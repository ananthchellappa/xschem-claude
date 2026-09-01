# 0316 — `read_dataset()`'s malformed-header aborts leak the half-built `Raw` and destroy the loaded database

> ⚠ **ATTEMPT 2 (2026-08-26) FIXED THIS AGAIN AND WAS REVERTED FOR AN UNRELATED REASON.**
> The four malformed-header aborts dropped their `extra_rawfile(3, NULL, ...)` clear-all
> and their `goto read_dataset_done` became `break`, so `read_dataset()`'s own
> `if(exit_status != 1) free_rawfile(...)` runs. **The fifth `goto` (the nvars mismatch)
> was deliberately left alone.** Valgrind on the abort path reported **0 definitely-lost
> bytes** (the 253,152-byte leak) and 0 errors. Rows R1–R6 in
> `test_raw_read_failure_0306` cover it. **Nothing about 0316's own fix is in doubt** —
> it was reverted only because the same patch made
> [0836](0836-update-op-segfaults-on-a-zero-point-database.md) reachable. See 0807 §13.


**Status:** OPEN. Measured on branch `fluid-editing` at the 0306 fix commit. A fix was written
under item 0807 on 2026-08-25 (the recommended variant: `break` into the function's own
`free_rawfile()`), **confirmed to close both the data loss and the leak**, then **reverted with
the rest of that item** — see
[0807](0807-annotate-op-destroys-the-attached-op-database-on-a-truncated-raw.md) §7.
**Area:** `src/save.c`, `read_dataset()` — the four `goto read_dataset_done` sites that jump over the
function's own `free_rawfile()`.
**Found:** 2026-08-12, by the phase-3 adversarial review (C memory-safety lens) of the issue-0306
fix. It was raised as a falsification of a premise the 0306 test file leaned on, and it is a real
defect in its own right.
**Related:** `doc/claude/issues/0306-a-failed-raw-read-leaves-a-state-the-next-operation-crashes-on.md`
(FIXED) — the *same shape*, in `table_read()`. 0306's scope rule ("if you find a third instance of
the same shape, file it as a new issue and fix it only if it is in the same two functions") is why
this is filed rather than fixed: `read_dataset()` is a third function.

**This is the same lesson 0306 carries: a failed read has to leave the editor in the state it found
it.** 0306 was `table_read()` forgetting to free on its error path. This is `read_dataset()`
forgetting on four of its error paths — and, unlike 0306, it also *destroys a good database* on the
way out.

---

## Mechanism

`read_dataset()` ends with a single cleanup, which is correct:

```c
  /* no analysis was found: delete */
  if(exit_status != 1) {
    free_rawfile(rawptr, 0, no_warning);
  }
  read_dataset_done:
  if(line) my_free(_ALLOC_ID_, &line);
  ...
  return exit_status;
```

Four malformed-header aborts `goto read_dataset_done`, i.e. **jump over that free**. All four have
the same shape (locate by the message, not by line number):

| abort | message |
| --- | --- |
| `No. of Data Rows :` | `read_dataset(): WARNING (No. of Data Rows): malformed raw file, aborting` |
| `No. Variables:` | `read_dataset(): WARNING (No. Variables): malformed raw file, aborting` |
| `No. Points:` | `read_dataset(): WARNING (No. Points): malformed raw file, aborting` |
| the `Variables:` index/name lines | `read_dataset(): WARNING (Variables): malformed raw file, aborting` |

Each one calls `extra_rawfile(3, NULL, NULL, -1.0, -1.0)` — clear-all — on the line above the
`goto`, and each has a **commented-out** `/* free_rawfile(rawptr, 0, 0); */` next to it, so the
free was consciously delegated to that call. The delegation only works in one of the two cases:

* **`xctx->extra_raw_n == 0`** — the adopt block at the top of `extra_rawfile()` takes
  `xctx->raw` (the half-built `Raw`) into slot 0, and the clear-all loop then frees it. Correct.
* **`xctx->extra_raw_n > 0`** (a database is already registered) — the adopt block does **not**
  fire, so the clear-all frees the *good* entries, sets `xctx->raw = NULL` and never sees the
  half-built one. The only remaining pointer to it is `read_dataset()`'s own `raw` local, and the
  function returns. **Leaked.**

Note that adding `if(*rawptr) free_rawfile(rawptr, 0, 1);` after the `extra_rawfile(3, ...)` call
does **not** fix it: `rawptr` is `&xctx->raw` at every call site, and the clear-all has already
NULLed it. The fix has to hold the pointer itself.

## Repro (measured, this tree)

```sh
printf 'time a b\n0 0 1\n1 2 3\n2 4 5\n' > /tmp/i0316/good.tbl
printf 'Title: x\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: junk\n' > /tmp/i0316/bad.raw
```

```tcl
puts "L1=[xschem raw table_read /tmp/i0316/good.tbl]"
puts "L2=[xschem raw info]"
catch {xschem raw read /tmp/i0316/bad.raw tran} e
puts "L3=$e"
puts "L4=[xschem raw info]"
puts "L5=[xschem raw loaded]"
```

```
L1=1
L2=0 current
0 /tmp/i0316/good.tbl table

read_dataset(): WARNING (No. Variables): malformed raw file, aborting, line:
No. Variables: junk

free_rawfile(): clearing data
raw_read(): no useful data found
extra_rawfile() read: /tmp/i0316/bad.raw not found or no "tran" analysis
L3=0
L4=
L5=-1
```

`L4` and `L5` are the second half of the defect: **the good database is gone.** The user asked to
load a second raw file, the second file was malformed, and the first one was destroyed silently —
`extra_rawfile()`'s restore branch cannot restore anything because `extra_raw_n` is now 0.

Under valgrind, the same script:

```
==4061994== 253,152 (136 direct, 253,016 indirect) bytes in 1 blocks are definitely lost
==4061994==    at 0x484D953: calloc
==4061994==    by 0x1DBCCD: my_calloc
==4061994==    by 0x1E0DA9: raw_read
==4061994==    by 0x1E01E1: extra_rawfile
==4061994==    by 0x1A2915: xschem_cmds_r.constprop.0
==4061994== LEAK SUMMARY:
==4061994==    definitely lost: 136 bytes in 1 blocks
==4061994==    indirectly lost: 253,016 bytes in 1 blocks
```

**253,152 bytes per attempt** — 136 direct + 253,016 indirect, i.e. `HASHSIZE` (31627) ×
`sizeof(Int_hashentry *)`. Exactly the figure 0306 measured for `table_read()`'s orphan, because it
is the same allocation.

## Reachability

Higher than 0306's. 0306 needed a path that `stat()`s as existing but is not a regular file — a
typed or scripted path. This needs only a **malformed or truncated raw file**, which is what a
crashed or killed simulator leaves behind, and which any of the shipped carry-over paths
(`open_sub_schematic`, `hi_descend`'s new-window arm, `load_raw`, the ASE plot path) will happily
hand to `raw_read()`. The `No. Points:`/`No. Variables:` header of a truncated ngspice raw file is a
realistic input.

It does **not** crash. 0306's crash needed a NULL `rawfile` reaching a registry lookup loop, and the
`Raw` leaked here is never registered — so 0306's guards are unaffected and its "no reachable
producer of a NULL-rawfile registry entry" argument still holds. This is a leak plus a data-loss,
not a SIGSEGV.

## Fix, when someone takes it

Hold the pointer across the clear-all at each of the four sites, e.g.

```c
      if(n < 1) {
        Raw *orphan = *rawptr;                     /* the clear-all below may NULL *rawptr */
        dbg(0, "read_dataset(): WARNING (No. Variables): malformed raw file, aborting, line:\n%s\n", line);
        extra_rawfile(3, NULL, NULL, -1.0, -1.0);
        if(orphan && orphan == *rawptr) free_rawfile(rawptr, 0, 1);
        else if(orphan && !*rawptr) { Raw *t = orphan; free_rawfile(&t, 0, 1); }
        exit_status = 0;
        goto read_dataset_done;
      }
```

— or, better and in one place, **delete the four `extra_rawfile(3, ...)` calls and let the four
aborts fall through to the function's existing cleanup** by `break`ing out of the `while` instead of
`goto`ing past it. That is what the two data-block aborts already do (issue 0213 wrote them that
way, with a comment saying why), and it would make all six abort paths agree. It changes behaviour:
the registry would no longer be wiped on a malformed header, which is the *second* half of this
issue and is arguably the point.

The data-loss half deserves its own decision. `extra_rawfile()` already has a restore-on-failure
branch that exists precisely so a failed read does not cost the user the database they had; the
clear-all inside `read_dataset()` defeats it. Whoever takes this should decide whether the clear-all
belongs there at all.

A test belongs in `tests/headless/test_raw_read_failure_0306.tcl`, which already owns the
"a failed read must leave the editor as it found it" theme and has the child harness for it: read a
good table, then read a malformed raw, then assert `xschem raw info` still lists the good file.


---

## Addendum, 2026-08-25 (item 0807) — the recommended variant was built and it works

Item 0807 could not meet its own acceptance without this: a raw truncated inside
`No. Points:` / `No. Variables:` / the `Variables:` index list makes the **reader** wipe the
whole registry, so no amount of care in `annotate_op` survives it.

The variant built was this issue's own recommendation — delete the `extra_rawfile(3, NULL, ...)`
clear-all and its dead commented `free_rawfile()` twin, keep `exit_status = 0;`, and turn
`goto read_dataset_done;` into `break;` so the function's existing
`if(exit_status != 1) free_rawfile(rawptr, ...)` runs. All six abort paths in the function then
agree. ⚠ The **fifth** `goto read_dataset_done` (the nvars-mismatch one) must **not** be
touched — it deliberately preserves `exit_status` for datasets already read.

Measured on that build, against this issue's own repro verbatim: the good entry survived the
malformed read (`L4` listed it where it had been empty, `L5` was 0 where it had been −1), and
**valgrind reported `definitely lost: 0 bytes in 0 blocks / indirectly lost: 0 bytes`** where
this issue measured **253,152 bytes lost per attempt**. Five test rows were written into
`tests/headless/test_raw_read_failure_0306.tcl` as this issue suggested — one per abort site
plus a crash canary — and a sabotage variant that restored the clear-all reddened all of them.

None of it is in the tree; the diff is at `doc/claude/evidence/0807-attempt1-reverted.patch.txt`.
This fix was **not** the reason 0807 was reverted and it can be taken on its own.
