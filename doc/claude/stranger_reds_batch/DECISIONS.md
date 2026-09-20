# Decisions — stranger reds batch

# D1 — The audit's remaining findings are one batch, dispatched one item at a time (driver)

Issues 1483-1487 and 1489 were filed rather than fixed when the outsider-fixes batch
closed. They share one subject: what someone who is not this developer meets on first
contact with the branch we publish. They are dispatched in the order of PLAN.md's table,
one crew at a time, each returning a receipt.

# D2 — Rounds are capped at three, and the cap is part of the brief (driver)

The previous batch ran eleven implement-and-refute rounds on one item; the last three
shipped nothing. Each item here gets one implement round, one adversarial verify and at
most one fix round, with the acceptance criteria written before the first round rather
than after the fifth.

# D3 — A corpus list is an enumeration question, not a trackedness question (driver)

Issue 1485's nine suites all asked git the same thing: "the `.state` files of this
checkout". Git was the cheapest enumerator, not the subject. So the fix enumerates the
same files from the filesystem when git cannot answer, and coverage does not move: an
export carries exactly the tracked files, and all nine keep every check (1284 across the
nine, in an export, in a clone with `.git` removed, and in a normal clone).

Skipping was rejected as the default. A stranger's run would have gone green by measuring
less, which is the failure this batch exists to remove rather than a fix for it. A row
that genuinely needs git — trackedness itself, a revision, a diff — reads the helper's
`source`/`reason` and prints its own `skip:` line naming what is missing. None of the nine
needed to.

Three consequences the verifiers measured, all now in the code:

* **The filesystem arm is a superset of the index**, so a row that reads it must assert a
  floor, not an equality. Four rows asserted "exactly 104 files" and went red the moment
  somebody saved their own bench — ordinary first use. They are floors now; their shape
  halves stay exact, so a 105th file must still round-trip.
* **"Git answered nothing" is not the same as "git cannot answer here."** Falling back on
  an empty list hid a real defect: in a clone where the corpus had stopped being tracked,
  all nine passed by measuring untracked files instead. The helper now asks which
  repository git is answering about, which also catches an export unpacked inside someone
  else's checkout (measured: 50 of 104 files, at exit 0, with nothing saying so).
* **A corpus read must never raise.** `glob -nocomplain` suppresses "no matches", not
  "permission denied", so one unreadable directory killed three suites outright — the
  very shape 1485 is about. Unreadable and symlinked directories are counted and named in
  the run's `note:` line instead.

# D4 — Two findings from item A's verifiers are filed, not fixed (driver)

A checkout path containing a space reds 71 rows across five suites, and a read-only
checkout fails `test_scratch` and `state_roundtrip.tcl`'s temporary file. Both are
stranger-facing and neither is issue 1485. They are filed as new issues (PLAN.md criterion
4) and will be scheduled on their own.
