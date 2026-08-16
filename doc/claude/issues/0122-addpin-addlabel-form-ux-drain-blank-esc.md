# 0122 — Add-Pin / Add-Wire-Label form UX: drain, blank-on-reopen, Esc-any-time

Status: **FIXED** — the three requested behaviors PLUS both edge cases E1 and E2 (below).

## Requested behavior (all done)

The schematic-editor **Add Pin** form (`p`, `addpin::`) and the **Add Wire Label** form
(`l`, `addlabel::`) are modeless placement forms in `src/xschem.tcl`. Three fixes:

1. **Drain as you place.** The Pin Name entry now consumes the just-placed name after each drop,
   so the field always shows what is still queued (`IN OUT VDD` → `OUT VDD` → `VDD` → empty).
   `addpin::after_drop` now runs `set name [join $pending " "]`, mirroring `addlabel::after_drop`
   which already did this.
2. **Blank on a new invocation.** Both forms retained the previous names on reopen. `on_destroy`
   (both namespaces) now also `set name {}`, so closing a form wipes the name and the next fresh
   `open` builds a blank entry. (The wire-label form had the same retain bug; fixed too.)
3. **Esc dismisses at any time.** The Add-Pin canvas Esc binding was guarded by
   `addpin::placing` — so with the queue drained (no preview armed) Esc on the canvas did nothing.
   Changed to `{if {[winfo exists .addpin]} {addpin::escape; break}}`, matching the wire-label form.

Verified end-to-end in GUI mode via `scratchpad/verify_pinlabel_forms.tcl` (19/19: drain,
blank-reopen both forms, Esc idle/armed/entry-focus). Headless regressions
`tests/headless/test_sch_add_pin.tcl` (21) and `test_add_wire_label.tcl` (59) still pass.

## Edge cases (also fixed)

### E1 — un-placed name silently lost after an external abort — FIXED (airtight drop-witness)
`after_drop`'s only "a real drop happened" witness was `armed && !placing()`. If the user left the
form open with a name armed and started an **unrelated** canvas gesture (e.g. `w` wire, `m` move)
that calls `abort_operation`, the C side cleared `START_SYMPIN` (`placing()→0`) but nothing reset
the Tcl `armed` flag or the `::sympin_place` latch (**issue 0246, 2026-08-11: that latch is gone
— the drop witness below is now split per owner, `sympin_drops_pin` / `sympin_drops_label`, and
each form compares only its own part**). The next stray left-`ButtonRelease` then
satisfied every `after_drop` guard, advanced the queue, and (with fix 1) drained an un-placed name.

Fix: a **per-context commit counter** `xctx->sympin_drops` (xschem.h), bumped **only** in
`callback.c end_move_copy_logged()` when `ui & START_SYMPIN`. That funnel is the *sole* commit path
for a sympin drop — an aborted preview is deleted in a different code path and never reaches it, and
an off-copper net-label refusal `return 0`s in `wire_label_try_commit()` *before* calling it; both
real-drop callers (pin drop `callback.c:1897`, on-copper label `:1816`) invoke it while
`START_SYMPIN` is still set. Exposed via `xschem get sympin_drops` (scheduler.c). Each form's
`arm()` snapshots the count into `drop_snap`; `after_drop` bails (`set armed 0; return`, **no
drain**) if the count did not rise. This is airtight where the earlier-considered instance/rect
count-witness was not (an unrelated instance deletion could false-block a real drop; a monotonic
commit counter cannot).

Recovery after an external abort: the form disarms (`armed=0`) but keeps the queued names in the
entry; editing the field re-runs `start_pass`→`arm` to resume. No data loss.

### E2 — two forms open share one canvas-Esc slot — FIXED (sibling handoff)
Both forms bound the same `.drw <Key-Escape>` (plain, non-`+`, last-open-wins) and each `on_destroy`
cleared it unconditionally, so closing one killed the survivor's canvas-Esc. Fix: per-form
`grab_esc` (claims the slot; called on fresh `open` **and** the raise path so a re-focused form
re-claims it) and `release_esc` (called from `on_destroy`; hands the slot to the **sibling** form if
it still exists — checked via `winfo exists` on the *other* toplevel, never self — else clears it).

## Second review pass (adversarial workflow) — 3 findings, all addressed

- **F1 (medium): the counter was not form-specific.** `sympin_drops++` bumped on *any*
  `START_SYMPIN` commit, and four NON-form paths also use that machinery — `place_net_label`
  (Ctrl+P ipin / Ctrl+Shift+P opin / Alt+Shift+L lab_wire / `xschem net_label`), `add_graph`,
  `add_image`, clipboard-image paste. Committing one of those *while a form was armed* bumped the
  count → the form's `after_drop` would spuriously drain a queued name. (Pre-existing hole in a
  different trigger class — the pre-diff `after_drop` already drained on `placing()==0 && latch`
  here — but it broke the "airtight witness" claim.) **Fixed**: gate the bump on
  `xctx->sympin_preview`, which is set ONLY by the three form `-place` arms and is still 1 at the
  funnel (cleared after). Foreign placements never set it, so they no longer bump. Now truly
  form-specific.
- **F2 (low, newly introduced): stale "placing…" prompt after the E1 bail.** The
  `set armed 0; return` left the status label reading "placing 'IN' … click to place", so a
  follow-up click was a silent no-op (reads as a hang). **Fixed**: the bail now sets a
  "placement paused (another action took over) — edit the name or reopen to resume" status.
- **F3 (pre-existing, not fixed): `.drw`-only.** The whole form mechanism — the
  `.drw <ButtonRelease>` drop hook and the E2 `.drw <Key-Escape>` slot — targets the MAIN window
  canvas only; in a detached window / non-first tab (`.xN.drw`) the queue does not drain and
  canvas-Esc does not dismiss. Predates 0122 (the drop hook was always `.drw`; mirrors the sibling
  `ciform`). Making these forms multi-window-aware is a separate, larger change. Left as a known
  limitation; the over-broad E2 comments were softened to state the `.drw`/main-window scope.

## Verification
GUI harness `scratchpad/verify_pinlabel_forms.tcl` (needs a display; drives real toplevels +
`xschem callback` drop events + `xschem abort_operation` + `xschem net_label`): **36/36**, incl.
E1 (external abort preserves the name; a real drop right after still drains), E2 (handoff on close;
slot cleared when none open), F1 (a foreign `net_label` drop does NOT bump the counter while a real
form drop does), F2 (paused status). Headless `test_sch_add_pin` (21), `test_add_wire_label` (59),
and `test_sympin_drop_log` (all pass, exercises the commit funnel) stay green. C build clean.

## Files
- `src/xschem.h` — `sympin_drops` field on `Xschem_ctx`.
- `src/callback.c` — counter bump in `end_move_copy_logged`.
- `src/scheduler.c` — `xschem get sympin_drops`.
- `src/xschem.tcl` — `after_drop`/`on_destroy` (both forms), `arm` drop_snap snapshot,
  `grab_esc`/`release_esc`, `.drw <Key-Escape>` wiring in both `open`s.
- `scratchpad/verify_pinlabel_forms.tcl` — GUI-driven verification.
