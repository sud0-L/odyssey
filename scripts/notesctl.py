#!/usr/bin/env python3
"""Atomic, file-per-note storage for Odyssey Notes."""

from __future__ import annotations

import json
import os
import re
import sys
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path


NOTE_ID = re.compile(r"^[a-f0-9]{32}$")
HEADER = re.compile(
    r'^---\nodyssey-note: 1\ntitle: (?P<title>[^\n]+)\n'
    r'updated: (?P<updated>[^\n]+)\n---\n',
)


def notes_dir() -> Path:
    data_home = os.environ.get("XDG_DATA_HOME")
    if not data_home:
        data_home = str(Path.home() / ".local" / "share")
    return Path(data_home) / "odyssey" / "notes"


def ensure_dir() -> Path:
    directory = notes_dir()
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    return directory


def note_path(note_id: str) -> Path:
    if not NOTE_ID.fullmatch(note_id):
        raise ValueError("Invalid note identifier")
    return ensure_dir() / f"{note_id}.md"


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace(
        "+00:00", "Z"
    )


def render(title: str, content: str, updated: str) -> str:
    clean_title = title.replace("\r", " ").replace("\n", " ").strip()
    return (
        "---\n"
        "odyssey-note: 1\n"
        f"title: {json.dumps(clean_title, ensure_ascii=False)}\n"
        f"updated: {json.dumps(updated)}\n"
        "---\n"
        f"{content}"
    )


def parse(path: Path) -> dict[str, str]:
    raw = path.read_text(encoding="utf-8")
    match = HEADER.match(raw)
    if match:
        try:
            title = json.loads(match.group("title"))
            updated = json.loads(match.group("updated"))
            if not isinstance(title, str) or not isinstance(updated, str):
                raise ValueError
            content = raw[match.end() :]
        except (json.JSONDecodeError, ValueError):
            title, content, updated = path.stem, raw, ""
    else:
        title, content, updated = path.stem, raw, ""
    if not updated:
        updated = datetime.fromtimestamp(
            path.stat().st_mtime, timezone.utc
        ).isoformat(timespec="milliseconds").replace("+00:00", "Z")
    return {"id": path.stem, "title": title, "content": content, "updated": updated}


def atomic_write(path: Path, text: str) -> None:
    descriptor, temporary = tempfile.mkstemp(
        dir=path.parent, prefix=f".{path.stem}.", suffix=".tmp"
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def emit(value: object) -> None:
    print(json.dumps(value, ensure_ascii=False, separators=(",", ":")))


def read_payload() -> dict[str, object]:
    value = json.loads(sys.stdin.readline())
    if not isinstance(value, dict):
        raise ValueError("Invalid note payload")
    return value


def save(note_id: str, payload: dict[str, object]) -> dict[str, str]:
    title = payload.get("title", "")
    content = payload.get("content", "")
    if not isinstance(title, str) or not isinstance(content, str):
        raise ValueError("Invalid note payload")
    if len(title) > 500 or len(content.encode("utf-8")) > 16 * 1024 * 1024:
        raise ValueError("Note is too large")
    timestamp = now()
    path = note_path(note_id)
    atomic_write(path, render(title, content, timestamp))
    return parse(path)


def main(argv: list[str]) -> int:
    command = argv[1] if len(argv) > 1 else ""
    if command == "list" and len(argv) == 2:
        directory = ensure_dir()
        notes = []
        for path in directory.glob("*.md"):
            if NOTE_ID.fullmatch(path.stem) and path.is_file() and not path.is_symlink():
                try:
                    notes.append(parse(path))
                except (OSError, UnicodeError):
                    continue
        notes.sort(key=lambda note: note["updated"], reverse=True)
        emit({"notes": notes})
        return 0
    if command == "create" and len(argv) == 2:
        note_id = uuid.uuid4().hex
        emit(save(note_id, {"title": "", "content": ""}))
        return 0
    if command == "save" and len(argv) == 3:
        emit(save(argv[2], read_payload()))
        return 0
    if command == "delete" and len(argv) == 3:
        path = note_path(argv[2])
        try:
            path.unlink()
        except FileNotFoundError:
            pass
        emit({"deleted": argv[2]})
        return 0
    raise ValueError("usage: notesctl.py {list|create|save ID|delete ID}")


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
