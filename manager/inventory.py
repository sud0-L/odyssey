"""Explicit source closure and read-only host discovery."""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import os
from pathlib import Path
import shutil
from typing import Callable, Iterable

QML_DIRECTORIES = ("applications", "components", "core", "island", "launcher", "panels", "services")
RUNTIME_SCRIPTS = (
    "capturectl.sh", "clipboardctl.sh", "command-launcherctl.py", "export-theme.sh", "generate-hyprlock-config.sh",
    "generate-palette.sh", "idle-brightnessctl.sh", "idlectl.sh", "install-hyprlock.sh",
    "lock-status.sh", "lock-powerctl.sh", "manage-theme-integration.sh", "notification-provenance.py",
    "odyssey-session.sh", "power-sound.sh", "sessionctl.sh", "settingsctl.sh",
    "shortcutctl.sh", "system-sensor-paths.sh", "wallpaper-mode.sh", "wallpaperctl.sh",
    "terminal-integrations.sh", "kitty-themectl.py", "starship-themectl.py",
    "fastfetch-themectl.py", "host-configctl.sh", "zsh-setup.sh",
)
MANAGER_ADAPTERS = ("startupctl.sh",)


@dataclass(frozen=True)
class XdgPaths:
    bin_command: Path
    manager_releases: Path
    manager_current: Path
    shell_releases: Path
    shell_current: Path
    install_manifest: Path
    operations: Path
    backups: Path
    policy: Path

    def as_dict(self) -> dict[str, str]:
        return {key: str(value) for key, value in self.__dict__.items()}


def resolve_xdg(environ: dict[str, str] | None = None) -> XdgPaths:
    env = os.environ if environ is None else environ
    home = Path(env.get("HOME", str(Path.home())))
    data = Path(env.get("XDG_DATA_HOME", home / ".local/share"))
    state = Path(env.get("XDG_STATE_HOME", home / ".local/state"))
    config = Path(env.get("XDG_CONFIG_HOME", home / ".config"))
    bin_home = Path(env.get("XDG_BIN_HOME", home / ".local/bin"))
    root = data / "odyssey"
    manager = root / "manager"
    manager_state = state / "odyssey" / "manager"
    return XdgPaths(bin_home / "odyssey", manager / "releases", manager / "current", root / "releases", root / "current", manager_state / "install.json", manager_state / "operations", manager_state / "backups", config / "odyssey")


def source_inventory(root: Path) -> list[dict[str, str]]:
    root = root.resolve()
    entries: list[dict[str, str]] = []
    def include(relative: str, category: str) -> None:
        path = root / relative
        if not path.is_file():
            raise ValueError(f"required production payload is absent: {relative}")
        entries.append({"path": relative, "category": category})
    include("VERSION", "release-metadata")
    include("shell.qml", "runtime-qml")
    include("qmldir", "runtime-qml")
    for directory in QML_DIRECTORIES:
        for path in sorted((root / directory).rglob("*")):
            if path.is_file() and (path.suffix == ".qml" or path.name == "qmldir"):
                include(path.relative_to(root).as_posix(), "runtime-qml")
    for script in RUNTIME_SCRIPTS:
        include(f"scripts/{script}", "runtime-helper")
    include("matugen/config.toml", "matugen-input")
    include("matugen/palette.json", "matugen-input")
    include("assets/hyprlock-power.png", "runtime-asset")
    include("generated/palette.json", "fallback-palette")
    for relative in (
        "config/hypr/hyprland.lua",
        "config/hypr/animations.lua", "config/hypr/appearance.lua",
        "config/hypr/environment.lua", "config/hypr/input.lua",
        "config/hypr/keybinds.lua", "config/hypr/layouts.lua",
        "config/hypr/monitors.lua", "config/hypr/startup.lua",
        "config/hypr/window-rules.lua", "config/kitty/kitty.conf",
        "config/starship/starship.toml", "config/fastfetch/config.jsonc",
        "config/hypridle/hypridle.conf", "config/zsh/.zshrc",
    ):
        include(relative, "managed-host-config")
    for relative in (
        "sddm/odyssey/Main.qml", "sddm/odyssey/LockPasswordField.qml",
        "sddm/odyssey/Theme.qml", "sddm/odyssey/theme.conf",
        "sddm/odyssey/metadata.desktop", "sddm/odyssey/background.jpg",
        "sddm/x11/Xsetup", "sddm/x11/blank-cursor.xbm",
        "sddm/x11/odyssey-x11.conf",
    ):
        include(relative, "optional-sddm-source")
    return sorted(entries, key=lambda item: item["path"])


def packaged_inventory(root: Path) -> list[dict[str, str]]:
    """The explicit release closure, partitioned by installation owner."""
    entries = [{**entry, "component": "shell"} for entry in source_inventory(root)]
    def include(relative: str, category: str) -> None:
        path = root / relative
        if not path.is_file():
            raise ValueError(f"required manager payload is absent: {relative}")
        entries.append({"component": "manager", "path": relative, "category": category})
    include("odyssey", "manager-launcher")
    include("VERSION", "manager-metadata")
    include("manager/default-release.json", "manager-metadata")
    for path in sorted((root / "manager").rglob("*.py")):
        include(path.relative_to(root).as_posix(), "manager-code")
    for script in MANAGER_ADAPTERS:
        include(f"scripts/{script}", "manager-adapter")
    return sorted(entries, key=lambda item: (item["component"], item["path"]))


def source_identity(root: Path, entries: Iterable[dict[str, str]]) -> dict[str, str]:
    digest = hashlib.sha256()
    for entry in entries:
        relative = entry["path"]
        digest.update(relative.encode("utf-8") + b"\0")
        digest.update((root / relative).read_bytes())
    artifact = digest.hexdigest()
    return {"kind": "source", "version": "development", "sourceSha256": artifact,
            "sourceId": f"development-{artifact}"}


def read_os_release(path: Path = Path("/etc/os-release")) -> dict[str, str]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return {}
    result: dict[str, str] = {}
    for line in lines:
        if "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            result[key] = value.strip().strip('"')
    return result


def discover_platform(os_release: dict[str, str] | None = None, which: Callable[[str], str | None] = shutil.which) -> dict[str, str]:
    release = read_os_release() if os_release is None else os_release
    manager = next((name for name in ("pacman", "apt-get", "dnf", "zypper", "apk") if which(name)), "unknown")
    return {"id": release.get("ID", "unknown"), "version": release.get("VERSION_ID", "unknown"), "packageManager": manager}


DEPENDENCIES = {
    "mandatory-manager-base": ("python3", "bash", "hyprctl", "qs", "systemctl", "busctl", "loginctl", "udevadm", "jq"),
    "default-feature-required": ("awww", "matugen", "kitty", "firefox", "thunar", "code", "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1", "starship", "fastfetch", "hyprlock", "hypridle", "hyprpicker", "grim", "slurp", "wl-copy", "wl-paste", "cliphist", "gpu-screen-recorder", "brightnessctl", "curl", "ffmpeg", "lspci", "wpctl", "pgrep", "pidof", "nmcli", "bluetoothctl", "playerctl", "sensors", "notify-send", "fc-match", "/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf", "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"),
    "optional-enhancement": ("powerprofilesctl",),
    "optional-zsh": ("zsh", "git"),
    "development-only": ("qmllint", "qmltestrunner"),
    "sddm-specific": ("sddm", "sddm-greeter"),
}


def discover_dependencies(which: Callable[[str], str | None] = shutil.which) -> list[dict[str, object]]:
    return [{"class": category, "commands": [{"name": name, "available": bool(which(name))} for name in names]} for category, names in DEPENDENCIES.items()]
