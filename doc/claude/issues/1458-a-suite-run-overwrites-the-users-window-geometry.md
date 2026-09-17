# 1458 — every GUI suite run overwrites the user's `~/.xschem/geometry`, and nothing gates it

**STAMP:** `v1 claim=duplicate tree=61af3692 stamped=2026-09-17 fix=none open=0 super=1397 by=D1`

**Status:** open · **Filed:** 2026-09-13 by the driver of the ASE-L analyses batch
**Area:** xschem core / test isolation
**Related:** **1453** (the same family, one file over), 0119 (the gate that exists), 0924, 1397

## The defect

`store_geom` (`src/xschem.tcl:16062`) writes `$USER_CONF_DIR/geometry` **unconditionally**. There
is no `no_recent_files`-style guard on it and no `--norecent`-style flag that reaches it, so a
`--pipe` run **with Tk** — which is exactly what every display-arm suite is — records its scratch
windows into the user's own geometry file on exit.

Compare the sibling that *is* gated. `src/xinit.c:3546` sets `no_recent_files` for
`--nogui` / `--pipe` / `--norecent` and restores it before the event loop, and
`update_recent_file` honours it. **`store_geom` has no equivalent**, so the two halves of "this
run's windows are not the user's windows" are half implemented.

```tcl
proc store_geom {win filename} {
  ...
  set geom_array($filename) [list $geom [clock seconds]]
  ...
  write_data $geom_data\n $geom_file        ;# no guard anywhere above this line
}
```

⚠ **And it displaces, exactly like the recent list.** The file is keyed by filename and **capped at
the 100 most-recent entries**, sorted newest-first by timestamp. A suite that opens dozens of
scratch schematics therefore pushes the user's own entries down and, eventually, out — the same
mechanism as issue 1453's ten-entry cap, with a bigger number and a slower fuse.

## How it was found

Not by looking for it. While collecting issue **1453** the driver listed `~/.xschem/` read-only and
found `geometry` with a timestamp minutes old — written during the driver's own verification runs,
*after* 1453's fix had stopped `recent_files` from moving. A crew that had finished hours earlier
independently flagged *"the `~/.xschem/geometry` write by `run_suites.sh`'s display arm"* as
something still unrouted.

### The measurement, and it is a natural experiment rather than a contrived one

After issue 1453 landed, the driver ran `test_ase_dialogs` on the dev display **twice** and two
solo `run_regression.tcl` passes, then listed `~/.xschem/` read-only:

```
-rw-r--r-- 1 analog analog 8464 2026-09-13 19:24 geometry        <- moved
-rw-r--r-- 1 analog analog 2632 2026-09-13 18:53 recent_files    <- did NOT move
```

**Same runs, same binary, same display. One file moved and the other did not** — because
`update_recent_file` is gated and `store_geom` is not. `recent_files` is frozen at 18:53, the last
pre-fix sweep; `geometry` is minutes old. That is the whole issue in two timestamps, and it needed
no deck and no instrumentation.

⚠ **Not yet measured, and it is the obvious next step**: the controlled version — a scratch `HOME`
carrying a marked `geometry`, one `--pipe` GUI run, and a diff. The driver has already run exactly
that shape for 1453's child process (where `geometry` came back **OVERWRITTEN** and `xschemrc`
did not), so the mechanism is not in doubt; what is untested is whether the *suite* path and the
*detached child* path write it the same way.

⚠ **The driver's first reading of that was wrong and is corrected here**: the `LEDGER.md` entry for
1453 waved it through as *"what any interactive xschem does on exit"*. That is true of an
interactive session and it is **not** an excuse for a test run — a suite is not a user, and the
whole point of the 0119 gate is that the two are told apart.

## What is NOT claimed

* **No user data is destroyed.** A geometry entry is a window size and position, not content.
* **It is milder than 1453**, whose cap is ten and whose entries are a menu the user reads. This
  one is felt as *"my window opened in the wrong place"*, if it is felt at all.
* **The suites are not obviously at fault.** `tests/headless/devdisplay.sh` and `xvfb_arm.sh`
  isolate the *display*; nothing in this tree claims to isolate `$HOME`, and a suite that set
  `HOME` to a scratch directory would lose the very `~/.xschem` state some of them are about.

## Options

| | what | cost |
|---|---|---|
| **A** | **(recommended)** `store_geom` honours the same gate `update_recent_file` does — return early when `no_recent_files` is set. One condition, and it makes `--norecent` mean what its name says. | small; the flag already exists and is already set for `--pipe` |
| **B** | a separate `no_save_geometry` flag and a new CLI option | more surface for the same result, and a second thing to remember |
| **C** | suites run under a scratch `HOME` | large, and it breaks the suites whose subject is the real registry |
| **D** | nothing — it is only window geometry | the honest do-nothing, and the reason it is listed is that it might be the right answer |

⚠ **A is not free of consequence**: after it, a deliberate `--pipe` GUI session that a user *wants*
remembered would stop being remembered. Whether that case exists is the question the ruling turns
on, which is why this is filed rather than fixed.

## What the user's file looks like today

Their `~/.xschem/geometry` is being written by test runs several times an hour, and has been for as
long as this batch has had display-arm suites. **Nothing here touched it**, per the standing rule
that nothing under `~/.xschem/` is read-modify-written — the same rule that left 1453's ten dead
entries in place.
