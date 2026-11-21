# 1725 — a window whose undo directory could not be created crashes xschem when it is closed

**STAMP:** `v1 claim=open tree=d36cb429e stamped=2026-11-19 fix=untried open=2 by=driver`

Found on 2026-11-19 by the second review of issue 1724, while it stress-ran the new
`test_pin_marker_1724` suite. It is not caused by issue 1724: a binary built from this
commit's `src/` crashes the same way. Filed, not fixed.

## What happens

1. A second window or tab is opened and something is edited in it, so that context asks
   for its undo directory (`init_undo()` in `src/save.c`, reached from the first
   `push_undo`).
2. `create_tmpdir()` fails five times. `init_undo()` then prints
   `init_undo(): problems creating tmp undo dir, Undo will be disabled`, sets `no_undo`,
   and still marks the context as initialised, with `undo_dirname` left NULL.
3. When that window is closed, `delete_undo()` builds a path from the NULL directory name
   and `my_snprintf()` calls `strlen(NULL)`: `FATAL: signal 11`.

Backtrace taken with gdb on the working-tree binary: `strlen` <- `my_snprintf` <-
`delete_undo` <- `delete_schematic_data` <- `new_schematic`.

## How a directory comes to fail

Two ways were measured.

- **The temporary directory cannot take it.** With the Tcl variable `XSCHEM_TMP_DIR`
  pointing at a directory that does not exist during the second context's
  `xschem push_undo`, then `xschem new_schematic destroy <second> {}`: the process dies.
  With `create_window` instead of `create` the destroy answers and the process dies at
  exit. The same probe without the bad directory passes.
- **Several xschem processes start in the same second.** `random_string()` in
  `src/save.c` seeds once with `srand((unsigned short) time(NULL))`, and it draws each
  character with `rand() % (sizeof(charset) - 1)` where `charset` is a pointer, so the
  names use only the first few letters of the alphabet. Every process started in one
  second therefore walks the same list of names. Two or three processes get through on
  the five retries; eight started together lost four, each printing
  `create_tmpdir(): failed to create /tmp/xschem_undo_<letters>, aborting` before the
  crash. In the review's stress run, 5 of 32 parallel display-arm runs of
  `test_pin_marker_1724` ended this way (that suite opens and closes the waveform
  viewer's context, which pushes undo).

One full regression run is serial, so the gate is not exposed. A parallel audit, or
several sessions starting suites together, is. For a user: a window opened while the
temporary directory is full or unwritable crashes xschem when that window is closed.

## Open items

1. **The crash.** `init_undo()` should mark the context initialised only when
   `create_tmpdir()` succeeded, so `delete_undo()` takes its not-initialised arm (or
   `delete_undo()` returns early on a NULL directory name). Tried by the review in a
   scratch build only: the bad-directory probe then answers and passes, and undo stays
   disabled for that context. Not tried in this tree. It needs a suite of its own that
   points `XSCHEM_TMP_DIR` at a missing directory, creates a second context, pushes undo
   there, restores the variable, destroys the context and asserts the process is alive.
2. **The names.** `random_string()` should index with the length of the string, not the
   size of a pointer, and mix the process id into the seed (or `create_tmpdir()` should
   use `mkdtemp`). A row: two names drawn in one process use letters beyond the first
   few.

The review's probes are not in the tree. Their shapes are described above closely enough
to rewrite: the bad-directory probe is nine lines of Tcl.

Related: issue 1706 is the same crash, filed on 2026-11-15 from the name-collision side
(the seed, the alphabet, the three other doors that reach the same NULL, and what
upstream has). Its section of 2026-11-19 has a full regression run that lost one case
this way while other sessions were starting xschem on the same machine.
