# 0307 — the co-simulation design walk is flat, so a code block below the netlisted schematic gets `cell=''`, `vfile=''` and a fabricated scope hint

**Status:** OPEN, documentation only. Nothing was fixed and no test was written for it.
**Area:** `src/ase.tcl` — `ase::cosim_design_scan` (`:979`), consumed by `ase::cosim_map`
(`:1046`); the underlying enumeration is `xschem instance_list` (`src/scheduler.c:6458-6472`).
**Found:** 2026-08-09, while ruling open decision 5 of
`doc/claude/specs/mixed_signal_signal_browser.md` (batch F item 3). It is not a regression from
that item — no code changed — but the ruling's key ladder has to work around it, so it is
written down rather than left as folklore in a spec paragraph.
**Related:** the same flatness is already acknowledged in §E6 of that spec ("a block ASE cannot
check never blocks the run"), which is the *build* consequence. This issue is about the two
consequences §E6 does not cover: the map artifact's `lib`/`cell`/`vfile` fields, and the
`scope` hint.
Numbered 0307, continuing the local sequence above 0305/0306.

---

## Mechanism

`ase::cosim_design_scan` builds `instname -> {inst symref lib cell module vfile}` for every
instance **of the current schematic** whose cell has a `verilog` view:

```tcl
proc ase::cosim_design_scan {} {
  set out [dict create]
  if {[catch {xschem instance_list} lst]} { return $out }      ;# src/ase.tcl:981
  foreach {inst symref type} $lst { ... }
```

`xschem instance_list` is a flat loop over `xctx->instances` (`src/scheduler.c:6458-6472`) — one
level, the loaded schematic, no descent. `ase::cosim_map` then joins the deck scan against that
walk **by instance name only** (`src/ase.tcl:1072-1079`), so a `d_cosim` code block that lives
one level down is invisible to it: the walk sees the *subcircuit* instance `x1`, whose cell has
no `verilog` view and is therefore skipped outright, and never sees `a1`.

Three fields of the map entry are the casualties, and one of them is worse than empty:

| field | value for a buried block | why it matters |
|---|---|---|
| `lib`, `cell` | `{}` | the F2 join key of RULING 5b (rungs 1 and 2) is dead |
| `vfile` | `{}` | E6 cannot stamp-check the `.so` against the `.v` — the §E6 gap, already documented |
| `module` | **the `.model` card's name**, via the fallback `if {$module eq {}} { set module [dict get $e model] }` (`src/ase.tcl:1086`) | rung 3 is not an independent key either — `module` and `model` are the same string twice |
| `scope` | `TOP.<the .model card's name>`, written unconditionally at `src/ase.tcl:1091` | **a hint that names a scope which need not exist in any VCD, with no `.v` behind it** |

The sidecar fallback (`src/ase.tcl:1080-1085`) cannot rescue this: it copies `lib`/`cell`/
`vfile`/`module` from the *previous map*, and the previous map has the same holes for the same
reason.

## Reproducer

The topology is the spec's own canonical one — `tb → x1 (dig_top) → a1 (counter)` — built as a
throwaway fixture library, netlisted for real, then run through `ase::cosim_map`:

```
PROBE-1 instance_list on tbh: {x1} {dlib/dig_top} {subcircuit}
PROBE-3 cosim_design_scan keys:            <- EMPTY
PROBE-4 netlist:
   | **.subckt tbh
   | x1 net1 net2 dig_top
   | **.ends
   | .subckt dig_top clk q
   | a1 [ net1 ] [ net2 ] dcell
   | .ends
   | .model dcell d_cosim simulation="./dcell.so" sim_args=["dcell.vcd"] delay=0
PROBE-5 entry: model='dcell' lib='' cell='' module='dcell' vfile='' insts='a1' scope='TOP.dcell'
PROBE-6 f1 for a1: lib='dlib' cell='dcell' module='dcell'
```

Variant B — identical design, the `.model` card renamed to `cnt8` while the cell's `.v` still
declares `module dcell` (legal: `device_model` is free instance text and the symbol template
merely *defaults* `model` to the cell name):

```
PROBE-5 entry: model='cnt8' lib='' cell='' module='cnt8' vfile='' scope='TOP.cnt8'
PROBE-6 f1 for a1: lib='dlib' cell='dcell' module='dcell'
```

`TOP.cnt8` exists nowhere. Measured against the reference VCD, which declares
`$scope module TOP` / `$scope module counter`, a query of that shape can only ever miss:

```
VPROBE index 'TOP.counter.clk' -> 7
VPROBE index 'top.counter.clk' -> -1
```

The variant-A case *looks* fine only because the user happened to name the card after the
module. That coincidence is what makes this worth an issue: today's behaviour is right by
accident and silently wrong on a rename.

## Consequences

1. **F2 (the Signal Browser branch)** — RULING 5b's cell key cannot fire for a buried block.
   The ruling covers the case with rung 4 (the entry's `model` against the selected instance's
   own `model=` property, which is the same string by construction) and forces the scope onto
   the derived path whenever `vfile` is empty, so the browser answers correctly or refuses —
   but it answers with no `.v` linkage.
2. **E6 staleness** — already documented and deliberately non-blocking.
3. **The `scope` field is written even when nothing was read.** Whatever else is done, the
   honest minimum is to *not* record a hint that has no `.v` behind it, or to mark it.

## Proposed fix, not implemented

Give `cosim_design_scan` a hierarchical walk, so `lib`, `cell`, `vfile` and a real `module` are
populated for blocks below the top schematic. Two candidate shapes, neither costed:

* descend per level in Tcl over the existing `xschem` verbs (`instance_list` + a descend/ascend
  pair), recursing into instances whose type is `subcircuit`; or
* a hierarchical enumeration verb in `scheduler.c` beside `instance_list`.

The deck-side alternative — recovering `x1.a1` from the netlist text, which *does* contain the
hierarchy, and which `cosim_scan_deck` already half-walks (`curblk`, `src/ase.tcl:877-886`;
`cosim_subckt_counts`, `:914-971`) — recovers an instance **path** but not the block's **cell**,
because the code block's cell name never appears in the deck (the symbol's `format` emits
`@name … @model`, not the cell). It also cannot produce a unique path: one `.subckt`
instantiated twice puts the same block at `x1.a1` and `x2.a1`. So it is not a substitute for the
design walk.

Whichever is taken, it is **additive** to the open-decision-5 ruling: the join key stays the
cell, the scope hint stays a hint, and rung 4 stays as the fallback.
