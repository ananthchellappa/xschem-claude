# Issue 0067 — raw Tk key/mouse binds bypass the action-registry logger

**Opened:** 2026-07-02
**Status:** OPEN — identified by the action-log coverage audit; not yet fixed.
**Severity:** MED — these are bound keys the user presses expecting parity with
other shortcuts, but they run mutating/highlight commands directly, outside
`dispatch_input_action`, so nothing is logged.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit of unlogged user interactions.
**Affects:** `src/change_index.tcl:19–20`, `src/cadence_style_rc` (:103–105,
:233, :140, :166), `utils/apply_hilight.tcl:130–131`,
`utils/lib_mgr_helpers.tcl:9`, `utils/cadence_nav.tcl:354`.
**Related:** [[action-logging]], [[action-registry]], [[bus-transpose]],
[[cadence-bindkeys]]; 0068 (legacy C switch keys — sibling); umbrella 0071.

---

## 1. Symptom

Several keys/buttons are wired with raw `bind <widget> <key> {…}` in Tcl and call
`xschem <sub>` (or a Tcl proc that does) directly. Because they never reach the C
input-binding table / `dispatch_input_action`, the Layer A logger never fires and
the action is unrecorded — unlike registry-dispatched shortcuts.

## 2. Root cause

`dispatch_input_action` (`callback.c:3409`) logs only chords that arrive via
`xschem callback` and match the registered binding table. A raw `bind … {xschem
…; break}` in a Tcl rc runs the command itself and (with `break`) may even
suppress the dispatch path, so no log line is emitted. The invoked subcommands
(`setprop`, `hilight*`, `place_symbol`, …) also don't self-log.

## 3. Scope — mutating / highlight raw binds

- `+` / `-` → `change_index 1|-1` → `xschem setprop instance $i lab …` (bus index
  ±1) — `change_index.tcl:19–20`. **Schematic mutation, fully unlogged.**
- `9` / `8` / `0` → `xschem hilight_net_interactive` /
  `unhilight_net_interactive` / `unhilight_all` — `cadence_style_rc:103–105`.
- `F5` → `apply_hilight {…}`; transient `<ButtonRelease>`/`<KeyPress>` →
  `aphl::on_release`/`on_key` apply highlight to the clicked net —
  `cadence_style_rc:233`, `apply_hilight.tcl:130–131`.
- `Ctrl-Alt-N` → `place_libmgr_selection` → `xschem place_symbol $f`
  (`lib_mgr_helpers.tcl:9`) — launch unlogged (drop later logs a `#` stub, 0069).
- `Ctrl-Alt-D` → `cadence::deeploc_note` → places a text note
  (`cadence_nav.tcl:354`) — launch unlogged.

(Borderline, view-state only: Alt-minus prev-hilight-style cursor; Ctrl-2 /
Ctrl-Shift-2 make-editable/readonly toggles.)

## 4. Fix sketch

Migrate these chords into the action registry (`xschem bind key … <action_id>`)
so `dispatch_input_action` logs them — the same route `cadence_style_rc` already
uses for its wheel/`Ctrl-G` binds. For the `+`/`-` bus-index case, either register
a `change_index` action or have `setprop` self-log (guarded). The interactive
hilight click binds need a replayable command form (relates to 0005 stable
referents for click position).
