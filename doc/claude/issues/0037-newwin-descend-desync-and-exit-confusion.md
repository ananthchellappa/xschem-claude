# Issue 0037 — new-window descend desync (read-only never applied) and multi-window exit confusion

**Opened:** 2026-06-26
**Status:** PARTIALLY FIXED (2026-06-26). Fixed: desync (§2), **blank new window** on WSLg
(§5, proactive fit backstop), and **stale on-disk parent / lost unsaved edits** in the
new-window descend (§6, `~`-backup bridge). The original-window `*` + exit confusion (§3)
remains unreproduced (reporter confirmed the spurious `*` no longer occurs via File ▸ Open
or the Library Manager, so §3's user-visible trigger is gone for now).
**Affects:** `hi_descend_newwin` (`src/xschem.tcl`), `schematic_in_new_window`
(`src/actions.c`), the multi-window quit/teardown path, the `callback()` disk-mtime
`set_modify(1)` check (`src/callback.c`). Repro env: `src/xschem --script
src/cadence_style_rc` (sets `descend_readonly 1`), open via Library Manager
`xschem_libraries_oa/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch`,
whose only instance `x1 = SANDBOX/solar_ctl`.
**Branch:** `fluid-editing`. See [[hi-descend]], issues 0035, 0036.

---

## 1. Symptoms reported

1. Select `x1`, open it in a new window → the new window **immediately shows the
   modified `*`** and the **title shows the PARENT cell** (`test_hier_descend_etc`)
   instead of `solar_ctl`.
2. (CTRL-X descend in the original window logs nothing in the CIW.)
3. On CTRL-Q: "Schematic test_hier_descend_etc.sch has unsaved changes. Save before
   quitting?" → No. Then BOTH windows pop "UNSAVED data: want to exit?" (the solar_ctl
   window's prompt names `test_hier_descend_etc.sch` — wrong cell). Clicking OK twice
   leaves the first window blank (title still `test_hier_descend_etc`), then it becomes
   the WSLg "empty shell immune to xkill" (issue 0002).

## 2. FIXED — the new-window desync (symptom 1's wrong title, and its `*`)

`hi_descend_newwin` called `schematic_in_new_window` with the target instance still
selected. That function's `lastsel==1` branch opens the **instance's** schematic
(`solar_ctl`) as a fresh top level, NOT the parent; `copy_hierarchy` then overwrites it
with the parent, and the following `select x1; descend` finds no `x1` in `solar_ctl`, so
the descend no-ops. The window is left desynced: `schname`=parent, `currsch`=0
(hierarchy lost), and — because the `if {$ok}` block is skipped — **read-only is never
applied** (`ro`=0). An editable window with a stale `time_last_modify` then trips the
`callback()` mtime check → spurious `*`.

Fix (commit `da142c75`): unselect before `schematic_in_new_window` (as
`open_sub_schematic` does), so it opens the parent and the descend is real. Verified on
the fixture: selected-`x1` new window → `sch=solar_ctl currsch=1 sch_path=.x1. ro=1`
(was `sch=parent currsch=0 ro=0`). Read-only now applied, so the mtime-check `set_modify`
is suppressed (issue 0035) and the `*` should be gone. Headless `SELNW` regression added.

## 3. NOT YET REPRODUCED — original-window `*` + exit confusion/crash

The CTRL-Q prompt names the **editable parent** (first window) as modified, which the
new-window fix does not touch. In a scripted repro of the full flow (source
`cadence_style_rc`, load the fixture, descend `x1`→`x3`, ascend) `modified` stays 0 at
every level — so the parent `*` is NOT from the descend path. The one path not
replicated headlessly is the **Library Manager open** (which has git integration,
`doc/claude/specs/library_git.md`). Hypothesis: the open (or git) leaves the parent file's on-disk
mtime != the loaded `time_last_modify`, so a later event's mtime check sets `modified`
on the editable parent — and the multi-window quit then walks windows with a confused
per-window `schname`, double-prompts, and tears down abnormally → WSLg ghost (0002).

To narrow it, need from the reporter:
- Does the spurious `*` on the original window happen when the file is opened via
  **File ▸ Open** instead of the Library Manager?
- Is `SANDBOX/...` under git / freshly written this session (so its mtime is "newer
  than load")?
- Which exact action opened the new window (hi_descend dialog → New window, vs
  Ctrl-Shift-N `cadence::open_inst_sch_readonly`)?

## 4. Candidate follow-up fixes (pending repro)

- The mtime check setting `modified` conflates "file changed on disk" with "you have
  unsaved edits"; the correct response to an external change is the RELOAD prompt
  (`scheduler.c:718`), not a save prompt. Consider not calling `set_modify(1)` from the
  mtime check at all (let reload handle it).
- Harden the multi-window quit to use each window's OWN `schname`/modified state and not
  double-prompt, so a confused/modified window cannot wedge teardown into the WSLg ghost.

## 5. FIXED — blank new window after a new-window descend (the §2 fix exposed it)

Once §2 made the new-window descend a *real* descend, the reporter hit a new symptom: the
new window opens with the correct title (`solar_ctl.sch (read only)`) but is **completely
blank — not even the grid** (or, descending one level deeper, shows the *grid but no
schematic elements*); pressing **F (zoom full)** makes it display normally. A second
descend-new-window on the same instance is blank too. Descending in the **same** window is
fine.

**Root cause — a geometry race, not a draw failure.** `descend_schematic()` ends with
`zoom_full(1, …)`, which derives the viewport from `xctx->xrect[0].width/height` (the
window's real canvas size, set by `resetwin()`). For a new top-level **window** the descend
runs inside the synchronous Tcl proc *before* the window has processed its queued
`Map`/`Configure`/`Expose` events, so the canvas is still at a transient size. `zoom_full`
computes the view for that transient geometry; when the WM then settles the window to its
real size, the `ConfigureNotify` → `resetwin()` updates the pixmap/`areaw` but does **not**
re-zoom (`pending_fullzoom==0`), leaving a stale viewport — blank / grid-only / off-screen
until a manual `F`. A *same-window* descend is fine because that window's geometry is
already settled; a *new tab* is fine because it shares the already-sized main canvas.
Deterministically reproduced: descend → window resized 1067→760 → zoom stayed `0.7713`
(computed for 1067) instead of refitting to `1.0829`.

**Key finding (reporter follow-up): WSLg never sends the settling Configure on open.** The
first fix attempt only *armed* `pending_fullzoom` so the settling `ConfigureNotify` would
re-zoom. The reporter confirmed it did **not** auto-fix — the window stayed blank until they
**manually resized** it. That nails the WM behaviour: WSLg drops the new window's initial
`Map`/`Configure`/`Expose` (the same reason `create_new_window` already has a "paint now"
Expose workaround), so the arm rides a Configure that never arrives; only a *user* resize
generates one. So the fix must fit the window **proactively**, not wait for a Configure.

**Fix.** Helper `newwin_defer_fullzoom` (`src/xschem.tcl`), called by `hi_descend_newwin`
(dest=window) and `open_sub_schematic` (window mode, not tab), is two-pronged:
1. **Fast path** — `xschem set pending_fullzoom 1`: on a normal X server the settling
   `ConfigureNotify` re-zooms immediately via `resetwin()`'s deferred-zoom block.
2. **WSLg backstop** — `after 120 _newwin_fit_fullzoom`: once the window is realized
   (`winfo ismapped` + size > 1, retried up to ~3 s), force the same work a manual resize
   does via the new `xschem resetwin W H` command — re-read geometry and perform the armed
   `zoom_full`. It passes Tk's known canvas size (`winfo width/height`) straight through,
   bypassing `XGetWindowAttributes`, which on WSLg still reports a transient 1×1 for a
   just-mapped window. It self-terminates: a no-op if a real Configure already fit it
   (pending cleared) or the user moved on, so it never fights the WM or overrides a later
   user zoom, and it doubles as the dangling-`pending_fullzoom` clear (a stuck arm would
   block hover window-switching, `callback.c:5878`).

New subcommands (`src/scheduler.c`): `set/get pending_fullzoom`, and `resetwin [w h]`
(re-read geometry → recreate pixmap → draw, performing an armed deferred zoom; explicit w/h
bypasses the flaky X query). All guarded to no-op without X. Verified deterministically: the
backstop recovers a forced degenerate viewport without any resize (`zoom 20.6 → 0.7713`,
pending → 0); a settling Configure refits (`0.7713 → 1.0829`); a second user resize does
**not** re-fullzoom; tabs are not armed; the auto-scheduled `after` chain fires on its own;
headless `test_hi_descend` SELNW and the core regression suite stay green. (The exact WSLg
blank can't be reproduced in batch — no WM maps the window — so the backstop is verified
against the *consequence*: it re-fits to the real Tk size regardless of any Configure.)

## 6. FIXED — new-window descend showed the STALE on-disk parent, losing unsaved edits

Reporter's second symptom: in the parent window, **add an instance** (e.g.
`ngspice/comp_ngspice`) without saving, select it, then E → New window → OK. The new window
came up titled with the **parent** cell and showing the **old** parent *without* the new
instance — "not even the proper schematic".

**Root cause.** `schematic_in_new_window` opens the parent by **reloading its file from
disk** (`create_new_window` → `load_schematic(xctx->sch[currsch])`), so the source window's
**unsaved** edits are absent from the new window. The freshly-added instance therefore does
not exist there, so `xschem select instance … ; xschem descend` finds nothing and no-ops,
leaving the new window stranded on the stale disk parent (`currsch=0`, parent title).
Reproduced headlessly: add `xcn1`, new-window-descend into it → new window `schname=test.sch
currsch=0` with only `{x1}` (vs. expected `comp_ngspice.sch currsch=1`).

**Fix.** Bridge the unsaved edits through the cell's existing `~` autosave backup. Two
helpers in `src/xschem.tcl`, wired into **both** `hi_descend_newwin` and
`open_sub_schematic` (applies to new tabs too — `create_new_tab` also reloads from disk):
- `newwin_capture_unsaved` (called while the *source* is the active context, before
  `unselect_all`/open): if `xschem get modified`, `xschem backup write` (persist in-memory
  content to `<cell>~.sch`) and return the cell path; else return `""`.
- `newwin_restore_unsaved` (called right after `new_schematic switch` to the new window):
  `xschem load_backup <cell>` pulls that backup into the new window (same cell → same backup
  file). Best-effort (`catch`): no backup → new window keeps the disk parent, no worse than
  before. Unmodified source → no-op, the plain disk reload (correct).
Verified: unmodified descend into an existing `x1` still reaches `solar_ctl.sch currsch=1`;
unsaved `xcn1` new-window descend now reaches `comp_ngspice.sch currsch=1`. The new window's
parent level is legitimately `modified` afterwards (it really does hold unsaved edits), so a
close/ascend may prompt to save — correct, not spurious. Deep-hierarchy edits at *shallower*
levels are not carried (only the current cell's backup), matching the reported scenario.

**Aside (separate, unfixed):** reporter noted "U for undo not working" after making the
parent read-only (Ctrl-Shift-2). Undo is an edit op, so a read-only buffer blocking it is
consistent with read-only enforcement; left as-is unless we decide read-only undo should be
allowed.
