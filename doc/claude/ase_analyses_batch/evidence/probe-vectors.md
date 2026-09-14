# What `.probe` actually names, and the device it inserts — debt **M7**, answered

**Measured 2026-09-13 by the driver**, on `/usr/bin/ngspice` (apt 45.2) **and**
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (the fork), one deck, `display` and the
written rawfile both read. M7 was due *"before Stage 10"* because the Outputs column is keyed on
these names, and the debt recorded that the manual's §11.6.5 spellings had **never been verified
against source or a run by anyone**.

They are correct. And the run turned up two things the manual does not mention, one of which
matters to this batch's own rules.

## The deck

```
.subckt amp a b
rin a b 1k
.ends
v1 in 0 1
x1 in mid amp
r2 mid 0 1k
m1 0 0 0 0 nm w=1u l=1u
.model nm nmos level=1
.probe p(x1)
.probe vd(r2)
.probe p(r2)
.probe p(m1)
.probe i(v1)
```

## The names, from the rawfile's `Variables:` block — **identical on both binaries**

| what was asked for | the vector, in `display` | in the rawfile | type |
|---|---|---|---|
| `.probe p(x1)` — a **subcircuit instance** | `x1:power` | `x1:power` | `power` |
| `.probe p(r2)` | `r2:power` | `r2:power` | `power` |
| `.probe p(m1)` | `m1:power` | `m1:power` | `power` |
| `.probe vd(r2)` | `vd_r2` | **`v(vd_r2)`** | `voltage` |
| `.probe i(v1)` | `v1#branch` | `i(v1)` | `current` |

⚠ **`p(<instance>)` really does answer `<instance>:power`, including for a subcircuit `x`** — which
is the half of M7 the manual asserted and nobody had run. The `:power` names are written **bare**,
not wrapped: `x1:power`, never `p(x1)`.

⚠ **The differential voltage is a NODE, not a device quantity.** `vd(r2)` becomes a node called
`vd_r2`, so the rawfile writes it **`v(vd_r2)`** and a plot expression must wrap it like any other
node. The manual's `vd_R1` spelling is right modulo case, and case here follows the **deck** — the
parser folds it — rather than being generated with capitals the way the S-parameter matrix is
(`evidence/sp-stage9.md` §2a), so this family shows **no difference between the two binaries**.

## ⚠ 1. `.probe vd(...)` ADDS A DEVICE TO THE CIRCUIT

The same deck with the `.probe vd(r2)` line removed produces **no `ediff2` vector at all**. With
it, the plot carries an extra branch current:

```
    ediff2_r2#branch    : current, real, 1 long      (display)
    i(ediff2_r2)        : current                    (rawfile)
```

ngspice inserts an **E-source** named `ediff2_r2` to compute the difference. So a differential
probe is not a passive observation: **it changes the netlist**, and it puts a vector in the results
file that no user asked for and that names a device that is not on their schematic.

That matters here for two reasons. It is a **capability the adapter must declare rather than ASE-L
assume** — a simulator whose differential probe is passive would need no such warning. And it is
squarely inside this batch's own rule that *nothing the deck contains may be unshowable*: the
`ediff2_*` vectors will appear in the Outputs list unless something accounts for them, and a user
who sees `i(ediff2_r2)` beside their own signals has no way to know what it is.

## ⚠ 2. `.probe i(v1)` ON A SOURCE PRODUCES A DUPLICATE NAME

`v1#branch` is listed **twice** by `display`, and the rawfile carries **two** variables both
called `i(v1)`:

```
    5   i(v1)   current
    6   i(v1)   current
```

The branch current of an independent source already exists without being asked for, so the probe
adds a second vector with the same name. Any reader keyed on **names** — the Outputs list, the
plotmap sidecar, `ase::raw_vectors_present` — meets a collision here, and a `dict` keyed on the
name silently keeps one of them. Nothing in this tree has been measured against that case.

## What this settles, and what it leaves

* **M7 is closed** on its own terms: the spellings are confirmed, on both binaries, from both
  `display` and the rawfile.
* **Two new facts** are recorded above, and neither is in the manual. The inserted `ediff2_*`
  device is the one with a design consequence for Stage 10's Outputs column.
* **Not measured:** whether the duplicate `i(v1)` survives into ASE-L's own readers, and what the
  `:power` family does under hierarchy (`p(x1.x2)`), and whether `vd()` between two arbitrary nodes
  spells its node differently from `vd(<device>)`. None of those blocks Stage 10; they are listed so
  the next person does not re-derive the part that is done.
