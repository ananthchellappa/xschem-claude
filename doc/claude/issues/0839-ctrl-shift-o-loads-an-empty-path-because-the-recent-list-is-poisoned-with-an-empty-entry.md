# 0839 — `Ctrl+Shift+O` intermittently loads nothing: the recent-files list is poisoned with an EMPTY entry, and it poisons itself

Status: **OPEN — measured 2026-08-26, reported by the user.** Two defects, one
self-perpetuating loop. Related: 0022 (brace-safe load), 0119 (`update_recent_files`
gating).

## The user's report, verbatim

> Ctrl-Shift-O to load sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch
>
> … Now, I quit and relaunch (/tmp/Xschem.log.3) and I find that Ctrl-Shift-O
> does not load sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch. I have to
> manually go through library manager.
>
> I quit and relaunch and, (/tmp/Xschem.log.4) Ctrl-Shift-O gets me
> sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch.

## Measured

`Ctrl+Shift+O` is `case 'O'` + `ControlMask` at `src/callback.c:8027-8034`,
*"load most recent tile"*, issuing `xschem load -gui -lastopened`.

`/tmp/Xschem.log.3`, the failing session, verbatim:

```
xschem library_manager
xschem load {}
xschem load {}
xschem load {}
xschem load {}
xschem load {}
xschem zoom_full
```

**Five loads with an empty path.** `~/.xschem/recent_files` says why:

```tcl
set tctx::recentfile {/home/analog/dev/xschem-claude/sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch {}}
```

The list has **two** elements and the second is the **empty string**.

## Defect 1 — `get_lastopened` breaks on the empty entry

`src/xschem.tcl:13897-13905`:

```tcl
proc get_lastopened {} {
  set f {}
  foreach f $tctx::recentfile {
    if {[xschem check_loaded $f] eq {}} {
      break
    }
  }
  return $f
}
```

The loop skips entries that are already loaded and stops at the first that is
not. `check_loaded {}` reports *not loaded*, so **the empty entry always
satisfies the break** — and it is reached whenever the real first entry is
already open. That is exactly the intermittency the user saw:

| state at keypress | element 1 (`tb_bandgap.sch`) | result |
|---|---|---|
| tb_bandgap NOT open | not loaded → **break** | loads it ✓ (logs .9, .4) |
| tb_bandgap already open | loaded → skip → element 2 `{}` → **break** | `xschem load {}` ✗ (log .3) |

**A second wrong answer hides in the same proc.** `foreach` leaves `f` holding
the LAST element after a loop that never breaks, so with a fully-loaded list
`get_lastopened` returns a file that IS loaded rather than returning nothing.
`set f {}` on line 1 looks like it guards this and does not — `foreach`
overwrites it.

## Defect 2 — the empty path is written straight back into the list

`src/scheduler.c:7715` (and `:7703`, `:7830`, `:7854`):

```c
if(undo_reset) {
  tcl_call("update_recent_file", f, NULL, NULL);
}
```

with **no `f[0]` guard**, and `update_recent_file` (`src/xschem.tcl:2535`) has no
guard of its own — it `lappend`s whatever it is given and calls
`write_recent_file`, which persists it.

So one empty load writes `{}` into `~/.xschem/recent_files`, where it survives
every relaunch and breaks `Ctrl+Shift+O` again. **The bug installs itself.**
That is why the user could not clear it by restarting.

Note the surrounding code *does* guard: `:7654` and `:7666` both test `f[0]`
before the open-probe and the already-open check. Only the recent-list write is
unguarded, so an empty load is quietly skipped by every check except the one that
makes it permanent.

## Fix — three guards, none of them clever

1. **`update_recent_file`**: return immediately when `$f` is empty. This is the
   one that stops the poisoning, and it is the one that matters — the other two
   only stop the symptom.
2. **`get_lastopened`**: skip empty elements, and return `{}` explicitly when the
   loop finds nothing suitable (do not fall out of `foreach` holding the last
   element).
3. **`xschem load -lastopened` / `-lastclosed`**: when the resolver returns
   empty, **no-op** — do not proceed into the load with an empty `f`.
   `get_lastclosed` has the same shape and the same exposure.

Plus a **one-time repair** of the user's `~/.xschem/recent_files`: the poisoned
`{}` entry is already on disk and guard 1 will not remove it. Guard 2 makes it
inert; a startup filter that drops empty elements when the file is sourced makes
it disappear.

## Acceptance

1. `get_lastopened` with `tctx::recentfile = {/a/b.sch {}}` and `/a/b.sch`
   already loaded returns `{}`, not `{}`-as-a-path — and the caller loads nothing.
2. `update_recent_file {}` leaves `tctx::recentfile` unchanged and does not
   rewrite the conf file.
3. `get_lastopened` with every element loaded returns `{}`, not the last element.
4. Ctrl+Shift+O with tb_bandgap already open is a no-op (or reopens the next
   distinct recent file), never `xschem load {}`.
5. A session that hits case 4 does not add an entry to the recent list.

## Still open

* **What SHOULD Ctrl+Shift+O do when the most recent file is already open?**
  Silently nothing is defensible but poor; raising the existing window, or
  falling through to the next distinct recent entry, are both better. Unratified
  user-visible behaviour — `rule` debt.
* **`get_lastclosed` (`xschem.tcl:13872`) is not audited here.** It reads a
  different file (`$USER_CONF_DIR/geometry`) and has an explicit `if {$ret ne {}}`
  guard, so it does not have defect 1 — but it shares the caller and therefore
  fix 3.
