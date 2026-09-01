# 0649 — the Simulation Log window shows the raw stream, never the framed log file: no header, no footer, no filename, and it fights you when you scroll

STATUS: **OPEN — reported by the user 2026-08-23**, immediately after 0618
landed. Everything the user asks for already exists; the window is fed from a
different source than the one that has it. Related: 0618, 0641.

---

## What the user said

> "What is the window showing simulation log? There is no way to scroll up and
> see information about the run. Nothing shows which file it is displaying (it
> must be an actual file that ngspice creates?). There is nothing at the end
> saying simulation completed successfully"

Three complaints. Answering the middle one first, because it explains the others.

## What that window is

`ase::ui::log_open` (`src/ase_window.tcl:3589`) creates a Tk **toplevel**
`$top.logwin`, titled `Simulation Log — <cell>`. It is not a file viewer. It has
**two sources** and they carry different content:

| when | source | has 0618's framing? |
|---|---|---|
| during a run | `::execute(data,$id)`, streamed live via a `trace` on the variable, delta-appended by `ase::ui::log_trace` | **no** — raw simulator stdout only |
| `Simulation > Log`, no run in flight | the backend's log **file**, `[ase::backend_hook $sim log_file] $st` | yes |

The file is real and it is ngspice's output **as re-written by ASE**, not
something ngspice creates directly: `ase::run_done` writes
`~/.xschem/simulations/<cell>_ase.log`. Measured on the user's own 18:32 run:

```
=== ase run tb_bandgap Sun Aug 23 18:32:09 MST 2026 ===
simulator : ngspice
command   : ngspice -b /home/analog/.xschem/simulations/tb_bandgap_ase.spice 2>@1
directory : /home/analog/.xschem/simulations
deck      : /home/analog/.xschem/simulations/tb_bandgap_ase.spice
--- simulator output ---
...
=== exit 0 after 3.47 s ===
```

**Every single thing the user asked for is in that file.** The window they were
looking at is the live one, which never sees any of it.

## The three defects

### 1. The framing never reaches the window

0618 put the header and footer in the **file**, written by `ase::run_done`. The
live window is fed the raw stream. `ase::ui::run_finished` appends the final
delta and any co-simulation diagnostics — and then **branches on the exit code
without printing it** (`set ec ...; if {$ec == 0}`). It knows the run succeeded
and says nothing.

So: no `command`/`directory`/`deck` header at the top, and no
`=== exit 0 after 3.47 s ===` at the bottom, for the entire live path — which is
the path every user is on, because the window opens itself when the run starts.

### 2. `$t see end` on every append fights the user's scroll

`ase::ui::log_append` ends with `$t see end`, unconditionally. There **is** a
vertical scrollbar (`$lw.sb`), so "no way to scroll up" is not a missing widget —
it is that every delta from the simulator yanks the view back to the bottom.
On a chatty run that is continuous.

Standard fix: only `see end` when the view was **already** at the bottom before
the insert (compare `$t yview` before/after, or track a sticky flag), so a user
who scrolls up stays put and a user at the tail keeps following.

### 3. `-wrap none` with no horizontal scrollbar

```tcl
text $lw.t -height 24 -width 84 -state disabled -wrap none \
     -yscrollcommand [list $lw.sb set]
```

No `-xscrollcommand`, no horizontal scrollbar. With `-wrap none`, anything past
column 84 is **unreachable** — including the full deck path in 0618's header once
that reaches the window. Either add the horizontal scrollbar or drop `-wrap none`.

## What to do

1. Put 0618's framing into the **window**, not just the file — the header when the
   run starts, the footer in `run_finished` where the exit code is already in
   hand. One source of truth: prefer having `run_done`/`run_deck` produce the
   framing once and feed both sinks, rather than formatting it twice (that is
   invariant I1's failure mode — two builders that drift silently).
2. **Name the file in the window.** The title already carries the cell; add the
   log path, or show it in the header line the window now gets for free from (1).
3. Make `see end` conditional on being at the tail.
4. Add the horizontal scrollbar.

## Landmines

- **Do not mutate `$::execute(data,$id)`.** `ase::run_done` parses it for results
  and the `result_probe` hook reads it (0618's central pin, row E1g). Framing is
  presentation; it belongs in the sink, never in the stream.
- 0618's adversary already proved the file's output region survives a **spoofed**
  `=== exit 99 after 1.00 s ===` embedded in the data. The window needs the same
  property: a simulator that prints something header-shaped must not be able to
  fake the window's framing either.
- **Issue 0641 is adjacent and must not be conflated**: `run_deck` truncates the
  log file at launch, so a previous run's complete log dies when the next starts,
  and a mid-run `Simulation > Log` with no `run_id` shows a header and nothing
  else. That is a *file lifetime* bug; this is a *window content* bug. Fixing
  this one does not fix that one, and the reverse.
- `ase::ui::log_widget` returns `{}` when the window is closed and every writer
  must keep tolerating that — the run must not fail because nobody is looking.
- The dialog/window paths are driven by `test_ase_window` (179 checks). Do not
  rename `$top.logwin` or `$lw.t`.

## Acceptance

- A live run's window opens with the header naming simulator, command, directory
  and deck, and ends with the exit code and elapsed time.
- The window states the path of the log file it corresponds to.
- Scrolling up mid-run stays up; a view already at the tail keeps following.
- A line longer than the window is reachable.
- `ase::last_result` and the `result_probe` hook return the same values as before
  on the same deck.
