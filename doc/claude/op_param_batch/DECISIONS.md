# Decisions — OP parameter lists batch

Settled with the user 2026-09-02, in two rounds, before any item started.
**Authoritative.** Where this file and the spec disagree, this file wins and the
spec is wrong.

| # | decision | the user's words |
|---|---|---|
| **D-1** | Declutter hides **everything except `@name` and the OP annotation**. Pin labels included. It is not a "parameter" classifier. | *"even pin labels can be hidden when user is hiding other things that are not @name. We are only interested in name and annotation of OP info."* |
| **D-2** | The RDW takes bare `1`/`2`/`3`/`4`, **in the cadence profile only**. Stock xschem keeps `logic_set`. | selected "Take 1-4, cadence profile only" |
| **D-3** | A multi-primitive instance prints **all** its primitives, *if the simulator has the data and it is easy to find*. | *"If data is available from simulator and easy to find, do it."* |
| **D-4** | **No guessing** what the simulator publishes. Key 3 is supported only where the simulator itself accepts the general request. | *"We should not guess what parameters are available."* |
| **D-5** | The simulator is a **moving target**. Key 3 sits behind a backend seam; today's implementation is the dumb one. | *"I am doing a custom ngspice that will support wildcard OP info save for all devices. Till then, we will go with this 'dumb' approach."* |
| **D-6** | The declutter reaches **only instances that got OP numbers**. Subcircuits and descriptor-less devices are untouched. | selected "Only instances that got OP numbers" |
| **D-7** | Lists **seed from the PDK; the user's file wins** per class. | selected "Seed from the PDK, user file wins" |
| **D-8** | The declutter exists **only while OP info is displayed**. A bit on `annot_show`; `Ctrl-6` clears it with the rest. | *"Declutter is active ONLY when OP info (6 key triggered) is displayed. I thought that was clear."* |

## What D-4 + D-5 forbid, stated so a crew cannot drift into it

A crew implementing key 3 **may not** add a `show` parse, a per-model parameter
catalogue, a probe-and-prune warm-up, or any other scheme that infers which
parameters exist. All of those were measured, and all were rejected. Key 3 lists
**what this run's raw actually holds for the device, and nothing else**, behind
`op_param_set`. A key 3 that looks richer than that is a defect, not an
improvement.

## Still open (non-blocking; recorded as debts, not gates)

* **Q6** — the dump header spelling. Proposed default in the spec §5.1; a `look`
  debt, to be judged on screen.
* **Q10** — whether the RDW is reachable after an ordinary OP+TRAN run. To be
  **verified as the RDW suite's first check**, not assumed either way.

---

## Driver decisions on the three questions that blocked B1 and B2

Taken 2026-09-03 by the driver, not the user, because the spec's rule is *"no
crew starts an item whose question is still open"* and all three are **forced by
rulings the user has already given**. Each is on the owed ledger as a `rule`
debt; the user can overrule any of them and the cost is bounded, because each
names exactly one seam.

### DD-1 — Q4: what the ngspice backend answers for "can you enumerate?"

**Decision: today's `ase::backend::ngspice` answers NO.** The capability is a
plain boolean the backend states about itself; the stock simulator has no
wildcard operating-point save, so it says so, and key 3 falls back to *"what
this run's raw actually holds for this device"* — which is the "dumb approach"
D-5 names. **The capability is never inferred from a probe, a `show` parse or a
successful save**; it is a property of the backend, declared. A backend that
answers YES is promising completeness, and only the user's custom ngspice will
be entitled to.

*Why it is forced:* D-4 forbids guessing what the simulator publishes, and any
scheme that measures the answer is a guess dressed as data. The only honest
"yes" is a declaration.

*What key 3 must therefore say on screen:* when the capability is NO, the dump
states that the list is what the run saved, not everything the device has. A
key 3 that is silent about its own incompleteness reads as a complete list, and
that is the failure D-4 exists to prevent.

### DD-2 — Q3: the lists key on the CLASS; flavor is an override

**Decision: class is the primary key, flavor is an optional narrower entry that
wins when present.** `nfet_01v8_lvt` with no entry of its own uses the `mos`
lists.

*Why it is forced:* the user asked for *"one list per major primitive type (MOS,
capacitor, resistor)"* — that is a class key. But B7's scope dialog offers *this
device flavor only* versus *every device of this broad class*, so the flavor
entry must exist too or half the dialog has nothing to write. Both exist; class
answers when flavor is silent. This also matches the registry, whose `match`
glob already narrows by cell name (§2.1).

### DD-3 — Q8: the settings file is DATA, and is never sourced

**Decision: a line-oriented data file, read by a strict parser that does no
`source`, no `eval`, no `subst`, and no substitution of any kind.** Anything the
parser does not recognise is reported and skipped, never executed.

*Why it is forced:* the user's own requirement is that the file be **shareable
with teammates**. A file that is shared and then sourced is arbitrary code
execution on whoever opens the project — the file's headline feature would be
its vulnerability. Issue 0812 already burned this tree on `subst` and paths.

*Cost, stated:* a `.tcl` extension would let the file be `source`d in one line
and would inherit Tcl's own comment and quoting rules for free. The parser is
maybe forty lines instead. That is the whole price, and it buys a file a user can
accept from a colleague without reading it first.

**⚠ Consequence for B2's Files cell:** the settings file is therefore **not**
`op_param_lists.tcl` as §4.4 proposes. The *implementation* is
`src/op_param_lists.tcl` (Tcl code, shipped, installed); the *settings file* it
reads is `<project>/.xschem/op_param_lists.conf`, with
`~/.xschem/op_param_lists.conf` as the user-global fallback and the project file
winning per class. Two different files; the spec's §4.4 conflates them.

### DD-4 — issue 1280: Delete is a DISPLAY decision, never a SAVE decision

Taken 2026-09-03 by the driver. On the owed ledger as rule debt **1280**; the
user can overrule and the cost is one proc.

Item B2 measured a coupling nobody had specified: `op_annot::_cards_for` emits
one `.save` card per row of a descriptor's `params`, and `op_param_lists::apply`
writes the **annotation** list into `params`. So deleting a parameter from the
on-sheet annotation list would also stop the **deck** saving it — and the
summary list's rows for that parameter would then render permanently blank, on a
schematic, with no report anywhere.

**Decision: Delete removes a parameter from what is DRAWN. It never changes what
the simulator is asked to save.** `apply` writes the **union** of the annotation
and summary lists into `params`, and the display narrows to the annotation list.

*Why it is forced:*

1. **The user's own framing.** The whole feature is a *declutter* — the word is
   the user's — and the button lives in a column described as editing "what gets
   printed and what gets annotated". Nothing the user said asks for a button
   that quietly reduces what a simulation measures.
2. **Invariant I3.** The alternative makes key 2 render blank for a parameter the
   user can still see listed, with nothing on screen explaining why. That is the
   plausible-wrong-answer failure this batch has now hit three times.
3. **Nothing is invented.** Every row of the union was declared either by the
   user or by the PDK, so the union violates no ruling — where a *narrowing*
   would silently destroy data the user never asked to lose.

*Cost, stated:* a user who deletes a row to make the deck smaller does not get a
smaller deck. Saving an operating-point parameter is measured free (spec §3.3),
so the cost is a slightly larger raw and nothing else. If the user later wants a
"stop saving this" control, it is a **separate** control with a separate name,
not an overloaded Delete.

### DD-5 — issue 1282: a DC sweep is rendered, and the window NAMES the analysis

Taken 2026-09-03 by the driver, option (a) of the three the issue lists. On the
owed ledger as rule debt **1282**; the user can overrule.

The seam's allow-list is `{op dc}`, copied deliberately from `update_op()`'s own
guard in `src/save.c`. So a DC sweep is accepted and the window prints its
point-0 numbers — under a heading saying these are the operating-point columns
this run saved, **with the word `dc` nowhere on screen**. Measured: `sim_type =
dc`, `state = ok`, block mentions `dc` zero times.

**Decision: keep rendering it, and add a sentence naming the analysis** —
*"these numbers come from the `dc` analysis at its first point, not from a
standalone operating point."*

*Why not (b), render it silently:* that is defensible only if a `.dc` point 0
**is** an operating point, which it is when the sweep source sits at its nominal
value and is not otherwise. The window cannot tell which, so it must not assert
the stronger reading. This is the same failure as rendering `complete 0`
silently, one state further in.

*Why not (c), refuse it:* that contradicts the seam's allow-list, which was
copied from the C on purpose so that the RDW and the on-sheet annotation agree
about what counts as an operating point. Refusing in the window only would make
the two disagree, which is worse than either answer alone.

*And the same sentence rule applies to `rdw::sim`'s two refusals* (1282 part 2):
"no such simulator" and "a simulator with no operating-point reader" are
different facts with different remedies, and this feature's own obligation is
that different silences get different sentences. **Item B5 is the first thing
that sets `::rdw::sim`, so it must land the split.**

### DD-6 — issue 1285: DD-4 NAMED ONE FIELD WHERE TWO ARE NEEDED

**This corrects DD-4, and the correction is the driver's own error, caught by
item B2a while implementing it.** Taken 2026-09-03; on the owed ledger as rule
debt **1285**.

DD-4 says *"`apply` writes the union of the annotation and summary lists into
`params`, and the display narrows to the annotation list."* **Those two clauses
cannot both be true of one field.** Verified directly in the tree at `825cd3bd`:
`op_annot::text` builds the on-sheet rows by iterating `dict get $d params`
(`src/op_annot.tcl:1742`), and `op_annot::_cards_for` builds the `.save` cards
by iterating **the same list** (`:2816`). One field, two consumers, and DD-4
asks them to differ.

Left as written, DD-4 would ship a Delete button whose visible effect is
**nothing at all**: the deck would keep saving the row (correct) and the sheet
would keep drawing it (the opposite of *declutter*, the word the feature is
named after).

**Decision: take issue 1285's Option 1 — a new descriptor key the display
prefers over `params`.** `op_annot::text` reads that key when it exists and
falls back to `params` when it does not. `apply` writes both: the **union** into
`params` (what the simulator is asked to compute) and the **annotation list**
into the new key (what is drawn).

*Why not Option 2 —* `op_annot::text` calling `op_param_lists::effective`
directly: it needs no new key and gives the narrowing exactly one definition,
but it makes `op_annot.tcl` depend on `op_param_lists.tcl` when the dependency
today runs the other way, and **`op_annot.tcl` is sourced first**. A load-order
inversion to save one dict key is a bad trade.

*Cost, stated:* a descriptor now carries two lists and a PDK author must be told
which is which. The header comment and all three PDK `_procs.tcl` files must say
it in one line: **`params` is what the run computes; the display key is what the
sheet draws.** A PDK that registers only `params` — which is all three of them
today — behaves exactly as it does now.

**The lesson, and it is the driver's own:** DD-4 was reasoned from what the two
lists *mean* and never checked what field the tree actually reads them from.
That is item A7's lesson arriving at the decision layer instead of the code
layer — a ruling about behaviour inherits the shape of the data structure
underneath it, and that structure was built for a different question.

---

## Three decisions taken after item B2a was refuted TWICE on the same two issues

Two independent crews implemented issue **1281** and both **deleted rows the
user had typed**. Two independent crews implemented issue **1277**'s precedence
and both produced an order in which a bare `*` beats a specific pattern — the
filed defect, under its own fix, twice. When two competent attempts fail the
same way, the design is wrong and no third implementation will save it. These
are the driver's design corrections. Each is on the owed ledger.

### DD-7 — issue 1281: Save is a READ-MODIFY-WRITE of one tier's own file

**Decision: writing a tier reads that tier's existing file, changes only the
keys this session actually changed, and writes it back. Every other row is
preserved verbatim, including rows this build does not understand.**

Both failed attempts serialized a **merged model** and tried to tag each row
with the tier it came from. Both lost rows — B2a deleted a user's `class mydiode
diode`; B2a-2 deleted a user's explicit `class nmos mos` because its value
happened to equal the shipped default. The second one is the sharper warning: a
row was destroyed for *agreeing with a default*, which is exactly the row a user
writes down to protect against a default changing.

*Why the new shape cannot fail that way:* **you cannot delete a row you never
parsed into a model.** Provenance stops being a field to get right and becomes a
property of which file you opened. A row this build cannot interpret survives a
save by a build that has never heard of it — which is what "shareable with
teammates" requires when two people are on different versions.

*Cost, stated:* Save must re-read the file it is about to write, so a file
edited by hand between load and save is merged rather than overwritten. That is
the behaviour a user expects from a config file and the opposite of what both
attempts did.

### DD-8 — issue 1277: precedence is FILE ORDER. Nothing is ranked.

**Decision: when two flavor globs both match a cell, the FIRST one in the file
wins. The file says exactly that, and no code anywhere tries to decide which
glob is "narrower".**

Two attempts tried to rank by narrowness and both produced a bare `*` beating a
specific pattern. That is not a coding slip repeated twice — **"narrower" has no
defensible total order over globs.** Is `sky130_fd_pr__*` narrower than
`*nfet_01v8_lvt*`? Neither contains the other; they are two different opinions
about what matters. Any tie-break is a heuristic the user must reverse-engineer
from behaviour, and both attempts also wrote *"narrowest matching glob wins"*
into the settings file while implementing something else — a file lying to its
own reader.

*Why file order is the right answer here specifically:* **the user already has a
reordering UI.** The spec's own button column gives every list Up and Down. So
precedence becomes something the user sets by dragging, visible in the file in
the order they set it, rather than a rule they have to infer. The feature that
was going to explain the heuristic instead removes the need for one.

*Cost, stated:* a user who wants a specific pattern to win must put it above the
general one. The file's header says so in one line, and because it is file
order, the file itself is the documentation.

⚠ **The class field on a flavor entry is still required** — that half of 1277
stands. `effective <class>` must not scan another class's flavors. Only the
*ranking* is deleted. And the key must be a **canonical string**, never an
uncanonicalised two-element list used as an array index, which is how B2a-2 lost
entries on a round trip.

### DD-9 — issue 1289: `derived` rows read the RUN, not the sheet

**Decision: issue 1289's option 2.** `op_annot::text` evaluates its `vars` over
`params` (what the run computed) and *displays* over the narrowed key (what the
sheet draws). A derived row keeps working when its operand is merely hidden.

*Why:* `derived` is already a display-only concept — it appears in no `.save`
card — so its operands naturally come from what was computed, not from what is
drawn. It is the only option under which the sheet never shows a row that cannot
carry a value. Option 3 (hide a derived row whose operands are hidden) is
defensible but makes one Delete silently remove two rows, and the user has not
asked for that.

*Constraint that binds the implementation:* `op_annot::text` runs **per instance
per redraw** from C. It may gain no new `xschem` call and no new raise site
(issue 0447).

### DD-6 AMENDED — the display key's two guarantees must be BUILT, not asserted

B2a-2 measured both of DD-6's written guarantees false. The amendment:

1. **The display key is a SUBSET of `params` by construction**, not by
   assertion: derive it by filtering `params`, so the property cannot be
   violated by any caller. B2a-2's `apply` produced the violation itself and
   `_kind` then raised.
2. **A malformed display key falls back to `params`. It never raises.**
   `op_annot::text` is a draw-time proc; a raise there is a black schematic. A
   key that does not parse as a list is treated as absent.

### DD-10 — item B2b's question: Delete REFUSES to remove the last row

Taken 2026-09-03 by the driver. On the owed ledger; the user can overrule.

B2b asked what happens when the user deletes the **last** row of a device's
annotation list, and offered two answers. **Both are bad, so neither is taken:**

* *the whole OP block vanishes* — which also drops the device out of the
  declutter, because the declutter's gate (ruling D-6) is "instances that got OP
  numbers". So deleting one row would make **more** text appear on the sheet:
  every W/L and pin label the declutter had been hiding comes back at once. The
  user pressed Delete to see less and got more.
* *an emptied list means "no narrowing"* — then Delete on the last row is a
  **silent no-op**, a button that does nothing with no explanation.

**Decision: Delete refuses to remove the last remaining row, and says why** —
*"at least one parameter must stay. To stop showing operating-point values on
this device, turn the annotation off instead."*

*Why:* it keeps the invariant that **an annotated device always has at least one
row**, which is what makes the declutter gate stable and the button's behaviour
predictable. And a user who genuinely wants no OP display for a device already
has two better tools — turning annotation off, or the declutter itself — neither
of which has the side effect of un-hiding everything else.

*Cost, stated:* the list cannot be emptied through the UI. A user who wants that
state is asking for "no annotation on this device", which is a different feature
and does not exist yet; if it is ever wanted it should be its own control, not
an emptied list with a surprising side effect.

### DD-11 — issue 1296: the `version` line belongs to xschem; comments belong to the user

Taken 2026-09-04 by the driver. On the owed ledger; the user can overrule.

Issue 1296 is a genuine collision between two things item B2c was told to do:
DD-7 says preserve every row verbatim, and DD-8's whole argument is *"because
it is file order, the file itself is the documentation."* If an existing file is
decorated nowhere, then the precedence sentence is true only of files this build
created from scratch — and every file is pre-existing from its second save on.

**The two halves are not equally important, and only one is a correctness bug.**

**Half one, a real defect: a v1 file keeps `version 1` while gaining v2 rows.**
The next `load_conf` then reports the version mismatch and skips rows this build
just wrote. The file becomes self-refuting on disk. **Decision: the `version`
line is xschem's own field, not user content, and is rewritten to the version
of the grammar actually being written.** A machine field that describes the
grammar is not a thing the user authored, and DD-7's promise is about *the rows
they wrote*, not about a stamp that says which dialect those rows are in.

**Half two, documentation: an existing file never gains the precedence
sentence.** **Decision: leave it.** xschem refreshes only the header block it
can recognise as its own; anything else in the file is left alone, including a
hand-written header. A user who wants the current explanatory header can delete
the file's header lines and save, or read the shipped documentation. **Silently
rewriting prose a person typed is worse than an out-of-date comment** — and this
batch has now reverted three items for deleting things the user wrote.

*So the rule, in one line:* **xschem owns the `version` line. The user owns
every comment.** Where the two conflict, correctness wins on the machine field
and the user wins on the prose.

*Cost, stated:* a long-lived settings file will carry the header sentence of
whatever xschem first created it, which may describe an older precedence rule.
That is why the version line matters: it is the field that tells a reader —
human or machine — which rules the file's rows are written under.

### DD-5 CORRECTED — the driver's specimen sentence was refuted by a measurement

Item B2d implemented DD-5 and **declined the specimen wording the driver put in
the ruling**, on a measurement. It was right to.

DD-5's specimen said the numbers *"come from the `$sty` analysis at its first
point"*. But `src/save.c:1073` and `:1120` both carry

```c
if(raw->npoints[...] > 1 && !strcmp(sim_type, "op")) sim_type = "dc";
```

so **the reader renames a multi-point `Operating Point` plot to `dc`**. Measured
on this binary: a three-point `Plotname: Operating Point` raw answers
`xschem raw sim_type` = `dc`. The specimen would therefore have told a user who
ran *nothing but an operating point* that they had run a sweep — a new false
statement, introduced by the sentence written to remove one.

**The shipped wording, accepted as written:**

> These numbers come from the first point of results xschem reports as a `dc`
> analysis, not as a standalone operating point. A `dc` sweep's first point is
> one sweep step, and xschem also reports a multi-point operating point as `dc`.

It is longer than the specimen and that is the price of being true: it names
what the loaded results **call themselves** rather than what the user ran,
because the window cannot tell those apart and must not pretend to.

**And the measurement independently justifies DD-5's rejection of option (c).**
Refusing `dc` outright would refuse a *real* operating point — the three-point
one. `test_op_annot`'s row T26 is exactly that case and must keep publishing, so
the C is not moving either. Option (c) was wrong on its own terms, not merely
forbidden by the ruling.

*Recorded as a `look` debt: the sentence is on screen and the user should read
it.* The driver considered tightening it and did not, because every shorter
phrasing tried either dropped the multi-point caveat — which is the half that
makes it true — or re-asserted what the user ran.

### DD-12 — issue 1308: Escape ends the MODE, on the window, and never closes it

Taken 2026-09-04 by the driver, immediately after item B4-3 landed and before
item B5 was dispatched. On the owed ledger; the user can overrule.

Issue 1306's fix let the Results window **keep the keyboard** when the user
clicks its text pane — which is the whole point of the feature, because the
user's stated purpose for the window is selecting dumps and pasting them into
design-review documents. The consequence, measured the same day: the command
mode's `1`/`2`/`3`/`4` and `<Key-Escape>` are bound on the **canvas**, so once
the pane held the keyboard the mode's documented exit was **dead**.

B4-3 asked whether the window should hold the keyboard and gain its own Escape,
or never take the keyboard at all.

**Decision: the window holds the keyboard AND gains its own Escape.** The
alternative is not really available — a pane that cannot hold the keyboard
cannot be copied from with the keyboard, which is the requirement the window
exists to satisfy. Escape is bound on the toplevel, so it fires wherever focus
sits inside the window, including the text pane, which is the case that matters.

**And Escape ends the mode WITHOUT closing the window.** That asymmetry is the
part worth arguing, because Escape closes a dialog in many applications:

* This is not a dialog. It holds an hour of dumps, and those dumps **are** the
  artifact the feature exists to produce. `rdw::close`'s own comment already
  records that losing them to a stray click on the window's X is the worse
  failure; a stray Escape is the same accident with a different finger.
* So Escape ends a mode when one is running and **does nothing otherwise** —
  never a destructive default. Row E5 holds that, and sabotaging it (making
  Escape also close) reds row E4 alone.

*Cost, stated:* a user who expects Escape to dismiss the window will press it
and see nothing happen. The window has its own close control, and the dumps are
worth more than the keystroke.

### DD-13 — issue 1312: THREE fields, because `seed` was the reader I never checked

**This corrects DD-6, which corrected DD-4. That is the same mistake three
times, and the pattern is the point.** Taken 2026-09-04 after item B5 was
refuted by it. On the owed ledger as rule debt **1314**.

**What B5 measured.** `op_param_lists::apply` writes the annotation+summary
union into the descriptor's `params`, and `op_param_lists::seed` reads *"the
PDK's own list"* back out of **that same field**, through `_params`
(`src/op_param_lists.tcl:700`). So after the first `apply`, the seed is no
longer the PDK's declaration — it is whatever the last apply computed:

```
seed0        = {id ids 0} {gm gm 1} {gds gds 1}
              # the user reorders the ANNOTATION list only
apply
seed1        = {gm gm 1} {id ids 0} {gds gds 1}
eff summary1 = {gm gm 1} {id ids 0} {gds gds 1}   <- the list nobody owns, moved
```

And with the button column owning **both** lists, two broad-scope Deletes strip
the parameter from `params` **and** from the seed, and from the sibling type —
so the `.save` card goes with it, and Add cannot put it back. That is a direct
violation of DD-4/DD-6, whose whole content is that Delete never changes what the
simulator computes.

`_save_set`'s in-code claim that the union *"can only ever be a SUPERSET, so no
PDK row is ever lost"* is true **only while one of the two lists is unowned.**
The button column is precisely the thing that owns both. The claim was correct
when written and the feature grew out from under it.

**Decision: issue 1312's option (a). The descriptor carries THREE lists.**

| field | means | written by |
|---|---|---|
| the **declaration** key | what the PDK declared | `op_annot::register` **only** |
| `params` | what the run computes | `apply` (the union) |
| the **display** key | what the sheet draws | `apply` (the annotation list) |

`_params` — and therefore `seed` — reads the **declaration**, so the seed means
what its name says and no edit can destroy it.

*Rejected, both from the issue:* (b) refusing to overwrite `params` when only the
ORDER differs — it would freeze the drawn order, which is what Up/Down exist to
change; (c) caching the first `_params` answer — a cache that outlives a user's
own `op_annot::register` breaks invariant I5.

### ⚠ THE PATTERN, STATED PLAINLY, BECAUSE IT IS MINE

* **DD-4** said `apply` writes the union into `params` and the display narrows.
  One field, two meanings. Refuted: `op_annot::text` and `_cards_for` read the
  same list.
* **DD-6** split off a display key. Two fields. Refuted: `seed`/`_params` reads
  `params` too, and it is a **third** consumer with a **third** meaning.
* **DD-13** splits off the declaration. Three fields.

Each time I reasoned about what the lists *mean* and did not enumerate **every
reader of the field** before ruling. DD-6 even says the lesson out loud — *"a
ruling about behaviour inherits the shape of the data structure underneath it"* —
and I then made the same error one layer down.

**The rule for any future ruling that assigns meaning to a stored field: grep
every reader FIRST, list them, and say what each one will now see.** Two of the
three refutations here cost a full crew run.

### DD-14 — issue 1315: the `dict unset d declared` line is PART of the recipe

Taken 2026-09-04 after item B2e landed. On the owed ledger; the user can
overrule.

Item B2e made `op_annot::register` **preserve** an existing declaration, which
is what stops the parameter-list editor's Save from destroying the PDK's own
list (issue 1312). B2e also documented a one-line escape hatch — but ~40 lines
*below* the recovery recipe the three PDK files print, so the copy-paste path
was still wrong.

**Measured, both spellings, on this binary:**

```
SEED0           = {id ids 0} {gm gm 1}
SEED_NO_UNSET   = {id ids 0} {gm gm 1}                  <- the recipe as printed
SEED_WITH_UNSET = {id ids 0} {gm gm 1} {cgg cgg 1}
```

So the recipe as printed changed what the run computes and what the sheet draws
and left `seed` still answering the shipped list — meaning a later Reset would
restore *our* set, not the user's, with nothing said anywhere.

**Decision: `dict unset d declared` goes IN the recipe, in all three PDK files,
with the reason beside it.** A recipe a user copy-pastes must be correct as
written; a caveat forty lines away is not part of what gets pasted.

*Why not make `register` always redeclare:* the editor's Save path re-registers
too, so always-redeclaring would let an ordinary Delete destroy the PDK's
declaration again — the exact defect that refuted item B5 and cost a full crew
run. Preserve-by-default is the safe direction, and the explicit unset is how a
user says *"forget the old declaration, this one is mine."*

*Applying the rule DD-13 wrote down:* every reader and writer of the key was
enumerated before this was decided — `op_annot::register` (writes,
preserve-if-present), `op_param_lists::_key_state`, `_declared_rows`,
`_merge_declared`, and `_params`/`seed`. The unset changes what each one sees to
the user's new list, which is what a user re-declaring wants.

### DD-15 — issue 1326: a duplicate label is refused AT THE DECLARATION

Taken 2026-09-04. Issue 1326's option **(c)**. On the owed ledger.

When a PDK declares two parameters sharing a label, the store's dedupe rule
(*"a second entry for a label replaces the earlier one in place"*) means the
declaration is asking for something the store cannot represent — and a later
Delete or Up then drops **both** rows and a `.save` card with it.

**Decision: `op_annot::register` refuses a declaration carrying a duplicate
label, once, where the duplicate is introduced.**

*Why not (a), refuse the Delete:* it leaves the broken declaration live and
breaks a button instead — a button that refuses **every** press for that class,
with a sentence about a row the user did not touch. That punishes the wrong
person, repeatedly, for somebody else's error.

*Why not (d), leave it:* all three shipped PDKs declare distinct labels, so it
is latent today and reachable only through invariant I5 — which is to say,
reachable exactly by the user writing their own registration in an rc, which is
the case this feature exists to serve.

*(b) is impossible in this store and 1323's own recommendation was refuted for
that reason.*

**The principle, which this batch has now applied four times:** reject an
ambiguity at the door where it is created, not at the far end where its
consequences show up. It is the same rule as DD-3 (the settings file is data,
parsed strictly), the strict reader, and issue 1294's *"both doors must reach
the same verdict."* A label is what identifies a row **to the user** and to the
store's dedupe; two rows sharing one are ambiguous by construction, and no
downstream code can repair that.

*Cost, stated:* a PDK author — or a user's own rc — gets an error at load time
instead of silence. That is the point. `src/op_annot.tcl` was a forbidden file
for most of this batch, but item B2e already edited `register` under DD-13, so
the door is open and this belongs behind it.

### DD-16 — a cross-sheet edit is allowed, and named only when it surprises

Taken 2026-09-04, answering item B5-a's second question.

Item B5-a fixed issue 1322 so a block now carries the subject it was dumped
about. The remaining question: when the user edits a block dumped from sheet A
while sheet B is open, should it work, work-and-say-so, or be refused?

**Decision: it works, and the status line names the source sheet ONLY when that
sheet is not the one currently open.**

*Why not refuse:* the three lists are **class- and flavor-level settings, not
sheet state**. A block says "this dump was about an nfet of class `mos`", and
editing the `mos` list is a global action that is correct regardless of which
sheet happens to be in front. Refusing would block a legitimate edit for a
reason the user would find arbitrary — and the window deliberately keeps its
dumps across a close (`rdw::close`'s own comment) precisely so they can be
worked with later.

*Why name it conditionally rather than always:* in the common case the source
sheet **is** the open one and saying so is noise on every press. The sentence
earns its place exactly when the two differ, which is the case a user could
otherwise misread — and which, before 1322 was fixed, silently edited the wrong
device.

### 1273 STAYS THE USER'S, AND IS NOT SETTLED HERE

Item B5-a made Save honest about which tier it wrote (issue 1325), which is a
different question from **which directory is "the project"** (issue 1273). That
one has been on the user's queue since item B2 and no driver decision touches
it. Item B5-a's brief said so explicitly and it obeyed. ⚠ Issue **1327** records
that the tier answer is still wrong through a **symlinked** project conf —
`file normalize` does not resolve symlinks — found by B5-a's own adversary and
reproduced before filing.
