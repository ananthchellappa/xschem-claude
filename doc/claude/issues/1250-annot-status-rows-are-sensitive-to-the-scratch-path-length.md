# 1250 — `test_annot_stale_0684`'s status-message rows red when the scratch path is long, and F21 flaked once at the default path

Status: **open** (measured by item A2's write-up pass, 2026-09-02; **not fixed** —
the files are `utils/annot_mode.tcl` and `tests/headless/test_annot_stale_0684.tcl`,
neither of which item A2 owns) · Branch: `fluid-editing`
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
