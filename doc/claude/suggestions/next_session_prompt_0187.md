# Issue 0187 — `wviewer::open`'s "did the context follow?" guard compares a value with itself

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
Next free issue number after 0186 is **0188**.
**Never push** — commit, raise `tools/review_gate/review_gate.sh` in the background, and wait.

Doc: `doc/claude/issues/0187-wviewer-open-context-guard-is-circular.md`. Read it first.
This prompt gives you the exact code, the one trigger I verified myself, the one I did
**not**, and why the testing is the hard part rather than the fix.

---

## The bug, in six lines of Tcl

`src/wave_viewer.tcl`, inside `wviewer::open`:

```tcl
580   set before [xschem get current_win_path]
581   set tops0 [winfo children .]
582   xschem load_new_window -window {}
583   set wp [xschem get current_win_path]
584   if {$wp eq $before} {
          # recovery loop: find the toplevel that was not there before and switch to it,
          # overwriting wp ONLY when the switch is VERIFIED to have landed
591       if {[xschem get current_win_path] eq "$t.drw"} { set wp $t.drw; break }
      }
...
602   if {$top eq {.}} { ... return 0 }          ;# ROOT window only
...
618   if {[xschem get current_win_path] ne $wp} {   ;# ← THE GUARD
619     ciw_echo "wviewer: the waveform window did not take the context, refusing" error
620     return 0
      }
626   xschem set readonly 1                       ;# five brands follow
631   xschem set no_grid 1
      catch {xschem set no_snap 1}
      catch {xschem set graph_snap_cursor 1}
656   catch {xschem set wave_viewer 1}            ;# added by 0172
```

`wp` is *read from* `current_win_path` at 583 (and only ever replaced at 591 by a value
that was **just verified** to equal `current_win_path`). Between there and 618 there is a
`regsub` and the `$top eq {.}` test — no `update`, no event loop, nothing that can move
the context. **Line 618 compares `current_win_path` with itself and can never fire.** The
only live guard is `$top eq {.}`, which catches slot 0 and nothing else: a context parked
on any `.xN.drw` — a detached editor, or any non-first tab, since `create_new_tab` names
them `.x<n>.drw` too — sails straight through and gets branded.

The comment block at 608-616 states precisely the case it believes it is guarding
("if the previously-current window was a DETACHED editor `.xN`, all four settings below
would be branded onto a real schematic the user is editing"). That case is exactly the
one that gets through.

---

## Trigger A — slots full. I verified this one myself, headless

`MAX_NEW_WINDOWS` is 20 (`src/xschem.h:158`). With every slot used,
`create_new_window()` returns **before** creating anything and before `(*window_count)++`
(`src/xinit.c:1966-1968`), printing only a `dbg(0, ...)` line — **no Tcl error, rc 0**.
So no new toplevel exists, the recovery loop finds nothing, and `wp` stays `== before`.

```tcl
set ::tabbed_interface 0
for {set i 0} {$i < 25} {incr i} {
  set before [xschem get current_win_path]
  set rc [catch {xschem load_new_window -window {}} e]
  set after [xschem get current_win_path]
  if {$after eq $before} { puts "i=$i rc=$rc err='$e' before=$before after=$after"; break }
}
```

```
new_schematic("create"...): no more free slots
i=19 rc=0 err='' before=.x19.drw after=.x19.drw ntabs=19 -- CONTEXT DID NOT MOVE
```

That is the whole precondition for the guard to pass while the context never moved. The
rest — that `wviewer::open` then brands the current schematic — is arithmetic, but see
"Testing" below: you cannot run `wviewer::open` headless to finish the demonstration.

**A subagent reported the end-to-end GUI form** (fill 19 slots, park a 23-instance
schematic in `.x19.drw`, register an ASE session, call `wviewer::open`): it returned
**1** for success, the user's schematic stayed loaded, and the window came out
`wave_viewer=1 readonly=1 no_grid=1 no_snap=1` with the viewer registry pointing at
`.x19`. **I did not re-run that myself.** Re-measure it before you build on it.

## Trigger B — the semaphore no-op. NOT established

The 0177-era comment says the context switch is *measured* to no-op ~3 times in 10 under
a raised semaphore, and that is why the guard exists at all. A subagent tried to drive
that end-to-end and could not: `switch_window` bails on `if(xctx->semaphore) return 1;`
(`src/xinit.c`), `callback()` raises the semaphore on every event, and every production
caller of `wviewer::open` it traced is Tk-driven with the C callback already broken out
of. Treat trigger B as **unproven** — the fix should not depend on it, and neither should
your test.

---

## Why this matters more since 0172

Four of the five brands are pre-existing and their damage is visible and recoverable: the
window goes read-only and loses its grid and snap; the user can see it and undo it.

The fifth, `wave_viewer` (`src/xschem.h:1760`), is **invisible and permanent** — nothing
in production ever clears it (`grep -n "set wave_viewer 0"` finds only the test) — and it
removes the window from the pristine-untitled reuse path and forces `ask_new_file()`
(`src/actions.c:701`) down its new-window arm for the rest of the session.

Keep the honest counter-argument in view: once `wviewer::windows` points at that window,
the window *functionally is* the viewer, so refusing to reuse it is arguably consistent.
**The defect is the branding of a live schematic, not the refusal that follows.**

---

## Two directions, and my leaning

1. **Compare against the INTENDED target, not against a re-read of the same source.**
   Capture the window path the viewer is supposed to land on (the toplevel that
   `load_new_window -window {}` was expected to create), and refuse when the context is
   not there. This is the actual repair — the current test is structurally incapable of
   failing.
2. **Make `create_new_window` report failure.** `src/xinit.c:1966-1968` returns silently on
   "no more free slots"; that silence is what makes trigger A possible at all. A caller
   that could see the failure would not need to infer it from window paths. This is a C
   change with a wider blast radius (`new_schematic` verbs are used everywhere) — worth
   doing, worth doing carefully, and worth its own guard test.

A third, much cheaper mitigation specific to the 0172 flag, if you want a belt while
deciding: refuse to stamp when the context holds instances or wires. A viewer never does.
It is a heuristic, not a fix, and it should be *additional*, not instead.

---

## Testing — the hard part

`wviewer::open` **cannot run headless**: `src/wave_viewer.tcl:556` is
`if {![info exists ::has_x]} { return 0 }`, and `::has_x` is set only when the C side has
X (`src/xinit.c`, `tclsetvar("has_x","1")` inside `if(has_x)`), which `--nogui` forces to
0 (`src/options.c`). Everything past the brands is Tk: menubar, bindtags, `winfo`.

So you have three honest options, in preference order:

* **Extract the decision.** Pull the "which window should the viewer be on, and did it
  get there?" logic into a proc that takes the paths as arguments and returns a verdict.
  Then it is testable headless with no Tk at all, and the guard becomes something a test
  can drive into every failure mode instead of one it can only reach by luck.
* **A GUI leg** in `tests/headless/test_wave_clear_all.tcl` (its CG block already opens a
  real viewer and self-skips without a `DISPLAY`; CG9/CG10 are the issue-0172 legs and
  are worth reading as a template). Note the harness gap: with no `DISPLAY` the whole CG
  block is skipped and the file still prints `RESULT: ALL PASS (3 checks)`, so a
  GUI-only guard is invisible in a headless run — the file now prints an explicit NOTE
  about exactly this.
* **A headless leg for the precondition only** (trigger A above), which is real,
  deterministic, and cheap — plus a comment saying what it does and does not prove.

Whichever you pick, say plainly in the issue doc which failure modes are guarded and
which are argued.

---

## HARD-WON TRAPS

1. **`xschem` needs `--pipe`** with `--script`, or it prints nothing with `rc=0`.
2. **An unknown `xschem get <name>` returns the EMPTY STRING, rc 0**; an unknown
   `xschem set` errors and aborts the whole script, so every later leg "passes" by never
   running. End with a sentinel and assert the leg count.
3. **`new_schematic` verbs fail SILENTLY when slots are full** — that is this issue, and
   it will also bite your test fixture the moment it opens more than 19 windows.
4. **Per-context flags survive `xschem clear force`.** Clear them explicitly between legs.
5. **Verify pre-fix with `git show <sha>:src/<f> > src/<f>`** (worktree only) —
   `git checkout <sha> -- <f>` also writes the index, and a later `git commit -a` reverts
   your fix. Back the file up to the scratchpad first.
6. **`make -C src`** — the shell cwd persists across tool calls.
7. **WSLg**: the X server dies a few times per session, taking every client with it. A
   suite that vanishes mid-run is usually that, not your change. Use
   `tests/headless/run_suites.sh` / `gated_xschem.sh`, never a bare loop.
8. **Subagents are confidently wrong in both directions** — including about this issue,
   where one refuted the finding on a technicality after another had reproduced it. The
   GUI measurement quoted above is second-hand; re-run it.

---

## Suites that must stay green

Measured at `abfe1153`:

```
--nogui:  test_pristine_untitled_viewer_0172   25
          test_untitled_reuse                   6
          test_wave_clear_all (CA legs only)    3
X arm:    test_wave_clear_all                  75
          test_wave_viewer                    368
          test_wave_snap                       90
          test_load_window_routing             14
          test_clone_canvas_bindings            3
```

Anything that opens a viewer is at risk here, because you are changing whether
`wviewer::open` refuses. `test_wave_viewer` (368 checks) is the one that will tell you.

## How I want you to work

1. Reproduce trigger A yourself, headless. Then decide whether you can reproduce the
   end-to-end GUI form; if the display makes it impossible, **say so explicitly** rather
   than quietly assuming it.
2. Fix the guard so it can actually fail; decide separately whether
   `create_new_window`'s silent return is in scope this session.
3. Make the decision testable — extracting the seam is worth more than the fix itself.
4. Issue doc updated with what you established, including which failure modes remain
   argued rather than guarded. Commit. Raise the review gate. **Never push.**
5. Report what you verified, what you did **not**, and any judgement call I should weigh
   in on.
