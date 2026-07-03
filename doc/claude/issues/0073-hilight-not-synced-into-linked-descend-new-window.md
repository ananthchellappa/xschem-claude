# Issue 0073 — A net highlighted in a parent window does not appear in a linked descend-NEW-WINDOW child (highlights sync only ONCE, at descend time)

**Opened:** 2026-07-02
**Status:** FIXED (bidirectional: parent→child AND child→parent, static + animated) 2026-07-02..03,
uncommitted on `fluid-editing`. Deep in-place descents >1 level inside a child remain deferred — see §9.
Child→parent (ascend) implemented 2026-07-03 — see §9.
**Severity:** MEDIUM — the two windows are advertised as *linked* (descend chain, issue 0053) but the
highlight state is not kept in sync; a probe applied in one window is invisible in the other, breaking
the Cadence-style "trace a net across the hierarchy in a second window" flow.
**Branch:** `fluid-editing`.
**Source:** user report.
**Affects:** `src/hilight.c` (highlight apply/propagate + the existing cross-window helpers
`net_hilight_borrow_ctx` / `net_hilight_redraw_other_windows`), the apply chokepoints in
`src/scheduler.c` (`hilight_netname`, `hilight`, `unhilight*`), and the descend-new-window plumbing in
`src/xschem.tcl` (`hi_descend_newwin` ~:5694, `open_sub_schematic` ~:5450, which call
`xschem copy_hilights` exactly once).
Related: [[net-hilight-styles]] (multi-window *animation/redraw* of already-set highlights),
[[buried-net-hilight]], issue 0053 (the parent↔child window link this relies on),
[[descend-newwin-return-chain]], [[multi-window-detach]].
**Teaching write-up:** `doc/claude/code_analysis/hilight_multiwindow_sync_tutorial.md` — the CS patterns
behind this feature (ambient context, reconciliation, duality, sentinel aliasing, observer completeness)
and how to build/test such a feature test-driven, plus how WSLg flakiness shaped it.

---

## 1. Report (user, exact scenario)

1. Run `src/xschem --script src/cadence_style_rc --logdir /tmp`.
2. Open `xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch`
   (via Library Manager) → the **primary** window. It has instance `x1` of `SANDBOX/solar_ctl`
   (whose schematic contains `x3`, `x4`).
3. Descend into `x1` with **E → New Window** → a **secondary** window opens showing `solar_ctl`.
   The two windows are *linked* (descend chain).
4. Highlight net **CTRL1** in the **primary** window. It highlights there.
5. **Bug:** the highlight does **not** appear in the secondary (descended) window.

## 2. Reproduced (headless, DISPLAY=:0)

Driving the exact descend-new-window path (`schematic_in_new_window force window` → `copy_hierarchy`
→ `copy_hilights` → switch → `select instance x1` → `descend`), then highlighting CTRL1 in the parent
and dumping each window's highlight table with `xschem display_hilights`:

```
CHILD (.x1., solar_ctl) hilights right after descend       = ''         (nothing highlighted yet — OK)
PARENT hilight_netname CTRL1 -> 1
PARENT (top) hilights                                       = '{CTRL1}'
CHILD (.x1., solar_ctl) hilights AFTER parent highlight     = ''         <-- BUG: still empty
```

**Ground truth for what the child SHOULD show.** Do the same in a *single* window — highlight CTRL1 at
top, *then* descend into `x1`:

```
TOP hilights                          = '{CTRL1}'
INSIDE x1 (.x1.) hilights             = '{CTRL1} {x1.CTRL1}'
```

The `{x1.CTRL1}` entry (path `.x1.`, the internal net of `solar_ctl` reached through `x1`'s pin) is
created by `hilight_child_pins()` during descend, using `x1`'s pin **names** — it does **not** require
the child schematic to be loaded. That entry is exactly what lights the internal net in the descended
view, and it is the entry the linked secondary window is missing.

## 3. Root cause

Highlights are stored **per window context** (`xctx->hilight_table[HASHSIZE]`, keyed by full hierarchy
`path` + net `token`). Each open window/tab is an independent `Xschem_ctx` in `save_xctx[]`.

The parent↔child highlight relationship is established **once**, at descend time:

- `hi_descend_newwin` / `open_sub_schematic` (xschem.tcl) call `xschem copy_hilights` a single time,
  right after creating the child window. `copy_hilights()` (`hilight.c:223`) copies the *whole* parent
  table into the child, and the subsequent `xschem descend` runs `hilight_child_pins()` +
  `propagate_hilights()` to materialize the child-level entries.

After that there is **no ongoing sync**:

- Applying a highlight (`hilight_netname`, `hilight`, cursor keys) mutates **only the current
  window's** `hilight_table` and calls `propagate_hilights()` on the current `xctx` only
  (`hilight.c:1873` — no cross-window awareness).
- The existing cross-window helper `net_hilight_redraw_other_windows()` (`hilight.c:3130`) only
  **redraws** other windows from *their own* tables (added for live style edits — see
  [[net-hilight-styles]]); it does not copy or propagate *new* highlight entries into them.
- The parent↔child link (`::descend_parent_win`, `::descend_entry_level`, xschem.tcl:5745-46) lives
  **only in Tcl**; there is no C-level `xctx` cross-reference and nothing consults it on a highlight
  change.

So a highlight applied to the parent *after* the child window exists never reaches the child's table,
and the child stays blank. (Symmetrically, a highlight applied in the child never reaches the parent.)

## 4. Why this is subtly non-trivial

The two linked windows sit at **different hierarchy levels**, so their correct tables differ: parent
at top needs `{.,CTRL1}`; child at `.x1.` needs `{.,CTRL1}` **and** `{.x1.,CTRL1}`. A plain
`copy_hilights` (verbatim whole-table copy) is therefore **not** sufficient to light the child's
internal net — the per-level pin-name translation (`hilight_child_pins`, ascend: `hilight_parent_pins`)
that `descend`/`go_back` run is what creates the extra-level entries.

Key facts that make a fix tractable:
- The one-level *down* translation (parent net → child pin-net) is computable **entirely from the
  parent window's context** (`x1.node[]` + `x1`'s symbol pin names); the child schematic need not be
  loaded (that is how `hilight_child_pins` already works mid-descend).
- The child window carries the **full copied hierarchy stack** (`sch_path[]`, `previous_instance[]`,
  `sch_inst_number[]`) via `copy_hierarchy_data()`, so it knows its own path relative to the parent.
- Intermediate levels between two windows more than one level apart are not loaded in either window —
  arbitrary-depth reconstruction is the hard case; depth-1 (the reported topology) is clean.

## 5. Scope questions to resolve in the plan

- **Direction:** parent→child only (the report), or symmetric (child→parent too)? The machinery is
  symmetric (`hilight_child_pins` / `hilight_parent_pins`), so bidirectional is natural.
- **Depth:** only windows exactly one level apart through a known instance (clean, covers the report),
  or arbitrary-depth descendants (needs a relay/replay design because intermediate netlists are not
  loaded)?
- **Which windows:** only descend-chain-linked windows (`::descend_parent_win`), or every open window
  showing the same design hierarchy?
- **Operations to hook:** every highlight mutation (`hilight_netname`, `hilight`, `unhilight`,
  `unhilight_all`, cursor-9/8/0, waveform-driven) so set *and* clear both sync.

## 6. Acceptance (draft)

1. In the reproduced scenario, after `PARENT hilight_netname CTRL1`, the linked child window at `.x1.`
   shows highlight table `{x1.CTRL1}` (matching the single-window ground truth) and repaints the
   internal net highlighted — without any user interaction in the child.
2. Un-highlighting (`unhilight` / `unhilight_all`) in the parent clears the child too.
3. Non-linked windows and single-window highlight/descend behavior are unchanged.
4. (If bidirectional is chosen) a highlight applied in the child appears in the parent per the
   single-window ascend ground truth.

## 7. Fix as implemented (2026-07-02, parent→child)

New C helper `net_hilight_sync_descend_windows()` (`hilight.c`), called after every current-window
highlight set/clear (7 sites: `hilight_netname`, `hilight_net_styled`, `unhilight_net` in hilight.c;
`hilight`, `hilight_instname`, waveform, `unhilight_all` in scheduler.c). It walks all open windows;
for each that sits **exactly one hierarchy level below** the changed (source) window through a
subcircuit instance (matched via the shared `sch_path[]`/`sch[]` stack + instance name, no reliance on
the Tcl link), it:
1. computes the child-level highlighted pin nets from the SOURCE context — `inst.node[]` + the symbol
   pin names, the same translation `hilight_child_pins()` uses, so the child schematic need not be
   reloaded (`net_hilight_sync_one_child`, phase A);
2. borrows the child (`net_hilight_borrow_ctx`), clears + re-copies the source table
   (`net_hilight_copy_table_from`), injects the child-level entries, runs `propagate_hilights()`, and
   redraws under the same guards as `net_hilight_redraw_other_windows` (skip background tab / unexposed
   / mid-gesture);
3. recurses so a consecutive-level descend-window chain updates from one change.

**Verified:** child table becomes `{FOO x1.FOO}`, byte-matching the single-window "highlight then
descend" ground truth; clear-through and net-swap tracked; sabotage (neuter the sync) → child stays
empty. Regression suite clean. Test: `tests/hilight_xwin_sync.tcl` + fixture
`tests/hilight_xwin_sync/` (GUI: `cd tests && DISPLAY=:0 ../src/xschem -q --script hilight_xwin_sync.tcl`).

**Deferred (v1 limitations):** *(child→parent now implemented, §9)*
- **Deep in-place descent inside a child:** sync only follows *consecutive* one-level window hops; if a
  child window descends further in place so it is >1 level below its linked parent, the intermediate
  level's netlist is loaded in no window and that gap is not bridged.

## 8. Animated-highlight follow-ups (2026-07-03, user retest)

After §7 shipped, static parent→child worked but a BLINK/MARCH style exposed two further defects (a
third — highlight in child not showing in parent — is the deferred child→parent direction, §7):

- **8a. Child showed the pattern but STATIC (obs 2/5).** The mutation hook order was
  `net_hilight_anim_update()` then `net_hilight_sync_descend_windows()`, so the per-window animation
  tick was armed while the child's table was still EMPTY → never armed for the child. (Pressing 9 for
  the next style re-armed it because the child already held the prior entry.) FIX: call
  `net_hilight_anim_update()` at the END of `net_hilight_sync_descend_windows()`, after the children's
  tables are populated, so each child arms on its now-current animation state.

- **8b. Main window's blink FROZE / went blank when a detached window had focus (obs 3/6).** The
  animation redraw guard (`redraw_hilight_region`, scheduler.c) and the fan-out/redraw skips
  (`net_hilight_anim_update`, `net_hilight_redraw_other_windows`, hilight.c) skip a **background tab**
  by its empty `top_path` — but the **main window (slot 0)** also has an empty `top_path`, so it was
  skipped whenever it was borrowed (i.e. whenever a detached window was current), stopping its tick
  (often at a blink-OFF phase → blank). Root: empty `top_path` can't tell "hidden background tab" from
  "the main window / front tab, which stays visible on `.drw` even when a detached window is focused."
  FIX: track the win-path of the tab currently shown on the shared `.drw` canvas — `drw_front_win` in
  xinit.c, updated by `note_drw_front()` on each switch to a tab, read via `get_drw_front_win()`. The
  three guards now skip an empty-`top_path` context ONLY when it is **not** the front-of-`.drw`. The
  sole behavior change is skip→draw for exactly the visible front tab when borrowed; every genuine
  background tab (`!= drw_front`) behaves as before (no regression).

**Verified (live, DISPLAY, `vwait`):** with a blink style applied in the parent and the CHILD focused,
BOTH windows' ticks fire sustained (parent .drw ≈ child .x1.drw ≈ 11 in ~1.8 s); the child's tick is
armed on the first animating apply with no interaction in the child; a genuine background tab still
returns 0 (skipped). Both fixes SABOTAGE-verified in `tests/hilight_xwin_sync.tcl` (neuter the re-arm →
"child tick armed" fails; neuter `get_drw_front_win` → "main window animates while child focused" fails,
frozen at 1 tick). Regression suite clean.

**Still deferred (after §8):** child→parent direction (obs "applying the style in the child does not show
up in the parent"); deep in-place descent >1 level below a linked parent (§7). *(child→parent is now
resolved — §9.)*

## 9. Child→parent (ascend direction) fix (2026-07-03)

The last deferred piece. A net highlighted INSIDE a descended child window now also lights the
corresponding net in the linked PARENT window (static + blink-animated), mirroring the parent→child
machinery in reverse.

**Ground truth (single window, the byte-target).** Highlight the internal net `FOO` inside `xi` at
`.xi.`, then `go_back`:
```
CHILD (.xi.) hilights   = '{xi.FOO}'                 (entry path=".xi." token="FOO")
TOP after go_back       = '{FOO} {xi.FOO}'           (parent net FOO + the inert child entry)
```
The cross-window path must make the linked parent window's table become exactly `{FOO xi.FOO}` after
`hilight_netname FOO` in the child — with no interaction in the parent.

**Why it is a two-context computation.** `hilight_parent_pins()` (hilight.c:956, run on `go_back`) maps a
highlighted child pin-net up to the parent net using `inst.node[]` + the symbol pin names. In a single
window that map and the child highlight live in ONE table (currsch selects the path key). Across two
linked windows they are split: the instance `node[]`/pin map exists ONLY in the PARENT (target) context;
the highlighted child nets exist ONLY in the SOURCE (child) table. So the sync (a) reads the child's
highlighted net tokens directly from `src->hilight_table` at the child's level path (a plain read, no
borrow — `src` is just a pointer), then (b) borrows the parent, resolves the instance THERE
(`get_instance`), and for each pin whose child-side net is in that snapshot, records the parent net bit
(`find_nth(inst.node[j], ((inst_number-1)*mult+k-1)%net_mult+1)`).

**Rebuild = mirror of the down direction.** As in `net_hilight_sync_one_child`, the parent table is
rebuilt from scratch: `clear_all_hilights()` + `net_hilight_copy_table_from(src)` (the child table
VERBATIM — this carries back the parent's OWN ancestor-level highlights, which the down-sync had copied
down into the child as inert `.`-level entries, so unrelated parent highlights survive) + the mapped-up
parent-net entries + `propagate_hilights(1,1,...)` + guarded `draw()`. This makes set/clear idempotent
and byte-match the ground truth; it is deliberately more aggressive on clear than single-window
`hilight_parent_pins()` (whose commented-out XDELETE keeps a parent net sticky) — for a *sync* the
clear-through is the wanted behavior and matches the parent→child direction.

**New code (hilight.c):** `net_hilight_sync_one_parent()` (the reverse of `net_hilight_sync_one_child`)
+ `net_hilight_sync_parents_rec()` (the reverse of `net_hilight_sync_children_rec`: finds every window
exactly one level ABOVE the source through the descended instance via the shared `sch_path[]`/`sch[]`
stack + instance-name match, reversed, and recurses UP a consecutive-level chain). Both wired into the
existing `net_hilight_sync_descend_windows()` — no new hook sites; the caller already invokes the sync
from whichever window changed, and the end-of-sync `net_hilight_anim_update()` + the `drw_front_win`
front-tab tracker (§8b) make the animated child→parent case work once the table sync lands.

**Verified:** RED-first (the 5 up-direction asserts failed on the pre-fix binary), then GREEN; parent
table becomes `{FOO xi.FOO}` byte-matching the go_back ground truth; clear-through the other way (child
`unhilight_all` clears the parent); a BLINK highlight applied in the child animates SUSTAINED in the
parent (`$cur .drw ≈ 11` ticks in ~1.8 s while the CHILD is focused — also re-exercises §8b). SABOTAGE
(env-gated early-return in `net_hilight_sync_parents_rec`) → exactly those 5 up asserts fail, the
parent→child asserts stay green (not green-but-hollow). Regression suite (create_save/open_close/
netlisting) clean. Test: `tests/hilight_xwin_sync.tcl` (20 checks at this stage; 26 after §9a) + fixture
`tests/hilight_xwin_sync/`.

**Scope note (v2 limit):** the up-recursion only walks a sibling-less up-chain (child→parent→grandparent).
Pushing a child's change back DOWN to a common parent's OTHER child windows (two windows descended into
the same instance) is not done — not the reported topology.

### 9a. Two follow-up defects from the first live retest (2026-07-03)

The child→parent table sync above was correct, but the first hands-on retest surfaced two defects — both
FIXED:

- **9a-1. Parent's buried-net cue repainted only on mouse-over (draw skipped).** Scenario: primary
  (main window), secondary descended into `x1`; highlight a buried net in the secondary → the primary's
  `x1` should get the buried-cue rectangle, but it appeared only after moving the mouse over the primary.
  The primary's *table* was synced correctly (the mouse-move expose proved it) — only the `draw()` was
  skipped. Root: `net_hilight_sync_one_parent`'s redraw guard was copied verbatim from the down helper as
  `if(xctx->top_path && xctx->top_path[0] && xctx->save_pixmap) draw();`. The parent synced UP is usually
  the **main window**, whose `top_path` is EMPTY (it is a tab on the shared `.drw` canvas, not a detached
  window), so the guard was false → no draw. This is the exact §8b trap. FIX: shared helper
  `net_hilight_ctx_visible(wp)` — draws when the borrowed ctx owns a pixmap AND is either a detached
  window (non-empty `top_path`) OR the front-of-`.drw` (`!strcmp(wp, get_drw_front_win())`). Applied to
  **both** the up and down helpers (the down helper had the same latent bug for a main/front-tab child).
  (Draw is not headless-pixel-asserted — the file's standing convention; the up-sync-to-main-window
  *table* path is fully tested and the animated main-window check exercises the same front-of-`.drw`
  predicate.)

- **9a-2. Ascending a deep child did not re-sync the parent (`go_back`/`descend` not hook sites).**
  Scenario: secondary descends `x1`→`x4` (now `.x1.x4.`, two levels below the primary), highlight an
  internal net there → primary correctly NOT updated (deep case; no window at the intermediate level).
  Then `go_back` in the secondary to `.x1.` — now depth-1 of the primary again, and `x4` gets its cue in
  the secondary — but the primary stayed blank even on click. Root: the sync fires only from the 7
  highlight-MUTATION hooks; `go_back`/`descend_schematic` change a linked window's current LEVEL (and
  `go_back` re-maps highlights via `hilight_parent_pins`) but were not hook sites, so the newly-adjacent
  primary was never re-synced. FIX: call `net_hilight_sync_descend_windows()` at the end of `go_back()`
  and `descend_schematic()` (actions.c), after their propagate + the existing `net_hilight_anim_update()`.
  Cheap no-op when no linked window exists; idempotent. This makes ascending back to depth-1 re-sync
  cleanly — the genuine deep case (a window sitting >1 level below a linked parent with no intermediate
  window) stays deferred (§7), and the test asserts exactly that boundary ("primary NOT synced from deep
  level" then "primary synced on ascend").

**Verified (9a):** `tests/hilight_xwin_sync.tcl` extended with a grandchild fixture
(`grandchild.sym`/`grandchild.sch`, internal net `BAR`; `child.sch` now instantiates it as `xg`) driving
the deep-descend→highlight→ascend flow; byte-target from the single-window deep ascend is the `.xi.`
table `{xi.xg.BAR} {xi.BAR}`, which the primary must mirror after the secondary's `go_back`. SABOTAGE
(env-gate the `go_back` sync call) → exactly the two "primary synced on ascend" asserts fail, while the
deep-boundary and ascend-path checks stay green (isolates the hook). Regression suite clean.

### 9b. Deep-gap staleness — the orphan mop-up (2026-07-03, second live retest)

A third-look retest of the 2-levels-deep topology (primary at top; secondary descended into `x1` then,
IN PLACE, into `x4` → `.x1.x4.`) surfaced a worse-than-missing failure: **stale** highlights.

Observations: (1) a highlight made in the deep secondary did not update the primary at all; (2) ascending
the secondary one level updated the primary (§9a-2, working); **(3)** with the secondary left deep,
pressing `0` (unhighlight-all) in the primary cleared the primary but the **deep secondary still showed
the highlight** — a highlight the user "cleared everywhere" persisted.

Root (both 1 and 3): the ±1-level recursion (`net_hilight_sync_children_rec`/`..._parents_rec`) only
reaches a window EXACTLY one level away, and relays through consecutive one-level window hops. A window
sitting **two levels away with no window loaded at the intermediate level** is on nobody's chain, so it is
never visited — neither cleared nor given a cue. Stale state (a highlight that should be gone) is more
confusing than merely-missing state.

Why the exact fix is still partly deferred: lighting the precise internal net across a >1-level gap needs
the **intermediate netlist** (`x1`'s schematic) to translate `x1`-pin ↔ `x4`-pin, and that netlist is
loaded in *no* window (the primary has the top, the secondary has `x4`'s leaf). That translation stays
deferred. But two things do NOT need it: **clearing** (the answer is "nothing" at every level) and the
**buried-net cue** (an ancestor instance lights whenever any entry exists in its subtree, regardless of
level).

FIX — **verbatim orphan mop-up** (`net_hilight_sync_orphans`, hilight.c). After the ±1 recursion runs
(marking every window it reconciled with the full per-level translation in `nh_sync_visited[]`), a mop-up
pass reconciles every *un-visited* window that is on the same hierarchy branch at a different depth
(`net_hilight_prefix_related`: one window's `sch_path` is a component-aligned prefix of the other's and
they share the schematic at the shallower level). The reconcile is direction/depth-agnostic and needs no
translation (`net_hilight_reconcile_verbatim`): `clear_all_hilights()` + copy the source table +
`propagate_hilights` + guarded `draw()`. Effect: **clear-through reaches any depth** (obs 3 fixed — no
stale). The precise deep net still does not light — the documented, netlist-bound deferral.

> **⚠ Superseded by §9c:** §9b as first shipped copied the source table *verbatim*, which also pushed the
> deep subtree entry into the ancestor and lit its buried cue — presented above as "obs 1 improved." A
> retest showed that cue is **wrong** when the deep net surfaces to a real net higher up. §9c replaces the
> verbatim copy with an **ancestor-only** copy: clear-through stays, the bogus cue is gone. Read §9c.

The `nh_sync_visited[]` set is the crux of *composability*: a fully-open descend chain (all intermediate
windows present) is still handled by the precise per-level relay (those windows are marked visited and the
mop-up skips them); only genuine orphans fall through to the coarser verbatim copy. So the mop-up strictly
*adds* coverage without regressing the precise path.

**Verified (9b):** the grandchild fixture now also drives "highlight deep → primary sees the subtree entry
(buried) but NOT the `.xi.` map; clear primary → deep secondary clears (no stale)". Test at 30 checks;
the earlier "primary NOT synced from deep level" assertion was **updated** to the new, more-correct
behavior ("primary sees deep subtree (buried), not `.xi.` map") since the mop-up now legitimately changes
it. SABOTAGE (env-gate `net_hilight_sync_orphans`) → exactly the three deep-gap asserts fail, all ±1-level
and ascend checks stay green. Regression suite clean.

**Still deferred after 9b:** lighting the *exact* internal net across a gap >1 level with no intermediate
window (needs the unloaded intermediate netlist); sibling cross-sync (§5 scope note).

### 9c. The deep-gap buried cue was a LIE — populate must not cross an untranslatable gap (2026-07-03)

The §9b mop-up fixed the stale-clear bug but its verbatim copy introduced a new wrong: retesting with a
deep net that **surfaces** (`comp_ngspice`'s `OUT`, two levels down, wired up to `CTRL1` at the top),
highlighting `OUT` in the deep secondary put a **buried-cue rectangle on `x1` in the primary** instead of
lighting `CTRL1`. That cue is a lie — it claims "there is a highlight buried inside `x1` you cannot see
here," but the highlight is not buried at all; it *surfaces* as `CTRL1`. A lone, wrong cue with no real
net shown is worse than showing nothing.

Root: the verbatim copy pushed the deep entry `(.x1.x4., OUT)` — a path **below** the primary's level —
into the primary, and `propagate` lights an instance's buried cue whenever any entry sits in its subtree.
Whether the deep net is genuinely buried or surfaces cannot be known without the intermediate netlist
(`x1`'s schematic), which is loaded in no window. So the cue is *unvalidatable*, and it is wrong exactly
in the surfacing case.

The correct rule, and the resulting spec:

> **Clearing propagates across any gap; *populating* only crosses a gap we can actually translate**
> (≤1 level, or a chain of windows one level apart). A gap with no intermediate window syncs *clearing
> only*.

FIX — the orphan mop-up now copies with `net_hilight_copy_table_ancestor(src, target_path)` instead of
the verbatim `net_hilight_copy_table_from`: it keeps only source entries whose path is an **ancestor-or-
self** of the target's current path (a component-aligned prefix test, paths being `.`-terminated), and
**drops every sub-target (deeper) entry**. Consequences:
- **Up-orphan** (deep source → shallow primary): the deep leaf entries are dropped → the primary is *not*
  populated → **no bogus buried cue**. Any genuinely shallower (ancestor-level) source entries still
  round-trip, so the primary's own highlights survive.
- **Down-orphan** (shallow source → deep secondary): the source's ancestor entries are all ≤ the target
  level, so they still copy in (inert), and an emptied source still clears the deep target →
  **clear-through preserved** (`unhilight_all` fires the sync unconditionally, scheduler.c, even when the
  source is already empty).
- The precise **±1 path is untouched** (still `net_hilight_copy_table_from` + translation): there, the
  sub-level entry accompanies the *real* translated net (matching single-window `go_back`), so the cue is
  not a lone false signal. The asymmetry — verbatim for ±1, ancestor-only for orphans — is deliberate:
  show the cue only alongside a real, translated highlight; never as the sole (unvalidatable) signal.

Net user-visible behavior across a >1-level gap now: a deep highlight shows **nothing** in the far window
(missing, never wrong); the exact net appears only once the secondary ascends through the intermediate
level (the ±1 relay does the real translation, as the user already confirmed works). Clearing anywhere
clears everywhere.

**Verified (9c):** the deep tests were **corrected** to the right expectation — "primary not populated
across the 2-level gap (no false cue)" (was, wrongly, "primary sees deep subtree (buried)") plus the
retained "deep secondary cleared through (no stale)". SABOTAGE (env-gate the ancestor filter so the copy
takes *all* entries = the §9b bug) → exactly the two "not populated" asserts fail with the primary showing
`{xi.xg.BAR}`, while clear-through stays green — pinning the filter as the thing that suppresses the false
cue. Regression suite clean. 31 checks.

**Still deferred after 9c:** unchanged — exact deep-net lighting across a >1-level gap (needs the
intermediate netlist); sibling cross-sync.

### 9d. Review-driven fixes (xhigh code review, 2026-07-03)

An xhigh multi-agent review of the branch found one correctness bug that undermines this work and one DRY
issue in it (plus several out-of-scope items in the companion action-log / read-only threads):

- **`drw_front_win` went stale on tab create/close.** `net_hilight_ctx_visible` (and the §8b guards)
  decide "is this empty-`top_path` context the visible front tab?" via `get_drw_front_win()`, but
  `note_drw_front()` was called only from `switch_window`/`switch_tab` — **not** from `create_new_tab` or
  `destroy_tab`, which also make a different tab the front-of-`.drw`. So after Ctrl-T or a tab close the
  proxy named the wrong tab: the real front tab was treated as a hidden background tab (draw/anim skipped)
  while the old hidden tab still matched and painted onto the shared canvas — the exact §8b display bug,
  re-opened. FIX: call `note_drw_front()` at the draw site of `create_new_tab` and `destroy_tab` (xinit.c),
  mirroring the switch paths.
- **DRY:** `net_hilight_copy_table_ancestor` was `net_hilight_copy_table_from` + one filter line (the
  ~18-line hash-entry clone duplicated, a struct-field-drift risk). Merged into a single
  `net_hilight_copy_table_from(src, tp)` — `tp == NULL` copies verbatim, non-NULL applies the
  ancestor-or-self filter.

**Bulk-highlight batching (perf, TAKEN).** The review noted `hilight_netname` fires the full child sync
once **per net**, so a bulk-highlight loop (e.g. `net_hilight_apply` applying a style to a whole bus)
rebuilt+repainted an open descend-child M times — a visible stall (narrow: only with a linked window open).
FIX: a suspend/resume bracket. `net_hilight_sync_suspend()`/`net_hilight_sync_resume()` (hilight.c, a
nestable counter; the `xschem net_hilight_sync_suspend`/`_resume` subcommands) make
`net_hilight_sync_descend_windows()` early-return while suspended and fire exactly ONE sync on the final
resume (the sync is a full rebuild, not incremental, so only the last matters). `net_hilight_apply`
(xschem.tcl) wraps its `foreach` in the bracket with a `catch` so a bad net name still resumes (else the
counter would stay >0 and suppress all later syncs). Deterministic — NOT idle-deferral — so single
highlights stay synchronous and tests need no `vwait`. Verified: 4 new checks (suspend defers the per-net
sync → child untouched mid-batch; resume fires one sync; the real `net_hilight_apply` loop still syncs the
child); SABOTAGE (neuter suspend) → "child NOT synced mid-batch" flips. 35 checks, regression clean.

Noted but not taken (recorded for follow-up): two windows at the **same** level/sheet are excluded from
every sync pass (`net_hilight_prefix_related` rejects equal `currsch`; a new topology, not a regression);
and the mirror-image children_rec/parents_rec + the duplicated bus-pin walk are refactor candidates. The
read-only-guard gaps
(`check_unique_names`/`attach_labels`/`floaters_from_selected_inst`) and the uncaught `set header_text`
TCL_ERROR belong to the companion action-log / read-only threads, not this feature — **split out to issue
0074** for the read-only thread to own.
