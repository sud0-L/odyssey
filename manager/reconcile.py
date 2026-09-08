"""Bounded, read-only host reconciliation for lifecycle status and doctor."""
from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
import subprocess
from typing import Callable

from manager.contracts import Evidence, parse_installation_manifest, parse_operation_plan, parse_operation_result, parse_release_manifest
from manager.inventory import XdgPaths

MAX_RECORD = 256 * 1024
MAX_OPERATIONS = 64
TIMEOUT = 3


@dataclass(frozen=True)
class Command:
    code: int
    out: str
    err: str = ""


def _run(args: list[str], timeout: int = TIMEOUT) -> Command:
    try:
        result = subprocess.run(args, text=True, capture_output=True, timeout=timeout, check=False)
        return Command(result.returncode, result.stdout[:8192], result.stderr[:512].replace("\n", " "))
    except (OSError, subprocess.TimeoutExpired) as error:
        return Command(127, "", str(error)[:256].replace("\n", " "))


class Reconciler:
    """Reader-injectable snapshot builder; none of its helpers mutate host state."""
    def __init__(self, paths: XdgPaths, *, run: Callable[[list[str], int], Command] = _run, root: Path | None = None, proc: Path = Path("/proc"), home: Path | None = None):
        self.paths, self.run, self.root, self.proc = paths, run, root or Path(__file__).resolve().parent.parent, proc
        self.home = home or Path(os.environ.get("HOME", str(Path.home())))

    def report(self) -> dict[str, object]:
        installation = self._json(self.paths.install_manifest, parse_installation_manifest)
        activation = self._activation(self.paths.shell_current, self.paths.shell_releases)
        manager_activation = self._activation(self.paths.manager_current, self.paths.manager_releases)
        launcher = self._launcher()
        release = self._release(activation)
        operations = self._operations()
        startup = self._startup()
        units = self._units()
        instances = self._instances(release)
        notifications = self._notifications(instances)
        sddm = self._sddm()
        lifecycle = self._lifecycle(installation, activation, manager_activation, release)
        evidence = {"installation": installation, "activation": activation, "managerActivation": manager_activation, "launcher": launcher, "release": release, "lifecycle": lifecycle, "operations": operations, "startup": startup, "units": units, "instances": instances, "notifications": notifications, "sddm": sddm}
        return {"schema": 1, "kind": "status", "readOnly": True, "summary": {"state": self._state(evidence)}, "evidence": evidence}

    def _present(self, path: Path) -> str:
        try:
            resolved = path.resolve()
            home = self.home.resolve()
            if resolved == home or resolved.is_relative_to(home):
                return "~" + str(resolved).removeprefix(str(home))
            return str(resolved)
        except OSError:
            return str(path).replace(str(self.home), "~")

    def _json(self, path: Path, parser: Callable[[object], Evidence]) -> dict[str, object]:
        try:
            if not path.is_file() or path.is_symlink():
                return Evidence("absent", reason="record is absent").as_dict()
            if path.stat().st_size > MAX_RECORD:
                return Evidence("invalid", reason="record exceeds bounded size").as_dict()
            return parser(path.read_text(encoding="utf-8")).as_dict()
        except OSError as error:
            return Evidence("unavailable", reason=str(error)[:160]).as_dict()

    def _activation(self, link: Path, releases: Path) -> dict[str, object]:
        try:
            if not link.exists() and not link.is_symlink():
                return Evidence("absent", reason="activation link is absent").as_dict()
            if not link.is_symlink():
                return Evidence("invalid", reason="activation path is not a symlink").as_dict()
            target = os.readlink(link)
            parts = Path(target).parts
            if len(parts) != 2 or parts[0] != "releases" or not parts[1] or Path(target).is_absolute() or parts[1] in (".", ".."):
                return Evidence("invalid", reason="activation link target is unsafe").as_dict()
            resolved = (link.parent / target).resolve(strict=False)
            expected = (releases / parts[1]).resolve(strict=False)
            if resolved != expected or not resolved.is_dir():
                return Evidence("invalid", reason="activation link is dangling").as_dict()
            return Evidence("valid", {"releaseId": parts[1], "path": self._present(resolved)}).as_dict()
        except OSError as error:
            return Evidence("unavailable", reason=str(error)[:160]).as_dict()

    def _launcher(self) -> dict[str, object]:
        expected = str(self.paths.manager_current / "odyssey")
        try:
            if not self.paths.bin_command.exists() and not self.paths.bin_command.is_symlink():
                return Evidence("absent", reason="stable launcher is absent").as_dict()
            if not self.paths.bin_command.is_symlink():
                return Evidence("invalid", reason="stable launcher is not a symlink").as_dict()
            target = os.readlink(self.paths.bin_command)
            if target != expected:
                return Evidence(
                    "invalid",
                    reason="stable launcher is pinned or does not use active-manager indirection",
                ).as_dict()
            if not (self.paths.manager_current / "odyssey").is_file():
                return Evidence("invalid", reason="stable launcher target is unavailable").as_dict()
            return Evidence("valid", {"target": expected}).as_dict()
        except OSError as error:
            return Evidence("unavailable", reason=str(error)[:160]).as_dict()

    def _release(self, activation: dict[str, object]) -> dict[str, object]:
        if activation["status"] != "valid":
            return Evidence("absent", reason="no active release").as_dict()
        value = activation["value"]
        assert isinstance(value, dict)
        record = self._json(self.paths.shell_releases / str(value["releaseId"]) / "release.json", parse_release_manifest)
        if record["status"] == "valid" and record["value"].get("releaseId") != value["releaseId"]:  # type: ignore[index]
            return Evidence("invalid", reason="release record identity does not match activation").as_dict()
        return record

    def _lifecycle(self, installation: dict[str, object], activation: dict[str, object], manager_activation: dict[str, object], release: dict[str, object]) -> dict[str, object]:
        if installation["status"] != "valid":
            return Evidence("absent", reason="no valid installation lifecycle identity").as_dict()
        active = installation["value"].get("activeReleaseId")  # type: ignore[index]
        linked = activation.get("value", {}).get("releaseId") if activation["status"] == "valid" else None
        manager_linked = manager_activation.get("value", {}).get("releaseId") if manager_activation["status"] == "valid" else None
        artifact = installation["value"].get("artifact", {})  # type: ignore[index]
        release_value = release.get("value", {}) if release["status"] == "valid" else {}
        if active != linked or active != manager_linked or release["status"] != "valid":
            return Evidence("invalid", reason="installation active release does not match shell and manager activation").as_dict()
        if (not isinstance(artifact, dict) or artifact.get("releaseId") != active
                or artifact.get("artifactSha256") != release_value.get("artifactSha256")):
            return Evidence("invalid", reason="installation artifact identity does not match active release").as_dict()
        return Evidence("valid", {"activeReleaseId": active}).as_dict()

    def _operations(self) -> dict[str, object]:
        if not self.paths.operations.exists():
            return Evidence("absent", reason="operations are absent").as_dict()
        try:
            dirs = sorted((item for item in self.paths.operations.iterdir() if item.is_dir() and not item.is_symlink()), key=lambda item: item.name)[:MAX_OPERATIONS]
        except OSError as error:
            return Evidence("unavailable", reason=str(error)[:160]).as_dict()
        interrupted, terminal, invalid = [], [], []
        for directory in dirs:
            plan = self._json(directory / "plan.json", parse_operation_plan)
            required = [directory / name for name in ("events.jsonl", "checkpoint.json", "result.json")]
            result = self._json(directory / "result.json", parse_operation_result)
            if plan["status"] != "valid" or any(not path.is_file() for path in required[:2]):
                invalid.append(directory.name)
            elif result["status"] == "absent":
                interrupted.append(directory.name)
            elif result["status"] == "valid" and result["value"].get("operationId") == plan["value"].get("operationId"):  # type: ignore[index]
                terminal.append({"id": directory.name, "status": result["value"]["status"]})  # type: ignore[index]
            else:
                invalid.append(directory.name)
        return Evidence("valid", {"interrupted": interrupted, "terminal": terminal, "invalid": invalid, "bounded": len(dirs) == MAX_OPERATIONS}).as_dict()

    def _startup(self) -> dict[str, object]:
        # Once installed, probe the adapter shipped with the active manager rather
        # than allowing a development checkout to describe live ownership.
        adapter = self.paths.manager_current / "scripts/startupctl.sh"
        if not adapter.is_file(): adapter = self.root / "scripts/startupctl.sh"
        result = self.run([str(adapter), "status"], TIMEOUT)
        state = result.out.strip()
        accepted = {f"STATE={item}" for item in ("unmanaged", "configured", "active", "partial", "conflict", "unsupported")}
        if state not in accepted:
            return Evidence("unavailable", reason="startup status probe failed").as_dict()
        return Evidence("unsupported" if state == "STATE=unsupported" else "valid", {"state": state[6:]}).as_dict()

    def _units(self) -> dict[str, object]:
        props = "LoadState,ActiveState,SubState,UnitFileState,MainPID,FragmentPath,ExecStart"
        units = {}
        for unit in ("odyssey.service", "hypridle.service"):
            result = self.run(["systemctl", "--user", "show", unit, f"--property={props}", "--no-pager"], TIMEOUT)
            if result.code != 0:
                if unit == "hypridle.service":
                    units[unit] = {"LoadState": "not-found", "ActiveState": "inactive"}
                    continue
                return Evidence("unavailable", reason="user systemd properties unavailable").as_dict()
            fields = {}
            for line in result.out.splitlines():
                if "=" in line:
                    key, value = line.split("=", 1)
                    if key in {"LoadState", "ActiveState", "SubState", "UnitFileState", "MainPID", "FragmentPath"}:
                        fields[key] = self._present(Path(value)) if key == "FragmentPath" and value else value
            units[unit] = fields
        return Evidence("valid", units).as_dict()

    def _instances(self, release: dict[str, object]) -> dict[str, object]:
        result = self.run(["qs", "list", "--all"], TIMEOUT)
        if result.code != 0:
            return Evidence("unavailable", reason="Quickshell instance probe unavailable").as_dict()
        found, ident, config, reported, unreadable = [], None, None, 0, 0
        for line in result.out.splitlines():
            if line.startswith("Instance "):
                ident, config = line.split()[1].rstrip(":"), None
                reported += 1
            elif line.startswith("  Process ID: "):
                try: pid = int(line[14:])
                except ValueError: continue
            elif line.startswith("  Config path: ") and ident:
                config = Path(line[15:])
                try:
                    exe = (self.proc / str(pid) / "exe").resolve()
                    argv = (self.proc / str(pid) / "cmdline").read_bytes().split(b"\0")
                    config_args = {str(config).encode(), str(config.parent).encode()}
                    if exe.name not in ("qs", "quickshell") or config_args.isdisjoint(argv): continue
                    found.append({"id": ident, "pid": pid, "config": self._present(config), "odyssey": self._is_odyssey_config(config, release)})
                except (OSError, UnboundLocalError):
                    unreadable += 1
                    continue
        if reported and unreadable == reported:
            return Evidence("unavailable", reason="Quickshell process identities unavailable").as_dict()
        return Evidence("valid", {"instances": found}).as_dict()

    def _is_odyssey_config(self, config: Path, release: dict[str, object]) -> bool:
        if release["status"] == "valid":
            return config.resolve(strict=False) == (self.paths.shell_releases / release["value"]["releaseId"] / "shell.qml").resolve(strict=False)  # type: ignore[index]
        return config.resolve(strict=False) == (self.root / "shell.qml").resolve(strict=False)

    def _notifications(self, instances: dict[str, object]) -> dict[str, object]:
        result = self.run(["busctl", "--user", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", "org.freedesktop.Notifications"], TIMEOUT)
        if result.code != 0:
            return Evidence("unavailable", reason="notification owner PID unavailable").as_dict()
        tokens = result.out.split()
        try: pid = next(int(token) for token in reversed(tokens) if token.isdigit() and int(token) > 0)
        except StopIteration: return Evidence("unavailable", reason="notification owner PID malformed").as_dict()
        matched = any(item["pid"] == pid and item["odyssey"] for item in instances.get("value", {}).get("instances", [])) if instances["status"] == "valid" else False
        return Evidence("valid", {"pid": pid, "odysseyMatch": matched}).as_dict()

    def _sddm(self) -> dict[str, object]:
        files = [*sorted(Path("/usr/lib/sddm/sddm.conf.d").glob("*.conf")), *sorted(Path("/etc/sddm.conf.d").glob("*.conf")), Path("/etc/sddm.conf")]
        current, seen = None, []
        for file in files:
            try:
                if not file.is_file(): continue
                in_theme = False
                for line in file.read_text(encoding="utf-8", errors="replace").splitlines():
                    in_theme = line.strip().lower() == "[theme]" if line.strip().startswith("[") else in_theme
                    if in_theme and line.strip().startswith("Current="):
                        current, seen = line.split("=", 1)[1].strip(), seen + [str(file)]
            except OSError: continue
        active = self.run(["systemctl", "show", "display-manager.service", "--property=LoadState,ActiveState,SubState", "--no-pager"], TIMEOUT)
        value = {"installed": Path("/usr/bin/sddm").exists(), "theme": current, "themeFiles": seen, "displayManagerActive": "ActiveState=active" in active.out}
        return Evidence("valid", value).as_dict()

    def _state(self, evidence: dict[str, object]) -> str:
        installation = evidence["installation"]
        activation = evidence["activation"]
        manager_activation = evidence["managerActivation"]
        launcher = evidence["launcher"]
        startup = evidence["startup"]
        if (installation["status"] == "absent" and activation["status"] == "absent"
                and manager_activation["status"] == "absent"):
            return "not-installed"
        if any(section["status"] == "unsupported" for section in evidence.values()): return "unsupported"
        if installation["status"] in ("invalid", "unsupported") or activation["status"] == "invalid" or manager_activation["status"] == "invalid" or launcher["status"] == "invalid" or evidence["lifecycle"]["status"] == "invalid" or (startup["status"] == "valid" and startup["value"]["state"] == "conflict"): return "conflict"
        units = evidence["units"]
        if units["status"] == "valid":
            values = units["value"]
            if values.get("odyssey.service", {}).get("ActiveState") != "active": return "degraded"
            idle = values.get("hypridle.service", {})
            if idle.get("LoadState") == "loaded" and idle.get("ActiveState") != "active": return "degraded"
        if any(section["status"] in ("invalid", "unavailable") for section in evidence.values()): return "degraded"
        return "healthy"


def findings(snapshot: dict[str, object]) -> list[dict[str, str]]:
    evidence = snapshot["evidence"]
    result: list[dict[str, str]] = []
    def add(severity: str, code: str, message: str, remediation: str) -> None: result.append({"severity": severity, "code": code, "message": message, "remediation": remediation})
    install, activation, startup = evidence["installation"], evidence["activation"], evidence["startup"]
    if install["status"] == "absent": add("info", "LIFECYCLE_NOT_INSTALLED", "No lifecycle installation record exists.", "Run the installer to create a managed release.")
    for name, item in (("INSTALLATION", install), ("ACTIVATION", activation), ("MANAGER_ACTIVATION", evidence["managerActivation"]), ("RELEASE", evidence["release"]), ("LIFECYCLE", evidence["lifecycle"])):
        if item["status"] in ("invalid", "unsupported"): add("error", f"{name}_{item['status'].upper()}", f"{name.title()} evidence is {item['status']}.", "Inspect the record; do not edit managed state manually.")
    launcher = evidence["launcher"]
    if launcher["status"] == "invalid":
        add("error", "LAUNCHER_INVALID", str(launcher["reason"]),
            "Run odyssey repair to restore active-manager indirection.")
    if startup["status"] == "valid" and startup["value"]["state"] in ("partial", "conflict"): add("error", f"STARTUP_{startup['value']['state'].upper()}", "Startup ownership is incomplete or conflicting.", "Use startupctl diagnostics before lifecycle mutation.")
    elif startup["status"] == "unavailable": add("warning", "STARTUP_UNAVAILABLE", "Startup ownership could not be probed.", "Ensure the user systemd manager is available.")
    ops = evidence["operations"]
    if ops["status"] == "valid" and ops["value"]["interrupted"]: add("warning", "OPERATIONS_INTERRUPTED", "Interrupted lifecycle operations were found.", "Run odyssey repair after reviewing the interrupted operation.")
    note = evidence["notifications"]
    if note["status"] == "valid" and not note["value"]["odysseyMatch"]: add("error", "NOTIFICATIONS_OWNER_MISMATCH", "Notification owner does not match an Odyssey instance.", "Resolve the competing notification owner.")
    elif note["status"] == "unavailable": add("warning", "NOTIFICATIONS_UNAVAILABLE", "Notification ownership could not be confirmed.", "Check the user session bus.")
    instances = evidence["instances"]
    if instances["status"] == "unavailable": add("warning", "INSTANCES_UNAVAILABLE", "Quickshell process identities could not be confirmed.", "Check /proc visibility for the session.")
    units = evidence["units"]
    if units["status"] == "valid":
        values = units["value"]
        if values.get("odyssey.service", {}).get("ActiveState") != "active": add("error", "ODYSSEY_SERVICE_INACTIVE", "odyssey.service is not active.", "Run odyssey repair and inspect the user journal.")
        idle = values.get("hypridle.service", {})
        if idle.get("LoadState") == "loaded" and idle.get("ActiveState") != "active": add("warning", "HYPRIDLE_SERVICE_INACTIVE", "hypridle.service is installed but inactive.", "Review the managed idle service and its user journal.")
    return result
