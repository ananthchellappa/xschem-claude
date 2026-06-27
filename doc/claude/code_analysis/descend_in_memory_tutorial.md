# Tutorial: from a save-prompt bug to crash-safe hierarchical editing

A real-world walkthrough of how a one-line bug report ("why does descending into
a cell ask me to save?") turned into a small architectural feature in XSCHEM —
letting you descend through a hierarchy and edit freely without ever being
prompted to save or risking lost edits. The design evolved mid-build (Part 5):
an in-memory snapshot, then — on review — an editor-style `cellName~.sch` backing
file. Both arcs are taught here, including *why* the second won.

This is a **living document**: it grows one part at a time as the work proceeds.
Every concept is paired with the concrete decision, command, or code from this
exact effort, so you can see the reasoning *in situ* rather than in the abstract.

Companion docs:
- Design/plan: `doc/claude/specs/descend_hierarchy_in_memory.md`
- Progress + resume state: `doc/claude/specs/descend_handoff.md`

Covered so far: **Parts 1–12 (Steps 0–6, the design pivot, B1–B4 of the
backing-file autosave, B5 — removing the descend save prompt, B6 — extending
autosave to symbols + the descend_symbol no-prompt path, B7 — hiding the `~`
backups from cell listings, B8 — lifecycle + crash recovery, the B9 deep-hierarchy
audit — close/quit prompting across the descend stack, and the Cadence-style
per-level close/quit walk-up + dialog polish).**

---

## Part 1 — Diagnosis: a report is a symptom, not a cause

### Lesson 1 — Trace the mechanism; don't guess from the symptom

The report: *"Right-click → Descend on a non-primitive cell pops a 'save?' dialog.
Nothing was modified."*

The tempting guess is "descend has a save step." The truth was one layer deeper.
`descend_schematic()` (`src/actions.c`) only saves **if the schematic is already
flagged modified**:

```c
if(xctx->modified) {
  ret = save(1, 0);          /* -> ask_save dialog */
  ...
}
```

So the real questions became: (a) why is `xctx->modified` set on a file the user
never touched, and (b) why only for non-primitive cells? Question (b) had a tidy
answer — a *type gate* runs **before** the modified check:

```c
if((sym)->type && strcmp(type,"subcircuit") && strcmp(type,"primitive"))
  return 0;                 /* leaf devices bail out here, never reach the save */
if(xctx->modified) { ... }  /* only descendable cells get this far */
```

`res`/`capa` are `type=resistor`/`capacitor` → they return before the check, so
they never prompt. Subcircuits fall through and do.

**Takeaway:** the first job is to find the *actual* line that produces the
behavior. "Descend prompts" was a symptom of "modified was already set" — a
completely different bug than it appeared.

### Lesson 2 — Reproduce first, and reproduce in the user's mode

Before changing anything, reproduce headlessly so you can iterate fast:

```sh
src/xschem --no_x -q --script repro.tcl     # prints `xschem get modified`
```

Plain load → `modified=0`. No repro! The user runs a **cadence-style** config.
Re-running with their rc (`src/cadence_style_rc`) → `modified=1` right after
`load_new_window`. The bug only exists in a particular mode.

**Takeaway:** a non-reproduction is information. "Works for me" usually means
"my configuration differs from theirs." Match the environment before concluding.

### Lesson 3 — When you can't see the cause, instrument it

`modified` was set *somewhere* during load. Rather than read every candidate, we
made the program tell us. A temporary backtrace at the moment the flag flips:

```c
int set_modify(int mod) {
  if(mod == 1 && xctx->modified == 0) {       /* TEMP: catch the 0->1 transition */
    void *bt[24]; int n = backtrace(bt, 24);
    backtrace_symbols_fd(bt, n, 2);
  }
  ...
}
```

The frames came back as addresses; `addr2line -f -e src/xschem <addr>` resolved
them to:

```
set_modify  <-  trim_wires  <-  load_schematic  <-  create_new_tab ...
```

**Takeaway:** a five-line instrument that prints a backtrace beats an afternoon of
reading. Resolve static-function addresses with `addr2line`. Then *remove* the
instrument — it was scaffolding, not a fix.

### Lesson 4 — Behavior emerges from interacting features

The backtrace named `trim_wires`, but *why* did it run on load, and only in
cadence mode? Following the chain:

```
cadence_compat=1
  └─ a Tcl trace sets autotrim_wires=1            (xschem.tcl)
       └─ load_schematic() runs trim_wires()       (save.c, gated on autotrim_wires)
            └─ it compacts redundant wires -> set_modify(1)   (check.c)
```

No single component is "wrong." A convenience (auto-join wires) + a mode that
enables it + a file with trimmable wires = a freshly-opened file marked dirty.

**Takeaway:** in a system with many toggles, bugs live in the *interactions*. Map
the chain end to end; the fix usually belongs at one specific link, not the ends.

**The Part-1 fix** (`save.c`): a load-time normalization must not make an untouched
file look edited. Snapshot the flag around the trim and restore it:

```c
int mod_before_norm = xctx->modified;
check_collapsing_objects();
if(reset_undo && tclgetboolvar("autotrim_wires")) trim_wires();
if(reset_undo && !mod_before_norm && xctx->modified) set_modify(0);
```

Genuine edits still set `modified`; only the self-inflicted load-time change is
undone.

---

## Part 2 — The architecture, and a deeper question

### Lesson 5 — Know your data model before redesigning behavior

The user made a design argument: *descending isn't discarding — you'll return, so
why prompt at all? Prompt on close or when going back up, where edits are actually
at risk.* Correct in principle — but is it how the code works? Read the model:

- **`xctx`** is one global context with **one** set of object arrays
  (`wire`, `inst`, `sym`, ...). Only the *current* hierarchy level is in memory.
- **Descend** (`actions.c`): `load_schematic(child)` loads the child **over** the
  parent's arrays. The parent's geometry is gone from memory; only small per-level
  metadata (`zoom_array[]`, `sch_path[]`, `hier_attr[]`, ...) is stacked.
- **go_back** (`actions.c`): `load_schematic(parent)` **re-reads the parent from
  disk**.

So in the *current* code, descending **does** discard the in-memory parent, and
returning rebuilds it from the file. The save-prompt was the only thing making
unsaved parent edits survive a round trip.

**Takeaway:** validate the user's mental model against the implementation. Here
the ideal behavior was right but *not yet true* — which reframed the task from
"remove a prompt" to "make descend non-destructive."

### Lesson 6 — Prove the data-loss claim; don't assert it

Before removing the prompt, we proved what removing it (naively) would cost:

| step | parent wires |
|------|------|
| load | 1 |
| add a wire (now modified) | 2 |
| descend, decline save | — |
| **go_back** | **1**  ← the added wire is gone |

A scripted, repeatable experiment turned "I think this loses data" into "here is
the data loss." That evidence justified the bigger fix instead of a one-liner.

**Takeaway:** when a change's safety is in question, build the smallest experiment
that demonstrates the failure. Evidence beats argument and prevents shipping a
plausible-but-wrong shortcut.

### Lesson 7 — Separate the symptom fix from the design change

Two independent problems were now clear:
1. **Spurious `modified` on load** — a real bug, fixed in isolation (Part 1).
2. **Descend is destructive** — an architectural gap requiring real work (Part 2).

We shipped (1) immediately (it solves the actual report) and planned (2) behind a
written spec. Crucially, we *kept the save-prompt* until the redesign made it
safe to remove — never trade a safe annoyance for silent data loss.

**Takeaway:** unbundle "fix the reported bug" from "fix the underlying design."
Ship the safe, small fix now; gate the risky redesign behind a plan and tests.

---

## Part 3 — Building the feature, test-first

### Lesson 8 — RED-first: write the test that *defines* done, and watch it fail

The very first implementation step was a **failing** test
(`tests/headless/test_descend_preserve.tcl`) encoding the goal:

- **S1**: edit the parent, descend (declining the save), `go_back` → the edit must
  still be there, and `modified` must still be 1.
- **S2**: descend must not pop the prompt at all.

Run on the unchanged code, it failed in exactly the right way (the four *setup*
checks passed; the two *acceptance* checks failed). A test that fails for the
expected reason is a specification you can execute.

Two practical points:
- **Self-contained fixture.** Rather than depend on a fragile library schematic,
  we generated a tiny parent/child pair under
  `tests/headless/fixtures/descend/` (a `type=subcircuit` symbol whose `<name>.sch`
  exists, so descend resolves it). Tests shouldn't rely on unrelated files.
- **Make the test observe the seam.** The test stubs `ask_save` to *return "no"
  and count calls* — so it both prevents the dialog from blocking headless and
  can assert (later) that the prompt is gone.

**Takeaway:** a RED test first makes "done" objective and stops scope creep. If it
doesn't fail — or fails for the wrong reason — fix the test before the code.

### Lesson 9 — Reuse battle-tested machinery instead of inventing it

The feature needs to snapshot/restore an entire schematic in memory. XSCHEM
already does exactly that, correctly, for **undo**: `mem_push_undo` /
`mem_pop_undo` deep-copy every object type (wires, instances, symbols via
`copy_symbol`, texts, per-layer rects/lines/polys/arcs, all `prop_ptr` strings)
into an `Undo_slot`.

So we didn't write a new serializer. We **extracted** the existing bodies into
reusable, slot-agnostic functions:

```c
void mem_serialize_slot(Undo_slot *s);              /* current drawing  -> slot */
void mem_restore_slot(Undo_slot *s, int set_modify);/* slot -> current drawing  */
```

and generalized the helpers they call (`free_undo_*`) from `(int slot)` to
`(Undo_slot *)` so they work on *any* slot, not just the undo ring `uslot[]`.
`mem_push_undo`/`mem_pop_undo` kept their stack bookkeeping and now just delegate.

An earlier idea — swap the whole `Xschem_ctx` pointer like the tab system does —
was rejected: it collides with the `currsch`-indexed metadata arrays and the
cross-level highlight code, which assume a single context. Reusing the undo
serializer keeps one context and touches far less.

**Takeaway:** the cheapest correct code is code that already exists and is already
tested. Look for the operation you need *already happening* elsewhere, and factor
it out rather than reimplementing.

### Lesson 10 — Refactor behind a safety net, in behavior-neutral steps

Steps 2–3 changed *no behavior* — they only moved code. The guard was the existing
undo test (`wireedit_14`) plus the full suites, run after each extraction:

```sh
cd src && make xschem
bash tests/headless/wireedit/run_wireedit.sh      # 18/18
cd tests && tclsh run_regression.tcl              # no FAIL/GOLD/FATAL
```

Because the refactor was mechanical and the tests were green before and after, a
later real bug can't hide in "the refactor."

**Takeaway:** make refactors provably behavior-neutral and commit them separately
from behavior changes. When something breaks later, `git bisect` lands on the
commit that *meant* to change behavior.

### Lesson 11 — C memory lifecycle: lazy alloc, teardown, and where *not* to free

The per-level store is `Undo_slot hier_slot[CADMAXHIER]` plus
`hier_slot_valid[]` / `hier_slot_modified[]`, all zeroed because `xctx` is
`my_calloc`'d. Each slot's inner arrays are allocated **lazily** at first use
(`mem_init_hier_slot`) and freed in two places:

- **per level** on `go_back` (consume the snapshot), and
- **all** at context teardown (`free_xschem_data`).

The subtle part is **where not to free**: the design note literally says "free in
`clear_drawing`" — which is *wrong*. Descend's child-load calls `clear_drawing()`,
so freeing snapshots there would wipe the parent snapshot you just took. Lifecycle
bugs are usually about the *one* call site you didn't expect to run.

**Takeaway:** for every allocation, name its free sites *and* the call sites that
must **not** free it. In C the second list is where the bugs hide.

### Lesson 12 — Compose with existing code instead of replacing it

`go_back` already does a lot besides loading geometry: file identity, window
title, netlist directory, read-only state. Rather than reproduce all that, we let
`load_schematic` run as before and then **overlay** the preserved geometry:

```c
load_schematic(1, filename, set_title, 1);          /* identity/title/etc. as today */
if(snapshot exists && keep_in_memory) {
  mem_restore_hier(currsch);                         /* swap in preserved drawing */
  set_modify(1);
}
```

It costs one disk read we then partly discard — but it reuses every bookkeeping
detail `load_schematic` already gets right. Optimize later; be correct now.

**Takeaway:** "load then overlay" is often safer than "replace." Touch the minimum
and lean on code that already handles the long tail of details.

### Lesson 13 — Keep the old path one boolean away (a bisect switch)

The new behavior is gated by a Tcl variable, `descend_keep_in_memory` (default 1).
Setting it to 0 restores the exact legacy disk-reload path. That's not for end
users — it's so we can A/B the two implementations in one binary while validating.

**Takeaway:** when you replace a code path, leave a switch to the old one during
bring-up. It turns "is this my change?" from a rebuild into a variable assignment.

---

## Part 4 — Fidelity: "it works" is not "it's faithful"

### Lesson 14 — Test equivalence, not just success

S1 proved edits *survive*. It did not prove the round trip is *exact*. Step 6 added
`test_descend_fidelity.tcl`, which:

1. loads the parent fresh and `saveas` to a file,
2. loads it, descends, `go_back`s, and `saveas` to a second file,
3. asserts the two `.sch` files are **byte-identical** (every object type and
   property), plus checks zoom restoration and a clean `modified` flag.

Comparing the *saved files* is a strong, cheap equivalence check: the file format
already serializes everything, so you don't need a per-field reader.

**Takeaway:** "the feature works" and "the result is identical to the baseline"
are different claims. A round-trip that saves and diffs catches drift that a
behavioral test sails past.

### Lesson 15 — The bug the fidelity test caught: cached/derived state leaks

The diff was not empty:

```
< N 0 -60 0 0 {}
---
> N 0 -60 0 0 {lab=INA}
```

Two unlabeled wires came back with a derived net name (`lab=INA`) **baked into
their saved props**. Bisecting *where*: not `go_back`, not the snapshot timing —
it was as early as **selecting the instance to descend into**. Net resolution
(`prepare_netlist_structs`) writes derived names into live wire props; the legacy
disk reload silently *laundered* that, while our faithful snapshot preserved it.

Method that found it: A/B the three save outputs — `fresh`, `disk-reload round
trip` (flag off), `memory round trip` (flag on):

```
DISK vs FRESH: identical
MEM  vs FRESH: DIFFER     <- the regression is ours, and only in the memory path
```

**Takeaway:** an in-memory snapshot captures *cached/derived* state too, not just
the authored model. When "faithful to memory" diverges from "faithful to disk,"
decide which one you actually want — and prove which path introduced the gap.

### Lesson 16 — The fix that is also a better design

Why did we snapshot at all? To preserve **unsaved edits**. If the parent was
*not* modified, there are no edits to preserve and the disk file is authoritative
*and* clean. So `go_back` overlays the snapshot **only when the parent was
modified**:

```c
if(!from_embedded_sym && xctx->hier_slot_modified[currsch]) {
  mem_restore_hier(currsch);   /* dirty parent: in-memory truth wins  */
  set_modify(1);
} else {
  mem_free_hier_slot(currsch); /* clean parent: trust the disk reload */
}
```

A clean parent now returns byte-identical to disk (fidelity test green); a dirty
parent keeps every edit (S1 green). The baking is confined to files that are
already dirty and about to be saved anyway. One predicate fixed the fidelity bug
*and* narrowed the feature to exactly the case that needs it.

**Takeaway:** the best fix often shrinks the feature. Ask "when is this machinery
actually needed?" — guarding on that condition frequently removes the bug for free.

### Lesson 17 — Don't *produce* what you've decided not to *consume*

Lesson 16 made `go_back` *use* the snapshot only when the parent was modified. But
the code still *took* a full deep-copy snapshot on **every** descend — including
the common case of browsing down into an unmodified design — and then discarded it
unused. The producer and the consumer disagreed about when the work was needed.

A reviewer's question ("do we only save the edits, to be efficient?") surfaced it.
The fix is to gate the *production* on the same predicate as the *consumption*:

```c
/* snapshot ONLY when the parent has unsaved edits -- the sole case go_back uses it */
if(tclgetboolvar("descend_keep_in_memory") && xctx->modified) {
  mem_snapshot_hier(xctx->currsch);
  xctx->hier_slot_modified[xctx->currsch] = 1;
}
```

For a clean parent this skips a full-schematic deep copy entirely — meaningful when
you descend several levels into a large design just to look around. Correctness is
unchanged (a clean parent was always restored from disk).

We then *locked the optimization in* with an observable invariant rather than
trusting it: a tiny read-only query `xschem get hier_slots` (count of live
snapshots) plus `test_descend_efficiency.tcl`:

```
unmodified descend -> hier_slots == 0   (no snapshot taken)
modified   descend -> hier_slots == 1   (taken)
after go_back      -> hier_slots == 0   (freed)
```

**Takeaway:** when one predicate decides whether an output is *used*, push that same
predicate to where the output is *produced*. And make non-functional properties
(cost, "no work done") *observable* so a test can defend them — otherwise the next
refactor silently reintroduces the waste.

---

## Part 5 — The pivot: when a simpler design appears mid-build

### Lesson 18 — Evaluate a reviewer's alternative honestly; sunk cost is not a vote

With the in-memory feature built and tested through Step 6, the reviewer asked:
why keep edits in memory at all? Write the edited cell to a backing file
`cellName~.sch` (the classic editor `~`-file), read it back on return. It reuses
the bulletproof save/load path, persists edits to disk, and gives crash recovery.

The wrong instinct is to defend what's built. We'd written real code — but six
committed steps are not an argument for the *design*. We compared the two on the
axes that matter for an EDA tool (new-code/bug-surface, crash safety, read-only
dirs, disk clutter, speed) and found the backing-file approach genuinely simpler
and more robust. So we pivoted: the in-memory mechanism (Steps 4–6) gets
replaced; what's reusable (the Part-1 fix, the undo-serializer refactor, the
behavior tests, this tutorial) carries forward.

Two discipline points made the pivot cheap and safe:
- **Validate the load-bearing assumption first.** The whole design hinges on
  "a highlight is not an edit." Before re-planning, we *proved* it: no
  `set_modify` in `hilight.c`/`findnet.c`/`node_hash.c`, and load/select/hilight
  all leave `modified=0`. If that had been false, the autosave hook would fire on
  every highlight — the design would have been wrong at the root.
- **Don't over-engineer the new idea either.** The first cut proposed
  `$XSCHEM_TMP_DIR/.hier_<pid>_<lvl>_cell.sch` to dodge read-only dirs and
  two-windows-same-cell collisions. The reviewer pushed back: just use
  `cellName~.sch`. Re-examined, those edge cases are non-issues for a *parent*
  backup (the cell you're editing is writable; a read-only cell can't be saved
  anyway). The conventional name won. Solving problems you don't have is its own
  kind of debt.

**Takeaway:** the tests and refactors you wrote are assets that survive a design
change; the *mechanism* is replaceable. Judge a proposed design on its merits,
prove its key assumption before committing, and resist gold-plating the
replacement as much as defending the incumbent.

### Lesson 19 — Choose the primitive by its side effects, not its name

The obvious function to write the backup was `save_schematic()`. Reading it first
saved a nasty bug: it **mutates the live buffer** — renames `sch[currsch]` to the
new filename, clears the selection (`unselect_all`), rewrites the timestamp and
window title. Perfect for "Save As"; catastrophic for an autosave that fires on
*every edit* (your selection would vanish as you work; the buffer would rename
itself to `cellName~.sch`).

The right primitive was one level down: `write_xschem_file(fd)` — a pure
serializer that takes a `FILE*` and writes content, touching no live state. So
`write_backup()` is just `fopen` + `write_xschem_file` + `fclose`.

**Takeaway:** name-matching the call ("I need to save → `save_schematic`") is how
you import side effects you didn't want. Read the candidate and pick by what it
*does to your state*, not what it's called. The function with fewer side effects
is usually the correct building block.

### Lesson 20 — Test the helper in isolation, and don't trust libc's twin

B1 added a `xschem backup write|remove|name` command *before* wiring autosave into
the edit path. That seam earned its keep immediately: the first run **segfaulted**,
and because the trigger was a one-line `xschem backup name`, the cause was
unambiguous — not buried inside a move/paste handler firing autosave mid-gesture.

The cause: `backup_file_name` used `my_snprintf(dest, n, "%.*s~%s", ...)`. XSCHEM
ships *two* `my_snprintf`s — a `vsnprintf` passthrough, and a hand-rolled fallback
that "implements only the bare minimum set of formatting." This build used the
fallback, which doesn't grok `%.*s` (variadic `*` precision) — it misparsed and
crashed. The fix was plain `memcpy`/`strcpy`.

**Takeaway:** build the observable seam (a tiny command/query) before the
automatic trigger — a crash on an explicit call is a five-minute fix; the same
crash inside an event handler is an afternoon. And a project's wrapper around a
libc function (`my_snprintf`, custom `strdup`, …) may implement only a subset —
don't assume full `printf` semantics.

---

## Part 6 — Wiring the autosave (and what a central funnel does and doesn't catch)

### Lesson 21 — Hook the funnel, but guard the funnel's non-user callers

The backing file should be written "on every edit." XSCHEM already has the perfect
single funnel: `set_modify(1)` is called once at the end of each edit operation. So
the hook is one line — `if(mod == 1) write_backup();`. But a funnel catches
*everything* that flows through it, not just what you pictured:

- **Load also flows through it.** In cadence mode, opening a file runs
  `trim_wires`, which calls `set_modify(1)` — so a naive hook writes a `~` while
  merely *opening* a file. Fix: `load_schematic` brackets itself with a new
  `xctx->no_autosave` flag (saved/restored around both return paths) and
  `write_backup` early-outs on it. Opening a file is not an edit.
- **Removal does NOT belong on the symmetric event.** The tempting symmetry is
  "write on `set_modify(1)`, remove on `set_modify(0)`." But *every load ends with
  `set_modify(0)`* — so removing there would **delete a crash-recovery backup on
  every open**. Removal instead hangs off a *real save* (`save_schematic`). The
  events that create and destroy a resource are often not the mirror image you
  expect.

And the part that made the whole design viable: highlight/select/pan/zoom and net
resolution **don't** call `set_modify(1)` (verified before the pivot), so the
funnel hook excludes them for free — no special-casing "a highlight is not an edit."

**Takeaway:** a single choke point is the right place to hook cross-cutting
behavior, but enumerate *every* caller that flows through it — especially the
non-user ones (load, internal normalization) — and guard them. And don't assume
the teardown belongs on the inverse event; trace when the resource must actually
die.

### Lesson 22 — Identity vs content: reuse the loader, then restore the name

`go_back` must load `cellName~.sch` (the edited content) but the buffer must still
*be* `cellName` — its title, hierarchy path, and save target. Reusing the full
`load_schematic(cellName~.sch)` gets all the heavy lifting (symbol linking, prep
flags, viewport) right, but it also stamps the buffer's identity as `cellName~`.
So we load by content, then re-assert identity:

```c
load_schematic(1, bak, set_title, 1);                 /* content from the ~ file   */
my_strdup2(_ALLOC_ID_, &xctx->sch[currsch], filename);/* identity is cellName      */
my_strncpy(xctx->current_name, rel_sym_path(filename), ...);
... current_dirname, time_last_modify from the REAL cellName ...
set_modify(1);                                        /* unsaved vs cellName        */
```

This is the editor's "buffer name vs backing file" distinction made explicit: the
content lives in one file, the identity points at another. Conflating them would
make Save write to `cellName~.sch` and the title lie.

**Takeaway:** when you load content from a stand-in file, separate *content* from
*identity* deliberately. Reuse the real loader for the hard parts, then fix up the
few identity fields — don't hand-roll a parallel loader, and don't let the
stand-in's name leak into the buffer.

### Lesson 23 — After a pivot, delete the superseded mechanism promptly — but keep the shared parts

Once the backing file replaced the in-memory snapshot, the `hier_slot[]` store and
its five `mem_*_hier` functions, the `descend_keep_in_memory` flag, and the
`xschem get hier_slots` probe were all dead. We removed them in one focused commit
the moment the new path was green — not "later." Dead code that "might be reused"
isn't an asset; it's a maintenance tax and a comprehension trap (the next reader
can't tell it's unused).

The discipline that made this safe: a single `grep` for every identifier confirmed
the references were confined and inter-dependent, so removal couldn't leave a
dangling call. And the cut was *surgical* — the genuinely shared extraction from
Lesson 9 (`mem_serialize_slot`/`mem_restore_slot`, still used by undo) stayed. The
undo test passing after the deletion proved the line was drawn correctly.

**Takeaway:** delete superseded code as soon as its replacement is proven, in its
own commit, after a reference sweep — but distinguish "scaffolding for the old
design" (delete) from "a reusable piece you happened to factor out" (keep, and let
its own tests guard it).

---

## Part 7 — Removing the guard, last (and proving the suite isn't lying)

### Lesson 24 — Remove a safety prompt only after its replacement is green, not before

The whole arc started with "why does descend prompt to save?" — yet the prompt was
the *last* thing removed, in B5, not the first. The order was deliberate. The
`if(xctx->modified) save(1,0)` block was the **only** thing preventing silent data
loss on a descend/return round trip (Lesson 6 proved the loss empirically). You do
not delete a guard until the thing that makes it unnecessary is built *and proven*:

- the autosave hook persists every edit to `cellName~.sch` (B2),
- `go_back` reloads that backup, restoring edits *and* the modified flag (B3),
- the acceptance test S1 (no data loss) and the fidelity test are both green.

Only then is removing the prompt a one-block deletion that flips S2 RED→GREEN with
S1 staying green. The diff is tiny; the precondition for the diff was five prior
steps. Sequencing — symptom fix, then mechanism, then *finally* retire the guard —
is what kept every intermediate commit safe to ship.

One detail worth noting: the old block also did `if(ret==0) clear_all_hilights()`
— it cleared highlights when the user *declined* to save, because the on-disk file
would then be stale and cross-level hilight propagation would be inconsistent. That
concern evaporates with the backing file: `go_back` reloads `cellName~.sch`, which
*is* the current edited content, so there is no stale-disk inconsistency to defend
against. When you remove a guard, account for its side effects too — and confirm the
new design makes each one moot rather than silently dropping it.

**Takeaway:** the reported symptom is often the right thing to fix *last*. Retire a
guard only once the mechanism that made it redundant is built and its tests are
green — and check that every side effect of the guard (here, the hilight clear) is
genuinely unnecessary under the new design, not just forgotten.

### Lesson 25 — A passing suite that never ran the code is the most dangerous kind

After B5 the headless tests went green and the regression run reported no
FAIL/GOLD/FATAL. That looked like done. It wasn't — the regression cases had
**FATAL'd on every case**: `couldn't execute "xschem": no such file or directory`.
The summary was clean only because the per-case `.log` files were never produced, so
the FAIL/GOLD/FATAL grep matched nothing. Absence of failure markers was being read
as success when the real meaning was "nothing ran."

Two reads of the same artifact tell different stories, so look past the summary line:

```
results.log:            (no FAIL/GOLD/FATAL)        <- looks green
create_save_output.txt: FATAL: couldn't execute "xschem" (×N)  <- actually ran nothing
```

The fix was environmental — the `tests/` cases invoke a bare `xschem`, so the built
binary has to be on `PATH` (`PATH=$REPO/src:$PATH`) on top of the
`XSCHEM_SHAREDIR=$REPO/src` the harness already needed. Re-run: `FATAL=0`, cases
genuinely executed. (The classic create_save/open_close/netlisting cases still have
no `gold/` folder in this checkout, so they generate results without a golden
comparison — a pre-existing property of the tree, and one B5 doesn't touch since it
changes no netlisting path. The real coverage for this change is the headless
descend suite.)

**Takeaway:** "no failures reported" and "the code under test ran" are different
claims — the green-but-hollow trap. Verify execution happened (a nonzero count of
cases that actually invoked the binary, `FATAL=0`), not just that the failure grep
came back empty. A summary that reads a log that was never written is silence
wearing a green coat.

---

## Part 8 — Extending the feature to symbols (and refusing to regress the deferred case)

### Lesson 26 — When the mechanism is type-agnostic, "extend it" can be mostly "test it"

B6 was "symbols too." The instinct is to write symbol-specific autosave code. But
the backing file keys off `backup_file_name()`, which was written from the start to
insert `~` before *either* extension (`cell.sch -> cell~.sch`, `cell.sym ->
cell~.sym`), and the autosave hook fires from `set_modify(1)` — which a symbol edit
calls exactly like a schematic edit. So editing a `.sym` buffer *already* wrote
`cellName~.sym` and a save *already* removed it. The "feature" for that half of B6
was three assertions (Part A), not new code.

The lesson isn't "do nothing" — it's that when you build a choke-point mechanism
(one filename helper, one funnel), later "extensions" often reduce to proving the
existing path already covers the new type. Write the test that would fail if it
*didn't*, watch it pass, and you've both verified the claim and locked it against a
future refactor that special-cases one extension and forgets the other.

**Takeaway:** before adding code to extend a feature to a new case, check whether the
mechanism was already general. If it was, the work is a characterization test that
pins the behavior — cheaper than code, and it documents the generality.

### Lesson 27 — A test bug can look exactly like a program crash; read the command before blaming the code

Part A's first run ended with `free(): invalid pointer` on exit. Alarming — a
double-free in teardown after a symbol edit. The reflex is to suspect the autosave
code or `free_xschem_data`. The discipline that saved an hour: *isolate before
theorizing*. A clean descend_symbol round trip didn't crash (Probe). The crash
needed an *edit* (`xschem line ...`) — but it fired with autosave OFF and with no
save at all, so neither the backing file nor save was the cause.

The cause was the test: `xschem line 4 -40 -40 40 -40` — five numbers. The command
is `line x1 y1 x2 y2 [pos]`, so the trailing `-40` became `pos=-40`, and
`storeobject(-40, ...)` indexed out of bounds. Drop the stray `4` and the crash
vanishes. The program was fine; the *test* corrupted memory by misusing a command.

**Takeaway:** a crash surfaced by your new test is not proof your feature crashes.
Bisect what actually triggers it (edit vs. save vs. teardown; flag on vs. off)
before reading the implementation. A malformed test command can scribble over memory
just as well as a real bug — and "it crashes only with my change present" can simply
mean "my change is the only thing exercising that command."

### Lesson 28 — "Deferred" must mean "left as safe as before," never "quietly regressed"

The plan defers embedded-symbol editing. So when B6 removed the descend_symbol save
prompt, the easy reading was "embedded is out of scope — ignore it." That was wrong.
`go_back`'s embedded return path (`from_embedded_sym`) reloads the parent from
*disk*, not from `cellName~.sch`. So with the prompt gone, descending into an
embedded symbol from a modified parent reloaded the *stale* parent on return — the
unsaved edit silently vanished (verified: parent wires 2→1, `modified` back to 0).
Removing the prompt didn't leave embedded "deferred"; it *broke* it.

The fix gated the removal on the *same predicate* descend_symbol already uses to
detect an embedded symbol (`EMBEDDED flag || embed attr`): non-embedded gets the new
no-prompt backing-file behavior, embedded keeps the legacy prompt — exactly as safe
as before. And a Part-C assertion pins it: embedded descent *still prompts*, so a
future "finish B6" can't silently re-open the data-loss path without a red test.

**Takeaway:** a feature that you're *not* touching can still be *broken* by a change
elsewhere if it shared the guard you removed. Before deleting a guard, ask which
other paths leaned on it — and for each one you're deferring, keep it exactly as safe
as it was and write a test that *fails* if someone later removes that safety. Deferred
is a promise to leave it working, not a license to let it rot.

---

## Part 9 — Hiding the artifact: enumerate every surface, exempt the resolver

### Lesson 29 — A new on-disk artifact leaks into every directory listing; find them all

The moment edits started writing `cellName~.sch`/`~.sym` next to the real cells,
those `~` files became visible everywhere the tool *lists* cells: the file-open
dialog, the library browser, the insert-symbol search. Nobody wants to open
`opamp~.sch` from a picker. Creating a sibling file is never just "write a file" —
it's "write a file that now shows up in every `glob` of that directory."

The work was to enumerate the listing surfaces, not guess one. A grep for `glob`
in the GUI layer surfaced the real set: `setglob` (the dialog lister, with *two*
branches — the `*` show-everything case and the `*.sch`/`*.sym` filter case, both of
which match the `~` siblings), `sub_match_file` (the browser/insert regexp matcher),
and `get_list_of_dirs_with_files` (which decides whether a directory even *appears*
as "containing cells"). Miss any one and the artifact leaks through that path.

The fix is one predicate (`is_backup_file`) applied at each surface — not three
ad-hoc string checks. A single helper means the definition of "what is a backup" can
never drift between the dialog and the browser.

**Takeaway:** when you introduce a file the program writes, list every place that
*reads the directory* and decide what each should do with it. One predicate, applied
at each enumeration point, beats scattering the same `string match` in three styles.

### Lesson 30 — Distinguish a *lister* from a *resolver*; only the lister hides

Two kinds of code touch these files. *Listers* enumerate "what cells are here?" for
a human to choose from — those must hide `~` backups. *Resolvers* answer "where is
the file named exactly X?" — symbol→schematic resolution (`abs_sym_path`) only ever
asks for `cellName.sch`, never `cellName~`, so it needs no change, and
`sub_find_file` (exact `$fname == $f` match) is a resolver too and was left
untouched. Filtering a resolver would be wrong: if something legitimately asked for
that exact name you'd hide the answer.

This is why hiding the backups is *complete and safe* with edits only to the
listers: nothing resolves a cell *by globbing*, so a hidden-from-listing file is
still perfectly loadable by its real name (which is exactly what go_back does with
`cellName~.sch` in B3). Cosmetic invisibility, zero functional reach.

**Takeaway:** before filtering a file out of a code path, classify the path: does it
*enumerate choices* or *resolve a known name*? Hide in the first, never in the
second. The same filename can be correctly invisible to a picker and fully reachable
by the loader at the same time.

---

## Part 10 — Closing the lifecycle: the artifact must mean something

### Lesson 31 — The second consumer is when the duplicated code finally earns extraction

B3 wrote, inline in `go_back`, the "load the `~` content but keep the cell's
identity" dance — load the backup file, then overwrite `sch[currsch]`,
`current_name`, `current_dirname`, `time_last_modify`, and `set_modify(1)`. Inlining
it was *correct then*: one caller, and premature extraction is its own guess. B8
introduced the **second** caller (crash recovery on open needs exactly the same
content/identity split). That's the signal — not "this looks reusable," but "a
second site now needs the identical thing." Extracting `load_backup_as()` removed
sixteen lines from `go_back`, gave recovery a one-line call, and — because the
existing descend round-trip tests still pass — proved the extraction was
behavior-neutral on the spot.

**Takeaway:** "don't repeat yourself" triggers on the *second* occurrence, not the
first. The first inline copy is a hypothesis; the second consumer confirms it and
tells you the exact shape to factor out. Extract then, with the original site's tests
as your safety net.

### Lesson 32 — An artifact is only useful if its presence is unambiguous

The `~` backup is meant to mean "unsaved edits survived a crash." But that meaning
only holds if the file is *absent* in every non-crash ending. A real save already
removed it (B2). The gap was the *intentional discard*: clear / new-file / "don't
save on close" left the `~` behind, so the next open would offer to "recover" edits
the user had deliberately thrown away — crying wolf until nobody trusts the prompt.
Adding `remove_backup()` to the discard path closes that: now a surviving `~` means
exactly one thing — the session ended *without* a clean exit. The recovery offer is
trustworthy precisely because every clean path cleans up after itself.

The same "unambiguous" instinct drove the mtime check: a `~` *older* than its cell
can't be live unsaved work (the cell was saved afterward), so it's stale junk —
deleted silently, never offered. Only a backup newer than the cell is a real
recovery candidate.

**Takeaway:** a recovery/lock/temp artifact is only as useful as the guarantee that
it exists *only* in the state it's supposed to signal. Enumerate every way the
program can end — save, discard, new-file, crash — and make all the non-target
endings remove it. An artifact that lingers after a normal exit trains the user to
dismiss the very prompt it powers.

### Lesson 33 — Make the dangerous part inert in the contexts that can't consent

Crash recovery *replaces the buffer the user just opened* with different content —
exactly the kind of action you never want firing unbidden in a script, a replay, or
a headless test. So the auto-offer is gated `if(!force && has_x)`: it runs only on an
interactive GUI open (`-gui`), never on programmatic `xschem load`, replay lines, or
`--nogui`. The *mechanism* (`load_backup`, `xschem_recover_backup`) stays fully
testable in isolation — the test calls the primitive and the proc directly with a
stubbed dialog — but the *automatic* trigger is inert everywhere a human isn't
present to answer the prompt. That split (testable mechanism, context-gated trigger)
is the same one from Lesson 20, applied to a destructive action instead of a crash.

**Takeaway:** when an automatic behavior is destructive or interactive, gate the
*trigger* on the context that can actually consent (GUI + interactive), and keep the
*mechanism* callable on its own so tests exercise it without the trigger. Don't make
a feature untestable to make it safe, and don't make it unsafe to make it testable.

---

## Part 11 — The audit finds the guard-shift's *third* victim

### Lesson 34 — Removing one guard can under-protect several distant paths; an invariant has many readers

Lesson 28 caught the embedded-symbol path breaking when B5/B6 removed the descend
save prompt. The B9 deep-hierarchy audit — prompted by the user actually *driving*
the GUI: descend two levels, `Ctrl-W` — found a **third** victim of the *same*
removal. Closing or quitting (`Ctrl-W`, `Ctrl-Q`, the window's X) all funnel through
`xschem exit`, which guarded on `xctx->modified`. That was correct for years because
of an invariant the old descend save *maintained*: **whenever you were deep in a
hierarchy, every ancestor was already saved to disk** (descend forced it). So the
current level's modified flag was a faithful proxy for "is anything unsaved?"

B5 removed that save. Now you can descend past an unsaved parent (its edits live in
`cellName~.sch`), so one level down `xctx->modified` is 0 while the parent is dirty —
and `exit` closed the window with no prompt. The edits weren't *lost* (the `~`
survived for recovery), but the warning the user expects simply didn't fire. One
removed guard had quietly weakened **three** separate consumers of the same
invariant: go_back (fixed by B3's reload), embedded-symbol descent (fixed by B6's
gate), and now close/quit.

The fix is a predicate that asks the real question — `hierarchy_modified()`: current
level modified, *or* any ancestor on the descend stack still has a `~` backup —
substituted into all four `exit` guards (tabbed/non-tabbed × window-count). The `~`
trail that B2–B8 built *is* the per-level dirty record, so the detector just reads it.

**Takeaway:** when you delete a guard, you haven't found all the fallout until you've
listed every place that read the *invariant the guard maintained*, not just the
guard's call site. "All ancestors are saved when deep" had at least three readers;
each needed its own repair. An audit that drives the real UI (descend, then close)
surfaces the readers a unit test aimed at the changed function never visits.

### Lesson 35 — Make "is this dirty?" answer for the whole unit of work, not one frame

The deep-frame bug is really a category error: the program tracked "is the *current
schematic frame* modified?" when the question the user is asking at quit is "does my
*design* have unsaved work?" A hierarchical edit session is one logical document
spread across stacked frames; `xctx->modified` describes the top frame of the stack.
The autosave `~` files turned each frame's dirtiness into a durable, queryable fact,
so "is the document dirty?" became answerable — sum the frames, don't read the top.

**Takeaway:** when state lives in a stack of contexts, a boolean on the *active*
context rarely answers a question about the *whole* stack. Decide which unit the
user's question is really about (the document, not the frame) and compute the answer
across the whole unit — ideally from a record you already maintain.

### Lesson 36 — One concept, many call sites: fix the *predicate*, not the first site you find

The deep-close fix (Lesson 34) substituted `hierarchy_modified()` into `xschem
exit`, shipped green, and *still didn't work in the GUI*. The user re-tested in their
real mode and it closed with no prompt anyway. The cause: "close this schematic" is
not one function. `xschem exit` handles the main non-tabbed window; the **tabbed
interface** closes through four *other* paths in `xinit.c` — `destroy_tab`
(Ctrl-W on a tab), `destroy_all_tabs` (Ctrl-Q), `destroy_window`,
`destroy_all_windows` — each with its own copy of `if(xctx->modified && has_x)`. I
fixed one of five sites and declared victory. The concept "is there unsaved work to
warn about?" had five implementations, and the user's mode happened to use the four I
hadn't touched.

The find was *only* possible by instrumenting and reading the actual branch taken:
the debug showed `tabbed=1` and that `hierarchy_modified()` was **never called**
during the close — which immediately said "the close isn't going through the code I
changed." Grepping `xctx->modified` across the *windowing* file, not just the exit
command, surfaced all five.

**Takeaway:** before you fix "the" guard, grep the *predicate* across the whole tree
and count its implementations. A user-facing concept ("close", "save", "is dirty")
is often spread across per-mode call sites that each re-derive it. Fixing one and
seeing your own test go green proves nothing if the user's path runs one of the
others. The green test that "passed" was testing the detector, never the four sites
that actually fire.

### Lesson 37 — If the trigger is gated on a flag your tests can't set, the wiring is untested by construction

Every one of those five close-guards is `hierarchy_modified() && has_x`. The headless
harness runs `has_x = 0`, so the prompt branch is *structurally unreachable* in a
test — the detector is unit-tested, but whether any close path actually *consults* it
is not, and can't be, headless. That's precisely the crack the Lesson-34 miss fell
through: a green suite that exercises the mechanism and never the wiring reads as
"done" while a whole class of call sites sits unverified.

The honest response is twofold: (1) say so plainly — "this needs a GUI eyeball, the
headless suite cannot reach it" — rather than letting green stand in for working; and
(2) treat the human test as the real gate for `has_x`-gated behavior. The earlier
Lesson-33 split (testable mechanism, context-gated trigger) is right, but it carries a
duty: when the trigger is untestable, you must *name* that gap, not paper over it with
the mechanism's green checkmark.

**Takeaway:** when a behavior's trigger is gated on a flag your test environment
forces off (`has_x`, `isatty`, a GUI toolkit), the wiring between detector and trigger
is untested *by construction*. Enumerate those sites deliberately, fix them as a set,
and route them to a human check — and never let the detector's passing test be quoted
as evidence the trigger fires.

---

## Part 12 — Polishing the close/quit UX: reuse the level machine, decide once

Once the deep-close *guard* fired (Part 11), the user drove it in the real GUI and
asked for three quality fixes: the save dialog was too small; declining a save on
`go_back` left the `~` behind; and Ctrl-W/Ctrl-Q should behave like Cadence — walk
*up* the hierarchy prompting per cell that needs attention, not throw one generic
"unsaved data, exit?" box. These are "make it nicer," but each carries a lesson.

### Lesson 38 — Drive a multi-step flow with the single-step primitive you already trust

The Cadence walk-up is not new traversal code — it is `go_back` in a loop. `go_back`
already ascends one level *and* prompts about that level (Save/No/Cancel) *and*
reloads the parent's backing file *and* honors the embedded-symbol guard. So "prompt
every dirty level, bottom to top" is just "call `xschem go_back 1` until `currsch`
hits 0," detecting Cancel by "did `currsch` actually decrease?". A hand-rolled
walk-up would have re-implemented the exact per-level save/discard/ascend logic the
whole project spent ten parts getting right.

```tcl
while {[xschem get currsch] > 0} {
  set before [xschem get currsch]
  xschem go_back 1                              ;# prompts + saves/discards + ascends
  if {[xschem get currsch] >= $before} { return 0 }   ;# go_back was cancelled -> abort
}
```

**Takeaway:** before writing a loop that repeats an operation, check whether the
single-step primitive already encapsulates everything one iteration needs —
*including its prompts and side effects*. The cleanest multi-step flow is often N
calls to a primitive you already trust, plus a termination/cancel check.

### Lesson 39 — Prompt in your layer, then *force* the layer that would prompt again

The close paths (`xschem exit`, `destroy_tab`, …) prompt on their own when modified.
Once `hierarchy_close` has walked the user through every level's decision, letting
those paths prompt again double-asks. So the orchestration layer does all the asking,
then invokes the teardown with `force`, which both skips the redundant prompt and
clears the modified flag. The discard case *needs* this: "No" leaves the buffer
modified in memory (we only deleted the `~` file), so only `force` makes the
subsequent close honor "don't save" without re-asking.

**Takeaway:** when you lift a decision up into an orchestration layer, tell the lower
layer the decision is already made — pass its `force`/no-confirm flag so it *executes*
instead of re-prompting. A half-lifted decision double-prompts.

### Lesson 40 — "Clean exit removes the artifact" has many exits — including go-back

B8 established the invariant (Lesson 32): every non-crash ending removes the `~`, so
its presence unambiguously means a crash. The user found the exit we'd missed —
declining the save on `go_back` left the `~`. "Leaving a cell without saving" *is* a
discard, a clean ending, so it must drop the `~` too, exactly like clear/new-file/
close. The rule was never "save and close remove it"; it's "every path where the user
consciously abandons edits removes it" — and per-level discard inside a walk-up is one
more such path.

**Takeaway:** when you define "clean endings remove the artifact," enumerate *all* of
them, not the obvious two. Each conscious-discard path that forgets to clean up
degrades the crash-recovery signal back into noise.

### Lesson 41 — A GUI-gated trigger is still testable if you stub the gate's collaborator

Lessons 33/37 noted the `has_x` gate makes prompt-*firing* untestable headless. But
the walk-up *logic* — which levels are visited, what's saved vs discarded, when it
aborts — is fully testable by stubbing `ask_save` (the proc the gate calls) to return
scripted answers. `test_hier_walkup` drives a real 3-level descend and asserts the
`~` files and `currsch` after save-all / discard-all / cancel, dialog stubbed. The
pixels need a human; the decision tree does not.

**Takeaway:** "the trigger is GUI-gated" means the *rendering* is untestable, not the
*behavior*. Stub the dialog proc and the orchestration logic — the part that actually
has bugs — becomes an ordinary unit test. Reserve the human for what only eyes can
judge: layout, wording, feel.

---

## Appendix — the toolbox used here

- **Headless repro:** `src/xschem --no_x|--nogui -q --nolog --script f.tcl`
- **Inspect state from Tcl:** `xschem get modified|wires|instances|xorigin|zoom`,
  `xschem getprop wire i lab` (beware: returns *derived* values, not raw props).
- **Backtrace an event:** `backtrace()/backtrace_symbols_fd()` +
  `addr2line -f -e src/xschem <addr>` for static symbols.
- **Equivalence by file:** `xschem saveas f.sch schematic` then `diff` (strip the
  volatile version header line).
- **A/B a code path:** a default-on config flag (`descend_keep_in_memory`,
  `autosave_backup`).
- **An observable seam:** a tiny read-only query/command (`xschem get hier_slots`,
  `xschem backup name`) so a test can pin behavior — and so crashes surface on a
  one-liner, not inside an event handler.
- **Guard rails:** `wireedit/run_wireedit.sh`, `tests/run_regression.tcl`, run
  after every step; commit refactors and behavior changes separately.

*Next parts will cover B6 (symbol backing files `cellName~.sym` and the
descend-into-symbol path), B7 (hiding `~` files from the file dialog / library
browser / directory scans), B8 (lifecycle + crash recovery: clean `~` on
save/close, offer to restore a stale `~` on open), and B9 (tabs, deep hierarchy,
leak audit, GUI eyeball) — added as those steps land.*
