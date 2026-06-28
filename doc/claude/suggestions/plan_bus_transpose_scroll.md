# Plan — ALT+SHIFT+ScrollWheel bustranspose (RED-first)

Spec: `doc/claude/specs/bus_transpose_scroll.md`. Branch `fluid-editing`. Builds on the
ALT+wheel busresize feature (shares its single-undo applier + the bind registry).

## Slices

1. **Docs** — spec + this plan. (done)

2. **RED tests** — `tests/bus_transpose.tcl`
   (`../src/xschem --nogui --pipe -q --script bus_transpose.tcl`):
   - Pure transform (source `utils/bus_transpose.tcl`):
     - grow: `dat`→`dat[0]`; `dat[0]`→`dat[1]`; `dat[7]`→`dat[8]`; range left alone
       `clk[1:0]`→`clk[1:0]`.
     - shrink: `dat[1]`→`dat[0]`; `dat[0]`→`dat`; `dat`→`dat` (floor); range `clk[1:0]`
       unchanged.
     - round-trip: shrink(grow(x))==x for `dat` and `dat[3]`.
   - Integration (needs xschem): net label `lab=bus` grow→`bus[0]`→`bus[1]`,
     shrink→`bus[0]`→`bus`; generic instance `name` grow. A selection that ALSO holds a
     wire and a text: those are unchanged (tolerated), label still transposes.
   - Single-undo: two labels selected, one grow, one `xschem undo` reverts both.
   - Confirm RED before implementing.

3. **Tcl** —
   - `utils/bus_resize.tcl`: extract `busresize::apply_changes {changes}` from
     `busresize_apply` (pass-2: collect-then push_undo once / `setprop -fast` /
     `recompute_inst_bbox` per instance / one `redraw`); `busresize_apply` now builds
     its change list and calls it.
   - `utils/bus_transpose.tcl` (new): namespace `bustranspose` (vars `open ] close ]`...
     i.e. `open [`, `close ]`); `_split` (name -> {base int} or {}); `grow_name` /
     `shrink_name`; `bustranspose_apply {dir}` collecting only `instance` objects
     (label/pin→`lab`, else→`name`), skipping wire/text/others, then
     `busresize::apply_changes`.

4. **C** — `src/callback.c`:
   - `handle_mouse_wheel()`: introduce normalized mask `m`; change the Shift / Ctrl
     branches to `m == ShiftMask` / `m == ControlMask` (exact) so Alt+Shift et al. fall
     to the else → canvas bind table. No-mod / lone-Shift / lone-Ctrl behavior intact.
   - `action_registry[]`: add `edit.transpose_grow_selection` /
     `edit.transpose_shrink_selection` (Tcl `bustranspose_apply grow|shrink`).
   - `action_id_mutates`: add both.
   - `make`; re-run tests GREEN.

5. **Wire-up + verify** — `src/cadence_style_rc`: source `utils/bus_transpose.tcl`;
   `xschem bind wheel up alt+shift canvas edit.transpose_grow_selection` + the down
   shrink. GUI smoke via synthesized Alt+Shift wheel (state = Mod1|Shift = 9): label/
   instance index grows/shrinks, a co-selected wire is untouched, one undo reverts a
   multi-object notch, and the older ALT-only busresize still works. Regression suite.
   Commit + push.

## Risks / notes
- The exact-mask change makes Ctrl+Shift+wheel stop panning (now bind-table, unbound =
  no-op). Acceptable; documented. Lone Ctrl/Shift unchanged — verify ALT-only busresize
  AND a plain/Shift/Ctrl wheel still behave.
- Reuse, don't duplicate, the single-undo applier — both features must stay one-undo.
