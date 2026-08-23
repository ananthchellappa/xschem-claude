# 0618 — the simulation log records the simulator's chatter and nothing about the run

STATUS: **OPEN — reported by the user 2026-08-22**, second eyes-on session.

---

## What the user sees

> "the log file displayed when simulation runs doesn't show anything about what
> the command line going out to run the sim is, what the working directory that
> simulation is using is, how much time the simulation took, etc."

## Measured

`ase::run_done` (`src/ase.tcl:583-592`) writes the log:

```tcl
if {![catch {open $logpath w} f]} {
  puts -nonewline $f $data      ;# $::execute(data,last) -- the simulator's stdout, verbatim
  close $f
}
```

That is the whole log. Everything the user asked for is **known to the caller and
thrown away**, a few lines earlier in `ase::run_deck` (`src/ase.tcl:559-570`):

| wanted | already in hand | line |
|---|---|---|
| command line | `set cmd [$run_cmd $state $deckpath]` | `ase.tcl:566` |
| working directory | `cd $rd` (`$rd` = `ase::rundir $state`) | `ase.tcl:569` |
| deck actually run | `$deckpath` | `ase.tcl:562` |
| exit code | `$::execute(exitcode,last)` — **read in `run_done` and used only for `results`** | `ase.tcl:582` |
| elapsed | nothing captures a start stamp | — |

So four of the five need no new plumbing at all: they are local variables that
simply never reach the file. Only elapsed time needs a stamp taken before
`execute` and read in `run_done`.

## Why it matters

An analog run that produces a wrong or empty raw is debugged by asking *what
exactly ran, where, and against which deck*. Today the log cannot answer any of
those, so the user reconstructs the command by reading `src/ase.tcl` — which is
how this was reported. It is also the missing evidence for 0617: a log that
printed the deck path and the command would have shown at a glance that no
per-device `.save` cards were in it.

Elapsed time additionally carries the "did it actually converge or did it give up
in 40 ms" signal that a bare exit code does not.

## What to write

A header before the simulator's output and a footer after it, both clearly
delimited so nothing downstream that greps this file for ngspice's own strings is
confused by them:

```
=== ase run <cell> 2026-08-22 14:03:11 ===
  simulator : ngspice
  command   : /usr/local/bin/ngspice -b bandgap_run.spice
  directory : /home/analog/.../rundir
  deck      : /home/analog/.../tb_bandgap_ase.spice
--- simulator output ---
<... verbatim, byte-identical to today ...>
=== exit 0 after 12.4 s ===
```

## Landmines

- **The simulator's output must stay byte-identical** in its own region.
  `ase::run_done` parses `$data` for results and a `result_probe` backend hook
  reads it; both must keep seeing what they see today. Add framing to the *file*,
  do not mutate `$data`.
- Anything that greps the log — the ASE UI's log viewer, `result_probe`, any test
  golden — must be checked against the new framing before it lands.
- `run_done` fires from `execute_fileevent` on EOF; a start stamp must be taken
  in `run_deck` and carried, not recomputed in the callback (where it would
  measure the wrong interval).
- The log is opened `w`, so a failed run's log is the whole record — the header
  must be written even when the simulator produces no output at all. That is
  precisely the case where it is most wanted.
- Do not put anything user-identifying in the header beyond paths already on
  screen. Command line and cwd only.

## Acceptance

- A successful run's log opens with the command, cwd and deck path, and closes
  with exit code and elapsed seconds.
- A run whose simulator emits nothing still has both header and footer.
- `ase::run_done`'s result parsing and the `result_probe` hook return the same
  values as before, on the same deck (measure before/after on one deck).
