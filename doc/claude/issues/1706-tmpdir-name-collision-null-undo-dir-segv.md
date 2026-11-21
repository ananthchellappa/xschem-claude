# 1706 — xschem processes started in the same second share temp-dir names, and a failed undo dir then SIGSEGVs

**STAMP:** `v1 claim=open tree=bd14668b9 stamped=2026-11-15 fix=none open=3 by=driver`

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

## Second sighting, 2026-11-15: a tab close under valgrind, on the base tree

Found by the selection-look batch's crew A5b while testing; it is not caused by that batch.
The code facts in this section were re-read at `bd14668b9` (the batch's uncommitted `src/`
edits touch none of the undo code). `init_undo()`, `random_string()` and `create_tmpdir()`
are byte-identical there to the fork base. Everything marked **crew** is the crew's
measurement, not re-run while filing. Everything marked **forensic** was read off `/tmp`
afterwards, without running xschem.

### What was seen (crew)

- The pose `a5_canvas`, row TM5, closes a tab from its right-click menu and answers OK to
  *"UNSAVED data: want to exit?"*. It sometimes stopped there. Under valgrind it is
  `Invalid read of size 1` at address `0x0` in `strlen`, called from `my_snprintf` ←
  `delete_undo` ← `delete_schematic_data` ← `new_schematic` ← `xschem_cmds_e` ← `xschem`.
  `free_xschem_data()` is static and does not appear, presumably inlined. A second report
  follows from inside `sig_handler`: `Syscall param rename(oldpath) points to unaddressable
  byte(s)`. That is the emergency save's `rename()` being handed the same NULL.
- Reproduced under valgrind with identical stacks:
  - base tree `~/gsl0` (classic, `e3c43487e`/`bd14668b9` era): 1 run in 10;
  - batch tree `~/gsa5`: 1 in 4;
  - batch tree `~/gsa7`: 2 in 5.

  The crew notes these counts are not a rate comparison, and the next subsection shows
  why: the rate follows launch timing, not the tree.
- Evidence: `doc/claude/selection_look_batch/receipts/A5b-fixes.md`, section *"Observation,
  not mine: the `a5_canvas` TM5 stop is a crash in `delete_undo()`, on base too"*.
  - The valgrind logs are `vgr_gsl0_a5_canvas_classic_own_b287b.vg`,
    `vgr_gsa5_a5_canvas_halo_own_1.vg`, `vgr_gsa7_a5_canvas_halo_own_2.vg` and
    `vg7_gsa7_a5_canvas_halo_own.vg`.
  - They are under
    `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/A5b/vg/`,
    which is session scratch and can be cleared.
  - The runs' stdout/stderr captures were deleted with the crew's `out/` directory. So this
    sighting has no `create_tmpdir(): failed to create ...` line to quote, unlike the first.

### The route the first report left unmeasured (forensic)

Item 2 of *What the code does* says which route exhausts all five candidates *"was not
measured"*. This sighting answers it.

- **Every crashing run was in a batch of four or five runs started in the same second**,
  one run per display. The start times come from the valgrind logs' birth times:
  - 12:24:40, 4 runs, 1 crash;
  - 12:27:46, 5 runs, 2 crashes;
  - 12:31:25, 4 runs, 1 crash.

  Two batches had no crash: one whose starts spread over 12:28:26 to 12:28:28, and the
  4-run batch at 12:30:43. The batch at 12:30:43 shows that one shared second is
  necessary but not sufficient.
- **Each crash leaked exactly one `/tmp/xschem_undo_*` directory**, holding one undo file
  and born 4 to 6 s after its batch started:
  - `fgaggaedad` at 12:24:46;
  - `cfcegfdbfa` and `ccgcfdgdfb`, both at 12:27:51;
  - `gggdcegedd` at 12:31:31.

  These are the main tab's dirs. `sig_handler()` renames only the current context's
  `undo_dirname`, which is the failed tab's NULL. So the other tab's dir is neither saved
  nor removed, and the emergency-save dir that `sig_handler()` creates stays empty.
- **A standalone replay of `random_string()`'s generator decodes all four.** The replay
  uses glibc `rand()`, `srand((unsigned short) t)` and the index `rand() % 7`; it is in
  `.../scratchpad/undo_issue/dec.c` and `dec2.c`.
  - Each seed is 0 to 2 s before its dir's birth.
  - Three dirs sit at `rand()` offset 12, the process's first candidate for an undo dir.
  - `ccgcfdgdfb` sits at offset 22, the next candidate. It has the same seed, 1974, as
    `cfcegfdbfa`. So two processes in the 12:27:46 batch drew one sequence, and one had to
    step past the other's name. The filesystem recorded a same-prefix collision.
  - Chance matches do exist, at large offsets or seeds minutes away. Matching one name
    within 2 s and at offset 12 or 22 by chance is on the order of 1e-8.
- **The shared sequence is visible directly, too.** Decoding the older leaked names in
  `/tmp` turned up `xschem_emergencysave_<cellA>_cdacccadgc` and
  `xschem_emergencysave_<cellB>_cdacccadgc` (two different user cells, names withheld), and
  also `..._ecfffbfbgf` for both. These are two processes with one seed, 60379, writing
  identical suffixes at the same positions. Their different cell prefixes kept them apart;
  `xschem_undo_` has no such escape.
- **The route that follows:**
  - Same-seed processes walk one name sequence in rough lockstep, and every attempt
    consumes a candidate whether it succeeds or not.
  - A process can take its main-tab dir on the first or second candidate and then be the
    last to reach the new tab's `init_undo()`. It then finds the next five candidates
    already held by its siblings' main-tab and tab dirs, and `create_tmpdir()` returns NULL.
  - With four lockstep processes this needs nothing unusual. Siblings B, C and D take
    candidates 2, 3 and 4 for their main tabs and 5, 6 and 7 for theirs. A, the first to
    make its main dir, then tries 2 to 6, and all five are taken.
  - This is timing-dependent, which is why it is intermittent at every tree.
- **Decoder detail.** These display-arm processes spend two `rand()` calls on something
  other than `random_string()` before the undo name: offset 12 rather than 10. Older
  leaked undo dirs decode at offset 10. Any other `rand()` caller in the process shares
  the stream.

### Three more NULL doors (by reading, not observed)

A failed `init_undo()` leaves the context in this state: `no_undo = 1`,
`undo_initialized = 1`, `undo_dirname = NULL`. `delete_undo()` at teardown is the door
both sightings went through. Three others reach the same `strlen(NULL)`:

1. **`xschem set no_undo 0`.** It is issued unconditionally by the restore paths in
   `src/op_annot.tcl`, `src/hspice_backannotate.tcl` and `src/xschem.tcl` (`no_undo` has no
   getter, issue 0432).
   - On the next edit, `push_undo()` calls `init_undo()`. That is a no-op, because
     `undo_initialized` is already 1.
   - It then passes `if(xctx->no_undo) return;` and hands NULL to `my_snprintf()` for the
     `gzip --fast -c > %s/undo%d` command.
2. **`undo_shield_push()` in `src/netlist.c`.** This is fork code, from `39ef9d74b`
   (issue 0498), and absent at the fork base. It forces `no_undo = 0` immediately before
   the hierarchy walks' own `xctx->push_undo()`.
   - That covers every `global_verilog_netlist()` run (the shield is unconditional there),
     every hierarchical SPICE, Spectre or tEDAx netlist, and `hier_psprint()`.
   - On a failed context, each of those reaches the same `push_undo()` crash.
   - The fork's fix for 0498 thereby turns upstream's silent no-op here into a SIGSEGV.
3. **`xschem undo_type memory`**, which calls `delete_undo()` directly.

### Upstream

The defect comes from upstream; the fork did not introduce it.

- Every line of `init_undo()`, `random_string()` and `create_tmpdir()` blames to upstream
  (Stefan Schippers, 2020-08-08 to 2025-04-18), unchanged since the fork base `f276d0cf2`
  (`origin/master`).
- The fork's two edits to `delete_undo()` leave the crashing path untouched:
  - `05af45561`, a port of upstream `0fa7b0ed7`'s early-return free;
  - `6658b6555`, the issue-0043 id ring.
- Upstream `0fa7b0ed7` (2026-10-13) is on a later upstream line that does not descend from
  the fork base. It is in this clone's object store but on no ref. At that commit:
  - `charset` is an array, so open item 2 is fixed upstream there;
  - `srand((unsigned short) time(NULL))` remains;
  - `init_undo()` still sets `undo_initialized = 1` after a failed `create_tmpdir()`;
  - `delete_undo()` still passes `undo_dirname` to `my_snprintf()` on the initialised path;
  - `my_snprintf()`'s `%s` arm still calls `strlen()` with no NULL check.

  So open items 1 and 3 are open upstream too, and worth reporting there.

### Fix direction, refined by this sighting

- **Open item 3 belongs in `init_undo()`, not at each reader.** Setting `undo_initialized = 1`
  only on success closes all four doors at once:
  - `delete_undo()` then early-returns;
  - a later `push_undo()` with `no_undo` cleared retries `create_tmpdir()`, and the
    sequence has moved on by then.

  Guarding the readers instead leaves the next door open.
- **Do not disable undo on that failure; fall back to memory undo for that context.**
  Switch the function pointers to `mem_*`, as `xschem undo_type memory` does.
  - With undo disabled, even a non-crashing `push_undo()` is a silent no-op.
  - That silently disables the 0498 walks' save/restore, whose measured consequence is the
    top-level buffer replaced by a sub-sheet.
  - The fallback keeps editing undo and the walk's restore both working.
- **Open item 1 alone removes the trigger.** Mix the pid into the seed, or use `mkdtemp()`
  where available.
- **Do not paper over this in `my_snprintf()`.** Printing `(null)` there would turn the
  crash into `xunlink("(null)/undo0")` and `rmdir("(null)")` relative to the cwd.
- The fence proposed under *Open items* still stands. Add a row driving a failed `init_undo()` through
  `xschem set no_undo 0` plus one edit, and one through a Verilog netlist. Each must exit
  cleanly.

## Third sighting, 2026-11-19: one case of a full regression run, lost after all its checks had passed

Seen while issue 1724 was being reviewed. It is not caused by that work, and nothing here
changes the claim on the stamp line. What follows is read off two files the run left; the
run was not repeated.

### What was seen

A full regression run in a clone (`/home/analog/g1724`, pid 1865558, started 15:02:56,
1750 s), taken while ten review agents were starting xschem on the same machine, each
through `tests/headless/run_suites.sh` on its own private Xvfb. Its trailer:

    T1-RUN-END pid=1865558 cases=224 blocks=223 counted_failures=2 skips=13 elapsed=1750s end=2026-11-19 15:32:06

Both counted lines are one case, `headless/test_wave_subwindows` on the display arm:

    headless/test_wave_subwindows.disp.log
    FATAL: signal 11
    HARNESS: headless/test_wave_subwindows (display arm) did not complete cleanly (exit=1, OVERALL_ok=1, died=1) -- crashed, aborted mid-script, or a check failed: FAIL
    RESULT: ALL PASS (544 checks)
    Total num fail: 2

Every other block of that verdict reads `Total num fail: 0`. The case's own log, in the
order it printed:

    create_tmpdir(): failed to create /tmp/xschem_web_cgagaegaea, aborting
    xinit(): problems creating /tmp/xschem_web_xxxx dir
    ...
    create_tmpdir(): failed to create /tmp/xschem_undo_ffceaebeca, aborting
    init_undo(): problems creating tmp undo dir, Undo will be disabled
    init_undo(): Check permissions in /tmp
    ...
    OVERALL: ok (544 checks)
    RESULT: ALL PASS (544 checks)
    rename dir (null) to /tmp/xschem_emergencysave_untitled_bbgdbdgdbg failed
    EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled_bbgdbdgdbg

    FATAL: signal 11
    while editing: untitled

The first failure is at the head of the log, at startup (the `xschem_web_` directory of
`xinit()`); the second comes while the suite is running, when a context asks for its undo
directory. The suite then ran to its end with every check passing, printed its completion
line, and died at teardown: the `(null)` of the emergency save's `rename` is the failed
context's `undo_dirname`, the route "What the code does" item 3 describes.

Three runs of the same suite alone afterwards, in the same clone, each ended `RESULT: ALL
PASS (544 checks)`.

### What it adds

- **The collision does not need a harness that starts its own runs together.** The
  regression driver is serial. The processes that shared its second were other sessions'
  suite runs on the same machine. One of the review agents had started sixteen display
  runs of one suite in one second at 15:28:52, and reports that several of them printed
  the same two names, `xschem_web_cgagaegaea` and `xschem_undo_ffceaebeca`, before four of
  them died the same way.
- **The names are all from the first seven letters**, as item 2 of "What the code does"
  predicts.
- **A run can pass every check and still be scored as failed, or the other way round.**
  The regression driver counts this case (a column-0 `FATAL:` line and exit 1, although
  the completion line is there). `tests/headless/run_suites.sh` scored the review agent's
  runs that died the same way as PASS, because it reads the result line.
- **So a gate is exposed whenever anything else on the machine starts xschem in the same
  second.** A red of this shape (the two `create_tmpdir(): failed` lines, a full pass,
  then `FATAL: signal 11` at exit) is not a defect of the suite it lands on. Run the
  suite again alone, and run a gate with nothing else starting xschem.

Issue 1725, filed the same day by that review, is the crash half of this (a context whose
undo directory could not be created crashes when it is closed), measured there with a
missing temporary directory and no second process.

Evidence: `lead4/t1_r3/results.1865558.log` and `lead4/t1_r3/test_wave_subwindows.disp.log`
under that session's scratchpad
(`/tmp/claude-1000/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/scratchpad/`),
which is session scratch and can be cleared; the lines above are copied from them.
