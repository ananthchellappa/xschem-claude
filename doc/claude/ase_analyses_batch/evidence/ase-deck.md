# ASE-L deck renderer and run pipeline — dossier

**Area:** `ase::backend::ngspice` in `/home/analog/dev/xschem-claude/src/ase.tcl`, plus the run
pipeline (`ase::run*`) and the capability-probe machinery (`ase::cap_*` / `ase::sim_capabilities*`).

**Anchor convention.** `ase.tcl:NNNN` and `ase_window.tcl:NNNN` are
`/home/analog/dev/xschem-claude/src/…`. `xschem.tcl:NNNN` is the same directory.
Bare `src/…` paths are `/home/analog/dev/ngspice/…`. Line numbers are as of
xschem-claude branch `fluid-editing` at the time of writing and ngspice `ver_50`
(`ngspice-46-419-gccebdf2a2`).

**Measurements labelled MEASURED-HERE** were taken by me on 2026-09-09 against
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (banner: `ngspice-46+`), in the scratchpad,
read-only against both repos. Everything else labelled "measured" is quoted from the source
comments, which carry their own measurement receipts.

---

## 0. Executive summary for the future session

ASE-L today renders **exactly four analyses** — `op`, `dc`, `ac`, `tran` — as **commands inside a
single `.control` block**, in a fixed order, each followed by a fixed five-line epilogue
(status guard, `remzerovec`, `write`, optionally the print block). Everything *around* the
analyses (includes, libs, params, options, temp, saves, pre-commands, cosim bridges) is a
generic, schema-driven emission that already scales. The analysis loop itself is the only part
that is hard-wired to four types, and it is hard-wired in **five** distinct places, three of
which are in the deck renderer and two in the GUI.

The good news: the deck-level architecture (one `.control` block, `set appendwrite`, one `write`
per analysis, a per-analysis status guard, results read back **by plot name**) is exactly the
architecture a 10+ analysis GUI needs. The bad news, and the thing a future session must design
for up front: **the "one write per analysis" invariant assumes one analysis produces one plot,
and that is false for `noise` and `disto`** (MEASURED-HERE, §7.4).

---

## 1. `render_deck` — the exact emission order

`proc ase::backend::ngspice::render_deck {state netlist_text}` — `ase.tcl:10521`, ends
`ase.tcl:11014`. Registered as the `render_deck` hook at `ase.tcl:11737`.

The proc's own header comment (`ase.tcl:10515-10520`) states the contract:

> Render the simulation deck: the circuit netlist minus its trailing `.end`
> (spice_netlist.c emits it last for top-level .spice netlists), then
> .include files, .lib models, .param variables, .options, .save outputs, one
> .control block from the enabled analyses in fixed order (op, dc, ac, tran) +
> a print per saved output for log-based result probing, then .end + trailing newline.

It builds a Tcl list `lines` and returns `"[join $lines "\n"]\n"` (`ase.tcl:11013`). It never
writes a file; `ase::run_deck` owns the file (`ase.tcl:7297-7300`).

### 1.1 The emission order, step by step

| # | line(s) | what is emitted | why / notes |
|---|---|---|---|
| 1 | `10522-10528` | the circuit netlist verbatim, **minus trailing blank lines and minus a trailing `.end`** | `spice_netlist.c` emits `.end` last for top-level `.spice` netlists; it has to come off so the deck can append to it |
| 2 | `10529-10538` | `ase::cosim_rewrite` rewrites any `.model <m> d_cosim` card in place | spec E2: gives each `d_cosim` model a per-run VCD path. `sim_args[0]` is what the shim opens. **Inert for any analog deck** (`cosim_map` returns `{}`) |
| 3 | `10539-10551` | `.include <path>` per `includes` row | **before** `.lib` deliberately: "so any global .params they define … are in scope when the models evaluate" (`ase.tcl:10540-10543`) |
| 4 | `10552-10554` | `.lib <file> <section>` per `models` row | `ase::expand_path` applies the `$::VAR` expansion contract |
| 5 | `10555-10557` | `.param <name>=<value>` per `variables` row | |
| 6 | `10558-10568` | `.options <name>` (value `1`) or `.options <name>=<v>`; value `0` skips the row entirely | tri-state: `0`=omit, `1`=bare flag, else `name=value` |
| 7 | `10569-10575` | `.options savecurrents` when `save_all_i` is 1 | "a duplicate line from an explicit `savecurrents` options row above is harmless to ngspice" (`10571-10572`) |
| 8 | `10576-10583` | `.temp <T>` — **always emitted**, default 27 | "default 27 (= ngspice's own default)". Non-numeric raises `-code error` at `10581`. The default is set in the **state schema**, `ase::state_default`, `ase.tcl:509` (`temperature 27`) |
| 9 | `10584-10588` | `.save all` when `save_all_v` is 1 | UI v2 "Save All voltages" blanket |
| 10 | `10589-10593` | `.save <expr>` per `outputs` row whose `save` is 1 | |
| 11 | `10594-10795` | **the op_annot device-OP save block** — a five-way `switch` on `ase::op_save_tier`'s answer, emitting `.save all` plus either deck-level cards, `optier_ctl` (in-`.control` `save` commands), `optier_write` (names for the OP `write` line) or `optier_post` (a post-`op` `show` dump) | see §3 |
| 12 | `10797` | `.control` | **the only `.control` block in the deck** |
| 13 | `10798-10810` | the `pre_commands` rows, verbatim (`$::VAR`-expanded) | "`pre_*` first, before anything that could need the modules they load. Position inside the block does not actually matter — ngspice runs every pre_ command before parsing the netlist, probe-verified on ngspice-46 with psp103.osdi in this trailing block — but first reads as what it is" (`10798-10802`) |
| 14 | `10811-10823` | `ase::cosim_default_bridges` — the adc/dac `pre_set` auto-bridge configuration | only when the deck really has a code block **and** the state configures no bridge of its own; `cosim bridges 0` opts out |
| 15 | `10844` | `set appendwrite` — **only when ≥ 1 analysis is enabled** | issue 0929; see §2.1 |
| 16 | `10845-10867` | (computation only) `set anorder {op dc ac tran}` at `10867`, flipped to `{dc ac tran op}` at `10946` when device requests moved inside `.control` | see §2.2 |
| 17 | `10868-10943` | (computation only) `printlines` (a `print` per saved output, `10879-10883`) and `printanchor` (`10933-10942`) | see §2.3 |
| 18 | `10947-10999` | **the analysis loop**: for each type in `anorder`, for each matching enabled row, emit the analysis + its epilogue | see §2 |
| 19 | `11000-11005` | the `print` lines, if the anchor never fired (no enabled analysis) | "A deck with no enabled analysis at all still carries its print lines, in the one place there is for them" |
| 20 | `11011` | `.endc` | |
| 21 | `11012` | `.end` | |
| 22 | `11013` | join + a **trailing newline** | |

### 1.2 A concrete golden

`tests/headless/test_ase_core.tcl:373-403` holds the committed byte-exact golden for a
single-`op` state. Reproduced here because it is the clearest statement of the shape:

```
** sch_path: /fixture/nfet_clean.sch
**.subckt nfet_clean
XM1 D G GND GND sky130_fd_pr__nfet_01v8 L=0.15 W=1 ...
V1 D GND 1
V2 G GND 1.8
**.ends
.GLOBAL GND
.lib /models/sky130.lib.spice tt
.param Vgs=1.8
.param Vds=1.0
.options savecurrents
.temp 27
.save -i(v1)
.control
set appendwrite
op
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
write <rundir>/nfet_clean_ase.raw
print -i(v1)
.endc
.end
```

Two committed byte-exact deck goldens exist (`test_ase_core.tcl` D1 and
`test_ase_final{,_gf180}.tcl`). Row E12 of `tests/headless/test_ase_optier_0963.tcl` is the
"renders byte-identically" guard that every change to this proc must keep green for decks that
carry no in-`.control` device requests (`ase.tcl:10850-10852`).

---

## 2. Per-analysis emission, exactly as it is today

### 2.1 The analysis loop

`ase.tcl:10945-10999`.

```tcl
set printsdone 0
if {[llength $optier_ctl] || [llength $optier_post]} { set anorder {dc ac tran op} }
foreach type $anorder {
  set ai -1
  foreach a [ase::state_get $state analyses] {
    incr ai
    if {[ase::state_get $a type] ne $type} { continue }
    if {[ase::state_get $a enabled 0] ne {1}} { continue }
    if {$type eq {op}} { foreach opsl $optier_ctl { lappend lines $opsl } }
    switch -- $type {
      op   { lappend lines "op" ; foreach opsl $optier_post { lappend lines $opsl } }
      dc   { lappend lines "dc $source $start $stop $step" }
      ac   { lappend lines "ac dec $points $start $stop" }
      tran { lappend lines "tran $step $stop" }
    }
    foreach g [::ase::backend::ngspice::sim_status_guard] { lappend lines $g }
    lappend lines "remzerovec"
    if {$type eq {op} && [llength $optier_write]} {
      lappend lines "write [raw_file $state] all [join $optier_write { }]"
    } else {
      lappend lines "write [raw_file $state]"
    }
    if {[list $type $ai] eq $printanchor} { foreach pl $printlines { lappend lines $pl } ; set printsdone 1 }
  }
}
```

Note the loop is **type-major, row-minor**: it iterates the four types in `anorder` and inside
each type scans the whole `analyses` list. Consequences:

* **more than one row of the same type is allowed and all of them are emitted** — the state
  schema does not enforce uniqueness, and the pane keeps extra rows X-deletable
  (`ase_window.tcl:4452-4459`, "The FIRST state row of `type` … extra same-type rows stay
  X-deletable in the pane"). Only the *first* row of a type is reachable from the Choose
  Analyses dialog.
* the **state list order is ignored**; `anorder` decides.
* a row with an unrecognised `type` is emitted by nothing and reported by nothing.

### 2.2 The four cards, argument by argument

| type | emitted line | source line | argument assembly | defaults |
|---|---|---|---|---|
| `op` | `op` | `10954` | no arguments at all | — |
| `dc` | `dc <source> <start> <stop> <step>` | `10962-10963` | `[dict get $a source]`, `start`, `stop`, `step` — **bare `dict get`, no default, no validation** | none. A missing key is a Tcl error out of `render_deck` |
| `ac` | `ac dec <points> <start> <stop>` | `10964-10965` | `points`, `start`, `stop` | **`dec` is a hard-coded literal.** The `dec` key exists in the arg schema (`ase_window.tcl:83`, `anaargs … ac {points start stop dec}`) but is **never read by the renderer** — it round-trips in the state file and shows in the Arguments summary and nowhere else. `ase_window.tcl:4439-4440` says so: "`dec` for ac is render-hardwired and only reachable through the extra-options editor" |
| `tran` | `tran <step> <stop>` | `10966` | `step`, `stop` | none. **No `tstart`, no `uic`, no `tmax`** — ngspice's `tran tstep tstop [tstart [tmax]] [uic]` is only half-exposed |

**Every one of these is a `.control` COMMAND, never a dot-card.** There is no `.op`/`.dc`/`.ac`/
`.tran` card anywhere in the rendered deck, and there is no `run` command either.

Validation happens in the GUI, not here: `ase::ui::chana_ok` (`ase_window.tcl:4522-4548`) refuses
OK when an *enabled* analysis has an empty quick field, with the comment "else `render_deck`'s
`dict get` would blow up at run time".

### 2.3 The per-analysis epilogue

Emitted after **every** analysis, in this order and for these reasons:

1. **`sim_status_guard`** (`ase.tcl:10978`, proc at `ase.tcl:11122-11132`) — seven lines:
   ```
   if $?sim_status = 0
     echo NO-SIM-STATUS
   end
   if $sim_status ne 0
     echo RUN-FAILED
     quit 1
   end
   ```
   From the proc header (`ase.tcl:11086-11121`), MEASURED 2026-08-17 on both
   `/usr/local/bin/ngspice` 46 and `build-ver_50`: a bad run (a `.save` of a node that does not
   exist) → `rc=1`, `RUN-FAILED` on stdout, **and no results file at all**; a good run → `rc=0`
   and the real raw. Two traps recorded there:
   * `$sim_status` does not exist before the first analysis, and on a build with no such variable
     the guard is inert — `NO-SIM-STATUS` in the log says so out loud. `Error: sim_status: no
     such variable.` is printed at *parse* time whether or not the `$?` test is present, so the
     `$?` block is a **marker, not an error suppressor**.
   * it is **last-writer-wins per analysis**, so **one guard at the end is the defect, not the
     fix**: measured with a failing `dc` followed by a good `tran`, a single trailing guard gave
     `rc=0` and a 2198-byte raw with the failure completely masked; a guard after each gave
     `rc=1`, `RUN-FAILED`, no file.
   * it **must precede the `write`** (`ase.tcl:10971-10975`): "placed after the write it would
     report the failure and ship the bad raw anyway".

2. **`remzerovec`** (`ase.tcl:10980-10984`) — "`.options savecurrents` leaves zero-length
   `@m...[ib]`-class vectors in the plot and ngspice's write then aborts SILENTLY
   (probe-verified, ngspice-42). It is per-PLOT, so one call at the end would only ever have
   cleaned the last analysis's."

3. **`write <rawfile>`** (`ase.tcl:10985-10993`) — no vector list, so it writes the current
   plot's saved vectors. The one exception is op-tier `b`, which appends
   `all <bare device names>` (see §3).

4. **the `print` lines**, only on the anchor row (§2.4).

### 2.4 Where the `print` lines go — two rulings stacked

`printlines` is built at `ase.tcl:10879-10883`: one `print [print_arg <expr>]` per output row whose
`save` is 1.

`print_arg` (`ase.tcl:11163-11167`, header `11149-11162`): a bracketed expression is
double-quoted, because "ngspice's expression parser reads the `[0]` in `print a[0]` as a
SUBSCRIPT of a vector named `a`, so a bus-bit name prints nothing at all … `print "a[0]"` prints
`"a[0]" = 1.500000e+00`". The `.save` side is unaffected.

`printanchor` (`ase.tcl:10933-10942`) is computed from the **enabled set alone**, walking
`{dc ac tran op}` and taking last-enabled-wins — i.e. `op` if `op` is enabled, else the last of
`dc ac tran` that is:

* **issue 0967** (`ase.tcl:10869-10884`) established that the emit order may not move the prints:
  a checkbox about *device* parameters must not silently change which analysis the Outputs Value
  column reports.
* **issue 1243** (`ase.tcl:10885-10932`), RULED BY THE USER 2026-09-02, settled *which* analysis:
  the operating point, whenever one is enabled. Reason given: `result_probe` accepts
  `<expr> = <number>` and nothing else, and `print` on a multi-point plot emits a paged
  `Index time vbg` table — "measured on the user's own run log, 20,514 rows per printed output
  and 108,275 log lines for five of them, from which `result_probe` extracts exactly nothing".
* **transient-only is deliberately blank**, recorded as an open `rule` debt rather than guessed:
  "What a scalar column should show for a waveform … is a separate ruling".

---

## 3. The op_annot device-OP block (context, not the analysis machinery)

`ase.tcl:10594-10795`. Two gates decide whether device numbers are asked for at all: the user's
`save_op_params` tick **and** an enabled operating point (`ase.tcl:10681-10682`). The *shape* is
`ase::op_save_tier`'s answer, pinned once per run by `ase::op_tier_arm`/`op_tier_now`
(issue 1366). Five arms:

| tier | deck-level | in-`.control` | notes |
|---|---|---|---|
| `a` | `.save all` | `optier_ctl` = wildcard `save` commands, emitted immediately before `op` | blanket-capable builds only; no released ngspice has it |
| `d` | `.save all` | `optier_post` = `set altshow` + `show all > <file>` **after** `op` | "`show` reads live CKT state rather than a stored plot" — dumping through the same carrier as the saves "would dump an unsolved circuit at exit 0" |
| `b` | `.save all` | — | `optier_write` = bare device names, spliced into the **`op` write line only**. Measured: the same bare name on a `.tran`/`.dc` write is *silently wrong* — dims=1, one non-zero sample at index 0, 0.0 for the rest |
| default, >1 analysis | `.save all` | `optier_ctl` = per-device `save` commands before `op` | issue 0964; requires the `op`-last reorder |
| default, 1 analysis | the whole captured block verbatim | — | byte-identical to what it has always been (row E8) |

The block itself is built at **netlist** time by `op_annot::save_cards` and cached keyed on the
exact netlist text (`ase.tcl:4874`, `ase::op_cards_*`). `render_deck` is a pure consumer.

---

## 4. INVARIANTS A FUTURE SESSION MUST NOT BREAK

These are load-bearing, each with measured evidence in the source comments. I have quoted the
evidence because a future session will be tempted by every one of them.

### I1 — The `.save all` leader stays at DECK level and is not "tidied away as a duplicate"

`ase.tcl:10633-10648`, guard **G-LEADER**, issue 0964:

> Any explicit `save` cancels ngspice's implicit save-everything (rule R2 / invariant I2), and the
> `.save all` at :3161 above is emitted ONLY when save_all_v is 1 — the schema default is 0.
> Measured on the committed save_all_v=0 sky130_tests/test_nfet_final state: block WITH the leader
> -> 13 vectors, 6 device parameters, 5 node v(); block WITHOUT it -> 7 vectors, 6 device
> parameters, ZERO node v(). And measured again when the reorder arm below was built: with the
> leader moved into `.control` alongside the device requests, a bench carrying per-output
> `.save <expr>` lines lost every OTHER node voltage from its TRANSIENT — the plot fell from 6
> vectors to 2, `time` and the one named output, silently.

Two `.save all` lines in one deck were re-measured harmless.

### I2 — A dot-card stays above `.control`; a `save` command stays inside it

`ase.tcl:10626-10632`:

> Inside a .control block a dot-card is `save: no such command available` at rc 0
> (op_annot.tcl:2112-2118) and above it a bare `save` is not a card at all — both fail silently.

This is why the per-device shape has two arms that are not interchangeable. Any new analysis
emitted as a **dot-card** must go above `.control` (step 11 of §1.1 is the last place available);
any new analysis emitted as a **command** goes in the loop.

### I3 — `set appendwrite` + one `write` per analysis + delete the raw before the run

`ase.tcl:10824-10844` (issue 0929):

> ngspice's `write` writes the CURRENT plot, and every analysis makes a new one. A single trailing
> `write` therefore stored ONLY the last analysis and silently discarded every earlier one. On the
> user's own tb_bandgap … the raw came back holding one plot, `Transient Analysis`, and pressing
> `6` said "No operating point results are loaded." … `set appendwrite` makes each `write` APPEND
> its plot to the file … ⚠ APPEND MEANS THE FILE MUST NOT PRE-EXIST. `ase::run_deck` deletes it
> before the run for exactly this reason.

The deletion is `ase.tcl:7156`. The lock (§5.2) exists because the deletion only protects
*sequential* runs.

### I4 — The analysis order is fixed, and the ONE exception is not reorderable by taste

`ase.tcl:10845-10866` (issue 0964):

> The emit order is normally the fixed `op dc ac tran` this block has always used, and every deck
> that carries no in-`.control` device requests renders byte-identically (row E12) …
> ⚠ THE ONE EXCEPTION IS NOT COSMETIC AND IS NOT REORDERABLE BY TASTE. When the per-device
> requests moved inside `.control`, they are asked for immediately before `op` — and ngspice's save
> list is sticky FORWARD ONLY: `unsave` does not exist and a later `save all` does not reset it
> (both measured, ngspice-46+). So `op` must be the LAST analysis or every analysis after it
> records the device numbers again, which is the 74.9 MB this change exists to delete.

Cost figure, same comment: +74.9 MB of results file (144,455,860 vs 69,595,016) and +4.08 s of
wall clock on the user's `tb_bandgap`.

**The reason for `op dc ac tran` as the *base* order is nowhere stated as physics.** It is
historical and frozen only by the byte-exact goldens. `ase::plot_sim_type` (`ase.tcl:7643-7657`)
used to say it "must mirror render_deck's emit order, forever" and its header now explicitly
retracts that (`ase.tcl:7620-7642`): both readers pick their plot **by name** out of the
multi-plot raw, so nothing downstream depends on which analysis ran last. That retraction is the
single most important fact for a future session: **the emit order is free, subject only to I4's
op-last rule and to the goldens.**

### I5 — The status guard after EVERY analysis, above the write

See §2.3 item 1. Row-pinned by `test_ase_core.tcl` D1's golden, whose comment
(`test_ase_core.tcl:369-372`) says a golden with the guard and the write in the other order
"would pass while the deck shipped the bad raw".

### I6 — The exit-status contract

Three defences, named (a), (b), (c) in the casemode batch's DECISIONS.md C4:

* **(a)** the pre-flight, `ase::preflight_gate` (`ase.tcl:4741`), run **before any artefact is
  read, deleted, rebuilt or written** (`ase.tcl:7114-7119`).
* **(b)** the in-deck `sim_status_guard` after every analysis → `quit 1`.
* **(c)** the process exit code, read from `::execute(exitcode,last)` in `ase::run_done`
  (`ase.tcl:7541-7542`).

Everything downstream keys on **exit code 0** (`ase_window.tcl:7860` `if {$ec == 0}` gates the
Value column refresh, the status colour, the auto-plot and the annotation refresh). A new
analysis that can fail without moving `$sim_status` or the exit code would silently ship a bad
raw. Note the measured hazard in §7.4: **`sp` on a portless circuit prints
`ERROR: fatal error in ngspice, exit(1)` and the run still ends `RC=0`** when a later analysis
succeeds — that is exactly the shape defence (b) was built for, and it only works because the
guard runs *per analysis*.

### I7 — `-r` is dead once analyses are `.control` commands

`ase.tcl:11006-11010`:

> with a .control block, ngspice's `-b -r <file>` is DEAD (re-probed 2026-08-29: with a .control
> block and no explicit `write`, `-r` produces NO raw file at all)

**MEASURED-HERE, confirmed and refined:** with `.control { tran 1u 5u }` and `-b -r r2.raw`, no
`r2.raw` is created (rc 0). But with a `.tran` **dot-card** plus `.control { run ; write dot.raw }`,
`-r r1.raw` **does** produce a 5933-byte raw alongside the explicit 5986-byte `dot.raw`. So the
invariant is precisely: *`-r` follows dot-card analyses, not `.control`-command analyses.* A future
session that moves any analysis to a dot-card must know this, because it changes which file the
results land in.

### I8 — `run_cmd`'s word order mirrors the probe's

`ase.tcl:11036` and the block above it: the shape is

```
<exe> -b <registry args…> [-n] [-D casemode=<mode>] <deckpath> 2>@1
```

"the probe's ordering wins, because a probe that measures a differently-shaped command from the
one that runs is measuring the wrong thing". Command goldens (`test_ase_simreg_0931.tcl` row D4)
pin it byte for byte, and the header says explicitly that reports belong to the *run*, not to
`run_cmd`, because of that pinning.

### I9 — the run log is written twice, both with mode `w`

Header before the launch (so a failed launch still leaves a log), whole file on completion
(`ase.tcl:7370-7392`, `ase::run_log_write` at `7503`). "a failed LAUNCH (`execute` returns -1, a
missing binary) raises out of this proc and run_done NEVER FIRES, so the old code left NO log file
at all — in precisely the case a user debugs."

---

## 5. The run pipeline

### 5.1 Doors

Three doors, one body:

* `ase::run` (`ase.tcl:7031`) — Simulation > Netlist and Run. Resolves the five hooks, calls
  `ase::netlist` (`ase.tcl:6797`, which re-netlists the design through xschem's C netlister and
  captures the op_annot block), then `ase::run_deck`.
* `ase::run_existing` (`ase.tcl:7048`) — Simulation > Run. Uses `<rundir>/<cell>.spice` as it
  stands, never re-netlists, so hand edits survive; works with the design window closed. Clean
  error if the artifact is absent.
* `ase::run_deck` (`ase.tcl:7075`) — the shared body; also reachable directly from the CIW or a
  script.

GUI entry points: `ase::ui::do_run` (`ase_window.tcl:7871`) and `ase::ui::do_run_existing`
(`ase_window.tcl:7967`).

### 5.2 `ase::run_deck`, in order (`ase.tcl:7075-7311`)

1. **`7143-7146` the in-flight refusal.** `ase::run_lock_key` = the normalized raw path
   (`ase.tcl:6875-6881`); `ase::run_in_flight` (`6886`) answers with the live execute id.
   Deliberately **at the top**, because everything above the first `open` only *reads* — "A
   refusal taken down there would therefore destroy the live run's results file on its way out".
2. **`7166` `ase::sim_apply_choice $state`** — the running session's simulator choice becomes the
   process-global in-force one, above every resolver and below the one gate that refuses without
   looking at one.
3. **`7171-7175` `ase::run_precheck`** — the casemode pre-run gate (B4). Refuses a `distinguish`
   mismatch, reports a `preserve` one; returns the line for the run log.
4. **`7177-7179`** reads the netlist file into `netlist_text`.
5. **`7186` `ase::preflight_gate`** — defence (a).
6. **`7191-7212`** cosim: `cosim_map`, `cosim_save_map`, `cosim_clear_artifacts`, then
   `cosim_build` (a failed model build **throws out of here**, deliberately: falling through would
   "silently simulate last week's Verilog").
7. **`7156` `file delete` the raw** (inside the cosim block region) — I3.
8. **`7169`-ish `catch {ase::cap_report $sim [ase::n_enabled_analyses $state]}`** — the capability
   report (`ase.tcl:3302`). Caught: "a probe that cannot run must never stop the run it was only
   reporting on".
9. **`7215` `ase::op_tier_arm`** then `7243` `ase::op_tier_report`, then
   **`7248-7254` `$render_deck $state $netlist_text`** — caught only to release the pin, re-raised
   unchanged (message, stack, errorCode).
10. **`7297-7300`** write the deck to `ase::deck_file $state` = `<rundir>/<cell>_ase.spice`
    (`ase.tcl:4830-4837`).
11. **`7302-7303`** `set logpath [$log_file $state]` = `<rundir>/<cell>_ase.log`
    (`ase.tcl:11134-11141`); `set cmd [$run_cmd $state $deckpath]`.
12. **`7327-7329` `ase::run_using_report`** — the "This run is starting the simulator you named
    …" sentence, at the last instant before launch (issue 1370: it used to sit eleven lines above
    the pre-flight and claimed starts for runs that never started).
13. **`7362-7366`** build `meta` = `{cell simulator cmd dir deck started opblock casenote optier
    using rawlock t0}`; `7367` write the header-only log.
14. **`7369`** `set ::execute(callback) [list ase::run_done $logpath $state $callback $meta]`.
15. **`7370-7373`** `cd $rd` ; `set id [eval execute 0 $cmd]` ; `cd $save`.
16. **`7374-7379`** `$id == -1` → unset the stale callback, raise
    `"ase: cannot start simulator '<sim>' (<argv0> not runnable)"`.
17. **`7380-7382`** `ase::run_lock_set $rawlock $id` — **only now**, so a launch that did not
    launch leaves no lock.

### 5.3 The command line

`ase::backend::ngspice::run_cmd` (`ase.tcl:11066-11079`):

```tcl
set s [ase::sim_status ngspice]
if {![dict get $s ok]} { return -code error "ase: [dict get $s why]" }
if {[dict get $s why] ne {}} { ase::echo "ase: [dict get $s why]" error }
set cmd [list [dict get $s exe] -b]
foreach a [ase::run_safe_args [dict get $s args]] { lappend cmd $a }
if {[ase::sim_nospiceinit ngspice]} { lappend cmd -n }
foreach w [ase::run_casemode_flag $state] { lappend cmd $w }
lappend cmd $deckpath 2>@1
```

* `-b` = batch. `2>@1` folds stderr into the captured stdout — **stdout must flow into
  `execute(data,$id)`, so `-o` is never used and is actively filtered out.**
* `ase::run_filter_args` / `ase::run_safe_args` (`ase.tcl:3915-3943`) drop exec-syntax
  redirections, pipelines, `&`, and `-o`/`--output`/`--output=`/`-o<x>`. **`-r`, `--rawfile`,
  `--soa-log` are KEPT** — the probe filter `sim_probe_safe_args` (`xschem.tcl:3507`) drops those
  too and is deliberately not used here. Anything dropped is reported by `ase::run_precheck`,
  never silently.
* `-n` (`--no-spiceinit`) is **off by default**, only when the registry entry asks
  (`ase::sim_nospiceinit`, `ase.tcl:3277`).
* `-D casemode=<mode>` only for a non-`fold` request (`ase::run_casemode_flag`, `ase.tcl:4002`).
  Rationale at `ase.tcl:3986-4001`: a released ngspice accepts and ignores the flag; a
  case-capable one defaults to `fold`; a `.spiceinit` overrides it regardless.
* The simulator is resolved by `ase::sim_status` (`ase.tcl:1978-2037`) — registry entry if one is
  in force, else `[lindex [auto_execok ngspice] 0]` off `$PATH`. **It refuses rather than falling
  back** (`ase.tcl:11026-11031`).

### 5.4 Output capture

`execute` (`xschem.tcl`, `proc execute {status args}`): `open "|$args" r`, non-blocking, a
`fileevent readable` handler. `execute_fileevent` appends **1024-byte chunks** to
`::execute(data,$id)`; at EOF it sets `::execute(data,last)` / `::execute(exitcode,last)` and
fires `::execute(callback,$id)`.

Status argument is `0` → no viewdata popup, headless-safe, no `$terminal` (`ase.tcl:7069-7073`).

**Live log:** `ase::ui::run_started` (`ase_window.tcl:7887`) opens+clears the log pane and calls
`ase::ui::attach_trace` (`7702`), which puts a Tcl **write trace** on `::execute(data,$id)`;
`log_trace` pushes only the delta into the widget. The EOF unset kills the trace; `drop_trace`
covers early window close.

### 5.5 Completion

`ase::run_done` (`ase.tcl:7531-7599`), fired from `execute_fileevent` at EOF:

1. `ase::run_lock_clear` **first**, before anything that can raise.
2. read `::execute(data,last)` and `::execute(exitcode,last)` (default `-1`).
3. `ase::run_log_write $logpath $meta $data $exitcode` — header + `--- simulator output ---` +
   body + `=== exit <n> after <s> s ===` footer (`ase.tcl:7414-7526`). Elapsed is from the `t0`
   stamp taken in `run_deck` immediately before `execute`, **never recomputed here**.
4. `results = [result_probe $state $data]` — **the Value column is parsed out of the LOG, not out
   of the raw** (`ase.tcl:11232-11288`; see §5.6).
5. `ase::run_diagnostics $data` — cosim desync scan; plus a filesystem check for VCDs the deck
   promised and that never appeared.
6. `last_run = {results … exitcode … log … diagnostics …}`.
7. `catch {ase::op_report_missing …}`, then
   `ase::echo "ase: simulation finished (exit $exitcode), log: $logpath"`.
8. `uplevel #0 $callback` — in the GUI that is `ase::ui::run_finished $key`.

`ase::ui::run_finished` (`ase_window.tcl:7885`... actually `7833`–onwards): flushes the final log
delta, drops the trace, echoes cosim diagnostics into the log pane, then **branches on
`$ec == 0`**: stores per-session `results`, refreshes the Outputs Value column, sets the status
segment green, schedules `auto_plot_idle` (deferred to `after idle` because the callback can run
inside `ase::wait`'s semaphore bracket where window switches silently no-op), and refreshes
annotation. Non-zero → red status.

### 5.6 How results are located and read back

**Two independent channels, and this is important:**

| channel | source | consumer |
|---|---|---|
| scalar Values | the **log text**, regexped for `<expr> = <float>` by `result_probe` (`ase.tcl:11232`) | the Outputs pane Value column |
| waveforms & OP device params | the **raw file** `<rundir>/<cell>_ase.raw`, via `xschem raw read <file> <type>` | the waveform viewer, `op_annot`, the Results Display Window |

`ase::last_rawfile` (`ase.tcl:7661-7669`) resolves the backend `raw_file` hook and returns it
**only when the file exists** — "file existence == this session has simulation results".

`ase::plot_sim_type` (`ase.tcl:7643`) chooses the `xschem raw read` **type** argument from the
enabled set in the fixed order `op dc ac tran`, last-enabled-wins — so a transient beats an
operating point. Its header (`7620-7642`) is where the "no longer mirrors the emit order"
retraction lives.

`result_probe`'s match is a **two-rung ladder** (`ase.tcl:11178-11231`): exact spelling first;
then a case-insensitive pass **which declines to guess** when the log offers more than one
differently-cased label (and says so in the CIW). Rung 2 is off under `distinguish`, and the
*delivered* mode outranks the *requested* one in the strict direction — the log is scanned for
`casemode[ =]'?distinguish|differs only in case` and forces strict matching regardless of the
request (`ase.tcl:11241-11250`).

### 5.7 Can a run be aborted?

**Yes, on Unix only.** `ase::ui::do_stop` (`ase_window.tcl:8003-8021`), menu label
`ase::ui::lbl_stop` = `Stop` (`ase_window.tcl:5922`):

* looks up the session attr `run_id`; if that is missing or dead, falls back to
  `ase::run_in_flight [ase::run_lock_key …]` — three measured routes where the attr is absent
  (two sessions on one cellview, a CIW/script launch, a window closed and reopened mid-run).
* `kill_running_cmds $id -9` — **SIGKILL**, "for a deterministic abort — close() then reports
  CHILDKILLED -> nonzero exitcode -> the normal completion path (run_finished) turns the status
  segment red".
* On Windows it refuses with `"ase: Stop is not available on Windows"` (the `kill(1)` path cannot
  work).

There is **no pause, no graceful interrupt, no partial-result salvage**. A SIGKILLed ngspice
leaves whatever `write`s already completed in the raw (which, with `appendwrite`, is a legitimate
partial multi-plot file) and a nonzero exit code that suppresses every downstream consumer.

---

## 6. The capability probe

### 6.1 What it is

`ase::sim_capabilities <backend>` (`ase.tcl:2858`) → `ase::sim_capabilities_at <backend>
<resolved> <eargs>` (`ase.tcl:2897`) → the backend's `capabilities` hook
(`ase::backend::ngspice::capabilities`, `ase.tcl:11325`) — **lazy, never at startup**, cached in
memory for the session, never written to disk.

Answer shape (`ase.tcl:2822-2833`):

```
{known 0}                                     nothing measured, nothing claimed
{known 0 unmeasured <timeout|noplace> …}      the same, plus why
{known 1 usable 0|1 appendwrite 0|1 blanket_op_save 0|1 hier_op_names 0|1
         [casemode_detected …] [altshow_op_dump 0|1]}
```

**The standing contract, stated three times in the file: a MISSING key means "not measured",
never "no".** `known` must be read first (`ase.tcl:2827-2831`). Two optional keys —
`casemode_detected` and `altshow_op_dump` — are published **only for a complete measurement**, and
their absence does *not* make the whole answer `known 0`.

### 6.2 What it currently probes

Three decks plus one sub-probe, all from **one** shared 30-second budget
(`ase::cap_budget_ms`, `ase.tcl:139`; `ase::cap_left`/`cap_spent`, `ase.tcl:2570`/`2590`):

* **the circuit** (`ase.tcl:11326-11338`): PDK-free, `.model nm1 nmos level=1`, one MOS two
  subcircuits deep (`xo1` → `outer` → `xi1` → `inner` → `m1`). Nothing on the user's machine has to
  be installed.
* **deck A** (`ase.tcl:11345-11360`): `set filetype=ascii`, three explicit device-param saves,
  `set appendwrite`, `op` + `write`, `tran 1n 5n` + `write` — into **one** file.
  → `usable` (any plot with ≥1 point came back at all),
  → `appendwrite` (**two plots in one file**; `ase.tcl:11424-11439` records that this used to be
     decided by whether the *named vectors* were found, which was issue 0952 and a wrong
     diagnosis),
  → `hier_op_names` (the three spellings `op_annot::_wrap` emits — `i(@m.xo1.xi1.m1[id])`,
     `@m.xo1.xi1.m1[gm]`, `v(@m.xo1.xi1.m1[vdsat])` — are all present **and** the OP plot has
     ≥1 point).
* **deck B** (`ase.tcl:11362-11372`): `save @m.xo1.xi1.m1[*]` (via `ase::cap_param_wildcard`,
  `ase.tcl:5464`), `op`, `write` → `blanket_op_save`. No released ngspice can do this; the probe
  keeps answering honestly rather than by assumption.
* **deck C** (`ase.tcl:11374-11390`): adds one PWL source, then `op` ; `set altshow` ;
  `show all > probe_c.txt` → `altshow_op_dump`, verdicted by `ase::cap_altshow_verdict`
  (`ase.tcl:5498`). **It writes a TEXT file, not a raw**, so it needs none of the
  claim/result machinery — this is the precedent a new probe should copy.
* **the casemode leg** (`ase.tcl:11504-11536`): `sim_probe_capability` (`xschem.tcl:3824`), which
  runs three legs (`-D casemode=fold|preserve|distinguish`) and compares request against
  `$curcasemode`. Each mode is probed separately and that is not waste: "a wrong-case KEY
  (`-D CaseMode=`) leaves `$curcasemode` at `fold` SILENTLY … while a wrong-case VALUE
  (`=PRESERVE`) works." Measured cost ~65 ms for all three on `build-ver_50`.

**⚠ NOT ONE VERDICT COMES FROM THE EXIT CODE OR THE LOG** (`ase.tcl:11298-11301`): "deck B's shape
exits 0, writes a results file, and logs no warning and no error, while holding no operating point
at all. The exit codes are collected for a bug report and used for nothing." Every answer is read
out of a file the deck itself asked for, by `ase::cap_raw_plots` (`ase.tcl:2649`), the probe's
**own** header parser — deliberately not `xschem raw`, because that would detach the results
database the user is looking at (ruling 0881, `ase.tcl:2653-2658`).

### 6.3 Cache and invalidation

* **Key**: `ase::cap_key {resolved eargs}` (`ase.tcl:2229`) — the **resolved absolute program
  path AND the argument list**, never the backend name and never the entry name. Issue 1371's
  adversary found that a path-only key let two argument lists share one answer.
* **Value**: `{stamp <cap_stamp> caps <dict>}` in `ase::sim_caps` (`ase.tcl:126`).
* **Stamp**: `ase::cap_stamp` (`ase.tcl:2180`) = `{path <normalized> mtime <n> size <n>}` — path +
  mtime + size, so a rebuild in place expires it.
* **Staleness**: `ase::cap_stale` (`ase.tcl:2204`) — **biased towards re-measuring**: any doubt at
  all answers 1 and costs one ~10 ms probe.
* **Only a `known 1` answer is remembered** (`ase.tcl:2947-2957`, issue 0950). "a wrong answer
  taken in a folder the simulator could not write into was then served for the rest of the
  session".
* **Manual clear**: `ase::sim_caps_clear` (`ase.tcl:2235`) — called on every registry edit; also
  clears `cap_noplace_said` so a fixed folder gets its notice again.
* **Free peek**: `ase::sim_caps_have_path` / `ase::sim_caps_have` (`ase.tcl:3026` / `3043`) — reads
  the cache and the stamp and **starts nothing**. Measured: 447 ms cold, 0 ms warm, **31.2 s** for
  a program that exists, is executable and never answers. Dialogs ask the peek first and offer the
  measured set only when asking is free; a **Detect** button is the door to the other case.
* **Working directory**: `ase::cap_workdir` (`ase.tcl:2276`) hands out a fresh, private, absolute
  `.ase_probe/…` directory per measurement, inside the simulation folder. Empty is a real answer
  and produces `{known 0 unmeasured noplace …}` — "a fact about the FOLDER, not about the
  program". `ase::cap_claim`/`ase::cap_result` (`2549`/`2561`) are the second guard: a results file
  this run did not see appear is never believed.
* **Runner**: `ase::cap_run` (`ase.tcl:2800`) — `timeout -k 2 <secs>` prefix when the box has one
  (`ase::cap_timeout_cmd`, `2605`), stdin from `/dev/null`, `2>@1`, `cd workdir` around the exec,
  relative-with-separator program names normalized before the move. Returns
  `{exitcode output was-cut-off elapsed-ms}`.

### 6.4 How a future session extends it to probe PSS / SP / CIDER / XSPICE

**Build gating in this ngspice tree, verified:**

| feature | macro | configure switch | default | this tree (`build-ver_50/src/include/ngspice/config.h`) |
|---|---|---|---|---|
| S-parameter (`sp`) | `RFSPICE` | `--disable-sp` to turn off (`configure.ac:1220-1229`) | **ON** | `#define RFSPICE 1` (config.h:535) |
| PSS (`pss`) | `WITH_PSS` | `--enable-pss` (`configure.ac:1082-1085`) | **OFF** | `/* #undef WITH_PSS */` (config.h:576) |
| CIDER | `CIDER` | `--enable-cider` (`configure.ac:149-151`, `1214-1217`) | **OFF** | `/* #undef CIDER */` (config.h:11) |
| XSPICE | `XSPICE` | `--disable-xspice` to turn off (`configure.ac:141-143`, `1108-1127`) | **ON** | `#define XSPICE 1` (config.h:579) |
| OSDI | `OSDI` | `--disable-osdi` to turn off | **ON** | `#define OSDI 1` (config.h:502) |

**Where the gate actually bites for the command layer:** `src/frontend/commands.c`. The
`spcp_coms[]` table carries `pss` under `#ifdef WITH_PSS` (`commands.c:324-331`) and `sp` under
`#ifdef RFSPICE` (`commands.c:333-338`); `codemodel` is under `#ifdef XSPICE`
(`commands.c:266,283-287`) and `osdi` under `#ifdef OSDI` (`commands.c:288-293`). `op`, `tf`,
`tran`, `ac`, `dc`, `pz`, `sens`, `disto`, `noise` are **unconditional**
(`commands.c:312-362`). CIDER has **no command of its own** — it adds *devices*
(`src/spicelib/devices/dev.c:197-203`: `get_nbjt_info`, `get_nbjt2_info`, `get_numd_info`,
`get_numd2_info`, `get_numos_info` under `#ifdef CIDER`).

**MEASURED-HERE — the direct approach fails the file-based doctrine.** A `.control` block
containing `pss` on this build prints, at *parse* time (before the `Circuit:` banner):

```
pss: no such command available in ngspice
Error: sim_status: no such variable.
```

and the deck continues; with no other analysis the process exits **1** with "incomplete or empty
netlist … no simulations run!". So the absence *is* detectable, but only from the **log**, which
§6.2's own doctrine forbids as a verdict source.

**MEASURED-HERE — the file-based probe that works.** `help all` writes the entire command list,
and it accepts a redirect inside `.control`:

```
* ase capability probe D: what commands does this build have
.model nm1 nmos level=1 vto=0.7 kp=100u
… (the same PDK-free circuit) …
.control
op
help all > probe_d.txt
devhelp    > probe_e.txt
.endc
.end
```

Result on `build-ver_50` (109 lines in `probe_d.txt`): `ac`, `dc`, `op`, `tran`, `tf`, `pz`,
`sens`, `disto`, `noise`, **`sp`**, `codemodel`, `osdi` present; **`pss` absent**. Each line has
the shape `<name> <usage> : <description>` with the command name at column 0, so the parse is a
`^(\S+)\s` scan into a set. `devhelp > probe_e.txt` writes 137 lines of
`NAME<pad>:\t<description>`, listing every compiled-in device **plus every code model the
`.cm` libraries actually loaded** — on this build that includes `d_cosim`, `adc_bridge`,
`dac_bridge`, `d_and`…, `table2d`, `mlin`/`tline`/`cpline`, `spice2poly`, which is a *stronger*
XSPICE signal than the `codemodel` command (the command's presence proves XSPICE was compiled;
the models' presence proves `spinit` actually loaded them).

Proposed new keys, following the existing naming and the missing-key-means-unmeasured contract:

```
analyses_available   {ac dc disto noise op pz sens sp tf tran}   ; from probe_d.txt
devices_available    {… d_cosim adc_bridge numd nbjt …}          ; from probe_e.txt
```

and derived booleans a caller may want spelled out — `has_pss`, `has_sp`, `has_cider`
(`numd`/`nbjt`/`numos` in `devices_available`), `has_xspice` (`codemodel` in
`analyses_available`, or `d_cosim`/`adc_bridge` in `devices_available`), `has_osdi`.

**Rules the new leg must obey** (each already stated in the file for the `altshow` leg,
`ase.tcl:11473-11503`, and for the casemode leg, `ase.tcl:11504-11532`):

1. **Publish the key only for a complete measurement.** A leg that runs out of budget publishes
   *nothing*; absence means "not measured", and readers must treat it as "do not offer", never as
   "not supported".
2. **A timed-out leg must NOT make the whole answer `known 0`** — the earlier legs' answers were
   paid for by the user's wait.
3. **Take the budget check first**: `if {[ase::cap_left $t0] > 0} { … }`, and pass
   `[ase::cap_left $t0]` to `ase::cap_run`.
4. **Read the file, not the log.** Guard with `[file exists $dumpd]`, exactly as deck C does.
5. **Do not add a fourth and fifth `cap_run`** if one deck can carry both redirects — deck D above
   does `help all` and `devhelp` in one run, cost ≈ one `op` (MEASURED-HERE: the deck completes
   in well under a second on the PDK-free circuit).
6. **The verdict lives in its own proc** if it is anything but set membership, so it can be driven
   from a suite without launching a simulator (`ase::cap_altshow_verdict` is the precedent).
7. **`ase::cap_report`** (`ase.tcl:3302`) is where a capability turns into a *sentence*; the
   sentences are minted in `ase::sim_why` (`ase.tcl:985`, `cap_*` arms at `1052-1061`). A new
   capability that the GUI must explain needs an arm there, not an inline string.

**One caveat worth measuring before relying on it:** `help all`'s output is the command *help*
table, and it is emitted by the help subsystem, not by the command dispatcher. It matched the
`#ifdef` set exactly on this build, but a build with a stripped or relocated help file could in
principle answer differently. A belt-and-braces second signal for `sp` is the presence of a
`Plotname: S-parameter`-class plot after a real `sp` run, and for PSS the *absence* of the
`pss: no such command available` string; both are weaker than the file scan and should be
secondary.

**What the probe can NOT tell you, and what a GUI must therefore not claim:** the probe measures
the *command's existence*, not whether the analysis will succeed on the user's circuit. MEASURED-
HERE: `sp lin 3 1 2` on a circuit with no RF port prints `Error: No RF Port is present, cannot
run sp analysis` and `ERROR: fatal error in ngspice, exit(1)` — a per-analysis failure, not a
capability failure. That distinction is exactly what the `sim_status_guard` (I5) is for.

---

## 7. Candid assessment: what generalises and what is welded to four

### 7.1 Generalises as written (no change needed)

* **Everything above `.control`** — includes, libs, params, options, savecurrents, temp, save-all,
  per-output saves. All schema-driven `foreach` over state lists.
* **`pre_commands`** — an arbitrary escape hatch already in the deck, verbatim, expanded.
* **The `.control` frame** — `.control` / `set appendwrite` / `.endc` / `.end`.
* **The per-analysis epilogue** — the status guard, `remzerovec`, `write` are already emitted
  *per analysis* and do not know which analysis they follow. A new type gets them for free.
* **`ase::n_enabled_analyses`** (`ase.tcl:3695`) — pure count over `analyses`, type-blind.
* **The results read-back** — `xschem raw read <file> <type>` picks its plot **by name** out of a
  multi-plot raw, and `ase::cap_raw_plots`/`cap_plot` enumerate plots generically. Adding a plot
  name is a data change.
* **The whole run pipeline** — locking, deck write, launch, capture, log framing, exit-status,
  Stop. None of it mentions an analysis type.
* **The capability probe** — one budget, private workdir, file-based verdicts, cache keyed on
  program+args. Extending it is additive.
* **The extra-key editor** (`ase::ui::chana_options`, `ase_window.tcl:4582`) — an arbitrary
  name/value editor per analysis row that already round-trips through the state file and the
  Arguments summary. It is a ready-made general options UI **whose values the renderer ignores**
  (see 7.2).

### 7.2 Welded to exactly four — the five sites

1. **`ase.tcl:10867` `set anorder {op dc ac tran}`** and **`ase.tcl:10946`
   `set anorder {dc ac tran op}`** — two literal four-element lists.
2. **`ase.tcl:10951-10967` the `switch -- $type`** — four arms, each hand-spelling its card. There
   is no per-type descriptor, no table, no hook. A tenth analysis means a tenth `switch` arm.
3. **`ase.tcl:10934` `foreach type {dc ac tran op}`** — the print-anchor order, a *third* literal
   four-element list, deliberately different from the other two.
4. **`ase.tcl:7647` `foreach type {op dc ac tran}` in `ase::plot_sim_type`** — a *fourth* literal
   list, deciding which plot the waveform viewer opens on.
5. **The GUI**: `ase_window.tcl:83` `anaargs` (a per-type field-order dict),
   `ase_window.tcl:4441-4449` `chana_fields` (a per-type quick-field list, a *subset* of
   `anaargs`), and `ase_window.tcl:4472` `foreach t {op dc ac tran}` (the radiobutton row) —
   three more literal four-element structures. Plus `ase::state_default`'s
   `analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}`
   (`ase.tcl:511`), which seeds every new session with exactly these four rows and no others.

**The dead field.** `anaargs` says `ac {points start stop dec}` but the renderer hard-codes
`dec`. So the schema already has one field that *looks* configurable and is not — and the GUI's
own comment admits it. Any generalisation pass should treat this as the canary: the arg schema
and the emitter are two sources of truth that have already drifted once.

**The unemitted extras.** `chana_options` lets a user put arbitrary `name value` pairs on an
analysis row; they persist and display, and `ase_window.tcl:4580-4581` states plainly: "DECK
emission of extra keys stays deferred (v1 limit, documented here)". So the GUI **already has a
general options editor whose output the deck throws away.** Wiring it up is probably the single
highest-leverage change available, and it is the natural home for `tran`'s `tstart`/`tmax`/`uic`,
`ac`'s `dec|oct|lin`, `dc`'s second source, `noise`'s `pts_per_summary`, and so on.

### 7.3 Structural gaps a 10+-analysis design must close

* **No per-analysis descriptor.** There is nowhere to say "this analysis is called `noise`, its
  card is `noise <output> <src> <variation> <pts> <fstart> <fstop> [pts_per_summary]`, it needs
  these fields, it produces plots named X and Y, it requires capability K". Every one of those
  facts is currently spread across five files. **This is the thing to build first**: one table,
  read by the renderer's loop, by `chana_fields`, by the radiobutton row, by `plot_sim_type`, by
  `arg_summary`, and by the capability gate.
* **No capability gate on an analysis at all.** `render_deck` will happily emit `pss` if a row
  says so, and the user sees `pss: no such command available` in a log they may never open. The
  probe machinery to prevent that exists (§6.4); nothing consults it.
* **No dot-card path.** Every analysis is a `.control` command. Some things (`.four`, `.meas`,
  `.probe`, `.disto`'s companion cards, CIDER's `.options`) are card-shaped, and I2 says a card
  must go above `.control` — i.e. into step 11 of §1.1, which today is op_annot's private
  territory.
* **`analyses` is a flat list with no identity.** Rows are addressed by "first row of type T"
  (`chana_row`, `ase_window.tcl:4452`; the index scans in `chana_ok`/`chana_x_ok`). Multiple
  sweeps of the same type (two `dc` sweeps, three `ac` corners) are emittable but not editable.
  A stable per-row id would be needed before a GUI could offer "add another AC analysis".
* **No sweep/corner/Monte-Carlo layer at all.** ADE-L's parametric sweep, corners and MC are
  entirely absent from the state schema. `.step`-style sweeps would have to be a *new* deck layer,
  not another analysis row.

### 7.4 The one measured landmine for multi-analysis generalisation

**MEASURED-HERE:** the deck's "one `write` per analysis" invariant (I3) silently assumes **one
analysis ⇒ one plot**. That is false for at least two of ngspice's analyses:

```
* after `noise v(mid) v1 dec 3 1 1k`, setplot reports:
Current noise2   (Integrated Noise)
        noise1   (Noise Spectral Density Curves)
        op1      (Operating Point)

* after `disto dec 3 1 1k`, setplot reports:
Current disto2   (DISTORTION - 3rd harmonic)
        disto1   (DISTORTION - 2nd harmonic)
```

A single `write` after `noise` therefore stores **`Integrated Noise` only** and silently discards
the spectral-density curves — which are the thing a designer actually wants to plot. This is issue
0929's exact defect arriving through a new door, and it will not announce itself: exit 0, a
well-formed raw, one plot.

The plot names measured on `build-ver_50` for a nine-analysis deck (`op dc ac tran noise tf pz
sens disto`, one `write` after each, `set appendwrite`, `set filetype=ascii`, rc 0, no warnings):

| analysis command | plot name written |
|---|---|
| `op` | `Operating Point` |
| `dc v1 0 1 0.5` | `DC transfer characteristic` |
| `ac dec 3 1 1k` | `AC Analysis` |
| `tran 1u 5u` | `Transient Analysis` |
| `noise v(mid) v1 dec 3 1 1k` | `Integrated Noise` *(and `Noise Spectral Density Curves` LOST)* |
| `tf v(mid) v1` | `Transfer Function` |
| `pz in 0 mid 0 vol pz` | `Pole-Zero Analysis` |
| `sens v(mid)` | `Sensitivity Analysis` |
| `disto dec 3 1 1k` | `DISTORTION - 3rd harmonic` *(and `- 2nd harmonic` LOST)* |

The internal analysis descriptor names (`src/spicelib/analysis/*setp.c`) differ from the plot
names — `OP`/`DC`/`AC`/`TRAN`/`NOISE`/`TF`/`PZ`/`SENS`/`DISTO`/`PSS`/`SP` — so **neither** the
command name nor the descriptor name can be used to find a plot; only the measured plot-name
string works. That table is data a per-analysis descriptor must carry, and for `noise`/`disto` the
descriptor needs a *list* of plots and the renderer needs `setplot <name>` + `write` per plot, or
`write <file> all` semantics, before those analyses can be offered honestly.

---

## 8. Quick reference — anchors

| thing | anchor |
|---|---|
| `render_deck` | `ase.tcl:10521-11014` |
| `.control` opens / `.endc` / `.end` | `ase.tcl:10797` / `11011` / `11012` |
| `set appendwrite` | `ase.tcl:10844` |
| base emit order | `ase.tcl:10867` |
| op-last reorder | `ase.tcl:10946` |
| the four `switch` arms | `ase.tcl:10951-10967` |
| print anchor order | `ase.tcl:10934` |
| `run_cmd` | `ase.tcl:11066-11079` |
| `sim_status_guard` | `ase.tcl:11122-11132` |
| `log_file` / `raw_file` / `deck_file` | `ase.tcl:11134` / `11145` / `4830` |
| `print_arg` / `result_probe` | `ase.tcl:11163` / `11232` |
| `capabilities` probe | `ase.tcl:11325-11544` |
| backend registration | `ase.tcl:11736-11744` |
| `register_backend` (5 required + 4 optional hooks) | `ase.tcl:663-673` |
| `ase::run` / `run_existing` / `run_deck` | `ase.tcl:7031` / `7048` / `7075` |
| `run_done` / `run_log_*` | `ase.tcl:7531` / `7414-7526` |
| `plot_sim_type` | `ase.tcl:7643` |
| run lock | `ase.tcl:6875-6920` |
| capability cache decl | `ase.tcl:117-152` |
| `cap_stamp` / `cap_stale` / `cap_key` / `sim_caps_clear` | `ase.tcl:2180` / `2204` / `2229` / `2235` |
| `cap_workdir` / `cap_claim` / `cap_result` | `ase.tcl:2276` / `2549` / `2561` |
| `cap_run` / `cap_raw_plots` / `cap_plot` | `ase.tcl:2800` / `2649` / `2712` |
| `sim_capabilities{,_at,_path,_for}` | `ase.tcl:2858` / `2897` / `2963` / `3006` |
| `sim_caps_have{,_path}` / `sim_has_probe` | `ase.tcl:3043` / `3026` / `3058` |
| `casemode_detected_in` / `cap_report` | `ase.tcl:3104` / `3302` |
| `sim_probe_capability` (casemode legs) | `xschem.tcl:3824` |
| Choose Analyses dialog | `ase_window.tcl:4438-4570` |
| extras editor (unemitted) | `ase_window.tcl:4582-4707` |
| `anaargs` field schema | `ase_window.tcl:83-84` |
| `do_run` / `do_run_existing` / `do_stop` | `ase_window.tcl:7871` / `7967` / `8003` |
| live-log trace | `ase_window.tcl:7702-7730` |
| committed deck golden | `tests/headless/test_ase_core.tcl:373-405` |
| ngspice command table | `src/frontend/commands.c:312-362`, `266-293` |
| ngspice build gates | `configure.ac:141,149,1082,1220`; `build-ver_50/src/include/ngspice/config.h:11,502,535,576,579` |

---

## 9. Gaps / things I could not settle

* I did not read `op_annot.tcl`, `wave_viewer.tcl` or `ase::preflight_*` in depth; the op-tier
  arms and the pre-flight are summarised from `render_deck`'s and `run_deck`'s own comments.
* I did not verify the `.save all` leader measurements or the `remzerovec` claim first-hand —
  they are quoted from the source, which carries dates and numbers.
* Whether `help all`'s output is guaranteed to track the `#ifdef` set on every build (e.g. one
  with a relocated help database) is unverified; it matched exactly on `build-ver_50`.
* Whether CIDER can be probed at all through `devhelp` on a CIDER build is **untested** — this
  tree has `CIDER` undefined, so `numd`/`nbjt`/`numos` are absent and I could not confirm they
  appear when it is enabled. `src/spicelib/devices/dev.c:197-203` says they should.
* PSS's card/command argument grammar, and `sp`'s port-setup requirements, are the analysis
  agent's territory; I only established that `pss` is absent from this build and `sp` is present
  but errors without an RF port.
* Whether `write <file> all` would capture *all* plots (fixing the noise/disto loss) or only all
  vectors of the current plot is **untested**; the `optier_write` arm uses
  `write <file> all <names>` for a different purpose, so the semantics need checking before it is
  relied on.
