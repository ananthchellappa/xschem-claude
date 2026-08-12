# 0319 — Ctrl-Alt-V on a FET inside a descended instance neither ticks `Show device internals` nor reaches the device

**Status:** OPEN. Not fixed. Reported by hand with an exact repro; the mechanism
below is a **located hypothesis, NOT a measurement** — see "What is not yet
known".
**Area:** `src/wave_viewer.tcl` — two-pane item 18's auto-unhide probe (R12) in
`browser_show_path`, and whatever builds the asked path `segs` for a selected
**primitive** instance.
**Found:** 2026-08-12, by the user, eyeballing two-pane **item 18**. That item's
LEDGER row stays **unticked** and its verdict is **NOT OK** because of this.
**Related:** two-pane item 18 (`18_receipt.md`, `6c887aed` + `91a3de1a`), item 13
(the descend-aware show, which the same session eyeballed **OK**), issue 0217
(the declass rule that decides what a device contributes to a path).

## What happens

```
xschem load {/home/qflow/dev/xschem/claude_1/xschem/sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch}
```
then load `ngspice_state1`.

**The part that works.** Descend into `x1`, select `x1` on the bandgap schematic,
press **Ctrl-Alt-V** — the Signal Browser finds `x1` correctly.

**The part that does not.** Descend into `x1` (inside the bandgap, an instance of
`bandgap_opamp`), then select a **FET such as `M18`** and press **Ctrl-Alt-V**:

* `Show device internals` **does not tick itself**, and
* the navigator pane selects only `x1 > x1` — the parent, not the device.

Item 18's whole promise is that this gesture ticks the box on the user's behalf
and says so in the status line. On this cell it silently lands on an ancestor.

Verbatim: *"if I then select a FET such as M18 and do CTRL-ALT-V, the Show device
internals does not get checked and it only selects x1 > x1 in the Signal Browser
navigator pane."*

## Where it stops

`browser_show_path`'s R12 probe ticks the box only on a **positive, exact** test:

```tcl
  if {$matched < [llength $segs] && ![wviewer::browser_devint $token]} {
    ... rebuild the would-be model with internals SHOWN, in memory ...
    if {$pmatched == [llength $segs]} {
      ... $bx invoke ; re-resolve ; set r12 1
    }
  }
```

The `==` is deliberate and defended at length in the source (relaxing it to `>`
ticks the box, triples the tree 45 → 129 and explains nothing; `BK43` guards
that). So the box not ticking means **`pmatched` never reached
`[llength $segs]`**: even with device internals shown, the asked path does not
fully resolve. The gesture then correctly falls through to improve-or-restore and
lands on the deepest ancestor it *can* reach — `x1 > x1`, exactly what was seen.

So the defect is upstream of the tick: **the asked path for this FET is not a
path the raw's own names can produce.**

## The hypothesis, and why it is only that

Item 18 was built and measured on `x1.x1.xm1.…` — an **`X`-prefixed, pcell-wrapped**
device, which is what sky130's `sky130_fd_pr__nfet_01v8` instances look like in a
raw: `v(m.x1.x1.x1.xm1.msky130_fd_pr__nfet_01v8#body)`, where `xm1` survives
0217's declass as a genuine **path segment**.

`M18` is an `M`-prefixed instance. Per 0217, SPICE requires *subcircuit*
instances to begin with `X`, which is the whole basis of the declass rule — so an
`M` instance is a primitive, and its internal nodes plausibly hang off the
**parent** level with the device fused into the **leaf**, contributing no path
segment at all. If so, a `segs` list built from the schematic hierarchy
(`x1`, `x1`, `m18`) can never match a rows model whose deepest real segment is
`x1.x1`, with or without internals shown — and `pmatched` stalls one short
forever.

## What is not yet known — do not skip this

1. **The actual raw names for `M18` in `ngspice_state1` have not been read.** The
   paragraph above is inference from 0217's grammar argument, not a measurement.
   First step for whoever takes this: `xschem raw list` in that context and grep
   for `m18` / `xm18` / `@m.` to see what segment, if any, the device produces.
2. **Whether `segs` is built from the schematic instance name or from something
   else** for a primitive — locate the producer before touching the probe.
3. **Whether item 18 is wrong or merely narrower than advertised.** If a primitive
   genuinely has no path segment, then "reach the device" is not expressible for
   it and the honest fix is a *different sentence* (land on the parent and say
   the device's internals live at that level), not a relaxed `==`.
4. **Whether descending matters at all.** The report descends first; it is not
   established that the same selection from the top level behaves differently.
   Worth one control run, because item 13's descend path eyeballed OK.

⚠ **Do not "fix" this by relaxing the `==` to `>`.** That edit is named in the
source as the one that ticks the box, triples the tree and says nothing —
`BK43` exists to red it.
