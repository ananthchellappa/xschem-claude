# Issue 0055 — `xschem library_manager <lcv>` logs the bare command, so the CIW / action-log line does not reproduce the located cell

**Opened:** 2026-06-28
**Status:** FIXED
**Severity:** LOW — action-log replay fidelity + CIW UX; no live-edit effect.
**Branch:** `fluid-editing`.
**Source:** user report.
**Affects:** `src/scheduler.c` `library_manager` subcommand (~:4147). Related: [[action-logging]],
[[library-manager]], [[cadence-note-nav]].

---

## 1. Symptom

Locating a cell in the Library Manager — Ctrl-Alt-S on a selected instance (or with nothing
selected, or on a `lib/cell` text note), all of which call
`xschem library_manager {lib cell view}` — echoes **`xschem library_manager`** (no argument)
to the CIW and writes that bare line to the action log. Replaying or re-typing that line just
opens the manager; it does **not** re-select/scroll to the cell that was located. The logged
command is not "the command the user would enter to get the same result."

(Plain `Tools -> Library Manager`, which legitimately takes no argument, correctly logs the
bare form — that case is fine.)

## 2. Root cause

`src/scheduler.c:4150` hard-codes the logged string:

```c
else if(!strcmp(argv[1], "library_manager")) {
  if(has_x) {
    log_action("xschem library_manager");        /* <-- ignores argv[2] (the lcv) */
    if(argc > 2) { tclvareval("libmgr::open {", argv[2], "}", NULL); }
    else         { tcleval("libmgr::open"); }
  }
}
```

The lcv (`argv[2]`) is passed to `libmgr::open` but never to `log_action`, so every locate
logs identically and the argument is lost.

## 3. Fix

Log the argument-bearing form when an lcv is given (and the bare form only when there is no
argument). The lcv is a single Tcl list argument, so brace it — consistent with the adjacent
`libmgr::open {`+argv[2]+`}` call:

```c
if(argc > 2) {
  log_action("xschem library_manager {%s}", argv[2]);   /* replayable: re-locates the cell */
  tclvareval("libmgr::open {", argv[2], "}", NULL);
} else {
  log_action("xschem library_manager");
  tcleval("libmgr::open");
}
```

So `Ctrl-Alt-S` on a `devices/res` instance now logs `xschem library_manager {devices res symbol}`.

(A backslash/brace in a library/cell name could still defeat the hand-rolled `{%s}` quoting —
the same `Tcl_Merge()`-vs-hand-quoting class as issue 0048, and the same assumption the
adjacent `libmgr::open {…}` call already makes. Out of scope here; realistic lcv names are
word tokens.)

## 4. Verification

`has_x`-gated, so not headless. Verified in a `--pipe` session with `libmgr::open` stubbed to a
no-op (no window → no WSLg hang) and `ciw_echo` overridden to capture the echoed line:
`xschem library_manager {devices res}` → logs `xschem library_manager {devices res}`;
`{devices res symbol}` → logs `{devices res symbol}`; bare → logs the bare form.
