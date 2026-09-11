# Dossier: Initial Conditions, Convergence Machinery and "It Did Not Converge" Remedies

Source tree: `/home/analog/dev/ngspice`, branch `ver_50`, `git describe = ngspice-46-419-gccebdf2a2`.
All `file:LINE` anchors are relative to `/home/analog/dev/ngspice/`.
Runtime facts marked **[verified]** were reproduced with the already-built binary
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` against scratch decks under
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/`.
Neither repository was modified.

---

## 0. Build configuration of *this* tree (matters for almost everything below)

From `build-ver_50/src/include/ngspice/config.h`:

| Macro | State here | Consequence for this dossier |
|---|---|---|
| `XSPICE` | **defined** (config.h:579) — on by default, `--disable-xspice` to remove | `minbreak` auto-default changes by 5 orders of magnitude (§6.3); `rshunt`/`convlimit`/`ramptime`/`maxopalter` options exist; `EVTop` replaces `CKTop` when event instances exist (§4.7) |
| `KLU` | **defined** (config.h:463) | `.options klu` / `.options sparse` exist; `.nodeset`/`.ic` cannot create a new matrix element under KLU (§1.2) |
| `OSDI` | **defined** (config.h:502) | OSDI (Verilog-A) devices take `max(CKTgmin, CKTdiagGmin)` — `src/osdi/osdiload.c:41` |
| `RFSPICE` | **defined** (config.h:579 area, :535) | `SP` analysis present in `analInfo[]` |
| `PREDICTOR` | **NOT defined** (config.h:529) — `--enable-predictor` | **`.options newtrunc` and `ltereltol`/`lteabstol`/`ltetrtol` are inert** (§6.5). `NIpred()` compiles to a stub (`src/maths/ni/nipred.c:150-152`) |
| `NEWCONV` | **always on** (`src/include/ngspice/macros.h:19`) | `NIconvTest()` also runs each device's `DEVconvTest`, which is what sets `CKTtroubleElt` (§9.2) |
| `NODELIMITING` | not defined (config.h:493) | experimental damping scheme absent |
| `NOBYPASS` | not defined (config.h:490) | `.options bypass` is live |
| `WANT_SENSE2` | not defined (config.h) | SPICE2 sensitivity paths dead |
| `CIDER` | not defined (config.h:11) | `--enable-cider` |
| `WITH_PSS` | not defined (config.h:576) | `.pss` absent from `analInfo[]` (`src/spicelib/analysis/analysis.c:47-49`) |
| `HAS_PROGREP` | **NOT defined in the console build** — only under `HAS_WINGUI` (`src/include/ngspice/ngspice.h:130-134`) or `SHARED_MODULE` (:286-299) | **A GUI that spawns the `ngspice` executable gets no `SetAnalyse()` progress callbacks.** Progress/status must be scraped from console text. Only `libngspice` (`--with-ngshared`) gets the `statfcn` callback (`src/sharedspice.c:1958`) |

---

## 1. `.ic` vs `.nodeset` vs `uic` — what each actually does

### 1.1 Parsing (where the values come from)

* `.nodeset` and `.ic` are handled in **pass 3** of the parser, `src/spicelib/parser/inppas3.c:23-169`, *after* every circuit node exists.
* Accepted syntax is only `V(node) = value` (`inppas3.c:89-108` for nodeset, `:138-159` for ic) plus the special `.nodeset all = value` form (`inppas3.c:79-87`) which applies the value to **every** `SP_VOLTAGE` node with `number > 0` (ground excluded). There is **no** `all` form for `.ic`. **[verified]** `.nodeset all=2.5` seeds every node.
* Non-existent node ⇒ warning, token skipped, simulation continues. **[verified]** literal text:
  ```
  Warning : Nodeset on non-existent node - zzz, ignored
     Please check line .nodeset v(zzz)=1

  Warning : IC on non-existent node - qqq, ignored
     Please check line .ic v(qqq)=1
  ```
  (`inppas3.c:95-98` and `:144-147`; both to **stderr**.)
* Both land on the `CKTnode` via `CKTsetNodPm()` — `src/spicelib/analysis/cktsetnp.c:29-37`: `PARM_NS` sets `node->nodeset` + `node->nsGiven`; `PARM_IC` sets `node->ic` + `node->icGiven`. Parameter table: `src/ngspice.c:22-26`.
* The dot-card handlers in `inp2dot.c` deliberately do nothing for these (`.nodeset` → `src/spicelib/parser/inp2dot.c:871-872`; `.ic` → `:885-886`).
* **Only node voltages** can be given. Branch currents and device internal states are not addressable by `.ic`/`.nodeset`.

### 1.2 `CKTic()` — the pre-analysis seeding pass

`src/spicelib/analysis/cktic.c`, called from `CKTdoJob()` for every analysis whose `SPICEanalysis.do_ic` is 1 (`src/spicelib/analysis/cktdojob.c:190-191`).

Sequence:
1. Zero the whole RHS (`cktic.c:21-24`).
2. For each `nsGiven` node: make/find the diagonal matrix element, set `CKThadNodeset = 1`, and seed `CKTrhsOld[n] = CKTrhs[n] = node->nodeset` (`cktic.c:26-48`).
3. For each `icGiven` node: make/find the diagonal element and seed `CKTrhsOld[n] = CKTrhs[n] = node->ic` (`cktic.c:49-71`).
   **Precedence within `CKTic`: if the same node has both, the `.ic` seed overwrites the `.nodeset` seed**, because the ic block runs second (`cktic.c:70`).
4. **Only if `CKTmode & MODEUIC`**: call every device's `DEVsetic` (`cktic.c:74-81`).
5. KLU caveat (`cktic.c:29-45`, `:52-66`): under `.options klu`, a diagonal element that does not already exist **cannot be created**, and you get
   `Warning: The needed element doesn't exist in the matrix, but KLU mode cannot create a new element. Please specify an existing element for .nodeset` (or `for .ic`) — printed to **stdout**.

`do_ic == 1` for: `AC` (`acsetp.c:104`), `DC` sweep (`dctsetp.c:114`), `OP` (`dcosetp.c:42`), `TRAN` (`transetp.c:82`), `PZ` (`pzsetp.c:100`), `DISTO` (`dsetparm.c:92`), `NOISE` (`nsetparm.c:105`), `SP` (`spsetp.c:111`), `PSS` (`psssetp.c:78`).
`do_ic == 0` for: `TF` (`tfsetp.c:71`) and `options` (`cktsopt.c:398`).

### 1.3 `CKTload()` — what actually happens to the matrix

`src/spicelib/analysis/cktload.c:120-174`. This is the only place where a nodeset or ic *constrains* the system.

**Nodeset clamp** (`cktload.c:122-145`) is applied when
`CKTmode & MODEDC` **and** `CKTmode & (MODEINITJCT | MODEINITFIX)`.
`MODEDC = 0x70` covers `MODEDCOP | MODETRANOP | MODEDCTRANCURVE` (`src/include/ngspice/cktdefs.h:179-182`).

For each nodeset node, `ZeroNoncurRow()` (`cktload.c:182-201`) walks the node's row and zeroes every entry whose column belongs to a *voltage* node, returning 1 if the row also touches a *current* unknown:
* row has **no** current unknowns ⇒ the node's equation is **replaced** by `V = nodeset`: diagonal `*= 1`, `RHS = nodeset * CKTsrcFact` (`cktload.c:132-134`).
* row **does** touch current unknowns ⇒ the softer "big conductance" form: diagonal `= 1e10`, `RHS = 1e10 * nodeset * CKTsrcFact` (`cktload.c:128-130`).

Note both are multiplied by `CKTsrcFact`, so during **source stepping the nodeset/ic targets ramp with the sources**.

**IC clamp** (`cktload.c:146-173`) is applied when
`CKTmode & MODETRANOP` **and NOT** `CKTmode & MODEUIC` — with **no `INITF` qualification at all**. It is therefore in force for *every* Newton phase of the transient operating point, including `MODEINITFLOAT`. Same `ZeroNoncurRow` treatment (`*(node->ptr) += 1.0e10` for the current-touching case at `:156`, `= 1` otherwise at `:162`).

**This is the whole difference in one sentence:**
`.nodeset` is released before the final Newton phase, so it only *steers* to one of several possible solutions; `.ic` in a transient OP is *never* released and therefore **changes the answer**.

**[verified]** with `v1 1 0 5 / r1 1 2 1k / r2 2 0 1k`:
| deck | result |
|---|---|
| `.ic v(2)=3` + `.op` | `V(2) = 2.500000e+00` — ic is only a seed (mode is `MODEDCOP`, not `MODETRANOP`) |
| `.ic v(2)=3` + `.tran` (no uic) | Initial Transient Solution `2 → 3`, `v1#branch → -0.002` (a physically inconsistent current, the signature of a clamp), then released for t>0 |
| `.nodeset v(2)=3` + `.tran` (no uic) | Initial Transient Solution `2 → 2.5` (released, true DC answer) |

So: **`.ic` does nothing to a `.op`, `.ac`, `.noise`, `.dc` — it only seeds.** It clamps only in the transient operating point. This is the single most misunderstood behaviour in this area and a GUI must state it explicitly.

### 1.4 `uic`

* `uic` is a *transient analysis parameter*, not an option: `TRANparms[]` entry `{ "uic", TRAN_UIC, IF_SET|IF_FLAG, ... }` (`src/spicelib/analysis/transetp.c:69`), handled at `transetp.c:51-55` → `job->TRANmode |= MODEUIC`. `MODEUIC = 0x10000l` (`cktdefs.h:199`).
* `TRANinit()` copies it into the live mode: `ckt->CKTmode = job->TRANmode` (`src/spicelib/analysis/traninit.c:37`). This happens in `an_init` *before* `CKTic()` in `CKTdoJob` (`cktdojob.c:188-191`), which is why `CKTic`'s `MODEUIC` test works.
* With `uic`, `NIiter()` short-circuits entirely:
  ```c
  if ((ckt->CKTmode & MODETRANOP) && (ckt->CKTmode & MODEUIC)) {
      SWAP(double *, ckt->CKTrhs, ckt->CKTrhsOld);
      error = CKTload(ckt);
      ...
      return(OK);
  }
  ```
  (`src/maths/ni/niiter.c:41-47`). One load, zero Newton iterations, always "converged".
* Console message (`src/spicelib/analysis/dctran.c:247-250`, suppressed if `set ngdebug`):
  ```
  Operating point simulation skipped by 'uic',
    now using transient initial conditions.
  ```
* Under `uic`, `CKTic()` calls each device's `DEVsetic` (`cktic.c:74-81`). 36 device families implement one (`grep 'DEVsetic = ' src/spicelib/devices/*/*init.c`): bjt, bsim1/2/3/3v0/3v1/3v32/4/4v5/4v6/4v7, bsim3soi_dd/fd/pd, bsimsoi, cap, dio, hfet1/2, hicum2, hisim2, hisimhv1/2, jfet, jfet2, mes, mesa, mos1/2/3/6/9, ndev, soi3, vbic, vdmos. `ind`, `isrc`, `vsrc`, `sw`, `ltra`, `tra`, `txl` etc. are `NULL`.
* The `getic` functions harvest **only the ICs the user did not give explicitly**. Example `src/spicelib/devices/cap/capgetic.c:28-32`:
  ```c
  if(!here->CAPicGiven) {
      here->CAPinitCond = *(ckt->CKTrhs + here->CAPposNode) - *(ckt->CKTrhs + here->CAPnegNode);
  }
  ```
  and `CKTrhs` at that moment holds the `.ic`/`.nodeset` seeds from `CKTic`.
* Then the device load uses `CAPinitCond` while `MODEUIC && MODEINITTRAN` (`src/spicelib/devices/cap/capload.c:30-51`). Inductors do the same for their flux (`src/spicelib/devices/ind/indload.c:41-49`), including mutual inductors (`:61-76`) — even though `ind` has no `DEVsetic`, so an inductor with no `ic=` starts from flux computed from `CKTrhsOld`, not from a `.ic`.

### 1.5 Exact precedence when several are present

For a **`.tran ... uic`** run on a node/device pair:
1. **Device instance `ic=` wins** (e.g. `c1 2 0 1n ic=1.5`), because `CAPgetic` skips instances with `CAPicGiven`.
2. Otherwise the device inherits `.ic v(node)=` (it reads the node voltage that `CKTic` seeded).
3. Otherwise it inherits `.nodeset v(node)=` (same mechanism, weaker only because `.ic` overwrites `.nodeset` in `cktic.c:70`).
4. Otherwise 0 (the RHS was zeroed at `cktic.c:21-24`).

**[verified]** deck `c1 2 0 1n ic=1.5` + `.ic v(2)=3` + `.tran 1n 10n uic` starts the transient at **1.500002 V**; removing `ic=1.5` makes it start at **3.0 V**.

For a **`.tran`** run **without** `uic`:
* `.ic` clamps the operating point for the whole OP; `.nodeset` steers only the `JCT`/`FIX` phases and is released.
* If both are on the same node, both clamps are installed in `CKTload` and both write the same row — the ic block runs second (`cktload.c:146-173` after `:122-145`) so the **ic value wins** in `MODEINITJCT`/`MODEINITFIX` too; in `MODEINITFLOAT` only ic is still active.
* Device `ic=` values are **ignored** without `uic` (`capload.c:32-36`, `cond1` requires `MODEUIC && MODEINITTRAN` for the transient branch).

For **`.op`, `.ac`, `.noise`, `.dc`, `.pz`, `.disto`, `.sp`**:
* `.nodeset` steers the JCT/FIX phases; `.ic` **only seeds the starting vector** and is never enforced (mode is `MODEDCOP` or `MODEDCTRANCURVE`, never `MODETRANOP`).

### 1.6 Auxiliary knobs and helpers

* `.options copynodesets` → `TSKcopyNodesets` → `CKTcopyNodesets` (`cktsopt.c:157-159`, `cktdojob.c:103`). When set, device setup routines propagate a terminal's nodeset onto the device's **internal** nodes. Implemented in ~30 device `*setup.c`/`*set.c` files (e.g. `src/spicelib/devices/dio/diosetup.c:386`, `src/spicelib/devices/bsim4v7/b4v7set.c:2354`, `src/spicelib/devices/vsrc/vsrcset.c:59`). Default 0 (`cktntask.c:136`).
* `NIiter` forces at least one extra iteration after the nodesets are released:
  ```c
  if (ckt->CKTmode & MODEINITFLOAT) {
      if ((ckt->CKTmode & MODEDC) && ckt->CKThadNodeset) {
          if (ipass) ckt->CKTnoncon = ipass;
          ipass = 0;
      }
      ...
  ```
  (`niiter.c:326-336`, with `ipass = 1` set in the `MODEINITFIX` arm at `:340-343`).
* **`wrnodev [file]`** (command table `src/frontend/commands.c:676-679`; implementation `src/frontend/com_wr_ic.c:25-66`) dumps the *current* node voltages as a ready-to-paste `.ic v(<node>) = <value>` file (default `dot_ic_out.txt`). Header lines: `* Intermediate Transient Solution`, `* Circuit: <name>`, `* Recorded at simulation time: <t>`. Requires a live `CKTrhsOld`, i.e. a `stop … tran … resume` sequence, otherwise:
  ```
  Warning: Command wrnodev is ignored!
      You need to execute stop ... tran ... resume
  ```
  This is the closest thing ngspice has to Cadence's "save/restore DC solution" and is a first-class GUI feature candidate.

### 1.7 Output artifact of `uic` a GUI must handle

`src/spicelib/analysis/dctran.c:416-419`:
```c
if ((ckt->CKTmode & MODEUIC && ckt->CKTtime > 0 && ckt->CKTtime >= ckt->CKTinitTime)
    || (!(ckt->CKTmode & MODEUIC) && ckt->CKTtime >= ckt->CKTinitTime)) {
    CKTdump(ckt, ckt->CKTtime, job->TRANplot);
}
```
**With `uic` the `t = 0` sample is never written to the output vector.** **[verified]** the same deck produces `Index 0 → 0.000000e+00` without `uic` and `Index 0 → 1.000000e-12` with `uic`. Same clause also explains why output starts at `tstart` while the simulation always runs from 0.

---

## 2. Where a knob lives, and when it takes effect

This is the plumbing a GUI has to respect.

```
.options card  ──┐
option cmd     ──┼─► if_option()  (src/frontend/spiceif.c:463-580)
set <optname>  ──┘        │
                          ▼
                  CKTsetOpt() ──► TSKtask fields (ci_defOpt / ci_defTask)
                  (src/spicelib/analysis/cktsopt.c:33-262)
                          │
                 CKTdoJob(): task ──► ckt at the START of each analysis
                  (src/spicelib/analysis/cktdojob.c:52-120)
                          │
                 an_init() (e.g. TRANinit) overrides some ckt fields
                  (src/spicelib/analysis/traninit.c:21-37)
```

* **Option changes do not take effect until the next `run`/`op`/`tran`/…** `CKTdoJob` copies 40-odd task fields into `ckt` at `cktdojob.c:52-120`. **[verified]** `option method=gear` followed by bare `option` (with no `run` in between) still reports `TRAPEZOIDAL`; after a `run` it reports `GEAR`.
* Defaults live in **one** place: `CKTnewTask()` `src/spicelib/analysis/cktntask.c:93-145`. (`CKTinit()` `src/spicelib/devices/cktinit.c` sets a parallel set of `ckt` defaults, but `CKTdoJob` overwrites them.)
* `TSKtask` fields never wired to any option are zero, because `tmalloc()` is `calloc()` (`src/misc/alloc.c:52-70`). That is how `TSKminBreak = 0`, `TSKdelmin = 0`, `TSKfixLimit = 0` get their "auto" meaning.
* The full option name table is `OPTtbl[]`, `src/spicelib/analysis/cktsopt.c:264-385`. `IF_SET` marks settable, `IF_ASK` marks readable-back (statistics).
* **`option` with no arguments is the read-back surface.** `src/frontend/com_option.c:28-105` prints a structured dump of the *live* `ckt`. Section headers a GUI can parse: `Temperatures:`, `Integration method summary:`, `Matrix solver:`, `Tolerances (absolute):`, `Tolerances (relative):`, `Iteration limits:`, `Truncation error correction, charge based, is selected:` / `…voltage based…`, `Conductances:`, `Default parameters for MOS devices`.
  * **Trap:** `option` prints `temp`/`tnom` in **kelvin** (`com_option.c:33-34` prints `CKTtemp` raw) while every input path is **celsius**. **[verified]** `temp = 300.150000`.
  * `option` also prints `delmin`, which is not settable (§6.3).
* `set <name>=<val>` for a simulator option reaches `if_option` through `cp_usrset` → `US_SIMVAR` (`src/frontend/variable.c:194-228`); the variable is then stored on `ft_curckt->ci_vars`. **[verified]** `set temp=55` works and prints `Doing analysis at TEMP = 55.000000 and TNOM = 27.000000`.
* `spiceif.c:446-460` keeps `unsupported[]` = {`itl3`, `itl5`, `lvltim`, `maxord`, `method`} and `obsolete[]` = {`limpts`, `limtim`, `lvlcod`}. **These lists are only consulted when the parameter is *not found* or lacks `IF_SET`.** `maxord`/`method` do have `IF_SET`, so they work normally and the warning never fires. **[verified]** `option method=gear` + `option maxord=4` from `.control` really change the method.
* `.options` cards are stripped from the deck by `inp_getopts()` (`src/frontend/options.c:262-285`) and replayed through `if_option` at the end of `inp_dodeck` (`src/frontend/inp.c:1605-1625`).

---

## 3. `.op` has no parameters at all

`DCOinfo` declares **zero** analysis parameters (`src/spicelib/analysis/dcosetp.c:32-47`, `NUMELEMS = 0`, `NULL` table). Everything a user can configure about an operating point comes from `.options`, the `optran` command, `.ic`/`.nodeset` and control-language variables. A GUI's "OP analysis" form is therefore entirely a convergence-and-temperature form.

---

## 4. The OP solution strategy ladder (`src/spicelib/analysis/cktop.c`)

`CKTop(ckt, firstmode, continuemode, iterlim)` is called by
`DCop` (`dcop.c:160-163`, `iterlim = CKTdcMaxIter`), `DCtran` (`dctran.c:237-240`), `acan.c:134-137`, `noisean.c:200-204` and `:402-406`, `distoan.c:91-94`, `span.c`, `pzan.c`, and — only on a failed `NIiter` — `dctrcurv.c:306-314`.

### 4.1 The literal order

| Rung | Function | Entry gate | Iterations per inner solve |
|---|---|---|---|
| 1 | plain Newton, `NIiter(ckt, iterlim)` | skipped if `CKTnoOpIter` (`.options noopiter`) — `cktop.c:40-51` | `iterlim` = `itl1` (default 100), floored at 100 |
| 2 | gmin stepping | `CKTnumGminSteps >= 1` (`cktop.c:57`) | `CKTdcTrcvMaxIter` = `itl2` (default 50), floored at 100 |
| 2a | `dynamic_gmin()` (`cktop.c:161-274`) | `gminsteps == 1` | as above |
| 2b | `new_gmin()` "true gmin" (`cktop.c:349-466`) | `gminsteps == 1` **and** `dyngmin` variable **not** set, and 2a failed (`cktop.c:58-70`) | as above |
| 2c | `spice3_gmin()` (`cktop.c:289-346`) | `gminsteps > 1` | as above |
| 3 | source stepping | `CKTnumSrcSteps >= 1` (`cktop.c:85`) | `CKTdcTrcvMaxIter` |
| 3a | `gillespie_src()` (`cktop.c:480-658`) | `srcsteps == 1` | as above |
| 3b | `spice3_src()` (`cktop.c:672-715`) | `srcsteps > 1` | as above |
| 4 | `OPtran()` — transient operating point (`optran.c:296`) | always attempted; returns `oldconverged` immediately if `nooptran` (`optran.c:320-321`) | `CKTtranMaxIter` = `itl4` (default 10), floored at 100 |
| — | give up | `cktop.c:110-115` | |

Each rung returns as soon as it converges (`cktop.c:47-48, 75-76, 90-91, 102-103`).

**[verified]** full ladder on a singular deck (`i1 0 1 1 / c1 1 0 1n / .op`), stderr:
```
Warning: singular matrix:  check node 1

Note: Starting dynamic gmin stepping
Warning: singular matrix:  check node 1

Warning: Dynamic gmin stepping failed
Note: Starting true gmin stepping
Warning: singular matrix:  check node 1
… (repeated)
Warning: True gmin stepping failed
Note: Starting source stepping
Warning: source stepping failed
Note: Transient op started
Note: Transient op finished successfully
```

### 4.2 Rung-by-rung mechanics

**`dynamic_gmin` (Alan Gillespie's algorithm)** — `cktop.c:161-274`
* Zeroes `CKTrhsOld` and `CKTstate0` first (`:182-186`) — it deliberately throws away any nodeset/ic seed.
* `factor = CKTgminFactor` (`.options gminfactor`, default 10). `OldGmin = 1e-2`; first trial value is `CKTdiagGmin = 1e-2 / factor = 1e-3` (`:188-190`). **[verified]** the trace starts at `1.0000E-03`, not `1e-2`.
* Target `gtarget = MAX(CKTgmin, CKTgshunt)` (`:191`), i.e. `1e-12` by default.
* Adaptive: after a step needing `iters <= itl2/4`, `factor *= sqrt(factor)` capped at `gminFactor` (`:216-220`); after `iters > 3*itl2/4`, `factor = MAX(sqrt(factor), 1.00005)` (`:222-223`).
* On a failed step, the previous `rhsOld`/`state0` are restored and `factor = factor^(1/4)` (`:233-249`) — the retry gets *closer* to the last good gmin. Gives up when `factor < 1.00005` (`:234-238`).
* Loop count is **unbounded**; the termination is the `factor` floor, not a step count.
* At the end `CKTdiagGmin` is restored to `CKTgshunt` (`:252`) and one final `NIiter(ckt, iterlim)` decides success (`:261`).

**`new_gmin` "true gmin stepping"** — `cktop.c:349-466`
Identical control flow, but it steps **`ckt->CKTgmin`** — the value each *device model* adds in parallel with its junctions (54 device directories reference `CKTgmin`; e.g. `src/spicelib/devices/dio/dioload.c:514-521`) — instead of the matrix diagonal. Failure-retry floor is `MAX(sqrt(factor), 3)` (`:411-412`), so it backs off much more coarsely. Restores `CKTgmin = MAX(startgmin, CKTgshunt)` at `:443`.
Selected by **`set dyngmin`** being *absent*: `cp_getvar("dyngmin", CP_BOOL, …)` at `cktop.c:60` — if `dyngmin` **is** set, only `dynamic_gmin` runs. This is a control-language variable, **not** an `.options` entry, and is undocumented in the tree.

**`spice3_gmin`** — `cktop.c:289-346`
Classic SPICE3: `CKTdiagGmin = (gshunt==0 ? gmin : gshunt) * gminFactor^gminsteps` (`:298-302`), then exactly `gminsteps+1` fixed steps dividing by `gminFactor` (`:304-322`), then a final `NIiter(iterlim)`.

**What gmin stepping does to the matrix:** `CKTdiagGmin` is passed to `SMPreorder()`/`SMPluFac()` (`src/maths/ni/niiter.c:122-123, 156-157, 173`), which call `LoadGmin()` (`src/maths/sparse/spsmp.c:460-478`) adding the value to **every** diagonal entry of the matrix, including current-equation rows. `gshunt` is what `CKTdiagGmin` is left at after stepping ends, i.e. **`.options gshunt` is a permanent diagonal loading**, not a device-level parameter. `.options gmin` is the per-junction conductance inside device models.

**`gillespie_src`** — `cktop.c:480-658`
1. `CKTsrcFact = 0`, zero `rhsOld`/`state0`, solve (`:494-506`).
2. If that fails, run a **hard-coded** 11-step decade gmin sweep (`for i<10: diagGmin *= 10`, then 11 steps dividing by 10) at `:510-549` — `gminFactor` and `gminsteps` are ignored here.
3. Then ramp: `raise` starts at `0.001`; `raise *= 1.5` if a step took `<= itl2/4` iterations, `raise *= 0.5` if `> 3*itl2/4` (`:603-607`); on failure `raise /= 10` capped at `0.01` and the state is rolled back (`:619-636`). Loop while `raise >= 1e-7 && ConvFact < 1` (`:641`). `CKTsrcFact` is clamped to 1 (`:638-639`).
4. Success iff `ConvFact == 1` (`:650-657`).
Note `iterlim` is explicitly ignored (`NG_IGNORE(iterlim)` at `:489`).

**`spice3_src`** — `cktop.c:672-715`
`CKTsrcFact = i / numSrcSteps` for `i = 0 … numSrcSteps` (`:683-684`), each solved with `itl2`; **any** failure aborts the rung immediately (`:691-700`).

**Side effect worth knowing:** both source-stepping functions set `ckt->CKTcurrentAnalysis = DOING_TRAN` on failure (`cktop.c:651`, `:693`). That flag is what suppresses the "Too many iterations without convergence" `errMsg` in `NIiter` (`niiter.c:274`).

### 4.3 The literal console messages (a GUI can parse these for live status)

All `SPfrontEnd->IFerrorf` output is produced by `OUTerrorf()` (`src/frontend/outitf.c:1771-1792`) with the prefix table at `outitf.c:1725-1734`:
`ERR_WARNING → "Warning: "`, `ERR_FATAL → "Fatal error: "`, `ERR_PANIC → "Panic: "`, `ERR_INFO → "Note: "`. **Everything goes to `cp_err` (stderr)** and is `fflush`ed. `ERR_INFO` messages are **suppressed** if the control variable `printinfo` is set (`outitf.c:1777`) — the name is the opposite of the behaviour; treat it as "silence notes".

| Literal text (after the prefix) | Anchor | Meaning | gated |
|---|---|---|---|
| `Starting dynamic gmin stepping` | cktop.c:173 | rung 2a entered | always |
| `Trying gmin = %12.4E ` (stderr, **no newline**) | cktop.c:195 | one gmin trial value | `set ngdebug` |
| `One successful gmin step` | cktop.c:205, 321, 394, 546 | | `set ngdebug` |
| `Further gmin increment` | cktop.c:240, 431 | last step failed, backing off | `set ngdebug` |
| `Last gmin step failed` | cktop.c:236, 427 | rung 2 gave up | `set ngdebug` |
| `Dynamic gmin stepping failed` / `… completed` | cktop.c:264 / 266 | rung 2a verdict | always |
| `Starting true gmin stepping` | cktop.c:361 | rung 2b entered | always |
| `True gmin stepping failed` / `… completed` | cktop.c:455 / 458 | rung 2b verdict | always |
| `Starting spice3 gmin stepping` | cktop.c:296 | rung 2c entered | always |
| `gmin step failed` | cktop.c:314, 535 | | `set ngdebug` |
| `spice3 gmin stepping completed` / `… failed` | cktop.c:334 / 342 | rung 2c verdict | always |
| `Starting source stepping` | cktop.c:492, 681 | rung 3 entered | always |
| `Supplies reduced to %8.4f%% ` (stderr, **no newline**) | cktop.c:505, 577 | current `srcFact*100` | `set ngdebug` |
| `One successful source step` | cktop.c:571, 599, 702 | | `set ngdebug` |
| `source stepping failed` | cktop.c:652, 694 | rung 3 verdict | always |
| `Source stepping completed` | cktop.c:655 | gillespie success | always |
| `Source stepping completed` | cktop.c:706 | spice3 success | **`set ngdebug` only** |
| `Transient op started` | optran.c:331 | rung 4 entered | always |
| `Ramptime enabled` | optran.c:335 | `opramptime > 0` | always |
| `Transient op finished successfully` | optran.c:484 | rung 4 success | always |
| `Error: Transient op failed, timestep too small` + blank line | cktop.c:99 (plain `fprintf(cp_err,…)`, no `Note:`/`Warning:` prefix) | `OPtran` returned `E_TIMESTEP` (=106) | always |
| `Error: Transient op failed, cause unrecorded` + blank line | cktop.c:101 | `OPtran` returned some other new error | always |
| `\nError: The operating point could not be simulated successfully.` | cktop.c:110 | all four rungs exhausted | always |
| `    Any of the following steps may fail.!` + blank line | cktop.c:113 | printed only if `strict_errorhandling` is **not** set (which otherwise `controlled_exit(1)` at `:112`) | |

**Parsing hazards for a GUI:**
* `Trying gmin = …` and `Supplies reduced to …%` end **without a newline**, so the next `Note:`/`Warning:` line is appended to the same physical line. **[verified]**:
  `Trying gmin =   1.0000E-03 Note: One successful gmin step`
* Ladder messages go to **stderr**; `DC solution failed -`, `CKTncDump`, the initial-transient table and SOA warnings go to **stdout**. The two streams are independently buffered and **arrive out of order** when merged. **[verified]** — in a `2>&1` capture the whole ladder appeared *before* `Circuit: …`.
* `set ngdebug` is the switch that turns the ladder from three lines into a full per-step trace. That trace is exactly what an ADE-style "convergence log" pane wants.

### 4.4 What follows the ladder in each caller

| Caller | On failure prints (stdout unless noted) | Anchor |
|---|---|---|
| `.op` | `\nDC solution failed -\n` then `CKTncDump()` | dcop.c:82 (via `DCop`, actual line 166 of the concatenated read → `src/spicelib/analysis/dcop.c:165-169`) |
| `.tran` | `\nError: Finding the operating point for transient simulation failed \n` (**stderr**) then `CKTncDump()` | dctran.c:242-246 |
| `.ac` | `\nAC operating point failed -\n` then `CKTncDump()` | acan.c:140-143, :286-289 |
| `.noise` | `\nError: NOISE operating point failed -\n` (**stderr**) | noisean.c:206 |
| `.noise` (Hertz variant) | `\nError: AC operating point with variable 'Hertz' for noise sim failed -\n` (**stderr**) | noisean.c:408 |
| `.sp` | `\nAC operating point failed -\n` | span.c:461, :699 |
| `.pss` | `\nTransient solution failed -\n` | dcpss.c:270 |

`CKTncDump()` (`src/spicelib/analysis/cktncdump.c:10-43`) prints, to **stdout**:
```
Last Node Voltages
------------------

Node                                   Last Voltage        Previous Iter
----                                   ------------        -------------
<name>                                 <rhsOld[i]>         <rhs[i]>        [*]
```
A trailing ` *` marks each node that still fails the convergence test (`cktncdump.c:35-37`) — **this is the single most useful diagnostic in ngspice for "why did it not converge"**, and it is currently buried in stdout text. Internal nodes (containing `#` but not `#branch`) are filtered out (`:24`).

### 4.5 `.options noopiter`

`{ "noopiter", OPT_NOOPITER, IF_SET|IF_FLAG, "Go directly to gmin stepping" }` (`cktsopt.c:279`) → `TSKnoOpIter` (`cktsopt.c:41-43`) → `CKTnoOpIter` (`cktdojob.c:99`). Default 0 (`cktntask.c:132`). **[verified]** with `.options noopiter` a trivially convergent diode deck prints `Note: Starting dynamic gmin stepping` / `Note: Dynamic gmin stepping completed`.

### 4.6 How to disable a rung

* rung 1: `.options noopiter` (or `optran 0 …`)
* rung 2: `.options gminsteps=0`
* rung 3: `.options srcsteps=0`
* rung 4: `optran <a> <b> <c> 0 <final> <ramp>` (step size 0 ⇒ `Note: Optran is deselected.`, `optran.c:182-185`)
Documented in `README.optran` (repo root).

### 4.7 XSPICE variant: `EVTop`

When the circuit contains event-driven instances (`ckt->evt->counts.num_insts != 0`), `EVTop()` replaces `CKTop` at the call sites (`dcop.c:146-156`, `dctran.c:224-234`, `acan.c:121-129`, `dctrcurv.c:336-365`).
`EVTop` (`src/xspice/evt/evtop.c:74-201`) alternates event iteration (`EVTiter`) with analog solution: the **first** analog pass is a full `CKTop` (the whole ladder), subsequent passes are a bare `NIiter` that falls back to `CKTop` on failure (`:133-153`).
Limits (both settable by `.options`, both auto-sized in `src/xspice/evt/evtinit.c:350-370`):
* `maxopalter` → `max_op_alternations`, default `num_hybrid_outputs + 1` (`evtinit.c:365`); exceeded ⇒ `Warning: Too many analog/event-driven solution alternations` plus one `ENHreport_conv_prob` block per changed output (`evtop.c:176-197`), returns `E_ITERLIM`.
* `maxevtiter` → `max_event_passes`, default `num_outputs + 1` (`evtinit.c:359`); exceeded ⇒ `Warning: Too many iteration passes in event-driven circuits` (`src/xspice/evt/evtiter.c:292-294`).
* `.options noopalter` disables the alternation entirely (`cktsopt.c:218-220`, exit at `evtop.c:164-165`).
`ENHreport_conv_prob` prints (stdout): `\nWARNING: Convergence problems at %s (%s).  %s\n` (`src/xspice/enh/enh.c:94-95`).

---

## 5. `NIiter` — the Newton loop itself (`src/maths/ni/niiter.c`)

### 5.1 Iteration limits are clamped

```c
/* some convergence issues that get resolved by increasing max iter */
if (maxIter < 100)
    maxIter = 100;
```
`niiter.c:38-39` (upstream, commit `b46dd5eff`/`27fb6cd0a` era). **Consequence: `itl1`, `itl2` and `itl4` are silently raised to 100 whenever they are set below it.** The shipped defaults `itl2 = 50` and `itl4 = 10` are therefore *both* effectively 100. A GUI must not present "transient iteration limit = 10" as if it were honoured. Only values **above** 100 change anything.

### 5.2 Per-iteration flow

1. `CKTload()` — zero RHS, `SMPclear`, call every `DEVload` (`src/spicelib/analysis/cktload.c:60-91`), then XSPICE `rshunt` diagonal loading (`:109-115`), then the nodeset/ic clamping (`:120-174`).
2. `SMPpreOrder` once (`niiter.c:94-105`).
3. Reorder when `MODEINITJCT`, or on the first `MODEINITTRAN` iteration, or when `NISHOULDREORDER` is latched (`niiter.c:107-146`); otherwise re-factor only (`:147-243`).
4. `SMPsolve` (`niiter.c:253-256`).
5. Iteration-limit check (`:271-285`) → `E_ITERLIM`.
6. Convergence test (`:287-290`): the very first iteration is **always** declared non-converged.
7. Optional node damping (`:297-324`).
8. `INITF` state machine (`:326-360`): `JCT → FIX → FLOAT`, `TRAN → FLOAT`, `PRED → FLOAT`, `SMSIG → FLOAT`; convergence is only *accepted* in `MODEINITFLOAT`.
9. `SWAP(rhs, rhsOld)` and repeat (`:363`).

### 5.3 The convergence test (`src/maths/ni/niconv.c:20-99`)

For every matrix row `i`:
* `NaN` ⇒ immediate non-convergence (`niconv.c:44-54`). With `set ngdebug` it prints (stderr, max 10 times, then one summary line):
  `Warning: non-convergence, node <name> is nan`
  `    non-convergence warnings (nan) limited to 10 node <name>`
* voltage nodes: `tol = reltol * max(|old|,|new|) + vntol` (`:56-57`)
* everything else (branch currents): `tol = reltol * max(|old|,|new|) + abstol` (`:68-69`)
* first offender sets `CKTtroubleNode = i`, `CKTtroubleElt = NULL`, returns 1 (`:63-65`, `:75-77`)
* with `NEWCONV` (always on here) it then runs `CKTconvTest()` (`niconv.c:83`), which calls each device's `DEVconvTest` (`src/spicelib/analysis/cktop.c:125-146`); a device failure sets `CKTtroubleElt` and clears `CKTtroubleNode` (`niconv.c:86-89`).

### 5.4 Node damping (`.options nodedamping`)

`niiter.c:297-324`. Active only when `nodedamping` is set, the iteration did **not** converge, the mode is `MODETRANOP` or `MODEDCOP`, and `iterno > 1`. It finds the largest voltage change; if `maxdiff > 10` volts it scales *all* node updates and *all* state updates by `damp_factor = max(10/maxdiff, 0.1)`.

**The thresholds are hard-coded.** `.options absdv` (`TSKabsDv`, default 0.5) and `.options reldv` (`TSKrelDv`, default 2.0) are parsed (`cktsopt.c:163-168`), stored on the task, copied to `ckt` (`cktdojob.c:105-106`) — and **read by nothing**. `grep -rn "CKTabsDv\|CKTrelDv" src --include=*.c` finds only the assignment sites and the shared-library getter (`src/frontend/spiceif.c:1587-1588`). **A GUI should either hide `absdv`/`reldv` or label them as no-ops.**

### 5.5 Singular-matrix reporting

`niiter.c:131-138` (and the KLU refactor path at `:177-184`):
```
Warning: singular matrix:  check node <name>
Warning: singular matrix:  check nodes <name1> and <name2>
```
* Emitted through `IFerrorf(ERR_WARNING, …)` ⇒ stderr, `Warning: ` prefix, and the format string itself ends in `\n` so **each message is followed by a blank line**. **[verified]**
* Limited to **6** messages per run unless `set ngdebug` (`niiter.c:131`, static `msgcount` at `:24`); reset by `NIresetwarnmsg()` (`:370-372`).
* Under SPARSE (not KLU) an `E_SINGULAR` during *re*-factorisation is not fatal: `NISHOULDREORDER` is latched and the iteration is retried (`niiter.c:219-230`). Under KLU it re-orders in the same iteration (`:162-195`) and prints `Warning: KLU ReFactor failed. Factoring again...` when `set ngdebug` (`:169-170`).
* Related knobs: `.options pivtol` (`CKTpivotAbsTol`, default `1e-13`) and `.options pivrel` (`CKTpivotRelTol`, default `1e-3`), both passed to `SMPreorder`/`SMPluFac`.

---

## 6. Transient timestep control

### 6.1 The `.tran` line and derived quantities

`TRANparms[]` `src/spicelib/analysis/transetp.c:64-70`: `tstart`, `tstop`, `tstep`, `tmax`, `uic`.
`TRANinit()` `src/spicelib/analysis/traninit.c:21-37`:
```c
if (ckt->CKTmaxStep == 0) {
    if ((ckt->CKTstep < (CKTfinalTime - CKTinitTime)/50.0) && !cp_getvar("nostepsizelimit", …))
        ckt->CKTmaxStep = ckt->CKTstep;
    else
        ckt->CKTmaxStep = (CKTfinalTime - CKTinitTime)/50.0;
}
ckt->CKTdelmin = 1e-11 * ckt->CKTmaxStep;   /* XXX */
```
So:
* **`tmax` defaults to `tstep`** unless `set nostepsizelimit`, in which case it defaults to `(tstop-tstart)/50`.
* **`delmin` (the absolute floor on the timestep) is `1e-11 × tmax`, and is not user-settable.** `TSKdelmin` exists in `tskdefs.h:58` but no `OPT_*` case ever writes it (`grep TSKdelmin` finds only `cktdojob.c:75`), so `CKTdoJob` always sets it to 0 and `TRANinit` then computes it. To raise `delmin`, the only lever is to raise `tmax`.
* Validation: `tstop <= 0` ⇒ `TSTOP is invalid, must be greater than zero.`; `tstep <= 0` ⇒ `TSTEP is invalid, must be greater than zero.`; `tstart >= tstop` ⇒ `TSTART is invalid, must be less than TSTOP.` (`transetp.c:24-47`).
* First step: `delta = MIN(tstop/100, tstep) / 10` (`dctran.c:125`), then divided by a further 10 at the initial breakpoint (`dctran.c:515`).
* `CKTsaveDelta` initialised to `tstop/50` (`dctran.c:292`).

### 6.2 Integration method and order

* `.options method=trap|gear` — `cktsopt.c:141-147`; **only `trap*` (prefix match on 4 chars) and exactly `gear` are accepted**, anything else returns `E_METHOD`. Default `TRAPEZOIDAL` (`cktntask.c:109`).
* `.options xmu` — the trapezoidal blend, default 0.5 (`cktntask.c:119`). `xmu=0` ⇒ backward Euler; `0.49` is the documented recipe for damping current ringing (comment `cktntask.c:113-118`). Used in `NIcomCof`: order-2 trapezoidal coefficients are `ag[0] = 1/(delta*(1-xmu))`, `ag[1] = xmu/(1-xmu)` (`src/maths/ni/nicomcof.c:42-45`).
* `.options maxord` — clamped to `[1,6]` with a warning (`cktsopt.c:123-134`):
  ```
  Warning -- Option maxord < 1 not allowed in ngspice
  Set to 1
  ```
  Default 2 (`cktntask.c:110`).
* **The transient loop only ever uses order 1 or 2.** `CKTorder` is set to 1 at breakpoints (`dctran.c:485, 494`), after non-convergence (`:741`), after an XSPICE backup (`:761`), and is raised **only to 2**, only from 1, only when `CKTmaxOrder > 1` (`dctran.c:822-833`). Same in `optran.c:779-790` and `dcpss.c:1359-1370`. `grep CKTorder src/spicelib/analysis/dctran.c` shows no other increment.
  ⇒ **`maxord` behaves as a boolean: 1 = pure backward Euler, ≥2 = allow second order.** Gear orders 3–6 are supported by `NIcomCof` (`nicomcof.c:52-110`), `NIintegrate` (`niinteg.c:42-70`), `CKTterr` (`cktterr.c:452-459`) and `CKTtrunc` (`ckttrunc.c:374-418`) but are **unreachable from the transient driver**. This directly contradicts the usual documentation ("MAXORD 2 to 6 for Gear"). *Trust the source.*
* Trapezoidal supports only order 1 and 2 anyway (`nicomcof.c:35-49` returns `E_ORDER` otherwise; `ckttrunc.c:367-369` likewise).
* XSPICE side effect: if the circuit contains any `A` device, `trtol` is forced down (§6.4).

### 6.3 Breakpoints and `minbreak`

* `.options minbreak` → `TSKminBreak` → `CKTminBreak` (`cktsopt.c:138-140`, `cktdojob.c:65`). No default in `CKTnewTask` ⇒ zero from `calloc`.
* When zero, `DCtran` fills it in **differently depending on the build**:
  ```c
  #ifdef XSPICE
      if (ckt->CKTminBreak == 0) ckt->CKTminBreak = 10.0 * ckt->CKTdelmin;   /* dctran.c:163-164 */
  #else
      if (ckt->CKTminBreak == 0) ckt->CKTminBreak = ckt->CKTmaxStep * 5e-5;  /* dctran.c:167-168 */
  #endif
  ```
  With `delmin = 1e-11*tmax`, the XSPICE default is `1e-10 × tmax` — **500 000× smaller** than the non-XSPICE default `5e-5 × tmax`. XSPICE is on by default in this tree, so the tiny value is what users get.
* Breakpoint handling at `dctran.c:488-598`:
  * at/near a breakpoint: `CKTorder = 1` and `delta = MIN(delta, 0.1*MIN(saveDelta, breaks[1]-breaks[0]))` (`:494-508`); on the very first point `delta /= 10` (`:515`), and with `uic` an extra breakpoint is planted at `tstep` "to reduce ringing of current in devices" (`:512-513`).
  * non-XSPICE only: `delta = MAX(delta, 2*delmin)` "don't want to get below delmin for no reason" (`:521-524`).
  * force the step onto the breakpoint if it would be crossed (`:530-538` non-XSPICE, `:582-587` XSPICE).
  * "equalise" the last two steps before a breakpoint by halving (`:539-547`, `:588-598`).
  * XSPICE additionally discards permanent breakpoints `<= CKTtime + CKTminBreak` (`:570-581`) and honours temporary code-model breakpoints via `g_mif_info.breakpoint` (`:551-562`).
* Extra breakpoints are planted by `stop when time = x` entries in the `dbs` database (`dctran.c:206-215`; with `set ngdebug`: `breakpoint set to time = %g`) and by XSPICE `ramptime` (`:220-221`).

### 6.4 Local truncation error (LTE) — the charge-based default

`CKTtrunc()` `src/spicelib/analysis/ckttrunc.c:220-258` (the `CKTnewtrunc == 0` branch) simply asks every device's `DEVtrunc` for its own limit and takes
```c
*timeStep = MIN(2 * *timeStep, timetemp);
```
(`ckttrunc.c:254`) — i.e. **the step can at most double per accepted point**.

Devices with reactive elements call `CKTterr()` — `src/spicelib/analysis/cktterr.c:440-507`:
```c
volttol   = abstol + reltol * MAX(|state0[ccap]|, |state1[ccap]|);       /* :465-466 */
chargetol = reltol * MAX(MAX(|state0[qcap]|,|state1[qcap]|), chgtol) / delta;  /* :468-469 */
tol       = MAX(volttol, chargetol);                                     /* :470 */
/* divided differences of the charge over CKTorder+1 past points  :472-487 */
del = trtol * tol / MAX(abstol, factor * |diff[0]|);                     /* :497 */
/* factor = 0.5 (order 1) or 0.0833… (order 2) for TRAP  :460-463
   factor = 0.5, .2222, .1364, .096, .0730, .0583 for GEAR orders 1..6  :452-459 */
if (order == 2) del = sqrt(del); else if (order == 3) del = cbrt(del); … /* :498-503 */
*timeStep = MIN(*timeStep, del);
```
Knobs, all `.options`, defaults from `cktntask.c`:
| option | field | default | anchor |
|---|---|---|---|
| `reltol` | `CKTreltol` | `1e-3` | cktntask.c:97 |
| `abstol` | `CKTabstol` | `1e-12` | cktntask.c:96 |
| `vntol` | `CKTvoltTol` | `1e-6` | cktntask.c:99 |
| `chgtol` | `CKTchgtol` | `1e-14` | cktntask.c:98 |
| `trtol` | `CKTtrtol` | `7.0` | cktntask.c:104 |

**XSPICE override:** if the circuit has any `A` device (`CKTadevFlag`) and `trtol > 1`, `CKTdoJob` reduces it (`cktdojob.c:81-91`):
```
Reducing trtol to 1 for xspice 'A' devices
```
or, if the control variable `xtrtol` is set,
```
Override trtol to <n> for xspice 'A' devices
```
This is a **control-language variable (`set xtrtol=…`), not an `.options` entry**, and it is undocumented in the tree.

### 6.5 LTE — the voltage-based alternative (`newtrunc`), inert in this build

`ckttrunc.c:259-427` implements a predictor-vs-corrector node-voltage LTE using `CKTlteReltol` / `CKTlteAbstol` / `CKTlteTrtol` (defaults `1e-3`, `1e-6`, `500.` — `cktntask.c:100-102`).
It requires `CKTpred[]`, which is only populated by `NIpred()`, which only exists under `PREDICTOR` (`nipred.c:19`, `:150-152`). Accordingly:
```c
case OPT_NEWTRUNC:
#ifdef PREDICTOR
    task->TSKnewtrunc = (val->iValue != 0);
#else
    task->TSKnewtrunc = 0;
    fprintf(stderr, "Warning: Option 'newtrunc' ignored,\n"
        "    compilation with preprocessor flag 'PREDICTOR' is required.\n");
#endif
```
(`cktsopt.c:199-207`). **[verified]** literal output in this tree:
```
Warning: Option 'newtrunc' ignored,
    compilation with preprocessor flag 'PREDICTOR' is required.
```
If enabled (`../configure --enable-predictor`), `CKTdoJob` announces it on stdout: `Note: Voltage based truncation error correction selected` (`cktdojob.c:125-126`), and `option` prints the `ltereltol`/`lteabstol`/`ltetrtol` block instead of `trtol` (`com_option.c:80-89`).

### 6.6 The step-accept/reject loop (`dctran.c:660-972`)

```
for (;;) {
    olddelta = CKTdelta;  CKTtime += CKTdelta;  NIcomCof();
    converged = NIiter(ckt, CKTtranMaxIter);            /* :709 */
    if (!converged) { CKTtime -= CKTdelta; STATrejected++;
                      CKTdelta /= 8; CKTorder = 1; }    /* :725-741 */
    else if (firsttime) { firsttime = 0; goto nextTime; }  /* no LTE check on the first point :769-791 */
    else {
        newdelta = CKTdelta;  CKTtrunc(ckt, &newdelta);         /* :793-800 */
        if (newdelta > 0.9 * CKTdelta) {                        /* accept :801 */
            if (CKTorder == 1 && CKTmaxOrder > 1) { try order 2; keep it only if
                                                    newdelta > 1.05*CKTdelta }   /* :822-833 */
            CKTdelta = newdelta;  goto nextTime;                 /* :835, :874 */
        } else { CKTtime -= CKTdelta; STATrejected++; CKTdelta = newdelta; }  /* :879-889 */
    }
    if (CKTdelta <= CKTdelmin) {                                 /* :899 */
        if (olddelta > CKTdelmin) CKTdelta = CKTdelmin;          /* one last try at delmin :900-901 */
        else { errMsg = CKTtrouble(ckt, "Timestep too small"); return E_TIMESTEP; }  /* :905-914 */
    }
}
```

### 6.7 "Timestep too small" — exactly what it means

It is raised **only** at `dctran.c:899-914` (and the identical guards `optran.c:814-822`, `dcpss.c:1401`), and only on the *second consecutive* attempt at `delmin`:

> The step was already at (or below) `delmin` on the previous attempt, and the solver still wants to shrink it — either because Newton did not converge (`delta /= 8`) or because the LTE estimate demanded `newdelta <= 0.9*delta`.

The message text is built by `CKTtrouble()` (`src/spicelib/analysis/ckttroub.c:20-79`) — see §9.1. **[verified]** literal console line (via `doAnalyses:` from `ft_sperror`):
```
doAnalyses: TRAN:  Timestep too small; time = 1e-11, timestep = 5.41862e-21: cause unrecorded.


run simulation(s) aborted
```

**Which knobs move it, in order of usefulness:**
1. **`tmax` on the `.tran` line** — raises `delmin` (`= 1e-11*tmax`) proportionally *and* limits the step. This is the only lever on `delmin`.
2. `.options trtol` — larger (e.g. 10, 50) means the LTE estimator demands fewer, larger steps; smaller means the opposite. `trtol` is a *tolerance overestimation factor*: bigger = looser.
3. `.options reltol` / `vntol` / `abstol` / `chgtol` — loosening these loosens both the Newton convergence test (§5.3) and the LTE tolerance (`cktterr.c:465-470`).
4. `.options method=gear` (+`maxord=2`) — Gear damps oscillatory LTE that trapezoidal ringing produces.
5. `.options xmu=0.49` — the ngspice-specific damped trapezoid, cheaper than switching to Gear.
6. `.options itl4=<large>` — only above 100 (§5.1).
7. `.options minbreak` — a too-small `minbreak` makes near-coincident breakpoints force absurdly short steps.
8. `.options gmin` / `gshunt` / XSPICE `rshunt` — for the "high-impedance node" flavour of the failure.
9. `set topo_reduce` — see §6.8.

### 6.8 `set topo_reduce` — the dangling-passive fix (recent upstream feature)

`CKTtopologyReduce()` `src/spicelib/analysis/cktsetup.c:63-257`, called from `CKTsetup`. Its own comment (`cktsetup.c:43-62`) states the motivation precisely:

> A node whose only connection is a single passive terminal (a degree-1 "dangling" node, e.g. the dead end of an opamp compensation cap) carries no steady current/charge, but its row becomes ill-conditioned as the timestep shrinks and shows up as a **spurious "Timestep too small" abort**.

* Enabled by `set topo_reduce` (in `.spiceinit` or `.control`) — **off by default** (`cktsetup.c:72-73`; commit `3c1687ea2`, Holger Vogt, upstream).
* Disabled automatically when XSPICE `rshunt` is in use (`cktsetup.c:75-78`).
* Counts node degree generically over `GENnode()` terminals and, separately, over the XSPICE MIF conn/port tree (`:102-138`) so code-model nodes are not missed.
* Only **capacitors and resistors** are ever pruned; the floating node is pinned with a unit diagonal at load time (`src/spicelib/devices/cap/capload.c:53-67`).
* Console (stdout, first 40 only): `Topology reduction: removed dangling capacitor <name> (floating node <node>)`, `… dangling resistor …`, then `Topology reduction: N dangling passive(s) removed from the matrix.` (`cktsetup.c:194-198`, `:231-235`, `:252-253`).
* With `set strict_errorhandling` it instead reports to stderr and **exits**: `Dangling capacitor <name> (floating node <node>) found in netlist.` then `\nError: N dangling passive(s) found.\n     Please correct the netlist.` (`cktsetup.c:188-193`, `:245-250`).

---

## 7. `optran` — the pre-transient operating point

Reference: `README.optran` at the repo root; implementation `src/spicelib/analysis/optran.c`; command declaration `src/spicelib/analysis/com_optran.h`; command table entry `src/frontend/commands.c:672-675`.

### 7.1 The problem it solves

Rungs 1–3 all try to solve the *algebraic* DC system. Some circuits (latches, relaxation oscillators, electro-thermal power stages, anything with a strong positive-feedback loop) have no numerically reachable DC solution from a cold start, but *do* settle if you simply integrate them forward in time. `OPtran` runs a full, self-contained transient from `t = 0` to `opfinaltime` with **no output vectors and its own private breakpoint array**, then leaves the matrix/state in that settled condition to serve as the operating point (`optran.c:288-294` header comment: "Do a simple transient simulation … No output vectors are generated, actual times and breakpoints are kept local. When returning, the matrix is left in its current state.").

### 7.2 Full argument list

```
optran <opiter> <gminsteps> <srcsteps> <opstepsize> <opfinaltime> <opramptime>
```
Exactly **six** arguments, enforced by the command table (`commands.c:673`, min 6 / max 6). Parsing `optran.c:73-193`.

| # | name | type | meaning | maps to |
|---|---|---|---|---|
| 1 | *opiter* | int, `strtol` | `0` ⇒ skip the plain-Newton rung (equivalent to `.options noopiter`); non-zero ⇒ do it | `TSKnoOpIter` (`optran.c:114-133`, note the inverted internal `opiter` flag and the final write at `:86`) |
| 2 | *gminsteps* | int | overrides `.options gminsteps` | `TSKnumGminSteps` (`optran.c:134-143`, `:87`) |
| 3 | *srcsteps* | int | overrides `.options srcsteps` | `TSKnumSrcSteps` (`optran.c:144-153`, `:88`) |
| 4 | *opstepsize* | real (`INPevaluate`, SI suffixes OK) | the pseudo-transient's `tstep`/`tmax`; **`0` disables optran entirely** | static `opstepsize` (`optran.c:155`) |
| 5 | *opfinaltime* | real | how long to integrate | static `opfinaltime` (`optran.c:160`) |
| 6 | *opramptime* | real, may carry a trailing `uic` | supply ramp duration for the pseudo-transient | static `opramptime` (`optran.c:165`) |

Validation and messages (all during parsing):
* `opstepsize > opfinaltime` ⇒ stderr `Error: Optran step size larger than final time.` then `Error in command 'optran'` (`optran.c:169-171`, `:192`).
* `opstepsize > opfinaltime/50` ⇒ silently reduced, stdout `Note: Optran step size set to %e, (stepsize = finaltime / 50).` (`optran.c:173-176`).
* `opramptime > opfinaltime` ⇒ stderr `Error: Optran ramp time larger than final time.` (`optran.c:177-179`).
* `opstepsize == 0` ⇒ stdout `Note: Optran is deselected.` and `nooptran = TRUE` (`optran.c:182-185`). **[verified]**
* Any parse failure ⇒ stderr `Error in command 'optran'` (`optran.c:192`).
* Called with no arguments and no circuit ⇒ `Warning: syntax error with command 'optran'!` / `    Command ingnored` [sic] (`optran.c:92-95`).

### 7.3 Defaults — **optran is ON by default in this tree**

`src/frontend/init.c:77-94` (in `cp_init()`, which runs at startup from `src/frontend/cpitf.c:74`):
```c
/* To make optran the standard, call com_optran here.
May be overridden by entry in spinit or .spiceinit or a local call in .control. */
    sbuf = { "1", "1", "1", "100n", "10u", "0" };
    com_optran(wl_build(sbuf));
```
That parse sets `nooptran = FALSE` (`optran.c:112`). So **every** ngspice run in this tree has rung 4 armed with `opstepsize = 100 ns`, `opfinaltime = 10 µs`, `opramptime = 0`. The static initialisers `opfinaltime = 1e-6`, `opstepsize = 1e-8`, `nooptran = TRUE` (`optran.c:48-51`) are immediately superseded.
`src/spinit.in` contains **no** `optran` line — the default really does come from `cp_init`.
**[verified]** a `.op` on a singular deck reaches `Note: Transient op started` / `Note: Transient op finished successfully` with no user configuration.

### 7.4 Two-phase application (why the command works in `.spiceinit`)

`com_optran` has a dual personality (`optran.c:73-110`):
* no circuit yet (`.spiceinit`/`spinit`/`cp_init`) ⇒ `getdata = TRUE`, values are cached in file statics `opiter`/`ngminsteps`/`nsrcsteps` plus `opstepsize`/`opfinaltime`/`opramptime`.
* later, `inp_dodeck` calls `com_optran(NULL)` once per loaded circuit (`src/frontend/inp.c:1583-1585`), which pushes the cached first three flags into `ft_curckt->ci_defTask` (`optran.c:85-91`).
* a call from a `.control` block with a live circuit writes `ci_defTask` directly (`optran.c:117-118`, `:139`, `:151`).

### 7.5 What `OPtran` actually does (`optran.c:296-852`)

* Returns `oldconverged` immediately if `nooptran` (`:320-321`).
* If `opramptime > 0`: `CKTsrcFact = 0`, `rhsOld` and `state0` zeroed, one `NIiter(ckt, CKTdcTrcvMaxIter)` at zero supplies, stdout note `Ramptime enabled` (`:332-344`).
* Saves and replaces the step-size fields: `prevmaxstepsize = CKTmaxStep; prevstepsize = CKTstep; CKTmaxStep = CKTstep = opstepsize` (`:361-363`), restoring them only on the success path (`:485-486`).
* `delta = MIN(opfinaltime/100, CKTstep)/10` (`:365`); `CKTsaveDelta = opfinaltime/50` (`:413`); private breakpoint array `opbreaks = {0, opfinaltime}` with `OPsetBreak`/`OPclrBreak` (`:345-349`, `:203-292`).
* Mode is `(CKTmode & MODEUIC) | MODETRAN | MODEINITTRAN` (`:415`) — **it inherits `uic` from the *analysis*, not from the optran command**.
* Main loop is a stripped copy of `DCtran`: `NIiter(ckt, CKTtranMaxIter)` (`:704`), `delta /= 8` on non-convergence (`:735`), `CKTtrunc` accept/reject (`:772-811`), the same `delmin` guard and `CKTtrouble(ckt, "Timestep too small")` (`:814-822`).
* Ends at `AlmostEqualUlps(optime, opfinaltime, 100)` (`:482-489`).
* Progress (shared/Windows builds only): `SetAnalyse("optran init", 0)` then `SetAnalyse("optran", permille)` (`:329`, `:494`).

### 7.6 Known defects in `optran` (verify before designing GUI around them)

1. **The `uic` suffix on argument 6 is parsed and discarded.** `optran.c:165-168` accepts a trailing token containing `uic` (`if (err || ((*stpstr != '\0') && !strstr(stpstr, "uic"))) goto bugquit;`) but nothing ever records it; `grep -n "uic" optran.c` shows the flag only ever comes from `CKTmode & MODEUIC`.
2. **Supply ramping does not stop ramping.** `optran.c:670-671`:
   ```c
   if (opramptime > 0)
       ckt->CKTsrcFact = 0.5 * (1 - cos(M_PI * optime / opramptime));
   ```
   There is no `optime > opramptime` clamp, so once `optime` passes `opramptime` the factor keeps oscillating (at `optime = 2*opramptime` it returns to **0**). `README.optran` itself says "supply ramping (**not yet established**) is OFF". Do not expose argument 6 as a working feature.
3. **`CKTsrcFact` is never restored** on exit from `OPtran` (compare `:485-487`, which restores `CKTmaxStep`, `CKTstep`, `CKTag`, but not `CKTsrcFact`). Only reachable when `opramptime > 0`.
4. **`README.optran` describes an auto-sizing heuristic that is `#if 0`-ed out.** The README says "If a transient simulation follows, choose 100 times the TSTEP value. If an ac or noise simulation follows, take the inverted starting frequency divided by 10". That code exists at `optran.c:345-364` inside `#if 0 … #else`, and the `#else` branch simply uses the user's `opstepsize`. **Trust the source: there is no auto-sizing.**
5. **`CKTdelmin` is 0 for a non-transient job.** For `.op`/`.ac`/`.dc`, `TRANinit` never runs, so `CKTdoJob` leaves `CKTdelmin = 0` (`cktdojob.c:75`) and `OPtran`'s guard `if (ckt->CKTdelta <= ckt->CKTdelmin)` (`:814`) can only fire once `delta` underflows to exactly 0. Not observed to hang in testing (**[verified]** the singular `.op` deck finished normally), but a GUI should impose its own wall-clock timeout on OP runs. *(inference from source, not reproduced)*

### 7.7 How a GUI should present optran

* Present it as a **fourth, named rung** of an "OP convergence strategy" panel, not as a mysterious command — with the four rungs as toggles plus the two meaningful numbers.
* Because `optran`'s first three arguments *override* `.options noopiter/gminsteps/srcsteps` on the same task, the GUI must own **one** model of the four rungs and emit **either** `.options` **or** `optran`, never both. Emitting `optran` is strictly more expressive.
* Sensible controls: `[x] Newton`, `[x] gmin stepping (n steps, factor f)`, `[x] source stepping (n steps)`, `[x] transient OP (step, stop)`; the emitted line is `optran <1|0> <gminsteps> <srcsteps> <step> <stop> 0`.
* Offer a "pick optran stop time" helper implementing what the README *wanted*: `100 × tstep` before a `.tran`, `0.1 / fstart` before an `.ac`/`.noise` — since ngspice does not do it.
* Show the live rung by watching stderr for the `Note: Starting …` / `Note: Transient op started` strings.

---

## 8. Temperature

### 8.1 The four things called "temperature"

| Concept | Where set | Unit at the interface | Stored as |
|---|---|---|---|
| circuit operating temperature | `.temp T`, `.options temp=T`, `set temp=T` | **celsius** | `TSKtemp`/`CKTtemp` in **kelvin** (`+ CONSTCtoK` at `cktsopt.c:75`) |
| nominal / parameter-extraction temperature | `.options tnom=T`, `set tnom=T` | celsius | `TSKnomTemp`/`CKTnomTemp` in kelvin (`cktsopt.c:72`) |
| per-instance absolute temperature | instance parameter `temp=` | celsius | device-specific |
| per-instance offset | instance parameter `dtemp=` | celsius delta | device-specific |

Defaults: `TSKtemp = TSKnomTemp = 300.15 K = 27 °C` (`cktntask.c:125-126`).

### 8.2 `.temp` vs `.options temp` — `.temp` wins, and it takes only ONE value

`.temp` is **not** handled by the parser. `inp2dot.c:861-867` explicitly ignores it ("not yet implemented - warn & ignore"). It is handled in the front end, `src/frontend/inp.c:1166-1177`:
```c
if (ciprefix(".temp", dd->line)) {
    s = skip_ws(dd->line + 5);
    if (*s == '=') s = skip_ws(s + 1);
    temperature = copy(s);       /* the WHOLE remainder of the line */
    *(dd->line) = '*';           /* comment the card out */
}
```
then `inp.c:1181-1196`:
```c
temperature_value = strtod(temperature, &endstr);
endstr = skip_ws(endstr);
if (*endstr != '\0') {
    fprintf(stderr, "Warning: Could not set temperature to %s\n   Set to default 27 C instead.\n", temperature);
    temperature_value = 27;
}
cp_vset("temp", CP_REAL, &temperature_value);
```
Consequences:
* **`.temp` overrides `.options temp`**, because this loop runs *after* `inp_dodeck()` (`inp.c:1096`) has already replayed the `.options` cards through `if_option`. Confirmed by the ngspice manual: ".temp will override .options temp" — https://ngspice.sourceforge.io/docs/ngspice-html-manual/manual.xhtml
* **`.temp` accepts exactly one value.** `.temp -40 27 125` does not sweep; it produces
  ```
  Warning: Could not set temperature to -40 27 125
     Set to default 27 C instead.
  ```
  and runs at 27 °C. **[verified]**
* Only the **last** `.temp` card in the deck survives (each iteration frees the previous `temperature` string, `inp.c:1172-1175`).
* `.temp=125` (with an `=`) is accepted (`inp.c:1169-1171`).
* Because it goes through `cp_vset("temp", …)`, `.temp` and `set temp=` are literally the same mechanism.

### 8.3 How temperature reaches the devices

`CKTdoJob` copies `TSKtemp/TSKnomTemp → CKTtemp/CKTnomTemp` (`cktdojob.c:52-53`) and announces it on **stdout**:
```
Doing analysis at TEMP = 27.000000 and TNOM = 27.000000
```
(`cktdojob.c:122-123`, printed in **celsius**). This is a reliable GUI hook for "what temperature is this run at". **[verified]**
Then `inp_evaluate_temper(ft_curckt)` re-evaluates every `temper`-dependent expression on instance and `.model` lines (`cktdojob.c:128-130`), and `CKTtemp(ckt)` (`src/spicelib/analysis/ckttemp.c:229-244`) sets `CKTvt = CONSTKoverQ * CKTtemp` and calls every device's `DEVtemperature`.
Model-level `tnom` defaults to `CKTnomTemp` if the `.model` card omits it (e.g. `src/spicelib/devices/res/ressetup.c:29`, `mos1/mos1temp.c:42`, `bsim4v7/b4v7set.c:1844`, `dio/diosetup.c:234`).

### 8.4 Per-instance `temp` / `dtemp`

25 device families accept `dtemp` (`grep -rln '"dtemp"' src/spicelib/devices/*/`): asrc, bjt, bsim4, bsim4v5/v6/v7, cap, dio, hfet1, hfet2, hisim2, hisimhv1, hisimhv2, ind, jfet, jfet2, mesa, mos1, mos2, mos3, mos6, mos9, res, vbic, vdmos.
Semantics, canonical example `src/spicelib/devices/res/restemp.c:33-53` + `:83`:
```c
if (!here->REStempGiven) {
    here->REStemp = ckt->CKTtemp;              /* inherit circuit temperature */
    if (!here->RESdtempGiven) here->RESdtemp = 0.0;
} else {
    here->RESdtemp = 0.0;                      /* instance temp WINS, dtemp discarded */
    if (here->RESdtempGiven && …)
        printf("%s: Instance temperature specified, dtemp ignored\n", here->RESname);
}
…
difference = (here->REStemp + here->RESdtemp) - model->REStnom;
```
So the rule is: **`temp=` (absolute) beats `dtemp=` (offset), with a stdout message; otherwise `T = CKTtemp + dtemp`.**
Note `restemp.c` reports the message via bare `printf`, i.e. stdout with no `Warning:` prefix, and suppresses it for `JOBtype == 9` (sensitivity).

### 8.5 A temperature SWEEP — the non-obvious part

**There is no `.step`.** `grep -rn '"\.step"' src/` returns nothing.

ngspice offers exactly two mechanisms:

**(a) `.dc temp <start> <stop> <step>` — a real, first-class temperature sweep, but only for DC.**
The `.dc` parser is generic (`src/spicelib/parser/inp2dot.c:284-345`) — it just records `name1`/`start1`/`stop1`/`step1`. `DCtrCurv` then recognises the literal name `temp` (case-insensitively) at `src/spicelib/analysis/dctrcurv.c:144-151`:
```c
if (cieq(job->TRCVvName[i], "temp")) {
    job->TRCVvSave[i] = ckt->CKTtemp;
    job->TRCVvType[i] = TEMP_CODE;             /* 1023, src/include/ngspice/trcvdefs.h:25 */
    ckt->CKTtemp = job->TRCVvStart[i] + CONSTCtoK;
    inp_evaluate_temper(ft_curckt);
    CKTtemp(ckt);
    goto found;
}
```
At each step it does `CKTtemp += step; inp_evaluate_temper(); CKTtemp(ckt)` (`dctrcurv.c:453-468`), and it restores the original temperature at the end (`:499-503`). The sweep vector is named **`temp-sweep`** (`dctrcurv.c:184-185`), and the sweep value stored in the plot's `CKTtime` slot is in **celsius** (`:377-378`).
Because `.dc` supports two nested sweeps, `.dc vdd 0 1.8 0.01 temp -40 125 5` gives you a proper DC family over temperature.
**[verified]** `.dc temp -40 125 55` produces `Index / temp-sweep / v(2)` rows at −40, 15, 70, 125.
`.dc` can also sweep a **resistor** (`dctrcurv.c:100-105`, vector `res-sweep`) — undocumented in most references and useful for the same GUI form.
Note also: `.dc` normally does **not** run the full `CKTop` ladder per point — it tries `NIiter(itl2)` first and only falls back to `CKTop` on failure (`dctrcurv.c:305-315`); with HSPICE compatibility mode (`newcompat.hs`) it runs `CKTop` at every point (`:297-304`).

**(b) For `.tran`, `.ac`, `.noise`, `.op` — a control-language loop. There is no declarative form.**
```
.control
  foreach t -40 27 125
    set temp = $t
    run
    set curplotname = "tran_$t"
  end
.endc
```
Each `run` re-enters `CKTdoJob`, which re-copies `TSKtemp → CKTtemp` and re-runs `inp_evaluate_temper` + `CKTtemp` (`cktdojob.c:52,122-130,167`), so the sweep is correct — but the GUI, not ngspice, owns the loop, the plot naming and the result collation.
**[verified]** `set temp=55` followed by `run` yields `Doing analysis at TEMP = 55.000000 and TNOM = 27.000000` and `option` then reports `temp = 328.150000`.

**This is precisely the place where "better than ADE" is easy to achieve**: ADE presents temperature as an axis of the analysis setup. ASE-L can do the same by owning the loop and hiding the `.control` scaffolding — and by hiding the celsius/kelvin asymmetry (`.options temp` in °C, `option` read-back in K).

---

## 9. The diagnostic / console surface

### 9.1 `CKTtrouble()` — `src/spicelib/analysis/ckttroub.c:20-79`

The one function that assembles a "where did it go wrong" string. Called only for `Timestep too small` (`dctran.c:907`, `optran.c:818`, `dcpss.c:1401`), and — dead in practice, see §9.3 — through `ft_sim->nonconvErr` (`src/ngspice.c:68`).

Grammar:
```
<ANALYSIS>:  [<optmsg>; ]<domain phrase><cause>
```
* `<ANALYSIS>` is `analInfo[JOBtype]->if_analysis.name`: `options`, `AC`, `DC`, `OP`, `TRAN`, `PZ`, `TF`, `DISTO`, `NOISE`, `SENS`, (`PSS`), (`SP`, `HB`). (`ckttroub.c:27`, `:30-33`)
* domain phrase (`ckttroub.c:37-78`):
  * `TIMEDOMAIN` (TRAN, PSS): `initial timepoint: ` if `CKTtime == 0`, else `time = %g, timestep = %g: `
  * `FREQUENCYDOMAIN` (AC, NOISE, DISTO, SP): `frequency = %g: ` (`CKTomega/2π`)
  * `SWEEPDOMAIN` (DC): one ` <name> = <value>: ` clause per nest level, formatted per sweep type — voltage source `VSRCdcValue`, temperature `CKTtemp - CONSTCtoK`, resistor `RESresist`, else current source `ISRCdcValue` (`:57-72`)
  * `NODOMAIN` (OP, TF, PZ): nothing
* cause (`ckttroub.c:82-90`):
  * `trouble with node "<nodename>"` when `CKTtroubleNode` is set (from `NIconvTest`, `niconv.c:63`/`:75`)
  * `trouble with <ModelName>-instance <InstanceName>` when `CKTtroubleElt` is set (from a device `DEVconvTest`)
  * `cause unrecorded.` otherwise — which is what you get whenever the failure was **LTE-driven** rather than convergence-driven, because `CKTload` clears `CKTtroubleNode` on every non-convergent device load (`cktload.c:80-81`) and `CKTdoJob` clears both at the start of a run (`cktdojob.c:107-108`).

The string ends up in the global `errMsg`, which `INPerror()` consumes in preference to the generic `SPerror()` text (`src/spicelib/parser/inperror.c:24-29`), and `ft_sperror()` prints as `"%s: %s\n"` with the caller's routine name (`src/frontend/error.c:57-62`), giving the `doAnalyses: TRAN:  Timestep too small; …` line seen above.

### 9.2 Simulator error codes and their canonical strings

`src/include/ngspice/sperror.h` + `src/include/ngspice/iferrmsg.h`; text table `src/spicelib/parser/sperror.c:18-120`.

| Code | Value | Text | Where raised in this area |
|---|---|---|---|
| `OK` | 0 | (NULL) | |
| `E_PAUSE` | −1 | `pause requested` | `dctran.c:455-458` (`IFpauseTest`), `dctrcurv.c:470-474` |
| `E_INTERN`/`E_PANIC` | 1 | `impossible error - can't occur` | `niiter.c:352-359` bad `INITF` state |
| `E_NOMEM` | 8 | `out of memory` | `cktic.c:45, 68` |
| `E_BADMATRIX` | 101 | `matrix can't be decomposed as is` | `SMPreorder`/`SMPpreOrder` |
| `E_SINGULAR` | 102 | `matrix is singular` | `niiter.c:126-145`, `:196-217`, `:219-240` |
| `E_ITERLIM` | 103 | `iteration limit reached` | `niiter.c:271-285`; `cktop.c:653` (source stepping); `evtop.c:197`; `evtiter.c:294` |
| `E_ORDER` | 104 | `unsupported integration order` | `ckttrunc.c:367`, `niinteg.c:36-39`, `nipred.c` |
| `E_METHOD` | 105 | `unsupported integration method` | `ckttrunc.c:420-421`, `niinteg.c:72-75`, `cktsopt.c:146` |
| `E_TIMESTEP` | **106** | `timestep too small` | `dctran.c:913`, `optran.c:820`, `dcpss.c` — and the literal `106` is hard-coded in `cktop.c:98` |

### 9.3 `where` is broken — do not build on it

`src/frontend/where.c:17-45`:
```c
if (!ft_curckt) { fprintf(cp_err, "There is no current circuit\n"); return; }
else if (ft_curckt->ci_ckt != NULL) { fprintf(cp_err, "No unconverged node found.\n"); return; }
msg = ft_sim->nonconvErr (ft_curckt->ci_ckt, NULL);   /* only reachable when ci_ckt == NULL */
printf("%s", msg);
```
The condition is inverted: whenever a circuit *is* loaded (the only case that matters) it short-circuits with `No unconverged node found.`, and the `CKTtrouble` call is only reachable with a NULL circuit, where `nonconvErr` returns NULL and `printf("%s", NULL)` is undefined.
**[verified]** after a deliberately failing `op`, `where` prints exactly `No unconverged node found.`
Command table entry (advertising what it *should* do): `src/frontend/commands.c:487-490` — `": Print last non-converging node or device"`.
**Implication:** ASE-L cannot ask ngspice "which node failed?" It must scrape `CKTncDump`'s starred rows (§4.4) and the `Warning: singular matrix: check node …` lines. Fixing `where.c` upstream (one character) would be a very high-leverage contribution.

### 9.4 SOA (safe operating area) checking

* Enabled by the **control variable** `set warn=1` (or `2` for the stricter VBIC checks, `src/spicelib/devices/vbic/vbicsoachk.c:92`), read at circuit load: `src/frontend/inp.c:1447-1450`. Not an `.options` entry.
* `set maxwarns=N` caps warnings per check kind, default **5** (`inp.c:1452-1455`).
* Counters are reset per analysis (`CKTsoaInit()` at `dcop.c:141-142`, `dctran.c:190-191`); checks run at each accepted transient point (`dctran.c:379-380`), at each DC sweep point (`dctrcurv.c:427-428`) and after the OP (`dcop.c:201-202`).
* Format (`src/spicelib/devices/devsup.c:833-852`), to **stdout** unless the `--soa-log <file>` command-line option redirected it (`devsup.c:831, 836`):
  ```
  Instance: <name> Model: <model> Time: <t> <specific message>
  Instance: <name> Model: <model> <specific message>     (non-transient)
  ```
  Example specific messages (`src/spicelib/devices/dio/diosoachk.c:48-68`): `Vd=%.4g V has exceeded Fv_max=%.4g V`, `Vd=… has exceeded Bv_max=…`, `Id=%.4g A at Vd=%.4g V has exceeded Id_max=%.4g A`.

### 9.5 Other messages a run can emit in this area

| Message | Stream | Anchor |
|---|---|---|
| `Doing analysis at TEMP = %f and TNOM = %f` | stdout | cktdojob.c:122 |
| `Note: Voltage based truncation error correction selected` | stdout | cktdojob.c:126 |
| `Reducing trtol to 1 for xspice 'A' devices` / `Override trtol to %d …` | stdout | cktdojob.c:84, 88 |
| `Using SPARSE 1.3 as Direct Linear Solver` / `Using KLU …` | stdout | (solver announce) |
| `Initial Transient Solution` table | stdout | dctran.c:251-262; suppressed by `set noacct`/`set noinit` |
| `Operating point simulation skipped by 'uic', now using transient initial conditions.` | stdout | dctran.c:247-250 |
| `\nError: Finding the operating point for transient simulation failed \n` | stderr | dctran.c:243 |
| `Note: Autostop after %e s, all measurement conditions are fulfilled.` | stdout | dctran.c:449 |
| `error: circuit reload failed.` | stderr | dcop.c (`:204` of the file) |
| `WARNING - Rshunt option too small.  Ignored.` | stderr | cktsopt.c:250 |
| `WARNING - Option Rshunt available only with XSPICE enabled.` | stderr | cktsopt.c:255 |
| `Warning -- Option maxord < 1 not allowed in ngspice\nSet to 1` / `> 6 … Set to 6` | stderr | cktsopt.c:128, 132 |
| `Warning: option %s is currently unsupported.` / `… is obsolete.` | stderr | spiceif.c:514, 519 |
| `Pole-zero iteration limit reached; giving up after %d trials` | stderr (`Warning:`) | cktpzstr.c:226 |
| `Warning: KLU ReFactor failed. Factoring again...` | stderr, `set ngdebug` only | niiter.c:170 |
| `(debug printing enabled)` | stderr | outitf.c:207-208 (when `printinfo` is set) |
| `Simulation parameter "%s" can't be set until\na circuit has been loaded.` | stderr | spiceif.c:564-566 |

### 9.6 Compile-time-only diagnostics (not available in this build)

`STEPDEBUG` (`--enable-stepdebug`, `configure.ac:253-255`) unlocks a very rich per-step trace that a GUI would love: `delta cut to %g for non-convergence`, `delta set to truncation error result: point rejected`, `delta at delmin`, `delta cut to %g to hit breakpoint`, `limited by Tstop/50` / `limited by Tmax == %g`, `throwing out permanent breakpoint times <= current time`, `timestep cut by device type %s from %g to %g` (`ckttrunc.c:246-251`), `device type %s nonconvergence` (`cktload.c:83-88`), `chk for convergence: %s new: %g old: %g` and the full tolerance breakdown (`niconv.c:33-39`, `:59-62`, `:71-74`). **Off by default** (`config.h:561`). Worth telling users that a `--enable-stepdebug` build is the deep-debug mode.

---

## 10. Complete option reference for this area

Names from `OPTtbl[]` (`src/spicelib/analysis/cktsopt.c:264-385`); defaults from `CKTnewTask()` (`src/spicelib/analysis/cktntask.c:93-145`) unless noted.

### 10.1 Convergence / OP

| Option | Type | Default | Field | Notes |
|---|---|---|---|---|
| `noopiter` | flag | 0 | `CKTnoOpIter` | skip rung 1 |
| `gmin` | real | `1e-12` | `CKTgmin` | per-junction conductance inside device models |
| `gshunt` | real | `0` | `CKTgshunt` | conductance added to **every** matrix diagonal after stepping ends (`LoadGmin`) |
| `cshunt` | real | `-1` | `CKTcshunt` | **not** applied by the solver — `.option cshunt=val` is intercepted in the front end (`src/frontend/inp.c:428-486`), stored in `cshunt_value`, and pass 4 of the parser *inserts real capacitors* on every node (`src/spicelib/parser/inppas4.c:27-93`, stdout `Option cshunt: %d capacitors added with %g F each`) |
| `gminsteps` / `itl6` alias `srcsteps` | int | `1` each | `CKTnumGminSteps` / `CKTnumSrcSteps` | `0` = off, `1` = adaptive algorithm, `>1` = SPICE3 fixed-step |
| `gminfactor` | real | `10` | `CKTgminFactor` | per-step ratio; ignored inside `gillespie_src`'s internal decade sweep |
| `itl1` | int | `100` | `CKTdcMaxIter` | OP Newton limit; floored at 100 |
| `itl2` | int | `50` | `CKTdcTrcvMaxIter` | **also the per-step limit inside gmin/source stepping**; floored at 100 ⇒ default is inert |
| `itl4` | int | `10` | `CKTtranMaxIter` | per-timepoint transient limit; floored at 100 ⇒ default is inert |
| `itl3`, `itl5` | int | — | — | parsed, **do nothing** (`cktsopt.c:83-89`) |
| `nodedamping` | flag | 0 | `CKTnodeDamping` | hard-coded 10 V / 0.1 thresholds |
| `absdv`, `reldv` | real | `0.5`, `2.0` | `CKTabsDv`, `CKTrelDv` | **read by nothing** |
| `pivtol` | real | `1e-13` | `CKTpivotAbsTol` | |
| `pivrel` | real | `1e-3` | `CKTpivotRelTol` | |
| `noopac` | flag | 0 | `CKTnoopac` | skip the OP for `.ac`/`.noise` **only if the circuit is linear** (`cktdojob.c:109` `&& ckt->CKTisLinear`); stdout `\n Linear circuit, option noopac given: no OP analysis` (`acan.c:146`) |
| `keepopinfo` | flag | 0 | `CKTkeepOpInfo` | dump the OP as its own plot before a small-signal analysis (`acan.c:155-...`) |
| `copynodesets` | flag | 0 | `CKTcopyNodesets` | see §1.6 |
| `oldlimit` | flag | 0 | `CKTfixLimit` | SPICE2 MOSFET limiting |
| `bypass` | int | 0 | `CKTbypass` | device reload bypass; `--enable-nobypass` removes it |
| `epsmin` | real | `1e-28` | `CKTepsmin` | floor for `log()` in device models |

### 10.2 Timestep / integration

| Option | Type | Default | Field |
|---|---|---|---|
| `method` | string | `trap` | `CKTintegrateMethod` (only `trap*`/`gear`) |
| `maxord` | int | `2` (clamped 1..6) | `CKTmaxOrder` (effectively 1 vs ≥2) |
| `xmu` | real | `0.5` | `CKTxmu` |
| `trtol` | real | `7.0` | `CKTtrtol` |
| `reltol` | real | `1e-3` | `CKTreltol` |
| `abstol` | real | `1e-12` | `CKTabstol` |
| `vntol` | real | `1e-6` | `CKTvoltTol` |
| `chgtol` | real | `1e-14` | `CKTchgtol` |
| `minbreak` | real | 0 ⇒ auto (§6.3) | `CKTminBreak` |
| `newtrunc` | flag | 0 | `CKTnewtrunc` — needs `--enable-predictor` |
| `ltereltol`, `lteabstol`, `ltetrtol` | real | `1e-3`, `1e-6`, `500.` | only used when `newtrunc` |
| `trytocompact` | flag | 0 | `CKTtryToCompact` (LTRA lines) |
| — (`delmin`) | — | `1e-11*tmax` | `CKTdelmin` — **not settable**, printed by `option` |

### 10.3 Temperature

| Option | Type | Default | Notes |
|---|---|---|---|
| `temp` | real, °C | `27` | `IF_SET|IF_ASK`; `+CONSTCtoK` |
| `tnom` | real, °C | `27` | `IF_SET|IF_ASK`; `+CONSTCtoK` |

### 10.4 XSPICE-only (present in this build)

| Option | Type | Default | Notes |
|---|---|---|---|
| `rshunt` | real Ω | off | adds `1/rshunt` to every analog node's diagonal at load time (`cktload.c:109-115`; setup at `cktsetup.c`); rejects values `<= 1e-30` |
| `ramptime` | real s | `0` | linear supply ramp `CKTtime/ramptime` applied to V/I/B sources (`src/spicelib/devices/vsrc/vsrcload.c:467`, `isrc/isrcload.c:450`, `asrc/asrcload.c:56`) and to opted-in code models via `cm_analog_ramp_factor()` (`src/xspice/cm/cm.c:498-523`); plants a breakpoint at `ramptime` (`dctran.c:220-221`); active in `MODETRANOP|MODETRAN` only |
| `convlimit` | flag | off | enable per-iteration input-step limiting on code models |
| `convstep` | real | — | fractional step limit (implies `convlimit`) — `src/xspice/mif/mifload.c:357-376` |
| `convabsstep` | real | — | absolute step limit (implies `convlimit`) |
| `maxopalter` | int | `num_hybrid_outputs+1` | §4.7 |
| `maxevtiter` | int | `num_outputs+1` | §4.7 |
| `noopalter` | flag | off | §4.7 |
| `autopartial` | flag | off | auto-partial derivatives for all code models |

### 10.5 KLU-only (present in this build)

`sparse` (flag), `klu` (flag), `klu_memgrow_factor` (real, default 1.2). **Bug:** `klu_memgrow_factor` assigns a *boolean* — `task->TSKkluMemGrowFactor = (val->rValue == 1.2);` (`cktsopt.c:186-188`) — so any value other than exactly 1.2 sets the factor to 0.

---

## 11. Control-language variables that change convergence (NOT `.options`)

These are `set`/`unset` variables. A GUI must emit them in a `.control` block or `.spiceinit`, not on an `.options` card.

| Variable | Effect | Anchor |
|---|---|---|
| `ngdebug` | turns the ladder trace, per-nan warnings, unlimited singular-matrix messages, `set nostepsizelimit` echo, and transient progress printing on | `src/frontend/options.c:355-356`; consumed at `cktop.c:194` etc. |
| `nginfo` | extra informational output | options.c:357-358 |
| `printinfo` | **suppresses** all `ERR_INFO` (`Note:`) messages; also prints `(debug printing enabled)` at plot start | outitf.c:1744, 1777, 207 |
| `strict_errorhandling` | `controlled_exit(1)` instead of continuing after a failed OP (`cktop.c:111-112`) and after topology reduction (`cktsetup.c:245-250`) | options.c:375-381 |
| `dyngmin` | if set, only `dynamic_gmin` runs (skips `new_gmin`) | cktop.c:60-70 |
| `xtrtol` (num) | overrides the automatic `trtol → 1` reduction for XSPICE `A` devices | cktdojob.c:83-85 |
| `nostepsizelimit` | `tmax` defaults to `(tstop-tstart)/50` instead of `tstep` | traninit.c:30 |
| `topo_reduce` | enable dangling-passive pruning (§6.8) | cktsetup.c:72 |
| `autostop` | end a `.tran` as soon as all `.meas` conditions are met; disabled automatically if a `.meas` uses `max|min|avg|rms|integ` (`inp.c:1143-1153`) | dctran.c:200, 430-449 |
| `warn` (num), `maxwarns` (num) | SOA checking, §9.4 | inp.c:1447-1455 |
| `num_threads` (num) | OpenMP device-load threads | cktsetup.c |
| `interp` | interpolated rawfile output — prints `Warning: Interpolated raw file data!` | outitf.c:211-213 |

---

## 12. Source-vs-documentation disagreements and dead knobs

Everything here is "trust the source"; each item was read in this tree and, where marked, reproduced.

1. **`maxord` above 2 does nothing** in `.tran`/`.pss`/`optran` (§6.2). Documentation and every SPICE reference say Gear 2–6.
2. **`itl1`/`itl2`/`itl4` below 100 do nothing** (`niiter.c:38-39`). The shipped defaults 50 and 10 are already below the floor.
3. **`absdv` and `reldv` are wired to nothing** (§5.4).
4. **`itl3` and `itl5` are accepted and ignored** (`cktsopt.c:83-89`); `spiceif.c:446-453` also lists them as "currently unsupported", but that list is unreachable for them.
5. **`newtrunc`, `ltereltol`, `lteabstol`, `ltetrtol` are inert** without `--enable-predictor` (§6.5). **[verified]**
6. **`where` always answers "No unconverged node found."** (§9.3). **[verified]**
7. **`optran`'s `uic` suffix is parsed and dropped**; **supply ramping oscillates past the ramp time**; **the README's auto-sizing heuristic is `#if 0`-ed** (§7.6).
8. **`printinfo` suppresses notes** despite its name (`outitf.c:1744, 1777`).
9. **`option` prints temperatures in kelvin** while every input is celsius (`com_option.c:33-34`). **[verified]**
10. **`.temp` silently degrades a multi-value list to 27 °C** (§8.2). **[verified]**
11. **`minbreak`'s auto-default differs by 5.7 orders of magnitude between XSPICE and non-XSPICE builds** (§6.3).
12. **`OPT_DEFAS` writes `TSKdefaultMosAD`** — `.options defas=` silently sets *defad* (`cktsopt.c:111-113`). Not convergence, but it is in the same table.
13. **`klu_memgrow_factor` stores a boolean** (`cktsopt.c:186-188`).
14. **`ENHreport_conv_prob` from analog code models is dead**: `ckt->enh->conv_debug.report_conv_probs` is declared (`src/include/ngspice/enh.h:67`) and tested (`mifconvt.c:128`, `mifload.c:371`) but never assigned `MIF_TRUE` anywhere in the tree. Only the event-side calls (`evtop.c:191`, `evtiter.c:286`) actually fire.
15. **`cktop.c:98` compares against the literal `106`** rather than `E_TIMESTEP`. Cosmetic, but a hint the surrounding code is fragile.

---

## 13. Implications for the ASE-L GUI

1. **The OP convergence ladder is the headline feature.** Give it a dedicated panel with four toggles (Newton / gmin stepping / source stepping / transient OP) plus `gminfactor`, `gminsteps`, `srcsteps`, `optran step`, `optran stop`. Emit a single `optran a b c step stop 0` line — it supersedes `.options noopiter/gminsteps/srcsteps` and is strictly more expressive. This is something ADE does not present at all.
2. **Make `.ic` vs `.nodeset` vs `uic` a three-way widget with the semantics spelled out on screen**, because the behaviour is genuinely counter-intuitive: `.nodeset` = hint (always released), `.ic` = hint for `.op`/`.ac`/`.dc` but a *hard clamp* for the transient OP, `uic` = skip the OP entirely and let device `ic=` win. Show which one is winning per node.
3. **Add a live "convergence status" pane driven by stderr.** The parseable state machine is `Note: Starting dynamic gmin stepping` → `Note: Starting true gmin stepping` → `Note: Starting spice3 gmin stepping` → `Note: Starting source stepping` → `Note: Transient op started`, with `Warning: … failed` / `Note: … completed` verdicts. Turning on `set ngdebug` upgrades this to a per-step `Trying gmin = …` / `Supplies reduced to …%` progress bar. Two parser rules are mandatory: those two `ngdebug` lines have **no trailing newline**, and stderr/stdout are separately buffered so they must be captured as **two ordered streams**, never merged.
4. **Surface `CKTncDump`'s starred rows as a first-class failure report.** `where` is broken (§9.3), so the `Last Node Voltages` table (with ` *` on each still-unconverged node) plus `Warning: singular matrix: check node X` are the only machine-readable "who failed" signals ngspice produces. Parse both, map node names back to schematic nets, and highlight them on the canvas. That single feature would put ASE-L ahead of ADE's opaque `sim.log`.
5. **Temperature needs an owned sweep loop.** Only `.dc temp start stop step` is declarative; for `.tran`/`.ac`/`.noise`/`.op` the GUI must generate the `foreach`/`set temp`/`run` scaffolding and collate the plots itself. Also normalise the units: input °C everywhere, and never show the kelvin figure that bare `option` reports.
6. **Hide or grey out the knobs that do nothing in this build**: `absdv`, `reldv`, `itl3`, `itl5`, `newtrunc`+lte* (unless `--enable-predictor`), and `maxord > 2`. Clamp `itl1`/`itl2`/`itl4` inputs to ≥100 with a tooltip explaining the floor at `niiter.c:38`.
7. **"Timestep too small" needs a remedy wizard, not an error dialog.** The ordered lever list is in §6.7; the top three are `tmax` (which is the *only* way to move `delmin`), `trtol`, and `method=gear`/`xmu=0.49`. Add `set topo_reduce` as a one-click fix for the dangling-passive class of failure, since it is off by default and its console message names the offending element.
8. **Read state back from `option` (no args), not from your own model.** Options only reach `ckt` at the start of the next run (`cktdojob.c:52-120`), so a settings panel that echoes its own values will lie. Run `option` after a `run` to confirm.
9. **Do not rely on progress callbacks with a spawned binary.** `HAS_PROGREP` is only defined for the Windows GUI and `libngspice`; a console-driven GUI must scrape text. If ASE-L ever links `libngspice`, `SetAnalyse` gives `"op"`, `"tran"`, `"tran init"`, `"optran init"`, `"optran"`, `"dc"`, `"sp"`, `"shooting"`, `"ptran"`, `"meas"`, `"Parse"`, `"Device Setup"` and `--ready--` strings for free (`src/sharedspice.c:2046-2090`).

---

## 14. Gaps / things another agent must confirm

* I could not fetch the `.options` reference chapter of the official manual (the HTML manual truncates before §11.1.1), so the documented defaults for most options are unverified against the source table in §10. The two documentation facts I *did* confirm are ".temp will override .options temp" and `.dc temp 25 49 2`, from https://ngspice.sourceforge.io/docs/ngspice-html-manual/manual.xhtml
* The `OPtran`-with-`CKTdelmin == 0` hang risk for `.op`/`.ac` jobs (§7.6 item 5) is an inference from `optran.c:814-822` + `cktdojob.c:75`; I did not construct a deck that triggers it.
* I did not exercise the XSPICE `EVTop` alternation limits (`maxopalter`/`maxevtiter`) or `rshunt`/`convlimit` on a real code-model deck; those sections are source-read only.
* `.pss` (`dcpss.c`) has its own copy of the transient loop with `steady_coeff` and shooting-method convergence; it is `--enable-pss`-gated and **off** in this tree, so I only skimmed it.
* CIDER (`src/ciderlib/`) has its own 2-D device convergence machinery and its own `.options`; it is off in this tree and out of scope here.
* I did not chase how `bypass` interacts with convergence in individual device models (`CKTbypass` is consumed inside `*load.c` files), nor `oldlimit`/`fixLimit` MOSFET limiting.
* `dctrcurv.c`'s HSPICE-compatibility branch (`newcompat.hs`, `dctrcurv.c:297-304`) changes the DC sweep to run the whole `CKTop` ladder at every point; I did not test which `set ngbehavior=` values enable it.
* Whether ASE-L will drive the `ngspice` executable or link `libngspice` decides §13 items 3 and 9; that decision has not been made in the material I was given.
