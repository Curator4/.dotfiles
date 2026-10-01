-- The ganymede app: a Chromium --app window at ganymede.localhost. Chromium
-- ignores --class on Wayland and derives the app-id from the host, the path
-- and the profile, so match that. The browser tag already tiles it where it
-- opens; this takes the blur off. require("ganymede") from rules.lua once
-- install.sh has copied this file to ~/.config/hypr/ganymede.lua.
hl.window_rule({
    name    = "ganymede-app-noblur",
    match   = { class = "^chrome-ganymede\\.localhost__-Default$" },
    no_blur = true,
})
