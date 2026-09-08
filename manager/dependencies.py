"""Bounded Arch dependency inspection and installation.

This is deliberately an adapter, not a second package manager.  Its package set is
small, explicit, and limited to official Arch repository names.  It never refreshes
the sync database, upgrades the system, invokes an AUR helper, or removes a package.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import shutil
import subprocess
from typing import Callable

from manager.install import Command
from manager.inventory import discover_platform


@dataclass(frozen=True)
class Package:
    name: str
    dependency_class: str
    commands: tuple[str, ...]
    files: tuple[str, ...] = ()


# These are the packages needed for the supported public-alpha shell path.  The
# remaining feature integrations retain their existing graceful-absence behavior.
ARCH_PACKAGES = (
    Package("python", "mandatory-manager-base", ("python3",)),
    Package("bash", "mandatory-manager-base", ("bash",)),
    Package("hyprland", "mandatory-manager-base", ("hyprctl",)),
    Package("quickshell", "mandatory-manager-base", ("qs",)),
    Package("systemd", "mandatory-manager-base", ("systemctl", "busctl", "loginctl", "udevadm")),
    Package("jq", "mandatory-manager-base", ("jq",)),
    Package("awww", "default-feature-required", ("awww", "awww-daemon")),
    Package("matugen", "default-feature-required", ("matugen",)),
    Package("kitty", "terminal-theme-required", ("kitty",)),
    Package("firefox", "desktop-default-required", ("firefox",)),
    Package("thunar", "desktop-default-required", ("thunar",)),
    Package("code", "desktop-default-required", ("code",)),
    Package("mate-polkit", "desktop-default-required",
            ("/usr/lib/mate-polkit/polkit-mate-authentication-agent-1",)),
    Package("starship", "terminal-theme-required", ("starship",)),
    Package("fastfetch", "terminal-theme-required", ("fastfetch",)),
    Package("hypridle", "idle-lock-required", ("hypridle",)),
    Package("hyprlock", "idle-lock-required", ("hyprlock",)),
    Package("hyprpicker", "desktop-default-required", ("hyprpicker",)),
    Package("grim", "capture-required", ("grim",)),
    Package("slurp", "capture-required", ("slurp",)),
    Package("wl-clipboard", "clipboard-capture-required", ("wl-copy", "wl-paste")),
    Package("cliphist", "clipboard-required", ("cliphist",)),
    Package("gpu-screen-recorder", "capture-required", ("gpu-screen-recorder",)),
    Package("brightnessctl", "display-required", ("brightnessctl",)),
    Package("curl", "weather-required", ("curl",)),
    Package("ffmpeg", "wallpaper-analysis-required", ("ffmpeg",)),
    Package("pciutils", "system-identity-required", ("lspci",)),
    Package("wireplumber", "audio-required", ("wpctl",)),
    Package("procps-ng", "session-process-required", ("pgrep", "pidof")),
    Package("networkmanager", "connectivity-required", ("nmcli",)),
    Package("bluez-utils", "connectivity-required", ("bluetoothctl",)),
    Package("playerctl", "media-tooling-required", ("playerctl",)),
    Package("lm_sensors", "system-sensors-required", ("sensors",)),
    Package("libnotify", "notification-tooling-required", ("notify-send",)),
    Package("adwaita-fonts", "ui-font-required", (),
            ("/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf",)),
    Package("ttf-jetbrains-mono-nerd", "ui-font-required", (),
            ("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf",)),
    Package("fontconfig", "ui-font-validation-required", ("fc-match",)),
)

OPTIONAL_PACKAGES = (
    Package("power-profiles-daemon", "optional-power-profile", ("powerprofilesctl",)),
    Package("zsh", "optional-zsh", ("zsh",)),
    Package("git", "optional-zsh", ("git",)),
)


class DependencyError(ValueError):
    pass


QUICKSHELL_UNUSABLE = (
    "Quickshell is installed but unusable or incompatible with the current Qt "
    "version. Reinstall quickshell, or rebuild quickshell-git against the current "
    "Qt version."
)


def _run(args: list[str]) -> Command:
    try:
        result = subprocess.run(args, text=True, capture_output=True, check=False)
        return Command(result.returncode, result.stdout, result.stderr)
    except OSError as error:
        return Command(127, "", str(error))


class ArchDependencies:
    def __init__(self, *, which: Callable[[str], str | None] = shutil.which,
                 platform: Callable[[], dict[str, str]] = discover_platform,
                 run: Callable[[list[str]], Command] = _run,
                 exists: Callable[[str], bool] = lambda value: Path(value).is_file()):
        self.which, self.platform, self.run, self.exists = which, platform, run, exists

    def _available(self, item: Package) -> bool:
        return (all(self.which(command) for command in item.commands)
                and all(self.exists(path) for path in item.files))

    def _inspect_package(self, item: Package) -> dict[str, object]:
        available = self._available(item)
        package: dict[str, object] = {
            "name": item.name,
            "class": item.dependency_class,
            "available": available,
        }
        if item.name == "quickshell" and available:
            qs = self.which("qs")
            if qs is None or self.run([qs, "--version"]).code != 0:
                package["available"] = False
                package["error"] = QUICKSHELL_UNUSABLE
        return package

    def inspect(self) -> dict[str, object]:
        platform = self.platform()
        supported = platform.get("id") == "arch" and platform.get("packageManager") == "pacman"
        packages = [self._inspect_package(item) for item in ARCH_PACKAGES]
        missing = [item["name"] for item in packages if not item["available"]]
        errors = [item["error"] for item in packages if "error" in item]
        optional = [{"name": item.name, "class": item.dependency_class,
                     "available": self._available(item)}
                    for item in OPTIONAL_PACKAGES]
        return {"kind": "dependencies", "platform": platform, "supported": supported,
                "packages": packages, "missingPackages": missing,
                "optionalPackages": optional, "errors": errors,
                "status": "ready" if supported else "unsupported"}

    def install(self, *, confirmed: bool, optional: bool = False,
                optional_class: str | None = None) -> dict[str, object]:
        report = self.inspect()
        if not report["supported"]:
            raise DependencyError("dependency installation is supported only on Arch Linux with pacman")
        if not confirmed:
            raise DependencyError("dependency installation requires explicit --yes confirmation")
        if report["errors"]:
            raise DependencyError(str(report["errors"][0]))
        if optional_class is not None and not optional:
            raise DependencyError("an optional dependency class requires optional installation")
        key = "optionalPackages" if optional else "missingPackages"
        selected = ([item for item in report[key]
                     if optional_class is None or item.get("class") == optional_class]
                    if optional else [])
        if optional and optional_class is not None and not any(
                item.dependency_class == optional_class for item in OPTIONAL_PACKAGES):
            raise DependencyError("unknown optional dependency class")
        missing = ([item["name"] for item in selected if not item.get("available", False)]
                   if optional else list(report[key]))
        if not missing:
            return {**report, "status": "completed", "installedPackages": []}
        if not self.which("sudo"):
            raise DependencyError("sudo is required to install missing Arch packages")
        # Keep the invocation structurally incapable of becoming a refresh,
        # upgrade, AUR, removal, or arbitrary-command interface.
        result = self.run(["sudo", "pacman", "-S", "--needed", *missing])
        if result.code != 0:
            raise DependencyError("pacman did not install the requested Odyssey dependencies")
        after = self.inspect()
        remaining = ([item for item in after[key]
                      if optional_class is None or item.get("class") == optional_class]
                     if optional else after[key])
        if (any(not item["available"] for item in remaining) if optional else remaining):
            raise DependencyError("installed dependencies did not provide the required commands")
        return {**after, "status": "completed", "installedPackages": missing}
