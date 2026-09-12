# Stage 4 — The netlist permits

**Five commits, not the planned one.**

| commit | issue | subject |
|---|---|---|
| `59513850` | **1421** | the preflight suite was never in T1, and 21 more ASE suites are not either |
| `30a7be00` | **1422** | the tokens `netlist_map` throws away are exactly the ones a precondition needs |
| `4adfda9a` | **1423** | preconditions become filters, not error messages |
| `99224bc0` | **1424** | a precondition that destroys the run is a refusal |
| *this one* | **1425** | the precondition is said before the run, with its remedy |

**Floors:** `test_ase_preflight` 125 → **152**. Twenty-four sabotages. T1 solo at zero on every
commit, and from `59513850` onward T1 is **62 cases** and includes the preflight suite at all.

---

## What the stage was for

ngspice's answer to a noise analysis with no AC input source is `E_NOACINPUT`, **after** the run, in
a log the user has to go and read. The same fact is in the netlist text before anything starts. The
stage turns preconditions from error messages into filters.

---

## What Stage 4 learned that binds later stages

**A false refusal is worse than a missed one, and it needs a mechanism, not a resolution.**
`netlist_facts` answers `exact 0` — it cannot see inside an `.include` — so every `blocked` verdict
on a static pass is demoted to `caution` **in one place**, in the evaluator rather than in each
predicate. A predicate author writes the honest verdict and the evaluator lowers it. Thirteen
authors each remembering the same caveat is not a design.

**Three predicates were nearly false refusals, and each was caught by asking what the feature is
for.** The CIDER/KLU pair fired on the device alone — and CIDER decks are the only reason anyone
builds ngspice with CIDER. `sweep_target` nearly required the target to be in the deck — which would
refuse `temp`, the cheapest genuine ADE-beater in the design. And an unimplemented precondition id
nearly blocked a run, when it is a fact about the registry rather than about the user's circuit.

**An ordering row whose fixtures never disagree is a row that cannot fail.** Swapping `fatal` and
`blocked` in `precheck_worst` passed the entire suite, because every fixture in it yielded findings
of exactly one severity — and with a lone `fatal`, any ordering returns `fatal`. The same shape
appeared again in PF225d, whose fixture had **no finding at all** and so could not tell *"refuses
fatal"* from *"refuses anything"*; that sabotage was caught by two rows written for something else.

**Write the unreachable thing down instead of writing it.** The DISTO save-list rule promotes
`saves_resolve` to `fatal` *when `disto` is enabled*, and `disto` is probe-only until Stage 6 — an
enabled `disto` row is refused by issue 1401's block long before a precondition is consulted. Same
for `noise` and `sp`. Unreachable code with an unreachable test is worse than a named gap.

**A dialog may not have side effects because a user opened it.** The plan asks for the precondition
banner under the form; `netlist_facts` needs netlist **text**, and producing it means `ase::netlist`,
which loads designs and writes artifacts. The findings are surfaced at the gate instead — the one
place the netlist already exists — which meets the plan's own stated goal of *before the run instead
of after it*.

**And the harness audit that fell out of the first commit is the widest finding of the stage.** Of
**29** `test_ase_*` suites, **seven** were in T1. The other twenty-one all print `RESULT:` and no
`OVERALL:` — one cause, twenty-one times, including `test_ase_cosim` at 341 checks. Any statement of
the form *"T1 at zero"* covers **eight of twenty-nine** ASE suites. Issue 1421 carries the list.
