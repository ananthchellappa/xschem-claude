# Casemode batch — crew brief

Read this **first**, before the item scope. It carries the traps that have
already cost this batch real time, and the decisions you are not allowed to
re-open. It is in every item's `load` list on purpose.

Companion state: `LEDGER.md` (batch state, baseline, re-grepped line numbers),
`DECISIONS.md` (the 13 rulings), `DESIGN_REVISION.md` (the read-path redesign),
`PLAN.md` **§3b** (the authoritative item list).

---

## 1. Base, baseline, and how an audit is judged

- Base HEAD **`577ef5bc`** (docs commit `f7ab5f65` on top). Branch
  `fluid-editing`. **Nothing is pushed and nothing may be pushed.**
- Baseline audit, already taken, debt discharged:
  `doc/claude/merge5_loose_ends/audit_item02_fixround_2026-08-16.txt`
  — **316 pass / 15 fail / 0 crash-timeout / 0 skip of 331**, at `577ef5bc`, on `:99`.
- **Judge every audit by DIFFING that file by test NAME and STATUS, never by
  the red count.** `batch_F/baseline_status.txt` (285/19/1) is **VOID** — shot
  with the pre-rework scorer. Do not diff against it, cite it, or average it in.
- **Default is `fold` at every stage, so the audit diff for items 1–9 must be
  EMPTY.** `receipts/00a-suite-sweep.md` establishes that contract: zero rows
  move, in either direction. **If a row moves, that is a finding** — stop,
  explain it, do not accept it as noise.

## 2. What you may not do

- **Do not re-open any decision in `DECISIONS.md`.** Thirteen rulings, settled
  with the user 2026-08-16, one question at a time. Four of them overturned the
  plan's own recommendation and the reasoning is recorded. If one looks wrong,
  say so in your return value — do not quietly choose differently.
- **Do not work from `PLAN.md` §3 or §4.** Both superseded, both marked in
  place. The wrong text is deliberately kept because it is why this batch was
  misled for four days. §3b is the authoritative item list.
- **Do not treat `PLAN.md` line-number citations as current.** Merge 5 moved 30
  pointers. `LEDGER.md` carries the re-grepped table; **re-grep anything not in
  it.**
- **Do not add a mode branch where the design says the mode should disappear.**
  Item 5b's whole point is that backannotation ends up with **no** mode-aware
  code: the query carries the schematic's own spelling and the one lookup
  authority resolves it.

## 3. Environment

- Dev display **`:99`** is up (1920x1080x24, openbox); the gate is armed
  `forever`. `full_audit.sh` and `run_suites.sh` self-arm to it. A bare
  `./src/xschem --script` does **not** — route it as
  `tests/headless/devdisplay.sh exec ./src/xschem …`. Never a bare
  `for … do ./src/xschem … done` loop: it enrols in no gate, the user cannot
  pause it, and the panel lists it as `UNGATED`.
- **Case-capable ngspice:**
  `/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice`. This is the **user's
  own fork** (branch `ver_50`, real ngspice as `upstream`), so **it keeps
  moving — three times in four days**; the stamp as of 2026-08-16 is
  `Sun Aug 16 06:52:46 UTC 2026`.
  **Assert on `$curcasemode` and on measured output, never on "this build has
  fix X in it". Every test needing it must SKIP, not fail, when it is absent.**
- **Baseline ngspice:** `/usr/local/bin/ngspice` (46). Folds always, **accepts
  and ignores** `-D casemode=`, has no `$curcasemode` (replies
  `Error: curcasemode: no such variable.`) — which is exactly the capability
  probe.
- Re-run `repro3/run_r3b.sh` and `repro2/run_round2.sh` (seconds each) if
  anything about the enabler looks off. They are the only thing that tells you
  the binary moved under you.
- **Check `doc/claude/ngspice_upstream/feedback/` for a round-4 drop before
  starting items 3, 10 or 14.** Latest is 2026-08-15 12:31. Last time, checking
  first deleted an entire planned migration pass.

## 4. Traps — every one of these has already cost real time

- **`render_deck`'s shape is the only shape that matters.** Analyses are
  control commands: **no dot card, no `run`**, bare `write <abs path>` with
  **no vector list**. A measurement taken on any other deck shape is a
  measurement about another program. This is what made PLAN §0b item 1 wrong
  for four days.
- **Never name vectors on a `write` line** (upstream `0073`, unfixed): it
  writes two identical columns with byte-identical names, which no filter can
  separate. `render_deck` complies today; **items 10 and 12 must not change
  that.**
- **Never emit both a `set` and an `unset` of the same simulator variable** —
  SIGABRT, rc=134, on stock too. Emitting only `set` is safe.
- **The probe hangs without `quit`** — two minutes, measured live. Item 7's
  hard timeout is not optional.
- **`~/.spiceinit` overrides `-D casemode=` too**, not just one beside the
  deck. Probe with the real argv **and** cwd = the deck's own directory.
- **SPICE decks need a title line.** A deck whose first line is a card loses
  that card silently. One whole round of measurements died this way.
- **Raw files are binary — `grep -a`.**
- **`write` inside `.control` is cwd-relative.** `fixtures/tr_source.cir`
  writes `tr_MODE.raw` into the *caller's* directory; `-r` does not override
  it. Run fixtures from a scratch dir.
- **`$?` is clobbered by a `$(…)` between the run and the check.** Capture
  `rc=$?` on the very next line.
- Always use `test_scratch` (`tests/headless/scratch.tcl`); never leak a
  scratch dir into the repo.

## 5. The two open items, neither blocking

- **Xyce is unverified.** `PLAN.md` asserts Xyce writes `V(EN)` uppercase;
  there is no Xyce on this machine and it has never been measured. Item 1 must
  either measure a real Xyce raw or keep a Xyce-specific fold. A Xyce-shaped
  branch already exists (`:` → `.`, `save.c:1010`).
- **The one ver_50 ask worth making** (not this batch's to make): send the
  written-but-unsent `cp_remvar` patch that makes `casemodewrite` default on.

## 6. Fixtures already committed

- `fixtures/tr_fold.raw` — tran, nets `In`/`MidNode`, source `Vs`, written
  under `-D casemode=fold`. Variables: `v(in) v(midnode) i(vs)`.
- `fixtures/tr_preserve.raw` — the same deck under `-D casemode=preserve`.
  Variables: `v(In) v(MidNode) i(Vs)`.

Both are 229-point binary raws, byte-comparable, differing **only** in the
Variables section — so items 1–5 can be tested with no ngspice present at all.
They are the only tracked `.raw` files in the repo, and **no test reads either
of them yet** (`receipts/00a-suite-sweep.md`, finding 1).
