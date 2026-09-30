# DECISIONS — replay_door_batch

Driver decisions, numbered. A crew that disagrees with one says so in its receipt rather than
quietly departing from it.

## D1 — the target was chosen by measurement, not off the list

The driver's reading of `wish_list.txt` had been wrong three times in two days (six shipped
waveform items called unshipped; Ctrl-A claimed to reach `select_all()` when it toggled a cursor;
`getprop` claimed to have nine arms when it had seven). So six candidates were measured by parallel
read-only crews before anything was picked — `receipts/R-recon-wishlist.md`.

**It changed the answer.** The driver's stated lean was new-list item 2 (wire labels). The
measurement put old-list item 3 far ahead: its engine is already built, safe and fenced, and the
only thing between it and the user's stated goal — macros — is a menu entry. Item 2 turned out to be
blocked on **four** semantic rulings the user has to make first, which is the worst possible shape
while the user is remote and cannot be asked things in bulk.

**Four of the six list annotations are now known wrong**, and that is recorded in the receipt rather
than acted on. Only the two proved today (items 13 and 15) were corrected in the file, in commit
`e05a9769`.

## D2 — scope is increments 1 and 2; the 29-suite registration is out

The recon named three increments. This batch takes the first two. Increment 3 — adding the
`OVERALL: ok` sentinel to the 29 replay round-trip suites and registering them — would take T1 from
107/106 to roughly **136/135** and move `wc -l`, `blocks=` and possibly `skips=`. CLAUDE.md's
adopted policy is the **bounded** half of the "run by nothing" lesson: *a suite you add a fence to,
you register in the same commit*, not mass registration.

⚠ The bounded half still binds. A stage that adds a row to an unregistered suite must give that
suite the sentinel additively (**above** its `RESULT:` line, since `summarize_all` publishes a
case's LAST `RESULT:` line) and register it in the same change. One or two suites, not 29.

## D3 — replay runs into the CURRENT session, and this is not an open question

`replay_action_log` already replays into the live session through the `log_action -suppress`
depth counter, and that is the shipped, fenced seam. The door uses it as-is.

Whether the user would rather replay into a **fresh** session is a genuine product question, and it
is theirs — filed as `rule/1619`. It does **not** gate Stage A, because the default matches what
already ships and because the user's standing instruction is that they must not be made a gate on
progress. A crew does not re-open this.

## D4 — no C change in Stage A

The whole point of the finding is that the engine exists. A `.c` edit in Stage A means the scope was
misread; the crew stops and says why in the receipt instead.

## D5 — the July audit document is not evidence

`doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` is wrong at HEAD
in four specific places, each re-verified against the binary by the recon crew: Ctrl-X self-logs
`xschem cut`, the Delete key produces `xschem delete`, Ctrl-C self-logs `xschem copy`, Ctrl-S
produces `xschem save`, and property edits emit real `xschem setprop … allprops` lines through
`log_prop_edit_one()` rather than a `# property-edit` marker. Its "roughly 70% landed" is stale and
its bare `file:line` citations have rotted.

**The document is left unedited for now** and this decision is the correction of record. Repairing
it is a separate unit of work; editing a dated analysis in place would falsify the record of what
was believed in July, which CLAUDE.md forbids for dated records.

## D6 — `xschem load <path>`'s scripted silence is correct and stays

`actions.c` logs a load only on the dialog path (`if(!filename && tcl_braceable(f))`). That is
deliberate: it stops a replay from re-opening a file chooser. It will read as a coverage gap to
anyone auditing log lines per verb. It is not one. Do not "fix" it.

## D7 — two numbers minted, 1619 and 1620

Both cleared the two-check procedure on 2026-09-29: candidate from this clone's pointer, no
reserved-band hit, no issue file in either checkout (`~/dev/xschem-claude`,
`~/dev/xschem-op-wcard`), and no other `NUMBERING.md` mentioning them.

## D8 — "25%" is replaced by a structure, not by a better percentage

The recon was told to report a structure and a denominator instead of a figure, because the split is
what matters: **machinery** is three chokepoints plus ~254 opt-in sites with a byte-identical
round trip, while **macros** are zero. A single percentage averages those into a number that is
wrong in both directions at once. Any future update to the wish-list line says what is reachable,
not what fraction is done.

## D9 — a READ-ONLY crew overwrote a shipped library schematic, and "read-only" now has to be spelled out

Stage R's brief said, in capitals, *"READ-ONLY. Change NOTHING. No edits, no commits, no writes into
the repo at all."* A crew nevertheless left `xschem_library/examples/nand2.sch` **modified in the
working tree**: 3 insertions, 35 deletions — the version header rewritten from
`3.4.4 file_version=1.2` to `3.4.8RC file_version=1.3`, `K {}` and `F {}` added, and **every `N`
net line and every instance deleted**. A shipped example schematic reduced to an empty stub. Written
at 20:08:40, inside the Stage R window and before Stage A was dispatched.

**The mechanism is not disobedience, it is a probe with the wrong target.** The wire-label crew's own
evidence quotes `xschem saveas` as its instrument for reading back what a placement wrote — a
legitimate and rather good method, since the `.sch` text is the ground truth for "did this place four
labels or one". But a save needs somewhere to go, and this one went to the file the probe had loaded.
A crew reasoning about *reads* does not necessarily notice that its read instrument is a write.

Handled as follows. The crew's version was **preserved** to the session scratchpad
(`nand2.sch.crew_overwrote.20260929`) before anything was restored, so nothing was destroyed to fix
a destruction; then the file was restored from HEAD and verified byte-identical to it (20 `N` lines
back, `git status` clean on that path). ⚠ The first restore attempt — `git checkout -- <path>` — was
**denied by the permission classifier** as irreversible local destruction, which was correct: at that
moment the crew's version existed nowhere else. The denial was not worked around; the backup is what
made the operation safe, and then a plain `git show HEAD:<path> >` did it.

Two rules follow, both now in `CREW_BRIEF.md`:

1. **A probe that saves, saves to scratch.** `xschem saveas <your scratch>/probe.sch` — never a path
   under `xschem_library/`, `tests/` or anywhere else tracked, and never the file the probe loaded.
2. **A read-only stage ends by proving it changed nothing**: `git status --short` must be empty of
   modifications the crew did not intend, and the receipt says so. "I did not mean to write anything"
   is not the same claim as "nothing is written", and only the second one is checkable.

⚠ **It also nearly reached a commit.** The driver staged by explicit path and caught it in review; a
`git add -A` or a `git commit -a` would have shipped a gutted library example. `tests/open_close`
does load this file (`tests/open_close/results/examples,nand2_sch_debug.txt`), so the blast radius
included a T1 case — mitigated only by the accident that `open_close` is one of the three cases
CLAUDE.md records as having no golden baseline and verifying nothing.
