-- Hyprland config. Lua replaced hyprlang in 0.55; .conf support is dropped in
-- 0.57. The old *.conf files are still here and still valid — Hyprland prefers
-- hyprland.lua when it exists, so `mv hyprland.lua hyprland.lua.off` falls all
-- the way back.
--
-- Load order matters the same way `source =` did: the palette must exist before
-- styling reads it, and theme-effects overrides decoration/animation on top of
-- styling. Each module is required for its side effects on the `hl` API.

require("env")
require("monitors")
require("styling")
require("theme-effects")
require("input")
require("keybinds")
require("rules")
require("autostart")
