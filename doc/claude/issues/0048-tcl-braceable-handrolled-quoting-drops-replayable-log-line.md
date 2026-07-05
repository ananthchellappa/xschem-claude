# Issue 0048 — `tcl_braceable()` hand-rolls list quoting and drops the replayable action-log line for brace/backslash names

**Opened:** 2026-06-26
**Status:** FIXED 2026-07-02 (`fluid-editing`). Added a `log_action_argv(argc, argv)` helper in
`src/callback.c` that emits a replayable command via `Tcl_Merge` (quotes EVERY element into a valid,
re-parsable list), and rebuilt the `PLACE_SYMBOL` and `PLACE_TEXT` emit paths on it with the numeric
fields pre-formatted — dropping the `tcl_braceable` guard on those two paths (the function stays for the
6 load-path callers, a possible later sweep). A name/prop with braces/backslashes now stays replayable
instead of degrading to a `# place symbol …` comment. **Log-format change**: emit now uses Tcl_Merge
MINIMAL quoting, so a plain sym name / text is no longer always brace-wrapped (`xschem instance
lab_pin.sym …`, not `{lab_pin.sym}`) — two existing gesture-log assertions were updated to match.
Test: `tests/headless/test_gesture_end_log.tcl` §7b (place a symbol with `lab=A\{B\}C\\D` prop, assert
the line is logged, not a comment, and replays to the EXACT prop) — sabotage-verified RED on the old
`tcl_braceable` path (placement dropped to a comment), GREEN after. (Pre-existing rect-gesture flakiness
under WSLg is unrelated.) **Prior triage** (2026-07-01): verified STILL PRESENT (`callback.c`; `Tcl_Merge` used nowhere yet). Confirmed **LOW** (replay fidelity only; degrades to a `#` comment — no corruption). **Priority P3.**
**Severity:** LOW — action-log replay fidelity (a placement is silently dropped on replay), no live-edit
effect.
**Branch:** `fluid-editing`.
**Source:** `/code-review high` this session (workflow `wf_1a6ce6c4-0d9`), finding #10 (CONFIRMED).
**Affects:** `src/callback.c` `tcl_braceable()` (~:1482) and `end_move_copy_logged()` (~:1524).
Related: [[action-logging]].

---

## 1. Symptom

An instance name or property string containing a backslash or brace (legal in xschem properties — e.g.
Windows paths, escaped tokens) makes `tcl_braceable()` return false, so `end_move_copy_logged()` writes a
non-replayable `# place symbol (instance not cleanly recordable)` comment instead of a real
`xschem instance …` line. Replaying the action log silently drops that placement.

## 2. Root cause

`tcl_braceable()` hand-rolls Tcl list-element quoting — it only checks for `{`, `}`, `\` and bails — and
emits the value inside literal braces. The Tcl C API already linked by the codebase (`Tcl_SplitList` is
used elsewhere) provides `Tcl_Merge()` / `Tcl_ConvertElement()`, which quote *any* string into a valid,
re-parsable list element.

## 3. Fix sketch

Build the replayable line with `Tcl_Merge()` (or `Tcl_ConvertElement()` per field) instead of the
brace-wrap + `tcl_braceable()` guard, so a name/prop with braces/backslashes is correctly quoted and the
line stays replayable. Add a test: log a placement of an instance whose name contains a brace, replay,
and assert the instance is recreated.

## 4. Acceptance

Action-log placement lines are replayable for any legal instance name / property string, including ones
containing braces or backslashes.
