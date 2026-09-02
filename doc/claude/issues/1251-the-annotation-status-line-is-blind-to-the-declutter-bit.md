# 1251 — the annotation status line is blind to the declutter bit

Status: **FIXED** by item **A4**, 2026-09-02. **The wording is UNRATIFIED —
`owed.sh` rule debt `1251`, the user's to settle.** Two of the recommendations at
the foot of this file were refuted by measurement and NOT implemented: the gate
`if {$mask & 8}` alone, and appending the clause last. See the resolution section.
Originally measured by item A3's write-up pass, 2026-09-02 · Branch: `fluid-editing`
Related: **1244**, ruling **D-8**, item **A4** of `doc/claude/op_param_batch/PLAN.md`
(which owns `utils/annot_mode.tcl`), row **V21** of `tests/headless/test_op_annot.tcl`,
row **S8** of `tests/headless/test_annot_declutter_1244.tcl`

## The defect

`cadence::_annot_msg` builds the sentence the status line shows after every
annotation key. It switches on the mask **with the top bit masked off**:

```tcl
utils/annot_mode.tcl:906:  switch -exact -- [expr {$mask & 7}] {
```

Eight arms, `0`..`7`, and not one of them can mention `ANNOT_SHOW_NOPARAM` (bit
3, value 8) because the value never reaches the switch. So mask 1 and mask 9
produce the **same** sentence:

> `Showing device operating-point values on the schematic.`

## Why this is now wrong, when it was harmless before

Item A1 added the bit and the chord; item A3 (this commit) added the rung that
reads it. Before A3 the bit moved no pixel, so a status line that ignored it was
accurate. **After A3 the bit is the difference between a FET drawing `WN/LLN/1`,
`D`, `vgs=`, `vds=` beside its name and drawing its name and the OP block
alone.** Press `6` after a `Ctrl-Alt-6` and the editor says "showing operating
point values" about a sheet from which it has just removed every parameter.

`cadence::_annot_declutter_msg` (the chord's *own* sentence, added by A1) is
correct and unaffected. The gap is only in the sentence the **other** keys write,
which is the one a user sees when they come back to the sheet later.

## Measured, 2026-09-02, on this tree

```
$ grep -n "expr {\$mask & 7}" utils/annot_mode.tcl
906:  switch -exact -- [expr {$mask & 7}] {
```

The eight arms are `0 1 2 3 4 5 6 7` and the `default` arm. Rendering AFTER item
A3, same sheet, same key, mask 1 vs mask 9 — the pixels differ and the sentence
does not:

```
mask 1 texts: ... WP/LLP/1 M2 D {vgs=- - - } {vds=- - - } - {zid =} {zgm =} WN/LLN/1 M1 D vgs=0 vds=0 ...
mask 9 texts: ... M2 - {zid =} {zgm =} M1 - {zid =} {zgm =} ...
```

## Why item A3 did not fix it (ladder L2, and it is not a free edit)

* `utils/annot_mode.tcl` is **item A4's** file per the driver's brief for A3, and
  A3's Files cell does not name it.
* Row **V21** of `tests/headless/test_op_annot.tcl` golds all eight arms
  byte-for-byte, and row **S8** of the declutter suite pins the `& 7` on purpose.
  Widening the switch from item A3 would red a row in a file A3 does not own, in
  the same commit as the draw rung, for a cosmetic gain.

**Rejected alternative:** leave the two documents disagreeing — the PLAN's A3
note 4 asks A3 to "decide whether to close that gap" and silence would have read
as a decision not taken. This file is the decision, in writing.

## Recommended repair (for item A4, or whoever next owns the file)

Keep the eight arms as the *base* sentence — they are ratified wording (0886) and
V21 golds them — and **append** one clause when bit 3 is set, so the arms
themselves are untouched and V21 keeps passing on the `& 7` part:

```tcl
if {$mask & 8} { append m " Device parameters are hidden." }
```

Then extend V21 (or add V21b) with the two-mask pair, and unpin row S8 with a
comment naming this issue. Note `cadence::_annot_fit` elides at 255 bytes
(issue **1250**), so the appended clause must be counted in that budget.


---

# RESOLUTION — item A4, 2026-09-02

## BEFORE (transcript, verbatim)

```
906:  switch -exact -- [expr {$mask & 7}] {
mask 1   bytes=55  Showing device operating-point values on the schematic.
mask 9   bytes=55  Showing device operating-point values on the schematic.
mask 1 vs 9 : identical=1
mask 7 vs 15 : identical=1
E2E declutter_bit=0 chord=6 mask_after=1 bytes=168
E2E declutter_bit=1 chord=6 mask_after=9 bytes=168
E2E declutter_bit=1 chord=Alt-Shift-6 bytes=134
```

All eight pairs (0/8, 1/9, 2/10, 3/11, 4/12, 5/13, 6/14, 7/15) were byte-identical.

## AFTER

```
state live : mask 1 vs 9  90 B vs 142 B · 3 vs 11 111/163 · 5 vs 13 133/185 · 7 vs 15 151/203
masks 0/2/4/6 vs 8/10/12/14 : byte-identical in all eight states (RULING D-8)
E2E, NO raw loaded at all (`xschem raw loaded` = -1):
  mask 1 texts = MC1 CW=1u {cid =}
  mask 9 texts = MC1 {cid =}
  bar = "Showing device operating-point values on the schematic. Decluttering is on,
         so other device text is hidden. There is no results file at <...> yet.
         Run a simulation first."
```

## What was built

One **pure** minter, `cadence::_annot_declutter_clause {mask}`, returning
`" Decluttering is on, so other device text is hidden."` (52 bytes, leading
space) when `($mask & 8) && ($mask & 1)`, else `{}`. **Two consumers, one mint**
(invariant **I1**): `cadence::_annot_msg` appends it after issue 0909's cause and
before the state clause; `cadence::annot_tran`'s success tail appends it at the
**call site**, on the mask that press just wrote.

## The three decisions, with the rung and the rejected alternative

* **The gate is bit 3 AND bit 0 — ladder L1, ruling D-8.** *"Declutter is active
  ONLY when OP info (6 key triggered) is displayed."* Item A3's draw rung is
  AND-ed on both bits, so at masks 8/10/12/14 nothing is hidden.
  **REJECTED: this file's own recommendation, `if {$mask & 8}` alone** — it
  captions a sheet nothing has stripped, contradicting D-8. Rows S8, S9, E2, E4
  and B1 leg 6 are the guard; the `bit0-blind-gate` sabotage reds five of them.
* **The clause is placed after the 0909 cause and before the state clause —
  ladder L2, measured not styled.** With the clause appended **last** (this
  file's other literal suggestion), mask 15 + `live` + five symbol types fits to
  254 bytes with **the clause itself eaten** by `cadence::_annot_fit`; placed
  early the same combination fits to 249 with the clause whole. **REJECTED:
  trailing** (the fix would be invisible exactly when the line is longest) and
  **ahead of the cause** (re-litigates A11-12b's ruling that what the elision
  sacrifices is the file name, not the answer).
* **Alt-Shift-6's clause is appended at the CALL SITE — ladder L2.**
  `cadence::_annot_tran_msg` is a pure four-argument minter that takes no mask,
  raises on unknown states, and is golded in `tests/headless/test_op_annot.tcl`,
  a file item A4 does not own. **REJECTED: giving it a mask argument** — it would
  red rows in someone else's file for a clause belonging to the caller.

## ⚠ THE MIS-STEP, RECORDED BECAUSE THE WHOLE SUITE AGREED WITH IT

Item A4 **first shipped** the clause behind a fourth condition,
`$state eq {live} || $state eq {loaded}`, reasoning from issue 0909's `canask`
term: *"a press that found no results file has already been told so; telling it
as well that its sheet is decluttered describes a sheet the press never drew."*
Row S8 golded that as a ruling. **The premise is false.** Item A3's rung is gated
on `annot_overlay_gate(n)` **and a non-blank `op_annot::text` block** — not on
numbers arriving — and `src/actions.c:2075` says so in as many words: *"a
registered device over a dead raw is therefore decluttered while its block shows
empty rows"*. Driven on a one-instance fixture with **no raw loaded at all**:

```
raw loaded = -1
op_annot::text M1 = |zid =|
mask1 texts = M1 W4GATE W4W=1u {zid =}
mask9 texts = M1 {zid =}
SVG 1 vs 9 identical : 0
```

So the sheet **is** stripped in `noraw` / `nopath` / `stale` / `failed` / `noop`,
and it was the **silence** that was inaccurate — in the most common press there
is, `6` before the simulation has been run. The state gate was deleted, row S8's
third leg inverted (and rewritten to report **state names**, not a list of ones,
because a golden of ones reads the same whichever way the comparison runs), and
row **E6** added to drive the whole thing end to end with no results file.
Ladder L2. **Every one of E1..E5 warms to a loaded raw before it measures, which
is why none of them could see it.**

## Sabotage matrix (all against the shipped text; md5 verified before and after)

| variant | red rows | note |
|---|---|---|
| `clause-mute` (body → `return {}`) | S8 S9 S10 S11 B1 E1 E2 E4 E6 (9) | |
| `bit0-blind-gate` (`$mask & 8` alone) | S8 S9 B1 E2 E4 (5) | B1 was blind to this until leg 6 was added |
| `state-gate-restored` (the mis-step above) | S8 B1 E6 (3) | **0 red before this repair** |
| `clause-trailing` (append last) | B1 E6 (2) | the placement is load-bearing |
| `tran-clause-dropped` | E4 E5 (2) | |

## Still open

* **THE WORDING IS UNRATIFIED — `owed.sh` rule debt `1251`.** Costed
  alternatives, all measured: `" Device parameters are hidden."` (30 B) names a
  class **ruling D-1 explicitly rejected** (*"even pin labels can be hidden"*);
  the precise per-device form (98 B) puts mask 3 + `loaded` at 251 bytes at an
  ordinary path and over the wall at this suite's; the remedy-bearing form
  (114 B) pushes mask 1 + `loaded` over the wall and the elision eats the remedy,
  which `Ctrl-Alt-6`'s own sentence already gave at the moment the bit was armed.
  A1's three sentences are **not** reworded — they are rule debt `1244`.
  The debt text predates the state-gate repair: the clause now also appears on a
  press that found **no** results, which is part of what is being ratified.
* **The clause loses to the 0909 cause at masks 11, 13 and 15.** Measured over
  256 sentences at an ordinary 55-byte path: with the cause present the clause is
  amputated in **all** states at those three masks (16 combinations each) and
  never at mask 9. That is A11-12b's ordering working as ruled, and row B1 leg 5
  pins the numbers so it cannot be misread as coverage.
* **The stock `Waves > Op Annotate` menu is still silent** — issue **1256**.
  `src/xschem.tcl:17311` and `:17749` preserve bit 3 and emit no sentence at all,
  so the same decluttered sheet arrives without a word by one of its two doors.
  `src/xschem.tcl` is in no A4/A5 Files cell.
* **This repair had no independent adversary pass.** The state gate was found by
  item A4's Verify-C agent, and removed by its write-up agent; the re-verification
  (tiers, five sabotage variants, T1 x4 solo, full audit) is that one agent's.
