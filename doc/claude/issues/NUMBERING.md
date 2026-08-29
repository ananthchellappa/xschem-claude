# Issue number reservations — read before filing

Two blocks are reserved for other branches. Filing into them collides with work
this branch cannot see, and the 02xx renumbering recorded in `status.md` is what
that costs to undo.

| block | owner | rule |
|---|---|---|
| **0500–0599** | the fluid-editing branch | after **0499**, the next number is **0600** |
| **0700–0799** | reserved (user, 2026-08-24) | after **0699**, the next number is **0800** |

So the filing sequence is:

```
… 0498  0499  0600  0601 …  0698  0699  0800  0801 …
```

Highest filed on `annotate` as of 2026-08-25: **0805** — the 0689+0690+0698 crew
filed **0802** (full_audit scores a pass banner followed by a death marker as PASS),
**0803** (`execute`'s modal dialog hangs any suite under X), **0804**
(`test_ase_core` NT14 asserts headless-only behaviour in both arms) and **0805**
(full_audit's pass arm is prefix-anchored only), so **the next number is 0806**.
Before that: **0801** — the 08xx block is now
OPEN (0699 was the last 06xx number; **0800** and **0801** were filed by the
0674+0675+0677 crew, so the next number is **0802**). Earlier: **0698** (0668-0673 filed by the
0663 crew; 0674-0677 by the 0664+0665+0666 crew; 0681 by the 0678 crew; 0679/0680
by concurrent crews; 0683-0684 by the 0682 crew; 0685-0690 by the 0683+0684 crew;
0691-0692 by the 0679 crew; 0693-0696 by the 0691+0692 crew; **0697-0698 by the
0695+0696 crew**). ~~The next number is **0699**~~ — ~~0802~~ superseded: 0802-0805
are filed too; **the next number is 0806**.

`status.md` covers the fluid-editing branch and its 02xx numbering.
`status_annotate.md` covers this branch, 0600–0698. They do not share a number
space. `status_annotate.md` §6d records the 0800/0801 filings; 0802-0805 came from
the 0689+0690+0698 harness-trust commit.

**2026-08-25, item 0812-retry write-up.** The block has moved a long way past the
paragraph above, which stopped at 0806. Filed since: **0807-0811** (the 0688+0683 crew),
**0812-0814** (the 0807 crew), **0815-0817** (the 0812 attempt-1 crew), **0818** (the
0812-retry plan agent), and **0819-0821** by this write-up, from the late adversary pass on
0812-retry — **0819** (`Tcl_GetVar2Ex` fires READ TRACES, so the resolver's "no evaluator"
comment was false; mitigation pinned by GUARD3), **0820** (a graph `%` rawfile field is
resolved twice, so `resolve_rawfile_path()` is not idempotent in general and read/clear can
disagree about a registry key), **0821** (a Tcl-side splice of the same shape: `src/xschem.tcl:4775` `graph_fill_listbox`
ran `subst` over a `.sch` `rawfile=` attribute).

**2026-08-25, item 0821+0816+0817 write-up.** Filed since: **0822** (the lead — `autoload`
and `sim_type` execute from a `.sch` attribute too), **0823**, **0824**, and by this item
**0825** (the three sym-path wrappers splice a `.sch` symbol name, so a plain `xschem load`
executes Tcl — found, filed and fixed in one commit), **0826** (test_wave_markers MX7b/MX7d
go red on a Tk key-delivery stall), **0827** (⚠ **LIVE**: `cellview_sch_path()`,
`src/actions.c:4215`, splices a `.sch` `schematic=` attribute, so a plain descend executes
Tcl), **0828** (three anti-hollow rows in the new GDI group stay green when the Graph
dialog's attribute intake is inert).

**0821 and 0822 are FIXED** — `src/xschem.tcl:4775` is no longer live and no line of this
file should still be quoted as evidence that it is; so are **0816** and **0825**. **0817**
is open and now has a driven vector.

~~**The next free number is 0829.**~~ superseded, see below.

**2026-08-27, the annotation driver run (items A0-A9).** The block has moved past
0829 several times over. Filed on this run: **0859-0867** by the earlier items, and
**0868** by item A3 (the on-request transient annotation, which also closed 0865),
then **0869-0876** by A3's write-up from three verification passes —
**0869** (the transient sentence names the REQUESTED time, not the measured one:
RULING D5-1), **0870** (`xschem annotate_at <unparseable>` publishes at t = 0 and
reports success), **0871** (the `nodata` refusal is unreachable and its golden is
hollow), **0872** (bit1 and bit2 share one render class, so `Alt-6` repaints a
transient's numbers as OP node voltages — RULING 0856 reopens), **0873** (guard G9,
"refusals speak", has no row), **0874** (the widened `text_hidden()` voltage arm has
no row), **0875** (row B12b cannot see a leaked viewer-context borrow), **0876**
(0868's eight C guards were never sabotage-tested).

Nothing new was filed for `test_ase_window` W7's flake: it is **0642**, and it got a
third dated sighting appended rather than a fourth number. See CLAUDE.md on 0689/0690
for why that matters.

**2026-08-28, the annotation driver run continued (items A10-A12).** Filed
**0877-0893** by the later items, then **0894-0898** by item A12's write-up:
**0894** (three of A12's own guards had no row that could see them removed — one
of them the routing that keeps the regression runner off the user's real screen;
fixed in the same commit), **0895** (issue 0893's truthful refusal sentence
misses its commonest trigger — a *deleted* results file, not a corrupt one),
**0896** (the two-window compare is skipped entirely while a run is still
filling, and another run's numbers reach the schematic — a live RULING D5-1
violation), **0897** (the plain-English refusal-sentence lists are
hand-maintained with no completeness check), **0898** (T1's new display arm gives
a wall-clock row two chances to flake on a loaded box).

**2026-08-28, item A13's write-up.** Filed **0899** by A13's sabotage pass (two
of A13's own guards had nothing able to see them go), then **0900** and **0901**
by this write-up, from A13's adversarial verification pass — **0900** (a second
Alt+Shift+6 skips the consult, both new guards and the two-window compare,
because the supply is called only when the design window holds no database, so
the previous run's numbers stay on the sheet: a **live** RULING D5-1 violation,
filed not fixed, same predicate mistake as 0684) and **0901** (A13's new
"still filling" sentence tells the user to wait for a run that has already
finished).

**2026-08-28, item A14's repair pass.** Filed **0902** — item A14's own gate
unloaded every database in the design window rather than the one it was talking
about, so a mixed-signal bench holding an analog run *and* a co-simulation VCD
lost both on one `Alt-Shift-6` and the sheet's digital back-annotation went
blank. Found by A14's sabotage pass, reproduced mechanically against the shipped
tree, and **fixed in the same commit** (the detach names its file and never
touches a digital database — RULING D5-3). Rows V72, V73, V75 behavioural and
V74 structural.

**2026-08-28, item A14's write-up.** Filed **0903**, **0904** and **0905**, each
measured by the write-up agent itself rather than inherited. **0903** — item
A14's fix revalidates against the ASE **waveform window** and only that, so with
no waveform window open and the cursor read off the schematic's **own** graph, a
second `Alt-Shift-6` still repaints the previous run's numbers: issue 0900's own
defect through a door 0900's fix does not reach, a **live RULING D5-1**
violation, reproduced on both arms, **filed not fixed**. **0904** — the cost of
revalidating on every press scales with the number of **saved vectors**, not with
points, and A14's published table swept points at a fixed 200 columns; an 11 MB
`.save all` database revalidates in 55.9 ms against 0.014 ms for a 995 KB one, so
the shipped *"+0.46 ms, the whole price of revalidating"* is true of one database
and false as a claim (issue 0899's class). The claim is corrected in that commit;
the cost is open and no row measures it. **0905** — two concurrent
`tclsh run_regression.tcl` runs truncate each other's `results.log` to **0
bytes**, and an empty summary contains no `FAIL`, `FATAL` or `GOLD?`, so the
wreckage of a destroyed verdict reads as a clean pass to every reader in the tree
and to a human: the same fail-open class as **0147**, one level further back.

**0906** — a new PDK cannot get device-OP annotation without hand-writing an
undocumented descriptor: only three PDK profiles call `op_annot::register`, so on
any fourth the six-row device block is empty **forever and silently**, and
`op_annot::register` appears in no user-facing document. Filed at the user's
request with a spec for a Python bootstrap script
(`doc/claude/specs/pdk_annotation_bootstrap.md`); **docs only, not to be worked
on yet**.

**2026-08-28, item A15's implementation (the issue 0684 fix).** Filed **0907**
and **0908**, both measured while fixing 0684 and both left OPEN. **0907** — the
`live` status line, *"These results were already loaded."*, never names the file
it is talking about, while the `loaded` line one arm away does; after 0684 those
two sentences are the only thing on screen distinguishing "the run you just did"
from "a database somebody attached earlier". **0908** — 0684's fix deliberately
leaves a database at a path other than the session's candidate exactly where it
is, so the tick can still show another corner's operating point; replacing it
would DESTROY it (`scheduler.c`'s delete-previous-OP branch, measured to drive
row W1a16's sentinel from 0 to -1), which is the data loss the reverted
2026-08-25 attempt created. Both need a user ruling.

**0909** — the blank-device-row explanation is a NAG fired at netlist time, not
an ANSWER given when you press `6`. Filed from a user reproduction on `tb_bandgap`
(OP-only, save-cards gate off): six blank rows, no CIW line. Nothing was removed —
`ase::op_cards_capture` still prints the menu path and the pasteable CIW command,
but behind `notify_latch_ok` (`src/ciw.tcl:187`), a **one-turn latch per cellview
per session**, so it speaks on the first Netlist-and-Run and never again. The `6`
path has **no state for it at all** (`grep -c` for any params-missing state in
`utils/annot_mode.tcl` = 0). A suppression latch is right for a nag and wrong for
an answer to a direct question. ⚠ The approved `save_op_params` default flip must
land AFTER this or it masks it.

**2026-08-28, item A15's adversary + write-up pass (still the issue 0684 fix).**
Filed **0910**, **0911** and **0912**, all three measured on the delivered tree
and all three the SAME defect 0684 names, surviving in states the fix does not
reach. **0910** — a database attached by `Simulation > Graphs > Annotate
Operating Point into schematic` or `Waves > Op Annotate` is trusted **forever**
at the very same path, because guard G3a stamps at the first *observation* and
not at the attach. **0911** — on a descended sheet with no ASE-L session the
candidate names the SUBCELL's raw, so the chord never repairs and
`Waves > Clear` then `6` reports "There is no results file at …/sub.raw yet"
about a run that just finished. **0912** — when the results file is deleted, the
`Results > Annotate` tick keeps the numbers and `6` blanks them: the two
operating-point surfaces disagree and only one speaks. 0684 §8's route table
said "every route" and has been corrected; §10 records the pass.

**2026-08-28, item A16 (the fix for 0909).** Filed **0913** — the blank-row
probe rides `cadence::_annot_scan`'s existing per-*cell* dedup, so one device
whose vectors are missing while its cell siblings populate is never looked at.
Recorded as an accepted limitation of 0909's fix and needing a user ruling on
whether to pay per-*device* for exactness.

**2026-08-28, item B1 (the fix for 0910).** Filed **0914**, **0915** and
**0916**. **0914** — with a waveform graph open in the same window, taking a
stale operating point off is a one-way door: `cadence::annot_mode` asks
`xschem raw loaded` right after its own detach, that question answers "is ANY
database attached", the user's graph answers yes, and the press blanks the sheet
instead of reloading. Found by B1's own sabotage pass, **fixed in the same item**
— half of it was a regression from 0910's first-sight re-read and half was live
on the shipped tree. **0915** — a re-run inside the same wall-clock second at the
same byte length is invisible to the `{mtime size}` freshness stamp, so from the
second press on the sheet keeps the previous run's numbers; named as a limitation
in three places since 0684 and never given a number until now. **0916** — when
`<netlist_dir>/<cell>.raw` is a **symlink** to the file the menu attached,
`file normalize` does not resolve the final component, so 0910's own same-path
test never fires and its §1 transcript reproduces word for word on a tree where
0910 is marked FIXED. 0915 and 0916 are OPEN; both are measured, neither is a
regression from this item.

**The next free number is 0917.** 0500-0599 and 0700-0799 remain reserved for
other branches. No 09xx block is reserved: the three tracked sources — this
file, `CLAUDE.md` and the auto-memory note — record only those two, so 0899 is
followed by 0900.
