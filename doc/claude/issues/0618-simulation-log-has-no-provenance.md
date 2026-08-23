# 0618 — the simulation log records the simulator's chatter and nothing about the run

STATUS: **CLOSED 2026-08-23.** `ase::run_deck` now writes a header at launch and
`ase::run_done` rewrites the file as header + delimiter + the simulator's verbatim
bytes + footer. All five facts the user asked for are there, and the simulator's own
region is byte-identical to what it was.

## BEFORE (Measure agent, verbatim)

```
log mentions the command line: 0 / log mentions the deck path: 0 /
log mentions an exit code: 0 / log mentions elapsed time: 0
log == execute(data,last) byte-identical: 1   (size=511)
PARSED RESULTS (must be IDENTICAL after framing): id 4.096837e-04
FAILED LAUNCH: LOG FILE EXISTS AFTER A FAILED LAUNCH: 0
simulator RUNS and fails with no output (/bin/false): LOG EXISTS: 1  size=0
```

## AFTER

```
=== ase run test_nfet_final Sun Aug 23 07:43:24 MST 2026 ===
simulator : ngspice
command   : ngspice -b <deck> 2>@1
directory : <rundir>
deck      : <deck>
--- simulator output ---
<the simulator's stdout, byte for byte>
=== exit 0 after 2.84 s ===
```

`log mentions the command line: 1 / rundir: 1 / deck path: 1 / exit code: 1 /
elapsed time: 1` — every one was 0. **`ase::last_result` is still
`id 4.096837e-04`**, the pin this issue demanded: `$data` is never mutated, so the
`result_probe` anchored per-line regexp (`ase.tcl:3510`) and `ase::run_diagnostics`
cannot move. Row **E1g** asserts the region between the delimiter and the footer is
byte-identical to `$::execute(data,last)`; the crew's adversary additionally drove
`ase::run_log_write` with five hostile payloads (no trailing newline, empty, CRLF,
embedded NUL/0x01, and a **spoofed** `=== exit 99 after 1.00 s ===` line inside the
data) and the region survived all five.

**Both failed-run flavours now leave a record**, which is what this issue said it
most wanted:

* a failed **launch** (`execute` returns -1, `run_done` never fires) leaves a
  header-only log naming the un-runnable command — **before, no log existed at all**;
* a simulator that **runs and prints nothing** leaves header + delimiter + footer with
  an empty output region — before, a zero-byte file.

## Decisions

* **D8 (L2) — the header is written by `run_deck` (mode `w`) before `eval execute`**,
  and `run_done` rewrites the whole file (mode `w`, truncation semantics unchanged).
  *Rejected:* writing everything only in `run_done` — measured, a failed launch never
  reaches it, losing the record in exactly the case a user debugs. *Rejected:*
  `run_done` appending (mode `a`) — `test_ase_cosim` calls `run_done` six times on one
  path and would accumulate. **Accepted cost, now filed as 0641**: the previous run's
  log is destroyed at launch and stays header-only for the whole run.
* **D9 (L2) — `ase::run_done {logpath state callback {meta {}}}`, DEFAULTED**, and an
  empty `meta` writes `$data` with **no framing at all**, byte-identical to today.
  A required 4th parameter would have killed `test_ase_cosim`'s 341 checks with
  `wrong # args` at six call sites (`:1019 :1036 :1049 :1056 :1061 :1067`).
  *Rejected:* synthesising a header from `$::execute(cmd,last)` when `meta` is absent
  — those are process-global "last" values and would stamp a foreign command onto the
  file. *Rejected:* `auto_execok`-resolving argv0 (a second source of truth about which
  binary ran, computed at a different instant from the exec). *Rejected:* `%.1f`, this
  issue's own example — it renders the "did it give up in 40 ms" signal as `0.0 s`.
* The framing **owns the newline before the footer**. Gluing the footer to `$data`'s
  own trailing newline breaks for a simulator whose last line carries none, and cannot
  express an empty output region at all.

## A near-miss worth carrying forward

The first implementation guarded the elapsed stamp with `string is integer -strict`.
`clock milliseconds` is a **wide** integer (~1.7e12) and `string is integer -strict`
is a 32-bit test that answers **0** for it, so the footer silently printed `0.00 s`
for every run — an always-zero elapsed is a *fabricated* number, not a missing one,
and the `E1f` regexp would have passed it forever. Caught by eyeballing a sample log,
not by a test. Do not use `string is integer -strict` on anything derived from
`clock`.

## One test-helper edit, flagged deliberately

`tests/headless/test_ase_core.tcl`'s `e_logbody` ended
`return [string range $rest 0 $j]` where `$j` indexes the `"\n"` that starts the
search needle. `string range` is **inclusive**, so the helper could never return `{}`
for any input — which made E1g ("the region is byte-identical") and E4 ("the region is
EMPTY, not absent") mutually unsatisfiable by *any* framing. Fixed by one character,
`$j` → `[expr {$j - 1}]`, proved exhaustively over three data shapes × two framings ×
both helper variants before the edit. No assertion was weakened.

## Still open

* **0641** — `run_deck` truncates the log at launch, so a previous run's complete log
  is destroyed the moment the next one starts, and a mid-run `Simulation > Log` with
  no run_id shows a header and nothing else.

---

## Original filing follows

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
