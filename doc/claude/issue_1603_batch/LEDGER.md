# Ledger — issue 1603 batch

Receipts land in `receipts/`. One row per handed-off task, collected by the driver.

| # | task | crew | receipt | verdict |
|---|---|---|---|---|
| A | rebuild the typeless-symbol fixture; drive every back end; count real crashes | `measure:fixture+drive` | `receipts/A-measure-and-triage.md` | **collected — 2 of 26 driven**, both with gdb backtraces; the issue's premise about NULL corrected |
| B | static triage of the netlister cluster | `triage:netlisters` | folded into receipt A | **collected — 16 of 19 are false positives**; 2 need guards, 1 must stay unguarded |
| C | static triage of draw / editprop / scheduler / token | `triage:rest` | folded into receipt A | **collected** — `draw.c` is a wrong-field guard, `scheduler.c` ×3 is one decision, `token.c` ×3 unreachable by caller contract |
| D | adversarially refute every claim | `verify:refute-claims` | folded into receipt A | **collected — refuted no verdict, refuted the EVIDENCE for several**, and turned the fragility argument into a one-token measurement |
| E | land the four guards, document the invariant, fence it all | `impl` | folded below | **collected — 9 rows, `ALL PASS` on both arms**, every row sabotage-verified, and `netlist_diff.sh` **BYTE-IDENTICAL across 905 netlists** |

## What the measurement round settled, and it reorders the issue completely

**The netlister cluster was the wrong priority, and the driver said so to the user before
measuring.** The recommendation rested on "19 of 27 sites are in the netlisters, and netlisting
runs headless in every batch flow". The count was right; the implication was not. That cluster
contains **zero** driven defects — 14 sites already guard, 2 are commented-out code, 3 are
unreachable by caller contract. The two real crashes are in `scheduler.c` (`sch_pinlist`, true
headless, two lines of Tcl) and `draw.c` (display, after one ordinary `setprop`).

**The issue's premise about when `type` is NULL was wrong.** A missing `type=` is not enough:
`set_sym_flags()` rewrites it to `""` for any symbol with any global property. The NULL state
requires an **empty or absent `G`/`K` record**. Any future fixture that gets this wrong measures
nothing — which is why the new suite carries a control row proving its own fixture.

**16 of 26 candidates were mis-classified by the original sweep**, not one as the issue conceded,
and six of those were guarded on the *immediately preceding line* at the sweep's own commit. The
sweep's method was the real defect: a `strcmp` regex is blind to `IS_LABEL_OR_PIN`, and that blind
spot hid `netlist.c:1024` — the site that actually faults first, and the only unguarded use of
that macro in the whole of `src/`.

**The defence-in-depth guards are backed by a measurement, not by taste.** One token in
`set_sym_flags` is what keeps three netlister sites safe; flipping it yields two sequential
segfaults. That flip is now the deterministic sabotage for the static rows.

Baseline to gate against, from `73ebbfa0`: `cases=97 blocks=96 counted_failures=0 skips=8`
(`results.1594312.log`, a fresh clone built from scratch at an 84-character path, ran solo,
throwaway home, `elapsed=589s`, `wc -l` 290).

⚠ **Gate in a clone at a SHORT path.** A clone under the session scratchpad reaches 173
characters and makes T1 report 11 failures that are not real — `test_op_annot` and
`test_annot_hier_0911` compare a status message the product deliberately elides past the status
bar's width. Full write-up in `CLAUDE.md` and
`doc/claude/issue_1607_batch/LEDGER.md`.

## Stage E — what the implementation added beyond the brief, and two Tcl traps worth keeping

**The decisive measurement, which is the one the brief asked for.** With `set_sym_flags`'s
normalisation flipped to `my_strdup` (so a NULL `type` survives into the netlisters), the five
back ends run **clean with the two defence-in-depth guards in place** (`ok=5/5`) and **segfault on
the very first back end without them** (`ok=0/5`, `rc=1`, `death=1`). That is what converts those
two guards from "house style" into "load-bearing", measured rather than argued.

**An extra row the crew added on its own judgement, and it was right to.** Row `S4` statically
asserts that *both* copies of the `draw.c` hide test guard `->type` and that *neither* guards
`->prop_ptr`. It exists because the behavioural row for that patch needs a display and self-skips
without one — which would have left the `draw.c` fix unfenced on the headless arm. Internal test
engineering, decided by the crew and stated, not queued.

**Why the static rows must strip comments — and this is a sharper version of the `V27` lesson.**
Every guard rows `S1`–`S4` assert is *quoted in prose in the source comment directly above it*
(the `netlist.c` comment literally contains `type && IS_LABEL_OR_PIN(type)`; the `actions.c`
comment contains both `my_strdup2` and `my_strdup`). Without the comment strip, **all four rows
would be satisfied by their own documentation.** The 1607 batch found a `#if 0` copy standing in
for live code; this batch found a *comment* standing in for it. Same failure, second mechanism.

**Two Tcl traps, both caught only because a control row existed.** Both are documented in the
suite file; recorded here because this project has hundreds of Tcl suites and both will recur:

1. **Tcl list parsing strips quotes.** `foreach t {… "bus_tap" …}` yields the element `bus_tap`,
   *without* the quotes, so token lists built that way silently stop matching quoted C string
   literals. The rows were **red on correct source** until every quote was written `\"`.
2. **Tcl ARE non-greediness is not local to the quantifier — it attaches to the whole branch.**
   `regexp "(?s)(?:^|\n)$name=<(.*?)>"` read **greedily** to the last `>` in the entire child
   transcript. Fixed with an explicit `([^>]*)`.

Both produced *wrong* results rather than errors, and neither would have been noticed without row
`C1` asserting a value the crew already knew. That is the argument for control rows in one line.

**A process note the crew reported against itself.** One sabotage restore used `cp -a`, which
preserved an older mtime, so `make` skipped the file and produced one bogus extra red. Caught
immediately and re-run; every figure in the matrix is from a correctly rebuilt binary. The general
form of this is already in `CLAUDE.md` under "No test harness builds" — a stale binary gives a
plausible result with wrong answers — and this is the same trap wearing a different hat.

## Resume point

**The batch is finished.** Five stages, all collected, committed as `c3a59de4` on `fluid-editing`
("guard the NULL symbol type — 2 real crashes, not 28, and the sweep was the defect"). Issue 1603
is stamped `claim=fixed fix=taken open=0`.

What landed: four guards (`scheduler.c` `sch_pinlist`, `draw.c` `draw_temp_symbol`, `netlist.c`
`set_lab_or_pin_inst_attr` and `instcheck`), the invariant comment at both places an editor would
look, one site deliberately left unguarded with a comment saying why, and
`tests/headless/test_typeless_symbol_1603.tcl` — 9 rows in `hcases`, `cases=` 97 → 98, `blocks=`
96 → 97, `skips=` 8 with the dev display up.

Nothing on this issue is outstanding. Carried forward, each recorded above with its evidence and
none of them a NULL-type defect:

1. **`vhdl_netlist.c` suspected `i`/`j` mix-up** — two lines read `xctx->sym[i]` inside a `j` loop
   whose neighbours read `xctx->sym[j]`; the analogous earlier loop uses `j` throughout. Read, not
   driven.
2. **`instcheck()` and the `sch_pinlist` branch index `xctx->sym[…]` with no `ptr >= 0` test** —
   the issue **0498** class. `ptr == -1` is a real state; `draw_temp_symbol()` opens by returning
   on it.
3. **`xschem show_unconnected_pins` blocks indefinitely** on a display when a referenced symbol
   file cannot be found — measured on the **pristine** binary at ~0 CPU after 150 s, so
   pre-existing and unrelated. Possibly a modal dialog a `--pipe` script cannot answer, i.e.
   possibly not a defect; the dialog was not identified.
4. **The non-netlister rows of the original sweep should be assumed to carry the same ~89%
   false-positive rate** if anyone revisits this family. The method — a `strcmp` regex with a
   two-line window — is what failed, not the individual rows.
