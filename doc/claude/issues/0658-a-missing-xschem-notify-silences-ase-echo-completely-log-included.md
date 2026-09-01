# 0658 — a missing `xschem::notify` silences `ase::echo` completely, the durable log included

Status: **FIXED 2026-08-24** (status **E** — the fix changes user-visible startup
behaviour and wants a ruling; see "The ratification this owes"). Four new defects
were measured on the way in and are filed, not fixed: **0664**, **0665**, **0666**,
**0667**. Two more found while implementing: **0662**, **0663**.
Filed by: the 0650 write-up pass, 2026-08-23, from the adversary leg's finding.
Fixed by: the 0658 crew, 2026-08-24, on branch `annotate`.

## Measured BEFORE — the driver reproduced it, then the Measure agent did

The driver's own probe, `rename ::xschem::notify ::v_saved_notify` then
`ase::echo "ASE: a refusal the user must see" error`:

```
notify exists : 1 | with channel gone: rc=0 res='0' | with channel back: rc=0 res='1'
```

The Measure agent's full transcript, `./src/xschem --nogui --pipe -q --logdir`,
asserting on the **file** rather than on a return value (verbatim):

```
PRE notify exists : 1
CONTROL  ase::echo      rc=0 res=1 log 251->291
CONTROL  wviewer::echo  rc=0 res=1 log 291->330
POST notify exists : 0
R1/R2 DEGRADED ase::echo      rc=0 res=0 log 330->330
R2    DEGRADED wviewer::echo  rc=0 res=0 log 330->330
RESTORED ase::echo      rc=0 res=1 log 330->379
--- the durable log file after all six calls (the two DEGRADED lines are ABSENT) ---
#! ASE-0658 a refusal the user must see
#! WV-0658 a refusal the user must see
#! ASE-0658-RESTORED a refusal the user must see
--- R4: no degraded-state announcement exists at HEAD ---
  ANY announcement proc/var: 0
--- the wider family with the channel gone (0658's fix covers only notify) ---
  ase::op_cards_nudge_ok <state> -> rc=1 res/err='invalid command name "::xschem::notify_latch_ok"'
```

Zero sinks, nothing raised, and the durable line — the sink 0650's own table
calls *"the one that survives a shut window"* — was **not written**. Before 0650
that write was **inline** in `ase::echo` and had no cross-file dependency. A
regression 0650 introduced, not a pre-existing limitation.

## ⚠ THIS ISSUE'S OWN REACHABILITY SENTENCE WAS FALSE, AND IT CHANGED THE FIX

The sentence that stood here — *"any Tcl error anywhere in `src/ciw.tcl` kills
the whole file, and `xschem.tcl` continues past a failed source"* — is **wrong**,
measured independently by the Scout, the Measure agent and the Implement agent's
own sabotage leg. `src/xschem.tcl:14648` was a **bare** `source`. A raise inside
`ciw.tcl` propagates **out of `xschem.tcl`**, `source_tcl_file()`
(`src/xinit.c:1513`) merely prints it and returns, `Tcl_AppInit` ignores that
return (`src/xinit.c:3406`) and walks on into
`tclgetdoublevar("cairo_font_line_spacing")` against variables the rest of the
file never got to set:

```
error at the TOP of ciw.tcl          -> SIGSEGV, exit 139, the script never runs
error at the END of ciw.tcl          -> SIGSEGV, exit 139
ciw.tcl ABSENT (the pure 0424 shape) -> SIGSEGV, exit 139
```

It is `Tcl_AppInit` that continues past a failed source of **`xschem.tcl`**, NOT
`xschem.tcl` past a failed source of a helper. **A bootstrap alone is therefore
inert in the exact scenario this issue is sold on** — the process is already
dead. Catching the source is what makes the degraded state *real*; the bootstrap
is what makes it *survivable*. The class is filed as **0663**.

## What landed — pure Tcl, four files, no build, no `./configure`

1. **A bootstrap channel in `src/xschem.tcl` at `:14595`** — after
   `save_as_form.tcl`, **before** `op_annot` (:14796), `cmdmode`, `ase` (:14802),
   `ase_window`, `wave_viewer` (:14806), `calculator` and `ciw` (:14854):
   `notify_log`, `notify_degraded_once`, `notify_bootstrap`, `notify`, the
   degenerate `notify_latch_ok`/`_rearm`/`_reset`, and `notify_safe`.
   `src/ciw.tcl:246` redefines the channel and the real latch trio exactly as
   before.
2. **`src/ciw.tcl` sink 2 collapsed** from 12 lines to
   `if {[xschem::notify_log $line $tag]} { lappend sinks log }`. **ONE builder,
   TWO consumers** — this is what keeps the bootstrap from being a second copy
   of the trimright / trailing-backslash pad / empty-guard / `actionlog_filename`
   block, and it is why this issue's own rejected alternative #1 stayed rejected.
3. **`src/ase.tcl:157` and `src/wave_viewer.tcl:750`** are now
   `proc X {msg {tag {}}} { return [::xschem::notify_safe $msg $tag] }`.
4. **`source .../ciw.tcl` (`:14854`) is caught and `ciw_create` (`:16919`) is
   guarded**, each announcing through `notify_degraded_once`.

## Measured AFTER

```
R1/R2 rename-away, --nogui --pipe -q --logdir:
  ase::echo      rc=0 res=1   Xschem.log GAINED the line
  wviewer::echo  rc=0 res=1   Xschem.log GAINED the line
Real degraded state (share farm whose ciw.tcl errors on line 1), --nogui:
  EXIT=0   (HEAD: 139 / SIGSEGV)   notify=1 ciw_echo=0   log carries all five notices
Same, on :99 with openbox live, --pipe -q --logdir:
  EXIT=0   (HEAD: 139)   .ciw absent, ase::echo rc=0 res=1, log line present
stderr, once:
  xschem: NOTICE CHANNEL DEGRADED: notices are LOG-ONLY from here on (no CIW
  pane, no status field, no popup, no remedy). Cause: invalid command name "::xschem::notify"
```

Suites: `test_ase_core` 146 → **159**, `test_ase_log_seam_0207` 32 → **41**, every
other tier unchanged (see the commit message).

## DECISIONS (ladder rung, and the rejected alternative)

| # | rung | decision | rejected |
|---|---|---|---|
| D1 | **L3** | **catch the `ciw.tcl` source and guard `ciw_create`**, so a broken/absent `ciw.tcl` yields a degraded-but-alive session instead of a startup SIGSEGV | bootstrap only, and file the segfault — that ships an item whose headline claim is false in the very configuration it is sold on. **This is the E question.** |
| D2 | **L1 (I1)** | the durable-log write is **extracted** into `xschem::notify_log` and consumed by both `ciw.tcl`'s sink 2 and the bootstrap | the bootstrap writing its own `xschem log_action` line — two copies of the same five-line block in two files, the I1 breach 0650 had just deleted, and this issue's rejected alternative #1 |
| D3 | **L1 (I1)** | **one** delegate body, `xschem::notify_safe`, behind both `ase::echo` and `wviewer::echo` | inlining the try-then-fall-back logic into each — those two were byte-identical bodies before 0650 and would become byte-identical again |
| D4 | L2 | the delegates' catch **falls back to the bootstrap** and returns its **honest** sink count | deleting the catch (a notice may never break a pick or a netlist); and keeping the bare `return 0` — 0652's class, a report that lies. Nothing in `src/` or `tests/` read either return value, so the contract was free to be tightened |
| D5 | L2 | the bootstrap also defines a **degenerate latch trio** | a notify-only bootstrap plus a filed issue — measured, `ase::op_cards_nudge_ok` (`ase.tcl:619`) and `_reset` (`:550`) call `::xschem::notify_latch_*` **uncaught** and raise, `ase.tcl:795`'s catch swallows the whole OP-card block, so a notify-only bootstrap turns the log rows green while the user's actually-reported gate-off nudge stays dead |
| D6 | L2 | the bootstrap **ignores** unknown options | mirroring `ciw.tcl:257`'s strict switch — it copies the channel's option table (I1) and destroys R3's sharpest discriminator, since *"the live notify raises on `-no_such_option`"* is exactly how a test tells the real channel from a permissive bootstrap |
| D7 | L2 | degraded mode drops the remedy, the short form, the statusbar and the popup | rendering `Fix: <menu>. CIW command: <cmd>` in the bootstrap — a second copy of the rendered-sentence builder, and R-0653-d's remedy contract is about the **visible** channel, which by definition is not there |
| D8 | L2 | with **no** durable log open at all, the bootstrap echoes to **stderr as a last resort** | total silence under `--nolog` + a dead `ciw.tcl`. This is **not** rejected alternative #2: stderr sits **behind** the durable log, never in front of it |
| D9 | **L1 (I1 honesty)** | the stderr echo is **never** claimed as a sink — `sinks` stays `{}` and the return stays 0 | recording `sinks {stderr}` and returning 1 — it would make a caller believe the user was told (0650's sink table does not contain stderr) |
| D10 | L2 | the announcement is **once per session**, gated on `::xschem::notify_degraded`, fired at the **catch site** so it names the real cause | announcing per notice — 0497 rule 1, *count per pass, never alert per item*; and a per-sink flag, which would let a second file's failure go unannounced |

## THE SABOTAGE MATRIX — 8 variants, 2 exact, 5 supersets, **1 coverage hole**

| variant | predicted | observed |
|---|---|---|
| **A** bootstrap body → live no-op | NT17 NT18 NTD2 NTD3 PS21 PS22 | **superset**: 10 red (+ NT21 NTD4 PS23 PS27) |
| **B** `ciw.tcl`'s channel renamed so the bootstrap wins | NT16 PS20 PS14-16 PS18 PS24-26 F19o F19s | **superset**: 43 red across three suites; every *named* prediction appeared |
| **C** bootstrap block moved **after** the `ciw.tcl` source | NT16 PS20 NTD4 NTD6 PS14 PS15 PS16 PS18 | **superset**: 46 red. ⚠ but see the miss below |
| **D** the `ciw.tcl` source-catch reverted to a bare `source` | NTD2-NTD7 PS27 | **exact**: 7 red, and `NTD bad status` flipped from `{0}` back to `{CHILDKILLED SIGSEGV}` |
| **E** the shared `notify_log` neutralised | 12 named rows | **17 red across BOTH suites** — the strongest evidence for D2: one renamed proc reddens `ciw.tcl`'s sink 2 *and* the bootstrap, i.e. they really do share one builder |
| **F** the delegate fallback reverted to HEAD's silent `return 0` | NT17 NT18 PS21 PS22 PS23 | **superset**: 6 red (+ NT21) |
| **G** the degenerate latch neutralised | NTD5 | **exact**, single-row precision |
| **H** the `ciw_create` guard removed | PS27 | ⚠ **0 red — A COVERAGE HOLE** |

### ⚠ SAB-H APPENDIX — the guard at `src/xschem.tcl:16919` is unfalsifiable today

Removing it reddens **nothing**, in either suite. Measured directly (broken farm,
`DISPLAY=:99`, `--pipe -q --logdir`): the child does **not** die. It prints
`Tcl_AppInit() error: ... invalid command name "ciw_create"` and **continues** —
exit 0, and the `#! ` notice line still lands in `Xschem.log`. PS27's four fields
are `[status, log-count-of-the-message, 'NOTICE CHANNEL DEGRADED' in -out,
'ciw.tcl' in -out]` and **not one of them moves**, because the source-catch at
`:14854` already emitted both strings PS27 greps for.

**What the guard actually buys**, and the discriminator PS27 should carry: the
uncaught raise aborts the **remaining 117 lines** of `src/xschem.tcl`. Measured
guard-removed vs guard-present in the same child:

```
[info commands ::stdin_repl_setup]     0  vs  1
[info commands ::cadence_compat_sync]  0  vs  1
```

Silently skipped without the guard: the `${USER_CONF_DIR}/colors` source, the
`ps_colors`/`svg_colors` regsubs, `setup_tcp_xschem` / `setup_tcp_bespice`, the
`XSCHEM_LIBRARY_PATH` + `new_file_browser_*` + `cadence_compat` variable traces,
and the entire stdin REPL. **The one-line fix:** append a fifth field to PS27's
tuple — the child printing
`[expr {[info commands ::stdin_repl_setup] ne {} ? 1 : 0}]`, expected `1`.
(`svg_colors` is **not** a discriminator: 1 in both.)

### Two further predicted reds that did not appear, and why neither is a hole

* **Variant C / rows NT17 NT18 PS21 PS22.** The driver brief predicted *"move the
  bootstrap after line 14648 → **R1** must redden"*. It does not: relocating the
  block does not delete `notify_bootstrap`, so `notify_safe`'s fallback still
  writes the durable line when `::xschem::notify` is renamed away — R1 is
  genuinely still satisfied by that sabotaged tree. The row variant C really
  breaks is **R3** (NT16/PS20, both red), and R1's *degraded-configuration*
  analogue (NTD2/NTD3) **did** redden. A mis-prediction in the brief, not a gap.
* **Variant E / PS10a, PS10b.** Both are **absence** assertions ("an empty
  `ase::echo` adds no log line"), so they pass identically whether the empty-guard
  works or the whole log writer is dead. Their sibling **PS12a** (the trailing-
  backslash row) *does* discriminate and went red, so the mechanism is covered —
  but PS10a/PS10b on their own prove nothing. **Genuinely weak rows.**

## The ratification this owes (status **E**)

> **Should a broken or absent `src/ciw.tcl` let xschem START in a degraded,
> log-only notice mode — announced once on stderr and once in the durable log —
> instead of today's SIGSEGV at startup (exit 139)?**

Implemented as **yes** (D1, rung L3). Without it the bootstrap is inert in the one
scenario this issue names, and the receipt for that is sabotage variant **D**.

## Still open

Four defects **introduced by this fix**, each measured twice (the adversary leg
and the write-up pass), each filed:

* **0664** — the degradation announcement claims LOG-ONLY **without measuring it**.
  A `ciw.tcl` that errors on its **last** line leaves the full four-sink channel
  live, and the durable log still records the LOG-ONLY claim. 0652's class,
  written into the artifact this issue exists to protect.
* **0665** — **one notice, two durable lines** when the full channel raises after
  sink 2: `notify_safe` re-makes the whole notice through the bootstrap even
  though sink 2 already wrote, and latches a false degradation for the session.
* **0666** — `ase::echo` / `wviewer::echo` **can now raise into their caller**
  when `notify_safe` itself is unavailable, where HEAD returned 0. The catch was
  not deleted, but it moved into the callee and the outermost link is uncaught.
* **0667** — the **degraded GUI user sees nothing on screen**: `.statusbar.12`
  exists and is writable in the degraded state, and the bootstrap deliberately
  writes nothing to it.

Carried over, not caused here:

* **0662** — `sinks` claims `ciw` vacuously. This is why every row in this issue
  asserts on the log **file**, never on the witness field.
* **0663** — the class behind D1: every *other* late `source` in `xschem.tcl` is
  still bare and still segfaults startup on a Tcl error.
* Under `--nolog` (or `--nogui` with no `--logdir`) there is no action log at all
  (`src/util.c:351`), so a degraded notice survives only as the stderr line of
  last resort. Honest, and recorded in the source — the user asked for no log.
* With `ciw.tcl` dead the process now runs on, but **139 unguarded `ciw_echo`
  call sites** remain live and a direct call raises. The C side is safe (every C
  call site uses the guarded `if {[info procs ciw_echo] ne {}}` idiom) and
  load/netlist both work; the Tcl GUI paths are not.
* `notify_last` does **not exist** in the real degraded state (`notify_record`
  lives in `ciw.tcl`), so `notify_bootstrap`'s honest-witness write is dead code
  exactly where it matters. Acknowledged in the source; the tests assert on the
  file instead.
* A **malformed** call silently demotes an error: `notify_bootstrap`'s
  `foreach {o v} $args` drops a dangling `-tag`, so an odd-argument call logs
  `#= ` instead of `#! `. The full channel would have raised on the same shape.
