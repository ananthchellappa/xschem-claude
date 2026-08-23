# 0620 — ngspice already has a Spectre-`dcOpInfo` equivalent (`show`), and S3/S4 should decide about it before emitting 78 save cards

STATUS: **OPEN — measured 2026-08-22** while answering the user's question
"does ngspice need to be updated to support what we want (like spectre)?".
Directly informs plan steps **S3** (`op_annot::save_cards`) and **S4**.
Related: 0617 (the user-visible symptom), spec §3 rule R1.

---

## The question

> "Do I read correctly that ngspice needs to be updated to support what we want
> (like spectre)? An OP run with save=all MUST make OP info available"

## Answer: no update needed. ngspice has the data; it has TWO delivery channels and XSCHEM reads only one.

All measured on `ngspice-46+`, level-1 MOS, throwaway decks under
`<scratch>/ngq/`. Reproduce with the decks in that directory.

### Channel 1 — the raw file. `save all` genuinely does not carry OP info.

```
deck a:  .save all              -> Variables: v(d) v(g) i(vg) i(vd)                    [4]
deck b:  .save all @m1[gm] @m1[gds] @m1[vth]
                                -> ... + @m1[gm] @m1[gds] v(@m1[vth])                  [7]
```

So **rule R1 is confirmed exactly as the spec states it**, and the user's
expectation ("save=all MUST make OP info available") does not hold for ngspice.
Two follow-ups, both measured, both worth knowing:

- **There is no wildcard.** `.save all @m1[all]` emits
  `Warning: unrecognized variable - @m1[all]` and creates a junk
  `v(@m1[all])` vector. One card per device **per parameter** is the only form.
- **`.option savecurrents` is real but partial.** It adds `i(@m1[id])`,
  `i(@m1[is])`, `i(@m1[ig])`, `i(@m1[ib])` for every device with no per-device
  cards — **terminal currents only**. No `gm`, no `gds`, no `vth`, no `vdsat`.

### Channel 2 — `show`. This is the one that behaves like Spectre.

A bare `show` inside a `.control` block, after `op`, with **no save cards at
all**, dumps every operating-point parameter of every device:

```
 Mos1: Level 1 MOSfet model with Meyer capacitance model
     device               m.x2.m1               m.x1.m1
      model                    nm                    nm
         id               0.00015               4.5e-05
        vgs                  1.35                     1
        von                   0.7                   0.7
      vdsat                  0.65                   0.3
         gm                0.0003                0.0003
        gds               0.00035                     0
   ... (25 rows for MOS, then a block per device class: Vsource, Resistor, ...)
```

Three properties that matter for S3/S4, all measured:

1. **Hierarchical names match ours.** `m.x2.m1`, `m.x1.m1` — the same convention
   as `get_fqdevice()` / `op_annot::devpath`. No name mapping needed.
2. **It redirects to a file from inside the control block.** `show > shw.txt`
   wrote 2504 bytes; works under `ngspice -b`.
3. **It needs no parameter list.** Every parameter the device model exposes
   appears, so a PDK descriptor would no longer have to enumerate them, and a
   parameter nobody thought to save is present anyway.

## So the real design question for S3/S4

| | A — save cards (the plan as written) | B — `show > <cell>.opinfo` |
|---|---|---|
| deck cost | **one card per device per parameter** — 78 for 13 FETs; a 500-device block is 3000 cards | one `.control` block, constant |
| lands in | the raw, readable by `xschem raw value <v> -1` today | a **text file**, needs a new ingest path |
| parameter set | exactly what the descriptor names | everything the model exposes |
| per-PDK work | a descriptor per PDK | none |
| risk | R2 — any explicit `save` cancels save-everything, so I2's `save all` is mandatory | text parsing; column-major, one block per device class |
| analyses | works for `op`, `dc`, `tran` (vector per timepoint) | **operating point only** — no per-timepoint history, so S11's cursor-follow does not work off it |

The last row is decisive and is why **this issue does not overturn the plan**:
S11 already shipped cursor-following device rows on a `tran` raw, and `show` has
no timepoints. **A is still the primary mechanism.**

But B is a strong second channel for the pure-OP case the user was actually
running, and it removes the card explosion, the descriptor maintenance and the
"a parameter nobody saved" hole. It also gives 0617 a much better remedy
sentence.

**What S3/S4 owes: a written decision.** Take A, take B, or take A with B as the
`op`-only fast path — and record which, with this measurement, in the spec. Do
not let S3 emit 78 cards without someone having read this table.

## Landmines

- Do not assume `show`'s parameter *names* match a PDK's. Measured here on
  level-1: `show m1 : vth` printed `?????????` — level 1 calls it `von`. A
  descriptor is still needed to map display rows to model parameter names, for
  either channel.
- `show`'s output is **column-major with one column per device**, and the
  columns are in ngspice's internal order, not the deck's. A parser must key on
  the `device` row, never on position.
- The blocks are per device *class* (`Mos1:`, `Vsource:`, `Resistor:` …). A file
  with several MOS levels has several MOS blocks.
- `.control` blocks in an ASE-generated deck interact with whatever `ase.tcl`
  already emits — check for an existing `.control` before adding one.
