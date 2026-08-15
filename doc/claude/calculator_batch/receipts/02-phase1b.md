# Item 02 — phase 1b: selector grid, mode strip, buffer + toolbar, Stack

Ledger row 2; plan 1.2–1.5; spec §4 W06–W25, §5, §6, R202, R506.
**Verdict `[E]`** — the payload is 22 buttons in three groups, a mode strip, a
toolbar and a list; 327 green checks pin paths, classes, initial states **and,
since the fix round, what is actually on screen**. Captures:
`02-phase1b-fixed.png` (default first open) and `02-phase1b-fixed-min.png` (at
the toplevel's own declared minimum) — `02-phase1b.png` is the pre-fix state and
is kept because §9 quotes it.

⚠ **A FIX ROUND FOLLOWED REVIEW.** Three independent lenses ran the window on
`:99` and measured pixels rather than `cget`s, and found six defects and five
coverage holes that all 299 checks had passed over. §9 records the round; the
body of this receipt describes the code AS FIXED.

## 1. Files changed

```
 doc/claude/specs/calculator.md        |  74 +    (+50 in the fix round)
 src/calculator.tcl                    | 581 +    (+128 in the fix round)
 tests/headless/test_calc_skeleton.tcl | 830 +    (+292 in the fix round)
 3 files changed, 1453 insertions(+), 32 deletions(-)
```
New: `02-phase1b.png`, `02-phase1b-fixed.png`, `02-phase1b-fixed-min.png`,
this file. **No rebuild** (`calculator.tcl` is sourced at
runtime, `xschem.tcl:14381`). Nothing staged, nothing committed.

## 2. What landed — all of it INERT

`.calc.sel` + 22 `.calc.sel.<id>` radiobuttons on `::calc::selmode`, two rows of
eleven in three groups (4/3/4) parted by a spacer column carrying a hairline
(`.sep1/.sep2`); rows are spec §5 + the explainer's ASCII §4(C), **not** the XL
screenshot's set. Eight are `-state disabled` (`sp zp yp hp vswr zm gd` + `mp`),
each with a `balloon` tooltip carrying its reason and a `<Button-1>` →
`calc::sel_refuse` that states it. `.calc.mode`: Off/Family/Wave on
`::calc::pickscope` (initial `off`), `Clip` on `::calc::clip` **initial 1**,
`Plot`/`Eval`/`Table`, destination combobox `Append Replace {New Strip}` initial
`Append` with `combo_letter_cycle` bound. `.calc.buf` (Text, height 4, `-undo 1`,
editable) + `.calc.btb` (Enter Pop Swap Roll ClrBuf ClrStk M+ ME Undo Redo, the
last two **created disabled**). `.calc.stk` + `.calc.stk.list` (**top of stack =
index 0**, documented at `build_stk` — invisible in an empty listbox, and
R503/R504/R511 all read it) + Push/Pop/Del/Recall. Every `-command` routes
through `calc::inert what phase` → `calc::status` (R506). Sashes, `-minsize`,
`pw_list` and the Functions/Keypad placeholders untouched.

## 3. Rulings made, and where they are written

| ruling | why | written into |
|---|---|---|
| **W11/W12/W14 are TEXT** (`Plot`/`Eval`/`Table`), not the reference's icons | no icon set a new dialog can draw from (`resources.tcl` is the main toolbar's base64, recon/theming.md §1); an invented glyph font is a second asset for three buttons | spec §4 W11/W12/W14 |
| **`.calc.pw.stk` loses its title**; `.calc.stk` keeps `Stack` | phase 0 titled the pane `Stack` and W23 puts a labelframe titled `Stack` inside it — the word was drawn twice, nested | spec §4 W23 + `build_stk` |
| **R202's line comes from a `<Button-1>` bind, not `-command`** | `invoke` and the `Button` class bindings both return early on a disabled widget, so its `-command` never fires; X still delivers the event | spec §5.1 R202 + `build_sel` |
| **flat paths beat the house radiobutton idiom** | recon §2's per-group frame yields `.calc.sel.g1.vt` and W07 is normative; kept the half that matters — one data table, a loop, spacer columns | `build_sel` |
| spec §4 gains a note that six W-rows are children of `.calc` drawn with `pack -in`, and that `ismapped` cannot guard them | the trap the Results Dir row already paid for, now true of five more widgets | spec §4 |

## 4. Three defects the capture caught that the checks did not

1. **The whole buffer toolbar was unmapped.** `pack` fills the cavity in packing
   order, so `-fill both -expand 1` on `.calc.buf` packed first took all of it
   and `.calc.btb` got nothing: measured at 660x700, `ismapped .calc.btb` = 0,
   Enter…Redo simply absent, every widget check green. Fixed by packing the
   fixed-height row first; S19 asserts **both mapped** plus the visual order.
2. **`Recall` floated 60 px below `Del`** — weighting the last button's grid row
   (the obvious way to make the listbox fill) stretches that row. Weight an
   empty row below them instead; S20's contiguity check was added *because* the
   defect went green (sabotage 23).
3. **`-selectcolor selectbg` painted every selector a solid dark blob.** Scanline
   across `.calc.sel.vt`'s indicator: `selmode {}` → background disc + grey dot
   (Tk tristate = "nothing armed"); `= vt` → `-selectcolor` disc + **black dot**;
   `= vf` → flat `-selectcolor` disc. `-selectcolor` is the indicator's *field*,
   so the role is `field` — also xschem's own `*selectColor white`
   (`xschem.tcl:15552`).

## 5. Tests

`test_calc_skeleton.tcl` — new **S17–S20**, S1–S16 intact and unrenumbered.
`RESULT: ALL PASS (299 checks)`, was 192.

**Three phase-1a checks RESTATED** (marked `⚠ RESTATED` in place; none deleted or
renumbered), because filling a pane changes what is in it:
`S14 … hint text/background` now loop over the two panes that still hold a
placeholder, and the other half of the restatement is the new
`S14 a filled pane keeps no placeholder hint`; `S15 packed into the Selectors
pane, first` → `{.calc.res .calc.sel .calc.mode}`; `S15 row sits at the top of
the pane` compares against `.calc.sel`, the widget that replaced the hint.

**Non-vacuity** with `HEAD:src/calculator.tcl` in place: `110 FAILED (189
passed)` — 108 of the 113 new/restated checks red without the feature, plus 2
pre-existing checks the restatement moved. (⚠ this receipt originally recorded
`108 FAILED (189 passed)`, which sums to 297 rather than 299; the total is 110.
Superseded anyway by §9.3, which re-measures the round's own suite.) The five
that are not: the two `open|reopen returns .calc` fixture preconditions, `S17 the
indicator field is not the panel` (palette sanity), `S18 the status history style
does have one` (a pair's positive control), `S20 the pane is still a labelframe
wearing the accent` (guard whose partner is red).

Two helpers added for a reason: `nsval` (namespace read returning
`NO-SUCH-VARIABLE` instead of throwing — a bare `$::calc::pickscope` against HEAD
killed the file at the first read and hid ~95 checks) and `selcol`'s `-999`
sentinel, same class of abort.

## 6. Sabotage — 23, every one red, every one restored from a byte-exact backup (md5 verified each time)

| # | broken | checks reddened |
|---|---|---|
| 1 | selectors not `-state disabled` | the 7 RF + mp are disabled; invoking arms nothing; clicking arms nothing; clicking explains why |
| 2 | `var`/`vn` swapped in `sel_rows` | row 1 is the voltage row, left to right |
| 3 | no spacer column | the three groups are separated; both separators are drawn |
| 4 | `balloon` removed | every disabled selector carries its reason; the RF/mp reasons differ |
| 5 | `<Button-1>` refuse bind removed | clicking a disabled selector explains why (R202) |
| 6 | `clip` seeded 0 | clip starts ON; toggles; toggles back; fresh window has Clip ON |
| 7 | `New Strip` dropped | dest values |
| 8 | dest wears `Calc.TCombobox` | dest does not borrow the status history's offset style |
| 9 | undo/redo not disabled | undo/redo start disabled; disabled undo/redo do not fire; fresh window |
| 10 | buffer `-height 6 -undo 0` | buffer height; undo on; `-undo 1` is live |
| 11 | toolbar `-command {}` | every toolbar button names itself and its phase |
| 12 | `.calc.pw.stk` retitled `Stack` | the pane carries no second title |
| 13 | buffer packed before the toolbar | packs the toolbar first; both mapped, buffer above |
| 14 | `selmode` seeded `vt` | nothing armed at first open; fresh window arms no selector |
| 15 | `-selectcolor` dropped | every selector wears the palette |
| 16 | `lower .calc.sel` | grid stacks above the panedwindow; grid is topmost at its centre |
| 17 | listbox loses select colours | list selection colours |
| 18 | `sel_refuse` says "selector error" | clicking a disabled selector explains why (R202) |
| 19 | dest initial `Replace` | dest initial; fresh window destination is Append |
| 20 | `recall` removed | the four side buttons; every side button names itself |
| 21 | `calc::inert` returns without speaking | 8 checks across S17–S20 |
| 22 | `.calc.stk -text {}` | titled Stack |
| 23 | stretch on the last button's row | the four side buttons are one contiguous column |

**Unsabotaged, therefore not evidence:** the three `parent is .calc` checks (they
can only fail when the widget is missing), `S17 grid is mapped`, `S18 strip sits
below the grid`, `S18 dest binds combo_letter_cycle`, `S19 the pre-press buffer
snapshot is real text` (a positive control), `S20 drawn in the Stack pane`.

## 7. Audit diff vs `receipts/00b-audit-baseline-2026-08-14.txt`, by name and status

Seven suites through `run_suites.sh` on `:99`: `test_calc_skeleton` PASS→PASS
(192→299 checks), `test_wave_viewer` PASS→PASS (400), `test_accelerators`,
`test_bindings_file`, `test_key_graph_context` PASS→PASS,
`test_wave_trace_menu` PASS→PASS (397), `test_ase_window` **FAIL→FAIL**
(identical W7 line item 1 recorded). **No suite moved in either direction.**
`grep -ln "calc::\|calculator" tests/headless/*.tcl` names only this suite, so
no other file greps the procs touched. `full_audit.sh` not run — item 99 owns it.

## 8. What was NOT verified

- **The pixels.** All on `:99`, nothing on `:0`. Look debt recorded and
  **uncleared** (only the user clears it); suite debt `test_calc_skeleton` for a
  `:0` run also recorded. Unjudged: hairlines as dividers or as dirt;
  `Plot`/`Eval`/`Table` as words vs the reference's icons; the eight greyed ids
  as information or as breakage; the Stack column vs the reference's round icons.
- ~~**The Selectors pane at the minimum window size.**~~ **This was the wrong
  axis and it hid a real defect** — the vertical question was measured, the
  horizontal one bit. Fixed in the round below; see §9.
- **Keyboard reachability** (all new controls `-takefocus 0` except the buffer;
  no Tab/Return replay). **Typing** is asserted through `insert`/`edit undo`, not
  a synthesised `<Key>` — bare `event generate` key delivery is a known ~1-in-5
  flake here. **R201** and everything else the `-command`s name a phase for.


---

## 9. THE FIX ROUND (2026-08-15, after review)

Three lenses ran the built window on `:99` and measured it — `winfo containing`,
`winfo reqwidth`/`reqheight`, `bbox`, and `xwd` scanlines — instead of trusting
`cget`. Everything below was confirmed by at least one reviewer with a
reproducer, and most by two.

### 9.1 What was wrong, and what fixed it

| # | defect (all invisible to 299 green checks) | fix |
|---|---|---|
| 1 | **The grid was clipped at the window's own declared minimum.** `.calc.sel` needs 614 px; `wm minsize .calc 560 620` (phase-0 code) left 548, so `zm` and `data` — and `data` is an ENABLED selector — were entirely off screen while `winfo ismapped` returned 1. `save_layout` persists the geometry, so once shrunk it stayed unusable across close/reopen. | `calc::apply_minsize` **derives** the minimum width from `winfo reqwidth .calc.pw.sel` and is applied AFTER `restore_layout`, so a geometry saved while clipped is corrected upward instead of replayed. A grid that grows carries the minimum with it. Spec §4.2 rule 1. |
| 2 | **The buffer drew 1.5 of its 4 lines.** W15 asks for `height 4` (72 px); the Buffer pane's phase-0 fraction gave it 29. `bbox 3.0` and `bbox 4.0` were empty while `cget -height` said 4. | first-open fractions `{0.21 0.36 0.64}` → `{0.21 0.42 0.645}` and the height floor `620` → `680`, so **every** pane gets at least its requested height with ≥ 9 px of margin. Arithmetic written out at `calc::pw_list`; spec §4.2 rule 2. |
| 3 | **All 22 selectors rendered half-armed at first open.** Tk's default `-tristatevalue` is the EMPTY STRING, which is exactly `calc::selmode`'s "nothing armed" value, so the state the window is BORN in was the only unarmed state that drew a dot. Scanline: `{}` → a (242,242,242) disc + a (127,127,127) dot; a non-matching value → the flat (255,255,255) `field` disc. | `calc::sel_tristate` — a sentinel no id and no legitimate state can hold — configured with a `catch` (Tk 8.4 has no such option). `{}` stays the normative unarmed value, which R201 also returns to. **Re-measured after the fix: A(`{}`) is pixel-identical to B(a non-matching value), and different from C(armed).** Spec §4 W07. |
| 4 | **Both comboboxes wore a stock `#d9d9d9` field.** `ttk::style configure ... -fieldbackground` does not reach a `-state readonly` combobox in this theme; the two checks that covered it read the style OPTION, so they were green about a colour that was not on screen (sampled: (217,217,217) against `.calc.status.msg` at (255,255,255)). | `ttk::style map` for the `readonly` state on **both** Calc.* combobox styles, so item 1's history dropdown is fixed with it. The check now reads the **map**. Spec R113a. Re-sampled: the dest field is dominantly (255,255,255). |
| 5 | **`.calc.stk.sb` was the one widget in the item with no palette at all** — grey80 with a `#b3b3b3` trough (sampled (204,204,204)) against a (242,242,242) panel — and nothing anywhere mentioned it. | palette background / trough / activebackground, plus four checks. Spec §4 W24. |
| 6 | **A NUL byte** got into the `-tristatevalue` sentinel while writing the fix, which made `src/calculator.tcl` a binary file to `grep`, `file` and `git`. Caught because two sabotages silently failed to apply and came back green. | printable literal; `file` reports UTF-8 text again. **Two sabotage rows in §9.3 are marked as re-runs for exactly this reason** — a green sabotage is a sabotage that did not happen. |

### 9.2 Coverage holes closed (the checks, not the feature)

| hole | proof it was a hole | closed by |
|---|---|---|
| Any non-toolbar control could write into the buffer undetected: S19 snapshots AFTER its own `delete 1.0 end`. | `sel_click` gaining `.calc.buf insert end` → `ALL PASS (299)`. Broadened to every non-toolbar control via `calc::inert` → still `ALL PASS`. | a sentinel snapshot taken **before the first press in S17**, compared at the end of S18, with a positive control. Both reproducers now red. |
| The three pick-scope radios were never invoked; 21 of the 22 selectors were never invoked. | `-command {}` on all three scopes → `ALL PASS (299)`. Silencing every selector but `vt` → `ALL PASS (299)`. | full sweeps: each enabled selector must arm ITSELF and name itself; each scope must select itself, name itself, and the sweep must land back on `off`. |
| "both group separators are drawn" asserted exists+mapped+width≥1, so an invisible hairline passed. | painting the separator `[calc::color panel]` → `ALL PASS (299)`. | the loop now also demands the hairline is not the frame colour it sits on. |
| No check anywhere read a pane's caption. | `.calc.pw.sel {}` / `.calc.pw.buf {}` → `ALL PASS (299)`. | `S14 the five panes carry their captions`, which also pins `.calc.pw.stk`'s empty title from the positive side. |
| Nothing read a RENDERED size anywhere — the whole class defects 1 and 2 hid in. | both defects, green throughout. | **S21**, a new section: `winfo height` vs `reqheight`, `.calc.buf bbox 4.0`, `winfo containing` at each of the 22 selectors' centres at the declared minimum, and a reopen-after-shrink leg. It needs a TRUE first open (`array unset calc::sash` **and** `set calc::geom {}`), because `calc::geom` survives a close and the plain teardown reopen is a roomier window in which defect 2 does not reproduce. |

Also hardened while there: two of the new checks used a bare `winfo` and aborted
the file when the widget was absent (`UNEXPECTED ERROR: bad window path name
".calc.sel"`, two checks never run) — the `wvbs_common.tcl:84` rule; and the new
stack-snapshot comparison could pass vacuously when both sides were the same
error string (the S16 recall lesson). Both now carry a sentinel.

### 9.3 Checks and sabotage

`RESULT: ALL PASS (327 checks)`, was 299. **28 new checks, one strengthened**
(`S17 both group separators are drawn`). S1–S16 and item 2's own S17–S20 are
intact and unrenumbered.

Non-vacuity with `HEAD:src/calculator.tcl` (the phase-0 file) in place:
`135 FAILED (192 passed)` — every check ran, none lost to an abort. Exactly
**eight** pass without the feature, all of them fixture preconditions or
positive controls: `S17 open/reopen returns .calc`, `S21 first open returns
.calc`, `S21 reopen after a shrink returns .calc`, `S17 the indicator field is
not the panel`, `S18 the status history style does have one`, `S20 the pane is
still a labelframe wearing the accent`, `S21 the declared minimum is wide enough
for the selector pane` (the phase-0 pane is narrow, so 560 really is enough for
it — the check is about the CURRENT grid).

⚠ **Correction to §5 above**: the figure recorded there for item 2's own
non-vacuity run was `108 FAILED (189 passed)`, which sums to 297, not 299. The
reproduced figure is **110 FAILED (189 passed)**; 108 of those 110 are among the
113 new/restated checks and 2 are pre-existing checks the restatement moved.

**Sabotages, all restored from a byte-exact md5-verified backup and re-run
green.** Every one of the 28 new checks is named by at least one row.

| # | broken (file:line-level) | went red |
|---|---|---|
| A3 | `calc::build`: the `calc::apply_minsize` call after `restore_layout` deleted | 6 — the whole S21 minimum block, including `all 22 selectors are on screen` and `a reopened window is not clipped either` |
| Y2 | `calc::apply_minsize`: sets `wm minsize .calc 1 1` while still REPORTING the derived value (a lying minimum) | 8 — the S21 minimum block plus both buffer-rendering checks |
| Z | the window forced open at 500x680 with a 200x200 minimum | 6 — incl. `no row is narrower than it asked to be at first open` |
| B | `calc::min_floor` height 680 → phase 0's 620 | `S21 no pane's contents are squeezed below their requested height` |
| C | `calc::pw_list` fractions back to phase 0's `{0.21 0.36 0.64}` | `S21 the buffer shows all four of its lines at first open (W15)` + `no pane's contents are squeezed` — i.e. the reviewer's defect, now covered |
| D | fractions made an even split `{0.25 0.50 0.75}` | 3 — S11's three first-open proportion checks still have teeth after the amendment |
| E | the `-tristatevalue` configure call deleted | `S17 no legitimate selmode value renders as Tk's tristate` |
| F ⟲ | `calc::sel_tristate` returns the empty string (Tk's own default) | same — **re-run**: the first attempt was a `sed` that silently failed to match because of defect 6's NUL byte, and came back green |
| G ⟲ | `calc::sel_tristate` returns a real id (`vdc`) | same — also a re-run, same cause |
| H | the Stack scrollbar's four palette options deleted | `S20 the scrollbar wears the palette` + `is not still stock grey` |
| I | the scrollbar's `-command` dropped | `S20 the scrollbar actually drives the listbox` |
| W3 | the scrollbar not built at all | 4 — class, palette, not-stock, command |
| J | the `ttk::style map` block deleted (leaving only `configure`) | `S18 the readonly field colour is MAPPED, not just configured` |
| K | the mapped readonly foreground is the accent, not `fieldfg` | same |
| L | `.calc.mode.dest` no longer `-state readonly` | `S18 dest readonly` + `both comboboxes are the state the map covers` |
| M | the group separators painted `[calc::color panel]` | `S17 both group separators are drawn` — the strengthened half |
| N | `.calc.pw.sel` loses its caption | `S14 the five panes carry their captions` |
| O | `calc::sel_click` writes into the buffer (LENS 3's exact reproducer) | `S17/S18 no selector or mode control touched the buffer` |
| P | `calc::inert` writes to the buffer for every non-toolbar control (RX2) | same |
| Q2 | `calc::dest_changed` pushes onto the stack | 4 — incl. `S17/S18 no selector or mode control touched the stack` |
| R | the three pick-scope radios silenced (`-command {}`) | `S18 each pick scope names itself and its phase (R506)` |
| S | every selector but `vt` silenced (LENS 3's RX5) | `S17 every enabled selector names itself and its phase (R506)` |
| T | all three pick scopes carry `-value off` | `S18 the three scopes share ::calc::pickscope with their own values` + `each pick scope selects itself` |
| X | the `Off` scope carries a `-value` nothing seeds | 3 — incl. `S18 the sweep left the scope back at off` |
| U | selector `idc` carries `vt`'s `-value` | `S17 each -value is its own id` + `every enabled selector arms itself` |
| V2 | the buffer created `-state disabled` | 6 — both pre-press positive controls and both S21 buffer legs |
| AH | `.calc.stk.list` is not a listbox | 10 — incl. the stack half of both purity snapshots |
| AA | `calc::open` returns `{}` | 8 — every open/reopen fixture precondition, S1 through S21 |
| AB ⟲ | (recheck) the stretch put back on the last button's grid row | `S20 the four side buttons are one contiguous column` — still red at the NEW pane height |
| AD | the toolbar packed `-side top` (drawn above the buffer) | `S19 buffer AND toolbar are both mapped, buffer above` |
| AE ⟲ | (recheck) `-selectcolor` is the panel, not the field | `S17 every selector wears the palette` |
| AF ⟲ | (recheck) the `Calc.Field.TCombobox` configure block deleted | `S18 dest style is real, and carries no popdown offset` |
| AG ⟲ | (recheck) `Calc.TCombobox` loses its `-postoffset` | 3 — S16's two dropdown-width checks and S18's control |

⚠ **One check was disarmed by the fix and is recorded rather than hidden.**
`S19 buffer AND toolbar are both mapped, buffer above` used to go red when the
pack order was reversed; it no longer does, because pack only starves a slave
when the cavity is smaller than the sum of the requests, and the Buffer pane is
now big enough that either order fits. The check is still live — sabotage AD
(packing the toolbar `-side top`) reddens it — and the CONDITION it used to
catch is now guarded directly by `S21 no pane's contents are squeezed below
their requested height`. Sabotage AC (the plain order reversal) reddens only
`S19 the Buffer pane packs the toolbar first`, which is the right answer.

### 9.4 Suites — the audit diff, by name and status, both directions

Seven suites through `run_suites.sh` on `:99`, against
`receipts/00b-audit-baseline-2026-08-14.txt`:

| suite | baseline | now |
|---|---|---|
| test_calc_skeleton | PASS | PASS (327 checks, was 299) |
| test_wave_viewer | PASS | PASS (400) |
| test_accelerators | PASS | PASS |
| test_bindings_file | PASS | PASS |
| test_wave_trace_menu | PASS | PASS (397) |
| test_key_graph_context | PASS | PASS |
| test_ase_window | FAIL | FAIL — the same single `W7 simulator produced output before Stop` line item 1 recorded |

**No suite moved in either direction.** `grep -ln 'calc::\|calculator'
tests/headless/*.tcl` still names only `test_calc_skeleton`, so no other suite
greps the procs touched. `full_audit.sh` is item 99's.

### 9.5 Still owed

- **The pixels are still unjudged by a human.** Everything ran on `:99`. The
  fix round changes what the window LOOKS like in four visible ways — the
  default window is 60 px taller, the buffer is a real four-line box, the 22
  indicators are empty instead of dotted, and the two comboboxes and the Stack
  scrollbar are no longer stock grey — so the existing look debt is restated,
  not discharged. A new `owed.sh add look` entry names them.
- **A `:0` run of `test_calc_skeleton`.** S21 measures geometry, and WSLg's
  extra `<Configure>` traffic is exactly what D6 lives for. Recorded as a suite
  debt.
- Nothing staged, nothing committed, nothing pushed.
