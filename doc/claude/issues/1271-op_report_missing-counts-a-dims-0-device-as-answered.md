# 1271 — `ase::op_report_missing` counts a device whose every saved parameter came back `dims=0` as "answered"

Status: **FILED, NOT FIXED** — claimed 2026-09-03 by item **B1** of
`doc/claude/op_param_batch/PLAN.md` · Branch: `fluid-editing`

Related: **1259**, **1263**, **0975**, **0972**, invariant **I3**, ruling **D5-1**

> ⚠ **B1's seam is not in the tree.** B1 was refuted (issue **1272**) and
> reverted; its code is preserved as
> `doc/claude/op_param_batch/B1_working_tree_REFUTED.patch`. Every reference
> below to `op_param_set` describes the design B1 measured, not a proc you can
> call today. **This issue is independent of that** — it is a defect in
> `ase::op_report_missing`, which is shipped and unchanged.

## The defect, in one sentence

`ase::op_report_missing` (`src/ase.tcl`) decides "did this device come back?" from
the variable NAMES in the operating-point plot, read through `ase::cap_raw_plots`
— and that parser keeps only the second tab-separated field of a `Variables:`
line (`src/ase.tcl`, `set nm [lindex [split [string trim $line] "\t"] 1]`),
throwing away the third field, which is the only in-file carrier of `dims=0`.
So a device every one of whose saved parameters arrived as a `dims=0` column is
named in the header, counted as answered, and the run says nothing.

## Why it matters and why B1 did not fix it

Item **A6-b** closed exactly this blindness on the C side
(`raw_line_dims_zero()` → `Raw.dims0` → `raw_vector_absent()` →
`xschem raw value <v> -1` answering the empty string), and item **B1**'s
`op_param_set` consumes that seam rather than the file parser — which is why B1
sources its names from `xschem raw list` and not from `ase::cap_raw_plots`.
`op_report_missing` is a **file** reader by design (it runs when no raw is
loaded into the context) and cannot reach `raw_vector_absent()` without either
loading the file into a slot or teaching `cap_raw_plots` the third field.

Not fixed by B1: `op_report_missing`'s answer shape is golded by rows Q7–Q17 of
`tests/headless/test_ase_optier_0963.tcl`, and changing what "answered" means is
a change to a shipped report sentence, not to B1's seam.

## Note the limit that comes with it

On xschem's own shipped simulate command (`ngspice -b -r`, `src/xschem.tcl:3854`)
there is no `dims=0` token at all — issue **1263** — so teaching `cap_raw_plots`
the third field closes the `.control` + `write` flavour only.

## Recommended option

**Option 1 (recommended) — teach `ase::cap_raw_plots` the third field.** Keep
the name it already keeps, and carry the `dims=0` flag beside it; then
`op_report_missing` can count a device whose every column is `dims=0` as
**unanswered** and say so. Smallest blast radius: one parser, one extra element
per variable, and the report sentence changes only for the case that is wrong
today.

* *Against:* every caller of `cap_raw_plots` must tolerate the wider element,
  and rows Q7–Q17 of `tests/headless/test_ase_optier_0963.tcl` gold the report's
  answer shape, so the golden moves in the same commit.
* *Risk that it is wrong:* it closes the `.control` + `write` flavour **only** —
  on the shipped `ngspice -b -r` there is no `dims=0` token to read (**1263**),
  so a device can still be counted answered when every number is a fabricated
  zero. That is 1263's to fix, at simulate time, and this option does not
  pretend otherwise.

**Option 2 (rejected) — load the file into a raw slot and ask
`raw_vector_absent()`.** Exact, and it reuses the predicate A6-b already landed;
but `op_report_missing` runs precisely when no raw is loaded into the context,
so it would mutate the user's raw registry to write a report. Trading a wrong
sentence for a global side effect is a bad trade.

**Option 3 (rejected) — leave it.** The report's whole purpose is to say what did
not come back; a device whose every parameter is absent is the case it exists for.

## Acceptance rows

1. A fixture raw whose only columns for one device all carry `dims=0`: the report
   names that device as **not answered**.
2. A device with one real column and one `dims=0` column is still **answered**.
3. A device with no `dims=0` columns at all is unchanged, by sentence and by count.
4. Rows Q7–Q17 of `test_ase_optier_0963.tcl` move deliberately, in the same commit.

## Still open

* The `ngspice -b -r` flavour (**1263**) is untouched by every option here.
* Nobody has decided whether "answered" should mean *the header named it* or *a
  number came back*. Option 1 assumes the second. That is a user-visible change to
  a shipped report sentence and is worth a `rule` debt when it is taken.
