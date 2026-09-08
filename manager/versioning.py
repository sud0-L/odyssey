"""Canonical Odyssey public-version loading and comparison."""
from __future__ import annotations

import re
from pathlib import Path

_PUBLIC_VERSION = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-([0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*))?$"
)


def parse_public_version(value: str) -> tuple[int, int, int, tuple[tuple[int, object], ...]]:
    if re.search(r"-[0-9a-f]{64}$", value):
        raise ValueError("immutable release identity is not a public version")
    match = _PUBLIC_VERSION.fullmatch(value)
    if match is None:
        raise ValueError(f"invalid Odyssey public version: {value}")
    prerelease = match.group(4)
    if prerelease is None:
        suffix: tuple[tuple[int, object], ...] = ((2, ""),)
    else:
        suffix = tuple(
            (0, int(part)) if part.isdigit() else (1, part.lower())
            for part in re.split(r"[.-]", prerelease)
        )
    return int(match.group(1)), int(match.group(2)), int(match.group(3)), suffix


def compare_public_versions(left: str, right: str) -> int:
    first, second = parse_public_version(left), parse_public_version(right)
    return (first > second) - (first < second)


def canonical_version(root: Path | None = None) -> str:
    source = (root or Path(__file__).resolve().parent.parent) / "VERSION"
    try:
        value = source.read_text(encoding="utf-8").strip()
    except OSError as error:
        raise RuntimeError("canonical Odyssey VERSION is unavailable") from error
    parse_public_version(value)
    return value
