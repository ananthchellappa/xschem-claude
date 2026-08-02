# 0209 — the action log's "`#` comment or `xschem …`" rule and the practice have drifted apart

Status: **OPEN**, undecided by design — this is a *decision* to take, not a bug to hunt. The
mechanism is fully measured (below); what is unresolved is which of the two sides is wrong.
Filed 2026-08-02 while fixing [0207](0207-ase-ciw-messages-never-reach-the-log-file.md),
which recorded the drift as its landmine 4 and then hit it from the other direction.
Area: `tests/headless/test_selflog_output.tcl:469-485` (the rule), `src/wave_viewer.tcl`
(`wviewer::log_action`, 14 sites), `src/library_manager.tcl` (14 sites), `src/xschem.tcl`
(4 sites), `src/xschem.tcl:15271` (`replay_action_log`, the thing that actually replays).
Tests: none trips today — that is the point. `test_selflog_output.tcl`'s source-ability leg
is the gate, and it never runs in a process that has logged one of the offending lines.
Related: [0207](0207-ase-ciw-messages-never-reach-the-log-file.md) landmine 4 and its
"deliberately left undone" item 2, [0208](0208-the-ctrl-4-pick-has-no-replayable-log-line.md)
(item 3 of its "what has to be built" is blocked on this decision), issue 0070.
Specs: `doc/claude/specs/action_logging.md` §2 and locked decision 4.1,
`action_logging_checklist.md` row 12.

## The rule

`tests/headless/test_selflog_output.tcl:469-485` accumulates physical log lines into logical
commands with `info complete`, then requires each to be one of exactly two things:

```tcl
  if {[string index $first 0] eq "#"} continue       ;# comment (header/output)
  if {[string match "xschem *" $first]} continue      ;# replayable command
  set srcok 0 ; puts "  non-source-able command starting: <$first>"
```

It is the mechanical form of `action_logging.md`'s locked decision 4.1 — *"Log-line format =
whatever is a valid `xschem …` Tcl command"* — and of §2's *"Each logged line MUST be a
command executable in Tcl — a real `xschem …` command"*.

## The practice: 32 sites in three files log something else

| file | sites | shape |
|---|---|---|
| `src/wave_viewer.tcl` | 14 | `wviewer::log_action [list wviewer::set_plot_mode $new $token]` — 2197, 2246, 2681, 3315, 3480, 3716, 3838, 4304, 4362, 4460, 4565, 4828 (+ the seam at 2138) |
| `src/library_manager.tcl` | 14 | `xschem log_action [list libmgr::do_new_cell $lib $cell]` — 619, 635, 682, 692, 703, 720, 959, 976, 992, 1006, 1021, 1163, 1180, 1196 |
| `src/xschem.tcl` | 4 | `xschem log_action [list net_hilight_style_set_live …]` (1363, 1463), `[list write_net_hilight_style_conf $path]` (1429), and a bare Tcl `set` — `[list set ::net_hilight_style …]` (1428) |

## Measured, not read

Driving the seams exactly as the product does, under `--logdir`, then running
`test_selflog_output.tcl`'s **own accumulator verbatim** over the resulting file:

```
--- LOG ---
# xschem action log
# launch: …
# cwd: …
wviewer::set_plot_mode single K
wviewer::clear_all tok1
libmgr::do_new_cell mylib mycell
set ::net_hilight_style 3
--- END ---
  NON-SOURCE-ABLE per the rule: <wviewer::set_plot_mode single K>
  NON-SOURCE-ABLE per the rule: <wviewer::clear_all tok1>
  NON-SOURCE-ABLE per the rule: <libmgr::do_new_cell mylib mycell>
  NON-SOURCE-ABLE per the rule: <set ::net_hilight_style 3>
scanner verdict srcok=0
```

So the gate **would** fail. It does not, for a mundane reason.

## Why no test catches it

`test_selflog_output.tcl` runs in one process, logs its own actions, then scans that
process's log. It never opens a waveform viewer or the Library Manager, so none of the 32
sites ever fires in the process being scanned.

The viewer's own suites do not catch it either, and for a sharper reason: they **spy on the
seam**. `test_wave_modes.tcl:755-756` does

```tcl
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::wvm_log $line }
```

and asserts on `$::wvm_log`. Measured: a full `test_wave_modes` run under `--logdir` — 433
checks, ALL PASS, 22 `set_plot_mode` calls — put **zero** `wviewer::` lines in `Xschem.log`.
The lines the tests assert on never reach the file they are supposedly a log of.

## The fork — and why "the practice is wrong" is NOT obviously the answer

**These lines are genuinely replayable.** `replay_action_log` (`src/xschem.tcl:15271`) is

```tcl
proc replay_action_log {file} {
  xschem log_action -suppress push
  set rc [catch {uplevel #0 [list source $file]} res]
  xschem log_action -suppress pop
  ...
}
```

— `uplevel #0`, i.e. the **live** xschem interpreter, where `wviewer::set_plot_mode` and
`libmgr::do_new_cell` are perfectly good commands. Re-logging on replay is already handled:
`wviewer::log_action` funnels into `xschem log_action`, which the `-suppress push` scope
silences. Nothing is broken at replay time.

What *is* broken is the check. Measured: sourcing such a log into a **fresh** interpreter
fails (`invalid command name "wviewer::set_plot_mode"`), which is what the `xschem `-prefix
rule was really testing for — "will this line survive a replay in a stock interpreter". That
is a stricter contract than the product actually needs, and three subsystems have quietly
stopped honouring it.

**Option A — narrow the practice to the rule.** Mint `xschem` subcommands for the 32
effects, or wrap them (`xschem wviewer set_plot_mode …`). Faithful to decision 4.1, keeps the
one-namespace log, and makes the gate meaningful again. Costs 32 new dispatcher entries or
one generic escape hatch, which is most of a phase of work.

**Option B — widen the rule to the practice.** Restate the invariant as *"every logical line
must be an executable Tcl command in a **live xschem interpreter**"* and enforce it by
resolving the first word (`info commands`), not by matching a string prefix. Cheap, honest
about what replay actually is, and it would catch the class the current rule catches (raw
output leaking into the log) just as well — an output line's first word is not a command.
Costs: the log is no longer a single-namespace artifact, and decision 4.1 has to be amended
by its owner.

**Recommendation: B**, with the enforcement rewritten rather than the rule merely relaxed. A
gate that three subsystems bypass unnoticed is worse than no gate; a first-word-resolves
check is strictly stronger than the prefix match *and* matches how replay really works. But
4.1 is a **locked decision** — amending it is the spec owner's call, which is why this is
filed rather than done.

## Do this before either option

Whichever way it goes, the scan must **actually see** the offending lines, or the next
subsystem will drift the same way. Two concrete gaps:

1. `test_selflog_output.tcl` scans only its own process's log. Add a leg that scans a log
   produced by a run that *did* open the viewer / LibMgr — or move the scan into
   `full_audit.sh` over every `logdir_tests` log.
2. The viewer suites' seam spy (`test_wave_modes.tcl:755-756` and siblings) means the file is
   never exercised. Keep the spy for the assertions, but add one leg that lets a real line
   through and reads it back from `[xschem get actionlog_filename]`.

## Not to be confused with 0207

0207 put ASE's **informational** text in the log as `#= ` / `#! ` comment lines, which
satisfy the rule trivially — comments are the sanctioned carrier and the seam deliberately
does not emit commands. This issue is about the sites that log **commands** in a form the
rule does not admit. 0207 is closed; this is untouched by it.

[0208](0208-the-ctrl-4-pick-has-no-replayable-log-line.md) is blocked here: its item 3 asks
for a replayable Direct-Plot line, and whether that may be `ase::ui::direct_plot …` or must
be `xschem ase_direct_plot …` is exactly the decision above.
