# 0403 — an armed placement form drains a queued name across a context switch (the drop witness is per-`Xschem_ctx`, the forms are not)

Status: **open**, measured 2026-08-11 (item D9, adversary pass on issue **0246**). Filed not fixed.
**Pre-existing** — reproduces byte-identically with the pre-0246 shared-total witness, so 0246
neither caused it nor closed it. Severity: a queued name is consumed without ever being placed, and
a preview is armed in the **wrong schematic**.
Related: **0122** F3 (the "the forms are singletons bound to the MAIN window `.drw`" scope note),
**0246** (the per-owner split this survives), `doc/claude/specs/add_wire_label.md` #8.

## The claim

`sympin_drops`, `sympin_drops_pin` and `sympin_drops_label` are fields of `Xschem_ctx` (`xschem.h`),
i.e. **per open schematic context**. `addpin::` / `addlabel::` are **singleton Tcl namespaces**
bound once to the main window's `.drw`. So `drop_snap` is taken in one context and compared in
whatever context is current when the next `ButtonRelease` arrives. A new tab/window starts its
counters at 0, which is *lower* than the snapshot — the compare is `==`, so it reads as "a drop
happened" and the form drains.

## Measured (headless, no state injection, at the 0246 fix)

```
CTXA after 3 label commits: label=3 pin=0 tot=3
ARMED  snap=3 armed=1 queue={KEEP1 KEEP2} inst=4
CTXB  label=0 pin=0 tot=0 inst=0 ui=0            <-- after `xschem new_schematic create`
STRAY armed=1 queue={KEEP2} inst=1 status={placing 'KEEP2' -- click ON a wire or pin to drop; Esc finishes}
```

One stray left-release in the **new, empty** schematic consumed `KEEP1` — which was never placed
anywhere — and armed a `KEEP2` preview on the cursor of a user who just asked for a blank sheet
(`inst=1` in CTXB is that preview). The user's queue silently lost an entry and their new sheet has
an object riding the pointer.

Same script with `proc addlabel::drops {} {return [xschem get sympin_drops]}` (the pre-0246
shared-total witness) prints the **identical** four lines, which is the proof this is inherited, not
introduced.

Repro driver kept out of the tree; it is four steps: arm nothing → commit N labels in context A →
arm a 2-name queue (`drop_snap` = N) → `xschem new_schematic create` → `addlabel::after_drop 1`.

## Root cause

The witness answers "*has a drop been committed since my snapshot*" only within one context. Nothing
ties `drop_snap` to the context it was taken in, and nothing invalidates an armed form when the
current context changes. `>` instead of `==` would not fix it either (a *stale-low* counter in a
fresh context is the wrong comparison, not the wrong operator) — and it would break the deliberate
"count did not move ⇒ pause" contract of 0122 E1.

## Fix sketch (not done here)

Snapshot the **context identity** alongside the count and require both to match:

- cheapest: also record `[xschem get current_win_path]` (or the `Xschem_ctx` address / a per-ctx
  serial exposed as a new getter) in `arm()`, and in `after_drop` take the ordinary 0122-E1 pause
  path when it differs — the form did not commit anything *here*, which is exactly the E1 story and
  needs no new string;
- or make the forms context-aware at the source: tear the arm down on a context switch
  (`new_schematic`, tab switch, window raise), which is a larger change and touches every
  `get_save_xctx`/`get_old_xctx` seam.

The first is the smaller blast radius and reuses the existing pause line.

## Where it lives

- `src/xschem.h` — `sympin_drops{,_pin,_label}` inside `Xschem_ctx`.
- `src/xschem.tcl` — `addpin::arm` / `addlabel::arm` (`set drop_snap [<ns>::drops]`) and both
  `after_drop` compares.
- No test covers it: every headless suite runs in a single context, and the two 0246 sections
  (W in `test_add_wire_label.tcl`, Q in `test_sch_add_pin.tcl`) never call `new_schematic`.
