# 0960 — a simulation folder the probe cannot use switches the simulator warnings off for good, and says nothing

**STATUS: OPEN.** Found by item S3a's verification pass, reproduced first-hand by
the write-up before filing. It is the honest half of a fix that landed in the same
item — S3a stopped this state ACCUSING the user's program (issue 0949's category
error), and the price is that it now says nothing at all, permanently.

## What the user sees

Nothing. That is the defect.

Their simulation folder cannot be used by the probe — it is read-only (a shared
project area, a mount that came up `ro`), or something already occupies the name
the probe needs. From then on, every warning the 0948 capability feature exists to
give them is switched off. The genuinely useful one goes with it: a build that
**keeps only the last analysis of a run** will now silently throw away every
analysis but the last, on a run with several in it, and the sentence that would
have warned them is never minted.

There is no message, no degraded-mode notice, nothing in the Simulators window,
and nothing that would let them find out — on this Run or any Run for the rest of
the session.

## Measured

Both shapes, on the built `src/xschem`, with the real `/usr/local/bin/ngspice`
registered and selected. `caps` is what `ase::sim_capabilities` answered, `said`
is every sentence that reached the Command window:

```
read-only simulation folder:
  RO press 1 : caps={known 0 unmeasured noplace} kind='' said={}
  RO press 2 : caps={known 0 unmeasured noplace} kind='' said={}
  RO press 3 : caps={known 0 unmeasured noplace} kind='' said={}
  RO writable? 0

a writable folder in which .ase_probe is an ordinary FILE:
  BL press 1 : caps={known 0 unmeasured noplace} kind='' said={}
  BL press 2 : caps={known 0 unmeasured noplace} kind='' said={}
  BL press 3 : caps={known 0 unmeasured noplace} kind='' said={}
  BL writable? 1
```

The second shape is worth its own line: the folder is perfectly writable and the
user has done nothing wrong. One stray file — a leftover from a crashed run, a
`.ase_probe` that was a directory yesterday — disables the feature for good.

## Mechanism

`ase::sim_capabilities` returns `{known 0 unmeasured noplace}` when
`ase::cap_workdir` cannot hand back a place to work, and `ase::cap_report`'s first
arm speaks only for `unmeasured timeout`:

```tcl
if {![dict exists $c known] || [dict get $c known] == 0} {
  if {[dict exists $c unmeasured] && [dict get $c unmeasured] eq {timeout}} {
    ase::sim_say cap_no_answer $backend $path [dict get $c secs]
    return cap_no_answer
  }
  return {}
}
```

Silence there is deliberate and, for the other `known 0` reasons, right: a backend
with no probe, or a resolver that already refused and said why, has nothing to add.
`noplace` is different from all of those, because **something the user could fix is
in the way**, and only this code knows what it is.

Note the section's own contract, written two screens above, for the sibling arm:
"A program that produced NO results at all on the probe's tiny test circuit is
reported whatever the run looks like: **never a silent failure**."

## Fix shape, none of it chosen

1. **Give `noplace` its own sentence**, in the plain-English register the other
   three use, naming the folder and what is in the way — a read-only folder and an
   occupied name are different sentences, and the code already knows which it hit.
   Say it **once per folder**, not once per Run, or it becomes a nag.
2. **Fall back to a scratch place** the tree can always write into (`$::env(TMPDIR)`,
   the user's config dir) and measure there anyway. The measurement is about the
   *program*, not the folder, so nothing about it needs the user's simulation
   folder — this makes the state unreachable rather than merely audible. It changes
   where a probe writes, which S4 should be told about.
3. Both: fall back, and say so quietly the first time.

## Acceptance

* A user whose simulation folder cannot be used either still gets the warnings, or
  is told plainly why they have stopped — once, not on every Run.
* The "keeps only the last analysis" warning in particular is never silently
  switched off, because that one costs the user their results.
