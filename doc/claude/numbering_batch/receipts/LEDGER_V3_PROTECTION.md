# V3 — PROTECTION. Does any of this actually protect anything?

**SOUND WITH FIXES**

The driver's three writes are sound and I could not break any of them. The
backfill is strictly append-only over all 194 pre-existing entries (0
violations, measured file by file), the recovered ruling is byte-faithful to the
09:20 backup, and `rule/1400` reads back, resolves, and is stamped correctly.
The refusal is **armed and it works** — an exhaustive sweep of all 196 entries
from this clone partitions them exactly 182 clear / 14 refuse, with zero
misfires on the rightful owner.

**And it protects almost nothing that matters, because it is one-sided.** The
clone that destroyed `rule/1351` at 10:46:14 runs its own copy of `owed.sh`,
dated 2026-09-04, which has never heard of `repo:`. I ran that script against
the fully-stamped ledger. It overwrote a stamped entry, exit 0, printed
`recorded`, destroyed the stamp along with the ruling, and wrote no
`cleared.log`. It also cleared the *recovered* `1351@xschem-claude` and the
brand-new `rule/1400`, both at exit 0. **The 10:46:14 defect is still live and
the backfill did not close it.** Section 2 has the outputs, section 6 has the
exhaustive residual list, and the one thing that would make this mutual is named
in 6.1 — it needs a user ruling, because D-1 forbids the tree that has to move.

Three fixes are also owed on this clone's own script, in section 6.4–6.6; one of
them (`clear` accepts `../`) lets a typo delete the pre-image log the whole fix
rests on, and `test_owed.sh` has no row for it.

---

## 0. Method, and what I did not touch

* **The live ledger is read-only to me and stayed that way.** Every exercise ran
  against a `cp -a` fixture with `XSCHEM_OWED_DIR` pointed at the copy. Proof:
  `diff -rq /home/analog/.claude/xschem_owed <my 12:26 copy>` → **IDENTICAL**;
  the state-dir root mtime is still `2026-09-02 03:12:39`, there is no
  `cleared.log` in it and no `.rewrite.*` temp. The kind-dir mtimes
  (`rule` 12:18:51, `look`/`suite` 10:46:33) all predate my first snapshot.
* `/home/analog/dev/xschem-op-wcard` was **read only**. Its `owed.sh` was
  `cp -a`'d to my scratch dir and run from there; the original is untouched
  (md5 `cc88328d6c788c83571435dce7b56a05`, mtime `2026-09-04 06:55:36`, both
  unchanged).
* No git write commands, nothing under `~/.xschem/`, and **the xschem binary was
  never launched** — including in section 6.2, where I read `cmd_drain` rather
  than running the arm that would exec a suite.
* Every count below names the command that produced it, and every one uses
  `/usr/bin/grep`.

### Snapshots — the ledger did not move under me

| | T0 = **12:20:36 -0700** | T1 = **12:28:11 -0700** |
|---|---|---|
| `rule` (`ls -1 …/rule \| wc -l`) | 134 | 134 |
| `look` | 53 | 53 |
| `suite` | 9 | 9 |
| total (`find … -type f \| wc -l`) | 196 | 196 |
| stamped (`/usr/bin/grep -rl '^repo:' … \| wc -l`) | 196 | 196 |
| `repo:/home/analog/dev/xschem-claude` | 182 | 182 |
| `repo:/home/analog/dev/xschem-op-wcard` | 14 | 14 |

Distribution taken with
`/usr/bin/grep -rh '^repo:' /home/analog/.claude/xschem_owed | sort | uniq -c`.
**Nothing moved in that 8-minute window** — but the op-wcard session simply
happened to be quiet; this is a snapshot, not a standing fact. `repo_via:` splits
**195 `told` / 1 `git`**, the `git` one being `rule/1400`.

### The backfill itself, verified rather than assumed

`diff -rq` of the 12:18 pre-backfill backup against the live ledger: **194
entries in the backup, 196 live**, the two extra being `rule/1351@xschem-claude`
and `rule/1400`. For each of the 194 I diffed the pair and required that no line
was removed or changed and that every added line matched `^repo(_via)?:`:

```
compared 194 pre-existing entries; violations: 0
```

**The backfill is append-only, as D-4 requires.** Line 1 of every entry is
intact.

**Attribution corroborated independently.** For every entry carrying a `ref:`, I
tested whether the referenced file exists in the clone the entry was stamped to:

```
entries with ref: 84   ref resolves in stamped clone: 84   dangles: 0
refs resolving in only ONE clone (so the ref discriminates): 45
refs resolving in BOTH clones (consistent, but no evidence):  39
entries with no ref at all: 112
```

So **45 of the 196 stamps are corroborated by a fact independent of the driver's
say-so**, 39 more are consistent, and **112 rest on the driver's assertion alone**
(`repo_via:told`) — 50 rule, 43 look, 7 suite for this clone; 10 look, 2 suite for
op-wcard. That is not a criticism of the backfill, which had nothing better to
work from; it is the honest confidence level, and it is why `repo_via:` was worth
recording.

---

## 1. Is the refusal armed, from this clone? Yes.

Fixture: `cp -a` of the live ledger, `XSCHEM_OWED_DIR` at the copy, script
`/home/analog/dev/xschem-claude/tests/headless/owed.sh`.

### 1a — clearing one of this clone's own entries still works

```
$ owed.sh clear rule 0643
owed: cleared rule debt 0643
EXIT=0
```
The entry is gone and its full pre-image, stamp included, is in `cleared.log`.

### 1b — clearing one of the 14 op-wcard entries is REFUSED

```
$ owed.sh clear rule 1339
!! owed REFUSED: rule 1339 belongs to another clone -- NOT cleared
   its clone: /home/analog/dev/xschem-op-wcard
   standing:  link hotspot: body or body+name
   this clone's own rule debts on that number:
      .../owed.sh clear rule 1339_R3_copy_says_what_it_did
   to clear THEIRS anyway: .../owed.sh clear rule 1339 --repo xschem-op-wcard
EXIT=5
md5 before: e040aee86239b23bf2d02f65ed5017be
md5 after : e040aee86239b23bf2d02f65ed5017be
BYTE-IDENTICAL: YES
```
Note it did the useful thing and named the this-tree candidate on the same
number, which is the whole 1339 collision in one line.

### 1c — `add rule 1339` is REFUSED and nothing is written

```
$ owed.sh add rule 1339 "an intruding ruling that must not land"
!! owed REFUSED: rule 1339 belongs to another clone -- NOTHING written
EXIT=5
BYTE-IDENTICAL: YES
```
`ls …/rule | /usr/bin/grep '^1339'` still returns exactly `1339` and
`1339_R3_copy_says_what_it_did` — nothing was filed beside it either.

### 1d — the exhaustive sweep, which is the real answer to "is it armed"

I ran `clear <kind> <id>` from this clone against **every one of the 196 entries**
in a throwaway fixture:

```
cleared (rc 0): 182    REFUSED (rc 5): 14    other rc: 0
survivors: 14  -- exactly the 10 op-wcard looks, rule/1339, rule/1351,
                  suite/test_hier_pdf_links_1333, suite/test_ps_valid_1350
pre-images recorded in cleared.log: 182
```

**Zero misfires in either direction**: not one of this clone's 182 entries was
refused to its rightful owner, and not one of op-wcard's 14 was destroyed. The
refusal also fires on all three kinds — `look` and `suite` refusals were checked
individually as well, with byte-identical survival.

---

## 2. ⚠ THE DIRECTION THAT MATTERS: the other clone runs the OLD script

**Prediction, written before the run:** the stamp will not stop it. The old
`cmd_add` is a bare `>` with no existence check
(`printf '%s\t%s\t%s\n' … > "$d/$id"`) and the old `cmd_clear` is `rm -f "$d/$id"`
by exact filename. `/usr/bin/grep -c 'repo' /home/analog/dev/xschem-op-wcard/tests/headless/owed.sh`
→ **5**, and all five hits are the words *reporting* / *repo-relative* in
comments. There is no `repo:` field logic anywhere in it.

**The run.** Script copied to my scratch dir under a fake clone layout; fixture
is a `cp -a` of the fully-stamped live ledger.

```
=== BEFORE: rule/1400 ===
1789067931  1400  who renumbers the 1333-1348 band, and when. …
ref:doc/claude/issues/1400-two-clones-filed-the-same-issue-numbers-and-neither-could-see-the-other.md
repo:/home/analog/dev/xschem-claude
repo_via:git
md5: f14176f4be65daa4e3ad25fbd7245794

=== RUN (op-wcard's own owed.sh): add rule 1400 ===
owed: recorded rule debt: 1400
EXIT=0

=== AFTER: rule/1400 ===
1789068144  1400  op-wcard's own 1400 ruling, whatever it is
md5: 4afbd972954eefa593cba86630119ad7

=== cleared.log ===
No such file or directory
```

The ruling is gone, the `ref:` is gone, **the stamp itself is gone**, the word
printed was `recorded` not `updated`, the exit code was 0, and no pre-image
exists. It also clears at will:

```
$ old_owed.sh clear rule 1351@xschem-claude     # the RECOVERED ruling
owed: cleared rule debt 1351@xschem-claude
EXIT=0                                           # file gone

$ old_owed.sh clear rule 1400
owed: cleared rule debt 1400
EXIT=0                                           # file gone
```

### How one-sided this is, plainly

| path | today |
|---|---|
| this clone → its own entries | works, pre-image logged |
| this clone → op-wcard's entries | **REFUSED, exit 5**, byte-identical survival |
| **op-wcard → this clone's entries** | **destroys them, exit 0, no log, stamp erased** |
| op-wcard → its own entries | works |

The backfill armed the half of the door that was never the problem. **Every
protection measured in section 1 is a protection against this session, not
against the session that actually destroyed a ruling.** The stamp on those 182
entries is, from op-wcard's side, four bytes of inert text that its `>`
truncates without reading.

**What would have to happen for it to become mutual.** Exactly one thing: the
repaired `owed.sh` has to exist at
`/home/analog/dev/xschem-op-wcard/tests/headless/owed.sh`. It is a single
self-contained file with no build step and no dependency on anything else in
this batch — `cp` would do it. **D-1 forbids this batch from touching that tree**,
so it is the user's call and nobody else's. Three ways it can be paid, in
increasing cost:

1. **The user copies the one file** into op-wcard (or merges this branch's
   `tests/headless/owed.sh` there). The op-wcard session then refuses in both
   directions from its next invocation. Nothing else in this batch is needed.
2. **The absorption merge (D-2) carries it.** `owed.sh` is not on the conflict
   list, so the merge lands the repaired script in the merged tree — but that
   is *after* the window in which the two trees are still separate and writing,
   which is the window the losses happen in.
3. **Nothing.** Then every entry this clone files is destroyable by the other
   clone at exit 0 for as long as both exist, and section 6.3 says how many
   barrels are loaded.

Until (1) or (2), **the honest description of the current state is: this clone
can no longer destroy the other's rulings; the other can still destroy all of
this clone's, silently, and the ledger will not record that it happened.**

---

## 3. The 10:46:14 scenario, re-run both ways, side by side

Fixture built as identical twins: a `cp -a` of the live stamped ledger with
`rule/1351` restored to this branch's RDW ruling from the 09:20 backup and
stamped `repo:/home/analog/dev/xschem-claude` — i.e. **the world as it stood one
second before 10:46:14, had the backfill already been done.** Both twins md5
`c456d25c3641df41a00313a23988a66b`. Both arms then run the same command,
`add rule 1351 "H5 maps the GENERIC font families to the PostScript base-14 set"`.

| **ARM A — the OLD script (what op-wcard really runs today)** | **ARM B — the NEW script, run from a second clone** |
|---|---|
| `owed: recorded rule debt: 1351` | `!! owed REFUSED: rule 1351 belongs to another clone -- NOTHING written` |
| `EXIT=0` | `EXIT=5` |
| entry now: `1789068205  1351  H5 maps the GENERIC font families…` | entry now: `1788626525  1351  DRIVER DECISION, taken while you were away…` |
| md5 `7c521703f523148dd119e18801c2d8a7` — **changed** | md5 `c456d25c3641df41a00313a23988a66b` — **byte-identical** |
| the RDW ruling: **destroyed** | the RDW ruling: **intact** |
| the `repo:` stamp: **destroyed** | stamp intact |
| `cleared.log`: **absent** | nothing to log — nothing was written |
| — | refusal names the standing text in full, both clones, and prints `--repo here` to file beside it or `--repo xschem-claude` to update theirs |

Arm B also filed nothing beside the entry: `ls …/rule | grep '^1351'` → `1351`
only.

**This is the exact defect that fired, re-fired against the repaired ledger, and
it still fires.** Arm B is what would have happened if the fix had been on both
sides. Arm A is what will happen the next time op-wcard runs `add` on a number
this branch owns.

---

## 4. Does `cleared.log` capture a destroy? Yes — for the new script only.

**A clear** (section 1a, `clear rule 0643`):

```
=== 1789068098	cleared	rule	0643	by /home/analog/dev/xschem-claude
| 1788920888	0643	TWO UI-COPY STRINGS NOBODY RATIFIED -- the two tails of the Netlist-and-Run refusal, raised by crew B as B-1/B-2. …
| ref:doc/claude/issues/0643-netlist-and-run-is-refused-when-the-user-is-descended.md
| repo:/home/analog/dev/xschem-claude
| repo_via:told
```

**An overwrite** (same-clone `add rule 1400` over the standing entry). The word
printed changes from `recorded` to `updated`, and the pre-image goes down first:

```
owed: updated rule debt: 1400

=== 1789068220	overwritten	rule	1400	by /home/analog/dev/xschem-claude
| 1789067931	1400	who renumbers the 1333-1348 band, and when. As of 2026-09-10 11:37 twelve numbers name two different defects across your two checkouts…
| ref:doc/claude/issues/1400-two-clones-filed-the-same-issue-numbers-and-neither-could-see-the-other.md
| repo:/home/analog/dev/xschem-claude
| repo_via:git
```

Full entry, all lines, prefixed `| `, in the state-dir root. In the 196-entry
sweep it recorded **182 of 182** destroys. A `--repo`-forced foreign clear logs
too (section 6.5). This is real and it works.

**Two limits worth naming.** (i) `cleared.log` **does not exist in the live
ledger** (`ls /home/analog/.claude/xschem_owed/cleared.log` → No such file) — it
is created lazily on the first destroy, so right now there is no audit file at
all, and the next destroy may well be an op-wcard one that never creates it.
(ii) The old script writes no pre-image ever, so **every loss caused by the
still-live path in section 2 is unlogged and unrecoverable** except from a
hand-taken `cp -a`, which is what saved `rule/1351` and which nothing automates.

---

## 5. `rule/1400` — the debt the driver filed

Verified four ways.

* **Reads back through `show`:**
  ```
    1400   (a RULING)
        why: who renumbers the 1333-1348 band, and when. As of 2026-09-10 11:37 twelve numbers name two different defects across your two checkouts and the set grows about one an hour; the absorption merge takes every colliding file as a CLEAN ADD, so after it the duplicates are inside one tree. This branch published its numbers, op-wcard did not. Four options with measured costs are in the issue. D-3 in doc/claude/numbering_batch/DECISIONS.md is this batch's recommendation, NOT your answer.
        the options are in: doc/claude/issues/1400-two-clones-filed-the-same-issue-numbers-and-neither-could-see-the-other.md
        waiting 0 day(s)   clear with: .../owed.sh clear rule 1400
  ```
  It reads as a ruling, it points at the option set rather than flattening it,
  and it says in its own text that D-3 is a recommendation and not the answer.
  It is **not** filed under a bare id that collides — `1400` is this branch's own
  next free number and op-wcard's pointer reads 1354, so the id is clean today
  (`tail -5 /home/analog/dev/xschem-op-wcard/doc/claude/issues/NUMBERING.md` →
  *"The next free number is 1354."*).
* **`ref:` resolvable:** `doc/claude/issues/1400-two-clones-filed-the-same-issue-numbers-and-neither-could-see-the-other.md`
  exists in this clone (32669 bytes, mtime 11:37) and **not** in op-wcard —
  which is the correct discriminating signal, and `list` marks it
  `(not in this clone)` when read from the other side.
* **Stamped for the right clone:** `repo:/home/analog/dev/xschem-claude`,
  `repo_via:git`. It is the **only** entry in the ledger with `repo_via:git` —
  every other stamp is `told`, because the backfill asserted them. That is the
  correct and more trustworthy of the two provenances.
* **A clear from a simulated other clone refuses:**
  ```
  $ (second clone) owed.sh clear rule 1400
  !! owed REFUSED: rule 1400 belongs to another clone -- NOT cleared
     its clone: /home/analog/dev/xschem-claude
     this clone owns no rule debt on that number
     to clear THEIRS anyway: … clear rule 1400 --repo xschem-claude
  EXIT=5   SURVIVED BYTE-IDENTICAL: YES
  ```
  …and, immediately afterwards on the same fixture:
  ```
  $ (op-wcard's real script) owed.sh clear rule 1400
  owed: cleared rule debt 1400
  EXIT=0                                    # file gone, no log
  ```
  **`rule/1400` — the ruling this whole batch exists to put in front of the user
  — is destroyable today by the other clone, at exit 0, with no record.**

**Also verified:** the recovered `rule/1351@xschem-claude` is clearable by the
exact id `show` prints for it (`clear rule 1351@xschem-claude` → exit 0), so the
`@` in the namespaced id does not lock the user out of answering it; and `show`
prints **both** 1351 rulings, the foreign one carrying
`filed in another clone: /home/analog/dev/xschem-op-wcard` and
`(not in this clone)` on its ref. The user can tell them apart. `list` marks all
14 foreign entries the same way.

---

## 6. The residual — every remaining way an unanswered ruling dies silently

Ordered by how likely it is to actually happen here. **6.1 is not one item in a
list; it is the whole of the exposure.**

### 6.1 — op-wcard runs the 2026-09-04 script. MEASURED, LIVE, UNCLOSED.
Section 2. `add` truncates any entry regardless of stamp at exit 0 printing
`recorded`; `clear` `rm`s any entry at exit 0; neither writes `cleared.log`;
`drain` (below) has no origin check either. This is the path that fired at
10:46:14 and **the backfill did not narrow it by one byte.** Closing it needs one
`cp` into a tree D-1 forbids this batch to touch. Everything below is small
beside it.

### 6.2 — op-wcard's `drain` runs and clears this clone's suite debts.
`/usr/bin/grep -c 'SKIP' /home/analog/dev/xschem-op-wcard/tests/headless/owed.sh`
→ **0**; its `cmd_drain` ends a passing suite with `rm -f "$d/${ids[$i]}"`. This
clone's repaired drain does skip correctly — measured on a fixture holding only
the two op-wcard suite debts, with no suite executed and no binary launched:
```
== SKIP test_hier_pdf_links_1333 -- another clone's debt (xschem-op-wcard); drain it there
== SKIP test_ps_valid_1350 -- another clone's debt (xschem-op-wcard); drain it there
no suite debts for THIS clone to drain (2 left standing for another clone).
(rule and look debts are untouched by drain, by design)
```
both entries byte-identical afterwards. From op-wcard there is no such skip: it
would resolve this clone's 7 suite names against **its own** `tests/headless`
(N2 measured 6 of 7 files differing in content), run the wrong suite, and clear
this clone's debt on a pass. Not a ruling, but an automated verdict discharging
work it never did.

### 6.3 — the loaded barrels, counted.
op-wcard's next free number is **1354**. Bare 4-digit rule ids in the ledger
stamped to this clone, inside 1354–1399 (counted by iterating
`…/rule/[0-9][0-9][0-9][0-9]` and testing each with
`/usr/bin/grep -q '^repo:/home/analog/dev/xschem-claude$'`):

```
1354 1355 1357 1358 1360 1362 1364 1365 1366 1368 1369 1370 1371 1372 1373 1374
1375 1381 1382 1384 1385 1387 1388 1389 1390 1391 1393 1395 1396 1397 1398 1399
count = 32
```
(67 of the 69 bare 4-digit rule ids in the whole ledger are this clone's.)
**32 unanswered rulings sit directly in the path of the other clone's pointer**,
and 6.1 says the refusal reaches none of them. Section 3's arm A is what each
one gets.

### 6.4 — new entries the old script files are UNATTRIBUTED, and this clone will overwrite them with only a warning.
Measured end to end:
```
$ (old script) add rule 1354 "op-wcard's real, unanswered 1354 ruling"
owed: recorded rule debt: 1354            # written with NO stamp

$ (this clone, new script) add rule 1354 "this clone's unrelated 1354 ruling"
!! owed WARNING: rule '1354' predates origin stamps -- claiming it for xschem-claude
owed: updated rule debt: 1354
EXIT=0                                     # their ruling replaced
```
The pre-image *is* logged and the warning *is* printed, so this is much better
than 10:46:14 — but it is exit 0, not a refusal. **And it does not decay away:
for as long as op-wcard runs the old script, every entry it files arrives
unstamped, so the backfill's coverage is a one-off snapshot that erodes with
every new op-wcard debt.** The "unattributed proceeds" rule is deliberate (R608,
so legacy `clear rule <id>` commands in receipts keep working) and I am not
arguing against it; it just is not protection, and after 6.1 is closed there
will be a moment where it is the widest remaining hole.

### 6.5 — the `--repo` escape does exactly what it says, including the ugly part.
Ratified by the user (N2 F4), so this is not a defect report — but it is a
destroy path and it belongs in the list. `clear rule 1339 --repo xschem-op-wcard`
from this clone: **exit 0, entry gone**, pre-image logged. Two sharper edges
measured on `add`:
```
$ owed.sh add rule 1351 "a foreign overwrite via --repo" --repo xschem-op-wcard
owed: updated rule debt: 1351  (id 1351, clone xschem-op-wcard)
EXIT=0
```
* their `ref:` was **replaced** with this clone's 1351 path
  (`1351-the-poll-guard-…`), so op-wcard's own entry now points at a file
  op-wcard does not have. This is N3's finding F2, deliberately left unpinned in
  N2's file; it is still live.
* their **`eyes:1` tag was silently dropped** — the standing entry had it, the
  updated one does not. Not previously recorded anywhere I can find. A ruling
  that needed the user's eyes quietly stops saying so.

### 6.6 — `clear` accepts `../` and deletes outside the state dir, including `cleared.log` itself. NEW.
`cmd_clear` does not sanitise the id (it must not `_slug` it, or the namespaced
`1351@xschem-claude` would be unreachable — see section 5), and it never checks
that the resolved path stays inside the kind dir:
```
$ owed.sh clear rule ../cleared.log
!! owed WARNING: rule 'cleared.log' predates origin stamps -- clearing it, but no clone is recorded on it
owed: cleared rule debt cleared.log
EXIT=0                                      # the audit log is gone

$ owed.sh clear rule ../../victim.txt
owed: cleared rule debt victim.txt
EXIT=0                                      # an arbitrary file outside the ledger, gone
```
The traversal is **inherited** — the 2026-09-04 script has the same
unsanitised `rm -f "$d/$id"` — so this is not something the repair introduced.
What the repair *did* introduce is a valuable target: the pre-image log now
lives at `$OWED_DIR/cleared.log`, one `../` from every kind dir, and clearing it
destroys the pre-image of the clear along with it. `add` is safe (`_slug` maps
`/` to `_`; `add rule ../../evil` files `.._.._evil` inside `rule/`).
**`test_owed.sh` has no row for this**: `/usr/bin/grep -c '\.\./' tests/headless/test_owed.sh`
→ 4, and all four are comments or `REPO=$(cd "$HERE/../.." && pwd)`. Suggested
fix: reject an id containing `/` in `cmd_clear` (exit 2), which costs nothing —
no legitimate id has ever contained one — plus one O-row.

### 6.7 — nine pre-fix copies of `owed.sh` are sitting in the scratchpad and default to the real ledger.
`OWED_DIR="${XSCHEM_OWED_DIR:-$HOME/.claude/xschem_owed}"`, so any copy run
without the env var writes the **live** ledger. Counted by testing each copy for
`_origin_init`:
```
pre-fix copies under /tmp/claude-1000: 9   post-fix: 68
```
The nine include `pristine/`, `oldtree/`, `redtree/`, `n2fix/mirror_head/`,
`n3fix/head/`, `n3/redtree/`, `fx6/cloneA`, `fx6/cloneB` and my own
`fake_opwcard/`. These are RED-first fixtures left by earlier crews. Each is a
loaded copy of the 10:46:14 weapon, one forgotten `XSCHEM_OWED_DIR` away from
the user's queue. Cheap mitigation, if wanted: have `owed.sh` refuse to run from
a path under `/tmp` unless `XSCHEM_OWED_DIR` is set.

### 6.8 — the stamp is a PATH, so renaming or moving a clone turns 182 rulings foreign at once.
`_origin()` is `git rev-parse --git-common-dir` with `/.git` stripped, falling
back to the checkout root by path. `mv /home/analog/dev/xschem-claude …` and
every one of this clone's 182 entries is refused **to its rightful owner** at
exit 5 until each is re-stamped or reached with `--repo`. Nothing is destroyed —
the failure mode is refusal, which is the safe direction — but the user's queue
would appear to belong to nobody. Linked worktrees are handled correctly (both
the git answer and the path fallback resolve back to the clone), and the two
real checkouts are the only ones on the machine
(`find /home/analog -maxdepth 7 -name owed.sh -path '*tests/headless*'` → exactly
2). This clone does carry one **prunable** worktree registration pointing into a
scratchpad path that no longer exists; harmless, worth pruning some day.

### 6.9 — direct filesystem writes, and concurrency.
Nothing gates a plain `rm ~/.claude/xschem_owed/rule/1400`, an editor writing
the file, or a `cp -a` restore over the top. Two simultaneous `add`s to the same
id both truncate with `>` (not an atomic rename), so a reader can see a
half-written entry; `_rewrite_line1` *does* use a temp-plus-`mv`, but plain `add`
does not. Low probability, unbounded consequence, and outside what a shell
ledger can fix — the real answer is the `numbers.sh` claim registry the PLAN
declares out of scope.

### 6.10 — the `look`-debt digest page prints commands that will now be refused.
`doc/claude/lookdebt_batch/build_page.py:52` emits
`owed.sh clear look <id>` into the user's digest, with no `--repo`. Ten of the
53 look debts are op-wcard's, so those ten rows now print a command that exits 5
from this clone. This is the *safe* direction — a refusal, not a destroy, and
the refusal names the override — but it is a user-facing surface that has not
been told about clones. Not this batch's file; flagged by N2 and still open.
`show` itself is correct here and prints `filed in another clone: …` (that the
plain clear command it prints is then refused is the user's own F4 ruling, not a
defect).

---

## What this work bought, stated honestly

**Bought:** a ledger where the loss of a ruling is *recorded* rather than
reconstructed by luck; a correct, corroborated, append-only attribution of all
196 entries; a refusal that partitions those entries 182/14 with zero misfires;
`drain` that will not run another clone's suite; a destroyed ruling recovered
byte-faithfully; and `rule/1400` finally standing in the user's queue, which the
batch had failed to do.

**Not bought:** any protection at all against the clone that caused the loss.
Every measurement in section 1 describes this session refusing to do something
it was not going to do anyway. The 10:46:14 path is open, `rule/1400` and 32
other unanswered rulings are in front of it, and one `cp` of one file into a
tree this batch may not touch is the whole fix.

*Written 2026-09-10, snapshots at 12:20:36 and 12:28:11 -0700. Fixtures under*
`/tmp/claude-1000/-home-analog-dev-xschem-claude/1e23e38a-228a-491e-a9b0-387bda9d283e/scratchpad/`.
