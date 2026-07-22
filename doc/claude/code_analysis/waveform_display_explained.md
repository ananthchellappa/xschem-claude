# How XSCHEM Shows You Simulation Results — a plain-English tour

*Audience: a curious engineer who wants to understand how xschem turns a
SPICE simulation into pictures and on-schematic numbers, what that machinery
can and cannot do, and where it could improve. No prior knowledge of the
xschem internals assumed. Companion reference for people (and AIs) who will
actually change the code: `waveform_subsystem_reference.md` in this folder.*

---

## 1. The one idea that makes xschem unusual

Most EDA tools keep the schematic and the waveform viewer in separate
windows, or separate programs entirely. xschem's defining choice is the
opposite: **a waveform plot is just another object drawn directly on the
schematic canvas.** You place a "graph" the same way you place a resistor,
and it sits there on the drawing showing your transient/AC/DC curves. The
same simulation data that feeds those curves can also be sprayed back onto
the wires as little voltage/current numbers.

That tight coupling — move a cursor in a graph and watch the operating-point
labels update on the actual circuit — is xschem's genuine strength. It is a
lightweight, free version of the "cross-probing" that expensive commercial
environments (Cadence Virtuoso, Keysight ADS) are famous for. Everything
else about the viewer is comparatively basic, and that's the honest trade:
deep schematic integration, shallow viewer features.

The rest of this document follows a single number on its journey from a
simulator's output file all the way to a pixel on your screen, then looks at
the limits and the opportunities.

---

## 2. The journey of a number

### Step 1 — The simulation writes a file

You press **Simulate**. xschem doesn't talk to ngspice through a live
data pipe; it just runs the simulator as an external command (e.g.
`ngspice -b -r mycell.raw mycell.spice`) and the simulator writes a
**`.raw` file** — the standard ngspice binary dump of every node's value at
every time/frequency point. When the process finishes, the Simulate button
turns green (or red on failure). *(Detail worth knowing: pressing Simulate
does **not** re-generate the netlist first — you netlist separately, so a
stale netlist can be silently reused.)*

### Step 2 — xschem reads the file into memory

xschem parses that `.raw` file into a single in-memory structure called
**`Raw`**. Think of it as a big spreadsheet: one column per signal
(`time`, `v(out)`, `i(vdd)`, …), one row per sample point, all numbers
stored as C `double`s. A little hash table maps a signal's name to its
column so lookups are instant.

A few quirks of this "spreadsheet":

- It is **column-major** (all of one signal's samples are contiguous). That
  layout is deliberately cache-friendly for the common operation: scan one
  waveform start-to-finish.
- **AC (frequency) data** is complex, so each AC signal is expanded into
  *four* columns — magnitude, phase, real, imaginary — quadrupling the width.
- One file can hold several analyses (op, then dc, then tran). xschem loads
  **one analysis at a time** into a `Raw`; the others are skipped.
- The data is **never saved inside your schematic file**. The `.sch` only
  remembers the *path* to the `.raw` and which signals to plot. Move a
  schematic without its `.raw` and the plots go blank until you re-simulate.

Multiple `.raw` files can be loaded at once (each graph can point at a
different one), managed by a small registry.

### Step 3 — A "graph" is really a rectangle with notes on it

Here's the part that surprises people reading the code: **there is no
"Graph" object type.** A graph is an ordinary rectangle (the same `xRect`
used for any box you draw), living on a specific layer, with one magic word
in its property text: `flags=graph`. Everything else about the plot — which
signals, what colors, the axis ranges, the number of grid divisions, whether
it's analog or digital, log or linear, where the cursors are — is stored as
plain `token=value` text inside that rectangle's properties, roughly thirty
such tokens.

This is elegant in one way (graphs cost the file format nothing — they
piggyback on the rectangle you already know how to save and load) and fragile
in another (it's untyped free text; a typo in a token silently falls back to
a default, and the list of signals, the list of colors, and the list of
sweep-variables are three separate space-delimited strings that must stay
lined up by position).

### Step 4 — Drawing the curves

On every screen redraw, xschem walks all the graph-rectangles and, for each
one, translates those text tokens into a temporary "how to draw this graph"
context, then plots. The core loop is: for each signal, for each sample,
convert the data coordinate (say, *t = 3.2 ns, V = 1.1 V*) into a screen
pixel using a cached bit of affine-transform arithmetic, collect the pixels,
and hand the whole array to the X11 line-drawing call.

Things it handles: analog line traces, **digital** step traces, multi-bit
**buses** rendered as the classic two-rail hex-value ribbon (with proper
20%/80% logic thresholds), **log axes**, **histograms**, engineering-notation
axis labels (µ, n, p…), and two kinds of cursor (vertical time-cursors A/B and
horizontal value-cursors), with live readouts of the value under the cursor.

The important thing it does **not** do: any form of **decimation**. If your
transient has three million points, xschem creates three million screen
points and draws all of them, on every single redraw. There's a chunking
constant, but it exists to satisfy an X11 request-size limit, not to speed
anything up. This is the single biggest performance limitation (more below).

### Step 5 — Numbers back onto the circuit

Separately from the graphs, the same `Raw` data drives **back-annotation**.
Certain library symbols (net labels, supply symbols, probes) carry a magic
text token like `@spice_get_voltage`. When back-annotation is on, xschem
resolves that symbol's net to a node name, looks it up in the `Raw`
spreadsheet, and prints the value right there on the schematic. Move the "B"
cursor in a graph and these on-schematic numbers update to the value at that
moment in time — that's the cross-probing payoff.

*(A historical wrinkle: there are two back-annotation engines — a modern C
path and an older pure-Tcl one — kept consistent because the write path
populates both.)*

### Step 6 — Two ways to look at graphs

There are two front-ends over the exact same underlying machinery:

1. **Native graphs** — you add a graph rectangle onto an ordinary schematic
   (Simulation ▸ Graphs ▸ *Add waveform graph*), double-click it to pick
   signals, and interact with it in place. This is the original path.
2. **The ASE Waveform Viewer** (`wave_viewer.tcl`) — a newer, tidier
   *window* that behaves like a dedicated waveform tool. Cleverly, it isn't a
   custom widget: it opens a real (but read-only) xschem editor window and
   fills it with graph rectangles, so the same C engine draws everything. It
   keeps its own tidy signal/graph model in Tcl and regenerates the
   rectangles from it. This is what most modern usage flows through
   (Results ▸ Direct Plot, auto-plot after a run). Its design is documented
   in `doc/claude/specs/waveform_viewer.md`.

---

## 3. How you interact with a graph

Graph interaction is bolted *in front of* normal schematic editing: before
handling a mouse or key event normally, the code asks "is the pointer over a
graph?" and, if so, routes the event to the graph engine instead. Over a
graph you get: wheel to zoom/pan, drag to pan, right-drag to box-zoom,
`f` to fit, arrow keys to pan/zoom, `a`/`b` to toggle the two time-cursors,
click-drag to move a cursor, and a hover readout of the value under the
pointer. Graphs with a locked, matching x-axis pan and zoom **together**, so
scrolling one transient scrolls them all in sync.

One notable gap: **you cannot drag a signal onto a graph.** The only way to
add a trace is to *highlight* nets in the schematic and use the
"send-to-waveform" action, which appends them to the last-selected graph.

---

## 4. Limitations of the current approach

Honest inventory, worst-first:

1. **No decimation — doesn't scale to large traces.** Every visible sample is
   transformed and drawn every frame. Multi-million-point transients are slow
   and get slower the more you pan/zoom. This is *the* limitation.
2. **The viewer can't fully "see" its own graphs.** The C engine doesn't
   expose a graph's on-screen coordinates or its cursor/measurement state to
   Tcl. The ASE viewer works around this by keeping *mirror copies* of that
   state in Tcl, which can drift out of sync with the real thing.
3. **Graph state is untyped text with no validation.** ~30 tokens in a
   free-form string; the parallel signal/color/sweep lists can silently
   desync; the signal-name mini-language overloads punctuation (`;` for
   alias, `,` for bus, space for expression, `%` for dataset/file), so signal
   names containing those characters can confuse the parser.
4. **Export is raster, not vector.** Saving a schematic with graphs to SVG or
   PostScript embeds a *bitmap* of each graph (PNG/JPEG), so waveforms don't
   scale cleanly in the output and vanish entirely if optional image
   libraries aren't compiled in.
5. **Rigid file-format assumptions.** Binary `.raw` blocks are read as
   native-endian doubles with no byte-swap or format negotiation; the nominal
   "float" storage path isn't actually wired up. Cross-endian or float-format
   raws would be misread.
6. **No auto-refresh.** A freshly written `.raw` isn't detected; you must
   explicitly clear and reload. Combined with "Simulate doesn't re-netlist,"
   it's easy to look at stale results.
7. **Interaction is a duplicated pre-emption layer, not a real mode.** The
   "is the pointer over a graph?" guard is copy-pasted into ~11 event
   handlers; a new event path silently won't reach graphs unless someone
   remembers to add the guard.
8. **Thin measurement/marker set.** Only two time-cursors and two
   value-cursors, one bolded trace, and RPN-expression derived signals. No
   measurement calculator, no arbitrary markers, no per-trace cursors.
9. **Single-bit "digital" traces aren't truly thresholded** — they're analog
   values squashed into a thin band; only multi-bit buses apply real logic
   thresholds.

---

## 5. Where this sits versus the state of the art

**Digital / logic.** The open-source reference is **gtkwave** (and its FST
format), engineered to open enormous digital dumps efficiently, with bus
grouping, named markers, and scripting. xschem doesn't read those formats
natively — it *bridges* to gtkwave by converting a transient `.raw` to VCD
and can even receive commands back over a socket. **sigrok/PulseView** (logic
analyzer captures) is notable for protocol decoders and for *downsampling*
large captures — exactly the decimation xschem lacks.

**Analog / mixed-signal.** The commercial heavyweights — Cadence's **ViVA**
and **SimVision**, Keysight **ADS** Data Display, Synopsys **WaveView** —
offer waveform *calculators* (build new expressions from measured signals via
a UI), many simultaneous markers, Smith charts, eye diagrams, and rich
cross-probing to the schematic. **ngspice itself** ships a native `plot`
command (X11/gnuplot) plus interactive `.control` measurement commands, which
many users reach for as the built-in alternative.

Against all of these, xschem offers two x-cursors, two y-cursors, one bolded
trace, and RPN-derived vectors — no calculator UI, no Smith chart, no eye
diagram, no arbitrary marker set. Newer viewers like **Surfer**
(GPU-accelerated, built for very large traces) and **WaveDrom** (JSON-driven
digital timing diagrams for documentation) illustrate directions xschem
hasn't taken: scalable/GPU rendering and vector-native output.

**The balanced verdict:** xschem covers the *essentials* well — analog lines,
digital/bus rendering with real logic thresholds, log axes, histograms,
engineering-notation axes, cursors with live back-annotation — and its
schematic-embedded graphs plus operating-point annotation are genuinely
convenient and distinctive. What it lacks is *scalable rendering*, a *rich
measurement/marker/calculator surface*, *specialized RF/mixed-signal plots*
(Smith, eye), *broad native format support* beyond ngspice raw, and *true
vector export*.

---

## 6. Low-hanging fruit

Ranked roughly by payoff-per-effort. "Effort" is a rough order of magnitude
(hours / days / weeks). The engineering specifics — exact functions to
touch — are in the companion reference doc.

### Quick wins (hours)

- **Expose cursor/measurement state to Tcl** (`xschem get graph_flags` and
  cursor positions). Small, self-contained C read. Lets the ASE viewer stop
  keeping fragile mirror copies of state it can't currently see. *(Best
  ratio: tiny change, removes a whole class of desync bug.)*
- **Cache per-dataset sample offsets.** A hot inner-loop accessor recomputes
  a running sum on *every* sample fetch; precomputing it once at load time is
  pure speed for free.
- **Fix a latent sizing bug** in the "delete a signal column" path (an
  operator-precedence mistake that under-allocates). One-line fix in a
  rarely-hit but dangerous spot.
- **Bound the bus-value buffers** against very wide buses (currently a fixed
  1024-char buffer — a latent overflow).
- **Add an integrity check** that the signal/color/sweep lists are the same
  length, warning early instead of drawing garbage.

### Medium (days)

- **Surface expression errors.** The C expression evaluator for derived
  signals silently swallows its own errors, forcing the Tcl side to keep a
  hand-copied duplicate of the operator table (which drifts). Returning a
  real error would let that duplicate be deleted.
- **A graph coordinate / legend hit-test API.** Would let the viewer delete
  a trace by clicking its legend on the canvas instead of using a list box,
  and drop its Tcl bounding-box bookkeeping. The geometry already exists in
  C; only the accessor is missing.

### Big but high-value (weeks)

- **Decimation / downsampling.** When a trace has more samples than the plot
  has horizontal pixels, reduce it to a per-pixel min/max envelope before
  drawing. This is the largest rendering-performance win, but it touches the
  core sample loop and has to preserve cursor-measurement and
  waveform-splitting semantics — genuinely careful work.
- **True vector export** for SVG/PostScript (emit real polylines instead of
  an embedded bitmap).
- **A drag-a-signal-onto-a-graph gesture**, and/or a small measurement
  calculator UI, to close the biggest usability gaps versus the commercial
  tools.

---

## 7. If you want to read the code

Start here, in order:

1. **`save.c`** — `raw_read` → `read_dataset` → `read_raw_data_block`: how a
   `.raw` becomes the in-memory spreadsheet.
2. **`draw.c`** — `draw_graph_all` → `setup_graph_data` → `draw_graph` →
   `draw_graph_points`: how the spreadsheet becomes pixels.
3. **`callback.c`** — `waves_selected` / `waves_callback`: how the mouse and
   keyboard drive a graph.
4. **`wave_viewer.tcl`** — the ASE viewer window and its model.
5. **`token.c`** `translate()` (the `@spice_get_voltage` case) — how numbers
   land back on the schematic.

The companion `waveform_subsystem_reference.md` has the exact function
locations, the data-structure field lists, the contracts between passes, and
the list of landmines to avoid when changing any of this.
