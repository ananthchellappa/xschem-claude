# Issue 0048 — `tcl_braceable()` hand-rolls list quoting and drops the replayable action-log line for brace/backslash names

**Opened:** 2026-06-26
**Status:** OPEN
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
