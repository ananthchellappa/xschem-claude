# Decision doc — modeless, selection-reactive Edit Properties form

*Status:* **M1 IMPLEMENTED 2026-06-14.** Decisions D1–D5 ratified (D1 selection-
only, D2 prompt Apply/Discard/Cancel, D3 C-fires-Tcl, D4 retarget, D5 keep-open;
see §3 / §7). M1 unlocked canvas selection while the form is open + the
selection-reactive Tcl layer (`on_selection_changed`, `maybe_apply_then`) with
Next/Prev folded into the same prompt. Suite 119 checks (PF40–PF46 + PF28c). The
C event gate is eyeball-verified (synthetic events are WSLg-flaky). **M2** (empty-
selection polish, single-click-retarget feel, redraw passes) remains.
Sibling of the multi-instance property-editing work
([[multi_instance_property_editing]]) and the apply-scope highlight
([[apply_scope_highlight]]). Builds on the slick property form
([[slick-property-forms]]) and the stable object handles
([[stable-object-handles]]).

*Summary:* Today, opening **Edit Properties** quietly **locks out canvas
selection** (you can pan/zoom but not click-select or rubber-band more objects).
Cadence's property editor is **modeless** — you keep selecting on the canvas and
the editor reacts. This doc characterizes *why* ours blocks, then proposes making
selection work while the form is open, with the selection change live-updating the
**scope set**, the **Next/Prev nav set**, and the **white scope-highlight**. As
with the earlier phases: decisions first, **STOP for ratification**, then
RED-first.

---

## 1. Characterization — why selection is blocked today (verified)

The form is **not a hard modal**. There is **no Tk `grab`** in
`property_form.tcl` — that is why canvas zoom/pan still work while it is open. The
only thing the form does to the engine is bump a counter (`property_form.tcl:582`,
undone at `:750`):

```tcl
xschem set semaphore [expr {[xschem get semaphore] + 1}]
```

`xctx->semaphore` is XSCHEM's **re-entrancy lock**. Baseline when idle is **0**.
Every canvas event runs through `callback()`, which raises it for the duration of
the event (`callback.c:2219` `xctx->semaphore++`, dropped at `:2221`). So:

| situation | semaphore during the event | result |
| --- | --- | --- |
| no form open | `callback()` → **1** | gestures run |
| form open | form's +1, then `callback()` → **2** | gesture guards trip |

The gesture handlers are guarded by `if(xctx->semaphore >= 2) …`:

- the **motion** handler bails at `callback.c:3306` (`return;`) — this kills
  rubber-band selection and most drags;
- wire/line/move/place starts bail at `callback.c:1866`, `:1891`, and the other
  `MENUSTART*` branches.

Crucially, **pan and zoom are handled *before* that guard** — `pan(RUBBER,…)` at
`callback.c:3304` (the guard is at `:3306`); wheel-zoom is on earlier branches
(`callback.c:1018`–`1132`). So view ops slip through; selection/edit gestures do
not. The asymmetry the user observed is purely **where the lock sits relative to
each operation**, not an intentional "look but don't touch."

**Why the lock exists at all.** It is a conservative guard from when this was a
blocking, single-object editor: don't let a *new* state-mutating gesture (move,
wire, a second editor, a selection change) start while an editor "owns" the
current selection and may hold **unapplied edits**. It was never designed to
forbid selection specifically — selection just falls on the locked side.

**What the form snapshots at open** (`property_form.tcl` `edit_form`, ~`:654–670`):
`nav(ids)` = the selected instances by stable id (from `::tctx::edit_sel_ids`),
`nav(disp_id)` = the displayed instance. These are taken **once** at open. Nothing
refreshes them afterward, because nothing *can* change the selection while open.

**The refresh machinery already exists** (added in P1/P3/H1): `load_pos`,
`scope_instances`, `update_warning`, `update_highlight`, and `update_nav_ui` all
recompute the form's derived state from `nav(...)` + `::slickprop_apply_scope`.
A modeless form mostly needs to **re-run these when the selection changes** — the
hard part is *knowing* it changed (Tk cannot see a C-side `select_object()`).

---

## 2. Target behavior (Cadence-like)

While the form is open, the user can keep working the selection on the canvas:

- **Click an object** → it becomes the selection (replacing the old).
- **Shift-click / rubber-band** → add to / sweep the selection.
- The form **reacts live**: the **scope set** (All Selected), the **Next/Prev
  nav set**, the **"values differ" warning**, and the **white scope-highlight**
  all update to the new selection.
- Under **Only Current**, clicking a single different instance **switches the
  displayed instance** to it (the form re-loads that object's fields).
- Heavier mutations (move, wire, place, a second editor) **stay locked** while the
  form is open — only *selection* is unlocked.

Non-goal for v1: full modeless editing (moving/drawing with the form open). That
keeps the re-entrancy guarantees intact and the change small.

---

## 3. Open decisions (settle first, then STOP)

### D1 — How far to relax the lock  *(needs a human call)*

- **(a) Unlock selection only (recommended).** Keep the form's `semaphore += 1`
  (move/wire/place stay locked), but let the **selection gestures** through even
  at `semaphore >= 2`: click-select (`unselect_at_mouse_pos` / `select_object`,
  `callback.c:1801`), Shift-add, the rubber-band (`STARTSELECT`,
  `callback.c:3327`), and select-all/unselect-all. Surgical; preserves every
  other re-entrancy guarantee.
- (b) Go fully modeless (drop the form's semaphore bump to 0). Smallest code, but
  unlocks move/wire/place too — a user could drag objects or start a wire with
  pending edits in the form. Rejected for v1 (too broad).
- (c) Add a separate `xctx->editor_open` flag distinct from the busy semaphore and
  re-express the guards in terms of it. Cleanest long-term, but touches every
  guard site. Heavier than needed for v1.

**Recommendation: (a).** Gate the selection-gesture sites on "selection is always
allowed" rather than the generic busy check — e.g. a helper
`selection_allowed()` that returns true even at `semaphore >= 2` when the
property form is the thing holding the lock. Implementation note: the cleanest
signal is a dedicated flag the form sets (see D3), so "form open" is distinguished
from other `semaphore >= 2` states (netlist in progress, etc.) where selection
should still be blocked.

### D2 — Pending unapplied edits when the selection changes  *(RATIFIED: prompt)*

When the user has typed into a field but not pressed Apply/OK, and then changes
the canvas selection:

**Ratified (user, 2026-06-14): match Cadence — pop up a dialog asking whether to
apply the pending edits.** (Rejected: (a) silent discard — what Next/Prev does
today; and (b) silent auto-apply — a stray click would write without asking.)

The behavior, spelled out:

- **Only prompt when the form is actually dirty.** Reuse the existing
  dirty-tracking (the modified-field accent dots, `slickprop::update_dirty` /
  `collect_changes`): if nothing was edited, switch to the new selection
  **silently** (no nag on every click). A `slickprop::is_dirty` predicate gates
  the prompt.
- **The dialog (a transient `tk_messageBox`)** on a dirty selection change:
  *"Apply your changes to `<displayed name>` before switching?"* with **three**
  buttons:
  - **Apply** → `do_apply` to the *current* scope + displayed instance (the
    normal Apply path, one undo), then proceed to the new selection.
  - **Discard** → drop the edits, proceed to the new selection (the old
    Next/Prev behavior).
  - **Cancel** → **stay where you are**: re-select the *previous* set in the
    engine (by stable id, from the pre-change `nav(...)`) and keep editing the
    current instance. The canvas selection is restored so the form, the
    selection, and the white highlight stay in agreement (outlined == being
    edited).
- This same prompt should also cover **Next/Prev** when dirty (today they discard
  silently). Folding nav into the same `maybe_apply_then` helper makes the whole
  editor consistent: *any* move away from a dirty instance asks once. (Call this
  out as a small, welcome behavior change to Next/Prev.)

Note this **supersedes** the old "nav silently discards" rule (§3.2 of the
multi-instance work) — moving away from a dirty instance now asks. Apply/Discard/
Cancel map cleanly onto the engine: Apply = the existing apply command, Discard =
rebuild the grid, Cancel = re-select the previous ids.

### D3 — How the form learns the selection changed  *(needs a human call)*

Tk cannot observe a C-side `select_object()`. Options:

- **(a) C fires a Tcl callback (recommended).** At the selection-gesture
  completion points in `callback.c` (button-release for rubber-band, the
  click-select path), when the property form is open, call a Tcl hook —
  `if(has_x && <form-open flag>) tcleval("slickprop::on_selection_changed");`.
  One or two well-placed calls; fires exactly when the selection settles.
- (b) The form polls (a `<timer>` re-reading `xschem objects -selected`). No C
  change, but it's the WSLg-flaky pattern we deliberately removed from the test
  harness, and it wastes redraws. Rejected.
- (c) Bind Tk `<ButtonRelease-1>` on `.drw` from the form. Tempting (pure Tcl),
  but it races/duplicates the C event handling and won't see programmatic
  selection changes. Rejected.

**Recommendation: (a).** A small, explicit "selection settled" notification, gated
on a form-open flag so it costs nothing when no form is open. `on_selection_changed`
rebuilds `nav(ids)` from `xschem objects -selected` (instances only), preserves
the displayed instance if it is still selected (else falls back to the first), and
re-runs the existing refreshers (`load_pos` / `update_nav_ui` / `update_highlight`
/ `update_warning`).

### D4 — The displayed instance after a selection change

- **current scope:** if the click selected a single instance, **switch the
  displayed instance to it** (re-`load_pos` on that id) — the Cadence "click to
  edit this one" feel.
- **selected / all scope:** keep the displayed instance if it is still in the new
  set; otherwise display the first of the new set. The scope set itself is the new
  selection (selected) or unchanged-by-selection (all is master-derived).

**Recommendation:** as above — single-click retargets the displayed instance;
multi-select keeps the displayed one when still present. All by stable id.

### D5 — Empty selection while the form is open

If the user clicks empty canvas (clears the selection):

- **Recommendation:** keep the form open showing the **last displayed instance**
  (don't auto-close), but the scope set under *selected* becomes just that one (or
  empty → behave like *current*). Clearing the selection should not yank the
  editor out from under the user. Closing stays an explicit OK/Cancel.

### D6 — Interaction with the scope-highlight (H-series) and Next/Prev

The highlight and nav already refresh from `nav(...)` + scope. Once
`on_selection_changed` rebuilds `nav(...)` and calls the existing refreshers, the
white outline and the "k of N" readout track the new selection **for free** — no
new highlight logic. This is the payoff of having centralized those refreshers.

---

## 4. Resulting shape (if recommendations are ratified)

**C:**
- A form-open flag the engine can see — reuse/extend rather than invent: e.g. set
  a known `xctx` flag (or a Tcl var the C side reads) in `edit_form` open/close.
- `selection_allowed()` (or inline equivalent): let the selection-gesture sites
  (`callback.c:1801` click-select, `:3327` rubber-band, shift-add, (un)select-all)
  run even at `semaphore >= 2` **when the form-open flag is set**; everything else
  stays locked.
- One/two `tcleval("slickprop::on_selection_changed")` calls at the
  selection-settled points, gated on the form-open flag.

**Tcl (`property_form.tcl`):**
- `slickprop::is_dirty`: true iff any field's value differs from its loaded value
  (reuse the dirty-tracking behind the accent dots / `collect_changes`).
- `slickprop::maybe_apply_then {action}`: if `is_dirty`, pop the D2 dialog —
  **Apply** runs `do_apply` then `eval $action`; **Discard** runs `eval $action`;
  **Cancel** runs the supplied *restore* (re-select the previous ids, stay put).
  If not dirty, just `eval $action`. **Next/Prev (`nav`) routes through this too.**
- `slickprop::on_selection_changed`: capture the previous `nav(ids)`/`disp_id`,
  read the new selection (`xschem objects -selected`, instances by stable id),
  then `maybe_apply_then` { rebuild `nav(...)`, reconcile `nav(disp_id)` (D4),
  `load_pos` } with a Cancel-restore that re-selects the previous ids. `load_pos`
  already re-runs greying / nav UI / warning / **highlight**.
- Nothing else changes: the scope dropdown, Apply/OK/Cancel, highlight, warning
  are all already driven off `nav(...)` + the scope var.

Contract stays thin: **C owns selection + when it settled; Tcl owns the form's
reaction.**

---

## 5. Phasing (incremental, each shippable)

1. **M1 — unlock selection + react. ✅ DONE 2026-06-14.** D1(a) selection-allowed
   gate + D3(a) notification + `on_selection_changed` rebuilding the nav set;
   **D2 prompt** (`is_dirty` + `maybe_apply_then`, Apply/Discard/Cancel, Next/Prev
   routed through it); D4 displayed-instance reconciliation. Highlight/nav/warning
   ride the existing refreshers.
2. **M2 — polish.** D5 empty-selection handling; single-click-retarget under
   *current*; make sure undo/Apply semantics are unchanged; eyeball the live feel.

---

## 6. Test plan (RED-first, headless where possible)

Add to `tests/property_form/` (suite at 102 checks; keep green). The selection
side is **drivable headlessly** — `xschem select instance …` changes the C
selection, and we can invoke `slickprop::on_selection_changed` directly (the same
way P3/H1 tests invoke `on_focus` / `nav` inside `pf_form_run`).

- **Nav set tracks selection:** open the form, then select a different/extra
  instance set, call `on_selection_changed`, assert `nav(ids)` == the new selected
  ids and `update_nav_ui` shows the new "k of N".
- **Highlight follows (ties to H-series):** after a selection change under
  *selected*, `xschem highlight_scope` count == the new selected-instance count
  and `highlight_scope ids` == the new set (outlined == applied still holds).
- **D2 prompt — all three paths.** The suite already stubs `tk_messageBox`
  (`body.tcl:18`); override its return per case. With a dirty field then a
  selection change: **Apply** → the old instance is written *and* the form moves
  to the new one; **Discard** → old instance unchanged, form moves, edit dropped;
  **Cancel** → old instance unchanged, form **stays** on it, and the previous
  selection is restored (`xschem objects -selected` == the pre-change set). Plus:
  a **clean** (non-dirty) selection change switches **without** any prompt (assert
  `tk_messageBox` was not called — e.g. a call-count probe).
- **Displayed-instance reconciliation (D4):** single-select a different instance
  → `nav(disp_id)` becomes it; multi-select keeping the displayed one → it stays.
- **Lock still holds for mutation (D1a):** with the form open, assert a *move*
  gesture is still refused (the selection-only relaxation didn't unlock editing).
  (Selection-allowed proven by the nav-set test; mutation-still-locked proven by
  a guarded probe.)

**Sabotage after green:** make `on_selection_changed` a no-op → the nav-tracks
and highlight-follows tests redden; relax the lock for *all* gestures → the
"mutation still locked" test reddens; make `maybe_apply_then` skip the
`is_dirty` check (always switch) → the Apply/Cancel prompt-path tests redden.
Revert.

Pixel/feel (does it *feel* modeless, no flicker) = manual eyeball, noted not
asserted.

---

## 7. Ratification questions (the gate)

1. **D1** — relax **selection only** (recommended) vs. fully modeless vs. a
   dedicated `editor_open` flag?
2. **D2** — ✅ **RATIFIED: prompt** (Apply / Discard / Cancel, only when dirty;
   Next/Prev folded in). Confirm the **3-button** shape (vs. 2-button
   Apply/Discard) and that **Cancel restores the previous selection**.
3. **D3** — **C fires a Tcl `on_selection_changed`** (recommended) vs. Tcl polling
   vs. Tk binding?
4. **D4** — single-click **retargets the displayed instance** under *current*;
   multi-select keeps it when still present — OK?
5. **D5** — clicking empty canvas keeps the form open on the last instance (not
   auto-close) — OK?

*On ratification: implement RED-first per §5 (M1 then M2). Commit per phase in the
established style; keep the suite green; update this doc's status, a short user-
guide note ("the editor is modeless — keep selecting"), and the tutorial.*
