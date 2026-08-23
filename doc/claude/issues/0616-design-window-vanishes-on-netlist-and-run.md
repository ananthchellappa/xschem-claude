# 0616 — "Netlist and Run" makes the schematic window disappear

STATUS: **OPEN — reported by the user 2026-08-22**, second eyes-on session.
Not yet root-caused; the crew measures first.

---

## What the user sees

> "(when I press Netlist and Run, the schematic window disappears). I have to do
> Session > Design window to get it back"

Launch: `src/xschem --script sky130A/cadence_style_rc --logdir /tmp`, open
`ngspice_state1` of `tb_bandgap` (`sky130_tests_ase`), enable only the OP
analysis, press **Netlist and Run**. The design window goes away. It is
recoverable from **Session > Design Window**, so the schematic is not closed —
something unmaps, lowers, or re-parents it.

## Why it matters more than a cosmetic annoyance

The whole OP-annotation workflow is *run, then descend and press 6*. If the run
takes the schematic off screen, every user's next action is a detour through a
menu — and a user who does not know that menu item exists reasonably concludes
the run destroyed their work. It also interacts with 0617: the user comes back
via a *different* code path than the one they left by, and `sim_sch_path` /
descend state ordering is already known-fragile (0608 — read the raw at the TOP,
then descend; descending first empties `sim_sch_path` and every row goes blank).

## Where to look

Nothing in `src/ase.tcl` withdraws or destroys a toplevel — `grep -n
'withdraw\|destroy \.\|wm iconify'` comes back empty of anything on the run path,
so **the cause is not an explicit hide** and the obvious suspect is already
eliminated. Candidates, in the order the crew should measure them:

1. `ase::run_deck` (`src/ase.tcl:513-576`) does `cd $rd` … `eval execute 0 $cmd`
   … `cd $save`. A Tcl `cd` moves neither `pwd_dir` nor the startup `getcwd`
   (`xinit.c:174`, issue 0323) — but check what it *does* move, and whether the
   window's identity survives it.
2. `ase::netlist` calls `xschem netlist -noalert $nl`. Netlisting walks the
   hierarchy; if it swaps or tears down a context (`get_save_xctx()` /
   `get_old_xctx()`, `xinit.c`), the canvas backing the design window may be the
   casualty.
3. The waveform viewer / ASE window raising itself over the design window —
   which would be *stacking*, not disappearance, and is distinguishable in one
   measurement (`wm state`, `winfo ismapped`, and the stacking order before and
   after).

**Measure which of the three it is before proposing anything.** The three have
nothing in common as fixes.

## Test note

This needs a real window manager to be meaningful. The Xvfb arm runs `openbox`
(`AUDIT_WM`, default) and reparents properly, so `winfo ismapped` / `wm state` /
stacking are all testable headlessly — an empty Xvfb is **not** enough (it does
not reparent and silently no-ops `wm iconify`).

## Acceptance

- After **Netlist and Run** the design window is still mapped and still visible,
  with no menu detour.
- A regression check asserts `winfo ismapped` and `wm state` across the run, and
  fails if the window is unmapped, iconified, or dropped below the ASE window.
