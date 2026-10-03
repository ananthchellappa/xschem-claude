# Receipt I4 — a row that asserts the stall bound is armed where a hang is possible

**Task.** Close the hole receipt `I3-watchdog.md` §9 declared and handed to the driver: *"No row
asserts that these three suites source `scratch.tcl`. Delete the line and nothing in the tree
reddens."* Write the assertion as a **derivation**, never a list of suite names.

**Left uncommitted in the tree**, as the brief requires. No commit, no push, no full T1.

---

## 1. What changed, by file and symbol

**`tests/headless/test_suite_watchdog_1403.tcl`** — the host. A new section **LAYER 2b**, placed
after LAYER 1 and before the verdict, holding six procs and eight rows:

| symbol | what it derives |
|---|---|
| `wd_cmdwords` | every word in **command position** — first word of the script, of a bracketed or braced body, or after a `;` — with comment fragments dropped |
| `wd_loop_verbs` | the event-loop verbs a file issues as commands, from the single list `WD_VERBS` |
| `wd_case_list` | one registered case list, lifted from `run_regression.tcl`'s own text: the `set <var> [list` line plus its backslash continuations, then every quoted word |
| `wd_case_file` | a registered entry resolved under `tests/`, which is where the four bare-name entries live as well as the `headless/` ones |
| `wd_sourced_names` | the `.tcl` basenames a line **sources** (any number), `{}` for a line that is not a source command |
| `wd_closure` | the transitive `source` closure, resolved against the sourcing file's own directory then `tests/headless/` then `tests/` |
| `wd_arms_bound` | does anything in that closure arm a timer that **ends the process** — `after … __wd_fire`, or the suite's own `after <ms> {… exit …}` |

Rows `W20a`–`W20h`. The header's `FLOOR:` figure moved 32 → 40 and now says the figure is a
ratchet rather than a baseline.

**Three suites gained the bound** — one non-comment line each,
`source [file join [file dirname [info script]] scratch.tcl]`, below the suite's no-X gate where it
has one (I3's placement finding) with a comment naming row `W20h` as what fails if it is removed:

* `tests/headless/test_fluid_editing.tcl` — below the `HASX` gate
* `tests/headless/test_headless_guards_xarm_1492.tcl` — below the `::has_x` gate
* `tests/headless/test_selflog_grep_guard.tcl` — above its `check` definition; this file has no gate

`git diff --stat`: 318 insertions, 4 deletions over four files; **1** non-comment added line in each
of the three, **151** in the host.

---

## 2. The population and the predicate, with the measurement

**Scope chosen: REGISTERED** (`hcases` ∪ `dcases`, lifted from the driver's text) — **96 + 24 = 104
unique**, every one of which resolves to a file. Reason, stated in the section's own header: CLAUDE.md
records that most `tests/headless/test_*.tcl` files are in neither list and that the rule this project
adopted is the bounded half ("a suite you add a fence to, you register in the same commit"). An
unregistered file gates no commit; a **registered** case that hangs stalls the one run whose baseline
is zero. Demanding a bound in the unregistered tail would be a coverage claim this project has
deliberately not made.

**Population** = a registered entry whose file issues any of `vwait` `tkwait` `update` `toplevel`
`grab` **in command position** — the three commands that enter the event loop plus the two that make
the window a modal wait blocks on. **26 of 104.**

**Predicate** = the member's transitive `source` closure arms a process-ending timer. Sourcing is not
privileged: `W20f` requires a suite with its own `after <ms> {… exit …}` to pass.

### Two measurements that shaped the derivation

**Command position is load-bearing, and the bare-word scan was wrong on this tree.** Scanned as bare
words, 20 members come back; two of them are false:

```
test_callback_argc    <- toplevel   "has_x 1 on this arm; this key would put the real toplevel in fullscreen"
test_fluid_editing    <- grab       check "FE9 tolerance grab of an OFF-GRID endpoint (other end (800,3) FIXED)"
                                    xschem zoom_box ... ;# zoom out: big grab zone + precise-enough endpoint select
```

A detail string and the English word. Both would have been ordered to arm a bound they cannot use —
a false red on an innocent suite is how a fence gets deleted. Rows `W20c`/`W20d` pin the scan against
exactly those two shapes.

**Widget-class names cannot be in the verb list.** `label`, `text`, `entry`, `place` and `raise` are
Tk commands and ordinary words in a schematic editor's corpus. Measured: `test_calc_scratch_reuse`
scans as a `label` user because of `foreach {label rpn ds} {` — the brace makes `label` a command
word. The list is verbs only.

**Why `update` is in the list although `update` does not block.** Without it the population misses
`test_calc_widgets` and `test_calc_buffer`, which drive the Calculator through `calc::*` and issue no
`toplevel` of their own — so the hole I was sent to close would have stayed two-thirds open. The
honest reading of the population is *the cases that can be sent into a modal wait by product code*,
and reaching the event loop at all is the derivable signature of that. Measured verbs actually seen
across the 26: `toplevel, update, grab, vwait`.

---

## 3. The red, verbatim

**The row's first run, against the tree as I found it** (host suite, `--nogui`, armed HOME). Seven
controls green, the fence red — and the red was **not** the Calculator suites:

```
FAIL     | test_suite_watchdog_1403     run 1/1  RESULT: 1 FAILED (39 passed)
         | FAIL: W20h-no-registered-event-loop-case-is-left-WITHOUT-a-stall-bound -- but 3 of 26 do:
           headless/test_fluid_editing, headless/test_headless_guards_xarm_1492,
           headless/test_selflog_grep_guard -- each reaches the event loop and arms NO deadman, so a
           modal `tkwait` there has no upper bound except whatever driver happens to wrap it; give it
           `source scratch.tcl` below its no-X gate, or its own `after <ms> {... exit ...}`
```

**That is a finding, not an inconvenience:** three registered T1 cases that drive Tk had no stall
bound at all. I gave them one rather than narrowing the instrument to fit the tree, because a fence
tuned to the tree it was written against is the rot this row exists to prevent.

The seven controls in that same red run:

```
ok:   W20a-registered-lift-is-not-empty-resolves-and-covers-BOTH-case-lists -- 96 hcases + 24 dcases = 104 unique ... unresolved: none
ok:   W20b-derived-population-is-neither-empty-nor-every-registered-case -- 26 of 104 ... Verbs actually seen: toplevel, update, grab, vwait
ok:   W20c-scan-finds-an-event-loop-verb-in-command-position -- fixture issues `vwait` as a command; got {vwait}
ok:   W20d-a-verb-in-a-STRING-or-after-a-semicolon-comment-is-not-a-command -- ... got {}
ok:   W20e-bound-detector-follows-the-transitive-source-closure
ok:   W20f-bound-detector-accepts-a-suites-OWN-after-exit-deadman
ok:   W20g-bound-detector-says-NO-to-a-MENTION-and-to-a-plain-after-sleep
```

### The hole itself, reddened and restored

The bound deleted from `tests/headless/test_calc_buffer.tcl` — the one of I3's three suites not owned
by the sibling crew:

```
FAIL: W20h-no-registered-event-loop-case-is-left-WITHOUT-a-stall-bound -- but 1 of 26 do:
      headless/test_calc_buffer -- ...
```

Restored from a byte-exact backup: `md5 c189c1f06805806b0842006737a2cc92`, **identical to the
pre-sabotage file**, and the suite is back at `ALL PASS (130 checks)` on the display arm. The host
suite is green again at 40 checks.

`test_calc_skeleton` and `test_calc_widgets` are in the derived population (both, via `toplevel` /
`update`), so the same removal in either reddens `W20h` the same way — but they belong to another
crew and **I did not write them**, so that half is argued from the population membership and not from
an experiment.

---

## 4. The green, per arm

| suite | registered arm | before | after |
|---|---|---|---|
| `test_suite_watchdog_1403` | `hcases` → `--nogui` | `ALL PASS (32 checks)` | `ALL PASS (40 checks)` |
| `test_suite_watchdog_1403` | display (not registered there) | `ALL PASS (32 checks)` | `ALL PASS (40 checks)` |
| `test_fluid_editing` | `hcases` → `--nogui` | `SKIP (no X)` | `SKIP (no X)` |
| `test_selflog_grep_guard` | `hcases` → `--nogui` | `ALL PASS (390 checks)` | `ALL PASS (390 checks)` |
| `test_headless_guards_xarm_1492` | `dcases` → display | `ALL PASS (8 checks)` | `ALL PASS (8 checks)` |

Neighbouring fences, after the change: `test_scratch_home_note` `ALL PASS (22 checks)`,
`test_registered_banner_1626` `ALL PASS (10 checks)`, `test_calc_buffer` `ALL PASS (130 checks)`.

Host suite wall time, armed spelling: **19 s** — the hang fixtures dominate; the text scan over 104
files plus closures is not measurable against them.

---

## 5. The T1 delta, derived with `summarize_all`'s own arms

Method: `summarize_all`'s body extracted from `tests/run_regression.tcl` by brace counting, then
**every** `regexp {…} $line` arm lifted out of that body and the banner fallback clause with it —
**8 arms lifted**, and the probe **refuses to score** unless all seven counted/uncounted arms plus
the fallback are present. `banner_complete` / `banner_died` come from `tests/banner_rule.tcl`, the
only Tcl reader `run_regression.tcl` sources. Captures taken with T1's own child command shapes
(`hccmd`'s `--nogui --pipe -q --script`, `dccmd`'s `devdisplay.sh exec … --pipe -q --script`) under a
real armed throwaway HOME, before **and** after, with the before state produced by restoring the HEAD
text of all four files in place and then restoring mine byte-exactly.

```
ARMS LIFTED: 8 -> {FAIL$} {GOLD\?$} {RESULT\?$} ^FATAL ^(NOGOLD|NODISPLAY) ^skip: ^RESULT: {\([^)]*\)}
```

| suite / arm | counted | `^skip:` | `^SKIP` | published `^RESULT:` | `banner_complete` | published count |
|---|---|---|---|---|---|---|
| watchdog / `--nogui` | 0 → 0 | 0 → 0 | 0 → 0 | 1 → 1 | 1 → 1 | 32 → **40** |
| watchdog / display | 0 → 0 | 0 → 0 | 0 → 0 | 1 → 1 | 1 → 1 | 32 → **40** |
| fluid_editing / `--nogui` | 0 → 0 | 0 → 0 | 1 → 1 | 1 → 1 | 1 → 1 | `SKIP (no X)` |
| fluid_editing / display | **1 → 1** | 0 → 0 | 0 → 0 | 1 → 1 | **0 → 0** | `1 FAILED (25 passed)` |
| selflog / `--nogui` | 0 → 0 | 0 → 0 | 0 → 0 | 1 → 1 | 1 → 1 | 390 → 390 |
| selflog / display | 0 → 0 | 0 → 0 | 0 → 0 | 1 → 1 | 1 → 1 | 394 → 394 |
| xarm_1492 / `--nogui` | 0 → 0 | **1 → 1** | 0 → 0 | 1 → 1 | 1 → 1 | `SKIP (no display)` |
| xarm_1492 / display | 0 → 0 | 0 → 0 | 0 → 0 | 1 → 1 | 1 → 1 | 8 → 8 |

**Derived delta on every trailer term: `cases` +0, `blocks` +0, `counted_failures` +0, `skips` +0,
`wc -l` +0.** Nothing was registered or deregistered. The only figure that moves is the host's
published check count inside its own block, which replaces a line rather than adding one.

Two cells are worth naming because they look like deltas and are not:

* `test_fluid_editing`'s **display** arm is `counted=1` / `banner_complete=0`, **before and after**,
  on row `FE8 drag-and-return changed the arc AND left buffer MODIFIED (no false-clean) (mod=0 a=30)`.
  **Pre-existing, measured at HEAD before I touched the file, byte-identical after.** It is not its
  registered arm: the suite is `hcases` only, where it self-skips.
* `test_headless_guards_xarm_1492`'s `--nogui` arm emits one lowercase `skip:`. It is `dcases` only,
  so T1 never runs that arm, and the figure cannot reach the trailer.

Per CLAUDE.md and the brief: this zero is a derivation, **not** a prediction about `skips=8`. Read the
trailer.

Line-by-line diff of the captured bodies, pid-carrying line 1 excluded: **0 differing lines** for all
three edited suites on both arms; **16** for the host, being the 8 new `ok:` lines, the `RESULT:`
count, and three values that differ run to run (two elapsed-ms figures, one child pid in a path).

---

## 6. The sabotages — seven, all reddening

Each applied to the green tree, measured, then reverted from a byte-exact backup.

| # | the plausible wrong implementation | rows that caught it |
|---|---|---|
| S1 | bare-word scan instead of command position | `W20d`, `W20h` (population 34, `test_callback_argc` ordered to arm a bound) |
| S2b | detector says yes to a **mention** of `scratch.tcl`, or to any `after` | `W20g` |
| S3 | detector reads only the suite's own text, no closure | `W20e`, `W20h` (25 of 26 "unbounded") |
| S4b | the case-list lift silently returns nothing | `W20a`, `W20b` |
| S5 | the verb list emptied | `W20b`, `W20c` |
| S6 | population scoped to `dcases` only | `W20a` |
| S7 | **the hole**: the bound deleted from `test_calc_buffer` | `W20h` |

**Two of these survived the first draft, and both fixes are in the code because of it:**

* **S2 survived.** `W20g`'s negative fixture was a bare `vwait` with nothing else in it, so a detector
  grepping for the word `scratch.tcl`, or for `after`, had nothing to be fooled by and the row passed.
  The fixture now carries all three near-misses deliberately — `scratch.tcl` named in a comment,
  `scratch.tcl` named on a code line that is not a `source`, and `after 25 ; update` (the small-sleep
  shape `test_calc_widgets` really uses).
* **S6 survived.** Dropping `hcases` from the union — one word, and the likeliest future edit if
  somebody decides "the GUI cases are the `dcases` ones" — left every row green with the fence walking
  24 cases instead of 104. `W20a` now asserts the **size relation** between the set the fence actually
  walks and both lifts, not merely that the lifts parsed.

---

## 7. `test_calc_scratch_reuse` — excluded on the predicate, measured not named

I3 §2 flagged it. Measured here over its own text:

```
command position  vwait/tkwait/grab/toplevel/update : no, none of the five
anywhere in text  vwait 0, tkwait 0, grab 0, toplevel 0, update 0, winfo 0, wm 0, bind 0, event 0, exec 0
sources anything?  : NO
the `label` decoy  : scans as a command   (foreach {label rpn ds} {)
```

Not one of the five verbs appears **anywhere** in the file, in or out of command position. So it falls
out of the population on the derivation itself, with no name-based exception — and the honest options
I was asked to choose between resolve on evidence rather than taste: **I did not give it the bound.**
A `source scratch.tcl` there would arm an `after` timer in a process that never reaches the event
loop, where a timer provably cannot fire (I3 §4 measured that even a stretch of pure `update
idletasks` does not service timers; this file has not even that). A guard that cannot fire is a guard
that measures nothing — the same defect class as the hand-kept row that silently measured 24 of 31.
If the file ever gains an `update`, the derivation picks it up and demands a bound; that is the
ratchet, and it needs no edit here.

---

## 8. Non-vacuity, and what each control would catch

Five of the eight rows exist only so that the fence cannot pass while measuring nothing:

* `W20a` — the lift is non-empty, every entry resolves, and the walked set **covers both lists**.
  Catches a lift that silently returns `{}` (S4b) and a silent scope narrowing (S6).
* `W20b` — the population is neither empty nor every registered case. Catches an emptied verb list
  (S5) and a scan that matches everything.
* `W20c` / `W20d` — the scan classifies in **both** directions on fixtures with a known answer: a
  verb in command position is found, and the same verb inside a string or after a `;#` is not.
  Catches a bare-word scan (S1).
* `W20e` / `W20f` / `W20g` — the bound detector classifies in **all three** directions: through a
  two-level source closure, on a suite's own deadman, and **negatively** on a file that merely names
  `scratch.tcl` and calls a plain `after`. `W20g` is the one that catches a detector answering yes
  unconditionally (S2b).

---

## 9. What I got wrong during the stage

1. **I assumed the population would already satisfy the predicate.** The task's own framing
   ("each member must arm a stall bound") reads as a tidy-up; the first run found **three registered
   suites with no bound at all**. The temptation was to narrow the population until the tree was
   green — which is exactly the rot the row exists to prevent — so the three suites got the bound
   instead. If I had narrowed instead, the fence would have been a description of the tree rather
   than a constraint on it.
2. **My first `W20g` fixture was too clean to be a control, and the sabotage pass is the only reason
   I know.** It passed under two reasonable wrong detectors. The row now carries three decoys, and
   the general lesson is in the code: a negative control must contain the **near-misses**, not merely
   the absence of the thing.
3. **My first S4 "sabotage" was not one.** I weakened the lift regexp to `^set $var \[list "` and it
   still matched, because both case lists really do have a quoted word on the opening line — so the
   row stayed green for a correct reason and I nearly recorded a survivor. Re-done as
   `\[list\s*$`, it reddens `W20a` and `W20b`. A sabotage that does not change behaviour measures
   nothing about the fence.
4. **I ran `tclsh -c` at one point**, which is not a flag `tclsh` has; it read stdin and hung until
   the tool's own timeout moved it to the background. No damage, but it is the second time this batch
   has paid for a command that looked like another tool's.

---

## 10. What I did NOT do, and the holes I am declaring

* **Did not write** `src/calculator.tcl`, `tests/headless/test_calc_measure.tcl`,
  `test_calc_skeleton.tcl` or `test_calc_widgets.tcl` (the sibling crew's). `test_calc_buffer.tcl`
  was temporarily sabotaged and restored byte-exactly; its md5 matches the pre-stage baseline.
* **Did not register anything** — `cases=`/`blocks=` cannot move.
* **Did not run a full T1**, did not commit, did not push, did not touch the `owed.sh` ledger,
  `~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display`, `~/.claude/gui_test_gate`, or
  `~/dev/xschem-op-wcard`. Ran `devdisplay.sh exec` only; never `start`, `stop` or `view`.
* **Did not delete any `/tmp/xschem_emergencysave_*`.** The count is **806 before and after**, and
  **none** of mine survived: the host suite's `W12`/`W13` reap only what their own child announced.

### Holes

1. **The host suite is blind to the removal of its OWN bound.** `wd_arms_bound` scans text, and
   `W20f`'s fixture literal `after 300000 {puts "suite deadline reached" ; exit 124}` lives in the
   host's text — so with its own `source scratch.tcl` deleted, the host would still classify as
   bounded. It is protected by a different mechanism rather than by this row: without that source,
   `test_scratch` is undefined and the suite dies at `set scratch [test_scratch wd1403]` with
   `invalid command name`, no banner, and T1 counts it. Declared rather than engineered around.
2. **The predicate recognises two deadman shapes, not every shape.** `after <ms> {… exit …}` and
   `scratch.tcl`'s arming. A suite whose deadman is `after $ms my_killer` with `exit` inside
   `my_killer` would be reported unbounded. The failure direction is a false red with a detail
   saying exactly what to add, not a silent pass.
3. **The scan over-includes rather than under-includes.** A verb at the start of a `;`-separated
   fragment inside a double-quoted detail string would still count. The two shapes this tree actually
   contains are fenced (`W20d`); a third would order a bound on an innocent suite.
4. **`test_fluid_editing`'s display arm is RED at HEAD** on row `FE8`, and **nothing gates it**: the
   suite is `hcases` only, and under `--nogui` it self-skips entirely, so all 26 of its rows gate no
   commit. Measured before and after my change, identical both times. Not mine to fix, and not
   something a `dcases` registration should be given without someone deciding about `FE8` first.
   This is CLAUDE.md's "does not gate a commit" theme arriving at a suite that **is** registered.
5. **`test_home_isolation` was not run.** My change adds no launcher and no script that starts
   xschem — the three edits are `.tcl` suite bodies — so row `G2` has nothing new to scan. Stated
   rather than assumed.

---

## 11. What the next stage must know

1. **W20h is a ratchet, and registering a new Tk-driving case without a bound will redden THIS
   suite**, not the new one. The detail line names the offender and what to add. That is the intended
   outcome; do not narrow the population to make it green.
2. **`skips=` is untouched by this stage**, derived with `summarize_all`'s own arms on both arms of
   all four suites. The one lowercase `skip:` in play belongs to `test_headless_guards_xarm_1492`'s
   `--nogui` arm, which T1 never runs because the suite is `dcases` only.
3. **The published check count of the host moved 32 → 40 and its header `FLOOR:` moved with it.** The
   header now says in as many words that the figure is a ratchet rather than a baseline, because one
   of the 40 walks the live case lists.
4. **I3 §9's hole is closed for all three Calculator GUI suites**, not one: `test_calc_skeleton`,
   `test_calc_widgets` and `test_calc_buffer` are all in the derived population, the first two
   through `toplevel`/`update` and the third through `update`. Phase 5's modal dialog will not change
   that.
