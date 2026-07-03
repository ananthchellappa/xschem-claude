# Keeping two windows in sync — a tutorial on ambient context, reconciliation, duality, and testing the untestable

*How we made a net highlighted in one window of XSCHEM light up the **same** net,
at a **different level of the hierarchy**, in a second linked window — in both
directions — and what that one feature teaches about ideas a working programmer
uses constantly but is rarely taught by name: that **program state can be
"ambient"** and switching it is a save/restore discipline; that the sane way to
keep two data structures in agreement is to **rebuild one from the other**, not
to patch deltas; that **symmetric problems have symmetric code and symmetric
bugs**; that **you cannot hook an event you forgot exists**; and that a GUI
feature is **not testable until you decide what "correct" means as data**.
Written for a CS student or engineer who can write a hash table and a tree walk
but has never had to keep two live views of the same tree consistent.*

This is a teaching companion to `doc/claude/issues/0073-hilight-not-synced-into-linked-descend-new-window.md`
(the issue, with the blow-by-blow) and a sibling to
`doc/claude/code_analysis/blink_animation_tutorial.md` (which adds *time* to
highlights) and `hover_highlight_tutorial.md` (the *static* overlay). All code is
real and lives in `src/hilight.c`, `src/actions.c`, `src/scheduler.c`, and
`src/xinit.c`. It is meant to be **embellished over time** — sections are
deliberately self-contained so we can grow them.

> **Status of this document:** living notes. Each "Pattern" below is a named,
> reusable idea; each "War story" is where the idea earned its keep (or where its
> absence cost us). Add freely.

---

## Part 0 — The one-sentence idea

> Two windows show the same schematic hierarchy at two different depths. A
> highlight is a fact ("net N is lit") stored **per window**. Keeping them in
> agreement means: on every change, **translate** the fact across the depth
> difference and **rebuild** the other window's facts from yours — a small,
> idempotent reconciliation that runs in whichever direction the depth gap points.

Everything hard about the feature is hidden in three words of that sentence:
*per window* (state is ambient, §2), *translate* (the two-context problem, §4),
and *rebuild* (reconciliation vs. deltas, §5). The rest of the document is those
three words.

---

## Part 1 — The domain in sixty seconds

XSCHEM is a hierarchical schematic editor. A schematic contains **instances** of
symbols; each symbol has its own schematic; you **descend** into an instance to
see its internals, and **ascend** (`go_back`) to return. The chain of instances
you descended through is the **hierarchy path**, e.g. `.x1.x4.` — "inside `x4`,
which is inside `x1`, which is at the top."

A **highlight** ("probe this net") is stored in a hash table keyed by
`(path, net-name)`. So the *same* net name means different things at different
paths: `(".", "CTRL1")` is a top-level net; `(".x1.", "CTRL1")` is the net named
CTRL1 *inside* `x1`. This composite key is the whole reason the feature is subtle
— see §3.

You can open the *same* design in a **second window** and descend it
independently. Now you have two live views. A user highlights a net in one and
expects to see it in the other. That is this feature.

---

## Part 2 — Pattern: **ambient context** and the borrow/restore discipline

### The pattern

Most of XSCHEM's state hangs off **one global pointer**, `Xschem_ctx *xctx`.
Nearly every function reads `xctx->...` implicitly. This is **ambient state**
(a.k.a. *dynamic scope*, *the "God context"*, or in web terms *request-local
context*): the code does not pass the context as a parameter; it reads whatever
context is "current."

Each open window is its own `Xschem_ctx`, parked in an array `save_xctx[]`. Only
one is "current" (`xctx`) at a time. To *read or draw a different window's state*
you must make it current, do the work, and put the old one back:

```c
Xschem_ctx *saved = net_hilight_borrow_ctx(win_path); /* xctx := that window */
if(saved) {
  ... operate on the borrowed window ...
  net_hilight_restore_ctx(saved);                     /* xctx := what it was  */
}
```

This is exactly a **register save/restore across a call**, or a **coroutine
context switch**, or **RAII scope guard** in a language that has one. The
invariant is *balance*: every borrow has exactly one restore, and the pair
leaves `xctx` precisely as it found it. `net_hilight_borrow_ctx` returns `NULL`
(a no-op) when you ask for the window you're already on or an unknown one, so the
`if(saved)` makes the pair self-balancing even on the no-op path.

### Why it matters here

The whole cross-window sync is: *stay in the changed window, borrow each related
window, rewrite its highlights, restore.* If any path could borrow-without-
restore, the global pointer would be left dangling and the next unrelated command
would corrupt the wrong window. The discipline is the safety.

### War story (the ambient trap that became Bug 1)

Ambient state has a signature failure mode: **a value you read implicitly is not
the value you think it is.** The draw guard read `xctx->top_path` to decide "is
this window on-screen?" For a detached window `top_path` is its widget path; for
the **main window it is empty** — because the main window is a *tab* on a shared
canvas, not a toplevel of its own. The guard `if(top_path[0]) draw()` silently
means "draw only detached windows." Down-direction (children are usually
detached) it worked. Up-direction (the parent is usually the *main* window) it
skipped the draw. See §7 — this is also a *sentinel aliasing* bug.

**Lesson.** With ambient/implicit state, write down the invariant of every field
you branch on ("empty `top_path` ⇒ a tab, which may still be visible"). The bug
is never in the value; it's in your *assumption* about the value.

---

## Part 3 — Pattern: **composite-key hashing** and why a plain copy is wrong

The highlight table is a classic separately-chained hash table (`hilight.c`,
`hilight_hash_lookup`), but the key is `hash(path) folded with hash(token)` —
a **composite key**. Two consequences drive the whole design:

1. The *same net name at two depths* is two distinct entries. So a naive
   "copy the whole table from window A to window B" is **insufficient**: it gives
   B the entry at A's depth (inert at B's depth), not the entry B needs at *its*
   depth. You must **synthesize the cross-depth entry** — that's the translation
   of §4.
2. Membership and value both live in the entry, so "is net X lit here, and in
   what color?" is one lookup. The sync carries the *value* (color/style) across,
   not just a boolean.

**Pattern name:** *key design determines algorithm.* When your key encodes
structure (here: hierarchy path), operations that cross that structure cannot be
value-level copies; they must recompute the key. Beginners reach for "just copy
the map"; the composite key is why that fails.

---

## Part 4 — Pattern: the **two-context (gather → apply) computation**

### The crux

To light net N of the child in the parent (ascend), you need two facts that live
in **two different windows**:

- *Which of the instance's pins are lit* — lives only in the **child** table
  (keyed at the child's depth).
- *Which parent net each pin connects to* — the map `inst.node[pin]` and the
  symbol's pin names — lives only in the **parent** context.

Neither window has both. In a *single* window, `hilight_parent_pins()` does this
translation trivially because both facts share one table and `currsch` (the depth
cursor) selects the key. Across two windows the fact is **split**.

### The shape of the solution

This is the **gather-then-apply** shape (a.k.a. *read phase / write phase*, or
*map then reduce*, or in systems terms *read-copy-update*):

```
Phase A (gather):  read the child's lit net tokens straight out of src->hilight_table
                   (a plain struct read — no borrow needed, src is just a pointer).
Phase B (apply):   borrow the parent; for each pin, if its child-side net is in the
                   gathered set, record the parent-side net; then rebuild + redraw.
```

The key engineering move: **do the read that needs context X entirely before you
switch to context Y.** You cannot hold two ambient contexts at once, so you
*snapshot* one into plain local data (arrays of `(token, value)`), then switch.
The snapshot is the bridge between the two worlds.

The down-direction (`net_hilight_sync_one_child`) is the same shape mirrored:
gather in the source (parent), apply in the borrowed child. Recognizing that both
directions are the *same* two-phase pattern is what made the second direction a
day of work instead of a week — see §6.

### The arithmetic nobody warns you about

Vector/bus pins make the translation a modular-index problem:
`find_nth(parent_net, ((inst_number-1)*mult + k-1) % net_mult + 1)`. This is not
incidental; any time you map an *N-wide thing instantiated M times* onto a flat
net vector you get this `(instance, bit) → flat index` formula. It is the same
math as addressing a 2-D array stored row-major, or de-interleaving channels.
Steal it whenever you flatten a repeated bundle.

---

## Part 5 — Pattern: **reconciliation** (rebuild-from-source) beats delta-patching

### The choice

When the source changes, you can update the target two ways:

- **Delta/patch:** compute what was added and removed, apply just those.
- **Reconcile/rebuild:** throw the target away and recompute it from the source.

The single-window ascend (`hilight_parent_pins`) is a *patch* — it even has a
famous commented-out `XDELETE` because deleting parent nets on child-unhighlight
is subtle and it chose to leave them "sticky." That stickiness is a bug magnet:
state drifts because the inverse operation is hard to get exactly right.

Our sync **reconciles**: `clear_all_hilights()` + copy the source table verbatim
+ re-synthesize the crossed-depth entries + `propagate`. Every change rebuilds
the whole target from scratch.

### Why reconcile

- **Idempotent.** Running it twice = running it once. No accumulation of drift.
- **Clear-through is free.** Un-highlight in the source and the rebuild simply
  doesn't re-create the entry — no special "delete" path to get wrong.
- **It converges.** The target is always exactly `f(source)`; there is no history
  to corrupt.

This is the **desired-state reconciliation** pattern you already know from React's
virtual-DOM diff, Kubernetes controllers, Terraform, and functional UI in general:
*describe what the output should be as a pure function of the input, and re-derive
it, rather than scripting the transitions.* The cost is recomputation; for a table
of a few probed nets that cost is nothing, and the correctness win is total.

### Corollary: **stale is worse than missing**, and reconciliation is how you kill stale

A later retest found the sharpest version of this lesson. When the second window
had descended *two* levels below the first (with no window at the level in
between), a highlight cleared in the first window **stayed lit in the deep second
window** — a probe the user had "cleared everywhere" persisted. A *missing*
highlight (a net that should be lit but isn't) is a mild disappointment; a
*stale* highlight (a net that should be gone but lingers) actively lies to the
user about the state of their circuit. Rank them: stale > missing.

Reconciliation is the cure precisely because **clearing needs no translation**.
Lighting the exact net across a multi-level gap is hard (it needs the netlist of
the level in between, which is loaded in no window — a genuine, documented
deferral). But "make the target equal to an empty source" is trivial at any
depth: clear it and copy. So clearing propagates unconditionally, at any distance
(`net_hilight_sync_orphans`, `net_hilight_reconcile_verbatim`, `hilight.c`).

**Design rule (first cut):** when the full transformation is only *partially*
computable, do the computable part everywhere rather than nothing where it's hard.
Never let "we can't do the exact thing here" degrade into "so we leave stale state
here." Guarantee the cheap invariant (no stale) unconditionally; best-effort the
expensive one (exact lighting) where the inputs allow.

### The trap on the other side: **a partial answer can be a WRONG answer**

The first version of this reconcile over-reached. Reasoning "clearing is free, so
let me also copy the deep entries up and at least get the *buried-net cue* for
free," it did a **verbatim** copy in both directions. That looked like more
coverage. It was a lie.

A buried-net cue (a rectangle on an instance) means "a highlighted net is buried
in this instance's subtree, invisible at this level." But a deep net often does
**not** stay buried — it connects up through pins to a real net you *can* see at
the top (a deep `OUT` that surfaces as `CTRL1`). Whether it surfaces is exactly
the fact you can't compute without the intermediate netlist. So the verbatim copy
painted a "buried" rectangle on the ancestor instance for a net that wasn't buried
at all — a **confident, wrong signal**, and the *only* signal, since the real net
(`CTRL1`) couldn't be lit. A user reading that rectangle is being actively misled
about their circuit.

Rank the outcomes: **stale > missing > wrong.** Stale (a highlight that should be
gone) is bad; *wrong* (a highlight/cue asserting something false) is worse, because
the user trusts it. The first fix moved us from stale to wrong for the surfacing
case — a regression in disguise.

**The corrected rule:**

> Clearing propagates across any gap. *Populating* only crosses a gap you can
> actually **translate** (≤1 level, or a chain of windows one level apart). An
> untranslatable gap syncs **clearing only** — it must never invent a cue it
> cannot validate.

Mechanically: the orphan reconcile copies only source entries whose path is an
**ancestor-or-self** of the target's current path (`net_hilight_copy_table_ancestor`)
and **drops every sub-target (deeper) entry** — the ones that would manufacture an
unvalidatable buried cue. Clearing still works (an empty source clears the target
at any depth); a deep highlight now shows **nothing** in the far window (missing,
never wrong) until a window actually visits the intermediate level and the precise
±1 relay does the real translation.

Note the deliberate **asymmetry**: the ±1 path still copies verbatim, because there
the deep entry rides *alongside* the real, translated net (matching the single-
window `go_back` result) — the cue is not a lone false claim. Same mechanism
(verbatim copy), opposite decision, because one context can validate the cue and
the other cannot. **The lesson: "best-effort where inputs allow" must include the
humility to output *nothing* when the only thing you can compute would be a lie.
Coverage is not a virtue if the covered answer is wrong.**

### The composability knob: a visited-set so precise and coarse paths coexist

There are now two reconcilers: the precise per-level translation (for windows one
hop apart, and chains of them) and the coarse verbatim mop-up (for orphans too far
to translate). They must not fight — the coarse one must not clobber a window the
precise one just did correctly. The arbiter is a one-bit-per-window **visited set**
(`nh_sync_visited[]`): the precise pass marks every window it handled; the mop-up
skips anything marked. So a fully-open descend chain keeps the precise relay, and
only genuine orphans fall through to verbatim. This is the general shape whenever a
cheap fallback backstops an expensive primary: **run the primary, record what it
covered, let the fallback handle only the remainder.** Without the visited set the
fallback silently overwrites good work — a classic layered-strategy bug.

### Subtle but essential: verbatim copy carries the "unrelated" state

Rebuilding the parent purely from one child would wipe the parent's *other*
highlights. It doesn't — because the copy is **verbatim**, and the child already
holds the parent's ancestor-level entries (the down-sync copied them down as inert
entries). So "rebuild parent from child" round-trips the parent's own state back
through the child. The two windows are treated as **one logical highlight state
viewed at two depths**; each direction re-derives the other from a table that
already contains both depths. That is why the naive-looking "clear and copy"
is actually conservative.

---

## Part 6 — Pattern: **duality** — symmetric problems, symmetric code, symmetric bugs

Descend/ascend are inverses. So are the two translations
(`hilight_child_pins` ↔ `hilight_parent_pins`) and the two syncs
(`net_hilight_sync_one_child` ↔ `net_hilight_sync_one_parent`,
`..._children_rec` ↔ `..._parents_rec`). Recognizing the duality is a
*force multiplier*: the second direction is the first with source/target swapped
and the level comparison flipped (`currsch+1` becomes `currsch-1`).

But duality cuts both ways: **a flaw in one half tends to be copied into the
other.** Bug 1 was exactly this — the draw guard was mirrored up along with a
latent assumption that didn't survive the mirror. The fix was to **extract the
shared truth into one helper** (`net_hilight_ctx_visible`) used by both halves,
so the duality is enforced by *sharing code* rather than *duplicating it*. That is
DRY with a purpose: not "less typing," but "one place for the invariant so the two
symmetric callers cannot disagree."

**Lesson.** When you copy code to build the mirror image, copy the *intent*, not
the *lines*. Better: don't copy — factor the common part out so the mirror is
structural, not textual.

---

## Part 7 — Pattern: **sentinel aliasing** — when one representation means two things

Empty `top_path` was overloaded to mean **both** "a hidden background tab" **and**
"the visible main window / front tab." Two genuinely different states aliased to
one representation. Any predicate that branches on it is guessing.

This is the *null-object / sentinel ambiguity* antipattern: a single sentinel
value stands in for multiple distinct conditions, so downstream code cannot tell
them apart. The cure is always the same — **add a discriminator**. Here:
`drw_front_win` (xinit.c), a tracker of *which* tab is currently shown on the
shared `.drw` canvas, read via `get_drw_front_win()`. Now "empty `top_path` AND
not the front window" unambiguously means "hidden tab," and the visible main
window draws.

The same discriminator fixed the earlier animation freeze (issue 0073 §8b) *and*
Bug 1 here — one missing bit of state, two bugs. When one added field kills
multiple bugs, that field was **missing domain state**, not a patch.

**Lesson.** If a boolean has to answer a question your data can't actually
distinguish, you have under-modeled the state. Add the bit; don't add a heuristic.

---

## Part 8 — Pattern: **observer completeness** — you can't hook what you forgot

The sync runs from **hooks** placed at every operation that mutates highlights —
seven of them (`hilight_netname`, `hilight_net_styled`, `unhilight_net`,
`hilight`, `hilight_instname`, waveform, `unhilight_all`). This is the
**observer/publish pattern**: state changes *notify* the sync.

Bug 2 was a **hole in the observer set**. Highlight *mutations* were hooked, but
`go_back`/`descend` also change what a window shows and, via
`hilight_parent_pins`, *re-map* its highlights to a new depth — a change the other
window must see. Nobody had registered navigation as a sync trigger, so ascending
a deep child never told the parent. The fix added two more hook sites.

**Lesson (the checklist that prevents this class of bug).** For any "keep X in
sync" feature, *enumerate every path that mutates the thing X depends on* — not
just the obvious verbs. Ask: "what else changes the mapped state?" Highlights
depend on *depth* as much as on *which net*, so anything that changes depth is a
mutation too. Missing observers are silent: nothing errors, the mirror just
quietly lags. The only defense is an explicit enumeration, ideally written next to
the state it guards.

---

## Part 9 — Testing: how to make a GUI feature test-driven

The feature is visual, multi-window, and animated — the reflexive verdict is
"untestable, eyeball it." That verdict is wrong, and avoiding it is the most
transferable lesson here.

### 9.1 Define correctness as **data**, and get an **oracle** for free

The breakthrough move: highlights are a **table you can print**
(`xschem display_hilights`). So "the windows agree" becomes a *string equality*,
not a screenshot. The moment your correctness condition is data, the feature is
testable.

Then: where does the *expected* data come from? From the **single-window** version
of the same operation. Highlight a net inside `x1`, `go_back`, dump the table:
`{FOO} {xi.FOO}`. That is the **oracle** — the byte-for-byte target the
cross-window path must reproduce. We didn't invent the expected output; we
*derived* it from a path already known to be correct. This is
**metamorphic / differential testing**: two different routes (single-window
ascend vs. two-window sync) must yield identical output, and one route is the
reference for the other.

> Establish the oracle *first*, before writing the feature. It doubles as the spec.

### 9.2 **RED before GREEN**

Write the assertion, run it against the *unfixed* binary, watch it fail for the
*right reason*. We did: the five up-direction asserts failed with the parent table
empty — proving the test actually exercises the missing path, not something
incidental. A test you never saw fail is a test you don't know works.

### 9.3 **Sabotage = mutation testing**: prove the test can catch the bug

Green is not enough — a *vacuous* test (asserting something always true) is also
green. So after fixing, we **deliberately re-broke** the code (an env-gated
early-return in the sync; then the same for the `go_back` hook), rebuilt, and
confirmed **exactly** the relevant asserts flip to FAIL while the unrelated ones
stay green. That is textbook **mutation testing**: a test suite is only as good as
its ability to fail when the code is wrong. The isolation ("only the ascend asserts
fail") also *localizes* the guarantee — it proves which assertion guards which
line.

This directly counters the **"green but hollow"** trap: a suite can be all-green
while the changed code never ran. Sabotage is the cheapest possible defense.

### 9.4 Test the **boundary**, not just the happy path

We asserted both "primary **NOT** synced from the deep (2-levels-down) state" and
"primary **IS** synced after ascending to depth-1." Encoding the *limit* of the
feature as a passing test does two things: documents the deferred scope precisely,
and turns "we'll do deep descent later" from a vague note into a **red line the
suite defends** — the day someone implements deep sync, that first assert flips and
tells them to update the test on purpose.

### 9.5 Assert **sustained** behavior for time-dependent things

For animation we asserted **≥3 ticks in ~1.8 s**, not **>0**. A frozen window
still fires its one *armed* tick, so `>0` passes on a broken window. "Sustained"
is the real property; pick the threshold that a *stuck* system fails. (This is the
same lesson as the blink tutorial: *time is not frames* — measure the process, not
a single sample.)

### 9.6 Recipe (reusable)

1. Express correctness as inspectable **data**.
2. Derive the **expected** data from a known-correct sibling path (oracle).
3. Write the assertion; run **RED**; confirm the failure reason.
4. Implement; run **GREEN**.
5. **Sabotage** each new assertion; confirm it — and only it — fails.
6. Add a **boundary** test that pins the feature's edge.
7. For anything timed, assert **sustained**, with a threshold a stuck system fails.
8. Run the full regression suite; expect zero deltas elsewhere.

---

## Part 10 — How WSLg flakiness shaped every one of these decisions

The user runs under **WSLg** (Wayland/X on WSL2). WSLg is a real compositor but a
*flaky* one for programmatic GUI: focus, raise, expose, and synthetic input are
all timing-dependent and occasionally dropped. That flakiness is not a footnote —
it changed the design and the tests.

### 10.1 It turned a skipped `draw()` from invisible into a **visible** bug

Bug 1 (the parent's cue drawn only on mouse-over) is a *missing explicit repaint*.
On a forgiving compositor, incidental expose events might repaint the window often
enough that a missing `draw()` is rarely noticed. Under WSLg the window genuinely
**stays stale** until an unrelated expose (the mouse moving over it) forces a
repaint — which is exactly the symptom the user reported. WSLg's reluctance to
repaint on its own is what *surfaced* the bug. **Lesson:** never rely on the
compositor to repaint for you; if the state changed, call `draw()` yourself. Flaky
compositors punish implicit repaints immediately.

### 10.2 It dictated how the tests **observe** and **drive**

- **`puts` is swallowed** by the GUI `--script` path, so the test writes a
  `results.log` and the **process exit code is the authoritative pass/fail** — a
  side-channel because the obvious channel is unreliable.
- **`event generate` is unreliable** on WSLg, so the tests never synthesize X
  events; they drive the editor through its own command surface
  (`xschem callback ...`, `xschem hilight_netname ...`). Testing through the
  *model*, not the *input layer*, sidesteps the flaky part entirely.
- **Bare `raise`/focus are no-ops** under WSLg, so window activation goes through
  `raise_activate_toplevel`, not `raise`. (Recorded in the keybind/raise memory;
  it recurs in every multi-window feature.)

### 10.3 It forced **sustained**, event-loop-driven timing assertions

The animation checks must run the real Tk event loop (`vwait`) and count ticks
over ~1.8 s, because under WSLg you cannot trust a single frame to have landed. The
"≥3, not >0" threshold (§9.5) exists partly *because* WSLg makes single-sample
assertions racy — you assert a trend, which is robust to the occasional dropped
frame.

### 10.4 The meta-lesson

A flaky platform is a **fuzzer you didn't ask for**: it exposes every place you
relied on timing, implicit repaint, or best-effort delivery. Painful, but it makes
the code honest — explicit repaints, model-level tests, side-channel results,
trend-based timing. Code hardened against WSLg is simply more correct everywhere.

---

## Part 11 — How to approach a feature like this *proactively*

A distilled checklist, in order, for "keep two live views of a structure
consistent":

1. **Model the state first.** Where does the truth live? Is it ambient (§2)?
   What is the key, and does the key encode structure you'll have to cross (§3)?
2. **Find the existing single-actor version** and make it your **oracle** (§9.1).
   If a single-window path already does the translation, its output is your spec.
3. **Name the invariant** you want between the views ("same logical state at two
   depths") before writing code — it tells you reconcile-vs-patch (§5).
4. **Prefer reconciliation.** Rebuild the target from the source; make it
   idempotent; get clear-through for free (§5).
5. **Enumerate every mutation point** the synced state depends on — including the
   non-obvious ones like navigation that change *derived* keys (§8). Write the list
   down next to the state.
6. **Exploit duality but share code, don't copy it** (§6). Factor the common
   predicate into one helper so the two directions cannot drift.
7. **Hunt for sentinel aliasing** (§7): any boolean that must distinguish states
   your data can't — add the discriminator bit.
8. **Test-drive it as data** (§9): oracle → RED → GREEN → sabotage → boundary →
   sustained → full suite.
9. **Assume the platform is flaky** (§10): explicit repaints, model-level drives,
   exit-code results, trend timing.

Do these and the *second* direction, the animation, and the deep-hierarchy
boundary all fall out of the same machinery — which is exactly how this feature
went.

---

## Appendix A — Map of the code

| Concept | Symbol | File |
|---|---|---|
| Ambient context, borrow/restore | `net_hilight_borrow_ctx` / `net_hilight_restore_ctx` | `hilight.c` |
| Composite-key table | `hilight_hash_lookup`, `hi_hash` | `hilight.c` |
| Single-window translation (oracle) | `hilight_child_pins` / `hilight_parent_pins` | `hilight.c` |
| Down sync (parent→child) | `net_hilight_sync_one_child` / `..._children_rec` | `hilight.c` |
| Up sync (child→parent) | `net_hilight_sync_one_parent` / `..._parents_rec` | `hilight.c` |
| Reconcile (rebuild target) | `clear_all_hilights` + `net_hilight_copy_table_from` + `propagate_hilights` | `hilight.c` |
| Depth-agnostic reconcile (orphan mop-up) | `net_hilight_sync_orphans` / `net_hilight_reconcile_verbatim` / `net_hilight_prefix_related` | `hilight.c` |
| Ancestor-only copy (drop sub-target entries → no false cue) | `net_hilight_copy_table_ancestor` | `hilight.c` |
| Layered-strategy arbiter (visited set) | `nh_sync_visited[]` | `hilight.c` |
| Visibility discriminator | `net_hilight_ctx_visible`, `get_drw_front_win` / `drw_front_win` | `hilight.c`, `xinit.c` |
| Mutation hooks (observers) | `net_hilight_sync_descend_windows` call sites | `hilight.c`, `scheduler.c` |
| Navigation hooks (Bug 2 fix) | end of `go_back` / `descend_schematic` | `actions.c` |
| The test + oracle | `tests/hilight_xwin_sync.tcl` + `tests/hilight_xwin_sync/` | tests |

## Appendix B — The three defects, classified (a teaching table)

| # | Symptom | Never-added or bug? | Underlying pattern | Fix |
|---|---|---|---|---|
| Core | Highlight in child not shown in parent | Never added (deferred v1) | Two-context computation (§4) | New up-sync helpers |
| Bug 1 | Parent cue drawn only on mouse-over | **Genuine bug** (mirrored a latent flaw) | Ambient trap (§2) + sentinel aliasing (§7) + duality copy (§6) | Shared `net_hilight_ctx_visible` |
| Bug 2 | Ascending a deep child didn't update parent | Never added (missing observer) | Observer completeness (§8) | Hook `go_back`/`descend` |
| Bug 3 | Clear in one window left a 2-levels-deep window **stale** | Never added (coverage gap) | Reconciliation / stale>missing (§5) | Depth-agnostic mop-up + visited set |
| Bug 4 | Deep **surfacing** net painted a false "buried" cue on the ancestor | **Genuine bug** (the Bug-3 fix over-reached) | Partial answer = wrong answer / stale>missing>**wrong** (§5) | Ancestor-only copy; populate only where translatable |

*Read the middle column top to bottom: most "why didn't it work" answers are
"the feature never covered that," and the genuine bugs cluster where **symmetry
tempted a copy** and **one representation meant two things**. Those two are the
patterns worth internalizing.*
