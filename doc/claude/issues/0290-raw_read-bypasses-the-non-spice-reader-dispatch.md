# 0290 — `xschem raw_read <file> table` feeds a table file to the spice parser and drops the database

Status: **OPEN** for `table`. The identical hole for `vcd` is CLOSED (§C of
`doc/claude/specs/mixed_signal_signal_browser.md`); this issue is the twin that was already there.
Area: `src/scheduler.c`, the `raw_read` arm (`xschem_cmds_r`); `src/save.c` `extra_rawfile()`.
Tests: `tests/headless/test_vcd_read.tcl` CX17/CX18 pin the `vcd` half. Nothing covers `table`.
Found: 2026-08-08, auditing the reader-dispatch seam while adding `vcd_read()` for §C.
Related: `doc/claude/specs/mixed_signal_signal_browser.md` §C (C5/C6).
Numbered 0290 to leave a gap above the local maximum 0285 (`github/open_pdk` is at 0263).

## The shape of it

`extra_rawfile()` picks its reader from the requested **type** string — the type is the dispatch
key, not just a label:

```c
/* src/save.c, extra_rawfile() */
if(what == 1 && ... && (type && (!strcmp(type, "table") || !strcmp(type, "vcd")))) {
  read_ret = !strcmp(type, "vcd") ? vcd_read(f) : table_read(f);   /* non-spice producers */
} else if(what == 1 && ...) {
  read_ret = raw_read(f, &xctx->raw, type, no_warning, sweep1, sweep2);   /* the spice parser */
}
```

`xschem raw_read` **does not go through `extra_rawfile()`**. It calls `raw_read()` directly, so it
has to repeat that dispatch or a non-spice file reaches `read_dataset()`:

```c
/* src/scheduler.c, the raw_read arm */
extra_rawfile(3, NULL, NULL, -1.0, -1.0);          /* <- CLEARS EVERY LOADED DATABASE FIRST */
...
if(argc > 3 && !strcmp(argv[3], "vcd")) res = vcd_read(f);     /* added by §C */
else if(argc > 3) res = raw_read(f, &xctx->raw, argv[3], 0, sweep1, sweep2);
```

With `argv[3] == "table"` the file goes to `read_dataset()`, which looks for `Plotname:` /
`No. Variables:` / `Values:` headers, finds none in a tabular file, and returns 0. No crash, no
error dialog — but the `extra_rawfile(3, ...)` at the top of the arm has **already cleared the
whole registry**, so the outcome is: the table database is gone and nothing replaced it.

## Why it is reachable, not theoretical

Two shipped Tcl paths carry the current database into a new window by round-tripping its own
`sim_type` back through this command:

```tcl
# src/xschem.tcl:5689-5706, open_sub_schematic
set rawfile  [xschem raw_query rawfile]
set sim_type [xschem raw_query sim_type]
...
if {$sim_type eq {op}} { xschem annotate_op $rawfile } else { xschem raw_read $rawfile $sim_type }

# src/xschem.tcl:5938-5958, hi_descend's new-window arm — the same one-lined
```

`sim_type` is `"table"` for any database loaded with `xschem raw table_read` (stamped at
`src/save.c` in the table arm, and at `src/scheduler.c` in the top-level `table_read` verb). So:
load a table, descend into a sub-schematic in a new window, and the data is silently gone.

This is exactly the bug §C had to avoid for VCD, which is how it was found — the `vcd` arm above
is the fix for the same defect one file format over.

## Fix

Route by type in the `raw_read` arm the way `extra_rawfile()` does, rather than assuming
everything that is not `vcd` is a spice raw:

```c
if(argc > 3 && !strcmp(argv[3], "vcd"))        res = vcd_read(f);
else if(argc > 3 && !strcmp(argv[3], "table")) res = table_read(f);
else if(argc > 3) res = raw_read(f, &xctx->raw, argv[3], 0, sweep1, sweep2);
else res = raw_read(f, &xctx->raw, NULL, 0, -1.0, -1.0);
```

`table_read()` does not stamp `sim_type` itself (unlike `vcd_read()`, which does — see the
rationale in `src/vcd_read.c`), so the `table` arm must also `my_strdup(&xctx->raw->sim_type,
"table")` on success or the database enters the registry with a NULL `sim_type`. That matters:
seven sites `strcmp` `xctx->raw->sim_type` with no NULL guard (`scheduler.c:2183, 9751, 9764`;
`callback.c:785`; `draw.c:3543, 4860, 8318`), and `scheduler.c` hands the bare pointer to
`Tcl_SetResult`. The dedup/lookup loops in `extra_rawfile()` also skip any entry whose `sim_type`
is NULL, so such a database becomes invisible to `raw switch` forever.

Deliberately **not** fixed under §C: that section's scope is the VCD reader, and widening it to a
second file format's pre-existing bug is the user's call, not a silent expansion.

## Not the same as a missing type

`xschem raw_read <file>` with no type is fine — `raw_read(…, NULL, …)` means "take the first
analysis found in the file" and only ever sees real spice raws in practice. The defect is
specifically that a **known non-spice type token** is passed through to the spice parser.
