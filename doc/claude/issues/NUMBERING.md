# Issue number reservations — read before filing

Four blocks are reserved for other branches. Filing into them collides with work
this branch cannot see, and the 02xx renumbering recorded in `status.md` is what
that costs to undo.

| block | owner | rule |
|---|---|---|
| **0500–0599** | the fluid-editing branch | after **0499**, the next number is **0600** |
| **0700–0799** | reserved (user, 2026-08-24) | after **0699**, the next number is **0800** |
| **1000–1199** | reserved (user, 2026-08-30) | after **0999**, the next number is **1200** |
| **1500–1599** | the op-wcard branch (hierarchical PDF links) | after **1499**, the next number is **1600** |

So the filing sequence is:

```
… 0498  0499  0600  0601 …  0698  0699  0800  0801 …
… 0998  0999  1200  1201 …  1498  1499  1600  1601 …
```

## `1500–1599`, and the absorption map — for the tree that renumbers

`1500–1599` is reserved because a **second checkout of this repository**,
`~/dev/xschem-op-wcard`, filed into `1333–1348` at the same time this branch did. This
file is **tracked and per-branch**, so neither tree could see the other and both tails were
honest. Sixteen numbers in `1333–1348` name two different defects each. **As of 2026-09-10
10:46 -0700, twelve numbers named two different files** — 1338, 1339 and 1344–1353 — and the
set was still growing as this sentence was written: the other clone filed four more issue
files between 10:19 and 10:45 that morning, and its own tail pointer had reached **1354**.
Every count here is a timestamped observation, not a standing fact. Full record, evidence,
and the options still open to the user in
`doc/claude/issues/1400-two-clones-filed-the-same-issue-numbers-and-neither-could-see-the-other.md`.

**This branch does NOT renumber. This map is for the tree that does** — apply it to
op-wcard's numbers when that work is absorbed. Nothing in `fluid-editing` moves.

```
1333 → 1500     1337 → 1504     1341 → 1508     1345 → 1512
1334 → 1501     1338 → 1505     1342 → 1509     1346 → 1513
1335 → 1502     1339 → 1506     1343 → 1510     1347 → 1514
1336 → 1503     1340 → 1507     1344 → 1511     1348 → 1515
```

A single **+167** offset. Source and target bands are **disjoint**, so a rewrite cannot
alias one number onto another mid-pass, and the arithmetic is checkable by eye.

⚠ **The map is not the whole exposure.** op-wcard's own next-free pointer is already
inside `1349–1399`, every number of which this branch has committed. Whoever performs the
absorption settles that band too. Issue **1400** carries the measurement.

⚠ **This has already cost a real ruling, and the ledger did not report it.** The shared
`owed.sh` rule ledger (`~/.claude/xschem_owed/`) lives in `$HOME`, outside both checkouts,
so a number that means two things means two things there too. On **2026-09-10 at 10:46:14
-0700** the other clone's `owed.sh add rule 1351` truncated this branch's standing,
unanswered ruling **in place** — exit 0, printed `recorded`, no warning, no pre-image — and
it was recovered only because a hand-taken `cp -a` backup happened to exist. Both 1351
rulings now stand (`rule/1351`, `rule/1351@xschem-claude`), both unanswered.
`tests/headless/owed.sh` in **this** checkout now stamps each entry with its clone and
refuses a cross-clone `add`/`clear`; **the other checkout runs its own older copy, so that
protection is one-sided until the repaired script reaches it.** Issue **1400** carries the
measurements. This paragraph is at the head on purpose: a merge of the two trees folds the
lower half of this file into one conflict hunk and leaves this section alone.

**Who moves is the USER's ruling, not this file's**
(`doc/claude/numbering_batch/DECISIONS.md` D-3, unratified), carried as a `rule` debt
against **1400**. The reservation and the map are published so the absorption is ready;
they do not decide it.

⚠ **The `next free number` pointer at the tail of this file is PER-CLONE.** On a merge
between two checkouts, prefer the **higher** of the two tails and grep both clones'
`doc/claude/issues/` before minting. The fuller warning is at the tail, next to the pointer
— this copy is deliberate duplication, because a merge of these two trees folds the whole
lower half of this file into a single conflict hunk that swallows the tail copy, and leaves
this head section untouched.

## The running record

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

**2026-08-28, item B2 (the fix for 0911).** Filed **0917**, **0918** and
**0919**, all three found by B2's own adversary/guard-coverage pass against the
delivered tree, and all three **invisible to every suite in the tree** — the
annotation tier list and all 44 blocks of `run_regression.tcl` are green with
every one of them live. **0917** — 0911's fix answers the results file from the
TOP of the hierarchy always, which moves 0911's own symptom into the
standalone-block workflow, where it is SILENT: with the chip's raw and a fresh
block raw both in `netlist_dir`, descending into the block and pressing `6`
paints the chip run and keeps painting it after a block re-run, under "These
results were already loaded". Rule debt 0911's options A and B *both* answer the
chip's file there, so 0917 §3 adds options C/D/E to the menu. **0918** —
`cadence::_annot_tran_supply` reads both halves of the same candidate, so the
same two lines moved **Alt-Shift-6** in both directions (a repair on a
chip-level transient, a regression on a block-only one), and left `$path` and
`$lvl` sourced from two different subjects when the waveform viewer supplies the
file. **0919** — two of 0911's own acceptance rows gold a whole sentence against
`xschem get statusmsg`, which is capped at 255 bytes; at this checkout path there
are 50 characters of headroom, so a worktree or a deeper clone false-reds a
correct tree. All three OPEN. 0917 and 0918 need a **user ruling**, together.

~~**The next free number is 0920.**~~ superseded, see below.

**2026-08-29, item B3 (the fix for 0861).** Filed **0920**, **0921** and
**0922**, all three found by B3's own plan/sabotage/verification passes against
the tree B3 delivered, and all three OPEN. **0920** — `xschem raw value <vec> 99`
on a 3-point database answers the value at the *annotation* point wearing the
label of a point that does not exist; the same D5-1 class one argument over,
milder because the number is real and the *label* is what is fabricated. B3's
guard blanks it only where nothing was published at all, and row `SGN18` of
`tests/headless/test_spice_get_node_0861.tcl` pins BOTH halves so the remaining
behaviour is chosen rather than inherited from where a brace landed. **0921** —
`SGN19`, the structural lock over the reconciled inventory comment in
`src/save.c`, asserts only the ABSENCE of two retired phrases; sabotage variant
S5b deleted the entire issue-0861 paragraph and all 23 checks stayed green, so
the comment that is the only thing telling a future author to guard a new reader
can be tidied away silently. **0922** — an **expression trace** added from the
waveform viewer (`xschem raw add`) gets a fresh `cursor_b_val` slot initialised
to `0.0` while `annot_p` stays published, so every `@spice_get_node` text naming
it paints a fabricated `0` on the schematic. Not a regression from 0861 — the
pre-fix read produced the identical zero — but it walks straight past both of
0861's guards, because `annot_p` answers "was an annotation published", never "is
THIS column's slot a measurement". It self-heals on a transient the moment the
cursor moves and **stands indefinitely on an operating point**, where there is no
cursor to move.

**2026-08-29, the ruling pass on 0682.** Filed **0923** — an unticked
`Results > Annotate` tick box means BOTH "the numbers are off" and "I could not
find out", and looks identical in the two states, so the menu can say the numbers
are off while they are on the schematic in front of the user. Carved out of
0682's ratification deliberately: it is a defect inside the ratified shape, not an
argument for a different shape.

**2026-08-29, the user's Open Recent report.** Filed **0924** — `File > Open
Recent` empties whenever a stock xschem touches the same `~/.xschem/recent_files`.
Two spellings of one variable: this tree writes `set tctx::recentfile`, stock
xschem writes `set recentfile`, neither could read the other, and the older build
rewrites the whole file. FIXED the same day, both directions, with
`tests/headless/test_recent_conf_compat_0924.tcl` (17 checks, 7 red pre-fix).

**2026-08-29, the adversarial review of the 0924 fix.** Filed **0925** — saved
net-highlight styles are discarded at every startup: `load_net_hilight_conf`
sources two conf files inside the proc frame, so their unqualified names become
throwaway locals. 0924's read half, unfixed, in the same file, and the suite that
should catch it sources the conf itself instead of calling the loader. And
**0926** — a stock-written `~/.xschem/simrc` would strip Spectre from this tree's
simulator list (latent; no simrc on disk).

**2026-08-29, the user's Save-All default request.** Filed **0927** — device
OP-parameter saving was off by default, so every pre-existing test bench showed
blank rows until the user ticked a box per bench. Flipped ON at the user's
instruction, with `{}` (the value that is never written to disk) reassigned from
"off" to "the default, which is on" — so the flip cost zero bytes on disk and
the 104 committed `.state` files were not touched. FIXED the same day; five
suites went green, and issue 0637 item 1 closed along the way.

**2026-08-29, the user's challenge to 0927** (*"you're telling me we have to
have a .save card per every device existing in the design?"*). Filed **0928** —
device OP save cards rode along on analyses that cannot use them: both gates
asked only about `save_op_params`, never whether an `op` analysis was enabled,
and `ase::op_analysis_enabled` had exactly one caller (the gate-OFF nudge).
Measured: 3000 cards are FREE under `.op` (+0.03 s, +107 KB) and cost +8.6 s and
+242 MB under a 10068-point `.tran`. A live regression 0927 created. FIXED the
same day.

**2026-08-29, the user's tb_bandgap report** (*"We are still screwed up ... The
ASE-L does have OP analysis enabled ... 6 says these are from a 'tran' run"*).
Filed **0929** — ngspice's `write` writes the CURRENT plot, and the deck emitted
ONE write after the LAST analysis, so on any state with more than one analysis
enabled every earlier plot was silently discarded. Their 144 MB raw held one
plot, `Transient Analysis`. Fixed with `set appendwrite` + one write per
analysis, plus deleting the raw before the run. No reader change was needed.
Every ASE deck test used an op-ONLY state, where the bug is invisible.

**2026-08-29, the user on ASE-L > Tools > Waveform Viewer leaving no trace**
(*"We want to log everything! I said that 3 months ago!"*). Filed **0930** —
menu picks outside the File menu reached the action log only by accident.
`menu_action_logged` existed but was attached in ONE place, so 6 of 238
main-window entries were wrapped and 15 of ASE-L's 24 were silent. Fixed with an
interceptor on the `menu` command that wraps each widget's `invoke`, leaving
every `-command` string byte-identical (19 test rows read them back).

**2026-08-29, the simulator-registry backlog item S1.** Filed **0931** — there
was no way at all to point ASE-L at a simulator that is not on `PATH`: the whole
body of `ase::backend::ngspice::run_cmd` was `return [list ngspice -b $deckpath
2>@1]`, no rc variable, no `$USER_CONF_DIR` file and no proc anywhere answered
"which program will be started", and the only lever was the `PATH` of the shell
that launched xschem. FIXED the same day: one resolver (`ase::sim_status`), a
named registry that an rc, the user's own file and the session all feed, four
validation guards that each SAY something, and `auto_execok` still the fallback
when nothing is registered (byte-identical command, which is why the committed
log-header goldens needed no edit). The GUI front door is item S2 and calls
`ase::sim_write_conf`.

Four things measured during that item's verification are filed and NOT fixed:
**0932** (clearing your simulator choice does not survive a restart — the saved
file cannot write down "none of mine", so the first entry is auto-selected back
into force silently); **0933** (a location naming an unknown setting is refused
at registration and honoured at the run, and skips the path normalisation on
that arm); **0934** (`ase::cosim_build_script` is silent on a missing or
non-runnable path and RETURNS A DIRECTORY as the build script — the neighbour
defect 0931's row C7 pins as KNOWN); **0935** (the resolver's `ok` field claims
more than it delivers — read `resolved`). And **0936** records a measurement
trap rather than a code defect: three tier baselines were taken on the dev
display and written down under the headless command, and a fourth cannot be
produced by the `--nolog` command printed beside it.

**2026-08-29, the simulator-registry backlog item S2.** Filed **0937** — the
registry 0931 shipped had no door in the GUI at all (nine menus walked on the
real session window, zero entries mentioning a simulator program) and nothing in
the tree ever called its writer, so anything registered from the CIW was gone at
the next start. FIXED the same day: `Setup > Simulators…`, one dialog that
drives S1's own procs and saves through `ase::sim_write_conf` — one writer, two
front doors. Four new sentences in the mint (removing the one in force now says
what happens next, in both arms), a per-entry reason a list can show
(`ase::sim_entry_why`, re-validated on every call), and a recorder
(`ase::sim_say` / `sim_said`) so the dialog shows the very sentence the CIW got
instead of composing a second one.

Two of the four things S1 left behind were closed by it: **0932** is FIXED (a
cleared choice is written down as `ase::sim_select {}` and survives a restart —
and therefore now overrides an rc's own `::ASE_SIMULATOR`, which is recorded and
unratified), and **0933** is HALF fixed — the list and the run now give the SAME
sentence for a location naming a setting this session does not know about; the
storage half (the unexpanded literal is stored and skips normalisation) stays
filed. **0934** and **0935** are untouched. 0937 carries S1's unratified
question forward: the first simulator you register still goes into force even
when its path is bad, and the dialog now makes the consequence visible in the
same gesture rather than changing the rule.

**2026-08-29, S2's write-up pass — seven more, and one of them is ours.**
Verifying the 0937 dialog measured seven defects that were filed rather than
fixed, each reproduced first-hand before filing. **0938** is a REGRESSION this
branch caused: `ase::sim_entry_kind` substitutes the stored path a second time,
registration already substituted it once, and the substitution is not
idempotent — so a runnable simulator whose path contains a literal dollar sign
is refused with a sentence blaming a setting the path never mentions. **0939**
(editing a startup-file simulator takes it over for good, silently), **0940**
(Add onto an existing name silently replaces it and wipes its settings) and
**0941** (Remove on a startup-file entry never says which simulator runs next —
a miss of the item's own brief) are silence or data loss in the new dialog's own
buttons. **0942** and **0943** are the two halves of the writer rewrite (a
symlinked list is replaced by a plain file; saves the old writer managed are now
refused, with an internal `.new` name leaking into user-facing wording).
**0944** is a blank Problem column for an entry registered for another backend.
0938 is on the user's ruling queue, because the way out is a trade between a
wrong sentence in a rare arm and a refusal to run a working simulator.

**2026-08-29, item S2a — one number claimed, three issues closed.** Repairing
0938 measured a fourth arm of the same guard that nobody had filed: a simulator
typed at its REAL absolute path with a dollar sign in it is refused when you add
it. That is **0945**, and it is NOT the 0937 regression — it is refused
consistently at both ends and dates from 0931 (`0225a962`). It is closed by the
same guard that closes 0938's restart half. **0938** is FIXED by its own option
2 (the verdict about the setting is worked out once, at registration, and
recorded on the entry) plus that guard; the rejected alternatives and the
residual 0933 storage half are written into the file. **0941** is FIXED by
making the sentence recorder accumulate, so a gesture with two true things to
say has both of them on the dialog's status line. **0940** was examined for the
same root and MEASURED to be a different one — it says no sentence at all, so
there is nothing for a recorder to overwrite — and stays OPEN, needing a new
minted sentence and the user's refuse-vs-confirm ruling.

**2026-08-29, item S2a's write-up pass — two more, both measured on the
repaired tree.** The 0938 repair narrowed the wrong sentence rather than
removing it, and the write-up agent measured how much is left before publishing
the claim. **0946**: a location with a dollar sign in a **folder name** that
names no file — a typo, or a program that moved — is still blamed on a setting,
in the live session, on the first gesture, with nothing deleted and no restart
involved. 0938's own residual paragraph scoped that to "after a restart, an
entry since deleted"; both qualifiers were wrong and the file now says so.
**0947**: the answer about the setting is worked out once and recorded, so an
entry added while its setting was unset goes on saying the session does not know
that setting after the user sets it — false by then, and one `Edit` → `OK` from
working, which no sentence mentions. 0947 is this repair's own doing; the
shipped-before code refused the same entry with a different wrong sentence, so
it is a wording trade, not a behaviour regression. Both lean on 0933's still-open
storage half, which would close them together.

**2026-08-30, item S3.** **0948**: a registered simulator is never asked what
it can actually do, so a build that keeps only the LAST analysis of a run
destroys the user's operating point with exit 0 and a clean log, and nothing at
any layer can even ask. FIXED — an optional sixth backend hook,
`capabilities`, answering from a PROBE RUN (never a version string, never an
exit code), cached on the resolved program's path + mtime + size so a rebuild
in place re-measures itself. Its open half is a ruling, on the user's queue:
warn-vs-refuse, and how often to say it.

**2026-08-30, item S3's write-up pass — eight more, each reproduced before
filing.** Six are defects in the capability probe 0948 just landed, and the
first three of those are one mistake in three places: a measurement that did
not happen reported as a fact about the user's program. **0951**: two xschem
windows share one probe scratch file under one fixed name, so a program that
wrote nothing was measured healthy. **0949**: a simulation folder with a space
in its name makes a working ngspice be told it is not a circuit simulator, on
every Run — the deck's `write` line is unquoted, and so is the real deck's,
which is older. **0952**: a build that appends perfectly but spells device
parameters differently is told it keeps only the last analysis, and given
advice that changes nothing. **0953**: the two probe runs are paid inside the
user's gesture, so a slow-to-start simulator freezes Run for a measured 20.0 s
and is then called not a simulator. **0950**: a wrong answer is remembered for
the whole session and no door in the GUI clears it. **0954**: the generic probe
runner appends ngspice's `-b`, breaching this file's own stated seam.

Two are harness, from the same session's verification. **0955**: two
`run_regression.tcl` runs in one tree truncate each other's `results.log`, so a
run can report the branch's ZERO baseline having verified nothing — issue
0147's false green through a new door, and the dangerous-direction sibling of
0867. **0956**: `devdisplay.sh start` deletes the lock of a server that is
merely slow to answer; its second half — a wedged display reported `alive` —
is recorded as observed and NOT explained, and must be reproduced before
anyone edits the liveness logic.

Also appended, not renumbered: a second dated sighting of `test_ase_window`'s
`W7` flake under **0801**, which already owns that class.

**0957** — the REAL deck's `write [raw_file $state]` line is unquoted and
absolute, so a run from a folder whose name has a space (or a dollar, a quote, a
semicolon) writes its results nowhere. Filed 2026-08-30 by item S3a, which fixed
issue 0949's PROBE half and is forbidden by its brief from touching deck
emission. The measured mitigation is recorded on the issue: `ase::run_deck`
already cd's into the very folder `raw_file` joins, so a bare basename on the
deck's `write` line resolves to the same file on every folder name.

**2026-08-30, item S3a's write-up pass — five more, each reproduced first-hand
before filing.** S3a repaired the 0948 capability probe (0949-0954, all FIXED);
these five are what the fix and its verification turned up and did not close.
**0958**: the Run pause for a simulator that never answers is paid on EVERY press,
not once — a consequence of S3a's own two correct rules meeting, measured at
3004/3003/3005 ms per press at a lowered budget and 30 s x 3 at the shipped one,
where the code it replaced cost 20 s once. **0959**: the bound, the honest
sentence and the never-cache rule all depend on `timeout(1)` being on the box and
evaporate together in silence when it is not — measured, 16.0 s unbounded then
the false "not a circuit simulator" sentence, remembered. **0960**: a simulation
folder the probe cannot use switches every simulator warning off, for good, with
nothing said — both shapes measured, a read-only folder and an ordinary file
sitting where `.ase_probe` needs to be. **0961**: a location written `./name` is
not made absolute before the probe changes folder and cannot then be started;
filed as latent behind the registry's own normalize, and the code comment states
the opposite rule. (⚠ **The "latent" half was wrong and was corrected
2026-09-07**: the nothing-in-force route hands the probe `auto_execok`'s answer,
which is relative on an ordinary `$PATH`. See the issue file.) **0962**: a coverage gap — no committed row reproduces the
CONCURRENT write that 0951 is about, and row I4's headline half passes on the
defective tree.

**2026-08-30, item S4's red pass.** Claimed as stubs before any work, so a
concurrent crew cannot collide: **0963** (a run never says how it asked for
device numbers, and there is no way to choose — the tier selection, the
override and the sentence), **0964** (the device requests are recorded at every
time point of the transient — issue 0928 section 7, measured at +74.9 MB and
+4.08 s on tb_bandgap; this is where the whole win of S4 lives), **0965** (two
devices on the bandgap bench get a device name ngspice cannot resolve — FILED,
NOT FIXED, and the reason the one-write-line form cannot be auto-selected), and
**0966** (the blanket request is not the shape the probe measured — FILED).

**2026-08-30, item S4's repair pass.** **0967**: ticking the device-numbers box
silently changed which analysis the Outputs pane's Value column reads — issue
0964 moved the operating point last and the deck's `print` lines, which sit
after every analysis, went with it. Found by the sabotage pass as a behaviour
change no committed row could see; FIXED, with rows P1/P2/P3.

**2026-08-30, item S4's write-up pass.** Two more, both reproduced first-hand
before filing, both FILED NOT FIXED. **0968**: the blanket form's request is a
deck-level `.options` line and so applies to every analysis, and the blanket arm
does not get 0964's reorder — so on the day a simulator honours it, issue 0964's
defect comes back inside the cheapest of the three forms; every committed row
that renders that form does so on an operating-point-only state, so nothing can
see it. **0969**: a coverage gap in two halves — the form-b-against-form-c value
acceptance runs on a hand-written level-1 transistor rather than the PDK bench
the item names (checked by hand: 456 of 456 bit-identical), and the leader rule
is a deck grep where its measured hazard was a run that lost 4 of 6 node
voltages from its transient (checked by hand: 424 vectors either way).

**2026-08-30, item S4a's repair pass.** Two more, both reproduced first-hand
before filing. **0970**: the bandgap bench does not simulate what its schematic
says — `passgate.sym`'s `format=` string never passes `modelp` down, so x5's and
x6's `modelp=pfet_01v8_lvt` is dead in the netlist and those two transistors are
simulated with a standard-Vt pfet. FILED NOT FIXED; netlister/symbol scope,
wider than annotation, and fixing it would change what the committed bench
simulates. **0971**: the results-file reader loaded the WHOLE file to read its
headers, which became a hazard the moment issue 0965's run report pointed it at
the user's own 69 MB results file; FIXED in the same pass, and filed anyway
because no behavioural row in the tree can see it.

The same pass FIXED **0965** (the two unresolvable device names, and the silence
that hid them), **0966** + **0968** (one change: the blanket form now asks the
shape the probe measures, inside the run and scoped to the operating point) and
**0969** (the acceptance is pinned on the PDK bench with a real run, section X).
**0967** stays with the user and was deliberately not acted on.

**2026-08-30, item S4a's REPAIR pass** (the sabotage pass found four guards no
row anywhere could see; one of the four was also half broken). **0972**: the
`@dev[param]` split cut at the FIRST bracket, which on a bussed instance is the
bus index — measured on the shipped `sky130_tests_ase/sky130_mismatch` bench,
whose ten matched transistors are one symbol named `M1[9:0]`, the split answered
`@m.xm1` for all ten. FIXED here, one splitter cutting at the last bracket, rows
Q7/Q8/Q11. **0973**: a vector instance's save cards name the bus RANGE, which
the deck never contains (the netlister writes one element per member) — 60 blank
annotation rows on that same bench. FILED NOT FIXED: which member's numbers
belong beside a symbol standing for ten transistors is the user's ruling, and
ruling D5-1 forbids the obvious shortcut. Recorded as a `rule` debt.

**2026-08-30, item S4a's WRITE-UP.** Three more, all measured and none fixed —
each reproduced first-hand from the shipped code before filing, and each left
unfixed on the rule the sabotage pass established on this very item: *a change
with no row watching it is not a fix.* **0974**: the sentence that says which
transistor's schematic and netlist disagree leads with `M2` — the device inside
the cell — on a sheet holding five passgates that each contain an `M2`, and
names the placed instance (`x5`) only inside the trailing raw-file device path;
it also never says what the user can do. **0975**: the "did not come back"
sentence names ONE cause ("the deck spells a device differently") even when
NOTHING came back, where the likelier reason is an operating point that did not
converge — and it says "of 1 devices". **0976**: issue 0965's model-resolution
defect is still live at five sites in the shipped PDK helper files, two of them
on surfaces a user reaches today (`sky130_display_fet_params`, behind the
shipped `annotate_fet_params` symbol, and `sky130_hier_sch_expand`, behind the
menu's `.save` writer); row NM5's "one place" claim is scoped to
`src/op_annot.tcl` and is not true of the tree.

**2026-08-30, item S4b — the last repair pass on the OP work.** FIXED **0970**
(both halves: the two bandgap passgates now netlist from a cell body built with
the low-threshold device their schematic line names, via a per-instance
`schematic=` attribute; and the netlister now says so when an instance sets a
property the symbol's format string never reads), **0974** (the disagreement
sentence leads with the placed instance, in the case the sheet spells it, and
ends with the action), **0975** (both defects: a third sentence for the
all-or-nothing shape that names no cause, and one place that chooses singular
from plural) and **2 of 5 sites of 0976** (the two user-reachable sky130 menu
surfaces; the three IHP ones are pinned unchanged at row PD5). Filed **0977**
(the tree's only other netlist-time warning suite was registered nowhere and had
never been run — fixed in the same pass, because the new check lives in the same
C function), **0978** (149 settings in `xschem_library/` that the new diagnostic
reports, NOT fixed — 111 of them real, the other 36 being issue 0980's defect
in the check itself) and **0979** (the `xschem descend` COMMAND cannot
fall back to a cell's base sheet where the menu can — measured on SHIPPED data,
pre-existing, NOT fixed).

**2026-08-30, item S4b write-up and commit.** The verification and sabotage
passes over the same item produced four more measured defects and one coverage
issue, all filed here rather than left in a report: **0980** (the new
netlist-time warning tells a designer to delete a setting the VHDL and Verilog
netlists really use — 36 of the 149 lines on the example library, and the one to
fix first), **0981** (the same warning says "on this sheet" about instances that
are not on the sheet, and names three of them identically), **0982** (two
instances given the same `schematic=` name collide in silence — reached by
following the advice the new sentences give), **0983** (a long or multi-line
attribute value costs the sentence its ending) and **0984** (the new guards are
pinned by fewer rows than they look; one gap in it, row UB9's anchor, was fixed
in the same commit). Issue **0978**'s claim that its 149 lines are "all real" is
corrected there by measurement.

**2026-08-30, item S4c — the correction of S4b's netlist warning.** FIXED
**0980** (the warning was wrong on 43 of the 149 lines it printed across
`xschem_library`, not the 36 that file claimed; it is now 0 of 98), **0981**
(every line names the sheet the instance is really on, and all 22 lines on
`rom8k.sch` are distinct), **0982**'s advice half (the collision itself stays
open there), **0983** (both shapes) and **0984** (all four coverage gaps; the
suite went 21 → 40 checks). Corrected the counts in **0978** and **0980**. Filed
**0985** (the VHDL netlist writes `extra=`-declared nodes into the generic map
where Verilog leaves them out — found while fixing 0980, deliberately not
settled, because settling it either way changes a shipped VHDL netlist).

**2026-08-30, item S4c sabotage pass.** Filed **0986** — halves of S4c's own new
guards that can each be deleted with all 40 checks green: the instance-side half
of GUARD UA-ALTFMT, five of the six names in `fmt_attrs[]`, any single name
dropped from the stoplist, the early-return restore of the netlister's
token-found flag, `unused_attr_elide()`'s buffer clamp, and — found when the
whole pass was repeated on 27 fresh builds — the `%` sigil half of GUARD UA-FMT.
**Six, not the five the filename says**; the sixth is in that file's addendum.
Found by neutralizing every guard one at a time against a real rebuild, one
mutation per build, restoring and re-asserting the baseline green between each.
It is issue 0984's complaint one round later, and the fourth of them is the same
defect UB9 was re-anchored to fix, one level down.

**2026-08-30, item S4c write-up.** Filed **0987** (0980's fix silences a setting
the SPICE deck really drops — 43 lines' worth on the shipped library — because
GUARD UA-TMPL asks whether ANY format could consume it, not whether the netlist
being written does), **0988** (a setting no format can consume at all is silent
too, when the symbol carries `vhdl_ignore`/`verilog_ignore`; 112 shipped symbols
carry such a flag), **0989** (`select` on the stoplist makes a real subcircuit
parameter of that name permanently unreportable) and **0990** (two concurrent
`run_regression.tcl` runs share `open_close`'s fixed `results/.work` directory,
and the one that finishes second reports a `FATAL: 10` that never happened —
a fake red in the suite whose baseline is ZERO).

**2026-08-30, item S4d sabotage pass.** Filed **0991** (the `short` half of the
four do-not-write marks has no test row; deleting `| VHDL_SHORT` makes the netlist
warning name VHDL as a carrier on a cell VHDL writes as a plain wire, with all 57
checks green), **0992** (an empty `vhdl_format=""` on one instance makes the
warning read the SYMBOL's format string while the netlister reads the instance's
empty one -- it tells the designer to delete a setting the VHDL netlist really
writes, and the correct fix is ALSO 57/57 green) and **0993** (a template-declared
setting whose VALUE is empty is claimed to be carried by VHDL, which drops it).
All three found by neutralizing every guard one at a time against a real rebuild,
50 mutations, one per build. Recorded as an addendum on 0986, whose "ended at 0"
count is corrected to *closed 6, opened 7*.

**2026-08-30, item S4d write-up pass.** Filed **0994** (the tier list in
`doc/claude/ledger/crew.js` prints three suites' DISPLAY-arm check counts under
the headless command, and `test_wave_viewer`'s `--logdir` count under `--nolog`,
so four suites can never reach their recorded baseline by the command recorded
beside them; its `run_regression.tcl` block count is stale at 46 against a
measured 53. Found independently FOUR times inside one item).

**2026-08-30, item S5 sabotage pass.** Filed **0995** (`library_dir_owner`'s
argument-side `file normalize` is live code no row can see -- deleting it leaves
both arms at 29/44 ALL PASS, against a plan that predicted two reds), **0996**
(two structural rows, R8a and R8d, grep `library_new`'s body for words that also
appear in the comment inside it, so both go green on a tree with BOTH folder
checks deleted; the before-mkdir ordering has ONE eye, R4b, not the two the plan
claims), **0997** (the "this folder holds your library list" refusal tests the
literal filename `library.defs` rather than this session's registry root, so a
root whose list file is spelled `cds.lib` is still accepted at rc=0 -- the issue's
own harm, reproduced on the fixed tree) and **0998** (deleting the re-prompt
loop's only way out makes the suite HANG with no banner rather than fail, and it
is registered in `run_regression.tcl`'s `dcases`). Sixteen mutations, one per
build, each restored and re-baselined before the next.

**ALSO NOTED, not an issue:** the item this pass audited carries
`doc/claude/issues/0799-…`, **inside the reserved 0700-0799 block**, and it is the
only 07xx file on this branch.

**2026-08-31, the S5 repair pass RULED THAT NUMBER CORRECT and did not renumber
it.** The reserved block exists *because the synthesis branch owns it*, and that
issue was authored **there**, not here: its own header reads `**Branch:**
synthesis`, and it cross-references `[[0792]]` and `[[0798]]`, neither of which
exists on `annotate` — 0792 is about `vimport::create_library`, code this branch
does not contain (`grep -rn vimport src/` matches only the comments S5 itself
wrote). Nothing on `annotate` **filed** into the reserved block; a briefing
document was carried across from the branch that owns the number, which is what
reserving a block is *for*. Renumbering would have given one user complaint two
identities on two branches and broken its two cross-references. Recorded in the
suite header (`tests/headless/test_lib_new_path_guards_0799.tcl`) so the next
reader does not re-derive it. The follow-ups `annotate` really did file for that
work — **0995-0999** — are all in this branch's own range.

**2026-08-31, item S5 repair pass.** Filed **0999** (the Library Manager's other
four prompt windows — New cell…, Rename…, Copy view…, New view… — have the same
missing close-button handler that `[[0998]]` describes: press the X in the title
bar and the window vanishes while the press goes on waiting for ever. Fixed in
**New library…** only, because that is the one window that *loops* and the one the
S5 suite could reproduce; the other four are recorded rather than changed
untested).

**2026-08-31, item S5 write-up/commit pass.** Filed **1200** (`library_new`'s one
remaining cryptic sentence, `no writable library.defs (set XSCHEM_LIBRARY_DEFS)`
— it names a file the user has never seen and an environment variable with no
value, and the 0799 re-prompt loop now lands it *inside* the New-library window
where it never used to appear. Measured on both arms; it has no test row
anywhere. Pre-existing, so it was recorded rather than reworded untested inside a
commit whose subject was something else).

**2026-08-31, item S6.** Claimed **1201** (the netlister must honour a
per-copy setting by itself, rather than silently discarding it and telling the
designer to hand-type a `schematic=` attribute). FIXED and committed.

**2026-08-31, item S6 write-up/commit pass.** Filed **1202-1209**, all measured
by that item's own verify pass and none of them fixed inside it:

* **1202** - a copy that hand-types the cell name the netlister would invent
  silently loses its own setting. Caused by 1201; a regression.
* **1203** - two different setting lists spell one cell name because the
  setting/value join is ambiguous. Caused by 1201.
* **1204** - "netlist current schematic only" calls a cell body it never
  writes. Caused by 1201; a regression.
* **1205** - the netlist warning says the cell's drawing does not use the
  setting, without having looked (RULING D5-1). Caused by 1201.
* **1206** - an empty setting value writes a second, identical copy of a cell.
  Caused by 1201.
* **1207** - netlisting eight shipped `viewdraw_import` sheets segfaults, in
  every backend. **Pre-existing**, not 1201's doing; the backtrace is in
  `netlist.c`, which that item does not touch.
* **1208** - two rows in the new netlister suite pin a whole-deck fingerprint
  that carries this checkout's own absolute path, so a clone elsewhere reds
  them. Test fragility, not a product defect.
* **1209** - a specialised copy loses the symbol/schematic pin-mismatch
  highlight. Error path only.

**2026-08-31, item S6a (the repair pass).** No new numbers filed. **1202,
1203, 1204, 1205, 1206 and 1208 are FIXED** and their files carry the
measurement; **1209 stays OPEN with its symptom corrected** (the pin-mismatch
check does still run on a specialised copy - what the designer actually gets is
four error lines where they got two, half naming a cell they never typed);
**1207 is untouched**, pre-existing and out of that item's scope.

**2026-08-31, item S6a (the repair pass, after sabotage).** Two numbers filed,
both for guards item S6a added that NO row could see - found by building each
one's removal, not by reading:

* **1210** - `auto_spec_begin()` keeps two flags, and the eleven-line comment
  explaining why one will not do was enforced by nothing. Collapsing them makes
  the single-sheet netlist re-read every cell's drawing off the disk once per
  token (295 opens against 286, measured). **FIXED**, row AS57.
* **1211** - the two new `xctx->tok_size` latches in `auto_spec_collides()` and
  `auto_spec_qualifies()` cite GUARD UA-TOKSIZE in `token.c`, whose own copy IS
  pinned by row UB9 of `test_unused_attr_0970`. These two got the citation and
  not the row. **FIXED**, row AS58, which also pins the issue-0986-gap-4 case a
  plain restore count cannot see.

**test_auto_specialize_1201 is 59 checks, was 57.** No product code changed for
either; `src/xschem` is byte-identical to the build item S6a shipped.

**2026-08-31, item S6a (the write-up/commit pass).** Eight numbers filed,
every one of them re-measured on the shipped binary by this pass before it was
written down - not adopted from a report:

* **1212** - a `schematic=` cell name typed on a copy one level DOWN is
  invisible to [[1202]]'s new collision probe, which walks the sheet being
  netlisted. That copy still gets someone else's device, silently, and the
  device it asked for is nowhere in the deck. This is the half of 1202 its fix
  does not reach; 1202 is now marked FIXED *for the sheet being netlisted*.
* **1213** - a value typed as a single SPACE passes GUARD AS-EMPTY's one-byte
  test, and the deck names a device model that exists in no PDK
  (`sky130_fd_pr__`). Same shape as 1204: an unusable deck under a note saying
  the designer need do nothing. RULING D5-1.
* **1214** - a value that matches the symbol template's own default still writes
  a second, byte-identical cell body (294 bytes each, measured). This was
  1206's recorded residue; it now has its own number so it is not lost inside a
  closed issue.
* **1215** - the over-refusal twin of 1202's fix: two copies asking for the SAME
  settings, one of which hand-types the name, get two IDENTICAL bodies (298
  bytes each) while the note says they share one.
* **1216** - the netlist warning's opening clause is now four separate string
  literals in `src/token.c` (lines 3725, 3739, 3754, 3769) and only one of them
  is pinned by a row. RULING D5-4, latent.
* **1217** - row AS56 prints the measurement its own words say it asserts; it is
  one `expr` short of pinning that the header strip covers every root-bearing
  line. No live gap today.
* **1218** - two comments name a checkbutton, "netlist current schematic only",
  that this build does not have. The doors are Shift-N and `xschem netlist
  -nohier`. The 1204 fix is right; only the name for the door is invented.
* **1219** - PROCESS. The sabotage protocol's closing check, `grep -rn SABOTAGE
  src/`, cannot see a sabotage left in a test file, and was clean for the eleven
  minutes a live SAB-HDRSTRIP variant sat in
  `tests/headless/test_auto_specialize_1201.tcl` and cost two verification
  passes. Widening it to `tests/` does not work either: 60 pre-existing prose
  hits across 28 files. Byte-compare against a pre-sabotage copy instead.

* **1220** - the recorded RESIDUAL of 1212's fix (item S6b): the design walk
  skips a sheet named through a generator or an `@` substitution, and a name it
  harvests from a FILE is unconditionally taken, so 1215's same-settings
  exemption applies on the sheet being netlisted and not across sheets. Neither
  loses a setting silently; the first says so out loud, the second costs a
  duplicate cell body.

**Item S6b (2026-08-31) closed 1212, 1213, 1214, 1215, 1216, 1217 and 1218.**
1219 is process-side and nothing in the repo carries it. 1207 is untouched.

**Item S6b's SABOTAGE pass (2026-08-31) filed 1221-1226** -- six guards the item
added that no test row can see, each measured by neutralising the guard, rebuilding
and watching the suite stay green:

* **1221** - the design walk's memory of sheets already read. AS74's `seen` element is
  satisfied by the function's own parameter name, so the whole memory can be deleted
  at 77/77. The depth limit half IS pinned.
* **1222** - AS77 cannot see the invented tick-box name wrapped across two comment
  lines, which is the shape all the original sites had. Only a one-line
  reintroduction reddens it.
* **1223** - HIGH, RULING D5-1. Deleting the shared-buffer re-read in
  `warn_unused_instance_attr()` makes the warning quote the symbol template's value as
  though the designer had typed it, and pick the wrong explanation, at 77/77.
* **1224** - the walk's once-per-run latch. AS74's prose claims it; its elements count
  call sites, not calls.
* **1225** - `auto_spec_symbol_body()` and the fallback beside it are run by no fixture
  and grepped by no row; the whole function can be emptied at 77/77.
* **1226** - `ua_value_fault()`'s three explanations are printed and never asserted;
  collapsing them to one string is green while a `---` value is called blank space.

**Item S6b's REPAIR pass (2026-08-31) filed 1227 and closed 1221-1226.**

* **1227** - HIGH, RULING D5-1. A setting XSCHEM said it could not use still
  reached the cell body it wrote for that copy, whenever the copy carried one
  usable setting beside it: `sky130_fd_pr__` back in the deck, a transistor line
  cut in half by a line break, and two copies with different refused values
  sharing one body so the second silently simulated the first one's transistor.
  Closed by GUARD AS-STRIP in `token.c` with two callers in `actions.c`, plus an
  `@`/`%` extension to the allow-rule. Rows AS78-AS81 and two new elements on
  AS65. 648 shipped sheets re-netlisted: zero copies qualify, so no shipped deck
  can have moved.
* **1221, 1224** closed inside row AS74 (the visited set is counted as its two
  table calls; the once-per-run latch is counted inside the walk's own entry
  point). **1222** closed in `as_flat` (C block-comment continuations are now
  dropped as well as Tcl hashes). **1223** closed by row AS82 (the sentence
  quotes the value the DESIGNER typed). **1225** closed by row AS84 (a middle
  cell laid out the way vendor PDKs lay them out). **1226** closed by row AS83
  (four reasons, four sentences, and the four have to be four).
* **1220** gained row AS85 for its case 2, and now records that the note's
  "shares that one" sentence is measurably false across sheets. Still open.

~~**The next free number is 1238.**~~ superseded: 1238 and 1239 were taken at
the `annotate` → `fluid-editing` merge (2026-09-01) for the two capabilities that
merge deliberately did not carry across — stock `proc simulate`'s exe/casemode
composer, and `ase::expand_path`'s `subst`, which the merge made more reachable.
**The next free number is 1244.** 1201-1243 are taken. **1243** went to the
Outputs pane's blank Value column, but only on the second attempt: it was very
nearly spent on a defect that already had a number, because the `raw switch`
publish gate reading the OUTGOING database is **0513**, filed 2026-08-19, and
`test_results_select`'s SEL195 had been carrying the note "WHEN 0513 IS FIXED,
SEL195 INVERTS" the whole time. Grep the issues directory before minting. (1240 records the
update_op() ruling collision the merge found; 1241 the log_action buffer
overflow it made reachable.) Item **S7**'s red phase
claimed **1228-1233** as stubs before writing its rows (1228 the E key opening the
cell's own schematic instead of the copy's own; 1229 the fallback ignoring whether
the bound file is there when there is no display; 1230 answering No still dropping
you on a blank page; 1231 the symbol form of the view resolver reading instance
minus one; 1232 a descend suite registered in no runner; 1233 the five scripted
hierarchy walks that stay on the bare verb). **1000-1199 is
reserved** (user, 2026-08-30), so 0999 was followed by **1200**; 0500-0599 and
0700-0799 remain reserved for other branches.

**Item S7's WRITE-UP pass (2026-08-31) filed 1234-1237.** All four were measured by
the adversary pass, re-measured independently before filing, and none was fixed
silently.

* **1234** — descending into a cell whose OWN schematic file is missing still drops
  you one level down on a blank page, through all three doors and with no question
  asked (copy x7 of `xschem_library/inst_sch_select`, a `type=subcircuit` symbol with
  no `.sch`). `get_sch_from_sym()` stats the file it refuses and never stats the file
  it offers. Pre-existing; it is item S7's own stated bar, unmet for the wider class.
* **1235** — RULING D5-1 / PLAIN ENGLISH. The sentence item S7 minted says *"The copy
  named xA … is set to open"* when the `schematic` setting lives on the CELL, and its
  advice sends the person to edit the copy, which masks the cell's setting for that
  copy alone.
* **1236** — the new View drop-down row is offered whether or not its file exists and
  reads identically either way. Presentation choice item S7 created and did not make.
* **1237** — LOW. `xschem descend -fallback` is swallowed in silence when it is not the
  first word, and a misspelled flag becomes an instance number.

**Still open from S7's red phase:** 1232 (a descend suite registered in no runner),
1233 (the five scripted walks left on the bare verb). **Closed by S7:** 0979, 1228,
1229, 1230, 1231.

**2026-09-02 — 1244 and 1245 are RESERVED for the OP-parameter-lists feature.**
Not defects: two features the user asked for on 2026-09-02, specified together
in `doc/claude/specs/op_param_lists.md` because they are the same object seen
twice (a per-primitive-class, user-owned, ordered list of operating-point
parameters).

* **1244** — `Ctrl-Alt-6`, the schematic parameter declutter. Hide a primitive's
  parameter text (W, L, m, nf, model) while — and only while — operating-point
  info is annotated.
* **1245** — the Results Display Window. Cadence ADE-L > Results > Print, but
  the printed dump is also where the annotation and summary lists are edited.

The measurement transcript both rest on is
`doc/claude/code_analysis/1244_op_param_list_measurements.md`.
**Item A1's passes (2026-09-02) filed 1246-1248.** All three were measured, none
was fixed silently, and none is in a file item A1 owns.

* **1246** — `Waves > Op Annotate` hard-sets `annot_show 3` (`src/xschem.tcl:17299`
  and `:17725`), so it silently clears the declutter bit item A1 added. Measured
  by A1, which owns neither line.
* **1247** — a NET-ZERO pair of `Ctrl-Alt-6` presses arms the 0688 root-change
  clear. `annot_show_set()` stamps `xctx->annot_root` for any nonzero mask, so
  two presses of a chord that changes nothing turn an `xschemrc`-armed
  `annot_show` from one that survives a `File > Open` into one that is cleared
  by it. Pre-existing mechanism, first *exposed* by A1. The repair reverses a
  prior ruling whichever way it goes, so it is a question, not a patch.
* **1248** — the A1 suite's three coverage holes: rows I2/I3 render on a fixture
  that is byte-identical at every mask (so the "A3 MUST REPLACE" tripwire cannot
  trip), sabotage SB5 is caught by a source grep and by no behavioural row, and
  the `off` arm is untested above bit 3. Item A3 should fix the first as part of
  replacing row I2.

**Item A2's implement pass (2026-09-02) filed 1249.** Measured behaviourally,
not fixed, and in files item A2 does not own.

* **1249** — the shipped keep-name test (`src/draw.c:873`, `src/svgdraw.c:928`,
  `src/psprint.c:1210`, three byte-identical copies) compares against `@symname`
  and `@name` only and misses the third shipped spelling `@spiceprefix@name`, so
  at `hide_symbols` 1/2 gf180's whole FET family and the generic
  `xschem_library/devices/nmos4.sym` lose their names on screen, in SVG and in
  PDF. 81 shipped `.sym` records. Pinned behaviourally by row **N14** of
  `tests/headless/test_annot_declutter_1244.tcl`, which whoever fixes 1249 flips.

**Item A2's write-up pass (2026-09-02) filed 1250.** Measured, not fixed, in
files item A2 does not own.

* **1250** — `cadence::_annot_fit` elides the held status line at 255 bytes
  (ratified in 0886), and the sentence embeds the raw's absolute path, so
  `tests/headless/test_annot_stale_0684.tcl`'s message rows are sensitive to the
  length of the scratch path — which `test_scratch` builds from the repo
  location and the **pid**. Deterministic: the suite passes at a scratch root of
  120 bytes and reds F17 at 124 (the shipped default is 54, so ~67 bytes of
  headroom). Separately and **not explained by that**, F21 red once in a real
  `run_regression.tcl` run at the default path and did not reproduce in 3 further
  T1 runs or 10 standalone ones. **A T1 red naming this suite's F17/F21 is not
  evidence about the change under test until part 2 has a cause.**

**Item A3's passes (2026-09-02) filed 1251-1254.** All four were measured, none
was fixed silently. A3 **fixed and closed 1246, 1247, 1248 and 1249**.

* **1251** — `cadence::_annot_msg` switches on `[expr {$mask & 7}]`
  (`utils/annot_mode.tcl:906`), so the status line cannot mention the declutter
  bit. Harmless until A3's rung landed; now mask 1 and mask 9 draw different
  sheets and produce the same sentence. `utils/annot_mode.tcl` is **item A4's**
  file and row V21 of `test_op_annot.tcl` golds all eight arms byte-for-byte, so
  A3 recorded the decision instead of reddening a row it does not own.
* **1252** — the declutter's per-instance gate reads the overlay cache, which is
  refreshed at **four** sites; `symbol_bbox()` has **thirty-nine** callers. A3
  synced the one that matters (`update_all_sym_bboxes`, so the click target is not
  one epoch behind the screen) and left the rest. Same staleness shape as 0453.
  **Item B4 picks by coordinate and is the exposed caller.**
* **1253** — P6 pin-owned pin names are drawn by a **fourth** pass gated by
  `pin_name_visible()`, not by `text_hidden()`, so a `show_pinname=true` pin keeps
  its name on a fully decluttered device — against ruling D-1, which puts pin
  labels in scope. Measured first-hand. Inert on all three PDK acceptance devices
  (four pins each, all `false`); 2,968 shipped records spell `true`.
* **1254** — two coverage holes in `test_annot_declutter_1244.tcl` found by A3's
  own sabotage pass: the new `src/scheduler.c` sync line is guarded by **no** row
  (removing it leaves all 610 checks green, because row A15's `load` leaves the
  cache cold), and row **A17** cannot detect the thing its name claims (at
  `hide_symbols=2` the keep-name filter has already reduced both renders to names,
  so the row is identical with the gate disabled).

**Item A5's passes (2026-09-02) filed 1255-1261.** A5 **fixed and closed 1252,
1253 and 1254**.

**Item A6's passes (2026-09-02) filed 1262-1268.** A6-a closed **1258**, A6-c
closed **1260**, and A6-b **partially** closed **1259** — the `dims=0` flavour
only. ⚠ **A6 did not land**: its write-up agent ran `git checkout -- src/save.c`
to undo a comment edit and destroyed A6-b's uncommitted implementation. The
issue files record the design and the measurements in full and are correct; the
code is preserved as `doc/claude/op_param_batch/A6_working_tree_UNVERIFIED.patch`
and in the working tree. Read PLAN.md's A6 entry before re-running it.

* **1262** — `raw_deletevar()` shifts `names[]` and `values[]` but leaves
  `cursor_b_val[]` unshifted, so after `xschem raw del` every column from the
  deleted index on reports its neighbour's OP number. Pre-existing.
* **1263** — ngspice's batch `-r` writer, which is what `src/xschem.tcl:3854`
  runs, emits an unsatisfiable `.save` card as a plain `current` column of 0.0
  with **no `dims=0` token**, warning only on stderr. **This is the refutation of
  A6-b's headline**: on that path a `savecurrents` run still declutters. Item B1
  inherits it.
* **1264** — a genuinely zero-length vector makes ngspice's `write` refuse the
  whole plot and produce no raw at all, in one form segfaulting. A deck-generator
  defect, and it corrects "neither says a word on stderr" in measurements §22 and
  spec landmine 11 — both now corrected in place.
* **1265** — the absence rule reached **one of three** readers of
  `cursor_b_val[]`; `src/token.c`'s six `@spice_get_*` branches and
  `ngspice::ngspice_data` still publish the fabricated `0`.
* **1266** — `annotate_op` and `raw clear` move the declutter gate **without
  touching geometry**, so the click box and the render disagree though every
  `symbol_bbox()` door now agrees. **Item B4 must still refresh the bboxes.**
* **1267** — three coverage holes found by A6's own sabotage pass, in the shape
  of 1254: the `dims=0` parse is guarded by one row, the numbered-point defence
  by one list element, and the pull/backstop split by nothing behavioural.
* **1268** — about a dozen `save.c:NNNN-MMMM` citations live in `.tcl` comments
  and only **two** are under a resolve-check; several are already rotted by up to
  1874 lines.

~~**The next free number is 1269.**~~ **1269** was filed by the DRIVER of the
same batch, not by a crew: `test_wave_sigbrowser_i12`'s BX42 reds on a dev
display that has been used and greens on a freshly started one — measured across
five binaries including A4's own commit built in a clean worktree, so it is the
display and not the code. ~~**The next free number is 1270.**~~ (1270 taken by item A7 — see below)

**Item A7 (2026-09-03) filed 1270 and closed nothing.** A7 attempted
**1255**, **1256**, **1257** and **1261** in one pass; its adversary refuted the
central mechanism and the item is **`[F]`, reverted**. The four target issues
stay **open**; each carries an "A7 attempt" section pointing at 1270.

* **1270** — A7's declutter counter is bumped at `text_hidden_core()`'s rung
  `return 1`, which sits **above** the `show_hidden_texts` / `HIDE_TEXT` /
  `HIDE_TEXT_INSTANTIATED` arms, so it answers "the rung said hide first" and not
  "this text would otherwise have been drawn". On any annotated device whose only
  non-`@name` text is already `hide=instance` (**57 shipped
  `xschem_library/devices/*.sym`**) or `hide=true`, the sheet is byte-identical
  at mask 1 and mask 9 and all three status producers still claim a declutter.
  Carries the four-line repair, A7's whole sabotage matrix, the one real coverage
  hole it found (row A62 is blind to its own sabotage), and the adversary's ten
  residual risks. A7's code is preserved as
  `doc/claude/op_param_batch/A7_working_tree_REFUTED.patch`, applying cleanly to
  `355a3dc6`.

* **1271** — `ase::op_report_missing` counts a device whose every saved parameter
  came back `dims=0` as "answered", because `ase::cap_raw_plots` keeps only the
  second tab-separated field of a `Variables:` line and throws the `dims=0`
  carrier away. Claimed and written by item **B1**, 2026-09-03; it is why B1's
  seam enumerated from `xschem raw list` and not from that parser. **FILED, NOT
  FIXED.**
* **1272** — `op_annot::raw_or_blank` passes a **non-finite** through (`string is
  double -strict` accepts `nan`/`inf`) and only a **second**, separate
  `op_annot::_finite` call rejects it; nothing at the seam obliges a new caller to
  make that call. Measured by item **B1**, which did not make it and was refuted
  for it — a binary raw carrying a NaN came back as `devices {@m.x1.m1 {{id nan}
  …}}`, and B3 rendering that would put `id = nan` on a schematic, which is
  verbatim what invariant I3 forbids. Carries the ascii/binary asymmetry
  (`nan`→`0` through `my_atof()`), the recommended one-stage fix and its two
  rejected alternatives. ~~**FILED, NOT FIXED.**~~ ✅ **FIXED 2026-09-03** in
  item B1's driver re-do, by option 1 plus a companion accessor: the three
  outcomes moved into a new `op_annot::raw_class` (`absent` / `nonfinite` /
  `value`) and `raw_or_blank` became one line on top of it, so every present and
  future consumer is correct by default and the seam that needs the third
  outcome has one place to get it. All six acceptance rows green; sabotage
  (deleting the `_finite` line) reds NF1 NF2 NF5 NF6 NF7 and nothing else.

* **1273** — which directory is `<project>` for `op_param_lists.conf`? DD-3
  names the tier and leaves the word undefined, and there is no `<dir>/.xschem/`
  precedent in this tree. Claimed by item **B2**, 2026-09-03. **RULE DEBT** —
  B2 shipped `[pwd]/.xschem/` by ladder L2 (measured: `current_dirname` moves
  under a descend and pwd does not) and the user can overrule it in one proc.
* **1274** — `op_annot` publishes **no registration order**: `::op_annot::desc`
  is a Tcl array, `array names` answers hash order, and there is no
  `op_annot::types`. So the driver's "first registered wins" for item B2's class
  seed is unimplementable as written. Claimed by item **B2**, 2026-09-03, which
  shipped *first in lexical order of the `type=` token* — deterministic, and it
  coincides with registration order for all three shipped PDKs. Carries the
  one-line repair. **FILED, NOT FIXED** (B2 may not edit op_annot.tcl).
* **1275** — the `op_param_lists.conf` grammar is **unratified**: DD-3 rules the
  file is data and never sourced, and states the cost, but not the grammar.
  Claimed by item **B2**, 2026-09-03. **RULE DEBT** — carries the grammar as
  shipped, verbatim, plus the one place B2 *refines* DD-3 (the tier win is per
  (scope,key,listname), not per class).

* **1276** — `op_param_lists::write_conf` returns **1 with no report** when the
  settings went somewhere else: a target that is a **directory** takes the temp
  *inside* it (`file rename -force` does not fail on a directory destination),
  and a target that is a **symlink** is replaced by a regular file while the real
  file keeps its old bytes. Atomicity and the never-truncate row both hold; the
  "returns 1, or 0 with a report" half does not. Found by item **B2**'s
  adversary on B2's own new code. **FILED, NOT FIXED** — carries both guards.
* **1277** — the **flavor glob wins by `lsort` order**, not by narrowness or
  file order, so with `*fet*` and `*nfet_01v8*` both matching, the broad one wins
  in both insertion orders and the winner flips when the *loser* is renamed. Part
  2: a flavor key carries **no class**, so a MOS flavor list can answer a
  `capacitor` query. Found by item **B2**'s adversary. **FILED, NOT FIXED** —
  blocks nothing, but the class field is a **grammar** change and so must be
  settled before **B5** writes the first flavor entry (see 1275).
* **1278** — a shared `op_param_lists.conf` can **wedge its reader and freeze its
  consumer** without executing anything: `effective` runs `string match` on an
  unbounded pattern from the file (measured 0.85 ms / 14.6 ms / 129 ms / 11.6 s /
  >70 s at 5/7/9/11/13 stars, accepted at load with zero reports), and
  `_parse_line`'s duplicate check is quadratic (19/67/249/1035 ms at
  1k/2k/4k/8k rows). DD-3's parser is safe; the consumer is not. Found by item
  **B2**'s adversary. **FILED, NOT FIXED** — fix is a wildcard cap at parse time.
* **1279** — `op_param_lists::apply` with no arguments iterates the **class map**,
  so a type the map does not name is never a candidate: an owned list for it is
  stored, correct, and **invisible on screen** because `::op_annot::gen` never
  moves (invariant **I5** failing silently). Every shipped-but-unmapped token
  inherits it (`varactor`, `esd`, `inductor`, `pnp`, part numbers). Found by item
  **B2**'s adversary. **FILED, NOT FIXED** — carries the two-line fix, and
  re-rejects growing the default map.
* **1280** — `op_param_lists::apply` **silently narrows the deck's `.save`
  cards**: `op_annot::_cards_for` (op_annot.tcl:2808-2820) emits one card per
  `params` row and `apply` writes the **annotation** list into `params`, so
  trimming list 1 stops the deck saving what list 2 asks for and those rows go
  **permanently blank** (rule R1, invariant I3) with no report. The three lists
  are not independent. Found by item **B2**'s adversary. **FILED, NOT FIXED** —
  the recommended union fix carries a **user question for B5** (does Delete stop
  drawing, or stop saving?).
* **1281** — writing the **project** settings file exports the author's
  **user-global** class map and lists into it, because the store flattens the
  tiers and keeps no provenance. For a file whose headline feature is
  shareability, Save checks one person's personal taste into the team's file and
  the next teammate's Save carries theirs back. Found by item **B2**'s adversary.
  **FILED, NOT FIXED** — fix is a per-entry `origin` tag, needed in B2's seam
  before **B5** can write only the right half.

* **1282** — the RDW renders a **DC sweep as an operating point**: the seam's
  allow-list is `{op dc}` (`ase.tcl:8803`, copied from `update_op()`'s own
  guard), so a `dc` raw answers `ok` with real point-0 numbers and the window
  prints them under *"these are the **operating-point** columns this run
  saved"* with the word `dc` nowhere in the block. Measured: `sim_type = dc`,
  `state = ok`, `block-mentions-dc = 0`. `ctx` already carries `simtype` and
  `_state_sentence` already reads it — only the `not_op` arm uses it. Part 2:
  `rdw::sim` collapses *not registered* and *registered without the hook* into
  one sentence. Found by item **B3**'s adversary, re-measured by its write-up
  agent. **FILED, NOT FIXED** — the choice between naming it, rendering it
  silently and refusing it is the **user's**, and refusing reaches into B1's
  landed seam.
* **1283** — three things **B3's own new suite** claims to fence and does not,
  behind a green 32/42: newest-first **store** order has no headless witness
  (row `Q1b` pushes one block and asserts it is at index 0 — true either way,
  so `SB-OLDEST-ON-TOP` passes the whole `--nogui` arm); the union's
  **cross-bucket order** is unfenced on both arms although the file's own
  comment promises it; and the **inert-button message** is fenced only on the
  display arm. Also records two predicted sabotage reds that did **not** appear
  (`F5` under `SB-NO-UNION`, `F3` under `SB-HONESTY-ALWAYS`) so the matrix is
  honest. Found by item **B3**'s sabotage and adversary passes. **FILED, NOT
  FIXED** — item **B4** already touches this suite by its Files cell.
* **1284** — a **backend's answer dict** can make the RDW lie, blank, or raise,
  because `rdw::format_answer` treats the five-key dict as trusted input and it
  is whatever a **D-5** backend hands it. Four measured shapes: malformed at the
  dict level → the **fifth silence**, a confident false claim about the raw (the
  shape that returned B1 `[F]`); malformed at the **value** level → an
  **uncaught raise** out of the pure renderer (found by the write-up agent, not
  the adversary); a value-less pair → blank with no footnote, byte-identical to
  `absent`; a newline in a value → one pair split across two untagged lines.
  Plus one reachable relative: the blank footnote is **per-block**, so an
  empty-string value inherits a footnote that is false about it. **Unreachable
  through the shipped ngspice backend**; live for whoever adds the second one.
  **FILED, NOT FIXED.**

* **1285** — `op_annot::text` draws the **on-sheet** annotation rows from the
  same `dict get $d params` list `_cards_for` turns into `.save` cards
  (`src/op_annot.tcl:1726`, loop at `:1741`), so ruling **DD-4**'s two clauses
  — `apply` writes the **union** into `params`, *and* the display narrows to the
  annotation list — **cannot both be true of one field**. Item **B2a** attempted
  the SAVE half (issue 1280) and **was reverted in full**, so nothing of DD-4 is
  in the tree; this issue is unaffected, because it is a property of
  `825cd3bd` + DD-4 and not of B2a's code. The DISPLAY half needs
  `src/op_annot.tcl`, which B2a did not own.
  **HARD BLOCKER FOR ITEM B5**: until it lands, Delete leaves the row drawn on
  the sheet, the opposite of the user's own word *declutter*. Two options
  costed, on the owed ledger as a `rule` debt. **FILED, NOT FIXED.**
* **1286** — `ase::sim_write_conf` (`src/ase.tcl:1999-2034`), the writer
  `op_param_lists::write_conf` was **copied from**, carries **both** of issue
  1276's holes: no directory guard (`file rename -force` moves the temp *into*
  a directory target and reports success) and no symlink resolution (the link is
  replaced by a regular file, the real target left empty). Found by item **B2a**
  while fixing the copy; `src/ase.tcl` is another item's file. A written fix
  exists as `_resolve_target` + `_target_why` inside
  `doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` (that item was
  reverted, so it is not in the tree).
  **FILED, NOT FIXED.**

* **1287** — `op_param_lists::seed` reads `dict get $d params`, which `apply`
  **overwrites**, so ruling **D-7**'s "the seed comes from the PDK" promise
  answers whatever `apply` last wrote and `reset` cannot restore it. Measured
  from a fresh process: `seed(mos)` = `{id id 0} {gm gm 1} {gds gds 1}` before
  any apply, `{id id 0}` after apply **plus a full reset**. Ruling **DD-6** makes
  it worse — the seed becomes the union, silently wider than the PDK's list.
  Needs a pristine-descriptor stash. **FILED, NOT FIXED.**
* **1288** — `op_param_lists::set_list` accepts two triples sharing one **label**
  (`rc=0`, reports success) where its own file parser rejects them, measured on
  the reverted tree so it is a **HEAD defect**. `_save_set` then dedups by label
  and drops one row from the `.save` cards while the display draws it, which is
  what makes **DD-6**'s `shown ⊆ params` guarantee false and `op_annot::_kind`
  raise. **FILED, NOT FIXED.**
* **1289** — **DD-6's display narrowing blanks a `derived` row whose operand it
  removed**: `op_annot::text` builds `vars` inside the loop the ruling makes
  iterate the display key, so `gm/id` renders blank when `gm` is deleted from the
  annotation list though the deck still saves it. IHP registers exactly such
  rows. A property of the **ruling**, so it survives B2a-2's revert and binds
  whoever re-does DD-6. Three options costed; **needs a ruling**, on the user's
  queue. **FILED, NOT FIXED.**
* **1290** — `test_ase_optier_0963` check **X7** fails nondeterministically on a
  simulator launch (`rc=1 raw=-1bytes op-vectors=0`) while check `XC` in the
  **same process** makes the identical call successfully. Passed twice in
  isolation and on a second full audit; a harness/environment defect, not a code
  defect, but a standing intermittent red in a 381-suite audit. **FILED, NOT
  FIXED.**

* **1291** — `op_param_lists::apply` **raises** on a descriptor whose registered
  `params` is malformed (issue 0447's own live shape), because `_save_set` /
  `_show_set` walk `effective`, which falls through to `seed`, i.e. the
  registered string verbatim. HEAD's `apply` never called `seed` and answered
  `rc=0`. Measured A/B on the same fixture. A **new** raise door opened by item
  **B2b** in its own file; latent — `apply` has no caller until **B5**.
  **FILED, NOT FIXED.**
* **1292** — `apply` can **narrow** the sheet but nothing ever un-narrows it: no
  code path removes the `shown` key, and a class the user owns nothing for is
  `continue`d by design, so `reset` + `apply` leaves a stale `shown` and the
  schematic stays narrowed for the session. The sheet-visible half of issue
  **1287**; it is what B5's Reset button will hit. **FILED, NOT FIXED.**
* **1293** — a **duplicate label** in `params` gives a narrowed sheet and a
  `derived` row two different values: the new label→value cache is FIRST wins,
  `_evalrow`'s binding loop is LAST wins. Unreachable through `apply` (it dedups
  by label); needs a hand-written descriptor or a PDK rc. Minor, filed for
  completeness beside issue **1288**. **FILED, NOT FIXED.**

* **1294** — **under DD-7's read-modify-write, a writer classifier LAXER than
  the reader deletes the rows the reader rejected.** `_row_id` validated
  verb/scope/arity while `_parse_line` also ran `_valid_list`, the livelist
  guard and `_triple`, so a `param` row the reader refused was *identified* by
  the writer and dropped when its key was dirty — `rc=1`, **zero reports**, the
  exact signature that killed B2a and B2a-2. **THE DEFECT THAT REVERTED ITEM
  B2c.** A property of the RULING's shape, not of the patch. Blast radius
  measured for all three stamp cases. **FILED, NOT FIXED.**
* **1295** — **DD-7's read-modify-write silently rewrites line endings.** A
  teammate's CRLF settings file comes back all-LF, `rc=1`, zero reports, every
  untouched line's bytes changed — so every save is a whole-file diff, against
  the file's own reason to exist. Reusing the parser preamble (`string trimright
  \r`) is right for a parser and wrong for a preserver. An interleaved comment
  inside a rewritten group also moves. **FILED, NOT FIXED.**
* **1296** — **an existing settings file never gains the precedence sentence,
  and a v1 file keeps `version 1` while gaining v2 rows.** A collision between
  DD-7 (*preserve every row verbatim* → emit the header only into an empty file)
  and item B2c's named ACCEPT row (*the sentence the file emits is TRUE of the
  code that emits it*). Harmless until B5 writes the first file; real from then
  on. Three options costed. **NEEDS A RULING**, on the user's queue with 1275.

* **1297** — **the `not_op` refusal says "a op analysis", and the article never
  agrees.** `rdw::_state_sentence`'s `not_op` arm interpolates `$sty` after a
  literal `a`, so `dc`/`tran`/`noise`/`sp` read correctly and every vowel-initial
  analysis name — `op`, `ac` — does not. Found by item **B2d** while reproducing
  issue 1284's legal minimal refusals; outside its three-issue scope, so filed
  rather than fixed, on B2b/1291's precedent. Three options costed, (a)
  recommended. **FILED, NOT FIXED.**

* **1298** — **ruling DD-5's analysis sentence is a property of `rdw::dump`, not
  of the seam's own door.** `rdw::_analysis_line` returns `{}` when the ctx
  carries no `simtype`, and `rdw::dump_devpath` — the proc the file calls THE
  SEAM'S ONLY DOOR, and the entry point items **B4** and **B5** call — adds
  `sim` to the ctx but never `simtype`. A caller that builds its own ctx gets a
  DC sweep rendered as an operating point again, silently. Latent today
  (`rdw::dump` is the only caller and it does set it). Found by item **B2d**'s
  adversary. Three options costed, (a) recommended. **FILED, NOT FIXED.**
* **1299** — **four edges the RDW's answer-shape predicate still leaves open.**
  A device that names nothing (`devices {{} {{id 1.5}}}`) renders a blank
  sub-header above real numbers; `_nonfinite_text` still discards its argument,
  so a triple whose third field is junk still asserts non-convergence;
  minimum-arity checking truncates a padded entry in silence; and `_named`'s
  `string trim` disagrees with `ase::op_param_split`'s exact-empty by exactly
  one shape. Same reachability class as everything issue **1284** closed —
  unreachable through shipped ngspice, reachable by the user's custom backend.
  Found by item **B2d**'s adversary. **FILED, NOT FIXED.**

* **1300** — **the RDW's keys 1, 2 and 3 select a list IDENTITY and narrow no
  CONTENT.** `rdw::format_answer` takes no list argument and row **S1** forbids
  naming the list store inside `src/rdw.tcl`, so the three keys render
  byte-identical blocks; only `::rdw::listkind` differs. The spec's §4.2 B4
  table says they should narrow, and **no item in PLAN owns that work**. Found
  by item **B4**; three options costed, all rejected for now. This is B4's own
  **E question**. **FILED, NOT FIXED.**

* **1301** — **the cadence profile's own descend never suspends a canvas
  command mode.** `cmdmode::suspend_all` is called from `hi_descend_do` and
  `hi_descend_pick_arm` only; `cadence::descend_into_inst`
  (`utils/cadence_nav.tcl:260`, bound to Ctrl-x) calls `xschem descend
  -fallback` directly. Measured with a live pick mode: the descend happens, the
  suspend arm is never called and the mode stays seized. With Ctrl-Shift-X
  `clone_canvas_bindings` then copies the seized bindings onto the child — the
  exact ordering `src/cmdmode.tcl:44-50` exists to prevent. Predates item B4
  (ASE Direct Plot has it too); pinned by row **D2** of
  `tests/headless/test_rdw_keys_1245.tcl`. **FILED, NOT FIXED.**

* **1302** — **the RDW pick mode has no on-canvas indicator.** ASE Direct Plot
  keeps a bottom-status-line prompt alive with `sod_prompt_pump` because the C
  engine blanks `.statusbar.10` on every event; those procs live in
  `src/ase_window.tcl`, outside item B4's Files cell. B4's mode therefore
  announces itself with one CIW line and nothing after. Carries a `look` debt.
  **FILED, NOT FIXED.**

* **1303** — **a Tcl canvas pick reads SNAPPED mouse coordinates and can answer
  for a device the user did not click.** `scheduler.c` exposes only
  `mousex_snap`/`mousey_snap` (`:5018`, `:5022`); there is no unsnapped
  accessor, while every C click path reads the unsnapped `xctx->mousex/mousey`.
  Reproduced on the shipped `cmos_inv.sch`: the exact point `175.175 -199.612`
  answers `M1`, the snapped point `180 -200` answers `R1` — a different device,
  from one pixel. Swept: 6.4% of in-bbox points miss, 0.5% resolve to another
  device. The same default is live in `ase::ui::sod_click`, though the harm
  there is not measured. Found by item **B4**'s adversary; **it is why B4 was
  reverted**. **FILED, NOT FIXED.**

* **1304** — **a canvas command mode swallows `<ButtonRelease-1>` and leaves
  C's rubber band alive, so pointer drift CHANGES THE SELECTION.** The seize
  binds `<ButtonPress-1>`, `<ButtonRelease-1>` and `<Key-Escape>` and **not**
  `<B1-Motion>`, so C keeps getting Button1Mask motion and starts a selection C
  can never terminate. Measured on item B4's mode: 1 px of drift leaves
  `ui_state 16` alive after `ESC`; an eight-step drag selects 13 objects; the
  same gesture with no mode leaves `ui_state 8`, terminated. Breaks the user's
  own *"clicking will not change selected set"*. The binding shape is live in
  `src/ase_window.tcl` at `735ea26e`. Found by item **B4**'s adversary; **it is
  why B4 was reverted**. **FILED, NOT FIXED.**

* **1305** — **a canvas command mode re-armed while SUSPENDED latches its own
  seize as the predecessor.** `rdw::pick_start`'s guard lets a suspended mode
  fall through into `_pick_seize` without clearing `pick(suspended)`, so the
  later `resume_all` seizes a second time and latches the seize's own scripts;
  `ESC` then restores them and the canvas is seized for the rest of the session.
  Measured on `:99`, with the control that `ase::ui::select_on_design` is immune
  because it ends the previous mode first. In item **B4-2**'s reverted patch,
  not in the tree. Found by B4-2's adversary; **it is one of the three
  refutations that reverted B4-2.** **FILED, NOT FIXED.**

* **1306** — **the Results-window focus hand-back bounces a DELIBERATE click
  into the text pane.** `rdw::_focus_handback`'s `%W eq .rdw` guard is reasoned
  from bindtags; the real mechanism is X's ancestor `FocusIn` chain, which
  delivers `%W = .rdw` with detail `NotifyNonlinearVirtual` when focus crosses
  into `.rdw.p.t`. Measured, both halves in one process on a WM-less server: a
  real first-of-session dump leaves `focus_pending 1`, and the user's next click
  into the pane is bounced to the canvas. The pane is what the feature exists
  for. In item **B4-2**'s reverted patch, not in the tree. **FILED, NOT FIXED.**

* **1307** — **`clone_canvas_bindings` copies a LIVE command-mode seize onto
  every new window or tab, and the mode's `ESC` restores only its own canvas.**
  `src/cmdmode.tcl:44-50` documents the hazard and states the invariant that
  saves it — *"every suspend site in the descend chain runs before
  `schematic_in_new_window`"* — which is true of the descend chain and of
  nothing else; `File > New Window` has no suspend site. **TRUE OF THE TREE
  TODAY**: measured against shipped `ase::ui::select_on_design` with no B4-2
  code loaded — the child keeps `sod_click`/`sod_end` and its `ESC` is dead.
  **FILED, NOT FIXED.**

* **1308** — **the Results window now HOLDS the keyboard and nothing on it ENDS
  the command mode.** Filed by item **B4-3** after its own issue-1306 fix landed:
  once the user clicks the text pane — the gesture the window exists for — a real
  `ESC` and a bare `2` are both dead, because the mode's four keys and its Escape
  are bound on the **canvas** (`src/rdw.tcl:1389`, `:1393`,
  `src/cadence_style_rc:181-184`) and `.rdw` carries none of them. Measured
  first-hand on `:99`/openbox: `WU-4 afterESC focus=.rdw.p.t seized=1 esc_on_rdw=0
  esc_on_pane=0`. **Identical on the unfixed arm** in the ordinary case (the WM's
  map-time grant had already spent the one-shot), so B4-3 neither causes nor fixes
  it — but on a WM that does not grant, the fix converts *"ESC works, copy
  impossible"* into *"copy works, ESC stuck"*. Its ruling is the SAME ruling as
  1306's. **FILED, NOT FIXED.**

* **1309** — **a list key pressed during a suspended descend leaves the DESCEND
  unterminable.** The other side of issue 1305's key press, and 1305's fix does
  not reach it: the re-seized mode `break`s the canvas click and the canvas
  `Escape`, which are `hi_descend_pick_arm`'s only two terminals
  (`src/xschem.tcl:7707`, `hi_descend_pick_cancel`), so C's arm stays live,
  `cmdmode::is_suspended` sticks at 1 and a later `cmdmode::suspend_all` returns
  0 — **no command mode is suspended by any subsequent descend**. Measured by
  B4-3's adversary, **identical on both arms**. Overlaps **1307**; option (d) in
  the file probably subsumes both. **FILED, NOT FIXED.**

* **1310** — **a NARROW (device-flavor) list is stored, written to the settings
  file and honoured by `effective`, and never reaches the drawn sheet.** Filed by
  item **B5** while wiring the scope dialog: `op_param_lists::apply` re-registers
  descriptors per `type=` token and passes no cell name, and `op_annot` holds ONE
  descriptor per type, so a per-cell display list has nowhere to live. Measured —
  `effective` answers the narrowed list for M1's cell and the PDK seed for M2's,
  while `op_annot::descriptor` is byte-identical before and after. The button
  SAYS so rather than looking broken (row BT21). ⚠ **B5 was REVERTED (issue
  1314), so nothing says so today; the measurement stands.** **FILED, NOT
  FIXED.**

* **1311** — **DD-8's precedence is FILE ORDER, and the Results window cannot
  reorder the entries whose order it is.** DD-8's own justification is *"the user
  already has a reordering UI"* — but the pane shows one line per PARAMETER of one
  dumped device, never the settings file's `flavor` ENTRIES, so Up and Down move
  `gm` above `id` and cannot move `flavor mos *nfet*` above `flavor mos *`.
  Measured by row BT10's third leg. Item **B5** detects the shadowed case (what it
  just wrote is not what `effective` now answers) and named the remedy in the
  status line — ⚠ **B5 was REVERTED (issue 1314); the measurement stands, the
  detection does not exist in the tree.** **FILED, NOT FIXED.**

* **1312** — **`apply` writes the union into `params`, and `seed` reads that same
  field back as "the PDK's own list".** Filed by item **B5**, the first caller of
  `op_param_lists::apply` in the tree. Measured 2026-09-04: with two type tokens
  in one class and nothing owned, reordering the ANNOTATION list and applying
  changes what the unowned SUMMARY list answers, because `_params`
  (`op_param_lists.tcl:700`) reads the field `apply` just overwrote. ⚠ **THE
  ORIGINAL ENTRY HERE SAID "content is a superset so nothing is lost". THAT IS
  FALSE** and it is corrected in the issue file: the superset property holds only
  while one of the two lists is UNOWNED, and two Delete presses own both — after
  which `params` loses the PDK's row, `_cards_for` stops emitting its `.save`
  card, and **ruling DD-4/DD-6 is violated**. This is the BLOCKER that refuted
  and reverted item **B5** (issue **1314**). **FILED, NOT FIXED.**

* **1313** — **the settings file is written by the Results window and read by
  nobody.** `op_param_lists::load` has no caller anywhere in `src/`, so item B5's
  Save produces a correct `<project>/.xschem/op_param_lists.conf` that a restart
  ignores. "Reorder persists through Save and reload" is provable inside ONE
  process (write_conf -> reset -> load_conf, rows BE1 and S1b) and not across a
  restart. Not wired by B5 because it is a startup-ORDERING change:
  `op_param_lists.tcl` is sourced before any PDK `_procs.tcl` and
  `op_annot::register` has replace semantics, so the `apply` that must follow the
  load would write into an empty registry and be discarded. Recommended (c): an
  explicit "Reload parameter lists" verb beside the window's Save. ⚠ **B5 was
  REVERTED (issue 1314), so there is no Save either; the analysis stands.**
  **FILED, NOT FIXED.**

* **1314** — **the wired Delete button changes what the simulator is asked to
  save, and destroys the PDK seed doing it.** Filed by item **B5**, whose
  implementation it refutes; **B5 was reverted in full (status F)** and the patch
  is preserved at `doc/claude/op_param_batch/B5_working_tree_REFUTED.patch`.
  Three attacks, each re-measured independently before the revert: **A5** two
  broad Deletes remove the parameter's `.save` card and the PDK row with it,
  irreversibly inside the session, with Add then blaming the PDK for a row xschem
  deleted (mechanism = **1312**, in a file B5 may not edit — so B5 is
  **mis-scoped**); **A6** the broad arm decides scope by exact-key `owns` while
  `effective` narrows by glob, so it edits a list the device does not use and
  reports success; **A7** a `set_list` that silently reduced the list by label is
  reported as a plain success, breaking **1288**'s ruled promise through the only
  UI door there is. Also records the two suite blind spots (BE3 fences one
  delete; SD3's fixture cannot fail) and the re-land order. **FILED, NOT FIXED.**

* **1315** — **the documented invariant-I5 round-trip no longer redeclares the
  seed.** Filed by item **B2e** while implementing ruling DD-13 (issue 1312).
  Not a defect: `op_annot::register`'s declaration stamp is PRESERVE-IF-PRESENT,
  which is what makes `op_param_lists::apply` structurally incapable of
  destroying a declaration, and its price is that the recovery recipe printed in
  all three PDK `_procs.tcl` files now changes what the run computes and what the
  sheet draws but NOT what `seed` answers. The escape hatch (`dict unset d
  declared`, or a fresh dict as all four shipped sites use) is documented in the
  three PDK files and in `register`'s header, and row **N10** of
  test_op_param_store_1245 fences BOTH directions. **STATUS E — a `rule` debt is
  owed; overruling costs one proc and one golden.**

* **1316** — **section N's two headline rows fence less than they claim.** A
  TEST defect in item B2e's own new suite section, found by B2e's Verify-B and
  Verify-C passes. **N11** — the driver's own *"attack the declaration, do not
  assert it"* row — reads all six of its terms AFTER the `reset`+`apply` that
  fires the issue-1292 undo, so three of the seven sabotage variants broke the
  declaration mid-storm and N11 stayed green; **N12** counts source lines
  carrying the literal key name, so a `dict set d $key …` evades it, which is
  the shape `_apply_state` already uses two procs away. Both fixes are pure
  additions of terms. **FILED, NOT FIXED.**

* **1317** — **the issue-1292 undo identifies "apply's own write" by byte
  equality on two fields, not provenance.** `_restorable` reverts any descriptor
  whose `params`/`shown` still equal what apply wrote, even one a third party
  registered with a different `devpath` and a different `declared`. Measured;
  contrived to reach, and the realistic neighbour (the documented I5 round-trip)
  is benign. Three options costed, (3) recommended. **FILED, NOT FIXED.**

* **1318** — **`op_param_lists::apply` returns one list holding two opposite
  meanings**: the types it NARROWED and the types the issue-1292 undo put BACK.
  Harmless today (no functional caller anywhere in `src/`), and it **binds the
  re-land of item B5** — a status line saying *"updated N device types"* is
  wrong for exactly the press, Reset/Defaults, whose accuracy matters most.
  Recommended: return a dict. **FILED, NOT FIXED.**

* **1319** — **a malformed declaration is now reported twice per type.**
  `_merge_declared` re-reads through `_params` after `_save_set` may already
  have, so with one class list unowned — the *common* shape — `apply` emits 4
  reports for a two-type class where HEAD emitted 2. Measured for all three
  ownership shapes and re-measured independently before filing. `said` is
  documented as countable, so a count that doubles for one shape is a count
  nobody can use. ⚠ DD-13 rejected caching `_params`; the fix must be scoped to
  one `apply` frame or it breaks invariant I5. **FILED, NOT FIXED.**

* **1320** — **with both class lists owned and EMPTY, `params` now becomes the
  full declaration and `_claims` flips 0 → 1**, so three `.save` cards appear
  where HEAD emitted none. Correct — it is ruling DD-4 holding for every
  ownership shape, and DD-4 states the price itself — and **no pixel moves**
  (traced into the C: `op_annot::text` returns empty, so the declutter gate
  never opens). Filed because it is stated nowhere in the change and because it
  **falsifies** the risk note item B2e was carrying (*"a settings file owning
  both lists empty still yields zero `.save` cards"*). Records the adjacent
  hand-written `declared {}` case too. **FILED, NOT FIXED.**

* **1321** — **a narrow scope key that self-matches can still match siblings.**
  The scope dialog's narrow arm mints the store key `{<cls> <cellname>}`, whose
  second field `governs` matches as a **glob**. Item B5-2 fixed the half that
  breaks loudly — `a[bc].sym` and `a\b.sym` do not match themselves, so the key
  answered nothing and DD-8's shadow sentence then blamed an earlier entry that
  does not exist; the narrow arm now refuses those up front (window row BT28).
  The residual: `a*b.sym` and `a?b.sym` **do** self-match and also match every
  sibling, so *"this device flavor only"* silently governs a class of them. Not
  fixed here — the guard cannot tell a deliberate glob from a literal, and no
  PDK in this tree ships such a cell name. Recommended: an exact-match key form
  decided inside `governs`, the one scan item B5-2 made single. **FILED, NOT
  FIXED.** ⚠ **Item B5-2 was REVERTED**, so the half described above as fixed
  lives only in `doc/claude/op_param_batch/B5-2_working_tree_REFUTED.patch`, not
  in the tree. Both halves are open against `fluid-editing` as it stands.

* **1322** — **`rdw::_subject` resolves the block against whatever sheet is
  open**, so a button edits a device the user is not looking at and names the
  wrong class in the status line. `_hdr_instname` captures the header's path half
  and returns only the name; `_subject` re-resolves that bare name against the
  live editor; nothing clears `::rdw::blocks` on a load. `M1` is every device
  symbol's default template name, so two sheets is the ordinary case. **This is
  the defect that reverted item B5-2.** Records the measurement that the obvious
  fix — comparing the cadence path — **does not catch its own reproduction**
  (both sheets top-level, `PATHS_EQUAL=1`). **FILED, NOT FIXED.**

* **1323** — **a reorder becomes a deletion when two declared triples share a
  label**, dropping a `.save` card — rulings **DD-4/DD-6** violated by the most
  purely-display operation the feature has. `register` accepts a duplicate label
  and `seed` returns it verbatim, while `set_list` dedupes by label, so a
  length-3 reorder request comes back length 2 (measured at HEAD with no B5-2
  code). Latent with sky130, gf180 and IHP — all three checked — and reachable
  through invariant **I5**'s user rc. **FILED, NOT FIXED.**

* **1324** — **the pane's `insert` mark drifts on every new dump**, so *"the row
  your cursor is in"* and `::rdw::targetrow` disagree (measured: widget 9,
  variable 3) — the state `set_row`'s own comment says cannot happen.
  `render_pane`'s `delete 1.0 end` collapses the right-gravity mark and the
  re-inserts carry it to the end. A confusing refusal rather than a wrong edit,
  and invisible because the pane is `-state disabled` and draws no cursor.
  **FIXED by issue 1337** (item R1, 2026-09-05): `_target_line` no longer reads
  the mark, so the two answers cannot disagree — measured 0/0 where this entry
  measured 9/3 — and the pane now SHOWS the targeted row, which is what this
  entry's own recommended fix asked for. The mark still rides to the end on a
  repaint (Tk's right gravity; nothing removes that) but has no readers left,
  and the next `set_row` puts it back.

* **1325** — **Save writes the USER-GLOBAL settings file while reporting a
  project write.** `rdw::_do_save` hardcodes `conf_path project`, and with cwd
  `$HOME` — how xschem is ordinarily launched — the project and user tiers are
  **the same path** (measured `SAME=1`). `op_param_lists::load` already dedupes
  that collision; the writer does not. Ruling **DD-7** and store row **BE5** both
  go vacuous in the common case. **FILED, NOT FIXED.**

* **1326** — **a Delete on a duplicate-label declaration drops TWO display rows
  and a `.save` card.** Issue 1323's mechanism arriving through a different
  button: the declaration's duplicate label survives `_merge_declared`, so one
  Delete press takes the named row AND one of the duplicate pair out of both the
  display and the deck, with verdict `ok` (measured: 3 rows -> 1,
  `.save @m.m1[ids]` gone). Item **B5-a** fixed 1323's reorder half and narrowed
  its guard to the reorder ON A MEASUREMENT — guarding the Add arm reds row
  **BT27**, which golds issue **1288**'s ruled accept-and-report. Delete has no
  ruling either way, so the choice is the USER's. **FILED, NOT FIXED.**

* **1327** — **`conf_tiers` does not follow a SYMLINKED settings file**, so Save
  can still name the wrong tier. `file normalize` does not resolve a path's
  final component; `write_conf` resolves the link chain and writes the real
  file, `conf_tiers` compares unresolved strings, so a project `.conf` that is a
  symlink to the user-global one answers `project` while the bytes land in the
  user's (measured: `CONF_TIERS_OF_PROJ=project`, `USER_GLOBAL_FILE_CHANGED=1`).
  **This is issue 1325's own title reproducing**, which is why 1325 is
  PARTIALLY FIXED and not FIXED. Found by item B5-a's adversary, reproduced
  independently. Nothing ships it yet — the only callers are in the preserved
  patch — so it is a **precondition on item B5-3**. **FILED, NOT FIXED.**

* **1328** — **a DD-15 refusal raised inside a PDK `_procs.tcl` aborts the rest
  of that file.** All four shipped `op_annot::register` sites are UNCAUGHT
  (`sky130A/sky130_procs.tcl:449`, `gf180mcuD/gf180_procs.tcl:155`,
  `ihp-sg13g2/sg13g2_procs.tcl:806` and `:856`), and `source` unwinds on the
  first raise — so one duplicate label costs every declaration after it in that
  file, including, in sg13g2, a `vertical_npn` the author never touched
  (measured `SOURCE_RC=1`, `SECOND_TYPE=0`). A consequence of ruling **DD-15**,
  found while implementing it in item **B5-3**. The fix wraps three files
  outside that item's Files cell for a case no shipped PDK hits — all four
  shipped declarations carry distinct labels and store row **DL3** golds them
  accepted by value. **FILED, NOT FIXED.**

* **1329** — **ruling DD-16's cross-sheet clause is FALSE through a symlink.**
  `rdw::_sheet_note` compares the block's stamped `schname` against
  `xschem get schname` as plain strings — a recorded choice, because `_fid` is a
  private store verb window row **BT22** forbids `rdw.tcl` from naming. One
  sheet opened by two names is announced as two (measured `STRING_EQ=0`, clause
  emitted). The proc's own header claims byte-identity "whenever they name the
  same sheet"; that sentence is refuted. One wrong advisory sentence, never a
  wrong write. Found by item **B5-3**'s adversary. **FILED, NOT FIXED.**

* **1330** — **`rdw::_apply_now` swallows an `apply` failure while the status
  line reports success.** `rdw::button` composes its whole sentence from
  `rdw::_edit` and only THEN calls `_apply_now`, whose three calls are each in a
  bare `catch` and which returns `{}` unconditionally (measured
  `APPLY_NOW_RC=0`, `APPLY_NOW_RES=''`, `EDIT_BEFORE_APPLY=1`). A silent-failure
  channel, not a live defect — the only measured route to an `apply` failure is
  issue 1326's descriptor, which **DD-15** now refuses. **FIXED by issue 1338**
  (item R2, 2026-09-05): `_apply_now` answers `{}` on success and a sentence on
  failure — a raise quoted, a `_say` read as the store's own report — and both
  `rdw::button` call sites append it. Measured: an ordinary accepted press adds
  nothing to `said`, so no success sentence moved.

* **1331** — **the narrow arm refuses a symbol path containing a space, in the
  store's own internal jargon.** A cell name with whitespace matches neither of
  `rdw::_edit`'s two up-front narrow guards and falls into `set_list`, so the
  user gets `the flavor key "spxcls {/home/u/My Designs/sp.sym}" has a field
  that is empty or carries whitespace…` — brace syntax exposed, two causes
  named, and, unlike both siblings, NO *"Choose every device of class X
  instead."* Nothing is mis-stored. **FILED, NOT FIXED.**

* **1332** — **the keys suite's SD rows drive a real modal on a fixed
  `after 100` and can false-red under load.** Rows SD1/SD2/SD3b arm their
  driver on a fixed timer rather than polling for `.rdw.scope`; observed once in
  134 runs as `SD3b -> {0 0 0 {} 0 0 {}}` while a second crew agent held the
  same `:99` display (issue **0990**'s situation). Instrumented margin: the
  dialog appears 3–6 ms after the invoke, max 19 ms over 88 runs, against a
  100 ms timer. The deadman worked — it false-redded, it did not hang. A TEST
  defect; the fix is to poll, not to widen the delay. **FIXED** 2026-09-05 by item
  **P3** of the RDW repair batch: the three rows now POLL for the dialog instead of
  betting on a fixed delay, and rows **SD5**, **SD6** and **SD7** were added, each of
  which reds under the old driver. ⚠ *This bullet read "FILED, NOT FIXED" until
  2026-09-17, twelve days after `1332-*.md` line 3 was changed to `Status: FIXED`.
  A summary line does not update itself when the file it summarises does — when you
  fix an issue, edit **both**, in the same commit.*

* **1333** — **the blanket operating-point dump shipped with no caller.**
  `op_annot::opdump_read` was defined, tested at 33 green checks and invoked by
  nothing; shape `d` emits no per-device card, so the raw held zero device
  parameters and every annotation row rendered blank — issue 0617 verbatim.
  Measured on the ngspice build carrying the printer fix: five working rows
  became five blank ones. Merge now runs in `op_annot::db_attach`. **FIXED.**

* **1334** — **a mixed-case run folder silently loses the dump, and the probe
  cannot see it.** ngspice folds the whole `show >` target and exits 0 writing
  nothing; capability deck C asks with a *relative* target so it has no
  directory to fold. Control proves it is shape `d`'s own regression: the
  per-device shape annotates fine in the same directory. New guard **G3b**,
  reason token `dumppath`. **FIXED.**

* **1335** — **the missing-numbers report is silent under shape d.** Defeated by
  `.options savecurrents`, which puts `i(@dev[id])` in the raw with no card
  behind it; the reporter compares devices, so one free vector marked the device
  answered while six rows were blank. `meta` now carries `optier` and the
  reporter asks the sidecar. **FIXED.**

* **1336** — **`test_op_dump_altshow` was absent from `full_audit.sh`.** The
  `nogui_tests=` list is explicit, so the audit never asked the suite and
  reported the same totals either way. **FIXED.**

## Reserved: 1337–1341, the RDW batch (`doc/claude/rdw_batch/`)

* **1337** — **the RDW's target row was invisible: the cursor the buttons obey
  drew nothing.** `rdw::set_row` / `rdw::_target_line` have been Delete's,
  Add's, Up's and Down's subject since item B5-3, but the pane is
  `-state disabled` and draws no insertion cursor, so the row those buttons act
  on had nothing on screen to mark it. Item **R1**: a `cursor` role DERIVED
  from the pane background (ruling DD-2; measured #ffffff -> #d7d7d7 light,
  #202020 -> #484848 dark, where a 0.88 multiply gives #1c1c1c and is
  invisible), a full-width `cursor` tag lowered below `sel`, a `<Button-1>`
  that does not `break`, and DD-1's clear on `rdw::push`. **FIXED.**
* **1338** — **Up and Down moved the store and the sheet, and not the window.**
  Measured at HEAD `27122ca4`: an accepted press moved `effective`, rewrote
  `shown` for both type tokens, and bumped `annot_overlay_flushes` by 1 — while
  `::rdw::blocks` came back byte-identical, so the pane kept showing the order
  the user had just changed. PLAN.md's premise that the SCHEMATIC half was the
  missing one is wrong, and `xschem annotate_op` (what key `6` calls) RELOADS
  THE RAW, so calling it would destroy a 1-point op. Item **R2**: the block is
  RE-SLOTTED (never an adjacent-display-line swap — the pane's row order is not
  the list's), no row crosses a `  <rawdev>` sub-header, an undeclared row keeps
  its slot, every block of the edited class follows, and the cursor follows the
  ROW. Carries the fix for **1330**. **FIXED.**
* **1339** — **select + `Ctrl-C` did not copy, and double-click-then-drag threw
  the double-clicked word away.** DD-5's literal reading is a NO-OP on this
  build: `event info <<Copy>>` already carries `<Control-Key-c>` AND
  `<Control-Key-Insert>`, and with the keyboard in the pane a real Ctrl-C
  already copied. Three real mechanisms, each driven: the copy rode a Text
  CLASS binding and so died the moment the keyboard left `.rdw.p.t` (which
  `rdw::_arm_focus_handback` arranges after every dump); a Tk text widget with
  `-exportselection 1` DELETES its own `sel` tag when another client takes
  PRIMARY, which is what VcXsrv's clipboard bridge does on its own schedule, so
  the highlight vanished and the copy wrote nothing; and `bind Text <1>`
  re-anchors on the press, cutting the double-clicked word in half. Item **R3**:
  the chord moves to the TOPLEVEL bindtag (never `bind all`, which reaches
  `.drw`), a `keepsel` mirror kept alive by an owner test that tells a THEFT
  from a deselect (measured: after a deselect the pane still owns PRIMARY,
  after a theft it does not), a `<B1-Motion>` union for the extend that needs no
  Tk internals, a right-click Copy / Select All, and a copy that never wipes a
  clipboard it has nothing to write to and SAYS which it did. `-exportselection
  0` was the one-line fix and was rejected: it costs middle-click paste (row
  CP10 is the receipt). **FIXED.**
* **1340** — the RDW must RAISE when something is sent to it, like the Library
  Manager on Ctrl-Alt-S — raise only, no focus. `rdw::push` said nothing to the
  window manager at all, and `rdw::open`'s plain `raise` is an inert no-op on
  the server the user reported from (issue 0054). Item **R4**:
  `raise_activate_toplevel` SPLIT (the shared body becomes `raise_toplevel`;
  the activation line MOVED, not deleted — fourteen other callers keep it), and
  `rdw::push` raises through the half without it. The re-map takes the keyboard
  unless the existing one-shot hand-back is armed for it, which is the half of
  this the user forbade in the same sentence. **FIXED.**
* **1341** — **the RDW printed raw exponents where the schematic prints
  engineering notation.** `rdw::_value_text` returned the seam's string as it
  arrived, so the same transistor read `id : 1.11e-05` in the window and
  `id = 11.1u` on the sheet two inches away. Item **R5**: that proc becomes a
  WRAPPER around `op_annot::eng_or_blank` — the sheet's own proc, so the two
  surfaces cannot drift and the user's `ev_precision` reaches both — with three
  arms ruling DD-7 requires kept intact: `(no value reported)` for a blank
  (1284), `rdw::_nonfinite_text` for a non-finite value (1272 — eng_or_blank
  would blank it, and `to_eng 1e400` answers the plausible-looking `infT`), and
  VERBATIM pass-through for a value that is not a number at all. `to_eng` is
  named nowhere in the file: it is `uplevel #0 expr`, on strings from a raw.
  **FIXED.**

* **1342** — **the probe's own suite reddened when a third deck was added.**
  Row C5 of `test_ase_simcaps_0948` counted `.control` blocks against
  `set filetype=ascii`, and the altshow probe's deck C produces TEXT by
  construction and writes no raw. Counting `write` LINES instead is also wrong —
  deck A writes twice on purpose, and that repetition is the `appendwrite`
  measurement. C5 now splits into blocks and asks only of blocks that write a
  raw. The sibling branch's hand-off note named three suites to check and not
  this one, which belongs to the very probe it changed. **FIXED.**

* **1343** — **the RDW's raise works on Xvfb and on Xwayland and not on the
  server the user actually looks at.** Found by item R3's crew paying ruling
  DD-8. Section RA of `test_rdw_keys_1245` is ALL PASS on `:99` and **five of
  six FAIL** on `$DISPLAY` = `172.20.160.1:0` (vendor `HC-Consult`, the VcXsrv
  the batch's report came from) — proved pre-existing by re-running with R3's
  `src/rdw.tcl` replaced by `git show HEAD:src/rdw.tcl`, byte-identical reds.
  `wm state` answers `normal` where `iconic` was asked for, and even RA5 (the
  shared raise still ACTIVATES for its four other callers) fails. Issue 1340 is
  closed FIXED on a `:99` number and its own suite debt names `:0`, which is
  Xwayland — neither is the user's screen. **FILED, NOT FIXED.**

* **1344** — **the Results Display Window put the WRONG text on the clipboard,
  and wiped it.** Found by item R3's adversary, which REFUTED R3 while every
  suite was green. Four defects, all in code item R3 added: the EMPTY window's
  Select All + Copy replaced the user's clipboard with a newline (a Tk text
  widget's mandatory trailing newline makes `tag add sel 1.0 end` a real range,
  so both guards were dead); Ctrl-C copied the PANE whenever the user selected
  in this window's own status entry, because `rdw::_selection_changed` scored a
  LOCAL sibling as a foreign theft; the same chord then destroyed the text
  being copied, `rdw::status` being a write to that entry's `-textvariable`;
  and the two sentences disagreed about one and the same content. A fifth face
  found by the new row: Tk's own `bind Text <<Copy>>` runs before the toplevel
  chord and was a second door obeying none of the guards. Fixed by three pure
  predicates (`_worth_copying`, `_copy_lines`, `_in_window`), a
  `_sibling_selection` consulted between the live `sel` and the mirror, a
  `_copy_report` that will not overwrite the widget it is reporting on, and the
  chord bound on the pane itself with a `break`. **FIXED.**

* **1345** — **the Results Display Window said "(did not converge)" when its
  own formatter merely declined.** Found by item R5's adversary while all four
  suites were green. `rdw::_value_text` inferred "non-finite" from an EMPTY
  answer out of `op_annot::eng_or_blank`, which answers empty for two different
  reasons — the value really is `nan`/`inf`, or `to_eng` could not format a
  perfectly finite number. The second is reachable from a shipped menu:
  `Simulation > Set netlist / graph / annotation precision` is a free-text
  entry with no validation, and all eight of `-1 2.5 abc 4x +4 0x4 6. 6.0`
  stick and make `format %.${pr}g` raise. From then on EVERY measured value in
  the pane claimed a non-convergence — a false statement about the circuit on
  the one surface built to be pasted into a design review — while the sheet
  blanked the same row, so the two surfaces disagreed, which is what item R5
  exists to stop. Fixed by asking `op_annot::_finite`, the predicate
  `eng_or_blank` gates on itself, BEFORE choosing the words; a finite value the
  formatter declined falls back to its raw text, unformatted but true. Rows
  EN8/EN9/EN10 added, EN6 rewritten, and both `test_rdw_window_1245` and
  `test_op_param_store_1245` now state the `ev_precision` they measure at
  instead of inheriting the reader's (measured: eleven and six rows red
  respectively under a non-default one). **FIXED.**

* **1346** — **`test_rdw_keys_1245` flakes in about fourteen focus/binding rows
  under CPU load**, in sections F, B, V, D, CU and RA. Found while measuring
  issue 1332's fix under that issue's own acceptance load (a 6-way spinner plus
  a concurrent suite on the same display). Measured **interleaved** pre/post so
  it is demonstrably not 1332's doing: the same set appears in both arms in the
  same proportions. Quiet, the suite is 12/12 ALL PASS (78) on `:99`, so this is
  invisible in a normal run and indistinguishable from a real regression when
  several agents share the box. **FILED, NOT FIXED.**

* **1347** — **a key-2 (summary) reorder made the Results Display Window
  contradict the sheet, and the fence could not see it.** Found by item R2's
  adversary with all four suites green. The user asked for a reorder to be
  "reflected in the Results Display Window as well as the schematic annotation
  — if applied to annotation params (1 key) or summary list (2 key)"; for list
  2 the window followed and the sheet did not, while the status line reported a
  plain success. Structural, and older than R2: `op_param_lists::_show_set`
  filters the annotation+summary union by the ANNOTATION list's labels in union
  order, so the summary list's order can never reach `op_annot::text`. The
  fence, row RE7, golds `annot_overlay_flushes` — measured +2 while the drawn
  string was byte-identical, because `op_annot::register` bumps the epoch on any
  re-register. Fixed by `rdw::_drawn_note`, one clause on the summary reorder
  arm saying the drawn order did not move; row **RE8** added, golding the drawn
  STRING for both legs. **The E question — should list 2 reach the sheet at all
  — is the USER's**, rule debt `1347_R2_summary_order_on_the_sheet`.
  **FIXED (the false sentence); the ruling is OPEN.**

* **1348** — **a device-flavor reorder re-slotted a block of a cell the entry
  does not match.** `rdw::_reorder_shown` re-slotted every block of the edited
  CLASS rather than every block the WRITE reached, so a press whose own sentence
  read "for cells matching …/p4n.sym" moved a different cell's block, and a
  broad write over a shadowed device re-slotted the very block
  `rdw::_shadow_why` was telling the user had not changed. Fixed by
  `rdw::_write_key`, ONE builder of the store key an edit writes at, shared by
  `_edit` and `_reorder_shown`. Rows **RE9** and **RE11**. **FIXED.**

* **1349** — **Delete and Add left the RDW pane and the store disagreeing about
  order.** Up/Down maintained "the window shows the order the store holds"; the
  two buttons either side of them did not, on a stated reason about MEMBERSHIP
  ("a re-slot could neither add the new row nor remove the deleted one") that is
  true and is not about ORDER — `rdw::_reslot_block` is a strict permutation
  over the rows the run published. Fixed by calling `_reorder_shown` on that arm
  too, with the scope the dialog answered. Row **RE10**. **FIXED.**

* **1350** — **after a reorder, the NEXT dump of the same device lands in raw
  order and contradicts the blocks below it.** `rdw::push` does not re-slot, so
  the oldest dumps carry the newest order and the newest dump carries the raw
  one — which falsifies row RE5's own title. Both fixes change a decision the
  batch already took (re-slotting on push reds RE0's control with nothing
  wrong), so it is an E question: rule debt
  `1350_R2_does_a_new_dump_follow_the_store`. **FILED, NOT FIXED.**

- **1351** — four defects the repair round's own adversaries found, one number
  because they share a cause: each is a FIX's own new failure mode, invisible to
  the rows that shipped with that fix. (A) issue 1332's fix added SD5–SD7 and
  did not raise `KX_FLOOR`, leaving the guard three rows of slack over the three
  rows that fence 1332 itself; (B) `sd_poll_modal` waited on a bare
  `[grab current] ne {}`, which answers for every grab the application holds, so
  the "exact pair" its comment claims was not exact; (C) `sd_arm` overwrote its
  predecessor's timer handles instead of cancelling them, turning a one-shot
  stray timer into a self-re-arming chain that lives across rows; (D) the
  give-up was a poll count that measured 6.0–6.5 s at load average 54, past the
  5 s deadman it was documented as sitting inside; (E) `rdw::status` replaced
  the status entry's text and left the user's selection INDICES standing over
  the new sentence, so the next Ctrl-C silently copied a slice of a refusal
  message. **FIXED**, fenced by SD8, SD9, SD10 and CP16, each proved by a
  sabotage that reds exactly it.

- **1352** — `input_line`'s OK button (`src/xschem.tcl:14146-14152`) runs
  `eval $cmd \[.dialog.f1.e get\]`, so the text typed into the dialog is
  spliced into a script and parsed as Tcl rather than passed as a value.
  DRIVEN in the real widget on `:99`: typing `7 ; set ::INJECTED yes` into
  **Simulation > Set netlist / graph / annotation precision** executes the
  second command. Shared by every `input_line` caller that passes a `cmd`,
  including **Set top level netlist name**. Stock xschem code, inherited, not
  introduced by this branch. **FILED, NOT FIXED** — the one-line fix
  (`[list ...]`) would silently change behaviour for any caller that relies on
  the typed text being substituted as several arguments, so it is a survey and
  a ruling, not a patch.

- **1353** — the RDW's keys 1 and 2 now narrow CONTENT, not only identity: the
  implementing record for issue **1300**, which this closes. `format_answer`
  filters all three buckets by `::op_param_lists::effective` (reached through
  item R2's `rdw::_list_params`, so there is still ONE definition of the list),
  the ctx carries the list identity and the class from `rdw::dump_devpath`, and
  the block is re-slotted into the list's order. Measured on the user's own
  M18: 88 rows before, 6 after, key 3 unchanged at 88, and the three blocks
  pairwise different where they used to be byte-identical. **FIXED**, fenced by
  section NW of `test_rdw_window_1245.tcl` (10 rows, both arms, `RW_FLOOR`
  134 -> 144) and section KN of `test_rdw_keys_1245.tcl` (2 rows, `KX_FLOOR`
  81 -> 83), every one proved by a sabotage. It carries **four decisions taken
  on the user's behalf** — hide the undeclared rows and say so, a sentence for
  an empty list, a past-tense list label inside the block, and the list's order
  over the raw file's — and **one residual it does not fix**: an unowned summary
  list answers the PDK seed, so keys 1 and 2 still show the same ROWS on a
  machine with no settings-file entries. Rule debt **1353**.

- **1354** — the ASE log says "468 device OP save card(s) added to the deck" and
  prints the shape-`c` nudge for a deck that carries **zero** `.save @dev[param]`
  cards. The count comes from `ase::op_cards_capture` (`src/ase.tcl:4506`, called
  `:4562`) reading the captured block, while the SHAPE is chosen separately by
  `ase::op_save_tier` (`:4792`, `:8050`); under tier `d` both sentences describe
  a deck that was not rendered. Measured in the user's own log and deck. It is
  what sent the RDW list batch's brief at the wrong hypothesis. **FIXED**
  (2026-09-05), both halves, and they failed differently. THE SENTENCE:
  `ase::op_tier_report` already asked `ase::op_save_tier`, got `d`, and threw
  the answer away — its `switch` had arms for `a` and `b` only, so `d` fell
  through to `op_tier_perdevice` and then past all five of that sentence's
  reason tails onto the catch-all, telling the user their simulator *cannot* do
  a shorter way about the build given the shortest one **because it can**. A
  fifth kind `op_tier_dump` is minted in `ase::sim_why` (ruling D5-4) and
  selected by a new `d` arm. THE COUNT: `op_cards_capture` runs at NETLIST time
  and **must not** learn the shape — `ase::op_save_tier` goes through
  `ase::sim_capabilities`, which on a cache MISS starts the user's simulator,
  and `Simulation > Netlist > Recreate` is a netlist gesture with no run behind
  it — so the line stops claiming the deck and reports what the walk built,
  cards **and devices**, because on shape `d` a card count is a category error
  and the device count is the number that survives. Fenced by **N1..N6** of
  `tests/headless/test_op_dump_altshow.tcl` (new section N; N2 the declared
  control) and by adding `op_tier_dump` to `TIERKINDS` in
  `test_ase_optier_0963.tcl`, which puts it under **S2** and **S4**; five
  sabotages, each red on exactly its own rows. `F19k`/`F19l` of
  `test_ase_final.tcl` re-spelled in the same commit. **Neither suite carries a
  FLOOR constant**, so no floor was raised — `KX_FLOOR`/`RW_FLOOR` belong to the
  RDW suites and no RDW row changed. Carries **one decision left to the user**:
  what the netlist line should count — rule debt **1354**.

- **1355** — the Results window never says which list is in force, and the scope
  dialog names no list on lists 1 and 2. The user's SECOND complaint. MEASURED
  at HEAD `d81b4b24`, after the narrowing: the title was `Results Display
  Window` on all three identities, the status line was empty on the whole dump
  path, `.rdw` had three children and none named a list, and the real scope
  dialog was BYTE-IDENTICAL on annotation and on summary with no `.q2` at all.
  So the only on-screen difference between lists 1 and 2 was the Add button's
  grey — the user's own clue, and true evidence for "not list 3" and none at all
  for "I am on summary". **FIXED**: one name/gloss builder read by four
  surfaces, a chrome `::label` `.rdw.hdr` above the pane, the list in the `wm
  title`, and `.rdw.scope.q2` as a STATEMENT on lists 1 and 2 in the slot list 3
  uses for its question — all refreshed by the ONE proc `rdw::set_list` calls
  (`rdw::apply_button_states` renamed `rdw::apply_list_state`). Fenced by
  section **LX** and row **BT31** of `test_rdw_window_1245.tcl` (`RW_FLOOR`
  144 -> 152) and section **LK** of `test_rdw_keys_1245.tcl` (`KX_FLOOR`
  83 -> 85), every row proved by a sabotage. Carries **four decisions taken on
  the user's behalf** — the wording of five sentences, the title as a second
  surface, "Keys 1/2/3 chose" as a claim about identity, and naming the TARGET
  list rather than the identity in force. Rule debt **1355**.

- **1356** — the Results window's buttons act on the CURSOR row, and a mouse
  selection of six rows is not a six-row edit. MEASURED on the user's own
  gesture: `tag ranges sel` = `8.4 13.4` (six rows) with `::rdw::targetrow` = 8,
  and one press produced one verdict about one parameter. Every reader of the
  text selection in `src/rdw.tcl` is on the CLIPBOARD path; none is on the edit
  path. **The SILENCE is FIXED** — `rdw::_selection_note` appends one clause to
  every verdict, and only when a selection really spans two or more lines (rows
  BT31 and LX11). **The FEATURE is a ruling and is NOT built**: one dialog for N
  rows, one status line for N outcomes, and ruling DD-10's last-row rule
  evaluated over a batch rather than per row. Proposed answer: keep it one row
  and keep saying so. Rule debt **1356**.

- **1357** — Add pressed on the SUMMARY list writes the ANNOTATION list.
  MEASURED on the user's own M18: `Add: gm is already in the mos annotation
  list`, from a press made on the summary list with a dialog that named no list.
  **It is spec §4.2 B7's own Add cell and the behaviour is UNCHANGED**; issue
  1355 gave the answer one builder (`rdw::_edit_list`, read by three consumers)
  and made the dialog say it out loud. **FILED, NOT FIXED** — whether a
  summary-list Add should target the summary list is the user's call, since it
  is their spec and their expectation that disagree. Rule debt **1357**.

- **1358** — the Results Display Window cannot hear its own refresh keys, so an
  edit that landed could not be looked at. The user's third symptom, and the
  delete was never the problem. MEASURED with no `focus -force` anywhere: press
  2, click the parameter row the status line INSTRUCTS you to click, press
  Delete and accept the defaults — `op_param_lists::effective` really moves and
  the status line really says so — then press 2 and **nothing happens**, 3/3.
  The digits are bound on the CANVAS only (`src/cadence_style_rc:181-184`);
  `.rdw`, `.rdw.p`, `.rdw.p.t`, the Text class and `all` all answered the empty
  string, so Tk delivered the key to the focus widget and found nothing — no
  block, no error, no status line. **PRE-EXISTING** (`rdw::button` calls neither
  `rdw::_focus_canvas` nor `rdw::_arm_focus_handback` at HEAD or at 79b0a0ce);
  it became reachable when the buttons became worth pressing. **FIXED**: the
  four bare digits are bound on the TOPLEVEL tag, the tag this file already
  chose for `<Key-Escape>` (issue 1308, ruling DD-12) and for the copy chord
  (issue 1339, ruling DD-5), with `cadence_style_rc`'s own 0x4c modifier mask
  and one shared map, `rdw::_digit_map`. **REJECTED**: handing the keyboard back
  from `rdw::button` — it fixes only the button gesture (a click then a bare 2
  is still swallowed) and re-creates DD-5's defect on the seven refusal arms
  that repaint nothing. Fenced by section **KB** of `test_rdw_window_1245.tcl`
  (`RW_FLOOR` 152 -> 154) and section **KD** of `test_rdw_keys_1245.tcl`
  (`KX_FLOOR` 85 -> 87), each row proved by a sabotage that reds exactly it.
  Carries **two decisions taken on the user's behalf** — the window does NOT
  refresh itself after an edit, and key 4 is bound in the window too. Rule debt
  **1358**.

- **1359** — `tests/run_regression.tcl:217` launches every DISPLAY-ARM case
  with no `--logdir`, so a solo T1 run — the acceptance signal CLAUDE.md itself
  mandates — overwrites the user's `/tmp/Xschem.log.*`. MEASURED by md5 before
  and after one run on 2026-09-05: five of nine files destroyed (`.1 .3 .4 .8
  .9`), `.5` — the log the whole RDW batch was diagnosed from — survived. The
  `--nogui` arms (`:176`, `:238`) are safe; a headless run without `--logdir`
  writes no log at all. **FILED, NOT FIXED**: the fix is one argument, but the
  display-arm list may contain a suite whose own subject is the log's default
  placement, so it needs its own verification pass rather than a drive-by.

- **1360** — the RDW's narrowing sentence (issue 1353) said three things that
  were not true about the user's own data, and the store's device-flavor scope
  had no coverage at all. (a) A block narrowed by a device-FLAVOR entry was
  captioned with the CLASS list's name, self-mixing a name from one entry with a
  count from the other — driven to a false sentence on their own M18 in two
  gestures from their reported workflow. (b) `rdw::_narrow_line`'s empty-list
  arm returned before the withheld-non-convergence clause was built, so the one
  case where every row is withheld was the one case that never said a withheld
  row failed to converge — and row NW4 golded the omission. (c) The number was a
  ROW count across ruling D-3's primitives printed as "columns", one line under
  the DD-1 line that uses the word correctly. (d) Passing `{}` for the cellname
  — silently disabling every per-cell list — left window 155, keys 83 and store
  130 all green. **FIXED**: `rdw::_narrowed_list` names the entry that answered
  in `rdw::_edit`'s own words, `rdw::_narrow_spec` carries `rdw::_scope_for`'s
  answer, the clause is built before the branch, and the three counts are over
  DISTINCT columns (the filter is still per row, so D-3's attribution is
  untouched). Fenced by **NW11 NW12 NW13** of `test_rdw_window_1245.tcl`
  (`RW_FLOOR` 154 -> 162, with 1361), each proved by a sabotage that reds
  exactly it.

- **1361** — the RDW's chrome line (issue 1355) said three things that were not
  true, and two of its own stated properties were fenced by nothing. (a) "Keys
  1/2/3:" — `src/xschem.tcl:17638` adds the Tools entry UNCONDITIONALLY while
  the binds live in `src/cadence_style_rc` alone, so the line was false on every
  open outside the cadence profile. (b) "only Add works here" — `button_state`
  returns `normal` for `save` on every kind and a real press wrote a 1627-byte
  `op_param_lists.conf`; nothing in the tree tested Save's success arm at all.
  (c) "the buttons edit this list" on summary — `_edit_list add summary` answers
  `annotation`, which LX2 and LX3 gold three rows from the literal LX4 golded.
  (d) `_selection_note`'s `< 2` boundary: `< 1` kept both suites green while
  lecturing every one-row select-to-copy. (e) `rdw::build`'s two `listkind`
  reads were dead code whose comment named a fence that does not fence.
  **FIXED**: `rdw::_keys_bound` asks the canvas's own binds and
  `rdw::_chrome_text` takes the answer as an argument; `rdw::_active_buttons` /
  `rdw::_active_phrase` are the one answer to "which buttons work here";
  `rdw::_chrome_add_note` derives the Add exception from `_edit_list`;
  `rdw::_selection_note_for` is the pure boundary; build's two setters are
  deleted. Fenced by **LX12..LX16** of `test_rdw_window_1245.tcl` and **LK3** of
  `test_rdw_keys_1245.tcl` (`KX_FLOOR` 87 -> 88). Carries **one decision left to
  the user**: the longer summary sentence grows the window 893 -> 971 px on list
  2 only, so it resizes as the identity changes — look debt
  `rdw_1361_chrome_width_measured`.

- **1362** — the RDW's status line silently amputated its own sentences, and
  the half it took was the answer. `.rdw.s.msg` was a one-line `entry` 887 px
  wide at the window's own default 893x498, `-xscrollcommand` empty and no
  scrollbar; issue 1356's Delete verdict is 147 characters / 1045 px, so `xview`
  parked at 0.0-0.85 and the reader got "... the buttons act on" with " the
  shaded row alone." off the edge — the clause minted to answer the user's
  confusion, cut exactly where it answers it. Measured independently by
  adversaries B1 and B2 and by the completeness critic. **NOT ONE STRING**:
  three more shipped sentences overflowed the same field (158, 128 and 191
  characters) and three of `rdw::status`'s 34 call sites interpolate an
  unbounded path. **FIXED** by changing the SURFACE, not the wording: a
  wrapping read-only `text` that takes the lines its message needs, borrowed
  from the pane and given back, with `rdw::status_max_lines` as the named cap
  and `rdw::_status_cut_mark` marking any cut past it — `cadence::_annot_fit`'s
  own decision (issue 0639) one surface over. `::rdw::statusmsg` still holds
  every sentence whole. **No pixel constant anywhere**: `rdw::_status_show`
  asks the live widget `count -displaylines`, so it is right on whatever font
  the user's server resolves. `<Configure>` re-fits on resize and
  `<<Selection>>` refuses the text widget's mandatory trailing newline (caught
  by pre-existing row CP14). Fenced by **SL1..SL8** of
  `test_rdw_window_1245.tcl` (`RW_FLOOR` 162 -> 165), all eight red on the
  pre-fix source, each proved by a sabotage. Rows CP14/CP16 of
  `test_rdw_keys_1245.tcl` re-spelled for the new class, names and expectations
  unmoved, `KX_FLOOR` unchanged at 88. Carries **the pixel half unpaid**: look
  debt `rdw_1362_status_wrap` and rule debt **1362** (the cap, and letting the
  window's height follow the verdict).
  ⚠ **SUPERSEDED IN PART BY 1365.** `rdw::_status_cut_mark` and the elision it
  marked are GONE. The sentence above — "`::rdw::statusmsg` still holds every
  sentence whole", offered as the reason a painter may shorten what it draws —
  was **measured false as an argument**: `rdw::copy` hands over the X PRIMARY
  selection, which is what the WIDGET holds, so an elided widget was an elided
  clipboard (issue 1344's defect, returning). The surface change stands; the
  cap is now a cap on HEIGHT and the tail scrolls. See **1365**.

- **1363** — shape `d` went live and left **two ASE suites standing red**, and
  nobody filed it. Measured at HEAD `fa0eb0b0`: `test_ase_core` 10 FAILED (172),
  `test_ase_final` 6 FAILED (74). Attributed rather than guessed — a wrapper
  pinning `ase::op_tier_force_set c` and sourcing the suite gives 4 FAILED (178)
  and **ALL PASS (80)** respectively, so all six of `test_ase_final`'s reds and
  six of `test_ase_core`'s ten are the deck-shape change. Most are shape-`c`
  expectations (`C5b`, `C6`×3, `C8`, `F12`, `F14`×2, `F21`) that assert
  per-device `.save` cards in a deck row `D1` of `test_op_dump_altshow`
  deliberately asserts has none. **`F16`/`F17` are not**: five of six annotation
  rows come back BLANK on a real run in that suite, which is issue 0617's own
  failure mode and needs measuring before it is dismissed as a stale
  expectation. Neither suite is in `tests/run_regression.tcl`, so **T1 stays at
  zero while both are red**; both are in `full_audit.sh`. **FILED, NOT FIXED.**

- **1364** — the blanket operating-point dump reached ONE door, and the door the
  user's own annotation path uses was the other one. Issue 1333 wired
  `op_annot::opdump_merge` into `op_annot::db_attach` under a comment claiming
  "db_attach is the ONE place that puts an operating point onto a window";
  **that sentence was false and its falseness was the defect**. `xschem
  annotate_op` — the general-purpose verb behind 61 committed schematics'
  `tclcommand=` launcher buttons, both `Annotate Operating Point into schematic`
  menu items, `Waves > Op Annotate`, the raw carried into a new window by
  `open_sub_schematic` / `hi_descend`, `results::select` and the cadence Alt-6
  rungs — never merged. MEASURED on the user's own registry (`tier d reason
  dump`): `xschem annotate_op <raw> 0 op` then `op_annot::text M1` rendered `id`
  and left `gm gds vgs vth vds` BLANK, i.e. **issue 0617 restored**; the one row
  that appeared is `.options savecurrents` putting `i(@dev[id])` in the raw with
  no card present. **FIXED** by one call in the tree's own choke point: a static
  `op_annot_autofill()` in `src/save.c` calls `op_annot::opdump_autofill` from
  inside `update_op()`, below its three refusals and above its publish, so every
  one of the five C callers is covered; `db_attach`'s own now-redundant call is
  removed. The new door refuses a transient and a multi-point sweep by name
  (RULING D5-1, issue 0862), keeps issue 0838's stale rule and issue 0975's
  silence, and is latched against re-entry twice. Fenced by **W8..W15** of
  `test_op_dump_altshow.tcl` (three RED on the unmodified source, five proved by
  a sabotage that reds exactly them). `test_ase_final.tcl` is now **shape-aware**
  (`F11`/`F12`/`F14`/`F21` ask `ase::op_save_tier`; `F16`/`F17` unchanged), so it
  reads **ALL PASS (81)** under the user's real registry AND under a HOME with
  none, where before it read 6 FAILED (74) / ALL PASS (80) on the same commit.

- **1365** — the Results window's status surface handed over **its own elided
  picture** of a sentence. Issue 1362 replaced the one-line `entry` with a
  wrapping `text` capped at four display lines and, past the cap, elided at a
  word boundary with a `...` marker — staking itself on "`::rdw::statusmsg`
  still holds every sentence WHOLE ... the painter may shorten what it DRAWS
  and never what it HOLDS". **The second half of that sentence is false about
  this window.** `rdw::copy`'s sibling leg is `rdw::_sibling_selection` ->
  `selection get PRIMARY`, i.e. what the WIDGET holds; the model is never
  consulted there and cannot be, because the user selected a RANGE. MEASURED on
  a 618-character composed verdict at 893x498: pre-1362 the clipboard came back
  **618** characters ending `the shaded row alone.`, at `fa0eb0b0` it came back
  **474** ending in a literal `...` — **issue 1344's defect returning through
  the door 1344 was fixed for**, in the window whose purpose is select-and-paste.
  Two more, same root: `rdw::_status_show` put the FULL model on the surface
  before measuring, so on a capped message `_status_put`'s no-repaint guard
  could never fire and **three pixels** of resize destroyed a standing selection
  (the pre-1362 entry survived it); and the cliff merely MOVED, from 122
  characters to **492**, against real composed verdicts of 618–778 — so a
  shipped verdict was still amputated at the window's default size. Row SL8
  could not see the first (its message never reaches the cap) and SL4/SL5/SL6
  could not see the second (260 / 147 characters of filler, and a 4000-character
  row that asserts only that the cut is MARKED). **FIXED** by removing the
  elision rather than patching it: the cap is a cap on the surface's HEIGHT, the
  widget holds every character of the model at every length, and a scrollbar
  appears when the sentence needs more lines than the surface has — an
  affordance that is operable, where `...` was one that was not. All three close
  by construction. Fenced by **SL9** (the clipboard IS the sentence, past the
  cap), **SL10** (a selection survives a resize on a capped verdict, with a
  control inside the cap), **SL11** (a verdict composed the way `rdw::button`
  composes one — `rdw::_edit` + `_sheet_note` + `_shadow_why` + `_selection_note`
  — MEASURED at **676 characters / 7 display lines** with real punctuation and a
  real path, read and copied whole) and **SL12** (the scrollbar's pure decision
  at its boundary); **SL3** and **SL6** are re-spelled, since the elision they
  golded is gone. `RW_FLOOR` 165 -> 166 in-commit; `KX_FLOOR` unchanged at 88.
  Seven sabotages, each row red where another is green.

- **1366** — **one run asked which shape it was using THREE times and pinned the
  three answers to nothing.** `ase::run_deck` called `ase::op_save_tier` once for
  the SENTENCE (`ase::op_tier_report`), once for the DECK (`render_deck`'s shape
  switch) and once for the RUN RECORD (`meta optier`) — and that function is
  **deliberately not constant**: `ase::sim_capabilities` never remembers a
  `known 0` answer (issue 0950, `src/ase.tcl:1863`) and `ase::cap_stale`
  re-measures on any change to the resolved binary's stamp, so **one** probe
  timeout or **one** mtime change between two of those calls makes them differ.
  Commit `6a55d626`'s adversary drove both directions; MEASURED again here with
  the decision replaced by a scripted stand-in: `flap {d c d}` gave
  `calls=3 said=op_tier_dump deck=c record=d` — the run telling the user the
  fast path worked when the deck on disk did not take it. **And a third sentence
  went false in the same run**: with the record on `d` over a shape-`c` deck,
  `ase::op_report_missing` took its dump branch, found no sidecar (correctly — a
  shape-`c` deck writes none) and told the user to **"Rename the run folder in
  lower case with no spaces"** for a folder already all lower case with no
  spaces, over a run that worked — issue **0975**'s rule broken by another
  route. `run_deck`'s own comment claimed the record was "computed under
  render_deck's own two gates so the two cannot disagree"; the *gates* were the
  same, the *measurement* was not. **FIXED** by an ordering and threading change,
  not a new policy: `ase::run_deck` **arms a pin** (`ase::op_tier_arm` /
  `op_tier_disarm` / `op_tier_pin_state` / `op_tier_now`), the first of the three
  consumers decides, and the other two are handed the same answer — so the
  renderer is **bound** rather than asked first, and the deck on disk stays the
  ground truth *and* now equals what was said and recorded. The pin's lifetime
  **begins** at the arm, immediately above the first consumer, and **ends** as
  soon as the record is taken, plus on the one statement between them that can
  raise (the render, re-raised unchanged); `op_tier_report` moved below the cosim
  block so `ase::cosim_build`'s raise cannot escape the armed span. **With
  nothing armed `op_tier_now` IS `op_save_tier`, call for call**, so every suite
  that drives the decision or the hook directly is untouched, and a **re-run
  after the user registers a different simulator re-measures** (row `Z6`, driven
  through the real capability store). Two smaller pre-existing defects taken in
  the same pass: a registered simulator whose file is gone left `resolved` empty
  and the run said *"…anything about what&nbsp;&nbsp;can do"* — no name, double
  space — now `ase::sim_named_path` falls back `resolved` → `exe` → backend name
  (`Z8`); and row `N6` of `test_op_dump_altshow.tcl` asserted only that a
  standalone `3` and a standalone `2` appeared *somewhere* in the netlist-time
  echo, so the two counts printed **swapped** passed it — re-spelled to anchor
  each number to its own clause, with the swap asserted absent (SAB7: old
  spelling `{1 1}` = pass on the swapped line, new spelling reds). Fenced by
  **Z1–Z8** of `tests/headless/test_ase_optier_0963.tcl`, **all eight RED on the
  unmodified source** (`RESULT: 8 FAILED (94 passed)`, red set exactly
  `Z1..Z8`), and nine sabotages. Neither suite carries a check-count floor, so
  none was raised.

- **1367** — the Results window's chrome said `Showing <list>` over a pane
  holding one character and zero blocks (measured in a stock profile through
  the unconditional Tools entry), i.e. issue 1355 fixed a false statement about
  the KEYS by minting one about the PANE; and `rdw::_keys_bound` still asked
  the canvas alone after issue 1358 had bound the same digits on the window, so
  a stock profile answered "no keys" while the keys worked. **FIXED**: the
  chrome asks whether the pane is filled and says what is true of each of the
  four states, naming the digit out of `rdw::_digit_map`; `_keys_bound` asks
  both widgets and knows both spellings of the one door. Rows LX17, LX18, LK3
  rewritten, LX7/LX12/LX13 re-pointed, RW_FLOOR 166 -> 168.

- **1368** — the Results Display Window had no text-size control at all, and the
  two one-liners that look like they would add one are both defects: `.rdw.p.t`
  was `-font TkFixedFont`, the SHARED named font that is every bare `text`
  widget's default in this tree (measured), so `font configure TkFixedFont -size
  N` is a global font control wearing a window-local label — it moves the
  attribute editor, the symbol-property editor, the text-input dialog,
  editpaths, the graph dialog, the notify popup and the calculator buffer in the
  same click; and the `hdr` tag was `font actual TkFixedFont`, a font
  DESCRIPTION and not a NAME, so it was a frozen snapshot (measured: pane
  linespace 27 against a header still at 17). **FIXED** by the user's own `aA`
  button — plain click +1 unit, Ctrl+click -1, hover tooltip carrying their
  verbatim sentence through the tree's ONE tooltip mechanism (`balloon`) — over
  two PRIVATE named fonts (`RdwPaneFont`, `RdwHdrFont`) and a model that is
  always the integer, never a size read back out of a font (measured: a `-14`
  PIXEL spelling reads back as `10` POINTS). The pane's `-width`/`-height` are
  recomputed from the new metrics in the same setter, because the pane is sized
  in CHARACTER units and one unmitigated step to size 20 took the window from
  893x498+1025+557 to 1757x914+161+141. Two smaller things taken in the same
  pass: `set_ne rdw_font_size 0` in `xschem.tcl` gives the rc door, and
  `balloon_show` now pulls an off-screen tip back on to the screen — measured on
  this very button, whose 564 px tip wanted to end at 2379 on a 1920 px display,
  with a tip that already fits left exactly where it was. Fenced by section
  **FZ** of `tests/headless/test_rdw_window_1245.tcl`, ten sabotages, `RW_FLOOR`
  168 -> 172. Three decisions are the USER's and are on the owed ledger as a
  rule debt.
  **REFUTED AFTER LANDING, AND REPAIRED IN THE SAME BRANCH.** Three real defects
  and one false sentence: (1) the Ctrl arm's `break` also stopped the `.rdw`
  bindtag, so a Ctrl+click was the ONE gesture in the window that did not spend
  issue 1369's focus one-shot and left the keyboard on the schematic canvas
  where the plain arm leaves it in the window (measured `focus_pending` 1 vs 0);
  (2) `rdw::_font` imposed a size only WHILE one was chosen and could never put
  one back, so a withdrawn choice left the model at 10 with the pane at 20 and
  the next `+` click SHRANK the text 20 -> 11, and the same hole under
  `_base_size`'s clamp rendered 40 while refusing at "already the largest (32)";
  (3) the new clamp in the SHARED `balloon_show` slid pointer-anchored (`pos 0`)
  tips UNDER the pointer, where `balloon`'s own `<Leave>` destroys them — the
  file browser's two directory tooltips (`xschem.tcl:9659`, `:9674`) never
  appeared at all and re-armed every 3 s whenever the pointer sat in the
  rightmost ~555 px (measured 16 shows, visible 0/40); and (4) the write-up's
  "none of the tree's other 43 call sites changes placement" was false — a tip
  that does not fit IS moved, which is the point. Repaired with
  `rdw::_shared_size`, `rdw::_ref_font`, an explicit `rdw::_focus_click %W` on
  the Ctrl arm, and a pointer-mirroring `pos 0` rule; **seven new rows FZ12..FZ18
  plus re-spelt FZ7/FZ8, twenty sabotages, `RW_FLOOR` 172 -> 186**. Five
  surfaces that had no witness at all (the `aA` label, `_base_size` reading
  TkFixedFont, the monospace requirement, `balloon_show`'s vertical flip and two
  zero clamps, the 300 ms delay) are now fenced.

- **1369** — the Results Display Window's raise KEPT the keyboard after one
  click anywhere in the window, so the user's next canvas click was spent
  re-activating the schematic and sent no dump ("another click to look at
  another device's OP info does not have intended effect - it just focuses the
  schematic window and doesn't send the OP info for that device to RDW"). The
  machinery was all there and its DECISION was wrong: `rdw::_focus_handback`
  compared the landing against the EXACT toplevel (`[focus] ne {.rdw}`), and Tk
  keeps a focus record PER TOPLEVEL — once any child has held the Tk focus,
  every later grant is resolved by Tk to that CHILD, so the equality was never
  true again, the one-shot stayed armed for ever and the window kept the
  keyboard after every dump. ONE ordinary gesture writes that record and it is
  the one the Add/Delete buttons ask for: `tk::TextButton1` calls `focus $w`
  UNCONDITIONALLY (`text.tcl:579`), unlike `tk::EntryButton1`, which skips a
  `disabled` widget (`entry.tcl:356`) — so a click in `.rdw.p.t` or in the
  `-takefocus 0` status surface `.rdw.s.msg` is enough, and `rdw.tcl`'s own
  comment asserted the opposite, which is why the hole was invisible.
  **FIXED** by asking `winfo toplevel` of the landing (not an equality, and not
  the `string match .rdw*` glob issue 1306 already refuted), plus a new
  `rdw::_focus_click` bound to `<ButtonPress>` on `.rdw`, which spends the
  one-shot when the user comes here on purpose — because a landing test that
  can see the whole window can no longer tell that click from the grant.
  BOTH EVENT ORDERS MEASURED, the second through XTEST so a real click-to-focus
  WM's passive grab is involved: on Tk's own path the press runs before the
  queued FocusIn (the disarm wins), on a real WM the FocusIn arrives FIRST and
  the click still wins because `tk::TextButton1`'s own `focus $w` takes the
  keyboard straight back. Fenced by rows **F5** and **F6** of
  `tests/headless/test_rdw_keys_1245.tcl` (`KX_FLOOR` 88 -> 90) and row **K18**
  of `tests/headless/test_rdw_window_1245.tcl` (`RW_FLOOR` 172 -> 173), with
  F3/F4/KD1 the fence over the disarm and three sabotages naming their red sets.
  Whether the raise should keep the WSLg re-map idiom on the user's own
  (HC-Consult, no EWMH WM) server is a USER ruling on the owed ledger (`--eyes`).

- **1370** — the ASE-L bottom bar's `Simulator:` segment named the **backend**,
  never the simulator the user registered and picked. `ase::ui::refresh_status`
  rendered `[ase::state_get $st simulator]` — the schema default `ngspice` set
  once in `ase::state_default` and never touched by the registry — so the
  segment carried zero registry information: measured on a live `.ase4` window
  with the user's own HOME, `Simulator: ngspice` with `ngspice-ver50` in force,
  with the choice cleared, and with it re-selected, three registry states and
  one byte-identical bar. Issue **0931** named this in its own problem statement
  and shipped without it; **0937** then wrote the exclusion down as a decision
  ("deliberately out of this item's scope"), which the user has now overturned
  directly — 0937's bullet is amended in place. **FIXED** by a new
  `ase::sim_label` in `ase.tcl` (the registered `entry`, never `sim_use`, so the
  ghost arm can never put a name on the bar for a simulator nobody registered;
  and a three-term "will it run" test — `ok` AND a non-empty `resolved` AND a
  backend `ase::backend_names` knows — because `ok` alone never validates on the
  PATH arm: measured `ok 1` with `resolved` EMPTY on an empty PATH), plus
  `ase::ui::refresh_status_all` called from the last line of
  `ase::ui::simdlg_fill`, the one proc all five registry gestures funnel
  through, so every open session window's bar follows a gesture made in any of
  them. The log half of the same complaint: a new `run_using` mint kind said
  once per run from `ase::run_deck` via `ase::run_using_report` (NOT from
  `run_precheck`, whose silence on a healthy resolve is pinned by `CS187b` /
  `CS180b` of `test_sim_run_profile.tcl` — a correction to this item's own
  plan), and a `using :` field ADDED to the run-log header beside
  `simulator :`, never re-pointing it, because row `E1e` of `test_ase_core.tcl`
  asserts the literal `ngspice` there and runs under the developer's own HOME.
  Fenced by section **L** (L0..L11) of
  `tests/headless/test_ase_simreg_0931.tcl` and rows **S20..S23** of
  `tests/headless/test_ase_simdlg_0937.tcl`; neither carries a check-count
  floor, so none was raised. The marker's WORDING is a user ruling on the owed
  ledger (`--eyes`); no suite retypes it.
  **REFUTED AFTER LANDING, THEN REPAIRED** (2026-09-06). Three adversaries;
  six real findings, four rejected with the measurement. (1) The say was called
  ABOVE `ase::preflight_gate`, so a refused run said "This run is starting …"
  and was then refused with "Nothing was generated" — moved below the gate and
  below the line composing the command. (2) `Q6` and `S11` of
  `test_ase_optier_0963.tcl` were RED because of this item — Q6 bans the code
  words `optier`/`tier` in anything a run says and the new sentence quotes the
  fixture's own entry NAME; both are TEST-ROW repairs, Q6 now lifting the user's
  substitutions out before the ban scan (row `L8`'s own discipline) and S11
  dropping a named list of foreign kinds, both proven still-toothed by sabotage.
  (3) The three-term test became FOUR — `ase::run_composes_registry` — closing a
  latent false name (a generic entry plus a backend with its own hardcoded
  `run_cmd`). (4) The bar went stale on the registry's OTHER door
  (`ase::sim_register`/`sim_select` from the Command window, the pre-0937 path
  and how this user's own entry was created): new single-slot `ase::sim_notify`
  seam fired by all four mutators, pointed at `refresh_status_all`. (5) A label
  with no name printed the marker after a double space — now `(none)`.
  (6) `L9`/`L10`'s literal call-text pins loosened to shape matches. Rows
  **L12..L15** and **S32** added; simreg 79 -> **83**, simdlg 40 -> **41**.
  The "hangs at N3" claim in the first write-up is half wrong: the optier suite
  DOES stall (inside `N4`'s `xschem load` of the bandgap, 4/4 reproduced,
  0% CPU on a futex) but `Q6` and `S11` print inside 40 s and were always
  measurable. Two more user rulings recorded: `1370_none_word` and
  `1370_ase_prefix`.

* **1371** — *a measured case-mode capability has no GUI door.* The user:
  "If the run *is* using ver_50, then why is case-mode support not showing up?
  … I plot the VBG net … and it plots v(vbg) not v(VBG). What's going on? I
  thought we nailed this weeks ago." Measured on their own bench: their build IS
  in force and WAS measured — `casemode_detected` and `casemode_selectable` both
  `fold preserve distinguish` — but their registry entry carried `casemode {}`,
  so the request fell to the global floor `fold`, and a `fold` request
  deliberately emits no `-D casemode=`. **The only broken link was that nothing
  could ask:** `ase::ui::simdlg_editor` built exactly two rows, `Name:` and
  `Program:`. `fluid-editing`'s casemode item 13 HAD that door (Exe / Args /
  Case / -n / Test); it was deleted at the annotate merge on the promise that
  Setup > Simulators… is now their one door — **the store moved and the door was
  never built**, and the stale `simconf` Help text went on documenting the
  removed controls. Worse, `ase::ui::simdlg_ok` rebuilt the entry from `args`
  and `backend` alone, so pressing Edit… and OK on a hand-edited entry ERASED
  `casemode` and `nospiceinit` and saved the erasure, while its own comment
  claimed the opposite and row S9 asserted that claim for two fields only.
  **FIXED** by `Case:` and `-n:` rows in that editor, built from cached
  measurements ONLY (`ase::sim_caps_have_path`, a peek) with an explicit
  `Detect` as the sole control that may launch anything — 447 ms cold on their
  build, 0 ms warm, **31.2 s** on a program that never answers, Tk frozen
  throughout, and a licensed tool would check out a licence. New model half:
  `ase::sim_entry`, `ase::sim_capabilities` split into a path-keyed core plus
  `_at`/`_path`/`_for`, the peeks `sim_caps_have{,_path}`, the A1 rule written
  once against a capability dict (`casemode_{detected,selectable}_in`,
  `casemode_report`), `sim_casemode_selectable_{path,for}` and
  `sim_casemode_floor`, and three new `sim_why` kinds. The entry-keyed
  accessors are load-bearing, not tidiness: measured, the in-force accessor
  answered about whichever row was SELECTED, so a chooser built from it offers
  one program's modes while the user edits another's. Fenced by rows **S9**
  (extended) and **S24..S31** of `tests/headless/test_ase_simdlg_0937.tcl`
  (32 → 40 checks; no floor, so none was raised), each proved non-vacuous by
  six separate sabotages. The ruling *may opening Edit… launch the user's
  simulator* is on the owed ledger. Adjacent and deliberately NOT swept in: the
  global floor `sim_case_mode` has no GUI door either (`set_ne`, rc-only).
  **REFUTED AFTER LANDING, AND REPAIRED IN PLACE (2026-09-06).** The single
  named "correction" — keying the chooser on the program in the FIELD — was
  fenced by nothing and did not do what it claimed: the offer was BUILT only at
  editor-open and by Detect, so retyping the Program field (or `Browse…`) left
  the previous program's modes on offer and OK saved one, emitting
  `-D casemode=preserve` for a build measured to deliver `fold` alone. Also
  measured: `ase::casemode_report` said "has not been tried yet … press Detect
  to try it" **after Detect** in every state but the happy one (a program that
  answered with no casemode key, a file that has gone, no probe hook, an empty
  Program field); the mark `(NOT measured)` was a false statement about a
  measurement taken 449 ms earlier; `casemode_measuring` was asserted by no test
  in the tree; and the capability cache, keyed on the path alone while the probe
  runs the entry's own argv, let one dialog-side Detect answer for the run
  (proved: an in-force `-args -q` entry that really folds answering
  `fold preserve distinguish`). Repaired with `ase::cap_key` (path AND argv),
  `ase::casemode_status`, an arm per state in `casemode_report`, six more
  `sim_why` kinds, two mark words, and the Program field's own `-validate`.
  Rows **S33..S39** (41 → 48 on `:99`, 4 → 5 on `--nogui`), nine sabotages red
  by name, including the adversary's own three, and two of the first pass's own
  sabotages re-run to prove the refactor left no existing fence vacuous. A second ruling is on the ledger
  (`1371_marked_mode_is_saved`) and the three pixel questions moved from the
  self-clearing `suite` debt to a `look`.

* **1372** — *an Add from list 3 into the summary list never showed up on key 2.*
  The user: "I put cursor on cgs and the clicked Add button and said add to all
  mos … for summary list, but, later, when I send summary list with 2 key, it
  never shows up." Reproduced end to end on their own `M18:/x1/x1` under
  `tb_bandgap` with the `ngspice-ver50` registry live. **Nothing downstream
  dropped it — nothing was ever written.** `rdw::_find_triple` (src/rdw.tcl) was
  the ONLY source of the `{label param kind}` triple an Add inserts and looked in
  exactly three places (`effective <cls> annotation`, `effective <cls> summary`,
  `seed <cls>`), all three of which answered the SAME six sky130 rows because
  `~/.xschem/op_param_lists.conf` owns no rows at all; `cgs` is not among the six,
  so the Add returned `refused` and the store was byte-identical before and after
  the press. Three aggravating facts, all measured: **SCALE** — list 3 offers 88
  rows for M18 and Add was accepted for **0** of them, 82 "no declaration" and 6
  "already in the list", on BOTH target lists; **ORDER** — `rdw::button` raised
  `rdw::scope_dialog` BEFORE it computed the refusal, so the user answered a
  two-part modal question and was then told once, into a four-line status pane,
  that it was impossible, which is why the report reads "it never shows up";
  **THE REFUSAL'S STATED REASON IS FALSE** — the ALL-CAPS invariant said a
  guessed kind "writes a `.save` card that matches nothing", but
  `op_annot::_cards_for` emits `.save ${dev}[${param}]` and never reads the kind
  (a kind-0 row and a kind-1 row produce byte-identical cards). **FIXED** by a
  FOURTH lookup that is reached only when all three declared ones are silent and
  that reads the kind off the vector name THIS RUN PUBLISHED — `rdw::_run_triple`
  → the new `ase::op_vector_for` (beside `op_param_split`/`op_dev_covers`, the
  two verbs it is made of) → the new `op_annot::_kind_of_vector` (beside
  `op_annot::_wrap`, whose token.c table it is the one inverse of, so the tree
  gains no second copy). Nothing is guessed: a column the run does not name is
  still refused by name. The read is gated on SHEET IDENTITY
  (`rdw::_subject_devpath`, issue 1322's own axis) because blocks deliberately
  outlive the raw and the sheet they came from, and a stale block gets a refusal
  that says which sheet to go back to. `rdw::_add_why` words that one rule once
  and `rdw::button` asks it BEFORE the dialog, so an unanswerable Add no longer
  costs a modal; `rdw::_mint_note` says on the success arm, once, that the shape
  came from the run. The ALL-CAPS invariant at `rdw::_find_triple` and the old
  row BT18 are REWRITTEN in place, not deleted, and both now name the hazard the
  invariant really was standing in front of: an accepted row joins
  `op_param_lists::_save_set`'s union and therefore the NEXT deck's `.save` cards
  (measured, `_cards_for M18` 6 → 7), where spec §3.2 / rule R5 say `show`'s
  catalogue is a SUPERSET of the savable set. **Whether an Add may accept a
  run-published column no list and no PDK declares is a USER ruling** on the owed
  ledger (rule debt 1372), with the four options recorded in the issue file.
  Fenced by rows **BT18** (rewritten, verdict reversed), **BT33**, **BT34**,
  **BT35** and **BT36** of `tests/headless/test_rdw_window_1245.tcl`
  (`RW_FLOOR` 173 → 177), each proved non-vacuous by seven sabotages.

* **1373** — `doc/claude/issues/1373-class-acronyms-printed-in-the-key-spelling.md`
  — *Device-class acronyms printed in the internal lower-case spelling.* The
  user, on their own M18: "said add to all mos (why is that not uppercase? MOS
  is an acronym!)". **ROOT CAUSE:** the Results Display Window had no
  display-name layer for a device class at all — fifteen interpolation sites in
  four procs (`rdw::_narrowed_list` 2, `rdw::_shadow_why` 1, `rdw::_edit` 11,
  `rdw::scope_dialog_build` 1) printed `$cls`, the STORE'S PRIMARY KEY, straight
  into prose, so the radiobutton read `every device of class mos` and the
  verdict read `gm is already in the mos annotation list` — the user's own two
  sentences, one missing layer twice. The file had already solved this one
  concept over (`rdw::_list_name`/`_list_gloss`, written because "four surfaces
  read these strings and four literals would drift"); classes never got it, and
  the drift was already on paper — `doc/claude/specs/op_param_lists.md` writes
  **MOS** in §2.2 and §3.4 while the code printed `mos`. **FIXED** by ONE
  accessor, `::op_param_lists::class_label`, a literal namespace array plus a
  pure proc placed in the STORE (not rdw.tcl: that file may not call `rdw::`
  under its source-time purity contract, so an accessor over there could never
  reach the store's own sentences, and a second copy is the very drift this item
  removes — there is deliberately no `rdw::_class_name` wrapper). All fifteen
  sites route through it; `$cls` itself stays the argument to every
  `::op_param_lists::` call. **THE CONSTRAINT, MEASURED:** class keys are
  compared with `eq` and used as array indices, so `MOS` is a DIFFERENT KEY —
  `get_list class MOS annotation` is empty, `governs MOS …` answers nothing —
  and the key is a field the user TYPES into `op_param_lists.conf`. So the
  store's own key-shaped messages (`_dup_why`, `_key_why`, `set_list`'s reports,
  `seed`'s divergence report, the parser's) keep the key spelling, with a
  comment at the accessor naming them, and the wrong-direction "fix" reds the
  pre-existing row RD4. The table is `mos MOS npn NPN pnp PNP esd ESD` and
  NOTHING else, with an identity fallthrough: a blind `string toupper` would
  print `PWELL_RESISTOR`, `HIGH_PRECISION_P` and `SUBCIRCUIT`, which
  `class`'s own identity fallthrough really does mint from shipped `type=`
  tokens. **ZERO existing goldens moved** — every sentence golden in both suites
  uses a synthetic class (`nwcls`, `b5cls`, `bs_pdev` …) that an identity
  fallback prints unchanged, so the change passed 307 checks while doing
  nothing; the new rows are the only fence. Fenced by **CL1..CL5** of
  `tests/headless/test_op_param_store_1245.tcl` (`OL_FLOOR` 130 → 135) and
  **CL6..CL10** of `tests/headless/test_rdw_window_1245.tcl` (`RW_FLOOR`
  177 → 181; CL10 `live_tk`-gated, not counted), proved non-vacuous by four
  sabotages — identity (all ten red), blind `toupper`, one-production-proc-at-a-
  time (CL6 / CL7+CL8 / CL9 / CL10), and the wrong-direction route (RD4).
  Whether the table should also carry prose for the snake_case sky130 keys and
  whether `bipolar` should read **BJT** is a USER ruling on the owed ledger
  (rule debt 1373).

* **1374** —
  `doc/claude/issues/1374-the-narrowed-dump-preamble-is-three-sentences-where-a-label-was-wanted.md`
  — *The narrowed-dump preamble is three sentences where a label was wanted.*
  The user, reading the block the Results Display Window prints for every
  device: "This is too verbose! Just say 'annotated list' or 'summary list'".
  **ROOT CAUSE:** two independent note-line builders, each written to a
  different defensible ruling and never costed against each other on screen.
  `rdw::_incomplete_line` emits ruling DD-1's honesty flag as a 121-character
  sentence and `rdw::_narrow_line` emits issue 1353's narrowing decision as
  three more; `rdw::format_answer` appends both on every narrowed dump.
  MEASURED in the real pane at the shipped geometry (`.rdw.p.t` is `-width 96
  -wrap word`): **311 characters over 2 logical lines wrapping to FOUR display
  lines, above SIX rows of data**, re-emitted per device. The four ⚠ comment
  blocks around those procs argue at length that each clause is obligatory, and
  every one of those arguments is about WHICH FACTS must appear — not one is an
  argument for the number of words. **FIXED** to **123 characters over two
  display lines** (`Not everything the device has - only what this run saved.` /
  `Narrowed to the MOS annotation list at this dump: 6 of 88 columns.`), which
  also REPAIRS a false deixis: the old DD-1 wording said "these are the
  operating-point columns this run saved" while pointing at six rows out of the
  88 the run saved, and the next line then corrected it. Three arms of
  `rdw::_narrow_line` became one builder; `Narrowed to the` stays (it supplies
  the sentence-initial capital the store's list name cannot, and
  auto-capitalising would print `Mos` — a collision with 1373), `at this dump`
  stays (1353 decision 3: a standing block is a record), and `Press 3` survives
  exactly where `kept == 0`, which now covers BOTH ways a block ends with no
  rows. **THE WITHHELD NON-CONVERGENCE CLAUSE WAS KEPT AGAINST A GENERAL
  INSTRUCTION TO CUT** — it is a RESULT and not an explanation, it costs 29
  characters, and MEASURED it is ABSENT on the user's own M18 (`wnf == 0`), so
  deleting it would have shortened the screen they complained about by zero
  characters while losing the one fact DD-1 and issue 1272 both say a designer
  most wants told. Fenced by **NW14** (the cap in characters, coupled to
  `rdw::_pane_chars`'s own `set W 96`, plus the five struck-out phrases gone
  from every shape), **NW15** (the surviving clause, both arms, scaling,
  silent at zero) and **NW16** (the pointer's one rule) of
  `tests/headless/test_rdw_window_1245.tcl` (`RW_FLOOR` 181 → 184; the keys
  suite gains no row and `KX_FLOOR` stays 90), proved non-vacuous by eight
  sabotages — sabotage 2, deleting the convergence suffix, reds NW15 and is the
  one a "be brief" reader would reach for. The keys suite's `cu_block` /
  `cp_block` fixtures were repaired in the same change: they relied on the
  121-character DD-1 sentence to give line 3 a real WRAP (rows CU11 and CP1),
  and now carry ruling DD-5's analysis sentence instead. Four wording choices —
  "annotation" vs the user's "annotated", whether the counts stay, the
  suffix's words, and the pointer leaning on a chrome that is one dump behind —
  are a USER ruling on the owed ledger (rule debt 1374).

- **1375** — `xschem descend -fallback` raises `ask_save` gated on `has_x`
  ALONE, so a `--script` run with a display gets an unclickable modal and hangs
  for ever. Reproduced at HEAD `5dc7b2c8`, so it is NOT the 1368-1374 batch's
  doing: `test_ase_optier_0963` is ALL PASS (102) `--nogui` and hangs after row
  N3 on `:99`. The suite's own comment asserts this cannot happen, under
  conditions that are exactly the conditions in which it does. **FILED, NOT
  FIXED** — the fix is a ruling (rule debt 1375). Until then that suite is a
  `--nogui` suite.

- **1376** — the user reports middle-button press-drag pan dead on BOTH their
  VcXsrv display and WSLg `:0`, with `cadence_style_rc`. **NOT REPRODUCED**
  here: the C arm, the Tk bindings, the cadence rc, the lock-modifier strip, the
  three servers' modifier maps, the graph-rect route and a loaded raw were each
  measured innocent. The file also records the METHOD error that produced a
  wrong first answer — `xschem callback` is the C entry point and proves nothing
  about a gesture, and `event generate` fires a `<Button>` binding only at state
  0, which manufactured and then destroyed an intermediate "lock modifier"
  finding. `tests/headless/probe_mmb_pan.tcl` is the outstanding measurement.

- **1377** — filed as four ASE suites reading the **developer's own**
  `~/.xschem/ase_simulators`; it is **SIX**. `src/xschem.tcl` loads the registry
  once at startup, so registering a simulator reddens the suites that guard the
  registry: `test_ase_core` 7, `test_ase_persist` 5, `test_ase_final` 3,
  `test_ase_preflight` 2 — and **`test_ase_sod_case` 11**, which nobody had
  noticed and which the survey found. A third, hostile registry is worse than a
  count change: `test_ase_core`, `test_ase_final` and `test_ase_final_gf180`
  ABORT on a `REFUSED` raise with 130, 55 and 4 checks never reached, while
  `test_ase_preflight` and `test_ase_sod_case` go green for the WRONG reason.
  `test_ase_sod_case` is the sharpest shape: green under an empty registry AND
  under a broken one, red only under a registry that WORKS. **FIXED** by an
  opt-in helper `test_sim_registry_isolate` / `test_sim_registry_state` in
  `tests/headless/scratch.tcl` (the file all six already source) plus one
  `ISO1377` row per suite and an `ISO1377b` round trip fencing the two clears no
  HOME can red; the user's registry file is never read, written, moved or backed
  up — the clear happens in memory after the startup load. The issue also
  records a standing red found in passing and NOT fixed: `test_op_dump_altshow`
  H1, a stray gitignored `/untitled~.sym` dated 2026-09-04, needs its own number.

- **1378** — `op_param_lists::write_conf` turns the user's settings file into a
  **symlink** when `<path>.new` is one: `open` follows a symlink and `file
  rename` does not, so the bytes land on the link's target — an unrelated file,
  truncated — and the link itself is moved onto the settings path. rc=**1**,
  **zero reports**. The third member of issue **1276**'s family, found by that
  item's own re-verification pass on 2026-09-07 and **filed, not fixed**,
  because 1276's scope was an explicit lift of two named hunks. Row W1 of
  `test_op_param_store_1245` makes `<path>.new` a *directory* (where `open`
  fails and the writer behaves); nothing makes it a *link* (where `open`
  succeeds). `ase::sim_write_conf` shares the idiom — see issue **1286**.
  ⚠ **FIXED 2026-09-07, close-out item F3, and it was in BOTH writers** — the
  claim in 1286 that it applied only to the sibling was measured false. Rows
  `W7f W7g W7h W7i` (`test_op_param_store_1245`, 138 → 142) and
  `R11j R11k R11l R11m` (`test_ase_simreg_0931`, 91 → 95). No new number was
  minted for the `..`-collapse residual measured alongside it; it is recorded
  in 1276, 1286 and in both resolvers' comments instead.

- **1379** — the Results Display Window's chrome line still reads "No device has
  been sent here yet" after a dump lands in the pane. `rdw::_chrome_line`
  derives its `filled` flag from `llength $blocks`, but the only proc that
  writes that text into `.rdw.hdr` — `rdw::apply_list_state` — is reached only
  from `rdw::build` and `rdw::set_list` (an invariant the comment at
  `src/rdw.tcl:409` states outright), and `rdw::push` calls neither. **Issue
  1367 in the mirror**: that one claimed to be `Showing` an empty pane, this one
  claims an empty pane while showing two blocks. Found 2026-09-07 by the
  look-debt digest batch, in the first RDW photograph it took; measured on `:99`
  against the tree's own `_chrome_line` one line later, so the widget and its
  builder disagree with no golden in between. **Filed, not fixed** — the batch
  was a reporting batch. No existing row reads the WIDGET after a push, which is
  how the same sentence came to be false in both directions.

- **1380** — `op_param_lists::load` had **zero callers**: Save wrote
  `<pwd>/.xschem/op_param_lists.conf` and no session ever read it back, so the
  RDW's parameter lists did not survive a restart and the Save button's own
  sentence was true and useless. Reported by the user 2026-09-07 ("*'Save'
  modified list … is not surviving session*"). The loader itself is complete —
  called by hand in a fresh process it restored their nine-row summary list
  exactly — so the fix is one guarded call at the `src/xschem.tcl` source seam.
  **FIXED**, verified in a fresh process. No suite caught it because a round
  trip needs TWO processes and every store row is single-process; that fence is
  still owed, as is a fix for `BT9`, which now reds because the user having
  their own `.xschem/` in the repo root is indistinguishable, to that row, from
  the suite dropping one.

- **1381** — the three decisions the multi-row Add/Delete had to take that the
  user's instruction did not settle (a one-row selection beating the shaded row;
  a partial batch proceeding rather than refusing whole; the cursor cleared after
  a multi-row press), each shipped in a stated reading with its alternative
  recorded — **rule debt 1381**. And, fixed in the same change, the three hygiene
  rows (`BT9`, `SD4`, `H1`) that asserted `<repo>/.xschem` did not exist: a
  legitimate user artifact since issue 1380 made it load at startup, so a
  developer who had used Save redded three suites for having used the feature,
  and the obvious way to green them again is to delete their file. That happened
  in this session. Now a snapshot-and-compare, which is what the rows always
  meant.

- **1382** — the Results Display Window had **no close control of its own**.
  Ruling DD-12 had already promised one — its stated cost reads "a user who
  expects Escape to dismiss the window will press it and see nothing happen.
  *The window has its own close control*" — and the only one was the window
  MANAGER's `X`, which is chrome and not part of this window at all. Requested
  by the user 2026-09-07 ("*In the RDW, add a Close button to dismiss the
  window*"). **FIXED**: `.rdw.b.close`, `-command rdw::close` and nothing else,
  at the foot of the column below `aA`, so the button and the WM's delete
  protocol are two DOORS on one rule; Escape still ends the pick and never
  closes, which is DD-12 and is now fenced by arithmetic (row CB2). Close is a
  **withdraw** — the dumps are namespace state and survive it, which ruling
  DD-16 leans on — fenced at source (CB3) and by a real press and reopen (CB6).
  Two supporting single-definition fixes: `rdw::apply_list_state`'s greying loop
  now walks `rdw::_buttons` instead of five literals, and `rdw::button`'s
  unknown-id refusal stopped claiming there is no button called `close` (or
  `fontsize`, which it had wrongly said since issue 1368). Also found and fixed
  here: **FZ17's fixture was leaning on `aA` being the lowest widget in the
  column** and went red with `balloon_show` untouched — now parked on the
  button's own bottom edge. Rule debt **1382**, one look debt, one `:0` suite
  debt.
  **REPAIR PASS, same number.** An adversary could not break the button and
  broke the column it sits in: Close pushed `winfo reqheight .rdw.b` to 243 px
  against the 208 px `wm minsize .rdw 520 260` leaves it, and at the window's
  OWN advertised minimum `winfo ismapped .rdw.b.fontsize` was **0** — issue
  1368's `aA` control, evicted, because `-side bottom` allocates Close first.
  The constant was written for item B3's five-button column and never re-judged
  (1368 had already reduced its slack to 4 px). Now derived: `rdw::min_floor`
  keeps `520 260` as a floor and `rdw::apply_minsize` raises it to `reqheight
  .rdw − reqheight .rdw.p + reqheight .rdw.b` = 295, the `calc::min_floor` /
  `calc::apply_minsize` shape this tree already uses for the same defect. Two
  stale widget enumerations rewritten, and two comment overclaims corrected —
  a misclick on Close costs no DUMPS (it does not end a running pick, which is
  now a stated contract, rows CB8/CB10), and `rdw::_active_phrase` is a claim
  about the LIST ACTIONS and not about the column. Rows CB7–CB10, `RW_FLOOR`
  191 → **193**. Rule debt **1382_repair**.

- **1383** — **four rows of `test_rdw_window_1245` are a standing red on `:0`**
  (Xwayland), and nobody had filed it. `SL8`, `FZ11`, `FZ17` and `FZ18`, green
  on `:99` and on the `--nogui` arm, red on `:0` at HEAD — measured with issue
  1382 entirely out of the tree, so they are not that item's. `SL8` is a font
  metric difference (the fixture picks 600 px by hand and the sentence does not
  re-wrap there on the other server); the FZ trio answer `NO-BALLOON` — the tip
  never appears after one `update`, which is the 3-vs-1 `<Configure>` traffic
  the tree has measured before. ⚠ **One run in ten reported `ALL PASS (204
  checks)`, which is the `--nogui` count: the `:0` client died and the suite
  fell back to its headless arm.** A green `:0` line from this suite is not by
  itself evidence — check the count. **NOT FIXED**; filed rather than
  re-derived, per CLAUDE.md's standing-red rule and the four-times-filed
  history of 0689/0690. The `test_rdw_window_1245` suite debt now points here.

- **1384** — the schematic's status bar **never said what the RDW pick mode was
  waiting for**. Requested by the user 2026-09-07 ("*status bar should suggest
  'Click on instance for annotation/summary/all OP info in Results Display
  Window'*") with a tooltip for the overflow. **FIXED**: the gate is
  COMMAND-MODE ENTRY, the user's own restatement — `rdw::key`'s `none` branch
  and nothing else, `intuitive_interface` not read at all. The other two
  branches were DRIVEN at HEAD first and already behaved exactly as the user
  described (one selected → that instance, no mode, CIW silent; two → a CIW
  warning and a refusal that moved nothing), so no repair was owed. The slot is
  `.statusbar.10`, xschem's own mode-prompt label: `.statusbar.1` was measured
  and refused because callback.c:10177 rewrites it on EVERY event and
  `statusmsg_hold()` expires after a fixed 5 s. `.statusbar.10` is *blanked* by
  `update_statusbar()` instead, so the answer is `ase::ui::sod_prompt_pump`'s
  80 ms re-assert, taken unchanged. `rdw::_hint_sync` is the ONE proc that
  decides what the slot says and every exit is a door on it — twice over, the
  transition synchronously and the pump as the net. Two new helpers beside
  `balloon` in xschem.tcl: `balloon_off` (cancels a pending show found in
  `after info`, clears only bindings that ARE balloons) and `balloon_clipped` /
  `label_clipped` (arm a tip only when `font measure` overflows the label's own
  width — measured threshold, 800 vs 815 px of main window). Rows HT1–HT10 and
  HP1–HP2; `RW_FLOOR` 193 → **198**, `KX_FLOOR` 90 → **92**; FZ4 re-spelled to
  count the three `::balloon` calls BY NAME. Rule debt **1384** (three
  decisions), one look debt, one `:0` suite debt.

- **1385** — **two rows of the RDW suites answer to state an earlier run left
  behind**, and one of them flipped item A's `ALL PASS (90)` into a red with
  nothing in the tree changed. `C2` of `test_rdw_keys_1245` searches for a
  pixel where the snapped and un-snapped picks disagree; whether one exists
  depends on the zoom, hence on the main window's width, which `set_geom`
  restores **per schematic file** from `~/.xschem/geometry` and which **every**
  Tcl `exit` rewrites (`Tcl_CreateExitHandler` → `xwin_exit` → `store_geom`).
  Proved with `--preinit 'set initial_geometry ...'`, touching nothing:
  1110x761 → ALL PASS, 900x761 → **C1** red, 700x761 → **C2** red. ⚠ The
  corollary is a hole in CLAUDE.md's own `~/.xschem` rule: **an ordinary
  `--script` run writes that file**. The second case is `FZ7` of
  `test_rdw_window_1245`, which read `.rdw.b.fontsize` as `active` because the
  PREVIOUS run's FZ11/FZ17/FZ18 left the X pointer on it — mitigated by issue
  1384's new section parking the pointer, not fixed at FZ11. **NOT FIXED**:
  the C-section fix needs a ruling (pin the geometry, widen the search, or
  drive at a fixed zoom) and issue 1303's two filed numbers must be re-taken
  under whichever wins. Rule debt **1385**.

- **1386** — **eighteen rows of `test_rdw_keys_1245` are a standing red on
  `:0`** (Xwayland), and nobody had filed it. Found while PAYING that file's
  own `:0` suite debt during issue 1384. Measured at HEAD with both RDW UX
  items out of the tree: `18 FAILED (72 passed)`; with 1384 in,
  `18 FAILED (74 passed)` — the same count, the two extra passes being 1384's
  own HP1/HP2, which are green on both servers. Stable core F1, B2–B5, V2, V3,
  V7, D1, RA1–RA6, KD1, plus a two-row rim out of {F3, F6, C2, LK2, CP9}. Five
  unrelated mechanisms — key delivery, focus grants, the seized-binding
  gestures, the descend re-latch and the whole raise section, whose own look
  debt already records that `:99` cannot reproduce what it tests. `C2` belongs
  to issue 1385 instead. Same `:99` suite: ALL PASS (92), four runs.
  **NOT FIXED**; the suite debt now points here, and a crew reporting this file
  must give both arms.

- **1387** — **two Tcl command modes seize one canvas, nobody decides, and
  neither of them works in a tab.** Filed while repairing issue 1384; none of it
  is 1384's. Four parts, all measured on `:99`. (1) `rdw::pick_start` asks
  `winfo exists [xschem get current_win_path]`, which is **0 in a tab** (tabs
  share the one real `.drw`; `top_path` is empty), so 1/2/3 with nothing
  selected does nothing there **and says nothing, not even in the CIW** — a
  refusal that names itself is this file's own rule. (2)
  `ase::ui::sod_statusbar` still carries the `regsub {\.drw$}` arithmetic that
  1384 corrected in its copy, and answers `.x1.statusbar.10` for a tab; the copy
  could not correct the original because `rdw.tcl` deliberately does not call
  into `ase_window.tcl`. (3) An RDW pick and an ASE select-on-design can be live
  at once — each self-serialises only against its own kind — so
  `<ButtonPress-1>` is seized twice, last arm winning silently, and TWO 80 ms
  pumps write `.statusbar.10` with neither reading the other. 1384's synchronous
  re-assert makes the label agree with the seize instead of contradicting it,
  which is an improvement and not a decision. (4) `ase_window.tcl:1884` states
  that an 80 ms re-assert costs "at most a sub-frame flicker"; measured with the
  same mechanism it is **16-40 % visible** while the pointer moves, with the
  slot's width swinging 8 <-> 471 px at ~12 Hz. Row **HT14** of
  `test_rdw_window_1245.tcl` pins part 1's silence so a fix cannot land without
  the hint following. **NOT FIXED**; part 3 needs a ruling, parts 2 and 4 are
  ASE's file and want an ASE row each.

- **1388** — **the settings file did not know which PDK it was for**, and the
  identity work uncovered a sharper defect than the grammar: the startup
  `catch {::op_param_lists::load}` (`xschem.tcl:17550`) runs while `xschem.tcl`
  is sourced, and a PDK workarea is entered with `--script
  <ws>/cadence_style_rc`, which `xinit.c:3793` sources **after** it — measured,
  `env(PDK)` is still UNSET at the top of the `--script` phase. Of the four
  candidate identities only `env(PDK)` survives measurement: `env(PDK_ROOT)` is
  set by none of the three workareas (`::PDK_ROOT` is a *location* shared by
  every PDK in one open_pdks install), `$::XSCHEM_LIBRARY_PATH` is **EMPTY** in
  all three, and the registered `op_annot` descriptors are **byte-identical
  between sky130A and gf180mcuD**, which is the user's own example. FIXED:
  `[pdk <name>]` sections plus `[pdk *]`, un-scoped rows apply to every PDK,
  PDK beats un-scoped as a **rank** (two reader passes, no rank field), another
  PDK's rows are never parsed and never rewritten, a Save **edits the rows
  where they already are** and invents no section, the grammar version does not
  move, and the three shipped `cadence_style_rc` files declare the PDK with
  `op_param_lists::set_pdk`, which re-reads the tiers. ⚠ A **second** defect was
  found only by a real launch and not by any row: `set_pdk` compared `pdk`
  before and after its own write, and the rcs set `env(PDK)` FIRST, so the two
  were equal and the section was silently lost — the store now records the PDK
  its rows were READ under. Section **PK** of `test_op_param_store_1245`,
  `OL_FLOOR` 135 → **158**, including **PK20/PK21, the two-process fence owed
  since issue 1380** and **PK7b**, the row that defect minted. Rule debt **1388** (which
  scope a Save writes into), one look debt (the two-axis header).

- **1389** — **ASE-L would start a second simulation on top of the first.** The
  user's 14:07 bench run annotated blank and printed zilch in RDW; the cause was
  not the annotator but a **double launch**. `/tmp/Xschem.log.1` carries two
  `xschem netlist` lines and two `This run is starting the simulator…` lines
  before either `simulation finished`, because both `Simulation > Netlist and
  Run` and the `N&>` strip button are plain Tk button commands and **nothing
  anywhere checked whether a run was in flight**. The deck says `set appendwrite`
  (issue 0929), so run 2 appended its Operating Point plot to the raw run 1 had
  not finished writing — `xschem raw points` 2, `xschem annotate_op` 423 vectors
  and every row blank, against **8248 vectors / 212 devices** from the identical
  deck with one dataset. FIXED: one predicate, `ase::run_in_flight`, keyed on the
  **results file** (not the session, not the widget — two ASE-L sessions on one
  cellview and a `Netlist and Run` racing a `Run` are the same hazard as a
  double-click), with three consumers: `ase::run_deck`'s gate (the authority,
  covering both buttons, `ase::run`, `run_existing`, a CIW paste and any script),
  the two ASE-L doors, and `do_stop`'s fallback. The gate sits at the **top** of
  `run_deck`, not "just before `eval execute`" as the plan asked: between those
  two points `run_deck` deletes the raw and rewrites the deck, so a late refusal
  would destroy the live run's results file — issue 0929's own symptom,
  manufactured by the fix for it. Lock set after the `-1` check, cleared in
  `run_done` from `meta`'s `rawlock`, and self-healing when `::execute(pipe,$id)`
  is gone. ⚠ **Three defects were found by the adversary pass and fixed by the
  integrator, and each had shipped green.** (1) *The CIW was FOCUSED, not merely
  raised* — the user's own emphasised requirement. `raise_toplevel`'s mapped arm
  is `wm withdraw` + `wm deiconify` and **a re-map is an activation**, so it and
  `raise_activate_toplevel` are indistinguishable in the property that matters,
  and the row that spied which one was called could not see it. Measured on all
  three X servers here: a plain `raise` rises **without** the keyboard on
  `:99`/openbox and is issue 0054's **no-op** on `:0`/Xwayland *and on the user's
  own screen* (`172.20.160.1:0`, the Windows X server, `_NET_SUPPORTING_WM_CHECK`
  **not found** — no EWMH WM at all). Shipped: plain raise, verify against the
  toplevel holding the keyboard, re-map only if it did nothing. A focus restore
  and a `-topmost` pulse were both tried and both rejected on the measurement.
  (2) *The refusal named a remedy that was a no-op* — `do_stop` was keyed on the
  session's `run_id` attr, so the refused session, a CIW/script run, and any
  session closed and reopened mid-run all answered *"no simulation running for
  this session"* over a live run: the user could neither run nor stop. `do_stop`
  now falls back to the lock, through the same predicate. (3) *The residual race
  §8 called unreached is reached by the originating gesture* — `do_run` calls
  `update` in its design-window routing arm, so a second press dispatched there
  launched while the outer press was refused **as a failure**: status `running` →
  `fail`, a red *Error* over a healthy run, and the same sentence in the CIW
  twice, once `note` and once `error`. Both doors now route a raise out of
  `ase::run` through `ase::ui::run_raised`, which recognises the refusal by its
  own minted sentence. Section **RG** of `test_ase_core.tcl`, 184 → **203** in
  both arms (the arms are equal by coincidence — NT14 skips under X, RG6's
  behavioural leg skips headless), ten neutralisations across four passes. The
  refusal reads issue 1391's `ase::ui::menu_path_stop` and never retypes it (RG5
  fences the absence of a copy; grep confirms the only two literals in `src/` are
  both comments). Rule debt **1389** (the `note`-not-`error` tag and the wording),
  look debt **1389** (on the user's own WM-less screen the CIW can only be raised
  by a re-map, so the emphasised half is **not** delivered there), suite debt
  `test_ase_core` (one `:0` run).

- **1390** — **the dump coverage check could never pass under `preserve`.** On
  the same 14:07 bench run, a red `#!` line said *"only **0 of the 78** devices
  your schematic asks about are in it, so the rest of the rows will be blank"* on
  a run whose annotation was perfect — and it fired on **every** run of that
  bench. `ase::op_report_missing_dump` built its `have` set from the dump's block
  headers **verbatim** and compared against `devs`, which `op_annot::devpath`
  lowercases unconditionally; the user's `ngspice-ver50` is registered `-casemode
  preserve`, so `show all` writes `M.x1.x23.XM2.M…` and the comparison could
  never match. Reproduced one device, one file, spelling the only difference:
  lowercase → silence, preserve-cased → `op_dump_partial`. The VALUES were always
  fine — `save.c:4175 raw_lookup_name`'s fold rung resolves the lowercase query
  against the stored mixed-case name, measured `1.37276e-12` either way — so this
  was purely a diagnostic that lied. FIXED by running the C ladder's own shape in
  Tcl: exact spelling first (an all-lowercase dump still answers on rung 1,
  unchanged), then the case-folded alias, with two headers differing only in case
  **declining** exactly as `raw_build_fold_table` stores −1 (DECISIONS.md D2). The
  ratified sentence is untouched. Rows **Y6–Y10** of `test_op_dump_altshow.tcl`,
  65 → **70**, paired lowercase/preserve twins required byte-identical; Y6 reds on
  the shipped exact-only compare, Y10 on a naive fold with no D2 decline. Rule
  debt **1390**: the fold is **unconditional** and does not consult the run's case
  mode — `devs` carries no case, so an exact compare under `distinguish` is
  today's defect unmoved, and gating on the *requested* mode would be the wrong
  gate because `Raw.case_sensitive` is a property of the READ.

- **1391** — **eight glyphs on the action strip and not a word between them.**
  `OP,TR = --> X N&> > ! ~`, and no tooltip anywhere in `ase_window.tcl`. FIXED:
  all eight carry a balloon tip, plus the temperature entry — but the
  load-bearing half is the **mint**. Eleven `ase::ui::lbl_*` constants and five
  `>`-separated menu-path composers now live in the same label section as
  `lbl_outputs`/`lbl_save_all`, and **the menubar is built from them**, so the tip
  and the menu entry are one string and cannot drift (the 0661 shape: a printed
  `Outputs > Save All` beside a menu reading `Outputs > Save All… > …`, string
  match 0). ⚠ **FIVE** strip buttons have a menubar twin, not the three the brief
  listed nor the four the first draft's comments claimed in eight places across
  three files — `OP,TR` is `Analyses > Choose…`. The count was corrected
  everywhere against a walk of the shipped `ase::ui::strip_tips` table (5 menu
  paths, 3 bare action names), and the issue now records what the mint does
  **not** yet reach: all three bare-named actions also sit on a per-pane CONTEXT
  menu spelled differently (`Add…`, `Delete`), which is not built from these
  constants. One measured cost: `balloon` does a plain bind on `<FocusOut>` and
  `$top.tb.temp` already carried `ase::ui::temp_commit` there — arming the tip
  second **deleted the commit outright**, so a typed temperature clicked away from
  never reached the deck; the builder arms the balloon first and the commit
  appends with `+`, and row **W1s3** reads the composed script back and reds if
  either half goes. Rows **W1s1–W1s6** of `test_ase_window.tcl`, 229 → **245**,
  every one read off the LIVE widget and compared to the constant **and** a
  literal golden. Item 1389's refusal consumes `ase::ui::menu_path_stop` from
  here. Rule debt **1391** (nine unratified tooltip strings and the deliberate
  mixed form), look debt **1391** (a tip is pixels; `balloon_show` returns early
  unless the pointer is physically over the widget, so every row asserts the
  `<Enter>` binding and no headless row can prove one appeared).

- **1392** — **the blank-row diagnosis named a box that was already ticked.**
  `cadence::_annot_cause` classified the user's bench `noparams` and told them to
  *"Run the simulation again with device parameter saving turned on"* — which was
  already on. That is what sent them to `Outputs > Save All…`, visible in their
  action log at line 64, hunting a tick that was already there. The honest fourth
  cause is *"the results file holds more than one operating point, so the device
  numbers were not merged"*. Mechanism measured: on a 2-plot raw with a fresh
  sidecar beside it, `_annot_devparams_present` answers 0 (savecurrents' `i(@…)`
  is skipped on purpose), so the tail arm fires. **FILED, NOT FIXED, and
  deliberately**: issue 1389 closes the only measured route in, so building the
  fourth cause now would add a branch nobody can reach. ⚠ The adversary pass
  recorded the consequence honestly: on that exact shape the shipped code printed
  a wrong line and, after 1390, prints **nothing at all** —
  `op_annot::opdump_autofill` refuses in silence on its `raw points != 1` gate.
  1389's lock is a per-process dict, so two xschem processes on one cell still
  reach it. §6 of the issue says what would turn the judgement over.

- **1393** — **the annotation level is taken only when THIS session owns the
  nearest one.** Minted by the `descend_run_batch` (`doc/claude/descend_run_batch/`)
  while closing 0643. `ase::ui::annot_ensure_loaded` (`src/ase_window.tcl:2782-2793`)
  resolves the hierarchy level it stamps the results basis at from
  `ase::session_for_current`, but takes it **only when
  `[lindex $s 0] eq $key`** — i.e. only when the nearest ancestor session is the
  one being refreshed. `session_for_current` (`src/ase.tcl:9263`) walks
  deepest-first and returns the NEAREST session, deliberately (issue 0168: a
  session bound to an intermediate cell simulates that cell as its deck's top).
  With one session the two coincide and the guard is invisible; with a **second**
  session bound to a descendant cell they diverge, `$level` stays `{}`, and
  `annotate_op` leaves `raw->level` at `currsch` (`src/scheduler.c:2540-2542`
  only overrides it `if(level >= 0)`), so `sch_waves_loaded()` (`src/draw.c:2853`)
  cannot place the deck-absolute paths and every device row on the sheet renders
  **blank, with no sentence**. Measured on the same bench that closed 0643, both
  sides of the door: `db_attach $raw 0` → `raw_level=0 sim_sch_path='x1.x1.'`,
  `db_attach $raw {}` → `raw_level=2 sim_sch_path=''`. **FILED, NOT BUILT, and
  deliberately** — the reported bench runs one ASE-L session, where the guard can
  only pass, and building an unreachable branch is the defect 1392 was just
  written about; it also needs two nested ASE-L sessions, which no suite in the
  tree sets up. The option set is three-way and turns on asking a *different*
  question: (a) `ase::stack_level [ase::ui::design_path $key]` — the mint
  `descend_run_batch` just added at `src/ase.tcl:6016` answers "where does MY
  design sit on this stack", which is what the proc actually wants; (b) drop the
  `eq $key` test — cheapest and **wrong**, it would stamp the outer session's raw
  at the inner session's level; (c) refuse in words instead of drawing blanks,
  on the argument that the silence is the real user-facing bug. Rule debt
  **1393**; §6 names what would turn the not-built judgement over (a user report,
  anything that makes a second session ordinary, or any change to
  `session_for_current`'s scan direction).

- **1394** — **a zero-instance child schematic turns a later `xschem netlist`
  into a modal that hangs a scripted run.** ⚠ **PRE-EXISTING, reproduced at HEAD
  `19f8e351` with no `ase::` code in the picture** — found by crew A of the
  `descend_run_batch` while building a fixture, filed against the batch only
  because the batch is what walked into it, and **not** reproducible on the real
  `sky130_tests_ase/tb_bandgap` bench (whose descended netlist is byte-identical
  to the top one). On a two-level fixture whose child has **zero instances**,
  `descend ; go_back ; xschem netlist -noalert <f>` pops
  `Please Set netlisting mode (Options menu)` and a scripted run **hangs on it
  forever**. Two halves, both verified against the source rather than copied:
  `load_schematic()` moves `netlist_type` to `CAD_SYMBOL_ATTRS` for any file with
  `xctx->instances == 0` (`src/save.c:6469`), and `CAD_SYMBOL_ATTRS` is 5
  (`src/xschem.h:229`), which is not one of the five formats the netlist
  dispatcher tests — so it falls into the dispatcher's `else`, and that `else` is
  the message box (`src/scheduler.c:9167-9169`). **`-noalert` cannot suppress
  it**: `alert` (cleared at `src/scheduler.c:9089`) is passed to the five
  `global_*_netlist()` back ends and is not consulted on that arm at all. Under
  `--nogui` the modal is skipped and the wrong mode is used silently instead,
  which is the quieter half of the same defect. ⚠ **What is NOT established is
  crew A's stated cause** — "the parent reload does not put it back". The very
  next lines *are* a restore (`src/save.c:6474-6480`) and `go_back` does reach
  them (`src/actions.c:6505-6506`, `reset_undo` 1), so on a straight reading the
  type should come back; the issue records that honestly and names two
  candidates instead, the leading one being that `save_netlist_type` is
  initialised to **0** per context (`src/xinit.c:913`, and `alloc_xschem_data()`
  runs per window and per tab), 0 being no more a valid format than 5. Worst
  property: the hang produces no exit code, no banner and no `FAIL`, so it is the
  one shape `tests/banner_rule.tcl` and the two shell readers cannot classify.
  In the meantime the RT rows drive the trip with a probe, RT11 stubs
  `ase::netlist_in_place`, and the RT child fixture is given one instance —
  workarounds to be reverted when this closes.

- **1395** — **registration persists through one door, and the choice persists
  through one too many.** Filed 2026-09-08 as item D of the ASE-L
  simulator-choice batch (`doc/claude/ase_simchoice_batch/CREW_BRIEF.md`), which
  is also what fixes it. Two halves of one boundary, and the shipped tree has
  each backwards. **Registration does not reach disk through every door**:
  `ase::sim_register` (`src/ase.tcl:1300`) and `sim_unregister` (`:1459`) write
  nothing, and the registry survives a restart only because the GESTURE saves —
  `ase::ui::simdlg_commit` (`src/ase_window.tcl:4649`) is `catch
  {ase::sim_write_conf}` and is the ONE production call site of the writer. So
  the Simulators dialog persists and the CIW does not, while
  `src/xschem.tcl:4935` promises persistence unconditionally and issue **1370**'s
  own comment (`src/ase_window.tcl:288`) already calls the CIW a real door and
  records that *this user's* `ngspice-ver50` entry was created through it — 1370
  fixed that door's DISPLAY half and left its PERSISTENCE half. **The choice
  reaches disk when it must not**: the entry in force is the process-global
  `ase::sim_use` (`:711`), in no `schema_keys` entry, so changing it cannot move
  `ase::session_dirty` (`:8996`), needs no save and prompts on no shutdown — and
  yet `sim_write_body` (`:3157`) writes an `ase::sim_select` line (`:3200`/`:3203`),
  so a choice gesture lands in the environment file anyway. Measured with
  `::USER_CONF_DIR` redirected to scratch: two registrations leave **no conf file
  at all**, and the writer, once called by hand, wrote `ase::sim_select bb`.
  ⚠ **The state key `simulator` is the BACKEND** (`ngspice`) and is already
  state and already dirties; the registry entry (`ngspice-ver50`) is the thing
  this issue is about. The fix: `ase::sim_default` for the installation default,
  a three-valued `sim_entry` state key (in `omit_if_empty`, or all 104 committed
  `.state` files stop round-tripping byte-identically), persistence moved from
  the gesture to the mutation and gated on `sim_origin eq session`,
  `ase::sim_clear` deliberately excluded because teardown is not a choice, and
  `sim_write_body` writing the default and never the in-force choice. Rule debt
  **1395** (two ASE-L windows still share one `ase::sim_use`: the run applies the
  running session's choice, but the other window's bar may momentarily name the
  other one — recorded, not fixed).

- **1396** — Save State overwrote an existing state with no confirmation. `Session > Save
  State` is always a Save-As and its only guard was `save_as_needs_confirm`, which by
  decision **D13** asked only on read-only + same-target; a different existing state was
  destroyed in silence. The user retired D13 on 2026-09-09 ("Just confirm if overwriting
  an existing state"; undo explicitly not wanted). Fix: a second predicate
  `ase::ui::save_as_overwrites_other`, the two sentences moved into the `lbl_*` family,
  and two defects the fix itself introduced — `<Return>` arming the popup that the same
  key raised, and a confirm orphaned by its own form's Escape — closed by
  `ase::ui::confirm_safe_default` and `ase::ui::confirm_owned_by`. Rule debt **1396**
  (the new sentence, the untitled-session rule S-3, and whether unwritable deserves a
  third sentence).

- **1397** — headless suites write the developer's real `~/.xschem/geometry` and evict
  their entries. `store_geom` keeps the 100 most recent per-schematic geometries in
  `$USER_CONF_DIR/geometry`; suites that open a schematic without redirecting
  `::USER_CONF_DIR` write the real file. Measured: **50 of 101 lines were scratch paths**
  after one session, i.e. half the developer's remembered window geometries permanently
  displaced. Two fixes proposed, neither taken: a per-suite redirect closed by a lint row,
  or one scratch `HOME` in the harness (measured to give an identical check count and
  leave the file byte-identical).

- **1398** — ASE-L rendered in a typeface nobody chose, and went blank in the dark scheme.
  `ase::theme` named Arial and Courier, neither installed; the ladder was inverted and 52
  of 53 fonted widgets were bold; `apply_theme` set a background and never a foreground,
  so the shipped `dark_gui_colorscheme 1` rendered 58 widgets at 1.119:1 and the
  temperature entry at 1.000:1; and pixel column widths against point fonts clipped at any
  other `tk scaling` while ratcheting on resize. Fix: four roles derived from
  `TkDefaultFont`/`TkFixedFont` via `font configure` (never `font actual`), one
  refuse-don't-clamp size knob, a foreground wherever there is a background, and column
  widths derived from `font measure` with a `-minwidth` of the heading's own ink.
  `ase::palette` is untouched. `PLAN.md` Stage 1 only.
- **1399** — `test_wave_sigbrowser_0312` has two standing reds (BF21a, BF24a) on the
  display arm. Proved pre-existing against a shadow tree built from `git show HEAD:`. The
  suite is not in `run_regression.tcl`'s case list, so T1 has never covered it.

- **1400** — **two clones filed the same issue numbers, and neither could see the other.**
  `~/dev/xschem-claude` and `~/dev/xschem-op-wcard` are both checkouts of this repository,
  and each read its own `NUMBERING.md` tail honestly, because this file is tracked and
  per-branch. **Sixteen** numbers in `1333–1348` mean two different defects each. **As of
  2026-09-10 10:46 -0700, twelve of them named two different files** — 1338, 1339 and
  1344–1353 — and the set was still growing at that moment: op-wcard filed `1350`–`1353`
  between 10:19 and 10:45 that morning and its tail then read **1354**. Every count in this
  bullet is a timestamped observation, not a standing fact. The two reservations overlap
  outright (`## Reserved: 1337–1341, the RDW batch` here against op-wcard's `**1333-1348 are
  reserved**`), and op-wcard's pointer is aimed straight into `1349–1399`, all 51 of which
  this branch has committed with no gaps — so the rest of that band is queued behind it and
  nothing in either tree reports it. A merge from base `28dabfe8` conflicts on four files
  (`NUMBERING.md`, `src/ase.tcl`, `src/op_annot.tcl`,
  `tests/headless/test_op_dump_altshow.tcl`) and takes op-wcard's colliding issue files as
  **clean adds — 8 of them at 2026-09-10 10:46 -0700, zero conflicts** — leaving a merged
  tree that holds **16 files carrying 8 duplicated numbers**. The shared `owed.sh` ledger is
  the live hazard: `clear` resolves by exact filename (`:288-295`), `add` is a bare `>`
  (`:187`), **six** bare rule ids on collided numbers stood at 10:46 (1337 1339 1344 1351
  1352 1353) and **35** are loaded inside `1349–1399` — **32 of those stamped to this
  branch and sitting inside `1354–1399`, directly in front of the other clone's pointer,
  which read 1354** (`ls ~/.claude/xschem_owed/rule | /usr/bin/grep -xE
  '13(5[4-9]|[6-9][0-9])'`, each entry then tested for `repo:/home/analog/dev/xschem-claude`;
  re-measured 2026-09-10 12:41 -0700).

  **A ruling WAS lost here.** At **10:46:14 -0700 on 2026-09-10** the other clone ran
  `owed.sh add rule 1351` and overwrote this branch's standing, unanswered RDW ruling **in
  place**: exit 0, the word printed was `recorded`, no warning, no pre-image. It came back
  only because a hand-taken `cp -a` of the ledger happened to exist
  (`~/.claude/xschem_owed.bak.2026-09-10`, taken **09:37:32** that morning — not by any
  automation); it was restored at **12:18:24** as `rule/1351@xschem-claude`, and **both 1351
  rulings now stand, both unanswered, and only the user may close either.**

  ~~**No ruling has been lost**~~ — that sentence stood in this bullet until 2026-09-10 and
  is **superseded**. The audit behind it was honest and its own finding still holds:
  op-wcard cleared its own `rule/1338` at 06:54:10 on 2026-09-10, transcript and directory
  mtime agreeing to the second, and 1338 survived on a naming coin-flip. It was wrong only
  because it was written at **10:49:57**, three minutes *after* a loss it structurally could
  not see — an in-place `>` rewrite moves no directory mtime and changes no file count, so
  the very forensic that proved 1338 safe is blind to what took 1351. **The lesson is not
  “1351”. It is that the ledger reports nothing at all when it loses a ruling, and that the
  only reason this one is recoverable is a backup nothing automates.** Read any “nothing was
  lost” claim about this ledger as a statement about what its author could see.

  This branch renumbers **nothing**: it reserves `1500–1599`, publishes the
  `1333–1348` → `1500–1515` map at the head of this file, and carries the who-moves
  question as a `rule` debt. The reservation and the map are at the **head** on purpose:
  the merge above folds everything from well above this bullet down to the end of the file
  into one conflict hunk, so this bullet, the pointer and the tail warning are all inside it
  and the head section is not. Filed by item **N1** of `doc/claude/numbering_batch/`.

- **1401** — **an analysis type ASE-L cannot render is dropped in silence.**
  `ase::backend::ngspice::render_deck`'s emit loop walked a literal `{op dc ac tran}` and
  matched rows against it, so a `.state` row of any other type was never visited at all —
  the `continue` skipped it once per type and the `switch` has no `default` arm. Measured
  on a noise-only state: rc **0**, no analysis command, no `$sim_status` guard, no
  `remzerovec` and **no `write` at all**, so the run produced no raw file whatsoever, while
  `ase::n_enabled_analyses` counted the row and the Analyses pane went on showing it
  ticked. The loop now walks the ENABLED ROWS and ranks them (`ase::analysis_emit_rank`,
  `ase::analysis_emit_order`); an unranked type is a named refusal, raised by
  `ase::preflight_gate` ahead of the deck write and again by `render_deck`, and **`set
  ase_preflight 0` does not defeat that clause**. The emit order is unchanged and deck
  golden D1 does not move. **Stage 0 of `doc/claude/ase_analyses_batch/`** — the only stage
  of that plan that is urgent, and the only one carrying no ruling.

~~**The next free number is 1400.**~~ superseded: **1400** is filed, above.

- **1402** — **the shipped bandgap bench does not converge reproducibly, so
  `test_ase_optier_0963` X7 flaps.** The row has been called a flake in that suite's own header
  since the 1377 sweep, and it is one — measured 2026-09-11 at **one red in three** consecutive
  runs with identical code, `HOME` and binary. **But the flake is in the simulation, not in the
  assertion**: on the red run X7's own `MEASURE` line reads `rc=1 raw=-1bytes op-vectors=0`, so
  the simulator exited non-zero and wrote no results file and there was nothing to read, while
  the same process had run the same bench successfully three times immediately before. And the
  answer moves even when it succeeds: the low-threshold passgate's `[vth]` reads **0.42189628**
  on one green run and **0.485901** on the next (~15 %) while the ordinary passgate holds to
  four figures — the signature of a bias point with more than one solution, which is what a
  bandgap reference is. Supersedes the header's *"did not reproduce in three runs"*: three clean
  trials is the likeliest outcome at that rate. **Not** issue 1375 (that suite's display-arm
  hang, already filed) and **not** issue 1401.

~~**The next free number is 1401.**~~ superseded: **1401** is filed, above.

~~**The next free number is 1402.**~~ superseded: **1402** is filed, above.

- **1403** — **a hung suite had no upper bound, and T1 had no timeout at all.** On
  2026-09-11 `test_ase_optier_0963` stopped after row N3 on the display arm and sat there
  for **8 h 07 m**, because a stall was the ABSENCE of an outcome rather than an outcome.
  Two holes: `tests/run_regression.tcl` carried no `timeout` on any of its four `exec`
  sites — the one suite whose baseline is ZERO was the one with no bound, display arm
  included — and nothing at all bounds a bare
  `./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl`, which is the
  command typed most often in a session. Two layers landed. **Layer 1**: `t1_timeout`
  (`T1_CASE_TIMEOUT`, default 900 s) prefixes all four sites with
  `timeout --kill-after=20`, inside `devdisplay.sh exec` and not around it, and `t1_why`
  turns rc 124 into a counted FAIL that says `TIMED OUT`. **Layer 2**: a watchdog in
  `tests/headless/scratch.tcl` (169 of 384 suites source it) that exits **124** — the code
  `run_suites.sh` already reads as `TIMEOUT`, so no reader changes — and names the suite
  and its LAST STDOUT LINE, so the message is *"stops after row N3"* rather than *"it
  hung"*. ⚠ **It is NOT a general timeout**: an `after` timer reaches only a hang that gets
  to the event loop (measured: `vwait`/`tkwait` yes — issue 1375's modal — blocking `exec`
  and busy loops no), and **row W13 pins that limitation** so the prose cannot drift from
  the code. `test_suite_watchdog_1403.tcl`, 27 checks, both arms, five sabotage passes.
  Write-up: `doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md`.

~~**The next free number is 1403.**~~ superseded: **1403** is filed, above.

- **1404** — **Stop succeeds silently, and the user goes looking for a rawfile that was never
  written.** Both Stop doors call `ase::ui::do_stop` → `kill_running_cmds $id -9`, and ngspice in
  batch installs a handler for **no signal at all** (`main.c` puts the block inside
  `if (!ft_batchmode)`), so the process dies at the default disposition in milliseconds with
  nothing of the analysis in flight on disk — and the window said none of it. Two sentences now
  say so: one at launch, in the run log header and the CIW, and one at the moment of the Stop,
  **only on the path that actually killed something**. ⚠ **ASE-L owns the FRAME and the ADAPTER
  owns the CLAUSE** — Stage 1's Xyce paper-validation caught the plan asserting a run-model fact
  about ngspice in ASE-L's own voice — so the clause comes from an OPTIONAL `run_stop_cost` hook
  and **a backend that declares none gets no sentence at all**, because a guessed warning is
  worse than silence. `test_ase_core` section SW, 8 rows, floor 258 → 266. ⚠ RG13 does NOT move:
  its fixture runs `simulator holdsim`, which is not a registered backend, so the silence there
  is the adapter scoping working — row SW7 pins it. **Stage 2e of
  `doc/claude/ase_analyses_batch/`**; both sentences are the user's to ratify under ⚖ R9.

~~**The next free number is 1404.**~~ superseded: **1404** is filed, above.

- **1405** — **Stage 1 moved a widget path, and a hundred checks vanished without a red.** Issue 1401 relocated the Choose Analyses quick fields from `$w.<field>` to `$w.form.<field>`. `tests/headless/test_ase_dialogs.tcl` moved with them; `tests/headless/test_ase_persist.tcl` row **G2** did not, because it reaches the same widgets through a VARIABLE (`set w $top.chana` then `$w.$fld`) and the survey behind Stage 1's claim *"no other suite in the tree touches a Choose Analyses quick field by path"* grepped for `chana\.`, which that block never writes. Invisible for **three** independent reasons, all of which had to hold: the whole G-block sits inside an `if {!$mainok}` skip so the HEADLESS arm reports `ALL PASS (44)` with the defect live; `run_regression.tcl` does not run this file on either arm, so T1 at zero said nothing about it; and the raise was swallowed by the enclosing `catch`, taking G3–G11 with it silently. **Measured cost: 100 checks** — display arm 47 before, **148** after. Fixed: the three lines take the `$w.form.` prefix, `ase::ui::chana_show`'s comment is corrected to name **two** suites and to say one of them reaches the path through a variable, and new row **G2p** asserts both halves (new paths present AND old paths absent) so a future move is ONE named red instead of a bare `UNEXPECTED ERROR`. Sabotage-verified: putting the fields back on `$w` reds G2p with exactly the inverse `{0 0 1 1}`.

~~**The next free number is 1405.**~~ superseded: **1405** is filed, above.

- **1406** — **A re-registered backend kept answering from the registry it replaced.** Stage 1 (issue 1401) gave `ase::analysis_types` a memo keyed on the backend NAME and gave it no invalidator: measured, `analysis_cache` has exactly four hits in the tree — declaration, `variable`, read, write — and `ase::sim_caps_clear` does not touch it. So `ase::register_backend` replaces what a backend IS while the answer to *what analyses does it have* goes on coming from the registry that was replaced. It shipped green because the invalidation rule was **"nobody ever does that"** — adapters are first-party and register once at source time — which is the same shape as the eight copies of *what is a `dc` analysis* this batch exists to delete. Found **independently by three** Stage 2 recon crews. Fixed with `ase::analysis_cache_clear`, called from `register_backend` **below** the five-hook `foreach` (row A3 of test_ase_simcaps_0948 reads that loop's source line and would score anything inside it as a sixth REQUIRED hook). ⚠ Its `{}` means EVERY simulator, the opposite of `analysis_types`'s `{}`, because the failure modes are not symmetric — one is a wrong answer, the other is a recomputation. Row **L1** reads the TYPE KEYS, not a count, with a control on a second backend; two sabotages red it `{zzl1a zzl1a OK}`. Floor 110 → 111, and the suite's **first floor paragraph**, which it had never had.

~~**The next free number is 1406.**~~ superseded: **1406** is filed, above.

- **1407** — **ASE-L asked the same question of one dict twenty-eight different ways.** `ase::sim_capabilities`' contract is that a missing key means *not measured*, never *no*, and SIX procs spelled that contract by hand — measured, **28** reads. Every copy is a chance to fuse *nobody asked* with *the answer is no*, which is issue **0953** exactly. Commit C1 of the analyses batch's Stage 2 ships three states as data (`ase::caps_get`), two predicates sharing ONE body so they cannot drift (`caps_is` delegates to `caps_measured_as`), four bands (`caps_keys`, with `defect` shipping EMPTY because a band key with no reader is a key no row can pin), and `unmeasured_keys` wired to the only TWO legs that can be cut without making the whole answer `known 0`. ⚠ `value` is ABSENT rather than empty when unmeasured, so reading it without reading `measured` RAISES in a row instead of fabricating a 0 on a user's screen. ⚠ The predicate follows the DIRECTION OF THE GATE, not the band. ⚠ The comparison is STRING equality — a behaviour change, measured: `appendwrite '0.0'` was a match and is not, and `altshow '1.0'` moves `op_save_tier` from tier d to tier c. `ase::sim_capabilities_at`'s `known` test is a WRITTEN EXEMPTION (the producer's cache-write gate). Floor 111 → 126, eight sabotages. **Row P15 exists only because a sabotage went green**: respelling `cap_report`'s refusal as `![caps_is $c usable 1]` passed all fourteen original rows.

~~**The next free number is 1407.**~~ superseded: **1407** is filed, above.

- **1408** — **ASE-L described a simulator it had never been told anything about.** The Choose Analyses dialog asked `ase::analysis_offered` with NO argument and defaulted `chana_fields`/`arg_summary` to the default simulator, so a bench whose state named a simulator with no adapter was shown **ngspice's four radios, a committable `dc` form and an ngspice DECK LINE in the Arguments column**. The registry was right throughout (`analysis_offered zznoad` answered `{}`); only the dialog never asked it. Ships `ase::ui::chana_sim` (the ONE resolver, six call expressions threaded — the plan said eight, measured six), `ase::analysis_gap_msg` and membership guards on all THREE commit doors. ⚠ The sentence and the empty grid are keyed on the SAME question, or a backend that declares a type and registers none yields a blank, dead, SILENT dialog. ⚠ THREE arms: "not a backend at all" is the LIKELIER case (a typo) and a different fact. ⚠ `[info exists dlg(antype)]` is TRUE for `{}`, which is how `chana_x_ok` wrote `{type {} enabled 0}` into a bench. Floors: core 266 → **273** (section AD, schema half, arm-independent on purpose — T1 runs test_ase_dialogs on NEITHER arm), dialogs display 215 → **224** (G14), headless 37 unmoved. **Two rows exist only because a sabotage went green**, and the first attempt at that sabotage was itself malformed — it broke the proc instead of reverting the guard, which proves nothing.

~~**The next free number is 1408.**~~ superseded: **1408** is filed, above.

- **1409** — **ASE-L never asked the simulator which analyses it has, so the list was a guess.** Deck C gains a per-analysis `help <verb>` plus one `devhelp` — **no new run**, measured 0 ms on all three preflight binaries — publishing `analyses_available`, `analyses_probed` and `devices_available`. The probe token had NO source (Stage 1 deleted `verb` as C41), so `ase::analysis_card_tmpl` returns the emit template row-free; it must NOT go through `analysis_cards`, which RAISES on three of four types when given only a type. Four rules, each measured on all three: the verdict is read from the FILE -- and the measured reason is that deck C exits **0** while a circuit-LESS deck exits **1** and BOTH write their files, so rc tracks whether a CIRCUIT was parsed and says nothing about whether the answers arrived (an earlier draft said "all three exit 1", measured on the wrong deck); a stanza counts on its FIRST TOKEN (`help tf` prints the *tran* bracket AND sentence, so a description match would read `tf` absent on every ngspice ever shipped); the comparison is CASE-INSENSITIVE (`cieq()`); never `help all` (which would accidentally work today, one table edit from load-bearing). ⚠ `pss` on stock-47 is the ONLY reproducible `absent` fixture here — `help sp` answers on all three, so PLAN.md's `--enable-rfspice` example cannot be shown. ⚠ A build whose `spinit` never loaded answers `devhelp` with **52** names against 136/138, so publishing it is a FABRICATED ABSENCE of ~84 device families: the key is withheld and a third provenance token `noinit` records why — grepped, never counted. ⚠ An unknown device family is `unknown`, never `absent` (OSDI appends at LOAD time, so a scratch deck cannot see a PDK's Verilog-A devices). Floor 126 → **141**, eight sabotages.

~~**The next free number is 1409.**~~ superseded: **1409** is filed, above.

- **1410** — **Eleven analyses, each with a state and a reason the user can act on.** Commit C5 of the analyses batch's Stage 2 ships the four-state resolver (`ase::analysis_state` / `analysis_states`), the core availability reader, `ase::requires_state`, the free peek `ase::sim_caps_cached`, `ase::analysis_detect` and the `analysis_caveat` hook; the ngspice registry grows to **eleven**. The honest grid today is **four `ok` and seven `blocked/unrenderable`** — the renderable test sits ABOVE the availability arms deliberately, because offering a type the adapter cannot emit produces a run that emits nothing (issue 1401's silent drop wearing a green cell). ⚠ FIVE reason tokens, and `unmeasured` vs `noprobe` is the pair that ships **a button that lies** if collapsed — `unmeasured` carries Detect, and for a backend with no `capabilities` hook Detect is a PERMANENT no-op. ⚠ An absent `baseline` defaults to **0** (C42's inversion), or every unmeasured capability resolves `ok/baseline` and analyses nobody verified get offered. `state_default` is UNMOVED at four rows, so ⚖ R4's recommended answer ships by construction and the 104 `.state` files round-trip. Floors: core 273 → **289**, simcaps 141 → **148**. Nine sabotages. ⚠ **Four driver errors caught by rows or sabotages**: a `viewrank` on types that can never produce data (D7k red); a `#` comment INSIDE a `dict create` argument list, which is an argument and silently broke `op`; a two-key sort composed backwards so rank was ignored entirely; and the probe skipping all seven types, fixed with a `role probe` card rather than re-adding `verb`. ⚠ **Row U2 took FOUR fixtures** — three looked fine and could not fail.

~~**The next free number is 1410.**~~ superseded: **1410** is filed, above.

- **1411** — **The Choose Analyses grid says which analyses this build can run, and why not.** `$w.types` becomes a wrapping grid, four per row, **eleven** cells for ngspice (not twelve — the options sheet is `$w.opts`, not an analysis type), each carrying its state as a GLYPH. ⚠ A glyph and not a colour because `_theme_widget`'s Radiobutton arm rewrites `-background` and `populate` ends in `apply_theme`, so a per-cell colour is WIPED — row GG4 proves it by setting one and repainting. ⚠ EVERY CELL STAYS SELECTABLE: `invoke` on a disabled radiobutton is a SILENT no-op, so disabling blocked cells would make a hand-edited `{type pss enabled 1}` impossible to turn OFF and would make a future `types.pss invoke` row pass while doing nothing. What is disabled is the **Enable** checkbutton. ⚠ `$w.types.<type>` DOES NOT MOVE (issue 1405's lesson). Detect PAINTS BEFORE IT BLOCKS — up to 31.2 s with Tk frozen — and is offered only where a measurement could change an answer (`unmeasured` or `baseline`, never `noprobe`). Floor: dialogs display 224 → **236**, headless 37 unmoved. Five sabotages.

~~**The next free number is 1411.**~~ superseded: **1411** is filed, above.

- **1412** — **Four defects this ngspice has or has not, measured from files instead of a version string.** Leg D, the last commit of Stage 2. ⚠ This suite's own header records two DIFFERENT builds printing `** ngspice-46+ : Circuit level simulation program` BYTE FOR BYTE, so the variant questions are asked as BEHAVIOUR and the identity keys are display-only (D44). Three Band-3 keys measured 0/1/0 on apt 45.2, the fork and upstream 47: `one_vector_write`, `keyword_case`, `gnd_literal`. ⚠ THE GROUND MARKER IS `@@gref=`, NOT `@@gnd=` — with the old spelling the key SATISFIES ITS OWN SEARCH and the verdict measures nothing. ⚠ The deck asks with `ALL` upper case because `all` SUCCEEDS on apt 45.2, so lower-casing it makes the probe answer 1 everywhere. ⚠ A FOLDER NAME COULD HAVE KILLED THE USER'S RUN: probe text handed to a Tcl LIST command raises on a quote or an unbalanced brace, inside a proc `sim_capabilities_at` deliberately re-raises. Words now come out by regexp; a raise publishes the third provenance token `noanswer`. THREE KEYS DROPPED with reasons: `flags` (half underivable, half a second answer to the same question), `curcasemode_default` (empty on two binaries, one forbidden use, no consumer) and `scripts_path` (empty on all three). Floor 148 → **158**, five sabotages. ⚠ Tcl counts braces INSIDE COMMENTS — an unbalanced one in a comment aborted xschem at startup.

~~**The next free number is 1412.**~~ superseded: **1412** is filed, above.

- **1413** — **T1 was quoted for coverage it did not have.** `run_regression.tcl` ran exactly FOUR `test_ase_*` suites and ran `test_ase_core`, `test_ase_dialogs` and `test_ase_persist` on NEITHER arm — so seven Stage 2 commits reported as *T1 at zero* said **nothing about test_ase_core's 289 checks**, where the registry, the Stop warning and the four-state resolver all live. (Those suites were run separately every time, so the work was verified; the NUMBER was quoted for more than it covered.) ⚠ They could not simply be added: there are TWO completion banners here — `run_suites.sh` takes `RESULT: ALL PASS` or `OVERALL: ok` (0228) while `banner_rule.tcl` takes only `OVERALL: ok`, so a `RESULT:`-only suite is scored a HARNESS failure at ALL PASS, which is issue **0689**'s shape filed four times. ⚠ The RULE was not the thing to change: `simcaps_0948` and `optier_0963` already print both, which is exactly why THEY were in T1. The three suites now emit the second sentinel and join `hcases`. T1 goes **58 → 61 cases, all zero**. They go in `hcases` and not `dcases` because dialogs is 37 headless against 236 on a display — a measurement of a much smaller thing, not a weaker one (issue 1405's lesson).

~~**The next free number is 1413.**~~ superseded: **1413** is filed, above.

- **1414** — **A skipped value would have emitted an empty word and shifted every value after it.** Commit C1 of Stage 3: the slot grammar (`@x` required, `@x?` optional, `@x!` bool), `ase::field_emits`, `ase::analysis_slots` and `ase::analysis_schema_errors`. ⚠ Joining an empty element gives `tran 1n 10u  0.2n` — a DOUBLE SPACE — and ngspice reads the next number as **tstart** rather than tmax: rc 0, no message, a different simulation. ⚠ Row EM1 only works because its fixture puts a literal AFTER the optional slot; trailing, the sabotage is byte-identical. ⚠ MEASURED on both binaries: `uic 0` and `uic=0` BOTH TURN uic ON, so a bool emits the adapter's `when_true` word and never the stored value — and the word is the ADAPTER's, or a simulator needing a word for OFF cannot say one. ⚠ The field table is an OPTIONAL third argument because Q2 of test_ase_simcaps_0948 calls the expander with two and asserts it RAISES. ⚠ `analysis_cards` guards `fields` because SEVEN of the eleven shipped entries carry no such key, and a bare `dict get` would be swallowed by arg_summary's catch into a silently degraded pane — this stage's defect, re-created by its fix. Floor core 289 → **298**, six sabotages.

~~**The next free number is 1414.**~~ superseded: **1414** is filed, above.

- **1415** — **One refusal reader, and the number alphabet the simulator actually reads.** Commit C2 of Stage 3: `ase::analysis_emit_check` (ALL offences, not the first), `ase::analysis_emit_msg`, `ase::si_parse` and a new optional `si_suffixes` hook; the gate refuses an unemittable row ABOVE the `ase_preflight` escape. Every suffix value MEASURED with a value harness: `20mil` → 5.08e-4 (a thousandth of an INCH, a factor of ~39), `1a` → 1e-18, and ⚠ **`1M` → 1e-3 with ZERO warning lines** — `M` is milli, users mean Mega, nine orders of magnitude SILENTLY, so ASE-L warns where ngspice does not (the plan claimed ngspice warns; it does not). ⚠ `x` is deliberately ABSENT: `1x` is **1.0** to ngspice and **1e6** to this repo's own `atof_spice` under the comment *Xyce extension*, so including it would make ASE-L agree with xschem and disagree with the simulator. ⚠ A backend with no table gets NO numeric opinion (`ok`, never `bad`). ⚠ Without its `ase_preflight 0` leg row EK3 is vacuous. ⚠ The clause carries NO frame — EK4 asserts the SHAPE, not two substrings. EK6 is the CORPUS INVARIANT and lands with this commit because it is the one that could make a shipped bench unrunnable. Floor core 298 → **309**, seven sabotages. ⚠ Two driver expectations wrong: `20u` is `1.9999999999999998e-5` (compare numbers as numbers), and `ase_preflight` is already set.

~~**The next free number is 1415.**~~ superseded: **1415** is filed, above.

- **1416** — **A skipped start time let the maximum step be read as one, and the sweep mode was discarded.** Commit C3 of Stage 3: the four field tables (`tran` gains `tstart`/`tmax`/`uic`, `ac` gains `sweep`, `dc` gains its second nest), the POSITIONAL BACK-FILL in `ase::analysis_expand`, the GROUP rule in `ase::analysis_emit_check`, a `dc_swkind` adapter hook, and `chana_ok`'s D6 loop replaced by the one reader. ⚠ 1414 stopped a skipped slot emitting an EMPTY word; it did not stop the value to its RIGHT sliding into its place, and THAT emission has no double space and nothing to notice — `tran 1n 10u 0.2n` reads 0.2n as **tstart**, rc 0, no warning, wrong physics. `whenskipped` lives on the FIELD, so a skipped positional slot emits it whenever anything to its right still emits. ⚠ MEASURED over all 104 tracked `.state` files: **36** dc rows carry `source` and **ZERO** carry `target`, so the plan's `@target` would have raised on every one — the field is `source`. ⚠ The plan's `{tran @step @stop @tstart! @tmax! @uic?}` is `?` and `!` SWAPPED against the grammar 1414 shipped: `!` resolves a non-bool through `field_emits`, which returns the DEFAULT when absent, so a defaulted `tstart` emits `tran 1n 10u 0` for every committed row. ⚠ `dc_swkind` classifies by SPICE device letter because the corpus carries `I0`/`i0`/`i1` across SEVEN rows that "literal temp else source" would mislabel — and `Vres` is a VOLTAGE source containing `res`, so it must be the first character, not a substring. ⚠ The `ac` sweep word was a LITERAL in the template, discarding a stored `oct`/`lin` in silence; `@sweep?` with `default dec` resolves it at emit, so all 104 committed ac rows (none of which carries a `sweep` key) still emit the same five words. ⚠ G2b alone could not have caught the D6 change — it asserts a REFUSAL, and a door that refuses everything satisfies it; **G2c** is the converse row. ⚠ Row **Q1** of simcaps was pinning the whole `dc` template as evidence for a claim about its first word, so it reddened for a reason unrelated to its subject; narrowed to the claim. Floors: core 309 → **333**, simcaps 158 → **164**, dialogs display 236 → **242**. Seven sabotages.

~~**The next free number is 1416.**~~ superseded: **1416** is filed, above.

- **1417** — **The form offered an entry for everything, and said "Points:" for both AC sweeps.** Commit C4 of Stage 3: `chana_field_row` builds each control from its declared `kind` (bool → checkbutton, mode → readonly combobox, else entry), `form_label` puts the declared label AND ITS UNIT on it, `chana_mode_changed` relabels a mode field's declared neighbour, and `chana_adv_toggle` hides the optional fields behind `▸ Advanced`. New: `chana_form`, `form_has`, `form_get`, `form_is_absent`, `dialog_status`. ⚠ `dec 10` is ten points PER DECADE, `lin 10` is ten IN TOTAL and `lin 2` yields ONE — the form said `Points:` for all three. ⚠ THE WRITE-BACK RULE IS A BYTE-IDENTITY RULE, measured the hard way TWICE inside this commit: a checkbutton answers `0` where an untouched entry answers empty, so the door stored `uic 0`; a combobox answers `dec` where a bench stores nothing, so it stored `sweep dec`. NEITHER key changes a deck line and BOTH break the 104-bench round trip the first time a user presses OK. "Absent" is per field: empty for text, OFF for a bool, THE DECLARED DEFAULT for anything that has one. ⚠ The refusal now appears IN THE DIALOG and focus lands on the offending widget — measured, there was no `focus` call anywhere in `choose_analyses` or any proc it calls, and the sentence went only to the action log, which lands in ANOTHER WINDOW, so OK "did nothing". ⚠ It does NOT rebuild the form to reach a hidden field: `chana_show` destroys every widget, so opening the disclosure there would DISCARD what the user typed in order to show them what was wrong with it. ⚠ The relabel runs at BUILD time too, or the form opens reading `Points per decade` for a bench that stored `lin`. ⚠ The disclosure TOGGLES and is remembered for the window — two of this commit's own fixtures assumed a fresh dialog is closed and were wrong. Floor: dialogs display 242 → **254**.

~~**The next free number is 1417.**~~ superseded: **1417** is filed, above.

- **1418** — **Options collected settings, round-tripped them, and never emitted them.** Commit C5 of Stage 3: `analysis_emit_check` gains an `unknownkey` offence, and `chana_x_add` / `chana_x_ok` refuse a name nothing can spend. ⚠ THE DEFECT THE WHOLE STAGE IS NAMED FOR, and the editor's own header comment admitted it: *"DECK emission of extra keys stays deferred (v1 limit, documented here)"*. Measured end to end: type `uic 1`, `tstart 5u`, `tmax 1n` into a tran row, see all three confirmed in the pane, and the deck says `tran 10n 200u`. ⚠ REFUSED AT `Add`, not only at OK — a pair the user has watched land in the list is a pair they believe they have set. ⚠ AND AGAIN AT OK, because `anextra` is seeded from the STORED row, so a bench written by an older ASE-L would otherwise be laundered through a door that refuses it at the front. ⚠ Refusing is safe and that was MEASURED FIRST: across all 104 tracked `.state` files and all 416 rows the key sets are `{type enabled}` plus declared field names and nothing else — zero rows carry a key this rejects (section CP). ⚠ **G2j exists so a sabotage can tell "closed the door" from "broke the editor"** — a refusal that rejected EVERY name satisfies G2i perfectly. ⚠ G2k plants the key in the state because `Add` can no longer create one, which is also the real-world case. Floors: core 335 → **337**, dialogs display 261 → **265**.

~~**The next free number is 1418.**~~ superseded: **1418** is filed, above.

- **1419** — **The one escape from a typed form that actually emits.** Commit C6 of Stage 3: the `x` verbatim hatch — a list of lines placed into `.control` immediately above that row's OWN analysis. `ase::analysis_verbatim` (one reader, never raises), a `verbatim` offence in `analysis_emit_check`, and `+ verbatim: <n> line(s)` in the Arguments column. ⚠ EVERY ESCAPE THIS STAGE INHERITED WAS A LIE: `Options…` collected pairs, round-tripped them and emitted nothing (1418), and the Arguments column is what made the lie convincing. ⚠ `x` is a ROW KEY, NOT A FIELD, and the distinction is load-bearing — a field no template spends is exactly what `analysis_schema_errors` refuses, so declaring it a field would make the registry self-inconsistent by its own rule. ⚠ ABOVE ITS OWN ANALYSIS, not at the top of `.control`: a deck with three enabled analyses would otherwise apply one analysis's setup to all three, silently, in run order. ⚠ A malformed list and a BLANK line are both refused — an escape that cannot be wrong is an escape nobody can trust — while the reader itself never raises, because two of its three callers swallow or die on a raise. ⚠ The column shows a COUNT: pasting three control lines into a one-line cell pushes the analysis line off the edge, but staying silent means the user runs something they cannot see. ⚠ **VB3's first draft pinned a whole deck against section D's and failed on the `write` line's RAW-FILE PATH** — D renders before a later fixture moves the rundir into scratch. A row pinning a whole deck across a long file is really pinning every fixture between the two points. Floor: core 337 → **343**.

~~**The next free number is 1419.**~~ superseded: **1419** is filed, above.

- **1420** — **The Arguments column listed values the deck would never carry.** Commit C7 of Stage 3, the LAST one. ⚠ The OTHER half of the batch's acceptance criterion: an ENABLED row that cannot render had its keys dumped into the column as `step=1n stop=10u`, which reads exactly like a setting in force, in the one column whose job is to say what the deck carries. It now gives the REASON, in the identical clause the commit door and the gate use — three surfaces, one vocabulary, because a pane and a dialog disagreeing about why a row will not run leaves the user unable to tell which is wrong (row AC2). ⚠ ONLY for an enabled row: `state_default` seeds every new bench with THREE empty disabled rows, each of which would otherwise open wearing a complaint about a value nobody has been asked for. ⚠ A probe-only type says it cannot be set up rather than naming a missing value — seven of eleven registered types have no field to hunt for. ⚠ AND A COMMENT THAT WAS THE DEFECT, WRITTEN DOWN AND SHIPPED: `chana_options`' header ended *"DECK emission of extra keys stays deferred (v1 limit, documented here)"*. ⚠ Two rows failed first time on Tcl LIST QUOTING, not on the code — expectations that compare as lists are now built with `[list …]` on both sides. Floor: core 343 → **348**. **Stage 3 complete: 1414–1420.**

~~**The next free number is 1420.**~~ superseded: **1420** is filed, above.

- **1421** — **The preflight suite was never in T1, and 21 more ASE suites are not either.** Commit C1 of Stage 4, landing before the stage's own subject because Stage 4 ADDS ITS ROWS to `test_ase_preflight.tcl` — 125 checks of the refusal standing between a user and a raw file of twelve mathematical constants, which `run_regression.tcl` had never run on either arm. Adding rows to a suite T1 does not run would be issue **1413** happening a second time. ⚠ TWO HALVES: the suite printed `RESULT:` and no `OVERALL:`, so `banner_rule.tcl` would score it a HARNESS FAILURE at ALL PASS; and it called `exit 0` UNCONDITIONALLY, discarding one of the three independent signals a case passes on — its whole body sits in a `catch` that prints `FATAL:` and increments `fail`, so a fatal error could print, be counted, and still leave the process claiming success. Both fixed; T1 **61 → 62 cases**. ⚠ AND THE AUDIT IS THE OPEN PART: measured across all **29** `test_ase_*` suites, only **7** were in T1 (8 with this one). The other **21 all print `RESULT:` and no `OVERALL:`** — one cause, twenty-one times — including `test_ase_cosim` at 341 checks and `test_ase_window` at 295. They must be measured standalone and added in bounded batches, NOT in one commit: a suite that has never been in T1 has never had its first run under the driver walked, which is exactly how `test_ase_optier_0963`'s display arm cost eight hours. **Any "T1 at zero" claim covers eight of twenty-nine ASE suites and no more.**

~~**The next free number is 1421.**~~ superseded: **1421** is filed, above.

- **1422** — **The tokens `netlist_map` throws away are exactly the ones a precondition needs.** Commit C2 of Stage 4: `ase::netlist_facts` — a SECOND pass over the same text, returning `sources` (scope/letter/ac/dc/portnum/z0/distof1/distof2/trnoise), `families`, `events`, `models`, `nodes` and `exact`. ⚠ `netlist_map` drops EVERY token containing `=` and every dot-card but four, which is right for "does this node exist" and makes it structurally unable to answer "does this source carry an AC magnitude". Row PF223a asserts BOTH halves so the passes cannot silently become redundant. ⚠ CORE, not adapter: it reads the netlist XSCHEM emits, and the device-letter convention is xschem's. ⚠ A BARE `ac` WITH NO MAGNITUDE IS STILL acGiven, magnitude 1 — requiring a number reports "no AC source" for a deck that has one, the false refusal this pass exists to avoid. ⚠ The continuation fold must be byte-identical to netlist_map's, because a source's `ac 1` usually lives on a `+` line; PF223j pins that both passes see the same scopes. ⚠ A bare third-position value is a DC value — `V9 TOPNET 0 1` is the commonest card in the repository. ⚠ An unknown device letter is RECORDED under its own letter: a family nothing recognises is a caution, never a block, and a caller cannot caution about one this pass dropped. ⚠ `exact 0` is part of the ANSWER — it cannot see inside an `.include`, so static WARNS and only an exact leg blocks. ⚠ `events` holds NODES; an event MODEL name in it would make "is this node an event node" true for a string that is not a node (wrong in the first draft, PF223h is why it is not now). Floor: preflight 125 → **135**, eight sabotages.

~~**The next free number is 1422.**~~ superseded: **1422** is filed, above.

- **1423** — **Preconditions become filters, not error messages.** Commit C3 of Stage 4: `ase::analysis_needs` evaluates a type's declared `needs` ids against `netlist_facts` and returns `{id verdict sentence fix}`; `ase::needs_eval` is the per-predicate body; `analysis_precheck` covers every ENABLED analysis; `precheck_worst` is the ordering, written once. Three predicates — `ac_source`, `sweep_target`, `cider_klu` — chosen because they are the three reachable today (noise/disto/sp stay probe-only until Stage 6, so a `needs` on them would be unreachable code with an unreachable test). ⚠ THE GOVERNING RULE IS THAT A FALSE REFUSAL IS WORSE THAN A MISSED ONE: `netlist_facts` answers `exact 0`, so every `blocked` on a static pass is DEMOTED to `caution` and the sentence says the pass could not see inside an `.include`. The demotion lives in ONE place so a predicate author writes the honest verdict and the evaluator lowers it. `fatal` is never demoted — ngspice `exit(1)`s on CIDER-under-KLU, so the rest of `.control` never runs. ⚠ THREE SHAPES THAT WOULD EACH HAVE BEEN A FALSE REFUSAL: the CIDER/KLU pair needs BOTH halves (firing on the device alone refuses every deck the feature exists for); `temp` is a legal sweep target naming no instance; and an UNIMPLEMENTED precondition id is SATISFIED, because a registry naming one nobody wrote must not block a run. ⚠ ONE SABOTAGE SURVIVED AND ITS REPAIR IS THE LESSON: swapping `fatal` and `blocked` in `precheck_worst` passed everything, because every fixture yielded findings of exactly ONE severity — with a lone fatal, any ordering returns fatal. **An ordering row whose fixtures never disagree is a row that cannot fail.** Floor: preflight 135 → **144**.

~~**The next free number is 1423.**~~ superseded: **1423** is filed, above.

- **1424** — **A precondition that destroys the run is a refusal.** Commit C4 of Stage 4: `preflight_gate` refuses on a `fatal` precheck verdict in a block ABOVE the `ase_preflight` escape, and `render_deck` re-checks before it builds a single line — the plan's second and third refusal tiers. ⚠ `fatal` IS NOT A STRONG `blocked`: caution and blocked mean "this run will be less useful than you think"; fatal means the simulator will not reach the end of `.control`. Measured: CIDER under KLU makes ngspice `exit(1)`, so every later analysis silently does not happen and the run directory holds a PARTIAL RAW FILE THAT READS BACK AS A VALID RESULT. That is why it sits above the escape — `ase_preflight 0` is a judgement call about a warning, not a way past a silent wrong answer. ⚠ AND THE GATE MAY ONLY SLAM FOR `fatal`: a caution or a blocked belongs in the WINDOW next to the control that causes it (PF225e pins that a deck with no AC source goes through). ⚠ ONE SABOTAGE SURVIVED MY OWN ROW AND WAS CAUGHT BY TWO OLDER ONES — making render_deck refuse on ANY verdict left PF225d green, because its fixture had NO FINDING AT ALL and could not tell "refuses fatal" from "refuses anything"; it reddened PF221al/PF221an instead. The row now renders a deck carrying a real caution and requires it through: a warning the user can act on is not a reason to refuse to write their deck. ⚠ And a first draft referencing a fixture defined LOWER in the file surfaced as `FATAL: can't read "KNOAC"` rather than a located failure — this suite wraps its whole body in one `catch`. Floor: preflight 144 → **149**.

~~**The next free number is 1424.**~~ superseded: **1424** is filed, above.

- **1425** — **The precondition is said before the run, with its remedy.** Commit C5 of Stage 4, the last one. `preflight_gate` emits every non-`fatal` precheck finding BEFORE the run: `ase: the ac analysis: this circuit has no AC source … Fix: put \u0060ac 1\u0060 on the input source`. ⚠ ngspice's own answer to the same condition is `E_NOACINPUT` AFTER the run, in a log the user has to go and read. ⚠ ADVICE, NOT A REFUSAL — the gate still returns {}; a caution is the user's call by definition, which is why a static pass demotes `blocked` to `caution` at all. ⚠ AND IT SITS ABOVE THE ESCAPE: `ase_preflight 0` turns off a REFUSAL, it is not a request to be told less about a circuit. ⚠ WHERE THE BANNER IS NOT: the plan asks for it under the FORM, but `netlist_facts` needs netlist TEXT and the dialog has none — producing it means `ase::netlist`, which loads designs and writes artifacts, a side effect no dialog may have because a user opened it. Deferred to Stage 6, where a cached artifact can be read without generating one. ⚠ AND THE DISTO SAVE-LIST RULE IS UNREACHABLE TODAY: it promotes `saves_resolve` to fatal WHEN `disto` IS ENABLED, and `disto` is probe-only until Stage 6, so an enabled disto row is refused by issue 1401's block long before a precondition is consulted. Named rather than faked. Floor: preflight 149 → **152**. **Stage 4 complete: 1421–1425.**

~~**The next free number is 1425.**~~ superseded: **1425** is filed, above.

- **1426** — **The transfer function was listed and could not be chosen.** The `tf` commit of Stage 5 (`pz` and `sens` are separate commits). `tf` was `registered 1` with a `role probe` card and nothing else, so the grid showed it exists and `analysis_renderable` answered 0; it now carries `emitorder 50`, two fields (`out`, `insrc`), a `role analysis` template, a `results`/`plots` destination and two preconditions. ⚠ THE MEASUREMENT: ngspice CHECKS the input source and aborts (`Transfer function source r1 not of proper type`, rc 1) and does NOT check the output at all — `tf v(nosuchnode) V1`, `tf v(in,nosuch) V1`, `tf i(R1) V1` and `tf i(nosuchsrc) V1` are all rc 0 with three plausible numbers and a vector named after the thing that is missing. ⚠ THE STATIC DEMOTION IS RIGHT FOR ONE FINDING IN THIS PREDICATE AND WRONG FOR ANOTHER: a missing node is `blocked`→`caution` with the `.include` caveat, a malformed output is `fatal` and carries none, because no include can make `v mid` legal — and measured with this tree's own `sim_status` guard, `tf x(mid) V1` fires `quit 1` while `tf v(nosuchnode) V1` reaches the end. ⚠ FOUR PLAN CORRECTIONS: `{build <proc>}` (PLAN §1c) was never implemented by Stage 1, so an emitted token is one field and `tf` ships two, not five; `viewrank 0` is refuted — measured, `xschem raw read <file> tf` finds nothing because `save.c`'s `read_dataset()` has six named `Plotname:` arms and then an exact `strcmp`, so a viewrank would open the viewer on nothing while `plot_sim_type_reason` reported a mapping; only ONE of the three vector names is a constant (the other two carry the row's own source and node, FOLDED to lower case even on the case-preserving fork), so `plots`' `vectors` names a proc; and the capitals are the FORK's — apt 45.2's rawfile writes `v(transfer_function)` / `v(v1#input_impedance)`, so a case-sensitive reader is wrong on the binary a downloading user has. No `seed_enabled`, so the 104 committed `.state` files are untouched. Floors: core 348 → **360** (section TF), simcaps 164 → **170** (section TV), preflight 152 → **164** (section PF227).

~~**The next free number is 1426.**~~ superseded: **1426** is filed, above.

- **1427** — **The pole-zero analysis was listed and could not be chosen.** The `pz` commit of Stage 5 (`tf` is 1426; `sens` is separate). `pz` was `registered 1` with a `role probe` card and nothing else; it now carries `emitorder 60`, six fields (four `kind node` boxes and two `kind mode` pickers), a `role analysis` template, a `results`/`plots` destination and FOUR preconditions. ⚠ THE MEASUREMENT: a device whose model declares `.DEVpzLoad = NULL` is SKIPPED by `cktpzld.c:29` and nothing at all is said — measured on both binaries, the same two-pole RC with a `Y` (TransLine) or `P` (CplLines) line hung off a node gives **byte-identical roots at rc 0** to the deck with the line deleted, while `T`, `O` and `U` abort at rc 1. ⚠ AND `PZinit`'s TRANSMISSION-LINE CHECK CANNOT FIRE FOR AN LTRA: `pzan.c:96-106` stops at the first NAME that is a compiled-in device type rather than the first with instances, so on any build with `tra` compiled in the LTRA arm is never reached — measured, an O-card deck does not print `Transmission lines not supported` and a deck with a T card AND an O card does. ⚠ THE STATIC DEMOTION'S THIRD CASE, which neither 1423 nor 1426 had a name for: a finding of the form "this deck CONTAINS X" is PROVED by the static pass, because an `.include` can only ADD devices and never remove the card just read, so it carries no `.include` caveat in either direction (row PF228h). ⚠ FOUR PLAN CORRECTIONS: `{build <proc>}` buys `pz` nothing (six separate tokens, so four node fields ARE the four node tokens — the escape Stage 1 never shipped was never needed here); `pzan.c:92-128` is cited for a guarantee it does not give; `plots`' vector key names a READER and not a predictor, because `pole(1)…pole(n)` has an `n` the root finder decides — measured, the same row that gives two poles gives ZERO zeros at rc 0; and 1426's capital-folding warning does NOT reach `pz`, whose names are built by `sprintf("pole(%-u)")` and are byte-identical in both binaries' rawfiles. ⚠ AND `viewrank` IS REFUTED AGAIN with a second reason: `xschem raw read <file> pz` finds nothing, AND a pz plot is a root list — `Flags: complex`, NO SCALE VECTOR — so even a mapping would open the waveform viewer on something that is not a sweep. The `keepopinfo` plot's upstream mislabel `Distortion Operating Point` (`pzan.c:52-61`) is carried verbatim, measured on both binaries. No `seed_enabled`, so the 104 committed `.state` files are untouched. Floors: core 360 → **376** (section PZ), simcaps 170 → **175** (section PV), preflight 164 → **177** (section PF228), dialogs `:99` 271 → **278** (section G2pz, headless 37 unmoved). ⚠ SEVEN EXISTING `test_ase_core` ROWS MOVED rather than being added, all named in that file's floor paragraph: AG1/AG2, EM7/CP6, GR8 (the new declared kind `node`), TF3b and D7e3 (both used `pz` as their unrenderable control).

~~**The next free number is 1427.**~~ superseded: **1427** is filed, above.

- **1428** — **DC sensitivity was listed and could not be chosen.** The `sens` commit of Stage 5 and the last of it (`tf` is 1426, `pz` is 1427). `sens` was `registered 1` with a `role probe` card and nothing else; it now carries `emitorder 70`, two fields (`out`, and a new `kind filter` box), a `role analysis` template `{sens @out @filters? dc}`, a `results`/`plots` destination and THREE preconditions. **DC ONLY — the `ac` mode is Stage 6's**, and that is the SHAPE CHANGING rather than work postponed: both AC defects were re-measured on both binaries (`sens … ac lin 5 1k 5k` sweeps 1e3 / 8e5 / 6.4e8 / 5.12e11 / 4.096e14, each ×800, from `inc_freq` testing `noisedef.h`'s `#define LINEAR 3` instead of `SENS_LINEAR`; `.options klu` + AC sens is rc 139 on both, from the guard at `cktsens.c:97-105` being COMMENTED OUT) and NEITHER reaches DC — `count_steps`' `SENS_DC` arm returns n=0/s=0 so `inc_freq`'s value is never used, and DC under KLU is rc 0 with numbers BYTE-FOR-BYTE the sparse ones. So neither of PLAN.md's two `rules` ships: the plan needs a `rule` only because `@modeargs` is a FREE SLOT, and this entry's mode is the LITERAL token `dc`, so Stage 6 can declare the sweep field `values {dec oct}` and make the restriction a FIELD CONSTRAINT the form cannot offer. ⚠ THE MEASUREMENT: ngspice does not validate the output and fills a ~90-row table anyway — `sens v(nosuchnode) dc`, `sens i(R1) dc`, `sens i(C1) dc`, `sens i(L1) dc`, `sens i(I1) dc` and `sens i(nosuchsrc) dc` are all rc 0 with EVERY vector zero, and `sens v(in,nosuch) dc` silently takes ground as the reference. ⚠ AND A FILTER THAT MATCHES NOTHING LEAVES THE RUN WITH NO PLOT AT ALL: measured on both binaries, `sens v(mid) nosuch dc` gives `$plots = const` at rc 0, and followed through this tree's own `render_deck` the raw file's only record is `Title: Constant values / Plotname: constants / No. Variables: 12` — the twelve-mathematical-constants artifact `test_ase_preflight.tcl` exists for, reached from a new direction, and defence (c) catches it while blaming a `.save`. ⚠ FOUR PLAN/APPENDIX CORRECTIONS: `{build <proc>}` is NOT built and the reason is a measurement rather than the cost (`out_decompose`, shipped by 1426 as a registered hook, already takes `v(a)` / `v(a,b)` / `i(src)` APART, so the structured data is recoverable from the one verbatim token and composition buys nothing); `sens_params` is not a condition this tree can reach (a deck whose only devices are a `V` and a `B` source still yields ten vectors — the only empty plot measured comes from a dead filter, which is `sens_filters`); APPENDIX §2.10's three-row naming table is a FLAT-DECK measurement, and a subcircuit device's vector is `<letter>.<instance path>.<name>` — measured, `V1/X1/R9` with `Ra`,`Rb` inside a subckt yields exactly `r.x1.ra r.x1.rb r9 v1`, so the filter check is keyed on the TOP scope; and §2.10's "write filters lowercase" is exactly backwards under the fork's `casemode=preserve` (`R1` matches, `r1` gives NO PLOT) and irrelevant under every other casemode. ⚠ AND THE UNDERSCORE FORM COLLIDES IN ngspice ITSELF: a deck carrying `R1` and `R1_temp` puts the vector name `r1_temp` in the plot TWICE, so `sens_param_kind` splits the colon and refuses to split the underscore. `viewrank` refuted a third time, with two new reasons (no scale vector; `Sensitivity Analysis` is the plot name of BOTH modes). No `seed_enabled`, so the 104 committed `.state` files are untouched. Floors: core 376 → **391** (section SE), simcaps 175 → **180** (section SV), preflight 177 → **192** (section PF229), dialogs `:99` 278 → **285** (section G2sens, headless 37 unmoved). ⚠ FIVE EXISTING `test_ase_core` ROWS MOVED — AG1/AG2 (the split goes to seven and `sens` overtakes `noise`), EM7/CP6 (four probe-only types now) and GR8 (the new declared kind `filter`) — and TWO THAT WERE EXPECTED TO MOVE DID NOT: `pz`'s commit had already moved TF3b and D7e3 off `pz` to `noise` and `noise`+`pss`, neither of which names `sens`.

~~**The next free number is 1428.**~~ superseded: **1428** is filed, above.

- **1429** — **The Outputs Value column could not see three analyses' answers.** The first commit of Stage 6 and ⚖ R3's reader seam ONLY — no writer, no sidecar, no reconciliation, no new analysis type, no salvage. ⚠ **⚖ R3 IS ASKED AND UNANSWERED**: what ships is `DECISIONS.md`'s RECOMMENDATION, Option **C** (named vectors from the results file, arbitrary expressions from the print log), marked as a recommendation in the issue file, the code comments, four suite headers and the receipt; `DECISIONS.md` records R3 as EXTENDING the user's own ruling in issue **1243**, not reversing it. ⚠ THE MEASUREMENT, and it REFUTES `PLAN.md` §6e's stated reason: §6e says reading the raw *"removes `result_probe`'s case-folding ladder"* — it does not, the raw needs a fold of its own because the fork writes `v(Transfer_function)` where apt 45.2 writes `v(transfer_function)`. The real reason is one plot deeper: `print` reads WHICHEVER PLOT THE SIMULATOR IS STANDING IN, and 1243 anchors the prints on the operating point, so measured on one deck with the prints exactly where `render_deck` puts them, `print v(mid)` answers `1.500000e+00` and `print Transfer_function`, `print onoise_total` and `print r1` produce **NOTHING AT ALL — no value, no warning, no error line**, while all three vectors sit in the results file. ⚠ WHAT THE VALUE COLUMN SHOWS WHEN A RUN COMPUTED NOTHING: **NOTHING** — measured on both binaries and reproduced independently by the driver, a `sens` filter matching nothing and a save list resolving to nothing BOTH exit 0 and write a file whose only record is `Title: Constant values / Plotname: constants / No. Variables: 12`, so `ase::raw_scalars` excludes that plot BY NAME. A reader that took "no vector" for zero would print a number for a run that computed nothing, and **`i` is one of those twelve constants**; that the plot is also `Flags: complex` is a SECOND, ACCIDENTAL guard, and a sabotage proved the accidental one was carrying the deliberate one (rows RD5c, RV3b). ⚠ AND THE READER NEVER FALLS BACK TO THE LOG: a single-vector row whose vector is absent has no value even when the log has one for it (row RD12), because a fallback would make the on-screen rule false and would make a later ruling of A two changes instead of one. ⚠ SEPARABILITY IS THE PROPERTY THAT LETS AN UNRATIFIED RECOMMENDATION SHIP: the rule lives in ONE proc, `ase::result_source`, whose body becomes `return raw` under ruling A (deleting `result_probe_log`) or `return log` under ruling B (deleting `result_probe_raw`, `raw_spellings`, `raw_scalar_format` and `ase::raw_scalars`); neither reader calls the other, and row **RS3** PERFORMS both rulings by stubbing that proc, with a fixture log deliberately carrying a DIFFERENT number from the results file so the row can say WHICH READER ANSWERED. ⚠ `%.6e` OF THE RAW VALUE IS `print`'S OWN ECHO BYTE FOR BYTE (`1.285714285714286e+00` → `1.285714e+00`), so C gives a number to rows that had none and changes no row that had one. ⚠ AND A PARENTHESIS THE RULE DID NOT PUT THERE IS AN EXPRESSION: `abs(v(mid))` and `output_impedance_at_V(mid)` are the same string shape and no string test tells them apart, so both read the log — the direction that loses nothing, since `abs(v(mid))` and `v(a)*2` are what Option B exists to protect. `@dev[param]` and `a[0]` stay on the log too, on issue 0167's own measured ground (a bracket is a SUBSCRIPT to ngspice's expression parser). New: core `ase::raw_scalars` and `ase::result_source`; adapter `result_probe_raw`, `result_casemode`, `raw_spellings`, `raw_scalar_format`; `result_probe` renamed to `result_probe_log` and a new `result_probe` dispatcher. `src/ase_window.tcl` untouched, no registry key added, no deck golden moved, no `seed_enabled`, 104 committed `.state` files byte-identical. Floors: core 391 → **417** (sections RS, RD), simcaps 180 → **190** (section RV), result_case 28 → **31** (section NCR), print_bracket 12 → **14**. ⚠ NOT ONE EXISTING ROW MOVED in any suite on either arm — but `test_ase_result_case.tcl` and `test_ase_print_bracket_0167.tcl` now drive `result_probe_log` BY NAME, a ONE-LINE swap in each, which is itself the evidence for the separability claim.

~~**The next free number is 1429.**~~ superseded: **1429** is filed, above.

- **1430** — **Two sensitivity plots in one results file, and nothing said which row wrote which.** The SECOND commit of Stage 6 — the writer, the sidecar and reconciliation (`PLAN.md` 6a/6b/6c) — and nothing else: no `noise`/`disto`/`sens (ac)` (6d), no checkpointed salvage (6f), no variant mitigations (6g), `src/ase_window.tcl` untouched. ⚠ THE DEFECT, MEASURED ON BOTH BINARIES: two enabled `sens` rows write two plots and **both are called `Sensitivity Analysis`**, and the plot literal cannot separate them even in principle — two DIFFERENT analyses already share that name (`sens … dc` and `sens … ac`, APPENDIX §0.7). Write order is not an answer either: it is `ase::analysis_emit_order`'s rank, which moves under 0964's `op`-last variant. The fix is a **sidecar**, `<rundir>/<cell>_ase.plotmap`, one `echo "PLOT <type> <row index> |$curplotname|" >> …` record per `write`, 1:1 with the results file's `Plotname:` records and **carrying the ROW INDEX**, which is the only thing that separates two rows of one type. ⚠ AND "ONE ANALYSIS, ONE PLOT" IS WRONG, measured per analysis on both binaries: under `.options keepopinfo`, `ac` writes `AC Analysis` **+ `AC Operating Point`** and `pz` writes `Pole-Zero Analysis` **+ `Distortion Operating Point`** (upstream's copy-paste, carried verbatim) — while **`tf` and `sens` write NOTHING extra, which REFUTES `PLAN.md` §6**'s list of the types `keepopinfo` prepends an operating point to. ⚠ AND THE `opinfo` COMPANION IS PREDICTED BUT **NOT CAPTURED**, which REFUTES `PLAN.md` 6a: `src/save.c`'s `read_dataset()` matches `strstr(lowerline, "operating point")` BEFORE its AC arm, so every `… Operating Point` plot reads back as `op` — measured on a file holding the companion AND the real operating point, made to disagree by an `alter`, `xschem raw read <file> op` answers `datasets=2` and `xschem raw value v(mid) 0` → **1**, the AC operating point, where the real one is **0.5**. Capturing it would make Annotate Operating Point publish the wrong numbers onto the schematic, and ASE-L cannot filter it on the read side because the match is in C over the whole file; the companion needs a results file of its own, which is not this commit. ⚠ THE OVER-WALK IS SILENT AND COUNTING CANNOT SEE IT: `setplot previous` past the first plot does NOT fail, it **saturates on the built-in `constants` plot** (`Warning: No previous plot is available…`, on **stderr**, where nothing in this tree looks) and the next `write` appends ngspice's twelve constants under a perfectly plausible record — record count, plot count and prediction all AGREE, and only the registry's own `select` disagrees, which is why `ase::reconcile_plots` has a `mislabel` arm (row RC5) beside `under`/`over`/`nomap`/`predmismatch`. ⚠ `under` IS THE CASE THAT IS SILENT TODAY: ngspice's `write` aborts SILENTLY when a zero-length vector survives into the plot, so a run exits 0 with the results file one plot short and nothing anywhere notices. ⚠ THE `plots` REGISTRY KEY STOPS BEING DECORATION: declared by four entries through Stages 1–5 and read by NOTHING (issue 1428's S35 class), it is now read by the writer and the reconciliation and REFUSED four ways by `ase::analysis_schema_errors` — `noplots`, `noplotselect`, `noplotrole` and `badplotwhen`, the last being the dangerous one because an unreadable `when` makes both consumers exclude the plot silently at rc 0. New core: `ase::plotmap_path`, `plotmap_record`, `plotmap_parse`, `plotmap_read`, `option_enabled`, `plot_when_valid`, `plot_when`, `analysis_plots`, `plot_capturable`, `analysis_captures`, `analysis_uncaptured`, `plot_select`, `reconcile_plots`, `reconcile_report`; one registry row (`ac`'s `AC Operating Point`); the sidecar joins `render_deck`'s write block and `ase::run_deck`'s pre-run delete; `ase::run_done` gains one caught report. ⚠ **ONE DECK GOLDEN MOVED AND IT IS THE ONLY ONE IN THE TREE: `test_ase_core.tcl`'s D1** (with C4/C5, which compare against it) — every other suite is byte-unmoved on both arms. No `seed_enabled`, four seeded rows, 104 committed `.state` files byte-identical. Floors: core 417 → **453** (sections PM, GP, WK, RC), preflight 192 → **194** (PF218f2/f3), optier 103 → **105** (E5b/E5c). ⚖ **R3 is untouched and still unanswered**; ⚖ R9 owes four new sentences.

~~**The next free number is 1430.**~~ superseded: **1430** is filed, above.

- **1431** — **A co-simulation golden has been one nanosecond stale, and no T1 run can see it.** Row **GE24-matches-the-golden** of `tests/headless/test_cosim_golden_e2e.tcl` fails with six differences that are all the SAME three signals at the SAME values, one nanosecond later than the golden records them (`TOP.counter.next_count` / `.phase` / `.prev`, **1950011 → 1950012**). ⚠ **IT IS DETERMINISTIC AND IT IS NOT A FLAKE**: three consecutive `run_suites.sh --nogui` runs gave byte-identical differences, so this is a DIFFERENT defect from issue **1402**'s bandgap non-determinism, which flaps under load — and re-running is not a fix. ⚠ **AND IT IS OLDER THAN THE COMMIT THAT FOUND IT, MEASURED RATHER THAN ASSUMED**: the suite calls `ase::backend::ngspice::render_deck` directly (`test_cosim_golden_e2e.tcl:322`), so issue **1430**'s sidecar work COULD have reached it and "pre-existing" could not be taken on anyone's word. Re-measured in a detached worktree at **`595ab274`** — the commit before 1430 — carrying the working tree's OWN compiled `src/xschem`, because 1430 is a Tcl-only change and copying the binary isolates `src/ase.tcl` as the single variable and rules out the stale-binary trap `CLAUDE.md` warns about. The answer came back identical: same row, same six differences, same timestamps. **1430 is innocent and the golden is stale.** ⚠ **WHY NOBODY NOTICED: `test_cosim_golden_e2e` IS NOT IN `tests/run_regression.tcl`.** It is one of issue **1421**'s twenty-one suites outside T1, and it prints `RESULT:` but no `OVERALL:`, so T1 cannot count it. **T1 is honestly at zero and this red is real at the same time** — precisely the hole 1421 exists to name. It also had NO issue file: `grep -rl GE24 doc/claude/issues/` returned nothing before this one, so `CLAUDE.md`'s *a standing red is a defect, not furniture* had been satisfied by invisibility rather than by anyone waving it through. ⚠ **WHAT IS DELIBERATELY NOT DECIDED HERE: whether the golden or the current behaviour is right.** A one-nanosecond VCD shift is equally consistent with a stale golden, a changed time base, a changed rounding rule and a corrected off-by-one. The suite's entire history is two commits, `c2d775ef` (added) and **`9be9c2d5` (*"the six clean auto-merges that were nonetheless wrong"*)** — which is itself a reason to read that merge before assuming the golden is merely old. **DO NOT re-baseline the golden to make it green**: promoting a baseline without deciding which side is correct converts an open question into a silent claim, and this file exists because the question was invisible long enough to become furniture once already.

~~**The next free number is 1431.**~~ superseded: **1431** is filed, above.

- **1432** — **Three analyses wrote more plots than ASE-L could keep, and one of them crashed the simulator.** Stage 6d of `doc/claude/ase_analyses_batch/`: `noise`, `disto` and `sens`'s **AC** mode were registered probe-only, so the three types that produce more than one plot per analysis were the three a user could not run — and issue **1430**'s `setplot previous` walk shipped **with no production exerciser**, by its own correction C64. ⚠ **FOUR MEASURED REFUTATIONS, each on the fork AND on apt 45.2.** (a) `PLAN.md` 6b's `when {expr {start ne stop}}` for `Integrated Noise` is WRONG in the direction that CORRUPTS the results file: `noise … lin 1 1k 10k` has start ≠ stop and produces ONE plot, so the plan's predicate would have declared one capture too many — and an over-walk is **silent**, saturating on the `constants` plot and appending ngspice's twelve mathematical constants at rc 0. The rule is *more than one frequency point* (`noisean.c:93-109`, `:145-168`). (b) `.options sqrnoise` **renames both noise plots**, so an exact `select` literal would report `mislabel` on every such run; the two declare globs. (c) **`sens … ac oct` is broken as well as `lin`, and nobody had measured it**: `count_steps` (`cktsens.c:862-900`) divides by `M_LOG2E` where an octave count needs `M_LN2`, so `oct 2 1k 4k` gives TWO points where `ac oct 2 1k 4k` gives five. The sweep field declares `values {dec}`, refuting receipt 12's `{dec oct}`. (d) the contributor names the appendix gives (`onoise_total_…`) are the **Integrated Noise** plot's while `§6.2` routes the table to the **spectrum** plot, which spells them `onoise_…`; both are real, and `onoise_spectrum` has exactly the shape of a device total, which is a fifth naming hazard beside the three §2.6 lists. ⚠ **AND MAKING THEM RENDERABLE PUT TWO DEFECTS IN A USER'S REACH.** `disto` **SEGFAULTS — rc 139, no exit status, no log, no results file** — when its save list resolves to nothing, reached through ASE-L's own `.save` dot cards; the trigger is the WHOLE list resolving to nothing, so design-C's proposed refusal would have refused a deck that runs. And `noise`, `tf` and `sens` are **starved by one ticked output** (`APPENDIX §7.5.2`, which assigns it to "Stage 6's precondition" by name) — three of this tree's own fixtures were rendering decks ngspice would have refused. ⚠ **D30 IS NORMATIVE NOW**: a plots row with no destination, an `opinfo` plot routed anywhere but `none`, and a destination the entry's own `results` does not declare are all load-time refusals. ⚠ **AND THE REGISTRY LISTS A MULTI-PLOT TYPE'S PLOTS IN WRITE ORDER, WHICH IS REVERSE CREATION ORDER** — the walk runs backwards and reconciliation compares positionally, so a registry in creation order would mislabel every two-plot run; that refutes `ase::analysis_plots`' own header as 1430 left it. Verified end to end through `render_deck`, four decks, both binaries: byte-identical sidecars and `Plotname:` lists, `ok` 5/5/5, **no `constants` record in any results file**. Floors: `test_ase_core` 453 → **475**, `test_ase_preflight` 194 → **210**, `test_ase_simcaps_0948` 190 → **199**, `test_ase_optier_0963` 105 → **106**.

~~**The next free number is 1432.**~~ superseded: **1432** is filed, above.

- **1433** — **A Stop threw away everything the run had computed.** Stage 6f of `doc/claude/ase_analyses_batch/` and ⚖ **R1's always-salvage requirement**, answered by the user with words neither offered option contained. `ngspice -b` installs **no signal handler at all** — `src/main.c` puts its whole `signal()` block inside `if (!ft_batchmode)` — so a Stop kills the process where it stands and the running analysis's work is gone; nothing was being bought with the loss. The deck now stops **itself** on a point count, writes to `<rundir>/<cell>_ase.raw.ckpt` through a `.tmp` and `shell mv -f`, and resumes. MEASURED end to end through ASE-L's own `render_deck` on the fork AND on apt 45.2, SIGTERM 6 s into an 8,000,008-point transient: rc 143, `op` and `ac` **intact**, the plotmap still 1:1 with the results file, and **4,800,000 points of the transient kept**, byte-identical on the two binaries. ⚠ **SIX MEASURED REFUTATIONS OF `PLAN.md` §6f, WHICH HAD NEVER BEEN RE-MEASURED.** (a) SV15's `tstop/tstep + 8` is wrong for **three of the five shapes the shipped `tran` row can produce** — `tstart` and `tmax` are advanced fields on it, and `tran 10n 80u 0 20n` is 4,009 rows where the formula says 8,008; the rule is `(tstop − tstart)/(tmax ? tmax : tstep)`. (b) **Both directions of estimate error were silent** in the plan's loop: 10× high made it spin five more times after the run finished, each writing the WHOLE rawfile again, and 10× low stopped checkpointing at 8,005 of 80,008 points leaving the last 90 % unprotected — both rc 0. The shipped loop terminates on a **measurement** (`if length(time) < $cktgt`). (c) **The `set` route rounds to six significant figures**, so `cknext` 1,600,002 arms 1,600,000 and a test against `cknext` reads the stop as "finished": an 8,000,008-point run wrote **zero** checkpoints and said nothing — invisible below 1,000,000 points, which is where a short test deck lives. (d) SV11's other half: `let` on a name that **already exists** in `const` writes **through** to `const` rather than shadowing, which is what lets two `tran` rows each carry their own interval. (e) `delete all` is mandatory and its leak is **invisible on a short next analysis** — a following `ac` of 601 points showed none, where one of 6,001 was truncated to the threshold at rc 0. (f) the completion marker is emitted **only** by a checkpointing deck, so the verdict is three-state (`unknown`), or every ordinary run reads as aborted and every deck golden moves a second time. SV1, SV2, SV4, SV5, SV7, SV8, SV10 and SV12 all re-confirmed on both binaries. Floor: **100,000 points**, picked and stated as `ase::ckpt_floor`. (g) the loop's EXIT must be the FALSE branch: `.control`'s `if` takes the false branch for a condition it cannot EVALUATE -- measured for `<`, `>` and `>=` -- so with a save list that resolves to nothing the transient never runs, `length(time)` is unevaluable, and a loop exiting on the true branch checkpointed and `resume`d **FOREVER at rc 0**, found by the sabotage that deleted the floor. (h) the arming block must sit ABOVE issue 1419's verbatim hatch, whose adjacency rows VB1/VB2 were green while it did not. Floors: `test_ase_core` 476 → **523**, `test_ase_preflight` 210 → **218**, `test_ase_optier_0963` 106 → **108**.

~~**The next free number is 1433.**~~ superseded: **1433** is filed, above.

- **1434** — **A ticked output stopped four analyses running at all, and one of them said nothing.** Stage 6g of `doc/claude/ase_analyses_batch/` — the four variant mitigations, `DECISIONS.md` **D46**/**D47**/**D48**, `APPENDIX` §7.5.1/§7.5.2. ASE-L emits one `.save <expr>` card per ticked Outputs row, and MEASURED on the fork (`ngspice-46+`) AND on apt 45.2, through `render_deck`'s own deck shape, **one ticked output is enough** to make `noise`, `tf`, `sens` (both modes) and **`pz`** refuse to run at all — `Error: no data saved for <X> analysis; analysis not run`. Issue **1432** shipped that as a **`fatal` precondition**; this makes the run WORK instead, by emitting the `.save all` leader (guard **G-LEADER**, issue 0964) that 1432's own stand-down already relied on, and demotes the precondition to the `caution` that SAYS the save list was widened. ⚠ **FIVE MEASURED REFUTATIONS, AND THREE DOCUMENTS SAY THE SAME WRONG THING.** (a) **`pz` IS in the class** — `APPENDIX` §7.5.2's table, `PLAN.md` §0.13.7 and `src/ase.tcl`'s own `vecsaves` comment all say it survives; measured three ways it does not, and it is the WORST member because its starvation is at **rc 0 with `$sim_status` 0**, so the deck's guard never fires and `RUN-FAILED` never appears. (b) **`disto` is NOT in the class**, which every document says it is: a `disto` plot's `Variables:` block is `frequency v(in) v(mid) v(out) i(v1)`, netlist names every one, and a resolving narrow save is rc 0 on both binaries. (c) **`sens` is starved in BOTH modes**, not `dc` alone. (d) **there is no "fifth type"**: issue 1433 handed on `tran` as one, and a save list that resolves to NOTHING is measured to starve `op`, `dc`, `ac`, `tran` and `pz` alike and to SIGSEGV `disto` — universal, now a `saves_resolve` `caution` on every netlist-named type with `disto_saves`' `fatal` untouched. (e) **the phantom `all` column takes the WRAPPER of the real save** — `.save i(v1)` + `op` on apt 45.2 answers `i(v1)` **and `i(all)`** — where `PLAN.md` §6g-2 says *"literally named `all`"* and `APPENDIX` §7.5.1 shows only `v(all)`, so a filter written to either misses it. 6g-2 ships as `ase::raw_drop_phantom_all` at `ase::cap_raw_plots`; 6g-3 as the leader gated on `ase::caps_measured_as $caps one_vector_write 0`; 6g-4 as `ase::deck_case_lint` over the `.control` block only, measured — `.SAVE V(MID)` is folded on both binaries while `WRITE <path> ALL` writes **no file** on apt 45.2 at rc 0. ⚠ **AND TWO MORE FOUND BY SABOTAGE.** (f) applying the 6g-2 filter at `ase::cap_raw_plots`, which is the seam `PLAN.md` §6g-2 NAMES, **switches 6g-3 off**: that proc is the capability probe's own reader, so dropping the phantom makes `one_vector_write` answer 1 on the binaries that have the defect -- measured by taking the filter back out and watching `test_ase_core`'s D1/D5/C4/C5 redden. **A reader whose answer feeds a MEASUREMENT may not be improved.** (g) `test_ase_core`'s ISO1377 isolates the REGISTRY and not `auto_execok`, so a live probe of whatever ngspice is on $PATH still ran and, once 6g-3 read a capability inside `render_deck`, decided a deck golden; row **ISO1434** declares it unmeasured and **WD6b** pins the gate three ways instead. And (h) 6g-3 DOES reach a committed bench -- `test_nfet_final` is its shape -- so it stands down where the operating-point tier will emit its own leader, which `test_ase_final`'s **F12** (exactly one `.save all`, invariant I2/R2) is what said. Floors: `test_ase_core` 523 → **558**, `test_ase_preflight` 218 → **229**. **No deck golden moved**, and row ISO1434 is what makes that a property rather than an accident.

~~**The next free number is 1434.**~~ superseded: **1434** is filed, above.

- **1435** — **The precondition banner needed a netlist a dialog may not produce.** Stage 6 task 6 of `doc/claude/ase_analyses_batch/`, and the third of Stage 4's three user-visible surfaces — the first two (`ase::preflight_gate`'s `fatal` refusal, issue 1424, and its pre-run advice block, issue 1425) landed with Stage 4; this one was deferred because it needs netlist **text**, which the dialog does not have and could only get by calling `ase::netlist` — a proc that deletes and rewrites `<rundir>/<cell>.spice` (`~/.xschem/simulations` when `rundir` is empty), whose arm (b) does `xschem load` over the current buffer and whose arm (c) walks the user's hierarchy and can REFUSE. **The fix is a slot the dialog PEEKS at and never fills**, the shape `ase::sim_caps_cached` and `ase::op_cards_*` already use: `ase::facts_capture` primes it from `ase::netlist_in_place` — measured the ONE `xschem netlist ` in ASE-L once comments are stripped, and all four arms of `ase::netlist` end there — `ase::facts_status` answers `cold`/`stale <why>`/`warm` from two `file stat`s, `ase::netlist_facts_cached` parses **once** and memoises, and `ase::facts_donate` lets `ase::run_deck` hand over the copy `preflight_gate` already computed (**an existing slot only** — `ase::run_existing` never re-netlists, so it donates nothing; `ase::preflight_gate` gained an optional third argument for it). ⚠ **THE CONTENT HALF IS EMPTY AND THAT IS THE FINDING**: every precondition sentence the banner prints was already minted in `ase::needs_eval` by 1423/1425/1426/1427/1428/1432/1434, `ase::backend::ngspice` is byte-unmoved, and this issue mints THREE frames (the cold sentence and the two stale ones). ⚠ **AND `PLAN.md` CONTRADICTED ITSELF**: its Stage 4 paragraph says *"there is no new pixel … No look debt is filed"* while its own Files-and-procs table adds a `.note` banner. MEASURED on `:99`: with the capability cache cold — what a user who has never pressed Detect has — `$w.status` is occupied on **all eleven cells**, and it has `-wraplength 0`, so one 101-character precondition sentence took the dialog from **667 px to 856 px**. The `.note` row is the live half; a **`look` debt is filed**. `ase::netlist_facts` measured at 0.9/7.5/**76.5 ms** over 200/2 000/20 000 netlist lines, which is why the parse is lazy. Floors: core 558 → **598** (section BN, 40 rows), preflight 229 → **235** (PF233), dialogs `:99` 285 → **300** (GN, headless 37 unmoved). **Thirty-two sabotages, zero survivors, zero kills** — and four of them (S04/S05/S13/S20) KILLED `test_ase_core` in pass 1 at `invalid command name "ag_five"` because a bare `dict get … why` on a `{state warm …}` answer raises inside the file's outer catch, which is why every optional key in section BN is now read through `bn_get`. No deck golden moved, no `.state` file moved, no new state key, no `seed_enabled`.
- **1436** — **Two display-arm rows of `test_ase_dialogs` have been red since before Stage 6.** Filed by the 1435 crew, **not fixed**, because a standing red is a defect rather than furniture and because both fixes are rulings. `G2sens` expects `$top.chana.form.stop` not to exist for `sens`; issue **1432** gave `sens` its AC mode and five more fields, every one carrying `depends {mode ac}`, and `ase::ui::chana_show` builds every non-advanced field whatever its `depends` says — so the widget is there and the row, written for 1428's two-field `sens`, says it is not. **That is receipt 17's own deferred note, "`depends` has no surface", arriving as a red.** `GG9` expects `ase::analysis_detectable` to be 1 and Detect live; by that point the capability cache is WARM. In a fresh process it is cold and the premise holds, and under a scratch `HOME` a THIRD row (`GG3`) reds as well — so the leak is environmental: `test_ase_core`'s ISO1434 lesson from the other side, a suite's isolation covering the REGISTRY while `ase::sim_status` falls back to `[auto_execok ngspice]`. Related: **1397**. ⚠ **Both were proven pre-existing by RESTORING `src/ase.tcl` and `src/ase_window.tcl` to HEAD `81312742` and re-running** — same two rows, same values, 283 passed either way. T1 runs this file's HEADLESS arm only (37, ALL PASS), so neither is a T1 failure.

~~**The next free number is 1435.**~~ superseded: **1435** and **1436** are filed, above.

- **1437** — **The option catalogue, and the one speller that makes its columns type errors.** Stage 7 task 1 of `doc/claude/ase_analyses_batch/` (`PLAN.md` §7a + §7b). **There is no error channel for a misdelivered option on ASE-L's route** — measured on both binaries, `.options bogusdot=1` plus `option bogusopt=3` print nothing on either stream and both names are silently invented as variables — so the class of a name has to be known BEFORE the line is written, and three silent wrong answers were live because it was not. **FIVE committed benches carry `{name wnflag value 1}`**; `wnflag` chooses MOS W total vs per finger, is read inside `inp_readall()` (`inpcom.c:990`) before any `.options` card exists, and is a `CP_NUM` a bare `set` cannot answer — `.options wnflag` is the wrong door TWICE OVER. ⚠ **CORRECTED BY 1439:** `inpcom.c:990` reads it into a local `inp_get_w_l_x` never uses and `inp.c:2828` is inside `#ifdef REM_UNUSED`, defined nowhere — the ONE live read, `inpgmod.c:268`, IS reached by an `.options` card (measured on both binaries, `.options wnflag=1` moves the selected bin). The wrong door was the VALUE, not the phase. MEASURED on both binaries: `.options maxord=1` gives `MaxOrder = 1` and `.options maxord` leaves it at **2** (the emitter writes the bare card for every valued option set to 1); `.options gminsteps=0` gives `gminsteps = 0` and writing nothing leaves it at **1** (the emitter drops a row set to 0). **The fix is a 247-row catalogue as the ngspice adapter's CONTENT** — 57 settable `OPTtbl` keywords + 163 `cp_getvar` variables (the plan's 220 floor, A∩B measured EMPTY, 98+163 = 261 distinct names) plus 27 rows in four classes the floor has no member of — reached only through the new `sim_options` hook, **and `ase::opt_line` as the one speller** (D23) switching on **(door, cptype)**, not on `cptype` alone. ⚠ **THE DOOR IS COMPUTED AND THE PLAN STATES ONE ON EVERY ROW**, three paragraphs above the sentence forbidding it — and spells it `phase L1`, an ngspice word in a column core computes from; ASE-L's vocabulary is `pre`/`deck`/`run`/`any`/`cmdline` and `ngphase` keeps the adapter's. ⚠ **TWO DELIVERY CLASSES `PLAN.md`'s DOOR TABLE DOES NOT HAVE**, both measured on both binaries: `.options warn=1` arms the SOA check while `set warn=1` in `.control` does nothing (the block runs after the circuit is loaded — `warn`, `maxwarns`, `probe_is_given`, `brief`), and `set units=degrees` gives −44.99° while `.options units=degrees` leaves the phase in **RADIANS** — the 57.2958× error no design in this batch caught, on an option that is **not one of the 220** at all. ⚠ **AND APPENDIX §3.2's 163rd NAME IS WRONG**: a literal `cp_getvar` grep finds 162 and the 163rd is `casemodewrite`, read through `cp_getvar_policy()` (`variable.c:753`), not the computed `auto_bridge_*` family. The pre-deck class is **34**, not 26 — the dossier's own table lists **35** and its count omits the ten `ps_*` rows, and one of the 35, `scale`, is MEASURED not pre-deck at all (`.options scale=0.5` halves a MOS W on both binaries, `@m1[w]` 2u → 1u, while `set scale=0.5` in `.control` does nothing; the shipped `rom8k` example carries `.options SCALE=0.10`). `render_deck` is **untouched**: no deck golden moved, no `.state` file moved, no new state key, no `seed_enabled`. New suite `test_ase_options_1437` (**75 checks**), registered in `run_regression.tcl`'s `hcases`, so T1 covers all 75.

~~**The next free number is 1437.**~~ superseded: **1437** is filed, above.

~~**The next free number is 1438.**~~ superseded: **1438** is filed, above.

- **1438** — **`render_deck` spells options without a `cptype`, and three classes of value are silently wrong.** Filed by the driver from the 1437 crew's findings, **not fixed there**; the repair is `PLAN.md` §7d/§7e's. Five committed benches ask for `wnflag` and none of them gets it; a valued option stored as `1` is written as a bare card (`.options maxord` leaves MaxOrder at 2); a valued option stored as `0` is dropped (`gminsteps` runs at 1). **FIXED BY 1439**, all three — and 1439 refutes this file's account of the first one. See `doc/claude/issues/1438-render_deck-spells-options-without-a-cptype-and-three-classes-of-value-are-silently-wrong.md`. ⚠ *This entry was added by the 1439 crew: the issue file was committed without one.*

- **1439** — **A pre-deck option had no door, and `wnflag` never needed one.** Stage 7 task 2 of `doc/claude/ase_analyses_batch/` (`PLAN.md` §7d), ⚖ **R2**'s four conditions as requirements. **Thirty-two** ngspice options are reachable from neither `.options` nor `.control`; ASE-L wrote a `.options` card for them and the simulator ignored it in silence. Delivery is now `-D name` / `-D name=<string>` for the CP_BOOL and CP_STRING subset and `<rundir>/.spiceinit` for the CP_NUM / CP_REAL / CP_LIST one, spelled by 1437's one speller and routed by the computed door. ⚠ **AND ISSUE 1438's DEFECT 1 HAS A DIFFERENT ROOT CAUSE THAN 1438 STATES.** Two of `wnflag`'s three cited read sites are **dead**: `inpcom.c:990` reads it into a local `inp_get_w_l_x()` never uses, and `inp.c:2828` is inside `#ifdef REM_UNUSED`, **defined nowhere in the ngspice tree**. The live read is `inpgmod.c:268` (`INPgetModBin`, at model-binning time), which an `.options` card reaches — ngspice's own comment at `:294` says *"or on the `.options` wnflag"*. MEASURED on BOTH binaries, on a flat `m` line AND on the sky130 `x`-line shape with two binned models 0.4 V apart: `.options wnflag` (ASE-L's line) leaves `@m1[vth]` at 9.888996e-01 and `.options wnflag=1` moves it to 5.888996e-01 — **a 71% change in i(vd)** at rc 0 with a clean log; `set wnflag=1` in `.control`, `-D wnflag=1` and `-D wnflag` all do nothing; `<rundir>/.spiceinit` `set wnflag=1` works. So `wnflag` is a **`deck`** option and 1438's defect 1 **is** its defect 2. `render_deck`'s option loop now asks what kind of option it is writing — all three of 1438's defects fixed, and **the five benches deliver**. The pre-deck class is **32**, not 34: `no_spinit` left it too (MEASURED: `-D no_spinit` does **not** suppress the start-up file on either binary, `-n` does). ⚠ **`PLAN.md` §7d's "every pre-deck option … refused when `-n` is in force" IS REFUTED** — measured on both binaries, `-n -D ngbehavior=hs` still prints `Note: Compatibility modes selected: hs`; `-n` closes the FILE and nothing else, which is ⚖ R2's own wording, and a rule debt is filed for the narrowing. ⚠ **AND `[R-M7]`'s "`source` loses the user's variables" IS CONDITIONAL**: `com_source` (`inp.c:1984`) is `substring(INITSTR, owl->wl_word)`, so the same bytes named `.spiceinit` are read as commands and named `myinit.txt` produce `Circuit: set frobnicate` / `Unable to find definition of model` — copying is still required, for a sharper reason. `casemode` and `no_spinit` carry an `owner` and the speller refuses them (MEASURED on the fork: the **last** `-D casemode=` wins, so a bench row would beat the pre-flight-gated request). New suite `test_ase_predeck_1439` (**78 checks**) in `hcases`; `test_ase_simreg_0931` **111 → 117** (section P, the `-D` arm) — ⚠ the plan's expected six-row re-baseline of A2/B5/B6/B11/B12/D4 **did not happen**, because all six build the command from an EMPTY state; `test_ase_options_1437` stays at **75** with seven rows re-baselined.

~~**The next free number is 1439.**~~ superseded: **1439** is filed, above.

~~**The next free number is 1440.**~~ superseded: **1440** is filed, above.

- **1441** — **A 247-row catalogue with no finder, and a badge nobody had measured.** Stage 7 task 3 of `doc/claude/ase_analyses_batch/` (`PLAN.md` §7c), and the only one of Stage 7's four tasks that draws a pixel. `Simulation > Options…` listed the rows this bench already stored and nothing else, so an option whose name you had not already typed was unreachable from the GUI; nothing said **where** a setting would be written or whether it would arrive. ⚠ **AND THE ⚠ BADGE §7c ASKS FOR RESTED ON A TRANSCRIPTION.** Issue 1437 shipped `group`, `scope` and `results` **0/247 verified** and said so; §7c asks for a badge asserting *"this option changes your numbers"* on every `results 1` row. All **22** were probed on BOTH binaries (`/usr/bin/ngspice` 45.2 and the fork `ngspice-46+`), each on a deck built to make its own mechanism fire, every value identical on the two: **9 MEASURED to move a printed value** (`scale` `@m1[w]` 2u→1u; `wnflag` `@m1[vth]` 1.0889→0.6889 across a binned-BSIM4 W bin edge, `i(vd)` 8×, and the **bare card delivers nothing**; `sqrnoise` `onoise_total` 3.147875e-07→9.909116e-14; `cshunt_value`; `notrnoise`; `seed`; `autostop` 226 data rows→**2**; `diode_cj0` AC imag 0→1.066292e-04 and `diode_rser` `i(vb)` 5.670347e-03→5.867302e-04, both through the run-directory start-up file); **3 MEASURED NOT TO, with the mechanism firing** — `warn=1` takes a deck from **0 to 5 SOA messages with every printed value byte-identical**, `maxwarns=2` takes 5 messages to 2, `num_threads=1` is identical to the default; **10 NOT MEASURED** (event/A-device XSPICE, model shapes, or nothing distinguished the two runs). ⚠ **The transcription would have badged all three refuted rows, two of them pure diagnostic printers** — and `hidden-vars.md` §2.1's own R/P column already marks them **P**. The column now carries `results_ev`, `ase::opt_results` answers `yes`/`no`/**`unverified`**, the default for an evidence-free row is `unverified`, and the sheet draws a **different** badge for it, so the uncertainty is on the surface. The sheet itself keeps the old toplevel, treeview, context menu, row editor and **integer row ids** — the changed-only default view IS the stored rows, so `test_ase_dialogs`' G6/GE9 did not move — and adds a live substring search over name/group/help, `Show all` in **groups**, a scope selector, the badge column, a detail line and a **live deck preview**. ⚠ **The preview is not a second opinion**: `render_deck`'s option loop moved into `ase::opt_deck_plan`, which the emitter calls and the preview reads, with the last-resort `.options` spelling behind the adapter's new `option_fallback` hook (D34, no fallback content for a backend with no hook). ⚠ **REFUTED IN `PLAN.md` §7c**: the "eleven categories" are fifteen, and one of them, `numerics`, was the `results` column wearing a group's clothes (all 20 re-filed, 14 groups now); and §7c-2's *"a filter, not a feature, because the catalogue carries `default`"* is wrong in the direction that **hides a real change** — storage decides visibility, `default` decides the annotation, and only **65 of 247** rows carry a default at all. `scope` cross-checked clean against `options.md` §10.2 (**zero set-level disagreements over 27 shared rows**; `dyngmin` and `chgtol` moved), and a wrong scope cannot hide an option because the **global surface offers every row**. `units` — the 57.2958× phase error — had **no help text** and has one now; only 64 of 247 rows carry help (⚖ R9). New suite `test_ase_optsheet_1441` (**62 headless / 87 on the dev display**) in **`hcases` AND `dcases`**, so T1 covers all 87; `test_ase_options_1437` stays at **75**, one row re-baselined. No deck golden moved and no `.state` file moved.

- **1442** — **A scope the simulator does not have, a read-back channel that was half broken, and the four rules.** Stage 7 task 4 of 4 of `doc/claude/ase_analyses_batch/` (`PLAN.md` §7e + §7f + §7g), and the last task of Stage 7. Three faults, one issue, because all three are about **what ASE-L claims versus what the simulator did**. (1) **The per-analysis options sheet was a lie**: issue 1441's `Simulator Options…` button opens the sheet with the scope preset and then writes into the same **global** list, so a value set "for this tran" was set for the whole run — and ngspice has no per-analysis option scope at all (MEASURED on both binaries, `option keepopinfo` inside `.control` stays set for every later analysis). (2) **There is no error channel for a misspelled option**: `.options bogusdot=1` + `option bogusopt=3`, and `.options frobnicate` + `.op`, print **not one word** on either binary, with `.options reltol=0.05` → `reltol (current) = 0.05` as the positive control in the same batch; the `Error: unknown option %s - ignored` branch is real (`inpdoopt.c:75`) and **neither route reaches it**. (3) **AC sensitivity under KLU is a SIGSEGV** and ASE-L refused the whole run for it. ⚠ **AND `PLAN.md` §7f's OWN RECIPE IS HALF BROKEN.** Measured in ONE deck on both binaries with `echo > f` and `print > f` beside them as positive controls: `echo` **22 bytes**, `print` **22**, `set >> f` **440/450**, and **`option > f` ZERO BYTES** — `com_option.c` writes its whole dump with bare `printf` while ngspice's `>` rebinds `cp_out`. A deck built to the plan's recipe would have produced a plausible half-empty sidecar whose missing half always diffs clean, which is this batch's vacuity defect inside the feature meant to cure it. The task dump is bracketed in the **run log** instead; only the variable dump is redirected. ⚠ **AND `ase::opt_restore_line` COULD NOT RESTORE A FLAG**, which is what §7e rests on: it answered `{}` for the whole class under *"absence has no line"* — true of the forward spelling, false of the reverse. MEASURED: `option keepopinfo` then `ac` puts `op1` in `$plots`; `option keepopinfo=0` then `ac` does not. Source generalises it — every `IF_FLAG` arm in `cktsopt.c` is `(val->iValue != 0)`, with `OPT_SPARSE` at `:181` inverted so `sparse=0` turns KLU **on**. ⚠ **REFUTED IN THE PLAN AND IN ISSUE 1441's RECEIPT**: **60** of 247 rows carry a `default`, not 65 (65 is the `help` count); only **39** can be spelled back through the `control` door and only **15** are both analysis-scoped and restorable, so §7e's escape hatch would have **removed 17 rows from a surface 1441 already shipped** — every analysis-scoped row stays offered and each one **says** whether it is `scoped` or `leaks`. ⚠ **§7g RULE 1's REFUSAL IS DEMOTED, NOT DELETED**: the suppression is scoped to the **analysis** rather than the run (`option klu=0` before the AC `sens`, `option klu` after), measured rc 0 with the solver reading KLU / sparse / KLU across three jobs and the `sens` numbers **byte-identical** to a deck that never asked for KLU — while a backend that cannot suppress still gets the `fatal`, because the alternative is the SIGSEGV. **Rule 2 was already shipped** (issue 1434, 6g-1) and is confirmed by a row rather than re-implemented; rules 3 (`ac lin 2` → **one** point, measured, with `lin 3` → 3 and `dec 2` → 3 as controls) and 4 warn and never refuse (D47). ⚠ **Rule 4 ships with a DIFFERENT REASON than the plan gives**: D4's 8-character `No. Points:` overflow is `-r`'s streaming writer (`outitf.c:1011`/`:1190`); ASE-L writes with the `write` command (`rawfile.c:209`), which has no reservation — verified, a 1008-point write gives `No. Points: 1008`. Rule 5 ships as `ase::opt_gate_state` over the same `ase::requires_state` the analysis grid uses, with **one** genuinely gated catalogue row: `filetype`, the only `cp_getvar` variable in `src/ciderlib` (verified by grep), and `src/ciderlib` is built only under `--enable-cider`. Four new optional adapter hooks (`option_restore_spell`, `effective_emit`, `effective_lookup`, `analysis_suppress`); a backend with none gets no content (D34). New suite `test_ase_effective_1442` (**92 checks, identical on both arms**) in `hcases` only, deliberately not `dcases`. Three rows re-baselined as decisions — `test_ase_options_1437` **RS2**, `test_ase_preflight` **PF230f**, and `test_ase_core` **D1**'s inline golden deck — plus four extractor repairs in `test_ase_core` where `^(op|…)` had no word boundary and also matched `option`. **No committed deck golden file moved and no `.state` file moved.**

~~**The next free number is 1441.**~~ superseded: **1441** is filed, above.

~~**The next free number is 1442.**~~ superseded: **1442** is filed, above.

- **1443** — **A GUI that could not read a number back, and five producers nobody could ask for.** Stage 8 task 1 of 2 of `doc/claude/ase_analyses_batch/` (`PLAN.md` §8a + §8c). `grep -c '\bmeas\b' src/ase.tcl` returned **zero**, so two of the six benchmark ADE tasks — *read back the phase margin* and *the spread of one measurement over 200 Monte Carlo runs* — ended at "you are on your own"; and `.four`, `fft`, `spec`, `psd` and `linearize` had destinations in every design and **no producers anywhere**. A `measurements` state list beside `outputs` (absent by default, in `ase::omit_if_empty`, all 104 committed `.state` files still byte-identical) emits `meas` **commands** inside `.control`, immediately after the analysis they read, plus the five post-processing producers. Thirty core `ase::meas_*` procs own the schema; four new **optional** adapter hooks (`meas_kinds`, `meas_analyses`, `meas_rule`, `meas_needs_degrees`) own the content, and a backend with none gets nothing (D34). ⚠ **THE RADIANS TRAP IS DEFEATED THROUGH THE ONE OPTION SPELLER, AND THE BRIEF FOR THIS TASK WAS WRONG ABOUT WHY THAT IS POSSIBLE**: it and `LEDGER.md`'s Stage 8 block both say `units` is *not* one of the 247 catalogue rows; counted live it **is** (issue 1437 added it, door `control`, `values {radians degrees}`), so `ase::opt_line ngspice units degrees control` already spells `set units=degrees` and no second literal was needed (C145). Measured on both binaries on an RC whose phase at 1 kHz is exactly −45°: nothing set → `-7.853982e-01`, `.options units=degrees` → `-7.853982e-01` (the card is inert, silently), `set units=degrees` → `-4.500000e+01`. The emission has its **non-vacuity control**: a row with no phase in it emits no line (PH2). ⚠ **§8c's TWO STRUCTURAL CLAIMS ARE BOTH REFUTED BY MEASUREMENT.** *"`.four` is a CARD"*: a dot card beside a `.control` block makes `main.c`'s batch arm call `ft_dorun(NULL)` and **run the whole simulation a second time** — `Doing analysis at TEMP` twice against once for the `fourier` command, which creates the identical `fourier<m><n>`/`thd<m><n>` vectors and prints the identical table — so the card slot ships **empty** (C148). *"All four are captured by Stage 6's walk"*: `save.c`'s `read_dataset()` matches `Plotname:` by substring, so `Transient Analysis (linearized)` reads back as the **transient** and `Spectrum` as an **AC analysis** — measured through this tree's own reader, `xschem raw read multi.raw tran` → `datasets=2` with a linearized copy made to disagree, and `… ac` → `datasets=1 sim_type=ac` on a deck with no `ac` in it. That is issue 1430's `AC Operating Point` refusal one stage later, so **no producer plot is written**, the walk, the plotmap and `ase::analysis_captures` are untouched, and the results come back as measurements and as the printed table (C149). ⚠ **THE BLOCK'S POSITION IS ITSELF A MEASUREMENT, BOUND FOUR WAYS** (DK2 by emission, DK2c on the emitter, after issue 1442's S24 hid in exactly that gap): below the `$sim_status` guard, below the row's first `write` — a `fourier` above it grew a 1,000,001-point rawfile from 48,000,724 to **64,000,905 bytes, +16 MB for two scalars**, because a length-1 vector is expanded to the whole record (C150) — above the `setplot previous` walk, and above the prints (0967/1243) and the per-analysis option restores (§7e). ⚠ **THE FOUR GRAMMAR TRAPS RE-MEASURED, AND TWO OF THEM SHARPENED**: on the COMMAND form `expr=`, `param=` and `par()` do not merely fail, they **do not exist** (`no such function as 'param=7.756162e+00'`), so the `param` kind ships as a `let` and cannot meet the once-per-session numparam trap at all (C147); `.meas` under `-r` is confirmed refused; and `meas … > file` really does write (54/66 bytes, with `echo > f` = 22 and `print > f` = 31 as positive controls in the same deck) — but its stated REASON is false on apt 45.2, where `set measureprec` and `NGSPICE_MEAS_PRECISION` are both **accepted and inert**, leaving the printed line at `%.6e`, exactly the vector's precision (C146). A failing `meas … > file` creates the file at **zero bytes**, so the sidecar is opened by an `echo` and appended to (C152). Also: `fft`/`psd`/`spec` leave their own plot current, so a second transform reads a spectrum and fails at rc 0 (C151); and `ase::si_parse` answers `{ok <value>}` rather than a number (C153). New suite `test_ase_meas_1443` (**88 checks, identical on both arms**) in `hcases` only. `test_ase_core` R1 re-baselined 18 → 19 schema keys with R1m added (floor 598 → 600) and `test_ase_persist` R1 likewise. **No committed deck golden file moved and no `.state` file moved.**

~~**The next free number is 1443.**~~ superseded: **1443** is filed, above.

~~**The next free number is 1444.**~~ superseded: **1444** is filed, above.

- **1445** — **The form forgot what you typed the moment you clicked another analysis.** ⚖ **R5** of `doc/claude/ase_analyses_batch/DECISIONS.md`, answered by the user on 2026-09-13 — *"Make it remember — that's a more professional UI. We are trying to be better than Cadence"* — and the **first ruling in that batch that changes behaviour rather than ratifying it**. Clicking a cell in the Choose Analyses type grid destroyed the form and rebuilt it from the stored row; `doc/claude/ase_l_ux_batch/FINDINGS.md` has it from the user's own seat (*"I typed 500u, clicked the ac radio, clicked back, and 500u was gone"*), and issue 1411 had just made that row **eleven** cells, so browsing the grid — the first thing a new user does — cost them their typing every time. Three procs in `src/ase_window.tcl` (`chana_cache_save` / `chana_cache_apply` / `chana_cache_clear`): a per-dialog, per-type cache of what the user **touched**, overlaid on the stored row when a type is repopulated, cleared on every dialog open and every close. **No new state key, no schema change, nothing serialised.** ⚠ **THE REVERSED D4 IS `doc/claude/ase_l_batch/prompts/item07_dialogs.md`'s**, NOT `ase_analyses_batch/DECISIONS.md`'s own D4 (the per-row keys `id` and `x`) — reversing that one would change the schema. ⚠ **D4's REASON SURVIVES ITS OWN REVERSAL**: *"no hidden multi-type writes"* defends the COMMIT, and `chana_ok` still writes the visible type alone and never reads the cache. ⚠ **THE SAVE GOES IN `chana_show`, NOT ON THE RADIOBUTTON**, which fixes a second discarding nobody had reported — `chana_adv_toggle` rebuilds through the same door, so folding `▸ Advanced` open or shut threw the form away too. ⚠ **IT REMEMBERS WHAT WAS TOUCHED, MEASURED RATHER THAN PREFERRED**: the first cut cached every live value and reddened the **existing** row `GN7b` by caching a `step` the user had never typed as the empty string, which then **deleted a stored `step 1n`**. ⚠ **BOTH HALVES MERGE AND NEVER REPLACE**, because `ase::ui::form_has` is false for a widget that was never built: an apply that replaced would silently delete every field `▸ Advanced` was hiding, and a save that replaced would discard a value typed under it the moment the disclosure folded shut. `test_ase_dialogs` **300 → 313 on the display arm** (section GR5, twelve rows; headless unmoved at 37 — there is no schema half). 104 `.state` files round-trip **0 of 104 differing**; **no committed `.state` file moved**. Nine sabotages, each restored by `cp` + md5. See `doc/claude/issues/1445-the-form-forgot-what-you-typed-the-moment-you-clicked-another-analysis.md`.

~~**The next free number is 1445.**~~ superseded: **1445** is filed, above.

- **1446** — **A value the dialog remembered, and OK did not write.** Filed by the driver out of ⚖ R5's implementation (1445), from a residual the crew measured and the driver verified in `ase::ui::chana_adv_toggle`. Two shapes survive R5's remembering. **(A)** Type into `tran`, click `ac`, press OK: the `tran` edit is dropped. That is the shape ⚖ R5 **ruled** — *commit only the visible type* — and it is filed to show the user the consequence of their own answer, not to reopen it. **(B)** Type into a field behind `▸ Advanced`, fold the disclosure shut, press OK: the value is **remembered** (unfold it and it is there) and **not committed**, because `ase::ui::chana_ok` reads **live widgets** and the fold destroys them — `chana_adv_toggle` rebuilds through `chana_show`, which does `destroy $w.form`. ⚠ **(B) IS NOT A REGRESSION**: before 1445 the value was destroyed outright, so OK could not write it and nothing could recover it; 1445 made it recoverable and left the commit door where it was, which is why the loss is now *visible*. ⚠ **AND (B) DOES NOT CROSS D4's LINE** — same type, same row, one write — so unlike (A) it is a ruling worth putting, recommended answer **B: `chana_ok` reads the visible type's live widgets merged over that type's cache**. `rule` debt filed. See `doc/claude/issues/1446-a-value-the-dialog-remembered-and-ok-did-not-write.md`.

~~**The next free number is 1446.**~~ superseded: **1446** is filed, above.

- **1447** — **Two sweeps of one type, and no word for either of them.** ⚖ **R6** of `doc/claude/ase_analyses_batch/DECISIONS.md`, answered by the user on 2026-09-13 — *"Add it"* — whose same message added a requirement neither option contained and became issue **1444**: *"It should be easy for a user to find out how to refer to different analyses for purposes of building measure statements."* A bench could hold two DC sweeps and there was **no way to say which one anything meant** — not in the file, not on screen, and not in a calculator expression. `ase::meas_binding` answered `{type idx}`, an **index**, which is a position and not a name; `PLAN.md` §8a's measurement rows had been written against a handle (`{name pm analysis ac id a1 …}`) whose spelling had never been specified. **This is the SCHEMA half.** One optional per-row `id` key on an `analyses` row — open dicts, so **no `version` bump, no new `schema_keys` member, nothing added to `ase::omit_if_empty`** — plus **the one speller**: a row's handle is its `id` if it declares one and `<type><n>` otherwise (`ac1 dc1 dc2 tran1 op1`), with `ase::analysis_by_handle` answering in `ase::meas_binding`'s own `{type idx}` shape and one arm on that binding so a measurement row carrying `id` binds by handle, beating the `row` index. ⚠ **`n` COUNTS EVERY ROW OF THE TYPE, SWITCHED ON OR NOT** — counting only enabled rows renames `dc2` to `dc1` the moment somebody unticks the row above it, and every reference silently re-points. ⚠ **AN EXPLICIT `id` IS CLAIMED OVER THE WHOLE LIST BEFORE ANY DERIVED HANDLE IS MINTED**, so a derived handle can never collide with one. ⚠ **`id` IS NOT THE COMMITTED OUTPUT ROW CALLED `id`** — four benches carry `outputs {{name id expr -i(v1) …}}`, a drain current in a different list; sabotage S5 reds exactly the two rows written for that confusion and nothing else in 769 checks. ⚠ **A TYPE THE REGISTRY DOES NOT OFFER STILL GETS A HANDLE** (`registered 0`); sabotage S6 reds **one row of 769**. **104 of 104** tracked `.state` files load and re-serialize byte-identically with **zero** analysis rows carrying `id`. `test_ase_core` **602 → 620** and `test_ase_persist` **44 → 49 / 148 → 153**, identical on both arms; eleven sabotages, each restored by `cp` + md5. **The three SURFACES — the handle column in Choose Analyses, `Analyses > List`, and Stage 8 task 2's dropdown — are `src/ase_window.tcl`'s and are OPEN; issue 1444 stays open for them.** See `doc/claude/issues/1447-two-sweeps-of-one-type-and-no-word-for-either-of-them.md`.

~~**The next free number is 1447.**~~ superseded: **1447** is filed, above.

- **1448** — **The handle is visible, and the second row of a type is reachable.** ⚖ **R6**'s GUI half and the half issue **1447** left open: 1447 gave every analysis row a name and **nothing rendered one**, while the row the name was invented for **could not be edited at all**. `ase::ui::chana_row` returned the **first** row of its type — its own header said so — and `ase::ui::pane_dblclick` derived a type from the double-clicked row and then **threw the index away**, so a bench saying *"sweep VIN, **and also** sweep temperature"* had a second `dc` row that could be deleted from the pane and never edited; both doors in and both commit doors inside walked to the first row of the type. Ships **three surfaces and one mechanism**: a **handle grid** in Choose Analyses (a `ttk::treeview`, one line per analysis row — `Handle` `Type` `Enable` `Arguments` — rendering `ase::analysis_handle_fields`, and picking a line edits **that** row), **`Analyses > List`** (a read-only viewer whose whole body is `ase::analysis_handle_text`, every row, disabled ones marked `(off)`), and **row addressing** through the one proc `ase::ui::chana_row_idx`. ⚠ **⚖ R5's EDIT CACHE IS NOW KEYED BY HANDLE, NOT BY TYPE** — a type-keyed cache overlays one `dc` row's typing on the other's form and OK writes it — and the key is **snapshotted at build time** (`anshownkey`), for `anshown`'s own reason one level down. ⚠ **AND IT FOUND A DEFECT IN THE HALF THAT SHIPPED BEFORE IT**: `ase::analysis_emit_check`'s `known` list is `{type enabled x}` plus field names and has never heard of `id`, so `ase::preflight_gate` **refuses the whole bench** for an ENABLED row that declares one — no deck, no raw, no log, and `set ase_preflight 0` does not disable it. One word fixes it (`src/ase.tcl:4615`); row **GH13b** pins all three measurements with the id-less bench as its paired control, so the fix reddens it. **104 of 104** tracked `.state` files still round-trip byte-identically with **zero** analysis rows carrying `id`. `test_ase_dialogs` **37 / 322 → 37 / 340**; sixteen sabotages, every GH row witnessed, four of them reddening rows in sections this change did not write. **The Measurements dropdown and the editable `id` field stay open, and issue 1444 with them** — the editable field is blocked by the `emit_check` defect above. See `doc/claude/issues/1448-the-handle-is-visible-and-the-second-row-of-a-type-is-reachable.md`.

~~**The next free number is 1448.**~~ superseded: **1448** is filed, above.

- **1449** — **Naming an analysis stopped the bench running.** ⚖ **R6**'s tail, found by issue **1448**'s task in the half that shipped before it. Issue **1447** gave an `analyses` row an optional `id` — the handle that makes two `dc` rows separately addressable, the thing issue 1444 exists to let a user *see* — and added it to the row and **not** to the one reader that decides which row keys are legal: `ase::analysis_emit_check`'s `set known [list type enabled x]`. `x` was there and `id` was not, so the check answered `unknownkey id` and `ase::preflight_gate`, which runs it over every **enabled** stored row before a run, answered `emit_incomplete`: **a user who named an analysis and switched it on could not run the bench** — no deck, no raw, no log, and the sentence ends *"`set ase_preflight 0` does NOT disable this check."* ⚠ **THE REFUSAL WAS NOT MERELY EARLY, IT WAS EMPTY**: the id-ful and id-less benches render the **same deck byte for byte** (`dc V2 0 1.8 0.01`), so the gate was withholding a deck it had no complaint about. ⚠ **IT SURVIVED 622 GREEN CHECKS AND A CLEAN T1 BECAUSE NO ROW ANYWHERE ENABLED A ROW CARRYING AN `id`** — section HN declares ids and never enables, section EK enables and never declares one, and for the first time in this batch **the two halves lived in different files**; `EK6`, the corpus invariant written for exactly this, could not see it either, because **no committed bench carries an `id`**. The fix is one word (`src/ase.tcl:4640`), and `id` is exempt for the **opposite** reason to `x`: `x` is exempt because it emits, `id` because it is a **name** and not a setting at all. ⚠ **NOT GENERALISED INTO "IGNORE UNKNOWN KEYS"** — `DECISIONS.md` **D4** says exactly two optional per-row keys, and sabotage **s2** (the over-wide fix) reds `EK7c` **and `GR9`**, the 1418 row in a section this change did not write. `test_ase_core` **622 → 624** with **EK7** (an ENABLED row carrying an `id` walked to a rendered deck **in one expression**) and **EK7c** (the over-width control), `ALL PASS` on both arms; **104 of 104** tracked `.state` files still round-trip byte-identically with **zero** rows carrying `id`; **no new state key, no schema bump**. ⚠ **`test_ase_dialogs` row `GH13b` GOES RED BY DESIGN** — it was written to pin this defect and says so — and needs rewriting in a file this change could not touch. ⚠ **THE SAME BLINDNESS EXISTS A SECOND TIME**, in `src/ase_window.tcl:5824`/`:5973`, where the Options subdialog's `skip` list knows **neither** `id` **nor** `x`, so `Options…` on a row carrying either refuses to save; `x` has been that way since issue **1419**. It is owed its own number. See `doc/claude/issues/1449-naming-an-analysis-stopped-the-bench-running.md`.

~~**The next free number is 1449.**~~ superseded: **1449** is filed, above.

- **1450** — **The Options editor refused every row that carried a name.** Found by issue **1449**'s task and left for a crew with the right file. `DECISIONS.md` **D4** licenses exactly **two** optional per-row keys, `id` (⚖ R6's handle) and `x` (issue 1419's verbatim hatch) — and **three** places kept a list of *"keys on an analysis row that are not settings"*, and the three **disagreed**: `ase::analysis_emit_check` knew both, while the `Options…` subdialog's **reader** (`ase::ui::chana_options`) and its **writer** (`ase::ui::chana_x_ok`) each knew `type enabled` plus the declared fields and nothing more. Measured through the real widgets: the subdialog listed `{id vinsweep}` and `{x {{echo hi}}}` as free-text NAME/VALUE pairs and OK then answered `ase: this dc analysis has a setting named 'id' that ASE-L cannot emit` and **returned** — subdialog left standing, nothing written, **the editor unusable on that row**, and the one gesture that did get an OK out of it was **deleting the name**. ⚠ **`x` HAD BEEN IN THAT STATE SINCE ISSUE 1419** and nothing noticed, because each of the three sites was right about itself. ⚠ **THE WRITER'S HALF WAS SHARPER**: its strip loop deletes every key not in `skip` before write-back, so a `skip` without `id`/`x` **destroys both** — latent only because the refusal fired first. **The structural defect is that the list was COPIED at all**, so the fix is **one proc** — `ase::analysis_nonsetting_keys`, in the schema namespace (**D34**–**D37**) — and **three callers**, plus row **NS2**, a SOURCE scan of both files that goes red the day a **fourth** copy appears (a runtime row cannot see a copy that is correct on the day it is written). ⚠ **NOT WIDENED**: `Add` still refuses `id` and `x` (**NX4**), and a genuine stray on the same row is still refused at OK and named (**NX3**). `test_ase_core` **624 → 626**, `test_ase_dialogs` **37 / 340 → 37 / 346**, and the display arm goes **2 FAILED (338 passed) → 1 FAILED (345 passed)** — row **`GH13b`**, written by 1448 to pin 1449's defect and red since 1449 landed, is **rewritten to assert the fixed behaviour** with a third state added as its non-vacuity control, and the one remaining red is the standing `G2sens` (issue **1436**). **104 of 104** tracked `.state` files still round-trip byte-identically; **no new state key, no schema bump, no new user-facing sentence** — one stops being shown. ⚖ **R9** is filed for the one question this leaves: whether `Options…` should *tell* the user their row carries a name (recommended **A**, say nothing new — the handle is already in the `Handle` column of the dialog whose button opened the subdialog). See `doc/claude/issues/1450-the-options-editor-refused-every-row-that-carried-a-name.md`.

~~**The next free number is 1450.**~~ superseded: **1450** is filed, above.

- **1451** — **A measurement could not be created, and a gain margin could not be measured.** Stage 8 task 2 (`PLAN.md` §8b). Issue **1443** shipped the whole DECK half of Stage 8 — a `measurements` state list, eighteen kinds, a four-verdict refusal evaluator, the `meas` speller, five producers and a sidecar — and **built no widget**: nothing read a kind's `label`, **`ase::meas_report` had no caller anywhere in the tree**, and `grep -rn measurements src/ase_window.tcl` returned nothing, so a user could not create one measurement row without hand-editing a `.state` file. This is `Outputs > Measurements…` — a list with an **Enable / Name / Kind / Analysis / Value** grid, Add / Delete / Up / Down, a **Kind picker** rendering the adapter's declared labels, a form built from the picked kind's declared fields, a **`Measured on`** control so nothing the deck can carry is unshowable, the selected row's **verdict sentence**, and the **eight named templates** behind `From Template…`. ⚠ **AND §8b's GAIN-MARGIN LINE ANSWERS NOTHING.** `meas ac gm find vdb(out) when vp(out)=-180`, measured on **both** binaries against a three-pole amplifier whose phase really does pass through −180, reports `out of interval` — because **`vp()` is WRAPPED**: on that same sweep the point whose continuous phase reads `-2.36596e+02` has `vp(out)` reading `+1.234040e+02`, so −180 is exactly the discontinuity. `WHEN cph(v(out))=-180` answers `no such vector` (the WHEN operand must be a vector NAME), so the working form needs `let gmph = cph(v(out))` first — the **19th kind `cphase`**, a `letform` kind that `yields vector`, which moves two of 1443's own rules narrowly: `meas_group` prints a `let` row only when its kind yields a NUMBER (one line per frequency point otherwise), and `ase::meas_schema_errors` permits `yields` on a letform kind. ⚠ **AND THE 57.2958× TRAP, MEASURED ON THE FINAL NUMBER**: the same rendered block run twice on both binaries gives `pm = 5.614170e+01` with `set units=degrees` and `pm = 1.778383e+02` without it — a 56-degree phase margin reported as 178, at rc 0, with the gain-margin row silently vanishing beside it. **Three corrections to §8b's table**: the gain margin above; phase margin cannot name two rows `pm` (ASE-L refuses a duplicate name — the measured phase is `pmph@n@` and the margin `pm@n@`); and *"Slew rate"* as written emits a **delay in seconds**, so the template writes `srt@n@` plus a `param` row `sr@n@ = (hi-lo)/srt@n@`. ⚠ **`@n@`, the batch suffix, is the load-bearing part** — a template's rows refer to each other, so one suffix is chosen for the WHOLE batch and a second phase margin becomes `ugf2`/`pmph2`/`pm2` with `let pm2 = 180 + pmph2`. The dropdown stores **`id <handle>`** (⚖ R6) and never `row <index>`, closing issue **1444**'s first surface; `ase::analysis_handle_text` became a **caller** of the new `ase::analysis_handle_line` so `(off)` keeps one spelling. **The Value column is the simulator's printed text verbatim** — apt 45.2 prints `9.149274e+05` where the fork prints `9.14927e+05` — and **a failed measurement renders its sentence**, because an empty cell reads as zero and a failed `meas` is silent on rc, on `$sim_status`, on `display` and on `print`. `test_ase_core` **626 → 636** (section MT), `test_ase_meas_1443` **100 → 113** (section TP), `test_ase_dialogs` **37 / 346 → 37 / 361** (section MS, display arm), the one red still the standing `G2sens` (issue **1436**). **104 of 104** tracked `.state` files still round-trip byte-identically; **no new state key, no schema bump**. ⚖ **R9** is filed for the new copy and a **`look`** debt for the pixels — `PLAN.md` §8's *"no look debt is filed"* is the stale half of that paragraph. See `doc/claude/issues/1451-a-measurement-could-not-be-created-and-a-gain-margin-could-not-be-measured.md`.

~~**The next free number is 1451.**~~ superseded: **1451** is filed, above.

- **1452** — **An S-parameter bench whose state could not say `sp`.** Stage 9's DECK half (`PLAN.md` §9). **Four S-parameter benches are committed in this repository** — `ihp-sg13g2/xschem_libs/sg13g2_tests_ase/sp_{mim_cap,rfmim_cap,parasitic_cap,svaricap_test}` — whose sources carry `portnum 1 z0 50` and whose ASE-L state holds **only the four seeded rows**, none of them the analysis the bench exists for, because ASE-L had no way to say `sp`. A port is an **ordinary voltage source carrying `portnum`** (`vsrc.c:31-37`) and the founding doctrine forbids writing that onto the schematic, which is why `design-B` concluded the analysis was unsatisfiable [crit §C11]. It is satisfiable **at run time**: `alter <src> portnum = N` / `alter <src> z0 = R` immediately above the card, measured rc 0 on apt 45.2 **and** on the fork with two *ordinary* V sources. ⚠ **THE SAME LINES BELOW THE CARD KILL THE PROCESS** — `Error: No RF Port is present, cannot run sp analysis` + `ERROR: fatal error in ngspice, exit(1)`, `span.c:376-386`'s `controlled_exit(EXIT_BAD)` — so every analysis after `sp` dies with it, **`op` included**, and `two_ports` is a **fatal** evaluated over the TABLE rather than over the netlist. ⚠ **AND `sp` EMITS AFTER `op`, WHICH AMENDS ISSUE 0964 BY MEASUREMENT**: promoting a source to a port adds a `z0` series resistance that changes every other analysis (`op` reads `v(in) = 1.000000e+00` before and `6.250000e-01` after) and **cannot be undone** — `alter v1 portnum = 0` answers `Internal Error: incomplete CKTunsetup()` + `exit(1)` on both binaries. 0964's rule is about which vectors land in which plot; this is about whether a printed number is true. `emitorder 95` beats op-last's 90 and non-op-last's 0, so **no change to `ase::analysis_emit_rank`**. New registry key **`setup`** — `key`/`noun`/`min`/`fields` are SCHEMA, `lines`/`post`/`check` are the adapter's (D34–D37) — with four core readers that COUNT the table and never look inside an entry; `ports` is therefore a legal row key on an `sp` row and an `unknownkey` everywhere else, **without** a third entry in `ase::analysis_nonsetting_keys` (D4). ⚠ **A NARROWED SAVE LIST SILENTLY REMOVES THE WHOLE ANSWER**: `.save v(mid)` + `sp` is rc 0 with the `SP Analysis` plot holding `frequency` and `mid` and no S, Y or Z at all — hence `resultvecs own`. **Touchstone export** is `let Rbase` / `wrs2p` / `unlet Rbase`, **not** APPENDIX §2.11's `.csparam Rbase=50`: measured identical files on both binaries, and without the `unlet` the results file grows a `16 rbase notype dims=1` column (`No. Variables: 21` against 20). ⚠ **THE BRIEF'S `mislabel` QUESTION IS ANSWERED NO**: `mislabel` compares PLOT names, `Plotname: SP Analysis` is byte-identical on both binaries, and both of its comparisons are case-**in**sensitive by construction — the mixed case lives in the VECTOR names (`S_1_1` on the fork, `s_1_1` on apt 45.2), which this half ships no reader of, pinned by row SM5. **Five corrections to the plan**: `lin_two` is not shipped (`lin_points` already covers it as a ⚖ D47 caution); the emit order above; `sp` declares a `viewrank` where `tf`/`pz` do not, because `src/save.c:889` aliases `sp`→`ac`; the export route; and the `mislabel` premise. New suite **`test_ase_sp_1452`** — **41 checks, identical on both arms**, whose section SE renders the deck, **runs it on both binaries** and reads `S_1_1` back (issue **1449**'s lesson); registered in `run_regression.tcl`'s `hcases`. Twelve sabotages, every one reddening by name. `test_ase_core` **636**, `test_ase_meas_1443` **113**, `test_ase_preflight` **235** — their `sp` fixtures moved to `pss`, the last shipped probe-only type. **104 of 104** tracked `.state` files round-trip byte-identically; **no new top-level state key, no schema bump**, `src/ase_window.tcl` untouched. See `doc/claude/issues/1452-an-s-parameter-bench-whose-state-could-not-say-sp.md`.

~~**The next free number is 1452.**~~ superseded: **1452** is filed, above.

- **1453** — **ASE-L's probe decks took over the user's `File > Open Recent`.** Found by Stage 9's crew in passing, **verified read-only by the driver**: the menu holds **ten entries and not one is the user's** — every one an ASE-L capability-probe scratch deck under `~/.xschem/simulations/.ase_probe/pNNNN_N/probe_a.sp`, across four pids, all pointing at directories that no longer exist. ⚠ **Second time this file has been damaged**; issue **0924** was the first, and that one was a stale binary on `PATH` rather than this tree's own code. Mechanism read rather than guessed: `src/xinit.c:3546` sets `no_recent_files` for `--nogui`/`--pipe`/`--norecent`, and its own comment (issue **0119**) says the suppression lasts **for the duration of the `--script` body** and is **restored before the event loop** so that a human's later loads record normally. The probe is on the wrong side of that: a `--pipe` run **with Tk** reaches the event loop with the gate back at 0. A `--nogui --pipe` run provably cannot do it — md5 unchanged across one. **The fix belongs in ASE-L, not in the gate**, and ⚠ **the ten existing entries are the USER'S to repair** — nothing here touches `~/.xschem/`, which is the rule 0924 wrote. `rule` debt filed with four options, **A recommended** (the probe suppresses the flag around its own loads). See `doc/claude/issues/1453-ase-l-probe-decks-took-over-the-users-open-recent.md`.

~~**The next free number is 1453.**~~ superseded: **1453** is filed, above.

- **1454** — **A ports table with no widget, and the one editor that saw it destroyed it.** Stage 9's **GUI half** (`PLAN.md` §9a/§9b), the second of Stage 9's two tasks. Issue **1452** made a `setup` table EMIT and built **no widget**: `ports` was a row key with no surface anywhere, so the only way to put a two-port table on a bench was to hand-edit a `.state` file — and the one editor that DID see the key was broken by it. ⚠ **MEASURED THROUGH THE REAL WIDGETS on an `sp` row carrying a two-port table**: the `Options…` subdialog listed *the whole table* as one free-text NAME/VALUE pair and OK then refused it as a setting ASE-L cannot emit, subdialog standing, **bytes changed = 0**. That is issue **1450**'s defect for the **third** time — `ports` is licensed on ONE type rather than on every row, so it is deliberately not in `ase::analysis_nonsetting_keys` and both sites asked only that proc; and the writer's strip deletes every key not in `skip`, so it would have **destroyed the table** on any commit that got past the refusal. Both sites now also ask `ase::analysis_setup_key`. **§9a** ships `ase::ui::setup_dialog` — the row's own table, an Add/edit/Delete entry row, the live refusal, `Add from Schematic…` and OK as a **commit door** that refuses any table `ase::needs_eval` would refuse (an EMPTY table goes through: untouched state, not a wrong answer). **Every word of it is the registry's** — `Source`/`Port`/`Z0 (ohm)` are the ADAPTER's declared `columns`, the button/title/caption are composed from its declared `noun`, and row SP3 asserts `ase_window.tcl` spells none of them. **§9b** ships `ase::ui::matrix_dialog` — one cell per vector the run will answer, laid out as the matrix it is, four formats, writing ordinary `{name expr plot save}` Outputs rows. ⚠ **THE MATRIX IS A TRANSCRIPT AND `evidence/sp-stage9.md` IS ONE FAMILY SHORT**: measured on both binaries, a two-port row answers **12** vectors in `S`/`Y`/`Z`, a three-port row **27**, and the noise flag adds **NF NFmin Rn SOpt *and a `Cy_i_j` noise correlation matrix*** — 20 in all. `Cy` is typed `current`, so ngspice writes it `i(Cy_1_1)` and `wviewer::validate_rpn` **rejects the bare name on both binaries**; a matrix entry therefore carries `vector` AND `expr`. ⚠ **ROW SM5's JOB CHANGED HANDS**: it asserted the ABSENCE of any reader of the S-parameter vector names so that whoever added one had to choose between folding and a red suite. `ase::raw_vectors_present` folds, answers in the DECLARED spelling and strips ngspice's own `v(…)`/`i(…)`; SM5 is **rewritten, not deleted**, and sabotage s1 (a case-sensitive fold) reds it, SX9 **and `SP14/apt`** while leaving the fork green — which is the whole case for the two-binary rule. ⚠ **§9b's SMITH CHART CANNOT BE DRAWN IN THIS TREE**: `grep -ri smith src/*.c src/*.tcl` prints NOTHING and `polar` matches only `bipolar`, so the four offered formats are the viewer's own RPN (`db20()`, `cph()`, `re()`, `im()`, each measured accepted against BOTH binaries' variable lists, with `S_9_9` and `nosuchfn()` as controls) and the chart is recorded as outstanding. ⚠ **AND §9a's SCAN RULE IS REFUTED BY THE STAGE'S OWN HEADLINE CASE**: "only sources that already declare a `portnum`" offers **nothing** on a bench of two ordinary V sources, which is the bench Stage 9 exists for — so the scan offers every **top-level voltage** source (no current sources, no subcircuit sources, no duplicates) and the declaration buys the **prefill**. It PEEKS and never netlists: a cold bench gets the precondition banner's own cold sentence. New suite rows: `test_ase_sp_1452` section **SX** + the rewritten **SM5** (41 → **50**, both arms), `test_ase_dialogs` section **SP** (37 / 362 → 37 / **382**, display arm), whose **SP14** takes a port typed into the table through the real widgets all the way to a rendered `alter` line and a **real run on both binaries** that answers `S_1_1` (issue **1449**'s lesson). **Twenty-seven sabotages, twenty-six red by name and one behaviour-preserving survivor**, and four of them found a defect in the SUITE rather than in the product: a read that raises kills a GUI suite at rc 0 instead of reddening a row, and it happened three times in one section. **104 of 104** tracked `.state` files round-trip byte-identically; **no new top-level state key**. Also corrects `test_ase_dialogs` GN1b, whose title had said `sp` was one of *"the two unrenderable cells"* since 1452 made it false (receipt 32's C8). See `doc/claude/issues/1454-a-ports-table-with-no-widget-and-an-editor-that-destroyed-it.md`.

~~**The next free number is 1454.**~~ superseded: **1454** is filed, above.

~~**The next free number is 1455.**~~ superseded: **1455** is filed, above.

- **1455** — **X7 of `test_ase_optier_0963` kills a real ngspice run, and it has now cost T1 twice.** ⚠ **AND IT IS NOT A FLAKE.** Row X7 drives a real sky130 bench through ngspice and reads three answers back. Under a **solo** `run_regression.tcl` on 2026-09-13 it read `{0 0 0}` against `{1 1 1}` — the shape of *the run produced nothing* — and cost T1 two counted lines; re-run standalone on the same tree minutes later it read `rc=0 raw=284381bytes op-vectors=891`, **ALL PASS (108)**. **Measured six ways on one unchanged tree: it fails 2 of 3 inside T1 and 0 of 3 outside it** — and one of those outside runs is byte for byte the invocation `run_regression.tcl:309` builds (no `--nolog`, cwd `tests/`), so **the command is not the variable**. An intermediate draft called it deterministic under T1; the third T1 run refuted that and the claim was withdrawn rather than kept. `rc=1` is the fact that survives: the simulator **ran and exited 1** rather than never starting. ⚠ **The suite's own header already calls X7 a flake (`:104`) and that note no longer covers it**: this ledger's Stage 2 block records the same row costing T1 the same two lines once before, but **that** occasion had four of the batch's own ngspice processes live — the condition `CLAUDE.md` names — and **this one had nothing else alive**. T1 is the one suite whose baseline is ZERO, so a row that fails perhaps one run in five smears the only signal that would show a real regression. ⚠ **Nothing captures ngspice's own stderr on the failing path**, so a failure costs a whole run to reproduce and explains nothing when it does; the recommendation is therefore **diagnostic before stable** — print the run's last lines when the answer is missing, and only then consider a bounded retry. Not a T1 timeout: `t1_why` turns rc 124 into a counted FAIL that says `TIMED OUT`, and this did not. See `doc/claude/issues/1455-a-flaky-row-in-the-one-suite-whose-baseline-is-zero.md`.

~~**The next free number is 1456.**~~ superseded: **1456** is filed, above.

- **1456** — **Three suites in T1's case list have never emitted a completion banner, so T1 has not been at zero since stage 7.** `test_ase_optsheet_1441` (both arms), `test_ase_effective_1442` and `test_ase_meas_1443` each end with a `RESULT:` line and **no `OVERALL:` line at all**; `banner_rule.tcl`'s `banner_complete` requires a whole-line `OVERALL: ok`, so `run_regression.tcl` has scored each of them a HARNESS failure on every run since it joined the list (`f91c36ae`, `1a5fefec`, `3f31a33b`) — **four counted lines, every time, with every one of their own checks green**. `git log -S'OVERALL'` on all three prints nothing: they never had one, and a sweep of every case in both of T1's lists finds exactly these three. Fixed with the one line 131 other sites already use. ⚠ **The reporting failure is the larger half**: `run_regression.tcl` prints only `Start`/`Finish` to stdout, **exits 0 whatever happens**, and writes its verdicts to **`tests/results.log` and nowhere else** — the driver grepped the stdout capture, found no `FAIL`, and reported "zero counted failures" four times in one day, once recording that `FAIL`/`FATAL`/`TIMED OUT` *"appear zero times in the log"* as a measurement, of strings that cannot appear in that file. **T1's answer lives in `tests/results.log`.** This is issue **0689**'s family inverted — there the reader was too strict for a banner that existed, here three suites emit none — and 0689 was filed four times and waved through each time. See `doc/claude/issues/1456-three-suites-in-t1-have-never-emitted-a-completion-banner.md`.

~~**The next free number is 1457.**~~ superseded: **1457** is filed, above.

- **1457** — **The matrix picker hides the `Cy` family on any run with more than two ports.** `ase::backend::ngspice::sp_matrix` adds the `Cy_i_j` noise correlation matrix only when the noise flag is set **and** the port count is exactly 2. Measured on **both** binaries, four decks, counting the rawfile's `Variables:` block: 2 ports flag-off **12**, 2 ports flag-on **20** (12 + 4 `Cy` + 4 scalars), 3 ports flag-off **27**, 3 ports flag-on **36** (27 + **9** `Cy` + 0 scalars). **`Cy` follows the noise flag at ANY port count, N×N; only the four scalars are restricted to N == 2.** So a three-port row with the flag on writes 36 vectors and ASE-L offers 27 — nine the user is never shown, which is the exact defect class issue **1454**'s receipt named in order to avoid it. ⚠ **The row that should have caught it asserts the defect**: `test_ase_sp_1452.tcl` **SX2** says *"the noise families do NOT appear on [a three-port row] even with the flag on"* and is green and wrong, so receipt 33's sabotage **s4** was scoring a move TOWARDS correctness as caught. The caution sentence is **not** wrong — it names only `NF`, `NFmin`, `Rn` and `SOpt`. Found by the driver re-measuring a crew's own correction before appending it to `evidence/sp-stage9.md`, on the one shape the crew's table did not contain. See `doc/claude/issues/1457-the-matrix-picker-hides-a-family-a-three-port-run-really-produces.md`.

~~**The next free number is 1458.**~~ superseded: **1458** is filed, above.

- **1458** — **Every GUI suite run overwrites the user's `~/.xschem/geometry`, and nothing gates it.** `store_geom` (`src/xschem.tcl:16062`) writes `$USER_CONF_DIR/geometry` **unconditionally** — there is no `no_recent_files`-style guard on it and no flag that reaches it, so a `--pipe` run **with Tk**, which is every display-arm suite, records its scratch windows into the user's own file on exit. The sibling that **is** gated is `update_recent_file` (`xinit.c:3546` + issue **0119**), so the two halves of *"this run's windows are not the user's windows"* are half implemented. ⚠ **And it displaces like the recent list**: keyed by filename, **capped at the 100 newest**, so a suite's scratch schematics push the user's entries out — 1453's mechanism with a bigger number and a slower fuse. **Measured as a natural experiment rather than a contrived one**: after 1453 landed, two display-arm runs and two solo T1s left `recent_files` frozen at **18:53** and moved `geometry` to **19:24** — same runs, same binary, one gated file and one ungated one. ⚠ **Milder than 1453** (window positions, not a menu the user reads) and **filed rather than fixed**, because option A has a real cost: after it, a deliberate `--pipe` GUI session the user *wanted* remembered would stop being remembered, and whether that case exists is the ruling. Found while collecting **1457**, after the driver's own first reading of it — *"what any interactive xschem does on exit"* — was wrong: a suite is not a user, which is the entire point of the 0119 gate. See `doc/claude/issues/1458-a-suite-run-overwrites-the-users-window-geometry.md`.

~~**The next free number is 1459.**~~ superseded: **1459** is filed, above.

- **1459** — **The simulator said which nodes would not converge, and nobody ever read it.** `grep -c 'CKTncDump\|Last Node Voltages\|optran\|wrnodev' src/ase.tcl` returned **zero**. `CKTncDump` prints a `Last Node Voltages` table with a trailing ` *` on every node still failing the convergence test (`cktncdump.c:23-39`) — `evidence/convergence.md`'s *"single most useful diagnostic in ngspice"* — the four-rung ladder is on **stderr**, and `optran`, the fourth rung, is **ON BY DEFAULT** and hands back the **transient state at its stop time** as the operating point: measured on **both** binaries, a 1 kΩ / 1 nF RC answers `1.000000e+00` from a real solve and **`9.999550e-01`** from that rung. ⚠ **Four more accepted-and-inert cases, all at rc 0**: `.options optran …` does nothing (`optran` is a COMMAND, absent from `OPTtbl[]`); `optran`'s first three arguments **silently override** `.options noopiter/gminsteps/srcsteps` on the same task; a transient step above `finaltime/50` is **silently replaced**, and one above `finaltime` draws `Error in command 'optran'` and **still exits 0**; and **`rusage devtimes` prints nothing in any stock build** — `resource.c:322` reads counters written only inside `#ifdef PER_DEVICE_STATS`, and `cktload.c:30` is the literal line `// #define PER_DEVICE_STATS` — which is the very command PLAN.md §10c names for the health strip. ⚠ **And the "fastest fix" silently changes the answer**: `wrnodev` writes `.ic`, and `.ic` in a transient operating point is a clamp that is never released (`cktload.c:146-173`) — the same bench one edit later starts at **2.500000e+00** with the file included and at **1.500000e+00** without it and with the same values re-spelt `.nodeset`, rc 0 and silent in all three, on both binaries. Fixed in `src/ase.tcl` only: three `omit_if_empty` state keys, the parsers and emitters in core, every simulator word in the adapter, and refusals rather than cautions at the form and again in `render_deck`'s third tier. New suite `tests/headless/test_ase_converge_1459.tcl`, **76 checks both arms**, whose section EE runs the real thing on both binaries and asks the **surplus** question (issue 1457's lesson: a row that runs the real thing is not automatically a row that would notice). `test_ase_core` **636 → 638**. See `doc/claude/issues/1459-the-simulator-said-which-nodes-would-not-converge-and-nobody-read-it.md`.

~~**The next free number is 1460.**~~ superseded: **1460** is filed, above.

- **1460** — **The convergence diagnostics had a parser and no surface.** Issue 1459 landed four parsers, three emitters, two refusal evaluators and eleven ngspice adapter hooks, and **built no widget**: `ase::ncdump_failing` knew which nodes had failed the convergence test and **nothing lit them**, `ase::ladder_parse` knew which rung answered and **nothing said so**, and `ase::optran_line` could only be reached by **hand-editing a `.state` file**, because `opstrategy` had no control anywhere in the program. Fixed in `src/ase_window.tcl` (plus one reader `ase::runhealth_strip` and one adapter hook `runhealth_labels` in `src/ase.tcl`): `Results > Highlight Non-Converged Nodes` maps the starred names through `ase::netlist_map`'s hierarchy-qualified resolution and **lights them on the schematic**, reporting by name and with the reason every one it could not; `Simulation > Convergence…` is the four-rung ladder pane with the emitted `optran` line beneath it; the remedy assistant previews the **deck** before and after; the run-health strip is one line in the status bar; and `ase::ladder_ran_notes`'s conditional sentence reaches the OP form. ⚠ **The checkbox really means OFF, and it is measured rather than asserted**: the deck ASE-L renders from a ticked transient rung is `optran 1 0 0 100n 10u 0` → rc 0, `v(1) = 1.413677e-02`; cleared it is `optran 1 0 0 0 10u 0` → **rc 1**, `The operating point could not be simulated successfully` — one argument apart, identical on apt 45.2 and on the fork, with Newton ON in both so the form permits both. ⚠ **And the trap that cost an hour**: `src/ase_window.tcl` defines `ase::ui::open`/`ase::ui::close`, so a bare `open $p r` in that file resolves to the WINDOW opener and — inside the `catch` a total reader needs — **returns an empty log with nothing said**; every reader here silently answered `{}` until it was `::open`. New suite `tests/headless/test_ase_conv_gui_1460.tcl`, **44 headless / 103 display**, registered in **both** of `run_regression.tcl`'s case lists; `test_ase_window` W1m gains the new menu entry. See `doc/claude/issues/1460-the-convergence-diagnostics-had-a-parser-and-no-surface.md`.

~~**The next free number is 1461.**~~ superseded: **1461** is filed, above.

- **1461** — **`show_log` leaks a file channel, because `close` is shadowed inside `ase::ui`.** Issue **1460**'s crew found that `src/ase_window.tcl` shadows **both** `open` (`:619`) and `close` (`:681`) and that a proc defined as `proc ase::ui::…` runs its body in that namespace, so an unqualified call resolves to the shadow first. They fixed the `open` at `:11078`, comment and all, **and missed the `close` on the next line.** Measured rather than reasoned, with a five-line reproduction: the shadow is entered (`SHADOW reached with key=file3`) and **`file channels` still lists the channel** — so `ase::ui::show_log` **leaks one file channel per invocation**, and `show_log` is something a user opens repeatedly while watching a run. **No state damage**: `ase::ui::close` returns at its first line for an unknown key and a channel name is never a session key, which is why nothing ever went visibly wrong. **Exactly one site** — a sweep of every unqualified `close $…` inside an `ase::ui::` proc finds this and no other. Fix: `close $fh` → `::close $fh`. ⚠ **The general rule is the part worth keeping**: any file I/O in `ase::ui` must be spelled `::open` / `::close`, and **a `catch` around the read does not save you — it is what hides the failure** (1460 measured seven of its own rows going green on an empty string). See `doc/claude/issues/1461-show-log-leaks-a-channel-because-close-is-shadowed.md`.

~~**The next free number is 1462.**~~ superseded: **1462** is filed, below.

- **1462** — **ngspice has no `.step` card, so a bench could only ever run once.** `grep -rn '"\.step"'` over the ngspice parser returns nothing and `.step param x 1 3 1` answers `unimplemented dot command '.step'` and **aborts**; there is no corner statement, no `.MC` card, no sort, no median, no percentile and no histogram. So a sweep, a corner set and a Monte Carlo run are the GUI's to generate, and ASE-L generated none — the user's own `tb_bandgap` carries `agauss(1.8, 'ABSVAR', 1)` in its `variables`, written by hand, and ASE-L ran it **once**. PLAN.md Stage 11 task 1: a `sweep` state key (⚖ **R8** Option A, the one named exception to D3, in `ase::omit_if_empty` so the 104 committed `.state` files still round-trip byte-identically), a Tcl sampler, an odometer, one process per point under `<rundir>/campaign/shard-NNNN/`, and `index.tsv` with one row per point **run or not**. **A shard is a STATE**: the point's coordinates are written into the keys they belong in (`variables`, `temperature`, `models`, `options`) and `rundir` points at the shard, so the shard's deck is `render_deck` of that state and there is no second deck writer. ⚠ **The measurement that reshaped the plan**: §11a's first-ranked mechanism, `.param rv='var(myres)'` + a per-shard `set`, is **fatal on apt 45.2** — `Undefined parameter [var]` → `Formula() error.` → `ERROR: fatal error in ngspice, exit(1)` — because `var()`/`vec()` arrived upstream in `aa1242ac7` on 2025-10-16, **50 commits after ngspice-45.2**, first shipped in ngspice-46, and the current Ubuntu LTS ships 45.2. Nothing emits it; the deck is re-rendered per shard and `campaign/deck.spice` is the **nominal** deck a shard is a one-line diff from. ⚠ **The SIXTH accepted-and-inert case**: `setseed` in `<rundir>/.spiceinit` is accepted, silent and seeds **nothing** — `main.c` reads the start-up file at `:1266-1330` and calls `initw()` (`srand(getpid()); TausSeed();`) at `:1371`, after it. ⚠ **And the seed APPENDIX §4.4 forbids is the right one here**: Trap B is about a `.control` loop that `reset`s, and a shard runner never `reset`s — `.options seed=<base+N>` per shard is reproducible, distinct per point, **identical on both binaries**, and reaches the NETLIST-level draw that `setseed` cannot. New suite `tests/headless/test_ase_campaign_1462.tcl`, **133 checks, identical on both arms**, registered in `run_regression.tcl`'s `hcases`. ⚠ **T1 caught one thing this suite did not**: the first version applied the session's simulator choice with a SECOND `ase::sim_apply_choice`, and row **S12** of `test_ase_simreg_0931` is structural and counts them. The requirement was right and the fix was in the wrong place -- every shard now goes through **`ase::run_deck`**, the body the three existing run doors already share, so a shard directory is literally a run directory and `campaign_step` got smaller. That repair then measured three more things: `ase::wait` is an unbounded `vwait` (a campaign now races it against an `after` and reports a stall as exit **124**), a killed shard strands its in-flight lock so the next campaign over the same directory is refused by a run nobody is waiting for, and a binary that never answers the capability probe pays `cap_budget_ms` **per shard** because a timed-out probe is not cached (31,296 ms for one probe against 64,420 ms for a two-point campaign with a one-second budget); `test_ase_core` and `test_ase_persist` each move their schema-key expectation 22 → 23 (two copies of one list, as receipt 36 predicted). See `doc/claude/issues/1462-ngspice-has-no-step-card-so-a-bench-could-only-ever-run-once.md`.

~~**The next free number is 1463.**~~ superseded: **1463** is filed, above.

- **1463** — **A registered binary that never answers costs the capability-probe budget ONCE PER SHARD.** Measured while repairing issue **1462**: one probe against an unresponsive entry takes **31 296 ms**, and a **two-point** campaign against the same entry takes **64 420 ms** — two shards, two full budgets. `cap_budget_ms` defaults to 30 s and **a timed-out probe is not cached**, because the cache stores an *answer* and a timeout is not one. Defensible for a single run; indefensible once the caller is a **loop** — a hundred-point campaign would spend **fifty minutes** waiting for a program that is never going to reply, and the run budget the user set governs none of it. ⚠ **ASE-L's existing behaviour, not the campaign's**: 1462's crew found it, recorded it and deliberately did not fix it, which was right, and this issue exists so it is tracked somewhere other than a receipt. For scale, `evidence/binary-differences.md` measured a **healthy** probe at ≈ **5 ms**. Four options; **A** (cache a timeout verdict for the life of one campaign) and **C** (probe once up front and refuse before any shard runs) are not exclusive, and **C is the one a user would notice** — *"this simulator did not answer"* in one second beats the same conclusion in fifty minutes. ⚠ C is a refusal, so it needs ⚖ R9 wording. See `doc/claude/issues/1463-a-dead-simulator-costs-the-probe-budget-once-per-shard.md`.

~~**The next free number is 1464.**~~ superseded: **1464** is filed, below.

- **1464** — **The campaign had a runner and no door, and no number at the end of it.** Issue **1462** shipped 44 core procs, five adapter hooks, a Monte Carlo sampler and an `index.tsv` writer and **built no widget**: the only way to put a `sweep` key on a bench was to close ASE-L and **hand-edit the `.state` file**, the only way to start a campaign was `ase::campaign_run` from the Command window, and §11c's whole claim — *"the campaign ends with a NUMBER, not a directory"* — had **no implementation at all**, because ngspice has no sort, no median, no percentile and no histogram to borrow one from. PLAN.md Stage 11 task 2: a `Simulation > Campaign…` dialog (enable, seed, an axis table, core's own note line, **Run Campaign**, **Stop**, a `k/N` readout), an axis editor built **entirely from declarations** — the kinds, their labels and their fields from `ase::campaign_axis_kinds`, the distributions and their parameters from `ase::mc_dists`, not one `switch` on a kind — and §11c's result table: `index.tsv` in full, a column picker, mean/sigma/min/max/median, a spec limit with a yield number, a **histogram** with the spec drawn on it, a **scatter of any two columns**, Export to TSV or CSV and **Re-run Point**. The twelve `ase::stat_*` procs are **core**, not the window's: a mean computed inside `ase::ui::` can only be tested on an arm that has a display, so the arithmetic that decides a yield number would be measured by half as many rows as the widget that prints it. ⚠ **The measurement that reshaped the task: `1k` is not a number.** An axis column holds what the USER typed, and `string is double` rejects `1k 2k 4.7meg` — so a histogram of a swept axis had **no bars** and a scatter **no points**, silently, on the commonest campaign there is. Which suffixes exist is the simulator's fact (D34), so `ase::stat_suffixes <sim>` resolves the adapter's `si_suffixes` hook and `{}` (plain numbers only) is the non-vacuity control; the parsing goes through `ase::si_parse`, the tree's one suffix reader, so `meg` is never read as `m`. ⚠ **And a `-` is not a zero**, and **sigma divides by n−1** — understating sigma OVERSTATES yield, the one direction this number must not err in. ⚠ **Two defects the suite found in this task's own code**: `Run Campaign` could not run from a window whose design was not current (**issue 0643's complaint on a new button**, because the routing lived inline in `ase::ui::do_run` — extracted as `ase::ui::route_design`, called by both doors), and `Run` was live on an empty form where pressing it could only say no. ⚠ **And the first canvas ASE-L has ever drawn**: `_theme_widget` had **no `Canvas` arm**, so both plots kept stock Tk grey inside a themed window — the class issue **1398** measured 58 widgets of. ⚠ **Issue 1463 reaching the screen**: the readout names the point that is **about to start**, with its coordinates, because a binary that never answers the probe costs 30 s per shard and a readout reporting the point that just finished would sit on `0 of 100` for the whole of point 1. New suite `tests/headless/test_ase_campaign_gui_1464.tcl`, **78 headless / 156 on the dev display**, registered in **both** `hcases` and `dcases`; its section EE runs a three-point resistive-divider campaign on **both** binaries and checks the measurement column against **physics** (`v(out) = 1k/(rtop+1k)` → 0.5 / 0.25 / 0.1) before checking the panel's arithmetic against that column. See `doc/claude/issues/1464-the-campaign-had-a-runner-and-no-door-and-no-number.md`.

~~**The next free number is 1465.**~~ superseded: **1465** is filed, below.

- **1465** — **A mixed-signal run's digital half never reached the window.** XSPICE is compiled into every ngspice this batch supports, so a deck with a digital gate is an ordinary deck — and an ASE-L run of one produced a rawfile with **no event node in it** (`write <f> all` omits them, silently) and nothing else, so the digital half was simulated and thrown away. PLAN.md Stage 12. **The inventory is MEASURED, not parsed**: a probe deck — the circuit the run reads, with `edisplay` and no analysis — is run with the run's own words (`run_cmd`, asked with a new `quiet` argument) in the run directory, once per distinct circuit, only for a circuit with an `a` card, and cached; `render_deck` reads only the peek. **The emission** is one `eprvcd` per 93 names (94 empties the file on both binaries) at the end of each transient's block, below the `$sim_status` guard and the `write`, to `<rundir>/<cell>_ase_evt[_N].vcd`, which `ase::last_vcdfiles` serves and `ase::run_deck` deletes first. ⚠ **Only the inventory's names, and none the lexer would split** — measured, `$` substitutes — because a non-event word on that line **aborts apt 45.2** (`binary-differences.md` #9); a dropped name is said in the CIW. ⚠ **The run end is the READER's, and it is C**: `eprvcd` ends its file on the last value change, so a held value was drawn as a trace that stops early (debt M9's pixel finding), and a deck cannot write the missing timestamp because `$&` prints 30000000 fs as `3E+07` whatever `numdgt` says — so `xschem raw read <f> vcd -end <seconds>` (`src/scheduler.c`, `src/vcd_read.c`, `src/xschem.h`) extends a VCD to a caller's run end, only ever later, and `ase::attach_dbs` passes the analog database's last time when it is a transient. **Two cautions** through a new `xspice` precondition on `tran` and `dc`, worded by the adapter's `xspice_caveat` hook with no fallback: trtol is lowered for **any** `a` card — an analog-only `gain` block prints the same line, which is wider than PLAN.md §12 said — and a DC sweep through auto-bridges fails on **both** binaries (debt **M13**, no root cause). **One refusal**: `.probe alli` beside a DIGITAL node exits 1 before anything is simulated, beside an analog-only `a` card it runs at rc 0, so it is read from the simulator's answer — by the gate when an earlier run measured it, before anything is deleted, and by `render_deck` on a first measurement, before a deck is written. ⚠ **The first cut split `run_cmd` into a silent `run_argv`, and three structural rows in other suites — `test_ase_simreg_0931` P6, `test_ase_predeck_1439` CM5/CM6 — reddened by name**, because they read `run_cmd`'s body for the router call and the word order; the body was put back and a `quiet` argument added instead. New suite `tests/headless/test_ase_events_1465.tcl`, **87 checks headless**, registered in `hcases`; its section EE runs the mixed chain on **both** binaries, with a DC sweep before the transient and a transfer function after it, so a run that died on the export line cannot hide. See `doc/claude/issues/1465-a-mixed-signal-runs-digital-half-never-reached-the-window.md`.

~~**The next free number is 1466.**~~ superseded: **1466** is filed, below.

- **1466** — **A transient could not carry noise without editing the schematic.** ngspice makes any independent source emit transient noise (`trnoise`: white, 1/f, RTS) or a held random value (`trrandom`) — the noise `.NOISE` cannot show — and ASE-L had no way to ask for it; the only door was positional arguments typed onto a source on the schematic, which the founding doctrine forbids and two shipped ngspice examples get wrong. PLAN.md Stage 13 **task 1, the DECK half**: a `noise` table on the `tran` row under a new `stimuli` registry contract (its own contract, not Stage 9's `setup`, because `src/ase_window.tcl` draws every `setup` contract as a table and task 1 must draw nothing; `ase::analysis_setup_key` now answers either contract's key, so the Options editor's two sites still skip it — `test_ase_sp_1452` SK1's fourth term moves `{}` → `noise`). **Two routes, neither touching the schematic**: `alter <src> <fn> = [ … ]` above the row's card, or a quiet carrier added right after the netlist and altered there; **all seven / all five arguments, always, positionally, padded with 0**; and a zero-`trnoise` restore below the guard. ⚠ **The restore is measured, not tidiness**: on both binaries a second transient after an altered one carried the first one's noise when nothing put it back (rms 0.84 V on a `dc 0` source). ⚠ **`PLAN.md` §13's carrier name `ase_inoise_1` is an XSPICE `a` card** (fork: `MIF-ERROR`, rc 1), so carriers are `iase_noise_<row>_<k>`. ⚠ **`trrandom` on a current source freezes**, measured on both binaries with a deterministic trigger — `trrandom(2 1u 1m 1m 0)` draws ONE value after TD where a V source draws 501, because `isrcacct.c` redraws only within 3 ulps of `n*TS` computed as `CKTtime - TD` — so an injected random current is a V source plus a 1 S VCCS and the `alter` route refuses one. **32 refusals and cautions** in the adapter (negative TS hangs the simulator — fork only, rc 124; a waveform-carrying source; an absent or digital net; the 1/f exponent; the `optran` fallback baking a draw into the transient's first point, avoided by a delay — measured on both). **Derived readouts as core arithmetic** (density `NA*sqrt(2*TS)`, the point estimate worded as one — the binaries give 5008 vs 4415 points — and file bytes at 8 a value, measured). **The seed sentence split by kind as data** (white/1-f never repeat, RTS/`trrandom` repeat under `.options seed=` or `setseed`, verified against both binaries in-suite) and the `notrnoise` kill split. `alter` does not survive `reset` (no ASE-L deck resets). New suite `tests/headless/test_ase_trnoise_1466.tcl`, **62 checks, identical on both arms**, registered in `hcases`; section EE runs the rendered deck on both binaries and reads it back with a second ngspice. See `doc/claude/issues/1466-a-transient-could-not-carry-noise-without-editing-the-schematic.md`.

~~**The next free number is 1467.**~~ superseded: **1467** is filed, below.

- **1467** — **The transient noise table had a deck and no form.** Issue **1466** made a transient able to carry noise with no schematic edit and drew nothing: the only way to put a table on a bench was to hand-edit the `.state` file, and the density, the point estimate, the seed sentence and 32 refusals reached no screen. PLAN.md Stage 13 **task 2, the GUI half**: a **noise section on the Tran form**, folded shut, one line per entry showing the values the deck writes (positionally, padded), an **Add** row that offers only the targets the adapter's own target check accepts **for the function chosen** (a current source for noise, never for a random value), an editor **bound to the entry** so there is no half-typed row for OK to drop, **live estimates** under it (density, flat-to, points, and a results-file size once a run has given a vector count — read from the last run's header through the plotmap, never guessed), **per-entry verdicts** in the precondition banner's shape, and the seed and kill-switch sentences **verbatim** from core's reports. OK commits the table **only when it changed** and **refuses** a changed table the run would refuse; the Arguments column counts the entries that reach the deck; the `notrnoise` Options-sheet row now names the per-kind split. ⚠ **A measurement corrected issue 1466's hand-over**: `facts nodes` is **not a net list** — `ase::netlist_map` files every token after a device name, so `dc`, `1k`, `sin(0` and a MOS model name all read `present` — so the adapter reads nets from the netlist **text** by device letter, and the target rules were split out of `noise_entry_check` so the offer and the refusal are **one body**. Two new contract legs (`candidates`, `kill_sentences`), five core readers, no simulator word in `src/ase_window.tcl` (linted). New suite `tests/headless/test_ase_trnoise_gui_1467.tcl`, **19 checks headless / 63 on the dev display**, registered in **both** `hcases` and `dcases`; its section EE types noise into the form, runs the deck on **both** binaries and checks the form's file-size estimate against the file the run wrote. See `doc/claude/issues/1467-the-transient-noise-table-had-a-deck-and-no-form.md`.

~~**The next free number is 1468.**~~ superseded: **1468** is filed, below.

- **1468** — **The "gigabytes and hours" caution goes silent at four billion points.**
  `ase::analysis_point_estimate` reads the adapter's estimate through `string is integer -strict`,
  which on Tcl 8.6.17 is false from 2³² (4 294 967 296) up, so §7g's size caution, the Tran form's
  noise estimate and the noise check's base all lose their answer for the largest runs.
  Checkpointing is unaffected. Found by Stage 13 task 3's crew, boundary measured by the driver.
  OPEN.

~~**The next free number is 1469.**~~ superseded: **1469** is filed, below.

- **1469** — **A campaign seed outside ngspice's range runs unseeded and says it was seeded.**
  ngspice honours `.options seed=` only for 1 … 2147483647 — it refuses 0, negatives and
  2³¹ … 2³² with one warning and runs unseeded, and wraps larger values — identically on 45.2 and
  the fork. ASE-L accepts 0 … 4294967295 and writes `seed + shard index` per shard, so a campaign
  can report seeded shards that ngspice ran unseeded. Driver-measured. OPEN.

~~**The next free number is 1470.**~~ superseded: **1470** is filed, below.

- **1470** — **A build that cannot do what ASE-L offers is never named, and a command line that
  crashes it gets no warning.** `unset temp` in a pre-command aborts apt 45.2 at rc 134 with the
  log destroyed and no sentence anywhere; the probe measures what each build lacks and ASE-L says
  none of it; an ASE-L run never sent `-D casemodewrite` (debt M21); and a build with an unsound
  dump printer is told the wrong reason for its long deck. Stage 16 task 1 of the ASE-L analyses
  batch. Checked free in every clone on this machine before minting. OPEN.

~~**The next free number is 1471.**~~ superseded: **1471** is filed, below.

- **1471** — **The Simulators window never says what the program in front of it can do, and no page
  says what works on which ngspice.** Issue 1470's sentence reached the run log only — once per
  session, and only when something was missing — so the row editor where a user registers a build
  and presses Detect said nothing about the fast operating-point dump it lacks or the command lines
  it misreads, and a person deciding whether ASE-L works with the ngspice they already have had
  nothing to read. Stage 16 task 2 of the ASE-L analyses batch. Checked free in every clone on this
  machine before minting. OPEN.

~~**The next free number is 1472.**~~ superseded: **1472** is filed, below.

- **1472** — **Two co-simulation installation defects were measured, characterised, and said to
  nobody.** Issue 1470 shipped `ase::backend::ngspice::scripts_dir_of` and `cosim_shim_verdict` —
  the parse rule and the two installation greps of PLAN §16c — and **nothing called them** (1470's
  own correction C6). So a `vlnggen` that does not link the VCD runtime, which makes a `--trace`
  Verilator build fail its final link and arrive as "my wrapper won't link", and a
  `verilator_shim.cpp` whose model holds a non-owning pointer to a `VerilatedContext` destroyed
  when `Cosim_setup()` returns — use-after-free for the whole simulation — both still reached no
  user. No probe leg collected `$sourcepath` either, so nothing knew which installed tree to read.
  Stage 16 task 3 of the ASE-L analyses batch. Checked free in every clone on this machine before
  minting. OPEN.

~~**The next free number is 1473.**~~ superseded: **1473** is filed, below.

- **1473** — **The stop warning still says a run is discarded, after Stage 6f made that untrue.**
  `ase::run_stop_warning` is emitted by both its callers with no test of the run's checkpoint plan,
  so a transient that Stage 6f checkpoints is still told stopping discards it, while
  `ase::ckpt_report` afterwards says what was kept. Debt **M18**'s unfinished half; the ledger says
  M18 is closed in one place and open in two. Driver-measured at `d761b630`. OPEN.

~~**The next free number is 1474.**~~ superseded: **1474** is filed, below.

- **1474** — **The post-stop message still says nothing was written, seconds before the checkpoint
  report says what was kept.** Issue 1473 made the LAUNCH warning true for a checkpointed run;
  `ase::run_stopped_msg` (`src/ase.tcl:16960`) takes one argument and was left composing *"nothing of
  this run was written"* unconditionally, its sole caller (`src/ase_window.tcl:12548`) passing only the
  simulator. So after 1473 the two messages of one run **disagree**, where before they agreed and were
  both wrong. Carries the `pss` and `sp` rows issue 1473's CK28c does not hold. Found by 1473's crew,
  confirmed by its independent verifier, filed by the driver at `df5df4fe`. ⚠ **This row was written
  late** — the pointer was advanced to 1475 in the 1473 commit without filing the block beneath it,
  which is the same stale-summary defect as the ledger's *Still open and named* line. OPEN.

~~**The next free number is 1475.**~~ superseded: **1475** is filed, below.

- **1475** — **`pss` is declared by every released ngspice built with it, and converges in none of
  them.** On `/usr/bin/ngspice` (45.2) PSS converged on **nothing measured** — twenty cases, zero
  convergences, including ngspice's own shipped `examples/pss/ring_osc_pss_ctrl.cir` with its own
  arguments — returning **rc 0** with both plots full and a frequency **~2.6 % high**. The
  convergence fix `668329ca3` is in **no release tag**, so every released ngspice with PSS has the
  broken one, and `help pss` answers identically on both binaries, so the capability probe cannot
  tell them apart. Also records the **four-argument SIGSEGV** (rc 139, both binaries, no salvage,
  takes `op` with it) and that a **non-existent `oscnode` moves f0 by 0.46 %** while real nodes
  steer nothing. ⚖ **R7 REVERSED on this evidence, 2026-09-16** — Stage 14's PSS panel is **NOT
  BUILT**; `PLAN.md` §14 is retained as the design that was not implemented. Revisit when a
  **released** ngspice contains `668329ca3`. OPEN.

~~**The next free number is 1476.**~~ superseded: **1476** is filed, below.

- **1476** — **the second regression run vanishes at startup, and the cleanup loses result
  files silently.** The two faces of the concurrent-`run_regression.tcl` collision that seven
  weeks and five issue numbers (0384, 0867, 0990, 0955, 0905) never recorded. **Face 2:** the
  startup wipe `file delete -force $testname/results` is unguarded and its target is shared, so
  when the other run is creating files inside that tree mid-walk it **raises** — `error deleting
  "open_close/results": file already exists` — and the case dies on the spot with **rc 1, no
  banner and no `Total num fail:` line at all** (measured: the second run died this way in **9 of
  9** staggered pairs). That is *worse* than the phantom FATAL it travels with, because all four
  of `run_regression.tcl`'s counted shapes need a line to **exist**: a run that screams gets
  counted, a run that vanishes does not, and the verdict file is merely one block shorter than it
  should be — which is what a clean run looks like. **Face 3:** `cleanup_debug_files` wrapped its
  `xargs … awk` in a bare `catch` with no branch and no return value, and gawk's *cannot open
  file* is **fatal**, so one missing path aborts the entire `-n 64` batch and leaves up to 63
  **present** files un-normalised beside it. ⚠ **Needs no concurrency at all** — reproduced
  race-free in two awk spawns. **FIXED** 2026-09-17 by the harness concurrency batch: `5f7164d4`
  (per-run results roots `<case>/results.<pid>`, scratch out of `results/`, `publish_results`
  restoring the canonical name, `read_job_status` distinguishing missing `-1001` from garbled
  `-1002` from a real exit, `cleanup_debug_file.awk` mapping the per-run token back to canonical)
  and `43b40f04` (the verdict lock: **refusal by default**, waiting opt-in via
  `T1_LOG_LOCK_WAIT`, and the waiting path **preserving** the prior verdict as
  `results.<pid>.log` — "wait politely then truncate" was measured to lose **0 of 4** case
  blocks). Red suite first at `5114dd8b` (20 checks, 13 red); registered in `hcases` and verified
  at `d4946b61` — solo T1, **84 cases, ZERO counted failures, rc 0**. Closes 0384, 0867, 0990,
  0955 and 0905 with it. Batch record `doc/claude/harness_concurrency_batch/`. FIXED.

~~**The next free number is 1477.**~~ superseded: **1477**, **1478** and **1479** are filed, below.

- **1477** — **a regression run killed mid-write leaves a truncated verdict that reads as a
  clean sweep.** Issue **0905**'s fix shape **(3)**, which the harness concurrency batch did
  **not** implement: there is still no `REGRESSION START/END` sentinel, and `banner_rule.tcl`'s
  three predicates are all **per-case**, so nothing judges the run as a whole. The batch closed
  the *collision* route into a short `results.log`; the *interrupted-state* route is untouched,
  and needs **no second run at all** — a `T1_CASE_TIMEOUT` kill, an outer `timeout`, an OOM.
  Measured on a copy of the real 169-line verdict: every prefix scores **0 counted failures**
  (1/10/40/80/120/170 lines), because all four shapes at `run_regression.tcl:327` require a line
  to **exist**. ⚠ **And it defeats the one rule CLAUDE.md tells you to trust** — the mtime
  *moves*, because the run really did write. Worse than a prefix, too: the channel is never
  `fconfigure`d, so it is full-buffered at **4096 B** while the whole verdict is **4785 B**
  (measured: 200 lines written and not closed → 4096 B on disk), so a killed run leaves **0 or
  4096 bytes**, not a proportional tail. OPEN.

- **1478** — **the per-case log names are not pid-qualified, so their only protection is a lock
  that fails open.** The residual of 0905's *second sighting*. ⚠ **First, a correction:** the
  inherited claim that *"a standalone suite on `:99` can still race those files"* is **wrong** —
  measured repo-wide, the ONLY writer of `headless/*.disp.log` anywhere is `run_regression.tcl`
  itself (`:669,671,691,696,700,704`); `devdisplay.sh cmd_exec:399-403` does **no** redirection,
  `run_suites.sh:121,123,125` and `full_audit.sh:475-485` capture into a shell variable, and
  `scratch.tcl` is already pid-qualified. What *is* exposed: `<case>.log`, `headless/<case>.log`,
  `headless/<case>.disp.log` and the display arm's `--logdir` `tests/results/.actionlogs`
  (`:661-662`) are fixed names whose guarantee is the verdict lock — **best-effort**, since
  `:502-505` proceeds **UNLOCKED** after four failed attempts — where the results trees' is
  *structural*. Cost when it bites is a **false RED** (0905's 47-blocks-in-a-45-case-tree, a torn
  block header, a FAIL against a file that ends `OVERALL: ok`). Not reproduced; the naming and
  ownership were. LOW/LATENT. OPEN.

- **1479** — **a job that never executed is counted as an ordinary failure, because nothing
  classifies infrastructure exit codes.** Issue **0384**'s fix candidate **2**, landed only for
  the status-file half. Measured on verbatim-extracted shipped source: `job_status_reason`
  (`test_utility.tcl:185-196`) returns a bare `exit $rc` for **126 / 127 / 139 / 143 alike**, and
  all of them score `counted=1` at `run_regression.tcl:327` — so *"the binary was never
  executed"* is indistinguishable from *"the product SIGSEGVed"*. ⚠ **`signal 15` is the wrong
  string to grep for**: jobs end `; echo $? > '$status'` so SIGTERM records **143**, while
  `FATAL: signal N` comes from a different channel entirely (`src/main.c:58` → `banner_died`).
  ⚠ **And an `INFRA:` line must stay COUNTED and merely be labelled** — making it non-counting
  would mean a run where every job failed to start reports zero, which is exactly issue **0147**.
  OPEN.

~~**The next free number is 1480.**~~ superseded: **1480** is filed, below.

- **1480** — **nothing sweeps for the `untitled*` residue class, and neither audit driver
  leaves a log that could attribute it.** The **litter** is not this number — it is filed five
  times already (**0353** detector-half, **0356** the open widening decision, **0609** the
  80-of-116 leak, **0673** whose fix item 2 *is* "widen the sweep", **0687** the `tests/`
  producer), and re-filing it would be the sixth copy of a proposal nobody has implemented.
  What is new is **why it survived an hour of checking by four readers**: ⚠ **neither audit
  driver writes a per-suite `.log` under `tests/` at all** — `full_audit.sh:473,475,477` and
  `run_suites.sh:121,122` capture into `out=$(…)` with a `mktemp -d` logdir outside the repo,
  so a verification pass that answered *"did a suite run in this window?"* from `tests/*.log`
  was **structurally incapable** of seeing the run responsible, and concluded the opposite of
  the truth (same fail-open class as **0147** and **1476** face 2). The second blindness —
  the audit's own detector is `git status --porcelain` and `.gitignore:75` hides `*~.sch` — is
  **already** 0353's closing section and 0356, locked as a LIMIT by C39b/C39c; ⚠ but its
  citations are stale in **five** places, still reading `.gitignore:55,:56` (today `:75,:76`),
  one of them a **check-name string** at `test_audit_classifier.tcl:490`. Measured: **T1
  writes `tests/untitled~.sch` on every green run**, twice with *different* pids
  (`_badig_2066619`, `_badig_2108581`) so a fresh write and not a survivor, from a **passing**
  case; **63 of T1's 69 headless cases** carry no `set ::autosave_backup 0` (static proxy, not
  a leak count — 0609's 80/116 is the real number); and `write_backup()`'s **header comment
  contradicts its own body** (`save.c:6137-6138` says untitled is skipped, `:6149-6152` and the
  code say it is deliberately **not**, issue 0060) — wrong in exactly the direction that hides
  this leak. ⚠ **AND IT MUST LAND WITH 0609's CONTAINMENT, OR EVERY T1 RUN GOES RED**: the only
  reason `C11` has never fired under T1 is that T1's cwd is `tests/` while `C11`
  (`test_ase_core.tcl:1531`, `$repo` at `:460` derived from `[info script]`) reads the repo
  root; 0609's fix direction pins T1's cwd to `$REPO`, which fires it on the first unguarded
  case in the one suite whose baseline is ZERO. OPEN.

~~**The next free number is 1481.**~~ superseded: **1481** is filed, below.

- **1481** — **the NODISPLAY arm skips its `Finish` line, so the `Start`/`Finish` case
  count under-counts by eleven on any box with no dev display.** The display-arm loop
  writes its block and `continue`s at `run_regression.tcl:841`, **before** the
  `puts "Finish …"` at `:872`, while `tcases` (`:736`), `hcases` (`:792`) and the
  `xschemtest` arm (`:895`) all print theirs unconditionally. So a run where
  `devdisplay.sh status` is not alive — a fresh boot, a container, a CI box — prints
  **84 `Start` and 73 `Finish`** lines, and a reader applying CLAUDE.md's *"count
  `Start`/`Finish` pairs for cases"* rule concludes **eleven cases vanished**: exactly
  the reading **1476** face 2 is about, reached from a perfectly healthy run. ⚠ **The
  rule this defeats is itself scar tissue** — it exists because two independent passes
  miscounted the tree (the 82/83/84 corrections), and both **1476**:75 and **1477**:101
  *cite* it as a protection without noticing the hole. `results.log` is **unaffected**
  (the branch writes its own block and increments `t1_blocks`, so a display-less green
  run still carries the normal 83 lines) and `T1-RUN-END cases=` is **correct**
  (`incr t1_cases` precedes the branch) — the damage is entirely in the stdout-derived
  count that readers are told to trust. Fix is one `puts` before the `continue`, ⚠ but
  it must not let a reader score those eleven arms as verified: **0891** chose the
  uncounted-loud-`NODISPLAY:`-line design on 0147's precedent so a headless box stays
  green while saying it verified nothing. Ships with **no row**; documented meanwhile in
  `CLAUDE.md` inline with the rule it undermines. OPEN.

~~**The next free number is 1482.**~~ superseded: **1482 is SKIPPED, not filed**, and
**1483**–**1488** are filed, below (2026-09-18, outsider-fixes batch, stage F).

- **1482** — **skipped on purpose.** At minting time the cross-clone check found `1482` in
  **both** clones' `NUMBERING.md`, as each one's live pointer line
  (`~/dev/xschem-op-wcard`'s copy of this file was byte-identical to this one). CLAUDE.md's
  procedure reads any `NUMBERING.md` hit as taken, and the reason is concrete here: the
  other clone's next filing would take 1482 by its own pointer, which is issue **1400**'s
  collision shape. Left for that clone. ⚠ Its pointer will then walk into 1483–1488, so
  that clone must run the cross-clone check too. The pointer cannot see these files.
- **1483** — **four T1 suites segfault mid-run under `--nogui` when `DISPLAY` is unset,
  so a headless box never sees T1 at ZERO.** `test_op_annot`, `test_ase_optier_0963`,
  `test_unused_attr_0970` and `test_auto_specialize_1201` die with `FATAL: signal 11`
  after rows `W30a`, `S13`, `UF28` and `AS65`, each while inside a child sheet, and pass
  with DISPLAY set. Re-measured at `7a46275f`. The outsider audit's "fresh-clone
  segfault" (F14) label was wrong. With DISPLAY unset, T1 is `87/86/8`. OPEN.
- **1484** — **an uppercase letter in the checkout path turns five ASE suites red**
  (`sp_1452`, `converge_1459`, `campaign_1462`, `campaign_gui_1464`, `variant_1470`: 18
  counted lines). Isolated for `sp_1452` only (`clonB` red, `clone2` green). ngspice
  lowercasing the unquoted `wrs2p` path is INFERRED. OPEN. ⚠ **Widened 2026-09-20** by
  item A: `variant_1470` `OT1` and `sp_1452` `SE1` are now MEASURED (which also closes
  1485's one unknown), the unquoted interpolation is READ in `sp_export_lines`, and the
  trigger is a path ngspice's control line cannot take literally — see **1490** for the
  space reproducer.
- **1485** — **nine T1 suites go red in a `git archive` export because they read their
  corpus through git** and use git's error text as data: 20 counted lines. The
  issue-stamp checker's classify-and-skip-by-name is the remedy's shape. **FIXED
  2026-09-20 in `1f3f5287`** — by enumerating the same files from the filesystem rather
  than skipping, because skipping would have gone green by measuring less. Its file
  carries the numbers; do not re-derive them from this line.
- **1486** — **suites write xschem's untitled autosave into their cwd, and the checkout's
  op_param project file is the user's, not litter.** Running from `~` overwrote or
  deleted the tester's own `~/untitled~.sch`; that is fixed for `run_suites.sh` and
  `gated_xschem.sh` (D13.3). ⚠ It **corrects** DECISIONS D12, which listed
  `<repo>/.xschem/op_param_lists.conf` as suite litter: per issue 1381 it is the user's
  Save. OPEN, partly fixed.
- **1487** — **the T1 verdict cannot show that a case skipped rows, because
  `summarize_all` drops `skip:` lines.** The stage-F gate's own case logs carried 8
  `skip:` lines (converge at 70 checks, not 76) and its verdict none. OPEN.
- **1488** — **`test_wave_markers` hangs when `run_suites.sh` attaches to a persistent
  dev display.** `TIMEOUT` at 200, 300 and 600 s on attached displays, in the old and new
  code alike, and `ALL PASS (983)` on the private `xvfb-run` one. Pre-existing. OPEN.

~~**The next free number is 1489.**~~

- **1489** — **the issue-stamp checker names honest fences (`title=`, `cc=`) and fenced
  stamp examples; four fixes are ready without the opener rule.** Filed when the outsider-fixes
  batch closed Item 1 under D21. S1-fix10's files minus the CommonMark opener rule measured
  regression-free. OPEN.

~~**The next free number is 1490.**~~

- **1490** — **a space in the checkout path reds 71 rows across five suites.** Filed by
  the stranger-reds batch (D4) from item A's verifier finding R6; same class as **1484**,
  measured with a space instead of a capital and far larger (71 rows against 18 counted
  lines). Mechanism READ: `sp_export_lines` in `src/ase.tcl` interpolates `s2p_file`'s
  absolute path into `wrs2p …` **unquoted**, so a space splits it on ngspice's control line.
  The five suites and 71 rows are an aggregate — the verifier's logs were deleted with its
  scratch, so step 1 is to re-measure and name them. OPEN.
- **1491** — **a read-only checkout dies in `test_scratch` and in `ase_state_roundtrip`'s
  temporary file**, both of which default to a path inside the tree. Filed by the
  stranger-reds batch (D4) from item A's verifier finding R7, which the verifier itself
  scored a nit. The corpus helper is read-only-safe (104 files against a `chmod -R a-w`
  tree); a read-only tree also cannot be built, so this is reachable only by building
  elsewhere first. OPEN.

~~**The next free number is 1492.**~~

- **1492** — **four `xschem` verbs kill the process when there is no display, and `catch`
  cannot catch it.** `fill_reset`, `fullscreen`, `copy_hilights` (signal 11) and
  `compare_schematics` (rc **139**). Filed by the stranger-reds batch (D6) from item B's
  fix round. Pre-existing and not headless-only — `--nogui` with `DISPLAY` set crashes
  too. **0834** owns the contract (*a Tcl-reachable verb must error, never crash*) and is
  where these close if a sweep shows one cause. No suite drives them, so nothing counts
  them. OPEN.
- **1493** — **`xserver_ok()` closes the display without nulling the global**, so with
  `--nogui` and `DISPLAY` set a missed `has_x` guard reads freed memory instead of
  faulting. MEASURED: `xschem globals` returning a fabricated `XMaxRequestSize=4` against
  a real `65535`, and `test_undo_selection` dying inside libxcb. **This is how issue 1483
  stayed invisible.** Both item B receipts call it the highest-value follow-up in the
  area; it needs a sweep first, and the sweep's size is unmeasured — three passes gave
  three different counts. 0227 recommends the same line in a parenthetical and says
  "worth fixing separately". OPEN.
- **1494** — **`run_suites.sh` reports a crashed suite as `NORESULT` and throws the crash
  text away.** MEASURED: a sweep of all 405 suites through the documented driver found
  `FATAL: signal` in **zero** output files, in a tree with four real crashes. The FAIL
  arm one line up already echoes `^(FAIL|FATAL)`; the NORESULT arm does not, while two
  other echoes (`skip:`, `note: corpus-source`) survive every arm. Same family as
  **1487**, different file and different lost line. OPEN.
- **1495** — **a checkout path longer than about 73 characters reds `test_op_annot` and
  `test_annot_hier_0911`.** `statusmsg_text` is `char[256]`, `cadence::_annot_fit` cuts an
  over-long status line, and five goldens embed an absolute path in the expected sentence
  (`test_op_annot` N6/N9/V31b, `test_annot_hier_0911` H6/H13). A T1 in a 111-character
  root counts **11**. Measured four times, including on the unfixed binary with `DISPLAY`
  set. Same class as **1484**/**1490**, different mechanism: the fix is test-side, and the
  product's elision is ratified (A11-12b). OPEN.

**The next free number is 1496.**

⚠ **That pointer is PER-CLONE, and always was.** It is one line in a tracked, per-branch
file, so it can see only the checkout you are reading it in. It cannot see another clone of
this repository on the same machine. **As of 2026-09-10 10:46 -0700** two clones here held
**twelve numbers naming two different files** (1338, 1339, 1344–1353), inside a band of
**sixteen** numbers that name two different defects each, with the rest of `1349–1399`
queued behind the other clone's tail — which read **1354** at that moment, five numbers
further on than it had been that morning. **That set was still growing when this was
written: it is an observation with a clock on it, not a standing count.** Both tails were
correct by the rule as written. So before minting, grep **every clone's**
`doc/claude/issues/`, not this one alone; and skip the reserved bands at the head of this
file, `1500–1599` included. Issue **1400** has the measurements and the commands for
re-taking them.
