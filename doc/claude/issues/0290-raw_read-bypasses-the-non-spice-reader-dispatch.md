# 0290 — `xschem raw_read <file> table` feeds a table file to the spice parser and drops the database

Status: **FIXED** 2026-08-09 — and fixed for *every* reader, not just `table`: the two dispatch
sites were collapsed into one table-driven function, so the class of bug (a duplicated `else if`
chain that drifts) is gone rather than patched one format at a time.
Area: `src/save.c` `read_rawfile_by_type()` / `raw_type_is_non_spice()` / `extra_rawfile()`;
`src/scheduler.c` the `raw_read` arm (`xschem_cmds_r`) and the top-level `table_read` / `vcd_read`
verbs (`xschem_cmds_t` / `xschem_cmds_v`).
Tests: `tests/headless/test_raw_read_dispatch.tcl` (51 checks, true headless — in `full_audit.sh`'s
`nogui_tests`). `tests/headless/test_vcd_read.tcl` CX17/CX18 pin the `vcd` half from §C;
`tests/headless/test_vcd_time_base.tcl` S19 pins the misroute-must-fail direction.
Found: 2026-08-08, auditing the reader-dispatch seam while adding `vcd_read()` for §C.
Related: `doc/claude/specs/mixed_signal_signal_browser.md` §C (C5/C6).
Numbered 0290 to leave a gap above the local maximum 0285 (`github/open_pdk` is at 0263).

> **Line numbers.** The citations below were refreshed against the fixed tree. The original
> report's numbers predated commits `299a9bc2` and `51fc30a4`; in particular its
> "`scheduler.c:2183, 9751, 9764`" list of NULL-unsafe `sim_type` sites named 9751, which is not
> one — the real pair is the `raw switch` and `raw switch_back` `update_op()` gates. The count of
> seven was right, the addresses were not. Locate these by symbol, not by line.

## The shape of it

`extra_rawfile()` picks its reader from the requested **type** string — the type is the dispatch
key, not just a label:

```c
/* src/save.c, extra_rawfile(), BEFORE */
if(what == 1 && ... && (type && (!strcmp(type, "table") || !strcmp(type, "vcd")))) {
  read_ret = !strcmp(type, "vcd") ? vcd_read(f) : table_read(f);   /* non-spice producers */
} else if(what == 1 && ...) {
  read_ret = raw_read(f, &xctx->raw, type, no_warning, sweep1, sweep2);   /* the spice parser */
}
```

`xschem raw_read` **did not go through `extra_rawfile()`**. It called the readers directly, so it
had to repeat that dispatch — and the repeat had drifted, because §C only taught it about `vcd`:

```c
/* src/scheduler.c, the raw_read arm, BEFORE */
extra_rawfile(3, NULL, NULL, -1.0, -1.0);          /* <- CLEARS EVERY LOADED DATABASE FIRST */
...
if(argc > 3 && !strcmp(argv[3], "vcd")) res = vcd_read(f);     /* added by §C */
else if(argc > 3) res = raw_read(f, &xctx->raw, argv[3], 0, sweep1, sweep2);
```

With `argv[3] == "table"` the file went to `read_dataset()`, which looks for `Plotname:` /
`No. Variables:` / `Values:` headers, found none in a tabular file, and returned 0. No crash, no
error dialog — but the `extra_rawfile(3, ...)` at the top of the arm had **already cleared the
whole registry**, so the outcome was: the table database is gone and nothing replaced it.

## Why it was reachable, not theoretical

Two shipped Tcl paths carry the current database into a new window by round-tripping its own
`sim_type` back through this command:

```tcl
# src/xschem.tcl:5705, in open_sub_schematic (proc at :5660)
if {$sim_type eq {op}} { xschem annotate_op $rawfile } else { xschem raw_read $rawfile $sim_type }

# src/xschem.tcl:5958, in hi_descend_newwin (proc at :5918) — the same line
```

(A third caller, `load_raw` at `src/xschem.tcl:14317`, passes a user-picked type from the
File>Load-raw menu.)

`sim_type` is `"table"` for any database loaded with `xschem raw table_read`. So: load a table,
descend into a sub-schematic in a new window, and the data was silently gone. That round trip is
group E of the new test, and it is the only thing that reproduces the bug as a user meets it — the
`vcd` half of §C had a direct-call check (CX17/CX18) and the `table` half would have needed the
same, but neither proves the Tcl carry-over.

## The fix

Not a third parallel `else if`. The dispatch now exists **once**, driven by a table, in
`src/save.c` just above `extra_rawfile()`:

```c
static struct raw_reader_entry {
  const char *type;
  int (*read)(const char *f);   /* builds xctx->raw; 1 on success */
} raw_reader_table[] = {
  {"table", table_read},
  {"vcd",   vcd_read}
};

int raw_type_is_non_spice(const char *type);   /* which registry protocol applies */
int read_rawfile_by_type(const char *f, Raw **rawptr, const char *type,
                         int no_warning, double sweep1, double sweep2);
```

`read_rawfile_by_type()` walks the table, and anything that matches no row falls through to
`raw_read()` — the spice parser stays the default, an unknown token is never mistaken for a
format. Every `(file, type) -> database` path now goes through it:

| call site | was |
| --- | --- |
| `save.c` `extra_rawfile()` non-spice arm | the `?:` above + a hand-written `sim_type` stamp |
| `save.c` `extra_rawfile()` spice arm | a bare `raw_read()` |
| `scheduler.c` `raw_read` arm (~:10002) | the drifted chain — **this issue** |
| `scheduler.c` top-level `table_read` verb (~:12500) | `table_read()` + a stamp hung off `sch_waves_loaded()` |
| `scheduler.c` top-level `vcd_read` verb (~:13039) | `vcd_read()` + the same conditional stamp |

`extra_rawfile()`'s guard — which decides whether a database dedups on filename alone (non-spice)
or on filename+sim_type (spice) — now asks `raw_type_is_non_spice()`, the same table. The guard
and the reader can no longer disagree about a type, which is what "adding a reader" used to have
to remember in two places.

Three behaviours came along with the consolidation:

1. **The `sim_type` stamp is unconditional on read success.** `table_read()` does not stamp
   `sim_type` (unlike `vcd_read()`, which does — see the rationale in `src/vcd_read.c`), so the
   dispatch stamps it for every non-spice reader. This is not cosmetic. Seven sites `strcmp` it
   with no NULL guard — `src/scheduler.c:2183` (`annotate_op`), `:9764` (`raw switch`), `:9777`
   (`raw switch_back`); `src/callback.c:785`; `src/draw.c:3543, 4860, 8318` — and
   `src/scheduler.c:9906` hands the bare pointer to `Tcl_SetResult()`. Both lookup loops in
   `extra_rawfile()` skip an entry whose `sim_type` is NULL, so such a database is **unreachable
   by `xschem raw switch` forever**. Sabotage S2 (stamp removed) does not merely fail checks: the
   end-to-end group segfaults (`FATAL: signal 11`) on the `Tcl_SetResult(NULL)`.
2. **The top-level verbs no longer hang that stamp on `sch_waves_loaded()`**, which additionally
   requires `raw->schname` to match a schematic in the *current* hierarchy and `raw->values` to be
   non-NULL. A data-less table (comments only) makes `table_read()` return 1 with `values == NULL`,
   so `sch_waves_loaded()` is -1 and the old code skipped the stamp — a NULL-`sim_type` database in
   the registry. Checks R9/R10; sabotage S6.
3. **An empty type string means "unspecified"**, as `extra_rawfile()` has always documented. The
   `raw_read` arm used to pass `""` down to `read_dataset()`, where it matched no analysis and read
   nothing — reachable because `open_sub_schematic` passes `[xschem raw_query sim_type]` through
   verbatim. Checks D18/D19; sabotage S5.

## Not the same as a missing type

`xschem raw_read <file>` with no type is fine — `raw_read(…, NULL, …)` means "take the first
analysis found in the file". The defect was specifically that a **known non-spice type token** was
passed through to the spice parser. The complementary direction is also pinned: a table declared
`tran` must FAIL rather than be rescued by sniffing the file's content (D20, sabotage S8), which is
the same expectation `test_vcd_time_base.tcl` S19 holds for a VCD declared `tran`. That test's
expectation is unchanged by this fix — `tran` is not a row in the dispatch table, so it routes to
the spice parser exactly as it did before.
