"""Strict, side-effect-free JSON contracts used by later lifecycle stages."""
from __future__ import annotations

from dataclasses import dataclass
import copy
import json
import re
from pathlib import PurePosixPath
from typing import Any, Mapping

from manager import CONTRACT_SCHEMA_VERSION
from manager.versioning import parse_public_version

_DIGEST = re.compile(r"^[0-9a-f]{64}$")
_RELEASE_ID = re.compile(r"^(.+)-([0-9a-f]{64})$")
_IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.+_-]*$")
_RELEASE_FIELDS = {"schema", "product", "version", "releaseId", "artifactSha256",
                   "artifactHashDomain", "managerCompatibility", "dataSchemaVersion",
                   "migrations", "capabilities", "dependencies", "payload"}


@dataclass(frozen=True)
class Evidence:
    status: str
    value: Mapping[str, Any] | None = None
    reason: str | None = None

    def as_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {"status": self.status}
        if self.value is not None:
            result["value"] = copy.deepcopy(dict(self.value))
        if self.reason is not None:
            result["reason"] = self.reason
        return result


def safe_payload_path(value: object) -> bool:
    if not isinstance(value, str) or not value or "\x00" in value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and all(part not in ("", ".", "..") for part in path.parts)


def _record(raw: object, kind: str) -> Evidence:
    if raw is None:
        return Evidence("absent", reason=f"{kind} record is absent")
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except json.JSONDecodeError:
            return Evidence("invalid", reason=f"{kind} JSON is malformed")
    if not isinstance(raw, Mapping):
        return Evidence("invalid", reason=f"{kind} record must be an object")
    schema = raw.get("schema")
    if not isinstance(schema, int) or isinstance(schema, bool) or schema < 1:
        return Evidence("invalid", reason=f"{kind} schema is invalid")
    if schema > CONTRACT_SCHEMA_VERSION:
        return Evidence("unsupported", reason=f"{kind} schema {schema} is newer than supported")
    return Evidence("valid", value=raw)


def parse_release_manifest(raw: object) -> Evidence:
    base = _record(raw, "release manifest")
    if base.status != "valid":
        return base
    assert base.value is not None
    record = base.value
    if set(record) != _RELEASE_FIELDS or record.get("schema") != 1 or record.get("product") != "odyssey" or record.get("artifactHashDomain") != "odyssey-release-v1":
        return Evidence("invalid", reason="release manifest schema fields are invalid")
    version, release_id, digest, payload = (record.get(key) for key in ("version", "releaseId", "artifactSha256", "payload"))
    match = _RELEASE_ID.fullmatch(release_id) if isinstance(release_id, str) else None
    try:
        parse_public_version(version)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return Evidence("invalid", reason="release manifest public version is invalid")
    if not isinstance(version, str) or not match or not isinstance(digest, str) or not _DIGEST.fullmatch(digest):
        return Evidence("invalid", reason="release manifest identity is invalid")
    if match.group(1) != version or match.group(2) != digest:
        return Evidence("invalid", reason="release ID does not bind version and artifact digest")
    compatibility = record.get("managerCompatibility")
    if not isinstance(compatibility, Mapping) or set(compatibility) != {"minimumVersion", "maximumContractSchema"} or not isinstance(compatibility.get("minimumVersion"), str) or not _IDENTIFIER.fullmatch(compatibility["minimumVersion"]) or not isinstance(compatibility.get("maximumContractSchema"), int) or isinstance(compatibility["maximumContractSchema"], bool) or compatibility["maximumContractSchema"] < 1:
        return Evidence("invalid", reason="release manifest manager compatibility is invalid")
    if not isinstance(record.get("dataSchemaVersion"), int) or isinstance(record["dataSchemaVersion"], bool) or record["dataSchemaVersion"] < 1:
        return Evidence("invalid", reason="release manifest data schema is invalid")
    for key in ("migrations", "capabilities", "dependencies"):
        values = record.get(key)
        if not isinstance(values, list) or any(not isinstance(value, str) or not _IDENTIFIER.fullmatch(value) for value in values) or values != sorted(set(values), key=lambda value: value.encode("utf-8")):
            return Evidence("invalid", reason=f"release manifest {key} are invalid")
    if not isinstance(payload, list):
        return Evidence("invalid", reason="release manifest payload must be a list")
    seen: set[tuple[str, str]] = set()
    for entry in payload:
        if not isinstance(entry, Mapping) or entry.get("component") not in ("shell", "manager") or not safe_payload_path(entry.get("path")) or not isinstance(entry.get("category"), str) or not entry["category"]:
            return Evidence("invalid", reason="release manifest has an unsafe payload path")
        key = (entry["component"], entry["path"])
        if key in seen:
            return Evidence("invalid", reason="release manifest has duplicate payload paths")
        seen.add(key)
        entry_type = entry.get("type")
        if entry_type not in ("file", "symlink"):
            return Evidence("invalid", reason="release manifest payload type is invalid")
        mode = entry.get("mode")
        if not isinstance(mode, int) or isinstance(mode, bool) or (mode != 0o777 if entry_type == "symlink" else mode not in (0o644, 0o755)):
            return Evidence("invalid", reason="release manifest payload mode is invalid")
        if entry_type == "symlink":
            target = entry.get("target")
            if set(entry) != {"component", "path", "category", "type", "mode", "target"} or not safe_payload_path(target) or target.startswith("../"):
                return Evidence("invalid", reason="release manifest has an escaping link")
        elif set(entry) != {"component", "path", "category", "type", "mode", "size", "sha256"} or not isinstance(entry.get("size"), int) or isinstance(entry["size"], bool) or entry["size"] < 0 or not isinstance(entry.get("sha256"), str) or not _DIGEST.fullmatch(entry["sha256"]):
            return Evidence("invalid", reason="release manifest regular payload entry is invalid")
    if payload != sorted(payload, key=lambda item: (item["component"].encode("utf-8"), item["path"].encode("utf-8"))):
        return Evidence("invalid", reason="release manifest payload is not sorted")
    return Evidence("valid", value=record)


def parse_installation_manifest(raw: object) -> Evidence:
    base = _record(raw, "installation manifest")
    if base.status != "valid":
        return base
    assert base.value is not None
    record = base.value
    installation_id = record.get("installationId")
    releases = record.get("installedReleaseIds")
    active = record.get("activeReleaseId")
    previous = record.get("previousReleaseId")
    data_schema = record.get("dataSchemaVersion")
    if not isinstance(installation_id, str) or not installation_id:
        return Evidence("invalid", reason="installation manifest identity is invalid")
    if not isinstance(releases, list) or not releases or any(not isinstance(item, str) or not _RELEASE_ID.fullmatch(item) for item in releases) or len(set(releases)) != len(releases):
        return Evidence("invalid", reason="installation manifest release IDs are invalid")
    if active is not None and (not isinstance(active, str) or active not in releases):
        return Evidence("invalid", reason="installation manifest active release is invalid")
    if previous is not None and (not isinstance(previous, str) or previous not in releases or previous == active):
        return Evidence("invalid", reason="installation manifest previous release is invalid")
    if not isinstance(data_schema, int) or isinstance(data_schema, bool) or data_schema < 1:
        return Evidence("invalid", reason="installation manifest data schema is invalid")
    return base


def parse_ownership_receipt(raw: object) -> Evidence:
    return _parse_identity_record(raw, "ownership receipt", ("category", "target"))


def parse_operation_plan(raw: object) -> Evidence:
    return _parse_identity_record(raw, "operation plan", ("operationId",))


def parse_operation_checkpoint(raw: object) -> Evidence:
    return _parse_identity_record(raw, "operation checkpoint", ("operationId", "phase"))


def parse_operation_event(raw: object) -> Evidence:
    return _parse_identity_record(raw, "operation event", ("operationId", "event"))


def parse_operation_result(raw: object) -> Evidence:
    base = _parse_identity_record(raw, "operation result", ("operationId", "status"))
    if base.status != "valid":
        return base
    assert base.value is not None
    if base.value.get("status") not in ("completed", "compensated", "failed"):
        return Evidence("invalid", reason="operation result status is invalid")
    return base


def parse_backup_set(raw: object) -> Evidence:
    return _parse_identity_record(raw, "backup set", ("backupId",))


def _parse_identity_record(raw: object, kind: str, required: tuple[str, ...]) -> Evidence:
    base = _record(raw, kind)
    if base.status != "valid":
        return base
    assert base.value is not None
    if any(not isinstance(base.value.get(field), str) or not base.value[field] for field in required):
        return Evidence("invalid", reason=f"{kind} identity is invalid")
    return base
