local theme = require("theme")

-- https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 5,

        border_size = 2,

        col = {
            active_border   = theme.border_active,
            inactive_border = theme.border_inactive,
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "master",
    },

    decoration = {
        rounding = 0,

        -- Change transparency of focused and unfocused windows
        -- active_opacity   = 0.95,
        -- inactive_opacity = 0.85,

        shadow = {
            enabled      = true,
            range        = 2,
            render_power = 3,
            color        = theme.shadow,
        },
    },

    -- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
    master = {
        new_status  = "slave", -- new windows go into the right-side stack, not as a new master
        new_on_top  = false,   -- append at bottom of stack
        mfact       = 0.6,     -- master takes 60% of width
        orientation = "left",  -- master on left, stack on right
        -- Portrait monitors (DP-1/DP-4) override both via layout_opts in rules.lua.
        -- mfact seeds a workspace at creation and is not re-applied on reload.
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = true,
    },
})
