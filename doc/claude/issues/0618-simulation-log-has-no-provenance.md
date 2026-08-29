# 0618 — the simulation log records the simulator's chatter and nothing about the run

STATUS: **CLOSED 2026-08-23. Ruling debt SETTLED 2026-08-29 — see "RULING, 2026-08-29" at the foot of this file; it ratifies the framing and implies follow-up code and test work, not yet done.** `ase::run_deck` now writes a header at launch and
`ase::run_done` rewrites the file as header + delimiter + the simulator's verbatim
bytes + footer. All five facts the user asked for are there, and the simulator's own
region is byte-identical to what it was.

---

## RULING — 2026-08-29 (decided under the user's "decide the 23" instruction)

**1. The framing and the header wording are RATIFIED as shipped. Nothing moves.**
The five-fact header, the `--- simulator output ---` delimiter, the byte-identical
simulator region, elapsed to two decimals, the header-written-at-launch /
file-rewritten-at-completion order, the defaulted `meta` (empty `meta` = an unframed
file, byte-identical to the old behaviour), and the framing owning the newline before
the footer all stand. Each rejected alternative in the Decisions section was rejected
on a measurement, not a preference, and the shape matches what a Cadence user already
reads at the top and bottom of a spectre log. No user ruling was worth spending here.

**2. The Simulation Log window must show what the log file shows.** *This is the part
that was NOT ratifiable, and it is what the user actually complained about* — their
words were "the log file **displayed** when simulation runs". Verified in the tree:

* `ase::ui::run_started` (`src/ase_window.tcl:4936-4942`) does `log_open`, then
  **`log_clear`**, then attaches the live trace, so the window is filled with
  `::execute(data,$id)` — the simulator's stream and nothing else. The header
  `ase::run_deck` just wrote to the *file* is never put in the *window*.
* `ase::ui::run_finished` (`:4886-4896`) appends the last stream delta and the
  co-simulation diagnostics, and never appends the footer.
* So after pressing **Simulation > Netlist and Run** and watching the **Simulation
  Log** window, the user still sees no command line, no run directory, no deck path,
  no exit code and no elapsed time — exactly the complaint 0618 was filed about. The
  five facts appear only if they close that window (Ctrl-W) and reopen
  **Simulation > Log**, which then reads the finished file
  (`ase::ui::show_log`, `:4719-4753`).
* Nothing tests the window for them: `test_ase_window.tcl:2229-2233` (W6) reads the
  widget after a run and asserts only the simulator's own banner and result line.

**Instruction:** render the same header into the Simulation Log window when a run
starts, and the same footer when it ends, from `ase::run_log_header` /
`ase::run_log_footer` — never from a second copy of the words. The window and the
file must give ONE answer about a run (ruling D5-4); today they give two. The run's
`meta` has to be reachable from the UI for that (carry it on the session record from
`ase::run_deck`, or read the header back from the just-written file). Append the
header after `log_clear` and the footer after the final delta — do **not** re-render
the whole widget from the file at completion; a 50 MB log makes that a visible stall.

**3. The footer's FAILURE arm speaks plain English; the success arm does not change.**
`=== exit 1 after 0.04 s ===` is the one line in this file a user must act on, and a
bare digit does not say so at ninth-grade reading level. Keep
`=== exit <code> after <s> s` as the opening — it is the parse anchor `e_logbody`
uses for the byte-identity check (`test_ase_core.tcl:863-877`) and it must not move —
and, when the code is not 0, append a plain tail before the closing `===`, e.g.
`— the simulator stopped with an error; its own messages are above ===`.
**Exit 0 keeps its bare wording deliberately:** "finished normally" would be a claim
this log cannot support, since a co-simulation desync exits 0 with wrong waveforms
(`ase::run_done`'s own comment, `src/ase.tcl:1170-1180`). Rows E1f and E4 of
`test_ase_core.tcl` pin the current footer text and will need their tails loosened;
E1g and `e_logbody` must be left alone.

**Not decided here:** 0641 (the previous run's log is destroyed at launch) stays open
and is unaffected by any of the above.

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

---

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim: *"decide the 23, leave 0861 and 0299 for me"*. A read-only
audit of the 57-entry ruling queue had classified 25 of the debts as questions whose
answer is cheap and obvious; this debt was one of the 23 the user handed back to be
**decided** rather than read. The decision below was therefore made on the user's
behalf. It keeps items 1 and 2 of the earlier "RULING — 2026-08-29" section above,
adds two things that section missed, and **replaces its item 3** (the footer wording).

### The ruling

**A. The Simulation Log window and the log file must break in the same places — in
both directions, and through all three doors.**

1. When a run starts, put the same run header **and** the same
   `--- simulator output ---` delimiter line into the **Simulation Log** window, so
   the window and the file separate the run's facts from the simulator's chatter at
   the same point. Rendering `ase::run_log_header` alone is not enough: that proc
   stops after the `deck      :` line and `ase::run_log_write` adds the delimiter
   separately (`src/ase.tcl:1132`), so a window given the header only would run the
   five facts straight into the simulator's first line while the file breaks there.
   Same words in a different shape is still two answers.
2. When the run ends, append the same footer line to the window.
3. Cover the third door. A user who closes the log mid-run and reopens
   **Simulation > Log** lands in `ase::ui::show_log`'s live-run branch
   (`src/ase_window.tcl:4730-4736`), which fills the window from
   `::execute(data,$id)` alone. That path must show the header too, or the same
   defect walks back in through a second entrance.
4. **The direction the earlier ruling missed.** The co-simulation
   *"the results of this run cannot be trusted"* block exists today only in the CIW
   pane (`src/ase.tcl:1196-1200`) and in the Simulation Log **window**
   (`src/ase_window.tcl:4900-4906`) — both of which are gone the moment that window
   is closed — while the durable file a user opens a week later says nothing about
   it. It must be written into the log **file** as well: compute the diagnostics
   before the file is written (today `ase::run_log_write` runs at `src/ase.tcl:1162`
   and `ase::run_diagnostics` at `:1172`; the diagnostics read `$data` in memory, so
   moving the block above the write costs nothing) and emit it as its own framed
   block immediately above the footer.
5. Append only. Do **not** re-render the whole log widget from the file at
   completion — a 50 MB log makes that a visible stall.

**B. The footer speaks plain English on BOTH arms, and never points the user at
something that is not there.**

Keep `=== exit <code> after <s> s` as the opening — it is the needle `e_logbody` uses
to find the end of the simulator's region (`tests/headless/test_ase_core.tcl:863-877`)
and it must not move. Then append a tail chosen by **what was actually measured**,
never by the exit code alone:

- **exit 0** — `— the simulator ran to the end and reported no error ===`
  This claims only what the exit status measured. It does not claim the waveforms are
  right, and with (A)(4) in place a co-simulation desync now carries its own
  "the results of this run cannot be trusted" block in the same file directly above
  the footer, so the two lines cannot contradict each other.
- **non-zero, and the simulator's output region is NOT empty** —
  `— the simulator stopped with an error; its own messages are above ===`
- **non-zero, and the output region is EMPTY** (row E4's measured shape) —
  `— the simulator started but stopped without printing anything; check the command
  line above ===`. Never "its messages are above" when there are none.
- **code `-1`, i.e. no exit status was ever seen** —
  `— the run ended without reporting an exit code ===`. Do not assert an error the
  simulator never reported.

**C. Tests.** Rows **E1f** and **E4** of `tests/headless/test_ase_core.tcl` pin the
footer with end-anchored patterns and need their tails loosened to a prefix match.
**E1g** and the `e_logbody` helper's needle must be left exactly alone. Add a row that
reads the Simulation Log **widget** after a run and asserts the header fields and the
footer are in it — today `tests/headless/test_ase_window.tcl` W6 (`:2229-2233`)
reads the widget and asserts only the simulator's own banner and result line, which
is exactly why this shipped screen-blind.

**Not decided here:** 0641 (the previous run's log is destroyed at launch) stays open
and untouched.

### Why

- **CADENCE OR NOTHING.** A header of run facts at the top and an exit/elapsed line at
  the bottom is what a Cadence user already reads at either end of a spectre log, so
  the framing is not a user trade-off at all — it is the target behaviour. Every
  alternative in the Decisions section above was rejected on a measurement, not a
  preference (a failed launch never reaches `run_done`; append mode would accumulate
  across the six direct `run_done` call sites; `%.1f` renders a 40 ms give-up as
  `0.0 s`). Nothing there was worth a user ruling.
- **D5-4 — a user-facing sentence is minted in ONE place and gives ONE answer, never
  two.** This settles the part that could not be ratified. The user's own complaint
  was about "the log file **displayed** when simulation runs", and today the window
  and the file give two different answers about the same run: the window is missing
  the header and the footer, and the file is missing the loudest sentence of all, the
  co-simulation warning. D5-4 runs in both directions or it runs in neither.
- **PLAIN ENGLISH, ninth grade, say what happened and what to do.** `=== exit 1 ===`
  is the one line in this file a user must act on and it is a bare Unix digit;
  `=== exit 0 ===` is the common case and teaches a user who does not already know
  what 0 means nothing at all. Wording is delegated work under a standing user
  ruling, so both arms get sentences.
- **INTENT OVER MECHANISM, and D5-1 (never a number or a claim next to something it
  was not measured for).** "its own messages are above" is false in the exact case
  0618's own Landmines section calls "precisely the case where it is most wanted":
  row E4 runs `/bin/false`, which prints nothing and exits 1, and the row asserts the
  output region is EMPTY rather than absent. Two more shapes land on the same
  sentence — `src/xschem.tcl:280-284` puts the Tcl `catch` return into the exit status
  when `errorCode` is not `CHILDSTATUS`, so a simulator killed by a signal reads
  "exit 1" and never reported an error of its own; and `src/ase.tcl:1158` defaults the
  code to `-1` when no exit status was seen at all. The tail must therefore key off
  whether there **is** an output region, not off the exit code.
- **Why the success arm no longer stays bare.** The earlier ruling left it bare
  because a co-simulation desync exits 0 with wrong waveforms. That reason conflates
  the process ending cleanly (measured: the child returned 0) with the results being
  right (not measured) — and the honest fix was one line away in `ase::run_done`, in
  (A)(4). Once the untrustworthy-results block is in the file, "ran to the end and
  reported no error" is exactly true and cannot mislead.
- **MUST ONLY HAPPEN WHEN THE USER REQUESTS IT** is unaffected: all of this changes
  only what a log the user already opened is showing them.

### What was verified in the tree (so a later reader need not re-derive it)

- `src/ase.tcl:1030-1044` — `run_deck` builds `meta {cell simulator cmd dir deck
  started t0}` and writes the header-only file **before** `eval execute`, exactly as
  the AFTER block above claims.
- `src/ase.tcl:1069-1141` — `run_log_header` / `run_log_body` / `run_log_footer` /
  `run_log_write` ship as described. The footer format is
  `"\n=== exit %s after %.2f s ===\n"`; the `--- simulator output ---` line is
  emitted by `run_log_write` at `:1132`, **not** by `run_log_header`; an empty `meta`
  writes `$data` with no framing at all.
- `src/ase.tcl:1154-1162` — `run_done {logpath state callback {meta {}}}` rewrites
  the file in mode `w`; `$data` itself is never mutated before `result_probe` and
  `run_diagnostics` read it. `:1158` is the `set exitcode -1` default.
- `src/ase.tcl:1172` — `run_diagnostics` runs AFTER the file is written; `:1196-1200`
  echoes the co-simulation warning to the CIW only.
- `grep` for `run_log_header|run_log_body|run_log_footer|run_log_write` across every
  `.tcl` in the tree — every consumer is inside `src/ase.tcl`. No UI code renders the
  framing.
- `src/ase_window.tcl:4936-4942` — `run_started` does `log_open`, `log_clear`,
  `attach_trace`, so the widget holds only `::execute(data,$id)` deltas: the header
  never reaches the window.
- `src/ase_window.tcl:4885-4906` — `run_finished` appends the final stream delta and
  the co-simulation diagnostics, and no footer.
- `src/ase_window.tcl:4719-4753` — `show_log` reads the framed file only when there is
  no live `run_id` **and** the window does not already exist; an open window is merely
  raised. Its live-run branch at `:4730-4736` fills a reopened window from
  `::execute(data,$id)` alone.
- `src/ase_window.tcl:4687` — the window the user sees is titled
  `Simulation Log — <cell>`.
- `src/xschem.tcl:275-295` — the exit status handed to `execute(exitcode,last)` is the
  `catch` return value, not a child status, when `errorCode` is not `CHILDSTATUS`.
- `tests/headless/test_ase_core.tcl:863-877` — `e_logbody` uses `"\n=== exit "` as its
  delimiter needle; `:915-937` (E1e/E1f/E1g) and `:1017-1029` (E4) pin the FILE's
  framing, with E1f and E4 both matching the footer with `$`-anchored patterns.
- `tests/headless/test_ase_window.tcl:2229-2233` (W6) — reads the log widget after a
  finished run and asserts only the simulator's own "No. of Data Rows" banner and the
  `-i(v1)` result line. Nothing anywhere asserts the header or footer in the window.

### Does this ratify shipped behaviour, or imply a code change?

**Both.** The framing and the header wording are **ratified — nothing moves there.**
The rest **IMPLIES A CODE CHANGE, and it is follow-up work that has NOT been done:**

1. `src/ase_window.tcl`, `ase::ui::run_started` — after `log_clear`, append the run's
   header text plus the `--- simulator output ---` delimiter to the log widget (carry
   the run's `meta` onto the session record from `ase::run_deck`, or read back the
   header-only file it just wrote; never a second copy of the words).
2. `src/ase_window.tcl`, `ase::ui::show_log` live-run branch — same header and
   delimiter before the buffered stream.
3. `src/ase_window.tcl`, `ase::ui::run_finished` — after the final stream delta,
   append `ase::run_log_footer`'s line. Append only; never re-render from the file.
4. `src/ase.tcl`, `ase::run_done` — move the `run_diagnostics` block above the
   `run_log_write` call and emit the co-simulation warning into the FILE as its own
   framed block just above the footer.
5. `src/ase.tcl`, `ase::run_log_footer` — keep the `=== exit <code> after <s> s`
   opening and add the four plain-English tails of (B), choosing among them by
   whether the output region is empty and whether an exit status was seen.
6. `tests/headless/test_ase_core.tcl` — loosen E1f's and E4's footer patterns to a
   prefix match; leave E1g and `e_logbody` alone.
7. `tests/headless/test_ase_window.tcl` — add a row asserting the header fields and
   the footer are in the log WIDGET after a run.

**One line for the user:** the simulation log's header wording stays as it is — but
the Simulation Log window will now show the same run header and exit/elapsed line the
log file gets (today you only see them if you close that window and reopen
**Simulation > Log** after the run), and a failed run will say so in words instead of
just "exit 1".

### Adversary

An adversary reviewed this decision and **overturned the wording half**: it agreed the
question stays decided rather than going back to the user, but showed the proposed
failure sentence is false in row E4's measured shape and that the success arm was
being left cryptic for a reason that the (A)(4) fix dissolves. Its better answer is
the ruling recorded above.

**The user may reverse this at any time; it was decided to spare their attention, not
to bind them.**
