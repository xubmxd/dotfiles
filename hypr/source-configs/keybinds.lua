-- ~/.config/hypr/source-configs/keybinds.lua

local mainMod = "SUPER"

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager)) -- or dolphin, nautilus, etc.
hl.bind("CTRL + SHIFT + RETURN", hl.dsp.exec_cmd("env -u QT_STYLE_OVERRIDE -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=xcb cool-retro-term"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + U", hl.dsp.layout("togglesplit"))
hl.bind("CTRL + SHIFT + W", hl.dsp.exec_cmd("~/.local/bin/exec-waybar"))

-- wallpaper - scripts
hl.bind(mainMod .. " + SHIFT + apostrophe", hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-selector.sh"))
hl.bind(mainMod .. " + SHIFT + semicolon", hl.dsp.exec_cmd("~/.config/hypr/scripts/gif-selector.sh"))
hl.bind(mainMod .. " + apostrophe", hl.dsp.exec_cmd("~/.config/hypr/scripts/random-wallpaper.sh"))
hl.bind(mainMod .. " + semicolon", hl.dsp.exec_cmd("~/.config/hypr/scripts/random-gif.sh"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/regenerate-colors.sh"))

-- Emoji
hl.bind(mainMod .. " + Period", hl.dsp.exec_cmd("~/.config/hypr/scripts/emoji-picker"))

-- Spotify - scripts 
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("~/.config/hypr/scripts/mewsic-toggle.sh"))

-- Kernel bugs - temp fix
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("sudo /usr/local/bin/fix-mouse"))

-- wayclick
hl.bind(mainMod .. " + F9", hl.dsp.exec_cmd("~/.scripts/wayclick/wayclick.sh"))

-- Screenshot
hl.bind("Print", hl.dsp.exec_cmd("grim ~/Pictures/Screenshots/screenshot_$(date +%s).png"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grim -g \"$(slurp)\" ~/Pictures/Screenshots/screenshot_$(date +%s).png"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("grim - | wl-copy"))
hl.bind("CTRL + SHIFT + Print", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
hl.bind("ALT + Print", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | swappy -f -"))

-- Move focus
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + i", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "down" }))

-- Window movement
hl.bind(mainMod .. " + SHIFT + j", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + i", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + k", hl.dsp.window.move({ direction = "d" }))

-- Window resize
hl.bind("CTRL + SHIFT + j", hl.dsp.window.resize({ x = -20, y = 0, relative = true }))
hl.bind("CTRL + SHIFT + l", hl.dsp.window.resize({ x = 20, y = 0, relative = true }))
hl.bind("CTRL + SHIFT + i", hl.dsp.window.resize({ x = 0, y = -20, relative = true }))
hl.bind("CTRL + SHIFT + k", hl.dsp.window.resize({ x = 0, y = 20, relative = true }))

-- ==========================================
-- ====== FUNCTION / MEDIA KEYS =============
-- ==========================================

-- Brightness control
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

-- Gesture Media Control (Updated to native Lua lambda functions)
hl.gesture({
    fingers = 3,
    direction = "up",
    action = function() hl.exec_cmd("playerctl play-pause") end
})
hl.gesture({
    fingers = 3,
    direction = "left",
    action = function() hl.exec_cmd("playerctl previous") end
})
hl.gesture({
    fingers = 3,
    direction = "right",
    action = function() hl.exec_cmd("playerctl next") end
})

-- Workspaces
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())

-- Volume & Mic Control
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })

-- Extra Brightness Binds
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
