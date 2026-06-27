# Issue 0053 — Return/return-to-top from a descend-NEW-WINDOW child should navigate the window chain, not ascend in place

**Opened:** 2026-06-27
**Status:** OPEN — spec agreed (§6 decisions resolved 2026-06-27); ready to implement.
**Severity:** MEDIUM — wrong hierarchy-navigation model for the Cadence browse flow; confusing and
loses the connection between the parent window and the window you descended into.
**Branch:** `fluid-editing`.
**Source:** user report / spec.
**Affects:** `utils/cadence_nav.tcl` (`return_to_top`, `ascend_to_top`, and a new return-one-level
proc), `src/cadence_style_rc` (Ctrl-E / Alt-E binds), and a small hook in
`src/xschem.tcl` `hi_descend_newwin` (~:5646) to record the parent-window link. The default xschem
Ctrl-E = `go_back(1)` (`callback.c:4001`) is unchanged for non-Cadence users.
Related: [[hi-descend]], [[descend-readonly]], [[cadence-bindkeys]], [[multi-window-detach]].

---

## 1. The model

When you **descend into a new window** (the hi_descend dialog's *New Window* option, or a future
Cadence bind), the new window is **linked** to the window you descended *from* — it is its child in a
cross-window descend chain. This is different from merely *opening* the cell in a new window (no
link). The return operations must walk that window chain:

- **Return one level** (Ctrl-E): step back up by one. If the current window has descended further
  *in place* below the level it was born at, ascend in place first; once it is back at its
  **entry level** (the level it was created showing), the next return moves **focus to the parent
  window** instead of ascending this window in place.
- **Return to top** (Alt-E): repeat "return one level" until the **root** window of the chain is at
  the top of its hierarchy, and focus that root window.

Two facts the implementation records per descend-new-window child window `W`:
- `parent_win(W)` — the window descended *from*.
- `entry_level(W)` — `currsch` in `W` right after it was created (the deepest level it was born at;
  acts as the floor for in-place ascend in `W`).

## 2. Worked examples (from the report)

**Scenario 1 — single return (Ctrl-E).**
`W1` shows **A** (which instantiates `x1` of **B**). Select `x1`, descend *New Window* → `W2` opens
showing **B**, linked: `parent_win(W2)=W1`, `entry_level(W2)=1`.
Press **Ctrl-E** in `W2`.
- **Want:** focus returns to **W1** (already showing A).
- **Now (bug):** `W2` ascends in place and shows **A** (it carries the full stack `[A,B]`).

**Scenario 2 — return to top (Alt-E).**
`W1` shows **A**; descend *in place* into `x1` of **B** → `W1` now shows **B** (stack `[A,B]`).
Then descend *New Window* into `x2` of **C** → `W2` opens showing **C**, linked:
`parent_win(W2)=W1`, `entry_level(W2)=2`.
Press **Alt-E** in `W2`.
- **Want:** the original window **W1** gets focus and ascends to show **A** (the top). Equivalent to:
  Ctrl-E in `W2` (focus hops to `W1`, still at B) → Ctrl-E in `W1` (in-place ascend B→A, since `W1`
  is the root and has the full stack).
- **Now (bug):** `W2` ascends in place C→B→A; `W1` is untouched.

## 3. Root cause

`hi_descend_newwin` (`xschem.tcl`) opens the parent schematic in the new window, `copy_hierarchy`s
the **entire** parent stack into it, then descends — so the child window is a fully independent
hierarchical view that merely *starts* deeper, and `go_back`/`ascend_to_top` ascend it **in place**.
No parent-window link is recorded, so the return operations have no way to know they should hop to
the window you came from. `cadence::return_to_top` / `ascend_to_top` only ever loop
`xschem go_back` on the **current** window.

## 4. Proposed behavior (return-one-level primitive; return-to-top loops it)

```
return_one_level (current window W):
  if currsch(W) > entry_level(W):        # in-place descents made within W -> unwind them first
      xschem go_back                     # ascend in place, stay in W
  elif parent_win(W) exists:             # at W's birth level -> step out to the parent window
      focus/raise/switch to parent_win(W)   # do NOT ascend W   (see §6 Q1: keep W open vs close it)
  elif currsch(W) > 0:                   # root window with its own stack -> ascend in place
      xschem go_back
  else:
      ciw_echo "already at top"

return_to_top:
  repeat return_one_level until at the root window (no parent_win) AND currsch == 0
```

Scope: Cadence config only — bound in `cadence_style_rc` (Ctrl-E → `cadence::return_one_level`,
Alt-E → the rewritten `cadence::return_to_top`), overriding the C defaults with `.drw` binds + `break`
the same way Alt-E is overridden today. Default xschem Ctrl-E (`go_back`) is untouched.

Implementation note: record `parent_win`/`entry_level` with a small hook in `hi_descend_newwin`
(a general `::descend_parent_win()` / `::descend_entry_level()` array, harmless when unused), since the
*New Window* descend goes through the core dialog, not a Cadence proc.

## 5. Current behavior reference

- Ctrl-E → `go_back(1)` (`callback.c:4001`); descend-new-window via hi_descend dialog →
  `hi_descend_newwin` → `copy_hierarchy` (full stack) → child ascends in place.
- Alt-E → `cadence::return_to_top` → `ascend_to_top` (loops `go_back` on the current window).

## 6. Resolved decisions (2026-06-27)

- **Q1 — Fate of the child window on a cross-window return → KEEP IT OPEN.** A return moves focus
  from child `W2` back to parent `W1`; `W2` stays open showing its cell (just unfocused), so the user
  can switch back to it. Return is a *focus* move up the window chain, not a window-close. Therefore
  a return never triggers a save prompt (nothing is unloaded), and return-to-top leaves every
  intermediate child window open — it only re-focuses the root and ascends *it* to the top.
- **Q2 — In-place descents inside a child window → UNWIND IN PLACE FIRST.** The §4 default holds: one
  Ctrl-E = one level up. Inside `W2` (born at B, then B→D in place), Ctrl-E ascends D→B within `W2`;
  the next Ctrl-E (now at the entry level) hops focus to `W1`.
- **Q3 — New *tab* descends → SAME AS WINDOWS.** A new-tab-descended child records the same
  `parent_win`/`entry_level` and returns to its parent context the same way. `hi_descend_newwin`
  handles both `dest eq window` and `dest eq tab`, so the link is recorded for both.
- **Q4 — Parent window/tab closed (default).** If `parent_win(W)` no longer exists when a return is
  attempted, fall back to ascending `W` in place (today's `go_back` behavior); if `W` is already at
  its top, report "already at top". The stale link is then cleared.
- **Q5 — Alt-X (descend-to-last) interaction (default).** `return_to_top` keeps remembering the
  descent location for Alt-X, recorded against the **root** window it ends focused on, and Alt-X
  re-descends there. (Per-window `cadence::last_loc` already keys by window path.)

## 7. Acceptance

1. Scenario 1: Ctrl-E in the descended child window focuses the parent window (which shows A); the
   child does not ascend in place and stays open showing B.
2. Scenario 2: Alt-E in the deepest child window focuses the original/root window and ascends it to
   the top (A); the child window stays open showing C.
3. A child window descended further *in place* unwinds those levels with Ctrl-E before the next
   Ctrl-E hops to the parent (Q2).
4. New-*tab* descends behave the same as new-window descends (Q3).
5. Parent closed → fall back to in-place ascend (Q4). Non-Cadence Ctrl-E (`go_back`) and plain
   *open in new window* (no descend link) are unchanged.
