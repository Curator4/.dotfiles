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

    -- eww (timer bar, AI companion) and the hud board
    hl.exec_cmd("eww daemon")
    hl.exec_cmd("systemctl --user start hud.service")
    hl.exec_cmd("sleep 3 && /home/curator/.local/bin/hud-desktop --layer-host --url http://127.0.0.1:8877/hud-board --runtime-dir /home/curator/.local/state/hud/board/runtime warm")

    -- Resident fan-control rail on DP-4; IPC only flips its visible state.
    hl.exec_cmd("qs -n -d -c fan-rail")

    -- Themis curation panel: pre-warm the scratchpad window (parked in
    -- special:themis, invisible) so Super+T slides it in instantly,
    -- and watch for the page's Escape dismiss signal.
    hl.exec_cmd("~/.config/hypr/scripts/themis-inbox.sh warm")
    hl.exec_cmd("~/.config/hypr/scripts/themis-panel-watchd")
end)
