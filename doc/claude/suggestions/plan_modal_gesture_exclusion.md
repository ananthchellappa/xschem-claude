# Roadmap — one modal gesture at a time

Status: **COMPLETE — all phases done.** Owner: `open_pdk`. Phases 1–2 landed 2026-08-08 (issue
**0247** FIXED, issue **0248** FIXED first), user-ratified the same day as option (a) cancel;
phase 4 landed 2026-08-08 (issue **0265**); phase 3, the last one, landed 2026-08-09 (issue
**0269**, with **0268** / **0270** / **0271** / **0272** found by its census and fixed with it).
Last measured 2026-08-09.

**The plan as a whole is done.** All four gesture families now have a teardown/gate pair and every
arm calls every gate that applies to it, in both interface branches. What remains of `WIRING.md`
§8 class **D** is the one deliberate residue **0262** (the bare `xschem unselect_all` verb: it
arms nothing, so the rule has no subject), plus the wire-family `ui_state2` residue recorded and
asserted-as-present in issue **0268**.

**Correction, 2026-08-09.** This list used to carry a second residue, **0263** (`netlist`),
excluded on the grounds that it "netlists a live preview but clears no gesture bits — a different
defect, not a door". Measured, that is false: the hierarchical driver's
`push_undo` → `unselect_all(1)` → `pop_undo` round trip clears every gesture bit AND restores the
preview as an ordinary committed instance that ESC can never take back, on top of emitting a wrong
deck in every backend. `netlist` was a door all along and is now gated like one, at both its verbs
(`scheduler.c`'s branch and `callback.c`'s Shift-N) — issue **0263**, FIXED. The phase-plan lesson:
this list was assembled from what each verb *arms*, and a verb that arms nothing can still destroy
a gesture by the way it saves and restores the document.

## The invariant

**Starting a modal gesture cancels whatever modal gesture is already live.**

Three gesture families exist and any two of them jam when co-armed:

| family | bits | armed by |
|---|---|---|
| wire/line **draw** | `STARTWIRE`, `STARTLINE`, or `MENUSTART`+`MENUSTARTWIRE/LINE/SNAPWIRE`, or the RESTING mode (`last_command` alone) | `w`, `W`/`s`, `Shift+L`, ctx-menu 2/3, menu/toolbar, `xschem wire\|line gui` |
| shape **draw** | `STARTRECT`, `STARTPOLYGON`, `STARTARC`, or `MENUSTART`+`MENUSTARTRECT/POLYGON/ARC/CIRCLE` | `r`, `P`, `C`/`Ctrl+C`, ctx-menu 4/5/19/20, `xschem rect\|polygon\|arc [gui]` |
| **placement** preview | `START_SYMPIN` / `PLACE_SYMBOL` / `PLACE_TEXT` (+`STARTMOVE`), or `STARTMERGE` | `l`, `p` (both views), component insert, `Ctrl+P`, `Alt+Shift+L`, `t`, `add_graph`, `add_image`, ctx-menu 1/6, `Ctrl+V` merge, screen-grab |

Why they cannot coexist: `end_place_move_copy_zoom()` tests `STARTWIRE` **before** the placement
arm, and under `persistent_command` (cadence rc) the Button-1 handler seizes the click one step
earlier still. Whichever gesture is armed second can never be completed, and ESC is the only exit.
Rejected alternative: reorder those branches — `WIRING.md` §8 class **H**, and it does not fix the
symptom (issue 0243 measured it).

Cadence mode is not special. It makes the jam louder (`persistent_command` claims every click) but
infix mode has the identical dead end with two rubber bands on screen.

## Machinery already in the tree

- `abort_wire_line_command()` — `src/callback.c`. Abandons a wire/line draw in **all three** of its
  states. Delete-free, no undo baseline stranded.
- `leave_wire_draw_for(const char *what)` — `src/scheduler.c:68`. The above + a statusbar line.
- `abort_placement_preview()` — `src/callback.c`. Tears down a cursor placement preview. Keeps the
  `delete(0)`/`delete(1)` undo discriminator verbatim.
- `leave_placement_for(const char *what)` — `src/callback.c`. The above + a statusbar line. It used
  to carry the issue **0241** decline guard (returned 0 while a multiple selection was live, so the
  caller must not arm); 0241 landed on 2026-08-08 and the guard is gone — it now always returns 1.
- `clear_orphan_gesture_bits()` — `src/callback.c`. What every early return in `abort_operation()`
  owes the terminal `ui_state = 0`.

**Nothing exists yet for abandoning a SHAPE draw** — phase 3 needs an `abort_shape_draw()` sibling
(clear the bits, erase the band with the `RUBBER|CLEAR` idiom).

## Phases

### Phase 0 — done

- [x] `l` (Add Wire Label) cancels a live wire/line draw — issue **0240**, ratified 2026-08-06
- [x] the RESTING wire command mode counts as "live" — 0240 follow-up
- [x] `p` (both views) and component insert cancel a live wire/line — issue **0243 F1**, ratified 2026-08-07
- [x] every wire/line verb cancels a live placement preview — issue **0243 F2**, ratified 2026-08-07
- [x] ESC cleans up after all of them; all three early returns in `abort_operation()` clear the
      orphan gesture bits — issue **0243 F3**
- [x] 86-check headless suite (`tests/headless/test_placement_wire_gate.tcl`) + 8 sabotage variants

### Phase 1 — shape draws cancel a live wire/line draw

Effort: ~8 one-line call sites, low risk (the call is a no-op unless a draw is live, and it is
delete-free so issue 0241 was never in play — and since 2026-08-08 the placement teardown is
scoped too).

- [x] fix issue **0248** first — done, and it turned out to need a writer-side hold in
      `statusmsg()`: for placement verbs the message was also being overwritten one call later by
      `select.c`'s object-info line, not only by the coordinate readout
- [x] ratify the policy with the user — 2026-08-08, option (a) cancel, one answer for both phases
- [x] `case 'r'` (`src/callback.c`) — gated above the infix test, so both branches
- [x] `P` polygon — the Shift+P binding is the registry action `tools.insert_polygon`, i.e.
      `xschem polygon gui`, so the scheduler gate covers the key (there is no polygon branch left
      in the `case 'P'` switch)
- [x] `case 'C'` / `Ctrl+C` arc+circle — both branches
- [x] ctx-menu picks 4, 5, 19, 20
- [x] `xschem rect` — the `gui` and bare/truncated ARM forms only
- [x] `xschem polygon` — same
- [x] `xschem arc` — the ARM form only
- [x] every coordinate/commit form left ungated (replay seams), pinned by checks F7/F8
- [x] new test section **F**, with disjoint sabotage (4 variants, red sets in issue 0247)
- [x] docs: `WIRING.md` class D, `FAQ.md` Q37, issue **0247**

### Phase 2 — the remaining placements cancel a live wire/line draw

Effort: ~7 call sites, same pattern as `p`. **Breaks `test_add_wire_label.tcl` G2** — see *Landmines*.

- [x] `place_net_label()` (`src/actions.c`) — covers `Alt+Shift+L`, `Ctrl+P`, `Ctrl+Shift+P`, `xschem net_label 0/2/3`
- [x] `add_graph` (`src/scheduler.c`)
- [x] `add_image` — gated before the file chooser, like `place_symbol`: cancelling the dialog does
      NOT restore the wire (stated in issue 0247)
- [x] `place_text` and `case 't'` (`src/callback.c`)
- [x] ctx-menu 1 Insert symbol (`start_place_symbol()`, which also serves the `I` and Insert keys)
      and 6 Insert text
- [x] screen-grab image (`src/draw.c`) — gated at the ARM on the release that completes the grab,
      so an abandoned grab leaves the wire alone. GUI-only, prove by code
- [x] `test_add_wire_label.tcl` G2 rebuilt — on the new test-only seam `xschem test_gate_bypass`,
      not on another door (there is none left but merge). `test_placement_wire_gate.tcl` **D3**
      needed the same rebuild — it was NOT in this plan's landmine list and would have been found
      only by running the suite
- [x] issue **0247** → FIXED (merge/`Ctrl+V` stays open, tracked there and in phase 4)

### Phase 3 — wire/line and placements cancel a live SHAPE draw — **COMPLETE 2026-08-09**

The reverse of phase 1; needs the new `abort_shape_draw()` helper. **Unchanged by phases 1-2**, and
now the only asymmetry left outside merge: `r` then `w` still leaves `STARTRECT` armed under a
fresh wire draw. Two things phases 1-2 hand it: the statusbar message will actually be readable
(issue 0248), and `xschem test_gate_bypass` already exists for building whatever co-armed state its
own tests need.

- [x] write `abort_shape_draw()` + `leave_shape_draw_for()` mirroring the wire/line pair — done
      2026-08-09, `src/callback.c`. Delete-free, undo-free, and (after issue **0270** moved the
      polygon's `set_modify`) modify-flag-free, so it needs none of the 0241/0244/0267 machinery
      the other two teardowns carry. It DOES owe the rubber band, and none of
      `new_rect`/`new_arc`/`new_polygon`/`zoom_rectangle` honoured `CLEAR` — the `RUBBER|CLEAR`
      guard was added to all four (`src/actions.c`), a strict no-op for every existing caller
- [x] call from every wire/line verb, every placement verb and every shape verb — **41 sites**,
      enumerated from the state rather than the verbs: 24 (exactly `leave_merge_for()`'s list) +
      15 shape arms + `undo`/`redo`. The 15 shape arms also gained `leave_placement_for()` and
      `leave_merge_for()`, which they had never carried
- [x] decide what an in-progress polygon does — **ratified 2026-08-09**: a competing gesture
      ABANDONS it; ESC keeps COMMITTING it (`abort_operation()`'s `new_polygon(END, …)` is
      unchanged, and so is its action-log line)
- [x] decide whether the ZOOM BOX belongs in the helper — **ratified 2026-08-09: included.** It
      stores nothing and needs no viewport restore, but it owns the next click exactly as an edit
      shape does. The `z` key's decline guard became a cancel
- [x] tests + sabotage — `tests/headless/test_shape_draw_gate.tcl`, 412 checks, six sabotage runs
      with disjoint red sets; `test_placement_wire_gate.tcl` D1/D2 constructors rebuilt on
      `test_gate_bypass`; new test seam `xschem test_shape_click` for the post-click state of
      arc/circle/zoom, which `xschem callback` cannot reach headlessly

### Phase 4 — merge / paste (`Ctrl+V`), both directions — **COMPLETE 2026-08-08**

Closed by issue **0265**: `abort_pending_merge()` + `leave_merge_for()` (`callback.c`), the merge
twins of `abort_placement_preview()` + `leave_placement_for()`. The teardown was factored out of
`abort_operation()`'s two arms (both are now one call to it) and the gate is called from **24**
sites — the merge funnel, all twelve `stamp_placement_preview()` placement arms, and all eleven
wire/line draw arms. `undo`/`redo` are deliberately **excluded**, unlike the placement side: a
pending merge is undo-covered (`merge_file()` pushes its baseline before loading), so `undo` already
removes the paste, and a `delete()`+`push_undo` in front of the pop would make undo *restore* it.
Issue **0267** closed with the same change but **not** as a byproduct of it — the pure-commit forms
stay ungated, so the stale `pre_merge_modified` latch needed `xctx->modify_seq` of its own.
Tests: section **E** of `tests/headless/test_paste_modify_flag_0244.tcl`, 247 checks (129 → 376),
five sabotage runs with disjoint red sets.

**Downstream:** phase 3 (shape draws) is the only phase left and is **not** blocked by anything this
phase produced — it needs `abort_shape_draw()`, which does not exist yet. `test_gate_bypass` now
also disables the merge gate, so phase 3's tests can construct a co-armed shape+merge state the same
way. The one thing phase 4 hands it: `abort_pending_merge()`/`leave_merge_for()` is the third worked
example of the teardown/gate pair, so `abort_shape_draw()`/`leave_shape_draw_for()` has a template
and the `preview_sel` slot-ordering rule is now written down in two places.

**UNBLOCKED 2026-08-08** — both named blockers are FIXED: **0242** (every door now calls
`leave_placement_for()`; a merge tears down a live placement) and **0244** (the aborted-paste flag
lie *and* the un-narrowed merge `delete(1)`, both arms). A merge preview still carries `STARTMERGE`
and not the placement bits, so `abort_placement_preview()` still deliberately does not see it —
but the merge arms now have their own scoped, flag-correct teardown to call from, which is exactly
what this phase needs.

The direction *merge cancels a live draw* already works (`merge_file()` calls
`leave_placement_for()`, which is the wire/line-draw teardown too). The direction *a draw cancels a
live merge* is the remaining work, and it now has a named prerequisite of its own: **issue 0265** —
nothing tears down a pending `STARTMERGE` at all, so today a second `Ctrl+V` or any placement arm
silently **commits** the pending paste (measured). Phase 4 should factor the merge teardown out of
`abort_operation()`'s two arms into a `leave_merge_for()` sibling and call it from the draw verbs;
that closes 0265 in the same move.

- [x] 0242 / 0244 landed
- [x] factor the merge teardown out of `abort_operation()` (select-stamp + `delete(1)` +
      `pre_merge_modified` restore + `clear_placement_preview()`) into `abort_pending_merge()`, with
      `leave_merge_for()` as its gate wrapper — two functions, not one, so ESC keeps raising no
      statusbar hold (the same split as `abort_placement_preview()` / `leave_placement_for()`)
- [x] then: a draw cancels a live merge — `wire gui`, `line gui`, `snap_wire` and their key / menu /
      context-menu twins, both interface branches (`snap_wire` arms `MENUSTART`, not `STARTWIRE`)
- [x] issue **0265** closed; issue **0267** closed with it, by a separate mechanism

## Cross-cutting blockers

- **Issue 0241** — **FIXED 2026-08-08, and the guard is deleted.** `abort_placement_preview()` tore
  the preview down with `delete()`, which removes the **selection**, not the preview object
  (measured: 2 wires + preview + `select_all` + `w` → 0 wires), so `leave_placement_for()` declined
  while a multiple selection was live. The teardown is now scoped to the preview's own identity —
  stamped per-object as session-stable ids at all twelve arm sites
  (`stamp_placement_preview()`, select.c) and re-selected immediately before the `delete()`, with
  "resolves to nothing → delete nothing" as the backstop. The decline guard came out with it, so
  **the blocker on later phases is lifted**: a new caller may now reach the placement teardown with
  a foreign selection live. `tests/headless/test_placement_wire_gate.tcl` **E7** was rewritten to
  assert the opposite of what it used to. The **merge/paste** `delete(1)` in `abort_operation()` was
  scoped the same way on 2026-08-08 by **issue 0244** part B (same stamp, same slot, both arms), so
  phase 4 no longer inherits an un-narrowed version.
- **Issue 0246** — `wirelabel_preview` has no `xschem get` seam, so its teardown is unassertable.
- **Issue 0248** — FIXED 2026-08-08. Gate/prompt messages now hold `.statusbar.1` for 5 s or until
  the next click; an ordinary `statusmsg(…, 1)` is dropped while a hold is up. Seams:
  `xschem get statusmsg` / `xschem get statusmsg_hold`, and a DISPLAY-gated test.
- **`xschem callback …` segfaults under `--nogui`**, so no click path is drivable headlessly. Arm
  with `xschem <verb> gui` / `::infix_interface`, assert on flags, confirm pixels by eye.

## Landmines

0. **RESOLVED 2026-08-08 — `xschem test_gate_bypass 0|1`** is the seam landmine 1 asked for
   (`xctx->gate_bypass`, disables both gate helpers for the length of a constructor). Used by
   `test_add_wire_label.tcl` G2 and `test_placement_wire_gate.tcl` D3, bracketed around the ARM
   only; section H of the gate suite pins that it defaults to off and really does disable a gate.
   The original text follows, as the record of why it exists.

1. **`test_add_wire_label.tcl` G2 needs the co-armed state to be constructible.** It is the only
   coverage of `abort_operation()`'s co-armed teardown. Its constructor has already been rebuilt
   twice (`wire gui` + `add_wire_label -place` → `add_graph` → `net_label 0`). **Phase 2 closes the
   last constructor**, so that phase must first give the tests a direct seam (there is no
   `xschem set ui_state` today) or move G2's intent into a differently-driven check. Decide this
   *before* writing the phase-2 gates, not after.
2. **Never gate a pure-commit form.** `add_wire_label -drop`, `add_symbol_pin <x> <y> …`,
   `xschem wire x1 y1 x2 y2`, `xschem rect x1 y1 x2 y2` commit outright and are the replay/test
   seams. `test_placement_wire_gate.tcl` C2 and E5 pin this in both directions.
3. **Arg-form quirk.** Truncated forms (`xschem wire 10 20`, `xschem line gui extra`) fall into the
   ARM branch, not the commit branch. Gate placement is by branch, not by verb name.
4. **One undo baseline per gesture.** A form's `-place` runs on every keystroke; a teardown that
   clears `sympin_preview` makes the next `-place` push a second baseline
   (`specs/add_wire_label.md`, `cadence_pin_name_text.md` item #3). Prove with a check.
5. **Test both interface modes.** `infix_interface 1` arms at the keystroke; `0` arms `MENUSTART`
   and the first click starts the gesture. Cadence rc uses 0 with `persistent_command 1`. A gate
   that only covers the infix branch looks green and does nothing for cadence users.

## Ratification

Each verb's policy has been ratified individually so far. Phases 1–2 are one question:

> Any new draw or placement command cancels the one in progress — for **all** remaining verbs
> (`r`, `P`, arc/circle, `Ctrl+P`, `Alt+Shift+L`, `t`, `add_graph`, `add_image`, ctx-menu inserts) —
> yes or no?

**Ratified 2026-08-08: (a) cancel**, one answer for both phases, consistent with 0240 and 0243.

The alternative the code already supports is *decline* (`leave_placement_for()` returns 0 and the
caller does not arm) with a statusbar hint. Mixing the two per family is possible but would be the
first inconsistency in the rule, so decide once.
