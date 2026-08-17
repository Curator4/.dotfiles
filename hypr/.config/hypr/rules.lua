-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
--
-- `match:class = X` becomes `match = { class = X }`; every other key stays put.
-- Regexes with backslashes use [[long strings]] — lua rejects \. as an escape.

-- Ignore maximize requests from apps. You'll probably like this.
hl.window_rule({
    name  = "suppress-maximize-all",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- Default opacity for all windows
hl.window_rule({
    name  = "default-opacity",
    match = { class = ".*" },

    opacity = "0.97 0.9",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "xwayland-drag-fix",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Terminal rules
hl.window_rule({
    name  = "terminal-tag",
    match = { class = "(Alacritty|kitty|com.mitchellh.ghostty)" },

    tag = "+terminal",
})

-- Browser-specific rules
hl.window_rule({
    name  = "chromium-browser-tag",
    match = { class = "([cC]hrom(e|ium)|[bB]rave-browser|Microsoft-edge|Vivaldi-stable)" },

    tag = "+chromium-based-browser",
})

hl.window_rule({
    name  = "firefox-browser-tag",
    match = { class = "([fF]irefox|zen|librewolf)" },

    tag = "+firefox-based-browser",
})

hl.window_rule({
    name  = "chromium-tile",
    match = { tag = "chromium-based-browser" },

    tile = true,
})

hl.window_rule({
    name  = "chromium-opacity",
    match = { tag = "chromium-based-browser" },

    opacity = "1 0.97",
})

hl.window_rule({
    name  = "firefox-opacity",
    match = { tag = "firefox-based-browser" },

    opacity = "1 0.97",
})

hl.window_rule({
    name  = "video-sites-opaque",
    match = { initial_title = [[((?i)(?:[a-z0-9-]+\.)*youtube\.com_/|app\.zoom\.us_/wc/home)]] },

    opacity = "1.0 1.0",
})

-- Floating windows (dialogs, settings, etc.)
hl.window_rule({
    name  = "floating-window-float",
    match = { tag = "floating-window" },

    float = true,
})

hl.window_rule({
    name  = "floating-window-center",
    match = { tag = "floating-window" },

    center = true,
})

hl.window_rule({
    name  = "floating-window-size",
    match = { tag = "floating-window" },

    size = "800 600",
})

hl.window_rule({
    name  = "floating-apps-tag",
    match = { class = "(blueberry.py|Impala|Wiremix|org.gnome.NautilusPreviewer|com.gabm.satty|Omarchy|About|TUI.float)" },

    tag = "+floating-window",
})

-- Volume control (pwvucontrol)
hl.window_rule({
    name  = "pwvucontrol-float",
    match = { class = "com.saivert.pwvucontrol" },

    float = true,
})

hl.window_rule({
    name  = "pwvucontrol-center",
    match = { class = "com.saivert.pwvucontrol" },

    center = true,
})

hl.window_rule({
    name  = "pwvucontrol-size",
    match = { class = "com.saivert.pwvucontrol" },

    size = "800 900",
})

hl.window_rule({
    name  = "file-dialogs-tag",
    match = {
        class = "(xdg-desktop-portal-gtk|sublime_text|DesktopEditors|org.gnome.Nautilus)",
        title = "^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files)",
    },

    tag = "+floating-window",
})

-- No transparency on media windows
hl.window_rule({
    name  = "media-opaque",
    match = { class = "^(zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$" },

    opacity = "1 1",
})

-- Fullscreen screensaver
hl.window_rule({
    name  = "screensaver-fullscreen",
    match = { class = "Screensaver" },

    fullscreen = true,
})

-- Pin workspaces to specific monitors
hl.workspace_rule({ workspace = "1", monitor = "DP-3", default = true }) -- bottom center
hl.workspace_rule({ workspace = "2", monitor = "DP-2" })                 -- top center

-- Portrait monitors: master on bottom, halved — near eye level on a tall screen.
-- Slaves lay out side-by-side above the master, so these read well at two
-- windows and get cramped past that.
--
-- Layout follows the monitor, not the workspace number. Numbered pins
-- still seed 3/4/5/8 at creation; the m[] rules plus create/move hooks
-- cover anything else that lands on DP-1/DP-4 (e.g. workspace 7).
local portrait_monitors = { ["DP-1"] = true, ["DP-4"] = true }
local portrait_layout   = { orientation = "bottom", mfact = 0.5 }
local landscape_layout  = { orientation = "left",   mfact = 0.6 }

local function layout_for(mon)
    if mon and portrait_monitors[mon.name] then
        return portrait_layout
    end
    return landscape_layout
end

local function seed_workspace_layout(ws, mon)
    if not ws or ws.special then
        return
    end
    mon = mon or ws.monitor
    if not mon then
        return
    end
    hl.workspace_rule({
        workspace   = tostring(ws.id),
        layout_opts = layout_for(mon),
    })
end

for _, mon in ipairs({ "DP-1", "DP-4" }) do
    hl.workspace_rule({
        workspace   = "m[" .. mon .. "]",
        layout_opts = portrait_layout,
    })
end

for _, ws in ipairs({ { "3", "DP-1" }, { "4", "DP-4" }, { "5", "DP-1" }, { "8", "DP-4" } }) do
    hl.workspace_rule({
        workspace   = ws[1],
        monitor     = ws[2],
        layout_opts = portrait_layout,
    })
end

hl.on("workspace.created", function(ws)
    seed_workspace_layout(ws)
end)

hl.on("workspace.move_to_monitor", function(ws, mon)
    seed_workspace_layout(ws, mon)
end)

for _, ws in ipairs(hl.get_workspaces()) do
    seed_workspace_layout(ws)
end

-- Spare workspace (bots moved into herdr 2026-07-22)
hl.workspace_rule({ workspace = "9", monitor = "DP-3" })

-- Floating workspace for casual use
hl.workspace_rule({ workspace = "10", monitor = "DP-3" })

hl.window_rule({
    name  = "workspace-10-float",
    match = { workspace = "10" },

    float = true,
})

hl.window_rule({
    name  = "workspace-10-position",
    match = { workspace = "10" },

    move = "200 200",
})

hl.window_rule({
    name  = "workspace-10-size",
    match = { workspace = "10" },

    size = "700 1000",
})

-- Steam window fixes
hl.window_rule({
    name  = "steam-empty-focus",
    match = { title = "^()$", class = "^(steam)$" },

    stay_focused = true,
})

hl.window_rule({
    name  = "steam-empty-minsize",
    match = { title = "^()$", class = "^(steam)$" },

    min_size = "1 1",
})

-- App-specific workspace assignments
hl.window_rule({
    name  = "firefox-workspace",
    match = { class = "([Ff]irefox)" },

    workspace = "2",
})

hl.window_rule({
    name  = "spotify-workspace",
    match = { class = "([Ss]potify)" },

    workspace = "3",
})

hl.window_rule({
    name  = "discord-workspace",
    match = { class = "([Dd]iscord)" },

    workspace = "4",
})

hl.window_rule({
    name  = "obsidian-workspace",
    match = { class = "(obsidian)" },

    workspace = "5",
})
