# Themes

Curated desktop themes for `theme-switcher.sh`. Each subdirectory is one theme.

**Apply (existing theme):**

```bash
theme                 # rofi picker (same as the waybar theme click)
theme nord            # apply by slug
theme list
theme current
```

Boot picks a random desktop theme once per boot via `theme-startup.sh` (autostart).

**Author (new theme)** — do not hand-roll a full palette from scratch unless you want to. Use the authoring tools, then hand-tune:

| Tool | When |
|------|------|
| `theme-scaffold wallpaper <image> [--name slug]` | Draft theme from a wallpaper (ImageMagick) |
| `theme-scaffold base16 <name\|file\|url>` | Draft from a Base16 scheme (tinted-theming name, YAML, or URL) |
| `theme-lint [slug\|path]` | WCAG contrast + completeness; `theme-lint --all` for every desktop theme |

Scaffold writes under `themes/<slug>/` with `draft: true` and a `DRAFT.md` checklist. It does **not** apply the theme. Apply path stays `theme-switcher.sh`.

```bash
theme-scaffold wallpaper ~/pictures/wallpapers/static/foo.png --name cool
theme-lint cool
# edit theme.json: wallpapers, nvim.colorscheme, obsidian.cssTheme
theme-switcher.sh apply cool
```

```bash
theme-scaffold base16 gruvbox-dark-medium --name gruv
# set real wallpapers (placeholders will fail hyprpaper) then lint + apply
```

## What a theme directory contains

| File | Role |
|------|------|
| `theme.json` | Source of truth: palette, wallpapers, monitors, nvim, hue, font, effects |
| `kitty.conf` | Terminal colors (also linked via `~/.config/current-theme`) |
| `hyprland.lua` | Borders/accent for Hyprland |
| `mako.conf` / `starship.toml` | Mako is **colors only** (chrome is `mako/layout.conf`); starship copied on apply |
| `waybar.css` / `hyprlock.conf` | Often legacy stubs; live waybar/hyprlock are **rendered** by `theme-render.sh` on apply from palette |

Older themes may omit `palette` in `theme.json` and rely on `kitty.conf` only — `theme-lint` and the switcher still understand that.

`terminal_only: true` themes (e.g. `grok-night`) are for `theme-term.sh`, not desktop apply.

**Time-of-day wallpapers:** optional `wallpaper_schedule` overrides a monitor by clock time. Apply picks the current slot; `theme-wallpaper-schedule.timer` re-applies at 07:00 and 19:00 without a full theme switch. Keep those OnCalendar times in sync with `morning_start` / `evening_start`.

```json
"wallpaper_schedule": {
  "DP-3": {
    "morning": "static[1]",
    "evening": "static[0]",
    "morning_start": "07:00",
    "evening_start": "19:00"
  }
}
```

`monitors.DP-3` stays the fallback (and the evening slot if `evening` is omitted). Morning is inclusive of `morning_start`, exclusive of `evening_start`.

## Agent notes

- User says “new theme”, “theme from wallpaper”, “base16 theme”, “check theme contrast”, or “theme authoring” → use `theme-scaffold` / `theme-lint`, not Aether, not a new skill.
- Never replace `theme-switcher.sh` with an external theming app.
- After scaffold: user usually still wants nvim/obsidian/wallpapers filled in before apply. Rofi is rendered from the palette.
- Full apply surface list and gitignore rules: `~/.dotfiles/README.md` § theming.
