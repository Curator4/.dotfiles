-- Palette of the active theme.
--
-- ~/.config/current-theme is a symlink that theme-switcher.sh repoints; dofile
-- resolves it at config-load time, so `hyprctl reload` picks up a switch. This
-- is the lua stand-in for what used to be `source = ~/.config/current-theme/
-- hyprland.conf` seeding global $border_active and friends.

return dofile(os.getenv("HOME") .. "/.config/current-theme/hyprland.lua")
