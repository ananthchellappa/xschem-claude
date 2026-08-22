# 0604 — a parameter the descriptor asked for and the raw did not deliver must be REPORTED, not merely blank

STATUS: **OPEN — approved in principle 2026-08-22, mechanism owed.** This is
invariant **I8**, added to `doc/claude/specs/op_annotation.md` by ruling **D9**.
Related: 0429 (the measurement that motivates it), **I3** (what the schematic
shows), 0482 (a resident raw is not re-read).

---

## The decision

The user's words: *"We can report a mismatch between expectation and actual
delivery from ngspice as a warning in CIW and logfile."*

I3 is unchanged and is about the **schematic**: a missing vector renders blank,
never 0, never a fabricated number, never the previous run's. I8 is about the
**tool**: the mismatch between what the descriptor asked for and what arrived is
said out loud, once, in the CIW and in the logfile.

## Why a blank row is not enough

A blank row cannot distinguish three completely different situations, and the
user needs to tell them apart:

1. **The device is off / the number is genuinely absent from this analysis.**
   Nothing is wrong.
2. **The simulator does not know that parameter.** Measured on ngspice-42 with
   real sky130 models: a `.save @m.…[cgso]` card is rejected, ngspice exits **0**,
   and the only trace anywhere is one line —
   `Warning from checkvalid: vector @m.xm1.…[cgso] is not available or has zero
   length` — in a log the user is not reading.
3. **No raw file was written at all.** The same rejected card, under the
   `.control … write <cell>.raw … .endc` idiom every shipped PDK bench uses,
   suppresses the **entire** raw. Every waveform and every node voltage is gone,
   still at exit 0. From the user's chair the simulation "succeeded" and the
   schematic is simply blank.

Case 3 is the one that cost the whole run, and it is indistinguishable from
case 1 on screen.

## What has to be decided before implementing

* **Where the CIW output goes.** xschem has no single "command interpreter
  window" by that name; the candidates are the Tcl console, the status line, and
  `puts stderr` (which lands in the logfile the harness already captures). The
  logfile half is easy; the on-screen half needs a home that a user running the
  GUI actually sees.
* **Dedup key.** Once per (device, parameter) per **annotate pass** — not per
  redraw. `op_annot::text` is called on every frame for every annotated device,
  so a naive `puts` inside the formatter would flood the console at the redraw
  rate. The natural anchor is the same invalidation epoch S9b built for the
  render cache (`annot_data_changed()` and the four enumerated inputs).
* **Whole-raw absence vs one absent vector.** These deserve different sentences.
  "3 of 6 parameters missing on 12 devices" is a summary a user can act on;
  "no raw file loaded" is a different message entirely and should not be
  reported 72 times.
* **Whether an unannotated schematic says anything at all.** A user who has not
  simulated yet must not be nagged.

## Not urgent, and say why

Under D9 no *default* row can provoke case 2 or 3: all six defaults are measured
savable on ngspice-42 and 46+, on sky130 and gf180. The warning becomes load
bearing the moment a user adds a parameter of her own (issue 0603) — which is
exactly when she is least able to guess why the screen went blank.
