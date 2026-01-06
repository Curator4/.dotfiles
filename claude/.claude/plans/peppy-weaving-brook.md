# Dynamic Theme Switcher for Waybar

## Overview
Create a dynamic theme switching system that allows changing themes across Hyprland, Waybar, Kitty, Hyprpaper, Mako, Rofi, and Hyprlock. Includes 4 new themes + existing osaka-jade (5 total). Integrates with Waybar via a custom module that opens a Rofi menu for theme selection.

## Themes to Create
1. **osaka-jade** (existing) - Complete with missing files
2. **cyberpunk-neon** (NEW) - Hot pinks, electric blues, purple highlights
3. **synth-blue** (NEW) - Cool blues, cyans, synthwave aesthetics
4. **purple** (NEW) - Purple/violet focused palette
5. **dark-gruvbox** (NEW) - Warm browns, oranges, earth tones

## Architecture

### Theme Structure
Each theme directory contains:
- `colors.conf` - Central color definitions
- `hyprland.conf` - Hyprland window manager colors
- `kitty.conf` - Terminal color palette
- `waybar.css` - Status bar styling
- `mako.conf` - Notification daemon colors
- `hyprlock.conf` - Lock screen colors
- `theme.json` - Metadata (name, icon, wallpaper mappings)

### Theme Switcher Script
**Location**: `/home/curator/.dotfiles/bin/theme-switcher.sh`

**Functions**:
- `list` - List available themes
- `current` - Show current active theme
- `apply <theme>` - Switch to specified theme

**Update Strategy**:
1. Update Hyprland source line in hyprland.conf
2. Update Kitty include line in kitty.conf
3. Copy theme-specific files (waybar.css, mako.conf, hyprlock.conf)
4. Update Rofi theme reference
5. Regenerate hyprpaper.conf with theme wallpapers
6. Reload services (Hyprland, Hyprpaper, Waybar, Mako, Kitty)
7. Save current theme to ~/.config/.current-theme

### Waybar Integration
**Custom Module**: `custom/theme`
- Display: Theme icon with tooltip showing theme name
- On-click: Launch rofi menu for theme selection
- Scripts:
  - `theme-display.sh` - Shows current theme info
  - `theme-menu.sh` - Opens rofi selector, applies theme

## Implementation Steps

### Phase 1: Create Theme Directories
Create 4 new theme directories under `/home/curator/.dotfiles/themes/`:
- `cyberpunk-neon/`
- `synth-blue/`
- `purple/`
- `dark-gruvbox/`

### Phase 2: Populate Theme Files
For each new theme, create 7 files with appropriate color palettes:

**Cyberpunk Neon Colors**:
- bg=#0A0E14, fg=#E0DEF4, accent=#FF006E, orange=#FF1493
- Hot pink borders, electric cyan accents

**Synth Blue Colors**:
- bg=#0C0E1A, fg=#B4C7E7, accent=#5CCFE6, orange=#FF6F91
- Cool blues with coral pink accents

**Purple Colors**:
- bg=#1E1325, fg=#E8D4F7, accent=#B565D8, orange=#FF9F43
- Deep purples with orchid highlights

**Dark Gruvbox Colors**:
- bg=#282828, fg=#EBDBB2, accent=#D79921, orange=#FE8019
- Warm browns, beiges, yellows

### Phase 3: Complete Osaka-Jade Theme
Add missing files to existing osaka-jade theme:
- Extract current waybar colors → `waybar.css`
- Extract current mako colors → `mako.conf`
- Extract current hyprlock colors → `hyprlock.conf`
- Create `theme.json` with osaka wallpaper mappings

### Phase 4: Create Rofi Themes
Create `.rasi` theme files in `/home/curator/.dotfiles/rofi/.config/rofi/`:
- `cyberpunk-neon.rasi`
- `synth-blue.rasi`
- `purple.rasi`
- `dark-gruvbox.rasi`

### Phase 5: Build Theme Switcher
1. Use existing `/home/curator/.dotfiles/bin/` directory
2. Create `theme-switcher.sh` with list/current/apply functions
3. Make executable: `chmod +x theme-switcher.sh`

### Phase 6: Waybar Integration
1. Create waybar scripts directory (already exists)
2. Create `theme-display.sh` - reads current theme, outputs JSON for waybar
3. Create `theme-menu.sh` - builds theme list, shows rofi, applies selection
4. Make scripts executable
5. Update `/home/curator/.dotfiles/waybar/.config/waybar/config.jsonc`:
   - Add `"custom/theme"` to `modules-left`
   - Add module configuration with exec/on-click

### Phase 7: Testing
1. Test theme listing: `./theme-switcher.sh list`
2. Test theme application for each theme
3. Verify all apps update correctly (Hyprland, Kitty, Waybar, Mako, Rofi)
4. Test waybar module click → rofi menu → theme switch
5. Verify wallpapers update on all monitors

## Critical Files

### New Files to Create
1. `/home/curator/.dotfiles/bin/theme-switcher.sh` - Main orchestration script
2. `/home/curator/.dotfiles/waybar/.config/waybar/scripts/theme-display.sh` - Waybar display
3. `/home/curator/.dotfiles/waybar/.config/waybar/scripts/theme-menu.sh` - Rofi menu launcher
4. Theme directories (4 new themes × 7 files each = 28 files)
5. 4 new Rofi theme files
6. Complete osaka-jade theme (add 4 missing files)

### Files to Modify
1. `/home/curator/.dotfiles/waybar/.config/waybar/config.jsonc` - Add custom/theme module
2. `/home/curator/.dotfiles/hypr/.config/hypr/hyprland.conf` - Will be updated by switcher
3. `/home/curator/.dotfiles/kitty/.config/kitty/kitty.conf` - Will be updated by switcher
4. `/home/curator/.dotfiles/hypr/.config/hypr/hyprpaper.conf` - Will be updated by switcher

## Wallpaper Mappings (Static Only)

**Note**: Using static images only, no videos. User will add proper themed wallpapers later.

### Cyberpunk Neon
- Static: `~/pictures/wallpapers/static/cyber_neon_catgirl.jpg`

### Synth Blue
- Static: TBD - user will add blue/synth themed static wallpapers

### Purple
- Static: TBD - user will add purple themed static wallpapers

### Dark Gruvbox
- Static: TBD - user will add warm/earth-toned static wallpapers

### Osaka Jade
- Static: `~/pictures/wallpapers/static/osaka-jade-bg.jpg` (DP-3: osaka-jade-bg-2.jpg)

Each theme.json will specify wallpaper paths that can be easily updated when user obtains proper themed wallpapers.

## Service Reload Order
1. Hyprland (`hyprctl reload`)
2. Hyprpaper (kill + restart)
3. Waybar (kill + restart)
4. Mako (kill + restart)
5. Kitty (`killall -SIGUSR1 kitty`)

## Dependencies
- `jq` - JSON parsing in bash scripts
- `rofi` - Theme selection menu (already installed)
- `notify-send` - Desktop notifications (already installed)
