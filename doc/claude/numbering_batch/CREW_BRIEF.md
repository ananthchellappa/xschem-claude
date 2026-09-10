# Crew brief — the cross-checkout numbering collision

You are running **one item** from `PLAN.md`, end to end: scout, measure, RED,
implement, verify, write up, ledger row. You do not commit — the driver does.

## Non-negotiable

* **Read `DECISIONS.md` first.** D-1 forbids editing
  `/home/analog/dev/xschem-op-wcard` in any way. Read it to measure; never
  write to it. D-4 makes the shared ledger append-only for this batch.
* **You own only the files your item names.** Another item owns the rest. If
  you need a change in a file you do not own, say so in your write-up.
* **RED before green.** Show the new checks failing first.
* **Never run `owed.sh` against the real ledger.** Export a throwaway
  `XSCHEM_OWED_DIR` pointing inside your scratch directory. `add` and `clear`
  against `$HOME/.claude/xschem_owed` are destructive and a live op-wcard
  session is writing that directory right now.
* **Never `git checkout --`, `git restore`, `git stash`, `git clean`.** There is
  uncommitted work in this tree. Never `git push`, never open a PR, never
  commit.
* **Never touch, move, back up or read-modify-write anything under
  `~/.xschem/`.** Reading is fine.
* **Never a bare `xschem`** on `PATH` — it is a 3.4.6 binary that rewrites the
  user's recent-files (issue 0924). Nothing in this batch should need the
  binary at all.
* **Issue numbers come from `doc/claude/issues/NUMBERING.md` and nowhere else**,
  and in this batch only item N1 may touch it or mint one.
* UI and user-facing copy is **terse**, and acronyms are **UPPERCASE** (PDK,
  SPICE, RDW, ASE-L, CIW, PATH).

## ⚠ `grep` in this shell is not GNU grep

It is a shell function routing to **ugrep**, with `-I --ignore-files` forced —
so it skips gitignored files, and it **silently returns 0** for a
single-alternative numeric pattern that GNU grep matches six times. Measured on
`NUMBERING.md`:

| pattern | ugrep (`grep`) | `/usr/bin/grep` |
|---|---|---|
| `(^\|[^0-9])1338([^0-9]\|$)` | **0** | **6** |

**Every count you report must be taken with `/usr/bin/grep`.** A number taken
with the bare `grep` function is not evidence, and this batch was nearly
mis-scoped twice by exactly that.

## What "measured" means here

The design work behind this batch was adversarially attacked and several of its
numbers did not survive. Do not inherit a figure from `PLAN.md` without
re-taking it. Where you assert a count, say the command that produced it. Where
you are inferring rather than measuring, **label it in the write-up** — every
prior report in this batch did, and it is the reason the mis-scopes were caught.

## Your write-up

`doc/claude/numbering_batch/receipts/<item>.md`. Say what you changed, the
commands that prove it, what you left alone and why, and anything you found
that the plan gets wrong. A finding that contradicts `PLAN.md` is a good
result, not an awkward one — say it plainly.

## Your ledger row

Append it to `LEDGER.md` yourself. A missing row is how a batch loses track of
itself.

## The rule this batch exists to defend

A `rule` or `look` debt clears **only when the user says so**. A suite debt
clears on a pass. No command converts one kind into another. The defect being
fixed is that a second checkout can destroy a ruling the user has not answered,
silently — so nothing you write may acquire that power, including in a test.
