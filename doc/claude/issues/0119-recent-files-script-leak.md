# 0119 — recent-files list re-contaminated by `--script` GUI verify runs

**Status:** FIXED
**Area:** recent-files protection (xinit.c, xschem.tcl), tests/headless/test_recent_launchlog.sh

## Symptom

The user's `~/.xschem/recent_files` (File > Open Recent) filled up with files the user
never opened: `xschem_library/examples/mos_power_ampli.sch` and
`/tmp/claude-.../scratchpad/wirefix.sch`, plus a "Recent components" toolbar array
pointing at a worktree scratchpad symbol (`.../wt_dd66/xschem_library/devices/lab_pin.sym`).
This is a regression of the protection first added in commit 3bcb6845.

## Root cause

The recent-views list belongs to the user; scripted/automation sessions must never write it.
The gate is the C-set `no_recent_files` flag (xinit.c), consumed by
`update_recent_file` / `update_recent_dir` / `write_recent_file` in xschem.tcl.

The original gate only forced `no_recent_files=1` for `--nogui`, `--pipe`, or `--norecent`:

```c
tclsetintvar("no_recent_files", (cli_opt_nogui || cli_opt_pipe || cli_opt_norecent) ? 1 : 0);
```

The protection was therefore **opt-in per launch**. A **real-GUI verify/repro run** — the
exact thing done to eyeball fluid-editing bugs — launches xschem with a real X display and a
canned startup script but *without* `--pipe`:

```
./src/xschem -x --script scratchpad/gui_verify.tcl
```

`gui_verify.tcl` does `xschem load .../wirefix.sch`. With none of the three gate flags present,
`no_recent_files=0`, so every programmatic `load` was recorded into the user's list. Same path
for `xschemtest.tcl` loading `mos_power_ampli.sch`, and for the recent-components toolbar writer
(which persists into the same file).

## Fix

Treat a `--script` startup file as automation too — a canned Tcl script's loads are programmatic,
never a human clicking File > Open. Real desktop users open designs via a positional argument or
the GUI, never via `--script` (the only shipped `--script` uses load *config/highlight styles*,
not a design into the recent list). xinit.c:

```c
tclsetintvar("no_recent_files",
  (cli_opt_nogui || cli_opt_pipe || cli_opt_norecent || cli_opt_tcl_script[0]) ? 1 : 0);
```

This closes the leak for *all* scripted sessions regardless of X display, with no per-launch flag
discipline required.

## Test

`tests/headless/test_recent_launchlog.sh`:
- The old positive rail abused `--script load_quit.tcl` as a stand-in for "user mode" — the exact
  conflation that hid the leak. Rewritten to the genuine user path: a **positional-arg** GUI launch
  (`xschem -x file.sch`), whose startup load writes recent_files (xinit.c ~3558), backgrounded and
  killed once the write lands.
- New regression rail **4b**: `xschem -x --script load_quit.tcl` (real GUI, no `--pipe`) must
  **not** write recent_files. Sabotage-verified: reverting the `cli_opt_tcl_script[0]` guard makes
  rail 4b fail ("leak is back") while the positional rail still passes.

The user's live `recent_files` was also cleaned of the two contaminant schematic entries and the
worktree-scratchpad toolbar array (backup left as `recent_files.bak.<mtime>`).
