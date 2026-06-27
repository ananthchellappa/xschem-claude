# Headless test/repro harness

A fast, hermetic edit → build → verify loop for the xschem C/Tcl core. It drives
the real binary with no GUI, so it works over SSH/CI and is safe to run on every
change.

## Quick start

```sh
cd src && make            # build the binary the harness runs
cd ../tests/headless
./run.sh                  # load every case, netlist it, diff against gold/
```

Exit status is `0` on PASS, non-zero on any mismatch — usable directly in scripts/CI.

## Modes

| Command | What it does |
|---|---|
| `./run.sh` | Run all manifest cases, compare normalized output to `gold/`. |
| `./run.sh --update-gold` | Adopt the current output as the new baseline (after an *intended* change). |
| `./run.sh --script FILE` | Run an arbitrary driver `.tcl` for one-off bug reproduction (no golden compare). |

## What makes it trustworthy

- **Hermetic.** Uses `minrc` via `--rcfile` and pins `XSCHEM_LIBRARY_PATH` to in-repo
  libraries, so results never depend on the developer's `~/.xschem/xschemrc`.
- **Pinned outputs.** Netlists go to `results/netlists/` via `--netlist_path`, not the
  user's `~/.xschem/simulations`.
- **Deterministic.** Output is normalized (absolute paths → `@REPO@`, embedded
  `sch_path:`/`sym_path:` comment lines dropped) so the diff is portable run-to-run
  and machine-to-machine.
- **Catches silent failures.** `state.txt` records per-case instance/wire counts, so a
  schematic that silently loads *empty* (e.g. a broken library path) shows up as a
  diff instead of a false PASS.

## Files

- `cases.txt` — manifest of schematics (paths relative to repo root). Add a line to
  cover a new design, then `./run.sh --update-gold`.
- `harness.tcl` — the headless driver: load, sanity-check, netlist each case.
- `minrc` — hermetic rcfile (reads `$REPO` from the environment, set by `run.sh`).
- `run.sh` — runner: orchestrates, normalizes, diffs.
- `gold/` — committed golden baseline (normalized).
- `results/` — per-run output and `*.diff` files (git-ignored).

## GUI smokes (`test_*.tcl`)

The `test_*.tcl` files are unattended-but-windowed smokes: they open the real Tk
window (they need a display) but are driven entirely by script. Standard
invocation:

```sh
DISPLAY=:0 ../../src/xschem --pipe -q --nolog --script test_<name>.tcl
```

**Pass `--nolog` unless the test's subject IS logging/the CIW.** It disables the
action log (no `Xschem.log` litter in the launch cwd) and the CIW auto-open
(short-lived toplevels leak WSLg ghost frames — see
`doc/claude/issues/0002-wslg-ghost-window-survives-xkill.md`). The exceptions —
`test_ciw.tcl` and `test_action_log_dispatch.tcl` — use `--logdir $(mktemp -d)`
instead, and destroy the CIW before exiting. `run.sh` already passes `--nolog`.

Most smokes print `RESULT: ALL PASS` / `RESULT: N FAILED` and exit nonzero on
failure (`test_palette.tcl` predates the convention and prints per-check lines
only).

`test_action_replay.sh` is a shell-orchestrated **two-process acceptance smoke**
for the action log: it records a session in one xschem, replays the captured
`Xschem.log` into a second fresh xschem, and diffs their state — proving the log
is replayable, not just well-formed. Run it directly with a display:
`DISPLAY=:0 sh test_action_replay.sh`.

## Workflow for a bug fix

1. `./run.sh` to confirm a clean PASS baseline.
2. Write a `/tmp/repro.tcl` and `./run.sh --script /tmp/repro.tcl` to reproduce.
3. Fix the C/Tcl, `cd src && make`.
4. `./run.sh` — a PASS means no regression in the covered cases; a FAIL shows the exact
   netlist diff. If the change *intends* to alter output, review the diff then
   `./run.sh --update-gold`.
