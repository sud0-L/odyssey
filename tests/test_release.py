from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

from manager.artifact import write_build
from manager.cli import main as cli_main
from manager.dependencies import (
    ARCH_PACKAGES,
    OPTIONAL_PACKAGES,
    ArchDependencies,
    DependencyError,
)
from manager.install import Command, Installer, _atomic_link
from manager.inventory import XdgPaths
from manager.lifecycle import Lifecycle
from manager.reconcile import Reconciler


ROOT = Path(__file__).resolve().parent.parent


def fixture_paths(root: Path) -> XdgPaths:
    data = root / "data" / "odyssey"
    state = root / "state" / "odyssey" / "manager"
    return XdgPaths(
        root / "bin" / "odyssey",
        data / "manager" / "releases",
        data / "manager" / "current",
        data / "releases",
        data / "current",
        state / "install.json",
        state / "operations",
        state / "backups",
        root / "config" / "odyssey",
    )


def healthy_report() -> dict[str, object]:
    return {"evidence": {
        "startup": {"status": "valid", "value": {"state": "active"}},
        "units": {"status": "valid", "value": {
            "odyssey.service": {"ActiveState": "active", "MainPID": "7"}}},
        "instances": {"status": "valid", "value": {
            "instances": [{"odyssey": True}]}},
        "notifications": {"status": "valid", "value": {
            "odysseyMatch": True}},
    }}


def healthy_dependencies() -> dict[str, object]:
    return {"missingPackages": [], "errors": []}


class DependencyTests(unittest.TestCase):
    def test_zsh_is_optional_and_required_fonts_are_exact(self) -> None:
        required = {item.name: item for item in ARCH_PACKAGES}
        optional = {item.name: item for item in OPTIONAL_PACKAGES}
        self.assertNotIn("zsh", required)
        self.assertNotIn("git", required)
        self.assertEqual(optional["zsh"].dependency_class, "optional-zsh")
        self.assertEqual(optional["git"].dependency_class, "optional-zsh")
        self.assertEqual(
            required["adwaita-fonts"].files,
            ("/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf",),
        )
        self.assertEqual(
            required["ttf-jetbrains-mono-nerd"].files,
            ("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf",),
        )
        self.assertIn("hyprpicker", required)

    def test_broken_quickshell_is_rejected_before_dependency_install(self) -> None:
        commands: list[list[str]] = []

        def run(args: list[str]) -> Command:
            commands.append(args)
            return Command(127, "", "undefined symbol: Qt_6_PRIVATE_API")

        dependencies = ArchDependencies(
            which=lambda command: f"/usr/bin/{command}",
            platform=lambda: {"id": "arch", "packageManager": "pacman"},
            run=run,
            exists=lambda _path: True,
        )

        report = dependencies.inspect()
        quickshell = next(
            item for item in report["packages"] if item["name"] == "quickshell")
        self.assertFalse(quickshell["available"])
        self.assertIn("installed but unusable or incompatible", quickshell["error"])
        self.assertEqual(report["missingPackages"].count("quickshell"), 1)

        commands.clear()
        with self.assertRaisesRegex(
                DependencyError,
                "installed but unusable or incompatible.*rebuild quickshell-git"):
            dependencies.install(confirmed=True)

        self.assertEqual(commands, [["/usr/bin/qs", "--version"]])


class LifecycleTests(unittest.TestCase):
    @staticmethod
    def runner(args: list[str]) -> Command:
        command = args[3] if len(args) > 3 else ""
        if command == "plan":
            return Command(0, json.dumps({
                "status": "ready", "plan": {"planId": "fixture-plan"}}), "")
        return Command(0, json.dumps({
            "status": "completed", "state": "unmanaged",
            "receipt": {"receiptId": "fixture"}}), "")

    def test_update_rollback_and_same_release_repair_keep_pair_consistent(self) -> None:
        with tempfile.TemporaryDirectory(prefix="odyssey-lifecycle-test.") as raw:
            root = Path(raw)
            paths = fixture_paths(root)
            first = root / "first.ody"
            second = root / "second.ody"
            first_id = write_build(ROOT, "1.0.0", first)
            second_id = write_build(ROOT, "1.0.1", second)
            Installer(paths, run=self.runner).install(
                first, str(first_id["artifactSha256"]))
            lifecycle = Lifecycle(paths, run=self.runner, report=healthy_report,
                                  dependencies=healthy_dependencies)
            lifecycle.update(second, str(second_id["artifactSha256"]))
            self.assertEqual(paths.shell_current.resolve().name,
                             second_id["releaseId"])
            self.assertEqual(paths.manager_current.resolve().name,
                             second_id["releaseId"])
            self.assertEqual(
                os.readlink(paths.bin_command),
                str(paths.manager_current / "odyssey"),
            )
            lifecycle.rollback()
            record = json.loads(paths.install_manifest.read_text())
            release = json.loads(
                (paths.shell_current.resolve() / "release.json").read_text())
            self.assertEqual(paths.shell_current.resolve().name,
                             first_id["releaseId"])
            self.assertEqual(paths.manager_current.resolve().name,
                             first_id["releaseId"])
            self.assertEqual(record["artifact"]["releaseId"],
                             first_id["releaseId"])
            self.assertEqual(record["artifact"]["artifactSha256"],
                             release["artifactSha256"])
            self.assertEqual(paths.bin_command.resolve(),
                             paths.manager_current.resolve() / "odyssey")
            result = lifecycle.bootstrap(first, str(first_id["artifactSha256"]))
            self.assertEqual(result["action"], "repaired")

    def test_launcher_drift_is_detected_and_repair_uses_active_indirection(self) -> None:
        with tempfile.TemporaryDirectory(prefix="odyssey-repair-test.") as raw:
            root = Path(raw)
            paths = fixture_paths(root)
            first = root / "first.ody"
            second = root / "second.ody"
            first_id = write_build(ROOT, "1.1.0", first)
            second_id = write_build(ROOT, "1.1.1", second)
            Installer(paths, run=self.runner).install(
                first, str(first_id["artifactSha256"]))
            lifecycle = Lifecycle(paths, run=self.runner, report=healthy_report,
                                  dependencies=healthy_dependencies)
            lifecycle.update(second, str(second_id["artifactSha256"]))
            paths.bin_command.unlink()
            os.symlink(paths.manager_releases / str(first_id["releaseId"]) / "odyssey",
                       paths.bin_command)
            preserved = root / "config/hypr/hyprland.lua"
            preserved.parent.mkdir(parents=True)
            preserved.write_text("# personal configuration\n")

            evidence = Reconciler(paths)._launcher()
            self.assertEqual(evidence["status"], "invalid")
            self.assertIn("pinned", evidence["reason"])

            active = str(second_id["releaseId"])

            def repair_runner(args: list[str]) -> Command:
                if len(args) > 3 and args[3] == "status":
                    return Command(0, json.dumps({
                        "status": "ok", "state": "active",
                        "receipt": {"status": "valid", "configurationMode": "preserve"},
                        "release": {"id": active},
                    }), "")
                return self.runner(args)

            Lifecycle(paths, run=repair_runner).repair()

            self.assertEqual(os.readlink(paths.bin_command),
                             str(paths.manager_current / "odyssey"))
            self.assertEqual(paths.shell_current.resolve().name, active)
            self.assertEqual(paths.manager_current.resolve().name, active)
            self.assertEqual(preserved.read_text(), "# personal configuration\n")

    def test_update_rejects_broken_runtime_before_activation(self) -> None:
        with tempfile.TemporaryDirectory(prefix="odyssey-update-runtime-test.") as raw:
            root = Path(raw)
            paths = fixture_paths(root)
            first = root / "first.ody"
            second = root / "second.ody"
            first_id = write_build(ROOT, "1.2.0", first)
            second_id = write_build(ROOT, "1.2.1", second)
            Installer(paths, run=self.runner).install(
                first, str(first_id["artifactSha256"]))
            before = (os.readlink(paths.shell_current),
                      os.readlink(paths.manager_current),
                      os.readlink(paths.bin_command))
            lifecycle = Lifecycle(
                paths, run=self.runner, report=healthy_report,
                dependencies=lambda: {
                    "missingPackages": ["quickshell"],
                    "errors": ["Quickshell is installed but unusable"],
                },
            )

            with self.assertRaisesRegex(ValueError, "installed but unusable"):
                lifecycle.update(second, str(second_id["artifactSha256"]))

            self.assertEqual(before, (
                os.readlink(paths.shell_current),
                os.readlink(paths.manager_current),
                os.readlink(paths.bin_command),
            ))

    def test_config_reset_backs_up_before_defaults_and_preserves_activation(self) -> None:
        with tempfile.TemporaryDirectory(prefix="odyssey-config-reset-test.") as raw:
            root = Path(raw)
            paths = fixture_paths(root)
            artifact = root / "release.ody"
            identity = write_build(ROOT, "1.3.0", artifact)
            Installer(paths, run=self.runner).install(
                artifact, str(identity["artifactSha256"]))
            hypr = root / "config/hypr/hyprland.lua"
            kitty = root / "config/kitty/kitty.conf"
            hypr.parent.mkdir(parents=True); kitty.parent.mkdir(parents=True)
            hypr.write_text("personal hypr\n"); kitty.write_text("personal kitty\n")
            activation = (os.readlink(paths.shell_current),
                          os.readlink(paths.manager_current))
            lifecycle = Lifecycle(paths, run=self.runner)

            def assert_backup_then_reset(_release: str, _mode: str) -> None:
                backups = list((root / "state/odyssey/backups").iterdir())
                self.assertEqual(len(backups), 1)
                contents = [item.read_text() for item in backups[0].glob("*.bak")
                            if item.is_file()]
                self.assertIn("personal hypr\n", contents)
                self.assertIn("personal kitty\n", contents)
                hypr.write_text((paths.shell_current / "config/hypr/hyprland.lua").read_text())

            def reset_runner(args: list[str]) -> Command:
                if args and args[0] == "env":
                    kitty.write_text((paths.shell_current / "config/kitty/kitty.conf").read_text())
                    return Command(0, "HOST_CONFIG=completed\n", "")
                return self.runner(args)

            lifecycle.run = reset_runner
            with patch.dict(os.environ, {"HOME": str(root / "home")}), \
                    patch.object(lifecycle, "_reapply_startup",
                                 side_effect=assert_backup_then_reset):
                result = lifecycle.config_reset()

            self.assertEqual(hypr.read_text(),
                             (paths.shell_current / "config/hypr/hyprland.lua").read_text())
            self.assertEqual(kitty.read_text(),
                             (paths.shell_current / "config/kitty/kitty.conf").read_text())
            self.assertEqual(activation, (os.readlink(paths.shell_current),
                                          os.readlink(paths.manager_current)))
            self.assertTrue(Path(str(result["backupDirectory"])).is_dir())

    def test_config_reset_backup_failure_prevents_writes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="odyssey-config-reset-failure-test.") as raw:
            root = Path(raw)
            paths = fixture_paths(root)
            artifact = root / "release.ody"
            identity = write_build(ROOT, "1.3.1", artifact)
            Installer(paths, run=self.runner).install(
                artifact, str(identity["artifactSha256"]))
            config = root / "config/kitty/kitty.conf"
            config.parent.mkdir(parents=True)
            config.write_text("must survive\n")
            lifecycle = Lifecycle(paths, run=self.runner)

            with patch.dict(os.environ, {"HOME": str(root / "home")}), \
                    patch("manager.lifecycle.shutil.copy2", side_effect=OSError("disk full")), \
                    patch.object(lifecycle, "_reapply_startup") as startup:
                with self.assertRaisesRegex(OSError, "disk full"):
                    lifecycle.config_reset()

            startup.assert_not_called()
            self.assertEqual(config.read_text(), "must survive\n")

    def test_interrupted_transition_compensates_both_activation_links(self) -> None:
        with tempfile.TemporaryDirectory(prefix="odyssey-recovery-test.") as raw:
            root = Path(raw)
            paths = fixture_paths(root)
            first = root / "first.ody"
            second = root / "second.ody"
            first_id = write_build(ROOT, "2.0.0", first)
            second_id = write_build(ROOT, "2.0.1", second)
            Installer(paths, run=self.runner).install(
                first, str(first_id["artifactSha256"]))
            lifecycle = Lifecycle(paths, run=self.runner, report=healthy_report)
            manifest = lifecycle._manifest(second)
            lifecycle._place(second, second_id["artifactSha256"],
                             second_id["releaseId"], manifest)
            operation = paths.operations / "update-fixture"
            operation.mkdir()
            plan = {
                "schema": 1, "operationId": operation.name, "kind": "update",
                "artifact": second_id,
                "oldShellReleaseId": first_id["releaseId"],
                "newShellReleaseId": second_id["releaseId"],
                "oldManagerReleaseId": first_id["releaseId"],
                "newManagerReleaseId": second_id["releaseId"],
                "createdShellDirectory": True,
                "createdManagerDirectory": True,
                "startupPlan": "startup-plan.json",
            }
            lifecycle._checkpoint(operation, "activated")
            (operation / "plan.json").write_text(json.dumps(plan))
            (operation / "events.jsonl").touch()
            _atomic_link(paths.shell_current,
                         f"releases/{second_id['releaseId']}")
            _atomic_link(paths.manager_current,
                         f"releases/{second_id['releaseId']}")
            result = lifecycle.recover(operation.name)
            self.assertEqual(result["status"], "compensated")
            self.assertEqual(paths.shell_current.resolve().name,
                             first_id["releaseId"])
            self.assertEqual(paths.manager_current.resolve().name,
                             first_id["releaseId"])

    def test_interrupted_first_install_can_complete_or_compensate(self) -> None:
        class SimulatedCrash(BaseException):
            pass

        for startup_became_active in (True, False):
            with self.subTest(startup_became_active=startup_became_active):
                with tempfile.TemporaryDirectory(
                        prefix="odyssey-first-install-recovery.") as raw:
                    root = Path(raw)
                    paths = fixture_paths(root)
                    artifact = root / "release.ody"
                    identity = write_build(ROOT, "3.0.0", artifact)
                    state: dict[str, object] = {
                        "value": "unmanaged", "release": None, "crash": True}

                    def run(args: list[str]) -> Command:
                        command = args[3]
                        if command == "plan":
                            return Command(0, json.dumps({
                                "status": "ready",
                                "plan": {"planId": "startup-plan"}}), "")
                        if command == "apply" and state["crash"]:
                            state["value"] = (
                                "active" if startup_became_active else "partial")
                            state["release"] = identity["releaseId"]
                            raise SimulatedCrash()
                        if command == "status":
                            release = ({"id": state["release"]}
                                       if state["value"] == "active" else None)
                            return Command(0, json.dumps({
                                "status": "ok", "state": state["value"],
                                "release": release,
                                "receipt": {"status": "valid",
                                            "receiptId": "fixture"}}), "")
                        if command == "compensate":
                            state["value"] = "unmanaged"
                            state["release"] = None
                            return Command(1, json.dumps({
                                "status": "compensated"}), "")
                        return Command(0, json.dumps({
                            "status": "completed", "state": "unmanaged"}), "")

                    with self.assertRaises(SimulatedCrash):
                        Installer(paths, run=run).install(
                            artifact, str(identity["artifactSha256"]))
                    state["crash"] = False
                    operation = next(item for item in paths.operations.iterdir()
                                     if not (item / "result.json").exists())
                    result = Lifecycle(paths, run=run).recover(operation.name)
                    if startup_became_active:
                        record = json.loads(paths.install_manifest.read_text())
                        self.assertEqual(result["status"], "completed")
                        self.assertEqual(record["artifact"]["artifactSha256"],
                                         identity["artifactSha256"])
                        self.assertEqual(paths.shell_current.resolve().name,
                                         identity["releaseId"])
                        self.assertEqual(paths.manager_current.resolve().name,
                                         identity["releaseId"])
                    else:
                        self.assertEqual(result["status"], "compensated")
                        self.assertFalse(paths.install_manifest.exists())
                        self.assertFalse(paths.bin_command.exists())
                        self.assertFalse(paths.bin_command.is_symlink())


class LifecycleConfirmationTests(unittest.TestCase):
    def test_update_repair_and_config_reset_decline_without_mutation(self) -> None:
        commands = (
            (["update", "--json"], "Update Odyssey"),
            (["repair", "--json"], "Repair Odyssey"),
            (["config", "reset", "--json"], "Replace Odyssey-managed configuration"),
        )
        for argv, prompt in commands:
            with self.subTest(command=argv[0]):
                stdout, stderr = io.StringIO(), io.StringIO()
                with patch("sys.stdin", io.StringIO("\n")), \
                        redirect_stdout(stdout), redirect_stderr(stderr):
                    result = cli_main(argv)
                self.assertEqual(result, 0)
                self.assertIn(prompt, stderr.getvalue())
                payload = json.loads(stdout.getvalue())
                self.assertEqual(payload["status"], "cancelled")
                self.assertFalse(payload["changed"])
                self.assertNotIn("read-only Stage 2", stdout.getvalue())

    def test_confirmed_local_update_reaches_existing_lifecycle_update(self) -> None:
        digest = "a" * 64
        stdout = io.StringIO()
        with patch("manager.cli.confirm", return_value=True) as confirmation, \
                patch("manager.cli.resolve_xdg", return_value=object()), \
                patch("manager.cli.Lifecycle") as lifecycle, \
                redirect_stdout(stdout):
            lifecycle.return_value.update.return_value = {
                "kind": "update", "status": "completed", "releaseId": "next-release"}
            result = cli_main([
                "update", "--artifact", "/tmp/candidate.ody",
                "--expect-sha256", digest, "--json",
            ])

        self.assertEqual(result, 0)
        confirmation.assert_called_once()
        lifecycle.return_value.update.assert_called_once()
        payload = json.loads(stdout.getvalue())
        self.assertEqual(payload["status"], "completed")
        self.assertNotIn("unavailable", stdout.getvalue())


class StartupUnitTests(unittest.TestCase):
    def test_generated_unit_resolves_and_launches_active_release(self) -> None:
        with tempfile.TemporaryDirectory(prefix="odyssey-startup-unit.") as raw:
            root = Path(raw)
            artifact = root / "release.ody"
            identity = write_build(ROOT, "4.0.0", artifact)
            with tarfile.open(artifact, "r:") as archive:
                release_record = archive.extractfile("release.json")
                assert release_record is not None
                release_json = release_record.read()
            release = root / "data" / "odyssey" / "releases" / str(
                identity["releaseId"])
            release.mkdir(parents=True)
            shutil.copy2(ROOT / "shell.qml", release / "shell.qml")
            shutil.copytree(ROOT / "config", release / "config")
            shutil.copytree(ROOT / "scripts", release / "scripts")
            (release / "release.json").write_bytes(release_json)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            (fake_bin / "systemctl").symlink_to("/usr/bin/true")
            (fake_bin / "qs").symlink_to("/usr/bin/true")
            env = {
                **os.environ,
                "HOME": str(root / "home"),
                "XDG_CONFIG_HOME": str(root / "config-home"),
                "XDG_DATA_HOME": str(root / "data"),
                "XDG_STATE_HOME": str(root / "state"),
                "PATH": f"{fake_bin}:{os.environ['PATH']}",
            }
            adapter = ROOT / "scripts" / "startupctl.sh"
            planned = subprocess.run([
                str(adapter), "--contract", "odyssey-startup/v2", "plan",
                "--action", "apply", "--release-id", str(identity["releaseId"]),
                "--release-root", str(release), "--configuration-mode", "managed",
            ], env=env, text=True, capture_output=True, check=True)
            plan = root / "plan.json"
            plan.write_text(json.dumps(json.loads(planned.stdout)["plan"]))
            plan_id = json.loads(plan.read_text())["planId"]
            subprocess.run([
                str(adapter), "--contract", "odyssey-startup/v2", "apply",
                "--plan-file", str(plan), "--plan-id", plan_id,
            ], env=env, text=True, capture_output=True, check=True)
            unit = (root / "config-home" / "systemd" / "user" /
                    "odyssey.service").read_text()
            self.assertNotIn("odyssey\" session", unit)
            self.assertNotIn("/odyssey session", unit)
            self.assertIn("readlink -f \"$$current\"", unit)
            self.assertIn("$$release/scripts/odyssey-session.sh", unit)
            self.assertIn("--root \"$$release\"", unit)

            current = root / "data" / "odyssey" / "current"
            current.symlink_to(Path("releases") / str(identity["releaseId"]))
            exec_start = next(line for line in unit.splitlines()
                              if line.startswith("ExecStart="))
            command = exec_start.removeprefix(
                "ExecStart=/bin/sh -c '").removesuffix("'").replace("$$", "$")
            subprocess.run(["/bin/sh", "-c", command], env=env, check=True)


if __name__ == "__main__":
    unittest.main()
