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
| A3 | the draw rung and the per-instance gate | `[ ]` | | | | | needs A1+A2; the 11th call site; **also owns 1246, 1247, 1248, 1249** |
| A4 | the status line is not path-length-sensitive | `[ ]` | | | | | fixes **1250**, an INTERMITTENT T1 red |
| B1 | the backend seam | `[ ]` | | | | | D-4/D-5 are the whole item |
| B2 | the list store and the settings file | `[ ]` | | | | | `Makefile.in` ×2 + `./configure` |
| B3 | the window | `[ ]` | | | | | `rdw::`, not `results::` |
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
