# 0807 — `xschem annotate_op` destroys the attached OP database on a truncated raw, and reports success

STATUS: **OPEN — attempt 1 implemented, measured, and REVERTED 2026-08-25.**
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
