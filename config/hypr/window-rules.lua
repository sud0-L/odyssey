-- Window rules

-- Zen
hl.window_rule({ match = { class = "^zen$" }, float = true, center = true, size = "1920 1080" })
hl.window_rule({ match = { class = "zen", title = "Picture-in-Picture" }, float = true })
hl.window_rule({ match = { class = "zen", title = ".*Library.*" }, float = true })

-- Prevent unnamed XWayland helper windows from stealing focus
hl.window_rule({
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

-- Thunar file-operation progress
hl.window_rule({
	match = { class = "thunar", title = "File Operation Progress" },
	float = true,
	center = true,
})

-- Force tile
hl.window_rule({ match = { class = "pavucontrol" }, tile = true })
hl.window_rule({ match = { class = "nm-connection-editor" }, tile = true })

-- Float these apps
hl.window_rule({ match = { class = "blueman-manager" }, float = true })
hl.window_rule({ match = { class = "steam" }, float = true })
hl.window_rule({ match = { class = "xdg-desktop-portal" }, float = true })

-- File dialogs
hl.window_rule({ match = { class = "xdg-desktop-portal-gtk", title = "^Open" }, float = true })
hl.window_rule({ match = { class = "xdg-desktop-portal-gtk", title = "^Save" }, float = true })
hl.window_rule({ match = { class = "thunar", title = ".*Rename.*" }, float = true, center = true })

-- Quickshell
hl.window_rule({ match = { class = "org.quickshell" }, float = true })

-- Floating windows: slight transparency
hl.window_rule({ match = { float = true }, opacity = "0.9 0.9" })
