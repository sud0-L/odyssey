#!/usr/bin/env python3
"""Opt-in, reversible Kitty inclusion for Odyssey's generated palette."""
import argparse, json, os, shutil, stat, subprocess, sys, tempfile
from pathlib import Path

STATE_VERSION = 1

class Refusal(Exception): pass

def paths():
    home = os.environ.get("HOME", "")
    if not home: raise Refusal("HOME is required")
    config = Path(os.environ.get("XDG_CONFIG_HOME", Path(home) / ".config"))
    state = Path(os.environ.get("XDG_STATE_HOME", Path(home) / ".local/state"))
    return config / "kitty" / "kitty.conf", state / "odyssey" / "theme-exports" / "kitty.conf", state / "odyssey" / "kitty-theme.json"

def write(path, text, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".%s." % path.name, dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            handle.write(text); handle.flush(); os.fsync(handle.fileno())
        os.chmod(temporary, mode); os.replace(temporary, path)
    except BaseException:
        try: os.unlink(temporary)
        except FileNotFoundError: pass
        raise

def config_text(path):
    return path.read_text(encoding="utf-8", newline="") if path.is_file() and not path.is_symlink() else None

def state(path):
    if not path.is_file() or path.is_symlink(): return None
    try: result = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error: raise Refusal("Kitty state is unreadable: %s" % error) from error
    if result.get("version") != STATE_VERSION: raise Refusal("Kitty state has an unsupported version")
    return result

def includes(text, theme):
    result = []
    for line in text.splitlines(keepends=True):
        fields = line.strip().split(None, 1)
        if len(fields) == 2 and fields[0] == "include" and fields[1] == str(theme): result.append(line)
    return result

def reload(config):
    kitty = shutil.which("kitty")
    if not kitty: return "unavailable"
    address = os.environ.get("KITTY_LISTEN_ON", "")
    if not address:
        for line in config.read_text(encoding="utf-8").splitlines():
            fields = line.strip().split(None, 1)
            if len(fields) == 2 and fields[0] == "listen_on" and fields[1].startswith("unix:"):
                address = fields[1]; break
    command = [kitty, "@"] + (["--to", address] if address else []) + ["load-config", str(config)]
    try: result = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3, check=False)
    except (OSError, subprocess.TimeoutExpired): return "failed"
    return "reloaded" if result.returncode == 0 else "failed"

def enable(config, theme, saved):
    if not shutil.which("kitty"): print("KITTY=unavailable"); return
    text = config_text(config)
    if text is None: print("KITTY=no-config"); return
    if not theme.is_file() or theme.is_symlink(): raise Refusal("generated Kitty theme is unavailable")
    existing, prior = includes(text, theme), state(saved)
    if len(existing) > 1: raise Refusal("duplicate Odyssey Kitty includes")
    if prior:
        if len(existing) != 1: raise Refusal("Kitty state exists but its include is missing")
        print("KITTY=enabled RELOAD=%s" % reload(config)); return
    if existing: raise Refusal("Odyssey Kitty include exists without Odyssey state")
    suffix = "\n" if text.endswith("\n") else "\n\n"
    addition = suffix + "# Odyssey-managed Matugen theme\ninclude %s\n" % theme
    write(config, text + addition, stat.S_IMODE(config.stat().st_mode))
    write(saved, json.dumps({"version": STATE_VERSION, "addition": addition}, indent=2) + "\n", 0o600)
    print("KITTY=enabled RELOAD=%s" % reload(config))

def refresh(config, theme, saved):
    if state(saved) is None: print("KITTY=disabled"); return
    text = config_text(config)
    if text is None: print("KITTY=no-config"); return
    if len(includes(text, theme)) != 1: raise Refusal("Odyssey Kitty include is missing or duplicated")
    print("KITTY=refreshed RELOAD=%s" % reload(config))

def disable(config, theme, saved):
    prior = state(saved)
    if prior is None: print("KITTY=disabled"); return
    text = config_text(config)
    if text is None: print("KITTY=no-config"); return
    addition = prior.get("addition")
    if not isinstance(addition, str) or not text.endswith(addition) or len(includes(text, theme)) != 1: raise Refusal("Kitty include boundary changed; refusing to remove it")
    write(config, text[:-len(addition)], stat.S_IMODE(config.stat().st_mode)); saved.unlink()
    print("KITTY=disabled RELOAD=%s" % reload(config))

def main():
    parser = argparse.ArgumentParser(); parser.add_argument("action", choices=("status", "enable", "refresh", "disable")); args = parser.parse_args()
    config, theme, saved = paths()
    if args.action == "enable": enable(config, theme, saved)
    elif args.action == "refresh": refresh(config, theme, saved)
    elif args.action == "disable": disable(config, theme, saved)
    else: print("KITTY=enabled" if state(saved) else "KITTY=disabled")

if __name__ == "__main__":
    try: main()
    except Refusal as error:
        print("Odyssey Kitty integration refused: %s" % error, file=sys.stderr); raise SystemExit(3)
