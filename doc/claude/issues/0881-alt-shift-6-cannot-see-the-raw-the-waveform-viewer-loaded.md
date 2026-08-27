# 0881 - `Alt-Shift-6` cannot see the `.raw` the waveform viewer loaded, and commit `ca39cecb` removed the only bridge

**Status:** OPEN, measured by CODE READING at `ca39cecb`, **not yet reproduced on a
bench**. Filed 2026-08-27. This is the primary path of the feature issue 0868
shipped, so if it is confirmed the feature has never worked end-to-end.

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
