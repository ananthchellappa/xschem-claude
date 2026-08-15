# 0279 — `execute_fileevent` reads child stdout 1024 bytes at a time and forks `ps` on **every** read, capping every subprocess in xschem at **~255 kB/s**

Status: **OPEN** — measured with a three-point A/B inside a real xschem process, cause isolated to
two lines, fix drafted, not implemented. **Major on usability**: any subprocess that talks costs
4 ms per kilobyte. A 50 MB stdout takes **3 min 20 s** to ingest, all of it in `fork`.
Area: `src/xschem.tcl:245` (`read … 1024`) and `src/xschem.tcl:255` (`exec ps` per read), inside
`execute_fileevent`. Channel setup at `src/xschem.tcl:388` (`fconfigure $pipe -blocking 0`).
Tests: none. Nothing in `tests/` drives `execute` with a large-output child, so the entire
throughput characteristic is unmeasured.
Found: 2026-08-08, while measuring issue **0278** — the ASE log flood is the trigger, this is why
it costs *minutes* rather than *seconds*.
Related: **0278** (produces the 49.9 MB that exposes this; that issue is the cause, this one is
the amplifier, and they are independently fixable). Numbered 0278/0279 to sit clear of the
`open_pdk` block, which has advanced past 0260; the pair was first filed as 0258/0259 against a
fetched `github/open_pdk` maximum of 0248 (that branch has not been pushed past 0248) and
renumbered the same day, before any cross-reference escaped this branch.

## The two lines

```tcl
proc execute_fileevent {id} {
  global execute OS has_x errorCode

  append execute(data,$id) [read $execute(pipe,$id) 1024]        ;# :245  <- 1 KB per event
  if { ![regexp -nocase {windows} $OS] && ![regexp -nocase {cygwin} $OS]} {
    set eof [eof $execute(pipe,$id)]
    ...
    set lastproc [lindex [pid $execute(pipe,$id)] end]
    set ps_status [exec ps -o state= -p $lastproc]               ;# :255  <- fork, EVERY event
    set finished [regexp Z $ps_status]
    if { $eof && !$finished} { ... }
```

The `ps` exists for a real reason, given in the comment above it: a child that closes stdout while
still running puts the pipe in EOF, and closing a blocking channel then hangs until the process
exits. `$finished` distinguishes "zombie, safe to close" from "still alive".

**But `$finished` is only ever read in EOF branches** — `if {$eof && !$finished}` immediately
below, and `if {$finished} {fconfigure … -blocking 1}` further down inside `if {$eof}`. On the
99.99% of events that are not EOF, the fork is computed and discarded.

## Measured

Probe: a headless xschem running `execute 0 sh -c "cat <file>"` and timing to pipe close.
`src/xschem` on this machine, WSL2.

```
exec ps      : 4.050 ms per call (mean of 200)

small            4096 bytes       27 ms     148.1 kB/s
medium        1048576 bytes     4026 ms     254.3 kB/s
large        52428800 bytes   200343 ms     255.6 kB/s
```

**Throughput is flat at ~255 kB/s across four orders of magnitude of volume.** That is the
signature of a per-event fixed cost, not of I/O:

```
1024 bytes / 4.050 ms = 252.8 kB/s     <- predicted from the fork cost alone
                        255.6 kB/s     <- measured at 50 MB
```

The `ps` fork is not *a* cost, it is essentially the *entire* cost. 50 MB = 51,200 reads =
51,200 forks = 200 s.

This is what 0278's 49.9 MB log actually buys: `49,922,360 / 1024 = 48,752` forks ≈ **197 s**,
matching the multi-minute gap observed between the co-simulation finishing and the raw appearing.

## Blast radius

18 call sites route through `execute`, including the main simulator launches — this is not an
ASE-only path:

| site | what |
|---|---|
| `src/xschem.tcl:4081`, `:4237` | **Start simulation** (the primary simulate arms) |
| `src/ase.tcl:518` | ASE-L `run_deck` |
| `src/xschem.tcl:2453`, `:5511` | external editor |
| `src/xschem.tcl:5484`, `:5486` | terminal |
| `src/xschem.tcl:9564-9571`, `:12774` | `xdg-open` (tiny output, unaffected in practice) |

Any simulator that is chatty on stdout — ngspice with `.control` echoes, a verbose Xyce, a
netlist tool — pays 4 ms/kB. A quiet one never notices, which is why this has survived.

## Fix sketch (not implemented)

Two independent changes; either alone helps, both together make the cost O(1) in forks.

1. **Hoist the `ps` into the EOF branch.** `$finished` is consulted nowhere else. Care needed:
   the Windows `else` branch sets `finished 1` unconditionally, and the restructure must keep
   `$finished` defined on every path that reads it — the naive move leaves it unset in the
   non-EOF Unix path, which is harmless only because nothing reads it *today*.
2. **Raise the read chunk.** `fconfigure $pipe -blocking 0` is already set
   (`src/xschem.tcl:388`), so `read $chan <N>` returns whatever is available without blocking —
   a larger N is safe and changes no semantics. 64 KB cuts the event count 64×.

⚠ Do **not** "fix" this by dropping the zombie check. It guards a genuine hang: closing a
blocking channel on a live process that closed stdout blocks until that process exits.

⚠ A second, separate cost survives both fixes: `execute(data,$id)` accumulates the child's entire
stdout as one Tcl string, so a 50 MB log becomes a 50 MB Tcl value handed whole to the caller's
callback (`ase::run_done` → `result_probe` in 0278's case). Bounding or streaming that is a
third change, out of scope here.

Worth pinning with a test that asserts throughput on a multi-MB child stays above some floor —
the current regression surface for this is empty.
