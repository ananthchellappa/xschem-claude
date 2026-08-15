# Batch F item 10 — D5: what a digital database contributes to backannotation

Branch `fluid-editing`, base `c6d26026`. Ruling: **NOTHING** — and it was not already true.

## 1. Files changed

`src/save.c` +144/-2 — a `digital` column on `raw_reader_table[]`; the predicates `raw_type_is_digital()`/`raw_is_digital()`/`raw_file_is_digital()` (sniffs `$enddefinitions`); `backannot_refuse_digital()` mints the one sentence; `update_op()` refuses · `src/token.c` +47/-6 — the D5 term on all six `@spice_get_*` live-backannotation gates · `src/scheduler.c` +63/-5 — `annotate_op` refuses BEFORE loading or clearing, `~/` resolved in C not via `tcleval(regsub …)`, new read-only `xschem raw is_digital [<type>]` · `src/callback.c` +42/-6 — `publish = !raw_is_digital(xctx->raw)`, array UNSET when refusing, no substitute publisher · `src/xschem.h` +15 · **new** `tests/headless/test_backannotate_digital.tcl` +748 · `full_audit.sh` +1/-1 (joins `nogui_tests`) · `test_wave_cursor_crossdb.tcl` +15/-6 (XC52 rationale only; assertion byte-identical) · `doc/claude/specs/mixed_signal_signal_browser.md` +301/-3 (rulings + D5 row).

## 2. Decisions, and the evidence

All eight rulings are written into `doc/claude/specs/mixed_signal_signal_browser.md` section "D5 — backannotation and the digital database"; no doc still says D5 is open.

- **D5-1 — a digital DB contributes nothing.** A logic level is not a voltage, and `vcd_read()`
  encodes X as **0.5**, Z as **0.3**. Evidence: on the pre-item binary the schematic read
  `top.m.same = 1` where the analog raw interpolates **0.7535**.
- **D5-2 — single-sourced** off the reader table's new `digital` column, so a future reader
  inherits the ruling by filling in its row; `table` is deliberately *not* digital (S9, 1 red).
- **D5-3/3a — three enforcement points, three roads onto the array:** `update_op()` (all four call
  sites funnel through it), the `annotate_op` arm (refusing *before* any side effect — S11 moves it
  below the load, BA22/BA23 catch the registry growing), and the cursor-B publisher. The array is
  **unset**, not left standing (S6), and no substitute DB promoted (S7) — else which values show
  would depend on registry order.
- **D5-4 — the REQUEST paths say why, the CURSOR path is silent.** One sentence minted once, put on
  the CIW via guarded `ciw_echo` *and returned*; a notice per cursor motion is noise.
- **D5-5 (review round) — the `@spice_get_*` FLOATERS are the overlay too.** Round 1 guarded only
  the Tcl array; `token.c` read `cursor_b_val[]` out of the current DB, so `lab_pin.sym` printed
  `1` (analog `0.7535`) and `0.5` on an UNKNOWN net as schematic text. Now blank — *"contributes
  nothing" is not "contributes a dash"*.
- **D5-6 (review round) — the refusal asks the FILE, not only the type token.** Both GUI call sites
  spell `xschem annotate_op $tctx::retval` with no type, so Op Annotate on a `.vcd` was unrefused
  *and* wiped the standing annotation and the loaded OP.
- **D5-7 (review round) — `raw switch` deliberately does NOT touch the array.** Ruled, not coded:
  `wviewer::signal_list_all`'s All-DBs search walks every loaded DB with exactly that call, so
  clearing on entry would let a *search* wipe the design window's backannotation. BA90-92 pin both
  directions, S23 implements the rejected alternative and reddens BA91.
- **Collateral, not a listed finding:** `annotate_op`'s pre-existing `tcleval(regsub {^~/} {%s})`
  ran a crafted rawfile path as Tcl and the sniff fix had to move the refusal below it. Resolved in
  C; `PWNED 1` -> `0` (BA96).

## 3. Test and result

`tests/headless/test_backannotate_digital.tcl` — **81 checks**, true headless, now in the audit's nogui arm. Verbatim:

```
PASS     | test_backannotate_digital    run 1/1  RESULT: ALL PASS (81 checks)
```

No neighbour's count shrank: `test_wave_cursor_crossdb` 93, `test_ase_cosim` 310, `test_vcd_read` 187, `test_node_token_split` 168, `test_raw_read_dispatch` 51; X arm 130/400/73/488.

## 4. Sabotage table

31 sabotages, each applied alone, built, run, restored from a byte-exact backup (`md5sum -c` clean). **76 of the 81 checks driven red.** Grouped by sabotage; every id appears exactly once.

| Checks | What was broken (sabotage) | red? | restored? |
|---|---|---|---|
| BA11 BA19 · BA12 · BA15 | S1/S2 `raw_type_is_digital()` short-circuited / the `vcd` row's `digital` zeroed (19 red each) · S9 `table` marked digital (1) · S8 `raw_is_digital(NULL)` returns 1 | yes | yes |
| BA10 BA13 BA14 BA17 BA30 BA31 BA36 BA50 BA80 | S18 an unknown type reads digital (BA80 = the ANALOG floater control) | yes | yes |
| BA20 BA73 · BA21 · BA24 | S4 `annotate_op`'s refusal disabled · S10 the sentence drops "not an operating point" (1) · S27 BOTH request refusals deleted | yes | yes |
| BA22 BA23 BA28 BA2b · BA25 BA26 BA2a · BA27 BA29 | S11 the refusal moved BELOW the load (registry grew, current DB changed) · S14 `annotate_op` refuses EVERYTHING (the control) · S22 the `$enddefinitions` file sniff disabled | yes | yes |
| BA32 BA33 BA34 BA35 BA72 BA74 · BA43 BA44 BA71 · BA4a BA63 BA90 | S3 `update_op()`'s refusal deleted · S12 every DB in the fan-out publishes · S20 a static latch: once digital is seen, publish 0 forever | yes | yes |
| BA46 BA47 BA49 BA92 · BA48 · BA4b | S5 the cursor-B publish guard removed = THE SHIPPED DEFECT restored · S6 guard kept but `Tcl_UnsetVar` deleted (stale overlay) · S7 a substitute publisher promoted | yes | yes |
| BA52 BA58 BA59 · BA4c BA57 BA60 BA61 BA62 | S24 a TRUE ADDITIVE MERGE (stealthy per-name skip) — the byte-identical-annotation invariant · S28/S17 fan-out restricted to the entry DB / the digital DB dropped from D4's walk (THE OVER-REACH) | yes | yes |
| BA18 BA42 BA45 BA51 BA70 BA83 BA84 · BA16 BA41 BA54 BA2z | S29 the VCD reader reports failure · S31 the SPICE reader reports failure | yes | yes |
| BA1c · BA1a BA1b · BA1d | S32 `get_raw_value()` returns 0.0 · S33 `get_raw_index()` never resolves · SF the VCD scope upper-cased, so there is no collision at all | yes | yes |
| BA81 BA82 BA85 · BA86 · BA87 | S21 the D5 term removed from all six `token.c` sites (floater printed `1`, `0.5` on UNKNOWN) · S30 a static latch at the five `translate()` sites · S21a the term removed from ONE site | yes | yes |
| BA91 · BA96 BA97 · BA98 | S23 `raw switch` unsets the array = D5-7's rejected alternative · S25 the `regsub` path resolution restored (`::PWNED` measured) · S26 the sentence concatenated into Tcl again | yes | yes |
| **BA40 BA53 BA55 BA56 BA5a** | **UNSABOTAGED — NOT EVIDENCE**, see §5 | no | n/a |
| BA99 | the ran-to-the-end guard: green by design, not a claim about D5 | n/a | n/a |

## 5. What was NOT verified

**The 31 sabotage runs are the implementer's and fixer's measurements, re-read but not re-executed by me; the spec's stale count of "29" was corrected to the 31 enumerated patches.** **Five hollow checks, declared rather than found later.** BA40 (cursor B enabled) and BA56 (`top.m.donly` is VCD-only) are premises about files the test itself writes. BA53/BA55/BA5a are **weak by construction** and labelled so in the file — the analog DB is current in both arms of BA53/BA55 and `update_op()` reads exactly one database, so all three survive every publisher sabotage including S24. Evidence-bearing coverage **76/81**. Two **SOURCE WITNESSES** are weaker than behaviour: BA87 counts the six `token.c` gates (the fixture reaches only one branch; the rest need a wired multi-pin instance and a device-current vector, and S21a reddened nothing until BA87 existed), and BA98 line-scans `backannot_refuse_digital()`, whose CIW half runs only under `has_x` — its behavioural proof is a manual run on the real display `:0`.

**Raised but not confirmed / not proven, carried forward.** (a) `wviewer::db_is_digital`
(`src/wave_viewer.tcl`, RULING F4) is a **second** answer, case-insensitive where the C predicate
is not and **not pinned** against it — measured to disagree (`is_digital VCD` → 0 vs 1) but not
shown reachable; D5-2's "single-sourced" is a C-side property, not a whole-tree one, and nothing
reddens the day a reader joins one list only. (b) `src/ngspice_backannotate.tcl:68` `upvar
::ngspice::ngspice_data` is a **third** writer of the overlay array outside the predicate's reach;
it parses a simulator *log* so it never sees a VCD — code read, not measured. (c) `annotate_op
<f>.vcd 0 VCD` (upper-case) still returns the bare path with no sentence: unchanged from before
this item and unreachable for a fabricated volt, but D5-4 is not universal. (d) `annotate_op`'s
delete-previous-OP branch being op/dc-only, and multi-dataset / many-point databases against the
refusal: read, agreed, **not exercised**. (e) No real co-simulation ran — the DBs are synthesized
(`mkraw`/`mkvcd`/`mkop`), so Verilator's real scope naming is untested. (f) **Adjacent, NOT
fixed:** `signal_browser_teardown_scoping.md` §1's All-DBs `update_op` clobber (an *analog* op/dc
slot rewriting `ngspice_data` during `signal_list_all`) — D5 removes one arm of it.

**EYEBALL OWED — confirmatory, not the payload** (an invariant plus three refusals, machine-checked against the exact strings `draw.c` expands): (1) VCD current → a `lab_pin` label renders **blank**, not a number, not `-`, not `0.5`; (2) analog + VCD, analog current → overlay unchanged from analog-alone; (3) VCD current + cursor B → overlay `?` everywhere while the readout bar still reads the digital trace; (4) the CIW sentence wraps sensibly and is not clipped.

**AUDIT** — my own `full_audit.sh`, `GUI_GATE=1 DISPLAY=:0` (root 5120x1440, no window at
-32768, so not issue 0310's stub): `280 pass 25 fail 3 crash/timeout 1 skip (total 309)`,
`WIREEDIT: ALL PASS`, `SCRATCH: 0 leaked dir(s)`. Diffed by NAME and STATUS against
`doc/claude/batch_F/baseline_status.txt` @ 7a592f9c — **18 rows moved. NEW, all PASS:**
`test_backannotate_digital` (this item), `test_wave_cursor_crossdb` (item 9),
`test_wave_sigbrowser_digital` (item 5). **GREEN-WARD (7):** `test_ase_persist`,
`test_fluid_bodyshove_guards_0132`, `test_wave_axis_zoom`, `test_wave_crossdb_trace` (this item's
two-database neighbour), `test_wave_sigbrowser_i12`, `test_wire_vertex_grab` FAIL→PASS;
`test_rotate_stretch_dangling_0103` SKIP→PASS. **RED-WARD (7), EVERY ONE RE-RUN AND ALL PASS:**
`test_altf5_ciw`, `test_ase_dialogs` (133), `test_hover_highlight`, `test_sod_pick_no_select_0204`
(66), `test_wave_tabs` (172), `test_wave_trace_menu` (397) PASS→FAIL; `test_apply_hilight_log`
PASS→TIMEOUT, ALL PASS when re-run in the audit's own `--logdir` arm. **Plus**
`test_fluid_editing` FAIL→SKIP: baseline-red already, and a re-run reproduces the baseline FAIL
(FE8, an arc/dirty-buffer fluid check), so the audit's SKIP is the anomaly, not a new failure.
**Attribution:** a `grep -lE` for `raw_is_digital|is_digital|annotate_op|update_op|ngspice_data|spice_get_voltage|raw read` over all eight files returns **nothing** — not one reaches the changed publisher, refusal or floater surface. The 58 `wireedit` rows are absent from the audit's per-test list, the same parsing artifact items 5 and 9 reported; its own summary reads `WIREEDIT: ALL PASS`.
