# Spec — the owed ledger

*Everything a piece of work still owes — the user's rulings, the user's eyes,
and a real-screen run — recorded when it is incurred and paid in one batch
instead of dozens of interruptions.*

Status: implemented. `tests/headless/owed.sh`, tests in
`tests/headless/test_owed.sh`.

**Three kinds since 2026-08-22.** `rule` joined `look` and `suite` at the user's
instruction — see §6 for why, and for what the split it replaced was costing.

**Origins since 2026-09-10.** One ledger is shared by every CLONE of this repo
on the machine, not just every worktree, and two of them filed the same issue
numbers. Every entry now records the clone it came from and a cross-clone write
refuses — R608, R609, R610, and the ⚠ in §2.

⚠ **THE PROTECTION IS ONE-SIDED. A SPEC THAT DESCRIBED IT AS MUTUAL WOULD BE
WORSE THAN NONE, SO READ THIS BEFORE R608.** Everything R608–R613 requires is
requirements *on this copy of `owed.sh`*. The ledger lives in `$HOME`; the
script does not. The other checkout on this machine runs **its own** copy —
`/home/analog/dev/xschem-op-wcard/tests/headless/owed.sh`, 459 lines, mtime
2026-09-04 06:55, `/usr/bin/grep -n repo` on it returns 5 hits and every one is
prose — and measured on 2026-09-10 against a `cp -a` copy of the fully stamped
ledger it still:

* `add`s over any entry at **exit 0** printing `recorded`, erasing `repo:`,
  `repo_via:` **and** `ref:` with the text, and writing **no** `cleared.log`;
* `clear`s any entry with a silent `rm`, no pre-image;
* `drain`s **this** clone's suite debts against **its own** files of the same
  names and clears them on a pass;
* and both of its drain rewrite arms are a bare `>`, so a red run un-stamps.

**Stamping all 196 entries did not narrow that by one byte.** What the stamping
bought is that this clone can no longer destroy the other one's entries, and
that a destroy leaves evidence here (R610, and R608's FOREIGN verdict). What it
did **not** buy is any protection for the 182 entries this clone owns, and the
other clone's own next-free issue number was pointed straight at a band this
branch has already committed. **The fix is one `cp` of this file into that
tree**; it is not a code change here, and no requirement below can substitute
for it.

Related: `doc/claude/specs/dev_display.md` (why routine testing no longer takes
the screen at all), `doc/claude/specs/gui_test_gate.md` (the panel, and its
`Forever` grant).

---

## 1. The problem

After the dev-display work, no test *requires* `:0` — a full audit under Xvfb
reproduces the `:0` verdict set exactly. What remains are two obligations that
still cost the user's attention, and both arrive at the worst possible cadence:
**scattered, one at a time, whenever a feature happens to finish.**

| | ruling owed by the user | item owes the user's look | suite owes a `:0` run |
|---|---|---|---|
| where it comes from | a driver run's **E questions**: "ratify this user-visible change, or revert it" | `pixel-deliverables-need-eyeball`: "the report is *suites green, please look* — not *done*" | `CLAUDE.md`: "run a GUI feature's suite on `:0` once before calling it done" |
| who performs it | **the user** | **the user** | a script |
| verdict | a decision | judgment | PASS/FAIL, machine-readable |
| clears itself | **never** — only the user clears it | **never** — only the user clears it | **yes**, on a pass |
| what it needs | *the user's attention*, and often a look first | *the user's attention*; a VNC view of `:99` serves equally | the real display |

The cost is not runtime. A suite is seconds; the batch of GUI tests that show
windows is 195 of 319 files, of which 23 replay real press/motion/release
gestures — the visible "placing resistors and dragging wires" show. The cost is
the **number of interruptions**. Three two-minute interruptions at unpredictable
moments are worse than one six-minute block the user chose.

Approval is already batched — the gate's `Allow 30m` / `Forever` means one press
covers a whole run of suites. What is *not* batched is the work itself: nothing
records "this owes a real-screen run", so it can only be paid immediately or
forgotten.

### The failure this must not become

A ledger that clears an eyeball item because a suite went green would be exactly
the defect `pixel-deliverables-need-eyeball` was written about: two defects
shipped past 28 passing checks because a green suite was read as an answer. **An
automated verdict may never discharge a human one.** The two lists therefore
have different clearing rules, and no code path converts one into the other.

---

## 2. Interface

```
owed.sh add   rule  <id> [why] [--eyes] [--ref <path>] [--repo <clone>]
owed.sh add   look  <what> [why]     # something owing the user's eyes
owed.sh add   suite <name> [why]     # a suite owing a :0 run
owed.sh list  [rule|look|suite]      # what is queued, and since when
owed.sh drain [--display :0]         # run the SUITE debts, one batch, one gate
owed.sh show                         # the USER'S QUEUE (rule + look), read aloud
owed.sh clear rule <id> [--repo <clone>]   # only the user closes a ruling
owed.sh clear look <id> [--repo <clone>]   # only the user clears a look
owed.sh clear suite <id>             # escape hatch: abandon a suite debt
owed.sh count                        # "9 rule, 2 look, 3 suite" — for status lines
owed.sh restamp --from <clone> [--to here] [--dry-run]   # after a clone MOVED
```

`add rule` also takes **`--no-eyes`**: an update keeps the `eyes` tag the
standing entry carries (R612), and this is the one way to drop one.

Exit codes: **2** usage — including **an id that is a path** (R611) — **3**
state dir or an unrecordable pre-image, **4** no such debt, **5** refused: that
entry belongs to another clone, or it carries **no** stamp in a ledger where
everything else does (R608/R609).

**`count` prints in `rule, look, suite` order and every consumer selects by
name.** The one consumer that did not — `drain`'s "look debts untouched",
written as `count | sed 's/.*, //'`, i.e. *the last field* — silently began
reporting the **rule** count the moment a third kind existed. Guarded by O18.

State: `${XSCHEM_OWED_DIR:-$HOME/.claude/xschem_owed}`, under `$HOME` so one
ledger serves the main session and every worktree — the same argument that put
the gate dir there.

⚠ **"the main session and every worktree" was never the whole story, and the
missing half is the dangerous one: a second CLONE is not a worktree, and `$HOME`
cannot tell them apart.** Every checkout of this repo on the machine writes this
one ledger, while `doc/claude/issues/NUMBERING.md` — the authority on issue
numbers — is *tracked and per-branch* and structurally cannot see across a clone
boundary. Measured 2026-09-10: two clones here each read their own NUMBERING.md,
each found `1333–1348` free, and each filed into it, so a rule id became a
4-digit number with two unrelated meanings and both writing paths destroyed the
other tree's entry in silence. Since then every entry records the clone that
filed it (**R608**) and a cross-clone write refuses (**R609**).

⚠ **Do not quote a bare count for that collision.** It was **7** numbers at
08:25 on 2026-09-10 and **12** by 10:45 the same day — the other clone filed
1349–1353 while this section was being written, and its own `next free number`
then read **1354**, which this branch has already committed. It was still
growing when this was written. Any number for it carries the date and the time
beside it, or it reads as settled when it is not.

---

## 3. Requirements

### R1 — recording

- **R101** `add suite <name> [why]` records a suite name, a reason, and a
  timestamp. Recording is cheap and never runs anything.
- **R102** `add look <what> [why]` records a description, a reason, and a
  timestamp.
- **R103** Adding the same suite twice does not duplicate it; the newer reason
  and timestamp win. `look` entries are **never** deduplicated — two different
  things can share a description, and silently merging them would drop one.
- **R104** An unknown kind is an error, not a **fourth** list. (It read "third"
  until `rule` became the third; the point was never the number, but that a typo
  must not quietly open a list nothing reads.)
- **R105** Entries survive across sessions and reboots.

### R2 — reading

- **R201** `list` shows both lists with ids, ages in days, and reasons.
- **R202** `list <kind>` shows one.
- **R203** `count` prints a single machine-readable line, one field per kind in
  `rule, look, suite` order. **Consumers select by name, never by position.**
- **R204** An empty ledger says so and exits 0. Nothing owed is a normal state.

### R3 — draining the suite debts

- **R301** `drain` runs every queued suite through `run_suites.sh` with
  `AUDIT_DISPLAY` set to the real display (default `:0`, overridable), so the
  gate is live and the user keeps Pause/Stop.
  - ⚠ **Every queued suite THIS CLONE FILED** (R608/R609, 2026-09-10). A suite
    name resolves against the invoking clone's `tests/headless` (R308), so a
    debt filed by another clone would be paid by running a *different file of
    the same name*. Measured over the 8 debts standing that day: 7 resolve in
    this clone, all 7 resolve in the other one too, and **6 of those 7 differ in
    content**. Another clone's debt is skipped, not run.
- **R302** A suite that **passes** is removed from the ledger.
- **R303** A suite that **fails** stays, with its failure recorded, so a drain
  cannot be a way to lose work.
  - **A skipped debt from another clone stays too, and is not a failure.** It is
    counted and named separately and does not colour the exit status: it is not
    this clone's work, so it can neither pass nor fail here.
  - ⚠ **Recording a failure REWRITES LINE 1 AND KEEPS LINES 2+.** Both rewrite
    arms — FAILED and R309's UNRESOLVED — truncated the file with a bare `>`
    until 2026-09-10, which erased the `repo:` stamp, the `ref:`, and any
    verdict a human had written on the entry. It did that exactly where debts
    live longest, since a debt is only ever rewritten when it is *not* being
    paid.
- **R304** `drain` prints a summary: how many ran, passed, failed, remain.
- **R305** `drain` never touches the `look` list **or the `rule` list**. Not
  even to reorder them. Its summary names both, because an unmentioned list is
  one a reader can believe was drained.
- **R306** `drain` with nothing queued exits 0 and runs nothing.
- **R307** The user can stop a drain mid-way (the gate's Stop); already-passed
  entries stay cleared and the rest stay queued.
  - ⚠ **This holds for `.tcl` debts only.** R308 runs a `.sh` suite *directly*
    and deliberately outside the gate, so Pause and Stop cannot reach it: the
    panel lists such a run under `UNGATED`, and its **`Halt N xschem`** button
    (SIGSTOP, resumable) is the only authority over it. The exception is
    narrow on purpose — the suites that need the `.sh` path are the gate's own
    self-tests, and a self-test *of* the gate must not run inside one — but it
    is a real hole in R307 and is written down rather than left for a reader to
    discover mid-drain. CLAUDE.md's owed-ledger section ("`drain` … gate live")
    carries the same caveat.
- **R308** **A suite name resolves to `<name>.tcl` *or* `<name>.sh`** in
  `tests/headless/` (a name containing `/` is taken as a path). Both kinds of
  suite exist in this tree — ~200 `test_*.tcl` driven through the xschem binary
  and a dozen standalone `test_*.sh` — and `drain` must be able to pay a debt of
  either kind.
  - a `.tcl` suite runs through `run_suites.sh`, which is what **enrols it in
    the gate** so Pause/Stop keep working;
  - a `.sh` suite is **executed directly**, because nothing else could run it:
    `run_suites.sh` drives `xschem --script`, which cannot source a shell
    script. It is handed the display in both spellings (`DISPLAY`, which such a
    suite reads, and `AUDIT_DISPLAY`, which the arm-aware ones read) and is
    **not** wrapped in the gate — the suites that most need this are the gate's
    own self-tests, and a self-test *of* the gate must not run inside one. Its
    **exit status is its verdict**, the contract every `test_*.sh` here already
    keeps.
  - *The defect that produced this rule:* `drain` handed every name straight to
    `run_suites.sh`, whose resolver knows `<name>.tcl` only
    (`run_suites.sh:82-88`). A shell-script debt therefore failed with `FATAL:
    no such test file: tests/headless/test_gui_gate_batch.tcl` on every drain,
    was recorded as failed and so was **kept** (R303) — a debt the ledger could
    only ever accumulate. Measured 2026-08-15 against the real
    `test_gui_gate_batch` entry.
- **R309** A name that resolves to **neither** extension is reported as a
  **misnamed debt**, naming the paths it looked for, and the debt is **kept**.
  It is not run, and it is not reported as a failing suite: only the user knows
  what they meant to write, and "FAILED on :0" sends the reader hunting a
  regression that does not exist.
  - ⚠ **The message names what was really stat'd** — `_suite_file` prints its
    own candidate list (`none\t<candidates>`) and the caller prints *that*.
    A bare name has two candidates (`$HERE/<n>.tcl` and `$HERE/<n>.sh`); a name
    containing `/` and a name that already carries an extension have exactly
    **one** each. Composing the message from the name unconditionally — which
    is what the first implementation did — named a doubled directory and a
    doubled extension for those two arms
    (`add suite tests/headless/test_nope.tcl` →
    *"neither …/tests/headless/tests/headless/test_nope.tcl.tcl nor …"*), i.e.
    two files nobody had looked for, which is exactly the reader-misdirection
    this rule exists to prevent.

### R4 — the look debts

- **R401** `show` prints the look list in a form meant to be read to the user:
  what to look at, why, and how long it has been waiting.
- **R402** **No command clears a look entry except `clear look <id>`.** Not
  `drain`, not a green suite, not age.
- **R403** `show` states plainly that these need a human, and suggests the
  cheapest way to serve them (`devdisplay.sh view`, or `:0` if the point is
  WSLg-specific rendering).

### R4b — what a debt's SCOPE is, and what may block clearing it

Added 2026-08-15 by the merge-5 loose-ends fix round, after `merge5-gui` was
cleared on a run that was not clean and two independent reviewers caught it.

- **R411 A debt has a scope, and it is the scope that must run clean — not
  every suite that happened to be in the same batch.** A debt named after a
  *change* (`merge5-gui`) is discharged by the suites that change touched; a
  debt named after a *suite* (`test_calc_widgets`) is discharged by that suite.
  The scope must be **derivable, not asserted**: `merge5-gui`'s is
  `git diff --name-only pre-open-pdk-merge-5 e7ae4d77 -- tests/headless/` minus
  `full_audit.sh`'s `nogui_tests`, and the receipt must print the command.
- **R412 A suite outside the scope that carries its OWN standing debt does not
  block the clear, and does not get silently dropped either.** `test_calc_widgets`
  is red on `:0` (R111) and is *not* merge-touched; it therefore cannot hold
  `merge5-gui` open, and its own debt stays standing regardless. Whichever way it
  falls, the receipt must NAME the suite, its result, and which debt owns it —
  the defect being prevented is a clear that rests on an *unstated* narrowing of
  the run set.
- **R413 Widening the scope is allowed; narrowing it after the fact is not.**
  Running more than the scope is how the merge-5 round found its only two real
  `:0` defects. But the set is fixed *before* the run, and a suite that fails may
  not be reclassified out of scope afterwards to make the clear work.
- **R414 A red that is one of the documented WSLg non-regressions does not block
  a clear, provided the receipt names it, names its mechanism, and shows a
  re-run.** The list is in `CLAUDE.md`: TG9 root-coords, `test_ase_plot`
  P4/P6/P8, and bare `event generate` key delivery. **Note the rate compounds:**
  the documented "~1 in 5" is per `event generate` CALL, so a suite making seven
  of them goes red far more often than one in five *runs* —
  `test_create_instance` measured 5/6 and 1/6 on `:0` on the same day with no
  code change between. Distinguish "late" from "lost" before believing any of
  it: poll for the effect, and if it has not arrived after ~3 s the event was
  lost and no amount of waiting in the test will fix it.

### R6 — the rule debts (added 2026-08-22)

- **R601** `add rule <id> [why]` records a **ruling the user owes**: an E
  question from a driver run, or any user-visible decision a step took without
  authority. The id is the issue number the question is filed under.
- **R602** Rule entries are **deduped by id — WITHIN AN ORIGIN** (amended
  2026-09-10, R608), like suites and unlike looks. Inside one clone a ruling
  *is* its issue number: re-adding `0444` restates one open question, and two
  `0444` entries would let the user answer one and still see the other standing.
  - ⚠ **Across two clones that identity is false, and assuming it was true is
    the defect this amendment exists for.** Two checkouts filed `1344` for
    unrelated questions on 2026-09-10 (the RDW clipboard text here, the negative
    page scale there). Deduping those two together does not restate a question,
    it destroys one — and the one destroyed is a ruling the user has not
    answered, which no automated path may ever close (§1, R605). `add` therefore
    dedupes against an entry of the **same origin** and refuses one from another
    (R609).
- **R603** **A rule entry is a POINTER, not a copy.** The option set (a/b/c),
  the measurements and the history stay in `doc/claude/issues/NNNN-*.md`.
  Flattening a three-option ruling into one ledger line is how the options get
  lost. `add` resolves the path from a 4-digit id and records it as `ref:`;
  `--ref <path>` supplies one for a ruling with no issue file (an E question
  keyed to a step, say `X0498`).
  - **R603a** An id that resolves to no file gets **no ref**, never an invented
    one. An id with no issue yet is a normal early state; a fabricated path
    sends the reader to a file that was never written.
- **R604** **`--eyes` tags a ruling that cannot be made without looking.** Four
  of the nine open on the OP-annotation branch are of this kind (0457 the
  resting value of `annot_show`, 0458 its stock control, 0468 the overlay's
  compiled-in geometry, 0475 the annotation-silent sky130 symbols). `list` marks
  them `[needs eyes]` and `show` says so in words. It is a **rule** tag: a look
  debt already needs eyes and a suite debt never does, so `--eyes` on either is
  an error rather than a no-op.
- **R605** **Only `clear rule <id>` closes a ruling.** Not `drain`, not a green
  suite, not age, and not `clear look` — the kinds are separate namespaces.
- **R606** `show` prints **rule and look together**, because from where the user
  sits they are one queue: both are owed by them, both are cleared only by them,
  and an R604 ruling needs a look before it can be made at all. Suite debts stay
  out — nobody needs to be told about work a script will do.
- **R607** **Optional per-entry data lives on lines 2+ as `key:value`, never as
  a fourth tab-separated column.** Line 1 is frozen at
  `<epoch>\t<subject>\t<reason>`; `_read_entry` hands everything after the
  second tab to `reason`, so a fourth column would appear glued to the end of
  every reason string in every existing reader. Growth happens downward.
  - **A newline in the subject, the reason or the `--ref` is a usage error, exit
    2.** The stamp is positional — `_entry_repo` takes the **first** `repo:`
    line — so `add rule 9001 $'B claims this\nrepo:<other clone>'` forged a
    stamp above the real one, and the writer was then refused on its own entry
    while another clone was offered it (measured 2026-09-10). Line 1's "one
    line" contract was stated in three comments and enforced nowhere.
    - Not closed, and lesser: a **tab** in the subject silently moves text into
      `reason`, because line 1 is tab-delimited. It corrupts a field; it cannot
      forge one.

### R6b — which clone an entry came from (added 2026-09-10, issue 1400)

*R608–R610 landed with the origin work that morning. **R611–R613 are the
second repair round the same day** — a path traversal in `clear`, what an
update destroys, and what a `mv` of a clone costs — and R608's
unattributed rule was rewritten there too, because the backfill changed
what an unstamped entry means.*

- **R608** **Every entry records the clone that filed it.** `repo:` on lines 2+
  (R607, never a fourth column), with `repo_via:` recording how the id was
  derived — `git`, `path`, or `told` when a `--repo` supplied it.
  - **What names a clone:** `git rev-parse --path-format=absolute
    --git-common-dir`, run against the script's own directory, with a trailing
    `/.git` removed. **`--git-common-dir`, not `--git-dir`**: every worktree of
    one clone has to give one id, which is exactly what §2's shared-ledger
    argument rests on. It survives a branch switch and a `git remote set-url`.
    The trailing `/.git` is removed so the git answer and the path fallback name
    the same clone — otherwise a tree that loses git turns all of its own
    entries foreign in one step.
    - **The fallback covers a LINKED WORKTREE too**, and the `/.git` strip alone
      did not: in a worktree, git answers with the *clone* and the checkout root
      by path is the *worktree*, so a worktree that lost git was refused on its
      own entries (measured 2026-09-10 with `git` stubbed to `exit 127`). The
      fallback therefore reads the worktree's `.git` **file** —
      `gitdir: <clone>/.git/worktrees/<name>` — and takes the clone from it.
      Absolute `gitdir:` only: a relative one cannot be an id, and a submodule's
      `.git/modules/<name>` deliberately does not match.
  - **Measured and rejected:** the remote URL and the root commit. Both clones
    on this machine point at the same GitHub repo and their root commits are
    identical; **neither can name a clone.** `--path-format` needs git ≥ 2.31
    (2.53.0 here); when git is missing or fails, the fallback is this checkout's
    root by path and `repo_via:path` says so, because a path-derived id and a
    git-derived id are not interchangeable evidence.
  - **AN ENTRY WITH NO `repo:` MEANS ONE OF TWO THINGS, AND WHICH ONE IS
    DECIDED BY EVIDENCE (amended 2026-09-10, second repair round).** Until the
    backfill it meant exactly one thing — *legacy*, filed before stamps existed
    — and every unattributed entry was therefore claimed by whoever touched it
    next. That reading died the moment the ledger became fully stamped: **196 of
    196 entries carried a stamp at 12:43:56 -0700 on 2026-09-10**
    (`find ~/.claude/xschem_owed -mindepth 2 -type f | wc -l` against
    `/usr/bin/grep -rl '^repo:'`; any count here is a timestamp, not a standing
    fact — another clone writes this directory). In a ledger like that a NEW
    unstamped entry cannot be legacy. It can only be a write by something that
    does not stamp, which on this machine means the other clone's older
    `owed.sh` — **and that script overwrites with no pre-image, so the absence
    of a stamp is evidence of a destroy.** Claiming on the strength of it is a
    false statement about another tree's text that also erases the one signal
    left behind. Measured before the repair, on a stamped copy of the live
    ledger: their script's `add rule 1354` wiped this clone's 1354 entry, its
    `ref:` and both stamp lines at exit 0, and this clone's next `add` then
    printed *"predates origin stamps — claiming it for xschem-claude"* and
    produced an entry carrying **our** stamp and **our** `ref:` over **their**
    words.
    - **The verdict.** *FOREIGN* when **both**: stamped entries are the majority
      of the ledger, **and** the entry was written **after the oldest stamped
      entry**. Otherwise *LEGACY*.
    - **Why not "newer than the newest stamp".** That was the first rule tried
      and it was measured wrong the same hour: this clone's own next `add`
      raises the newest stamp above the foreign write, and every older anomaly
      falls back to LEGACY and is claimed. Neither condition above moves when
      this clone writes.
    - **The LEGACY arm is unchanged, wording included**, because other checkouts
      of this repo exist and their ledgers have never been backfilled: with no
      stamps at all, or for an entry older than every stamp, `add` claims,
      `clear` clears and `drain` claims exactly as before, with the same
      `predates origin stamps` warning. Every `clear rule <id>` quoted in a
      receipt keeps working — that is the backward-compatibility contract, and
      breaking it would cost the user the queue the whole file exists to
      protect. Measured: `test_owed.sh` **ALL PASS (233 checks, 1 skipped)**
      against the repaired script, O32's legacy rows included, unaltered.
    - **The FOREIGN arm, per command, and the asymmetry is deliberate:**
      - **`add` REFUSES, exit 5, nothing written.** `add` is the AUTOMATIC path
        — an agent recording work — and it must not paper over a destroy. The
        refusal names what is standing, states the evidence, and offers the two
        deliberate ways through (`--repo here` to take the slot, `clear` to drop
        what is there).
      - **`clear` PROCEEDS, loudly.** It is the one command only the user is
        entitled to run, and a refusal in front of it is exactly how a user gets
        locked out of their own queue (R613). It says the entry is **not**
        legacy, says what it may be destroying, and R610's pre-image makes it
        recoverable.
      - **`drain` SKIPS**, as it does for another clone's debt: not run, not
        claimed, left standing. A pass in this tree may not clear a debt this
        tree was never given.
      - **`list` and `show` MARK it**, so the evidence reaches the reader before
        they type `clear` — the user reads the queue first, and until this round
        nothing in the queue said anything at all.
    - **A claim on the strength of absence alone no longer happens anywhere.**
      `owed.sh` said `predates origin stamps -- claiming it for <clone>` in
      three places; on the LEGACY verdict that sentence is still true and still
      printed, and on the FOREIGN verdict nothing claims.
    - The one narrowing, unchanged: `drain` claims an unattributed **suite**
      debt only when its name resolves in this clone. A name that resolves
      nowhere here is evidence the debt is another clone's —
      `test_hier_pdf_links_1333` is one — and claiming it would hand this tree a
      debt it cannot pay while refusing the clone that can. It stays
      unattributed and is reported by R309 exactly as before.
  - **`list` and `show` name the clone only when it is not this one**, and mark
    a `ref:` that does not resolve here (`(not in this clone)`). The everyday
    single-clone output is unchanged. Of the 132 rule entries standing on
    2026-09-10, 82 carry a ref; **one** does not resolve in this clone — the
    collided `rule/1339` — and **42 of the 82** do not resolve in the other one.
  - **`show` prints the PLAIN clear command, never the `--repo` override**
    (user's ruling, 2026-09-10). It names the owning clone —
    `filed in another clone: <id>` — and stops there.
    - It printed the override at first, on the argument that a queue telling the
      user to type a command that gets refused is worse than one that says
      nothing. True of a user at a keyboard, and wrong here: the failure this
      whole section exists to stop is an **agent** in clone B closing a ruling
      the user has never answered in clone A, and `show` handed it that exact
      command with no friction and no statement of consequence — removing every
      cost from the one operation R609 exists to make expensive.
    - **The refusal is the friction, and the refusal is where `--repo` is
      spelled out** — read by someone who has just been told no, and told whose
      entry it is and what is standing in it. The escape is not removed and not
      hidden: `help` documents it too.
  - **The tag** — the basename of the id — is a convenience for typing and for
    the `<id>@<tag>` slot, **never the identity**, and **no ownership decision
    compares tags.** Every one of them compares the full id, exactly. A `--repo`
    the user typed may *name* a clone by tag, but the tag is turned into a full
    id at resolve time by asking the ledger, and a tag the ledger cannot answer
    for — or that more than one clone answers to — is a usage error (**exit 2**),
    never a guess.
    - **Why this is stated twice and enforced three times.** The first
      implementation of R608 compared tags in `add`'s ownership test, `add`'s
      namespacing test and `clear`'s `--repo` test, while promising in prose
      that it did not. Measured 2026-09-10 in a fixture whose two clones were
      **both named `xschem`**: a plain, no-flag `add rule 1344` from the second
      clone replaced the first clone's unanswered ruling at **exit 0** and left
      the first clone's stamp on it, so the owner could never see it as
      foreign — verbatim the defect R608/R609 exist to stop. `--repo here`
      reached another clone's entry the same way, on both `clear` and `add`.
      Two clones of one repo under its own name is the **ordinary** shape; the
      pair on this machine happens to have different basenames, which is the
      only reason it was latent.

- **R609** **A command that would write another clone's entry refuses, exits 5,
  and says what to do instead.** Nothing is written, nothing is removed.
  - `add` on an existing `rule`/`suite` id stamped to another clone: the message
    names the standing subject and reason, both clone ids, and both `--repo`
    forms. This is the path that was a bare `>` with no existence check, and it
    printed `recorded` while truncating a ruling nobody had answered. An `add`
    that replaces now says **`updated`**.
  - `clear` on an entry stamped to another clone: the message names the owning
    clone, the entry's reason, and **the ids this clone owns on the same issue
    number** as a did-you-mean list — or says plainly that it owns none, which
    is itself the answer (the number means something else here).
  - `drain` **skips** another clone's suite debt (R301/R303).
  - **`--repo <clone>` is the deliberate override, on `add` as much as on
    `clear`**: a clone path, its basename, or `here`.
    - **`add … --repo here`** when another clone holds the bare id files the
      entry in a slot of its own, `<id>@<tag>`. `@` cannot survive `_slug`, so a
      namespaced id can never collide with a legacy one. The **subject** is left
      alone, so `_issue_ref` still resolves the ref (R603) — suffixing the
      subject instead is the workaround this replaces, and it silently drops the
      ref because that gate accepts a bare 4-digit id only. Without this, a
      second clone could not record a ruling for its own issue number **at all**.
    - **`add … --repo <their tag>`** updates their entry and keeps their stamp
      **verbatim**: rewriting it from what was typed would replace a full clone
      id with a tag, and the owning clone would then read its own entry as
      foreign — the refusal firing on the one person entitled to write.
    - **`clear … --repo <clone>`** prefers the `<id>@<tag>` slot when one
      exists, so whatever `add --repo` created, the matching `clear` reaches
      with the same words.
    - **`--repo` is matched EXACTLY, and `here` means strictly THIS clone.**
      A tag compare here is the same defect wearing the user's own words: with
      two clones sharing a basename, `clear <id> --repo here` from the clone
      that does **not** own the entry destroyed it at exit 0, and `add … --repo
      here` overwrote it and kept the owner's stamp (both measured 2026-09-10).
      A `--repo` naming a clone the entry is **not** filed in refuses (`clear`)
      or files a slot of its own (`add`). The escape is a statement of intent,
      not `-f`.
    - **A bare `--repo <tag>` the ledger cannot resolve is a usage error, exit
      2** — it is never stamped verbatim. It used to be, and the clone the tag
      named was then refused on its own entry while a clone that had never
      touched it could overwrite: the refusal firing on the one person entitled
      to write. A tag **more than one** clone answers to is the same error, for
      the same reason. Both messages ask for the clone's path.
    - **A refusal prints a `--repo` argument that really reaches that clone** —
      its tag when the tag is unambiguous, its full path when it is not.
      `show` is silent about the override (R608); the refusal is the one place
      it is spelled out, so what it prints has to work.

- **R610** **`cleared.log` — append-only, inside the state dir.** Every `clear`,
  every `add` that overwrites, and every debt a drain clears on a pass is
  appended **with its full text** before it is destroyed: a header line
  `=== <epoch> <event> <kind> <id> by <clone>` and the entry body prefixed `| `.
  `clear` is an `rm` and `add` is a `>`; the only reason the 2026-09-10
  collision could be reconstructed at all is that a tool result happened to
  persist, which is luck, not a ledger. It lives in the state dir **root**,
  where nothing globs — `list` and `count` walk the kind dirs only — and R502 is
  unaffected: nothing is written outside the state dir.
  - **If the append fails, the destroy does not happen.** `clear` keeps the
    entry and exits **3**; an `add` that would overwrite writes nothing and
    exits 3; a passing drain does not remove the debt. It used to warn and
    delete anyway — a pre-image that can silently not happen is the luck this
    requirement exists to replace. The warning is the ledger's, not the shell's:
    stderr is redirected before the append, so a failing redirect cannot leak
    its own message ahead of it.

- **R611** **An id is a FILENAME, never a path.** Any id that contains `/`, or
  that is `.` or `..`, is a usage error — **exit 2**, nothing written, nothing
  removed. It is checked wherever a user-supplied id becomes a path, and
  asserted in `add` even though `_slug` already maps `/` to `_`, so that an edit
  which drops the slug is caught by the ledger rather than by the filesystem.
  - **What it was.** `clear` resolved `$OWED_DIR/<kind>/<id>` with the id
    straight off the command line and never checked that the result stayed
    inside the kind dir. Measured 2026-09-10 against a `cp -a` copy of the live
    ledger: `clear rule ../cleared.log` → `owed: cleared rule debt cleared.log`,
    **exit 0**, the pre-image log gone; `clear rule ../../victim.txt` → **exit
    0**, a file outside the state dir gone. Neither wrote a pre-image, for the
    obvious reason in the first case.
  - **The traversal is INHERITED** from the pre-stamp script — this is not
    something the origin work introduced. What the origin work added is a target
    worth hitting: `cleared.log` now sits one `../` from every kind dir, and
    destroying it destroys the pre-image of the clear that destroyed it. In the
    measurement the *next* destroy then failed with exit 3, because R610's log
    was no longer there.
  - No legitimate id has ever contained a slash: an id is `_slug` output
    (`A-Za-z0-9._-`), plus at most the `@<tag>` suffix R609 files. Both of those
    shapes must keep clearing — verified on the live-ledger copy with the bare
    id `1400` and the namespaced id `1351@xschem-claude`.

- **R612** **An update KEEPS what the entry it replaces already says about
  itself.** `add` over an existing entry rebuilt the file from the command line
  and nothing else, so an update silently dropped every optional field.
  - **`eyes:1` survives**, unless **`--no-eyes`** is given. Dropping it
    downgrades what the debt asks of the user — a ruling they cannot make
    without looking quietly stops saying so — and nothing recorded that it ever
    did. `--eyes` and `--no-eyes` together is a usage error (exit 2).
  - **`ref:` is taken in priority order: an explicit `--ref`, then whatever the
    standing entry carries, then — only for a `rule` entry that is THIS clone's
    — the issue file this clone can see (R603).** The owner's `ref:` is never
    replaced by one derived here, and **an entry filed for another clone gets no
    auto-resolved ref at all**: the ledger must not assert, in their name, that
    their ruling lives in our file.
  - **Any other line 2+ content is carried over**, so a hand-written annotation
    survives an update exactly as it survives a drain rewrite (R303/R607).
  - **A rescue is reported, and only a rescue.** The `kept from the entry it
    replaced: …` line prints only for a field the command line did not supply
    **and** this tree could not have re-derived — so the everyday same-clone
    re-add prints exactly what it always printed.
  - Measured 2026-09-10 on a copy of the live ledger. Before:
    `add rule 1351 … --repo xschem-op-wcard` left their entry with **no**
    `eyes:1` and with their `ref:` replaced by this clone's unrelated 1351 file.
    After: both intact, and the two rescues named on stderr.

- **R613** **The stamp is an ABSOLUTE PATH, so moving or renaming a clone
  orphans every entry it filed — and there is a way back.** This was undocumented
  until 2026-09-10 and is total: measured by running this clone's `owed.sh` from
  a copy of the tree at a different path against a copy of the live ledger, all
  196 entries read foreign, `show` marked 187 of 187 rule+look `filed in another
  clone`, `clear` on the user's own look debt was **refused exit 5**, and `drain`
  reported nothing of its own to do. Nothing is destroyed — refusal is the safe
  direction — but the user's whole queue appears to belong to nobody, and before
  that morning moving a clone cost nothing.
  - **`owed.sh restamp --from <clone> [--to here|<clone>] [--dry-run]`**
    re-points every entry stamped `<from>` and sets `repo_via:restamped` — a
    path a human asserted after the fact is not the same evidence as one git or
    the filesystem answered with, and the ledger says which it holds.
  - **`--from` is required and never guessed.** It is the id the entries carry
    *now*: the old path, or a basename the ledger can resolve — which it still
    can, because the stamps themselves are what it asks.
  - ⚠ **It REFUSES (exit 5) if the `--from` path is still a checkout on this
    machine** — i.e. still holds `tests/headless/owed.sh`. That is the whole
    safety argument: restamp is for a clone that *moved*, which is why its old
    path is gone. A live path is another tree's, and re-stamping its entries
    would be a mass transfer of another tree's rulings on one command line — the
    thing R609 exists to make expensive. `--repo` remains the way to write one
    of their entries, one command at a time.
  - Every entry it rewrites gets a **pre-image first** (R610); if that cannot be
    written, nothing is rewritten. A re-attribution is not a destroy, but it
    rewrites the one field the whole mechanism rests on.
  - **If `restamp` is ever removed, the manual remedy must be documented in its
    place:** `--repo <old path>` on every single command, or a hand-written
    `sed -i 's|^repo:<old>$|repo:<new>|'` across `~/.claude/xschem_owed/*/*`
    with a copy of the directory taken first. A fragility this total must not be
    discoverable only by tripping over it.

### R5 — not lying

- **R501** Every command exits non-zero on real failure.
- **R502** Nothing is written outside the state dir — **and nothing is removed
  outside it either.** The second half was implicit and was false: `clear`
  resolved `$OWED_DIR/<kind>/<id>` with the id straight off the command line, so
  `clear rule ../../victim.txt` deleted a file outside the ledger at exit 0
  (measured 2026-09-10). See **R611**.
- **R503** A corrupt or hand-edited entry is skipped with a warning, never
  silently dropped and never fatal to the rest of the ledger.

---

## 4. Test plan — `tests/headless/test_owed.sh`

Runs against a throwaway `XSCHEM_OWED_DIR`.

| # | check |
|---|---|
| O1 | `add suite` records; `list` shows it; `count` reports it |
| O2 | `add look` records separately; the two lists do not mix |
| O3 | re-adding a suite updates rather than duplicates (R103) |
| O4 | re-adding a look does **not** dedupe (R103) |
| O5 | unknown kind is an error (R104) |
| O6 | empty ledger: `list` says so, exit 0 (R204) |
| O7 | `drain` runs queued suites and **clears the ones that pass** (R302) |
| O8 | `drain` **keeps** a suite that fails, and records the failure (R303) |
| O9 | **`drain` does not touch the look list** (R305/R402) — the headline |
| O10 | `drain` on an empty queue runs nothing, exits 0 (R306) |
| O11 | `clear look` is the only thing that clears a look |
| O12 | a corrupt entry is skipped with a warning, the rest of the ledger survives (R503) |
| O13 | one REAL drain of a real `.tcl` suite, so the stub cannot hide an integration break |
| O14 | a **`.sh`** suite drains: it really runs (its own witness file), **not** through the suite runner, gets the display in **both spellings, pinned separately** (`DISPLAY` and `AUDIT_DISPLAY` on their own anchored lines — one grep for the substring `DISPLAY=…` matches the other spelling and proves neither), clears on a pass and is **kept** on a failure (R308/R303) |
| O16 | `add rule` records; re-adding the same id updates rather than duplicates, newer reason wins (R601/R602) |
| O17 | the **three** lists stay apart — a ruling is not in the look list or the suite list, and vice versa |
| O18 | **`drain` does not touch the RULE list** (R305/R605) — O9's twin, and the row that exists because `rule` arrived *after* O9 was written. Also pins the positional-`count` defect: the fixture keeps 2 looks against 1 rule so a last-field read prints the wrong number under the look label |
| O19 | `clear rule` is the only thing that closes a ruling; `clear look <rule-id>` is an error and leaves it standing (R605) |
| O20 | `--eyes` is marked in `list` and stated in `show`; an untagged ruling is not marked (R604) |
| O21 | a 4-digit id auto-resolves to its issue file; `--ref` is kept verbatim; an id with **no** issue file gets no ref rather than an invented one (R603/R603a) |
| O22 | `--eyes` on a `look` or a `suite` is an error, not a silent no-op (R604) |
| O15 | a name with neither extension: non-zero exit, **both** candidate paths named, runner never invoked, debt kept and marked as misnamed (R309); plus a **path-shaped** and an **already-suffixed** name, whose message must name the **one** path really stat'd, with neither the directory nor the extension doubled |

**Rows for R608/R609/R610 (2026-09-10).** Named here for the implementer; they
need a **fake-clone fixture** (directories, each a real `git init`, each holding
a copy of `owed.sh` at `tests/headless/`) against a throwaway
`XSCHEM_OWED_DIR`. Whatever else changes, **O9 and O18 still have to hold**:
`drain` touches neither the look list nor the rule list, in any clone.

⚠ **TWO CLONES WITH DIFFERENT BASENAMES CANNOT SEE THE HEADLINE DEFECT.** The
first fixture was `cloneA` / `cloneB`, and every row in O23–O34 passed while
`add` still replaced another clone's unanswered ruling at exit 0 — the tag
compare only fires when the basenames match, so a fixture that never matches
them cannot reach it. **A THIRD clone sharing one of the others' basenames under
a different parent is mandatory** (`.../p1/xschem` and `.../p2/xschem`), and
O35 below is the row that uses it. The real pair on this machine —
`xschem-claude` and `xschem-op-wcard` — differ, which is the only reason the
defect was latent rather than live; the ordinary shape is a repo cloned twice
under its own name.

| # | check |
|---|---|
| O23 | every `add` stamps `repo:` and `repo_via:` on **lines 2+**; line 1 still has exactly three tab fields (R608/R607) |
| O24 | the origin is **one id per clone** and **one id for every worktree of that clone**, and survives a branch switch and a `git remote set-url` (R608) |
| O25 | with git unable to answer, the fallback stamps the checkout root and records `repo_via:path` (R608) |
| O26 | `add` on another clone's `rule`/`suite` id **refuses, exit 5, writes nothing**, and names the standing entry, both clones and both `--repo` forms (R609) |
| O27 | `clear` on another clone's entry **refuses, exit 5, leaves it standing**, and prints this clone's own ids on that number — or says it owns none (R609) |
| O28 | `--repo here` files a slot of its own, `<id>@<tag>`, **with the `ref:` intact**; `clear --repo here` finds that slot back and leaves the bare one alone (R609/R603) |
| O29 | `--repo <their tag>` updates their entry and leaves their stamp **verbatim**; a `--repo` naming a clone the entry is not filed in still refuses on `clear` (R609). ⚠ **A `--repo` given as a PATH is matched exactly**, so a path that merely carries another clone's basename is **not** that clone: on `add` it files a slot of its own, `<id>@<tag>`, and leaves the standing entry untouched — the old row asserted it updated theirs, which was the tag compare being pinned as correct |
| O30 | `drain` **skips** another clone's suite debt, keeps it, counts it separately, still exits 0, and does not run this clone's file of that name (R609/R303) |
| O31 | **both** drain rewrite arms preserve lines 2+: the stamp and a hand-written verdict survive a FAILED run **and** an UNRESOLVED one (R303/R607) |
| O32 | an **unattributed** entry still clears from any clone with one warning, `add` claims it, and `drain` claims it **only when its name resolves here** (R608) |
| O33 | `cleared.log` captures a clear, an `add` overwrite and a drained pass, **with the full entry text**; `list` is unbothered by the file sitting in the state dir root (R610) |
| O34 | the **everyday single-clone output is unchanged** — no origin line, no marker, `list`/`show`/`add` byte-identical (R608) |
| O34b | ⚠ **`show` never prints `--repo`, on any entry** (user's ruling). For a foreign entry it names the clone and prints the **plain** clear command; running that verbatim is **refused, exit 5**, and the refusal is where the override is named. The old row ran what `show` printed and required exit 0 — it pinned the bypass |
| O35 | ⚠ **the same-basename pair.** With two clones both named `xschem`: a plain no-flag `add rule <id>` from the second **refuses, exit 5, writes nothing** and leaves the first clone's text and stamp intact; `clear --repo here` and `add --repo here` from the second **do not reach** the first's entry (`clear` refuses exit 5, `add` files `<id>@<tag>` beside it). This is F1/F2 and the reason the fixture grew a third clone (R608/R609) |
| O36 | a bare `--repo <tag>` **no** ledger stamp answers to is a usage error, **exit 2**, nothing written; a tag **two** clones answer to is the same error and names both. Never stamped verbatim (R609) |
| O37 | a **newline** in the subject, the reason or the `--ref` is a usage error, **exit 2**, nothing written — a forged `repo:` above the real stamp used to hand the entry to a clone that never touched it (R607) |
| O38 | `list`/`show` and `clear` give the **same** answer about an entry whose last line has **no trailing newline** — both see the `repo:` (R607) |
| O39 | with `cleared.log` unwritable, `clear` **keeps** the entry and exits 3; a passing drain **keeps** the debt; an `add` that would overwrite writes nothing (R610). And a **linked worktree** whose git is unavailable still clears its own entries — the path fallback reads the worktree's `.git` file back to the clone (R608) |

**Rows for R608's FOREIGN verdict, R611, R612 and R613 (2026-09-10, second
repair round). NONE OF THESE EXIST YET** — `test_owed.sh` scored
`ALL PASS (233 checks, 1 skipped)` against the repaired `owed.sh` unaltered,
which says the repair broke nothing and says **nothing whatever** about whether
the new behaviour works. Every row below is unwritten:

| # | check |
|---|---|
| O40 | **R611.** `clear <kind> ../cleared.log`, `../../<file>`, `.`, `..` and `a/b` are each **exit 2**, write nothing and **remove nothing** — with a witness file planted both in the state dir root and outside it, asserted still present. And the two legitimate shapes still clear: a bare id and an `<id>@<tag>` one |
| O41 | **R612.** an update keeps `eyes:1`; `--no-eyes` drops it; `--eyes --no-eyes` is exit 2; an update keeps the standing `ref:` and an explicit `--ref` still wins; `add --repo <theirs>` leaves **their** `ref:` alone; a new entry filed `--repo <theirs>` gets **no** auto ref; an unknown line 2+ survives; and the everyday same-clone re-add prints **no** extra line |
| O42 | **R608 FOREIGN, the discriminator.** In a fixture whose entries are stamped, an unstamped entry written *after* the oldest stamp: `add` refuses **exit 5** and writes nothing, `clear` proceeds with a warning that says it is **not** legacy, `drain` **skips** it and does **not** claim it, `list` and `show` mark it. ⚠ **And it must still refuse after this clone has filed something newer** — the first implementation compared against the *newest* stamp and lost the verdict the moment the ledger moved |
| O43 | **R608 LEGACY, the compatibility half.** Three worlds, and the wording must be byte-identical to the pre-repair wording in all three: a ledger with **no** stamps at all; an entry **older** than every stamp; and a half-armed ledger where the unstamped entries are still the majority. `add` claims, `clear` clears, `drain` claims — exactly as O32 already requires |
| O44 | **R613.** a clone that really moves (`mv` the fixture clone) turns its own entries foreign — `clear` on the user's own debt refused exit 5 — and `restamp --from <old path>` returns them: `repo_via:restamped`, `show` marking none, `clear` accepted. Plus `--dry-run` writing nothing, a pre-image per entry in `cleared.log`, **refusal exit 5 when the `--from` path still holds a `tests/headless/owed.sh`**, `--from here` exit 2, no `--from` exit 2, and an unknown `--from` tag exit 2 with the message naming **`--from`**, not `--repo` |

Each needs a sabotage that turns it red. O9 and O18 especially: they are the two
guarding the rule the whole design exists to protect.

⚠ **A stub copy of `owed.sh` is a different clone.** The existing rows copy
`owed.sh` to `$TMP/bin` beside a stub `run_suites.sh`, and that copy's origin is
whatever `$TMP` resolves to, not this tree. Entries added through `$OWED` and
entries added through `$STUB` therefore belong to two different clones, and
mixing them in one fixture is now a refusal rather than a no-op. The existing
rows happen not to mix them; a new one must not start.

**Sabotage matrix run 2026-08-22** when `rule` landed, 77 checks green:

| variant | predicted red | measured |
|---|---|---|
| `drain` clears the rule list | O18 | 2 rows red |
| rule ids stop deduping | O16 | 4 rows red (O16, O17, O19×2) |
| `_issue_ref` fabricates a path | O21 | 1 row red |
| look count read positionally (`sed 's/.*, //'`) | O18 last row | 1 row red |
| `--eyes` accepted on any kind | O22 | 2 rows red |

No variant was footnoted; every predicted red appeared.

---

## 6. Why `rule` exists — the two-queue split it replaced

Added 2026-08-22, at the user's instruction, after they asked the question the
split could not survive: *"What is the difference? Why isn't it one list? What
is 'the list'?"*

The E questions a driver run emits — "ratify this user-visible change, or revert
it" — are owed by the user **exactly as a look is**. They were living in a
markdown table in `doc/claude/ledger/driver_run_*.md` for one reason: that is
where the run's own results table happened to be. So the person who owed nine
rulings and eight looks had to know which of two files each lived in, and the
assistant referring to "the list" was naming one of two and meaning either.

Worse, **the split does not cut cleanly**. Four of the nine rulings open on the
OP-annotation branch cannot be decided without looking at pixels (R604). A
taxonomy whose two categories overlap in 44% of one of them is not a taxonomy.

What *is* a real difference, and what R603 is built around: a look clears with
no artefact, whereas a ruling clears by landing text in a spec or an issue and
usually code after it. That is an argument for the rule entry being a **pointer**
into `doc/claude/issues/`, not an argument for a second ledger in a second file.
