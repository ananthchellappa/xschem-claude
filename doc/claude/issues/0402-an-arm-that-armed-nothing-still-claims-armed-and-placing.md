# 0402 — an `arm()` that armed **nothing** still sets `armed=1` and tells the user "placing …"

Status: **open**, measured 2026-08-11 (item D9, split out of issue 0246). Filed not fixed —
see 0246 decision D6. The *harm* this used to cause is gone with 0246; the false claim is not.

## The claim

Both form `arm()` procs call the C `-place` verb and then unconditionally declare success,
without ever asking whether the C armed anything:

```tcl
xschem add_wire_label -place   ;# src/xschem.tcl addlabel::arm
set armed 1
...
addlabel::status "placing '$current'$more -- click ON a wire or pin to drop; Esc finishes"
```

`addpin::arm` has the identical shape around `xschem [addpin::place_verb] -place`.

## Measured (at 9e51b4c8, and unchanged by 0246)

`add_wire_label` short-circuits in a symbol view (`src/scheduler.c`, the
`editing_symbol_view()` guard — a net label has no meaning in a `.sym`) and returns `TCL_OK`
having armed nothing. With a library symbol loaded:

```
G1  add_wire_label -place  rc=0 res={} ui=16424 wlp=0      ;# ui_state is the PIN form's, not ours
G1  after addlabel::start_pass  latch=label lab.armed=1 \
    status={placing 'A' (+1 queued) -- click ON a wire or pin to drop} sympin_preview=1
```

`wirelabel_preview` never went to 1 — nothing was armed — yet the form says it is placing `A`
and offers a drop that can never happen.

Pinned as a documented residue by `tests/headless/test_add_pin_lib_symbol_view.tcl` row **S13**
(`wirelabel_preview` 0 while `addlabel::armed` 1). That row must be inverted when this is fixed.

## What 0246 already removed

Before 0246 this false `armed=1` was *dangerous*: the form also wrote the `::sympin_place` owner
latch, so a symbol-view label form that armed nothing could win the latch and then drain a queued
name on somebody **else's** pin drop. 0246 deleted the latch and gave each form its own commit
counter (`sympin_drops_label` / `sympin_drops_pin`), and a label form in a symbol view can never
move `sympin_drops_label` — so it can no longer consume a name it did not place. What remains is
the misleading status line and a stale `armed` flag.

## Why it was not fixed with 0246 (rung R2, avoiding R3)

The fix is issue 0246's fallback (a): gate the `armed`/status write on evidence that the C really
armed (e.g. `xschem get wirelabel_preview` after the `-place`, or a return value from the verb).
That changes what a user **sees** in a symbol view — an error/refusal line instead of
"placing 'A' … click ON a wire or pin to drop" — which is user-visible and not covered by any
prior ratification, so folding it into 0246 would have made a cheap item status **E**. It is a
real improvement and wants its own item with the wording ratified.

Note the pin side needs the same treatment and has the same short circuit
(`add_sch_pin` in a symbol view routes to `add_symbol_pin` via `addpin::place_verb`, so the pin
form is *usually* fine there — the exposure is any `-place` that fails for another reason, e.g.
`place_wire_label`/`place_sch_pin` failing to find the symbol, where the C clears both preview
flags and the Tcl still says "placing").

## Where it lives

- `src/xschem.tcl` — `addpin::arm`, `addlabel::arm` (the `set armed 1` + status after `-place`).
- `src/scheduler.c` — the `editing_symbol_view()` short circuit in `add_wire_label`, and the
  `place_*` failure guards that clear the preview flags.
- Residue row: `tests/headless/test_add_pin_lib_symbol_view.tcl` S13.
