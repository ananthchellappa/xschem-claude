# Tabs *and* windows, and the long tail of making a dormant code path the default

*A lessons-learned write-up of one multi-session effort: give XSCHEM Chrome-style
behavior — real OS windows alongside tabs, plus tear-a-tab-into-its-own-window — and
then the string of editor-polish fixes that fell out of actually using it. The
headline lesson is not about windows. It is about what happens when a feature is
**already 90% built behind a single either/or flag**, and you flip the switch that
makes a rarely-exercised code path the default: every latent bug in that path wakes
up at once. Running examples are in `src/xinit.c`, `src/callback.c`,
`src/scheduler.c`, `src/actions.c`, and `src/cadence_style_rc`. Specs:
`doc/claude/specs/multi_window_detach.md`, `doc/claude/specs/descend_readonly.md`,
`doc/claude/specs/untitled_reuse.md`. Every lesson transfers to any app with two UI modes that
were never meant to run at the same time.*

---

## 0. The ask, and the surprise

The user wanted what every browser and editor has: **tabs AND windows**. Put one
schematic on monitor A, another on monitor B, but still keep a stack of tabs in each.
And — like NEdit — tear a tab off into its own window.

The surprise, found in the first hour: **XSCHEM already had all the hard parts.**
There were two complete implementations of "open another schematic," both built on
the same per-schematic `Xschem_ctx` and the same context-switching machinery:

| | **Tabbed** (`create_new_tab`, xinit.c) | **Windowed** (`create_new_window`, xinit.c) |
|---|---|---|
| Tk widget | a `.tabs.xN` button in the one shared tab bar | a real `toplevel .xN` (own menubar, canvas) |
| X11 window | **shares** the main canvas (`xctx->window = save_xctx[0]->window`) | its **own** id via `Tk_WindowId` |
| GCs / pixmap | reuses the main window's | its own, created against its own window |
| rendering | repaints the single `.drw` on tab switch | independent OS window, composited by X |

The schematic *data* — wires, instances, zoom, selection — is entirely
window-independent. The only thing separating a tab from a window is the **render
target**: which X window, which graphics contexts, which widget the events come from.

So why couldn't you have both? Because every dispatch keyed off **one global flag**,
`tabbed_interface`:

```c
/* xinit.c — new_schematic(), the single create/destroy/switch dispatcher */
if(!strcmp(what, "create")) {
  if(!tabbed_interface) create_new_window(...);   /* windowed mode */
  else                  create_new_tab(...);      /* tabbed mode   */
}
```

Tabs *or* windows, never both. And the moment you created a second context, the
"Tabbed interface" menu toggle was disabled — you were locked into whichever mode you
started in.

**Lesson 0.** Before building, find out how much already exists. A feature that looks
absent is often present but gated. The work then is not *construction* but
*decoupling* — and decoupling has a very different risk profile (you are touching
load-bearing code that already works, not adding to the edges).

---

## 1. The two atomic seams: a forcing verb and an introspection query

The whole feature pivots on two tiny additions made first, before any behavior
changed:

**A force-a-window verb.** `new_schematic` learned `create_window`, which calls
`create_new_window` *regardless* of `tabbed_interface`:

```c
} else if(!strcmp(what, "create_window")) {
  create_new_window(&window_count, win_path, fname, dr);  /* a real window, even in tabbed mode */
}
```

`load_new_window` gained a `-window` flag that routes through it, and the Library
Manager "New window" checkbox was pointed at `xschem load_new_window -window`.

**A read-only introspection query**, `xschem windows`, returning one row per open
context: `{win_path top_path group xwindow current_name}`. This is the unglamorous
hero of the whole effort. You cannot test "which schematic is in which window"
through pixels; you *can* assert on a list. Every headless test in
`tests/headless/test_multi_window.tcl` leans on it. The `group` field —
the owning toplevel (`.` for main, `.x1`, … for extras), derived from each context's
`top_path` — is what lets a test say "this one detached, that one didn't."

**Lesson 1.** When a behavior is GUI-only, the first thing to build is the *query*
that makes it observable to a script. The query is cheap, read-only, and it is what
turns "I eyeballed it" into a regression test that survives the next refactor.

---

## 2. The reorder: ship the headline, defer the cathedral

The original plan (`doc/claude/suggestions/plan_multi_window_detach.md`, RED-first) had a
Phase 1 — *per-window tab strips*: each window owns its own `.xN.tabs` bar so a
detached window can itself hold tabs. Full Chrome parity.

A probe of the live binary killed that ordering. The single `.tabs` strip is
hardcoded across `switch_tab`, `setup_tabbed_interface`, `swap_tabs`,
`tab_context_menu`, `next_tab`/`prev_tab` — all literal `.tabs`. Per-window strips
meant reworking all of them at once: large, and squarely in the hairiest GUI code.

But the headline feature — *tear a tab into its own window* — **does not need it.** A
detached tab can be a standalone single-schematic window, reusing the proven
`create_new_window` machinery. So the order flipped: **detach first, per-window tab
strips deferred** (and, honestly, probably never needed). The user signed off.

`detach_tab` re-homes an existing context onto a fresh toplevel without disturbing
the active tab — it operates on the detached context, then restores the active one:

```c
/* xinit.c — detach_tab(), abbreviated */
cur = xctx;                 /* remember the active context */
xctx = save_xctx[n];        /* operate on the tab being detached */
/* build the toplevel + widgets, get its X window id */
free_gc();                  /* old GCs were bound to the MAIN window */
xctx->window = win_id;      /* repoint to the new window */
my_strdup(_ALLOC_ID_, &xctx->top_path, toppath);   /* now its own group */
create_gc(); build_colors(0.0, 0.0); resetwin(1, 1, 1, 0, 0);  /* new GCs + pixmap */
/* drop the .tabs.xN button + tab_queue entry */
xctx = cur;                 /* restore the active context — main strip undisturbed */
```

The data never moves. Detach is a **render-target swap**: free the GCs bound to the
old window, repoint `xctx->window`, recreate the GCs and pixmap against the new one.

**Lesson 2.** Re-scope against the *actual* ask, not the tidy phase list. The probe
turned "Phase 1 then Phase 2" into "the small valuable half of Phase 2, and skip the
expensive half nobody asked for." A plan is a hypothesis; the codebase is the
referee.

---

## 3. The long tail: a dormant path becomes the default

Phase 0 made "New window" route through `create_new_window`. That path *existed* but
had been exercised by almost nobody (tabbed mode was the default for years). The
moment it became the common path, its latent bugs surfaced one user-session at a
time. This is the heart of the story.

### 3a. Dispatch by global flag → the zombie window

Close a real window while `tabbed_interface=1` and you got a dead window: visible,
stale content, no response. Root cause: closing dispatched on the *global* flag, so a
real window went to `destroy_tab`, which deletes the context, tries to remove a
`.tabs.xN` button that doesn't exist for a window, and **never destroys the
toplevel**.

The fix names the real distinction. Tabs and windows now coexist, so you cannot
decide by a global; you must decide by **what the target actually is**:

```c
/* xinit.c — a context owns its own top-level iff top_path is non-empty */
static int is_window_context(const char *win_path) {
  int n = get_tab_or_window_number(win_path);
  if(n <= 0) return 0;
  return (save_xctx[n] && save_xctx[n]->top_path && save_xctx[n]->top_path[0]) ? 1 : 0;
}
/* destroy: a real window ALWAYS uses destroy_window (which destroys the toplevel) */
if(!tabbed_interface || is_window_context(win_path)) destroy_window(...);
else                                                 destroy_tab(...);
```

### 3b. The big one: input routed to the wrong window

Two real windows open; click, type, or zoom in window A and **window B reacts**.
Close B and input went to the *original* untitled window. The feature was unusable.

The smoking gun was in `callback.c`. *All* per-window context switching —
the code that makes `xctx` follow the focused window — lived inside one `if`:

```c
/* callback.c — handle_window_switching(), BEFORE */
if(!tabbed_interface) {
  if((event == FocusIn || event == Expose || event == EnterNotify) && ...) {
    /* ... switch xctx to the window the event came from ... */
  }
} else {
  /* if something needs to be done in tabbed interface do it here */   <-- EMPTY
}
```

In tabbed mode the `else` was empty — correct when tabs share one canvas and switch
via the tab bar. But with real windows in tabbed mode, `xctx` never followed focus, so
every event hit whatever context was last active. The fix gates on **what is
involved**, not the global mode, and routes real-window switches to `switch_window`:

```c
int win_is_real = (n > 0 && save_xctx[n] && save_xctx[n]->top_path && save_xctx[n]->top_path[0]);
int cur_is_real = (xctx->top_path && xctx->top_path[0]);
if(!tabbed_interface || win_is_real || cur_is_real) { /* ... the switch dance ... */ }
```

Crucially the blast radius is *exactly* the new mixed mode: pure-tabbed
(`win_is_real==0 && cur_is_real==0 && tabbed`) and pure-windowed (`!tabbed`) both keep
their old behavior bit-for-bit. The user-reported **crash** on CTRL-SHIFT-N
(`schematic_in_new_window`, which reads the selected instance from `xctx` then opens
it) was the same bug wearing a different mask: with input mis-routed, `xctx` was a
stale/foreign window at the moment of the read. Fix the routing, the crash's
precondition is gone.

### 3c. Focus the canvas, not the frame

Round two of testing: new windows opened **blank** (mouse-move revealed bits), and
**CTRL-W/CTRL-Q/`f` did nothing** while the mouse still worked. Two bugs, and the
second was *my own regression* from the previous round.

- **Blank:** `create_new_window` set a "full-zoom pending" flag and waited for an
  Expose to paint. WSLg drops that first Expose. Fix: paint explicitly (mirror
  `create_new_tab`'s `zoom_full`/`draw`).
- **Dead keys:** the previous round added `focus -force .x1` — the *toplevel frame*.
  But the `<KeyPress>` binding lives on the **canvas** `.x1.drw`. Focusing the frame
  starved the canvas of keystrokes; only mouse motion (which re-focuses the canvas via
  `<Motion>`) made keys work, which is why it looked intermittent. Fix: `focus -force`
  the **canvas**.

**Lesson 3.** When you promote a dormant code path to the default, budget for a
*sequence* of bug reports, not one. Each fix exposes the next layer (the focus fix
revealed the blank-draw timing; my own focus fix *was* a regression). And the unifying
move across 3a/3b/3c is identical: **a decision that used to be made by a global mode
flag must instead be made per-object** — by `top_path` (is this a window?), by which
widget the event hit (canvas vs frame). A global boolean that meant "the whole app is
in mode X" cannot survive the introduction of "both modes at once."

---

## 4. Two Tcl gotchas worth keeping

### 4a. The deferred `<<TreeviewSelect>>` clobber

CTRL-ALT-S (locate the selected instance in the Library Manager) selected only the
*library*, not library→cell→view. `libmgr::refresh_after` selected all three
synchronously and correctly — and then, the moment the event loop turned, the panes
collapsed to library-only. Reproduced exactly:

```
BEFORE update: cell=adc_bridge view=symbol
AFTER  update: cell=          view=
```

A programmatic `$tree selection set` **queues a `<<TreeviewSelect>>` virtual event**.
When it fired, the bound `on_lib` re-ran and `pane_clear`ed the Cell/View panes that
`refresh_after` had just filled. (`update idletasks` does *not* flush virtual events —
only full `update` does, which is reentrancy-risky mid-proc.) The deterministic fix is
a suppress flag, lowered via `after idle` so the queued events fire as no-ops
*before* the flag clears:

```tcl
proc libmgr::refresh_after {...} {
  set suppress_select 1
  after idle [list set libmgr::suppress_select 0]   ;# scheduled AFTER the queued <<TreeviewSelect>>
  ...
}
bind $tree <<TreeviewSelect>> {if {!$libmgr::suppress_select} libmgr::on_lib}
```

(There was a second, simpler bug stacked on top: `libmgr::locate` still ran *listbox*
API — `$lb get 0 end` — which errors on the `ttk::treeview` the library-git migration
introduced. Removed; `locate` now just delegates to `refresh_after`.)

### 4b. The shifted-digit keysym

CTRL-2 (Make Editable) worked; CTRL-SHIFT-2 (Make Read Only) never fired — yet typing
`cadence::make_readonly` in the CIW worked. So the *proc* was fine and the *binding*
was dead. The cause is a classic Tk trap: with **Shift** held, the number-row `2` key
emits its **shifted keysym** — on a US layout `@` (keysym `at`), not `2`. So
`<Control-Shift-Key-2>` can never match. Bind the keysym the key actually emits:

```tcl
bind .drw <Control-Key-at>      {cadence::make_readonly; break}  ;# Ctrl-Shift-2 on US
bind .drw <Control-Shift-Key-2> {cadence::make_readonly; break}  ;# layouts where Shift-2 stays "2"
```

This is why `Control-Shift-Key-N` (the other cadence chord) works and the digit one
doesn't: **letters** give keysym `N` under Shift; only shifted **digits/symbols** bite.

**Lesson 4.** Two recurring Tk hazards: (1) programmatic selection generates the same
virtual events as a human click — your "set it up" code re-triggers the "user changed
it" handler, on the next idle, after you thought you were done; and (2) modified
number/symbol keys are not the unmodified keysym. Both are invisible until the event
loop runs, which is exactly when your headless test that didn't call `update` passes
and the real session fails.

---

## 5. Editor polish: chokepoints and auto-restore

Two requests near the end were small but instructive because each had a *single right
place* to hook.

**Descend opens read-only by default** (Cadence browse mode). Every descend path —
double-click, Ctrl-X, context menu, the `xschem descend` command — funnels through
**one** function, `descend_schematic`. So the hook is one place, gated by a flag
(default off, unchanged behavior):

```c
/* actions.c — descend_schematic(), after the child loads */
if(descend_ok && tclgetboolvar("descend_readonly")) {
  xctx->readonly = 1;
  set_modify(-1);   /* refresh the title's read-only marker */
}
```

The elegant part is what we *didn't* write. `readonly` is a single window-context
field, not per-hierarchy-level — so "descend read-only, ascend back to an editable
parent" looks like it needs per-level bookkeeping. It doesn't: `go_back` already
reloads the parent via `load_schematic`, which sets `readonly` from the parent's own
file writability. Forcing read-only *only on descend* gives the whole behavior for
free.

**Reuse the launch `untitled` buffer.** Editors don't leave an orphaned "Untitled"
beside the file you opened — the first open consumes the placeholder. The hook is
`load_new_window`, guarded by a predicate:

```c
static int is_pristine_untitled(void) {  /* top level, !modified, empty, untitled name */
  if(xctx->currsch != 0 || xctx->modified) return 0;
  if(xctx->instances != 0 || xctx->wires != 0) return 0;
  return (xctx->sch[xctx->currsch][0] == '\0' || strstr(xctx->sch[xctx->currsch], "untitled"));
}
/* in load_new_window: */
if(is_pristine_untitled()) tclvareval("xschem load {", f, "}", NULL);   /* reuse in place */
else                       new_schematic(force_window ? "create_window" : "create", ...);
```

`!modified` is doing quiet, important work: a scratch buffer you *drew in* is modified,
so it is **not** clobbered — your work survives and the open goes to a new window.

And the inevitable follow-up bug: after reusing the buffer to view a read-only file
and then closing it, the fall-back `untitled` came up *read-only* — the
window-context `readonly` flag lingered. A blank scratch has no file to protect, so
`clear_schematic` now resets it:

```c
set_modify(0);
xctx->readonly = 0;   /* a fresh blank untitled is always editable */
```

**Lesson 5.** Find the funnel. Both features had a single C function every path flows
through (`descend_schematic`, `clear_schematic`) — hook there and you cover
double-click, key, menu, and command in one edit. And before adding state, check
whether existing reload paths already re-derive it (the `go_back` → `load_schematic`
→ writability chain meant "ascend restores editability" needed *zero* new code).

---

## 6. Testing a windowed feature headless

Almost none of this is unit-testable in the classic sense; it is window-manager and
event-loop behavior. What made it testable anyway:

- **The `xschem windows` query** (§1) — every multi-window assertion is a list
  comparison, not a screenshot.
- **Drive the C callback directly.** Context-switch routing (§3b) is verified by
  `xschem callback .x1.drw 9 ...` (event type 9 = `FocusIn`) and then checking
  `current_win_path` followed — no real keyboard needed.
- **End-to-end key delivery** is checked with `event generate .x1.drw
  <Control-KeyPress-w>` and asserting the window closed — proving the keystroke
  reached the canvas binding and the close path ran.
- **Sabotage every green.** Each fix was confirmed by reverting it and watching the
  specific check go red (MW5 for detach, MWs for routing, DRO2 for read-only descend,
  UR2 for untitled reuse, LM-LOC2 for the treeview clobber). A green suite proves
  nothing until you've seen it fail without the fix — see
  `doc/claude/suggestions/green_but_hollow_tests.md`.

And three test-setup traps that cost real time, recorded so they don't again:

1. **`info script` ≠ repo root.** An ad-hoc probe in `/tmp` computed
   `repo = [file join [file dirname [info script]] .. ..]` → `/`, so every `xschem
   load` silently failed and "instances=0" looked like a query bug. It wasn't; the
   file never loaded.
2. **`XSCHEM_LIBRARY_PATH` must be set (Tcl `set`, no `::` prefix) before load**, or a
   descend can't resolve the child symbol and `xschem descend` silently returns 0. The
   `::`-prefixed write also trips a buggy `file_chooser` variable-trace — use the
   plain global, or an env var.
3. **`new_schematic destroy_all {}` ≠ reset to untitled.** It closes *extra* windows;
   the main window keeps its content. To get a fresh pristine untitled mid-test, use
   `xschem clear force` (= `clear_schematic(0,0)`, the same path the exit handler uses
   for a blank schematic).

Some things stay manual on purpose: WM focus/raise arbitration across monitors,
geometry of a torn-off window, the right-click "Descend (edit)" popup. Under WSLg/Xvfb
a scripted toplevel is auto-mapped and auto-focused regardless of the code, so an
assertion there cannot tell the bug from the fix (see
`gui_focus_and_testability_lessons.md`). Say so in the test and move the check to a
human's eyes.

**Lesson 6.** "Hard to test" usually means "no observation seam yet," not "untestable."
Build the seam (a query, a direct callback entry, a synthesizable event), sabotage to
prove the seam discriminates, and write down the environment-specific traps — they
are not one-offs, they are the local physics.

---

## 7. The shape of the whole thing

Nine commits, but one spine. The feature was *latent*: two render targets behind one
either/or flag. Unlocking it was four moves —

1. **Decouple** the per-open choice from the global mode (a forcing verb).
2. **Observe** it (the `xschem windows` query).
3. **Re-home** a context between render targets (detach = swap GCs/window/pixmap).
4. **Re-decide, per object, every place that used to decide by the global flag** —
   destroy (3a), context-switch (3b), focus target (3c).

— and the rest was the long tail of a default-switched code path (blank draw, keysym,
treeview clobber) plus two single-funnel polish features (descend read-only, untitled
reuse). The recurring failure mode, stated once: **a boolean that means "the app is in
mode X" is a time bomb the day you allow "both modes at once."** Every serious bug in
this effort was that bomb going off in a different function, and every fix replaced the
global question with a local one — *what is this particular object?*

That generalizes well past XSCHEM. Any system with a global mode switch — read/write,
online/offline, simple/advanced — is one feature request ("can I have both?") away
from needing the same surgery: push the decision down from the mode to the object.
