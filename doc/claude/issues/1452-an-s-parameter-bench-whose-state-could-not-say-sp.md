# 1452 — an S-parameter bench whose state could not say `sp`

**Status:** fixed (Stage 9's DECK half; the GUI half — the Ports table, the S-parameter
surface, the matrix picker and Smith/polar — is a separate task and is NOT in this commit)
**Branch:** `fluid-editing`
**Area:** ASE-L — the analysis registry, the `setup` contract, the ngspice adapter (`src/ase.tcl`)
**Suites:** `tests/headless/test_ase_sp_1452.tcl` (new, 41 checks, identical on both arms,
registered in `run_regression.tcl`'s `hcases`); rows moved in `test_ase_core.tcl`,
`test_ase_meas_1443.tcl` and `test_ase_preflight.tcl`
**Batch:** `doc/claude/ase_analyses_batch/`, **PLAN.md Stage 9**, rulings ⚖ **R9**
**Decisions:** D3, D4, D34–D37, and issue **0964**'s op-last rule, which this amends by
measurement

---

## The defect

**Four S-parameter benches are committed in this repository** —
`ihp-sg13g2/xschem_libs/sg13g2_tests_ase/sp_{mim_cap,rfmim_cap,parasitic_cap,svaricap_test}`
— whose sources carry `portnum 1 z0 50` and whose ASE-L state says, in full:

```
analyses {{type op enabled 0} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}
```

Four seeded rows, **none of them the analysis the bench exists for**, because ASE-L had no
way to say `sp`. Somebody built those benches and then drove the simulator by hand.

## ⚠ And the obvious fix is the one ASE-L is not allowed to make

A port is an **ordinary voltage source carrying `portnum`** (`vsrc.c:31-37`); there is no
port device and no port model. ASE-L's founding doctrine is that the schematic carries only
the circuit, so `portnum 1 z0 50` may not be written onto it. `design-B` concluded from this
that `sp` was simply unsatisfiable and made `two_ports` a precondition with no route to
satisfy it (critique §C11).

It **is** satisfiable. Measured 2026-09-13 on apt 45.2 **and** on the fork, on two *ordinary*
V sources that declare no port anywhere in the netlist:

```
alter v1 portnum = 1 / alter v1 z0 = 50
alter v2 portnum = 2 / alter v2 z0 = 50
sp lin 3 100meg 1g
   -> rc 0, `SP Analysis`, s_1_1[0] = 2.500000e-01,0.000000e+00
```

## What shipped

| | |
|---|---|
| **the `sp` registry entry** | `emitorder 95`, `viewrank 25`, `resultvecs own`, six fields (`sweep` `points` `start` `stop` `donoise` `s2p`), the card `sp @sweep? @points @start @stop @donoise!`, two `plots` rows |
| **the `setup` contract** | a new registry key. ASE-L owns its SHAPE and its readers; the adapter owns every line it produces. `key` `noun` `min` `fields` are schema; `lines` `post` `check` are adapter procs |
| **`ase::analysis_setup{,_key,_rows,_emit}`** | four core readers. They COUNT the table and never look inside an entry, because `z0` is an ngspice keyword (D34–D37) |
| **`two_ports`** | a **fatal** precondition, evaluated over the table rather than over the netlist |
| **`setup_check`** | a second precondition that delegates the simulator's own rules to the declared `check` hook |
| **`ase::backend::ngspice::sp_alter_lines` / `sp_export_lines` / `sp_row_check` / `s2p_file`** | the content: the promotion lines, the Touchstone export, the table's rules, the artifact path |

## ⚠ The measurement that changes issue 0964's emit order

**Promoting a source to a port changes every other analysis in the run**, and the promotion
**cannot be undone**. Both measured 2026-09-13 on both binaries:

```
op                                  -> v(in) = 1.000000e+00
alter v1 portnum = 1 / z0 = 50 ... sp lin 3 100meg 1g
op                                  -> v(in) = 6.250000e-01

alter v1 portnum = 0
   -> `Internal Error: incomplete CKTunsetup(), this will cause serious problems,
       please report this issue !`
      `ERROR: fatal error in ngspice, exit(1)`, rc 1
```

`vsrcset.c:53-79` adds an internal `<name>#res` node per port and `vsrcload.c:51-64` stamps
`g0 = 1/z0` across it. So there are exactly two orders available: **`op` before `sp`** gives a
correct operating point and leaves the SP plot carrying the op tier's forward-sticky device
columns, and **`op` after `sp`** gives an operating point measured on a circuit that has grown
two resistors, at rc 0, with nothing said.

**0964's rule is about which vectors land in which plot; this is about whether a printed number
is true.** `sp` therefore takes `emitorder 95`, which beats `op`'s op-last 90 **and** its
non-op-last 0 — so `sp` is last under both variants with **no change to
`ase::analysis_emit_rank`**. Rows SR4/SR4b/SE2 are the claim, and sabotage **s5** (rank 25)
reds SR4 and SR4b by name.

## ⚠ `two_ports` is FATAL, and it takes `op` with it

Measured on both binaries, with `echo AFTER_SP` and an `op` after the card:

| what is wrong | stderr | rc | did the block continue |
|---|---|---|---|
| no source carries `portnum` | `Error: No RF Port is present, cannot run sp analysis` + `ERROR: fatal error in ngspice, exit(1)` | 1 | **no** |
| exactly one port | `Error: Only one RF Port is found, we need at least two!` + the same | 1 | **no** |

`span.c:376-386` calls `controlled_exit(EXIT_BAD)`: the **process** dies. Every analysis after
`sp` dies with it — `op` included. The same four `alter` lines moved **below** the card produce
the first row exactly, which is why the promotion sits above it (sabotage **s1**).

## The four rules the adapter's `check` leg holds

All measured 2026-09-13 on both binaries. All **fatal**, not because the process dies — it does
not, the block runs on — but because this tree's own deck puts a `$sim_status` guard after every
analysis and the guard's `quit 1` fires (issue 1424's definition).

```
portnum 1,3 / 2,3  -> Fatal error: v2: incorrect port ordering
portnum 1,1        -> Fatal error: v1: duplicate port Index
z0 = 0  /  z0 = -50 -> Fatal error: v2: incorrect port ordering
```

⚠ **The last one names the wrong source and the wrong problem.** `vsrctemp.c:74-82` requires
`z0 > 0` to promote, so a zero silently demotes **v1** and ngspice then complains about **v2**,
which is fine. ASE-L says so instead, in the sentence ⚖ R9 lists.

## ⚠ A narrowed save list silently removes the whole answer

```
.save v(mid) + sp   -> rc 0, plot `SP Analysis`, vectors `frequency` and `mid` and NOTHING ELSE
.save all above it  -> S_1_1 present
```

Hence `resultvecs own`, which makes `ase::saves_widen_types` emit the leader and `vecsaves` say
it did.

## ⚠ The Touchstone export uses `let`/`unlet`, not the documented `.csparam`

APPENDIX §2.11 records `.csparam Rbase=50` as *"the workaround nobody promoted to a
recommendation"*. Measured 2026-09-13 on both binaries:

| | result |
|---|---|
| nothing | `Error: No Rbase vector given`, **no file** |
| `set Rbase = 50` | the same — a shell variable is not a vector |
| `.csparam Rbase=50` | an 8-line Touchstone file, results file `No. Variables: 20` |
| `let Rbase = 50` / `wrs2p` / `unlet Rbase` | **the same 8-line file**, `No. Variables: 20` |
| `let` **without** the `unlet` | the same file, results file `No. Variables: **21**` — a `16 rbase notype dims=1` column the user never asked for |

`let`+`unlet` is per row, per Z0 and leaves the deck body untouched; `.csparam` is a deck-level
card and could not carry two `sp` rows with different port-1 impedances. Sabotage **s8** drops
the `unlet` and reds SL4 **and both end-to-end rows**.

## ⚠ The brief's `mislabel` question, answered: NO

`evidence/sp-stage9.md` says the mixed-case S-parameter vector names are *"the exact shape
`mislabel` was written to catch, so it should catch this"*. Measured, rows SM1–SM5: **it does
not, and it should not.**

`mislabel` compares **plot** names, and `Plotname: SP Analysis` is byte-identical on both
binaries. Both of its comparisons are case-**in**sensitive by construction (`string equal
-nocase` against the results file, `string match -nocase` against the registry), so a lowercased
`select` is tolerated — proved with a genuinely different name (`Scattering Parameters`) as the
positive control, which reds immediately and names the row and both names.

The mixed case is real and it lives in the **vector** names:

```
fork      frequency S_1_1 S_1_2 … Y_1_1 … Z_1_1 …    NF NFmin Rn SOpt
apt 45.2  frequency s_1_1 s_1_2 … y_1_1 … z_1_1 …    nf nfmin rn sopt
```

`display` shows the capitals on both; it is the **rawfile** that differs — `tf`'s folding
finding, measured again for `sp`. This stage ships **no reader of those names**, and row SM5
asserts that absence so the surface that does add one (PLAN.md §9b's matrix picker) cannot be
written case-sensitively and stay green.

## The corrections this stage makes to the plan

| | |
|---|---|
| **C1** | PLAN.md §9's `lin_two` **refusal** is not shipped. `lin_points` already exists, is a **caution** by ⚖ D47 (*"refusing removes a number the user typed into a form"*), and its own comment says it *"covers `sp` the day `sp` gets a sweep"*. A second rule with a different verdict over the same condition is the drift this batch deletes. Row SN6 |
| **C2** | `sp` emits **after `op`**, not among the small-signal analyses — the port-promotion measurement above. PLAN.md does not say where `sp` sits; 0964 would have put `op` last |
| **C3** | `sp` **declares a `viewrank`** where `tf` and `pz` do not, because `src/save.c:889` reads `else if(!my_strcasecmp(type, "sp")) type = "ac";` — measured, `xschem raw read <file> sp` answers 1 with `sim_type=ac`. Below `ac`, because with both plots in one file the reader loads the FIRST and refuses the second |
| **C4** | the Touchstone export is `let`/`unlet`, not `.csparam` (above) |
| **C5** | the brief's `mislabel` premise is refuted (above) |
| **C6** | `sp` is **not** a fork-only capability: it runs on apt 45.2 as well, so `baseline 0` is kept for the `#ifdef` and the probe, not because the binary is expected to lack it |

## What is still owed

* **Stage 9's GUI half** — the Ports table (§9a), the S-parameter surface, the matrix picker and
  Smith/polar (§9b). `src/ase_window.tcl` is **untouched** by this commit.
* **⚖ R9** — the new user-facing copy, listed verbatim in the receipt and recorded with
  `owed.sh add rule 1452`.

⚠ **No `look` debt and no `suite` debt are filed by this task, and both are measurements
rather than claims.** Nothing here draws a pixel: `src/ase_window.tcl` is untouched, and the
new suite's two arms are **41 and 41 with the same rows** (`diff` of the two ok-lists is
empty). `PLAN.md` §9's *Re-measure on the dev display* paragraph asks for the Ports table and
the S-matrix picker — both of which are the GUI half's, along with the conditional `look` debt
its ⚠ describes for a Smith chart drawn outside the waveform viewer.
