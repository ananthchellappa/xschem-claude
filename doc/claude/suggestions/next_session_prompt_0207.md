# Session prompt — issue 0207: ASE's CIW messages must reach the log file

Paste everything below the line into a fresh session, from the repo root
`/home/analog/dev/xschem-claude`, on branch `open_pdk`.

---

Read `doc/claude/issues/0207-ase-ciw-messages-never-reach-the-log-file.md` in full first.
Then `doc/claude/specs/action_logging.md` (the source-ability invariant and the comment
convention) and `doc/claude/issues/0204-sod-pick-mutates-the-selection.md` "What is
deliberately left undone" item 1, so you know which half of the problem you are NOT solving.

## The job

In Ctrl-4 "select signals to plot" mode, every pick prints to the CIW:

```
ase: queued trace 'v(x1.minus)'
ase: Direct Plot — 3 trace(s) queued
```

None of it reaches `Xschem.log`. The reason is established in the issue: `ciw_echo`
(`src/ciw.tcl:113`) is a pure Tk widget append, and the log file is written only by C
`log_action()` (`src/util.c:489`), which **mirrors into** the CIW afterwards
(`log_action_echo`, `util.c:424`). The pane is the log's mirror; ASE writes to the mirror.
`ase_window.tcl` has 60 bare `ciw_echo` calls and `ase.tcl` 21, against 3 `log_action`
references total — so ~80 user-visible messages are pane-only by construction.

Make ASE's user-visible messages land in the action log as **source-able comment lines**,
without breaking replay and without touching what the log means.

## Scope — deliver (A), do not drift into (B)

**(A) is the deliverable.** Informational ASE messages appear in `Xschem.log` as comments.

**(B) — a *replayable* line for the pick itself (0204's left-undone item 1) — is NOT in
scope.** A `#=` comment is not replayable by design, and the altitude question (gesture vs.
outcome level) is unresolved; the issue's D5 lays out the fork and the two hazards that kill
the gesture-level form (a bus pick opens a modal dialog; a suspended mode can resume onto a
different canvas, issue 0201). If you have a view, write it up as issue 0208 — do not
implement it here.

## Step 1 — reproduce it, and confirm which file

Do not skip. The issue is established by reading; nothing in it is measured.

The action log path at runtime is `xschem get actionlog_filename` (empty when logging is
off), and it is what the CIW puts in its title bar. Run a real Ctrl-4 pick under
`--logdir`, then show that the CIW pane contains the two lines and the file does not.

Note before you start: `--nolog` disables the action log entirely, and a `--nogui` run with
no `--logdir` writes none either — so the harness needs `--logdir`
(`tests/headless/run_suites.sh --logdir <name>`, and `tests/headless/test_select_at.tcl` is
the established `--logdir` harness to copy). Run GUI work under the test gate
(`run_suites.sh` / `gated_xschem.sh`, never a bare loop — CLAUDE.md), and press
`Allow 30m` once rather than clicking Proceed repeatedly.

## Step 2 — the fix

The issue's D1-D4 are the decisions. Recommended shape, but say which you took and why:

- **A seam, not a tee.** Add `ase::echo {msg {tag {}}}` (mirroring
  `wviewer::log_action`, `src/wave_viewer.tcl:2136-2140`) that does the pane echo *and* the
  file write, then substitute the bare `ciw_echo` calls in `ase_window.tcl` / `ase.tcl`.
  **Teeing inside `ciw_echo` is a trap**: `ciw_echo` is also the sink `log_action_echo`
  calls for lines that are *already* in the file, so a naive tee double-writes every action
  line. If you tee anyway, it needs a re-entrancy guard.
- The existing "both places" idiom is `src/action_registry.tcl:199-200`:
  `ciw_echo $err result ; xschem log_action -result $err`.
- Preserve the `catch` wrapping (a broken message must never break a pick) and stay correct
  when Tk is absent, when logging is off, and when both are.

**Landmine, and it is directly in the API you are about to call from ~80 sites:** every flag
arm of the `xschem log_action` dispatcher is gated on `argc > 3`, so `xschem log_action
-result` with a **missing value** falls through to the bare-line arm and writes the literal
line `-result` into `Xschem.log` — which then aborts a replay `source`. An empty message
variable would therefore corrupt the log rather than log nothing. Guard on `$msg ne {}` in
the seam. Fixing the arity check in C is optional but welcome; nothing covers it today.

Merge note: `src/ase_window.tcl` is owned by the `fluid-editing` branch, which is actively
editing the waveform viewer. This change touches many lines in that file by nature — keep it
mechanical and uniform (one substitution pattern, no reflowing, no reordering) so the
conflict resolution is trivial. Do not touch `src/wave_viewer.tcl`.

## Step 3 — tests

These pin the log's format and must stay green:

```
tests/headless/test_ciw.tcl                    # the whole file must `source` cleanly
tests/headless/test_selflog_output.tcl         # every logical line: `#` comment or `xschem `
tests/headless/test_selflog_grep_guard.tcl     # no hand-logged self-logging verbs
tests/headless/test_actionlog_suppress_gate.tcl
tests/headless/test_select_at.tcl              # needs --logdir
tests/headless/test_ase_plot.tcl               # see the known-failure note below
tests/headless/test_ase_interact.tcl
tests/headless/test_ase_unnamed_net.tcl
```

Add a new test with its own leg IDs (prefixes `AN BB LK HP PH P PL CR CS DS VN I HL SO` are
taken; `PS NM RP` are free) asserting at minimum: a Ctrl-4 pick's message appears in
`Xschem.log` as a comment line; the file still `source`s without error afterwards; the pane
still gets it too; and an empty message logs *nothing* rather than a stray flag line.

Several ASE tests stub `ciw_echo` to capture notices (`test_ase_locked_wire_pick_0160.tcl`
renames it; `test_ase_unnamed_net.tcl:139-140` too). If you route ASE through a new seam,
those stubs may stop intercepting — check each and update deliberately, saying which and why.

**Sabotage-verify.** Break the seam (drop the `log_action` half; then drop the `ciw_echo`
half) and confirm the new legs go red, and say which. A leg that stays green under sabotage
is not testing anything.

## Known-failing before you start

`tests/headless/test_ase_plot.tcl` P4/P6 fail on `open_pdk` **already** — six legs,
reproduced with the 0204 change stashed and the tree rebuilt. That is
[0206](../issues/0206-ase-plot-p4-direct-plot-click-queues-nothing.md), not you. Do not
chase it, and do not let it mask a real regression: compare against the baseline.

Two harness quirks that look like failures and are not: `test_select_at` reports 5 false
failures ("action log open") unless run with `--logdir`; `test_hi_descend` prints its own
banner instead of `RESULT:`, so `run_suites.sh` scores it `NORESULT` — run it directly.

## Step 4 — write it up

Update `doc/claude/issues/0207-*.md`: status, what Step 1 measured (including anything that
contradicted the issue), which of D1-D4 you took and why, the sabotage table, and what you
deliberately left undone. Add the missing ASE row to
`doc/claude/specs/action_logging_checklist.md` — ASE/Direct Plot/signal picking appears in
**no** row of it today, which is why this went unnoticed. Do not commit unless asked.

While you are in there, two unrelated one-line defects the investigation turned up (fix or
file, your call, but do not lose them):

- `xschem get actionlog_filename` is handled twice in `scheduler.c` — the live one under
  `case 'a':`, and a byte-equivalent dead copy under `case 'c':` the first-letter switch can
  never reach.
- `src/xschem.help` still documents the action log's default location as the current working
  directory; `util.c` moved it to `$TMPDIR`/`/tmp` in issue 0038.

## Context you will want

- Branch `open_pdk` = `fluid-editing` + the 0200/0201/0204 work. Number any new issue from
  **0208**; the `fluid-editing` agent owns the 0188-01xx range.
- `src/xschem` in-tree is the binary the tests use. **`/usr/local/bin/xschem` on `PATH` is
  from January 2025 and has none of this work** — never test against it.
- Three separate streams, do not confuse them: the **action log** (`Xschem.log`, what this
  issue is about), the **debug stream** (`errfp`; `-d` gates `dbg()`, `-l <file>` captures
  it — and a detached GUI launch `freopen`s stdout+stderr to `/dev/null`, so without `-l` it
  is silently discarded), and the **info window** (`.infotext`, fed by `statusmsg(str,2|3)`,
  where netlist/ERC output goes — a different toplevel from the CIW, and never on disk).
