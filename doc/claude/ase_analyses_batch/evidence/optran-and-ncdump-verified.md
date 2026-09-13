# Stage 10's two load-bearing claims, re-measured on BOTH binaries

Taken by the driver on **2026-09-13**, while the crews held the code. Both binaries:
`/usr/bin/ngspice` (**45.2**, apt) and `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(**46+**, the fork). The point of the exercise was that `PLAN.md` §10b rests on a number
measured once, in one place, on one binary — and this batch has already found two places
where 45.2 and the fork differ.

## 1. `optran`'s transient operating point — REPRODUCED, and identical on both

`evidence/an-core.md` §5.10's table reproduces exactly, on **both** binaries. Deck: 1 kΩ /
1 nF RC (τ = 1 µs) driven to 1 V, with `.options noopiter gminsteps=0 srcsteps=0`.

| optran settings | `v(out)`, 45.2 | `v(out)`, the fork |
|---|---|---|
| default `1 1 1 100n 10u 0` (10 τ) | `9.999550e-01` | `9.999550e-01` |
| `optran 0 0 0 50n 100u 0` (100 τ) | `1.000000e+00` | `1.000000e+00` |
| `optran 0 0 0 0 10u 0` (deselected) | run **fails**, rc 1 | run **fails**, rc 1 |

`1 - e^-10 = 0.99995460`. The operating point really is the transient value at
`opfinaltime`, and the two binaries agree to every digit printed.

## 2. ⚠ BUT "ON BY DEFAULT" IS NOT "USED BY DEFAULT", AND THE DIFFERENCE IS THE UI'S

The same RC, left alone, answers **`1.000000e+00` on both binaries** — with the shipped
defaults, and again with `option optran = 0 0 0 0 0 0`. The transient rung is reached only
when the rungs above it have failed:

* default: Newton converges at rung 1, and `optran` is never called;
* `option noopiter` alone: rung 1 is skipped, **gmin stepping succeeds at rung 2**
  (`Note: Starting dynamic gmin stepping` / `Note: Dynamic gmin stepping completed`, on
  stderr, both binaries), and `optran` is still never called;
* only `noopiter` **plus** `gminsteps=0 srcsteps=0` gets there.

So §10b's proposed sentence on the OP form — *"this operating point may come from a
transient"* — **must be conditional on the run having actually descended the ladder**, and
the run says so itself in the lines above. Said unconditionally it would tell a user their
exact operating point is suspect when it is exact, which is a worse failure than silence:
the first time they check it by hand, the pane loses its credibility for every case where
it is right.

The detectable events, measured:

| event | text | stream |
|---|---|---|
| rung 2 entered | `Note: Starting dynamic gmin stepping` | stderr |
| rung 2 succeeded | `Note: Dynamic gmin stepping completed` | stderr |
| rung 4 entered | `Note: Transient op started` | stderr |
| rung 4 succeeded | `Note: Transient op finished successfully` | stderr |
| rung 4 disabled | `Note: Optran is deselected.` | **stdout** |

⚠ **`Note:` lines are NOT all on one stream.** `PLAN.md` §10b already says to match on line
CONTENT rather than arrival order; this sharpens it — **never on the stream either**. Four
of these five are on stderr and the fifth is on stdout, in the same run.

## 3. `CKTncDump` — the table prints, and it can arrive with NO starred node

Stage 10a's whole premise is the `Last Node Voltages` table with a trailing ` *` on every
node still failing the convergence test. The table is real and it is on **stdout**:

```
DC solution failed -

Last Node Voltages
------------------

Node                                   Last Voltage        Previous Iter
----                                   ------------        -------------
in                                                0                    0
out                                               0                    0
v1#branch                                         0                    0
```

⚠ **Not one node in it is starred**, because this failure was "every rung disabled", not
"this node would not settle". **A parser that assumes at least one `*` will highlight
nothing and look broken**, and one that treats "table present" as "these nodes are the
problem" will highlight the whole circuit. Both arms need a test row.

Note also what the table contains: `v1#branch`, a **branch current**, sitting in a table of
node voltages. Whatever maps these names to canvas nets must not assume every row is a net.

## 4. What the failure costs the rest of the run

With the op unreachable, stderr carries:

```
Error: The operating point could not be simulated successfully.
    Any of the following steps may fail.!
doAnalyses: impossible error - can't occur
op simulation(s) aborted
```

and the batch run ends `Error: incomplete or empty netlist … no simulations run!` with
**rc 1**. Identical on both binaries. (`doAnalyses: impossible error - can't occur` is
ngspice's own text for a reachable state; it is not evidence of a defect in the deck, and a
diagnosis pane that quotes it verbatim will frighten people for no reason.)
