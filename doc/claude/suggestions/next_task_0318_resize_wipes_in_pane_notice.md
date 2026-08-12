# Task hand-off — issue 0318: resizing the sidebar wipes the sentence inside the empty pane

**Handed off** 2026-08-12 by the driver session that closed issues 0312 and 0315.
**Branch** `fluid-editing`. **Start HEAD** `a34dbf80`. **21 commits are unpushed
and NOTHING MAY BE PUSHED.**

You are the implementer. The driver does no work on this task and will only read
your receipt.

---

## The task

Fix `doc/claude/issues/0318-resizing-the-sidebar-wipes-the-in-pane-notice.md`.

**Read the issue first, whole.** It carries the mechanism with the offending line
quoted, the reachability argument, two candidate fixes with the cost of each, and
a ⚠ saying what a check for this must do. **Do not re-derive it.** Line numbers
in it may have moved — locate by symbol.

One sentence of it: `browserseanote($token)` holds §F item F5's in-pane notice;
its whole lifetime is `set browserseanote($token) {}` at the top of
`browser_sea_refresh`, and the sea canvas's `<Configure>` is wired straight into
that proc — **so a resize is treated as navigation** and the sentence vanishes.

**The user reported it by hand, verbatim:** *"When you drag to make it really
narrow, the sentence vanishes from the signal pane. Doing select of a1 in tb1.sch
and CTRL-ALT-V again displays it again."*

### The ruling you have, and the one you do not

The issue lists two fixes: **save/restore around the `<Configure>` trampoline**
(one line, closes the reported symptom exactly) or **split the clear out of
`browser_sea_refresh` into the callers that really are navigations** (the honest
shape, but every caller has to be classified). **The issue itself says splitting
is the honest shape.**

**This is your call to make and defend in the receipt** — the user has not ruled
between them, and does not want to be asked for one here. Pick one, and if you
pick save/restore, say in the receipt why the split was not worth its cost, with
the caller count you measured. If you pick the split, **classify every caller of
`browser_sea_refresh` explicitly in the receipt** — one line each, navigation or
not — because an unclassified caller is how this comes back.

### Scope

* **In scope:** `src/wave_viewer.tcl`, a regression test, the receipt, the issue's
  Status line.
* **Out of scope:** issue 0319 (a different crew has it or will), issue 0313
  (same family — a refused gesture emptying the sidebar — but a separate defect),
  and anything about the *wording* of the F5 sentence. The user has an owed
  eyeball on that wording (`doc/claude/batch_F/EYEBALL_QUEUE.md` item 5 step 7)
  which is **blocked behind this fix**; do not pre-empt it by rewording.
* If you find a third door onto the same "a geometry event is treated as
  navigation" shape, **file it as a new issue** rather than widening this one.

---

## Non-negotiables — every one of these has cost this project a session

1. **No `make` needed** — this is Tcl only. If you somehow touch C: **NEVER run
   `make` while any suite is running**, it starves the CPU and the headless
   suites flake in a way that reads as a regression.
2. **⚠ AN AUDIT IS RUNNING RIGHT NOW** in the driver session (`full_audit.sh`,
   started 2026-08-12 ~08:20). **Before you run ANY suite**, wait for it:
   ```sh
   while pgrep -af 'bash tests/headless/full_audit' >/dev/null; do sleep 60; done
   ```
   Use that exact pattern — a bare `pgrep -f full_audit` **matches your own Bash
   tool wrapper** and answers "yes" forever. Until it clears, do read-only work:
   read the issue, read the procs, write the fix plan, draft the checks.
3. **GUI gate.** `GUI_GATE=1` **always** — never `GUI_GATE=0`, that disables the
   user's control panel. Run suites through `tests/headless/run_suites.sh` or
   `tests/headless/gated_xschem.sh`. **Never a bare `for` loop** — the panel
   cannot pause it, and it will list your processes as `UNGATED`. An approval
   window is open until roughly **09:40**; if it has lapsed the panel will ask
   and you wait for the user.
4. **Display health first:** `bash tests/headless/wslg_health.sh`. A `STUB`
   verdict means every GUI result in that run is meaningless (issue 0310). The
   WSLg X server dies ~3x a session and kills every client; a whole-suite
   `NORESULT` is that, not your bug.
5. **`tests/headless/test_wave_sigbrowser.tcl` is FROZEN** (ruling 30). Do not
   edit it. `_i14`, `_i1315`, `_panes`, `_sea`, `_2pane`, `_keys`, `_digital`,
   `_sigsearch`, `_0312`, `_0315` are amendable. A NEW `test_*.tcl` is picked up
   by `full_audit.sh` automatically.
6. **Do not push. Do not touch issue 0319.**

---

## Definition of done

1. **The symptom is gone**: the sentence survives a resize of the pane.
2. **A check that would have caught it.** ⚠ The issue is explicit about the shape:
   **resize the pane and then read the CANVAS ITEM, not the variable** —
   `browserseanote` is what survives, the drawn `seanote` tag is what the user
   sees. `bs_wait_mapped` plus `$c find withtag seanote` is the idiom. **A source
   grep cannot see this defect**: every line involved is already there and
   individually correct.
3. **SABOTAGE EVERY NEW CHECK.** One mutation per claim, applied to the source,
   suite re-run, the ids it reds recorded in a table in the test file's header. A
   check with no sabotage is not evidence. **Expect the battery to find a hole** —
   it has every time; record what it found rather than quietly fixing it.
4. **Adversarial review by agents that are NOT the implementer**, two lenses:
   one on Tk/Tcl event-lifetime correctness, one on evidence quality (what could
   be broken while every check stays green). Fix confirmed findings; record them
   in the receipt with their triage. On the two issues just closed this pair found
   five live defects behind a fully green suite — budget for that, do not treat
   review as a formality.
5. **Suites**: the sigbrowser family, each re-run whole —
   `test_wave_sigbrowser`, `_sea`, `_panes`, `_2pane`, `_i12`, `_i14`, `_i1315`,
   `_keys`, `_digital`, `_0312`, `_0315`, plus `test_ase_cosim`. Then
   **`full_audit.sh`**, reported as a **DIFF against
   `doc/claude/batch_F/baseline_status.txt` by test NAME and STATUS, never by red
   count**. **Re-run every red-ward row standalone** before calling it a
   regression. Known flake classes that are NOT regressions: whole-suite
   `NORESULT` inside a batched sweep, `test_wave_modes` `MG13` (key delivery),
   `test_wave_sigbrowser_i1315` `BP72` (`:0` geometry echo), `test_wave_markers`
   `MX7b`/`MX7d`, `test_ase_plot` P4/P6/P8, `test_placement_wire_gate` TIMEOUT
   (TIMEOUT in the baseline too).
6. **Receipt** at `doc/claude/batch_F/receipts/18-issue-0318-resize-wipes-the-notice.md`
   — the fix and WHICH candidate you chose with why, the sabotage table, the
   review findings and their triage, the suite results, the audit diff, and an
   explicit **"what this does not claim"**.
7. **Commit** (conventional-commit subject, body says *why*, not *what*).
   **DO NOT PUSH.**
8. Update the issue's `**Status:**` line to FIXED with the commit SHA — and if the
   fix cannot be verified without a human looking at the pane, say
   **FIXED pending an eyeball** and write the exact steps a human should follow.

## Handy context

* Fixture: `sh doc/claude/batch_F/eyeball_fixtures.sh` builds
  `/tmp/xschem_eyeball_F`. **Do NOT `rm -rf` it** — the user has owed eyeballs
  standing on it. `EYEBALL_QUEUE.md` item 5 steps 1-6 are how the notice gets on
  screen in the first place.
* Standalone run of one suite:
  `GUI_GATE=1 DISPLAY=:0 bash tests/headless/gated_xschem.sh --pipe -q --nolog --script tests/headless/<t>.tcl`
* The shared sigbrowser prelude is `tests/headless/wvbs_common.tcl` (`check`,
  `pcall`, `bgerror`, `wvproc_body`, `bs_wait_mapped`, `$wsrc`, `wvbs_finish`).
  A new file sets `::wvbs_tag` / `::wvbs_name` and sources it. **A helper must
  never be named `test_*.tcl`** — `full_audit.sh` would run it as a case.
* Precedent worth copying, both landed this session:
  `doc/claude/batch_F/receipts/17-issue-0315-one-gesture-one-ciw-account.md`
  (how a ruling, a sabotage table and review triage are written up) and
  `tests/headless/test_wave_sigbrowser_0315.tcl` (how the real command is driven
  headlessly with only the design-side reads stubbed — the `fd_drive_on` idiom
  from `test_wave_sigbrowser_digital.tcl:833`).
