# Issue number reservations — read before filing

Three blocks are reserved for other branches. Filing into them collides with work
this branch cannot see, and the 02xx renumbering recorded in `status.md` is what
that costs to undo.

| block | owner | rule |
|---|---|---|
| **0500–0599** | the fluid-editing branch | after **0499**, the next number is **0600** |
| **0700–0799** | reserved (user, 2026-08-24) | after **0699**, the next number is **0800** |
| **1000–1199** | reserved (user, 2026-08-30) | after **0999**, the next number is **1200** |

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
latent behind the registry's own normalize, and the code comment states the
opposite rule. **0962**: a coverage gap — no committed row reproduces the
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

**The next free number is 1273.**
