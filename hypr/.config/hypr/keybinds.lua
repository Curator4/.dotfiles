-- See https://wiki.hypr.land/Configuring/Basics/Binds/

local p = require("programs")

local mod = "SUPER" -- Sets "Windows" key as main modifier

-- bindel (locked + repeat) and bindl (locked) become option tables.
local LOCKED    = { locked = true }
local LOCKED_EL = { locked = true, repeating = true }

local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

-- Descriptions are not a second cheat sheet: Hyprland exposes them with
-- `hyprctl binds -j`, which desktop-help renders directly.
local function bind(keys, description, dispatcher, options)
    local metadata = { description = description }
    for key, value in pairs(options or {}) do
        metadata[key] = value
    end
    return hl.bind(keys, dispatcher, metadata)
end

bind(mod .. " + Q", "[Apps] Terminal", exec(p.terminal))
bind(mod .. " + W", "[Picker] Application launcher", exec("rofi -show drun"))
bind(mod .. " + E", "[Apps] File manager", exec(p.fileManager))
bind(mod .. " + slash", "[Help] Open desktop help", exec("~/.bin/desktop-help"))
bind(mod .. " + D", "[Apps] Discord", exec("discord"))
bind(mod .. " + SHIFT + D", "[Apps] Dynasty workspace", exec("kitty herdr --session dynasty"))
bind(mod .. " + F", "[Apps] Browser", exec(p.browser))
bind(mod .. " + T", "[Picker] Themis inbox", exec("~/.config/hypr/scripts/themis-inbox.sh"))
bind(mod .. " + N", "[Apps] Neovim", exec("kitty nvim"))
bind(mod .. " + M", "[Apps] Spotify", exec(p.spotify))
bind(mod .. " + O", "[Apps] Obsidian", exec("obsidian"))
bind(mod .. " + C", "[Window] Close focused window", hl.dsp.window.close())
bind(mod .. " + I", "[Apps] Open itinerary", exec("kitty nvim +$ /home/curator/workspace/ai/household-oc/agents/tactical/data/itinerary.md"))
bind(mod .. " + X", "[HUD] Open routine checks", exec("~/.config/hypr/scripts/hud-checks.sh"))
bind(mod .. " + SHIFT + T", "[Picker] Theme picker", exec("~/.bin/theme"))
bind(mod .. " + SHIFT + I", "[Layout] Toggle split direction", hl.dsp.layout("togglesplit"))
bind(mod .. " + SHIFT + F", "[Window] Toggle floating", hl.dsp.window.float({ action = "toggle" }))
bind(mod .. " + Escape", "[Desktop] Exit Hyprland", hl.dsp.exit())
bind("F11", "[Window] Toggle fullscreen", hl.dsp.window.fullscreen())

-- Move focus with vim keys
local directions = { H = "left", L = "right", K = "up", J = "down" }
for key, dir in pairs(directions) do
    bind(mod .. " + " .. key, "[Window] Focus " .. dir, hl.dsp.focus({ direction = dir }))
    bind(mod .. " + SHIFT + " .. key, "[Window] Move window " .. dir, hl.dsp.window.swap({ direction = dir }))
end

-- Promote the focused window into the master slot.
bind(mod .. " + SHIFT + N", "[Layout] Promote window to master", hl.dsp.layout("swapwithmaster"))

-- Master ratio. Applies to the focused workspace only and is not persisted.
bind(mod .. " + minus", "[Layout] Shrink master area", hl.dsp.layout("mfact -0.05"))
bind(mod .. " + equal", "[Layout] Grow master area", hl.dsp.layout("mfact +0.05"))
-- Transpose the master split (two-way; SHIFT+O's orientationnext cycles the
-- full set). Keep off T and SHIFT+T — the Themis inbox and theme picker above.
bind(mod .. " + SHIFT + P", "[Layout] Transpose master split", hl.dsp.layout("orientationcycle left bottom"))
bind(mod .. " + SHIFT + O", "[Layout] Cycle master orientation", hl.dsp.layout("orientationnext"))

-- Master/dwindle flip for the whole focused monitor. Layouts are per-workspace
-- (0.54+), and workspaces are pinned to monitors in rules.lua, so re-ruling
-- every workspace on the focused monitor at once is the per-monitor switch a
-- global general:layout flip can't give. New workspaces still seed master via
-- the rules.lua hooks — this only re-lays-out what already exists.
-- Recipe: wiki "Cycle layout for current workspace", collapsed to two-way.
bind(mod .. " + A", "[Layout] Toggle dwindle on this monitor", function()
    local active = hl.get_active_workspace()
    if not active or not active.monitor then
        return
    end
    local target = (active.tiled_layout == "dwindle") and "master" or "dwindle"
    for _, ws in ipairs(hl.get_workspaces()) do
        if not ws.special and ws.monitor and ws.monitor.name == active.monitor.name then
            hl.workspace_rule({ workspace = tostring(ws.id), layout = target })
        end
    end
end)

-- Cycle through windows in current workspace. Two dispatchers on one key: as a
-- single lua callback rather than two binds, so the order is explicit.
bind(mod .. " + TAB", "[Window] Cycle windows", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- Switch workspaces with mod + [0-9], move the active window with mod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    bind(mod .. " + " .. key, "[Workspace] Switch to workspace " .. i, hl.dsp.focus({ workspace = i }))
    bind(mod .. " + SHIFT + " .. key, "[Workspace] Move window to workspace " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mod + LMB/RMB and dragging
bind(mod .. " + mouse:272", "[Window] Drag window", hl.dsp.window.drag(), { mouse = true })
bind(mod .. " + mouse:273", "[Window] Resize window", hl.dsp.window.resize(), { mouse = true })

-- Screenshots. submap_universal: the backlog/checks vim submaps would
-- otherwise swallow Super+S / Super+Shift+S (and slurp never starts).
local CAPTURE = { submap_universal = true }
bind(mod .. " + S", "[Capture] Screenshot a region", exec("hyprshot -m region"), CAPTURE)
bind(mod .. " + SHIFT + S", "[Capture] Screenshot the focused monitor", exec("hyprshot -m output"), CAPTURE)

-- Screen recording (toggle: first press = pick region + start, second press = stop)
bind(mod .. " + SHIFT + R", "[Capture] Start or stop region recording", exec("~/.bin/record-region"))

-- Utilities
bind(mod .. " + P", "[Desktop] Lock screen", exec("hyprlock"))
-- Super+Y = quick capture (backlog/itinerary). Super+U family is Huddle:
--   U        = focus the active-monitor board
--   Shift+U  = show/hide the active-monitor board
--   settings  = 'g' inside the focused board (no global key)
--   Alt+U    = SSH (unchanged)
-- Super+X = checks card (routine ack). Super+Shift+X is caffeine.
-- Super+Shift+B = backlog card (B is bluetooth; Shift+Y is hue).
-- Hue lights on Super+Shift+Y.
bind(mod .. " + U", "[Huddle] Focus the active-monitor board", exec("/home/curator/.local/bin/huddle-desktop --layer-host --url http://127.0.0.1:8877/huddle-board --runtime-dir /home/curator/.local/state/huddle/runtime focus"))
bind(mod .. " + SHIFT + U", "[Huddle] Show/hide the active-monitor board", exec("/home/curator/.local/bin/huddle-desktop --layer-host --url http://127.0.0.1:8877/huddle-board --runtime-dir /home/curator/.local/state/huddle/runtime toggle"))
bind(mod .. " + ALT + U", "[Apps] SSH terminal", exec(p.ssh))
bind(mod .. " + V", "[Fan] Toggle fan controls", exec("qs -c fan-rail ipc call fan toggle"))
-- submap_universal: same reason as Super+S. The backlog/checks vim
-- submaps swallow Super+Y otherwise, so hud-capture.sh never gets to
-- drop the submap and the rofi entry can't receive paste/type.
bind(mod .. " + Y", "[Picker] Quick capture", exec("~/.config/hypr/scripts/hud-capture.sh"), CAPTURE)
bind(mod .. " + SHIFT + Y", "[Desktop] Toggle office lights", exec("~/.bin/hue toggle"))
bind(mod .. " + SHIFT + B", "[HUD] Open backlog", exec("~/.config/hypr/scripts/hud-backlog.sh"))

-- Backlog card is a modal: j/k or arrows move, g/G top/bottom, x clears,
-- e edits, u undoes, y yanks, Escape/q closes. reset is required — without
-- it a failed close leaves every key trapped.
local backlogNav = "~/.config/hypr/scripts/hud-backlog-nav.sh"
hl.define_submap("backlog", function()
    bind("j", "[Modal] Backlog: move down", exec(backlogNav .. " down"), { repeating = true })
    bind("k", "[Modal] Backlog: move up", exec(backlogNav .. " up"), { repeating = true })
    bind("down", "[Modal] Backlog: move down", exec(backlogNav .. " down"), { repeating = true })
    bind("up", "[Modal] Backlog: move up", exec(backlogNav .. " up"), { repeating = true })
    bind("mouse_down", "[Modal] Backlog: scroll down", exec(backlogNav .. " down"), { repeating = true })
    bind("mouse_up", "[Modal] Backlog: scroll up", exec(backlogNav .. " up"), { repeating = true })
    bind("g", "[Modal] Backlog: jump to first", exec(backlogNav .. " first"))
    bind("SHIFT + G", "[Modal] Backlog: jump to last", exec(backlogNav .. " last"))
    bind("x", "[Modal] Backlog: complete item", exec(backlogNav .. " x"))
    bind("Return", "[Modal] Backlog: complete item", exec(backlogNav .. " x"))
    bind("e", "[Modal] Backlog: edit item", exec(backlogNav .. " e"))
    bind("u", "[Modal] Backlog: undo last clear", exec(backlogNav .. " u"))
    bind("y", "[Modal] Backlog: copy item", exec(backlogNav .. " y"))
    bind("escape", "[Modal] Backlog: close", exec("~/.config/hypr/scripts/hud-backlog.sh close"))
    bind("q", "[Modal] Backlog: close", exec("~/.config/hypr/scripts/hud-backlog.sh close"))
    bind(mod .. " + SHIFT + B", "[Modal] Backlog: close", exec("~/.config/hypr/scripts/hud-backlog.sh close"))
end)

-- Checks card is the same modal as backlog: j/k move, g/G top/bottom, x acks,
-- y yanks, Escape/q closes. reset is required — without it a failed close
-- leaves every key trapped.
local checksNav = "~/.config/hypr/scripts/hud-checks-nav.sh"
hl.define_submap("checks", function()
    bind("j", "[Modal] Checks: move down", exec(checksNav .. " down"), { repeating = true })
    bind("k", "[Modal] Checks: move up", exec(checksNav .. " up"), { repeating = true })
    bind("down", "[Modal] Checks: move down", exec(checksNav .. " down"), { repeating = true })
    bind("up", "[Modal] Checks: move up", exec(checksNav .. " up"), { repeating = true })
    bind("mouse_down", "[Modal] Checks: scroll down", exec(checksNav .. " down"), { repeating = true })
    bind("mouse_up", "[Modal] Checks: scroll up", exec(checksNav .. " up"), { repeating = true })
    bind("g", "[Modal] Checks: jump to first", exec(checksNav .. " first"))
    bind("SHIFT + G", "[Modal] Checks: jump to last", exec(checksNav .. " last"))
    bind("x", "[Modal] Checks: acknowledge", exec(checksNav .. " x"))
    bind("Return", "[Modal] Checks: acknowledge", exec(checksNav .. " x"))
    bind("y", "[Modal] Checks: copy item", exec(checksNav .. " y"))
    bind("escape", "[Modal] Checks: close", exec("~/.config/hypr/scripts/hud-checks.sh close"))
    bind("q", "[Modal] Checks: close", exec("~/.config/hypr/scripts/hud-checks.sh close"))
    bind(mod .. " + X", "[Modal] Checks: close", exec("~/.config/hypr/scripts/hud-checks.sh close"))
end)

-- Sit/stand toggle — declares the transition, HUD footer counts the block with
-- away-from-desk time subtracted. Confirms with a short notification because the
-- board is often closed when this is pressed.
bind(mod .. " + R", "[HUD] Toggle sit or stand posture", exec("posture"))
-- Caffeine dose picker (coffee mug / Monster). Super+X is the checks card;
-- this is the sibling event logger. Confirms with notify-send (active mg +
-- quiet estimate).
bind(mod .. " + SHIFT + X", "[Picker] Log caffeine", exec("~/.config/hypr/scripts/caffeine-menu.sh"))
-- Super+Caps: NEO70 Caps is QK_GESC (Esc on tap; grave when Super/Shift is
-- held). Super+Caps therefore arrives as Super+grave, not Caps_Lock.
-- Real Caps_Lock is layer 2 on that same key (hold the MO(2) "Alt" key).
-- Super+period stays as the old bind.
bind(mod .. " + grave", "[Picker] Emoji picker", exec("~/.config/hypr/scripts/emoji-picker.sh"))
bind(mod .. " + Caps_Lock", "[Picker] Emoji picker", exec("~/.config/hypr/scripts/emoji-picker.sh"))
bind(mod .. " + period", "[Picker] Emoji picker", exec("~/.config/hypr/scripts/emoji-picker.sh"))
bind(mod .. " + B", "[Picker] Bluetooth devices", exec("~/.config/waybar/scripts/bluetooth-menu.sh"))
-- Display warmth (sunsetr) — steps active-period target via ~/.bin/sunset-step.
-- Geo schedule lives in ~/.config/sunsetr/sunsetr.toml (systemctl --user sunsetr).
bind(mod .. " + G", "[Desktop] Make display warmer", exec("~/.bin/sunset-step warmer"))
bind(mod .. " + SHIFT + G", "[Desktop] Make display cooler", exec("~/.bin/sunset-step cooler"))

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
    bind(mod .. " + " .. fkey, "[Theme] Apply " .. theme .. " to terminal", exec(themeTerm .. " " .. theme))
    bind(mod .. " + ALT + " .. fkey, "[Theme] Apply " .. theme .. " to desktop", exec(themeApply .. " " .. theme))
end

-- Super+Shift+T = theme picker (Super+T is the Themis inbox). Super+Shift+M = random.
bind(mod .. " + SHIFT + M", "[Theme] Apply a random desktop theme", exec("~/.bin/theme random"))

-- Laptop multimedia keys for volume and LCD brightness.
-- Volume snaps to multiples of 5 (see scripts/volume-snap.sh) so a volume that
-- drifted off-grid (mixer UI, apps) re-aligns instead of staying at 47/52/….
local volSnap = "~/.config/hypr/scripts/volume-snap.sh"
bind("XF86AudioRaiseVolume", "[Hardware] Raise volume", exec(volSnap .. " up"), LOCKED_EL)
bind("XF86AudioLowerVolume", "[Hardware] Lower volume", exec(volSnap .. " down"), LOCKED_EL)
bind("XF86AudioMute", "[Hardware] Toggle output mute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), LOCKED_EL)
bind("XF86AudioMicMute", "[Hardware] Toggle microphone mute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), LOCKED_EL)
bind("XF86MonBrightnessUp", "[Hardware] Raise brightness", exec("brightnessctl -e4 -n2 set 5%+"), LOCKED_EL)
bind("XF86MonBrightnessDown", "[Hardware] Lower brightness", exec("brightnessctl -e4 -n2 set 5%-"), LOCKED_EL)

-- Volume control with arrow keys
bind(mod .. " + up", "[Hardware] Raise volume", exec(volSnap .. " up"), LOCKED_EL)
bind(mod .. " + down", "[Hardware] Lower volume", exec(volSnap .. " down"), LOCKED_EL)

-- Media controls with playerctl
bind("XF86AudioNext", "[Media] Next track", exec("playerctl next"), LOCKED)
bind("XF86AudioPause", "[Media] Play or pause", exec("playerctl play-pause"), LOCKED)
bind("XF86AudioPlay", "[Media] Play or pause", exec("playerctl play-pause"), LOCKED)
bind("XF86AudioPrev", "[Media] Previous track", exec("playerctl previous"), LOCKED)

-- Arrow keys + space for media control
bind(mod .. " + left", "[Media] Previous track", exec("playerctl -p ncspot,spotify,firefox previous"))
bind(mod .. " + right", "[Media] Next track", exec("playerctl -p ncspot,spotify,firefox next"))
bind(mod .. " + space", "[Media] Play or pause", exec("playerctl -p ncspot,spotify,firefox play-pause"))

-- TTS / desk-ear — nav cluster, no modifier (mute-shaped toggles)
-- Print = shut her up, Home = pause her, Insert = talk / stop talking
bind("Print", "[TTS] Stop speech", exec("python3 ~/workspace/ai/tts-daemon/tts_client.py kill"), LOCKED)
bind("Home", "[TTS] Pause or resume speech", exec("python3 ~/workspace/ai/tts-daemon/tts_client.py pause"), LOCKED)
bind("Insert", "[TTS] Start or stop voice input", exec("uv run --project /home/curator/workspace/ai/household-oc/tools/speak hark"), LOCKED)

-- Quick emoji shortcuts (mod + CTRL + key) — clipboard+ydotool paste
-- (plain wtype unicode is ignored by Electron/Chromium on Wayland)
local typeEmoji = "~/.config/hypr/scripts/type-emoji.sh"
local emoji = {
    { "J", "😂", "joy" }, { "R", "🤣", "rolling laugh" }, { "C", "☕", "coffee" },
    { "U", "🙃", "upside down" }, { "T", "🤔", "thinking" }, { "F", "🫡", "salute" },
    { "P", "😔", "pensive" }, { "H", "😌", "relieved" }, { "E", "😎", "sunglasses" },
    { "D", "🫤", "unsure" }, { "Y", "🥹", "holding back tears" }, { "Q", "😳", "flushed" },
    { "S", "😭", "crying" }, { "W", "👋", "wave" }, { "M", "😓", "sweat" },
    { "X", "💀", "skull" }, { "A", "😇", "angel" }, { "L", "😈", "devil" },
    { "Z", "🤡", "clown" }, { "B", "👍", "thumbs up" }, { "I", "🫵", "point" },
    { "K", "👀", "eyes" }, { "O", "😮", "surprised" }, { "G", "😼", "smirking cat" },
    { "N", "😅", "nervous laugh" }, { "V", "🤮", "vomit" }, { "1", "😤", "huffing" },
    { "2", "🤦", "facepalm" }, { "3", "🔥", "fire" }, { "4", "👌", "okay" },
    { "5", "✅", "checkmark" }, { "6", "🤨", "raised eyebrow" }, { "7", "💪", "flex" },
    { "semicolon", "æ", "Danish ae" }, { "apostrophe", "ø", "Danish oe" },
    { "bracketleft", "å", "Danish aa" }, { "8", "€", "euro" }, { "9", "😠", "angry" },
    { "slash", "🤷", "shrug" },
}

for _, e in ipairs(emoji) do
    bind(mod .. " + CTRL + " .. e[1], "[Emoji] " .. e[3] .. " " .. e[2], exec(typeEmoji .. ' "' .. e[2] .. '"'))
end
