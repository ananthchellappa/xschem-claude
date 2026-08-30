# 0938 — a simulator whose path contains a dollar sign can no longer be started

**Status: FIXED 2026-08-29 (item S2a), by option 2 below plus one guard the
original filing did not know it needed.** The reproduction, the mechanism and
the rejected alternative are kept verbatim below, because the trade they
describe is still the user's to ratify — see "What shipped, and what was
rejected". **This is a REGRESSION introduced by issue 0937's commit** (the
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

## What shipped, and what was rejected

**"Apply section 7" has no referent.** The S2a item brief directed the
implementer to "apply section 7". At the moment that brief was written this file
had five headings and not one of them was numbered; `grep -rn "section 7" doc/claude/` returns exactly one hit, in an
unrelated 0807 patch file. The brief's own gloss — *"record the substitution
result at REGISTRATION"* — is **option 2 above**, and option 2 is the only one
of the two that keeps row R7 green. That is what was implemented. Recorded here
so the next reader does not go looking for a section that never existed.

**SHIPPED — option 2, and it is two guards, not one.**

1. `ase::sim_register` works the answer about the setting out **once** and
   records it on the entry as `varok`. `ase::sim_entry_kind` now takes the
   ENTRY, reads that recorded answer, and never substitutes anything. The
   filesystem facts (`missing`, `notfile`, `notexec`) are still worked out
   fresh on every call, which is what row R6 demands and what row R14 now
   pins from the other side.
2. **A location that already names a real file is a file name, not a
   template.** When the substitution fails and `file exists` says there is a
   program sitting at that location, registration takes it as the file name it
   is and normalises it. This guard can only ever turn a refusal into a run: it
   fires exactly where the entry was about to be recorded unusable, and it
   defers to the filesystem guards, so a folder is still `notfile` and a
   location naming a setting nobody set still gets the sentence it always got.

**Guard 2 is not optional, and this file did not record why.** Option 2 as
originally written — record the verdict in the in-memory entry — fixes the live
session and leaves **every saved entry dead at the next start**. Measured:
`ase::sim_write_conf` saves the line

```
ase::sim_register pdk {/tmp/m0938/root/p$q/bin/ngspice} -args {} -backend ngspice
```

— the setting is already substituted away and the literal dollar is what is
written down. At the next start that line goes back through
`ase::sim_register`, whose **own** substitution then fails, and the entry comes
back with `ok 0` in a session where `PDKROOT` is not even set:

```
J3 entry after restart      = ... path {/tmp/m0938/root/p$q/bin/ngspice} ... ok 0
J4 file still runnable      = 1
J6 sim_status ok            = 0
J7 THE RUN after restart    = rc 1
```

Guard 2 is what makes that line read back correctly, with no change to the
saved-list format, no new option on `ase::sim_register`, and no migration. It
also closes **issue 0945** for free — a user who types the real absolute path of
their program, dollar sign and all, was refused at the door by the same arm.

**REJECTED, with the measured reason for each.**

* **Option 1, reverting the one validator call.** Kills the regression today and
  reopens 0933's wrong-sentence half; reddens row R7. Rejected because a wrong
  sentence and a dead run are not the only two choices on the table — option 2
  gives up neither.
* **Save the form the user typed instead of the resolved one.** The typed form
  can be RELATIVE, and re-normalising it at the next start against a different
  working directory is the `cd`-then-normalise defect `ase::sim_register`'s own
  normalisation comment exists to prevent.
* **Mark the saved line "already resolved" by escaping the dollar.** Measured
  impossible: `subst -nocommands -nobackslashes {/a/p\$q/x}` still raises
  `can't read "q": no such variable`, because `-nobackslashes` disables
  backslash processing without disabling the variable reference. A marker would
  need a new option on `ase::sim_register` and a change to the saved format, and
  it still would not fix the literal-typed arm (0945).
* **Changing `ase::expand_path` itself.** Model files, `.include` and `.lib`
  lines all depend on it. Out of scope and far wider blast radius.

## What is left — and this section had the scope wrong

An earlier draft of this section said the remainder was "after a restart, an
entry whose dollar-bearing program has since been **deleted**". **Both
qualifiers were wrong, and the write-up agent measured that before publishing
it.** No restart is needed and nothing has to be deleted: a **typo** is enough,
on the first gesture, in the live session.

```
A1 the location typed   = /tmp/wu0946/root/p$q/bin/ngspce
A2 does it exist        = 0
A7 the list's problem   = The location given for the simulator named typo mentions a setting
                          this session does not know about ... /tmp/wu0946/root/p$q/bin/ngspce
```

The identical typo one folder over, with no dollar sign in the path, is told the
truth ("There is no file at …. Check that you typed the location correctly").
That is filed as **0946**, with the corrected scope and three options. What this
repair actually did to that arm is **narrow** it: the *working* program at a
dollar-bearing path used to get the same sentence, and now only a location where
nothing is there does.

A second remainder, which is this repair's own doing and was not written down
anywhere until the write-up pass measured it: recording the answer about the
setting **freezes** it, and unlike the filesystem facts that answer *can* change
under a live entry. Add the portable form while its setting is unset — an entry
the registry deliberately keeps and reports — then set the setting, and the list
still says the session does not know about it, which by then is false. The
shipped-before code refused that entry too, with a different wrong sentence
("There is no file at `$::PDK_ROOT/bin/ngspice`"), so this is a wording trade
rather than a behaviour regression; and adding the entry again recovers it
completely, which no sentence mentions. That is **0947**.

Both of them, and the restart case the earlier draft described, lean on the same
unfixed thing: issue **0933**'s storage half. The saved list and the stored entry
keep only one string, so nothing downstream can tell what the user typed from
what it resolved to. Fixing that half closes 0946 and 0947 together, and is on
the user's queue as a "worth fixing next, or leave it?" question.

## One change nobody planned, disclosed here so it is not folklore

`ase::sim_clear` now empties the record of what was said as well as the list of
simulators. It was needed because the recorder accumulates (issue 0941): row R10
says a sentence and reads the record back **without** clearing first, and it
would otherwise have picked up every sentence the earlier rows had said. Putting
the section back to the state it had before anything was registered is the
honest reading of "clear" — sentences already said were about entries that no
longer exist — and it is pinned by a sabotage variant that reddens R10 alone.

Worth one line for the next reader: `ase::sim_said` is public and now
accumulates for a whole session outside the dialog. All three production readers
(`src/ase_window.tcl:3561`, `:3589`, `:3607`) clear immediately before they read,
so nothing user-visible changes today; a future reader that forgets to clear
gets the session's whole backlog, which is exactly what R10 exists to catch.
`ase::sim_clear` itself has **no production caller** — only the two suites — so
the widened contract is reachable by no gesture a user can make.

## Acceptance rows

Added to `tests/headless/test_ase_simreg_0931.tcl` (60 → 67 checks) and
`tests/headless/test_ase_simdlg_0937.tcl` (25 → 26 on a display):

* **R13** — the row that is **not** blind to a list/run agreement. It registers
  the portable form against a real directory with a dollar in its name and
  **actually starts the program**, `eval exec`-ing the backend's own command
  line against a stub that echoes a sentinel. R7 compares two sentences and
  passes while nothing runs; R13 runs.
* **R14** — the recorded answer is about the setting and nothing else: delete
  the program under the live entry and the list must say the file is gone, put
  it back and the run must start again; and a location that really does name an
  unknown setting must still be reported as exactly that, so the fix cannot be
  bought by going silent.
* **R15** — two real child xschem processes sharing one redirected `HOME`. The
  first saves the list; the second is a fresh session, with the setting not set
  at all, that reads it back through the ordinary startup path and starts the
  program. Nothing in-process can prove a restart.
* **R16** — issue 0945: the same path typed exactly as the disk spells it, plus
  the normalisation half.
* **R18 STRUCTURAL** — comments stripped: `ase::sim_entry_kind`'s body contains
  **zero** occurrences of `expand_path`, `ase::sim_register`'s contains
  **exactly one**, `sim_entry_kind` names the recorded field, and it reads that
  field defensively (`dict exists` first). This pins the invariant the
  regression was made of, so a reader who re-adds a "quick" second look at the
  location to the validator is stopped by a row and not by a comment. The last
  term exists because the "an entry with no recorded answer has nothing wrong
  with it" default has **no producer**: there is exactly one place in
  `src/ase.tcl` that builds an entry and it always records the answer, so no
  gesture a user can make reaches that default and no behavioural row can see
  it. Measured: deleting it reddens nothing at all. A structural term keeps it
  without inventing a caller that does not exist.
* **R19** — the three outcomes of the new arm that R13–R16 never reach.
  R13–R16 all point the dollar-sign arm at a **working** program, so only one
  of its four outcomes was measured. R19 points it at a **folder** under a
  dollar-sign path and at a **file nobody marked runnable**, and asserts the
  user still gets "is a folder, not a program. … Point this entry at the
  simulator program inside that folder." and "is not marked as a program you can
  run … Use chmod +x on it", that neither entry is accepted (`ok` 0, the
  Simulators list shows the problem against it, the run refuses), and that
  neither sentence mentions a **setting** — the recorded answer about the
  setting is 1 in both, which is the whole point: a dollar sign buys the
  location the benefit of the doubt about a setting and about nothing else.
  The row leads with its own witnesses (the fixture really contains a dollar
  sign, the location really cannot be read as a setting, the folder really is a
  folder) so it cannot go green while measuring the ordinary arm that C2 and C3
  already cover.

  **This row was written because a sabotage pass measured its absence.** With
  the "look at what is really there" half taken out of the new arm, pointing a
  simulator at a folder under a dollar-sign PDK path answered "added, nothing
  wrong with it", the list showed no problem against it, the CIW said nothing,
  and the whole suite stayed green at 66 checks. With R19 in, that same edit is
  the **only** thing that reddens — one row, 66 others still green.
