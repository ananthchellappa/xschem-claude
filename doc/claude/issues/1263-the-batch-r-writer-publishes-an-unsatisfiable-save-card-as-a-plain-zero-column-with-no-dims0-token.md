# 1263 — the batch `-r` writer publishes an unsatisfiable save card as a plain zero column, with **no `dims=0` token**

**Filed** 2026-09-02 by item **A6**'s write-up, from the **adversary pass's own
refutation of A6-b** and re-measured by the write-up agent before filing.
**Status: OPEN. Item B1 inherits it.**
**⚠ This issue is why item A6 is recorded as a PARTIAL close of 1259.**

## What A6-b believed

Issue **1259**, the item brief and `1244_op_param_list_measurements.md` §22 all
say the same thing, and §22 says it in one sentence:

> `dims=0` — not stderr — is the only detector.

A6-b was built on that sentence. `src/save.c`'s `raw_line_dims_zero()` parses the
`dims=0` token out of the third tab-separated field of each `Variables:` line,
records one byte per column in `Raw.dims0`, and `raw_vector_absent()` publishes
it; `xschem raw value <v> -1` then answers **empty** for such a column, so the
row renders blank and A5-a's value gate correctly stays closed.

## What is actually true

**`dims=0` is the detector for the `.control` + `write` flavour only.** On
**xschem's own shipped simulate command** it does not appear at all.

`src/xschem.tcl:3854`:

```tcl
set_ne sim(spice,2,cmd) {ngspice -b -r "$n.raw" "$N"}
```

Measured 2026-09-02, `/usr/bin/ngspice` 45.2, BSIM4 (`level=14 version=4.8.1`),
`.options savecurrents`, run exactly that way:

```
Variables:
        0       v(d)    voltage
        1       v(g)    voltage
        2       i(vg)   current
        3       i(vd)   current
        4       i(@m1[id])      current
        5       i(@m1[is])      current
        6       i(@m1[ig])      current
        7       i(@m1[ib])      current

$ grep -ac 'dims=' sc.raw
0
$ head -3 sc.err
Warning: unrecognized variable - @m1[is]
Warning: unrecognized variable - @m1[ig]
Warning: unrecognized variable - @m1[ib]
```

and read back through the A6 binary:

```
PT0 i(@m1[id]) = 0.00031215789
PT0 i(@m1[is]) = 0
PT0 i(@m1[ig]) = 0
PT0 i(@m1[ib]) = 0
```

`is`, `ig` and `ib` are **ordinary `current` columns of 0.0**. Nothing in the
file distinguishes them from `id`. The only signal is on **stderr**, which
xschem never reads, and which is discarded by the batch runner.

## Consequences, in order of sharpness

1. **The literal headline of A6-b is not closed on this path.** "A published zero
   satisfies the gate, so a `savecurrents` run still declutters" — on
   `ngspice -b -r` it still does. `raw_vector_absent()` answers 0 for every one
   of those columns, `op_annot::raw_or_blank` returns `0`, the block mints
   `ib = 0`, `annot_block_has_value()` returns 1 and the device is decluttered:
   the user trades `W=1u` and the pin labels for a column of fabricated zeros.
2. **The ACCEPT row's third absent state is unhandled.** The brief names three
   absent flavours — no vector, zero-length, `dims=0`. A6 closes `dims=0` and
   "no vector" (already closed by A5-a). **Zero-length never arrives as
   zero-length**: it arrives either as no raw at all (issue **1264**) or, here,
   as a column byte-identical to a measured zero.
3. **§22's own design conclusion is weakened.** §22 argues for a
   probe-and-prune warm-up keyed on `dims=0`. Ruling **D-5** already rejected
   probe-and-prune for other reasons; this measurement shows the detector it
   would have keyed on is absent on the path xschem uses, so D-5's rejection is
   now over-determined.
4. **The same parameter reads differently depending on how it was simulated.**
   Blank after an ASE `.control`+`write` run; `0` after a built-in batch run.
   That inconsistency is new with A6 and is on the user's ruling queue.

## What would close it

Not the raw reader — the carrier is not in the file. Candidates, none taken here:

* **the deck generator** — do not emit a `.save` card for a parameter the model
  does not publish. This is the `1244_op_param_list_measurements.md` §21/§22
  territory and is where B1's descriptor work already lives.
* **read the simulator's stderr.** `Warning: unrecognized variable - <name>` is
  emitted once per unsatisfiable card and names the vector exactly. It is a
  second source outside the raw, so it must be recorded at simulate time and
  carried alongside the raw, not asked for from inside the gate (that is issue
  **0466**, and row A35 reds on it).
* **do nothing, and accept that the fabricated zero is indistinguishable.** This
  is the honest status quo on the `-r` path, and it is what ships today.

`raw_vector_absent()` (`src/save.c`, prototype in `src/xschem.h`) is the seam:
whatever closes this should widen that one predicate, not build a second
detector — invariant **I1**, and two independent answers to one question is how
issue 1252 became issue 1260.

## Still open

Everything above. Item **B1** inherits it; PLAN.md's B1 entry now says so.
