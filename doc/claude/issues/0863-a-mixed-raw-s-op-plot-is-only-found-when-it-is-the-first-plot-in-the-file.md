# 0863 - a mixed raw's `op` plot is found ONLY when it is the FIRST plot in the file

**Status:** **OPEN, MEASURED, NOT FIXED.** Filed 2026-08-27 by the write-up pass
of the [0856](0856-annotate-op-shows-a-transient-s-t-0-as-the-operating-point-silently.md)
landing. **Pre-existing**, and it is the defect that decides whether the 0856
ruling can be honoured at all on the user's own bench.

## Why this one matters most

The user ruled: *"if OP is part of the run, then plot from OP."* On a raw whose
transient plot is written **first**, OP **is** part of the run and xschem cannot
reach it — so `annotate_op` falls through to the transient and, since the 0856
landing, publishes **nothing**. The user gets a blank schematic on a bench that
does contain the operating point they asked for. The original report was against
`tb_bandgap`, *a bench carrying both an OP and a TRAN analysis*.

## The measurement

One rawfile, two concatenated plots, identical vectors, measured on the landed
binary 2026-08-27. Only the **order** of the two plots differs.

**Transient first, Operating Point second — the op leg is never found:**

    raw_read(): no useful data found
    extra_rawfile() read: .../mixed.raw not found or no "op" analysis
    read-as-op   rc=0 -> 0 ; loaded=-1
    ... falls through to dc (also not found), then to tran ...
    points=3, vars=2, datasets=1 sim_type=tran
    update_op(): 'tran' is not an operating point database, publishing nothing
    annotate_op  text=VDNODE=0

**Operating Point first — found immediately:**

    Raw file data read: .../mixed2.raw
    points=1, vars=2, datasets=1 sim_type=op
    OP-FIRST mixed: loaded=0 annot=0 0 -1 text=VDNODE=1.77

So the reader does not **search** the file for the requested analysis; it
succeeds only when the requested plot happens to be the one it lands on first.
`xschem raw read <file> op` answers `0` with `loaded=-1` rather than reporting
that the file holds an `op` plot it declined to reach.

(The `VDNODE=0` in the first block is [0861](0861-spice-get-node-renders-a-fabricated-0-when-nothing-is-published.md),
a separate defect visible in the same trace.)

## Where to look

`raw_read()` / `read_dataset()` in `src/save.c` — the `Plotname:` scan and how
`extra_rawfile(1, f, "op", ...)` decides a file "has no op analysis". Note
`save.c:942` and `:989` already special-case `npoints > 1 && sim_type == "op"`
(the multi-point-OP -> `dc` rewrite), so the reader does walk plot headers; the
question is why a non-matching first plot ends the search.

## Interaction with the 0856 landing

Before 0856 this defect was **masked**: the fallback attached the transient and
published its t=0, which on many benches is close enough to the operating point
that nobody looked. The gate correctly stops publishing that number, which makes
this reader limitation **visible** for the first time. Fixing 0863 is what turns
the user's blank schematic back into the right numbers.

## Acceptance if fixed

1. `xschem raw read <tran-first mixed raw> op` attaches the **op** plot:
   `loaded=0`, `sim_type=op`, and the op leg's values, not the transient's.
2. **Positive twin.** The op-first ordering still works exactly as measured
   above (1.77).
3. `annotate_op` on the tran-first mixed raw puts the OP numbers on the
   schematic — the user's ruling, honoured end to end.
4. A raw genuinely holding no `op` plot still answers "no op analysis"; the
   search must not start inventing one.
5. Sabotage: restore the first-plot-only behaviour and confirm row 1 reds.
