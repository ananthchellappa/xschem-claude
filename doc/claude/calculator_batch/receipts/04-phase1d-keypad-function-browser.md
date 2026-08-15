# Item 04 — phase 1d: the keypad (RULING-2) and the function browser over one catalogue

Closing receipt. Ledger row 4; plan 1.6–1.7; spec §4 W26–W31, §7.1, §7.2, R413, RULING-2, RULING-3. **Verdict `[E]`**
— the last two phase-0 placeholders are gone, every pane holds its real controls, and all of it is still inert. **438
checks** (327 at phase 1b), **109 sabotages** over three rounds, no suite moved either way. The payload is a window
full of names and operators; no number judges whether it reads. `04-phase1d-keypad-functions.md` is the long-form
working receipt — its §8 is the fix round, its §9 the per-check sabotage map this receipt's §4 points at.

## 1. Files changed

```
 doc/claude/specs/calculator.md        |   94 ++-
 src/calculator.tcl                    |  708 ++++++++++++++++++++--
 tests/headless/test_calc_skeleton.tcl | 1042 ++++++++++++++++++++++++++++++++-
 3 files changed, 1787 insertions(+), 57 deletions(-)
```
Also committed: `04-phase1d-keypad-functions.md`, this file, and two captures — `04-phase1d.png` (as first shipped)
and `04-phase1d-fixes.png` (after the fix round), both default first open, 656x680, dev display `:99`. **No rebuild**
— `calculator.tcl` is sourced at runtime (`xschem.tcl:14381`). `LEDGER.md`, `recon/`, `ref/` untouched (driver's).
Nothing else in this dirty tree was staged.

## 2. Decisions taken, and the evidence

| ruling | evidence / why | written into |
|---|---|---|
| **The keypad set is the twelve operator tokens `+ - * / ** ? == != > < >= <=`** — eleven binary plus the ternary `?`; no digit, no `±`, no `.` | RULING-2 fixed the principle and left the set to the crew. Every key emits a token `plot_raw_custom_data()` really lexes (`save.c:2414-2425`); §3.1 makes one unknown token return `-1` for the *whole* expression. A key survives RULING-2 because R510/R511 give a binary-operator **button** stack semantics no keystroke has; a digit has no second meaning. `.` is not lexable alone (`strtod(".")` fails → looked up as a vector name → `-1`) | spec §4 W30 |
| **`?` is NOT binary and phase 4 owes it its own rule** | `#define COND 49` (`save.c:2361`) dispatched at `2531-2536` under `if(stackptr2 > 2)`, consuming **three** entries. The first cut's W30 said "twelve binary tokens" while its own catalogue row said three — one ruling and one table disagreeing inside one commit, with ledger item 10 reading W30 as its contract | spec §4 W30 (+ `pad_keys` comment, S24) |
| **`.calc.pw.bot.pad -minsize` STAYS at 140** — the phase-0 look debt, settled with a measurement | `winfo reqwidth .calc.pad` = **128**, `.calc.pw.bot.pad` = **140**: not slack, it is what the pane's contents ask for to the pixel. 128 was tried and clipped the keypad to 126/128 at the first-open sash. **S4's number unchanged**; S22 now pins it to `winfo reqwidth` so it is never again a guess | `build_panes`, S4/S22 |
| **`.calc.pw.bot -minsize` 140 → 158** — a *second* amendment to a frozen phase-0 minsize, taken deliberately | filling the pane took its `reqheight` 67 → 158; at the pane's own legal floor `user 3`/`user 4` hung 3 px past `.calc.pad`. A minimum that hides a control is what landmine D3 exists to prevent. New `calc::apply_pane_minsize` keeps phase 0's numbers as **floors** and raises only the two panes item 4 filled; S4 changed in the same commit. **The driver may overrule** — dropping one table row + S4 back to 140 reverts it, and three checks go with it | `apply_pane_minsize`, spec, S4/S22 |
| **`.calc.fn.list` is a `canvas`** | the signal browser's own enumeration applies verbatim (`wave_viewer.tcl:9429-9436`): treeview tags are per **row**, so `dft` could not be greyed without greying its five neighbours; side-by-side listboxes each own their `xview`, so W28's one h-scrollbar could not scroll the grid | spec §4 W28 |
| Entries render **alphabetically**; `All` is synthetic; the row schema is six fields `{name category route returns insert help}` | §7.2's table order is the order to *read the spec* in, the wrong one to *look a name up* in; the reference sorts the same way | spec §7.1 |
| **`calc::status` takes `record` (default 1)**; R413 hover passes 0 | help is a legend, not an event: 56 entries under a moving pointer would spend R509's 50-entry cap on tooltips | spec R507 |
| **The five T-verbs standing on `dft` carry route `N`** | with `dft` absent there is no T to write; this keeps the **table** the single source for the disabled state, which is RULING-3's requirement | spec §7.2a |
| **Catalogue defects D1–D7 all applied, none rejected** | D1 category `Special`→`Special Functions` *in the data* (else the default category renders empty); D2 `lshift` is a **T** route emitting nothing (the `del()` recipe reads past a `my_calloc` — item 12's); D3 `returns` added, `integ`/`iinteg` no longer identical; D4/D5/D7 spec text corrected against the C (`MAX` returns the *greater* operand so `max()` is a **floor**; `CPH` unwraps by 360; `/` by zero yields `y[p-1]` unless the dividend is 0); D6 `groupDelay` emits **`cph() deriv() -360 /`** — φ is in degrees and `deriv()` differentiates against **Hz**, so the spec's string was short of −dφ/dω by π/90 | spec §3.2 note, §7.2a |
| **Refusals are short enough to render**: `fn_reason N` → `needs a C opcode not in v1` | the composed line was 94 chars / 666 px against a 613 px `.calc.status.msg` and ended `…no N-route function sh`. RULING-3's point is that a greyed entry *carries information* | `fn_reason`, S24 |

## 3. Tests

`tests/headless/test_calc_skeleton.tcl` — new **S22** (keypad), **S23** (browser), **S24** (catalogue); S1–S21 intact
and unrenumbered. **438 checks, was 327**: 115 added, 4 removed by restatement (S14's two per-pane placeholder-hint
colour checks — their subject no longer exists, `calc::placeholder` being deleted with its last two callers; the
surviving check now covers all five panes, plus a new one that the proc is gone). Nothing else deleted, nothing
renumbered.

Verbatim: `RESULT: ALL PASS (438 checks)`

**Non-vacuity, measured**: with `git show HEAD:src/calculator.tcl` in place the file reports `110 FAILED (328 passed)`
and **runs to the end** — no outer-catch abort. Getting there took three attempts; twice a new leg threw against a
keypad-less tree and took S23/S24 down with it, the trap this suite already records twice.

## 4. Sabotage

**109 breaks over three rounds — 22 (item) + 63 (verification, 85 runs) + 24 (fix) — every one red, every one restored
from a byte-exact md5-verified backup and re-run green** (`src/calculator.tcl` `8cb530b2…` through the first two
rounds, `14128a26…` through the fix round; both md5s identical before and after). **The per-check table — one row for
each of the 115 added or changed checks — is §9 of `04-phase1d-keypad-functions.md`, committed with this receipt.** By
family:

| checks | broken | red? | green after restore? |
|---|---|---|---|
| S22 the pad exists, is a frame, is in the Keypad pane, stacks above the panedwindow, is topmost at its centre; palette on keys and frame; both R506 lines; neither touches buffer nor stack (12) | `open` returns `.nope` (A01); `labelframe` (A02); `destroy .calc.pad` (A03); `place` for `pack -in` (A04); `lower .calc.pad` (E01); `k1 -background #123456` (A13); pad `grey40` (A14); phases 2→3 / 9→8 (A15,A16); `pad_click` writes to `.calc.buf` (A17) and to the Stack (A18) | yes | yes |
| S22 the twelve keys in order, no k13, no digit/`.`/`±`, four user buttons, no u5, all pressable, all on screen (10) | `?`→`.` (A08); a 13th token (A09); `pad_keys` reordered (A10); labels `u$i` (A11); a fifth user button (A12); `k3` disabled (A06); `pad_cols` 4→1 (A20) | yes | yes |
| S4/S22 both derived minimums, and the sash dragged to the bottom pane's floor (6) | pad `-minsize` 140→100 (A19); the pad row dropped + floor 140→100 (B); the `.calc.pw.bot` row dropped (A), the raise disabled (C), only that row removed (S) | yes | yes |
| S23 the browser exists, is a frame, is in the Functions pane, and all three stacking legs (6) | `labelframe` (B01); `destroy .calc.fn` (B02); `place` (B03); `lower .calc.fn` (D) — **D left the pre-fix suite ALL PASS (415)** | yes | yes |
| S23 the chooser: class, §7.1 values in order, initial `Special Functions`, readonly, `combo_letter_cycle`, style (7) | `ttk::spinbox` (B04); reordered (B06); initial `Arithmetic` (B07); `-state normal` (B08); the bind deleted (B09); `Calc.TCombobox` (B10) | yes | yes |
| S23 the list: canvas, field colour, both scrollbars wired/oriented/palette, both `-*scrollcommand`, both partial views, a real scrollregion wider than the pane (10) | `text` (B05); `grey70` (B11); hsb → `yview` (B12), `-orient vertical` (B13); scrollregion `{0 0 0 0}` (B14) and width 10 (B15); both `-*scrollcommand` deleted (E) — **E left the pre-fix suite ALL PASS with both bars dead** | yes | yes |
| S23 56 entries, the table's names, alphabetical, six column-major columns (7) | one entry dropped (B16); `lsort` dropped (B17); `AVERAGE` (B18); `fn_cols` 6→4 (B19); row-major index (B20) | yes | yes |
| S23 RULING-3: exactly the 14 greyed, in a colour that differs, all RENDERED, greying read off the **route field**, greying follows a runtime move of the dead set, the repaint leaves 56, each refuses with its own reason (8) | live colour everywhere (B21); `disabledfg`=`fieldfg` (B22); dead rows dropped (B23); hardcoded list **agreeing with the table** (I) — **I left the pre-fix suite ALL PASS**; hardcoded + `psd` route moved (J); `$c delete all` removed (T) | yes | yes |
| S23 hover: per-entry bindings, help from the one table, records nothing, B's `<Leave>` cannot wipe A's line, leaving retires it, leaving spares a later message (7) | `<Enter>` bind deleted (B24); a second-table string (B26); `record 1` (B27); `status` default `record 0` (B28); shared-`fnhelp` guard (K); early return (U/B29); unconditional clear (V/B30) | yes | yes |
| S23 clicks: live entry inert + phase, N and X refusals, neither touches buffer nor stack, a real `<Button-1>` reaches the handler (7) | phase 5→4 (B31); `fn_reason N`→`{}` (W/B32); `X` reworded (X/B33); `fn_click` writes to buffer (B34) / Stack (B35); `<Button-1>` bind deleted (B36) | yes | yes |
| S23 category switch repopulates, says so, `All` is the union, and the view snaps back to the top-left with the alphabet's head visible (6) | counts instead of filling (B37); message reworded (B38); the `All` arm dropped (B39); the `xview/yview moveto 0` pair removed (F); scrollregion 10 so the fixture cannot scroll (G) | yes | yes |
| S24 shape: non-empty, six-field schema, six-field rows, every §7.1 category non-empty in the spec's numbers, category values legal, `All` synthetic, no duplicate name in a category or across the table (10) | catalogue `{}` (C01); `returns` dropped from the schema (C02) and from a row (C03); a row deleted (C04); `clip`→`All` (C06); a second `average` (C07); `idx()`→`abs()` (C08) | yes | yes |
| S24 engine coupling: the §3.2 token set, primitives insert themselves, every token lexable or numeric, compositions >1 token (L3), T/N/X emit nothing, the four C-route strings pinned by literal and *are* the whole C set (12) | `sgn()`→`sign()` (C09); `sqrt()`→`abs()` (C10); `rms` emits `mean()` (C11); `dBm`→one token (C12); `stddev` given an insert (C13/P); `rms`/`dBm`/`rmsNoise`/`groupDelay` rewritten to plausible wrong RPN (L,M,N,O) — **L/M/N left the pre-fix suite ALL PASS** | yes | yes |
| S24 the audited defects (D1 category string, D2 `lshift` T-and-silent, D3 `integ`≠`iinteg`, D6 `groupDelay`, the `?` row's category and its **three**-operand help); the disabled set is the ledger's N + X; a live route has no reason and a dead one does; every help line **and** every composed refusal fits the entry (12) | `Special` restored (C05); `lshift` back to C/`del()` (C14); `iinteg` reverted (C15); `cph() deriv() -1 *` (C16); `?`→Trigonometric (Q); help as two operands (R); `psd` N→T (C17); `fn_reason` inventing a reason for P (C18); help past 72 chars (C19); `fn_dead_routes` forgetting X (C20); the 94-char reason restored (H) | yes | yes |
| S14 no pane keeps a placeholder hint (restated over all five); the proc is gone with its last caller (2) | a hint packed back into the Keypad pane (D02); `calc::placeholder` resurrected (D01) | yes | yes |

**Unsabotaged, therefore NOT evidence — three checks**, all fixture preconditions or positive controls that assert the
*test's own* sentinel arrived: `S22 the pre-press snapshot is real text`, `S23 the pre-click buffer snapshot is real
text`, `S24 fixture: the spec's §3.2 lists 52 tokens`. No sabotage of item-4 code can redden them; what they buy is
that the purity and lexability checks beside them are not vacuous. ⚠ Two more are reddened only by widget **deletion**
— `S22/S23 parent is .calc` — because in Tk the path *is* the parent.

## 5. What was NOT verified

**Audit diff, by name and status, both directions.** Four suites through `run_suites.sh` on `:99` against
`receipts/00b-audit-baseline-2026-08-14.txt`: `test_calc_skeleton` **PASS→PASS** (438 checks, was 327),
`test_wave_viewer` **PASS→PASS** (400), `test_accelerators` **PASS→PASS**, `test_bindings_file` **PASS→PASS**. **No
test moved in either direction.** Three more, unnamed by the driver, were run in the fix round: `test_wave_tabs`
PASS→PASS (172), `test_binding_precedence` PASS→PASS, and `test_palette`, which prints no `RESULT:` line so
`run_suites.sh` scores it `NORESULT` against a baseline `PASS` — proved not this item's doing by A/B against
`HEAD:src/calculator.tcl` (byte-identical output), and that file names no `calc::` anything. `full_audit.sh` is item
99's.

- **THE PIXELS. `[E]`.** Two look debts recorded and **uncleared** (only the user clears one), one for
  `04-phase1d.png` and one for the fix round's `04-phase1d-fixes.png`, plus a closing one for both together. Unjudged:
  whether six columns of names are *readable* at the default size (§11.4 says this is the thing no test can answer);
  whether the 14 greyed entries read as information or as breakage; whether a list needing **both** scrollbars at
  first open (8 of 10 rows, ~4.5 of 6 columns; column 6 not visible, column 5 in 2-character stubs) is right or
  whether the browser should get more of the window; the keypad's ~180 px of empty pane under the user buttons;
  `**`/`?`/`>=` as button labels; the four small categories rendering as one row rather than six columns; and whether
  the *shortened* refusal still says enough for RULING-3.
- **The phase-0 look debt is answered, not cleared.** *"Calculator phase 0 keypad pane width"* was settled on the
  engineering side by measurement (§2) and put under a check; the debt itself stands, uncleared, for the user.
- **`:0`.** Nothing ran there, per policy. The existing `test_calc_skeleton` suite debt covers it; S22/S23 *add*
  rendered-geometry legs (a real `sash place` drag, three `winfo containing` probes, canvas bboxes after a repaint) of
  exactly the kind WSLg's async `<Configure>` traffic has moved before.
- **Reviewer findings raised but NOT confirmed: none** — the three lenses raised sixteen, all confirmed, deduplicating
  to eleven distinct defects; **all eleven applied, none rejected.** One (`probe_calc_*.tcl` droppings) needed no
  code: both files were already gone (`ls` → no such file).
- **Marked not-proven by the reviewers, carried forward:** (a) D2's out-of-bounds read in `ravg_store()` was reasoned
  from the C, never executed — item 12's; (b) the claim that `-minsize 128` clips the keypad to 126/128 was not re-run
  by any reviewer; (c) the non-vacuity leg was re-run by one reviewer, not all; (d) two reviewers did not themselves
  diff the 52 `strcmp` arms or read the `MAX`/`CPH` arms; (e) a hypothesis that `fn_unhover` can wipe an identical
  *recorded* message (only `freq`/`frequency` share help text — harmless) is recorded, not fixed; (f) `calc::close`
  does not reset `fnhelp`, with no user-visible consequence found; (g) whether the greyed entries should be
  *unclickable* rather than answering with a refusal — judged a defensible reading of R202's shape, not a violation.
- **Known and deliberately left:** the `raise` loop in `build_panes` is dead code for both new widgets (Tk already
  stacks later siblings above earlier ones) — cheap insurance, but its comment overstates what it does;
  `.calc.pw.buf`/`.calc.pw.stk` minimums are *not* re-derived (arguably right, not this item's call); no selection
  rendering and no wheel scrolling in the list, because insertion is phase 5.
