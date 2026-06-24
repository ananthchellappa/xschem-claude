# Issue 0029 — interactive open of a missing/unreadable recent file strands the untitled buffer (cascades to broken reuse + close)

**Opened:** 2026-06-24
**Status:** ✅ RESOLVED 2026-06-24 (branch `fluid-editing`) at the root. `xschem load -gui`
(the interactive open path: File ▸ Open Recent, "Open most recent", file-dialog OK) now
verifies the resolved file is **readable** before loading; if not, it alerts and skips,
leaving the current buffer untouched. Scripted loads (no `-gui`) keep the legacy
create-on-missing behavior; web urls are exempt.
**Affects:** `scheduler()` `xschem load` command (`src/scheduler.c`); trigger via
`setup_recent_menu` (`src/xschem.tcl:1331`, builds `xschem load -gui {$i}` entries with no
existence check). Downstream: `load_schematic()` (`src/save.c:3727/3729`),
`is_pristine_untitled()` (`src/scheduler.c`), `destroy_tab()` (`src/xinit.c`).
**Severity:** medium — a single misclick on a stale recent entry leaves the editor in a
wedged state (blank window, wrong tab title, `Ctrl-W` dead); only `Ctrl-Q` recovers.
**Branch:** `fluid-editing`. Related: [[untitled-reuse]], issues 0021/0022/0023/0025.

---

## 1. Symptom (the cascade the user hit)

1. Open a **non-existent or non-accessible** recent file (Ctrl-Shift-O / File ▸ Open Recent).
   The load fails, but the *pristine `untitled.sch` buffer is renamed to the bad file* (tab
   title shows the missing name; canvas stays empty).
2. Open an existing cell (e.g. `cell_A.sch`) via the Library Manager. It should *replace the
   pristine main `untitled.sch` in place*, but instead opens a **new window**.
3. Go to the main window, press **Ctrl-W** (close): the schematic window vanishes, the tab
   title changes to `cell_A.sch` but the canvas is **blank**, and **Ctrl-W stops responding**.
   `Ctrl-Q` still quits.

## 2. Root cause (one defect, three symptoms)

`load_schematic()` commits the buffer name **before** the file-open check and never reverts
it on failure:

```c
/* src/save.c:3727-3729 — name committed up front */
my_strdup2(_ALLOC_ID_, &xctx->sch[xctx->currsch], ffname);
my_strncpy(xctx->current_name, rel_sym_path(ffname), S(xctx->current_name));
...
/* src/save.c:3756-3774 — open fails, but the name is kept */
if(fd == NULL) { ret = 0; ...; clear_drawing(); if(reset_undo) set_modify(0); }
```

The fail branch (`clear_drawing()` + keep name) is the **intentional "open-or-create"**
behavior — `xschem foo.sch` on a missing path gives a blank buffer named `foo.sch` to save.
That is correct for scripted/command-line create; it is *wrong* for an interactive open of a
file the user expects to already exist.

Everything else is a **consequence** of the stranded name:
- **(B) reuse breaks:** `is_pristine_untitled()` gates the open-in-place reuse on the buffer
  still being named `untitled.sch` (`is_untitled_basename`, issue 0023). Once renamed to the
  bad path it returns 0, so the Library-Manager open falls through to a **new window**.
- **(C) close breaks:** `destroy_tab()` switches `xctx` and re-titles via the now-inconsistent
  name/tab bookkeeping; with the current buffer pointing at a non-existent file the restore
  lands on a blank/wrong context and `Ctrl-W` wedges.

Reproduced headless: `xschem load -gui {/tmp/missing.sch}` changed `schname` from
`untitled.sch` to `/tmp/missing.sch`.

## 3. Fix (root)

Enforce "must be loadable" at the **interactive (`-gui`) chokepoint**, where the intent is
"open an existing file" — not in `load_schematic()` (whose create-on-missing is wanted for
scripted loads). Probe with the *same* `my_fopen()` test the loader uses, so it covers
missing AND unreadable files in every path form; exempt **generators** (`name(args)`, run via
popen — not files) and **web urls**:

```c
/* src/scheduler.c, xschem "load" command, after f = abs_sym_path(f) */
if(!force && f[0] && !is_generator(f) && !is_from_web(f)) {
  FILE *probe = my_fopen(f, fopen_read_mode);
  if(probe) fclose(probe);
  else {
    if(has_x) tclvareval("alert_ {Unable to open file: ", f, "}", NULL);
    else dbg(0, "xschem load -gui: unable to open file: %s\n", f);
    skip = 1;                         /* leave the current buffer intact */
  }
}
```

`-gui` sets `force = 0`; the recent-menu / most-recent / file-dialog opens all carry it. With
the buffer no longer stranded, (B) and (C) no longer trigger from this path.

> **Note (review round, 2026-06-24):** a first cut used `tcleval("file readable {<f>}")`
> gated by `tcl_braceable()`. A high review flagged three real defects: it **rejected
> generator schematics** (not literal files), it **left the bug unfixed for paths containing
> `{`/`}`/`\`** (the braceable gate skipped the check), and a fixed `chk[]` buffer could
> **truncate** a long valid path. The `my_fopen` + `is_generator`/`is_from_web` form above
> replaces it: no Tcl round-trip, no brace gate, no stack buffer, and it matches the loader's
> own open semantics exactly.

**Verified headless:** missing file → buffer stays `untitled.sch` (refused + alert); a
brace-in-name missing file → also refused (the old braceable gate would have corrupted it); a
generator (`gen(1,2,3)`) → passed the guard to the loader (not wrongly refused); a real file
(incl. a `has{brace}.sch` path) → loads; a scripted `xschem load {missing}` (no `-gui`) →
still creates `missing.sch` (legacy create-on-missing preserved).

## 4. Teaching note / smell

Same family as issue 0028: a **dual-purpose function with an intent it can't see**.
`load_schematic()` serves both "open existing" and "create if missing", distinguished only by
the *caller's* intent, which isn't passed down — so the failure policy (keep the name) is right
for one caller and wrong for the other. The robust fix puts the policy at the boundary that
knows the intent (`-gui` = open existing) instead of overloading the shared routine. The
**commit-state-before-validating** ordering (`save.c:3727` rename, then `:3756` open-check) is
the classic "do the irreversible thing before the thing that can fail" smell; the validation
belongs before any mutation.

## 5. Deferred follow-up (defense in depth — NOT yet done)

The root fix removes the reported repro, but the downstream code is still fragile if a buffer
name is corrupted by *any* other means:
- `destroy_tab()` (`src/xinit.c`) restores `prev` (defaulting to 0) without validating the
  context, and re-titles via possibly-stale name/tab bookkeeping — the likely source of the
  blank-canvas + dead-`Ctrl-W` wedge. Worth an explicit guard + a headless tab-close test.
- `load_schematic()` could additionally **revert** `xctx->sch[currsch]`/`current_name` to the
  pre-call value on open failure when invoked interactively, as belt-and-suspenders.
- Recent-menu builders (`setup_recent_menu` no check; `file_dialog_fill_recent_menu` uses
  `file exists`) could pre-filter with `file readable` so stale entries are greyed rather than
  erroring on click.

Accepted as minor (from the review, not worth fixing now): a multi-file interactive load with
several bad files raises one modal `alert_` per bad file (rather than a consolidated notice);
if the *first* file of a multi-file `-gui` batch is unreadable the per-file `first_loaded`
routing differs slightly (the next good file loads into the current buffer instead of a new
tab); and a *broken/non-existent generator* opened via `-gui` is exempt from the probe and so
can still strand the buffer (generators must be exempt since they aren't files — narrow edge).

## 6. Tests

Headless (added to repro, recommended to commit as a regression):
- `xschem load -gui {<missing>}` and `{<mode-000>}` must leave `schname == untitled.sch`.
- `xschem load -gui {<real.sch>}` must load it.
- `xschem load {<missing>}` (no `-gui`) must still create the named buffer.
A GUI smoke test should additionally confirm Ctrl-W still closes cleanly after a refused open.
