# Spec — the owed ledger

*Two debts that need the real screen, recorded when they are incurred and paid
in one batch instead of dozens of interruptions.*

Status: implemented. `tests/headless/owed.sh`, tests in
`tests/headless/test_owed.sh`.

Related: `doc/claude/specs/dev_display.md` (why routine testing no longer takes
the screen at all), `doc/claude/specs/gui_test_gate.md` (the panel, and its
`Forever` grant).

---

## 1. The problem

After the dev-display work, no test *requires* `:0` — a full audit under Xvfb
reproduces the `:0` verdict set exactly. What remains are two obligations that
still cost the user's attention, and both arrive at the worst possible cadence:
**scattered, one at a time, whenever a feature happens to finish.**

| | suite owes a `:0` run | item owes the user's look |
|---|---|---|
| where it comes from | `CLAUDE.md`: "run a GUI feature's suite on `:0` once before calling it done" | `pixel-deliverables-need-eyeball`: "the report is *suites green, please look* — not *done*" |
| who performs it | a script | **the user** |
| verdict | PASS/FAIL, machine-readable | judgment |
| clears itself | **yes**, on a pass | **never** — only the user clears it |
| what it needs | the real display | *the user's attention*; a VNC view of `:99` serves equally |

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
owed.sh add   suite <name> [why]     # a suite owing a :0 run
owed.sh add   look  <what> [why]     # something owing the user's eyes
owed.sh list  [suite|look]           # what is queued, and since when
owed.sh drain [--display :0]         # run the SUITE debts, one batch, one gate
owed.sh show                         # the LOOK debts, formatted to read aloud
owed.sh clear look <id>              # only the user clears a look
owed.sh clear suite <id>             # escape hatch: abandon a suite debt
owed.sh count                        # "3 suite, 2 look" — for status lines
```

State: `${XSCHEM_OWED_DIR:-$HOME/.claude/xschem_owed}`, under `$HOME` so one
ledger serves the main session and every worktree — the same argument that put
the gate dir there.

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
- **R104** An unknown kind is an error, not a third list.
- **R105** Entries survive across sessions and reboots.

### R2 — reading

- **R201** `list` shows both lists with ids, ages in days, and reasons.
- **R202** `list <kind>` shows one.
- **R203** `count` prints a single machine-readable line.
- **R204** An empty ledger says so and exits 0. Nothing owed is a normal state.

### R3 — draining the suite debts

- **R301** `drain` runs every queued suite through `run_suites.sh` with
  `AUDIT_DISPLAY` set to the real display (default `:0`, overridable), so the
  gate is live and the user keeps Pause/Stop.
- **R302** A suite that **passes** is removed from the ledger.
- **R303** A suite that **fails** stays, with its failure recorded, so a drain
  cannot be a way to lose work.
- **R304** `drain` prints a summary: how many ran, passed, failed, remain.
- **R305** `drain` never touches the `look` list. Not even to reorder it.
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

### R5 — not lying

- **R501** Every command exits non-zero on real failure.
- **R502** Nothing is written outside the state dir.
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
| O15 | a name with neither extension: non-zero exit, **both** candidate paths named, runner never invoked, debt kept and marked as misnamed (R309); plus a **path-shaped** and an **already-suffixed** name, whose message must name the **one** path really stat'd, with neither the directory nor the extension doubled |

Each needs a sabotage that turns it red. O9 especially: it is the one guarding
the rule the whole design exists to protect.
