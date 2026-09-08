-- Session startup

hl.on("hyprland.start", function()
	hl.exec_cmd('bash -c "wl-paste --watch cliphist store &"')
	hl.exec_cmd("/usr/lib/mate-polkit/polkit-mate-authentication-agent-1")
end)
