# 0807 — `xschem annotate_op` destroys the attached OP database on a truncated raw, and reports success

STATUS: **OPEN — attempt 1 implemented, measured, and REVERTED 2026-08-25. RULING SETTLED 2026-08-29** — both halves decided (see the RULING section at the foot; it supersedes §14.1's mechanism), half (1) NOT the way attempt 2 wrote it. The code that ruling implies is follow-up work, NOT YET DONE.
The defect below is still live at HEAD. A fix was written, passed every tier and the
whole sabotage matrix, and was then refuted by the adversary and reverted because it
introduced a worse defect on a shipped route (§7). The reverted diff is kept at
`doc/claude/evidence/0807-attempt1-reverted.patch.txt`; **§11 is binding on the retry.**
FOUND IN: `src/scheduler.c:2411-2417` (the `annotate_op` branch), `src/save.c:1988`
`update_op()`, `ngspice::ngspice_data`.
RELATED: [0685](0685-annotate-op-reuses-a-stale-registry-database-at-the-same-path.md) §4
(which attributes this loss to the reverted workaround, and is **incomplete on this
point**), [0683](0683-annotation-is-reachable-with-no-bound-ase-l-session.md) §7
(refutation 3), [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md).

---

## 1. The defect

`annotate_op` deletes the previously loaded 1-point `op`/`dc` database and
`array unset`s `ngspice::ngspice_data` **before** it attempts to read the new
file. When the read then fails — ngspice mid-rewrite, so the raw is readable but
truncated — nothing replaces what was deleted, and the user's loaded database is
gone.

It then returns `TCL_OK` **with the path string**, so its return value can never
be used as a success test.

## 2. The measurement

Write-up agent, 2026-08-25, `src/xschem` built from the 0688+0683 tree, `--nogui`,
against a 182-byte 1-point op raw truncated to its first 40 bytes:

```
WU| GOOD raw attached: raw loaded=0  v(a)=3.14  switch op=0/1
WU| annotate_op TRUNCATED  rc=0  ret=/…/trunc.raw
WU| AFTER: raw loaded=0/-1  v(a)=1/No raw file loaded  switch op=0/0
WU| ngspice_data entries=0
```

`rc=0` and the returned path are a **lying success**: `raw loaded` went `0` → `-1`,
`raw value v(a) -1` went from `3.14` to a raise, and `ngspice::ngspice_data` is
empty. Three agents on this item reproduced it independently (scout, implement,
adversary). The scout additionally measured that with BOTH a tran waveform db and
an op db attached, the truncated annotate destroys the op db while the tran db
survives, and that in that arrangement `xschem raw switch op` **still answers 1**
over the emptied slot — a lying witness. (In the simpler arrangement above
`raw switch op` answered 0; the witness is unreliable in both directions.)

`/nonexistent.raw` behaves the same way: `raw loaded` −1, `rc` 0.

## 3. Why it matters here, and why 0685 §4 is wrong about it

0685 §4 records the data loss as caused by the reverted `annot_drop_stale`
workaround. It is not: the loss is in the **shipped** command that
`annot_drop_stale` merely called. `annot_drop_stale` **widened** it from `op`/`dc`
to `tran`; it did not create it.

This is the command **both** guarded stock entry points call, and the one ASE-L's
`Results > Annotate` attach arm calls, so it sits inside the annotation feature's
blast radius even though this issue's fix does not.

## 4. What is NOT affected

Issue **0688**'s root-sheet clear, which landed in the same commit, does not go
near this: it writes one int, one Tcl var and one path stamp and never opens a
file. Rows **Y7** and **Y7b** in `tests/headless/test_op_annot.tcl` pin exactly
that, including the truncated-on-disk case — the raw stays in the registry across
the clear and answers `3.14` out of memory.

## 5. The shape of a fix, and the open question now SETTLED by measurement

Read into a scratch database and swap only on success, so a failed read leaves the
previous one intact — the "do not destroy what you cannot replace" rule `save.c`
RULING **D5-1** already states for a different surface. Secondly, the command must
stop returning `TCL_OK` with a path when nothing loaded; a caller has no other way
to tell.

The brief asked how much of a partial read counts as success. **Measured, and the
answer is that today the same condition gets opposite answers depending on the
encoding the simulator chose:**

* **ASCII** truncation is all-or-nothing. Measured at 14 truncation offsets of a
  194-byte op raw and 10 of a 197-byte 5-point tran raw: every short read already
  fails (issue 0213's arm, `save.c` ascii branch).
* **BINARY** truncation *always succeeds*. The binary arm only warns on a short
  `fread` (issue **0299**). A real `/usr/local/bin/ngspice-46+` 1-point op raw
  (277 B) cut to 261 B loads with `v(a)` correct and `v(b)` **fabricated as 0**;
  a hand-built fixture once produced `6.7903865e-315` out of the reused `tmp`
  buffer.

**ngspice writes binary raws by default**, so the user's actual bench case is the
binary one, and it is *not* the "database destroyed" shape at all — it is "the good
database is legitimately replaced by one carrying invented numbers", i.e. invariant
**I3** / RULING **D5-1**'s forbidden case. A swap-only-on-success fix alone does
nothing for it, because the read reports success. **0299 is on this item's critical
path, not adjacent to it.**

`tests/headless/test_op_annot.tcl`'s section-N comment block records the
missing-file half of this in prose, but there has never been a committed row.

## 6. Attempt 1 — what was built (REVERTED, kept for the retry)

Three layers, all of them required; the top one alone does not fix the bench case.

1. **`src/scheduler.c`, the `annotate_op` branch — destroy-then-read became
   detach-then-read-then-dispose.** `extra_rawfile(3, ...)` (which *frees*) replaced
   by `extra_rawfile_detach()` (which does not); `tcleval("array unset
   ngspice::ngspice_data")` **deleted** outright, because `update_op()` unsets and
   rebuilds that array wholly from `xctx->raw` — it was redundant on success and was
   the entire Tcl-side half of the loss on failure. On `res == 1`,
   `extra_rawfile_discard()`; on failure, `extra_rawfile_reattach()` plus one
   `dbg(0)`. `tclsetboolvar("live_cursor2_backannotate", 1)` moved *into* the success
   arm. Last statement of the branch, after `draw()`:
   `Tcl_SetResult(interp, my_itoa(res == 1), TCL_VOLATILE)` with `TCL_OK`.
2. **`src/save.c` — three new primitives** (`extra_rawfile_detach`,
   `_reattach`, `_discard`) plus a factored `extra_raw_room()`, so the registry
   bookkeeping stays in one file. Three externs in `src/xschem.h`.
3. **`src/save.c` — the two readers that make "swap only on success" mean anything.**
   0299's `res = 0; break;` at both binary short-`fread` sites, and 0316's four
   malformed-header aborts stop calling `extra_rawfile(3, NULL, ...)` (the CLEAR-ALL)
   so the reader can no longer wipe the registry from under its caller.

It measured well. Every tier was clean (T1 32/32, T2 PASS, `test_op_annot`
349→366 `--nogui` / 355→372 on `:99`, `test_backannotate_digital` 81 unchanged),
valgrind showed `definitely lost: 0`, and it closed 0316's own 253,152-byte leak.

## 7. Why it was reverted — the regression that refuted it

**The shipped `load_raw` route publishes the PREVIOUS run's numbers and calls it
success.** `src/xschem.tcl:14533 proc load_raw` (reached from `:4244`, the
Simulation menu) does `xschem raw_clear` then `xschem raw_read <file>`. The
`raw_read` verb reads **directly into `xctx->raw`, bypassing the registry**
(`scheduler.c`, `read_rawfile_by_type(f, &xctx->raw, ...)` after an
`extra_rawfile(3, NULL, ...)`), so the database is then **current but
unregistered** — `extra_raw_n == 0`.

`extra_rawfile_detach()` searches only `extra_raw_arr[0 .. extra_raw_n)`, finds
nothing, and returns `NULL`. **No detach happens.** `extra_rawfile(1, ...)` then
runs its base-insert (`if(xctx->raw && xctx->extra_raw_n == 0)`), adopting the live
entry into `arr[0]`, and the rawfile+sim_type dedup immediately matches it and takes
*"already loaded: switch to it"* **with no read at all**.

Reproduced by the write-up agent on the patched tree, independently of the
adversary. `P.raw` is written with 3.14/1.50, read, then **overwritten on the same
path** with 8.00/4.00 as ngspice would on a re-run:

```
WU| step1 raw_read run1   rc=1
WU| step2 annotate SAME  result=<1>  v(a)=3.1399999 v(b)=1.5  ngdata_v(b)=1.5   WANT 8.0/4.0
WU| step3 annotate again result=<1>  v(a)=5.5500002 v(b)=2.22   WANT 5.55/2.22
```

Step 2 returns **`1` — success — while serving the previous run's numbers**, and
publishes the stale value into `ngspice::ngspice_data`, which is the array the
display reads. Step 3 shows it self-heals once the entry is registered: **only the
first annotate after a `raw_read` is affected**, which is exactly why every suite
stayed green.

This is invariant **I3** violated by its literal words — *"not the previous run's
number"* — and it is a **regression**: at HEAD the destroy `extra_rawfile(3,
rawfile, sim_type, ...)` base-inserted that same entry and then **freed** it, so
HEAD's subsequent read was real. The adversary measured the A/B with two real
ngspice-46+ raws: HEAD `v(b)=4` (the current run), patched `v(b)=1.5` (the previous
run).

**A fix that trades "the database is destroyed and the screen goes blank" for "the
schematic shows last run's operating point and reports success" is not a fix for
this issue — it is the same family of defect, moved somewhere harder to see.** Hence
the revert, per the run's status rules (adversary refuted ⇒ F ⇒ revert, commit only
the write-up).

**The gap is about three lines**, in `extra_rawfile_detach()`: when
`extra_raw_n == 0 && xctx->raw` matches the file/type, detach `xctx->raw` **itself**
(`detached = xctx->raw; xctx->raw = NULL;`) rather than returning `NULL`. The
existing single-entry path already shows this is safe: with `n == 0` the read arm's
`if(xctx->extra_raw_n)` restore is skipped and `extra_rawfile_reattach()` supplies
`xctx->raw`, exactly as it does when the last registry entry is detached. **It was
not applied here: the write-up agent may not run `make`, and committing an unbuilt C
change would put source in the tree that no measurement covers.**

## 8. Decisions taken (each with its ladder rung and rejected alternative)

* **Detach-and-restore, not scratch-read-and-adopt** (L2, smallest blast radius):
  the op→dc→tran reads stay byte-identical. *Rejected:* reading into a scratch
  `Raw*` — `read_rawfile_by_type()` refuses any destination other than `&xctx->raw`
  for non-spice types, so `annotate_op f.txt 0 table` would start failing where it
  works today; and `raw_read` on a foreign destination still runs `set_modify(-2)`,
  the Waves-cue repaint and the `graph_flags & 4` backannotate block against the
  **old** `xctx->raw`. *Rejected:* a validating pre-read probe — doubles the I/O and
  puts two readers on one file, the **I1** drift shape.
* **Refuse a short binary point** (L1 / invariant **I3**, seconded by RULING D5-1).
  *Rejected:* 0299's own alternative `raw->npoints[datasets] = p` (keep the points
  actually read) — it buys nothing for a 1-point op raw, and re-creates the
  ascii/binary disagreement in the other direction.
* **Fold in 0316** (L2, and forced by this item's acceptance): the brief requires
  that with a tran db *and* an op db attached a failed annotate destroy **neither**,
  and a raw truncated inside `No. Points:` makes the *reader* wipe the whole
  registry. No care in `scheduler.c` survives that.
* **Result `"1"`/`"0"` with `TCL_OK`, set last** (L2, matching `raw_read` and
  `raw read`/`raw switch`/`raw clear`). *Rejected:* `TCL_ERROR` — four uncaught
  shipped callers, two of them Tk `-command` bodies where a raise becomes a
  `bgerror` modal (issue 0803's suite-hanging shape) and two mid window construction.
* **The RULING D5-3 digital-refusal branch is not touched** (L2): it is a deliberate
  no-op returning a minted sentence before any side effect, and
  `test_backannotate_digital` BA20/BA21/BA27 assert that exact sentence as the interp
  result. *Rejected:* a blanket 0/1 for the whole branch — reds three shipped rows
  for no gain.
* **Delete the `array unset` rather than move it into the success arm** (L1 / **I1**
  one-owner): `update_op()` is the array's only writer. *Rejected:* republishing on
  the failure path via `update_op()`, which would bump `annot_data_changed()` and
  flush the overlay cache for a call that changed nothing.
* **No GUI notice on failure, one `dbg(0)` line** (L2). *Rejected:* the notify
  channel — the brief fences its defects, and the two menu callers are Tk `-command`
  bodies.

## 9. The full caller list (six shipped sites, ten invocations)

**Uncaught (4)** — why `TCL_ERROR` was rejected: `src/xschem.tcl:5830`
(open-in-new-window carry-over, mid window construction), `:6123` (hi_descend's
new-window arm), `:15468`+`:15470` and `:15894`+`:15896` (the two copies of
*Simulation > Graphs > Annotate Operating Point*, Tk `-command` bodies).
**Catch-wrapped (2)** — the two that want a failure signal:
`src/ase_window.tcl:2333`+`:2337` (`ase::ui::annot_ensure_loaded`),
`utils/annot_mode.tcl:330`+`:332` (`cadence::annot_mode`; `:334-340` already re-asks
`xschem raw loaded` with a comment saying the rc is useless). **No C caller** — the
`draw.c`/`callback.c`/`actions.c`/`save.c` hits are comments.

`cadence::annot_mode` cannot regress on a surviving database: it only reaches
`annotate_op` in the `loaded < 0` branch (`utils/annot_mode.tcl:296-320`), so it
never annotates while a database is attached. **That guard is now the only thing
keeping that caller honest** — if it changes, a survived database is reported as a
successful annotate.

## 10. The sabotage matrix (attempt 1)

Seven variants, each neutralizing a callee by renaming it (never a comment marker).

| # | mutation | predicted red | observed |
|---|---|---|---|
| SAB-1 | detach is a destroy again | 8 | **8, exact** (Z2, Z3, Z4b, Z5, Z6, Z7, Z9, Z15) |
| SAB-2 | return value is residue again | 8 | **9** — all 8 plus Z5 |
| SAB-3 | binary short read only warns | 4 | **7** — all 4 plus M4b/M4c/M6 |
| SAB-4 | `read_dataset` clears the registry | 6 | **7** — all 6 plus R5 |
| SAB-5 | the `array unset` comes back | 1 | **1, exact** (Z3 alone) |
| SAB-6 | reattach forgets to make it current | 7 | **5** — Z3 and Z6 did *not* red |
| SAB-7 | failure arms the live flag again | 1 | **1, exact** (Z13 alone) |

**The two predicted reds that did not appear.** *SAB-6 / Z3* is a **mis-prediction**:
Z3 asserts the Tcl mirror, which survives because the `array unset` was deleted and
`update_op()` never runs on the failure path — whether the reattached entry is
*current* is irrelevant to it. Its mechanism is covered twice over (red under SAB-5
and SAB-1). *SAB-6 / Z6* is a **real narrow-coverage statement**: Z6 asserts registry
membership and the result string only (its helper drops the `<idx> current` line by
word count), so a reattach that restores membership but leaves a different database
current satisfies it. Covered by its two siblings on the same fixture, Z5 and Z7.

⚠ **A sabotage lesson worth more than the matrix.** `grep -rn SABOTAGE src/` **and**
`nm | grep _sab` are **both blind to an inlined static one-call helper**. The
adversary measured a confident wrong answer against a SAB-7 build that both checks
called clean. The detector that worked: pick a behaviour the *source* pins exactly
and verify the *binary* agrees before trusting any measurement.

## 11. Binding on the retry

1. **`extra_rawfile_detach()` must handle the unregistered database** — `raw_read`
   leaves `xctx->raw` live with `extra_raw_n == 0`, and that is a shipped route
   (`load_raw`), not a corner. §7 has the three lines.
2. **The regression test must not probe with `xschem raw info` first.** `raw info`
   is `extra_rawfile(4, ...)`, and the base-insert runs **before** the what-dispatch,
   so a single `raw info` *registers* the database and hides the defect. The
   adversary measured a false green exactly that way. Trustworthy probes in that
   window: `xschem raw loaded`, catch-wrapped `xschem raw value <v> -1`,
   `xschem raw rawfile` / `raw sim_type`, and `ngspice::ngspice_data`.
3. **`xschem raw switch op` is a rotate, not a query.** It is `extra_rawfile(2, ...)`
   with a non-numeric arg and returns 1 whenever `extra_raw_n > 0`, never asking
   about the type. §2's "still answers 1 over the emptied slot" is explained by this.
   Do not build an acceptance row on it. `raw info` is **multi-line**; a first-line
   grep silently drops the registry.
4. **The acceptance must include a truncated *binary* fixture**, and it can only go
   green with 0299's `res = 0; break;` (§5).
5. **A failed annotate must not renumber the registry.** Attempt 1's detach compacted
   and its reattach appended, so `[0 g.raw op | 1 t.raw tran]` became
   `[0 t.raw tran | 1 g.raw op]` and `xschem raw switch 0` returned a *different*
   database. No shipped caller holds an index across an annotate today, so it is
   latent — but it contradicts the change's own "a failure must leave the state it
   found". Reattach at the original index, or write the weaker invariant down
   explicitly.
6. **Sabotage must be verified against the binary, not the source** (§10).
7. **THIS FIX CANNOT SHIP WITHOUT [0836](0836-update-op-segfaults-on-a-zero-point-database.md)'s
   GUARD, and the 0814 fixture must be a LIVE ngspice header.** Added by attempt 2,
   which was reverted for exactly this (§13). Any fix that makes the fallback legs
   perform a *real* read — which is what closing 0814 means — will read the
   `No. Points: 0` header ngspice leaves on disk for the **whole duration** of a run,
   succeed with zero points, and SIGSEGV in `update_op()`. At HEAD the dedup never
   opens that file, so HEAD cannot crash there; the fix is what makes it reachable.
   Land the `npoints`/`allpoints` guard in the same commit. And note that a
   *garbage* fixture **cannot** catch this — garbage fails every leg and returns 0.
   The fixture must be a well-formed header declaring zero points.

## 12. Still open

All of the original defect. Plus, from attempt 1's review:

* **The same-path dedup hole — [0814](0814-annotate-op-adopts-a-cached-same-path-entry-instead-of-reading.md),
  measured on HEAD, unfixed.** When the registry already holds a `<path> tran` entry
  and `annotate_op` is called on that same `<path>`, the fallback matches the cached
  entry and returns success **without reading**. This is the shipped ASE/wave-viewer
  arrangement. It means the brief's acceptance ("a failed annotate must destroy
  neither") is *not met when the two databases share a path*, and rows using two
  different paths cannot see it.
* **[0812](0812-extra-rawfile-substs-the-raw-path-so-a-crafted-filename-executes-tcl.md)**
  (a crafted filename executes Tcl) is unfixed and would run **while a database is
  detached** — a live `Raw` owned only by a C local. Name it there as an aggravating
  factor for any detach-based fix.
* **[0299](0299-truncated-binary-raw-reads-as-success-with-a-fabricated-final-point.md)
  carries a user question that only the user can settle**, and the cost is larger
  than the "a 1-point op raw has no 99%" argument implies: a **real 59-point ngspice
  binary transient missing 3 bytes now loads nothing at all**, where today it loads
  all 59 with the last fabricated. If any workflow polls a raw while ngspice is still
  writing it, that turns a slightly-wrong plot into no plot.
* **Unverified by anyone:** the hierarchy leg (descend two levels, annotate, ascend).
  The reverted diff contained no hierarchy walk and no `no_draw`/`no_undo`/
  `keep_symbols`/`sch_path` handling, and a failed annotate left `currsch`,
  `sch_path` and `xschem get modified` untouched at level 0 — but nobody measured a
  descended annotate.


## 13. Attempt 2 — reverted 2026-08-26 (status F). Correct, tier-green, and INCOMPLETE

The full diff, with a long header explaining it, is kept at
**`doc/claude/evidence/0807-attempt2-reverted.patch.txt`**. Read that before
attempt 3; most of it is re-usable as-is once §11.7 is satisfied.

### What it built

**It stashed the whole registry across the read** instead of detaching one entry.
Three new primitives in `save.c` (`extra_rawfile_stash` / `_unstash(keep)` /
`_publish(raw, also_drop)`) plus a `Raw_stash` struct: `xctx->extra_raw_arr`,
`extra_raw_n`, `extra_raw_size`, `extra_idx`, `extra_prev_idx` **and** `xctx->raw`
go aside for the duration of the read, nothing is freed, and a failure restores all
six fields verbatim. `annotate_op` lost its destroy-before-read and its
`array unset ngspice::ngspice_data`, moved `live_cursor2_backannotate` into the
success arm, and ended with `Tcl_SetResult(interp, my_itoa(res == 1), ...)`.
`raw_read` (0813) got the same primitives. 0299 shipped as one owner
(`raw_keep_short_block(p) { return p > 0; }`, both binary `fread` sites) and 0316
was folded in.

This shape beats attempt 1's detach on its own terms and **§11's first six
constraints were all met**:

* **§11.1** — there is nothing to match, so the unregistered-`xctx->raw` case that
  killed attempt 1 cannot arise: the live database is *part of* the stash, so
  `extra_rawfile()`'s base-insert has nothing to adopt and its dedup nothing to find.
  The §7 row measured **8.0 / 4.0** (run 2's numbers), where attempt 1 gave 3.14/1.5.
* **§11.5** — met *exactly* rather than approximately: six fields restored verbatim,
  so the whole multi-line `raw info` and a `raw switch_back` round trip are identical
  across a failed annotate.
* **§11.2/3/4** — honoured in the new rows; the binary fixture is row AA9.

Tiers, all independently re-measured by Verify-A against a byte-guarded pristine
snapshot: `test_op_annot` 358 → **384**, `test_raw_read_failure_0306` 63 → **73**,
`test_raw_ascii_point_bounds` 90 → **118**, every other suite unchanged, T1 zero
counted failures, T2 `HARNESS: PASS`. The eight-variant sabotage matrix was caught,
each variant proved against the **binary** per §11.6.

### Why it was reverted — it makes 0836 reachable in the shipped arrangement

**ngspice writes `No. Points: 0` into the header at the start of a run and backfills
it only at the end.** So for the entire duration of a simulation the raw on disk is a
legitimate, untruncated, **zero-point** file. `read_dataset()` reads it as a success
(`res == 1`, `points == 0`); `my_realloc(..., 0)` frees and NULLs every
`raw->values[v]` (`util.c:1330-1334`); `update_op()`'s only guard is
`if(xctx->raw && xctx->raw->values)` and it then dereferences `values[i][0]`.
That is [0836](0836-update-op-segfaults-on-a-zero-point-database.md).

**0299's change is not in this path** — `npoints` comes from the header, so the store
loop never runs, no `fread` happens and `raw_keep_short_block()` is never consulted.
Verified: no `binary block is not of correct size` warning appears.

The differential is what makes it a **regression** and not merely an inherited defect.
Shape: `<P> tran` is already registered, ngspice re-runs and rewrites `P`, the user
hits Annotate while it is running. **This is the shipped ASE / wave-viewer
arrangement** — `ase.tcl` and `wave_viewer.tcl` load with `xschem raw read`, which
appends, and ngspice overwrites one stable path every run.

* **At HEAD** the tran leg's `rawfile`+`sim_type` dedup (`save.c:1849-1856`) matches
  and `save.c:1885-1889` adopts the cached entry **with no read**. HEAD never opens
  the file, so **it cannot crash**. It publishes the previous run's point 0 and
  reports success — that is 0814, the defect being fixed. Measured at HEAD:

      WU| F2 after : loaded=0 rawfile=Q.raw sim=tran v(a)=7.77 ngdata=5  result=<::op_annot::text>

* **With the patch** the registry is stashed, the dedup cannot match, so every leg
  performs a real read — which is *precisely* how it closes 0814 "by construction".
  The real read of a live zero-point header then succeeds and `update_op()` dies:

      WU| S1 registered  loaded=0 sim=tran
      WU| S2 Q.raw is now a LIVE (0-point header) raw
      extra_rawfile() read: .../Q.raw not found or no "op" analysis
      extra_rawfile() read: .../Q.raw not found or no "dc" analysis
      Raw file data read: .../Q.raw
      points=0, vars=3, datasets=1 sim_type=tran
      FATAL: signal 11

The A/B is airtight **by construction** and does not depend on the fixture: HEAD
never opens the file in this shape, so no file content can crash it; the patch always
opens it, so any zero-point header crashes it.

Note the crash class is *not* new — HEAD reaches the same `update_op()` deref through
the same `annotate_op` door whenever the path is **not** already registered, which is
the commoner case (source-confirmed: HEAD's tran leg is a real
`extra_rawfile(1, f, "tran", ...)` and its success arm calls `update_op()` with no
`npoints` check). What the patch removes is the dedup that *accidentally masked* the
crash in the registered shape. That is why the verdict is **incomplete, not wrong**.

### How it was found, and the process gap

By the **Verify-C adversary**, which drove a real still-being-written 2.9 MB ngspice
raw (`live.tcl`) rather than a crafted one, hit the crash, and then **died before
writing a report** — the crew's summary recorded "verify-C produced nothing". The
finding was recovered by the write-up agent from the adversary's leftover
`live_fix.out`, and then reproduced minimally with a twelve-line hand-written header.
Verify-B likewise produced no report (its sabotage evidence survives only in the
Implement agent's own transcript, corroborated incidentally by Verify-A, which
accidentally measured two SAB builds mid-run and diagnosed them from source diffs).

**Lesson for the run harness, not for the code:** an adversary that crashes is not an
adversary that found nothing. Its scratch directory must be swept before a status is
assigned. Had it not been, this would have shipped green.

### What attempt 3 should do

1. **Land 0836's guard first, or in the same commit** — an `npoints`/`allpoints`
   check before `update_op()` dereferences `values[i][0]`, plus a decision on what a
   zero-point database *means* to `annotate_op` (recommend: treat it as "nothing was
   published", answer `0`, leave the previous database attached — invariant I3).
2. **Then re-apply `0807-attempt2-reverted.patch.txt`**, which needs no rework.
3. **Fix the 0814 fixture**: row AA19 used 40 bytes of garbage, which fails every leg
   and returns 0 — it passes on a tree that crashes. Use a well-formed
   `No. Points: 0` header, and add the live-raw row as an acceptance row in its own
   right.
4. Consider whether a zero-point read should be refused **in the reader** rather than
   guarded in `update_op()`. That is a wider blast radius (the wave viewer may want to
   attach a running sim's raw and watch it fill) and is a **user-visible ruling** — do
   not decide it unilaterally.

---

## 14. RULING, 2026-08-29 — both halves decided, one of them NOT the way attempt 2 wrote it

Decided under the user's instruction of 2026-08-29 ("decide the 23, leave 0861 and
0299 for me"). Ruling debt **0807** is discharged; **0299 remains the user's** and is
still on the critical path (§5, §11.4).

### 14.1 THE ANSWER — ratified. `annotate_op` must answer `1` or `0`.

**Instruction to the codebase:** the `annotate_op` branch of `scheduler.c` must set
its own Tcl result as its last act — `"1"` when the operating point was actually read
and published, `"0"` when it was not — always with `TCL_OK`. It must never again fall
off the end setting nothing.

Verified at HEAD before ruling: between the digital refusal
(`src/scheduler.c:2481`) and the branch's closing brace (`:2546`) there is **no**
`Tcl_SetResult` on any path. The result is therefore the previous command's residue,
and the residue is not even stable across arms — row **F0** of
`tests/headless/test_annot_stale_0684.tcl` golds a *successful* annotate as
`{0 ::op_annot::text}`, and the comment above row **F10** (`:528`, `:543-546`)
records the failure result as "an empty string headless and `0` on the display arm".
A verb whose success answer is another proc's name and whose failure answer depends
on whether a display is attached cannot be asked "did that work".

Note the issue text in §1 above ("returns `TCL_OK` **with the path string**") is
**stale** and so is any test comment repeating it. The path string is not what ships.

Costs nothing to ratify: **no shipped caller reads the result.** All six sites were
re-checked — `src/xschem.tcl:5916`, `:6209`, `:15713`/`:15715` and `:16139`/`:16141`
(the two copies of *Simulation > Graphs > Annotate Operating Point*) ignore it, and
the two that want a failure signal already work around its absence by re-asking:
`utils/annot_mode.tcl:2118-2124` (`catch`, then `cadence::_annot_db_analog_loaded`,
with the comment "SUCCESS IS RE-ASKED FROM `xschem raw loaded`, NEVER TAKEN FROM THE
rc") and `src/ase_window.tcl`'s `annot_ensure_loaded`.

`TCL_ERROR` stays rejected for the reason §8 already gives: four uncaught callers,
two of them Tk `-command` bodies where a raise becomes a `bgerror` modal.

The **RULING D5-3 digital refusal keeps its plain-English sentence** as the result
(minted once in `save.c:1602 backannot_refuse_digital()`, rendered at
`scheduler.c:2481`, asserted by `test_backannotate_digital` BA20/BA21/BA27). That is
not a second answer to the same question: it is the one arm that has something to
*say* rather than a yes/no to report, which is what RULING D5-4 asks for.

**Cost of honouring this:** row **F0** of `tests/headless/test_annot_stale_0684.tcl`
golds the residue and must be re-golded `{0 1}`. Row **F10** golds only
`[lindex $f10_raw 0]`, the return code, and is unaffected.

### 14.2 THE WAVES CHECKBUTTON — ratified in the OPPOSITE direction to attempt 2

**Instruction to the codebase:** *Simulation > Graphs > "Live annotate probes with
'b' cursor"* is the user's tick and nothing but a user click may move it.
`annotate_op` must not set it on **any** arm — not on failure, and **not on success
either**. When `0807-attempt2-reverted.patch.txt` is re-applied for attempt 3, the
line that moves `tclsetboolvar("live_cursor2_backannotate", 1)` into the success arm
must be **dropped, not carried over**.

The debt's own pitch, and the read-only audit that proposed an answer to it, both
framed this as "arm it only when the annotate succeeded" — which is what attempt 2
built. That framing predates **issue 0864** and ratifying it would be a *regression*.

Verified at HEAD: `grep -rn 'tclsetboolvar("live_cursor2_backannotate"' src/` returns
**one hit, and it is inside a comment** (`src/scheduler.c:2487`, the 0864 note telling
a future reader not to put it back). No code anywhere sets that variable; the only
assignment in the tree is the shipped default `set_ne live_cursor2_backannotate 0`
(`src/xschem.tcl:16819`). So HEAD is already stricter than attempt 2, and this half of
the ruling **ratifies shipped behaviour and moves no code**.

Why the stricter reading is the right one, and why this is not a trade-off:

* it is the user's standing ruling verbatim — *"MUST ONLY HAPPEN WHEN USER REQUESTS
  IT!!"*, quoted in the 0864 note at `scheduler.c:2487` and again at
  `xschem.tcl:16809-16818`. Untick the box, press `6`, and the box came back ticked;
* the only argument that ever existed for the force-set (upstream 89d847fb — without
  the switch a fresh annotation drew nothing, because the switch was also the first
  term of every render gate) **no longer applies**: 0864 removed it from those gates
  in both languages. There is no remaining cost on the other side, which is why this
  was decided rather than bounced;
* rows **A64-1 / A64-2 / A64-3** of `tests/headless/test_op_annot.tcl` already watch
  this arm, and A64-2 requires the variable's name to appear on no *code* line of it.
  Attempt 2's success-arm set would red A64-2 on re-application; that red is correct
  and must be fixed by deleting the line, never by relaxing the row.

---

## RULING, 2026-08-29 — decided on the user's instruction

**Scope note.** This section **supersedes the mechanism of §14.1** and **adds one
line to §14.2**. §14 is left exactly as written, as the record of what was ruled
first. §14.2's substance stands unchanged; §14.1 was right that the verb must
answer and wrong about where the answer comes from.

The user's instruction, 2026-08-29, verbatim:

> "decide the 23, leave 0861 and 0299 for me"

A read-only audit of the 57-entry ruling queue classified 25 entries as questions
whose answer is cheap and obvious — things to be **decided** rather than put to the
user. **0807 was one of the 23** so classified. 0861 and 0299 were excluded and
remain the user's to answer.

### The ruling, as an instruction to the codebase

**(1) `annotate_op` must answer, and its answer is "did the numbers reach the
schematic".**

The `annotate_op` branch of `src/scheduler.c` must set its own Tcl result as its
last act — `"1"` or `"0"`, always with `TCL_OK`, never falling off the end.
`TCL_ERROR` stays rejected for the reason §8 already gives (four uncaught callers,
two of them Tk `-command` bodies where a raise becomes a `bgerror` modal). The
RULING D5-3 digital refusal keeps its minted plain-English sentence as its result:
that arm has something to *say*, not a yes/no to report.

**The yes/no is `update_op()`'s verdict, NOT `extra_rawfile()`'s.** Attempt 2 wrote
`Tcl_SetResult(interp, my_itoa(res == 1), TCL_VOLATILE)`, where `res` is the return
of `extra_rawfile(1, ...)` — that means *"a results file got attached"*, which is not
what the user is being told. Instead:

* declare `int published = 0;` at the top of the branch;
* in the success arm, capture the return that is presently discarded:
  `published = update_op();`
* answer `Tcl_SetResult(interp, my_itoa(published == 1), TCL_VOLATILE);`

`update_op()` is the one choke point where "was anything put on the schematic" is
known (`src/save.c:2100-2320`; `res` is set to `1` only inside the publish loop, and
each refusal returns `0` at `:2122`, `:2200`, `:2304`). With that source, `"1"` means
what the user was told it means — *the operating point is on the schematic*.

**(2) The Waves checkbutton — §14.2 stands, plus one line.** *Simulation > Graphs >
"Live annotate probes with 'b' cursor"* is the user's tick and nothing but a user
click may move it; `annotate_op` must not set it on **any** arm, success or failure.
When `0807-attempt2-reverted.patch.txt` is re-applied for attempt 3, the line moving
`tclsetboolvar("live_cursor2_backannotate", 1)` into the success arm must be
**dropped**. **The added line:** that patch also brings its own new row **AA13**,
golded `{0 1}` — *"a FAILED annotate leaves `live_cursor2_backannotate` as it found
it; a SUCCESSFUL one arms it"* (patch line 1095). Deleting the code without
re-golding AA13 to **"leaves the box as it found it on BOTH arms"**, gold `{0 0}`,
lands attempt 3 with a **false red** that reads like the fix is broken.

**(3) The unreadable raw must speak plain English, like its two neighbours.** The
failure this issue is *named after* is the one arm with no sentence: attempt 2's
failure arm is `dbg(0, "annotate_op(): no op/dc/tran data read from %s...")`, which
reaches stderr and the action log, where someone editing a schematic never sees it.
Mint a **third sentence** beside `backannot_refuse_digital()` and
`backannot_refuse_empty()` in `src/save.c` — naming the file, saying it could not be
read, and saying that nothing on the schematic changed — rendered on the same
channel those two use. §8 rejected a GUI notice because no channel existed; one
exists now, minted-once and already used twice.

### Why

* **INTENT OVER MECHANISM, and RULING D5-4.** "Attached" and "published" disagree in
  shipped shapes, not corners, and every disagreement prints a contradiction:
  * **a transient run** — the commonest thing on a bench. ngspice writes one `.raw`;
    `op` fails, `dc` fails, `tran` attaches, and `update_op()` refuses to publish a
    transient's t=0 as an operating point — the user's own ruling of 2026-08-26,
    shipped as 0856/0872. The schematic shows nothing; `res == 1` would answer `1`.
    The contradiction is already committed one row apart: **BA25** runs
    `xschem annotate_op $collraw 0 tran` and is "not refused", while **BA26** beside
    it asserts the array is left empty;
  * **annotating while the simulation is still running** — ngspice leaves
    `No. Points: 0` in the header for the whole run. The attach succeeds, the 0836
    guard refuses, and `backannot_refuse_empty()` prints its plain-English *"holds no
    simulation points yet"* sentence **into the command window**
    (`src/save.c:1652`, `ciw_echo` under `has_x`). Then the command window prints
    `1` on the next line, because `ciw_exec` echoes any non-empty result
    (`src/ciw.tcl:642-643`). The user reads the refusal and the success one line
    apart — RULING D5-4 broken in the literal;
  * **ac / noise / table**, per the 0860 widening: attach, refuse to publish, answer
    `1`.
* **§13 already rules against the weaker reading.** "What attempt 3 should do" item 1
  requires *"a decision on what a zero-point database means to `annotate_op`
  (recommend: treat it as 'nothing was published', answer `0`... invariant I3)"*, and
  §11.7 makes a well-formed `No. Points: 0` header a required acceptance fixture.
  `res == 1` answers `1` on the exact fixture this document requires to answer `0`.
* **Half (1) is a bug wearing a question mark, so ratifying costs nothing.** No
  shipped caller reads the result at all, and the two that want a failure signal
  already work around its absence by re-asking. Every `"1"` gold attempt 2 wrote is
  on an `op` fixture (AA0/AA8/AA10), as is F0, so all stay green under the corrected
  reading.
* **Half (2) is the user's standing ruling verbatim** — *"MUST ONLY HAPPEN WHEN USER
  REQUESTS IT!!"* (issue 0864, quoted at `scheduler.c:2487` and
  `xschem.tcl:16809-16818`). Untick the box, press `6`, and the box came back ticked.
  The only argument that ever existed for the force-set (upstream 89d847fb — the
  switch was also the first term of every render gate, so a fresh annotation drew
  nothing without it) **no longer applies**: 0864 removed it from those gates in both
  languages. Nothing on the other side of the scale, which is why this was decided
  rather than bounced.
* **PLAIN ENGLISH.** Point Annotate at a `.vcd` and get a paragraph; press it mid-run
  and get a paragraph; point it at a results file that cannot be read and get the
  digit `0` and silence. Half (3) closes that gap.

### What was verified in the tree, so a later reader need not re-derive it

* `src/scheduler.c:2386-2546` — the whole branch read. The **only** `Tcl_SetResult`
  is the digital refusal at `:2481`; the `res == 1` success arm (`:2539-2546`) calls
  `update_op()` and `draw()`, **discards `update_op()`'s return**, and sets no result.
  The verb therefore answers the previous command's residue. §1's claim that it
  "returns `TCL_OK` **with the path string**" is **stale**; the path string is not
  what ships.
* `src/save.c:2100-2320` — `int update_op()`. `res` starts `0` and is set `1` only
  inside the publish loop (`:2320` returns it); the refusals return `0` at `:2122`
  (digital), `:2200` (zero-point / `backannot_refuse_empty`) and `:2304`
  (non-op/transient). This is the published verdict, minted at one choke point.
* `tests/headless/test_annot_stale_0684.tcl:340-346` — row **F0** golds a
  *successful* annotate as `{0 ::op_annot::text}`: a committed measurement of the
  residue on success.
* `tests/headless/test_annot_stale_0684.tcl:528, 539-546` — row **F10**'s comment:
  *"annotate_op over an unreadable file answers an empty string headless and `0` on
  the display arm"*. F10 golds only `[lindex $f10_raw 0]`, the return code, so it is
  unaffected by the change.
* `tests/headless/test_backannotate_digital.tcl:290, 307-310` — **BA25** ("the same
  command on an ANALOG raw is not refused") and **BA26** ("a TRANSIENT publishes
  NOTHING onto the schematic (0856)... the array is left EMPTY"): attached-but-not-
  published, already committed, one row apart.
* `grep -rn 'tclsetboolvar("live_cursor2_backannotate"' src/` → **one hit**,
  `src/scheduler.c:2487`, **inside the 0864 comment block**, not code. No force-set
  survives at HEAD on any arm.
* `grep -rn 'live_cursor2_backannotate' src/*.tcl utils/*.tcl` → three hits, none an
  assignment by annotate: `src/xschem.tcl:14276` (a variable list), `:16189` (the
  checkbutton's `-variable`, user-visible label *"Live annotate probes with 'b'
  cursor"*, under *Simulation > Graphs*), `:16819` `set_ne live_cursor2_backannotate 0`
  (the shipped default).
* `doc/claude/evidence/0807-attempt2-reverted.patch.txt` — line **571** is the
  success-arm `tclsetboolvar(...)` to be dropped; line **589** is
  `Tcl_SetResult(interp, my_itoa(res == 1), TCL_VOLATILE)`, the mechanism corrected
  here; line **577** is the `dbg(0, ...)` failure arm half (3) replaces; lines
  **1081-1096** are row **AA13** and its `{0 1}` gold.
* `src/save.c:1602` `backannot_refuse_digital()` and `:1652`
  `backannot_refuse_empty()` — the two existing minted sentences, both echoing to the
  command window via `ciw_echo` under `has_x`. `src/ciw.tcl:636-644` — `ciw_exec`
  echoes any non-empty result, which is how a bare `1` would land beside a refusal.
* Caller sweep: `src/xschem.tcl:5916`, `:6209`, `:15713`/`:15715`, `:16139`/`:16141`
  — none reads the result. `utils/annot_mode.tcl:2118-2121` —
  `catch {xschem annotate_op $path $lvl tran}` then `cadence::_annot_db_analog_loaded`,
  under the comment *"SUCCESS IS RE-ASKED FROM `xschem raw loaded`, NEVER TAKEN FROM
  THE rc"*. `src/ase_window.tcl`'s `annot_ensure_loaded` does the same.

### Does this move code?

**Half (2) ratifies shipped behaviour — nothing moves at HEAD.** HEAD is already
stricter than attempt 2. Its obligation is a *don't* aimed at attempt 3.

**Halves (1) and (3) IMPLY A CODE CHANGE — follow-up work, NOT YET DONE.** Nothing
in this ruling has been implemented; no source or test file was touched to record it.
Attempt 3 owes:

1. `src/scheduler.c`, `annotate_op` branch: add `int published = 0;` at the top,
   change the discarded `update_op();` in the success arm to
   `published = update_op();`, and add
   `Tcl_SetResult(interp, my_itoa(published == 1), TCL_VOLATILE);` as the branch's
   **last statement**.
2. `src/save.c`: mint a third refusal sentence beside `backannot_refuse_digital()`
   and `backannot_refuse_empty()` for the unreadable/unparseable raw — names the
   file, says it could not be read, says nothing on the schematic changed — rendered
   on the same channel; replace the `dbg(0, ...)`-only failure arm with it.
3. `tests/headless/test_annot_stale_0684.tcl`: re-gold row **F0** from
   `{0 ::op_annot::text}` to `{0 1}`. Row F10 is unaffected.
4. On re-applying `0807-attempt2-reverted.patch.txt`: **delete** its success-arm
   `tclsetboolvar("live_cursor2_backannotate", 1)` (patch line 571) — otherwise it
   reds row **A64-2** of `tests/headless/test_op_annot.tcl`, correctly — **and**
   re-gold that patch's own row **AA13** to *"leaves the box as it found it on BOTH
   arms"*, gold `{0 0}`, so the deletion does not land as a false red.
5. Add the zero-point acceptance fixture §11.7 and §13 already require (a well-formed
   `No. Points: 0` header, not AA19's 40 bytes of garbage). Under this ruling it must
   answer **`0`** — which `res == 1` could not have delivered.

**The adversary ran.** It could not overturn half (2) and confirmed it independently
at HEAD; it **overturned half (1)** — not on *whether* the verb should answer, but on
*what its yes/no means* — and its better answer, the published-not-attached reading
plus the third minted sentence, is what is ruled above.

**What this means for the person using the tool:** pressing *Annotate Operating
Point* will give a plain yes/no about whether it actually worked — not merely whether
a results file opened — and when it cannot work it will say why in the command window
instead of leaving you guessing. And it will never tick the *Simulation > Graphs* box
*"Live annotate probes with 'b' cursor"* on your behalf, on success or failure; that
box stays wherever you left it.

**The user may reverse this at any time; it was decided to spare their attention, not
to bind them.**
