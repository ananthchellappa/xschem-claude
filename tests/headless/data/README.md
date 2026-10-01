# `tests/headless/data/` — committed simulation fixtures

Committed simulation artefacts that tests **read and never write**, with the deck and the
derivations that document each one. Nothing in here is generated at test time: spec `doc/claude/specs/calculator.md` §11.2 says *"generate it once with ngspice, commit
it, and document the generating deck next to it. Do not regenerate it in the test — a fixture
that regenerates is a fixture that drifts."*

---

## `calc_fixture.raw` + `calc_fixture.cir`

The Calculator's test fixture (PLAN row 2.1). `calc_fixture.cir` is the deck that produced it;
its header comments carry the circuit-level reasoning, this file carries the **contract** and
the **hand derivations**.

### ⚠ The deck cannot overwrite the fixture, on purpose

`calc_fixture.cir` ends in `write calc_fixture.regen.raw`, **not** `calc_fixture.raw`. Running
the deck in this directory produces an untracked sibling and leaves the committed fixture
alone. To re-verify the fixture, copy the deck to a scratch directory, run it there, and
compare numerically — see *Reproducibility* below.

### Which simulator produced it, and why that one

**`/usr/bin/ngspice`.** The version is not taken from this sentence: the raw file carries its
own `Command:` header line, which reads `ngspice-45.2, Build Fri Sep 12 11:58:13 UTC 2025`, so
the artefact states its own generator and this paragraph can be checked against it. (The *path*
is not in the file; that part is this paragraph's claim.)

There is a second ngspice on this machine: the **`ngspice-46+` fork build** at
`$XSCHEM_TEST_REAL_HOME/dev/ngspice/build-ver_50/src/ngspice`, which `test_real_home` in
`tests/headless/scratch.tcl` exists to locate for the ASE-L capability-gated features
(`ee_binaries` in `test_ase_converge_1459.tcl` is the pattern). It was **deliberately not
used**, for three reasons:

1. **A fixture inherits its generator.** This deck needs nothing but `tran`, `linearize`, `ac
   lin` and `op` — four of the oldest, most stable commands in ngspice. The capability the fork
   exists for (the gated ASE-L features) is not in play, so the fork would buy nothing and cost
   provenance.
2. **The fork lives under the tester's real HOME**, found read-only through
   `XSCHEM_TEST_REAL_HOME`. A fixture whose documented generator exists only in one person's
   home directory cannot be re-derived by anyone else — including a driver running in a
   throwaway-HOME clone, which is where T1 runs.
3. **`/usr/bin/ngspice` is the one `ase::sim_status ngspice` resolves from PATH**, and the
   ASE-L registry `~/.xschem/ase_simulators` currently registers **nothing** (it holds only
   `ase::sim_select {}`), so there is no registered simulator whose choice this would be
   contradicting. The registry was read and not written; it is on the do-not-touch list.

### Structure — four plots in one file

The file is frozen, so these are properties of a committed artefact rather than figures that
can drift. They are written down here to be asserted by rows, which is where they get
re-measured:

| # | `Plotname:` | flags | `No. Variables` | `No. Points` | reached by |
|---|---|---|---|---|---|
| 0 | `Transient Analysis (linearized)` | real | 10 | 101 | `xschem raw read <f>` → dataset **0** |
| 1 | `Transient Analysis (linearized)` | real | 10 | 101 | same read → dataset **1** |
| 2 | `AC Analysis` | complex | 10 | 20 | `xschem raw read <f> ac` |
| 3 | `Operating Point` | real | 9 | 1 | `xschem raw read <f> op` |

The two transient plots come **first** because `read_dataset()` in `src/save.c` adopts the first
plot's type when `xschem raw read` is given no type argument. So a bare read selects `tran` and
sees **two datasets** — which is §11.2's *"more than one dataset"* requirement.

What `xschem` reports for each read (measured through `./src/xschem --nogui --pipe -q --script`):

* bare read: `sim_type=tran`, `datasets=2`, `vars=10`, `points` (no argument) = 202,
  `points 0` = `points 1` = 101
* `ac`: `sim_type=ac`, `datasets=1`, `vars=40`, `points=20`
* `op`: `sim_type=op`, `datasets=1`, `vars=9`, `points=1`

⚠ **`vars` is 40 for the ac read, not 10.** xschem expands every complex column into four
readable names, and **the spelling is not uniform**: a voltage `v(lp)` becomes `v(lp)`
(magnitude), `ph(lp)`, `re(lp)`, `im(lp)` — the `v(...)` wrapper is *stripped* from the derived
three — while an op-parameter `@m1[gm]` becomes `@m1[gm]`, `ph(@m1[gm])`, `re(@m1[gm])`,
`im(@m1[gm])`, keeping its brackets. Anything that constructs an ac component name from a node
name has to know both spellings. `ph()` is in **degrees**.

⚠ **The `Operating Point` plot has no sweep variable.** Its index 0 is `v(sq)`, not `time` or
`frequency`, so a reader that assumes variable 0 is the sweep will read a node voltage as an
X axis.

### Vector inventory

Both transient datasets, in file order:

```
time  @m1[gm]  i(@m1[id])  i(@rdc1[i])  i(@rtop[i])  v(dcmid)  v(div)  v(lp)  v(ramp)  v(sq)
```

The `AC Analysis` plot carries the same ten (as `frequency` plus the same nine); the
`Operating Point` plot carries the nine without a sweep column.

**Only two columns of the ac plot are driven**, and knowing which matters:

* **driven** — `v(sq)`, the `AC 1` reference, exactly `1 + 0j` at every frequency; and `v(lp)`,
  the pole.
* **carried through as a real constant** — `@m1[gm]` and `i(@m1[id])`, the op parameters of a
  device biased by fixed sources: real part the operating-point value, imaginary part exactly 0,
  `ph()` exactly 0.
* **undriven** — `v(ramp)`, `v(div)`, `v(dcmid)`, `i(@rtop[i])`, `i(@rdc1[i])`: no small-signal
  excitation reaches them, so they are `0 + 0j`.

They are kept rather than trimmed because the alternative (`write <plot>.<vector>`) mangles the
names — see the deck's closing comment. That is also what a real ngspice ac raw looks like when
the `save` list was written for a transient.

### ⚠⚠ An undriven ac column does NOT read back as zero through the magnitude name

This is the trap most likely to cost a later row an afternoon. For a complex sample that is
exactly `0 + 0j`, `read_raw_data_block()` in `src/save.c` substitutes a floor into the
**magnitude** column — its own comment is *"avoid 0 for dB calculations"* — and stores the
**`float`** literal `1e-35f` into a `double` slot. So on this fixture:

| accessor | what an undriven ac column answers |
|---|---|
| `xschem raw values v(ramp) 0` | `1.000000018002509e-35` at **every** point — not 0 |
| `xschem raw values re(ramp) 0` | exactly `0` |
| `xschem raw values im(ramp) 0` | exactly `0` |
| `xschem raw values ph(ramp) 0` | exactly `0` (set to `0.0` explicitly by the same branch) |

The odd mantissa is the float literal widened to double, so a row asserting this value must
either compare against `1.000000018002509e-35` exactly or test `< 1e-30`. **A row that asserts
"an undriven ac node reads 0" will fail on the magnitude accessor and pass on `re`/`im`**, and
the reason is a deliberate product behaviour, not a fixture defect.

### Op-parameter vectors — §11.2's fourth requirement, and the naming trap

Four `@<dev>[<param>]`-family vectors are present, and **ngspice does not write them all the
same way**:

| what the deck `save`d | the name in the raw | why |
|---|---|---|
| `@m1[gm]` | `@m1[gm]` | admittance-typed: keeps its bare name |
| `@m1[id]` | `i(@m1[id])` | current-typed: wrapped in `i(...)` |
| `@rtop[i]` | `i(@rtop[i])` | current-typed: wrapped in `i(...)` |
| `@rdc1[i]` | `i(@rdc1[i])` | current-typed: wrapped in `i(...)` |

`xschem raw index` resolves all four under the names in the middle column and returns `-1` for
the left column's spelling of the three wrapped ones. **This asymmetry is what R207 is
about** (*"read them back from the raw inventory"*) and of R204 (*"the emitted name is exactly
what `xschem raw index <name>` resolves"*): a selector that builds `@rtop[i]` from the
schematic, correctly, produces a name this raw does not have.

Note also `scheduler.c`'s own help example, `xschem raw add power {outm outp - i(@r1[i]) *}` —
the `i(...)` wrapper is in the shipped documentation, which is the same fact seen from the
other side.

---

## The hand-derived values

**Every expected value below is derived from the deck, not read out of the run.** They are
here to be asserted by rows; a row that recomputed an expected value from the fixture would
prove only that the fixture is self-consistent.

**Use a tolerance, not equality**, and take the tolerance from the table below rather than
picking a round one. Two independent reasons it cannot be equality: ngspice's transient solution
and `linearize`'s interpolation carry ordinary floating-point error, and `twopi` in the deck is
2π rounded to sixteen significant digits, so the pole is at 1 kHz only to that precision.

⚠ **The expected values in this file are hand-derived; the tolerances in the next table are
MEASURED HEADROOM** — the largest disagreement between the committed fixture and the hand value,
over every sample of both transient datasets and all twenty ac points. They are stated so that a
row picks a tolerance it can justify, not so that a row asserts them.

| quantity | worst disagreement with the hand value | a safe tolerance |
|---|---|---|
| `time` | 9.2e-16 relative | 1e-12 rel |
| `v(ramp)`, `v(div)`, `i(@rtop[i])` | 8.2e-13 relative | 1e-11 rel |
| `v(sq)` at the five 50 % samples, and on its flat-1 intervals | 5.0e-14 relative | 1e-11 rel |
| `v(sq)` on its flat-**zero** intervals | 1.8e-15 **absolute** | 1e-12 **abs** — relative is undefined at zero |
| `v(dcmid)`, `i(@rdc1[i])` in the **transient** datasets | 1.7e-12 relative | 1e-10 rel |
| `v(dcmid)`, `i(@rdc1[i])` in the **op** dataset | **zero — bit-exactly 3.0 and 0.001** | equality holds, but prefer 1e-10 rel |
| `frequency` in the ac dataset | **zero — bit-exact 100 … 2000** | equality holds |
| `v(lp)/v(sq)` at every ac point | 3.8e-16 relative | 1e-12 rel |
| `@m1[gm]` | 1.7e-13 relative | 1e-11 rel |
| ⚠ `i(@m1[id])` | **3.5e-9 relative** | **1e-8 rel** — see below |

⚠ **`i(@m1[id])` is the one value whose tolerance has to be loose**, and the reason is
instructive: the fixture holds 870.3500030 µA where the pure level-1 saturation formula gives
870.35 µA exactly. The extra 3 parts in 10⁹ come from ngspice's own MOS1 device code, not from
the deck, so this is the one place where the hand derivation is an *approximation of the
simulator* rather than a restatement of it. A row that used the 1e-11 tolerance of its
neighbours would be red on a correct fixture. `i(@rdc1[i])` = 1 mA is the op-parameter value to
use when an exactly-known one is wanted.

Note also that `v(dcmid)` and `i(@rdc1[i])` are **not** bitwise constant across the transient
even though the circuit that produces them is purely resistive and time-invariant: the solver
re-solves at every timepoint and lands within 1.7e-12. They *are* bit-exact in the op dataset.

### The time grid

`linearize` resamples onto the uniform grid the `tran 0.1m 10m` command asked for:

> **sample `k` is at `t = k × 0.1 ms`, for `k = 0 … 100`.**

### The ramp — `v(ramp)`, both datasets

`PWL(0 0 10m 10)` is a slope of exactly **1 V/ms**:

> **`v(ramp)` at sample `k` is `k/10` volts.**
> **The level-`L` crossing is at exactly `t = L` ms**, for any `0 ≤ L ≤ 10`.

So `v(ramp)` at sample 30 is 3 V and at sample 100 is 10 V, and anything that measures where the
ramp crosses 3 V must answer 3 ms.

### The square wave — `v(sq)`, both datasets

`PULSE(0 1 0.9m 0.2m 0.2m 1m 4m)`, a trapezoid whose every breakpoint is a multiple of the
0.1 ms grid:

| interval (ms) | `v(sq)` |
|---|---|
| 0 … 0.9 | 0 |
| 0.9 → 1.1 | rising linearly 0 → 1 |
| 1.1 … 2.1 | 1 |
| 2.1 → 2.3 | falling linearly 1 → 0 |
| 2.3 … 4.9 | 0 |
| then +4 ms periodic |  |

> **Rising 50 % crossings at `t = 1.0`, `5.0`, `9.0` ms — samples 10, 50, 90.**
> **Falling 50 % crossings at `t = 2.2`, `6.2` ms — samples 22, 62.**
> **At each of those five samples `v(sq)` is 0.5** — to 5.0e-14 relative; see the tolerance table.
> At `t = 10 ms` (sample 100) `v(sq)` is 1: the third rising edge completed at 9.1 ms and the
> run ends before the next fall at 10.1 ms.

That is five crossings of one level, at round times, with the *value* at the crossing also
round — which is what makes a `cross`-style measurement checkable both ways.

### The divider — `v(div)` and `i(@rtop[i])`: the dataset discriminator

Pure resistive: no time constant anywhere, so the relation below is exact in closed form at
every sample, and the fixture meets it to 8.2e-13 relative.

| | dataset 0 (`rtop` = 1k) | dataset 1 (`rtop` = 3k) |
|---|---|---|
| `v(div)` | `v(ramp) / 2` | `v(ramp) / 4` |
| `i(@rtop[i])` | `v(ramp) / 2000` A | `v(ramp) / 4000` A |

> At sample 30 (`t = 3 ms`, `v(ramp) = 3 V`):
> **dataset 0 — `v(div)` = 1.5 V, `i(@rtop[i])` = 1.5 mA**
> **dataset 1 — `v(div)` = 0.75 V, `i(@rtop[i])` = 0.75 mA**

`i(@rtop[i])` is the current from `ramp` to `div`, i.e. `(v(ramp) − v(div)) / rtop` — which is
`v(ramp) / (rtop + rbot)` either way.

### The dc divider — `v(dcmid)` and `i(@rdc1[i])`: the op dataset's non-zero values

`vdc` = 5 V across `rdc1` = 2k and `rdc2` = 3k. Unaffected by the `alter`, so the same in both
transient datasets and in the op dataset. ⚠ **Not in the ac dataset**: `vdc` has no `AC` value,
so both of these are undriven there and read back through the 1e-35 magnitude floor above.

> **`v(dcmid)` = 5 × 3k/(2k+3k) = 3 V**
> **`i(@rdc1[i])` = (5 − 3)/2k = 1 mA**

These two are the op dataset's reason to exist: at `t = 0` the pulse and the ramp are both zero,
so every other node there is zero. In the **op** dataset they are bit-exactly `3.0` and `0.001`;
in the transient datasets they land within 1.7e-12 of those, re-solved at every timepoint.

### The single pole — the ac dataset

`clp = 1/(2π · rac · fp)` with `rac` = 1k and `fp` = 1k puts the pole at **exactly 1 kHz**, and
`ac lin 20 100 2k` steps by exactly 100 Hz, so the sweep is

> **f = 100, 200, … 2000 Hz — twenty samples, and 1000 Hz is sample index 9.**

`v(sq)` is the `AC 1` drive, so `v(sq) = 1 + 0j` at every frequency and
`H(f) = v(lp)/v(sq) = 1 / (1 + j·f/1000)`:

| f | `v(lp)` | \|H\| | `db20()` | `ph()` |
|---|---|---|---|---|
| 100 Hz (index 0) | `(1 − 0.1j)/1.01` | `1/√1.01` = 0.995037190209989… | −0.0432137378264…dB | −atan(0.1) = −5.710593137499…° |
| **1000 Hz (index 9)** | **`0.5 − 0.5j`** | **`1/√2` = 0.707106781186547…** | **`−10·log10(2)` = −3.010299956639812** dB | **−45°** |
| 2000 Hz (index 19) | `0.2 − 0.4j` | `1/√5` = 0.447213595499958 | −6.989700043360187 dB | −atan(2) = −63.43494882292201° |

> **The −3 dB point is sample index 9, f = 1000 Hz**, where the response is `0.5 − 0.5j`.

The sweep frequencies themselves are bit-exact, so index 9 really is 1000.0 and not 999.99…;
that is why a `lin` sweep was chosen over a `dec` sweep, which would have straddled the pole and
left the −3 dB point to interpolation. The response at the pole is not quite bit-exact — the
imaginary part is exactly −0.5 and the real part is one ulp above 0.5 — so even here the
comparison is a tolerance, and the measured headroom is 3.8e-16 relative.

The derivation, end to end, with no simulator in it: `H = 1/(1 + jωRC)`; `RC = 1/(2π·1000)` by
construction; at `f = 1000`, `ωRC = 2π·1000·1/(2π·1000) = 1`; so `H = 1/(1+j) = (1−j)/2`;
`|H| = 1/√2`; `20·log10(1/√2) = −10·log10 2`; `arg H = −45°`.

### `@m1[gm]` and `i(@m1[id])` — hand-derivable, but model-dependent

`m1` is a level-1 NMOS, `vto` 0.7, `kp` 100u, `W/L` = 10u/1u so `β = KP·W/L = 1 mA/V²`,
`λ` = 0.01, `Vgs` = 2 V, `Vds` = 3 V. `Vds > Vgs − Vt = 1.3 V`, so it is saturated and the
level-1 equations give

> **`@m1[gm]` = β(Vgs−Vt)(1+λVds) = 1m × 1.3 × 1.03 = 1.339 mS**
> **`i(@m1[id])` = (β/2)(Vgs−Vt)²(1+λVds) = 0.5m × 1.69 × 1.03 = 870.35 µA**

Both are time-invariant — the gate and drain are held by fixed sources — so they take the same
value at every transient sample (to 1.7e-13) and in the op dataset.

⚠ **Treat these two differently from everything above.** They are derived from the *level-1
model equations*, which are a property of the simulator's device code rather than of the deck,
so they are the only values here whose agreement with the fixture could be broken by a different
ngspice — and `i(@m1[id])` already disagrees by 3.5e-9, as the tolerance table says. Neither is
needed for any measurement: **`@m1[gm]` is in the fixture for its NAME, not its value.** A row
that wants an exactly-known op-parameter *value* uses `i(@rdc1[i])` = 1 mA.

---

## Two facts about the engine, measured on this fixture, that PLAN phase 3 needs

Recorded here because they were measured while verifying the fixture and they change what
phase 3 can be built on. Neither is a property of the fixture.

1. ⚠ **`xschem raw add` returns 1 for an expression the engine REJECTED.**
   `xschem raw add bad {v(nosuch) v(div) +}` answers **`1`**, and the created column is
   **all zeros**. `raw_add_vector()` in `src/save.c` discards `plot_raw_custom_data()`'s return
   value, so §3.1's `-1` — *"callers must treat `-1` as 'no data'"* — is **not reachable through
   the Tcl verb at all**. Spec §3.1 already notes that a rejected expression yields a defined
   all-zero column (issue 0325) and that *"a caller that wants to distinguish 'rejected' from
   'all zero' must read the `-1` return, not the column"*; what is new is that from Tcl there is
   no `-1` to read. **R607 (PLAN 3.4) therefore cannot be implemented as "on engine `-1`, …"**:
   the failing token has to be found by validating every vector-looking token with
   `xschem raw index` *before* calling the engine, or the engine's return has to be plumbed out
   first. Verified in both directions on this fixture — a good expression and a rejected one are
   indistinguishable by return value.

2. ⚠ **`xschem raw index` does not parse the `%<n>` dataset suffix.** `xschem raw index
   v(div)%0` returns `-1`, as does `v(div)%1`. The `%<dataset>` syntax belongs to
   `node_token_split()` (landmine L5) on the trace/`node=` path, not to the inventory lookup.
   The reader that *does* take a dataset is **`xschem raw values <name> <dataset>`**, and on
   this fixture it answers differently for the two datasets, which is how the ">1 dataset"
   requirement is actually exercised from Tcl. R303's `%<dataset>` emission is a `wviewer`
   question, not a `raw index` one.

---

## Reproducibility

The deck is deterministic to the bit. Measured twice — two runs of identical deck text, and
one run across a comment-only edit of the deck — the outputs differ in **nothing but the four
`Date:` header lines**; every data byte is identical. The committed `.raw` is the output of the
committed `.cir` text, not of an earlier revision of it. So "re-verify" means:

```sh
mkdir -p /tmp/myscratch && cd /tmp/myscratch
cp <repo>/tests/headless/data/calc_fixture.cir .
timeout 180 /usr/bin/ngspice -b calc_fixture.cir      # writes calc_fixture.regen.raw
cmp -l calc_fixture.regen.raw <repo>/tests/headless/data/calc_fixture.raw
```

`cmp -l` lists **every** differing byte, which is the point — plain `cmp` stops at the first one
and would not show that the rest agree. On the same ngspice it lists only bytes inside the four
`Date:` header lines, and nothing in any `Binary:` block. A *different* ngspice
is expected to differ in the low-order bits of the transient columns and must be compared
numerically, with the tolerance above, against the hand-derived values in this file — never
against the committed bytes.

The committed fixture's own identity, for a row that wants to assert the artefact has not been
regenerated in place:

```
21330 bytes   md5 23bf926f6def8fe4525a881e80fcdd1a
```
