-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Cursor size
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- hyprshot
hl.env("HYPRSHOT_DIR", os.getenv("HOME") .. "/pictures/hyprshot")

-- NVIDIA-specific
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Force all apps to use Wayland
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("OZONE_PLATFORM", "wayland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- Allow better support for screen sharing
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- XWayland scaling
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})
