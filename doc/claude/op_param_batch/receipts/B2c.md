# B2c — the settings file on disk  ⛔ **status F, 2026-09-03**

**Scope:** issues **1277** (flavor class field + DD-8 file order), **1281**
(DD-7 read-modify-write Save), **1276** (the writer's target guards), **1288**
(one duplicate-label rule at both doors). Pure Tcl, one code file.

**Outcome: NOT LANDED. Reverted on issue 1294.** Third revert on 1277/1281.
Code preserved at `doc/claude/op_param_batch/B2c_working_tree_REVERTED.patch`
(2,095 lines, two files, applies clean to `adc08706`, round-tripped twice).

---

## What was measured BEFORE (HEAD `adc08706`)

All four reproduced red, each being the previous crews' own measurements:

```
A4-BARESTAR        | {winner={everything everything 0}}      <- a bare * beats *nfet_01v8_lvt*
A6-CLASSBLIND      | {capacitor_query={mosflavor mosflavor 0}}
C1-USERFILE        | rc=1 reports=1 keeps_class_nmos_mos=0 keeps_MYID=0 keeps_unknown_row=0
D1-DIR             | rc=1 reports=0 target_is_still_a_dir=1 landed_inside=dirtarget.new
E1-SETLIST         | rc=1 reports=0 stored={A ids 0} {A vth 2}
B1/B2/B3-HDR       | the emitted file says nothing about precedence (0 hits: win/preced/order)
```

## What was built, and it went green everywhere

Store suite **56 → 79 ALL PASS** (headless and `:99`); `test_op_annot` 485/492,
`test_annot_declutter_1244` 134, `test_rdw_seam_1245` 49,
`test_rdw_window_1245` 32 — all unmoved; T1 **0**; T2 6/6; full audit
**367/12/0/2 of 381**, non-PASS diff empty **by name and verdict** and identical
at check level (25 → 25 FAIL lines). Eight sabotage variants / ten arms, all
caught, four unfired predictions each explained by construction.

**DD-8 is settled and correct.** `variable keyorder` replaces `lsort` in
`effective` and the writer; all three glob pairs both crews got backwards, in
both insertion orders, 6/6 = the first row in the file. **No ranking proc
exists.** Row **F5** generates its own case *out of the emitted comment*, which
is the acceptance row both previous crews failed.

## Why it was reverted — issue 1294, reproduced first-hand by the write-up agent

**A `param` row this build cannot parse is DELETED on save. rc=1, ZERO reports.**

```
file:   version 2
        param class mos annotation KEEP id 0
        param class mos annotation NEWROW raw ratio
load:   <path>:3: kind "ratio" is not an integer   <- the reader REFUSES the row
then:   set_list class mos annotation {{KEEP id 0}} ; write_conf
after:  version 2 / list class mos annotation / param class mos annotation KEEP id 0
        write=1  writereports=0  NEWROW_kept=0
```

`_row_id` (the writer's merge classifier) validates verb → scope → arity and
stops; `_parse_line` also runs `_valid_list`, the livelist guard and `_triple`.
So the writer **identifies** what the reader rejected, finds the key dirty, and
rebuilds the group without it. **DD-7's own justification — "you cannot delete a
row you never parsed into a model" — is falsified by its own implementation**,
and so is the emitted header's *"rows a newer xschem wrote that this one does
not understand."*

5/5 unparseable kinds. Blast radius measured for all three stamp cases:

```
N1  load_conf(stamp=1) + change a DIFFERENT key : NEWROW_kept=0   (every import)
N2  load_conf(stamp=0) + change a DIFFERENT key : NEWROW_kept=1
N3  load_conf(stamp=0) + change THE SAME key    : NEWROW_kept=0   (the real Save path)
```

**Row T4 could not see it:** its future row `sometotallyfuturerow whatever 1`
has an **unknown verb** — the one class `_row_id` genuinely cannot identify.
The item's own plan had forbidden the two-builder shape in writing.

## Also measured, filed, not the reason for the revert

* **1295** — the merge rewrites line endings (CRLF file → all LF, rc=1, zero
  reports); an interleaved comment inside a rewritten group moves.
* **1296** — an existing file never gains the precedence sentence, and a v1 file
  keeps `version 1` while gaining v2 rows. **Needs a ruling.**
* **1294 secondary** — `_key` silently truncates a >2-element flavor key, so
  `owns`/`get_list` answer for a key `set_list` refuses: a new two-door
  disagreement of exactly the class 1288 was filed about.
* **1290 widened** — a solo T1 returned 3, all `test_ase_optier_0963`
  (X1/X2/HARNESS, **not** X7) on a tree byte-identical to HEAD; the suite then
  passed 94/94 in isolation and a second solo T1 returned **0 / 117 lines**. It
  is the suite's simulator launch, not one check.

## Decisions recorded (ladder rung + rejected alternative)

| rung | decision | rejected |
|---|---|---|
| **L2** | A direct `load_conf` stamps its keys session-dirty; the two-tier startup `load` does not. | Stamping only in `set_list`/`set_class` (M3/X3/P5 red, P4 vacuous); stamping in `load` too (reopens 1281's leak). |
| **L2** | The class map loses its default-comparison filter — a token this session set is written whether or not it equals the shipped default. | Keeping the override-compression: the branch that destroyed a user's `class nmos mos`. |
| **L2** | Header and `version` row emitted only into a file with no lines. | Always emitting (duplicates on every save). **⚠ This collides with the ACCEPT row — issue 1296.** |
| **L3** | Cross-tier flavor precedence is **read order**, user file first, stated in the header. | Project-first — 1281's privacy direction in a hat. |
| **L3** | `set_list` reduces a duplicate label the way the file reader does and returns **1**. Malformed *triple* stays an all-or-nothing refusal. | Returning 0 and refusing: keeps the old contract, leaves the two doors disagreeing. |
| **L2** | Metacharacters: emit two fields, do **not** reject. | Rejecting at write time — costs `[nm]` and `\*`, both documented `string match` features, for a problem the writer created. |

## Debts

* `look` — the emitted `<project>/.xschem/op_param_lists.conf` and its
  precedence paragraph. **Suites green, please look.** Supersedes
  `[op_param_lists.conf_precedence_comment]`, whose refuted "narrowness"
  sentence is gone. **Recorded by the Implement agent; the file it names does
  not exist on the reverted tree, so this debt is a proposal until the patch
  lands.**
* `rule 1275 --eyes` — grammar v2, file-order precedence, user-file-read-first,
  and now issue 1296's question. The consequence to accept: **a bare `*` placed
  first now legitimately beats a specific glob.**
* `rule 1288` — `set_list`'s changed contract and the row-D5 knock-on.

## For whoever lands this

**Apply the patch; do not retype it.** Fix **1294** by making `_parse_line` call
`_row_id`, so there is genuinely one builder — the shape this item's plan
specified and the code did not build. Decide **1296**. Then re-verify, with a
"future row" fixture built from a **known verb and an unreadable field**, not an
unknown keyword.

**⚠ Process:** a sibling agent mutated `src/op_param_lists.tcl` in place during
verification; Verify-A's first T1 and Verify-C's first suite number were both
void and had to be re-taken under an md5 guard. **Run sabotage on a copy.**
`grep -c SABOTAGE src/op_param_lists.tcl` must be **0** on a reverted tree.
