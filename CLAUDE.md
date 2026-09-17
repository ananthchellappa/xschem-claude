# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
  and `config.h` are generated, gitignored, and have **no self-regeneration rule**, so
  a corrected `Makefile.in` sits happily next to a stale `Makefile` and `make` never
  notices. The trap is invisible in-tree — `XSCHEM_SHAREDIR` resolves to `src/`, so a
  helper that was never added to the install list is still found — and fatal once
  installed: `make install` then ships an `xschem.tcl` that sources a file it did not
  install, and the installed binary **segfaults at startup** (exit 139, via issue 0423,
  where `Tcl_AppInit()` continues after a failed `source`). Issue 0424 is the measured
  case: 275 in-tree checks green, installed binary dead. Verify with
  `grep -c <newfile> src/Makefile` — expect 2, an install line and an uninstall line.

### Generated parsers (do not hand-edit the .c)
- `expandlabel.c`/`expandlabel.h` ← bison from `expandlabel.y` (bus/label expansion)
- `eval_expr.c` ← bison from `eval_expr.y`, prefix `kk` (expression evaluator)
- `parselabel.c` ← flex from `parselabel.l`

## Tests

Regression tests live in `tests/` and are driven by Tcl, comparing generated output
against golden files.

```sh
cd tests
tclsh run_regression.tcl        # runs all cases: create_save, open_close, netlisting
```

- Each case is a `<name>.tcl` script; `run_regression.tcl` execs them and greps
  `results.log` for `FAIL` / `GOLD?` / `FATAL`. To run one case, source its script
  directly (e.g. `tclsh netlisting.tcl`).
  ⚠ **YOUR run's answer is `tests/results.<pid>.log`, not `results.log`** (changed
  2026-09-17, harness-concurrency batch). Every run fills its own per-run verdict and
  **copies** it to the canonical `results.log` at the end, so `results.log` holds
  whichever run finished **last** — which need not be yours if anyone else was running
  T1 in this tree. The per-case logs work the same way: `<name>.<pid><suffix>`,
  published back to the canonical `<name>.log` after that case is scored. Running one
  case by hand is unchanged (`cd tests && tclsh open_close.tcl` still writes
  `open_close.log`); the pid tag rides in `T1_LOG_TAG` and an unset tag means the old
  name.
- Tests invoke the built binary headless via `xschem ... --pipe -q --script <file>`.
  `tests/test_utility.tcl` resolves it as **`$XSCHEM` → in-tree `src/xschem` →
  `PATH`**, so an uninstalled dev tree works out of the box (issue 0147 — it used
  to be a bare `xschem`, and with nothing installed the entire suite silently
  no-op'd while still printing a plausible `results.log`).
- **⚠ A BARE `xschem` ON `PATH` IS NOT THIS TREE.** It resolves to
  `/usr/local/bin/xschem`, which on this machine is **3.4.6 from Jan 2025**. It
  is not merely stale — it predates issue 0119, so it has **no `no_recent_files`
  gate at all**: `--pipe`, `--nogui` and `--norecent` do not stop it rewriting
  the user's `~/.xschem/recent_files`, because it has never heard of them. One
  run of it through a tree with no built `src/xschem` is what emptied the user's
  `File > Open Recent` (issue **0924**). The conf is now written in both the
  modern and the legacy spelling so the round trip is lossless, but the rule
  stands: **always give the binary a path** — `./src/xschem`, `$XSCHEM`, or
  `devdisplay.sh exec ./src/xschem`. Never a bare `xschem`.
  ⚠ **Measured 2026-09-17: nothing is installed at that path any more.**
  `/usr/local/bin/` is **empty**, `/usr/local/share/xschem` is gone, and
  `command -v xschem` exits **1** — so the 3.4.6 above can no longer be verified,
  and a bare `xschem` today fails loudly (`command not found`) instead of
  silently running a Jan-2025 build. **That re-arms this rule rather than
  retiring it:** one `make install` puts a binary back on PATH the same minute,
  and `test_utility.tcl`'s third fallback *is* PATH. Give the binary a path
  anyway — and read a `xschem: command not found` in an old transcript as this
  state, not as a broken harness.
- **`create_save`, `open_close` and `netlisting` have no committed `gold/`
  baseline**, so they can only report `NOGOLD` — they run the cases and produce
  `<case>/results/`, but verify nothing until someone promotes a baseline. The
  trustworthy signal is the headless cases (which do have
  `tests/headless/gold/`), or running one directly:
  `./src/xschem --nogui --pipe -q --script tests/headless/<t>.tcl`.
- **Reading `results.log`:** a `FAIL` ending a line, `GOLD?`, `RESULT?` or a
  leading `FATAL` is counted.
  ⚠ **READ THE TRAILER FIRST — new 2026-09-17, and it supersedes most of what
  follows.** Every verdict now opens with `T1-RUN-BEGIN pid= script= start=
  planned_cases= verdict= canonical=` and closes with `T1-RUN-END pid= cases= blocks=
  counted_failures= elapsed= end=` (`run_regression.tcl:694` and `:916`), written on a
  channel that is `fconfigure`d `-buffering line` so the header survives a kill. **A
  verdict with no `T1-RUN-END` line did not finish, whatever its contents**, and one
  whose `T1-RUN-BEGIN` names a pid or a start time you do not recognise is somebody
  else's answer or a fossil. Neither sentinel can match a counted shape, deliberately
  — row `V4a` of `test_regression_concurrency_1476.tcl` holds that by measurement — so
  they never manufacture a red. The trailer also **states** the arithmetic the rest of
  this bullet makes you do by hand: `cases=`, `blocks=`, `counted_failures=`.
  ⚠ **AND `results.log` IS THE ONLY PLACE THE ANSWER IS.** `run_regression.tcl`
  prints only `Start …` / `Finish …` to stdout, so grepping its stdout capture for
  `FAIL` finds nothing on a run with reds in it, and **its exit code does not carry
  the verdict**: a run that completes exits 0 whether every case passed or every one
  failed. ⚠ **This bullet said "rc 2 means nothing ran" for part of 2026-09-17, and
  that is now FALSE — the refusal it described was deleted the same day.** The text
  *it* replaced said "exits 0 whatever happens"; the refuse-and-`exit 2` path existed
  only between the two harness-concurrency commits and is gone (`/usr/bin/grep -n
  'exit 2' tests/run_regression.tcl` finds no such exit). **No run is refused and no
  run exits 2 on account of another run.** So rc 0 still tells you nothing about what
  the run found, and rc 2 now tells you nothing either — it is the **trailer**, not the
  exit code, that says whether a run completed. Measured 2026-09-13 (issue **1456**): four
  consecutive T1 runs were reported as *"rc 0, zero counted failures"* from a grep
  of the stdout capture while `results.log` held **six** counted lines — three suites
  that emit no completion banner, plus a flaky row. Read the file, then name any case
  whose `Total num fail:` is not 0. `couldn't execute "xschem"` or `exit 127` anywhere
  means the binary never launched and *nothing in that run is meaningful*
  (issue 0016 Part 4 distinguishes this from the benign rc=10 fall-through).
  ⚠ **AND A STALE `results.log` READS EXACTLY LIKE A CLEAN SWEEP.** Invoke it as
  `cd tests && tclsh run_regression.tcl`, the spelling under "Build & run" above —
  **never `tclsh tests/run_regression.tcl` from the repo root.** Measured
  2026-09-15: run that way it **exits 1 without running the cases** and leaves the
  *previous* run's `results.log` byte-for-byte in place, so the next reader counts
  a sweep nobody took. Note how cleanly this defeats the rule above it: you are
  told to ignore the exit code and read the file, and here the nonzero exit is the
  **only** signal that the file is a fossil. Two receipts in the ASE-L batch and
  one commit message carry a case count obtained this way: **84, at a time when the
  tree ran 83.** ⚠ **That coincidence has since LAPSED, and the lesson has not.** When
  the tree ran 84 the fossil's number was *indistinguishable from today's correct
  one*; the tree now runs **85**, so a stale log reading 84 finally looks stale. **Do
  not read that as the trap closing** — it reopens the instant the count next moves,
  and the next fossil will carry 85. The durable half is the sentence below, not the
  digit: only the mtime, and now `T1-RUN-BEGIN`, ever said otherwise. — the fossil
  number was *indistinguishable from today's correct one*, and only its mtime ever
  said otherwise. A plausible value is not a measurement.
  ⚠ **"Only its mtime" stopped being true on 2026-09-17.** `T1-RUN-BEGIN` names the
  pid and the wall-clock start time, so a fossil is now self-identifying **from
  content** — which is the only thing the reader of a pasted log actually has. The
  nonzero exit is still the signal that *this* invocation never ran; the header is
  what tells you how old the file in front of you is. The trap is unchanged; the
  detection is no longer forensic.
  ⚠ **AND THE CASE COUNT IS NOT THE LOG-LINE COUNT** — a correction to this very
  paragraph, measured 2026-09-15. It said the tree has "82", which was itself wrong
  for the *same* reason the 84 was: 82 is the number of `Total num fail:` lines, and
  `results.log` carries **one fewer than there are cases** by design (the bullet
  below: `xschemtest.tcl` logs only when it fails). **Count `Start`/`Finish` pairs
  for cases; count log lines only for failures.** Two independent passes reached
  "82" by conflating them, so this is a trap with a track record, not a one-off slip.
  **The run is 85 cases and 84 log lines** as of 2026-09-17 (it was 84 and 83
  earlier the same day — see the registration note below), and the arithmetic is
  written out here because this paragraph has already been wrong twice in exactly
  this way — swap the digit and the next reader inherits the conflation again:

  ```
    70  hcases      (run_regression.tcl:27-94, entries not lines)
  + 11  dcases      (:310-319, the display arm)
  +  3  tcases      (:23 — create_save, open_close, netlisting)
  +  1  xschemtest.tcl
  = 85  Start/Finish pairs          84 `Total num fail:` lines
  ```

  ⚠ **84 → 85 on 2026-09-17, second registration of the day**, when the
  issue-tracker batch added `headless/test_issue_stamp` to `hcases` (70th entry).
  **Every number here was read off the artefact, not computed**: the trailer
  `T1-RUN-END … cases=85 blocks=84 counted_failures=0 elapsed=380s` at
  `1acae0b0`, `Start`/`Finish` counted at **85/85**, and `wc -l` run once. The
  driver's own `grep -cE '\.log$'` answered **85** block headers in the act of
  checking this — because `T1-RUN-BEGIN` **ends in** `canonical=results.log`.
  **`blocks=` from the trailer is authoritative; a pattern that can match the
  header is not.** That is the `pgrep -af` self-match wearing yet another hat.

  It was **68 + 11 + 3 + 1 = 83** until the harness-concurrency batch registered
  `headless/test_regression_concurrency_1476` in `hcases`. ⚠ **`hcases` entries are
  not `hcases` lines** and no crude grep can see the difference: `grep -c '"headless/'`
  answers **75**, because it counts lines, spans `dcases` too, and one line carries
  two entries. Three separate crude-grep miscounts landed in one batch. Take the
  number from the run's own `Start`/`Finish` output.
  ⚠ **Re-measured 2026-09-17 after the harness-concurrency batch: still 84 THEN.** The
  suite `test_regression_concurrency_1476` went **20 → 36 checks**, but those are
  checks *inside* one case, not cases — it was already the 69th `hcases` entry, and
  the three list lengths were unchanged at **3 / 69 / 11**, taken from the lists
  themselves rather than from a sentence. ⚠ **And the verdict FILE was no longer 83
  lines: `wc -l` answered 171.**
  ⚠ **Both numbers moved again LATER THE SAME DAY** — the issue-tracker batch added
  `headless/test_issue_stamp` as the **70th** `hcases` entry. Current lengths
  **3 / 70 / 11**, and `wc -l` on a green verdict is **173**. Take the list lengths
  by piping each `[list …]` block through `/usr/bin/grep -o '"[^"]*"' | wc -l`, and
  **find the block by matching `set hcases [list` rather than by line number** — the
  ranges quoted here have already rotted twice, and this batch measured bare
  `file:line` citations rotting **5 of 5** while symbolic ones held **3 of 3**.
  ⚠⚠ **READ THE NEXT WARNING WITH THIS ONE, OR YOU WILL DELETE IT.** The paragraph
  below says *"85 was wrong"*. **85 is also, now, right — and the two are different
  quantities.** The wrong 85 was an answer to *"how many LINES is the verdict?"*
  (the answer is **173**). The right 85 is the answer to *"how many CASES does T1
  run?"*. **Same numeral, different question**, and they became equal by coincidence
  on the same day: the issue-tracker batch registered a 70th `hcases` entry hours
  after the `wc -l` error was corrected. **The warning below is NOT refuted. Do not
  tidy it away on the grounds that "85 is the right number now."**

  ⚠ **This passage said 85 for a few hours on 2026-09-17, and that is the sharpest
  lesson in this batch.** 85 is `83 + 2` — the `Total num fail:` lines plus the two
  new sentinels — and it **forgets the 83 block-header lines entirely**. It was
  reached by doing arithmetic on a sentence instead of by running `wc -l` once, and it
  was added *to prevent* exactly the cases-vs-lines conflation this paragraph exists
  to warn about. **So this paragraph has now been wrong three times, and the third
  time was the correction itself.** Measured by V4 on four independent green verdicts,
  all 171, and re-derived from those artefacts when this correction was written:

  ```
     2  sentinel lines (T1-RUN-BEGIN, T1-RUN-END)
  +  84  block header lines (one per block, naming the log)
  +  84  "Total num fail:" lines
  +   3  NOGOLD notes
  = 173  wc -l on a GREEN verdict        (85-case tree, measured at 1acae0b0)
  ```

  ⚠ **And it MOVES WITH THE FAILURE COUNT**, so it is not a constant to check against:
  on the **84-case** tree, measured 2026-09-17, **171** green, **172** with one counted
  failure, **174** with three. ⚠ **Only the GREEN figure has been re-measured on the
  85-case tree — it is 173.** The one-failure and three-failure numbers above are the
  **old tree's** measurements and are deliberately **not** renumbered here: nobody has run
  an 85-case verdict with failures in it, and inventing 174/176 by adding two would be
  exactly the arithmetic-on-a-sentence this paragraph exists to forbid.
  **The three numbers, none of them interchangeable: 85 cases · 84 `Total num
  fail:` lines · `wc -l` = 173 on a green run.** Count nothing you can read off
  `T1-RUN-END`, which states `cases=`, `blocks=` and `counted_failures=` outright.
  ⚠ **Take the number from the artefact. Every time — including when you are writing
  the warning about not doing that.** Three passes have now missed that, and the third
  missed it while typing the warning.
  ⚠ **AND `Start`/`Finish` PAIRS DO NOT PAIR ON A BOX WITH NO DEV DISPLAY.** Found
  2026-09-17 by the harness-concurrency batch; filed as issue **1481**, and in no
  issue file before that. The display arm's NODISPLAY path writes its block and
  `continue`s at `run_regression.tcl:856` — **before** the `puts "Finish …"` at
  the `Finish` line — so a run on a box where `devdisplay.sh status` is not alive
  prints **85 `Start` lines and 74 `Finish` lines** (it was 84/73 before the
  issue-tracker batch registered a 70th `hcases` entry; the gap is always the 11
  `dcases`). The rule just above ("count `Start`/`Finish`
  pairs for cases") therefore **under-counts by 11 exactly there**, and a reader
  counting `Finish` concludes eleven cases vanished — the same shape as 1476 face 2,
  which is the defect that rule exists to catch. The `tcases` and `hcases` loops print
  their `Finish` unconditionally; this one arm is the only asymmetry. **Count `Start`
  lines, or read `cases=` from `T1-RUN-END`** — that counter is incremented once per
  case entered and is blind to the asymmetry.
  ⚠ **IT IS DISPLAY-STATE DEPENDENT, AND ON THIS BOX IT DOES NOT FIRE.** Do not read
  the paragraph above as "the count is broken". V4's seven T1 runs on 2026-09-17 all
  ran with the persistent dev display `:99` alive, and every one printed **84 `Start`
  / 84 `Finish`** — as did the issue-tracker batch's gate run at **85 / 85**. The hole
  was confirmed **in the source** (the `foreach dc $dcases` loop prints `Start`,
  `continue`s on `!$dd_alive`, and prints `Finish` only past that point — **cited by
  the loop, not by line number, because these three coordinates have now rotted
  twice**) and has **never been observed** — the
  85/74 split remains **derived, not measured**, because nobody has yet run T1 with
  the display down. Read that the right way round: the `Start`/`Finish` rule is safe
  *here* and unsafe *generally*, so it turns wrong the first time anyone runs on a
  fresh boot, a container or CI — which is exactly where nobody is watching for it.
  `cases=` from the trailer is correct on every box, which is why it is the rule.
  ⚠ **EVERY LINE NUMBER IN THE TWO PARAGRAPHS ABOVE WAS WRONG BY +15 UNTIL
  2026-09-17 — AND SO IS ISSUE 1481's OWN CODE BLOCK.** They read `:826` `Start`,
  `:841` `continue`, `:872` `Finish`; measured against **`69c65249`** the text is at
  **`:841`, `:856`, `:887`**, and 1481's companion citations rot by the same amount
  (`tcases` `Finish` `:736`→**`:751`**, `hcases` `:792`→**`:807`**, `xschemtest`
  `:895`→**`:910`**). Nobody mis-read anything: a **uniform +15**, from one crew's
  `+22/−7` edit landing above all six sites the same day. This is the batch's
  four-source-citation lesson arriving inside the paragraph that describes the defect
  it was learned on — **a citation needs a tree state, not just a line** — so these
  are quoted with their text at `69c65249`: `841:    puts "Start ${dc}.tcl (display
  arm)"` · `856:      continue` · `887:    puts "Finish ${dc}.tcl (display arm)"`.
  Re-grep before requoting. That includes these.
  **So before counting, confirm the log's MTIME moved off its pre-run value**
  — and treat an empty log *after* a run as a death, never as a zero.
  ⚠ **BUT A MOVED MTIME PROVES A RUN *WROTE*, NOT THAT A RUN *FINISHED* (issue
  1477).** The rule above is still correct and still necessary — V2 demonstrated
  its value in the sharpest possible way, its mtime and md5 tests *disagreeing*:
  the mtime had moved while the md5 came back byte-identical to the previous
  run's. It has a hole all the same, measured 2026-09-17. A run killed mid-write
  (1403's 900 s per-case timeout, an outer `timeout` around the driver, or an OOM)
  moves the mtime **and** leaves a truncated `results.log` that scores **zero
  counted failures at every prefix length** — verified at 1, 10, 40, 80, 120 and
  170 lines of V2's own 169-line verdict — because all four counted shapes
  (`FAIL$`, `GOLD?$`, `RESULT?$`, `^FATAL`, at `run_regression.tcl:387` — this
  said `:327`, then `:376`, both on 2026-09-17 — **three positions for one
  sentence in one day.** ⚠ **And the citation is still a line number, which is
  the defect.** The issue-tracker batch measured this corpus-wide on 40
  pre-registered random issue files: bare `file:line` rotted **5 of 5**,
  `file:line` **plus a revision** reproduced **4 of 4**, and **symbolic**
  citations held **3 of 3**, while backticked `foo()` names across all 1047 issue
  files are **98.4%** still present. **Coordinates rot; identity holds.** Cite
  `summarize_all`, which has not moved, rather than the line it currently
  occupies — as `src/op_annot.tcl` already does on purpose. Verified at
  `07c8dee3`) need a
  line to **exist**, and
  a short file has fewer lines to match. **Every prefix of a green run is itself a
  green run** to every automated reader. Worse, the verdict channel was never
  `fconfigure`d, so it was **full-buffered at 4096 B** against a **4785 B** verdict:
  a killed run left **0 or 4096 bytes**, not a proportional prefix, which made
  the 0-byte file the *typical* outcome rather than an extreme one. **So pair the
  mtime with the case count:** the log must carry one `Total num fail:` line per case
  minus one (**84** for today's 85), and a short count is a death even when every line
  that is present is green.
  ⚠ **TWO HALVES OF THAT WERE FIXED ON 2026-09-17 AND THE DANGEROUS HALF WAS NOT.**
  This bullet said *"Nothing marks that a run began or ended — there is no `REGRESSION
  START/END` sentinel anywhere in `tests/`"*: there is one now
  (`T1-RUN-BEGIN`/`T1-RUN-END`), and the channel is line-buffered, so a killed run
  leaves a **genuine proportional prefix** instead of 0 or 4096 bytes and the header
  survives the kill. What did **not** change is the thing this bullet is about:
  **every prefix of a green run still scores zero counted failures**, because the four
  counted shapes still need a line to exist. Row `V3c` of
  `test_regression_concurrency_1476.tcl` now states it as a measurement rather than a
  paragraph — a verdict carrying **800** counted failures, cut to its first line,
  scores **ZERO**. The difference is that the death is now **decidable**: no
  `T1-RUN-END` ⇒ the run did not finish. Pair the mtime with the case count if you
  like; read the trailer regardless.
  ⚠ **THE OOM USED TO HEAD THAT LIST, AND THE BOX IT NAMED DOES NOT EXIST.**
  This bullet said *"OOM on this ~7.8 GB box"* until 2026-09-17. Measured twice
  that day: `MemTotal: 16091816 kB` — **15.35 GiB** (16.48 GB decimal) — plus
  **4 GiB of swap, none of it in use**. The figure was wrong by **2×**, and it
  reached CLAUDE.md *that same day* by being copied out of a session prompt
  dated **2026-08-07** that nobody had re-measured. Headroom during a deliberate
  two-run collision: **5282 MB minimum available against 487 MB peak combined
  `xschem` RSS over 31 processes** — two orders off. `dmesg` carries **zero** OOM
  kills this boot (up 1 d 22 h at the time of measuring), and no file in this
  repo records an observed one either: every *"recorded OOM
  path"* and *"documented event"* traces back to another assertion, never to a
  measurement. **The defect is untouched** — a kill is a kill whatever kills it,
  and 1403's 900 s per-case timeout is a measured cause with nothing to do with
  memory — so read a short `results.log` as a death, but stop reaching for
  memory to explain it, and do not serialise crews on a RAM figure nobody took.
  ⚠ **HALF OF THAT IS NOW MEASURED, AND CONCURRENCY COST NOTHING.** This read *"Still
  unmeasured: concurrent `make`, and the arms that start real `ngspice`, are where a
  memory ceiling would actually show; neither has been measured"* until 2026-09-17.
  V4 then ran two full T1s concurrently — which **do** start real `ngspice` — sampling
  `/proc/meminfo` every 2 s: peak used **10328 MiB concurrent against 10350 MiB
  solo**, minimum available **~5.4 GiB**, **swap 0 throughout**, and `dmesg` OOM kills
  **0** before and after. **Concurrency added no measurable peak memory at all** — the
  *solo* run's peak was marginally the highest of the three. So stop serialising crews
  on a memory argument: the thing everyone was prepared to serialise over cost nothing.
  **Concurrent `make` is still unmeasured** and is not declared safe here.
  ⚠ **None of this touches 1477.** That defect is about a *kill* — a kill is a kill
  whatever causes it, and a truncated verdict still scores green at every prefix
  length. What died is only the habit of reaching for **memory** as the explanation.
  ⚠ **CHECK MTIME, NOT THE MD5.** This bullet said "mtime and md5" for about an
  hour on 2026-09-15 and that was wrong: `results.log` is **byte-deterministic for
  a green run**, so a clean sweep writes the identical file every time
  (three consecutive runs, all `8456b56c…`; that was the 83-case tree, whose log
  carried 82 lines — ⚠ this bullet said "82-**case** sweep" until 2026-09-17, which
  is the very conflation the bullet above it exists to warn about, two bullets
  away). An unchanged md5 therefore proves
  nothing, and reading it as proof of a fossil would condemn every honest green
  run. Only the mtime separates "rewritten identically" from "never rewritten" —
  which is also why the fossil is so dangerous: the stale file it leaves behind is
  a **previous green run**, indistinguishable from a pass by content alone.
  ⚠ **AND AS OF 2026-09-17 A GREEN VERDICT IS NO LONGER BYTE-DETERMINISTIC, so this
  bullet is wrong for the THIRD time — this time because the world moved under it, not
  because it overclaimed.** `T1-RUN-BEGIN` carries a **pid** and a start timestamp;
  `T1-RUN-END` carries a pid, an end timestamp and an **elapsed** time. Two identical
  green sweeps therefore differ in at least five fields and their md5s **always**
  differ. So a *changed* md5 now proves nothing either — it no longer separates "a real
  second run" from "the same file again", which is the one job anyone gave it.
  **Stop hashing this file.** Read the header: it states the pid and the start time
  outright, which is what the hash was ever a poor proxy for. The mtime rule still
  works and is still the cheapest check — but the closing sentence above, *the fossil
  is indistinguishable from a pass by content alone*, is the one claim here that the
  sentinels retire.
- **⚠ TWO REGRESSION RUNS IN ONE TREE NOW BOTH PROCEED. THE "RUN IT SOLO" RULE IS
  GONE** (2026-09-17). ⚠ For part of that same day this bullet read *"RUN
  `run_regression.tcl` SOLO — and as of 2026-09-17 it makes you … a second run is
  **refused loudly** … **exits 2 and writes nothing**"*, with queueing opt-in through
  `T1_LOG_LOCK_WAIT`. **All of that is deleted.** The refusal era is exactly datable
  and lasted hours: `43b40f04` introduced it, `32dff39a` removed it, both on
  2026-09-17 — so a transcript from that window is the only place the refused-run
  behaviour was ever real. Nobody waits, nobody is refused, nothing is truncated, and — read the
  corrected paragraph above — **`rc 2` no longer means "nothing ran"**. A live run is
  **announced, not refused**: the second run prints a banner naming the other pid and
  telling you which file is yours.
  **How it works now.** Each run fills `tests/results.<pid>.log` and at the end
  **copies** it onto the canonical `results.log`, which therefore holds whichever run
  finished **last**. Copy, never rename: a rename would hand the canonical name over
  and **delete that run's own answer**, the "lost cleanly" outcome
  `DECISIONS.md:64-70` names — a quiet data loss traded for a loud one. Each case
  likewise writes `<name>.<pid><suffix>` and publishes back to the canonical name once
  it is scored, so 83 of the 88 fixed-name files are now structurally per-run and the
  84th is published rather than shared. Both answers survive under their own names,
  and every verdict carries its own `T1-RUN-BEGIN`/`T1-RUN-END` pair naming its pid —
  **so read the trailer, not the filename.**
  ⚠ **IT IS NOT A THROUGHPUT OPTIMISATION — AND IT IS NOT SLOWER EITHER. THE REASON
  STANDS; THE NUMBER WAS BACKWARDS.** ⚠ This passage read *"CONCURRENCY IS 20%
  SLOWER"* until 2026-09-17, generalising a single-**case** pair to a full T1. V4 then
  measured the full-T1 case back-to-back rather than deriving it, and the sign flips:

  | mode | to BOTH answers |
  |---|---|
  | back-to-back (389 s + 382 s) | **771 s** |
  | concurrent, pair 1 / pair 2 | **435 s** / **436 s** |

  **A concurrent pair delivers both answers ~44% FASTER**, at a per-run cost of
  **~12%** (426–431 s against 382–389 s; solo reference 375 s). That per-run figure is
  the part directionally consistent with the old measurement — the sign flips only on
  the quantity the claim was actually about. **Why:** this box has **20 cores**
  (`nproc`), a full T1 has long serial stretches, and two runs interleave into idle
  cores. The original **64.4 s vs 53.7 s** stands as what it always was — a single
  `open_close` *case* pair, where 16 parallel `xargs` workers already saturate the box
  so a second copy is pure contention (`receipts/R1-recon.md:291-292,469-470`).
  Correctly scoped it is not refuted; generalised to a full T1 it was.
  ⚠ **KEEP THE REAL POINT, WHICH THE NUMBER NEVER WAS.** The change was made so that
  **no crew is ever turned away.** That is the entire case for it, it is confirmed,
  and it is independent of the clock. The speed is a side effect measured once, on one
  20-core box, and it would invert again on a busier or narrower one. Do not let a
  future reader — or a future scheduler — come away thinking concurrency was adopted
  for throughput.
  ⚠ **AND THE HARNESS ITSELF STILL PRINTS THE REFUTED SENTENCE TO EVERY CREW.**
  `run_regression.tcl:672-673` tells the second run *"This is not faster: measured 20%
  SLOWER to both answers than running back-to-back."* That first sentence is false for
  a full T1 — which is the only thing that banner is ever printed by. Believe this
  paragraph, not the banner, until the banner is fixed; its second sentence (*"what it
  buys is that neither crew is turned away"*) is the true half. This is the batch's own
  **D2 "lying detail string"** class: a true measurement of one thing, printed as a
  claim about another.
  **The lock survives, demoted to a publish mutex.** It brackets exactly one file copy
  — a sub-second critical section instead of a ~410 s one — so the canonical file can
  never be a mixture of two runs' bytes. The knobs were retuned to match:
  `T1_LOG_LOCK_WAIT` **0 → 60 s** (it used to mean "seconds to queue behind a whole
  live run before being refused", and 0 was right for that; the only thing it can wait
  for now is a copy, so 0 would make the lock decorative), `T1_LOG_LOCK_TTL`
  **14400 → 300 s** (it had to outlast a whole run; now it only has to outlast a
  copy), and a new `T1_VERDICT_KEEP` (**86400 s**) sweeps dead runs'
  `results.<pid>.log` — a pid with `/proc` present is never swept, so the failure
  direction is always "a leftover survives", never "a live run's answer is deleted".
  A stale lock is still broken on **evidence** — the owner pid is gone, or
  `/proc/<pid>/cmdline` is no longer the script that took it, since a bare `kill -0`
  answers yes for a *recycled* pid — and it still **fails open**: one that can be
  neither taken nor broken lets the run proceed UNLOCKED with a warning. Each case
  also works in its own `<case>/results.<pid>` with scratch in `<case>/.work.<pid>`,
  published back to the canonical `<case>/results` at the end, so two runs do not wipe
  each other's *files* either.
  Fixed by `5f7164d4`, `43b40f04` and `32dff39a` (the last is the one that made both
  runs proceed); issues **0384**, **0867**, **0955**, **0905**, **0990**, **1476**,
  **1477**, **1478**; batch record in `doc/claude/harness_concurrency_batch/`, build
  receipt `receipts/R1-build.md`.
  ⚠ **The history still matters, because it is what a number from the broken era is
  worth.** Before the fix two runs at once corrupted each other and the loser reported
  a `FATAL` that never happened: the per-job exit-status files lived under a **shared**
  `results/` tree that every run wiped on the way in, and `read_job_status` scored a
  missing status file as `-1`, so the victim printed `FATAL: 10` and a nonzero count in
  the one suite whose baseline is ZERO. **`exit -1` was the tell**: no xschem process
  writes that; a real crash writes a real code. Both verify passes on item S4c hit it
  in one session. The *quiet* variant is the one to fear in an old transcript: the
  second run could instead **die at startup with no banner and no `Total num fail:`
  line at all** (1476 face 2), and nothing counts a line that is not there. **So a T1
  number taken before 2026-09-17 while another agent's suite was live is still not
  evidence** — nothing recorded whether that run had been contended. ⚠ This sentence
  used to end *"A number taken today either held the lock or was refused"*, which the
  same-day rewrite above makes false: nothing is refused now. **A number taken today
  is its own run's**, written under its own pid to its own file, and its trailer says
  whether it finished — which is a better answer than the lock ever gave.
  ⚠ **THE RULE THAT SERIALISED CREWS LOST ITS STATED REASON AND KEPT A REAL ONE
  (⚖ R4, 2026-09-17).** For five weeks "one crew at a time" was justified in writing
  by *"a ~7.8 GB box"* on which *"a concurrent `make` is the recorded OOM path"*.
  **Neither half was ever measured.** The box is **15.35 GiB** with 4 GiB of untouched
  swap, `dmesg` carries **zero** OOM kills, and V4's 2 s sampling found concurrency
  added **nothing** to peak memory — **10328 MiB** concurrent against **10350 MiB**
  solo, the *solo* run peaking highest. **The rule was right anyway, for a reason
  nobody was citing.** The one measured block that survived the entire batch is the
  pre-fix pair table: two staggered runs produced **407 / 432 / 757 phantom `FATAL`s**
  with the second run **dead at rc 1**, in the one suite whose baseline is ZERO. That
  is the whole basis, it has nothing to do with memory, and it is why a T1 number
  taken during a collision was void.
  **R4 is now RELAXED, on measurement — and the relaxation is about THE HARNESS.**
  V4 ran the first clean concurrent pair (both verdicts complete, self-identifying,
  neither missing a block the other had), and `W12b` — the last row that manufactured
  a false red out of a shared namespace — was fixed by **identity**, the child
  announcing `EMERGENCY SAVE DIR:` on its way out (`src/main.c:52`), not by counting.
  Two T1 runs in one tree are a supported thing to do.
  ⚠ **A batch's own dispatch queue does not inherit that licence.** A driver that
  serialises its crews is applying a *scheduling* choice of its own. Meeting a relaxed
  R4 here and a serialised ledger there does **not** mean one of them is stale — ask
  which is speaking, the harness (relaxed) or that batch (its own call).
  ⚠ **Two caveats stand, and neither is bookkeeping.** **Diagnose a T1 red by case,
  never by count**: the `test_ase_optier_0963` flake was observed in an
  **uncontended** run and is still unexplained, so "T1 went red" is not evidence of a
  collision. And **nobody has swept the shared globals** beyond
  `/tmp/xschem_emergencysave_*` — `W12b` was one count-based assertion on one global
  namespace, found by accident, and no one has looked for its siblings.
  **Concurrent `make` remains unmeasured** and nothing here declares it safe.
  ⚠ **The refuted figure is still on disk in 18 places, deliberately.** Measured
  2026-09-17: five `doc/claude/ledger/*.md`, four crew-launcher `.js` (`crew.js:29`,
  `crew_annotate.js:58`, `crew_opfix.js:67`, `op_param_batch/item_pipeline.js:91`),
  five `doc/claude/suggestions/next_session_prompt_*.md`, and four issue files
  (`0432:82`, `0671:83`, `0868:215`, `0876:45`). Those are dated records of what
  people believed, and rewriting them would falsify the record — **so when you meet
  "~7.8 GB" out there it is a fossil, and this bullet is the correction.** Note the
  four `.js` are *launchers*, not archives: each still emits that sentence into a new
  crew's brief, and `crew.js:25` tells that crew CLAUDE.md **overrides** it — this
  paragraph is what does the overriding. (`receipts/ram-figure.md` records the same
  set as **17**; it counted four session prompts where the tree carries five.)
  ⚠ **AND DO NOT ASK `pgrep -af run_regression` WHETHER A RUN IS LIVE — IT ANSWERS
  YES TO ITSELF.** Measured 2026-09-17: **four hits for one run** — the real `timeout`
  and `tclsh` processes, plus **two Bash wrapper shells whose command *text* contains
  the pattern**, one of them the `pgrep` being typed. `-f` matches the whole command
  line, so **any pattern you type is, at that instant, present in a live process's
  command line: your own.** In a batch whose subject was detecting concurrent runs,
  the detector had a false-positive mode that makes a solo run look contended — and a
  false collision is a ready-made excuse for a red. Same defect as `W12b` and `C11` in
  different clothes: **matching a shared namespace by pattern instead of by identity.**
  **Ask the harness instead.** `t1_live_runs` (`tests/run_regression.tcl:656-665`)
  already does it by identity: it globs `results.<pid>.log` and keeps a pid only if
  `/proc/<pid>` exists, so the verdict file *is* the liveness record and there is no
  second thing to leak. A run that sees a peer says so on stdout (`another regression
  run is live in this tree (pid: …)`), so **zero occurrences of that line in your own
  run's output is a positive statement that it ran solo** — better evidence than any
  `pgrep`, because it comes from the thing being measured. If you must match processes
  by hand, bracket a character (`'run_[r]egression'`) or match `ps -eo comm=` by name;
  never a bare `-f` substring.
  Deliberately **not** filed as an issue: the trap is already written up correctly in
  `doc/claude/code_analysis/gui_test_gate_tutorial.md:207-210` (Lesson 5),
  `doc/claude/suggestions/retrospective_new_user_lessons.md:46-98`, and
  `doc/claude/ase_analyses_batch/CREW_BRIEF.md:125-160`, which records three sightings
  including one that **killed its own shell**. A sixth document about a defect already
  documented five times is this project's signature failure, not a fix. What was
  missing was never a number — it was this sentence, here, where everyone reads.
- **⚠ NO TEST HARNESS BUILDS. `full_audit.sh` runs `$REPO/src/xschem` as it
  finds it** (`full_audit.sh:49`), and so does every standalone suite. So a
  source tree that is correct and a binary that is stale produce a *plausible*
  audit — right suite names, right check names, wrong answers — and nothing in
  the transcript says so. The way in is ordinary: `git stash` → build → test the
  stashed state → `git stash pop` restores the sources and leaves the binary a
  build behind. Measured 2026-09-02: a full audit taken that way reported two
  extra reds, one of them the very suite the change was meant to green, which
  passed 120/120 the moment the tree was rebuilt. **Rebuild before any audit that
  is meant to be evidence**, and when a suite reds unexpectedly check the binary
  before the code — `make -C src` recompiling *everything* means a header moved
  under the objects, which is itself the tell.

- **T1's baseline is ZERO counted failures, as of the 0689+0690 commit.** For days
  every crew report carried "T1 3 FAIL — pre-existing" and every reader, the lead
  included, waved it through. Two of those three were the completion sentinel
  false-redding a suite that appends a check count to its banner (0689, filed
  **four** times: 0420, 0492, 0629, 0689); the third was a golden one library
  behind its own tracked `library.defs` (0690, filed **four** times: 0421, 0455,
  0491, 0690). Eight issue files, nobody fixing, everybody re-deriving. **A
  standing red is a defect, not furniture** — it is the one place a real
  regression hides in plain sight, and this branch has already shipped two
  defects past twenty-eight passing checks. If T1 is not at zero, say which case
  and why, per case; never carry a count forward as a known quantity.
  ⚠ **Measured green 2026-09-17:** a solo T1 returned `rc 0`, **375 s**, trailer
  `cases=84 blocks=83 counted_failures=0`. The baseline is met and it remains ZERO.
  ⚠ **Re-measured green the same day at 85 cases**, after the issue-tracker batch
  registered `headless/test_issue_stamp`: `rc 0`, **380 s**, trailer
  `cases=85 blocks=84 counted_failures=0` (commit `1acae0b0`). **Still ZERO**, and
  solo-ness was established *positively* — zero occurrences of `another regression
  run is live` in the run's own output, which is better evidence than any `pgrep`.
  ⚠ **That gate went RED twice first, and both reds are worth knowing.** One was a
  driver hand-running a suite **while T1 was live** — in a diagnostic run undertaken
  to be careful. The other was **the spelling of `HEAD`**: `83656487` has no `a`–`f`,
  the issue-stamp suite feeds `git rev-parse --short=8 HEAD` into its fixtures, and
  its grammar correctly refuses a `tree=` with no hex letter — so **12 rows died at
  once, on a 2%-per-commit coin flip**, under a baseline that treats any red as a
  defect. Measured: 6 of the last 300 commits abbreviate to all-decimal.
  ⚠ **BUT A T1 RED IS NOT BY ITSELF EVIDENCE OF A COLLISION**, and the
  harness-concurrency batch has just spent a night teaching everyone to suspect one.
  In that same session an **uncontended, solo** run produced **3 counted failures** in
  `headless/test_ase_optier_0963` (`X1`/`X2` — ngspice `rc=1`, `raw=-1bytes`,
  `NORAW`); the standalone re-run was `ALL PASS (109 checks)` with
  `raw=284381bytes`. A flake, cause undiagnosed — **not** concurrency, and not a
  standing red. Of seven runs that day five were green and two red: **one concurrent**
  (a real collision through a global `/tmp` corpse *count*) and **one solo** (this
  flake). So diagnose **by case, never by count** — which is what this bullet already
  demanded, and here is the session that shows it is not mere bookkeeping: the same
  number, 3, meant a genuine defect in one run and noise in another.
- **The banner rule lives in `tests/banner_rule.tcl`** (`banner_complete`,
  `banner_died`, `regression_case_failed`) and `run_regression.tcl` is a
  *consumer* of it. The two shell readers (`run_suites.sh`, `full_audit.sh`) keep
  their own EREs because `/bin/sh` cannot source Tcl;
  `test_audit_classifier.tcl` **section K** locks the Tcl rule against
  `run_suites.sh`'s ERE and against `full_audit.sh`'s two crash literals, by
  verdict. `full_audit.sh`'s *pass* arm is **not** locked and is only
  prefix-anchored, so it still accepts trailing junk the other two reject — latent
  (no suite emits it), filed as **0805**.
  A case passes only on **exit 0 AND a whole-line completion banner AND no
  column-0 death marker** — the exit code alone is not enough (`--nogui --pipe`
  exits 0 on an uncaught mid-script Tcl error) and neither is the banner (a suite
  that reported and *then* died used to score a silent pass).
- `xschemtest.tcl` is a broader functional/perf harness, run as
  `xschem --script xschemtest.tcl` then calling `xschemtest`. Use `-d 3 -l log` to
  log allocations for leak checking.

### The persistent dev display (`tests/headless/devdisplay.sh`)
**Start this once and GUI testing stops touching your screen at all**, including
the case no wrapper script can reach — a bare
`./src/xschem --pipe -q --script tests/headless/<t>.tcl`, which is the most-typed
command in a session and which no arming script wraps.

```sh
tests/headless/devdisplay.sh start     # Xvfb :99 + openbox, ~0.3 s, idempotent
tests/headless/devdisplay.sh view      # x11vnc on localhost, to watch it
tests/headless/devdisplay.sh status|stop
```

**The human does NOT want `DISPLAY=:99` in their interactive shell**, and an
earlier revision of this section wrongly told them to put it in `~/.bashrc`. A
person launching xschem is launching it *to use it* — sending that to an
invisible display is the bug, not the fix. The armed entry points
(`full_audit.sh`, `run_suites.sh`, `gated_xschem.sh`, the 8 standalone
`test_*.sh`) already need nothing.

**The one consumer of the export is the assistant**, whose bare
`./src/xschem --pipe -q --script tests/headless/<t>.tcl` is typed dozens of
times a session and is armed by nothing. Two ways to cover it, in order:

1. **Launch the session as `DISPLAY=:99 claude`.** Tool shells inherit the
   Claude Code process's environment, so every bare invocation lands on the dev
   display and the human's own terminals keep `:0`. One word, no rc edits, and
   it does not depend on the assistant remembering anything.
2. **Failing that — assistant, route it yourself**: `tests/headless/devdisplay.sh
   exec ./src/xschem --pipe -q --script <t>.tcl`, or run suites through
   `run_suites.sh`. Never a bare `./src/xschem --script` on a live `:0` unless
   the point *is* the real screen.

Note `~/.bashrc` cannot serve purpose 1 here anyway: it returns at its line 6–9
for non-interactive shells, and the Bash tool's shell is non-interactive
(`$- = hmtBc`). It inherits its environment; it does not source that file. (An
earlier claim in this section that it *is* sourced was wrong — inferred from
`~/eda/bin` being on `PATH`, which arrives by inheritance.)

`shellinit` remains, for the narrow case it fits: a **dedicated terminal used
only for running tests by hand**. It emits a *conditional* export, because an
unconditional one in an rc outlives the display it names — after a reboot or a
`stop`, every GUI program in that shell dies with `cannot open display`. **The
display does not survive a reboot**; re-run `start`.

The arm (below) **attaches** to it when it is up, so every entry point lands on
one stable display. `:0` becomes the opt-in (`AUDIT_DISPLAY=:0`), which is the
right way round — the only thing that still needs it is reproducing
Xwayland-specific defects. Side wins: immune to the WSLg Xwayland aborts that
kill `:0` clients ~3×/session, and no per-run Xvfb spawn.

### ⚠ THERE ARE THREE X SERVERS HERE, AND `:0` IS NOT THE USER'S SCREEN

Measured 2026-08-22 with `xdpyinfo`, all three live at once:

| display | vendor string | what it is |
|---|---|---|
| `:0` | `Microsoft Corporation` | **Xwayland**, WSLg's own server |
| `$DISPLAY` = `<win-ip>:0` | `HC-Consult` | the **Windows X server** the user actually looks at, over TCP |
| `:99` | `The X.Org Foundation` | Xvfb, the persistent dev display |

`$DISPLAY` comes from `~/.profile:48` (`export DISPLAY="$WINDOWS_IP:0"`). Note
`~/.bashrc:152-153` would override it to `:0` when `WAYLAND_DISPLAY` is set — and
it *is* set — but bashrc returns early for non-interactive shells, so a tool shell
keeps the TCP display and an interactive terminal may not. **Check `$DISPLAY`
rather than assuming.**

**This matters because `AUDIT_DISPLAY=:0` exports the LITERAL string `:0`**
(`tests/headless/xvfb_arm.sh:140`), not `$DISPLAY`. So:

* every `:0` measurement recorded below — the flake rates, the 3-vs-1
  `<Configure>` traffic, the Calculator phase-0 failures, `test_wave_modes` at
  6.2–45.6 s — was taken against **Xwayland**, and the WSLg attributions in this
  section are correct;
* a **bare** `./src/xschem --script …` inherits `$DISPLAY` and therefore lands on
  the **user's real screen**, a different server from the one the suites call
  `:0`. That is the reason for the "never a bare run on a live `:0`" rule above,
  and it is a sharper reason than it sounds: the two are not the same X server;
* **"run a GUI feature's suite on `:0`" means Xwayland**, not the user's screen.
  A look debt that says "on the real VcXsrv screen" — issue 0413's does — is
  asking for something `AUDIT_DISPLAY=:0` **cannot** provide. Pay that one with
  `AUDIT_DISPLAY=$DISPLAY`, or by hand from a terminal.

Do not "correct" WSLg to VcXsrv in this file. Both are here; they are different
displays; the distinction is the load-bearing part.

`_gate_enabled` returns false on the dev display, deliberately: an invisible
display would otherwise arm the gate and `_gate_attention` would relaunch the
user's Pause panel where nobody can see it. Spec: `doc/claude/specs/dev_display.md`.

**Two platform traps recorded there**: under WSLg `/tmp/.X11-unix` is mode 777
without the sticky bit, so Xvfb binds only the *abstract* socket
`@/tmp/.X11-unix/XN` and a `[ -S /tmp/.X11-unix/XN ]` readiness poll is always
false; and `xdpyinfo` against a dead display **hangs** on the TCP fallback rather
than failing — check the listen state before probing.

### The owed ledger (`tests/headless/owed.sh`)
Three debts still cost the user's attention, and they used to arrive scattered —
one at a time, whenever a feature happened to finish, and out of *two different
files*. Record them instead, pay them in one batch:

```sh
owed.sh add rule  <id> [why] [--eyes]  # owes the USER a RULING (a driver run's
                                       #   E questions; --eyes if it cannot be
                                       #   decided without looking at pixels)
owed.sh add look  <what> [why]         # owes the USER's eyes (pixel deliverables)
owed.sh add suite <name> [why]         # owes a :0 run ("run a GUI feature's
                                       #   suite on :0 once before calling it done")
owed.sh list | count | show            # `show` = the user's queue: rule + look
owed.sh drain                          # runs the SUITE debts, one batch, gate live
owed.sh clear <kind> <id>              # rule/look: ONLY when the USER says so
owed.sh add|clear … --repo <clone>     # deliberately touch ANOTHER clone's entry
                                       #   (a clone path, its basename, or `here`)
```

**`rule` and `look` are the user's queue; `suite` is not.** A suite debt clears
itself on a pass. A **rule or look debt clears only when the user says so**
(`clear rule <id>` / `clear look <id>`), and no command converts one kind into
another — `drain` does not so much as open the other two lists. A ledger that
discharged an eyeball because a suite went green would be exactly the defect
that rule was written about (two defects shipped past 28 passing checks), and
one that closed a *ruling* that way would be the same defect wearing a tie.

**One ledger, every CLONE — not merely every worktree.** It lives in `$HOME`, which
cannot tell a second checkout of this repo from a worktree of this one, so two trees
wrote one ledger and a 4-digit rule id came to mean two different things (issue
**1400**). Both writing paths destroyed the other tree's entry in silence: `clear` is
an `rm` by exact filename, and `add` was a bare `>` with no existence check that
printed `recorded` however much it overwrote — **either could close a ruling the user
had never answered, and nothing said so.** Now an entry carries the clone that filed
it, and an `add` or `clear` that would write **another** clone's stamped entry
**refuses, exit 5**, printing what is standing there, whose it is, and what to type
instead; `clear` also lists this tree's own ids on that number. When you really do
mean the other tree's entry, say so: `--repo <clone>` on both `add` and `clear` — a
clone path, its basename, or `here`.

**Every live entry is stamped, so an UNSTAMPED one is EVIDENCE, not legacy.** Measured
**2026-09-10 12:40**: `/usr/bin/grep -L '^repo:' ~/.claude/xschem_owed/{rule,look,suite}/*`
printed **nothing**, and `/usr/bin/grep -h '^repo:' … | sort | uniq -c` split the 196
entries **182 this clone / 14 op-wcard**. Re-run both rather than quoting the numbers —
this set has moved every time anyone has measured it. Against a stamped ledger a bare
entry can only have arrived one way: **another clone's older `owed.sh` wrote over
something.** Do not claim it for this clone on the strength of its being unstamped — that
erases the one signal the destroy left, and if `owed.sh` still offers to (*"predates
origin stamps — claiming it for …"*) that is the old legacy contract talking, not a fact
about the entry. Reconstruct from **`cleared.log`** in the state dir root: append-only,
never rotated, the full pre-image of every clear and every overwrite *this* script makes.
A silent `cleared.log` beside a missing debt means the other clone did it, and there is
no pre-image anywhere.
⚠ **BUT FOUR UNSTAMPED ENTRIES ARE INNOCENT, AND THEY WILL OUTLIVE THIS PARAGRAPH.**
Measured **2026-09-16 07:43**: that same `grep -L` now prints **four** —
`rule/1357`, `look/hier_pdf_nav_1357_H6.…`, `suite/test_hier_pdf_links_1333` (all three
at **2026-09-10 13:25:32**, twelve *milliseconds* apart) and `rule/1357@xschem-claude`
(13:35:02). Nothing was destroyed. The first three are **one `owed.sh` run filing three
debts**, from op-wcard, in the window after this file recorded a clean sweep at 12:40 and
before the repaired script reached that clone — an atomic trio is a *filing*, never an
overwrite, and that is the shape to check first. The fourth is the guard **working**: ten
minutes later this clone hit the collision on 1357 and wrote the suffixed name rather than
clobbering. Their `ref:` resolves too, to an op-wcard branch nobody here has checked out
(`5866270d`), so **"the ref names a file no clone has" is not evidence either.** The rule
above still holds for an unstamped entry that is *alone*, *undated* or *unexplained*; it
does not hold for these four, and re-running the twenty-minute investigation on them is
waste. **Read the mtimes before reaching for `cleared.log`.**

**The refusal WAS one-sided, and as of 2026-09-15 it is not.** One ledger, but each clone
runs its **own** `owed.sh`, and the guard lives in the script, not in the ledger — so
until the repaired script reached the other clones, this one refused to write theirs while
theirs could still destroy ours wholesale. That window is **closed**: measured
**2026-09-16 07:44**, op-wcard's copy is dated **2026-09-15 10:05** and contains `repo:`
**thirteen times, identical to this clone's**. This paragraph said "dated 2026-09-04 and
has never heard of `repo:`" until that measurement, which is why the four unstamped
entries above read as a live attack rather than as fossils of the gap.
⚠ **Do not read the closed window as a closed risk.** The guard is still per-script and
still absolute-path-based, a third clone would arrive unrepaired, and **a ruling really was
destroyed in place at 10:46:14 on 2026-09-10, surviving only because a backup existed.**
**Take one before any pass that touches the ledger** — `cp -r ~/.claude/xschem_owed …`
costs nothing and is the only thing that has ever saved one. And **re-measure both clones'
scripts rather than trusting this paragraph**: it has been wrong once, in the direction of
alarm, and the next edit to either script can make it wrong in the direction of comfort.

**The stamp is an absolute path**, so moving or renaming a clone turns every one of its
own rulings foreign — run `owed.sh` from this tree at a different path and all 196 read
as someone else's, `clear` refusing the user's own debts. There is no `rename` and no
`re-stamp`; the escape is `--repo <clone>` on every command. Mechanism: issue **1400**,
spec `owed.md` §R6b.

**A rule entry is a pointer, not a copy.** The option set stays in
`doc/claude/issues/NNNN-*.md`; `add rule` resolves the path from the id. Spec:
`doc/claude/specs/owed.md` (§6 for why `rule` exists).

Assistant: `add` at the moment the debt is incurred; it costs nothing and is the
only thing that makes the batching possible. Never report a pixel deliverable
"done" on a green suite — record a `look` and say "suites green, please look".
Never leave a step's unratified user-visible decision in a write-up only —
record a `rule`, or the user never sees it was theirs to make.

### The display arm: Xvfb by default (`tests/headless/xvfb_arm.sh`)
`full_audit.sh`, `run_suites.sh`, `gated_xschem.sh` and the 7 window-mapping
standalone `test_*.sh` suites run on the persistent dev display if one is up,
otherwise a **private Xvfb**, and no longer
borrow the screen they were launched from. That is the routine arm because it is
measured better, not merely quieter: 30/30 soak with identical check counts where
the same suites on `:0` flake 4-in-10 / 2-in-3 / 1-in-5, a full audit reproducing
the recorded `:0` fail list exactly, and `test_wave_modes` at 2.3 s against
6.2–45.6 s. Knobs: `AUDIT_DISPLAY=:0` (Xwayland — **not** the user's screen,
see the three-server table above; use `=$DISPLAY` for that), `=none` (no DISPLAY, GUI
legs self-skip), `AUDIT_SCREEN=WxHxD` (default `1920x1080x24` — **pin it**, and
never `1600x1200`, the one size `test_fluid_bodyshove_guards_0132` fails at).

**`GUI_GATE=0` is forced on the Xvfb arm, not defaulted.** `_gate_enabled` only
checks that `$DISPLAY` is non-empty, so a virtual display arms the gate; then
`gate_start` → `_gate_attention` kills the live panel and relaunches it on the
invisible display, for every session sharing the control dir. Xvfb without
`GUI_GATE=0` doesn't free the screen, it breaks Pause.

**A window manager runs inside the virtual session** (`AUDIT_WM`, default
`openbox`; `none` for the old empty-Xvfb behaviour). Measured: empty Xvfb does
not reparent and silently no-ops `wm iconify`; with a WM both work — and on
iconify a real WM is *more* faithful than WSLg, which doesn't honour it either.
So decoration/iconify/stacking/raise are no longer a reason to reach for `:0`.

⚠ **`openbox` WAS MISSING UNTIL 2026-08-23** (issue 0645). It is installed now
(`/usr/bin/openbox`, Openbox 3.6.1, verified), so `xvfb_arm.sh:154`'s default
finally resolves and a WM really is live. But **every WM-dependent measurement
recorded before that date was taken WM-less** — `:156` falls back to no WM with
only a stderr warning, so suites that believed they had a window manager did not.
Re-measure rather than trusting an older number.

The fallback path is still real (another box, a stripped container), so the rule
stands: a suite whose subject is reparenting, iconify, stacking or raise **must
say in its report which WM was actually live**, and if it needs to be certain it
should name one explicitly — `AUDIT_WM=openbox` (verified 2026-09-17:
`/usr/bin/openbox`, Openbox 3.6.1, dpkg `openbox 3.6.1-12ubuntu3`).
⚠ **`AUDIT_WM=xfwm4` IS NOT A LIVE OPTION HERE.** This paragraph said
`AUDIT_WM=xfwm4` *"as issue 0616's did (`xfwm4 --compositor=off`;
`/usr/bin/xfwm4` is also present)"* from 2026-08-23 until 2026-09-17 — added, as
it happens, by the very commit that corrected the openbox claim above it, and
never measured. Measured 2026-09-17: `command -v xfwm4` exits **1** and **no
xfwm package is installed**, only the openbox family. So either 0616 ran on an
install since removed, or its report is itself the thing this paragraph warns
about. Naming an absent WM does **not** fail loudly — `:156` falls back to no WM
with a stderr warning — so check that a WM exists before naming it. A report
that omits the WM is a bare-Xvfb measurement wearing a window manager's name, and
it will pass while the bug is live. The warning line is not cosmetic; it is the
difference between evidence and nothing.

**Xvfb is still not a substitute for `:0`** for a human eyeball, or for Xwayland's
own quirks. The sharpest of those is **event traffic**: one `wm geometry`
request yields 3 `<Configure>` events on `:0` against 1 under Xvfb with or
without a WM, and Calculator phase 0 passed 49/49 under Xvfb while failing 3
checks on `:0` for exactly that reason. **Run a GUI feature's suite on `:0` once
before calling it done** — but treat a bug that only `:0` can reproduce as a
*test* defect too: the fix is to force the race deterministically
(`test_calc_skeleton` S12), not to hope an environment supplies it.

### GUI-test control gate (`tests/headless/gui_gate.sh`)
Running a suite under a real/WSLg `$DISPLAY` pops a **control panel**
(`tests/headless/gui_gate_widget.tcl` via `wish`) that **warns before the
suite runs** (Proceed / Snooze 5·15·30 min) and gives a **Pause/Resume toggle
+ Stop** during it — the GUI suite otherwise floods the display and makes the
machine unusable. The gate lives in the harness (`gui_gate.sh`), **not** a
Claude Code settings hook (a prior hook-based gate silently died when
`settings.local.json` was rewritten — do NOT reintroduce it as a hook). Control
dir `~/.claude/gui_test_gate/` is shared by the main session and all
worktree/subagent runs, so one Pause pauses every suite. It **fails open** (no
`DISPLAY`, `GUI_GATE=0`, or a closed panel → tests just run) so CI/headless is
unaffected. Spec: `doc/claude/specs/gui_test_gate.md`.

Since the default arm became Xvfb the panel should be **rare** — it now guards
the deliberate `AUDIT_DISPLAY=:0` runs, not the everyday ones. A panel popping
for a routine suite means something bypassed `xvfb_arm.sh`.

**Don't press Proceed forty times.** Many small runs each cost a click, or a
2-minute autostart wait with nobody at the desk. Press **`Allow 30m` / `Forever`**
once and every suite in that window starts unprompted — Pause and Stop keep
working throughout, and the panel shows how many have run. Approving *before*
launching a batch works too.

**Getting a run under the panel's control:** `run_suites.sh` (preferred, reports
PASS/FAIL and gives a pause point between runs) or `gated_xschem.sh` as a
drop-in for `./src/xschem` in a hand-written loop. A bare
`for i in ...; do ./src/xschem --script t.tcl; done` enrols in neither, so Pause
cannot reach it — the panel lists such processes as `UNGATED` and the
**`Halt N xschem`** button (SIGSTOP, resumable) is the only authority over them.

### ⚠ A HAND-ROLLED SUITE LOOP ALSO FORFEITS THE TIMEOUT, AND A STALL THEN HAS NO UPPER BOUND

The gate is not the only thing a private loop loses, and it is not the expensive
one. **`run_suites.sh` wraps every arm in `timeout "$TIMEOUT"`**
(`SUITE_TIMEOUT`, default **200 s**) and prints a stall as its own verdict —
`TIMEOUT | <name> run i/n (after 200s)`. `full_audit.sh` does the same with
`AUDIT_TIMEOUT` (default 300 s) and counts `crash/timeout` as a column of its
`SUMMARY:` line. Its own comment already records this failure shape: a startup
Tcl error popup *"does not fail, it HANGS, and paid AUDIT_TIMEOUT (300 s) plus a
crash row"*.

**Measured 2026-09-11, and it is why this paragraph exists:** a session that
hand-rolled `for t in ...; do ./src/xschem --nogui --pipe -q --nolog --script
tests/headless/$t.tcl; done` to collect per-suite `RESULT:` lines on two arms hit
a stall in `test_ase_optier_0963`'s **display** arm — 86 of 103 rows, stops after
row N3, no `ngspice` alive, no verdict line — and sat on it for **8 hours 7
minutes**, because the loop had no `timeout` and the waiter around it
(`until grep -q done; do sleep 15; done`) had no deadline. Through
`run_suites.sh` the same stall is 200 seconds and one printed line. Write-up:
`doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md`.

So: **use `run_suites.sh`, and extend it rather than replacing it.** If a
bespoke invocation is genuinely unavoidable, `timeout <n>` goes on **each
command** (rc 124 is a result, not a gap in the log) and every waiting loop
carries a deadline that announces itself when it expires. **A stall must be a
named outcome — `PASS` / `FAIL` / `TIMEOUT` / `NORESULT` — never the absence of
one**, because "no output yet" is indistinguishable from "still working".

⚠ **A suite's first run on an arm nothing has exercised is unexplored ground.**
`run_regression.tcl`'s case list runs `test_ase_optier_0963` **headless only**,
so its display arm had never been walked by anything before it hung. Give any
such first run a timeout and watch it.

**TWO BOUNDS NOW EXIST, AND NEITHER REPLACES THE OTHER (issue 1403).**

* **`tests/run_regression.tcl` finally has one.** It had NO `timeout` on any of its
  four `exec` sites — the one suite whose baseline is ZERO was the one with no
  bound, and that includes its six-suite display arm. `t1_timeout`
  (`T1_CASE_TIMEOUT`, default **900 s**, `0` disables) now prefixes all four with
  `timeout --kill-after=20`, and `t1_why` turns rc 124 into a counted `FAIL` that
  says `TIMED OUT`. Note the display-arm prefix goes **inside** `devdisplay.sh
  exec`, not around it: `cmd_exec` stays the parent of what it runs, so a timeout
  around the script would signal the shell and orphan xschem on `:99`.
* **Every suite that sources `tests/headless/scratch.tcl` (169 of 384) carries its
  own watchdog**, armed by being a suite — so it reaches the one command no driver
  wraps, a bare `./src/xschem --nogui --pipe -q --nolog --script <t>.tcl`. Budget
  `XSCHEM_SUITE_WATCHDOG_MS`, default **900 000 ms** (deliberately above both
  drivers' caps so it never preempts their verdict), `0` disables. It exits **124**,
  which `run_suites.sh` already reads as `TIMEOUT`, and prints
  `###### WATCHDOG TIMEOUT ###### <suite> exceeded <n>ms -- last output: <line>` on
  both streams. The last-output clause is the point: *"stops after row N3"* is the
  finding, *"it hung"* is what an external timeout could already tell you.

⚠ **THE IN-SUITE WATCHDOG IS NOT A GENERAL TIMEOUT.** A Tcl `after` timer fires only
when the interpreter reaches the event loop. Measured: a hang in `vwait`/`tkwait`
**is** caught (that is issue 1375's modal, the one that cost the night); a hang in a
blocking `exec` or a busy Tcl loop is **not**. For those the answer is still an
external bound — `run_suites.sh`, or `timeout` on the command. Row **W13** of
`test_suite_watchdog_1403.tcl` pins the limitation by measurement, so if anyone makes
the watchdog general the row goes red and names the paragraph that needs rewriting.

⚠ **And do not gate a whole report on the last check.** Thirteen of fourteen
suites were green on both arms hours before anyone knew it. Report — and where
appropriate commit — the verified majority, naming the outstanding item as
outstanding.

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

**Issue numbers: `doc/claude/issues/NUMBERING.md` is authoritative about what a
number MEANS, and blind to what is free.** It is a **tracked, per-branch** file, so
it can see only the checkout you are reading it in, and its `next free number` line
is a **per-clone pointer** — the line that reads most like an authority is the blind
one. Measured **2026-09-10 10:47**: two clones of this repo on this machine held
**twelve** numbers naming two different defects each, and the set was **still growing
as this was written** — five of the twelve (1349–1353) were filed by the other clone
during the batch that was measuring the first seven, the last of them two minutes
before this sentence. Its pointer now reads 1354, and every number from 1349 to 1399
is already a committed issue file here. Nothing in either tree reports any of it
(issue **1400**; both pointers were honest, and the rule is what broke). **Any count
in this paragraph is a timestamp, not a standing fact** — re-measure before quoting it.

So minting takes **two** checks and neither substitutes for the other. The
**candidate** comes from this clone's `NUMBERING.md`: its `next free number` line for
the number, and its **reserved-block table at the head** for the bands to skip. A
band is a **range**, so no per-number grep can see one — that check is separate, and
first. Only then does a grep prove no *other* checkout has taken the number you
landed on:

```sh
N=doc/claude/issues/NUMBERING.md                   # this clone's pointer AND bands
/usr/bin/grep 'next free number' "$N" | /usr/bin/grep -v '~~' | tail -n1
n=1401                                             # 1550 to see the other answer
awk -v n="$n" -F'|' '/^\| \*\*[0-9]/{gsub(/[^0-9]/," ",$2); split($2,b," ")
  if (n>=b[1] && n<=b[2]) print "!! "n" is in RESERVED band "b[1]"-"b[2]}' "$N"

set -- ~/dev/*/doc/claude/issues/NUMBERING.md      # EVERY clone on this machine
[ -e "$1" ] || echo "!! glob matched nothing -- fix the path, not the number"
ls ~/dev/*/doc/claude/issues/"$n"-* 2>/dev/null    # a file in ANY checkout here
/usr/bin/grep -lw "$n" "$@"                        # or a reservation with no file
```

Both answers, run today: `n=1401` → silence from the band check and only this clone's
own `NUMBERING.md` from the last line; `n=1550` → `!! 1550 is in RESERVED band
1500-1599` **while every grep stays silent**, which is the whole reason the band check
exists; `n=1349` → two issue files and two `NUMBERING.md`s, the live collision. A
reserved number often has no file yet, so a bare `NUMBERING.md` hit is a taken number.
`~/dev/*` is the whole set of checkouts **today**; one living elsewhere must be added
to that glob, and the `[ -e "$1" ]` line is there because a glob matching nothing
sends grep's complaint to **stderr** and exits 2 — silent stdout, indistinguishable
from "free". Use `/usr/bin/grep`, never the bare `grep`: it is a function routing to
ugrep, and it returns **nothing in either clone** for the anchored-alternation form
this block used to print (`-lE "(^|[^0-9])$n([^0-9]|$)"`, `n=1349`) where
`/usr/bin/grep` finds that number taken in **both**.

**`1500–1599` is reserved for the op-wcard branch: after 1499 the next number here
is 1600.** Do not trust a number quoted anywhere else, including here: this paragraph
itself said "next 0513" until 2026-09-02, by which time the tree had filed through
**1243**, and it also told you to file at "≥ 0500" when NUMBERING.md's head table
lists **0500–0599** as a reserved block — a row whose owner that table names as **the
fluid-editing branch**, i.e. this one, with 21 issue files already inside it. (This
sentence said "another branch" until 2026-09-10; it is not one. Read the table.) A
duplicated number rots silently and a collision costs a renumbering (0420–0432, +80,
2026-08-19). Record the new number in NUMBERING.md as part of the same commit.

**Wiring work**: before touching anything that creates, moves, deletes, or reroutes wires
(move.c, the fluid passes, trim/break/merge, connected drag/rotate/flip), read
`doc/claude/WIRING.md` — data model, END pipeline, pass contracts, landmines, open risks.
Keep it updated when fixing wiring issues.
