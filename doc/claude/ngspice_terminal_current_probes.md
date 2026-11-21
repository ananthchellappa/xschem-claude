# ngspice terminal-current probes: a brief for XSCHEM / ASE-L

**From:** the ngspice session, 2026-11-19
**ngspice:** branch `ver_53`, commit `f53c57168`; `probe_version` in the commit after it. The full spec is that repo's
`doc/claude/specs/terminal-current-probes.md`. Upstream ngspice does not have this.
**Bears on:** issue 1724, open items 1 and 2. For a build with this feature it
supersedes two statements: the premise of `specs/ase_l.md` "Select On Design v1 scope"
that ngspice has no current-into-this-pin signal, and 1724's "What ngspice does not
give" (sky130 `ig/is/ib` absent, no vector for block pins).

## The contract

Add one line to the deck, at its top level, with the full path:

```
.probe I(<path>,<pin>) [I(<path>,<pin>) ...]
```

- **`<path>`** is the instance's hierarchical path as the netlist spells it: `xm1` at
  the top, `x1.xm1` inside `x1`. That is `op_annot::devpath` without its `@<letter>.`
  prefix and without the device inside a PDK wrapper: `@m.x1.xm1.msky130_fd_pr__nfet_01v8`
  becomes `x1.xm1`.
- **`<pin>`** is a position, 1..n on the netlist line, or a name. For an X instance
  (sky130 and IHP wrapped FETs, user blocks) the name is the port name on the `.subckt`
  line. Device letters work too: M `d g s b`, Q `c b e s`, D `a`, and `c` or `k`.
- **Raw file:** the vector is `i(<path>:<tname>)`, type `current`. Inside ngspice it is
  `<path>:<tname>#branch`.
- **`<tname>`** is computed, not echoed:
  - X: the port name from the `.subckt` line.
  - M: `d g s b_tj tc n6 n7`
  - Q: `c b e s t`
  - J/Z: `d g s`
  - D: `a c`
  - OSDI (N): the Verilog-A terminal names. IHP PSP103 gives `d g s b`.
  - Anything else: `n1 n2 …`.

  So `I(x1.xm1,3)` on a wrapper with ports `D G S B` gives `i(x1.xm1:s)`, and
  `I(x1.r1,2)` gives `i(x1.r1:n2)`.
- **Sign:** the current into the pin, the Cadence convention 1724 assumes. Never negate:
  probe the second pin of a two-terminal device explicitly.
- **Always name a pin.** `I(<path>)` alone means every pin, except on a two-terminal
  instance, where it gives a single through-current vector `i(<path>)`. That is a special
  case the pick does not need.
- **Analyses:** `op`, `dc`, `ac` (complex), `tran`. It is a 0 V source in the
  circuit, so the value is the solution: no `@dev[param]` iterate lag, and no per-model
  gaps.

## Integration rules

1. **Do not write a `.save` for a probe vector.** The probe saves itself. A second
   `.save` in another spelling duplicates the vector under `casemode=preserve`. That is
   older ngspice behaviour for any vector saved twice, and ver_52 does it too. A deck with
   no `.save` at all gets `.save all` from `.probe`. ASE-L always writes saves, so this
   does not arise there.
2. **Case:** under `fold` names are lower case. Under `preserve` they keep the deck's
   spelling, for example `x1.XM1:D`. Match them through `ase::ui::sod_case_mode`, as for
   voltages.
3. **Refusals** come on stdout as `probe: I(<path>:<pin>) not inserted: <reason>`, and
   the run continues. Surface that line. Refused today: XSPICE code-model instances,
   couplings (`K`), and E/G sources with an expression.
4. **`:` in names.** Inside ngspice control expressions, write `i(x1.xm1:d)`. A bare
   `x1.xm1:d#branch` in `let` can parse as the ternary operator. Check that the wave
   viewer and calculator tokenizers take `:` inside `i(...)`.
5. **Probes are made when the deck is read.** A new pick needs a re-rendered deck, which
   ASE-L does per run. `reset` keeps the probes.
6. **Capability:** test `$?probe_version` before writing a probe. It is set to 1 at
   start-up in the executable and in the shared library, as `stb_version` is, and it
   goes up when the names or the sign of the vectors change. An ngspice without it
   prints `Warning: Could not find the instance line for <path>` and leaves the vector
   out. 1724's own check still applies: assert that the vector exists with a non-zero
   length.

## Measured on the ver_53 build

A sky130-shaped wrapper (`XM1 out g 0 0 nfet_wrap`, `.subckt nfet_wrap D G S B`, an M
device inside) under `x1`, with
`.probe I(x1.xm1,d) I(x1.xm1,G) I(x1.xm1,3) I(x1.xm1,b) I(x1.r1,1)`. The raw file
Variables:

```
1  i(x1.r1:n1)  current
2  i(x1.xm1:b)  current
3  i(x1.xm1:d)  current
4  i(x1.xm1:g)  current
5  i(x1.xm1:s)  current
```

The values were d 62.5 µA, s −62.5 µA, g 0, b −1.7 pA (junction gmin), r1 62.5 µA.
The terminals sum to zero.

Bus-expanded instances (`XM1[1]`, `XM1[0]` inside `x1`):
`.probe I(x1.xm1[1],d) I(x1.xm1[0],d)` gives `x1.xm1[1]:d#branch` and
`x1.xm1[0]:d#branch`, 62.5 µA each.

## Not measured

- Real sky130 and IHP decks end to end. Only the wrapper shape and IHP PSP103 through
  OSDI have been run.
- `libngspice`, the shared-library build.

## Suggested shape (non-binding)

1724's items 1 and 2 become one path. A click on a pin resolves `(path, pin)`, ASE-L
writes the `.probe` line when it renders the deck, and the Saves row is `i(<path>:<tname>)`.
The fences 1724 already lists still apply: a run per device class asserting the vector
exists with a non-zero length, a bus instance, a pick from a descended sheet, and the
refusal path, now a code-model instance rather than a FET source pin. The Calculator pick
(`calc::pick_click`) should learn the same thing.

## Measured from the xschem side, 2026-11-19

ASE-L writes these probes now (issue 1724: `ase::probe_plan` in `src/ase.tcl`), and the
Calculator's current selectors pick a pin whose vector the loaded result holds
(`calc::pick_imeasure` in `src/calculator.tcl`). Measured
on the `ver_53` build (`$?probe_version` = 1) and, where named, on apt 45.2, `ver_50` and
`ver_52` (`$?probe_version` = 0). Each item corrects or sharpens a statement above, which
is left as written.

1. **A vector's `<tname>` is not always accepted back as a `<pin>`** (the contract's
   `<pin>` and `<tname>`).
   - `.probe I(r1,n1)`, top level: refused with `Warning: Node n1 is not available for
     device r1,` and `   .probe i(r1,n1) will be ignored`. `.probe I(r1,1)` gives
     `i(r1:n1)`.
   - `.probe I(x1.r1:n1)`: refused with `probe: I(x1.r1:n1) not inserted: x1.r1 has no
     terminal named n1 (1 to 2)`.
   - `.probe I(x1.m2:b_tj)`: refused with `probe: I(x1.m2:b_tj) not inserted: x1.m2 has
     no terminal named b_tj (1 to 4, or d g s b)`. `I(x1.m2,b)` gives `i(x1.m2:b_tj)`.
     `I(m1:b_tj)` at the top level is accepted.
   - An X port name round-trips: `I(x1.xm1,s)` gives `i(x1.xm1:s)`.
   - `,` and `:` are the same separator in a card. Several `I(...)` on one card and
     several `.probe` cards are taken. Terms joined by a comma are not:
     `.probe i(x1.xm1:d),i(x1.xm1:g)` drops the second with `Warning: unknown .probe
     parameter ,i(x1.xm1:g),`.
   - A term that holds a `;` cuts its card there: `.probe I(xa.xm1,d;x) I(...)` loses
     every term behind the `;`, prints `Warning: Strange parameter in line *probe
     i(xa.xm1,d, ingnored`, and writes vectors nobody asked for.
   - **`;` is not the only one** (a second sweep, each character between two good terms on
     one card; this corrects an earlier sentence here that said only `;` did harm). A `$`
     opening the pin, `I(rt,$x)`, starts a comment too: rc 0, `Warning: Strange parameter
     in line *probe i(rt,, ingnored`, and the term behind it is lost. An `=` (`I(=rt,1)`,
     `I(rt,1=)`), a `'` (`I(rt,1')`) and an opening brace (`I(rt,1{)`) are a netlist error
     at rc 1 before any analysis. A closing brace is harmless. ASE-L reads a name holding
     `;`, `$`, `=`, `'` or a brace as no terminal (`ase::probe_split`).
   - A signed number for the pin, `I(rt,-1)`, is taken, and the operating point then
     failed to converge (rc 1). ASE-L still writes that card for a typed row `i(rt:-1)`.
   - A row that names a terminal by a word the card takes and the vector is not called
     (`b` on a MOS inside a subcircuit, a position) gets its card, and the vector comes back
     under the simulator's own name: `I(x1.m2,b)` as `i(x1.m2:b_tj)` (above), `I(xa.q3,1)`
     as `i(xa.q3:c)`.
   - **The same term twice.** For a device inside a subcircuit it is taken once, without a
     message (`I(x1.r1,1)` twice gives one vector). For a TOP-LEVEL device it is not: on
     `ver_53` and on apt 45.2 `.probe I(rt,1)` plus `.PROBE I(RT,1)` prints `rt:n1#branch`
     twice, the vector is in the operating point and in the transient twice under one name,
     and on `ver_53` a second probe node stands in series with the first. A `.probe` card
     inside a `.subckt` body makes the top-level vector, and doubles with a top-level card.
   - On a card, what stands behind a `;`, or behind a `$` that follows a blank or a comma,
     is a comment: `.probe I(ra,1) $ I(rb,1)` and `.probe I(rt,1) ; I(rt,2)` each make the
     first vector and not the second.
   - What ASE-L writes: for a leaf starting with `x`, `I(<path>,<tname>)`, or the port's
     position when `<tname>` is a number (item 7); otherwise `n<k>` becomes `<k>` and
     `b_tj` becomes `b`. Each distinct term once, and not at all when the netlist's own
     `.probe` cards already hold it (`ase::probe_terms_new`; compared as text, so
     `I(m1,d)` beside `I(m1,1)` is still written twice).

2. **A symbol's pin names are not the `.subckt` port names of a PDK wrapper** (the
   contract's "for an X instance the name is the port name").
   - sky130 `res_xhigh_po_1p41`: ports `r0 r1 sub`, xschem pins `M P B` in that order (pin
     `M` is `r0`, `P` is `r1`, `B` is `sub`). `I(x1.xr2,P)` is refused. The pnp: `c b e`
     against `collector base emitter`. `cap_mim`: `c0 c1`.
   - A wrapped FET's ports match its pins up to case.
   - So the row `i(<path>:<tname>)` can only be built by reading the callee's `.subckt`
     header. ASE-L takes it from its own netlist, from the instance's `device_model` text,
     or from the model files the deck names (the session's, and those the netlist names)
     through their `.lib` and `.include` lines.

3. **Refusals come in two shapes, and not all on stdout** (rule 3).
   - `probe: I(<path>:<pin>) not inserted: <reason>` on stdout, for a path inside a
     subcircuit, a subcircuit instance or a missing instance. Also for a top-level X port:
     `probe: I(x1:zz) not inserted: x1 has no terminal named zz (1 to 2, the ports of blk:
     p q)`.
   - For a top-level element, two lines on stderr: `Warning: There are only 2 nodes
     available for r5,` (or `Warning: Node zz is not available for device r5,`) and
     `   .probe i(r5,3) will be ignored`.
   - Both spell the card, not the vector: the row `i(r5:n3)` is refused as `i(r5,3)`.
     ASE-L's log is the two streams folded together, which does not keep their order, so it
     matches a refusal by its path and pin and never by position
     (`ase::probe_refusals`).
   - Older builds, rc 0, the run continues: a top-level element that is not an X is probed
     by position with the same vector name. A path inside a subcircuit is refused with
     `Warning: Could not find the instance line for x1.xm1,` and `   .probe i(x1.xm1,d)
     will be ignored`; a top-level X port by name with `Warning: Node a is not available
     for device x1,` and `   .probe i(x1,a) will be ignored`.
   - So ASE-L does not test `$?probe_version` before writing a probe (rule 6). The card is
     written for every build, the deck echoes `ASE-PROBE-VERSION $?probe_version` before
     its first analysis, and the refusals are reported after the run.

4. **Three cards stop the run before any analysis, on every build** (rule 3 says the run
   continues).
   - A top-level `E` whose card, `+` lines joined, has fewer than six words:
     `E9 e9 0 vol='v(g)*2'` with `.probe I(e9,1)` ends in `Error: Not enough tokens` and
     `ERROR: fatal error in ngspice, exit(1)`. Six words are enough:
     `E5 TEMPERAT VSS VOL=' temper '`, the shape xschem's `vsource_arith` symbol netlists,
     is probed on pins 1 and 2 without harm.
   - Pin 3 or 4 of a top-level `E` written with `vol=` or `value=`: rc 1.
   - A top-level `K`: `Fatal error: k9: coupling to non-existent inductor
     probe_int_l1_k9_1.`
   - A card naming a missing instance or a bad pin is rc 0.
   - ASE-L withholds these three and says so after the run.

5. **Case, for a top-level element that is not an X** (rule 2).
   - Under `preserve`, a card that spells the instance in upper case is mis-named:
     `.probe I(R1,1) I(R1,2)` gives two vectors, both `i(R1:nn)`; `I(M1,d)` and `I(D1,a)`
     are refused. `ver_52` does the same.
   - The instance in lower case is right under `preserve` (`.probe I(r1,1)` gives
     `i(R1:n1)`) and changes nothing under `fold` or on an older build.
   - Under `distinguish` the lower-case card is refused: `probe: I(r1:1) not inserted: no
     instance named r1; 'R1' differs only in case (casemode=distinguish)`. No spelling
     works there.
   - X instances and everything inside a subcircuit are right in all three modes.
   - What ASE-L writes: the instance in lower case unless the run requests `distinguish`;
     under `distinguish`, no card for a top-level element with a capital in its name.
   - A netlist's own upper-case card beside ASE-L's, under `preserve`: `.probe I(Rtop,1)`
     plus `I(rtop,1)` gives `i(Rtop:nn)` and `i(Rtop:n1)`; with only the netlist's card
     the plot holds no `i(Rtop:n1)`. So under `preserve` and `distinguish` ASE-L leaves its
     own term out only for a netlist term spelled the same; under `fold` it ignores case.

6. **Which plots hold a probed vector** (the contract's "Analyses").
   - Present: op, dc, ac, tran, disto, sp.
   - Absent: both noise plots, tf, pz, sens, and the plot of a dc sweep over a design
     variable (its loop copies top-level nodes and source currents only).
   - ASE-L looks for a missing vector only in op, dc, ac, tran and disto plots. After a
     run that made only noise, tf, pz or sens analyses it says one note naming the
     terminals that are in no plot for that reason. An sp-only run does hold the vector
     (`i(r1:n1)` in its `SP Analysis` plot); a sens-only run lists it as `v(r1:n1)`.
   - The note is said as well when dc sweeps over a design variable stand beside those
     analyses, and then names the sweep: on such a run no plot of the results file holds a
     vector naming the terminal (the sweep's plot held `rv v(in) v(out) v(out2) i(v1)
     i(v2)` on the bench measured). A row that reads the sweep by its qualifier
     (`is(r1:n1)`) is told by the sweep's own advice instead, and is not named twice.
     A bench whose only analyses are two or more such sweeps still gets no sentence.

7. **A number in a card is a position, also where a port has that number as its name**
   (the contract's "`<pin>` is a position, 1..n on the netlist line, or a name").
   - Over `X1 a b c blk` / `.subckt blk 3 2 7`: `I(x1,3)` is the third port and comes back
     as `i(x1:7)`; `I(x1,7)` is refused with `probe: I(x1:7) not inserted: x1 has 3
     terminals`; `I(x1,2)` happens to be right. The vector is always named by the port it
     measures, so no wrong number appears under a row's name; what goes wrong is which
     vectors exist. A correct positional card prints the line `… is taken as a position,
     not as the port named …` whenever the number is also another port's name.
   - Vendor macro-models name their ports this way (`.SUBCKT LM741 1 2 99 50 28`), so no
     card can ask for such a port by name.
   - What ASE-L writes: the port's 1-based position, looked up in the callee's `.subckt`
     header (in the netlist, else in the model files the deck names). With those rows
     `i(x1:3) i(x1:2) i(x1:7)` the deck carries `.probe I(x1,1) I(x1,2) I(x1,3)` and all
     three vectors are in the results. It does not read the `taken as a position` line as
     a refusal.

8. **A probe is a device to the rest of the simulator** (the contract's "It is a 0 V
   source in the circuit").
   - `sens`: each probed terminal adds entries to the `Sensitivity Analysis` plot,
     `v(<path>:<tname>)` and the same name with `_freq`, `_phase`, `_pwr` and `_z0`, some of
     them not zero. The real parameters agree with a probe-free run to solver tolerance.
   - Convergence: on sky130 `tb_ft_test_2` one probe on the drain of the device under test
     turns a transient that finished into `Timestep too small`, exit 1. A hand-placed 0 V
     source at the same pin fails the same way, on `ver_53` and on apt 45.2, so it is the
     series source and not the `.probe` card. ASE-L says after such a run how many probes
     its deck asked for.
   - What a log says about convergence. A failed operating point always prints `Error:
     The operating point could not be simulated successfully.`, whichever analysis asked
     for it. `Transient op failed, timestep too small` stands beside it only when the
     transient-op rung was tried (ASE-L's Convergence form can switch it off), and `DC
     solution failed -` only when the analysis is `op`. With the transient-op rung off, a
     failed operating point is followed by `doAnalyses: iteration limit reached` on
     `ver_53` (apt 45.2: that or `doAnalyses: Too many iterations without convergence`,
     depending on the bench); with the rung tried both print `doAnalyses: <analysis>:
     Timestep too small`. A `tf`-only bench whose `tf` solve aborts prints neither. The
     line `singular matrix` is a warning and is printed on the way to a solution too: a
     bench with a capacitively coupled node prints it and finishes at rc 0, on both
     binaries. So is `Pole-zero iteration limit reached; giving up after N trials`, after
     which a pz run goes on to rc 0. ASE-L's note is keyed on `timestep too small`, `DC
     solution failed`, `no convergence` and `operating point could not be simulated`, not
     on those warnings, so a healthy run that was stopped is not told it did not
     converge. A `tf` analysis goes on after a failed operating point. Where the failed
     solve leaves no singular matrix (measured: a comparator loop, rung on and off, both
     binaries) the run ends at rc 0 with that error line in its log, and a tf-only bench
     gets no such note. Where it does (an inductor loop, a node with no dc path, rung
     off) the simulator aborts in the `tf` solve (`spSolve: Assertion IS_VALID(Matrix) &&
     IS_FACTORED(Matrix) failed`) at a nonzero rc, and the note is said.
   - Every other analysis measured gains exactly the asked vectors, and the other vectors
     agree with a probe-free run to solver tolerance.

9. **`preserve` and a top-level expression source** (item 5, one case more). For
   `E5 TEMPERAT VSS VOL=' temper '` under `preserve` the lower-case card `I(e5,1)` is
   refused (`e5 is a source with an expression and is replaced by other elements`) and the
   upper-case one comes back as two vectors both named `E5:nn`. Under `fold` it works.
   ASE-L writes the lower-case card and relays the refusal.

10. **A probe on a block's port is stored by xschem under the name of a source inside
    that block.** xschem's raw reader writes `i(x1:vp)` as `i(x1.vp)`, and its lookup for
    a source's current `i(v.x1.vp)` falls back to exactly that name. Where a block has a
    port and an internal voltage source of one name, and the source's own current is not
    saved, asking for the source's current answers the port's (measured on a block where the
    two differ).
    This is xschem's reader, not ngspice; it is here because the two vector names are one
    edit apart.

11. **The sign of a source's own current against its terminals.** For a top-level voltage
    source `i(v1)` equals `i(v1:n1)`, the current into its first pin, and is the negative of
    `i(v1:n2)`: on one bench −1 mA, −1 mA and +1 mA (`.probe I(v1,1) I(v1,2)`, rc 0).
    ASE-L's Direct Plot and the Calculator plot `i(v1)` for a source's pin whose own vector
    the results do not hold, and say on the second pin that it is the negative.
    Measured 2026-11-19 on a copy of `ver_53` for a four-node element, `E1 p m cp cm 2`
    with `.probe I(E1,1) I(E1,2) I(E1,3) I(E1,4)`, rc 0: `i(e1)` equals `i(e1:n1)`, is the
    negative of `i(e1:n2)`, and `i(e1:n3)` and `i(e1:n4)` are zero. So on a pin that is
    neither the first nor the second node ASE-L says only that the source's current is
    not that pin's, and nothing about a sign.

12. **The same characters on a `.save` card** (item 1's sweep, on the other card). Measured
    on `ver_53` and on apt 45.2 with hand-written decks:
    - `.save v(a=b)`, `.save v(a'b)`, `.save v(a{b)`, `.save i(=rtop:n1)`, `.save
      i(rtop:1')`, `.save i(rtop:1=)`, `.save i(rtop:1{)` and `.save @rtop[i=x]`: a netlist
      error before any analysis, rc 1, no results file.
    - `.save v(a}b)`, `.save i(rtop:1})`, `.save v(a;b)`, `.save v(a$b)` and `.save
      v(nosuch)`: rc 0, and the other saved vectors are kept.
    - So one output expression that read such a name cost a bench its whole run, through
      the `.save` card ASE-L wrote for the read. ASE-L now writes no `.save` card for an
      expression's read of a name holding `=`, `'`, `{` or `}`
      (`ase::output_card_sources`); the run goes on and that row's Value says the name is
      unknown. A read of a name holding `;` or `$` keeps its card.

### What would help from the ngspice side

- **A card spelling that names a numbered port BY NAME** (item 7). A word of digits is
  always read as a position, so for a subcircuit with ports `3 2 7` there is no way to
  write "the port called 3" in a card. ASE-L reads the `.subckt` header to write the
  position instead, and cannot when the header is out of its reach. A quoted form, or a
  `name=` form, would let a row's own text be the card.
- **`get_terminal_name()` under `preserve` and `distinguish`** for a top-level element
  that is not an X (item 5). ASE-L lower-cases the card as a workaround and has none under
  `distinguish`.
- **The two top-level fatals** (item 4): the short `E` card and the `K`. A refusal at rc 0,
  as inside a subcircuit (`x1.k1 has no terminals`), would let ASE-L stop reading the
  netlist for them.
- **`n<k>` and `b_tj` accepted back as a `<pin>`** (item 1), so a row's own text is a valid
  card.
- **One line per inserted probe naming its vector**, for example
  `probe: I(x1.xr2:1) inserted as i(x1.xr2:r0)`. An inserted probe prints nothing today,
  so xschem reads the PDK library for the port names (item 2).
- **`wrnodev`** writes `.ic v(probe_int_out_r9_1) = …` for a top-level element probe. A
  later run without that probe then warns `Nodeset on non-existent node -
  probe_int_out_r9_1, ignored`.
- **`sens`**: each probe adds five rows to the plot, `v(r9:n1)` and `v(r9:n1_freq)`,
  `v(r9:n1_phase)`, `v(r9:n1_pwr)`, `v(r9:n1_z0)`, because the probe is a source (item 8).
  A probe's source left out of the sensitivity analysis would keep that plot to the
  circuit's own devices.
- **`preserve` and a top-level expression source** (item 9): no card spelling gives its two
  terminal vectors there.
- **A `;` or a `$` inside a term** (item 1) refused as one term, instead of cutting the
  card and taking the terms behind it with it; and an `=`, a `'` or a brace inside a term
  refused at rc 0 instead of ending the run. The same for a `.save` card (item 12).
- **The same term twice for a top-level device** (item 1) taken once, as it is inside a
  subcircuit. ASE-L reads the netlist's own `.probe` cards to avoid writing a second one.
