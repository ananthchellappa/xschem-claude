# 1724 — Select On Design cannot queue a device terminal current: a click on an instance pin queues the voltage of the pin's net

**STAMP:** `v1 claim=partial tree=d36cb429e stamped=2026-11-19 fix=taken open=15 by=driver`

Asked by the user on 2026-11-18:

> when I'm not in any mode, if I put the cursor on a terminal (such as instance pin) and click,
> it selects the pin. So, why am I unable to save a terminal current in ASE-L when I use
> Outputs > Save > Select on Design? I'm only able to save nets

And, for the cue on the sheet:

> While in that mode, (in ADE-L, Cadence), the chosen terminals in the schematic are given thin
> ellipses in light green vertically oriented (longer dimension is vertical) with pin at center
> to show that they have been chosen. Exiting the mode with ESC dismisses (clears) these drawn
> ellipses. When plotting, if user plots a terminal current, the color of the waveform in the
> Waveform Viewer is the color of the ellipse. These ellipses are also dismissed by the 0 key
> shortcut to clear all highlights.

**Built**, on top of `d36cb429e`: in Select On Design a click on a device pin queues the current
into that terminal; the deck asks the simulator for it with a `.probe` card and a report after
the run says what came of each; the picked pin carries an ellipse; the Calculator's current
selectors take the same click. The build was reviewed twice and repaired after each review;
a third, short repair then built the items the second one had measured and handed back; a
third review found no blocker, and a fourth repair built what it found. Four verifiers
then checked that repair; each answered that it holds and listed what was left, and a
closing pass the same day built that list. Two verifiers checked the closing pass; both
answered that it holds and listed what was left, and a last build, the same day, built
the items of that list the lead ruled in.
On 2026-11-20 the user ran it on her own bench: no simulator picked, so a build without the
terminal-probe extension started, and a pin of a subcircuit instance below the top level
picked for saving. What she was told did not say that the simulator was the cause, which of
her registered simulators can, or where to pick one; Direct Plot told her to do what she had
just done. A message pass the same day built what "When the simulator cannot save the
terminal" describes below; three verifiers drove it, a repair pass built what they found,
and a short round after that reworded one sentence (decision 68) and gave rows to two
things the last verifier had found without one (the entries the cure does not ask, and the
session a run's record carries). That round's own verifier then measured that one kind of
those entries CAN be asked, by Detect and by a run, and the words that said nothing can
were corrected (Limits, "An entry the cure does not ask"); no code moved.
This file describes the behaviour after that round. The title is the defect as it
was filed. This file says what the pick does now, what was built, which decisions were taken
on the user's behalf and await a ruling, what the measurements corrected, the limits, and what
is left.

## What the pick does now

One click serves ASE-L's Outputs > To Be Saved > Select On Design, Outputs > To Be Plotted >
Select On Design, the Add/Edit Output dialog's "From Design…" and Results > Direct Plot
(`ase::ui::sod_click`).

| the click is | it queues |
|---|---|
| on a device pin: its own square (also where a wire ends on it), the device's lead beside it, any point within its reach that is neither on a wire nor right beside one | the current into that terminal, `i(<path>:<tname>)` |
| on a wire, or within a pixel or two of one, off a device pin's own square | the net's voltage, `v(<net>)`, as before |
| on the body of a voltage source or an ammeter | its branch current, `i(<name>)`, as before |
| on a net label out of reach of every device pin, or on a net label's pin that is nearer than every device pin | the net's voltage, as before |
| on a device pin whose instance or port name holds a character a terminal row cannot hold (`=`, `$`, `'`, a brace and the others listed under "Refused at the click") | nothing, with a sentence |
| on anything else | nothing, with the notice below |
| on empty canvas | nothing, silently, as before |
| in a window or tab that shows neither the session's design nor a sheet below it | nothing, with a sentence; the mode stays armed |

The window test runs first (`ase::ui::sod_design_shown`), then the pin test, in its own proc
(`ase::ui::sod_terminal_at`). Where the pin test answers "no pin" the click goes on as it
always did: the source rule, then the net.

**The click is resolved where the button was pressed.** The script the mode binds on the
press and on the double click first hands the engine the press's own position as a pointer
motion (`xschem callback %W 6 %x %y 0 0 0 %s`) and then runs the click
(`ase::ui::sod_press_script`). `ase::ui::sod_click` reads the pointer the engine last heard
of, and the engine takes the position of every event it is sent: a `<Configure>` of the
design canvas carries the canvas's place in its window, not a pointer position, and one can
arrive between the last pointer motion and the press (issue 1659). Before this, a press at a
pin's pixel after such an event queued nothing and said nothing. A scripted call of
`ase::ui::sod_click` with no coordinates still reads the engine's pointer.

The notice, which replaces *"v1 queues source currents only"*:
`ase: nothing to queue there — click a wire or a net label for a voltage, an instance pin for
its terminal current, or a voltage source/ammeter for its current`. The two entry echoes name
the pins as well: `… click wires/net labels for voltages, pins for terminal currents, sources
for currents; ESC ends` (`ase::ui::sod_entry_notice`).

**On a device pin** (`ase::ui::sod_terminal_at`):

- **In range.** The cursor is where the editor's pin-select click reaches the pin (the rule
  of `find_closest_pin()`, asked through `xschem pin_at -all`) **and** within 10 schematic
  units of the pin's point. The editor's rule has two halves: within `12 * zoom * tk scaling`
  of the pin's point, a fixed distance on screen; or inside the pin's own drawn rectangle,
  edges included (`point_in_inst_pin_rect()`). The second half keeps the whole square the pin
  when the sheet is zoomed in so far that the on-screen radius is smaller than the square. The
  test uses the raw cursor, not the snapped one.
- **A device.** The instance is a device (`ase::ui::sod_inst_is_device`): its symbol is not one
  that only carries a net (`label ipin opin iopin show_label scope bus_tap noconn probe`), it is
  not left out of the netlist (`spice_ignore` on the instance or the symbol, `lvs_ignore` under
  its switch, `only_toplevel` below the session's design), and its netlist format is an element
  line, not a comment or a card.
- **A click on a wire is the wire.** With a device pin in range the click is still the wire's
  voltage when the cursor is outside the pin's own square (2.5 units either side of the pin's
  point) and either of two tests says it is on a wire:
  - the editor's hit test names a wire under the cursor, and the point of that wire nearest
    the cursor lies on the wire, not past its end, and outside the square
    (`ase::ui::sod_wire_wins`);
  - some wire's nearest point to the cursor, taken on the wire, is within 2.5 units or one
    and a half screen pixels, whichever is more, and outside the square
    (`ase::ui::sod_wire_near`). This one asks the wires directly. It covers a cursor a pixel
    beside a wire where a net label's box or the device's own box lies over the wire and the
    hit test names that instead.

  So the wire is the net at any zoom, and the pin's own square is the pin at any zoom. The
  device's lead beside the square is the terminal as far as the pin radius reaches, which is
  a fixed distance on the screen: zoomed far in, a point a few units down the lead is beyond
  it and is not the terminal. A click in range that is on no wire is the terminal too.
- **A net label's or a port's pin** that is strictly nearer than every device pin makes the
  click a voltage pick. At the same distance the device wins. So a label placed directly on a
  device pin gives the terminal at the shared point and into the label's text as far as the
  pin's range reaches, 10 units at most; further into the text it is the net's voltage.
- **A net label's box near a device pin.** A label that is not on the pin, but whose box
  reaches within the pin's range, is the terminal's there, except within the wire tolerance
  of a wire. For the net's voltage click the wire, or the label farther from the pin.
- **Two devices with pins on the same point.** The click takes the device on whose side of the
  point the cursor stands.
  - The side is measured towards the middle of that device's pins
    (`ase::ui::sod_term_toward`).
  - Where the pins of ANY device on the point say nothing about its side, every device on
    that point is measured towards the middle of its symbol's box instead, texts not
    counted (`ase::ui::sod_term_toward_box`, `ase::ui::sod_term_box_centre`). The pins say
    nothing for a block with every pin on one edge and for a one-pin symbol
    (`ase::ui::sod_term_edge_on`): there the middle of the pins is on the edge, or is the
    point itself. So two abutting blocks are told apart whether or not their pin sets are
    equal and whatever title they carry. The two measures are never held against each
    other.
  - A two-pin symbol whose drawing is lopsided by more than 5 units (the stock `led.sym`)
    is read the same way: its pins are on one line and the middle of its box is off that
    line. Every device on its point is then measured by its box, which still takes the
    device whose lead the cursor is on.
  - A symbol that uses one pin name twice (the shipped `examples/xcross.sym`) makes no
    such claim: its pins are placed by name, and for a name used twice the engine answers
    the first pin of that name, so `ase::ui::sod_term_edge_on` answers 0 for it and its
    shared points are decided by the pin measure, unless another device on the point is
    edge-on (a one-pin symbol, a block with every pin on one edge): then every device
    there, this one included, is measured by its box, as since the fourth repair
    (Limits).
  - A pin name that ends in a backslash (symbols of the gschem import library have such
    pins, the shipped `gschem_import/sym/MC10E104-1.sym` among them) is read like any
    other. Both measures ask one reader for a symbol's pin names
    (`ase::ui::sod_term_pin_names`). It asks the engine for the names first (`xschem
    pinlist <n> name`) and keeps that answer when it is a list; for a name that ends in
    a backslash it is not, and each name is then read off the pin's own attribute
    string. Each pin's point is read off the end of the engine's answer as text
    (`ase::ui::sod_term_pin_xy`), because for such a name `xschem instance_pin_coord`
    answers no list either. Before the last build both measures raised on such a symbol
    and a click on a point it shares with another device said `ase: the pin test of
    this click failed …`.
  - A symbol whose pins have plain names and ANOTHER attribute that ends in a backslash
    is read by its names too (row TPR4x). For it the attribute strings are what is no
    list, and a reader that asked them alone took its pins for unreadable: on a point it
    shares with another device its side was then taken from its box.
  - Where the pins are the measure and give two devices the same value, the box decides
    between them.
  - Exactly on the point, or no more on one device's side than on another's by the measure
    in use, `pin_at`'s order decides (the lowest instance index).

  A notice names the others (`ase: that point is also … — the click took …`). One click
  never queues two terminals. The rule reads only: the selection, the editor's state and
  the modified flag are as they were.
- It does not depend on Options > Enable pin selection (`en_pin_select`). The pins of a
  `lock=true` instance do not answer, and no pin answers while the pin layer is hidden.

**The row** is the simulator's own name for the current into that terminal
(`ase::ui::sod_term_name`). It sorts into the Saves tab (`ase::output_tab`), and it is lower
case unless the session's simulator keeps case (`ase::ui::sod_expr`).

| element as netlisted | `<tname>` | example row |
|---|---|---|
| `M…` | `d g s b_tj` | `i(m1:d)` |
| `Q…` | `c b e` (then `s t`) | `i(q1:c)` |
| `J…`, `Z…` | `d g s` | |
| `D…` | `a c` | `i(d1:a)` |
| any other letter but `X` (R, C, L, V, I, E, …) | `n<position on the netlist line>` | `i(r1:n1)`, `i(v1:n2)` |
| `X…` (a PDK wrapper, a block) | the callee's `.subckt` port at that position | `i(x1.xm1:d)`, `i(x1:in)` |

- `<path>` is the instance path from the session's own design down to the clicked sheet, then
  the element as the netlist spells it (the first word of the instance's netlist line, never
  `@spiceprefix@name`).
- For an `X` the port comes from, in this order (an instance or a symbol that carries a
  `spice_sym_def` is asked for that definition's own header first):
  1. the symbol's own pin, when xschem writes the callee's body from that symbol
     (`ase::ui::sod_term_own_block`);
  2. the `.subckt` header in the netlist ASE-L last made, while that netlist is current;
  3. the `device_model` text the instance puts into the deck (the instance's, else the
     symbol's: `ase::ui::sod_term_device_model`) and the files that text includes;
  4. the model files the deck will name: the session's `includes` and `models` rows, and the
     `.include`/`.lib` cards of the netlist ASE-L last made, which are still followed after
     that netlist has gone stale (a model file does not move with a sheet edit);
  5. failing all of these, the symbol's pin name, with a caution in the CIW that says why no
     header names the port and ends with what to do about that
     (`ase::ui::sod_term_header_gap`):
     - none is known: `… no .subckt header for '<callee>' is known, so the terminal is named
       as the symbol's pin; that is right only if the subcircuit names its ports the same way;
       to be sure, netlist the design from ASE-L (or run), or name the model file under Setup >
       Model Files, then pick again`;
     - the place that answers holds several headers whose ports differ: `… the session's
       model files hold more than one .subckt header for '<callee>' and their ports differ, so
       the terminal is named as the symbol's pin; that is right only if the subcircuit the
       simulator uses names its ports the same way; to be sure, leave one definition of
       '<callee>' in the model files (Setup > Model Files), then pick again`. For the design's
       netlist and for a `device_model` the sentence names that place and says to leave one
       definition there;
     - the one header known is too short: `… the .subckt header known for '<callee>' has 1
       port, too few for that pin, which is node 2 of the call, so the terminal is named as
       the symbol's pin; …`.

  Steps 2 to 4 are `ase::ui::sod_term_port_lists`, which answers every different port list of
  the place that has the name; `ase::ui::sod_term_ports` is its one list, and nothing when it
  has none or several. Which of several headers the simulator would use is not guessed. A PDK
  wrapper's ports are not its symbol's pins: a sky130 poly resistor's symbol pins `M P B` are
  the ports `r0 r1 sub`.
- A port whose name is a number is queued under that name: `i(x1:3)` is the port called 3,
  wherever it stands on the header. The deck side turns it into a position (below).
- A bus instance, a bus pin, or both, is several vectors: the Select Bus Bits dialog
  (`ase::ui::bus_dialog`) lists them as `<path>:<tname>` and Cancel queues nothing.

**In the deck.** A terminal row is never a `.save` card (`ase::output_card_sources`). The deck
carries `.probe I(<path>,<pin>)` cards instead (`ase::probe_plan`, written by
`ase::backend::ngspice::render_deck`), and one line `echo ASE-PROBE-VERSION $?probe_version`
in its `.control` block. The capability probe's deck C asks the same question of a program
before any run, in a file of its own, and publishes the answer as the capability key
`hier_probes` (below, "When the simulator cannot save the terminal").

- **Asked for:** a Saves-tab row with Save or Plot ticked; every terminal a Measures-tab row
  reads, ticked or not, whether the row is one signal (`idc(xm1:d)`, `-i(rt:n1)`,
  `it(xm1:d)`) or an expression (`db(if(a:d)/if(b:d))`); and every terminal an enabled
  measurement row reads (`ase::meas_probes`). A Measures row has a Value whether or not it is
  saved, and the Add Output dialog opens with both boxes off.
- **Each distinct term is written once** (`ase::probe_terms`), also when two rows name one
  terminal in two ways.
- **A term the netlist's own `.probe` card already holds is not written again**
  (`ase::probe_netlist_terms`, `ase::probe_terms_new`). A schematic can carry such a card in
  a code block, and the same term twice in one deck makes a top-level device's vector twice
  under one name (measured on `ver_53` and on apt 45.2). The card word is read without case,
  `+` lines are joined, a card inside a `.subckt` body counts, and a term behind `;` or behind
  a `$` that follows a blank or a comma does not. Under `fold` case is ignored. Under
  `preserve` and `distinguish` the term must be spelled the same: there a netlist's `.probe
  I(Rtop,1)` makes `i(Rtop:nn)`, not the row's `i(Rtop:n1)`, so leaving ASE-L's term out
  would cost the row its vector. The plan, the run record and the echo line are unchanged.
- **A numbered subcircuit port goes into the card as its position** on the `.subckt` header
  (`ase::probe_card`, `ase::probe_x_ports`), because the simulator reads a number in a card
  as a position. The header is looked for in the netlist text and then in the model files the
  deck names. A number that names no port of the header is a position somebody typed and is
  written as it stands. When no header is found the number is written as it stands and the
  report explains a row that then has no vector.
- **A Save-ticked terminal row brings the `.save all` leader**, as every other Save-ticked row
  does (`ase::output_saves_any`). A netlist can carry a `.save` of its own (every stock
  ammeter writes one), and without the leader that card narrowed the results to itself and
  the terminal. A plot-only terminal row brings none, like a plot-only voltage row.
- **A name holding `;`, `$`, `=`, `'`, `{` or `}` is not a terminal** (`ase::probe_split`).
  Measured on `ver_53`, each between two good terms on one card: a `;`, and a `$` opening the
  pin, cut the `.probe` card where they stand, so the terms behind are lost at exit 0; an `=`,
  a `'` and an opening brace stop the simulator before any analysis; a closing brace is
  harmless and leaves with the opening one. Such a row is the `.save` card it was before this
  feature: with Save ticked the pre-flight refuses it by name before the run, and a plot-only
  one writes nothing. These are typed rows: a pick on a device or a port whose own name
  holds such a character is refused at the click (below).
- **An expression's read of a name holding `=`, `'`, `{` or `}` makes no `.save` card**
  (`ase::output_card_sources`), whatever the read's shape: a node, a terminal-shaped
  current, a device parameter. Measured 2026-11-19 on `ver_53` and on apt 45.2: a `.save`
  of a name holding an equals sign, a single quote or an opening brace stops the simulator
  with a netlist error before any analysis, so one such read in one expression row cost a
  bench with a Save-ticked plain row its whole run. With no card the run goes on, and the
  row's Value says what it says for any read the results lack (`Cannot evaluate: unknown
  token 'vdc(a=b)' …`). A read of a name holding `;` or `$` keeps its card: both were
  measured harmless on a `.save` card. Only an expression's reads are held to this: a
  Save-ticked plain row of such a name is still a card, and the pre-flight refuses it by
  name before the run.

**After the run** `ase::probe_report` says one line per terminal that did not arrive:

- `ase: no probe was written for the terminal current <row>: <reason>. To measure it, place an
  ammeter (ammeter.sym) in series.` (a card ASE-L withheld, `ase::probe_card`: a `K` coupling;
  a top-level expression `E` source on a short card, or its third or fourth pin; under
  `distinguish`, a top-level device with a capital in its name);
- `ase: the simulator refused the terminal current <row> (.probe <card>): <its reason>.` Not
  said when the results hold a vector of the row's name all the same;
- the vector is missing and the results hold other terminal currents of the same instance:
  `ase: the terminal current <row> is not in this run's results under that name: the deck
  asked for it (.probe <card>), and for <path> the results hold <names>. Name the row after
  the one meant.`;
- the vector is missing and they hold none: `ase: the terminal current <row> is not in this
  run's results: the deck asked for it (.probe <card>) and the simulator neither made the
  vector nor said why.`;
- for a numbered port whose header was not found, behind the refused or the missing
  sentence: `The simulator reads a number in a .probe card as a position, not as the port of
  that name, and ASE-L did not find one .subckt header for <subckt>, in this run's netlist or
  in the model files it names, to turn the port named <n> into its position. Name the model
  file that holds that header under Setup > Model Files and run again.` Where the instance's
  own card is not in the netlist the last sentence is the ammeter's instead
  (`ase::probe_nohdr_note`);
- when the simulator answered 0 to `$?probe_version`, for ALL the terminals that need a
  simulator which probes below the top level and were refused or are missing, ONE line in
  place of theirs: `ase: <program>, the simulator this run started, cannot save the terminal
  current <row>: it saves terminal currents only on top-level devices that are not
  subcircuit instances. <cure>` (next section). A top-level device that is no subcircuit
  instance keeps its refused or missing line on such a build, and nothing is added for it.
  (Until 2026-11-20 each such terminal kept the simulator's own refusal and one note stood
  behind them, `ase: this simulator probes only top-level devices that are not subcircuit
  instances.`; that note is gone);
- when the run failed, its deck carried a `.probe` term and its log holds a convergence
  failure (`timestep too small`, `DC solution failed`, `no convergence` or `operating point
  could not be simulated`): `ase: this run did not converge, and its deck asked for <N>
  terminal current(s). Each one puts a zero-volt source in series with its pin, and that
  alone can stop a run that finishes without it. Switching those rows off -- unticking Save
  and Plot on a Saves row, removing or disabling a Measures or measurement row that reads a
  terminal -- may let the run finish.` It is not said for any other failed run.
  - **A failed operating point is told whichever analysis asked for it** and whichever
    rungs of the Convergence form were on: the simulator's last line for it, `The
    operating point could not be simulated successfully.`, is in the key. With the form's
    transient-op rung switched off it is the only line of the key in the log of an ac, a
    transient, a dc-sweep, a noise, a pz or a sens bench (measured 2026-11-19 on `ver_53`
    and on apt 45.2); `timestep too small` stands beside it only when that rung was tried,
    and `DC solution failed` only when the analysis is `op`.
  - **Two lines that look like a failure are not in the key**, because a run that goes on
    prints them too. `singular matrix` is a warning printed on the way to a solution, so a
    healthy run that was stopped, or that failed later for another reason, is not told it
    did not converge. `iteration limit reached` is also what the pole-zero search says
    in a warning when it gives up and the run goes on to exit 0. Under a failed
    operating point it stands only where the transient-op rung was not tried: with the
    rung off, the failure is followed by `doAnalyses: iteration limit reached` on
    `ver_53` (apt 45.2: that or `Too many iterations without convergence`), except on
    a `tf`-only bench whose `tf` solve aborts, which prints neither; with the rung
    tried both print `doAnalyses: <analysis>: Timestep too small`;
- when the run finished, at least one noise, transfer-function, pole-zero or sensitivity
  analysis is enabled and every other enabled analysis is one of those four or a dc sweep
  of a design variable: `ase: the terminal current <row> is not in this run's results: the
  run made only noise, transfer-function, pole-zero or sensitivity analyses, and none of
  those keeps a terminal current. Enable an operating point, a dc sweep of a source, an ac or
  a transient analysis and run again.` (several rows: `the terminal currents <a>, <b> are
  not …`). With a sweep among them the sentence names it: `… or sensitivity analyses beside
  a sweep of a design variable, and none of those keeps …` (two or more: `beside sweeps of
  design variables`). It names the rows whose card was written and not refused and whose
  vector is in no plot of the results file, and it needs the plot sidecar and the results
  file.
  - **Beside a sweep, a row that reads the sweep by its qualifier is left to the sweep's
    own advice.** A row such as `is(r1:n1)`, alone or inside an expression, is already
    told before the run and in its Value that the sweep cannot carry it
    (`ase::backend::ngspice::dcvar_output_refusals`). A terminal that only such rows ask
    for is not named in the note; a terminal any other row asks for is named
    (`ase::probe_asked`). So no row is spoken for twice.
  - **Not said** when any other analysis is enabled: an `sp` plot holds the probed vector,
    a dc sweep of a source or an operating point gives the row its value, and a sweep of a
    design variable that is the bench's only analysis keeps its own advice and gets no
    note.

The older note about rows with *"no single-point value"* leaves out a terminal row whose
vector is in no plot of the results file: neither of its reasons holds for such a row, and the
probe report speaks for it, with a missing-vector sentence or with the note above.

**When the simulator cannot save the terminal** (built 2026-11-20). A build without the
terminal-probe extension probes a top-level device that is no subcircuit instance and
refuses every other terminal. Four places say so, with one name for the program and one
cure.

- **Which terminals.** `ase::probe_needs_hier <path>`: the instance path holds a `.` (a
  device inside a subcircuit) or its last word begins with `x` or `X` (a pin of a
  subcircuit instance).
- **Which programs.** The capability key `hier_probes`, 0 or 1
  (`ase::backend::ngspice::capabilities`, `ase::caps_keys`). The first line of deck C's
  control block writes `ASE-PROBE-VERSION $?probe_version` into `probe_h.txt` in the
  probe's own folder; the answer is read from that file, never from the exit code;
  published only for a 0 or a 1; a run of deck C cut by the budget records the key as
  unmeasured (`timeout`), as it does `altshow_op_dump`. Measured 2026-11-20 through the real
  probe: 0 on apt 45.2, `ver_50`, `ver_52` and stock 47, 1 on `ver_53`; every other key of
  the answers taken on apt 45.2, `ver_50`, `ver_52` and a copy of `ver_53` was the same
  before and after. The sentence about a program (`ase::backend::ngspice::variant_notes`)
  names the gap last, before its asides: apt 45.2 reads `… can do everything ASE-L offers
  except case-sensitive net names, the fast operating-point dump and terminal currents of
  subcircuit pins or of devices inside subcircuits. …`, `ver_50` and `ver_52` read `… except
  terminal currents of subcircuit pins or of devices inside subcircuits.`, and `ver_53`
  still reads `… can do everything ASE-L offers.`
- **The program's name** (`ase::sim_run_name`): the file when no registered entry is in
  force (`/usr/bin/ngspice`), `<entry> (<file>)` when one is. A run resolves it once and
  carries it in its record, so the report names what that run started.
- **The cure** (`ase::probe_cure`), the end of every sentence below, the first of these
  that applies: the registered simulators that were measured able, in registry order --
  `<A> can — pick it under Setup > Simulators… and run again.`, `<A> and <B> can — pick one
  under Setup > Simulators… and run again.`; with none known able and an entry nobody has
  asked yet, `<C> has not been tried yet — the next run finds out whether it can, or select
  it under Setup > Simulators…, press Edit… and then Detect.` (several: `<C> and <D> have
  not been tried yet — the next run finds out which of them can, or select each under
  Setup > Simulators…, press Edit… and then Detect.`); with none able, none untried and an
  entry that was asked and gave no answer -- or one the cure does not ask: registered
  while its file could not be started, its file gone since, or a backend with no probe --
  `None of the simulators you have registered is known to. Register an ngspice
  build that saves terminal currents inside subcircuits under Setup > Simulators… and run
  again, or place an ammeter (ammeter.sym) in series with the pin.`; with every entry
  measured unable, the same with `None of the simulators you have registered can.`; with
  nothing registered, the same without its first sentence. An entry whose answer is not
  known is never called able and never unable. At a pick the sentences that end `and run
  again` end `before you run`. For a run the cure may start registered programs nobody
  has asked; one call spends at most five seconds on that (`ase::probe_cure_ms`), a
  program with entries still to be asked behind it is not given all of what is left, and
  a program that does not answer in a fair share of the call is not started again until
  the capability answers are cleared, the registry is edited or its file changes. At a
  click it starts none. What it knows is kept under the program (its file's stamp and
  the words it is started with), so two entries for one program share an answer, and the
  answers `can` and `cannot` are carried over an edit of the registry
  (`ase::probe_cure_carry`), which empties the capability store as before.
- **Before the run** (`ase::probe_start_report`, from `ase::run_deck`), when the program
  about to start was measured `hier_probes` 0 and the deck's plan holds such a terminal:
  `ase: <program>, the simulator this run is starting, cannot save the terminal current
  <row>: it saves terminal currents only on top-level devices that are not subcircuit
  instances. <cure> This run goes on without that current.` Said on every such run, as an
  error. The run is not refused. A program nobody has measured is not told it cannot. A
  run on a program measured unable whose plan holds NO such terminal says nothing and
  asks the registered entries all the same, so that a pick, which starts nothing, can
  name the one that can.
- **After the run** the report's line above, from the run's own log.
- **At a pick** in the flavours that write rows (`ase::probe_pick_report`), when the
  program THIS SESSION starts is already known unable and the click queued such a
  terminal: `ase: <program>, the simulator this session starts, cannot save that current:
  it saves terminal currents only on top-level devices that are not subcircuit instances.
  <cure, ending "before you run">`, once for the click. The row is queued and the pin
  marked all the same. The program is what a run of the clicking session would start
  (`ase::sim_session_view`), not what another session's run left in force in the
  process; known unable is the capability store's measured answer for it, or, after an
  edit of the registry has emptied the store, what the cure kept about it.
- **In Direct Plot** (next paragraph).

**Direct Plot** writes no row, so it adds no probe. A pin click there queues the trace only
when the session's results file already holds the vector (`ase::raw_vectors_present` on
`ase::last_rawfile`). Otherwise it says `ase: terminal current '<row>' is not in this
session's results` and why, where that is known (`ase::probe_absent_groups`, from what the
last run's report said about these results, `ase::last_probes`):

1. that report said the run's simulator cannot save it: `…: <program>, the simulator of the
   last run, cannot save it. <cure>`. Where the entry this session starts now is already
   known able, the sentence ends `<entry> is picked now — run again.` in place of the cure
   (a session that starts no entry: `<file>, which this session starts now, can — run
   again.`);
2. that report gave another reason (a withheld card, a refusal, a missing vector, analyses
   that keep no terminal current): that reason as a clause, such as `…: in the last run the
   simulator refused it (.probe I(r5,3)): Node zz is not available for device r5.`;
3. the terminal is asked for now (a Saves row with a box ticked, a Measures or measurement
   row that reads it) and the last run said nothing about it: `…: it is set to be saved,
   and this session has no results yet — run.` when the session has no results in view;
   `…: it is set to be saved, and these results are from before that — run again.` when
   the report is about these results, the run was this session's and its deck did not ask
   for the terminal; `…: it is set to be saved, but these results do not hold it — run
   again.` when the run on these results was another session's, when it did ask and said
   nothing, or when nothing is remembered about these results. For a terminal below the
   top level, when the program this session starts is already known unable, each of them
   ends `…, but <program>, the simulator this session starts, cannot save it. <cure>` in
   place of `— run again.` (after `do not hold it`: `…, and <program>, …`);
4. otherwise, as before: `… — pick it under Outputs > To Be Saved > Select On Design and run
   again`.

What the last run said (1, 2) is tried before whether the row is set (3), and the
simulator's sentence is said ahead of another terminal's reason.
**Except on the pin of a voltage source or an ammeter.** When that pin's terminal is not in
the results, or is refused a name, the click plots the source's own branch current, `i(v1)`
(`ase::ui::sod_terminal_as_source`): that is what the same click plotted before pins were
picked, and every run holds it. On the source's first pin, alone on its point, nothing more
is said. Where the trace is not what the click was aimed at, the click says so
(`ase::ui::sod_source_standin_notes`):

- **On the source's second pin.** `i(v1)` is the current into the source's first pin
  (`i(v1)` = `i(v1:n1)` = −`i(v1:n2)`, measured), so there the trace has the opposite sign of
  the pin's own current: `ase: V1 pin m — the trace is the source's own current 'i(v1)',
  which is the current into its first pin, so the current into V1 pin m is the negative of
  that trace; to plot the pin's own current, pick it under Outputs > To Be Saved > Select On
  Design and run again`. When the pin cannot be named the sentence ends after `… the negative
  of that trace`.
- **On a pin that is neither the first nor the second.** A controlling pin of a controlled
  source carries no current (measured on `ver_53`: for a four-node `E` element the currents
  into nodes 3 and 4 are zero), and a pin the netlist line does not carry is no node of the
  element. There the sentence says nothing about a sign: `ase: E1 pin cp — the trace is the
  source's own current 'i(e1)', which is not the current into E1 pin cp; to plot that pin's
  current, place an ammeter (ammeter.sym) in series with it`. When the pin can be named
  the sentence ends with the Outputs advice of the second pin instead. Driven on two stock
  symbols: the two controlling pins of `vsource_pwl.sym`, and both pins of
  `filesource.sym`, whose netlist line places neither.
- **Which pin it is** is `ase::ui::sod_term_pin_place {term nm}`, which answers `first`,
  `second` or `other`: the position in the row's own name when it is `n<position>`,
  otherwise the pin's place on the instance's netlist line
  (`ase::ui::sod_term_line_pos`). A pin that line does not carry, carries more than once,
  or carries behind a word that may not be a node is `other`, and so is a pin of an
  instance that cannot be read. The Calculator asks the same proc.
  `ase::ui::sod_term_first_pin` is kept unchanged for its callers.
- **On a point shared with another device's pin.** `ase: that point is also RE pin M — the
  click took the current of Vef`.

**Refused at the click**, in one sentence, `ase: cannot name the terminal current of <inst>
pin <pin> — <reason>; place an ammeter (ammeter.sym) in series`. The refusals are one proc's,
`ase::ui::sod_terminal_resolve`; `ase::ui::sod_terminal_pick` says the sentence:

- flat netlisting is on;
- a block instance between the session's design and the clicked sheet carries a `spiceprefix`
  (issue 0488: the hierarchy path would not be the deck's);
- the pin's place on the instance's netlist line cannot be worked out: the line does not carry
  the pin, its netlist format writes that pin more than once, an untagged word stands ahead of
  it on a line that is not a subcircuit call, or the line starts with a `#` form other than
  the two `src/spice.awk` expands;
- the instance has a netlist format of its own or a `spice_sym_def`, and no `.subckt` header
  can name the port at the pin's position: none is known, the place that answers holds
  several whose ports differ, or the one known has too few ports. The sentence says which of
  the three it is and ends with what to do about that one, as the caution does.

**A name the deck cannot carry is refused too**, with a sentence of its own
(`ase::ui::sod_term_unwritable`, asked by `ase::ui::sod_terminal_pick` after the naming and
before the Select Bus Bits dialog): `ase: nothing queued for <inst> pin <pin> — its current
would be the row '<row>', and a terminal-current row cannot hold <the character, in words>;
rename the instance or the port, or place an ammeter (ammeter.sym) in series`. Nothing is
queued and nothing is marked. The test is the deck side's own predicate
(`ase::probe_split`) put to each row the click would queue, so it refuses a name holding a
dollar sign, an equals sign, a single quote, a brace, a semicolon, a comma, a parenthesis,
a double quote, a blank or a second colon. Such names do reach the pick: measured for a
block port `Y=1` and for instances named `R=9`, `R$8` and `R'7`. An instance written with a
semicolon in its name reads back cut at the semicolon, so that one cannot. In Direct Plot
the pin of a voltage source or an ammeter with such a name still plots the source's own
current, as any pin of a source that cannot be plotted does.
A block whose PORT name ends in a backslash is refused by this sentence as well, with
the right remedy and the wrong reason: the row it shows has a blank where the backslash
is (`i(xw:a 1)` for the port `A\`) and the character it names is a blank (Limits, "The
pick").

**The mode itself** (`ase::ui::select_on_design`, `ase::ui::sod_seize`,
`ase::ui::sod_release`).

- **What it holds.** Six slots on the design canvas (`ase::ui::sod_slots` is the table):
  the left press and the double click (both are the pick), the left release and the pointer
  motion with the left button held (both swallowed), ESC (ends the mode) and the canvas's
  `<Destroy>` (the window going away). `ase::ui::sod_seize` takes them and
  `ase::ui::sod_release` hands each previous binding back as it was, when the mode ends or
  is paused for a descend; on a design canvas the double click's is the editor's own script.
- **A drag in the mode is one pick.** The pick is made at the press. A hand that moves with
  the button down changes nothing else: no selection rectangle starts, and a selection made
  before the mode is still there after it.
- **A double click is two picks.** Every press of a double or triple click reaches the pick.
  Nothing is selected and the editor's property dialog does not open. A second press on
  something already queued says `already queued`, as two single clicks do.
- **With tabs, the mode is on the main window's canvas**, which every tab shares
  (`ase::ui::sod_canvas`, used by the entry and by the resume after a descend). Before
  this, the mode could not be entered at all while the design was in a tab other than the
  first: both the session's menu entries and Ctrl-4 answered `ase: no design canvas to
  select on (.x1.drw)`, because the name of a tab's context is not a widget.
- **A window made while the mode is up is the editor's.** A window created with the mode up
  (`xschem new_schematic create_window`, which the Cadence-style profile's Ctrl-N runs) gets
  the bindings it would have got with no mode up: `clone_canvas_bindings` asks
  `cmdmode::pristine`, which reads what the mode says it holds (`ase::ui::sod_held`). Clicks
  there select, while the mode is up and after it. ESC pressed there is the editor's too:
  the mode ends by ESC in the window it is on.
- **One click mode at a time.** Entering the mode ends a Calculator selector that is waiting
  for its click (`selector it: pick cancelled`), and arming a Calculator selector ends a
  live Select On Design the way its ESC does. The Results Display Window's pick mode is not
  ended by either (Limits, and issue 0202).
- **The Results Display Window's mode on top of the mode that is ended keeps the canvas.**
  That mode (keys 1 to 3 with nothing selected) can be entered over Select On Design or
  over a Calculator selector. Whatever then ends the mode underneath, that mode's release
  hands the editor's scripts back over the Results window's live ones, so the Results
  window's mode is asked to take the canvas again (`rdw::pick_reseat`). It stays up, a
  mode started next stacks on it, and one ESC for each mode that is up leaves the canvas
  free. The doors that end the mode underneath, each followed by that call:
  - starting the other of the two modes, or entering Select On Design again
    (`ase::ui::select_on_design`, after the Calculator pick it ends and again after a
    Select On Design it ends; `calc::pick_end_sod`);
  - the Calculator's own doors: the armed selector pressed again, another selector
    pressed, the Calculator window closed (`calc::pick_end`, when it released a pick);
  - the ASE-L session window closed with its Select On Design up (`ase::ui::close`).

  The last two were built by the closing pass: before it, each left the Results window's
  mode recorded as up with nothing bound. When the pick is ended by a press in the
  Calculator window, the keyboard moves to the schematic, where that mode's ESC is
  (Limits, "The mode").
- **The other way round, the mode on top keeps the canvas too** (the last build). With
  Select On Design, or a Calculator pick, entered over the Results Display Window's
  mode, that mode can be ended first: by Escape pressed in the Results window, which
  ends its mode and leaves the window open. Its release hands the canvas the editor's
  scripts over the live ones of the mode on top. So its end (`rdw::pick_end`, when it
  released a mode) asks the two other modes to take the canvas again
  (`ase::ui::sod_reseat`, `calc::pick_reseat`). The mode on top stays as it was: its
  prompt, its clicks, the rows it queued and their ellipses, and its ESC, which then
  leaves the canvas free. Before the last build that mode stayed recorded as up with
  nothing bound: its prompt on the bar, ESC on the schematic doing nothing, and, once it
  had been entered and ended again, a schematic that took no left click. Taking the
  canvas again puts the keyboard on the schematic, where the remaining mode's ESC is
  (Limits, "The mode").
- **With two modes stacked the status bar shows one sentence, the top mode's**, which is
  the mode the clicks go to (the last build). Each mode keeps its sentence up with a
  timer of its own, and before this the two wrote the same slot in turn, so the text
  changed with every tick. Now a mode writes nothing while another mode that is up
  holds the press slot of its canvas over it (`ase::ui::sod_covered`,
  `calc::pick_covered`, `rdw::_pick_covered`, asked by `ase::ui::sod_prompt_pump`,
  `calc::pick_pump` and `rdw::_hint_sync`); its timer keeps running, so its sentence is
  back within one tick of the mode on top ending.
- **Stacked modes keep their order across a descend.** A descend through `hi_descend`
  (same window, new tab, new window) pauses every click mode and brings it up again where
  the descend lands. The top of a stack is released first and put back last
  (`cmdmode::release_order`), so while the modes are paused the canvas holds the editor's
  bindings, the modes come up stacked as they were, ESC ends them from the top down, and
  afterwards every window takes clicks.
- **A mode ended while a descend has it paused writes nothing on the canvas.** The
  descend command given with nothing selected pauses the modes and waits for a click on
  an instance. A paused mode has handed the canvas back, and what it still has on record
  as the canvas's own is, for a mode entered over another one, that other mode's
  scripts. Ended during the wait, it drops its record and leaves the canvas as it is
  (`ase::ui::sod_release`, `calc::pick_release` and `rdw::pick_release` write nothing for
  a paused mode): the click on an instance still descends, and the mode that is left
  comes up alone where the descend lands, or in place when the descend is cancelled.
  The doors that end a paused mode: Escape pressed in the Results window; the session
  window closed, Select On Design entered again, or a Calculator selector pressed, for
  Select On Design; the armed selector pressed again, another selector pressed, Select
  On Design entered, or the Calculator window closed, for a Calculator pick. A mode
  ENTERED during the wait is up at once and takes the clicks, the click on an instance
  among them, until its ESC.
- **The prompt names the pin.** While the mode is up the design window's prompt ends with
  the pin a click would take: `select outputs on design — pin R1:P (terminal current)`, and
  in Direct Plot `select signals to plot — pin R1:P (terminal current)`
  (`ase::ui::sod_prompt_text`). It asks the rule the click uses, at the raw pointer, and
  follows the pointer within one period of the prompt's timer. On a wire, a net label or
  empty canvas the prompt is the mode's words alone. The editor's hover outline does not say
  this: on a pin with a wire ending on it the outline is the wire.
- **It names a pin only while the pointer is in the window the mode is on.** With the
  pointer in another window of the design (the sheet above a block that was opened in a
  window of its own, or that block's window) the prompt is the mode's words alone, because
  a click there is the editor's (`ase::ui::sod_pointer_elsewhere`, asked by
  `ase::ui::sod_prompt_now`). Tabs share one canvas and are told apart by the design they
  show.
- **A click in another design's window is refused.** With tabs every tab shares the canvas,
  so the mode stays armed while another design is shown. A click there queues nothing, marks
  nothing and leaves the mode armed: `ase: nothing queued — this window shows neither the
  session's design '<lib>/<cell>' nor a sheet below it; switch to that design's window or
  tab and click there` (`ase::ui::sod_design_shown`). A block opened from the design in a
  new window or a new tab still picks.
- **Closing the window the mode is on ends the mode** (`ase::ui::sod_canvas_gone`, then
  `ase::ui::sod_drop_gone` once the event loop is idle). The row flavours' ellipses go from
  every window that is left, and the CIW says `ase: the design window the pick mode was on
  is gone — mode dropped`. With tabs the canvas is shared, so closing a tab does not end
  the mode; ESC still does.
  - **In Direct Plot nothing queued is plotted, and the sentence says so** when traces
    were queued (`ase::ui::sod_drop`): `ase: the design window the pick mode was on is gone
    — mode dropped; 2 queued traces were not plotted, and the colours their picks left on
    the schematic stay until the highlights are cleared (Highlight > Un-highlight all
    net/pins, or its key)`. For one trace: `1 queued trace was not plotted, and the colours
    its pick left …`. With nothing queued, and in the three row flavours, the sentence ends
    at `mode dropped`. No Direct Plot colour is taken away by the drop: clearing Direct
    Plot's ellipses there would also take those of earlier plots whose traces are still
    in the viewer.

**The marker.** A pin whose pick queued something carries an ellipse: thin, unfilled, centred
on the pin's point, twice as tall as wide, upright on the screen whatever the instance's
rotation or flip (`draw_pin_markers()`, behind `xschem pin_marker`).

- **What marks.** One ellipse per pick that queued, on the pin the click took, however many
  vectors it queued (a bus pin gets one).
  - To Be Saved, To Be Plotted and From Design…: on layer 16 with the tag `save`
    (`ase::ui::sod_mark_pin`), also when the row was already in the table. So a terminal
    picked under To Be Plotted has a light-green ellipse like a saved one, and its waveform,
    plotted after the run, has the viewer's next colour, not the ellipse's.
  - Direct Plot: on the layer the trace is given, with the tag `plot` (the `terminal` arm of
    `ase::ui::dp_hilight`, for the first vector the results hold). The colour is the one
    `ase::ui::dp_queue` hands the viewer, so the ellipse and the waveform have one colour.
    Only Direct Plot's ellipse has its trace's colour.
- **What does not.** A refused pick; a cancelled bit dialog; a Direct Plot pick none of whose
  vectors the results hold; a click on a wire beside a pin, which is a voltage pick; a click
  in a window that does not show the session's design; and the pin of a source whose branch
  current stands in, where the source's body is coloured as it is for a click on the body.
- **How long.** The markers of the three row flavours go when the mode ends: ESC, a second
  entry into the mode, a Calculator selector being armed, the session window closing, the
  window the mode is on being closed, or that window being gone when a paused mode is
  resumed (`ase::ui::sod_end`, `ase::ui::sod_drop_gone` and `ase::ui::sod_resume`, through
  `ase::ui::sod_marks_clear`), in every window and tab. Direct Plot's stay past ESC, as its
  net and source colours do. `xschem unhilight_all` (key `0` under `src/cadence_style_rc`,
  Shift+K in the stock bindings) clears every marker, of either tag, of the window it is
  given in and of the windows and tabs linked to that one by a descend
  (`pin_marker_clear_linked_windows()`: the windows whose net colours the same key clears),
  also while the mode is up and also when no net is highlighted anywhere. A window showing
  another document keeps its markers. A later click on the same pin puts the marker back.
  **Given while the window is in the middle of a gesture** (a wire being drawn), the command
  clears that window only: the linked windows keep their marker lists, their ellipses and
  their net colours together, because nothing repaints another window during a gesture.
  Given again once the gesture is over, it takes all three there.
- **A Direct Plot ellipse can outlive its trace.** It keeps its colour until the highlights
  are cleared. After a run whose plot replaces the viewer's traces (a row with Plot ticked,
  destination Replace) the trace of that colour is gone or another signal has the colour;
  Direct Plot's net and source colours do the same.
- **Below the top.** A pick made on a sheet below, after a descend with the mode up, is
  marked on that sheet, and the mode's end from any sheet takes it away.
- **Size.** Half as wide as it is tall; the half-width is the larger of 5 schematic units and
  3 pixels times the Tk scaling, so it surrounds the pin's square at ordinary zooms and stays
  visible from far away. The stroke has a fixed width on the screen.
- **It is a cue, not data.** It is not written to the file, takes no undo slot and does not
  set the modified flag. It stays through a descend and the way back, an undo, a redo and
  `xschem reload`; a load of another file into the window, File > Open in place and
  `xschem clear` drop it.

**In the Calculator.** With `it`, `if`, `idc` or `is` armed, a click on a device pin is that
terminal's current (`doc/claude/specs/calculator.md` R208f). The click asks the same pin rule
and the same naming rule as Select On Design (`calc::pick_imeasure` calls
`ase::ui::sod_terminal_at`, `ase::ui::sod_terminal_resolve` and `ase::ui::sod_source_at`).

- The Calculator writes no deck, so the current is inserted only when the loaded result holds
  it. The token is built from the name the result's reader stores, which has a dot where the
  row has a colon: R9's first pin inserts `it(r9.n1)`, a drain one level down
  `it(x1.xm1.d)`, and `idc(…)` on an operating-point result.
- A terminal the result does not hold: `selector it: i(M1:d) is not in this result; ASE-L
  Outputs: To Be Plotted, rerun`. The Calculator reads the database the session's viewer has
  loaded, and a finished run loads its results there only when it plots a row. A pin picked
  under To Be Plotted is saved and plotted, so that run is seen; one picked under To Be Saved
  is in the results file and not yet seen.
- On the pin of a voltage source or an ammeter the source's own current is inserted when the
  pin's is not in the result, or the pin is refused a name. On the source's first pin nothing
  more is said. On its second pin the inserted current is the negative of the pin's own, and
  the click says so before its last sentence: `selector it: V1 pin m: inserted the source's
  current, the negative of this pin's` (arm `srcneg`). On a pin that is neither of the
  first two nodes (the controlling pins of `vsource_pwl.sym`, a pin of `filesource.sym`) it
  says `selector it: E1 pin cp: inserted the source's current, which is not this pin's`
  (arm `srcother`). Where other device pins share the point: `selector it: that point is
  also R7 pin P; the click took the current of V1`. Once the second pin is probed the same
  click inserts `it(v1.n2)`, of the opposite sign, and says nothing. Which node a pin is
  comes from ASE-L's rule, `ase::ui::sod_term_pin_place`, asked through
  `calc::pick_iplace` (with `ase::ui::sod_term_first_pin` as the fallback where that rule
  is absent); the plan's source step carries it as `place`.
- A bus pin is refused (`… is a bus; pick one bit`); a pin that cannot be named is refused
  with the naming rule's reason. The Calculator's pick adds no marker.
- With a current selector armed the design window's prompt ends with the pin the pointer is
  on: `Calculator it: click a device pin, voltage source or ammeter; ESC cancels — pin
  R9:P` (`calc::pick_hover`). A voltage selector's prompt names no pin.
- Arming a selector ends a live Select On Design first, as its ESC does
  (`calc::pick_end_sod`): the outputs it queued stay, its ellipses go, a Direct Plot plots
  what it had queued. A selector that refuses to arm leaves it up. When the Results Display
  Window's pick mode sits on top of the Select On Design that is ended, that mode takes
  the canvas again (`rdw::pick_reseat`) and the pick stacks on it.
- With the Results Display Window's pick mode on top of an armed pick, every door that
  ends the pick leaves that mode holding the canvas: the armed selector pressed again,
  another selector pressed, the Calculator window closed (`calc::pick_end` calls
  `rdw::pick_reseat` whenever it released a pick). One ESC then ends that mode and the
  canvas is free. Taking the canvas again also takes the keyboard: it moves from the
  Calculator's buffer to the schematic, where that mode's ESC is, and keys typed next go
  to the schematic until the buffer is clicked (measured in the closing pass).
- With a pick armed on top of the Results Display Window's pick mode, that mode ended
  first (Escape pressed in the Results window) leaves the pick armed and on the canvas:
  `rdw::pick_end` asks `calc::pick_reseat`, which seizes again when it finds the pick
  with nothing bound. The selector stays lit, the prompt stays, a click is still the
  pick's, and one ESC on the schematic ends it and frees the canvas. A pick whose click
  has already resolved and that is waiting for its release keeps its end on the release
  slot. Here too the keyboard ends on the schematic (the last build).
- While the Results Display Window's mode is on top of an armed pick the design
  window's slot shows that mode's sentence, and the pick's prompt is back when that
  mode ends (`calc::pick_covered`, asked by `calc::pick_pump`).
- A pick follows a return from a block opened in a window of its own to a parent that is
  in a tab other than the first (Ctrl-E in the Cadence-style profile), as Select On Design
  does: `calc::pick_resume` resolves the context it is handed to the canvas that shows it
  (`calc::pick_canvas`, which takes that context as an argument). The Results Display
  Window's pick mode does the same (`rdw::pick_resume`, `rdw::_pick_canvas`), and its
  keys 1 to 3 with nothing selected now arm it in such a tab (`rdw::pick_start`; the tab
  half of issue 1387). Before this the pick stayed armed on the window the user had just
  left, a click on the parent's sheet was no pick at all, and the keys did nothing in
  such a tab. After a dump made in such a tab the keyboard goes back to the schematic,
  as it does in the first tab (`rdw::_focus_canvas` resolves the tab's name the same
  way; before the closing pass it stayed in the Results Display Window).
- With a pick armed both presses of a double click are the pick's, so a miss is answered
  twice and nothing reaches the editor (`calc::_pick_seize` holds the double click too). A
  pick that resolved has ended by the second press (Limits).
- The click is resolved where the button was pressed, as in Select On Design: the press's
  script, and the double click's, first hand the engine the press's own position. Before
  this, a press after the canvas had been laid out again answered `nothing under the click`
  (a voltage selector) or `nothing there` (a current selector) about a wire or a pin the
  pointer was on. The Results Display Window's pick mode does the same on its press
  (`rdw::_pick_seize`); there it answered `no device under the click`.
- A window made while a pick is armed (`xschem new_schematic create_window`) carries the
  editor's bindings and none of the pick's, and clicks there select
  (`calc::pick_held`, and `rdw::pick_held` for the Results Display Window's mode).

**In the Signal Browser** (`src/wave_viewer.tcl`). A terminal current is stored with a dot,
`i(x1.xm1.d)`, so it files under a tree node named after its device, `x1.xm1`.

- Its label is its terminal: `d:i`, `n1:i`, and `in_p:i` for a block's port
  (`wviewer::browser_label`). The rule that reads an underscore as a model name does not apply
  to it, so `in_p` and `in_n` of one block are told apart and a MOS bulk reads `b_tj:i`.
- **Descend to here** on such a node takes the schematic window to the sheet the device is on
  and selects the device (`wviewer::hier_walk` with its `leaf` argument, from
  `wviewer::browser_descend_to`): `'xm9' is a device with no sheet of its own; selected M9 at
  the top level`. A device drawn `M9` with a `spiceprefix` is found under the name it netlists
  as (`ase::inst_path_segment`). When several instances could be the one meant, none is
  selected and all are named.

## What was built

- **The message pass (2026-11-20), Tcl only.** In `src/ase.tcl`: the capability key
  `hier_probes` (`ase::caps_keys`; `ase::backend::ngspice::cap_hier_lines` and the leg of
  `ase::backend::ngspice::capabilities` that rides deck C; the clause in
  `ase::backend::ngspice::variant_notes`); `ase::probe_marker_answer`, the one reader of the
  marker's line, for the run's log and for the probe's file; `ase::probe_needs_hier` and
  `ase::probe_plan_hier`; `ase::sim_run_name`; the cure, `ase::probe_cure` over
  `ase::probe_cure_entries` (with `ase::probe_cure_verdict`, `ase::sim_entry_file`,
  `ase::sim_caps_forget`, the variables `ase::probe_cure_ms` and `ase::probe_cure_seen`,
  the latter forgotten by `ase::sim_caps_clear`); the kinds `probe_hier` and
  `probe_hier_plot` of `ase::sim_why`; `ase::probe_start_report` and its call in
  `ase::run_deck`, which also puts `simname` in the run record; the `hier` record of
  `ase::probe_report` in place of the `oldbuild` note; `ase::probe_said_keep`,
  `ase::probe_said_clear`, `ase::probe_said_for` and the variable `ase::last_probes`;
  `ase::probe_pick_report`; `ase::probe_absent_groups`. In `src/ase_window.tcl`:
  `ase::ui::sod_terminal_pick` calls the last two. Added by the repair pass of the same
  day: `ase::probe_cure_peek` (the verdict `untried`), `ase::probe_cure_key`,
  `ase::probe_cure_kept`, `ase::probe_cure_fair`, the variables `ase::probe_cure_each_ms`
  and `ase::probe_cure_min_ms`, `ase::probe_cure_carry` and `ase::probe_cure_restore`
  (called by `ase::sim_register` and `ase::sim_unregister`), `ase::cap_key_args`;
  `ase::sim_session_view` and `ase::probe_session_verdict`, with the `say` argument of
  `ase::sim_apply_choice`; `ase::session_holding` and the `session` key of the run record
  and of `ase::last_probes`; the roles and endings of `probe_hier_plot`. Rows: PH12b,
  PH13c, PH13d, PH35 and PH36 and the moved PH12, PH13, PH13b, PH14 and PL20 of the deck
  suite; TPV9, TPV9b, TPV11b, TPV16 and TPV17 and the moved TPV6, TPV8 and TPV10 to TPV15
  of the pick suite. Rows: band PH (rows PH1 to PH34 and PC1
  to PC5), rows PL6, PL19 to PL22 and PW2 as moved, the new rows PL21b, PL21c and PL30, and
  the real-simulator rows PN14, PN15 and PN15b of
  `tests/headless/test_ase_probe_deck_1724.tcl`; band TPV of
  `tests/headless/test_ase_terminal_pick_1724.tcl`; rows VS3c, VS3d, VS4a2 and EX4, and
  the moved shapes, of `tests/headless/test_ase_variant_1470.tcl`; row WG7/v53 and the
  moved shapes of `tests/headless/test_ase_simwin_variant_1471.tcl`. Added by the round
  after the repair pass, the same day: the `not tried yet` sentence of `ase::probe_cure`
  says the steps to Detect (decision 68), and no other code changed. Rows: PH12c (the
  entries the cure does not ask, read by a peek), PH17b (the `Edit…` and `Detect` buttons the
  sentence names, read off the two dialogs' builders, and the sentence spelled out) and
  PH37 (the session in the run record, through `ase::run_deck` with the session edited
  while the simulator runs) of the deck suite; TPV6b of the pick suite and, in its row
  TPV13, one new leg (a report made from a record that names this session, after the
  session was edited) and the leg of a run that asked and said nothing, whose record
  now names this session too (it named none, so that leg stayed green with the plan
  ignored); WG8 of `tests/headless/test_ase_simwin_variant_1471.tcl`, which takes the
  sentence's steps through the real menu and buttons on the display arm, each found by
  the label the sentence gives it.
- **The pin probe.** `xschem pin_at <x> <y> [-all]` (`xschem_cmds_p()`, `src/scheduler.c`):
  read-only, the pin-select click's own hit rule. `pins_in_pick_radius()` in `src/findnet.c` is
  the one walk `find_closest_pin()` and the new `find_pins_at()` share. A pin whose distance
  is not a number is out of range, as it was before the walk was shared; a coordinate that is
  not a number, whole word, is a usage error.
- **The pin's own rectangle.** `point_in_inst_pin_rect()` (`src/findnet.c`): a point inside a
  pin's drawn rectangle reaches that pin whatever the zoom. It is part of the one hit rule,
  so the editor's pin-select click, `xschem pin_at` and the mode's pin test changed together.
  The distance recorded for such a pin is still the one to its centre, so the nearest-first
  order is unchanged.
- **The lookup rung.** xschem's raw reader stores every `:` of a variable name as `.`
  (`read_dataset()`), so the row's `i(x1.xm1:d)` is stored `i(x1.xm1.d)`. `get_raw_index_in()`
  (`src/save.c`, with `raw_lookup_rungs()`) retries a query holding a `:` on its dotted
  spelling, and `wviewer::name_rungs` mirrors it. Spec: `doc/claude/specs/raw_case_mode.md` §9.
- **The marker's engine.** A list of `Pin_marker` per window or tab in `Xschem_ctx`
  (`src/xschem.h`), keyed by hierarchy path, instance name and pin index;
  `pin_marker_add()`, `pin_marker_remove()`, `pin_marker_clear_in()`, `pin_marker_clear()`,
  `pin_marker_resolve()` and `draw_pin_markers()` in `src/draw.c`, the last called from
  `draw()`; the command `xschem pin_marker add|remove|clear|list` (`src/scheduler.c`); the
  clears in the `unhilight_all` and `load` branches there and in `ask_new_file()` and
  `clear_schematic()` (`src/actions.c`); `pin_marker_clear_linked_windows()` (`src/hilight.c`),
  which the `unhilight_all` branch calls for the windows linked by a descend, except while
  the window is in the middle of a gesture (`net_hilight_ctx_gesturing()`). Spec:
  `doc/claude/specs/pin_selection.md` §4.7.
- **The pick** (`src/ase_window.tcl`): `ase::ui::sod_click`, `sod_terminal_at`,
  `sod_inst_is_device`, `sod_inst_ignored`, `sod_wire_wins`, `sod_wire_near`,
  `sod_term_toward`, `sod_term_toward_box`, `sod_term_box_centre`, `sod_term_edge_on`,
  `sod_term_pin_names`, `sod_term_pin_xy` (the two readers the last build gave the
  same-point rule; the first asks the engine's list of names before the attribute
  strings since the build after it), `sod_term_format`, `sod_term_pins`,
  `sod_term_pieces`, `sod_term_rewrite`, `sod_term_lines`, `sod_term_where`,
  `sod_term_letter_name`, `sod_term_own_block`, `sod_term_device_model`,
  `sod_term_abs_cards`, `sod_term_stale_cards`, `sod_term_header_remedy`,
  `sod_term_header_gap`, `sod_term_port_lists`, `sod_term_ports`, `sod_term_sym_def`,
  `sod_term_sym_def_ports`, `sod_term_prefixed_ancestor`, `sod_term_name`,
  `sod_terminal_resolve`, `sod_terminal_as_source`, `sod_term_first_pin`,
  `sod_term_line_pos`, `sod_term_pin_place`,
  `sod_source_standin_notes`, `sod_mark_pin`, `sod_marks_clear`, `sod_term_unwritable`,
  `sod_terminal_pick`, `sod_entry_notice`, and the `terminal` arm of `dp_hilight`.
  `sod_subckt_scan`, `sod_subckt_walk` and `sod_subckt_lib` forward to the core's header
  reader and keep no memory of their own. The pick never netlists.
- **The mode's lifecycle** (`src/ase_window.tcl`): `ase::ui::sod_slots` (the table of the
  slots), `sod_press_script` (the press hands its own position to the engine),
  `sod_seize`, `sod_own_script` and `sod_dbl_editor` (the seize, shared by
  `select_on_design` and `sod_resume`; a slot found holding the mode's own script is never
  kept as the previous binding, and a double-click slot with no record falls back to the
  editor's script), `sod_release`, `sod_held` (what the mode holds, for `cmdmode`),
  `sod_canvas` (the canvas widget of a window context, also for a tab), `sod_canvas_gone`,
  `sod_drop_gone`, `sod_drop`, `sod_design_shown`, `sod_elsewhere_notice`,
  `sod_prompt_base`, `sod_prompt_words`, `sod_prompt_text`, `sod_pointer_elsewhere`,
  `sod_prompt_now`, and, at the head of `select_on_design`, the Calculator pick ended and
  the Results Display Window's mode asked to take the canvas again after each mode the
  entry ends. `ase::ui::close` asks the same after it has ended the session's Select On
  Design. From the last build: `sod_reseat` (the mode takes the canvas again after the
  Results Display Window's mode was ended underneath it; it does nothing in every other
  state), with `sod_overlaid` (does a mode that is up hold this script in the press
  slot), and `sod_covered` (is another mode that is up seized over this one), which
  `sod_prompt_pump` asks before it writes the prompt. From the build after it:
  `sod_release` writes nothing for a mode that a descend has paused, and neither do
  `calc::pick_release` and `rdw::pick_release`; each answers that there was a mode to
  end, and the ends go on as for any other.
- **The command-mode contract** (`src/cmdmode.tcl`, `src/xschem.tcl`): the optional fourth
  argument of `cmdmode::register`, a callback that answers what the mode holds on a canvas
  now; `cmdmode::pristine` and `cmdmode::seq_spelled`, which answer the script a slot would
  hold with no mode up; `clone_canvas_bindings`, which asks it for every script it is about
  to copy onto a new canvas, and `bind_seq_spelling` beside it (Tk's own spelling of a
  sequence, so a mode may declare `<ButtonPress-1>` although `bind` lists `<Button-1>`);
  `cmdmode::release_order` and `cmdmode::holds_over`, by which `cmdmode::suspend_all`
  releases the top of a stack first (read from what the modes declare they hold, by canvas
  and script, with no Tk). Issues 0201, 0202 and 1307 have the detail.
- **The deck and the report** (`src/ase.tcl`): `ase::probe_split`, `ase::output_probes`,
  `ase::output_is_probe`, `ase::output_saves_any`, `ase::probe_mode`, `ase::probe_top_card`,
  `ase::probe_x_calls`, `ase::probe_x_ports`, `ase::probe_card`, `ase::meas_probes`,
  `ase::probe_asked`, `ase::probe_plan`, `ase::probe_terms`, `ase::probe_netlist_terms`,
  `ase::probe_terms_new`, `ase::probe_marker`, `ase::probe_refusals`,
  `ase::probe_nohdr_note`, `ase::probe_row_swept`, `ase::probe_report`;
  the one `.subckt` header reader,
  `ase::subckt_scan`, `ase::subckt_walk`, `ase::subckt_lib`, with `ase::subckt_model_cards`;
  `ase::facts_netlist_file`; the exclusions in `ase::output_card_sources` (a terminal in
  either role; an expression's read of a name no `.save` card can carry) and in
  `ase::saves_unresolved`; the leader in `ase::saves_all_forced`; the cards and the echo in
  `ase::backend::ngspice::render_deck`, and that backend's `missing_spoken` and
  `missing_row_note`; the `probes` key of `ase::run_deck`'s run record; the report call in
  `ase::run_done`.
- **The Calculator** (`src/calculator.tcl`): `calc::pick_imeasure`, `calc::pick_iplan`,
  `calc::pick_iplace`, `calc::pick_iresolve`, `calc::pick_inotes`, the current arm of
  `calc::pick_click`, and the arms `iarmed iprompt inothing notsource noterm absent also
  caution srcneg srcother pinerr` of `calc::pick_msg`; `calc::pick_end_sod` (called by
  `calc::pick_arm`); the call of `rdw::pick_reseat` in `calc::pick_end`, made when a
  pick was released; the context argument of `calc::pick_canvas`, which
  `calc::pick_resume` hands it; `calc::pick_hover` and
  `calc::pick_hover_text` (written by `calc::pick_pump` and `calc::pick_echo`); the double
  click in `calc::_pick_seize` and `calc::pick_release`, with `calc::pick_dbl_editor`; the
  press's own position handed to the engine by the press and the double-click script; and
  `calc::pick_held` (what the pick holds, for `cmdmode`). From the last build:
  `calc::pick_reseat` (the pick takes the canvas again after the Results Display
  Window's mode was ended underneath it), `calc::pick_own_script`,
  `calc::pick_overlaid`, and `calc::pick_covered`, which `calc::pick_pump` asks before
  it writes the prompt.
- **The Results Display Window** (`src/rdw.tcl`): `rdw::_pick_seize` and `rdw::pick_release`
  hold the double click as well; there the second press is swallowed. The press hands its
  own position to the engine first. The seize never keeps the mode's own scripts as the
  previous bindings (`rdw::pick_own_script`), and with no record the double click falls
  back to the editor's script (`rdw::pick_dbl_editor`). `rdw::pick_held` is what the mode
  holds, for `cmdmode`. `rdw::pick_reseat` takes the canvas again after another click mode
  was ended underneath this one, and does nothing in every other state
  (`rdw::_pick_overlaid` is its test for a mode that is up holding the press slot).
  `rdw::_pick_canvas` resolves a window context to the canvas that shows it, for
  `rdw::pick_start`, `rdw::pick_resume` and `rdw::_focus_canvas` (the keyboard handed
  back to the schematic after a dump). From the last build: `rdw::pick_end` asks
  `ase::ui::sod_reseat` and `calc::pick_reseat` once its own record is gone, when its
  release released a mode; and `rdw::_pick_covered`, which `rdw::_hint_sync` asks
  before it writes the sentence (the tag on the canvas, the tooltip and the blanking of
  what it last wrote go on as before).
- **The viewer** (`src/wave_viewer.tcl`): the terminal-current exception in
  `wviewer::browser_label`; the third tier of `wviewer::hier_resolve`; `wviewer::hier_scan`,
  `hier_device`, `hier_no_sheet`, `hier_stay`, `hier_device_msg`; the `leaf` argument of
  `wviewer::hier_walk`.
- **Fences**, each registered in `tests/run_regression.tcl`, whose comments say in which list
  and why:
  - `tests/headless/test_pin_at_1724.tcl`: the probe (bands PA; band PA9 is the pin's own
    rectangle, on unrotated, rotated and flipped instances) and the rung (bands LR);
  - `tests/headless/test_ase_terminal_pick_1724.tcl`: the click, the naming, the refusals,
    the notices, the window test (rows TPH11 to TPH14), the prompt (rows TPM6 to TPM11), a
    name the deck cannot carry (band TPU, on a scratch sheet with a port named `Y=1`) and
    the mode's lifecycle with the canvas stood in for (band TPL: the slots taken and handed
    back, the double-click fallback in row TPL4b, what the mode reports it holds in rows
    TPL9 and TPL9b, the press script run after the pointer was overwritten in row TPL10,
    the canvas of a tab in rows TPL11 and TPL12); no simulator. From the fourth repair:
    blocks with unequal pin sets, a title that reaches over the neighbour and the box
    without its texts (rows TPR4n to TPR4t); the place of a source's pin and what Direct
    Plot says on each (rows TPP13 to TPP14b, on `vsource_pwl.sym` and `filesource.sym`);
    the prompt with the pointer in another window (row TPM12); the Results Display
    Window's mode asked to take the canvas again (row TPL1c); what the drop says in Direct
    Plot (rows TPL6 and TPL6b). From the closing pass: two instances of the shipped
    `xcross.sym`, whose pins share names (row TPR4u); a one-pin capacitor placed later on
    the sheet than the resistor it shares a point with, which tells "any device on the
    point" from "the first one" (row TPR4v); the middle of the box held against the
    engine's own box in all eight placements of a text-free block (row TPR4s, restated);
    the stock LED (a leg of row TPR4r); the drop in an outputs flavour with a queue on
    record (a case of row TPL6b); a position written `08` (a leg of row TPP13). From the
    last build: scratch symbols whose pin names end in a backslash on points shared with
    a resistor, a two-pin device, a one-pin device and a block whose click is then
    refused (row TPR4w); a second one-pin capacitor, placed EARLIER on the sheet than
    its resistor, which tells "any device on the point" from "the last one" (a leg of
    row TPR4v); the mode taking the canvas again after another mode was ended
    underneath it, and doing nothing in every other state (row TPL13); the prompt's
    timer writing nothing while another mode sits on top, and ticking on (row TPL14).
    From the build after it: a two-pin device with plain pin names and another pin
    attribute that ends in a backslash, on a sheet of its own (row TPR4x); and the
    release of a paused mode writing nothing, for Select On Design, the Calculator's
    pick and the Results Display Window's mode, each entered over five scripts that
    stand for another mode's, on a stood-in canvas (row TPL15).
    The suite is in both gate lists (`hcases` and `dcases`; in `dcases` since the closing pass),
    so its display arm is a gate arm: a recorder stands in for
    `tk_messageBox`, row TPU6 says what the engine asked for, and the last row, TPZ1, names
    any box asked for elsewhere. Before that recorder the display arm stopped at the
    engine's modal box about the fixture instance `R=B[1:0]`;
  - `tests/headless/test_ase_probe_deck_1724.tcl`: the deck, the report, and every
    real-simulator row: band PN, band PE, which goes from a click on a sheet to the vector
    in the results, and rows PA8g and PA8h. They are announced by a `skip:` line where no
    ngspice answers `$?probe_version` = 1. Rows PL15e to PL15h and PA8h are the note beside
    a sweep of a design variable; rows PX7, PR11d, PN12 and PN12b the expression read that
    makes no card; rows PL28, PL28b, PL29 and PL29b the convergence key (with the
    transient-op rung on and off, and the warnings that are not in it); rows PN13 and
    PN13b a bench that converges only on the transient-op rung, and the same bench failing
    with that rung off, on the simulator. The other failure lines that rows PL28b, PN13
    and PN13b look for are read out of the key of `ase::probe_report` itself, and a PD0
    fixture row goes red when that key cannot be read;
  - `tests/headless/test_pin_marker_1724.tcl`: the command and its list, the clears (rows C8
    and C9: a window and a tab linked by a descend), ASE-L's picks through the real
    `ase::ui::sod_click` (band G), and on a display band P, announced by a `skip:` line
    without one: the pixels, a real click, a real ESC, the real viewer, two linked windows
    (group P7), the window closed under the mode (group PC), the prompt naming the pin
    (group PN), a drag in the mode (group PD), a press after the pointer was overwritten
    (group PS), a window made while the mode is up (group PW), the clear-all given in the
    middle of a gesture (group PV), the design in a second tab (group PT), the prompt
    with the pointer in another window of the design, after a descend into a new window
    (group PE), Direct Plot's window closed with traces queued (group PF) and the
    clear-all keys pressed for real, with a drag under the Cadence-style profile in row
    P8d (group P8);
  - `tests/headless/test_ase_interact.tcl`, on a display: a real double click and a triple
    click in the mode (row I2b), the slots handed back (rows I7, I10), the session window
    closed with the Results Display Window's mode on top of Select On Design (row I11:
    that mode holds its five scripts on the canvas again, and one real ESC ends it), the
    Results Display Window's mode ended first from under a Select On Design entered by
    its menu entry (row I12: Select On Design holds the canvas again, a real press still
    queues, and one real ESC leaves every binding as before any mode), the session
    window closed while a descend has Select On Design and the Results Display Window's
    mode under it paused (row I13: nothing is written on the canvas, a real Escape drops
    the descend and that mode comes back alone) and
    the mode entered from the session's menu with the design in a second tab (rows IT0 to
    IT3);
  - band PK13 of `tests/headless/test_calc_selector_names.tcl` and band PG19 of
    `tests/headless/test_calc_pick.tcl`: the Calculator's pin pick; band PK14 and bands PG20
    to PG23: the two modes ending each other, the double click, the prompt naming the pin;
    band PK15 and bands PG24 to PG26: the press's own position, what the pick reports it
    holds and a window made while it is armed, and the Results Display Window's seize not
    keeping its own scripts; band PG27, with real events: a third mode entered over the
    Results Display Window's mode (three orders and a control), the Calculator's own
    doors under that mode (another selector, the same selector again, the Calculator
    window closed) and a pick with that mode on top taken through a descend in the same
    window. From the last build: band PG26 is one row, the Results window's scripts
    written by hand onto a canvas no mode holds (the doors no longer leave that state);
    band PG27 has the Results window's mode ended first from under a pick and from under
    Select On Design, a pick whose click has resolved, the end that released no mode
    asking nothing, and the states in which `calc::pick_reseat` does nothing; band PG28
    is the status bar under each of the four stacks of two (one sentence, the top
    mode's, and the lower mode's back after one ESC); band PG29 is a mode ended while a
    descend has the stack paused (the Results window's mode from over a pick; a pick
    from over that mode, by its selector pressed again and by the Calculator window
    closed; Select On Design from over that mode, by a selector pressed), each reading
    every binding of the canvas straight after the end; the rows of band PK13
    about which node of a source a pin is (on `vsource_pwl.sym` and `filesource.sym` as
    well), and the row of band PK15 about a pick resumed with the name of a tab;
  - rows BL01 to BL06 of `tests/headless/test_wave_sigbrowser.tcl` (the label) and the BV
    rows of `tests/headless/test_wave_sigbrowser_panes.tcl` (Descend to here on a device).

  Suites that carry rows of this work and were in no gate list when the third repair
  began (`/usr/bin/grep -n <suite> tests/run_regression.tcl` says whether one is now):
  `tests/headless/test_cmdmode_0201.tcl` (legs CR4 to CR9: the contract's fourth argument,
  `cmdmode::pristine`, and on a display `clone_canvas_bindings` between real canvases and
  through the real new-window door; band CR6 is the release order of stacked modes,
  against stub modes, with a mode that declares nothing registered between the two of a
  stack in row CR6i and one mode registered and unregistered again in row CR6s; row CR7c
  is `clone_canvas_bindings` with no Tk),
  `tests/headless/test_cmdmode_descend_0201.tcl` (the slots across a descend; rows CS1e,
  CS1f, CS2b, CS3g, CS7d, DS6k; leg DS8 is the Results Display Window's mode over Select
  On Design across a descend into a new window and, in rows DS8j to DS8q, across a
  descend in the same window, with real ESC and real clicks; leg DS9 is a mode ended
  while the descend has that stack paused, in both orders: a real Escape in the Results
  window, and Select On Design entered again, each followed by the real click the
  descend was waiting for),
  `tests/headless/test_sod_pick_no_select_0204.tcl` (rows SO13a to SO13e, and SO15a to
  SO15c: a pick whose pointer drifts), `tests/headless/test_ase_plot.tcl` (the slots in
  Direct Plot, rows P2 and P4), `tests/headless/test_rdw_keys_1245.tcl` (rows B0d and V3b:
  the Results Display Window's double click; section XP: its press after the pointer was
  overwritten, its seize, a window made while its mode is up, in row XP7 when
  `rdw::pick_reseat` takes the canvas and when it does nothing (a canvas that is gone
  and a canvas the mode already holds, with `cmdmode` out of reach, among them), and in
  row XP8 the key, the resume and the keyboard after a dump in a real second tab; row
  WM0 names the window manager, and rows F3 and RA4 are left out, under an upper-case
  line, on a display that has none or whose manager has died; row E6, from the last
  build: the real Escape pressed in the Results window's text pane with Select On
  Design on top of its mode, the keyboard on the canvas afterwards and one real ESC
  there) and
  `tests/headless/test_rdw_window_1245.tcl` (rows K19 to K21; row HT14, restated: the
  mode arms in a tab).

  Reds that are not this work's, measured 2026-11-19 on the display arm, three runs each,
  on a build of `d36cb429e` and on the working tree with byte-identical output:
  `tests/headless/test_wave_sigbrowser_keys.tcl` rows BK29 and BK31 (beside the known BK22)
  and `tests/headless/test_wave_sigbrowser_0312.tcl` rows BF21a and BF24a. Neither suite is
  in a gate list.

  Fixtures: `tests/headless/data/probe_1724.cir`, `probe_1724_op.raw`, `probe_1724_tran.raw`.
- **Specs and user text.** `doc/claude/specs/ase_l.md` ("Select On Design v1 scope", "A click
  on a device pin queues its terminal current", R-OUT17), `pin_selection.md` §4.2, §4.6 and
  §4.7, `raw_case_mode.md` §9, `waveform_viewer.md` ("Terminal currents from a pin click",
  "Hierarchy sync"), `waveform_signal_browser_two_pane.md` §5.4 and §10, `calculator.md`
  R208, R208b, R208e, R208f and R307, `net_hilight_styles.md` §5.3 and §6.2,
  `op_param_lists.md` landmine 11, `doc/claude/FAQ.md` Q95, `doc/ase_l_tutorial.html`
  ("Terminal currents"), `doc/waveform_viewer_guide.html` (the Direct Plot row, the `E` row
  and §11), the brief `doc/claude/ngspice_terminal_current_probes.md` ("Measured from the
  xschem side"), and the quiz entries `direct-plot` and `calc-pick` of
  `src/startup_quiz_bank.tcl`. Issue 0202 holds what the second review and the two repairs
  after it measured about click modes that share the canvas; issue 1304 the held motion on
  this mode, measured and then held; issue 1307 the window made while a mode is up; issue
  0201 the contract's fourth argument and the release order of stacked modes; issue 1659
  the engine's pointer and what the three click modes now do about it; issue 1387 the
  Results Display Window's keys in a tab and the status slot two modes used to write
  at once; issue 1713 the first tab coming to the front
  beside a real window; issue 1726 a real window's toplevel left standing by `xschem
  new_schematic destroy_all` (the engine's, found on the way); `op_param_lists.md` §2.5
  the seized sets as they stand.

## Decisions taken on the user's behalf — each awaits a yes or a no

Numbers 1 to 27 are the ones this file carried before the second review; those it changed
are restated here (2, 5, 9, 10, 12, 17, 19, 26, 27). Numbers 28 to 44 were added after it and
stand under the heading they belong to. The third repair restated 19 and 39 and added 45 to
49, which stand under their headings too. The fourth repair restated 5, 12, 26, 33, 34 and
38, each with a pointer to the new decision it leads to, and added 50 to 55. The closing
pass after it added none: what it built follows decisions already here (5 and 51 on a
shared point, 35 and 54 for the click modes, 38 and 55 for the convergence note). One
consequence of it that the user may want to rule on, the keyboard moving to the schematic
when a pick is ended under the Results Display Window's mode, is under Limits ("The
mode") and in open item 5. The last build added none either. What it built follows
decisions already here: 5 and 51 for a symbol whose pin names end in a backslash (a
two-pin device is chosen by its pins, a one-pin device by its box) and 47 for a block
port of that kind, whose click is refused; 35 and 54 for the mode on top keeping the
canvas when the Results Display Window's mode is ended first; and 33 and 52 for the one
sentence on the status bar under two stacked modes (the bar says what a click would do,
and the clicks are the top mode's). What it left for the user is in open item 5: the
keyboard on the schematic after a mode has taken the canvas again, whether the Results
Display Window's mode should nest at all, and a real stack. The build after it added none:
a mode ended while a descend has it paused leaves the canvas alone, which follows 54 (the
canvas is the editor's while the modes are paused), and a symbol with plain pin names is
read by its names, which follows 5 and 51 (its pins say its side; the box is for a device
whose pins say nothing).

The pick:

1. A click within reach of a device pin (its own square, the device's lead beside it) is the
   terminal's current, whether or not Options > Enable pin selection is on.
2. A click on a wire, or within a pixel or two of one, is the wire's voltage, also right
   beside a device pin: there only the pin's small square is the terminal.
3. "On the pin" stops at 10 schematic units from the pin's point, on top of the pin-select
   radius, so the body of a source stays pickable at a far zoom.
4. The pin test reads the pointer, not the snapped crosshair. With `draw_crosshair` on, the
   crosshair can sit on a pin while the pointer, a little further off, is on the wire, and the
   click then queues the wire's voltage.
5. Where two devices have pins on one point, the side of that point the cursor stands on
   chooses the device: the side towards the middle of the device's pins and, where two
   devices measure the same that way, towards the middle of the device's box. Exactly on the
   point, the lower instance index. Where a device's pins say nothing about its side it is
   decision 51.
6. The pin of a voltage source or an ammeter is a terminal (`i(v1:n1)`) in the three flavours
   that write rows, while a click on its body stays the branch current `i(v1)`.
7. The pin of a net label or a port stays a voltage pick; where it shares its point with a
   device pin, the device wins.
8. A bus instance or a bus pin opens the Select Bus Bits dialog, one entry per terminal.
9. A subcircuit call whose port ASE-L cannot read off a `.subckt` header is named by the
   symbol's pin, with a caution, instead of being refused. That covers three cases, and the
   caution says which: no header is found; the place that answers holds several headers
   whose ports differ; the one header found has too few ports.
10. That caution, and the refusal for a call with a netlist format of its own, end with what
    to do. For no header and for one that is too short: netlist the design from ASE-L (or
    run), or name the model file under Setup > Model Files, then pick again. For several
    that differ: leave one definition where they are, then pick again.

Added after the second review:

28. The box of a net label that reaches within range of a device pin is the terminal's
    there, except within a pixel or two of a wire. For the net's voltage the user clicks the
    wire, or the label farther from the pin.
29. A point inside a pin's own drawn square is the pin at any zoom. This changed the
    editor's own pin-select click too (Options > Enable pin selection): zoomed far in, a
    click on the corner of a pin's square used to miss the pin and now selects it.
30. The device's lead beyond the square is the terminal only as far as the pin radius
    reaches, a fixed distance on the screen. Zoomed far in, a point a few units down the lead
    is not the terminal.
31. Both presses of a double click in the mode are picks. The editor's own double click (its
    property dialog; connected-select under the Cadence-style profile) does not run while
    the mode is up.
32. A click in a window or tab that shows neither the session's design nor a sheet below it
    queues nothing, says so and leaves the mode armed.
33. While the mode is up, the design window's prompt names the pin a click would take
    (`select outputs on design — pin R1:P (terminal current)`). In which window it does so
    is decision 52.
34. Closing the window the mode is on drops the mode. The row flavours' ellipses go from
    every window that is left, and the CIW says the mode was dropped. In Direct Plot nothing
    queued is plotted and the colours its picks left stay until the highlights are cleared;
    what the CIW says about that is decision 53.
35. Select On Design and a Calculator selector's pick never hold the canvas together:
    entering either one ends the other first.

Added by the third repair:

45. A drag in the mode is one pick, made where the button went down, and nothing else: no
    selection rectangle starts and the selection made before the mode is kept. (The mode
    holds the pointer motion with the left button held.)
46. A window made while a click mode is up (Select On Design, a Calculator selector's pick
    or the Results Display Window's pick mode) is an ordinary editor window: clicks there
    select, and ESC pressed there is the editor's. The mode ends by ESC in the window it is
    on.
47. A click on a pin whose instance or port name holds a character a terminal row cannot
    hold queues nothing, marks nothing and says so, with what to do (rename the instance or
    the port, or place an ammeter in series). The characters are a dollar sign, an equals
    sign, a single quote, a brace, a semicolon, a comma, a parenthesis, a double quote, a
    blank and a second colon. A bus instance is also judged by its own name as the sheet
    writes it (its bits can come back without the character). In Direct Plot the pin of a
    voltage source or an ammeter with such a name plots the source's own current, as
    decision 12 has it for any pin of a source that cannot be plotted.

Added by the fourth repair:

51. Where a device on a shared point has pins that say nothing about its side (a block with
    every pin on one edge, a one-pin symbol), every device on that point is chosen by the
    side towards the middle of its symbol's box, texts not counted. The reason: with
    unequal pin sets the pin measure let the side of the lead's axis choose the block, so a
    click on one block's lead took the other block's pin, and a title that reached over
    the neighbour moved the box that was used before.
52. The prompt names a pin only while the pointer is in the window the mode is on. With the
    pointer in another window of the design it shows the mode's words alone. The reason: a
    click in that other window is the editor's, and the prompt is to name only what a
    click would take.
53. When the window Direct Plot is on is closed with traces queued, the CIW says how many
    were not plotted and that the colours their picks left on the schematic stay until the
    highlights are cleared, naming the menu entry (Highlight > Un-highlight all net/pins).
    Nothing is cleared by the drop. The reason: clearing Direct Plot's ellipses there
    would also take those of earlier plots whose traces are still in the viewer, the net
    colours would stay all the same, and the key that clears differs by key profile.
54. A descend releases stacked click modes from the top down and puts them back from the
    bottom up, so the stack comes up where the descend lands in the order it had. The
    reason: released in the order the modes were registered, a stack with the Results
    Display Window's mode on top left every canvas on dead scripts after any descend.

Direct Plot:

11. Direct Plot refuses a terminal the last run did not save; it neither adds a probe nor
    runs.
12. On the pin of a voltage source or an ammeter Direct Plot plots the source's branch
    current when the pin's terminal is not in the results, or is refused a name. On the
    source's first pin it says nothing more. On its second pin the trace is the negative of
    that pin's own current, and the click says so in one sentence. On a pin that is neither
    it is decision 50.

Added after the second review:

36. On a point that a source's pin shares with another device's pin, a Direct Plot click
    that takes the source's current names the other pins and says it took the source's.
37. A Direct Plot ellipse, like a Direct Plot net colour, keeps its colour until the
    highlights are cleared. After a run whose plot replaces the viewer's traces it therefore
    shows the colour of a trace that is gone, or that another signal now has.

Added by the fourth repair:

50. The sentence about the sign is said only on a source's second pin. On any further pin
    (a controlling pin of a controlled source, a pin the netlist line does not carry) the
    click says that the trace is the source's own current and is not the current into that
    pin, with nothing about a sign; the Calculator says the same of the current it
    inserted. The reason: the source's current is the negative of the current into its
    second node only, and into a controlling node the current is zero, so the sentence
    said there before was false.

The deck:

13. A simulator without the probe extension still gets the `.probe` card and the run goes
    ahead. Where ASE-L has measured that the program about to start cannot save a terminal
    the deck asks for, it says so before the run starts, with which registered simulator
    can and where to pick it, and says it again in the report after the run; where it has
    not measured the program, the report after the run says it from the run's own log.
    The alternative, which the user may prefer: REFUSE such a run before it starts, as a
    run that requests `distinguish` on a simulator that folds is refused. It was not built:
    the run's other analyses and outputs are the user's too, the terminal is named twice,
    and a run nobody can start on the simulator they have is a harder stop than a missing
    current.
14. A terminal row is not checked before the run (`ase::preflight_gate` does not see it), so
    a mistyped one is reported only after it.
15. A Measures row, and an enabled measurement row, that reads a terminal is probed whether
    or not a box is ticked.
16. A Save-ticked terminal row brings `.save all` into the deck, as any other Save-ticked row
    does.

Added after the second review:

38. The note that a run did not converge with probes in its deck is said only when the log
    holds `timestep too small`, `DC solution failed`, `no convergence` or `operating point
    could not be simulated` (the last since the fourth repair: decision 55). A `singular
    matrix` warning alone does not bring it, so a run the user stopped is not told it did
    not converge.
39. A run that made only noise, transfer-function, pole-zero or sensitivity analyses, with
    or without dc sweeps of a design variable beside them, says one note naming the terminal
    rows that have no value for that reason, and which analyses to enable. Beside a sweep,
    a terminal that only rows reading the sweep by its qualifier (`is(r1:n1)`) ask for is
    left to the sweep's own advice and is not named a second time.
40. A typed row whose name holds `;`, `$`, `=`, `'` or a brace is not a terminal row. No
    `.probe` card is written for it, and with Save ticked the pre-flight refuses it by name
    before the run.
41. A term the netlist's own `.probe` card already holds is not written a second time. Case
    is ignored only when the run folds case; under `preserve` and `distinguish` the netlist's
    term counts only when it is spelled as ASE-L spells it.

Added by the third repair:

48. An expression row that reads a name holding `=`, `'` or a brace gets no `.save` card
    for that read, so the run goes ahead and the row's Value says the name is unknown.
    Before, such a row stopped the simulator for the whole bench. A Save-ticked plain row
    of such a name is still refused by name before the run.

Added by the fourth repair:

55. The convergence note is also said when the log holds `operating point could not be
    simulated`, and it is not said for `iteration limit reached`. The reason: the first
    is what a failed operating point always prints, and with the Convergence form's
    transient-op rung switched off it is the only line of the key in the log of an ac,
    tran, dc-sweep, noise, pz or sens bench, which was therefore told nothing; the second
    is also printed in a warning by a pole-zero search that gives up while the run goes
    on, so it would bring the note back for a run that failed for another reason.

Added by the message pass (2026-11-20):

56. On a simulator that answers 0 to the probe question, the terminals it cannot save are
    reported in ONE line that names the program and gives the cure, in place of the
    simulator's own refusal of each ("Could not find the instance line …") and of the note
    about the build. The simulator's words are still in the run's log.
57. The cure names the registered simulators that were MEASURED able and no other: an entry
    whose answer is not known is never recommended and never ruled out, and a program that
    says it has the probes but produced no results on the capability probe's own small
    circuit counts as not known. With none able and an entry nobody has asked yet, it
    names those entries as not tried yet and says what finds out (the next run, or
    Detect); only when no entry is left that it can ask and has not does it say to
    register a build that does, or to place an ammeter.
58. To give the cure for a run, ASE-L may start registered simulators it has no answer
    about, each on the capability probe's small decks: at most five seconds in all for one
    call, and never at a click (a pick and Direct Plot read only what is already known).
59. At a pick the sentence about the simulator is said only when ASE-L already knows the
    program this session starts cannot -- that is, after a run or after Detect in the
    Simulators window. Before that the pick says nothing about it, and the run does.
60. Direct Plot's refusal says why the results do not hold the terminal where the last
    run's report gave a reason, and for a row that is already set says to run again; it
    tells the user to pick the pin under Outputs only when nothing else is known.
61. The line that says a run is starting on a simulator that cannot save a terminal ends
    "This run goes on without that current." -- not "without it", which after "pick it
    under Setup > Simulators…" would read as the simulator.

Added by the repair pass (2026-11-20), after three verifiers drove the message pass:

62. **A run on a simulator measured unable asks the registered entries even when its own
    deck holds no terminal below the top level** (decision 58's asking, at the same place
    and under the same bound). A click starts nothing, so without this the first pin
    picked after such a run could only be told its entries have not been tried. It is the
    one place a run starts a registered program the user's own outputs did not call for:
    once for each program (measured 2026-11-20 on the user's four entries: about 0.2 s in
    all), and up to the bound's five seconds, once, where a registered program never
    answers. The alternative
    is to leave the click saying "not tried yet" until a run that does ask.
63. An entry nobody has asked is called "not tried yet", with what finds out, and is not
    a reason to register another build (decision 57 as amended).
64. What the cure knows about which program can is kept over an edit of the registry. The
    edit still empties the capability store, so what a run reads is measured afresh; only
    the names in these sentences survive it, under the program file's stamp. A program
    held to be slow is forgotten by the edit and asked again. A click reads what was
    carried about its own session's program as well: after an edit the pick still says
    that program cannot, and Direct Plot still ends with it, although the store holds
    nothing about it until the next run.
65. A click speaks about its OWN session's simulator -- what a run of that session would
    start -- whatever another session's run left in force in the process, and it leaves
    what is in force alone.
66. Direct Plot does not tell the user to pick what is picked: where the entry the
    session starts now is already known able, the sentence about the last run's simulator
    ends "<entry> is picked now — run again."
67. Direct Plot does not send a row that is set to be saved into a run that cannot save
    it: for a terminal below the top level, when the session's simulator is already known
    unable, the sentence ends with that and the cure in place of "run again". In a session
    with no results the sentence says so ("this session has no results yet — run.").

Added by the round after the repair pass (2026-11-20). What the repair pass had left for
a ruling was ruled by the lead that day to stand as built: decision 57 as amended and 63
("None of the simulators you have registered is known to" only when no entry is left
that the cure can ask and has not), decision 62 (a run on a simulator measured unable asks the untried registered
entries once, under the bound), decision 64 (with the click reading what an edit
carried), and the sentence of decision 69. Each is built, and each is the user's to
overturn here.

68. The sentence about an entry that has not been tried yet says the way to Detect step
    by step: "select it under Setup > Simulators…, press Edit… and then Detect." (several
    entries: "select each"). The Simulators window lists the entries and has no Detect
    button; Detect is in the row editor that window's `Edit…` button opens for the entry
    selected in its list. Until this round the sentence sent the user to Setup >
    Simulators… to press Detect there, a button the window that entry opens does not
    show.
69. A run that was stopped after its checkpointed analysis had been written is told that
    the plot was written, at how many points, and which analysis did not finish
    (`ase::ckpt_report`), where it used to be told the plot was still filling. The
    sentence, its measurement and the one case it does not tell apart are in issue
    1657's file, whose repair built it; it is numbered here because it is wording of the
    same passes that the user has not ruled on.

The marker:

17. The three flavours that write rows mark on layer 16, and their ellipses go when the mode
    ends, however it ends, in every window and tab. So a pin picked under To Be Plotted or
    From Design… has a light-green ellipse like a saved one, and its waveform, plotted after
    the run, has the viewer's next colour. Only Direct Plot's ellipse has its trace's colour
    (18).
18. Direct Plot's ellipse has the trace's colour and stays past ESC, as Direct Plot's net and
    source colours do, until the highlights are cleared.
19. Key `0` clears the ellipses, of both kinds, of the window it is pressed in and of the
    windows and tabs linked to that one by a descend, also while the mode is up. A window
    showing another document keeps its own. In the middle of a gesture it is decision 49.
20. Under the stock light colour scheme layer 16 is a mid green (`#7ccc40`), not a light one.
    The dark scheme, which the user's launch profile runs, has the light green (`#bfff81`).
    The marker takes the layer's colour in both.
21. `xschem reload` keeps the ellipses: it is the same document.
22. In Direct Plot a pin clicked again gets its ellipse back after key `0`, in the colour its
    queued trace has, while a net clicked again gets no colour back.

Added by the third repair:

49. Key `0` pressed while the window is in the middle of a gesture (a wire being drawn)
    clears that window only. The windows linked to it keep their ellipses and their net
    colours until the key is pressed again after the gesture.

The Signal Browser:

23. A terminal current is labelled by its terminal under its device's node (`in_p:i`,
    `d:i`), not by the device.
24. "Descend to here" on a device's node goes to the device's parent sheet and selects the
    device there.

The Calculator:

25. The Calculator inserts the name as the result's reader stores it, with a dot
    (`it(x1.xm1.d)`). Pasted into an ASE-L Outputs row that text is not a terminal row and
    gets no `.probe` card (`ase::probe_split` answers nothing for it).
26. On the pin of a voltage source or an ammeter the Calculator inserts the source's own
    current when the pin's is not in the result, or the pin is refused a name. On the
    source's first pin it says nothing more. On its second pin the inserted current is the
    negative of that pin's own, and the click says so (`… inserted the source's current, the
    negative of this pin's`). On a pin that is neither it is decision 50 (`… inserted the
    source's current, which is not this pin's`).
27. The Calculator's sentences are the short ones that fit its status line: `ASE-L Outputs:
    To Be Plotted, rerun` for the place to ask for a current, `use an ammeter in series` for
    a refusal. The first names To Be Plotted and not To Be Saved, because the Calculator sees
    a new run only once the viewer has loaded it, and a finished run loads the viewer only
    when it plots a row. The pin's row then has Plot ticked, so every later run plots it.

Added after the second review:

42. With a current selector armed, the Calculator's prompt on the design window names the
    pin under the pointer (`… ESC cancels — pin R9:P`).
43. With a Calculator pick armed, both presses of a double click are the pick's, so a miss is
    answered twice. In the Results Display Window's pick mode the second press is swallowed:
    one double click is one dump.
44. Where a source's pin shares its point with other device pins and the source's current
    is inserted, the Calculator names those pins and says the click took the source's
    current.

## What the measurements corrected

**In this file as first filed:**

- *"sky130 FETs: the drain only"* and *"a subcircuit instance has no terminal-current vector"*
  hold for `.options savecurrents` and `@dev[param]`. With a probe, every terminal of a wrapped
  FET and every port of a block has a vector.
- `op_annot::devpath` cannot name the instance: its descriptors exist only for the nmos and
  pmos of two PDKs. `@spiceprefix@name` is not the deck's element for every symbol either
  (sky130 `res_generic_*` netlist as `R14 …`).
- *"A two-terminal device's single current, negated on its second pin"*: each pin has its own
  vector. Nothing is negated.
- *"Which tab"*: `ase::output_is_save` already admitted `i(x1.xm1:d)` to Saves. What stopped it
  was the deck: a `.save i(x1.xm1:d)` card, and `ase::preflight_gate` refusing the run.

**In the brief** `doc/claude/ngspice_terminal_current_probes.md`. The exact cards and vectors
are in its section "Measured from the xschem side, 2026-11-19"; in short:

- The vector's `<tname>` is not always accepted back as a card pin (`n<k>`, `b_tj` inside a
  subcircuit), so the card is built from the row, not copied from it (`ase::probe_card`).
- A PDK wrapper's port names are not the symbol's pin names, and the netlist position is not
  the pin index plus one, so the pick reads the instance's own netlist line and the callee's
  `.subckt` header.
- A word of digits in a card is a position, also where a port has that number as its name, so
  no card can ask for a numbered port by name.
- Refusals come in two shapes, spell the card and not the row, and are not all on stdout; an
  older build only warns and the run continues.
- Three cards stop the run on every build (a top-level `E` on a short card, pins 3 and 4 of a
  top-level expression `E`, a `K`); ASE-L withholds them.
- A top-level device that is not a subcircuit instance is mis-named under `preserve` and
  `distinguish` when the card spells it in upper case; ASE-L lower-cases it, and withholds the
  card under `distinguish`.
- A probed vector is in the op, dc, ac, tran, disto and sp plots and in none of the noise, tf,
  pz and sens plots, nor in a design-variable dc sweep's.
- Inside xschem the vector is stored with a dot, which is why the lookup rung exists.
- A `;` is not the only character that harms a card: a `$` opening the pin cuts it too, and
  an `=`, a `'` or an opening brace stop the simulator.
- The same term twice in a deck makes a top-level device's vector twice; only inside a
  subcircuit is it taken once.
- A voltage source's `i(v1)` is the current into its first terminal: it equals `i(v1:n1)`
  and is the negative of `i(v1:n2)`.
- The simulator prints `singular matrix` on the way to a solution too, so that line alone
  does not say a run failed to converge.

**In the first build, by its review** (each measured on real sheets or a real run, then
repaired):

- The 10-unit bound took every click on a short wire between two device pins; the wire rule
  gives the wire back.
- Of two devices abutting on one point only the lower instance index could be picked; the
  side of the point now chooses.
- Direct Plot on a source's lead printed the "not in this session's results" sentence where it
  used to plot; the source's current stands in.
- Before the first netlist, and after every sheet edit, a subcircuit whose header was only in
  the netlist's own `.lib` lines or in a `device_model` was named by the symbol's pin; both are
  read now.
- A subcircuit port named with a number went into the card as a name and was read as a
  position; the card carries the position.
- A Measures row or a measurement over a terminal with no box ticked got no probe and no
  Value; both are asked now.
- A terminal-only save list on a bench with an ammeter kept no node voltage; the leader is
  back.
- A run that stopped converging because of a probe said nothing about the probes; the note
  does.
- The Signal Browser showed two pins of one block under one label; the label is the terminal.

**In the repaired build, by its second review** (each measured, then repaired or declared):

- **A wire click a pixel off the wire took the terminal.** Where a net label's box or the
  device's own box lies over a wire, the editor's hit test names the box for a cursor a
  fraction of a unit off the wire, and the wire rule, which trusted the hit test, did not
  fire. Measured 2026-11-19 with real pointer motion on scratch copies of the shipped
  `sky130_tests_ase` sheets at their fit view, over wire points near a device pin that
  queue a voltage at HEAD (the counts are in the review's scratch, not here: no row
  re-checks them). With the first wire test alone a share of those points became a
  terminal, at the nearest pixel and one pixel to either side. With the second wire test
  (`ase::ui::sod_wire_near`) a handful were left, all on sheets whose fit view is so far
  out that the pixel's centre or the wire's nearest point is inside the pin's own square.
  No device pin lost every pixel, and the points up a device's lead that were the terminal
  still are.
- **Two blocks abutting on facing edges** could only be picked by the lower instance index:
  with every pin on one edge the middle of the pins is on that edge and gives no side. The
  box was made to decide the tie. (That cured blocks with equal pin sets only; the third
  review's item below has what the box decides now.)
- **Zoomed far in, part of the pin's own square was not the pin.** The on-screen radius is
  then smaller than the square. The square's rectangle now counts, in the editor's click as
  well.
- **Two different headers for one callee** were reported as "no header is known", with a
  remedy that could not help. The sentence now says several differ, where, and to leave one.
- **The remedy named a place the UI does not have** ("the session's Models"). It names
  Setup > Model Files.
- **A click in another design's tab** queued that design's net, source or pin into the
  session and drew an ellipse there. It is refused.
- **The Calculator's own sentence led into a dead canvas.** A miss leaves the selector
  armed and sent the user to Select On Design; the two modes then held the same canvas slots
  with one predecessor each, and ending them out of order left a schematic window that took
  no left click (issue 0202 has the sequences). The two modes now end each other.
- **That sentence's advice did not complete.** After a To Be Saved pick and a rerun the
  same click still said "not in this result", because the Calculator reads the viewer's
  loaded database and a run with no Plot-ticked row does not reload it. The sentence names
  To Be Plotted.
- **On a source's second pin the stand-in has the opposite sign of the pin's own current**,
  and nothing said so: the same click gave one sign before the pin was probed and the other
  after. The stand-in stays; both the mode and the Calculator say the sign.
- **On a point a source shares with a probed device pin**, Direct Plot on the source's side
  plotted the source without a word about the other pin. It names it.
- **Closing the window the mode was on** left the ellipses in the other window with no ESC
  that could remove them. The mode ends.
- **Key `0` cleared net colours in both linked windows and ellipses only in the focused
  one.** It clears both in both.
- **The second press of a double click went to the editor**: a property dialog, modal on an
  empty sheet, and the object selected. Both presses are the mode's.
- **The convergence note was said for a healthy run the user stopped**, because the
  simulator's `singular matrix` warning was read as a failure.
- **A bench with only noise, tf, pz or sens analyses** left a terminal row blank with no
  sentence anywhere.
- **A `$`, `=`, `'` or brace in a typed terminal name** cut the card or stopped the run.
- **A netlist that already carried the `.probe` card** got the same term a second time, and
  the vector twice.
- **Not changed, declared instead:** a To Be Plotted waveform does not have its ellipse's
  colour (decision 17); a Direct Plot ellipse can outlive its trace's colour (decision 37);
  a net label's box near a device pin is the terminal's (decision 28); a block port and a
  same-named source inside the block get one label in the Signal Browser (Limits).

**In the twice-repaired build, by what its second repair measured and handed back** (each
built in the third repair, 2026-11-19; the probes are in the review's scratch):

- **A pick whose hand drifted with the button down** cleared a selection made before the
  mode and left the editor's selection rectangle up past the mode's own ESC: the mode did
  not hold the pointer motion with the button held. It holds it now.
- **A press after the canvas had been laid out again was resolved at a point nobody
  clicked.** The engine takes the position of every event it is sent, and the canvas's own
  `<Configure>` carries the canvas's place in its window. Measured: after a real motion
  onto a pin and a `<Configure>` delivered to the canvas, generated or from a real resize
  of the window, the engine's pointer was far from the pin, and a press there queued
  nothing and said nothing. The three click modes now hand the press's own position to the
  engine before the click is resolved.
- **Issue 1659's chain was wrong in one step.** It says the `<Configure>` script is bound
  on a toplevel and so fires for every widget below it. Measured on this tree: it is bound
  on the design canvas only, and a `<Configure>` on a status-bar label leaves the engine's
  pointer alone. Issue 1659 has the dated note.
- **A window made while the mode was up took the mode's scripts** and, once the mode had
  ended, no left click. A new window now gets what the canvas holds underneath the modes.
- **The mode could not be entered with the design in a tab other than the first.** This
  file had it down as not measured. Measured, both the menu path and Ctrl-4 refused. The
  tabbed interface is the default.
- **Key `0` in the middle of a gesture** emptied the linked window's marker list and left
  its ellipse on its screen. The linked windows are left alone during a gesture.
- **A dc sweep of a design variable beside a noise, tf, pz or sens analysis** left a
  terminal row with no value and no sentence. The note is said there too.
- **An expression row reading a name with an equals sign, a single quote or an opening
  brace** stopped the simulator for the whole bench through its `.save` read card. No such
  card is written.
- **A pin whose instance or port name the deck cannot carry** was queued and marked, and
  its row was then no terminal row. This file had that as read from the code; driven, such
  names do reach the pick. The click refuses them.
- **A canvas left on a mode's dead scripts could not always be freed from inside the
  session.** The Results Display Window's seize kept its own scripts as the previous
  bindings, and Select On Design's recovery lost the editor's double click. Both seizes now
  refuse their own scripts and fall back to the editor's double click (issue 0202 has the
  sequences measured again).

**In the three-times-repaired build, by its third review** (2026-11-19; five reviewers,
each finding re-measured by a second agent; no blocker; each item built in the fourth
repair or declared; the probes are in the review's scratch):

- **Two abutting blocks with different numbers of pins.** The box was asked only when the
  two pin measures were equal. With unequal pin sets they differ, so the block taken was
  decided by which side of the lead's axis the pointer was on: real presses on one block's
  lead took the other block's pin at two of three shared pins. And the box that was used
  held the symbol's texts, so a title reaching over the neighbour moved it. Now a device
  whose pins say nothing about its side puts every device on that point to the box, and
  the box is the symbol's without its texts. On the reviewers' grids and with real
  presses every such point takes the block it is in; a block's pin against a FET's drain,
  wrong on the block's whole lead before, is right on that lead now (Limits, "The pick",
  has what is left).
- **The sign sentence was false on a third or fourth pin of a source.** On the controlling
  pins of the stock `vsource_pwl.sym` Direct Plot said the current into the pin is the
  negative of the trace; it is zero. The Calculator said the same. The sentence is now
  said on the second pin only, and a pin that is neither has a sentence of its own.
- **The prompt named a pin of a window the mode was not on.** With the mode on one window
  of the design and the pointer on a pin in another (the sheet above a block opened in
  its own window, or the other way round), the prompt named that pin although a click
  there is the editor's. It names a pin only in the window the mode is on.
- **A third mode entered over the Results Display Window's mode stranded that mode.** With
  that mode on top of Select On Design or of a Calculator pick, starting the other of the
  two ended the mode underneath and left the Results window's mode recorded as up with
  nothing bound: its sentence on the status bar, clicks selecting, its key doing nothing.
  The second repair had made this reachable by a selector press or a menu entry. That mode
  now takes the canvas again and the three orders unwind with one ESC per mode.
- **A stack with the Results Display Window's mode on top did not survive a descend.** The
  modes were released in the order they were registered, the lower one first. After a
  descend in the same window, into a new tab or into a new window the canvas was left on
  the lower mode's scripts and, once both modes had been ended, took no left click (after
  a descend into a new window: neither window did, and the two modes had come back upside
  down); the descend's own pick (`E` with nothing selected) never got its click. This is
  older than this work. The top is now released first.
- **A Calculator pick and the Results Display Window's mode did not follow a return to a
  parent in a tab**, and that mode's keys did nothing in a tab other than the first
  (issue 1387's tab half): both read the name of a tab as if it were a widget. The third
  repair had cured this for Select On Design only.
- **Closing the window Direct Plot was on threw the queue away without saying so**, and
  left the colours of traces that were never made. The sentence now says how many traces
  were not plotted and how their colours go.
- **A failed operating point with the transient-op rung switched off got no convergence
  note** on an ac, tran, dc-sweep, noise, pz or sens bench: none of the three phrases of
  the key is in such a log. The simulator's last line for a failed operating point is in
  the key now.
- **The pick suite stopped on a display.** The fixture instance `R=B[1:0]`, added after
  the third repair, makes the engine raise a modal box the first time one of its pins is
  named, and nobody answered it. The suite stands a recorder in for that box and now runs
  on both arms. The engine raises the same box at every netlist of such a sheet; that is
  its own notice and was left alone.
- **`test_rdw_keys_1245` stalled on a display with no window manager**: it deleted its
  recorder of `ciw_echo` without putting the product's proc back, and two of its rows need
  a window manager. Both are repaired in the suite.
- **Not changed, declared instead:** with the design in a tab other than the first and a
  second real window on the screen, the main window can end with the first tab in front
  (Limits, "The mode"; the engine's, issue 1713).

**In the four-times-repaired build, by the verifiers of its fourth repair** (2026-11-19;
four verifiers, one for each of that repair's four code packages, each running the
reviewers' own reproductions again; each answered that its package holds and listed what
was left; each item built in the closing pass or declared; their scripts and logs are in
that repair's scratch):

- **A symbol that uses one pin name twice was read as having every pin on one edge.**
  The edge test places a symbol's pins by name, and for a name used twice the engine
  answers the first pin of that name. On the shipped `examples/test_doublepin.sch`
  (`xcross.sym`, pins on two edges) shared points were therefore read as edge-on that
  are not, and the device taken changed at points off the leads, against the tree before
  the fourth repair. This was a regression of that repair, and unlike its change at
  exact ties it had not been declared. Such a symbol now makes no claim
  (`ase::ui::sod_term_edge_on` answers 0), and on that sheet every junction answers as
  it did before the fourth repair (Limits, "The pick").
- **The fourth repair's statement about the shipped sheets left one sheet out.** Its
  sweep ran without the sky130 libraries and listed pins by name. With both put right, a
  shipped sheet shows a change at points on a lead: sky130 `test_carry_lookahead`, where
  a one-pin capacitor sits on a block's pin. A point on the capacitor's own lead now
  takes the capacitor, where it took the block. That is the rule doing what it was built
  for, but this file's sentence that no point on a lead had changed was too wide. It is
  corrected under Limits.
- **The Calculator's own doors, and the session window's close, stranded the Results
  Display Window's mode.** With that mode on top of an armed pick, the armed selector
  pressed again, another selector pressed or the Calculator window closed ended the pick
  underneath and left that mode recorded as up with nothing bound; closing the ASE-L
  session window did the same with Select On Design underneath. All four are older than
  the fourth repair, which had cured the same defect behind three other doors. Each door
  now asks that mode to take the canvas again.
- **In a tab other than the first the keyboard stayed in the Results Display Window
  after a dump** made in its pick mode, a state the fourth repair had made reachable by
  letting the keys arm the mode in such a tab. It goes back to the schematic now.
- **A `tf`-only bench whose operating point fails does not always end at exit 0.** This
  file said it does, on both binaries. Measured on three benches: one does; the other two
  abort in the `tf` solve at a nonzero exit, and those do get the convergence note. The
  limit is reworded.
- **`iteration limit reached` stands under a failed operating point only when the
  transient-op rung was not tried.** A comment and two sentences said it without that
  condition; with the rung tried the line is `Timestep too small`.
- **`bind` on a tab's name raises.** The header of `calc::pick_canvas` said it creates
  bindings for a widget that does not exist. Measured in a real second tab: it raises
  `bad window path name`, and a caller that catches the raise binds nothing, which is
  why a mode looked armed and was not. The comment says that now.
- **The note on the release order said a mode whose place cannot be read goes in
  registration order.** It can go ahead of an earlier-registered mode that is waiting
  for the mode over it. The comments in `src/cmdmode.tcl` say what the proc does; no
  code changed there.
- **Parts of the fourth repair had no row that would go red without them:** the flip and
  the rotation of the box's middle; "any device on the point is edge-on" against "the
  first one"; two conditions under which `rdw::pick_reseat` does nothing; the release
  order with real modes on a display, beyond one stack on one road; the hand-kept copy
  of the convergence key's other phrases in the deck suite. Each has a row or a leg now
  ("What was built", Fences), and each of these five was shown red against the code with
  that part taken out. Three smaller legs of the closing pass were not (Limits).
- **`test_rdw_keys_1245` went red on a display whose window manager had died**, because
  the root window still names a manager that is gone. The suite now takes such a record
  as no manager.
- **Not changed, declared instead:** exactly beside a shared point with no edge-on device
  on it, the lowest instance index is taken (Limits, "The pick"); a `tf`-only bench whose
  operating point fails without aborting gets no convergence note (Limits, "The deck and
  the results"); a selector the result cannot serve, pressed while another is armed,
  stays lit with no pick running (Limits, "The mode").
- **Found on the way, not this work's, each filed or noted where it belongs:**
  `xschem new_schematic destroy_all` leaves a real window's toplevel standing while the
  tabbed interface is on (issue 1726, new); `test_wave_markers` also times out on a
  private display (a dated note in issue 1488); a scratch path with a capital letter
  reddens `test_ase_saved_results_1705` and `test_ase_variant_1470` and puts the first
  one's fixture files in a lower-cased sibling directory (a dated note in issue 1334).

**In the build after the closing pass, by that pass's two verifiers** (2026-11-19; one
for the pick, one for the life of the modes; both answered that the closing pass holds,
with no regression, and listed what was left; the lead ruled on that list and a last
build built the items ruled in; the verifiers' and that build's scripts and logs are in
their scratch):

- **The Results Display Window's mode ended first stranded the mode on top of it.** With
  Select On Design or a Calculator pick entered over that mode, Escape pressed in the
  Results window ended its mode from underneath and wrote the editor's scripts over the
  upper mode's live ones. The upper mode stayed recorded as up with nothing bound, its
  prompt on the bar, through four ESC on the schematic; ended later, it handed the
  Results window's dead scripts back to the canvas. This is older than this work; the
  closing pass had named it as the one order left and given three recoveries for it.
  The end of that mode now asks the mode on top to take the canvas again, and the
  recoveries are no longer needed for this. Measured by the last build with real
  presses and real ESC, one process an order: the two orders that were not free end
  free after one ESC, in the first tab and in a second one, and every order the
  earlier verifiers had driven still ends with no mode recorded, the canvas as the
  editor has it and a click selecting. Run again from a copy for this file, on the
  tree as it stands: the same for the two orders.
- **With two modes stacked the status bar changed text on every tick.** Each mode
  re-asserts its sentence on the same slot with its own timer. Sampled with no event
  sent, the slot held two sentences in turn in every stack of two; one mode alone
  holds one. It is older than this work (issue 1387 names the two writers). Now a
  mode writes only while no other mode that is up is seized over it: sampled the same
  way the slot holds one sentence, the top mode's, and the lower mode's is the only
  one after the top mode's ESC. A selector armed over the Results window's mode shows
  a blank for an instant before its prompt, as a selector armed alone does.
- **A pin name that ends in a backslash made the same-point rule raise.** For such a
  symbol `xschem pinlist <n> name` answers text that is no list, both measures used to
  ask it for the names, and a click on a point the symbol shares with another device
  queued nothing and said `ase: the pin test of this click failed …`. Older than the
  closing pass, and met on a shipped symbol (`gschem_import/sym/MC10E104-1.sym`).
  The last build read the names from the pins' attribute strings (the build after it
  asks the engine's list of names first: the block below). That alone did not cure
  it: `xschem instance_pin_coord` answers the name in front of the point in the same
  way, so the point is read off the end of its answer as text. The ruling was to take
  the names from `ase::ui::sod_term_pins`; that proc also expands each name as a bus,
  and for a name the engine cannot expand it raises a message box that waits, which
  the prompt would then meet at every hover, so a reader that expands nothing was
  written instead (measured on a display: one box against none).
- **"Any device on the point is edge-on" was not told from "the LAST one".** The
  closing pass's row told it from "the first one" only: in every fixture the edge-on
  device was the last on the sheet, or both were. Row TPR4v has the leg now.
- **Two sentences of this file were wider than the code.** A symbol that repeats a pin
  name is NOT always decided by the pin measure: with an edge-on device on the point,
  every device there is measured by its box. And more than one shipped sheet has
  points shared with an edge-on device: the verifier swept the shipped sheets this
  file called unswept. Both are corrected under Limits.
- **The first tab can also come to the front on a press of a Calculator selector**
  (the engine's, issue 1713); this file named only the session's menu and the pointer.
  Nothing wrong is inserted: the click there cancels the pick.
- **Two comments were not exact**: the header of `rdw::pick_reseat` on when
  `ase::ui::select_on_design` calls it (after its Calculator line, whether or not a
  pick was ended there), and the header of `ase::probe_report` on `iteration limit
  reached`, which a `tf`-only bench whose `tf` solve aborts does not print. Both are
  reworded; no code line of `src/ase.tcl` moved.
- **Not changed, declared instead:** after a mode has taken the canvas again the
  keyboard is on the schematic (Limits, "The mode", and open item 5); a selector the
  result cannot serve stays lit; three small clauses of the click modes, and two legs
  of a pin's place on its netlist line, have no row that goes red without them
  (Limits).
- **Found on the way by the last build, not built:** a block whose port name ends in
  a backslash is refused at the click with a sentence that shows a blank for the
  backslash (Limits, "The pick"); while the Results window's mode is under another
  mode its tooltip on the status slot still holds its own sentence (Limits, "The
  mode"); and the two engine verbs that do not answer a list for such a name (open
  item 15).

**In the last build, by its verifier** (2026-11-19; it answered that the build holds,
with no regression, and listed three things left; the lead ruled two of them in and one
more build built them; the verifier's and that build's scripts and logs are in their
scratch):

- **A mode ended while a descend had it paused wrote on the canvas a second time.**
  The descend command given with nothing selected pauses the click modes and waits for
  a click on an instance. With the Results window's mode entered over Select On Design
  or over a Calculator pick, Escape pressed in the Results window during that wait
  ended its mode, and the end wrote back what that mode had on record as the canvas's
  own: the scripts of the mode underneath, which was paused. The click on the instance
  was then that mode's and nothing descended; ESC on the schematic and a second click
  completed the descend. Older than the last build. The other two modes had the same
  shape and were read, not driven, by the verifier: Select On Design ended while paused
  (the session window closed, the mode entered again, a Calculator selector pressed)
  and a Calculator pick ended while paused (its selector pressed again, the Calculator
  window closed), each over the Results window's mode. Now the release of a paused mode
  writes nothing, in all three modes. Measured with each release's test taken out
  again in memory: the canvas is back on the paused mode's scripts in every one of
  those orders; with it in, the canvas keeps the editor's bindings, the first click on
  the instance descends, the mode that is left comes up alone where the descend lands,
  and one ESC ends it. With the ended mode UNDER the other one its record is the
  editor's own, and writing it again changed no binding; there the only difference is
  that the status slot is no longer blanked for an instant.
- **The name reader of the last build could not read a symbol with plain pin names and
  another pin attribute that ends in a backslash.** It read every name off the pin's
  attribute string, and for such a symbol the engine's list of those strings is no
  list. The same-point rule then took the symbol's pins for unreadable and measured
  every device on a point it shares by its box, where before the last build its pins
  had said its side. No changed pick was found, and no shipped symbol of that shape.
  The reader now asks the engine's list of names first and the attribute strings only
  when that is no list, so such a symbol is read by its names again and a symbol whose
  NAMES end in a backslash is read as the last build made it (rows TPR4x and TPR4w).
  The sheets the verifier swept pixel by pixel give the same pick at every point as
  before this change.
- **Not changed, declared instead:** a click on a pin of that symbol is still refused
  with `… its pins could not be read`, because the click names a terminal through
  `ase::ui::sod_term_pins`, which reads the attribute strings (it needs each pin's
  `spice_ignore` as well); the block port that ends in a backslash, the tooltip of the
  status slot under a stack and the clauses with no row that goes red without them
  stay as the block above says. One clause of the new reader joins those: its test that
  every row of the engine's name answer is a list of two words has no row that goes red
  without it, and no engine answer was found that it tells apart (a pin name holding a
  close brace raises with the test or without it).
- **The suspend arm of Select On Design answers 0 for a mode that is already paused**
  (`ase::ui::sod_suspend`), as the arms of the two other click modes do. Before, it
  answered 1 a second time; the command-mode registry never asks it twice, so nothing a
  user does reaches the difference. Row TPL15 holds the answer.
- **Found on the way, not this work's:** `tests/headless/test_t1_display_arm.tcl` leaves
  an `untitled~.sch` backup at the repository root (the verifier's finding; the file is
  gitignored and was removed).

**In the build as the user ran it** (2026-11-20; her own bench `sky130_tests_ase/tb_bandgap`,
state `ngspice_state1`, four simulators registered and none picked):

- **What she picked and what started.** The pin `diffout` of `x1.x1`, a subcircuit instance
  inside `x1`, under Outputs > To Be Saved > Select On Design. With no simulator picked the
  program named `ngspice` on the PATH started: apt 45.2, which has no probe extension.
- **What she was told.** After the run: the simulator's own refusal, `Could not find the
  instance line for x1.x1`, which reads like a mistyped name, and the note `this simulator
  probes only top-level devices that are not subcircuit instances`, which named no program
  and no way out. In Direct Plot, three times: to pick the pin under Outputs > To Be Saved >
  Select On Design and run again, which is what she had done. And before the run, of that
  program: `… can do everything ASE-L offers except case-sensitive net names and the fast
  operating-point dump`, when it also cannot do this. She found the cure herself, by
  registering a fifth entry for a program one of her four already named.
- **Measured the same day**, one deck with a top-level MOS and resistor, a subcircuit
  instance and a device inside it, a `.probe` card for a pin of each and `echo
  $?probe_version`: apt 45.2, `ver_50` and `ver_52` answer 0, save the two top-level
  devices' currents and refuse the other two with `Could not find the instance line`;
  `ver_53` answers 1 and saves all four. So the sentence about top-level devices was right
  for every build without the flag, and the flag is what to ask a program before a run.
- **Corrected.** That question is now a capability key, measured by the probe; the sentence
  about a program names the gap; the report's line names the program that ran, says what it
  saves and which registered simulator can, in place of the refusal and the note; the same
  is said before a run and at a pick once the program is measured; and Direct Plot says why
  the results do not hold the terminal. On her registry the cure reads `ng_w_stb and ver_53
  can — pick one under Setup > Simulators… and run again.` Row PN15 is her run on two real
  programs: nothing picked, a build without the extension on the PATH, a device inside a
  subcircuit asked for, and the same bench again on the registered program that can.
- **Not this issue's:** the two `results cannot be matched to the row that asked for them`
  lines of that log are issue 1657.

## Limits

**The pick.**

- A header written in the netlist itself (not in a file the netlist names) is read only while
  that netlist is current.
- A numbered port of an instance below a subcircuit whose body is in a model file is not
  followed: bodies are walked in the netlist text only. Such a row gets the report's sentence
  that ends with the ammeter.
- Two pixels off a wire, inside a net label's box, a click within range of a device pin is
  still the terminal's when two pixels are more than 2.5 units.
- The second wire test reads every wire of the sheet. It runs only when a device pin is in
  range, the cursor is outside the pin's square and the first wire test has not already said
  yes. Its cost was measured 2026-11-19 without a display, on the shipped sheet with the
  most wires and on a much larger synthetic one (the figures are in the review's scratch:
  no row re-checks them); it grows with the number of wires. The prompt asks it again only
  when the pointer, the zoom or the sheet has changed.
- **A bus instance whose own name holds an equals sign** (`R=B[1:0]`) is named `R:n1` by
  the naming rule: one token, with the equals sign and the bus range gone (measured
  2026-11-19 beside a control `RB[1:0]`, two tokens and the dialog). The token test
  above therefore passes it. The click now also puts the instance's own name to the same
  words (`ase::ui::sod_term_odd_inst`; a comma, a colon and a bracket are bus syntax
  there and are not judged) and refuses: nothing is queued or marked, no dialog opens, and
  the sentence says the instance's name holds an equals sign. Row TPU6 of
  `test_ase_terminal_pick_1724`. Why the naming rule answers so, and what the netlister
  writes for such an instance, were not looked into.
- Of the characters the click refuses, an equals sign, a dollar sign and a single quote
  were put on a sheet (a port and three instance names). The others are fenced on the test
  proc alone.
- **Two devices on one point, what is left.** Measured 2026-11-19 on the third review's
  grids, before and after the fourth repair, and again by that repair's verifier on
  scratch copies of the shipped example sheets and sky130 ASE test benches, with the
  sky130 libraries registered and the pins listed by index, and by the closing pass's
  verifier on scratch copies of the other shipped sheets (the tables are in the
  repairs' scratch: no row re-checks their counts).
  - A block's pin against a FET's drain, and two resistors at a right angle: one point of
    each grid still takes the other device. The CIW names the pin taken and the other
    one; click further up the lead of the device meant.
  - **Exact ties.** Exactly beside a shared point, on neither device's lead, where the
    two devices' pins measure the same: the box without its texts now decides, and where
    the two boxes measure the same too, the lower instance index. On the shipped sheets,
    at shared points with no edge-on device on them, this changed which device is taken
    only at points exactly on an axis through the shared point, where the symbols' texts
    used to decide; there the lower instance index is taken now. Judged by which
    symbol's box such a point lies in, as many answers got worse as got better. At those
    shared points no point on a lead, or half a unit beside one, changed. This was
    declared by the fourth repair and is not changed. The CIW names the pin taken and
    the other one; for the other device, click on its lead.
  - **A shared point with an edge-on device on it** (a one-pin symbol, a block with every
    pin on one edge). There the fourth repair did change points on a lead, as it was
    meant to. Of the sheets first swept one has such points: sky130
    `test_carry_lookahead` (the ASE test bench, in `sky130_tests_ase`), where a one-pin
    capacitor sits on a block's pin. A point on
    the capacitor's own lead now takes the capacitor, where it took the block; around
    those junctions more answers got better than worse by box containment, and some did
    get worse. The other shipped sheets were swept afterwards, by the closing pass's
    verifier, and in `sky130_tests` the sheets `cla_2bits`, `cla_4bits`, `stdcells` and
    that library's own `test_carry_lookahead` have such points too, with no lead point
    lost or gained.
  - **A symbol that uses one pin name twice** (the shipped `examples/xcross.sym`). The
    edge test places pins by name (`xschem instance_pin_coord <n> name <name>`), and for
    a name used twice the engine answers the first pin of that name, so such a symbol's
    pins cannot be placed. `ase::ui::sod_term_edge_on` answers 0 for it and its shared
    points are decided by the pin measure, unless another device on the point is edge-on
    (a one-pin symbol, a block with every pin on one edge): then every device there,
    this one included, is measured by its box, as since the fourth repair. On
    `examples/test_doublepin` every junction answers as it did before the fourth repair
    (the closing pass's
    sweep of that sheet; row TPR4u holds the same shape on two instances of the symbol).
    Two things follow. The pin measure itself (`ase::ui::sod_term_toward`) still aims at a
    middle built from the first pin of each name, as it always did. And a block that
    really has every pin on one edge AND repeats a pin name is measured by its pins,
    not by its box; one shipped symbol has that shape, the PCB connector
    `gschem_import/sym/31-71043-1.sym`. The
    lasting cure is an engine verb that gives a pin's coordinates by index (Open items).
  - **A pin name that ends in a backslash** (closed by the last build; the gschem import
    library has such symbols). A click on a point such a symbol shares with another
    device takes the device on whose side the cursor stands, as for any other pair:
    a two-pin device of that kind against a resistor by the pins (decision 5), a
    one-pin device by the boxes (decision 51). Held by row TPR4w on scratch symbols;
    probed on the shipped `gschem_import/sym/MC10E104-1.sym` with a resistor on one of
    its pins, without a display and at one zoom, by a scratch script only: the rule
    answers at every point probed and each click queues one terminal and names the
    other pin. That symbol also repeats a pin name, so the edge test makes no claim for
    it (the bullet above). Other symbols of that library were not driven.
  - **Plain pin names beside another pin attribute that ends in a backslash.** The
    same-point rule reads such a symbol by its names (row TPR4x, on a scratch symbol).
    A click on one of its own pins is still refused, with `ase: cannot name the terminal
    current of <inst> pin <pin> — its pins could not be read; place an ammeter
    (ammeter.sym) in series`: the click names the terminal through
    `ase::ui::sod_term_pins`, which reads the pins' attribute strings, and for such a
    symbol the engine's list of them is no list. No shipped symbol of that shape was
    found. The cure is the engine request of open item 15.
  - **A block whose PORT name ends in a backslash** is chosen by the same rule and then
    refused at the click, with nothing queued or marked. The sentence is the one for a
    name a terminal row cannot hold, and its remedy is right (rename the port, or place
    an ammeter in series), but it shows the row with a blank in place of the backslash
    and gives a blank as the character: `ase: nothing queued for xw pin A\ — its
    current would be the row 'i(xw:a 1)', and a terminal-current row cannot hold a
    blank; …`. The cause: `xschem expandlabel` answers the name and then a count,
    `A\ 1`; `ase::ui::sod_bits` reads that answer as a list, and as a list it is the
    one element `A 1`. Not built: taking the expansion off that answer as text, or
    naming the backslash among the characters of `ase::ui::sod_term_unwritable`.
    Measured by the last build on both arms, and run again from a copy for this file
    without a display; row TPR4w holds that the click is refused in one sentence and
    queues and marks nothing.
  - **A lopsided two-pin symbol** (the stock `led.sym`, whose drawing is more than 5
    units off the line of its pins) is read as edge-on, so every device on its point is
    measured by its box. On the LED junctions the verifier swept, every point on a lead
    took the device whose lead it is on and none changed against the tree before the
    fourth repair; that sweep is not a suite row (row TPR4r holds only that the LED is
    read so).
  - The box's middle is worked out from `xschem instance_bbox` and `xschem
    instance_coord`, which print with six significant digits, as the pin coordinates
    already are. A sheet with coordinates of seven or more digits was not measured. The
    arithmetic is held against the engine's own box in all eight placements of a
    text-free symbol (row TPR4s); a read-only engine verb that prints the text-free
    instance box would replace it (Open items).
  - Not swept: any zoom other than the fit view, 1.0 and 0.6.
  - The leg for a pin position written with a leading zero (`n08`, row TPP13) holds the
    answer, not the way it is read: it stays green when the decimal read is replaced by
    a text comparison, because no digit string answers differently there, and goes red
    against an arithmetic read.
  - "Any device on the point is edge-on" is held against "the first one" and, since the
    last build, against "the last one" (row TPR4v: one pair whose one-pin capacitor
    stands later on the sheet than its resistor and one whose capacitor stands
    earlier). Two legs of a pin's place on its netlist line
    (`ase::ui::sod_term_line_pos`) still have no row that goes red without them: a pin
    the line carries more than once, and the element form with a prefix between two
    `#`. Both were left unbuilt by ruling.
- **Direct Plot on a source's pin: what the sentences rest on.** That the source's current
  is the current into node 1, the negative of node 2 and unrelated to nodes 3 and 4 was
  measured on the simulator by the third review, on a copy of `ver_53`; the rows are
  about the sheet and the sentence, not about a number. The first pin of
  `filesource.sym` stands behind a word that may not be a node, so its place is not
  known and a click on it now says the trace is not that pin's current, where it said
  nothing before. Whether a results file holds a current of that name for such an
  element at all was not measured. The third review could not simulate the stock
  `vsource_pwl.sym` on `ver_53` at all (`MIF-ERROR … Bad real value` for every spelling
  of its table that was tried), so the sign
  facts were measured on a hand-written four-node `E` element, and the Calculator's
  sentence for a pin that is neither, which needs a loaded result, is fenced on that
  symbol's geometry against a results file written by hand, not one a run made.

**The mode.**

- **The Results Display Window's pick mode still nests** under and over Select On Design and
  a Calculator pick (keys 1 to 4; ESC is its only exit). Ended last-entered first, the
  canvas ends free. This holds across a descend as well (same window, new tab, new window):
  the modes come up where the descend lands, stacked as they were, and after both are
  ended every window takes clicks. It also holds when the other of the two modes, or
  Select On Design again, is started while that mode sits on top: the mode underneath is
  ended, the Results window's mode takes the canvas again, and one ESC for each ends
  them. And since the last build it holds in the other order, which the closing pass
  had left: the Results window's mode ended FIRST, by Escape pressed in the Results
  window, while another mode sits on top of it. The mode on top takes the canvas again
  (`ase::ui::sod_reseat`, `calc::pick_reseat`), and one ESC on the schematic ends it and
  leaves the canvas free. No door of the product that was found leaves a canvas on a
  mode's dead scripts any more, and the three recoveries this file and issue 0202 gave
  for that state are not needed for it. (They still work: a canvas put into that state
  by hand is freed by entering the mode whose scripts were left and ending it with
  ESC; band PG26 holds that for the Results window's scripts.) What is left:
  - **The keyboard is on the schematic after the Results window's Escape.** Pressed in
    the Results window's text pane with Select On Design on top of its mode, Escape
    ends that mode, Select On Design takes the canvas again, and the keyboard goes to
    the canvas, where Select On Design's ESC is (row E6). With a Calculator pick on top
    it goes to the canvas too, from wherever it was (measured from the Calculator's
    buffer). The next key typed goes to the schematic; click in the Results window, or
    in the Calculator's buffer, to type there again. Whether the keyboard should stay
    where it was is the user's to rule on (Open items, item 5).
  - **The tooltip of the status slot.** While the Results window's mode is under another
    mode the slot shows the top mode's sentence, and the tooltip that mode arms on the
    slot still holds the Results window's own sentence: resting the pointer on the slot
    can show it over the top mode's text. Read off the slot's binding; no pointer was
    parked there. Left as it is by ruling.
  - **What was driven.** The real Escape of the Results window was pressed with Select
    On Design on top (row E6); with a Calculator pick on top the mode was ended by
    `rdw::pick_end`, the command that key runs (rows of band PG27), as it was in the
    order bench. The two orders were driven in the first tab and, with the tab put back
    in front after every step (issue 1713), in a second tab; the non-tabbed interface
    was not. Direct Plot on top of that mode, that mode ended first, was not driven
    with real events (row TPL13 holds by hand that a queue, its count and a pin's
    ellipse are kept).
  - **A mode ended while a descend has it paused.** Built and driven since the build
    after the last one: the end writes nothing on the canvas ("The mode itself", above).
    Driven with the real E key, a real Escape in the Results window, real clicks and
    real Escapes for the Results window's mode over Select On Design and for Select On
    Design entered again over that mode (leg DS9, in the Direct Plot flavour: the paused
    mode that is ended plots what it had queued); with real selector presses and the
    Calculator's close script for a pick and for Select On Design ended by a selector
    (band PG29, where the descend is armed by the command its key runs and the Results
    window's mode is ended by the command its Escape runs); and with the session
    window's own close script (row I13). In those rows the descend's wait is ended by
    its own doors that need no chooser: a click on an instance the suite gives no views,
    or a real Escape on the canvas. The chooser's own path, a click on a block that is
    then descended into in a new window, was driven in the order bench only, with the
    modal chooser stood in for by its success path. Not driven: a descend into a new
    tab after such an end, the design in a second tab, and the non-tabbed interface.
  - The same holds for `ase::ui::sod_reseat` and `calc::pick_reseat` as for
    `rdw::pick_reseat`: they are called by the one door that was found,
    `rdw::pick_end`. Nothing enforces that a new door which ends the Results window's
    mode calls them.
- **A mode ended under the Results Display Window's mode no longer strands that mode**
  (closed by the closing pass). Before it, with a Calculator selector armed and the
  Results window's key pressed on top of it, pressing the armed selector again, pressing
  another selector or closing the Calculator window left the Results window's mode
  recorded as up with nothing bound: its sentence on the status bar, clicks selecting,
  its key doing nothing. Closing the ASE-L session window did the same with Select On
  Design underneath. Now that mode takes the canvas again behind each of those doors and
  one ESC ends it. Measured by the closing pass with real presses and real ESC, one
  process for each order of Select On Design, a selector and the Results window's key
  that the fourth repair's verifier had driven: every order ends with no mode recorded,
  the canvas as the editor has it and a click selecting. What is left, none of which
  leaves the canvas seized:
  - **The keyboard moves to the schematic** when the pick is ended by a press in the
    Calculator window (the armed selector again; measured: from the Calculator's buffer
    to the design canvas). Taking the canvas takes the keyboard, as every seize of that
    mode does, because its ESC is bound on the canvas. Keys typed next go to the
    schematic; click the Calculator's buffer to type there again. Whether the keyboard
    should stay in the Calculator is the user's to rule on (Open items, item 5).
  - **A selector the loaded result cannot serve stays lit.** With `vt` armed on a
    result that has no ac analysis, pressing `vf` ends the armed pick, refuses to arm
    and leaves the `vf` radio lit with no pick running. The canvas is free and no mode
    is up. That is older than this work (the grid shows what was clicked, by the
    selector's own ruling) and was observed, not judged.
  - `calc::pick_end` asks that mode only when it released a pick. No row goes red with
    the question asked every time: `rdw::pick_reseat`'s own tests absorb it. (The same
    condition in `rdw::pick_end`, which the last build wrote, does have a row of band
    PG27 that goes red without it.)
  - The session window's close was driven in one shape (row I11): the design in the
    first tab, the stock bindings, a session with nothing unsaved, the Results window's
    mode entered by the command its key runs. The design in another tab and the
    Cadence-style profile's own key were not driven. A session closed through its save
    question was driven by a scratch probe only (answered No: the same end state).
- **With two modes stacked the status bar shows one sentence, the top mode's** (closed
  by the last build; before it the two sentences took turns on every tick). Held by
  band PG28 of `test_calc_pick.tcl` for the four stacks of two that the Results
  Display Window's mode makes with Select On Design and with a voltage selector, in
  the first tab: the slot sampled with no event sent, both writers then run once by
  hand (the sampling alone did not always catch a missing guard, because timers that
  fall due together run back to back), and the lower mode's sentence back after one
  ESC. A selector armed over the Results window's mode shows a blank for an instant
  before its prompt, as a selector armed alone does. Not driven: Direct Plot's
  flavour, a current selector, a second tab. What is left of the slot is its tooltip
  (the bullet above).
- **The design in a tab other than the first, with a second real window on the screen**
  (the waveform viewer's window, a block opened in a window of its own): the main window
  can end with the FIRST tab in front while the mode is armed. Once a real window has
  been the current one, the engine takes the next event on the canvas the tabs share for
  the first tab (open issue 1713; it does so with no mode up and is older than this
  work). Entering the mode from the session's menu can bring it about, and so can the
  pointer crossing the other window on its way to the schematic, and so can pressing a
  Calculator selector. Nothing wrong is queued or inserted. In Select On Design a click
  on the sheet that came to the front is refused with the window sentence and the mode
  stays armed: press the design's tab and click again. Under a Calculator selector the
  click there cancels the pick (`selector vt: this window is on another schematic now;
  pick cancelled`): press the design's tab, press the selector again and click.
- **In a tab other than the first the keyboard now goes back to the schematic after a
  dump** made in the Results Display Window's pick mode, as it does in the first tab
  (closed by the closing pass: `rdw::_focus_canvas` read the tab's name as a widget and
  handed nothing back, so the keyboard stayed in the Results window). Measured in the
  second tab with the tabbed interface on (row XP8); a third tab and the non-tabbed
  interface were not driven.
- **A stack whose order cannot be read.** A mode registered without saying what it
  holds, or whose answer raises, is neither over nor under any other mode. A stack of
  two with such a mode in it is released in the order the modes were registered, which
  is top first only when the upper mode was registered first. Such a mode waits for no
  other, so among three modes it can be released ahead of an earlier-registered mode
  that is waiting for the mode over it. Two modes that each name the other's script as
  what the canvas held before go in registration order too. The three click modes all
  say what they hold, so this is about a mode added later. The three-mode case is held
  by a leg of row CR6i for a mode that declares nothing; the same shape for a mode whose
  answer raises, is malformed or is empty was measured by a scratch probe and is held by
  no row. Row CR6s (one mode registered, then unregistered) goes red when the order
  leaves a mode out; nothing that was tried reddens its "empty again" half alone.
- **Across a descend, what was driven with real modes on a display** is the Results
  Display Window's mode over Select On Design into a new window (rows DS8a to DS8i) and
  in the same window (rows DS8j to DS8q: the stack order on the canvas, two real ESC,
  the unseized binding table, a real click on a device of the sheet landed on), and a
  Calculator pick with that mode on top through a descend in the same window (a row of
  band PG27: the order after the descend, ESC, ESC, a click that selects). The descend
  into a new tab, a Calculator pick taken into a new tab or a new window and the
  descend's own pick under a stack were measured by the fourth repair's verifier with
  scratch probes (each stack of two real modes through each kind of descend and the way
  back up) and are held in the suites only by the counted rows of band CR6, which use
  stub modes. Both display rows descend by the scripted `hi_descend` command, not
  through the key and its chooser, and the PG27 row uses a voltage selector.
- **A window made while a mode is up** gets the editor's bindings only when the mode's
  script is the exact string the canvas holds. A script appended to a slot the mode holds
  (`bind … +…`) is copied as it stands, the mode's script included.
- **With the tabbed interface a new tab is not a new canvas**: nothing is copied, and the
  canvas every tab shares keeps the mode's bindings. A click in a tab that shows another
  design is refused by the window test.
- **ESC pressed in a window that was made while the mode is up** is the editor's and does
  not end the mode. The mode ends by ESC in the window it is on.
- In a window that does not show the session's design the prompt names no pin, and
  neither does it while the pointer is in another window than the one the mode is on.
  The second was driven with real events in one shape: the mode carried into a new
  window by a descend, the pointer back on the first window (group PE). The other shape,
  the block's window made before the mode is entered, is fenced with stand-ins (row
  TPM12).
- A mode that was paused on a window of its own and comes back up with a tab current is
  fenced with a stood-in window list (row TPL12), not with real windows. A Calculator
  pick in the same place is fenced with stand-ins too (band PK15) and was driven once
  with the profile's real return by a scratch probe; the Results Display Window's mode
  is fenced with a real second tab (row XP8), where the way back is made by the two
  steps of the profile's return, not by its key, and the window it comes back from was
  made with `xschem new_schematic create_window`, not by a descend.
- A press made with Shift or Control held, or with another button already down, hands that
  modifier state to the engine with the press's position. It was not driven.

**The deck and the results.**

- **What a program can save is known only once it has been tried.** The line before a run
  and the sentence at a pick need the capability probe's answer for the program the
  session starts.
  A run takes it before it starts, so the first run on a program already says its line;
  a pick made before any run, and before Detect in the Simulators window, says nothing
  about the simulator.
- **The key is the simulator's answer to `$?probe_version`**, not a probe of a terminal
  below the top level. It was measured to agree with what the builds here do (three that
  answer 0 and refuse such a probe, one that answers 1 and makes it). A build that probes
  below the top level without setting that variable would be measured unable.
- **The cure names registered entries, not programs.** Two entries that name one program
  are both named (`ng_w_stb and ver_53 can`). An entry is asked with its own arguments.
- **A registered program that does not answer the probe in a fair share of the cure's
  time** is not started again by the cure until Detect in the Simulators window has
  measured it, the capability answers are cleared, the registry is edited or its file
  changes. The cure then says `is known to` where a measurement would have said `can` or
  named the entry. With such a program registered, the first run of a session on a
  simulator measured unable waits for it once, for no longer than the cure's bound
  (measured 2026-11-20 with one such program ahead of an able one: about four seconds
  before that run started, none before the next).
- **At a click nothing is started**, so a registered simulator nobody has asked is not
  known there: the pick's sentence and Direct Plot's then name it as not tried yet. That
  is rare after a run, because a run on a simulator measured unable asks every registered
  entry; it is what a click says after a new program has been registered, until the next
  run.
- **An entry that was asked and whose probe measured nothing a store keeps** (no folder
  to work in, for one) reads `not tried yet` again at the next click, and the next run
  asks it again.
- **An entry the cure does not ask is `not known`, never `not tried yet`**: one
  registered while its file could not be started, one whose file is gone, one of a
  backend that has no capability probe (row PH12c reads each at a peek; row TPV6b the
  first two at a click). About an entry whose file is gone, and about one of a backend
  with no probe, no run can find out, so the sentence does not say that one will. An
  entry whose file comes back is `not tried yet` again and is asked the next time the
  cure asks.
  An entry that was REGISTERED while its file could not be started is the other kind,
  and about it the sentence is WRONG once the file has been repaired: something can ask
  it, and the cure still does not. The cure reads what registering recorded
  (`ase::probe_cure_peek`; `ase::sim_capabilities_for` reads the same flag, is older
  than this issue and is left as it is), not the file as it is now. So after the file
  is repaired the cure still says `is known to`, and tells the user to register a
  build, until the entry is registered again -- which OK in the row editor does
  (`ase::ui::simdlg_ok`) -- although by then the list's Problem cell for it is empty
  (`ase::sim_entry_why`) and the resolver a run asks answers that the entry can be
  started (`ase::sim_status`). **Measured** 2026-11-20 by the verifier of the round
  that gave these entries their rows, on a copy of `ver_53` registered before its file
  was there and the file put in place afterwards: the Problem cell is empty; the
  cure's own ask starts nothing and the entry stays not known; Detect's measurement
  of the file in the Program field (`ase::sim_capabilities_path`, called as
  `ase::ui::simdlg_detect` calls it) starts the program and answers that it can do
  everything ASE-L offers; with nothing registered after it, as when the editor is
  cancelled, the click still reads *"None of the simulators you have registered is
  known to. Register an ngspice build …"*; after the entry is registered again as OK
  in the row editor registers it, the click reads *"late can — pick it under Setup >
  Simulators… before you run."* And through the real windows on the tree's own
  `tb_bandgap` bench, opened under a scratch home that held a copy of the user's
  registry: the entry picked under "Use this one:", the run starts
  it and exits 0, the terminal current below the top level is in the results and
  Direct Plot queues the trace; with nothing picked again the next pick still reads
  *"None of the simulators you have registered is known to. Register an ngspice build
  …"*. Not changed here: the cure would have to read the file as it is now in place of
  the recorded flag (`ase::probe_cure_peek`, `ase::sim_caps_have`), which is a change
  of code and turns the `zlate` legs of rows PH12c and TPV6b over. Those legs hold
  what the cure does today, and say so in their names.
- **What the cure knows is kept under the program file's stamp alone.** An edit of the
  registry no longer forgets which program can and which cannot, so a program rebuilt in
  place within one second, to the same size, keeps its old answer in these sentences
  until its file changes again. What a run reads is not affected: the capability store
  is still emptied by the edit.
- **What the last report said is one record**, for the whole process and not kept across a
  restart. After another session's run on other results, with a saved result in view, or
  after a restart, Direct Plot knows no reason: a row that is set is told the results do
  not hold it and to run again, and any other terminal keeps the sentence that says
  where to ask for it. Two state views of one bench that share a results file read one
  record: the simulator's sentence about the last run is said in both, and `these results
  are from before that` only in the view whose run it was.
- **Whose run it was is told by the state the run was handed**: the session whose current
  state it is when the run starts (`ase::session_holding`). It is taken once, at the
  start, and carried in the run record, so a session edited while its simulator runs is
  still the session whose run it was (row PH37 through `ase::run_deck`; row TPV13 for
  Direct Plot's "from before that"). A run a script starts with a
  state no session holds belongs to none, and a row set afterwards is then told the
  results do not hold it, not that they are from before it.
- **Direct Plot says the cure has been taken only when the session's program is already
  known able.** With an entry picked that nobody has asked yet, the sentence still names
  the entries known able, or says which have not been tried.
- **On a simulator without the extension**, a device inside a subcircuit is run on a real
  such build by row PN15. A subcircuit instance's pin, a vector that is missing with no
  refusal line, and several terminals in one line are text rows (PL19 to PL22).
- A probed vector is in the op, dc, ac, tran, disto and sp plots only.
- **A voltage source inside a block that has the same name as one of that block's ports**,
  with its own current not saved, reads the PORT's terminal current when it is asked for as
  `i(v.<path>.<name>)`. The probe's vector `i(x1:vp)` is stored `i(x1.vp)`, and the lookup
  ladder's older rung 4 rewrites `i(v.x1.vp)` to exactly that. Measured with the fork
  simulator on a block whose port and internal source are both `vp` and carry different
  currents: the answer was the port's. With the source's own current saved the exact name
  wins and the answer is right.
- A hand-typed row is reported after the run, not before it.
- **A bench whose only enabled analyses are two or more dc sweeps of a design variable**
  leaves an unqualified terminal row with an empty Value and no sentence. None of the
  sweeps is the bench's one analysis, so none gives its advice, and none of the four
  analyses is there to bring the note. Measured on the real road with states written by
  hand; whether the Analyses form lets a user enable two such rows was not checked.
- Beside a sweep of a design variable the note was run on the simulator for a noise
  analysis by a registered row (PA8h). Beside a tf, a pz and a sens analysis, and with two
  sweeps, it is fenced from written files (rows PL15e and PL15e2) and was run on the
  simulator by scratch scripts only.
- **The netlist's own `.probe` terms are compared as text.** A hand-written `.probe I(m1,d)`
  beside ASE-L's `I(m1,1)` names one terminal and is not seen to, so that pair is still
  written twice. Only the spelling with no blank inside the parentheses is read.
- **A netlist that carries `.probe alli` of its own** (seen by the third review, the same
  before and after the repairs): `ver_53` and apt 45.2 then name a top-level two-terminal
  device's current `i(rtop)` and make no `i(rtop:n1)`, also with ASE-L's `.probe I(rtop,1)`
  beside it. Such a row has no Value, and the report says the simulator neither made the
  vector nor said why. Taking `.probe alli` out of the sheet's code block gives the row
  its vector back.
- **A typed row with a signed number for the terminal**, `i(rt:-1)`, is taken as a terminal
  row. Its card `I(rt,-1)` made the operating point fail to converge on `ver_53` (exit 1);
  the convergence note is then said. No pick writes such a row.
- **A Save-ticked plain row of a name holding `=`, `'` or a brace** is still a `.save`
  card. The pre-flight refuses it by name before the run, so it does not reach the
  simulator; only an expression's reads are left out of the deck.
- Under `distinguish` the comparison with the netlist's own `.probe` terms is rendered by a
  row and has not been run on a simulator.
- **A bench whose only analysis is `tf`, with an operating point that fails.** A `tf`
  analysis goes on after a failed operating point. Where the failed solve leaves no
  singular matrix (measured 2026-11-19: a comparator loop, with the transient-op rung on
  and off, on `ver_53` and on apt 45.2) the run ends at exit 0, with the simulator's
  failure line in its log and a results file written. The convergence note is said only
  for a run that failed, so that bench is not told its probes may be the cause; it gets
  the note for a bench of only noise, tf, pz or sens analyses instead, and the log's own
  line `The operating point could not be simulated successfully.` is what tells the
  user. Where the failed solve does leave one (measured with the rung off: an inductor
  loop, a node with no dc path) the simulator aborts in the `tf` solve at a nonzero
  exit, and the note is said. No row pins either case (Open items).
- **The convergence note is fenced from log text**, and by one real-simulator row for an
  operating point that fails with the transient-op rung off (PN13b). A healthy run that
  was stopped and a later `tf` failure were run on both binaries by scratch scripts and
  are text rows in the suite. A pole-zero run that prints its warning and then fails was
  driven on the whole road by the fourth repair's verifier (a scratch script on both
  binaries, a failing `sens` after the pz: no note); no row runs it. The key's new
  phrase was not driven under `preserve` or
  `distinguish` (the line that reads the log does not read the case mode), nor in a
  campaign, a checkpointed or resumed run or a co-simulation.

**The marker.**

- Rows already in the Outputs table when the mode is entered get no marker: only this mode's
  clicks mark.
- SVG, PS and PDF exports do not draw markers.
- `xschem pin_marker clear -all`, which is how the mode's end clears, repaints the other
  visible windows. A hidden tab keeps a cleared marker's pixels until it is next shown, and
  another window is not repainted while the focused one is in the middle of a gesture.
- **Key `0` pressed in the middle of a gesture** clears the window it is pressed in and
  leaves the linked windows as they are (decision 49); it has to be pressed again after the
  gesture for those. Fenced with one gesture, a wire being drawn (rows PV1 and PV2); a
  move and a selection rectangle were not driven.
- A linked sheet in a tab is fenced on its marker list only; no row reads a tab's pixels.
- To Be Plotted and From Design… picks do not carry their waveform's colour (decision 17),
  and a Direct Plot ellipse can show the colour of a trace a later run replaced
  (decision 37).
- One marker per pin: a pin that carries a Direct Plot marker and is then picked in a row
  flavour takes that flavour's marker, which the mode's end removes.
- A renamed or deleted instance leaves its marker in the list, undrawn, until a clear.
- When xschem runs with 16 layers or fewer the row flavours draw no marker and say nothing.
- A switch to a cell's symbol and back goes through `xschem load`, and so clears the markers
  as it clears net highlights (read from the code, not driven).

**The Calculator.**

- It cannot add a probe, so a pin's current is there only after a run that saved it and
  after the viewer has loaded that run. A finished run loads the viewer when it plots a row;
  Results > Direct Plot followed by ESC loads it, and so does the `~` button when a row has
  Plot ticked. Doing nothing, `~` with no Plot-ticked row, Tools > Waveform Viewer, the
  viewer's Location bar on the same file and Results > Select of the same file do not
  (measured on a real session with real runs).
- **In a session with only an operating point**, with the viewer on the op slot, nothing
  that was tried reloads it: the run says `op results have no sweep -- nothing to auto-plot`
  and Direct Plot says there is nothing to plot. There the path the `absent` sentence names
  does not complete.
- A selector whose analysis is not the one the viewer shows reads the results file anew at
  each click, so only the selector of the shown analysis can be stale.
- **After a pick that resolved**, the second press of a double click is the editor's: the
  pick is one-shot and ended on the first release. In the stock bindings the property dialog
  of the wire or device under the cursor opens and the object is selected; under the
  Cadence-style profile connected-select runs there. Curing it needs a time window after
  the mode has ended, which is a trade-off left to the user.
- The sign note and the `absent` sentence fill the status line's room exactly at the
  shortest selector id; with a longer id and pin name the line elides the note, and the
  status history and the CIW hold it whole.
- Its pick needs an ASE-L session behind the result. The shared-point note on a source's pin
  is fenced without a display and was not driven by a real click.

**The Signal Browser.** The search bars match the label, so a terminal current is found by its
terminal (`*in_p*`, `d:i`) and not by its device's name; the device is the tree node.
A block port's terminal current and the branch current of a source of the same name inside
that block get one label in one node: `i(x3.vin)` and `i(v.x3.vin)` both read `vin:i` under
`x3`. The tooltip shows the raw name, and un-ticking the source-currents box removes the
second (`doc/claude/specs/waveform_signal_browser_two_pane.md` §5.4).
"Descend to here" still fails, with the window put back, for a format that writes a literal
letter in front of `@name`, for the second element of a two-line format, for a block with no
schematic file, for a device in the middle of a path, and for a segment nothing on the sheet
answers to.

**The user's other checkout.** `~/private/xschem-private`, which the user's design workarea
launches, has none of this: no `xschem pin_at`, no `xschem pin_marker`, no pin pick, no
`.probe` plan. A state saved here with a terminal row would there be written as a `.save`
card, which that tree's pre-flight refuses.

## When the pick refuses, or the simulator has no probes

0. **Pick a simulator that has them.** When the run's simulator cannot save a terminal
   below the top level, ASE-L names the registered simulators that can and the menu to
   pick one in (Setup > Simulators…). The three ways below are for when none can.
1. **Ammeter in series.** Place `ammeter.sym` in the branch and click its body: `i(<name>)`.
   Works for any terminal, a block pin included.
2. **All device currents.** Outputs > Save All… > "Save all terminal currents"
   (`.options savecurrents`, state key `save_all_i`): names of the shape
   `i(@m.xm1.msky130_fd_pr__nfet_01v8[id])`, the drain only on sky130 FETs.
3. **One device, typed.** Measures tab: `@m.xm1.msky130_fd_pr__nfet_01v8[id]` with Save ticked.

## Open items

The third repair closed one item of this list as it stood before it (key `0` in the middle
of a gesture, then item 11) and narrowed another (the sweep beside a noise analysis, then
item 12, now item 11). An item it added, a bus instance whose own name holds an equals
sign, was closed the same day (Limits, "The pick"; row TPU6). Items 1 to 10 keep their
numbers. The fourth repair closed nothing in this list, brought items 2 and 5 up to date
and added items 13 and 14. The closing pass built two of item 14's three parts (the
Calculator's doors under the Results Display Window's mode, and the keyboard in a tab),
so item 14 is now the `tf`-only bench alone; it brought item 5 up to date and added
item 15, two requests to the engine. The last build closed no item: it built the order
item 5 still named (the Results Display Window's mode ended first), which leaves in
that item only what is the user's to rule on, and it added a third request to item 15.
The message pass of 2026-11-20 closed no item and brought item 2 up to date.

1. **Nobody has seen it on a real screen.** Every run was headless or on a private Xvfb with
   generated events. Not seen: the ellipse on a picked pin, its green, its going on ESC and on
   key `0`, a Direct Plot ellipse beside its trace; the real Select Bus Bits dialog with
   terminals in it; the Calculator's pin pick; the prompt naming a pin; a double click by a
   real hand, with its real timing; a pick whose hand drifts; a window made while the mode
   is up; the mode with the design in a second tab; the prompt with a second window of the
   design on the screen; two click modes stacked, across a descend; the one sentence the
   status bar shows under two stacked modes; Escape pressed in the Results Display
   Window with another mode on top of its mode.
2. **Measured by hand, or not at all, with no row that runs it**: on an older simulator
   (`$?probe_version` 0), a subcircuit instance's pin and a missing vector (their report
   line is fenced from log text; a device inside a subcircuit is run on a real such build
   by row PN15 since 2026-11-20); a run that
   requests `distinguish` (its plan and its deck are fenced, the run is not); the `.probe`
   cards beside the operating-point tier's block; the optimizer export end to end with a
   terminal row; the transient's `Timestep too small` line in the convergence note (the
   operating-point failure lines were measured on two simulators; the note is fenced from
   log text and, for an operating point that fails with the transient-op rung off, by one
   registered real-simulator row, PN13b); `if` and `is` in the Calculator on a result with
   terminal vectors (the committed fixtures are an operating point and a transient); the
   path the Calculator's `absent` sentence names, which was followed on a bench with a
   simulator and has no registered row; the mode's rows under the Cadence-style profile, apart from the
   clear-all key and a drag (row P8d): the press after the pointer was overwritten, the
   window made while the mode is up and the tab were run under the stock bindings only,
   the Calculator's rows of the same kind likewise, and the Results Display Window's with
   the profile only; a window made by the profile's own Ctrl-N key, by a new tab or by
   detaching a tab while a mode is up (the rows make it with `xschem new_schematic
   create_window`); what a press does when the engine refuses the motion it is handed
   because a callback is already running.
3. **A hand-typed bus range**, `i(xb[1:0]:out)`, is not read as terminals (it holds two
   colons) and stays an inert `.save` card. The pick itself never writes one: it queues one row
   per bit.
4. **The ngspice side.** What would remove a workaround here is listed under "What would help
   from the ngspice side" in the brief.
5. **Click modes that share the canvas** (issue 0202). Select On Design and a Calculator
   pick end each other. The Results Display Window's pick mode still nests with both.
   No door of the product that was found leaves the canvas seized any more, in either
   order (Limits, "The mode"): a stack ended last-entered first is free, also across a
   descend (the fourth repair); the Results Display Window's mode survives the mode
   under it being ended (the closing pass: the other mode started, Select On Design
   entered again, a selector pressed again or changed, the Calculator window closed,
   the session window closed); and the mode on top survives the Results Display
   Window's mode being ended first, by Escape in the Results window (the last build).
   The two smaller members of the family are cured as well: the mode holds the motion
   with the button held, and a window made while a mode is up no longer gets the mode's
   scripts. What is left is the user's to rule on:
   - **a real stack** (issue 0202, D1), in place of each mode asking the others to take
     the canvas again behind every door that was found;
   - **whether the Results Display Window's mode should nest at all**, or end and be
     ended by the other two, which its own rulings forbid (ESC is its only exit, its
     keys are always live);
   - **the keyboard after a mode has taken the canvas again.** It is on the schematic,
     where the remaining mode's ESC is: after a pick is ended under the Results Display
     Window's mode by a press in the Calculator window (the closing pass), and after
     that mode is ended first by Escape in the Results window (the last build). Whether
     it should stay in the window it was in is a ruling (Limits, "The mode").
6. **A probe's source is a device to a `sens` analysis.** Each probed terminal adds entries
   to the sensitivity plot (`v(<path>:<tname>)` and that name with `_freq`, `_phase`, `_pwr`
   and `_z0`), some of them not zero. ASE-L has no sensitivity table today; one built later
   has to leave out the terminals of the run record's plan.
7. **A probe can stop a marginal transient.** It is a zero-volt source in series with the
   pin. Measured on the shipped `tb_ft_test_2`: one picked terminal turned a run that
   finished into `Timestep too small`, and a hand-placed ammeter at the same pin fails the
   same way, on the fork and on stock 45.2. ASE-L says so after such a run and cannot prevent
   it.
8. **`preserve` on a top-level expression source.** For a top-level `E` source written with
   `vol=` the lower-case card ASE-L writes is refused under `preserve` and the upper-case one
   is mis-named, so no spelling gives the two vectors. The run ends at exit 0 and the report
   relays the simulator's reason; the source's own `i(E5)` still works.
9. **Not in the user's other checkout** (Limits, last paragraph). Until it is ported there,
   or the workarea is pointed at this tree, the user's own designs do not have the feature.
10. **A double click after a Calculator pick that resolved.** Its second press is the
    editor's (Limits, "The Calculator"). A double click on the net one wants is the likeliest
    double click under a voltage selector. The cure is a short time window after the pick has
    ended in which a second press is swallowed; whether to have one is the user's call.
11. **A bench whose only analyses are two or more dc sweeps of a design variable** leaves an
    unqualified terminal row with no value and no sentence (Limits, "The deck and the
    results"). It is not specific to terminals: no unqualified row gets the sweep's advice
    there. Treating a sweep as the bench's one analysis when every other enabled analysis
    is such a sweep too (`ase::backend::ngspice::dcvar_output_refusals`) would close it.
12. **When the viewer reloads.** A run that plots no row leaves an open viewer on the
    previous run's data, and a session with only an operating point has no action that
    reloads it. That policy is older than this work and was left alone; it is why the
    Calculator's sentence names To Be Plotted, and why its path does not complete in an
    operating-point-only session.
13. **With the design in a tab other than the first and a second real window on the
    screen, the main window can end with the first tab in front** (Limits, "The mode").
    The cause is the engine's and is older than this work: an event on the canvas the
    tabs share is taken for the first tab once a real window has been the current one
    (open issue 1713, which now holds the two shapes measured here). No code of this work
    cures it: a switch back made once by the mode's entry does not hold, because the
    pointer crossing the other window flips the tab again. The cure proposed there is two
    engine changes, tried in a scratch build on four flows only.
14. **A `tf`-only bench whose operating point fails is not always told that it did not
    converge.** Where the failed solve leaves no singular matrix the simulator ends the
    run at exit 0, and the note is said only for a run that failed (Limits, "The deck
    and the results"); where it leaves one the run aborts and the note is said. No cure
    was tried and no row pins either case. (The two other parts this item had after the
    fourth repair, a selector pressed again under the Results Display Window's mode and
    the keyboard in a tab, were built by the closing pass.)
15. **Three requests to the engine**, each of which would replace a workaround of the pick
    on a shared point (Limits, "The pick"). None is built; no C was changed for them.
    The third was added by the last build.
    - **A verb that gives a pin's coordinates by index.** `xschem instance_pin_coord`
      looks a pin up by an attribute, and for a pin name used twice it answers the first
      pin of that name. `ase::ui::sod_term_edge_on` and `ase::ui::sod_term_toward` both
      place pins by name, so the first makes no claim for such a symbol and the second
      aims at a middle built from the first pin of each name.
    - **A read-only verb that prints an instance's box without its texts, on the
      sheet.** `ase::ui::sod_term_box_centre` works it out from the `Symbol:` line of
      `xschem instance_bbox` and the origin, rotation and flip of `xschem
      instance_coord`, repeating the engine's placement arithmetic in Tcl with six
      significant digits.
    - **Answers that are lists whatever the name.** `xschem pinlist <n> <attr>` writes
      each value between braces as it stands, `{ {<i>} {<value>} }`, and `xschem
      instance_pin_coord` answers `{<name>} <x> <y>` the same way (read in
      `src/scheduler.c`). For a pin name that ends in a backslash neither answer is a
      list: Tcl reads the backslash as escaping the closing brace. Each value, and that
      name, should be given as a list element. Until then the pick asks the engine's
      list of names and, where that is no list, reads each name off the pin's attribute
      string (`ase::ui::sod_term_pin_names`), and reads the point off the end of the
      answer as text (`ase::ui::sod_term_pin_xy`). The list of the attribute strings
      themselves is no list when one of them ends in a backslash; the reader of a
      terminal's netlist line (`ase::ui::sod_term_pins`) still needs it.
