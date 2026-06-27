# Issue 0041 — nhse editor: signal 11 segfault with named colors or dash patterns

**Opened:** 2026-06-27
**Status:** OPEN — requires C fix; cannot be fixed in Tcl. Needs Ananth.
**Affects:** xschem update_net_hilight_style (C: src/hilight.c or src/scheduler.c)
**Severity:** HIGH — crashes xschem in production when applying real highlight styles
**Branch:** fluid-editing

**Repro:** Under DISPLAY=:0 ./src/xschem --pipe --nolog:
  set ::net_hilight_style {{0 4 1 {} 0 0 none 0} {1 red 3 {6 4} 30 0 march_fwd 2}}
  xschem update_net_hilight_style
  → FATAL: signal 11 (no crash when color=3 and dash={})

**Tests failing:** test_nh_editor_table.tcl, test_nh_editor_align.tcl,
test_nh_editor_persist.tcl, test_nh_editor_flush_scroll.tcl — all CRASH with signal 11.

**Root cause (suspected):** The C update_net_hilight_style function does not safely
handle named X11 colors (red, green, #00ff00) or non-trivial dash patterns ({6 4}).
Possible: NULL deref from XAllocNamedColor failure, or dash array bounds overrun.

**Note:** utils/display.tcl ships with these exact style values. If this reproduces
with --script src/cadence_style_rc, the standard cadence launch also crashes.

**Acceptance criteria:** All 4 tests pass with no signal 11.
