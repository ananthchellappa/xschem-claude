# Ctrl-N → open a new blank editor window (scratchpad)

Status: SPEC. Related memory: [[cadence-bindkeys]], [[cadence-note-nav]],
[[multi-window-detach]], [[descend-newwin-return-chain]], [[user-run-config]].

## 1. Goal

Repurpose **Ctrl-N** (in the user's Cadence interaction mode) from its current
**Clear Schematic** action — which *destroys the current schematic in place* — to
**open a new blank editor window**: a fresh `untitled.sch` in its own top-level window,
leaving the schematic the user was in **completely untouched**. The user wants a
throwaway scratchpad; they can keep working in it or close the old window.

## 2. Current behaviour (what changes)

Ctrl-N today is the table-driven default `file.clear_schematic`
(`keybindings.csv:47` → keycode 110+ctrl; `callback.c:3053`), running
`xschem clear schematic` → `clear_schematic(cancel=1, symbol=0)` (`actions.c:2852`):
it prompts to save, then **discards the current buffer** and resets to a blank
`untitled.sch` *in the same window*. Destructive to the current view.

## 3. New behaviour

Ctrl-N opens a **new real top-level window** containing a blank `untitled.sch`; the
current window/schematic is unchanged and the new window becomes the focused context.

Mechanism (verified): `xschem new_schematic create_window {}`
- `create_window` forces a real top-level window even under the tabbed interface
  (`new_schematic()`/`create_new_window()`, xinit.c) — the user asked for a *window*.
- empty win_path → auto-assigned (`.x1.drw`, …); no filename → `load_schematic(1, "", …)`
  → a blank untitled schematic.
- `create_new_window()` already **clones the `.drw` cadence bindings** into the new
  window (`clone_canvas_bindings`, xinit.c:1832), so the scratchpad has the same
  shortcuts (including this Ctrl-N).
- It is **additive**: the source window keeps its schematic and edits (no save prompt,
  nothing discarded).

Verified headlessly: from a window showing `a.sch` (1 instance),
`xschem new_schematic create_window {}` → current window becomes `.x1.drw`,
`untitled.sch`, 0 instances; `xschem windows` lists both; the original `.drw`/`a.sch`
is intact.

## 4. Implementation

Pure Tcl, scoped to the user's mode (consistent with the other Cadence shortcuts):

- Helper `cadence::new_blank_window` in `utils/cadence_nav.tcl`:
  ```tcl
  proc cadence::new_blank_window {} {
    xschem new_schematic create_window {}
    xschem log_action "xschem new_schematic create_window {}"   ;# replayable (cf. issue 0055)
    ciw_echo "new blank window: [xschem get current_win_path]"
  }
  ```
- Bind in `src/cadence_style_rc` (overrides the default Ctrl-N for `.drw`, exactly how
  the other cadence binds override C defaults; the more-specific `<Control-Key-n>` wins
  and `break` stops fallthrough):
  ```tcl
  bind .drw <Control-Key-n> {cadence::new_blank_window; break}
  ```

## 5. Scope & decisions

1. **Scoped to `cadence_style_rc`, not the global default.** Clear Schematic stays the
   vanilla-xschem Ctrl-N and stays on the **File menu** (its menu item is untouched), so
   nothing is lost — it is simply no longer on Ctrl-N *in this mode*. Matches how the
   user's other shortcuts (Ctrl-E, Ctrl-X, Ctrl-Shift-N…) already re-skin defaults.
   (If a global change is later wanted: edit `keybindings.csv` + the `actions.csv`
   accelerator, out of scope here.)
2. **Real window, not a tab** (`create_window`) — the user said "window" and wants to be
   able to close it independently.
3. **Window vs symbol:** always a schematic scratchpad (`untitled.sch`).
4. **Focus/raise:** a freshly mapped top-level gets focus on WSLg (the issue-0054 raise
   saga: a fresh *map* is granted focus), so no explicit raise is needed. Revisit only
   if the new window comes up unfocused in practice.
5. **Menu accelerator label:** File → Clear Schematic still shows "Ctrl+N"; in cadence
   mode that hint is now stale (same pre-existing cosmetic wrinkle as the other
   cadence-overridden accelerators). Not fixed here.

## 6. Test plan (RED-first)

Headless (`xschem --nogui --pipe -q --script`):
- Load `a.sch` (1 instance). Call `cadence::new_blank_window`. Assert: current window
  changed; `xschem get instances` == 0; `[file tail [xschem get schname]]` == `untitled.sch`;
  `[llength [xschem windows]]` == 2.
- Switch back to the original window; assert it still has `a.sch` (1 instance) — proves
  non-destructive.
(The `clone_canvas_bindings … winfo` message under `--nogui` is a Tk-absent artifact and
non-fatal; the window is still created. The actual key-press→helper and focus are
manual GUI.)

## 7. Acceptance criteria

Status: IMPLEMENTED. `tests/cadence_new_window.tcl` green (8 checks).

1. ✅ Ctrl-N opens a new top-level window with a blank `untitled.sch`
   (`xschem new_schematic create_window {}`). ◻ key-press→helper + focus: manual GUI.
2. ✅ The schematic the user was in is unchanged (test switches back and asserts
   `a.sch` / 1 instance — no discard, no save prompt).
3. ✅ `cadence::new_blank_window` headless test green (new blank window + original intact).
4. ✅ Clear Schematic remains available on the File menu (unchanged; only the
   cadence-mode Ctrl-N key is rebound).
