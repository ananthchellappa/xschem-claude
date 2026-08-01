# 0172 — a waveform-viewer window can be hijacked by the pristine-untitled reuse path, and viewer keys then eat the loaded schematic

Status: **FIXED** 2026-07-31. Filed 2026-07-29. Pre-existing; **not** introduced by
viewer plan item 4 — surfaced by the adversarial review of it, and reproduced
independently by two agents.

## Summary

`xschem load_new_window` reuses a *pristine untitled* buffer in place instead of
opening a new window. An ASE waveform-viewer buffer satisfies every test
`is_pristine_untitled()` applies, **permanently and by construction**, so a real
user schematic can be loaded into a live viewer window. The window keeps its
`WaveViewer` bindtag, its viewer menubar and its `wviewer::windows` registry
entry, so the viewer's own keys and menu entries then operate on the user's
schematic:

* **`Ctrl-D` / Graph > Clear All** — `wviewer::clear_all` replaces the model with
  one empty strip and regenerates. Probed on a hijacked window: the loaded
  schematic went from `instances=14 wires=8 graph_rects=3` to
  `instances=0 wires=0 graph_rects=1`. **The whole document.**
* **`u` / `Shift-u`** — `wviewer::undo_at` / `redo_at` drive the viewer's
  model-snapshot stack, not the C undo stack, against a document that stack
  knows nothing about.
* **`Ctrl-E` / Graph > Delete All Markers** (item 4, 2026-07-29) — strips
  `markers=` from the schematic's graph rects. Strictly the *smallest* instance
  of the family.

## It reproduces HEADLESS — that is the useful part

`is_pristine_untitled()` never looks at the viewer, only at the buffer's SHAPE, so a
buffer shaped like a viewer's is hijacked identically with no Tk, no `DISPLAY` and no
`wviewer::open`. Measured 2026-07-31 against `54eabbaf`, `--nogui`:

```tcl
xschem clear force
xschem set rectcolor 2
xschem rect 0 0 100 100 -1 "flags=graph,unlocked" 0
xschem set_modify 0          ;# the with_edit/D1 contract, permanently
xschem set no_grid 1
xschem set no_snap 1
xschem set readonly 1
xschem load_new_window <real.sch>
```

```
before  rects2=1 inst=0 wires=0 modified=0 readonly=1 ntabs=0 sch=untitled.sch
after   rects2=0 inst=1 wires=1 modified=0 readonly=0 ntabs=0 sch=real.sch
```

`ntabs` never moved and `rects2` went to **0**: the schematic was loaded *into* the
viewer-shaped buffer and its graph rect was destroyed. Note `readonly` went **1 → 0** as
well — the load resets it — so "the window is read-only, nothing can reach disk" is a
mitigation that the hijack itself removes.

## Root cause

`is_pristine_untitled()` (`src/scheduler.c`, pre-fix) tested only `currsch`,
`modified`, `instances`, `wires` and the basename. A viewer buffer is
`currsch == 0`, has no instances and no wires (its content is graph *rects*), is
named `untitled`, and — this is the part that makes it permanent rather than
merely momentary — the `wviewer::with_edit` contract (D1) ends every mutation
with `xschem set_modify 0` before restoring `readonly 1`, so **`modified` is 0
for the buffer's whole life**. A viewer therefore never ages out of "pristine"
the way an ordinary untitled buffer does the moment the user draws something.

## FOUR doors, not one

The predicate has three callers — the earlier draft of this doc named only the second —
and there is a fourth door that does not go through the predicate at all:

| door | where (2026-07-31) | reachable under `--nogui`? |
|---|---|---|
| 1. `xschem load -gui` routing | `src/scheduler.c` `route_newwin = has_x && !force && !inplace_hint && !is_pristine_untitled()` | no — `has_x` is the first conjunct, so the predicate is not even evaluated |
| 2. `load_new_window <file>` | `src/scheduler.c`, the `is_pristine_untitled() && tcl_braceable(f)` reuse | **yes** |
| 3. `load_new_window` via the file dialog | same file, the dialog arm | no — needs the dialog |
| 4. `ask_new_file()` | `src/actions.c` — the in-place arm calls `load_schematic()` **unconditionally**; the predicate is never consulted | no — `if(!has_x) return;` |

The CIW rewrites a typed `xschem load <file>` into the `-gui` form
(`tests/headless/test_ciw_interactive_load.tcl`, `doc/claude/specs/load_window_routing.md`),
so door 1 is a *user-facing* door, not an internal one.

**Door 4 was found while fixing 1–3 and is the nastiest**, because no change to
`is_pristine_untitled()` can reach it: with `open_in_new_window` at its shipping default of
0, `ask_new_file()` clears hilights, resets `currsch`, removes symbols and calls
`load_schematic()` over whatever the current context holds. It is entered from `xschem
load` with **no filename** (the CIW rewrite only adds `-gui` to a load that *has* an
argument) and from Ctrl-O / Alt-O. It is *not* reachable from the viewer's own keyboard —
`wviewer::key_filter` forwards only ESC, `f`/`Z`/`Ctrl-z` and the `graphkeys`
`{97 98 100 115 109 116 65 66 77}`, which excludes `o` (111), and the viewer's File menu
has only Close — but it is reachable by typing `xschem load` in the CIW while the viewer
holds the context. Measured: with door 4 open and 1–3 closed, that clobbered the viewer
and its graph rects went to 0 (`test_wave_clear_all` CG10, both legs red).

## The fix (implemented 2026-07-31)

Inside `is_pristine_untitled()` itself, so doors 1–3 close at once and the next caller
cannot reintroduce the hijack, plus one line in `ask_new_file()` for door 4. Three
mechanisms, deliberately:

1. **`xctx->wave_viewer`** — a fifth per-context C flag next to `no_grid` / `no_snap` /
   `graph_snap` (`src/xschem.h`), with `xschem get wave_viewer` / `xschem set
   wave_viewer 0|1` arms in `src/scheduler.c`, stamped by `wviewer::open`
   (`src/wave_viewer.tcl`) in the same block as the other four and *below* that block's
   `[xschem get current_win_path] ne $wp` refusal, so it cannot be branded onto a real
   schematic that took the context by accident. `alloc_xschem_data()` uses `my_calloc`,
   so every other context is 0 for free — there is no explicit `no_grid = 0` / `no_snap
   = 0` anywhere either, and that is why. `is_pristine_untitled()` returns 0 when it is
   set: a viewer is excluded because it **is** a viewer, not because of what it happens
   to contain.
   Making it settable from Tcl is not only for `wviewer::open`: it is what lets the
   regression guard brand a buffer as a viewer **headlessly**.
2. **"pristine" hardened to mean actually empty** — no texts and no rects / lines /
   polygons / arcs on any layer, not merely no instances and no wires. Drawing normally
   sets `modified`, which is what made the other arrays look redundant; but any path
   that clears it (the viewer's D1 contract, a script calling `xschem set_modify 0`)
   handed a buffer *with content in it* to the next open. Measured: a freshly created
   untitled buffer is 0 in every one of those arrays, at startup and after `xschem clear
   force`, so this costs the intended behaviour nothing.
3. **`ask_new_file()` forces its new-window arm for a viewer** (`src/actions.c`):
   `if(xctx && xctx->wave_viewer) in_new_window = 1;`. That arm goes through
   `load_new_window`, hence through the fixed predicate, so door 4 lands where doors 1–3
   do. One line rather than an argument about who can press Ctrl-O.

The registry lookup this doc originally proposed (`is_pristine_untitled()` asking Tcl
whether the window path is a value of `wviewer::windows`) was **not** implemented: it
puts a C→Tcl query in the middle of a predicate that runs on every open, and it is not
testable without a real viewer.

### What was deliberately NOT done

Refusing reuse whenever `xctx->readonly` is set would also fix this and needs no new
flag. It is a bigger behavioural claim than the evidence supports: this branch has
several paths that open ordinary schematics read-only (descend read-only, the reopen
shortcuts) and a read-only buffer is not obviously a bad reuse target. Measured
pre-fix and unchanged after: a **read-only** pristine untitled buffer is reused exactly
like a writable one, and `tests/headless/test_pristine_untitled_viewer_0172.tcl` leg R1
pins that. If that ever flips it should be a decision, not a regression.

## Eyeballed

2026-07-31, by the user, in the real app: a waveform viewer open, **File > Open** from the
menu — the schematic landed in its own window and the viewer kept its waveforms. That is
the one link no headless test covers (the tests brand a plain buffer to *imitate* a
viewer, and CG9 calls `wviewer::open` directly rather than through the GUI), so it is the
only evidence that the whole chain — menu → Tcl → predicate → new window — holds in the
shipping app.

## Guards

* `tests/headless/test_pristine_untitled_viewer_0172.tcl` — **41 checks, no X needed**
  (25 when the fix shipped; the follow-up session added S6–S21, see *Evidence* below).
  The mechanism: F* the flag itself (default 0, round-trip, per-context — branding one
  window does not brand another); V* the defect (viewer-shaped + branded buffer →
  new window, graph rect intact, branding intact); S* the emptiness hardening (an
  *unbranded* graph rect, a lone text, and one of every other object type — line,
  polygon, arc on the **top** layer, wire, instance — each asserted to *survive* the
  open, not merely to have provoked a new window); P* the behaviour that must not change
  (a genuinely pristine untitled buffer is still reused in place); R* read-only is not
  the guard; M* the control that proves the "a new window appeared" witness can fail.
  Pre-fix it failed 16 of 23; the P/R/M legs passed pre-fix and still pass.
* `tests/headless/test_wave_clear_all.tcl` **CG9** (needs X, 4 checks) — the leg that
  proves `wviewer::open` *itself* brands the context, i.e. that the C-side refusal is
  armed in production and not only in the headless test's imitation.
* `tests/headless/test_wave_clear_all.tcl` **CG10** (needs X, 2 checks) — door 4: a bare
  `xschem load` (dialog stubbed, as `test_load_window_routing` stubs `ask_save`) against a
  real viewer must open a new window and leave the viewer's rects alone. Verified honest
  by reverting `src/actions.c` to `HEAD` in the worktree, rebuilding, and watching both
  legs go red — the second one because the viewer's graph rects were destroyed. Use a
  file that is *not* already open: `new_schematic create` switches to the window holding
  an already-open file instead of creating one, which leaves `ntabs` unmoved and reads
  exactly like the hijack.
* `tests/headless/test_load_window_routing.tcl` (needs X, 14 checks) — the pre-existing
  guard on the `-gui` door; re-run green after the fix, including its "pristine untitled
  is reused in place" legs.

## Evidence (follow-up session, 2026-07-31)

The fix shipped with three of its own branches untested. This section is the measurement
that closes that, plus the sabotage table that proves each leg guards the clause it is
named for. Everything here was reproduced in this session, not carried over.

### 1. Every clause has a leg (Task 1)

`test_pristine_untitled_viewer_0172.tcl` went **25 → 41 checks**:

| new legs | what they hold |
|---|---|
| S6 | the top layer is real and above the layers the older legs use (`cadlayers`=22 here, so 21) |
| S7–S9 | a buffer holding one **line** on the **top** layer: not reused, and the line survives |
| S10–S12 | the same for a **polygon** |
| S13–S15 | the same for an **arc** — and the only guard on the new `xschem get arcs` |
| S16–S18 | a buffer holding one **wire**, `modified` cleared |
| S19–S21 | a buffer holding one **instance**, `modified` cleared |

Two properties the pre-existing S legs did not have: the object goes on the **top** layer
(read from `xschem get cadlayers`, never hard-coded), which is what makes the
`i < cadlayers` loop bound observable; and each leg asserts the object **survived** the
open, because "a new window appeared" also happens when the load fails outright.

`xschem get arcs <n>` did not exist — `rects`, `lines` and `polygons` did. An unknown
`xschem get` answers the empty string with rc 0, so an arc-count assertion would have
been silently vacuous. Added in the `case 'a'` group of the `get` dispatcher
(`src/scheduler.c`; the arms dispatch on the first letter of `argv[2]`, so the letter
group is not optional).

The wire/instance legs (S16–S21) were **not** in the plan: the sabotage pass found that
deleting the original `instances != 0 || wires != 0` clause reddened *nothing*. Once a
real schematic is loaded the buffer is no longer named `untitled`, so the basename clause
was covering for it. That clause is older than this issue and had been untested since it
was written.

**The suite now runs under X too, and did not before.** The X arm of the audit is what
surfaced it, and it took two fixes:

| version | X-arm result |
|---|---|
| one shared `real.sch` (as shipped), 25 checks | `W-win` fixture red **1 run in 3** |
| one shared `real.sch`, 41 checks | `W-win` fixture red **3 runs in 3** |
| one file per block (`mkreal <tag>`) | `W-win` + `M1` red **2 runs in 6** |
| + `wait_switch` after each open that expects a new window | **8 runs in 8 green** |

Two distinct causes, both in the test, neither in the fix:

1. every block opened the *same* path, which trips the trap this issue already documented
   — `new_schematic create` switches to the window that already holds an open file
   instead of creating one, so the `W-win` fixture found no second window to swap with
   (`other=.drw main=.drw`). Latent, not introduced: the shipped 25-check version fails
   the same leg 1 run in 3 under X;
2. under X the context switch to a freshly created window arrives through Tk events, so a
   leg reading `current_win_path` on the next line can still see the OLD window while
   `ntabs` has already gone up. That is exactly what `M1` printed (`ntabs 0 -> 1`, window
   unchanged). `wait_switch` pumps the event loop until the switch lands, and is
   deliberately *not* used on P1/R1, where the window must not change.

Headless neither ever showed — no events, synchronous switch. Both arms are now green:
`RESULT: ALL PASS (41 checks)`, 8/8 under X.

### 2. Sabotage table (Task 2)

Method: neutralise **one** clause (`if(<cond>) {` → `if(0) {`, the deletion equivalent now
that each clause is a braced block with a `dbg` line), `make -C src`, run the guard
suites, restore. Worktree-only edits from a scratchpad copy; the final row confirms
`src/scheduler.c` is byte-identical to the pre-sabotage file and the suites green again.

| clause | legs that go RED | other suites |
|---|---|---|
| **A** `wave_viewer` | F5, F6 | all green |
| **B** `currsch != 0` | **none** | all green |
| **C** `modified` | W-win, W-tab (fixture), M1 | all green |
| **D** `instances != 0 \|\| wires != 0` | S17, S18, S20, S21 | all green |
| **D1** instances half only | S20, S21 | all green |
| **D2** wires half only | S17, S18 | all green |
| **E** `texts` | S4, S5 | all green |
| **F** `rects[i]` | S1, S2 | all green |
| **G** `lines[i]` | S8, S9 | all green |
| **H** `polygons[i]` | S11, S12 | all green |
| **I** `arcs[i]` | S14, S15 | all green |
| **J** untitled basename | none *here* — `test_pristine_untitled_basename` **UT1** | 0172 suite green |
| loop bound `i < cadlayers` → `i < 3` | S8, S9, S11, S12, S14, S15 | all green |

Suites run per row: `test_pristine_untitled_viewer_0172`, `test_untitled_reuse`,
`test_pristine_untitled_basename`, `test_ciw_interactive_load`, `test_wave_clear_all`
(`--nogui`). Read the table as: one clause → one small, *named*, non-overlapping set of
legs. Three things it says that are worth keeping:

* **A's own legs are F5/F6, not the V block.** Neutralising the viewer flag leaves V1–V5
  green, because a branded buffer also holds a graph rect and the rect clause refuses it.
  That is deliberate and documented in the test — the V legs assert the *defect* is gone
  by either mechanism; F5/F6 are where the flag is load-bearing alone (empty buffer,
  branded). Under X, `test_wave_clear_all` CG9/CG10 are the production-side guard on A.
* **B (`currsch != 0`) has no leg and cannot easily get an honest one.** A descended
  buffer is named after a real file, so the basename clause refuses it first; to make B
  load-bearing you would have to descend into a schematic actually named `untitled.sch`.
  Pre-existing clause, unchanged by this issue, recorded rather than faked.
* **The loop bound is now observable.** Cutting it to 3 reddens exactly the six top-layer
  legs and leaves the layer-2 legs (S1/S2) green.

### 3. The negative, measured (Task 3)

**Full audit, both arms, against a baseline build of `54eabbaf`** (the commit *before*
`abfe1153`; `00b64977` is prompts only). The baseline is a separate `git worktree`, its
own `./configure` + `make`, verified honest by running the 0172 suite against it:
**17 of 25 legs red**.

| arm | baseline `54eabbaf` | this tree (fix + evidence work) |
|---|---|---|
| no X (`env -u DISPLAY`) | 138 pass / 8 fail / 62 crash / 62 skip (270) | 139 pass / 8 fail / 62 crash / 62 skip (271) |
| X (`DISPLAY=:0`, WSLg) | 254 pass / 13 fail / 0 crash / 3 skip (270) | 244 pass / 18 fail / 0 crash / 9 skip (271) |

Per-test comparison of the no-X arm: **every test present in both runs has the identical
status**; the only difference in the totals is `test_pristine_untitled_viewer_0172`
itself, which does not exist at the baseline. The 8 FAIL and 62 CRASH are therefore
pre-existing at `54eabbaf` and not this change (the crashes are X-needing tests that die
on `invalid command name "winfo"` with no `DISPLAY`, which is what that arm does to them).
Scratch-leak detector: **0 leaked dirs** on both runs; the wireedit suite passes on both.

The X arm's totals differ, and **none of it survives repetition**. 21 tests changed status
between the two X runs — in *both* directions (3 FAIL→PASS, 8 PASS→SKIP, 2 SKIP→PASS,
6 PASS→FAIL). Both runs contain `X connection to :0 broken (explicit kill or server
shutdown)` — the WSLg X server died once during the fixed run and twice during the
baseline run, which is what the SKIPs are. Re-running all 21 twice on each binary:

| verdict | tests |
|---|---|
| fails on **both** binaries, both repeats | `test_altf5_ciw` (Alt-F5 raise, a known WSLg raise/key-delivery flake), `test_rotate_stretch_short_0104` |
| flaky on **both** binaries (one pass, one fail each) | `test_ase_interact`, `test_graph_context` |
| flaky on the baseline, green twice on this tree | `test_ase_unnamed_net` |
| green twice on both | the remaining 16 (SKIPs scattered over both binaries as the server died) |

So no test differs *systematically* between the two binaries on either arm. The honest
statement is: **the emptiness hardening changed no test's behaviour that this box can
measure**, and the X arm on this box cannot resolve differences smaller than its own
noise (recorded so the next session does not re-derive it).

**`create_save` / `open_close` / `netlisting` (`cd tests && tclsh run_regression.tcl`),
both binaries.** These drive *repeated loads*, which is the behaviour the hardening could
plausibly change. They have **no committed `gold/`**, so they can only report `NOGOLD` —
what is being watched for is a crash, a hang or a different number of results, not a
golden compare. Both runs completed, `Total num fail: 0` for all three cases on both, and
the two `results.log` files are **identical after path normalisation except two counts**:

```
open_close   1896 result file(s)  (baseline)   vs  1901  (this tree)
netlisting   1480 result file(s)  (baseline)   vs  1504  (this tree)
```

Not the binary: the working tree carries three extra `*~.sch` autosave files under
`xschem_library/examples/` that the clean baseline worktree does not (they are
`.gitignore`d, so `git status` does not show them). 3 extra designs × 4 netlist formats ×
(netlist + debug file) = exactly the 24 extra netlisting results; `ls
xschem_library/examples/*~.sch` gives 6 here and 3 there. Everything else in both logs
matches line for line, including the pre-existing `test_sky130a_libmgr` failure (an extra
library in this workarea), which is byte-identical on both.

**Where a shipped flow *does* leave content in an unmodified untitled buffer.** The claim
"a freshly created untitled buffer is 0 in every one of those arrays" is necessary but not
sufficient — what matters is whether anything *puts* content there and then clears
`modified`. Census of every `set_modify 0` / `set_modify(0)` in the tree:

* `src/wave_viewer.tcl:926` — the `with_edit`/D1 contract. **This issue.**
* `src/create_graph.tcl:54` — `create_graph` does `xschem clear force`, draws a title
  **text** and a graph **rect** into the current buffer, then clears `modified` "so we can
  quit without xschem asking to save". That is a shipped, upstream-provided helper that
  leaves exactly the hijackable state, in a window that is *not* branded a viewer. It has
  no in-tree caller (it is called from user scripts), which is why no test moved.
  Pre-fix, opening a file into that window destroyed the graph silently; post-fix the open
  routes to a new window. **The emptiness hardening is what covers this one — the
  `wave_viewer` flag does not.**
* `src/xschem.tcl:5802` — descend read-only clears the `modified` the load itself set. The
  buffer is named after a real file, so the basename clause refuses reuse anyway.
* `src/save.c`, `src/scheduler.c` (`clear force`), `src/callback.c` (aborted merge) — either
  a named file, or nothing was drawn.

Greps run and what they found: `grep -rn "untitled" src/*.tcl` (no startup insertion —
the hits are naming/adoption logic in `ase.tcl`, `save_as_form.tcl`, `alt2_toggle_view.tcl`,
plus the reuse comments themselves); `src/xschemrc`, `~/.xschem/xschemrc`,
`src/cadence_style_rc` (**no** drawing commands at all, so no rc-driven template or title
block); shape-placing Tcl (`place_sym_pins.tcl`, `create_graph.tcl`, the Tools > Insert
line menu entry — all user-invoked, and only `create_graph` clears `modified`);
`create_graph` callers repo-wide (**none** outside git worktree copies and docs).

### 4. A refusal now explains itself (Task 4)

Every early return in `is_pristine_untitled()` names itself at `dbg(1, ...)`, and the
accepting path prints the name it accepted. Measured with `-d 1` on the shipping binary,
one line per case:

```
NO -- this window is a waveform viewer
NO -- buffer is modified
NO -- buffer has content (instances=0 wires=1)
NO -- buffer has 1 text object(s)
NO -- 1 rect(s) on layer 2
NO -- 1 line(s) on layer 21
NO -- 1 polygon(s) on layer 21
NO -- 1 arc(s) on layer 21
YES -- empty buffer named ".../untitled.sch" (reused in place)
```

Level 1 costs nothing in normal use (`dbg()` returns immediately below the level).

### 5. Decision: the emptiness hardening (E–I) STAYS

It is a contiguous block that reverts cleanly, so this was a real choice. Kept, on this
evidence:

1. **It has a real workflow to protect that the flag does not.** `create_graph.tcl` builds
   a graph in an unmodified untitled buffer with no `wave_viewer` brand. A viewer-only fix
   leaves that window hijackable — same defect, different door.
2. **It costs nothing measurable.** Identical per-test status across the whole audit on the
   no-X arm, and the reuse behaviour it could have broken is pinned by P0–P2, R1 and
   `test_untitled_reuse` — all green, and green pre-fix too.
3. **Every clause of it is now guarded**, one clause → one named set of legs, verified by
   rebuilding with each clause neutralised.
4. The old predicate's own comment claimed "empty (no instances/wires)" while the code
   ignored five of the seven object arrays. Keeping the flag and dropping the hardening
   would leave that contradiction in place for the next thing that clears `modified`.

## One thing the flag itself broke, and the fix for it

A per-context flag travels with the *document*, but "this window is a viewer" is a
property of the *Tk surface* — the WaveViewer bindtags and the viewer menubar stay on the
widget. `swap_windows()` / `swap_tabs()` (`src/xinit.c`), which run when the **main**
window is closed while another window/tab exists, swap the two contexts between slots and
then re-swap `top_path` / `current_win_path` / `window`. So the viewer's document lands on
`.drw` — and, before this was fixed, its brand with it: the ordinary editor canvas came
out `wave_viewer 1` permanently (nothing clears it, and unlike `readonly` it is not reset
by `clear_schematic`), so `.drw` was never a pristine-untitled reuse target again, even
after File>New. Measured A/B with a control, headless, both in windowed and tabbed mode.

Fixed by swapping `wave_viewer` back alongside the window paths in both functions; legs
`W-win` / `W-tab` guard it, and were confirmed red against a `HEAD` `src/xinit.c`. The
sibling flags (`readonly`, `no_grid`, `no_snap`, `graph_snap`) have exactly the same
surface-vs-document mismatch and were left alone deliberately — that is a bigger
behavioural claim than this issue supports; recorded in issue 0186.

## Residual risks (measured, filed, not fixed here)

* **`xschem reload` still wipes a viewer** and clears `readonly` as a side effect —
  issue 0186. Reproduced headless on the post-fix binary.
* **`xschem load -window <win>` and the in-place-hint loads** (`-inplace`, `-nodraw`, …)
  bypass the predicate by design and still land in place on a viewer — issue 0186.
* **`wviewer::open`'s own "did the context follow?" guard compares a value with itself**
  and can brand a live user schematic with all five flags — issue 0187, pre-existing, and
  reproduced both headless and under X.
* **CG9/CG10 need X.** Without a `DISPLAY`, `test_wave_clear_all` skips the whole CG block
  and still prints `RESULT: ALL PASS (3 checks)`; the file now prints an explicit NOTE
  saying the 0172 legs did not run. The headless guard is the one that runs everywhere.

## Cross-references

* `doc/claude/specs/waveform_viewer.md` — the `with_edit` / D1 read-only contract
  that makes `modified == 0` permanent.
* `doc/claude/specs/load_window_routing.md` — the reuse rule this predicate implements.
* `doc/claude/issues/0171-viewer-clear-all-ctrl-d.md` — the `Ctrl-D` that makes
  this destructive rather than cosmetic.
* `doc/claude/specs/graph_markers.md` §6.1.1 — the `Ctrl-E` that surfaced it.
