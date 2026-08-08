# Next-session prompt — modal-gesture exclusion, phases 1 and 2 (+ issue 0237 correction)

Paste everything below the line into a fresh session with cleared context.

---

Implement **phases 1 and 2** of `doc/claude/suggestions/plan_modal_gesture_exclusion.md`, fix issue
**0238**, and fold in the issue **0237** corrections listed at the bottom. Tree is at `465223be` on `open_pdk`; every
anchor below was verified there. Re-derive line numbers by grepping the quoted statement, not by
trusting the number.

## The rule you are extending

**Starting a modal gesture cancels whatever modal gesture is already live.** It holds today for
four forward doors (`l`, `p` in both views, component insert) and for every wire/line verb in the
reverse direction (issue 0233 F2). Phases 1–2 extend the *forward* direction to the verbs still
ungated: the shape draws (`r`, `P`, arc/circle) and the remaining placements (`Ctrl+P`,
`Alt+Shift+L`, `t`, `add_graph`, `add_image`, the two context-menu inserts).

This is what the user hit in the GUI on 2026-08-07, under `src/cadence_style_rc`: pressed `w`,
clicked, pressed `r`, and the editor stayed in wire mode — `r` armed `MENUSTART|MENUSTARTRECT`
(measured `ui=65537`, `last_command=1`) while the wire kept claiming every click, so the rectangle
could never start. Same dead end in infix mode, where both rubber bands are live at once
(`ui=3 [STARTWIRE|STARTRECT]`).

## Read first

`doc/claude/suggestions/plan_modal_gesture_exclusion.md` (the roadmap — phases, machinery,
landmines, ratification question), then `doc/claude/issues/0233-*.md` (**FIXED**; its *Where the fix
diverged from the sketch* and *Known gaps* sections carry the reasoning you must not re-derive),
then `doc/claude/issues/0237-*.md` (**OPEN** — the doors you are closing) and
`doc/claude/issues/0238-*.md` (**OPEN** — the statusbar fix, below), then `WIRING.md` §7
landmines 8, 9, 12, §8 classes **D** and **H**, and §10 (testing traps).

## ASK THE USER FIRST

One question, both phases, exactly as issues 0230 and 0233 did per verb:

> Any new draw or placement command cancels the one in progress — for all remaining verbs (`r`, `P`,
> arc/circle, `Ctrl+P`, `Alt+Shift+L`, `t`, `add_graph`, `add_image`, ctx-menu Insert symbol / Insert
> text) — **(a) cancel** (recommended, consistent with what shipped) or **(b) decline** (the command
> refuses while a gesture is live, statusbar says finish or ESC it first)?

The code supports both: `leave_wire_draw_for()` is the cancel path, and `leave_placement_for()`
(`src/callback.c`) is a worked example of the decline path — it returns 0 and every caller then
skips arming. The user has already said they lean toward consistency but has not ratified the verbs.

## Phase 1 — shape draws cancel a live wire/line draw

Call `leave_wire_draw_for("<verb>")` at each arm, exactly as `add_wire_label` / `add_sch_pin` /
`place_symbol` do. It is delete-free, so issue 0231 is not in play here. Gate **both** the infix and
the `MENUSTART` branch of every key — cadence users are on `infix_interface 0` and a gate that only
covers the infix branch does nothing for them.

Verified sites (`src/callback.c` unless noted):

| verb | anchor | note |
|---|---|---|
| `r` rectangle | `case 'r':` `:6916` | infix branch calls `new_rect(PLACE,…)`, else `MENUSTART`+`MENUSTARTRECT` |
| `P` polygon | `case 'P':` `:6862` | same shape |
| `C` / `Ctrl+C` arc, circle | `case 'C':` `:6310` | `new_arc(PLACE, 180.…)` / `360.` |
| ctx-menu 4, 5 | `:4427`, `:4433` | rect, polygon |
| ctx-menu 19, 20 | `:4510`, `:4516` | arc, circle |
| `xschem rect` | `scheduler.c:9958` | ARM forms only |
| `xschem polygon` | `scheduler.c:9044` | ARM forms only |
| `xschem arc` | `scheduler.c:2126` | ARM forms only |

Do **not** touch `check_menu_start_commands()` (`callback.c:3901-3925`): that is the *click* that
starts a menu-armed shape, not a verb. Gating the keystroke is what makes the click land on the
rectangle instead of the wire.

## Phase 2 — the remaining placements cancel a live wire/line draw

Same helper, same rule. Sites:

| verb | anchor | covers |
|---|---|---|
| `place_net_label()` | `actions.c:2477` (`ui_state \|= START_SYMPIN`) | `Alt+Shift+L`, `Ctrl+P`, `Ctrl+Shift+P`, `xschem net_label 0/2/3` |
| `add_graph` | `scheduler.c:1924` | Graphs ▸ Add graph |
| `add_image` | `scheduler.c:1963` | Graphs ▸ Add image |
| `place_text` | `scheduler.c:8982` | and `case 't'` at `callback.c:7088` |
| ctx-menu 1 Insert symbol | `start_place_symbol()`, `callback.c:478` | |
| ctx-menu 6 Insert text | `callback.c:4439` | **pick 6, not 8** — 8 is Paste clipboard |
| screen-grab image | `draw.c:305` | GUI-only; prove by code, no headless seam |

`Ctrl+V` merge is **out of scope** (phase 4, blocked on issues 0232/0234): its preview carries
`STARTMERGE`, not the placement bits.

## Issue 0238 — do this FIRST, before adding any gate

Every gate message is invisible in the running GUI, and the user confirmed it on 2026-08-07: press
`p`, type a name, press `w`, and the preview vanishes with no explanation — the status bar shows
only the green `DRAW WIRE!` mode label. `statusmsg(str, 1)` does write `.statusbar.1`
(`scheduler.c:28`, `:49` — its only writer), but the motion handler's coordinate readout
(`callback.c:5911-5921`, guarded by `if(xctx->ui_state)` and an 8-pixel threshold, plus the
press/release twins at `:8495` and `:8882`) overwrites it on the next flick of the mouse. `ui_state`
is non-zero for exactly the reason the message exists, so it is always wiped.

This matters here because phases 1–2 add eight more verbs that silently discard work in progress.
Ship the feedback before you ship the verbs. Issue 0238 recommends a hold counter checked by the
readout; read its *Fix options* and *Landmines* (three readout sites, keep the live `w=`/`h=` size
feedback during moves, `statusmsg(…,2|3)` is a different sink, not headless-testable) before
choosing. `leave_wire_draw_for()`'s 0230 message has the same defect and is fixed by the same change.

## TRAPS

1. **Phase 2 closes the last constructor for `test_add_wire_label.tcl` G2.** That section is the
   only coverage of `abort_operation()`'s co-armed teardown, and its constructor has already been
   rebuilt twice — `add_wire_label -place` + `wire gui` (closed by 0233 F2), then `add_graph`
   (rejected: its preview is a rect, so two checks went vacuous), now `wire gui` + `net_label 0`.
   Gating `net_label` kills it. **Decide the replacement before you write the phase-2 gates.**
   There is no `xschem set ui_state` seam today; the honest options are a small test-only seam, or
   moving G2's intent into a check driven some other way. Do not simply delete it, and do not leave
   a vacuous check standing (that is exactly what review caught last time).
2. **Never gate a pure-commit form.** `xschem rect x1 y1 x2 y2`, `xschem polygon …`,
   `xschem net_label` with coordinates, `add_wire_label -drop`, `add_symbol_pin <x> <y> …` commit
   outright and are the replay/test seams. Sections C2 and E5 of `test_placement_wire_gate.tcl` pin
   this in both directions — keep them green and add the equivalent control for every new gate.
3. **Arg-form quirk.** Truncated forms (`xschem wire 10 20`) land in the ARM branch, not the commit
   branch. Gate by branch, not by verb name.
4. **`t` needs a Tk toplevel**, so `case 't'` is not drivable headlessly; its pre-arm effect
   (`last_command` 1 → 0 with `STARTWIRE` intact) is measurable, and `xschem place_text` is the
   scriptable twin. Assert what you can and say what you could not.
5. **Both interface modes.** `infix_interface 1` arms at the keystroke; `0` arms `MENUSTART` and the
   first click starts the gesture. Test each new gate in both — the cadence path is the one the user
   actually runs (`./src/xschem --script src/cadence_style_rc`, which sets `infix_interface 0`,
   `persistent_command 1`, `cadence_compat 1`).
6. **Do not touch `leave_placement_for()`'s issue-0231 decline guard.** It exists because
   `abort_placement_preview()` deletes the *selection*, not the preview (measured: 2 wires +
   preview + `select_all` + `w` → 0 wires). Phases 1–2 do not need it — they cancel draws, which is
   delete-free — so no new caller should reach `delete()`.
7. **`xschem callback …` segfaults under `--nogui`.** No click path is drivable headlessly. Arm with
   `xschem <verb> gui` and `::infix_interface`, assert on flags, confirm pixels by eye.
8. Out of scope: issues **0231**, **0232**, **0234**, **0235**, **0236**, and phases 3–4 of the
   roadmap. If a fix here would obviously close one of those, say so and stop — do not widen.

## METHOD

RED-first, and reproduce headlessly before theorising. Add the new checks to
`tests/headless/test_placement_wire_gate.tcl` (**86 checks today**, registered in
`tests/run_regression.tcl`): phase 1 as section **F**, phase 2 as section **G**. Every new predicate
gets a sabotage variant (`WIRING.md` §10) with a named red check, and the red sets must be
**disjoint** — the file already demonstrates the pattern with eight variants (see the sabotage table
at the top of issue 0233). Include a control per gate proving the commit form is untouched.

Tiers that must stay green:

| tier | today |
|---|---|
| `tests/headless/test_placement_wire_gate.tcl` | 86 |
| `tests/headless/test_add_wire_label.tcl` | 88 (see TRAP 1) |
| `tests/headless/test_sch_add_pin.tcl` | 21 |
| `tests/headless/test_label_ride.tcl` | 157 |
| `tests/headless/test_label_strand_oracle.tcl` | 32 |
| `tests/headless/test_wire_split.tcl` | 119 |
| `tests/headless/wireedit/run_wireedit.sh` | 58/58 |
| `tests/headless/run.sh` | 6 goldens |
| `cd tests && tclsh run_regression.tcl` | **3 FAIL lines from ONE pre-existing defect** (`test_ihp_sg13g2_libmgr` expects 9 libs, tree has 10) — not yours |

Also re-run the 16 headless tests that call `abort_operation` and diff them against the pre-change
binary; an identical baseline is the evidence nothing else moved. Do not rebuild while a multi-agent
fan-out is live — this box has ~7.8 GB RAM.

## Issue 0237 corrections (fold into this session)

Measured against the tree, its current text is wrong in two ways:

- It calls the `rect`/`polygon`-on-a-live-wire case *"a different (and much milder) clash"*. It is
  not milder: the user demonstrated the identical dead end (the rectangle never starts, ESC is the
  only exit). Rewrite that note and **add the shape-draw arms to the door table** as their own
  group, with the phase-1 anchors above.
- Its title and provenance line say "eight placement arms"; the shape arms make it a different
  count, and the file is named `0237-placement-arms-...`. Re-title around what it actually tracks:
  every verb that can arm a second modal gesture on top of a live one.

## Deliverables

- The code, with comments that name the issue and explain *why* the gate is shaped that way (match
  the density of the surrounding comments — `leave_wire_draw_for()` and `leave_placement_for()` are
  the house style).
- New sections F and G in `tests/headless/test_placement_wire_gate.tcl`, plus the sabotage runs and
  their red sets recorded in the issue.
- `doc/claude/suggestions/plan_modal_gesture_exclusion.md`: tick the phase 1–2 checkboxes, update
  the "Status" line and the phase-3 notes if anything you learn changes them.
- Issue **0237** corrected as above, and marked FIXED or narrowed to merge-only depending on what
  lands.
- Issue **0238** fixed and closed, with the gate messages actually visible in the GUI — confirm by
  eye, since it cannot be asserted headlessly, and say plainly that you did.
- `WIRING.md` §8 class **D** if the work names a new class member; `doc/claude/FAQ.md` (Q36 is the
  reverse-door entry — a new Q for "what happens if I press `r` mid-wire" belongs on top);
  `doc/claude/specs/add_wire_label.md` and `schematic_add_pin.md` only if the user-visible rule for
  those two forms changes.
- Tell the user plainly which verbs changed behaviour, since every one of them is a keystroke they
  already have in their fingers.
