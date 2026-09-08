"""Bounded local-artifact installation transaction.

This module deliberately owns only first-install durability and activation. The
startup adapter remains the only writer for its user unit and Hyprland integration.
"""
from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import uuid
from typing import Callable

from manager.artifact import canonical_json, verify
from manager.inventory import XdgPaths


class InstallError(ValueError):
    pass


@dataclass(frozen=True)
class Command:
    code: int
    out: str
    err: str = ""


def _run(args: list[str]) -> Command:
    try:
        result = subprocess.run(args, text=True, capture_output=True, check=False)
        return Command(result.returncode, result.stdout, result.stderr)
    except OSError as error:
        return Command(127, "", str(error))


def _atomic_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".odyssey-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as file:
            file.write(canonical_json(value)); file.flush(); os.fsync(file.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary): os.unlink(temporary)


def _atomic_link(path: Path, target: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.parent / f".odyssey-link-{uuid.uuid4().hex}"
    os.symlink(target, temporary)
    os.replace(temporary, path)


def _remove_tree(path: Path) -> None:
    if path.exists() or path.is_symlink():
        for item in path.rglob("*") if path.is_dir() and not path.is_symlink() else ():
            try: os.chmod(item, 0o755 if item.is_dir() else 0o644)
            except OSError: pass
        try: os.chmod(path, 0o755)
        except OSError: pass
        if path.is_dir() and not path.is_symlink(): shutil.rmtree(path)
        else: path.unlink()


def _immutable(path: Path) -> None:
    for item in sorted(path.rglob("*"), reverse=True):
        if item.is_symlink(): continue
        os.chmod(item, 0o555 if item.is_dir() else (0o555 if item.stat().st_mode & 0o111 else 0o444))
    os.chmod(path, 0o555)


class Installer:
    """Durable first-install transaction with an injectable adapter runner."""
    def __init__(self, paths: XdgPaths, *, run: Callable[[list[str]], Command] = _run):
        self.paths, self.run = paths, run

    def install(self, artifact: Path, expected_digest: str,
                *, configuration_mode: str = "managed") -> dict[str, object]:
        if configuration_mode not in ("managed", "preserve"):
            raise InstallError("configuration mode must be managed or preserve")
        if not isinstance(expected_digest, str) or len(expected_digest) != 64 or any(ch not in "0123456789abcdef" for ch in expected_digest):
            raise InstallError("install requires an independently supplied lowercase SHA-256 digest")
        try:
            identity = verify(artifact, expected_digest)
        except ValueError as error:
            raise InstallError(str(error)) from error
        release_id = str(identity["releaseId"])
        manifest = self._manifest(artifact)
        self._preflight(release_id)
        operation_id = f"install-{uuid.uuid4().hex}"
        operation = self.paths.operations / operation_id
        operation.mkdir(parents=True, mode=0o700)
        plan = {"schema": 1, "operationId": operation_id, "kind": "install",
                "artifact": {"path": str(artifact.resolve()), **identity},
                "releaseId": release_id, "configurationMode": configuration_mode,
                "startupPlan": "startup-plan.json"}
        _atomic_json(operation / "plan.json", plan)
        (operation / "events.jsonl").touch(mode=0o600)
        self._event(operation, "planned")
        self._checkpoint(operation, "prepare")
        stage = self.paths.shell_releases.parent / f".stage-{operation_id}"
        adapter_plan: Path | None = None
        adapter_id: str | None = None
        adapter_started = False
        try:
            # Never extract from a path that an external writer can swap after the
            # initial identity check.  The operation-local copy is reverified.
            staged_artifact = operation / "artifact.ody"
            shutil.copyfile(artifact, staged_artifact)
            if verify(staged_artifact, expected_digest) != identity:
                raise InstallError("staged artifact identity changed during copy")
            self._extract(staged_artifact, stage)
            shell_stage, manager_stage = stage / "shell", stage / "manager"
            if not (shell_stage / "shell.qml").is_file() or not (manager_stage / "scripts/startupctl.sh").is_file():
                raise InstallError("verified artifact lacks required shell or startup adapter payload")
            (shell_stage / "release.json").write_bytes(canonical_json(manifest))
            self.paths.shell_releases.mkdir(parents=True, exist_ok=True)
            self.paths.manager_releases.mkdir(parents=True, exist_ok=True)
            shell_release, manager_release = self.paths.shell_releases / release_id, self.paths.manager_releases / release_id
            if shell_release.exists() or manager_release.exists(): raise InstallError("release identity already exists; use the lifecycle update path")
            os.replace(shell_stage, shell_release); os.replace(manager_stage, manager_release)
            _immutable(shell_release); _immutable(manager_release)
            stage.rmdir()
            self._event(operation, "artifacts-installed"); self._checkpoint(operation, "adapter-plan")
            _atomic_link(self.paths.manager_current, f"releases/{release_id}")
            if self.paths.bin_command.exists() or self.paths.bin_command.is_symlink(): raise InstallError("stable odyssey command already exists")
            _atomic_link(self.paths.bin_command, str(self.paths.manager_current / "odyssey"))
            adapter = self.paths.manager_current / "scripts/startupctl.sh"
            response = self._adapter(adapter, ["plan", "--action", "apply",
                "--release-id", release_id, "--release-root", str(shell_release),
                "--configuration-mode", configuration_mode])
            plan_value = response.get("plan")
            if response.get("status") != "ready" or not isinstance(plan_value, dict) or not isinstance(plan_value.get("planId"), str): raise InstallError("startup adapter refused install plan")
            adapter_plan = operation / "startup-plan.json"; _atomic_json(adapter_plan, plan_value); adapter_id = str(plan_value["planId"])
            self._event(operation, "startup-plan-durable", {"planId": adapter_id}); self._checkpoint(operation, "adapter-apply")
            response = self._adapter(adapter, ["apply", "--plan-file", str(adapter_plan), "--plan-id", adapter_id])
            adapter_started = response.get("status") in ("completed", "unchanged")
            if not adapter_started: raise InstallError("startup adapter did not activate the selected release")
            self._event(operation, "startup-applied", {"receipt": response.get("receipt")}); self._checkpoint(operation, "activate")
            _atomic_link(self.paths.shell_current, f"releases/{release_id}")
            install = {"schema": 1, "installationId": operation_id, "installedReleaseIds": [release_id], "activeReleaseId": release_id, "previousReleaseId": None, "dataSchemaVersion": manifest["dataSchemaVersion"], "operationId": operation_id, "artifact": identity, "startup": {"adapter": "odyssey-startup", "adapterVersion": 3, "receipt": response.get("receipt")}}
            _atomic_json(self.paths.install_manifest, install)
            self._event(operation, "committed"); self._checkpoint(operation, "committed")
            result = {"schema": 1, "operationId": operation_id, "status": "completed", "releaseId": release_id}
            _atomic_json(operation / "result.json", result)
            return {"kind": "install", "status": "completed", "operationId": operation_id, **identity}
        except Exception as error:
            try:
                compensated = self._compensate(adapter_plan, adapter_id) if adapter_started and adapter_plan and adapter_id else True
            except InstallError:
                compensated = False
            self._cleanup_new(release_id, stage)
            status = "compensated" if compensated else "failed"
            self._event(operation, "compensated" if compensated else "compensation-failed", {"reason": str(error)})
            self._checkpoint(operation, status)
            _atomic_json(operation / "result.json", {"schema": 1, "operationId": operation_id, "status": status, "reason": str(error)})
            raise InstallError(f"install {status}: {error}") from error

    def _preflight(self, release_id: str) -> None:
        for path in (self.paths.install_manifest, self.paths.shell_current, self.paths.manager_current, self.paths.bin_command):
            if path.exists() or path.is_symlink(): raise InstallError("existing installation state requires a later lifecycle stage")
        if (self.paths.shell_releases / release_id).exists() or (self.paths.manager_releases / release_id).exists(): raise InstallError("release identity already exists")
        if self.paths.operations.exists() and any(item.is_dir() and not (item / "result.json").is_file() for item in self.paths.operations.iterdir()): raise InstallError("an interrupted operation blocks installation")

    def _manifest(self, artifact: Path) -> dict[str, object]:
        with tarfile.open(artifact, "r:") as archive:
            member = archive.extractfile("release.json")
            if member is None: raise InstallError("verified artifact release manifest is unavailable")
            return json.loads(member.read().decode("utf-8"))

    def _extract(self, artifact: Path, stage: Path) -> None:
        _remove_tree(stage); stage.mkdir(parents=True)
        with tarfile.open(artifact, "r:") as outer:
            payload = outer.extractfile("payload.tar")
            if payload is None: raise InstallError("verified artifact payload is unavailable")
            with tarfile.open(fileobj=payload, mode="r:") as inner:
                for member in inner.getmembers():
                    component, relative = member.name.split("/", 1)
                    destination = stage / component / relative; destination.parent.mkdir(parents=True, exist_ok=True)
                    if member.issym(): os.symlink(member.linkname, destination)
                    else:
                        source = inner.extractfile(member)
                        if source is None: raise InstallError("verified payload member is unreadable")
                        with destination.open("wb") as output: shutil.copyfileobj(source, output)
                        os.chmod(destination, member.mode)

    def _adapter(self, adapter: Path, arguments: list[str]) -> dict[str, object]:
        result = self.run([str(adapter), "--contract", "odyssey-startup/v2", *arguments])
        try: payload = json.loads(result.out)
        except json.JSONDecodeError as error: raise InstallError("startup adapter returned invalid JSON") from error
        if result.code != 0 and payload.get("status") not in ("completed", "unchanged", "compensated"): raise InstallError(str(payload.get("error", "startup adapter failed")))
        return payload

    def _compensate(self, plan: Path, plan_id: str) -> bool:
        response = self._adapter(self.paths.manager_current / "scripts/startupctl.sh", ["compensate", "--plan-file", str(plan), "--plan-id", plan_id])
        return response.get("status") == "compensated"

    def _cleanup_new(self, release_id: str, stage: Path) -> None:
        if self.paths.install_manifest.exists(): self.paths.install_manifest.unlink()
        for path in (self.paths.shell_current, self.paths.manager_current, self.paths.bin_command):
            if path.is_symlink(): path.unlink()
        _remove_tree(stage); _remove_tree(self.paths.shell_releases / release_id); _remove_tree(self.paths.manager_releases / release_id)

    def _event(self, operation: Path, event: str, extra: dict[str, object] | None = None) -> None:
        record = {"schema": 1, "operationId": operation.name, "event": event, **(extra or {})}
        with (operation / "events.jsonl").open("ab") as file:
            file.write(canonical_json(record)); file.flush(); os.fsync(file.fileno())

    def _checkpoint(self, operation: Path, phase: str) -> None:
        _atomic_json(operation / "checkpoint.json", {"schema": 1, "operationId": operation.name, "phase": phase})
