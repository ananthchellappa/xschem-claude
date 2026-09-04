# 1313 — the settings file is WRITTEN by the window and READ by nobody: `op_param_lists::load` has no caller

**Filed by item B5 (2026-09-04), which is the first thing that writes one.**
Status: **FILED, NOT FIXED.**

## What is missing

`op_param_lists::load` (`src/op_param_lists.tcl:844`) reads the user-global tier
then the project tier, project winning per key, stamping nothing so that a later
Save rewrites only what this session changed (ruling **DD-7**). It works, it is
tested, and **nothing in `src/` calls it**:

```
$ grep -rn 'op_param_lists::load' src/*.tcl        # outside op_param_lists.tcl itself
(nothing)
```

So as of item B5 a user can press **Save**, get a correct
`<project>/.xschem/op_param_lists.conf` naming the exact path in the status
line — and restarting xschem reads none of it. The feature's own acceptance
sentence, *"reorder persists through Save and reload"*, is true **inside one
process** (write_conf → reset → load_conf, which is what rows **BE1** of
`tests/headless/test_op_param_store_1245.tcl` and **S1b** of the same file
prove) and **not** across a restart.

## Why item B5 did not wire it

It is a startup-ordering change, not a button change, and its blast radius is
every session rather than this window:

* `src/op_param_lists.tcl` is sourced from `src/xschem.tcl:16756`, **before** any
  PDK `_procs.tcl` runs, and `op_annot::register` has **replace** semantics. A
  `load` there is harmless (it only fills the store), but the `apply` that has to
  follow it would write into an **empty registry** and be discarded by the PDK's
  own registration a moment later.
* So the pair has to be *load early, apply after the PDK has registered*, and
  this tree has no "after the rc chain" hook that a shipped helper may use. The
  candidates all touch files item B5 may not (`src/xschem.tcl`'s source block, or
  a new hook), and getting it wrong is silent: the sheet simply draws the PDK's
  list and nobody is told the file was ignored.
* Item B5's Files cell is `src/rdw.tcl` plus suite rows.

## Options

* **(a)** call `op_param_lists::load` at source time and `op_param_lists::apply`
  from the first `op_annot::text`/annotate path, once per session, guarded by a
  flag. Cheapest; the guard is the whole risk.
* **(b)** an explicit rc-level call the PDK files end with — honest, and it makes
  every PDK author responsible for a line they did not ask for.
* **(c)** a "Reload parameter lists" menu item beside the window's Save, so the
  round trip is explicit and the ordering problem disappears. Also gives the user
  the verb they will want after hand-editing the file.

**Recommended: (c) first** — it is small, it is inside this feature's own
surface, and it makes the file useful today; then **(a)** for the automatic case,
once someone owns the ordering.

⚠ Note that **(a)** interacts with issue **1292** (nothing ever removes `shown`)
and **1312** (`apply` overwrites the field `seed` reads back): an automatic
startup apply makes both of those fire on every launch rather than only after a
button press.
