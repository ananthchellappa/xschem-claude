# Dossier: the hidden option surface — every `cp_getvar()` variable in the tree

**Closes critique holes §1.2 and §1.3, and completes `options.md`'s mechanism C.**

Tree: `/home/analog/dev/ngspice`, branch `ver_50`, `git describe = ngspice-46-419-gccebdf2a2`.
Binary for every empirical claim: `/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46+`).
Scratch decks: `/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/hv/`.
Nothing in either repository was modified.

**MEASURED** = I ran it in this session. **SOURCE** = I read it in this tree.
Everything else is attributed.

Reader: the session writing the ASE-L analyses plan. This dossier is the answer to
"what else, besides `.options`, silently changes my results — and when must the GUI
say it?"

---

## 0. Verdict in one paragraph

There are **163 distinct front-end variables read by `cp_getvar()`** at **304 call sites**
across 48 files, and **not one of them is an `OPTtbl` keyword** — the two catalogues are
completely disjoint, which is the one piece of good news. Of the 163, **21 change simulation
results** and **11 more decide whether a run happens or produces output at all**; the rest are
presentation, plotting devices, help, remote-spice and PSpice-`u`-device plumbing. The
mechanism has four traps that will each produce a "the GUI says X but the simulator did Y"
bug report: (1) **a `CP_BOOL` variable is silently turned OFF by writing `set x=1`** —
`set interp` gives 21 uniform points, `set interp=1` gives 109 raw ones, MEASURED; (2) **a
`CP_NUM`/`CP_REAL` variable is silently inert under a bare `set x`** and under
`ngspice -D x=1`, because `-D` only ever makes strings and booleans, MEASURED; (3) **26 of
them are read before `.options` exists** and can therefore only be delivered by `spinit`,
`.spiceinit`, `-D` or `-p` pipe mode — `.options nosubckt` and `.options casemode=preserve`
are silently ignored, MEASURED; and (4) `savecurrents` + `ac` is not merely "documented to
need `nosavecurrents`" — `nosavecurrents` **does not exist in this tree** (confirmed by a
whole-tree grep including `*.in` and `*.txt`) and the real behaviour is two different
failures depending on the output route: on the `.control` + `write` route **the whole
`write` aborts and no file is written at all**, and on the `-r` route the file is written
with every device-current column **identically zero at every frequency**. The in-tree remedy
is `remzerovec`, which ASE-L already emits (F13) — this dossier is the empirical
justification for that rule.

Method note that cost me an hour: **`grep -rn cp_getvar src` UNDER-REPORTS.**
`src/maths/cmaths/cmath4.c` is ISO-8859 text, GNU grep classifies it binary and silently
drops its matches. Use `grep -a`. The plain grep finds 299 lines and 161 names; `grep -a`
finds 304 and 163. The two it hides — `dpolydegree` and `mtimeavgwindow` — are both real.

---

## 1. The mechanism, stated exactly

`cp_getvar(name, type, retval, rsize)` (`src/frontend/variable.c:724`) is a **lazy** read:
the value is looked up at the moment the consuming code needs it, not when the user sets it.
Everything below follows from that.

### 1.1 The search chain — `getvar_chain()`, `variable.c:759-858`

```
1. variables            the global list   -- `set x=y`, `-D x=y`, spinit, .spiceinit
2. cp_usrvars()         5 computed names  -- plots curplot curplotname curplottitle curplotdate
3. plot_cur->pl_env     the current plot  -- SKIPPED for a policy read (see 1.2)
4. ft_curckt->ci_vars   the circuit       -- `.options x=y`
```

First hit wins, so **`set` shadows `.options`** for this whole class. Miss returns FALSE and,
for `CP_BOOL` with a non-NULL `retval`, writes FALSE.

### 1.2 Two entry points

`cp_getvar()` passes `inp_reading_netlist()` as the `policy` flag; `cp_getvar_policy()`
passes TRUE unconditionally. A policy read skips step 3, because a rawfile's `Option:` line
is parsed straight into `plot_cur->pl_env` (`rawfile.c`) and a file the user merely *loaded*
must not decide how *this* session behaves (`doc/codex/issues/0061`). One variable in the
tree is read this way: **`casemodewrite`** (`outitf.c:993`, `rawfile.c:204`).

### 1.3 The coercion table — this is where the bugs live

`getvar_chain()` does an exact type match first, then attempts exactly four coercions
(`variable.c:836-854`):

| stored → requested | CP_BOOL | CP_NUM | CP_REAL | CP_STRING | CP_LIST |
|---|---|---|---|---|---|
| **CP_BOOL** | ✔ | ✘ | ✘ | ✘ | ✘ |
| **CP_NUM**  | ✘ | ✔ | ✔ | ✔ `"%d"` | ✘ |
| **CP_REAL** | ✘ | ✔ `(int)` truncating | ✔ | ✔ `"%f"` | ✘ |
| **CP_STRING** | ✘ | ✘ | ✘ | ✔ | ✘ |
| **CP_LIST** | ✘ | ✘ | ✘ | ✘ | ✔ |

**`CP_BOOL` is isolated in both directions.** That single row is trap (1) and trap (2)
of §0. A failed coercion returns FALSE, i.e. "unset", with no message anywhere.

### 1.4 How a value acquires its type

`cp_setparse()` (`variable.c:387-555`) runs `ft_numparse()` on the right-hand side:
integer → `CP_NUM`, real → `CP_REAL`, anything else → `CP_STRING`. No `=` at all →
`CP_BOOL`. Double quotes force `CP_STRING`. MEASURED (`types.cir`):

| written | stored as | note |
|---|---|---|
| `set a=1` | CP_NUM `1` | |
| `set b=1.0` | CP_REAL `1` | |
| `set c=1e-3` | CP_REAL `0.001` | |
| `set d=1k` | CP_NUM `1000` | **engineering suffixes work** |
| `set k=1.5meg` | CP_REAL `1500000` | |
| `set e="1"` | CP_STRING `"1"` | **quoting a number makes it inert for NUM/REAL reads** |
| `set i=0x10` | CP_NUM `0` | **hex is silently zero** |
| `set g` | CP_BOOL TRUE | |

MEASURED against a real consumer (`warn`, a `CP_NUM` read):
`set warn=1.0` → SOA check fires; `set warn="1"` → nothing.

### 1.5 The four doors, and which ones each variable can use

| door | writes | reaches | fails for |
|---|---|---|---|
| `spinit` / `.spiceinit` `set x=y` | global list | everything, incl. netlist-read time | nothing |
| `ngspice -D x=y` / `-D x` | global list, **CP_STRING or CP_BOOL only** | everything, earliest of all | every `CP_NUM`/`CP_REAL` read |
| `.options x=y` in the deck | `ci_vars` | only reads taken at/after `inp.c:1376` | the 26 load-time variables of §3 |
| `set x=y` inside `.control` | global list | only reads taken at/after the analysis | the 26 load-time variables of §3 |

`-D` is worth stating precisely because it is the only door that needs no file on disk and
is therefore the one a GUI reaches for first. `main.c:984-999`:

```c
case 'D':       /* Definition of variable */
    if (optarg) {
        const char *eq = strchr(optarg, '=');
        if (eq == (char *) NULL) {           /* no assignment */
            bool true_val = TRUE;
            cp_vset(optarg, CP_BOOL, &true_val);
        } else {
            ... cp_vset(ds_get_buf(&ds), CP_STRING, eq + 1);   /* ALWAYS a string */
        }
    }
```

MEASURED, and this is a rule the GUI must encode:

| invocation | result |
|---|---|
| `-D sqrnoise` (CP_BOOL read) | **works** — `onoise_total = 1.489e-13` (squared) |
| `-D sqrnoise=1` | **inert** — `3.859e-07` (unsquared), same as no flag |
| `-D warn=1` (CP_NUM read) | **inert** — no SOA warnings |
| `-D warn` | **inert** — CP_BOOL cannot answer a CP_NUM read |
| `-D casemode=preserve` (CP_STRING read) | **works** — `$curcasemode = preserve`, node `In` keeps its case |
| `-D ngbehavior=hs` (CP_STRING read) | **works** — `Note: Compatibility modes selected: hs` |

**So `-D` can deliver exactly the CP_BOOL and CP_STRING variables and nothing else.**
For a `CP_NUM` or `CP_REAL` load-time variable the GUI must write a `.spiceinit` next to the
deck, or drive ngspice through `-p` pipe mode.

---

## 2. The master inventory — 163 variables, one row each

Columns: **name | type | read at (file:line, function) | phase | what it changes | default when absent |
in `OPTtbl`? | results (R) or presentation (P)?**

**The `OPTtbl?` column is "no" for all 163.** MEASURED by set intersection:
`comm -12 <(cp_getvar names) <(OPTtbl names)` is **empty**. `OPTtbl` (`cktsopt.c:275-390`)
has exactly **86** rows — 57 `IF_SET`, 27 `IF_ASK`, plus `itl3` and `itl5` which are neither
(§8.4). No name is in both catalogues, so a GUI never has to arbitrate which mechanism wins
for a given name. `cshunt` (OPTtbl) and `cshunt_value` (this table) are different names for
two halves of one feature; `temp` and `scale` look like a clash and are not (`temp` is
OPTtbl-only and merely *written* by `cp_vset` at `inp.c:1194`; `scale` is here-only). The
column is therefore omitted from the rows below and stated once, here.

Phase vocabulary, in execution order:

| phase | when | can `.options` answer? |
|---|---|---|
| **L1 netlist-read** | inside `inp_readall()`; `inp_reading_netlist()` is TRUE | **no** |
| **L2 deck-processing** | `inp_spsource()` before `inp_dodeck()` fills `ci_vars` | **no** |
| **L3 circuit-load** | `inp_dodeck()` at/after `inp.c:1376`, and the parser passes | **yes** |
| **S setup** | `CKTsetup()` / `DEVsetup()`, i.e. the first `run` | yes |
| **A analysis-setup** | once per analysis, at its start | yes |
| **I inner-loop** | per iteration / per timepoint | yes |
| **O output** | `OUTpBeginPlot`/`beginPlot`/rawfile write | yes |
| **C command** | only when the user issues that command | yes |

### 2.1 Group R — the 21 that change numerical results

| name | type | read at | phase | changes | default | R/P |
|---|---|---|---|---|---|---|
| `scale` | REAL | `inpgmod.c:265` `INPgetModBin`; `resparam.c:26`; `capparam.c:27`; `mos1/2/3par.c`; `b3*par.c`; `b4*par.c`; `b4soipar.c`; `hsm2par.c`; `hsmhv*par.c`; `vdmospar.c`; `diosetup.c:30`; `subckt.c:592` `doit`; `inp.c:2689` — **21 sites** | L2/L3/parse | multiplies every *geometric* device parameter (`W`, `L`, `AD`, `AS`, …) of R, C, DIO and every MOS family; also model binning. Does **not** scale a resistor's `resistance` (MEASURED: `.options scale=2` left `@r1[resistance] = 1k`) | `1` | **R** |
| `wnflag` | NUM | `inpgmod.c:268`; `inp.c:2828`; `inpcom.c:990` | L1/L3 | `nf = wnflag*wnf > 0.5 ? nf : 1; w = w/nf` — decides whether a MOS `W` is total or per-finger. Changes every multi-finger device and its model bin | `0`, or `1` under `ngbehavior=hs`/`spe` | **R** |
| `diode_cj0` | REAL | `diosetup.c:89` `DIOsetup` | S | overrides `DIOjunctionCap` on every diode model that did not give `cj0`. **Only under `newcompat.ps \|\| newcompat.lt`** — i.e. only with `ngbehavior=ps` or `lt`. The critique reported it unconditional; it is not | unset ⇒ `cj = 0` | **R** |
| `diode_rser` | REAL | `diosetup.c:241` and `:259` `DIOsetup` | S | overrides `DIOresist` (bulk) and `DIOresistSW` (sidewall) on every diode model that did not give `rs`. Same `ps`/`lt` gate | unset ⇒ `g = 0` | **R** |
| `ng_nomodcheck` | BOOL | `b3check.c:41`, `b3v32check.c:41`, `b4check.c:47`, `b4v5check.c:43`, `b4v6check.c:52`, `b4v7check.c:53` | S | skips the BSIM3/BSIM4 model-parameter sanity clamps. Silently lets out-of-range model cards through | off | **R** |
| `sqrnoise` | BOOL | `noisean.c:242` `NOISEan`; `noisesp.c:152` `NOISEsp` | A | `data->squared` — noise reported as V²/Hz instead of V/√Hz. MEASURED: `onoise_total` `1.83e-06` → `3.35e-12`, and the plot titles change | off | **R** |
| `notrnoise` | BOOL | `1-f-code.c:122` `trnoise_state_gen` | A (first eval per source) | zeroes `NA TS NALPHA NAMP RTSAM RTSCAPT RTSEMT` — kills every `trnoise` source in the deck | off | **R** |
| `noisyxspice` | BOOL | `mifload.c:464` `MIFload`; `evtload.c:253` `EVTload_with_event` | **I** | prints a code model's `errmsg` from inside the device-load loop. **The only per-iteration `cp_getvar` in the tree** — short-circuited by `errmsg && errmsg[0]`, so it costs nothing when models are quiet | off | P (but see §9.3) |
| `autostop` | BOOL | `dctran.c:200` `DCtran`; `inp.c:1143` `inp_spsource`; `measure.c:250` `do_measure` | L3 + A | ends the transient as soon as every `.meas` is satisfied — **changes `tstop`, so it changes the data you get**. Auto-disabled with a warning (and `cp_remvar`) if any `.meas` uses `max/min/avg/rms/integ` | off | **R** |
| `nostepsizelimit` | BOOL | `traninit.c:30` `TRANinit` | A | lifts `tmax = tstep`; `tmax` becomes `(tstop-tstart)/50` instead | off | **R** |
| `dyngmin` | BOOL | `cktop.c:60` `CKTop` | A | with `gminsteps=1`, runs *only* dynamic gmin stepping instead of dynamic-then-true. Changes which OP you converge to | off | **R** |
| `xtrtol` | NUM | `cktdojob.c:83` `CKTdoJob` | A | overrides the automatic `trtol → 1` reduction that XSPICE `A` devices force (`Reducing trtol to 1 for xspice 'A' devices`) | unset ⇒ the reduction happens | **R** |
| `topo_reduce` | BOOL | `cktsetup.c:72` `CKTtopologyReduce` | S | prunes dangling degree-1 R/C leaves before the matrix is bound; the console message names the element. Skipped when `rshunt` is on | off | **R** |
| `num_threads` | NUM | `cktsetup.c:316` `CKTsetup` | S | OpenMP thread count. Build-gated on `USE_OMP` (on here). **The shipped `spinit` sets `8`** | `2` in code, `8` from spinit | P (timing only) |
| `cshunt_value` | REAL | `inppas4.c:41` `INPpas4` | L3/parse | creates `capac<N>shunt` from every voltage node to ground. Written by `.options cshunt=<C>` (`inp.c:485`); a direct `set cshunt_value=…` reaches the same read | unset ⇒ `INPpas4` returns immediately | **R** |
| `enable_noisy_r` | BOOL | `inpcom.c:7417` `inp_compat` | **L1** | makes behavioural (B-source-expanded) resistors noisy; per-instance `noisy=` overrides | off | **R** |
| `soacheck` | BOOL | `inpcom.c:4543` `expand_section_references` | **L1** | injects `.param SWSOA=1` after every `.lib` (IHP Open-PDK hook). **Unrelated to `warn`** | off | **R** |
| `warn` | NUM | `inp.c:1447` `inp_dodeck` | **L3** | `ckt->CKTsoaCheck` — enables SOA checking in OP / DC sweep / TRAN (not AC, not NOISE). MEASURED: `.options warn=1` fires, `set warn=1` in `.control` does not (§3.2) | `0` | P (diagnostic; does not alter the solution) |
| `maxwarns` | NUM | `inp.c:1452` `inp_dodeck` | **L3** | `ckt->CKTsoaMaxWarns` — per-check cap on SOA messages | `5` | P |
| `auto_bridge` | NUM | `evtcheck_nodes.c:975` `Evtcheck_nodes` | S | verbosity/enable of automatic analog↔event bridging. `0` disables | `AB_SILENT` | **R** (topology) |
| `no_auto_bridge_family` | BOOL | `evtcheck_nodes.c:624` `find_bridge` | S | suppresses family-specific auto-bridges | off | **R** (topology) |

Plus the computed-name family read that belongs to the same feature:
`auto_bridge_<family>_<type>_<dir>` (`evtcheck_nodes.c:524`, `:569`, `:742`, `:761`,
built with `snprintf` into `buff`) — a user-defined bridge selector, `CP_LIST`/`CP_STRING`,
S phase, results-affecting, no default.

And the `.param` back-door, which is not a variable but *reads every variable*:

| mechanism | read at | phase | what it does |
|---|---|---|---|
| `var(<name>)` inside a `.param`/`{}` expression | `xpressn.c:1134` `formula`, `cp_getvar(vec_name, CP_REAL, …)` | **L1/L2** | pulls any front-end variable into the netlist as a real. The function table is `fmathS` (`xpressn.c:90-93`), where `vec` and `var` are the two string-argument entries |

**MEASURED and this is a first-class GUI capability nobody has named.** With
`set myres=4700` in `.spiceinit` and `.param rv = 'var(myres)'` + `r1 in 0 {rv}` in the deck,
`@r1[resistance] = 4.700000e+03`. The GUI can therefore inject arbitrary named scalars into
an unmodified netlist. Two cautions, both MEASURED: `var(nosuchvar)` returns **0 silently**
(here it produced `@r1[resistance] = 1.000000e-12`, the resistor minimum, with no message);
and the read is L1/L2, so `.control set myres=4700` and `.options myres=4700` **both fail
silently**. Only `spinit` / `.spiceinit` / `-D` (string form only, and `var()` wants a REAL,
so `-D` cannot deliver it) / `-p` pipe mode work.

### 2.2 Group G — the 11 that decide whether a run happens or produces output

| name | type | read at | phase | what it does | default | R/P |
|---|---|---|---|---|---|---|
| `noparse` | BOOL | `inp.c:1372` `inp_dodeck` | **L2** (one line *before* `ci_vars` is built — §3.1) | read the deck, build no circuit. Nothing can run | off | G |
| `nosubckt` | BOOL | `inp.c:936` `inp_spsource`; `nutinp.c:161` | **L2** | do not expand `.subckt`. MEASURED: with it set the deck dies `Error: incomplete or empty netlist` | off | G |
| `no_mem_check` | BOOL | `outitf.c:143` `OUTpBeginPlot` | O | disables the pre-flight "required memory > available memory" refusal for a transient plot | off (check on) | G |
| `interp` | BOOL | `outitf.c:211` `beginPlot`; `breakp.c:49` `com_stop` | O | write only interpolated data on a uniform grid; prints `Warning: Interpolated raw file data!`. **This is F12's uniform-output-grid switch** | off | **R** (resamples the data) |
| `filetype` | STRING | `postcoms.c:596` `com_write`; `runcoms.c:240` `dosim`; `runcoms2.c:103` `com_resume`; `ciderlib/support/misc.c:171` | O/C | `ascii` vs `binary` rawfile. Anything else warns `Warning: strange file type %s` and keeps binary | binary | P |
| `appendwrite` | BOOL | `postcoms.c:604` `com_write`; `gnuplot.c:702` `ft_writesimple` | C | append instead of truncate. **This is the F6 multi-plot recipe's enabler** | off | G |
| `plainwrite` | BOOL | `postcoms.c:606` `com_write` | C | skip expression parsing in `write` — **and therefore skip `checkvalid()`**, which is the escape hatch from the zero-length-vector abort of §4 | off | G |
| `noquotesinoutput` | BOOL | `parse.c:129` `ft_getpnames_quotes_probe` | C | disables the auto-quoting that makes `v(2p)` and `v(a-b)` resolvable in `print`/`plot`/`write` argument lists | off (quoting on) | G |
| `keep#branch` | BOOL | `rawfile.c:58` `raw_write`; `outitf.c:1091` `fileInit_pass2` | O | keep the `#branch` suffix in rawfile variable names instead of rewriting to `i(v1)` | off | P (but changes the names the GUI must match) |
| `nopadding` | BOOL | `rawfile.c:57` `raw_write` | O | drop the fixed-width padding in the ASCII rawfile header | off (padding on) | P |
| `casemodewrite` | BOOL | `outitf.c:993` `fileInit`; `rawfile.c:204` `raw_write` | O | write the `Option: casemode=` line into the raw header. **Read via `cp_getvar_policy()`** — the only such read in the tree | off | P |

### 2.3 Group N — netlist rewriting and parse policy (all L1/L2/L3)

| name | type | read at | phase | what it does | default |
|---|---|---|---|---|---|
| `casemode` | STRING | `inpcom.c:1238` `set_case_mode` | **L1** | `fold` / `preserve` / `distinguish`. Read back with `$curcasemode` (§5) | `fold` |
| `ngbehavior` | STRING | `inpcompat.c:76` `set_compat_mode` | **L1** | compatibility dialect, substring-matched | unset ⇒ `Note: No compatibility mode selected!` |
| `no_auto_gnd` | BOOL | `inpcom.c:1541` `inp_readall_cards`; `inpcom.c:2330` `inp_read` | **L1** | do not rewrite `gnd`-like node names to `0` | off |
| `no_auto_braces` | BOOL | `inpcom.c:9082` `inp_quote_params` | **L1** | do not add `{}` around parameter expressions | off |
| `addcontrol` | BOOL | `inpcom.c:1547` `inp_readall_cards` | **L1** | append a generated `.control` block. Set by `main.c:1031/1040` for `-a`/`-b` | off |
| `rawfile` | STRING | `inpcom.c:3311` `inp_add_control_section` | **L1** | the filename that generated block writes to. Also written by `-r` (`main.c:1086`) and by `cp_usrset` (`options.c:349` → `ft_rawfile`) | unset |
| `sourcepath` | LIST | `inpcom.c:2486` `inp_pathresolve`; `inpcom.c:10532` `add_to_sourcepath`; `sharedspice.c:1097` | **L1** | `.include` search path | `( . <pkgdatadir>/scripts )` |
| `mingwpath` | BOOL | `inpcom.c:2445` `inp_pathresolve`; `osdiregistry.c:70` `resolve_path` | **L1** | translate `/c/...` MSYS paths | off |
| `substart` `subend` `subinvoke` `modelcard` `modelline` | STRING ×5 | `subckt.c:241-249` `inp_subcktexpand` | **L2** | the five keywords the subcircuit expander recognises | `.subckt` `.ends` `x` `.model` `.model` |
| `statlocal` | BOOL | `inp.c:945` `inp_spsource` | **L2** | scope of statistical/Monte-Carlo parameters | off |
| `renumber` | BOOL | `inp.c:252` `inp_list` | L2/C | renumber lines after `.include` expansion | off |
| `debug-out-short` | BOOL | `inp.c:1000`, `inp.c:1218`, `inpcom.c:1640` | L1/L2 | shorten the `ngdebug` deck dumps | off |
| `brief` | BOOL | `inp.c:1533` `inp_dodeck` | **L3** | suppress the `Processed Netlist` echo. **Set automatically in batch** (`cpitf.c:177`) | off interactively, on in `-b` |
| `controlswait` | BOOL | `inp.c:1280` `inp_spsource` | **L2** | defer `.control` execution (shared build) | off |
| `probe_is_given` | BOOL | `inp.c:1433` `inp_dodeck` | **L3** | set by the `.probe` preprocessor (`inpc_probe.c:99`), consumed here | off |
| `probe_alli_given` | BOOL | `evtcheck_nodes.c:980` | S | ditto, set at `inpcom.c:9615` | off |
| `probe_alli_nox` | BOOL | `inpc_probe.c:262` `inp_probe` | **L1** | `.probe alli` skips `x`-prefixed instances | off |
| `no_spinit` | BOOL | `cpitf.c:264` `ft_cpinit` | pre-L1 | skip `spinit` entirely | off |
| `no_spiceinit` | BOOL | `sharedspice.c:989` `ngSpice_Init` | pre-L1 | skip `.spiceinit` (shared build; the binary uses a command-line flag) | off |
| `interactive` | BOOL | `main.c:1510`; `control.c:237` `docommand`; `inp.c:1660/1933/1951/1976`; `com_hardcopy.c:185`; `spicenum.c:367` `nupa_done` | many | suppresses "abort on error" and changes `source`/`edit` behaviour. **Set by `main.c:1195`** when stdin is a tty | set iff interactive |
| `editor` | STRING | `inp.c:1886` `doedit` | C | `$EDITOR` override for the `edit` command | env / built-in |
| `ps_global_tmodels` `ps_global_hash_table` `ps_tpz_delays` `ps_use_mntymx` `ps_ports_and_pins` `ps_udevice_msgs` `ps_udevice_exit` `ps_scan_gates_optimize` `ps_with_inverters` `ps_with_tri_inverters` | NUM ×10 | `udevices.c:941-1017` `initialize_udevice`; `inpcompat.c:474` `u_instances` | **L1** | the PSpice `U`-device (digital primitive) translator's ten knobs — timing model choice, min/typ/max selection, port naming, inverter synthesis. All results-affecting **for a PSpice digital deck** and dead for every other deck | all `0` |

### 2.4 Group X — post-processing, measurement and control-language

| name | type | read at | phase | what it does | default |
|---|---|---|---|---|---|
| `measoutfile` | STRING | `measure.c:257` `do_measure` | C | redirect `.meas` text output to a file | unset ⇒ stdout |
| `nfreqs` | NUM | `fourier.c:69` `fourier` | C | harmonics computed by `.four`/`fourier` | `10` |
| `nperiods` | NUM | `fourier.c:71` | C | periods used | `1` |
| `fourgridsize` | NUM | `fourier.c:75` | C | interpolation grid for the Fourier resample | `200` (`FT_GRIDSIZE`) |
| `fournosave` | BOOL | `fourier.c:77` | C | do not create the `fourierMN`/`thdMN` vectors (F14 item 16 depends on these existing) | off |
| `polydegree` | NUM | `cmath4.c:226` `cx_interpolate`; `fourier.c:73`; `plotcurv.c:43` `ft_graf` | C | interpolation degree for `interpolate()`, the Fourier resample, and curve plotting | `1` |
| `dpolydegree` | NUM | `cmath4.c:263` `cx_deriv` | C | polynomial degree for `deriv()` | `2` |
| `mtimeavgwindow` | REAL | `cmath4.c:1054` `cx_mtimeavg` | C | window for `mtimeavg()`; falls back to `1e-6` with a `Note:` if no circuit | derived from the circuit |
| `specwindow` | STRING | `cmath4.c:676` `cx_fft`; `com_fft.c:95` `com_fft`; `com_fft.c:332` `com_psd`; `spec.c:91` `com_spec` | C | FFT/PSD/spec window: `none rectangular bartlet hanning hamming blackman gaussian flattop` | `none` (`hanning` for `spec`) |
| `specwindoworder` | NUM | same four files | C | Gaussian window order, floored at 2 | `2` |
| `spectrace` | BOOL | `spec.c:236` `com_spec` | C | per-bin trace during `spec` | off |
| `diff_abstol` `diff_reltol` `diff_vntol` | REAL ×3 | `diff.c:164-168` `com_diff` | C | tolerances for the `diff` run-to-run comparison (F14 item 12) | `1e-12` / `1e-3` / `1e-6` |
| `sanelet` | BOOL | `com_let.c:142` `com_let` | C | reject `let` names that collide with a plot-qualified name |off |
| `plainlet` | BOOL | `com_let.c:178` `com_let` | C | `let` without expression parsing | off |
| `csnumprec` | NUM | `variable.c:52` `cp_varwl` | C | digits used when a variable is expanded into a word list (`$var`) | `6`-ish; only honoured when `> 0` |
| `nosort` | BOOL | `com_display.c:70` `com_display` | C | leave `display` output in creation order | off (sorted) |
| `altshow` | BOOL | `device.c:366` `com_showmod`; `device.c:376` `com_show` | C | alternate `show`/`showmod` layout | off |
| `level` | STRING | `com_ahelp.c:41` `com_ahelp` | C | help verbosity for `ahelp` | unset |
| `askquit` | BOOL | `misccoms.c:59` `com_quit` | C | confirm before quitting | off |
| `histsubst` | BOOL | `init.c:33` `cp_init` | startup | enable `!!`-style history substitution | off |
| `moremode` | BOOL | `terminal.c:77` `out_init` | O | pager the terminal output | off |
| `silent_fileio` | BOOL | `com_fileio.c:33` `verbose` | C | silence `fopen`/`fread`/`fclose`. **`vlnggen` depends on these commands** (CLAUDE.md) | off |
| `rndseed` | NUM | `randnumb.c:82` `checkseed`; `randnumb.c:298` `com_sseed`; `main.c:1363`; `sharedspice.c:1072` | startup/C | RNG seed. **Set to `1` at startup** (`main.c:937`), so Monte-Carlo runs are deterministic by default; `setseed [n]` re-seeds; `setseed` with no argument uses `getpid()` | `1` |
| `sim_status` | NUM | `main.c:1559` `main` | post-run | **written** by `runcoms.c:329/352/358` and read here to become the process exit status. This is the variable F13's `sim_status` guard is about | `0` |
| `nosighandling` | BOOL | `sharedspice.c:913`, `:1051` `ngSpice_Init` | startup | shared build only: do not install SIGSEGV/SIGILL/SIGABRT handlers | off |
| `addescape` | BOOL | `sharedspice.c:1558` `sh_vfprintf` | O | escape special characters in the shared build's output callback | off |
| `spicepath` | STRING | `aspice.c:82` `com_aspice` | C | binary used by `aspice` | `Spice_Path` |
| `rhost` `rprogram` `remote_shell` | STRING ×3 | `aspice.c:285-289` `com_rspice` | C | remote-spice host / program / rsh | `Spice_Host` / built-ins |

### 2.5 Group D — display, plotting and hardcopy (pure presentation, 62 variables)

Listed compactly; none of these can change a number. All phase C or "device init".

* **Terminal / ASCII output** — `width` (`device.c:404`, `device.c:566`, `com_ghelp.c:87`, `agraf.c:70`, `postcoms.c:206`, `postcoms.c:282`, `terminal.c:103`), `height` (`agraf.c:73`, `postcoms.c:290`, `terminal.c:105`), `nobreak` (`agraf.c:79`, `postcoms.c:294`), `noprintscale` (`postcoms.c:299`), `noasciiplotvalue` (`agraf.c:61`), `printinfo` (`outitf.c:207`, `outitf.c:1744` `OUTerror`, `outitf.c:1777` `OUTerrorf` — gates `ERR_INFO` messages).
* **X11** — `display` (`x11.c:160`, `display.c:182` `DevInit`, `com_ghelp.c:89`, `nghelp.c:62`), `device` (`com_ghelp.c:91`, `graf.c:697` `gr_pmsg`), `xfont` (`x11.c:525`), `xfont_size` (`x11.c:552`), `xbrushwidth` (`x11.c:591`, and NUM/REAL elsewhere), `xgridwidth` (`x11.c:601`), `plothistory` (`x11.c:1114` `zoomin`), `x11lineararcs` (`x11.c:707` — **dead, see §8.1**), plus computed `color0…colorN` (`x11.c:266`).
* **Windows GDI** — `wfont` ×4, `wfont_size` ×4 (`windisp.c:207-1116`), `xbrushwidth`/`xgridwidth` (`windisp.c:841/851`), computed `color0…colorN` (`wincolor.c:37/114/169`, `windisp.c:325`).
* **Graph frame** — `pointchars` (`graf.c:112`), `ticmarks` (`graf.c:117` NUM **then** `:118` BOOL — the *correct* two-read pattern, §7.4), `ticchar` (`graf.c:126`), `ticlist` LIST (`graf.c:130`), `nolegend` (`graf.c:139`, `gnuplot.c:347`), `nounits` (`graf.c:140`), `event_node_spacing` REAL (`graf.c:1344` `gr_iplot`), `gridstyle` (`plotit.c:565`), `plotstyle` (`plotit.c:662`), `plainplot` (`plotit.c:730`), `plot_auto_spacing` REAL (`plotit.c:901`), `gridsize` (`plotcurv.c:57`), `polysteps` (`plotcurv.c:342` `plotinterval` — reachable; `options.md`'s "read by nothing" is wrong, MEASURED-by-reading that `plotinterval` is called from `ft_graf` at `plotcurv.c:267/269/307/310`).
* **gnuplot / pyplot** — `gnuplot_terminal` (`gnuplot.c:303`), `pointstyle` (`gnuplot.c:338`, `pyplot.c:144`), `wr_singlescale` `wr_vecnames` `wr_onespace` (`gnuplot.c:703-705` `ft_writesimple` — these three also shape `wrdata` output), `pyplot_terminal` `pyplot_figsize` `pyplot_python` `pyplot_backend` `pyplot_subplots` `pyplot_style` `pyplot_linewidth` (`pyplot.c:90-140`).
* **Hardcopy** — `hcopydev` `hcopydevtype` (`com_hardcopy.c:40/43`), `lprplot5` `lprps` (`com_hardcopy.c:214/231`), `hcopyscale` (`postsc.c:122`, `hpgl.c:90`), `hcopypscolor` `hcopypstxcolor` (`postsc.c:136/145`), `hcopywidth` `hcopyheight` `hcopyfont` `hcopyfontsize` (`postsc.c:163-210` as STRING, `svg.c:157-192` as NUM — see §7.4), `hcopyfontfamily` (`svg.c:183`), `svg_intopts` `svg_stropts` LIST (`svg.c:138/146`), computed `color0…colorN` (`postsc.c:516`, `svg.c:199`).
* **Help browser** — `helppath` `helpregfont` `helpboldfont` `helpitalicfont` `helptitlefont` `helpbuttonfont` `helpbuttonstyle` `helpinitxpos` `helpinitypos` (`com_ghelp.c:46-76`).

---

## 3. Question 1 — which are read at CIRCUIT-LOAD time, and the ordering rule

### 3.1 The exact boundary, and it is one line

`inp_dodeck()` builds `ft_curckt->ci_vars` from the deck's `.options` cards at
**`src/frontend/inp.c:1376-1397`**. Every `cp_getvar()` taken *before* that point cannot see
a `.options` line in the same deck; every read at or after it can.

```c
/* src/frontend/inp.c:1372 */
    noparse = cp_getvar("noparse", CP_BOOL, NULL, 0);      /* <-- LAST read .options cannot answer */

    /* Read the options, create variables and store them in ftcurckt->ci_vars */
    if (!noparse) {                                        /* :1376 */
        ...
                ct->ci_vars = eev = cp_setparse(wl);       /* :1394 */
```
```c
/* src/frontend/inp.c:1447 — the FIRST read .options can answer */
        if (cp_getvar("warn", CP_NUM, &warn, 0))
            ckt->CKTsoaCheck = warn;
```

MEASURED, both sides of the line:

| deck | outcome |
|---|---|
| `.options warn=1` in the deck | `Instance: r1 Model: R \|Vr\|=10 has exceeded Bv_max=1` |
| `set warn=1` inside `.control`, then `op` | **nothing** |
| `set warn=1` in `.spiceinit` | fires |
| `.options nosubckt` (read at `inp.c:936`, phase L2) | **silently ignored** — `x1.mid` still exists |
| `set nosubckt` in `.spiceinit` | `Error: incomplete or empty netlist` — it took effect |
| `.options casemode=preserve` + `.options ngbehavior=hs` | **both silently ignored** — `$curcasemode = fold`, `Note: No compatibility mode selected!` |
| `-D casemode=preserve` | `$curcasemode = preserve`, node `In` keeps its case |

### 3.2 The complete list of variables that MUST be emitted before the deck is read

**26 variables**, in three phases. The critique named one (`warn`, for `--soa-log`) and
guessed there were others; here they all are. `warn` and `maxwarns` are *not* in this list —
they are the first two reads on the safe side of the boundary and `.options` reaches them.

**L1 — inside `inp_readall()` (a policy read; the current plot's env is skipped):**

| variable | type | reachable by | not reachable by |
|---|---|---|---|
| `casemode` | STRING | spinit, .spiceinit, `-D` | `.options`, `.control` |
| `ngbehavior` | STRING | spinit, .spiceinit, `-D` | `.options`, `.control` |
| `sourcepath` | LIST | spinit, .spiceinit | `-D` (lists), `.options`, `.control` |
| `mingwpath` | BOOL | spinit, .spiceinit, `-D` | `.options`, `.control` |
| `no_auto_gnd` | BOOL | spinit, .spiceinit, `-D` | `.options`, `.control` |
| `no_auto_braces` | BOOL | spinit, .spiceinit, `-D` | `.options`, `.control` |
| `addcontrol` | BOOL | spinit, .spiceinit, `-D` | `.options`, `.control` |
| `rawfile` | STRING | spinit, .spiceinit, `-D`, **`-r`** | `.options`, `.control` |
| `soacheck` | BOOL | spinit, .spiceinit, `-D` | `.options`, `.control` |
| `enable_noisy_r` | BOOL | spinit, .spiceinit, `-D` | `.options`, `.control` |
| `probe_alli_nox` | BOOL | spinit, .spiceinit, `-D` | `.options`, `.control` |
| `wnflag` | **NUM** | spinit, .spiceinit **only** | **`-D`**, `.options`, `.control` |
| `debug-out-short` | BOOL | spinit, .spiceinit, `-D` | `.options`, `.control` |
| `ps_global_tmodels` `ps_global_hash_table` `ps_tpz_delays` `ps_use_mntymx` `ps_ports_and_pins` `ps_udevice_msgs` `ps_udevice_exit` `ps_scan_gates_optimize` `ps_with_inverters` `ps_with_tri_inverters` | **NUM** ×10 | spinit, .spiceinit **only** | **`-D`**, `.options`, `.control` |
| *any name used as* `var(<name>)` | **REAL** | spinit, .spiceinit **only** | **`-D`**, `.options`, `.control` |

**L2 — `inp_spsource()`, before `ci_vars` exists:**

| variable | type | note |
|---|---|---|
| `nosubckt` | BOOL | MEASURED above |
| `statlocal` | BOOL | |
| `controlswait` | BOOL | |
| `substart` `subend` `subinvoke` `modelcard` `modelline` | STRING ×5 | |
| `noparse` | BOOL | `inp.c:1372`, one line before the boundary |
| `scale` (the `subckt.c:592` and `inp.c:2689` sites) | REAL | **but** the device-`param` sites are parse-phase and `.options scale=` does reach those; `inp.c:879-928` also hoists `.options scale` into the global list early in `hs`/`spe` mode. Net effect: **use `set scale=` if you want it to be uniform** |

**Pre-L1 (before even `spinit` is sourced):** `no_spinit` (binary; the practical route is the
command-line `--no-spiceinit`), `no_spiceinit` (shared build only).

### 3.3 The rule for the ASE-L plan

> **Ordering rule.** Any option in §3.2 is a *pre-deck* option. The GUI must deliver it
> either (a) as `-D name` / `-D name=string` on the command line, when the variable is
> `CP_BOOL` or `CP_STRING`, or (b) by writing a `.spiceinit` in the run directory, when it is
> `CP_NUM`, `CP_REAL` or `CP_LIST`, or (c) as a `set` line before `source` in `-p` pipe mode.
> Emitting it as `.options` or inside `.control` produces **no message and no effect**.

`--soa-log=FILE` (`main.c:1101-1164`) is the case the critique named. Note it is *paired*
with `warn`, which is on the **other** side of the boundary: the log file is a command-line
flag, but `set warn=1` that populates it is an `inp_dodeck` read, so `.options warn=1` in the
deck is the correct and simplest emission for the value. The GUI needs both, from two
different doors, for one feature.

---

## 4. Question 2 — `nosavecurrents`, and what `savecurrents` + AC actually does

### 4.1 `nosavecurrents` does not exist. Confirmed.

```
$ grep -rIn "nosavecurrents" /home/analog/dev/ngspice        →  0 lines
$ git grep -In "savecurrents"                                →  savecurrents, savecurrents_bsim3/4/mos1 only
$ grep -rIn "nosavecurrents" build-ver_50                    →  0 lines
```

Nothing — not in `*.c`, `*.h`, `*.in`, `*.txt`, `NEWS`, `examples/`, `tests/`, the generated
`spinit`, or `src/ngspice.txt` (the built-in `help` database). The manual's §13.7 workaround
is not implemented in this tree. Emitting `set nosavecurrents` produces a variable nothing
reads, and no message.

### 4.2 What actually happens — two different failures, one option

`.options savecurrents` is a **mechanism-E preprocessing** option: `inp_savecurrents()`
(`inp.c:2417-2506`) appends one `.save @<dev>[…]` card per device — `[id is ig ib]` for `m`,
`[id is ig igd]` for `j`, `[ic ie ib is]` for `q`, `[id]` for `d`, `[i]` for
`r c l b f g w s`, `[current]` for `i` — plus `.save all` if the deck had no other save.

Deck used for everything below (`sc_ac.cir`): `v1` + `r1` + `c1` + `m1`, `.options savecurrents`,
`ac dec 2 1k 10k`.

**Route A — `.control` + `write` (ASE-L's shape).** MEASURED:

```
Warning from checkvalid: vector @c1[i] is not available or has zero length.
Error during 'write': no writable vector found.
```

and **no rawfile is created at all.** `display` shows why:

```
@c1[i]   : current, complex, 0 long        <- zero length
@m1[ib]  : current, complex, 0 long
@m1[id]  : current, complex, 3 long        <- the only survivor, and it is all zeros
@m1[ig]  : current, complex, 0 long
@m1[is]  : current, complex, 0 long
@r1[i]   : current, complex, 0 long
frequency, in, mid, v1#branch              : 3 long, correct
```

SOURCE, the mechanism, and it is worse than "savecurrents is broken": `com_write`
(`postcoms.c:611-618`) calls `ft_getpnames_quotes(&all, TRUE)`, whose `check` argument runs
`checkvalid()` (`parse.c:278-307`). `checkvalid()` returns FALSE on **the first**
zero-length vector in the entire expanded list, `ft_getpnames_quotes` then returns NULL, and
`com_write` bails:

```c
        if (names == NULL) {
            fprintf(stderr, "Error during 'write': no writable vector found.\n");
            return;
        }
```

**So a single zero-length vector anywhere in a plot destroys the whole `write` for that
plot.** `print all` fails the same way. This is a general hazard, not a `savecurrents` one —
`savecurrents` is just the easiest way to create one.

**Route B — `ngspice -b -r out.raw` (no `.control`).** MEASURED: the run succeeds, rc 0, and
the rawfile is written with **all ten columns and three points**:

```
	0	frequency	frequency	grid=3
	1	v(in)	voltage
	2	v(mid)	voltage
	3	i(v1)	current
	4	i(@r1[i])	current
	5	i(@c1[i])	current
	6	i(@m1[id])	current       ... etc
```

Loaded back and printed:

```
Index   i(@r1[i])                       i(@c1[i])
0	0.000000e+00,	0.000000e+00	0.000000e+00,	0.000000e+00
1	0.000000e+00,	0.000000e+00	0.000000e+00,	0.000000e+00
2	0.000000e+00,	0.000000e+00	0.000000e+00,	0.000000e+00
```

**Every device-current column is identically zero at every frequency, with no warning.** A
GUI that plots this shows a flat trace at 0 A and the user believes it. That is the worse of
the two failures.

### 4.3 The remedy that DOES exist: `remzerovec`

MEASURED, same deck, `.control` route:

```
ac dec 2 1k 10k
write sc_ac_raw.raw all      -> Error: no writable vector found.  (no file)
remzerovec
write sc_ac_rz.raw all       -> ASCII raw file "sc_ac_rz.raw"     (5 vars, 3 points)
```

After `remzerovec` the plot holds `@m1[id] frequency in mid v1#branch` and the write
succeeds. This is the in-tree idiom — `examples/mos/ro-meas.cir:53` says so in a comment
(`*use remzerovec if option savecurrents is given`) — and it is exactly the rule F13 already
imposes ("a `sim_status` guard AND a `remzerovec` must follow EVERY analysis"). **This
dossier is the empirical reason that rule exists.** `set plainwrite` is the second escape
hatch (it bypasses `checkvalid` entirely, `postcoms.c:606`), but it also disables expression
parsing in `write`, so prefer `remzerovec`.

### 4.4 Which analyses are affected — AC and only AC

MEASURED, the identical deck with `write /dev/null all` after each analysis, counting
`no writable vector found`:

| analysis | write aborts? |
|---|---|
| `op` | no |
| `tran 1u 10u` | no |
| **`ac dec 2 1k 10k`** | **yes** |
| `noise v(mid) v1 dec 2 1k 10k` | no |
| `tf v(mid) v1` | no |
| `pz in 0 mid 0 vol pz` | no |

And under NOISE the `@dev[i]` vectors are not merely present, they are **populated with the
small-signal currents from the noise analysis's own AC solve** — MEASURED,
`@r1[i]` = `3.947686e-08 / 3.946284e-07 / 3.932318e-06` at 1 k / 3.16 k / 10 k, which is
exactly the `i(v1)` magnitude the AC run computed. So the data a user wants **does** exist
under NOISE and is missing only under AC. That asymmetry is worth surfacing rather than
hiding.

### 4.5 The rule for the ASE-L plan

> 1. Never emit `.options savecurrents` together with an enabled AC analysis. Offer per-device
>    `save @dev[…]` from the Outputs pane instead, or use `.probe` (F14 item 13), which works
>    in every analysis.
> 2. Emit `remzerovec` after **every** analysis, unconditionally — not because of
>    `savecurrents` alone, but because one zero-length vector from any source aborts the whole
>    `write`, silently, and takes the entire plot with it.
> 3. If the GUI ever uses the `-r` route, it must reject `savecurrents` + AC outright: `-r`
>    turns the loud failure into silent zeros.
> 4. Do not offer a `nosavecurrents` checkbox. It does nothing here.

---

## 5. Question 3 — the read-only introspection API

Three separate populations. Only the first is answerable by `cp_getvar()`; the difference
matters because a GUI probe written as `if $?x` / `echo $x` sees a larger set than the C code
does.

### 5.1 Enforced read-only — `cp_usrset()` refuses the write

`cp_usrset()` (`options.c:465-472`) returns `US_READONLY` for exactly two names:

| name | shape | answered by | notes |
|---|---|---|---|
| `plots` | list of plot **typenames** (`const op1 ac1`) | `cp_enqvar` **and** `cp_usrvars` ⇒ visible to `cp_getvar`, `$plots`, and `set` | **the F6 multi-plot loop's iterator.** MEASURED: `set` shows `* plots ( const op1 ac1 )`, `echo $plots` prints `const op1 ac1` |
| `curcasemode` | `fold` / `preserve` / `distinguish` | `cp_enqvar` **only** — *not* in `cp_usrvars`, so **`cp_getvar("curcasemode",…)` cannot see it and `set` does not list it**. Only `$curcasemode` works | computed fresh on every read from `inp_case_mode_name()`; `casemode` is what you *asked for*, this is what is *in force* |

### 5.2 Computed-on-read, writable but `US_DONTRECORD`

`cp_enqvar()` (`options.c:52-140`) computes these before consulting the current plot's
environment; `cp_usrset()` accepts a write (it retargets the plot) but does not store the
variable:

| name | value | writing it does |
|---|---|---|
| `curplot` | `plot_cur->pl_typename` (e.g. `ac1`) | `plot_setcur()` — **this is `setplot` by another name** |
| `curplotname` | `plot_cur->pl_name` — **the literal `Plotname:` string** (`AC Analysis`, `DISTORTION - 2nd harmonic`, …) | renames the plot |
| `curplottitle` | `plot_cur->pl_title` (the deck's title line) | retitles |
| `curplotdate` | `plot_cur->pl_date` | redates |

`curplot`, `curplotname`, `curplottitle`, `curplotdate` and `plots` are the five names in
`cp_usrvars()` (`options.c:/^cp_usrvars/`), which is why they are the five that `cp_getvar()`
and `set` can both see. **`setplot $p` + `$curplotname` is F6's plot→analysis map**, and this
is the source-level reason it works.

### 5.3 Set by ngspice itself at startup or during the run — read-only in practice

Written by `cp_vset()` somewhere in the tree; the user *can* overwrite them but nothing good
happens. Complete list, from `grep -rn 'cp_vset *( *"' src`:

| name | written at | value on this build (MEASURED) | use as a probe |
|---|---|---|---|
| `xspice_enabled` | `main.c:943`, `sharedspice.c:944` | `TRUE` | **reliable** XSPICE probe |
| `osdi_enabled` | `main.c:946`, `sharedspice.c:947` | **empty** | **UNRELIABLE — see §5.4** |
| `program` | `cpitf.c:154` | `ngspice` | |
| `oscompiled` | `init.c:75` | `6` | build-OS id; `vlnggen` branches on it |
| `batchmode` | `main.c:1032` | `TRUE` under `-b` | tells you `-b` is in force, i.e. §F9's no-signal-handler mode |
| `interactive` | `main.c:1195` | unset under `-b` | |
| `sharedmode` | `sharedspice.c:939` | unset (binary) | libngspice probe |
| `win_console`, `pg_config`, `term` | `cpitf.c:241/226-234`, `main.c:1097` | unset here | |
| `sim_status` | `runcoms.c:329/352/358` | `0` after a clean run | **the run's error code**; `main.c:1559` turns it into the exit status. F13's guard |
| `shellstatus` | `com_shell.c:80` | set after `shell` | exit status of the last `shell` command |
| `plots` | (computed) | `const op1 ac1` | §5.1 |
| `rndseed` | `main.c:937`, `inp.c:455/465`, `randnumb.c:300/317` | `1` | |
| `history` | `init.c:26` | `10000` | |
| `prompt` | `cpitf.c:176` | `ngspice ! -> ` | |
| `brief` | `cpitf.c:177` | set in `-b` | |
| `inputdir` | `inp.c:591` | `.` | directory of the deck |
| `sourcepath` | (spinit/default) | `( . <pkgdatadir>/scripts )` | |
| `temp` | `inp.c:1194` | unset unless the deck sets it | mirrors `.options temp` |
| `scale`, `scalm` | `inp.c:885/897/912/924` | unset | hoisted from `.options` in `hs`/`spe` mode |
| `cshunt_value` | `inp.c:485` | unset | hoisted from `.options cshunt` |
| `probe_is_given`, `probe_alli_given` | `inpc_probe.c:99`, `inpcom.c:9615` | unset | set by the `.probe` preprocessor |
| `addcontrol` | `main.c:1031/1040` | set under `-a`/`-b` | |
| `rawfile` | `main.c:1086` | set by `-r` | |
| `hcopydevtype`, `hcopypscolor` | `x11.c:1132/1134/1169`, `windisp.c:278-312` | | set by the hardcopy dialog |
| `no_spinit`, `no_spiceinit` | `sharedspice.c:809/819` | | shared build |

### 5.4 The `$osdi_enabled` false negative — a new finding

`main.c:946` sets `osdi_enabled` whenever `OSDI` is defined, and
`build-ver_50/src/include/ngspice/config.h:502` has `#define OSDI 1`. But **the shipped
`spinit` unsets it**:

```
/home/analog/dev/ngspice/src/spinit.in:
* comment out if central osdi management is set up
unset osdi_enabled
```

MEASURED: `echo $osdi_enabled` prints nothing, `set` does not list it, and the `if
$?osdi_enabled` block that would load the nine `.osdi` models never runs. So **`$osdi_enabled`
is a probe for "spinit chose to load OSDI models", not for "this binary has OSDI"**. The
critique's §5.1 statement that "`$xspice_enabled` / `$osdi_enabled` are the only two variables
set at startup" is true of `main.c` and false of the running session. A GUI that reports
"OSDI: not available" from this variable is wrong on a default build. Use the `osdi` command's
own response, or `devhelp`, as the real probe.

### 5.5 The other `$`-only surface

`$?name` (is it set), `$#name` (list length), `$&vec` (a vector as a variable, via
`cp_enqvec_as_var`, `options.c:158-207` — one element becomes a `CP_REAL`, more become a
list; **this is how `echo "$&n"` reads a `length()` back into text**), `$<` (read a line),
`$argc`/`$argv` (script arguments). None of these are `cp_getvar` variables and none can be
`set`.

---

## 6. Question 4 — the boolean/real trap, exhaustively

### 6.1 The headline, MEASURED

```
tran 1u 20u on an RC with a 1 ns pulse edge at 3.3 us
  (no interp)     length(time) = 109
  set interp      length(time) =  21   + "Warning: Interpolated raw file data!"
  set interp=1    length(time) = 109   <- SILENTLY OFF
```

and the same shape on the analysis side:

```
noise v(mid) v1 dec 2 1k 10k, reading onoise_total
  (default)          3.858661e-07
  set sqrnoise       1.488926e-13   <- squared, ON
  set sqrnoise=1     3.858661e-07   <- SILENTLY OFF
  set sqrnoise=0     3.858661e-07   <- off (coincidentally right)
  set sqrnoise=true  3.858661e-07   <- SILENTLY OFF (CP_STRING)
```

and the converse:

```
.op on a resistor with bv_max=1 at 10 V, counting SOA warnings
  set warn      (in .spiceinit)   0 warnings   <- CP_BOOL cannot answer a CP_NUM read
  set warn=1                      1 warning
  set warn=1.0                    1 warning    (REAL -> NUM coercion)
  set warn="1"                    0 warnings   <- quoted, CP_STRING, SILENTLY OFF
  set warn=0                      0 warnings
```

### 6.2 The complete lists

**Write these with a bare `set x` and NEVER `=anything` — 61 `CP_BOOL` variables:**

`addcontrol addescape altshow appendwrite askquit autostop brief casemodewrite controlswait
debug-out-short dyngmin enable_noisy_r fournosave histsubst interactive interp keep#branch
mingwpath moremode ng_nomodcheck no_auto_braces no_auto_bridge_family no_auto_gnd no_mem_check
no_spiceinit no_spinit noasciiplotvalue nobreak noisyxspice nolegend nopadding noparse
noprintscale noquotesinoutput nosighandling nosort nostepsizelimit nosubckt notrnoise nounits
plainlet plainplot plainwrite plothistory printinfo probe_alli_given probe_alli_nox
probe_is_given renumber sanelet silent_fileio soacheck spectrace sqrnoise statlocal ticmarks
topo_reduce wr_onespace wr_singlescale wr_vecnames x11lineararcs`

**Write these with `set x=<number>` and NEVER bare — 41 `CP_NUM`:**

`auto_bridge csnumprec dpolydegree fourgridsize gridsize hcopyfontsize hcopyheight
hcopypscolor hcopypstxcolor hcopywidth height helpinitxpos helpinitypos maxwarns nfreqs
nperiods num_threads polydegree polysteps ps_global_hash_table ps_global_tmodels
ps_ports_and_pins ps_scan_gates_optimize ps_tpz_delays ps_udevice_exit ps_udevice_msgs
ps_use_mntymx ps_with_inverters ps_with_tri_inverters pyplot_subplots rndseed sim_status
specwindoworder ticmarks warn wfont_size width wnflag xbrushwidth xfont_size xgridwidth
xtrtol`

**…and 12 `CP_REAL`:** `cshunt_value diff_abstol diff_reltol diff_vntol diode_cj0 diode_rser
event_node_spacing mtimeavgwindow plot_auto_spacing pyplot_linewidth scale xbrushwidth
xgridwidth` *(`xbrushwidth` and `xgridwidth` appear in both lists — §6.4)*

**49 `CP_STRING`** (bare `set` is inert; quoting is fine and often necessary): `casemode
device display editor filetype gnuplot_terminal gridstyle hcopydev hcopydevtype hcopyfont
hcopyfontfamily hcopyfontsize hcopyheight hcopyscale hcopywidth helpboldfont helpbuttonfont
helpbuttonstyle helpitalicfont helppath helpregfont helptitlefont level lprplot5 lprps
measoutfile modelcard modelline ngbehavior plotstyle pointchars pointstyle pyplot_backend
pyplot_figsize pyplot_python pyplot_style pyplot_terminal rawfile remote_shell rhost rprogram
specwindow spicepath subend subinvoke substart ticchar wfont xfont`

**4 `CP_LIST`** (need the `( a b c )` form; nothing else reaches them, and `-D` cannot):
`sourcepath svg_intopts svg_stropts ticlist`

### 6.3 Values coerced oddly

| what | where | behaviour |
|---|---|---|
| `set x=1.7` read as `CP_NUM` | `variable.c:846` | `(int) 1.7` = **1**, truncation not rounding, silent |
| `set x=0x10` | `ft_numparse` | **0**, silent |
| `set x="1"` read as NUM/REAL | `cp_setparse` + coercion table | **inert**, silent |
| `set x=1` read as `CP_STRING` | `variable.c:848` | becomes `"1"` — works |
| `set x=1.5` read as `CP_STRING` | `variable.c:850` | `sprintf("%f")` = `"1.500000"` — **loses precision and gains trailing zeros**; matters for `hcopywidth`/`hcopyheight`/`hcopyfontsize`, which PostScript reads as strings |
| `-D x=<anything>` | `main.c:994` | **always `CP_STRING`** — inert for NUM/REAL |
| `set` with a very long string into a small buffer | `variable.c:817-821` | truncated with `Warning: string length for variable %s is limited to %zu chars` |

### 6.4 Variables read at two different `CP_` types

Six, and only one is a real hazard:

| name | types | verdict |
|---|---|---|
| `ticmarks` | `CP_NUM` (`graf.c:117`) then `CP_BOOL` (`graf.c:118`) | **the correct pattern.** Both `set ticmarks` and `set ticmarks=10` work. This is what every other boolean read should have done |
| `xbrushwidth` | `CP_NUM` (x11/svg/gnuplot/windisp), `CP_REAL` (`postsc.c:185`) | safe — NUM↔REAL coerce both ways |
| `xgridwidth` | same | safe |
| `hcopywidth` | `CP_NUM` (`svg.c:157`), `CP_STRING` (`postsc.c:163`) | safe — NUM→STRING coerces; but a *real* value reaches PostScript as `"800.000000"` |
| `hcopyheight` | same | same |
| `hcopyfontsize` | same | same |

### 6.5 The OPTtbl side of the same trap — `klu_memgrow_factor`

Not a `cp_getvar` variable, but the critique flagged it and it belongs with these.
SOURCE, `src/spicelib/analysis/cktsopt.c:186-188`:

```c
    case OPT_KLU_MEMGROW_FACTOR:
        task->TSKkluMemGrowFactor = (val->rValue == 1.2);
        break;
```

The row is declared `IF_SET|IF_REAL` (`cktsopt.c:376`) and the field is a `double`
(`tskdefs.h:79`) that ends up as KLU's `Common->memgrow` (`klusmp.c:1117`). So the option
stores **1.0 if you write exactly 1.2, and 0.0 for every other value** — including every
value a user would actually want. The default from `CKTnewTask` (`cktntask.c:144`) is a
correct `1.2`, so **the option can only make things worse.** MEASURED on a small RC, KLU
gives identical results at 1.2 and 2.0 because a tiny matrix never needs to grow; the defect
is latent, not observable on a toy deck. **Do not offer this field.**

---

## 7. Question 5 — the merged classification

Every option in the merged set — 57 settable `OPTtbl` keywords + 27 `IF_ASK` statistics +
`itl3`/`itl5` + 163 `cp_getvar` variables + the `cp_usrset`-only names + the mechanism-E
preprocessing options — appears in **exactly one** category below. `[C]` marks a
`cp_getvar` variable (this dossier), `[T]` an `OPTtbl` keyword (`options.md` Table A/B),
`[U]` a `cp_usrset`-only name (`options.md` Table D), `[E]` a preprocessing pseudo-option
(`options.md` Table E). **`INERT`** marks something that does nothing in this build; a GUI
must not offer it.

### 7.1 Tolerances
`reltol`[T] `abstol`[T] `vntol`[T] `chgtol`[T] `trtol`[T] `pivtol`[T] `pivrel`[T]
`ltereltol`[T] `lteabstol`[T] `ltetrtol`[T] `epsmin`[T] `absdv`[T] `reldv`[T]
`diff_abstol`[C] `diff_reltol`[C] `diff_vntol`[C]

### 7.2 Iteration limits
`itl1`[T] **INERT below 100** `itl2`[T] **INERT below 100** `itl4`[T] **INERT below 100**
`itl3`[T] **INERT — empty case arm**, `cktsopt.c:83`
`itl5`[T] **INERT — empty case arm**, `cktsopt.c:88`
`maxopalter`[T] `maxevtiter`[T] `bypass`[T]

> `niiter.c:37-39` raises `maxIter` to 100 whenever it is lower, on **every** `NIiter()`
> caller. The shipped defaults `itl2 = 50` and `itl4 = 10` are therefore both 100 in fact.
> A spinner that offers 10 lies; clamp the GUI input to ≥ 100 and say why.

### 7.3 Timestep and integration
`method`[T] `maxord`[T] `xmu`[T] `minbreak`[T] `trytocompact`[T] `newtrunc`[T]
(*build-gated on `PREDICTOR`, undefined here → emits `Warning: Option 'newtrunc' ignored`,
`cktsopt.c:199-207`; the only probe for `PREDICTOR` there is*) `nostepsizelimit`[C]
`autostop`[C] `interp`[C] `xtrtol`[C]

### 7.4 Convergence aids
`gmin`[T] `gshunt`[T] `gminsteps`[T] `gminfactor`[T] `srcsteps`[T] `itl6`[T] (*alias of
`srcsteps`*) `noopiter`[T] `noopac`[T] `noopalter`[T] `nodedamping`[T] `copynodesets`[T]
`oldlimit`[T] **INERT on the `.control` route** `rshunt`[T] `cshunt`[T] `cshunt_value`[C]
`dyngmin`[C] `topo_reduce`[C] `convlimit`[T] `convstep`[T] `convabsstep`[T]
`ramptime`[T] **INERT — `#ifdef XSPICE_EXP`, defined nowhere**

> `oldlimit`: `CKTnewTask()`'s always-compiled "special" arm (`cktntask.c:36-88`) copies 45
> `TSK*` fields and leaves `/* fixLimit */` as a bare comment at `:68`. `.options oldlimit`
> is therefore dropped the moment an analysis is issued as a `.control` command, which is
> ASE-L's shape. (`minBreak` at `:51` and `delmin` at `:61` are dropped too but recomputed
> per run, so they are harmless.)
> `ramptime` is a code-model knob (`cm_analog_ramp_factor()`, `cm.c:507-522`) plus one
> breakpoint (`dctran.c:220-221`). It ramps nothing by itself.
> The fourth rung, `optran`, is a **command**, not an option — see `convergence.md` and
> F11. It is on by default and supersedes `noopiter`/`gminsteps`/`srcsteps`.

### 7.5 Device defaults
`defl`[T] `defw`[T] `defm`[T] `defad`[T] `defas`[T] `badmos3`[T] `indverbosity`[T]
`scale`[C] `scalm`[E] **INERT — `Warning: option SCALM is not supported.`, `inp.c:891-901`**
`wnflag`[C] `diode_cj0`[C] (*`ngbehavior=ps|lt` only*) `diode_rser`[C] (*same*)
`ng_nomodcheck`[C] `enable_noisy_r`[C] `rseries`[E] `savecurrents`[E]
`savecurrents_bsim3`[E] `savecurrents_bsim4`[E] `savecurrents_mos1`[E]
`nosavecurrents` **INERT — does not exist in this tree (§4.1)**

### 7.6 Temperature
`temp`[T] `tnom`[T] (*and `.dc temp` / the `temp-sweep` scale vector, which is an analysis
parameter, not an option*)

### 7.7 Model and solver selection
`sparse`[T] `klu`[T] `klu_memgrow_factor`[T] **INERT/BROKEN — stores `(val == 1.2)`, §6.5**
`num_threads`[C] `ngbehavior`[C] `casemode`[C] `auto_bridge`[C] `no_auto_bridge_family`[C]
`auto_bridge_<family>_<type>_<dir>`[C] `autopartial`[T] `noisyxspice`[C]

### 7.8 Output and formatting
`keepopinfo`[T] `filetype`[C] `appendwrite`[C] `plainwrite`[C] `nopadding`[C]
`keep#branch`[C] `casemodewrite`[C] `noquotesinoutput`[C] `measoutfile`[C]
`numdgt`[U] `rawfileprec`[U] `measureprec`[U] `rawfile`[C/U] `units`[U] `csnumprec`[C]
`nfreqs`[C] `nperiods`[C] `fourgridsize`[C] `fournosave`[C] `polydegree`[C] `dpolydegree`[C]
`mtimeavgwindow`[C] `specwindow`[C] `specwindoworder`[C] `sqrnoise`[C] `nosort`[C]
`altshow`[C] `plainlet`[C] `sanelet`[C] `nobreak`[C] `noprintscale`[C] `noasciiplotvalue`[C]
`width`[C] `height`[C] `moremode`[C] `wr_singlescale`[C] `wr_vecnames`[C] `wr_onespace`[C]
`plainplot`[C] `nolegend`[C] `nounits`[C] `ticmarks`[C] `ticchar`[C] `ticlist`[C]
`pointchars`[C] `pointstyle`[C] `gridstyle`[C] `plotstyle`[C] `gridsize`[C] `polysteps`[C]
`plot_auto_spacing`[C] `event_node_spacing`[C] `plothistory`[C] `noinit`[U] `norefvalue`[U]
`list`[U] `nopage`[U] `nomod`[U] `node`[U] `opts`[U] `acct`[U] `noacct`[U]
`x11lineararcs`[C] **INERT — `if (0 && …)`, `x11.c:707`, and `spinit` sets it**
— plus the whole device/hardcopy block of §2.5 (`display device xfont xfont_size wfont
wfont_size xbrushwidth xgridwidth hcopy* lprps lprplot5 svg_* gnuplot_terminal pyplot_*
color0…colorN help*`)

### 7.9 Diagnostics
`warn`[C] `maxwarns`[C] `soacheck`[C] `printinfo`[C] `no_mem_check`[C] `spectrace`[C]
`sim_status`[C] `ngdebug`[U] `nginfo`[U] `strict_errorhandling`[U] `strictnumparse`[U]
`debug`[U] **INERT — `FTEDEBUG` undefined; warns `compiled without debug messages`**
`debug-out-short`[C] `unixcom`[U] `silent_fileio`[C] `askquit`[C] `histsubst`[C]
`addescape`[C] `nosighandling`[C] `level`[C] `editor`[C]
— and the 27 read-only `IF_ASK` statistics[T], which are the `rusage` surface:
`totiter traniter equations originalnz fillinnz totalnz tranpoints accept rejected time
loadtime synctime reordertime factortime solvetime trantime tranloadtime transynctime
tranfactortime transolvetime trantrunctime trancuriters actime acloadtime acsynctime
acfactortime acsolvetime`

### 7.10 Netlist processing (a category the ADE-L analogy has no name for, and the GUI needs)
`noparse`[C] `nosubckt`[C] `statlocal`[C] `renumber`[C] `controlswait`[C] `brief`[C]
`no_auto_gnd`[C] `no_auto_braces`[C] `addcontrol`[C] `sourcepath`[C] `mingwpath`[C]
`substart`[C] `subend`[C] `subinvoke`[C] `modelcard`[C] `modelline`[C]
`probe_is_given`[C] `probe_alli_given`[C] `probe_alli_nox`[C] `notrnoise`[C]
`no_spinit`[C] `no_spiceinit`[C] `interactive`[C] `rndseed`[C] `seed`[E] `seedinfo`[E]
`spicepath`[C] `rhost`[C] `rprogram`[C] `remote_shell`[C]
`ps_global_tmodels`[C] `ps_global_hash_table`[C] `ps_tpz_delays`[C] `ps_use_mntymx`[C]
`ps_ports_and_pins`[C] `ps_udevice_msgs`[C] `ps_udevice_exit`[C] `ps_scan_gates_optimize`[C]
`ps_with_inverters`[C] `ps_with_tri_inverters`[C]
`curplot`[U] `curplotname`[U] `curplottitle`[U] `curplotdate`[U] `plots`[U] `curcasemode`[U]

### 7.11 Experimental or inert — the do-not-offer list, consolidated

| option | why | anchor |
|---|---|---|
| `itl1` `itl2` `itl4` below 100 | floored at 100 unconditionally | `niiter.c:37-39` |
| `itl3` `itl5` | `case` arms are empty | `cktsopt.c:83,88` |
| `ramptime` | live code is inside `#ifdef XSPICE_EXP`, defined nowhere | `vsrcload.c:465`, `isrcload.c:448`, `asrcload.c:54` |
| `oldlimit` | `TSKfixLimit` never copied in `CKTnewTask` | `cktntask.c:68` |
| `klu_memgrow_factor` | stores a boolean `(val == 1.2)` into a double | `cktsopt.c:187` |
| `newtrunc` | needs `PREDICTOR`, undefined here; prints an ignore warning | `cktsopt.c:199-207` |
| `scalm` | explicitly refused with a warning | `inp.c:891-901, 918-928` |
| `nosavecurrents` | **does not exist in this tree at all** | §4.1 |
| `x11lineararcs` | `if (0 && …)` — and `spinit` sets it, so it is a visible lie in `set` output | `x11.c:707`, `spinit.in:4` |
| `debug` | `FTEDEBUG` undefined; warns and does nothing | `options.c:346-348` |
| `polysteps` `dpolydegree` `mtimeavgwindow` | **not** inert — `options.md` and `ft_setkwords` mislead here; all three are live (§2.4, §2.5) | `plotcurv.c:342`, `cmath4.c:263`, `cmath4.c:1054` |
| `.SNDPARAM` / `.SNDPRINT` | `HAVE_LIBSNDFILE` / `HAVE_LIBSAMPLERATE` undefined | `dotcards.md` §3.24 |
| `check_autostop`'s own gate | the `cp_getvar("autostop")` at `measure.c:538` is **commented out**; the real gate is `have_autostop` at `dctran.c:200`/`:430` | `measure.c:534-541` |

`ft_setkwords[]` (`miscvars.c:25-133`) is the tree's own list of "known" `set` names. It is
**stale in both directions**: it lists `dpolydegree` (real, but the list is not why),
`polysteps`, `maxwins`, `slowplot`, `dontplot`, `geometry<num>` and omits most of §2. Do not
use it as the GUI catalogue. This dossier plus `options.md` Tables A/B/D/E is the catalogue.

---

## 8. Findings that change what earlier dossiers say

1. **`options.md` Table C is incomplete by ~140 names.** It lists roughly 25 mechanism-C
   variables; there are 163. The missing ones are mostly presentation, but `wnflag`,
   `diode_cj0`, `diode_rser`, `cshunt_value`, `no_mem_check`, `noquotesinoutput`,
   `keep#branch`, `nopadding`, `casemodewrite`, `plainwrite`, `filetype`, `appendwrite`,
   `mtimeavgwindow`, `dpolydegree` and the ten `ps_*` are not.
2. **`options.md` says `polysteps` is "read by nothing".** It is read at `plotcurv.c:342`
   inside `plotinterval()`, which `ft_graf()` calls at four sites.
3. **The critique's §1.3 says `diode_cj0`/`diode_rser` "silently change every diode in the
   netlist".** They do — but only under `ngbehavior=ps` or `lt`
   (`newcompat.ps || newcompat.lt`, `diosetup.c:87/239/257`). In default mode they are inert.
4. **The critique names `rsdiode` as a third variable.** It is not a variable; it is the
   local `double rsdiode` that `diode_rser` is read into (`diosetup.c:240`, `:258`). There
   are exactly two diode variables.
5. **`$osdi_enabled` is a false negative on a default build** (§5.4). New.
6. **`nosavecurrents` is confirmed absent** and the real `savecurrents` + AC behaviour is two
   distinct failures, neither of them the one the manual describes (§4). New.
7. **`-D name=value` is always a string** and therefore cannot deliver any `CP_NUM` or
   `CP_REAL` option (§1.5). New, and it invalidates the obvious GUI approach.
8. **`.param x = 'var(name)'` is a documented-nowhere channel from GUI state into the
   netlist** (§2.1). New.
9. **`curcasemode` is invisible to `cp_getvar` and to `set`** — `$curcasemode` only (§5.1).
10. **A grep for `cp_getvar` must use `-a`** or it silently loses `cmath4.c` (§0).

---

## 9. Gaps and open questions

1. **`@m1[id]` under AC is 3 points of zero** while `@r1[i]` is zero-length. Both are wrong,
   but the *reason* they differ (which `askQuest` arms return a value in `MODEAC`) was not
   traced. Only matters if someone wants to fix it upstream rather than route around it.
2. **`auto_bridge_<family>_<type>_<dir>`** — the computed-name variable family at
   `evtcheck_nodes.c:524/569/742/761`. I read the construction but did not exercise a
   user-defined bridge. `xspice.md` owns this; it should record the exact spellings.
3. **The `ps_*` ten** are the PSpice `U`-device translator's knobs. I classified them from
   their fallbacks; none was exercised against a PSpice digital deck.
4. **`csnumprec`** is read in `cp_varwl` and only honoured when `> 0`; I did not measure what
   it does to `$var` expansion of a real.
5. **`libngspice`** — `sharedspice.c` contributes six reads (`nosighandling` ×2,
   `no_spiceinit`, `rndseed`, `sourcepath`, `addescape`). None was exercised; the shared
   build still does not exist on this machine (critique §5.7 item 2).
6. **The `itl1/2/4` floor was taken from source, not measured.** `niiter.c:37-39` is
   unambiguous, but a deck that provably needs 150 iterations and converges at
   `.options itl1=10` would nail it shut.
7. **`no_mem_check`'s refusal path** was read, not triggered. Triggering it needs a deck
   whose estimated plot exceeds RAM.
8. **Whether `unset` restores the default** for mechanism-C variables. `options.md` proves it
   does **not** for mechanism-A (`cp_remvar` re-applies the old value, `variable.c:623`); for
   mechanism C, `unset` removes the variable from the list so the next lazy read misses and
   takes the fallback — which *is* a restore. Verified by inspection of `getvar_chain`, not by
   running. The one case where it demonstrably matters is `autostop`, which ngspice itself
   `cp_remvar`s at `inp.c:1152`.
