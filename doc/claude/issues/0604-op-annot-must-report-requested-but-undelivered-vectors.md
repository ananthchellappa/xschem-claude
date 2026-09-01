# 0604 — a parameter the descriptor asked for and the raw did not deliver must be REPORTED, not merely blank

STATUS: **OPEN — approved in principle 2026-08-22, mechanism owed.** This is
invariant **I8**, added to `doc/claude/specs/op_annotation.md` by ruling **D9**.
Related: 0429 (the measurement that motivates it), **I3** (what the schematic
shows), 0482 (a resident raw is not re-read), 0607 (65 of 78 vectors lost in
silence: the sharpest argument that this must be built).

**THREE OTHER ISSUES NOW RIDE ON THIS ONE**, all ruled by the user 2026-08-22:
**0444** (a mis-tokenised `@`-token that silently substituted nothing),
**0446** (via 0603 — a silently truncated row the user asked for) and
**0447** (a malformed descriptor key). Each resolves to the same sentence: *the
tool says out loud what it was asked for and did not deliver.* Building three
warn-once mechanisms with three dedup keys is the **I1** drift shape this
subsystem exists to prevent, which makes this issue the next implementation step
rather than a nice-to-have.

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


## The bracket case — ruled into this issue 2026-08-22

Issue **0444**: `xschem translate` tokenises on `SPACE(c)` (`src/token.c:24`),
which does not include `)`. A user who writes the natural

```
expr(@#1:spice_get_voltage - @#2:spice_get_voltage)
```

gets the second token read as `@#2:spice_get_voltage)`, which misses
`get_tok_value()` and appends **nothing** — no error, no warning, the line comes
out short and the row renders blank. Measured still live 2026-08-22:

```
no-space  -> | - |
space     -> | -  |
```

The user ruled: **warn once; do not change `SPACE(c)`.** Changing the macro
governs every @-token in the tree and is an audit, not a fix.

**That warning belongs here, not in its own mechanism.** I8 as filed covers *the
raw did not deliver this vector*; the bracket case adds *the substitution never
asked for it, because the name was mis-tokenised*. From the user's chair both are
"the number is blank and nothing told me why" — and the second is worse, because
her descriptor never reached the simulator at all. Two warn-once mechanisms with
two dedup keys would be the I1 drift shape.

**Concrete requirement:** when an @-token finds no value **and** ends in a
bracket, report it once — CIW and logfile — through the same seam and the same
dedup key as the missing-vector case. The bracket test is what keeps it quiet: an
@-token that simply resolves to empty is ordinary and must stay silent.

## The malformed-descriptor case — ruled into this issue 2026-08-22

Issue **0447**: `op_annot::register` validates only `dict size`, so a descriptor
whose `params`, `pinexpr` or `derived` value is not a well-formed Tcl list is
**accepted at rc=0** and stored. The raise then happens at DRAW time inside three
uncaught `foreach`es (`src/op_annot.tcl:652`, `:672`, `:689`), is absorbed by
`tcl_hook2`, and the block renders a single **`?`**. One unbalanced brace in a
hand-written descriptor is the whole trigger — and hand-written Tcl is the only
interface the feature has until 0603 lands.

The user rejected the obvious fix (reject loudly at registration) on a
measurement: a raising `register` **aborts the rest of the user's rc**, so later
settings silently do not apply and nothing says so. It moves a silent failure
rather than removing one.

**Concrete requirement:** `op_annot::register` validates the three list-valued
keys and, on failure, **reports through this channel — naming the symbol type and
the key — while still returning rc=0** so the rc runs to completion. A read-side
catch in `op_annot::text` is required alongside it, because **I5** lets a
descriptor be replaced at any time from any rc.

Note the reporting point differs from the other riders: this one fires at
**registration**, not during an annotate pass. The dedup key must accommodate
both, or the once-per-pass rule will either suppress a registration report or
repeat it on every redraw.
## "Not urgent" — REVISED 2026-08-22

The section below was written when this issue stood alone. Three rulings have
since ridden onto it (0444, 0446/0603, 0447), two of them describing failures a
user reaches with a single typo. The original argument — that no *default* row
can provoke case 2 or 3 — still holds and is unchanged. What has changed is that
the warning is no longer only about undelivered vectors.

## Not urgent, and say why

Under D9 no *default* row can provoke case 2 or 3: all six defaults are measured
savable on ngspice-42 and 46+, on sky130 and gf180. The warning becomes load
bearing the moment a user adds a parameter of her own (issue 0603) — which is
exactly when she is least able to guess why the screen went blank.
