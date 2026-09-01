# Spec — the owed ledger

*Everything a piece of work still owes — the user's rulings, the user's eyes,
and a real-screen run — recorded when it is incurred and paid in one batch
instead of dozens of interruptions.*

Status: implemented. `tests/headless/owed.sh`, tests in
`tests/headless/test_owed.sh`.

**Three kinds since 2026-08-22.** `rule` joined `look` and `suite` at the user's
instruction — see §6 for why, and for what the split it replaced was costing.

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
owed.sh add   rule  <id> [why] [--eyes] [--ref <path>]   # a ruling owed by the user
owed.sh add   look  <what> [why]     # something owing the user's eyes
owed.sh add   suite <name> [why]     # a suite owing a :0 run
owed.sh list  [rule|look|suite]      # what is queued, and since when
owed.sh drain [--display :0]         # run the SUITE debts, one batch, one gate
owed.sh show                         # the USER'S QUEUE (rule + look), read aloud
owed.sh clear rule <id>              # only the user closes a ruling
owed.sh clear look <id>              # only the user clears a look
owed.sh clear suite <id>             # escape hatch: abandon a suite debt
owed.sh count                        # "9 rule, 2 look, 3 suite" — for status lines
```

**`count` prints in `rule, look, suite` order and every consumer selects by
name.** The one consumer that did not — `drain`'s "look debts untouched",
written as `count | sed 's/.*, //'`, i.e. *the last field* — silently began
reporting the **rule** count the moment a third kind existed. Guarded by O18.

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
- **R302** A suite that **passes** is removed from the ledger.
- **R303** A suite that **fails** stays, with its failure recorded, so a drain
  cannot be a way to lose work.
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
- **R602** Rule entries are **deduped by id**, like suites and unlike looks. A
  ruling *is* its issue number; re-adding `0444` restates one open question,
  and two `0444` entries would let the user answer one and still see the other
  standing.
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
| O16 | `add rule` records; re-adding the same id updates rather than duplicates, newer reason wins (R601/R602) |
| O17 | the **three** lists stay apart — a ruling is not in the look list or the suite list, and vice versa |
| O18 | **`drain` does not touch the RULE list** (R305/R605) — O9's twin, and the row that exists because `rule` arrived *after* O9 was written. Also pins the positional-`count` defect: the fixture keeps 2 looks against 1 rule so a last-field read prints the wrong number under the look label |
| O19 | `clear rule` is the only thing that closes a ruling; `clear look <rule-id>` is an error and leaves it standing (R605) |
| O20 | `--eyes` is marked in `list` and stated in `show`; an untagged ruling is not marked (R604) |
| O21 | a 4-digit id auto-resolves to its issue file; `--ref` is kept verbatim; an id with **no** issue file gets no ref rather than an invented one (R603/R603a) |
| O22 | `--eyes` on a `look` or a `suite` is an error, not a silent no-op (R604) |
| O15 | a name with neither extension: non-zero exit, **both** candidate paths named, runner never invoked, debt kept and marked as misnamed (R309); plus a **path-shaped** and an **already-suffixed** name, whose message must name the **one** path really stat'd, with neither the directory nor the extension doubled |

Each needs a sabotage that turns it red. O9 and O18 especially: they are the two
guarding the rule the whole design exists to protect.

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
