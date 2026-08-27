# 0861 - a `@spice_get_node` text renders a fabricated `0` when nothing has been published

**Status:** **OPEN, MEASURED, NOT FIXED.** Filed 2026-08-27 by the write-up pass
of the [0856](0856-annotate-op-shows-a-transient-s-t-0-as-the-operating-point-silently.md)
landing. The hole is **PRE-EXISTING** — it is reachable today on a plain
`xschem raw read` and predates the gate — but the 0856 landing **routes the
ordinary menu flow into it**, so it went from a corner case to the thing a user
sees after **Simulation > Graphs > Annotate Operating Point** on a transient.
Same class as RULING **D5-1**.

## What the user sees

A schematic carrying a `@spice_get_node` text — a probe symbol, or the shipped
`xschem_library/devices/scope_ammeter.sym` — reads **`0`** where it should read
nothing at all. On a scope ammeter that is **zero amps through the branch**,
which is a plausible-looking measurement and is a number the database does not
contain.

## The measurement

Fixture: `probe.sym` carrying `T {VDNODE=@spice_get_node v(d) }` (the pattern
`src/token.c:4443` documents verbatim), one instance on a sheet, and a 3-point
database whose `v(d)` is 1.8 / 1.9 / 2.0. Rendered text, measured on the landed
binary 2026-08-27:

    A nothing-loaded : loaded=-1  annot=-1 0 -1  text=VDNODE=-
    B TRAN attached  : sim=tran   annot=-1 0 -1  text=VDNODE=0     <-- FABRICATED
    C OP   attached  : sim=dc     annot=0 0 -1   text=VDNODE=1.8

**Causation is proven, not inferred.** B and C are the SAME three data points;
the only difference is the `Plotname:` line. And the codebase's own correct
answer already exists two lines away — with nothing loaded the identical text
renders `-`.

**The hole is older than the gate.** A plain `raw read`, which never calls
`update_op()` at all, has always left `annot_p` at -1 with a database attached:

    PRE-EXISTING raw-read tran : annot=-1 0 -1  text=VDNODE=0
    PRE-EXISTING raw-read op   : annot=-1 0 -1  text=VDNODE=0

So this is not a defect the 0856 gate created. It is a defect the 0856 gate made
**reachable from the menu**: before it, Annotate-OP-on-a-transient set
`annot_p = 0` and this text showed the t=0 sample (measured, mislabeled); after
it, `annot_p` stays -1 and the text shows a calloc zero (measured for nothing).

## Root cause, one line

`spice_get_node()`, `src/token.c:4483`:

```c
    idx = get_raw_index(node, NULL);
    if(idx >= 0) {
      val = xctx->raw->cursor_b_val[idx];
    }
```

No `annot_p >= 0` term, no `live_cursor2_backannotate` term, no
`sch_waves_loaded()` term. It is the **one** `cursor_b_val[` read in `token.c`
that stands outside the guarded `live_cursor2` family — six siblings guard at
`token.c:4349, 4838, 4930, 5016, 5111, 5184`; this one does not.

`update_op()` returns at `src/save.c:2240` **before** `annot_p = 0` (`:2246`) and
before the fill loop `cursor_b_val[i] = values[i][p]` (`:2251`), so the array
keeps its `my_calloc` zeros and this reader publishes them.

## A comment being committed asserts the wrong inventory

`src/save.c`'s 0836 block says `annot_p >= 0` *"is a term of the published-
annotation gate in token.c's six live_cursor2 sites and in op_annot.tcl"*. Six is
the right count of **guarded** sites; there is a **seventh reader** with no
guard. The audit that produced that sentence stopped at `op_annot.tcl`'s
`_annotated` and never reached the C renderers.

## Second face, same root

The public verb answers the same fabricated number: `xschem raw value {v(d)} -1`
returns `0` on the refused transient and `1.8` on the operating point.
`op_annot::raw_or_blank` is that verb.

## Shipped consumer

`xschem_library/devices/scope_ammeter.sym:31` is the one in-tree symbol using the
pattern, and its text is **not** `hide=true`:

    T {tcleval(@spice_get_node [xschem get_fqdevice @device ] )} 12.5 -139.375 0 0 0.15 0.15 {layer=17}

## No row sees it

None of the eleven rows rewritten for 0856, and none of the new T23-T28 / BA26b /
BA37, exercises a rendered `@spice_get_node` value in the refused state. They key
on `annot_p`, on `ngspice::ngspice_data`, and on the lab_pin `@spice_get_voltage`
floater — which **is** guarded and does blank correctly (row `T22`).

## ⚠ TWO GOLDENS NOW PIN THE FABRICATED ZERO — a correct fix will red them

`T14` and `T15` of `tests/headless/test_op_annot.tcl` carry
`[opa_t_v {v(d)}] == 0` with a comment that correctly identifies the calloc-zero
fall-through and judges it inert. It is **not** inert — it is this same zero, one
accessor over. Whoever fixes this must expect T14 and T15 to red, and must move
those goldens to the blank rather than weaken the fix. `T23`'s `{{tran 5 0} 0}`
and `T27`'s `{{table 3 0} {}}` are unaffected.

## Acceptance if fixed

1. B above renders `-` (or empty), not `0` — same three data points, `Plotname:
   Transient Analysis`.
2. **Positive twin.** C still renders `1.8`, unchanged.
3. The pre-existing `raw read`-without-annotate path renders `-` too, for both
   `tran` and `op`.
4. `xschem raw value {v(d)} -1` and `op_annot::raw_or_blank` agree with the
   rendered text — one answer, not two (RULING D5-4).
5. `T14`/`T15` goldens moved to the blank, not the fix narrowed to keep them.
6. Sabotage: restore the unguarded read and confirm row 1 reds.
