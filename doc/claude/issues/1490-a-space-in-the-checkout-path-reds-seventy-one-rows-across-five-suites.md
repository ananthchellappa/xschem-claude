# 1490 — a space in the checkout path reds 71 rows across five suites

**STAMP:** `v1 claim=open tree=1f3f5287 stamped=2026-09-20 fix=none open=4 by=A-docs`

**Status: OPEN — filed 2026-09-20** by the stranger-reds batch, from item A's adversarial
verifier (finding **R6**), under batch decision **D4**: a finding outside the item being
worked is written down and filed, never fixed on the way past.
**Class** stranger-facing false red in T1, with a **product** defect underneath it that a
user can hit without running a test at all.
**Related: issue 1484**, which is the same class measured with an uppercase letter instead
of a space. Read the two together; see "Why this is not filed as a duplicate of 1484".

---

## What happens

Unpack the ZIP, or clone the repository, into a directory whose path contains a **space** —
`~/Downloads/xschem stuff/`, `/mnt/c/Users/Jane Doe/dev/`, `~/Documents/My Designs/` — and
build it. **Five suites go red, 71 rows in total, and every one of them is a
simulator-invocation row.** The same tree at a path with no space is green.

(They are presumably the ASE suites — every row is a simulator-invocation row, and issue
1484's five are all `test_ase_*` — but the receipts do not name them, so this file does not
either. "ASE" is deliberately not in its title for that reason.)

Nothing about the tree is different. The only variable is the name of a directory above it.

## What was measured, and by whom

| | |
|---|---|
| measured by | item A's `reproduce` verifier, 2026-09-20 |
| tree | `bbc9de1a` plus item A's then-uncommitted files (the fix landed as `1f3f5287`) |
| result | **5 suites red, 71 rows**, all simulator-invocation rows |
| recorded in | `doc/claude/stranger_reds_batch/receipts/A-verify.md` (finding R6) and `receipts/A-impl.md` (§F5), and `DECISIONS.md` D4 |

⚠ **The aggregate is all that survives, and that is a gap in this file rather than a
softening of the finding.** The receipts record "5 suites, 71 rows, all simulator-invocation
rows"; they do not enumerate the suites or name the rows. The per-row detail was in the
verifying crew's own logs, and the batch brief requires a crew to delete its scratch
(`CREW_BRIEF.md`, and `PLAN.md` criterion 6), so the logs are gone. **Whoever takes this
item re-measures first.** That is two builds and one loop over the suites, and it hands back
the row names this file cannot — see "Fix direction" step 1.

### Corroboration from the same class, with an uppercase letter instead of a space

Item A's implementer and its fix round both hit issue 1484 by accident, because the scratch
root they were assigned had a capital `A` in it — one directory name apart, **same commit,
same binary, same fresh throwaway HOME, same `AUDIT_DISPLAY=none`**:

| export built at | `test_ase_variant_1470` | `test_ase_sp_1452` |
|---|---|---|
| path with an uppercase `A` | `OT1` **FAIL** | `SE1/apt` **FAIL**, `SE1/fork` **FAIL** |
| the all-lowercase sibling | `OT1` **ok** → `ALL PASS (76)` | `SE1` **ok** → `ALL PASS (58)` |

Those two rows belong to issue **1484**, and they are now measured rather than inferred —
1484 records that. They are quoted here because they are the cheapest existing evidence that
the *class* is real: the checkout path reaches a simulator invocation, and the simulator
does not get the path back.

⚠ **The two sightings are not equally strong.** The implement round's is the clean one: two
trees, each built from scratch at its own path. The fix round's is a `cp -a` of a tree built
elsewhere, so it corroborates and does not repeat the experiment. Both are recorded in
`receipts/A-impl.md` §7.1 and `receipts/A-verify.md` R6, which say so themselves.

## Why it happens — the mechanism, READ from the code and not traced

`sp_export_lines` in `src/ase.tcl` (namespace `::ase::backend::ngspice`) returns the three
ngspice control lines of one S-parameter row. The middle one is built by string
interpolation:

```tcl
return [list "let Rbase = $rb" \
             "wrs2p [s2p_file $state $idx]" \
             {unlet Rbase}]
```

`s2p_file` in the same file builds an **absolute** path — `file join [::ase::rundir $state]
<cell>_ase_sp<idx>.s2p` — so the checkout path is inside the word, and the word goes onto an
ngspice control line **unquoted**. A space splits it into two arguments there. That is a
word-splitting defect, and it is a plainer explanation than the lowercasing that issue
1484's uppercase variant was attributed to.

⚠ **Stated as it is known.** The interpolation and the absolute path are a **READ of
`src/ase.tcl`** and are certain. That the split is what reddens these 71 rows is
**INFERRED** from the red/green split of two otherwise identical trees. Nobody has yet run
ngspice by hand with a spaced path, captured the deck, and looked at where the file landed.
Do that before writing a fix — and do not assume that the other suites in the red set share
this one call site.

## Why this is not filed as a duplicate of 1484

1484's title, and the whole of its measured set, is *"an uppercase letter"*: five suites and
**18** counted lines. This finding is a **space** and **71** rows. Same class, probably the
same cause, and **nobody has shown they are one bug** — that is the first thing to settle,
not something to assume by filing them as one number. Filing them together would also bury
the larger reproducer inside a file whose name says "uppercase". 1484 has been widened to
name the mechanism and to point here; if the measurement in step 1 shows one cause, close
this one into 1484 then, with the evidence in hand.

## Why a user cares, and not only a tester

The rows are tests, and the defect they trip over is not test-side. If the mechanism above
holds, then **any user whose project lives under a path with a space in it gets an
S-parameter export that silently lands somewhere else, or nowhere** — with no error, because
ngspice took a truncated word as the filename and wrote what it was told. On this platform
the shape is not exotic: `/mnt/c/Users/<First Last>/` is the ordinary Windows home seen from
WSL, and `~/Documents/My Designs/` is what a person actually types.

That widens issue 1484's own product claim from *"a capital letter"* to **"a path the
ngspice control line cannot take literally"**, which is the sentence both files now carry.

## Fix direction

1. **Measure it, and name the rows this file cannot.** Two clones of the same commit, both
   built, one at `…/sp space/` and one at `…/spspace/`; run the ASE suites through the armed
   driver and diff the verdicts. Record the five suite names and the 71 row ids in this
   file. Then run the S-parameter export by hand in the spaced tree, keep the deck ngspice
   was given, and look at what was written and where — that is the step that turns the
   mechanism from READ to TRACED.
2. **Fix it where the deck line is built**, not in the suites. The argument to `wrs2p` needs
   whatever quoting or escaping ngspice's control-line parser actually honours — check that
   before choosing, because a quoted word that ngspice takes *literally including the
   quotes* is a second defect wearing the fix's clothes.
3. **Sweep for siblings.** `wrs2p` is one interpolation onto one control line. Any other
   place in `src/ase.tcl` that interpolates a path into a control line has the same defect
   whether or not a test currently reaches it.
4. **Add a T1-visible row** that a regression cannot walk past: a run directory whose name
   contains a space (and one with a capital), whose export must round-trip. Until such a row
   exists, this defect is invisible to every green T1 that has ever been taken, because
   every one of them ran at a path with neither.

## Still open (4)

1. The five suites and the 71 rows are not named anywhere — re-measure (step 1).
2. The mechanism is READ, not traced: no deck captured, no ngspice run observed (step 1).
3. No product fix for the unquoted control-line path (steps 2 and 3).
4. No T1-visible row, so nothing catches a regression or a recurrence (step 4).

## Evidence

`doc/claude/stranger_reds_batch/receipts/A-verify.md` — finding **R6** (the aggregate, the
rejection for item A, and the mechanism); `receipts/A-impl.md` §7.1 (the uppercase pair,
measured twice) and §F5; `doc/claude/stranger_reds_batch/DECISIONS.md` **D4**.
Code: `sp_export_lines` and `s2p_file` in `src/ase.tcl`.
