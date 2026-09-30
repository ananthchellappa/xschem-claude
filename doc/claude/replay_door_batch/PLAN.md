# PLAN — replay_door_batch

Old-list wish item **3**: *"Logging of all user interactions to enable macros and script creation
from log files. WIP - but 25% DONE by Claude Code"*.

Stage R is **already done** — `receipts/R-recon-wishlist.md`, six parallel read-only crews over six
wish-list candidates. Read it before anything else in this batch; it is where the corrections to
every assumption below live.

Opened 2026-09-29 at `e05a9769`. T1 baseline `107/106/0/8` (`tests/results.775219.log` at
`acd30d62`, re-gated green after the `test_ase_optier_0963` flake reddened the first run).

## What the recon established, in one paragraph

The logging **engine is done and safe**: three chokepoints (`dispatch_input_action`,
`context_menu_action`, `perform_action`/`core_log_action`) plus ~254 opt-in sites, and
`replay_action_log` (`src/xschem.tcl`) wraps `source` in the `xschem log_action -suppress
push/pop` depth counter. A recorded log replayed in a fresh process produced a **byte-identical**
log back — a log-idempotent round trip — and 29 suites already drive record→replay per verb.
**But macros are at zero**, because `replay_action_log` has no `actions.csv` row, no menu entry,
no keybinding and no file dialog: the only way to reach it is to type it into the CIW. So the
"25%" figure is simultaneously far too low for the machinery and far too high for the stated
purpose. ⚠ The July 2026 audit doc
`doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` **contradicts
the code in four places** (Ctrl-X, the Delete key, Edit Copy and File Save all DO log; property
edits emit real replayable `setprop … allprops` lines). **Do not cost work off that table.**

## Stage A — give replay a door (issue 1619)

**Deliverable:** working code + fence, uncommitted, receipt `receipts/A-door.md`.

The engine needs a user-reachable entry point. Scope:

* One **`actions.csv`** row, `type=command`, menu `tools`, that reaches a new small Tcl proc.
* That proc runs a file chooser and calls the **existing** `replay_action_log $file`. 
* **No C change.** If you find yourself editing a `.c` file, stop and say why in the receipt.
* Reuse the shipped seam. Do **not** write a second replay path, and do not change
  `replay_action_log`'s own semantics.

Constraints and traps, all from the recon:

* **Replay runs into the CURRENT session** — that is what the shipped seam does and it is this
  batch's decision **D3**, not an open question. The user's ruling on it is filed as `rule/1619`
  and does **not** gate this stage.
* Wording: **terse, acronyms uppercase** (the repo's UI-copy rule). A trailing `...` is the
  convention for an entry that opens a chooser.
* A replayed log **mutates the open schematic**. Say in the receipt whether the whole replay is
  one undo unit or N, and whether you changed that — `add_pin_stubs()` is the precedent for N
  operations under a single `push_undo`.
* ⚠ **`xschem load <path>` logs only on the dialog path**, by design
  (`if(!filename && tcl_braceable(f))` in `actions.c`), so replay does not re-open a chooser.
  **Do not "fix" that.**
* ⚠ **Dialog-opening keys hang a headless probe with no upper bound** (modal `vwait`). Put
  `timeout` on every run and write output to a **file** — under `--pipe` a suite's `puts` may
  never reach your stdout, so a stalled run otherwise leaves you nothing.

## Stage B — close the selection gap (issue 1620)

**Deliverable:** working code + fence, uncommitted, receipt `receipts/B-select.md`.

`select_all()` and `unselect_all()` are the **only wholly unlogged selection primitives**, and
selection is the commonest macro prefix — a recorded macro cannot say "select everything, then act".
The Ctrl-A arm of the legacy `switch (key)` in `callback.c` calls `select_all();` raw, under a
`/* select all ... */` comment and with no log line.

Scope: make both primitives self-log `xschem select_all` / `xschem unselect_all`, guarded by
`actionlog_suppress` exactly like every other self-logging core, plus the legacy-switch arm.

* Red first is easy here: assert the line's **presence in a recorded log** before writing the code.
* ⚠ **Absence of a log line is not absence of coverage** — the recon crew walked into this. Its
  fixture load silently failed (`xschem get instances` = 0 while `file exists` = 1), so every
  selection probe read "not logged" when nothing was selected to act on. **Assert the EFFECT
  alongside the log line**; a bare "no new log line" is uninterpretable.
* ⚠ **A scripted verb is not the interactive path** and badly under-reports: headless `xschem
  <verb>` logged 9 of 20, while the same operations driven through `xschem callback` key events
  logged real commands. Measure the path you are claiming about.
* ⚠ Take chords from **`xschem bindings dump`**, never from memory — the recon lost two first-pass
  "misses" to probing keysym `'o'` (111) where the binding is on `'O'` (79).
* `nolog=1` is **not** a gap: 39 of 166 rows are nolog and most are gesture STARTS logged at the
  gesture END, or dialog rows whose core logs the resolved referent. Do not count them.

## Out of scope, deliberately

**Registering all 29 replay round-trip suites.** They pass today and are blocked only by the
missing `OVERALL: ok` sentinel, but registering them takes T1 from 107/106 to roughly **136/135**
and moves `wc -l`, `blocks=` and possibly `skips=`. CLAUDE.md's adopted policy is the bounded half
— *a suite you add a fence to, you register in the same commit* — not mass registration.

⚠ **So the bounded half still binds:** if your stage adds a row to a suite that is **not** in
`hcases`/`dcases`, you must give that suite the sentinel **additively** (above its `RESULT:` line,
because `summarize_all` publishes a case's LAST `RESULT:` line) and register it in the same change.
Expect that to be **one or two** suites, not 29, and say in the receipt which.

Also out of scope: migrating the 81 legacy `switch (key)` cases onto the binding table, and
continuing the `perform_action` migration past 29 of 323 verbs. That is the open-ended half.

## Driver-retained work (not for crews)

* Issue numbers **1619** and **1620**, minted 2026-09-29 by the two-check procedure; `NUMBERING.md`
  entries and the pointer move.
* Issue files with valid `**STAMP:**` lines (`tclsh tests/headless/issue_stamp.tcl` → ok).
* The solo T1 gate in a fresh `git clone --local --no-hardlinks` at a **short** path,
  `./configure && make` from scratch, zero live-peer lines.
* Commits, commit messages, the push.
* Filing `rule/1619` and judging whether any red is real.
* `CLAUDE.md` baseline update if the case count moves.
