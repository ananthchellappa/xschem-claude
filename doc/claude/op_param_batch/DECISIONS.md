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
