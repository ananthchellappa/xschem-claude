# 1652 — three suites print `RESULT: ALL PASS` and no `OVERALL: ok`, so registering any of them costs a counted failure

**STAMP:** `v1 claim=fixed tree=72185f2a stamped=2026-10-04 fix=taken open=2`

Status: **OPEN**, measured 2026-10-04 by the issue-1645/1650 hole-filing crew. Same defect family
as issues 0420, 0456, 0492, 0629, 0689, 1413, 1615, 1626 and 1645 — the one `tests/banner_rule.tcl`
records as *"filed FOUR times and waved through as furniture each time."*

Area: `tests/headless/test_del_negative_arg.tcl`, `tests/headless/test_raw_ascii_point_bounds.tcl`,
`tests/headless/test_wave_crossdb_trace.tcl`; `banner_complete` in `tests/banner_rule.tcl`.

## The defect

Each of the three ends with a `RESULT:` line and nothing else. `banner_complete` — the only Tcl
reader of a completion banner, and the one `tests/run_regression.tcl` sources — matches a whole-line
`OVERALL: ok` with an optional parenthesised trailer and, in that file's own words, *implements no
`RESULT: ALL PASS` spelling at all*. So a T1 entry for any of the three scores a `HARNESS: … did
not complete cleanly` failure **however many of its own checks pass**.

`tests/headless/run_suites.sh` and `full_audit.sh` carry their own looser EREs that **do** accept
the `RESULT:` spelling. So the two readers that can see these suites are the two that are not the
gate, and *"it passes standalone"* is not evidence that a suite can be registered.

## Measured, by sourcing the real rule rather than reading the regexp

Each suite was captured on both arms and scored with `banner_rule.tcl` itself:

```sh
. tests/headless/test_home.sh; test_home_arm
timeout 400 env -u DISPLAY ./src/xschem --pipe -q --nolog --nogui --script tests/headless/<s>.tcl > <s>.NOGUI.cap 2>&1
timeout 400 env DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog --script tests/headless/<s>.tcl > <s>.DISP.cap 2>&1
tclsh -c 'source tests/banner_rule.tcl; set f [open <cap>]; set b [read $f]
          puts "banner=[banner_complete $b] died=[banner_died $b] casefail=[regression_case_failed 0 $b]"'
```

All three answer `banner=0 died=0 casefail=1` on **both** arms, and all three answer
`RESULT: ALL PASS` in the same capture. That their epilogue is the cause rather than a symptom is
visible in the source:

```sh
/usr/bin/grep -nE 'puts .*(RESULT:|OVERALL)' tests/headless/test_del_negative_arg.tcl \
  tests/headless/test_raw_ascii_point_bounds.tcl tests/headless/test_wave_crossdb_trace.tcl
```

— nine lines, every one of them a `RESULT:`, not one `OVERALL:` among them.

## What is unfenced while this stands, which is the reason it is worth a number

Two of the three fence the **C engine** — and one of them fences the exact function issue **1650**
changed four commits ago:

* **`test_del_negative_arg`** fences the `DEL` arm of `plot_raw_custom_data()` in `src/save.c`
  (issue 0325): a negative delay made the forward search run to `last + 1`, reading one element
  past the sweep column and handing `last + 1` to `ravg_store()`, whose row is allocated with
  `last + 1` doubles. Confirmed under valgrind when it was filed.
* **`test_raw_ascii_point_bounds`** fences `read_raw_ascii_point()` (issue 0213): an ASCII rawfile
  lacking the blank separator between points made the reader write past
  `my_calloc(rawvars)`, `xschem raw read` reported **success**, and the process died in
  `free_rawfile()` with *"double free or corruption (out)"* — SIGABRT, **editor gone**. That is a
  crash the user experiences, and the suite's own header records that on an unfixed binary it does
  not merely fail, it takes the process down.
* **`test_wave_crossdb_trace`** holds row `XB10`, the only assertion anywhere that
  `wviewer::browser_plot_ids`' armed per-signal database list is consumed by the plot it belongs
  to. Issue **1651** is that hole; this file is its precondition.

Issue 1650 re-read every `p == first` guard in `plot_raw_custom_data()` and added row `DS12` to
derive that arm set from the function's own text. It did that work with the DEL arm's own
behavioural suite outside the gate.

## The fix, which is additive and has three precedents

One line per suite, inside the `$fail == 0` branch and **above** the existing `RESULT:` line,
because `summarize_all` publishes a case's **last** `RESULT:` line:

```tcl
puts "OVERALL: ok ($npass checks)"
```

That is the shape issue 1615 applied to `wvbs_finish`, issue 1413 applied to three `test_ase_*`
suites, and issue 1645 applied to two more. In 1645's measurement the omission cost **six** counted
failures — four `HARNESS:` lines plus rows `RB2` and `RB4` of `test_registered_banner_1626` — and
one additive `puts` per suite cleared all six with every check count unmoved.

⚠ **Emitting the sentinel and registering the suite are two changes, and the second one needs its
own derivation.** The arms measure different-sized things, so the shape is not a preference:
`test_raw_ascii_point_bounds` answers the **same** check count on both arms,
`test_del_negative_arg` answers a slightly larger one on the display arm, and
`test_wave_crossdb_trace` answers roughly twice as many — read them off the captures above rather
than from this sentence, which nothing re-checks. Derive the trailer delta by lifting
`summarize_all` out of `run_regression.tcl`'s own text and running its regexp arms over the real
captured output; do not predict `skips=`.

⚠ **`test_wave_crossdb_trace`'s `RESULT:` line is not the last line of its capture** — engine
chatter follows it. `banner_complete` is whole-line and position-independent so the sentinel is
unaffected, but a reader eyeballing `tail` will not see either banner.

## One rotted citation found inside one of these suites

`test_del_negative_arg`'s own header cites the DEL arm as `src/save.c:2381`. That line now reads a
`my_strcasecmp(type, "sp")` normalisation, and `plot_raw_custom_data()` is some two thousand lines
further on:

```sh
sed -n '2381p' src/save.c
/usr/bin/grep -n '^int plot_raw_custom_data' src/save.c
```

That is issue **1268**'s class (bare `save.c:<line>` citations rot; cite by symbol), not a new
defect, and it is noted here only because a crew registering this suite will read that header
first.

## 2026-10-04 — items 1 and 2 are done, and item 2 turned out to be a display-safety question

The sentinel landed as one additive `puts` per suite (`72185f2a`) and all three are registered and
gated. Item 2's answer was not decided by coverage: `test_del_negative_arg` gates its Tk bands on
the presence of `DISPLAY` in the environment rather than on `has_x`, and T1's `hcases` loop is the
one loop that does not route its child through `devdisplay.sh`, so an `hcases` entry there would
have mapped a real xschem window on whatever display the gate inherited. It went to `dcases` alone
on that measurement, and the follow-up commit fixed the gate expression, put `env -u DISPLAY` on the
driver's two un-routed arms, and added the `hcases` arm back.

⚠ **That follow-up also found a SECOND member of the class already registered and shipping in every
gate** — `test_ase_simcaps_0948`, whose `a_xe_child` launched a plain GUI xschem with no display gate
at all, which is why no audit of gate expressions could have found it. Both are repaired and the
population is now re-derived every gate by section `X` of `test_home_isolation`.

## Outstanding

1. `test_del_negative_arg`'s header citation `src/save.c:2381` is rotted and unrepaired
   (issue 1268).
2. ⚠ **`tests/headless/test_audit_classifier.tcl` is in neither list and is this issue's defect
   again, one suite over.** It prints lines ending in the word `FAIL` as part of its own check
   *names* — it classifies audit output, so its subject matter is failure text — and
   `summarize_all`'s counted shape is a line ENDING in `FAIL`. Registering it as it stands therefore
   scores several counted failures at `ALL PASS`, the same way the three suites above did, but by a
   different mechanism: not a missing sentinel but a row name that looks like a verdict. ⚠ It is
   also the file section K of which locks `run_suites.sh`'s and `full_audit.sh`'s EREs to
   `banner_rule.tcl`, so it is load-bearing for the harness and worth registering properly rather
   than leaving out. The fix shape is not the additive `puts` used above; it needs the row names
   changed so no counted shape appears in them, which is a behaviour-neutral rename whose delta must
   still be derived.
