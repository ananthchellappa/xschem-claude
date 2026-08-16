# Case-preserving signal names — the open questions, in plain English

Written 2026-08-16, before any code was written for items 1–15. Nothing here is
decided. This document exists so the decisions get made deliberately, by the
user, with the background spelled out — not chosen by whoever happens to be
writing the code that day.

Companion documents: `PLAN.md` (the 15 items), `LEDGER.md` (batch state),
`receipts/00c-round3-verification.md` (the measurements), and
`doc/claude/ngspice_upstream/` (the exchange with the ngspice maintainers).

---

## Part 1 — What the feature is, and why it doesn't exist yet

### The one-sentence version

If you draw a wire and name it `EN`, and then simulate, the waveform viewer
shows it as `v(en)`. All lowercase. You wanted `v(EN)`. This batch is about
making the capital letters survive the round trip.

### Why the capitals get lost

There is a chain of about five programs between your schematic and the picture
on screen, and historically **every single one of them was allowed to lowercase
names**, because the file format they all share was designed that way.

SPICE — the circuit simulator language, invented at Berkeley in the 1970s — is
case-insensitive by design. `R1` and `r1` are the same resistor. `VDD` and `vdd`
are the same wire. This is not a bug or an oversight; it is written into the
language. Every SPICE simulator ever built folds names to lowercase somewhere,
and every tool that reads SPICE output has been written assuming lowercase is
what it will get.

So there was never anything to decide. Names were lowercase. Full stop.

### What changed

The ngspice maintainers built a new option called `casemode`. It has three
settings:

- **`fold`** — today's behaviour, and the default. Everything is lowercased.
  `EN` becomes `en`.
- **`preserve`** — the *labels* keep their capitals, but two names that differ
  only in case are still the same wire. So `EN` is displayed as `EN`, and
  `EN` and `en` are still one wire.
- **`distinguish`** — capitals are kept *and* they matter. `EN` and `en` become
  two different wires that are not connected.

This is brand new and it is not in any released ngspice. It exists on a private
development branch, which is on this machine at
`/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice`. The released version
everyone else has (`ngspice-46`, at `/usr/local/bin/ngspice`) accepts the new
flag, ignores it, and folds anyway.

### The good news, and it is genuinely good

We measured the whole chain. **xschem's netlister already does the right
thing.** If you draw a net called `TOPNET`, the netlist file it writes really
does say `TOPNET`, capitals intact. The simulator, in `preserve` mode, really
does write `v(TOPNET)` into its output file.

Then xschem reads that file back and lowercases it — at exactly **one line of
C code**, `src/save.c:1008`, a call to `strtolower(varname)`.

One line. That is the whole reason you see `v(en)`.

Everything else in the 15-item plan is about doing this *safely* — making sure
that removing that fold does not break the thousands of things downstream that
have always assumed lowercase.

### Why this is not a two-line change

Because "assumed lowercase" is load-bearing in more places than you would like:

- Saved schematics on disk have graph settings storing folded names like
  `node="v(midnode)"`. Those must keep working.
- Saved ASE-L session files store expressions like `v(en)`. Those must keep
  working.
- Branch currents get names the simulator *invents* — `i(V.X1.Vp)` — which are
  not in the netlist at all, and whose capitalisation follows its own rules.
- The Ctrl-K highlight-to-viewer path lowercases in four separate places in
  `hilight.c`, none of which know about any of this.
- About twenty committed test assertions have lowercase names baked into them.

None of that is hard. It is just wide. Hence 15 items.

---

## Part 2 — What the user has already said they want

From this session, verbatim:

> "We want full support for case *when user wants it* — we want to know what
> simulator we are using and set options accordingly."

That is a clear steer and it settles more than it looks like it settles:

1. **Opt-in, not automatic.** Nobody gets case names because they upgraded.
2. **There is a notion of "which simulator am I using"** — a registered
   simulator with a path, arguments, and a known capability. That is items 6, 7
   and 13 of the plan (the profile registry, the capability probe, and the
   `Setup > Simulator…` dialog).
3. **We set options based on what we detected.** So the probe is not decoration;
   it is how the feature knows what to ask for.

The questions below are the parts that steer does *not* settle.

---

## Part 3 — The questions

Thirteen of them, in four groups. Group A is the core bargain. Group B is the
simulator registry. Group C is bugs we tripped over on the way and now have to
rule on. Group D is scope — how much to build now versus later.

---

# GROUP A — The core bargain

## A1. Which mode should we ask for by default?

### The plain version

`preserve` and `distinguish` are not "a bit of case" and "a lot of case". They
are two genuinely different deals, and the difference is about **whether two
names that differ only in case are the same wire.**

**Under `preserve`:** `EN` shows up as `EN`. But if your design has a wire
called `Out` and another called `OUT`, the simulator still treats them as one
wire. Capitals are decoration — accurate, useful decoration, but decoration.

**Under `distinguish`:** `Out` and `OUT` become two separate wires. Capitals are
now *meaningful*. Which sounds better until you consider what else that changes.

### Why `distinguish` is riskier than it sounds

Case-insensitivity is not just about wire names. It runs through the entire
SPICE ecosystem:

- **PDK libraries.** A foundry model file defines `.SUBCKT NAND2` in capitals.
  Every schematic that instantiates it as `nand2` works today, because case
  folds. Under `distinguish` that call stops resolving. And we do not control
  the PDK files — they belong to the foundry.
- **Subcircuit parameters.** If a parameter is defined as `W` and you pass `w`,
  under `distinguish` the simulator does not error. It silently uses the
  default value. Your circuit simulates fine and gives the wrong answer.
- **Global nets.** A `.global VDD` with a `vdd` reference elsewhere silently
  becomes a floating node. Again: no error, wrong answer.

Both of those last two exit with status 0. A clean run. A wrong number.

### The state-file consequence, which is new

The ngspice maintainers confirmed something in round 3 that sharpens this.

A session file you saved last month contains lowercase expressions like
`v(en)`. When we re-run it:

- Under **`preserve`**, that old lowercase spelling still works. The simulator
  resolves it. (They fixed this specifically, upstream change `0056`.)
- Under **`distinguish`**, that old spelling is **fatal**. The run dies, and the
  output file that gets written contains no useful data at all.

They also confirmed this is **permanent** — the strict behaviour is
`distinguish`'s contract, not a temporary state they intend to relax.

So the two modes do not merely differ in what the labels look like. They differ
in **whether your existing saved work survives**.

### Why this has never come up before

Because until this ngspice branch existed, there was no choice to make. Every
SPICE simulator folded. There was one mode and it was `fold`.

### Who notices if we get this wrong

- Pick `preserve` and someone genuinely needed `Out` ≠ `OUT`: they are
  disappointed, but nothing breaks and they can switch their profile.
- Pick `distinguish` as the default and someone has a PDK with capitalised
  subcircuit names: their designs stop netlisting correctly, possibly silently.

The failure is asymmetric, which is the main argument here.

### The choices

| | what a fresh profile proposes |
|---|---|
| **(a)** | `preserve` default, `distinguish` available per-profile with a warning in the dialog |
| **(b)** | `distinguish` default — matches the literal premise "`EN` ≠ `en` ≠ `En`, everywhere" |
| **(c)** | `fold` default — the feature ships switched off, both modes opt-in |

**Recommendation: (a).** It delivers the stated goal — your capitals show up —
without any of the silent-wrong-answer paths, and it keeps every existing PDK
and session file working. `distinguish` stays available for anyone who wants
the strict deal, behind a warning that says what they are giving up.

Note that (c) is defensible too given the user's "when user wants it" framing —
it is the same thing as (a) except the profile dialog starts on `fold`. The
practical difference is one dropdown's initial value.

---

## A2. What do we do when the user's own config file overrides us?

### The plain version

ngspice reads a startup file called `.spiceinit` when it launches. It looks for
it **in the directory the deck is in**. Users keep real customisations in there.

We measured this: if `.spiceinit` contains `set casemode=fold`, and we launch
with the command-line flag `-D casemode=preserve`, **the file wins**. The run
folds. Our flag is silently ignored.

There is a command-line switch, `-n`, that tells ngspice to skip `.spiceinit`
entirely. That would guarantee our mode takes effect — and would also throw away
every other customisation the user has in that file.

### Why this has never come up before

Because nobody has ever passed `-D casemode` to ngspice. The option is weeks
old. The precedence itself is not new or broken — the maintainers confirmed
it is deliberate and they are not changing it. It only becomes *our* problem
now that we have an option we care about.

### How we know it happened

This is the part that got much easier. The maintainers added a variable called
`$curcasemode` that reports **the mode actually in effect, after `.spiceinit`
has had its say**. We can ask, before the run, what mode we are really going to
get. It costs about 12 milliseconds.

One catch we measured the hard way: the question must be asked **from the deck's
own directory**. Ask from anywhere else and you get a confident, wrong answer,
because that is where `.spiceinit` is looked for.

### Who notices

Only a user who has a `.spiceinit` with a `casemode` line in it. Today that is
nobody, since the option barely exists. In future it is the power user who has
deliberately set a preference — which is arguably a good reason to let them win.

### The choices

| | behaviour |
|---|---|
| **(a)** | No `-n`. Probe first, run in whatever mode came back, and **say so** in the log and CIW when it differs from what we asked for. Add a per-profile `-n` checkbox for anyone who wants the override. |
| **(b)** | No `-n`, no checkbox. Same as (a) minus the escape hatch. |
| **(c)** | Pass `-n` always. Our mode always wins. |

**Recommendation: (a).** The user's own config file beating the application is
the normal and correct precedence; what would be wrong is us *claiming*
`preserve` while the run folded. Detecting and reporting the mismatch costs 12 ms
and turns a silent surprise into a log line.

---

# GROUP B — Knowing which simulator we are talking to

This group is the direct expression of "we want to know what simulator we are
using and set options accordingly". The plan covers it in items 6, 7 and 13, but
several shape decisions are unmade.

## B1. Where does the mode setting live?

Today xschem has a setting called `simulator`, which names a *backend* — which
set of hooks and command templates to use. That is not the same thing as "which
executable, with what arguments, having what capabilities".

The plan proposes a new **simulator profile registry**: a small user-level file
listing named simulators, each with an executable path, arguments, a requested
casemode, the measured casemode, and the date it was probed.

The unmade decision: **what scope does the mode setting have?**

| | |
|---|---|
| **(a)** | **Per profile.** You register "ngspice-dev" with `preserve` and "ngspice-system" with `fold`, and picking a simulator picks the mode. |
| **(b)** | **Global preference**, one setting for all simulators. |
| **(c)** | **Per session**, stored in the ASE-L state file, so different analyses can differ. |

**Recommendation: (a), with a global fallback for the plain File→Open-raw path**
— which has no session and no profile to consult, and needs *some* answer.
That is what the plan's `sim_case_mode` variable is for. (a) and the global
default are not alternatives; the global one covers the case where no profile
applies.

## B2. What do we do when we cannot tell?

The probe returns one of four answers: `fold`, `preserve`, `distinguish`, or
**nothing at all** — which is what a simulator without the feature does
(released ngspice-46 replies `Error: curcasemode: no such variable.`).

There is also a second, better source. The maintainers now write a line into the
output file itself: `Option: casemode=preserve`. That is exact — it describes
the run that produced the file, not a guess. But it only appears if we ask for it
(by emitting `set casemodewrite`), and it does not appear at all on released
ngspice, which ignores the request silently.

So there is a third, weakest source: **sniff the file**. If the signal names
contain capital letters, assume `preserve`. This is a guess and it can be wrong —
the Xyce simulator writes `V(EN)` in capitals under semantics that are not
`preserve` at all.

Two things to rule on:

**B2a. Resolution order.** Recommendation: **header → probe → sniff**, with the
sniff off by default. Read the exact answer if the file carries one; ask the
simulator if we can; guess only if asked to.

**B2b. What does "no answer" mean?** Recommendation: **unknown, never `fold`**,
falling back to `fold` *behaviour* while recording that we did not actually know.
The distinction matters because the maintainers have written a patch that would
make the header line appear by default, and have **not submitted it** — so
"absent" will keep meaning "old simulator or feature not requested" for the
foreseeable future, and treating absence as a positive statement would age badly.

## B3. Should we probe automatically when a simulator is registered?

The plan proposes: on Add, if the executable's filename contains `ngspice`
(case-insensitively), run the probe immediately and pre-fill the detected mode.
Plus a **Test** button that probes on demand for any simulator.

Question: is the automatic probe wanted, or should it always be an explicit
button press?

**Recommendation: automatic on Add for ngspice-named executables, plus the Test
button for everything.** It is 12 ms and it makes the dialog show truth instead
of an empty field. But it does execute a program the user just typed a path to,
which is worth being conscious of.

## B4. Requested mode ≠ measured mode — run anyway, or refuse?

Following on from A2. Suppose the profile asks for `preserve`, we probe, and the
answer is `fold`.

| | |
|---|---|
| **(a)** | Run anyway in the measured mode, and report the mismatch in the log and CIW. |
| **(b)** | Refuse to start and make the user resolve it. |
| **(c)** | Ask, in a dialog, each time. |

**Recommendation: (a).** The run is still valid — it just produces lowercase
names, which is what happens today anyway. Refusing would block work over a
cosmetic difference. The ngspice guide's own closing advice is to report rather
than assume, and (c) becomes an interruption the user will click through.

---

# GROUP C — Bugs found along the way

These are not case-related. We found them while measuring, they are real, and
they need rulings because the plan currently has no home for some of them.

## C1. The phantom `v(all)` signal

### What happens

Run an operating point analysis. Record exactly one signal. The output file
comes back with **two** signals: the one you asked for, and a second one named
`v(all)`.

It is not a corrupted or garbage signal. It carries the **same value** as the
real one — we measured `v(in) = 1.5` and `v(all) = 1.5`. It is a duplicate
column with a wrong name.

### The exact trigger — narrower than the plan says, and wider in one way

We measured this today, and it is more precise than what `PLAN.md` records:

| what you run | released ngspice-46 | the dev build |
|---|---|---|
| `op`, save exactly one voltage | `v(in)` **`v(all)`** | `v(in)` — clean |
| `op`, save exactly one **current** | `i(v1)` **`i(all)`** | `i(v1)` — clean |
| `op`, save two signals | clean | clean |
| `op`, save nothing (saves everything) | clean | clean |
| `tran`, save one signal | clean | clean |
| `dc`, save one signal | clean | clean |

**New fact, and it changes the answer:** the current form `i(all)` also happens.
The plan and the round-3 receipt only ever mention `v(all)`. A filter written
against `v(all)` alone would miss half of it.

Why `tran` and `dc` escape: they automatically include a sweep axis (`time`,
`v-sweep`), so the total is already two signals and the trigger never fires. Only
`op` has no axis. So the rule is: **an operating point with exactly one recorded
signal**.

### Why this hasn't been brought up before

Three reasons stacked:

1. **It is a genuinely rare shape.** You have to run an operating point *and*
   record exactly one signal. Most people run transient or DC sweeps. Most
   people who run `op` do not restrict what gets recorded — and if you record
   nothing specific, everything gets recorded, and the trigger does not fire.
2. **Nothing breaks.** The value is correct. The number is right. It is one
   extra row in a list, carrying a duplicate of a number you already have.
3. **In plain xschem it barely arises.** The `.save` lines that trigger it come
   from ASE-L, which emits one `.save` per output row you have added. Hand-driven
   xschem simulation usually saves everything.

### Is it an ngspice-46 bug?

**Yes.** It is present in the released `ngspice-46` that everyone in the world
has. We found it, reported it, and the maintainers fixed it on their development
branch (change `0064`). It is not in any release yet.

So this is not a risk introduced by our feature. It is a live upstream defect
that our feature happens to walk past.

### Why is the rest of the world not complaining?

Because of reason 1 and reason 2 above — you need an unusual analysis shape to
see it, and when you do see it, it looks like a slightly odd extra signal
carrying a plausible value. Nobody files a bug about that. They ignore the row.

It became visible to *us* because ASE-L generates its `.save` lines
mechanically, one per output row, so a user with exactly one output row hits the
shape every single time. And our signal browser lists every signal in the file,
so the phantom is presented as if it were a net in the circuit.

### The choices

| | |
|---|---|
| **(a)** | **Filter it, but only when we know the run recorded exactly one signal** — which we do know, because we generated the `.save` lines ourselves. Filter both `v(all)` and `i(all)`. Because it is gated on the one-signal case, it cannot swallow a real net named `all` in any other session. |
| **(b)** | **Warn once in the CIW** and leave the row on screen. |
| **(c)** | **Leave it**, document it, cite the upstream fix. |

**Recommendation: (a)**, now that the `i(all)` form is confirmed — a
name-only filter would have been a poor lever, but a filter gated on "we asked
for exactly one signal" is exact rather than heuristic. This affects everyone
using a released ngspice, and will keep affecting them for as long as the fix
sits unreleased.

Sub-question: **which item owns this?** It currently belongs to no item. Item 5
(the browser side) is the natural home, or it can be a new item.

## C2. Two schematic nets that differ only in case

### What happens

You have a net named `Out` and another named `OUT`. In xschem these are **two
different nets** — we confirmed the net hash table compares names with `strcmp`,
which is case-sensitive. The schematic shows them as separate.

The netlist we write contains both spellings. ngspice then folds them together
into **one** net.

So: two nets on your screen, one net in the simulation, **and nothing tells you**.
Silent, today, in every mode. This is the current released behaviour and it has
nothing to do with our feature.

### Why this hasn't come up before

Partly luck, partly that people rarely name two nets `Out` and `OUT` in the same
schematic on purpose. And when it does happen, the symptom is not an error — it
is a simulation result that does not match what you drew, which most people
would chase as a circuit problem, not a naming problem.

### What changed upstream

The maintainers shipped a warning for it in round 3. We measured it:

```
no flag / fold  Warning: node names 'Out' and 'out' differ only in case and name one node (casemode=fold)
preserve        ... name one node (casemode=preserve)
distinguish     ... name two nodes (casemode=distinguish)
released 46     (silent)
```

Two useful properties: it fires in **all three modes**, and it is emitted at
parse time, which means **it sees `.include`d PDK model files** — content our
netlister never sees and cannot check.

Two awkward properties: because it is parse-time, a deck cannot capture it from
inside its own control block, so we would have to scrape it off the run log; and
a collision inside a subcircuit body is reported **once per instantiation**, so
it needs de-duplicating.

### The two halves

- **Relay their warning** when using a simulator that emits it. Free, and it
  covers PDK files we cannot see.
- **Our own netlister-side check**, for the released simulators where nothing is
  emitted at all. Honest scope: we can only see the nets we generate.

The question is about our half only.

### The choices

| | |
|---|---|
| **(a)** | **Warn.** Netlist proceeds; the message names both nets. |
| **(b)** | **Error** — refuse to netlist. |
| **(c)** | ~~Warn under `fold`/`preserve`, error under `distinguish`.~~ **WRONG — see correction below.** |

> **Corrected 2026-08-16, mid-Q&A.** Option (c) above is backwards and the user
> caught it. `distinguish` makes ngspice see **two** nodes, which is what xschem
> already shows — that mode is the one where nothing is wrong. `fold` and
> `preserve` are where ngspice sees one node against xschem's two, so they are
> the hazard. The corrected option (c), and the decision taken, is: **fire only
> under `fold`/`preserve`, stay silent under `distinguish`, and warn rather than
> error.** Wrong text kept, not deleted — the bad intuition ("strict mode
> deserves strict errors") is worth seeing. See `DECISIONS.md` §C2.

**Recommendation: (a).** It matches what the maintainers chose for their own
half, it cannot break an existing design that has been quietly relying on the
collapse, and since we cannot see PDK-included nets, an error would be a hard
stop based on an admittedly incomplete check. (c) is defensible — under
`distinguish` the collapse genuinely becomes a two-net split — but it is more
code for a case that is already opt-in and already warned about.

## C3. A `.save` of a signal that does not exist

### What happens

Ask the simulator to record a signal name that is not in the circuit — a typo,
say `v(nosuchnode)`. What you get:

- **No error message that names the token you got wrong.** The only mention
  comes from a separate `print` line, and it says
  `Warning from checkvalid: vector nosuchnode is not available or has zero length` —
  which is our own doing, not a diagnostic about the `.save`.
- An output file that **exists**, is **well-formed**, and contains **twelve
  variables** — which are ngspice's built-in mathematical constants
  (`pi`, `boltz`, `echarge`, `kelvin`, …). Not your circuit. Not empty either.
- Exit status **1** in the deck shape we actually emit. (This took four days to
  get right — an earlier measurement used a different deck shape and reported 0.
  See C4.)

The downstream problem: xschem reads that file, gets a valid parse and a
non-zero variable count, and **attaches it as if the simulation succeeded**. The
viewer shows a database with no traces and no explanation.

### Why this hasn't come up before

Because you need a typo — or a stale saved session naming a net you have since
renamed. Then the symptom is "my plot is empty", which people re-run rather than
report. And the file genuinely is valid; nothing in the parse says otherwise.

### Is it an ngspice bug?

Arguably, and we reported it. The maintainers have withdrawn a fix for it
**three times**, so the defence has to be ours. It happens on **released
ngspice-46** in every casemode. Nothing to do with our feature — but our feature
brought us here, and it is worth fixing on its own merits.

### Not really a question, but worth confirming

The plan (item 10) proposes two defences:

1. **Refuse to launch** when a name in the deck is not in the netlist we just
   generated, listing the offending expressions. This is the only defence that
   can name the problem *before* a simulator runs.
2. **Reject that output file on content** — recognise the constants plot
   (`Plotname: constants`, a `Date:` equal to the build stamp, a variable-count
   floor) rather than trusting the exit code.

Confirming that this is worth building as part of this batch, rather than
splitting it out as its own issue, is a scope call — see D-group.

## C4. The `$sim_status` guard — does it replace the pre-flight, or sit beside it?

### Background

The maintainers pointed out a variable, `$sim_status`, that reports whether the
analysis actually succeeded. We can emit a guard into the generated control
block:

```
op
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
write <path>
```

Measured on both simulators: on a bad run this exits 1, prints `RUN-FAILED`, and
**writes no file at all** — which is strictly better than the constants file,
because there is no misleading artefact to mistake for success. It works on
released ngspice-46 today.

### The question

Does the guard **replace** the netlist pre-flight from C3, or do we build both?

**Recommendation: both.** They defend different moments. The guard is cheaper
and stronger *after* the run starts. But only the pre-flight can tell the user
*which expression* is wrong, *before* a simulator launches — and since the
simulator emits **zero** diagnostics naming the bad token, the pre-flight is the
only thing in the entire chain that can point at the actual mistake.

---

# GROUP D — Scope calls

Four "how much do we build now" questions. Each has a legitimate "defer with a
filed issue" answer.

## D1. Re-casing old session files

**The situation.** A session file saved before this batch contains `v(en)`. Under
`preserve` that still works — the maintainers fixed it (`0056`). Under
`distinguish` it is fatal.

**The proposed work:** at deck-generation time, build a map from the netlist we
just produced (lowercase name → real spelling) and rewrite each stored
expression to the netlist's spelling.

**The question:** build it, or defer it with a filed issue?

**Recommendation: defer with a filed issue**, unless `distinguish` is going to be
a default (see A1). It is only load-bearing in `distinguish`, which is opt-in and
carries a warning. Deferring keeps the batch focused; the issue records why.

## D2. VCD files

**The situation.** xschem can read VCD files (digital simulation output). That
reader **already keeps names verbatim** — it never folded. A comment at
`vcd_read.c:140` documents the resulting lookup mismatch as a known cost.

**The proposed work:** mark a VCD dataset as `preserve` so lookups behave
correctly, and delete that comment's apology.

**The question:** in this batch, or separately? It *changes VCD lookup
behaviour*, which is a real behavioural change for existing users, not a
tidy-up.

**Recommendation: in this batch but as a deliberate sub-step with its own
checks** — not a drive-by inside item 2. It is the one place where the existing
code was already right and our machinery finally lets it say so.

## D3. Backannotation under `distinguish`

**The situation.** Backannotation (reading simulation results back onto the
schematic, ten call sites in `token.c`) folds names. It keeps working under
`preserve`, because the lookup ladder keeps its lowercase fallback rungs. Under
`distinguish` those rungs are removed by design, and backannotation breaks.

**The question:** accept that as a documented `distinguish`-mode limitation for
this batch, or fix it now?

**Recommendation: accept and document**, given `distinguish` is opt-in.

## D4. `full_audit` baseline — already resolved, recorded here for completeness

The plan and ledger say a ~80-minute baseline audit pair is owed. **It is not.**
The merge-5 loose-ends batch shot one at the current HEAD and committed it:

`doc/claude/merge5_loose_ends/audit_item02_fixround_2026-08-16.txt` —
316 pass / 15 fail / 0 crash-timeout / 0 skip of 331, at `577ef5bc`, on the dev
display `:99`.

That is the file every later audit gets diffed against, by test **name and
status**, never by the red count. `LEDGER.md` needs the pointer written in. No
decision needed; just noting that the debt is paid.

---

## Part 4 — Things that are settled, so nobody re-opens them

- **Where the fold happens:** `src/save.c:1008`. Verified still there after the
  open_pdk merge 5.
- **The netlister is already correct.** It emits schematic case verbatim.
- **`.save` should always use the schematic's spelling.** Safe in all three
  modes. The folded spelling is fatal in `distinguish`.
- **The default at every stage is `fold`.** Items 1–8 must produce an **empty**
  audit diff. If they do not, something changed behaviour that should not have.
- **Never name signals on a `write` line.** Doing so writes two identical
  columns with byte-identical names, which no filter can separate. Our generator
  already complies; nothing may change that.
- **Never emit both a `set` and an `unset` of the same simulator variable.**
  That is an immediate crash (SIGABRT) on released ngspice too.
- **The dev build is a moving target.** It has moved three times during this
  batch — most recently to `Sun Aug 16 06:52:46 UTC 2026`, this morning. Tests
  must assert on `$curcasemode` and on measured output, never on "this build has
  fix X in it", and must **skip, not fail**, when the private build is absent.

---

## Part 5 — Summary table

| # | question | recommendation |
|---|----------|----------------|
| A1 | default mode for a fresh profile | `preserve` default, `distinguish` opt-in with a dialog warning |
| A2 | `-n` / does `.spiceinit` win | no `-n`; probe, run in the measured mode, report the mismatch; per-profile checkbox |
| B1 | scope of the mode setting | per profile, plus a global default for the no-profile path |
| B2a | how we resolve the mode | header → probe → sniff; sniff off by default |
| B2b | what "no answer" means | unknown, never `fold`; permanent |
| B3 | auto-probe on Add | yes for ngspice-named executables, plus a Test button |
| B4 | requested ≠ measured | run in the measured mode, report it |
| C1 | phantom `v(all)` / `i(all)` | filter both forms, gated on "we saved exactly one signal"; assign it an item |
| C2 | `Out`/`OUT` collision, our half | warn |
| C3 | `.save` of an absent signal | build both defences (see C4) |
| C4 | `$sim_status` guard vs pre-flight | both — only the pre-flight can name the bad expression |
| D1 | re-case old session files | defer with a filed issue unless `distinguish` becomes a default |
| D2 | VCD marked `preserve` | in this batch, as a deliberate sub-step with its own checks |
| D3 | backannotation under `distinguish` | accept and document as a mode limitation |
| D4 | audit baseline | already paid; record the pointer in `LEDGER.md` |
