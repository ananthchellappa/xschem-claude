# Ledger — the cross-checkout numbering collision

Baseline, taken 2026-09-10 before any item ran:

* `tests/headless/test_owed.sh` — the suite N3 extends. Its pre-change verdict
  is recorded by N3 in its receipt; acceptance is **name+status**, never a
  count, and floors are RAISED when rows are added and never lowered.
* `~/.claude/xschem_owed/` — rule 132, look 51, suite 8 at 08:19; look 51 at
  08:25 (a live op-wcard session added `hier_pdf_links_1338_H4` mid-audit).
  **Any count here is a snapshot**; the other session writes this directory.

| item | what | status |
|---|---|---|
| N1 | issue 1400, NUMBERING.md reservation + absorption map | **DONE** — issue 1400 filed (296 lines, option set a-d open for the user); NUMBERING.md +69/-2: `1500–1599` row, Three→Four, filing sequence, `1333–1348`→`1500–1515` map at the head (16 pairs, all +167, verified), tail annotated PER-CLONE, next free **1401**. Renumbered nothing; op-wcard untouched. **Driver must add the `rule` debt on 1400** — crew may not write the real ledger. Three PLAN corrections: `owed.sh:187` not `:188`; the merge takes **16** colliding files as clean adds, not 14 (re-measured at 09:56 after op-wcard committed `24e09c65`); collisions are **8** and queued **50** — op-wcard filed 1349 at 09:12 today. See `receipts/N1.md`. **REPAIRED 2026-09-10 ~11:00 (adversary F1-F12: 12 fixed, 0 disputed as wrong, 2 of them corrected by measurement before being applied).** `NUMBERING.md` now **+91/-2** (2953 -> 3042); issue 1400 was **519** lines at 11:00 (`wc -l < doc/claude/issues/1400-*.md`), not the 296 this row claimed nor the 313 the adversary measured -- **and 519 was already stale when the close-out below was typed at 11:39: the file's mtime was 11:37:54 and it was 536.** It is **792** as of 2026-09-10 12:5x, after the second repair round. **Any line count of that file is an mtime-stamped observation; take it with the command, never from a receipt.** **F1:** "8" and "16" are one measurement in two units — the merge **adds 8 files, conflicts on 0**, and the merged tree holds **16 files carrying 8 duplicated numbers**; stated identically in all three places, and the 09:38 column re-measured against `e451892b` (**6** adds), not re-expressed. **F3:** every count in both files is now date-AND-time stamped and says the set was still growing — **TWELVE** collisions at **10:46 -0700** (1338, 1339, 1344-1353), op-wcard's tail **1354**, `1350`'s file written 10:45:47, one minute before the count. **F4:** **six** live collided bare rule ids, not three, and N2's refusal covers **none** of them — 194 of 194 live entries are unstamped legacy; the driver's backfill pass is what closes it. **F4b, NEW and the defect firing live: `rule/1351` was overwritten IN PLACE at 10:46:14, during this repair pass** — ts field 10:46:14, `rule/` dir mtime frozen at 06:54:10 (a directory mtime cannot see an in-place rewrite), file count 132 unchanged from the adversary's 10:40 reading; the entry now standing is op-wcard's, unstamped, with a `ref:` that dangles here, and `rdw_batch/LEDGER.md:1107` records this branch minting that same bare id. **F5:** check #4 was `^`-anchored over a four-column map and could see 4 of 16 pairs; replaced with an awk check, RED demonstrated on a sabotaged column-3 pair. **F6:** verified against the repaired file — the merge hunk (1612/3044/3336) leaves the reservation, the map and the filing sequence **above** it and swallows the 1400 bullet, the pointer and the tail warning; one caution sentence mirrored into the head, where a merge cannot reach it. **F2:** disputed on its premise and fixed on its residue — `ase_analyses_batch` had minted nothing (its own `CREW_BRIEF.md:118`), but its `PLAN.md:2535-2536` still told a crew to file under 1400 and `owed.sh add rule 1400`; those two lines now name no number (`/usr/bin/grep -c 'add rule 1400'` on that file -> **0**), the only file outside N1's two that this item wrote. **F4 attribution corrected:** `rule/1351` is **op-wcard's**, not this branch's — its `ref:` dangles here, which is how F4b was found. Also F7 **31** not 32 (`13[3-9][0-9]` swept in `fix(1332)`), F8 `24e09c65` at **09:44:06** not 09:52, F9 strikethrough precedent quoted as a grep not line numbers, F11 the unpublished evidence taken op-wcard-side (`no upstream configured`, no tracking marker, `--contains` empty x5), F12 the `0999 -> 1200` skip added to the filing sequence. **Driver still owes the `rule` debt on 1400 — and must NOT use the bare id `1400`.** |
| N2 | `owed.sh` origin stamping, cross-origin refusal, `cleared.log`; spec R608/R609/**R610** | **done** — 92/92 new checks green on a two-real-git-clone fixture, existing `test_owed.sh` 75/75 (77/77 with a display). RED shown first: pristine `add`/`clear` destroyed the other clone's entry at exit 0. `list` also got faster (2.39 s → 1.36 s over the live 192-entry ledger). Receipt: `receipts/N2.md` — three notes for N3, one for N4. **REPAIRED 2026-09-10 ~11:15 (adversary F1-F10: 9 fixed, 1 changed by the user's ruling, 0 disputed).** The three BLOCKING findings shared one root cause and are closed: **no ownership decision compares tags any more** — `cmd_add`'s ownership test, `cmd_add`'s namespacing test and `cmd_clear`'s `--repo` test are all exact string compares, and `_repo_same` is deleted. Reproduced first in a **same-basename** fixture (`…/p1/xschem`, `…/p2/xschem`), which the old `cloneA`/`cloneB` one structurally could not reach: **F1** a plain no-flag `add rule 1344` from the second clone replaced the first's unanswered ruling at exit 0 and kept the first's stamp -> now REFUSED exit 5, entry byte-identical; **F2** `clear --repo here` destroyed it and `add --repo here` overwrote it -> now refused / files `<id>@<tag>` beside it; **F3** a bare `--repo <tag>` the ledger does not know was stamped verbatim -> now exit 2, and so is an **ambiguous** tag (new, only reachable in the same-basename fixture). Also **F5** `_read_opts` now agrees with `_entry_field` about an entry with no trailing newline; **F6** a newline in subject/reason/`--ref` is exit 2 (it forged a `repo:` above the real stamp); **F7** the path fallback reads a linked worktree's `.git` file back to the clone, so R608's claim is now TRUE rather than softened; **F8** a failed `cleared.log` append is fatal — `clear` keeps the entry (exit 3), an overwriting `add` writes nothing, a passing drain does not remove the debt; **F9** the frozen "192" is out of R608 and is a dated measurement (192 at 10:05, 194 at 10:54). **F4 was the user's ruling, not a defect fix: the `--repo` escape STAYS, but `show` no longer advertises it** — it prints the plain clear command and names the owning clone; `show | grep -c -- '--repo'` -> **0**; running what it prints is refused, and the refusal is the one place `--repo` appears (and `_repo_hint` prints the clone's full path when its basename is shared). Verification: `bash -n` clean; **HEAD's 75-row `test_owed.sh` ALL PASS**; the current 181-row suite **3 FAILED**, all three the F4 ruling at `test_owed.sh:781-788`, named in the receipt with what they must become (O34b) — **N3's file, not touched**. Everyday output still byte-identical to HEAD bar the one marker; `list` still faster (2.34-2.43 s -> 1.51-1.57 s). Spec §4 now REQUIRES a third same-basename clone and adds rows O34b, O35-O39. **Collision size is date-and-time stamped in both files and says it was still growing** (7 at 08:25, 12 at 10:45, op-wcard's tail 1354). **Limit stated in the receipt: 0 of 194 live entries are stamped, so the refusal protects nothing yet — it arms one entry at a time as each is next touched; a driver backfill would arm all 194 (that is why `rule/1351` could still be overwritten in place at 10:46:14).** Cross-item: `doc/claude/lookdebt_batch/build_page.py:52` emits `owed.sh clear look <id>` into the user's digest page and will print a command that exits 5 once entries are stamped — not my file. Real ledger never written (`diff -rq` IDENTICAL after every read); op-wcard not touched; binary never launched. |
| N3 | `test_owed.sh` rows for all of N2 | **DONE** — **75 -> 181 checks** (`RESULT: ALL PASS (181 checks, 1 skipped)`), +106 rows, none removed, none altered: the diff deletes exactly 3 lines (header `O1..O22`->`O1..O34`, the `OWED_SH` RED hook, the O13 skip wording). **O9 and O18 green in every run**, and re-asserted in the two-clone world. RED first against `git show HEAD:tests/headless/owed.sh`: **70 of the 106 new rows fail, 0 of the 75 old ones** — the 36 green ones are the 192-legacy compatibility rows, the O9/O18 twins, and paired halves whose partner is red (itemised in the receipt). **15-variant sabotage matrix**, every group O23-O34 red under at least one; it found a hole in my own O29 (a bare `--repo <tag>` round-trips through the ledger, so the stamp-rewrite defect was undetectable — closed with a `--repo <path>` sharing the basename, +3 rows). Fixture: two real `git init` clones + a worktree + a `git` shim that fails. Three findings: **O13 launches the real binary on the user's own screen** and the condition is live here (`$DISPLAY`=the Windows X server, `src/xschem` built) — added an announcement and `OWED_TEST_DISPLAY=none`, but **preferring `:99` is a ruling, not mine**; `add --repo <theirs>` keeps their stamp but **overwrites their `ref:`** with a path from the updating clone (N2's file, not pinned in a check on purpose); and `specs/owed.md` §5 should gain this matrix (also N2's). Real ledger never written (no `cleared.log` in it), op-wcard never read, binary never launched. See `receipts/N3.md`. **REPAIRED 2026-09-10 ~11:25 (adversary: 3 findings + the driver's JOB A; 3 fixed, 0 disputed, 0 skipped, plus 3 spec rows nothing had implemented).** **181 -> 233 checks**, `RESULT: ALL PASS (233 checks, 1 skipped)` — and the 181-row suite scored **`3 FAILED (178 passed, 1 skipped)`** against the *repaired* `owed.sh`, so 181 was never the number to compare against. **JOB A: the O29 group pinned the tag-tolerant compare as correct and the whole fixture (cloneA/cloneB) structurally could not see the defect.** Fixture grew a third clone, `.../p1/xschem` + `.../p2/xschem`, sharing one basename: **O35** covers a plain no-flag foreign `add` (exit 5, standing entry byte-identical, wording and stamp intact, nothing filed beside it), `--repo here` meaning strictly this clone (files `<id>@<tag>`, and with its own slot gone does **not** fall through to theirs), and refusals that print the **full path** rather than the ambiguous tag; **O36** covers a bare unknown tag (exit 2, nothing written, and the rightful owner still clears its own entry — it used to be **refused on its own ruling**, `{5} (exp {0})`) and an ambiguous tag (exit 2, both candidates named). **O29 realigned** (+4 rows, now asserting the opposite) and the 3 `show`/`--repo` rows became **O34b**'s 6, asserting the user's ruling: `show` prints no `--repo` at all, the plain command it prints is **refused**, the ruling stands. **Finding 1** (O33's R502 row counted a directory `owed.sh` cannot write, so it could not fail) fixed and proved both ways: mutation m5 leaves the OLD row at `ALL PASS (233)` and reds the NEW one 1/233. **Finding 2** (O13's live arm has never been executed by anyone; `1 skipped` reads as coverage) declared in the skip line, a comment block and the **banner**, which now prints it on every run; `full_audit.sh:393` globs `test_*.tcl` so this file is outside the audit set. **Finding 3** (the count is a moving floor) — both published: **233/1 skipped with git, 228/3 with a `git` shim that exits 1, both ALL PASS**, and the suite prints its own environment. **Extra: O37/O38/O39** — named by N2's spec, implemented by nobody — added (newline forging exit 2; `list` and `clear` agreeing about an unterminated `repo:` line; an unwritable `cleared.log` being fatal to every destroy, plus the worktree-without-git leg). **RED first against N2's pre-repair `owed.sh` via `OWED_SH`: `40 FAILED (193 passed, 1 skipped)`, every red row one this repair wrote or turned round, and 0 of the 75 pre-existing rows** (`107 FAILED` against HEAD's pristine copy, same 0). Working-tree `owed.sh` md5 unchanged; vs HEAD the diff is still **3 deletions**, 742 insertions, 353 -> 1092 lines. Collision size stamped in the file and the receipt: **7 at 08:25, 12 at 10:45 on 2026-09-10, still growing**, op-wcard's tail 1354. Real ledger never given to `owed.sh` (no `cleared.log` in it, 0 stamped entries) — though it moved again under us, 52->53 look / 8->9 suite, `look/` and `suite/` mtime **10:46:33**. op-wcard not read; binary never launched. N3's own F2 re-measured and still live (`add --repo <theirs>` replaces their `ref:`, so the owner's `list` marks the owner's own entry `(not in this clone)`) — N2's file, still deliberately unpinned. |
| N4 | `CLAUDE.md` numbering + ledger paragraphs | **DONE** — both existing sections edited, no section added; `CLAUDE.md` +43/-9 (445 -> 479 lines) and nothing else in the repo written. The numbering paragraph drops *both* broken halves ("the ONLY authority", "read its tail"), calls NUMBERING.md tracked/per-branch and its tail a **per-clone pointer**, carries a 4-line cross-clone mint command **run verbatim before it was pasted in**, reserves `1500–1599` (after 1499 -> 1600), and keeps the 2026-09-02/0513, 0420–0432 +80 and same-commit clauses. The ledger paragraph adds clone-vs-worktree, the `rm`/bare-`>` mechanism, the exit-5 refusal and `--repo <clone|here>`, **re-verified against the shipped `owed.sh` in a two-real-clone fixture**, not from N2's receipt. Two brief figures did not survive re-measurement: the collisions are **8** (1349 filed at 09:12 today) and the queue is **50** (op-wcard's tail is **1350**), so the paragraph states 16 taken in both / 7 already naming two defects / 1349 the same morning / 50 committed behind that tail. **Cross-item: `NUMBERING.md:3016-17` (N1's) still says "seven … 51 more", contradicting its own `:2997` and `:3000` — needs 8 and 50.** Also: the ugrep trap hits the exact `-l` command CLAUDE.md now prints (bare `grep` calls 1349 free in both clones), and N2's `[--repo]` request went into the prose, not the usage block (the block never listed `clear`). See `receipts/N4.md`. **REPAIRED 2026-09-10 10:47 (adversary F1-F10, all 10 fixed, none disputed): `CLAUDE.md` now +81/-9, 445 -> 517.** The mint check was **false-green on a reserved band** — `n=1550` and `n=0550` read as free from both greps, including the band this batch just reserved — because bands are RANGES in NUMBERING.md's head table and no per-number grep matches one. It is now **two** checks: an `awk` over the head table (n=1550 -> `!! 1550 is in RESERVED band 1500-1599`) plus the cross-clone grep, with the deleted "reserved blocks that must be skipped" clause restored, `n` sourced from the pointer line (**`tail -n1` is wrong** — N1 appended prose after it), `/usr/bin/grep -lw` in place of the anchored-alternation form ugrep silently drops, and a `[ -e "$1" ]` guard because an empty glob exits 2 on stderr and reads as free. `--repo <clone>` and `clear` moved **into** the usage block (my "three lines below" was 21). Ledger paragraph now says plainly that **an unstamped entry is NOT protected** (194 live entries, 0 stamped at 10:47; a foreign `clear` still succeeds at rc=0 with a warning — measured) and names **`cleared.log`**. **The collision set is TWELVE, not 8, and was still growing while this was written** — op-wcard filed 1349-1353 during this batch, its pointer reads **1354**, 1350's file was touched 10:45:47; the prose is date-AND-time stamped and says "any count here is a timestamp, not a standing fact". `NUMBERING.md:3016-17` (N1's) is now stale twice over. |

## Driver close-out, 2026-09-10 11:40 -0700

| item | status |
|---|---|
| N1 | landed — issue **1400** (**792** lines at 2026-09-10 12:5x, `wc -l < doc/claude/issues/1400-*.md`; it was **536** when this table said 519 — see the N1 row above), `NUMBERING.md` **+126/-2** (2953 → 3077). Adversary: 12 findings, all applied; second repair round: 4 more. |
| N2 | landed — `owed.sh` 459 → ~1020, `owed.md` +261. Adversary: 3 blocking, all closed and reproduced before/after. |
| N3 | landed — `test_owed.sh` 353 → ~1100. **Floor RAISED 75 → 233.** |
| N4 | landed — `CLAUDE.md` +90/-9, both paragraphs. Adversary: 10 findings, all applied. |
| close-out | 35 of 37 findings CLOSED, 0 disputed. |

`tests/headless/test_owed.sh`: **`RESULT: ALL PASS (233 checks, 1 skipped)`**
(228/3 on a box with no usable `git` — both published, so a git-less run does not
read as a regression). The 1 skip is O13's live-binary arm and **the suite now says
in its own banner that a skip is not a pass** — that arm has never been executed in
any published run.

### The defect fired during the batch, and it took a real ruling

At **10:46:14 -0700**, while the repair pass was running, the other clone ran
`owed.sh add rule 1351` and **silently overwrote this branch's standing, unanswered
ruling** — exit 0, printed `recorded`, no warning. Proof it was an in-place rewrite
and not a create: the entry's own `ts` field reads 10:46:14 while `rule/`'s directory
mtime is still frozen at `06:54:10.569645589` (a directory mtime moves on create and
unlink, not on a rewrite), and the file count did not change.

**The lost ruling was recoverable** and was held in
`~/.claude/xschem_owed.bak.2026-09-10/rule/1351`: an RDW driver decision about a
selection that outlives its text, filed 2026-09-04,
`ref:doc/claude/issues/1351-the-poll-guard-the-orphan-chain-and-a-selection-that-outlives-its-text.md`.
The live `rule/1351` is op-wcard's H5 PostScript-font ruling, also real and also
unanswered. **Both must stand.** **It HAS since been recovered — see “Second repair round”
below; this paragraph's “Neither has been touched” no longer describes the ledger.**

⚠ **Correction to that backup's label.** This close-out called it *"the `cp -a` taken at
**09:20 before any item ran**"*. **Both halves are wrong.** Its copy-root ctime is
**09:37:32.626884587** (`stat -c '%n ctime=%z' ~/.claude/xschem_owed.bak.2026-09-10`;
strictly, ctime also moves on a rename or a chmod, so what is measured is "created or last
metadata-touched at 09:37:32"), and the batch had been running for **3 minutes** by then —
`DECISIONS.md` mtime **09:34:12**, `PLAN.md` **09:35:06**, `CREW_BRIEF.md` **09:35:33**.
**The evidence it carries is unaffected**: the overwrite was at **10:46:14**, over an hour
after the copy was taken, and 191 of the 192 entries in that copy have line 1 byte-identical
to the live ledger — the single exception is `rule/1351` itself, which is exactly the
signature of a clean pre-overwrite image. The figure is corrected rather than left standing,
because a wrong time in the one document that proves a recovery is a figure that will not
survive its next check.

This is the first confirmed loss. The earlier audit's "no ruling has been lost" was true of
what its author could see when it was taken, and it is no longer true.

### Not done, and why

⚠ **The first three bullets of this section were written at 11:39 and the first two are
now WRONG — the driver did all three things at 12:18.** They are kept, struck through,
because a reader who quotes this section is quoting the state of the ledger, and the
correction belongs next to the claim. The live state is in **“Second repair round”** below
and, durably, in `doc/claude/issues/1400-…md` under *“What was actually done to the
ledger”*.

* ~~**The ledger is unwritten by this batch** — 0 of 194 entries carry a `repo:` stamp~~
  **DONE 2026-09-10 12:18: 196 of 196 entries stamped**, append-only (byte-exact prefix on
  all 194 pre-existing ones), split **182 this clone / 14 op-wcard**, re-measured 12:41.
  There is still **no `cleared.log`** — it is created lazily on the first destroy by the
  repaired script, and the other clone's script never writes one. **The refusal now arms
  every entry from this clone — and protects none of them from the other clone**, which
  runs its own 2026-09-04 copy with no `repo:` logic at all. That half is the whole
  remaining exposure; see below.
* ~~**The `rule` debt on 1400 is not recorded**~~ **DONE 2026-09-10 12:18:51 —
  `rule/1400` stands**, `repo_via:git` (the ledger's only one), `ref:` resolving to the
  issue file. ⚠ It was filed on the **bare id `1400`**, which the N1 row above says twice
  not to do. It is clean today (op-wcard's tail reads 1354, and that tree has no 1400 issue
  file) but it is 46 numbers ahead of a pointer moving about one an hour, and it is
  destroyable by the other clone at exit 0 today — reproduced. Re-siting it as
  `rule/1400@xschem-claude` is a destroy-and-recreate and therefore the **user's** call.
* **op-wcard's pointer still walks this branch's committed band** (D-1). At 11:37 and
  again at 12:41 it read **1354**; 46 of the band remain queued ahead of it, and **32 of
  those numbers hold a bare rule id stamped to this branch** — i.e. an unanswered ruling
  each (`ls ~/.claude/xschem_owed/rule | /usr/bin/grep -xE '13(5[4-9]|[6-9][0-9])'`, each
  tested for `repo:/home/analog/dev/xschem-claude`; 32 of 32, 12:41 -0700). **10:46:14 was
  a sample, not an outlier.**
* **`doc/claude/ase_analyses_batch/`** still quotes the retired "ONLY authority" rule
  in `evidence/ase-conventions.md:47` and names 1400 as the tail in five dated places.
  The one genuinely dangerous line — `PLAN.md:2536`'s literal `owed.sh add rule 1400`
  — **is fixed**. The rest are honest dated observations whose own text says to re-read
  the tail at minting time, and that batch was being written by another session at
  11:27–11:29 today, so editing it further is the clobber hazard this batch is about.

---

## Second repair round — item N1 (the tracked record), 2026-09-10 ~12:4x–12:5x -0700

Applied against the four verifier receipts (`receipts/LEDGER_V{1,2,3,4}_*.md`) after the
driver's three writes to the live shared ledger. **The live ledger was read only** —
`/usr/bin/grep`, `find`, `stat`, `diff`; `owed.sh` was never invoked against it, nothing
under `~/.xschem/` was touched, `/home/analog/dev/xschem-op-wcard` was read only, no
git-mutating command was run, the binary was never launched. Files written: **exactly the
three this item owns** — `doc/claude/issues/NUMBERING.md`,
`doc/claude/issues/1400-…md`, and this file.

| defect | verdict |
|---|---|
| **C-A HIGH** — `NUMBERING.md:3017` still said in bold *“No ruling has been lost”* | **FIXED.** Replaced with the true account: a ruling **was** lost at 10:46:14, recovered only because a hand-taken `cp -a` happened to exist, both 1351 rulings now stand unanswered. The old claim is kept struck-through and labelled superseded, with **why the earlier audit was honest and still wrong**: it was written at 10:49:57, three minutes after a loss it structurally could not see, because an in-place `>` moves no directory mtime and changes no file count — so the very forensic that proved 1338 safe is blind to what took 1351. The generalised lesson is stated: *the ledger reports nothing when it loses a ruling*. A merge-safe copy of the same warning was added to the **head** of `NUMBERING.md`, above the conflict hunk that swallows the tail. |
| **C-A residue** — other copies of the claim in the tree | **MEASURED, one left, NOT MINE.** `/usr/bin/grep -rIn 'ruling has been lost' --exclude-dir=.git .` taken **before** this round → **6 hits in 5 files**: `NUMBERING.md:3017` (the defect — fixed), `LEDGER.md:51` (already corrected it), issue 1400’s *“A ruling WAS overwritten”* section, which quotes the earlier draft’s heading in order to retire it, `receipts/LEDGER_V4_BLAST.md:309` and `:314` (the finding itself), and **`numbering_batch/PLAN.md:63`, which still carries the bold claim uncorrected**. PLAN.md is **not** one of this item's files, and it is untracked batch scaffolding superseded by this ledger — flagged here rather than edited, per the ownership rule. One line closes it. |
| **C-B HIGH** — the recovery is invisible in the repo | **FIXED.** `/usr/bin/grep -rIc '1351@xschem-claude' doc/claude/issues/` was **0**; it is now recorded in issue 1400 as a new section, *“What was actually done to the ledger — the recovery, the backfill, and `rule/1400`”*: the 10:46:14 destroy and its evidence, the recovery with its byte-faithful `diff` (the whole diff is the two stamp lines) and its provenance, the backfill with the append-only proof and the **182/14** split corroborated six ways with zero misattributions, `rule/1400`, and the fact that **both 1351 rulings stand and both are unanswered**. The four contradicting statements are corrected: closing conditions **4** and **5** of issue 1400 (struck through, with what replaces each), this file's *“Not done, and why”* (all three bullets), and issue 1400’s live-sounding `clear rule 1339` sentence (V4 cited it as `:331`), which since 12:18 exits **5** from this clone — rewritten to past tense with the refusal quoted, and with the sharper half said out loud: **the refusal runs here; the same command from the other clone still succeeds.** **`CLOSEOUT.md` §5 — the fourth site — is a receipt this item does not own; still says *“no backfill has run”* and *“the ledger at 194 / 0 stamped”*.** |
| **C-C** — issue 1400 is 536 lines, stated as 519 in three places | **FIXED in the two sites this item owns**, and re-measured: **792** lines after this round (`wc -l < doc/claude/issues/1400-*.md`, 2026-09-10 12:5x). Both `LEDGER.md` sites now carry the number **with its clock and its command**, and say plainly that 519 was already stale when it was typed at 11:39 (the file's mtime was 11:37:54 and it was 536). **NOT MINE, still 519: `receipts/CLOSEOUT.md:135` — the N1-F10 finding that certifies the figure — `CLOSEOUT.md:224`, and `receipts/N1.md:344`.** Named with line numbers so the driver closes them in one edit. |
| **C-D** — the pre-batch backup labelled *“taken at 09:20 before any item ran”* | **FIXED.** Corrected in place to **09:37:32.626884587** (copy-root ctime; strictly “created or last metadata-touched”, since ctime also moves on a rename or chmod), with the batch already **3 minutes** in — `DECISIONS.md` 09:34:12, `PLAN.md` 09:35:06, `CREW_BRIEF.md` 09:35:33 — **and with why it does not matter**: the overwrite was at 10:46:14, over an hour later, and 191 of the 192 entries in that copy have line 1 byte-identical to live, the one exception being `rule/1351` itself. |
| **the four verifier facts about the options** | **FOLDED IN, not appended.** Issue 1400's options section gained a three-point preamble that re-prices all four — (1) the protection is **one-sided**, the single thing that makes it mutual is the repaired `owed.sh` being present in the other clone, and **that file is still uncommitted here** so that clone could not get it by pulling; (2) renumbering never repairs the ledger and can damage it; (3) after absorption an entry's clone can no longer be re-derived from the tree — plus a **new cost paragraph inside each of (a), (b), (c) and (d)**. The recommendation line now leads with *commit `owed.sh` and get it into the other clone today*, which is not a ruling and is not blocked by D-1. The **32** barrels in `1354–1399` are in the ledger-hazard section as a measured list, under the heading *“the fired one was a sample, not an outlier”*, and the marker-rule fragility has its own subsection, *“The limit of the attribution, stated plainly”*. |

**One correction to the brief, with evidence.** The brief says *“12 of the 14 op-wcard
stamps rest on the literal string `hier_pdf_links`”*. Measured per entry at 12:41 -0700
(each foreign-stamped entry's filename + full text tested for each literal): **11** rest on
`hier_pdf_links` and **1** on `test_ps_valid` — 12 rest on a **batch-name literal**, and
those same 12 carry **no `ref:` at all**; the remaining 2 (`rule/1339`, `rule/1351`) rest
solely on a `ref:` that resolves only in op-wcard. The conclusion is unchanged and the
issue states the corrected breakdown.

**Counts re-taken 2026-09-10 12:41 -0700, read-only, and each is an observation with a
clock on it — this set has moved every single time this batch measured it:**

```
find ~/.claude/xschem_owed -maxdepth 2 -type f | wc -l                        -> 196
find ~/.claude/xschem_owed/{rule,look,suite} -maxdepth 1 -type f | wc -l      -> 134 / 53 / 9
find ~/.claude/xschem_owed -maxdepth 2 -type f -exec /usr/bin/grep -h '^repo:' {} + \
  | sort | uniq -c                     -> 182 xschem-claude, 14 xschem-op-wcard
find ~/.claude/xschem_owed -maxdepth 2 -type f -exec /usr/bin/grep -L '^repo:' {} + | wc -l   -> 0
ls ~/.claude/xschem_owed/rule | /usr/bin/grep -xE '13(49|[5-9][0-9])'         -> 35
  … of which stamped repo:/home/analog/dev/xschem-claude and inside 1354-1399 -> 32
ls doc/claude/issues + op-wcard's, numbers whose filenames differ             -> 12 collisions
tail of op-wcard's NUMBERING.md                                              -> next free 1354
git status --porcelain tests/headless/owed.sh                                -> " M"  (UNCOMMITTED)
/usr/bin/grep -c '^repo:\|_entry_repo\|_origin' <op-wcard>/tests/headless/owed.sh -> 0
```

**Left standing for the driver, in files this item does not own:** `PLAN.md:63`
(uncorrected *“No ruling has been lost”*), `CLOSEOUT.md` §5 (*“no backfill has run”*,
*“194 / 0 stamped”*), `CLOSEOUT.md:135` and `:224` and `N1.md:344` (**519**).
