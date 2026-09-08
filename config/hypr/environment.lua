-- Environment and default applications

hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")

hl.env("TERMINAL", "kitty")
hl.env("FILE_MANAGER", "thunar")
hl.env("XDG_UTILS_DEFAULT_FILE_MANAGER", "thunar")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
