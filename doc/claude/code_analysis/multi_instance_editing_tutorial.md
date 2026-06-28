# Building multi-instance property editing: a coding tutorial

*How we turned XSCHEM's "Edit Properties" dialog into a Cadence-grade
multi-instance editor — and what each step teaches about layering, refactoring,
stable identity, reactive UI, and writing tests that don't lie.*

This is the **analysis-and-teaching** companion to the how-to-use manual
(`doc/multi_instance_property_editing.md`) and the design spec
(`doc/claude/specs/multi_instance_property_editing.md`). It walks the *engineering* of the
feature end to end across three shippable phases, with the real code, the two
real bugs we hit, and the testing discipline that caught them. Scattered
throughout are **▶ Level up** sidebars connecting the concrete xschem code to the
general computer-science idea underneath, so you can carry the lesson elsewhere.

All line references were read from the source on the `slick-property-forms`
branch and are reproducible. The feature is split across one C file
(`src/editprop.c`), one dispatcher (`src/scheduler.c`), one header
(`src/xschem.h`) and one Tcl GUI file (`src/property_form.tcl`), with tests in
`tests/property_form/body.tcl`.

---

## Part 0 — The job, in one paragraph

You select five resistors, open **Edit Properties**, change the value to `2k`,
and click OK. What should happen? In the *old* xschem the answer was a surprise:
it silently edited **all five** (forcing a hidden "preserve unchanged" mode), with
no UI telling you so, no way to choose otherwise, and no way to walk the set.
Cadence's editor does this properly — an **"Apply to"** scope (Only Current /
All Selected / All), **Next/Prev** through the selection, an **Apply** button
that edits without closing, and a **warning** when one value would overwrite
several different ones. Our job: build that, in three phases, without rewriting
the editing engine — because the engine already exists.

That last clause is the whole story. **Most of this feature is a UI and
scope-selection layer over machinery that already did the hard part.** Knowing
*what not to build* is a senior skill; let's see how it played out.

---

## Part 1 — Read before you write: the engine that already existed

Before touching anything, we traced the existing edit path. Two functions matter.

**`set_different_token`** (`token.c:207`) is the changed-fields-only primitive:

```c
/* token.c:207 */
int set_different_token(char **s, const char *new, const char *old);
/* "modify only the token values that differ between new and old" */
```

Given an instance's property string `*s`, a `new` string, and the `old` baseline,
it copies into `*s` only the tokens that changed between `old` and `new` — leaving
every other token of `*s` untouched. That is *exactly* "apply just the fields the
user edited, keep each instance's own rest."

**`update_symbol`** (then at `editprop.c:834`) was the apply loop. It walked the
selection and, for each selected instance, called `set_different_token(&inst.prop,
new_prop, old_prop)` where `old_prop` was the **displayed** instance's original
string. So the behavior "apply my edits to N instances, each keeping its own other
attributes" was *already implemented and battle-tested*. It just had no UI and a
bad default.

> **▶ Level up — Spike before you build.** The single most valuable hour on this
> feature was spent reading, not typing. The design spec opens with a verified
> "what happens today" section (line numbers and all) precisely because the
> cheapest version of a feature is the one where you discover the engine is
> already there. Before estimating a task, find the code that already does 80% of
> it. The estimate changes by an order of magnitude.

---

## Part 2 — The architecture seam: C engine ↔ Tcl form

XSCHEM is a C drawing engine with a Tcl/Tk GUI. The property dialog lives on a
deliberately thin **contract** between them, and understanding it is the key to
everything that follows.

The C function `edit_symbol_property` (`editprop.c:1061`) sets a few Tcl
variables, calls one Tcl command, and reads the result back:

```
C side                                   Tcl side
------                                   --------
tctx::retval = displayed instance prop
symbol       = displayed instance symbol
   │
   └─ tcleval("edit_prop {...}")  ──────► slickprop::edit_form  (the modal dialog)
                                              user edits, clicks OK/Cancel
   ◄──────────────────────────────────────  sets tctx::retval, tctx::rcode
read tctx::applied / update state
```

The genius of the original "slick form" (v1, a prior project) was that it
reskinned the dialog *entirely in Tcl* with **zero C changes**, by honoring this
same variable contract. We inherit that seam and extend it.

> **▶ Level up — A contract is an API even when it's just shared variables.**
> `tctx::retval`, `symbol`, `tctx::rcode` form an interface between two languages.
> Because it was a stable, documented contract, the GUI could be rebuilt three
> times without the C engine noticing. When you draw a boundary, write down what
> crosses it; that written-down thing is what lets the two sides evolve
> independently. This is the same reason microservices publish schemas.

---

## Part 3 — P1: fix the default, add the scope (policy vs. mechanism)

P1 had three jobs: stop force-editing-all, add a sticky "Apply to" scope, and
grey the `name` field when the scope spans many instances.

### 3.1 Deleting the bad default

The old code, in `edit_property` (`editprop.c:1231`), forced a hidden mode:

```c
/* DELETED: the surprising default */
if(xctx->lastsel > 1) {
  tclsetvar("preserve_unchanged_attrs", "1");   /* silently edit them all */
}
```

We removed it. Selecting N no longer *implies* editing N.

### 3.2 The scope becomes the only authority

Inside the apply loop we made changed-fields-only **unconditional** for instances
and built the target list from a single sticky variable:

```c
/* editprop.c — apply_symbol_prop() */
int only_different = 1;   /* changed-fields-only is now the contract, not a mode */
...
targets = my_malloc(_ALLOC_ID_, (xctx->instances + 1) * sizeof(int));
if(!strcmp(scope, "all")) {
  int master = xctx->inst[displayed_inst].ptr;     /* captured BEFORE the loop */
  for(i = 0; i < xctx->instances; ++i)
    if(xctx->inst[i].ptr == master) targets[ntargets++] = i;
} else if(!strcmp(scope, "selected")) {
  for(k = 0; k < xctx->lastsel; ++k)
    if(xctx->sel_array[k].type == ELEMENT) targets[ntargets++] = xctx->sel_array[k].n;
} else { /* current */
  targets[ntargets++] = displayed_inst;
}
```

The loop then iterates `targets[]` instead of the selection directly. Three
scopes, one loop.

> **▶ Level up — Separate policy from mechanism.** The *mechanism* (apply the
> changed tokens to a list of instances) never changed. What we added is *policy*
> (which instances make the list). Keeping them apart meant the dangerous part —
> the token surgery — was reused verbatim, and the new part was a tiny, readable
> switch. When you find yourself adding an `if` deep inside a workhorse function,
> ask whether the decision belongs *outside* it, computed once, passed in.

> **▶ Level up — Equivalence classes, again.** "All instances of the same master"
> is `{ i : inst[i].ptr == inst[displayed].ptr }` — an equivalence class keyed by
> the symbol pointer. Note we snapshot `master` into a local *before* the loop,
> because the loop can reassign `inst[].ptr` when a symbol changes. Reading a
> mutable key inside the loop that mutates it is a classic iterator-invalidation
> bug; capturing the key first is the fix.

### 3.3 The Tcl side: a sticky dropdown and a write-trace

The scope lives in one global, `::slickprop_apply_scope`, initialized *only if
unset* so it survives across dialog opens (stickiness):

```tcl
if {![info exists ::slickprop_apply_scope]} { set ::slickprop_apply_scope current }
```

A readonly `ttk::combobox` shows friendly labels; helpers map label↔value
(`scope_label`/`scope_value`, `property_form.tcl:355`/`363`). And the `name`
field greys out under a multi scope, wired through a **variable write trace**:

```tcl
trace add variable ::slickprop_apply_scope write slickprop::apply_scope_greying
```

`apply_scope_greying` (`property_form.tcl:375`) disables the name entry under
selected/all (a name must stay unique, so it can't be fanned out) and re-enables
it under current. Because it's a *trace*, changing the dropdown updates the
greying with no explicit "on change" plumbing.

> **▶ Level up — Greying is a correctness guard, not just polish.** A disabled
> entry's value never differs from what it loaded, so the "only changed fields"
> collector naturally excludes it — each instance keeps its own name *for free*.
> Good UI constraints often double as data-integrity constraints. Make the wrong
> thing impossible to express, and you delete a whole class of bugs downstream.

---

## Part 4 — P2: refactor to a reusable apply, then add a mid-session command

P1 applied *after* the dialog closed. P2 needs **Apply** (apply and stay open) and
**Next/Prev** (re-display a different instance), which means applying *while the
dialog is open*, possibly many times, each to the *currently displayed* instance.

### 4.1 The refactor: extract a pure-ish core

The old `update_symbol` did everything: build `new_prop` from Tcl vars, decide the
scope, loop, redraw. We split it into a reusable core and two thin callers:

```c
/* editprop.c:843 — the shared fan-out: takes everything as parameters */
static int apply_symbol_prop(const char *new_prop, const char *old_prop,
                             int displayed_inst, const char *scope);

/* editprop.c:1031 — the post-close path (vim/legacy editor) */
static int update_symbol(const char *result, int x, int selected_inst) {
  ...
  modified = apply_symbol_prop(new_prop, xctx->old_prop, selected_inst, "selected");
  ...
}

/* editprop.c:1017 — the NEW mid-session path */
int apply_instance_properties(const char *scope, unsigned int displayed_id,
                              const char *new_prop, const char *old_prop) {
  int idx = inst_index_from_id(displayed_id);   /* resolve a STABLE id */
  if(idx < 0) return 0;
  int modified = apply_symbol_prop(new_prop, old_prop, idx, scope);
  if(modified) set_modify(1);
  return modified;
}
```

The crucial change: `apply_symbol_prop` takes `old_prop` as a **parameter**
instead of reaching for the global `xctx->old_prop`. That one substitution is what
turns a close-coupled procedure into something callable repeatedly with different
arguments.

> **▶ Level up — Refactor first, then add the feature.** We did *not* bolt the
> Apply button onto the old function. We first restructured to a function that
> *could* support it (parameters instead of globals), verified the old behavior
> still passed every test, *then* added the new caller. This is the "make the
> change easy, then make the easy change" rule (Kent Beck). Mixing a refactor and
> a feature in one step is how you end up unable to tell which one broke the test.

### 4.2 Referring to an instance that might move: stable ids

Between two Applies, the instance array can be re-sorted or compacted. An array
*index* is not a safe handle across edits. XSCHEM already has a
**session-stable id** stamped on every instance, with resolvers
`inst_index_from_id` (C) and `xschem instance_index <id>` (Tcl). The mid-session
command takes the displayed instance **by id**:

```
xschem apply_properties <scope> <displayed_id> <new_prop> <old_prop>
```

The form passes `nav(disp_id)` (a stable id); C resolves it to a live index at the
moment of apply.

> **▶ Level up — Identity vs. address.** An index is an *address* (where the thing
> is right now); an id is an *identity* (which thing it is, wherever it ends up).
> Cross a time boundary — a later apply, an undo, a re-sort — and you must hold
> identity, not address. Pointers, array indices, and memory offsets are all
> addresses; database primary keys and these session ids are identities. (There's
> a whole sibling tutorial on this: `identity_vs_address_tutorial.md`.)

### 4.3 Who applies now? Bypassing the post-close path

For the slick form (`x==0`), `edit_symbol_property` no longer calls
`update_symbol` at all. Instead it hands the form the displayed id and the
selected set, runs the modal, and reads back a flag:

```c
/* editprop.c:1086 */
tclsetvar("tctx::edit_inst_id", idbuf);     /* the displayed instance's stable id */
tclsetvar("tctx::edit_sel_ids", sel_ids);   /* space-joined ids of the selection  */
tclsetvar("tctx::applied", "0");
tcleval("edit_prop {Input property:}");      /* the form applies via the command   */
modified = tclgetboolvar("tctx::applied");   /* did anything change?                */
```

The Tcl `do_apply` (`property_form.tcl:283`) is the single apply path for both
Apply and OK: it sets the symbol/copy-cell state, populates `tctx::retval` (still
honoring the legacy contract), then calls `xschem apply_properties` and flips
`tctx::applied`. `apply_now` = `do_apply` + reload the displayed baseline (stay
open); `ok` = `do_apply` + close; `cancel` applies nothing.

> **▶ Level up — One write path.** Apply and OK do not duplicate the apply logic;
> OK is "apply, then close." Two buttons, one code path. Every time you have "do
> X" and "do X and also Y," make Y wrap X — never copy X. Duplicated side-effect
> code drifts, and the drift is always discovered in production.

### 4.4 Navigation state vs. rebuild-wiped state

Next/Prev rebuilds the field grid for a new instance. The rebuild
(`build_fields`) starts with `array unset cur` — it wipes the per-field state.
So the **navigation** state (which instances, current position, displayed id)
*cannot* live in `cur`, or it'd be erased on every step. It lives in a separate
array, `slickprop::nav`:

```tcl
# nav(ids)     the selected instances, by stable id
# nav(pos)     the displayed index into nav(ids)
# nav(disp_id) the displayed instance's id
```

`load_pos` (`property_form.tcl:489`) fetches an instance's props + symbol by id
and rebuilds the grid (which *discards* any pending edits — that's the
"navigating away drops unapplied edits" rule, for free). `nav` ±1 with
end-clamping; `update_nav_ui` shows "k of N" and greys Prev/Next at the ends.

> **▶ Level up — State ownership and lifetime.** Two pieces of state here have
> *different lifetimes*: field widgets live for one displayed instance; the nav
> set lives for the whole dialog session. Storing them together meant the
> shorter-lived reset destroyed the longer-lived data. When state churns at
> different rates, give each rate its own home. (This is also why React separates
> `useState` from `useRef`, and why CPUs have registers *and* RAM.)

---

## Part 5 — P3: the "values differ" warning (derived, reactive state)

P3 is pure Tcl, no C change. Under a multi scope, if the **focused** field's value
isn't the same across the in-scope instances, the footer turns red — applying one
value would overwrite several. The whole feature is four small procs
(`property_form.tcl:396`–`487`):

```tcl
proc slickprop::scope_instances {}     ;# the instance indices in scope right now
proc slickprop::field_varies {tok insts}  ;# 1 if tok's value isn't uniform across them
proc slickprop::on_focus {tok}         ;# record the focused field, refresh warning
proc slickprop::update_warning {}      ;# set red footer text, or restore the hint
```

`field_varies` is the heart, and it's a textbook "all-equal" fold:

```tcl
proc slickprop::field_varies {tok insts} {
  set first {}; set got 0
  foreach i $insts {
    set v [xschem get_tok [xschem getprop instance $i] $tok 2]
    if {!$got} { set first $v; set got 1 } elseif {$v ne $first} { return 1 }
  }
  return 0
}
```

The warning is **derived state**: it is never stored, only *computed* from (focused
field, scope, instance values) whenever any of those change. We wired the
recomputation to fire from three triggers: the focus handler, the scope
write-trace (reused from P1 — changing the dropdown re-evaluates the warning for
free), and the end of `load_pos` (Next/Prev).

> **▶ Level up — Derive, don't store.** A bug-magnet pattern is caching a derived
> fact (here, "does this field vary?") and forgetting to update the cache when an
> input changes. By recomputing on demand from the source of truth, the warning
> *cannot* go stale. Cheap to compute → don't cache it. This is the same instinct
> behind pure render functions and spreadsheet formulas.

> **▶ Level up — The observer pattern, the lightweight way.** We didn't build an
> event bus. Tcl's `trace add variable` *is* the observer pattern: write to
> `::slickprop_apply_scope` and the greying + warning handlers fire. Many
> languages give you this (property observers, signals, reactive streams). Reach
> for the built-in before you invent a notification system.

---

## Part 6 — Two real bugs, and why the tests found them

Green tests that never ran the new code are worthless. We committed every test
**RED first**, watched it fail for the right reason, then made it pass — and
afterwards **sabotaged** the new code to confirm the right tests turned red. That
discipline surfaced two genuine bugs.

### Bug 1 — the widget-name collision

The original `build_fields` was only ever called *once* per dialog. P2's Next/Prev
and Apply call it *repeatedly* into the same parent frame. The second call tried
to create a widget named `.i0` that already existed:

```
window name "i0" already exists in parent
```

Fix (`property_form.tcl`, top of `build_fields`):

```tcl
foreach w [winfo children $parent] { destroy $w }
```

> **▶ Level up — An assumption is a landmine with a delay.** "This is only called
> once" was *true* when the code was written and silently *false* the moment we
> reused it. The function never documented or enforced the assumption. When you
> rely on a precondition, assert it or make the code robust to its absence —
> because the caller who violates it will be you, six months later.

### Bug 2 — stale timers, a heisenbug

The test harness drives the modal dialog with `after` timers (the dialog blocks,
so a timer fires the "edit + click OK" script). Early versions scheduled a 6-second
**safety cancel** and never cancelled it when the test finished early. Those
orphaned timers piled up and fired *during a later test*, cancelling its dialog
mid-action — producing 3–4 failures that moved around between runs.

Two fixes, both worth internalizing:

1. **Cancel what you schedule.** `pf_form_run` now saves the `after` ids and
   `after cancel`s them on return.
2. **Poll, don't guess.** A fixed `after 400` raced the dialog's build time under
   WSLg (sometimes the form wasn't ready at 400 ms). We replaced it with a poller
   (`pf_tick`, every 40 ms until the form exists) plus a hard safety ceiling.

```tcl
proc pf_tick {} {
  if {$::pf_done} return
  if {[winfo exists .dialog] && [info exists slickprop::cur(tokens)]} {
    set ::pf_ran 1
    if {[catch {uplevel #0 $::pf_body} m]} { set ::pf_err $m }
    catch {if {[winfo exists .dialog]} {slickprop::cancel}}
    return
  }
  incr ::pf_ticks
  if {$::pf_ticks > 150} { catch {if {[winfo exists .dialog]} {slickprop::cancel}}; return }
  after 40 pf_tick
}
```

> **▶ Level up — A flaky test is a race condition you wrote.** Nondeterministic
> failures are never "just the environment"; they are real concurrency bugs in the
> test (or the code). Two root causes recur: (a) *unbounded waits with fixed
> timeouts* — replace "wait 400 ms and hope" with "wait until the condition holds,
> with a ceiling"; (b) *un-scoped global resources* — a timer, a temp file, a
> socket created in one test and not torn down leaks into the next. Make each test
> own and release everything it touches.

### A third gotcha — read the exit code, not the stale log

At one point the suite "failed" identically across runs, *after* a fix that should
have worked. The cause: a `git commit` had `cd`'d the shell to the repo root, so a
later bare `./xschem` (the binary lives in `src/`) silently didn't run — exit code
**127**, "command not found" — and we were re-reading a **stale** `/tmp` log from
the previous run. Lesson: when a result looks impossible, check the *plumbing*
(did the command run at all? what was the exit code?) before re-debugging the
*logic*.

---

## Part 7 — The shape of the whole change

```
doc/claude/specs/multi_instance_property_editing.md   the design + ratified decisions
        │
        ├─ P1  editprop.c     remove forced default; apply_symbol_prop scope switch
        │      property_form.tcl  sticky scope combobox + name greying (write-trace)
        │
        ├─ P2  editprop.c     refactor update_symbol → apply_symbol_prop (params)
        │      editprop.c     apply_instance_properties (by stable id)
        │      scheduler.c    xschem apply_properties command (xschem_cmds_a)
        │      property_form.tcl  do_apply / apply_now / nav / load_pos
        │
        ├─ P3  property_form.tcl  scope_instances / field_varies / on_focus / update_warning
        │
        └─ +   scheduler.c    `xschem edit_prop [scope]` optional arg (see Part 7½)
```

Notice the gradient: **P1 touched C and Tcl, P2 was mostly C plumbing for a new
command, P3 was pure Tcl.** As the engine grew the right seams (a scope-aware
apply, a stable-id command), each later phase needed less and less of the
expensive layer. That is what good incremental design feels like — the
*marginal* cost of each feature falls because the earlier work left the right
hooks.

> **▶ Level up — Shippable slices beat a big bang.** Each phase was independently
> releasable and independently tested (60 → 77 → 85 → 91 checks, the last bump
> being the Part 7½ coda). If we'd stopped after P1, the surprising-default bug
> was already fixed and the product was better. Cut features along seams where
> each slice stands alone; never along seams where nothing works until the last
> commit lands.

---

## Part 7½ — A coda: extending the command surface

After the three phases shipped, a user asked for a small thing: a way to open the
dialog *already set* to a scope, so they could bind one key to "edit just this
one" and another to "edit the whole selection." The entire change was eight lines
in the `edit_prop` dispatcher (`scheduler.c`):

```c
/* xschem edit_prop [current|selected|all] */
else if(!strcmp(argv[1], "edit_prop")) {
  if(!xctx) { Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR; }
  if(argc > 2) {
    if(strcmp(argv[2],"current") && strcmp(argv[2],"selected") && strcmp(argv[2],"all")) {
      Tcl_SetResult(interp, "xschem edit_prop: scope must be current|selected|all", TCL_STATIC);
      return TCL_ERROR;                       /* fail fast: reject, don't open */
    }
    tclsetvar("slickprop_apply_scope", argv[2]);   /* reuse the sticky var */
  }
  edit_property(0);
  Tcl_ResetResult(interp);
}
```

Three things make this small change a good one, and each is a transferable habit:

1. **It reused the existing state, not a new path.** The scope already lived in
   one sticky variable that the form reads. The arg just *writes* that variable
   before opening — no new flag, no second way for the form to learn the scope.
   The form didn't change at all.
2. **It fails fast and loudly.** An unknown scope returns a Tcl error *before*
   opening the dialog, rather than silently defaulting. A bad keybinding tells you
   so immediately instead of quietly doing the wrong thing.
3. **It's backward compatible.** With no argument the command behaves exactly as
   before, so every existing caller and the menu are untouched.

> **▶ Level up — A good command is a thin, total function over existing state.**
> The new arg added *zero* new capability to the engine — the form could already
> open in any scope. It only gave that capability a convenient *name at the call
> site* (`edit_prop selected`). The best command-line/API additions are often
> exactly this: a thin, validated wrapper that makes an already-possible thing
> ergonomic. Before adding state or a code path, check whether you can instead
> expose what's already there. And make the function *total*: define what happens
> for every input, including the bad ones (here, reject them) — a function that's
> undefined on some inputs is a bug waiting for a user to find it.

> **▶ Level up — Design for the bind point.** The feature was driven by *how it
> would be invoked* — a keystroke that needs no follow-up interaction. That's why
> the scope is an argument (one atomic command) rather than, say, a mode you'd
> have to set and then trigger separately. When you expose an operation, picture
> the caller: a script, a keybinding, a pipe. The shape that's awkward to call is
> the wrong shape, however clean it looks from the inside.

---

## Part 7¾ — The scope highlight: a redraw-persistent overlay from one source of truth

The last backlogged piece (phase H1) draws a **white outline** on the canvas
around exactly the objects an OK/Apply will write to, updated live as you change
scope or step Next/Prev. Three design choices carry it, and each is a transferable
habit.

**1 — Persist by re-rendering, not by remembering pixels.** XSCHEM's selection
highlight isn't a sprite layered on top of a static image; it is *re-stroked at
the end of `draw()`*, after the canvas is rebuilt from its pixmap. The scope
outline simply joins that tail:

```c
draw_selection(xctx->gc[SELLAYER], 0);
draw_scope_highlight();   /* re-strokes the overlay every redraw */
```

Because the renderer runs on every `draw()`, the outline survives pan/zoom/any
redraw for free, and **clearing it is just `count = 0` then one more `draw()`** —
no XOR un-draw, no saved background to restore. The canvas rebuilds from the
pixmap (which never held the overlay), so it returns pixel-identical. When state
is cheap to recompute, *recomputing on every frame is simpler and more correct
than incrementally patching a cache.*

**2 — Outlined set == applied set, by construction.** The cardinal rule is "if
the user sees N outlines, OK writes exactly those N." The way to guarantee that
is not to compute the set carefully in two places — it is to compute it in
**one** place and call it from both:

```c
int scope_targets(int displayed_inst, const char *scope, int *targets); /* the helper */
```

`apply_symbol_prop()` (the write) and `xschem highlight_scope` (the outline) both
go through it. They *cannot* disagree, because there is only one computation. The
sabotage test proves the seam is real: freezing `scope_targets`'s `current` case
to "instance 0" reddened both the highlight follow-test **and** the apply tests —
one wrong line, caught on both sides.

> **▶ Level up — "Two things must agree" is a smell; "two things share one
> source" is the fix.** Any time a spec says invariant X must hold between a
> display and an action, resist writing the logic twice and keeping them in sync.
> Extract the shared computation and let both consumers call it. The invariant
> then holds *by construction* rather than by vigilance — and a single test (or
> sabotage) exercises both consumers at once.

**3 — Hold the set by stable id, resolve at draw time.** The overlay stores
`{type, stable-id}`, not array indices. While the dialog is open the user can do
things that reindex the arrays; an index would dangle, but the id still resolves
(`inst_index_from_id`, `wire_index_from_id`, …) — or cleanly *fails* to resolve
(a deleted object is skipped, not mis-drawn). This is the same discipline the
stable-handles work established, now paying off in a feature that holds a
reference across redraws.

One C↔Tcl seam, kept thin: the form hands C a scope string and a stable id
(`slickprop::update_highlight` → `xschem highlight_scope <scope> <id>`); **C owns
all the drawing.** The form never computes geometry, never touches a GC. That is
the same engine/GUI split as the rest of the feature — the Tcl side decides
*what* and *when*, the C side decides *how to draw*.

> **▶ Level up — A general primitive, a specific consumer.** The renderer
> dispatches on object type (instance → bbox, wire → its line segment, …) even
> though this dialog only ever feeds it instances. Building the primitive general
> — and testing the dormant wire path directly via `xschem highlight_objects` —
> costs little and means the next consumer ("outline these search hits") needs no
> engine change. Generalize the *mechanism*; specialize the *caller*.

---

## Part 7⅞ — Making the form modeless: read the lock before you pick it

A user noticed the dialog blocked canvas selection (you could pan/zoom but not
click to select more). The instinct is "it's modal, make it modeless." But the
first move is always **find the actual mechanism**, and here it was a surprise:

- there was **no Tk `grab`** — that's why pan/zoom still worked;
- the form just did `xschem set semaphore +1`. XSCHEM's `xctx->semaphore` is a
  re-entrancy counter: idle is 0, `callback()` raises it to 1 per event, and the
  form's extra +1 pushed every event to **2**, tripping the `if(semaphore >= 2)`
  guards that short-circuit *gesture* handlers. Pan/zoom happen to run on code
  paths **before** that guard; selection runs after it. The asymmetry was never a
  decision — just where the lock sat relative to each operation.

> **▶ Level up — characterize the mechanism, not the symptom.** "It's modal" was
> wrong, and building on that wrong model (e.g. fiddling with `grab`) would have
> wasted the session. Ten minutes reading `callback.c` turned a vague "unblock
> the form" into a precise, small change: *let the selection-gesture sites run
> even at `semaphore >= 2` when our form holds the lock; leave every other guard
> alone.* The right fix was surgical because the diagnosis was exact.

Even better, the engine **already had a branch** for "Button1 clicked while a
property dialog is open" (`callback.c`, the legacy text dialogs used it). The new
behavior slotted into that existing seam rather than adding a parallel path —
extend the place that already exists before inventing a new one.

**The C↔Tcl seam.** Tk can't see a C-side `select_object()`, so C *tells* Tcl the
selection settled: `tcleval("slickprop::on_selection_changed")`. C owns the
event and the engine state; Tcl owns the form's reaction (rebuild the nav set,
re-load the displayed instance, refresh the highlight). One explicit
notification, gated on a "form open" flag so it costs nothing otherwise — far
cleaner than the form polling the canvas on a timer.

**One prompt, every exit.** Changing the selection and pressing Next/Prev are the
*same situation* — "you're leaving an instance that has unapplied edits." So they
route through **one** helper:

```tcl
proc slickprop::maybe_apply_then {action cancelaction} {
  if {![slickprop::is_dirty]} { uplevel #0 $action; return }
  switch -- [tk_messageBox -type yesnocancel -message "Apply your changes?"] {
    yes     { slickprop::do_apply; uplevel #0 $action }   ;# Apply, then go
    no      { uplevel #0 $action }                        ;# Discard, then go
    default { uplevel #0 $cancelaction }                  ;# Cancel: stay / restore
  }
}
```

Both `nav` and `on_selection_changed` call it with their own *action* (step / adopt
the new selection) and *cancel-action* (stay put / restore the previous
selection). This deliberately **superseded** the older "Next/Prev silently
discards" rule — and the test that encoded the old rule (PF28) was *updated*, not
worked around, because the behavior genuinely changed.

> **▶ Level up — collapse parallel flows into one decision point.** Two code paths
> that face the same question should ask it in the same place, or they *will*
> drift (one grows a confirmation, the other doesn't). Passing the
> situation-specific bits as `action` / `cancelaction` lets one helper serve both
> without a flag-laden mega-proc. And when a change supersedes old behavior, edit
> the test that asserted it — a test you route *around* is a test you've stopped
> trusting.

---

## Part 8 — Try it yourself (exercises)

1. **Add a per-field "varies" marker.** P3 implements the required red footer
   text but skips the optional muted `<*>` next to a varying field. The indicator
   column already exists (the dirty dot). Add the marker, RED-first.
2. **A fourth scope: "All in hierarchy."** `scope_instances` and
   `apply_symbol_prop`'s switch are the only two places that enumerate targets.
   What would "all instances of this master across the whole design hierarchy"
   need? (Hint: it crosses sheets — read `netlist.c`'s traversal first.)
3. **Make `field_varies` short-circuit cheaper.** It already returns on the first
   mismatch. Could you avoid re-fetching `getprop` for the displayed instance,
   which the form already has in `cur(orig)`?
4. **Break it on purpose.** Comment out the `after cancel` lines in `pf_form_run`
   and run the suite five times. Watch the failures wander. Now you've felt a race
   condition — fix it again and the lesson sticks.
5. **Extend the command surface (Part 7½ style).** Add an optional argument to
   another existing command that today reads a sticky/global setting — make the
   arg a thin, validated, backward-compatible wrapper that writes that setting,
   exactly like `edit_prop [scope]`. Reject bad inputs before doing any work.
   Then ask: did you add any new capability, or just a convenient name for one
   that already existed? (The best answer is usually the latter.)

---

*Reference manual: `doc/multi_instance_property_editing.md`. Design + decisions:
`doc/claude/specs/multi_instance_property_editing.md`. Sibling tutorials:
`identity_vs_address_tutorial.md` (stable handles),
`net_as_object_coding_tutorial.md` (derived data).*
