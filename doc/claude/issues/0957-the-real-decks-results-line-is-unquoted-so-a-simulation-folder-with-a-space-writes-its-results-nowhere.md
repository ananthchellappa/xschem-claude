# 0957 — the real deck's results line is unquoted, so a run from a folder with a space in its name writes its results nowhere

**STATUS: OPEN — measured 2026-08-30 by item S3a while fixing issue 0949's probe
half. NOT fixed there: S3a's brief forbids touching deck emission. This is the
older half of 0949 and it belongs to whoever owns `render_deck`.**

## What the user sees

They keep their design under a folder whose name has a space in it — `my
project`, `Bandgap rev 2` — and press Run. The simulator starts, it exits, and
there are no results. Pressing 6 on the schematic says there are no operating
point results. Nothing tells them why.

## Where it is

`src/ase.tcl:5613`, inside `ase::backend::ngspice::render_deck`:

```tcl
lappend lines "write [raw_file $state]"
```

and `raw_file` (`src/ase.tcl:5680`) answers
`[file join [ase::rundir $state] ${cell}_ase.raw]` — an absolute path built from
the run directory, which is built from the simulation folder, which is the user's
to name.

## Why the path being absolute is fatal, measured

Not truncation. Measured first-hand on ngspice-46+ during item S3a: given
`write /a/b c/x.raw` the program reads the second whitespace word as a VECTOR
name, finds no such vector, prints `Error during 'write': no writable vector
found.` and writes nothing anywhere. A dollar sign, a single quote or a
semicolon in the folder name kills it the same way. A square bracket does not.

**No quoting form inside the deck rescues it.** Six write forms were measured
against five hostile folder names: a bare name, `write "..."`, backslash
escaping, a `.control`-level `cd "..."`, and `set ofn = "..."` + `write $ofn` all
fail for a folder called `do$llar`, because the program expands `$` inside
`.control` regardless of quoting.

## The measured mitigation, and why it should be cheap here

The one form that produced the file for a space, a dollar, a bracket, a quote and
a semicolon alike is: give the program the target folder as its own current
directory, and name the results with a **bare file name**. That is exactly what
item S3a did to the probe (`ase::cap_run` + `write probe_a.raw`).

**`ase::run_deck` already cd's into the very folder `raw_file` joins**:
`src/ase.tcl:2549-2552` does `set save [pwd]` / `cd $rd` / `eval execute 0 $cmd` /
`cd $save`, and `raw_file` is `[file join [ase::rundir $state] ...]`. So a bare
basename on the deck's `write` line resolves to the same file it does today, on
every folder name, with no other change to the launch.

## What the fix has to be careful about

* `raw_file` is a PUBLIC hook and other readers call it for the absolute path
  (`src/ase.tcl:2476` deletes it, `:2759` hands it out). Only the deck's `write`
  line wants the bare name; the hook itself must keep answering absolutely.
* the same argument applies to any other in-deck path the emitter writes.
* it needs its own suite rows, driving the REAL simulator from a folder whose
  name has a space and one with a dollar, the way row K3 of
  `tests/headless/test_ase_simcaps_0948.tcl` does for the probe.

## Related

Issue 0949 (the probe half — FIXED in S3a), issue 0938 (the dollar-sign class at
registration), issue 0929 (a blank annotation with nothing said).
