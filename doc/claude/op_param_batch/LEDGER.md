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
| A6 | close the value gate and the last bbox doors | `[ ]` | | | | | needs A5; fixes **1258, 1259, 1260** |
| A7 | the wording follows the gate, guards stop lying | `[ ]` | | | | | needs A6; fixes **1255, 1256, 1257, 1261**. **FEATURE A CLOSES HERE** |
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
