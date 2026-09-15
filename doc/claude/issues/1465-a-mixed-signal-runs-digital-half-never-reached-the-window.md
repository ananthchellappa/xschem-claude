# 1465 — A mixed-signal run's digital half never reached the window

**Status:** fixed by Stage 12 of `doc/claude/ase_analyses_batch/` (event-driven results).
**Suite:** `tests/headless/test_ase_events_1465.tcl` (T1 `hcases`, headless only).
**Receipt:** `doc/claude/ase_analyses_batch/receipts/40-stage-12-event-results.md`.
**Ruling:** ⚖ R9 — the sentences below are recommended copy, recorded with
`owed.sh add rule 1465`.

## What the user met

XSPICE is compiled into every ngspice this batch supports, so a deck with a digital gate in it
is an ordinary deck. An ASE-L run of one produced a rawfile holding `time i(adac) v(aout) v(in)
i(vin)` and **not** `din` or `dout`: `write <f> all` omits every event node without a word, and
`-b -r` discards them. The digital half was simulated and thrown away, and the window showed an
analog-only result as though that were the whole circuit.

## What was measured before a line was written (2026-09-15, apt 45.2 AND the ngspice-46+ fork)

| fact | 45.2 | fork |
|---|---|---|
| `edisplay` in a deck with no analysis lists every event node, counts 0 (rc 1, "no simulations run") | yes | yes |
| `.probe alli` beside a digital node | `Error: Dot command '.probe alli' and digital nodes are not compatible.`, exit 1 | identical |
| `.probe alli` beside an analog-only `a` card (`gain`) | rc 0 | rc 0 |
| `Reducing trtol to 1 for xspice 'A' devices` on an analog-only `a` card | printed | printed |
| `set xtrtol=7` | `Override trtol to 7 for xspice 'A' devices` | identical |
| `eprvcd` with 94 names | `ERROR - eprvcd currently limited to 93 arguments`, empty file, rc 0 | identical |
| `$&` of a 30 ns end in fs, with and without `set numdgt=17` | `3E+07` | `3E+07` |
| name characters through the control-language lexer (via `eprint`) | `_ - + : # @ / .` survive; `$` substitutes; `% < > ' [ ]` refused at parse; `~ = ,` split at parse | identical |
| §12.1 DC sweep through an auto-bridge (`v(out)` should fall at 1.65 V) | stays 3.3 V throughout | identical |
| §12.2 the same bridge written ahead of the gate | falls at 1.8 V | identical |

And, from the driver's debt-M9 measurement (`evidence/m9-event-vcd-attach.md`): the VCD attaches
beside the rawfile under the nodes' ngspice names; its traces END at the last value change; and an
analog argument to `eprvcd` aborts 45.2.

## What shipped

* **The inventory** — `ase::event_nodes` (the cold door) and `ase::event_nodes_peek` (never starts
  a program), cached per program + arguments + stamp + probe deck. The adapter's `event_probe`
  hook builds the probe deck (netlist, includes, libraries, parameters, `pre_` commands,
  `edisplay`; nothing that writes) only for a circuit with an `a` card, with the run's own words
  (`run_cmd` asked with a new `quiet` argument, so the stale-entry sentence is not said twice);
  `event_inventory` runs it in the run directory under the
  probe budget; `event_parse` reads it. Taken by `ase::run_deck` immediately before render — after
  the pre-deck file and the co-simulation models are in place — and by `ase::campaign_prepare`.
* **The emission** — one `eprvcd <names> > <rundir>/<cell>_ase_evt[_N].vcd` per 93 exportable
  names, at the end of each transient's block: below the `$sim_status` guard, below `remzerovec`
  and the `write`, below every positional anchor. Only the inventory's names; a name the lexer
  would split is left off and named in the CIW.
* **The attach** — `ase::last_vcdfiles` serves the event VCDs after the co-simulation ones;
  `ase::run_deck` deletes them before a run.
* **The run end** — `xschem raw read <f> vcd -end <seconds>` (C: `src/scheduler.c`,
  `src/vcd_read.c`, `src/xschem.h`); `ase::attach_dbs` passes the analog database's last scale
  value when that database is a transient. Only ever extends.
* **Two cautions** — a new `xspice` precondition on `tran` and `dc`, evaluated by core, worded by
  the adapter's `xspice_caveat` hook, with no fallback for a backend without it.
* **One refusal** — `ase::event_refusals`, read from the peek: by the gate (an earlier run's
  measurement, before anything is deleted) and by `render_deck` (a first measurement, before the
  deck is written).

## ⚖ R9 — the new sentences

```
this circuit has XSPICE devices, so the simulator lowers trtol to 1 and takes smaller time steps than the options ask for
add `set xtrtol=<n>` to this analysis's verbatim lines to choose the value yourself
a DC sweep does not always reach digital nodes through the bridges the simulator inserts on its own
write the bridge devices into the netlist yourself, ahead of the digital devices
this circuit has digital nodes, and with `.probe alli` the simulator exits before it simulates anything
remove `.probe alli` from the netlist
ase: this circuit cannot run: <sentence>
ase: left out of the VCD, because the export command cannot take these digital node names: <names>
```

## Declared limits

* An `a` card that lives only inside an `.include` is not seen by the gate that decides whether to
  ask, so that circuit's digital half stays unexported (the same limit `ase::netlist_facts` states).
* An included file edited in place keeps its path and so keeps the cached inventory until the
  netlist or the binary changes.
* The probe is synchronous: one extra read of the circuit, once per distinct circuit, before the
  first run of a mixed-signal bench.
* A bench with two enabled transients exports the second's event history to the same file.
