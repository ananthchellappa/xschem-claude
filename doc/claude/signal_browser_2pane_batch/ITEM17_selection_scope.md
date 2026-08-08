# Item 17 — "Show in Signal Browser" must honour the SELECTION

**Status: SCOPED.** Driver-raised after item 16 landed. Rulings 1-3 below are
TAKEN; do not re-open them.

Spec to amend: `doc/claude/specs/waveform_signal_browser_two_pane.md` (a new
§7.8) and `doc/claude/specs/waveform_signal_browser.md` §12 (item 12's contract).

---

## 1. The defect, in the driver's own words

> in tb_bandgap, descend to `x1` and now, within x1, the user has selected `x2`
> and issues this command — it should expand this instance in the hierarchy
> navigator so that the signals at the `x1.x2` level are visible in the signal
> pane. It should not be necessary for the user to descend into x2.

**CONFIRMED BY READING THE CODE, not by reproducing a symptom.**
`ase::show_in_browser_for_current` (`src/ase.tcl:1054`) step 2:

```tcl
  # 2. THE PIVOT — read in the DESIGN context, before anything raises a viewer
  set segs [wviewer::hier_now]
```

`wviewer::hier_now` is `xschem get sim_sch_path` (`wave_viewer.tcl:8928`) —
**where the window is STANDING**, and nothing else. The selection is never read,
at any point in the proc.

⚠ **ONE CORRECTION TO THE REPORT, and it matters for the reds.** The command
does *not* "do nothing": it reveals and selects the node for the CURRENT descend
level and fills the sea with that level's signals. What it ignores is the
selection — so selecting `x2` first changes nothing. A test written against "it
does nothing" would be testing a false premise.

## 2. What this is called

**Selection as the object of the verb.** Every other Cadence-style navigation
gesture in this codebase already takes its target from the selection rather than
from the cursor's *position in the hierarchy* — `Descend` (`e`), the browser's
own `Descend to here`, `Copy names`, the sea's context menu. This one command
reads the *stack* instead, so it is the only navigation verb in the tool whose
answer cannot be changed by pointing at something. Naming the general rule:
**the selection is the direct object; the hierarchy position is only the
fallback when there is no direct object.**

## 3. ⚠ Three things that are ALREADY TRUE, which is why this item is small

Measured by reading, before any code was written:

**3.1 The reveal already expands.** `wviewer::browser_reveal`
(`wave_viewer.tcl:9395`) does `$tv selection set`, `$tv see $id` — which opens
**every ancestor** of its target, the central finding of spec §4.2 — and then
`$tv item $id -open 1`. And a tree selection is what fills the sea
(`<<TreeviewSelect>>` → `browser_sea_refresh`). **Reveal `g:x1.x2` and x1.x2's
own-level signals appear, with no descend.** Nothing in the lower pane needs
touching; the path is the only thing that is wrong.

**3.2 Case is already handled.** `browser_node_for` (`wave_viewer.tcl:9325`)
matches each segment EXACT-first and falls back to `string equal -nocase`. The
fixture proves it end to end today: BX42 drives `X1.X2` and lands on the raw's
`g:x1.x2`. So a schematic-spelled `X2` appended to the path resolves against a
raw-spelled `x2` **with no new normalisation**.

**3.3 Ruling 1's answer already exists.** `browser_show_path` returns
`{partial <id> <landed> <asked>}` for a path whose deepest segment has no node,
after selecting the deepest ancestor that DOES exist
(`wave_viewer.tcl:9525-9526`), and `browser_msg` already has the sentence for it.
So "a non-hierarchical instance lands on the parent and says so" costs **zero new
branches** — append the name and let the existing arm answer.

## 4. Scope

### 4.1 What changes

**Exactly one thing: the path `ase::show_in_browser_for_current` asks for.**

```tcl
# NEW, in ase.tcl. The selection, reduced to the ONE question this item asks.
#   {ok <name>}  exactly one instance is selected
#   {none}       nothing selected, or the read failed
#   {many <n>}   two or more — ruling 2
proc ase::browser_sel_segment {} { ... }
```

and, in `show_in_browser_for_current`, immediately after the pivot is read and
**before anything raises a viewer**:

```tcl
  set selr [ase::browser_sel_segment]
  switch -- [lindex $selr 0] {
    ok   { lappend segs [lindex $selr 1] }
    many { <the CIW comment, ruling 2> }
  }
```

The reader is `xschem objects -type instance -selected`, whose elements are
documented in `scheduler.c:8466` as `{type T index I layer C id ID name {N}}` —
**the name is a dict key**, so no `getprop`/`get_tok` round trip is needed.
`slickprop::selected_inst_ids` (`property_form.tcl:773`) is the existing
precedent for the call.

### 4.2 ⚠⚠ WHERE THE CALL GOES IS LOAD-BEARING, NOT COSMETIC

It goes **beside step 2's pivot, in the DESIGN context, before step 4's
`wviewer::open`.** The proc's own ⚠ says why for `sim_sch_path`:

> `wviewer::open` and the sidebar show both MOVE the xschem context to the
> viewer window (measured), and `sim_sch_path` read there answers about the
> viewer's own untitled buffer.

The selection has exactly the same hazard and a worse failure mode: read after
the raise, `xschem objects -selected` answers about the **viewer's** buffer,
which has no instances — so it would degrade to `{none}` and the whole item
would silently do nothing while every check that drives the procs directly
stayed green. **A sabotage moves the call after `wviewer::open`; it must red.**

### 4.3 The three rulings, taken

| # | case | ruling |
|---|---|---|
| 1 | selected instance is NOT hierarchical (a device, a `V9`) | **Land on the parent, say so.** The existing `partial` arm, no new code. |
| 2 | TWO OR MORE instances selected | **Ignore the selection, use the descend level** — and **say so in the CIW as a comment**, naming both the confusion and the action taken. |
| 3 | process | Full item: work order, RED first, sabotages, spec amendment, receipt. |

Ruling 2's echo is `ase::echo` with **no `error` tag** (`ase.tcl:115`): the tag
routes to `xschem log_action -error` versus `-result`, and this is a comment
about an ambiguous request, not a failure. It must NAME BOTH HALVES — what was
ambiguous and what was done instead — or it is a warning the user cannot act on.

⚠ Ruling 2 is the same shape as `browser_sea_target_path`, which refuses two
cells at different levels rather than picking first-won. Cite it; do not invent
a second policy for "the pane shows ONE level, so N targets is not a question it
can answer".

### 4.4 Non-goals, declared

* **The lower pane is untouched.** §3.1: revealing the node is already enough.
* **No hierarchy test on the selected instance.** Ruling 1 makes one
  unnecessary, and adding one would be a second, weaker answer to a question
  `browser_show_path` already answers correctly.
* **Not a new key or menu entry.** Ctrl-5 / Tools > Show in Signal Browser is
  the same gesture; only its target changes.
* **Wires, pins and text stay out.** `-type instance`. Selecting a net and
  asking to show it in the browser is a different item (it would want a SIGNAL
  row, not a node) and has no rulings.

## 5. Existing checks it moves — to be MEASURED, not assumed

The prediction, to be checked against a run rather than trusted:

* **BX42 and the BX4x block drive `hier_walk X1.X2` with NOTHING selected**, so
  `{none}` keeps today's answer and they should not move. ⚠ VERIFY: the fixture
  prologue does `xschem load`, and a load may leave a selection.
* **BX48's level>0 origin mapping** likewise.
* Anything in `test_wave_sigbrowser_i11.tcl` that shares the design window.

**If a BX check does move, that is a finding about the fixture's selection
state, not licence to re-pattern it — read it before touching it.**

## 6. RED first

New band **`BX53`-`BX5x`** in `test_wave_sigbrowser_i12.tcl` (BX52 is the
highest spent, file-wide and tree-wide; BX51 is free but leave the gap).
The fixture is ALREADY THERE and is unusually well suited — `wvhier_top` holds
**`X1` AND `x1`** (both instances of `wvhier_mid`) plus the **non-subcircuit
`V9`**, and `mid` holds **`X2`**:

1. **the driver's own case** — descend to `X1`, select `X2`, invoke: the tree
   selection is `g:x1.x2` and the sea shows x1.x2's own level. Today: `g:x1`.
2. **the negative control on the same fixture** — same position, NOTHING
   selected: still `g:x1`. Without this, (1) proves only that something moved.
3. **ruling 1** — select `V9` at the top level: `partial`, landing on the root,
   with the status line saying so.
4. **ruling 2** — select `X1` and `x1` together: the answer is the descend
   level's, AND `::ciw_echo` captured a comment naming both the ambiguity and
   the action. (Tests capture ASE notices by renaming `::ciw_echo` — `ase.tcl`
   :117 says so.)
5. **PURE legs for `browser_sel_segment`**: `{none}` / `{ok X2}` / `{many 2}`,
   in the `BX01`-`BX19` both-arms block, so the reducer is pinned without a
   viewer.

## 7. Sabotages

* Move the selection read AFTER `wviewer::open` → §4.2's silent nothing.
* Use the selection when `many` instead of falling back → ruling 2 reds.
* Append the instance's `id` (or its index) instead of its `name` → the path
  cannot resolve; every case lands `partial` on the parent.
* Drop the `-type instance` filter → a selected WIRE or TEXT contributes a
  segment.
* Take the LAST selected rather than refusing on `many` → the first-won failure
  ruling 2 exists to forbid.
* `lappend segs` BEFORE the `$drop` trim rather than after → the appended name
  is eaten by the origin mapping whenever drop > 0 (BX48's level>0 case).

## 8. Spec amendments owed

* **A new §7.8** in the two-pane spec: the selection is the direct object; the
  hierarchy position is the fallback. Both rulings, with §3.1-§3.3 as the reason
  the item is three lines of behaviour.
* **`waveform_signal_browser.md` §12**: item 12's contract sentence gains the
  selection.
* **`doc/waveform_viewer_guide.html`**: the Ctrl-5 prose says "wherever the
  schematic is standing"; it now needs "…or whatever instance is selected".
