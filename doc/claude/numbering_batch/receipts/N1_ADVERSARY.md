# N1 — adversary

**SOUND WITH FIXES**

The deliverables exist, the RED baseline reproduces bit-for-bit, the absorption map is
arithmetically correct when re-derived independently, and every boundary rule (D-1, the
shared ledger, file ownership) was obeyed. What did not survive is a set of counts in
**tracked, published text** — one of them stated three different ways inside a single issue
file — plus one check that cannot fail, one merge-survival property nobody measured, and
two live hazards nobody looked for. Nothing here refutes the item's thesis; several things
make it stronger.

All counts below were taken with `/usr/bin/grep`. Commands are given inline.
`cwd = /home/analog/dev/xschem-claude` unless stated.

---

## Part 1 — what survived re-measurement (do not re-check these)

| claim | my command | result |
|---|---|---|
| RED baseline `c8b76d8565c2d480`, 2953 lines | `git show HEAD:doc/claude/issues/NUMBERING.md \| sha256sum` / `\| wc -l` | `c8b76d8565c2d480…`, **2953** — exact |
| all six RED counts were 0 (and `Three…` was 1) | six `/usr/bin/grep -cE` on the HEAD blob | `1500`→0, `Three`→1, `Four`→0, `1333.*1500`→0, `PER-CLONE`→0, `1401`→0 — exact |
| six GREEN checks | the receipt's own six commands, verbatim | **1 / 1,0 / 1 / 4 / 1 / 1,1** — all reproduce |
| whole-file `1500` mentions = 7 | `/usr/bin/grep -cE '(^\|[^0-9])1500([^0-9]\|$)' …/NUMBERING.md` | **7** |
| next-free lines = 2 (1401 live + historical 1244) | `/usr/bin/grep -nE '^\*\*The next free number is' …` | `:845` (1244), `:3012` (1401) |
| map: 16 pairs, all `+167`, both bands complete, no aliasing | `/usr/bin/grep -oE '13[0-9]{2} → 15[0-9]{2}'` piped to awk | **16 pairs, bad_offset=[], sources 1333–1348 complete, targets 1500–1515 complete, 0 duplicate sources, 0 duplicate targets** |
| `1500–1599` is free | `ls …/issues/ \| /usr/bin/grep -cE '^15[0-9]{2}-'` in both clones | **0** here, **0** in op-wcard; and `15xx` appears in `NUMBERING.md` only on N1's own 7 lines |
| `owed.sh:187` is the bare `>` (PLAN said `:188`) | `/usr/bin/grep -n "printf '%s\\t%s\\t%s\\n'"` on `git show HEAD:tests/headless/owed.sh` | **187** — PLAN correction upheld. `cmd_clear` spans **288–295** |
| `1349–1399` = 51 tracked, no gaps | `git ls-tree -r --name-only HEAD doc/claude/issues/ \| /usr/bin/grep -cE 'issues/13(49\|[5-9][0-9])-'`, plus a `seq` loop asserting exactly 1 per number | **51**, zero gaps, zero duplicates |
| 35 loaded barrels | `ls ~/.claude/xschem_owed/rule/ \| /usr/bin/grep -xE '13(49\|[5-9][0-9])' \| wc -l` | **35** |
| op-wcard NUMBERING bullets 1333–1348 | `/usr/bin/grep -cE '^\* \*\*13(3[3-9]\|4[0-8])\*\*' <op-wcard>/…/NUMBERING.md` | **16** |
| the nine fileless numbers | `ls` loop over `<op-wcard>/…/${n}-*.md` | **1333 1334 1335 1336 1337 1340 1341 1342 1343** — exact |
| 7 filename collisions in 1333–1348 | `comm -12` of the two `ls \| grep -E '^13(3[3-9]\|4[0-8])-'` number lists | **1338 1339 1344 1345 1346 1347 1348** |
| op-wcard 5 band commit subjects | `git -C <op-wcard> log --oneline 28dabfe8..op-wcard \| /usr/bin/grep -cE '13(3[3-9]\|4[0-8])'` | **5** |
| this branch 10, all published | same shape + `git merge-base --is-ancestor <sha> origin/fluid-editing` for each | **10, 10/10 PUBLISHED**; `origin/fluid-editing` ref mtime **2026-09-10 06:55**, i.e. fresh |
| the merge: base + 4 conflicts | fresh `git clone --local --shared` + `fetch wc op-wcard` + `merge --no-commit --no-ff` | base `28dabfe8…`, rc=1, conflicts **exactly** `NUMBERING.md`, `src/ase.tcl`, `src/op_annot.tcl`, `tests/headless/test_op_dump_altshow.tcl` |
| the ledger demonstration | replayed against `git show HEAD:tests/headless/owed.sh` with `XSCHEM_OWED_DIR` in scratch | second `add rule 1344` → **rc=0**, prints **`recorded`**, replaces the reason, **drops `eyes:1`**; foreign `clear rule 1339` → **rc=0**, file removed |
| `rule/1339` is op-wcard's | `cat ~/.claude/xschem_owed/rule/1339` | `ref:doc/claude/issues/1339-pdf-link-hotspot-tracks-name.md` — **does not resolve here**; this tree also carries `1339_R3_copy_says_what_it_did` |
| the 06:54 forensics | `stat -c '%y' ~/.claude/xschem_owed/rule` | `2026-09-10 06:54:10.569645589 -0700` — matches the receipt to the nanosecond |
| the ugrep trap is live | `grep -cE '(^\|[^0-9])1338([^0-9]\|$)'` vs `/usr/bin/grep -cE …` on `NUMBERING.md` | bare **0**, `/usr/bin/grep` **5** |
| "no headings between `:1` and `:1590`" | `git show HEAD:…/NUMBERING.md \| /usr/bin/grep -nE '^#{1,6} '` | `:1` and `:1590` only — the `## The running record` insertion is justified |

## Part 2 — boundary compliance

**D-1 — clean.** `/usr/bin/git -C /home/analog/dev/xschem-op-wcard status --porcelain` shows
`M src/psprint.c`, `M src/save.c`, and untracked `1350`–`1353` issues + `test_ps_valid_1350.tcl`.
Every one is that session's own live PDF/PostScript work: the issue-file mtimes are
**10:19:19 – 10:24:27 today**, after N1 finished, and the subjects match `psprint.c`.
Corroborating: op-wcard's remotes are `origin` **only** (no `claude`/`wc` remote was ever
added there — N1 added it in its scratch clone); its reflog's last five entries are its own
commits and nothing else; `.git/FETCH_HEAD` is dated **2026-09-04**; there is no
`doc/claude/numbering_batch` in that tree. I re-ran the same clone+fetch recipe myself and
op-wcard's `status --porcelain` md5 was byte-identical before and after.

**Shared ledger — clean.** No `cleared.log` in `~/.claude/xschem_owed/` (only `look/`,
`rule/`, `suite/`). `rule/` dir mtime is frozen at **06:54:10.569645589**, i.e. *before*
N1 ran — no rule entry was created or removed by this batch. `suite/` is Sep 9 15:14.
Counts now **rule 132 / look 52 / suite 8** against LEDGER.md's baseline 132/51/8; the one
new file is `look/hier_pdf_links_1338_H4.1789056750.1637118` at **09:12:30**, an op-wcard
name written by the live op-wcard session, exactly as LEDGER.md warned. **Not this batch.**

**File ownership — clean.** `/usr/bin/git status --porcelain` shows five modified files:
`CLAUDE.md` (N4), `doc/claude/issues/NUMBERING.md` (N1), `doc/claude/specs/owed.md` +
`tests/headless/owed.sh` (N2), `tests/headless/test_owed.sh` (N3). N1 touched nothing
outside its two files. `git diff --stat` on `NUMBERING.md` is **+69/-2**, as claimed.

**`~/.xschem/` — unattributed, stated rather than cleared.** Files under it moved during
the item window: `geometry` 09:51, `simulations` 09:42, `op_annot` 09:42, `.clipboard.sch`
09:39. These are xschem-runtime artefacts. **LEDGER.md records no `~/.xschem/` baseline**,
so there is nothing to compare against, and I cannot attribute the writes to any item —
the user's own session or another batch would produce them identically. N1 declares the
binary was not launched; nothing I measured refutes that and nothing confirms it. *(Gap in
the batch's instrumentation, not a finding against N1.)*

---

## Part 3 — findings

### F1 — HIGH. "sixteen colliding issue files land as clean adds" is **eight**, and issue 1400 states the same measurement three different ways

The merge adds op-wcard's files; this branch's are already in the target and are not adds.

```
$ git -C <scratch clone> diff --cached --name-only --diff-filter=A -- doc/claude/issues/ \
    | /usr/bin/grep -cE '/13[0-9]{2}-'
8
```

Eight `A` lines, one per op-wcard file (1338 1339 1344 1345 1346 1347 1348 1349) — the same
eight the receipt itself prints. But:

* `doc/claude/issues/1400-…md:141` (the twice-measured table): *"colliding files taken as
  clean adds … **16** (8 pairs)"*
* `doc/claude/issues/1400-…md:278` (option (c)): *"measured above as **six clean adds** and
  no conflict"*
* `doc/claude/issues/NUMBERING.md:3000`: *"takes **all sixteen** colliding issue files as
  clean adds — not one of them conflicts"*

Six, eight and sixteen for one number, two of them in the same file 137 lines apart, and
the "16" is now published in `NUMBERING.md`. PLAN's "14" was a pairs-doubled figure and the
receipt corrected it to 16 by doubling again; the merge's own answer is 8. The **`six`** at
`:278` is simply wrong under every reading.

**Fix:** state it once, unambiguously — *the merge takes **8** files as clean adds, **0** of
them conflict, and the merged tree then holds **16** files carrying **8** duplicated
numbers.* Correct `1400:141`, `1400:278`, `NUMBERING.md:3000`.

### F2 — HIGH. Another batch in **this same clone** had already claimed 1400, and still instructs `owed.sh add rule 1400`

```
$ /usr/bin/grep -rn 'add rule 1400' .
doc/claude/ase_analyses_batch/PLAN.md:2536:re-read it at the moment of minting), then `owed.sh add rule 1400`.
doc/claude/numbering_batch/receipts/N1.md:177:  … `owed.sh add rule 1400 …` writes the real shared ledger,
```

`doc/claude/ase_analyses_batch/PLAN.md:2535` — *"File them as one batch under issue **1400**"*
— plus `:31`, `README.md:149`, `CREW_BRIEF.md:118`, `LEDGER.md:149`, and
`evidence/ase-conventions.md:129,148`. That batch's own ledger, `:152`, says in as many
words: *"two batches minting 1400 simultaneously is a merge nobody wants."* Newest file in
it: 2026-09-09 23:41 — a day old, untracked, live.

N1 minted 1400 and moved the tail to 1401 without grepping for an in-clone claimant, and
left nine references pointing at 1400 as free. **This is the batch's own defect happening
inside one clone**, where N2's origin stamping gives *zero* protection — both sides share
an origin, so whichever runs `owed.sh add rule 1400` second silently truncates the first
via the bare `>` at `owed.sh:187`. The one debt N1 asks the driver to record is the debt
most likely to be destroyed.

Mitigating: the ase batch's own docs say *"re-read it at the moment of minting"*, so it is
built to notice. It is still not N1's to edit, so this is a **driver/cross-item action**.

**Fix:** (a) the driver, when adding the rule debt, must not use the bare id `1400` — use
a suffixed id, or `--repo here`, and check `~/.claude/xschem_owed/rule/1400` first;
(b) someone who owns `doc/claude/ase_analyses_batch/` must repoint it at the current tail;
(c) N1's receipt and issue 1400 should record that the collision reproduced *within one
clone*, which is a strictly stronger statement than the issue currently makes.

### F3 — MEDIUM. The tail annotation is falsified by its own file, and by the clock

`NUMBERING.md:3016-17`: *"two clones here held **seven numbers naming two defects each**,
with the whole of `1349–1399` — **51 more** — queued behind them."*

Three errors in two lines, against `:2992`, `:2993` and `:2997` of the same file:

1. **sixteen** numbers name two defects each; *seven* is the count that name two different
   **files**.
2. the queue is **50**, not 51 — op-wcard filed `1349` at 09:12 (`:2994` says so).
3. Both are now stale again. Measured just now:

```
$ for n in $(seq 1333 1399); do  # both trees, filename differs
    ... done | wc -l
12          # 1338 1339 1344 1345 1346 1347 1348 1349 1350 1351 1352 1353
$ tail -n 1 /home/analog/dev/xschem-op-wcard/doc/claude/issues/NUMBERING.md
**The next free number is 1354.**
```

**12** live filename collisions and op-wcard's pointer at **1354** — it consumed five of
this branch's committed numbers between 09:12 and 10:24 today. N4 flagged the 7/51 pair;
neither item caught the *"seven numbers naming two defects"* conflation, which is the
sentence a reader will quote.

**Fix:** `NUMBERING.md:3016-17` → *sixteen numbers naming two defects each, twelve of them
naming two different files as of 2026-09-10 10:30, with the rest of `1349–1399` queued
behind a pointer now at `1354`.* Date-stamp it; the issue already concedes every count is
a snapshot.

### F4 — MEDIUM. "three live collided bare rule ids" is **six**, and three of the 35 barrels went live during the item

```
$ for n in 1337 1338 1339 1344 1345 1346 1347 1348 1349 1350 1351 1352 1353; do
    [ -e "$HOME/.claude/xschem_owed/rule/$n" ] && echo "PRESENT rule/$n"; done
PRESENT rule/1337   PRESENT rule/1339   PRESENT rule/1344
PRESENT rule/1351   PRESENT rule/1352   PRESENT rule/1353
```

`rule/1351`, `rule/1352`, `rule/1353` are **this branch's** standing, unanswered rulings
(`1352` is the `input_line` `eval`-injection one, explicitly flagged as *"on the branch you
share"*), all three with `ref:` paths that resolve here. op-wcard filed issue **files**
`1351`, `1352`, `1353` at **10:19:47 – 10:24:27 today**. Three of the "35 loaded barrels"
acquired a live counterpart inside 90 minutes of the item finishing.

And they are **not protected by the shipped fix**. Measured, `XSCHEM_OWED_DIR` in scratch,
a fixture entry byte-shaped like the real `rule/1351`:

```
$ cd /home/analog/dev/xschem-op-wcard && bash …/xschem-claude/tests/headless/owed.sh \
      add rule 1351 "op-wcard font-attribute ruling"
!! owed WARNING: rule '1351' predates origin stamps -- claiming it for xschem-claude
owed: updated rule debt: 1351
rc=0
# reason REPLACED; stamped repo:/home/analog/dev/xschem-claude
```

Two things: the unattributed path proceeds and **overwrites the standing reason at rc=0**
(by N2's design, for the 191 legacy entries), and `_origin()` resolved to **xschem-claude
while cwd was op-wcard** — it follows the script, not the tree. In practice op-wcard runs
its *own*, unfixed copy, which truncates silently; either way the barrel fires.

**Fix:** N1's issue 1400 should say **six**, name 1351/1352/1353, and state plainly that
N2's refusal does **not** cover an unattributed legacy entry — so the 35 barrels stay live
until they are stamped. *(The `_origin()`-follows-the-script behaviour is N2's file; raised
here because it changes what issue 1400 may claim.)*

### F5 — MEDIUM. Part B check #4 cannot fail on 12 of the 16 pairs

```
$ /usr/bin/grep -cE '^133[3-6] → 150[0-3]' doc/claude/issues/NUMBERING.md
4
```

The map is four columns wide; that pattern is anchored at `^` and therefore only ever sees
the **leftmost** column. A typo anywhere in the other twelve pairs — `1341 → 1519`, a
duplicated target, a transposed source — leaves this check green at 4. The receipt's real
verification is a `python3` line quoted as **output only**, with no runnable command, so a
reader cannot re-run the check that actually covers the map.

I re-derived it independently and **the map is correct** (16/16, `+167`, both bands
complete, no duplicates). The defect is the check, not the map.

**Fix:** replace check #4 with something that can go red, e.g.

```sh
/usr/bin/grep -oE '13[0-9]{2} → 15[0-9]{2}' doc/claude/issues/NUMBERING.md \
 | awk -F' → ' '{n++; if ($2-$1!=167) bad++; s[$1]++; t[$2]++}
   END{printf "pairs=%d bad=%d uniq_src=%d uniq_dst=%d\n", n, bad+0, length(s), length(t)}'
# expect: pairs=16 bad=0 uniq_src=16 uniq_dst=16
```

### F6 — MEDIUM. Under the merge D-2 predicts, the head of N1's work survives and the tail does not

Nobody measured what happens to N1's own edits in the conflict it documents. I did:
scratch clone, N1's working-tree `NUMBERING.md` + the 1400 file committed on top, then
`merge --no-commit --no-ff wc/op-wcard`.

```
conflict markers in NUMBERING.md:  <<<<<<< 1602    ======= 3022    >>>>>>> 3314
Four blocks are reserved      line 3      SAFE (above hunk)
| **1500–1599** row            line 12     SAFE (above hunk)
… 1498  1499  1600  1601 …    line 18     SAFE (above hunk)
the absorption map            line 35     SAFE (above hunk)
## The running record          line 53     SAFE (above hunk)
the 1400 bullet                line 2990   INSIDE CONFLICT HUNK
**next free number is 1401**   line 3013   INSIDE CONFLICT HUNK
PER-CLONE warning              line 3015   INSIDE CONFLICT HUNK
```

One giant hunk, 1602–3314. **N1's placement decision pays off**: the reservation row and
the whole map sit above the hunk and survive any resolution automatically. But the
incoming side of that hunk ends `**The next free number is 1350.**`, so a resolver who
takes theirs — the normal move for the tail of a running log — gets a file that reserves
`1500–1599` at the head and points at **1350** at the tail, a number this branch has
committed. That is a state worse than either input, produced by the ordinary resolution.

**Fix:** mirror one sentence of the PER-CLONE caution into the head section (above 1602),
e.g. after the reserved table: *"⚠ The `next free number` pointer at the tail of this file
is PER-CLONE. On a merge, prefer the HIGHER of the two tails and check both clones."*
Cheap, and it is the only part of the warning that can survive the conflict.

### F7 — LOW. "32 commit subjects name something in 1333–1399" is **31**

```
$ git log --oneline 28dabfe8..fluid-editing | /usr/bin/grep -cE '13[3-9][0-9]'
32
$ git log --oneline 28dabfe8..fluid-editing \
    | /usr/bin/grep -cE '(^|[^0-9])13(3[3-9]|4[0-9]|[5-9][0-9])([^0-9]|$)'
31
```

The 32nd is `a1e85d3c fix(1332): a $DISPLAY run of the keys suite is a measurement again` —
**1332 is outside the band**. `13[3-9][0-9]` spans 1330–1399, not 1333–1399. `1400:271`
prices option (b) on this figure.

### F8 — LOW. op-wcard committed `24e09c65` at **09:44:06**, not 09:52

```
$ git -C /home/analog/dev/xschem-op-wcard log -1 --format='%cI' 24e09c65
2026-09-10T09:44:06-07:00
$ git -C … reflog -1  ->  HEAD@{2026-09-10 09:44:06 -0700}: commit: feat(1338): …
```

Stated as 09:52 in `receipts/N1.md` and twice in issue 1400 (`:145`, `:150`). Eight minutes,
in a document that elsewhere agrees "to the second". Also `git log -1 -- <the 1348/1349
files>` confirms both became tracked in that same 09:44:06 commit.

### F9 — LOW. The strikethrough precedent citations are wrong, in the receipt that warns about exactly this

The receipt cites `~~…~~ superseded` "as at `:61`, `:217`, `:845`". In the **current** file
those lines are ordinary prose (they shifted `+36` to `:97` and `:253` under N1's own head
insertion). `:845` was never a strikethrough in **either** revision — at HEAD it is
`1233 (the five scripted walks…`, and in the current file `:845` is the live
`**The next free number is 1244.**` pointer the receipt separately counts. The real third
instance is `:841`.

```
$ /usr/bin/grep -n '~~' doc/claude/issues/NUMBERING.md
66: 97: 253: 841: 1003: 1007: 1041: 3010:
```

The **substance is correct** — the convention exists and N1 followed it at `:3010`. Only
the citations are unreliable, and finding #5 of the receipt's own "Where the plan is wrong"
is the rule these three break.

### F10 — LOW. Issue 1400 is **313** lines; LEDGER.md's N1 row says 296

`wc -l < doc/claude/issues/1400-*.md` → **313**.

### F11 — LOW. The quoted evidence for "op-wcard has no remote branch" cannot prove it

`1400:258-260` cites `git branch -r | /usr/bin/grep wcard` → nothing, of 19 — run **in
xschem-claude**, whose `.git/FETCH_HEAD` is dated **2026-09-04**. A six-day-stale remote
list cannot show a branch pushed since. **The conclusion is correct**, but the proving
commands are op-wcard-side and should be the ones quoted:

```
$ git -C /home/analog/dev/xschem-op-wcard rev-parse --abbrev-ref op-wcard@{upstream}
fatal: no upstream configured for branch 'op-wcard'
$ for s in 24e09c65 e451892b 7f8d72a8 743c81d2 18e8e179; do
      git -C … branch -r --contains $s; done      # empty for all five
$ git -C … branch -vv   ->  * op-wcard 24e09c65   (no [origin/…] marker)
```

*(Caveat, labelled: op-wcard's own remote refs are also from 2026-09-04. Absent a
`git ls-remote`, "unpublished" rests on the missing upstream config and the missing
tracking marker, which are local facts and do not decay.)*

### F12 — LOW. The filing-sequence block still omits the `0999 → 1200` skip

N1 was the last hand in that code block and added the `1499 → 1600` line to it:

```
… 0498  0499  0600  0601 …  0698  0699  0800  0801 …
… 1498  1499  1600  1601 …
```

The `1000–1199` reservation sits in the table at `:11` with rule *"after 0999, the next
number is 1200"*, and the sequence block a few lines below never shows it. Pre-existing,
one line to fix while the file is open.

---

## Fix list

1. **F1** — one statement of the merge result: **8 files added, 0 conflicts, 16 files / 8
   duplicated numbers in the merged tree.** Correct `1400:141`, `1400:278` ("six clean
   adds"), `NUMBERING.md:3000` ("all sixteen … as clean adds").
2. **F2** — record the in-clone contention on 1400 with `doc/claude/ase_analyses_batch/`
   (its `PLAN.md:2535-36` still says file under 1400 and run `owed.sh add rule 1400`).
   Driver: do **not** record the debt under the bare id `1400`. The owner of that batch
   must repoint it. Say in 1400 that the collision reproduced inside one clone, where
   origin stamping cannot help.
3. **F3** — `NUMBERING.md:3016-17`: *sixteen* numbers naming two defects, **12** naming two
   files, pointer now at **1354**, date-stamped.
4. **F4** — issue 1400: **six** live collided bare rule ids (add 1351, 1352, 1353), and
   state that N2's refusal does not cover an unattributed legacy entry.
5. **F5** — replace Part B check #4 with the awk one-liner above, which can go red.
6. **F6** — mirror one PER-CLONE sentence into the head section, above the merge hunk.
7. **F7** — `1400:271`: **31**, not 32 (`13[3-9][0-9]` catches `fix(1332)`).
8. **F8** — `24e09c65` is **09:44:06**; correct the receipt and `1400:145,150`.
9. **F9** — strikethrough precedent is `:66 :97 :253 :841 …`, not `:61 :217 :845`; better,
   quote the `grep` instead of line numbers, per the receipt's own finding #5.
10. **F10** — LEDGER N1 row: **313** lines, not 296.
11. **F11** — quote the op-wcard-side upstream/`--contains` commands as the evidence for
    "unpublished".
12. **F12** — add `… 0998  0999  1200  1201 …` to the filing-sequence block.

None of 1–12 requires renumbering anything, and none touches op-wcard.

## Method

Read-only on the repo; the only file I wrote is this one. Scratch dir
`/tmp/claude-1000/…/1e23e38a-…/scratchpad`: a throwaway merge clone
(`git clone --local --no-hardlinks --shared` of xschem-claude, `git fetch` of op-wcard,
`merge --no-commit`, `merge --abort`, then `rm -rf`) and two fake ledgers under
`XSCHEM_OWED_DIR`. The real ledger was read, never written — verified after the fact by
`rule/` still carrying mtime `06:54:10.569645589`. op-wcard was read; its
`status --porcelain` md5 was identical before and after everything I ran. The binary was
not launched. No `git checkout/restore/stash/clean/commit/push`. Every count above came
from `/usr/bin/grep`; the bare `grep` function was invoked exactly once, deliberately, to
confirm the ugrep trap is still live (`1338` → 0 against `/usr/bin/grep`'s 5).
