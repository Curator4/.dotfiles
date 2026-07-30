-- Hyprland autostart config
--
-- NOTE: With UWSM, autostart is handled by XDG autostart (~/.config/autostart/)
-- This file is kept for Hyprland-specific launches that don't belong in XDG autostart.
--
-- `exec-once =` has no lua equivalent; it is an hl.exec_cmd inside the
-- hyprland.start event, which fires once per compositor start (not per reload).

hl.on("hyprland.start", function()
    -- Phone-facing Claude Code bots — panes in the dedicated "bots" herdr session,
    -- separate from the default one (starts that server headless if needed).
    -- View: any terminal, `herdr --session bots`. Revive after a server stop or
    -- crash: re-run `herdr-bots`.
    hl.exec_cmd("herdr-bots")

    -- Household HUD — attention board panel on DP-4
    hl.exec_cmd("eww daemon")
    hl.exec_cmd("sleep 2 && eww open hud")
end)
