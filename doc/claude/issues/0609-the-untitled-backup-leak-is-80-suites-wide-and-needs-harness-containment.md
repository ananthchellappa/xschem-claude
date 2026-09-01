# 0609 — the `untitled~.sch` leak is 80 suites wide; per-suite guards cannot close it

STATUS: **OPEN — measured 2026-08-22**, during the 0601 fix. Related: 0601 (the
five suites now guarded), 0353 (the two originally filed), 0356 (the delete half),
0323 (`cd` does not move the buffer name), 0060 (why untitled buffers ARE backed
up on purpose).

---

## The measurement

A sweep of all **116** headless suites that touch an untitled buffer and carry no
guard, each run one at a time in a private cwd via `devdisplay.sh exec` with a
12 s timeout: **80 of them leave `untitled~.sch` in their cwd.** Not five.
`test_find_helper`, `test_label_ride`, `test_fluid_editing`,
`test_backannotate_digital`, every `test_perform_action_*`, and so on.

`tests/headless/full_audit.sh:64` does `cd "$REPO"`, so a full audit still ends
with one `untitled~.sch` in the repository root no matter how many individual
suites are guarded.

Good news in the same sweep: the leftover is **only ever** `untitled~.sch`. No
suite creates a numbered `untitled-N.sch` any more — the numbered producer
(`test_placement_wire_gate`) was fixed in `316aafdd`.

## Why the per-suite guard does not generalise

`set ::autosave_backup 0` is correct for a suite that neither descends nor
recovers. It is **wrong** for the suites that assert the backup IS written:
`tests/headless/test_backup_file.tcl:70` and
`tests/headless/test_descend_untitled_preserve.tcl:53`. Blanket-applying the
guard would silently gut those.

## The mechanism, for whoever takes this

* `src/actions.c:208` — `set_modify(1)` calls `write_backup()` on the **first**
  edit of any buffer, untitled included.
* `src/save.c:4149-4171` — `write_backup()`; the create is `fopen(bak, "w")` at
  `:4164`. It deliberately does not skip untitled buffers (`:4159-4162`, issue
  0060).
* `src/save.c:4156` — it returns early when `autosave_backup` is off. That is the
  hook the per-suite guard uses.
* The path is composed from `pwd_dir`, which is `$env(PWD)` when set
  (`src/xinit.c:3690-3693`) and otherwise the **startup** `getcwd`
  (`src/xinit.c:2952`). A Tcl `cd` moves neither (`src/xinit.c:174`, issue 0323).

## The fix direction

Containment belongs in the **harness**, not in 80 suites: give each test its own
cwd in `tests/headless/full_audit.sh` and `tests/run_regression.tcl`.

**It must set `$env(PWD)`, not merely `cd`** — that is the load-bearing detail,
and it was measured the hard way while building `test_no_untitled_litter.tcl`: a
child `xschem` exec'd after a Tcl `cd` inherits the parent's `::env(PWD)` and
prefers it over `getcwd`, so the children named their buffers in the *parent's*
directory. The first guardian run read its own positive control as "no litter"
while the file had in fact gone to the repo root.

## What is already covered

`tests/headless/test_no_untitled_litter.tcl` owns the six guarded suites and
fails if any of them loses its guard. It does **not** cover the other 80 — by
design, since the guard is not the right fix for all of them.
