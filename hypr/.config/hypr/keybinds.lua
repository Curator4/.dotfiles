-- See https://wiki.hypr.land/Configuring/Basics/Binds/

local p = require("programs")

local mod = "SUPER" -- Sets "Windows" key as main modifier

-- bindel (locked + repeat) and bindl (locked) become option tables.
local LOCKED    = { locked = true }
local LOCKED_EL = { locked = true, repeating = true }

local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

hl.bind(mod .. " + Q", exec(p.terminal))
hl.bind(mod .. " + W", exec("rofi -show drun"))
hl.bind(mod .. " + E", exec(p.fileManager))
hl.bind(mod .. " + slash", exec(p.fileManager))
hl.bind(mod .. " + D", exec("discord"))
hl.bind(mod .. " + SHIFT + D", exec("kitty herdr --session dynasty"))
hl.bind(mod .. " + F", exec(p.browser))
hl.bind(mod .. " + T", exec("~/.bin/themis-entry --new-term"))
hl.bind(mod .. " + N", exec("kitty nvim"))
hl.bind(mod .. " + M", exec(p.spotify))
hl.bind(mod .. " + O", exec("obsidian"))
hl.bind(mod .. " + C", hl.dsp.window.close())
hl.bind(mod .. " + I", exec("kitty nvim +$ /home/curator/workspace/ai/household-oc/agents/tactical/data/itinerary.md"))
hl.bind(mod .. " + X", exec("~/workspace/ai/household-oc/tools/checks/checks-menu.sh"))
hl.bind(mod .. " + SHIFT + I", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + Escape", hl.dsp.exit())
hl.bind("F11", hl.dsp.window.fullscreen())

-- Move focus with vim keys
local directions = { H = "left", L = "right", K = "up", J = "down" }
for key, dir in pairs(directions) do
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))
end

-- Promote the focused window into the master slot.
hl.bind(mod .. " + SHIFT + N", hl.dsp.layout("swapwithmaster"))

-- Master ratio. Applies to the focused workspace only and is not persisted.
hl.bind(mod .. " + minus", hl.dsp.layout("mfact -0.05"))
hl.bind(mod .. " + equal", hl.dsp.layout("mfact +0.05"))
hl.bind(mod .. " + SHIFT + O", hl.dsp.layout("orientationnext"))

-- Cycle through windows in current workspace. Two dispatchers on one key: as a
-- single lua callback rather than two binds, so the order is explicit.
hl.bind(mod .. " + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- Switch workspaces with mod + [0-9], move the active window with mod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mod + LMB/RMB and dragging
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots
hl.bind(mod .. " + S", exec("hyprshot -m region"))
hl.bind(mod .. " + SHIFT + S", exec("hyprshot -m output"))

-- Screen recording (toggle: first press = pick region + start, second press = stop)
hl.bind(mod .. " + SHIFT + R", exec("~/.bin/record-region"))

-- Utilities
hl.bind(mod .. " + P", exec("hyprlock"))
hl.bind(mod .. " + U", exec(p.ssh))
hl.bind(mod .. " + Y", exec("~/.config/hypr/scripts/hud-capture.sh"))
hl.bind(mod .. " + SHIFT + Y", exec("eww open --toggle hud"))
-- Sit/stand toggle — declares the transition, HUD footer counts the block with
-- away-from-desk time subtracted. Confirms with a short notification because the
-- board is often closed when this is pressed.
hl.bind(mod .. " + R", exec("posture"))
hl.bind(mod .. " + period", exec("~/.config/hypr/scripts/emoji-picker.sh"))
hl.bind(mod .. " + B", exec("~/.config/waybar/scripts/bluetooth-menu.sh"))
-- Display warmth (hyprsunset) — manual override, auto-resets at next profile boundary.
-- Schedule lives in ~/.config/hypr/hyprsunset.conf.
hl.bind(mod .. " + G", exec("~/.bin/sunset-step warmer"))
hl.bind(mod .. " + SHIFT + G", exec("~/.bin/sunset-step cooler"))

-- Theme switching, F1..F12 in a fixed order.
--   mod + Fn        — reskins the FOCUSED kitty window only
--   mod + ALT + Fn  — repaints the whole desktop
-- apply restarts waybar, so detach into a transient scope: a bind spawned from
-- waybar's own tree would be killed mid-apply, before .current-theme is written.
local themes = {
    "aegis", "ashen", "calliope", "crimson-gray", "cyber", "ember",
    "pine", "lavender", "mono", "neon", "nord", "serene",
}
local themeTerm  = "~/.dotfiles/bin/.bin/theme-term.sh"
local themeApply = "systemd-run --user --quiet --collect ~/.dotfiles/bin/.bin/theme-switcher.sh apply"

for i, theme in ipairs(themes) do
    local fkey = "F" .. i
    hl.bind(mod .. " + " .. fkey, exec(themeTerm .. " " .. theme))
    hl.bind(mod .. " + ALT + " .. fkey, exec(themeApply .. " " .. theme))
end

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), LOCKED_EL)
hl.bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), LOCKED_EL)
hl.bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), LOCKED_EL)
hl.bind("XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), LOCKED_EL)
hl.bind("XF86MonBrightnessUp", exec("brightnessctl -e4 -n2 set 5%+"), LOCKED_EL)
hl.bind("XF86MonBrightnessDown", exec("brightnessctl -e4 -n2 set 5%-"), LOCKED_EL)

-- Volume control with arrow keys
hl.bind(mod .. " + up", exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), LOCKED_EL)
hl.bind(mod .. " + down", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), LOCKED_EL)

-- Media controls with playerctl
hl.bind("XF86AudioNext", exec("playerctl next"), LOCKED)
hl.bind("XF86AudioPause", exec("playerctl play-pause"), LOCKED)
hl.bind("XF86AudioPlay", exec("playerctl play-pause"), LOCKED)
hl.bind("XF86AudioPrev", exec("playerctl previous"), LOCKED)

-- Arrow keys + space for media control
hl.bind(mod .. " + left", exec("playerctl -p ncspot,spotify,firefox previous"))
hl.bind(mod .. " + right", exec("playerctl -p ncspot,spotify,firefox next"))
hl.bind(mod .. " + space", exec("playerctl -p ncspot,spotify,firefox play-pause"))

-- TTS controls - no modifier needed, global hotkeys
hl.bind("Insert", exec("python3 ~/workspace/ai/tts-daemon/tts_client.py kill"), LOCKED)
hl.bind("Home", exec("python3 ~/workspace/ai/tts-daemon/tts_client.py pause"), LOCKED)

-- Quick emoji shortcuts (mod + CTRL + key) — clipboard+ydotool paste
-- (plain wtype unicode is ignored by Electron/Chromium on Wayland)
local typeEmoji = "~/.config/hypr/scripts/type-emoji.sh"
local emoji = {
    { "J", "😂" }, { "R", "🤣" }, { "C", "☕" }, { "U", "🙃" },
    { "T", "🤔" }, { "F", "🫡" }, { "P", "😔" }, { "H", "😌" },
    { "E", "😎" }, { "D", "🫤" }, { "Y", "🥹" }, { "Q", "😳" },
    { "S", "😭" }, { "W", "👋" }, { "M", "😓" }, { "X", "💀" },
    { "A", "😠" }, { "L", "😈" }, { "Z", "🤡" }, { "B", "👍" },
    { "I", "🫵" }, { "K", "👀" }, { "O", "😮" }, { "G", "😼" },
    { "N", "😅" }, { "V", "🤮" }, { "1", "😤" }, { "2", "🤦" },
    { "3", "🔥" }, { "4", "👌" }, { "5", "✅" }, { "6", "🤨" },
    { "7", "💪" },
    { "semicolon", "æ" }, { "apostrophe", "ø" }, { "bracketleft", "å" },
    { "slash", "🤷" },
}

for _, e in ipairs(emoji) do
    hl.bind(mod .. " + CTRL + " .. e[1], exec(typeEmoji .. ' "' .. e[2] .. '"'))
end
