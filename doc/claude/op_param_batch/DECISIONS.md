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
