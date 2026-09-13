# Stages 12 and 13 measured on both binaries — the digital half, and what a seed does not reach

Taken by the driver on **2026-09-13** while the crews held the code. Both binaries:
`/usr/bin/ngspice` (**45.2**) and `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(**46+**, configured `--enable-pss --enable-cider`, `#define XSPICE 1`).

## Part 1 — Stage 12: event-driven results

### XSPICE is present in BOTH builds

Neither banner advertises it, so it has to be probed rather than read: an XSPICE chain runs
on both. The fork's `config.log` says `XSPICE features included`; 45.2 proves it by running
the deck.

### ⚠ The node list is an ARRAY, and the error for getting it wrong is good

```
aconv in dig adcmod          ->  Error on line 4 or its substitute:
                                 Missing [, an array connection was expected
aconv [in] [dig] adcmod      ->  runs
```

An emitter that writes the bare form gets a refusal with a clear reason, not a crash —
unlike `pss` (see `evidence/pss-stage14.md`). Worth knowing which failures are cheap.

### Event data lives in a SEPARATE namespace from vectors

```
=== edisplay ===
List of event nodes in plot tran1
    node name           : type , number of events
    dig                 : d    ,    10

=== eprint dig ===
**** Results Data ****
Time or Step
dig

0.000000000e+00    0s
1.320000000e-09    Us
2.000000000e-09    1s
2.270000000e-08    Us
```

`display` does **not** list `dig`; `edisplay` does. So every piece of ASE-L machinery that
reasons about *vectors* — the Outputs list, the Value column, the plotmap sidecar and its
reconciliation verdicts — is **blind to event nodes by construction**. A digital node cannot
be saved, plotted or counted through the analog path, and Stage 12 either teaches those
surfaces a second namespace or says plainly that it does not.

Values carry a **strength suffix**: `0s`, `1s`, `Us` (unknown). Users will ask.

### ⚠ AND THE EVENT DATA IS BINARY-DEPENDENT

| | 45.2 | the fork |
|---|---|---|
| events on `dig` | **10** | **11** |
| third transition | `2.270000000e-08` | `2.265000000e-08` |

Same deck, same run. **An event golden that pins counts or timestamps passes on one binary
and fails on the other** — the same shape as the `meas` echo line in
`evidence/meas-readback.md`. Assert the shape (a transition happened, in this order, within
a tolerance), never the exact time or the count.

## Part 2 — Stage 13: ⚠ THE SEED GOVERNS `trrandom` AND DOES NOT REACH `trnoise`

One deck, two sources — `v1 … trrandom(2 10n 0 1)` and `v2 … trnoise(1m 10n 0 0)` — with
`.options seed=5`, run **three times on each binary**:

| | 45.2, runs 1–3 | the fork, runs 1–3 |
|---|---|---|
| `v(in)[50]` — **trrandom** | `1.031261e+00` ×3 | `1.031261e+00` ×3 |
| `v(n2)[50]` — **trnoise** | `1.407468e-03`, `-8.09163e-04`, `-1.54499e-04` | `-3.79019e-04`, `1.067496e-03`, `-4.78590e-05` |

**`trrandom` under a seed is reproducible run to run AND across the two binaries.**
**`trnoise` under the same seed is not reproducible at all** — a different number every
single run, on both.

So, for Stage 13:

* a **`trrandom`** bench can carry a committed value golden, and it will hold on both
  binaries;
* a **`trnoise`** bench **cannot**, not even on one binary with one seed. Its rows must
  assert deck content, or statistics with a tolerance, or the mere presence of noise — never
  a number;
* and any UI sentence promising that *"a seed makes the run repeatable"* is **false for
  `trnoise`** and must not be said on a `trnoise` row.

⚠ This corrects the reading a reasonable person takes from `evidence/randomness-stage11.md`
§2, which measured `.options seed=<n>` making netlist `agauss` and interpreter
`sgauss`/`sunif` reproducible. That is true of those three and **not** of `trnoise`. The
first pass of this measurement compared one seeded run per binary, saw two different
numbers, and was about to record *"trnoise disagrees across binaries"* — which is true but
is not the finding. Repeating on the **same** binary is what turned it into the right
sentence.
