# 1600 — one file-scope `catch` swallows 83% of `test_ase_window`, and the verdict still reads like an ordinary red

**STAMP:** `v1 claim=partial tree=e92a2abf stamped=2026-09-22 fix=partial open=2 by=1600-core`

**Status: OPEN — filed 2026-09-21** by the ASE-L UX batch's fix round, which **named it
rather than fixed it** (`doc/claude/ase_l_ux_batch/receipts/verify.md`, the ⚠ under
*"S3 · FIXED"*, and its *"Left for the driver"* item 3). **Class** harness / verification
method: lost coverage that reads as a pass.
**PARTIALLY FIXED 2026-09-22:** `tests/headless/test_ase_core.tcl` — the one suite the
*"Still open"* item 2 said to do first — is converted; **15 named guards**, measured, see
*"What was done: `test_ase_core`"* below. `test_ase_window` and **33** other suites are
untouched.
**Related, read first:** **1487** (the T1 verdict could not show that a case skipped rows —
**FIXED** in `c84aee78`; its fix **cannot see this class**, see *"Why 1487's fix does not
reach this"* below), **1494** (`run_suites.sh` throws a crashed suite's text away),
**1497** (`full_audit.sh` drops per-row `skip:` lines), **0147** and **0891** (the
printed-but-uncounted precedents), **1456** (a suite that reports and then dies).

---

## The defect

`tests/headless/test_ase_window.tcl` wraps almost its whole body in a single column-0
`catch` whose handler names nothing:

```tcl
} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}
```

READ at `6a0d1126` (the committed state; the file is 3929 lines there): the opener is the
column-0 `if {[catch {` at `:395`, immediately below the scratch-library fixture, and the
arm above is at `:3670`–`:3673`. **Span 3275 lines, 83% of the file.** Inside it, in order:
the state-view fixture, `H1`–`H6`, `T1`, `P2`–`P4`, the `L1398` font/theme section, the `W`
window section, and the `R` reachability section.

So **any** raise anywhere in that body — a missing command, a typo in a proc name, a fixture
the environment cannot build, a widget path that does not exist — unwinds straight to
`:3670`, skips every row between the raise and that arm, prints one line that does not say
where it came from, counts **one** failure, and lets the file run on to its verdict.

Counted at `6a0d1126`, by `check`/`check_true` call site:

| region | call sites |
|---|---|
| the whole file | **289** |
| inside the unnamed catch (`:395`–`:3670`) | **277** |
| …of which the nested, **named** `R`-block catch (`:3466`–`:3665`, `UNEXPECTED ERROR (R block)`) re-covers | 22 |
| **under the unnamed catch with no nested guard** | **255** |
| outside it entirely (the `D1398` block, which has its own named catch) | 11 |

This is **pre-existing and predates the batch that found it**: the unnamed handler arrives
with `5f94d6d6` (2026-07-20), the commit that created the suite.

## What it costs — MEASURED

All three measurements below were taken by the ASE-L UX batch (implementer and fix round)
on private Xvfb displays, against the batch's working tree at `6a0d1126`, where the suite
runs **333** checks. **Nothing was run to write this issue**; the numbers are read off
`receipts/impl.md` and `receipts/verify.md`.

| what was done to the tree | verdict the suite printed | what actually happened |
|---|---|---|
| **`ase::ui::results_from_disk` deleted** | **`RESULT: 3 FAILED (13 passed)`** | raises at **`H4`**, on the `ase::ui::close $key` that ends the H4 block (`close` → `results_refill` → the deleted proc). 16 reported outcomes out of 333 rows. |
| the same proc **stubbed to return `{}`** instead of deleted | `7 FAILED (326 passed)` (implementer) · `7 FAILED (329 passed)` (fix round, +3 new rows) | seven **named** rows: `RD1498a` `RD1498c2` `RD1498f2` `RD1498g2` `UX1498a` `UX1498a2` `UX1498c`. Nothing lost. |
| a fixture raise later in the file (an unknown state-view type), `RD1498` block **un-wrapped** | `2 FAILED (63 passed)` | the outer catch prints `UNEXPECTED ERROR: unknown view type: ngspice_rd1498X` — **no block name** — then `D1398` cascades on a `w1f_colscan` defined in a section that never ran |
| the same raise, `RD1498` block **wrapped** (the fix round's S3 fix) | `1 FAILED (318 passed)` | `UNEXPECTED ERROR (RD1498 block): …` — one line, named. `333 − 318 = 15`, exactly that block's own rows |

**The first row is the whole issue.** `3 FAILED (13 passed)` is a shape a reader has seen a
hundred times: a small, ordinary red. It is in fact a run in which **at least 317 of the
suite's 333 rows never executed**, and in which the three counted failures are very likely
the three block handlers rather than three failing assertions. Compare row two: *the same
proc, neutered rather than removed*, produces seven named rows and full coverage. **The
difference between a diagnosable failure and a silent 95% loss is whether the error is a
wrong answer or a raise** — and a raise is what a genuine missing symbol, renamed proc or
absent widget produces.

A fourth figure, from the same class, is recorded in the suite's own comment wall above the
`RD1498` catch and in `impl.md` §8: `RESULT: 8 FAILED (42 passed)`, for a suite that runs
333. Four different raise points, four plausible-looking verdicts, none of them stating the
denominator.

## Why the verdict cannot say so — READ

The verdict is printed from two counters and **no denominator**:

```tcl
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
```

Nothing in the file knows how many rows it *should* have run, so `13 passed` and
`330 passed` are typographically the same kind of fact. The completion banner
(`OVERALL: notok`) and the exit code are both correct — the run **is** a failure — but they
say only *that*, never *how much of the suite is missing from the answer*.

### Why 1487's fix does not reach this

Issue **1487** is the neighbouring defect: the T1 verdict could not show that a case had
skipped rows, because `summarize_all` dropped `skip:` lines. It was fixed in `c84aee78`,
and `tests/run_regression.tcl` now carries `skip:` lines into the verdict and reports
`skips=` in the `T1-RUN-END` trailer.

**That fix is blind here by construction.** A skipped row announces itself; a *swallowed*
section does not exist. The suite emits no `skip:` line for the 317 rows it never reached,
so the trailer would print `skips=0` — a positive statement that nothing was left unmeasured
— for a run that measured 5% of the case. 1487 made the verdict able to report a loss the
suite declares; this defect is a loss the suite cannot declare.

(`test_ase_window` is **not** in either of `run_regression.tcl`'s case lists today, so this
particular file's hole is not currently a T1 hole. Four suites that *are* T1 cases carry the
same shape — see the sweep below.)

## The shape a fix takes — and there are two idioms in the tree already

The fix round wrapped one block and proved the difference by A/B (the last two rows of the
measurement table): `if {[catch { … } rd_bigerr]}` with
`puts "UNEXPECTED ERROR (RD1498 block): $rd_bigerr"; incr fail`. A raise inside that block
now costs **that block's 15 rows and nothing else**, and the message says which block died.
The same file already used the idiom for `R`, `D1398` and `UX1498/UX1499`.

A **stronger** idiom is also already in this corpus, in 14 suites: the handler is not a
`puts` but a **named check row**, e.g.

```tcl
} ncerr]} { check {NC0 section NC ran to the end} "RAISED:$ncerr" {} }
```

That version counts, names the section, *and* appears in the log as a row — so a driver
grepping rows sees it, the check total moves by one, and the failure text carries the raise.
Files using it: `test_ase_campaign_1462`, `test_ase_campaign_gui_1464`, `test_ase_conv_gui_1460`,
`test_ase_converge_1459`, `test_ase_core`, `test_ase_effective_1442`, `test_ase_events_1465`,
`test_ase_meas_1443`, `test_ase_options_1437`, `test_ase_optsheet_1441`, `test_ase_predeck_1439`,
`test_ase_simcaps_0948`, `test_ase_trnoise_gui_1467`, `test_backannotate_digital`.

**`test_ase_core` is in that list and in the sweep below**, which is the sharpest single
fact here: its newer sections each carry a `XX0 section XX ran to the end` row, while its
original 5324-line body still sits under one unnamed `UNEXPECTED ERROR: $bigerr`. The
remedy was invented in this repo, applied forward, and never applied back.

## How widely the pattern occurs — MEASURED by reading, not by running

Swept across all **406** `tests/headless/test_*.tcl` in the working tree: **35** carry a
column-0 whole-body `catch` whose entire handler is the unnamed `UNEXPECTED ERROR: $bigerr`.
Largest by fraction of the file, and the four that are T1 cases:

| suite | catch span | file | % | T1 case? |
|---|---|---|---|---|
| `test_wave_sigbrowser` | 3173 | 3283 | 96% | no |
| `test_calc_skeleton` | 3406 | 3536 | 96% | no |
| `test_wave_modes` | 2157 | 2249 | 95% | no |
| `test_wave_viewer` | 2373 | 2545 | 93% | no |
| `test_wave_sigbrowser_2pane` | 802 | 857 | 93% | no |
| `test_ase_final` | 1348 | 1455 | 92% | no |
| `test_ase_dialogs` | 5699 | 6380 | 89% | **yes** |
| `test_ase_persist` | 992 | 1181 | 83% | **yes** |
| `test_ase_window` | 3450 | 4411 | 78% | no |
| ~~`test_ase_core`~~ | ~~5324~~ | ~~12131~~ | ~~43%~~ | **yes — CONVERTED 2026-09-22, 15 guards, largest span now 609** |
| `test_op_annot` | 257 | 16383 | 1% | **yes** |

(`test_ase_window`'s row is the working tree as the ASE-L UX batch leaves it; at `6a0d1126`
the same catch is 3275 of 3929 = 83%. `test_op_annot` is the one file largely converted
already — 20 named handlers and one small unnamed remnant.)

Re-derive with this awk program, run per file from `tests/headless`:

```awk
# pairs column-0 `if {[catch {` openers with column-0 `} <var>]} {` closers and
# reports the pairs whose handler text is the UNNAMED "UNEXPECTED ERROR: $..."
{ lines[FNR]=$0; nline=FNR }
/^[ \t]*if \{\[catch \{[ \t]*$/ { stk[++top]=FNR }
/^\}[ \t]*[A-Za-z_][A-Za-z0-9_]*\]\} \{/ { if (top>0) { pairs[++np]=FNR "|" stk[top--] } }
END {
  for (i=1;i<=np;i++) {
    split(pairs[i], a, "|"); c=a[1]+0; o=a[2]+0
    h = lines[c] " " lines[c+1] " " lines[c+2]
    if (h ~ /UNEXPECTED ERROR: \$/ && h !~ /UNEXPECTED ERROR \(/)
      printf "%-40s open=%-6d close=%-6d span=%-6d filelen=%-6d\n", FILENAME, o, c, c-o, nline
  }
}
```

⚠ **What that sweep can and cannot see.** It is textual. It finds only the literal shape
(column-0 opener, column-0 closer, unnamed `UNEXPECTED ERROR: $…` within two lines of the
arm), so **35 is exact for that spelling and a lower bound for the defect** — an indented
whole-body catch, a handler worded differently, or a `catch` whose arm is on the same line
with other text is invisible to it. Two files were found by the same scan with the handler
on the closer line itself (`test_calc_widgets` 89%, `test_del_negative_arg` 77%) and are
included in the 35.

## Why this was named and not fixed

`test_ase_window`'s body is one 3275-line lexical run at file scope. Cutting it into
per-section catches is **mechanically safe for variables** — `catch` evaluates its script in
the caller's scope, so `$key`, `$scratch`, `$rundir` and the mid-body `proc`s stay exactly
where they are — but that is the easy half, and it is not the half that makes this a
restructure:

1. **Every cut needs a per-block judgement about what stays outside it.** The fix round's
   own S3 wrap had to leave two `proc` definitions outside the guard, because a *later*
   block calls `rd1498_raw` and a catch around the definitions would have converted one dead
   block into two. That judgement has to be made for each of the seven-or-so sections here,
   by someone who knows which later section depends on what.
2. **Guarding changes what a survivor runs against.** Today a raise in `W` ends the run;
   guarded, the sections after `W` proceed against a half-built window fixture. The `D1398`
   cascade in the measurement table is that outcome observed once already: a section that
   survived the guard failed anyway, for a reason that had nothing to do with its own
   subject. Each block therefore needs a decision — skip its dependents with a `skip: <row>
   -- <why>` line (the D10 contract, which `run_regression.tcl` now carries into the verdict
   since 1487's fix) or let them fail loudly.
3. **A guard is worth nothing unguarded-by-a-sabotage.** The S3 wrap is credible because it
   was proved A/B with an identical forced raise. Seven blocks means seven red-first proofs.

That is a design pass over a 4000-line suite with a sabotage matrix behind it — a task with
its own receipt — not a fix-round edit, which is precisely why the fix round wrote it down
instead of attempting it at the end of a batch.

## What is inferred here, and is not measured

* **The composition of the `3 FAILED`.** The receipts record the totals only. Reading the
  file, the three most likely contributors are the unnamed outer handler, the `D1398` block
  handler (its `w1f_colscan` is defined inside the skipped body) and the `UX1498/UX1499`
  block handler (its rows call the deleted proc). Nobody has recorded the three lines.
* **“At least 317 rows never ran.”** Arithmetic on two measured numbers: 333 rows in a full
  run, 16 reported outcomes in the sabotage run. `verify.md` states the same fact as
  *"13 checks of 333"*, counting only the passes. Either way the order of magnitude is the
  claim, not the last digit.
* **That the other 34 suites lose comparable coverage.** Not measured. Only the span of each
  catch was measured; what fraction of each suite's *rows* sit inside it was measured for
  `test_ase_window` alone.
* **Nothing in this file was produced by running anything.** No suite, no binary, no T1.
  (That is true of the sections above it. Every figure under *"What was done"* below came
  from a run — of the suite, or of T1 — and says which.)

---

## What was done: `test_ase_core` — MEASURED, 2026-09-22

`tests/headless/test_ase_core.tcl`'s one unnamed 5324-line `catch` is **gone**, cut into
**15** guards whose handlers are the named-check-row idiom this file already used for
`HN`, `RS`, `PM`, `MP`, `CK`, `WD` and `MT`. The file is 12131 → 12331 lines. **The biggest
span a single raise can now swallow is 609 lines, down from 5324 — 8.7×.**

Measured on the arm T1 uses for `hcases` (`--nogui --pipe -q --nolog`), binary built at
`e92a2abf`, dev display `:99` up. **The suite runs 675 checks and is ALL PASS on both arms
before and after** — the conversion changes nothing in green, which is the point: `catch`
evaluates its script in the caller's scope, so every variable and `proc` stays where it was.

### The guards, and what each one costs when it dies

Each row was measured by forcing `error "ZZ1600 …"` at the **head** of that guard and
counting `^ok:`/`^FAIL:` lines in the whole run. `rows` is the section's own row count,
recovered as `675 − total + 1` (the +1 is the guard's own failure row, which only exists in
the red run).

| guard | covers | span | rows | total after a raise at its head | extra named failures |
|---|---|---|---|---|---|
| `SD` | `R1`–`R4`, `C2`–`C4`, `B1`, `D1`–`D8` | 699–1308 | 76 | 600 | `C4`, `C5` (the D1 golden) |
| `OC` | `C0`–`C13`, `D6` op-cards | 1315–1859 | 51 | 625 | — |
| `PV` | `P1`, `F` | 1866–1930 | 23 | 653 | — |
| `NL` | `N1`, `N2` | 1946–1998 | 9 | 667 | 12 `BN` rows |
| `BN` | `BN` | 2005–2424 | 40 | 636 | — |
| `LG` | `0618`, `E1`–`E4b` | 2440–2654 | 19 | 657 | — |
| `RG` | `RG`, `SW` | 2693–3164 | 26 | 650 | — |
| `NT` | `NT1`–`NT21` | 3204–3734 | 22 | 654 | — |
| `ND` | `NT22`–`NT29`, `NTD1`–`NTD12` | 3741–4317 | 20 | 656 | — |
| `RT` | `RT` | 4324–4711 | 13 | 663 | — |
| `DX` | `DX` | 4718–5063 | 8 | 668 | — |
| `AD` | `AD` | 5070–5204 | 7 | 669 | — |
| `AG` | `AG` | 5223–5580 | 18 | 658 | — |
| `EM` | `EM` | 5599–5786 | 9 | 667 | — |
| `EK` | `EK`, `NS`, `SI` | 5793–6171 | 15 | 661 | — |

**356 of the suite's 675 rows — 53% — were inside the unnamed catch.** In all fifteen runs
the named guard row appeared carrying the raise text, the `RESULT:` line printed, and the
`OVERALL:` banner printed. The pristine file was restored and proved by `md5sum` after each.

### The two cascades, and what they cost before they were fixed

Both were found by the sabotage, not by reading, and both are **pre-existing couplings** the
one big catch had merely hidden:

* **`$render` and `$netlist_text`** (set in `SD`) are read by rows `VB1`–`VB3`, which sit in
  the region **below** the old arm and have never been guarded by anything. With them inside
  `SD`'s guard a raise at the head of `SD` aborted the interpreter at `can't read "render":
  no such variable` — no `RESULT:`, no `OVERALL:`. **On the file as it stood before this
  change the same raise produced NINE rows and no verdict at all.** Both are now hoisted
  above the `SD` guard.
* **`$expected_deck`** (D1's golden, built in `SD`) is compared against by `C4` and `C5` in
  `OC`. Unset, `OC` *raised* and lost all 51 of its rows; the cost of one dead section was
  two. It now gets an empty default above the `SD` guard, so those two rows **fail loudly on
  their own names** and `OC` keeps the other 49. Delta fell from −124 to −75.
* **`$rundir` and its directory** (`NL`). `$rundir` is read by `BN`, `LG` and `RG`; the
  directory is created by `N1`'s `ase::netlist`. Hoisting the `set` and adding a `file mkdir`
  above the guard took `NL`'s blast radius from **−46 rows** (`BN` raised on a missing
  `bn_stamp_a.txt` and lost 38 of its 40 rows) to **−8, its own rows and nothing else**:
  `BN` now runs its whole 40 and 12 of them fail **loudly and by name** on a cold facts slot,
  which is exactly their subject.

### Cascade policy, per section

**Fail loudly everywhere; no `skip:` line was added.** The two dependencies that survive a
guard — `OC`'s `C4`/`C5` on the D1 golden, and `BN`'s twelve warm-slot rows on `NL` — are
rows whose *own subject* is the thing that went missing, so their ordinary failure text
(`{cold {}}` vs `{warm aselib/nfet_clean/schematic}`) says more than a `skip:` would. A
`skip:` is right when a row *cannot be evaluated*; these can be, and the answer is no.

### What this does NOT fix in this file

* **The region below the `EK` guard is still only partly guarded.** `AC`, `VB`, `PB`, `TF`,
  `SE`, `LB`, `ISO`, `CP`, `PZ`, `GR` and others sit between the guards, outside all of them;
  the seven pre-existing guards (`HN`, `RS`, `PM`, `MP`, `CK`, `WD`, `MT`) cover the rest. A
  raise in an unguarded stretch still aborts the interpreter. Converting that region is the
  same task again and was not in this one's scope.
* **The hoisted `set netlist_text`/`set render` are themselves unguarded**, by construction —
  that is the price of keeping them alive for the unguarded `VB` rows.
* **`RESULT:` still has no denominator.** This change makes a swallowed section *named*; it
  does not make the verdict state how many rows it should have run. That is the `skips=`
  half of 1487's problem and is untouched.

---

## Still open

1. **`test_ase_window.tcl`** — the restructure described above.
2. **The other 33 suites**, three of them T1 cases (`test_ase_dialogs` 89%,
   `test_ase_persist` 83%, `test_op_annot` 1%). `test_ase_core` was the fourth and is
   **done** — see *"What was done"* above. `test_ase_dialogs` is the one to do next: it is a
   T1 case and its unnamed body is 5699 lines, the largest left in the sweep.

### What the `test_ase_core` pass learned, for whoever does the next one

* **Sabotage at the HEAD of each guard, not the middle.** A head raise is what exposes the
  cross-section couplings; a middle one finds only the rows below it.
* **Count rows as `^ok:` plus `^FAIL:` in the whole run, not from `RESULT:`.** A cascade that
  aborts the interpreter prints neither, and a run with no `RESULT:` line is the finding.
* **`run_suites.sh` echoes only failing lines** (issue 1494), so diagnose a cascade through
  `tests/headless/gated_xschem.sh --pipe -q --nolog --nogui --script …` with the whole text
  captured. It arms `HOME` the same way.
* **A variable read *below* the old arm is the trap.** Scan for it mechanically: every
  column-0 `set` inside the body, grepped for `$name` in the region after it. In
  `test_ase_core` that scan returned five names, of which three (`d`, `st`, `f`) were loop
  locals and two (`render`, `netlist_text`) were real.
* **Give an unset dependency an empty default rather than a `skip:`** where the dependent row
  can still be evaluated — it converts a section-killing raise into one named failing row.
