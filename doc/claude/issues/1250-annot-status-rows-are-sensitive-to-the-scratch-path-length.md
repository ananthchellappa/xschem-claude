# 1250 — `test_annot_stale_0684`'s status-message rows red when the scratch path is long, and F21 flaked once at the default path

Status: **FIXED** by item **A4** of `doc/claude/op_param_batch/PLAN.md`,
2026-09-02, test-side, with the 255-byte cap untouched. **Three statements in the
report below are WRONG and are corrected in the resolution section at the foot of
this file: the row set (six rows, not two), the cliff (root 121, not "between 120
and 124"), and F21 (which is not path-sensitive at all — it is a one-second
`file mtime` race, and its product half is now issue 1255).**
Originally measured by item A2's write-up pass, 2026-09-02 · Branch: `fluid-editing`
Related: **0886** (the elision was chosen there), **0990** (the other way a T1
number lies), **1244** item A2

## Why this matters more than a normal flake

**T1's baseline is ZERO counted failures.** A suite that reds one run in four is
the one place a real regression hides in plain sight, and this batch already
carries a rule about it (CLAUDE.md: *"a standing red is a defect, not
furniture"*). This one is worse than a standing red: it is intermittent, so a
crew that re-runs and sees green will wave it through.

## Part 1 — the deterministic half, reproduced on demand

`cadence::_annot_say` (`utils/annot_mode.tcl:755`) writes the held status line
through `cadence::_annot_fit` (`:724`), which **elides anything over 255 bytes**
and appends `...`. That was a deliberate choice (issue 0886: *"nothing is dropped
from the record, and the bar shows a marked elision instead of an amputation"*).

The sentence embeds the **absolute path of the raw**, and several rows of
`tests/headless/test_annot_stale_0684.tcl` assert a substring that sits near the
**end** of that sentence — which is exactly the part the elision eats first:

* `F17` — *"the second chord adds DC node voltages AND brings the numbers up to date"*
* `F21` — the ` These results were already loaded.` clause (`:276`)

`test_scratch` (`tests/headless/scratch.tcl`) puts the fixture under
`tests/headless/.scratch/_annot_stale_0684_<pid>/nd/mos.raw`, so the sentence's
length is a function of **where the repo lives** and of **how many digits the pid
has**. Measured by overriding `XSCHEM_TEST_SCRATCH` and changing nothing else,
on this tree at `e14d429e` + item A2:

| scratch root length | verdict |
|---|---|
| 100 | `ALL PASS (52 checks)` |
| 110 | `ALL PASS (52 checks)` |
| 120 | `ALL PASS (52 checks)` |
| **124** | **`1 FAILED (51 passed)` — F17** |
| 130 | `1 FAILED (51 passed)` — F17 |
| 132, 135 | `1 FAILED (51 passed)` — F17 |

```
FAIL: F17 ... -> {1 3 {id = 9m | gm = 7m | gds = 50u} 0}
              (exp {1 3 {id = 9m | gm = 7m | gds = 50u} 1}) : FAIL
```

The first three elements match: the annotation happened, the mask is right, the
numbers are right. **Only the message check moves.** The cliff is between a root
of 120 and one of 124.

The default root on this machine is
`/home/analog/dev/xschem-claude/tests/headless/.scratch` — **54 bytes**, so the
shipped configuration sits roughly 67–70 bytes clear of the cliff. A developer
who clones one directory deeper, or into `~/work/eda/vendor/…`, walks into a
deterministic red that has nothing to do with their change.

## Part 2 — the half that is NOT explained, and it is the one that was observed

The trigger for this issue was a **real** T1 run:

```
$ cd tests && DISPLAY=:99 GUI_GATE=0 tclsh run_regression.tcl
rc=0   counted failures = 2
111:FAIL: F21 CONTROL an already-loaded operating point is published by the press,
     and nothing is taken off or re-read behind it
     -> {{0 {-1 0 -1}} 0 1 1} (exp {{0 {-1 0 -1}} 1 1 1}) : FAIL
112:HARNESS: headless/test_annot_stale_0684 (display arm) did not complete cleanly
     (exit=1, OVERALL_ok=0, died=0) ... : FAIL
```

Again only the message element (the second) moved: `f21_pre`, the raw file
identity and the `raw annot` index were all correct, so the operating point
really was published from the right file.

**It did not reproduce.** On the same tree state:

* `run_regression.tcl` solo, three further runs: **0, 0, 0** counted failures;
* the suite standalone with `--nolog`: **4/4 ALL PASS (52 checks)**;
* the suite through the harness's own invocation, from `tests/`, no `--nolog`,
  `devdisplay.sh exec ../src/xschem --pipe -q --script …`: **6/6 ALL PASS**.

So: **1 red in 7 known T1 runs of this tree state** (this pass 1/4, the item's
verify-A pass 0/2, its measure pass 0/1).

**Part 1 does not explain part 2.** At the default root the message has ~67 bytes
of headroom, and a pid gaining a digit moves it by one. Something else made that
sentence come out short or different, and this issue does **not** identify it.
Candidates not ruled out: a second `_annot_say` overwriting the held line before
`xschem get statusmsg` read it, or a state difference only the full T1 ordering
produces (`test_op_annot`, `test_annot_show_menu` and `test_annot_blank_cause_0909`
share the display arm with it).

## It is not item A2

`TEXT_ANNOT_NAME` is written in exactly one place and **read nowhere**:

```
$ grep -rn TEXT_ANNOT_NAME src/ --include=*.c --include=*.h
src/actions.c:1222: * THE NAME CLASS (TEXT_ANNOT_NAME, ...)          <- comment
src/actions.c:1382:   * both. TEXT_ANNOT_NAME is deliberately ...    <- comment
src/actions.c:1396:  if(annot_name_token(t->txt_ptr)) t->flags |= TEXT_ANNOT_NAME;
src/xschem.h:464:#define TEXT_ANNOT_NAME 1024
src/xschem.h:501: * ... the TEXT_ANNOT_NAME content                   <- comment
src/xschem.h:983:              * bit 10 : TEXT_ANNOT_NAME             <- comment
```

One write, zero reads. No code path can branch on it, and F21 is a Tcl status
sentence in `utils/annot_mode.tcl`, a file item A2 does not touch.

## Recommended repair

Two separable pieces, in this order:

1. **Part 1, cheaply.** Either assert the message against the **CIW** sentence,
   which `_annot_say` emits **whole** (that asymmetry is deliberate and
   documented at `:742-746`), or have the suite's fixture live at a short,
   length-pinned path. The second is a one-line change in the suite; the first
   is the more honest one, because the row's subject is *what the surface says*,
   not *what fits*. **Do not** raise `_annot_fit`'s 255 to make a test pass —
   that limit is the status bar's, and 0886 ratified the elision.
2. **Part 2** needs instrumentation, not reasoning: have the suite record the
   full `f21_msg` (and `f17`'s) into its own log on failure, then wait for the
   next occurrence. A row that reds on a substring must print the string it
   actually got, or the next crew re-derives this whole page.

Until part 2 has a cause, **a T1 red naming `test_annot_stale_0684` F17 or F21
is not evidence about the change under test** — re-run it solo and standalone
before attributing it, and record both numbers.


---

# RESOLUTION — item A4, 2026-09-02

## What was actually measured before the fix (BEFORE transcript, verbatim)

Driving `XSCHEM_TEST_SCRATCH` and changing nothing else, default root 54 bytes,
7-digit pids on this box:

```
root=120 RESULT: ALL PASS (52 checks)|
root=121 FAIL: F17 the same through Alt-6: the second chord adds DC node voltages AND brings the numbers up to date|RESULT: 1 FAILED (51 passed)|
root=142 ... RESULT: 6 FAILED (46 passed)   [F16 F17 F36 F39 F43 F44]
ROOTLEN=121 PIDDIGITS=7 UNFITTED=256 FITTED=99 ELIDED=1 TAILMATCH=0
```

**Three corrections to the report above.**

1. **SIX rows are path-sensitive, not two.** `F16 F17 F36 F39 F43 F44`, each a
   `string match "$F_M1 Loaded results from *mos.raw."` against the **fitted**
   line. Cliffs: F17 at root 121, F36/F39/F43/F44 at 136, F16 at 142.
2. **The cliff is at 121, not "between 120 and 124".** The original pass sampled
   120 then 124 and missed the gap.
3. **F21 is not a path-length defect and does not belong in Part 1 at all.** Its
   sentence is the `live` arm, which pastes **no path**: 90 bytes, byte-identical
   when re-rendered against a 4009-byte path, `elided=0`, 165 bytes of headroom.

## Part 2 was fully explained, and it is a clock, not a budget

`op_annot::_db_stat` (`src/op_annot.tcl:1136`) is `{mtime size}` and `file mtime`
has **one-second** resolution. Row F19's press stamps `$F_RAW`; row F20 rewrites
the same file byte-identically ~1 ms later. Same second → the stamp survives →
`live` → *"already loaded"* → F21 green. Clock ticks between them → the stamp
mismatches → `op_annot.tcl:1354-1358` returns 0 → guard G11 detaches → state
`loaded` → the sentence becomes *"Loaded results from <path>."* and F21 reds.

Forced on demand with one `f_bump` before F20's rewrite, byte for byte the line
the real T1 run produced:

```
FAIL: F21 ... -> {{0 {-1 0 -1}} 0 1 1} (exp {{0 {-1 0 -1}} 1 1 1}) : FAIL
```

Window measured: 658–1513 µs on the `--nogui` arm, 9.8–10.9 ms on the display
arm; `run_regression.tcl` runs this suite on **both** (`:59` and `:91`). That is
~1.1–1.2 % per T1 run, and P(at least one red in 7 runs | p = 0.012) = 8.1 %, so
the "1 red in 7 runs" observation is an ordinary event and **there is no
unexplained residue to hunt**. All 22 sub-second stamp-then-rewrite pairs in the
suite were forced to tick at once; **only F21 reds**, so exactly one window is
consequential.

## The repair, and the recommendation that was refuted

**Issue 1250's own recommended repair is not implementable on this path** and was
not implemented. It says: *"Either assert the message against the **CIW**
sentence, which `_annot_say` emits **whole**"*. The `6` / `Alt-6` success path
never calls `_annot_say`: `utils/annot_mode.tcl:1569` writes the bar directly as
`catch {xschem statusmsg -hold [cadence::_annot_fit [cadence::_annot_msg ...]]}`,
and the CIW leg at `:1533-1536` emits `[string trim "$cmsg [types_clause]"]`
only. **No whole copy of the mask+state sentence exists anywhere.**

* **Part 1 — ladder L1, invariant I1.** The 255-byte cap is NOT widened and the
  path is NOT shortened: `cadence::_annot_bytes` measures against the C wall
  `char statusmsg_text[256]` (`src/xschem.h:1859`), which no Tcl edit can move,
  and issue 0639's closing section rejects both moves by name. The six rows now
  compose the expected sentence and render **the expectation** through
  `cadence::_annot_fit` before comparing — the BC5/BC5b idiom of
  `tests/headless/test_annot_blank_cause_0909.tcl:847-856`. Strictly stronger
  than the old two-anchor `string match` at the default root, and immune to the
  path by construction.
  **Rejected:** an `_annot_fit` spy for all six rows — it drops the C round trip
  through `statusmsg -hold` / `xschem get statusmsg`, the seam issue 0887 found
  broken (bytes vs characters). One spy row (**F48**) buys back the strength the
  fitted comparison loses at a long path.
* **Part 2 — ladder L2, smallest blast radius.** Row F21 mints its own stamp,
  `catch {::op_annot::_db_stamp [file normalize $F_RAW]}`, before the press, so
  the row's subject is the press and not the clock. Row **F49** is the
  deterministic twin: stamp, `f_bump`, byte-identical rewrite, re-stamp, press.
  **Rejected, each measured:** (a) `_db_forget` + `db_current {}` — `_annotated`
  is 0 at that point, so it forgets every stamp and F21 goes deterministically
  RED; (b) deleting F20's rewrite — an implicit cross-row dependency; (c)
  weakening F21's message leg — that leg was deliberately inverted on 2026-09-01
  and is the row's point.

## AFTER

```
test_annot_stale_0684 --nogui, scratch root 54 / 121 / 142 / 201 : ALL PASS (54 checks) at every root
test_annot_stale_0684 on :99 (openbox 3.6.1), root 54 and 142     : ALL PASS (54 checks)
T1 SOLO x4 (cd tests && tclsh run_regression.tcl)                 : rc=0, 0 counted failures, no `exit -1`
full_audit.sh  SUMMARY: 365 pass  11 fail  0 crash/timeout  2 skip  (total 378) — eleven reds IDENTICAL BY NAME to audit_A3_2026-09-02.txt
```

Suite count 52 → 54 (rows F48 and F49 added; six rows rewritten in place).

## Sabotage

| variant | predicted | observed |
|---|---|---|
| `stale-rows-reverted` (drop the `_annot_fit` render from `f_loadedmsg`) | 6 red at a long root, green at the default one | exactly that: `ALL PASS (54)` at root 54, `F16 F17 F36 F39 F43 F44` red at root 142 |
| `f21-restamp-removed` (delete F21's staging line only) | F21 + F49 | **0 red on 3 runs** — see "still open" |
| `f49-restamp-removed` | F49 | F49 red 2 of 2, deterministic |
| `fit-neutered` (`_annot_fit` returns its argument) | 11 red | 12 red, every predicted row present |

## Still open

* **Nothing detects the removal of F21's own staging line.** F49 re-spells the
  same idiom inline, so it stays green; F21's ~1 % coin flip is the only witness.
  A one-line structural leg (F21's source region contains the `_db_stamp` call)
  would close it; nothing in the tree does today.
* **The product half of the race is issue 1255** and is unfixed. The one-second
  `file mtime` granularity still makes a same-second rewrite invisible to any
  stamp, and still forces a needless detach and re-read on a byte-identical
  rewrite one second later.
* Both repairs are **test-side by construction**, so neither row exercises the
  racy product path any more. A suite elsewhere that stamps and rewrites inside
  one second keeps the same flake shape.
