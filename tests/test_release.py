from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest

from manager.artifact import write_build
from manager.dependencies import ARCH_PACKAGES, OPTIONAL_PACKAGES
from manager.install import Command, Installer, _atomic_link
from manager.inventory import XdgPaths
from manager.lifecycle import Lifecycle


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
            lifecycle = Lifecycle(paths, run=self.runner, report=healthy_report)
            lifecycle.update(second, str(second_id["artifactSha256"]))
            self.assertEqual(paths.shell_current.resolve().name,
                             second_id["releaseId"])
            self.assertEqual(paths.manager_current.resolve().name,
                             second_id["releaseId"])
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
