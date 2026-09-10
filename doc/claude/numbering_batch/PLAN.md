# Plan — the cross-checkout numbering collision

## What is actually wrong

`doc/claude/issues/NUMBERING.md` is a **tracked, per-branch file**. CLAUDE.md
names it "the ONLY authority" on issue numbers and tells a filer to read its
tail. A tracked file structurally cannot see across a clone boundary, so two
checkouts of this repo on one machine each read their own tail honestly, each
found the same block free, and each filed into it. Neither session did anything
wrong by the rule as written. **The rule is what is broken.**

Measured, 2026-09-10, read-only in both clones:

| | this branch (`fluid-editing`, filed 2026-09-05) | `xschem-op-wcard` (filed 09-09/09-10) |
|---|---|---|
| 1338 | `1338-updown-move-the-store-but-not-the-window.md` | `1338-pdf-link-border-invisible.md` |
| 1339 | `1339-select-and-ctrl-c-do-not-copy.md` | `1339-pdf-link-hotspot-tracks-name.md` |
| 1344 | `1344-the-rdw-puts-the-wrong-text-on-the-clipboard-and-wipes-it.md` | `1344-negative-page-scale-mirrors-export.md` |
| 1345 | `1345-the-rdw-says-did-not-converge-...md` | `1345-export-page-scale-follows-the-canvas.md` |
| 1346 | `1346-the-keys-suite-is-noisy-under-cpu-load-...md` | `1346-link-prefs-read-once-per-link.md` |
| 1347 | `1347-the-rdw-summary-reorder-...md` | `1347-issue-numbers-collide-across-checkouts.md` |
| 1348 | `1348-a-flavor-reorder-reslots-a-block-...md` | `1348-two-pages-can-share-one-pdf-destination.md` |

Seven collisions by **filename**. **Sixteen by NUMBERING.md's own authority** —
op-wcard carries NUMBERING entries for every number `1333–1348`; nine of them
have no issue file only because that batch fixed them in flight, and two of its
commit subjects already name them. The two reserved bands overlap outright:
this branch's `## Reserved: 1337–1341, the RDW batch` sits inside op-wcard's
`1333-1348 are reserved`.

The 1348 pair landed at **08:25 on 2026-09-10**, while the collision was being
measured. It is not a closed historical set.

## The part that is worse than the past

op-wcard's tail says **next free 1349**. This branch has committed every number
from **1349 to 1399** — verified, no gaps. Its next free is 1400.

**op-wcard is currently aimed at 51 consecutive guaranteed collisions**, and
nothing in either tree reports it at any point. Under D-1 this batch cannot fix
that. It can only make sure this side is ready.

## The ledger is the live hazard

`~/.claude/xschem_owed/` lives in `$HOME`, outside both clones, so both trees
write one ledger. Two paths destroy a ruling:

* `cmd_clear` (`tests/headless/owed.sh:288-295`) resolves by **exact filename**.
  `clear rule 1339` today succeeds and deletes op-wcard's link-hotspot ruling
  while this tree's `1339_R3_copy_says_what_it_did` survives. No error.
* `cmd_add` (`:188`) is a bare `>` with **no existence check**. It prints
  `recorded`, never `replaced`. `add rule 1344` from the other tree silently
  truncates this tree's standing 1344 ruling.

Live today, three bare 4-digit ids on collided numbers: **`rule/1337`**,
**`rule/1339`**, **`rule/1344`**. Loaded for later: **35** bare 4-digit rule ids
inside `1349–1399`.

Renumbering does **not** repair this. The ledger is outside both clones, no
`git mv` reaches it, and `owed.sh` has no rename command. The ledger needs its
own fix, and it needs it whether or not anything is ever renumbered.

~~**No ruling has been lost.**~~ **SUPERSEDED — two have.** That sentence was true
when it was measured at 08:19 on 2026-09-10 and false by the afternoon. The other
clone's `owed.sh add` overwrote this branch's standing, unanswered rulings **twice
while this batch was running**: `rule/1351` at **10:46:14** (an RDW decision about a
selection that outlives its text) and `rule/1357` at **13:25:32** (Add-on-the-summary-list
writing the annotation list). Both were recovered, and recovered **only** because a
hand-taken `cp -a` happened to exist — nothing in the ledger records a destroy, and
an in-place `>` moves no directory mtime and changes no file count, so nothing
reports it either. The lesson is not that the audit was sloppy. It is that **this
ledger cannot tell you when it loses a ruling**, so an audit of it can only ever be
true as of its own clock.

The paragraph below still holds as written, for the period it covers:

Verified: all ten of op-wcard's ledger entries were
accounted for against its own session transcripts, and every one of the eight
`cleared rule debt` events across all sessions was same-tree. The bare `1338`
that the incoming report saw was op-wcard's own, answered and cleared by
op-wcard at 06:54 on 2026-09-10. It survived on a naming coin-flip: this tree
used a bare id for `1344` and a suffixed one for `1338`.

---

## Items

Each item owns the files it names and **nothing else**.

### N1 — the record and the reservation
**Owns:** `doc/claude/issues/1400-*.md` (new), `doc/claude/issues/NUMBERING.md`.

1. File issue **1400** — this branch's next free number, taken from
   NUMBERING.md's tail. It is the tree-local record of the collision: the
   mechanism, the measured table above, the measured merge behaviour, the
   ledger hazard, and the options left open for the user.
2. `NUMBERING.md`:
   * add the reserved block **`1500–1599` — the op-wcard branch**, with the
     skip rule in the same shape as the three that are already there: *after
     **1499**, the next number is **1600***;
   * `Three blocks are reserved` → **Four**;
   * publish the **`1333–1348` → `1500–1515`** absorption map, so whoever
     performs the absorption applies it instead of re-deriving it;
   * annotate the `next free number` line: it is **per-clone** and cannot see
     another checkout of this repo — the sentence that reads most like an
     authority is the one that is blind;
   * record 1400 as filed; next free becomes **1401**.

### N2 — `owed.sh` learns which clone an entry came from
**Owns:** `tests/headless/owed.sh`, `doc/claude/specs/owed.md`.

* `_origin()` — `git rev-parse --path-format=absolute --git-common-dir`.
  Distinct per clone, **unified across that clone's worktrees** (which the
  ledger's whole rationale depends on, `owed.md:75-77`), survives a branch
  switch and a `git remote set-url`. Fall back to `realpath "$HERE/../.."` when
  there is no git, and say which was used. Both clones' remotes point at the
  same GitHub repo and both root commits are identical, so **neither the remote
  nor the root commit can name a clone** — they were measured and rejected.
* `cmd_add` stamps `repo:` on line 2+ (R607 growth; line 1 stays frozen).
* `cmd_add` on an existing `rule`/`suite` id from **another** origin: **refuse,
  non-zero**, print what is standing there and who owns it. This is the path
  with 35 loaded barrels and today it is completely silent.
* `cmd_clear` on a foreign entry: **refuse, non-zero**, print the entry's
  origin and reason **and the ids in this tree carrying the same number**
  ("did you mean `1339_R3_copy_says_what_it_did`?").
* A `--repo <id>` escape on **both** `add` and `clear`, for when the user
  really does mean the other tree's. `add` needs it as much as `clear`: without
  it, a second clone cannot record a legitimate ruling for its own issue number
  at all, and the only workaround — suffixing the id — silently drops the `ref:`,
  because `_issue_ref`'s gate at `:131` accepts bare 4-digit ids only.
* `cmd_drain` **skips** a suite debt whose origin is not this clone (7 of 8
  suite names resolve in both clones and 6 of those 7 files differ in content,
  so a wrong-tree drain runs the wrong suite and clears the other tree's debt
  on a pass).
* Both drain rewrite arms (`:399` UNRESOLVED, `:424` FAILED) must **preserve
  lines 2+**. Today both truncate with `>`, so a stamp erodes exactly where
  debts live longest, and a hand-written verdict is destroyed by one red run.
* An entry with **no `repo:`** is **unattributed**: proceed as today with a
  one-line warning and stamp it on the way through. 191 legacy entries and
  every `clear rule <id>` command quoted in receipts keep working unchanged.
* `list`/`show` mark a foreign entry, and mark a `ref:` that does not resolve
  in this tree — 42 of 132 rule entries point at a file only this clone has,
  and from the other one they are a path with no explanation.
* Append-only `cleared.log` inside the state dir (R502 permits it) capturing
  the full entry text on **every clear and every overwrite**. `cmd_clear` is an
  `rm`; the tree is already doing this by hand in `doc/claude/ledger/`. The
  only reason the 1338 forensics were possible at all is that a tool result
  happened to persist — that is luck, not a ledger.
* Spec: new **R608** (origin recorded and shown when foreign), new **R609**
  (cross-origin `clear`/`add` refuses and prints candidates), amend **R602**
  (dedupe by id **within an origin** — "a ruling *is* its issue number" is
  precisely the assumption that broke), amend **R301/R303** (a suite debt
  resolves against its origin clone, not `$HERE`), and retire "one ledger
  serves the main session and every worktree" as the whole story: **a second
  clone is not a worktree, and `$HOME` cannot tell them apart.**

### N3 — the checks
**Owns:** `tests/headless/test_owed.sh`.

New rows continuing the existing `O<n>` numbering, against a throwaway
`XSCHEM_OWED_DIR` and a **two-fake-clone** fixture. Must cover, at minimum: the
stamp; the foreign `clear` refusal and its candidate list; the foreign `add`
refusal; `--repo` on both; unattributed-proceeds-with-warning and gets stamped;
drain skipping a foreign suite debt; **both** drain rewrite arms preserving
lines 2+; `cleared.log` capturing a clear and an overwrite; and O9/O18 still
holding — drain touches neither the look list nor the rule list.

**RED before green**: show the new checks failing against the unmodified
`owed.sh` first.

### N4 — the rule that produced the defect
**Owns:** `CLAUDE.md`.

The numbering paragraph currently says NUMBERING.md is "the ONLY authority" and
"read its tail before filing". Both halves are why this happened. Amend it:
NUMBERING.md is **tracked and per-branch**, so it is authoritative about what a
number **means** and structurally blind to any other checkout of this repo;
before minting, grep **every** clone, not just this one; the `1500–1599` band
is reserved. Also amend the owed-ledger section: the ledger is shared by every
clone, not just every worktree, and `add`/`clear` now refuse across origins.

## Out of scope, and why

* **The `numbers.sh` allocator** — a `$HOME` claim registry, the actual
  prevention. A working 264-line prototype exists and races clean (60
  concurrent claimants alternating between the two real clones: 60 distinct, 0
  duplicates; 400-claim soak the same), but its adversary broke four things
  that must be fixed before it ships, and it needs a `test_owed.sh`-grade suite
  and a spec. It is its own batch. Under D-1 it would also change nothing
  today: it only helps once the *other* clone runs it.
* **Renumbering anything.** D-3 is unratified and D-1 forbids the tree that
  would move.
