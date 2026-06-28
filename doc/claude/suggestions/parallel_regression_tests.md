# Parallelizing the XSCHEM regression tests — a tutorial

*Why the suite took minutes, what made it unsafe to "just run in parallel," and how
the fix is structured so it stays correct.*

This came up as an afterthought ("are the tests even running in parallel?") and is the
kind of thing that's easy to miss: the suite was never slow because the *work* is slow
— it's slow because it does the work ~2,600 times, one process at a time.

---

## 1. Where the time actually goes

`tests/run_regression.tcl` runs three cases back-to-back, and each case is a plain
`foreach { exec xschem ... }` loop that **spawns one `xschem` process per file and
blocks until it exits** before starting the next.

| Case          | Invocations | What each invocation does                              |
|---------------|-------------|--------------------------------------------------------|
| `create_save` | 5           | one `xschem` per generator script                      |
| `open_close`  | ~1893       | one `xschem` per `.sym`/`.sch` in `xschem_library/`    |
| `netlisting`  | ~728        | one `xschem` per `.sch` × 4 formats (vhdl/v/tdx/spice) |

A single invocation measures at **~0.13 s wall**. So `1893 × 0.13 ≈ 4 min` for
`open_close` alone. The schematics are tiny; the cost is almost entirely **per-process
startup** (Tcl init + library load). That is the textbook profile of an
*embarrassingly parallel* workload: thousands of independent, short, identical-shaped
tasks.

**Lesson:** before optimizing, measure *one* unit and multiply. If `unit_time ×
count ≈ total_time`, the bottleneck is the count and the loop, not any single unit.

---

## 2. Why you can't naively parallelize this

Two landmines turn "just add `&`" into silent corruption. Both were found by *reading
the code*, not by running it — a green suite would not have warned us.

### Landmine A — `cd` is process-global

`open_close` and `netlisting` do:

```tcl
cd $dir
exec $xschem_cmd $fn ...
cd $cwd
```

`cd` changes the working directory of the **whole Tcl interpreter**, not just that one
`exec`. If you launched several of these concurrently *inside the same interpreter*,
job B's `cd` would yank the directory out from under job A between its `cd` and its
`exec`. Every relative path (`$fn`, the `2> $output` redirect) would resolve against
the wrong directory, nondeterministically.

> **The fix is to never change the interpreter's cwd at all.** Each job is handed to a
> fresh `/bin/sh` as a self-contained command string that does its *own* `cd`. A
> child process's cwd is its own; it cannot disturb a sibling or the parent.

### Landmine B — colliding output filenames

`netlisting` writes every netlist into one shared directory using the schematic's
**basename**:

```
results/<schname>.<ext>      # e.g. results/Q1.spice
```

The library contains **5 duplicate `.sch` basenames** in different sub-directories
(`Q1.sch`, `Q2.sch`, `MSA-2643.sch`, `TwoStageAmp.sch`, `lightning.sch`). Sequentially
this is a benign "last writer wins," resolved by directory-walk order. Run
concurrently, two jobs would `open()` and `write()` **the same file at the same time**
→ interleaved garbage.

There's a subtler trap too: `xschem -o <dir>` also drops *intermediate* dotfiles in
the output dir. Two concurrent jobs sharing that dir would trample each other's
scratch files even when the final basenames differ.

> **The fix is isolation + deterministic collation.** Every job writes into its own
> private work dir (`results/.work/<idx>.d/`). A **sequential** post-pass then moves
> the finished netlist into the shared `results/` dir, **in the original walk order**.
> Races are impossible (nobody shares a dir during the write), and the
> last-writer-wins outcome is identical to the sequential run (same order), so we stay
> bit-for-bit comparable to the golden files.

### Landmine C — a latent program bug that only concurrency exposes

This one was *not* visible by reading the test scripts — it lives in xschem itself, and
the sequential suite never tripped it. On the first parallel run, ~9 of 728 netlist
jobs failed with `exit 1`, **intermittently** — a different set each run. The schematics
were fine; each passed when run alone.

The cause is in `src/save.c`:

```c
srand((unsigned short) time(NULL));          // 16-bit seed, changes once per second
...
const char *create_tmpdir(char *prefix) {
  for(i=0; i<5; ++i) {                        // only 5 attempts
    my_snprintf(str, ..., "%s%s", tclgetvar("XSCHEM_TMP_DIR"), random_string(prefix));
    if(stat(str,&buf) && !mkdir(str,0700)) return str;   // give up after 5 collisions
  }
  return NULL;                                // -> caller aborts, exit 1
}
```

xschem makes a temp/undo dir (and a `xschem_web_` dir) on every load, naming it with
`rand()` in the **shared** `XSCHEM_TMP_DIR` (hardcoded to `/tmp` on Unix). The seed is
`time(NULL)` truncated to 16 bits, so **two processes that start in the same second get
the identical `rand()` sequence** → identical candidate names → all 5 `mkdir` attempts
collide → `create_tmpdir` returns NULL → abort. Sequentially this never happens (one
process per instant); at 10-wide it happens whenever two jobs launch in the same second.

The right *product* fix is to seed `rand()` with something per-process (`time ^ getpid`)
— but that's a C change, a rebuild, and a behavior change shipped to all users, out of
scope for "speed up the tests." The **harness-level** fix matches the user's "safe usage
of directories": give every job its **own** `XSCHEM_TMP_DIR` so identical names land in
**different parent directories** and can't collide:

```
xschem ... --preinit 'set XSCHEM_TMP_DIR {<private-per-job-dir>}'
```

`--preinit` runs Tcl *before* xschemrc and before any temp dir is created, and a plain
`set` overrides the `/tmp` default (which is applied with `set_ne` = set-if-unset).
After this, 3 consecutive full runs gave **0 failures** and **bit-identical** results.

**Lesson:** concurrency doesn't only collide on *your* shared state — it surfaces
**latent races in the code under test** (weak RNG seeding, shared scratch dirs, global
lockfiles) that were simply unreachable serially. When a parallel run fails
*intermittently* and the same unit passes in isolation, suspect a shared namespace in
the program, not your harness. The cheapest correct fix is often to give each worker a
private namespace (its own temp dir / HOME / cwd) rather than to patch the program.

**Lesson:** parallelism is safe only when tasks are *actually* independent. Three things
break independence — **shared mutable global state** (the interpreter's cwd),
**shared output names** (the results dir), and **shared scratch namespaces inside the
program being tested** (xschem's `/tmp` temp dirs). Find all three before adding
concurrency.

---

## 3. The shape of the fix

Each case is restructured into three phases. This separation is the whole trick: the
expensive part runs in parallel, the parts that need ordering or shared state run
sequentially and cheaply.

```
PLAN (sequential, cheap)
  Walk the library tree exactly as before, in the same lsort order.
  For each unit, build a *job record*: the shell command string, the
  private work dir, the status file, and the output paths it will produce.
  No xschem runs yet. Ordering is captured here, once.

EXECUTE (parallel, expensive)
  Dump all job command strings, NUL-delimited, to a temp file.
  Feed them to:  xargs -0 -P <njobs> -n1 sh -c 'eval "$0"'
  Each command runs in its own /bin/sh: its own cwd, its own work dir,
  its own redirect. The pool keeps <njobs> running at once.

COLLATE (sequential, cheap, deterministic)
  Iterate the job records IN PLAN ORDER. For each: read its status file,
  apply the exact same pass/FATAL logic as the original, run
  cleanup_debug_file, move any netlist from the private dir into results/,
  and append to pathlist. Then print_results — unchanged.
```

Why `xargs -P` rather than Tcl threads or hand-rolled `exec &` bookkeeping:

- It's a **bounded pool** out of the box (`-P N` = at most N at once), so we never
  fork 1900 processes simultaneously.
- It needs no Tcl threading package and no fragile waitpid loop (Tcl 8.4–8.6 has no
  clean `waitpid`).
- `-0` (NUL-delimited) + `-n1 sh -c 'eval "$0"'` lets each job be an **arbitrary shell
  command** — `cd`, redirects, `;`, `$?` — without quoting nightmares. xargs hands the
  one NUL-delimited item to `sh` as `$0`; `eval "$0"` runs it.

### Per-job exit codes survive the pool

`xargs` only tells you *something* failed, not *which* or *how*. The original code
needs per-file exit codes — `netlisting` specifically treats **exit 10** (a netlist
error) as a non-fatal, expected outcome but any *other* nonzero exit as `FATAL`. So
each job records its own result:

```sh
... ; echo $? > '<results>/.work/<idx>.status'
```

The collate pass reads each `.status` file and reproduces the original logic exactly:

- `create_save` / `open_close`: nonzero ⇒ `FATAL`, count it.
- `netlisting`: `10` ⇒ ignore (expected netlist error, still record the paths);
  other nonzero ⇒ `FATAL`; `0` ⇒ normal.

**Lesson:** when a dispatcher (xargs, a queue, a thread pool) collapses many results
into one summary status, push the per-item outcome into a **side channel** each worker
owns alone (one status file per job — no append contention) and interpret it
afterward.

### Amdahl strikes back: the second bottleneck

After parallelizing the xschem spawns, `open_close` *still* took ~6 minutes. Timing the
phases separately told the real story:

```
xschem phase (1893 jobs, parallel):   4.7 s
awk cleanup phase (1893 files, serial): 389 s   <-- now 99% of the wall time
```

Each result file was normalized by its own `awk` process (`cleanup_debug_file`), called
**sequentially** in the collate loop. That serial spawn cost was always there — it was
just *hidden behind* the equally-slow serial xschem phase. The moment you parallelize the
obvious bottleneck, **the next-slowest serial stage becomes the whole runtime**
(Amdahl's law, in the flesh).

The fix has two parts, both worth internalizing:

1. **Batch, don't spawn-per-item.** `cleanup_debug_file.awk` already handles *many*
   files in one process (its `beginfile`/`endfile` logic writes each `FILENAME` back
   independently). Passing 64 files per `awk` turns ~1893 process spawns into ~30.
2. **Run the batches through the same pool.** Disjoint file sets per batch ⇒ no two
   awks touch the same file ⇒ trivially parallel.

Result: the 389 s cleanup dropped to ~30 s, and `open_close` went from ~6 min to ~37 s.

**Lesson:** profile *after* each optimization, not just before. "I parallelized the slow
part" is not "it's fast now" — measure the phases again and find what's serial now.
Spawning one short-lived helper process per item (awk/sed/grep in a loop) is a classic
hidden serial cost; batch the items into one invocation before reaching for more cores.

---

## 4. Auto-sizing the pool — keeping the coder out of the loop

No `-jobs` flag. The suite detects the host's CPU count and **leaves 4 cores free** so
an interactive machine stays responsive while the suite runs:

```tcl
proc test_njobs {} {
  set n 0
  if {![catch {exec nproc} out]}                    { set n [string trim $out] }
  if {$n <= 0 && ![catch {exec getconf _NPROCESSORS_ONLN} out]} { set n [string trim $out] }
  if {![string is integer -strict $n] || $n <= 0}   { set n 1 }
  set j [expr {$n - 4}]
  if {$j < 1} { set j 1 }    ;# never drop below 1
  return $j
}
```

`nproc` (coreutils) is primary; `getconf _NPROCESSORS_ONLN` is the fallback; a hard
floor of 1 means it still *works* (just serially) on a tiny or exotic host. On the
14-core dev box this yields **10 jobs**.

**Lesson:** "keep the human out of the loop" means *derive* the knob, don't *ask* for
it — but always derive it defensively (probe, fall back, floor) so a missing tool
degrades to "slower," never "broken."

---

## 5. What is intentionally NOT changed

- **Golden semantics.** `print_results`, `comp_file`, `cleanup_debug_file`, the gold
  directory layout, and the file *names* compared are all untouched. Only *dispatch*
  changed.
- **Walk order.** The plan phase walks with the same `lsort`/recursion as before, so
  `pathlist` — and therefore the numbered log and any collision's winner — is
  identical to the sequential run.
- **Flags.** Each `xschem` invocation keeps its original flags
  (`-q --nogui -r -d 1`, the `-V/-w/-t/-s` netlist options, `-o`, `-n`).

This is what lets you trust the speedup: if the suite was green before and is green
after, it's because the *same comparisons ran on the same outputs* — just produced ~10×
faster.

---

## 6. Verifying the parallel suite is honest

Speed that comes from *skipping* work is a regression, not an optimization. Confirm the
parallel run still does everything:

1. **Count outputs.** `results/` and the `pathlist` length must match the sequential
   run's. Fewer files = jobs silently dropped.
2. **Sabotage one unit.** Break a single schematic (or point one job at a missing file)
   and confirm exactly one `FATAL` / `FAIL` appears — proves the per-job status channel
   and collation actually observe each job.
3. **Diff the logs.** `create_save.log` / `open_close.log` / `netlisting.log` should be
   identical (modulo the cosmetic `$i.` numbering if order ever shifts) to a known-good
   sequential run.
4. **Race check.** Run the suite 2–3× and diff results between runs — any difference
   means an isolation leak (a shared dir or name slipped through).

See `doc/claude/suggestions/green_but_hollow_tests.md` for why a green suite alone proves
nothing about whether the changed path ran.
