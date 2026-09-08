#!/usr/bin/env python3
"""Safely manage Odyssey's one Starship named-palette block.

The Starship configuration remains user-owned.  This tool only changes a
root-level palette selection it recorded itself and the bytes between its two
explicit managed markers.  It deliberately refuses ambiguous ownership.
"""

import argparse
import json
import os
import re
import stat
import sys
import tempfile
from pathlib import Path


OPEN = "# >>> ODYSSEY MANAGED PALETTE >>>"
CLOSE = "# <<< ODYSSEY MANAGED PALETTE <<<"
STATE_VERSION = 1
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
TABLE = re.compile(r"^[ \t]*\[(?:[^\]]+)\][ \t]*(?:#.*)?$", re.MULTILINE)
ODYSSEY_TABLE = re.compile(
    r"^[ \t]*\[palettes[ \t]*\.[ \t]*(?:odyssey|\"odyssey\"|'odyssey')\][ \t]*(?:#.*)?$",
    re.MULTILINE)
ROOT_PALETTE = re.compile(r"^[ \t]*palette[ \t]*=[^\r\n]*(?:\r?\n|$)", re.MULTILINE)
PALETTE_MAPPING = (
    ("primary", "primary"), ("secondary", "secondary"),
    ("tertiary", "tertiary"), ("foreground", "onSurface"),
    ("muted", "onSurfaceVariant"), ("background", "surface"),
    ("surface", "surfaceContainer"), ("surface_low", "surfaceContainerLow"),
    ("surface_high", "surfaceContainerHigh"), ("on_primary", "onPrimary"),
    ("on_primary_container", "onPrimaryContainer"), ("border", "outline"),
    ("border_muted", "outlineVariant"), ("error", "error"),
    ("warning", "warning"), ("success", "success"),
)


class Refusal(Exception):
    pass


def roots():
    home_value = os.environ.get("HOME", "")
    if not home_value:
        raise Refusal("HOME is required")
    home = Path(home_value).expanduser()
    config_root = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    state_root = Path(os.environ.get("XDG_STATE_HOME", home / ".local/state"))
    return config_root / "starship.toml", state_root / "odyssey" / "starship-theme.json"


def atomic_write(path, text, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".%s." % path.name, dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def read_config(path):
    if not path.is_file() or path.is_symlink():
        raise Refusal("Starship config must be an existing regular file: %s" % path)
    return path.read_text(encoding="utf-8", newline="")


def load_state(path):
    if not path.is_file() or path.is_symlink():
        return None
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise Refusal("Odyssey Starship state is unreadable: %s" % error) from error
    if state.get("version") != STATE_VERSION:
        raise Refusal("Odyssey Starship state has an unsupported version")
    return state


def write_state(path, state):
    atomic_write(path, json.dumps(state, indent=2, sort_keys=True) + "\n", 0o600)


def marker_range(text):
    starts = [match.start() for match in re.finditer(re.escape(OPEN), text)]
    ends = [match.start() for match in re.finditer(re.escape(CLOSE), text)]
    if not starts and not ends:
        return None
    if len(starts) != 1 or len(ends) != 1 or starts[0] >= ends[0]:
        raise Refusal("conflicting Odyssey managed-palette markers")
    end = text.find("\n", ends[0])
    return starts[0], len(text) if end < 0 else end + 1


def assert_no_conflicting_palette(text, managed):
    entries = list(ODYSSEY_TABLE.finditer(text))
    if not entries:
        return
    if managed is None:
        raise Refusal("existing [palettes.odyssey] is user-owned; refusing to replace it")
    start, end = managed
    if any(match.start() < start or match.start() >= end for match in entries):
        raise Refusal("conflicting [palettes.odyssey] definition outside Odyssey block")
    if len(entries) != 1:
        raise Refusal("conflicting [palettes.odyssey] definitions")


def root_palette_lines(text):
    first_table = TABLE.search(text)
    prefix_end = first_table.start() if first_table else len(text)
    return [match for match in ROOT_PALETTE.finditer(text[:prefix_end])]


def palette_block(palette_path, mode):
    if mode not in {"dark", "light"}:
        raise Refusal("theme mode must be dark or light")
    try:
        document = json.loads(Path(palette_path).read_text(encoding="utf-8"))
        colors = document[mode]
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        raise Refusal("active Odyssey palette is invalid: %s" % error) from error
    values = {}
    for name, token in PALETTE_MAPPING:
        value = colors.get(token)
        if not isinstance(value, str) or not HEX.fullmatch(value):
            raise Refusal("active Odyssey palette is missing a valid %s token" % token)
        values[name] = value.lower()
    lines = [OPEN, "[palettes.odyssey]"]
    lines.extend("%s = %s" % (name, json.dumps(value))
                 for name, value in values.items())
    lines.append(CLOSE)
    return "\n".join(lines) + "\n"


def replace_range(text, bounds, replacement):
    return text[:bounds[0]] + replacement + text[bounds[1]:]


def config_mode(path):
    return stat.S_IMODE(path.stat().st_mode)


def enable(config_path, state_path, palette_path, mode):
    text = read_config(config_path)
    managed = marker_range(text)
    assert_no_conflicting_palette(text, managed)
    state = load_state(state_path)
    if state is not None:
        if managed is None:
            raise Refusal("Odyssey state exists but its managed block is missing")
        return refresh(config_path, state_path, palette_path, mode)
    if managed is not None:
        raise Refusal("Odyssey managed markers exist without Odyssey state")
    palette_lines = root_palette_lines(text)
    if len(palette_lines) > 1:
        raise Refusal("multiple root-level palette selections; refusing to guess")
    selection = {"kind": "inserted", "original": ""}
    if palette_lines:
        line = palette_lines[0]
        selection = {"kind": "replaced", "original": text[line.start():line.end()]}
        text = text[:line.start()] + 'palette = "odyssey"\n' + text[line.end():]
    else:
        text = 'palette = "odyssey"\n' + text
    prefix = "\n" if text.endswith("\n") else "\n\n"
    text += prefix + palette_block(palette_path, mode)
    atomic_write(config_path, text, config_mode(config_path))
    write_state(state_path, {"version": STATE_VERSION, "selection": selection,
                             "blockPrefix": prefix})
    print("STARSHIP=enabled")


def refresh(config_path, state_path, palette_path, mode):
    state = load_state(state_path)
    if state is None:
        print("STARSHIP=disabled")
        return
    text = read_config(config_path)
    managed = marker_range(text)
    if managed is None:
        raise Refusal("Odyssey state exists but its managed block is missing")
    assert_no_conflicting_palette(text, managed)
    palette_lines = root_palette_lines(text)
    if len(palette_lines) != 1 or 'palette = "odyssey"' not in palette_lines[0].group(0):
        raise Refusal("Odyssey palette selection changed or is ambiguous")
    atomic_write(config_path, replace_range(text, managed, palette_block(palette_path, mode)),
                 config_mode(config_path))
    print("STARSHIP=refreshed")


def disable(config_path, state_path):
    state = load_state(state_path)
    if state is None:
        print("STARSHIP=disabled")
        return
    text = read_config(config_path)
    managed = marker_range(text)
    if managed is None:
        raise Refusal("Odyssey state exists but its managed block is missing")
    assert_no_conflicting_palette(text, managed)
    prefix = state.get("blockPrefix")
    if prefix not in {"\n", "\n\n"} or text[max(0, managed[0] - len(prefix)):managed[0]] != prefix:
        raise Refusal("Odyssey managed block boundary changed; refusing to remove it")
    text = text[:managed[0] - len(prefix)] + text[managed[1]:]
    palette_lines = root_palette_lines(text)
    if len(palette_lines) != 1 or 'palette = "odyssey"' not in palette_lines[0].group(0):
        raise Refusal("Odyssey palette selection changed or is ambiguous")
    selection = state.get("selection", {})
    if selection.get("kind") == "replaced":
        text = text[:palette_lines[0].start()] + selection.get("original", "") + text[palette_lines[0].end():]
    elif selection.get("kind") == "inserted":
        text = text[:palette_lines[0].start()] + text[palette_lines[0].end():]
    else:
        raise Refusal("Odyssey Starship state has an invalid selection record")
    atomic_write(config_path, text, config_mode(config_path))
    state_path.unlink()
    print("STARSHIP=disabled")


def status(config_path, state_path):
    state = load_state(state_path)
    if state is None:
        print("STARSHIP=disabled")
        return
    text = read_config(config_path)
    managed = marker_range(text)
    assert_no_conflicting_palette(text, managed)
    print("STARSHIP=enabled" if managed is not None else "STARSHIP=invalid")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("status", "enable", "refresh", "disable"))
    parser.add_argument("palette", nargs="?")
    parser.add_argument("mode", nargs="?")
    arguments = parser.parse_args()
    if arguments.action in {"enable", "refresh"} and (not arguments.palette or not arguments.mode):
        parser.error("enable and refresh require PALETTE MODE")
    config_path, state_path = roots()
    if arguments.action == "enable":
        enable(config_path, state_path, arguments.palette, arguments.mode)
    elif arguments.action == "refresh":
        refresh(config_path, state_path, arguments.palette, arguments.mode)
    elif arguments.action == "disable":
        disable(config_path, state_path)
    else:
        status(config_path, state_path)


if __name__ == "__main__":
    try:
        main()
    except Refusal as error:
        print("Odyssey Starship integration refused: %s" % error, file=sys.stderr)
        raise SystemExit(3)
