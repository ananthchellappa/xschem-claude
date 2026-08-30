# 0938 — a simulator whose path contains a dollar sign can no longer be started

**Status: OPEN. This is a REGRESSION introduced by issue 0937's commit** (the
`Setup > Simulators…` dialog). It is not a pre-existing defect that 0937
uncovered; 0937 caused it. Filed by the S2 write-up agent, who reproduced it
first-hand rather than taking the verification agent's word for it.

**Severity: narrow but real, and the refusal blames the user for something they
did not do.** It bites exactly one shape of path: one whose *expansion succeeds*
and whose *result still contains a `$`* — a PDK root or build directory with a
literal dollar in a folder name. On such a machine a simulator that xschem
started yesterday cannot be started today, and the sentence explaining why is
wrong.

## What was measured

`doc/claude/issues/0933` is the neighbour: a location naming an unknown setting
was refused at registration and honoured at the run, so the list and the run
disagreed about the same entry. 0937 closed that half by teaching
`ase::sim_status` to validate with the new `ase::sim_entry_kind` instead of the
bare `ase::sim_check`. `ase::sim_entry_kind` re-runs the variable expansion:

```tcl
proc ase::sim_entry_kind {path} {
  if {[catch {ase::expand_path $path}]} { return badvar }
  return [ase::sim_check $path]
}
```

**The expansion is not idempotent, and the stored path has already been through
it once.** `ase::sim_register` expands the user's portable form and stores the
*result*, normalised. Substituting that result a second time is a different
question from the one registration asked, and on a path containing a literal `$`
it fails.

Measured on the built `src/xschem`, with `::PDKROOT` pointing at a real
directory whose name contains a dollar, registering the documented portable form
`$::PDKROOT/bin/ngspice`:

```
F4 PDKROOT dir really exists: 1
F4 register rv           = 1
F4 stored path           = /tmp/wu0937/root/p$q/bin/ngspice
F4 entry ok flag         = 1
F4 file is runnable      = 1
F4 OLD validator (sim_check)      -> ''
F4 NEW validator (sim_entry_kind) -> 'badvar'
F4 sim_status ok         = 0
F4 sim_status resolved   = ''
F4 sim_status why        = The location given for the simulator named pdk mentions a setting this session does not know about, so it cannot be turned into a real file name: /tmp/wu0937/root/p$q/bin/ngspice
F4 sim_exe RAISED: ase: The location given for the simulator named pdk mentions a setting this session does not know about, so it cannot be turned into a real file name: /tmp/wu0937/root/p$q/bin/ngspice
```

Registration says the entry is good (`rv = 1`, `ok = 1`), the file really is
runnable, and the validator the shipped code used *before* this change says
there is nothing wrong with it. The new one refuses, `resolved` goes empty, and
`ase::sim_exe` raises. **The path it is complaining about mentions no setting at
all** — the `$q` is a folder name.

## Why no row caught it

The change carries a comment asserting the opposite of what it does:

> Every field `ase::sim_status` answers with — `exe`, `resolved`, `ok` — stays
> byte-identical to what it answered before this proc existed.

That is false: `ok` flips 1 → 0 and `resolved` goes from the path to empty. Row
**R7** in `tests/headless/test_ase_simreg_0931.tcl` cannot see it, because R7
asserts the *list* and the *run* give the same sentence — and after this change
they are wrong **together**. The sabotage pass confirmed the shape from the
other side: variant G-A (revert `sim_status` to the old validator) reddens R7 and
nothing else.

## What is still open — and it is a ruling, not a repair

Two ways out, and they trade against each other. **This is the user's call, not
the crew's**, which is why it is on the ruling queue rather than fixed here:

1. **Revert the one call** in `ase::sim_status` from `ase::sim_entry_kind` back
   to `ase::sim_check`. Kills the regression outright; reopens 0933's
   wrong-sentence half (the list and the run disagree again for an unknown
   setting) and reddens row R7.
2. **Stop re-deriving the reason by substituting twice.** Record the expansion
   outcome at registration — it is a static property of the string and cannot
   change — and keep re-validating only the filesystem facts (`missing`,
   `notfile`, `notexec`) on every call, which is what row **R6** actually
   demands. Strictly better than both, and more work: the entry dict gains a
   field, which is the storage half 0933 already has filed.

A wrong *sentence* in a rare arm (0933) is a smaller harm than a *refusal to run
a working simulator*, so option 1 is the safe immediate revert and option 2 is
the right destination.

## Acceptance rows this needs when it is fixed

None exist yet. A fix must add a row that registers the portable form against a
real directory with a dollar in its name and asserts the simulator still starts
— pinning idempotence directly, which is the property that broke. R7 as written
cannot serve, because it compares two things that fail together.
