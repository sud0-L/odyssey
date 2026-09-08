"""CLI for the bounded Odyssey lifecycle manager."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from manager import CONTRACT_SCHEMA_VERSION, MANAGER_VERSION
from manager.artifact import verify, write_build
from manager.inventory import discover_dependencies, discover_platform, resolve_xdg, source_identity, source_inventory
from manager.install import InstallError, Installer
from manager.lifecycle import Lifecycle
from manager.acquire import AcquireError, acquire, default_url
from manager.dependencies import ArchDependencies, DependencyError
from manager.reconcile import Reconciler, findings

RESERVED = ("backup", "restore", "startup", "component")
UNAVAILABLE_EXIT = 69


def confirm(message: str) -> bool:
    sys.stderr.write(f"{message} [y/N] ")
    sys.stderr.flush()
    answer = sys.stdin.readline()
    return answer.strip().lower() in ("y", "yes") if answer else False


def emit(payload: dict[str, object], as_json: bool) -> None:
    if as_json:
        print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
        return
    if payload.get("status") == "unavailable":
        print(f"odyssey: {payload['command']} is unavailable in this release")
        return
    if payload.get("kind") == "version":
        print(f"Odyssey manager {payload['managerVersion']} (contract schema {payload['contractSchema']})")
        print(f"Source identity: {payload['source']['sourceId'][:24]}")
        return
    if payload.get("kind") in ("status", "doctor"):
        print(f"Odyssey {payload['kind']}: {payload['summary']['state']}")
        for finding in payload.get("findings", []): print(f"{finding['severity']}: {finding['code']}: {finding['message']}")
        return
    if payload.get("kind") == "artifact":
        print(f"Artifact {payload['action']}: {payload['releaseId']}")
        return
    if payload.get("kind") in ("install", "bootstrap", "update", "rollback", "repair", "config-reset", "uninstall", "cleanup"):
        print(f"Odyssey {payload['kind']}: {payload.get('releaseId', payload.get('status'))}")
        return
    if payload.get("kind") == "dependencies":
        if not payload["supported"]:
            print("Odyssey dependencies: Arch Linux with pacman is required for automatic installation")
            return
        missing = payload["missingPackages"]
        if missing:
            print("Odyssey dependencies missing: " + ", ".join(missing))
            print("Run: odyssey dependencies --install --yes")
        else:
            print("Odyssey dependencies: ready")
        return
    print("Odyssey preflight (read-only)")
    print(f"Platform: {payload['platform']['id']} ({payload['platform']['packageManager']})")
    print(f"Payload entries: {len(payload['sourcePayload'])}")
    for key, value in payload["paths"].items():
        print(f"{key}: {value}")


def version_payload() -> dict[str, object]:
    inventory = source_inventory(ROOT)
    return {"kind": "version", "managerVersion": MANAGER_VERSION, "contractSchema": CONTRACT_SCHEMA_VERSION, "source": source_identity(ROOT, inventory)}


def preflight_payload() -> dict[str, object]:
    inventory = source_inventory(ROOT)
    return {"kind": "preflight", "readOnly": True, "paths": resolve_xdg().as_dict(), "platform": discover_platform(), "dependencies": discover_dependencies(), "source": source_identity(ROOT, inventory), "sourcePayload": inventory}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="odyssey", description="Odyssey lifecycle manager")
    parser.add_argument("command", nargs="?", choices=("version", "preflight", "status", "doctor", "artifact", "dependencies", "bootstrap", "install", "update", "rollback", "repair", "config", "uninstall", "cleanup", *RESERVED), help="read-only report or reserved lifecycle command")
    parser.add_argument("--json", action="store_true", dest="as_json", help="emit stable JSON")
    args, tail = parser.parse_known_args(argv)
    if args.command is None:
        parser.print_help()
        return 0
    if args.command == "artifact":
        artifact_parser = argparse.ArgumentParser(prog="odyssey artifact")
        subparsers = artifact_parser.add_subparsers(dest="action", required=True)
        build_parser = subparsers.add_parser("build")
        build_parser.add_argument("--version", required=True)
        build_parser.add_argument("--output", required=True, type=Path)
        build_parser.add_argument("--source-root", type=Path, default=ROOT)
        build_parser.add_argument("--json", action="store_true", dest="as_json")
        verify_parser = subparsers.add_parser("verify")
        verify_parser.add_argument("file", type=Path)
        verify_parser.add_argument("--expect-sha256")
        verify_parser.add_argument("--json", action="store_true", dest="as_json")
        artifact_args = artifact_parser.parse_args(tail)
        try:
            payload = write_build(artifact_args.source_root, artifact_args.version, artifact_args.output) if artifact_args.action == "build" else verify(artifact_args.file, artifact_args.expect_sha256)
        except (ValueError, OSError) as error:
            if artifact_args.as_json or args.as_json: print(json.dumps({"status": "invalid", "reason": str(error)}, sort_keys=True, separators=(",", ":")))
            else: print(f"odyssey: artifact {artifact_args.action} failed: {error}", file=sys.stderr)
            return 65
        payload = {"kind": "artifact", "action": artifact_args.action, **payload}
        emit(payload, artifact_args.as_json or args.as_json)
        return 0
    if args.command == "dependencies":
        dependency_parser = argparse.ArgumentParser(prog="odyssey dependencies")
        dependency_parser.add_argument("--install", action="store_true", help="install missing official Arch packages")
        dependency_parser.add_argument("--optional", action="store_true", help="install a selected optional official Arch package class")
        dependency_parser.add_argument("--optional-class", choices=("optional-power-profile", "optional-zsh"), help="limit optional installation to one feature class")
        dependency_parser.add_argument("--yes", action="store_true", help="confirm the fixed pacman package set")
        dependency_parser.add_argument("--json", action="store_true", dest="as_json")
        dependency_args = dependency_parser.parse_args(tail)
        try:
            manager = ArchDependencies()
            if dependency_args.optional and not dependency_args.install:
                dependency_parser.error("--optional requires --install")
            if dependency_args.optional and not dependency_args.optional_class:
                dependency_parser.error("--optional requires --optional-class")
            if dependency_args.optional_class and not dependency_args.optional:
                dependency_parser.error("--optional-class requires --optional")
            payload = manager.install(confirmed=dependency_args.yes, optional=dependency_args.optional,
                                      optional_class=dependency_args.optional_class) if dependency_args.install else manager.inspect()
        except DependencyError as error:
            payload = {"kind": "dependencies", "status": "failed", "reason": str(error)}
            if dependency_args.as_json or args.as_json:
                print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
            else:
                print(f"odyssey: dependencies failed: {error}", file=sys.stderr)
            return 65
        emit(payload, dependency_args.as_json or args.as_json)
        return 0
    if args.command in ("bootstrap", "install", "update"):
        install_parser = argparse.ArgumentParser(prog="odyssey install")
        install_parser.add_argument("--artifact", type=Path)
        install_parser.add_argument("--expect-sha256")
        install_parser.add_argument("--configuration-mode",
                                    choices=("managed", "preserve"))
        install_parser.add_argument("--json", action="store_true", dest="as_json")
        install_args = install_parser.parse_args(tail)
        if bool(install_args.artifact) != bool(install_args.expect_sha256):
            install_parser.error("--artifact and --expect-sha256 must be supplied together")
        if args.command == "update" and not confirm(
                "Update Odyssey and activate the validated candidate release?"):
            emit({"kind": "update", "status": "cancelled", "changed": False},
                 install_args.as_json or args.as_json)
            return 0
        if install_args.artifact is None:
            try: descriptor = default_url(ROOT)
            except AcquireError as error: descriptor = None; source_error = str(error)
            else: source_error = "no default HTTPS release descriptor is configured"
            if descriptor is None:
                payload = {"kind": args.command, "status": "unavailable", "reason": source_error}
                if install_args.as_json or args.as_json: print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
                else: emit({"status": "unavailable", "command": args.command, "reason": payload["reason"]}, False)
                return UNAVAILABLE_EXIT
            try:
                with tempfile.TemporaryDirectory(prefix="odyssey-acquire-") as raw:
                    file, digest, source = acquire(descriptor, Path(raw))
                    payload = (Installer(resolve_xdg()).install(file, digest,
                                   configuration_mode=install_args.configuration_mode or "managed")
                               if args.command == "install"
                               else Lifecycle(resolve_xdg()).bootstrap(file, digest,
                                   configuration_mode=install_args.configuration_mode)
                               if args.command == "bootstrap"
                               else Lifecycle(resolve_xdg()).update(file, digest, source=source,
                                   configuration_mode=install_args.configuration_mode))
            except (AcquireError, InstallError, OSError, ValueError) as error:
                payload = {"kind": args.command, "status": "failed", "reason": str(error)}
                if install_args.as_json or args.as_json: print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
                else: print(f"odyssey: {args.command} failed: {error}", file=sys.stderr)
                return 65
            emit(payload, install_args.as_json or args.as_json); return 0
        try:
            if args.command == "install":
                # Preserve the bounded first-install primitive.
                payload = Installer(resolve_xdg()).install(
                    install_args.artifact, install_args.expect_sha256,
                    configuration_mode=install_args.configuration_mode or "managed")
            elif args.command == "bootstrap":
                payload = Lifecycle(resolve_xdg()).bootstrap(
                    install_args.artifact, install_args.expect_sha256,
                    configuration_mode=install_args.configuration_mode)
            else:
                payload = Lifecycle(resolve_xdg()).update(
                    install_args.artifact, install_args.expect_sha256,
                    configuration_mode=install_args.configuration_mode)
        except (InstallError, OSError, ValueError) as error:
            payload = {"kind": args.command, "status": "failed", "reason": str(error)}
            if install_args.as_json or args.as_json: print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
            else: print(f"odyssey: {args.command} failed: {error}", file=sys.stderr)
            return 65
        emit(payload, install_args.as_json or args.as_json)
        return 0
    if args.command == "rollback":
        if not resolve_xdg().install_manifest.is_file():
            emit({"status": "unavailable", "command": "rollback", "reason": "no lifecycle installation exists"}, args.as_json); return UNAVAILABLE_EXIT
        rollback_parser = argparse.ArgumentParser(prog="odyssey rollback"); rollback_parser.add_argument("--json", action="store_true", dest="as_json")
        rollback_args = rollback_parser.parse_args(tail)
        try: payload = Lifecycle(resolve_xdg()).rollback()
        except (InstallError, OSError, ValueError) as error:
            payload = {"kind": "rollback", "status": "failed", "reason": str(error)}
            if rollback_args.as_json or args.as_json: print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
            else: print(f"odyssey: rollback failed: {error}", file=sys.stderr)
            return 65
        emit(payload, rollback_args.as_json or args.as_json); return 0
    if args.command == "repair":
        repair_parser = argparse.ArgumentParser(prog="odyssey repair"); repair_parser.add_argument("--recover"); repair_parser.add_argument("--json", action="store_true", dest="as_json")
        repair_args = repair_parser.parse_args(tail)
        if not confirm("Repair Odyssey operational and lifecycle state without resetting user configuration?"):
            emit({"kind": "repair", "status": "cancelled", "changed": False},
                 repair_args.as_json or args.as_json)
            return 0
        try: payload = Lifecycle(resolve_xdg()).repair(repair_args.recover)
        except (InstallError, OSError, ValueError) as error:
            payload = {"kind": "repair", "status": "failed", "reason": str(error)}
            if repair_args.as_json or args.as_json: print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
            else: print(f"odyssey: repair failed: {error}", file=sys.stderr)
            return 65
        emit(payload, repair_args.as_json or args.as_json); return 0
    if args.command == "config":
        config_parser = argparse.ArgumentParser(prog="odyssey config")
        config_parser.add_argument("action", choices=("reset",))
        config_parser.add_argument("--json", action="store_true", dest="as_json")
        config_args = config_parser.parse_args(tail)
        if not confirm("Replace Odyssey-managed configuration with packaged defaults after creating a backup?"):
            emit({"kind": "config-reset", "status": "cancelled", "changed": False},
                 config_args.as_json or args.as_json)
            return 0
        try: payload = Lifecycle(resolve_xdg()).config_reset()
        except (InstallError, OSError, ValueError) as error:
            payload = {"kind": "config-reset", "status": "failed", "reason": str(error)}
            if config_args.as_json or args.as_json:
                print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
            else:
                print(f"odyssey: config reset failed: {error}", file=sys.stderr)
            return 65
        emit(payload, config_args.as_json or args.as_json)
        return 0
    if args.command == "uninstall":
        uninstall_parser = argparse.ArgumentParser(prog="odyssey uninstall")
        uninstall_parser.add_argument("--yes", action="store_true", help="remove only manager-owned Odyssey payload and startup ownership")
        uninstall_parser.add_argument("--json", action="store_true", dest="as_json")
        uninstall_args = uninstall_parser.parse_args(tail)
        if not uninstall_args.yes:
            payload = {"kind": "uninstall", "status": "unavailable", "command": "uninstall", "reason": "explicit --yes is required; user settings and data are preserved"}
            emit(payload, uninstall_args.as_json or args.as_json)
            return UNAVAILABLE_EXIT
        if not resolve_xdg().install_manifest.is_file():
            emit({"kind": "uninstall", "status": "unavailable", "command": "uninstall", "reason": "no lifecycle installation exists"}, uninstall_args.as_json or args.as_json)
            return UNAVAILABLE_EXIT
        try: payload = Lifecycle(resolve_xdg()).uninstall()
        except (InstallError, OSError, ValueError) as error:
            payload = {"kind": "uninstall", "status": "failed", "reason": str(error)}
            if uninstall_args.as_json or args.as_json: print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
            else: print(f"odyssey: uninstall failed: {error}", file=sys.stderr)
            return 65
        emit(payload, uninstall_args.as_json or args.as_json)
        return 0
    if args.command == "cleanup":
        cleanup_parser = argparse.ArgumentParser(prog="odyssey cleanup")
        cleanup_parser.add_argument("--yes", action="store_true", help="remove only terminal lifecycle journals")
        cleanup_parser.add_argument("--json", action="store_true", dest="as_json")
        cleanup_args = cleanup_parser.parse_args(tail)
        if not cleanup_args.yes:
            emit({"kind": "cleanup", "status": "unavailable", "command": "cleanup", "reason": "explicit --yes is required; releases and user data are preserved"}, cleanup_args.as_json or args.as_json)
            return UNAVAILABLE_EXIT
        try: payload = Lifecycle(resolve_xdg()).cleanup()
        except (InstallError, OSError, ValueError) as error:
            payload = {"kind": "cleanup", "status": "failed", "reason": str(error)}
            if cleanup_args.as_json or args.as_json: print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
            else: print(f"odyssey: cleanup failed: {error}", file=sys.stderr)
            return 65
        emit(payload, cleanup_args.as_json or args.as_json)
        return 0
    if args.command in RESERVED:
        emit({"status": "unavailable", "command": args.command, "reason": "not implemented in this release"}, args.as_json)
        return UNAVAILABLE_EXIT
    if args.command in ("status", "doctor"):
        try:
            payload = Reconciler(resolve_xdg()).report()
            if args.command == "doctor":
                payload["kind"] = "doctor"
                payload["findings"] = findings(payload)
            emit(payload, args.as_json)
            return 1 if args.command == "doctor" and any(item["severity"] == "error" for item in payload.get("findings", [])) else 0
        except Exception:
            return 70
    emit(version_payload() if args.command == "version" else preflight_payload(), args.as_json)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
