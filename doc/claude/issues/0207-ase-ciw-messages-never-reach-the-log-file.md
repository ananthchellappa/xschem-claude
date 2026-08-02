# 0207 — ASE's CIW messages never reach the log file: they are written to the log's MIRROR

Status: **RESOLVED** 2026-08-02, ask (A) only. Filed the same day from a user report and
established by reading; **now measured** — see "What Step 1 actually showed", which
confirmed the mechanism exactly and corrected two of the assumptions underneath it.
Ask (B), a *replayable* line for the pick, is out of scope by design and is now
[0208](0208-the-ctrl-4-pick-has-no-replayable-log-line.md).
Area: `src/ase.tcl` (the new `ase::echo` seam + 10 call sites), `src/ase_window.tcl`
(56 call sites), `src/scheduler.c` (the `xschem log_action` arity backstop), `src/ciw.tcl`
(`ciw_echo`, unchanged), `src/util.c` (`log_action`, `log_action_echo`, `log_output`,
all unchanged).
Tests: `tests/headless/test_ase_log_seam_0207.tcl` (new, X + `--logdir`, legs `PS*`/`RP*`,
26 checks). Format gates it had to satisfy and does: `tests/headless/test_ciw.tcl`,
`test_selflog_output.tcl`, `test_selflog_grep_guard.tcl`, `test_actionlog_suppress_gate.tcl`.
Related: [0204](0204-sod-pick-mutates-the-selection.md) "What is deliberately left undone"
item 1 (the *replayable* half — now [0208](0208-the-ctrl-4-pick-has-no-replayable-log-line.md)),
issue 0070 (D1, command output as source-able comments), issue 0155, issue 0038.
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

---

# What Step 1 actually showed

Measured by running the new test against **pristine `open_pdk`** (`git checkout src/ase.tcl
src/ase_window.tcl`, the C and doc changes left in place), under a real DISPLAY with a real
CIW and `--logdir`:

```
ok:   PS0b CIW log pane exists
ok:   PS2 the pick's message is in the CIW pane
FAIL: PS3 the pick's message is in the LOG FILE
ok:   PS4 the ESC summary is in the CIW pane
FAIL: PS5 the ESC summary is in the LOG FILE
FAIL: PS6 the mode-entry notice is in the LOG FILE too
note: log lines added by the pick = {0}
```

and the whole log file after a complete Ctrl-4 arm → pick → ESC:

```
# xschem action log
# launch: …/src/xschem --pipe -q --logdir /tmp/tmp.nz5A1TTHt9 --script …
# cwd: /home/analog/dev/xschem-claude
```

Three header comments. **Zero lines from the entire gesture.** The pane had both messages;
the file had neither. The report is exact and the mechanism in "Why" is exact.

After the fix, the same gesture:

```
#= ase: Direct Plot — click wires/net labels for voltage traces, sources for current traces; ESC plots
#= ase: queued trace 'v(named)'
#= ase: Direct Plot — 1 trace(s) queued
```

## Two things the measurement CORRECTED

1. **`ciw_echo` is not absent headless.** `src/ciw.tcl` is sourced unconditionally
   (`xschem.tcl:14312`) and the proc self-no-ops on its own `winfo` check, so `::ciw_echo`
   exists under `--nogui`. Measured: `CIW_EXISTS=::ciw_echo`, `HASX=0`. What actually
   suppressed ASE's notices headless was the call sites' `[info exists ::has_x]` guard —
   `::has_x` is *unset* under `--nogui`. Those guards are what had to go; the availability
   check did not. This is why the fix is testable at all under `--nogui --logdir`.
2. **0206's known failure did not reproduce.** The session prompt warned that
   `test_ase_plot.tcl` P4/P6 fail on `open_pdk` already. They passed here — `ALL PASS (150
   checks)`, with all sixteen P4 legs and the P6 legs green. Recorded as an observation, not
   a claim that [0206](0206-ase-plot-p4-direct-plot-click-queues-nothing.md) is fixed; it
   means the baseline was clean for this session and could not have masked a regression.

## Two pre-existing failures that are NOT this change

Both reproduce **identically on pristine HEAD** (verified by `git stash` + rebuild + re-run):

| suite | failing legs |
|---|---|
| `test_ciw.tcl` | `no result/error text in file` |
| `test_selflog_output.tcl` | `key Shift-F logs flip`, `Alt-F flip_in_place`, `Shift-R rotate`, `Alt-R rotate_in_place`, `Shift-V flipv`, `Alt-V flipv_in_place` |

Not investigated here. They are the only two red suites in the whole run set.

# The fix

## D1 — a seam, not a tee. Taken as recommended.

`proc ase::echo {msg {tag {}}}` in `src/ase.tcl`, mirroring `wviewer::log_action`
(`wave_viewer.tcl:2138-2140`) and the "both places" idiom at `action_registry.tcl:199-200`.
All 66 bare `ciw_echo` calls substituted: 10 in `ase.tcl`, 56 in `ase_window.tcl`.

The tee was rejected for the reason the issue predicted, and the rejection is now *measured*
rather than argued: `ciw_echo` is also the sink `log_action_echo()` calls for lines already
in the file, so a naive tee double-writes every action line. Three ASE suites assert an
**exact notice count** (`test_ase_locked_wire_pick_0160` LK8d, `test_sod_pick_no_select_0204`
line 295) or **exact emptiness** (LK8b, SO10b). Measured through the seam: 5 `ase::echo`
calls → exactly 5 `::ciw_echo` calls. A tee would have reddened all four legs.

## D2 — `#= ` / `#! `, keyed off the pane tag. Taken.

`-result` for a plain notice, `-error` for a site that already passes the `error` tag (39 of
the 66 do). Reasons for this over a hand-built `# ase: …` line:

- `log_output()` (`util.c:536`) prefixes **every** physical line of a multi-line message. A
  hand-built comment does not, so an embedded newline would turn a continuation line into
  live Tcl on replay.
- It is exactly what `action_registry.tcl:199-200` already does for command output.
- The tag is already at every call site, so the error/result split costs nothing and the
  pane and the file agree on severity.

## D3 — the `catch` wrapper. Kept, and doubled.

Both halves are `catch`'d **inside** the seam, so correctness no longer depends on the call
site. The call sites' own `catch` wrappers were left in place: it keeps the substitution a
pure 1:1 rename (`catch {ciw_echo ` → `catch {::ase::echo `), which is what makes the
`fluid-editing` merge trivial.

## D4 — headless. Correct, and now the primary test surface.

`log_output()` no-ops on a NULL `actionlog_fp`, the pane half no-ops without Tk. The
`[info exists ::has_x]` guards at the three `ase.tcl` sites and the whole-proc early return
in `ase::no_session_notice` were **removed** — they were the reason the notices could not be
logged headless. The `[info commands ::ciw_echo]` check is kept as a cheap belt (ciw.tcl is
sourced 37 lines *after* ase.tcl, so a future source-time notice would otherwise lose its
pane half silently).

## D5 — altitude for (B). Not implemented; written up as [0208](0208-the-ctrl-4-pick-has-no-replayable-log-line.md).

Recommendation recorded there: **outcome-level** at the `dp_finish` seam
(`xschem ase_direct_plot <key> {expr…}`), because it is coordinate-free and therefore
survives both hazards that kill the gesture form — a bus pick's modal bit dialog, and
0201's suspend/resume onto a different canvas. Leg **PS13** pins the current absence, so a
future (B) has to land deliberately.

## Landmine 1 — fixed on BOTH sides

`xschem log_action -result` with a missing value used to fall through every `argc > 3` gate
to the bare-line arm and write the literal line `-result` into `Xschem.log`; replaying that
file executes `-result` and aborts the `source`. **8 of the 66 call sites pass a bare
catch-result variable** (`$err`, `$r`, `$st`, `$nl`, `$id`) that is empty if a callee ever
does `return -code error {}`.

- Tcl side: the seam returns before logging when `$msg eq {}`.
- C side (`scheduler.c`, the `log_action` arm): the five value-taking flags are now matched
  at `argc > 2` and a missing value is a **no-op** instead of a fall-through. An unrecognised
  `argv[2]` still reaches the bare-line arm, as before.

Defence in depth on purpose: sabotage S3 (both guards removed) and S4 (C backstop only)
both go red, so each is independently load-bearing.

## Landmine 2 — a NEW one, found while fixing landmine 1

A Tcl comment whose line ends in a **backslash** continues onto the next line. Measured:

```
#= ase: ends with backslash\
puts SWALLOWED          <- never runs
```

So a logged message ending in `\` eats the **following** log line on replay. Reachable:
14 sites end in interpolated text, all paths or Tcl error strings, and `ase::expand_path`
deliberately preserves backslashes for Windows paths (`-nobackslashes`).

The crosscheck found a second face of it the first guard missed: `log_output()` writes no
prefix after a final newline, so a message ending `"\\\n"` also lands as `#= …\` — and
`[string index $msg end]` sees the *newline*. The seam therefore `trimright`s the newlines
first, then pads a trailing backslash with one space (logged copy only; the pane copy is
byte-identical to before). Legs PS12b/c/d.

**No format gate catches this.** `test_selflog_output.tcl`'s source-ability leg accumulates
physical lines with `info complete`, which recognises a leading `#` as a comment and returns
1 regardless of a trailing backslash — measured. Only `test_ase_log_seam_0207` PS12 sees it,
and only because PS12c *replays* rather than greps: the physical line always survives, the
damage happens at `source` time.

## Sabotage table

Each row: break one thing, run `test_ase_log_seam_0207`, confirm the legs that should die,
do. Every leg has at least one killer, so none is green by accident.

| # | what was broken | legs that went RED | verdict |
|---|---|---|---|
| S1 | the seam's `xschem log_action` half dropped | PS3, PS5, PS6, PS7a, PS7a2, PS7b, PS7d, PS12a — **8** | the file half is real |
| S2 | the seam's `::ciw_echo` half dropped | PS2, PS4, PS7d, PS8 — **4** | the pane half is real, and PS8 proves the pane copy comes from the seam, not from a mirror |
| S3 | BOTH empty-message guards (Tcl `$msg eq {}` + C backstop) | PS10a, PS11, PS12c, PS12d, RP1 — **5** | an empty message really does corrupt the log; RP1 shows it aborts `source` |
| S4 | the C backstop only (Tcl guard intact) | PS11, PS12c, PS12d, RP1 — **4** | the C fix is independently load-bearing, not redundant |
| S5 | the trailing-backslash pad | PS12b, PS12c, PS12d — **3** | the pad is load-bearing; PS12c/d are the ones that matter (they replay) |
| — | pristine `open_pdk` (the RED-first repro) | PS1, PS3, PS5, PS6, PS7a, PS7a2, PS7b, PS7d + FATAL — **8** | the fix is what makes the suite green |

Two legs deliberately have no sabotage row: **PS9** (format gate) and **PS13** (no
replayable line) are *absence* assertions — they go red when a future change adds something,
which is their whole job.

## What is deliberately left undone

1. **(B), the replayable pick line** — [0208](0208-the-ctrl-4-pick-has-no-replayable-log-line.md).
   Pinned absent by PS13.
2. **`src/wave_viewer.tcl`'s ~75 `ciw_echo` sites.** Same pane-only class, out of scope by
   instruction (the `fluid-editing` branch is actively editing that file). It already has
   `wviewer::log_action` as its seam. **Found while crosschecking:** that seam writes
   *replayable-looking* lines like `wviewer::set_plot_mode single K` (`wave_viewer.tcl:2197`
   and 11 other sites) — bare namespaced proc calls, which violate
   `test_selflog_output.tcl`'s rule that every logical line is a `#` comment or starts with
   `xschem `. Filed as [0209](0209-log-format-rule-and-practice-have-drifted.md), where it
   turned out to be 32 sites across three files and a decision (amend the rule or narrow the
   practice), not a viewer bug.
3. **C code calling `ciw_echo` directly** — `hilight.c:410-414`, `draw.c`, `scheduler.c:179`,
   `actions.c`, `move.c`, `paste.c`, `callback.c`, via the guarded
   `tclvareval("if {[info procs ciw_echo] ne {}} …")` idiom. Same class, not surveyed.
4. **`ase.tcl`'s plot-mode notice (`ase: waveform viewer plot mode = …`) was KEPT in the
   log, against two independent recommendations to leave it pane-only.** It genuinely
   duplicates `wviewer::set_plot_mode`'s own logged line one line above, in both channels,
   and on the `new eq cur` path the wviewer line is not written at all — so it is a duplicate
   on the interesting path and the only record on the boring one. Kept anyway because the
   merge note demanded one uniform substitution pattern with no special cases, and because a
   `#=` restating a command in human terms is precisely the `action_registry.tcl` transcript
   shape. Revisit if the log gets noisy.
5. **Three volume flags, all measured, none acted on.** `dp_queue`/`sod_queue` fire **once
   per bus BIT** (`sod_click`'s `foreach t $toks`), so one click on a 32-bit bus writes 32
   lines; the "already queued" and "v1 queues source currents only" notices repeat per
   duplicate/miss-click; `auto_plot`'s per-row error fires after every run. Kept: they are
   the *only* record of what a Direct Plot session picked, and a run of identical lines is an
   honest transcript of a user clicking the same thing repeatedly — which is what the
   reporter asked the log for. Checked and clean: `ase::ui::sod_prompt_pump` re-arms every
   80 ms and does **not** echo; it and `force_window_repaint` are the only two `after` calls
   in `ase_window.tcl`.
6. **The action-log spec's own staleness.** `action_logging.md` §1 and locked decision 4.2
   still say the default location is the launch cwd; issue 0038 moved it to `$TMPDIR`//tmp.
   `xschem.help` and checklist row 1 were corrected here (below); the spec's own two lines
   were left alone — amending a *locked decision* is the owner's call, not a drive-by.

## The two unrelated defects: both fixed

- **The dead `actionlog_filename` arm.** `scheduler.c` handled `xschem get
  actionlog_filename` twice: the live one under `case 'a':`, and a byte-equivalent copy under
  `case 'c':` that the first-letter switch can never reach. The dead copy is removed (a
  comment marks the spot so it does not get "helpfully" re-added).
- **`src/xschem.help`'s wrong default.** It documented the action log's default location as
  the current working directory; `util.c:363-374` has used `$TMPDIR`, else `/tmp`, since
  issue 0038 — precisely to stop littering the source tree. Corrected. Checklist row 1 now
  records the move and flags the spec lines that still disagree.

## Tests

New: `tests/headless/test_ase_log_seam_0207.tcl` — 26 checks, X + `--logdir`, legs `PS*`
(seam) and `RP*` (replay). Prefixes `NM` remains free.

Run set, all after the change:

| suite | result |
|---|---|
| `test_ase_log_seam_0207` (new) | ALL PASS (26) |
| `test_selflog_grep_guard` | ALL PASS (391 legs, matches baseline exactly) |
| `test_actionlog_suppress_gate` | ALL PASS |
| `test_select_at` | ALL PASS |
| `test_ciw_actionlog_output` | ALL PASS (25) |
| `test_ase_plot` | ALL PASS (150) |
| `test_ase_interact` | ALL PASS (63) |
| `test_ase_unnamed_net` | ALL PASS (28) |
| `test_sod_pick_no_select_0204` | ALL PASS (66) |
| `test_ase_locked_wire_pick_0160` | ALL PASS (16) |
| `test_ase_hier_pick_0161` / `test_ase_hier_plot_0168` | ALL PASS (21 / 31) |
| `test_ase_core` | ALL PASS (66) |
| `test_window_numbering`, `test_nh_editor_buttons`, `test_nh_editor_load`, `test_nh_angle_clamp` | ALL PASS |
| `test_ciw`, `test_selflog_output` | **FAIL — identical on pristine HEAD**, see above |

### The five ASE suites that stub `ciw_echo`: checked, all left unchanged

`test_ase_locked_wire_pick_0160`, `test_sod_pick_no_select_0204`, `test_ase_hier_pick_0161`,
`test_ase_hier_plot_0168` (conditional `rename ciw_echo real_ciw_echo` + a bare
`proc ciw_echo {msg args}`) and `test_ase_unnamed_net` (`::`-qualified, unconditional).
**All five still intercept, and none needed editing.** `ase::echo` resolves `::ciw_echo` by
name at call time, so a rename+redefine stub is exactly what runs — measured with each stub
shape, not reasoned. The two properties that made "no edit" the right answer:

- **no doubling** (D1 above), which is what keeps the exact-count and exact-emptiness legs
  green;
- **`::ciw_echo` exists even under `--nogui`**, so `test_ase_unnamed_net`'s *unconditional*
  rename is safe and the other four's restore guards always fire.

One landmine noted for whoever writes the next one: `ase::echo` always calls `::ciw_echo`
with **two** arguments inside a `catch`. `test_nh_angle_clamp.tcl:22` is the tree's only
arity-1 stub (`proc ciw_echo {msg}`) and it *silently drops* a 2-arg call. It is safe today
(it captures `hilight.c`'s 1-arg C path, not ASE) — but do not copy that shape into an ASE
test.

## Cross-references

* `doc/claude/specs/action_logging.md` — source-ability is the invariant; comments are the
  sanctioned way to carry non-replayable text.
* `doc/claude/issues/0070-*` — D1, command output as `#= ` / `#! ` comment lines, and the
  `action_registry.tcl` idiom this fix copies.
* `doc/claude/issues/0204-sod-pick-mutates-the-selection.md` — item 1 of "left undone", the
  replayable half.
* `src/wave_viewer.tcl:2136-2140` — `wviewer::log_action`, the one-line seam pattern (and the
  rename-able spy point its tests use).
