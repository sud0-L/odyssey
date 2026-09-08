"""Deterministic Stage 3 Odyssey release artifact construction and validation."""
from __future__ import annotations

import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import struct
import tarfile
import tempfile
from typing import Any, Mapping

from manager import CONTRACT_SCHEMA_VERSION, MANAGER_VERSION
from manager.contracts import parse_release_manifest, safe_payload_path
from manager.inventory import packaged_inventory

HASH_DOMAIN = "odyssey-release-v1"


def canonical_json(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False,
                       allow_nan=False) + "\n").encode("utf-8")


def _tar_bytes(members: list[tuple[str, bytes | str, int, bool]]) -> bytes:
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w", format=tarfile.USTAR_FORMAT) as archive:
        for name, content, mode, link in members:
            info = tarfile.TarInfo(name)
            info.uid = info.gid = info.mtime = 0
            info.uname = info.gname = ""
            info.mode = 0o777 if link else mode
            if link:
                info.type = tarfile.SYMTYPE
                info.linkname = str(content)
                info.size = 0
                archive.addfile(info)
            else:
                data = bytes(content)
                info.type = tarfile.REGTYPE
                info.size = len(data)
                archive.addfile(info, io.BytesIO(data))
    return output.getvalue()


def _mode(path: Path) -> int:
    return 0o755 if path.stat().st_mode & 0o111 else 0o644


def _payload(root: Path) -> tuple[bytes, list[dict[str, object]]]:
    manifest: list[dict[str, object]] = []
    members: list[tuple[str, bytes | str, int, bool]] = []
    for item in packaged_inventory(root):
        component, relative = item["component"], item["path"]
        source = root / relative
        archive_path = f"{component}/{relative}"
        if source.is_symlink():
            target = os.readlink(source)
            if not safe_payload_path(target) or not _safe_link(component, relative, target):
                raise ValueError(f"unsafe packaged symbolic link: {archive_path}")
            manifest.append({"component": component, "path": relative, "category": item["category"],
                             "type": "symlink", "mode": 0o777, "target": target})
            members.append((archive_path, target, 0o777, True))
        else:
            data = source.read_bytes()
            mode = _mode(source)
            manifest.append({"component": component, "path": relative, "category": item["category"],
                             "type": "file", "mode": mode, "size": len(data),
                             "sha256": hashlib.sha256(data).hexdigest()})
            members.append((archive_path, data, mode, False))
    members.sort(key=lambda member: member[0].encode("utf-8"))
    manifest.sort(key=lambda item: (str(item["component"]).encode("utf-8"), str(item["path"]).encode("utf-8")))
    return _tar_bytes(members), manifest


def _safe_link(component: str, path: str, target: str) -> bool:
    resolved = PurePosixPath(component) / PurePosixPath(path).parent / PurePosixPath(target)
    return resolved.parts and resolved.parts[0] == component and ".." not in resolved.parts


def _digest(manifest: Mapping[str, object], payload: bytes) -> str:
    projection = dict(manifest)
    projection.pop("releaseId", None)
    projection.pop("artifactSha256", None)
    data = canonical_json(projection)
    digest = hashlib.sha256()
    digest.update(HASH_DOMAIN.encode("ascii") + b"\0")
    digest.update(struct.pack(">Q", len(data)))
    digest.update(data)
    digest.update(struct.pack(">Q", len(payload)))
    digest.update(payload)
    return digest.hexdigest()


def build(root: Path, version: str) -> tuple[bytes, dict[str, object]]:
    payload, entries = _payload(root.resolve())
    manifest: dict[str, object] = {
        "schema": 1, "product": "odyssey", "version": version,
        "releaseId": "", "artifactSha256": "", "artifactHashDomain": HASH_DOMAIN,
        "managerCompatibility": {"minimumVersion": MANAGER_VERSION.split("-", 1)[0],
                                  "maximumContractSchema": CONTRACT_SCHEMA_VERSION},
        "dataSchemaVersion": 1, "migrations": [], "capabilities": [], "dependencies": [],
        "payload": entries,
    }
    digest = _digest(manifest, payload)
    manifest["artifactSha256"] = digest
    manifest["releaseId"] = f"{version}-{digest}"
    release = canonical_json(manifest)
    artifact = _tar_bytes([("release.json", release, 0o644, False), ("payload.tar", payload, 0o644, False)])
    return artifact, manifest


def write_build(root: Path, version: str, output: Path) -> dict[str, object]:
    if output.exists() or output.is_symlink():
        raise ValueError(f"refusing to overwrite artifact: {output}")
    artifact, manifest = build(root, version)
    output.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{output.name}.", dir=output.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(artifact); stream.flush(); os.fsync(stream.fileno())
        os.replace(temporary, output)
    except Exception:
        try: os.unlink(temporary)
        except FileNotFoundError: pass
        raise
    return _identity(manifest, artifact)


def _read_canonical_tar(data: bytes, expected: list[str] | None = None) -> list[tarfile.TarInfo]:
    try:
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:") as archive:
            members = archive.getmembers()
            contents: list[tuple[str, bytes | str, int, bool]] = []
            for member in members:
                if member.pax_headers or member.islnk() or member.isdev() or member.isfifo() or member.isdir() or not (member.isfile() or member.issym()):
                    raise ValueError("archive has a forbidden member type or extension")
                if member.uid or member.gid or member.uname or member.gname or member.mtime or member.mode != 0o644:
                    raise ValueError("archive header is not canonical")
                if member.issym(): contents.append((member.name, member.linkname, 0o777, True))
                else:
                    extracted = archive.extractfile(member)
                    if extracted is None: raise ValueError("archive regular member is unreadable")
                    contents.append((member.name, extracted.read(), 0o644, False))
    except (tarfile.TarError, OSError) as error:
        raise ValueError(f"invalid tar archive: {error}") from error
    if expected is not None and [member.name for member in members] != expected:
        raise ValueError("archive members are not the canonical required sequence")
    if _tar_bytes(contents) != data:
        raise ValueError("archive framing or header metadata is not canonical")
    return members


def _inner_members(payload: bytes) -> list[tuple[tarfile.TarInfo, bytes | str]]:
    try:
        with tarfile.open(fileobj=io.BytesIO(payload), mode="r:") as archive:
            raw = archive.getmembers(); rebuilt: list[tuple[str, bytes | str, int, bool]] = []; result = []
            names: list[str] = []
            for member in raw:
                if member.pax_headers or member.islnk() or member.isdev() or member.isfifo() or member.isdir() or not (member.isfile() or member.issym()): raise ValueError("payload has a forbidden member type or extension")
                if member.uid or member.gid or member.uname or member.gname or member.mtime: raise ValueError("payload header is not canonical")
                if not member.name.startswith(("shell/", "manager/")) or not safe_payload_path(member.name.split("/", 1)[1]): raise ValueError("payload has an unsafe namespace path")
                if member.name in names: raise ValueError("payload has duplicate paths")
                names.append(member.name)
                if member.issym():
                    if member.mode != 0o777 or not safe_payload_path(member.linkname) or not _safe_link(member.name.split("/", 1)[0], member.name.split("/", 1)[1], member.linkname): raise ValueError("payload has an unsafe symbolic link")
                    value: bytes | str = member.linkname; rebuilt.append((member.name, value, 0o777, True))
                else:
                    if member.mode not in (0o644, 0o755): raise ValueError("payload file mode is invalid")
                    stream = archive.extractfile(member)
                    if stream is None: raise ValueError("payload file is unreadable")
                    value = stream.read(); rebuilt.append((member.name, value, member.mode, False))
                result.append((member, value))
    except (tarfile.TarError, OSError) as error: raise ValueError(f"invalid payload archive: {error}") from error
    if names != sorted(names, key=lambda name: name.encode("utf-8")) or _tar_bytes(rebuilt) != payload: raise ValueError("payload ordering or framing is not canonical")
    return result


def _identity(manifest: Mapping[str, object], artifact: bytes) -> dict[str, object]:
    return {"version": manifest["version"], "releaseId": manifest["releaseId"], "artifactSha256": manifest["artifactSha256"], "containerSha256": hashlib.sha256(artifact).hexdigest()}


def verify(path: Path, expected_digest: str | None = None) -> dict[str, object]:
    try: data = path.read_bytes()
    except OSError as error: raise ValueError(f"cannot read artifact: {error}") from error
    outer = _read_canonical_tar(data, ["release.json", "payload.tar"])
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:") as archive:
        release = archive.extractfile(outer[0]).read()  # type: ignore[union-attr]
        payload = archive.extractfile(outer[1]).read()  # type: ignore[union-attr]
    try: parsed = json.loads(release.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error: raise ValueError("release manifest is not UTF-8 JSON") from error
    if canonical_json(parsed) != release: raise ValueError("release manifest JSON is not canonical")
    evidence = parse_release_manifest(parsed)
    if evidence.status != "valid": raise ValueError(evidence.reason or "release manifest is invalid")
    assert evidence.value is not None
    manifest = evidence.value
    computed = _digest(manifest, payload)
    if computed != manifest["artifactSha256"] or expected_digest is not None and computed != expected_digest: raise ValueError("artifact digest does not match independent identity")
    members = _inner_members(payload)
    listed = manifest["payload"]
    actual: list[dict[str, object]] = []
    for member, value in members:
        component, relative = member.name.split("/", 1)
        entry: dict[str, object] = {"component": component, "path": relative, "type": "symlink" if member.issym() else "file", "mode": member.mode}
        if member.issym(): entry["target"] = value
        else: entry.update({"size": len(value), "sha256": hashlib.sha256(value).hexdigest()})  # type: ignore[arg-type]
        actual.append(entry)
    expected = [{key: value for key, value in item.items() if key != "category"} for item in listed]  # type: ignore[union-attr]
    if actual != expected: raise ValueError("payload contents do not match release manifest")
    return _identity(manifest, data)
