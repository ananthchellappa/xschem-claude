# `sp` before Stage 9 opens — measured, on both binaries

Taken by the driver on **2026-09-13**, in a scratch directory outside the repository,
while Stage 8 was in flight. Both binaries: `/usr/bin/ngspice` (**45.2**, apt) and
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (**46+**, the fork). **Every result
below was identical on the two**, which is itself the first finding.

Test circuit: a resistive two-port attenuator, ports declared the ngspice way —
`v1 in 0 dc 0 ac 1 portnum 1 z0 50`.

## 1. `sp` runs on BOTH binaries, so it is not a fork-only capability

`sp lin 11 1meg 100meg` completes with rc 0 on 45.2 as well as on the fork. Stage 9 still
**probes** rather than assuming — that is the batch's standing rule and the reason is that
a probe is true about the binary in front of the user, not about the one measured here —
but nobody should plan around `sp` being new.

## 2. What it puts in the plot, and the spelling matters

Plot: `sp1 (SP Analysis)`. Vectors, in ngspice's own capitalisation:

```
    S_1_1 / S_1_2 / S_2_1 / S_2_2   : s-param,    complex
    Y_1_1 / …                        : admittance, complex
```

With the optional noise flag (a trailing `1`: `sp lin 3 1meg 100meg 1`) the plot also
carries **`NF`, `NFmin`, `Rn`, `SOpt`**.

⚠ **AND THE CASE DIFFERS BETWEEN THE BINARIES — IN THE RAWFILE, NOT IN `display`.** Measured
2026-09-13 after Stage 9's crew reported it and the driver re-measured both places:

| | `display` says | the written rawfile says |
|---|---|---|
| apt 45.2 | `S_1_1` | **`s_1_1`** |
| the fork | `S_1_1` | `S_1_1` |

So an interactive listing agrees on both and **the file does not**. Anything that reads an
S-parameter vector **out of the results file** must be case-insensitive, and this is the sixth
measured difference between the two binaries — see `evidence/binary-differences.md`.

⚠ **These names are MIXED CASE and carry underscores.** Anything that lowercases a vector
name on the way in or out — the Outputs list, the plotmap sidecar, the reconciliation
`mislabel` verdict from Stage 6 — will disagree with the results file about what the plot
is called. That is the exact shape `mislabel` was written to catch, so it should catch
this; Stage 9 should prove it does rather than assume it.

## 3. The preconditions, measured — and they are REFUSALS, not cautions

| what is wrong | what ngspice says (stderr) | rc |
|---|---|---|
| no source carries `portnum` | `Error: No RF Port is present, cannot run sp analysis` | **1** |
| exactly one port | `Error: Only one RF Port is found, we need at least two!` | **1** |

⚠ **BOTH KILL THE WHOLE DECK, NOT JUST THE ANALYSIS.** The message is followed by
`ERROR: fatal error in ngspice, exit(1)` and **the control block never reaches the next
line** — the `echo` after the `sp` command never printed. So every analysis after `sp`
dies with it, including `op`, which this batch keeps LAST in emit order (0964) precisely
so it is not disturbed by what came before.

That settles the class: an `sp` row with fewer than two ports must be a **refusal** that
stops the run before the deck is written, in the shape Stage 5 established, never a
caution that lets the run proceed.

`z0` may be omitted — two ports with `portnum` and no `z0` run fine and answer
`s_1_1[0] = 1.515152e-01,0.000000e+00`, i.e. the 50 Ω default is applied silently.

## 4. Sweep spellings

`sp` takes `dec`, `oct` and `lin` exactly as `ac` does, plus the optional trailing noise
flag. So the `sweep`/`points` field pair and its `labels` table — the one that makes
`Points per decade` become `Number of points` when the mode changes (issue 1417) — is
reusable as it stands.

## 5. ⚠ THE FIXTURES ALREADY EXIST IN THIS TREE, AND THEY ARE EVIDENCE OF THE GAP

Four benches under `ihp-sg13g2/xschem_libs/sg13g2_tests_ase/` are S-parameter benches:
`sp_mim_cap`, `sp_rfmim_cap`, `sp_parasitic_cap`, `sp_svaricap_test` (and their twins
under `sg13g2_tests/`). Their schematics carry `portnum 1 z0 50` and `portnum 2 z0 50` on
the sources, so the netlist side is already right.

And their committed ASE-L state says what the gap costs:

```
analyses {{type op enabled 0} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}
```

**An S-parameter bench whose ASE-L state cannot say `sp`** — four seeded rows, none of
them the analysis the bench exists for, because ASE-L has no way to express it. Somebody
built these and then had to drive the simulator by hand.

⚠ Those `.state` files are inside the **104 that must round-trip byte-identically**, so
Stage 9 adds `sp` to the registry **without touching them**. Enabling `sp` on one of them
is a user gesture, not a migration.
