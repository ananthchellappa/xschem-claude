# 0442 — op_annot's walk filters three of the netlister's seven drop classes

STATUS: **OPEN.** Measured on branch `annotate`, step S3b, 2026-08-16.
**This is the defect that refuted S3b and caused its revert.**
Successor to 0437 (which fixed three classes); blocks the S3 deliverable.

Related: 0437 (the three classes that WERE fixed), 0434 (the failure mode is
idiom-dependent), 0429 (the same harm, used there as grounds to delete a
parameter), 0436 (the other S3b fix, which survived every attack).

---

## The claim that was refuted

S3b shipped `op_annot::save_cards` whose own header (src/op_annot.tcl:647 in the
reverted patch) asserts, in a boxed comment:

```
# ⚠ THE WALK EMITS ONLY WHAT THE NETLISTER WOULD (issue 0437)
```

That is **measurably false**. `op_annot::_netlisted` implements three of the
SPICE netlister's drop classes (`spice_ignore`, `only_toplevel`, `lvs_ignore`)
and misses four more. Cards are emitted for devices that are nowhere in the
generated deck, which is precisely the defect class 0437 was filed about,
arriving through a different door.

The brief for the step said, in as many words:

> Filter what the netlister would skip (spice_ignore, and whatever else
> `xschem netlist` actually drops — **measure it, do not assume**)

Three classes were measured. The remaining four were assumed absent.

---

## The four missing classes, located in the C

All four are in `spice_block_netlist()` (`src/spice_netlist.c:616`), and each
returns or diverts BEFORE the subcircuit body is traversed:

| # | Class | C site | What the deck ends up containing |
|---|---|---|---|
| 1 | symbol `format` empty/absent | `spice_netlist.c:639` `if(!strcmp(get_tok_value(...,"format",0),"")) return err;` | **Nothing at all** — no call line, no `.subckt`. The instance vanishes. |
| 2 | symbol `default_schematic=ignore` | `spice_netlist.c:643` | Call line present, **no `.subckt` definition** emitted. |
| 3 | symbol `spice_sym_def` | `spice_netlist.c:665` | `.subckt` body is the **attribute text**; the schematic is never traversed, so no device inside it exists. |
| 4 | symbol `spice_stop=true` | `spice_netlist.c:635` + `:695` | `.subckt` emitted but **EMPTY** — `load_schematic(0,...)` + `spice_netlist(fd,1)` skip the contents. |

Classes 3 and 4 are ordinary, widely used xschem symbol attributes — `spice_sym_def`
is exactly how a symbol carries its own `.subckt` text — so this is reachable on
real PDK designs, not a contrived shape.

---

## BEFORE (the Measure agent's transcript, verbatim)

The step's own baseline recorded the netlister as the oracle for **one** class
only, and recorded that the suite could not see any other:

```
netlist rc/err                           '1'
NETLIST-LINE: XMOK net3 net4 net5 net6 sky130_fd_pr__nfet_01v8 L=0.15 W=1 ...
MOK  appears in netlist                  1
MIGN appears in netlist                  0
```

```
$ grep -cE 'raw_read|annotate_op|spice_ignore' tests/headless/test_op_annot.tcl
0
```

and, on the shape of the filter that was then built:

```
$ grep -cE 'spice_ignore|only_toplevel|skip_instance' src/op_annot.tcl
0
```

## AFTER (measured by the write-up agent, independently, on the S3b tree)

Fixture `verifyc/lib/vtop.sch`: three subcircuit instances, one plain, one
carrying `spice_sym_def`, one carrying `spice_stop=true`; each subcircuit's
schematic holds one device `MA` that the descriptor claims.

`xschem netlist` — the oracle — writes:

```
  | xplain net1 vsub
  | xdef net2 vsymdef
  | xstop net3 vstop
  | **.ends
  | .subckt vsub A
  | XMA net1 nch          <-- the ONLY XMA in the deck
  | .ends
  | .subckt vsymdef A
  | Rfake A 0 1k          <-- attribute text; no XMA
  | .ends
  | .subckt vstop A
  | .ends                 <-- EMPTY; no XMA
```

`op_annot::save_cards` on the same design emits:

```
  | .save all
  | .save xplain.xma[gm]
  | .save xdef.xma[gm]     <-- device does not exist in the deck
  | .save xstop.xma[gm]    <-- device does not exist in the deck
```

Second fixture `verifyc/lib/vtop2.sch` (`default_schematic=ignore` and a symbol
with no `format`):

```
  | xplain net1 vsub
  | xign net2 vign         <-- call present, no .subckt vign defined
  |                        <-- xnofmt ABSENT ENTIRELY
```
```
  | .save all
  | .save xplain.xma[gm]
  | .save xign.xma[gm]     <-- subckt never defined
  | .save xnofmt.xma[gm]   <-- instance is nowhere in the deck
```

`op_annot::write_save_file` writes that block to `$netlist_dir/<cell>.save`, and
the new menu item hands the user that file.

---

## Severity: each bad card destroys the ENTIRE raw, on BOTH binaries

The shipped code's own comment (src/op_annot.tcl:649-651 in the reverted patch)
states the harm model as:

> ngspice writes a full column under exactly the name asked for, holding 0.0,
> with only `Warning: unrecognized variable` on stderr (spec landmine 9)

**That is wrong, in the worse direction.** Re-measured here under the DOT-CARD
idiom that `save_cards` actually generates (`.save` cards before `.op`, `run` +
`write` inside `.control`) — which is the idiom ruling R2/D8 established as the
only one that works at all:

```
== /usr/bin/ngspice (42)   : bogus prefix   rc=0 raw=NO checkvalid=1
== /usr/local/bin/ngspice  : bogus prefix   rc=0 raw=NO checkvalid=1
== /usr/bin/ngspice (42)   : missing device rc=0 raw=NO checkvalid=1
== /usr/local/bin/ngspice  : missing device rc=0 raw=NO checkvalid=1
```

Control decks identical but for the single offending `.save` line write the raw
on both binaries (`rc=0 raw=YES checkvalid=0`). So under the shipped idiom
**both** bad-card shapes — a missing instance prefix and a missing device inside
a present instance — suppress the whole raw file while the exit status stays 0.

Verify-C observed a `dims=0` empty vector for the second shape; that was under a
different invocation idiom. **Issue 0434 already records that this failure mode
is idiom-dependent**, and this measurement pins the shipped idiom's behaviour:
total, silent raw loss for either shape.

### Why that is disqualifying rather than a wart

Ruling **D8**, made in this same step, deleted `cgso`/`cgdo` from the sky130
descriptor on exactly this criterion, in its own words:

> a feature that destroys the data it exists to display is not shippable

D8's harm was **ngspice-42 only**. This one is **both binaries**. The step
therefore removed a parameter to prevent a harm while shipping a walk that
causes the same harm more broadly — an internal contradiction, and the reason
the step cannot be rounded up to a pass.

---

## Why 96 green checks and 8 sabotage variants did not see it

Row **S31** is the right test — it uses `xschem netlist` as the oracle and
asserts set equality between the elements the deck contains and the devices the
cards name. The oracle is sound. Its **fixture** is the problem: `s3filt.sch` is
flat, eight sibling instances, and its only variants are the
`spice_ignore`/`lvs_ignore` family that was already handled. A correct oracle
asked only about the classes already fixed cannot fail.

This is the same failure shape the retry was commissioned to fix — attempt 1's
85 checks missed two defects because no row loaded a raw or placed a
non-netlisted instance — recurring one level up: the row exists, the fixture
does not exercise it.

---

## What the fix has to be

1. Extend `op_annot::_netlisted` with the four classes. All four are **symbol**
   attributes, so the probe is `xschem getprop instance <n> cell::<attr>`:
   `format` (empty ⇒ drop), `default_schematic` (`ignore` ⇒ drop),
   `spice_sym_def` (non-empty ⇒ do not descend), `spice_stop` (truthy ⇒ do not
   descend). Note 3 and 4 drop the **subtree** while the instance call itself
   survives — so `_netlisted` and `_descendable`, which S3b made aliases, must
   genuinely diverge. That divergence is the reason the two names exist, and it
   is currently untested because nothing makes them differ.
2. Give S31 a **hierarchical** fixture carrying all seven classes. As shipped,
   `filter_skips_cards_but_still_descends` was predicted to red S31 and did not
   (Verify-B) — the flat fixture cannot observe a walk that descends into an
   ignored subtree, so decision D6 has exactly one guardian (S28), not two.
3. Correct the two false comments in `op_annot.tcl` (the "EMITS ONLY WHAT THE
   NETLISTER WOULD" box, and the 0.0-column harm model) and **spec landmine 9**,
   which asserts the same wrong harm model.

A cheaper and more durable alternative worth weighing first: rather than
re-implementing the netlister's filter in Tcl a class at a time — this issue is
the second time that has drifted — derive the device set FROM `xschem netlist`
output, or expose `skip_instance()` to Tcl so there is one filter rather than
two. The C is the only thing that knows all seven classes, and it will grow an
eighth.

---

## Still open

- The four classes above, unfiltered.
- `_netlisted` hardcodes the SPICE class; `skip_instance()` branches on
  `xctx->netlist_type` (netlist.c:1247-1257), so spectre/verilog modes diverge.
- The card prefix is built from `sch_path` components, which are the instance
  `name` only. An instance with `spiceprefix=X` and `name=SUB1` yields
  `.save sub1.…` while the deck contains `XSUB1` (measured by Verify-C).
  Pre-existing — inherited from `sim_sch_path`/`@path` alike — but now
  load-bearing for a file handed to a simulator.
