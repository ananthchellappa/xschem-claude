# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The why behind these rules (measurements, incidents, dated corrections) is in
`doc/claude/claude_md_history.md`, this file verbatim at `a7d0876d` before it was
condensed; where the two differ, this file wins. A bare `D<n>` means a decision in
`doc/claude/outsider_fixes_batch/DECISIONS.md`; "row X" is a check in a suite.

## What this is

XSCHEM is a hierarchical schematic capture and netlisting EDA tool for VLSI/analog
custom design. It draws schematics and symbols and generates SPICE, Spectre, VHDL,
Verilog and tEDAx netlists. The drawing engine is plain C on top of Xlib primitives
(optionally Cairo for text/anti-aliasing); the GUI and the extension/scripting
language are Tcl/Tk.

## Build & run

```sh
./configure          # wraps scconfig; run from repo root. See ./configure --help
make                 # builds src/, xschem_library/, doc/, src/utile/
make install         # installs (honors DESTDIR=/tmp/pkg and PREFIX)
cd src && ./xschem   # run directly from the source tree, no install needed
```

- Build is **scconfig**-based (a self-contained ./configure system under `scconfig/`),
  not autotools. `configure` regenerates `Makefile.conf` and `config.h` from the
  `.in` templates — edit the `.in` files, not the generated ones (they carry a
  "DO NOT EDIT" header).
- Requires a C89 compiler, awk (mawk/gawk), Tcl/Tk 8.4–8.6, Xlib, Xpm, bison, flex.
  Optional: cairo, xcb, xrender.
- `src/Makefile` lists object files explicitly in `OBJ` — adding a new `.c` file
  means adding it to `OBJ` and adding an explicit compile rule (or regenerate from
  `Makefile.in`).
- A `CMakeLists.txt` exists as an alternative build but the Makefile path is canonical.
- **Editing `src/Makefile.in` obliges you to re-run `./configure`.** `src/Makefile`
  and `config.h` are generated and gitignored with no self-regeneration rule, so `make`
  never notices a stale `Makefile`. In-tree the miss is invisible (`XSCHEM_SHAREDIR`
  resolves to `src/`); installed, `xschem.tcl` sources a file `make install` never
  shipped and the binary segfaults at startup (exit 139; issues 0423, 0424). Verify with
  `/usr/bin/grep -c <newfile> src/Makefile`: expect 2, an install and an uninstall line.
- Concurrent `make` is unmeasured; nothing here declares it safe.

### Generated parsers (do not hand-edit the .c)
- `expandlabel.c`/`expandlabel.h` ← bison from `expandlabel.y` (bus/label expansion)
- `eval_expr.c` ← bison from `eval_expr.y`, prefix `kk` (expression evaluator)
- `parselabel.c` ← flex from `parselabel.l`

## Tests

Regression tests live in `tests/` and are driven by Tcl, comparing generated output
against golden files.

```sh
cd tests
tclsh run_regression.tcl        # T1: all cases (tcases, headless, display arm, xschemtest)
```

### Running T1 and single cases
- Each case is a `<name>.tcl` script that `run_regression.tcl` execs and scores into
  `results.log`. Run one case by sourcing it directly: `cd tests && tclsh open_close.tcl`.
- **Run T1 from `tests/`, never as `tclsh tests/run_regression.tcl` from the repo
  root**: that exits 1 without running (the nonzero exit says it never ran) and leaves
  the previous `results.log`, whose `T1-RUN-BEGIN` pid and start time give it away.
- **Your run's answer is `tests/results.<pid>.log`, not `results.log`.** Each run copies
  (never renames) its own onto `results.log` at the end, so that holds whichever run
  finished last. Case logs `<name>.<pid><suffix>` are published to `<name>.log` once
  scored, case output `<case>/results.<pid>` (scratch in `<case>/.work.<pid>`) to
  `<case>/results` at the end. A case run by hand keeps its plain log name
  (`open_close.log`): the pid tag rides in `T1_LOG_TAG`, and unset means the plain name.
- `tests/test_utility.tcl` resolves the binary as **`$XSCHEM` → in-tree `src/xschem` →
  `PATH`** (issue 0147) and runs it headless (`--pipe -q --script <file>`).
- **Always give the binary a path** (`./src/xschem`, `$XSCHEM`, `devdisplay.sh exec
  ./src/xschem`), never a bare `xschem`, which is not this tree. None was on PATH when
  checked (2026-09-17), so `command not found` in a transcript is not a broken harness;
  but one `make install` puts one back, and a build older than issue 0119 rewrites
  `~/.xschem/recent_files` despite `--pipe`/`--nogui`/`--norecent` (issue 0924). Test
  runs contain that with their throwaway HOME; a bare `xschem` at your prompt is not
  contained.
- **`create_save`, `open_close` and `netlisting` have no committed `gold/` baseline**:
  they report `NOGOLD` and verify nothing. Trust the headless cases
  (`tests/headless/gold/`), run as `tests/headless/run_suites.sh --nogui <t>` (drop
  `--nogui` for the display arm), which also echoes each `skip:` line under its verdict.
  The bare `./src/xschem` spelling works but is unarmed (see the throwaway test home).

### Reading `results.log`
- **It is the only place the answer is.** Stdout carries progress and notices, never the
  verdict; a run that completes exits 0, pass or fail, and none is refused or exits 2
  for a live peer. The exit code never says what a run found or whether it finished
  (the repo-root spelling above excepted). Name every case whose `Total num fail:` isn't 0.
- **Counted lines** (`summarize_all`): ending `FAIL`, `GOLD?` or `RESULT?`, or starting
  `FATAL`.
- **Uncounted lines** (`summarize_all`): `NOGOLD`/`NODISPLAY` — the case verified nothing —
  and, since issue **1487**, every `skip:` line a case printed plus that case's last
  `RESULT:` line with its check count, both inside that case's own block. A `skip:` names a
  row that did **not** run and is never a failure. ⚠ **`counted_failures=0` is a claim about
  correctness, not about coverage**: read `skips=` with it, and `/usr/bin/grep -n '^skip:'`
  the verdict for the names. Before 1487 the verdict was the one file that could not say what
  had not been measured — the stage-F gate at `7a46275f` carried **8 `skip:` lines in its case
  logs and 0 in its verdict**, with `test_ase_converge_1459` reporting 70 checks where a home
  holding the fork ngspice gets 76. The counted arm is still tested **first**, so a `skip:`
  line whose reason happens to end in `FAIL` scores exactly as it did before (rows `V5a`–`V5f`,
  `test_regression_concurrency_1476.tcl`).
- **Read the trailer first**: `T1-RUN-BEGIN pid= script= start= planned_cases= verdict=
  home= binary= canonical=` (line-buffered; survives a kill) and `T1-RUN-END pid= cases=
  blocks= counted_failures= skips= elapsed= end=`. `home=` is `throwaway`, `real` or `custom`;
  `binary=` is the path `auto_execok` resolved (a PATH fallback shows). Both are
  sanitised (whitespace replaced, `T1-RUN-` → `T1_RUN_`) and precede `canonical=`, which
  stays last, so no value can end the header in a counted shape or plant a fake sentinel
  (D6, D13.10, D13.17); neither sentinel matches a counted shape (row `V4a`,
  `test_regression_concurrency_1476.tcl`). **No `T1-RUN-END` means the run did not
  finish**, whatever the contents; an unfamiliar pid or start time is someone else's run
  or a fossil.
- **Every prefix of a green run is green** (counted shapes need a line to exist): a run
  killed mid-write (an outer `timeout` on the driver, any kill) can score zero (row
  `V3c`). The missing `T1-RUN-END` exposes it, as does a block count short of cases − 1.
  A per-case `T1_CASE_TIMEOUT` is instead scored as a counted `FAIL`.
- **A stale file**: its header's pid and start time identify it; also check the mtime
  moved off its pre-run value, and treat an empty log after a run as a death, never a
  zero. Don't hash it: pids and timestamps make every md5 differ.
- `couldn't execute "xschem"` or `exit 127` anywhere: the binary never launched and
  nothing in that run is meaningful (issue 0016 Part 4 separates it from the benign
  rc=10 fall-through).
- **Cases, blocks and lines are three different numbers**; take `cases=`, `blocks=`,
  `counted_failures=` and `skips=` from `T1-RUN-END`. Cases = `Start` lines; blocks = `Total num
  fail:` lines = cases − 1 on a green run (`xschemtest.tcl` writes one only on failure);
  `wc -l` moves with the failure count — and, since issue **1487**, with the number of `skip:`
  and `RESULT:` lines the cases emitted — so never check it against an arithmetic figure.
  At `7a46275f`: 87 cases (3 `tcases` + 72 `hcases` + 11 `dcases` + `xschemtest`), 86
  blocks, `wc -l` 177 green, 185 with eight failures, on the **pre-1487** driver. Read off
  the gate verdict `tests/results.3294880.log` at **`486a9635`**, taken in the `~/gc26` clone at an
  18-character path (worst-case `test_op_annot` probe path **80**, inside the 84 that re-gates
  clean): **125 cases** (3 `tcases` + **96** `hcases` + **25** `dcases` + `xschemtest`),
  **124 blocks**, **`wc -l` 374 green**; trailer
  `cases=125 blocks=124 counted_failures=0 skips=8 elapsed=649s`, zero live-peer lines, zero
  counted shapes, zero nonzero `Total num fail:` lines, and `test_ase_optier_0963` at
  `ALL PASS (110 checks)`.
  ⚠⚠ **`headless/test_fluid_editing.disp.log` reads `RESULT: ALL PASS (28 checks)` IN THIS VERDICT,
  WHICH IS THE FIRST TIME THAT SUITE'S GESTURE ROWS HAVE EVER RUN INSIDE A GATE.** Issue **1641**:
  it had been in `hcases` ALONE for a month, whose loop hard-codes `--nogui`, where it self-skips to
  **zero** rows and exits 0 with a completion banner — so the case PASSED having measured nothing
  while its display arm was RED at row `FE8`. The `hcases` entry **stays**, as a crash guard: the
  gesture path dereferences the absent `.drw` canvas and SIGSEGVs under `--nogui`. Its `hcases`
  block still reads `RESULT: SKIP (no X)` at line 37 and its `dcases` block reads the 28 checks at
  line 371 — **two blocks, one suite**, which is what a both-lists registration looks like in a
  verdict and is worth recognising before diagnosing one of them as a contradiction.
  ⚠ **The registration delta was DERIVED and matched exactly**: `cases` 124 → 125, `blocks`
  123 → 124, **`wc -l` 371 → 374**, `counted_failures` 0 and `skips` **8** both unmoved, by lifting
  `summarize_all` out of `run_regression.tcl`'s own text (16 procs lifted, so a future helper
  arrives for free) with `banner_complete` **sourced** from `banner_rule.tcl` and run over both
  arms' real captured output. `planned_cases=125` in the header agreed INDEPENDENTLY. **This is the
  SEVENTEENTH consecutive `skips=8`, and it held for the by-now-familiar reason**: the suite's
  self-skip is announced **uppercase** (`SKIP:`) and `summarize_all` counts only lowercase
  `^skip:` — measured, not predicted (`/usr/bin/grep -c '^skip:'` → 0 on both arms,
  `/usr/bin/grep -c '^SKIP'` → 1 on the headless one).
  ⚠ **Stage J1 moved TWO published check counts and no trailer term**: `test_calc_wave_dest`
  90 → **102** and `test_calc_measure` 160 → **170**, both already in `hcases`. Together with the
  1641 registration in the same gate, that is one run demonstrating both halves of the rule —
  a registration moves the trailer, a check count never does.
  ⚠ **PLAN 5.4 moved SIX published check counts and not one trailer term** — `test_calc_measure`
  135 → 160, `test_calc_skeleton` 548 → **573**, `test_calc_widgets` 246 → **259**,
  `test_calc_buffer` 130, `test_suite_watchdog_1403` 32 → **40**, and `test_calc_wave_dest` 89 → 90.
  Every one of those suites was **already registered**, so `cases`, `blocks`, `counted_failures`,
  `skips` and even **`wc -l` are all unchanged** — `wc -l` moves with the *number* of `RESULT:` and
  `skip:` lines, not with the counts inside them. **That is the clean demonstration that a published
  check count is NOT a baseline**: it is a figure three instruments recompute every run, which is why
  this batch twice chose to move one rather than leave a sabotage unfenced. 371 was derived both
  times and matched both times.
  ⚠ `test_fluid_editing` appears in this verdict as `RESULT: SKIP (no X)` — registered in `hcases`
  **only**, whose loop hard-codes `--nogui`, so **all 26 of its rows gate nothing** and its display
  arm has been red at row `FE8`. Issue **1641**; the row is the suspect, not the product.
  The Calculator batch's **wave destination** took it there (`test_calc_wave_dest`, **`hcases`
  alone**, 89 checks) -- `calc::wave_dest` plus R420's `xaxis` argument on `dutyCycle`, the
  destination that `dutyCycle`'s default, `delay`'s `nth = 0` and the unbuilt `frequency` were all
  waiting on. **TWENTY-FOURTH consecutive `skips=8`**, and `wc -l` 371 is the derived figure
  (368 + 3) matching exactly. ⚠ **`planned_cases=124` in the header agreed INDEPENDENTLY** with the
  figure derived from `summarize_all`'s own arms before the run, which is the only method that has
  been right about this number.
  ⚠ **`test_calc_scratch_reuse` is 54 here, not 53**: row **SR5** was widened as a derivation because
  the destination's producer must call `xschem raw add` -- the only way to create a column -- so it
  lands in SR5's `adders` set without minting a `calc::tmpvec`, reading samples back or deleting.
  R402's mint-and-delete discipline is about a **temporary** and that column is **persistent**, which
  is the exemption SR5's own comment already grants `plot_rpn`. **The producer was right and the row
  was narrow**, which is the opposite of the usual call and was decided by measuring, not by arguing.
  ⚠⚠ **A SABOTAGE SURVIVED THE FIRST IMPLEMENTATION AND WAS CLOSED RATHER THAN DECLARED.** Hardcoding
  the sweep column's name instead of reading it from the current database gives `ALL PASS`, because
  every row in the band drives the `tran` fixture where that name *is* `time`; against an `ac`
  database it is `frequency`. The crew declared it and chose not to fence it, on the grounds that a
  new row moves the published check count. **The driver overruled that**: a fence that passes against
  its own defect reads as coverage and is not -- and the count is **not a baseline**, since every site
  carrying it (`OVERALL:`, `RESULT:`, and a `banner_rule`/`summarize_all` capture) is an instrument
  that recomputes it. Re-derived rather than preserved: **88 -> 89, identical on both arms, delta
  exactly +1 on each**, registration delta unchanged.
  One commit earlier, `123/122/0/8` was `tests/results.2806916.log` at `7f9b9b50` (3 + 95 + 24 +
  `xschemtest`, `wc -l` 368, 634s), **PLAN 7.3** (`test_calc_measure`, `hcases` alone, 125 checks) --
  `riseTime`, `delay` and `dutyCycle`, green on the FIRST attempt where the previous commit took four.
  ⚠ **`test_calc_skeleton` ran its DISPLAY arm at `ALL PASS (548 checks)` in this gate**, which is the
  only reason the catalogue change is verified: that suite holds row **S24**, whose closed `returns`
  vocabulary is now `{scalar wave bool scalar/wave scalar/list}` -- **widened by one term for R419**,
  with its eight category counts unmoved at `{56 26 12 4 3 3 4 108}` -- and it is a `dcases` entry
  that **self-skips to 0 checks under `--nogui`**. A crew can only lift S24's predicates and run them
  headless; the real arm is the gate's. `cross` moved from `scalar/wave` to `scalar/list` here (and,
  one commit earlier, `dutyCycle` from `scalar` to `scalar/wave`), so the arm mattered both times.
  ⚠ **The vocabulary is enumerated in THREE other places that move with it**: the `calc::fn_fields`
  schema comment, the `calc::catalogue` comment (**twice**), and spec R416. A widening that edits only
  S24 leaves three prose copies lying.
  One commit earlier, `122/121/0/8` was `tests/results.2701197.log` at `c4eba95d` (3 + 94 + 24 +
  `xschemtest`, `wc -l` 365, 635s) -- and ⚠ that commit's FIRST gate was RED on
  `test_home_isolation` rows `H1a`/`H1b`, which has not recurred in the two full gates since.
  The Calculator batch's **`cross`** took it there (`test_calc_cross`, **`hcases` alone**, 187
  checks) -- PLAN rows 7.1+7.2, the measurement layer's keystone, pulled ahead of phases 4-6 at the
  user's request. **TWENTY-SECOND consecutive `skips=8`**, and `wc -l` 365 is the derived figure
  (362 + 3) matching exactly.
  ⚠⚠ **THIS COMMIT'S FIRST GATE WAS RED AND THE RED WAS NOT THE NEW SUITE.**
  `tests/results.2565930.log` at the same commit came back `counted_failures=1`, the failure being
  `test_home_isolation` rows **`H1a`/`H1b`** -- *"with no dev display the arm runs on a private Xvfb
  numbered from 100"* -- reporting **`rc=0` with an EMPTY display number** (`arm said : (pid )`,
  `the case saw DISPLAY=`). `test_calc_cross` was `ALL PASS (187 checks)` in that same run, row
  **`G2`** passed over all **740** scripts (`UNARMED: none`), and row `H2` started a fixture display
  on `:151` seconds later -- so neither the new suite nor Xvfb itself is implicated. It did **not**
  reproduce: the suite passes standalone at 116 checks, and the re-gate above has it at
  `ALL PASS (116 checks)`. **Per D8 this is ONE observation and nothing was changed for it**; the
  evidence is kept under the session scratchpad. This is the SAME SUITE as the 2026-09-24
  `H2b` observation below but a **different row**, so it is not a second sighting of that one. If
  `H1a` recurs, suspect a failed Xvfb *spawn* (which is what `rc=0` plus an empty display looks
  like) before suspecting the code.
  ⚠ **Three gate attempts were killed before one completed, and the cause was NOT the product.**
  Two `run_in_background` gate runs were killed by the harness *"because the system is running low
  on memory"*, both at roughly case 100. **The diagnosis that memory was to blame was wrong and is
  recorded here because it is the plausible wrong answer**: the run that COMPLETED had `/tmp` at
  **5.0 GB** while the two that died had it at **744 MB with 12 GiB available**. What actually
  worked was **`setsid`** -- taking T1 out of the tool's background-command process tree, after
  which it ran to completion untouched while the *waiter* watching it was itself killed. So the kill
  is a property of the harness's wrapper, not of T1's footprint, and the fix is to detach rather
  than to free memory.
  ⚠⚠ **CONFIRMED AGAIN ON 2026-10-02, AND THIS TIME THE MEMORY FIGURE WAS TAKEN AT THE INSTANT OF
  THE KILL** — which is what the earlier sighting lacked and why its diagnosis went wrong. The
  wave-destination gate was launched under `setsid` with an `until`-loop waiter in
  `run_in_background`. The waiter was killed *"because the system is running low on memory"*;
  checked immediately afterwards, `free -g` reported **12 GiB available** of 15 with `/tmp` at
  **721 MB of 7.7 GB**, and the detached `tclsh run_regression.tcl` was **alive at 1:52 with 39
  cases started**. So the message is not a report about this machine's memory: it fires with ~80% of
  RAM free. **Expect the waiter to die and treat it as routine** — re-arm it, or poll; the run is
  unaffected because `setsid` put it in its own session. **FOURTH sighting, and the first that
  cannot be explained by memory at all.** Never respond to it by freeing memory, shrinking a run, or
  serialising crews.
  ⚠ **But `/tmp` IS tmpfs here, and scratch left in it keeps consuming RAM for the whole session**
  -- a real standing cost even though it was not this red's cause. This session had **4.4 GB** of
  finished batches' scratch sitting in `/tmp/claude-1000/...`, i.e. in RAM; removing it took `/tmp`
  from 5.0 GB to 744 MB and `available` from 7.9 to 12 GiB. The paragraph under **Concurrent T1
  runs** saying not to serialise on memory remains correct about *T1's* peak, and the
  gate-clone-path warning already said `/tmp` is tmpfs -- neither says that **your own scratch is
  charged to RAM until you delete it**. Sweep a finished stage's scratch rather than leaving it.
  One commit earlier, `121/120/0/8` was `tests/results.2406744.log` at `08b860e1` (3 + 93 + 24 +
  `xschemtest`, `wc -l` 362, 632s).
  The Calculator batch's **PLAN 3.3-3.4** took it there (`test_calc_plot`, `dcases` alone), which
  closes its vertical slice. ⚠ **The registration shape was MEASURED rather than reasoned, and the
  measurement is the argument**: run through `tests/banner_rule.tcl` before the entry went in, that
  suite's display arm gives `banner_complete=1` and its `--nogui` arm gives
  `regression_case_failed(0)=1` -- so an `hcases` entry would have been a standing red, which is
  issue 1615's incident exactly. **TWENTY-FIRST consecutive `skips=8`**, derived as every figure
  since 1625 has been.
  One commit earlier, `120/119/0/8` was `tests/results.2198974.log` at `47ea655a` (3 + **93** + 23
  + `xschemtest`, `wc -l` 359, 631s), PLAN 3.1-3.2.
  The Calculator batch's **PLAN 3.1-3.2** took it there (`test_calc_engine` and
  `test_calc_scratch_reuse`, both `hcases`), the stage where Evaluate stopped being a stub.
  ⚠ **TWENTIETH consecutive `skips=8`, and it is still derived rather than predicted** -- the two
  captures were taken exactly as the `hcases` arm takes them and scored with `summarize_all`'s own
  regexp arms before the run: zero lowercase `^skip:`, zero uppercase, one `^RESULT:`,
  `banner_complete=1` for both, giving cases +2 / blocks +2 / counted +0 / skips +0 / `wc -l` +6,
  every one of which the gate matched. `planned_cases` agreed independently at 120.
  One commit earlier, `118/117/0/8` was `tests/results.1996257.log` at `c2cdb307` (3 + **91** +
  23 + `xschemtest`, `wc -l` 353, 633s), issue 1628's engine fix.
  Issue **1628** took it there (`test_divis_zero_1628`, **`hcases` alone**) -- a C fix in the RPN
  engine, not a Calculator change: `plot_raw_custom_data()`'s `DIVIS` arm read `y[p - 1]` at
  `p == first`, one element BEFORE the destination column, witnessed by valgrind as an
  *"Invalid read of size 8 … 8 bytes BEFORE a block of size 64"*. ⚠ **`skips=` held at 8 for a
  NINETEENTH figure and the suite is `hcases` alone with NOTHING display-only in it**, which is the
  surprising part: the half of the defect needing a caller with `first > 0` is reached through
  `xschem graph_marker add_at` -> `graph_marker_sample`, which evaluates and returns a sample with
  no X at all, where issue 0325's equivalent band needs a display and self-skips. Derived from
  `summarize_all`'s own arms before the run, as every figure since 1625 has been.
  One commit earlier, `117/116/0/8` was `tests/results.1789789.log` at `a0d56801` (3 + 90 + 23 +
  `xschemtest`, `wc -l` 350, 627s), the Calculator batch's PLAN phase 2.
  The Calculator batch's **PLAN phase 2** took it there, registering `test_calc_buffer` in
  `dcases` alone -- the behaviour fence for a Tk feature, so its headless arm self-skips and an
  `hcases` entry would measure nothing. ⚠ **`skips=` held at 8 for an EIGHTEENTH consecutive
  figure, and again the method is the point**: the capture was taken exactly as T1's `dcases` arm
  takes it and scored with `summarize_all`'s own regexp arms before the gate ran -- zero lowercase
  `^skip:`, zero uppercase, exactly one `^RESULT:`, `banner_complete=1` -- giving cases +1,
  blocks +1, counted +0, skips +0, `wc -l` +3, every one of which the gate then matched.
  One commit earlier, `116/115/0/8` was `tests/results.1603161.log` at `deccdbd1` (3 + 90 +
  **22** + `xschemtest`, `wc -l` 347, 628s).
  Issue **1626** took it there, registering **THREE** cases at once: `test_calc_skeleton` and
  `test_calc_widgets` in `dcases`, and the new `test_registered_banner_1626` in `hcases`. The
  defect was that **789 passing Calculator checks gated nothing for a month** -- both suites
  printed only `RESULT: ALL PASS` and `banner_complete` returned **0** on their real output on
  both arms, the same structural unregisterability issue 1615 found in the whole
  `test_wave_sigbrowser*` family.
  ⚠ **`skips=` held at 8 for a SEVENTEENTH consecutive figure, and this time for a reason that is
  not any of the five mechanisms below**: all three suites emit **no skip announcement at all**,
  in any case, on any arm -- not a lowercase `skip:`, not an uppercase `SKIP:`, nothing. So there
  was no spelling subtlety to get wrong, which is worth saying plainly because the previous two
  figures were both reached by one. ⚠ **The delta was DERIVED, not predicted**: two crews
  independently lifted `summarize_all` out of this file's own text, ran its regexp arms over real
  captured output, and both got cases +3 / blocks +3 / counted +0 / skips +0 / `wc -l` +9 before
  the gate ran -- and `planned_cases` arithmetic agreed at 116. After 1625, where a verifier and
  the driver both mispredicted this number, deriving it is the only acceptable method.
  ⚠ **The gate clone is at `~/gc26`, NOT in `/tmp` and NOT in the session scratchpad.** `/tmp` is
  tmpfs with ~3 GB free here and a clone plus build needs about a gig; the scratchpad is ~100
  characters before the clone name, which is most of the path budget `test_op_annot` needs.
  17 characters gives a worst-case probe path of 79, under the 84 that re-gated clean at
  `97766c66`.
  One commit earlier, `113/112/0/8` was `tests/results.1227234.log` at `f3d60af9`, a clone at a
  9-character path (3 + 89 + **20** + `xschemtest`, `wc -l` 338, 620s). Issue **1625** took it
  there by adding a `dcases` arm to
  `test_add_wire_label`, which was already in `hcases` -- because the six rows fencing its new
  Edit-Properties checkbox drive real Tk, self-skip under `--nogui`, and so **were being run by
  nothing**. ⚠⚠ **BOTH AN ADVERSARIAL VERIFIER AND THE DRIVER PREDICTED THAT REGISTRATION WOULD
  MOVE THE TRAILER OFF `skips=8`, AND BOTH WERE WRONG** -- the suite announces its skipped bands
  with an **uppercase `SKIP:`** at three sites and `summarize_all` counts `^skip:` lowercase, so
  the figure held. The driver caught it by checking `summarize_all`'s own `regexp {^skip:}` arm
  before committing the claim, rather than after the gate contradicted it. That is the **sixteenth**
  consecutive 8 and the SECOND both-lists entry to cost none, by the same mechanism
  `test_replay_door_1619` used. One commit earlier, `112/111/skips=8` was
  `tests/results.1010173.log` at `80dc3bbb` (3 + 89 + 19 + `xschemtest`, `wc -l` 335, 627s), and the
  same 112/111 was re-measured at `15b76bae` (`results.1120366.log`, 633s) where issue 1623 changed
  six C files and moved **no** count at all, only the published check total 196 -> 224. Issue **1620** took it there, registering `test_select_log_1620` in BOTH lists
  and `test_selflog_grep_guard` in `hcases` -- **three** cases at once, and `wc -l` moved by
  **9** = 3 cases x 2 lines + 3 newly published `RESULT:` lines, which is why the delta is worth
  checking against the registration rather than against a remembered number.
  One commit earlier, `109/108/skips=8` was `tests/results.902414.log` at `1041a87f`
  (3 + 87 + 18 + `xschemtest`, `wc -l` 326, 622s), where issue **1619** took it there
  (`test_replay_door_1619`, the replay door for the action log),
  and ⚠ **it is the first suite in this series registered in BOTH lists that still costs ZERO
  skips — which falsifies, as a universal, the sentence two paragraphs down saying a suite in
  both lists costs one headless self-skip.** It costs none because its headless arm self-skips
  with an **uppercase `SKIPPED:`**, which `summarize_all` does not count; only 2 of its checks
  are display-only (63 headless, 65 on the display arm). So the both-lists rule is a rule about
  *lowercase* `skip:` lines, not about registration shape. **That is the FOURTH distinct
  mechanism to arrive at 8**, after `hcases`-alone, `dcases`-alone, and both-lists-with-a-skip
  cancelling out. One commit earlier the same figure was `107/106/skips=8` in
  `tests/results.775219.log` at `acd30d62` (`wc -l` 320, 619s), itself a **re-gate** after the
  `test_ase_optier_0963` flake reddened the first run at that commit; and before it
  `tests/results.438229.log` at `3e307011` (107/106, `wc -l` 320, 621s), where issue **1616**
  took the count up (`test_wave_viewer`, **`dcases` alone** — the second suite in this series
  registered that way, after 1615's). ⚠ **That commit's FIRST gate was RED at
  the same commit** (`results.370291.log`, `counted_failures=3`) and the red was
  `test_ase_optier_0963`, the known flake, printing the `rc={1}` that the `d6816c00`
  diagnostic exists to print. **The commit was NOT declared green on that run**: the suite
  was re-run three times alone (110 checks each) and then the WHOLE T1 was re-run at the
  same commit, which is the figure quoted above. See the flake paragraph under
  **Concurrent T1 runs** — a red there is still a red, and re-gating is the handling.
  ⚠⚠ **AND IT HAPPENED AGAIN THE SAME DAY, WITH THE SAME rc, ON A QUIET MACHINE — SO IT IS NOW
  TWO IDENTICAL OBSERVATIONS AND NOT A ONE-OFF.** Issue 0619's gate at `acd30d62`
  (`results.709339.log`) also came back `counted_failures=3`, the same case, the same row `X1`
  with `NORAW rc={1} wall=11381ms` against the previous `rc={1} wall=12058ms`, `X2` again
  `ZZNOTRUN`. Nothing else in either run failed. **D8 says not to declare a standing red that
  cannot be reproduced AND not to dismiss repeated identical observations — this is the second,
  so the second half now applies.** What the two share and what it rules out: `rc=1` both times,
  meaning ngspice ran for 11-12 s and exited nonzero of its own accord, so it is not a timeout,
  not a missing binary and not the harness; both on a quiet machine, so the "under load"
  correlate from the 2026-09-28 characterisation is dead; both inside a full T1 and never
  standalone, where the suite passes at 110 checks every time it has been asked. **That last
  asymmetry is the live lead** — something about the full-run environment, not the load, makes
  this ngspice invocation fail. Do not spend another gate re-running it without looking at that.
  ⚠ **But "inside a full T1" is NOT sufficient either, and the re-gate proves it**: `acd30d62`
  was re-gated in the SAME clone at the SAME commit and came back
  `cases=107 blocks=106 counted_failures=0 skips=8 elapsed=619s` (`tests/results.775219.log`,
  `wc -l` 320, zero live-peer lines) with **`test_ase_optier_0963` itself at `ALL PASS (110
  checks)`**. So the condition is intermittent *within* the full-run environment, not caused by
  it — which kills "just run it standalone to bisect" as a method, since the only environment
  that has ever failed also passes most of the time. Whatever is found next has to explain a
  coin-flip, not a switch. That green run is this commit's gate figure; the red one is
  `results.709339.log`, kept above because a red that is re-gated away still has to be recorded.
  One commit earlier, `106/105/skips=8` was `tests/results.138903.log` at `943038f9`, a
  clone at a 10-character path, `wc -l` 317, 607s (3 + 86 + 16 + `xschemtest`); issue
  **0514** took it there (`test_raw_schname_0514`, `hcases` alone). Before that,
  `105/104/skips=8` was `tests/results.61417.log` at `76c132de`, a clone at an
  11-character path, `wc -l` 314, 609s (3 + 85 + 16 + `xschemtest`).
  Issue **1615** took the count up, and it is the **first figure in this series where the
  new suite went into `dcases` ALONE** (`test_wave_sigbrowser_panes`, whose fenced band is
  display-only). ⚠ **That commit's FIRST gate was RED at `809c03d1`** —
  `counted_failures=1`, the failure being the newly registered suite scored
  `HARNESS: … (exit=0, OVERALL_ok=0, died=0)` with all 88 of its own checks passing, because
  `wvbs_finish` never emitted the `OVERALL: ok` sentinel `banner_complete` requires. See the
  two bullets under **Harness rules**; the lesson is that **registering a suite is itself a
  change that needs gating**, and a suite's own green run says nothing about it.
  Before that, `104/103/skips=8` was `tests/results.3703564.log` at `00d90845`
  (3 + 85 + 15 + `xschemtest`, `wc -l` 311, 598s). The same 104/103 was measured one commit
  earlier at `818ea64c`
  (`results.3631374.log`, 600s), where issue 1614's suite took the case count up; the two
  commits between them changed `src/util.c` and that suite only, which is why both were
  gated. Before them, `103/102/skips=8` twice — `results.3547226.log` at `5d7380b2` and
  `results.3467604.log` at `69be35d3` (issue 1611's suite) — and `102/101/skips=8` was
  `results.3308304.log` at `cee5945b` (issue 1610, `wc -l` 305, 596s). The
  `101/100/skips=8` figure before that was `results.3226734.log`
  at `636bc431`, which registered `test_scratch_home_note` — a suite that had been failing
  at HEAD with nothing running it, so **the fence over T1's own counting predicate was
  itself unfenced**; `wc -l` 302, `elapsed=599s`. Before those, `100/99/skips=8` was
  `results.3131395.log` at `2fbfa809` (issue 1608, `wc -l` 299, 594s), and
  `99/98/skips=8` was `results.2257277.log` at
  `eb20dc62` (issue 1606), and `98/97/skips=8` before that was `results.1842389.log` at
  `c3a59de4` (issue 1603), and `97/96/skips=8` before that was `results.1594312.log` at
  `97766c66` (`wc -l` 290 = `2` sentinels + `96` headers + `96` `Total num fail:` + `3`
  NOGOLD + **`8` `skip:`** + **`83` `RESULT:`** + **`2` banner-only counts**).
  **Sixteen figures in seven days**: `88/87/skips=5` (`results.2325750.log`,
  the 1487+1486 fixes), `90/89/skips=6` (`results.2825611.log`, 1352), `92/91/skips=7`
  (`results.3482374.log`, 1601), `94/93/skips=8` (`results.344048.log`, 1604),
  `95/94/skips=8` (`results.598045.log`, the headless-crash batch), `97/96/skips=8` (the
  hierarchical-PDF port), `98/97/skips=8` (1603), `99/98/skips=8` (1606),
  `100/99/skips=8` (1608), `101/100/skips=8` (the `test_scratch_home_note` repair),
  `102/101/skips=8` (1610), `103/102/skips=8` (1611), `104/103/skips=8` (1614) and
  `105/104/skips=8` (1615) and `106/105/skips=8` (0514) and `107/106/skips=8` (1616) and
  `109/108/skips=8` (1619, which took TWO cases at once) and `112/111/skips=8` (1620,
  which took THREE) and `113/112/skips=8` (1625, a second arm for a suite already registered)
  and `116/115/skips=8` (**1626**, THREE cases at once -- two `dcases` plus one `hcases` --
  for suites whose 789 green checks had been gating nothing because neither printed the sentinel)
  and `117/116/skips=8` (the Calculator batch's PLAN phase 2, `test_calc_buffer` in `dcases`)
  and `118/117/skips=8` (**1628**, `test_divis_zero_1628` in `hcases` alone -- an engine fix, and a
  suite with no display-only row at all) and `120/119/skips=8` here (the Calculator batch's
  PLAN 3.1-3.2, TWO `hcases` suites at once) and `121/120/skips=8` here (PLAN 3.3-3.4,
  `test_calc_plot` in `dcases` alone, chosen by measuring `banner_complete` on both arms first)
  and `122/121/skips=8` here (**`cross`**, `test_calc_cross` in `hcases` alone, 187 checks --
  and the one figure in this series whose commit took **FOUR** gate attempts, three lost to a
  harness kill and one red on an unrelated case, before a clean trailer)
  and `123/122/skips=8` here (**PLAN 7.3**, `test_calc_measure` in `hcases` alone, 125 checks --
  `riseTime`, `delay`, `dutyCycle`)
  and `124/123/skips=8` here (**the wave destination**, `test_calc_wave_dest` in `hcases` alone,
  89 checks -- and the figure whose `planned_cases` header agreed INDEPENDENTLY with the
  `summarize_all`-derived prediction, which is now the only method this file endorses)
  and `124/123/skips=8` **again** at `cac6ca61` (**PLAN 5.4**, the argument dialog -- the first
  figure in this series where a whole stage landed and **no trailer term moved at all**, because all
  six suites it touched were already registered; only their published check counts moved, and even
  `wc -l` held at 371).
  ⚠ **`skips=` has now held at 8 across SIXTEEN
  consecutive
  figures, and that is a coincidence of what was registered, not a property**: 1604, 1603,
  1606, 1608, 1610, 1611, 1614 and the `test_scratch_home_note` repair each went into
  `hcases` ALONE, which costs one case and no skip, while 1352
  and 1601 went into both lists and cost a skip each. ⚠⚠ **AND THE ELEVENTH REACHED 8 BY A
  THIRD MECHANISM, WHICH IS THE CLEAREST PROOF YET THAT THE NUMBER IS NOT A PROPERTY:** issue
  1615 registered `test_wave_sigbrowser_panes` in **`dcases` ALONE** — the first time in this
  series — which also costs one case and no skip, but for a different reason (its headless
  arm is not run at all, rather than run and self-skipped). Three different registration
  shapes have now produced the same 8, and a fourth (`dcases` alone for a suite that DOES
  print a lowercase `skip:`) would not. ⚠ **Issue 1616 then registered `test_wave_viewer` in
  `dcases` ALONE as well — the SECOND suite to reach 8 that way — and it is worth knowing why
  it costs no skip even though its headless arm DOES self-skip 343 of its 402 checks: the
  self-skip prints uppercase `SKIPPED:`, which `summarize_all` does not count, and in any case
  the headless arm is never run for a `dcases`-only entry. Two different reasons, same zero.**
  ⚠⚠⚠ **AND THE FOURTEENTH BROKE THE RULE STATED IN THE VERY NEXT PARAGRAPH.** Issue
  **1619** registered `test_replay_door_1619` in **BOTH** lists -- the shape this file says costs
  "two cases and one headless self-skip" -- and it cost **two cases and ZERO skips**, taking the
  count straight from 107/106 to 109/108. The reason is the same uppercase/lowercase distinction
  1616 turned up, now arriving where it actually contradicts something: the suite's headless arm
  DOES self-skip its 2 display-only checks (63 headless, 65 on the display arm), but it announces
  that with an uppercase `SKIPPED:`, and `summarize_all` counts only lowercase `skip:`. **So the
  both-lists rule below is a rule about the SPELLING a suite uses to announce a skipped row, not
  about registration shape at all** -- and a fourth distinct mechanism has now produced 8. Anyone
  who had memorised "both lists costs a skip" would have called this green gate wrong.
  ⚠ **The FIFTEENTH added THREE cases in one commit and still did not move it** (issue 1620:
  `test_select_log_1620` in both lists, `test_selflog_grep_guard` in `hcases`). So the number has now
  survived a one-case commit, a two-case commit and a three-case commit unchanged, which is worth
  saying plainly because it is exactly the evidence a reader would use to conclude it is a constant.
  It is not. What actually held is that none of those suites printed a **lowercase** `skip:` line.
  ⚠ **THE SIXTEENTH IS THE ONE THAT SHOULD SETTLE IT, BECAUSE TWO INDEPENDENT PARTIES PREDICTED IT
  WRONG.** Issue 1625 added a `dcases` arm to a suite already in `hcases`. An adversarial verifier
  wrote that this would "cost one case and one `skip:` line, moving the trailer off `skips=8`", and the
  driver wrote the same thing into a source comment. Both were wrong, and the gate came back
  `113/112/skips=8`. The reason is the uppercase/lowercase distinction this warning has now recorded
  three times: the suite prints `SKIP:` and `summarize_all` counts `^skip:`. **If two parties reasoning
  carefully about registration shape both got it wrong, nobody should be predicting this number at
  all.** Read the trailer.
  ⚠ **THE SEVENTEENTH SHOWS WHAT TO DO INSTEAD, AND IT IS NOT "PREDICT MORE CAREFULLY".** Issue
  **1626** registered THREE cases at once (two `dcases`, one `hcases`) and came back
  `116/115/skips=8`. Nobody guessed: two crews independently **lifted `summarize_all` out of this
  file's own text**, printed its five regexp arms, and ran them over the suites' real captured
  output -- both arriving at cases +3 / blocks +3 / counted +0 / skips +0 / `wc -l` +9 before the
  gate ran, with `planned_cases` arithmetic agreeing at 116, and the gate then matching every one.
  The reason the figure held is also a **sixth** mechanism and the only boring one: all three suites
  emit **no skip announcement whatsoever**, in any case, on any arm, so there was no spelling to get
  wrong. **Derive it from the predicate, do not reason about registration shape.** That is a
  five-minute probe and it has now been right where careful reasoning was twice wrong.
  **Sixteen in a row is well past the point where
  a reader starts treating it as the expected value, which is exactly why this warning gets
  longer rather than shorter each time.** A reader who starts treating 8 as the
  expected value will call a correct run wrong the next time a suite registers in both, and
  **eight in a row is exactly long enough for someone to start trusting it**.
  **The step is not a constant**: a suite registered in BOTH
  lists costs two cases and one headless self-skip; one registered in `hcases` alone costs
  one case and no skip. Anyone checking against a figure written down anywhere, this file
  included, would have called eight green runs red this week. Read the trailer. ⚠ Both new terms are
  **environment-dependent** — a home that cannot reach the fork ngspice adds three more
  `skip:` lines — so this figure is even less of a constant than it was. To count a list, find `set hcases
  [list` (not a line number) and pipe it through `/usr/bin/grep -o '"[^"]*"' | wc -l`;
  `grep -c '"headless/'` and `grep -cE '\.log$'` (it matches `canonical=results.log`)
  miscount.
- **`Start`/`Finish` do not pair when the display arm cannot run.** Without a live dev
  display T1 runs the `dcases` on a private Xvfb from `:100` (D8). With no Xvfb (an
  uncounted `NODISPLAY:` per case) or one that won't start (a counted `HARNESS: <dc>
  display arm NOT RUN -- … : FAIL`), the `dcases` loop skips `Finish`. Count `Start`
  lines, or read `cases=`.

### Concurrent T1 runs
- **Two runs in one tree both proceed**; a live peer is announced (`another regression
  run is live in this tree (pid: …)`), so **zero such lines in your run's output is
  positive evidence it ran solo.** This exists so no crew is turned away, not for speed.
- The lock is only a publish mutex around the final copy. Knobs: `T1_LOG_LOCK_WAIT`
  (60 s), `T1_LOG_LOCK_TTL` (300 s), `T1_VERDICT_KEEP` (86400 s; sweeps dead runs'
  `results.<pid>.log`, never one whose `/proc/<pid>` exists). A stale lock is broken
  only on evidence (owner pid gone, or `/proc/<pid>/cmdline` no longer the script); one
  that can be neither taken nor broken lets the run proceed UNLOCKED with a warning.
- **Diagnose a T1 red by case, never by count.** A red can be a flake
  (`test_ase_optier_0963` is the known one -- see the measurement below) or a real collision (a
  suite hand-run while T1 was live has reddened a gate run). Shared globals beyond
  `/tmp/xschem_emergencysave_*` are unswept.
  **`test_ase_optier_0963`, characterised 2026-09-28.** It is NONDETERMINISTIC and the
  failing row MOVES, which is the tell that separates it from a regression: at one commit,
  a gate reddened `X1`/`X2`, a local run reddened `X7`, and three consecutive local runs
  passed at 109 checks; three further runs at the parent commit also passed. Both failures
  were under load, all six passes on a quiet machine. Every failure reported the bare word
  `NORAW`, which conflates "never ran", "ran and failed", "timed out" and "wrote nothing" --
  and `x_run2` had been capturing `ase::wait`'s rc, the wall time and the raw path into its
  result dict all along while the two readers discarded them. Since `d6816c00` a missing raw
  answers `NORAW rc={...} wall={...}ms raw={...}`, so **the next occurrence explains itself
  in the verdict** instead of needing five re-runs. ⚠ Nothing was retried, lengthened or
  skipped: that would have made it invisible rather than legible, and the suite would go
  green while measuring less. **So a red here is still a red** — read the rc it now prints
  before deciding anything, and do not treat the name as permission to ignore it.

  ⚠ **THE NEXT OCCURRENCE ARRIVED, THE rc REPORTING DELIVERED, AND IT REFUTES THE LOAD
  CORRELATE — 2026-09-29, issue 1616's gate at `3e307011`.** `counted_failures=3`
  (`results.370291.log`): `X1` reddened with **`NORAW rc={1} wall=12058ms
  raw={…/_optier0963_397286/xrun/tb_bandgap_ase.raw}`** and `X2` followed with
  `ZZNOTRUN`, plus the case's `HARNESS: … (exit=1, OVERALL_ok=0, died=0)` line. So the
  `d6816c00` diagnostic did exactly what it was built for: **rc 1 means ngspice RAN for
  12 seconds and exited nonzero of its own accord** — not "never ran", not a timeout, not
  a harness fault — and that was readable from the verdict without a single re-run.
  ⚠ **But the machine was QUIET**: the only other work that day's session had running
  ended at 03:14:15 and this T1 ran 03:18:12–03:28:33, no overlap. The sentence above
  saying "both failures were under load, all six passes on a quiet machine" is therefore
  **no longer a pattern you may lean on** — a quiet machine now has a failure too. Three
  immediate re-runs in the SAME clone at the SAME commit then passed at **110 checks**
  each (the count moves with the environment; 109 was a different home), and the same
  suite had been green in the previous commit's gate 20 minutes earlier. Per D8 this is
  recorded as an observation, not a verdict: nothing was retried in the product, nothing
  was skipped, and **the gate was re-run rather than the red waved through** — which is
  the only handling this paragraph licenses.

  **Second observation, 2026-09-24, recorded as an observation and not as a verdict:**
  `test_home_isolation` row **`H2b`** reddened once inside a full T1 run at `c3a59de4`
  (`results.1766057.log`, `counted_failures=1`) and the mechanism is named in the row's own
  detail — its **fixture** dev display's `openbox` never started, so `running $w2` was false
  (`openbox  {}`, empty pid). It is that row's own child on a fixture display number, not the
  real `:99`, which was healthy throughout. It did **not** reproduce: the same suite passed
  alone in the same clone (116 checks), passed in the main tree at the same commit, and a
  second full gate of the same commit in the same clone came back
  `cases=98 blocks=97 counted_failures=0 skips=8` (`results.1842389.log`); it has not recurred
  since, through two further full gates at `c3a59de4` and `eb20dc62`. Per D8 — do not
  declare a standing red that cannot be reproduced, and do not dismiss repeated identical
  observations — this is **one** observation, so nothing was changed for it. If it recurs,
  suspect `openbox` failing to start under full-run load before suspecting the code, and note
  that an absent WM falls back silently with only a stderr warning.
- A T1 number taken before 2026-09-17 while another run was live is not evidence (runs
  then corrupted each other; `exit -1`, which no xschem writes, is the tell). A batch
  driver that serialises its crews is making its own scheduling choice, not the harness's.
- **Do not serialise on memory, or blame it for a short verdict** (15.35 GiB RAM + 4 GiB
  swap, measured 2026-09-17; concurrent T1s add no measurable peak; no OOM kill is
  recorded). "~7.8 GB" is a fossil this file overrides, also in briefs from
  `doc/claude/ledger/{crew,crew_annotate,crew_opfix}.js` and
  `doc/claude/op_param_batch/item_pipeline.js`; leave dated records carrying it
  (ledgers, session prompts, issue files) unedited, or you falsify the record.
- **Match shared namespaces by identity, never by pattern or count.** Never ask
  `pgrep -af run_regression` whether a run is live (`-f` matches your own shell). Like
  `t1_live_runs`, count a `results.<pid>.log` as live only if `/proc/<pid>` exists; or
  bracket a character (`'run_[r]egression'`), or match `ps -eo comm=`. Already written
  up (Lesson 5 of `doc/claude/code_analysis/gui_test_gate_tutorial.md`, and two
  others): file nothing new.

### Harness rules
- **No test harness builds.** `full_audit.sh` and every suite run `$REPO/src/xschem` as
  found, so a stale binary (e.g. after `git stash` → build → `git stash pop`) gives a
  plausible audit with wrong answers. **Rebuild before any audit meant as evidence**; on
  an unexpected red, check the binary before the code (`make -C src` recompiling
  everything means a header moved).
- **A suite that is not in `run_regression.tcl` is run by NOTHING, and a fence nothing runs
  rots silently.** Measured 2026-09-27: `test_scratch_home_note` row `C1` lifts T1's own
  `summarize_all` out of `run_regression.tcl` and evaluates it, to prove the driver does not
  miscount the `note:` and `skip:` lines these suites print. Issue **1487** gave that proc a
  helper; the row lifted one proc **by name**, the lifted copy died on an unknown command, and
  the row had been **red at HEAD** reporting a bare `{1 -1}` that said nothing about why —
  because the suite was in no list, so only a hand-run could ever have surfaced it. **Write the
  suite and register it in the same commit.** Two habits came out of it and both generalise:
  make a probe lift or discover **everything** its target needs rather than a named subset (a
  hand-kept list is the same defect one level up — the same reason row `X1` of
  `test_snprintf_fmt_1608.tcl` exists), and put the failure's **cause** in the check's own name,
  so a future break prints `invalid command name "…"` instead of a sentinel.
- ⚠ **"Run by NOTHING" is the wrong half of that sentence; the right one is "does not gate a
  commit".** Measured 2026-09-28 (issue **1615**): **334 of the 418 `tests/headless/test_*.tcl`
  files are in neither `hcases` nor `dcases`** — only **84** are, plus 4 bare-name entries that
  live in `tests/` rather than `tests/headless/` (`buried_hilight`, `hilight_hier_oracle`,
  `hilight_hier_dump_replay`, `hilight_xwin_sync_headless`; a census regex requiring the
  `headless/` prefix reports those four as registered-with-no-file, which is the regex's bug and
  not a defect). `full_audit.sh` **does** run all 418 — it globs `test_*.tcl` — so the tail is
  audit-reachable and simply never in front of a gate. The remedy the two readings imply differs:
  "run by nothing" says register everything, "does not gate" says decide per suite. **What is
  adopted is the bounded half: a suite you add a fence to, you register in the same commit.**
- ⚠⚠ **AND "IT PASSES STANDALONE" IS NOT EVIDENCE THAT A SUITE CAN BE REGISTERED.** Registering
  `test_wave_sigbrowser_panes` gated **red** at `809c03d1` with all 88 of its own checks passing:
  `HARNESS: … did not complete cleanly (exit=0, OVERALL_ok=0, died=0)` on the line above its own
  `RESULT: ALL PASS (88 checks)`. `banner_complete` in `tests/banner_rule.tcl` — the only Tcl
  reader, the one `run_regression.tcl` sources — is `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$`, and
  that file's header says it *"implements no `RESULT: ALL PASS` spelling at all"*. `wvbs_finish`
  in `tests/headless/wvbs_common.tcl` printed only the `RESULT:` line, so **all fourteen
  `test_wave_sigbrowser*` suites were structurally unregisterable** — which is the mechanical
  reason the whole `test_wave_*` family sat outside T1, not an oversight. `run_suites.sh` and
  `full_audit.sh` carry their own EREs and both accept `RESULT: ALL PASS`, so **the two readers
  that could see these suites were the two that are not the gate.** Fixed by making `wvbs_finish`
  emit `OVERALL: ok ($npass checks)` **additively**, `RESULT:` kept last because `summarize_all`
  publishes a case's last `RESULT:` line (119 suites already printed the sentinel;
  `wvbs_common.tcl` printed it zero times). Same defect family as issues 0420/0456/0492/0629/0689,
  whose standing red `banner_rule.tcl` records as *"filed FOUR times and waved through as
  furniture each time"*. **Before registering any suite, check its epilogue against
  `banner_complete`, not against `run_suites.sh`.** Write-up:
  `doc/claude/code_analysis/t1_runs_84_of_418_headless_suites.md`.
- **T1's baseline is ZERO counted failures.** A standing red is a defect, not
  furniture: if T1 is not at zero, say which case and why, per case; never carry a count
  forward. **Since 2026-09-22 the zero holds on BOTH display arms**, measured in a
  throwaway clone of `2bf05781`: `DISPLAY=:99` gives `cases=95 blocks=94
  counted_failures=0 skips=8` (`results.598045.log`) and `DISPLAY` **unset** gives the same
  (`results.658534.log`). Before that, four suites segfaulted with `DISPLAY` unset (issue
  1483, then 1492/1493), which is why every earlier figure in this file is a `DISPLAY`-set
  one. That class is closed at every site the headless-crashes batch could measure — and
  its receipts name the four blind spots its methods had, so "closed" means "closed where
  anyone has looked". **Green is per case, and coverage is a second number**: since issue 1487 the
  verdict carries each case's `skip:` lines and check count and the trailer states
  `skips=`, so read `counted_failures=0 skips=N` together — N > 0 means rows that did not
  run, named in the blocks. Measured 2026-09-22 in a throwaway clone of `949cc585`:
  `cases=94 blocks=93 counted_failures=0 skips=8` — five are `test_op_annot`'s display-only
  rows on the headless arm; the other three belong to `test_input_line_inject_1352`,
  `test_preview_name_inject_1601` and `test_generator_paren_1604`, which self-skip their
  behavioural rows there because all three drive real Tk dialogs and neither `toplevel`,
  `winfo`, `bind` nor `event generate` exists under `--nogui`. ⚠ **`skips=` is not a constant to check
  against**: a suite registered in both lists reports its skip on one arm and its rows on the
  other, so the number moves with what is registered, not only with the environment.
- **Gate in a clone at a SHORT path, or T1 invents 11 failures.** `test_op_annot` (×4, on both
  arms) and `test_annot_hier_0911` (×3), plus their three `HARNESS: … did not complete cleanly`
  lines, compare a status-bar sentence that embeds an absolute path — and the product **elides** a
  sentence too long for the bar, deliberately (`test_op_annot` checks for the `...`, and its own
  comment records the defect the ellipsis fixed: *"the sentence died mid-token with no `...` to say
  it had"*). So those suites assume a scratch path short enough not to trigger it. Measured at
  `97766c66`, same commit, same two suites: a clone under the session scratchpad reaches **173
  characters** at `tests/headless/.scratch/_op_annot_<pid>/n_nd_empty/n_dev.raw` and gives
  `counted_failures=11`; the real tree reaches **92** and gives `ALL PASS (485 checks)` +
  `ALL PASS (15 checks)`; a clone at **84** re-gated clean at `cases=97 blocks=96
  counted_failures=0 skips=8`. The session scratchpad alone is ~100 characters before the clone
  name — most of the budget — so **the scratchpad is the wrong place for a gate clone**, and a red
  there is worth re-running short before it is worth diagnosing. Not a product defect: a user with
  a deep tree gets a correctly-elided message. Write-up:
  `doc/claude/issue_1607_batch/LEDGER.md`.
- **The banner rule lives in `tests/banner_rule.tcl`** (`banner_complete`,
  `banner_died`, `regression_case_failed`); `run_suites.sh` and `full_audit.sh` keep
  their own EREs (`/bin/sh` can't source Tcl), locked to it by section K of
  `tests/headless/test_audit_classifier.tcl`, except `full_audit.sh`'s prefix-anchored
  pass arm (issue 0805). A case passes only on **exit 0 AND a whole-line completion
  banner AND no column-0 death marker** (`--nogui --pipe` exits 0 on an uncaught Tcl
  error).
- `tests/xschemtest.tcl` is a broader functional/perf harness: from the repo root
  `./src/xschem --script tests/xschemtest.tcl`, then call `xschemtest`; `-d 3 -l log`
  logs allocations for leak checking. Run by hand it uses your real HOME and prints no
  note saying so.

### The throwaway test home (`t1_arm_home`, `tests/headless/test_home.sh`)
Every test driver (T1, each tcase run alone, the launchers below) runs with `HOME` set to
a fresh `${TMPDIR:-/tmp}/xschem-test-home.<pid>.XXXXXX`, deleted at exit by its creator,
sparing your clipboard, `~/.xschem/simulations` netlists and geometry.

* **Armed** (one `test home: throwaway … (your HOME is untouched; …)` line per run): T1
  and each tcase run alone with `tclsh` (`t1_arm_home`, on sourcing
  `tests/test_utility.tcl`); `run_suites.sh`, `full_audit.sh`, `gated_xschem.sh`, the
  standalone `test_*.sh` (via `xvfb_arm.sh --arm`), `test_devdisplay.sh`, each shell
  debt `owed.sh drain` runs, `run.sh`, `run_nogui.sh`, `lookshot.sh`,
  `tests/netlist_diff/netlist_diff.sh`, `tests/headless/wireedit/run_wireedit.sh`,
  `doc/claude/signal_browser_2pane_batch/xarm.sh`, `tools/migrate/test_ase_migrate.py`
  (`winshot.sh` builds into the gitignored `tests/headless/.winshot-cache/`). A nested
  driver reuses its parent's throwaway; only the owner deletes it.
* **Not armed:** the bare `./src/xschem … --script tests/headless/<t>.tcl` (D9: it keeps
  your real HOME; the `scratch.tcl` suites print a `note:` naming the armed spelling,
  other suites print nothing) and a hand-run `xschemtest.tcl`. **The armed spelling is
  `tests/headless/run_suites.sh [--nogui] <t>`.**
* **Enforced:** row **G2** of `test_home_isolation.tcl` (a T1 case) fails on any script
  that starts xschem (directly, via a variable, a PATH lookup or a Python/Tcl launcher)
  unless it is armed, runs inside xschem, or is on the path-keyed allowlist with a
  reason; a stale allowlist entry fails too. **A new launcher reddens T1 until you arm
  it** (`. test_home.sh; test_home_arm`, or source `test_utility.tcl`). G2 is textual;
  row **G2b** measures its blind spots.

| variable | meaning |
|---|---|
| `XSCHEM_TEST_HOME=real` | opt out: your real HOME, a loud `!! test home: REAL` banner on **every** run, header `home=real` |
| `XSCHEM_TEST_HOME=<abs dir>` | use that directory, never delete it (`home=custom`); refused if it resolves (symlinks included) to your real HOME, or its `.xschem` (two levels deep), `.cache` or `.claude` leads into it |
| `XSCHEM_TEST_KEEP_HOME=1` | keep the throwaway and print its path; `.keep` is written at arm time, so a killed run's is kept too |
| `XSCHEM_TEST_REAL_HOME` | **set by the arm**: your real HOME, for **read-only** fixture lookups (`test_real_home` in `scratch.tcl`: the fork ngspice, VCD fixtures, `test_launch_context`'s geometry); a row that finds nothing prints `skip:`, never a silent pass |

**What your real HOME still sees (D13.2):** the dev display itself, which writes
`~/.claude/xschem_dev_display` and `~/.cache/openbox` whether started by hand
(`devdisplay.sh start`) or by T1 (which attaches to or auto-starts it only if that state
dir exists), as a persistent display must outlive the run; likewise an existing
`~/.claude/gui_test_gate`. Neither is created for someone who lacks it (T1 then uses a
private Xvfb from `:100` and removes it). A `TMPDIR` inside your HOME puts the throwaway
there, and the banner says so instead of "untouched". Rules and reasons: D4–D20.

### The persistent dev display (`tests/headless/devdisplay.sh`)
Keeps GUI testing off your screen. A bare `./src/xschem --pipe -q --script
tests/headless/<t>.tcl` lands on it only if it inherits `DISPLAY=:99` (option 1 below).

```sh
tests/headless/devdisplay.sh start     # Xvfb :99 + openbox, ~0.3 s, idempotent
tests/headless/devdisplay.sh view      # x11vnc on localhost, to watch it
tests/headless/devdisplay.sh status|stop
```

- **The human does NOT want `DISPLAY=:99` in their interactive shell** (nor in
  `~/.bashrc`): a person launching xschem is launching it to use it. The armed drivers
  need nothing.
- For the assistant's own bare invocations: (1) **launch the session as `DISPLAY=:99
  claude`** (tool shells inherit it, the human's terminals don't; `~/.bashrc` can't,
  as it returns early for the non-interactive Bash tool shell); else (2)
  `tests/headless/devdisplay.sh exec ./src/xschem …`. **Only `run_suites.sh [--nogui]
  <t>` also arms HOME**: (1) and `devdisplay.sh exec` (which pins only `DISPLAY` and
  `GUI_GATE=0`) still write your clipboard, geometry and `simulations/`, so prefer it.
- `devdisplay.sh shellinit` is only for a terminal dedicated to hand-run tests; its
  export is conditional, as an unconditional one outlives the display (GUI programs then
  die with `cannot open display`). **The display does not survive a reboot**; re-run
  `start`.
- **`test_wave_markers` times out when `run_suites.sh` attaches to a dev display**
  (issue 1488, pre-existing): with `:99` up that `TIMEOUT` is not your change. It passes
  on the private `xvfb-run` display (dev display down); no knob goes private while
  `:99` is up.

### There are three X servers here, and `:0` is not the user's screen

| display | vendor string | what it is |
|---|---|---|
| `:0` | `Microsoft Corporation` | **Xwayland**, WSLg's own server |
| `$DISPLAY` = `<win-ip>:0` | `HC-Consult` | the **Windows X server** the user actually looks at, over TCP |
| `:99` | `The X.Org Foundation` | Xvfb, the persistent dev display |

- `$DISPLAY` comes from `~/.profile` (`export DISPLAY="$WINDOWS_IP:0"`); `~/.bashrc`
  would reset it to `:0` (`WAYLAND_DISPLAY` is set) but returns early for
  non-interactive shells, so tool shells keep the TCP display and interactive terminals
  may not. **Check `$DISPLAY`; don't assume.**
- **`AUDIT_DISPLAY=:0` exports the literal string `:0`**, not `$DISPLAY`: a `:0` figure
  taken through it, and every "run the suite on `:0`", means Xwayland. A **bare**
  `./src/xschem --script …` inherits `$DISPLAY`, the **user's real screen**: never run
  one there unless that screen is the point. A look debt "on the real VcXsrv screen"
  (issue 0413's) needs `AUDIT_DISPLAY=$DISPLAY` or a run by hand from a terminal.
- Do not "correct" WSLg to VcXsrv here: both exist, and the distinction is load-bearing.
- `_gate_enabled` is false on the dev display on purpose, or `_gate_attention` would
  relaunch the user's Pause panel where nobody can see it. `doc/claude/specs/dev_display.md`
  records two traps: under WSLg `/tmp/.X11-unix` lacks the sticky bit, so Xvfb binds
  only the abstract socket `@/tmp/.X11-unix/XN` and a `[ -S /tmp/.X11-unix/XN ]` poll is
  always false; and `xdpyinfo` on a dead display **hangs** on the TCP fallback, so check
  the listen state before probing.

### The owed ledger (`tests/headless/owed.sh`)
Record each debt on the user's attention the moment it is incurred; pay them in one batch.

```sh
owed.sh add rule  <id> [why] [--eyes]  # owes the USER a RULING (--eyes: needs pixels)
owed.sh add look  <what> [why]         # owes the USER's eyes (pixel deliverables)
owed.sh add suite <name> [why]         # owes a :0 run of a GUI feature's suite
owed.sh list | count | show            # `show` = the user's queue: rule + look
owed.sh drain                          # runs the SUITE debts, one batch, gate live
owed.sh clear <kind> <id>              # rule/look: ONLY when the USER says so
owed.sh add|clear … --repo <clone>     # ANOTHER clone's entry: path, basename, `here`
```

- **`rule` and `look` are the user's queue; `suite` is not.** A suite debt clears itself
  on a pass; a rule or look debt clears **only when the user says so**, and nothing
  converts one kind into another (`drain` never opens the other two lists).
- **One ledger (`~/.claude/xschem_owed/`) for every clone.** Entries are stamped with the
  filing clone; an `add` or `clear` that would write another clone's entry **refuses,
  exit 5**, saying what is there and what to type (`clear` also lists this tree's ids on
  that number), unless you pass `--repo <clone>` (issue 1400; `owed.md` §R6b). The stamp
  is an absolute path, so a moved or renamed clone sees its own entries as foreign;
  there is no re-stamp, only `--repo`.
- **An unstamped entry is evidence, not legacy**: another clone's older `owed.sh`
  overwrote something, so never claim it for this clone, whatever `owed.sh` offers. Find
  them with `/usr/bin/grep -L '^repo:' ~/.claude/xschem_owed/{rule,look,suite}/*`;
  `-h '^repo:' … | sort | uniq -c` splits entries by clone (re-run; never quote counts).
  **Read the mtimes first** (entries milliseconds apart are one filing), then
  `cleared.log` in the state dir root (append-only pre-images of this script's clears
  and overwrites; silence about a missing debt means the other clone did it). Known
  innocent: `rule/1357`, `look/hier_pdf_nav_1357_H6.…`, `suite/test_hier_pdf_links_1333`
  (one op-wcard filing) and `rule/1357@xschem-claude` (the collision guard working); a
  `ref:` to an op-wcard branch nobody here has is not evidence either.
- **Back up before any pass that touches the ledger** (`cp -r ~/.claude/xschem_owed …`).
  The guard lives in each clone's own `owed.sh` and a third clone would arrive
  unrepaired: re-check every clone's script rather than trust this paragraph.
- A rule entry is a pointer, not a copy: the options stay in
  `doc/claude/issues/NNNN-*.md`, and `add rule` resolves the path from the id. Spec:
  `doc/claude/specs/owed.md` (§6 for why `rule` exists).
- Never report a pixel deliverable "done" on a green suite: record a `look` and say
  "suites green, please look". Never leave an unratified user-visible decision only in a
  write-up: record a `rule`.

### The display arm: Xvfb by default (`tests/headless/xvfb_arm.sh`)
`full_audit.sh`, `run_suites.sh`, `gated_xschem.sh` and the window-mapping `test_*.sh`
suites run on the dev display if up, else a private Xvfb, never the screen they were
launched from (measured more reliable and faster than `:0`, and immune to the WSLg
Xwayland aborts that kill `:0` clients). Knobs: `AUDIT_DISPLAY=:0` (opt-in, Xwayland, for
its own defects; `=$DISPLAY` for the user's screen) or `=none` (GUI legs self-skip);
`AUDIT_SCREEN` (default `1920x1080x24`; **pin it**, never `1600x1200`, where
`test_fluid_bodyshove_guards_0132` fails); `AUDIT_XVFB_BASE` (first private display,
default 200, never below 100, since bare `xvfb-run -a` starts at the dev display's `:99`;
D17.8); `AUDIT_WM` (default `openbox`, `/usr/bin/openbox` 3.6.1 as checked 2026-09-17;
`none` = empty Xvfb).

- **`GUI_GATE=0` is forced on the Xvfb arm, not defaulted**: `_gate_enabled` only
  checks that `$DISPLAY` is non-empty, so `gate_start` → `_gate_attention` would move
  every session's live panel onto the invisible display and break Pause.
- Empty Xvfb doesn't reparent and silently no-ops `wm iconify`; a WM fixes both, so
  decoration, iconify, stacking and raise are no reason to use `:0`. **An absent WM
  falls back silently** (stderr warning only) and **`xfwm4` is not installed** (checked
  2026-09-17), so `command -v` a WM before naming it. A suite about reparenting, iconify,
  stacking or raise must report which WM was live, naming `AUDIT_WM=openbox` when it
  needs certainty. WM measurements from before 2026-08-23 were WM-less; re-measure.
- **Xvfb is not a substitute for `:0`** for a human eyeball or Xwayland quirks (one
  `wm geometry` gives 3 `<Configure>` events on `:0`, 1 on Xvfb). **Run a GUI feature's
  suite on `:0` once before calling it done**, and treat a `:0`-only bug as a test
  defect too: force the race deterministically (`test_calc_skeleton` S12).

### GUI-test control gate (`tests/headless/gui_gate.sh`)
Under a real/WSLg `$DISPLAY` a suite pops a control panel
(`tests/headless/gui_gate_widget.tcl` via `wish`): Proceed / Snooze 5·15·30 min before,
Pause/Resume and Stop during, since a GUI suite otherwise floods the display. It lives in
the harness: **do NOT reintroduce it as a Claude Code settings hook** (one died silently
with a `settings.local.json` rewrite). Control dir `~/.claude/gui_test_gate/` is shared
by every session, worktree and subagent, so one Pause pauses every suite. It **fails
open** (no `DISPLAY`, `GUI_GATE=0`, or a closed panel). Spec:
`doc/claude/specs/gui_test_gate.md`.

- The panel should be rare (it guards `AUDIT_DISPLAY=:0` runs); one popping for a
  routine suite means something bypassed `xvfb_arm.sh`.
- Press **`Allow 30m` / `Forever`** once rather than Proceed per run (each run otherwise
  costs a click, or a 2-minute autostart wait if nobody is there), or approve before
  launching a batch; Pause and Stop keep working.
- Enrol runs through `run_suites.sh` (preferred) or `gated_xschem.sh`, a drop-in for
  `./src/xschem`. A bare `./src/xschem` loop is listed `UNGATED`, and only **`Halt N
  xschem`** (SIGSTOP, resumable) reaches it.

### A hand-rolled suite loop also forfeits the timeout, and a stall then has no upper bound
- `run_suites.sh` wraps every arm in `timeout` (`SUITE_TIMEOUT`, default 200 s) and
  reports `TIMEOUT | <name> run i/n (after 200s)`; `full_audit.sh` uses `AUDIT_TIMEOUT`
  (default 300 s) and a `crash/timeout` column in `SUMMARY:` (a startup Tcl error popup
  hangs rather than failing). A private loop has neither
  (`doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md`).
- **Use `run_suites.sh`; extend it rather than replacing it.** Otherwise put
  `timeout <n>` on **each command** (rc 124 is a result) and a self-announcing deadline
  on every waiting loop. **A stall must be a named outcome** (`PASS` / `FAIL` /
  `TIMEOUT` / `NORESULT`), never silence. Give a suite's first run on an arm nothing has
  exercised a timeout, and watch it.
- Two bounds, neither replacing the other (issue 1403). **T1:** `t1_timeout`
  (`T1_CASE_TIMEOUT`, default 900 s, `0` disables) puts `timeout --kill-after=20` on all
  four `exec` sites and `t1_why` scores rc 124 as a counted `FAIL` saying `TIMED OUT`;
  on the display arm it goes *inside* `devdisplay.sh exec`, or xschem is orphaned on
  `:99`. **In-suite watchdog:** every suite sourcing `tests/headless/scratch.tcl`, bare
  runs included, arms `XSCHEM_SUITE_WATCHDOG_MS` (default 900000, above both drivers'
  caps; `0` disables), which exits 124 printing `###### WATCHDOG TIMEOUT ###### <suite>
  exceeded <n>ms -- last output: <line>` on both streams.
- **The watchdog is not a general timeout**: an `after` timer fires only in the event
  loop, so it catches a `vwait`/`tkwait` hang but not a blocking `exec` or busy Tcl loop
  (row W13 of `test_suite_watchdog_1403.tcl`). Bound those externally.
  ⚠ **THERE IS A THIRD BLIND SHAPE AND NEITHER W13 NOR `scratch.tcl` RECORDS IT: `update
  idletasks`.** Measured 2026-10-03: it services *idle* events only and **never runs timer
  callbacks**, so a loop spinning on `update idletasks` is invisible to the watchdog —
  `fired=0` after 200 ms of it against `fired=1` after a single full `update`. That also
  explains a confusing observation: a Tk suite can sit at a 1 ms budget without the
  watchdog firing on its *normal* run while the same suite's `tkwait` hang fires every
  time. **`update` arms it; `update idletasks` does not.** All three blind shapes need an
  external bound, not a bigger budget.
  ⚠ **And a hand-rolled deadline NAMES THE OUTCOME WRONGLY, which is its own defect.**
  Measured: `after <n> {puts "deadline"; exit 1}` does stop the stall, but `t1_why` scores
  rc 1 as *"crashed, aborted mid-script, or a check failed"* while rc **124** is *"TIMED
  OUT"*, and `run_suites.sh` likewise scores FAIL rather than TIMEOUT; it prints on stdout
  only and names neither the suite nor where it stopped. **Arm `scratch.tcl`'s watchdog
  rather than inventing a deadline**: it exits 124, prints on both streams, and names the
  file plus the last row it got past. ⚠ Conversely an **unbounded** stall killed from
  outside takes the emergency-save path and prints `FATAL: signal 15`, which
  `banner_died` matches — so it is scored a **death**, not a timeout, and the verdict
  misdescribes it.
  ⚠⚠ **AND WHEN A ROW WAS FINALLY WRITTEN TO ASSERT THIS, IT FOUND THREE REGISTERED T1 CASES
  WITH NO STALL BOUND AT ALL.** Row **`W20h`** of `test_suite_watchdog_1403.tcl` (2026-10-03)
  derives the population — a registered `hcases`/`dcases` entry whose file issues `vwait`,
  `tkwait`, `update`, `toplevel` or `grab` **in command position**, 26 of 104 — and derives
  the predicate over each member's transitive `source` closure. Its first run reddened on
  `test_fluid_editing`, `test_headless_guards_xarm_1492` and `test_selflog_grep_guard`:
  each reaches the event loop and arms **no** deadman, so a hang in any of them had no
  bound but whatever driver happened to wrap it. **They were given the bound rather than the
  instrument narrowed to fit the tree** — narrowing was the available alternative and is
  exactly the rot the row exists to prevent. `FLOOR: 32` → `40`, a **ratchet, not a baseline**.
  ⚠ Two scanning lessons, both measured and both load-bearing: **the scan must be
  command-position**, because a bare-word scan reports `test_callback_argc` (its only
  `toplevel` is inside a check's detail *string*) and `test_fluid_editing` (its only `grab`
  is the English word, *"tolerance grab of an OFF-GRID endpoint"*); and **`update` belongs in
  the verb list**, because without it the population misses `test_calc_widgets` and
  `test_calc_buffer` — which drive Tk through `calc::*` and issue no `toplevel` of their own —
  leaving the hole two-thirds open. Widget-class names (`label`, `text`, `entry`, `place`,
  `raise`) must stay **out**: `test_calc_scratch_reuse` scans as a `label` user purely
  because of `foreach {label rpn ds} {`.
- **Do not gate a whole report on the last check**: report (and where appropriate
  commit) the verified majority, naming what is outstanding.

## Architecture

### The `xctx` global context
Almost all program state hangs off a single global `Xschem_ctx *xctx` (defined in
`xschem.h`, ~`Xschem_ctx` struct). It holds the current schematic's object arrays
(`wire`, `inst`, `sym`, `rect[layer]`, `line[layer]`, `poly`, `arc`, `text`),
the hierarchy stack (`sch[CADMAXHIER]`, `sch_path[]`, `currsch`), zoom/pan state,
selection (`sel_array`), spatial hash tables, undo slots, highlight/node tables, and
the drawing GCs/colors. When reading or modifying behavior, the relevant fields are
usually grouped in the struct with comments pointing to the owning `.c` file
(e.g. `/* move.c */`, `/* callback.c */`). Multiple open windows/tabs each have their
own context — see `get_save_xctx()` / `get_old_xctx()` and the tabbed-interface logic
in `xinit.c`.

Core object types (`xWire`, `xRect`, `xLine`, `xPoly`, `xArc`, `xText`, `xInstance`,
`xSymbol`) are all defined together near the top of `xschem.h`.

### The `xschem` Tcl command — central dispatcher
The C core exposes essentially all functionality through one Tcl command, `xschem`,
registered in `xinit.c` (`Tcl_CreateCommand(interp, "xschem", ...)`) and implemented
by the giant dispatcher `scheduler()` in `scheduler.c` (function `xschem(...)`). Tcl
scripts, menus, keybindings and tests all drive the editor by calling
`xschem <subcommand> ...` (e.g. `xschem load`, `xschem netlist`, `xschem hilight`,
`xschem get xorigin`, `xschem callback ...`). **When adding a new user-facing
operation, you add a branch in `scheduler.c` and usually wire it up from Tcl** rather
than inventing a new C entry point. GUI events are funneled in as
`xschem callback <win> <event> ...` → `callback()` in `callback.c`.

### Layering: C engine ↔ Tcl GUI
- `src/xschem.tcl` (~12k lines) is the Tcl GUI: menus, dialogs, simulation launchers,
  preferences. Many config variables are deliberately **mirrored between C and Tcl**
  (search `MIRRORED IN TCL` in `xschem.h`) — keep both sides in sync when changing one.
- Other `.tcl` files are loadable helpers (`mouse_bindings.tcl`, `place_pins.tcl`,
  `create_graph.tcl`, `*_backannotate.tcl`, custom menu/button hooks).
- The C side reads/writes Tcl variables via helpers like `tclgetvar`,
  `tclgetboolvar`, `tcleval`.

### Drawing
`draw.c` is the rendering core over Xlib (with `#if HAS_CAIRO` paths for text/images;
`svgdraw.c` and `psprint.c` produce SVG and PostScript/PDF output). `font.c` holds the
vector font. Spatial hash tables in `xctx` (`*_spatial_table[NBOXES][NBOXES]`)
accelerate hit-testing and selection.

### Netlisting
`netlist.c` is the shared hierarchy traversal and node-naming machinery; per-format
backends are separate files: `spice_netlist.c`, `spectre_netlist.c`,
`vhdl_netlist.c`, `verilog_netlist.c`, `tedax_netlist.c`. Label/bus expansion goes
through the bison/flex parsers. Highlighting and node tracing live in `hilight.c`,
`findnet.c`, `node_hash.c`.

### Editing pipeline
`actions.c` (largest file — high-level edit ops), `move.c`, `paste.c`, `clip.c`,
`select.c`, `editprop.c` (property/attribute editing), `store.c` (object allocation),
`save.c` (the `.sch`/`.sym` file format I/O), `check.c` (ERC/symbol consistency),
`in_memory_undo.c` (undo can be on-disk or in-memory; chosen via the `push_undo`/
`pop_undo` function pointers in `xctx`).

### awk scripts
The many `*.awk` scripts in `src/` are import/convert/flatten utilities (e.g.
`gschemtoxschem.awk`, `make_sym_from_spice.awk`, `flatten.awk`). They are part of the
shipped toolchain, invoked from Tcl, not build-time codegen.

## Symbol & schematic libraries
`xschem_library/` holds the standard device symbols (`devices/`) plus example
designs and generators. The library search path is configured in `Makefile.conf`
(`xschem_library_path`) and overridable in `~/.xschem/xschemrc` or a `./.xschemrc`.
`.sym` (symbol) and `.sch` (schematic) share the same text record format handled by
`save.c`; the format version is `XSCHEM_FILE_VERSION` in `xschem.h`.

## Conventions
- C89 throughout; the codebase targets both Unix and Windows (`XSchemWin/` holds the
  Windows config). Guard platform code with `__unix__`.
- Memory tracking: allocations use id-tagged wrappers (`my_malloc`, `my_realloc`,
  `my_strdup`, etc.) whose first arg is the placeholder macro `_ALLOC_ID_`. The
  `create_alloc_ids*.awk` / `get_malloc_id.awk` scripts rewrite those placeholders
  into unique numeric ids for leak tracing — write `_ALLOC_ID_`, don't hand-number.
  Debug logging via `dbg(level, ...)`.

## AI / planning docs
Design and working notes live under `doc/claude/` (not installed — `doc/Makefile`
ships only `*.svg/*.html/*.css/*.png`): `doc/claude/specs/` (feature specs),
`doc/claude/issues/` (numbered issue tracker, `NNNN-*.md`), `doc/claude/code_analysis/`
(analysis & decision write-ups), `doc/claude/suggestions/` (session prompts, plans), and
`doc/claude/FAQ.md` (a running design Q&A, newest entries on top).
Source comments reference these by their full path (e.g. `see doc/claude/specs/foo.md`).

**Do not write down a number nothing re-checks.** Two conventions out of the 1606 and 1608
batches, both of which cost four to six hardening rounds to learn and are fenced in
`tests/headless/test_snprintf_fmt_1608.tcl`'s header as limits `L9` and row `X1`:

- **A comment must not quote a count a command produces over the tree's own text.** One
  sentence there shipped wrong three times, each time inside the revision written to fix the
  previous one: it quoted `grep -c '#pragma'` as 0, then as 1, and the truth was **3** —
  because `grep -c` counts *lines* and the correcting rewrite had spread the word `#pragma`
  across three lines of its own sentence. The comment became its own counterexample. Either a
  **row** asserts the count, where it is re-measured every run, or the sentence drops the
  number. Same rule for any figure the instrument cannot reproduce: a `--rcfile` probe's
  integer is `va_arg` on a vararg nobody pushed, and quoting it gave 32, 112 and 24 on three
  retries. Quote the shape, not the number.
- **A test row's NAME must describe its method, not its coverage**, and cross-references must
  be checked rather than trusted. Rows called "every write to X" and "every indirect-precision
  sprintf in the tree" were each defeated by one whitespace variant or a `#define` alias, and
  **five shipped source comments cited rows that do not exist**. Row `X1` now derives the real
  row set from the suite's own `check` calls — a hand-kept list is the same defect one level
  up — and catches an id hidden in a block comment, a string literal, a `#if 0` region,
  another suite, or backticks.
- ⚠⚠ **A FIXTURE CAN MAKE A ROW GREEN ON BROKEN CODE, WHICH IS THE MIRROR OF THE LEVEL TRAP AND
  HAS NOW COST THIS TREE BOTH WAYS.** Measured 2026-10-03 (issue **1643**): row `WD8` of
  `test_calc_wave_dest.tcl` — the end-to-end row cited as proof the wave destination worked —
  compared a Y column read back out of the destination, element-wise, with `near` at a **relative**
  1e-7, driving `v(sq)` at its own level of `1/3`. There the two values it compares are
  `0.31666666666666676` **twice**: the same double, relative spread **exactly zero**. So a producer
  writing `y[0]` into both points, writing the column **reversed**, or writing a **constant**, all
  passed — confirmed by attack. Exactly one series on the committed fixture discriminates
  (`dutyCycle` on `v(lp)`, relative 1.83e-4); `riseTime` per edge on `v(sq)` agrees to ~4e-15.
  The other direction is already recorded as `DESTINATION_CONTRACT.md` §11(c): a level of 0.5 put a
  quantity at 2.2e-16 **inside** a 1e-12 door, making a discrimination row **red on correct code**.
  **One rule, two faces: a row that compares two numbers must be driven on inputs whose numbers
  differ by more than its own tolerance, and that must be MEASURED when the row is written.** Carry
  an explicit distinctness leg so the row cannot go vacuous again if a fixture is regenerated —
  the non-vacuity discipline the derivation rows already apply to populations, applied to values.
  ⚠ And the first report of it **quoted the wrong level** (1.8e-15 at 0.5, which `WD8` does not
  use), understating the defect; that was the fourth quoted-rather-than-derived figure to be wrong
  in one batch.
- ⚠⚠ **A COMMIT THAT LANDS HALF A FEATURE CAN BE A REGRESSION, AND "FENCEABLE ON THE COUNTED ARM"
  IS NOT THE AXIS TO SPLIT ON.** Measured 2026-10-03. Stage J1 was deliberately narrowed to a
  producer, on the sound ground that the surface half can only be observed on a gate's display arm
  (`calc::fn_measure` and `calc::buf_set_number` both return early on `calc::has_win .calc.buf`, so
  under `--nogui` both are no-ops). A crew then measured the consequence: on a producer-only tree
  the click pasted the measured **list** over the user's expression, silently, because the success
  arm was unconditional and `buf_set_number` has no numeric check. **That is worse for the user
  than the refusal it replaced**, on the branch they publish. The split that works is between the
  **decision** and the **act**: the routing predicate was factored into a pure proc with no Tk, so
  it gates on the counted arm, while the act — the buffer really being left alone, the sentence
  really reaching the widget, the undo still being one step — is display-only and **declared**.
  **Before narrowing a unit, ask what the narrowed tree DOES, not only what it can prove.**
- ⚠ **A KEY AND THE ROW THAT ASSERTS ITS KEY SET MUST LAND IN ONE COMMIT.** Measured in both
  directions at one site: a row asserting an answer dict's key set **exactly**, ahead of the
  producer that sets the new key, is a gate red for a key nothing sets; the producer ahead of the
  row is a gate red for a key the row does not expect. An exact key-set assertion is the right
  shape — it is what catches a wiring that puts a live value in a retired key — but it makes the
  widening a **sequencing** obligation. Say so in the band's own comment, or somebody meets it as
  a gate red and weakens the row to clear it.
- ⚠ **A WRITE-UP FILED UNDER `doc/claude/issues/` WITH AN `NNNN-` NAME REDDENS T1, EVEN IF IT IS
  NOT AN ISSUE.** Row `D9` of `test_issue_stamp` fails on any `doc/claude/issues/NNNN-*.md` with no
  `**STAMP:**` line, and grandfathering is by **exact file name**. A crew receipt saved there as
  `1641-receipt-….md` produced `ISSUE-STAMP: 1 problem(s)` immediately; moving it to
  `doc/claude/code_analysis/` gave `ok (0 problems)`. Receipts and analyses go in
  `doc/claude/code_analysis/` or a batch's own `receipts/`, never in the issues directory. Check
  with `tclsh tests/headless/issue_stamp.tcl` after adding any file there.
- ⚠ **A fence keyed to a symptom dies quietly when something else cures the symptom.** Two
  rows asserted the *absence* of a malformed output; a later change stopped producing that
  output and both silently stopped fencing anything, with only non-behavioural rows still
  reddening. Nothing detects this automatically. Prefer asserting the correct shape over
  asserting a wrong one's absence, and re-run the site-by-site sabotage after any change in
  the same file.
- ⚠⚠ **A COMMENT BETWEEN TWO `switch` PATTERNS IS A PARSE ERROR THAT `info complete` CANNOT SEE.**
  Measured 2026-10-02 in `calc::cross_msg`: a four-line explanatory comment placed between two
  `switch` arms left the braces perfectly balanced and **`info complete` answering `1`**, while Tcl
  raised *"extra switch pattern with no body, this may be due to a comment incorrectly placed outside
  of a switch body"* out of **every** sentence in the catalogue — **34 rows red at once**, three of
  them in a different suite. A comment is safe above a proc and fatal between two `switch` arms, and
  **nothing structural distinguishes them**. So the brace-balance scan that this tree's Tcl work
  relies on (adopted after a literal `{` in a comment silently unbalanced two files, once inside the
  comment warning about it) is **insufficient on its own**: it catches the unbalanced-brace shape and
  is blind to this one. The only confirmation is behavioural — exercise every arm of the `switch` and
  see that none raises. Put explanatory prose **above the proc**, never between patterns.
  ⚠⚠ **AND THE ONE ROW THAT CONFIRMS THIS BEHAVIOURALLY HAD ALREADY ROTTED, WHICH IS THE WHOLE POINT
  OF THE RULE TWO BULLETS UP.** Measured 2026-10-03: `test_calc_wave_dest`'s arm-sweep row — the
  *only* behavioural confirmation anywhere that a `switch` catalogue still parses — drove a
  **hand-kept list of 24 message kinds against a proc that had 31 arms**. The seven it never asked
  about (`badxaxis` and six `dest*`) were added by the very stage that wrote the row. Its name claimed
  *"every arm this stage touches"*, which is **coverage, not method**, so nothing could detect the
  drift: the row stayed green while silently measuring 24/31. Replaced by a **derivation over the
  proc's own switch patterns** plus a non-vacuity row, giving `ok=31 raised=0`. **A hand-kept list is
  the same defect one level up** — exactly what row `X1` of `test_snprintf_fmt_1608.tcl` exists to
  prevent — and a fence against a parse trap is worth nothing if it only exercises the arms that
  existed when it was written.
  ⚠⚠⚠ **AND THE TRAP IS PARITY-DEPENDENT, WHICH THE WARNING ABOVE STATES AS AN ABSOLUTE AND SHOULD
  NOT.** Measured 2026-10-03 in `calc::fn_argspec`, both directions, same site:

  | comment between two patterns | words, `#` included | result |
  |---|---|---|
  | two lines, 26 words | **EVEN** | `ALL PASS (158 checks)` — **a complete no-op** |
  | `# R415 applies` | **ODD** (3) | **18 rows red at once** |

  The mechanism: `switch`'s single trailing argument is parsed as a **Tcl list**, and every word of
  the comment becomes an element. An **even** word count re-pairs the list so every real pattern
  keeps its real body and the comment is swallowed as one harmless pattern/body pair; an **odd**
  count shifts the pairing by one and Tcl raises out of every arm.
  **So the consequences are worse than "a comment there is fatal", not better.** A comment in that
  position can sit green for months and **detonate the moment somebody edits a single word into or
  out of it** — including into the comment itself, which is how this class keeps recurring (CLAUDE.md
  already records a literal `{` unbalancing a file *from inside the comment warning about it*, and a
  suite author hit a bare `}` twice on this batch, the second time inside the comment warning about
  the first). **A green run proves only that the word count is even**, never that the comment is
  safe. The rule stands unchanged — prose above the proc, never between patterns — and the only
  confirmation remains behavioural: exercise every arm, with the arm set **derived from the proc's own
  switch argument**, and see that none raises.

**Cite code by symbol (proc or function name), not by bare `file:line`**: coordinates
rot, identity holds (`src/op_annot.tcl` does this on purpose). A line number that cannot
be avoided needs the commit it was measured at; re-grep before quoting it again.

**Issue numbers: `doc/claude/issues/NUMBERING.md` is authoritative about what a number
MEANS, and blind to what is free.** Tracked per branch, its `next free number` line is
a per-clone pointer, so two clones here have minted the same numbers for different
defects (issue 1400). Minting takes **two** checks, neither substituting for the other:
the **candidate** from this clone's `NUMBERING.md` (its pointer, and the **reserved-block
table at its head**: a band is a range no per-number grep can see), then a grep proving
no *other* checkout took it:

```sh
N=doc/claude/issues/NUMBERING.md                   # this clone's pointer AND bands
n=$(/usr/bin/grep 'next free number' "$N" | /usr/bin/grep -v '~~' | tail -n1 |
    /usr/bin/grep -o '[0-9][0-9]*' | tail -n1); echo "candidate $n"   # or n=1550
awk -v n="$n" -F'|' '/^\| \*\*[0-9]/{gsub(/[^0-9]/," ",$2); split($2,b," ")
  if (n>=b[1] && n<=b[2]) print "!! "n" is in RESERVED band "b[1]"-"b[2]}' "$N"

set -- ~/dev/*/doc/claude/issues/NUMBERING.md      # EVERY clone on this machine
[ -e "$1" ] || echo "!! glob matched nothing -- fix the path, not the number"
ls ~/dev/*/doc/claude/issues/"$n"-* 2>/dev/null    # a file in ANY checkout here
/usr/bin/grep -lw "$n" "$@"                        # or a reservation with no file
```

- A free candidate prints only this clone's `NUMBERING.md` (its pointer line names it);
  an issue file or any other `NUMBERING.md` means taken (a reserved number often has no
  file yet). `n=1550` shows the band check catching what every grep misses.
- `~/dev/*` is every checkout today; add any clone living elsewhere. `[ -e "$1" ]`
  catches a glob matching nothing (grep would exit 2 with silent stdout, reading "free").
- **Use `/usr/bin/grep`, never the bare `grep`**: here `grep` is a function routing to
  ugrep, which misses forms like `-lE "(^|[^0-9])$n([^0-9]|$)"`.
- **`1500–1599` is reserved for the op-wcard branch: after 1499 the next number here
  is 1600.** `0500–0599` (fluid-editing, i.e. this branch) is a head-table band too;
  skip it like the rest. Trust the head table over any number quoted elsewhere,
  including here. Record the new number in `NUMBERING.md` in the same commit; a
  collision costs a renumbering.

**A NEW issue file must open with a valid stamp line, or T1 goes red.** Row `D9` of
`test_issue_stamp` (a T1 case) fails on an issue file with no `**STAMP:**` line unless
its **exact file name** is in `tests/headless/issue_stamp_baseline.txt` (grandfathering
is by name, not number). The line sits in the first 12 lines, on one physical line;
`tree=` is a commit abbreviation with an `a`–`f` letter (lengthen an all-decimal one)
that, in a full clone, resolves **to an ancestor of HEAD** (D15.4), not to a commit only
on another branch or clone, or amended away. Grammar and vocabulary:
`doc/claude/specs/issue_stamp.md` §2. Check with `tclsh tests/headless/issue_stamp.tcl`
→ `ok (0 problems)`. A stamp-shaped example anywhere else in an issue file is itself a red.

**Wiring work**: before touching anything that creates, moves, deletes, or reroutes wires
(move.c, the fluid passes, trim/break/merge, connected drag/rotate/flip), read
`doc/claude/WIRING.md` — data model, END pipeline, pass contracts, landmines, open risks.
Keep it updated when fixing wiring issues.
