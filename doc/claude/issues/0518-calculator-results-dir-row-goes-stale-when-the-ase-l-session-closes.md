# 0518 — the Calculator's Results Dir row goes stale when the ASE-L session closes

**Status:** OPEN. Filed 2026-08-20 by the results/calculator batch measuring
round (no repo edit outside this file). **Branch:** `fluid-editing`.
**Area:** `calc::results_publish` (`src/calculator.tcl:1105`) and its four
callers — `calc::build_res` (`:759`), `calc::open`'s raise arm (`:419`),
`calc::res_toggle`'s expand (`:1209`) and `calc::require_result` (`:1156`).
The resolver they publish is `calc::results_source` (`:948`) →
`calc::session_result` (`:924`) → `calc::viewer_tokens` (`:855`) /
`calc::ctx_result` (`:889`) / `calc::token_origin` (`:904`); the strings are
`calc::results_label` (`:1066`) and `calc::results_tip` (`:1077`).
The teardown paths are `ase::ui::close` (`src/ase_window.tcl:294`) →
`ase::session_close` (`src/ase.tcl:3653`) + `wviewer::close`
(`src/wave_viewer.tcl:1296`) → `wviewer::forget` (`:840`).
**Specs:** `doc/claude/specs/calculator.md` W05 (`:201`) — *"**R705 binds**:
this is a live query, never a cached or persisted value"* — and R705 itself
(`:806-807`).
**Severity:** silent. The row states a fact about the world that is no longer
true, nothing corrects it *on its own*, and the only gesture that **reveals**
the error is a gesture that repairs it. Two of the four publishers do repair it
— measured, a later `calc::open` (the raise arm, `:419`) and a collapse+expand
(`calc::res_toggle`, `:1209`) both re-resolve the stale row back to
`Results Dir:` / `(no raw file loaded)` — but silently, saying nothing about
what was there before, and only if the user happens to make one of those two
gestures. Evaluate is the third, and it is the only one that says why.

---

## What happens

The Results Dir row is a **published snapshot**, not a live readout. Three
widgets carry it — the label `.calc.res.lab` (W04), the readonly entry
`.calc.res.path` (W05) and the `balloon` tooltip baked into
`bind .calc.res.path <Enter>` — and all three are written by
`calc::results_publish` (`src/calculator.tcl:1105`) from a measurement its
caller took. There are exactly four callers, and the file enumerates them as
complete:

```tcl
# sentence.  The callers are the moments the answer can have changed:
# `calc::build_res`, at the end of building the row, which is the only one that
# runs on a FIRST open and is therefore the one that delivered item 13's fix (do
# not delete it as an unlisted extra -- `calc::open`'s raise arm does not run
# when there is nothing to raise); `calc::open`'s raise arm, for a later open
# onto a world that has moved; the row's own expand, whose whole meaning is
# "show me that path again"; and now Evaluate (U3).
```
— `src/calculator.tcl:839-845`, and the same list in
`doc/claude/specs/calculator.md:201` (*"⚠ FOUR callers since item 10, not
three"*).

**A session or a viewer disappearing is a moment the answer changes, and it is
not on that list.** So it publishes at build/raise/expand/Evaluate — the
nearest thing the file says about that is the `results_publish` header's
*"a refresh runs at BUILD time"* (`:1100`, written to justify not printing a
status line) and the tooltip note *"there is one string and it changes rarely"*
(`:1121-1122`). **Neither is a statement that a stale row is acceptable**, and
the spec sentence they sit under says the opposite. This is a plain bug against
R705, not an accepted design limit being reported.

Measured, with a real ASE-L session, a real waveform-viewer window and a real
`tran` raw, and no shims (full transcript below):

```
A2 after close sessions={} viewer win exists=0 viewer_tokens={}
A2 row         label={Results Dir (ASE-L session):}  entry={$W/an.raw}
              tooltip={The result selected in the ASE-L session (lib0518/cell0518/(unsaved)).}
A2 source      none {} {} {} {}
```

The tooltip names a session key that is no longer in `::ase::sessions`.

### The gesture table

Every leg measured on `:99` in one process each, priming the same
session+viewer+result before each gesture.

| gesture | row afterwards | `calc::results_source` afterwards |
|---|---|---|
| ASE-L `Session ▸ Close` (`$top.mb.session`'s own `-command`, `src/ase_window.tcl:465-466` → `ase::ui::close_request`) | **STALE** — `Results Dir (ASE-L session):` + the raw's path + the `ase` tooltip | `none {} {} {} {}` |
| WM **X** on the ASE-L window (`wm protocol … WM_DELETE_WINDOW`, `src/ase_window.tcl:277` — the same `ase::ui::close_request`) | **STALE**, identical | `none {} {} {} {}` |
| closing the **waveform viewer** window only (`wviewer::close`, `src/wave_viewer.tcl:1296`; the window's own `WM_DELETE_WINDOW` reaches the same `wviewer::forget` via the `<Destroy>` bind at `:1276`) | **STALE**, identical — and now *wrong twice*: the session is alive with no viewer, so the advice this world earns is `calc::no_viewer_msg`, not the `ase` arm the row shows | `none {} {} {} {}` |
| destroying the **schematic window** the Calculator was opened from (a second window via `xschem load_new_window -window`, then `xschem new_schematic destroy .x2.drw` → rc 1, toplevel gone) | **correct, unchanged** | `ase <path> <key> tran 0` (`require_result ok=1`) |
| ASE-L `Session ▸ New` | **does not exist.** The Session menu is exactly `{Design Window} {Load State} {Save State} -- Close` (`src/ase_window.tcl:455-466`, read back off the live widget) | — |

The schematic-window row is the correct behaviour, not an exception: since U6
the row reports the *session's viewer*, and no schematic window is on that path.

### Is there a refresh that exists but does not fire? No — there is none at all

* **`.calc` itself carries exactly one binding**: `bind .calc <Configure>` →
  `calc::save_layout` (`src/calculator.tcl:485`), which writes the layout file
  and never touches the row. The strings `<Visibility>`, `<FocusIn>`, `<Map>`
  and `<Expose>` do not occur in `src/calculator.tcl` at all. The other ten
  `bind` calls are a sash release (`:487`), the status combobox (`:628`), the 22
  selector buttons (`:1369`), two comboboxes (`:1469-1470`, `:1874-1875`) and
  the wheel handlers (`:2261-2267`). The row's own `<Enter>` is `balloon`'s
  (`src/xschem.tcl:14918`) — it *shows* the string baked in at publish time and
  re-resolves nothing.
* **No `trace add variable` exists in `src/calculator.tcl`, `src/ase.tcl`,
  `src/ase_window.tcl` or `src/wave_viewer.tcl`** other than
  `src/ase_window.tcl:4885`, which watches `::execute(data,$id)` for live log
  tailing.
* **A session-notify seam exists and is not wired to close.**
  `ase::session_notify_fire` (`src/ase.tcl:3540`) is called from
  `ase::session_update` (`:3583`), `session_save` (`:3605`), `session_adopt`
  (`:3626`), `session_load` (`:3638`) and `session_revert` (`:3648`) — **not**
  from `ase::session_close` (`:3653-3657`, a three-line `dict unset`) and not
  from `ase::new_session` (`:3851`). It is also a **scalar**, not a list
  (`variable session_notify {}`, `src/ase.tcl:75`), and it is already owned:
  `set ::ase::session_notify ase::ui::session_changed` (`src/ase_window.tcl:271`).
* **`wviewer` has a teardown hook** — `bind $top <Destroy> "+… wviewer::forget"`
  (`src/wave_viewer.tcl:1276`) — and it calls `wviewer::forget` only.

### Do the row and Evaluate contradict each other on screen? Measured: no

The file states, above `calc::no_result_advice`:

```tcl
# The choice lives HERE, one level up, where both callers -- the row's tooltip
# and `calc::require_result` -- reach it, so the row and Evaluate can never give
# different advice about the same world.
```
— `src/calculator.tcl:1050-1052`

**That claim holds, and it was measured to hold.** `calc::require_result`
resolves once and publishes the row *from that same measurement* before it
composes anything:

```tcl
proc calc::require_result {} {
    set src [calc::results_source]
    catch {calc::results_publish $src}
```
— `src/calculator.tcl:1154-1156`

So pressing Evaluate on the stale row repairs the row **inside the same call
that refuses**. Measured, both worlds, with nothing else touching the row in
between:

```
A3 press Evaluate (calc::eval_click):
A3 row         label={Results Dir:}  entry={(no raw file loaded)}
              tooltip={No simulation results are loaded. Run a simulation, or pick an existing one with ASE-L ▸ Results ▸ Select.}
A3 status      {No simulation results are loaded. Run a simulation, or pick an existing one with ASE-L ▸ Results ▸ Select.}

B3 press Evaluate:
B3 row         label={Results Dir:}  entry={(no raw file loaded)}
              tooltip={The ASE-L session has no waveform viewer, and the Calculator reads the session's viewer — …}
```

Label, entry **and** tooltip all follow, and in leg B the tooltip picks up
`calc::no_viewer_msg` — the same sentence the status line gets. **There is no
moment at which the row and Evaluate contradict each other on screen.**

That is worse in one specific way, and it is the point of this issue: the row's
only error-reporting channel is the gesture that erases the error. A user who
reads `Results Dir (ASE-L session): …/an.raw`, believes it, and presses Evaluate
sees the row change under their hand at the same instant they are told there is
nothing to evaluate against. A user who reads it and does **not** press Evaluate
is simply told something false, indefinitely, with no cue.

### It is stale in the other direction too

Same mechanism, opposite sign — the Calculator open with nothing loaded, then a
session + viewer + result appear:

```
(M) Calculator opened with nothing loaded: row={Results Dir:} {(no raw file loaded)}
(M) a session+viewer+result now EXIST: src=ase $W/an.raw mlib/mcell/(unsaved) tran 0
(M) row, no refresh              = {Results Dir:} {(no raw file loaded)}
(M) require_result ok            = 1
(M) row after that call          = {Results Dir (ASE-L session):} {$W/an.raw}
```

The row says there is nothing while `require_result` says `ok=1`. Any fix
hooked to *teardown* leaves this half alive.

## Reproducer

Save as `<scratch>/repro0518.tcl` and run from the repo root. No PDK, no
simulator; `::USER_CONF_DIR` is redirected and `::update_recent_files` is 0, so
nothing touches `~/.xschem/raw_history` or `~/.xschem/recent_files`.

```sh
DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog --script <scratch>/repro0518.tcl
```

```tcl
# doc/claude/issues/0518 reproducer.  No PDK, no simulator, no config-dir write.
set W [file normalize [file join [file dirname [info script]] w0518]]
file delete -force $W ; file mkdir $W/conf
set ::USER_CONF_DIR $W/conf      ;# keep raw_history / recent_files off ~/.xschem
set ::update_recent_files 0
proc wr {p b} { set f [open $p w] ; puts -nonewline $f $b ; close $f }
wr $W/cellA.sch "v {xschem version=3.4.4 file_version=1.2}\nG {}\nV {}\nS {}\nE {}\nN 0 0 200 0 {}\n"
wr $W/an.raw "Title: 0518\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 2\nNo. Points: 2\nVariables:\n\t0\ttime\ttime\n\t1\tv(n1)\tvoltage\nValues:\n0\t0.000000000000000e+00\n\t1.000000000000000e+00\n\n1\t1.000000000000000e-08\n\t2.000000000000000e+00\n\n"
proc p {args} { puts [join $args " "] ; flush stdout }
proc S {s} { return [string map [list $::W {$W}] $s] }
proc row {} {
  set l - ; set e - ; set t -
  catch {set l [.calc.res.lab cget -text]}
  catch {set e [.calc.res.path get]}
  catch {regexp {balloon_show %W \{\{(.*)\}\} [0-9]+$} [bind .calc.res.path <Enter>] -> t}
  return "label={$l}  entry={[S $e]}\n              tooltip={[S [lindex [split $t "\n"] 0]]}"
}
proc prime {} {
  catch {calc::close}
  foreach k [dict keys $::ase::sessions] { catch {ase::ui::close $k} }
  xschem load $::W/cellA.sch ; update
  set k [ase::new_session lib0518 cell0518 schematic]
  ase::ui::open $k lib0518 cell0518 schematic ; update
  wviewer::open $k ; update
  wviewer::attach_raw $k $::W/an.raw tran ; update
  calc::open ; update
  return $k
}
proc world {} {
  set s {} ; catch {set s [dict keys $::ase::sessions]}
  set w {} ; catch {set w [dict keys $::wviewer::windows]}
  return "sessions={$s} viewer win exists=[llength $w] viewer_tokens={[calc::viewer_tokens]}"
}

# ============ A: ASE-L  Session > Close  (the menu entry's own -command) ======
set k [prime]
p "A1 primed      [world]"
p "A1 row         [row]"
p "A1 source      [S [calc::results_source]]"
ase::ui::close_request $k                        ;# == the Session>Close -command
update
p ""
p "A2 after close [world]"
p "A2 row         [row]                      <-- UNCHANGED"
p "A2 source      [S [calc::results_source]]                          <-- gone"
p ""
p "A3 press Evaluate (calc::eval_click):"
calc::eval_click ; update
p "A3 row         [row]"
p "A3 status      {[S $::calc::statusmsg]}"

# ============ B: only the WAVEFORM VIEWER window closed ======================
set k [prime]
p ""
p "B1 primed      [world]"
wviewer::close $k                                ;# viewer window X / Ctrl-W
update
p "B2 after close [world]"
p "B2 row         [row]                      <-- UNCHANGED"
p "B2 source      [S [calc::results_source]]"
p "B2 sessions_without_viewer={[calc::sessions_without_viewer]}"
p "B3 press Evaluate:"
calc::eval_click ; update
p "B3 row         [row]"
p "B3 status      {[string range $::calc::statusmsg 0 70]...}"
exit 0
```

Actual output at `30d87dee` (xschem banner lines and the `Raw file data read:` /
`free_rawfile()` engine chatter elided; `$W` is the scratch dir):

```
A1 primed      sessions={lib0518/cell0518/(unsaved)} viewer win exists=1 viewer_tokens={lib0518/cell0518/(unsaved)}
A1 row         label={Results Dir (ASE-L session):}  entry={$W/an.raw}
              tooltip={The result selected in the ASE-L session (lib0518/cell0518/(unsaved)).}
A1 source      ase $W/an.raw lib0518/cell0518/(unsaved) tran 0

A2 after close sessions={} viewer win exists=0 viewer_tokens={}
A2 row         label={Results Dir (ASE-L session):}  entry={$W/an.raw}
              tooltip={The result selected in the ASE-L session (lib0518/cell0518/(unsaved)).}                      <-- UNCHANGED
A2 source      none {} {} {} {}                          <-- gone

A3 press Evaluate (calc::eval_click):
A3 row         label={Results Dir:}  entry={(no raw file loaded)}
              tooltip={No simulation results are loaded. Run a simulation, or pick an existing one with ASE-L ▸ Results ▸ Select.}
A3 status      {No simulation results are loaded. Run a simulation, or pick an existing one with ASE-L ▸ Results ▸ Select.}

B1 primed      sessions={lib0518/cell0518/(unsaved)} viewer win exists=1 viewer_tokens={lib0518/cell0518/(unsaved)}
B2 after close sessions={lib0518/cell0518/(unsaved)} viewer win exists=0 viewer_tokens={}
B2 row         label={Results Dir (ASE-L session):}  entry={$W/an.raw}
              tooltip={The result selected in the ASE-L session (lib0518/cell0518/(unsaved)).}                      <-- UNCHANGED
B2 source      none {} {} {} {}
B2 sessions_without_viewer={lib0518/cell0518/(unsaved)}
B3 press Evaluate:
B3 row         label={Results Dir:}  entry={(no raw file loaded)}
              tooltip={The ASE-L session has no waveform viewer, and the Calculator reads the session's viewer — a result selected while the session has no viewer is not visible here. Run a simulation, or open the session's waveforms and then pick a result with ASE-L ▸ Results ▸ Select.}
B3 status      {The ASE-L session has no waveform viewer, and the Calculator reads the ...}
```

⚠ **Do not probe `calc::require_result` before the Evaluate press.** It
publishes (`:1156`); a diagnostic call to it repairs the row and the press then
appears to have done nothing. The first draft of this reproducer had exactly
that leg and had to be removed.

## Why it matters

* **The row's whole job is to say which database an expression will resolve
  against**, and its label — W04, `.calc.res.lab`
  (`doc/claude/specs/calculator.md:200`) — was given a provenance because *"a
  path with no provenance is worse than no path, because it reads as the current
  context's and is silently somebody else's; the short form is on W04's label,
  the long form … is the `balloon` tooltip on the entry"* (that sentence sits in
  the **W05** row, `doc/claude/specs/calculator.md:201`, and hands the short form
  to W04). A
  row naming a **dead** session is that trap one step further on: the
  provenance is not merely unhelpful, it is false, and it names a specific
  session key the user can no longer find.
* **It breaks the spec sentence directly.** The W05 row says of this exact
  resolution: *"**R705 binds**: this is a live query, never a cached or
  persisted value"* (`doc/claude/specs/calculator.md:201`; R705 itself, `:806-807`,
  is the narrower rule about not persisting across a reopen). Between two of its
  four publishers the row **is** a cache, rendered on screen, with no expiry.
* **The failure is silent and self-erasing.** No status line is written on
  teardown — deliberately (`src/calculator.tcl:1098-1104`, R508/S16: a fresh
  window starts silent) — and the row corrects itself only when acted on, so a
  screenshot or a bug report of the Calculator taken after teardown documents a
  result that is not there.
* **Phase 3 lands on top of this.** `calc::require_result` already answers
  `{ok origin path type idx msg}` for the computation phase
  (`src/calculator.tcl:1160-1168`; `doc/claude/specs/calculator.md`
  R603-R607). The gate itself is safe — it re-resolves. The row is the only thing the user reads *before* deciding to
  press it.

## Fix — candidates in order

Ranked by "cannot be defeated by a teardown path nobody thought of". Cost of a
re-resolve, measured on this machine at `30d87dee` (`time … 50` / `… 200` in the
live process):

| | with a live viewer holding a result | with no viewer (empty walk) |
|---|---|---|
| `calc::results_source` | **0.028 ms** | 0.0024 ms |
| `calc::results_refresh` (resolve + publish) | **0.064 ms** | 0.027 ms |

**1. Never render a measurement older than the look — re-resolve on an
idle/timer while `.calc` is mapped.** This is *"resolve lazily at read time so
the row is never a cache"* in the only form Tk allows: a `label`/`entry` holds
literal text, there is no read hook to make lazy, so "never a cache" has to mean
"re-published faster than a person can notice". One
`after` chain armed in `calc::build` and cancelled in `calc::close`. **Touches
`src/calculator.tcl` only.** At a 500 ms cadence the measured cost is ≤ 0.013 %
of one core. It cannot be defeated by any teardown path, present or future,
because it knows nothing about teardown — and it is the **only** candidate that
also fixes the reverse-direction staleness above.
**It needs one ruling before it can be written:** `calc::results_source`
takes the 0173 loan per token, and a refused loan publishes
`(results unavailable: the session's context is busy)` (`:1109-1110`). A timer
tick landing on a busy context would flicker the row into a refusal the user did
not cause. The tick must therefore **keep the last published state on a
`refused` walk** and let `refused` be published only from a user-initiated
resolve (Evaluate, expand, open) — which is T-J's own logic, applied to a
caller T-J did not have.

**2. Two write traces, both installed from `src/calculator.tcl`:** on
`::ase::sessions` (`src/ase.tcl:68`) and on `::wviewer::windows`. Every gesture
in the table above **that stales the row** — rows 1-3, the three teardowns —
mutates one of the two, so two traces cover all three. (Rows 4 and 5 do not:
row 4 leaves both registries byte-identical across the `xschem new_schematic
destroy`, measured, which is why it does not stale the row either, and row 5
does not exist.) The two mutation points are `ase::session_close`'s
`dict unset` (`src/ase.tcl:3655`) and `wviewer::forget`
(`src/wave_viewer.tcl:840`), the single point every viewer token passes through
on the way out (reached from `wviewer::close` `:1301`, the `<Destroy>` bind
`:1276`, and the stale-entry arm `:1088`). **One file touched, no new
dependency in either direction.** A
teardown path added later still has to go through the registries or its token
would keep answering, so this is close to undefeatable *for teardown*. It does
**not** catch a result being selected or cleared inside a viewer that stays
open — the reverse-direction case.

**3. Explicit `calc::results_refresh` calls from the teardown procs** — the
obvious repair, plus the viewer half it needs to be complete: one in
`ase::ui::close` (`src/ase_window.tcl:294`, after `:304`/`:318`) and one in
`wviewer::forget` (`src/wave_viewer.tcl:840`). **Touches `src/ase_window.tcl`
and `src/wave_viewer.tcl`.** The dependency direction is not new
(`src/ase_window.tcl:579` already calls `calc::open`). Same teardown coverage as
(2) but re-earned by hand at every future teardown site, which is exactly the
class of omission that produced this issue.

**4. A trace on `::ase::sessions` alone.**
**Measured insufficient**: gesture B stales the row with `::ase::sessions`
unchanged (`B2 … sessions={lib0518/cell0518/(unsaved)}`). It is candidate (2)
with one of its two halves missing.

**5. Re-resolve on `<FocusIn>` / `<Visibility>` of `.calc`.**
**Measured and refuted.** With `.calc` at `+100+100` and the ASE-L window
overlapping it at `+120+120`, closing the session delivers **80 `<Visibility>` +
156 `<Expose>`** events to `.calc`. With the two windows **disjoint**
(`.calc` at `+40+40`, ASE at `+1000+600`) it delivers **zero** — no
`<Visibility>`, no `<Expose>`, no `<FocusIn>`, no `<Map>` — and the row stays
stale. Side-by-side is the layout a user picks for two windows they read
together, so this arm works precisely when it is least needed. Cheapest to
write, and wrong.

## Coverage

`tests/headless/test_calc_skeleton.tcl` S26/S27 own this row and already assert
the label, the entry, the tooltip *binding* (not just the formatter) and the
five-element `results_source`. The gap is narrow and exact:

* **S27's own R705 leg is one line short of catching this.**
  `tests/headless/test_calc_skeleton.tcl:3490-3495` is titled *"S27 R705:
  nothing was cached — the answer is live"*; it removes the shims, asserts
  `calc::results_source` is `{none {} {} {} {}}` — and then calls
  `pcall calc::results_refresh` at `:3492` **before** reading the row at
  `:3493-3495`. It proves the *resolver* is live. Nothing in the suite reads the
  row after a world change with **no refresh in between**, which is the whole of
  this defect.

A test must assert, with **no `calc::results_refresh` and no
`calc::require_result` between the world change and the read**:

1. prime a live session + viewer + result, read all three widgets;
2. tear the session down through `ase::ui::close_request` (the real menu
   `-command`), read all three again — they must have changed;
3. the same for the **viewer-only** close (`wviewer::close`), so a fix hooked to
   the session alone cannot pass;
4. the **reverse** direction: `.calc` open showing `(no raw file loaded)`, then a
   session + viewer + result appear, and the row must name them;
5. a **negative control** — the assertion must go red with the fix line deleted
   (S27's own history: `build_res`'s refresh was deleted and the suite stayed
   all-pass, `:3499-3509`);
6. if candidate 1 is taken, that a timer tick landing on a **refused** loan does
   **not** publish `(results unavailable: …)`.

⚠ **Match the tooltip on a distinctive prefix, not a substring.**
`calc::no_viewer_msg` (`src/calculator.tcl:1038`) contains the words
*"The ASE-L session has no waveform viewer"*, so a `*ASE-L session*` glob
classifies it as the `ase` arm. This report's own first probe did exactly that
and briefly appeared to show a contradiction that does not exist. Match
`The result selected in the ASE-L session` for the `ase` arm.

## Related

- issue **0516** — a result selected through `Results ▸ Select…`'s `here` arm is
  invisible to the Calculator. Same row, same resolver, opposite failure: 0516
  is the row correctly reporting a place it does not read, this is the row
  reporting a place that no longer exists.
- issue **0517** — the four ASE-L result sentences overflow the status entry
  (the other 283 strings the status line can hold all fit; 0517 was rescoped
  from a wrongly universal title). The two meet in leg B: the row is stale *and*
  `calc::no_viewer_msg`, the sentence that would correct it, is cut at
  `…reads the session's vie`.
- issue **0509** — `raw read` of an already-loaded file reports success but
  leaves it bound to the old cell. The same class: a stamp treated as a property
  of the thing when it is a property of the moment it was taken.
- `doc/claude/specs/calculator.md` W05 (`:201`), R705 (`:806-807`), R508.
- `doc/claude/specs/results_selection.md` §17 U3 / U6 / U7, R503f, R603.
- `doc/claude/calculator_batch/LEDGER.md` — the batch that owns this window.
  Its item 13 (`0c104dac`) is the fix `calc::build_res`'s publish call carries
  (`src/calculator.tcl:840-842`), and its item 8 (phase 3a, Evaluate /
  R603-R607) is the phase that lands on this row.
  `doc/claude/results_batch/LEDGER.md` item 10 (`407dc86b`) is where the row
  stopped being a reporter (U3) and gained the fourth publisher.
