> **SUPERSEDED IN PART, 2026-09-10 13:40 -0700. Nothing below is edited — this is a
> receipt, and its findings are what was true at 11:25.** Four of its readings have since
> moved, and a reader must not quote them as current:
>
> * *"the real ledger — no backfill has run"*, *"194 / 0 stamped"* (§ and the closing
>   list). The backfill ran at **12:18**. The ledger now holds **198** entries, **194**
>   stamped, split **181** this clone / **13** op-wcard; four entries are unstamped and
>   that now means something new — see below.
> * *"issue 1400 is **519** lines"* (N1-F10 row, and the summary). It was **536** when
>   that was typed and is **792** after the second repair round.
> * *"the six collided bare rule ids"* and *"the 35 loaded barrels"* — 13 numbers now
>   collide and the barrels in 1354–1399 stand at **31**, because two of them have
>   already fired.
> * **The headline finding of this batch's first audit is retired.** A ruling had not
>   been lost when this receipt was written. Two have been lost since — `rule/1351` at
>   **10:46:14** and `rule/1357` at **13:25:32**, both this branch's, both overwritten
>   in place by the other clone's 2026-09-04 `owed.sh`, both recovered from a hand-taken
>   backup. Neither event moved a directory mtime or a file count, which is why nothing
>   reported them and why an audit of this ledger is only ever true as of its own clock.
>
> Current state lives in `../LEDGER.md` and `doc/claude/issues/1400-*.md`.

# CLOSEOUT — close-out verification of the four adversary fix lists

*Read-only pass over the repo. The only file this pass wrote is this one.
2026-09-10, 11:20–11:35 -0700. Every count with `/usr/bin/grep`; the command is
beside the number. Fixtures under
`/tmp/claude-1000/-home-analog-dev-xschem-claude/1e23e38a-…/scratchpad/closeout`.
op-wcard read-only; the real ledger read, never written; no binary launched; no
`git checkout/restore/stash/clean/commit/push`.*

**The collision was still growing while this was verified.** At **11:25:18 -0700 on
2026-09-10** the per-number filename compare across the two clones returned **twelve**
numbers — 1338, 1339, 1344–1353 — and op-wcard's working `next free number` read
**1354** while its *committed* one read **1350**. Five of the twelve (1349–1353) were
filed by the other clone during this batch's own run, and that clone's session was
**live during this pass** (`ps` at 11:29:31 shows its `src/xschem --nogui --pipe`
running `test_ps_valid_1350.tcl`). No count in this file is a standing fact.

```
for f in doc/claude/issues/[0-9][0-9][0-9][0-9]-*.md; do b=$(basename $f); n=${b%%-*}
  o=$(ls /home/analog/dev/xschem-op-wcard/doc/claude/issues/$n-*.md 2>/dev/null|head -1)
  [ -n "$o" ] && [ "$(basename $o)" != "$b" ] && echo $n; done | sort -u | wc -l
->  12      (at 2026-09-10 11:25:18 -0700, still growing)
```

---

## 1. The four blocking reproductions — mine, before and after

I built every fixture myself. I reused nothing from the crews. **No mutation touched
the working tree**: `md5sum` on `tests/headless/owed.sh` and `tests/headless/test_owed.sh`
is byte-identical at the start and the end of this pass (see §5).

### N2-F1 — a plain no-flag foreign `add` when two clones share a directory basename

Fixture: two real `git init` clones, `…/closeout/fix/p1/xschem` and
`…/closeout/fix/p2/xschem` — **same basename, different parents** —
`XSCHEM_OWED_DIR=…/closeout/fix/state`.

| | command | result |
|---|---|---|
| **BEFORE** (HEAD's `owed.sh`, no origin code) | `p2 … add rule 1344 'P2 unrelated question'` | `owed: recorded rule debt: 1344`, **exit 0**; entry now reads `P2 unrelated question`; `md5sum -c` → **FAILED** |
| **BEFORE** (pre-repair comparator, reconstructed) | same | `owed: updated rule debt: 1344 (id 1344, clone xschem)`, **exit 0**; P1's ruling gone, **P1's stamp still on the file** |
| **AFTER** (shipped `owed.sh`) | same | `!! owed REFUSED: rule 1344 belongs to another clone -- NOTHING written`, **exit 5** |

The pre-repair reconstruction is a three-anchor mutation of the *shipped* file that
puts the tag-tolerant compare back (`diff` shows exactly `:499`, `:512`, `:726`), so
before and after differ only in the comparator:

```
elif [ "$st" = "$repo" ]            ->  elif [ "$(_repo_tag "$st")" = "$(_repo_tag "$repo")" ]
[ -n "$standing" ] && [ "$standing" != "$repo" ]   ->  tag compare
[ "$st" = "$want" ] || _refuse                     ->  tag compare
```

Proof the standing entry is untouched after the refusal:

```
md5sum -c …/closeout/fix/pre1344.md5
->  …/fix/state/rule/1344: OK
ls -1 …/fix/state/rule/     ->  1344      (nothing filed beside it)
```

**CLOSED.**

### N2-F2 — `--repo here` reaching another clone's entry

| | command | result |
|---|---|---|
| **BEFORE** (pre-repair comparator) | `p2 … clear rule 1339 --repo here` | `owed: cleared rule debt 1339`, **exit 0** — entry **DESTROYED** |
| **AFTER** | `p2 … clear rule 1339 --repo here` | `!! owed REFUSED: rule 1339 is filed in …/p1/xschem, not …/p2/xschem -- NOT cleared`, **exit 5**; `md5sum -c` → **OK** |
| **AFTER** | `p2 … add rule 1339 'P2 overwrites via here' --repo here` | `owed: recorded rule debt: 1339 (id 1339@xschem, clone xschem)`, exit 0 — files its **own** slot; the bare slot's `md5sum -c` → **OK** |

**CLOSED.**

### N4-F1 — the mint check must see a reserved band

Block extracted verbatim from `CLAUDE.md` and piped to `sh` with only `n=` substituted:

```
awk '/^N=doc\/claude\/issues\/NUMBERING.md/{f=1} f{print} f&&/^\/usr\/bin\/grep -lw/{exit}' CLAUDE.md
```

| n | BEFORE (the first-pass per-number grep alone) | AFTER (the shipped two-check block) |
|---|---|---|
| **1550** | `ls` silent, `/usr/bin/grep -lE …` silent, **rc=1 — reads as FREE** | `!! 1550 is in RESERVED band 1500-1599`, every grep silent |
| 0550 | — | `!! 0550 is in RESERVED band 0500-0599` |
| 1401 | — | band check silent; only this clone's own `NUMBERING.md` |
| 1349 | — | **two issue files and two `NUMBERING.md`s**, both clones |

**CLOSED.**

### N3-F1 — the O33 R502 row must go red under m5

m5 built on a **copy** of `owed.sh` (`_log_gone` appends the pre-image to
`$HERE/cleared.log` *in addition to* the state-dir log), driven through `OWED_SH`.
A control copy of the same file, unmutated, at the same depth, isolates the mutation.

| suite | `owed.sh` under test | verdict |
|---|---|---|
| current `test_owed.sh` | unmutated control copy | `RESULT: ALL PASS (233 checks, 1 skipped)` |
| current `test_owed.sh` | **m5** | `RESULT: 1 FAILED (232 passed, 1 skipped)` — `FAIL: O33 ...and nothing was written outside the state dir (R502) -> {5} (exp {0})` |
| **old row restored** (`ls -1 "$FX" \| $GREP -c cleared.log`) | **m5** | `RESULT: ALL PASS (233 checks, 1 skipped)` — the row could not fail |

The stray file is real: `…/closeout/m5/tests/headless/cleared.log`, 1836 bytes.
Restore: every mutation ran on a `cp` copy; the working tree was never written.

```
md5sum -c …/closeout/tree.md5
->  tests/headless/owed.sh: OK
->  tests/headless/test_owed.sh: OK
```

**CLOSED.**

---

## 2. Finding-by-finding table

Severity as the adversary labelled it; where it labelled none, my read is marked *(mine)*.

### N1 — `NUMBERING.md`, issue 1400

| id | severity | status | command that proves it |
|---|---|---|---|
| N1-F1 | HIGH | **CLOSED** | `/usr/bin/grep -c 'six clean adds' doc/claude/issues/1400-*.md` → 0; `/usr/bin/grep -c 'all sixteen' doc/claude/issues/NUMBERING.md` → 0; the merge result is now stated identically at `1400:198`, `1400:475` and `NUMBERING.md:3013` — **8 files added, 0 conflicts, 16 files carrying 8 duplicated numbers** |
| N1-F2 | HIGH | **CLOSED as scoped; residue open** | `/usr/bin/grep -rn 'add rule 1400' .` → 0 hits outside the batch's own receipts. Residue: `doc/claude/ase_analyses_batch/` still names **1400** as the next free number in 6 places (`PLAN.md:31`, `LEDGER.md:164`, `README.md:177`, `CREW_BRIEF.md:143`, `evidence/ase-conventions.md:129,148`) — see contradiction **C6** |
| N1-F3 | MEDIUM | **CLOSED** | `/usr/bin/grep -c 'seven numbers' doc/claude/issues/NUMBERING.md` → 0; `/usr/bin/grep -c '51 more' …` → 0; `NUMBERING.md:26-29` and `:3005` now carry `2026-09-10 10:46 -0700`, twelve, and tail **1354** |
| N1-F4 | MEDIUM | **CLOSED** | `for n in 1337 1339 1344 1351 1352 1353; do [ -e ~/.claude/xschem_owed/rule/$n ]; done` → all **PRESENT** (six); `ls -1 ~/.claude/xschem_owed/rule/ \| /usr/bin/grep -xE '13(49\|[5-9][0-9])' \| wc -l` → **35**; `/usr/bin/grep -rl '^repo:' ~/.claude/xschem_owed \| wc -l` → **0**, so the refusal covers none of them |
| N1-F4b (new) | HIGH *(mine)* | **CONFIRMED — the defect fired live** | `cut -f1 ~/.claude/xschem_owed/rule/1351` → `1789062374` (**10:46:14**); `stat -c '%y' ~/.claude/xschem_owed/rule` → `2026-09-10 06:54:10.569645589` (a dir mtime cannot see an in-place rewrite, so the file pre-existed); its body is op-wcard's PostScript-font ruling and its `ref:` **dangles here** (`[ -e doc/claude/issues/1351-font-attribute-…md ]` → false) |
| N1-F5 | MEDIUM | **CLOSED** | `/usr/bin/grep -oE '13[0-9]{2} → 15[0-9]{2}' doc/claude/issues/NUMBERING.md \| awk …` → `pairs=16 bad=0 uniq_src=16 uniq_dst=16` |
| N1-F6 | MEDIUM | **CLOSED** | `/usr/bin/grep -cE 'PER-CLONE' doc/claude/issues/NUMBERING.md` → **2** (was 1); the head copy is at `:56`, above the merge hunk |
| N1-F7 | LOW | **CLOSED** | `git log --oneline 28dabfe8..fluid-editing \| /usr/bin/grep -cE '(^\|[^0-9])13(3[3-9]\|4[0-9]\|[5-9][0-9])([^0-9]\|$)'` → **31**; the loose `13[3-9][0-9]` still gives 32. `1400:465` says 31 |
| N1-F8 | LOW | **CLOSED** | `/usr/bin/grep -c '09:44:06' doc/claude/issues/1400-*.md` → 4; the single `09:52` left (`:123`) is the sentence retracting it |
| N1-F9 | LOW | **CLOSED** | `/usr/bin/grep -n '~~' doc/claude/issues/NUMBERING.md` → `76 107 263 851 1013 1017 1051 3027` — the citation is now the command, not line numbers |
| N1-F10 | LOW | **CLOSED** | `wc -l < doc/claude/issues/1400-*.md` → **519**; `/usr/bin/grep -c '\*\*519\*\* lines' doc/claude/numbering_batch/LEDGER.md` → 1 |
| N1-F11 | LOW | **CLOSED** | `/usr/bin/grep -c 'no upstream configured' doc/claude/issues/1400-*.md` → 1 (the op-wcard-side evidence is now what is quoted) |
| N1-F12 | LOW | **CLOSED** | `sed -n '17,18p' doc/claude/issues/NUMBERING.md` → the two-line filing sequence covering all four blocks, `… 0998 0999 1200 1201 … 1498 1499 1600 1601 …`; the head table reads **Four blocks are reserved** |

### N2 — `owed.sh`, `specs/owed.md`

| id | severity | status | command that proves it |
|---|---|---|---|
| N2-F1 | **BLOCKING** | **CLOSED** | §1 above — same-basename fixture, `add rule 1344` from the second clone → **exit 5**, `md5sum -c` **OK**, nothing filed beside it. `/usr/bin/grep -n '_repo_same' tests/headless/owed.sh` → **no hits** (the tolerant comparator is deleted) |
| N2-F2 | **BLOCKING** | **CLOSED** | §1 above — `clear … --repo here` → exit 5, entry `md5sum -c` **OK**; `add … --repo here` files `1339@xschem` and leaves the bare slot byte-identical |
| N2-F3 | HIGH *(mine)* | **CLOSED, and widened** | `p2 … add rule 2001 … --repo notaclone` → `!! owed ERROR: --repo 'notaclone': no entry … is stamped to a clone by that name`, **exit 2**, nothing written. Ambiguous tag (both clones stamped `xschem`): `--repo xschem` → **exit 2**, **both candidates named**. And the refusal's own hint switches to the full path once the tag is ambiguous (measured) |
| N2-F4 | RULING (user's) | **CLOSED as ruled** | `p2 … show \| /usr/bin/grep -c -- '--repo'` → **0**; `show` prints the plain `clear rule 1339` and names the owning clone; running that verbatim is refused, exit 5 |
| N2-F5 | latent | **CLOSED** | entry whose last line is `repo:…` with no `\n`: `list` prints `from: …/p1/xschem   (another clone)` **and** `clear` refuses, exit 5 — one answer, two readers |
| N2-F6 | latent | **CLOSED** | `add rule 9001 "$(printf 'B claims this\nrepo:…')"` → `!! owed ERROR: a newline in the subject, the reason or the ref would forge a field`, **exit 2**, nothing written |
| N2-F7 | latent + spec overclaim | **CLOSED** | fixed in code, not softened in prose; pinned by `test_owed.sh` O39's `a linked worktree whose git is gone still clears its CLONE's entry` — `ok:` in the full run |
| N2-F8 | minor | **CLOSED** | state-dir `cleared.log` made unwritable → `!! owed ERROR: rule '1344' NOT cleared: the pre-image could not be recorded`, **exit 3**, **entry KEPT** |
| N2-F9 | — | **CLOSED** | `sed -n '339,340p' doc/claude/specs/owed.md` → both readings dated (192 at 10:05, 194 at 10:54), not frozen into the requirement |
| N2-F10 | — | **CLOSED by N3** | the same-basename third clone is mandatory in `owed.md:501` and implemented as O35/O36 — see the suite verdict in §3 |
| N2 cross-item 4 | — | **NOT CLOSED** *(nobody owns it)* | `stat -c '%y' doc/claude/lookdebt_batch/build_page.py` → **2026-09-07 17:49**; `:52` still emits a bare `owed.sh clear look %s`. Harmless today (0 of 194 entries stamped) and correctly declared out of scope by both N2 and N3 |

### N3 — `test_owed.sh`

| id | severity | status | command that proves it |
|---|---|---|---|
| JOB A (driver) | BLOCKING | **CLOSED** | O29 realigned and O35/O36 added; the suite's own RED against the pre-repair `owed.sh` was `40 FAILED`, and my independent fixture reproduces the same defect and the same fix (§1) |
| N3-F1 | MEDIUM *(mine)* | **CLOSED** | §1 — old row `ALL PASS (233)` under m5, new row `1 FAILED`, and the failing row is the one named for the job |
| N3-F2 | LOW *(mine)* | **CLOSED as declared** | the run's own banner: `env:  O13's live arm did NOT run, and a skip is NOT a pass …`, and `skip: O13 (…). NOT COVERAGE.` Closing it any other way would mean launching the binary, which the batch forbids |
| N3-F3 | LOW *(mine)* | **CLOSED** | both numbers reproduce: `ALL PASS (233 checks, 1 skipped)` with git; with a `git` shim that exits 1, `ALL PASS (228 checks, 3 skipped)` plus `skip: O24 …` and `skip: O39 …` |
| N3's own F2 (`add --repo <theirs>` replaces their `ref:`) | — | **OPEN BY DESIGN** | still live in `owed.sh`, deliberately unpinned by any check so whoever fixes it is not fighting a test. Recorded in both receipts; **N2's file** |

### N4 — `CLAUDE.md`

| id | severity | status | command that proves it |
|---|---|---|---|
| N4-F1 | MEASURED / HIGH *(mine)* | **CLOSED** | §1 — `n=1550` → `!! 1550 is in RESERVED band 1500-1599` |
| N4-F2 | MEDIUM | **CLOSED** | the block's first two lines source `n` from the pointer: `/usr/bin/grep 'next free number' "$N" \| /usr/bin/grep -v '~~' \| tail -n1` → `**The next free number is 1401.**` |
| N4-F3 | MEDIUM | **CLOSED** | the glob guard is in the shipped block: `set -- ~/dev/*/…/NUMBERING.md` + `[ -e "$1" ] \|\| echo "!! glob matched nothing …"`, and the scope limit is stated in the prose |
| N4-F4 | MEDIUM | **CLOSED** | the block prints `/usr/bin/grep -lw "$n" "$@"`; run at `n=1349` it returns **four** paths across both clones |
| N4-F5 | MEDIUM | **CLOSED** | `/usr/bin/grep -c 'no `repo:` line is not protected' CLAUDE.md` → 1, with the dated 194/0-stamped reading beside it — which the live ledger still confirms (`/usr/bin/grep -rl '^repo:' ~/.claude/xschem_owed \| wc -l` → 0) |
| N4-F6 | LOW | **CLOSED** | `/usr/bin/grep -c 'cleared.log' CLAUDE.md` → 1 |
| N4-F7 | MEDIUM | **CLOSED** | `sed -n '507,509p' CLAUDE.md` → `0500–0599` named as **the fluid-editing branch, i.e. this one**, with the retraction in parentheses |
| N4-F8 | LOW | **CLOSED** | `/usr/bin/grep -n -- '--repo <clone>' CLAUDE.md` → **:247**, inside the usage block at `:237-248` |
| N4-F9 | LOW | **CLOSED** | correction box present in `receipts/N4.md` §4 |
| N4-F10 | LOW | **CLOSED** | `CLAUDE.md:462-470` is date-**and**-time stamped and says the set was still growing; it adds *"Any count in this paragraph is a timestamp, not a standing fact"* |

**Nothing is DISPUTED by this pass.** Two findings were *corrected by measurement*
before being applied (N1-F2's premise, N1-F4's attribution) and both corrections
made the finding stronger; I re-took both and agree with the correction.

---

## 3. `tests/headless/test_owed.sh`, run whole, by me

```
cd /home/analog/dev/xschem-claude
env -u DISPLAY OWED_TEST_DISPLAY=none GUI_GATE=0 bash tests/headless/test_owed.sh
```

Verdict line, verbatim:

```
RESULT: ALL PASS (233 checks, 1 skipped)
```

`/usr/bin/grep -c '^FAIL'` → **0**. 3.30 s. One skip, `O13 (OWED_TEST_DISPLAY=none --
asked not to start the binary). NOT COVERAGE.` No stray `/tmp/owedtest.*` afterwards
(`ls -d /tmp/owedtest.* | wc -l` → 0). With a `git` shim that exits 1:
`RESULT: ALL PASS (228 checks, 3 skipped)`.

---

## 4. Internal contradictions still standing

| # | where | what disagrees | severity |
|---|---|---|---|
| **C1** | `doc/claude/issues/1400-…md:143`, `:145`, `:155` | The section heading **"The forward exposure: fifty more, already queued"**, the sentence *"op-wcard's tail said next free 1349 when this batch was scoped, and says **1350** now"*, and *"**50 remain queued**"* — all undated. They contradict `1400:94` (*"op-wcard's tail read **1354** when this was written"*) and `1400:258` (*"four numbers behind its own working tree, which read `1354`"*), and the tree: at 11:25 five of the 51 have collided, so **46** remain and the working tail is **1354**. `1350` is true only of the *committed* tail and is not labelled as such. **This is the batch's signature defect — one number three ways — surviving in the one file that will be committed.** | **MEDIUM** — tracked-to-be-committed text |
| **C2** | `receipts/N3.md:558` and the `LEDGER.md` N3 row | Both say the `test_owed.sh` diff is *"742 insertions(+), 3 deletions(-), 353 → 1092 lines"*. Measured: `/usr/bin/git diff --numstat tests/headless/test_owed.sh` → **750 3**, `wc -l` → **1100**. Self-consistent (353+742−3=1092) but eight lines behind the file it describes — the receipt was written at 11:19, the file at 11:16, and the figure was not re-taken | LOW |
| **C3** | `receipts/N4.md:147-151`, `:345-348`, and the `LEDGER.md` N4 row's last sentence | All assert `NUMBERING.md:3016-17` *"still reads 'seven numbers naming two defects each … 51 more'"* and ask the driver to make it say **8 and 50**. Measured now: `/usr/bin/grep -c 'seven numbers' …` → **0**, `'51 more'` → **0** — N1 fixed it at ~11:00, after N4's 10:54 receipt. And **8/50 are themselves superseded**: the answer is twelve, and 46 of 51 queued | LOW–MEDIUM (receipts only, but it tells a future reader to re-introduce a wrong number) |
| **C4** | `receipts/N2.md:472-480` | *"Three fail today"* — the three O34 `show`/`--repo` rows. N3 turned them round into O34b at ~11:16; the suite is at 0 FAIL. Stale note, correctly handed off and correctly acted on | LOW |
| **C5** | `tests/headless/owed.sh:328` | A bare, undated *"the live ledger is 192 of them"*, against `:284`'s dated *"192 were standing at 10:05 on 2026-09-10"* and `owed.md:339-340`'s **194 at 10:54**. Same file, two readings, one of them presented as a constant. It is a performance rationale, not a claim about the collision | LOW |
| **C6** | `doc/claude/ase_analyses_batch/` (untracked, **being written right now** — five files touched 11:27–11:29) | Still names **1400** as the next free number in six places (`PLAN.md:31`, `LEDGER.md:164`, `README.md:177`, `CREW_BRIEF.md:143`, `evidence/ase-conventions.md:129,148`) while `NUMBERING.md` now says **1401** and 1400 is filed. `evidence/ase-conventions.md:47` and `:153` also still quote the **retired** rule verbatim (*"`NUMBERING.md` is the ONLY authority. Read its tail."*). N1 fixed only the two `owed.sh add rule 1400` lines it was granted. **This is issue 1400's own thesis reproducing inside one clone, live, while this was being written** | MEDIUM — out of batch scope, but it is the next collision |
| **C7** | `LEDGER.md` N1 and N4 rows | Each cell states the **pre-repair** figure first (N1: *"issue 1400 filed (296 lines)"*, *"the merge takes 16 colliding files as clean adds"*; N4: *"the collisions are 8 … the queue is 50"*) and the corrected figure later in the same cell. Documented supersession, not an error — but a reader skimming the first half of the row takes away the wrong number | LOW |

Everything else reconciles. Specifically checked and **consistent** across issue 1400,
`NUMBERING.md`, `CLAUDE.md` and the receipts: the merge result (8 adds / 0 conflicts /
16 files / 8 duplicated numbers), the collision count (**12**, dated everywhere it
appears), op-wcard's tail (**1354** working, **1350** committed, distinguished where it
matters), the next free number (**1401**), the reserved band (**1500–1599**, "Four
blocks"), the commit-subject count (**31**), `24e09c65` at **09:44:06**, issue 1400 at
**519** lines, the six collided bare rule ids, the 35 loaded barrels, and the ledger at
**194 / 0 stamped**. Five of the six owned files carry the date-and-time-stamped,
still-growing phrasing (`NUMBERING.md`, issue 1400, `CLAUDE.md`, `owed.sh`,
`test_owed.sh`); `owed.md:98-103` carries it too.

---

## 5. Boundaries

**`/home/analog/dev/xschem-op-wcard` — not written by this batch.**
`/usr/bin/git -C … status --porcelain` now shows **more** than the receipts recorded:
` M doc/claude/hier_pdf_links_batch/{CREW_BRIEF,DECISIONS,LEDGER}.md`,
` M doc/claude/issues/NUMBERING.md`, ` M src/psprint.c`, ` M src/save.c`, and untracked
`hier_pdf_links_batch/{H5_look.png, audit_H5_*.txt, receipts/H5.md, *.log}`,
`doc/claude/issues/135{0,1,2,3}-*.md`, `tests/headless/test_ps_valid_1350.tcl`.
**All of it is that clone's own H5 PDF-links work, and its session is live**
(`ps` at 11:29:31: `./src/xschem --nogui --pipe -q --script tests/headless/test_ps_valid_1350.tcl`,
plus a helper out of `/tmp/claude-1000/h5work/pretree`). The decisive negatives:
its `tests/headless/owed.sh` and `test_owed.sh` are both still dated **2026-09-04
06:55:36**; `doc/claude/numbering_batch` does not exist there; its `NUMBERING.md` diff
is **101 insertions / 6 deletions**, 16 of the added lines naming `1350`–`1353`, i.e.
its own filings. **D-1 holds.**

**The real ledger — no backfill has run, exactly as expected.**

```
for k in rule look suite; do ls -1 "$HOME/.claude/xschem_owed/$k" | wc -l; done   -> 132 / 53 / 9   (194)
ls -1a $HOME/.claude/xschem_owed                                  -> . .. look rule suite
/usr/bin/grep -rl '^repo:' $HOME/.claude/xschem_owed | wc -l      -> 0
find $HOME/.claude/xschem_owed -name cleared.log -o -name '.rewrite.*' | wc -l   -> 0
stat -c '%y' $HOME/.claude/xschem_owed        -> 2026-09-02 03:12:39
stat -c '%y' $HOME/.claude/xschem_owed/rule   -> 2026-09-10 06:54:10.569645589
```

**No `repo:` stamp, no `cleared.log`, no `.rewrite.*`.** The `rule/` directory mtime is
still frozen at 06:54:10, so nothing was created or removed in it by any batch item or
by me. The counts have moved (132/51/8 at the 08:19 baseline → 132/53/9 now); `look/`
and `suite/` carry mtime **10:46:33**, the other clone's session writing its own debts.
The one in-place rewrite — `rule/1351` at **10:46:14** — is N1-F4b above and is that
clone's unfixed `owed.sh`, not this batch's.

**`~/.xschem/` — not touched by this batch.** Newest writes are `geometry` 11:12:01,
`op_annot` 11:08:06, `simulations/{clean,short}.spice` 11:04:54, `.clipboard.sch`
11:04:56 — all inside the op-wcard session's live run window, from its own binaries.
`recent_files` is unchanged at **2026-09-09 21:53:48**, so the 0924 hazard did not fire.

**`/home/analog/dev/xschem-claude` — only batch-owned files changed.**

```
 M CLAUDE.md                                  (N4)
 M doc/claude/issues/NUMBERING.md             (N1)
 M doc/claude/specs/owed.md                   (N2)
 M tests/headless/owed.sh                     (N2)
 M tests/headless/test_owed.sh                (N3)
?? doc/claude/issues/1400-…md                 (N1, new)
?? doc/claude/numbering_batch/                (the batch)
?? .xschem/  ?? doc/claude/rdw_lists_batch/  ?? doc/claude/rdw_sim_batch/
?? sky130A/…/debug_st1/                       (all four pre-date the batch)
?? doc/claude/ase_analyses_batch/             (pre-dates the batch; N1 edited two lines
                                               of its PLAN.md under a driver grant, and
                                               ANOTHER SESSION wrote five of its files
                                               at 11:27–11:29 today — see C6)
```

Five tracked files modified, one tracked file added, one file outside the item map
(`ase_analyses_batch/PLAN.md`, driver-granted, two lines, verified minimal:
`/usr/bin/grep -c 'add rule 1400'` → 0 and no `1400` left in that file's minting step).

**My own footprint.** Every fixture, mutation and copy lives under
`…/scratchpad/closeout`. Working-tree md5s are identical at the start and the end of
this pass: `owed.sh 678d663752c4186b8f26933774fe6a42`,
`test_owed.sh 26e099c36bc567e4996e7113aa2d823d`, `CLAUDE.md 95eed77b72613380c0792ae92272a5b8`,
`NUMBERING.md f5cde805262b73bb1388deb340859dcb`, `owed.md e5c5ad5b3f1329428c2d71a7ac2467f3`,
`1400-…md 0c6b71169fafb7ad7bda13fca8451aec`.

---

## 6. Still owed after the commit (not blockers, but nobody has them)

* The **`rule` debt on issue 1400** is still unrecorded — a crew may not write the real
  ledger. It must **not** go in under the bare id `1400`: check
  `~/.claude/xschem_owed/rule/1400` first, then use `--repo here` or a suffixed id.
* The **backfill stamping pass** over all 194 entries. Until it runs, N2's refusal
  protects nothing: 0 of 194 are stamped, and `rule/1351` shows what that costs.
* The **overwritten RDW ruling behind `rule/1351`** — a question the user never saw.
  Recovering or re-raising it is a driver action.
* Under **D-1**, op-wcard's pointer is still aimed into `1349–1399`. Unfixable from here,
  and said so rather than worked around.

---

**NOT READY** — one repair, then ready.

`doc/claude/issues/1400-…md` §"The forward exposure" (**C1**, lines 143, 145, 155) still
states op-wcard's tail and the queue three ways inside one file, undated, contradicting
its own `:94` and `:258` and the tree. It is the only defect I found in text that this
commit publishes, and it is the exact class this batch exists to eliminate. Fix the
heading, the *"says **1350** now"* sentence (say **committed 1350 / working 1354, as of
`<time>`**) and *"50 remain queued"* (**46 as of 2026-09-10 11:25 -0700, and shrinking**),
then commit.

Everything else — all four blocking findings, the whole 233-check suite, both clone
boundaries, the real ledger and `~/.xschem/` — is verified closed by measurement above.
**C2 and C3 are receipt-only and can be corrected in the same pass or left with this
file standing as the correction of record.**
