# 1634 — the top-level `xschem table_read` TOGGLES: reading one file takes two calls, and the first one silently discards the loaded result

**STAMP:** `v1 claim=open tree=a90ffb98 stamped=2026-10-02 fix=none open=2`

Status: **OPEN**, found 2026-10-02 by the calculator batch's recon stages while establishing how the
Calculator should import an ASCII table. Pre-existing; no Calculator change caused it.

Area: the **`table_read`** arm of `xschem_cmds_t()` — `src/scheduler.c` — i.e. the **top-level**
`xschem table_read <file>`. It is a **different verb** from `xschem raw table_read <file>`, which
lives in `xschem_cmds_r()` and behaves as its name says.
Found: `env -u DISPLAY ./src/xschem --pipe -q --nogui --script …` against a three-line table and
`tests/headless/data/calc_fixture.raw`

## The defect

The arm is an `if`/`else if` on whether anything is loaded, and the read is in the **else**:

```c
if(sch_waves_loaded() >= 0) {
  extra_rawfile(3, NULL, NULL, -1.0, -1.0);   /* clear ALL */
  draw();
} else if(argc > 2) {
  expand_tilde(argv[2], f, (int)S(f));
  extra_rawfile(3, NULL, NULL, -1.0, -1.0);
  read_rawfile_by_type(f, &xctx->raw, "table", 0, -1.0, -1.0);
  …
}
Tcl_ResetResult(interp);
```

So with a result loaded, `xschem table_read <file>` **does not read `<file>`**. It takes the
clear-all arm, destroys every loaded database, and returns. The filename is parsed and discarded.
Only a *second* invocation — now with nothing loaded — reads it.

`extra_rawfile(3, NULL, …)` is clear-**all**, not clear-this-one: it frees every entry, unsets
`ngspice::ngspice_data`, and resets `extra_idx`, `extra_prev_idx`, `extra_raw_n` and the registry
array. The verb also `Tcl_ResetResult`s, so **it answers the empty string in every case** — a
caller cannot tell a read from an unload from a failure.

## Measured

```
read rc=1                                            (fixture loaded)
info0: 0 current | 0 tests/headless/data/calc_fixture.raw tran

--- call 1: xschem table_read <table> ---
free_rawfile(): clearing data
rc=<>
info1:                                               (empty — nothing loaded)
points1: raises "No raw file loaded"

--- call 2: the SAME command again ---
Table file data read: <table>
points=3, vars=2, datasets=1
rc=<>
info2: 0 current | 0 <table> table
points2: 3
```

Note what `raw info` says after call 2: the table is **slot 0**. The transient result that was
loaded before call 1 is gone, and nothing said so — the only output is the generic
`free_rawfile(): clearing data` line, which the same verb prints when it is used deliberately as an
unload.

## The contrast that shows this is a defect and not a design

`xschem raw table_read <file>` — same tree, same file format, name differing by one word — goes to
`extra_rawfile(1 | RAW_READ_REBIND, argv[3], "table", …)`, which **appends**:

```
read rc=1                                            (fixture loaded)
raw table_read rc=<1>
info3: 1 current | 0 …/calc_fixture.raw tran | 1 <table> table
```

One call, a real return code, the incoming file current, the outgoing one still loaded. That is the
read-before-clear policy `ase::attach_dbs` states in its own comment as *"a stale-but-loaded DB
beats an empty viewer"*. The top-level verb predates the registry and implements the opposite.

## Why it looks deliberate and is not

The arm's own help comment above it reads *"If a simulation raw file is lodaded unload from memory.
else read a tabular file 'table_file'"* — so the toggle **is** documented, and the sentence is
honest about the code. Two reasons it is still filed:

* **The toggle is not reachable as a toggle.** The documented unload behaviour requires passing a
  filename that is then ignored, so the "unload" spelling is `xschem table_read <anything>`. There
  is no argument-free spelling and no separate unload verb at the top level; `xschem raw clear`
  (also argument-free) is the one that exists, and it is in the other dispatcher.
* **A caller cannot write the two-call form safely either.** The second call is only a read if
  nothing got loaded in between, and nothing in the verb's answer reports which arm ran, so the
  loop a caller has to write is "call, ask `raw info`, call again if needed" — against a verb whose
  first call has already destroyed the user's result.

## Open items

1. **Decide what the top-level verb is for, and say so in one place.** Two shapes are defensible
   and they are not interchangeable: (a) make it a thin alias of `xschem raw table_read` — one
   call, appends, returns 1/0 — and accept that the documented unload behaviour goes away;
   (b) keep the unload but give it its own spelling and make the filename form always read. **(a)
   is the smaller change and the one a Calculator import path wants**, but it changes a documented
   user-visible behaviour, so it is the user's call and not the implementer's.
2. **The verb should return something.** Whatever is decided above, `Tcl_ResetResult(interp)` on
   every path means no caller can check. `xschem raw table_read` already returns
   `extra_rawfile()`'s value; matching it costs one line and is independent of item 1.

## What this is NOT

Not the same defect as the tilde expansion the arm's own long comment describes (issue 0812,
fixed): that comment is about *how* the filename is expanded, and the filename here is expanded
correctly and then not used.

Not a duplicate of issue 1636, which is about `xschem raw clear <name> <type>` moving the selected
analysis. This one destroys the whole registry; that one keeps it and moves the cursor.
