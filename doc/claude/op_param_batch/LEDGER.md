# OP parameter lists — batch ledger, branch `fluid-editing`, base `9ef4a37e`

**State lives HERE, not in the driver's context.** After a compaction, re-read
this file and continue from the first row that is not `[x]`/`[E]`/`[D]`/`[F]`.

Verdicts: `[x]` done+verified · `[E]` done, eyeball pending (pixels) ·
`[D]` deferred (needs a filed issue) · `[F]` failed (needs a filed issue) ·
`[ ]` not started · `[~]` in flight.

## Read before touching anything

1. **`DECISIONS.md`** — D-1 … D-8, settled with the user 2026-09-02. It
   overrides the spec wherever they disagree.
2. **`PLAN.md`** — the authoritative item list and the dependency edges.
3. `doc/claude/specs/op_param_lists.md` — the spec.
4. `doc/claude/code_analysis/1244_op_param_list_measurements.md` — every number
   the design rests on, with the command that produced it.

Receipts: `receipts/<item>-<slug>.md`, 120 lines max.

## Baseline — audit debt is PAID

**364 pass / 11 fail / 0 crash-timeout / 2 skip of 377** at `9ef4a37e` on the
dev display `:99`. The eleven are named in `PLAN.md`. Every later audit is
judged by DIFFING that list by test **NAME and STATUS**, never by the red count.
`run_regression.tcl` (T1) baseline is **ZERO** counted failures, run **solo**.

## Items

| # | item | verdict | commit | checks | files | eyeball | note |
|---|------|---------|--------|--------|-------|---------|------|
| A1 | the mask bit and the chord | `[E]` | `59b67766` | 36 new, ALL PASS | xschem.h, annot_mode.tcl, cadence_style_rc | owed | ✅ `Ctrl-Alt-6` no longer fires `Alt-6`. Filed 1246, 1247, 1248 |
| A2 | the name classifier | `[x]` | `dcbb85c3` | 36→52, ALL PASS | xschem.h, actions.c | — | `TEXT_ANNOT_NAME 1024`, unconditional. Filed 1249, 1250 |
| A3 | the draw rung and the per-instance gate | `[E]` | `39769294` | 52→82, ALL PASS | actions.c, draw.c, svgdraw.c, psprint.c, select.c, xschem.tcl | owed | closed 1246-1249. Filed 1251-1254. **Audit run by the DRIVER: 365/11/0/2 of 378, 11 reds identical by name** (`audit_A3_2026-09-02.txt`) |
| A4 | the status line is not path-length-sensitive | `[E]` | `ccd2aec1` | 82→93; stale_0684 52→54 | annot_mode.tcl | owed | **T1 solo ×4 = 0/0/0/0** — the flake is dead. Filed 1255, 1256. **Driver audit: 365/11/0/2, IDENTICAL BY NAME to A3's** (`audit_A4_2026-09-02.txt`) |
| A5 | D-1 / D-6 conformance, and A3's staleness | `[E]` | `cd212b69` | 93→105, ALL PASS | actions.c, draw.c, svgdraw.c, psprint.c, select.c, scheduler.c | owed | closed 1252-1254 + the gate. **Ran its own audit; by-name diff vs A4 EMPTY.** Filed 1257-1261 |
| A6 | close the value gate and the last bbox doors | `[E]` | `c8bb41f9` (driver) | 105→120, ALL PASS | actions.c, save.c, scheduler.c, select.c, xschem.h | owed | crew returned **F** — destroyed its own work, then blocked from building. Driver built, ran the suite, attributed the 12th red (**1269**, the display). **1259 only PARTIALLY closed** → **1263** to B1 |
| A7 | the wording follows the gate, guards stop lying | `[E]` (driver re-do) | see commit | 120→**134**, ALL PASS | actions.c, op_annot.tcl, scheduler.c, xschem.h, xschem.tcl, annot_mode.tcl | owed | crew returned **F**, refuted by its own adversary (**1270**). Driver re-did from the crew's preserved patch + 4 lines + rows **A64/A65**, both sabotage-proved. Closes **1255, 1256, 1257, 1261**; fixes **1270**. T1 **0**. Audit 364/12/0/2, by-name diff vs A6 **EMPTY**. **FEATURE A CLOSES HERE** |
| B1 | the backend seam | `[x]` | see commit | **37→49**, ALL PASS | ase.tcl, op_annot.tcl, test_rdw_seam_1245.tcl | — | crew returned **F**, refuted by its own adversary (**1272**). Driver re-did from the preserved patch + 2 fixes + 12 rows. Fixes **1272**; answers **1259** (NO) and **Q10** (YES). Answer dict is **five** keys |
| B2 | the list store and the settings file | `[E]` | `1340da77` | 39 new, ALL PASS | op_param_lists.tcl (new), Makefile.in, 3 PDK procs | owed | `grep -c` 0→**2**, `Makefile.conf` byte-identical. Settings file is DATA (DD-3) and the sourced-conf attack was **demonstrated on this tree**. Filed **1273-1281**; six are defects in its own new code, found by its own adversary |
| B2a | the six seam defects B2's adversary found | `[ ]` | | | | | **must land before B5** — 1277 changes the file grammar |
| B3 | the window | `[~]` | | | | | `rdw::`, not `results::` |
| B4 | the keys and the two grammars | `[ ]` | | | | | needs B3; displaces `logic_set` |
| B5 | the button column and the scope dialogs | `[ ]` | | | | | needs B2+B3; issue 0803 |

## Driver decisions (taken by the driver, not the user — recorded so they are auditable)

* **A1's status sentence is accepted as written**, although until A3 lands its ON
  form — *"a device showing operating-point values draws its name and those
  values only"* — describes a declutter that has not arrived. The batch lands as
  a unit and nothing ships between A1 and A3; rewording it twice would risk the
  interim wording surviving. **The safeguard moves to A3**, whose brief must
  replace A1's vacuous "A3 MUST REPLACE" tripwire (issue **1248**) with a real
  rendering check, so the sentence is proved rather than promised.
* **Issues 1246, 1247 and 1248 are assigned to item A3**, which is the first item
  that owns the files each needs (`src/xschem.tcl` for 1246, `src/actions.c` for
  1247) and the first at which any of them has a visible effect. A1 correctly
  measured and filed all three without fixing them; none is A1's to own.

### ⚠ A6: what a crew could not do, and what the driver had to

A6 is the first item to return **F**, and the reason is worth keeping. Its
write-up agent ran `git checkout -- src/save.c` to undo a comment edit and
destroyed ~99 lines of its own **unstaged, already-verified** implementation.
Never staged, so `git fsck` recovered nothing. It reconstructed 88 lines
verbatim plus one 8-line hunk from prose, **said so plainly**, and was then
denied permission to run `make` — so it could not certify the reconstruction and
**refused to commit unbuilt C**. That refusal was correct.

The driver did the half the crew could not: built it (clean; the one `save.c`
warning is pre-existing, confirmed by building both HEAD and the change and
diffing by *content*, since A6 shifts line numbers by ~99), ran the suite
(105 → 120, ALL PASS), and **attributed the twelfth red instead of accepting
it** — five binaries, including A4's own commit rebuilt in a clean worktree,
all of which fail it, against a freshly restarted display which passes all 126.
It is the display, not the code: issue **1269**.

**And then the driver's own audit turned out to be worthless, for a reason worth
keeping.** The first post-A6 full audit reported two extra reds — including
`test_annot_declutter_1244` itself, with every one of A6's own checks failing.
The tree was correct; the **binary was a build behind**, left there by the
`git stash` / build / `git stash pop` cycle run during the 1269 attribution. No
test harness builds — `full_audit.sh:49` runs `src/xschem` as it finds it — so
the transcript was entirely plausible and entirely false. One `make -C src`
(which recompiled *every* object, the tell) and the suite passed 120/120.
Recorded as a standing trap in CLAUDE.md. **The driver's rule for the rest of
this batch: rebuild immediately before any audit that is meant to be evidence,
and read an unexpected red as a question about the binary before it is a
question about the code.** The 1269 table has been amended, because two of its
rows were taken with that stale binary.

**The audit re-run against a correct binary** (`audit_A6_2026-09-03.txt`):

```
SUMMARY: 364 pass  12 fail  0 crash/timeout  2 skip  (total 378)
```

`test_annot_declutter_1244` is **green in the audit**, which is what A6 had to
prove. The list is the eleven known reds plus **`test_wave_sigbrowser_i12`**,
which the re-measurement excludes the binary from: it passes on a freshly started
display, passes on a second run, passes even after the red suite that precedes it
in the audit - and fails after a full audit. Issue 1269 now carries the excluded
candidates and the named-but-unproven mechanism (BX42 reads
`xschem get current_win_path`, which follows X focus and `<Enter>`, so it is
really asking where the pointer and focus are).

**The baseline for A7 is therefore TWELVE NAMES, carried by name and by reason -
never as a count.** A7 must not add a thirteenth.

**Two standing lessons for the rest of this batch.** A crew that reports its own
destruction honestly is behaving correctly and its work is still usable — check
it, do not discard it. And an unexplained red is attributed, never absorbed:
this one cost a worktree build and it was still cheaper than a batch that learns
to wave reds through.

### ⚠ A7: the crew was refuted, was right to be, and the re-do cost four lines

A7 is the second item to return **F**, and unlike A6 nothing was lost. Its own
adversary refuted the central mechanism, its write-up agent **agreed with the
adversary against its own work**, reverted, and preserved every line as a
re-appliable patch that was dry-run-applied to a pristine `git archive`
extraction *before* anything was touched. The driver's re-do was: apply the
patch, add four lines, write two rows.

**The defect is worth remembering because it is a class, not an incident.** A7
needed to answer *"was anything actually hidden?"* and answered it with a counter
bumped at the declutter rung's `return 1` — which sits **above** the three
predicates that would have hidden the text anyway. So the counter measured *which
predicate fired first*, not *what came off the sheet*. On any annotated device
whose only non-`@name` text already carries `hide=instance` — **57 shipped
symbols** — the sheet was byte-identical at mask 1 and mask 9 while all three
status-line producers claimed a declutter. That is the very defect A7 was written
to fix, in a state nobody had named, and it was green past **132 checks**.

**The lesson: a measurement taken at a seam inherits the seam's position, and
the seam's position was chosen for a different question.** Visibility only needs
to know that something says "hide". A sentence that says *"other device text is
hidden"* is a claim about what the user can no longer see. Those are two
questions and one `return`.

Three things from the re-do that the rest of this batch should copy:

* **A golden was wrong and the measurement was right.** A64 was written expecting
  the stock `Graphs` door to stay silent on the counterexample sheet, like the
  two chords. It does not, and it should not: the menu body runs
  `set show_hidden_texts 1` one line before writing the mask, so on that door the
  text really *is* drawn and really *is* taken away. The row now goldens the
  asymmetry and **reads the switch back to prove the reason**. When a new row
  reds, find out which side is wrong before changing either.
* **Both repairs were sabotaged, not asserted.** The 1270 defect restored reds
  A64; the tempting repair that tests only the two `HIDE_*` bits reds A65. A65
  exists solely to catch a fix that would work for the keyboard and silently
  break the menus — the workflow the feature was written for.
* **A62 was green against a menu that raises**, because `xschem set annot_show`
  runs early in the `-command` body and the mask merges before the raise. It now
  reports whether the body raised. And the mechanism was corrected a second time
  in the re-do: deleting the `info commands` guard raises *nothing*, because the
  call below it is already inside a `catch`. The guard is not what keeps stock
  xschem quiet — **the inner catch is**.

### ⚠ FEATURE A CLOSES AT A7 — a driver boundary, set 2026-09-02

Six landed items, **sixteen filed issues** (1246-1261). Every one measured; several
were real — a D-1 violation, an intermittent T1 red against a zero baseline, and
a feature that inverted itself before you had simulated. The crews behaved
correctly. But three consecutive items have each produced residue from the item
before, and that recursion must be bounded by a decision rather than by
exhaustion. **A6 and A7 close feature A. Anything found after A7 is filed and
deferred to a later batch, not spawned as another item.** Feature B — the half
the user described first and at greater length — has not started.

### ⚠ A3's receipt carried no full audit, and the driver ran it

A3 is the only item in feature A that changes **rendering**, in six call sites
across three back-ends, and its receipt recorded per-suite results but no
`full_audit`. The acceptance criterion for every item is a **name+status diff**,
so the driver ran it rather than take the item on trust:

```
SUMMARY: 365 pass  11 fail  0 crash/timeout  2 skip  (total 378)
```

Identical to the post-A2 baseline, and the eleven failing names are the eleven
known reds. A3 moved nothing. Transcript committed as
`audit_A3_2026-09-02.txt`.

**For every later item: the audit is the driver's to verify, not the crew's to
assert.** A per-suite list is not an audit.

### Driver rulings on A3's six queued questions (2026-09-02)

Six `rule` debts reached the user's queue from items A1-A3. **Five of them follow
from rulings the user has already given**, so the driver has read each one and
said how — they stay on the queue because only the user clears a rule debt, but
no item is blocked waiting for them.

| debt | driver's reading | follows from |
|---|---|---|
| `1244` (A1's three status sentences) | accepted as written; the safeguard moved to A3, which has now landed a real rendering check | driver decision, recorded above |
| `1244_A2_name_bit_vs_hide_true` | **unconditional is right.** Gating it would make a name vanish under the one feature whose whole promise is "its name and the OP numbers, nothing else". Zero shipped records are affected either way | **D-1** |
| `1244_A3_blank_valued_block` | **the gate must require a value.** A label-only block (`zid =`) did not "get OP numbers", and decluttering there loses `W/L` for nothing. **This changes code** — item **A5-a** | **D-6** |
| `1244_A3_click_target` | **correct as measured.** The text is not drawn, so it is not clickable; a bbox that still covered it would be the bug. Item **B4** must click the device body, and item **A5-c** must first make the gate agree at both `symbol_bbox()` callers (issue 1252) | **D-1** |
| `1244_A3_hide_true_op_texts` | **intended.** S10b deduplicated the PDK symbols' own OP texts with `hide=true` precisely so the draw-time overlay replaces them; hiding them under declutter is that trade working, not breaking | issue **0475** §3 |
| `1244_A3_rc_armed_stamp` | **the correct consequence of the 1247 fix.** A net-zero pair of presses changing a sheet's arming was the defect; leaving it rc-armed is the fix behaving | issue **1247** |

If the user disagrees with any of these, the item that implements it is named in
the row and the ruling is cheap to reverse — none has shipped to a user.

## Debts this batch owes the user

Recorded on `tests/headless/owed.sh` at the moment they are incurred, never at
the end.

| kind | what | state |
|---|---|---|
| `look` | Q6 — the dump header spelling, on screen | to record when B3 lands |
| `look` | the decluttered sheet on the real display, per PDK | to record when A3 lands |
| `rule` | Q10 — is the RDW reachable after an ordinary OP+TRAN run | **verify first**, ask only if the answer is "no" |

Pre-existing and unrelated, still open: `rule` **1240**, `rule` **1243**, and
three `look` debts from the merge.

## Carried risks

1. **`Ctrl-Alt-6` is not free** and the failure is silent — it turns node
   voltages on. A1's chord matrix is the only guard.
2. **`Makefile.in` without `./configure` is invisible in-tree and fatal
   installed** (issue 0424, exit 139 at startup). Two items add a `.tcl` file.
3. **Modal dialogs hang suites under X** (issue 0803). B5.
4. **Symbol texts are shared across instances**, so feature A cannot be
   per-instance in `xText.flags`. A3 carries the gate in the context argument.
5. **A crew "improving" key 3** by inferring parameters violates D-4. The
   DECISIONS file states this in the negative on purpose.
| A1 | E | 59b67766 | test_annot_declutter_1244 new->ALL PASS 36; full_audit 364/11/0/2 of 377->365/11/0/2 of 378 (+1 = this suite, 11 reds identical by name); T1 0->0 solo; T2 HARNESS PASS 6/6->6/6; test_op_annot 492->492; annot siblings 36/52/27/15/22 unchanged; accelerators+launch_context+keybind_snap_grid 6+clone_canvas 3+audit_classifier 69 unchanged | 1246,1247,1248 | Accept the three Ctrl-Alt-6 declutter status sentences as written — including that, until item A3 lands, the ON one ("a device showing operating-point values draws its name and those values only") promises a declutter that has not arrived yet? |
| A2 | x | dcbb85c3 | test_annot_declutter_1244 36->52 ALL PASS \| test_op_annot 492->492 \| annot_show_menu 36 \| stale_0684 52 \| hier_0911 15 \| blank_cause_0909 27 \| op_behind_tran_1242 22 \| selflog_grep_guard (no count) \| T1 0->0 solo (1 unattributed F21 red in 4 runs, filed 1250) \| T2 HARNESS PASS 6/6 \| audit 365/11/0/2 of 378, all 11 reds + 2 skips identical BY NAME | 1249, 1250 | A2 landed and committed: TEXT_ANNOT_NAME 1024 set unconditionally on a whole-string match of all three spellings, nothing visible until A3 (proved cross-binary byte-identical); rule debt 1244_A2_name_bit_vs_hide_true is wanted BEFORE A3. |
| A3 | E | 39769294 | test_annot_declutter_1244 52->82 ALL PASS \| test_op_annot 492->492 \| annot_show_menu 36->36 \| stale_0684 52->52 \| hier_0911 15 \| blank_cause_0909 27 \| op_behind_tran_1242 22 \| spice_get_node_0861 23 \| sod_pick_0204 66 \| select_at 15 (--logdir) \| verb_noun_descend 25 \| hover_repair 5 \| cmdmode_descend 90 \| locked_wire_pick 16 \| no_untitled_litter 12 — all ALL PASS, row-id diff 0 \| te | 1251,1252,1253,1254 | The declutter fires on any instance whose descriptor RESOLVES, not one that got numbers — a registered FET over a raw with no matching vectors is decluttered while its OP block shows "zid =" with nothing after it (common, per rule R1: gm/vth exist only if the deck saved them) — is that "only instances that got OP numbers" per D-6, or must the block carry at least one actual value before any parame |
| A4 | E | ccd2aec1 | test_annot_stale_0684 52->54 (default + roots 121/142/201, and :99); test_annot_declutter_1244 82->93 (:99); test_op_annot 485/492, blank_cause_0909 27, hier_0911 15, results_freshness 21, show_menu 36, op_behind_tran_1242 22 all unchanged; T1 SOLO x4 = 0/0/0/0; T2 HARNESS PASS 6/6; full_audit 365 pass / 11 fail / 0 crash / 2 skip of 378, eleven reds identical BY NAME to audit_A3_2026-09-02.txt | 1255,1256 | After Ctrl-Alt-6, every 6 / Alt-6 / Alt-Shift-6 press now also says " Decluttering is on, so other device text is hidden." — including before you have run a simulation, because the sheet is stripped then too: is that the right reminder, should it be shorter, should it repeat the way out (Ctrl-Alt-6), or should the other keys stay silent about it? |
| A5 | E | cd212b69 | test_annot_declutter_1244 93->105 ALL PASS; T1 0->0 solo; T2 6/6 HARNESS PASS; op_annot 492, show_menu 36, stale_0684 54, blank_cause 27, hier 15, op_behind_tran 22, pin-name x4 + pick/descend x6 all unmoved; full_audit 365 pass/11 fail/0 crash/2 skip of 378, by-name-and-status diff vs audit_A4 EMPTY | 1257,1258,1259,1260,1261 | With no results file, Ctrl-Alt-6 now hides nothing but the held status line still says other device text is hidden - should the clause follow the gate (say nothing when nothing was hidden), or should the press be refused outright with "Run a simulation first"? |
| A6 | F | a728d198 | Before the loss (Tk arm unless noted): test_annot_declutter_1244 105->120 ALL PASS (re-run by me), test_op_annot 485(nogui)/492(Tk)->492 ALL PASS, test_results_select ->377 ALL PASS, test_raw_read_dispatch 137->137, test_raw_read_failure_0306 63->63, test_zero_point_raw_0836 74->74, test_backannotate_digital 84->84, test_spice_get_node_0861 23->23, test_annot_show_menu 36->36, test_annot_stale_068 | 1262,1263,1264,1265,1266,1267,1268 | A6 was implemented, built and fully verified, then I destroyed A6-b's uncommitted src/save.c half with `git checkout -- src/save.c`; no code is committed, the work is preserved in doc/claude/op_param_batch/A6_working_tree_UNVERIFIED.patch and in the working tree, and A6 must be re-run starting with `cd src && make`. |
| A7 | F | b169d5ff | As built, now REVERTED: declutter_1244 120->132 ALL PASS, stale_0684 54->56 ALL PASS both arms, op_annot 492/485 unchanged, show_menu 36, waves_gate 42, hier_0911 15, blank_cause 27, behind_tran 22, results_select 377, raw_read_dispatch 137, T1 0 counted, T2 6/6, full audit 364/12/0/2 with the twelve names verdict-identical; after the revert every suite is back at its baseline count. | 1270 | A7 is F: all four parts implemented, built and green everywhere including the audit, then refuted on a fourth state nobody had named — reverted, preserved as a re-appliable patch, and the re-do is four lines of C. |
| B1 | F | 99cb360c | Re-taken AFTER the revert: T1 0->0 counted (117 lines, rc=0); T2 HARNESS PASS 6/6->6/6; test_ase_simcaps_0948 ok->ok; test_ase_core 1 FAILED (181 passed)->1 FAILED (181 passed), the C11 phantom by name; test_rdw_seam_1245 was ALL PASS (37) and is DELETED with the revert, so the audit denominator stays 378. | 1271,1272 | B1 REFUTED and REVERTED: the seam was green at 37/37 while returning `nan` in the VALUE bucket from a binary raw (issue 1272) — code preserved as doc/claude/op_param_batch/B1_working_tree_REFUTED.patch, applies clean to 9f1d9153, two named blockers, reconstruction is apply+fix+re-verify not a retype. |
| B2 | E | 1340da77 | test_op_param_store_1245 new->ALL PASS 39; T1 0->0 counted solo; T2 HARNESS PASS 6/6->6/6; op_annot 485/492->485/492; startup_guard_0663 22->22; results_select 377->377; ase_simreg_0931 67->67; raw_read_dispatch 137->137; rdw_seam_1245 49->49; annot_declutter_1244 134->134 (:99 openbox); sim_casemode 28->28; ase_simdlg_0937 4->4; ase_core 1 FAILED(181)->1 FAILED(181) = the C11 untitled~.sch phanto | 1273,1274,1275,1276,1277,1278,1279,1280,1281 | Should the project settings file live beside the directory xschem was LAUNCHED from ([pwd]/.xschem/op_param_lists.conf, what shipped) or beside the schematic being edited — because as shipped, a teammate who clones the project and starts xschem from $HOME silently finds no project settings at all? |
