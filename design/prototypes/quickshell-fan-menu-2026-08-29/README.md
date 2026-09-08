# Quickshell fan menu prototype

Throwaway, read-only UI exploration for a fan controller that opens from the
outer right edge of DP-4. The HTML never invokes `xiaomi-fan`.

## Run

From this directory:

```bash
chromium 'index.html?variant=A'
```

The second round, built around discrete vertical commands, is:

```bash
chromium 'discrete.html?variant=D'
```

The third round, rebuilt around Caelestia's small right-edge icon rail, is:

```bash
chromium 'rail.html?variant=G&theme=calliope'
```

Use the on-screen arrows or the left/right arrow keys to switch variants:

- `A` — full instrument drawer
- `B` — literal half-wheel / radial menu
- `C` — compact edge rail with a local popover

The controls mutate prototype state in memory only.

## Round 3 — small right-edge icon rail

This round takes only the form factor from Caelestia: a narrow edge object with
large icon targets. It does not copy Caelestia's colours or install any of its
shell code.

The selected `G` direction is now a dark sci-fi instrument rail. It exposes
power, levels 1–4, straight/natural airflow, horizontal swing, and vertical
swing. Command text is hidden in hover tooltips so the rail itself remains
icon-only. Each click still resolves to exactly one `xiaomi-fan` invocation and
locks the other controls until fresh readback.

The prototype's Theme button previews the same semantic role mapping with the
Calliope, Neon, and Cyber palettes. Calliope is the default because it is the
active desktop theme. The production seam is `theme.json`, reached through
`~/.config/current-theme`; the prototype embeds representative values only so
it remains a standalone HTML file.

- `G` — sculpted edge: a thin full-height spine that blooms into an eight-icon
  sci-fi control island, closest to the supplied reference.
- `H` — floating capsule: the same icons inside a detached glass pill.
- `I` — bare pebbles: independent icon buttons pinned to a thin accent line.

`G` is the selected direction. Its final chamfered frame sizes itself from the
complete icon stack, so power through vertical swing are always enclosed. The
frame uses one active-theme accent rather than a multicolour gradient. The other
two remain as earlier shape tests.

## Round 2 — discrete vertical commands

This round removes sliders, radial gestures, compound scenes, and ambiguous
toggles. Each action button maps to exactly one high-level CLI invocation, and
all other actions lock until that command confirms.

- `D` — full-height command ladder: the requested vertical version of A.
- `E` — six-button physical remote: only on, levels 1–4, and off.
- `F` — accordion deck: the full command set, with one vertical group open.

The speed labels now follow Xiaomi's own product language: slow, medium, fast,
and turbo. The UI uses explicit `on`/`off` commands instead of trusting cached
state enough to choose a toggle operation.

## Live context captured on 2026-08-29

- Fan: Xiaomi Smart Desktop Air Circulation Fan, model `xiaomi.fan.p70`.
- Existing CLI: `~/.local/bin/xiaomi-fan` with power, 1–100 speed, levels 1–4,
  straight/natural mode, and horizontal/vertical swing.
- Existing read model: confirmed commands update
  `~/.local/state/xiaomi-fan/status.json`; the Eww HUD polls only that cache.
- Live read at 18:13: power off, speed 1, level 1, straight mode, horizontal and
  vertical swing enabled, fault 2. The P70 MIoT property table labels fault 2
  as insufficient supply power.
- Display: DP-4 is the outer-right 1440×2560 logical portrait monitor. Its top
  282 px are already reserved for the Eww HUD.
- Theme: Calliope (`#08090B`, `#B4BAC2`, `#3E6FA8`, JetBrains Mono).
- Quickshell itself is not currently installed and no Quickshell config exists.
  Qt 6 Declarative and Qt 6 Wayland are present.

## Implementation seam verified

Quickshell's `PanelWindow` can anchor a decorationless window to the right edge
of a selected screen. An `IpcHandler` exposes typed functions to `qs ipc call`,
so a Hyprland binding can toggle the drawer without spawning a second shell.
`Quickshell.Io.Process` can invoke `xiaomi-fan` with an argument list and collect
its JSON output without shell interpolation.

Sources:

- <https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/>
- <https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/IpcHandler/>
- <https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/Process/>
- <https://home.miot-spec.com/spec/xiaomi.fan.p70>

## First-round verdict

The original A/B/C set was rejected as too rich and too dependent on continuous
controls for the relay path. It remains here only as the first-round source.

## Settled design — 2026-08-29

Build the selected G form in Quickshell. Its form factor, control density,
sci-fi skin, semantic theme mapping, and stack-wrapping border are approved. Preserve
the one-command-in-flight rule; do not carry the rejected drawer, radial, or
row-based variants into production.
