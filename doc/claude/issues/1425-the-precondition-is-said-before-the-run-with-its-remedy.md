# 1425 — the precondition is said before the run, with its remedy

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C5** of Stage 4 of `doc/claude/ase_analyses_batch/` — the last one.

## The whole point of the stage, in four lines of output

ngspice's own answer to a noise analysis with no AC input source is `E_NOACINPUT`, **after** the
run, in a log the user has to go and read. The same fact is knowable from the netlist text **before
anything starts** — and it comes with the remedy attached:

```
ase: the ac analysis: this circuit has no AC source (read from the netlist text,
     which cannot see inside an .include). Fix: put `ac 1` on the input source
     (any magnitude will do)
```

`ase::preflight_gate` now emits every non-`fatal` precheck finding before the run.

⚠ **Advice, not a refusal.** Nothing here stops the run; the gate still returns `{}`. A `caution` is
the user's call by definition — they may know something the netlist text cannot show, which is
exactly why a static pass demotes `blocked` to `caution` in the first place.

⚠ **And it sits above the `ase_preflight` escape.** That flag turns off a **refusal**; it is not a
request to be told less about a circuit. A user who has switched off the save-list check has said
*"let me run this anyway"*, not *"stop telling me things I can act on"*.

## Where the banner is not

The plan asks for this as a **banner under the form**, in the Choose Analyses dialog. It is not
there, and the reason is structural rather than a shortcut: `ase::netlist_facts` needs netlist
**text**, and the dialog has none. Producing it means calling `ase::netlist`, which loads designs
and writes artifacts — a side effect no dialog may have merely because a user opened it.

So the findings are surfaced at the one place the netlist already exists: the gate, immediately
before the run starts. That satisfies the plan's own stated goal — *"offered **before** the run
instead of after it"* — and the dialog banner is deferred to Stage 6, which is where the grid work
lives and where a cached netlist artifact can be read without generating one.

## Also deferred, and named rather than faked

**The DISTO save-list rule is unreachable today.** It promotes `saves_resolve` to `fatal` *when
`disto` is enabled* — and `disto` is one of the seven probe-only types, so an enabled `disto` row is
refused by issue 1401's block long before any precondition is consulted. Writing the rule now would
be unreachable code with an unreachable test, which is the same reasoning that kept `noise`,
`disto` and `sp` out of the `needs` declarations in issue 1423. It lands in Stage 6 with the type.

## Suites

`test_ase_preflight.tcl` **149 → 152** (section **PF226**). Four sabotages.
