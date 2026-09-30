# RECEIPT A — the action log's replay door (issue 1619)

**Stage:** A · **Crew:** 1 · **Date:** 2026-09-29 · **Tree:** `951e628c`, branch `fluid-editing`
**State:** everything below is **UNCOMMITTED** in the working tree. I did not commit, push, stash,
or run a full T1.

## Headline

The engine was finished; the door was missing; the door is now in. A user reaches replay three ways
that did not exist this morning — **Tools → `Replay action log...`**, the **command palette** (typing
`replay` ranks it first), and the proc `replay_action_log_dialog` — and all of it is fenced by a new
suite registered in **both** `hcases` and `dcases`, **63 checks headless / 65 on the display arm**,
with **twelve sabotages each caught by a named row and none surviving**.

**No `.c` file was touched** (decision D4 honoured; no C change was needed or wanted).

---

## 1. What I changed, by symbol

### `src/actions.csv` — one row

```
tools.replay_action_log,command,tools,Replay action log...,,replay_action_log_dialog,,,Replay a recorded action log into the current session (macro playback),,1
```

Column set copied from **`file.open`** (11 fields: `idle` empty, `nolog=1`), and the row is placed
immediately after **`tools.raise_ciw`**, which is the action log's only other user-facing row. Two
column choices I made rather than inherited, both fenced:

* **`nolog=1`** (row `D8`). `tools.raise_ciw` and `tools.net_hilight_style_editor` — the two rows a
  naive imitation would copy — carry **no** nolog, but both are Tcl-only. Mine opens a **modal
  chooser**, and actions.csv's own header says nolog exists for exactly that: *"place_symbol/
  place_text open dialogs when a log is sourced"*. `file.open` is the precedent. It costs nothing
  today (`set_action_nolog` returns 0 for an id the C registry does not know, and mine is not in it)
  and it is correct the moment anyone adds a C binding for the id.
* **`accel` empty** (row `D9`). A real chord needs a C input-binding entry, which D4 forbids. The
  `accel` column is display-only by its own documentation, so filling it would advertise a chord
  that binds nothing.

### `src/xschem.tcl` — two new procs, one menu line, one global

* **`replay_action_log_run {path}`** — the testable half. Refuses an empty path (chooser Cancel)
  silently, refuses a directory or unreadable file with a CIW line, otherwise calls the **existing**
  `replay_action_log` inside a `catch`, reports the outcome through `ciw_echo`, and returns **1/0**.
  Never raises.
* **`replay_action_log_dialog {}`** — the chooser half. `tk_getOpenFile` with a sticky
  `INITIALLOGDIR` (seeded from `xschem get actionlog_filename`'s directory, so the obvious first
  answer is the log this session is writing), a `.log` filetype filter with an all-files escape,
  title `Replay action log`, then delegates and **propagates** the run half's answer.
* **`$topwin.menubar.tools add command -label "Replay action log..." -command {replay_action_log_dialog}`**,
  placed next to `Net highlight styles...` — the same-menu precedent for a `...` entry that has both
  a csv row and a hand-written menu line. **This line is not optional**: actions.csv's own header
  says only the **File** menu is generated (`build_menu_from_table`), so a `tools` row alone reaches
  the palette and the cheat-sheet but **no menu**. The PLAN's "one `actions.csv` row plus a small Tcl
  proc" would have shipped a door with no menu entry. See §5.
* **`INITIALLOGDIR` added to `tctx::global_list`** next to `INITIALINSTDIR` / `INITIALLOADDIR` /
  `INITIALPROPDIR` / `INITIALTEXTDIR`, so it is per-window-context like every other `INITIAL*DIR`
  instead of being the one that leaks between tabs. Both `save_ctx` and `restore_ctx` guard on
  `info exists`, so a context where it was never set is fine. Fenced by row `P9b`.

`replay_action_log` itself is **byte-for-byte unchanged** (rows `P3`, `P8` assert that), and neither
new proc contains a `source` (row `P6`) — there is no second replay path.

### `src/xschem.tcl` — the reporting channel, and why there is no dialog box

The door reports **only** through `ciw_echo`, never `tk_messageBox`. Two reasons, and the second is
the one that matters:

1. It is the house rule. `doc/claude/specs/net_hilight_style_editor.md` states it in as many words:
   *"see [[ciw-feedback-channels]] — use `ciw_echo`, not `puts`/the statusbar"*. The action log's
   own channel is the CIW.
2. **A modal box would make the door's own failure paths undrivable on every arm that has a
   display.** Rows `R5a`/`R6a`/`R7a`/`C2`/`C3` drive exactly those paths; with a `tk_messageBox` in
   them, the `dcases` arm of this very suite would stall on a modal `vwait` with no upper bound —
   the trap the brief names. The failure would become the one thing no suite could measure.

**I also rejected a `puts` fallback**, and the reason is worth recording: under `--nogui` a product
`puts` lands in the suite's own stdout, and a log whose error text happened to end in the word
`FAIL` would then be scored as a counted failure by `summarize_all`. Injecting arbitrary product
text into a test stream is a hazard, not a convenience.

**Known limit, stated because nothing fences it:** with the CIW pane closed, `ciw_echo` no-ops and an
interactive user sees only the effect. `ciw_create` auto-opens the CIW for interactive sessions, and
`Raise CIW window` is two entries away on the same menu, so this is a corner rather than the normal
case. It is the one user-visible thing in this stage I could not verify by test.

### `tests/headless/test_replay_door_1619.tcl` — NEW, 63/65 checks

Seven bands: `D*` the csv row and its palette visibility, `P*` the procs and their wiring, `R*`
behaviour against the real binary, `C*` **the words the door says** (`ciw_echo` shadowed), `X*` **the
chooser half** (`tk_getOpenFile` shadowed), `L*` the log-side properties in a child with its own
`--logdir`, `M*` the Tools-menu entry. Prints `OVERALL: ok ($npass checks)` — verified against the
tree's own `banner_complete`, not against `run_suites.sh` (see §5).

### `tests/run_regression.tcl` — registered in `hcases` AND `dcases`

Plus a comment block saying why it is in both and why that costs **zero** `skip:` lines.

### `doc/claude/specs/action_logging.md` — new section 3b

The spec had **no section at all** on how a user plays a log back. Section 3b now records the door,
the `nolog` and `accel` decisions, the CIW-not-messagebox decision, and the three properties in §7
below, each with the row that pins it. Both new procs and the suite cite it by path.

---

## 2. The red, verbatim

**Written and run before any product change.** First run of the suite against the unfixed tree
(`tests/headless/run_suites.sh --nogui test_replay_door_1619`):

```
FAIL     | test_replay_door_1619        run 1/1  RESULT: 32 FAILED (8 passed)
         | FAIL: D1 actions.csv has a row with id tools.replay_action_log -> {0} (exp {1}) : FAIL
         | FAIL: D4 the row's command is the chooser proc -> {NO-ROW} (exp {replay_action_log_dialog}) : FAIL
         | FAIL: D8 the row is nolog=1 (a modal chooser must never become a replay command) -> {NO-ROW} (exp {1}) : FAIL
         | FAIL: P1 the chooser proc replay_action_log_dialog is defined -> {0} (exp {1}) : FAIL
         | FAIL: P2 the testable half replay_action_log_run is defined -> {0} (exp {1}) : FAIL
         | FAIL: R1a the door reports success on a good log -> {RAISED(invalid command name "replay_action_log_run")} (exp {1}) : FAIL
         | FAIL: R1b EFFECT: the two logged wires exist (+2) -> {0} (exp {2}) : FAIL
         | FAIL: R2 a replay is N undo units, not one (one undo removes one line's effect) -> {0} (exp {1}) : FAIL
         | FAIL: R5b a syntax error leaves a PARTIAL replay: the 2 lines above it applied -> {0} (exp {2}) : FAIL
         | FAIL: L1a EFFECT: the replay ran in the child (one wire from the fixture) -> {0} (exp {1}) : FAIL
         | FAIL: L2 after a FAILED replay the session still logs (suppress depth balanced) -> {0} (exp {1}) : FAIL
         | FAIL: M1 src/xschem.tcl adds the Tools-menu entry with that label and command -> {0} (exp {1}) : FAIL
RESULT: 0/1 runs passed
```

(32 lines; the ones above are a representative slice. Full transcript:
`<scratch>/A-door/red1.txt`.)

**Note the `RAISED(...)` sentinels.** Every probe that touches a proc which does not exist on the
unfixed tree goes through a `catch` and reports `RAISED(invalid command name "…")` as a legible
value. The suite **failed 32 times and completed**, printing its verdict — it did not throw and
abort at check 8, which is the issue-1616 failure mode the brief warns about.

**Bands `C*` and `X*` were written after the code** (they exist because the first green run showed
me a plausible wrong implementation would survive — see §4, sabotage S7). So I re-created the
no-door tree by renaming both procs away (sabotage **S0**) and observed them red there too:

```
FAIL     | test_replay_door_1619        run 1/1  RESULT: 35 FAILED (28 passed)
FAIL: C1 a good replay is announced and names the path -> {0} (exp {1}) : FAIL
FAIL: C2 a failed replay says it STOPPED and names the path -> {0} (exp {1}) : FAIL
FAIL: C3 a failed replay warns that the lines above it were already applied -> {0} (exp {1}) : FAIL
FAIL: C5 an unreadable path says it cannot be read, not that it was replayed -> {0} (exp {1}) : FAIL
FAIL: C6 a directory says it cannot be read -> {0} (exp {1}) : FAIL
FAIL: X4 the next open starts in the directory last picked from (INITIALLOGDIR) -> {/home/analog/dev/xschem-claude/NO-OPT} (exp {…/.scratch/_replay_door_1619_878384}) : FAIL
FAIL: X5 a vanished remembered directory is replaced, not passed on -> {0} (exp {1}) : FAIL
FAIL: L1a EFFECT: the replay ran in the child (one wire from the fixture) -> {0} (exp {1}) : FAIL
FAIL: L2 after a FAILED replay the session still logs (suppress depth balanced) -> {0} (exp {1}) : FAIL
```

## 3. The green, quoted

| arm | before (unfixed tree) | after |
|---|---|---|
| `--nogui` | `RESULT: 32 FAILED (8 passed)` | `RESULT: ALL PASS (63 checks)` |
| display (`:99`) | — (suite did not exist) | `RESULT: ALL PASS (65 checks)` |

Sentinel, from T1's exact invocation (`env -u DISPLAY ./src/xschem --nogui --pipe -q --script …`):

```
SKIPPED: M2/M3 live Tools-menu rows (no Tk on this arm; M1 grep-guards the same wiring)
RESULT: ALL PASS (63 checks)
OVERALL: ok (63 checks)
```

Scored with the tree's **own** reader rather than with `run_suites.sh`:

```
$ tclsh ; source tests/banner_rule.tcl
banner_complete = 1
banner_died     = 0
case_failed(0)  = 0
```

Counted shapes in that output (`(FAIL|GOLD\?|RESULT\?)$` or `^FATAL`): **0**.
Lowercase `^skip:` lines: **0**. Wall time: **under 1 s on both arms**.

## 4. What I sabotaged, and what reddened

Twelve sabotages, each applied to the real product files, run headless, then restored from a backup
taken before the first one. Patches kept at `<scratch>/A-door/p*.py`, transcripts at
`<scratch>/A-door/sab_S*.txt`.

| # | the plausible wrong implementation | caught by |
|---|---|---|
| S0 | **no door at all** (both procs renamed away) | 35 rows across `P*/R*/C*/X*/L*` |
| S1 | the run half sources the file **inline** instead of calling the seam | `P6`, `P7`, **`L1b`** (the replayed lines get re-logged) |
| S2 | the run half **does not catch** — returns the seam's result raw | `R5a R6a R7a C2 C3 L2` |
| S3 | the door **hand-rolls** `push; source; pop` and loses the pop on error | `P6`, `P7`, **`L2`** (logging stays wedged off for the rest of the session) |
| S4 | `nolog` forgotten on the csv row | `D8` |
| S5 | csv row only, **no Tools-menu line** (the PLAN read literally) | `M1` headless, `M2`/`M3` on the display arm |
| S6 | Tools-menu line only, **csv row forgotten** (no palette, no cheat-sheet) | `D1`–`D12` (12 rows) |
| S7 | the empty-path (Cancel) case dropped — *"`file readable {}` is false anyway"* | **`C7`** only |
| S8 | the partial-state warning sentence dropped as noise | **`C3`** only |
| S9 | the chooser does not remember the directory it picked from | `X4` |
| S10 | the remembered directory trusted without checking it still exists | `X5` |
| S12b | `replay_action_log_run $path ; return 1` — reports success regardless | **`X2c`** only |

**Nothing survived.** Four of the twelve are caught by exactly one row each, and three of those four
rows (`C7`, `C3`, `X2c`) did not exist in my first green version — they were written *because* the
sabotage survived. That is the whole value of the exercise and I would have shipped a weaker fence
without it.

**One sabotage turned out not to be one, and it is worth knowing.** I first wrote S12 as
`replay_action_log_run $path` with the `return` stripped, expecting `X2a` to redden. It passed at 62
checks — because a Tcl proc returns the value of its **last command**, so dropping the `return` is a
no-op here. The real defect is `run …; return 1`, which is what S12b does, and `X2c` exists to catch
it. I have **not** recorded S12 as a surviving sabotage, because it is not a behaviour change.

## 5. What I got wrong during the stage

1. **I believed the PLAN and the recon that "one `actions.csv` row plus a small Tcl proc" was the
   whole door. It is not, and this is the most important correction in this receipt.**
   `src/actions.csv`'s own header says *"Phase 1 seeds the File menu … Other menus are still
   hand-written in xschem.tcl"*, and `build_menu_from_table` is called for the key `file` only. So a
   `tools` row reaches the **command palette** and the **keybindings cheat-sheet** and **no menu at
   all** — which is precisely why `tools.raise_ciw`, the row both the recon and my brief pointed me
   at as the model, has **no Tools-menu entry**: its door is the Alt+F5 chord, not a menu item. Had
   I implemented what the plan said, the "menu entry" the wish item asks for would not exist.
   `tools.net_hilight_style_editor` is the row that has both, and it is the one I imitated. Sabotage
   **S5** exists to keep this from regressing.
2. **My first red suite was a syntax error, in the row designed to test a syntax error.** I wrote
   the malformed-log fixture as a brace-quoted list element `{this is { an unbalanced brace}`, which
   leaves *the suite's own* parser unbalanced — the suite would not have loaded. Caught by reading
   it back before running, not by running it. It is now a quoted string with `\{`, and the code
   comment says why.
3. **I wrote `\Q…\E` in a Tcl `regexp`.** Tcl has no such escape. Row `M1` now matches with
   `string first` against a literal built from `$LABEL` and `$DLG`, which is both exact and legible.
4. **My first `q` helper re-parsed its argument through `uplevel`**, which would have split a scratch
   path containing a space. Replaced by `doorrun`/`dlgrun`, which invoke the proc directly.
5. **I mis-read the recon's log fixture once.** Recording a log with
   `--pipe -q --logdir --script /dev/stdin` echoed *my own script lines* into `Xschem.log`, and I
   briefly read that as `xschem select_all` self-logging (contradicting the recon's finding that it
   does not). It was the pipe's input echo, because `/dev/stdin` made stdin both the script and the
   command pipe. **A recorded log taken that way is not evidence about what a verb logs.** My
   suite's children use a real `--script <file>`, so they are clean.
6. I assumed the display arm would be the risky one. It was not: both arms pass in under a second.

## 6. What I did NOT do, and why

* **No `.c` change** (D4). None was needed. I did check for one: the only thing that would have
  wanted C is a keybinding (the input-binding table is C-side) or an undo barrier (§7.1), and both
  are out of scope.
* **I did not change `replay_action_log`** or add a second replay path (rows `P3`, `P6`, `P8`).
* **I did not "fix" `xschem load <path>`'s scripted silence** (D6). Rows `R7a`/`R7b` describe the
  foreign-schematic consequence and the spec §3b says a dialog-recorded log re-establishes its own
  schematic, so the design is recorded, not altered.
* **I did not register the other 28 replay round-trip suites** (D2). One suite, in both lists.
* **I did not file `rule/1619`.** It is not on the ledger (`owed.sh list` shows no 1619 entry) and
  the PLAN reserves it for the driver. The wording is shipped and fenced; a re-wording costs the
  `$LABEL` constant in the suite plus the csv row plus the menu line.
* **I did not add a `look` debt.** Nothing here needs eyes: the palette row, the menu entry and its
  `-command` are all asserted mechanically, including on a real display.
* **I did not update `doc/claude/specs/wish_list.txt`.** D8 says the line should say what is
  reachable rather than a percentage; that is a batch-close edit and the driver's.
* **I did not run a full T1** (the driver's job, and a concurrent run can redden a gate).
* **I did not repair `doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md`**
  (D5 leaves it as the record of what was believed in July).
* **Could not verify:** the CIW-closed case (§1, reporting channel) — there is no non-modal channel
  left when the pane is gone, and the house rule forbids the two alternatives.

## 7. The three questions

### 7.1 Is the whole replay one undo unit or N? — **N, one per logged line. I did not change it.**

Measured, not inferred. A log of two `xschem wire` lines replayed through the door leaves two wires;
**one** `xschem undo` leaves **one**. Row **`R2`** pins that:

```
ok:   R2 a replay is N undo units, not one (one undo removes one line's effect)
```

So undoing a 50-line macro takes 50 undos. **I did not change it, and it cannot be changed from
Tcl.** Every logged verb pushes its own undo slot inside C; `xschem push_undo` *adds* a slot, it does
not merge the ones the verbs push, so there is no Tcl-level grouping primitive. `add_pin_stubs()` is
indeed the precedent for N operations under one `push_undo` — and it is a **C** function, which is
exactly why the fix is a C-side undo barrier and therefore out of this issue's scope (D4). Row `R2`
is written so that the day someone adds that barrier, this row reddens and says so rather than the
change landing silently.

Follow-up worth a number: a `xschem undo_group push|pop` (or a `replay_action_log` variant that
suppresses intermediate pushes the way `-suppress` suppresses logging) would make a macro one undo.
That is a real usability gap for a macro feature and it is C work.

### 7.2 What happens on a malformed or hostile log file? — **reported, never thrown; and the schematic is left HALF CHANGED.**

Three findings, all fenced:

* **A log file is executable Tcl and `source` evaluates commands one at a time.** So a syntax error
  on line 3 has **already run lines 1 and 2**, and line 4 never runs. Measured: a four-line fixture
  whose third line is an unbalanced brace leaves **+2** wires. Rows `R5a` (the door returns 0, does
  not throw) and **`R5b`** (`a syntax error leaves a PARTIAL replay: the 2 lines above it applied`).
  A runtime error behaves the same way — rows `R6a`/`R6b`, **+1** of 2 possible wires.
* **There is no rollback and the door says so.** The CIW gets two lines, and the second is the one
  the user needs: `# (lines before the failing one have already been applied; undo is per line)`.
  Row **`C3`** asserts that sentence is there; sabotage **S8** (dropping it as noise) reddens only
  `C3`.
* **The failure never escapes as a Tcl error.** The seam re-raises (row `R4c` is the control:
  `the RAW seam THROWS on the same path`), so uncaught from a menu callback it would reach Tk's
  bgerror and show a stack trace to someone who merely picked a file. The door catches. Rows
  `R4a`/`R5a`/`R6a`/`R7a`/`R8a` all assert a plain `0`, and sabotage **S2** (no catch) reddens six
  rows.
* **A failed replay does not wedge logging off.** The seam pops its suppress depth before
  re-raising, and the door catches rather than unwinding past the pop, so the session keeps
  recording afterwards. Row **`L2`**, measured in a child with a real `--logdir`. Sabotage **S3**
  (the hand-rolled `push; source; pop` that loses the pop on the error path) reddens exactly this
  row — it is the most likely wrong implementation of the whole stage and `L2` is the only thing
  between it and a session that silently stops logging.

**On "hostile", as distinct from "malformed": this door does not make that worse, and it does not
make it better either.** A `.log` file is arbitrary Tcl and `source` will run it; the door adds a
chooser in front of a capability the CIW already had. That is the **same** trust question as issue
**0823** (*"opening someone else's .sch runs its code: trusted-path vs prompt vs off-switch"*),
which is already an unratified `rule` debt on the user's queue. I did not extend it to logs, did not
add a trusted-path check, and did not file a second debt for the same question — but a reader
deciding 0823 should know a second executable-file door now exists, and it is one the user opens
deliberately from a menu rather than by opening a design.

### 7.3 What happens replaying a log recorded against a different schematic? — **it aborts at the first line whose referent is absent, with the same partial state.**

Measured with the deterministic case: `xschem setprop instance 3 name X1619` against a schematic
with no instance 3 answers `xschem setprop: instance not found`. In a three-line fixture (wire,
setprop, wire) the replay leaves **+1** wire — the line above applied, the line below did not. Rows
`R7a` (reported as failure) and `R7b` (`it aborts AT the foreign line`).

**Not fixed, and I do not think it should be.** Two reasons. First, a log recorded through the file
dialog normally **opens** with `xschem load {…}` (that is the one path `actions.c` logs, per D6), so
it re-establishes its own schematic and the mismatch does not arise; the exposure is a log recorded
mid-session. Second, the alternative — validating referents before replaying — would need the door
to understand every verb's argument space, which is the whole of `scheduler.c`. What the door
*should* do is make the failure legible, and it does: the CIW names the file, quotes the interpreter's
own message, and says the prefix has already been applied.

## 8. What the next stage must know

1. **The PLAN and the recon are both wrong about the door being one csv row.** See §5.1. If Stage B
   or any later stage adds a user-facing entry to a menu other than **File**, it needs a
   hand-written `add command` line in `src/xschem.tcl` as well as the csv row. `tools.raise_ciw` is a
   misleading model for that; `tools.net_hilight_style_editor` is the right one.
2. **`ciw_echo` and `tk_getOpenFile` are both shadowable**, and shadowing them turns "grep-guarded,
   untestable" into behavioural rows. Bands `C*` and `X*` do it, restore the originals, and assert
   the restore (`C8`, `X6`). Every "this needs a human to press OK" comment in this tree — there are
   at least three (`ase::ui::simdlg_browse`, `wviewer::rawbar_browse`, and the one I nearly wrote) —
   is testable this way for everything except the blocking call itself. **Three of the twelve
   sabotages are caught only by those two bands.** This generalises well beyond issue 1619.
3. **T1 case-count expectation: 107 → 109 cases, 106 → 108 blocks, `skips=` UNCHANGED at 8.** One
   new suite in **both** lists, costing two cases. It costs **zero** `skip:` lines because its only
   display-dependent rows self-skip with an **uppercase** `SKIPPED:`, which `summarize_all` neither
   counts nor counts as a skip. Verified: the headless output has 0 lowercase `^skip:` lines and 0
   counted shapes. Per CLAUDE.md do not check the trailer against 8 as if it were a property — this
   is the fourteenth consecutive 8 and it is still a coincidence of what is registered.
4. **`tests/headless/test_palette.tcl` and `tests/headless/test_action_log_dispatch.tcl` are
   pre-existing `NORESULT` on BOTH arms** — `invalid command name "bind"` / `"focus"`, i.e. they
   need a Tk neither `run_suites.sh` arm gives them. I verified this **against the pristine tree**
   (`git show HEAD:` both changed files swapped in) so it is not mine. Neither is registered in T1,
   so neither can redden a gate. `test_keybindings_help` — the other actions.csv consumer — **passes
   on the display arm** with my row present, which is the positive evidence that the csv change does
   not break the generated views.
5. **The live palette and the live menu were checked on a real display**, since no registered suite
   could do it for me. `DISPLAY=:99`, throwaway HOME, querying the palette with `replay`:
   ```
   palette rows for 'replay': 2
     [0] Replay action log...
     [1] Open last closed                               [Ctrl+Shift+T]
   tools entries: 27
     TOOLS[2] label={Replay action log...} command={replay_action_log_dialog}
   ```
   The new row **ranks first** for the obvious query. Rows `M2`/`M3` fence the menu half of this on
   the `dcases` arm from now on.
6. **Wording, my call, for the user to ratify later.** Menu label **`Replay action log...`** —
   sentence case with the trailing `...`, matching `Net highlight styles...` (the only other `...`
   entry on the same menu) and `Execute TCL command`; no acronym is involved so the
   uppercase-acronyms rule is satisfied vacuously. Dialog title **`Replay action log`** (no ellipsis:
   the `...` promises a dialog, and this *is* the dialog). Help string **`Replay a recorded action
   log into the current session (macro playback)`** — imperative, no trailing period, parenthetical
   gloss, exactly the `tools.raise_ciw` help shape, and it states the D3 semantics (**current**
   session) where a user will actually read it. A re-wording is three edits: the csv row, the menu
   line, and `set LABEL` in the suite.
7. **Three suites that gate the harness itself are green with this change**:
   `test_home_isolation` (116 checks), `test_home_isolation_sh` (90), `test_scratch_home_note` (22).
   Row `G2` does **not** trip on the new suite: it starts child xschems, but it *runs inside*
   xschem, which is the documented exemption (`test_ciw_actionlog_output.tcl` does the same and is
   registered).
8. **Leftovers in the tree that are not mine:** `?? .xschem/` and
   `?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/` were both untracked before this
   stage started. HEAD moved from `e05a9769` to `951e628c` during the stage (the driver committed
   the batch directory).
