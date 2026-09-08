-- Animations

hl.curve("odysseyEase", {
	type = "bezier",
	points = {
		{ 0.23, 1 },
		{ 0.32, 1 },
	},
})

hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "default" })
hl.animation({
	leaf = "specialWorkspace",
	enabled = true,
	speed = 2,
	bezier = "default",
	style = "slidefadevert",
})
