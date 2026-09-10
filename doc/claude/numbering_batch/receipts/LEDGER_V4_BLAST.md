# SOUND WITH FIXES

**V4 — blast radius of the 12:18 stamping pass.**
Pass run 2026-09-10 **12:20:22 → 12:31:28 -0700**. The live ledger was read only.
`diff -rq /home/analog/.claude/xschem_owed <my 12:20 cp -a>` → **IDENTICAL** at
12:31:28: it did not move during my pass and I did not write it. Everything that
exercises `owed.sh` below ran against a `cp -a` copy under
`XSCHEM_OWED_DIR=/tmp/claude-1000/…/scratchpad/…`. The binary was never launched
(`OWED_TEST_DISPLAY=none`, stub `run_suites.sh` for every drain).
`/home/analog/dev/xschem-op-wcard` was **read** — never written; its `owed.sh` and
`test_owed.sh` still stat at 2026-09-04 06:55.

Every count below names the command behind it. All greps are `/usr/bin/grep`.

---

## 0. What the ledger actually is now (snapshot 12:20:22, re-taken 12:31:28, unchanged)

| | rule | look | suite | total |
|---|---|---|---|---|
| entries (`ls <k> \| wc -l`) | 134 | 53 | 9 | **196** |
| stamped (`/usr/bin/grep -l '^repo:' <k>/* \| wc -l`) | 134 | 53 | 9 | **196 — 100 %** |

`cat rule/* look/* suite/* \| /usr/bin/grep '^repo:' \| sort \| uniq -c`
→ **182** `/home/analog/dev/xschem-claude`, **14** `/home/analog/dev/xschem-op-wcard`.
`… '^repo_via:' …` → **195 `told`**, **1 `git`**.

**The driver's "195 / 14 / 181" reconciles exactly.** The 12:18 backup holds 194
entries; +`rule/1351@xschem-claude` (recovered) = the **195** stamped `told`;
`rule/1400` was filed by `owed.sh` itself and is the single `git` one. 181 `told`
entries are this clone's, +1400 = the 182 measured.

**Integrity of the stamping pass — measured, not inferred.**
* Append-only: for all **194** entries in `xschem_owed.bak.2026-09-10.1218`, the
  backup file is a byte-exact **prefix** of the live file (`diff <(head -n $(wc -l
  < bak) live) bak` over every entry → **0 not-a-prefix, 0 missing**).
* Every entry has exactly **one** `^repo:` and exactly **one** `^repo_via:`; none on
  line 1; all 196 end with a newline; the last line of all 196 is `repo_via:`.
  (So no stamp was glued onto an unterminated `ref:` — the O38 hazard did not fire.)
* `owed.sh list` over the copy emits **0** `skipping unreadable entry` warnings:
  all 196 still parse.
* The recovery is faithful: `rule/1351@xschem-claude` is byte-identical to
  `xschem_owed.bak.2026-09-10/rule/1351` plus the two stamp lines.
* No `cleared.log`, no `.rewrite.*` (`ls -a` of the state dir → `. .. look rule suite`).

Nothing in this section is a fix request. It is the baseline the rest is measured against.

---

## 1. Quoted `owed.sh` commands in the tree

`/usr/bin/grep -rIn 'owed\.sh[[:space:]]\+clear' --exclude-dir=.git --exclude=owed.sh --exclude=test_owed.sh .`
→ **62 lines across 27 files** (per-file counts summed with `grep -rIc … | awk`).
The earlier pass's "54 lines / 24 files" was a smaller tree; **27 files** is today's number.

Of those 62, **39** carry a concrete id and are therefore runnable. Each was
evaluated against the stamped copy, honouring any `--repo` on the same line:

| outcome | count | which |
|---|---|---|
| **EXIT 0, works** | **4** | `clear rule 1344` (bare, at `N2.md:444`), `clear rule 1344 --repo xschem-claude` ×2 (`N2.md:153`, `:451`), `clear rule 0643` (`N3_ADVERSARY.md:174`) |
| **EXIT 5, refused — NEW** | **2** | both are `clear rule 1339`: `issue 1400:331` (bare) and `N2.md:145` (`--repo xschem-claude`, which now mismatches the owner) |
| **EXIT 4, "no such debt"** | **33** | ids already cleared long ago — **pre-existing, unchanged by stamping** |

**No live instruction in the tree breaks.** Both exit-5 lines are *narrative*, not
commands to run: `1400:331` is the sentence *"So today, from this tree, `owed.sh clear
rule 1339` deletes **op-wcard's** unanswered ruling"*, and `N2.md:145` is a transcript
of a refusal printed by N2's own two-fake-clone fixture. That said —

> **FIX 1 (LOW).** `issue 1400:331` is now **factually false** and it is in a tracked
> file. Since 12:18 that command refuses, exit 5. Verbatim, measured on the copy:
> `!! owed REFUSED: rule 1339 belongs to another clone -- NOT cleared / its clone:
> /home/analog/dev/xschem-op-wcard / … this clone's own rule debts on that number: …
> clear rule 1339_R3_copy_says_what_it_did`. Reword to past tense, or say the stamp
> now stops it — the sentence is the issue's proof of the hazard and it reads as live.

> **FIX 2 (LOW).** `receipts/N3_ADVERSARY.md:174` predicts `clear rule 0643` →
> `!! owed WARNING: rule '0643' predates origin stamps …`. Measured: `rule/0643` now
> carries `repo:/home/analog/dev/xschem-claude`, so it clears **with no warning at
> all**. Documentation rot in a receipt.

**`add`**: `… 'owed\.sh[[:space:]]\+add' …` → **172 lines across 92 files**; **54**
carry a concrete `rule`/`suite` id. Cross-checked against the stamped copy, exactly
**one distinct id is now foreign — `rule 1351`** — and its single occurrence
(`numbering_batch/LEDGER.md:38`) is narrative. **0 live `add` instructions break.**

**`drain`**: 14 quoted lines. `drain` never refuses; it **skips**. See §4.4.

**`list`/`show`/`count`**: 44 quoted lines, all still exit 0. Output gains markers:
`list` prints **14** `from: … (another clone)` lines and **2** `(not in this clone)`
ref markers; `show` prints **12** `filed in another clone` lines (rule+look only) and
`grep -c -- '--repo'` → **0**, so the user's ruling of 11:15 still holds post-backfill.

### The named "live defect in a generated page" is not one

`doc/claude/lookdebt_batch/build_page.py:52` emits `owed.sh clear look %s`.
`N2.md:517,522`, `N3.md:613`, `CLOSEOUT.md:153` and the `LEDGER.md` N2 row all predict
it "will print a command that exits **5** once entries are stamped". **Measured today,
that is wrong on three independent counts:**

1. **It does not read the ledger.** It reads `debts.json`, a 46-entry snapshot frozen
   2026-09-07 (`stat` → 17:49).
2. **It cannot run.** `python3 build_page.py` in a scratch copy →
   `FileNotFoundError: …/shots/rdw_status.png`; the directory beside it is `poses/`,
   not `shots/`. `find /home/analog -maxdepth 4 -name 'lookdebt_digest*'` → nothing;
   same under op-wcard. **No `.html` file in either tree contains the string `owed.sh`**
   (`grep -rIl 'owed\.sh' --include='*.html'` → empty in both). There is no generated
   page the user reads.
3. **Even if built, the exit code would be 4, not 5, and for an unrelated reason.**
   Of its 46 ids, **0** are op-wcard's; **35** are *prefixes* of a live look filename
   with the `.<epoch>.<pid>` suffix stripped, so those commands name a file that does
   not exist; the other **11** are already cleared. (Python cross-check of `debts.json`
   ids against `ls look/`.)

> **FIX 3 (MEDIUM — it is the batch's only named live defect and it is misdescribed).**
> Correct the claim in `N2.md`, `N3.md`, `CLOSEOUT.md:153` and `LEDGER.md`.
> `build_page.py`'s real defect is that it emits **ids that are not ledger filenames**,
> it predates the stamp entirely, and it is currently unbuildable. Leaving the exit-5
> story standing means the next reader "fixes" the wrong thing and leaves the exit-4
> one — the one that would actually waste the user's time — in place.

### Forward exposure the stamping creates for crews

Ten files instruct an agent to run `owed.sh add rule <issue-number>`:
nine `doc/claude/*/CREW_BRIEF.md` (`ase_analyses`, `ase_l_ux`, `ase_registry`,
`ase_run_guard`, `ase_simchoice`, `descend_run`, `rdw_lists`, `rdw_sim`, `rdw_ux`) and
the prompt generator `doc/claude/ledger/crew.js:112,727-729`. For all ten,
`/usr/bin/grep -c -- '--repo\|exit 5\|another clone'` → **0**.

> **FIX 4 (LOW today, grows).** Today only `1339` and `1351` are foreign, so a crew
> hits exit 5 only on those. But op-wcard's pointer is at **1354** and this branch has
> committed every number to 1399, so each new op-wcard filing that also gets a rule
> debt arms one more. A crew that meets exit 5 with no guidance will either give up on
> recording the ruling — which is the loss this whole batch exists to prevent — or
> reach for `--repo`, which is worse. One sentence in `crew.js` (it generates the other
> nine) is the whole fix.

---

## 2. Automated consumers

**There are only two, and both are fine.**

* `tests/headless/owed.sh` — the tool. Exercised throughout below.
* `tests/headless/test_owed.sh` — `export XSCHEM_OWED_DIR="$TMP/state"` at `:41`, a
  `mktemp -d` under a trap. It never opens the live dir; verified after my run — the
  state dir still contains only `look rule suite`, no `cleared.log`.

**Everything else that could have consumed it does not.**
`crontab -l` → `no crontab for analog`. No user systemd timer touches it
(`systemctl --user list-timers` → three unrelated Ubuntu units). No Claude Code hook:
`/usr/bin/grep -n owed` over `~/.claude/settings.json`, `~/.claude/settings.local.json`,
`.claude/settings.json`, `.claude/settings.local.json` → nothing in any of the four.
`/usr/bin/grep -c owed` → **0** for `full_audit.sh`, `run_suites.sh`, `gated_xschem.sh`,
`xvfb_arm.sh`, `gui_gate.sh`. The `owed` hits in `devdisplay.sh`, `winshot.sh`,
`wslg_health.sh`, `test_gui_gate_*.sh`, `src/ase.tcl`, `utils/annot_mode.tcl`,
`tests/headless/test_op_annot.tcl`, `test_sim_plain_run.tcl`, both `item_pipeline.js`
and `crew.js` are **comments and prompt text** — I read every one; not one opens the
directory. (Several are `swallowed`/`followed`/`borrowed` substring noise.)

The only *generator* that emits `owed.sh` commands into an artifact is
`build_page.py`, handled above.

---

## 3. `test_owed.sh` — verdict, and whether it covers today's world

Run 2026-09-10 **12:23:31 -0700**,
`cd /home/analog/dev/xschem-claude/tests/headless && OWED_TEST_DISPLAY=none bash test_owed.sh`,
rc=**0**. Verbatim last line:

```
RESULT: ALL PASS (233 checks, 1 skipped)
```

(`OWED_TEST_DISPLAY=none` because this task forbids launching the binary. The suite's
own banner says it: *"a skip is NOT a pass -- the one row that launches the real binary
is unexecuted, in every published run of this suite so far."* That row is O13 and it
remains unexecuted here too.)

**Does it cover the state the world is now in? Mostly — with three real gaps.**

The suite builds a fresh empty fixture and creates every entry through `owed.sh`, so
**none of the 233 checks has ever been evaluated against a 196-entry, 100 %-stamped,
two-owner ledger.** That is not itself a defect — O23–O39 cover each mechanism in
miniature, and I re-exercised the important ones directly against a copy of the *real*
ledger in §1 and §4, where they behaved as the suite says. The gaps are these:

**G1 — no check runs two `owed.sh` VERSIONS against one ledger, which is the world we
are in.** `OWED_SH` (`test_owed.sh:45-49`) repoints the *whole* suite at another copy;
it is a RED-run knob, not a mixed-version fixture. This clone runs 961 lines, op-wcard
runs 459. §4 shows the 459-line one still destroys stamped entries at exit 0 — the only
remaining destroy path, and it is the one nothing fences.

**G2 — O32 is now the only path that can fire, and it is labelled backwards.** It is
headed *"an UNATTRIBUTED entry — the 192-legacy contract"* (`test_owed.sh:718`), and
`:740` pins `predates origin stamps -- claiming it for cloneA` as **correct**.
Post-backfill there are **0** unattributed entries, so an unstamped entry can now only
arrive one way: op-wcard's old script wrote it. Against today's ledger that sentence is
false and the claim it blesses **transfers op-wcard's text to this clone** (§4.6).

**G3 — nothing pins `repo_via:` to a legal value.** 195 of 196 live entries read
`repo_via:told`, which `owed.sh:462` writes only for an explicit `--repo <path|tag>`.
The spec (`owed.md:309-311`) names the set `git | path | told`; no check asserts it. So
a *backfilled* stamp is indistinguishable from a *user-typed override*, and the ledger
has lost the ability to say which of its 196 entries were hand-stamped this morning.

> **FIX 5 (MEDIUM).** Add a row for G1/G2: a fixture holding one stamped entry and a
> stamp-blind `owed.sh` (`git show ddf1f58e:tests/headless/owed.sh` is the exact
> artefact, 459 lines), asserting what this clone then says about the wreckage. And
> re-word O32's heading and `owed.sh`'s three `predates origin stamps` warnings
> (`:291`, `:511`, `:721`) so they stop asserting "legacy" about the one thing that can
> now produce them.

---

## 4. What the other clone's old `owed.sh` does now that it meets stamped entries

`/home/analog/dev/xschem-op-wcard/tests/headless/owed.sh`: **459 lines**, mtime
**2026-09-04 06:55**, last touched by commit `ddf1f58e`. `/usr/bin/grep -n repo owed.sh`
→ **5 hits, every one prose** (`reporting`, `repo-relative`). It has no `_entry_repo`,
no `_origin`, no refusal, no `cleared.log`. All of the following was measured against a
`cp -a` copy.

**4.1 — Its READERS are completely blind to the stamp, and say nothing.**
`diff <old list> <new list>` over the same ledger → the *only* differences are the **14**
`from: … (another clone)` lines and the **2** `(not in this clone)` ref markers this
clone adds. `count` is identical (`134 rule, 53 look, 9 suite`). `show` prints **0**
ownership lines. stderr is **empty** — `_entry_field` only asks for `eyes` and `ref`, and
`^repo:` matches neither, so the two new lines are silently ignored. **A person working
in op-wcard cannot distinguish the 14 entries they own from the 182 they do not**, and
nothing tells them the ledger has grown a concept.

**4.2 — `add` still destroys, and now destroys the stamp too.** Measured:
`add rule 1400 "probe from the other clone"` → prints **`owed: recorded rule debt: 1400`**,
exit **0**. Before: 4 lines (ruling + `ref:` + `repo:` + `repo_via:`). After: **1 line**.
The ruling, the pointer to its option set, and both stamp lines are gone; **no
`cleared.log` was created**. Note the word: **`recorded`**, where this clone says
`updated` and writes a pre-image first.

**4.3 — `clear` still `rm`s in silence.** `clear rule 1344` (this clone's, stamped) →
`owed: cleared rule debt 1344`, exit **0**, file gone, no pre-image.

**4.4 — `drain` runs and clears THIS clone's suite debts.** With a stub `run_suites.sh`
(nothing launched): **9/9 run, 9/9 `PASS -> debt cleared`, `suite/` emptied** — including
the 7 stamped `xschem-claude`. All 7 of those names resolve in op-wcard too (checked
file-by-file), so it runs *its* copies of *this* clone's suites and clears this clone's
debts on their pass. This clone's drain, on the same ledger, prints
`== SKIP … -- another clone's debt (…); drain it there` and runs nothing foreign.
(The two op-wcard suite debts resolve in **neither** direction here — `test_hier_pdf_links_1333`
and `test_ps_valid_1350` have no file in this clone — so from this side the stamp only
changes `UNRESOLVED -> debt KEPT` into `SKIP`; the debt stood either way.)

**4.5 — op-wcard's `drain` also *un-stamps*.** Both its rewrite arms are a bare `>`
(`:399-401` UNRESOLVED, `:424-425` FAILED), so any suite debt that goes red or
unresolvable there loses `repo:`, `repo_via:` **and** `ref:`. This clone's
`_rewrite_line1` preserves lines 2+. Erosion is now one red run per debt.

**4.6 — the new failure mode the backfill creates, and the fix that matters most.**
Before today an unstamped entry meant *legacy*. It now means exactly one thing:
**op-wcard's old script just wrote over something.** This clone greets it with
`!! owed WARNING: <kind> '<id>' predates origin stamps -- claiming it for xschem-claude`
(`owed.sh:291`, `:511`, `:721`) and stamps it as **ours** — a false statement that
silently transfers op-wcard's text to this clone *and erases the one signal that a
destroy happened*.

> **FIX 6 (HIGH — this is the sharpest thing stamping broke).** With the ledger at
> 196/196, an unstamped entry is evidence, not history. The warning must say so, and
> `_claim` must **not** claim on the strength of absence alone. `CLAUDE.md`'s ledger
> paragraph teaches the old rule verbatim (*"An unstamped entry is claimed for this
> clone the first time it is touched"*), and `test_owed.sh` O32 pins it as correct —
> so all three move together, or none of them does.

**4.7 —** `rule/1351@xschem-claude` now appears in op-wcard's `list`/`show` carrying
`ref:doc/claude/issues/1351-the-poll-guard-…md`, a file that tree does not have, and its
old script does not mark dangling refs. There it reads as a **missing file**, not as
another tree's — which is precisely the confusion `_ref_missing` was added here to stop.

**4.8 — the one nobody has written down: the ledger is now pinned to two absolute
paths, and `owed.sh` has no command to re-point it.** Measured by running this clone's
`owed.sh` from a copy of the tree at a different path: **all 196 entries read foreign** —
`show` marks **187 of 187** rule+look as `filed in another clone`, `list` marks **196**,
`clear` on this clone's own look debt is **REFUSED exit 5** (and unhelpfully adds *"this
clone owns no look debt on that number"*), and `drain` reports
`no suite debts for THIS clone to drain (9 left standing for another clone)`. The
`--repo xschem-claude` escape does work (verified, exit 0) but must be typed on **every**
command, and the dispatcher has `add|list|show|count|clear|drain|help` — **no rename, no
re-stamp**. Before this morning, renaming or moving `/home/analog/dev/xschem-claude` cost
nothing; today it converts the user's entire 196-entry queue into someone else's.

> **FIX 7 (MEDIUM).** Either a `re-stamp`/`adopt` path in `owed.sh`, or — cheaper — one
> line in `owed.md` and `CLAUDE.md` warning that moving or re-cloning either checkout
> orphans the whole ledger, and naming the `--repo` escape as the manual remedy. A
> fragility this total should not be discoverable only by tripping over it.

---

## 5. Internal contradictions still standing

Re-swept `issue 1400`, `NUMBERING.md`, `CLAUDE.md`, `numbering_batch/{PLAN,LEDGER,DECISIONS}.md`
and all nine receipts. **The driver's 11:37 repair pass closed CLOSEOUT's C1** — the
"fifty more / 1349 / 1350 / 1354" tangle is gone from issue 1400 (`grep -n 'fifty
more\|50 remain queued\|next free 1349'` → the single surviving hit at `:158` is now
explicitly dated *"when this batch was scoped at 08:25"*, under a section headed *"Every
figure in this section is a timestamped observation, not a standing fact"*). C4 is
closed. **Five contradictions stand, two of them new since the closeout, and both new
ones are consequences of the driver's own three actions.**

### C-A · HIGH · `doc/claude/issues/NUMBERING.md:3017` still says **"No ruling has been lost"**

In bold, in the same sentence that lists **1351** among the six collided bare ids. It is
false — `rule/1351` was destroyed at 10:46:14 and the batch's own `LEDGER.md:51` says
*"This is the first confirmed loss."* NUMBERING.md was written at **10:49:57**, three
minutes after the loss. `grep -rIn 'ruling has been lost'` finds four sites: `PLAN.md:63`
(superseded plan), `LEDGER.md:51` (corrects it), `1400:365` (corrects it), and this one —
**the only uncorrected copy, in the only tracked file, and the file `CLAUDE.md` sends
every filer to.**

### C-B · HIGH · the driver's three ledger actions are recorded **nowhere in the tree**

`/usr/bin/grep -rIn '1351@xschem-claude' --exclude-dir=.git .` → **0 hits**. The single
most consequential thing that happened today — recovering a destroyed, unanswered user
ruling — exists only in `$HOME`. Consequently four tracked/batch statements now assert
the opposite of the ledger's state:

* **issue 1400, closing condition 5**: *"this branch's RDW question … **is not in the
  ledger anywhere**. That is a debt the user never saw."* It is in the ledger, as
  `rule/1351@xschem-claude`, since 12:18.
* **issue 1400, closing condition 4**: *"**The backfill stamping pass runs.** … at 10:46
  all 194 live entries had none … The driver owns this pass."* It has run.
* **`LEDGER.md`, "Not done, and why"**: *"**The ledger is unwritten by this batch** — 0
  of 194 entries carry a `repo:` stamp"* and *"**The `rule` debt on 1400 is not
  recorded**"*. Both done — `rule/1400` exists, `repo_via:git`, its `ref:` resolving here.
* **`CLOSEOUT.md` §5**: *"**The real ledger — no backfill has run, exactly as
  expected.**"* with `grep -rl '^repo:' … | wc -l -> 0`.

**FIX 8 (HIGH).** One short section — in issue 1400, and referenced from `LEDGER.md` —
recording: the recovery, its provenance (`xschem_owed.bak.2026-09-10`, `cp -a` at 09:20),
the new id, the fact that **both** 1351 rulings now stand and both are unanswered, the
backfill's scope (195 `told`, 14/181 split) and that it was verified append-only. Without
it, the next reader of this repo is told a ruling is lost that is not, and told a pass is
owed that has run. Both backups must be named, because they are the only proof.

### C-C · MEDIUM · issue 1400 is **536** lines, stated as **519** in three places

`wc -l < doc/claude/issues/1400-*.md` → **536**. `CLOSEOUT.md:135` (closing finding
N1-F10 on that very figure), `CLOSEOUT.md:224` (in the list headed *"Everything else
reconciles"*) and the `LEDGER.md` N1 row all say **519**. The file's mtime is
**11:37:54**, after CLOSEOUT (11:34:08) and **before** LEDGER.md (11:39:09) — so the
LEDGER figure was already wrong when it was typed. This is the batch's signature defect —
one number stated two ways — surviving inside the closeout that certifies it was fixed.

### C-D · MEDIUM · `CLOSEOUT.md`'s reconciliation list ends *"the ledger at **194 / 0 stamped**"*

Now **196 / 196**. A dated receipt may of course go stale, but this sits in a paragraph
headed *"Everything else reconciles"* and reads as a standing fact, immediately above §5's
*"no backfill has run, exactly as expected"*. Same fix as C-B: one dated line saying the
receipt's snapshot was superseded at 12:18.

### C-E · MEDIUM · `CLAUDE.md`'s ledger paragraph now teaches the wrong reflex

It reads *"a backfill pass **is** stamping them, so **look at the entry rather than
assuming either state**"* and *"An unstamped entry is claimed for this clone the first
time it is touched, but until that happens a foreign `clear` still **succeeds**"*. The
pass has finished; the state is no longer ambiguous; and the claim-on-absence it
describes is now the ownership-transfer bug of §4.6. `CLAUDE.md` is the file every
session reads first, so this is the highest-traffic stale sentence in the tree. Fix it
with FIX 6, in the same edit.

### C-F · LOW · the closeout's own C2/C3/C5/C6 are unchanged, and I re-measured two

* **C2 confirmed still open**: `git diff --numstat tests/headless/test_owed.sh` → **750 3**,
  `wc -l` → **1100**, against `N3.md:558`/`LEDGER.md`'s *"742 insertions, 3 deletions,
  353 → 1092"*.
* **C5 confirmed still open**: `tests/headless/owed.sh:328` still carries the bare,
  undated *"the live ledger is 192 of them"*. It is now **196** — the third value that
  sentence has had today, in a file whose own header insists no bare count may be written.
* C3 (receipts telling a future reader to re-introduce 8/50) and C6
  (`ase_analyses_batch` naming 1400 as next free) stand as the closeout describes them.

---

## What "SOUND WITH FIXES" means here

**The stamping pass itself is sound.** It is append-only against the 12:18 backup with
byte-exact prefixes on all 194 entries, structurally clean (one stamp per entry, none on
line 1, no gluing, all parse), correctly attributed on the two ids I could check
independently, and the recovery is byte-faithful to the 09:20 backup. The refusals it
arms work, and they work with useful, correct output — I ran all four shapes against a
copy of the real ledger and the entries were still byte-identical afterwards. **No live
instruction anywhere in the tree was broken by it.** Only two of 39 concrete quoted
`clear` commands changed outcome, and both are prose.

**What needs fixing is what the tree now says about the world**, in four places that
matter (C-A, C-B, C-C/C-D, C-E), plus two behavioural consequences nobody has written
down: an unstamped entry has silently changed meaning and is still handled as though it
had not (FIX 6), and the ledger is now pinned to two absolute paths with no way back
(FIX 7). The misdescribed `build_page.py` defect (FIX 3) matters mainly because it is the
one item the batch nominated as *live*, and it is the one item that is not.

Nothing here asks for a ledger write. **Both 1351 rulings stand, both unanswered, and
only the user may close either.**
