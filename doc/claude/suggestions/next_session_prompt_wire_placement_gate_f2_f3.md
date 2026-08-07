# Next-session prompt — issue 0233 F3 (the ESC hole) and F2 (the reverse door)

Paste everything below the line into a fresh session with cleared context.

---

Finish issue **0233** (`doc/claude/issues/0233-modal-gesture-exclusion-gated-at-one-of-thirteen-arm-sites.md`,
status **PARTIAL**). Two remaining pieces, **F3 first — it is smaller, needs no decision from the
user, and it is the one that still shows the user-visible symptom**. Tree is at `322be1b0`; every
anchor below was verified there. Re-derive line numbers by grepping the quoted statement, not by
trusting the number.

## Background you need before touching anything

Read in this order: `doc/claude/issues/0233-*.md` (the whole thing — it carries the measured
censuses), then `doc/claude/issues/0230-*.md` (the parent fix, especially its *Follow-up
2026-08-06* section: "wire-draw mode is THREE states"), then `doc/claude/WIRING.md` §7 landmines
**8, 9, 12**, §8 classes **D** and **H**, and §10 (testing traps).

The one-sentence model: a modal placement and a wire/line draw cannot coexist, because
`end_place_move_copy_zoom()` tests `STARTWIRE` (`callback.c:2872`) **before** the placement arm
(`:2927`), and under `persistent_command` the Button-1 handler (`callback.c:7843`) seizes the click
one step earlier still. So whichever gesture is armed second can never be completed.

Already fixed (do not redo): entering `l` / `p` / component insert leaves wire mode, via
`leave_wire_draw_for()` (`scheduler.c:68`) wrapping `abort_wire_line_command()`
(`callback.c:510`). That helper handles all three states of "wire mode" — live draw
(`ui_state & STARTWIRE`), menu-armed (`MENUSTART` + `MENUSTARTWIRE`), and **resting**
(`ui_state` clear, only `last_command` armed — the state after a double-click ends a segment,
diamond snap cursor up). The resting state was itself a shipped bug caught by the user; do not
write a new gate that only looks at `ui_state`.

---

## F3 — ESC leaves a half-drawn wire behind when `last_command` was zeroed

**Do this one first.** No policy question, small blast radius, and it is the surviving half of the
original user report ("there are grey lines of the same dimensions as the wire drawn").

`abort_operation()`'s wire/line teardown is nested inside `callback.c:351`:

```c
if(xctx->last_command && xctx->ui_state & (STARTWIRE | STARTLINE)) {
```

The `xctx->last_command &&` conjunct predates issue 0230 (commit `a797bc59`) and exists **only** to
protect the two-stage ESC in persistent command mode. But several arms zero `last_command` while
leaving `STARTWIRE` set:

- `case 't'` place text (`callback.c:6976`, arming `PLACE_TEXT` at `:6983`) and the context-menu
  Insert text (`:4327`, arming at `:4334`)
- `xschem rect gui` (`scheduler.c:9989`, inside the `rect` branch at `:9953`)
- `xschem polygon gui` (`scheduler.c:9078`, inside the `polygon` branch at `:9039`)
- `place_text` (`scheduler.c:8981`, arming `PLACE_TEXT` at `:8989`) and the bare `place_symbol` form

Confirm the list yourself with
`grep -n "xctx->last_command = 0;" src/callback.c src/scheduler.c` cross-referenced against the
`ui_state |= PLACE_*` / `STARTRECT` / `STARTPOLYGON` arms — the point is the *shape*, not the exact
membership.

With `last_command == 0` the guard is false, so **neither** the rubber `new_wire(RUBBER|CLEAR, …)`
at `:352` **nor** `ui_state &= ~(STARTWIRE|STARTLINE)` at `:375` runs. Control falls into the
`STARTMOVE` branch, tears the placement down, and hits `return;` at **`callback.c:406`** — which
never clears the shape bits and never reaches `ui_state = 0` (`:417`) or `draw()` (`:419`).

Measured at `322be1b0` (this reproduces headlessly):

```tcl
set ::infix_interface 1
xschem clear force; xschem wire 0 0 100 0; xschem unselect_all
xschem wire gui          ;# live draw:      ui=1  [STARTWIRE]  last_command=1
xschem add_sch_pin -place ;# (now gated, so use an UNGATED arm instead -- see note)
xschem rect gui          ;# `r`: zeroes last_command, keeps STARTWIRE
xschem abort_operation   ;# ESC
xschem get ui_state      ;# -> 3  [STARTWIRE|STARTRECT]   <-- the wire gesture SURVIVED
```

Note: `p` is gated now, so build the state with an arm that is still ungated (`r`, `P`, `t`), or
with `r` alone — the defect does not need a placement at all. Also verify the **non-wire** sibling:
`p` → `r` → ESC leaves `ui=2 [STARTRECT]`, i.e. `callback.c:406` leaks *every* shape-draw bit, not
just `STARTWIRE`.

Because `redraw_w_a_l_r_p_z_rubbers()` (`callback.c:241`) re-strokes the band only while
`STARTWIRE` is set, and the CLEAR never ran, the stroke has no owner left to erase it. That is the
grey-lines symptom.

**Proposed shape** (0233 already spells it out — verify it, do not assume):

```c
if(xctx->ui_state & (STARTWIRE | STARTLINE)) {
  … RUBBER|CLEAR + crosshair …                              /* unchanged, :352-354 */
  if(!(xctx->ui_state & (STARTMOVE | STARTCOPY | STARTMERGE))) {
    if(xctx->last_command) { xctx->ui_state = 0; return; }   /* a797bc59 two-stage ESC, unchanged */
  }
  xctx->ui_state &= ~(STARTWIRE | STARTLINE);
  if(xctx->last_command) keep_last_command = 1;
}
```

plus clearing `STARTRECT | STARTPOLYGON | STARTARC` before the `return;` at `:406` (or letting that
branch fall through to `:417`, which is a bigger change — measure before choosing).

**Think about the `last_command == 0 && no placement` case explicitly.** With the conjunct dropped,
a bare `STARTWIRE` with `last_command == 0` now takes the CLEAR + `ui_state = 0` path instead of
falling to the bottom. Decide whether it should `return` there or fall through to `unselect_all` /
`draw()`, and pin the choice with a check.

---

## F2 — the same clash entered backwards (needs a user decision first)

`l` / `p` / insert now cancel a wire. Nothing stops the opposite: arm a placement, then press `w`
(or `L`, or menu Wire). Measured at `322be1b0`:

```
after l   ui=16424 [SELECTION|STARTMOVE|START_SYMPIN]           last_command=0
after w   ui=16425 [STARTWIRE|SELECTION|STARTMOVE|START_SYMPIN] last_command=1
```

Same jam: wire wins every click, the preview rides the cursor and can never be dropped.
Add-Wire-Label has an accidental escape hatch (typing one more character re-issues `-place`, which
hits the gate and frees the wire while keeping the preview); **Add-Pin does not** — ESC is the only
exit and it throws the pin away.

**ASK THE USER BEFORE WRITING CODE**, exactly as issue 0230 did for `l`:

- **(a) `w` abandons the placement preview** and starts drawing — symmetric with what `l` now does
  to a wire, and consistent with the ratified rule *"whatever you just pressed is what you meant"*.
  **Recommended.**
- **(b) `w` declines** while a placement is live: the preview stays, the status bar says finish or
  cancel it first. Nothing is thrown away, but a key that silently does nothing reads as broken.

If (a): add an `abort_placement_preview()` helper — factor the existing block at
`callback.c:383-400` (`move_objects(ABORT)` → `delete(sympin_preview && START_SYMPIN ? 0 : 1)` →
`set_modify(save)` → clear `START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT`, `sympin_preview`,
`wirelabel_preview`) into a function and call it from `abort_operation()`, from `start_wire()`
(`callback.c:551`) and from `start_line()` (`:473`). **It must NOT be `abort_operation()`** — see
the comment at `callback.c:502-505` and the trap below. Issue **0232** wants the same helper for a
different set of callers; factor it once, in a way both can use.

---

## TRAPS

1. **0230's section G2 constructs the double-armed state on purpose.**
   `tests/headless/test_add_wire_label.tcl` (88 checks) builds it with `add_wire_label -place` then
   `xschem wire gui` — that is exactly reverse door F2. Fixing F2 makes
   `check "0230 both gestures armed" … 1` unreachable and the whole section stops testing what it
   was written for. Rebuild G2 on a different constructor (a direct seam that sets the flags) or
   move its intent into the new tests — do not just delete it, it is the only coverage of
   `abort_operation()`'s co-armed teardown.
2. **The one-undo-baseline-per-gesture rule.** A form's `-place` runs on *every keystroke*; if the
   new placement-teardown helper fires on a re-arm it clears `sympin_preview`, the next `-place`
   takes the fresh-arm branch and pushes a **second** baseline for one gesture
   (`doc/claude/specs/add_wire_label.md`, `cadence_pin_name_text.md` item #3). The forms never call
   `start_wire()`, so F2 should not hit this — prove it with a check rather than assuming.
3. **Preserve the `delete(0)` vs `delete(1)` discriminator** at `callback.c:393`.
   `add_graph`/`add_image`/merge arm `START_SYMPIN` with `sympin_preview == 0` and rely on
   `delete(1)` pushing undo. `tests/pin_name_text.tcl` regression 11 is an explicit sabotage check
   on this.
4. **Do not gate the scripted / pure-commit seams.** `add_wire_label -drop` and
   `add_symbol_pin <x> <y> …` commit outright, arm no cursor placement, and are the replay/test
   paths. `test_placement_wire_gate.tcl` section C2 pins that; keep it green.
5. **`xschem add_wire_label -drop` is not a faithful model of a GUI click.** It calls
   `wire_label_try_commit()` directly (`scheduler.c`) and bypasses `end_place_move_copy_zoom()`, so
   headlessly a label *does* drop while `STARTWIRE` is live where the GUI cannot. **Assert on the
   flags, never on `-drop`'s return value.**
6. **`xschem callback …` segfaults under `--nogui`** (no mapped window) — the press path is not
   drivable headlessly. Use `xschem wire gui` with `::infix_interface 1` for a live draw,
   `xschem wire` with `infix_interface 0` for a menu arm, and `wire gui` + `abort_operation` for the
   resting state.
7. **The visual half is not headless-testable** (`WIRING.md` §8 classes I/K, §10): a scripted END
   runs a full `draw()` that flushes over any stray stroke. Assert the **state**; confirm the grey
   lines by eye in the GUI.
8. **`ui_state2` is never cleared by `abort_operation()`** — after ESC on the menu-wire path
   `ui_state == 0` but `ui_state2 == MENUSTARTWIRE`. Inert today (only `MENUSTART` gates its
   consumers) but do not make it load-bearing.
9. Out of scope: issues **0231**, **0232**, **0234**, **0235**, **0236** (all filed, all open) and
   the nine remaining F1 forward doors. If a fix here would obviously close one of those, say so
   and stop — do not widen.

## METHOD

RED-first, and **reproduce headlessly before theorising**. Add the new checks to
`tests/headless/test_placement_wire_gate.tcl` (29 checks today, registered in
`tests/run_regression.tcl`) — F3 as a new section D, F2 as section E — unless something genuinely
needs X. Every new predicate gets a **sabotage variant** (`WIRING.md` §10) with a named red check,
and the red sets must be **disjoint** (the existing file already demonstrates the pattern: three
sabotage runs → 4 / 4 / 2 checks).

Tiers that must stay green:

| tier | today |
|---|---|
| `tests/headless/test_placement_wire_gate.tcl` | 29 |
| `tests/headless/test_add_wire_label.tcl` | 88 (see TRAP 1) |
| `tests/headless/test_sch_add_pin.tcl` | 21 |
| `tests/headless/test_label_ride.tcl` | 157 |
| `tests/headless/test_label_strand_oracle.tcl` | 32 |
| `tests/headless/test_wire_split.tcl` | 119 |
| `tests/headless/wireedit/run_wireedit.sh` | 58/58 |
| `tests/headless/run.sh` | 6 goldens |
| `tests/headless/test_create_instance.tcl`, `test_add_pin_lib_symbol_view.tcl` | placement/ESC coverage |
| `cd tests && tclsh run_regression.tcl` | **3 FAIL lines from ONE pre-existing defect** (`test_ihp_sg13g2_libmgr` expects 9 libs, tree has 10) — not yours |

Also re-run the ~20 headless tests that call `abort_operation` and diff the per-test failure counts
against the pre-change binary; F3 edits that function, so an identical baseline is the evidence that
nothing else moved. These five fail at HEAD for unrelated reasons and are baselined:
`test_context_menu_descend_edit` (2), `test_lib_sweep` (5), `test_load_window_routing` (4),
`test_nh_angle_clamp` (3), `test_reopen_readonly` (1).

## Deliverables

- The code, with comments that name the issue and explain *why* the guard is shaped that way (match
  the density of the surrounding comments — see `abort_wire_line_command()` for the house style).
- `doc/claude/issues/0233-*.md` updated: status **PARTIAL → FIXED** only if both F2 and F3 land and
  the nine remaining forward doors are re-scoped into their own issue; otherwise keep PARTIAL and
  update the census tables and the "What landed" paragraph.
- `WIRING.md` §8 class **D** if the root cause names a new class member; `doc/claude/FAQ.md` Q35 and
  `doc/claude/specs/add_wire_label.md` / `schematic_add_pin.md` if the F2 decision changes what `w`
  does mid-placement.

GUI gate: press **Allow 30m / Allow 2h** once before a batch rather than Proceed per suite. This box
has ~7.8 GB RAM — **do not run a build while a multi-agent fan-out is live**.
