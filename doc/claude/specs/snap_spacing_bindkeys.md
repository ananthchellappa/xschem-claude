# Alt+Up / Alt+Down — snap spacing x2 / x0.5, always logged

Status: **implemented**.
Related: `src/cadence_style_rc` (the two bind lines), `src/callback.c`
(`view_snap_change` — the core and its self-log), `src/util.c` / `src/util.h`
(`log_action_result`), `tests/headless/test_snap_bindkeys.tcl`,
`tests/headless/test_phase3_mints.tcl`.
Builds on: `doc/claude/specs/keybind_snap_grid_actions.md` (the actions and why they
ship unbound), issue `doc/claude/issues/0066-xschem-set-config-changes-not-logged.md`
(the "log the resolved absolute value" rule), `doc/claude/specs/action_logging.md`.

## 1. What the user gets

Two Cadence-style snap-spacing bindkeys, active under `cadence_style_rc`:

| Chord | Keysym + mods | Action | Effect |
|---|---|---|---|
| **Alt+Up** | 65362 + `alt` | `view.snap_double` | `cadsnap` **x2** (coarser snap) |
| **Alt+Down** | 65364 + `alt` | `view.snap_half` | `cadsnap` **x0.5** (finer snap) |

- Works in the **schematic** editor **and the symbol** editor. There is one canvas
  and one input-binding table; the chord is dispatched by `dispatch_input_action()`
  on the `canvas` context, which knows nothing about what kind of cellview is
  loaded, so both get it for free.
- Works on a **read-only** view (Cadence-style browse mode, `descend_readonly 1`):
  snap is edit *geometry*, not saved content, so `view.snap_*` are not flagged
  `mutates` and `readonly_block()` does not touch them.
- **Plain (unmodified) arrows are untouched** — they still scroll the viewport
  (`view.scroll_up` / `view.scroll_down`). Only the `alt` chord is claimed.

`cadgrid` (the displayed dot pitch) is a **separate** value and is deliberately not
moved by these keys; there is no halve/double action for it. Set it outright with
`xschem set cadgrid <value>` (also self-logged) or View > Set grid spacing.

## 2. Remappable

Nothing is hardcoded: the chords are two `xschem bind` rows in `cadence_style_rc`,
against actions that ship **unbound** (that is the contract of
`keybind_snap_grid_actions.md` §4 and it is unchanged — the default binding table
still has no snap row; only the user's rc attaches one).

```tcl
xschem bind key 65362 alt canvas view.snap_double     ;# Alt+Up   : snap x2
xschem bind key 65364 alt canvas view.snap_half       ;# Alt+Down : snap x0.5
```

Remap by editing those lines, by binding at runtime from the CIW
(`xschem bind key 65451 ctrl canvas view.snap_double` for Ctrl+KP_Add), or from a
`keybindings.csv` in `USER_CONF_DIR`. Un-bind with
`xschem unbind key 65362 alt canvas`. Arrow keysyms: Up=65362, Down=65364,
Left=65361, Right=65363.

Modified **named** keys reach the table unchanged: `handle_key_press` uses
`kmods = (key < 0xff00) ? rstate : state`, and an arrow keysym is `>= 0xff00`, so
the raw modifier mask (Alt = `Mod1Mask` = 8) is what the binding matches — no
Shift-strip surprise of the kind printable keys have.

### Gotcha: `event generate <Alt-Key-Up>` is NOT a physical Alt+Up

Writing a Tk-level test for this chord, use `event generate .drw <Key-Up> -state 8`,
never `event generate .drw <Alt-Key-Up>`. The `<Alt-…>` shorthand makes Tk fill in
its **own** synthetic ALT_MASK (`AnyModifier<<2` = 131072), a bit no real X event
ever carries; the chord then misses the binding table and falls through to the plain
Up scroll. A physical Alt+Up carries `Mod1Mask` (8), which `-state 8` reproduces
exactly. (Probe-verified on this tree: `<Alt-Key-Up>` delivered `%s=131072` and
scrolled; `-state 8` hit `view.snap_double` and did not scroll.)

## 3. Logging — the point of the feature

Every use writes **two lines**, to the action-log **file** and to the **CIW pane**:

```
xschem set cadsnap 20            <- replayable, ABSOLUTE
#= snap 10 -> 20 (x2)            <- human-readable outcome
```

Why absolute and not `xschem snap double`: the 0066 `cadsnap` rule — never log a
relative/gesture form when an absolute one exists. A replayed `xschem snap double`
lands on a different value whenever the start snap differs from record time. The
value is read **back** from `cadsnap` after the change, not computed, because
`set_snap()` maps 0 to the default.

The self-log lives at the **core**, in `view_snap_change()` (`callback.c`), so every
entry point logs identically and exactly once:

- the Alt+Up / Alt+Down chords → `dispatch_input_action` → `act_snap_double` /
  `act_snap_half` → `view_snap_change`;
- View > Double / Halve snap factor (menu);
- `xschem snap half|double` from a script or the CIW.

`log_action()` sets `actionlog_cmd_logged`, so the `actions.csv` `log_cmd` copy
(`xschem snap half|double`) that `dispatch_input_action` would otherwise add
**dedups away** — one line, not two. This is the same self-log-at-core dedup the
`y` / `toggle_stretch` key uses.

The outcome line goes through `log_action_result()` (`util.c`), a small shared sink
that writes a `#= ` comment to the file (so the log stays `source`-able for replay)
and echoes the same text to the CIW pane. `select.c`'s `select_net_report` — which
had its own hand-rolled copy of exactly this — now calls it too.

Rationale for the second line: a snap change otherwise announces itself only by the
statusbar field turning orange, which is invisible while the eye is on the
schematic. The command line alone states the new value but not the direction or
where it came from.

## 4. Tests

`tests/headless/test_snap_bindkeys.tcl` (in `full_audit.sh`'s `logdir_tests`) covers:
actions bindable to the chords; x2 / x0.5 in a schematic; the same in a **symbol**;
on a **read-only** view; the absolute command line + the `#= ` outcome in the file
**and** in the CIW pane; absence of the relative `xschem snap half|double` line;
`xschem snap double` from a script logging identically; the logged line **replaying**
to the same snap; unbind making the chord inert and a remap (Ctrl+KP_Add/Subtract)
working; plain Up/Down still scrolling and not touching snap; and that the shipped
`src/cadence_style_rc` really contains the two rows.

`test_phase3_mints.tcl`'s two `key g` / `key G` rows were **stale** — keysyms 103/71
were unbound when `keybind_snap_grid_actions.md` removed the defaults, so those two
checks had been failing ever since. They are replaced by Alt+Up / Alt+Down checks
asserting the absolute log form.
