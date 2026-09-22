# 1600 — one file-scope `catch` swallows 83% of `test_ase_window`, and the verdict still reads like an ordinary red

**STAMP:** `v1 claim=partial tree=81386d97 stamped=2026-09-22 fix=partial open=4 by=driver-reconcile`

**Status: OPEN — filed 2026-09-21** by the ASE-L UX batch's fix round, which **named it
rather than fixed it** (`doc/claude/ase_l_ux_batch/receipts/verify.md`, the ⚠ under
*"S3 · FIXED"*, and its *"Left for the driver"* item 3). **Class** harness / verification
method: lost coverage that reads as a pass.
**PARTIALLY FIXED 2026-09-22 — ALL FOUR T1 CASES IN THE SWEEP ARE CONVERTED:**
`tests/headless/test_ase_core.tcl` (**15** named guards, span 5324 → 609),
`tests/headless/test_ase_dialogs.tcl` (**20**, span 5699 → 659),
`tests/headless/test_ase_persist.tcl` (**27**, span 992 → 104) and
`tests/headless/test_op_annot.tcl` (**22**, its last 257-line remnant named), each measured
with a per-guard head-raise sabotage; see the four *"What was done"* sections below.
**No T1 case now carries an unnamed whole-body `catch`**, and the corpus sweep reports
**31** files, from 35. What is left is `test_ase_window` (item 1) and 30 other suites,
**all non-T1** — plus item 3, which this sweep cannot see and which is now measured on
three files.
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
| ~~`test_ase_dialogs`~~ | ~~5699~~ | ~~6380~~ | ~~89%~~ | **yes — CONVERTED 2026-09-22, 20 guards, largest span now 659** |
| ~~`test_ase_persist`~~ | ~~992~~ | ~~1181~~ | ~~83%~~ | **yes — CONVERTED 2026-09-22, 27 guards, largest span now 104** |
| `test_ase_window` | 3450 | 4411 | 78% | no |
| ~~`test_ase_core`~~ | ~~5324~~ | ~~12131~~ | ~~43%~~ | **yes — CONVERTED 2026-09-22, 15 guards, largest span now 609** |
| ~~`test_op_annot`~~ | ~~257~~ | 16383 | ~~1%~~ | **yes** | **CONVERTED 2026-09-22**, 22 guards, 496 of 496 rows inside one |

(`test_ase_window`'s row is the working tree as the ASE-L UX batch leaves it; at `6a0d1126`
the same catch is 3275 of 3929 = 83%. `test_op_annot` was the one file largely converted
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

## What was done: `test_ase_dialogs` — MEASURED, 2026-09-22

`tests/headless/test_ase_dialogs.tcl`'s one unnamed **5699-line** `catch` — the largest
span left in the sweep, 89% of the file — is **gone**, cut into **20** guards carrying the
same named-check-row idiom the `test_ase_core` pass used. The file is 6380 → 6659 lines.
**The biggest span a single raise can now swallow is 659 lines, down from 5699 — 8.7×**,
and **all 388 of the file's `check`/`check_true` call sites sit inside a guard: zero are
outside one** (the hole *"Still open"* item 3 names, which cost `test_ase_core` 319 rows,
does not exist here — measured, not assumed).

⚠ **THIS FILE'S TWO ARMS MEASURE DIFFERENT THINGS.** `run_regression.tcl` runs it in
`hcases`, i.e. `--nogui`, where the `::has_x` gate skips everything below `H4d`: **37
checks headless, 389 on the display arm**. The conversion is row-for-row identical on both
arms before and after — the `ok:`/`FAIL:` name lists `diff` clean — so `37 ALL PASS`
headless is unchanged, and the display arm's four failures (`G2sens`, `GG3`, `GG9`,
`GN1b`, all capability-detection rows that answer to what the home can reach) are
pre-existing and unmoved.

### The guards, and what each one costs when it dies

Each row was measured by forcing `error "ZZ1600 <CODE> head raise"` at the **HEAD** of that
guard on the **display arm** and counting `^ok:` plus `^FAIL:` over the whole run — never
from `RESULT:`, which a cascade that aborts the interpreter never prints. Green baseline is
**389**. The pristine converted file was restored and proved by `md5sum` after every entry
(`6e22bc85d69193b09959568154122914`, twenty times).

| guard | covers | span | total rows after a head raise | delta | named guard rows that fired |
|---|---|---|---|---|---|
| `FX` | the state-view fixture | 31 | 42 | -347 | `FX0` `HD0` `GA0` `GT0` `GQ0` `GS0` `GV0` `GL0` `GE0` `GG0` `GN0` `GW0` `GR0` `GO0` `GH0` `NX0` `MS0` `SA0` `SB0` |
| `HD` | `H1`-`H4d` | 267 | 353 | -36 | `HD0` |
| `GA` | `G1`, `G2`, `G2b`, `G2c`, `G2h` | 230 | 169 | -220 | `GA0` `GT0` `GQ0` `GS0` `GV0` `GL0` `GE0` `GD0` |
| `GT` | `G2tf`, `G2pz`, `G2a2`, `G2sens` | 431 | 369 | -20 | `GT0` |
| `GQ` | `G2i`-`G2k`, `G2e`, `G2e2`, `G2g`, `G2d`, `G2dc`, `G2f` | 321 | 370 | -19 | `GQ0` |
| `GS` | `G3`-`G6` | 154 | 357 | -32 | `GS0` |
| `GV` | `G7`, `G8`, `G8b`, `G8c` | 202 | 355 | -34 | `GV0` |
| `GL` | `G9`-`G9d`, `G10`, `G11` | 144 | 367 | -22 | `GL0` |
| `GE` | `GE1`-`GE16` | 455 | 319 | -70 | `GE0` |
| `GD` | `G13`, `G12` | 44 | 387 | -2 | `GD0` |
| `GG` | `GG` | 153 | 364 | -25 | `GG0` `GN0` |
| `GN` | `GN` | 288 | 375 | -14 | `GN0` |
| `GW` | `G14` | 178 | 381 | -8 | `GW0` |
| `GR` | `GR5` | 278 | 369 | -20 | `GR0` `GO0` |
| `GO` | `GR6` | 343 | 381 | -8 | `GO0` |
| `GH` | `GH` | 466 | 373 | -16 | `GH0` `NX0` |
| `NX` | `NX` | 214 | 384 | -5 | `NX0` |
| `MS` | `MS` | 659 | 372 | -17 | `MS0` |
| `SA` | `SP1`-`SP6b` | 225 | 382 | -7 | `SA0` |
| `SB` | `SP7`-`SP14` | 511 | 376 | -13 | `SB0` |

`delta` is the whole-run row count minus the green 389, so it already **nets off the guard
rows the red run adds** — a guard that costs exactly its own `n` rows shows `-(n-1)`. `HD`
−36 is its 37 rows minus its one guard row; `GD` −2 is its three minus one. Spans are
measured on the converted file, opener line to closer line.

### The A/B, which is the whole issue in two runs

The **same** raise, on the **same** arm, at the **same** place, once on the file as it
stood and once on the converted file:

| raise | file as it stood | converted |
|---|---|---|
| at the head of the fixture (pristine line 649, the old `if {[catch {` itself) | `UNEXPECTED ERROR: ZZ1600 FX head raise` · `RESULT: 1 FAILED (0 passed)` · **0 rows** | 19 of the 20 guard rows fire carrying `RAISED:`, plus 18 loud named failures on their own subjects · `RESULT: 37 FAILED (5 passed)` · **42 rows** |
| at the head of section `SP7` (pristine line 5832) | `UNEXPECTED ERROR: …` · **`RESULT: 5 FAILED (371 passed)`** · `OVERALL: notok` · **four `FAIL:` lines in the log** | **`RESULT: 5 FAILED (371 passed)`** · `OVERALL: notok` · **five `FAIL:` lines**, the fifth `FAIL: SB0 sections SP7-SP14 ran to the end -> {RAISED:ZZ1600 SB head raise}` |

**The second row is the sharper one.** The two verdicts are *byte-identical* — same
`RESULT:`, same `OVERALL:` — and the only difference is in the log: the unnamed handler
increments `fail` without printing a row, so the pristine run counts **five** failures and
prints **four**, and the fifth is nameless. Fourteen rows never ran and nothing anywhere
says so. Guarded, the count and the rows agree and the missing section has a name.
(That arithmetic — `RESULT:` saying 5 while the log holds 4 — is also why the row count
here is taken as `^ok:` plus `^FAIL:` over the whole run and never from `RESULT:`.)

### The five cascades, and what they say

Fifteen of the twenty guards cost **their own rows and nothing else**. Five do not, and all
five are **pre-existing couplings the one big catch had merely hidden**; the sabotage is
what found every one of them:

* **`FX`, the fixture, is total — and now NAMED nineteen times over.** 42 of 389 rows
  survive and 19 guard rows fire. Every section opens the state view the fixture seeds, so
  no hoist can rescue them; what the guards buy is that the log says so nineteen times
  instead of once, anonymously. (`GD` is the one survivor: `G13`/`G12` ask the simulation
  configuration dialog a question that needs no session.)
* **`GA` owns `$top`, and seven later sections read it** — `GT`, `GQ`, `GS`, `GV`, `GL`,
  `GE`, `GD`. `G1` is where the session window is opened and `$top`/`$atv` are set, and
  none of those sections re-opens one. A head raise there fires **eight** guard rows and
  leaves 169 rows. Hoisting `$top` would not help: a window that was never opened is not a
  value any hoist can supply. The eight further failures it produces (`GN5`–`GN9`, `G14f`,
  `SP6`, `SP6b`) are loud, named, and on their own subjects — they are the rows that need a
  netlist the dead sections would have made.
* **`GG` → `GN` via `$gw` and `$top`** (−25 rather than −12): the precondition-banner rows
  read the Choose Analyses window the type-grid section built.
* **`GR` → `GO` via `$R5FIX`** (−20 rather than −13): `GR6` restores the session snapshot
  `GR5` took, three times, at its own head. An empty default would be worse than the raise —
  `ase::session_update $key {}` would silently install an empty bench — so this one is left
  to fail by name.
* **`GH` → `NX` via `$GHFIX`** (−16 rather than −18 + 0): `NX` keeps **all six** of its own
  rows and `NX0` fires on its *teardown*, which puts `GH`'s bench back. That is the shape a
  guard is supposed to produce: the section ran, the section is named, and the reader can
  see it was the cleanup.

### The hoists

Three, found by the mechanical scan the `test_ase_core` pass prescribed — every `set` in a
guard's span grepped for `$name` below it, with proc bodies excluded, and every `proc`
defined in the body grepped for its name across the whole file:

* **`$key`** — read at 662 sites in every section and by the H teardown. It used to be set
  in the MIDDLE of the fixture, below `library_new_view` and `xschem cellview_path`, the two
  calls that can actually fail. `ase::session_key` is a pure string join, so it is now
  computed above the `FX` guard where it cannot raise, and a fixture that fails to build
  reddens `FX0` while the sections below fail on their own subjects.
* **`r5_open`** — defined in `GR5`, called by **section `GR6`** at nine of its own row
  sites. Inside `GR`'s guard, a raise anywhere in `GR5` would take the definition with it
  and `GR6` would die on `invalid command name "r5_open"`: the "one dead section becomes
  two" case, verbatim.
* **the five `sp_*` helpers and `$SPROW`/`$SPBENCH`** — section `SP` is split into `SA`
  (SP1–SP6b) and `SB` (SP7–SP14), and `sp_open_chana`, `sp_type` and `sp_bench` are called
  from `SB` seventeen times. Nothing in the hoisted stretch touches a widget or the session:
  four of the procs are pure readers, `sp_bench` is a definition, and the two `set`s are
  literals. The first call that CAN raise (`sp_bench $key $SPBENCH`) is the first line
  inside `SA`.

**No code moved except the one `set key` line.** The other two hoists are insertions only:
the guard simply opens *below* the definition it used to swallow.

### Three handlers put a renamed global proc back

`GN10`, `G14` and `NX5` each `rename` a real proc aside, install a stub, and rename it back.
A raise between the two renames would leave the stub installed for every section below — and
`GN10`'s stub **raises on call**, so one dead section would have become all of them. Those
three handlers restore before they report, each guarded by `[info commands <saved>] ne {}`,
because an unconditional `rename ase::netlist {}` would DELETE the real proc on any other
raise in that section. This was found by reading, not by the sabotage: a head raise fires
before the rename, so it cannot expose it.

### Cascade policy, per section

**Fail loudly everywhere; no `skip:` line was added**, for the reason the `test_ase_core`
pass gave. Every surviving dependent here is a row whose *own subject* is the thing that
went missing — `GN5`'s "the run has not started", `SP6`'s "a bench nobody has netlisted" —
so its ordinary failure text says strictly more than a `skip:` would. A `skip:` is right
when a row cannot be evaluated; these can be, and the answer is no.

### What this does NOT fix in this file

* **`RESULT:` still has no denominator.** The check totals are **unchanged** — 37 headless
  and 389 display, before and after, with twenty guards added — because the idiom puts the
  `check` inside the handler and a green run therefore emits none of them. That is item 4
  below, deliberately not done here.
* **The stale bullet in the file's own floor paragraph.** It says `run_regression.tcl` runs
  this file *"on **NEITHER** arm — measured, it is in neither `cases` nor `dcases`"*. It is
  in `hcases` today (`run_regression.tcl`, the `headless/test_ase_dialogs` entry), so the
  headless 37 ARE a T1 number and the display 389 are not. Left alone by this pass to keep
  the diff to the guards; it is a one-line correction for whoever is next in the file.

### What this pass adds to the list below, for `test_ase_persist`

* **The verdict can be BYTE-IDENTICAL and still be the defect.** The `SP7` A/B above is two
  runs printing the same `RESULT:` and the same `OVERALL:`, differing only in whether the
  log holds four `FAIL:` lines or five. An A/B that compares verdict lines therefore proves
  nothing; compare the `^FAIL:` lines.
* **`RESULT:` and the log disagree BY CONSTRUCTION under an unnamed handler.** It does
  `incr fail` without printing a row, so `RESULT: N FAILED` beside `N-1` `FAIL:` lines in
  the log IS the signature of a swallowed section — readable in any old transcript without
  re-running anything.
* **A teardown at the END of a section is a different fact from the section's rows.** `NX`
  kept all six of its rows and `NX0` fired on the fixture restore that follows them, so the
  guard row said *"the section ran and its cleanup broke"*, which a reader can tell apart
  from *"the section died"*.
* **Some couplings no hoist can dissolve, and saying so is part of the job.** `$top` is a
  live Tk window and `$R5FIX` is a session snapshot: an empty default for either would
  install a plausible wrong value instead of raising. Where the empty default would LIE,
  take the raise and name it.

---

## What was done: `test_ase_persist` — MEASURED, 2026-09-22

`tests/headless/test_ase_persist.tcl`'s one unnamed **992-line** `catch` — 83% of the file,
and the last T1 case in the sweep with a large unnamed body — is **gone**, cut into
**27** guards carrying the same named-check-row idiom the `test_ase_core` and
`test_ase_dialogs` passes used. The file is 1181 → 1401 lines. **The biggest span a single
raise can now swallow is 104 lines (section `R6`), down from 992 — 9.5×**, and **all 155 of
the file's `check`/`check_true` call sites sit inside a guard: zero are outside one**,
measured with a brace-depth scan, not assumed.

⚠ **THIS FILE'S TWO ARMS MEASURE DIFFERENT THINGS**, as `test_ase_dialogs`'s do.
`run_regression.tcl` runs it in `hcases`, i.e. `--nogui`, where the `::has_x` gate takes the
R5 branch and skips G1–G11b: **49 checks headless, 153 on the display arm**. The conversion
is **row-for-row identical on both arms before and after** — the `ok:`/`FAIL:` name lists
`diff` clean — so `49 ALL PASS` headless and `153 ALL PASS` on the display arm are unchanged,
which is the point: `catch` evaluates its script in the caller's scope, so every variable and
`proc` stays where it was. Binary built at `0aa50c3e`; dev display `:99` up; the display arm
reaches `ngspice`, so **no leg self-skipped in any run below** (`T-E legs: RAN`).

### The A/B, which is this issue in four runs

The **same** forced raise, on the **same** arm, at the **same** place, once on the file as it
stood and once on the converted file:

| raise | file as it stood | converted |
|---|---|---|
| head of the old body (the `if {[catch {` itself, pristine line 156) | `UNEXPECTED ERROR: …` · **`RESULT: 1 FAILED (2 passed)`** · **2 rows of 153** · **ZERO `FAIL:` lines in the log** | `RESULT: 12 FAILED (136 passed)` · **148 rows** · `FX0` `BK0` `RS0` `AP0` named, plus 8 loud named failures |
| head of section `G2` (pristine line 696) | `UNEXPECTED ERROR: …` · **`RESULT: 1 FAILED (49 passed)`** · 49 rows, nameless | `RESULT: 45 FAILED (94 passed)` · **139 rows** · `CA0` `CU0` `SW0` `RL0` named |
| **middle** of `R6`, between the six renames and their restore (pristine line 301) | `RESULT: 1 FAILED (16 passed)` · **16 rows** | `RESULT: 1 FAILED (138 passed)` · **139 rows** · `RR0` named, shims put back |
| **middle** of `G10`, between the `::ase::echo` rename and its restore (pristine line 1020) | `RESULT: 1 FAILED (130 passed)` · 130 rows | `RESULT: 1 FAILED (140 passed)` · 141 rows · `MX0` named |

**The first row is the whole issue in one line.** `RESULT: 1 FAILED (2 passed)` is a shape
nobody looks at twice, and it is a run that measured **2 of 153 rows**. It also shows the
signature `test_ase_dialogs` named: the unnamed handler does `incr fail` without printing a
row, so `RESULT:` claims **one** failure while the log holds **zero** `FAIL:` lines. That
arithmetic is readable in any old transcript of any of the 31 unconverted suites without
re-running anything.

### The guards, and what each one costs when it dies

Each row: `error "ZZ1600 <CODE> head raise"` forced at the **HEAD** of that guard, `^ok:`
plus `^FAIL:` counted over the whole run — never from `RESULT:`, which a cascade that aborts
the interpreter never prints. Green baseline **153** (display) / **49** (headless, `HL`
only). The pristine converted file was restored and proved by `md5sum` after every entry
(`9c6acf54d19c919484e7d8c53acc8b95`, **twenty-nine times** — the 27 head raises plus the two
middle raises below; the eight A/B and policy runs each restored their own source the same
way). **Every one of the 27 printed its named guard row carrying the raise text, a `RESULT:`
line and an `OVERALL:` banner.**

| guard | covers | span | total after a head raise | delta | named guard rows that fired |
|---|---|---|---|---|---|
| `SU` | registry isolation + the cell clone + `library.defs` | 22 | 65 | −88 | `SU0` `FX0` `CA0` `PC0` `SV0` `NR0` `CU0` `DP0` `SW0` `RL0` `BK0` `NA0` `MX0` `RS0` `AP0` |
| `FX` | the hermetic rundir shaping | 8 | 148 | −5 | `FX0` `BK0` `RS0` `AP0` |
| `SD` | `R1` | 41 | 152 | −1 | `SD0` |
| `VR` | `R2` | 24 | 150 | −3 | `VR0` |
| `OS` | `R3` | 17 | 149 | −4 | `OS0` |
| `SN` | `R4` | 9 | 151 | −2 | `SN0` |
| `RR` | `R6` | 104 | 139 | −14 | `RR0` |
| `SE` | `R7` | 71 | 144 | −9 | `SE0` |
| `ID` | `R8` | 80 | 149 | −4 | `ID0` |
| `MR` | the DISPLAY/ngspice precondition probe | 3 | 48 | −105 | `MR0` |
| `SS` | `G1` | 8 | 61 | −92 | `SS0` `CA0` `PC0` `SV0` `NR0` `CU0` `DP0` `SW0` `RL0` `BK0` `NA0` `MX0` `RS0` `AP0` |
| `CA` | `G2`, `G2p` | 51 | 139 | −14 | `CA0` `CU0` `SW0` `RL0` |
| `PC` | `G3` | 7 | 148 | −5 | `PC0` `CU0` `SW0` |
| `SV` | `G3s` | 21 | 149 | −4 | `SV0` |
| `NR` | `G4` | 31 | 108 | −45 | `NR0` `CU0` `SW0` `RL0` `BK0` `NA0` `RS0` `AP0` |
| `CU` | `G5` | 17 | 151 | −2 | `CU0` |
| `DP` | `G6` | 20 | 147 | −6 | `DP0` `SW0` |
| `SW` | `G7` | 41 | 115 | −38 | `SW0` `RL0` `NA0` `MX0` `RS0` `AP0` |
| `RL` | `G8` | 56 | 127 | −26 | `RL0` `NA0` |
| `BK` | the raw backup `G11` restores | 2 | 147 | −6 | `BK0` `RS0` `AP0` |
| `NA` | `G9`, `G9a`, `G9b` | 38 | 144 | −9 | `NA0` |
| `MX` | `G10` | 60 | 141 | −12 | `MX0` |
| `RS` | `G11` | 20 | 149 | −4 | `RS0` |
| `AP` | `G11b` | 28 | 150 | −3 | `AP0` |
| `HL` | `R5` (**headless arm**, green 49) | 8 | 48 | −1 | `HL0` |
| `TE` | the T-E reason row | 14 | 153 | 0 | `TE0` |
| `CL` | the scratch drop + `cleanup` row | 3 | 153 | 0 | `CL0` |

`delta` is the whole-run row count minus green, so it already **nets off the guard rows the
red run adds** — a guard that costs exactly its own `n` rows shows `−(n−1)`. `NA` −9 is
`G9`'s ten rows minus its one guard row; `TE` and `CL` are 0 because each owns one row and
adds one. Spans are opener line to closer line on the converted file.

### Seventeen of the twenty-seven fire their own guard row and no other

`SD` `VR` `OS` `SN` `RR` `SE` `ID` `MR` `SV` `CU` `NA` `MX` `RS` `AP` `HL` `TE` `CL`. All of
them except `MR` also cost **exactly their own rows** — their delta is `−(n−1)` to the row.

The ten that fire more than one guard row (`SU` `FX` `SS` `CA` `PC` `NR` `DP` `SW` `RL` `BK`)
are all **pre-existing couplings the one big catch had merely hidden**, and the sabotage is
what found every one:

* **`SU` and `SS` are total, and now NAMED fifteen and fourteen times over.** `SU` builds the
  cloned library every section opens; `SS` (`G1`) opens the session window `$top` that `G2`
  through `G8` all drive. Neither can be rescued by a hoist — a library that was never copied
  and a Tk toplevel that was never mapped are not values any default can supply. What the
  guards buy is that the log says so fifteen times by name instead of once, anonymously.
* **`MR` −105 is the file's own skip branch, not the guard's doing.** `main_ready` raising
  leaves `$mainok` at its hoisted `0`, so the pre-existing `if {!$mainok}` branch takes the
  documented WSLg skip and G1–G11b never run. `MR0` is the only red, and it is the whole
  tell: the preconditions were never measured, which the old file could not say at all.
  Defaulting `$mainok` to `1` instead would drive eleven sections at a window nobody has
  confirmed is usable, so the loud guard row is the better trade.
* **`CA` (`G2`) −14 with 41 further loud failures.** `G2` builds the dc bench; `G5`, `G7` and
  `G8` all read what a dc run produced. Their rows *run* and fail on their own subjects.
* **`NR` (`G4`) −45.** The run itself: no raw, no viewer, no snapshot to save or reopen.
* **`SW` (`G7`) −38.** `G7` writes `ngspice_persist1`; `G9`, `G10`, `G11` and `G11b` all
  reopen it. The state file is a physical artifact, so no default substitutes for it.
* **`RL` (`G8`) −26, and this is the shape a guard is supposed to produce.** `G8`'s own 18
  rows plus `G9`'s 10, and **nothing else**: `G10`, `G11` and `G11b` all run to their ends
  and post thirteen loud named failures instead of vanishing. `NA0` fires because `G9` needs
  `$top2`, the relaunched toplevel.
* **`BK` −6 and `FX` −5** are artifact dependencies — a backup nobody took, a rundir that was
  never made hermetic — and both are named at the point of failure.
* **`DP` → `SW`** and **`PC` → `CU`/`SW`**: the snapshot rows read the graph the Direct-Plot
  and Plot-cell sections created.

### The hoists

Found by the mechanical scan the earlier passes prescribed: every `set` outside a proc body
in the old catch, grepped for `$name` in the region after it and bucketed by section, plus
every `proc` defined in the body grepped file-wide. **The scan returned 20 cross-section
names**, which split three ways: **five are false positives** — `d` is a proc local, and `f`,
`pre_esc`, `pst` and `w` are each re-`set` at every downstream read site; **five are live Tk
paths no hoist can supply** (`$top`, `$top2`, `$vtop`, `$vtop2`, `$vdrw`), whose cascades are
taken and named; and `$te_why` already sat above the GUI block. **The remaining nine are the
hoists and defaults below**, joined by two procs the proc-scan found:

* **`r7_lines` and `r7_bytes`** — defined in `R7`, **called by section `R8`** from
  `r8_analine`, `r8_trip`, `R8c` and `R8e`. Inside `R7`'s guard, a raise in any of `R7`'s ten
  rows would take the definitions with it and `R8` would die on
  `invalid command name "r7_lines"`: the "one dead section becomes two" case, verbatim. All
  four `r7_*` helpers now sit above the guard; none of them can raise.
* **`$key`, `$clonelib`, `$rundir`, `$schpath`, `$clonestate`** — read by every section and,
  for `$clonelib`, by `G7`–`G11b`. Pure `file join` / `file normalize`, and
  `ase::session_key` is a string join, so they are computed above the `SU` guard.
* **`$key2`, `$persistfile`, `$rawfile`, `$rawbak`** — set in `G7`/`G8`, read by `G9`, `G10`,
  `G11` and `G11b`. All four are pure joins. This hoist is what makes `RL`'s −26 a clean
  "`G8` plus `G9` and no more" instead of four dead sections.
* **`$cv`** (`set cv .drw`) — set in `G3s`, read by `G6`.
* **`$truth` defaulted to `0`** — `G5`'s engine ground truth, read by two `G8` rows **at the
  end of that section**, just above the raw backup. MEASURED: with the default, a head raise
  in `G5` costs **2 rows** and produces one loud, self-explaining failure
  (`G8 relaunched readout carries id=0 again`); without it `G8` would die at that line and
  take the backup, `G11` and `G11b` with it.
* **`$vd_live` defaulted to `{}`** — `G9`'s live viewer dict, read by `G10`, `G11` and
  `G11b`. MEASURED: the default makes `G9`'s blast radius **exactly its own ten rows** while
  all three dependents run to their ends and report ten loud named failures.
* **`$mainok` / `$have_ng` defaulted to `0`** — read by `if {!$mainok}` immediately below,
  which is a bare structural `if` outside every guard, and again by the T-E bookkeeping
  **below the whole `if`/`else`**, which is the trap the earlier passes name.
  MEASURED both ways with a head raise in `MR`: **with** the defaults, **48 rows**, `MR0`
  red, `RESULT:` and `OVERALL:` both printed; **without** them the `if` raises on
  `can't read "mainok": no such variable` with nothing left to catch it — **46 rows, NO
  `RESULT:`, NO `OVERALL:`, exit 0**. Two `set`s of a literal are the difference between a
  named red and a silent death, and this is the **third** place in this one file where that
  turned out to be true.

The GUI helper procs (`viewer_ready`, `send_key`, `send_return`, `tv_bbox`, `tv_cell_click`,
`real_esc`) were already above every G-section and are left there, marked.

**No code moved except `set cv .drw`, `set key2`, `set persistfile`, `set rawfile` and
`set rawbak`.** Every other hoist is an insertion; the guard simply opens *below* the
definition it used to swallow.

### Two handlers put a renamed global proc back — and this is the part a sabotage cannot find

`R6` renames **six** real procs aside (`ase::session_state`, `ase::last_rawfile`,
`ase::last_vcdfiles`, `ase::plot_sim_type`, `wviewer::restore`, `::ase::echo`) and installs
stubs; `G10` parks `::ase::echo` aside to capture the restore's sentence. A head raise fires
*before* the rename, so **the head-raise matrix above cannot see this at all** — it was found
by reading, exactly as `test_ase_dialogs` reported. Both handlers now restore before they
report, through `r6_unshim` / `g10_unshim`.

Both halves were then measured, and both are load-bearing:

| variant | raise | result |
|---|---|---|
| handler **without** the restore | middle of `R6` | **47 rows**, 16 failures, 15 guard rows — `ase::session_state` stayed stubbed and **every G-section died** |
| handler **with** the restore | middle of `R6` | **139 rows**, 1 failure (`RR0`) — identical to the head raise |
| restore made **unconditional** | **head** of `R6` | **15 rows, NO `RESULT:` LINE, NO `OVERALL:` BANNER, exit 0** — `rename ase::session_state {}` deleted the real proc and the handler then died inside itself |
| restore made **unconditional** | **head** of `G10` | **129 rows, no `RESULT:`, no `OVERALL:`, exit 0** — same mechanism on `::ase::echo` |

**The restore is worth 92 rows and the `[info commands <saved>] ne {}` in front of it is
worth the whole verdict.** The last two rows are the worst shape in this corpus: `--nogui
--pipe` exits 0 on an uncaught Tcl error, so only the banner rule catches them.

### Cascade policy, per section

**Fail loudly everywhere; no `skip:` line was added**, for the reason both earlier passes
gave. Every surviving dependent here is a row whose *own subject* is the thing that went
missing — `G10 sanity: the stored state NAMES the deleted result`, `G11 raw attached through
the rawfile seam` — so its ordinary failure text says strictly more than a `skip:` would.
Where a default would have **lied**, the raise is taken and named instead: `$top`, `$top2`
and `$vtop` are live Tk windows, and while `$persistfile` and `$rawbak` are hoisted paths,
the **files** they name are artifacts only `G7` and `BK` can produce.

### One deliberate behaviour change, and it is the T-E row

`set te_why RAN` is the file's claim that the acceptance legs reached their end, and the
`T-E` row at the foot compares it against preconditions measured independently. It is left
**inside `G11b`'s guard**, preserving the row's designed meaning, so a raise in `G11b` costs
`AP0` *and* the T-E row — two named reds for one cause, which is what that row's own comment
asks for. The guards **narrow** it: before, a raise anywhere from `G4` down stopped `te_why`
being set; now only damage that reaches `G11b` does. **Measured: seven of the 27 head raises
redden `T-E`** — `AP` itself, plus `SU` `SS` `FX` `NR` `SW` `BK`, every one of which also
fires `AP0`. The other ten in the G-legs (`CA` `PC` `SV` `CU` `DP` `RL` `NA` `MX` `RS`, and
`MR` through the skip branch) do **not**: `G11b` ran to its end and set `te_why RAN`, so the
T-E row stays green and the named guard rows carry the whole story.

### Two stale claims in the file's own comment wall, both corrected

Both said, in the present tense, that this suite is **not** a T1 case. It has been an
`hcases` entry in `tests/run_regression.tcl` since issue **1413**.

* The header's *"Runs via full_audit's DEFAULT arm"* named only `full_audit` as the file's
  home. It now states that T1 runs it `--nogui`, so **the 49 headless checks ARE a T1 number
  and the 153 display ones are not**, and keeps the `full_audit` sentence after it.
* The foot's banner paragraph ended *"`test_ase_simcaps_0948` and `test_ase_optier_0963`
  already emit both, which is exactly why THEY are in T1"* — read forward, that says this
  file still is not. The past-tense history is kept (it is the reason the `OVERALL:` line
  exists) with a dated correction under it.

This is the same class `test_ase_dialogs` reported at four sites — **wrong in the direction
that costs coverage**, because it invites a reader to discount a real T1 result. ✓ **That
file's own copy has since been fixed** (its header now reads *"`run_regression.tcl` RUNS THIS
FILE ON THE HEADLESS ARM ONLY — it is in `hcases`"*, with the superseded *"NEITHER arm"*
wording named and dated), so the class is now corrected in both converted suites. **Worth
checking in the next one**: it is the cheapest defect in this issue to find and the only one
that makes a reader mistrust a green T1.

The `G2p` comment's reference to *"the enclosing `catch ... bigerr`"* was also updated: the
catch is gone, and the row still earns its place, because the guards would name the section
(`CA0`) but not the widget path — and a `G2` death still costs 45 of 153 rows.

### What this does NOT fix in this file

* **`RESULT:` still has no denominator.** The check totals are **unchanged** — 49 headless
  and 153 display, before and after, with 27 guards added — because the idiom puts the
  `check` inside the handler and a green run therefore emits none of them. That is item 4
  below, deliberately not done here.
* **`source scratch.tcl` and `set scratch [test_scratch ase_persist]` remain unguarded**, by
  construction: they are the bootstrap that supplies `test_scratch_drop` and the watchdog,
  and `$scratch` is what the cleanup guard drops. Neither line holds a `check`, so the
  "zero call sites outside a guard" figure is unaffected, but a raise in either still aborts
  the interpreter.
* **`MR`'s −105 is a real hole that no guard closes.** A precondition probe that raises is
  indistinguishable, to the `if {!$mainok}` branch, from one that legitimately returned 0.
  `MR0` names it; the eleven skipped sections still emit nothing.

### What this pass adds to the list below, for whoever does the next one

* **Sabotage the RESTORE, not just the section.** The head-raise matrix proves a guard
  contains a raise; it says nothing about whether the handler leaves the interpreter in a
  usable state. Two more runs per shim-owning guard settle it: one with the restore removed
  (here, 139 rows → 47) and one with the restore made unconditional (139 rows → **15 rows
  and no verdict at all**). Both variants were built with `sed` from the converted file and
  `md5sum`-proved back afterwards.
* **An unconditional restore is worse than no restore**, and it fails in the shape this
  whole issue is about: the handler raises *inside itself*, so the run exits **0** with no
  `RESULT:` and no `OVERALL:`. `[info commands <saved>] ne {}` in front of every
  `rename … {}` is not defensive style, it is the difference between a named red and a
  silent death.
* **A pure `set` hoisted above a guard can convert a section-killing cascade into one
  self-explaining row.** `$truth` → `0` is the sharpest example here: the failure text the
  reader gets is literally `G8 relaunched readout carries id=0 again`, which names the
  default, the section that should have supplied it, and the row that wanted it.
* **Guard the SETUP and the CLEANUP, not only the old catch's span.** They sit outside every
  version of the sweep's pattern, they are exactly where a `file copy` or a `file delete`
  fails, and unguarded they abort the interpreter between the last row and the verdict.
  Two cheap guards (`SU`, `CL`) are what took this file to zero unguarded call sites.
* **Check whether the file lies about its own T1 status.** Two sites here said it was not a
  T1 case; `test_ase_dialogs` had four. The tell is any sentence naming `full_audit`,
  `hcases`, `dcases` or "in T1" — `/usr/bin/grep -n 'full_audit\|run_regression\|hcases'`
  the file and check each hit against `tests/run_regression.tcl`.
* **A guard row count is not a coverage number.** Report `check`/`check_true` sites outside
  every guard as a separate figure, by brace-depth scan. It is the one number the issue's
  awk sweep is structurally blind to.
* **THE WORST OUTCOME IN THIS FILE WAS NEVER THE BIG CATCH — it was "exit 0, no banner",
  and it turned up THREE times**, all in the guards' own machinery: an unconditional
  `r6_unshim`, an unconditional `g10_unshim`, and a missing `set mainok 0`. Each gives
  `rc=0`, no `RESULT:` line and no `OVERALL:` banner, which is the one shape only the banner
  rule catches and which a standalone run reports as silence. **So the last check on any
  conversion is not "did the guard fire" but "did the run still print its two verdict
  lines"** — count them in the sabotage harness, as a column, on every single run.

## What was done: `test_op_annot` — MEASURED, 2026-09-22

Measured on the arms T1 uses for this file — it is in **both** `hcases` (`--nogui`) and
`dcases` (the dev display `:99`) — with the binary built at `03ea42b4`.

`tests/headless/test_op_annot.tcl`'s one unnamed **257-line** `catch` — the last one
in a T1 case, and the smallest in the sweep at 1% of a 16383-line file — is **gone**.
It is now `UNEXPECTED ERROR (sections A-D): $aderr`, the file's own idiom, used
twenty times **below** it — the remnant was the file's FIRST guard and its last
unnamed one. The awk sweep run on the converted file returns **nothing**. The file is
16383 → 16425 lines: 44 lines added and 2 replaced, of which **7 are code** (the two
guard openers, the two arms) and 35 are comment.

**The headline is not the remnant.** It is the answer to *"Still open"* item 3, which
this file inverts: **496 `check`/`check_true`/`check_raises` call sites, and exactly
ONE sat outside every guard.** `test_ase_core` had 319 of 675 outside; `test_ase_dialogs`
had zero of 388; this file had **one of 496** — row `R1`, the D9b-cap restore wedged
in the 27-line gap between section `K`'s closer and section `R`'s opener. It is now
guarded too, so the file is at **496 of 496, 22 named guards, zero unnamed**.

### The remnant: what it was and why it is ONE guard, not two

| | |
|---|---|
| opener / closer | `:255` / `:512` at `03ea42b4`, span **257** |
| covers | `A1`-`A3`, `B1`-`B5`, the `X1` top.sch fixture, `C5`/`C6`/`D6`, the `X2` descend fixture, `B6`, `C1`-`C11`, `D1`-`D9` (incl. the `D8` shipped-symbol cross-check), and `C4` |
| call sites | **34** — of which `D8`/`D8b` appear twice, in the `if` and the `else` of the shipped-symbol regexp, so **32 run** |
| guard added | `} aderr]} { puts "UNEXPECTED ERROR (sections A-D): $aderr" ; incr fail }` |

**One guard, and the reason is the fixture chain — not brevity.** A, B, C(top),
B(cont), C, D and C4 read as seven headings and are one straight line: fill the
descriptor store → `xschem load top.sch` → `xschem descend` to sim_sch_path `x1.` →
measure → reload `leaf.sch` for the no-caching row. A cut anywhere inside would only
move rows from one guard into the next **without changing what a raise costs**,
because the rows *before* a raise have already printed and the rows *after* it have
lost the fixture whatever guards them. The tempting seam — split `A`+`B` (8 rows, no
schematic needed) from the fixture and `C`/`D` — buys nothing for exactly that reason:
`A1`-`B5` sit **above** the first `xschem load`, so a fixture raise never reaches them.

**Nothing to hoist, measured.** The mechanical scan this issue prescribes — every
column-0 `set`/`proc` in the span, grepped for its name past the closer — returns
`opa_probe_devproc`, `opa_upper_devproc`, `::opa_devproc_args`, `c10_before`,
`c10_rc`, `symf`, `symtext` and the `D8` locals, and **every one has zero readers
after the closer**. No renamed or stubbed global exists in the span either — no
`rename`, no stub install, no restore of a global proc, which is the trap
`test_ase_dialogs` hit three times and which no head-raise sabotage can reach.

### The A/B, which is this file's honest result: the conversion changes NOTHING

Same forced `error "ZZ1600 AD head raise"`, at the head of the same guard, headless arm:

| | file as it stood | converted |
|---|---|---|
| rows (`^ok:` + `^FAIL:`) | **453** | **453** |
| verdict | `RESULT: 1 FAILED (453 passed)` · `OVERALL: notok` · exit 1 | *byte-identical* |
| the one line that differs | `UNEXPECTED ERROR: ZZ1600 AD head raise` | `UNEXPECTED ERROR (sections A-D): ZZ1600 AD head raise` |

**485 − 453 = 32, exactly the section's own runtime rows and nothing else — no
cascade in either direction.** That is what a 1:1 conversion of a whole-body catch
into a named one is *supposed* to produce, and saying so is the result: the remnant
bought a **name**, not a smaller blast radius. The blast radius was already the
minimum, because the 20 guards below it were already doing the work.

### The one unguarded row, and why it is the worse defect of the two

`R1` (`check {R1 D9b the cap is back to its shipped default …}`) called
`op_annot::max_rows` **bare**, in the gap between the `K` and `R` guards. Same
method, same arm, a raise at that row:

| | unguarded (file as it stood) | guarded |
|---|---|---|
| rows | **119** of 485 | **484** |
| `RESULT:` | **none** | `RESULT: 1 FAILED (484 passed)` |
| `OVERALL:` | **none** | `OVERALL: notok` |
| `UNEXPECTED ERROR` | **none** | `UNEXPECTED ERROR (section R1): …` |
| exit code | **0** | 1 |

**A run that prints 119 green rows, no banner, no count, and exits zero.** T1 still
scores it as a death by the banner rule, so this was never a T1 hole; run standalone
it is silent, which is precisely what item 3 predicts and here it is measured on a
second file. One guard around one row converts it into a named, counted, exit-1 red.

### The hoist the sabotage found

`set ::op_annot_max_rows 6` is the restore the comment wall calls load-bearing for
`L`, `N`, `O`, `Q` and `T`. Wrapped **inside** the new `R1` guard, a head raise
skipped the restore and cost **three** rows instead of one — `R1` plus loud named
reds on `R2` and `R3`, both answering `{id gm gds vgs vth vds vdsat cgg ft
gm/id_long}` against an uncapped formatter (`RESULT: 3 FAILED (482 passed)`).
It is a literal assignment that cannot raise, so it is **hoisted above the guard**,
and the same raise then costs `R1` and nothing else. This is the `test_ase_core`
`$rundir` lesson arriving a third time: *the statement that cannot raise belongs
outside the guard that protects the statement that can.*

### What did NOT need fixing, against expectation

* **No stale T1-coverage claim.** `test_ase_dialogs` claimed at four sites that
  `run_regression.tcl` runs it on neither arm. This file is the opposite: it is in
  **both** of `run_regression.tcl`'s lists — the `"headless/test_op_annot"` entry in
  `hcases` and the same name in `dcases` — its comment
  wall says so, and **row `V57` asserts it structurally on six legs** — that the
  suite is still in the headless list, that it is also in a display list, that the
  list is driven by a loop, that the loop's launch line routes through
  `devdisplay.sh`, that the loop does not pass `--nogui`, and that
  `summarize_all`'s classifier surfaces `NODISPLAY`. Checked against
  `tests/run_regression.tcl`; nothing to correct. Every comment edit in this pass is
  at column 0 outside any proc body, and `info complete` on the whole file is 1.
* **The gaps hold no rows.** 4672 of 16425 lines sit outside every guard, but reading
  them they are comment wall, `proc` definitions, and `set` of literals and
  `file join $repo …` paths, none of which can raise. The only raise-capable calls in
  a gap are `file mkdir` (sections `W`, `X`, `NM`), `open`/`puts`/`close` fixture
  writes (`NM`), and `opa_source` — and `opa_source` **cannot raise by construction**:
  it returns `[list 1 $e]` from its own `catch`. Left alone.

### Check counts: unchanged, as the idiom requires

**485 headless / 492 display, before and after, `ALL PASS` on both**, with the remnant
named and one guard added — the idiom is failure-only, so a green run emits none of
them. The `ok:`/`FAIL:`/
`skip:` name lists `diff` **clean** on both arms. The five pre-existing headless
`skip:` lines (`M1/M2`, `O14/O36/O38`, `W23`, `W29`, `V53`) and the one display
`skip:` (`W23`) are untouched and unmoved.

⚠ **492 is the BARE display figure, not the T1 one.** `run_regression.tcl`'s `dcases`
loop gives its children a `--logdir` of their own (issue 1359), which satisfies `W23`'s
precondition, so the T1 display arm runs **493** with **zero** `skip:` lines while a
hand-run `gated_xschem.sh … --script` on the same display runs 492 with one. Both were
measured here; neither moved across the change. In the gate verdict the case reads
`RESULT: ALL PASS (485 checks)` headless with its five skips and
`RESULT: ALL PASS (493 checks)` on the display arm.

### The sweep's four T1 cases are now all converted

With this file, `test_ase_core`, `test_ase_dialogs` and `test_ase_persist`, **every
T1 case in the 35-file sweep carries named guards.** (This pass did not verify
`test_ase_persist` itself — that was a concurrent crew in another clone; its own
*"What was done"* section is the evidence for it.) What is left is `test_ase_window`
and the 30 remaining non-T1 suites — see *"Still open"*.

---

## Still open

1. **`test_ase_window.tcl`** — the restructure described above.
2. **The remaining 31 suites, and NOT ONE of them is a T1 case.** All four — `test_ase_core`,
   `test_ase_dialogs`, `test_ase_persist` and `test_op_annot` — were converted on
   2026-09-22; see the four *"What was done"* sections above.

   ⚠ **This item should now be read AFTER item 3, not before it.** Item 3 is a hole in a
   file that **is** a T1 case; everything here is a file that is not. Ranking by line count
   put this first when the sweep was the only measurement anyone had.

   **What is left is entirely non-T1, and the largest are all in the waveform and
   calculator families**: `test_ase_window` (3450 in the working tree — item 1),
   `test_calc_skeleton` (3406), `test_wave_sigbrowser` (3173), `test_wave_viewer` (2373),
   `test_wave_modes` (2157), `test_ase_final` (1348), `test_wave_sigbrowser_2pane` (802).
   **`test_calc_skeleton` or `test_wave_sigbrowser` is the one to do next** if the priority
   is size — but see item 3 first. ⚠ Being non-T1 makes these
   **worse**, not better: T1's banner rule at least scores a case that dies without a
   completion banner as a death, and a suite nobody runs under T1 has no such backstop —
   only whoever reads its `RESULT:` line.
3. **The UNGUARDED stretches, which this sweep cannot see at all and which are worse.**
   Added 2026-09-22 by the driver, from the `test_ase_core` crew's own "where I am unsure"
   list. In that file, **319 of the 675 rows sit outside every guard** — sections `AC`,
   `VB`, `PB`, `TF`, `SE`, `LB`, `ISO`, `CP`, `PZ`, `GR` and others, lying *between* the
   named guards with nothing around them. A raise in one of those stretches does not
   produce a misleading verdict; it produces **no verdict at all** — no `RESULT:` line and
   no completion banner. MEASURED on the unmodified original: a forced raise in section
   `SD` (whose `$render` the unguarded `VB` rows read) killed the interpreter after 9 rows.

   T1 still catches this, because the banner rule scores a case with no completion banner
   as a death. **Run standalone it is much quieter**, and it inverts the sweep's whole
   premise: the awk program looks for a `catch` that is too big, and cannot see a region
   with no `catch` at all. **The 35 (now 32 — `test_ase_core`, `test_ase_dialogs` and
   `test_ase_persist` are all rows in that table and all converted) is therefore not the
   population.** Converting
   a file's big catch into named guards does not finish that file, and nobody should read
   a zero-hit sweep as "this suite is done".

   **Two of the three converted files got to zero, and it is measurable per file.**
   `test_ase_dialogs` leaves 0 of 388 call sites outside a guard and `test_ase_persist`
   0 of 155; `test_ase_core` leaves **319 of 675**. The measurement is a brace-depth scan
   over the file (every `check`/`check_true` line, counted inside if the guard depth is
   non-zero) and takes a minute, so **a conversion receipt that does not state this number
   has not finished the job**. In `test_ase_persist` reaching zero cost two extra guards
   beyond the old catch's span — `SU` over the scratch clone and `CL` over the cleanup row
   — both of which aborted the interpreter when they raised. **Closing `test_ase_core`'s
   319 is the largest single piece of coverage left in this issue** and is worth more than
   any of the unconverted non-T1 suites in item 2, because that file **is** a T1 case.
4. **The verdict still has no denominator, and named guards do not give it one.** The
   idiom puts the guard row *inside* the handler, so a green run emits nothing: 675 checks
   before this pass, 675 after, with 15 guards added. That is correct and deliberate — all
   98 call sites in the corpus are failure-only, and inventing a second spelling for one
   file would be worse. But it means the fix bought **diagnosability, not coverage
   reporting**: a red run now names which section died, while a green run still cannot say
   how much of the suite the number represents.

   **A suite declaring its expected row count is the obvious shape and it is the wrong
   one.** The number is maintained by hand, so it drifts the first time anyone adds a row;
   worse, it is environment-dependent — the same suite legitimately runs 70 checks or 76
   depending on whether the home can reach the fork ngspice (`test_ase_converge_1459`), so
   a fixed expectation would be red on a correct run.

   **The guards themselves are already the denominator, and the `else` arm is all that is
   missing.** Give each guard
   ```tcl
   } ncerr]} { check {NC0 section NC ran to the end} "RAISED:$ncerr" {} } \
     else       { check {NC0 section NC ran to the end} {} {} }
   ```
   and a green run states *"22 sections declared, 22 ran to the end"* — self-maintaining,
   because the declaration IS the guard nobody can forget to add, and environment-proof,
   because a section that legitimately skips its rows still runs to its end. The suite
   count then carries a coverage fact instead of only a correctness one, and the T1 verdict
   could summarise it beside `skips=`.

   The cost is the reason it was not done here, and **it has grown with each conversion**:
   re-measured 2026-09-22 after the `test_ase_persist` pass, **160 call sites across 16
   suites** (`/usr/bin/grep -c 'ran to the end' tests/headless/test_*.tcl`; was 98 across 15
   when this item was written, before core's 15, dialogs' 20 and persist's 27 landed). Every
   one changes its suite's check total, which ripples into any row that asserts an exact
   count. Doing it in one file only would leave two spellings in a corpus whose own comment
   wall complains about exactly that. So it is a corpus-wide harness pass with its own
   receipt — not a rider on a per-suite conversion. ⚠ **It gets more expensive every time
   this issue is worked on**, which is an argument for doing it soon or for deciding
   explicitly not to.

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
