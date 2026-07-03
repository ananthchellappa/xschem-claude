# Net highlighting across the hierarchy and across linked windows

*An architectural analysis of how XSCHEM propagates net highlights through a
schematic hierarchy, how it keeps two linked windows' highlights in agreement,
why one particular linked‑window scenario still does not work, and how the whole
subsystem can be tested without a GUI.*

> **Audience and scope.** This is a design‑level explainer for someone who wants
> to *understand* the highlight subsystem — its data model, its two flavours of
> propagation (down/up the hierarchy, and across windows), the buried‑net cue,
> and the boundary where the current implementation deliberately stops. Every
> claim is anchored to current source (branch `fluid-editing`, HEAD `0b6cc230`
> plus uncommitted work) with `file:line` references. A companion document,
> [`net_highlight_linked_windows_agent_guide.md`](net_highlight_linked_windows_agent_guide.md),
> restates the same facts as a dense, actionable map for future implementation
> work, including a concrete fix roadmap and a headless‑test plan. Two earlier
> write‑ups cover adjacent ground: the issue tracker entry
> `doc/claude/issues/0073-hilight-not-synced-into-linked-descend-new-window.md`
> (the blow‑by‑blow of how the multi‑window sync was built) and the CS‑patterns
> tutorial `doc/claude/code_analysis/hilight_multiwindow_sync_tutorial.md`.

---

## 1. Orientation: two kinds of propagation, and one motivating bug

A *highlight* in XSCHEM is a probe on a net: "light this wire up so I can trace
it." Two questions organise everything that follows:

1. **How does a highlight propagate through the hierarchy?** When you highlight a
   net at the top of a design and descend into a subcircuit, the corresponding
   internal net lights up too; when you highlight an internal net and climb back,
   the parent net it connects to lights up. This is *intra‑window* propagation.
2. **How is a highlight kept consistent across multiple linked windows?** You can
   open the *same* design in a second window and descend it independently. XSCHEM
   is meant to keep the two views' highlights in agreement — a probe applied in
   one window appears, at whatever depth the other window sits, in the other.
   This is *cross‑window* synchronisation.

The two are deeply related, because the cross‑window machinery is built out of
the intra‑window translation. And both are best understood through a concrete
failure that this document exists to explain:

> **The reported bug.** Start with a primary window showing a top‑level schematic
> that contains instance `x1`. Descend into `x1` with **New Window** selected — a
> secondary window opens showing `x1`'s master cell. In that secondary window,
> descend *in place* into instance `x4`, and highlight a net there that is **not**
> buried and that connects up to a net visible in the primary window.
>
> - **Symptom 1.** The net does *not* highlight in the primary window. But if you
>   activate the primary and press `0` (unhighlight‑all), the effect *is* visible
>   in the secondary (it clears).
> - **Symptom 2 (reverse).** Highlight a net in the primary that connects down to
>   a net in the secondary. It does *not* highlight in the secondary. Activate the
>   secondary and press `0`, and the primary unhighlights.

The recurring shape — *populating a highlight across the two windows fails, but
clearing propagates* — is not random. It falls directly out of the data model and
the deliberate design of the sync engine, and §7 traces it line by line. The
short version, established below, is that the secondary sits **two** hierarchy
levels below the primary with **no window loaded at the intervening level**, and
the exact cross‑level translation needs a netlist that is loaded in no window.
This is a documented, intentional deferral (issue 0073 §9c), not a regression —
and §10 sketches what a real fix would take.

---

## 2. The data model: per‑window ownership and a composite key

Everything starts with where a highlight is stored, because that single fact
determines what is easy and what is hard.

### 2.1 There is no global highlight store

XSCHEM keeps essentially all live schematic state in one global structure,
`Xschem_ctx *xctx`. To hold more than one open schematic, it keeps an *array* of
whole contexts (`save_xctx[]`, `src/xinit.c:41`) and swaps the global pointer
between them. Net highlighting lives entirely inside each context's own hash
table, `Hilight_hashentry **hilight_table[HASHSIZE]` (`src/xschem.h:1201`;
`HASHSIZE` is 31627, `src/xschem.h:316`). There is no shared store. Highlighting a
net in one window mutates *that window's* table and nothing else; making a
highlight appear in a second window is always an explicit act of copying or
translating entries from one context's table into another's. This is the root of
the entire multi‑window sync machinery.

### 2.2 The record

A single highlight is one `Hilight_hashentry` (`src/xschem.h:871`):

- **`token`** — the net name. A *leading space* is overloaded as a type tag, so a
  net and an instance can coexist in the same table without colliding (see §2.4).
- **`path`** — the dot‑terminated hierarchy path at which this net is highlighted,
  e.g. `.x1.x4.`. This is what makes the key hierarchical.
- **`value`** — the highlight itself. When `value >= 0` it is a style index into
  the `NetHilightStyle` table (colour, width, dash, blink/march), taken modulo the
  number of styles. When `value < 0` it is a *simulation logic level*, resolved to
  a colour by negating and indexing the layer palette instead of the style table
  (`src/hilight.c:654`, `:693`). The levels are `LOGIC_0 = -12`, `LOGIC_1 = -5`,
  `LOGIC_X = -1`, `LOGIC_Z = -13` (`src/hilight.c:1940`).
- **`seq`** — a process‑global monotonic "apply‑order" stamp, bumped on every
  insert or re‑apply from the counter `hilight_apply_seq` (`src/hilight.c:74`,
  `:112`, `:132`). Its sole purpose is the buried‑net cue (§3.5): when several
  buried nets sit under one instance, the cue shows the *most recently applied*
  one, so the winner is the entry with the greatest `seq`. Recency must survive a
  descend, so both `copy_hilights()` (`src/hilight.c:244`) and the cross‑window
  copy (`src/hilight.c:3202`) carry the stamp across verbatim rather than
  restamping.
- `hash`, `oldvalue`, `time`, `next` round out the record (`oldvalue` matters only
  for edge‑sensitive simulation; `next` chains hash collisions).

### 2.3 The composite key is the whole story

An entry is identified not by its net name but by the **pair `(path, token)`**.
`hi_hash()` (`src/hilight.c:25`) hashes the current path `sch_path[currsch]`
first — caching the result in `sch_path_hash[currsch]` — then folds in the net
token; a lookup confirms a match only when the hash agrees *and* both strings
agree (`src/hilight.c:119`). The consequences drive the entire design:

- The **same net name at two different depths is two distinct entries**, because
  their `path` differs. The net `OUT` inside `.x1.x4.` is a genuinely different
  thing from a net `OUT` at the top. This is what makes highlighting
  hierarchy‑aware.
- A **plain whole‑table copy cannot manufacture a cross‑level entry.** Copying one
  window's table into another only ever reproduces entries that already exist in
  the source — it can never invent the differently‑keyed `(path, token)` pair that
  names the same physical wire on the other side of a subcircuit boundary.
  Producing that pair requires *translating* a parent pin‑net into the child's
  internal net name, which is exactly what §3.1 describes. **A copy carries no
  translation.** Keep this sentence in mind; it is the mechanical heart of the
  reported bug.

### 2.4 Instances and derived state share the table

Highlighted *instances* live in the same table, distinguished by "uglification":
`inst_hilight_hash_lookup()` prefixes the instance name with one leading space, or
two for a label/pin (`src/hilight.c:151`). Because a real net name never begins
with a space, the keyspaces never collide, and readers decode the tag by
inspecting the first characters (`display_hilights()`, `src/hilight.c:271`).

Two pieces of state are *derived* from the table and cached for speed:
`hilight_nets` (a fast "is anything highlighted?" flag, `src/xschem.h:1204`,
recomputed by `there_are_hilights()`, `src/hilight.c:290`) and, per instance,
`color` (sentinel `-10000` means "not highlighted") and `buried_hilight`
(sentinel `-1` means "no buried net below me", §3.5). `clear_all_hilights()`
(`src/hilight.c:896`) is the single reset point: it frees the whole table and
walks every instance resetting `color` and `buried_hilight`.

---

## 3. Propagating a highlight through the hierarchy (within one window)

Because an entry is keyed by `(path, token)`, reading or writing a highlight *at a
different level* requires first moving `xctx->currsch` (the depth cursor) to that
level. The two hierarchy translators do exactly this — nudging `currsch` up or
down by one around a single lookup.

### 3.1 Descend: `hilight_child_pins` translates one level down

When you descend into an instance, `descend_schematic` (`src/actions.c:3365`)
records which instance and which vector slice you entered
(`previous_instance[currsch]`, `sch_inst_number[currsch]`, set *before* the depth
increment), increments `currsch`, and calls `hilight_child_pins()`
(`src/hilight.c:1036`) — critically, *before the child schematic is even loaded*
(`src/actions.c:3516`, load at `:3522`). This ordering is deliberate and is the
property the cross‑window sync later reuses: the translation needs only the
*parent* instance (still in memory) and the child symbol's pin **names**, never
the child's internal wiring.

For each pin of the entered instance it takes the external net on that pin,
`expandlabel(inst[i].node[j])`, and the pin's own name. It momentarily steps back
up to the parent level (`currsch--`), asks whether that external net is
highlighted, steps back down (`currsch++`), and — on a hit — writes a highlight
onto the corresponding internal pin‑net at the child level; on a miss it deletes
any stale child entry (`src/hilight.c:1086-1094`).

The bit arithmetic that pairs an external net bit with an internal pin bit is the
recurring motif of the whole subsystem:

```c
find_nth(net_node, ",", "", 0, ((inst_number - 1) * mult + k - 1) % net_mult + 1)
```

Read it as flattening a two‑dimensional index. An instance placed as a vector
(`M2[3:0]`) has several copies; each symbol pin can itself be a bus of width
`mult`. The quantity `(inst_number-1)*mult + (k-1)` lays the *(which copy, which
pin bit)* grid out into a single linear position; `% net_mult` wraps it when the
external net is narrower or repeats; `+1` makes it a 1‑based index. This exact
expression appears in **five** places — the two single‑window translators, the
port‑map `descend_schematic` builds for netlisting (`src/actions.c:3477`), and the
two cross‑window sync helpers — which is a strong sign it captures a genuine
invariant of how vectored instances connect to vectored nets. (It is also a
standing DRY / drift risk: any change to the mapping must be mirrored across all
five.)

### 3.2 Ascend: `hilight_parent_pins` is a patch, not a reconcile

Going back up (`go_back`, `src/actions.c:3571`) decrements `currsch` and runs the
mirror translator `hilight_parent_pins()` (`src/hilight.c:956`) followed by a
`propagate_hilights(1, 1, …)` pass. It steps *down* to test whether an internal
pin‑net is highlighted and, when it is, adds a highlight to the corresponding
parent net (`src/hilight.c:1007-1015`).

The crucial subtlety is what it does *not* do. The branch that would *remove* a
parent‑net highlight when the child pin is not highlighted is present but
**commented out**, with an in‑source explanation (`src/hilight.c:1019-1028`): two
child pins can share one parent net, and deleting the parent net on account of the
un‑highlighted one would be wrong. So single‑window ascend is strictly additive —
it surfaces highlights upward but never retracts one. This makes it a *patch/remap*
of the highlight set rather than a from‑scratch recomputation, and it is why
highlight state can feel "sticky" as you move around the hierarchy. (The
cross‑window sync deliberately does the opposite — it *reconciles* from scratch —
which is what gives it clean clear‑through; see §6.)

### 3.3 `propagate_hilights`: the finalizer

Every highlight change funnels through `propagate_hilights(set, clear, mode)`
(`src/hilight.c:1874`). It walks all instances at the current level and paints
them from the table — conducting instances take the colour of whichever pin sits
on a highlighted net; pin and label instances take the colour of the net on their
terminal; `clear` resets an instance's colour to `-10000` when nothing it touches
is highlighted. It then recomputes `hilight_nets`, optionally drills (§3.4), and
always recomputes the buried‑net cue (§3.5). Note that it edits *instance colours*,
not the *set of net entries* — combined with the additive ascend, that is why
orphaned net entries are not garbage‑collected on the single‑window path.

### 3.4 `drill_hilight`: horizontal, never vertical

The name invites a fatal misreading. `drill_hilight` (`src/hilight.c:1443`) does
**not** drill *down through the hierarchy*. It is a same‑level fixpoint: its outer
`while(1)` repeats until a full instance sweep adds no new net; each sweep visits
only the current level's instances and, for any pin sitting on an already‑highlighted
net, copies that highlight to the *sibling pins of the same instance* named in that
pin's `propag` attribute (`src/hilight.c:1476-1512`). This is how a probe is made to
pass through a resistor, a pass gate, or any device whose pins are annotated as
electrically continuous. Every lookup and insert uses the *current* `currsch`; the
function never changes `currsch`, never touches `sch_path`, and never loads a
subcircuit.

The practical answer to the question a fix design might hinge on is therefore
unambiguous, and it was verified adversarially: **with drilling enabled,
highlighting a top‑level net does not create any `.x1.x4.`‑level entry in that
window's table.** Drill spreads a highlight *sideways* across conducting devices at
one level; it does not pre‑populate deep levels. Drilling is also off by default —
`enable_drill` starts at 0 (`src/xinit.c:798`), is cleared on entry to every
`xschem hilight` and only set when the literal argument `drill` is present
(`src/scheduler.c:3209`), and its only UI trigger is a Ctrl+Shift+K menu item.
The consequence for the bug: the only ways a deep entry ever exists in a window's
table are (a) having physically descended through the intervening level, so that
`hilight_child_pins` could translate across each boundary using each level's
in‑memory netlist, or (b) waveform back‑annotation naming a deep node explicitly.
No code path transiently loads an intermediate schematic just to synthesize a
two‑levels‑removed entry.

### 3.5 The buried‑net cue

When you descend deep and highlight a net *internal* to the cell you are
viewing — one that reaches none of that cell's interface pins — and then climb
back, the highlight would simply vanish from the parent, with no trace that
"something is highlighted down there." Pin‑reaching nets already survive the
climb (their instance gets coloured). The buried‑net cue closes the remaining gap:
an ancestor instance earns a rectangle, drawn in the buried net's *own* highlight
style, so the user learns both *that* and *with which style* a net is highlighted
inside.

`compute_buried_hilights()` (`src/hilight.c:1831`), called last inside
`propagate_hilights`, flags an instance when a highlighted table entry is (1) a
real net highlight not a sim level (`value >= 0`), (2) a net entry not a
space‑tagged instance/label entry, (3) at a path **strictly deeper** than the
current level, (4) under the current level (prefix test), and (5) *not* already
exposed at the instance's pins — the last checked by an independent read‑only pin
re‑scan `buried_inst_pin_hilighted()` (`src/hilight.c:1798`) that deliberately
does not consult `inst[].color`, so the exclusion is robust on every code path.
The algorithm is recursive over depth with no explicit recursion: a net three
levels down flags a different ancestor at each level, purely because its path is
prefix‑tested against the *current* path each time. If several nets are buried
under one instance, the cue shows the style of the most‑recently‑applied one
(highest `seq`, `src/hilight.c:1861`).

The field `xInstance.buried_hilight` (`src/xschem.h:684`) is a style index or
`-1`. It must be stamped `-1` at the instance birth chokepoint `inst_register`
(`src/store.c:543`), because slot‑growth `memset` zeroes it and `0` is a valid
style index — a zeroed field would falsely read as "cue in style 0". Drawing
(`draw_hilight_net`, `src/hilight.c:3773`) renders the four edges of the symbol's
bounding box (outset by `BURIED_CUE_OUTSET_PX = 4.0` screen px) as four "wires"
through `draw_hilight_wire`, so the cue inherits colour, width, dash and the
blink/march animation for free; a dedicated third loop in `scan_animating_hilights`
(`src/hilight.c:2872`) ensures a window whose only animated element is a buried cue
still arms its animation tick. The buried cue re‑appears again in §8, because it is
the reason one particular filter exists in the cross‑window engine.

---

## 4. How multiple linked windows exist, and how one safely reads another

To keep the reported bug tractable, three layers of the multi‑window design must
be clear: the context array, the borrow/restore discipline, and the shared‑canvas
complication.

### 4.1 The context array and the single‑schematic invariant

Every open window or tab is a complete `Xschem_ctx`, and pointers to all of them
live in `save_xctx[MAX_NEW_WINDOWS]` (`src/xinit.c:41`; `MAX_NEW_WINDOWS` is 20,
`src/xschem.h:158`). Slot 0 is the main window. Because the array is `static`,
`hilight.c` reaches it through `get_save_xctx()`.

One subtlety pervades the subsystem: the *single‑schematic invariant*. When only
the main window is open, its schematic still lives in the live global `xctx`, not
in `save_xctx[0]`. This is encoded in exactly one place, `get_window_ctx()`
(`src/xinit.c:138`):

```c
Xschem_ctx *ctx = (get_window_count() == 0 && i == 0) ? xctx : save_xctx[i];
if(win_path) *win_path = (i == 0) ? ".drw" : get_window_path(i);
```

Every per‑slot loop is expected to route through this so the invariant is defined
once. The sync engine's window loops all do.

### 4.2 The borrow/restore discipline

When the highlight code needs to read or draw *another* window — to translate a
parent's highlighted net into a child window and repaint the child — it cannot
afford a full GUI `switch_window` (which raises, refocuses, retitles, and
reconfigures layer buttons). Instead there is a minimal, side‑effect‑free
primitive, `net_hilight_borrow_ctx()` (`src/hilight.c:2922`): it saves the current
`xctx`, points the global at the target, and returns the old pointer;
`net_hilight_restore_ctx()` (`src/hilight.c:2952`) puts it back. The header comment
is emphatic that this is *only* the pointer swap, so it is safe to use
synchronously inside an animation tick.

The pair is **self‑balancing**. Borrow returns `NULL` — "no borrow happened, do
not restore" — for an empty/unknown path, for the window already current, or for
an unallocated slot; and `restore(NULL)` is a no‑op. So callers can always write
the same shape and it is always correct:

```c
saved = net_hilight_borrow_ctx(wp);
if(saved) { /* …work; if(net_hilight_ctx_visible(wp)) draw(); */ net_hilight_restore_ctx(saved); }
```

The borrow matches *only* an exact window path, deliberately not the more
permissive cell‑name fallback of `get_tab_or_window_number()`, which would resolve
ambiguously when two windows show the same cell. Re‑entrancy is safe because
borrows form a balanced stack restored synchronously within one command/tick, with
no `vwait`/`update` between borrow and restore, and Tcl's single‑threaded event
loop runs each callback to completion.

### 4.3 Tabs, detached windows, and the `drw_front_win` sentinel

There are two flavours of extra window, and they differ exactly here. A **detached
window** owns its own Tk toplevel and X canvas; it is marked by a *non‑empty*
`top_path` (e.g. `.x3`). A **tab** does not get its own canvas — every tab renders
into the single shared `.drw` X window (`xctx->window = save_xctx[0]->window`,
`src/xinit.c:2049`), so only one tab is visible at a time.

The trap: both a tab **and the main window** carry an *empty* `top_path`. So an
empty `top_path` is a **sentinel that aliases two different situations** — "hidden
background tab, do not paint" versus "visible main/front tab, definitely paint" —
and a guard that checks `top_path` alone cannot tell them apart. The fix is a
single file‑scope string recording which tab currently owns the shared canvas,
`drw_front_win` (`src/xinit.c:51`), updated by `note_drw_front()` on every event
that can change the front‑of‑`.drw` (window switch, tab switch, tab create, tab
destroy) and read via `get_drw_front_win()`. With it, the visibility test that
gates every cross‑window repaint becomes crisp (`net_hilight_ctx_visible`,
`src/hilight.c:3217`):

```c
if(!xctx->save_pixmap) return 0;                    /* unexposed: nothing to draw into */
if(xctx->top_path && xctx->top_path[0]) return 1;   /* detached window: its own canvas */
return !strcmp(wp, get_drw_front_win());            /* tab: only when it is the front tab */
```

Without the front‑of‑`.drw` arm, syncing a highlight *up* into the main window
(the usual parent) would update the table but skip the `draw()`, leaving the
buried‑net cue invisible until an unrelated expose repainted it — a real bug that
was fixed by exactly this discriminator.

Finally, the sync is skipped whenever the focused window is mid rubber‑band
gesture (`net_hilight_ctx_gesturing()`, `src/hilight.c:2988`, tests
`ui_state & HILIGHT_ANIM_BUSY`) — because borrowing another context would swap the
global `xctx` out from under an in‑flight draw. That predicate deliberately
excludes the passive `semaphore` (raised by, say, a modal dialog), which must not
freeze other windows' animation.

### 4.4 The headless constraint (it matters for §9)

Creating a second window requires a real Tk toplevel: in `create_new_window`
(`src/xinit.c:1813`) the toplevel, canvas, graphics contexts, and backing pixmap
are all created inside `if(has_x)` blocks, and `--nogui`/`--no_x` set `has_x = 0`.
Moreover the entire sync driver is X‑gated at its very top
(`net_hilight_sync_descend_windows` opens with `if(!has_x) return`,
`src/hilight.c:3606`). So a headless run *can* allocate a second `Xschem_ctx`, but
it has no window, no pixmap, and the whole cross‑window path is short‑circuited.
§9 returns to this at length.

---

## 5. Descending into a new window: the plumbing behind the linked secondary

When you descend into an instance *in a new window*, XSCHEM does **not** open the
instance's schematic directly. Understanding why is the key to the whole story.

### 5.1 The choreography

The user‑facing entry is `hi_descend_newwin` (`src/xschem.tcl:5701`); its simpler
twin `open_sub_schematic` (`src/xschem.tcl:5457`) performs the same dance and is
easier to read:

1. Capture the source window's unsaved edits, so an in‑progress edit survives.
2. **Deselect everything** — `xschem unselect_all`. Load‑bearing; see §5.3.
3. **Open the *parent* schematic in a new window** —
   `xschem schematic_in_new_window force window`. Note the subject: the schematic
   the source window is *currently showing*, not the instance's schematic.
4. Learn the new window's path (`xschem get last_created_window`, guarded so a
   failed open cannot be mistaken for success).
5. **Copy the hierarchy stack** — `xschem copy_hierarchy` (backed by
   `copy_hierarchy_data`, `src/actions.c:2614`, which copies `sch[]`, `sch_path[]`,
   `sch_inst_number[]`, `previous_instance[]`, zoom, and portmap).
6. **Copy the highlight table** — `xschem copy_hilights`.
7. Make the new window current; restore the carried‑over edits.
8. **Re‑select the target instance and descend** — a real in‑window `xschem
   descend`.

So the secondary window is born showing the *parent*, is handed the parent's
descent stack and highlight table, and is then driven through a genuine descend
into the target instance — arriving at exactly the hierarchy path (`.x1.`) it
would have reached in place, but in its own window.

### 5.2 Why open the parent and re‑descend?

Because a child schematic opened cold has no hierarchy context: it sits at
`currsch == 0` with an empty path and does not know it is "instance `x1` inside the
top cell." By opening the parent, copying the parent's stack, and performing a real
descend, the child window inherits a correct, fully‑populated hierarchy path, which
netlisting, node naming, and highlight translation all depend on.

### 5.3 The one‑time highlight transfer, and why a later sync was needed

The highlight transfer happens exactly once, in two halves. `copy_hilights()`
(`src/hilight.c:223`) deep‑copies every entry of the source window's table
verbatim (no path translation) and sets `hilight_nets = 1`. The descend itself then
translates parent‑side highlights down onto the child's pins via
`hilight_child_pins()` (which bails immediately unless `hilight_nets` is set — the
reason `copy_hilights` sets that flag).

This transfer is **strictly one‑and‑done.** Nothing re‑runs when the parent's
highlights change afterward; the in‑code comment says so plainly
(`src/hilight.c:3156`: "a highlight applied to the parent AFTERWARDS never reaches
the child"). Before issue 0073, a highlight applied in the parent after the
descend left the child dark. The fix (§6) added a standing fan‑out,
`net_hilight_sync_descend_windows()`, fired on every highlight mutation.

### 5.4 The `lastsel` gotcha, and the Tcl link versus structural matching

Step 2's deselect is not cosmetic. The C core `schematic_in_new_window`
(`src/actions.c:2693`) branches on the selection count: `lastsel == 0` opens the
current (parent) schematic (the branch the flow depends on); `lastsel == 1`
resolves the *selected instance's own* schematic and opens that directly. If the
target were left selected, the wrong branch would fire and the subsequent descend
would find no matching instance — a desynced window.

`hi_descend_newwin` also records `::descend_parent_win` / `::descend_entry_level`,
a Tcl‑only association used solely by the Cadence Ctrl‑E/Alt‑E *return navigation*
(issue 0053). **The C highlight sync never consults it.** It re‑derives the
parent↔child relationship *structurally*, by comparing the `sch_path[]`/`sch[]`
stacks of the open windows — which is what lets the sync work even for a window
the Tcl link never recorded, and is why the analysis below talks only about paths
and stacks.

---

## 6. The cross‑window synchronisation engine

### 6.1 One entry point, three passes

Every highlight change funnels through `net_hilight_sync_descend_windows()`
(`src/hilight.c:3602`). It first bails cheaply in three cases — no X display,
inside a suspended bulk batch, or mid rubber‑band gesture — then takes the changed
window as *source*, clears the per‑pass `nh_sync_visited[]` bookkeeping, and runs
three passes in a fixed order (`src/hilight.c:3610`):

1. `net_hilight_sync_children_rec(0)` — push the change **down** into linked
   windows exactly one level below.
2. `net_hilight_sync_parents_rec(0)` — push it **up** into a linked window exactly
   one level above.
3. `net_hilight_sync_orphans(src)` — mop up any linked window **more than one
   level away** that the first two passes could not reach.

It finishes by re‑running `net_hilight_anim_update()`, because the caller's own
animation re‑arm ran earlier, while the child tables were still empty.

### 6.2 Why "exactly one level away" gets the precise treatment

The two `±1` passes perform a genuine, pin‑accurate re‑translation of the highlight
across the hierarchy boundary. `net_hilight_sync_children_rec` (`src/hilight.c:3344`)
accepts a window `C` only if `C->currsch == src->currsch + 1` (`:3365`), its path is
the source's path plus exactly one trailing component, and — crucially — the source
currently shows the child's *parent* schematic (`:3378`). When those hold,
`net_hilight_sync_one_child` (`src/hilight.c:3275`) rebuilds the child's table
exactly, because everything it needs lives in the single loaded source context: the
descended instance's `node[]` map and the symbol's pin names. It walks each
highlighted parent pin, maps it to the child‑side net bit (the §3.1 formula), and
re‑inserts it at the child level. `net_hilight_sync_parents_rec` (`src/hilight.c:3509`)
is the mirror image, with an extra `if(src->currsch <= 0) return;` guard (`:3517`)
because the top level has no parent window above it. Both recurse, so a fully‑open
descend chain relays precisely, level by level, marking each window it touches in
`nh_sync_visited[]` so the mop‑up leaves it alone.

The precision is only possible at a one‑level step because the translation needs
the netlist that *contains the instance*. For a single hop, that netlist is loaded
in the source (or the borrowed parent). For a two‑hop gap with nothing loaded in
between, the middle netlist is loaded nowhere, and the pin‑to‑net‑to‑pin chain has
a missing link.

### 6.3 Reconciliation, not patching

Each `±1` sync **rebuilds the target from scratch**: `clear_all_hilights()`, copy
the source table verbatim (carrying the parent's own ancestor‑level entries), add
the translated crossed‑depth entries, `propagate_hilights`. This is the opposite of
the additive single‑window ascend (§3.2), and the payoff is that clear‑through is
free and the result is idempotent: un‑highlight in the source and the rebuild
simply does not re‑create the entry — there is no special delete path to get wrong.

### 6.4 The orphan mop‑up and its deliberate one‑way behaviour

When a linked window is more than one level from the source with no intermediate
window to bridge the gap, it never satisfies the `±1` test and falls to
`net_hilight_sync_orphans` (`src/hilight.c:3568`). That pass pairs the source with
any window that is `net_hilight_prefix_related` (`src/hilight.c:3234`) — different
depth, one current path a component‑aligned prefix of the other, same schematic at
the shared shallower level — and hands it to `net_hilight_reconcile_verbatim`
(`src/hilight.c:3258`).

The reconcile does something deliberately lopsided (`src/hilight.c:3262`): it
borrows the target, computes `tp` as the *target's own current‑level path*,
unconditionally calls `clear_all_hilights()`, then repopulates with
`net_hilight_copy_table_from(src, tp)`. That copy applies an **ancestor‑or‑self
filter** whose heart is one line (`src/hilight.c:3193`):

```c
if(!e->path || plen > tplen || strncmp(tp, e->path, plen)) continue;
```

Any source entry whose path is *deeper* than the target's level (`plen > tplen`)
is dropped; an entry at the target's level or shallower survives only if it is a
component‑aligned prefix of `tp`. The consequence is the whole point:

- **Clearing propagates across any depth** — the `clear_all_hilights()` is
  unconditional, so an emptied source empties the target no matter how far apart.
- **Populating never crosses the untranslatable gap** — the deep leaf entry that
  would need re‑translation is simply dropped.

This is not a bug; it is the design choice recorded in issue 0073 §9c, and §7 and
§8 explain exactly why the alternative (copying the deep entry) would produce a
*wrong* answer.

### 6.5 Batching, borrowing, and drawing

Two supporting mechanisms complete the engine. A **suspend/resume bracket** lets a
bulk operation collapse many syncs into one: `net_hilight_sync_suspend()`
increments a counter, `net_hilight_sync_resume()` decrements it and fires exactly
one sync at zero, and the dispatch early‑returns while the counter is positive
(`src/hilight.c:3589`). Because it is a counter, nested brackets compose; the Tcl
proc `net_hilight_apply` uses it around a whole‑bus apply loop, inside a `catch` so
a bad net name still resumes. Second, every helper reaches another window through
`net_hilight_borrow_ctx` (§4.2), and every `draw()` it issues is gated by
`net_hilight_ctx_visible` (§4.3), which repaints only a window that owns a pixmap
and is actually on screen.

---

## 7. The reported bug, traced line by line

> **Note.** This section traces the behaviour of the orphan mop-up *before* the §10
> relay fix — it is the mechanism of the reported bug, kept because it is the
> clearest way to understand the engine. With the relay in place (§10), the
> populate cases below now succeed; the clear cases are unchanged. Read this to
> understand *why* the gap was hard, then §10 for how it is bridged.

Now the payoff. Set up the reported topology precisely:

- **Primary window P** is the main window on the shared `.drw` canvas:
  `sch_path = ["."]`, `currsch = 0`, empty `top_path`, window path `.drw`.
- **Secondary window S** was opened by descending into `x1` with New Window, then
  descending *in place* into `x4`. It is a detached window with
  `sch_path = [".", ".x1.", ".x1.x4."]`, `currsch = 2`, its own canvas.
- **No window is loaded at the intermediate `.x1.` level.**

The two windows are `net_hilight_prefix_related`: different depths (0 vs 2), `.` is
a prefix of `.x1.x4.`, and they share the same top schematic. So any change in one
*always* reaches the other's mop‑up pass — but only the mop‑up, never the precise
`±1` relay. (This trace was independently verified against current source.)

**Action 1 — highlight a deep net in S** (e.g. `x4`'s internal `OUT`, which
surfaces up to a top net). Source is S at `currsch = 2`.
`children_rec` looks for a window at `currsch = 3`: none. `parents_rec` looks for a
window at `currsch = 1`: P is at 0, so `P->currsch != Ccurr - 1` skips it — the
level that *would* match (the unloaded `.x1.`) exists in no window. The pair falls
to `sync_orphans`, which reconciles P against S with `tp = P.sch_path[0] = "."`.
S's new entry has path `.x1.x4.` (length 7) versus `tp` length 1; the filter's
`plen > tplen` is `7 > 1`, true, so the entry is **dropped**. Nothing is added to
P's table. → **The primary does not light.**

**Action 2 — press `0` (unhighlight‑all) in P.** `unhilight_all`
(`src/scheduler.c:9029`) clears P's already‑empty table, then syncs with source P.
`children_rec` finds nothing; `parents_rec` returns immediately because
`P.currsch == 0`. The mop‑up reconciles P with S using `tp = S.sch_path[2] =
".x1.x4."`. `clear_all_hilights()` runs on S and **wipes the deep highlight**; the
copy from the now‑empty P adds nothing; S is a detached window with its own pixmap,
so `net_hilight_ctx_visible` is true and it repaints. → **The secondary clears.**
The clear crossed the gap because it depends on translating nothing.

**Action 3 — the reverse: highlight a net in P that connects down into S.** Source
is P at `.`. `children_rec` and `parents_rec` again find nothing. The mop‑up
reconciles S with `tp = ".x1.x4."`. P's entry has path `.` (length 1) versus `tp`
length 7; the filter test is `plen(1) > tplen(7)` → false, and
`strncmp(".x1.x4.", ".", 1) == 0` → the entry is **kept** and copied verbatim into
S at path `.`. But it lands at path `.` while S's current view is `.x1.x4.`;
`propagate_hilights` only colours nets at the current level, and an entry at `.` is
neither at S's level nor buried below it, so it lights nothing and paints no cue. →
**The secondary does not visibly light.**

> Note the mechanisms differ, even though both "look like" a highlight failing to
> appear. Up‑direction (Action 1): the deep leaf is *dropped* by the `plen > tplen`
> filter. Down‑direction (Action 3): the ancestor entry is *kept but inert* at the
> deep level. Both fail to populate, for symmetric reasons.

**Action 4 — press `0` in S.** Source S clears; `children_rec`/`parents_rec` find
nothing; the mop‑up reconciles P with `tp = "."`, `clear_all_hilights()` wipes P's
entry, the empty copy adds nothing, and P (front `.drw`) repaints. → **The primary
clears.**

In every case the symptom follows from the same asymmetry: **clearing is an
unconditional wipe that survives any depth, while populating across a two‑level gap
with no intermediate netlist is either dropped or copied‑but‑inert.** The exact
fix — re‑deriving the cross‑level net — is documented as deferred (issue 0073 §9,
"Still deferred after 9c") because it requires loading the intermediate `.x1.`
netlist to translate `x4`‑pin ↔ `x1`‑pin ↔ top‑net. §10 sketches it.

### 7.1 The governing principle: stale > missing > wrong

The design ranks failure modes. A **stale** highlight (one that should be gone but
lingers) actively lies about the circuit; a **missing** highlight (one that should
be lit but isn't) is a mild disappointment; a **wrong** signal (a highlight or cue
asserting something false) is worst of all, because the user trusts it. So:

- Clearing, which needs no translation, is guaranteed *unconditionally at any
  depth* — never leave stale state.
- Populating, which needs translation the shallow window cannot compute across the
  gap, is best‑effort — and where it cannot be computed, the engine shows
  **nothing** rather than guess. §8 shows what "guessing" would look like and why
  it is worse than missing.

---

## 8. The buried cue meets linked windows — why the filter exists

§6.4's ancestor‑or‑self filter looks over‑cautious until you see what a verbatim
copy would do to the buried cue.

Recall (§3.5) that `compute_buried_hilights` paints a "buried" rectangle on an
ancestor instance whenever any table entry sits at a path strictly deeper than the
current level under that instance, *and* the net does not surface to a pin. Now
suppose the orphan mop‑up blindly copied the deep entry `(.x1.x4., OUT)` up into
the shallow primary. `compute_buried_hilights` would see a highlighted path deeper
than `.` under `x1`, find no pin exposure (because the shallow window *cannot*
compute the pin translation without `x1`'s netlist), and slap a "buried" rectangle
on `x1`.

But `OUT` is *not* buried — it **surfaces**, connecting up to a real net `CTRL1`
at the top. The correct behaviour is to light `CTRL1`, not to box the instance.
The shallow window cannot tell the surfacing case from the truly‑buried case
without the intermediate netlist, so the rectangle would be a **confident lie, and
the only signal shown** (since the real net cannot be lit). That is strictly worse
than showing nothing. This is precisely the `stale > missing > wrong` ranking in
action: the filter drops the deep entry so the far window shows *nothing* (missing)
rather than a false cue (wrong).

The asymmetry between the two sync paths is deliberate and instructive. The **±1
path** copies the source table *verbatim* — deep entries included — *and* adds the
genuinely translated child‑level nets (`src/hilight.c:3328-3330`). That is safe
precisely because the intermediate netlist *is* the loaded source: the real
surfacing net is reproduced at the child's own level alongside any deep entry, so
if the net surfaces the pin‑exposure test suppresses the cue, and if it is truly
buried the cue is correct. The deep entry never rides *alone*. The **orphan path**
cannot supply that companion net, so it must drop the deep entry entirely. Same
mechanism, opposite decision, because one context can validate the cue and the
other cannot.

The lesson for any future fix (§10): copying deep entries into a shallow window is
safe **only when accompanied by the correctly‑translated shallow net.** A fix that
translates across the gap must inject the translated net in the *same* reconcile as
any deep copy, or it re‑introduces the false cue.

---

## 9. Testing without the GUI

The reflexive verdict on a visual, multi‑window, animated feature is "untestable,
eyeball it." That verdict is wrong, and avoiding it is the most transferable lesson
here: **the hard part of this feature is not the windows, it is the arithmetic —
and the arithmetic is pure.**

### 9.1 Correctness as data, and a free oracle

The keystone is that highlights are *a table you can print*. `xschem
display_hilights` (`src/scheduler.c:1337`) serialises the current window's table to
a Tcl list of `{path+token}` groups — e.g. `{FOO}`, `{xi.FOO}` — and `xschem
list_hilights all` (`src/hilight.c:3912`) dumps the full `path token value` table
including cross‑level entries. So "the windows agree" becomes a *string equality*,
not a screenshot.

Where does the *expected* data come from? From the **single‑window** version of the
same operation. Highlight a net inside `xi`, `go_back`, dump the table: `{FOO}
{xi.FOO}`. That is the **oracle** — the byte‑for‑byte target the cross‑window path
must reproduce, and it was not invented but *derived* from a path already known
correct. This is metamorphic/differential testing: two routes (single‑window
ascend vs two‑window sync) must yield identical output, and one is the reference for
the other. The bit‑index formula that does the translation is identical in the
single‑window translators and the sync helpers (§3.1), which is exactly why the
single‑context oracle is a valid ground truth for the multi‑window path.

### 9.2 The headless wall, precisely

There is one blunt obstacle. `net_hilight_sync_descend_windows()` opens with
`if(!has_x) return;` (`src/hilight.c:3606`), and `--nogui` sets `has_x = 0`. So
under `--nogui` the *entire* cross‑window engine is dead code — a naive headless
"sync" test would pass vacuously because nothing runs. And creating a real second
window is itself `has_x`‑gated (§4.4). But — importantly — everything *below* that
outer guard is display‑independent: borrowing is a pointer swap; clearing, copying,
and propagating touch no Tk; and the one `draw()` per helper is *already*
independently gated by `net_hilight_ctx_visible`, which returns false with no
pixmap (always the case headless). The guard is a coarse early‑out, not a
structural dependency. Relax it for a test and the table logic runs while drawing
quietly skips itself. That distinction is what makes the tiers below possible.

### 9.3 Four tiers, cheapest to strongest

**Tier A — the single‑window oracle (zero new code).** Load the top, descend into
the target instance in place, descend again into the deep instance, highlight the
net, then climb back with `go_back`, dumping `display_hilights`/`list_hilights all`
at each level. Because the sync byte‑matches this, the tables you capture *are* the
spec. This runs fully under `--nogui` today — exactly the shape of the existing
`tests/buried_hilight.tcl`. It locks down the translation arithmetic (bus indices,
inst_number slices, buried‑vs‑surfaced classification) with no window at all.

**Tier B — dump the representation, replay the mapping offline (the user's
suggestion).** Serialise, for the current context, precisely what the sync
consumes: the path stack and `sch_inst_number` at each level; for each instance its
name and, per pin, the pin name plus the raw and expanded `node[]` string; and the
full highlight table. Strikingly, *almost all of this is already reachable* through
existing headless introspection — `instance_nodemap`, `getprop instance_pin`,
`list_hilights all`, `get sch_path`, `get currsch` — so the dump can be a thin Tcl
helper (or a small `xschem dump_hier_rep <file>` for cleanliness; the one field
with no getter today is `sch_inst_number`). Then a pure offline checker loads the
three dumps (top, mid, deep) and *replays* the two engine rules: the one‑level
relay (copy the neighbour's table, then map the shared instance's pins across using
the dumped pin/node data) and the deep‑gap reconcile (the ancestor‑or‑self filter
that drops any entry deeper than the target level). With **no windows**, this
asserts the property the whole issue turns on: a highlight two levels down does not
populate the top across an unbridged gap, whereas an emptied source does clear it.
It is the §7 boundary, tested as arithmetic — the highest value for the lowest risk.

**Tier C — run the real engine against two logical contexts (one small seam).**
Because the sync core is display‑independent, a single test‑only flag that bypasses
the outer `!has_x` guard — modelled exactly on the existing `net_hilight_test_now`
flag, which already forces a normally‑GUI‑only path for tests — lets the genuine
`net_hilight_sync_descend_windows()` run headless. Paired with a headless second
context (either the existing new‑window path under `--nogui`, whose Tk work is all
guarded while its context allocation and schematic load are not, or a dedicated
`test_new_logical_ctx` seam that allocates a `save_xctx` slot, loads a file, and
descends to a chosen path without a widget), this exercises the actual
`sync_children_rec` / `sync_parents_rec` / `sync_orphans` code — the real product
logic minus the pixels.

**Tier D — keep the GUI test, narrow its remit.** Three things stay legitimately
display‑bound in `tests/hilight_xwin_sync.tcl`: real toplevel/canvas/GC creation,
the Tk `after`‑loop animation tick verified with `vwait`, and actual painted pixels
(the front‑tab‑vs‑background‑tab visibility that only exists once a canvas is
mapped). Each *wraps* correctness the headless tiers already cover at the table
level, so the right split is to move the translation math, the deep‑gap boundary,
and (with the Tier‑C seam) the engine itself into the fast headless suite, and keep
only the integration surface in the GUI test.

### 9.4 What the existing tests already prove

`tests/buried_hilight.tcl` runs fully headless (four‑level fixture `A > x_b > x_c >
x_d`, an internal `lab_pin` net, asserting each ancestor's `hilight_buried` style).
`tests/hilight_xwin_sync.tcl` (35 checks) runs headful with a `DISPLAY`, drives the
real descend‑new‑window path, and — the sharpest part — encodes the deep‑gap
*boundary* as passing assertions: a deep highlight must **not** populate the
primary (line ~141), yet clearing the primary must **still** clear the deep
secondary (line ~146). That populate‑fails‑but‑clear‑works pair is exactly the
reported behaviour, enforced by the ancestor‑or‑self filter. Encoding the *limit*
of the feature as a green test turns "we'll do deep sync later" from a note into a
red line the suite defends: the day someone implements §10, that first assertion
flips on purpose.

---

## 10. The fix (implemented)

> **Status: implemented** on `fluid-editing` — `net_hilight_relay_reconcile()` in
> `src/hilight.c`, wired into `net_hilight_sync_orphans()`. The reported scenario
> now works: a surfacing deep net lights the real net in the far window, and a
> genuinely buried deep net shows a *validated* buried cue instead of nothing;
> clear-through is unchanged. Regression: `tests/hilight_xwin_sync.tcl` (44 checks,
> including a surfacing-net case and a relay-off sabotage guard). What follows is
> the design as built.

The one thing that makes the gap untranslatable is a missing schematic — and that
schematic's filename is *not* missing: it sits in the orphan window's own descent
stack (`C->sch[currsch-1]` names the intermediate cell, reachable via
`get_window_ctx`). So the gap is bridgeable; the fix is to load the one schematic
nobody has open and run one more hop of the translation the engine already performs
everywhere else.

The recommended approach — a **transient intermediate‑netlist relay** — walks the
gap one level at a time: read the crossed instance's `node[]` and pin names to map
the working set of nets across a boundary (the §3.1 hop), loading each intermediate
schematic into a *scratch context* (allocated the way the symbol‑preview window is,
but never drawn) for the hops where the needed netlist is loaded in no window. After
the last hop the working set is at the far window's own level, and the target is
reconciled exactly as the one‑hop path does. For the reported two‑level topology the
relay loads exactly one schematic.

The subtle payoff is that this **resolves** the buried‑vs‑surfacing hazard of §8
rather than reviving it: loading the intermediate netlist *is* the computation that
decides whether a deep net surfaces. If it surfaces, the relay yields the real
shallow net (`CTRL1`) and the pin‑exposure test suppresses the cue; if it is truly
buried, the deep entry stands alone and the cue is correct. So the relay can safely
copy deep entries verbatim *and* add the translated shallow net, byte‑matching what
a fully‑open descend chain would show.

Two other approaches were evaluated and rejected: **reusing `drill_hilight`** (its
premise is false — drill is horizontal and off by default, §3.4, so no deep entry
exists to copy), and **piggybacking the SPICE netlister's hierarchy walk** (it
traverses by unique subcircuit *type*, not by instance path, and builds no
per‑path node table to query — though its transient `load_schematic` + `pop_undo`
mechanism is a reusable primitive). The full ranked roadmap, the exact wire‑up
point (inside `net_hilight_sync_orphans`, no new hook sites), the scratch‑context
lifecycle, the risks (keeping `xctx` balanced; verifying `load_schematic` in a
windowless context; a graceful fallback to today's clear‑through behaviour when an
intermediate cannot be loaded), and the effort estimate are in the companion
agent guide.

---

## Appendix A — Map of the code

| Concept | Symbol | File:line |
|---|---|---|
| Highlight record | `struct hilight_hashentry` (`token`,`path`,`value`,`seq`,…) | `src/xschem.h:871` |
| Per‑window table | `hilight_table[HASHSIZE]` (`HASHSIZE`=31627) | `src/xschem.h:1201`,`:316` |
| Composite‑key hash / lookup | `hi_hash`, `hilight_hash_lookup`, `bus_hilight_hash_lookup` | `src/hilight.c:25`,`:81`,`:161` |
| Reset / query | `clear_all_hilights`, `there_are_hilights` | `src/hilight.c:896`,`:290` |
| Descend translation (down) | `hilight_child_pins` | `src/hilight.c:1036` |
| Ascend translation (up, additive) | `hilight_parent_pins` | `src/hilight.c:956` |
| Finalizer | `propagate_hilights` | `src/hilight.c:1874` |
| Same‑level pass‑through (NOT hierarchy) | `drill_hilight` (gated `enable_drill`, default 0) | `src/hilight.c:1443` |
| Buried‑net cue detect / field / draw | `compute_buried_hilights`, `xInstance.buried_hilight`, draw loop | `src/hilight.c:1831`; `src/xschem.h:684`; `src/hilight.c:3773` |
| Buried‑cue birth stamp | `inst_register` (`buried_hilight = -1`) | `src/store.c:543` |
| Context array + invariant | `save_xctx[]`, `get_window_ctx` | `src/xinit.c:41`,`:138` |
| Borrow / restore (ambient ctx) | `net_hilight_borrow_ctx` / `net_hilight_restore_ctx` | `src/hilight.c:2922`,`:2952` |
| Visibility discriminator | `net_hilight_ctx_visible`, `drw_front_win`/`get_drw_front_win` | `src/hilight.c:3217`; `src/xinit.c:51`,`:210` |
| Gesture guard | `net_hilight_ctx_gesturing` | `src/hilight.c:2988` |
| Descend‑new‑window plumbing | `hi_descend_newwin`, `open_sub_schematic`, `copy_hilights`, `copy_hierarchy_data` | `src/xschem.tcl:5701`,`:5457`; `src/hilight.c:223`; `src/actions.c:2614` |
| Sync dispatch | `net_hilight_sync_descend_windows` | `src/hilight.c:3602` |
| ±1 relay (down / up) | `net_hilight_sync_children_rec` / `_parents_rec`; `_one_child` / `_one_parent` | `src/hilight.c:3344`/`3509`; `3275`/`3408` |
| Orphan mop‑up | `net_hilight_sync_orphans`, `net_hilight_reconcile_verbatim`, `net_hilight_prefix_related` | `src/hilight.c:3568`,`:3258`,`:3234` |
| The decisive filter | `net_hilight_copy_table_from(src, tp)` — ancestor‑or‑self drop | `src/hilight.c:3183` (test at `:3193`) |
| Batch bracket | `net_hilight_sync_suspend` / `_resume` | `src/hilight.c:3589` |
| Navigation hooks | end of `descend_schematic` / `go_back` | `src/actions.c:3560`,`:3667` |
| Test oracle / seams | `display_hilights`, `list_hilights all`, `hilight_buried` | `src/scheduler.c:1337`; `src/hilight.c:3912`; `src/scheduler.c:3289` |
| Regression tests | `tests/hilight_xwin_sync.tcl` (GUI), `tests/buried_hilight.tcl` (headless) | `tests/` |

## Appendix B — A note on two stale prior‑doc claims (verified against source)

- Issue 0073 §9c prose names a function `net_hilight_copy_table_ancestor`; that
  symbol **does not exist** in current source. The shipped code merged it into
  `net_hilight_copy_table_from(src, tp)` with a nullable `tp` (verbatim when
  `NULL`, ancestor‑or‑self when non‑NULL). The issue's own "files touched" section
  already matches the merged signature; only the §9c prose name is stale.
- The `compute_buried_hilights` docblock (`src/hilight.c:1822`) and
  `doc/claude/specs/buried_net_hilight.md` §4.2 say the buried cue shows the
  *lowest* style index among several; the shipped code (`src/hilight.c:1861`) and
  the field comment (`src/xschem.h:882`) implement *most‑recently‑applied* (max
  `seq`). Spec §8.2 is the correct description.
