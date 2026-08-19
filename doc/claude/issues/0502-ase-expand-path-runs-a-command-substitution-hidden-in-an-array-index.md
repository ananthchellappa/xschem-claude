# 0502 — `ase::expand_path` runs a command substitution hidden in an array index, so opening a state file can execute arbitrary commands

**Status:** OPEN. Measured on branch `fluid-editing` at `d0eb835d` (casemode batch item 6),
Tcl 8.6.14. Pre-existing — **not** introduced by item 6.
**Area:** `ase::expand_path` (`src/ase.tcl:174`) and its three call sites in the deck
renderer (`src/ase.tcl:3271` `.include`, `:3274` `.lib`, `:3327` `pre_commands`).
**Found:** 2026-08-17 by the casemode batch item-6 crew, while fixing the *same* defect
in its own `exe`-field expansion (`sim_profile_exe_path`). Recorded in
`doc/claude/specs/simulator_profiles.md` §5, in a warning comment at
`ase::expand_path`'s own definition, and in
`doc/claude/casemode_batch/receipts/06-simulator-profiles.md` §5. Filed by the closer
because it is a **code-execution** surface in another item's code, which no receipt
should absorb.

---

## What

`ase::expand_path` expands `$VAR` references in **model / include / pre-command paths
taken out of an ASE-L state file**:

```tcl
proc ase::expand_path {p} {
  if {[catch {uplevel #0 [list subst -nocommands -nobackslashes $p]} out]} { ... }
```

`-nocommands` is doing the job it looks like it is doing only at the top level. It does
**not** stop a `[...]` that sits inside the **array index** of a variable reference —
Tcl parses the index of `$A(...)` itself, and command substitution inside it still runs.
Measured, twice, independently (item 6's crew and the closer):

```tcl
set ::RAN 0
subst -nocommands -nobackslashes {$A([set ::RAN 1])/x}
# -> error "can't read \"A(1)\": no such variable"   ... and ::RAN is now 1
```

So a state file carrying a model path of the form

```
$env([exec touch /tmp/PWNED])/models
```

runs that command when the deck is rendered — and it runs it even though the expansion
then *fails*, because the side effect happens during parsing. The reachable route is a
state file (`.state`) a user opens, i.e. a file that arrives by email, git or a shared
PDK area and is not thought of as executable.

## Why item 6 did not fix it

Item 6 hit the identical defect in its own `exe` field, and closed it there by dropping
`subst` entirely: `::sim_profile_expand_vars` (`src/xschem.tcl`) expands
`$name`, `${name}` and `$name(index)` through `set` and **refuses** an index containing
`[`, `]`, `$` or a backslash (checks `CS157l`, `CS157n`). It deliberately did **not**
re-point `ase::expand_path` at it:

- model / include / `pre_commands` paths are **other items'** surface (7, 8, 13 and the
  cosim work), with committed golden decks behind them;
- narrowing what a path may contain is a **behaviour change** that wants its own
  measurement — `$sub(x)` shapes, `~`, Windows backslashes and the "unknown variable is
  a clean error" contract at `:174` all need re-checking against those goldens;
- item 6's audit contract was an empty diff, and a deck-renderer change cannot promise
  one without that measurement.

## Suggested fix

Swap the body for `::sim_profile_expand_vars` (already written, already sabotage-covered)
and keep `expand_path`'s existing error wrapper so an unset variable still reports
`ase: cannot expand model path '...'`. Then re-run the deck goldens:
`test_ase_cosim`, `test_ase_final`, `test_ase_final_gf180`, `test_gf180_ase_defaults`,
`test_cosim_golden_e2e`, plus `test_ase_core`/`test_ase_persist`. Add a check that a
`$env([...])` index is **refused** rather than executed, and one that an ordinary
`$::M/models` path still expands.

## Not affected

`library_defs_expand_path` (`src/library_defs.tcl:23`) does its own `regexp`/`regsub`
expansion of `${VAR}` and never calls `subst`, so the same shape is not reachable there.
