#!/usr/bin/env python3
"""Safely apply Odyssey's generated Fastfetch accent to existing visual fields.

Fastfetch has no config-fragment include.  This opt-in helper therefore records
the complete original JSONC bytes privately, edits only existing title/header/
divider format escapes and named visual colour fields, and refuses refresh or
cleanup if the managed config has drifted.
"""

import argparse
import base64
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path


STATE_VERSION = 1
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
COLOR_FIELD = re.compile(
    r'(?P<prefix>"(?:keyColor|titleColor|separatorColor)"\s*:\s*)'
    r'"(?:\\.|[^"\\])*"')
FORMAT_FIELD = re.compile(
    r'(?P<prefix>"format"\s*:\s*")(?P<value>(?:\\.|[^"\\])*)(?P<suffix>")')
FORMAT_COLOR = re.compile(r"\{##[0-9a-fA-F]{6}\}")


class Refusal(Exception):
    pass


def paths():
    home_value = os.environ.get("HOME", "")
    if not home_value:
        raise Refusal("HOME is required")
    home = Path(home_value).expanduser()
    config_root = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    state_root = Path(os.environ.get("XDG_STATE_HOME", home / ".local/state"))
    return (config_root / "fastfetch" / "config.jsonc",
            state_root / "odyssey" / "theme-exports" / "fastfetch.json",
            state_root / "odyssey" / "fastfetch-theme.json")


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
        raise Refusal("Fastfetch config must be an existing regular file: %s" % path)
    return path.read_text(encoding="utf-8", newline="")


def config_mode(path):
    return stat.S_IMODE(path.stat().st_mode)


def digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def load_state(path):
    if not path.exists() and not path.is_symlink():
        return None
    if not path.is_file() or path.is_symlink():
        raise Refusal("Odyssey Fastfetch state is not a regular file")
    try:
        result = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise Refusal("Odyssey Fastfetch state is unreadable: %s" % error) from error
    if result.get("version") != STATE_VERSION:
        raise Refusal("Odyssey Fastfetch state has an unsupported version")
    original = result.get("original")
    managed_digest = result.get("managedDigest")
    if not isinstance(original, str) or not isinstance(managed_digest, str):
        raise Refusal("Odyssey Fastfetch state is incomplete")
    try:
        base64.b64decode(original, validate=True).decode("utf-8")
    except (ValueError, UnicodeDecodeError) as error:
        raise Refusal("Odyssey Fastfetch state has an invalid baseline") from error
    return result


def original_text(state):
    return base64.b64decode(state["original"], validate=True).decode("utf-8")


def theme_accent(path):
    if not path.is_file() or path.is_symlink():
        raise Refusal("generated Fastfetch theme is unavailable")
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise Refusal("generated Fastfetch theme is invalid: %s" % error) from error
    accent = document.get("accent")
    if document.get("version") != 1 or not isinstance(accent, str) or not HEX.fullmatch(accent):
        raise Refusal("generated Fastfetch theme has no valid accent")
    return accent.lower()


def transform(text, accent):
    changes = 0

    def replace_field(match):
        nonlocal changes
        changes += 1
        return match.group("prefix") + json.dumps(accent)

    def replace_format(match):
        nonlocal changes
        value, count = FORMAT_COLOR.subn("{##%s}" % accent[1:], match.group("value"))
        changes += count
        return match.group("prefix") + value + match.group("suffix")

    transformed = COLOR_FIELD.sub(replace_field, text)
    transformed = FORMAT_FIELD.sub(replace_format, transformed)
    return transformed, changes


def validate_config(config_path, candidate, mode):
    fastfetch = shutil.which("fastfetch")
    if not fastfetch:
        raise Refusal("Fastfetch is unavailable")
    descriptor, temporary = tempfile.mkstemp(prefix=".%s.odyssey-check." % config_path.stem,
                                            suffix=".jsonc", dir=config_path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
            handle.write(candidate)
        os.chmod(temporary, mode)
        result = subprocess.run([fastfetch, "--config", temporary, "--pipe", "true"],
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                                text=True, timeout=8, check=False)
        if result.returncode != 0:
            message = result.stderr.strip() or "Fastfetch rejected the configuration"
            raise Refusal("Fastfetch config validation failed: %s" % message)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise Refusal("Fastfetch config validation could not run: %s" % error) from error
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def write_state(path, original, managed):
    state = {
        "version": STATE_VERSION,
        "original": base64.b64encode(original.encode("utf-8")).decode("ascii"),
        "managedDigest": digest(managed),
    }
    atomic_write(path, json.dumps(state, indent=2, sort_keys=True) + "\n", 0o600)


def enable(config_path, theme_path, state_path):
    if not shutil.which("fastfetch"):
        print("FASTFETCH=unavailable")
        return
    text = read_config(config_path)
    existing = load_state(state_path)
    if existing is not None:
        refresh(config_path, theme_path, state_path)
        return
    accent = theme_accent(theme_path)
    managed, changes = transform(text, accent)
    if changes == 0:
        raise Refusal("Fastfetch config has no supported visual color fields")
    validate_config(config_path, managed, config_mode(config_path))
    atomic_write(config_path, managed, config_mode(config_path))
    try:
        write_state(state_path, text, managed)
    except BaseException:
        atomic_write(config_path, text, config_mode(config_path))
        raise
    print("FASTFETCH=enabled")


def refresh(config_path, theme_path, state_path):
    state = load_state(state_path)
    if state is None:
        print("FASTFETCH=disabled")
        return
    text = read_config(config_path)
    if digest(text) != state["managedDigest"]:
        raise Refusal("Fastfetch config changed outside Odyssey; refusing to overwrite it")
    accent = theme_accent(theme_path)
    baseline = original_text(state)
    managed, changes = transform(baseline, accent)
    if changes == 0:
        raise Refusal("Odyssey Fastfetch baseline has no supported visual color fields")
    validate_config(config_path, managed, config_mode(config_path))
    atomic_write(config_path, managed, config_mode(config_path))
    write_state(state_path, baseline, managed)
    print("FASTFETCH=refreshed")


def disable(config_path, _theme_path, state_path):
    state = load_state(state_path)
    if state is None:
        print("FASTFETCH=disabled")
        return
    text = read_config(config_path)
    if digest(text) != state["managedDigest"]:
        raise Refusal("Fastfetch config changed outside Odyssey; refusing to restore over it")
    baseline = original_text(state)
    validate_config(config_path, baseline, config_mode(config_path))
    atomic_write(config_path, baseline, config_mode(config_path))
    state_path.unlink()
    print("FASTFETCH=disabled")


def status(config_path, _theme_path, state_path):
    state = load_state(state_path)
    if state is None:
        print("FASTFETCH=disabled")
        return
    text = read_config(config_path)
    print("FASTFETCH=enabled" if digest(text) == state["managedDigest"] else "FASTFETCH=invalid")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("status", "enable", "refresh", "disable"))
    arguments = parser.parse_args()
    config_path, theme_path, state_path = paths()
    if arguments.action == "enable":
        enable(config_path, theme_path, state_path)
    elif arguments.action == "refresh":
        refresh(config_path, theme_path, state_path)
    elif arguments.action == "disable":
        disable(config_path, theme_path, state_path)
    else:
        status(config_path, theme_path, state_path)


if __name__ == "__main__":
    try:
        main()
    except Refusal as error:
        print("Odyssey Fastfetch integration refused: %s" % error, file=sys.stderr)
        raise SystemExit(3)
