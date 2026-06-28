# Adopting the file-open enhancement — baby steps

You were pointed at the branch `feature/file-open-dialog`. This guide walks
you through taking **only** the file-open enhancement out of it, in small
verifiable steps. Total adoption effort: roughly an hour, most of it reading.

**What the enhancement is** (full design rationale: `doc/claude/code_analysis/file_open_ux.md`,
sections 3, 5 and 6):

- The `File:` entry of the classic open dialog (`load_file_dialog`, the
  `.load` toplevel) becomes a real path field: Tab-reachable, focused on
  open, and **Enter** opens the typed/pasted path. Directories navigate the
  dialog into them instead of being silently refused.
- A **Recent** menubutton next to the entry lists recent files (full-path
  labels) and recent directories (new, persisted as `tctx::recentdirs` in
  the existing `recent_files` conf). Stale entries are hidden, not deleted.

Pure Tcl. No C changes, no new files, no new dependencies, Tcl/Tk 8.4
compatible, no rebuild needed.

## Step 1 — identify the relevant commits

Everything else on this branch is an unrelated feature (action logging);
ignore it. The enhancement is exactly these commits:

```sh
git log --oneline --grep='feat(dialog)' feature/file-open-dialog
```

- `451a949c` — *type/paste-a-path + Recent dropdown in the classic open dialog*
- `fffb3641` — *skip stale entries in the Recent drop-down*

plus the commit that adds `tests/file_open_dialog/` and this guide
(subject: *adoption guide + in-repo test suite*), which you want too.

## Step 2 — look at what you'd be taking

```sh
git show --stat 451a949c fffb3641
git show 451a949c -- src/xschem.tcl
```

Both commits touch a single file, `src/xschem.tcl` (+170/−10 across both;
the rest is documentation). Skim the diff once before applying anything.

## Step 3 — take the commits

```sh
git checkout -b file-open-enhancement master   # or your integration branch
git cherry-pick 451a949c fffb3641
git cherry-pick <hash of the tests/guide commit>   # optional but recommended
```

This cherry-pick has been verified to apply onto this repository's `master`
(which is essentially vanilla upstream) with **zero conflicts**, and the full
test suite passes on the result. If your tree has drifted and you do get
conflicts, skip to Step 7 and apply by hand — there are only seven small
hunks.

## Step 4 — try it (no rebuild)

`xschem` sources the local `xschem.tcl` when started from the source tree:

```sh
cd src && ./xschem
```

Manual checklist, two minutes:

1. **File → Open**, paste an absolute `.sch` path, press Enter → loads.
2. Open again, type a directory path, Enter → dialog navigates there,
   entry clears, dialog stays open.
3. Type garbage, Enter → error popup, dialog stays open.
4. Click **Recent** → recent files with full paths, separator, directories
   with a trailing `/`. Pick a directory → navigates. Pick a file → opens.
5. Tab from the Search field → reaches the File entry (previously skipped).
6. **File → Save as** → no Recent button; typing a *new* filename + Enter
   still works (this mode must accept names that don't exist yet).
7. Insert symbol (`Shift-Ins`) → no Recent button; dialog otherwise
   unchanged.

## Step 5 — run the scripted suite

```sh
cd src && timeout -s KILL 120 ./xschem -q --script ../tests/file_open_dialog/wrap.tcl
cat /tmp/qo_test.log
```

Expect **33 PASS, 0 FAIL**, last line `DONE`. Needs an X display. The run
backs up and restores your `$USER_CONF_DIR/recent_files` automatically and
cleans its `/tmp/qo_fixture` files. The suite covers: path resolution
(absolute, `~`, browsed-dir-relative, cwd-relative, library-path-relative),
directory navigation, error handling, Recent menu contents and stale-entry
filtering, conf-file persistence/back-compat, and non-regression of the
save-as and insert-symbol modes.

## Step 6 — decide on the severable pieces

Each of these is an independent few-line hunk; drop any you disagree with
without affecting the rest:

| Piece | Where | To revert |
| --- | --- | --- |
| Initial focus on the File entry in load mode | `focus` block at the end of `load_file_dialog` | restore the unconditional `focus .load.buttons_bot.src` |
| `H`/`U` shortcuts suppressed while typing in an entry | the two `bind .load <KeyPress-H/U>` lines | restore the unguarded bindings (note: typing `H` in the Search box then triggers Home — pre-existing wart) |
| Stale-entry hiding in the Recent menu | all of commit `fffb3641` | just don't cherry-pick it |

## Step 7 — hand-apply map (only if cherry-pick conflicted)

All edits are in `src/xschem.tcl`, anchored here by proc name, in file
order. Diff source of truth: `git show 451a949c fffb3641`.

1. **`load_recent_file`** — add `set tctx::recentdirs {}` *before* the
   `source $USER_CONF_DIR/recent_files` (old conf files without the
   variable must still load).
2. **after `update_recent_file`** — new proc `update_recent_dir {d}`:
   normalize, dedup, most-recent-first, cap 10, `write_recent_file`.
3. **`write_recent_file`** — emit `set tctx::recentdirs {...}` next to the
   `tctx::recentfile` line.
4. **after `load_file_dialog_up`** — four new procs, self-contained:
   `file_dialog_navigate` (must mirror `load_file_dialog_up`:
   `file_dialog_set_home` + `setglob` + `file_dialog_set_colors2` +
   set `file_dialog_dir1` — see invariant 2 below), `file_dialog_entry_enter`,
   `file_dialog_fill_recent_menu`, `file_dialog_recent_pick`.
5. **`load_file_dialog`, widget creation** — remove `-takefocus 0` from
   `.load.buttons_bot.entry`; create the Recent menubutton + menu (gated
   `$loadfile == 1`); add `bind .load.buttons_bot.entry <Return>
   {file_dialog_entry_enter; break}`.
6. **`load_file_dialog`, pack / bindings / focus** — pack
   `.load.buttons_bot.recent` after the entry (same gate); guard the
   `KeyPress-H`/`KeyPress-U` bindings; focus the entry when
   `$loadfile == 1`.
7. **`tctx::global_list`** (bottom of the file) — add `tctx::recentdirs`
   after `tctx::recentfile` (globals not in this list are lost on
   window/tab context switches).

## Invariants — keep these if you rework anything

1. **Accepting a file must go through the OK-button path**
   (`file_dialog_retval` + destroy), never load directly: that is what keeps
   `file_dialog_getresult`'s `is_xschem_file` sniff, the save-as overwrite
   confirm, and all six callers working unchanged.
2. **Navigation must go through `file_dialog_set_home`**, not just
   `set file_dialog_dir1`: the right-pane listbox derives its directory from
   `file_dialog_files1[$file_dialog_index1]` (the left pane), so skipping
   `set_home` desynchronizes the panes.
3. **Mode gating.** `load_file_dialog` has six callers in three modes:

   | `loadfile` | Callers | Recent button | Enter accepts a file | Enter on nonexistent |
   | --- | --- | --- | --- | --- |
   | 1 | Open (`actions.c`), Merge (`paste.c`), Compare (`xinit.c`) | yes | yes | error popup |
   | 0 | Save as (`save_file_dialog`) | no | yes | accepted (new name is the normal case) |
   | 2 | Insert symbol (`actions.c`, `callback.c`) | no | no (never had Enter) | ignored |

   Directory-navigation-on-Enter is the only behavior active in all modes.
4. **The `<Return>` binding on the entry ends in `break`** — without it the
   generic `bind .load <Return>` fires too and double-handles the event.
5. **Filter, don't prune, the Recent lists**: the fill proc skips
   nonexistent paths at post time but never rewrites `tctx::recentfile` /
   `tctx::recentdirs`, so entries on temporarily unmounted filesystems
   come back by themselves. Web URLs can't be stat'ed and are always shown.
