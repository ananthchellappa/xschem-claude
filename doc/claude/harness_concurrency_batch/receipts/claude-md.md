# claude-md — CLAUDE.md is rewritten to the new harness contract, and the `Start`/`Finish` hole is filed as 1481

**Status:** DONE

**Headline.** `CLAUDE.md`'s Tests section described a harness that stopped existing
hours earlier. Nine passages corrected in the house confessional style, all dated
**2026-09-17**, none of the existing ⚠ confessions removed. The new defect R1-build
found was **not** already filed and is now issue **1481**. Two things the driver's
brief did not ask for turned up and are done: R1-build's **seventh** CLAUDE.md item,
which the brief omitted, and a **stale source citation** (`run_regression.tcl:327` →
`:376`) that no list mentioned.

**⚠ No suite was run, no build, no `./src/xschem`.** Another crew holds the suite slot.
Every command below is read-only and carries a `timeout`.

---

## Files touched

| file | +/- | what |
|---|---|---|
| `CLAUDE.md` | +141/−32 (net +109) | nine corrections in the Tests section, below, plus one sentence of the SOLO bullet's history paragraph |
| `doc/claude/issues/NUMBERING.md` | +24/−1 | 1481 entry; pointer 1481 → 1482 |
| `doc/claude/issues/1481-the-nodisplay-arm-skips-its-finish-line-so-the-start-finish-case-count-under-counts-by-eleven.md` | new | the minted issue |

**Not touched, deliberately:** `tests/run_regression.tcl`, `tests/test_utility.tcl`,
the four reserved suite files, `DECISIONS.md`, `LEDGER.md`, `PLAN.md`, every `.js`
under `doc/claude/ledger/`, and `tests/headless/owed.sh`.

### The eight corrections, by anchor

| # | anchor | was | now |
|---|---|---|---|
| 1 | `:61` first bullet | silent on which file is yours | ⚠ **your answer is `tests/results.<pid>.log`**; `results.log` is a *copy* held by whichever run finished last; per-case logs `<name>.<pid><suffix>`; the by-hand path is unchanged because an unset `T1_LOG_TAG` means the old name |
| 2 | `:102` head of "Reading `results.log`" | counting rules first | ⚠ **READ THE TRAILER FIRST**: `T1-RUN-BEGIN`/`T1-RUN-END` at `run_regression.tcl:694`/`:916`, `-buffering line`, **no `T1-RUN-END` ⇒ did not finish**, and neither sentinel can match a counted shape (row `V4a`) |
| 3 | `:117` | *"**rc 2 means nothing ran**"* | ⚠ marked **FALSE**, with the grep that shows the `exit 2` path is gone, and the correction that **rc 2 now tells you nothing either** |
| 4 | `:143` fossil bullet | *"only its mtime ever said otherwise"* | ⚠ no longer true — `T1-RUN-BEGIN` names pid and start time, so a fossil is self-identifying **from content**; trap unchanged, detection no longer forensic |
| 5 | `:207` | counted shapes *"at `run_regression.tcl:327`"* | `:376`, with the note that it read `:327` until today, before the driver grew 305 lines |
| 6 | `:174` + `:183` arithmetic block | 84 cases / 83 lines, `Start`/`Finish` pairs | ⚠ **re-measured: still 84** (20→36 is checks *inside* one case); ⚠ **the file is now 85 lines** (83 + 2 sentinels), a third number for a paragraph already wrong with two; ⚠ **the NODISPLAY `Start`/`Finish` hole**, with issue **1481** |
| 7 | `:217` the 1477 bullet | *"Nothing marks that a run began or ended"*, full-buffered at 4096 B | ⚠ both halves fixed; **the dangerous half is not**: every prefix of a green run still scores zero, now stated as measurement by row `V3c` (800 counted failures → **ZERO** when cut to one line). The death is **decidable**, not gone |
| 8 | `:259` "CHECK MTIME, NOT THE MD5" | rests on *"byte-deterministic for a green run"* | ⚠ **wrong for the THIRD time**, in the confessional style the bullet already uses: sentinels carry pid + two timestamps + elapsed, so md5s **always** differ and a *changed* md5 now proves nothing either. **Stop hashing this file** |
| 9 | `:271` the SOLO bullet | *"refused loudly … exits 2 and writes nothing"* | replaced wholesale: **both runs proceed**, announced not refused; copy-never-rename and why; ⚠ **20% SLOWER** (64.4 s vs 53.7 s) and that what it buys is **no crew is turned away**; the lock demoted to a publish mutex with all three knobs; the refusal era datable to `43b40f04` → `32dff39a` |

Plus the closing sentence of the SOLO bullet's history paragraph, which read *"A number
taken today either held the lock or was refused"* — corrected, since nothing is refused.

## Rows added/changed

**None, and that is not an omission.** This is a documentation task on a file no suite
reads. The red-first rule is discharged by the issue instead: **1481** ships with an
explicit *"What holds it"* section saying it has **no row**, naming the two places one
belongs (`test_regression_concurrency_1476.tcl` or `test_suite_watchdog_1403.tcl`) and
the cheap `has_text` idiom (`W14`–`W19`) that would express it without a display.

## Commands run

All read-only, all with `timeout`, `/usr/bin/grep` never bare `grep`:

```sh
timeout 30 sed -n '820,940p;697,800p;585,700p;488,535p;305,322p' tests/run_regression.tcl
timeout 30 sed -n '23p;27,93p;309,318p' tests/run_regression.tcl | /usr/bin/grep -o '"[^"]*"' | wc -l
timeout 30 /usr/bin/grep -n "exit 2\|REFUS\|refus" tests/run_regression.tcl
timeout 30 /usr/bin/grep -n 'FAIL\$\|GOLD?\$\|RESULT?\$' tests/run_regression.tcl
timeout 60 /usr/bin/grep -rln 'Start/Finish\|NODISPLAY\|nodisplay' doc/claude/issues/
timeout 60 /usr/bin/grep -rn "73 .Finish\|84 .Start\|Finish=73\|under-count\|undercount" doc/claude/ tests/
timeout 60 /usr/bin/grep -rln 'NODISPLAY' /home/analog/dev/xschem-op-wcard/doc/claude/issues/
timeout 60 /usr/bin/grep -rn "64\.4\|53\.7" doc/claude/harness_concurrency_batch/ doc/claude/issues/
timeout 30 git log --oneline -8 -- tests/run_regression.tcl
# the full minting block from CLAUDE.md, verbatim, for n=1481 and again for the new pointer 1482
```

## Measurements

| measurement | value | command |
|---|---|---|
| case lists | **3 / 69 / 11** (+1) = **84**, unchanged | `sed -n '23p'/'27,93p'/'309,318p' \| /usr/bin/grep -o '"[^"]*"' \| wc -l` |
| `Finish` lines with no dev display | **73** = 84 − 11 | static: `continue` at `:841` precedes `puts "Finish …"` at `:872`; `tcases` `:736`, `hcases` `:792`, xschemtest `:895` are unconditional |
| counted-shape regexps | `run_regression.tcl:376` (CLAUDE.md said `:327`) | `/usr/bin/grep -n 'FAIL\$…'` |
| sentinels | `:694` BEGIN, `:916` END, `fconfigure` immediately before BEGIN | `sed -n '585,700p'`, `sed -n '900,930p'` |
| knob defaults in shipped source | `T1_LOG_LOCK_WAIT 60`, `T1_LOG_LOCK_TTL 300`, `T1_VERDICT_KEEP 86400` | `:930-931`, `:656`, doc block `:512-530` |
| refusal path | **absent** — the only `exit 2` matches are prose in comments | `/usr/bin/grep -n "exit 2" tests/run_regression.tcl` |
| 1481 free? | band check silent; no issue file in **either** clone; only this clone's `NUMBERING.md` pointer line matched | the full minting block |
| diff | **141/32** CLAUDE.md, **24/1** NUMBERING.md | `git diff --numstat` — ⚠ this row said `+170/−33` until I re-ran it; `--stat`'s single number is *changed* lines, not insertions, and I had read it as insertions. The same conflation this file's own case-count paragraph is about |

## Claims checked vs taken on trust

The brief said to treat its seven-item list as a hypothesis and to say so loudly where
R1-build disagrees. **R1-build's receipt and the source agree with the brief on six of
seven items; the seventh is a case where the brief was too weak, and the brief also
dropped one of R1-build's items entirely.**

### CONFIRMED (checked against `receipts/R1-build.md` *and* the source, not one or the other)

1. **Item 1 — the SOLO bullet is obsolete and `rc 2` no longer means nothing ran.**
   CONFIRMED twice over: R1-build `:310-315`, and `/usr/bin/grep -n "exit 2"` on the
   shipped driver returns only comment prose. The banner at `:658-674` announces and
   proceeds. Corrected as instructed, not softened.
2. **Item 2 — read the trailer, keep the mtime paragraph.** CONFIRMED (R1-build
   `:297-306`). Kept the fossil and 1477 paragraphs and marked what each one loses.
3. **Item 3 — a green verdict is no longer byte-deterministic.** CONFIRMED from the
   source: `T1-RUN-BEGIN` carries `pid=` and `start=`, `T1-RUN-END` carries `pid=`,
   `end=` and `elapsed=`. Written in the same confessional style, as the third failure
   of that bullet.
4. **Item 5 — the knob retunings.** CONFIRMED against the shipped defaults at `:930-931`
   and `:656`, not against the receipt's prose. Documented in the SOLO bullet, with the
   *reason* each default moved (the driver's own comment block `:512-530` explains it
   better than any summary and is the source for the "0 would make the lock decorative"
   clause).
5. **Item 6 — concurrency is 20% slower.** CONFIRMED and traced to its origin:
   `receipts/R1-recon.md:291-292` and `:469-470` (`date +%s.%N` either side), echoed by
   `DECISIONS.md:254-255` and `LEDGER.md:280`. R1-build itself lists this figure under
   *taken on trust*, so the primary source is R1-recon. Written with the benefit named
   — **no crew is turned away** — and an explicit sentence forbidding the throughput
   reading.
6. **Item 7 — the NODISPLAY defect is real and unfiled.** CONFIRMED in the source
   (`continue` at `:841`, `Finish` at `:872`) and confirmed unfiled by three searches,
   including the other clone. Minted as **1481**.

### CORRECTED

7. ⚠ **Item 4 — the case count. The brief asked "check whether R1-build changed it";
   the honest answer is "no, and there is now a THIRD number in play".** The count is
   **still 84** — 20→36 is checks within one case, exactly as the brief guessed, and
   `test_regression_concurrency_1476` was already the 69th `hcases` entry. But the
   verdict **file** now carries the 83 `Total num fail:` lines **plus two sentinel
   lines**, so `wc -l` answers **85**. That paragraph has already been wrong twice by
   conflating cases with lines; a third plausible number in the same neighbourhood is
   precisely the shape of the first two errors, so it is written out explicitly rather
   than left for the next reader to trip over.
8. ⚠ **A stale citation nobody's list caught.** CLAUDE.md placed the four counted shapes
   at `run_regression.tcl:327`. They are at **`:376`** — the driver gained 305 lines in
   `32dff39a`. Both R1-build's seven-item list and the driver's brief cite the paragraph
   containing this line without noticing the line number inside it moved. Fixed, with
   the old value recorded inline.

### The brief was incomplete

9. ⚠ **R1-build's list has SEVEN items and the driver's brief carries six of them plus
   the NODISPLAY find. R1-build's item 7 was dropped.** It reads: *"`:65`/`:59` — a crew
   should be told its own answer is `tests/results.<pid>.log` whenever another run may
   have been live."* Nothing in the brief asks for it. It is arguably the single most
   *operationally* useful sentence of the whole change — a crew that reads `results.log`
   while another run is live now gets an answer that is complete, well-formed and
   **somebody else's** — so it is done anyway, as correction 1 in the table above, at the
   first bullet where a reader meets the filename.

### Taken on trust (NOT verified by me — I ran no suite and no driver)

* **The 84/73 split is derived, not observed.** I did not run T1 with the display down;
  I read the code and did the arithmetic (84 `Start`, minus 11 arms that `continue`
  before their `Finish`). R1-build states the same two numbers independently. The issue
  file says so in as many words rather than implying a measurement.
* **`V3c`'s 800-vs-ZERO and `V4a`'s sentinel non-counting.** Quoted from R1-build's row
  table; I did not re-run the suite.
* **64.4 s / 53.7 s.** R1-recon's measurement, which R1-build also took on trust. Two
  receipts deep, and worth re-measuring before anyone builds on it — but it is the only
  number in the batch for this question and it is directionally confirmed by two
  independent write-ups.
* **That T1 is at zero today.** Not my slot.

## Corrections to PLAN.md / for the driver

* ⚠ **`CREW_BRIEF.md:29-31` is now teaching the obsolete rule to every crew this batch
  still dispatches.** It says: *"Read `results.log` itself … confirm its **mtime moved**
  first (a green run is byte-deterministic, so an unchanged md5 proves nothing)"*.
  Both clauses are now wrong — the mtime rule is superseded by `T1-RUN-END`, and a green
  run is no longer byte-deterministic. R1-build flagged this at its `:286-287`. **It is
  not my file and I did not touch it.** One sentence — *"read the trailer; your answer
  is `results.<pid>.log`"* — closes it, and every crew briefed before that lands will
  apply a rule this batch retired.
* **The driver's brief omitted R1-build's item 7** (see finding 9). Worth checking
  whether other items were dropped when this batch's remaining briefs were written from
  summaries rather than from the receipts.
* **1481 ships with no row.** If the batch wants coverage, the cheap source-text guard
  belongs in `test_regression_concurrency_1476.tcl` and costs milliseconds.

## Left dirty

`git status --porcelain` at hand-off, verbatim:

```
 M CLAUDE.md
 M doc/claude/issues/NUMBERING.md
 M tests/headless/test_ase_core.tcl
 M tests/headless/test_no_untitled_litter.tcl
 M tests/headless/test_op_dump_altshow.tcl
?? .xschem/
?? doc/claude/harness_concurrency_batch/receipts/claude-md.md
?? doc/claude/issues/1481-the-nodisplay-arm-skips-its-finish-line-so-the-start-finish-case-count-under-counts-by-eleven.md
?? doc/claude/rdw_lists_batch/
?? doc/claude/rdw_sim_batch/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
```

**Mine are exactly three:** `CLAUDE.md`, `NUMBERING.md`, and the two new files (the 1481
issue and this receipt).

⚠ **The three modified `tests/headless/` files are NOT mine and were not dirty when this
task began** — the session's opening status does not contain them. All three are on this
task's explicit do-not-touch list, so another crew is editing them concurrently, and the
driver should expect their receipt rather than attribute these to me. I did not read,
edit, or run them.

The four `??` directories at the bottom pre-date this task (they are in the session's
opening status). **Nothing committed.** No binary was built and no test ran, so `src/xschem` is
exactly as R1-build left it. ⚠ **Note for the driver:** R1-build's eight modified files
are no longer in `git status` — they were committed as `32dff39a` between that receipt and
this task, which is where this receipt's commit citation comes from.

## Owed to the user

**Nothing, and I did not touch `owed.sh`.** Every decision here is a documentation
faithfulness question with one correct answer — does the file describe the harness that
exists — and none of it changes program behaviour or produces a sentence a user sees.
Issue 1481 records an OPEN defect with two fix directions; choosing between them is a
future implementer's call, not a user ruling, since neither reaches a person outside the
harness.
