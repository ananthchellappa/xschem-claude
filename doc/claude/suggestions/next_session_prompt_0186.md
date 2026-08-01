# Issue 0186 — a viewer context is still destroyed by `xschem reload`, and by the loads that skip routing

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
Next free issue number after 0187 is **0188**.
**Never push** — commit, raise `tools/review_gate/review_gate.sh` in the background, and wait.

Doc: `doc/claude/issues/0186-viewer-context-destroyed-by-reload-and-inplace-loads.md`. Read
it first. This prompt does not repeat it; it hands you the measurements, the line
numbers as of commit `abfe1153`, and the two decisions I deliberately did not make.

---

## Where this came from

0172 (commit `abfe1153`) established that a waveform viewer is a schematic buffer that
looks exactly like a pristine untitled scratch buffer, and closed the **four doors** an
*open* could use to land a user schematic inside a live viewer: the three
`is_pristine_untitled()` callers plus `ask_new_file()`. It added the per-context flag
`xctx->wave_viewer` (`src/xschem.h:1760`), stamped by `wviewer::open`
(`src/wave_viewer.tcl:656`), with `xschem get/set wave_viewer` arms
(`src/scheduler.c:4481` / `:10586`).

**This issue is everything that takes a viewer's document apart WITHOUT going through
that predicate.** The flag already exists and is already the right oracle — the work is
deciding where else it must be consulted, and what "refuse" should look like.

---

## Part 1 — `xschem reload` wipes the viewer. Measured, twice.

```tcl
xschem clear force
xschem set rectcolor 2
xschem rect 0 0 100 100 -1 "flags=graph,unlocked" 0
xschem set_modify 0
xschem set wave_viewer 1
xschem set readonly 1
xschem reload
```

```
before wv=1 ro=1 rects2=1
load_schematic(): unable to open file: /home/qflow/dev/xschem/claude_1/xschem/untitled.sch
after  wv=1 ro=0 rects2=0
```

`--nogui`, against the post-0172 binary. I reproduced this myself after a subagent
reported it — do the same before you trust it.

The path, line numbers re-derived at `abfe1153`:

| what | where |
|---|---|
| the `reload` branch | `src/scheduler.c:9494` — `unselect_all(1); remove_symbols(); load_schematic(1, xctx->sch[xctx->currsch], 1, 1);` with **no** guard of any kind |
| `readonly` reset | `src/save.c:3734` — `xctx->readonly = 0;` inside `if(reset_undo)`, i.e. **before** the file is even opened |
| the fopen failure | `src/save.c:3810` `if( fd == NULL) {` → `:3814` the message above |
| the wipe | `src/save.c:3827` `clear_drawing();` on that failure path |

Two separable defects in one line, and **they should probably be fixed separately**:

* **the viewer-specific one.** A viewer's `sch[currsch]` is `untitled.sch`, a file that
  does not exist, so reload always takes the failure path and always clears the model.
  Even if the file existed, reloading a *viewer* from disk is meaningless.
* **the general one.** `readonly` is cleared at `save.c:3734` unconditionally under
  `reset_undo`, so **any** read-only buffer whose file has vanished comes back writable
  after a failed reload. That is not a viewer bug; it hits descend-read-only and the
  reopen shortcuts too. It deserves its own issue number and its own guard test, and it
  is the one I would fix first — it is smaller and it is a data-safety property.

Reachability, checked (do not take it on faith, but do not re-derive it either):
`wviewer::key_filter` forwards only ESC, `f`/`Z`/`Ctrl-z` and `graphkeys`
`{97 98 100 115 109 116 65 66 77}`, and the viewer's File menu has only **Close**. So
reload is not reachable from the viewer's own keyboard or menubar — it is reachable by
typing `xschem reload` in the CIW while the viewer holds the context, from an action-log
replay, and from any Tcl that calls it.

## Part 2 — the loads that never compute `route_newwin`

| door | where | why it skips the predicate |
|---|---|---|
| `xschem load -window <winpath>` | `src/scheduler.c:6474` | switches to the named window, sets `target_done = 1`, never computes `route_newwin` |
| any in-place hint | `src/scheduler.c:6469` `inplace_hint = inplace \|\| !load_symbols \|\| nodraw \|\| nofullzoom \|\| keep_symbols \|\| !undo_reset` | `route_newwin` at `:6503` is false by construction |

Both land in `load_schematic()` in place, on a viewer, today.

**I did not close these on purpose.** `-window` is a caller naming its target
explicitly, and the hint flags are the documented contract for scripted/internal
in-place loads (`doc/claude/specs/load_window_routing.md`) that the entire regression
suite depends on. The question is narrow: *should "explicit" still win when the target
is a viewer?* My inclination is yes for `-window` (the caller asked for that window by
name and gets what it asked for, with a `ciw_echo` warning), no for the hint flags (a
script that says `-nodraw` is not a user gesture). **Bring the reasoning, not just the
patch** — and whatever you decide, put a leg in the guard test that pins the decision so
the next person sees it was a decision.

---

## The shape I would try first

One guard, not four: the viewer refusal belongs at the small number of C entry points
that **replace a context's whole document**, not spread across every verb.
`load_schematic()` itself is tempting but wrong — it is also how the viewer's own
`clear_drawing`/regenerate machinery works, and how `wviewer::open` builds the window in
the first place. Look at the *callers* instead, and reuse the reporting shape that
already exists: `wviewer::open`'s refusals go out through `ciw_echo ... error`, and the
user sees them in the CIW rather than in a modal.

Whatever you pick, the refusal must be **loud**. A silently-ignored `xschem reload` is
its own bug report six months from now.

---

## Testing

The whole of Part 1 reproduces **headless**, which is the good news: `xschem set
wave_viewer 1` exists precisely so a test can brand a buffer with no Tk and no
`DISPLAY`. Model the guard on
`tests/headless/test_pristine_untitled_viewer_0172.tcl` — it is 25 checks, needs no X,
and its `reset` / `brand_viewer` helpers are exactly what you want to copy.

Legs worth having, at minimum:

* a branded viewer + `xschem reload` → rects intact, `readonly` still 1, and the refusal
  was *reported*;
* the general defect: an ordinary read-only buffer whose file is gone + reload →
  `readonly` still 1 (this leg fails today and is the one that matters most);
* the behaviour that must NOT change: an ordinary schematic + reload still reloads;
* if you close either Part-2 door, the same pair for it, plus a leg pinning the door you
  chose to leave open.

`tests/headless/test_wave_clear_all.tcl` CG9/CG10 (need X) are the real-viewer legs for
0172; add a real-viewer reload leg there if you want end-to-end proof, but do not make
it the mechanism.

---

## HARD-WON TRAPS — these cost real time in the 0172 session

1. **`xschem` needs `--pipe` with `--script`** or it runs the file and prints nothing with
   `rc=0`: `./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl`.
2. **An unknown `xschem get <name>` returns the EMPTY STRING with rc 0** — it does not
   error. An unknown `xschem set` **does** error. So `get` legs are honest RED before a
   feature exists, but `set` legs need `catch` or the whole script aborts and every leg
   after it "passes" by never running. Print a sentinel and check the leg count.
3. **The `get` arms are dispatched on the FIRST LETTER of `argv[2]`** (`switch` with
   `case 'w':` etc.); the `set` arms are a flat else-if chain. A new `get` name in the
   wrong letter group is silently unreachable and answers empty.
4. **Verify "pre-fix" really is pre-fix**: `git show <sha>:src/<f> > src/<f>` — worktree
   only. `git checkout <sha> -- <file>` also writes the INDEX and a later `git commit -a`
   silently reverts your fix. Back the file up to the scratchpad first; the tree already
   has your uncommitted work in it.
5. **C changes need `cd src && make`, and the shell's cwd PERSISTS across tool calls** —
   prefer `make -C src`.
6. **`new_schematic create` switches to the window already holding a file** instead of
   creating a new one, so `ntabs` stays put and it reads exactly like a hijack. Use a
   distinct file per leg.
7. **Per-context flags survive `xschem clear force`** (measured on `no_grid` and
   `wave_viewer`) — a leg that forgets to clear them poisons the next one.
8. **Subagents report confident wrong answers in both directions.** In the 0172 session
   two of six findings were real and cost-effective, two were real but pre-existing, and
   two were refuted on measurement. Reproduce everything yourself.
9. **The GUI arm is unreliable on this box (WSLg).** Keep this issue headless. If you run
   X suites, use `SUITE_TIMEOUT=900 tests/headless/run_suites.sh <names>` or
   `tests/headless/gated_xschem.sh`, **never a bare loop**.

---

## Suites that must stay green

Measured at `abfe1153`:

```
--nogui:  test_pristine_untitled_viewer_0172   25
          test_untitled_reuse                   6
          test_pristine_untitled_basename       2
          test_ciw_interactive_load            12
          test_wave_clear_all (CA legs only)    3
X arm:    test_load_window_routing             14
          test_wave_clear_all                  75
          test_wave_viewer                    368
          test_wave_snap                       90
```

`tests/netlist_diff/netlist_diff.sh` is **not** indicated — this is window/document
lifecycle, not netlisting. Say so rather than running it out of habit.

`test_cadence_descend_newwin_ro` scores **NORESULT** on both arms because it ends
`... all checks passed` instead of `RESULT: ALL PASS (N checks)` — a known pre-existing
harness gap, not something you broke.

## How I want you to work

1. Reproduce Part 1 yourself, headless, before trusting this prompt.
2. Split the `readonly`-cleared-on-failed-load defect out and fix it on its own merits —
   file it as **0188** with its own guard.
3. Decide Part 2 explicitly and record the decision in a test leg, whichever way it goes.
4. RED before GREEN. Issue doc updated with what you actually established. Commit. Raise
   the review gate. **Never push.**
5. Report what you verified, what you did **not**, and any judgement call I should weigh
   in on.
