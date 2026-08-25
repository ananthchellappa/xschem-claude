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

## 5. Still open

The C defect itself, all four exposed callers, and the absence of any test row for
it anywhere in the tree.
