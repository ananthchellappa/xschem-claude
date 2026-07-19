# Lessons: stringly-typed identity, and why a bug wouldn't reproduce

A post-mortem of one debugging session (2026-07-19, fluid-editing), written to teach.
Two independent bugs in the "schematic port" tooling had the *same* root cause, and the
investigation of the second one stalled for many turns for a *second, separate* reason.
Both the design mistake and the debugging mistake map cleanly onto named ideas in
computer science. This doc is the map.

Commits referenced: `74d1e03f` (feature), `7f26eadd` (bug 1 fix), `2f2f5170` (bug 2 fix).

---

## The episode, in brief

Two features let a user turn schematic net-labels into ports and edit a port's
name/direction in a Cadence-style "Edit Pin" form.

- **Bug 1.** The "toggle net-label ↔ port" utility reported *"no ports or wire-labels
  selected"* even with a label selected. Cause: it matched the symbol **filename**
  `lab_pin.sym`, but the user's label was `lab_wire.sym` — a different file, same *kind*
  of object.
- **Bug 2.** Pressing `q` on a port opened the generic *Edit Properties* form instead of
  the custom *Edit Pin* form. Cause: three code sites matched the filename `ipin.sym` /
  `opin.sym` / `iopin.sym`, but under the **library manager** symbols are referenced as
  `lib/cell` — `devices/ipin`, with **no `.sym` extension**. None matched.

Bug 2 is the interesting one to debug, because the code was *correct on every path I could
drive*. I reproduced the exact user steps — real `q` key, the toggle keybinding, a click
afterwards, with the user's `cadence_style_rc` loaded, on a freshly toggle-created pin —
and each time got the *right* form. The stall broke only when the user ran a one-line
diagnostic that printed the actual data: `sym=devices/ipin routes=0`. The symbol name had
no `.sym`; my test fixtures always did.

---

## Lesson 1 — Identity belongs to intrinsic type, not to a surface string

Both bugs are the same anti-pattern: deciding *what an object is* by string-matching one
of its **representations** instead of asking for its **intrinsic kind**.

```c
/* bug 2, paste.c — "is this instance a port?" answered by filename */
if(!strcmp(b, "ipin.sym")) return "in";        /* misses "ipin", "iopin", abs paths… */
```
```tcl
# bug 1, the toggle — "is this a wire-label?" answered by filename
switch $base { lab_pin.sym { … } }              # misses lab_wire.sym
```

A "port" is not the string `ipin.sym`. That string is *one* of several valid names for the
same thing (`ipin.sym`, `devices/ipin`, an absolute path, a `lib/cell` reference…). Tying
the program's notion of identity to one spelling is **primitive obsession** /
**stringly-typed programming**: a domain concept ("kind of pin") encoded as a raw string,
compared by equality, with all the aliasing and normalization hazards that implies.

The robust answer was available the whole time. Every symbol carries a `type` field
(`type=ipin`, `type=label`, …). Classifying by type is representation-independent:

```tcl
set type [xschem getprop instance $inst cell::type]   ;# ipin | opin | iopin | label
```

**The natural experiment.** The two features sat side by side answering the *same*
question, with two designs:

| feature | "is this a port/label?" | result |
|---|---|---|
| toggle utility (after bug-1 fix) | by `cell::type` (intrinsic) | **immune** to the `.sym` problem |
| Edit-Pin form | by filename (surface) | **broke** on `lib/cell` refs |

The type-based feature never even noticed the library-manager naming; the filename-based
one fell over. That is the lesson in a single controlled comparison: **prefer the intrinsic
discriminant.** When you must match a name, treat the name as data to be *canonicalized*
first (Lesson 6), never as the identity itself.

> General principle: *don't encode identity in an incidental representation.* A file's kind
> isn't its extension; a user isn't their email string; a shape isn't its serialized form.

---

## Lesson 2 — Reproduction needs the right *input class*, not just the right *steps*

I reproduced the user's **actions** faithfully and still saw correct behavior, because the
bug lived in the **input space**, not the action sequence. My fixtures always wrote
`C {devices/ipin.sym} …`; the user's world used `C {devices/ipin} …`.

In test-design terms these are two **equivalence classes** of input ("`.sym`-qualified" vs
"`lib/cell`, no extension"), and the defect lived entirely in the class I never sampled. My
whole reproduction suite was drawn from one partition — so every run was, unknowingly, a
test of the *happy* class. A green reproduction proved nothing about the user's class.

> General principle: a repro has two axes — **control** (the steps) and **data** (the
> inputs). Matching only the steps reproduces only control-flow bugs. When you can't
> reproduce, vary the *data* along its equivalence classes (empty, aliased, differently
> normalized, boundary, "the other config") — not just the clicks.

This is also why "works on my machine" happens: the machine differs in *configuration data*
(here, whether the library manager rewrites symbol references), not in the code.

---

## Lesson 3 — When every control-flow hypothesis falsifies, suspect the data

The investigation was disciplined but aimed at the wrong dimension. I generated and
falsified a chain of **control-flow** hypotheses:

- double dispatch of `q` (traced: single dispatch → correct form);
- the `edit_symbol_prop_new_sel` "edit-next" while-loop (only fires on a flag nothing set);
- the modeless-form re-target hook `on_selection_changed` (gated on `slickprop_form_open`,
  reliably 0);
- a leaked flag from a form closed via the window `X` (all close routes reset it);
- a stale running instance (plausible, but unproven).

Every one was correctly refuted. That *pattern itself* — many well-formed control-flow
hypotheses, all false — is the signal. It means the control flow is fine and the fault is
in an **assumption about the data** the control flow operates on. I kept searching the code
graph when I should have pivoted to interrogating the inputs.

> General principle (hypothesis-driven debugging, done right): track *which dimension* your
> falsified hypotheses live in. A run of dead ends in one dimension is evidence to switch
> dimensions, not to search that dimension harder.

---

## Lesson 4 — Observability collapses a search that theory cannot

Hours of reading and reproduction ended with one line the user ran in their live session:

```tcl
puts "schpin=[llength [info procs schpin::edit_form]] \
      sym=[lindex [xschem instance_coord] 1] \
      routes=[expr {[file tail …] in {ipin.sym opin.sym iopin.sym}}]"
# -> schpin=1 sym=devices/ipin routes=0
```

`routes=0` with `sym=devices/ipin` named the bug outright. The decisive move was not a
cleverer theory; it was **printing the actual value of the predicate at the actual site in
the actual environment**. Everything I couldn't see by reading — the environment-specific
data — became visible in one measurement.

> General principle: instrument the *real* environment and print the *decision variable*.
> A well-placed observation is worth many well-reasoned guesses; theory can only explore the
> state space you already imagined, measurement reveals the state you didn't. Design that
> observation to be *self-locating*: dump the predicate **and** its inputs, so one line both
> proves and explains.

Corollary for tools you ship: make the failure path *say what it saw*. Bug 1's fix didn't
just fix the match — it changed the dead-end message from *"no ports or wire-labels
selected"* to one that lists the selected symbols and their types, so the next mismatch
diagnoses itself instead of starting another investigation.

---

## Lesson 5 — One assumption in three places is a DRY violation waiting to bite

The `.sym`-suffix assumption was copied into **three** sites — C (`pin_sym_dir`) and two Tcl
(`slickprop::edit_form` routing, `schpin::dir_of_sym`). Fixing the bug meant finding and
editing all three (**shotgun surgery**): miss one and the form opens but the direction is
wrong, or `set_pin_type` still refuses. The single fact — *what counts as a port* — had no
single home.

Had "is this a port?" lived in one function (ideally the type-based one), the fix would have
been one edit and there would have been nothing to miss.

> General principle: a rule replicated across N call sites is one decision stored N times.
> Duplication is not just extra characters — it is N chances to fix it inconsistently, and a
> guarantee that the next related change is a scavenger hunt. Give each domain rule a single
> source of truth.

---

## Lesson 6 — Canonicalize before you compare; be liberal in what you accept

When you *must* compare names, normalize them to a canonical form first. The fix does the
minimum version of this:

```tcl
# ipin.sym -> ipin ; ipin -> ipin ; then compare against the canonical set
if {[file rootname [file tail $symbol]] in {ipin opin iopin}} { … }
```
```c
if(!strcmp(b, "ipin.sym") || !strcmp(b, "ipin")) return "in";
```

This is the **robustness principle** (Postel's law): *accept the several valid spellings of
the input, emit one canonical spelling.* The bug existed because comparison happened on
**un-normalized** strings drawn from a space with more than one legal form. Comparing raw,
multi-form representations for equality is a perennial source of defects (trailing slashes,
case, Unicode normalization, `./` prefixes, extensions). The habit to build: *normalize at
the boundary, compare in canonical form.*

---

## Lesson 7 — The bug was a leaked abstraction

The library manager offers an abstraction: refer to a cell as `lib/cell`, and the tool
resolves it to a file. That abstraction **leaked** — the resolved-vs-unresolved distinction
surfaced exactly where downstream code assumed a filesystem path with a `.sym` extension.
Leaky abstractions aren't a moral failing of the abstraction; they're a reason to *not
assume the abstraction's internal representation* in code that lives underneath it. Detecting
"port-ness" from the reference string reached under the abstraction and depended on a detail
(the extension) the abstraction was free to change — and did.

---

## Takeaways (the checklist)

1. **Classify by intrinsic type, not by a surface string.** If a `type`/kind field exists,
   use it. Extensions, filenames, and paths are representations, not identities.
2. **If you must match names, canonicalize first**, then compare against a canonical set.
   Accept the several valid input forms; store one.
3. **Give each domain rule one home.** A predicate duplicated across call sites will be
   fixed inconsistently.
4. **To reproduce, vary the data, not only the steps.** Enumerate the input equivalence
   classes — especially "the other configuration" (here: library manager on).
5. **A run of falsified control-flow hypotheses means: switch to the data dimension.**
6. **End the guessing with a measurement.** Print the decision variable *and* its inputs in
   the real environment; make failure messages self-diagnosing.
7. **Don't assume an abstraction's internal representation** in code beneath it.

The one-line summary: *both bugs, and the long hunt for the second, came from treating a
representation (a filename) as an identity (a kind). Ask what a thing **is**, not what it is
**called**.*
