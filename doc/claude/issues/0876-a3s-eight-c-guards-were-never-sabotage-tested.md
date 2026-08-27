# 0876 — issue 0868's eight C-level guards were never sabotage-tested, so none of them is falsified

**Status:** 🔴 **OPEN — an evidence gap, not a defect.** Filed by the A3 write-up,
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
