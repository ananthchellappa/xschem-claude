# 0854 - `annotate_op`'s pre-delete hands `extra_rawfile()` a pointer into the Raw it then frees

**Status:** OPEN, **measured under valgrind**, not fixed. Filed 2026-08-26 by the
0836 crew. Adjacent to
[0807](0807-annotate-op-destroys-the-attached-op-database-on-a-truncated-raw.md)
but **distinct from it**: 0807 is about *whether* the pre-delete should happen at
all; this is about the pre-delete being memory-unsafe *however that is ruled*.

## The defect

`src/scheduler.c`, the `annotate_op` branch:

    /* delete previously loaded OP */
    if(xctx->raw && xctx->raw->rawfile && xctx->raw->allpoints == 1 &&
       (!strcmp(xctx->raw->sim_type, "op") || !strcmp(xctx->raw->sim_type, "dc"))) {
      res = extra_rawfile(3, xctx->raw->rawfile, xctx->raw->sim_type, -1.0, -1.0);
    }

Both arguments are pointers **into the Raw that the clear arm is about to free**.

`extra_rawfile()` copies the *file* argument into a local buffer on entry —
`resolve_rawfile_path(file, f, (int)S(f))` — so `f` survives. **The `type`
argument is never copied.** The named-clear loop then keeps dereferencing it
after the free:

    for(i = 0; i < xctx->extra_raw_n; i++) {
      if(type && type[0] &&                                    /* <-- reads freed memory */
          xctx->extra_raw_arr[i]->rawfile && xctx->extra_raw_arr[i]->sim_type &&
          !strcmp(xctx->extra_raw_arr[i]->rawfile, f) &&
          !strcmp(xctx->extra_raw_arr[i]->sim_type, type) ) {  /* <-- and here */
        free_rawfile(&xctx->extra_raw_arr[i], 0, no_warning);  /* <-- frees raw->sim_type */
        found++;
        continue;
      }
      ...
    }

`free_rawfile()` releases `raw->sim_type` (`src/save.c`, `my_free(_ALLOC_ID_,
&raw->sim_type)`). So once the matching entry has been freed, every **subsequent**
iteration of the loop reads a dangling pointer. It is only invisible when the
matching entry happens to be the last in the registry.

## Measured, at the 0836 commit, under valgrind

Registry built as `[0 G op | 1 S tran]` with `G` current, then
`xschem annotate_op <L>`:

    ==1094444== Invalid read of size 1
    ==1094444==    at 0x1E48DF: extra_rawfile (save.c:2022)
    ==1094444==  Address 0x60c1bb0 is 0 bytes inside a block of size 3 free'd
    ==1094444==    at 0x484988F: free
    ==1094444==    by 0x1E3884: free_rawfile (save.c:1099)
    ==1094444==    by 0x1E5238: extra_rawfile (save.c:2032)

A block of size 3 is `"op"` plus its terminator — the `sim_type` string the
caller passed in. Freed at the loop's `i == 0` iteration, read again at `i == 1`.
The process survived this run; that is what undefined behaviour looks like when
the allocator has not yet reused the block.

Reproducer (`--nogui --pipe`, fixtures are the 0836 suite's `G`, `S`, `L`):

    xschem raw read <G> op        ;# arr = [0 G op]
    xschem raw read <S> tran      ;# arr = [0 G op|1 S tran]
    xschem raw switch 0           ;# make G current again
    xschem annotate_op <L>        ;# pre-delete frees arr[0], loop continues to arr[1]

## Why this is not 0807

0807 asks whether `annotate_op` should be deleting the attached operating point
database before it has successfully read a replacement — a behaviour question,
reverted on 2026-08-26 and still open. **This issue stands whichever way 0807 is
ruled**: as long as the pre-delete exists in any form, it must not hand
`extra_rawfile()` a pointer that `extra_rawfile()` will free and then keep
reading. If 0807 is fixed by removing the pre-delete entirely, this dies with it;
if 0807 is fixed by making the delete conditional on a successful read, this
survives untouched and still wants fixing.

## The fix shape

Copy `type` on entry the way `file` already is — one local buffer beside `f`,
filled at the top of `extra_rawfile()` before any dispatch, so the whole function
works from its own storage and no arm can be broken by a caller passing in a
pointer to registry-owned memory. That is strictly better than fixing it at the
one caller: the same hazard is available to every future caller of
`extra_rawfile(3, ...)`, and the loop is the thing that is wrong.

## Acceptance if fixed

1. The reproducer above runs clean under
   `valgrind -q --leak-check=no`: no `Invalid read`, in `extra_rawfile` or
   anywhere on that path.
2. **Positive twin.** `xschem raw clear <file> <type>` still removes exactly the
   named entry and leaves the others, with the registry listing asserted before
   and after — the fix must not turn a working clear into a no-op.
3. A clear whose match is the **last** registry entry still works (that is the
   case that never dereferenced freed memory and so could silently change).
4. A clear with a NULL/empty type still removes by filename alone (the second arm
   of the same loop).
5. Sabotage: revert the copy and confirm row 1 reds under valgrind.

⚠ Row 1 needs valgrind or ASAN. A plain run **passes on the broken tree** — the
measured run above survived. An acceptance row that only checks the exit code
would be hollow here in the strictest sense.
