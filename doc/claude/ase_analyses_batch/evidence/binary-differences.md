# What actually differs between the two ngspice binaries — measured, 2026-09-13

⚖ **R11** ruled that ASE-L states **no version floor** and instead names the binaries it is
*tested against*. That sentence is only honest if somebody knows what the two binaries
actually do differently. This is that list, measured in one sitting by the driver while the
crews held the code.

The two:

* `/usr/bin/ngspice` — **ngspice-45.2**, apt, built 2025-09-12, KLU
* `/home/analog/dev/ngspice/build-ver_50/src/ngspice` — **ngspice-46+**, the fork,
  `--enable-pss --enable-cider`, `#define XSPICE 1`

## They DIFFER here

| # | what | 45.2 | the fork | why it matters |
|---|---|---|---|---|
| 1 | rawfile for **one saved op vector** | **2 variables**: `v(out)` **and `v(all)`** | 1 variable | issue 1434's "phantom duplicate column", now with its **name**: the `all` keyword leaks into the variable list. A reconciliation `over` verdict on 45.2 is expected here, and the extra column is identifiable by name rather than by counting. |
| 2 | the `meas` **echo line** | `1.000000e+00` (6 decimals) | `1.00000e+00` (5) | a golden or a parse keyed on digits passes on one and fails on the other. `print name` is byte-identical on both — use it. |
| 3 | **XSPICE event data** | `dig : d , 10` events; transition at `2.270000000e-08` | **11** events; `2.265000000e-08` | an event golden that pins counts or times is binary-dependent. |
| 4 | `pss` with **6** arguments | rc 0 | rc 1 | the analysis aborts on one and not the other; the process survives on both. Cosmetic beside #1–#3, recorded so nobody re-measures it. |

## They AGREE here — and the agreements are the load-bearing half

Every one of these was measured on both, in the same sitting:

* **`sp` exists and behaves identically** — same plot name, same mixed-case vector spellings
  (`S_1_1`, `Y_1_1`, `NF`, `NFmin`, `Rn`, `SOpt`), same two port refusals, same `exit(1)`.
  So S-parameter support is **not** a fork-only capability. (`evidence/sp-stage9.md`)
* **`optran`'s numbers agree to every digit printed** — `9.999550e-01` and `1.000000e+00`
  on both, and the same failure when it is deselected.
  (`evidence/optran-and-ncdump-verified.md`)
* **Seeded randomness agrees across the binaries**: `.options seed=7` gives the same netlist
  `agauss` draw and the same interpreter `sgauss`/`sunif` values on both, and `trrandom`
  under a seed gives the same number on both. So a **seeded** golden is portable.
  (`evidence/randomness-stage11.md`)
* **`trnoise` is unreproducible on both** — a different number every run under the same
  seed, on each binary. Identical *behaviour*, no usable number.
  (`evidence/events-and-trnoise.md`)
* **All four `meas` readback facts agree**: vector not variable, `meas … > file` writes,
  a failed measurement is silent to rc/`$sim_status`/stdout, and a deck-card `.measure`
  never becomes a vector. (`evidence/meas-readback.md`)
* **`pss` segfaults on four arguments on both** (rc 139). (`evidence/pss-stage14.md`)
* **`CKTncDump`'s table, and the ladder's `Note:` lines, are the same on both** — including
  the stream each one is written to.
* **XSPICE is compiled into both**, though neither banner says so.

## What this says about ⚖ R11's sentence

The differences are **four**, and three of them are about *how a number is printed or
counted*, not about what the simulator can do. Not one of them is a capability the older
binary lacks. That is the empirical case for R11's ruling: **a version number would have
refused work that 45.2 does correctly**, while the four real differences are exactly the
kind a probe or a tolerant parser handles.

⚠ It is also the case for keeping the two-binary rule. Every difference in the table was
found by running the same deck twice — none of them by reading source, and none of them
would have been visible to a test suite that ran on one binary. **A batch that verified on
one would have shipped a golden for #1, #2 and #3 and never known.**
