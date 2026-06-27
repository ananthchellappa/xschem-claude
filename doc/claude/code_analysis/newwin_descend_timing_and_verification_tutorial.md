# The window that opened blank — a tutorial on event-timing races, "fix what you can't reproduce," and the discipline of verification

*How a freshly-opened editor window came up **completely blank until you resized
it**, why the first fix was correct in theory but useless in practice, and what
that one bug teaches about the parts of GUI programming that tutorials almost
never mention: that **a draw depends on state that may not exist yet**, that
**an event you arm for can simply never arrive**, that the right fix is often to
**replicate the exact manual action the user confirmed works**, and — the part
nobody teaches — **how to gain confidence in a fix for a bug you cannot
reproduce on your own machine.** Written for a CS student who can wire up a
button callback but has never had to reason about *when*, in wall-clock and in
event-queue order, their code actually runs.*

This is a teaching companion to `doc/claude/issues/0035-descended-new-window-spuriously-modified.md`
and `doc/claude/issues/0037-newwin-descend-desync-and-exit-confusion.md` (§5 and §6). It is
a sibling to `doc/claude/code_analysis/blink_animation_tutorial.md` (which is about *time as
frames*) and `doc/claude/code_analysis/gui_focus_and_testability_lessons.md` (which is about
*which window is "current"*). This one is about a third invisible axis:
**the order in which a window comes into existence**, and what your code is
allowed to assume at each instant. All code is real and lives in
`src/actions.c`, `src/xinit.c`, `src/callback.c`, `src/scheduler.c`, and
`src/xschem.tcl`; line numbers were read from source and are reproducible.

The feature involved is mundane — "open this sub-circuit in a new window." The
bug is a single missing assumption. And yet getting from "it's blank" to a fix I
*trusted* took two wrong turns, a fake reproduction harness, and a near-miss that
would have silently broken an existing command. Every one of those is a lesson
you will reuse for the rest of your career.

---

## Part 0 — The one-sentence idea

> When you create a window and immediately draw into it, **the window does not
> have its real size yet**. The drawing is computed against a placeholder
> geometry, and the event that *would* tell you the real size **can be dropped
> by the window manager** — so the only robust fix is to stop waiting for that
> event and **proactively re-fit the window once it has actually appeared.**

Everything below is that sentence, slowed down. If you ever build a UI that
sizes content to a window — a canvas app, a game viewport, a chart, a CAD tool,
a text editor that wraps — you will meet this exact problem.

---

## Part 1 — The two symptoms (state them precisely; precision is the whole game)

A user descends into a sub-schematic in a **new window** (the "E → New window"
flow). Two distinct things went wrong, reported together but with *different*
root causes. Half of debugging is refusing to let two bugs blur into one.

**Bug A — the blank window.** The new window opens with the *correct title* but
shows **nothing — not even the grid**. Descending one level deeper sometimes
shows *the grid but no schematic elements*. The fix the user found:
**"Resize the window and all works normally."** Pressing **F** (zoom-to-fit) also
fixes it.

**Bug B — the stale schematic.** In the parent window the user **adds a new
instance** without saving, selects it, and does E → New window. The new window
opens showing the **parent** cell — *the old version, without the just-added
instance* — and never descends into it. "Not even the proper schematic."

Notice how specific those are. "It's broken" is not a bug report. "Blank
*including the grid*, fixed by *resize*" and "shows the *old* parent *missing the
unsaved instance*" each point a finger at a different subsystem. **The exact
shape of a symptom is data.** We will use every word of it.

---

## Part 2 — The mental model: what a "draw" silently depends on

To see the bug you have to know what `zoom_full` — the "fit everything in the
window" operation — actually reads. Here is the load-bearing code
(`src/actions.c`, in `zoom_full()`):

```c
if(flags & 1) {
  ...
  xctx->areax2 = xctx->xrect[0].width  + 2*INT_LINE_W(xctx->lw);   /* actions.c:3098 */
  xctx->areay2 = xctx->xrect[0].height + 2*INT_LINE_W(xctx->lw);
  xctx->areaw  = xctx->areax2 - xctx->areax1;
  xctx->areah  = xctx->areay2 - xctx->areay1;
}
...
xctx->zoom = bboxw / schw;   /* schw derived from areaw */
```

Read that carefully. `zoom_full` computes the zoom factor as *"width of all the
shapes" ÷ "width of the drawing area."* The drawing-area width comes from
`xctx->xrect[0].width` — **the window's pixel size.** If that number is wrong,
the zoom is wrong, and "wrong zoom" means *everything is off-screen or
microscopic*: a blank window.

So the question becomes: **who sets `xrect[0].width`, and is it correct at the
moment `zoom_full` runs?** It is set by `resetwin()` (`src/xinit.c`), which asks
the X server for the window's real geometry:

```c
status = XGetWindowAttributes(display, xctx->window, &wattr);   /* xinit.c ~2537 */
if(status) { width = wattr.width; height = wattr.height; }
...
xctx->xrect[0].width  = (unsigned short) width;
```

`resetwin()` is called from exactly one place during normal interaction — the
**ConfigureNotify** handler, i.e. *"the window changed size"* (`src/callback.c`):

```c
case ConfigureNotify:                       /* callback.c:6061 */
  resetwin(1, 1, 0, 0, 0);
  draw();
  break;
```

**Here is the entire mental model in one breath:** the window's true size only
enters your program through a *ConfigureNotify event*. Until that event has been
processed, `xrect[0]` holds whatever placeholder was there at creation time. Any
draw before that event uses a lie.

> **Lesson 1 — Drawing has prerequisites, and they are not all in your call
> stack.** A function like `zoom_full()` looks self-contained, but it secretly
> depends on a *prior event* having been delivered and handled. The dependency
> is invisible in the code; it lives in the event timeline. When you read a draw
> routine, ask: *"what does this assume the system already told me?"*

---

## Part 3 — Bug A's root cause: the synchronous descend runs *before* the window is real

Now the descend. A descend ends, every time, with a fit (`src/actions.c`, end of
`descend_schematic()`):

```c
zoom_full(1, 0, 1 + 2 * tclgetboolvar("zoom_full_center"), 0.97);   /* actions.c:2746 */
```

In the **same window**, this is fine: the window has existed for a while, a
ConfigureNotify long ago set `xrect[0]` to the real size, the fit is correct.

In a **new window**, the orchestration (Tcl, `src/xschem.tcl`) is *synchronous*:

```
xschem schematic_in_new_window force window   ;# create the toplevel
xschem new_schematic switch <newwin>          ;# make it current
xschem select instance <inst>
xschem descend                                ;# <-- zoom_full() runs HERE
```

These run back-to-back with **no return to the event loop in between.** And here
is the crux: creating a Tk toplevel does *not* synchronously give it its final
size. The `Map`/`Configure`/`Expose` events are **queued**; they are delivered
only when control returns to the event loop — which is *after* `descend` has
already run its `zoom_full`. So the fit is computed against the placeholder
geometry. Blank.

The codebase already half-knew this. `create_new_window()` carries a deferred-fit
flag, `pending_fullzoom`, and a comment that is the smoking gun (`src/xinit.c`):

```c
/* paint now rather than waiting for an Expose event — some window managers
 * (e.g. WSLg) drop the first Expose, leaving the window blank until the mouse
 * moves over it. ... */                                       /* xinit.c:1826 */
```

The mechanism: arm `pending_fullzoom`, and when a ConfigureNotify *does* arrive,
`resetwin()` performs the fit then (`src/xinit.c`):

```c
if(xctx->pending_fullzoom > 0 && create_pixmap) {              /* xinit.c:2609 */
  tcleval("winfo ismapped .");
  if(tclresult()[0] == '1' && (width > 1 || height > 1)) {
    zoom_full(1, 0, ...);          /* fit, now that geometry is real */
    xctx->pending_fullzoom--;
  }
}
```

So my **first fix** was the obvious one: after the new-window descend, *arm
`pending_fullzoom`* so the window's settling ConfigureNotify re-fits it. Clean,
reuses the existing mechanism, verified in a harness. I shipped it mentally.

It did not work. And *why* it did not work is the most important lesson in this
document.

---

## Part 4 — Reading the user's clue like a detective

The user came back: *"It opens up blank... **Resize the window and all works
normally.**"*

Stop and weigh that sentence. My fix arms a fit that fires *on a
ConfigureNotify*. The user reports that the window is blank **until they
manually resize it** — and a manual resize **is** a ConfigureNotify. So:

- The mechanism works *when a ConfigureNotify arrives* (manual resize proves it).
- The window is blank *until* they cause one by hand.

There is only one explanation: **on this window manager (WSLg), the new window's
initial ConfigureNotify is never delivered.** The same comment at `xinit.c:1826`
already said WSLg *drops the first Expose*; it drops the first Configure too.
My fix armed a gun that waits for a trigger the WM refuses to pull.

> **Lesson 2 — The user's workaround tells you which event is missing.** "It
> works after I resize / click / hover / focus it" is not noise; it is a precise
> statement of *which event your code depends on and is not receiving.* Treat a
> workaround as a probe the user ran for you. "Resize fixes it" literally means
> "your fix depends on ConfigureNotify, and ConfigureNotify is your problem."

This reframes the whole fix. The lesson generalizes far past this codebase:

> **Lesson 3 — You cannot rely on an event arriving. Events are dropped,
> coalesced, reordered, and delivered late — especially across remoting layers
> (WSLg, VNC, X-over-SSH, RDP, browser tabs throttled in the background).** If
> correctness hinges on "the system will send me X," you have a latent bug on
> *some* configuration. The robust move is to stop waiting and **do the work
> proactively** once you can observe the precondition is met.

---

## Part 5 — The real fix: replicate the manual action, on a timer, defensively

The user told us the cure: a resize. A resize does two things — re-reads the
geometry and re-fits. So the fix is to **perform that ourselves, automatically,
once the window has actually appeared** — without waiting for the WM.

### 5a. Make the geometry refresh callable, and bypass the unreliable query

The deferred-fit lives in `resetwin()`, but `resetwin` re-queries the X server
with `XGetWindowAttributes` — which on WSLg *still* returns a transient 1×1 for a
just-mapped window even though **Tk already knows the real size**. So the new
command lets the caller pass the size straight through (`src/scheduler.c`,
extending the existing internal `resetwin` command):

```c
else if(!strcmp(argv[1], "resetwin")) {
  if(argc > 6) {                       /* full internal form: resetwin c c f w h */
    resetwin(atoi(argv[2]), ...);
  } else if(argc > 3) {                /* fit form: resetwin w h  (issue 0035/0037) */
    resetwin(1, 1, 1, atoi(argv[2]), atoi(argv[3]));  /* force, with explicit w/h */
    draw();
  }
}
```

The caller hands it `[winfo width $win] [winfo height $win]` — Tk's *known* size,
not the X server's *claimed* size.

> **Lesson 4 — When one source of truth is unreliable, prefer the layer that is
> authoritative for your purpose.** Two parts of the system "know" the window
> size: the X server (via `XGetWindowAttributes`) and Tk (via `winfo`). On WSLg
> they disagree during the window's first moments. Tk is the one that is right
> *for drawing*, so route the size through Tk.

### 5b. The two-pronged helper (fast path + proactive backstop)

`src/xschem.tcl`:

```tcl
proc newwin_defer_fullzoom {win} {                          ;# xschem.tcl:4378
  global has_x
  if { ![info exists has_x] || !$has_x } return             ;# no geometry race without X
  xschem set pending_fullzoom 1                             ;# (1) fast path: ride a real Configure
  after 120 [list _newwin_fit_fullzoom $win 0]              ;# (2) backstop: fit proactively
}
proc _newwin_fit_fullzoom {win tries} {                     ;# xschem.tcl:4384
  if {![winfo exists $win]} return
  if {[xschem get current_win_path] ne $win} return         ;# user moved on -> stop
  if {[xschem get pending_fullzoom] == 0} return            ;# a real Configure already fit it
  if {[winfo ismapped $win] && [winfo width $win] > 1 && [winfo height $win] > 1} {
    xschem resetwin [winfo width $win] [winfo height $win]  ;# force the fit, Tk's size
  } elseif {$tries < 25} {
    after 120 [list _newwin_fit_fullzoom $win [expr {$tries + 1}]]   ;# not realized yet; retry
  }
}
```

Three design decisions worth dwelling on, because each is a reusable pattern:

1. **Keep the fast path.** On a *normal* X server the ConfigureNotify *does*
   arrive and fits the window in milliseconds. The arm (`pending_fullzoom 1`)
   handles that case immediately. The backstop is only insurance. *Don't throw
   away the cheap correct path just because it isn't sufficient everywhere.*

2. **Poll for the precondition, don't assume it.** The backstop does not blindly
   fit at 120 ms; it checks `winfo ismapped` and `width > 1`, and **retries** if
   the window isn't realized yet. This is the proactive analogue of waiting for
   an event: instead of trusting the WM to *tell* us the window is ready, we
   *ask* until it is. Bounded (`$tries < 25`, ~3 s) so a never-realized window
   can't loop forever.

3. **Make it idempotent and self-cancelling.** If a real Configure already fit
   the window (so `pending_fullzoom == 0`), or the user has navigated away
   (`current_win_path ne $win`), the backstop does **nothing**. It can never
   fight the WM, never override a zoom the user just made, never double-fire.

> **Lesson 5 — "Defer until a precondition holds" beats both "do it now" (too
> early) and "wait for an event" (may never come).** The shape is: *arm the
> cheap path; schedule a bounded poll that does the work the moment the
> precondition is observably true; make the work a no-op if it's already done.*
> This is the same pattern as a retry-with-backoff, a `MutationObserver` that
> also checks initial state, or a React effect that guards on a ref being
> attached.

### 5c. The flag that could get stuck (a sub-lesson in shared state)

`pending_fullzoom` is not just a fit flag — it is *also* read elsewhere as "a new
window is opening, don't switch focus away from it" (`src/callback.c`):

```c
if(xctx->pending_fullzoom == 1) return 0;   /* no switching if opening a new window */  /* callback.c:5878 */
```

So if the backstop *armed* the flag and then nothing ever cleared it, the user
would be unable to hover-switch to other windows. The backstop's `xschem
resetwin` consumes the flag (the deferred-zoom block decrements it), so it
doubles as the un-stick. The earlier, weaker version of the fix used a separate
"clear it after 1.5 s" timer purely to prevent this dangle.

> **Lesson 6 — A piece of state that more than one subsystem reads is a
> liability you must track to zero.** Before you set a shared flag, ask: *"who
> else reads this, and what guarantees it gets cleared on every path —
> including the ones where my happy-path event never fires?"* A flag that gates
> behavior must have a cleaner that does not depend on the same unreliable event
> that set the need for it.

---

## Part 6 — Bug B: the new window read from *disk*, not from *memory*

Bug B is unrelated to timing and is a cleaner, more classic mistake. The
new-window flow opens the parent like this (conceptually):
`schematic_in_new_window` → `create_new_window` → `load_schematic(<parent file>)`.
That last call **reads the parent's file from disk.** But the user had just
**added an instance in memory and not saved.** So the new window faithfully
loads the *old* parent. The just-added instance isn't there; the subsequent
`select instance ... ; descend` finds nothing and silently no-ops; the window is
stranded on the stale parent.

Reproduced headlessly (this one *is* batch-reproducible, because it has nothing
to do with window geometry):

```
add instance xcn1 (unsaved)  -> parent has {x1, xcn1}, modified=1
new-window descend into xcn1 -> new window: schname=test.sch, only {x1}, currsch=0   # BUG
```

> **Lesson 7 — "Open it again" usually means "re-read it from storage," and
> storage lags memory.** Any time you "duplicate," "open in new tab/window,"
> "preview," or "reload," check whether you are cloning *live state* or
> *re-reading the saved copy*. Unsaved edits are the canonical thing that falls
> through that gap. The same bug shows up as: a "duplicate tab" that loses form
> input, a "preview" that shows the last-saved version, an "open in new window"
> that drops your cursor position.

### The fix: bridge memory → memory through the existing autosave backup

XSCHEM already writes a `~`-suffixed autosave backup whenever a buffer is
modified (so a descend or crash never loses edits). That backup *is* the live
in-memory state, serialized. So we don't need a new "clone memory" mechanism — we
bridge through the file that already exists (`src/xschem.tcl`):

```tcl
proc newwin_capture_unsaved {} {                ;# xschem.tcl:4408  (run while SOURCE is current)
  if { ![xschem get modified] } { return {} }
  xschem backup write                           ;# persist in-memory edits to <cell>~.sch
  return [xschem get schname]
}
proc newwin_restore_unsaved {src} {             ;# xschem.tcl:4416  (run in the NEW window)
  if { $src eq {} } return
  catch { xschem load_backup $src }             ;# reload those edits (same cell -> same backup)
}
```

Capture is called **before** opening (while the source is the active context);
restore is called **after** switching to the new window. Same cell name → same
backup file → the edits cross over. The descend target now exists; the descend
works (`comp_ngspice.sch, currsch=1` ✓).

> **Lesson 8 — Reuse the serialization you already have instead of inventing a
> new transfer path.** The temptation was to write a "copy in-memory objects from
> context A to context B" routine. But an autosave file is *already* "the live
> state, on disk." Bridging A→file→B is less code, exercises a path that already
> works, and is `catch`-safe (no backup ⇒ fall back to the disk version, i.e.
> exactly the old behavior — *no worse than before*). Best-effort degradation is
> a feature.

---

## Part 7 — The hard part: verifying a fix for a bug you cannot reproduce

Here is the uncomfortable truth that ran through the whole session: **I could not
reproduce Bug A on my machine.** In a headless/batch run there is no window
manager to map the window, so it comes up at its final size immediately and the
race never triggers. The bug is real but lives only in the user's WSLg
environment.

This is an extremely common situation — the bug is on *their* phone, *their* GPU,
*their* corporate proxy — and juniors freeze here, because "I can't reproduce it"
feels like "I can't fix it." It is not. Here is the discipline that gets you a
trustworthy fix anyway.

**(a) Separate the mechanism from the trigger.** I couldn't trigger the *blank*,
but the blank is just "the viewport was computed for the wrong size and never
re-fit." That *consequence* is fully reproducible: force a wrong viewport, then
run the backstop, and assert it re-fits. If the mechanism is correct, the fix is
correct regardless of what pulls the trigger.

```
descend → window → clobber viewport to a degenerate zoom (simulate the blank)
run the backstop
assert: zoom went 20.6 → 0.7713 (refit to the real 1067-px width), pending → 0
```

**(b) Reproduce the *symptom class*, not the exact incident.** "Resize doesn't
re-fit" is the same *class* as the blank. I drove the harness to resize a
post-descend window and asserted the zoom adapts — and, separately, that a
*second* resize does **not** re-fit (so the fix doesn't introduce a new "window
keeps jumping" bug).

**(c) Replicate the known-good manual action.** The user proved that *resize* and
*F* fix it. My backstop calls the exact same underlying operation a resize does
(`resetwin` + the armed `zoom_full`). I am not hoping a novel code path works; I
am automating an action the user already confirmed works. That is a strong
correctness argument even with zero local reproductions.

**(d) Be honest in the writeup about what was and wasn't verified.** The issue
file says plainly: *"The exact WSLg blank can't be reproduced in batch... so the
backstop is verified against the consequence."* A fix you oversell is worse than
one you scope honestly, because the next person will trust it past its evidence.

> **Lesson 9 — "I can't reproduce it" is a starting condition, not a dead end.**
> Decompose the bug into *trigger* (environment-specific, maybe unreachable) and
> *mechanism* (logic you can isolate and test). Verify the mechanism
> deterministically; replicate any user-confirmed workaround; and document the
> gap between what you proved and what you inferred.

---

## Part 8 — Building a faithful harness (a comedy of five dead ends)

To test *any* of this I needed a GUI XSCHEM that (1) actually creates windows and
(2) lets me drive it step by step while the event loop runs. Getting there took
five wrong turns, each of which is a lesson about how programs are wired.

1. **`--script` alone exits before timers fire.** Batch mode runs the script and
   quits; my `after` callbacks never ran. *A script that only schedules work does
   nothing if the process exits before the scheduler runs.*

2. **No-flag launch *detaches* and redirects stdout to `/dev/null`.** Under a
   tool with no controlling tty, `main.c` decides it's a background process and
   silences output (and closes stdin). My logs vanished not because code didn't
   run but because *I was writing to a closed stream.* *Always check whether your
   harness even has a channel to speak on before concluding the code is silent.*

3. **`--pipe` keeps the interactive event loop alive.** The flag that fixed it
   tells XSCHEM "input is a pipe, stay interactive": it runs `Tk_Main`, processes
   the event loop, and reads commands from stdin. *Knowing the one flag that
   changes the run-loop is worth an hour of guessing.*

4. **`update idletasks` ≠ `update`.** Idle tasks flush Tk's geometry math but do
   **not** process X events like ConfigureNotify. To let real events flow between
   steps I had to `vwait` on a timer (`after $ms {set done 1}; vwait done`), which
   runs the *full* event loop. *Know exactly which "process events" primitive
   processes which events.*

5. **Relative paths silently loaded an *empty* buffer.** My fixtures are at the
   repo root; the working directory was `src/`. `xschem load relative/path.sch`
   found nothing, and instead of erroring it created a blank schematic *with that
   name* — so every early run showed "0 instances" and I chased a phantom. The
   real fixes: absolute paths, and set `XSCHEM_LIBRARY_PATH` to the library root
   so symbol references resolve. *A loader that "succeeds" on a missing file by
   inventing an empty one will waste an hour of your life; distrust a green that
   you didn't make turn red on purpose.*

> **Lesson 10 — Your test harness is itself software with bugs, and most "the
> code is broken" moments early in a hard debug are actually "the harness is
> lying."** Before you trust a measurement, prove the harness can *see* — make it
> report a value you can independently predict (a window size you set, a count you
> know), and only then trust the values you *can't* predict.

(See `green-but-hollow` in project memory: a green run is not evidence that the
changed code ran. Make it fail on purpose first.)

---

## Part 9 — The near-miss that would have shipped a regression

While adding the geometry-refresh command I wrote a new branch:

```c
if(!strcmp(argv[1], "resetwin")) { ... }   /* my new 2-arg fit form */
```

It built. It passed my tests. It was **wrong in two compounding ways**, and only
a habit of grepping saved it.

**(i) Commands dispatch by first letter.** The giant `xschem` command router is
split into per-initial functions and switched on `argv[1][0]`
(`src/scheduler.c:8689`): `xschem_cmds_a`, `..._r`, `..._z`, etc. I first added my
branch next to `zoom_full` — in `xschem_cmds_z`. But `resetwin` starts with `r`,
so the router calls `xschem_cmds_r` and **never reaches** the `_z` branch. The
command silently did nothing (no error — an unknown subcommand just falls
through). *I spent a while convinced `resetwin` "didn't fire pending" when in
fact it was never being called.*

**(ii) The command already existed.** Once I moved it to `xschem_cmds_r`, a grep
revealed an **existing** internal `resetwin create_pixmap clear_pixmap force w h`
command — and a caller, `xschem resetwin 1 1 1 0 0`, at `xschem.tcl:12133`. My new
`if` branch was placed *first* in the chain, so it **shadowed** the real one: my
2-arg parser would have read `resetwin 1 1 1 0 0` as "width=1, height=1" and
resized the window to 1×1. I would have fixed a blank-window bug by introducing a
*different* blank-window bug, in a code path my tests didn't cover.

The fix was to **merge**, not duplicate: extend the one existing `resetwin`
branch to also accept the 2-arg fit form.

> **Lesson 11 — Before adding a command/route/handler, grep for the name and
> confirm where its dispatcher sends it.** Two corollaries: (a) in any
> dispatch-by-key structure (first-letter, hash, URL prefix, opcode table),
> putting your case in the wrong bucket fails *silently*; (b) adding a branch
> that *shadows* an existing one is worse than a crash, because it "works" for
> your input and quietly corrupts someone else's. A 10-second grep beats a
> 2-week heisenbug.

---

## Part 10 — The transferable checklist

Strip away XSCHEM and here is what stays — a checklist for any UI, game, or
event-driven system:

1. **A draw depends on state that arrives via events.** Know which event
   supplies each input (size, DPI, theme, focus) and whether it has fired yet.
2. **Never assume an event will arrive.** Across remoting/throttling layers the
   first Configure/Expose/resize/visibility event is routinely dropped. Design
   for "it never comes."
3. **Prefer proactive convergence to event-waiting.** Arm the cheap event-driven
   path *and* schedule a bounded poll that does the work once the precondition is
   observably true, as a no-op if already done.
4. **The user's workaround names the missing event.** "Works after I
   resize/click/hover" → your code depends on that event and isn't getting it.
5. **Route truth through the authoritative layer.** When two subsystems disagree
   about a value during a transient (Tk vs X here), use the one that's correct
   for your purpose.
6. **Track shared flags to zero on every path**, especially paths where your
   happy-path event never fires.
7. **"Open again" re-reads storage; storage lags memory.** Watch for lost unsaved
   state on duplicate/preview/new-window/reload.
8. **Reuse existing serialization to move live state** instead of inventing a
   transfer path; degrade best-effort to the old behavior.
9. **Can't reproduce ≠ can't fix.** Split trigger from mechanism; verify the
   mechanism and the symptom-class; automate the user's known-good action;
   document the gap.
10. **Distrust the harness first.** Make it report a value you can predict before
    you believe the ones you can't; make a test fail on purpose before you trust
    its pass.
11. **Grep before you add.** Wrong dispatch bucket fails silently; a shadowing
    branch is worse than a crash.

The whole adventure changed four files by ~200 lines. The *code* was easy. The
*reasoning* — about time, events, environments you can't see, and how to earn
confidence without a reproduction — is the part that makes you an engineer. That
is why a "blank window" was worth a tutorial.

---

*Real symbols to read next, in source: `descend_schematic` and `zoom_full`
(`src/actions.c`), `resetwin` and `create_new_window` (`src/xinit.c`), the
`ConfigureNotify` case and the `pending_fullzoom` focus guard (`src/callback.c`),
the `resetwin` / `set,get pending_fullzoom` commands (`src/scheduler.c`,
`xschem_cmds_r` / `_g` / `_s`), and the four `newwin_*` helpers
(`src/xschem.tcl`). Issue write-ups: `doc/claude/issues/0037-newwin-descend-desync-and-exit-confusion.md`
§5 (blank window) and §6 (stale parent).*
