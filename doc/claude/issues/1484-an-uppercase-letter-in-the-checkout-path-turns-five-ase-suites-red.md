# 1484 — an uppercase letter in the checkout path turns five ASE suites red

**STAMP:** `v1 claim=open tree=1f3f5287 stamped=2026-09-20 fix=none open=4 by=A-docs`

**Status: OPEN — filed 2026-09-18** by the outsider-fixes batch, stage F (docs crew), from
`doc/claude/outsider_fixes_batch/DECISIONS.md` D12, where it is recorded as **a new
stranger finding**. **Class** stranger-facing false red in T1, with a product defect likely
underneath it (INFERRED, see below).

**Updated 2026-09-20** by the stranger-reds batch with two measurements from item A — see
"What item A added". `open=` was re-derived from this file's own list rather than carried
forward: it reads **4** now, listed under "Still open". Two rows moved from inferred to
measured, and the trigger is now described as **a path the ngspice control line cannot take
literally** rather than as a capital letter. **Related: issue 1490**, the same class
measured with a space, which is the larger and cheaper reproducer.

---

## What happens

Clone this repository into a directory whose path contains an uppercase letter, build it,
run T1, and five ASE suites go red. The suites are the same, and fail the same way, in the
old harness and the new one.

* **MEASURED (S2a redirect study, `receipts/S2a.md`):** a variant tree named `cloneB`
  turned five suites red: `test_ase_sp_1452` (row `SE1`), `test_ase_campaign_1462`,
  `test_ase_campaign_gui_1464`, `test_ase_converge_1459` and `test_ase_variant_1470`.
  For `test_ase_sp_1452` the variable was isolated: a tree at `clonB` gave `2 FAILED`,
  and one at `clone2` gave `ALL PASS`. **For the other four, case and path length were
  not separated.**
* **MEASURED (S2c-T, `receipts/S2c-T.md`):** a T1 in a stage directory named `s2c_T`
  carried **26** counted failures. The same code in a lowercase sibling carried **8**,
  which are the DISPLAY-unset segfaults of issue 1483. The difference is **18 counted
  lines, all in the five suites above** (`test_ase_campaign_gui_1464` on both arms), and
  they were identical in the fixed tree and the unfixed base, after pid normalisation.
* **MEASURED (S2c-U, `receipts/S2c-U.md`):** under a scratch root named `s2c_U`,
  `test_ase_converge_1459` `EE5` and `test_ase_sp_1452` `SE1` were red in tree and base
  alike. Both were green under a lowercase root.

Later crews moved their clones to lowercase siblings to get a clean comparison (the S2c
regression refuter's `s2cv2`, the R3 prover's `r3p`). The S2c safety refuter stayed at its
assigned uppercase path and saw the same reds, identical per case in tree and base
(`receipts/S2c_refute_r1.md`, "Per case, tree and base are IDENTICAL").

## Why — INFERRED, not measured

`ase::sp_export_lines` in `src/ase.tcl` writes the S-parameter export into the ngspice
deck as `wrs2p [s2p_file $state $idx]`: a bare, **unquoted** path (READ). The S2a study
inferred that ngspice lowercases an unquoted word on that control line, so the file is
written to a path that does not exist when the directory has capitals, and the suite's
check then finds nothing. **That is inferred from the red/green split, not read in
ngspice's source and not traced.** The mechanism for the other four suites is not
established at all, and it may be a different one.

⚠ **Read "What item A added" at the foot of this file before acting on the paragraph above.**
The unquoted interpolation is confirmed by a second reader and cited there by proc name; the
*lowercasing* half is still nobody's measurement, and a space in the path — issue **1490** —
reds far more rows than a capital does, which word-splitting explains and case folding does
not.

If the inference holds, **this is a product defect, not only a test one**: a user whose
project lives under `~/Projects/…`, `~/Documents/…`, or a home directory with a capital
in the user name would get an S-parameter export that silently lands nowhere (INFERRED).

## What it is not

* **Not the test home.** The throwaway HOME's `mktemp` suffix is mixed-case about 96% of
  the time. S2a measured 11 ASE-heavy hcases identical under a mixed-case HOME
  (`xschem-test-home.4242.QmZxKe_…`) and a lowercase control, and every later T1 ran
  green under mixed-case throwaways. The "lowercase only" rule is about paths that reach
  an ngspice control line, and the checkout is one of those.
* **Not the git-export reds (1485) or the DISPLAY-unset segfaults (1483).** Those appear
  in lowercase paths too.

## Fix direction

1. Measure it first: run `test_ase_sp_1452` in `…/caseA` and `…/casea` clones, and
   inspect the deck and the directory ngspice actually wrote into. Then quote the
   `wrs2p` argument the way the deck quotes its other paths, if ngspice accepts that.
2. Separate case from length for the other four suites before assuming they share the
   cause.
3. Add a T1-visible row: a two-character uppercase directory in the S-parameter export
   path, which must round-trip.

## Evidence

`doc/claude/outsider_fixes_batch/receipts/S2a.md` (the paragraph beginning "Confound
found and removed"), `receipts/S2c-T.md` (the per-case attribution under the T1 table,
and open problem 6), `receipts/S2c-U.md` (deviation 2).

---

# What item A added — 2026-09-20, stranger-reds batch

Two facts this file did not have. Neither is a fix; both are evidence, and the second one
changes what this issue is about.

## 1. MEASURED: `test_ase_variant_1470` `OT1` and `test_ase_sp_1452` `SE1`, by accident

Item A's implementer was assigned a scratch root with a capital `A` in it, reproduced these
two rows, moved to an all-lowercase sibling and re-measured. Its fix round hit the same
thing again from a different direction. The identical export, built twice from the same
`HEAD`:

| export built at | `test_ase_variant_1470` | `test_ase_sp_1452` |
|---|---|---|
| a path with an uppercase `A` | `OT1` **FAIL** | `SE1/apt` **FAIL**, `SE1/fork` **FAIL** |
| the all-lowercase sibling | `OT1` **ok** → `ALL PASS (76)` | `SE1` **ok** → `ALL PASS (58)` |

**Same commit, same binary, same fresh throwaway HOME, same `AUDIT_DISPLAY=none`, one
directory name apart** — and from a crew that was not looking for this defect, which is why
it is worth more than another deliberate run.

⚠ **Two qualifications, so the strength of each half is plain.** The implement round's pair
is the clean one: two trees each built from scratch at the two paths. The fix round's
corroboration is a `cp -a` of a tree built elsewhere, so it is corroboration and not a
second clean experiment. And these two rows are an observation about **case**, not about the
mechanism — nothing here traces what ngspice did.

**This also closes issue 1485's one open question.** 1485 recorded that an F21 verifier saw
`OT1` and `SE1` red in a fresh-HOME git clone while this box's full-clone control had both
green, and called the difference UNKNOWN with 1484 as an INFERRED explanation. It is this
issue, it is measured, and 1485 now says so. Those two rows are therefore **MEASURED** here;
the other three suites' rows remain as measured by S2a/S2c-T/S2c-U above, and the mechanism
below remains unproven for all of them.

## 2. The mechanism is LOCATED — and it is READ from the code, not proven

Item A's verifier went to `src/ase.tcl`. `sp_export_lines` (namespace
`::ase::backend::ngspice`) returns the three ngspice control lines of one S-parameter row,
and builds the middle one by string interpolation:

```tcl
return [list "let Rbase = $rb" \
             "wrs2p [s2p_file $state $idx]" \
             {unlet Rbase}]
```

`s2p_file`, in the same file, returns an **absolute** path —
`file join [::ase::rundir $state] <cell>_ase_sp<idx>.s2p` — so the checkout path is inside
that word, and the word reaches an ngspice control line with **no quoting at all**.

**What is measured, what is read, and what is still inferred:**

* **READ, and certain:** the interpolation is unquoted, and the interpolated value is an
  absolute path containing the checkout path. Two procs, both in `src/ase.tcl`, cited by
  name because a line number rots.
* **MEASURED:** the red/green split of two otherwise identical trees, above and in S2a/S2c.
* **STILL INFERRED, and this is the important one:** that the unquoted path is *why* those
  rows red. **Nobody has captured the deck ngspice was given, run it, and looked at where
  the file landed.** The original attribution — ngspice lowercasing an unquoted word — is
  likewise inferred, and it is *not* what the space reproducer suggests. Do not write
  "ngspice lowercases the path" into a fix commit; measure it.
* **UNESTABLISHED:** that the other four suites fail through this call site at all. They may
  not.

## 3. Consequently this is not "a capital letter" — it is a path ngspice cannot take literally

Item A's verifier also measured, in passing, that a checkout path containing a **space**
reds **71 rows across five suites**, all of them simulator-invocation rows — far more than
the 18 counted lines this file records for the uppercase case. A space splits an unquoted
word into two arguments, which is a plainer and better-understood failure than case folding,
and it points at the same unquoted interpolation.

That finding is filed as issue **1490** (it was not folded in here, because nobody has yet
shown the two are one bug, and burying the larger reproducer in a file named "uppercase"
would hide it). Taken together the two say the trigger is not a letter's case but
**a path the ngspice control line cannot take literally**.

⚠ **So the product claim widens, and it is the half a user meets.** This file already said a
user under `~/Projects/…` would get an S-parameter export that silently lands nowhere. Add
the space: `~/Documents/My Designs/`, `/mnt/c/Users/Jane Doe/…` — the ordinary Windows home
seen from WSL. **Any user whose project path carries a capital or a space is exposed**, with
no error, because ngspice wrote what it was told to write. That is a product defect, not a
test one, and it is the reason to fix the deck line rather than the suites.

## Still open (4)

1. The mechanism is not traced: no deck captured, no ngspice run observed, nothing looked at
   where the file actually landed (fix direction 1).
2. No product fix — the `wrs2p` argument is still unquoted, and no sweep has been made for
   other unquoted path interpolations onto control lines.
3. Case and path length are still not separated for `test_ase_converge_1459`,
   `test_ase_campaign_1462` and `test_ase_campaign_gui_1464`; and whether they share this
   call site at all is unestablished (fix direction 2).
4. No T1-visible row, so every green T1 ever taken was taken at a path with neither a capital
   nor a space (fix direction 3, and issue 1490's step 4).
