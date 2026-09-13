# 1439 — a pre-deck option had no door, and `wnflag` never needed one

**PLAN.md Stage 7d, task 2 of Stage 7's four. ⚖ R2's four conditions, ratified
2026-09-10, are its requirements.** Fixes **issue 1438** — all three defects,
and refutes 1438's own account of the first one.

**Branch:** fluid-editing. Suite: `tests/headless/test_ase_predeck_1439.tcl`
(**78 checks**, registered in `tests/run_regression.tcl`'s `hcases`, so T1 covers
all 78).

## What went wrong for the user

Thirty-two of ngspice's options are reachable from **neither** `.options` **nor**
`.control`. ASE-L offered them beside `reltol`, wrote a `.options` card for them,
and the simulator ignored it without a word. `.options casemode=preserve` folds
every node name anyway; `.options ngbehavior=hs` selects no compatibility mode at
all. There is no error channel for any of it — measured on both binaries, an
unknown or unreachable option name prints **nothing on either stream** and is
silently invented as a front-end variable.

And **five committed benches asked for `wnflag` and none of them got it**.

## ⚠ The root cause is not the one issue 1438 named

1438 says `wnflag` cannot be reached by any `.options` card because one of its
three read sites runs during card reading. **Two of those three sites are dead
code**, verified in `/home/analog/dev/ngspice` (`ver_50`, `ccebdf2a2`):

* `src/frontend/inpcom.c:990` reads `wnflag` into a local that
  `inp_get_w_l_x()` **never uses again** — grep the function, the variable does
  not appear after the `cp_getvar` call;
* `src/frontend/inp.c:2828` is inside `#ifdef REM_UNUSED`, and **`REM_UNUSED` is
  defined nowhere in the ngspice tree** — three `#ifdef`s and no `#define`,
  nothing in `configure.ac`, nothing in the build's `config.h`. Same shape as
  `ramptime`'s `XSPICE_EXP`.

The one live read is `src/spicelib/parser/inpgmod.c:268`, inside
`INPgetModBin()`, at **model-binning time** — after `inp_dodeck()` turns the
deck's `.options` cards into `ci_vars`. ngspice's own comment three lines below
it says so: *"Now it depends on the default wnflag or on the `.options
wnflag`."*

**MEASURED on both binaries** — `/usr/bin/ngspice` (45.2) and the fork
(`ngspice-46+`) — on a flat `m` line **and** on the sky130 `x`-line shape the
five benches actually use, with two binned models 0.4 V apart:

```
.options wnflag          @m1[vth] 9.888996e-01   i(vd) -1.01728e-03   <- ASE-L's line
.options wnflag=1        @m1[vth] 5.888996e-01   i(vd) -1.73730e-03
set wnflag=1 (.control)  @m1[vth] 9.888996e-01                        <- too late
-D wnflag=1              @m1[vth] 9.888996e-01                        <- CP_STRING
-D wnflag                @m1[vth] 9.888996e-01                        <- CP_BOOL
<rundir>/.spiceinit
  set wnflag=1           @m1[vth] 5.888996e-01                        <- works
```

A **71% difference in drain current**, at rc 0, with a clean log.

So `wnflag` is a **`deck`** option, not a pre-deck one, and issue 1438's defect 1
**is** its defect 2: a valued option stored as `1` was written as a bare card.
The catalogue row is corrected with the measurement on it, and the class drops
from 34 to 32 (`no_spinit` is the other departure — see below).

## What shipped

**Schema (`ase::`)** — `ase::opt_owner`, `ase::opt_offer`,
`ase::rundir_is_shared`, `ase::predeck_plan`, `ase::predeck_argv`,
`ase::predeck_deliver`, `ase::predeck_report`; an `owner` arm in
`ase::opt_line`, `ase::opt_restore_line`, `ase::state_option_delivery` and
`ase::option_schema_errors`.

**Content (`ase::backend::ngspice`)** — `predeck_file`, `predeck_marker`,
`predeck_user_file`, `predeck_write`, registered as the optional
`predeck_write` hook; the `-D` arm in `run_cmd`; the catalogue corrections.

**The emitter** — `render_deck`'s option loop now asks what kind of option it is
writing. Three arms: a name this simulator does not describe keeps the old rule
(a catalogue must not outrank the user); an option whose door is not the deck's
is left to the pre-deck doors; everything else goes through the one speller.

## ⚖ R2's four conditions, each as a row

1. **deleted and rewritten per run** — `FW3`/`FW4`, and it is deleted even when
   this run has nothing to put in it, because a stale one **shadows the user's
   own file** while it sits there.
2. **copied under a banner, never `source`d** — `UF4`/`UF5`. ⚠ And the dossier's
   reason is narrower than it says. `[R-M7]`'s transcript reproduces exactly —
   `Circuit: set frobnicate`, `Unable to find definition of model` — but **only
   when the sourced path does not contain `.spiceinit` or `spice.rc`**.
   `com_source` (`src/frontend/inp.c:1984`) is
   `substring(INITSTR, owl->wl_word)`, a plain substring test on the word that
   was typed; with the real name the variables survive on both binaries. A
   mechanism that turns on a substring of a path ASE-L composes is not a
   mechanism, and copying also lets ASE-L's lines come **last** so the bench
   beats the user's global default.
3. **the run log says once what it shadows** — `UF6`, with `UF7` as the
   non-vacuity row: with nothing of the user's there, the sentence must not
   invent a shadow.
4. **refused under `-n` and under the shared `set_netlist_dir 0` rundir** —
   `RF1`/`RF3`, each naming what it refuses over.

## ⚠ Condition 4 refuses the FILE, and `PLAN.md` §7d says it refuses everything

§7d writes *"every pre-deck option and the entire campaign mechanism are refused
when `-n` is in force"*. **MEASURED on both binaries: `-n` suppresses the
start-up file and nothing else.** `ngspice -b -n -D ngbehavior=hs <deck>` prints
`Note: Compatibility modes selected: hs` and the variable is in force.

⚖ R2's own text refuses **the file** (*"ASE-L writes `<rundir>/.spiceinit` … and
it is refused when … `-n` is in force"*), which is what is implemented. Refusing
`-D` as well would refuse a door measured to work — issue 1437's **C107** in a
different coat — and would delete `-D casemode=`, which this tree already emits
under `-n` today and which six rows of `test_ase_simreg_0931` pin. **A rule debt
is filed for the narrowing**: it is the user's call, and the shape implemented is
the ruling's own words.

## Two options ASE-L already delivers through a control of its own

`casemode` and `no_spinit` now carry an `owner`, and the speller refuses them.

* **`casemode`** — MEASURED on the fork: `-D casemode=preserve -D casemode=fold`
  answers `fold`, and the reverse answers `preserve`. **The last one wins.**
  `ase::run_casemode_flag` already puts one on the command line, gated by the B4
  pre-flight that *measures* what the binary delivers. A second one from an
  options row would land after it, win, and bypass the measurement entirely.
* **`no_spinit`** — MEASURED on both binaries: `-D no_spinit` does **not**
  suppress the start-up file (the run still read `<rundir>/.spiceinit`), while
  `-n` does. So its phase is `cmdline`, not `pre`, and its control is the
  simulator entry's `-n` flag.

## The inert list's three shapes

`ase::opt_offer` answers them as data §7c can draw: `no` (16 rows), `clamp`
(`itl1`/`itl2`/`itl4`, widget minimum 100), `caveat` (`defas`, whose
`.options defas` writes `TSKdefaultMosAD` — the **drain** area — at
`cktsopt.c:111`, the same field `OPT_DEFAD` writes at `:108`; and `scale`),
`elsewhere` (the two owned rows), `yes`.

## What this does not do

No pixel is drawn. §7c owns the options pane, the search box, the changed-only
view, the ⚠ badge and the live deck preview; §7e owns emit-then-restore and the
`control`-door rows, which still take the old `.options` card and are pinned by
`RD8` so the day they move, the suite says so.
