# Receipt A — register the Calculator suites and fence the registration lists (issue 1626)

Stage **A** of `doc/claude/calculator_batch/`, worked 2026-09-30 on `fluid-editing` at
`621c1ff5`. **Nothing is committed** — the work is left in the tree for the driver, which
also keeps the T1 gate.

---

## 1. What I changed, by symbol

| file | what |
|---|---|
| `tests/run_regression.tcl` | **`dcases`**: two entries added, `"headless/test_calc_skeleton"` and `"headless/test_calc_widgets"`. **`hcases`**: one entry added, `"headless/test_registered_banner_1626"`. One comment block added to the run of `##` notes that follows `dcases`, naming why the shape is `dcases`-alone for the calculators, why the new fence is not a section-K row, and that `skips=` must be read rather than predicted. |
| `tests/headless/test_calc_skeleton.tcl` | the final verdict block (the `if {$fail == 0}` at end of file) now prints `OVERALL: ok ($npass checks)` **before** its existing `RESULT: ALL PASS` line, on the success path only, with the comment explaining the rule and why the no-DISPLAY early exit gets no banner. Nothing else touched. |
| `tests/headless/test_calc_widgets.tcl` | same change to its one-line verdict block; same comment, plus the explicit decision about `RESULT: SKIP (no X …)`. |
| `tests/headless/test_registered_banner_1626.tcl` | **NEW.** The structural fence. Procs: `rb_slurp`, `rb_decomment`, `rb_code`, `rb_list_items`, `rb_brace_body`, `rb_puts_args`, `rb_render`, `rb_var_literals`, `rb_sourced`, `rb_suite_path`, `rb_emitters`, `rb_naive_hit`, plus `check`/`pcall`/`flat`. Rows `RB0`, `RB1`, `RB2`, `RB3`, `RB3b`, `RB4`, `RB5`. |

### Where the row lives, and why not section K

The task named `tests/headless/test_audit_classifier.tcl` section K as the obvious home. I
did not put it there, for one decisive reason I measured rather than assumed:

```
$ /usr/bin/grep -c 'audit_classifier' tests/run_regression.tcl   # 1, and it is PROSE
```

**`test_audit_classifier` is in neither `hcases` nor `dcases`.** A fence placed there would
be run by nothing and would gate no commit — which is issue 1626's own defect one level up.
Section K's existing rows are untouched; I ran that suite and it still passes
(`ALL PASS (75 checks)`, below).

The new suite is registered in `hcases`, so **it also checks itself** — `RB2` reads the
registration lists out of the driver's text and `test_registered_banner_1626` is one of the
96 entries it scores.

### The method, stated as the row names state it

* the suite list is **lifted from `run_regression.tcl`'s own text at runtime** (`rb_list_items`
  over `set hcases [list` / `set dcases [list`). A hand-kept copy would be the same defect one
  level up.
* the verdict is `tests/banner_rule.tcl`'s **own `banner_complete`**, sourced. `RB5` asserts
  this file spells no banner regexp of its own.
* a suite "can emit the banner" when a `puts` **to stdout** has an argument whose *rendered*
  text `banner_complete` accepts, following the `source` chain transitively and one level of
  same-file variable assignment.

**The tree uses four mechanisms to emit that line, not one, and I found two the brief did not
name.** This is the single most load-bearing measurement of the stage:

| mechanism | example | a one-file text scan sees it? |
|---|---|---|
| literal | `puts "OVERALL: ok"` (most suites) | yes |
| counted literal | `puts "OVERALL: ok ($npass checks)"` (`test_pdk_launcher`) | yes |
| **computed by `expr`** | `puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"` — **13 registered `test_ase_*` suites** | **no** |
| **from a sourced common** | `wvbs_finish` in `wvbs_common.tcl` (`test_wave_sigbrowser_panes`) | **no** |
| **from a variable** | `set summary [expr …]` then `puts $summary` — `tests/hilight_hier_oracle.tcl` and its two siblings | **no** |

`RB4` re-measures the gap every run and prints the names, so nobody can replace `rb_emitters`
with a grep without reddening and being shown their own false reds.

---

## 2. The red, verbatim

Order was: **register first, with no sentinel; write the fence; run it.** The fence was
therefore red on a tree where nothing had been fixed yet.

`./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_registered_banner_1626.tcl`,
armed HOME, `DISPLAY` unset:

```
ok:   RB0 the hcases and dcases lists were lifted from the driver's own text and are non-empty
ok:   RB1 every one of the 96 registered entries resolves to a suite file (both spellings: headless/<name> and a bare name in tests/)
FAIL: RB2 every registered suite has a stdout puts whose rendered argument banner_rule.tcl's own banner_complete accepts, source chain and one assignment level resolved -> {headless/test_calc_skeleton headless/test_calc_widgets} (exp {}) : FAIL
ok:   RB3 the predicate's own controls: 10 synthesized suites, 4 that must be accepted and 6 that must be rejected
ok:   RB3b a suite whose own text has no banner and whose sourced common prints one is accepted (the source chain is followed)
ok:   RB4 the plausible wrong implementation -- a one-file scan of the suite's own non-comment text -- would false-red 14 registered suites this predicate accepts: test_ase_campaign_1462 test_ase_campaign_gui_1464 test_ase_conv_gui_1460 test_ase_converge_1459 test_ase_effective_1442 test_ase_events_1465 test_ase_meas_1443 test_ase_optsheet_1441 test_ase_simwin_variant_1471 test_ase_sp_1452 test_ase_trnoise_1466 test_ase_trnoise_gui_1467 test_ase_variant_1470 test_wave_sigbrowser_panes
ok:   RB5 this file sources the shared rule, calls banner_complete, and spells no banner regexp of its own
OVERALL: 1 FAILED (6 passed)
RESULT: 1 FAILED (6 passed)
```

and through the armed driver, `tests/headless/run_suites.sh --nogui test_registered_banner_1626`:

```
FAIL     | test_registered_banner_1626  run 1/1  RESULT: 1 FAILED (6 passed)
         | FAIL: RB2 every registered suite has a stdout puts whose rendered argument banner_rule.tcl's own banner_complete accepts, source chain and one assignment level resolved -> {headless/test_calc_skeleton headless/test_calc_widgets} (exp {}) : FAIL
RESULT: 0/1 runs passed
```

### The driver's premise, re-verified before any of that

Both suites, both arms, armed HOME, at `621c1ff5` with no edits:

```
test_calc_skeleton.before.disp.txt    RESULT: ALL PASS (545 checks)
test_calc_skeleton.before.nogui.txt   RESULT: ALL PASS (0 checks)
test_calc_widgets.before.disp.txt     RESULT: ALL PASS (244 checks)
test_calc_widgets.before.nogui.txt    RESULT: SKIP (no X: the Calculator widget inventory is Tk-only)
```

and `banner_complete` / `regression_case_failed` from `tests/banner_rule.tcl`, sourced, over
those four real outputs:

```
test_calc_skeleton.before.disp.txt    banner_complete=0 banner_died=0 case_failed(exit0)=1
test_calc_skeleton.before.nogui.txt   banner_complete=0 banner_died=0 case_failed(exit0)=1
test_calc_widgets.before.disp.txt     banner_complete=0 banner_died=0 case_failed(exit0)=1
test_calc_widgets.before.nogui.txt    banner_complete=0 banner_died=0 case_failed(exit0)=1
```

**The 0-check headless claim is mine, measured, not taken on trust** — `test_calc_skeleton`'s
`--nogui` arm really does print `RESULT: ALL PASS (0 checks)`. That is why `hcases` is wrong
for it: the entry would spend a whole case measuring nothing.

---

## 3. The green, each arm

`tests/headless/run_suites.sh test_calc_skeleton test_calc_widgets test_registered_banner_1626`
— **display arm** (attached to the dev display `:99`, left as found):

```
PASS     | test_calc_skeleton           run 1/3  RESULT: ALL PASS (545 checks)
PASS     | test_calc_widgets            run 2/3  RESULT: ALL PASS (244 checks)
PASS     | test_registered_banner_1626  run 3/3  RESULT: ALL PASS (7 checks)
RESULT: 3/3 runs passed
```

same command with `--nogui` — **headless arm**:

```
PASS     | test_calc_skeleton           run 1/3  RESULT: ALL PASS (0 checks)
SKIP     | test_calc_widgets            run 2/3 (self-skipped: no X — nothing ran)
PASS     | test_registered_banner_1626  run 3/3  RESULT: ALL PASS (7 checks)
RESULT: 2/2 runs passed (1 skipped)
```

Before → after, per suite per arm: `test_calc_skeleton` disp `ALL PASS (545 checks)` →
`ALL PASS (545 checks)`; `test_calc_widgets` disp `ALL PASS (244 checks)` →
`ALL PASS (244 checks)`. **The check counts are unchanged — the change is additive.** What
changed is the line above them.

### The sentinel is accepted, measured through the only Tcl reader

`banner_complete` sourced from `tests/banner_rule.tcl` over the real captured output:

```
test_calc_skeleton.after.disp.txt            banner_complete=1 banner_died=0 regression_case_failed(0)=0
test_calc_widgets.after.disp.txt             banner_complete=1 banner_died=0 regression_case_failed(0)=0
test_registered_banner_1626.after.nogui.txt  banner_complete=1 banner_died=0 regression_case_failed(0)=0
test_registered_banner_1626.after.disp.txt   banner_complete=1 banner_died=0 regression_case_failed(0)=0
```

The emitted lines, with `RESULT:` last on every one:

```
test_calc_skeleton  (display)   OVERALL: ok (545 checks)  /  RESULT: ALL PASS (545 checks)
test_calc_widgets   (display)   OVERALL: ok (244 checks)  /  RESULT: ALL PASS (244 checks)
test_calc_skeleton  (--nogui)   RESULT: ALL PASS (0 checks)                 -- no banner, by design
test_calc_widgets   (--nogui)   RESULT: SKIP (no X: …)                      -- no banner, by design
```

### `RESULT: SKIP (no X …)` gets NO banner. The decision and the reason

`test_calc_widgets`'s no-X gate runs **zero** checks. Adding a completion banner there would
make a run in which nothing happened claim it had finished and reported — a **worse** defect
than the one 1626 names, and the exact hollow-pass shape that suite's own gate comment already
refuses to copy from `test_calc_skeleton`. Three consequences, all intended:

1. as a `dcases`-only entry T1 never takes that path, so nothing is lost;
2. `full_audit.sh`'s `is_skip` matches `RESULT: SKIP` **before** `is_pass`, and
   `run_suites.sh` tests its skip arm before its pass arms, so both still classify it `SKIP`
   — confirmed above, `SKIP | test_calc_widgets … (self-skipped: no X — nothing ran)`;
3. if anyone later adds either calculator suite to `hcases`, T1 will score it
   `HARNESS: … (exit=0, OVERALL_ok=0, died=0)` — **loudly, and correctly**, because a case
   that measures nothing should not be green. I left `test_calc_skeleton`'s hollow
   `RESULT: ALL PASS (0 checks)` alone for the same reason; see §6.

---

## 4. T1 would now score them — proved without running T1

`tests/run_regression.tcl`'s scoring code was **lifted out of its own text** (not re-spelled):
`t1_carry_line` and `summarize_all` extracted by name from `\nproc <name> ` to the next
column-0 `}`, `eval`'d, `tests/banner_rule.tcl` sourced beside them, then run over the real
captures. `summarize_all`'s own regexp arms, printed from the lifted body:

```
ARM: if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
ARM: } elseif { [regexp {^(NOGOLD|NODISPLAY)} $line] } {
ARM: } elseif { [regexp {^skip:} $line] } {
ARM: } elseif { [regexp {^RESULT:} $line] } {
ARM: } elseif { [banner_complete $line] && [regexp {\([^)]*\)} $line] } {
```

Result:

```
test_calc_skeleton.after.disp.txt            | summarize_all: blocks+1 counted+0 skips+0
test_calc_widgets.after.disp.txt             | summarize_all: blocks+1 counted+0 skips+0
test_registered_banner_1626.after.nogui.txt  | summarize_all: blocks+1 counted+0 skips+0
test_registered_banner_1626.after.disp.txt   | summarize_all: blocks+1 counted+0 skips+0
TOTALS: blocks=4 counted_failures=0 skips=0
```

and the blocks it wrote, which is what the verdict file will contain:

```
test_calc_skeleton.after.disp.txt
RESULT: ALL PASS (545 checks)
Total num fail: 0
test_calc_widgets.after.disp.txt
RESULT: ALL PASS (244 checks)
Total num fail: 0
test_registered_banner_1626.after.nogui.txt
RESULT: ALL PASS (7 checks)
Total num fail: 0
```

---

## 5. The trailer delta, DERIVED

**I did not predict this from memory.** `summarize_all`'s skip arm is `regexp {^skip:}`,
lowercase, as printed above. Applied to all six real captured outputs:

| capture | `^skip:` | `^SKIP` | case-insensitive `^skip` | counted shapes (`FAIL$ GOLD?$ RESULT?$ ^FATAL`) |
|---|---|---|---|---|
| `test_calc_skeleton` disp | 0 | 0 | 0 | 0 |
| `test_calc_skeleton` nogui | 0 | 0 | 0 | 0 |
| `test_calc_widgets` disp | 0 | 0 | 0 | 0 |
| `test_calc_widgets` nogui | 0 | 0 | 0 | 0 |
| `test_registered_banner_1626` disp | 0 | 0 | 0 | 0 |
| `test_registered_banner_1626` nogui | 0 | 0 | 0 | 0 |

So, against the baseline `cases=113 blocks=112 counted_failures=0 skips=8` at `f3d60af9`:

* **cases +3** — `test_calc_skeleton` and `test_calc_widgets` are `Start` lines in the
  `dcases` loop; `test_registered_banner_1626` is one in the `hcases` loop.
* **blocks +3** — each of the three reaches `summarize_all`, which does `incr ::t1_blocks`;
  measured above as `blocks+1` apiece.
* **counted_failures +0** — zero counted shapes in all six outputs.
* **skips +0** — zero `^skip:` lines, and not merely zero lowercase ones: these suites emit
  **no skip announcement at all**, in any case, on any arm. There is no uppercase/lowercase
  trick hiding here, which is the trap that caught both a verifier and the driver on 1625.
* **`wc -l` +9** — each block is exactly three lines (label, `RESULT:`, `Total num fail:`),
  measured: 12 lines over 4 blocks.

**Expected trailer: `cases=116 blocks=115 counted_failures=0 skips=8`.** The `skips=` figure
holding at 8 for a seventeenth consecutive figure is a consequence of what these three suites
print, re-derived here from their real output — not a constant. **Read the trailer.**

---

## 6. Sabotage, and what each reddened

The tree was byte-restored from a scratch backup after every one, verified by `md5sum`.

### (a) sentinel removed from one calculator suite

`test_calc_widgets`'s verdict block put back to `puts "RESULT: ALL PASS …"` alone:

```
FAIL: RB2 every registered suite has a stdout puts whose rendered argument banner_rule.tcl's own banner_complete accepts, source chain and one assignment level resolved -> {headless/test_calc_widgets} (exp {}) : FAIL
RESULT: 1 FAILED (6 passed)
```

Reddens, and **names that suite and only that suite.**

### (b) the sentinel where a naive grep accepts it and a real run does not

Three variants, each applied to `test_calc_skeleton`, each leaving
`/usr/bin/grep -c 'OVERALL: ok'` on the file at **3 lines** — so a grep-based fence passes
all three:

| variant | what I wrote | `RB2` |
|---|---|---|
| whole-line comment | `## puts "OVERALL: ok ($npass checks)"` | **FAIL** `-> {headless/test_calc_skeleton}` |
| **tail comment carrying a whole `puts` statement** | `puts "RESULT: ALL PASS ($npass checks)" ;# puts "OVERALL: ok ($npass checks)"` | **FAIL** `-> {headless/test_calc_skeleton}` |
| unprinted string | `set banner "OVERALL: ok ($npass checks)"` | **FAIL** `-> {headless/test_calc_skeleton}` |

All three redden. The tail-comment variant is the one worth noting: dropping whole-line
comments is **not** enough, because a line scanner reads a `puts` parked after `;#` as code.
`rb_decomment` is what defeats it — a `#` opens a comment only in command position, so it
cuts the tail only when the previous non-blank character is `;` or `{` and we are not inside
a double-quoted word.

### (c) `RESULT:`-last ordering broken — and nothing catches it, because nothing breaks

`test_calc_widgets` changed to print `RESULT:` **before** the banner. Real run, display arm:

```
RESULT: ALL PASS (244 checks)
OVERALL: ok (244 checks)
```

* `RB2`: **green** — `ok:   RB2 …`
* `run_suites.sh`: **green** — `PASS | test_calc_widgets run 1/1 RESULT: ALL PASS (244 checks)`
* lifted `summarize_all` + `banner_complete`: **green**, `banner_complete=1`,
  `regression_case_failed(0)=0`, and the published block still reads
  `RESULT: ALL PASS (244 checks)`.

Nothing catches it **and nothing should**: `banner_complete` is `regexp -line` over the whole
captured body, `summarize_all` keeps the *last* `^RESULT:` line of which there is one, and
`run_suites.sh` does `grep -E '^RESULT' | tail -1`. All three are order-independent here.
`wvbs_finish`'s own comment says the same thing and this measurement confirms it on these
suites.

**So I measured the hazard the rule actually guards**, which is being the last `RESULT:` line
rather than being after the banner. One extra `RESULT: ALL PASS (0 checks)` line appended
after the real one, fed to the lifted `summarize_all`:

```
--- the block T1 would publish ---
sab_c2.txt
RESULT: ALL PASS (0 checks)
Total num fail: 0
TOTALS: blocks=1 counted_failures=0 skips=0
```

The published check count silently goes from **244 to 0** with **zero counted failures** and
nothing reddening in any of the three readers — `run_suites.sh`'s `tail -1` reports the same
wrong line. That is the coverage-loss hole issue 1487 exists to close, and it is **unfenced**.
Noted for the next stage; I did not widen scope to fix it.

### The fence's own controls

A predicate that answered "accepted" to everything would make `RB2` green while measuring
nothing. `RB3` is the battery that stops that — 10 synthesized one- and two-file suites
written into scratch, **4 that must be accepted** (literal, counted literal, computed by
`expr`, built-into-a-variable-and-printed) and **6 that must be rejected** (whole-line
comment, tail comment, unprinted string, written to a channel variable, failure spelling only,
quoted inside a check's own message). `RB3b` is the two-file source-chain case. `RB0` is the
anti-vacuity row: if the list lift silently returns nothing, `RB2` passes while measuring
nothing, so `RB0` asserts both lists are non-empty before `RB2` runs.

### Named limits of `RB2`, in the suite's own header as `L1`–`L5`

`L1` a substitution renders as the word `ok`, so `puts "OVERALL: $v"` is accepted without
anyone knowing what `$v` holds — conservative in the accepting direction on purpose, because
a false red here is a standing red in T1. `L2` variable resolution is one level and same-file.
`L3` a `puts` whose first word is a channel variable is treated as a write to that channel.
`L4` the scan is line-oriented: a `puts` split across a continuation, or a banner assembled
from two `puts -nonewline` calls, is missed. `L5` dead code is not detected — `RB2` answers
*could this suite ever emit it*, not *does this run emit it*. The run-level answer is T1
itself, which is what this stage exists to let T1 give.

### Neighbours that parse `run_regression.tcl` or scan the tree, run because I edited it

```
PASS     | test_audit_classifier        RESULT: ALL PASS (75 checks)     # K17-K22 intact
PASS     | test_scratch_home_note       RESULT: ALL PASS (22 checks)     # C1 lifts summarize_all
PASS     | test_regression_concurrency_1476  RESULT: ALL PASS (46 checks)
PASS     | test_op_annot                RESULT: ALL PASS (486 checks)    # V57, the dcases loop line
PASS     | test_home_isolation          RESULT: ALL PASS (116 checks)    # G2, new-file launcher scan
PASS     | test_issue_stamp             RESULT: ALL PASS (102 checks)
PASS     | test_snprintf_fmt_1608       RESULT: ALL PASS (48 checks)
```

---

## 7. What I got wrong, and what corrected me

**Four things, and the third is the one that would have shipped a standing red.**

1. **I first assumed the sentinel-less registered suites took the banner from a sourced
   common**, because that is what the brief and the issue say ("7 registered suites today take
   the sentinel from a sourced common"). My own census said 16 registered suites have no
   `OVERALL: ok` on any non-comment line of their own text. Reading four of them corrected me:
   **13 of those 16 are `test_ase_*` suites that COMPUTE it** —
   `puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"` — and only **one**,
   `test_wave_sigbrowser_panes`, uses a sourced common. The brief's figure of 7 is not what
   this method measures, and the mechanism it names is the minority one. `RB4` now re-measures
   **14** every run instead of quoting either number.

2. **I built the predicate as "the literal argument of a `puts`", ran it, and got three false
   reds** — `hilight_hier_oracle`, `hilight_hier_dump_replay`, `hilight_xwin_sync_headless`.
   They do `set summary [expr {$nfail ? … : "OVERALL: ok"}]` then `puts $summary`. A **fifth**
   mechanism nobody had named. Shipping that version would have put a **standing red in T1**,
   which is the thing CLAUDE.md says a fence must never become. `rb_var_literals` (one level,
   same file) closed it, and the measurement over all 96 entries is now exactly the two
   calculator suites.

3. **`RB4`'s first definition was trivially true and therefore worthless.** I defined "naive"
   as a line-anchored `^OVERALL: ok` over the file's text, which matches almost nothing
   because the sentinel always lives inside a `puts "…"`. The row reported **94** false reds
   out of 95 — a number so large it says nothing about the real gap. Re-defining "naive" as
   the plausible wrong implementation (the issue's own census method: the sentinel text
   anywhere on a non-comment line) brought it to **14**, which is informative and is the
   measurement that justifies `rb_emitters` existing.

4. **Tcl's brace counter reads comments inside a proc body.** My first prototype would not
   parse: `possible unbalanced brace in comment`, from a comment that said *"preceded by `;` `{`
   `[` or whitespace"*. Every literal brace in this file's code is now written as
   `[format %c 123]` / `[format %c 125]` and the header carries the constraint in capitals.

---

## 8. What I did NOT do, and why

* **No T1 run.** Explicitly the driver's job; a concurrent run plus hand-run suites can redden
  a gate. §4 and §5 are the honest unit-level substitute, and they are a substitute for
  *scoring*, not for *running*: only T1 can show the two `dcases` cases actually executing on
  the display arm inside the driver.
* **Nothing committed, pushed or stashed.** §9.
* **I did not fix `test_calc_skeleton`'s hollow `RESULT: ALL PASS (0 checks)`** on its no-X
  path, which `test_calc_widgets`'s own comment calls out as a hollow pass that scores a
  PASS in `full_audit.sh` having run nothing. Changing it to `RESULT: SKIP (…)` would change
  how `full_audit.sh` and `run_suites.sh` classify that arm — a real behaviour change to a
  reader outside this issue's scope, on an arm T1 will not run. Flagged in §10.
* **I did not fence the "a second `RESULT:` line silently rewrites the published count" hole**
  found by sabotage (c2). It is a defect in the *verdict's* coverage reporting, not in this
  issue, and it needs a ruling about where the row belongs. Flagged in §10.
* **I did not register the other ~334 unregistered headless suites.** CLAUDE.md's bounded rule
  is the adopted reading: a suite you add a fence to, you register in the same commit.
  `test_audit_classifier` is one of that tail and I left it there rather than expand scope —
  but that is exactly why the fence is not a row in it.
* **Nothing was verified by eye.** Every claim here is a row, a sourced predicate or a quoted
  command output. No `look` debt was incurred and none is needed: this stage has no pixels.

---

## 9. `git status --short` at the end

```
 M doc/claude/calculator_batch/PLAN.md
 M doc/claude/issues/NUMBERING.md
 M doc/claude/specs/calculator.md
 M src/calculator.tcl
 M tests/headless/test_calc_skeleton.tcl
 M tests/headless/test_calc_widgets.tcl
 M tests/run_regression.tcl
?? .xschem/
?? doc/claude/calculator_batch/CREW_BRIEF.md
?? doc/claude/calculator_batch/LEDGER.md
?? doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md
?? doc/claude/issues/1626-the-calculators-789-phase-0-and-1-checks-are-registered-in-nothing-because-neither-suite-prints-the-completion-banner.md
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/test_registered_banner_1626.tcl
```

⚠ **Four of those modified files are NOT mine, and one of them changed while I was working.**
Mine are exactly: `tests/run_regression.tcl`, `tests/headless/test_calc_skeleton.tcl`,
`tests/headless/test_calc_widgets.tcl`, and the new
`tests/headless/test_registered_banner_1626.tcl`.

* `doc/claude/issues/NUMBERING.md` was already modified at the session's start snapshot.
* `doc/claude/calculator_batch/PLAN.md` (19:12:05), `doc/claude/specs/calculator.md`
  (19:12:32) and `doc/claude/calculator_batch/LEDGER.md` (19:13:03, untracked) are the
  driver's.
* **`src/calculator.tcl` was modified at 19:19:52**, between my `tests/run_regression.tcl`
  edit (19:17:53) and my last restore (19:21:57) — i.e. **something else was writing this tree
  during my stage.** Its diff is a dead-pointer cleanup in `calc::build_stk`'s comment block
  (removing a citation to `doc/claude/calculator_batch/recon/catalogue_defects.md`, which was
  never committed on any branch). It is not mine and I did not touch it.
* `.xschem/`, `doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md`,
  the issue file, `CREW_BRIEF.md` and the `sky130A/.../debug_st1/` directory were all present
  before I started.

**The only consequence I could find:** my before-captures (545/244) pre-date that
`src/calculator.tcl` change and my after-captures and final runs post-date it, and both report
**545** and **244**. So the concurrent edit did not move either suite's check count, and the
before/after comparison in §3 is sound. The driver should still confirm nothing else of that
unit is half-written before gating.

No probe wrote anything: this stage ran no `xschem save` / `saveas`, and nothing under
`xschem_library/`, `tests/headless/gold/` or any tracked fixture was touched. All scratch is
under `…/scratchpad/A-register-1626/` (captures, the backup copies, the lifted-predicate
probes).

---

## 10. What the next stage must know

1. **Issue 1626's open item 2 is now closed and item 1 is done; the file still says
   `open=3`.** The driver should re-stamp it. Item 3 (the unregistered tail) was and remains
   out of scope.
2. **The brief and the issue are wrong about the sourced-common mechanism being the one that
   defeats a text scan.** It is the minority case (1 registered suite). The majority is the
   `expr`-computed banner (13 `test_ase_*` suites) and there is a third, `puts $var` (the three
   bare-name `hilight_*` entries in `tests/`). Anyone extending `RB2` must keep all three, and
   `RB4` reddens if they do not. Correction recorded here rather than in the dated receipts, as
   the brief requires.
3. **`test_audit_classifier` is in neither `hcases` nor `dcases`**, so section K — the tree's
   lock on the three banner readers — gates nothing today. That is a live instance of the same
   class as 1626 and worth its own decision; I did not take it.
4. **A second trailing `RESULT:` line silently rewrites a case's published check count to
   whatever the last one says, with zero counted failures and no reader reddening** (§6(c2),
   measured: 244 → 0). Nothing fences it. If the batch adds suites with multiple exit paths,
   this is how a coverage loss hides.
5. **`skips=` is derived, not predicted** (§5). Both calculator suites emit no skip
   announcement at all, uppercase or lowercase, on any arm, so the expected trailer is
   `cases=116 blocks=115 counted_failures=0 skips=8`. Read the trailer anyway.
6. **`test_calc_skeleton`'s headless arm is a hollow pass** (`RESULT: ALL PASS (0 checks)`,
   which `full_audit.sh` scores PASS having run nothing). Left alone deliberately (§8). If
   Phase 2 adds non-Tk rows to that suite, revisit the gate *and* the `dcases`-alone shape
   together — the moment some of its rows run headless, an `hcases` arm starts measuring
   something and will need the banner on that path too.
7. **Phase 2 adds fences to these suites, so Phase 2 registers what it fences.** Both are now
   `dcases` citizens, so a new row in either gates automatically — which is the whole point of
   this stage. A *new* suite still needs its epilogue checked against `banner_complete` before
   registration, and `RB2` will now say so before the gate does.
