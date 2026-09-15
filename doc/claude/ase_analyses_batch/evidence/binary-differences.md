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
| 3 | **XSPICE event data** | `dig : d , 10` events; transition at `2.270000000e-08` | **11** events; `2.265000000e-08` | an event golden that pins counts or times is binary-dependent. ⚠ **The count difference is deck-dependent; the time difference is not** (2026-09-15, receipt 47 C4): on M9's `adc_bridge → d_inverter → dac_bridge` deck the counts were **equal** (7/7, 12 timestamps) while every time moved by up to 7.5 ps (`evidence/m9-event-vcd-attach.md`, finding 4). Not a contradiction — two decks. Pin neither. |
| 4 | `pss` with **6** arguments | rc 0 | rc 1 | the analysis aborts on one and not the other; the process survives on both. Cosmetic beside #1–#3, recorded so nobody re-measures it. |
| 6 | **S-parameter vector names in the WRITTEN RAWFILE** | `s_1_1` … **lowercase** | `S_1_1` … **mixed case** | measured 2026-09-13, after Stage 9's crew found it and the driver re-measured. ⚠ **`display` says `S_1_1` on BOTH** — the difference exists only in the file, which is the half a reader parses. Anything reading an S-parameter out of a results file must be case-insensitive. |
| 5 | **`set measureprec=10`** / `NGSPICE_MEAS_PRECISION=10` | **accepted and INERT** — `meas` still prints `-7.851545e-01` | **honoured** — `-7.8515453642e-01` | measured 2026-09-13 while collecting Stage 8 task 1, both controls, same deck. The older binary **takes the setting without complaint and ignores it**, which is worse than refusing it: a UI that offers "more digits" gets silence and no digits. |
| 7 | **the point count of an identical transient** | `tran 1u 20u` → **118** points | the same deck → **121** | measured 2026-09-13 paying debt M8. The timestep controllers disagree, so **any golden that pins a transient point count is build-dependent**. ⚠ **And `set interp` removes the difference**: both binaries answer exactly **21** with it on. That makes `interp` the one setting that buys reproducibility across builds — which is a better argument for offering it than the one the plan gives. ⚠ **Larger under transient noise** (Stage 13 task 1, issue 1466, C8): `tran 1u 1m` with a `trnoise` source at `TS = 1u` gives **4415** points on 45.2 and **5008** on the fork, at `TS = 100n` **44116** against **50008** — ≈ 4.4 points per noise interval against 5, a 12 % gap, where at `TS = 10u` both give 1309. A noise point estimate is worded as an estimate for that reason. |
| **8** | ⚠ **`var()` IN A `.param` EXPRESSION** | **the run DIES** — `Undefined parameter [var]`, `Formula() error.`, **rc 1** | `@r1[resistance] = 4.700000e+03` | measured 2026-09-13 collecting issue **1462**. It is ngspice `aa1242ac7`, 2025-10-16, **fifty commits after 45.2**, first in ngspice-46 — and **the current Ubuntu LTS ships 45.2**. ⚠ **The most consequential difference in this table**: `PLAN.md` §11a's whole campaign design rested on it, and a feature verified on the fork alone would have **exited 1 on every shard** for most users. The design became *nominal deck plus a one-line diff per shard* because of this row. |
| **9** | ⚠ **`eprvcd` GIVEN AN ANALOG ARGUMENT** — `eprvcd din dout v(in)`, with or without `-a` | **the process ABORTS** — `*** buffer overflow detected ***: terminated`, **rc 134**, VCD **0 bytes** | rc 0, a valid VCD with `$var real 1 # v(in)` | measured 2026-09-15 paying debt **M9** (`evidence/m9-event-vcd-attach.md`). **`-a` with event nodes only is safe on both**; the trigger is the analog name. So Stage 12's emission names **only what `edisplay` reported** — a line verified on the fork alone would kill every mixed-signal run on the stock binary. `SIGABRT` puts it in `fork-dependencies.md` §5's B1 family: avoided by construction, never probed. |

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
* **`eprvcd` directly after a `tf` segfaults on both** (rc 139, VCD 0 bytes), while after a `dc`
  it writes the same VCD on each (225 / 224 bytes). Found by Stage 12's sabotage T13 (issue
  **1465**), re-confirmed by the driver on the fork only — see `CREW_BRIEF.md` on never crashing
  the user's simulator. It is why the export line follows a transient and nothing else.
* **`CKTncDump`'s table, and the ladder's `Note:` lines, are the same on both** — including
  the stream each one is written to.
* **XSPICE is compiled into both**, though neither banner says so.
* **CIDER is in both too** — a `numd level=2` card is parsed and reaches the mesh reader on
  each, failing identically (`Fatal error: y.mesh card list is empty`) on a deliberately
  incomplete mesh. Only the fork's config names `--enable-cider`; the apt build has it
  anyway, which is exactly why capability is probed and not read off a build flag.

## What this says about ⚖ R11's sentence

⚠ **CORRECTED 2026-09-15 (receipt 47 C4): this paragraph was written when the table had six rows, and it
now has nine.** Five of them (#1, #2, #3, #6, #7) are about *how a number is printed, named or counted*;
#4 is one analysis aborting on one argument count; #5 is a control accepted and ignored. **#8 and #9 are
different in kind: each makes a whole run die on 45.2** — `var()` in a `.param`, and an analog name on the
`eprvcd` line. **Still not one of them makes an analysis unavailable**, and ASE-L avoids both by construction
(a campaign is a nominal deck plus a one-line diff; the export names only event nodes), which is the argument
below, not against it.

⚠ The honest exception is **#5**: `measureprec` is a control 45.2 **accepts and ignores**, so
in that one respect the older build genuinely cannot do something the fork can. It does not
change the ruling — it sharpens it. A version floor would still be the wrong instrument,
because what a caller needs to know is *"does raising precision work on the binary in front
of me?"*, and only a probe answers that. A version number would also have refused every
analysis on a build whose only shortfall is the number of digits it prints. That is the empirical case for R11's ruling: **a version number would have
refused work that 45.2 does correctly**, while the real differences are exactly the
kind a probe, a tolerant parser or a deck built to avoid them handles.

⚠ It is also the case for keeping the two-binary rule. Every difference in the table was
found by running the same deck twice — none of them by reading source, and none of them
would have been visible to a test suite that ran on one binary. **A batch that verified on
one would have shipped a golden for #1, #2 and #3 and never known.**

## Appendix — what a probe costs, measured

Five trivial `-b` runs (a 1 kΩ divider and an `op`) took **27 ms** on 45.2 and **28 ms** on
the fork: **≈5 ms per launch**, on both.

So **probing a capability by launching the simulator is cheap** — the expensive case named in
`src/ase_window.tcl`'s "peeked at, never measured" comment (**31.2 s**, Tk frozen) is a
binary that *exists, is executable and never answers*, not the normal cost of asking. That
distinction belongs in Stage 16's panel design: a probe budget sized from the pathological
case would conclude that probing must be rare, and the measurement says the opposite — what
must be rare is **blocking Tk on a probe that may never return**.
