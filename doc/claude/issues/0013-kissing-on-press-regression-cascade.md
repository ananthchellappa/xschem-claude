# Issue 0013 — "wire-follow on drag" leaked into clicks: a three-stage regression cascade

**Opened:** 2026-06-19
**Status:** RESOLVED 2026-06-19 — feature shipped (Phase 3 of the wire-editing
plan) then hardened across two follow-up fixes after the user hit the fallout in
the GUI. Commits: `29e55f90` (feature), `b52c4648` (fix 1: no spurious wires /
stub on a click), `d296b673` (fix 2: keep a wired gate selected on a click).
**Affects:** interactive use with `src/cadence_style_rc` (`cadence_compat=1`,
`enable_stretch=1`, `orthogonal_wiring=1`, `intuitive_interface=1`). Also the
non-cadence intuitive stretch path when `enable_stretch` is on.
**Severity:** medium — the feature worked, but ordinary *clicks* (select an
instance) acquired side effects: a Shift+drag copy drew phantom wires, abutted
clicks left invisible zero-length wires, and clicking a wired gate deselected it.
**Branch:** `fluid-editing`. See [[wire-editing-on-move]], [[cadence-modifier-drag]].
**Related:** `doc/claude/code_analysis/wire_editing_spec_and_plan.md` (Phase 3), Issue 0011
(another cadence-mode release-path interaction), [[green-but-hollow]].

A tutorial follows in §8 — including the requested **"what to do proactively next
time"** in §8.6.

---

## 1. The feature that started it (Phase 3)

Phase 3 made attached wires *follow* a component when it is dragged in cadence
mode, including two harder cases:

- **T-junction / mid-span:** a wire that passes *through* a moved pin (not at an
  endpoint) stays connected by growing a stub.
- **Pin-to-pin abutment:** two pins placed directly coincident (no wire between
  them) stay connected by *generating* a wire when one moves.

Both already had a mechanism: `connect_by_kissing()` (`actions.c:1163`). It is a
sticky-flag operation — you set `xctx->connect_by_kissing = 2`, and the next
`move_objects(START)` (`move.c:1165`) or `copy_objects(START)` (`move.c:619`)
*consumes* the flag: it scans the moving selection's pins, and for each pin that
abuts another pin or touches a wire it inserts a **zero-length stub wire** at that
point (`storeobject(..., WIRE, 0, SELECTED1, ...)`). The subsequent move stretches
the stub into the real connecting segment.

The Phase 3 change (`29e55f90`) was tiny: in `handle_button_press`, set
`xctx->connect_by_kissing = 2` on the **plain drag** arms (the cadence plain arm
and the non-cadence plain-stretch arm), right next to the existing
`select_attached_nets()` call. On a drag, this is exactly right and the feature
worked, verified by `test_cadence_drag` Phase 6 and wireedit TC5/TC16.

> The trap is already visible in that sentence: the flag is armed **on press**,
> but "press" is not the same event as "drag." Every press is a *potential* drag —
> and also a potential *click*.

---

## 2. Regression A — Shift+drag copy drew phantom wires (the reported bug)

**User report:** with `cadence_compat`, a Shift+LMB-drag (the copy gesture) now
drew spurious connecting wires.

The Shift arm only calls `copy_objects(START)` — it never sets the kissing flag.
So for the copy to kiss, the flag had to be **2 on entry**, i.e. *leaked* from an
earlier gesture.

**Where it leaked:** the flag is reset to 0 at move/copy *END* unconditionally,
but on the *ABORT* path the reset was nested inside `if(xctx->kissing)`:

```c
if(xctx->kissing) {            /* only true if a kiss actually happened */
  pop_undo(0, 0);
  if(xctx->connect_by_kissing == 2) xctx->connect_by_kissing = 0;
}
```

A plain press that kissed **nothing** (`xctx->kissing == 0`) skipped the reset, so
the flag stayed at 2. The very next Shift+drag copy inherited it and kissed.

**Fix (`b52c4648`):** reset the flag unconditionally on ABORT, mirroring END:

```c
if(xctx->kissing) { pop_undo(0, 0); check_collapsing_objects(); }
if(xctx->connect_by_kissing == 2) xctx->connect_by_kissing = 0;   /* always */
```

Reproduced headlessly: a no-motion click on an isolated instance (kisses nothing →
leaks) followed by a Shift+drag copy of an abutted instance drew a wire — and was
green after the fix.

---

## 3. Regression B — abutted *clicks* left an invisible stub, and mis-fired deselect

While fixing A, a second manifestation surfaced. A no-motion **click** directly on
an abutted instance (just selecting it) created a permanent **zero-length wire**
`{x y x y}` at the abutment.

The mechanism is a chain reaction in the release handler:

1. The press kisses → a zero-length stub is inserted and **selected** (`SELECTED1`).
2. That stub bumps `xctx->lastsel` from 1 to 2.
3. The cadence "deselect everything but the item under the cursor" branch
   (`callback.c:5384`) is gated on `lastsel != 1`. The stub made that condition
   true for what was really a single-instance click, so it fired.
4. Its `unselect_all` perturbed the undo pointers, so when the move *did* finally
   abort, `pop_undo` no longer restored the pre-kiss state — the stub survived.

So one injected object (the stub) corrupted **two** downstream decisions: the
deselect test and the undo restore.

**Fix (`b52c4648`, same commit):** abort a no-motion plain intuitive move **before**
the cadence deselect test reads `lastsel`, and sweep any degenerate stub with the
existing cleanup (`check_collapsing_objects()`, predicate `wire_doomed_degenerate`,
`move.c:127`):

```c
/* before the cadence deselect-others branch */
if(intuitive && (ui_state & STARTMOVE) && drag_elements &&
   !mouse_moved && !(state & (ShiftMask|ControlMask))) {
  move_objects(ABORT, 0, 0.0, 0.0);
  drag_elements = 0;
}
```

Now the stub is gone and `lastsel` is back to 1 before the deselect branch, so it
correctly skips. Regression-guarded by `test_cadence_drag` Phase 7.

---

## 4. Regression C — clicking a *wired* gate deselected it (found by the user)

The user then noticed: clicking m2 in `nand2.sch` no longer left it selected.

The early-abort from fix B was the cause. `move_objects(ABORT)` runs `pop_undo`
**only when a kiss happened**, and `pop_undo` (`save.c:3844`) calls
`unselect_all(1)` internally (`save.c:3883`). So:

- A **bare** instance (kisses nothing) → no `pop_undo` → selection intact → fine.
- A **wired / abutting** gate (kisses) → `pop_undo` → `unselect_all` → selection
  wiped, and the downstream cadence reselect couldn't re-anchor (the object was no
  longer "already selected").

That asymmetry — bare instances fine, wired gates broken — was the tell.

**Fix (`d296b673`):** after the abort, re-select the object under the cursor *only
when the abort actually cleared the selection*, mirroring the intuitive-launcher
branch (`callback.c:5370`):

```c
move_objects(ABORT, 0, 0.0, 0.0);
drag_elements = 0;
if(xctx->lastsel == 0) {                 /* a kiss's pop_undo wiped selection */
  select_object(xctx->mousex, xctx->mousey, SELECTED, 0, NULL);
  rebuild_selected_array();
}
```

The `lastsel == 0` guard is load-bearing: it means "repair only when we broke it,"
preserving the no-kiss click and the multi-select-then-isolate behavior untouched.

---

## 5. Reproductions (all headless, via `xschem callback`)

Run from the **repo root** under X (the fixtures use the `res.sym`/`nand2.sch`
paths), `cadence_compat`/`enable_stretch`/`orthogonal_wiring`/`intuitive_interface`
all on. A "click" is press + release within the 5px motion threshold (so
`mouse_moved` stays 0; it is reset at press, `callback.c:5123`).

- **A:** isolated no-motion click, then Shift+drag copy an abutted pair → copy
  draws a wire (pre-fix).
- **B:** no-motion click on two abutted devices → a `{x y x y}` wire appears
  (pre-fix); `xschem get wires` == 1.
- **C:** load `nand2.sch`, no-motion click on instance 12 (m2) → `xschem get
  lastsel` == 0 (pre-fix); a bare instance returns 1.

`xschem get connect_by_kissing` and `xschem get mouse_moved` have **no getter**
(return empty) — observe via `wires` / `lastsel` / `instances` instead.

---

## 6. Verification & guards

- `test_cadence_drag` (now **16 checks**): Phase 6 proves the feature (plain drag
  of abutted pins generates a wire); Phase 7 proves the fixes (no stub on a click;
  no spurious wire on Shift+copy after a no-kiss click; click-to-isolate still
  works; **a kissing-instance click stays selected**).
- Every fix was **sabotage-verified**: revert the unconditional reset → the leak
  check reddens; revert the early-abort → the stub check reddens; revert the
  re-select → the stays-selected check reddens.
- Regression guards stayed green throughout: wireedit TC1–5/11/13–16, golden
  harness (`HARNESS: PASS`), `stable_handles` 58.

---

## 7. Acceptance criteria

- Plain drag still follows abutments and T-junctions (Phase 3 intact).
- A **click** (no motion) on any instance — bare, abutted, or wired — leaves that
  instance selected and creates **no** wire.
- A Shift+drag copy never draws connecting wires from a leaked flag.
- The cadence click-to-isolate behavior is unchanged.

---

## 8. Tutorial — when a feature's side effect escapes its intended gesture

This was not one bug; it was a **cascade of three**, each fix exposing the next.
That shape is itself the lesson. The deeper subject is the **lifecycle of a
side effect armed on one event and consumed on another**.

### 8.1 "Press" is three gestures wearing one coat

The whole cascade traces to a single design move: arming `connect_by_kissing` in
the **press** handler. But a Button1 press in this editor is the prefix of *three*
different gestures, only disambiguated later:

| Gesture | Disambiguated by | When |
|---|---|---|
| **drag** (the move we wanted to kiss) | motion > 5px | release |
| **click** (just select) | no motion | release |
| modified drag (copy/detached) | Shift/Ctrl | release |

The feature was designed for one of the three (drag) and silently attached itself
to all of them. Every symptom downstream is a click or a copy executing a code
path meant for a drag.

> **Paradigm — arm on the disambiguated event, not the ambiguous one.** If a side
> effect only makes sense for one outcome of an ambiguous gesture, arm it when the
> outcome is *known*, not at the shared prefix. We couldn't fully do that here
> (the kiss must scan pins at the pre-move position, which is only available at
> press), which is exactly why every *other* exit of the gesture then had to learn
> to unwind it. When you cannot defer the arming, you have signed up to handle
> **every** way the gesture can end.

### 8.2 A sticky global is a contract with every exit path

`connect_by_kissing` is a `xctx` global flag with a tiny protocol: *set to 2, and
the next move/copy START consumes and clears it.* That protocol has an unwritten
clause — **every** path that ends a move/copy must clear it — and the ABORT path
violated it (it cleared only when a kiss happened). Regression A is precisely that
missing clause.

> **Paradigm — a global flag is an invariant, and invariants need a complete set
> of maintainers.** When you add a setter, enumerate *all* the consumers and *all*
> the abort/cancel/error exits, and make each one restore the invariant. "END
> resets it" is not enough if ABORT, no-motion-return, and exception paths exist
> too. The grep that matters is not "where is this set" but "where can this
> gesture *end*."

### 8.3 Injected objects corrupt decisions made downstream

Regression B is subtle and worth slowing down on. The kiss inserted a *selected*
stub wire. Nothing about that wire is wrong in isolation — but it silently changed
the value of `xctx->lastsel`, and a release-path branch three steps later
(`lastsel != 1`) *keyed its decision on that count*. One injected object flipped a
conditional that had nothing to do with kissing, which then corrupted the undo
restore. The bug is an **action at a distance**: the cause (insert a stub) and the
symptom (wrong deselect + surviving wire) are in different functions with no
visible link.

> **Paradigm — mutating shared state mid-gesture is spooky action at a distance.**
> Before injecting an object/flag/selection into a shared structure during a
> multi-step interaction, ask *who reads this between now and the end of the
> gesture, and will my injection change a decision they make?* Selection counts,
> "dirty" flags, undo depth, and z-order are the usual victims. Issue 0011 in this
> very folder is the same shape (a hover redraw read a stale selection snapshot);
> two cadence-mode bugs, one root pattern.

### 8.4 The non-obvious fact: `pop_undo` is not selection-preserving

Regression C hinged on one fact that no signature advertises: **`pop_undo` calls
`unselect_all`.** Restoring a document snapshot conceptually "shouldn't" touch the
*selection* — but this implementation rebuilds the whole drawing, so it does. Fix B
introduced an abort on a path (a click) where the user expects their selection to
*persist*, and that abort quietly nuked it via `pop_undo`.

> **Paradigm — know the full blast radius of the primitive you call.** "Abort the
> move" sounds selection-neutral; it wasn't. When you reuse a heavyweight
> primitive (`pop_undo`, "reload", "reset") on a new path, audit *everything* it
> touches, not just the thing you wanted. The asymmetry in the symptom (bare
> instance fine, wired gate broken) was the fingerprint: the same gesture behaving
> differently by data shape almost always means a *conditional* side effect — here
> `pop_undo` ran only when a kiss happened.

### 8.5 The cascade itself: why fixes bred fixes

Each fix was locally correct and globally incomplete, because each one **moved**
the problem rather than dissolving its root:

```
arm kissing on every press   (29e55f90)
  └─ flag leaks to copy       → fix: always reset on abort      (A, b52c4648)
       └─ but abort path was never reached for kissing clicks
          → fix: abort early, before the deselect branch        (B, b52c4648)
            └─ but early abort's pop_undo wipes selection
               → fix: re-select after abort when cleared         (C, d296b673)
```

The root — *a drag-only side effect armed on every press* — was never removed; it
was **contained**, one exit path at a time. That is a legitimate engineering
choice (the alternative, deferring the kiss, fights the pre-move-position
constraint), but it must be made **knowingly**: when you choose containment over
removal, you owe yourself an enumeration of the paths to contain, up front —
otherwise the user enumerates them for you, one bug report at a time (which is
literally what happened: A was reported, then C was reported).

### 8.6 What to do proactively next time

With hindsight, the cascade was avoidable — not by being smarter mid-bug, but by a
short ritual *before* committing the feature:

1. **Draw the gesture lifecycle before arming anything.** List every way the
   gesture can end: drag-release, click-release, Shift, Ctrl, Escape/abort,
   tab-switch, error. A side effect armed at press has to be correct (or undone) on
   **all** of them. Here that list *is* the three regressions — they were
   discoverable as a checklist on day one, not as three separate reports.

2. **Test the gesture you're *not* building.** Phase 3 had a strong test for the
   drag (the happy path). It had **zero** tests for the click and the copy — the
   exact paths that broke. When you add a side effect to a shared prefix, the first
   regression tests to write are for the *other* exits of that prefix. A one-line
   "a plain click creates no wire and stays selected" check would have failed
   immediately on the feature commit.

3. **Treat `git grep` of the flag as a coverage map.** `connect_by_kissing` is set
   to 2 in nine places (`callback.c` ×7, `scheduler.c` ×2) and reset in a handful.
   Before shipping, confirm the **reset set dominates the set set** — every arming
   has a guaranteed disarming on every exit.
   The asymmetry (END unconditional, ABORT conditional) was visible in a 30-second
   read of the two ABORT blocks side by side.

4. **When you inject into shared state mid-gesture, grep its readers.** After the
   kiss inserts a selected wire, `git grep lastsel` in `callback.c` would have
   surfaced the `lastsel != 1` deselect branch as a reader whose decision your
   injection changes. Injection + reader-audit is a cheap pre-mortem.

5. **Audit the blast radius of reused primitives.** Before putting `move_objects(
   ABORT)` on the click path, a glance at what ABORT calls (`pop_undo` →
   `unselect_all`) predicts regression C without a user report. "What does this
   helper touch besides the thing I want?" is a 2-minute question that saves a
   round trip.

6. **Prefer dissolving a root to containing it — or contain it deliberately.** We
   contained. That was defensible given the pre-move-position constraint, but the
   decision should be *explicit in the commit message* ("kiss must arm at press;
   therefore every gesture exit must unwind it; here are the exits"), so the
   completeness obligation is visible to the next reader instead of implicit.

### Takeaways to carry forward

1. A side effect armed on an **ambiguous** event (press) owes correctness to
   **every** disambiguated outcome (drag, click, copy, abort).
2. A sticky global flag is an invariant; every exit path is a maintainer; missing
   one is a leak.
3. Injecting objects/flags into shared state mid-gesture is action at a distance —
   audit who reads it before the gesture ends.
4. Heavyweight primitives have blast radius (`pop_undo` → `unselect_all`); reuse
   them only after reading what they touch.
5. A cascade of fix-breeds-fix means the **root was contained, not removed** —
   make that choice deliberately and enumerate the paths up front.
6. The cheapest test to write for a shared-prefix side effect is the path you did
   **not** build for.
