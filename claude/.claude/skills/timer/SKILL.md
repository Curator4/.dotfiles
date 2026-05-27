---
name: timer
description: Set a desktop timer with a themed countdown bar on the right monitor (DP-4) and a mako notification when it ends. Use when the user says "set a timer", "remind me in X", "X-minute timer", "X-minute pomodoro", "timer for X", "give me a Y break", "start a countdown", or wants a visual countdown. Also handles cancellation phrasings — "cancel the timer", "stop the timer", "kill the timer".
argument-hint: "[duration] [message]"
---

# timer — Desktop Timer

Run the `timer` CLI (wrapper at `~/.local/bin/timer`, source at `~/.config/fish/functions/timer.fish`). The timer shows a themed bar at the top of DP-4 with a draining progress bar, then fires a color-matched mako notification when it ends.

## Invocation

```
timer [-c COLOR] DURATION [MESSAGE...]
timer cancel
```

- `DURATION` accepts mixed `s/m/h/d` suffixes — `45s`, `30m`, `1h30m`, `2h`
- `MESSAGE` is the notification body (defaults to `"time's up"`)
- `-c COLOR` is one of `red green yellow blue purple cyan` (default `red`)

## Natural-language → CLI mapping

| User says | Run |
|---|---|
| "set a 25 min pomodoro" | `timer -c blue 25m pomodoro` |
| "remind me in 10 min to check the oven" | `timer -c red 10m check the oven` |
| "2 hour focus block" | `timer -c purple 2h focus block ended` |
| "5 min break timer" | `timer -c green 5m break over` |
| "give me 90 seconds" | `timer 90s` |
| "cancel the timer" / "stop the timer" | `timer cancel` |

## Color picking (when user doesn't specify)

- focus / pomodoro / deep work → `blue` or `purple`
- break / stretch / exercise → `green`
- oven / urgent / cooking / "don't forget" → `red`
- ambient / soft reminder → `yellow` or `cyan`

Default to `red` if nothing about the task hints otherwise.

## Behavior notes

- Only one timer at a time. Starting a new one replaces the active one (no overlap).
- The bar reserves screen space at the top of DP-4 while active (pushes windows down). It disappears 5s after the timer ends.
- `timer cancel` kills the worker and closes the bar without firing the notification.
- The bar and the mako notification both use the same color, so glanceability is consistent across surfaces.
