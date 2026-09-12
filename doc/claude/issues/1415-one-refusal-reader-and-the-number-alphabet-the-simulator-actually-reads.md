# 1415 — one refusal reader, and the number alphabet the simulator actually reads

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C2** of Stage 3 of `doc/claude/ase_analyses_batch/`.

## What ships

`ase::analysis_emit_check {sim row}` — **every** offence that stops a row reaching a deck, in
order, as `{token field sentence}`. `ase::analysis_emit_msg` — the clauses. `ase::si_parse` — a
number read the way the simulator will read it, with the adapter's alphabet arriving through a new
optional `si_suffixes` hook. `ase::preflight_gate` gains the check **above** the `ase_preflight`
escape.

## Three things measured, and two of them correct the plan

Every value was measured with a **value harness** (`v1 in 0 dc <s>` / `op` / `print v(in)`) against
`/usr/bin/ngspice` — not read from a manual, and **not** taken from a frequency harness, which
collapses an out-of-range value to ngspice's default and announces it.

| input | measured | note |
|---|---|---|
| `20u` | 2.000000e-05 | |
| `20mil` | 5.080000e-04 | **`mil` is a thousandth of an inch, not a thousandth** — a factor of ~39 |
| `1a` | 1.000000e-18 | atto is real, and in xschem's own parser too |
| **`1M`** | **1.000000e-03**, with **zero** warning or error lines | |
| **`1x`** | **1.000000e+00** — the suffix is **ignored** | xschem's `atof_spice` reads it as **1e6** |

⚠ **`M` is milli and ngspice says nothing about it.** Users who write `1M` mean *Mega*; measured,
they get a thousandth, **silently**. Nine orders of magnitude, and ASE-L is the only place it can be
said — so `si_parse` warns on it and ngspice does not. *(The plan said "with ngspice's own warning";
there is none.)*

⚠ **`x` is deliberately absent from the table, and its absence is measured.** The same schematic
value means **1e6 to xschem's own C parser** (under the literal comment `/* Xyce extension */`) and
**1.0 to ngspice**. Putting `x` in the adapter's table would make ASE-L agree with xschem and
disagree with the simulator it is driving.

## The rules that are not obvious

⚠ **A backend that declared no table gets NO numeric opinion** — `si_parse` answers `ok` with no
value, never `bad`. Refusing text there would be a claim about a simulator ASE-L has never seen, and
there are real ones whose parameters are not numbers at all (a Xyce `.TRAN {tstep}` carries a braced
expression and is legal). Same house rule as every other optional hook: absent means *not measured*,
never *no*.

⚠ **The escape hatch does not reach this check.** `set ase_preflight 0` is a real lever for the
netlist scanner — a user who knows their netlist better than it does can switch it off and run.
There is nothing for it to be right about here: a row with no value for a required slot cannot be
emitted by **any** spelling, so forcing it produces exactly the silent nothing this stage deletes.
⚠ **Without that leg row EK3 is vacuous**, because `ase_preflight` defaults to 1 and no other row
sets it — a gate placed *below* the escape behaves identically until someone does.

⚠ **All offences, not the first.** A validator that stops at the first makes the user press OK once
per mistake, and each press re-renders the form.

⚠ **The clause carries no frame.** `ase::analysis_emit_msg` returns a bare clause with no `ase:` and
no verdict; the frame is composed once, at the gate. That is issue 1404's split, and row **EK4**
asserts the **shape** — a row checking two substrings of the finished sentence would stay green when
an adapter composed the whole thing in ASE-L's voice.

⚠ **Every optional-hook resolve sits inside a `catch`.** Measured in source: `ase::backend_hook`
**raises** both for an unknown hook and for an unknown simulator; `ase::analysis_types` survives only
because it wraps the lookup in its own catch. A call site written to *"it falls back"* raises instead
of answering — and this one runs on the Run path.

## Two expectations of mine that were wrong

- **`20u` computes to `1.9999999999999998e-5`**, while `0.02m` is exactly `2e-5` — the same
  quantity, two strings, because 20 × 1e-6 is not representable. A row comparing the rendered string
  asserts IEEE double formatting rather than the suffix table, and breaks on a value nobody changed.
  The SI rows compare **numbers as numbers**, within a relative epsilon.
- **`ase_preflight` is already set** when EK3 runs, so the row now asserts the restore is *faithful*
  rather than assuming the variable was unset.

## Verification

`test_ase_core` **298 → 309** (sections **EK** and **SI**).

⚠ **EK6 is the corpus invariant and it belongs with this commit** — C2 is the one that could make a
shipped bench unrunnable at the gate, so the row that would notice lands with it: every **enabled**
analysis row of every tracked `.state` file passes the check clean.

**Seven sabotage passes:** the gate moved below the escape (EK3); only the first offence reported
(EK2); the adapter clause grown to carry ASE-L's frame (EK1, EK4); `mil` read as milli (SI2); the
atto entry dropped (SI2); a hookless backend given a numeric opinion (SI5); no warning on the
capital `M` (SI3).

## Related

* **1414** — the slot grammar this validates against.
* **1404** — the frame/clause split.
* **1401** — the unrenderable refusal this sits beside in the gate.
