# PDK launcher GUI

Status: EXECUTED 2026-08-02. A small Tcl/Tk front end that replaces having to remember
and retype

```sh
src/xschem --script sky130A/cadence_style_rc --logdir /tmp
```

Run it with `./pdk_launcher.sh` from the repo root (thin `wish` wrapper);
the GUI itself is `tools/launcher/pdk_launcher.tcl`.

## What it does

Pick a PDK, a log directory and (optionally) a netlist directory / a schematic, press
**Launch**. It builds one xschem command line and `exec`s it detached, so the launcher
and the editor are independent.

- **PDK list is DISCOVERED, not hard-coded.** Every immediate subdirectory of the repo
  that has BOTH a `cadence_style_rc` and its own `xschem_libs/library.defs` becomes an
  entry — so a new workarea appears the moment it is created, with no edit here. The
  `library.defs` half of the test matters: `src/` also ships a `cadence_style_rc` (the
  repo's plain Cadence UX) and would otherwise show up as a bogus "src" PDK that loads no
  libraries.
- Two synthetic entries are always offered: **(no PDK — repo Cadence UX)**, which uses
  `src/cadence_style_rc`, and **(plain xschem — no rc)**, which passes no `--script`.
- A live **Command** preview shows exactly the argv that will run — it is a rendering of
  the same list `exec` receives, not a separately-formatted string, so it cannot drift.
- Settings persist to `~/.xschem/pdk_launcher.conf` (plain `key value` lines; unknown
  keys ignored, so an older or newer launcher cannot choke on the file).

## Fields

| field | becomes | notes |
|---|---|---|
| PDK | `--script <workarea>/cadence_style_rc` | omitted entirely for "plain xschem" |
| Log directory | `--logdir <dir>` | offers to create it if missing |
| Netlist directory | `--netlist_path <dir>` | created silently if missing |
| Schematic (opt.) | positional arg | must come LAST; existence checked before launch |
| Extra args | split on whitespace | escape hatch for any other xschem flag |
| don't touch Open Recent | `--norecent` | keeps throwaway sessions out of Open Recent |

Blank fields are omitted entirely rather than passed as empty strings — a bare
`--logdir {}` would make xschem swallow the next argument as the log directory.

### There is no quiet flag — `-q` means QUIT

The launcher originally offered a **"quiet (-q)"** checkbox, defaulted ON. In xschem `-q`
is `--quit`, *"Quit after doing things (no interactive mode)"* (`src/xschem.help`), so
every launch opened a window and immediately closed it. With *quit launcher after
starting xschem* also ticked, both windows vanished and nothing was left to explain why.
xschem has no quiet option at all; the checkbox was invented, not verified against the
help text.

The option is gone, and `do_launch` now warns if `-q`/`--quit` reaches the command line
through **Extra args**, because the symptom gives no hint of the cause. The test asserts
the flag is never emitted for any PDK.

## Verification

`tests/headless/test_pdk_launcher.tcl` (30 checks, registered in `run_regression.tcl`
hcases). It sources the launcher with `::PDK_LAUNCHER_NO_UI` set, which skips
`package require Tk` and returns before any widget is built — so the command-building
logic is testable under a plain `tclsh` with no display. It checks discovery (including
that `src/` is not listed), the rc mapping for each PDK, flag construction, blank-field
omission, and that the schematic stays last. Sabotage-verified: dropping the
`library.defs` discovery filter → 2 FAILED; dropping the blank-`logdir` trim → 10 FAILED.

End-to-end, the real UI is driven programmatically (set the fields, call `do_launch`) with
`HOME` redirected to a scratch dir, in the reported configuration — *quit launcher after
starting xschem* ticked — and xschem is then asserted to be **still running** several
seconds after the launcher has exited.

That liveness assertion is the point. The first version of this check concluded "launched"
from the existence of `Xschem.log` in the target directory. xschem writes that header and
*then* honours `-q` by exiting, so the artifact was produced by a run that had already
died — a green check on a broken launcher. An artifact proves a process started, never
that it survived.

## Known environment quirk (not a defect in this code)

Screenshots of this GUI taken with `xwd` under WSLg/Xwayland show text but no
radio/check indicators and no entry borders. That is a **capture** artifact — `xwd
-screen` and `xwd -root` both fail with `BadMatch` on this display, and a minimal
classic-Tk probe reproduces it identically. Tk widget chrome renders normally in
practice (the GUI test gate panel and xschem itself are Tk apps used interactively on
this same display). The launcher forces the `clam` ttk theme regardless, since it draws
indicators and entry reliefs consistently across builds.

## Related

[[sky130_workarea]], [[gf180mcud_workarea]], [[ihp_sg13g2_workarea]].
