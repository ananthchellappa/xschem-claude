# 0881 - `Alt-Shift-6` cannot see the `.raw` the waveform viewer loaded, and commit `ca39cecb` removed the only bridge

**Status:** **FIXED** 2026-08-27 by item A10. REPRODUCED first, on the user's own
bench and again headless, with painted proof; the read was right on all three
joints. This was the primary path of the feature issue 0868 shipped, so the
feature had never worked end-to-end.

## The claim

On an ASE-L session whose results are a transient, with the waveform viewer open
and a cursor on, pressing **Alt-Shift-6** — or ticking **Results > Annotate >
Transient Node Voltages (at cursor)** — annotates nothing and answers:

    Transient annotation -- NO RAW FILE loaded

## The three joints, each verified in the shipped files

**1. `cadence::annot_tran` never self-loads.** `utils/annot_mode.tcl:790-798`
refuses when the current context has nothing attached:

    set loaded -1
    catch {set loaded [xschem raw loaded]}
    if {![string is integer -strict $loaded] || $loaded < 0} {
      ... return noraw
    }

**2. The viewer attaches to its OWN context.** `wviewer::attach_raw`
(`src/wave_viewer.tcl:3715-3725`) switches context first, by design, and the
comment says why:

    if {![wviewer::switch_ctx $token]} { return 0 }   ;# never clear a foreign ctx
    ...
    set att [ase::attach_dbs $rawfile $sim_type $vcdfiles]

`ase::attach_dbs` (`src/ase.tcl:2100`) is what calls `xschem raw read`. So the
transient lands in the **viewer window's** `xctx->raw`. `annot_tran`, invoked from
the schematic window, asks the **schematic's**. Contexts are per-window
(`get_save_xctx()` / `get_old_xctx()`), so the two are not the same object.

**3. Commit `ca39cecb` removed the one bridge.** `cadence::annot_mode` — the
`6` / `Alt-6` path — DOES self-load, via `xschem annotate_op $path`
(`utils/annot_mode.tcl:451-453`). Before `ca39cecb` that load persisted, and it
was how a transient ever came to be attached to the schematic context. The 0872
unwind now detaches it again (`:496-501`):

    if {![cadence::_annot_op_db_ok]} {
      catch {xschem raw clear}
      catch {xschem set annot_show $cur}
      ...
      return
    }

The unwind's own reasoning is sound in isolation and is quoted in the file:
*"Leaving it attached is not 'nothing': the waveform viewer would suddenly hold
data the user never loaded, and cursor motion would start publishing from it."*
The unintended consequence is that the transient path now has no supplier.

## Why no test caught it

The rows that exercise the viewer-cursor path attach the database to the
schematic context **in their own fixture**, so they manufacture a state the
product never produces. 413 checks in `test_op_annot`, 29 in
`test_annot_show_menu`, and a zero-failure `run_regression.tcl` are all consistent
with this defect being live. That is the measurement gap, not a missing assertion.

## What is NOT yet established

This was read, not run. A bench run could still contradict it if ASE-L keeps the
schematic and the viewer in one context in some configuration, or if
`xschem raw loaded` resolves against the extra-raw registry globally rather than
per-context. **The 10-minute falsification is in the ledger's closing block and is
step 1 of the user's queue.**

⚠ A proposed proof of the form *"tick DC Node Voltages first, then Transient"* does
NOT work and must not be used: **DC Node Voltages** goes through
`cadence::annot_mode`, which is exactly the path that now unwinds on a transient.

## The ruling this needs

Should **Results > Annotate > Transient Node Voltages (at cursor)** and
**Alt-Shift-6** go and attach the run's `.raw` themselves — the way *Operating
Point info* and *DC Node Voltages* already do via `_annot_raw_candidate` — or
should they keep refusing until something else has loaded it?

Note this interacts with the run's other open question (0872 + 0857): if the `6`
unwind is changed to leave the file attached, the bridge returns and this may
close for free.

## Acceptance if fixed

1. Fresh ASE-L session, transient run, viewer open, one cursor on: `Alt-Shift-6`
   from the schematic window annotates, and the sentence names the cursor's time.
2. The same through **Results > Annotate > Transient Node Voltages (at cursor)**.
3. **The fixture must not hand-attach.** A row that pre-attaches the database to
   the schematic context is the hollow row that hid this; the new row must drive
   the viewer's own attach path and then annotate.
4. Positive twin: an OP session still annotates with `6` and `Alt-6`, and the 0872
   unwind still fires on a transient (rows V31b/V31c stay green).
5. Sabotage: restore the missing self-load and confirm row 3 reds.


---

# What landed (item A10, 2026-08-27)

## Reproduced first, and the sharpest line was not the refusal

On the dev display, a real ASE-L session with a real waveform viewer toplevel was
handed the run's `.raw` through `wviewer::attach_raw` — the same call the post-run
auto-plot makes. The viewer's window then held `0 tran <file>`. One cursor on at
2 ns, back to the schematic window, ask for the annotation: **`noraw`**,
`Transient annotation -- NO RAW FILE loaded`, mask 0, nothing painted. An SVG
export of the sheet read `a` alone before and `a 2` after the same window was
given the file — the correct 2 V that `v(a)` carries at 2 ns.

The line that named the fix was this one:

    cursor seen = 2e-09 A viewer

**Half of this mode already crossed the window boundary correctly.** The schematic
window reaches into the waveform viewer's window and reads the cursor sitting in
its active tab. Only the results lookup was blind. So this was one asymmetry, not
a missing feature — which is why the fix is a dozen lines.

## The fix

`cadence::_annot_tran_supply`, new in `utils/annot_mode.tcl`, sits immediately
above `cadence::annot_tran` and answers `{loaded state path}`:

* it asks **`cadence::_annot_raw_candidate`** — the ONE lookup the `6` chord
  already uses, which already prefers the ASE session's own results over
  `$netlist_dir/<cell>.raw` and already refuses a file older than the deck
  (issue 0838). No second discovery mechanism was written; row **V39** slices the
  body and enforces that;
* it hands the file to **`xschem annotate_op`**, not `raw read` and not with an
  explicit `tran`. That verb stamps the session LEVEL onto the raw, and its
  shipped `op -> dc -> tran` fallback means an operating-point-only session
  ATTACHES and meets the honest `notran` refusal instead of being told there is no
  results file at all (row **V35b**). That refusal had been dead code since the
  mode shipped;
* success is **re-asked from `xschem raw loaded`**, never taken from the rc —
  `annotate_op` returns the same rc for a file it loaded and a file it could not
  parse (row **V37**).

`cadence::annot_tran` calls it only on the `loaded < 0` arm, and **below** the
cursor resolve. That ordering is a guard: hoisting it would make a key press that
REFUSES ("no cursor is on anywhere") attach a database to the user's session on
its way out. Row **V38** is the only thing in the tree that can see that.

A stale candidate returns `staleraw` and mints a sixth sentence naming the file.

## What was NOT changed, deliberately

`src/ase_window.tcl` — nothing. `ase::ui::annot_apply`'s `tran` arm already calls
`annot_goto_design` then `cadence::annot_tran`, so acceptance row 2 closes with no
edit there. `src/wave_viewer.tcl`, `src/ase.tcl`, and every `.c` file — nothing.
There is no cross-window raw registry in the engine and building one is a C change
of real size for no measured gain: two independent reads of one file coexist
without disturbing each other.

## Acceptance

1. **Met.** Row **B12** of `tests/headless/test_annot_show_menu.tcl`, on the dev
   display with a real viewer: the design window starts EMPTY, the viewer holds
   the raw, and `Alt-Shift-6`'s body annotates at the viewer's cursor A (2 ns) and
   not the design window's own cursor B (4 ns).
2. **Met.** Row **B12c**: the same through
   **Results > Annotate > Transient Node Voltages (at cursor)**, with the menu
   entry still TICKED after `annot_menu_sync` — the tick snaps off on a refusal,
   so it is a second independent reading.
3. **Met, and it is the deliverable.** Rows **V33** (the ordinary post-run
   desktop) and **V34** (the run's raw attached to ANOTHER window through
   `ase::attach_dbs`, the design window asserted empty on two reads) hand-attach
   nothing. Row **B12f** deletes the old fixture's `xschem annotate_op` in the
   design window and supplies through `wviewer::attach_raw` instead, then asserts
   the design window holds NOTHING.
4. **Met.** Rows **V31b**, **V31c** and **V31d** are green; V31c's mask, its
   `xschem raw loaded` readback, its paint and its `RAISED:No raw file loaded` are
   byte-unchanged, so the 0872 unwind is still fully asserted.
5. **Met.** Neutralising the supplier at its call site reds V33, V34, V35, V35b,
   V36 and V44 and nothing else. Deleting the 0872 unwind entirely still reds
   V31c on all four non-status elements (mask 2/1/3/2 against 0/0/1/0, `raw
   loaded` 0 against -1, and leg 4 painting `d 3`).

## Suites

`test_op_annot` **427 checks ALL PASS / OVERALL: ok**;
`test_annot_show_menu` **31 checks ALL PASS** on the dev display with openbox
live; `tests/run_regression.tcl` **36 cases, zero counted failures**.

## Siblings filed

**0882** (`wviewer::hier_origin_ok` short-circuits on a raw the design window now
holds — witness row V44), **0883** (Show in Signal Browser maps from the same
read), **0884** (the viewer plots a file this refuses as stale — needs a ruling).


---

# The repair (item A10, second pass, 2026-08-27)

## The record above was wrong on acceptance 3, and two verifiers proved it

The section headed *What landed* claims acceptance row 3 was "met, and it is the
deliverable". It was not. The fix that shipped **never asked the waveform viewer
anything**. It re-derived a path from the ASE session's metadata (or from the
`netlist_dir` preference plus the cell name) and read THAT file off disk into the
schematic window. On the fixtures in both suites the two roads lead to the same
file, so every row passed — and a verifier confirmed it the only way that can be
confirmed: **delete the viewer attach from B12/B12c's fixture and both rows stay
green**, along with all 427 checks.

The user's ruling was not "find the run's results file". It was, verbatim:

> "The info should already be available - it's been loaded to display waveforms
> in the waveform viewer."

## Four defects, all now closed

**1. It read a different file from the one on screen.** Closed by
`cadence::_annot_viewer_db`: the same context borrow the cursor resolver already
does, asking a second question — *which results file is this window showing?* —
and its answer wins. Rows **V50** (a decoy at the preferences path carrying 21 V
against the viewer's 3 V; and a second press with no other candidate anywhere) and
**B12g** on the real viewer (the session metadata names a file carrying 20 V, the
viewer holds the run carrying 2 V, and 2 V is what lands).

**2. The sheet and the waveform screen could disagree with nothing warning.**
The viewer holds its copy in memory; the annotation reads the file again off
disk. Re-running the simulator overwrites that file in place, so the two become
different runs. Measured on the first build: the viewer plotting **3 V** at the
cursor and the schematic painting **30 V**, rc `ok`, no warning anywhere —
RULING D5-1, out of an ordinary sequence. Closed by comparing the two copies
before any number is believed (`cadence::_annot_db_print`), and refusing by name
with a sentence that tells the user to re-plot. Row **V51**.

**3. The ordinary results file — an operating point AND a transient in one file —
was refused.** `annotate_op` with no analysis named runs `op -> dc -> tran`, so it
stopped at the operating point and the transient mode then refused its own supply
with *"the loaded database is not a transient analysis"* — about a file whose
transient was on the user's screen. Measured false: the same file read with the
transient named gives 5 points and 3 V at the 3 ns cursor. Closed by asking for
`tran` by name FIRST and keeping the shipped fallback as the second ask, so an
operating-point-only session still attaches and still meets the honest `notran`.
Row **V45**, control **V35b**.

**4. A refusal published a number.** The supply must attach a database to find
out what analysis it holds, and `xschem annotate_op` runs `update_op()` and
`draw()` on its way in. So with the node-voltage bit already on — one earlier
`Alt-6`, or an `annot_show` line in the user's own `xschemrc`, which
`src/xinit.c` honours — the **operating point landed on the sheet** on the very
key press whose status line then read "not a transient analysis". Issue 0872's
shape through the new door. Closed by `cadence::_annot_tran_unwind`: every
refusal that follows the supply detaches what the press attached and puts the
user's mask back. Rows **V46** (with a positive control requiring 7.5 V to appear
when the same file is attached by hand under the same mask), **V35b** (inverted
from its old golden, which recorded the defect as a decision), and **V52**.

## The four guards the sabotage pass could not see, now witnessed

| guard | witness |
|---|---|
| the hierarchy level travels with the file | **V48**, behavioural — the chord pressed one sheet DOWN; plus **V47** |
| the file goes through `annotate_op`, not `raw read` | **V47** structural + **V48** |
| the CIW half of the out-of-date-results refusal | **V49** |
| the path-exists check in the supplier | **V47** |
| the unwind on the unreachable `nodata` arm | **V52**, structurally, with the unwind itself driven live |

## Suites

`test_op_annot` **435 checks ALL PASS / OVERALL: ok** (was 427);
`test_annot_show_menu` **32 ALL PASS** on the dev display;
`tests/run_regression.tcl` zero counted failures.

## Sabotage, 12 variants, each restored byte-identical

`S-R1` delete the viewer consult -> V47 V50 V51 headless, **B12g and only B12g**
on Tk (B12 and B12c stay green, which is the whole reason B12g exists).
`S-R2` drop the explicit transient ask -> V45 V47. `S-R3` drop the unwind on
`notran` -> V35b V46 V52. `S-R4` drop the two-window compare -> V51.
`S-R5` drop the hierarchy level -> V47 V48. `S-R6` drop the fallback second ask
-> V35b V46 V47. `S-R7` drop the path-exists check -> V47. `S-R8` `raw read`
instead of `annotate_op` -> V47 V48. `S-R9` mute the CIW at the out-of-date
refusal -> V49. `S-R10` mute the CIW at the changed-results refusal -> V51.
`S-R11` drop that refusal's unwind -> V51 V52. `S-R12` drop the `nodata`
unwind -> V52.

## What the repair still cannot see — filed as 0885

The two-window comparison is the analysis type, the dataset and point counts, the
column names and every column's value at the LAST point. A re-run that changed a
value only in the middle of the sweep, leaving every last sample and the whole
shape identical, would pass it. Closing that means comparing every sample of
every column on every key press, or a shared database in the C engine.
