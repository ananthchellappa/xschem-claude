# Dossier: salvaging a run that is stopped — what batch mode can and cannot keep

**Reader:** the crew that implements ⚖ R1's answer, and anyone who later asks why ASE-L
keeps `-b`.

**Scope:** the user has ruled R1 = **Option A** — keep `ngspice -b` in this batch, `-p`
deferred — and has added **always-salvage** as a plan-level requirement, with a warning
wherever a Stop would still discard work. R1's write-up assumed batch mode cannot salvage.
It can. This dossier is the measured basis for that, and the list of everything the quick
pass got wrong on the way.

**Anchors.** Bare `src/…` paths are `/home/analog/dev/ngspice/…`; `ase.tcl` is
`/home/analog/dev/xschem-claude/src/ase.tcl`. Functions are cited by name, not by line
number — both trees are moving under this work.

**MEASURED** marks something run here, on 2026-09-10, against
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (banner `ngspice-46+`, build of
2026-09-03, `git describe = ngspice-46-419-gccebdf2a2`). **SOURCE** marks something read
in that tree here. Scratch decks and captured output live in this session's scratchpad;
nothing in either repository was modified, and the one directory used outside `/tmp`
(`~/.cache/ase_salvage_probe`, for the ext4 timings) was removed afterwards.

**Reference deck** for everything below unless stated otherwise — an RC driven by a 1 kHz
sine, four vectors in the transient plot (`time`, `v(in)`, `v(out)`, `i(v1)`), so a row is
32 bytes:

```
V1 in 0 dc 0 sin(0 1 1k)
R1 in out 1k
C1 out 0 1u
```

`tran 10n 80m` → 8,000,008 points, 256 MB, 7.84 s. `tran 10n 8m` → 800,008 points,
25.6 MB, 0.82 s. Both used throughout; the short one wherever a hundred repetitions were
needed.

---

## 0. Executive summary

**Salvage in batch mode is real, and it is route S2 — `stop` / `resume` checkpointing —
not route S1.** The recipe below survives a `kill -9` at any instant and costs a
predictable, measurable amount. But five of the quick pass's load-bearing statements were
wrong, and each of them is the kind of wrong that ships:

1. **The quick pass's own S2 deck does not resume.** `stop when` is **not disarmed when it
   fires** (MEASURED, §3.1). Its `resume` advanced the run by exactly **one point** and
   stopped again. That deck simulates 12.5 % of what it was asked for and exits **rc 0**.
   The plan would have shipped a checkpoint loop that silently truncates every run.
2. **`stop when time > X` changes the answer; `stop after N` does not.** `com_stop` calls
   `CKTsetBreak()` for a time condition, forcing a timepoint (SOURCE + MEASURED, §3.2). One
   time-checkpoint costs 3 extra rows and a different timestep grid. 100 `stop after`
   checkpoints produce a rawfile body whose **sha256 is identical** to the unchecked run's.
3. **Accumulate-and-overwrite holds — but ASE-L's deck sets `appendwrite`, which turns it
   into accumulate-and-STACK.** 3 checkpoints + the final write to one path produced **four
   plots** totalling 64,001,536 bytes where one plot is 25,600,541 (MEASURED, §3.3). ASE-L
   reads results *by plot name*; naive checkpointing into the results file breaks readback
   and grows the file quadratically.
4. **Route S1 does not merely lose the file — `-r` DELETES the path.** On a `.control`
   deck, the trailing `ft_dorun(ft_rawfile)` in batch reaches `dosim()`, which opens the
   `-r` path `"wb"`, writes nothing, and `unlink()`s it. MEASURED: a good rawfile written by the block's own `write`
   to that path was **gone** at exit, rc 0 (§2.4).
5. **The S1 header repair is a two-step recipe, not one.** Patching `No. Points:` is not
   enough: a truncated file usually ends mid-row, and any leftover byte makes ngspice's
   loader abort the **whole file** — `no data read`. The partial row must be truncated too.
   The quick pass never saw it because its 4-variable deck has a 32-byte row, and 32
   divides stdio's buffer; a 3-variable deck tore in 2 of 3 tries (§2.3).

Three things the quick pass did not look for at all:

6. **A kill during a checkpoint write leaves a torn file that ngspice refuses entirely**, and
   one of five kills landed in the `fopen(…, "wb")` window and left a **0-byte** file where the
   previous good checkpoint had been (MEASURED, §4.3). One hit in five is not a rate — a later
   sitting saw 0 in 5 — but it is what makes tmp+rename mandatory rather than tidy, because
   that failure destroys the **fallback** and not the new file. The fix is
   `write <path>.tmp` + `shell mv`; verified kill-safe 6/6, and verified that ngspice has no
   rename primitive of its own (§4.4).
7. **A stop armed for one analysis leaks into the next one in the same block.** `stop after
   200000` armed once truncated both the `tran` **and** the following `ac`, rc 0. A
   `stop when time` left armed during an `ac` wrote **600,045** error lines and a **15.6 MB**
   log (§3.5). ASE-L runs op/dc/ac/tran in one block; `delete all` between analyses is
   mandatory.
8. **`ngspice -b -r` corrupts its own output above 99,999,999 points** — an upstream defect,
   MEASURED end to end (§2.5). `fileInit()` reserves 8 characters for the count and
   `fileEnd()` writes `%d`; a 9-digit count eats the newline. A 101-second, 3.2 GB run
   produced a file ngspice will not load.

And one number that matters to how R1 is written down: **abort latency in batch is at worst a
few milliseconds, SIGTERM and SIGKILL indistinguishable** (MEASURED, §4.2) — at or below the
"sub-5 ms" figure `evidence/builds.md` credits to `-p`. What `-p` buys is not a *faster* abort.
It is a **non-destructive** one. Say that, not the other thing (§6).

---

## 1. Scorecard against the quick pass

| quick-pass claim | verdict | measured here |
|---|---|---|
| S1: `-r` is written incrementally | **holds** | 133,128,473 bytes on disk 4 s into a 7.84 s run |
| S1: header says `No. Points: 0` until the end | **holds** | placeholder + `fileEnd()` back-patch, SOURCE and MEASURED |
| S1: `rows = body / (nvars*8)`, 16 for complex | **holds** | and generalises to complex and multi-plot (§2.6) |
| S1: repair = rewrite the `No. Points:` line | **incomplete** | must also truncate the partial trailing row (§2.3) |
| S1: 8.2 s / 256,000,554 B / 132,555,050 B / 4,142,336 pts / t=0.0414233 | **holds, ±** | 7.84 s / 256,000,537 B / 133,128,473 B / 4,160,256 pts / t=0.04160248. Byte counts differ only because the header carries the deck's title line; the rest is run-to-run variation |
| S1 catch: `-r` "produced NO FILE AT ALL" on a `.control` deck | **understated** | it creates the path `"wb"` and then `unlink()`s it, destroying whatever was there (§2.4) |
| S2: `stop when` checkpointing works in batch | **holds** | `1 : condition met`, AFTER-TRAN / AFTER-WRITE / AFTER-RESUME, 32,000,573 B = 1,000,009 points |
| S2: "the transient halted, the write ran, and **resume continued**" | **WRONG** | resume advanced 1 point and re-fired; the run ended at 12.5 %, rc 0 (§3.1) |
| S2: the in-memory plot accumulates, so overwriting the same path is enough | **holds, with a killer caveat** | prefix property verified byte-exactly — but `set appendwrite`, which ASE-L emits, stacks plots instead (§3.3) |
| S2: "no header repair" | **holds for a clean checkpoint** | but a *killed* checkpoint needs the same repair, in the over-claiming direction (§4.3) |
| S2: "a Stop costs at most one checkpoint interval" | **holds** | plus, without tmp+rename, possibly the checkpoint itself (§4.3) |
| S2: the interval is in simulated time, so the GUI must choose it | **half right** | in simulated time only for `stop when`, which perturbs. The safe primitive counts **points** (§3.2) |
| S3: batch installs no signal handlers, so SIGINT is fatal; no benefit traded away | **holds** | SOURCE `main.c`; and *every* signal is fatal, not just SIGINT (§4.1) |

⚠ **And one correction against THIS dossier, applied 2026-09-10 in the amendment pass that
carried it into the plan.** §3.8's recipe printed `let ckdone = 0` **after** the `tran`, which
is the very trap §3.9a documents: the counter lands in `tran1` and is written into every file
the loop produces. The deck as first published emitted `No. Variables: 5` with a
`ckdone notype dims=1` column beside time and the circuit quantities, in the checkpoint **and**
in the results file — so the "byte-identical to an unchecked run" property this dossier
measured on §3.2's plain decks did not hold for the recipe it printed. §3.8's own byte count,
192,000,311 for a 4,800,000-point plot, was 40 bytes a row and said so. The counter is now
created with the other two, before the first analysis; re-measured, `No. Variables: 4` and the
final body's sha256 matches the unchecked run's. **Three other numbers moved in the same pass**
— abort latency (§4.2), the checkpoint cost table (§3.7) and the `shell mv` cost (§3.7) — none
of which changes a conclusion.

---

## 2. Route S1 — `ngspice -b -r` writes incrementally

### 2.1 Reproduction

MEASURED. `ngspice -b -r out.raw deck.cir` on the dot-card deck (`.tran 10n 80m`):

| | |
|---|---|
| run to completion | 7.84 s wall, 256,000,537 bytes, `No. Points: 8000008` |
| SIGINT at 4 s | rc 130, **133,128,473 bytes already on disk**, `No. Points: 0` |
| repaired and loaded | 4,160,256 points, `maximum(time)` = **4.160248e-02** of the 0.08 s run |

The incremental write is real: 52 % of the file is on disk at 51 % of the run.

### 2.2 Why the header lies, and how ngspice fixes it

SOURCE, `src/frontend/outitf.c`. `fileInit()` writes the field and remembers where it is:

```c
    sprintf(buf, "No. Points: ");
    ...
    if (run->fp == stdout || (run->pointPos = ftell(run->fp)) <= 0)
        run->pointPos = (long) n;
    fprintf(run->fp, "0       \n"); /* Save 8 spaces here. */
```

`fileEnd()` — whose own comment is *"Here's the hack... Run back and fill in the number of
points"* — seeks back to `pointPos` and writes `run->pointCount` with `%d`. Kill the process
and `fileEnd()` never runs, so the placeholder stands. Every byte of data before it is
valid.

### 2.3 The repair recipe — and the step the quick pass missed

The arithmetic is as stated: `rows = floor(body_bytes / stride)`, `stride = No. Variables ×
8`, ×16 for `Flags: complex`, body starting immediately after `Binary:\n`. **But the file
usually does not end on a row boundary**, and the leftover bytes are fatal.

MEASURED, 3-variable deck (`V1 in 0 sin(...)`, `R1 in 0 1k`, stride 24), three SIGINTs at
random times:

| run | rows recovered | leftover bytes |
|---|---|---|
| 1 | 1,710,421 | **8** |
| 2 | 1,191,594 | **16** |
| 3 | 1,783,808 | 0 |

Two in three. The quick pass's deck has stride 32, and 32 divides stdio's 4096-byte buffer
exactly, so its truncation always landed on a row boundary and the trap was invisible.

MEASURED, what happens if you skip the truncation: ngspice's loader reads the declared rows,
finds text where a new plot header should be, and gives up on **the entire file** —

```
Error: strange line in rawfile:
  load aborted.
no data read.
```

Not "the last row is dropped". **Nothing is recovered.** So the recipe is two steps:

> 1. `No. Points:` ← `floor(body / stride)`, written into the reserved field.
> 2. `truncate` the file to `body_start + rows × stride`.

Both are in-place; no copy of the body is needed. The reserved field is 8 characters
(`"0       \n"`), which is also the cap — see §2.5.

### 2.4 The catch, sharpened: `-r` on a `.control` deck DELETES the path

The quick pass said `-r` "produced NO FILE AT ALL". True, and worse.

SOURCE, `src/main.c`, batch arm: when `rflag` is set, `ft_dorun(ft_rawfile)` is called
**unconditionally**, after the deck has already been sourced — including after a `.control`
block ran the whole analysis. SOURCE, `src/frontend/runcoms.c` — ⚠ **the behaviour is in
`dosim()`, not in `ft_dorun()`**, which is a four-line wrapper doing nothing but
`return dosim("run", &wl)`; grep the wrapper and you find no `fopen`, no `unlink` and no `err`
mapping, and conclude this is false. `dosim()` opens the path before running:

```c
        else { /* binary */
            if ((rawfileFp = fopen(wl->wl_word, "wb")) == NULL) {
```

— and on the way out:

```c
    if (rawfileFp) {
        if (ftell(rawfileFp) == 0) {
            (void) fclose(rawfileFp);
            if (wl) {
                (void) unlink(wl->wl_word);
            }
        }
```

With no dot-card analysis left to run, nothing is written, `ftell` is 0, and the path is
unlinked.

MEASURED. A 32-byte file `victim.raw`; a deck whose `.control` block runs `tran` and
`write victim.raw`; invoked as `ngspice -b -r victim.raw deck.cir`. The log prints
`binary raw file "…victim.raw"` **twice** — once for the block's own write, once for the
`-r` open. At exit: `ls: cannot access 'victim.raw': No such file or directory`, **rc 0**.

So `-r` against an ASE-L-shaped deck is not inert. It is a destructor pointed at whatever
path you name. If the plan ever adds `-r` to `run_cmd` for progress or for a fallback
rawfile, it must point at a path nothing else owns.

### 2.5 The 8-character field: `-b -r` corrupts its own output above 99,999,999 points

`fileInit()` reserves 8 characters; `fileEnd()` writes `%d` with no width. A 9-digit count
overwrites the newline.

MEASURED, `.tran 1n 100m` with `-r`, run to completion: 101.075 s, 3,200,000,569 bytes, and
stdout's own `No. of Data Rows : 100000008`. The header on disk:

```
No. Variables: 4$
No. Points: 100000008Variables:$
	0	time	time$
```

ngspice will not load what ngspice just wrote:

```
Error: strange line in rawfile:
  	0	time	time
  load aborted.
no data read.
```

Exit status 0. Two minutes of simulation, 3.2 GB, silently unreadable.

MEASURED recovery, and it needs no copy of the 3.2 GB body: overwrite the first 8 digits
with `99999999` and the 9th digit byte with `\n`, then truncate to
`body_start + 99999999 × stride`. The file then loads — 99,999,999 points, `maximum(time)`
= 9.999999e-02. **Nine points lost out of 100,000,008.**

This is an upstream ngspice defect and belongs in `doc/codex/issues/` in that tree. For this
plan it is a boundary on route S1 and a reason the plan should not lean on `-r`.

### 2.6 The repair generalises — complex and multi-plot

MEASURED, complex: `.ac dec 2000000 1 1e6` with `-r`, SIGINT at 3 s → 437,469,491 bytes,
`Flags: complex`, `No. Variables: 4`, stride 64. Patched `0 → 6,835,456`; loads; four
complex vectors 6,835,456 long; `frequency` reaching 2616.541 Hz of the 1 MHz sweep.

MEASURED, multi-plot: `.op` + `.ac dec 20000 1 1e6` + `.tran 10n 80m` in one deck with `-r`,
SIGINT at 4 s → 136,078,836 bytes holding three plots. Note the **order on disk is `ac`,
`op`, `tran`** — ngspice's own dot-card execution order, not the deck's. Only the last plot
is short; the first two carry correct counts and must be left alone. Repaired
(`0 → 4,012,416` on the transient only) and loaded: `const ac1 op1 tran1`.

So one repair tool covers all four shapes the tree can produce: real, complex, single-plot,
multi-plot — **and the torn-write case in §4.3**, which fails in the opposite direction.
Worth keeping as a last-ditch recovery utility even though route S1 itself is not adopted.

---

## 3. Route S2 — `stop` / `resume` checkpointing. This is the route.

### 3.1 The quick pass's deck reproduces — and its `resume` is a no-op

MEASURED, the deck exactly as the quick pass wrote it. Everything it reported is there:
`1 : condition met: stop  when time > 0.01`, then `AFTER-TRAN`, `AFTER-WRITE`,
`AFTER-RESUME`, and `ck1.raw` at 32,000,573 bytes — a real partial plot, `No. Points:
1000009`.

What it did not report: **wall clock 1.24 s**, against 7.84 s for the same `tran 10n 80m`
unchecked. The run did not finish.

MEASURED, instrumented: after the `tran`, `length(time)` = 1,000,009 and `status` prints

```
1    stop when time > 0.01
```

— **still armed**. `resume` runs one timestep, the condition `time > 0.01` is satisfied
again immediately, and it stops. `length(time)` after the resume: **1,000,010**. One point.

The deck then falls off the end of the `.control` block and exits **rc 0**. Nothing in
`sim_status`, nothing in the exit status, and nothing in stdout says the run covered 12.5 %
of what was asked. The only tells are on **stderr**: a second `condition met` line and
`simulation interrupted`, both easy to read as the checkpoint working as designed.

A checkpoint loop written from the quick pass's deck would truncate every long run in ASE-L
and report success. This is the single most important correction in this dossier.

### 3.2 `stop when` vs `stop after` — only one of them is safe

SOURCE, `src/frontend/breakp.c`. `ft_bpcheck()` is called from `OUTpData()` (and the two
interpolating writers) as `ft_bpcheck(run->runPlot, run->pointCount)` — so the "iteration"
a `stop after` counts is **the written point count**, and its test is an equality:

```c
            case DB_STOPAFTER:
                if (iteration == dt->db_iteration)
```

An equality cannot recur inside one analysis, so a `stop after` fires exactly once per
analysis without being deleted. Neither kind is ever removed from the list — `status` still
lists a fired `stop after` — but only `stop when` can re-fire.

`com_stop()` treats a time condition specially:

```c
        /* If com_stop is called after tran simulation has already started, set a breakpoint
           if not in the past */
        if ((thisone->db_type == DB_STOPWHEN) && cieq(thisone->db_nodename1, "time")) {
            if (thisone->db_value2 > ft_curckt->ci_ckt->CKTtime) {
                CKTsetBreak(ft_curckt->ci_ckt, thisone->db_value2);
```

That is a real breakpoint handed to the integrator, and it forces a timepoint.

MEASURED, `tran 10n 8m`, bodies compared byte for byte against the unchecked run:

| checkpoint scheme | final rows | body sha256 vs unchecked |
|---|---|---|
| none | 800,008 | — |
| 3 × `stop after` | 800,008 | **identical** |
| 100 × `stop after` | 800,008 | **identical** |
| 1 × `stop when time` | 800,011 | different |
| 3 × `stop when time` | 800,017 | different |

`stop when time` costs **3 extra rows per checkpoint** and a different timestep grid from
the first checkpoint onward — the trajectory shows the forced landing, `t = 2.000000000000e-03`
exactly, where the unchecked run steps straight past it. The *physics* is unharmed: at the
timepoints the two runs share, `max |Δv(out)| = 4.7e-13`. But the point count and the bytes
are not the same, and anything downstream that compares them — a golden, a regression, a
diff of two campaign shards — sees a difference that the user did not ask for.

**Rule for the plan: checkpoint with `stop after <points>`. Never with `stop when time`.**
The cost is that the interval is expressed in points, not in simulated time; §3.7 turns that
into a GUI-facing number.

### 3.3 Accumulate-and-overwrite — verified, and what `appendwrite` does to it

MEASURED, three `stop after` checkpoints on `tran 10n 8m`, each `write` to its own path:

| file | body bytes | rows | is an exact prefix of the final body? |
|---|---|---|---|
| checkpoint 1 | 6,400,000 | 200,000 | **yes** |
| checkpoint 2 | 12,800,000 | 400,000 | **yes** |
| checkpoint 3 | 19,200,000 | 600,000 | **yes** |
| final | 25,600,256 | 800,008 | (sha256 = unchecked run) |

So the claim holds in its strongest form: checkpoint *k* is not "the newest segment", it is
everything from t = 0, byte for byte, and a later checkpoint written over an earlier one at
the same path loses nothing.

**But `render_deck` emits `set appendwrite`** (`ase.tcl`, the analysis loop; the reason is
issue 0929 — one results file holding one plot per analysis). Under `appendwrite`, `write`
to an existing path **appends a plot**.

MEASURED, ASE-L's shape — `set appendwrite`, three checkpoints and the final write, all to
one path:

```
No. Points: 200000
No. Points: 400000
No. Points: 600000
No. Points: 800008
```

Four stacked plots, **64,001,536 bytes** where the single plot is 25,600,541. The growth is
quadratic in the checkpoint count — total ≈ (N/2 + 1) × final size — and ASE-L reads results
*by plot name*, so `tran1` would no longer be the run's answer.

MEASURED fix, and it works mid-block: `unset appendwrite` around the checkpoint write, `set
appendwrite` after it, and **the checkpoint goes to its own path**, not the results file.
One plot in the checkpoint file, one plot per analysis in the results file, both correct.

### 3.4 Which analyses can be checkpointed

`ft_bpcheck()` is called from `OUTpData()`, the generic per-point output hook, so the stop
machinery is not transient-specific. MEASURED:

| analysis | `stop when` | `stop after N` | `resume` | notes |
|---|---|---|---|---|
| `tran` | yes (`time > x`) | yes | yes | the reference case |
| `dc` | yes (`v(in) > 0.5` fired at 500,002 pts) | yes | yes | `stop after` + resume → 1,000,000 pts, same as unchecked |
| `ac` | yes (`frequency > 1000` fired at 300,002 pts) | yes | yes | |
| `op` | n/a | fires at 1 point | n/a | single point; nothing to salvage |
| `noise` | — | yes | yes | **see below** |
| `disto` | — | yes, **once per pass** | yes | two `condition met` lines for one armed stop |

**`noise` is the one that bites.** MEASURED: an unchecked `noise v(out) V1 dec 100000 1 1e6`
leaves `noise1 noise2`. Stopped mid-run it leaves **`noise1` only**; `resume` then produces
`noise2`. So a checkpoint taken during a `noise` is not a short plot — it is an **incomplete
plot set**, missing the integrated-noise plot entirely. `disto` has the same two-plot shape.
This is the same invariant `evidence/ase-deck.md` §7.4 flagged ("one analysis produces one
plot … is false for `noise` and `disto`"), now with a second way to break it: the GUI must
not present a salvaged `noise`/`disto` as merely truncated.

### 3.5 One block, many analyses: the leak and the log bomb

ASE-L renders **one** `.control` block with op/dc/ac/tran in it. A stop armed for one of them
is armed for all of them.

MEASURED, `stop after 200000` armed once, then `op`, `tran`, `ac`:

```
1 : condition met: stop  after 200000
tran simulation interrupted
nt = 2.000000e+05
 : condition met: stop  after 200000
ac simulation interrupted
na = 2.000000e+05
```

The `ac` was truncated to 200,000 of its 600,001 points. **rc 0.** `run->pointCount` restarts
per analysis, so the equality is satisfied again.

MEASURED, `stop when time > 0.002` armed once, then `op`, `tran`, `ac`: the tran stops
correctly; the `ac` then evaluates a condition on a vector that does not exist in its plot,
once per frequency point —

```
Error: time: no such node
```

**600,045 of them, a 15.6 MB log**, and the `ac` runs to completion anyway. rc 0. ASE-L pipes
this into `<cell>_ase.log`.

**Rule: `delete all` before the next analysis, always.** MEASURED that it works and that a
final `delete all` + `resume` lets the run finish clean.

### 3.6 The `sim_status` guard, `remzerovec`, and the exit status

MEASURED, ASE-L's guard verbatim after a stopped `tran` with no resume:

```
tran simulation interrupted          <- stderr, from dosim() in runcoms.c
SIM-STATUS-IS 0
REACHED-END
```

`$sim_status` is **0**. Neither `NO-SIM-STATUS` nor `RUN-FAILED` printed, the `write` ran, the
deck reached its end, **rc 0**, and a 200,000-point rawfile was produced where 800,008 was
asked for.

SOURCE: `dosim()` — which `ft_dorun()` is a four-line wrapper over — maps `err == 1` to
*"simulation interrupted"* and then sets `err = 0` —
an interrupted run is deliberately not an error. That is the right call for `-p`, where the
user chose to stop. In `-b` it means **ASE-L's existing guard cannot tell a completed run from
a checkpointed one**, and neither can the exit status.

Consequence for the plan: completeness needs its own marker. The only in-band tells are the
stderr lines `N : condition met: stop …` (`breakp.c`, `ft_bpcheck()`) and `<what> simulation
interrupted` (`runcoms.c`, `dosim()`), plus the absence of whatever the deck echoes after
the last analysis. A deck-emitted completion echo is the cheap, reliable marker; the crew
should add one and not infer completeness from rc.

MEASURED, `remzerovec` is unaffected: with `.options savecurrents`, a stopped transient plot
holds `@c1[i]`, `@r1[i]`, `in`, `out`, `time`, `v1#branch`, **all 200,000 long**. `remzerovec`
removes nothing, and the write succeeds (9,600,353 bytes). The zero-length-vector condition
`remzerovec` exists for is not created by a stop.

### 3.7 What a checkpoint costs

MEASURED, `tran 10n 8m` (800,008 points, 25.6 MB final), checkpoints spread evenly, three
runs each, wall seconds. Checkpoint k writes k/(N+1) of the final size, so N checkpoints
write **N/2 × final size** of extra bytes.

| N | extra bytes written | tmpfs | ext4 | overhead |
|---|---|---|---|---|
| 0 | 0 | 0.81 / 0.86 / 0.81 | 0.83 / 0.83 / 0.80 | — |
| 4 | 2 × 25.6 MB | 1.01 / 0.92 / 0.97 | 0.96 / 0.97 / 0.91 | +0.15 s (+18 %) |
| 20 | 10 × 25.6 MB | 1.42 / 1.46 / 1.44 | 1.42 / 1.44 / 1.44 | +0.61 s (+75 %) |
| 100 | 50 × 25.6 MB | 3.89 / 3.95 / 3.94 | 4.32 / 3.90 / 3.94 | +3.1 s (+380 %) |

The three points are linear in bytes, and tmpfs and ext4 are the same, because SOURCE: there
is **no `fsync` anywhere in `rawfile.c` or `outitf.c`** — only `fflush`. The measured
throughput is page-cache throughput.

⚠ **The model reproduces; the constants do not.** Two later sittings on the same machine, same
reference deck, best of five:

| N | this table | 2nd sitting | 3rd sitting |
|---|---|---|---|
| 4 | +18 % | +8 % | +21 % |
| 20 | +75 % | +60 % | +62 % |
| 100 | +380 % | +288 % | +299 % |

Implied B moved from ≈ 410 MB/s here to 510–540 MB/s in both later sittings — i.e. **above**
what this section first called a ceiling. **B is page-cache throughput on one machine and it
moved ±30 % between sittings; it is a planning constant, not a bound.** Quote the span, not one
row. What survives untouched is the shape (extra bytes = N/2 × final size, linear in bytes) and
therefore everything §3.7 derives from it. (It also means a *machine* crash, as opposed to a
kill, can lose a checkpoint that `write` reported as finished.)

`shell mv` for the atomic rename (§4.4) adds **≈ 4 ms per checkpoint** — two later A/B sittings,
twenty checkpoints each, measured 3.7 ms and 3.9 ms. An earlier pass recorded ≈ 12 ms; that
figure is three times too large and is immaterial at any plausible N either way.

**The rule for choosing N.** Two costs pull against each other: a Stop at a uniformly random
moment wastes `T/(2(N+1))` of simulated work, and the checkpoints themselves cost
`N × S / (2B)` where S is the final rawfile size and B the write throughput. Minimising the
sum gives

> **N + 1 = sqrt(T × B / S)**

with T the expected runtime in seconds, S the expected rawfile size, B ≈ 400 MB/s.

Worked, MEASURED-calibrated: the reference deck (T = 0.82 s, S = 25.6 MB) gives N + 1 = 3.6,
i.e. **N = 3**, and the table shows N = 4 costing 18 %. A realistic ASE-L job — a ten-minute
transistor-level transient producing a 200 MB rawfile — gives N + 1 = sqrt(600 × 400 / 200)
= 35, i.e. **a checkpoint every ~17 s, costing 8.3 s: 1.4 %**. The formula scales the right
way because checkpoint cost depends only on the rawfile, never on how hard the circuit is to
solve, while the value of a checkpoint scales with the runtime.

**Defensible default: N = 4** (a checkpoint every 20 % of the run) whenever the GUI cannot
estimate T and S, clamped to `[2, 50]`. It is right for short runs, cheap in absolute terms
for long ones, and it bounds the worst-case loss at 20 % — which is the number the warning
in §5 has to quote.

Converting N to `stop after` thresholds needs a point-count estimate. For a `tran tstep
tstop` the measured count was `tstop/tstep + 8` (800,008 for `10n`/`8m`; 8,000,008 for
`10n`/`80m`), so `k × tstop/(tstep × (N+1))` is a good threshold. Where the count is not
predictable, the loop can read `length(time)` at the first checkpoint and re-arm from the
measured value — §3.8 does exactly that, and §3.9 is why it is harder than it looks.

### 3.8 The recipe

MEASURED end to end: ASE-L's deck shape (one `.control` block, `set appendwrite`, `op` then
`ac` then a checkpointed `tran`, guard + `remzerovec` + `write` per analysis), killed with
SIGTERM 6 s in.

```
.control
set appendwrite
let ckstep = 400000          <- ALL THREE before the first analysis: see §3.9a.
let cknext  = ckstep            A `let` made after `tran` lands in tran1 and is
let ckdone  = 0                 WRITTEN INTO every file the loop writes.
set  cktgt  = $&cknext       <- and go through a `set` variable: see §3.9b

op
<guard>
remzerovec
write <rundir>/<cell>_ase.raw

ac dec 1000 1 1e6
<guard>
remzerovec
write <rundir>/<cell>_ase.raw

stop after $cktgt
tran 10n 80m
while ckdone = 0
  unset appendwrite
  remzerovec
  write <rundir>/<cell>_ase.raw.ckpt.tmp
  shell mv -f <rundir>/<cell>_ase.raw.ckpt.tmp <rundir>/<cell>_ase.raw.ckpt
  set appendwrite
  echo CKPT-DONE $cktgt
  let cknext = cknext + ckstep
  set cktgt = $&cknext
  if cknext < <total>
    stop after $cktgt
    resume
  else
    let ckdone = 1
    delete all
    resume
  end
end
<guard>
remzerovec
write <rundir>/<cell>_ase.raw
echo ASE-RUN-COMPLETE
.endc
```

MEASURED, that deck run verbatim against `tran 10n 80m` with `ckstep = 1600000` and killed
with SIGTERM at 6 s — **rc 143**:

* the log carries `CKPT-DONE 1600000`, `CKPT-DONE 3200000`, `CKPT-DONE 4800000` and **no**
  `Syntax error`, **no** `no such variable`, **no** `RUN-FAILED`, **no** `NO-SIM-STATUS`;
* `<cell>_ase.raw` is 384,650 bytes holding the completed `op` (1 point) and `ac` (6,001
  points) plots, **intact** — `load` gives `const op1 ac1`;
* `<cell>_ase.raw.ckpt` is **153,600,270 bytes** holding **one** Transient Analysis plot of
  4,800,000 points; `load` gives `const tran1` and `maximum(time)` = **4.799992e-02** of the
  0.08 s asked for — 60 % of the run kept out of a hard kill. ⚠ **Check that number against
  the arithmetic before quoting it**: 4,800,000 rows × 4 vectors × 8 bytes = 153,600,000, plus
  a header of a few hundred bytes whose length follows the deck's title line. This paragraph
  read **192,000,311** until 2026-09-10 — 40 bytes a row, i.e. **five** vectors — which was the
  arithmetic proof that the recipe above was writing `ckdone` into the file, and nobody read it;
* whether a `.tmp` is left behind depends on where the kill lands. The run above left none;
  a re-run killed during a checkpoint write left a torn 165,990,400-byte `.tmp` beside an
  **intact** previous checkpoint, which is the tmp+rename guarantee working (§4.4). The GUI
  sweeps the `.tmp` at the next run either way;
* ⚠ **the per-checkpoint echoes are not a reliable progress signal under a kill.** ngspice's
  stdout is block-buffered when redirected to a file, so the last echoes before a SIGTERM can
  die in the buffer: the re-run above completed and renamed its third checkpoint but its log
  carries only the first two `CKPT-DONE` lines. The *completion* marker is unaffected, because
  what the GUI reads is its **absence**;
* `ASE-RUN-COMPLETE` absent from the log — which is what tells the GUI the run was aborted,
  because rc and `sim_status` will not (§3.6).

Note the three thresholds are all above 1,000,000, which is exactly where the `$&` form of
this loop fails silently (§3.9b); the `set` variable route carries them correctly.

Seven properties, each measured — and the first of them holds **only with the counters where
they now are**; with `let ckdone = 0` after the `tran`, as this recipe printed it until
2026-09-10, the final file carries a fifth vector and is not byte-identical to anything:
the final result is byte-identical to an unchecked run (§3.2, re-verified against this deck
after the counter moved — `No. Variables: 4`, final body sha256 `b9836c494d9d52ad`); each checkpoint is a prefix of the final (§3.3); the checkpoint file holds exactly
one plot (§3.3); the results file is never touched by a checkpoint (§3.3); a kill at any
instant leaves the checkpoint loadable (§4.3–4.4); `sim_status` and `remzerovec` are
undisturbed (§3.6); `delete all` before the final `resume` keeps the run from stopping again
(§3.2, §3.5).

### 3.9 Two silent traps in writing that loop

Both were found by writing the recipe wrong first, and both fail with **rc 0**.

**(a) A `let` counter created after an analysis is invisible to the next one.** MEASURED:

```
created a while curplot = const
after op, curplot = op1 ; a = 111
created b while curplot = op1
after tran, curplot = tran1
  a = 111
  b =                        <- Error: &b: no such variable.
  const.a = 111
```

Vectors created before any analysis land in the `const` plot and are visible from every later
plot. Created while `op1`/`ac1` is current, they land there and vanish when `tran1` becomes
current. In the first draft of the recipe the counters sat next to the `tran`, after `op` and
`ac` — so `let cknext = cknext + ckstep` failed with `Error: RHS "cknext + ckstep" invalid`,
the counter never advanced, no further checkpoint was armed, and the deck carried on at rc 0.
**Create the counters at the top of the block, before the first analysis**, or prefix them
with a plot name.

**(b) `stop after $&vec` breaks above 1,000,000 points.** SOURCE: `com_stop()` parses the
`after` argument digit by digit (`if (!isdigit_c(*s)) goto bad;`). MEASURED, how a computed
number reaches the command line:

| value | `$&x` | `set s = $&x` → `$s` |
|---|---|---|
| 7 | `7` | `7` |
| 1500000 | **`1.5E+06`** | `1500000` |
| 1234567 | **`1.23457E+06`** | `1234570` |
| 12345678 | **`1.23457E+07`** | `12345700` |
| 100000000 | **`1E+08`** | `100000000` |

MEASURED consequence: `stop after $&big` with `big = 1200000` prints **`Syntax error parsing
breakpoint specification.`** and arms nothing; the run continues to completion at rc 0 with no
checkpoint. `stop after $sbig` through a `set` variable arms correctly and fires at 1,200,000
points. The `set` route also **rounds to 6 significant figures** (1,234,567 → 1,234,570) — 
harmless for a checkpoint threshold, but the crew should know the threshold is approximate.

This is exactly the regime checkpointing exists for. A checkpoint loop tested only on short
runs passes, and stops checkpointing the moment the run is long enough to matter.

---

## 4. The abort itself

### 4.1 Batch mode handles no signal at all — S3 confirmed, and wider

SOURCE, `src/main.c`. The whole signal block is inside one guard:

```c
    /* Set up signal handling */
    if (!ft_batchmode) {
        /*  Set up interrupt handler  */
        signal(SIGINT, (SIGNAL_FUNCTION) ft_sigintr);
        /* floating point exception  */
        signal(SIGFPE, (SIGNAL_FUNCTION) sigfloat);
#ifdef SIGTSTP
        signal(SIGTSTP, (SIGNAL_FUNCTION) sigstop);
        signal(SIGCONT, (SIGNAL_FUNCTION) sigcont);
#endif
...
    }
```

SIGINT, SIGFPE, SIGTSTP, SIGCONT, SIGTTIN, SIGTTOU — none installed in batch. SIGTERM, SIGHUP
and SIGQUIT are not installed in **any** mode; a grep of the tree finds SIGQUIT only in
`com_shell.c` and `unixcom.c`, where it is saved and restored around a child process.

MEASURED, one signal per row, sent 2 s into the 7.84 s run:

| signal | rc | rawfile | `REACHED-END` |
|---|---|---|---|
| INT | 130 | none | no |
| TERM | 143 | none | no |
| HUP | 129 | none | no |
| QUIT | 131 | none | no |
| USR1 | 138 | none | no |
| USR2 | 140 | none | no |
| PIPE | 141 | none | no |

All fatal at the default disposition, nothing salvaged. The quick pass's S3 reading is
right, including its conclusion: **no benefit is being traded away.** Batch was written for
scripted use where nobody presses Stop.

### 4.2 Latency — and what this does to the `-p` argument

MEASURED, time from `kill` to process exit, three runs each, mid-transient:

| signal | latency |
|---|---|
| SIGTERM | 5.6 / 4.5 / 5.3 ms |
| SIGKILL | 5.0 / 5.2 / 5.5 ms |

⚠ **Those numbers are a moment in a run, not a constant, and two later sittings disagreed with
them and with each other (0.4–0.6 ms; 1.6–2.2 ms). The mechanism is now measured.** Two things
move the figure, and neither is signal delivery:

* **It scales with what the run has accumulated in memory** — the kernel is tearing down an
  address space. MEASURED, SIGKILL into the same deck at three depths, three runs each:
  **0.78–0.85 ms at 24 MB RSS**, **1.83–2.14 ms at 62 MB**, **3.84–5.15 ms at 177 MB**. The
  table above is the deep end of that, which is the honest place to measure it, because a Stop
  a user presses is a Stop on a run worth keeping.
* **A `T0=$(date +%s%N); kill; wait; T1=$(date +%s%N)` harness charges its own two fork/execs
  to ngspice.** MEASURED at one fixed depth: **4.21–4.46 ms the `date` way against 1.83–2.14 ms
  timed parent-side across `waitpid`**, and a bare `date`-to-`date` pair costs 2.05–2.32 ms of
  that. Time it in the parent, around the wait.

So: **a few milliseconds at worst, sub-millisecond on a small run, SIGTERM and SIGKILL
indistinguishable throughout.** The conclusion below is unharmed and strengthened.

`evidence/builds.md` credits `-p` with a "graceful abort measured at under 5 ms". **Batch
already aborts in that time.** SIGTERM and SIGKILL are indistinguishable here because
nothing handles either; the only practical difference is that a wrapper can block SIGTERM
and cannot block SIGKILL.

**What ASE-L should send: SIGTERM first, SIGKILL after a short grace.** Not because ngspice
does anything with SIGTERM — it does not — but because a `shell` child (§4.4) may be running
and because SIGTERM is what a process-group teardown expects. The grace period only needs to
cover a `mv`, so ~200 ms is generous. And because `rename(2)` is atomic in the kernel, even a
kill that lands on the whole process group during the rename leaves either the old file or
the new one, never a mixture.

### 4.3 A kill during a checkpoint write tears the file — and the loader recovers nothing

MEASURED. A deck that finishes a 2,000,008-point transient and then writes the same 64 MB
rawfile 40 times in a `repeat` loop; `kill -9` at a random point inside the loop, five times:

| run | file bytes | header says |
|---|---|---|
| 1 | 64,000,560 (complete) | `No. Points: 2000008` |
| 2 | 27,291,648 | `No. Points: 2000008` |
| 3 | 64,000,560 (complete) | `No. Points: 2000008` |
| 4 | **0** | — |
| 5 | 14,065,664 | `No. Points: 2000008` |

Two failure modes, both destructive:

* **The header over-claims.** SOURCE: `raw_write()` in `rawfile.c` knows the length up front —
  the vector is complete in memory — so it writes `fprintf(fp, "No. Points: %d\n", length)`
  correctly and *then* streams the body. This is the mirror image of §2.2, where `-r`
  under-claims. MEASURED, what ngspice does with such a file:

  ```
  Error: bad rawfile
    point 1727094, var v(out)
    load aborted
  no data read.
  ```

  1.7 million good points on disk, **nothing recovered**, and `load` still returns to the
  prompt with no nonzero status anywhere.
* **The file is empty.** `fopen(path, "wb")` truncates before the first byte is written. Run 4
  caught it in that window: the previous good checkpoint was gone, and there was nothing to
  fall back to. ⚠ **One hit in five is not a rate.** The window is a few hundred microseconds
  inside a ~120 ms write, so where a kill lands in it is timing; a later sitting took five
  kills into the same loop and got five torn-but-non-zero files and no empty one. The
  mechanism is certain from SOURCE, and it is what makes tmp+rename **mandatory rather than
  tidy** — this failure destroys the fallback, not the new file.

MEASURED, the §2.3 repair fixes the first mode: patched `2000008 → 1727094`, truncated the
16 leftover bytes, and the file loads — 1,727,094 points, `maximum(time)` = 1.727086e-02.
Nothing fixes the second.

### 4.4 Write to a temp path and rename — verified, and ngspice cannot do it itself

MEASURED, the same experiment with `write <path>.tmp` + `shell mv -f <path>.tmp <path>`,
six `kill -9`s at random points in the loop:

| run | `safe.raw` | `safe.raw.tmp` | load errors |
|---|---|---|---|
| 1 | 64,000,563 (complete) | — | 0 |
| 2 | 64,000,563 | 63,508,480 (torn) | 0 |
| 3 | 64,000,563 | 6,250,496 (torn) | 0 |
| 4 | 64,000,563 | 48,848,896 (torn) | 0 |
| 5 | 64,000,563 | 30,326,784 (torn) | 0 |
| 6 | 64,000,563 | 9,728,000 (torn) | 0 |

**Six for six.** The damage is confined to the `.tmp`, which the GUI sweeps at the next run.

SOURCE, and this is the part the plan needs stated flatly: **ngspice has no rename, move or
copy primitive.** The command table in `src/frontend/commands.c` (`spcp_coms[]`) offers
`write`, `hardcopy`, `cdump`, `eprvcd`, `fopen`/`fread`/`fclose`, `cd`, `getcwd` — and
`shell`. There is no option on `write` that writes elsewhere and renames. So the atomicity
has to come from `shell mv` in the deck, or from the GUI checkpointing into a path it renames
itself. **It cannot come from ngspice.** `shell mv` costs ≈ 4 ms per checkpoint (§3.7), which
is the cheaper of the two.

---

## 5. What the GUI must say, and when

The requirement is always-salvage, and a warning wherever a Stop still discards work. From
the measurements, that is three distinct statements and they are not interchangeable.

**§5.1** — 1. **Before a run that has no checkpoints at all** — an `op`, a `dc`, a short `ac`, or any
   run where the estimated checkpoint cost is not worth paying: *"Stopping this run discards
   it. ngspice in batch mode writes nothing on a stop."* True, cheap, and it ships before any
   salvage code exists. This is the free warning the ruling asks for.
**§5.2** — 2. **Before a checkpointed run**: *"Stopping loses up to the last N % of the run"* — N being
   `100/(N_ckpt+1)`, i.e. **20 % at the default N = 4**. Plus the I/O the checkpoints cost,
   which §3.7 makes computable: `N/2 × rawfile size / 400 MB/s`. Say both numbers; a user
   choosing an interval is trading exactly one against the other.
**§5.3** — 3. **After a Stop, on the results**: a salvaged rawfile is **not** a completed one, and
   nothing in ngspice's exit status or `sim_status` says so (§3.6). The GUI must mark it —
   from the absence of the deck's completion echo, not from rc — and must say **how far it
   got**, which is `maximum(time)` (or `frequency`, or the sweep variable) of the salvaged
   plot, against what was asked for. For `noise` and `disto` it must additionally say that a
   salvaged run may be **missing a plot**, not merely short (§3.4).

One thing the GUI must *not* do: point `-r` at any path it cares about while the deck has a
`.control` block (§2.4).

---

## 6. What this does to ⚖ R1

The ruling is Option A and this dossier does not reopen it. What it changes is the record.

* **R1's stated cost was wrong.** "`-b` … leaves the only measured capability gap — *stop and
  keep what you have* — permanently open on a single long run" is not true. §3 is that
  capability, in `-b`, on the stock binary, without touching `run_cmd`'s pinned word order.
  The recommendation ("define one run interface now, implement with `-b`, schedule `-p` after
  Stage 10") survives with its cost line corrected.
* **`-p`'s abort advantage is not latency.** §4.2: batch dies in a few milliseconds at worst —
  sub-millisecond on a small run, and the figure scales with the run's resident memory, not
  with the signal — at or below the figure `builds.md` credits to `-p`. What `-p` buys is that
  the abort is
  **non-destructive** — no checkpoint granularity, no torn-file window, no `shell mv`, and the
  data still in the process afterwards. Say that where R1 is recorded; the latency framing
  invites a reader to think the two are close, and on *this* axis they are.
* **`-p` keeps two advantages that §3 does not touch**: the no-circuit capability probe the
  adapter doctrine leans on, and the pre-deck door collapsing to one (`set` before `source`),
  which is what would make R2 moot and delete D19. Neither is about losing work.
* **Always-salvage is affordable now.** §3.8 is a deck-renderer change: extra lines around one
  analysis in `render_deck`'s loop, plus a checkpoint path beside `raw_file`. It touches no
  argv, so none of the six `test_ase_simreg_0931` rows that pin `run_cmd` move. The warning of
  §5.1 is smaller still and can ship in the stage that ships the run panel.
* **What still argues for `-p` after Stage 10** is unchanged and slightly strengthened: §3.9's
  two traps, §3.5's leak, §3.6's blind status guard and §4.3's torn-file window are all
  accidents of doing this from outside the process. They are each individually cheap to
  handle; together they are the reason the second implementation is worth scheduling.

---

## 7. What I did not measure

1. **A nonlinear circuit.** Everything here is an RC. The byte-identity result for `stop after`
   (§3.2) is the one I would most want re-confirmed on a transistor-level deck, because the
   claim is that stopping and resuming does not perturb the integrator's state — measured true
   where the timestep is not LTE-limited. The mechanism (`stop after` never touches
   `CKTsetBreak`) says it should hold; I did not prove it where the stepping is adaptive.
2. **The point-count estimate for `stop after`.** `tstop/tstep + 8` held exactly on this deck.
   A deck with breakpoints (`pulse`, `pwl`), `.options interp`, or a max-step setting will not
   match, and §3.8's loop then re-arms from a wrong base. The adaptive form (read
   `length(time)` at the first checkpoint, re-arm from it) is the fix and I wrote it, but I did
   not exercise it against a deck whose count it could not predict.
3. **`stop`/`resume` on `pss`, `sp`, `pz`, `sens`, `tf`.** `evidence/builds.md` item 3 already
   records that `sens` does not honour `bg_halt` and that `pz` likely cannot be interrupted.
   Those are the analyses where salvage may simply be unavailable, and the GUI needs the list.
4. **`shell` on Windows.** The rename in §4.4 goes through `com_shell`, which on a Windows
   build runs `cmd`. `mv -f` is not a `cmd` builtin. If ASE-L is ever expected to run there,
   the rename has to move into the GUI.
5. **Checkpointing a `dc` or `ac` end to end.** §3.4 shows both stop and resume correctly; I
   did not run the full §3.8 loop against either, and `dc`'s sweep-variable plot may interact
   with the `unset appendwrite` dance differently.
6. **Writeback under pressure.** §3.7's 410 MB/s is page-cache throughput on a machine with
   9 GB free. A checkpointed run whose rawfile approaches RAM will hit dirty-page throttling
   and the cost model will understate. Worth one measurement before the formula is quoted to a
   user as a prediction.
7. **The 9-digit `No. Points:` defect upstream.** §2.5 is measured and reproducible; I did not
   write it up in `doc/codex/issues/` in the ngspice tree, which is where it belongs.
