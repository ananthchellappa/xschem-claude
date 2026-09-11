# Dossier: What an ngspice Run PRODUCES, and How a GUI Gets It Back

Area owner: the results surface behind the analysis picker.
Tree: `/home/analog/dev/ngspice`, branch `ver_50`, `git describe` = `ngspice-46-419-gccebdf2a2`.
Binary used for every measurement below: `/home/analog/dev/ngspice/build-ver_50/src/ngspice`,
version string `ngspice-46+`, build stamp `Thu Sep  3 06:46:24 UTC 2026`, configured with
`../configure --prefix=.../stage --with-readline=yes` (i.e. all defaults).
Scratch decks and captures: `/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/out/`.
Nothing in either repository was modified.

Convention in this file: `file.c:LINE` is a path under `/home/analog/dev/ngspice/`.
"MEASURED" marks a claim taken from an actual run of the binary above, not only from source.

---

## 0. Executive summary for the plan author

Three transport routes exist, and a GUI has to pick per feature, not once:

| route | gets you | costs you |
| --- | --- | --- |
| **spawn `ngspice -b -r file.raw deck.cir`** | one rawfile holding every analysis in the deck, in one pass | no `.meas`, no `.four`, no `.print`; XSPICE event data is *discarded*; no progress except a `\r` line; multi-run sweeps unlabelled |
| **spawn `ngspice -b deck.cir` with a `.control` block that `run`s and `write`s** | full control language: `meas` into vectors, `let`, loops, per-step files, event nodes via `write`/`eprvcd` | exit status stops meaning "the analysis worked" (issue 0069); you must build the deck |
| **link `libngspice` (`--with-ngshared`)** | live vector pointers during the run, per-point callback, progress percentage, real abort | a whole separate build of ngspice; in-process crashes kill the GUI; global state; this is not the binary any distro ships as `ngspice` |

The one non-obvious structural fact: **the rawfile identifies an analysis only by a free-text
`Plotname:` string**, the literal C string the analysis passed to `OUTpBeginPlot()`. There is no
analysis code, no parameter record, and no per-sweep-step label anywhere in the file. Section 3
enumerates every literal string. Section 6 shows that three runs of the same analysis produce three
plots with *identical* headers, distinguished only by their order in the file.

---

## 1. Where output is produced: the two writers

There are exactly two rawfile writers, they share no code, and they differ in observable ways.

### 1a. The batch/streaming writer — `src/frontend/outitf.c`

Used when a rawfile FILE* is open, i.e. when `-r` was given or `run <file>` was typed.
`ft_getOutReq()` (`src/frontend/runcoms.c:421-433`) returns TRUE iff the global `rawfileFp` is
non-NULL; `beginPlot()` then takes the `fileInit()` arm instead of the `plotInit()` arm
(`src/frontend/outitf.c:491-505`).

- `fileInit()` — `src/frontend/outitf.c:929-1016` — writes the header.
- `fileInit_pass2()` — `:1086-1133` — writes the `Variables:` block, on the **first data point**,
  not at header time (`:696-698`). This is why `No. Points:` is a placeholder.
- `fileStartPoint()` / `fileAddRealValue()` / `fileAddComplexValue()` / `fileEndPoint()` —
  `:1136-1179` — stream one point at a time.
- `fileEnd()` — `:1184-1201` — seeks back and backfills the point count.

Consequences a GUI must know:
- Data is **streamed**: the file grows during the run and is valid-ish but incomplete until the
  analysis ends. A GUI that tails the file sees a plot whose `No. Points:` still reads `0`.
- Precision is **hard-coded 15 significant digits** (`#define DOUBLE_PRECISION 15`,
  `src/frontend/outitf.c:103`, used at `:1154` and `:1165`). The `rawfileprec` control variable
  does **not** affect this path — it only sets `raw_prec` for the other writer
  (`src/frontend/options.c:382-390`, `src/frontend/rawfile.c:29`).
- No `Dimensions:` line is ever written on this path (grep: the only `Dimensions:` writer is
  `src/frontend/rawfile.c:212`).
- No per-vector `min=`/`max=`/`color=`/`plot=`/`dims=` attributes; only `grid=3` for a log scale
  (`src/frontend/outitf.c:1113-1114`).

### 1b. The in-memory writer — `raw_write()`, `src/frontend/rawfile.c:41-424`

Used by the `write` command (`com_write()`, `src/frontend/postcoms.c:578-751`, calling
`raw_write()` at `:723`). Serialises `struct plot`s that already exist in memory.

- Precision: `raw_prec` if set by `set rawfileprec=N`, else `DEFPREC` = **15**
  (`src/frontend/rawfile.c:29`, `:31`, `:66-71`).
- Writes `Dimensions:`, per-vector attributes, `Command:` lines from `pl_commands`, and
  `Option:` lines from `pl_env` (`:206-288`).
- Honours `nopadding` (`:55`) and `keep#branch` (`:56`).

---

## 2. The rawfile format, field by field

### 2.1 Header keys, in the exact order each writer emits them

| key | `-r` writer (`outitf.c`) | `write` writer (`rawfile.c`) | notes |
| --- | --- | --- | --- |
| `Title: ` | `:945` — `run->name` = `ft_curckt->ci_name`, the deck's first line | `:114` — `pl->pl_title` | one per plot, repeated for every plot in a multi-plot file (MEASURED: 9 `Title:` lines in a 9-plot file) |
| `Date: ` | `:948` — `datestring()`, taken *now* | `:115` — `pl->pl_date`, taken when the plot was created | format e.g. `Wed Sep  9 18:47:52  2026` (note the double space before the year) |
| `Command: ` | `:951` — always `ngspice-<version>, Build <date>` | `:117` — same, but only `if (ft_sim)` | see §2.6: this key is dangerous on read |
| `Plotname: ` | `:954` — `run->type`, the `analName` the analysis passed | `:118` — `pl->pl_name` | **the only analysis identifier in the file**; §3 |
| `Option: casemode=<mode>` | `:993-997` | `:200-201` | OFF BY DEFAULT. Gated on control variable `casemodewrite`, read through `cp_getvar_policy()`. Local to this tree (issues 0067/0070/0071); no released ngspice writes it. |
| `Option: <name>[=<value>]` | never | `:219-268` — one per `pl_env` entry | `pl_env` is populated **only** by `raw_read()`; a running session cannot put anything there (`src/frontend/variable.c:737-752` says so explicitly). So in practice this line only appears when re-writing a plot that was loaded from a file. |
| `Flags: ` | `:998` — `complex` or `real` | `:206-207` — `real`/`complex`, plus ` unpadded` when `nopadding` is set | §2.3 |
| `No. Variables: ` | `:1001` — `run->numData` | `:208` — count of `pl_dvecs` | |
| `No. Points: ` | `:1004-1011` — key, then `0       ` (8 spaces) as a placeholder, backfilled by `fileEnd()` at `:1190` | `:209` — the true length of the **longest** vector in the plot | |
| `Dimensions: ` | never written | `:210-213`, only when `numdims > 1` | comma-separated, from `dimstring()` |
| `Command: <user text>` | never | `:214-218`, one per `pl_commands` entry | |
| `Variables:` | `:1013` | `:290` | §2.2 |
| `Values:` / `Binary:` | `:1119` — `"%s:\n"` with `Binary` or `Values` | `:352` / `:389` | §2.4 |

**`Offset:`** is a key the reader recognises and rejects with
`Warning: Offset: is not supported` (`src/frontend/rawfile.c:501-502`). Neither writer emits it.

**Key matching on read is case-insensitive** (`ciprefix()` throughout `raw_read()`,
`src/frontend/rawfile.c:493-745`), and **any non-blank line the reader does not recognise aborts the
whole load**: `Error: strange line in rawfile:\n  %s\n  load aborted.` and `return NULL`
(`:860-867`). There is no forward compatibility: a new header key breaks every existing reader.

### 2.2 The `Variables:` block

One line per variable. `-r` writer (`src/frontend/outitf.c:1093-1117`):

```
\t<index>\t<name>\t<typename>[\tgrid=3]\n
```

`write` writer (`src/frontend/rawfile.c:291-289`, attributes at `:269-288`):

```
\t<index>\t<name>\t<typename>[ min=%e][ max=%e][ color=%s][ grid=%d][ plot=%d][ dims=d1,d2,...]\n
```

- `<index>` is 0-based and is the column position in the data block.
- `<typename>` is one of the `types[]` names in `src/frontend/typesdef.c:38-63`, looked up by
  `ft_typenames()` (`:288-294`) and parsed back by `ft_typnum()` (`:313-325`, which also accepts
  `none` as a synonym for `notype`). The complete list, in `enum simulation_types` order
  (`src/include/ngspice/sim.h:4-28`):
  `notype`, `time`, `frequency`, `voltage`, `current`, `voltage-density`, `current-density`,
  `voltage^2-density`, `current^2-density`, `voltage^2`, `current^2`, `pole`, `zero`, `s-param`,
  `temp-sweep`, `res-sweep`, `impedance`, `admittance`, `power`, `phase`, `decibel`,
  `capacitance`, `charge`. (`typesdef.c` also carries a 24th entry `temperature` that no enum value
  reaches.) The `deftype v <name> <abbrev>` command can add more at runtime
  (`src/frontend/typesdef.c:112ff`).
- **The type is guessed, not known.** `guess_type()` (`src/frontend/outitf.c:1022-1083`) infers it
  from the vector's *name* and the plot name: `#branch` → current, `time` → time, `frequency` →
  frequency, `inoise*`/`onoise*` → the noise types, `temp-sweep`/`res-sweep`/`i-sweep` → those,
  `*:power` → power, and — only when the plot name starts with `sp` — `S_*` → s-param, `Y_*` →
  admittance, `Z_*` → impedance, `NF`/`NFmin` → decibel, `Rn` → impedance, `Cy_*` → current.
  `@dev[...]` names are guessed from the bracket letter. **Everything else defaults to
  `voltage`** (`:1079-1080`). The comment at `:1018-1021` calls this out as a FIXME.
- **Name mangling on write.** Both writers wrap names: a `SV_CURRENT` vector `x#branch` is written
  as `i(x)` and a `SV_VOLTAGE` vector `x` as `v(x)` (`outitf.c:1100-1111`, `rawfile.c:295-320`),
  unless `set keep#branch` is set. Because the type is *guessed*, this mangles names that were never
  node names. MEASURED: a `.pz` run through `-r` writes its pole as `v(pole(1))`; the same analysis
  in memory names the vector `pole(1)`. MEASURED: `.sens` parameter sensitivities come out as
  `v(r1:rsh)`, `v(c1_temp)`, …; a two-source `.dc` sweep scale comes out as `v(v-sweep)`.
  A GUI must be prepared to strip a `v(`/`i(` wrapper it did not ask for.
- Reading back, `raw_read()` re-wraps a name that *starts with a digit* as `<abbrev>(<name>)`
  (`src/frontend/rawfile.c:701-706`), so node `1` becomes `v(1)`.
- The `scale=<name>` per-variable attribute exists on read (`:718-720`) and is resolved by name
  (`:761-780`) but **is never written by either writer** — grep for `" scale="` in `rawfile.c`
  finds only the reader. A vector with its own scale therefore loses that binding through a
  round trip. (Which matters: XSPICE event vectors have their own scale — §7.)

### 2.3 Real vs complex

The flag is **per plot, not per vector**.

- `-r` writer: `run->isComplex` is TRUE if *any* column is `IF_COMPLEX`
  (`src/frontend/outitf.c:938-942`, called "a hack" in the source). Then `Flags: complex` and
  **every** column is written as a real/imag pair.
- `write` writer: `realflag` starts TRUE and is cleared by the first complex vector
  (`src/frontend/rawfile.c:90-92`). Then a real vector is written with imag = 0.0 explicitly
  (`:381-383` ASCII, `:334-339` binary).
- Reader: `Flags:` tokens recognised are `real`, `complex`, `padded`, `unpadded`; anything else
  gives `Warning: unknown flag %s` (`:542-556`).

**MEASURED defect worth knowing:** in an AC (or SP, or disto) rawfile written through `-r`, the
**imaginary part of the `frequency` scale column is uninitialised stack garbage**. `CKTacDump()`
sets only `freqData.rValue` (`src/spicelib/analysis/cktacdum.c:31`), `IFvalue` is a union
(`src/include/ngspice/ifsim.h:232-251`) so `.rValue` aliases `cValue.real` and `cValue.imag` is
never assigned, and `OUTpData()` reads `refValue->cValue` because the run is complex
(`src/frontend/outitf.c:703-704`). Observed value in a scratch run: `5.245455799165564e-310`
(a denormal) in every row. In the in-memory path the same code happened to yield 0.0 in the same
session, so it is UB and not reliably one or the other. A GUI should take `real(frequency)` and
never test `imag(frequency) == 0`.

### 2.4 The data block

**ASCII, `-r` writer** (`src/frontend/outitf.c:1136-1168`):
```
<point index>\t\t<v0>\n
\t<v1>\n
\t<v2>\n
...
<point index+1>\t\t<v0>\n
```
`fileStartPoint()` writes `"%d\t"` with the **0-based** index, then every value including the first
is written by `fileAdd*Value()` as `"\t%.15e\n"` (or `"\t%.15e,%.15e\n"` for complex). There is
**no blank line between points** (`fileEndPoint()` writes nothing in ASCII mode, `:1171-1179`).

**ASCII, `write` writer** (`src/frontend/rawfile.c:389-420`):
```
 <point index>\t<v0>\n
\t<v1>\n
...
<blank line>
```
Note the differences: a **leading space** before the index, one tab (not two) before the first
value, and a **trailing blank line after every point** (`putc('\n', fp)` at `:419`).
MEASURED on both paths; the difference is real and a strict parser will trip on it.

**Binary, both writers**: raw little-endian (host-endian) IEEE-754 `double`s, no separator, no
alignment, no length prefix. Row-major: for each point, for each variable in `Variables:` order,
one `double` if `Flags: real`, two (real then imag) if `Flags: complex`.
`-r` writer buffers a row and `fwrite`s it (`src/frontend/outitf.c:1124-1132`, `:1171-1179`);
`write` writer `fwrite`s value by value (`:352-387`).

**Binary blocks are not newline-terminated.** MEASURED: in a 9-plot binary rawfile the last
`double` of one plot is immediately followed by the `T` of the next plot's `Title:` with no
separator — byte offsets 0, 1958, 2416, 2705, 6474, 6819, 8791, 10756, 11707, and `grep '^Title'`
found only the first. **A GUI parsing a binary rawfile MUST, at `Binary:\n`, seek exactly
`No. Points × No. Variables × (8 or 16)` bytes and resume header parsing there.** The ASE-L code
already does this (`/home/analog/dev/xschem-claude/src/ase.tcl:2696-2701`).

### 2.5 Padding

Vectors in one plot may have different lengths (`No. Points:` is the longest). By default the short
ones are **padded with zeros** so every row has the same width (`src/frontend/rawfile.c:325-331`
binary, `:378-386` ASCII); the true length is carried in the per-variable `dims=` attribute
(`:264-268`). `set nopadding` (`:55`) suppresses the padding and adds ` unpadded` to `Flags:`
(`:206-207`); the reader then skips reading past each vector's own length (`:816-848`).
**A reader that ignores `dims=` will read trailing zeros as real data.** MEASURED: an XSPICE deck
whose transient has 227 points and whose two event nodes have 26 each produced a 227×5 file with
`dims=26` on four of the five columns.

The `-r` writer never pads, because every column there has exactly one value per point by
construction, and it never writes `dims=` or ` unpadded` either.

### 2.6 Reading a rawfile executes code — security note

`raw_read()` files each `Command:` line into `pl_commands` **and then runs it**:
`(void)cp_evloop(s);` at `src/frontend/rawfile.c:621`, guarded only by "is this line our own
`ngspice-<version>` provenance stamp" (`:612`). MEASURED: a hand-written rawfile carrying
`Command: echo PWNED-BY-RAWFILE-COMMAND-LINE` printed exactly that when `load`ed.
**A GUI must never `load` a rawfile it did not write, and must never `load` a file a user
downloaded.** (This is upstream and pre-existing; `doc/codex/issues/0061` covers the adjacent
`Option:` hazard.)

### 2.7 The plot *typename* — how a plot is addressed in the control language

`raw_write()` and `fileInit()` write `Plotname:` (the human string). The name a GUI uses in
`setplot`, `print tran1.v(out)`, `write f.raw tran2.all` is a **different** string, `pl_typename`,
computed by `plot_alloc()` (`src/frontend/vectors.c:1094-1120`) as
`ft_plotabbrev(pl_name)` + a number, and **never written to the rawfile**.

`ft_plotabbrev()` (`src/frontend/typesdef.c:331-348`) lowercases the plot name and returns the
first `plotabs[]` entry whose *pattern is a substring* of it. The table, in match order
(`src/frontend/typesdef.c:67-89`):

| abbrev | pattern |
| --- | --- |
| `tran` | `transient` |
| `op` | `op` |
| `tf` | `function` |
| `dc` | `d.c.` , `dc` , `transfer` |
| `ac` | `a.c.` , `ac` |
| `pz` | `pz` , `p.z.` , `pole-zero` |
| `disto` | `disto` |
| `dist` | `dist` |
| `noise` | `noise` |
| `sens` | `sens` , `sensitivity` |
| `sens2` | `sens2` |
| `sp` | `s.p.` , `sp` |
| `harm` | `harm` |
| `spect` | `spect` |
| `pss` | `periodic` |

No match ⇒ `unknown`. MEASURED: a rawfile with `Plotname: Injected` loaded as `unknown1`.

**The number is a GLOBAL counter, not a per-type sequence.** `plot_alloc()` only increments
`plot_num` when the candidate name collides. MEASURED, one `.control` block running
op, dc, ac, tran, noise, tf, disto, pz, sens with `keepopinfo`:

```
op1  (Operating Point)              dc1    (DC transfer characteristic)
op2  (AC Operating Point)           ac2    (AC Analysis)
tran2 (Transient Analysis)          op3    (NOISE Operating Point)
noise3 (Noise Spectral Density Curves)  noise4 (Integrated Noise)
tf4  (Transfer Function)            op4    (Distortion Operating Point)
disto4 (DISTORTION - 2nd harmonic)  disto5 (DISTORTION - 3rd harmonic)
op5  (Distortion Operating Point)   pz5    (Pole-Zero Analysis)
sens5 (Sensitivity Analysis)        const  (constants)
```

**A GUI must not assume `tran1` is the first transient.** Resolve the name from `setplot` output
(`Current <typename>\t<title> (<plotname>)`) or from `ngSpice_AllPlots()`.

Also note the always-present `const` plot, `Plotname: constants`, 12 vectors
(`FALSE TRUE boltz c e echarge i kelvin no pi planck yes`, MEASURED) — this is the plot a `write`
falls back to when no analysis ran, `doc/codex/issues/0059`.

---

## 3. The exact `Plotname:` string each analysis writes

This is the enumeration the plan asked for. Two sources: analyses that pass
`ckt->CKTcurJob->JOBname` write the string the *parser* gave the job
(`src/spicelib/parser/inp2dot.c`, via `CKTnewAnal()` at `src/spicelib/analysis/cktnewan.c:26,32`);
analyses that pass a literal write that literal.

| deck card | `Plotname:` literal | source | notes |
| --- | --- | --- | --- |
| `.op` | `Operating Point` | `inp2dot.c:141` → `dcop.c:48-52` | 1 point, no scale, `Flags: real` |
| `.dc` | `DC transfer characteristic` | `inp2dot.c:303` → `dctrcurv.c:191-195` | scale is `v-sweep`, `i-sweep`, `temp-sweep`, `res-sweep` or `?-sweep` (`dctrcurv.c:180-189`) |
| `.ac` | `AC Analysis` | `inp2dot.c:203` → `acan.c:169-173` | scale `frequency`; `Flags: complex`; `grid=3` when the step type is not LINEAR (`acan.c:177-179`) |
| `.ac` with `keepopinfo` | `AC Operating Point` | literal, `acan.c:157-161` | an **extra** plot written *before* the AC plot |
| `.tran` | `Transient Analysis` | `inp2dot.c:429` → `dctran.c:181-185` | scale `time` |
| `.noise` | `Noise Spectral Density Curves` | literal, `noisean.c:274-281` | **first** of two plots; scale `frequency`; `Flags: real` |
| `.noise` with `.options noisesquared`/`squared` set | `Noise Spectral Density Curves - (V^2 or A^2)/Hz` | literal, `noisean.c:275-278` | same slot, different string |
| `.noise` | `Integrated Noise` | literal, `noisean.c:532-538` | **second** plot, 1 point, no scale |
| `.noise` squared | `Integrated Noise - V^2 or A^2` | literal, `noisean.c:533-535` | |
| `.noise` with `keepopinfo` | `NOISE Operating Point` | literal, `noisean.c:225-229` | extra plot first |
| `.pz` | `Pole-Zero Analysis` | `inp2dot.c:265` → `pzan.c:159-163` | `Flags: complex`, vectors `pole(1)`, `zero(1)`, … ; no scale |
| `.pz` with `keepopinfo` | `Distortion Operating Point` | literal, `pzan.c:57-61` | **yes, the PZ op dump is labelled "Distortion"** — a copy-paste bug in upstream, verified at that line |
| `.tf` | `Transfer Function` | `inp2dot.c:368` → `tfanal.c:104-108` | 3 vectors: the transfer function, `Input_impedance`, `output_impedance_at_<node>` (`tfanal.c:94-102`); 1 point |
| `.disto` (single-frequency) | `DISTORTION - 2nd harmonic` | literal, `distoan.c:516-520` | `Flags: complex`, scale `frequency` |
| `.disto` (single-frequency) | `DISTORTION - 3rd harmonic` | literal, `distoan.c:540-544` | second plot |
| `.disto` with `f2overf1` | `DISTORTION - IM: f1+f2` | literal, `distoan.c:563-567` | |
| `.disto` with `f2overf1` | `DISTORTION - IM: f1-f2` | literal, `distoan.c:584-588` | |
| `.disto` with `f2overf1` | `DISTORTION - IM: 2f1-f2` | literal, `distoan.c:606-610` | |
| `.disto` with `keepopinfo` | `Distortion Operating Point` | literal, `distoan.c:106-110` | extra plot first |
| `.sens` | `Sensitivity Analysis` | `inp2dot.c:485` → `cktsens.c:277-281` | `Flags: real` for a DC sens, `Flags: complex` with a `frequency` scale for `.sens ... ac ...` (MEASURED) |
| `.sp` (RFSPICE) | `SP Analysis` | `inp2dot.c:736` → `span.c:556-560` | see §3.1 |
| `.sp` with `keepopinfo` | `AC Operating Point` | literal, `span.c:478-482` | reuses the AC string |
| `.pss` (build-gated) | `Time Domain Periodic Steady State Analysis` | literal, `dcpss.c:226-230` | scale `time` |
| `.pss` (build-gated) | `Frequency Domain Periodic Steady State Analysis` | literal, `dcpss.c:941-945` | scale `frequency`; also gets `PLOT_COMB` (`dcpss.c:947`) |
| `.sens2` (`WANT_SENSE2`, build-gated) | `Sensitivity-2 Analysis` | `inp2dot.c:608` | not reachable in this tree; `if_sens_run()` path, `runcoms.c:325-334` calls this "not used in ngspice" |
| `.hb` (`WITH_HB`, build-gated) | `Harmonic Balance State Analysis` | `inp2dot.c:774` | requires RFSPICE **and** `WITH_HB`; not defined in this tree |
| XSPICE event nodes via `write` | `digital` (typename `dig1`, title `DigitalData`) | `src/frontend/vectors.c:328-333` | §7 |
| the fallback / no analysis | `constants` (typename `const`) | `src/frontend/vectors.c:1397` region | §2.7 |
| `fft` / `spec` commands | `spectrum` | `com_fft.c:140`, `com_fft.c:377`, `spec.c:195` | typename `spect<N>` |
| `linearize` | `transient` | `linear.c:95`, `linear.c:248` | typename `tran<N>` |

MEASURED confirmation (one deck with `.op .dc .ac .tran .noise .tf .disto`, `-b -r`):
the file held, in order,
`AC Analysis`, `DC transfer characteristic`, `Operating Point`, `Transient Analysis`,
`Transfer Function`, `DISTORTION - 2nd harmonic`, `DISTORTION - 3rd harmonic`,
`Noise Spectral Density Curves`, `Integrated Noise`.
Also MEASURED separately: `Pole-Zero Analysis`, `Sensitivity Analysis`, `SP Analysis`.

**Note the ordering:** it is *not* deck order. The job list is built by pushing each new analysis
onto the head (`src/spicelib/analysis/cktnewan.c:33`) and then run; the effective order in the file
above was AC, DC, OP, TRAN, TF, DISTO, NOISE. A GUI must not index plots by the position of the dot
card in the deck.

### 3.1 The `.sp` variable set

MEASURED on `examples/sp/sp1.cir` (2 ports), `Flags: complex`, 28 variables:
`frequency`, the node voltages and source branch currents, `v(<vsrc>#res)` per port, then
`S_i_j`, `Y_i_j`, `Z_i_j` for every i,j; `i(Cy_i_j)`; and `NF` (decibel), `SOpt` (notype),
`NFmin` (decibel), `Rn` (impedance). Types are assigned by the `sp`-prefixed arms of
`guess_type()` (`src/frontend/outitf.c:1049-1065`).

`wrs2p <file>` (`com_write_sparam()`, `src/frontend/postcoms.c:762ff`) exports the 2-port subset to
Touchstone v1 via `spar_write()` (`src/frontend/rawfile.c:934-1022`). Format is fixed:
`# Hz S RI R <Rbase>`, one row of `freq ReS11 ImS11 ReS21 ImS21 ReS12 ImS12 ReS22 ImS22`, default
precision **6** (`:937-940` — note: *different* default from `raw_write`'s 15), and it prints
`Note: only 2 ports 1 and 2 are supported by wrs2p` on stderr every time.

### 3.2 Analysis registry names (a different string again)

`SPICEanalysis.if_analysis.name` — used by `.save <analysis> <vec>` scoping
(`src/frontend/outitf.c:226`, `:239`) and by `$last_an`-style bookkeeping. Also
`.description`, which is what the "analysis not run" error prints
(`src/frontend/outitf.c:483-484`).

| name | description | defined at |
| --- | --- | --- |
| `options` | `Task option selection` | `cktsopt.c:389-395` |
| `OP` | `D.C. Operating point analysis` | `dcosetp.c:32-39` |
| `DC` | `D.C. Transfer curve analysis` | `dctsetp.c:104-111` |
| `TRAN` | `Transient analysis` | `transetp.c:72-79` |
| `AC` | `A.C. Small signal analysis` | `acsetp.c:94-101` |
| `PZ` | `pole-zero analysis` | `pzsetp.c:90-97` |
| `TF` | `transfer function analysis` | `tfsetp.c:61-68` |
| `DISTO` | `Small signal distortion analysis` | `dsetparm.c:82-89` |
| `NOISE` | `Noise analysis` | `nsetparm.c:95-102` |
| `SENS` | `Sensitivity analysis` | `senssetp.c:106-112` |
| `PSS` | `Periodic Steady State analysis` | `psssetp.c:68-75` (gated) |
| `SP` | `S-Parameters analysis` | `spsetp.c:101-108` (gated) |

So there are **three** name spaces for the same analysis — registry name (`AC`), plot name
(`AC Analysis`), plot typename (`ac2`) — and a GUI will touch all three.

### 3.3 Build gating

| feature | macro | configure flag | default in this tree |
| --- | --- | --- | --- |
| `.sp` / S-parameters | `RFSPICE` | `--enable-sp` / `--disable-sp` | **ON** (`configure.ac:1219-1227`; `config.h:535` `#define RFSPICE 1`) |
| `.hb` harmonic balance | `WITH_HB` (inside `RFSPICE`) | none found in `configure.ac` | **OFF** (`src/spicelib/analysis/analysis.c:22-24`) |
| `.pss` | `WITH_PSS` | `--enable-pss` | **OFF** (`configure.ac:1082-1085`; `config.h:576` `/* #undef WITH_PSS */`) |
| `.sens2` | `WANT_SENSE2` | `--enable-sense2` | **OFF** (`configure.ac:232-234`) |
| XSPICE event layer | `XSPICE` | `--disable-xspice` | **ON** (`config.h:579`) |
| CIDER | `CIDER` | `--enable-cider` | **OFF** (`config.h:11`) |
| shared library | `SHARED_MODULE` | `--with-ngshared` | **OFF** (`config.h:550`) |
| progress callback | `HAS_PROGREP` | implied by `HAS_WINGUI` **or** `SHARED_MODULE` | **OFF** — see §8 |

---

## 4. Multiple plots in one file

Concatenation, nothing more. Each plot is a complete header + `Variables:` + data block, and the
next plot's `Title:` follows immediately.

- **ASCII**: a blank line separates a `write`-produced plot from the next (`rawfile.c:419`);
  a `-r`-produced plot's last value line ends with `\n` and `Title:` is the next line.
- **Binary**: no separator at all (§2.4). Seek the exact payload length.

Every plot carries its own `Flags:` / `No. Variables:` / `No. Points:`, so a file may mix real and
complex plots freely — MEASURED in the 9-plot file above.

### 4.1 A multi-analysis deck

One rawfile, one plot per `OUTpBeginPlot()` call. Note that some cards emit **more than one plot**:
`.noise` → 2 (+1 with `keepopinfo`), `.disto` → 2 or 5 (+1), `.ac`/`.sp`/`.pz` → +1 with
`keepopinfo`, `.pss` → 2. A GUI that maps "one analysis card ⇒ one plot" is wrong.

### 4.2 A multi-run sweep

MEASURED. A `.control` loop doing three `tran` runs, then
`write sweep.raw tran1.all tran2.all tran3.all`, produced one file with three plots whose headers
are **byte-identical apart from the offsets**:

```
Title: * multi-run sweep     Plotname: Transient Analysis   No. Variables: 4   No. Points: 59
Title: * multi-run sweep     Plotname: Transient Analysis   No. Variables: 4   No. Points: 59
Title: * multi-run sweep     Plotname: Transient Analysis   No. Variables: 4   No. Points: 59
```

The typenames `tran1/tran2/tran3` are **not** in the file. Nothing records which `alter` produced
which plot. There is no `.step`-equivalent in ngspice that labels its runs.

**Implications for an ADE-class sweep UI.** Four options, in the order I would recommend them:

1. **One rawfile per sweep step** (`write step_<i>.raw`), the step values held by the GUI. Simple,
   robust, and the only one that survives the GUI restarting mid-sweep.
2. **One file, and rely on plot order.** Cheap, but any deck change that adds a plot (a
   `keepopinfo` op dump, a second `.disto` harmonic) silently re-indexes everything.
3. **Encode the step in the deck title line.** `pl_title` comes from the deck's first line
   (`src/frontend/outitf.c:945` via `ft_curckt->ci_name`), so a per-step generated deck can put
   `* step: r1=2k temp=27` there and it lands in `Title:`. Works only when each step is its own
   deck/process.
4. **`Option:` lines.** Tempting and **not available**: `pl_env` is written by `raw_read()` and by
   nothing else (`src/frontend/variable.c:737-752`). A running session cannot tag a plot.

### 4.3 Nested DC sweeps do not become multi-dimensional

MEASURED: `dc v1 0 2 1 v2 0 1 0.5` (3 × 3) produced **9 flat points, no `Dimensions:` line,
`v_numdims == 1`**. `fileInit()` never writes `Dimensions:` at all, and `plotInit()` sets
`pl_ndims = 1` (`src/frontend/outitf.c:499`) with `v_dims[0] = v_length` per point
(`:1320`, `:1346`). The multi-dimensional machinery exists (`raw_write` at `:210-213`, `dims=` at
`:264-268`, `setdim` at `src/frontend/newcoms.c:150-215`) but nothing populates it for a nested
sweep. **A GUI plotting a family of DC curves must reshape the flat vector itself using the sweep
spec it generated**, or call `setdim` in a `.control` block before `write`.

---

## 5. `wrdata` vs `write` vs `print`

### 5.1 `write [file] [exprs]` — `com_write()`, `src/frontend/postcoms.c:578-751`

Produces a rawfile via `raw_write()`. Behaviour levers, all control variables:

| variable | effect | read at |
| --- | --- | --- |
| `filetype` = `binary` \| `ascii` | picks the format; anything else warns `Warning: strange file type %s` | `postcoms.c:597-605` |
| (env) `SPICE_ASCIIRAWFILE` | integer, sets the `AsciiRawFile` default (default 0 = binary) | `src/misc/ivars.c:103-105`, `src/conf.c:32` |
| `appendwrite` | opens the file `a`/`ab` instead of `w`/`wb` | `postcoms.c:606`, `rawfile.c:72-84` |
| `plainwrite` | takes a `vec_get()` path that does no expression evaluation, so `+`, `-`, `/` in node names survive | `postcoms.c:608-650` |
| `nopadding` | see §2.5 | `rawfile.c:55` |
| `keep#branch` | keep `x#branch` instead of rewriting to `i(x)` | `rawfile.c:56`, `:296-311` |
| `rawfileprec` = N | significant digits, default 15 | `options.c:382-390`, `rawfile.c:29,66-71` |
| `casemodewrite` | emit the `Option: casemode=` line; **local to this tree**, off by default | `rawfile.c:200` |

`write` with **no arguments** writes `all` of the current plot to `ft_rawfile` (the `-r` name, or
`rawspice.raw`). With expressions it writes **one plot per source plot**, appending after the first
(`postcoms.c:744`, `appendwrite = TRUE`).

Two behaviours to plan around:
- **`write` prepends the plot's default scale** to a partial vector list even when you did not ask
  for it (`postcoms.c:686-696`; `doc/codex/issues/0073`, open, pre-existing and upstream). So
  `write f.raw v(out)` gives you a 2-column file, and under some spellings a duplicated column.
- **`write` after a failed/absent analysis writes the 12-vector `constants` plot** rather than
  refusing (`doc/codex/issues/0059`, open, fix attempted and withdrawn). A GUI must check
  `Plotname:` before believing a file.

### 5.2 `wrdata <file> <exprs>` — `com_write_simple()` → `ft_writesimple()`

`src/frontend/com_gnuplot.c:46-70` → `src/frontend/plotting/plotit.c:1262` →
`src/frontend/plotting/gnuplot.c:683-820`.

Plain columnar text, **no header by default**, no plot metadata at all. Layout
(`gnuplot.c:786-816`):

- For each requested vector, in order: its **own scale** column, then its value column(s).
  So the scale is repeated once per vector.
- A **real** vector contributes 1 column; a **complex** vector contributes **2** (real, imag)
  — `gnuplot.c:808-812`.
- The **scale is always printed as a real** — `realpart(scale->v_compdata[i])` at `:801-805` — so
  a complex `frequency` scale is one column, not two.
- Rows run to `maxlen` = the longest scale among the requested vectors (`:728-731`); a vector that
  ran out gets blank-padded fields of exactly the same width (`:790-797`).
- Number format: `"% .*e "` — leading space for the sign, then `precision` digits.
- **Precision = `numdgt` if `> 0`, else 8** (`gnuplot.c:742-745`). Note this default (8) differs
  from `write`'s (15) and from `print`'s (6).

Options:

| variable | effect | read at |
| --- | --- | --- |
| `appendwrite` | append instead of truncate | `gnuplot.c:701` |
| `wr_singlescale` | print the scale column **once**, at the left; refuses (with an error, writing nothing) if the scales differ in length | `gnuplot.c:702`, `:713-727` |
| `wr_vecnames` | emit a header line of names; a complex vector's name appears **twice** | `gnuplot.c:703`, `:745-781` |
| `wr_onespace` | header names separated by a single space instead of padded to the number width | `gnuplot.c:704` |
| `numdgt` (via `option numdgt=N`) | precision | `gnuplot.c:742` |

MEASURED, `wrdata f.dat v(out) v(in)` on a 3-point AC plot:

```
 1.00000000e+00  9.99960523e-01 -6.28293727e-03  1.00000000e+00  1.00000000e+00  0.00000000e+00 
```
(freq, Re v(out), Im v(out), freq, Re v(in), Im v(in))

and with `set wr_vecnames`, `set wr_singlescale`, `option numdgt=4`:

```
 frequency   v(out)      v(out)      v(in)       v(in)      
 1.0000e+00  9.9996e-01 -6.2829e-03  1.0000e+00  0.0000e+00 
```

`wrdata` reaches the same `vec_get()` fallback as `write` and so has the same
"constants plot when nothing ran" hazard (`doc/codex/issues/0059` row 13).

### 5.3 `print [col|line] <exprs>` — `com_print()`, `src/frontend/postcoms.c:129-436`

Human-readable, paginated, **for the log, not for a parser**.

- Chooses column mode automatically if any vector is longer than 1 (`:181-197`); `col`/`line`
  force it.
- Column mode emits a centered title, a `<plotname>  <date>` line, a `-`-rule of `width`
  characters, an `Index   ` header of `%-16.15s` (real) or `%-32.31s` (complex) name fields, another
  rule, then rows of `<index>\t<value>\t...` (`:333-409`).
- Number format is `printnum()` (`src/misc/printnum.c:41-45`): `"%.*e"` with
  `n = cp_numdgt` if `cp_numdgt > 1`, else **6**, minus one for a negative value
  (`printnum.c:19-34`). `cp_numdgt` is set by `option numdgt=N` (`src/frontend/options.c:401-409`)
  and reset to `-1` by unsetting it.
- Special case: a vector named `frequency` whose imaginary part is exactly 0.0 prints as **one**
  column rather than two (`:353-361`, `:394-401`).
- Pagination: form feeds (`\f`) between pages unless `set nobreak` or `option nopage`
  (`:302-306`, `:412-427`); page height from `set height` (min 20), width from `set width`
  (min 40 in column mode, 60 in line mode).

**Do not parse `print` output.** Use `wrdata` for a text table or the rawfile for anything else.

### 5.4 Quick comparison

| | `write` | `wrdata` | `print` |
| --- | --- | --- | --- |
| destination | file (arg or `$rawfile`) | file (arg) | stdout / `out_printf` |
| format | ngspice rawfile, binary or ASCII | plain columns | paginated report |
| metadata | full header, types, plotname | optional name row only | title/plotname/date banner |
| default precision | 15 (`rawfileprec`) | 8 (`numdgt`) | 6 (`numdgt`) |
| complex | flagged, `re,im` per value | 2 columns, scale as real | `re,\tim`, `frequency` special-cased |
| several plots | yes, appended | vectors from several plots side by side | yes, `plot.vec` names when mixed |
| scale | forced in, possibly duplicated (issue 0073) | one per vector, or one total | prepended per page |

---

## 6. The ngspice command line a GUI can drive

`main.c:950-1110` is the option loop. Long/short pairs (`main.c:953-971`):

| flag | long form | effect | code |
| --- | --- | --- | --- |
| `-b` | `--batch` | sets `batchmode`, clears `addcontrol`, sets `ft_batchmode` | `main.c:1027-1035` |
| `-r <f>` | `--rawfile <f>` | `cp_vset("rawfile", ...)`, sets `rflag` | `main.c:1084-1089` |
| `-o <f>` | `--output <f>` | **freopens stdout to `<f>` and `dup2`s stderr onto it**; sets `orflag`; line-buffers stdout | `main.c:1062-1069`, `main.c:1145-1153` |
| `-p` | `--pipe` | sets `iflag`, `istty`, `ft_pipemode`; line-buffers stdout | `main.c:1071-1077` |
| `-s` | `--server` | `ft_servermode = TRUE`; deck on stdin, **rawfile on stdout** | `main.c:1091-1093`, `main.c:1284-1291` |
| `-a` | `--autorun` | wraps the deck in an implicit `.control run .endc` | `main.c:1037-1042` |
| `-n` | `--no-spiceinit` | skip `.spiceinit` | `main.c:1058-1060` |
| `-i` | `--interactive` | force the interactive loop | `main.c:1054-1056` |
| `-c <f>` | `--circuitfile <f>` | read the deck from `<f>` and set `istty = FALSE` | `main.c:1044-1052` |
| `-D k=v` | `--define k=v` | `cp_vset()` — sets a control variable before anything reads it | `main.c:984-1000` |
| `-t <term>` | `--terminal` | sets `term` | `main.c:1095-1099` |
| `--soa-log <f>` | | SOA warnings to a separate file | `main.c:1101-1106` |
| `-v`/`-f`/`--version-small`/`-h` | | print and `sp_shutdown(EXIT_INFO)` | `main.c:1001-1024` |
| `-q` | `--completion` | **ignored**, prints a warning | `main.c:1079-1082` |

Non-option arguments are **concatenated into one temporary file** and sourced together
(`main.c:1418-1497`) — so `ngspice a.cir b.cir` simulates the concatenation, not two circuits.
A first file beginning `*ng_script_with_params` switches to script mode and the remaining
arguments become script parameters (`main.c:1477-1490`).

### 6.1 Batch mode is entered three ways

`main.c:1175-1180`:
```c
if ((!iflag && !istty) || ft_servermode)
    ft_batchmode = TRUE;
```
So **`ngspice deck.cir < /dev/null` is batch mode even without `-b`** — this is the trap
`tests/bin/check_status.sh` calls `notty`, and `tests/regression/exitstatus/op-empty-notty.cir`
pins it. The three routes the suite drives are `--batch deck`, `-b < deck`, and
`deck < /dev/null`.

### 6.2 What each route gives a GUI

**`-b -r out.raw deck.cir`** — the simplest. One process, one file, exit status usable (§6.4).
Costs, all MEASURED:
- `.meas` is **refused**: `No .measure possible in batch mode (-b) with -r rawfile set!` followed by
  `Remove rawfile and use .print or .plot or ...`.
- `.four` and `.print` are ignored, with
  `.fourier line ignored since rawfile was produced.` / `.print line ignored since rawfile was
  produced.` on stdout (`src/frontend/dotcards.c` `terse` arms).
- `.op`/`.tf` print `OP information in rawfile.` / `TF information in rawfile.` instead of a table.
- XSPICE event data is **thrown away**: `EVTdiscard()` at `main.c:1567`, with the comment
  "Do not save any XSPICE node data, as there is no way to use it."
- Only `.save` among dot cards still applies (`main.c:1561-1565`).

**`-b deck.cir` with a `.control` block** — the full language. `run`, `alter`, `meas`, `let`,
`write`, `wrdata`, `eprvcd`, `while`, `quit <n>`. Costs: the exit status becomes ambiguous (§6.4);
and if the deck also carries an analysis dot card, **the analysis runs twice** — once in the block,
once in `main()`'s arm 2 (`doc/codex/issues/0069` Impact).

**`-p` / `--pipe`** — a co-process. MEASURED: stdout is line-buffered and carries a
`ngspice <N> -> <command>` echo of every command read, so a GUI has a natural synchronisation
marker; `quit` ends the session. This is the route for a live, incremental GUI that does not want
to link the library. Note `-p` sets `iflag` and `istty`, so it does **not** enter batch mode.

**`-o log.txt`** — merges stdout **and** stderr into one file via `dup2`
(`main.c:1146-1152`) and sets `orflag`, which suppresses the `Reference value` progress line
(`src/frontend/outitf.c:710`, `:724`, `:821`). Also prints a preamble naming the mode and the
rawfile (`main.c:1128-1134`). **`-o` and `-s` together are useless**: `-s` writes the rawfile to
stdout, and `-o` redirects stdout to the log.

**`-s` / `--server`** — MEASURED, and a trap. Deck arrives on stdin, rawfile goes to **stdout**,
`No. Points:` stays at its `0       ` placeholder because `fileEnd()` cannot seek stdout, and the
true count is emitted **on stderr** as `@@@ <byteOffsetOfPointsField> <pointCount>`
(`src/frontend/outitf.c:1193-1196`). Worse: **the log text is interleaved into the rawfile stream**.
An actual capture:

```
Note: No compatibility mode selected!
Circuit: * server mode deck
Doing analysis at TEMP = 27.000000 and TNOM = 27.000000
Using SPARSE 1.3 as Direct Linear Solver
Title: * server mode deck
...
Variables:
No. of Data Columns : 4              <- log line inside the header
Initial Transient Solution           <- log block inside the header
--------------------------
Node                                   Voltage
in                                           1
...
	0	time	time                 <- the variable list, after the op table
	1	v(in)	voltage
Binary:
<payload>
```

ngspice cannot even read its own `-s` output back: `raw_read()` aborts on the first `Note:` line
(`src/frontend/rawfile.c:860-867`). **Do not use `-s`.**

### 6.3 Format selection from outside the deck

Three equivalent levers, all MEASURED:
- `-D filetype=ascii` on the command line;
- `SPICE_ASCIIRAWFILE=1` in the environment (`src/misc/ivars.c:103-105`);
- `set filetype=ascii` in `.spiceinit` or a `.control` block (read at `runcoms.c:239-252` for the
  `-r` path and `postcoms.c:597-605` for `write`).

Binary is the default (`src/conf.c:32`, `AsciiRawFile = 0`), and it is roughly 3× smaller and much
faster to parse. Prefer binary unless a human has to read the file.

### 6.4 Exit status — read `doc/codex/issues/0069` before designing around this

The decision recorded upstream in this tree is that **the exit status does not change** and that
`$sim_status` is the signal a deck should use.

`sp_shutdown()` (`src/main.c:530-558`) maps `EXIT_NORMAL`=0, `EXIT_BAD`=1, `EXIT_INFO`=2→0
(`src/include/ngspice/defines.h:122-124`). The batch epilogue (`main.c:1533-1596`) is a four-arm
chain and **rc reports whichever arm ran last**:

1. `if (rflag)` (`main.c:1561`) — `-r` given. Dot cards ignored except `.save`; `ft_dorun()`'s
   failure ⇒ `EXIT_BAD`. This is the only arm that reports a `.save` miss.
2. `else if (ft_savedotargs())` (`:1577`) — an analysis dot card, no `-r`. Builds its own save list
   from `.op`/`.print`/`.tf`, so a deck-level `.save` miss no longer kills the run; the re-run
   succeeds and rc is 0 **even if a `.control run` earlier in the same file failed**.
3. `else if (error3 == 0)` (`:1584`) — no dot card, and a `.control` run set `sim_status` to 0 ⇒ 0,
   with `Note: Simulation executed from .control section` on stdout.
4. `else` (`:1588`) — `Error: incomplete or empty netlist / or no ".plot", ".print", or ".fourier"
   lines in batch mode; no simulations run!` ⇒ 1.

MEASURED status matrix on this binary:

| situation | `-b` | `-b -r f.raw` | rawfile left behind |
| --- | --- | --- | --- |
| netlist parse error (`model name is not found`) | **1** | **1** | none |
| deck with netlist but no analysis card | **1** | **0** | none |
| `.save v(nosuchnode)` + `.op` (analysis aborts) | **0** | **1** | none |
| `.control ... quit 3` | **3** | **3** | none |
| a good `.op`/`.tran`/`.ac`/`.dc` | 0 | 0 | yes |
| deck file does not exist | **1** (`<path>: No such file or directory`) | 1 | none |
| pre-fix `.op` on an empty netlist | was **134** (SIGABRT); now **1** | 0 | `doc/codex/issues/0072` |

`quit <n>` from a `.control` block passes `n` straight through, which is the **only reliable way a
generated deck can report its own verdict**.

**`$sim_status`** (`src/frontend/runcoms.c:329`, `:352`, `:358`) is the per-analysis outcome:
0 before dispatch, 1 on `simulation(s) aborted`, 1 on `simulation not started`. Its three
properties, each asserted by a committed deck in `tests/regression/exitstatus/`:
1. **last-writer-wins** — a failing analysis sets 1, a later good one sets 0
   (`sim-status-properties.cir`);
2. **it does not exist before the first analysis of the session** (`sim-status-unset.cir`);
3. **0 means "the last analysis did not report a failure", not "an analysis produced data"** — a
   bare `run` with nothing to do reads 0 (`sim-status-properties.cir`).

The guard shape a GUI's generated deck should use (`tests/regression/exitstatus/sim-status-guard.cir`):

```spice
.control
run
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
write results.raw
.endc
```

**Do not infer "no output" from rc=1.** Both rc=1 arms can leave a `Plotname: constants` rawfile on
disk (`doc/codex/issues/0069` criterion 5, `doc/codex/issues/0059`). Checking `Plotname:` is
mandatory. The ASE-L already takes this position: `ase.tcl:2720-2727` says
"THE EXIT CODE IS RECORDED AND USED FOR NOTHING … every verdict is taken from the results file".
That is the right call and this dossier corroborates it — with one refinement: rc is worth reading
as a *secondary* signal, because `quit <n>` from a generated deck's own guard is under the GUI's
control and is unambiguous.

### 6.5 Other exits

`controlled_exit(1)` fires on ≥3 SIGINTs (`src/frontend/signal_handler.c:100-103`) and on the
Windows out-of-memory path (`src/frontend/outitf.c:161`). `fatal()` calls `exit(EXIT_BAD)`
(`src/frontend/error.c:65-78`). Any rc ≥ 128 is a signal death and the exitstatus driver treats it
as a hard failure by construction (`tests/bin/check_status.sh`).

**MEASURED hazard for a multi-analysis GUI:** a deck carrying **two `.sens` cards** aborted with
`malloc(): unsorted double linked list corrupted`, rc=134. Each `.sens` alone is fine. Not
investigated further; it is outside this dossier's area, but a GUI that lets the user stack
analyses will hit it.

---

## 7. XSPICE event data — a separate results channel

Event-driven (digital) nodes do **not** live in the analog plot and are **not** in a `-r` rawfile
(`main.c:1567`, `EVTdiscard()`).

Four ways out, all requiring a `.control` block:

| command | output | source |
| --- | --- | --- |
| `edisplay` | list of event nodes: `<name> : <type> , <n events>` | `src/xspice/evt/evtprint.c` `EVTdisplay` |
| `eprint <node> ...` | a text table; time column `"%.*e"` with precision `numdgt` or **9**; `DCOP` for the operating point row | `src/xspice/evt/evtprint.c:368-393` |
| `eprvcd [-a] [-t <step>] <node> ...` | a VCD file (redirect with `>`); `-a` also emits analog values at timesteps | `src/xspice/evt/evtprint.c:578-660` |
| `write f.raw <node> ...` | the event node **as an analog dvec pair in the rawfile** | `EVTfindvec()`, `src/xspice/evt/evtplot.c:202-299` |

The `write` route is the interesting one for a plotting GUI. `EVTfindvec()` builds, per event node:
- a scale vector named **`<node>_steps`**, type `time`, `VF_REAL|VF_EVENT_NODE`, not
  `VF_PERMANENT` (`evtplot.c:286-289`);
- a value vector named **`<node>`**, type `voltage` (`:291-294`), with points doubled so the
  waveform renders as a staircase (`:255-281`), plus one final point at `CKTtime`.

MEASURED, a `.tran` with 227 analog points and two digital nodes with 13 events each:

```
Plotname: Transient Analysis
Flags: real
No. Variables: 5
No. Points: 227
Variables:
	0	time	time
	1	dout_steps	time dims=26
	2	din_steps	time dims=26
	3	v(din)	voltage dims=26
	4	v(dout)	voltage dims=26
```

Three things to note: the value vectors got a spurious `v(` wrapper (§2.2); the event columns are
zero-padded out to 227 rows and **only `dims=26` says so**; and the `scale=` binding between
`v(din)` and `din_steps` is **not written** (§2.2), so the GUI must re-pair them by the `_steps`
suffix.

**MEASURED bug:** `write f.raw alle` — the documented "all event nodes" wildcard,
`findvec_alle()` at `src/frontend/vectors.c:315-361` — fails with
`Warning from checkvalid: vector alle is not available or has zero length.` and
`Error during 'write': no writable vector found.`, even with two live event nodes present.
Naming the nodes explicitly works. A GUI must enumerate event nodes with `edisplay` (or
`ngSpice_AllEvtNodes()`) and name them one by one.

---

## 8. The log / stdout stream, and what is parseable in it

### 8.1 Where it goes

Default: stdout and stderr, separately. With `-o <f>`: both merged into `<f>` via `dup2`
(`main.c:1146-1152`), line-buffered. With `-s`: stdout is the rawfile, so the log is *in* it (§6.2).

### 8.2 Markers, in the order they appear (MEASURED across op/dc/ac/tran/noise/tf/disto/pz)

Startup / per deck:
- `Note: No compatibility mode selected!` — or a mode name.
- `Circuit: <title line>` — the deck's first line. **The best "the deck loaded" marker.**
- `binary raw file "<name>"` / `ASCII raw file "<name>"` — printed by `dosim()`
  (`src/frontend/runcoms.c:295`, `:303`) when a rawfile is opened. Also printed by `raw_write()`
  (`src/frontend/rawfile.c:78`, `:84`) for a `write` command.
- `Doing analysis at TEMP = %f and TNOM = %f`
- `Using SPARSE 1.3 as Direct Linear Solver` — or the KLU line. Printed **once per matrix setup**,
  so `.pz` prints it three times.
- `Warning: Interpolated raw file data!` when `set interp` (`src/frontend/outitf.c:211-214`).
- A memory pre-check for transient runs: `Warning: memory required (...B), made of N nodes and
  approximately M time steps, is more than the DRAM memory available (...B)!` — a *warning* on
  POSIX, a hard `controlled_exit(1)` on Windows (`src/frontend/outitf.c:143-173`). Suppress with
  `set no_mem_check`.

Per plot:
- **`No. of Data Columns : <n>  `** — start of a plot, from `fileInit()`
  (`src/frontend/outitf.c:1015`). Note the two trailing spaces. **Only emitted on the `-r`/file
  path.**
- **`No. of Data Rows : <n>`** — end of a plot, preceded by a blank line, from `fileEnd()`
  (`:1191`) or `plotEnd()` (`:1353`). Emitted on **both** paths.
- These are the only per-plot markers, and **neither names the analysis**. Pair them by order with
  the plots in the rawfile.
- For `.tran`: `Initial Transient Solution` + a `Node / Voltage` table, from `CKTdump`, unless
  `set noinit` / `.options noinit`.

Progress:
- **` Reference value : % 12.5e\r`** — `src/frontend/outitf.c:713`, `:727`, `:825`, `:828`.
  Throttled to at most one per **0.25 s** (`(currclock-lastclock) > 0.25*CLOCKS_PER_SEC`).
  Carries the current scale value: simulation time for `.tran`, frequency for `.ac`/`.noise`/`.sp`,
  sweep value for `.dc`. **This is the only progress signal a spawned binary gives you.**
  MEASURED on a 21-second transient: 86 such records, all `\r`-terminated with no newline —
  a line-oriented reader will block until the analysis ends. Read by chunks and split on `\r`.
  Suppressed when: `-o` is used (`orflag`), `set norefvalue` / `.options norefvalue`
  (`src/frontend/options.c:361-362`, `src/frontend/spiceif.c:481-483`), or the process is judged
  to be in the background (`cp_background`, `src/frontend/signal_handler.c:150-165`). Note
  `test_background()` is only called when **not** in batch mode, so `-b` runs keep it on.
- **`Total analysis time (seconds) = <x>`** and **`Total elapsed time (seconds) = <x>`** at the end,
  then the DRAM/program-size block. These make a clean "run finished" marker.

Errors, in parseable form:
- `Error on line <n> or its substitute:` + the offending card + a reason — netlist parse errors.
- `    Simulation interrupted due to error!` — after a failed `inp_spsource()` (`main.c:1505`).
- `Error: no data saved for <analysis description>; analysis not run` — `src/frontend/outitf.c:483`,
  using `spice_analysis_get_description()`, e.g. `D.C. Operating point analysis`.
- `<what> simulation(s) aborted` / `<what> simulation interrupted` / `<what> simulation not started`
  — `src/frontend/runcoms.c:344-359`.
- `doAnalyses: <reason>` — `ft_sperror()` (`src/frontend/error.c:57-62`) with `SPerror()`'s text
  (`src/spicelib/parser/sperror.c:19-118`). The reasons worth matching:
  `timestep too small`, `matrix is singular`, `iteration limit reached`,
  `matrix can't be decomposed as is`, `out of memory`, `no such analysis type`,
  `transmission lines not supported by pole-zero`, `ac input not found`,
  `no F2 source for IM disto analysis`, `transfer function is 1`, `pss failed`.
- `Warning: singular matrix:  check node <name>` and the gmin/source-stepping notes
  (`Note: Starting dynamic gmin stepping`, `Warning: Dynamic gmin stepping failed`,
  `Note: Starting source stepping`, `Note: Transient op started`, …). MEASURED: these appear and
  the run still **succeeds and exits 0** once a fallback works.
- `Warning: unrecognized variable - <name>` — a `.save` of a `@dev[param]` that does not resolve,
  emitted only at the first data point (`src/frontend/outitf.c:774-776`).
- `Warning: rawfile write error !!` — disk full / write failure; sets the stop flag
  (`src/frontend/outitf.c:808-811`).
- `Note: Simulation executed from .control section` — `main.c:1585`, arm 3.
- `Error: incomplete or empty netlist / or no ".plot", ".print", or ".fourier" lines in batch mode;
  no simulations run!` — arm 4.

Post-run dot-card output (only when **no** `-r`, from `ft_cktcoms()`,
`src/frontend/dotcards.c:190ff`):
- the `.op` table: `\tNode<pad>Voltage`, `\t----<pad>-------`, rows, then `\n\tSource\tCurrent\n`
  and the branch currents; then `showmod`/`show` output unless `set nomod`
  (`dotcards.c:222-268`);
- `Transfer function information:` + a `print` of the tf plot (`dotcards.c:271-282`);
- `.print` / `.plot` / `.four` output (`dotcards.c:286-...`);
- `.meas` results, one per line: `<name>                = <value>` and, for a TRIG/TARG measure,
  ` at= <value>`; a failure prints
  `Error: measure  <name>  trig(TARG) : out of interval` and
  ` .meas <line> failed!` (MEASURED).
- `.four` output: `Fourier analysis for <vec>:` then
  `  No. Harmonics: N, THD: X %, Gridsize: N, Interpolation Degree: N, No. Periods: N` then a
  fixed-width harmonic table (MEASURED). Field width is `numdgt + 5` (`src/frontend/fourier.c:167`).

### 8.3 `meas` produces vectors — the ADE-class measurement route

MEASURED: `meas tran vmax MAX v(out)` inside a `.control` block **creates a vector** in the current
plot (`vmax : notype, real, 1 long`), so a subsequent `write` carries it as an extra column with
`dims=1`. This is how an ADE-alike gets numeric measurement results back through the rawfile
instead of by scraping stdout, and it is the strongest argument for the `.control`-block route over
`-r`.

---

## 9. `libngspice` — what it buys, what it costs, and whether ASE-L should want it

Header: `src/include/ngspice/sharedspice.h` (570 lines).
Implementation: `src/sharedspice.c` (2690 lines).
Build: `--with-ngshared` ⇒ `#define SHARED_MODULE` (`configure.ac:178-180`, `:440-442`).

### 9.1 The API surface

Lifecycle: `ngSpice_Init()`, `ngSpice_Init_Sync()`, `ngSpice_Init_Evt()` (XSPICE),
`ngSpice_Command(char*)`, `ngSpice_Circ(char**)` (send a netlist as an array of lines, no file),
`ngSpice_Reset()`, `ngSpice_nospinit()`, `ngSpice_nospiceinit()`.

Data access:
- `ngGet_Vec_Info(char *name)` → `vector_info*` with **direct pointers** `v_realdata` /
  `v_compdata` and `v_length` (`sharedspice.h:229-237`). No copy, no file, no parsing.
- `ngSpice_CurPlot()`, `ngSpice_AllPlots()` (typenames), `ngSpice_AllVecs(plotname)`.
- `ngSpice_LockRealloc()` / `ngSpice_UnlockRealloc()` — hold the vectors still while reading them
  from the foreground thread during a background run.
- XSPICE: `ngGet_Evt_NodeInfo()`, `ngSpice_AllEvtNodes()`, `ngSpice_Raw_Evt()`,
  `ngSpice_Decode_Evt()`, `ngCM_Input_Path()`.

Callbacks (all set at `ngSpice_Init()`):
- `SendChar(char*, int, void*)` — every `printf`/`fprintf`/`fputs` the simulator makes. This is the
  log stream, already split into strings, tagged `stdout `/`stderr ` by the sender.
- `SendStat(char*, int, void*)` — **the progress callback**: `SetAnalyse()`
  (`src/sharedspice.c:1952-2050`) hands over strings like `tran 43.7%`. Throttled to
  `DELTATIME 150` ms and thread-aware. The analysis-type strings it can send, from every
  `SetAnalyse()` call site: `Device Setup`, `Source Deck`, `Prepare Deck`, `Parse`, `op`,
  `tran init`, `tran`, `optran init`, `optran`, `dc`, `ac`, `sp`, `ptran init`, `ptran`,
  `shooting`, `spec`, `meas`, `shell`, `gnuplot`, `pyplot`, `Wav out`, `or` (matrix reorder),
  `Start`.
- `SendInitData(pvecinfoall, int, void*)` — fired from `sh_vecinit()`
  (`src/sharedspice.c:2332-2400`), once per plot at `beginPlot()` time, carrying the plot's
  name/title/date/typename and one `vecinfo` per vector (name, is_real, and raw `struct dvec*`
  pointers for the vector and its scale). **This is the analysis identification the rawfile lacks**
  — you get `pl_typename` (`tran2`) *and* `pl_name` (`Transient Analysis`) live.
- `SendData(pvecvaluesall, int, int, void*)` — fired from `sh_ExecutePerLoop()`
  (`src/sharedspice.c:2291-2325`) **once per accepted data point**, carrying every vector's new
  value plus `is_scale` and `is_complex` flags and the point index. Real streaming.
- `BGThreadRunning(NG_BOOL, int, void*)` — background thread start/stop.
- `ControlledExit(int, NG_BOOL, NG_BOOL, int, void*)` — instead of `exit()`.
- Sync callbacks: `GetVSRCData`, `GetISRCData`, `GetSyncData` — let the host **drive a voltage or
  current source from its own code** and negotiate the timestep. Nothing in the file route can do
  this.

Threading and abort:
- Prefix a command with `bg_` (`bg_run`, `bg_tran`, …) to run it on a background thread
  (`src/sharedspice.c:649-700`).
- `bg_halt` stops it: `_thread_stop()` (`src/sharedspice.c:547-580`) sets `ft_intrpt = TRUE` and
  polls for up to 100 × 10 ms, then reports `Error: Couldn't stop ngspice` or
  `Background thread stopped with timeout = N`. This is a **cooperative** abort — the simulator
  checks the flag at data points — so it is prompt for a normal run and useless if the solver is
  wedged inside one Newton iteration.
- While a background run is live, any non-`bg_` command is refused with
  `Warning: cannot execute "<cmd>", type "bg_halt" first` (`:719`).
- `set savenone` makes the vectors length-1 rolling buffers so a long run costs no memory
  (`src/frontend/outitf.c:1259-1263`, `:1302-1306`, `:1334-1337`) — only meaningful when the host
  consumes every `SendData` callback.

### 9.2 What it costs

1. **It is a different build of ngspice, not an add-on.** `src/Makefile.am:19-32` puts
   `bin_PROGRAMS = ngspice` (and `ngsconvert`, `ngproc2mod`, `ngmultidec`, `ngmakeidx`, `nghelp`)
   inside `if !SHARED_MODULE`, and `:503-506` builds `libngspice.la` inside `if SHARED_MODULE`.
   You get the binary **or** the library, never both from one build tree. A user with a distro
   ngspice may not have `libngspice` at all — MEASURED on this machine: `/usr/bin/ngspice` exists,
   no `libngspice.so` anywhere under `/usr/lib` or `/usr/local/lib`.
2. **Crashes become GUI crashes.** In-process means a `SIGSEGV` in a device model, a
   `malloc(): unsorted double linked list corrupted` (which I reproduced with two `.sens` cards),
   or a `controlled_exit()` takes Xschem with it. The file route contains all of that in a child
   process.
3. **Global state.** The comment in `/home/analog/dev/ngspice/CLAUDE.md` is explicit: anything
   touching global/static simulator state must survive repeated `ngSpice_Reset()`, and recent
   commits `c5cd68015` and `5ad395d5e` are exactly that class of bug. `doc/codex/issues/0062`
   ("shared build command after reset") is another. Multi-corner / multi-run means many resets.
4. **Tcl.** Xschem's ASE-L is Tcl. Reaching a C API means a Tcl extension (a `.so` with
   `Tcl_CreateObjCommand` wrappers, or critcl/ffidl/SWIG), plus marshalling `double*` arrays into
   Tcl values, plus running the callbacks on the right thread — Tcl's interpreter is not
   thread-safe and every callback would have to be queued to the event loop. That is the real cost,
   and it is much larger than the C API itself.
5. **Identifier case.** `sharedspice.h:57-108` documents that `ngGet_Vec_Info()` matches
   case-insensitively under `casemode=fold`/`preserve` and **exactly** under
   `casemode=distinguish`, and that the only way to select the mode is
   `ngSpice_Command("set casemode=preserve")` before `ngSpice_Circ()`. There is no `argv`.
   The safe rule in every mode is to use the string the simulator gave you.
6. **No progress on the binary route as consolation.** `HAS_PROGREP` — the macro that makes
   `SetAnalyse()` exist — is defined **only** under `HAS_WINGUI` or `SHARED_MODULE`
   (`src/include/ngspice/ngspice.h:130-133`, `:281-299`). A Linux CLI ngspice has no
   percentage-progress mechanism at all; it has the `\r` reference-value line and nothing else.

### 9.3 Recommendation

**No, not for ASE-L, not now — but design as if it might come later.**

The reasons, in order of weight:

- The GUI's job is scheduling runs, presenting results and iterating on options. Every one of those
  is served by files and a child process. The two things only the library adds — *live* vectors
  during a run and a real percentage — are polish, and the second one is achievable another way:
  the `\r` reference-value line already carries the current scale value, and the GUI knows the
  final time / final frequency because it wrote the analysis card. A progress bar from
  `refvalue / tstop` is a few lines of Tcl and needs no new build of anything.
- Robustness runs the other way. An ADE-class tool is judged on not falling over when a model
  misbehaves. Process isolation is the single most valuable property here, and linking throws it
  away. ASE-L's own code already reasons this way — `ase.tcl:2720-2727` deliberately distrusts
  even the exit code and verdicts on the results file.
- Deployment. Asking users to build ngspice with `--with-ngshared`, on a machine where the
  system ngspice is a binary, converts "install xschem, install ngspice" into a source build. For a
  tool whose selling point is being lighter than ADE, that is the wrong trade.
- The abort story is not as good as it looks: `bg_halt` is cooperative and can time out
  (`src/sharedspice.c:566-570`). `kill -INT` / `kill -TERM` on a child process is not worse in
  practice and is far simpler.

**Migration cost if it is ever wanted**, roughly ordered:
1. a build of ngspice with `--with-ngshared` (mechanical, but a second build to ship or document);
2. a Tcl binding layer — ~600-1000 lines of C for `Init`, `Command`, `Circ`, `Reset`,
   `CurPlot`/`AllPlots`/`AllVecs`/`Get_Vec_Info`, the six callbacks, and the event API;
3. a thread-safe queue from the callbacks into the Tcl event loop (`Tcl_ThreadQueueEvent`), because
   `bg_run` callbacks arrive on a foreign thread;
4. a results adaptor that presents `vector_info` the same way the current rawfile parser presents
   `cap_raw_plots` output, so the rest of ASE-L does not learn which route it is on;
5. a crash policy — supervise, or accept losing the schematic editor;
6. reset hygiene, and a test that runs `ngSpice_Reset()` in a loop.

**The design lesson to take now, for free:** put a **results-provider seam** in ASE-L — one module
whose contract is "given a completed run, return `{plotname, npoints, complexflag, [{name, type,
data}...]}`", and whose only current implementation reads a rawfile. Then a library backend, a
`-p` co-process backend, or a future `ngspice --json` are all drop-ins. ASE-L is already close to
this: `ase::cap_raw_plots` (`/home/analog/dev/xschem-claude/src/ase.tcl:2649-2709`) is that seam
in embryo, and `ase.tcl:2727-2733` already notes that the runner "belongs to no one simulator".

---

## 10. Concrete implications for the ASE-L GUI

1. **Identify plots by `Plotname:` string, not by position, and keep the literal table from §3
   in one place in the code.** There are 25-odd literals and several analyses emit more than one
   plot; a hard-coded `[lindex $plots 0]` will break the first time a user sets `keepopinfo`.
2. **Never assume `tran1`.** Plot typenames carry a global counter (§2.7). If the GUI needs to
   address a plot in the control language, read the name from `setplot` output.
3. **Parse binary rawfiles by seeking the payload, not by lines** (§2.4). ASE-L already does.
4. **Honour `dims=`.** Padded columns are real in every `write`-produced file, and XSPICE event
   data always has them (§2.5, §7).
5. **Take the `.control` route, not `-r`,** if measurements matter: `-r` disables `.meas`, `.four`
   and `.print`, and discards XSPICE event data (§6.2). `meas` inside `.control` produces vectors
   that `write` carries (§8.3), which is exactly the ADE "outputs → measurement expressions" model.
6. **Have the generated deck report its own verdict** with `if $sim_status ne 0 / quit 1` (§6.4).
   That converts an ambiguous exit status into one the GUI defined. Still check `Plotname:` — the
   constants-plot artefact (issue 0059) survives both.
7. **A sweep needs a labelling scheme the file format does not provide** (§4.2). One rawfile per
   step, with the step values held by the GUI, is the only design that stays correct when the deck
   changes.
8. **Nested DC sweeps come back flat** (§4.3). The GUI must reshape.
9. **Progress**: parse ` Reference value : <x>\r` from stdout in chunks, and normalise against the
   analysis stop value the GUI itself wrote into the card. Do not use `-o` if you want it (§8.2).
10. **Never `load` an untrusted rawfile** — `Command:` lines execute (§2.6).
11. **Prefer binary rawfiles** for size and parse speed; expose ASCII as a debug toggle via
    `-D filetype=ascii` (§6.3).
12. **Budget for size.** MEASURED: a 20 ms transient at 1 ns step wrote 20,000,008 rows × 4
    variables = ~640 MB in 22 s. The GUI needs `.save`-based column selection in the analysis form
    (and ngspice will warn — or on Windows, `controlled_exit(1)` — before it starts, §8.2).

---

## 11. Where source and documentation disagree

- **`sharedspice.h` on `ngGet_Vec_Info` case matching** (`:56-64`) documents per-mode behaviour that
  is specific to this tree's `casemode` feature. Upstream ngspice-46 has no `casemode`. Trust the
  header for *this* build; a GUI targeting stock ngspice should assume case-insensitive matching.
- **The `Option: casemode=` header line** (§2.1) is written by this tree and by nothing released.
  It is off by default precisely because a released ngspice-46 that unsets the resulting `casemode`
  key crashes (`doc/codex/issues/0067`). Trust the source; do not emit or expect this line in a
  portable GUI.
- **`raw_write()`'s comment at `src/frontend/rawfile.c:29`** says "default 15 (max)"; the code
  agrees (`DEFPREC 15`). The `-r` path's 15 is a *different, unrelated* constant
  (`src/frontend/outitf.c:103`) that `rawfileprec` cannot reach. The manual's description of
  `rawfileprec` as "the raw file precision" is therefore incomplete — it governs `write` only.
  Trust the source.
- **`.sens2`** appears in the parser (`inp2dot.c:608`) and in `runcoms.c:325`, which says
  `/* "sens2" not used in ngspice */`. The analysis is `WANT_SENSE2`-gated and off. Trust the source
  comment; treat `.sens2` as absent.
- **PZ's operating-point plot is labelled `Distortion Operating Point`** (`pzan.c:58`). No
  documentation says so; this is a source-level fact and looks like an upstream copy-paste. Trust
  the source, and match the literal.
- **The AC `frequency` column's imaginary part** (§2.3) is documented nowhere and is UB. Trust the
  measurement and read only `real(frequency)`.
- **`alle` in `write`** (§7) is documented as a vector wildcard but MEASURED to fail there. Trust
  the measurement.

---

## 12. Files a future session should open first

| purpose | path |
| --- | --- |
| rawfile format, both directions | `src/frontend/rawfile.c` (`raw_write` :41, `raw_read` :455, `spar_write` :934) |
| the batch/streaming writer, plot lifecycle, type guessing | `src/frontend/outitf.c` (`beginPlot` :179, `fileInit` :929, `guess_type` :1022, `fileInit_pass2` :1086, `fileEnd` :1184, `plotInit` :1206) |
| `write` / `print` / `wrs2p` | `src/frontend/postcoms.c` (`com_print` :129, `com_write` :578, `com_write_sparam` :762) |
| `wrdata` | `src/frontend/plotting/gnuplot.c:683` (+ `src/frontend/com_gnuplot.c:46`) |
| plot & vector structs | `src/include/ngspice/plot.h`, `src/include/ngspice/dvec.h`, `src/include/ngspice/sim.h` |
| type & plotname tables | `src/frontend/typesdef.c` (`types[]` :38, `plotabs[]` :67, `ft_plotabbrev` :331) |
| plot allocation & naming | `src/frontend/vectors.c` (`findvec` :182, `findvec_alle` :315, `plot_alloc` :1094) |
| command line, batch epilogue, exit status | `src/main.c` (`sp_shutdown` :530, option loop :950, batch epilogue :1533) |
| rawfile opening, `$sim_status`, `ft_getOutReq` | `src/frontend/runcoms.c` (`dosim` :205, `ft_getOutReq` :421) |
| post-run dot cards | `src/frontend/dotcards.c` (`ft_dotsaves` :57, `ft_savedotargs` :92, `ft_cktcoms` :190) |
| shared library | `src/sharedspice.c`, `src/include/ngspice/sharedspice.h` |
| XSPICE event output | `src/xspice/evt/evtprint.c`, `src/xspice/evt/evtplot.c` |
| the `Plotname:` literals | `src/spicelib/analysis/{dcop,dctrcurv,acan,dctran,noisean,tfanal,distoan,pzan,cktsens,span,dcpss}.c` |
| exit-status contract, in prose | `doc/codex/issues/0069-batch-exit-status-reports-the-last-thing-main-did.md` |
| the constants-plot artefact | `doc/codex/issues/0059-write-emits-the-constants-plot-when-no-analysis-ran.md` |
| `write`'s scale-prepending | `doc/codex/issues/0073-write-prepends-the-plot-scale-to-a-partial-vector-list.md` |
| exit-status test harness and decks | `tests/bin/check_status.sh`, `tests/regression/exitstatus/` |
| rawfile format converter | `src/ngsconvert.c` — `ngsconvert <fromtype> <fromfile> <totype> <tofile>`, types `o` (spice2 binary), `b` (raw binary), `a` (raw ASCII); built only when `!SHARED_MODULE` |

---

## 13. Open questions / gaps

- I did not measure `.pss` or `.hb` — both are build-gated off in this tree. Their `Plotname:`
  strings are read from source only.
- I did not measure CIDER's `Device Cross Section` plot (`src/frontend/rawfile.c:781-789` special-
  cases it into `pl_xdim2d`/`pl_ydim2d`); CIDER is off in this tree.
- I did not exercise the `interp` option's effect on a rawfile's row set
  (`src/frontend/outitf.c:683-692`, `InterpFileAdd`).
- The two-`.sens` heap corruption (§6.5) is unexplained.
- I did not test `libngspice` at all — no shared build exists in this tree or on this machine, so
  every claim in §9 is from source and headers.
- Whether `SendStat`'s percentage is reliable for every analysis (some call sites pass 0)
  is unverified.
