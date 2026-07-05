# Issue 0070 — command output / results are not logged to the CIW and log file

**Opened:** 2026-07-02
**Status:** PARTIALLY IMPLEMENTED (2026-07-02). Design chosen (D1 = comment-lines
in the log file) and the output sink landed for the CIW-typed path and menu
picks. Remaining: key-dispatch results and the report sinks (netlist/ERC/check).
See "Implementation status" below.
**Severity:** HIGH (user priority) — the log/CIW records *what was driven* but not
*what came back*, so results, reports, and errors of GUI-driven commands vanish.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit — explicit requirement: "output of commands
must also be logged into the CIW and log file."
**Affects:** `src/ciw.tcl` (`ciw_exec`, `ciw_capture_puts`), `src/util.c`
(`log_action`, `log_action_noecho`, `log_action_echo`); result/report sinks in
`scheduler.c`, `hilight.c`, `check.c`, `xschem.tcl` (`infowindow`, statusbar).
**Related:** [[action-logging]], [[ciw-feedback-channels]]; spec
`doc/claude/specs/action_logging.md` **decision 7**; umbrella 0071.

---

## 1. Symptom / requirement

Command *results and output* should appear in the CIW pane **and** the log file.
Today:
- **Typed CIW commands:** the result/error shows in the CIW pane only; the file
  gets just the command (`xschem log_action -noecho`), or `# failed: <cmd>` on
  error. Results are never written to the file.
- **GUI-driven commands** (menu / key / toolbar / gesture): the result is
  discarded by the caller — it reaches **neither** the CIW pane **nor** the file.
- **User-facing reports** (netlist summary, ERC/`check`, `print_hilight_net`
  lists, `get`, search) go to the separate `.infotext` infowindow, the statusbar,
  or stdout/stderr — never the CIW, never the log.

## 2. Root cause

By design (**decision 7**): results are kept out of the log file so it stays
`source`-able (replaying a results line would error). `log_action` (util.c:394)
writes only the one command line and mirrors that same line to the pane; it never
appends a result. `ciw_capture_puts` (ciw.tcl:153) routes `puts` to the pane only
for the dynamic extent of a *typed* `ciw_exec` — a menu/key `puts` goes to real
stdout. So the result path was never wired to the CIW for non-typed commands, and
the file path deliberately excludes results.

## 3. Design tension to resolve

The requirement conflicts with decision 7 (source-able log file). Options:
- **(a) Results as comments.** Write results/output to the file as `#`-prefixed
  comment lines (e.g. `#= <result>`), so the file stays source-able *and* carries
  output. Mirror the same to the CIW with the `result`/`error` tag.
- **(b) CIW-only for output, file keeps commands.** Echo every command's result
  (and captured `puts`, and the infowindow reports) to the CIW pane regardless of
  how the command was invoked; leave the file as the pure replayable stream.
- **(c) Sidecar.** A parallel `Xschem.out` transcript with results, leaving
  `Xschem.log` replay-pure.

Recommend (a)+(b) combined: CIW always shows input+output; file carries output as
comments. Needs a decision from the user/spec owner before implementing.

## 4. Fix sketch (once policy chosen)

- Add a `log_result`/`log_output` sink (util.c) that writes to the file as a
  comment line and mirrors to the CIW `result`/`error` tag.
- In `ciw_exec`, call it for `$res` and errors (currently pane-only).
- Route GUI command results: capture the `Tcl_GetStringResult` after
  menu/key/toolbar dispatch and feed the sink; redirect the infowindow/statusbar
  report writers (netlist/ERC/check/`print_hilight_net`) to also echo the CIW.
- Keep replay safe: comment lines are ignored on `source`.

---

## 5. Implementation status (2026-07-02)

**Landed (D1 = comment-lines):**
- `log_output(int iserr, const char *text)` (`src/util.c`) writes the result/error
  to the log file as `#= ` / `#! ` comment lines, one prefix per physical line so
  a multi-line result stays source-able. Guarded by `actionlog_suppress`.
- Tcl surface: `xschem log_action -result <t>` / `-error <t>`.
- `ciw_exec` (`src/ciw.tcl`) now records the result (`#=`) and error (`#!`) of every
  typed command to the file, keeping the existing pane echo.
- `menu_action_logged` (`src/action_registry.tcl`) mirrors a menu pick's result to
  the CIW pane and the file.
- Test: `tests/headless/test_selflog_output.tcl` (result/error/multi-line comments
  + source-ability), in `full_audit.sh` `logdir_tests`.

**Remaining:**
- Key-dispatch command results (`dispatch_input_action`) → echo the non-empty Tcl
  result to CIW + `log_output`.
- Report sinks: netlist summary, ERC/`check`, `print_hilight_net` — redirect the
  infowindow/statusbar writers to also `ciw_echo` + `log_output`.
- Toolbar/raw `-command` results (bonus; depends on 0062 wrapping).
