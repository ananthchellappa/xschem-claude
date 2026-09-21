# 1334 — a mixed-case run folder silently loses the operating-point dump, and the probe cannot see it

**STAMP:** `v1 claim=fixed tree=a1314271 stamped=2026-09-20 fix=taken open=1 by=C-docs`

**Status:** FIXED (this branch) — **unchanged.** The fix below still stands and still
behaves exactly as described.
**Files:** `src/ase.tcl`
**Found by:** review of the `op-wcard` sibling branch, 2026-09-05

⚠ **Read "2026-09-20 — the underlying defect is fixed, and the refusal may be liftable" at
the foot of this file.** The fix here is a **refusal**: ASE-L declines the fast
operating-point dump and asks the user to rename their folder. Issue 1484/1490's item C
fixed the defect that refusal was working around, so the refusal may now be liftable —
**which is the user's decision and is filed as a rule debt, not a change made here.**
`open=1` is that ruling.

⚠ **`tree=a1314271` qualifies the 2026-09-20 section and this header.** The measurements in
the body below were taken on 2026-09-05 against `build-ver_50` and have **not** been
re-taken; nothing has contradicted them, and nobody has re-run them either.

## What was wrong

ngspice case-folds the **whole** `show >` redirect target, directory component
included, and exits 0 having written nothing when the folded directory is
absent. `op_annot::opdump_path` lowercases the path itself so that the asking
and reading sides agree — but agreeing on a path ngspice cannot write to only
makes the failure consistent, not survivable.

**The probe cannot detect it.** Capability deck C asks with a *relative* target,
`show all > probe_c.txt`, which has no directory to fold. So a probe that
watched the printer work says nothing whatever about the path the real deck will
use.

## Measured

`build-ver_50`, same cell, only the run directory changed:

| rundir | probe | tier | exit | raw | `.opinfo` | annotation |
|---|---|---|---|---|---|---|
| `lower_ok` | 1 | d | 0 | good | written | five values |
| `MixedCase` | 1 | d | 0 | good | ***never written*** | **five blank** |

**Control, same `MixedCase` directory, per-device shape on 45.2: all five rows
annotate.** So this is not a hazard the older shape shares — it is a regression
shape `d` introduces.

Bare ngspice, both builds:
```
show all > MixedCase/Up.opinfo    -> exit 0, nothing written, no stderr
```

## Not fixed here, and deliberately

A **space** in the run directory also breaks the redirect (ngspice splits on it
and creates a junk file named after the first word). It is refused by the same
predicate, but it is **not this feature's bug**: measured control, the shipped
per-device shape on 45.2 in a directory with a space fails to write the raw at
all. That is a pre-existing ASE-L defect, orthogonal, and not filed here.

## The fix

`ase::op_dump_reachable_dir` is a **pure string predicate** — no filesystem —
because the hazard is decided by the spelling of the path and nothing else,
which is what lets the guard run before the run directory exists.
`ase::op_dump_dir` reads the directory without creating it (`set_netlist_dir 2`,
the read-only spelling; `ase::rundir`'s own fallback is `0`, which mkdirs, and
`ase::op_tier_report` calls this path just to *describe* a run).

New guard **G3b**, above G3a, with its own reason token `dumppath` — because
`c unsafe` would say the shorter way is risky when what is actually true is that
this run folder's *name* defeats the redirect. It gets its own
`op_tier_perdevice` sentence naming the remedy.

After: `MixedCase` selects `tier c reason dumppath` and annotates all five rows.

Rows X1–X6 of `tests/headless/test_op_dump_altshow.tcl`.

---

# 2026-09-20 — the underlying defect is fixed, and the refusal may be liftable

Added by the stranger-reds batch, item C docs, at `a1314271`. **Nothing in this file's
status or behaviour is changed by this section.** It records a measurement and a question,
and the question is the user's.

## What changed underneath this issue

This file's fix is a **refusal**. `ase::op_dump_reachable_dir` declines the fast
operating-point dump whenever the run folder's spelling defeats ngspice's redirect, and the
user-facing sentence says so in as many words (quoted from `receipts/C-impl.md` §7, item 2):

> *"it writes the numbers through a path it converts to lower case and cuts at the first
> space … Rename the run folder in lower case with no spaces to get the faster way."*

Item C of the stranger-reds batch (issues **1484** and **1490**, commit `a1314271`) fixed
the defect that sentence is working around. The mechanism is now **TRACED**, not inferred —
MEASURED on `/usr/bin/ngspice` **45.2** and on the ASE registry's fork
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (**46+**), and confirmed against
`inp_readall` in ngspice's own `src/frontend/inpcom.c`:

* **a control line whose command is not on ngspice's whitelist is lowercased in full**, and
  **every** control line splits an unquoted path at the first space — which is exactly the
  two halves this file measured in 2026-09-05 without being able to name them;
* **quoting does not work** (`wrs2p "<path>"` keeps the quotes as part of the filename and
  writes nothing, at rc 0, in a directory with neither a capital nor a space);
* **`setcs v = '<path>'` followed by `$v` does**, on both binaries, for every one of the ten
  commands measured — because `setcs` is on the whitelist and `$v` expands *after* the
  reader has folded the line it sits on.

At the product level, one bench writing six artifacts through
`ase::backend::ngspice::render_deck`, rc 0 throughout (`C-impl.md` §F2.1): base wrote
**6 / 3 / 1** artifacts in a `plain` / `Cap` / `w s` run directory, the fix wrote
**6 / 6 / 6**. That is the escape this refusal did not have when it was written.

## The measurement that bears directly on lifting it — including a negative one

The fast dump is `show all > <path>`. `show` is on **neither** of ngspice's whitelists, so
the dump is *a bare word on a folded control line* — **the exact shape the new escape
handles**. That is the case for lifting.

⚠ **And item C wrote the lift, measured it, and threw it away.** Quoting `C-impl.md` §7,
item 2, in full because the negative result is the useful half:

> **With a general escape in hand that refusal can be lifted**, which would give every user
> with a mixed-case project folder the faster shape back. I did **not** do it: it is
> user-visible behaviour, it retires a user-facing sentence, and it needs its own end-to-end
> measurement that the dump really lands on both binaries. **I wrote the emitter fix,
> measured that it is unreachable behind 1334's guard, and reverted it** rather than ship a
> third mechanism on top of two deliberate workarounds. `src/op_annot.tcl` is untouched.

So: the emitter change was **written**, it was **measured unreachable** because this file's
own guard refuses before the emitter is ever asked, and it was **reverted**. Lifting the
refusal is therefore not a code change on its own — the guard has to go first, and the
reader side (`op_annot::opdump_path`, which pre-lowercases the target so the asking and
reading sides agree) has to go with it.

## ⚠ In `a1314271` this refusal became WIDER, not narrower

This is the part that matters most if the ruling goes the other way, and it is already in
the shipped code. The guard tested for lower case plus `[ \t\n]`. Two measured failures
walked straight through it (`C-impl.md` §F1.3, both binaries):

```
show all > /var/tmp/…/my$dir/f.txt   Error: dir: no such variable. / No such file
                                     or directory   rc 0, NOTHING WRITTEN
show all > /var/tmp/…/o'b/f.txt      an error line, rc 0, NOTHING WRITTEN
```

Both answered *"reachable"*. `ase::op_dump_reachable_dir` now routes through
`path_bare_ok $dir 1` — **the same predicate the escape uses**, so guard and escape are one
rule — and row **`X4b`** of `tests/headless/test_op_dump_altshow.tcl` pins that it refuses
`$`, a backquote, braces, an apostrophe and a newline while still accepting an ordinary
directory. The receipt's justification is this file's own reasoning, restated:

> **A refusal costs only the fast shape** — the per-device dump still runs and still
> annotates — so widening it can slow a run and can never lose a number, which is the
> direction 1334 chose on purpose.

**Consequence for the ruling:** the folders this feature declines are *more* numerous today
than when 1334 was filed, not fewer. A user with `O'Brien` in a path meets the refusal now
and did not before — correctly, because they were previously losing the dump in silence.

## Two rows that are this refusal, not a defect

* `test_ase_variant_1470 OT1` is red in a capital checkout and reads the reason token
  `{c dumppath}` — *this guard, working as designed*. Issue 1484 records it as one of its
  two remaining rows and attributes it here.
* `test_op_dump_altshow` **dies** (`NORESULT`, exit 0 with no `RESULT` line) in a capital
  checkout, because the suite takes its own fixture dump with `show >` into a scratch that
  carries the checkout's capital. MEASURED identically with `HEAD`'s `src/ase.tcl` in the
  same tree, so it is **pre-existing** and not caused by `a1314271`. It is **not a T1 case**.
  Carried on issue **1484**, not here.

## This is the USER's decision, and it is filed as a rule debt

Lifting the refusal is **user-visible product behaviour**: a feature that currently declines
would start working, and the sentence asking people to rename their run folder would be
retired. That is not a batch's call (`doc/claude/stranger_reds_batch/DECISIONS.md` **D8**:
*"That is user-visible product behaviour, so it is the user's call, not the batch's: filed
as a ruling rather than changed."*).

Filed in the owed ledger on **2026-09-20 19:24**, `~/.claude/xschem_owed/rule/1334`,
stamped `repo:/home/analog/dev/xschem-claude`:

> ASE-L refuses the fast operating-point dump when the run directory has a space or a
> capital, and asks you to rename your folder (issue 1334). Item C fixed the underlying
> ngspice path defect (`a1314271`), so the refusal may be liftable. Lifting it is
> user-visible: the feature would start working where it currently declines. Needs your
> ruling and its own measurement.

**A rule debt clears only when the user says so.** Until then this file's status stays
**FIXED**, the guard stays in place, and nobody lifts it on the strength of a green suite.

**What a lift would have to measure first**, if it is ruled for: that the dump really lands
on **both** binaries through the escape, end to end — the emitter change alone is known to
be unreachable (above), and `show all > $var` has not been measured the way the other ten
commands were.

## Still open (1)

1. Whether to lift the refusal now that the underlying defect is fixed. The user's ruling,
   filed as `owed.sh rule 1334`. Not a defect and not scheduled.
