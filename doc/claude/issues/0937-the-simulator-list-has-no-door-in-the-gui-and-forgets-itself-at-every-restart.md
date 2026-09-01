# 0937 — the simulator list has no door in the GUI, and forgets itself at every restart

STATUS: **FIXED** 2026-08-29 (backlog item S2, branch `annotate`). Measured
BEFORE at HEAD 439d1087; fixed and re-measured on the same day.

**READ THIS BEFORE TRUSTING THE FIX.** The door works and is well covered, but
verification measured **seven further defects that this commit did not fix, one
of which this commit CAUSED**. They are filed as **0938–0944** and listed under
*Known, not fixed* at the bottom. The regression is **0938**: a simulator whose
path expands to a name containing a literal dollar sign is runnable, registers
cleanly, and is then refused at the run with a sentence blaming a setting the
path never mentions. Three of the others — **0939**, **0940**, **0941** — are
silent data loss or silence in this dialog's own Add / Edit / Remove buttons.

Suites: `tests/headless/test_ase_simdlg_0937.tcl` (the door — 4 checks headless,
23 on the dev display) and section H of `tests/headless/test_ase_simreg_0931.tcl`
(the non-GUI half the door cannot be built without — 58 checks, was 48).

## What the user could not do

Issue 0931 (commit 0225a962) shipped a working simulator registry — register a
build of your own by name, say which one is in force, four validation guards
that each say something in plain English — and shipped it with **no way into
it**. The real ASE-L session window was opened on the dev display and its whole
menubar walked: nine menus, and not one entry anywhere mentioned a simulator
program. `Setup` offered exactly `Design…` and `Model Files…`. The only lever
was typing Tcl into the CIW.

And typing it into the CIW did not stick. `ase::sim_write_conf` — the writer —
had **zero callers in the shipped tree**. Measured across two real restarts with
`HOME` redirected: register a build, it goes into force, `WILL START:
/tmp/s2_before_bin/ngspice_ok` — then `SAVED FILE EXISTS: 0`, and the next run
printed `AFTER RESTART registered = ''` and fell back to `ngspice`. S1 built the
persistence half and wired it to nothing.

Three more gaps sat on the required path, and none of them was a widget:

* **Remove said nothing.** In all three arms — the only entry, one of two, one
  of three — taking out the simulator that was in force printed *(nothing at
  all)*, while the program that would actually start changed underneath the
  user. There was no sentence to say it with either: `removed_now_path`,
  `removed_now_other` and the two state kinds all fell through
  `ase::sim_why`'s catch-all, "Something is wrong with the simulator named X."
* **A row could not say why it was unusable.** The stored entry carries
  `name path args backend origin ok` and no reason. `ok` is a boolean with no
  words in it, and re-checking the stored path was not a substitute: for a
  location naming a setting this session does not know about, registration says
  *setting* and a bare re-check answers `missing`, so the list would have
  contradicted, in writing, the sentence the user had just been given.
* **A cleared choice did not survive a restart** (issue 0932, on this item's
  path rather than beside it, because the dialog offers exactly that choice).
  Saving wrote two register lines and no selection line; reading it back put the
  first entry in force again and the user's own gesture was silently undone.

## The fix

**One door, one writer.** `Setup > Simulators…` opens `$top.simdlg`: the
registered simulators with Name / Program / Problem, a read-only "use this one"
control whose first line is *(none — use the program my system finds on the
PATH)*, Add / Edit / Remove, a status line, and a line saying where the list is
saved. Every gesture drives S1's own procs and saves through
`ase::sim_write_conf`. No validation, no path resolution and no persistence is
re-implemented in the dialog.

**Nothing is worded twice (ruling D5-4).** Four new kinds are minted in
`ase::sim_why` — `removed_now_path`, `removed_now_other`, `in_force`,
`path_in_force` — and the dialog only renders them. Where it has to show what a
gesture just said, it reads it back: `ase::sim_say` mints, RECORDS and echoes,
`ase::sim_said` returns the last sentence, `ase::sim_said_clear` empties it. All
six render-and-echo sites in `ase.tcl` now go through `sim_say`, and row R10
greps the comment-stripped file so no `ase::echo [ase::sim_why …]` construct can
come back for a caller to copy. Row R9 checks every fixed ≥25-character piece of
the four new sentences occurs exactly once in `src/ase.tcl` and never in
`src/ase_window.tcl`.

**The per-entry reason.** `ase::sim_entry_why <name>` is the sentence a Problem
column shows, re-validated on every call (row R6 deletes the program under a
live entry and expects the row to explain itself, with `ok` untouched).
`ase::sim_entry_kind` is the entry-flavoured validator behind it, and it is what
makes the list and the run agree in the unknown-setting arm (row R7) — half of
issue 0933 closed; the storage half stays filed. **It also caused issue 0938**:
it substitutes the stored path a second time, the stored path has already been
expanded once, and the substitution is not idempotent. Row R7 cannot see that,
because the list and the run are then wrong together.

**Feedback lands in the dialog.** The status label is the surface, and the row
editor has its own. The precedent next door is the bad one: `Setup > Design` and
the shared list dialog behind `Model Files` report to the CIW only, in un-minted
machine wording, so the user sits looking at a dialog that did nothing and says
nothing.

**Remove works on the entry in force by construction** and says what happens
next, in both arms. The "it will be back the next time xschem starts" sentence
for an rc-declared entry is still said LAST; row R4 pins that order in the
source, because row E13 reads the last sentence a removal echoed and no
behavioural row in that file can see the ordering.

**Two writer fixes came with it.** A cleared choice is now written down
(`ase::sim_select {}` — issue 0932), and the file is written beside itself and
moved into place: `open <path> w` truncated the user's saved list before a
single line was written, and a `close` that reported a buffered write raised out
of a proc that promises never to raise. That was survivable while nothing called
the writer; the dialog now calls it on every Add, Edit, Remove and choice.

**Nothing here logs.** The 0930 interceptor records the pick from the Setup
entry's own `-command`; a second call would double every line. Row S13 greps the
dialog's proc bodies for one.

## Decisions, and what was rejected

* **The first simulator you register still goes into force even when its path
  is bad.** S1's rule, kept — but the consequence is now visible in the same
  gesture: the row's Problem cell and the dialog's status line both say what is
  wrong and what to do. REJECTED: only a validated entry may be auto-selected —
  it changes the registry's semantics for the CIW and rc routes too, and leaves
  a user who registered exactly one simulator with nothing in force and no hint
  that a second gesture is required. **This is the unratified question S1 left
  and it is on the user's ruling queue** (`owed.sh add rule 0937`).
* **A cleared choice now overrides an rc's `::ASE_SIMULATOR` at the next
  start**, because the user file is read after the rc seed and their later
  gesture wins over the rc's default. REJECTED: leaving 0932 filed — the dialog
  would offer "use the program on my PATH", appear to accept it, and silently
  undo it at the next start.
* **Renaming is not offered.** In Edit the Name field is read-only; a rename is
  Remove then Add. REJECTED: rename as unregister+register — it moves the entry
  to the end of the list and fires the "you removed X" sentence in the middle of
  what the user experienced as a rename.
* **The dialog shows Name and Program only.** Extra arguments and the backend an
  entry is registered for stay CIW/rc-only and are carried through untouched by
  an Edit (row S9). REJECTED: four fields — it doubles the dialog for two
  settings almost nobody sets, and nothing is lost.
* **The status line prefers the state over the "more than one is registered and
  none is picked" sentence.** With the choice deliberately cleared and two
  entries registered, the resolver's `why` carries that sentence — true, but an
  answer to a question this dialog IS the answer to, with the list right there.
  A problem is shown only when the resolver could not honour what is in force.
* **Menu label and placement: `Setup > Simulators…`.** REJECTED: `Simulation >
  Simulators…` — Setup is where the other configuration dialogs live.

## Known, not fixed

**Seven defects were measured against this change and are filed, not fixed.**
Each was reproduced first-hand by the write-up agent before filing. None is
covered by any row in either suite — they sit in arms no row exercises
(startup-file entries, an Add onto an existing name, a backend mismatch) or are
consequences of two changes the suites were written around rather than against.

* **0938 — a simulator whose path contains a dollar sign can no longer be
  started. THIS COMMIT CAUSED IT.** `ase::sim_entry_kind` expands the stored
  path a second time; registration already expanded it once. `ok` flips 1 → 0,
  `resolved` goes empty, `ase::sim_exe` raises. The way out is either reverting
  one call (reopening 0933's half, reddening R7) or recording the expansion
  outcome at registration instead of re-deriving it — **the user's call, and it
  is on the ruling queue.**
* **0939 — editing a simulator that came from a startup configuration file takes
  it over for good, silently.** `origin` is laundered `rc` → `session`, the
  entry lands in the saved list, and editing the xschemrc no longer changes
  anything for it. The writer's own comment says this must never happen. S9 uses
  session-origin entries only.
* **0940 — Add onto a name already in the list silently replaces it**, wiping
  extra arguments and backend, and reports success. This is the defect S9 exists
  to prevent, reachable through the other button.
* **0941 — Remove on a startup-file entry never says which simulator runs next**
  — a direct miss of this item's own brief. `ase::sim_said` holds one string and
  the rc sentence is deliberately said last (row R4), so it overwrites the
  what-happens-next sentence that was minted for exactly this.
* **0942 — saving replaces a symlinked list with a plain file**, orphaning a
  shared list, and reports success. The rename-into-place replaces the link
  itself; the old writer wrote through it.
* **0943 — the new writer refuses saves the old one managed** (a writable file in
  a read-only directory), leaks the internal `.new` file name into a user-facing
  sentence, and leaves the dialog saying two opposite things at once. Worth
  knowing: that rewrite was made to bring row S11 within reach, not to fix a
  reported defect — though it does also close a real truncate-before-write
  hazard, now pinned by R11 and R12.
* **0944 — the Problem column is blank for an entry registered for another
  backend**, which is unusable the moment it is picked. The sentence exists; the
  list never asks for it.

* **The bottom bar still reads `Simulator: ngspice`** — the backend name, never
  the program that will start. Deliberately out of this item's scope; the
  dialog's status line is the surface that names the program.
* **The registry is process-global while the dialog is per-session.** With two
  ASE-L windows open, a change made in one window's dialog is not reflected in
  the other's open dialog until it is reopened.
* **The file browser is modal and no suite can press OK in it.**
  `tk_getOpenFile` grabs the display and waits for a human. Row S14a asserts the
  proc body and the wiring and says so out loud rather than faking the click.
* **Nobody has looked at this dialog.** A `look` debt is recorded; a green suite
  is not a pixel deliverable.
