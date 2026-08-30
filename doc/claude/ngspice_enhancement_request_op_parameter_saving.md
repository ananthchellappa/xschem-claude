# Enhancement request to ngspice — a blanket way to save device operating-point parameters

**To:** the ngspice project
**From:** the XSCHEM / ASE-L integration (schematic capture, netlisting, and
back-annotation of operating-point values onto the schematic)
**Date:** 2026-08-29
**Measured against:** ngspice-46+, git `c76219a37` (2026-08-09), built locally;
`/usr/local/bin/ngspice`
**Status:** draft — not yet sent

---

## 1. The ask, in one paragraph

ngspice has no way to say *"save the operating-point parameters of every device
in this circuit."* Currents have exactly that — `.options savecurrents` — and
node voltages have `.save all`, but the small-signal and bias quantities a
designer actually annotates (`gm`, `gds`, `vth`, `vdsat`, `vgs`, `vds`, …) can
only be requested **one device and one parameter at a time**. A tool that wants
to annotate a schematic must therefore enumerate every device itself, construct
each device's SPICE name inside its model subcircuit, and emit one `.save` card
per device per parameter. We are asking for a blanket form. **The mechanism
already exists in the code base** — `inp_savecurrents()` is precisely the shape
the answer should take.

## 2. Why we are asking — the concrete case

XSCHEM annotates operating-point values directly onto the schematic (the
designer presses a key and each transistor shows its `id`, `gm`, `gds`, `vgs`,
`vth`, `vds`). To do that it must first get those numbers into the raw file.

On a real bandgap reference testbench in the sky130 PDK, with 78 flattened
transistors, the generated deck carries:

```
.save @m.xm1.msky130_fd_pr__nfet_01v8[id]
.save @m.xm1.msky130_fd_pr__nfet_01v8[gm]
.save @m.xm1.msky130_fd_pr__nfet_01v8[gds]
...
```

**468 cards** — 78 devices × 6 parameters. On a 500-device block it is ~3000.
That is the *small* problem. The real costs are these:

1. **The tool must know each device's name inside the PDK's model subcircuit.**
   `@m.xm1.msky130_fd_pr__nfet_01v8` is not derivable from the schematic; it is a
   property of the PDK's subcircuit definitions and of ngspice's naming. sky130
   needs a four-branch rule to construct it, GlobalFoundries gf180mcu a
   different one, IHP SG13G2 another. Each PDK needs a hand-written descriptor
   before annotation works at all.
2. **Getting it wrong is silent.** A `.save` card naming a device that does not
   exist is accepted without complaint, produces no vector, and yields no
   diagnostic. The user sees a blank annotation and nothing else. This is the
   single largest source of support burden in the feature.
3. **The tool must walk the design hierarchy** to enumerate devices before it can
   emit anything — work the simulator has already done, and which the simulator
   is in a far better position to do correctly.

A blanket request removes all three at once.

## 3. The paragon — what Spectre does

Spectre lets the *simulator* answer the question:

```
save *:oppoint
```

One statement. It means "for every instance, save its operating-point
information." The integrating tool supplies **no device list, no parameter list
and no knowledge of subcircuit-internal naming**. Spectre knows its own devices;
it writes their operating-point data into the results database, and the tool
reads it back by name.

This is the right division of labour, and it is why operating-point annotation
"just works" on any PDK in that ecosystem while it needs bespoke per-PDK
configuration in ours.

## 4. What ngspice offers today — measured

Every row below was measured on the version named above, on purpose-built decks
plus a real sky130 bench.

| Mechanism | Result |
|---|---|
| `.save all` | Node voltages and voltage-source branch currents only. **No `@…` device vector of any kind.** |
| `.options savecurrents` | Terminal **currents** only — 4 per MOS, 1 per resistor. No `gm`, no `gds`, no `vth`. |
| `.probe` / `.probe alli` | Same content as savecurrents under different names. `.probe allp` → `Warning: Strange parameter in line *probe allp, ingnored`. `.probe @m1[gm]` → ignored. |
| `save @m1[all]`, `save @m1[*]`, `save @m.*`, `save @m*[gm]` (in `.control`) | `Warning from checkvalid: vector … is not available or has zero length`, then `Error during 'write': no writable vector found`. |
| `write out.raw all @m*` / `@*` | `Error: no such device or model name m` / `PPerror: syntax error in line segment`. |
| `op_save`, `opsave` | `no such command available in ngspice`. |

The grammar confirms it. `settrace()` (`src/frontend/breakp2.c:68`) recognises
exactly two special words — `all` and `nosub` — and treats every other token as a
node name. `help save` documents only `save [all] [node ...]`. Grepping the
tree for a `saveparams` / `saveoppoint` / `saveopinfo` equivalent returns
**nothing**.

### 4.1 One trap worth fixing regardless

A **deck-level** wildcard does not error — it corrupts:

```
.save @m1[all]
```

→ `Warning: unrecognized variable - @m1[all]`, then `No. of Data Columns : 1`.
The raw file contains a single bogus vector named `v(@m1[all])` whose value is
`0.0`, **and every other vector — including the node voltages that would
otherwise have been saved — is gone.** The same input inside `.control` is
rejected cleanly. We would suggest the deck-level path reject it the same way.

## 5. The primary request

**A blanket option that saves the operating-point parameters of every device**,
in the spirit of `.options savecurrents`. A spelling such as:

```
.options saveopparams          * or: save *:oppoint, or .probe allop
```

### 5.1 Why we believe this is a small change

`inp_savecurrents()` (`src/frontend/inp.c:2416`) already does the whole job for
currents:

* it checks whether the option is present;
* it walks the deck's card list, switching on the device letter;
* for each device it emits a `.save @<name>[<param>] …` line by `tprintf`;
* it prepends `.save all` when the user gave no other save, so the blanket does
  not cancel the implicit save-everything.

A `saveopparams` sibling is the same function with a different parameter list per
device type.

**And one property of its call site makes it work for free where a tool cannot.**
`inp_savecurrents()` is invoked at `src/frontend/inp.c:1081`, *after* subcircuit
expansion — the deck it scans is flat, and the very next comment in the file says
so ("Circuit is flat, all numbers expanded"). That is why
`.options savecurrents` already produces correctly hierarchical names such as
`i(@m.xm1.msky130_fd_pr__nfet_01v8[id])` on the sky130 bench above. A sibling
would inherit exactly that, which is the hardest part of the problem for an
external tool and a non-problem inside ngspice.

### 5.2 Which parameters

We would rather not prescribe. Two workable answers:

* **Everything the device publishes.** Measured: naming a device with no bracket
  on a `write` line already dumps all of them — 75 parameters for a level-1 MOS,
  89 for BSIM4 — so the per-device set is already well defined internally.
* **A useful subset per device type**, the way `savecurrents` has
  `savecurrents_bsim3` / `savecurrents_bsim4` / `savecurrents_mos1` variants.
  For MOS the annotation-relevant set is `id gm gds vth vgs vds` (plus `vdsat`,
  `gmb`).

Either is a large improvement. The first is simpler and needs no per-model
curation.

### 5.3 Scoping to an analysis

Because a `.save` applies to every analysis in a deck, device parameters
requested for an operating point are also sampled at **every timepoint of a
transient**. Measured, 500 devices × 6 parameters:

| analysis | Δ wall clock | Δ raw size |
|---|---|---|
| `.op`, 1 point | +0.03 s | +107 KB |
| `.tran`, 10 068 points | **+8.6 s** | **+242 MB** (40.7 → 282.4 MB) |

≈ 8.0 bytes and ≈ 285 ns per (device × parameter × timepoint). Not I/O bound —
writing to `/dev/null` is just as slow.

If a blanket option could apply **to the operating-point analysis only** (or if
there were a documented way to change the save set between analyses in a
`.control` block), that whole cost would disappear. This is a secondary but
genuinely valuable part of the request.

## 6. Secondary items

These are smaller and independently useful. Two are arguably bugs.

### 6.1 `show` is the right idea, but its output cannot be parsed

`show` with no argument already does the semantic thing we want — one command,
every device, every operating-point parameter, including devices inside
subcircuits, in 0.01 s for 500 devices. It is unusable as a machine interface
for one reason: the device-name column is truncated to **21 characters**
(`DEV_WIDTH` in `src/frontend/device.h:11`, applied via `"%*.*s"` in
`src/frontend/device.c`), and `set width=200` does not widen it.

Measured: `m.xtop_level_analog_bank.xfirst_stage_device.mdev` and
`m.xtop_level_analog_bank.xsecond_stage_device.mdev` produce **byte-identical
column headers** (`m.xtop_level_analog_b`) and cannot be told apart. Column order
is also reversed relative to netlist order.

Either honouring `set width`, or a machine-readable mode (one
`name<TAB>param<TAB>value` triple per line), would make `show` a complete answer
on its own.

### 6.2 `write file.raw @dev` is silently wrong in multi-point analyses

Naming a bare device on a `write` line writes all of that device's parameters —
excellent, and it round-trips exactly under `.op`. Under `.tran` (208 points) and
`.dc` (11 points), however, every device-parameter vector is emitted with
`dims=1` inside a multi-point plot: **one sample is non-zero and the remaining
207 are 0.0**, and the non-zero one is the end-of-run value parked at index 0.

Measured identity: the expansion's `gm[0]` equals the explicit-`.save`
reference's `gm[207]`, while the true `gm[0]` differs. No warning, no error, a
well-formed raw file. A viewer plots a spike at t=0 and a flat zero line. The
explicit `.save @m…[gm]` path on a byte-identical deck gives genuinely
time-varying values at all 208 points, so this looks like a defect in the write
path rather than a limitation.

### 6.3 Deck-level `.save @m1[*]` should be rejected

See §4.1 — it currently poisons the whole raw file rather than erroring.

## 7. Workarounds we evaluated and rejected

Recorded so the request does not read as under-researched.

* **Parse `show` output** — blocked by §6.1's truncation.
* **One `write out.raw all @dev1 @dev2 …` naming every device** — works, is
  O(devices) rather than O(devices × parameters), and our existing raw reader
  consumes the result unchanged. But it still requires the tool to enumerate
  every device and to know its subcircuit-internal name, which is the actual
  problem; and it is unsafe outside a single-point analysis per §6.2.
* **Query `@m1[gm]` on demand after the run** — works interactively, but our flow
  is batch (`ngspice -b`); by the time the results are read the simulator is
  gone.
* **`.options savecurrents`** — currents only, and the annotation the user asks
  for is mostly not currents.

## 8. What "done" would look like for us

1. A deck can request device operating-point data **without naming any device**.
2. The resulting vectors carry the same hierarchical names `.save` produces
   today, so existing readers need no change.
3. Devices inside PDK model subcircuits are included, at any depth.
4. A request that cannot be honoured says so, rather than yielding a raw file
   with nothing in it.

Item 4 matters as much as the rest. The present failure mode of this whole area
is silence: a wrong card is accepted, no vector appears, and the user is left
with a blank annotation and no diagnostic anywhere.

## 9. Environment and reproducibility

* ngspice-46+, git `c76219a37`, 2026-08-09, locally built, KLU direct solver.
* Decks: purpose-built level-1 MOS cases plus sky130A BSIM4 (`sky130.lib.spice`,
  `tt`) with devices two and three subcircuit levels deep.
* Every measurement in §4, §5.3 and §6 is reproducible from a deck of under
  thirty lines; we are glad to supply them, or a patch, if the direction is
  welcome.

## 10. In short

ngspice already has the machinery — `inp_savecurrents()` walks a flattened deck
and generates save cards, which is exactly the operation being asked for. What is
missing is the same treatment for operating-point parameters. Spectre's
`save *:oppoint` is the behaviour to match: the simulator knows its devices, so
the simulator should be the one to enumerate them.
