# Item 02 — phase 1b: selector grid, mode strip, buffer + toolbar, Stack

Closing receipt. Ledger row 2; plan 1.2–1.5; spec §4 W06–W25, §5, §6, R202, R506.
**Verdict `[E]`** — 22 buttons in three groups, a mode strip, a toolbar and a
list, all real and all inert. 327 green checks pin paths, classes, initial states
and (since the fix round) rendered geometry and sampled pixels — not whether it
*looks* right. `02-phase1b.md` is the long-form working receipt, superseded here
on figures.

## 1. Files changed

```
 doc/claude/specs/calculator.md        |  74 ++-
 src/calculator.tcl                    | 581 +++++++++++++++++++++++-
 tests/headless/test_calc_skeleton.tcl | 830 +++++++++++++++++++++++++++++++++-
 3 files changed, 1453 insertions(+), 32 deletions(-)
```
Also committed: `02-phase1b.md`, this file, and three captures — `02-phase1b.png`
(pre-fix, quoted by that receipt's §9), `02-phase1b-fixed.png` (default first
open, 656x680), `02-phase1b-fixed-min.png` (at the derived 626x680 minimum). **No
rebuild** (sourced at runtime, `xschem.tcl:14381`). `LEDGER.md`, `recon/`, `ref/`
untouched — driver's.

## 2. Decisions taken, and the evidence

| ruling | evidence / why | written into |
|---|---|---|
| W11/W12/W14 are TEXT labels `Plot`/`Eval`/`Table`, not the reference's icons | no icon set a new dialog can draw from; an invented glyph font is a second asset for three buttons | spec §4 W11/W12/W14 |
| `.calc.pw.stk` loses its own title; `.calc.stk` keeps the `Stack` caption | phase 0 titled the pane `Stack` and W23 nests a titled labelframe inside it — the word was drawn twice | spec §4 W23 |
| R202's line comes from a `<Button-1>` bind, not `-command` | `invoke` and the Button class bindings both return early on a disabled widget; X still delivers the event | spec §5.1 R202 |
| flat `.calc.sel.<id>` paths beat the house per-group-frame idiom | recon §2's idiom yields `.calc.sel.g1.vt`; W07 is normative. Kept one data table + a loop; spacer columns do the grouping | `build_sel` |
| `-selectcolor` is the indicator's FIELD colour → role `field`; and Tk's default `-tristatevalue` `{}` collides with "nothing armed", so `calc::sel_tristate` returns a sentinel no id can hold, under `catch` (Tk 8.4 lacks the option) | xwd scanline at three selmode states — armed, unarmed, non-matching; also xschem's own `*selectColor white`. `{}` stays the normative unarmed value, which R201 returns to | `build_sel`, spec §4 W07 |
| `ttk::style map`, not `configure`, for a readonly combobox field | `configure -fieldbackground` never reaches `-state readonly` here: sampled (217,217,217) while the style reported `#ffffff` | spec R113a |
| **the phase-0 freeze means "do not redecorate", not "ship a control off the window"**: `wm minsize` now DERIVED from `winfo reqwidth .calc.pw.sel` (floor 560x680); fractions `{0.21 0.36 0.64}`→`{0.21 0.42 0.645}`; `.calc.pw.buf -minsize` left at 70 | defects 1–2 (§5) are only fixable there, and R112 already required every control to stay reachable. `-minsize`s, dragged sashes and the bot pane's 0.78 untouched — the defect was the DEFAULT allocation, not the floor, and a user may still drag the buffer smaller. **The driver may overrule.** | spec §4.2 rules 1–2 |
| spec §4 notes that six W-rows are `.calc` children drawn `pack -in`, and that `winfo ismapped` cannot guard them | `ismapped` returned 1 for two selectors entirely off screen | spec §4 |

## 3. Tests

`tests/headless/test_calc_skeleton.tcl` — new sections **S17–S21**; S1–S16 intact
and unrenumbered, with three phase-1a checks RESTATED in place (`⚠ RESTATED`,
none deleted) because filling a pane changes what is in it. **327, was 192.**
Verbatim: `RESULT: ALL PASS (327 checks)`

Non-vacuity with `HEAD:src/calculator.tcl` in place: `135 FAILED (192 passed)` —
every check ran, none lost to an abort; exactly eight pass without the feature,
all fixture preconditions or positive controls (`02-phase1b.md` §9.3). ⚠ That
receipt's §5 figure `108 FAILED (189 passed)` sums to 297, not 299; the
reproduced figure for that earlier run is `110 FAILED`. Corrected in place there.

## 4. Sabotage

**51 sabotages over the two rounds** (23 + 28), every one red, every one restored
from a byte-exact md5-verified backup and re-run green. The per-check, file:line
mapping is `02-phase1b.md` §6 + §9.3; every one of the 135 new checks is named by
a row there **except the three tautological ones below**. Load-bearing:

| check(s) | broken | red? | green after restore? |
|---|---|---|---|
| the 7 RF + `mp` disabled; invoking/clicking arms nothing; clicking explains why | `-state disabled` removed (A15); the `<Button-1>`→`sel_refuse` bind deleted (A20) | yes | yes |
| rows 1/2 in the spec's order; groups separated; both separators drawn, and (STRENGTHENED) visible | two ids swapped in `sel_rows` (A11,A12); spacer `incr col` deleted (A13); the `grid` deleted (A14); hairline painted `[calc::color panel]` (M) | yes | yes |
| every selector wears the palette; no legitimate selmode value renders as Tk's tristate | `-selectcolor`→`panel` (A24/AE), `-foreground`→accent (A25); `-tristatevalue` configure deleted (E), sentinel `{}` (F ⟲), sentinel a real id (G ⟲) | yes | yes |
| clip ON / toggles / toggles back / fresh window | seeded 0 (B14); `-onvalue 2` (B15) | yes | yes |
| dest values / initial / readonly / style / `combo_letter_cycle`; the readonly field colour is MAPPED, not just configured | `New Strip` dropped (B18); `set Replace` (B19); readonly dropped (B20/L); style swapped (B22); bind deleted (B21); the `ttk::style map` block deleted (J); mapped fg→accent (K) | yes | yes |
| every enabled selector / pick scope names itself + phase (R506); `calc::inert` is the one R506 route | all but `vt` silenced (S); all three scopes `-command {}` (R) — **both left the pre-fix suite ALL PASS**; `inert` body → `return {}` (A26), 8 red at once | yes | yes |
| no selector or mode control touched the buffer / the stack | `sel_click` writes to the buffer (O); `inert` writes for every non-toolbar control (P); `dest_changed` pushes (Q2) — **all three left the pre-fix suite ALL PASS** | yes | yes |
| buffer height / undo / editable / colours / caret; toolbar packed first, both mapped, buffer above; ten toolbar buttons, order, labels, Undo/Redo disabled | `-height 6` (C2); `-undo 0` (C3); `-state disabled` (C4); roles swapped (C5–C7); pack order reversed (C8/AC); toolbar `-side top` (AD); `ME` row deleted (C10); `Enter`→`Entr` (C11); rows swapped (C12); disabling deleted (C13,C14) | yes | yes |
| Stack: title, listbox class, colours, empty, side buttons contiguous; the scrollbar's class / palette / not-stock-grey / `-command` | `-text {}` (D2); listbox→frame (D6/AH); colours swapped (D8–D10); `recall` dropped (D11); stretch back on the last row (D14/AB ⟲); scrollbar not built (W3), palette deleted (H), `-command` dropped (I) | yes | yes |
| the five panes carry their captions; the S21 minimum block; all 22 on screen; reopen not clipped; the buffer shows four lines; no pane squeezed; S11 proportions | `.calc.pw.sel` caption emptied (N) — **left the pre-fix suite ALL PASS**; `apply_minsize` deleted (A3); a LYING minimum reporting the derived value while setting 1x1 (Y2); forced 500x680 (Z); fractions reverted (C); floor 680→620 (B); an even split (D) | yes | yes |

**Unsabotaged, therefore NOT evidence — three checks:** `S17`/`S18`/`S20 parent
is .calc`. In Tk the path *is* the parent, so only deleting the widget reddens
them (A1/B2/F1); they fire on absence alone. Every other check the implementer
listed as unsabotaged was later covered (`grid is mapped`←A3, `strip below the
grid`←B3, `dest binds combo_letter_cycle`←B21, `snapshot`←C4/C1, `Stack pane`←D3).

⚠ **One check was partially disarmed by the fix — recorded, not hidden.** `S19
buffer AND toolbar are both mapped, buffer above` no longer reddens on a plain
pack-order reversal: pack starves a slave only when the cavity is smaller than
the sum of the requests, and the corrected Buffer pane fits either order. It is
still live (AD reddens it), the condition it caught is now guarded by `S21 no
pane's contents are squeezed`, and AC reddens `S19 the Buffer pane packs the toolbar first`.

## 5. What was NOT verified

**Audit diff, by name and status, both directions.** Seven suites through
`run_suites.sh` on `:99` vs `receipts/00b-audit-baseline-2026-08-14.txt`:
`test_calc_skeleton` PASS→PASS (327 checks, was 192), `test_wave_viewer`
PASS→PASS (400), `test_wave_trace_menu` PASS→PASS (397), `test_accelerators`,
`test_bindings_file`, `test_key_graph_context` PASS→PASS, `test_ase_window`
**FAIL→FAIL** (the same single `W7 simulator produced output before Stop` line
item 1 recorded). **No suite moved either way.** `full_audit.sh` — item 99's.

- **THE PIXELS.** All on `:99`, nothing on `:0`. Look debt recorded via
  `owed.sh add look`, **uncleared** — only the user clears one. Unjudged: the
  hairline separators as dividers or as dirt; `Plot`/`Eval`/`Table` as words vs the
  reference's icons; the eight greyed ids as information or as breakage; the
  Stack's four fixed-width buttons vs its round icon column; the doubled Stack
  border; and the fix round's four visible changes (empty not
  dotted indicators, a real four-line buffer, non-grey combobox and scrollbar, a
  window 60px taller). Plus a `:0` run of `test_calc_skeleton`, a suite debt: S21
  measures real geometry and WSLg's extra async `<Configure>` traffic — what D6
  exists for — is what Xvfb cannot produce.
- **Reviewer findings raised but not confirmed: none** — all 13 confirmed were
  fixed in the round or are duplicate framings of defects 1–2. **Not-proven,
  carried forward:** (a) no reviewer reproduced the 23 item-round sabotages —
  only B21 was re-run, and it *refuted* the implementer's claim that it was
  unsabotaged; (b) `Calc.Field.TCombobox`'s isolation from
  `Calc.TCombobox`/`Ase.TCombobox` was reasoned, never sabotaged; (c) whether
  `balloon_show` renders over a disabled radiobutton, and whether its deferred 1s
  `after` can fire on a widget destroyed by closing the Calculator inside that
  second; (d) a dark palette; (e) keyboard reachability (new controls are
  `-takefocus 0` bar the buffer) and a synthesised `<Key>` — typing is asserted
  via `insert`/`edit undo`, bare `event generate` being a ~1-in-5 flake here.
- **Latent, deliberately not fixed:** the `sel_refuse` bind is attached to the
  eight disabled ids and never removed, so a later phase that enables `mp` gets a
  selector that both arms and prints its refusal — whoever enables `mp` owns it.
  Same bucket: the disabled `.calc.btb.undo`/`.redo` are silent on a click where a
  disabled SELECTOR explains itself (R202 is about selectors only).
  **R201 and all other behaviour** is absent by design — each `-command` names
  the phase that owns it.
