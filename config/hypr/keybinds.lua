-- Keybindings

local mod = "SUPER"

local function odyssey(command)
	return hl.dsp.exec_cmd("odyssey ipc " .. command)
end

-- Application launchers
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("code"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("firefox"))
hl.bind(mod .. " + SHIFT + F", odyssey("capture screenshot region both"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("thunar"))

-- Audio controls
hl.bind("XF86AudioRaiseVolume", odyssey("audio increment 3"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", odyssey("audio decrement 3"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", odyssey("audio mute"), { locked = true })
hl.bind("XF86AudioMicMute", odyssey("audio micmute"), { locked = true })

-- Keyboard backlight
-- Uses the standard Linux keyboard-backlight LED device when available.
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("brightnessctl -d '*::kbd_backlight' set +1"), { repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d '*::kbd_backlight' set 1-"), { repeating = true })

-- Display brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Window management
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + W", hl.dsp.group.toggle())
hl.bind(mod .. " + M", hl.dsp.window.fullscreen())

-- Focus navigation
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))

-- Window movement
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))

-- Monitor navigation
hl.bind(mod .. " + CTRL + left", hl.dsp.focus({ monitor = "left" }))
hl.bind(mod .. " + CTRL + right", hl.dsp.focus({ monitor = "right" }))
hl.bind(mod .. " + CTRL + H", hl.dsp.focus({ monitor = "left" }))
hl.bind(mod .. " + CTRL + J", hl.dsp.focus({ monitor = "down" }))
hl.bind(mod .. " + CTRL + K", hl.dsp.focus({ monitor = "up" }))
hl.bind(mod .. " + CTRL + L", hl.dsp.focus({ monitor = "right" }))

-- Move window to monitor
hl.bind(mod .. " + SHIFT + CTRL + left", hl.dsp.window.move({ monitor = "left" }))
hl.bind(mod .. " + SHIFT + CTRL + down", hl.dsp.window.move({ monitor = "down" }))
hl.bind(mod .. " + SHIFT + CTRL + up", hl.dsp.window.move({ monitor = "up" }))
hl.bind(mod .. " + SHIFT + CTRL + right", hl.dsp.window.move({ monitor = "right" }))
hl.bind(mod .. " + SHIFT + CTRL + H", hl.dsp.window.move({ monitor = "left" }))
hl.bind(mod .. " + SHIFT + CTRL + J", hl.dsp.window.move({ monitor = "down" }))
hl.bind(mod .. " + SHIFT + CTRL + K", hl.dsp.window.move({ monitor = "up" }))
hl.bind(mod .. " + SHIFT + CTRL + L", hl.dsp.window.move({ monitor = "right" }))

-- Workspace navigation
hl.bind(mod .. " + Page_Down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + Page_Up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + U", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + I", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + CTRL + down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mod .. " + CTRL + up", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mod .. " + CTRL + U", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mod .. " + CTRL + I", hl.dsp.window.move({ workspace = "e-1" }))

-- Move window to workspace
hl.bind(mod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mod .. " + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mod .. " + SHIFT + U", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mod .. " + SHIFT + I", hl.dsp.window.move({ workspace = "e-1" }))

-- Mouse-wheel workspace navigation
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + CTRL + mouse_down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mod .. " + CTRL + mouse_up", hl.dsp.window.move({ workspace = "e-1" }))

-- Numbered workspaces
for i = 1, 9 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
	hl.bind(mod .. " + ALT + " .. i, hl.dsp.window.move({ workspace = i, silent = true }))
end

-- Special workspaces
hl.bind(mod .. " + F1", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + F1", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mod .. " + ALT + F1", hl.dsp.window.move({ workspace = "special:magic", silent = true }))
hl.bind(mod .. " + F2", hl.dsp.workspace.toggle_special("magic1"))
hl.bind(mod .. " + SHIFT + F2", hl.dsp.window.move({ workspace = "special:magic1" }))
hl.bind(mod .. " + ALT + F2", hl.dsp.window.move({ workspace = "special:magic1", silent = true }))

-- Layout management
hl.bind(mod .. " + bracketleft", hl.dsp.layout("preselect l"))
hl.bind(mod .. " + bracketright", hl.dsp.layout("preselect r"))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + CTRL + F", hl.dsp.window.fullscreen())

-- Mouse move / resize
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mod .. " + Z", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + X", hl.dsp.window.resize(), { mouse = true })

-- Resize by keycode
hl.bind(mod .. " + code:20", hl.dsp.window.resize({ x = -100, y = 0 }), { description = "Expand window left" })
hl.bind(mod .. " + code:21", hl.dsp.window.resize({ x = 100, y = 0 }), { description = "Shrink window left" })

-- Manual sizing
hl.bind(mod .. " + minus", hl.dsp.window.resize({ x = -50, y = 0 }), { repeating = true })
hl.bind(mod .. " + equal", hl.dsp.window.resize({ x = 50, y = 0 }), { repeating = true })
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -50 }), { repeating = true })
hl.bind(mod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 50 }), { repeating = true })

-- Screenshots and Odyssey power control
hl.bind("XF86Launch1", odyssey("power cycle"))
hl.bind("CTRL + XF86Launch1", odyssey("capture screenshot full copy"))
hl.bind("ALT + XF86Launch1", odyssey("capture screenshot active copy"))
hl.bind("Print", odyssey("capture screenshot region copy"))
hl.bind("CTRL + Print", odyssey("capture screenshot full copy"))
hl.bind("ALT + Print", odyssey("capture screenshot active copy"))
