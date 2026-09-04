# 1286 — `ase::sim_write_conf` carries both of issue 1276's holes

**Status: MEASURED (structurally), FILED, NOT FIXED.** Filed by item **B2a**,
2026-09-03. It is the writer `op_param_lists::write_conf` was **copied from**,
so fixing the copy and leaving the original is exactly the drift this tree keeps
paying for.

## The claim

`ase::sim_write_conf` (`src/ase.tcl:1999-2034`) uses the same
write-beside-and-move idiom (issue 0937) and guards the same one thing —
that the **temp** is openable — and nothing about the **target**:

* **No directory guard.** `file rename -force <tmp> <path>` with `<path>` an
  existing directory does **not** fail; Tcl moves the temp *into* it. The writer
  returns success, the user's Save line names a path it did not write, and the
  settings sit at `<dir>/<basename>.new`, a name no reader looks at. Measured on
  `write_conf` as it stands at `825cd3bd` (B2a measured a fix for the sibling and was reverted): `rc=1 reports=0 path_is_dir=1
  inside={dirtarget.new}`.
* **No symlink resolution.** The rename replaces the **link** with a regular
  file and leaves the real target at size 0. Measured on `write_conf` before the
  fix: `rc=1 link_is_still_link=0 real_size=0 link_size=706`.

## Why it is filed and not fixed here

`src/ase.tcl` is another item's file; item B2a owns
`src/op_param_lists.tcl`, `src/rdw.tcl` and their two suites. Fixing it needs
its own suite rows, and `ase::sim_write_conf`'s callers and file shape are not
this item's to measure.

## The fix, already written next door

`op_param_lists::_resolve_target` + `_target_why` in
`src/op_param_lists.tcl` are exactly the two procs this needs, and their comment
block carries the four measurements the guard order depends on — including the
one that **refutes issue 1276's own recommended one-liner** (`file normalize
[file link $path]` resolves a relative target against the **cwd**, not the
link's directory). Copy the shape; do not re-derive it.

## Acceptance rows this will need

Mirrors of `W6`, `W7` and `W7b` in
`tests/headless/test_op_param_store_1245.tcl`: a directory target refused with
nothing created inside it, a **relative** symlink written through from a
different cwd, and a chain plus a dangling link.
