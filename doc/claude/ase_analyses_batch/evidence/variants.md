# Dossier: the three ngspice a user can actually have — apt 45.2, stock 47, and the fork

Reader: the session that answers "what hooks let ASE-L work with an ngspice that is not ours".
Scope: build **stock upstream** from a scratch worktree with **default configure flags**, then
characterise all three binaries side by side on the analysis set, the build flags, casemode,
the four known hazards, and version reporting.

Everything below was run in this session. **Nothing in `/home/analog/dev/ngspice` or
`/home/analog/dev/xschem-claude/src/` was modified.** The scratch worktree was removed after
the build; the build tree was kept.

**MEASURED** marks something executed here. **SOURCE** marks something read in a tree here.

| tag used below | binary | provenance |
|---|---|---|
| **APT-45.2** | `/usr/bin/ngspice` | Debian package `ngspice 45.2+ds-1`, installed 2025-09-12 |
| **UP47** | `/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/builds/upstream47/src/ngspice` | built here from `origin/pre-master-47` @ `c5cd68015`, `git describe --tags` = `ngspice-46-212-gc5cd68015` |
| **FORK** | `/home/analog/dev/ngspice/build-ver_50/src/ngspice` | branch `ver_50` @ `ccebdf2a2`, `git describe --tags` = `ngspice-46-419-gccebdf2a2` |

`git rev-list --left-right --count origin/pre-master-47...ver_50` → `0	207`. **MEASURED.**
The fork branched from the exact commit UP47 is built at, so **every FORK↔UP47 difference in
this dossier is one of those 207 commits and nothing else.** That makes the comparison exact in
a way a version-number comparison never is.

Commit-type histogram of the 207, **MEASURED**
(`git log --oneline origin/pre-master-47..ver_50 --no-merges | sed -E 's/^\S+ ([a-z]+):.*/\1/' | sort | uniq -c`):

```
     96 fix        76 docs        26 test         9 feat
```

All nine `feat:` commits are casemode. So the fork's *added capability* is one feature; its
*behavioural delta* is 96 bug fixes, and that asymmetry is the whole shape of the problem.

---

## 0. The build: what a bare `./configure` actually turns on

```sh
git -C /home/analog/dev/ngspice worktree add .../workpad/upstream47 origin/pre-master-47
cd .../workpad/upstream47 && ./autogen.sh
cd .../workpad/builds/upstream47 && ../../upstream47/configure && make -j8
```

**MEASURED, all three stages rc 0.** `config.log` records the invocation as
`$ ../../upstream47/configure` — no flags, which is the point.

**Wall time, from file mtimes: `autogen.sh` 26 s, `configure` 14 s, `make -j8` 59 s — 99 s end to
end** on this 20-core machine. 269 `warning:` lines, the same background noise `builds.md` §0
recorded. The brief's "10+ minutes" is an overestimate by an order of magnitude; a GUI installer
that offers to build ngspice for the user is a two-minute proposition, not a coffee break.

**What the defaults gave**, from `src/include/ngspice/config.h` of the two builds side by side
(**MEASURED**, `grep -E '^#define X|^/\* #undef X \*/'`):

| macro | UP47 (bare `./configure`) | FORK (`build-ver_50`, see below) |
|---|---|---|
| `XSPICE` | `#define XSPICE 1` | `#define XSPICE 1` |
| `OSDI` | `#define OSDI 1` | `#define OSDI 1` |
| `RFSPICE` | `#define RFSPICE 1` | `#define RFSPICE 1` |
| `KLU` | `#define KLU` | `#define KLU` |
| `USE_OMP` | `#define USE_OMP 1` | `#define USE_OMP 1` |
| `HAVE_LIBFFTW3` | `#define HAVE_LIBFFTW3` | `#define HAVE_LIBFFTW3` |
| `CIDER` | *undef* | *undef* |
| `WITH_PSS` | *undef* | *undef* |
| `SHARED_MODULE` | *undef* | *undef* |
| `PREDICTOR`, `EXPERIMENTAL_CODE`, `NGDEBUG`, `HAS_WINGUI` | *undef* | *undef* |

So **the default build is XSPICE + OSDI + RFSPICE + KLU + OpenMP + readline
(`HAVE_GNUREADLINE`, auto-detected), and no CIDER, no PSS, no shared library.** That is what a
user who types `./configure` gets.

**A correction to `CLAUDE.md` while I am here.** It says `build-ver_50` was "configured with bare
`../configure`". **MEASURED**, `build-ver_50/config.log`:

```
  $ ../configure --prefix=/home/analog/dev/ngspice/build-ver_50/stage --with-readline=yes
```

Neither flag changes a feature — `HAVE_GNUREADLINE` is on in the bare UP47 build too, so
`--with-readline=yes` only pins what autodetection already found, and `--prefix` moves an install
location. **The two builds are feature-identical**, which is what makes the FORK↔UP47 comparison
in this dossier a comparison of 207 commits and not of configure flags. But the `--prefix` has
one operational consequence, §0.1.

### 0.1 The uninstalled-build trap, re-confirmed

A build that is never `make install`ed has no `spinit`, so no code models load.
**MEASURED**, `devhelp` row counts:

| invocation | rows |
|---|---|
| UP47, `SPICE_LIB_DIR` unset | **56**, plus `Warning: can't find the initialization file spinit.` on stderr |
| UP47, `SPICE_LIB_DIR` = staged libdir | **137**, no warning |
| FORK, `SPICE_LIB_DIR` unset | **137**, no warning |
| APT-45.2, installed | **140** = 137 − 2 (`astate`, `ota`) + 5 (the CIDER devices); see §2 |

The FORK row is the one to notice. It needs no `SPICE_LIB_DIR` because
`build-ver_50` was configured `--prefix=…/build-ver_50/stage` and *has been installed there* —
`stage/share/ngspice/scripts/spinit` and `stage/lib/ngspice/*.cm` exist, and `NGSPICEDATADIR` in
its `config.h` points at them. UP47, at the default `prefix=/usr/local`, has nothing installed and
falls back to a warning.

**This is a trap for anyone comparing the two by eye**: run both bare and the fork looks like it
has 81 more devices than upstream. It does not. Every measurement in this dossier uses staged
libdirs (`workpad/libdir/upstream47`, `workpad/libdir/fork`, built with `builds.md` §0's recipe)
so the three binaries are compared on equal terms.

### 0.2 `spinit` differs between fork and upstream by three comment lines

**MEASURED**, `diff upstream47/src/spinit.in ngspice/src/spinit.in`:

```
14a15,17
> ** keep the case of node, instance, model and subcircuit names as written **
> ** the default, fold, lower cases every card as it is read **
> *set casemode=preserve
```

The fork ships its headline feature **commented out**. Default behaviour on the fork is
therefore identical to stock unless something turns casemode on. That is good news for the
adapter design: ASE-L is not fighting a different default, it is deciding whether to *request*
a mode.

---

## 1. The analysis set — three columns

Probe: `help <verb>` inside a `.control` block, one `-b` run per binary
(`decks/verbs.cir`, §10). `Sorry, no help for <verb>.` on stdout means absent.
This is `00-critique.md` §5.1's method and it holds.

| verb | APT-45.2 | UP47 | FORK |
|---|---|---|---|
| `op` | yes | yes | yes |
| `dc` | yes | yes | yes |
| `ac` | yes | yes | yes |
| `tran` | yes | yes | yes |
| `tf` | yes | yes | yes |
| `noise` | yes | yes | yes |
| `disto` | yes | yes | yes |
| `pz` | yes | yes | yes |
| `sens` | yes | yes | yes |
| `sp` | yes | yes | yes |
| **`pss`** | **yes** | **—** | **—** |
| `hb` | — | — | — |
| `four` | — | — | — |
| `fourier` | yes | yes | yes |
| `fft` | yes | yes | yes |
| `spec` | yes | yes | yes |
| `linearize` | yes | yes | yes |
| `run` | yes | yes | yes |
| `resume` | yes | yes | yes |
| `optran` | yes | yes | yes |

**The headline stands and is now three-way: the OLDEST binary has the MOST analyses.** The
Debian 45.2 package is built with `--enable-pss` (and `--enable-cider`, §3); the current
upstream tip built with defaults has neither. **Capability is not ordered by version.**

`pss` is not merely a help string on APT-45.2 — it runs. **MEASURED**, the Van der Pol body from
`examples/pss/vdp_osc_pss_ctrl.cir` with `pss 0.5e6 100e-6 1 50 10 50 5e-3 uic`:

```
APT-45.2     "@@plots=[const pss1]"      rc=1 (rc from the deck's missing analysis card, not pss)
UP47         pss: no such command available in ngspice      "@@plots=[const]"
FORK         pss: no such command available in ngspice      "@@plots=[const]"
```

Note the **second absence signal**: a missing verb invoked as a command prints
`<verb>: no such command available in ngspice`. `help` is the cheap pre-flight probe;
this is what a run actually says when the probe was skipped.

`sp` runs on all three. **MEASURED**, a two-port 50 Ω through-resistor with `sp lin 3 1g 3g`:
all three produce `Plotname: SP Analysis` (`$curplotname` = `SP Analysis`) with
`S_1_1 : s-param, complex, 3 long`. RFSPICE is a default, not an opt-in.

### 1.1 The whole command table, not just the analyses

Because it costs one extra run, I probed **all 134 names** in `spcp_coms[]` on each binary
(402 rows, `out/allcmds.tsv`). Only three names move:

| command | APT-45.2 | UP47 | FORK | why |
|---|---|---|---|---|
| `pss` | present | absent | absent | `#ifdef WITH_PSS` |
| `pyplot` | **absent** | present | present | no guard — a 46-era addition, so this one is a *version* fact |
| `bltplot` | absent | absent | absent | `#ifdef TCL_MODULE` |
| `sndparam`, `sndprint` | absent | absent | absent | `#if defined(HAVE_LIBSNDFILE) && defined(HAVE_LIBSAMPLERATE)` |
| `use` | absent | absent | absent | `#ifdef DEVLIB` |

The `why` column is **SOURCE** (`commands.c`, the `#if` immediately above each entry) and it is
worth more than the rows themselves: **`help sndprint` is a working probe for
`HAVE_LIBSNDFILE`**, which `00-critique.md` §5.1 lists as having none, and `help bltplot` /
`help use` do the same for `TCL_MODULE` and `DEVLIB`. Every `#ifdef`-guarded entry in
`spcp_coms[]` is a free build-flag probe.

`pyplot` is the one row with no guard, so its absence on the apt build is a **version**
difference, not a configure difference — a GUI that offers "send this plot to matplotlib" has to
probe for it on 45.2 and cannot get it back by rebuilding.

**And the finding that decides the whole design: FORK and UP47 have byte-identical help text for
all 134 commands.** **MEASURED** — a `join` of the two 134-row lists on the command name,
filtered to rows where the help strings differ, is **empty**. **SOURCE** confirms it: the
`spcp_coms[]` name lists extracted from both trees' `commands.c` are identical
(`comm -23`/`comm -13` both empty).

> **The fork adds no command, changes no help string, and reports the same version.
> Nothing in the command table can tell ASE-L which of the two it is talking to.**

---

## 2. Build flags per binary

| flag | probe used | APT-45.2 | UP47 | FORK |
|---|---|---|---|---|
| XSPICE | `if $?xspice_enabled` / `help codemodel` | **on** | **on** | **on** |
| OSDI | `help osdi` (`#ifdef OSDI` guards the entry) | **on** | **on** | **on** |
| KLU | `-v` line 3 | **on** | **on** | **on** |
| RFSPICE / SP | `devhelp vsource` → `portnum` | **on** | **on** | **on** |
| PSS | `help pss` | **on** | off | off |
| CIDER | `devhelp` → any `NUMD` / `NBJT` / `NUMOS` / `NDEV` row (or `version -f`) | **on** | off | off |
| OpenMP | `version -f` → `OpenMP multithreading…` | **on** | **on** | **on** |
| shared lib | `version -f` → `ngspice shared library.` | off | off | off |
| PREDICTOR | `version -f` → `--enable-predictor` | off | off | off |
| libsndfile | `help sndprint` | off | off | off |
| TCL module | `help bltplot` | off | off | off |
| DEVLIB | `help use` | off | off | off |

**MEASURED evidence, per probe.**

`devhelp` row counts and the CIDER grep:

```
APT-45.2     devhelp rows=140  CIDER(NUMD|NBJT|NUMOS|NDEV)=5
UP47         devhelp rows=137  CIDER(NUMD|NBJT|NUMOS|NDEV)=0
FORK         devhelp rows=137  CIDER(NUMD|NBJT|NUMOS|NDEV)=0
```

The device-list diff is exact and worth having:

```
apt-only  : NBJT NBJT2 NUMD NUMD2 NUMOS       (the five CIDER numerical devices)
up47-only : astate ota                        (two post-45.2 code models)
fork vs up47 : identical
```

`devhelp vsource` on all three prints `portnum / z0 / pwr / freq / phase`, so RFSPICE is on
everywhere and `an-rf-pss.md`'s probe stays valid.

### 2.1 Two traps in the probes the earlier dossiers recommended

**Trap 1 — `$osdi_enabled` is useless.** `00-critique.md` §5.1 names
`$xspice_enabled` / `$osdi_enabled` as "the only two variables set at startup". They are set at
`main.c:943-946`, but **the shipped `spinit` then unsets one of them**. **SOURCE**,
`spinit` line 16-17, identical in all three variants:

```
* comment out if central osdi management is set up
unset osdi_enabled
```

**MEASURED**, `echo "@@osdi_enabled=$osdi_enabled"` → `@@osdi_enabled=` on **all three**, and
`if $?osdi_enabled` takes the false branch on all three — on builds that all have
`#define OSDI 1`. **The variable answers "no" on every binary that has OSDI.** Use
`help osdi` instead (**MEASURED**: `osdi library library ... : Loads a osdi library.` on all
three); the command entry is inside `#ifdef OSDI` (**SOURCE**, `commands.c:288-293`) so its
presence is the real signal. `$xspice_enabled` is safe — spinit reads it, it does not unset it.

**Trap 2 — KLU compiled in is not KLU in use.** **MEASURED**: with no `option` card, every run
on every binary prints `Using SPARSE 1.3 as Direct Linear Solver`; after `option klu` it prints
`Using KLU as Direct Linear Solver`. Both go to **stdout** (**SOURCE**, `cktsetup.c:388,421`
and `cktpzset.c:94,149` are `fprintf(stdout, …)`). So `-v`'s
`** Compiled with KLU Direct Linear Solver` means *available*, and the runtime line means *used*.
A GUI that reports "solver: KLU" from the banner is reporting a capability, not a fact about the
run — and §5's `sens ac` hazard turns on the second, not the first.

---

## 3. Casemode: what a stock binary does when you ask for it

This is the fork's headline feature and the measurement is unambiguous.

### 3.1 The variables

**MEASURED**, one deck, `-b`, three binaries:

| expression | APT-45.2 | UP47 | FORK |
|---|---|---|---|
| `echo $curcasemode` (stdout) | *(empty)* | *(empty)* | `fold` |
| …and on stderr | `Error: curcasemode: no such variable.` | same | *(nothing)* |
| `if $?curcasemode` | false | false | **true** |
| `set casemode=preserve` | **accepted silently** | **accepted silently** | accepted |
| `echo $casemode` after that | `preserve` | `preserve` | `preserve` |
| `set casemode=bogusvalue` | accepted silently | accepted silently | accepted silently |

Two consequences, both sharp:

1. **`$casemode` is NOT a capability probe.** It is an ordinary control variable, so `set` writes
   it and `echo` reads it back on every ngspice ever built. A GUI that sets it and reads it back
   to "confirm" gets `preserve` from a binary that has never heard of the feature.
2. **`$curcasemode` IS the probe, and `if $?curcasemode` is the clean form of it.** **MEASURED**,
   the silent three-way probe:
   ```spice
   .control
   if $?curcasemode
     echo "@@CASEMODE=yes:$curcasemode"
   else
     echo "@@CASEMODE=no"
   end
   .endc
   ```
   ```
   APT-45.2   @@CASEMODE=no
   UP47       @@CASEMODE=no
   FORK       @@CASEMODE=yes:fold
   ```
   `$?var` produces **no stderr line at all**, where `echo $curcasemode` produces
   `Error: curcasemode: no such variable.`. For a GUI that treats stderr as a problem signal
   that difference matters. This is the known-0 / known-1 pair `ase::sim_capabilities` wants.

**SOURCE** confirms the contract was designed for exactly this use —
`src/include/ngspice/sharedspice.h:105-108`:

> `A build without this feature has no such variable and answers 'Error: curcasemode: no such
> variable.' on stderr, which is how a caller can detect the capability before committing to it.`

Note also the fork's own subtlety, **MEASURED**: after `set casemode=preserve` inside a
`.control` block, `$curcasemode` still reads `fold`, because the mode takes effect on the *next*
netlist read. `casemode` is the request; `curcasemode` is the fact. A GUI must read the second.

### 3.2 What actually happens to a deck — the silent no-op, measured

The dangerous half. Deck with mixed-case nets, run as `-D casemode=preserve`:

```spice
* casemode behavioural probe: mixed-case nodes
v1 In 0 dc 1
r1 In OuT 1k
r2 OuT 0 1k
.op
.control
run
print all
.endc
```

**MEASURED:**

```
APT-45.2   @@curcasemode=[]           in = 1.000000e+00   out = 5.000000e-01   v1#branch = -5.00000e-04
UP47       @@curcasemode=[]           in = 1.000000e+00   out = 5.000000e-01   v1#branch = -5.00000e-04
FORK       @@curcasemode=[preserve]   In = 1.000000e+00   OuT = 5.000000e-01   v1#branch = -5.00000e-04
```

**On a stock binary `-D casemode=preserve` is a completely silent no-op: rc 0, no warning on
either stream, the deck runs, and every net name comes back lower-cased.** There is no error to
catch. (`print all` labels correctly here on all three because the plot holds three vectors —
the one-vector case where it does not is §6.) If ASE-L asks for `preserve` and then looks vectors up by the spelling the schematic
uses, it finds nothing on stock ngspice and cannot tell why from the run's output. Detection has
to happen *before* the run, with `$?curcasemode`.

### 3.3 The raw-header marker is fork-only, and it is a per-file provenance stamp

`-D casemode=preserve -D casemodewrite` + `-r out.raw`, **MEASURED** header bytes:

```
APT-45.2 / UP47                        FORK
Plotname: Operating Point              Plotname: Operating Point
Flags: real                            Option: casemode=preserve
                                       Flags: real
  0  v(in)     voltage                   0  v(In)     voltage
  1  v(out)    voltage                   1  v(OuT)    voltage
```

So a rawfile written by the fork under `casemodewrite` carries `Option: casemode=<mode>` and a
rawfile from stock never does. That is a **post-hoc** capability marker on the artifact —
useful for a reader that did not run the simulator itself, useless as a pre-flight probe.

---

## 4. The four known hazards, per binary

| hazard | APT-45.2 | UP47 | FORK | discriminates? |
|---|---|---|---|---|
| D1 `.disto` + unresolvable save → SIGSEGV | **present** | **present** | **present** | **no** |
| D2 `ac lin 2 f1 f2` → one point | **present** | **present** | **present** | **no** |
| D3 `sens … ac` under `option klu` → SIGSEGV | **present** | **present** | **present** | **no** |
| D4 `No. Points` 8-char overflow > 99,999,999 | **present** | **present** | **present** | **no** |

**All four are universal. Not one of them is version-discriminating across the three binaries a
user can plausibly have.** That is the single most consequential result in this dossier for the
design, and §7 draws the conclusion.

### 4.1 D1 — `.disto` SIGSEGV, three deck shapes, three binaries, nine runs

**MEASURED**, `rc=139` (`Segmentation fault`) on **every one of the nine**, each preceded by the
same stderr line `Error: no data saved for Small signal distortion analysis; analysis not run`:

| deck shape | APT-45.2 | UP47 | FORK |
|---|---|---|---|
| `.save v(nosuchnode)` + `.disto` + `.control run` | 139 | 139 | 139 |
| `.op` + `.disto`, plain `-b`, no `.control` | 139 | 139 | 139 |
| `.control` `save v(nosuchnode)` then `disto …` — ASE-L's exact shape | 139 | 139 | 139 |

**SOURCE**: `distoan.c:516,540,563,584,606` discard `OUTpBeginPlot`'s return at all five plots.
Present in both trees; the fork did not fix it either.

### 4.2 D2 — `ac lin 2` returns one point

**MEASURED**, `ac lin N 1k 11k` then `let n = length(frequency)`:

| N | 1 | **2** | 3 | 11 | `dec 2` |
|---|---|---|---|---|---|
| APT-45.2 | 1 | **1** | 3 | 11 | 3 |
| UP47 | 1 | **1** | 3 | 11 | 3 |
| FORK | 1 | **1** | 3 | 11 | 3 |

Identical on all three, exactly as `acan.c:103-114` predicts. **SOURCE**: `diff` of
`origin/pre-master-47:src/spicelib/analysis/acan.c` against the fork's is **empty** — the file
has not been touched by any of the 207 commits. The same is true of `cktsens.c` (D3) and
`distoan.c` (D1).

### 4.3 D3 — `sens … ac` under `option klu`

**MEASURED**, an R–C–R divider, `sens v(mid) …`:

| deck | APT-45.2 | UP47 | FORK |
|---|---|---|---|
| `option klu` + `sens v(mid) ac dec 1 1k 10k` | **139** | **139** | **139** |
| `option klu` + `sens v(mid)` (DC) | 0, `r1 = -2.50000e-04` | 0, same | 0, same |
| `option sparse` + `sens v(mid) ac dec 1 1k 10k` | 0 | 0 | 0 |

DC sensitivity is safe under KLU on all three; AC sensitivity under KLU kills all three.

### 4.4 D4 — the 8-character `No. Points` field

I ran the expensive version and also found a cheap structural probe; both are reported because
the cheap one is what a GUI can afford.

**The cheap structural proof, MEASURED on all three** — write any rawfile with `-r`, then look
at the field with `cat -A`:

```
op   plot (1 point) :  No. Points: 1       $
tran plot (1012 pts):  No. Points: 1012    $
```

Identical bytes on APT-45.2, UP47 and FORK. The field is exactly **8 characters wide**,
back-filled left-aligned, and the residue of the placeholder spaces survives — so a **9-digit**
count must consume the newline. **SOURCE** confirms the mechanism in both trees:
`outitf.c` reserves it with `fprintf(run->fp, "0       \n"); /* Save 8 spaces here. */` and
`fileEnd()` back-fills with `fprintf(run->fp, "%d", run->pointCount)` — no width.

**The expensive confirmation, MEASURED.** `.tran 1n 100m` (100,000,008 rows), 2 variables,
`-b -r`:

| binary | wall | rawfile | stdout | header on disk |
|---|---|---|---|---|
| UP47 | **91.9 s** (`/usr/bin/time -v`), 15 MB max RSS | 1,600,000,404 B | `No. of Data Rows : 100000008` | `No. Points: 100000008Variables:$` |
| APT-45.2 | 107 s (header `Date:` → file mtime) | 1,600,000,405 B | `No. of Data Rows : 100000008` | `No. Points: 100000008Variables:$` |
| FORK | 115 s (same method) | 1,600,000,404 B | `No. of Data Rows : 100000008` | `No. Points: 100000008Variables:$` |

The newline is gone; `Variables:` is welded onto the count. And ngspice will not read back what
ngspice wrote — **MEASURED**, `load` of that header on all three:

```
Error: strange line in rawfile:
  load aborted.
no data read.
rc=1
```

---

## 5. Version reporting — what a GUI can actually key on

### 5.1 The banner

`ngspice -v`, **MEASURED**, rc 0 on all three:

```
APT-45.2                          UP47                              FORK
******                            ******                            ******
** ngspice-45.2 : Circuit …       ** ngspice-46+ : Circuit …        ** ngspice-46+ : Circuit …
** Compiled with KLU …            ** Compiled with KLU …            ** Compiled with KLU …
…
** Creation Date: Fri Sep 12      ** Creation Date: Thu Sep 10       ** Creation Date: Thu Sep  3
   11:58:13 UTC 2025                 21:51:07 UTC 2026                 06:46:24 UTC 2026
******                            ******                            ******
```

> **UP47 and FORK report the SAME version string, `ngspice-46+`.** **SOURCE**: both trees'
> `configure.ac:19` reads `m4_define([ngspice_major_version], [46+])`, and the fork has not
> touched it. The only field that differs is `Creation Date`, which is the build timestamp of
> whoever ran `make` — not an identity. Rebuild stock tomorrow and it is newer than the fork.

**There is no version string, anywhere, that distinguishes the fork from stock upstream.**
Combine that with §1.1 (identical command table, identical help text) and §4 (identical hazards)
and the conclusion is forced: a version-keyed capability table cannot express what ASE-L needs
to know about the fork. Only a probe can.

### 5.2 The `version` command, and the CLI flags that are a trap

**MEASURED**, `version` inside `.control`:

| form | APT-45.2 | UP47 | FORK |
|---|---|---|---|
| `version -v` | `ngspice-45.2` | `ngspice-46+` | `ngspice-46+` |
| `version -d` | `Fri Sep 12 11:58:13 UTC 2025` | `Thu Sep 10 21:51:07 UTC 2026` | `Thu Sep  3 06:46:24 UTC 2026` |
| `version -s` | banner, short | banner, short | banner, short |
| `version -f` | full, **+ CIDER + XSPICE + OpenMP** | full, **+ XSPICE + OpenMP** | full, **+ XSPICE + OpenMP** |

**`version -v` is the best machine-readable key available: one bare line, `<simulator>-<version>`,
on stdout, and it works on all three including 45.2.**

**`version -f` is the closest thing to a compile-options dump.** **SOURCE**, `misccoms.c:228-290`,
it reports exactly: KLU-vs-Sparse, `CIDER`, `XSPICE`, `NGDEBUG`, `USE_OMP`, X11-missing,
`NOBYPASS`, `CAPBYPASS`, `NODELIMITING`, `PREDICTOR`, `WANT_SENSE2`, `EXPERIMENTAL_CODE`,
`EXP_DEV`, `SHARED_MODULE`. **It does NOT report `OSDI`, `RFSPICE` or `WITH_PSS`** — the three
flags a GUI most wants. So `version -f` answers CIDER and PREDICTOR (which had no probe before,
`00-critique.md` §5.1) and leaves OSDI/RFSPICE/PSS to `help osdi` / `devhelp vsource` /
`help pss`.

**The CLI trap.** `-f`, `--version-full` and `--version-small` are 46-era additions.
**MEASURED** on APT-45.2:

```
/usr/bin/ngspice: invalid option -- 'f'
Error: incomplete or empty netlist … no simulations run!     rc=1
```

The unknown flag does not stop the program — it falls through into batch mode and exits 1.
**A GUI must never probe with `-f` / `--version-full` / `--version-small`.** `-v` is universal.

### 5.3 The rawfile header carries a version too

**MEASURED**, every `-r` rawfile's third line:

```
Command: ngspice-45.2, Build Fri Sep 12 11:58:13 UTC 2025
Command: ngspice-46+, Build Thu Sep 10 21:51:07 UTC 2026
Command: ngspice-46+, Build Thu Sep  3 06:46:24 UTC 2026
```

Same string, so the same fork-vs-stock ambiguity — but it is attached to the *artifact*, so a
reader handed a rawfile it did not produce can at least recover the version and build date
without re-running anything. Together with §3.3's `Option: casemode=…` line (fork-only, opt-in),
those are the two provenance fields a rawfile carries, and the casemode line is the only one of
the two that separates fork from stock.

---

## 6. A behavioural divergence that no probe in §1–§5 would have found

Everything above says fork and stock are indistinguishable by inspection. Here is the other
half: they are **not** indistinguishable by behaviour, and the difference bites the exact code
path ASE-L uses. This is one measured instance of category V3b; the systematic hunt belongs to
whoever takes that task, but the shape is worth pinning down here because it calibrates how
dangerous the category is.

**MEASURED**, an all-lower-case deck, single narrowing `save`:

```spice
v1 in 0 dc 1
r1 in midnode 3k
r2 midnode 0 1k
.control
save v(midnode)
op
print all
.endc
```

```
APT-45.2   all = 2.500000e-01
UP47       all = 2.500000e-01
FORK       midnode = 2.500000e-01
```

The **value** is right everywhere; the **label** is wrong on stock. `display` shows the plot is
correct on all three (`midnode : voltage, real, 1 long`), and `print v(midnode)` prints
`v(midnode) = 2.500000e-01` on all three. The divergence appears only through the `all`
wildcard, and only when it matches **exactly one** vector — with two saved vectors
`print all` prints `in = …` / `midnode = …` identically on all three. **MEASURED** both ways.

**SOURCE**, the fork's fix is `vec_is_all_wildcard()` in `src/frontend/vectors.c` (commit
`fix: withhold the wildcard rename from a one-vector match`, `doc/codex/issues/0064`), whose own
comment states the mechanism:

> `ft_evaluate() labels a result with the text of the parse node that produced it whenever the
> result is a single unchained vector, which is right for an expression and wrong for a
> wildcard: "all" names nothing…`

UP47 has no such symbol — **MEASURED**, `git grep -c vec_is_all_wildcard origin/pre-master-47 -- src/`
returns nothing, while on `ver_50` it names `src/frontend/evaluate.c`, `src/frontend/vectors.c`
and `src/include/ngspice/fteext.h`.

The same divergence appears with a **mixed-case** deck, which is the shape ASE-L actually emits.
**MEASURED**, nets written `In` / `MidNode` and `save v(MidNode)` with no casemode set:
APT-45.2 and UP47 print `all = 1.000000e+00`, FORK prints `midnode = 1.000000e+00`. The `save`
itself resolves on all three (`display` confirms `midnode` is in `op1` everywhere) — case is not
what breaks here, the one-vector wildcard is.

Why this one matters more than its size suggests: **ASE-L narrows the save list from its Outputs
pane**, so "exactly one saved vector" is not an exotic case, it is what happens when a user
probes one net. A GUI that scrapes `print all` output by name gets a column called `all` on
stock ngspice and the net's real name on the fork. Silent, rc 0, right numbers, wrong key.

The general lesson for the plan: **the fork's 96 `fix:` commits are invisible to every
capability probe.** They change what ngspice *does*, not what it *has*. No amount of probing
finds them; only knowing they exist does.

---

## 7. What this measurement says about the design (V3 and V6)

Stated as findings, not recommendations — the plan owns the recommendation.

**F1. The four-category split (V3) survives contact, but the boundary moved.** Categories (a)
and (c) are probeable and I have working probes for both (§2, §3.1). Category (d) —
"unprobeable hazards needing a version-keyed table" — **has nothing to key on**: all four
measured hazards are present on all three binaries (§4), and the two 46+ binaries are
version-identical anyway (§5.1). A version-keyed hazard table built today would have one row
("all known versions") and one column. **The table is not wrong, it is empty**, and the
machinery to consult it is machinery that currently earns nothing.

**F2. V6's "apply mitigations down, unconditionally" is right, and §4 is the reason.** Every
mitigation the batch has proposed — never emit a narrowed `save` alongside `disto`, never emit
`option klu` with an AC `sens`, refuse `ac lin 2`, cap or ignore `No. Points` above 8 digits —
is needed on **every** binary measured. There is no build on this machine for which any of them
is dead weight. Gating them on a version would add a branch that is never false.

**F3. V6's "gate capabilities up, prove before you offer" is right, and the three-way
PSS/CIDER/`pyplot` result is the reason.** APT-45.2 has one analysis (`pss`) and five device
families (CIDER) that the newest binary lacks; the newest binary has one command (`pyplot`) and
two code models (`astate`, `ota`) that APT-45.2 lacks. **Capability moves in both directions at
once.** A GUI that reasoned "45.2 is old, 46+ is newer, so 46+ has everything 45.2 has" would be
wrong about PSS and CIDER, and a GUI that reasoned the other way would be wrong about `pyplot`.

**F4. There is one place where "gate up" needs a footnote.** Casemode is a capability (gate up),
but asking for it on a binary that lacks it is **silent** (§3.2) rather than refused. So the
gate cannot be "ask and check for an error" — there is no error. It has to be "probe
`$?curcasemode`, and if false, never emit `set casemode=` **and** never assume a name's case
survives." The second half is the one that is easy to forget: the mitigation for *not* having
the capability is a change to how ASE-L reads results, not just a suppressed line.

**F5. The adapter's variant key cannot be a version string.** Per D34-D37 the adapter owns
variant content. The natural implementation of that is a version→capability table, and §5.1
kills it: fork and stock share `ngspice-46+`. What the adapter can key on is the **probe result
vector** — `{pss, cider, osdi, rfspice, xspice, klu, casemode, pyplot}` — cached the way
`ase::sim_capabilities` already caches, on resolved path + mtime + size. Version belongs in that
record as a *label for the user* and as the tie-breaker for the one thing probing cannot reach
(F6), not as the key.

**F6. The one thing probing cannot reach is the fork's 96 fixes (§6).** They have no probe, no
command, no version. If ASE-L must know whether it is on a fixed simulator, the only honest
signals available today are (i) `$?curcasemode` used as a **proxy** for "this is the fork" —
sound today because the 9 casemode `feat:` commits and the 96 `fix:` commits ship together, and
fragile the moment casemode is upstreamed without the fixes or vice versa — or (ii) not knowing,
and writing ASE-L so it does not depend on any of the 96. **(ii) is the only one that does not
rot**, and §6 shows what it costs: `print all` output must be read positionally or via
`display`, not by trusting the label. Whether every one of the 96 admits such a workaround is
the open question this dossier cannot answer.

---

## 8. The probe kit, as one deck

Everything §1–§5 needs, in a single `-b` run. **MEASURED — this is the literal deck
(`variants/decks/probekit.cir`), run on all three binaries, rc 0 on each.**

```spice
* ASE-L capability probe
v1 1 0 dc 1
r1 1 0 1k
.op
.control
version -v
version -d
if $?curcasemode
  echo "@@casemode=$curcasemode"
else
  echo "@@casemode=none"
end
if $?xspice_enabled
  echo "@@xspice=yes"
else
  echo "@@xspice=no"
end
echo "@@osdi_BEGIN"
help osdi
echo "@@osdi_END"
echo "@@pss_BEGIN"
help pss
echo "@@pss_END"
echo "@@sp_BEGIN"
help sp
echo "@@sp_END"
echo "@@pyplot_BEGIN"
help pyplot
echo "@@pyplot_END"
echo "@@devhelp_BEGIN"
devhelp
echo "@@devhelp_END"
echo "@@versionf_BEGIN"
version -f
echo "@@versionf_END"
.endc
.end
```

**Its three-way answer, MEASURED:**

| line | APT-45.2 | UP47 | FORK |
|---|---|---|---|
| `version -v` | `ngspice-45.2` | `ngspice-46+` | `ngspice-46+` |
| `@@casemode=` | `none` | `none` | **`fold`** |
| `@@xspice=` | `yes` | `yes` | `yes` |
| `help osdi` | `osdi library library …` | same | same |
| `help pss` | `pss [.pss line args] …` | `Sorry, no help for pss.` | `Sorry, no help for pss.` |
| `help sp` | `sp [.sp line args] …` | same | same |
| `help pyplot` | `Sorry, no help for pyplot.` | `pyplot [file] plotargs …` | `pyplot [file] plotargs …` |
| `devhelp` CIDER rows | **5** | 0 | 0 |
| `version -f` | `** CIDER 1.b1 …` + XSPICE + OpenMP | XSPICE + OpenMP | XSPICE + OpenMP |

Rules the measurements impose on any reader of that output:

* Absence of a command is `Sorry, no help for <x>.` — match on the leading token of the
  *positive* answer, never on the sentence (`builds.md` §1.1 records that `pss`'s help string is
  spelled two different ways in the two command tables).
* Do **not** use `$osdi_enabled` (§2.1 trap 1). Do **not** use `$casemode` (§3.1). Do **not**
  invoke `ngspice -f` / `--version-full` / `--version-small` (§5.2) — they are not options on 45.2.
* `devhelp` needs `SPICE_LIB_DIR` to be right for an uninstalled build, or the CIDER and
  code-model rows are missing for a reason that has nothing to do with the flags (§0.1).
* The whole kit costs **one** `ngspice -b` invocation. That is what makes caching it on
  resolved path + mtime + size (the `ase::sim_capabilities` discipline, V4) cheap enough to be
  the only mechanism.

---

## 9. What I did not close

1. **No non-KLU, non-XSPICE, non-RFSPICE build exists to test the negative side of those three
   probes.** Every binary on this machine has all three. The probes are sound by **SOURCE**
   (`#ifdef` guards around the `klu` option entry at `cktsopt.c:371-377`, the `osdi` command at
   `commands.c:288-293`, the `sp` command at `commands.c:332-338`, the `portnum` parameters at
   `vsrc.c:31-37`) but their **known-0 leg is unmeasured**. Closing it costs one
   `../configure --disable-xspice --disable-osdi --disable-klu --disable-sp && make -j8`, about
   two minutes on the evidence of §0.
2. **Only one Debian version was available.** Everything said about "the apt ngspice" is about
   `45.2+ds-1` on this machine. Other distributions and other Debian releases will differ, and
   `--enable-cider --enable-pss` being in Debian's build is a *packager's* choice, not a
   property of 45.2.
3. **Stock 47 is not released.** UP47 is `origin/pre-master-47` @ `c5cd68015`, which reports
   itself as `46+`. When 47 ships, `configure.ac:19` will change to `47` and the version
   ambiguity of §5.1 *between fork and stock* will resolve for that release — but only until the
   fork rebases onto it.
4. **The 96 `fix:` commits were not systematically differenced.** §6 measures one. A full pass
   over them, deciding for each whether ASE-L can depend on stock behaviour, is a separate task
   and is the highest-value follow-on this dossier can point at.
5. **`libngspice` was not built for any of the three variants here** — `builds.md` PART 3 covers
   it for the fork only. Whether the shared build of *stock* has the same `ngSpice_Reset`
   behaviour is untested.

---

## 10. Artifacts

All kept under `/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/`:

| path | what |
|---|---|
| `builds/upstream47/` | the stock build — `src/ngspice` (8,194,472 B), `configure.log`, `make.log`. Survives the worktree removal; **MEASURED** running after it. |
| `libdir/upstream47/`, `libdir/fork/` | staged `spinit` + `*.cm` so `SPICE_LIB_DIR` makes an uninstalled build behave like an installed one (§0.1) |
| `variants/run3.sh` | the three-binary runner every measurement above used: `run3.sh <deck> [ngspice args…]` |
| `variants/decks/` | all 31 probe decks, named as cited in the text |
| `variants/out/allcmds.tsv` | the 402-row command matrix (binary, command, help line) |
| `variants/out/verbs.txt`, `flags.txt`, `case1.txt`, `case2.txt`, `ver.txt` | raw three-binary captures for §1, §2, §3, §5 |
| `variants/out/overflow_{apt,up47,fork}.log` | the three 100 M-row runs of §4.4 |
| `variants/out/rc_{apt,up47,fork}.raw` | the three casemode-header rawfiles of §3.3 |

Removed after use: the scratch worktree `workpad/upstream47` (`git worktree remove --force`;
`git worktree list` now shows only `/home/analog/dev/ngspice ccebdf2a2 [ver_50]`, and
`git status --short --branch` is `## ver_50...origin/ver_50` with no modified files), and the
three 1.6 GB overflow rawfiles under `workpad/bigraw/`.
