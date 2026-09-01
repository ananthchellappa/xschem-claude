# 0685 — `xschem annotate_op <path>` hands back a STALE in-memory database when that path is already in the extra-raw registry

STATUS: OPEN — measured 2026-08-25 by the 0683+0684 crew (plan pass), and
**independently re-measured by the write-up pass, including the precondition the
first attempt got wrong**. Filed, not fixed.
FOUND IN: `scheduler.c:2409-2427` (the `annotate_op` arm) + `save.c:1819-1830`
(`extra_rawfile()`'s dedup loop).
RELATED: invariant **I3**, [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md).

---

## 1. The defect

`annotate_op` deletes the previously loaded database **only when that database is
itself a 1-point `op`/`dc`**:

```c
/* scheduler.c:2410-2414 — delete previously loaded OP */
if(xctx->raw && xctx->raw->rawfile && xctx->raw->allpoints == 1 &&
   (!strcmp(xctx->raw->sim_type, "op") || !strcmp(xctx->raw->sim_type, "dc"))) {
  res = extra_rawfile(3, xctx->raw->rawfile, xctx->raw->sim_type, -1.0, -1.0);
}
```

It then calls `extra_rawfile(1, f, sim_type, ...)`, whose dedup loop
(`save.c:1819-1826`) matches on **rawfile + sim_type** and, on a hit, takes the
"already loaded: switch to it" branch **with no read**. So whenever the current
database is something else — a waveform graph, say — a same-path entry left in the
registry is handed straight back, however old it is.

## 2. The measurement, and the precondition that decides it

⚠ **The precondition is exact, and the obvious probe misses it.** `xschem raw_read`
REPLACES slot 0 (it evicts the old entry, so the next `annotate_op` re-reads and the
defect does not appear). `xschem raw read` ADDS. Only the adding form leaves a
same-path entry behind while making something else current.

First probe, using `raw_read` — **the hazard does NOT appear**, and a crew that stops
here will wrongly conclude the C is fine:

```
1. annotate_op the op raw   -> v(a)=111   info = 0 current | 0 …/p685_op.raw op
2. raw_read a foreign tran  -> info = 0 current | 0 …/p685_tr.raw tran   <<< op EVICTED
3. the SAME op path is rewritten on disk to 999
4. annotate_op the SAME path -> v(a) = 999    (correct: it re-read)
```

Second probe, identical but with `xschem raw read $T tran` — **the hazard reproduces**:

```
1. annotate_op op raw     v(a)=111  info=0 current | 0 …/q_op.raw op
2. xschem raw read tran (ADDS)  rc=1
   info=1 current | 0 …/q_op.raw op | 1 …/q_tr.raw tran   current sim_type=tran
3. SAME op path rewritten on disk to 999
4. annotate_op SAME path  rc=::op_annot::text
   rawfile=q_op.raw   v(a)=111   <<< STALE: the file says 999
5. force-drop then retry:
   foreach t {op dc tran} { catch {xschem raw clear $P $t} }
   annotate_op  v(a)=999
```

`xschem raw value v(a) -1` returning the previous run's number is invariant **I3**'s
forbidden case in its own words — *"not the previous run's number"*.

## 3. Who is exposed

Every caller that re-annotates a stable path while a graph is open:

| caller | exposure |
|---|---|
| `Waves > Op Annotate` / `Simulation > Graphs > Annotate Operating Point` | both call `annotate_op` on a user-chosen path |
| `utils/annot_mode.tcl` (`cadence::_annot_raw_candidate`, the `6`/`Alt-6` chords) | re-annotates the `netlist_dir` candidate |
| `ihp-sg13g2/sg13g2_procs.tcl:436` `sg13g2_raw_or_double` | a bare `xschem raw value` with **no** `annot_p` gate at all |
| any ASE-L raw-attach arm | `<rundir>/<cell>_ase.raw` is a stable path each run overwrites |

## 4. Decision — filed, not fixed (ladder **L2**)

The 0683+0684 crew worked around it in Tcl with `ase::ui::annot_drop_stale`
(`foreach t {op dc tran} { catch {xschem raw clear $np $t} }` immediately before the
`annotate_op`). **That workaround was reverted with the rest of the attempt**, and it
should NOT be re-created in the same shape — see the warning below.

REJECTED: fixing it in C inside `annotate_op` **in this run** — a C change whose blast
radius covers every caller above, in a Tcl-only run. It remains the right place.

### ⚠ The workaround, as written, caused a data-loss regression

`annot_drop_stale` cleared `op`, `dc` **and** `tran` at the session path before the
re-read. When the re-read then FAILED — the ordinary case of ngspice being mid-rewrite
of that path, file present and readable but truncated — the user's loaded waveform
database was gone and nothing replaced it. Measured (`vc/atk5.tcl`, same scenario run
twice, old guard vs new):

```
--- (1) THE OLD, SHIPPED-BEFORE GUARD ---
    AFTER the tick: raw info = '0 current | 0 …/atkH.raw tran'   points=3
    >>> OLD: the user's waveform database SURVIVES (the guard early-returned)
--- (2) THE NEW annot_ensure_loaded ---
    [ECHO error] ase: '…/atkH.raw' produced no operating-point data -- the annotation will be blank
    AFTER the tick: raw info = ''   points=<RAISED: No raw file loaded>
    >>> NEW: destroyed.
--- (3) the file-readability pre-check does NOT catch it ---
    file isfile = 1     file readable = 1
```

Binding on any retry: **drop the entry only for the sim_type you are about to read**
(`op`/`dc`, never `tran`), and/or verify the candidate parses before dropping
anything. `file readable` is not that verification.

## 5. Still open — but the hazard now has a workaround AND its first test rows

**2026-08-28, item A15 (the issue 0684 fix).** The Tcl workaround this section
asks for now ships, in the shape §4 makes binding, inside `op_annot::db_attach`
(`src/op_annot.tcl`):

* it enumerates `xschem raw info` and drops **only** entries whose normalized
  rawfile equals the path it is about to read **and** whose sim_type is `op` or
  `dc` — **never** `tran`, and never the bare `xschem raw clear` the reverted
  attempt used;
* it hands `raw clear` the **registry's own spelling** of the path, so a drop
  cannot silently miss on a path-spelling difference (a miss is a no-op:
  `save.c`'s `what==3` returns 0 and changes nothing);
* it then **verifies by re-asking**, because `annotate_op` returns `TCL_OK` for a
  file it could not read.

Five rows now cover it, the first anywhere in the tree
(`tests/headless/test_annot_stale_0684.tcl`, both arms):

* **F12** stages §2's second probe exactly — `annotate_op`, then
  `xschem raw read <tran> tran` (the **adding** form), then the same op path
  rewritten — and golds the naive `annotate_op` handing back `1e-05` **next to**
  `db_attach` yielding `0.009`, with the user's transient still in the registry.
  So the hazard and its workaround are pinned in one golden. ⚠ It is a
  **demonstration, not a guard**: its own bare `annotate_op` call leaves the
  stale entry *current*, and once it is current the attach re-reads with or
  without the drop — measured 2026-08-28, deleting the drop loop left F12 green.
* **F12b** is the guard. Same staging, **nothing in between**: the stale
  operating-point entry sits at the session's path while the user's waveform
  graph is the current database, and `op_annot::db_attach` is the first thing to
  touch it. Without the drop, `extra_rawfile`'s dedup loop takes the
  "already loaded: switch to it" branch with **no read** and the sheet paints
  the previous run.
* **F13** stages §4's data loss with the user's waveform at a **different** path
  from the one being attached: the rewritten op file is truncated garbage,
  `db_attach` must fail **and** the transient must still be attached and
  readable. It guards the drop **existing**, not its type list.
* **F13b** is the type list's guard, and it is where §4's loss actually lives:
  one file, read as a waveform by `xschem raw read`, then rewritten by a re-run
  this surface tries to annotate from while the simulator is still mid-write.
  The drop runs **before** the read, so a drop that included `tran` would take
  the user's trace off and the failed read would put nothing back. Measured both
  ways — shipped keeps the registry entry and `v(zzz)` still reads; with `tran`
  in the list the registry is **empty** and the vector is unreadable. Until
  2026-08-28 nothing but F14's source grep stood between the user and that.

Row **F14** is the structural guard: `db_attach`'s body must contain no `tran` and
no bare `xschem raw clear`.

**Still open:** the C defect itself (`scheduler.c:2410-2427` +
`save.c`'s dedup loop) and the other exposed callers, which the workaround does
not reach. C remains the right place; every Tcl caller that re-attaches has to
carry this drop until then.
