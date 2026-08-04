# Signal Browser batch plan — ViVA-style signal browsing for the ASE waveform viewer

Generated 2026-08-03. Source of truth for the batch. Driver: `DRIVER_PROMPT.md` in this
directory. Per-item workflow: `item_pipeline.js`. Receipts: `receipts/NN_receipt.md`.

The batch shape is the one proven by `doc/claude/refactor_b_batch/` (see its `RUNBOOK.md`
for the rationale — fresh context per stage, state on disk, defer-as-success).

Research basis: `references/viva_cadence_waveform_viewer.md` §3 (Results Browser,
Search toolbar, wildcard semantics) and §13 item 1, with the corrections in
`references/viva_briefing_critique.md`. Read §3 before scouting any item — several
ViVA behaviours below are deliberate divergences and the reason is only recorded there.

---

## Status legend

- `[ ]` pending
- `[S]` scouted, verdict pending
- `[x]` DONE — implemented + adversarially verified + committed
- `[E]` DONE but **eyeball pending** — deliverable is pixels, no test can see it
- `[D]` DEFERRED — friction verdict, reason appended to the line
- `[F]` FAILED — needs a human, reason appended to the line

**An item whose deliverable is visible UI may NOT be verdicted `[x]`.** It gets `[E]`
and lands in the eyeball queue at the bottom of this file. Items marked **PIXEL** in
their heading are `[E]`-only. (Lesson: `pixel-deliverables-need-eyeball` — 2 defects
shipped past 28 green checks.)

---

## Rules of the batch

- **Strictly sequential.** Items 0→16 in order. Every item after 4 edits
  `src/wave_viewer.tcl`; parallel items would conflict. Parallelism lives *inside*
  pipeline stages, never across items.
- **One commit per green item.** Explicit file lists only — never `git add -A`,
  `git commit -a`, `git reset --hard`, never `git push`. Commit message ends with the
  item line. Order is **build → suites green → commit → raise review gate**
  (`review-commit-dont-push`).
- **Sabotage-verify every item.** Each item below names its sabotages. Every named
  sabotage must fail EXACTLY its target check, be reverted with a targeted
  `git checkout -- <file>` after confirming the diff holds only the sabotage, and the
  clean re-run must be green. No exceptions — a green suite is not evidence the changed
  code ran (`green-but-hollow`).
- **Adversarial verify is a DIFFERENT agent from the implementer.** It re-runs the
  item test, the full headless suite, and diffs the commit scope itself. One repair
  attempt, then `[F]` and move on.
- **Baseline fails** are recorded by the driver at preflight in the header block below.
  Every verifier compares against that exact list. Any new fail is the current item's
  problem, full stop.
- **GUI gate.** Any stage that runs the headless suite under a real `$DISPLAY` must go
  through `tests/headless/run_suites.sh` or `gated_xschem.sh` — never a bare
  `for i in ...; do ./src/xschem --script t.tcl; done`, which enrols in no gate and
  shows up in the panel as `UNGATED` (`gui-test-gate`). Press **Allow 2h** once before
  launching the batch.
- **Never `make` while suites run** (`headless-suite-flakes-under-cpu-load`).
- **Known-flaky, NOT regressions:** TG9 root-coords (4-in-10 even on a pristine tree),
  `test_ase_plot` P4/P6/P8 (1-2/10), bare `event generate` key delivery (~1-in-5).
  A verifier that sees one of these must re-run it before calling a fail.
- **Ambiguity never escalates to the user mid-batch.** It becomes a `[D]` with reasons,
  reviewed at the final report.
- **Stop conditions:** two consecutive `[F]`; broken build; any non-baseline audit fail
  that survives one repair; item 0 verdicting `[F]`.

### Baseline (driver fills at preflight)

```
Date: 2026-08-03
Commit at batch start: ccd5f30aa271fbd176dcfc06d8a1aa6a0a805990
full_audit exit code: 1   (SUMMARY: 264 pass  18 fail  0 crash/timeout  0 skip  (total 282); WIREEDIT: PASS; SCRATCH: 0 leaked dir(s))
Baseline fail list (verbatim):
test_ase_log_seam_0207
test_ase_window
test_cadence_drag
test_ciw
test_gf180mcud_libmgr
test_ihp_sg13g2_libmgr
test_lib_manager_gui
test_lib_manager_locate
test_lib_sweep
test_phase3_mints
test_remap
test_reopen_readonly
test_resolved_net_hash_bus_0158
test_rotate_stretch_short_0104
test_select_at
test_selflog_output
test_sky130a_libmgr
test_wave_trace_menu
Note: test_wave_trace_menu's ONLY failing check is "TG9 it was posted in ROOT
coordinates" -- the documented 4-in-10 flake, not a regression. The other 17 are
pre-existing on this tree. Build was green (`cd src && make` -> nothing to be done).
Pre-existing dirty tracked files under src/ tests/ doc/: NONE (git status --porcelain
reported only untracked `??` entries: doc/claude/signal_browser_batch/,
tests/from_user/{after_30,after_35,after_36,after_37,after_38,before_9}.sch,
tests/symbol_pin_scope_form_work/, tests/symbol_pin_scope_hilight_work/,
tests/symbol_pin_scope_work/, tests/undo_link_child/). Any tracked-file diff a later
verifier sees under src/ tests/ doc/ is the current item's, full stop.
```

---

## Settled design decisions

These are **decided**, not open. A scout that wants to overturn one must verdict `[D]`
with the reason; it may not silently substitute its own.

1. **The browser is a left sidebar inside the viewer toplevel**, not a separate
   toplevel and not a floating assistant. `$top.wvbrowser`, packed
   `pack $top.wvbrowser -side left -fill y -before $top.drw` — the same `-before`
   idiom `readout_show` (`wave_viewer.tcl:6563`) already uses for the bottom bar,
   for the same reason (a plain `-side left` after the canvas gets squeezed to zero).
   xschem has no dockable-assistant framework and building one is an `L` this batch
   does not buy.

2. **The match subject is the FULL raw name, `v(out)` — not the stripped `out`.**
   This is a deliberate divergence from `graph_get_signal_list` (`xschem.tcl:4480`),
   which strips the `v(...)` wrapper for matching *and* for display. Reason: the type
   filter derives from the `v(`/`i(` prefix, so stripping it destroys the very
   information the type dropdown needs, and a user searching `i(` deserves a hit.
   Item 3 retrofits the legacy dialog onto the shared matcher **with a compat flag**
   that preserves its stripped display — the legacy dialog's on-screen behaviour must
   not change.

3. **Wildcards are whole-name anchored**, per ViVA (`references/viva_cadence_waveform_viewer.md`
   §3.3). Shell mode: Tcl `string match` is already whole-string, so it is free. RegExp
   mode: wrap the user pattern as `^(?:$pat)$`. Document that xschem's shell mode gets
   `?` and `[a-z]` ranges from `string match` — glob features Cadence never documented.

4. **An invalid regexp is an ERROR, shown in the search bar, not a silent match-all.**
   The legacy `set err [catch {regexp $pattern {12345}} res]; if {$err} {set pattern {}}`
   (`xschem.tcl:4477`) widens a typo into "show everything", which is the worst possible
   failure for a search box. Item 1 returns an error; items 3/4 surface it.

5. **Search is live-as-you-type AND has a Search button.** ViVA is click-to-apply only
   because its databases are huge and it warns with a modal "Searching" dialog. xschem's
   var lists are thousands of entries at worst — a Tcl `string match` sweep is
   sub-millisecond. Ship both: live filter on `<KeyRelease>`, plus the button (so the
   ViVA muscle memory works, and so a future expensive All-DBs search has a trigger).

6. **Default is case-INsensitive**, `Match case` off, matching ViVA
   (*"Select the Match case check box to perform a case-sensitive search"*).

7. **Default syntax is `Shell`**, matching `viva.filter textFilterType string "shell"`.

8. **No new C code in items 1-15.** Everything is Tcl over the existing
   `xschem raw list` / `xschem raw` verb family. If a scout concludes an item needs a
   `scheduler.c` branch, that is a `[D]` — the C surface is a separate batch.

9. **Two test files, not seventeen.** `tests/headless/test_wave_sigsearch.tcl` (items
   1-7) and `tests/headless/test_wave_sigbrowser.tcl` (items 8-15). Each item APPENDS
   its checks to the right file and both files are re-run whole by every later item's
   verifier. Both get `gold/` entries if the suite convention requires one.

10. **Hierarchy sync pivots on `xschem get sim_sch_path`, in BOTH directions.**
   That getter (`src/scheduler.c:4567`) returns the path relative to the level where
   the raw was loaded — the same origin the raw's signal names use. `xschem get
   sch_path` is absolute and includes levels above the sim root; using it puts the sync
   one or more levels off, silently and plausibly. Neither item 11 nor item 12 may use
   `sch_path`. A sync is **name-addressed** (`xschem descend -inst <name>`), never
   coordinate- or index-addressed, which also makes it replayable in the action log for
   free.

11. **A failed sync rolls back.** Partway down a hierarchy is a worse place to leave a
   user than where they started. Both directions report what happened in the status bar;
   neither ever fails silently.

---

## Ledger

**This table is the ledger.** The pipeline ticks exactly one line here per item and
touches nothing else in this file except the eyeball queue. The detail sections below
are stable reference text and carry no checkbox.

- [x] 0 — PRECONDITION: 0187 FIXED (Tcl-only); 0186 carried forward as `[D]`; the
      items-8-15 auto-defer is RECOMMENDED NOT TO FIRE — its premise is measured false
      (see `receipts/00_precondition.md` §3). Driver's call.
- [ ] 1 — `wviewer::sig_match` — the shared matcher
- [ ] 2 — `wviewer::signal_list` — typed signal inventory
- [ ] 3 — retrofit the legacy dialog onto the shared matcher
- [ ] 4 — PIXEL — `wviewer::searchbar` reusable widget
- [ ] 5 — PIXEL — searchbar into `add_trace_dialog`
- [ ] 6 — multi-select plot from Add Trace
- [ ] 7 — PIXEL — plot-destination dropdown
- [ ] 8 — PIXEL — browser sidebar shell (empty)
- [ ] 9 — PIXEL — browser content: tree + search + filter
- [ ] 10 — PIXEL — RMB context menu on a browser row
- [ ] 11 — hierarchy sync: browser -> schematic ("Descend to here")
- [ ] 12 — hierarchy sync: schematic -> browser ("Show in Signal Browser")
- [ ] 13 — PIXEL — Location bar + last-20 raw history
- [ ] 14 — All DBs search
- [ ] 15 — persist browser state in snapshot/restore
- [ ] 16 — docs, guide rows, issue closure

## Item detail

### Item 0 — PRECONDITION: issues 0186 / 0187

`doc/claude/issues/0186-viewer-context-destroyed-by-reload-and-inplace-loads.md` and
`0187-wviewer-open-context-guard-is-circular.md`.
(The filename above was corrected at implement time: the PLAN as written carried 0172's
title on 0186's number. The parenthetical gloss it used — "viewer context destroyed by
reload and in-place loads" — matched the real file, so this was a typo, not a missing
anchor.)

**Why first:** item 13 persists browser state into the snapshot, and every item from 8
onward adds live widget state to the viewer toplevel. Anything that adds state makes
0186 strictly worse — a reload that destroys the context now also orphans a sidebar.

**Scope:** read both issues. The scout's job is a verdict, not a fix design:
- both already fixed on this branch → `[x]`, note the commit, proceed;
- fixable inside the pipeline's one implement stage → fix it, `[x]`;
- needs real design → `[D]`, and **items 8-15 are automatically deferred with it**
  (items 1-7 and 16 do not touch the toplevel and proceed regardless).

**Files:** `src/wave_viewer.tcl` (`wviewer::open` :624, `wviewer::forget`), the load
path in `src/xschem.tcl`.
**Test:** existing `tests/headless/test_wave_viewer.tcl`.
**Receipt:** `receipts/00_precondition.md`

---

### Item 1 — `wviewer::sig_match` — the shared matcher (pure Tcl, no UI)

The foundation. Every later item calls this; nothing else may re-implement matching.

**Contract** (write it in the proc header comment, verbatim, so a later reader cannot
guess wrong):

```tcl
# wviewer::sig_match  siglist  pattern  ?opts?
#   -syntax   shell|regexp    default shell
#   -case     0|1             default 0  (0 = case-INsensitive, ViVA default)
#   -type     all|v|i|other   default all
#   -sort     0|1|-1          0 = raw order (default), 1 = -increasing, -1 = -decreasing
# Returns: {ok  {matched names...}}   on success
#          {err {message}}            on an invalid regexp
# Matching is WHOLE-NAME anchored. shell -> `string match`; regexp -> `^(?:$pat)$`.
# The subject is the FULL raw name (`v(out)`), never the stripped form.
# An empty pattern matches everything (that is a cleared box, not a typo).
```

Plus `wviewer::sig_type {name}` → `v` | `i` | `other`, classifying on a leading
`v(` / `i(` (case-insensitively), and used by `-type`.

**Files:** `src/wave_viewer.tcl`, new procs near the other pure helpers (NOT inside
any dialog proc).
**Test:** create `tests/headless/test_wave_sigsearch.tcl`. Cover at minimum:
shell `l*` matches `l...` and NOT `xl...`; regexp `l*` matches **everything** (the
documented ViVA trap — assert it, it is not a bug); regexp `l.*` matches `l...` only;
`net[0-9]` range; literal-bracket escape `*net_name[[]*`; `?` single-char;
case-insensitive default vs `-case 1`; `-type v` excludes `i(...)`; empty pattern =
all; invalid regexp `[` returns `{err ...}` and **not** the whole list.
**Sabotages (3):** (a) drop the `^(?:...)$` anchoring → the regexp-anchoring check
fails and nothing else; (b) flip the `-case` default to 1 → the case check fails;
(c) restore the legacy `if {$err} {set pattern {}}` → the invalid-regexp check fails.
**Done:** all checks green, 3 sabotages fire on exactly their targets.
**Receipt:** `receipts/01_sig_match.md`

---

### Item 2 — `wviewer::signal_list` — typed signal inventory

One accessor every consumer uses instead of open-coding `split [xschem raw list] "\n"`
(currently done at `wave_viewer.tcl:7190`).

**Contract:** `wviewer::signal_list {token}` → list of dicts
`{name <full raw name> type <v|i|other> leaf <last dot-segment> path <all but last>}`.
Returns `{}` when no raw is loaded (the `catch {xschem raw list}` arm at `:7187` — keep
that behaviour, it is what produces the *"no raw data loaded"* note). Must switch to the
viewer's `win_path` context first and **verify the switch followed** — landmine 17, the
rule this file states at `wviewer::open` and has been burned by before.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigsearch.tcl`. Load a fixture raw, assert count, assert
a known `v(...)` classifies `v`, an `i(...)` classifies `i`, a dotted hierarchical name
splits into `path`/`leaf`, and that a token with no raw returns `{}` without throwing.
**Sabotages (2):** (a) delete the context-switch verify → the wrong-context check fails;
(b) make the no-raw arm throw instead of returning `{}` → the no-raw check fails.
**Receipt:** `receipts/02_signal_list.md`

---

### Item 3 — retrofit the legacy dialog onto the shared matcher

`graph_get_signal_list` (`src/xschem.tcl:4469`) is the only search box that exists
today, and it silently turns a bad regexp into match-all.

**Scope:** reimplement its body as a call to `wviewer::sig_match` with
`-syntax regexp -case 1 -sort $graph_sort`, then apply the legacy display strip
(`regsub {^v\((.*)\)$}`) to the RESULT. **On-screen behaviour must not change** except
that an invalid pattern now yields an empty list rather than the whole list. Keep the
`graph_sort` global and its `-increasing`/`-decreasing` mapping exactly.

⚠ `src/xschem.tcl` may not depend on `wave_viewer.tcl` having been sourced. Scout must
confirm load order; if the dependency is wrong, move `sig_match` to a shared file and
say so in the receipt.

**Files:** `src/xschem.tcl`.
**Test:** append to `test_wave_sigsearch.tcl` — call `graph_get_signal_list` directly
with a known list: sort order both ways, the `v()` strip still happens in the output,
and a bad regexp returns `{}` not everything.
**Sabotage (1):** revert the strip → the display check fails.
**Receipt:** `receipts/03_legacy_retrofit.md`

---

### Item 4 — **PIXEL** — `wviewer::searchbar` reusable widget

The ViVA Search toolbar as a self-contained megawidget with no consumer yet.

**Contract:** `wviewer::searchbar_build {parent args}` → the frame path.
`-command <cb>` is called as `<cb> <pattern> <syntax> <case> <type>` on every live
keystroke and on the Search button. `-showbutton 0` hides the button (the Filter bar
variant). `wviewer::searchbar_get {w}` → the same four values as a dict, for snapshot.

**Widgets, in ViVA's order** (§3.2): type dropdown (`All / Voltage / Current / Other`)
→ pattern entry → syntax dropdown (`Shell / RegExp`) → `Match case` checkbutton →
`Search` button. Defaults: type `All`, syntax `Shell`, case OFF. Plus an error label
that shows `sig_match`'s `err` message and clears on the next valid keystroke.

Theme through `ase::ui::apply_theme`, fonts `AseLabelFont` / `AseEntryFont`, error
label foreground `[ase::theme accent]` — the same treatment `add_trace_dialog` gives
`$w.err` at `:7198`.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigsearch.tcl` — build it on a throwaway toplevel,
assert every child exists and its default value, assert the callback fires with the
right four args on a simulated keystroke, assert the error label populates on `[`.
**Sabotage (1):** change the syntax dropdown default to RegExp → the default check fails.
**Eyeball:** widget order, spacing, that the error label does not resize the bar.
**Receipt:** `receipts/04_searchbar.md`

---

### Item 5 — **PIXEL** — searchbar into `add_trace_dialog`

**Scope:** insert a searchbar above `$w.vars` in `add_trace_dialog`
(`wave_viewer.tcl:7152`), filtering the listbox through `wviewer::sig_match` over
`wviewer::signal_list`. Set `$w.vars -selectmode extended`.

⚠ **Do not redesign the dialog.** It already has, and must keep: the Graph combobox
(`:7160`, hidden when `< 2` graphs), the Expression row (`:7172`), the
`Name (optional):` row (`:7173`), and the `$w.err` label (`:7183`). The searchbar's own
error label is separate from `$w.err`; `$w.err` stays the RPN/no-raw channel. Grid rows
shift — renumber every `grid` call, do not leave a hole.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigsearch.tcl` — open the dialog headless, type a
pattern, assert the listbox contents shrink to the matching set and grow back when
cleared; assert the Graph combobox / Name entry / err label still exist and still work
(a regression guard for the "do not redesign" clause).
**Sabotages (2):** (a) make the filter reset the selection → the
selection-survives-filter check fails; (b) delete the Name row → the regression guard
fails.
**Eyeball:** the dialog is not taller than the screen; the bar does not steal focus
from the Expression entry (`focus $ee` at `:7200` must still win).
**Receipt:** `receipts/05_addtrace_search.md`

---

### Item 6 — multi-select plot from Add Trace

**Scope:** `add_trace_ok` (`:7217`) currently reads one selection
(`lindex $sel 0` at `:7226`). Make the empty-expression path add **one trace per
selected row**, in listbox order, each through the existing
`wviewer::add_trace $token $gi $rpn $name`. Rules: a non-empty Expression entry still
wins and still adds exactly one trace (the RPN path is unchanged); the `Name` field
applies only when exactly one row is selected (N traces cannot share one name — with
N > 1 and a name typed, show that in `$w.err` and add nothing); the first error from
any trace aborts the rest and reports, leaving the already-added ones in place.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigsearch.tcl` — select 3, OK, assert 3 traces; assert
the RPN path still adds 1; assert name+multi is refused with a message and adds nothing.
**Sabotages (2):** (a) keep `lindex $sel 0` → the 3-trace check fails; (b) drop the
name+multi refusal → that check fails.
**Receipt:** `receipts/06_multiselect.md`

---

### Item 7 — **PIXEL** — plot-destination dropdown

ViVA's `Append / Replace / NewSubWin / NewWin`, mapped to xschem's model.

**Mapping** (decided): `Append` → current behaviour, land per `plan_plot`
(`wave_viewer.tcl:1491`); `Replace` → clear the target graph's traces first, then add;
`New Strip` → force a fresh graph regardless of plot mode; `New Tab` → open a new
viewer tab and land there. `plan_plot` is already the pure landing *policy* — extend
it, do not fork it. Default `Append`, persisted per window.

⚠ ViVA's `Append` has a unit-collision rule (*different unit → new Y axis; four Y axes
already → new subwindow instead*). xschem has **no unit metadata at all** —
`save.c read_dataset` discards ngspice's per-var type. Do not attempt it. Record the
divergence in the receipt.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigsearch.tcl` — one check per policy asserting the
resulting graph/trace counts.
**Sabotages (2):** (a) make Replace behave as Append → the Replace check fails;
(b) make New Strip respect plot mode → the New Strip check fails.
**Eyeball:** dropdown placement; New Tab actually raises the new tab.
**Receipt:** `receipts/07_destination.md`

---

### Item 8 — **PIXEL** — browser sidebar shell (empty)

*Depends on item 0. If item 0 is `[D]`, this and everything after it defer with it.*

**Scope:** `$top.wvbrowser` frame, `pack ... -side left -fill y -before $top.drw`.
A `View > Signal Browser` menu checkbutton mirroring a per-token variable, plus a
bindtag key on `WaveViewer` (pick an unused one — **run the written three-path
collision check** that `wave_viewer.tcl` documents per key, and record the three paths
checked in the receipt). Show/hide follows the `readout_show` (`:6563`) pattern
exactly: pack/unpack against the mirror, `catch {pack forget}`, `pack ... -before`.
Content: a placeholder label only.

**Files:** `src/wave_viewer.tcl`.
**Test:** create `tests/headless/test_wave_sigbrowser.tcl` — toggle on/off, assert
`pack info` presence/absence, assert the canvas `$top.drw` survives both, assert the
menu checkbutton and the key agree.
**Sabotages (2):** (a) drop `-before $top.drw` → a geometry check fails (assert the
canvas keeps non-zero width); (b) desync the menu variable from the key → the agree
check fails.
**Eyeball:** the canvas does not jump or repaint wrong on toggle (WSLg repaint is a
known trap here); sidebar width is sane and the divider is draggable if one is added.
**Receipt:** `receipts/08_sidebar_shell.md`

---

### Item 9 — **PIXEL** — browser content: tree + search + filter

**Scope:** fill the sidebar. `ttk::treeview` over `wviewer::signal_list`, grouped by
the `path` field (dot-separated hierarchy) with leaves as rows; flat when no signal has
a path. A `searchbar_build` at the top (with the Search button) and a second
`searchbar_build ... -showbutton 0` at the bottom as ViVA's **Filter** bar — both feed
`sig_match`, ANDed. `-selectmode extended`. Plot gestures, all three, per §3.4:
**double-click**, **middle-click**, and a **Plot** toolbar button — each honouring
item 7's destination dropdown.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigbrowser.tcl` — assert tree population from a fixture
raw, assert grouping for a hierarchical name, assert each of the three plot gestures
adds a trace, assert search and filter AND together.
**Sabotages (3):** (a) break the AND so filter is ignored → that check fails;
(b) remove the MMB binding → the MMB check fails; (c) flatten the grouping → the
hierarchy check fails.
**Eyeball:** tree indentation, column width, that a 2000-signal raw is not
unusably slow to populate.
**Receipt:** `receipts/09_browser_tree.md`

---

### Item 10 — **PIXEL** — RMB context menu on a browser row

**Scope:** Plot (per destination), Plot to → `Append / Replace / New Strip / New Tab`
(a one-shot override of the dropdown), `Send to Add Trace…` (opens
`add_trace_dialog` with the name prefilled into the Expression entry), `Copy name`.

Reserve a **`Descend to here`** entry, greyed/disabled, at the bottom of the menu.
Item 11 fills it in. Reserving it now means item 11 does not have to re-touch the menu
construction and risk the 0178 swallow.
Follow the Tcl-only Button3 swallow that issue 0178 established for the legend
(`wave_viewer.tcl:7680`) — the canvas RMB must not also fire.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigbrowser.tcl` — assert menu entry labels, assert each
entry's effect, assert the RMB does not reach the canvas.
**Sabotage (1):** drop the swallow → the canvas-must-not-see-it check fails.
**Eyeball:** menu posts at the pointer, entries not greyed wrongly on an empty selection.
**Receipt:** `receipts/10_browser_rmb.md`

---

### Item 11 — hierarchy sync: browser -> schematic ("Descend to here")

The user descends the browser tree to `x1.x2`, invokes the command, and the ASE-L
session's **schematic** window is at that same point in the hierarchy — opened, raised
and activated if it was not already.

**All primitives exist. No C.**

- `xschem descend -inst <name>` (`src/scheduler.c:2811`) — name-addressed descend:
  `get_instance(name)`, `unselect_all`, `select_element`, `descend_schematic`. Returns
  non-zero on success; errors with *"instance not found"*. This is the coordinate-free
  replay form the action log already emits, so a sync is replayable for free.
- `xschem get sim_sch_path` (`src/scheduler.c:4567`) — the current hierarchy path
  **relative to the level where the raw was loaded**, i.e. the same origin the raw
  signal names use. This is the pivot for BOTH directions. Do not use
  `xschem get sch_path`, which is absolute and includes levels above the sim root.
- `xschem go_back` — ascend one level.
- `raise_activate_toplevel` — the WSLg raise idiom (issue 0054: a bare
  `deiconify`/`raise` is a no-op there).

**Algorithm** (write it in the proc header so nobody re-derives it wrong):

1. Target = the tree node's dotted instance path, sim-root-relative, e.g. `x1.x2`.
2. Resolve the ASE-L session's design window from the token; if it is gone, open it;
   then `raise_activate_toplevel` + `focus`.
3. **Verify the context followed** before touching hierarchy state — landmine 17, the
   rule `wviewer::open` documents and this file has been burned by. A switch under a
   raised semaphore silently no-ops roughly 3 times in 10.
4. Read `xschem get sim_sch_path`. Compute the common prefix with the target.
5. `xschem go_back` once per level of current-beyond-common-prefix.
6. `xschem descend -inst <seg>` once per remaining target segment.
7. Redraw / `xschem zoom_full` per the existing descend convention.

**The traps, all of which must be handled and tested:**

- **Case.** ngspice lowercases: the raw carries `x1.x2`, the schematic instance is
  `X1`. `get_instance()` is case-sensitive. The scout must establish the real
  behaviour from source and the matcher must be case-insensitive **with the
  case-sensitive attempt tried first** (an exact hit always wins, so a design that
  genuinely has both `x1` and `X1` still resolves correctly).
- **Partial failure must roll back.** If segment 3 of 4 does not resolve, `go_back` the
  levels already descended and report — never strand the user halfway down a hierarchy
  they did not ask for. This is the single most important behaviour in the item.
- **Vector instances.** `descend -inst` picks the instance; the slice is separate
  (`xschem change_sch_path n`, `scheduler.c:2341`; the slice reached is readable as
  `xschem get sch_inst_number`). If the target path segment carries a slice index,
  either apply it via `change_sch_path` or verdict `[D]` for vectors specifically and
  handle scalars only — say which, in the receipt, and open an issue for the other.
- **Unsaved changes / read-only.** Descend goes through the normal path; do not
  bypass any existing guard. If a guard refuses, report it in the status bar and roll
  back what was already descended.
- **Already there** = a no-op that still raises the window, and says so.

**Entry points:** an entry in item 10's browser RMB menu ("Descend to here"), a
`View` (or `Hierarchy`) menu item, and a `WaveViewer` bindtag key — run the written
three-path collision check and record the three paths in the receipt.

**Files:** `src/wave_viewer.tcl`; possibly `src/ase_window.tcl` for the design-window
handle (read-only use of the session state — do not restructure it).
**Test:** append to `tests/headless/test_wave_sigbrowser.tcl` against a 2-3 level
fixture: descend 2 levels and assert `sim_sch_path`; a sibling-to-sibling sync
(requires an ascend then a descend, not just a descend); a bad segment leaves
`sim_sch_path` **exactly as it started** (the rollback check); already-at-target is a
no-op; case-mismatched path still resolves.
**Sabotages (3):** (a) remove the rollback → the bad-segment check fails and the tree
is left descended; (b) use `sch_path` instead of `sim_sch_path` → the sync lands one or
more levels off and the 2-level check fails; (c) drop the case-insensitive retry → the
case check fails.
**Receipt:** `receipts/11_sync_to_schematic.md`

---

### Item 12 — hierarchy sync: schematic -> browser ("Show in Signal Browser")

The mirror. From the schematic at `x1.x2`, one command opens/raises the viewer, expands
the browser tree to that node, selects it, and scrolls it into view.

**Direction-specific pieces:**

- Source of truth is again `xschem get sim_sch_path`, read in the **schematic's**
  context. Verify the context is the one you think it is before reading it.
- `wviewer::open $token` is already raise-or-open and returns 0 for an unknown token —
  reuse it, do not write a second opener.
- If the browser sidebar is hidden, show it (item 8's mirror) as part of the command.
- If the tree has no node for that path — the usual cause is that the raw simply has no
  signals under that instance — **say so in the status bar and select the deepest
  ancestor that does exist.** Silently doing nothing is the failure mode to avoid.
- If no raw is loaded at all, report that and stop.

**Entry points:** a schematic-side menu item, plus a key. Both must work while the
schematic is descended and while it is at the top. Consider the precedent in
`ase-direct-plot-hierarchy-0168` (a descended Direct Plot resolves against the
ancestor that owns the raw) — this item resolves against the same origin, and the
scout should confirm the two agree rather than assume it.

**Files:** `src/wave_viewer.tcl`, `src/ase_window.tcl` (menu/key on the design window),
`src/cadence_style_rc` if the key is bound there.
**Test:** append to `tests/headless/test_wave_sigbrowser.tcl` — descend the schematic
2 levels, invoke, assert the tree selection is the matching node and that it is
visible (its ancestors are expanded); assert the deepest-ancestor fallback for a path
with no signals; assert a clear report when no raw is loaded; assert the sidebar
un-hides.
**Sabotages (3):** (a) select the node without expanding ancestors → the visible check
fails; (b) remove the deepest-ancestor fallback → that check fails; (c) skip the
sidebar un-hide → that check fails.
**Receipt:** `receipts/12_sync_to_browser.md`

---

### Item 13 — **PIXEL** — Location bar + last-20 raw history

**Scope:** ViVA's Location field (§3.1). An editable path entry at the top of the
sidebar, Enter commits and loads that raw; a dropdown of the last 20 raw files opened,
newest first, deduped, persisted in the config the same way other viewer prefs are.
Replaces nothing — `select_raw` (`xschem.tcl:14209`, a bare `tk_getOpenFile`) stays as
the Browse… button beside it.

⚠ **Do not pollute Open Recent.** Issue 0119 is exactly this class of bug: a
`--script` verification run re-polluted the recent-files list. The raw history is its
own store, and headless/`--script` loads must not write to it.

**Files:** `src/wave_viewer.tcl`, config var registration in `src/xschem.tcl`.
**Test:** append to `test_wave_sigbrowser.tcl` — assert history grows, dedups, caps at
20, newest-first; assert a `--script` load does NOT append.
**Sabotages (2):** (a) remove the dedup → that check fails; (b) let the headless load
append → the 0119 guard fails.
**Eyeball:** long paths do not blow out the sidebar width (ViVA right-justifies with a
tooltip — do that).
**Receipt:** `receipts/13_location_bar.md`

---

### Item 14 — All DBs search

**Scope:** the `All DBs` checkbox from §3.2, searching every open results database, not
just the current one. xschem's equivalent registry is `xctx->extra_raw_arr[]`
(`src/save.c`, reachable from `scheduler.c:9517`'s `raw`/`raw_query` branch). Scout
must first establish **from source** what the Tcl-visible enumeration of extra raws is;
if there is no getter, this is a `[D]` (decision 8 — no new C in this batch).
Matched rows from a non-current DB are labelled with their source in the tree.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigbrowser.tcl` — two raws loaded, assert All-DBs finds
a signal that exists only in the second and labels its source; assert it is excluded
when the box is off.
**Sabotage (1):** ignore the checkbox → the excluded-when-off check fails.
**Receipt:** `receipts/14_all_dbs.md`

---

### Item 15 — persist browser state in snapshot/restore

*Depends on item 0 being `[x]`.*

**Scope:** `wviewer::snapshot` (`wave_viewer.tcl:2165`) / `restore` (`:2212`) carry:
sidebar visible?, sidebar width, search pattern/syntax/case/type, filter
pattern/syntax/case/type, destination policy, raw-file history, **the browser tree's
expanded-node set and current selection** (so a restore lands where the user left it —
and so item 12's sync survives a session round-trip). Follow the existing
deliberate exclusions — undo/redo history, wave highlights and the per-tab `view` range
cache are excluded on purpose; do not "fix" that here.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigbrowser.tcl` — snapshot → destroy → restore, assert
every field round-trips; assert a snapshot taken with the sidebar hidden restores hidden.
**Sabotages (2):** (a) drop one field from the snapshot → its round-trip check fails;
(b) restore the sidebar always-visible → the hidden check fails.
**Receipt:** `receipts/15_persist.md`

---

### Item 16 — docs, guide rows, issue closure

**Scope:**
- New spec `doc/claude/specs/waveform_signal_browser.md`: the settled decisions above,
  the divergences from ViVA and **why** (anchoring, error-not-match-all, live+button,
  full-name subject, no unit rule), and the widget contracts.
- The spec must carry a **hierarchy-sync section**: the `sim_sch_path` pivot and why
  `sch_path` is wrong, the descend/ascend algorithm, the rollback rule, the case-folding
  rule, and whatever items 11/12 concluded about vector instances. This is an
  xschem-only feature — ViVA has no documented equivalent of "put the schematic where
  the browser is" — so there is no upstream doc to fall back on and this spec is the
  only record.
- `doc/waveform_viewer_guide.html`: a `data-seq` row per new key/gesture. Note
  `test_wave_grid.tcl` GH1/GH2/GH5 assert those rows — extend the assertion, don't
  break it.
- Open a numbered issue under `doc/claude/issues/` for each `[D]` this batch produced.
- Add a `references/viva_cadence_waveform_viewer.md` §13-item-1 back-pointer to the
  new spec.

**Files:** docs only.
**Test:** `tests/headless/test_wave_grid.tcl` still green with the extended row set.
**Sabotage (1):** remove one new `data-seq` row → the guide check fails.
**Receipt:** `receipts/16_docs.md`

---

## Eyeball queue

Items verdicted `[E]` land here with their commit hash. Batch them into one review
session at the end; the driver does not block on them.

| Item | Commit | What to look at | Eyeballed? |
|------|--------|-----------------|------------|
|      |        |                 |            |

---

## Deferred / failed

Appended by the pipeline's ledger stage with the full reason. Do not summarise —
a `[D]` reason is the input to the next batch.

### Item 0 — issue 0186 `[D]` (0187 in the same item was FIXED)

`doc/claude/issues/0186-viewer-context-destroyed-by-reload-and-inplace-loads.md` was
re-measured at `ccd5f30a` on 2026-08-03 and still reproduces verbatim
(`before wv=1 ro=1 rects2=1` → `after wv=1 ro=0 rects2=0`). Two independent reasons it
is deferred rather than fixed:

1. **It needs C.** The two families of site are `src/scheduler.c:10036` (the `reload`
   branch, whose body `unselect_all(1); remove_symbols(); load_schematic(...)` has no
   guard) and the routing-exempt in-place loads (`scheduler.c` / `src/save.c:3734`,
   `:3810`, `:3814`, `:3827`). Batch **decision 8** forbids new C in items 1-15.
   `src/xschem.tcl` holds only a `xschem reload` *caller* (`:13074`, plus
   `action_registry.tcl:183`), so no Tcl edit can close it.
2. **Its Part 2 is an undecided design question by the issue's own words** — the
   in-place loads are "arguably correct as it stands"; the open question is whether
   "explicit" should still mean "explicit" when the target is a viewer.

New data for whoever picks it up: the **raw survives intact** (424 vars / 20503 points,
before and after), so the blast radius is the graph-rect model only; **reload frees no
Tk widget** (a sidebar packed `-before $top.drw` survives packed, with its child); and
**under a real `DISPLAY` reload on a viewer also HANGS** on the modal
`alert_ {Unable to open file: …}` at `save.c:3814` — a symptom the original `--nogui`
filing could not see. The split-out `readonly`-cleared-on-failed-load defect is item
16's to file; the next free issue number is **0212**, not 0188.
