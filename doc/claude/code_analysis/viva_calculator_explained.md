# The Calculator, explained

*For anyone who has never touched Cadence. No EDA background assumed. This describes
what Cadence's "Virtuoso Visualization & Analysis (ViVA) L Calculator" is, what its
window looks like, what every part of it does, and why we want one in xschem.*

**Companion:** `doc/claude/specs/calculator.md` is the build spec — same subject, written
for a machine, with numbered requirements. This file is the one to read first.

---

## 1. The problem, in plain terms

You draw a circuit. You hand it to a **simulator** — a program that solves the physics and
tells you what every wire in the circuit does over time. The simulator writes its answers
to a results file.

That file is not a picture. It is a pile of numbers: for each *signal* (a wire, or a
current through a device), a long column of measurements — one per instant of simulated
time, or one per frequency, or one per step of some swept input.

A **waveform viewer** turns a column of numbers into a curve on a screen. xschem has one.
It is very good at "show me the voltage on node `out`".

But almost nothing an engineer actually wants to know is a raw signal.

- "What's the *gain*?" → that's `out` divided by `in`, in decibels.
- "How fast does it settle?" → that's a *time*, extracted from a curve by a rule.
- "How much power does it burn?" → that's supply voltage times supply current, averaged.
- "Where does the gain fall off?" → that's the frequency at which a derived curve crosses
  a threshold.

Every one of those is a **computation on waveforms**. None of them is a signal you can
point at in the results file. Something has to build them.

That something is the Calculator.

---

## 2. The one big idea

The name is misleading, and this is the single most important thing to understand:

> **It is not a pocket calculator. It is an expression builder.**

A pocket calculator's job is to give you a number and forget. This tool's job is to help
you *compose a formula*, and then hand that formula to something else that will run it —
possibly thousands of times, on results you have not simulated yet.

That is why it matters. In a serious design you don't simulate once. You simulate across
temperature, across manufacturing variation, across supply voltage, across a hundred random
samples of the same transistor. Each of those runs produces its own results file. You want
the *same question* asked of all of them: "what is the gain here?"

So the Calculator's real output is a **string** — a formula, in a form the simulation
environment understands. You build it by clicking, you check it by plotting it once, and
then you paste it into the place where the tool keeps its list of things-to-measure. From
then on it is evaluated automatically, forever, on every run.

Everything about the window's design follows from this. The big white box in the middle is
not a display of *results*; it is a display of the *formula being written*. The stack below
it is a scratch area for half-built formulas. The buttons don't compute — they **type**.

Keep this in mind and the whole layout becomes obvious. Forget it and the tool looks
bizarre.

---

## 3. Words you need

A short glossary, because the rest of this uses these constantly.

| Word | What it means |
|---|---|
| **net** / **node** | A wire. Everything electrically joined together is one net with one voltage. |
| **terminal** / **pin** | A connection point on a component. Currents are measured *at* terminals, not at nets. |
| **instance** | One placed copy of a component. `M1` is an instance of a transistor. |
| **hierarchy** | Circuits nest. A net inside a block inside a block has a path-like name: `/I0/I3/net12`. |
| **transient** | A simulation of behaviour over **time**. X axis is seconds. |
| **AC** | A small-signal simulation over **frequency**. X axis is Hz. Results are complex numbers (magnitude + phase). |
| **DC sweep** | Slowly vary one input and record the steady answer at each step. X axis is whatever you swept. |
| **operating point** ("op") | One steady snapshot with no sweeping. Each signal is a single number, not a curve. |
| **noise** | A simulation of random electrical fuzz vs frequency. |
| **sweep** | Re-running a simulation with one parameter varied. Produces a *set* of results. |
| **corner** | A named worst-case combination (slow silicon, hot, low supply, …). |
| **Monte Carlo** | Many runs with randomised component values, to see spread. |
| **family** | The *set* of curves that comes out of a sweep/corner/MC run — one curve per member, all under one name. |
| **PSF** | Cadence's results-file format. A directory full of data. xschem's equivalent is a `.raw` file. |
| **OCEAN / SKILL** | Cadence's scripting languages. The Calculator emits OCEAN expression text. |

---

## 4. The window, region by region

Here is the layout, matching the screenshot. Letters key to the walkthrough below.

```
┌────────────────────────────────────────────────────────────────────────┐
│ Virtuoso (R) Visualization & Analysis L Calculator            _ □ ✕   │
├────────────────────────────────────────────────────────────────────────┤
│ File   Tools   View   Options   Constants   Help           cādence    │  (A)
├────────────────────────────────────────────────────────────────────────┤
│ ▲  Results Dir: /auto/fsc/rjz/.../tutorial3/spectre/schematic/psf      │  (B)
├────────────────────────────────────────────────────────────────────────┤
│  ○vt ○vf ○vdc ○vs   ○op  ○var ○vn    ○sp ○vswr ○hp ○zm                │  (C)
│  ○it ○if ○idc ○is   ○opt ○mp  ○vn2   ○zp ○yp   ○gd ○data              │
├────────────────────────────────────────────────────────────────────────┤
│  ◉Off ○Family ○Wave   ☑Clip   [∿] [→]   [ Append ▾ ]   [▤]            │  (D)
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│                    T H E   B U F F E R                                 │  (E)
│           (the expression you are building, as text)                   │
│                                                                        │
├────────────────────────────────────────────────────────────────────────┤
│ ▲ [↵][⧉] Pop [⇥][⇤] │ [⌫][⌦] M+  ME   ↶ ↷                             │  (F)
├─ Stack ────────────────────────────────────────────────────────────────┤
│ (◎)                                                                    │
│ (⇩)         parked expressions, most recent at top                     │  (G)
│ (⊘)                                                                    │
│ (◎)                                                                    │
├────────────────────────────────────────────────────────────────────────┤
│ [ Special Functions ▾ ]                       │   7   8   9   /        │
│  average    delay     flip      harmonic  …   │   4   5   6   *        │
│  bandwidth  deriv     fourEval  harmonicFreq  │   1   2   3   -        │  (H) (I)
│  clip       dft       freq      histo         │   0   ±   .   +        │
│  …                                            │  user1  user2          │
│  ◄────────────────────────────────────────►   │  user3  user4          │
├────────────────────────────────────────────────────────────────────────┤
│ status area                                                         ▾  │  (J)
└────────────────────────────────────────────────────────────────────────┘
 8                                                                          (K)
```

### (A) Menu bar

Six menus, and their contents tell you what the tool thinks it is:

- **File** — open/save a saved expression, print, close. Not files of *data*; files of
  *formulas*.
- **Tools** — jump to the other tools in the family (the waveform viewer, the results
  browser).
- **View** — show/hide the panels. Every big region of this window can be collapsed, which
  is why there are little `▲` triangles hanging off the left edge in two places.
- **Options** — the important one. **RPN vs Algebraic mode** lives here, along with display
  precision and stack behaviour.
- **Constants** — a menu of physical constants (Boltzmann's constant, electron charge, π)
  that you can drop into the formula rather than typing `1.380649e-23` by hand.
- **Help**.

### (B) Results Dir

*Where the numbers come from.* One line, showing the path to the results of the simulation
you are asking about. Everything the tool does is relative to this.

This exists as a visible, editable field because a real user has many result sets lying
around — last night's run, this morning's run, the one from the good version — and wants to
point the same formula at a different one. Changing this line re-aims every subsequent
click at a different pile of data.

The `▲` on the left collapses the row to save screen space.

### (C) The signal-selection grid — the heart of the tool

Twenty-two little radio buttons in two rows. These are the *only* way raw signals enter a
formula, and each one answers a different question.

You click one — say `vt` — and the button stays lit. Your mouse pointer then becomes a
picker over the **schematic window**. You click a wire in your circuit. The Calculator
writes `VT("/out")` into the buffer.

That is the whole gesture: **choose what kind of quantity you want, then point at the
circuit.** You never type a node name. The two rows are laid out so that voltage-things sit
above the matching current-things:

| top row | bottom row | you get |
|---|---|---|
| `vt` | `it` | **v**oltage / current vs **t**ime (from a transient run) |
| `vf` | `if` | voltage / current vs **f**requency (from an AC run) |
| `vdc` | `idc` | the single steady **DC** value (from an operating-point run) |
| `vs` | `is` | voltage / current vs the **s**wept variable (from a DC sweep) |
| `op` | `opt` | an internal device property — a transistor's transconductance, its threshold voltage, its current — as a single number (`op`) or vs time (`opt`) |
| `var` | `mp` | a **var**iable you defined in the simulation setup / a **m**odel **p**arameter from the device library |
| `vn` | `vn2` | noise voltage (per root-hertz) / noise voltage **squared** (noise *power* density) |

The right-hand block is radio-frequency work, meaningless outside RF design:

| | |
|---|---|
| `sp` `zp` `yp` `hp` | S-, Z-, Y-, H-**p**arameters — four equivalent ways of describing how a circuit reflects and transmits high-frequency signals |
| `vswr` | voltage standing-wave ratio — a single number for "how badly does this reflect?" |
| `gd` | group delay — how long a signal is delayed, as a function of frequency |
| `zm` | port impedance |
| `data` | escape hatch: pick a result by name from a browser, instead of by pointing at the schematic |

Two things are worth noticing about this grid.

**First:** the split between `vt`/`vf`/`vs`/`vdc` is not pedantry. The same wire has a
different *meaning* in each analysis. In a transient run `out` is a real number vs time. In
an AC run it is a *complex* number vs frequency. In an operating-point run it is one
number. Asking for the wrong one gives you a formula that will not evaluate, so the tool
makes you say which up front.

**Second:** currents need a *terminal*, not a net. There is no such thing as "the current
in this wire" if three things are joined to it. So `it` makes you click a component's pin,
and the name it writes looks like `/M1/D` — the drain of transistor M1.

### (D) The mode strip

A small row of controls that change *how the next thing you do behaves*.

- **Off / Family / Wave** — three radio buttons, one selected. This is the "what am I
  picking?" switch.
  - **Off** — normal pointing at the schematic.
  - **Family** — a sweep produced a whole family of curves; pick the family as one object.
  - **Wave** — don't point at the schematic at all; point at a **curve already drawn in the
    waveform viewer** and pull it into the formula. This is how you build on what you're
    looking at.
- **Clip** (a checkbox, ticked in the screenshot) — when on, an incoming signal is
  automatically trimmed to the X range currently visible in the waveform window. If you've
  zoomed in on the interesting 2 µs, "average" means the average of *those* 2 µs. This is a
  quiet but enormous convenience, and it is on by default for exactly that reason.
- **Two icon buttons** — evaluate/plot shortcuts (send the buffer to the waveform window;
  evaluate it to a number).
- **`Append ▾`** — a dropdown deciding what plotting *does*: **Append** (add to what's
  already drawn), **Replace** (wipe and draw this), or send it to a new panel. Without this
  every plot would either pile up forever or destroy your comparison.
- **A table icon** — show the result as a table of numbers instead of a curve.

### (E) The buffer

The large white box. **This is the formula.** It is plain, editable text; you can click in
it and type if you'd rather. Everything else in the window is a way of putting text here
without typing it.

Its contents at any moment are something like:

```
db20(VF("/out") / VF("/in"))
```

That string *is* the deliverable. Select it, copy it, paste it into the simulation
environment's outputs list, and you have a permanent measurement.

### (F) The buffer toolbar

Verbs that act on the buffer and the stack:

- **Enter** — push what's in the buffer down onto the stack, clearing the buffer.
- **Pop** — bring the top stack item back up into the buffer.
- **Swap / roll** — reorder stack items.
- **Clear buffer / clear stack** — the two with red marks.
- **`M+`** — store the buffer into a memory slot.
- **`ME`** — memory recall / memory editor.
- **↶ ↷** — undo/redo (greyed out when there's nothing to undo).

### (G) The Stack

A list of parked expressions, most recent at the top. The four round buttons down the left
edge push, pop, delete and recall.

Why does an expression builder need a stack? Because real formulas are built out of pieces
that must be captured *before* they can be combined. To get gain you need `out`, then `in`,
then a division. You can't type them in one go — each one requires a trip to the schematic
with the mouse. So you fetch the first, park it, fetch the second, and combine.

The stack is that parking area. It is also, in RPN mode, the actual machinery of
computation — see §5.

### (H) The function browser

Bottom-left: a **category dropdown** (showing "Special Functions") and, below it, a
multi-column scrolling list of function names. Clicking a name applies that function to
what's in the buffer.

The dropdown switches whole categories — trigonometry, arithmetic, matrix ops, RF-specific
ones, and "Special Functions", which is where the measurement verbs live. The horizontal
scrollbar underneath is a giveaway: the list shown is not all of them.

These are documented in §6 because they are the substance of the tool.

### (I) The keypad and user buttons

A numeric keypad — digits, `.`, `±`, and `+ - * /`. Not because typing `4` is hard, but
because in a click-driven workflow you don't want to move your hand to the keyboard
mid-formula.

Below it: **user 1 … user 4**. Four blank buttons you bind to your own expressions. Every
group has three or four measurements they take on everything; these are them, one click
away.

### (J) The status area

A one-line message field with a dropdown at the right — the dropdown reveals *history*, so
an error that flashed by is still readable. Errors, evaluation results and warnings land
here.

### (K) The corner number

A small number outside the main frame — a stack-depth / status indicator.

---

## 5. RPN, explained from scratch

The Calculator has two modes, set in **Options**. You should understand both, because the
default is the unfamiliar one.

### Algebraic mode

What you'd expect. You write

```
(a + b) * c
```

and the brackets say what happens first.

### RPN — Reverse Polish Notation

You write the *values first* and the *operator last*:

```
a b + c *
```

Read it as instructions to a machine with a stack of plates:

| step | you say | the stack becomes |
|---|---|---|
| 1 | `a` | `a` |
| 2 | `b` | `a`, `b` |
| 3 | `+` | *(take two, add, put the result back)* → `a+b` |
| 4 | `c` | `a+b`, `c` |
| 5 | `*` | *(take two, multiply, put back)* → `(a+b)*c` |

No brackets are ever needed, because the order is already unambiguous. That is RPN's whole
selling point: **there is no precedence to remember and nothing to get wrong.**

The cost is that it reads backwards until you're used to it.

RPN is the historical default here for a reason that is not nostalgia. In this tool, the
operands arrive **one mouse-trip at a time** from the schematic. RPN is the notation whose
natural order is "fetch a thing, fetch another thing, combine" — exactly the order your
hand is already working in. Algebraic mode makes you plan the parentheses before you have
the operands.

Two consequences worth knowing:

- In RPN mode, **the stack panel is not decoration** — it is where the operands live and
  where the operators act. `Enter` is a real operation.
- In algebraic mode the stack is demoted to a scratchpad, and the buffer does the work.

*(Aside, relevant to us: xschem's existing waveform engine already speaks RPN. See §8.)*

---

## 6. The function library, in plain English

These are the "Special Functions" — the measurement verbs. Grouped by what they're *for*,
rather than alphabetically as the tool shows them.

### Reduce a curve to a number

| | |
|---|---|
| `average` | mean value over the X range |
| `rms` | root-mean-square — the "effective" magnitude of a wobbling signal |
| `stddev` | spread |
| `integ` / `iinteg` | area under the curve; `iinteg` gives the running total as a new curve |
| `peak` | find the peaks |
| `histo` | build a histogram of the values |

### Timing measurements (transient)

| | |
|---|---|
| `riseTime` | how long to go from (say) 10% to 90% |
| `slewRate` | how fast the voltage moves, in volts per second |
| `delay` | time between an event on one signal and an event on another — the workhorse |
| `settlingTime` | how long until the signal stays inside a tolerance band |
| `overshoot` | how far past the target it went before settling |
| `dutyCycle` | fraction of a period spent high |
| `frequency` / `freq` | the signal's frequency, derived from its crossings |
| `period_jitter` / `freq_jitter` | how much the period/frequency wanders run to run — clock quality |
| `cross` | the X value where the signal crosses a threshold (the primitive most others are built on) |
| `eyeDiagram` | fold a data stream over one bit period to see if the "eye" is open — the standard picture for a serial link |

### Frequency-domain measurements (AC)

| | |
|---|---|
| `bandwidth` | where the response falls off by a given number of dB |
| `gainBwProd` | gain × bandwidth — a figure of merit that's roughly constant for an amplifier |
| `gainMargin` / `phaseMargin` | *how close to oscillating* a feedback loop is. Two of the most-consulted numbers in analog design |
| `groupDelay` | delay vs frequency |
| `pzbode` / `pzfilter` | work with pole/zero results — the mathematical description of a filter's behaviour; `pzfilter` selects a subset of them |

### Spectral / signal analysis

| | |
|---|---|
| `dft` | Discrete Fourier Transform — turn a time waveform into its frequency content |
| `dftbb` / `psdbb` | the "baseband" (complex I/Q) variants used in radio work |
| `psd` | power spectral density — how power is distributed over frequency |
| `spectrum` / `spectralPower` | spectrum and the power in it |
| `harmonic` / `harmonicFreq` | pull out the Nth harmonic, or its frequency |
| `phaseNoise` / `rmsNoise` | noise expressed as phase wobble, and integrated noise |
| `fourEval` | evaluate a Fourier series |

### Distortion and linearity

| | |
|---|---|
| `compression` / `compressionVRI` | the input level at which gain has dropped by 1 dB — where an amplifier stops being linear |
| `ipn` / `ipnVRI` | intercept points (IP3 etc.) — how badly two tones mix into unwanted products |
| `evmQAM` / `evmQpsk` | error vector magnitude for digital modulation — "how mangled is the constellation?" |
| `dnl` | differential nonlinearity — data-converter step-size error |

### Shape and combine curves

| | |
|---|---|
| `clip` | keep only part of the X range |
| `flip` | mirror along X |
| `lshift` | slide the curve along X by an offset |
| `deriv` | slope |
| `convolve` | convolution of two waveforms |
| `intersect` | where two curves cross |
| `compare` | do these two curves agree within a tolerance? (regression checking) |
| `sample` | take values at chosen X points |
| `root` | the X where the curve equals zero |
| `dBm` | convert to dBm — power in decibels relative to a milliwatt |
| `getAsciiWave` | pull a curve in from a text file, so you can plot measured lab data against simulation |

The transforms that *sound* mathematical (`dft`, `deriv`, `convolve`) return curves.
The ones that sound like questions (`bandwidth`, `riseTime`, `delay`) return single
numbers — and when applied to a family, one number per family member, which is precisely
what you feed into a corner table.

---

## 7. What it is not

Worth stating, because each of these is a plausible misreading:

- **Not a spreadsheet.** It does not hold your data. It holds a formula that refers to data
  living somewhere else.
- **Not a plotting tool.** It has a "plot" button, but drawing happens in the waveform
  viewer. Plotting from here is *checking your formula*, not the goal.
- **Not a numeric calculator.** `2 + 2` works, and nobody has ever opened this window
  to do that.
- **Not where measurements live.** Measurements live in the simulation setup's output list.
  The Calculator is where they are *composed* before being put there.

---

## 8. Why xschem can have one, cheaply

This is the surprising part, and it changes the size of the job.

**xschem already contains the evaluation engine.** In `src/save.c` there is a function
`plot_raw_custom_data()` — a stack machine that evaluates **RPN expressions over waveform
data**, with about fifty operations already implemented: arithmetic, comparison, a
conditional, `sqrt() abs() sgn()`, the full trig and hyperbolic set, `exp() ln() log10()`,
`db20()`, `integ()`, `deriv()` in four flavours, `avg()`, `ravg()` (running average),
`max()`/`min()` clipping, `prev()`, `del()` (delay), `idx()`, `re()`/`im()`, `cph()`
(continuous phase), stack manipulation via `dup()` and `exch()`, and the constants
`pi() k() q() e()`.

It is reached today from the graph attributes: a plotted trace's name can be an RPN
expression instead of a signal name. The waveform viewer's own trace-adding procedure takes
a parameter literally called `rpn`. And `xschem raw add <name> <expr>` already lets an
expression become a **new named vector** in the loaded results, visible everywhere a real
signal is.

So the three hard parts of building a calculator are already done:

1. an expression language over waveforms — **exists**, and it's RPN, which is what the
   Cadence tool defaults to anyway;
2. a way to evaluate an expression against loaded results — **exists**;
3. a way to plot the result — **exists**, and even the Append/Replace destination selector
   already exists in the viewer.

What does not exist is the *window*: the buffer, the stack, the signal-picking radio grid,
the function browser, the memories, and the measurement verbs (`bandwidth`, `riseTime`,
`delay` and friends) that sit above the arithmetic layer.

That is the shape of the work. The engine is there; the cockpit is not.

One honest caveat: the RF half of the signal grid (`sp`, `zp`, `yp`, `hp`, `vswr`, `zm`,
`gd`) describes analyses ngspice does not perform. Those buttons should be visible but
disabled — the layout is part of the tool's identity, and a greyed button is information
("this exists, not here"), while a missing one is a puzzle.

---

## 9. Where to go next

`doc/claude/specs/calculator.md` — the build spec: widget inventory, exact semantics of
every control, the function catalogue as a table, and ~90 numbered requirements written so
they can be turned into tests.
