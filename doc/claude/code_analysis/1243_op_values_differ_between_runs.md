# Why the annotated operating point differs between two runs of `tb_bandgap`

**Measured 2026-09-02**, against the user's own artifacts:
`~/.xschem/simulations/tb_bandgap_ase.{spice,raw,log}` and ngspice-45.2.

## What was reported

> What gets annotated for M2 and M18 in x1/x1 differs if I have only OP or
> OP AND TRAN enabled in the ASE-L. Also, for VBG at the top level, if only OP
> is enabled, it annotates 1.183. If OP and TRAN are enabled, it annotates
> 1.135.

Three candidate causes were checked. **The first two are cleared by
measurement; the answer is the third, and it is in the testbench.**

## 1. Is xschem reading the wrong plot out of the multi-plot raw? — NO

With both analyses enabled the deck writes one raw holding two plots
(`set appendwrite`). Read straight off the user's own 69 MB results file:

| plot | points | vars | `vbg` |
|---|---|---|---|
| `Transient Analysis` | 20514 | 424 | `4.4965e-19` at t=0, **`1.1892032088`** at t=200 µs |
| `Operating Point` | 1 | 891 | **`1.1350018660628125`** |

The number on the schematic was **1.135**. That is the `Operating Point`
plot's own value, to every digit it was printed to. `xschem raw read <file> op`
picked the right plot and `update_op` published the right point.

## 2. Does running `op` after `tran` change the operating point? — NO

The 0964 reorder makes the operating point run **last** when its device requests
move inside `.control`, so the obvious suspicion is that ngspice's `op` inherits
the transient's end state. Controlled test — one run, one deck, the same random
draw, `op` both before and after a 5 µs transient:

```
.control
op
print VBG v(vcc) v(start)
tran 10n 5u
op
print VBG v(vcc) v(start)
.endc
```

| run | op BEFORE the transient | op AFTER the transient |
|---|---|---|
| 1 | `vbg = 1.146684e+00` | `vbg = 1.146684e+00` |
| 2 | `vbg = 1.202065e+00` | `vbg = 1.202065e+00` |

**Byte-identical within each run.** The analysis order does not move the
operating point. (Note also how far apart the two RUNS are — that is symptom 3.)

The transient's *final* value differs from the operating point for a plain
circuit reason, not a bug: in the user's own raw, `v(start)` is **0 V** at
t = 200 µs and **1.816 V** in the operating point, because the startup source
`V4 START VSS pwl 0 'VCC' 25u 'VCC' 25.001u 0` drops START at 25 µs and its DC
value is the t=0 one. The two are different bias conditions, so 1.189 and 1.135
are both correct answers to different questions.

## 3. The supply is randomised on every run — THIS IS IT

The netlist carries, at lines 321–323:

```spice
.param ABSVAR=0.03
.param VCCGAUSS=agauss(1.8, 'ABSVAR', 1)
.param VCC=VCCGAUSS
```

`agauss` draws a **new Gaussian sample on every ngspice invocation** — 1.8 V
with a 3 % 1σ. Every run is a different supply, so every run is a different
bandgap output. Measured across five invocations of the user's own deck:

| run | `v(vcc)` | `vbg` |
|---|---|---|
| user's recorded run | 1.816096 | 1.135002 |
| a | 1.842830 | 1.223263 |
| b | 1.786175 | 1.175313 |
| c | 1.818745 | 1.146684 |
| d | 1.785087 | 1.202065 |

"OP only" and "OP and TRAN" are **two different runs**, so they are two
different supplies. The 1.183 → 1.135 the user saw sits inside the spread above,
and so does the difference in what M2 and M18 annotate — every device's
operating point moves with the supply.

**Nothing in xschem or ASE-L is involved.** To compare two runs the testbench
has to stop rolling the dice: set `.param VCC=1.8` (or seed the generator) for a
nominal run and keep `agauss` for the Monte Carlo sweep it was written for.

## What WAS a defect in the same report

The third symptom — *"in the ASE-L output pane, nothing is displayed for values
if both OP and TRAN are enabled"* — is real, and is issue **1243**.
