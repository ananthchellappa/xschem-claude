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
