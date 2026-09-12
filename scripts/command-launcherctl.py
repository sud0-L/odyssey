#!/usr/bin/env python3
"""Local-only history discovery and terminal launching for Odyssey."""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

SUPPORTED_SHELLS = ("zsh", "bash", "fish")
SUPPORTED_TERMINALS = ("kitty", "foot", "alacritty", "ghostty")


def selected_shell(requested: str, environment: dict[str, str] | None = None) -> str:
    env = os.environ if environment is None else environment
    if requested in SUPPORTED_SHELLS:
        return requested
    if requested != "auto":
        raise ValueError("unsupported shell history source")
    candidate = Path(env.get("SHELL", "")).name.lower()
    return candidate if candidate in SUPPORTED_SHELLS else ""


def history_path(source: str, environment: dict[str, str] | None = None) -> Path:
    env = os.environ if environment is None else environment
    home = Path(env.get("HOME", str(Path.home())))
    if source == "zsh":
        return Path(env.get("HISTFILE") or Path(env.get("ZDOTDIR", home)) / ".zsh_history")
    if source == "bash":
        return Path(env.get("HISTFILE") or home / ".bash_history")
    if source == "fish":
        data = Path(env.get("XDG_DATA_HOME") or home / ".local" / "share")
        return data / "fish" / "fish_history"
    raise ValueError("unsupported shell history source")


def _logical_lines(raw: str) -> list[str]:
    lines: list[str] = []
    pending = ""
    for line in raw.splitlines():
        pending = f"{pending}\n{line}" if pending else line
        if pending.endswith("\\"):
            pending = pending[:-1]
            continue
        lines.append(pending)
        pending = ""
    if pending:
        lines.append(pending)
    return lines


def parse_zsh(raw: str) -> list[str]:
    return [re.sub(r"^: \d+:\d+;", "", line) for line in _logical_lines(raw)]


def parse_bash(raw: str) -> list[str]:
    return [line for line in _logical_lines(raw) if not re.fullmatch(r"#\d{9,}", line)]


def _fish_unescape(value: str) -> str:
    def hexadecimal(match: re.Match[str]) -> str:
        try:
            return chr(int(match.group(1), 16))
        except ValueError:
            return match.group(0)

    value = re.sub(r"\\x([0-9a-fA-F]{2})", hexadecimal, value)
    return value.replace(r"\n", "\n").replace(r"\\", "\\")


def parse_fish(raw: str) -> list[str]:
    commands: list[str] = []
    for line in raw.splitlines():
        match = re.match(r"^- cmd: ?(.*)$", line)
        if match:
            commands.append(_fish_unescape(match.group(1)))
    return commands


def recent_history(source: str, limit: int,
        environment: dict[str, str] | None = None) -> dict[str, object]:
    resolved = selected_shell(source, environment)
    if not resolved:
        return {"source": "", "entries": [], "error": "Current shell history is unsupported"}
    path = history_path(resolved, environment)
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {"source": resolved, "entries": [], "error": "Shell history is unavailable"}
    parser = {"zsh": parse_zsh, "bash": parse_bash, "fish": parse_fish}[resolved]
    unique: list[str] = []
    seen: set[str] = set()
    for command in reversed(parser(raw)):
        if not command.strip() or "\0" in command or command in seen:
            continue
        seen.add(command)
        unique.append(command)
        if len(unique) >= limit:
            break
    return {"source": resolved, "entries": unique, "error": ""}


def selected_terminal(requested: str) -> str:
    if requested != "auto" and requested not in SUPPORTED_TERMINALS:
        raise ValueError("unsupported terminal")
    candidates = SUPPORTED_TERMINALS if requested == "auto" else (requested,)
    return next((candidate for candidate in candidates if shutil.which(candidate)), "")


def terminal_command(terminal: str, shell: str, command: str) -> list[str]:
    if terminal == "kitty":
        return [terminal, "--hold", "--", shell, "-lc", command]
    if terminal == "foot":
        return [terminal, "--hold", shell, "-lc", command]
    if terminal == "alacritty":
        return [terminal, "--hold", "-e", shell, "-lc", command]
    if terminal == "ghostty":
        return [terminal, "--wait-after-command=true", "-e", shell, "-lc", command]
    raise ValueError("unsupported terminal")


def launch(requested_terminal: str, command: str,
        environment: dict[str, str] | None = None) -> None:
    env = os.environ.copy() if environment is None else environment.copy()
    terminal = selected_terminal(requested_terminal)
    if not terminal:
        raise RuntimeError("Configured terminal is unavailable")
    shell = env.get("SHELL", "")
    if not shell or not Path(shell).is_file() or not os.access(shell, os.X_OK):
        shell = shutil.which("sh") or "/bin/sh"
    subprocess.Popen(terminal_command(terminal, shell, command), env=env,
        start_new_session=True, stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main(arguments: list[str]) -> int:
    if len(arguments) >= 2 and arguments[1] == "history":
        if len(arguments) != 4 or not arguments[3].isdigit():
            return 2
        try:
            result = recent_history(arguments[2], min(int(arguments[3]), 2000))
        except ValueError as error:
            result = {"source": "", "entries": [], "error": str(error)}
        print(json.dumps(result, ensure_ascii=False))
        return 0
    if len(arguments) == 4 and arguments[1] == "run":
        try:
            launch(arguments[2], arguments[3])
        except (OSError, RuntimeError, ValueError) as error:
            print(str(error), file=sys.stderr)
            return 1
        return 0
    print(f"usage: {arguments[0]} history SOURCE LIMIT | run TERMINAL COMMAND", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
