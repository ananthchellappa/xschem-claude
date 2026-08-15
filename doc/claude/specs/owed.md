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

### R4 — the look debts

- **R401** `show` prints the look list in a form meant to be read to the user:
  what to look at, why, and how long it has been waiting.
- **R402** **No command clears a look entry except `clear look <id>`.** Not
  `drain`, not a green suite, not age.
- **R403** `show` states plainly that these need a human, and suggests the
  cheapest way to serve them (`devdisplay.sh view`, or `:0` if the point is
  WSLg-specific rendering).

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

Each needs a sabotage that turns it red. O9 especially: it is the one guarding
the rule the whole design exists to protect.
