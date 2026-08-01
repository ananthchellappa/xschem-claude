# Issue 0172 follow-up — turn "I think the emptiness hardening costs nothing" into "I measured that it costs nothing"

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
Next free issue number is **0188**.
**Never push** — commit, raise `tools/review_gate/review_gate.sh --label ... --body-file ...`
in the background, and wait.

This is **evidence work on already-shipped code**, not a new feature. The code is
committed (`abfe1153`, plus prompts in `00b64977`), the suites are green, and the review
gate said PROCEED. What is missing is proof, and there is one real hole: **three of the
branches that shipped have no test at all.**

Read `doc/claude/issues/0172-viewer-buffer-hijacked-by-pristine-untitled-reuse.md` first
for the story. This prompt is only about tasks 1–4 below.

---

## What shipped, exactly

`is_pristine_untitled()` (`src/scheduler.c:6175`) decides whether an open loads INTO the
current buffer or opens a new window/tab. Three doors call it (the `xschem load -gui`
routing at `:6503`, `load_new_window <file>` at `:6701`, `load_new_window` via the file
dialog at `:6722`); a fourth door, `ask_new_file()` (`src/actions.c:701`), does not — it
reads `xctx->wave_viewer` directly. The body today:

```c
  if(xctx->wave_viewer) return 0;                                    /* A */
  if(xctx->currsch != 0) return 0;                                   /* B */
  if(xctx->modified) return 0;                                       /* C */
  if(xctx->instances != 0 || xctx->wires != 0) return 0;             /* D */
  if(xctx->texts != 0) return 0;                                     /* E */
  for(i = 0; i < cadlayers; i++) {
    if(xctx->rects && xctx->rects[i]) return 0;                      /* F */
    if(xctx->lines && xctx->lines[i]) return 0;                      /* G */
    if(xctx->polygons && xctx->polygons[i]) return 0;                /* H */
    if(xctx->arcs && xctx->arcs[i]) return 0;                        /* I */
  }
  if(!xctx->sch[xctx->currsch]) return 0;   /* NULL-safe (issue 0023) */
  return (xctx->sch[xctx->currsch][0] == '\0' ||
          is_untitled_basename(xctx->sch[xctx->currsch]));           /* J */
```

**A** is the issue-0172 viewer flag. **E–I** are the "emptiness hardening": the old
predicate called a buffer empty when it had no instances and no wires, ignoring text,
rects, lines, polygons and arcs entirely. Drawing normally sets `modified` (**C**), which
is what made **E–I** look redundant — but anything that clears `modified` while content
is present (the viewer's `with_edit` D1 contract; a script calling `xschem set_modify 0`)
then handed a buffer *with content in it* to the next open, and it was overwritten
silently.

The arrays are per-layer, sized `cadlayers`, allocated at `src/xinit.c:830`
(`xctx->rects = my_calloc(_ALLOC_ID_, cadlayers, sizeof(int));` and siblings).

**The honest state of the evidence.** `tests/headless/test_pristine_untitled_viewer_0172.tcl`
(25 checks, no X) exercises **E** (a lone text, leg S3–S5) and **F** (a graph rect, legs
S1–S2 and the whole V block) — both on **layer 2 only**. **G, H and I have no leg at
all**, and no leg places anything on a high layer, so the `cadlayers` loop bound is
untested. That is three shipped branches with zero coverage, in a change whose whole
point was that an unexercised check had been silently covering for another one.

---

## Task 1 — cover every clause you added (the real hole)

Add legs to `tests/headless/test_pristine_untitled_viewer_0172.tcl` for **G (line)**,
**H (polygon)** and **I (arc)**, in the shape of the existing `S*` legs: build a buffer
holding exactly that one object, `xschem set_modify 0` so it looks pristine to **C**,
`xschem load_new_window <real.sch>`, then assert (a) a new window/tab appeared and
(b) switching back finds the object still there.

Two things the existing legs do not do and these must:

* **place at least one object on a NON-ZERO layer** — ideally the highest layer the build
  has. That is the only leg that proves the loop really scans `cadlayers` entries rather
  than accidentally passing because everything lives on layer 0/2. Get the count from
  Tcl: `xschem get cadlayers` exists (`src/scheduler.c:3662`), so the leg can size itself
  and does not need a hard-coded layer number;
* **assert the object survived**, not just that a new window appeared. "A new window
  appeared" also happens when the load fails outright.

Watch out: `xschem get arcs <n>` does **not** exist (it answers the empty string, rc 0 —
see trap 2). If you need an arc count in Tcl for an assertion, either add the getter next
to `rects`/`lines`/`polygons` in the `case 'a'` group of `xschem get` (`src/scheduler.c`,
around `:4029`–`:4290` — and see trap 3 about letter groups), or assert on something else
that is observable, and say in the leg comment which you did and why.

Update the leg-count sentinel at the bottom of the file (currently 25) — it exists
precisely so a skipped leg cannot pass by not running.

## Task 2 — sabotage-test each clause

For each of **A, C, D, E, F, G, H, I** in turn: delete that one line from
`is_pristine_untitled()`, `make -C src`, run the test, and record **which named legs go
red**. Then put the file back. Expect exactly one clause → one (or one small, named) set
of legs. If deleting a clause changes nothing, that clause has no test and Task 1 is not
finished. If deleting one clause reddens legs you thought belonged to another, the legs
are covering for each other — which is exactly the failure mode this whole issue came
from.

Do it with `git show HEAD:src/scheduler.c > src/scheduler.c` style worktree-only edits, or
a scratch copy — see trap 4. Record the resulting table in the issue doc; it is the most
useful artefact of this session.

**A and the swap fix are already sabotage-verified** (16 of 25 legs red pre-fix; W-win /
W-tab red against `HEAD`'s `src/xinit.c`; CG10 red against `HEAD`'s `src/actions.c`), so
you are filling in **C–I**.

## Task 3 — prove the negative empirically

The claim in the spec is "a freshly created untitled buffer is 0 in every one of those
arrays, so the hardening costs the intended reuse behaviour nothing." That currently rests
on two probes and a grep. Upgrade it:

* run the **full** `tests/headless/full_audit.sh` (not a hand-picked list) on both arms,
  and compare against a baseline run of the same audit at the commit before the fix
  (`54eabbaf` — `abfe1153` is the fix, `00b64977` is prompts only) so a pre-existing failure is not read as yours;
* run the `create_save`, `open_close` and `netlisting` cases (`cd tests && tclsh
  run_regression.tcl`) — they drive **repeated loads**, which is exactly the behaviour the
  hardening could change. Note in the report that these have **no committed `gold/`
  baseline**, so they can only report `NOGOLD`: what you are watching for is a crash, a
  hang, or a diff in *how many windows* the runs end up with, not a golden compare;
* search for any shipped flow that puts an object into the untitled buffer *before* a
  file is opened (a template, a title block, an rc-driven insertion, a demo). `grep -rn
  "untitled" src/*.tcl` and the `xschemrc` files are the places to start. Report the
  result either way — "I looked here, here and here, and found none" is the deliverable.

If the audit moves, **that is a success, not a setback**: you found the workflow the
hardening breaks, and the fix then has a real case to be judged against.

## Task 4 — make the refusal explainable

Add a `dbg(1, ...)` in `is_pristine_untitled()` naming **which** clause refused (one line
per early return, or a single line with a reason string). When someone asks in six months
"why did opening a file give me a new window instead of reusing my blank one?", that must
be one debug run away, not an afternoon of `git log`. Keep it at level 1 so it costs
nothing in normal use, and confirm with `-d 1` that the lines actually appear.

---

## Judgement call to make, and record

The viewer flag (**A**) and the emptiness hardening (**E–I**) have different risk
profiles: **A** is narrow and provably right; **E–I** is a broad behavioural change that
affects every window, viewer or not. They shipped in one commit, so the risky half cannot
be reverted without losing the fix.

Decide, on the evidence Tasks 1–3 produce, whether **E–I** stays. It is a contiguous block
and reverts cleanly. If it stays — my recommendation, because the old check contradicted
its own comment and a viewer-only fix leaves the same trap open for the next thing that
clears `modified` — say so in the issue doc **with the measurements behind it**, not the
assertion. If the audit turns up a real workflow it breaks, drop **E–I**, keep **A**, and
file the general defect separately.

---

## HARD-WON TRAPS

1. **`xschem` needs `--pipe`** with `--script`, or it runs the file and prints nothing
   with `rc=0`: `./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl`.
2. **An unknown `xschem get <name>` returns the EMPTY STRING with rc 0** — it does not
   error, so a leg comparing it to a number just fails quietly. An unknown `xschem set`
   **does** error, and that aborts the whole script: every leg after it "passes" by never
   running. This is why the file ends with a leg-count sentinel — keep it correct.
3. **`xschem get` arms dispatch on the FIRST LETTER of `argv[2]`** (`switch` with
   `case 'a':`, `case 'w':` …); the `set` arms are a flat else-if chain. A new `get` name
   in the wrong letter group is silently unreachable and answers empty.
4. **Verify a "pre-fix" or sabotaged binary really is one** by running the test against it
   and watching it fail. `git show <sha>:src/<f> > src/<f>` is **worktree only**;
   `git checkout <sha> -- <file>` **also writes the index**, and a later `git commit -a`
   silently reverts your work. Back the file up to the session scratchpad first — the tree
   normally has uncommitted work in it.
5. **`make -C src`** — the shell's cwd persists across tool calls, so a `cd src` earlier
   makes a later `./src/xschem` fail with "No such file or directory".
6. **Per-context flags survive `xschem clear force`** (measured on `no_grid` and
   `wave_viewer`). The test's `reset` clears them explicitly; a new leg that forgets to
   poisons the next one.
7. **`new_schematic create` switches to the window already holding a file** instead of
   creating a new one — `ntabs` then stays put and reads exactly like the defect. Use a
   distinct file per leg (this cost a red CG10 in the original session).
8. **Scratch dirs: always `test_scratch` from `tests/headless/scratch.tcl`.** Throwaway
   probes go in the session scratchpad, never in the repo.
9. **A new test must end with `RESULT: ALL PASS (N checks)`** or `full_audit.sh`'s
   `is_pass()` scores it FAIL while every leg prints ok. Several existing suites end
   `OVERALL: ok` / `all checks passed` instead and are scored **NORESULT on both arms** —
   a known pre-existing harness gap (`test_cadence_descend_newwin_ro` is one).
10. **The GUI arm is unreliable on this box (WSLg)** — the X server dies a few times per
    session and takes every client with it. Use
    `SUITE_TIMEOUT=900 tests/headless/run_suites.sh <names>` or
    `tests/headless/gated_xschem.sh`, **never a bare loop**; press **Allow 30m/2h** once
    on the gate panel instead of Proceed per suite.
11. **Subagents report confident wrong answers in both directions.** In the session that
    produced this code, six review findings came back: two were real and worth fixing, two
    were real but pre-existing, two were refuted on measurement. Reproduce everything
    yourself.

---

## Suites that must stay green

Measured at `abfe1153`:

```
--nogui:  test_pristine_untitled_viewer_0172   25   <- the one you are extending
          test_untitled_reuse                   6   <- the "reuse still happens" guard
          test_pristine_untitled_basename       2
          test_ciw_interactive_load            12
          test_wave_clear_all (CA legs only)    3
X arm:    test_load_window_routing             14   <- the -gui door, needs X
          test_wave_clear_all                  75   <- CG9/CG10 are the 0172 legs
          test_wave_viewer                    368
          test_wave_snap                       90
          test_clone_canvas_bindings            3
```

`tests/netlist_diff/netlist_diff.sh` is **not** indicated — this is window/document
lifecycle, not netlisting. Say so rather than running it out of habit.

## The human check — already done, keep it that way

**Done 2026-07-31 by the user**: a real waveform viewer open, **File > Open** from the
menu, and the schematic landed in its own window with the viewer's waveforms intact. That
is the one link no headless test covers (the tests brand a plain buffer to *imitate* a
viewer; CG9 calls `wviewer::open` directly rather than through the GUI), so it is the only
evidence the whole chain holds in the shipping app.

You do not need to repeat it to start — but **if any of Tasks 1–4 changes the predicate,
`ask_new_file()` or the branding, repeat it before you commit**, and say in your report
whether you did. If the display makes it impossible, say that explicitly rather than
quietly skipping it.

## How I want you to work

1. Task 1 first — it is the actual hole. Do not start Task 2 until every clause has a leg.
2. Task 2's table goes in the issue doc. If a clause has no red leg, go back to Task 1.
3. Task 3 is a measurement, not a formality: baseline at `7cf1858c`, then compare.
4. Task 4 is five lines; do it last so the debug output describes the final predicate.
5. Commit. Raise the review gate. **Never push.**
6. Report what you verified, what you did **not**, and the E–I keep-or-drop decision with
   the evidence behind it.
