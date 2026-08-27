# 0876 — issue 0868's eight C-level guards were never sabotage-tested, so none of them is falsified

**Status:** ✅ **CLOSED for seven of the eight guards — the C table is complete
(appended at the foot of this file, 2026-08-27). The eighth, G10, is NOT falsifiable
by any row in the suite and is re-filed as issue 0878 — which the A3h repair pass has
since ✅ FIXED, by adding row V10b on a dedicated fixture sheet that actually has a
floater; S9 now reds V10b and only V10b.** The S15b block below is REFUTED by three
independent measurements and is re-filed as issue 0879 — do not read it as fact.
Original status line follows.

**(was) OPEN — still an evidence gap; the C half is now SCHEDULED and the
Tcl half is DONE.** The A3h hardening crew has a dedicated sabotage phase that runs
alone and is permitted to build, and that phase exists because of this issue. Six Tcl
variants were executed by the implement agent (table at the foot of this file); the
seven C variants are the sabotage phase's, and this issue closes when their table is
complete and every predicted red that did not appear is named, per variant.
Originally filed by the A3 write-up,
2026-08-27. Class: **unfalsified guards**, the thing this branch's rules exist to
prevent.

## What happened

Issue **0868** landed with a 13-variant sabotage table (S1-S13). Only the six that
touch **Tcl** were ever executed:

| variant | guard | executed? | verdict |
|---|---|---|---|
| S7 | G7, the cursor rule | ✅ | reds V11 and only V11 |
| S13 | G13, mask armed last | ✅ | reds V14/V15/V16's mask legs |
| S10 | G8, the viewer borrow | ✅ | reds B12 + B12b (see **0875**) |
| S11 | G11, the bind spelling | ✅ | reds V20 |
| S12 / S12b | G12, the ASE menu entry | ✅ | reds B11 + W1a18-W1a23 |
| S8 / S8b | G9, refusals speak | ✅ | **reds NOTHING** — see **0873** |
| S6b | the `text_hidden` arm | ✅ | **reds NOTHING** — see **0874** |
| **S1** | **G1**, `raw_read()`'s gate | ❌ | never run |
| **S2** (behavioural) | **G2**, `descend_schematic()`'s gate | ❌ | never run |
| **S3** | **G3**, the `at` parameter | ❌ | never run |
| **S4** | **G4**, the `sch_waves_loaded()` gate | ❌ | never run |
| **S5** | **G5**, the `±HUGE_VAL` window | ❌ | never run |
| **S6** | **G6**, the bit2 render arm | ❌ | never run |
| **S9** | **G10**, the floater refresh | ❌ | never run |

Cause, plainly: the implement agent ran no sabotage pass (its stated reason — the fix
was genuinely absent during the RED phase — is fair but is not a substitute), and
both verify agents were barred from `make` on this ~7.8 GB box, so a C variant could
not be built. Only **S2's structural half** was covered, by replaying row V23b's own
logic against a `/tmp` copy of `src/actions.c` with the guard term deleted: `{1 1}`
became `{1 0}`.

## What IS known, and it is weaker than it looks

The guards are **present and working** — measured behaviourally many times over. That
is a different statement from *"a row can see them"*, which is the one this branch's
rules require before a guard is trusted. The reasoning for each row is recorded in
0868 and in the verify leg's report; row **V3** in particular is argued to be the only
row that can see G5, and V3 is the discriminator whose absence would let a plausible
wrong number onto a schematic (RULING D5-1).

## What is owed

One sabotage pass over S1, S2-behavioural, S3, S4, S5, S6 and S9, run by an agent
permitted to build, with the protocol this branch requires: back up every file,
restore with `cp backup src/file.c && touch src/file.c` (**never `cp -p`**), assert
`grep -rn SABOTAGE src/ utils/` is empty and the restored baseline is green BEFORE
publishing any number, and report every predicted red that did not appear.

Baselines to measure against (2026-08-27, all green): `test_op_annot` 401,
`test_backannotate_digital` 84, `test_wave_cursor_crossdb` 93; Tk on `:99`,
`test_annot_show_menu` 29 and `test_ase_window` 221.


---

# A3h, 2026-08-27 — what has been executed, and what the sabotage phase still owes

## The Tcl half, executed by the implement agent (no build needed)

The harness intercepts `source` and rewrites the proc body in memory the moment
`utils/annot_mode.tcl` loads, so **no repo file is modified** and no build is involved.
Baseline for every row below: `test_op_annot` **410** checks, ALL PASS.

| variant | guard / subject | mutation | measured |
|---|---|---|---|
| S14 | the new 0872 refusal | the `if {$mask != 0 && ![cadence::_annot_op_db_ok]} { return }` line deleted | **reds V31**, and only V31 ✅ as predicted |
| S14b | the `none` exemption | the `$mask != 0` term dropped, so Ctrl-6 is refused too | **reds V31** ✅ as predicted |
| S15 | the 0869 clamped sentence | `annot_tran` always mints the shipped `ok` | **reds V26**, and only V26 ✅ as predicted |
| S15b | the 0869 tolerance direction | the comparison inverted, so `okclamped` is minted in range | ⚠ **THIS CELL IS REFUTED — see issue 0879, do not quote it.** Three later runs measure **V26b + V28** for the plan's literal wording and **V26 + V26b + V28** for the flipped operator. V11/V12/V13/V31 are green in all three |
| S16 | **G9**, the CIW emitter | `cadence::_annot_ciw` reduced to `return 0` | **reds V28, V29, V30** ✅ — this is A3's S8b, which reddened NOTHING before the new rows existed |
| S16b | the held status line | the five `catch {xschem statusmsg -hold …}` calls swallowed in `annot_tran` | **reds V26, V26b, V28, V29** ✅ |

Both silencings together — **the mode made completely mute**, the exact state that
passed 651 checks before this pass — now red **five** rows. That is issue **0873**'s
acceptance test, and it passes.

### ⚠ THE BLOCK THAT WAS HERE IS REFUTED — issue 0879

It claimed the plan's *"S15b must NOT red V26"* was wrong, and that S15b also reds
V11, V12, V13, V28 and V31 *"because `okclamped` is minted with the argument order the
`ok` state does not expect"*.

**Three independent runs refute it** — the verifying agent, the sabotage phase, and
the repair agent, each running both readings of *"invert the comparison"* with the
edit brace-balance-checked before use:

| reading | rows reddened |
|---|---|
| the plan's literal wording — `okclamped` minted unconditionally | **V26b, V28** |
| the comparison operator flipped (`>` → `<=`) | **V26, V26b, V28** |

Under the plan's own literal wording **V26 stays green: the plan was right.** The
stated cause cannot hold either — `cadence::annot_tran` returns `ok` in **both**
branches by design (`utils/annot_mode.tcl`, and its own comment says so), and
V11/V12/V13 read that return value, so no wording change can move them.

Probable provenance, reproduced by VERIFY-B: a brace-unaware single-line `sed` into a
braced Tcl body closes the proc early and reports a twelve-row superset, which
contains exactly the V11/V12/V13/V31 recorded here. The full account is **issue
0879**; correcting a tracker entry another agent wrote is owed as `rule 0879`.

## The C half, still owed — the seven variants, with their decoys

The eight guards are present verbatim and `grep -rn SABOTAGE src/ utils/` is empty, so
nothing is half-sabotaged. Two traps the phase must not walk into:

* **S4 / S5 have a byte-identical DECOY.** `if(!xctx || sch_waves_loaded() < 0) return 0;`
  and the `gr.gx1 = -HUGE_VAL; gr.gx2 = HUGE_VAL;` pair appear **twice** — at
  `src/callback.c:1762` / `:1765-1766` inside `backannotate_at_time()`, which is the
  target, and at `:1696` / `:1699-1700` inside `backannotate_at_cursor_b_nograph()`,
  which is **not**. Sabotaging the copy reds the S11 rows instead and produces a
  confidently wrong attribution.
* **S6 must NOT red V32, and S6b must red ONLY V32.** V32's fixture carries
  `HIDE_TEXT_VOLTAGE`, not the annotation class, so `annot_class_mask()` returns 0 for
  it. That separation is why V32 and V7/V9 are different rows — see **0874**.

Baselines to measure against, re-measured 2026-08-27 after the A3h fix, all green:
`test_op_annot` **410**, `test_backannotate_digital` 84, `test_zero_point_raw_0836` 73,
`test_zero_point_pos_at_0852` 41, `test_raw_read_dispatch` 137,
`test_raw_ascii_point_bounds` 90, `test_raw_read_failure_0306` 63,
`test_wave_cursor_crossdb` 93, `test_wave_markers` 437, `test_wave_viewer` 57;
Tk on `:99`, `test_annot_show_menu` 29 and `test_ase_window` 221;
`tclsh run_regression.tcl` **zero** counted failures.


---

# MEASURED — the C table, executed 2026-08-27 by the A3h sabotage phase

Protocol: one variant at a time, alone; every touched file backed up and restored
with `cp` + `touch` (never `cp -p`); `make` between every variant and after every
restore; baseline re-asserted green before the next variant. `grep -rn SABOTAGE src/`
empty at the end; `git diff HEAD -- src/` empty.

| variant | guard | site | rows that ACTUALLY reddened | predicted reds that did NOT appear |
|---|---|---|---|---|
| S1 | G1 | save.c:1302 | **V22** leg 2; and cross-suite **XCO0b** in `test_wave_cursor_crossdb` | none |
| S2 | G2 | actions.c:4867 | **V23** leg 2 **and V23b** | none |
| S3 | G3 | callback.c:1378-1379 | V2, V3, V4, V7, V9, V10, V11, V13 | **V1 and V26** — see below |
| S4 | G4 | callback.c:1762 | **V5**, and only V5 | none |
| S5 | G5 | callback.c:1765-1766 | V1, V2, **V3**, V4, V7, V9, V10, V12, V13, V26, V26b, V28, V31 (13 rows) | none; the plan's "V3 ONLY" was far too narrow, and contingency row V33 is **not** needed |
| S6 | G6 | actions.c:1533 | **V7, V9**, + V11, V12, V13, V26, V26b, V31. **V32 stayed green**, as required | none |
| S6b | G6b | actions.c:1554-1555 | **V32, and only V32** — sweep `0 0 1 1 0 0 1 1` vs `0 0 1 1 1 1 1 1` | none. **This is the variant that reddened NOTHING for A3. Issue 0874 is now genuinely FIXED.** |
| S9 | G10 | scheduler.c:2372 | **NOTHING. 410 checks still ALL PASS.** | **V10 — the guard is unseen. Re-filed as 0878.** |

## The decoy is real, and it was measured

`callback.c:1696` / `:1699-1700` are byte-identical to the G4/G5 pair at `:1762` /
`:1765-1766`, 66 lines apart. Sabotaging the **wrong** copy (`:1696`) reds **T19 and
T20** and leaves **V5 green** — a run that edited it would have reported "V5 did not
red, G4 is unseen", confidently and wrongly. Sabotaging `:1762` reds V5 and only V5.
The two rows discriminate the two copies cleanly.

## S3's two missing reds are fixture coincidences, not cascade

Both were measured, not reasoned. With G3 deleted a requested time falls through to
`xctx->graph_cursor2_x`:

* **V1** — probed `xschem get cursor2_x` at V1's fixture point: it is **3e-09**, the
  exact time V1 requests. The fallthrough returns the identical answer. V1's header
  claims the verb "does NOT go through a cursor" — that is precisely the claim V1
  cannot test.
* **V26** — V26's own fixture does `xschem set cursor2_x 4.5e-9` and then asks for
  4.5e-9. Requested time == global cursor, so again indistinguishable.

Neither is a defect in the fix; both are rows credited with a discriminating power
they do not have. G3 itself is well covered — V2, V3 and V4 red on it.

## Build-reproducibility note, so a later run does not chase it

`scheduler.c:4343` compiles `__DATE__ " : " __TIME__` into the binary. Two back-to-back
builds of identical source differ in **exactly one byte** (a seconds digit), verified
with `cmp -l`. So **binary md5 is not a valid restore check for any variant touching
scheduler.c** — compare the *source* to the backup instead. The other three guard
files do rebuild bit-identically.
