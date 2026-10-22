# 1706 — xschem processes started in the same second share temp-dir names, and a failed undo dir then SIGSEGVs

**STAMP:** `v1 claim=open tree=af9c26789 stamped=2026-10-22 fix=none open=3 by=driver`

Filed, not fixed. Found by verifier crews running several `run_suites.sh` arms in
parallel on separate private Xvfb displays. The code facts below were read in the tree
at `af9c26789`; the crash observation is the crews' report and was not reproduced
while filing.

## Observation (reported, not re-measured here)

Several xschem test runs launched **in the same second** died with `FATAL: signal 11`,
with both the HEAD binary and modified builds. Their stderr carried

    create_tmpdir(): failed to create /tmp/xschem_undo_..., aborting

and the emergency save printed `rename dir (null) to ...`. Launches spaced 2 s or more
apart never crashed. This is a hazard for any parallel harness and for a user who
starts two xschem processes at once.

## What the code does (src/save.c, src/xinit.c, src/main.c)

### 1. The seed is the wall-clock second, truncated to 16 bits

`random_string()` in `src/save.c` seeds once per process with
`srand((unsigned short) time(NULL));`. Two processes started in the same second
therefore get the same `rand()` sequence and generate the **same candidate names in the
same order**. The cast to `unsigned short` also makes the seed repeat every 65536 s
(about 18 h). The same generator serves `create_tmpdir()` (undo dirs, the
`xschem_web_` dir in `src/xinit.c`, the emergency-save dir in `sig_handler()` in
`src/main.c`) and `open_tmpfile()`.

### 2. Only 7 characters of the 62-character charset are ever used

`charset` is declared `static const char *charset="abc...789";`, which is a
**pointer**, and the index is `rand()%(sizeof(charset)-1)`. `sizeof(charset)` is the
size of a pointer, not of the string, so on a 64-bit build the index is in 0..6 and
every random character is one of `a`..`g`. The comment above the function (example
`"/xschem_undo_dj5hcG38T2"`) shows the intended 62-character alphabet. This does not
cause the collision by itself (it still leaves 7^10 names) but it means the names are
far less random than the code reads.

`create_tmpdir()` tries five candidates and then returns `NULL`. With a shared seed,
concurrent processes walk the same five candidates; which route exhausts all five in
the reported runs (lockstep `stat`/`mkdir` races between several processes, other
`create_tmpdir()`/`open_tmpfile()` calls having already consumed earlier names, or
directories left behind by an earlier crash at the same seed) was **not measured**.

### 3. A failed undo dir is still marked initialised, and teardown dereferences NULL

`init_undo()` in `src/save.c`:

- `my_strdup(_ALLOC_ID_, &xctx->undo_dirname, create_tmpdir("xschem_undo_"))` — with a
  `NULL` source `my_strdup()` (`src/util.c`) leaves/sets the destination `NULL` and
  returns 0;
- on that failure it prints the two `init_undo(): ...` messages and sets
  `xctx->no_undo = 1`;
- then, **unconditionally**, sets `xctx->undo_initialized = 1`.

`delete_undo()` returns early only on `!xctx->undo_initialized`, so it proceeds with
`xctx->undo_dirname == NULL`: `my_snprintf(diff_name, S(diff_name),
"%s/undo%d", xctx->undo_dirname, i)` reaches `my_snprintf()`'s `%s` arm in
`src/util.c`, which calls `strlen(sptr)` on the `NULL` — the SIGSEGV. (`rmdir()` on the
same `NULL` follows.) The path from a normal teardown is `new_schematic()` ->
`delete_schematic_data()` -> `free_xschem_data()` -> `xctx->delete_undo()` (set to
`delete_undo` for on-disk undo in `src/xinit.c` and `src/scheduler.c`).

The SIGSEGV then lands in `sig_handler()` (`src/main.c`), which for on-disk undo calls
`rename(xctx->undo_dirname, emergency_dir)` and on failure prints
`"rename dir %s to %s failed\n"` with the same `NULL` — glibc's `(null)` in the
observed output. That handler also calls `create_tmpdir()` again, under the same
shared seed.

## Open items (`open=3`)

1. Seed per process, not per second (e.g. mix in the pid), or use `mkdtemp()` where
   available.
2. Index with the string length (`strlen(charset)` or an array declaration), not
   `sizeof` of a pointer.
3. `init_undo()` must not leave `undo_initialized = 1` with `undo_dirname == NULL`, and
   `delete_undo()` / `sig_handler()` must tolerate a `NULL` `undo_dirname`.

A fence should launch several xschem processes within one second and assert that none
dies and each gets a distinct undo directory; and, separately, drive `init_undo()` into
its failure arm (e.g. an unwritable `XSCHEM_TMP_DIR`) and assert that a subsequent
teardown exits cleanly.
