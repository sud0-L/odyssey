"""Small update, rollback, and recovery transaction.

It deliberately composes the installer extractor and startup-v2 adapter instead of
creating another startup or health subsystem.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import tempfile
import time
import uuid
from typing import Callable

from manager import CONTRACT_SCHEMA_VERSION, MANAGER_VERSION
from manager.artifact import verify
from manager.contracts import parse_installation_manifest, parse_release_manifest
from manager.dependencies import ArchDependencies
from manager.install import InstallError, Installer, _atomic_json, _atomic_link, _immutable, _remove_tree
from manager.reconcile import Reconciler


class Lifecycle(Installer):
    """The running manager owns an update until its terminal result is durable."""
    def __init__(self, *args, report: Callable[[], dict[str, object]] | None = None,
                 dependencies: Callable[[], dict[str, object]] | None = None, **kwargs):
        super().__init__(*args, **kwargs)
        self.report = report or (lambda: Reconciler(self.paths).report())
        self.dependencies = dependencies or (lambda: ArchDependencies().inspect())

    def current_release(self) -> dict[str, str]:
        """Return the active public version after checking update invariants."""
        install = self._installation()
        self._require_consistent_activation(install)
        release_id = str(install["activeReleaseId"])
        if not self._release_pair_valid(release_id):
            raise InstallError("active release pair is invalid; run odyssey repair first")
        manifest = self._release_manifest(release_id)
        if manifest["releaseId"] != release_id:
            raise InstallError("active release identity is inconsistent; run odyssey repair first")
        return {"version": str(manifest["version"]), "releaseId": release_id}

    def update(self, artifact: Path, expected_digest: str, *,
               source: dict[str, object] | None = None,
               configuration_mode: str | None = None) -> dict[str, object]:
        identity = self._verify(artifact, expected_digest)
        install = self._installation()
        self._require_consistent_activation(install)
        self._validate_runtime()
        old = str(install["activeReleaseId"])
        if identity["releaseId"] == old: raise InstallError("candidate is already active")
        manifest = self._manifest(artifact); self._compatible(manifest, install)
        return self._transition("update", artifact, expected_digest, identity,
                                manifest, install, old, source or {"kind": "local"},
                                configuration_mode=configuration_mode)

    def repair(self, operation_id: str | None = None) -> dict[str, object]:
        recovered: list[str] = []
        interrupted = self._interrupted_operation_paths()
        if operation_id is not None:
            selected = self.paths.operations / operation_id
            if selected not in interrupted:
                raise InstallError("requested interrupted operation is unavailable")
            interrupted = [selected]
        for operation in interrupted:
            result = self.recover(operation.name)
            recovered.append(str(result["operationId"]))
        install = self._installation()
        release_id = str(install["activeReleaseId"])
        if not self._release_pair_valid(release_id):
            raise InstallError("active release pair is invalid and cannot be repaired in place")
        self._repair_activation_links(release_id)
        adapter = self.paths.manager_releases / release_id / "scripts" / "startupctl.sh"
        status = self._adapter(adapter, ["status"])
        receipt = status.get("receipt")
        active_release = status.get("release")
        startup_valid = (
            status.get("state") == "active"
            and isinstance(receipt, dict) and receipt.get("status") == "valid"
            and isinstance(active_release, dict) and active_release.get("id") == release_id
        )
        if not startup_valid:
            mode = (str(receipt.get("configurationMode"))
                    if isinstance(receipt, dict)
                    and receipt.get("configurationMode") in ("managed", "preserve")
                    else "preserve")
            self._reapply_startup(release_id, mode)
        return {"kind": "repair", "status": "completed", "releaseId": release_id,
                "version": str(self._release_manifest(release_id)["version"]),
                "recoveredOperations": recovered}

    def config_reset(self) -> dict[str, object]:
        install = self._installation()
        self._require_consistent_activation(install)
        release_id = str(install["activeReleaseId"])
        root = self.paths.shell_releases / release_id
        if not self._release_pair_valid(release_id):
            raise InstallError("active release pair is invalid; run odyssey repair first")
        backup = self._backup_managed_config()
        self._reapply_startup(release_id, "managed")
        receipt = self.paths.install_manifest.parent.parent / "installer" / "host-config.json"
        zsh_enabled = False
        try:
            zsh_enabled = bool(json.loads(receipt.read_text()).get("zshEnabled", False))
        except (OSError, json.JSONDecodeError):
            pass
        helper = root / "scripts" / "host-configctl.sh"
        result = self.run(["env", f"ODYSSEY_USER_BACKUP_DIR={backup}",
                           str(helper), "apply", str(zsh_enabled).lower()])
        if result.code != 0:
            detail = result.err.strip() or result.out.strip() or "unknown failure"
            raise InstallError("config reset failed: " + detail)
        return {"kind": "config-reset", "status": "completed",
                "releaseId": release_id, "version": str(self._release_manifest(release_id)["version"]),
                "backupDirectory": str(backup)}

    def bootstrap(self, artifact: Path, expected_digest: str, *,
                  configuration_mode: str | None = None) -> dict[str, object]:
        """Converge source-install lifecycle state without exposing stage details."""
        identity = self._verify(artifact, expected_digest)
        recovered: list[str] = []
        for operation in list(self._interrupted_operation_paths()):
            result = self.recover(operation.name)
            recovered.append(str(result["operationId"]))
        installation = self._valid_installation_or_none()
        release_id = str(identity["releaseId"])
        if installation is not None and self._release_pair_valid(str(installation["activeReleaseId"])):
            if str(installation["activeReleaseId"]) == release_id:
                self._repair_activation_links(release_id)
                self._reapply_startup(release_id, configuration_mode)
                return {"kind": "bootstrap", "status": "completed", "action": "repaired",
                        "releaseId": release_id,
                        "version": str(self._release_manifest(release_id)["version"]),
                        "recoveredOperations": recovered}
            result = self.update(artifact, expected_digest,
                                 configuration_mode=configuration_mode)
            self._reapply_startup(release_id, configuration_mode)
            return {**result, "kind": "bootstrap", "action": "updated",
                    "recoveredOperations": recovered}
        if self._has_lifecycle_state():
            backup = self._quarantine_partial_state()
        else:
            backup = None
        result = Installer(self.paths, run=self.run).install(
            artifact, expected_digest,
            configuration_mode=configuration_mode or "managed")
        return {**result, "kind": "bootstrap", "action": "installed",
                "recoveredOperations": recovered, "quarantineBackup": backup}

    def rollback(self) -> dict[str, object]:
        install = self._installation(); old, target = str(install["activeReleaseId"]), install.get("previousReleaseId")
        if not isinstance(target, str): raise InstallError("no previous release is available for rollback")
        manifest = self._release_manifest(target); self._compatible(manifest, install)
        identity = {"releaseId": target,
                    "artifactSha256": manifest["artifactSha256"]}
        return self._transition("rollback", None, None, identity, manifest, install, old, {"kind": "rollback"}, candidate=target)

    def uninstall(self) -> dict[str, object]:
        """Restore startup ownership, then remove only installed manager payload."""
        install = self._installation()
        if self._interrupted_operations():
            raise InstallError("an interrupted operation blocks uninstallation")
        releases = [str(item) for item in install["installedReleaseIds"]]
        self._verify_uninstall_ownership(install, releases)
        operation = self.paths.operations / f"uninstall-{uuid.uuid4().hex}"
        operation.mkdir(parents=True, mode=0o700)
        _atomic_json(operation / "plan.json", {"schema": 1, "operationId": operation.name, "kind": "uninstall", "releaseIds": releases})
        (operation / "events.jsonl").touch(mode=0o600); self._checkpoint(operation, "prepared")
        try:
            adapter = self.paths.manager_current / "scripts/startupctl.sh"
            response = self._adapter(adapter, ["plan", "--action", "remove"])
            startup = response.get("plan")
            if startup is not None:
                if not isinstance(startup, dict) or not isinstance(startup.get("planId"), str):
                    raise InstallError("startup adapter refused removal plan")
                stored = operation / "startup-plan.json"; _atomic_json(stored, startup)
                self._checkpoint(operation, "startup-remove")
                response = self._adapter(adapter, ["remove", "--plan-file", str(stored), "--plan-id", str(startup["planId"])])
                if response.get("status") not in ("completed", "unchanged") or response.get("state") != "unmanaged":
                    raise InstallError("startup adapter did not restore the prior host configuration")
            self._checkpoint(operation, "startup-removed")
            self._remove_terminal_integrations()
            self._remove_uninstall_payload(releases)
            self._terminal(operation, "completed", None)
            # Keep user state and named backups intact. Completed operation
            # journals are the only manager state discarded after their terminal
            # result is durable.
            self.cleanup()
            return {"kind": "uninstall", "status": "completed", "removedReleaseIds": releases}
        except Exception as error:
            self._event(operation, "failed", {"reason": str(error)})
            self._checkpoint(operation, "failed")
            raise InstallError(f"uninstall failed: {error}") from error

    def cleanup(self) -> dict[str, object]:
        """Prune only terminal manager journals; releases stay under retention."""
        if self._interrupted_operations():
            raise InstallError("an interrupted operation blocks cleanup")
        removed = 0
        if self.paths.operations.exists():
            for item in self.paths.operations.iterdir():
                if item.is_dir() and (item / "result.json").is_file():
                    _remove_tree(item); removed += 1
        return {"kind": "cleanup", "status": "completed", "removedOperationCount": removed}

    def recover(self, operation_id: str) -> dict[str, object]:
        operation = self.paths.operations / operation_id
        try:
            plan = json.loads((operation / "plan.json").read_text()); checkpoint = json.loads((operation / "checkpoint.json").read_text())
        except (OSError, json.JSONDecodeError) as error: raise InstallError("operation recovery record is invalid") from error
        if plan.get("schema") != 1 or plan.get("operationId") != operation_id: raise InstallError("operation recovery identity is invalid")
        if (operation / "result.json").is_file(): return {"kind": plan.get("kind"), "status": "completed", "operationId": operation_id}
        phase = checkpoint.get("phase")
        if phase == "committed":
            _atomic_json(operation / "result.json", {"schema": 1, "operationId": operation_id, "status": "completed"}); return {"kind": plan.get("kind"), "status": "completed", "operationId": operation_id}
        if phase == "verified":
            self._publish(plan); self._checkpoint(operation, "committed"); _atomic_json(operation / "result.json", {"schema": 1, "operationId": operation_id, "status": "completed"}); return {"kind": plan.get("kind"), "status": "completed", "operationId": operation_id}
        if phase == "prepared":
            self._clean_candidate(plan); self._terminal(operation, "compensated", "candidate was never activated"); return {"kind": plan.get("kind"), "status": "compensated", "operationId": operation_id}
        if phase in ("activation-pending", "activated"):
            self._restore_old(plan, operation); self._clean_candidate(plan); self._terminal(operation, "compensated", "restored previous release"); return {"kind": plan.get("kind"), "status": "compensated", "operationId": operation_id}
        # Compatibility with first-install journals at every durable checkpoint.
        if plan.get("kind") == "install" and phase in ("prepare", "adapter-plan"):
            self._clean_first_install(plan); self._terminal(operation, "compensated", "first-install operation had not started startup"); return {"kind": plan.get("kind"), "status": "compensated", "operationId": operation_id}
        if plan.get("kind") == "install" and phase in ("adapter-apply", "activate"):
            return self._recover_first_install(plan, operation)
        raise InstallError("operation checkpoint drift is refused without mutation")

    def _transition(self, kind, artifact, digest, identity, manifest, install, old,
                    source, *, candidate=None, configuration_mode=None):
        candidate = candidate or str(identity["releaseId"]); opid = f"{kind}-{uuid.uuid4().hex}"; operation = self.paths.operations / opid
        if self.paths.operations.exists() and any(p.is_dir() and not (p / "result.json").is_file() for p in self.paths.operations.iterdir()): raise InstallError("an interrupted operation blocks mutation")
        created_shell = created_manager = False
        if artifact is not None:
            shell, manager = self.paths.shell_releases / candidate, self.paths.manager_releases / candidate
            if shell.exists() != manager.exists(): raise InstallError("candidate release directory drift")
            created_shell = created_manager = not shell.exists()
        plan = {"schema": 1, "operationId": opid, "kind": kind, "artifact": {**identity, "source": source}, "oldShellReleaseId": old, "newShellReleaseId": candidate, "oldManagerReleaseId": old, "newManagerReleaseId": candidate, "createdShellDirectory": created_shell, "createdManagerDirectory": created_manager, "priorStartupReceiptId": install.get("startup", {}).get("receipt", {}).get("receiptId") if isinstance(install.get("startup"), dict) else None, "startupPlan": "startup-plan.json"}
        operation.mkdir(parents=True, mode=0o700); _atomic_json(operation / "plan.json", plan); (operation / "events.jsonl").touch(mode=0o600); self._checkpoint(operation, "prepared")
        try:
            if artifact is not None and created_shell:
                staged = operation / "artifact.ody"; shutil.copyfile(artifact, staged)
                if verify(staged, digest) != identity: raise InstallError("staged artifact identity changed during copy")
                self._place(staged, digest, candidate, manifest)
            adapter = self.paths.manager_releases / old / "scripts/startupctl.sh"
            adapter_args = ["plan", "--action", "retarget",
                "--release-id", candidate, "--release-root",
                str(self.paths.shell_releases / candidate)]
            if configuration_mode is not None:
                adapter_args.extend(["--configuration-mode", configuration_mode])
            response = self._adapter(adapter, adapter_args)
            startup = response.get("plan")
            if response.get("status") != "ready" or not isinstance(startup, dict) or not isinstance(startup.get("planId"), str): raise InstallError("startup adapter refused retarget plan")
            stored = operation / "startup-plan.json"; _atomic_json(stored, startup); self._checkpoint(operation, "activation-pending")
            _atomic_link(self.paths.shell_current, f"releases/{candidate}")
            _atomic_link(self.paths.manager_current, f"releases/{candidate}")
            _atomic_link(self.paths.bin_command, str(self.paths.manager_current / "odyssey"))
            self._checkpoint(operation, "activated")
            response = self._adapter(adapter, ["retarget", "--plan-file", str(stored), "--plan-id", str(startup["planId"])])
            if response.get("status") not in ("completed", "unchanged"): raise InstallError("startup adapter did not retarget")
            if not self._healthy(candidate): raise InstallError("candidate did not satisfy exact startup health")
            self._checkpoint(operation, "verified"); self._publish(plan); self._checkpoint(operation, "committed"); self._terminal(operation, "completed", None); self._retain(plan)
            return {"kind": kind, "status": "completed", "operationId": opid,
                    "releaseId": candidate, "version": str(manifest["version"])}
        except Exception as error:
            try: self._restore_old(plan, operation); self._clean_candidate(plan); self._terminal(operation, "compensated", str(error))
            except Exception: self._event(operation, "compensation-failed", {"reason": str(error)})
            raise InstallError(f"{kind} failed: {error}") from error

    def _place(self, artifact, digest, release_id, manifest):
        shell, manager = self.paths.shell_releases / release_id, self.paths.manager_releases / release_id
        if shell.exists() != manager.exists(): raise InstallError("candidate release directory drift")
        if shell.exists(): return False, False
        stage = self.paths.shell_releases.parent / f".stage-{uuid.uuid4().hex}"; self._extract(artifact, stage)
        (stage / "shell" / "release.json").write_bytes(json.dumps(manifest, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode() + b"\n")
        self.paths.shell_releases.mkdir(parents=True, exist_ok=True); self.paths.manager_releases.mkdir(parents=True, exist_ok=True)
        shutil.move(str(stage / "shell"), shell); shutil.move(str(stage / "manager"), manager); _remove_tree(stage); _immutable(shell); _immutable(manager); return True, True

    def _healthy(self, release_id):
        deadline = time.monotonic() + 10
        while True:
            evidence = self.report().get("evidence", {})
            startup = evidence.get("startup", {}); units = evidence.get("units", {}); instances = evidence.get("instances", {}); notes = evidence.get("notifications", {})
            unit = units.get("value", {}).get("odyssey.service", {}) if isinstance(units, dict) else {}
            live = instances.get("value", {}).get("instances", []) if isinstance(instances, dict) else []
            matching = [item for item in live if item.get("odyssey")]
            ok = startup.get("status") == "valid" and startup.get("value", {}).get("state") == "active" and units.get("status") == "valid" and unit.get("ActiveState") == "active" and str(unit.get("MainPID", "0")).isdigit() and int(unit.get("MainPID", "0")) > 0 and len(matching) == 1 and notes.get("status") == "valid" and notes.get("value", {}).get("odysseyMatch") is True
            if ok: return True
            if time.monotonic() >= deadline: return False
            time.sleep(.1)

    def _publish(self, plan):
        old, new = plan["oldShellReleaseId"], plan["newShellReleaseId"]; manifest = self._release_manifest(new)
        record = {"schema": 1, "installationId": plan["operationId"], "installedReleaseIds": [new, old], "activeReleaseId": new, "previousReleaseId": old, "dataSchemaVersion": manifest["dataSchemaVersion"], "operationId": plan["operationId"], "artifact": plan["artifact"], "startup": {"adapter": "odyssey-startup", "adapterVersion": 3}}
        _atomic_json(self.paths.install_manifest, record)
        _atomic_link(self.paths.manager_current, f"releases/{plan['newManagerReleaseId']}")
        _atomic_link(self.paths.bin_command, str(self.paths.manager_current / "odyssey"))

    def _restore_old(self, plan, operation):
        old = plan["oldShellReleaseId"]; oldroot = self.paths.shell_releases / old
        if not oldroot.is_dir(): raise InstallError("previous release is missing")
        oldmanager = self.paths.manager_releases / str(plan["oldManagerReleaseId"])
        adapter = oldmanager / "scripts/startupctl.sh"; response = self._adapter(adapter, ["plan", "--action", "retarget", "--release-id", old, "--release-root", str(oldroot)])
        start = response.get("plan")
        if not isinstance(start, dict) or not isinstance(start.get("planId"), str): raise InstallError("old-release retarget plan refused")
        fallback = operation / "restore-plan.json"; _atomic_json(fallback, start); response = self._adapter(adapter, ["retarget", "--plan-file", str(fallback), "--plan-id", str(start["planId"])])
        if response.get("status") not in ("completed", "unchanged"): raise InstallError("old-release retarget failed")
        _atomic_link(self.paths.shell_current, f"releases/{old}")
        _atomic_link(self.paths.manager_current, f"releases/{plan['oldManagerReleaseId']}")
        _atomic_link(self.paths.bin_command, str(self.paths.manager_current / "odyssey"))
        if not self._healthy(old): raise InstallError("previous release did not recover health")

    def _clean_candidate(self, plan):
        if plan.get("createdShellDirectory"): _remove_tree(self.paths.shell_releases / str(plan.get("newShellReleaseId")))
        if plan.get("createdManagerDirectory"): _remove_tree(self.paths.manager_releases / str(plan.get("newManagerReleaseId")))
    def _clean_first_install(self, plan):
        release = str(plan.get("releaseId", ""))
        shell = self.paths.shell_releases / release
        manager = self.paths.manager_releases / release
        if self.paths.bin_command.is_symlink():
            target = self.paths.bin_command.resolve(strict=False)
            if target == (manager / "odyssey").resolve(strict=False):
                self.paths.bin_command.unlink()
        for link, expected in ((self.paths.shell_current, shell),
                               (self.paths.manager_current, manager)):
            if link.is_symlink() and link.resolve(strict=False) == expected.resolve(strict=False):
                link.unlink()
        _remove_tree(self.paths.shell_releases.parent / f".stage-{plan.get('operationId', '')}")
        _remove_tree(shell); _remove_tree(manager)

    def _recover_first_install(self, plan, operation):
        release = str(plan.get("releaseId", ""))
        manager = self.paths.manager_releases / release
        adapter = manager / "scripts/startupctl.sh"
        if not adapter.is_file():
            self._clean_first_install(plan)
            self._terminal(operation, "compensated", "first-install startup was unavailable")
            return {"kind": "install", "status": "compensated", "operationId": operation.name}
        status = self._adapter(adapter, ["status"])
        state = status.get("state")
        owned = (state in ("active", "configured")
                 and isinstance(status.get("release"), dict)
                 and status["release"].get("id") == release)
        active = state == "active" and owned
        if active:
            if not self._release_pair_valid(release):
                raise InstallError("first-install recovery release pair is invalid")
            for link, expected in (
                    (self.paths.shell_current, self.paths.shell_releases / release),
                    (self.paths.manager_current, manager),
                    (self.paths.bin_command, manager / "odyssey")):
                if link.exists() or link.is_symlink():
                    if not link.is_symlink() or link.resolve(strict=False) != expected.resolve(strict=False):
                        raise InstallError("first-install recovery found foreign activation state")
            _atomic_link(self.paths.manager_current, f"releases/{release}")
            _atomic_link(self.paths.bin_command, str(self.paths.manager_current / "odyssey"))
            _atomic_link(self.paths.shell_current, f"releases/{release}")
            manifest = self._release_manifest(release)
            artifact = plan.get("artifact", {})
            identity = {key: artifact[key] for key in
                        ("releaseId", "artifactSha256", "containerSha256")
                        if isinstance(artifact, dict) and key in artifact}
            record = {"schema": 1, "installationId": plan["operationId"],
                      "installedReleaseIds": [release], "activeReleaseId": release,
                      "previousReleaseId": None,
                      "dataSchemaVersion": manifest["dataSchemaVersion"],
                      "operationId": plan["operationId"], "artifact": identity,
                      "startup": {"adapter": "odyssey-startup", "adapterVersion": 3,
                                  "receipt": status.get("receipt")}}
            _atomic_json(self.paths.install_manifest, record)
            self._checkpoint(operation, "committed")
            self._terminal(operation, "completed", None)
            return {"kind": "install", "status": "completed", "operationId": operation.name,
                    "releaseId": release}
        startup_plan = operation / str(plan.get("startupPlan", "startup-plan.json"))
        if owned:
            response = self._adapter(adapter, ["plan", "--action", "remove"])
            removal = response.get("plan")
            if not isinstance(removal, dict) or not isinstance(removal.get("planId"), str):
                raise InstallError("first-install startup removal plan was refused")
            removal_file = operation / "recovery-remove-plan.json"
            _atomic_json(removal_file, removal)
            response = self._adapter(adapter, ["remove", "--plan-file", str(removal_file),
                                               "--plan-id", str(removal["planId"])])
            if (response.get("status") not in ("completed", "unchanged")
                    or response.get("state") != "unmanaged"):
                raise InstallError("first-install startup removal failed")
        elif state == "partial" and startup_plan.is_file():
            try:
                plan_id = str(json.loads(startup_plan.read_text())["planId"])
                self._adapter(adapter, ["compensate", "--plan-file", str(startup_plan),
                                        "--plan-id", plan_id])
            except (OSError, KeyError, json.JSONDecodeError):
                raise InstallError("first-install startup recovery plan is invalid")
        elif state != "unmanaged":
            raise InstallError("first-install startup ownership is ambiguous")
        self._clean_first_install(plan)
        self._terminal(operation, "compensated", "first-install startup was not active")
        return {"kind": "install", "status": "compensated", "operationId": operation.name}
    def _interrupted_operations(self):
        return self.paths.operations.exists() and any(path.is_dir() and not (path / "result.json").is_file() for path in self.paths.operations.iterdir())
    def _interrupted_operation_paths(self):
        if not self.paths.operations.exists(): return []
        return sorted((path for path in self.paths.operations.iterdir()
                       if path.is_dir() and not (path / "result.json").is_file()), key=lambda p: p.name)
    def _valid_installation_or_none(self):
        if not self.paths.install_manifest.is_file(): return None
        try:
            raw = json.loads(self.paths.install_manifest.read_text())
            return raw if parse_installation_manifest(raw).status == "valid" else None
        except (OSError, json.JSONDecodeError):
            return None
    def _release_pair_valid(self, release_id):
        try:
            return (self.paths.shell_releases / release_id).is_dir() and (self.paths.manager_releases / release_id).is_dir() and self._release_manifest(release_id)["releaseId"] == release_id
        except (InstallError, OSError, ValueError):
            return False
    def _has_lifecycle_state(self):
        return any(path.exists() or path.is_symlink() for path in (
            self.paths.install_manifest, self.paths.shell_releases.parent,
            self.paths.manager_releases.parent, self.paths.bin_command))
    def _quarantine_partial_state(self):
        if self.paths.bin_command.exists() and not self.paths.bin_command.is_symlink():
            raise InstallError(f"partial installation contains a foreign command at {self.paths.bin_command}; move it and rerun")
        if self.paths.bin_command.is_symlink():
            target = self.paths.bin_command.resolve(strict=False)
            manager_root = self.paths.manager_releases.parent.resolve(strict=False)
            if not target.is_relative_to(manager_root):
                raise InstallError(f"partial installation contains a foreign command link at {self.paths.bin_command}; move it and rerun")
        backup = self.paths.install_manifest.parent.parent / "bootstrap-backups" / f"bootstrap-partial-{uuid.uuid4().hex}"
        backup.mkdir(parents=True, mode=0o700)
        targets = ((self.paths.shell_releases.parent, backup / "data-odyssey"),
                   (self.paths.install_manifest.parent, backup / "manager-state"),
                   (self.paths.bin_command, backup / "odyssey-command"))
        for source, destination in targets:
            if not (source.exists() or source.is_symlink()): continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(source), str(destination))
        _atomic_json(backup / "receipt.json", {"schema": 1, "kind": "bootstrap-partial-backup"})
        return str(backup)
    def _repair_activation_links(self, release_id):
        for path, owned_root in ((self.paths.shell_current, self.paths.shell_releases),
                                 (self.paths.manager_current, self.paths.manager_releases)):
            if path.exists() and not path.is_symlink():
                raise InstallError(f"activation path is not Odyssey-owned: {path}")
            if path.is_symlink() and not path.resolve(strict=False).is_relative_to(
                    owned_root.resolve(strict=False)):
                raise InstallError(f"activation link is not Odyssey-owned: {path}")
        if self.paths.bin_command.exists() and not self.paths.bin_command.is_symlink():
            raise InstallError(f"stable command is not Odyssey-owned: {self.paths.bin_command}")
        if self.paths.bin_command.is_symlink():
            launcher_target = self.paths.bin_command.resolve(strict=False)
            manager_root = self.paths.manager_releases.resolve(strict=False)
            stable = os.readlink(self.paths.bin_command) == str(
                self.paths.manager_current / "odyssey")
            if not stable and not launcher_target.is_relative_to(manager_root):
                raise InstallError(f"stable command link is not Odyssey-owned: {self.paths.bin_command}")
        _atomic_link(self.paths.shell_current, f"releases/{release_id}")
        _atomic_link(self.paths.manager_current, f"releases/{release_id}")
        _atomic_link(self.paths.bin_command, str(self.paths.manager_current / "odyssey"))
    def _require_consistent_activation(self, install):
        release_id = str(install["activeReleaseId"])
        expected = (
            (self.paths.shell_current, self.paths.shell_releases / release_id),
            (self.paths.manager_current, self.paths.manager_releases / release_id),
        )
        for link, target in expected:
            if (not link.is_symlink()
                    or link.resolve(strict=False) != target.resolve(strict=False)):
                raise InstallError("lifecycle activation is inconsistent; run odyssey repair first")
        launcher = str(self.paths.manager_current / "odyssey")
        if (not self.paths.bin_command.is_symlink()
                or os.readlink(self.paths.bin_command) != launcher):
            raise InstallError("stable launcher drift requires odyssey repair first")
    def _validate_runtime(self):
        report = self.dependencies()
        errors = report.get("errors", [])
        if errors:
            raise InstallError(str(errors[0]))
        missing = report.get("missingPackages", [])
        if missing:
            raise InstallError("required runtime dependencies are unavailable: "
                               + ", ".join(str(item) for item in missing))
    def _backup_managed_config(self):
        config = self.paths.policy.parent
        state = self.paths.install_manifest.parent.parent
        home = Path(os.environ.get("HOME", str(config.parent)))
        targets = [
            config / "hypr/hyprland.lua", config / "hypr/odyssey.lua",
            *(config / "hypr/config" / name for name in (
                "animations.lua", "appearance.lua", "environment.lua", "input.lua",
                "keybinds.lua", "layouts.lua", "monitors.lua", "startup.lua",
                "window-rules.lua")),
            config / "kitty/kitty.conf", config / "starship.toml",
            config / "fastfetch/config.jsonc", config / "hypr/hypridle.conf",
            config / "systemd/user/odyssey.service",
            config / "systemd/user/hypridle.service",
            home / ".bashrc", home / ".zshrc", config / "fish/config.fish",
            state / "startup/session-startup.json", state / "startup/pending.json",
            state / "installer/host-config.json", state / "terminal-integrations.json",
            state / "kitty-theme.json", state / "starship-theme.json",
            state / "fastfetch-theme.json", state / "theme-exports",
        ]
        root = state / "backups"
        root.mkdir(parents=True, exist_ok=True)
        backup = root / f"odyssey-config-reset-{uuid.uuid4().hex}"
        backup.mkdir(mode=0o700)
        indexed: list[str] = []
        for index, target in enumerate(targets):
            if not (target.exists() or target.is_symlink()):
                continue
            destination = backup / f"{index:02d}-{target.name}.bak"
            if target.is_dir() and not target.is_symlink():
                shutil.copytree(target, destination, symlinks=True)
            else:
                shutil.copy2(target, destination, follow_symlinks=False)
            indexed.append(str(target))
        index_file = backup / ".odyssey-backup-index"
        index_file.write_text("".join(f"{target}\n" for target in indexed),
                              encoding="utf-8")
        os.chmod(index_file, 0o600)
        return backup
    def _reapply_startup(self, release_id, configuration_mode=None):
        adapter = self.paths.manager_releases / release_id / "scripts" / "startupctl.sh"
        status = self._adapter(adapter, ["status"])
        receipt = status.get("receipt")
        action = "retarget" if isinstance(receipt, dict) and receipt.get("status") == "valid" else "apply"
        adapter_args = ["plan", "--action", action,
            "--release-id", release_id, "--release-root",
            str(self.paths.shell_releases / release_id)]
        if configuration_mode is not None:
            adapter_args.extend(["--configuration-mode", configuration_mode])
        response = self._adapter(adapter, adapter_args)
        plan = response.get("plan")
        if not isinstance(plan, dict) or not isinstance(plan.get("planId"), str):
            raise InstallError("startup repair plan was refused")
        with tempfile.TemporaryDirectory(prefix="odyssey-startup-repair-") as raw:
            stored = Path(raw) / "plan.json"; _atomic_json(stored, plan)
            response = self._adapter(adapter, [action, "--plan-file", str(stored), "--plan-id", str(plan["planId"])])
        if response.get("status") not in ("completed", "unchanged"):
            raise InstallError("startup repair did not complete")
    def _verify_uninstall_ownership(self, install, releases):
        active = str(install["activeReleaseId"]); expected_shell = self.paths.shell_releases / active
        if not expected_shell.is_dir() or expected_shell.is_symlink() or not self.paths.shell_current.is_symlink() or self.paths.shell_current.resolve() != expected_shell.resolve():
            raise InstallError("shell activation drift is refused without mutation")
        if not self.paths.manager_current.is_symlink() or self.paths.manager_current.resolve().parent != self.paths.manager_releases.resolve() or self.paths.manager_current.resolve().name not in releases:
            raise InstallError("manager activation drift is refused without mutation")
        expected_command = self.paths.manager_current / "odyssey"
        if not self.paths.bin_command.is_symlink() or self.paths.bin_command.resolve() != expected_command.resolve():
            raise InstallError("stable command drift is refused without mutation")
        for release in releases:
            shell, manager = self.paths.shell_releases / release, self.paths.manager_releases / release
            if not shell.is_dir() or shell.is_symlink() or not manager.is_dir() or manager.is_symlink():
                raise InstallError("managed release payload drift is refused without mutation")
            manifest = self._release_manifest(release)
            if manifest["releaseId"] != release or not (manager / "scripts" / "startupctl.sh").is_file():
                raise InstallError("managed release identity is invalid")
    def _remove_uninstall_payload(self, releases):
        for path in (self.paths.bin_command, self.paths.shell_current, self.paths.manager_current): path.unlink()
        for release in releases:
            _remove_tree(self.paths.shell_releases / release); _remove_tree(self.paths.manager_releases / release)
        self.paths.install_manifest.unlink()
    def _remove_terminal_integrations(self):
        """Remove only terminal integrations explicitly recorded by install.sh."""
        receipt = self.paths.install_manifest.parent.parent / "terminal-integrations.json"
        if not receipt.is_file() or receipt.is_symlink():
            return
        helper = self.paths.shell_current / "scripts" / "terminal-integrations.sh"
        result = self.run([str(helper), "disable"])
        if result.code != 0:
            detail = result.err.strip() or result.out.strip() or "unknown failure"
            raise InstallError("terminal integration cleanup refused: " + detail)
    def _retain(self, plan):
        """After durable publication, retain only the two releases named by it."""
        keep = {str(plan["oldShellReleaseId"]), str(plan["newShellReleaseId"])}
        protected = set()
        if self.paths.operations.exists():
            for op in self.paths.operations.iterdir():
                if not op.is_dir() or (op / "result.json").is_file(): continue
                try: protected.update(value for value in json.loads((op / "plan.json").read_text()).values() if isinstance(value, str))
                except (OSError, json.JSONDecodeError): continue
        for root in (self.paths.shell_releases, self.paths.manager_releases):
            if root.exists():
                for release in root.iterdir():
                    if release.name not in keep and release.name not in protected: _remove_tree(release)
    def _terminal(self, operation, status, reason):
        self._event(operation, status, {} if reason is None else {"reason": reason}); _atomic_json(operation / "result.json", {"schema": 1, "operationId": operation.name, "status": status, **({} if reason is None else {"reason": reason})})
    def _verify(self, artifact, digest):
        try: return verify(artifact, digest)
        except ValueError as error: raise InstallError(str(error)) from error
    def _installation(self):
        try: raw = json.loads(self.paths.install_manifest.read_text())
        except (OSError, json.JSONDecodeError) as error: raise InstallError("valid existing installation is required") from error
        parsed = parse_installation_manifest(raw)
        if parsed.status != "valid": raise InstallError("installation record is invalid")
        return raw
    def _release_manifest(self, release):
        try: raw = json.loads((self.paths.shell_releases / release / "release.json").read_text())
        except (OSError, json.JSONDecodeError) as error: raise InstallError("release manifest is unavailable") from error
        if parse_release_manifest(raw).status != "valid": raise InstallError("release manifest is invalid")
        return raw
    def _compatible(self, manifest, install):
        compat = manifest["managerCompatibility"]
        if compat["maximumContractSchema"] < CONTRACT_SCHEMA_VERSION or self._version(MANAGER_VERSION) < self._version(compat["minimumVersion"]): raise InstallError("candidate manager compatibility is unsupported")
        if manifest["dataSchemaVersion"] != install["dataSchemaVersion"]: raise InstallError("candidate data schema is unsupported")
    def _version(self, value): return tuple(int(x) if x.isdigit() else 0 for x in value.split("-")[0].split("."))
