-- General layout, decoration, groups, and miscellaneous appearance

hl.config({
	general = {
		gaps_in = 3,
		gaps_out = 3,
		border_size = 0,
		resize_on_border = true,
		col = {
			active_border = "0xff444444",
			inactive_border = "rgba(d0d0d0ff)",
		},
		layout = "dwindle",
	},
})

hl.config({
	decoration = {
		rounding = 15,
		active_opacity = 1.0,
		inactive_opacity = 0.9,
		shadow = {
			enabled = true,
			range = 1,
			render_power = 3,
			offset = "2 2",
			color = "rgba(255,255,255,0.75)",
			color_inactive = "rgba(255,255,255,0.31)",
		},
	},
})

hl.config({
	group = {
		col = {
			border_active = "0xff444444",
			border_locked_active = "0xff444444",
		},
		groupbar = {
			enabled = true,
			col = {
				active = "0xff444444",
				inactive = "0xA9A9A9",
			},
			font_family = "JetBrainsMono Nerd Font",
			font_size = 10,
			gradients = true,
			keep_upper_gap = false,
			round_only_edges = false,
			rounding = 10,
			indicator_gap = 0,
			indicator_height = 0,
		},
	},
})

hl.config({
	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		vrr = 1,
	},
})
