# Issue 0002 — the ghost window that survived xkill

**Opened:** 2026-06-11
**Status:** RESOLVED 2026-06-11 (pending user observation over the next few
sweeps — the ghost lives on the Windows desktop, invisible from inside WSL).
Fix shipped: explicit **`--nolog`** option (no action log + no CIW auto-open),
adopted by `run.sh` and the GUI-smoke invocation pattern; the two
logging-subject smokes destroy the CIW cleanly before exit. This supersedes
§7's auto-detect-`--script` proposal with a simpler explicit opt-out (user's
call). Plan: `claude_suggs/plan_nolog_option.md`. Residual trigger budget: 2
CIW mappings per sweep (test_ciw, test_action_log_dispatch), both with clean
`destroy + update` teardown, vs ~16 map-then-die windows before.
Bonus found while fixing: the engine harness (`run.sh`, which runs with X and
no `--logdir`) had been BOTH littering `tests/headless/Xschem.log{,.N}`
(masked by .gitignore) AND auto-opening a CIW per run since Phase 0 — it was a
ghost trigger too, now also covered by `--nolog`.
**Affects:** any WSLg session that runs the GUI smoke suite after commit `80d63eb9`
**Sibling:** issue 0001 (the WSLg display wedge) — same environment layer,
different failure mode; this doc assumes no prior knowledge of that one

This write-up is deliberately tutorial-style: the *path* to the diagnosis is the
reusable part, more than the diagnosis itself.

---

## 1. The symptom

After a code-update-then-run-the-tests cycle, one extra window is left on the
Windows desktop: just a frame — title bar, minimize/maximize/close controls —
with **nothing inside it**. No application content, no redraw.

Two facts about it were the real clues, and they looked like throwaway
frustrations at first:

1. **`xkill` cannot kill it.**
2. The only thing that removes it is **`wsl --shutdown`** from Windows.

Hold on to those. Most of the diagnosis falls out of taking them literally.

## 2. Reasoning from the symptom — what xkill immunity *means*

`xkill` does one thing: you click a window, it finds the X **client** (the
connected application) that owns it, and severs that client's connection to the
X server. The window then dies because its owner died.

So "survives xkill" admits very few explanations:

- (a) the owning process ignores the connection loss — rare, and the window
  would still be destroyed server-side;
- (b) **there is no owning client and no X window at all** — xkill has nothing
  to act on.

And the second clue discriminates between them. `wsl --shutdown` doesn't just
kill your distro — it also kills the **WSLg system distro**, which runs Weston,
the compositor that puts Linux windows on the Windows desktop. If restarting
*Weston* is what clears the frame, the frame must live **inside Weston**, not in
the X server and not in any application.

That's a falsifiable hypothesis, and it's checkable from inside WSL in two
commands.

## 3. Verifying: look for the corpse

If hypothesis (b) is right, there should be *no* leftover process and *no* X
window behind the visible frame:

```sh
$ pgrep -a xschem
(nothing — rc=1)

$ xwininfo -root -tree
  4 children:
     0x200056 (has no name)   ← Weston bookkeeping
     0x200027 "Weston WM"
     0x200002 (has no name)
     0x200001 (has no name)
```

No xschem process. No client X windows at all — only the compositor's own
internals. Yet the frame is still visible on the desktop. **Confirmed:** the
ghost exists only on the Windows side of the fence.

This is the moment the bug stops being "something in our code holds a window
open" and becomes "something in our code *triggers a leak in the platform*".
Those need different fixes: you can't close a window you don't own.

## 4. Background: how a Linux window becomes a Windows frame

To see where the leak lives, follow one window through WSLg's pipeline:

```
xschem (pure Xlib client)
  → XWayland          (X server living inside the WSLg system distro)
    → Weston          (Wayland compositor, WSLg's build)
      → RDP "RAIL"    (Remote Application Integrated Locally — each Linux
                       window is remoted as an individual app window)
        → mstsc/msrdc on Windows draws the actual frame you see —
          title bar, min/max/close are NATIVE Windows chrome
```

The frame with controls-but-no-content is exactly what a **RAIL window whose
backing surface is gone** looks like: Windows still holds the frame it was told
to create, but the Linux surface that fed its content no longer exists.

The leak mechanism: when a window is created, mapped, and destroyed in quick
succession — especially when the client *process exits* mid-handshake — Weston's
RAIL channel can fail to send (or the Windows side fails to process) the
matching "destroy window" order. The Windows-side frame is orphaned. This is a
known WSLg bug class with short-lived windows; nothing on the Linux side still
references the frame, which is why no Linux-side tool can remove it.

## 5. Whodunit: which window, which commit

"After one of the recent updates" + "each time we run tests" narrows it fast.
Ask: *what changed recently in how many windows a test run creates and how long
they live?*

```sh
$ git log --oneline -5
ec8de190 feat(logging): Phase 1 Layer A first slice — ...
31f95a02 docs(logging): add per-spec progress checklist ...
80d63eb9 feat(logging): CIW — live log window with command entry   ← suspect
4334b00f feat(logging): action-log Phase 0 — ...
```

Commit `80d63eb9` added the CIW (Command Interpreter Window) and **auto-opens it
on every interactive startup** (`ciw_create` in xschem.tcl's `has_x` block —
spec decision 8). Now line up the test-run timeline against the leak recipe from
§4:

- Every GUI smoke runs `xschem --pipe -q --script <test>.tcl` **on a real
  display** (these are unattended-but-windowed tests; see the tests/headless
  README). Startup auto-opens `.ciw` as a second toplevel.
- `-q` makes the process **exit the moment the script ends** — typically one or
  two seconds after `.ciw` mapped. Map → process-exit, back to back.
- A full sweep is **14–16 such launches in a tight loop**. Before `80d63eb9`,
  the same sweep created only the main window per launch (long-lived relative
  to the handshake) plus the occasional dialog.
- `test_ciw.tcl` is the most provocative single test: it maps `.ciw`,
  **withdraws** it (exercising the close protocol), **re-maps** it, then exits
  — a map/unmap/map/die sequence inside a few hundred milliseconds.

So the CIW didn't *introduce* a bug in the ordinary sense — the leak is
WSLg's — but it changed our trigger rate from "almost never" to "a dozen
dice-rolls per test sweep". One leaked frame per sweep is exactly the observed
"one ghost each time we update code and run tests".

(Likely related in hindsight: the WSLg wedge of issue 0001 happened during
heavy smoke iteration. Same compositor, same kind of stress.)

## 6. The fingerprint, for next time

| Observation | What it tells you |
|---|---|
| Empty frame: native chrome, no content | RAIL frame whose Linux surface is gone |
| `xkill` has no effect | No X client owns it — nothing to kill |
| `pgrep <app>` empty | Not a hung/leaked process |
| `xwininfo -root -tree` shows no client windows | Not an X window at all — the leak is compositor-side |
| Only `wsl --shutdown` clears it | The orphan lives in Weston (WSLg system distro) |
| Started when a new short-lived toplevel entered the hot path | That window is the trigger; reduce its create/destroy churn |

Diagnostic order that worked, generalized:

1. Take the "weird" symptom literally (`xkill` immunity is *evidence*, not noise).
2. Form the discriminating hypothesis (live client vs orphaned frame).
3. Check for the corpse: `pgrep`, then `xwininfo -root -tree`.
4. Only then read code — and read it asking "what creates/destroys windows
   *quickly*", not "what is buggy".

## 7. Fix direction (proposed, not yet applied)

The platform bug isn't ours to fix; the trigger is. Stop creating
human-facing windows in runs no human watches:

1. **Suppress the CIW auto-open in scripted runs.** Gate the `ciw_create` call
   on the session being interactive *in spirit*: skip when `--script`/`-q` is
   in effect. `cli_opt_tcl_script`/`cli_opt_quit` are not currently visible to
   Tcl, so mirror one as a Tcl variable in `xinit.c` before `xschem.tcl` is
   sourced. Spec decision 8 ("auto-open for interactive sessions") gets its
   wording refined — a script-driven run that quits on completion is not an
   interactive session.
2. `test_ciw.tcl` then calls `ciw_create` explicitly at the top (it tests the
   CIW itself; the *auto-open* condition check moves with the gate).
3. Optional hardening: tests that open extra toplevels destroy them and
   `update` before `exit`, giving Weston a clean destroy order while the
   client is still alive.

This removes ~all trigger events without changing anything a human user sees:
their interactive sessions still auto-open the CIW, and their windows live long
enough that the handshake race is not a practical concern.

## 8. Workaround until then (and for any recurrence)

A leaked frame is cosmetic — it holds no resources worth caring about — but the
only way to remove one is to restart WSLg:

```powershell
wsl --shutdown     # from Windows; kills the session — commit work first
```

Minimizing the ghost or dragging it aside also works for ignoring it within a
session.

## 9. Recurrences

- **2026-06-11 (Layer C session).** Ghost frame titled `xschem - untitled.sch`,
  transparent body. Verified per §3: `pgrep xschem` empty, `xlsclients` empty,
  nothing in `xwininfo -root -tree` — compositor-side orphan again. Trigger was
  a NEW variant of the same class: the first run of
  `tests/headless/test_gesture_end_log.tcl` hung (a no-motion right-click fell
  through to the real context-menu popup, which blocked on a Tk grab) and was
  SIGTERM-killed by `timeout` — an abnormal teardown while a grabbed popup was
  mapped. The test now stubs `proc context_menu {} {return 21}` so that hang
  cannot recur, but the general lesson stands: **a timeout-killed GUI smoke is
  a ghost-frame factory** — stub anything that can block (popups, dialogs) so
  smokes always reach their clean `destroy`+`update`+`exit` path, and treat a
  smoke that needed `timeout` to die as a bug in the smoke. The stale title is
  expected: the orphaned frame stops receiving title updates, so it shows
  whatever was last set (here the pre-load default).
