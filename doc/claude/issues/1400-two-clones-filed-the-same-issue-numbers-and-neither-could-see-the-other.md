# 1400 — two clones filed the same issue numbers, and neither could see the other

**Measured 2026-09-10; collision counts taken at 10:46 -0700, ledger counts re-taken at
12:41 -0700**, read-only in both checkouts, by item **N1** of
`doc/claude/numbering_batch/` and its second repair round. Every count below was taken with `/usr/bin/grep`;
the shell's bare `grep` is ugrep with `-I --ignore-files` forced and returns **0**
for the single-alternative numeric patterns used here.

⚠ **Every count in this file is an observation with a clock on it, and the set was still
growing when the last one was taken** — the other clone filed five more colliding numbers
during the batch that wrote this issue, the most recent **one minute** before the final
count. Read the timestamp beside a number before quoting it, and re-take it with the
command printed next to it. Nothing here is a standing fact.

## The mechanism

`doc/claude/issues/NUMBERING.md` is a **tracked, per-branch file**. CLAUDE.md called it
"the ONLY authority" on issue numbers and told a filer to read its tail before minting —
item **N4** of this batch removed both halves of that sentence. A tracked file lives inside
one checkout, so it structurally **cannot see across a clone boundary**.

Two clones of this repository sit on this machine:

```
/home/analog/dev/xschem-claude    branch fluid-editing
/home/analog/dev/xschem-op-wcard  branch op-wcard      (no remote branch exists)
```

Each read its own tail. Each found the block free. Each filed into it. **Neither session
did anything wrong by the rule as written — the rule is what is broken.** op-wcard filed
this same defect from its own side as its issue **1347**, which is itself one of the
colliding numbers.

## It does not take two clones — one clone with two batches will do

`1400` was minted for this issue from the tail of `NUMBERING.md`, and it was genuinely free.
The only other batch in this checkout that had written the number down,
`doc/claude/ase_analyses_batch/`, says so itself: its crew brief records *"this batch has not
advanced it and has minted nothing"*, its plan-authored receipt records that its code
sketches no longer hard-code the number, and its minting step says to read the tail **at the
moment of minting**. Nothing was claimed and nothing collided.

What was live was the **residue**. One paragraph of that batch's `PLAN.md` still read *"File
them as one batch under issue 1400 … then `owed.sh add rule 1400`"* — a number frozen into a
plan that a crew reads days later. A crew following it literally would have filed its nine
questions against this issue and then written the bare id `1400` over the rule debt this
issue exists to carry. **Inside one clone, origin stamping is no defence whatever**: both
batches share an origin, the stamp matches, `cmd_add` takes the update path, and the bare
`>` at `owed.sh:187` keeps whichever ruling landed second.

That paragraph now names **no number** and says to read the tail at minting time, matching
what the rest of that batch's own documents already said. The general form is the point:
**a number written into a document is stale from the moment it is written.** Two clones or
two batches in one directory only changes how long it takes to hurt.

## The collision, by filename

`ls doc/claude/issues/ | /usr/bin/grep -E '^13(3[3-9]|4[0-8])-'` in each tree:

| number | `fluid-editing` (filed 2026-09-05) | `op-wcard` (filed 09-09 / 09-10) |
|---|---|---|
| **1338** | `1338-updown-move-the-store-but-not-the-window.md` | `1338-pdf-link-border-invisible.md` |
| **1339** | `1339-select-and-ctrl-c-do-not-copy.md` | `1339-pdf-link-hotspot-tracks-name.md` |
| **1344** | `1344-the-rdw-puts-the-wrong-text-on-the-clipboard-and-wipes-it.md` | `1344-negative-page-scale-mirrors-export.md` |
| **1345** | `1345-the-rdw-says-did-not-converge-when-its-formatter-merely-declined.md` | `1345-export-page-scale-follows-the-canvas.md` |
| **1346** | `1346-the-keys-suite-is-noisy-under-cpu-load-…-not-the-modal.md` | `1346-link-prefs-read-once-per-link.md` |
| **1347** | `1347-the-rdw-summary-reorder-says-the-sheet-followed-and-it-cannot.md` | `1347-issue-numbers-collide-across-checkouts.md` |
| **1348** | `1348-a-flavor-reorder-reslots-a-block-the-edit-never-reached.md` | `1348-two-pages-can-share-one-pdf-destination.md` |

**Seven when that table was taken at 09:38. TWELVE as of 2026-09-10 10:46 -0700**, and
still growing at that moment. The band the table covers is `1333–1348`; the collision has
since walked out the top of it, into numbers this branch committed on 2026-09-05:

| number | `fluid-editing` (2026-09-05) | `op-wcard` | its mtime |
|---|---|---|---|
| **1349** | `1349-delete-and-add-leave-the-rdw-pane-and-the-store-disagreeing.md` | `1349-same-basename-page-ownership-is-symbol-table-order.md` | 09:12:14 |
| **1350** | `1350-the-newest-dump-carries-the-raw-order-and-contradicts-the-reordered-blocks-below-it.md` | `1350-backslash-in-text-never-terminates-its-postscript-string.md` | **10:45:47** |
| **1351** | `1351-the-poll-guard-the-orphan-chain-and-a-selection-that-outlives-its-text.md` | `1351-font-attribute-is-a-postscript-name-and-a-format-string.md` | 10:19:47 |
| **1352** | `1352-input-line-runs-what-you-type-as-tcl.md` | `1352-a-dest-name-minted-from-a-file-name-is-not-a-postscript-name.md` | 10:19:47 |
| **1353** | `1353-the-narrowing-landed-and-the-four-decisions-it-forced.md` | `1353-set-ps-colors-reads-one-element-past-the-colour-array.md` | 10:24:27 |

Re-runnable, both trees, any time — this is the command, not the number:

```
for n in $(seq 1333 1399); do
  a=$(ls doc/claude/issues/ | /usr/bin/grep -cE "^${n}-")
  b=$(ls /home/analog/dev/xschem-op-wcard/doc/claude/issues/ | /usr/bin/grep -cE "^${n}-")
  [ "$a" -gt 0 ] && [ "$b" -gt 0 ] && echo -n "$n "
done; echo
->  1338 1339 1344 1345 1346 1347 1348 1349 1350 1351 1352 1353      (12, at 10:46 -0700)
```

**This is not a closed historical set.** It went from seven to twelve on one morning — 1349
at 09:12, 1351 and 1352 at 10:19, 1353 at 10:24, 1350 at **10:45:47, one minute before the
count above was taken** — and op-wcard's tail read **1354** when this was written. **Every
number in this file carries the clock it was read at. None of them is a standing fact, and
the set was still growing when the last of them was taken.**

## The collision, by NUMBERING.md's own authority: sixteen

op-wcard's `NUMBERING.md` carries a bullet entry for **every** number `1333–1348`:

```
/usr/bin/grep -nE '^\* \*\*13(3[3-9]|4[0-8])\*\*' \
    /home/analog/dev/xschem-op-wcard/doc/claude/issues/NUMBERING.md   ->  16 lines
```

Nine of them — **1333 1334 1335 1336 1337 1340 1341 1342 1343** — have no issue file in
that tree only because the batch fixed them in flight and numbered them in the register
instead. This branch has all sixteen as files. So by the authority CLAUDE.md names,
**sixteen numbers mean two different things**, not seven. Five of op-wcard's twelve commit
subjects already name them:

```
24e09c65 feat(1338): only a non-PDK cell with real hierarchy gets the clickable link highlight
e451892b feat(1338,1339): the PDF link gets a visible border and a choosable hotspot…
7f8d72a8 fix(1336,1337): the hierarchical PDF's link rectangles become legal…
743c81d2 fix(1333,1334,1335): the hierarchical PDF's links stop crashing…
18e8e179 batch(hier_pdf_links): DD-6 splits 1334 off and re-designs it after two refutations
```

(**Four** when this issue was first written, at 09:38. `24e09c65` landed at **09:44:06** —
`git -C /home/analog/dev/xschem-op-wcard log -1 --format='%cI' 24e09c65` →
`2026-09-10T09:44:06-07:00`. An earlier draft of this issue said 09:52, from the wall clock
of the re-run rather than the commit.)

## The two reservations overlap outright

| file | line | text |
|---|---|---|
| `xschem-claude` `NUMBERING.md` | **1590** | `## Reserved: 1337-1341, the RDW batch (doc/claude/rdw_batch/)` |
| `xschem-op-wcard` `NUMBERING.md` | **1833** | `**1333-1348 are reserved by doc/claude/hier_pdf_links_batch.**` |

Both numbers were taken with `/usr/bin/grep -n` **before** this item edited anything, and
**neither is stable**. This item's own head insertion moved the first from **1590** to
**1626**; op-wcard's live session moves the second whenever it files. Find them with
`/usr/bin/grep -nE 'Reserved: 1337'` and `/usr/bin/grep -nE '1333-1348 are reserved'`
rather than trusting either figure — a line number in a file two sessions are writing is
the same class of authority as the tail pointer this issue is about.

`1337–1341` sits wholly inside `1333–1348`. Both reservations are honest; neither file
can read the other.

## The forward exposure: the rest of the band, already queued

**Every figure in this section is a timestamped observation, not a standing fact.** The
set was growing while this issue was being written, and every count below moved at least
once during the batch that produced it. Re-take them before quoting them:

```
# how many numbers name two different defects right now
for n in $(seq 1333 1399); do
  a=$(ls doc/claude/issues/                       | /usr/bin/grep -E "^$n-" | head -1)
  b=$(ls ../xschem-op-wcard/doc/claude/issues/    | /usr/bin/grep -E "^$n-" | head -1)
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" != "$b" ] && echo "$n"
done | wc -l
```

op-wcard's tail read **next free 1349** when this batch was scoped at 08:25. As of
**2026-09-10 11:37 -0700** it reads **1354**, and it is **still moving** — it advanced
five numbers during the batch run alone, roughly one an hour.

This branch has committed **every** number from 1349 to 1399, with no gaps:

```
git ls-tree -r --name-only HEAD doc/claude/issues/ \
  | /usr/bin/grep -cE 'issues/13(49|[5-9][0-9])-'        ->  51
```

`for n in $(seq 1349 1399)` over `doc/claude/issues/${n}-*.md` finds **no missing number
and no untracked one**. So op-wcard's pointer walks a band this branch has already spent.
At 11:37 -0700 on 2026-09-10: **12** numbers name two different defects (1338, 1339,
1344–1353), and **46** of the band remain queued ahead of that pointer. Nothing in either
tree reports any of it at any point — not on filing, not on merge, not on `owed.sh add`.

Under ruling **D-1** this batch may not touch op-wcard, so it cannot move that pointer.
**That is stated here rather than worked around.**

## What a merge actually does with it — measured, not inferred

Re-measured for this issue in a throwaway clone under the session scratch directory
(`git clone --local --shared` of `fluid-editing`, `git fetch` of op-wcard, `git merge
--no-commit --no-ff`, then `git merge --abort`; neither real tree was written to):

```
merge-base            28dabfe85898669290180769fa358c7c2bad5070
conflicts (4)         doc/claude/issues/NUMBERING.md
                      src/ase.tcl
                      src/op_annot.tcl
                      tests/headless/test_op_dump_altshow.tcl
colliding issue files A  doc/claude/issues/1338-pdf-link-border-invisible.md
                      A  doc/claude/issues/1339-pdf-link-hotspot-tracks-name.md
                      A  doc/claude/issues/1344-negative-page-scale-mirrors-export.md
                      A  doc/claude/issues/1345-export-page-scale-follows-the-canvas.md
                      A  doc/claude/issues/1346-link-prefs-read-once-per-link.md
                      A  doc/claude/issues/1347-issue-numbers-collide-across-checkouts.md
                      A  doc/claude/issues/1348-two-pages-can-share-one-pdf-destination.md
                      A  doc/claude/issues/1349-same-basename-page-ownership-is-symbol-table-order.md
duplicated numbers in the merged worktree (.md only)
                      1338 1339 1344 1345 1346 1347 1348 1349
```

**Every colliding issue file lands as a clean add. Not one of them conflicts** — the slugs
differ, so git sees two unrelated files and takes both. The merged tree then holds two
`1338`s, two `1339`s and so on, permanently, inside one checkout.

**Stated once, in the units the command reports.** Earlier drafts of this issue gave this
one measurement three different ways — 6, 8 and 16 — by mixing *files added by the merge*
with *files in the merged tree*. They are not the same number and neither is wrong:

```
git diff --cached --name-only --diff-filter=A -- doc/claude/issues/ \
  | /usr/bin/grep -cE '/13[0-9]{2}-'
```

> **The merge adds 8 files and conflicts on 0 of them. The merged tree then holds 16 files
> carrying 8 duplicated numbers** — 1338 1339 1344 1345 1346 1347 1348 1349. Measured
> 2026-09-10 10:46 -0700, and the 8 is a snapshot: it counts only op-wcard's **committed**
> files, so `1350`–`1353` are outside it until that session commits them.

Only op-wcard's files are adds; this branch's are already in the target of the merge, so
they never appear as `A`. **This measurement was taken three times and it moved twice:**

| | 09:38 | 10:46 -0700 |
|---|---|---|
| conflicts | the same 4 | the same 4 |
| op-wcard files added (`--diff-filter=A`) | **6** | **8** |
| duplicated numbers in the merged tree | 1338 1339 1344 1345 1346 1347 | + **1348 1349** |
| files in the merged tree carrying them | 12 | 16 |

The 09:38 column is not re-expressed arithmetic — it was re-measured by merging the same
clone against `e451892b`, op-wcard's tip before `24e09c65`, and counting `A` lines: **6**.
At 09:38 op-wcard's `1348` and `1349` were *untracked* in that tree
(`git ls-files --error-unmatch` errored on both), so the merge could not see them, and this
issue recorded eight pairs as a **projection**. At **09:44:06** that session committed
`24e09c65 feat(1338): only a non-PDK cell with real hierarchy gets the clickable link
highlight`, and the right-hand column is **measured, no longer projected**.
`PLAN.md`'s "14 files" figure counted seven pairs from a working tree.

The defect grew twice while one item was documenting it: once by a new collision (`1349`,
09:12) and once by the merge surface widening (`24e09c65`, **09:44:06**). By the repair pass
at 10:46 it had grown three times more. **Any count in this file is a snapshot with a
timestamp on it, including this one.**

**The only file that would have flagged any of it is `NUMBERING.md` — which a human
resolves as prose**, in the same sitting as three code conflicts, at the end of a merge.

### ⚠ Hazard for whoever performs the absorption: half of this repair is inside that hunk

Measured the same way, with this item's own edits committed on top before the merge: the
`NUMBERING.md` conflict is **one hunk covering the whole lower half of the file**, and the
repair straddles it.

| what | where | fate |
|---|---|---|
| `Four blocks are reserved` + the reserved-block table | head | **above the hunk — survives any resolution** |
| the filing sequence, `… 0998  0999  1200  1201 …  1498  1499  1600  1601 …` | head | **above the hunk — survives** |
| the `1333–1348` → `1500–1515` absorption map | head | **above the hunk — survives** |
| the PER-CLONE caution mirrored into the head | head | **above the hunk — survives** |
| the **1400** bullet in the running record | tail | **inside the hunk** |
| `**The next free number is 1401.**` | tail | **inside the hunk** |
| the full PER-CLONE warning under the pointer | tail | **inside the hunk** |

Verified against the repaired file itself, not a projection: the working-tree
`NUMBERING.md` and this issue were committed onto a throwaway clone of `fluid-editing`, then
merged with `wc/op-wcard`. One conflict, three markers — `<<<<<<< HEAD`, `=======`,
`>>>>>>> wc/op-wcard` — with **every head-section landmark above the first marker, every
tail landmark of ours between the first and second, and op-wcard's own `1350` pointer
between the second and third**. Re-take it with
`/usr/bin/grep -n '^<<<<<<<\|^=======$\|^>>>>>>>' doc/claude/issues/NUMBERING.md` in the
merged worktree and compare against
`/usr/bin/grep -n 'PER-CLONE\|next free number' …`; the absolute line numbers move every
time either clone writes, which is the reason this issue quotes commands and not lines.

The incoming side of that hunk ends `**The next free number is 1350.**` — op-wcard's tail as
committed, four numbers behind its own working tree, which read `1354`. So a resolver who
takes *theirs* for the tail — the ordinary move for the end of a running log — produces a
file that reserves `1500–1599` at the head and points at **1350** at the tail, a number this
branch has committed. **That is worse than either input, and it is what the normal
resolution does.** This is why one sentence of the per-clone caution is duplicated into the
head section: it is the only part of the warning a merge cannot swallow. **On resolution,
take the HIGHER of the two tail pointers, and check both clones before minting from it.**

## The ledger hazard, which renumbering does not repair

`~/.claude/xschem_owed/` lives in `$HOME`, outside both clones. Both trees write one
ledger, and `owed.sh` has no idea there is more than one tree.

* **`cmd_clear` (`tests/headless/owed.sh:288-295`) resolves by exact filename.**
  `[ -e "$d/$id" ] || _die …` then `rm -f "$d/$id"`. Nothing consults an origin.
* **`cmd_add`'s write (`:187`) is a bare `>` with no existence check.**
  `printf '%s\t%s\t%s\n' … > "$d/$id"`. It prints `recorded`, never `replaced`.
  (`PLAN.md` says `:188`; the line is **187**.)

Demonstrated against a throwaway `XSCHEM_OWED_DIR` in scratch — the real ledger was read,
never written:

```
add rule 1344 "RDW clipboard ruling" --eyes
  1789058620  1344  RDW clipboard ruling
  eyes:1
  ref:doc/claude/issues/1344-the-rdw-puts-the-wrong-text-on-the-clipboard-and-wipes-it.md

add rule 1344 "page scale ruling from the other clone"     -> "owed: recorded rule debt: 1344"
  1789058620  1344  page scale ruling from the other clone
  ref:doc/claude/issues/1344-the-rdw-puts-the-wrong-text-on-the-clipboard-and-wipes-it.md
```

The reason is replaced, **`eyes:1` is silently dropped**, and the tool reports success. In
the real cross-clone case the `ref:` is re-resolved from the *writing* tree, so the entry
becomes a chimera: one tree's ruling text over the other tree's pointer.

**SIX bare 4-digit rule ids on collided numbers were live in the real ledger at 2026-09-10
10:46 -0700** — three when this issue was first written, six once the collision walked into
`1349–1399`:

```
for n in 1337 1338 1339 1344 1345 1346 1347 1348 1349 1350 1351 1352 1353; do
  [ -e "$HOME/.claude/xschem_owed/rule/$n" ] && echo -n "$n "
done; echo          ->  1337 1339 1344 1351 1352 1353
```

| id | whose ruling it is | evidence |
|---|---|---|
| `rule/1337` | this branch (RDW target row) | `ref:` → `1337-the-rdw-target-row-is-invisible.md`, resolves here |
| `rule/1339` | **op-wcard** (PDF link hotspot) | `ref:` → `1339-pdf-link-hotspot-tracks-name.md`, **dangling here** |
| `rule/1344` | this branch (RDW clipboard, `eyes:1`) | `ref:` → `1344-the-rdw-…-wipes-it.md`, resolves here |
| `rule/1351` | **op-wcard** (PostScript font mapping, `eyes:1`) | `ref:` → `1351-font-attribute-is-a-postscript-name-and-a-format-string.md`, **dangling here** — and see the next section, because this slot changed hands *during this batch* |
| `rule/1352` | this branch (`input_line` runs typed text as Tcl) | `ref:` → `1352-input-line-runs-what-you-type-as-tcl.md`, resolves here |
| `rule/1353` | this branch (RDW narrowing, four forced decisions) | `ref:` → `1353-the-narrowing-landed-…md`, resolves here |

At **10:46 -0700 on 2026-09-10**, from this tree, `owed.sh clear rule 1339` deleted
**op-wcard's** unanswered ruling and left this tree's `1339_R3_copy_says_what_it_did`
standing, with no error and no trace. `rule/1339`'s `ref:` is a dangling path from here,
and that was the only signal.

**That specific command no longer works from this tree.** Since the driver's backfill at
**12:18** it exits **5** and writes nothing: *`!! owed REFUSED: rule 1339 belongs to another
clone -- NOT cleared`*, naming op-wcard as the owner, printing the standing text, and
offering `clear rule 1339_R3_copy_says_what_it_did` as this tree's candidate on that
number. **Read the paragraph above as the reason the fix exists, not as a live
instruction** — and note carefully that the refusal runs **here**; the same command from
the other clone still succeeds. See *“What was actually done to the ledger”* below.

**At 10:46 -0700, item N2's refusal covered none of these six.** All six were *legacy*
entries with no `repo:` stamp, and an unstamped entry is by design claimable — `cmd_add`
warns (`… predates origin stamps -- claiming it for <clone>`) and then **proceeds at
rc=0**. **All 194** entries in the live ledger were unstamped at that moment (`for f in
~/.claude/xschem_owed/*/*; do /usr/bin/grep -q '^repo:' "$f" || echo "$f"; done | wc -l`
→ 194 of 194); they had to stay writable or the fix would have bricked the ledger it was
repairing.

**The backfill has since run — 2026-09-10 12:18, by the driver.** Re-measured
**12:41 -0700**: 196 entries, **196 stamped, 0 unstamped**, split **182 this clone / 14
op-wcard** (`find ~/.claude/xschem_owed -maxdepth 2 -type f -exec /usr/bin/grep -h '^repo:'
{} + | sort | uniq -c`). So from **this** clone the refusal now covers all six, and every
barrel below. **From the other clone it covers nothing** — that half is one-sided and is
the subject of *“What was actually done to the ledger”* below. Every count in this
paragraph is a timestamped observation.

**Thirty-five more bare 4-digit rule ids sit inside 1349–1399** — every one a loaded
barrel the moment op-wcard's pointer walks into that band
(`ls ~/.claude/xschem_owed/rule/ | /usr/bin/grep -xE '13(49|[5-9][0-9])'`, count **35**):

```
1351 1352 1353 1354 1355 1357 1358 1360 1362 1364 1365 1366 1368 1369 1370
1371 1372 1373 1374 1375 1381 1382 1384 1385 1387 1388 1389 1390 1391 1393
1395 1396 1397 1398 1399
```

**One of those thirty-five has now fired.** `1351` is in the list above, and it is the
entry overwritten at 10:46:14 — see the next section. The band was not a projection.

**And the fired one was a sample, not an outlier.** Of those 35, **32 are bare 4-digit rule
ids stamped to this branch that sit inside `1354–1399`** — i.e. at or beyond the other
clone's pointer, which read **1354**:

```
1354 1355 1357 1358 1360 1362 1364 1365 1366 1368 1369 1370 1371 1372 1373 1374
1375 1381 1382 1384 1385 1387 1388 1389 1390 1391 1393 1395 1396 1397 1398 1399
```

(`ls ~/.claude/xschem_owed/rule | /usr/bin/grep -xE '13(5[4-9]|[6-9][0-9])'`, each entry
then tested for `repo:/home/analog/dev/xschem-claude`; **32 of 32**, re-measured 2026-09-10
**12:41 -0700**. 69 of the ledger's 134 rule entries carry a bare 4-digit id; 67 of those 69
are this branch's.) The other clone walked 1349→1353 in roughly one number an hour on the
morning of 2026-09-10. **The next 32 numbers it reaches each hold an unanswered ruling of
this branch's, and 1351 is what each of them gets.**

**Renumbering does not repair this.** The ledger is outside both clones, no `git mv`
reaches it, and `owed.sh` has no rename command. It needs its own fix — items **N2** and
**N3** of this batch — and it needs it whether or not anything is ever renumbered.

## A ruling WAS overwritten, at 10:46:14, while this issue was being repaired

An earlier draft of this section was headed *"No ruling has been lost — and that was luck,
not design."* The luck ran out during the batch that wrote it. **Measured 2026-09-10, and
this part is not an inference:**

```
$ cut -f1 ~/.claude/xschem_owed/rule/1351 | head -1 | xargs -I{} date -d @{}
2026-09-10 10:46:14 -0700          <- owed.sh writes `date +%s` on EVERY add
$ stat -c '%y' ~/.claude/xschem_owed/rule
2026-09-10 06:54:10.569645589 -0700
$ ls ~/.claude/xschem_owed/rule | wc -l
132                                 <- 132 at 10:40 too (receipts/N1_ADVERSARY.md:59)
```

A directory's mtime moves when an entry is **created or unlinked**, and not when an
existing file is truncated and rewritten. `rule/` has not moved since **06:54:10**, and the
file count did not change across the window either — yet `rule/1351`'s own timestamp field,
which `cmd_add` rewrites on every write, says **10:46:14**. **So `rule/1351` existed before
10:46:14 and was overwritten in place.** The entry standing there now is op-wcard's
PostScript font-mapping ruling, an `eyes:1` debt whose `ref:` names
`1351-font-attribute-is-a-postscript-name-and-a-format-string.md` — **a file that does not
exist in this tree** — and it carries **no `repo:` line**, so it was written by an `owed.sh`
without the stamping the other clone has not got.

*Labelled as corroboration, not direct observation:* what stood in that slot before is not
recoverable **from the ledger**, because `owed.sh` at HEAD keeps no pre-image. (It was
recovered from a hand-taken `cp -a` backup at 12:18:24 — see *“What was actually done to the
ledger”* — which confirms the identification below to the byte, and which nothing
automates.) Two records
independently say it was **this branch's**. `doc/claude/rdw_batch/LEDGER.md:1107` — *"New
rule debt **1351**, because fix E is a third answer to the question
`1344_the_status_line_receipt_goes_stale` already asks"* — is this branch minting a **bare**
`1351`. And this batch's own adversary receipt, written at 10:40:27, records `rule/1351`
present with a `ref:` path that **resolved here**
(`receipts/N1_ADVERSARY.md:175,178`). Six minutes later it did not.

**This is the defect, firing, in the window between an item and its repair.** It also
retires the strongest reassurance in the earlier draft: the `rule/` directory mtime, cited
below as forensic evidence that nothing was lost, **cannot see an overwrite at all** — it is
evidence about creations and deletions only. Nothing in the ledger reported this; it was
found by re-reading six files during a fix pass.

And it happened **after** item N2 shipped the refusal in this clone, because `rule/1351`
was unstamped legacy and because the other clone runs its own unfixed copy. The driver's
backfill stamping pass is what would have refused it — **it has since run**, and the
scenario was re-run against the stamped ledger both ways: from this clone the same command
is refused at exit 5 with the entry byte-identical; **from the other clone's own script it
still succeeds, at exit 0, destroying the stamp along with the ruling.** Being unstamped was
only half the reason it fired.

### The 1338 case, which is what the earlier draft was about

The bare `rule/1338` that first raised the alarm was **op-wcard's own**, answered and
cleared by op-wcard. Two independent clocks agree to the second:

```
~/.claude/xschem_owed/rule/   mtime  2026-09-10 06:54:10.569645589 -0700
op-wcard transcript                  2026-09-10T13:54:10.581Z  (= 06:54:10 -0700)
    tool result: "DECISIONS.md: RULE-1 answered\nowed: cleared rule debt 1338"
    command ran from cd /home/analog/dev/xschem-op-wcard
```

This branch's 1338 ruling — `rule/1338_R2_every_block_of_the_class_follows`, an `eyes:1`
debt — is untouched and still standing.

**Do not read that as a safety property.** It survived on a naming coin-flip: this tree
happened to suffix its `1338` id and leave `1339` and `1344` bare, and op-wcard happened
to do the opposite for `1339`. Where the coin landed the other way — `1339`, and now
`1351` — the standing entry in the shared ledger is the *other* tree's.

## What was actually done to the ledger — the recovery, the backfill, and `rule/1400`

Three writes to the live shared ledger, all by the **driver** on 2026-09-10 (a crew may not
write it), all verified afterwards by four independent verifier passes whose receipts are in
`doc/claude/numbering_batch/receipts/LEDGER_V{1,2,3,4}_*.md`. **None of this was in the repo
until this section existed** — `/usr/bin/grep -rIn '1351@xschem-claude' doc/claude/issues/`
returned **0** — which is why four statements in this file and in the batch's `LEDGER.md`
asserted the opposite of the ledger's real state until they were corrected with it.

**1 — the destroyed ruling was recovered, at 12:18:24.** The in-place overwrite at
**10:46:14** (evidence in the section above: the entry's own `ts` field against a `rule/`
directory mtime frozen at `06:54:10.569645589` and an unchanged file count of 132 — a
directory mtime moves on a create or an unlink, never on a truncate-and-rewrite) was undone
from `~/.claude/xschem_owed.bak.2026-09-10`, a **hand-taken `cp -a`** whose copy-root ctime
is **09:37:32** that morning. Nothing automates that backup; it existed by habit.

The recovered entry is `rule/1351@xschem-claude`, and it is **byte-faithful**:

```
$ diff ~/.claude/xschem_owed.bak.2026-09-10/rule/1351 \
       ~/.claude/xschem_owed/rule/1351@xschem-claude
2a3,4
> repo:/home/analog/dev/xschem-claude
> repo_via:told
```

The whole diff — the 09:37 file is the first 1450 bytes of the 1500-byte live file, `cmp`
clean. Line 1 (epoch `1788626525` = 2026-09-05 09:42:05 -0700, subject `1351`, the full RDW
driver-decision reason) is intact to the byte, and its
`ref:doc/claude/issues/1351-the-poll-guard-…-outlives-its-text.md` resolves in this tree.
The `@`-suffixed filename is not hand-shaped: it is exactly what `cmd_add`'s namespacing arm
produces, with line 1's subject left as the bare `1351`.

**op-wcard's `rule/1351` was left byte-identical.** Its own diff against the 12:18
pre-backfill backup is the same two stamp lines and nothing else.
**Both 1351 rulings now stand, both are unanswered, and only the user may close either.**
`show` prints both under the heading `1351`; they are told apart by
`filed in another clone: /home/analog/dev/xschem-op-wcard` on the foreign one and by their
differing `clear with:` lines (`clear rule 1351` versus `clear rule 1351@xschem-claude`),
both of which were exercised and work.

**2 — every entry was backfilled with `repo:`/`repo_via:`, append-only.** 195 entries
stamped `repo_via:told`; `rule/1400` was written by the tool itself and is the ledger's
only `repo_via:git`. Verified **append-only in the strongest available form**: for all
**194** entries present in the 12:18 pre-image, the backup file is a byte-exact **prefix**
of the live file (`n=$(stat -c%s bak); head -c "$n" live | cmp -s - bak`) — **194 of 194,
0 violations**, which forecloses a line-1 edit, a dropped key, a reorder and a silent
rewrite in one measurement. Exactly one `^repo:` and one `^repo_via:` per entry, none on
line 1, all 196 still parse, and the *un-upgraded* reader in the other clone neither chokes
on the new lines nor echoes them.

The split is **182 this clone / 14 op-wcard**, re-measured **2026-09-10 12:41 -0700**:

```
find ~/.claude/xschem_owed -maxdepth 2 -type f -exec /usr/bin/grep -h '^repo:' {} + \
  | sort | uniq -c
    182 repo:/home/analog/dev/xschem-claude
     14 repo:/home/analog/dev/xschem-op-wcard
```

It was corroborated by **six methods that do not use the driver's marker rule** — the
op-wcard clone's birth at 2026-09-03 21:49:44 (39 entries predate it and none is stamped
op-wcard), which session was alive within ±30 s of each entry's epoch, the `cwd` of the
Bash call that wrote it, `owed.sh`'s own output line, `ref:` resolution plus `git log` in
both trees, and the two backups' differential — with **zero misattributions and zero
unattributable entries in 196**. The twelve entries no transcript appeared to record were
resolved to a single `for` loop from this clone that redirected `owed.sh`'s stderr.

**3 — `rule/1400` was filed**, `repo_via:git`, its `ref:` resolving to this file. It reads
back through `show` as a ruling, points at the option set below rather than flattening it,
and says in its own text that D-3 is a recommendation and not the answer.
⚠ **It is filed on the bare id `1400`.** That is clean *today* — op-wcard's tail reads 1354
and it has no 1400 issue file — but it is one of the barrels, 46 numbers ahead of a pointer
that moves about one an hour, and it is the single entry in the ledger whose loss would be
self-refuting. Re-siting it as `rule/1400@xschem-claude` is a destroy-and-recreate and
therefore the user's call.

### What the protection is actually worth: it is ONE-SIDED

This is the fact that re-prices every option below, and it is measured, not argued.

| path | today |
|---|---|
| this clone → its own entries | works, pre-image logged to `cleared.log` |
| this clone → op-wcard's 14 entries | **REFUSED, exit 5**, entry byte-identical |
| **op-wcard → this clone's 182 entries** | **destroys them, exit 0, no log, stamp erased** |
| op-wcard → its own entries | works |

An exhaustive sweep — `clear` run from this clone against **all 196** entries in a throwaway
fixture — partitions them **182 cleared / 14 refused, zero misfires in either direction**.
That is the row that works. The row that matters is the third one. The other clone's
`tests/headless/owed.sh` is **the 2026-09-04 script**, `md5
cc88328d6c788c83571435dce7b56a05`, byte-identical to this clone's `git show
HEAD:tests/headless/owed.sh`, and `/usr/bin/grep -c '^repo:\|_entry_repo\|_origin'` on it
returns **0**. Run against the fully-stamped ledger it overwrote `rule/1400` at exit 0
printing `recorded`, reducing a 4-line entry to 1 line and **erasing `ref:`, `repo:` and
`repo_via:` along with the ruling**, and wrote no `cleared.log`. It cleared the recovered
`rule/1351@xschem-claude` at exit 0 as well.

**So the backfill armed the half of the door that was never the problem.** Every refusal
measured above is this session declining to do something it was not going to do. The clone
that actually destroyed a ruling is unaffected by all of it.

**The single thing that makes it mutual** is the repaired `owed.sh` being *present in the
other clone*. It is one self-contained file, no build step, no dependency on anything else
in this batch — a `cp` would do it. **D-1 forbids this batch from touching that tree**, so
it is the user's call and nobody else's. And note the ordering trap:
**the repaired `owed.sh` is still UNCOMMITTED here** (`git status --porcelain
tests/headless/owed.sh` → ` M`, `git diff --numstat` → 531 insertions / 29 deletions),
so **the other clone could not obtain the protection even by pulling.** Committing it is
not forbidden by D-1.

Two consequences worth knowing before reading the options:

* **A backfilled stamp does not decay gracefully.** For as long as the other clone runs the
  old script, every entry it files arrives **unstamped** — and an unstamped entry now means
  something new. Before 12:18 it meant *legacy*; now, with 196 of 196 stamped, it can only
  mean *the other clone's old script just wrote here*. This clone still greets it with
  `… predates origin stamps -- claiming it for xschem-claude` and claims it at rc=0, which
  transfers the other tree's text to this one and erases the one signal that a destroy
  happened. The backfill's coverage is a snapshot that erodes with every new op-wcard debt.
* **`cleared.log` does not exist in the live ledger yet.** It is created lazily on the first
  destroy *by the repaired script*; the old script never writes one. So today there is still
  no audit file at all, and the next loss may well be one that never creates it. **Do not
  delete either backup** (`~/.claude/xschem_owed.bak.2026-09-10` and
  `…bak.2026-09-10.1218`) — they are the only pre-images that exist.

### The limit of the attribution, stated plainly

The 14/182 split is right, and it was checked six ways. But the *rule* the backfill used to
recognise an op-wcard entry is a fingerprint of one op-wcard batch, not a rule, and **the
absorption merge in D-2 is already scheduled to break it**:

* **12 of the 14** foreign stamps rest on a batch-name literal in the entry's id — **11** on
  `hier_pdf_links` and **1** on `test_ps_valid` — and those same 12 carry **no `ref:` at
  all**, so there is nothing to fall back on. op-wcard's next batch names nothing of the
  sort.
* The other **2** (`rule/1339`, `rule/1351`) rest entirely on their `ref:` resolving only in
  op-wcard — **and D-2 measured every colliding issue file as a clean add.** The moment the
  absorption lands, `1339-pdf-link-hotspot-tracks-name.md` exists *here*, that `ref:`
  resolves here, and the marker rule hands op-wcard's 1339 ruling to this clone: the
  "refused on your own ruling" failure, on one of the two rulings that names a collided
  number.
* The two halves **never overlap** — every one of the 14 rests on a single, unreplicated
  signal.

None of that is a defect in today's stamps. It means the backfill is a **one-time bridge
that must not be repeated**: after this, an entry is attributed by `_origin()` at write
time, and an unstamped one is stamped by whoever next touches it, one at a time, by
measurement. If a backfill ever *is* needed again, the discriminator that works is the
`cwd` of the Bash call that produced the entry, matched to its epoch — signal-bearing for
195 of 196, against 14 of 196 for the marker rule. **This issue and the four
`receipts/LEDGER_V*.md` files are the only durable evidence that the 14 are the 14**; the
ledger itself cannot re-derive it, and `repo_via:told` records only that a human asserted
it. (`repo_via` is inert — every ownership decision reads `repo:` — so `told` is not a
confidence level the tool acts on.)

## What this branch did about it

Nothing that moves a number. Item **N1** amended `doc/claude/issues/NUMBERING.md`:

* reserved **`1500–1599`** for the op-wcard branch, with the same skip rule shape the
  three existing reservations use — after **1499**, the next number here is **1600**;
* published the absorption map **`1333–1348` → `1500–1515`** (a single `+167` offset;
  source and target bands are disjoint, so a rewrite cannot alias and the arithmetic is
  checkable by eye) at the head of the file, where whoever performs the absorption will
  meet it;
* annotated the `next free number` pointer at the tail as **per-clone**, because the
  sentence that reads most like an authority is the one that is blind — and mirrored one
  sentence of that caution into the **head** of the file, because the tail copy is inside
  the merge conflict hunk and the head copy is not.

and repointed one paragraph outside it: `doc/claude/ase_analyses_batch/PLAN.md`'s minting
instruction, which named this issue's number, now names none.

Items **N2**/**N3** teach `owed.sh` which clone an entry came from and make cross-origin
`add` and `clear` refuse. Item **N4** amends the CLAUDE.md paragraph that produced this.

## Options, and what each costs

**This is a user ruling, not a crew decision.** `DECISIONS.md` **D-3** records the
recommendation as *unratified*, and `D-1` forbids this batch from touching the tree the
recommendation asks to move. Recorded as a `rule` debt pointing here (`rule/1400`).

**Read all four against the section above, because it re-prices them.** Three facts from it
apply to every option and are not repeated inside each:

1. **The ledger protection is one-sided.** Whichever option is taken, the other clone can
   still destroy any of this branch's 182 entries at exit 0 with no record, and **32
   unanswered rulings of this branch's sit inside `1354–1399`, in front of a pointer that
   read 1354** — so 10:46:14 is a *sample*, not an outlier. **The one thing that makes it
   mutual is the repaired `owed.sh` being present in the other clone**, and that file is
   **still uncommitted here**, so that clone could not get it even by pulling. Committing it
   is not blocked by D-1, costs nothing, and is independent of which option below is chosen.
   **Do it first, whatever is ruled.**
2. **Renumbering does not repair the ledger and can damage it.** `owed.sh` has no rename
   command and no `git mv` reaches `$HOME`. 69 of the 134 rule entries carry a bare 4-digit
   id; 67 of them are this branch's.
3. **After the absorption merge, an entry's clone can no longer be re-derived from the
   tree.** 12 of the 14 foreign stamps rest on one batch's name string and carry no `ref:`;
   the other 2 rest on a `ref:` that resolves only in op-wcard — and the merge takes those
   very files as clean adds, so that signal dies on the day the trees become one. The stamps
   written at 12:18 are the record; nothing regenerates them.

* **(a) op-wcard renumbers `1333–1348` → `1500–1515` at absorption time.** Cost, measured:
  **7 file renames** and **16 NUMBERING bullets** in that tree, and **5 commit subjects**
  — **unpublished**, on op-wcard-side evidence that does not decay:

  ```
  $ git -C /home/analog/dev/xschem-op-wcard rev-parse --abbrev-ref op-wcard@{upstream}
  fatal: no upstream configured for branch 'op-wcard'
  $ git -C … branch -vv | /usr/bin/grep '^\* op-wcard'
  * op-wcard 24e09c65 feat(1338): …          <- no [origin/…] tracking marker
  $ for s in 24e09c65 e451892b 7f8d72a8 743c81d2 18e8e179; do
      git -C … branch -r --contains $s; done   ->  empty for all five
  ```

  An earlier draft cited `git branch -r | /usr/bin/grep wcard` → nothing, of 19, run **in
  this tree** — whose `.git/FETCH_HEAD` is dated 2026-09-04. A six-day-stale remote list
  cannot prove a branch was never pushed; the conclusion was right and the command could
  not carry it. *(Labelled: op-wcard's own remote refs are also from 2026-09-04. Absent a
  `git ls-remote`, "unpublished" rests on the missing upstream config and the missing
  tracking marker, which are local facts.)* Rewriting unpublished subjects is available. Body-text references in
  that tree, as an upper bound including coincidental numeric matches:
  `/usr/bin/grep -rhoE '(^|[^0-9])13(3[3-9]|4[0-8])([^0-9]|$)'` over `doc/claude` **910**,
  `src` **60**, `tests` **449**. It does **not** repair the ledger, and under **D-1** this
  batch cannot perform it — it can only publish the map, which it has.

  **New cost, from the backfill:** renaming `1339-pdf-link-hotspot-tracks-name.md` to
  `1506-…` breaks `rule/1339`'s `ref:`, and the same for `rule/1351`. Those two `ref:` lines
  are the **entire** independent evidence behind two of the fourteen foreign stamps
  (`owed.sh` has no rename), and a `ref:` that resolves in neither tree reads as *this*
  clone's — the wrong direction. So (a) must also re-point those two entries by hand, or
  accept that the two foreign rulings on collided numbers are thereafter attributable only
  by this issue's prose. It is two lines of work; it is invisible if nobody says so.
* **(b) this branch renumbers instead.** Cost, measured: **16 file renames** for the band
  and **10 commit subjects** naming it — and `git merge-base --is-ancestor` says **all ten
  are ancestors of `origin/fluid-editing`**, which currently equals the local tip
  (`2f1fad58`). They are **published**. Worse, the real overlap is not sixteen numbers but
  **sixty-seven**: op-wcard's pointer is already inside `1349–1399`, so a renumbering that
  fixes the problem has to move that band too — **31** commit subjects on this branch name
  something in `1333–1399`, all published, plus the 35 bare ledger ids listed above.
  (`git log --oneline 28dabfe8..fluid-editing | /usr/bin/grep -cE
  '(^|[^0-9])13(3[3-9]|4[0-9]|[5-9][0-9])([^0-9]|$)'` → **31**. An earlier draft said 32,
  from `13[3-9][0-9]`, which spans 1330–1399 and swept in
  `a1e85d3c fix(1332): a $DISPLAY run of the keys suite is a measurement again`.)
  Rewriting published history on the branch the user shares is not a cost this issue can
  price.

  **New cost, from the backfill:** the ledger side of a `1349–1399` move is **32 bare
  4-digit rule ids stamped to this branch inside `1354–1399`** plus 3 more at 1351–1353,
  each an unanswered ruling that `owed.sh` cannot rename. Moving the numbers in the tree
  and leaving the ledger behind produces exactly the chimera this issue is about, with the
  clones the right way round and the numbers wrong.
* **(c) leave both numbering spaces alone and carry a permanent mapping table.** Cost:
  zero today, and it is what the tree does right now by default. But the merged checkout
  then contains sixteen numbers naming two defects each — measured above as **8 files added
  by the merge, 0 conflicts, 16 files carrying 8 duplicated numbers in the result** — and every future reader of a commit subject, a source comment
  (`see doc/claude/issues/1344-…`) or a ledger `ref:` has to know which tree the sentence
  was written in. The table is a document; nothing enforces it, and the thing that would
  have caught the original defect was also a document.

  **New cost, from the backfill, and it is the one that has a clock on it:** (c) is the
  option that spends the longest with both trees live and writing, which is the window the
  losses happen in — one has already happened. It also chooses to keep two ledger entries
  under one number indefinitely (`rule/1351` and `rule/1351@xschem-claude` are the standing
  example, and both are unanswered), and it carries the attribution debt in fact 3 above:
  after the merge, the mapping table plus this issue's prose is the *only* thing that says
  which clone a ruling came from. Zero today is not zero at absorption.
* **(d) ship the `numbers.sh` allocator first, then decide.** A `$HOME` claim registry —
  the actual prevention, and the only option that stops the next collision rather than
  naming this one. A working **264-line** prototype exists and races clean (60 concurrent
  claimants alternating between the two real clones: 60 distinct, 0 duplicates; a 400-claim
  soak the same). Cost: it is **not in either tree** — it lives only in a session scratch
  directory, so today it is one power cut from gone; its adversary broke four things that
  must be fixed before it ships *(inherited from `PLAN.md`, not re-measured here)*; and it
  needs a `test_owed.sh`-grade suite and a spec. It is its own batch. **Under D-1 it also
  changes nothing today** — it only helps once the *other* clone runs it.

  **That last clause is now measured, not predicted.** It is precisely what happened to
  N2's refusal: shipped, correct, exhaustively verified 182/14 with zero misfires, and worth
  nothing against the clone that caused the loss, because that clone runs its own copy. **A
  `$HOME` allocator inherits the same one-sidedness**, so (d) is only worth its cost if the
  *distribution* problem is solved with it — which is the same one-file `cp`/commit named in
  fact 1, done once for `owed.sh` and then never again for anything else that lives in
  `$HOME`.

**The assistant's recommendation, offered and not taken: commit `owed.sh` and get it into
the other clone TODAY (it is not a ruling and not blocked by D-1), then (a), then (d).** (a) because the
published/unpublished asymmetry is not close — ten published subjects against four local
ones, and no remote branch on the tree being asked to move — and because `+167` onto an
empty, disjoint band is the one rewrite whose correctness a human can check by eye.
(d) after it, because (a) is a one-time repair of a defect that will recur on the next
clone, and (c) is (a)'s cost deferred forever rather than avoided. **What (a) explicitly
does not do is fix the ledger**, which is why N2/N3 are in this batch and not waiting on
the ruling.

## What would close this

0. **Not a ruling, and first: commit `tests/headless/owed.sh` and get it into the other
   clone.** It is one self-contained file, no build step. Until it is there, everything
   items N2 and N3 built protects this clone from itself and nothing else, and **32
   unanswered rulings of this branch's stand in front of that clone's pointer**. It is
   still uncommitted here, so the other clone could not obtain it even by pulling. **D-1
   forbids this batch from touching that tree; it does not forbid the commit.**
1. The user rules on (a)/(b)/(c)/(d).
2. If (a): the absorption applies the map published at the head of `NUMBERING.md`, and the
   `1349–1399` overlap is settled at the same time — the map as written covers `1333–1348`
   only, and **it is not the whole exposure**.
3. Independently of the ruling: `owed.sh` refuses a cross-origin `add`/`clear` (N2), the
   suite fences it (N3), and CLAUDE.md stops telling a filer that one tracked file is the
   only authority (N4).
4. ~~**The backfill stamping pass runs.**~~ **DONE, 2026-09-10 12:18, by the driver** —
   196 of 196 entries stamped, append-only against a byte-exact prefix check on all 194
   pre-existing ones, split 182/14 with zero misattributions. See *“What was actually done
   to the ledger”*. **What replaces it:** the repaired `owed.sh` is **committed and present
   in the other clone**. Until then the stamps protect this clone from itself and nothing
   else, and the coverage erodes with every entry the other clone's old script writes.
5. ~~**`rule/1351` is answered as two rulings, or one of them is re-raised.**~~ The half
   that was missing is **DONE, 2026-09-10 12:18:24** — this branch's RDW ruling was
   recovered byte-faithfully from the 09:37 backup and stands as
   `rule/1351@xschem-claude`. **Both 1351 rulings are now in the ledger and BOTH ARE
   UNANSWERED**, op-wcard's font-mapping question under `rule/1351` and this branch's RDW
   question under `rule/1351@xschem-claude`. **This condition closes when the user answers
   them** — a rule debt clears only when the user says so, and no green suite finds either.

Nothing here is closed by a green suite. The band reservation and the map are prose in a
file; the thing that failed last time was also prose in a file.
