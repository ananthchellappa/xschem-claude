# Crew brief — the RDW + simulator-identity batch

## What the user reported, in their words (verbatim, do not paraphrase in issue files)

> (Up,Down buttons in RDW seem to be doing their job. I only checked Annotate list though)
>
> **Issues**
>
> enhancement : add a button to allow user to manipulate font size in RDW. it can
> be the "aa" button you see in e-readers - 2nd a bigger. Key part, as soon as user
> hovers over it, tooltip should be displayed : click to increase font one unit.
> Ctrl+click to decrease font one unit
>
> Few things broken. When user is in print to RDW mode (1,2,3 key) and then clicks
> on an instance, RDW needs to be raised, but focus should return to the schematic
> window. Else, another click to look at another device's OP info does not have
> intended effect - it just focuses the schematic window and doesn't send the OP
> info for that device to RDW
>
> /tmp/Xschem.log.8 : which version of ngspice did the most recent run use? It's
> very confusing.. in ASE-L, to know if a change has had desired effect. In the
> ASE-L, in status bar, Simulator: <name> should show the correct name. If user has
> designated (registered) a new instance of ngspice named ngspice-ver50, and the
> "use this one:" field shows that, then the status bar in ASE-L should show that.
>
> If the run *is* using ver_50, then why is case-mode support not showing up? What
> needs to be done for that? I plot the VBG net from top level of
> sky130_tests_ase/tb_bandgap and it plots v(vbg) not v(VBG). What's going on? I
> thought we nailed this weeks ago.
>
> I guess ver_50 *is* being used because 3 key did send ALL OP info parameters - a
> lot of them, to RDW.
>
> I put cursor on cgs and the clicked Add button and said add to all mos (why is
> that not uppercase? MOS is an acronym!) for summary list, but, later, when I send
> summary list with 2 key, it never shows up.
>
> For each devices, is being printed:
>
> Not a complete list: these are the operating-point columns this run saved for
> this device, not everything the device has.
> Narrowed to the mos annotation list as it stood at this dump. 82 columns are not
> in that list and not shown; this run published 88 for this device. Press 3 for
> everything this run published.
>
> This is too verbose! Just say "annotated list" or "summary list"

## The user's bench, so nobody re-derives it

* Design `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch`,
  descended `x1` → `x1`, device `M18`.
* `~/.xschem/ase_simulators` holds exactly:
  `ase::sim_register ngspice-ver50 /home/analog/dev/ngspice/build-ver_50/src/ngspice -args {} -backend {} -casemode {} -nospiceinit 0`
  followed by `ase::sim_select ngspice-ver50`.
* Their action log is `/tmp/Xschem.log.8`. **DO NOT WRITE TO `/tmp/Xschem.log.*`.**
  Every launch you make gets `--logdir <your scratch dir>`. Issue 1359 is the scar:
  a crew destroyed this user's log twice in the last session.

## What the driver MEASURED before the crews started

Read from the running binary with the user's own HOME, not inferred:

    ase::sim_status ngspice   -> ok 1  resolved .../build-ver_50/src/ngspice
                                 source registry  entry ngspice-ver50
    ase::sim_capabilities     -> known 1 usable 1 appendwrite 1 blanket_op_save 0
                                 hier_op_names 1
                                 casemode_detected {fold preserve distinguish}
                                 altshow_op_dump 1
    ase::sim_casemode_detected   -> fold preserve distinguish
    ase::sim_casemode_selectable -> fold preserve distinguish
    ase::sim_casemode_requested  -> fold
    $::sim_case_mode             -> fold

**So the case-mode answer is already correct and already measured. The user gets
`v(vbg)` because NOTHING ASKS FOR `preserve`.** `ase::sim_casemode_requested`
(`src/ase.tcl:1931`) reads the registry entry's `casemode` field, which is `{}`,
and falls to the global floor `sim_case_mode`, which `set_ne`s to `fold`
(`src/xschem.tcl:18513`). `ase::run_casemode_flag` (`src/ase.tcl:2517`) emits no
`-D casemode=` at all for a `fold` request.

And there is **no door**: `ase::ui::simdlg_editor` (`src/ase_window.tcl`) builds
exactly two rows, `Name:` and `Program:`. It offers no case mode, no `-args`, no
`-nospiceinit`. A capability the program measures, publishes and can act on is
unreachable from the GUI that measured it. That is the defect, not the probe.

Also measured, and it is a separate hazard to confirm: `simdlg_editor` fills the
Edit… form from `ase::sim_list`'s `path` only. Check whether a re-register from
Edit… silently drops `args`, `casemode` and `nospiceinit`.

The status bar reads `Simulator: [ase::state_get $st simulator]`
(`src/ase_window.tcl:6130`) — the state's backend word, not the registered
instance name the user chose in "Use this one:".

## The seven items

Each item gets its own issue file under `doc/claude/issues/`, its own rows in a
suite, and its own paragraph in the write-up.

| id | item |
|---|---|
| **1368** | RDW font-size control: an `aA` button, hover tooltip "click to increase font one unit. Ctrl+click to decrease font one unit", Ctrl+click decreases. |
| **1369** | The RDW raise takes the keyboard on the user's own X server, so the next canvas click only restores focus and sends no dump. |
| **1370** | ASE-L status bar names the backend, not the registered simulator the user selected. |
| **1371** | A measured `casemode_detected` has no GUI door: the Simulators editor offers Name and Program only, so `preserve` is unreachable and every net folds to lower case. |
| **1372** | Add from list 3 with the dialog set to the summary list does not show up when key 2 is pressed afterwards. |
| **1373** | Device-class acronyms are printed in the internal lower-case spelling ("every device of class mos"). |
| **1374** | The narrowed-dump preamble is three sentences where the user wants a label. |

## Standing rules — every one of these has a scar behind it

1. **Never a bare `xschem`.** `/usr/local/bin/xschem` is 3.4.6 from Jan 2025 and
   rewrites the user's recent-files list (issue 0924). Use `./src/xschem`,
   `$XSCHEM`, or `tests/headless/devdisplay.sh exec ./src/xschem`.
2. **Every launch carries `--logdir <scratch>`.** See issue 1359 above.
3. **Never touch the user's `~/.xschem/` files**, and never `git checkout --`,
   `git restore`, `git stash` or `git clean` against uncommitted work.
4. **Do not run `tests/run_regression.tcl`.** The driver runs it, solo (issue 0990).
5. **Do not commit.** The driver commits. Leave the tree with your edits in place.
6. **GUI work runs on the dev display**: `tests/headless/devdisplay.sh start` then
   `devdisplay.sh exec ./src/xschem …`, or `--nogui` where the item allows it.
   Never a bare run on a live `:0` — `$DISPLAY` here is the user's real screen.
7. **Acceptance is a name+status diff, never a count.** Every new suite row must be
   proved non-vacuous: sabotage the fix, watch the row go RED, restore by `cp` and
   verify the md5 matches. Report the red set by name.
8. **Suites that carry a check-count floor must have it raised**, with the file's
   own `AND RAISED N -> M` paragraph.
9. **`doc/claude/issues/NUMBERING.md` is the only authority on numbers.** Your
   number is assigned above; record it in NUMBERING.md's tail as part of your work.
10. **UI copy: terse, and acronyms in upper case.** The user's two rulings this
    round. A label beats a paragraph. `mos` is an internal key; `MOS` is what a
    person reads.
11. If your item needs a decision that is the user's to make, do not invent one —
    file it and `tests/headless/owed.sh add rule <id> <why>` (add `--eyes` if it
    cannot be settled without looking at pixels). Pixel deliverables get
    `owed.sh add look`.
