# Issue 0172 — a waveform-viewer window gets hijacked by the pristine-untitled reuse path

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
Next free issue number after this one is **0186**.
**Never push** — commit, raise `tools/review_gate/review_gate.sh` in the background, and wait.

Doc: `doc/claude/issues/0172-viewer-buffer-hijacked-by-pristine-untitled-reuse.md`. Read it
first; this prompt does not repeat the discovery story. It corrects two things in that doc
and hands you a reproduction the doc did not have.

---

## ⚠ Read this before you plan anything: it reproduces HEADLESS

The issue doc frames this as a viewer problem and puts the regression guard in
`tests/headless/test_wave_clear_all.tcl`, whose viewer legs need a real Tk viewer and a
`$DISPLAY`. **You do not need any of that.** `is_pristine_untitled()` never looks at the
viewer, only at the buffer's shape — so a buffer shaped like a viewer's is hijacked
identically with no Tk, no `DISPLAY`, no `wviewer::open`. Measured 2026-07-31 under
`--nogui`:

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
after   rects2=0 inst=1 wires=1                        ntabs=0 sch=real.sch
```

`ntabs` never moved and `rects2` went to **0**: the schematic was loaded *into* the
viewer-shaped buffer and its graph rect was destroyed. That is the whole defect, in a
headless test leg. **Build the regression guard on this**, and treat a real-viewer GUI leg
as an optional extra rather than the mechanism.

Two consequences worth stating plainly:

* the guard does **not** belong only in `test_wave_clear_all.tcl` — the defect is in the
  load path, not the viewer. Put the headless legs where the load path is tested and, if
  you want a viewer-shaped leg near the viewer, cross-reference it.
* `readonly = 1` does **not** protect the buffer today. Measured: a readonly pristine
  untitled buffer is reused exactly like a writable one. So "it is read-only, nothing can
  reach disk" is a mitigation, not a guard.

---

## What the code actually says — measured, line numbers re-derived 2026-07-31

The issue doc's line numbers have drifted. Current:

| what | where |
|---|---|
| `is_pristine_untitled()` | `src/scheduler.c:6167` |
| caller 1 — `xschem load -gui` routing | `src/scheduler.c:6468` (`route_newwin = has_x && !force && !inplace_hint && !is_pristine_untitled()`) |
| caller 2 — `load_new_window <file>` | `src/scheduler.c:6666` |
| caller 3 — `load_new_window` via the file dialog | `src/scheduler.c:6687` |

```c
static int is_pristine_untitled(void)
{
  if(!xctx) return 0;
  if(xctx->currsch != 0) return 0;
  if(xctx->modified) return 0;
  if(xctx->instances != 0 || xctx->wires != 0) return 0;
  if(!xctx->sch[xctx->currsch]) return 0;   /* NULL-safe (issue 0023) */
  return (xctx->sch[xctx->currsch][0] == '\0' ||
          is_untitled_basename(xctx->sch[xctx->currsch]));
}
```

**There are THREE doors, not one.** The issue doc names only the `load_new_window` one.
`xschem load -gui` (caller 1) reaches the same hijack by a different route, and the CIW
rewrites a typed `xschem load <file>` into exactly that form
(`tests/headless/test_ciw_interactive_load.tcl`, `doc/claude/specs/load_window_routing.md`).
Decide deliberately whether you are closing one door or all three, and say which in the
diff. **My recommendation: fix inside `is_pristine_untitled()`**, so all three close at
once — a viewer must never be a reuse target by any route, and a caller-side patch invites
the next caller to reintroduce it.

---

## The fix has a precedent already in the tree — use it

`wviewer::open` (`src/wave_viewer.tcl:618-645`) already stamps **four** per-context C flags
onto the viewer's `xctx`, each with its own comment explaining why a global would be wrong:

```tcl
xschem set readonly 1            ;# D1
xschem set no_grid 1             ;# item 18
catch {xschem set no_snap 1}     ;# issue 0177
catch {xschem set graph_snap_cursor 1}   ;# item 9
```

A fifth flag is the established shape, and it is the honest oracle the issue asks for
without a C→Tcl query into `wviewer::windows`:

* declare it next to `no_grid` (`src/xschem.h:1735`) and `no_snap` (`:1738`);
* add the `xschem get` arm next to `no_snap`'s (`src/scheduler.c:4197`) and the
  `xschem set` arm next to its (`src/scheduler.c:10544`);
* `alloc_xschem_data()` (`src/xinit.c:621`) allocates the context with
  `my_calloc`, so **every other context gets 0 for free** — verified, not assumed. There is
  no explicit `no_grid = 0` / `no_snap = 0` anywhere, and that is why.

Making it settable from Tcl is not just for `wviewer::open`: it is what lets the regression
guard mark a buffer as a viewer **headlessly**, which is what makes the whole thing testable
without Tk.

Note `wviewer::open`'s own guard immediately above those four lines: it re-checks
`[xschem get current_win_path] ne $wp` and *refuses* rather than branding the flags onto
whatever window actually holds the context. Your new flag is stamped in the same block, so
it inherits that protection — do not move it above the check.

### The alternative, and why I am not recommending it

Refusing reuse whenever `xctx->readonly` is set would also fix this and needs no new flag.
It is a bigger behavioural claim than the issue supports, though: this branch has several
paths that open ordinary schematics read-only (descend read-only, the reopen shortcuts), and
a read-only buffer is not obviously a bad reuse target. If you take that route instead,
bring the reasoning and expect to prove it against `test_load_window_routing.tcl`.

---

## Phase 1 — RED first, headless

Turn the block at the top of this prompt into failing legs before you touch any C. At
minimum:

* **the defect**: viewer-shaped buffer + `load_new_window` → assert the buffer still holds
  its own graph rect and that a new window/tab appeared. Pre-fix this fails on both halves.
* **the behaviour that must NOT change**: a genuinely pristine untitled buffer (no rects,
  writable) + `load_new_window` → still reused in place, `ntabs` unmoved. Measured today:
  `sch` goes from `untitled.sch` to `real.sch` with `ntabs` still 0. If your fix breaks
  this leg you have gone too far.
* **the other two doors**, if you close them: same pair for `xschem load -gui`.

Useful measured facts for writing the legs:

* `xschem get ntabs` is the window/tab counter (`get_window_count()`); there is no
  `get_all_windows` — a wrong query name aborts the script mid-way and the legs after it
  simply never run, which reads exactly like a passing test. I hit this.
* the non-pristine fallback **does** work headless: a modified buffer + `load_new_window`
  took `ntabs` 0 → 1 and left the new schematic current. So asserting "a new tab appeared"
  is legitimate under `--nogui`.
* `xschem clear force` after a load leaves the buffer named `untitled-1.sch`, not
  `untitled.sch`; `is_untitled_basename()` accepts both, so legs must not hard-code the
  name.

## Phase 2 — the fix, then the doors you did not close

Whatever you implement, the issue doc needs updating: it currently says the fix direction is
a `wviewer::windows` lookup, and it names one caller. Record what you actually did, the
three call sites, and the headless reproduction — that last one is the most useful thing to
leave behind.

---

## HARD-WON TRAPS — these cost real time, do not rediscover them

1. **A wrong `xschem get <thing>` aborts the whole script.** The Tcl error is reported once
   and everything after it silently does not run. Every leg after the mistake "passes" by
   not existing. Print a sentinel at the end and check the check-count.
2. **A test leg that passes on absent or unparseable output is passing VACUOUSLY.** Ask of
   every leg: *what does this print when the feature is completely broken?*
3. **Verify a "pre-fix" binary really is pre-fix** by running your new test against it and
   confirming it fails. `git show <sha>:src/<f> > src/<f>` — worktree only, so `git status`
   stays at ` M`; **`git checkout <sha> -- <file>` also writes the INDEX** and a later
   `git commit -a` silently reverts your fix.
4. **C changes need `cd src && make`. The shell's cwd PERSISTS across tool calls** — a later
   `./src/xschem` from inside `src/` fails with "No such file or directory".
5. **`xschem` needs `--pipe`** with `--script`, or it runs the file and prints NOTHING with
   `rc=0`. A whole suite reads as silently empty. Run
   `./src/xschem --nogui --pipe -q --script tests/headless/<t>.tcl`.
6. **Scratch dirs: always `test_scratch` from `tests/headless/scratch.tcl`.** Throwaway
   probes go in the session scratchpad, never in the repo.
7. **A new test must end with `RESULT: ALL PASS (N checks)`** or `full_audit.sh`'s
   `is_pass()` scores it FAIL while every leg prints ok. Several existing suites end
   `OVERALL: ok` instead and are scored **NORESULT on both arms** — that is a known
   pre-existing harness gap, not a failure you introduced.
8. **Subagents report confident wrong answers, including about code they claim to have
   read.** In the 0183 session two agents were wrong about `actions.c` in opposite
   directions, and I was wrong to dismiss a third that turned out to be right. Reproduce
   everything yourself before believing or refuting it.
9. **The GUI arm is unreliable on this box (WSLg).** Keep this issue headless. If you do add
   a real-viewer leg, run suites with
   `SUITE_TIMEOUT=900 GUI_GATE=0 tests/headless/run_suites.sh --nogui <names>`, **never a
   bare loop**.

---

## Suites that must stay green

Measured 2026-07-31, `--nogui` arm, at `7cf1858c`:

```
test_ciw_interactive_load             (the typed-load -> -gui rewrite; pure Tcl)
test_empty_value_swallows_token_0183   69
test_schpins_stale_lab_0185            15
test_list_nets_null_token_0180          9
test_hash_extra_node_warn_0165         15
test_tedax_extra_pinnumber_0179        10
test_resolved_net_attr_scope_0163      34
test_resolved_net_templ_fallback_0164  23
test_hash_label_crash_0156             23
test_ase_unnamed_net                   28
test_sch_add_pin                       21
test_add_wire_label                    59
```

**`tests/headless/test_load_window_routing.tcl` is the one most at risk** — it is the
existing guard on exactly this decision ("reuses the current window only when it is a
pristine empty untitled scratch"). It **needs X** and says so in its header:
`DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_load_window_routing.tcl`.
Run it, and if the WSLg display makes that impossible, say so explicitly rather than
quietly skipping it.

`tests/headless/test_wave_clear_all.tcl` carries the `CA*` legs that run under `--nogui` and
the `CG*` legs that need a viewer; the issue doc asks for the guard there, and you may still
want a cross-reference from it.

`tests/netlist_diff/netlist_diff.sh <old-binary>` is **not** indicated here unless you touch
netlisting — this is a window-routing change. Say so rather than running it out of habit.

## How I want you to work

1. Reproduce the symptom yourself, headless, before trusting any of this prompt.
2. Decide **one door or three** on the evidence, and put the reasoning in the diff.
3. RED before GREEN, and keep the "a plain pristine untitled buffer is still reused" leg —
   that behaviour is deliberate and specced.
4. Issue doc updated with what you actually established, including the corrections to it
   this prompt makes. Commit. Raise the review gate. **Never push.**
5. Report what you verified, what you did **not**, and any judgement call I should weigh in
   on.
