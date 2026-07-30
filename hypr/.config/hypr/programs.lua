-- Programs referenced from keybinds. Was a set of hyprlang $variables; lua
-- modules do not share locals, so this returns a table keybinds.lua requires.

return {
    terminal    = "kitty",
    fileManager = "thunar",
    menu        = "rofi -show drun",
    ssh         = "rofi -show ssh",
    browser     = "firefox",
    spotify     = "spotify-launcher",
    ncspot      = "kitty -e ncspot",
}
