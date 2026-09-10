# N4 — adversary

**Verdict: SOUND WITH FIXES.**

Every factual claim in the two new `CLAUDE.md` paragraphs reproduced under
`/usr/bin/grep` and under a fresh two-real-clone `owed.sh` fixture. Nothing in the
shipped text is false. What it has is a **check that cannot see a reserved band**
(measured false green on the very band this batch reserved), an instruction it
deleted and did not replace, and two paragraph-level over-reads about the ledger as
it stands **today**. Ten fixes, all small, none requiring a rewrite.

Constraint compliance: clean. D-1, D-4, `~/.xschem/`, file ownership — all verified
below, all green, none of the drift attributable to N4.

---

## 1. What survived re-measurement (the item's own numbers)

All commands run from `/home/analog/dev/xschem-claude` unless a path says otherwise.

| receipt claim | command | result |
|---|---|---|
| `CLAUDE.md` +43/−9, 445 → 479 | `/usr/bin/git diff --numstat CLAUDE.md`; `git show HEAD:CLAUDE.md \| wc -l`; `wc -l CLAUDE.md` | `43 9`; 445; 479 ✓ |
| two hunks, no section added | `/usr/bin/git diff -U6 CLAUDE.md` | 2 hunks, at `:256` and `:445` ✓ |
| receipt's line refs | `/usr/bin/grep -n 'Issue numbers:' CLAUDE.md`; `… 'One ledger, every CLONE'` | 445; 256 ✓ |
| 50 committed behind op-wcard's tail | `/usr/bin/git ls-tree -r --name-only HEAD doc/claude/issues/ \| /usr/bin/grep -cE 'issues/13(5[0-9]\|[6-9][0-9])-'` | **50**; distinct numbers also 50; `seq 1350 1399` loop → **no gaps** ✓ |
| op-wcard's tail is 1350 | `tail -n 1 …/xschem-op-wcard/doc/claude/issues/NUMBERING.md` | `**The next free number is 1350.**` ✓ |
| sixteen taken in both | `/usr/bin/grep -cE '^\* \*\*13(3[3-9]\|4[0-8])\*\*' …/xschem-op-wcard/…/NUMBERING.md` → 16; loop over 1333‑1348 for files here → 16 | ✓ |
| nine of the sixteen have no file there | same loop against op-wcard | **9** — 1333 1334 1335 1336 1337 1340 1341 1342 1343 ✓ |
| seven naming two different defects | per-number basename compare, both clones | 1338 1339 1344 1345 1346 1347 1348 ✓ |
| 1349 taken the same morning | `stat -c '%y %n' …/xschem-op-wcard/doc/claude/issues/1349-*.md` | `2026-09-10 09:12:14` ✓ |
| the block runs verbatim, `n=1401` free | the 4 lines exactly as printed in `CLAUDE.md` | `ls` silent; grep → this clone's `NUMBERING.md` only ✓ |
| `n=1349` control finds both | same block | two issue files **and** two `NUMBERING.md`s ✓ |
| the ugrep trap on the `-l` form | `grep -lE "(^\|[^0-9])1349([^0-9]\|\$)" ~/dev/*/…/NUMBERING.md` vs `/usr/bin/grep …` | bare: nothing, rc=1. real: **both files**, rc=0 ✓ exactly as `CLAUDE.md` prints it |
| 1338 count is 5, not the brief's 6 | `/usr/bin/grep -cE '(^\|[^0-9])1338([^0-9]\|$)' doc/claude/issues/NUMBERING.md` | 5 ✓ (but see fix 9 for the *explanation*) |
| `1500–1599` row, after 1499 → 1600 | `sed -n '1,14p' doc/claude/issues/NUMBERING.md` | "Four blocks are reserved" + the row ✓ consistent with N1 |

Ledger-paragraph behaviour, re-verified against the **shipped** `owed.sh` in my own
fixture (two `git init` clones, `XSCHEM_OWED_DIR` in scratch, real ledger never
opened for writing):

* `cloneB add rule 1344` over cloneA's entry → `!! owed REFUSED … NOTHING written`, **rc=5**, entry byte-identical afterwards ✓
* `cloneB clear rule 1344` → `!! owed REFUSED … NOT cleared`, rc=5, prints its clone, what is standing, and `--repo cloneA` ✓
* `clear` listing this tree's own ids: with `1341` owned by A and `1341_R3_b_variant` owned by B, B's `clear rule 1341` printed **"this clone's own rule debts on that number: … clear rule 1341_R3_b_variant"** ✓
* `--repo here` on `add` → `recorded rule debt: 1344 (id 1344@cloneB, clone cloneB)`, rc=0 ✓
* the refusal is **not** rule-only: `add suite` cross-clone rc=5, `clear look <id>` cross-clone rc=5 ✓ (so `CLAUDE.md`'s unqualified "an `add` or `clear`" is right)
* legacy claim-on-touch: `add` over an unstamped entry → `WARNING … predates origin stamps -- claiming it for cloneB`, then `updated` ✓
* `clear` is an `rm`: `owed.sh:657` `rm -f "$f"`; drain's second `rm` at `:811`; the `>` and the `recorded`/`updated` split at `:415-446`; `OWED_DIR` at `:86` ✓ — every line reference in the receipt lands where it says

## 2. Constraint compliance

**D-1 — op-wcard untouched.** `/usr/bin/git -C /home/analog/dev/xschem-op-wcard status
--porcelain` → ` M src/psprint.c`, ` M src/save.c`, and untracked
`doc/claude/issues/1350‑1353-*.md`, `tests/headless/test_ps_valid_1350.tcl`. All of it
is that session's own PostScript/PDF work, and none of it is numbering-batch shaped.
The decisive file: `stat` on its `doc/claude/issues/NUMBERING.md` → **09:12:14**,
i.e. its own 1349 filing, untouched since, hours before N4 ran. No
`doc/claude/numbering_batch` exists there. Its regression suite ran 09:38–09:43
(`tests/create_save.log` 09:38:30, `tests/results.log` 09:43:02) and it rebuilt
`src/xschem` at 10:22 — all its own.

**D-4 — the shared ledger.** `~/.claude/xschem_owed`: rule **132**, look **52**, suite
**8** (192 files). `/usr/bin/grep -rl '^repo:' ~/.claude/xschem_owed | wc -l` → **0**.
No `cleared.log`. `find ~/.claude/xschem_owed -type f -newermt '2026-09-10 09:30'` →
**nothing**; the newest entry is `look/hier_pdf_links_1338_H4.1789056750.1637118` at
**09:12:30**. So look moved 51 → 52 by the **live op-wcard session** at 09:12 (same
minute as its 1349 filing), not by any batch item, and no batch item ran the new
`owed.sh` against the real directory — a single `add` or `clear` there would have
left a `repo:` stamp or a `cleared.log`, and there is neither.

**`~/.xschem/`.** Newest write is `geometry` at **09:51**; `.clipboard.sch` 09:39,
`simulations/*.spice` 09:39, `op_annot/` 09:42 — inside op-wcard's 09:38–09:43 suite
window, before N4 started. N4 wrote `CLAUDE.md` at **10:14:55** and its receipt at
**10:16:45**; nothing under `~/.xschem/` has changed since 09:51.

**Ownership.** Repo-wide, `find . -path ./.git -prune -o -type f -newermt '2026-09-10
09:30' -print` (minus the batch dir) returns exactly six files: `CLAUDE.md` (N4),
`doc/claude/issues/NUMBERING.md` + `1400-*.md` (N1), `tests/headless/owed.sh` +
`doc/claude/specs/owed.md` (N2), `tests/headless/test_owed.sh` (N3). **N4 wrote
nothing but `CLAUDE.md`.** (`doc/claude/ase_analyses_batch/` is untracked from
2026-09-09 22:46, predating the batch.)

**No verification here could only pass.** Each check above has a demonstrated red
counterpart: the `n=1349` control fails the free test that `n=1401` passes; the bare
`grep` returns the opposite answer to `/usr/bin/grep` on the same line; the
cross-clone `add`/`clear` exit 5 where the same-clone ones exit 0; `--repo here`
exits 0 where the bare form exited 5. The one exception is the "nothing in either
tree reports it" clause, which the receipt already labels **inferred** — I confirmed
the basis: `find /home/analog/dev -maxdepth 6 -name numbers.sh` → nothing.

---

## 3. Fixes

### 1. The printed check cannot see a reserved band — false green on the band this batch just reserved (MEASURED)

```
$ n=1550; ls ~/dev/*/doc/claude/issues/$n-* 2>/dev/null
$ /usr/bin/grep -lE "(^|[^0-9])$n([^0-9]|\$)" ~/dev/*/doc/claude/issues/NUMBERING.md; echo rc=$?
rc=1                      # nothing, in either clone -> reads as "1550 is free"
$ n=0550  (same block)    -> rc=1, same false green
```

Reserved blocks live in `NUMBERING.md` as **ranges** — `| **1500–1599** | the op-wcard
branch | after **1499**, the next number is **1600** |` — and no per-number grep can
match a range. The old paragraph's answer to this was the clause N4 deleted: *"it
carries the next free number, **the reserved blocks that must be skipped**, and why."*
The new paragraph replaces it with a headline that pushes the reader **away** from the
only artifact that carries them ("blind to what is free") and a check that cannot see
them. `1500–1599` is saved by being named in prose two sentences later; `0700–0799`
and `1000–1199` are now named nowhere in `CLAUDE.md` at all.
**Fix:** one clause before the block — the candidate comes from `NUMBERING.md`'s tail
and its reserved-block table at the head (a band is a range and the grep below cannot
see it); the grep only proves nobody in another clone has taken the number you landed
on.

### 2. Nothing says where `n` comes from

The block's only guidance is `# the number you mean to mint`. The sentence that used
to supply it ("Read its tail before filing") was removed as one of the two broken
halves — but only its *authority* was broken, not its *usefulness*. Same one-clause
fix as 1.

### 3. The command's scope limit is in the receipt, not in `CLAUDE.md`

`~/dev/*` is complete **today** and I re-measured that: `find /home/analog -maxdepth 6
-type d -name issues -path '*doc/claude*'` → exactly the two clones, both under
`/home/analog/dev`. But `/usr/bin/git worktree list` already shows a checkout outside
it (`…/scratchpad/wt2`, prunable), and if the glob ever matches nothing, `grep` prints
`No such file or directory` on **stderr** and exits 2 — which, on a silent stdout,
reads exactly like "free". The receipt flags this limit honestly and then leaves it
out of the file a future session will read. **Fix:** name the limit in one clause.

### 4. Trap-proof the pattern instead of only warning about it (MEASURED, and it works)

The ugrep failure is specifically **an anchor inside an alternation**, not numbers:

```
bare grep -cE '(^|[^0-9])1338([^0-9]|$)' NUMBERING.md -> 0     <- the trap
bare grep -cE '[^0-9]1338[^0-9]'         NUMBERING.md -> 5
bare grep -cw 1338                       NUMBERING.md -> 5     <- agrees with /usr/bin/grep
/usr/bin/grep -cw 1338                   NUMBERING.md -> 5
```

`-lw` gives the **same answer under both greps** on the live data — `grep -lw 1349
~/dev/*/…/NUMBERING.md` and `/usr/bin/grep -lw 1349 …` both return both clones;
`-lw 1401` both return this clone only. Over 121 probes `n=1300..1420` against both
`NUMBERING.md` files, the ERE and `-w` **decision** (which files match) is identical
**121/121**; only raw counts differ, on 9 numbers, because `-w` won't match
`test_hier_pdf_links_1333` (underscore is a word character) — which is if anything the
behaviour you want for a taken/free question.
**Fix:** print `/usr/bin/grep -lw "$n" ~/dev/*/doc/claude/issues/NUMBERING.md`, keep
the `/usr/bin/grep` advice and keep the 1349 anecdote as the *reason*. A rule that is
only correct if the reader remembers a caveat is the same failure class this item
exists to fix.

### 5. The ledger paragraph is true of the ledger of the future, not the one standing today (MEASURED)

`/usr/bin/grep -rl '^repo:' ~/.claude/xschem_owed | wc -l` → **0 of 192**. And an
unstamped entry is still destructible across clones — measured in the fixture:

```
cloneB clear rule 1339   (entry has no repo: line)
  -> !! owed WARNING: rule '1339' predates origin stamps -- clearing it,
        but no clone is recorded on it
  -> owed: cleared rule debt 1339          rc=0     <- gone
```

All three live collided ids are in exactly that state: `rule/1337`, `rule/1339`,
`rule/1344` carry no `repo:`, and `rule/1339`'s `ref:` resolves **only** in op-wcard
(`doc/claude/issues/1339-pdf-link-hotspot-tracks-name.md` — absent here, present
there) while this tree's `1339_R3_copy_says_what_it_did` sits beside it. The paragraph's
"a legacy one is claimed the first time it is touched" is defensible but is read as
reassurance; the hazard the batch exists to close is **open on every entry standing
today**. **Fix:** one clause — until an entry is stamped, a foreign `clear` still
succeeds with a warning, and today every entry is unstamped.

### 6. `cleared.log` is unmentioned

The paragraph's sharpest line is "**and nothing said so**". The thing that now says so
— an append-only pre-image log on every clear *and* every overwrite, which I watched
capture the full 4-line entry in the fixture — is the one fact a future session needs
when a ruling has vanished. One clause.

### 7. A carried-verbatim sentence is wrong in this clone, inside the file N4 owns

> "…and it also told you to file at "≥ 0500" when NUMBERING.md reserves **0500–0599**
> for another branch."

`NUMBERING.md`'s table, both at `HEAD` and after N1, reads `| **0500–0599** | **the
fluid-editing branch** |` — this branch — and `ls doc/claude/issues/ | /usr/bin/grep
-cE '^05[0-9]{2}-'` → **21** files here (21 there too). The receipt's §7 calls this
"not mine to fix"; ownership says otherwise — N1 owns `NUMBERING.md`, N4 owns
`CLAUDE.md`, and the sentence that is wrong is `CLAUDE.md`'s. Low risk, but this item
is *the rule that produced the defect*, and a filer told to skip a band that is his
own is the same class of blind instruction.

### 8. Receipt §5's justification for declining N2's request is off by an order

> "The prose paragraph names `--repo <clone|here>` on both commands, **three lines
> below the block**."

Measured: the usage block ends at `CLAUDE.md:246`; `--repo` first appears at `:267` —
**21 lines and one intervening paragraph** later. The decision to keep `--repo` out of
the usage block may still be right (the block genuinely never listed `clear`), but it
was justified by a proximity that does not exist. Re-decide with the real distance —
a reader scanning the block for syntax gets no hint the flag exists.

### 9. Receipt §4 attributes the brief's `6` to the wrong file

```
/usr/bin/grep -cE '(^|[^0-9])1338([^0-9]|$)':
  git show HEAD:doc/claude/issues/NUMBERING.md   -> 2
  worktree doc/claude/issues/NUMBERING.md        -> 5
  op-wcard's doc/claude/issues/NUMBERING.md      -> 6      <- the brief's number
```

So N1's edits took this clone's count 2 → 5; the brief's 6 is op-wcard's file, not a
pre-N1 state of this one. The receipt's *number* (5) is right and the figure `CLAUDE.md`
actually prints (the `n=1349` `-l` example) is unaffected — only the explanation is
wrong. Worth correcting so nobody re-derives it a fourth time.

### 10. The collision figure moved again, ten minutes after the receipt was written

```
$ per-number basename compare, both clones, all numbers
  -> 12 numbers whose slug differs:
     1338 1339 1344 1345 1346 1347 1348 1349 1350 1351 1352 1353
$ stat …/xschem-op-wcard/doc/claude/issues/135*.md
  1350 10:19:19   1351 10:19:47   1352 10:19:47   1353 10:24:27
```

`CLAUDE.md` was written at **10:14:55**. Four of the "50 more numbers this branch has
already committed" were consumed by the other clone inside the next ten minutes. The
prose is date-stamped and stays true, but the driver should either re-take the figure
at commit time or phrase it so it cannot rot — e.g. *"the whole of 1350–1399 is queued
behind that tail; four of them were taken while this paragraph was being written."*
This is the batch's own thesis arriving as evidence, not a defect in N4.

---

## 4. Cross-item, confirmed

* **N4's flag on N1 is real.** `doc/claude/issues/NUMBERING.md:3016-17` reads "two
  clones here held **seven numbers naming two defects each**, with the whole of
  `1349–1399` — **51 more** — queued", against its own `:2994-98` ("**eight** before
  the day was out … **50 collisions are still queued**"). Both are N1's. As of now
  both are stale again (12 and 46-of-50 remaining).
* Untracked and not this batch's, but it will propagate the retired rule:
  `doc/claude/ase_analyses_batch/evidence/ase-conventions.md:47` quotes the superseded
  text verbatim as a live convention — *"`NUMBERING.md` is the ONLY authority. Read
  its *tail*."* — and `:153` repeats "Grep the issues directory before minting". That
  batch is from 2026-09-09; whoever runs it will re-derive the broken rule.

## 5. One objection I formed and then killed by measuring

I expected `CLAUDE.md:41`'s older instruction — `grep -c <newfile> src/Makefile`, a
bare `grep` with a single-alternative pattern on a **gitignored** file — to be a
second live instance of the trap the new paragraph warns about. It is not:
`grep -c break.awk src/Makefile` → **2**, identical to `/usr/bin/grep`. `--ignore-files`
does not suppress an explicitly named path, and the trap is the alternation anchor
(fix 4), not the pattern's arity. No action.

## 6. Method notes

Every count above was taken with `/usr/bin/grep`; the two places a bare `grep` appears
are deliberate A/B comparisons and are labelled. `owed.sh` was exercised only against
`XSCHEM_OWED_DIR=<scratch>/adv/state` inside two throwaway `git init` clones under the
session scratchpad; the real ledger was read with `ls`, `cat`, `find` and `grep -rl`
only. `/home/analog/dev/xschem-op-wcard` was read only. The binary was never launched.
No `git checkout/restore/stash/clean/commit/push`. This adversary wrote exactly one
file, this one, and did **not** append a `LEDGER.md` row (read-only mandate).
