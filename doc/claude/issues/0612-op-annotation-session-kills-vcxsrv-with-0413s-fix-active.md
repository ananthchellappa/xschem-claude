# 0612 — an OP-annotation session kills VcXsrv, with 0413's fix active

STATUS: **OPEN — reproduced TWICE by the user on the real screen, 2026-08-22.**
Not reproducible on Xvfb. Related: **0413** (same symptom, different cause, marked
FIXED and its fix verified active here), 0457(b), spec §S9b.

---

## What happens

The **X server dies.** XSCHEM does not crash — it loses its connection to a
server that is no longer there:

```
X connection to 172.30.64.1:0 broken (explicit kill or server shutdown).
```

Measured immediately after, from the same machine:

```
port 6000            REFUSED            -> VcXsrv is down
DISPLAY=:99 (Xvfb)   still answers      -> the machine is healthy
XSCHEM_BACKING_STORE <unset>            -> 0413's fix WAS active
```

The user loses every X client on that server, not just XSCHEM.

## The two sequences that did it

Both on `sky130A/xschem_libs/sky130_tests_ase/bandgap_opamp` (13 FETs, two levels
inside `tb_bandgap`), launched with `sky130A/cadence_style_rc`, a 15.8 MB tran raw
loaded and `cursor2_x` at 20 µs.

**Run 1.** `6` (annotation on) → `Alt-6` → `Ctrl-6` → `Ctrl-X` up a level →
descend back → `Ctrl-6` → **server dies**.

**Run 2, sharper.** descend → `6` (annotation on) → `Ctrl-E`
(`cadence::return_one_level`) → *select an instance to descend into* →
**server dies**.

The common element is: **annotation has been ON, then a hierarchy change, then a
redraw.**

## What is NOT the cause — measured, so nobody re-walks these

* **Not an XSCHEM crash.** No SIGSEGV, no `FATAL: signal`, no emergency save. The
  process died because its server did.
* **Not 0413's backing store.** `XSCHEM_BACKING_STORE` was unset, so
  `src/xinit.c:3609` applied `NotUseful`, which is the whole of 0413's fix.
* **Not a stale overlay cache.** The first hypothesis was that
  `annot_cache` survives a level change and draws the child's blocks against the
  parent's instance array. It does not: `clear_drawing()` calls
  `annot_data_changed()` (`src/actions.c:2321`) and its comment names descend and
  ascend explicitly. The apparent evidence — `xschem get annot_overlay_count`
  reading **13** at the parent level where no instance is annotatable — was a
  misreading: that counter is **monotonic** (`src/actions.c:1261-1263`), a session
  running total, not a per-frame count.
* **Not reproducible under Xvfb.** The exact Run-2 sequence, scripted, plus
  selecting all 115 instances on the returned-to level with a redraw each:
  `REPRO413B SURVIVED`, `:99` still alive. A virtual server is far more robust
  than this one; absence here is not evidence of absence there.

## Why this is worth a number of its own rather than reopening 0413

0413's cause was a specific request (`backing_store = WhenMapped`) and its fix is
verified present and active. This is a different path to the same outcome, and the
family it belongs to — *XSCHEM can issue something that takes this server down* —
now has two members. That is the argument for treating the server's fragility as a
class rather than as one bug.

## What is owed, and the cheapest next step is NOT ours

**The VcXsrv log names the failing request.** VcXsrv writes a log on the Windows
side; the last entries before it exits should identify the request that killed it.
That is a manual step only the user can take, and it is worth far more than
further guessing from the Linux side.

Failing that, a bisect against the real server — each iteration costs the user
their X session, so it needs consent and should be scripted to run the sequence
unattended and report how far it got.

## The reproducer, scripted

`<scratch>/bg/repro413b.tcl` runs Run 2 headlessly and reports each step. It
survives on Xvfb; point it at the real server to reproduce.
