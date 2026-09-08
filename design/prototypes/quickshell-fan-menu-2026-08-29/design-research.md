# Vertical fan-command drawer: design research

Date: 2026-08-29

Scope: first-party interaction guidance for a narrow, transient right-edge controller whose buttons each issue one direct fan command. This note intentionally treats device state as potentially stale and does not assume that a successful transport response proves the physical state.

## Findings and implications

### Treat it as a right-side utility pane, not a navigation sidebar

GNOME defines a utility pane as a vertical side panel for supplementary controls. It says subordinate panes belong on the right, may be transient, and should overlap content when width is constrained. Microsoft documents the same overlay/compact-overlay drawer shape, including panes that can open from the right.

Implication: slide a narrow command drawer over the outer-right monitor edge, summoned by the hotkey. Keep the closed state fully hidden or, if discoverability is later needed, use only a small noninteractive edge mark; do not reserve desktop width. The pane should read as one compact tool, not as a full-height settings page.

Sources:

- [GNOME HIG: Utility Panes](https://developer.gnome.org/hig/patterns/containers/utility-panes.html) — “Utility panes can appear on the left or right side of the window.”
- [Microsoft WinUI: Split view control](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/split-view) — documents right-side, overlay, and compact-overlay pane modes.

### Use a stack of actual buttons, not rows containing controls

Apple recommends consistent button sizes within a set, a prominent style for only the most likely action, and press feedback for custom buttons. GNOME likewise recommends one or two consistent widths, short imperative labels, and no hidden double-click or right-click behavior. Its strong suggested/destructive treatment is limited to one button per view.

Implication: each command should be one full-width vertical tile with one hit area and a short verb-first label: `Turn On`, `Turn Off`, `Speed 1`, `Natural Air`, `Swing Left–Right`. Avoid a “row” anatomy with a label on the left and tiny toggle, chevron, or value control on the right. Keep all tiles the same height and width. Use styling, not a larger tile, if one action deserves emphasis; make at most one action strongly accented. Group Power, Speed, Airflow, and Swing with whitespace and small section labels rather than enclosing every command in a row-like card.

Sources:

- [Apple HIG: Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) — “Always include a press state for a custom button.”
- [GNOME HIG: Buttons](https://developer.gnome.org/hig/patterns/controls/buttons.html) — recommends consistent widths, short imperative labels, and a single strongly styled action.
- [GNOME HIG: Menus](https://developer.gnome.org/hig/patterns/controls/menus.html) — recommends logical ordering, grouping similar commands, and reserving easy-to-target endpoints for important actions.

### Make the buttons comfortably larger than the accessibility floor

Material's official Android guidance sets a 48 dp minimum interactive target. Apple gives a 44 by 44 point general minimum. WCAG 2.2 requires at least 24 by 24 CSS pixels at Level AA; its enhanced 44 by 44 criterion specifically recommends going larger for frequently used controls and controls near a screen edge.

Implication: for this desktop drawer, use 64–72 px-high full-width buttons with 8–12 px clear gaps. Those dimensions are a design recommendation, not a platform rule; they deliberately exceed the formal minima and make a fast edge-launched controller easy to click. Padding around an icon does not help if adjacent expanded hit regions overlap, so the visible tile itself should own the whole target.

Sources:

- [Android Developers: Minimum touch target sizes](https://developer.android.com/develop/ui/compose/accessibility/api-defaults#minimum-touch-target-sizes) — “set the minimum size to 48dp”.
- [Apple HIG: Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) — gives a general 44 by 44 point hit-region minimum.
- [W3C WAI: Understanding Target Size (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum) — explains the 24 CSS pixel minimum and spacing exception.
- [W3C WAI: Understanding Target Size (Enhanced)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced) — gives a 44 CSS pixel enhanced target and recommends larger targets near screen edges.

### Prefer explicit On and Off commands when displayed state may be stale

Most general HIGs recommend a toggle for a normal binary setting. This appliance-control case is a justified exception because the UI cannot safely derive the next command from a possibly stale state. Google's official Home APIs distinguish command-only devices from devices that expose queryable state, and expose explicit `on()` and `off()` commands in addition to `toggle()`.

Implication: show separate `Turn On` and `Turn Off` buttons whose meaning never changes. Keep both callable even if an informational state label claims one is already true. Never turn one button into “the opposite action” based on cached state, and never label a command result as physical state unless a fresh readback verified it.

Sources:

- [Google Assistant SDK: Smart Home OnOff trait](https://developers.google.com/assistant/sdk/reference/traits/onoff) — defines `commandOnlyOnOff` for devices that cannot be queried for state and an explicit boolean OnOff command.
- [Google Home APIs: Control devices on Android](https://developers.home.google.com/apis/android/device/control) — explicitly offers `off()` and `on()`, then separately recommends reading or observing state after command completion.
- [W3C WAI: Button Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/button/) — distinguishes an ordinary button that triggers an action from a toggle button that must expose a current pressed state.

### Serialize brittle commands and show pending, completion, and failure

Google says Home API commands complete only after an API response, can throw execution-flow exceptions, and should surface actionable errors. Its Cloud-to-cloud contract explicitly separates `SUCCESS`, `PENDING`, `OFFLINE`, and `ERROR`, with post-command state present only when available. Apple recommends putting an activity indicator inside a button and changing its label when an action does not complete instantly. Microsoft says an indeterminate progress ring communicates an operation with unknown duration that blocks further interaction. GNOME recommends a short toast when an asynchronous operation terminates. W3C defines waiting, progress, successful results, and errors as status messages that must remain perceivable without moving focus.

Implication: permit one in-flight command at a time. On click, immediately show the pressed state, replace that button's leading icon with a small spinner, change its label to `Sending…`, and temporarily disable the other command buttons. Keep the drawer open until the command resolves.

- On transport success, show a brief check and a short toast whose wording matches the real contract: `Command sent` for process success, or `Command accepted` for a relay acknowledgement. Say `Fan is on` only after fresh device readback.
- On failure or timeout, keep the drawer open, restore all buttons, and show a short error toast such as `Fan did not respond`; the original button remains the easy retry.
- Do not use an optimistic selected state as acknowledgement; it collapses “button was clicked,” “command returned,” and “fan physically changed” into one misleading signal.

Sources:

- [Google Home APIs: Control devices on Android](https://developers.home.google.com/apis/android/device/control) — command calls await a response, may return exceptions, and should surface actionable failures.
- [Google Home Cloud-to-cloud: EXECUTE](https://developers.home.google.com/cloud-to-cloud/intents/execute) — defines distinct `SUCCESS`, `PENDING`, `OFFLINE`, and `ERROR` results, and returns post-command state only when available.
- [Apple HIG: Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) — recommends an in-button activity indicator and alternate progress label for actions that do not finish instantly.
- [Microsoft WinUI: Progress controls](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/progress-controls) — distinguishes indeterminate blocking progress from nonblocking progress.
- [GNOME Developer: Notifying the user with toasts](https://developer.gnome.org/documentation/tutorials/beginners/getting_started/adding_toasts.html) — recommends toasts when an asynchronous operation terminates.
- [GNOME HIG: Toasts](https://developer.gnome.org/hig/patterns/feedback/toasts.html) — reserves short transient toasts for individual events rather than ongoing state.
- [W3C WAI: Understanding Status Messages](https://www.w3.org/WAI/WCAG21/Understanding/status-messages) — covers waiting, progress, success, and error feedback without changing focus.

### Do not use a slider for speed

GNOME recommends sliders when values are numerous, relative adjustment matters, and real-time feedback is useful. That is the wrong interaction contract for a slow or brittle remote command path. WCAG also requires a single-pointer alternative to any drag operation.

Implication: expose a small number of useful speed presets as individual buttons. Each click sends one absolute command, for example `Speed 1`, `Speed 2`, `Speed 3`, and `Speed 4`; there is no scrubbing, repeated update stream, drag gesture, or client-side value that can drift away from the device.

Sources:

- [GNOME HIG: Sliders](https://developer.gnome.org/hig/patterns/controls/sliders.html) — reserves sliders for high-cardinality ranges where relative, real-time adjustment is useful.
- [W3C WAI: Understanding Dragging Movements](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html) — requires an equivalent single-pointer operation without dragging.

## Source-backed recommendation

Build a transient 280–320 px right-edge overlay with one single-column stack of 64–72 px full-width buttons. Group actions using whitespace and small labels, but keep every actionable item a whole button:

1. `Turn On`
2. speed presets as direct absolute commands
3. airflow-mode commands
4. explicit swing commands only where the CLI can express the requested end state
5. `Turn Off`

The width and exact height are local design judgments; the interaction model follows the sources above. Keep state readout secondary and plainly qualified (`Last read…`, `Unknown`) because it must never alter what a button will send. Serialize calls, show `Sending…`, and acknowledge the command rather than claiming a physical state without readback.

For the next mockups, explore visual treatments—not different command semantics:

- a quiet monochrome instrument stack with one restrained accent;
- larger labeled “paddle” buttons with strong negative space;
- compact square-ended keys in a thin dark utility drawer.

All three should preserve the same full-width vertical-command structure, explicit On/Off controls, no slider, and the pending/success/error states above.
