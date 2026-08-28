# 0883 - Show in Signal Browser maps from a raw the DESIGN window now holds

**Status:** OPEN, mechanism MEASURED, end-to-end case NOT yet reproduced on a
descended session. Filed 2026-08-27 by item A10's PART 5 sibling audit, BEFORE
the case can be hit, because item A10's own fix is what makes it reachable.

## The claim

`ase::browser_show_current` (`src/ase.tcl:3573-3590`) maps the schematic position
onto the Signal Browser by dropping leading hierarchy segments, and it decides how
many to drop from a read taken **in the design window**:

    # 3. the origin mapping
    set lv -1
    catch {set lv [xschem raw loaded]}
    set drop [wviewer::browser_origin_drop $level $lv]

`wviewer::browser_origin_drop` (`src/wave_viewer.tcl:11486`) is
`level - (rawlevel >= 0 ? rawlevel : 0)`.

Until item A10 the design window never held a raw — the waveform viewer attaches
to its OWN window's context, on purpose — so `lv` was **always -1** there and the
drop was always the full `level`. After A10, **Alt-Shift-6** and
**Results > Annotate > Transient Node Voltages (at cursor)** supply the design
window themselves, so `lv` becomes a real level and the drop changes.

## What is measured

`xschem raw loaded` is `sch_waves_loaded()` (`src/draw.c:2834`): it walks the
hierarchy stack from `currsch` down and returns the index whose `sch[i]` equals
`raw->schname`, or -1. And `xschem annotate_op <file> <level>` stamps exactly
that (`src/scheduler.c:2539-2542`):

    if(level >= 0) {
      xctx->raw->level = level;
      my_strdup2(_ALLOC_ID_, &xctx->raw->schname, xctx->sch[level]);
    }

Item A10's supplier passes the ASE session's own level through that argument. So
on a session bound at level 2, after one Alt-Shift-6 the design window answers
`lv = 2` where it answered -1 before, and the drop goes from **2 to 0**.

Measured directly at level 0 (where the two answers coincide, which is why no
existing row sees this):

    browser_origin_drop 2 -1  ->  2      (today, design window empty)
    browser_origin_drop 2  0  ->  2      (A10, session at the top)
    browser_origin_drop 2  2  ->  0      (A10, session two levels down)

## What is NOT established

Nobody has driven **Show in Signal Browser** on a descended session with a bound
ASE-L session after an Alt-Shift-6. Which of the two drops is CORRECT is also
open: the new one arguably describes reality better (the raw really is anchored
at that level), and the refusal arm above it —

    "the simulation data is read below this session's design; cannot map the
     schematic position onto the Signal Browser"

— may also change which side of zero it lands on. This needs a bench run before
anyone changes a line.

## Why it is not fixed here

`src/ase.tcl` and `src/wave_viewer.tcl` are outside item A10's blast radius, and
touching either puts the four signal-browser suites in play. This is filed so the
next crew confronts a stated premise rather than rediscovering it. Sibling of
issue **0882**, which is the same class in `wviewer::hier_origin_ok`.
