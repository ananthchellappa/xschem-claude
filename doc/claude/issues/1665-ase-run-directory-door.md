# 1665 — ASE-L had no door for the run directory

**STAMP:** `v1 claim=fixed tree=47c687ef4 stamped=2026-10-19 fix=taken open=0 by=driver`

The user asked (2026-10-19) whether ASE-L lets them set the run directory, and to
add it if not: "Cadence's ADE-L lets the user do it on the same form that chooses
simulator, but we need not do it that way. A separate menu item to pop up a dialog
is fine."

## What was wrong

The state has always carried a `rundir` key (`ase::state_default`), and the engine
reads it everywhere through `ase::rundir`: the deck, raw, log, `.meas`, `.plotmap`,
campaign shards, the results resolver, the viewer's stored rawfile. **Nothing in
the window wrote it.** Only a hand-edited `.state` file or the campaign shard code
could, while two engine refusals told the user to "set a run directory" —
`ase::predeck_plan`'s `filewhy` and `ase::campaign_refusals`' `sharedrundir`
remedy — a gesture that did not exist.

## What landed

- **Setup > Run Directory…**, after Simulators… (`ase::ui::rundir_dialog`):
  a modeless dialog with the path, Browse…, Use Default, an "Empty = shared:
  <path>" hint, an in-dialog status line, OK/Cancel, ESC and the title-bar X
  both running Cancel (`ase::ui::dialog_close_protocol`).
- **Session state** (the 1395 rule): OK writes the key through
  `ase::ui::set_rundir`, the session goes dirty, the close and quit prompts
  follow, Save State persists it. `set_rundir` is scriptable and logs one
  replayable line per change.
- **Engine procs, pure and headless-counted** (`src/ase.tcl`, "THE RUN-DIRECTORY
  DOOR"): `ase::rundir_validate` (absolute storage form, expansion before the
  character test, the backend's own `path_quoted`/`shell_word` probes called
  rather than re-spelled, filesystem refusals, advisory notes),
  `ase::rundir_set` (rebases a stored relative `viewer.rawfile` so it keeps
  naming the same file), `ase::rundir_busy` (refuses OK while a run or campaign
  is live), `ase::rundir_default_preview` (read only), and
  `ase::rawfile_relative`, the R602 predicate moved out of
  `ase::ui::viewer_rawfile_relative` so the rebase and the relativiser share it.
- Both refusals now name the door ("… (Setup > Run Directory…)" and "set one in
  Setup > Run Directory…"); row RD-L holds the typed engine literals equal to
  `ase::ui::menu_path_run_dir`.

## Decided, with reasons (doc/claude/specs/ase_l.md "Run directory")

- Stale results are left alone: nothing is deleted or moved, the panes re-read
  from disk (a fresh directory honestly shows no results), plotted waves stay.
- A relative input is stored absolute (every reader resolves the key against the
  process cwd). Upper case, spaces and symbols are accepted with a note — ADE-L
  is a floor.
- The shared fallback itself, typed or reached through Browse…, is a clear
  (stored `{}`), never a key: a key naming it would read as unshared and
  silence the `sharedrundir` and `filewhy` refusals. Browse… starts at the
  entry's directory or HOME.
- OK is never disabled: a run in flight is said in the dialog at open and
  re-asked at every press, so the same OK works once the run ends. An OK on the
  directory already stored, however spelled, writes nothing and says nothing.
- The validator creates nothing. Note that OK's pane refresh
  (`ase::ui::results_refill`, the same call `load_state_commit` makes) reaches
  `ase::rundir`, which creates the chosen directory then, as any open would.

## Fences

`tests/headless/test_ase_rundir_1665.tcl` (both T1 lists), plus R9 of
`test_ase_persist` (the key on disk) and RF2 of `test_ase_campaign_1462` (the
new remedy text).
