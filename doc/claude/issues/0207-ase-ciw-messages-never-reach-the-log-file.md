# 0207 — ASE's CIW messages never reach the log file: they are written to the log's MIRROR

Status: **OPEN**. Filed 2026-08-02 from a user report. Mechanism established by reading and
grepping (every claim carries a file:line); the fix is not yet written and nothing here is
measured against a running session.
Area: `src/ase_window.tcl` (~60 `ciw_echo` calls), `src/ase.tcl` (~21), `src/ciw.tcl`
(`ciw_echo`), `src/util.c` (`log_action`, `log_action_echo`, `log_output`),
`src/scheduler.c` (the `xschem log_action` bridge).
Tests: none yet. Format gates any fix must satisfy: `tests/headless/test_ciw.tcl`,
`test_selflog_output.tcl`, `test_selflog_grep_guard.tcl`, `test_actionlog_suppress_gate.tcl`.
Related: [0204](0204-sod-pick-mutates-the-selection.md) "What is deliberately left undone"
item 1 (the *replayable* half of this — see "Two asks, not one"), issue 0070 (D1, command
output as source-able comments), issue 0155, issue 0038.
Specs: `doc/claude/specs/action_logging.md`, `action_logging_checklist.md`,
`action_log_absorb.md`, `doc/claude/specs/ase_l.md`.

## Report

> When I am in select signals to plot command mode, and I click on net labels or wires, I
> see, in the CIW:
>
> ```
> ase: queued trace 'v(x1.minus)'
> ase: Direct Plot — 3 trace(s) queued
> ```
>
> But, these don't make it to the log file. Why? They are really useful info for debug

## Why: the CIW pane is the log's mirror, and ASE writes to the mirror

The two sinks look like one because the CIW window's **title bar shows the action-log file
path** (`src/ciw.tcl:44-48`, `wm title .ciw "xschem CIW - [file normalize $_log]"`). So the
pane presents itself as a view of that file. It is — but only in one direction.

`ciw_echo` is a pure Tk text-widget append. It opens no file, calls no `log_action`, and has
no tee:

```tcl
# src/ciw.tcl:109-120 — note the docstring: "Called from C (the log_action mirror)"
proc ciw_echo {line {tag {}}} {
  if {![llength [info commands winfo]] || ![winfo exists .ciw.l.t]} return
  .ciw.l.t configure -state normal
  .ciw.l.t insert end $line\n $tag
  ...
}
```

The file is written **only** by C `log_action()` (`src/util.c:489`), which — after writing
the line — mirrors it into the pane via `log_action_echo()` (`src/util.c:424`, a
`tcleval` of `ciw_echo`).

So the data flow is **file → pane, one way**:

```
  log_action()  ──writes──►  Xschem.log
        └────────mirrors────►  ciw_echo  ──►  .ciw.l.t     (every logged line shows)

  ase::ui::dp_queue ─────────► ciw_echo  ──►  .ciw.l.t     (nothing reaches the file)
```

ASE calls `ciw_echo` **directly**, so its lines land in the mirror without ever existing in
the thing being mirrored. Nothing is broken in the log; ASE simply never asked to be in it.

The two lines the user quoted:

```tcl
# src/ase_window.tcl:1987, in ase::ui::dp_queue  — one per pick
  catch {ciw_echo "ase: queued trace '$ex'"}
# src/ase_window.tcl:1672, in ase::ui::sod_end   — the summary
    catch {ciw_echo "ase: Direct Plot — $n trace(s) queued"}
```

### It is systemic, not two lines

`ase_window.tcl` has **60** `ciw_echo` calls and `ase.tcl` has **21**. Between them there
are exactly **3** `log_action` references, all inside one proc (`ase::ui::design_window`,
`ase_window.tcl:3331-3334`, logging a schematic load). So on the order of **80 user-visible
ASE messages are pane-only by construction** — the sibling summary
`ase: Select On Design ended — N output(s) queued` (`ase_window.tcl:1676`) included.

It is not unique to ASE either: C code calls `ciw_echo` directly in at least seven files
(`hilight.c:410-414`, `draw.c`, `scheduler.c:179`, `actions.c`, `move.c`, `paste.c`,
`callback.c`) through the guarded `tclvareval("if {[info procs ciw_echo] ne {}} …")` idiom,
with the same result. ASE is just where the density is highest.

### And it is three files, not one

Worth stating in the issue so a debugging session looks in the right place:

| stream | file | turned on by | content |
|---|---|---|---|
| **action log** | `Xschem.log[.N]` in `--logdir`, else `$TMPDIR`/`/tmp` (issue 0038) | interactive session, or explicit `--logdir`; killed by `--nolog` | replayable `xschem …` lines + `#` comments. Path readable as `xschem get actionlog_filename` |
| **debug stream** (`errfp`) | stderr, or `-l <file>` / runtime `xschem log <file>` | `-d <level>` gates `dbg()` | diagnostics. **A detached GUI launch `freopen`s stdout+stderr to `/dev/null`**, so with no `-l` this is silently discarded |
| **info window** | none (a Tk toplevel, `.infotext`) | `statusmsg(str, 2\|3)` | netlist/ERC/`check` output. Separate toplevel from the CIW, never touches either file |

The user means the first one. `--nolog` also means a headless scripted run writes no action
log at all, which is worth knowing before writing a test.

## The good news: the mechanism already exists, and comments are already legal

The action log is a **source-able** Tcl script — that is its invariant
(`action_logging.md`). But it is deliberately *also* a transcript: informational text is
carried as **comment lines**, and there are already three prefixes for it, written by
`log_output()` (`src/util.c:536`) and reachable from Tcl:

- `xschem log_action -result TEXT` → `#= TEXT`
- `xschem log_action -error TEXT` → `#! TEXT`
- a bare line already starting with `#`, and the fixed `# failed: <cmd>` form

And there is an **exact in-tree idiom** for "put this in both places", from issue 0070 D1:

```tcl
# src/action_registry.tcl:199-200
  # D1 (issue 0070): mirror the pick's OUTPUT to the CIW pane + transcript file.
  if {$err ne {}} { ciw_echo $err result ; xschem log_action -result $err }
```

So the user's ask needs no new C, no spec amendment, and no format risk: ASE's informational
echoes become `#= ase: queued trace 'v(x1.minus)'` comment lines, invisible to replay and
fully present for debugging.

## Two asks, not one — keep them apart

**(A) The user's ask: ASE's informational messages should be in the file.** Cheap, low risk,
and it fixes ~80 messages at once. The shape is an `ase::echo` seam — one proc that does the
`ciw_echo` + `xschem log_action -result` pair — and a mechanical substitution of the bare
`ciw_echo` calls in `ase_window.tcl` / `ase.tcl`. This is the deliverable.

**(B) 0204's left-undone item 1: a *replayable* line for the pick itself.** Different
problem, different altitude, unresolved design question. Quoting 0204:

> The Ctrl-4 pick no longer writes an action-log line. `select_at` stashed a replayable
> `xschem select_at x y`. It logged a *selection that no longer happens*, so keeping it
> would have been a lie — and it never made the pick replayable anyway.

(A) does **not** deliver (B): a `#=` comment is not replayable by design. Do (A) first;
(B) needs the altitude decision below and can be its own issue.

## Design decisions the fixing session must take

**D1 — seam or tee?** An `ase::echo` seam (substitute ~80 call sites) vs. teeing inside
`ciw_echo` itself (one edit, catches the C callers too). **The tee is a trap**: `ciw_echo`
is *also* the sink `log_action_echo` calls for lines that are already in the file, so a
naive tee double-writes every action line. A tee would need a re-entrancy guard around
`log_action_echo`'s call. The seam is the safer default and matches `wviewer::log_action`.

**D2 — which prefix?** `-result` (`#= `) reads as command output and is what
`action_registry.tcl` uses. An ASE notice is arguably not a "result". Options: reuse `#= `,
or log a bare `# ase: …` line. Either stays source-able; pick one and be consistent.

**D3 — the `catch` wrapper.** Every ASE `ciw_echo` is `catch`-wrapped so a broken message
can never break the pick. The seam must preserve that for both halves.

**D4 — headless.** `ciw_echo` no-ops without Tk; `log_action` no-ops when logging is off.
The seam must be correct when either or both are absent, which is also what makes it
testable under `--logdir` with `--nogui`.

**D5 — altitude for (B), if taken.** Gesture-level (`ase::ui::sod_click <key> <x> <y>` per
click, plus entry and ESC lines) vs. outcome-level (one line per queued trace at the
`dp_queue` seam, or a single `dp_finish <key> {queue}`). Gesture-level is **not
self-contained on replay**: a BUS pick opens a modal bit dialog, and the mode can be
suspended and resumed onto a *different* canvas mid-sequence (issue 0201). Outcome-level is
coordinate-free and survives both. The absorb doctrine favours outcome-level.

## Landmines

1. **`xschem log_action <flag>` with no value writes the flag name into the log.** Every
   flag arm in the dispatcher is gated on `argc > 3`, so `xschem log_action -result` with a
   missing value falls through to the bare-line arm and writes the literal line `-result`
   into `Xschem.log`. Replaying that file then executes `-result` as a command and aborts
   the `source`. Since the fix will call exactly this API from ~80 catch-wrapped sites, a
   variable that is legitimately empty would corrupt the log rather than log nothing —
   guard on `$msg ne {}` in the seam, and consider fixing the arity check in C. No test
   covers this today.
2. **`test_selflog_grep_guard.tcl`** forbids a `.tcl` file hand-logging a literal
   `xschem <verb>` for a verb whose C core self-logs, unless gated on `log_action -emitted`.
   Comment lines are not affected, but a (B) implementation would be.
3. **`test_ciw.tcl`** requires the whole log file to `source` without error into a live
   interpreter. Any new line — comment or not — has to survive that.
4. **`test_selflog_output.tcl`** requires every logical line to be a `#` comment or start
   with `xschem `. A bare `ase::ui::…` line would fail that scan, which is a live tension
   for (B) (LibMgr and the waveform viewer already log namespaced proc calls, so the rule
   and the practice have drifted apart).
5. ASE / Direct Plot / signal picking is **absent from the checklist entirely** — not a gap
   row, not a deferred row. Whatever is decided should add the row, or there is no place to
   record it.

## Two unrelated defects found while establishing this

Both are real, neither is this issue; recorded so they are not lost.

- `xschem get actionlog_filename` is handled **twice** in `scheduler.c` — the live one under
  `case 'a':`, and a byte-equivalent dead copy under `case 'c':` that the first-letter switch
  can never reach.
- `src/xschem.help` still documents the action log's default location as the **current
  working directory**. `util.c` moved it to `$TMPDIR`/`/tmp` (issue 0038) precisely to stop
  littering the source tree, so the shipped `--help` text is wrong.

## Cross-references

* `doc/claude/specs/action_logging.md` — source-ability is the invariant; comments are the
  sanctioned way to carry non-replayable text.
* `doc/claude/issues/0070-*` — D1, command output as `#= ` / `#! ` comment lines, and the
  `action_registry.tcl` idiom this fix copies.
* `doc/claude/issues/0204-sod-pick-mutates-the-selection.md` — item 1 of "left undone", the
  replayable half.
* `src/wave_viewer.tcl:2136-2140` — `wviewer::log_action`, the one-line seam pattern (and the
  rename-able spy point its tests use).
