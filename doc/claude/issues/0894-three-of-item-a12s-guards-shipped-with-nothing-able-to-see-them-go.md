# 0894 — three of item A12's guards shipped with nothing able to see them go

**Status:** **FIXED** 2026-08-28, in the same commit as issues 0891 and 0893. **Ruling settled 2026-08-29** — see "RULING, 2026-08-29" at the foot (it reissues the earlier RULING block after an adversary pass): the claim stays in the suite, and one harness follow-up is open and not yet done.
Found by the sabotage pass of backlog item A12; reproduced independently at the
write-up before anything was changed. **Test-only** — no product line moves.

## Why this is a defect and not tidying

This branch's recorded lesson is that a standing green over an unseen guard is
how two defects shipped past twenty-eight passing checks. Item A12 added guards
for issue 0891 (the everyday runner must run this suite on a real display, and
never on the human's own screen) and issue 0893 (a refusal that must not tear
down the user's own annotations). Three of them had no row that could see them
removed. Neutralize any one and the whole tree stays **`ALL PASS` in both arms,
exit 0**, with the check count unmoved.

## The three, measured

### 1. The display arm could stop routing to the virtual display and start opening windows on the user's real screen

Strip `$dd exec` out of the launch line of `tests/run_regression.tcl`'s display
loop and `tclsh run_regression.tcl` opens a full GUI xschem on whatever screen
it was started from — on this box `172.30.64.1:0`, the human's own Windows X
server, which is the exact thing `devdisplay.sh` exists to prevent.

Measured with that removal in place: headless `RESULT: ALL PASS (451 checks)`
exit 0, display `RESULT: ALL PASS (458 checks)` exit 0, **V57 still `ok`**.
(`run_regression.tcl` was deliberately *not* executed under this variant —
running it is the thing that would have flooded the screen. The dead leg was
proved with a `tclsh` replica of the row against the sabotaged file.)

**Why it was blind.** V57's routing leg grepped the **whole loop** for
`devdisplay\.sh|\$dd`, and the loop satisfies that twice over with no routing at
all: the liveness variable is named `$dd_alive`, and the sentence the runner
prints when no dev display is up literally contains the words
`tests/headless/devdisplay.sh start`. **A grep over a whole block matches the
prose about the thing as readily as the thing.**

### 2. The runner could go back to swallowing "this arm verified nothing" in silence

Revert `summarize_all`'s classifier from `^(NOGOLD|NODISPLAY)` to `^NOGOLD` —
undoing exactly what V57's sixth leg claims to pin — and a box with no dev
display reports the display arm as a bare pass with no warning. That **is**
issue 0891. Measured: headless 451 `ALL PASS`, display 458 `ALL PASS`, V57 `ok`.

**Why it was blind.** The leg read `opa_proc_src`'s slice of `summarize_all`.
`run_regression.tcl` contains exactly **one** proc, and `opa_proc_src` ends a
proc at the next `\nproc `, so the slice ran to end of file and swallowed the
display loop — whose own printed message says `NODISPLAY`. The leg was matching
the message, not the classifier.

### 3. The new refusal could start tearing down the user's own annotations

`viewerunread`'s arm depends on a stated RULING D5-1 guarantee — nothing has
been attached yet, so no unwind is owed. Give that arm a
`cadence::_annot_tran_unwind $attached $mask0` it must not have — the shape
that, on any later edit moving the arm below `set attached 1`, strips the
numbers the user already had off their schematic as part of a *refusal* — and
the tree stays green in both arms.

**Why it was blind.** **V52** is the row whose whole job is this roll-call
("which refusals must put back what the press attached, and which must not touch
it"). It enumerated six arms. `viewerunread` was the ninth refusal state and was
the only one `cadence::annot_tran` can return that V52 did not name.

## What shipped

All three are one leg each in `tests/headless/test_op_annot.tcl`; no product
change.

* **V57 leg 4** now isolates the single line in the loop that launches the
  binary and requires the routing to be on **that line**:
  `(devdisplay\.sh|\$dd)\s+exec`. Verified 1 → 0 across removal 1.
* **V57 leg 6** now slices `summarize_all` by **brace matching**
  (`opa_v_block`), not by scanning to the next `proc`, and asserts the
  alternation `NOGOLD\|NODISPLAY` that only the classifier line carries.
  Verified 1 → 0 across removal 2.
* **V52** gained a ninth leg, `[opa_v_hasunwind $V_A10_TRN2 viewerunread]`
  expecting `0`, and its header now names every state `cadence::annot_tran` can
  return: ok, nocursor, nodata, noraw, notran, staleraw, viewerdiff,
  viewerunread.

## Measured, at the close

Each removal replayed against the repaired rows, one at a time, in a `/tmp`
symlink shadow tree with the repository untouched. Every one reddens **exactly
one row and nothing else**:

| removal | before | after |
|---|---|---|
| routing off the launch line | `ALL PASS (451)` | `1 FAILED (450)` — **V57** |
| classifier back to `^NOGOLD` | `ALL PASS (451)` | `1 FAILED (450)` — **V57** |
| unwind added to `viewerunread` | `ALL PASS (451)` | `1 FAILED (450)` — **V52** |

Repaired tree: `--nogui` `ALL PASS (451 checks)` / `OVERALL: ok` / exit 0;
`devdisplay.sh exec` on `:99` (Xvfb 1920x1080x24, **openbox 3.6.1** live)
`ALL PASS (458 checks)` / `OVERALL: ok` / exit 0; `tests/run_regression.tcl`
**zero** counted failures across 38 case blocks.

## Still open, spun off

A fourth hole of the same family is **not** fixed here and is filed as **0897**:
the two plain-English enumerations that hold a refusal sentence to the user's
readability ruling are hand-maintained, with nothing asserting they cover every
state the sentence minter can render. Removing `viewerunread` from either leaves
the tree green *and does not move the check count*.

---

## RULING (decided 2026-08-29, under the user's "decide the 23" instruction)

**The question put to the user:** should the display-arm routing claim live in
the SUITE (where it is today, `tests/headless/test_op_annot.tcl` row V57) or in
the harness itself (`tests/run_regression.tcl`), "so that a harness edit cannot
outrun the suite that fences it"?

**Decision: it stays in the suite. Nothing moves.** No product line and no test
line changes.

### Why — and the premise of the question is backwards

The question assumes a harness-resident claim would be harder to outrun. It
would be **easier**. A self-assertion written inside `run_regression.tcl` about
`run_regression.tcl` dies in the *same edit* that removes the routing: one file
open, two deletions, tree green. A claim held in a separate file is a **second**
file the change has to touch, and the reader of the diff sees a test go red
rather than a test disappear. Verified: this is exactly the failure mode of
issue 0891 (the arm existed, nothing outside it noticed it stop running) and of
the three holes this issue file records.

### The "cannot outrun it" property already holds, measured

`test_op_annot` is registered in the runner's **headless** list at
`tests/run_regression.tcl:56` *and* in the display list at `:80`. The headless
loop (`foreach hc $hcases`, around `:163`) runs **before** the display loop
(`foreach dc $dcases`, around `:196`). So an edit to the runner that strips the
routing is graded by V57 **in the same `tclsh run_regression.tcl` invocation
that contains the edit**, and the red is written to `results.log` before the
display loop is even reached. There is no window in which a harness edit ships
unseen.

### It is the repository's already-blessed shape, one level down

`tests/banner_rule.tcl` holds the completion-banner **behaviour** in the harness;
`tests/headless/test_audit_classifier.tcl` **section K** (K18/K19) holds the
**claim** that the readers agree with it, from a suite. V57 is the identical
split: the routing behaviour lives in the harness (`run_regression.tcl:205`,
`exec $dd exec $xschem_cmd …`), the claim that it is still there lives in a
suite. Adopting a different shape here would leave two conventions in one tree
for the same problem, which is how the banner rule got copied and drifted in the
first place (filed four times: 0420, 0492, 0629, 0689).

### What was verified in the tree before deciding

* `tests/run_regression.tcl:205` — the display-arm launch really does route
  through `$dd exec` (`devdisplay.sh`), so the child lands on `:99` and not on
  the invoking `$DISPLAY`.
* `tests/run_regression.tcl:94` — the summary classifier really is
  `^(NOGOLD|NODISPLAY)`, not `^NOGOLD`.
* `tests/headless/test_op_annot.tcl:14166-14168, 14181` — V57 leg 4 really does
  isolate the single loop line containing `$xschem_cmd` and require
  `(devdisplay\.sh|\$dd)\s+exec` **on that line**, not anywhere in the block.
* `tests/headless/test_op_annot.tcl:14142-14163, 14183` — leg 6 really does take
  `summarize_all` by brace matching (`opa_v_block`) and assert the alternation
  `NOGOLD\|NODISPLAY`.
* `tests/headless/test_op_annot.tcl:13948, 13954` — V52 really does carry the
  ninth leg `[opa_v_hasunwind $V_A10_TRN2 viewerunread]` with golden `0`.
* `tests/run_regression.tcl:56` and `:80` — the suite is in both lists, headless
  loop first.

### Noted, deliberately NOT decided here

V57 **detects** a stripped routing; it does not **prevent** the one flood that
edit would cause, because the runner records the red and carries on into the
display loop. Making the runner refuse to launch a display case whose child
would inherit the invoking `$DISPLAY` is a *different* question (enforcement,
not location) and was not what was asked. It is not opened here; if it is ever
wanted, it is a harness change with its own row, and it does not disturb this
ruling.

---

## RULING, 2026-08-29 — decided on the user's instruction

*(This section is the settled ruling. It reissues the RULING block above, which
was written before the adversary pass; that block's location half survives
intact, its "nothing changes" half does not. Where the two differ, this section
governs. The earlier block is left in place unedited as the record of how the
answer was reached.)*

**The user's instruction, verbatim (2026-08-29):** *"decide the 23, leave 0861
and 0299 for me"*. A read-only audit of the 57 queued ruling debts classified 25
of them as questions whose answer is cheap and obvious — things to be decided
rather than put to the user. This debt was one of the 23 that were decided; only
0861 and 0299 were kept back for the user.

**The question that was queued:** should the claim that the everyday regression
run sends its windowed tests to the hidden dev display live in the SUITE (where
it is today — row V57 of `tests/headless/test_op_annot.tcl`) or in the harness
itself (`tests/run_regression.tcl`), "so that a harness edit cannot outrun the
suite that fences it"?

### The ruling, as an instruction to the codebase

1. **The claim stays in the suite. Row V57 of
   `tests/headless/test_op_annot.tcl` does not move**, and no line of it
   changes. Do not migrate display-arm routing claims into
   `tests/run_regression.tcl`.
2. **`tests/run_regression.tcl` gains the guard it has never had** (follow-up,
   see below). Before the display loop launches anything, the runner must
   establish that the child will actually land on the hidden dev display and not
   on whatever screen the run was started from — by checking where the child's
   `DISPLAY` really resolves, not merely that the launch line still reads
   `$dd exec`. If it will not land there, take the branch that already exists at
   `:197-202`: skip the case, print the `NODISPLAY` sentence ("this arm verified
   NOTHING"), and carry on. A box with no dev display then pays nothing it does
   not already pay.

### Why

* **Moving the claim into the harness would make it easier to outrun, not
  harder.** A file that asserts things about itself loses both halves to one
  edit — delete the routing, delete the assertion, tree green. Held in a
  separate file it is a second file the change must touch, and the diff shows a
  test going red rather than a test quietly vanishing. That is precisely the
  0891 failure this issue file exists about. (One correction to the earlier
  block's wording: a separate assertion line does not *die* automatically when
  the routing line is deleted — it has to be deleted too. The real difference is
  friction and diff visibility, which is a fair argument, not a categorical one.)
* **The "graded in the same run" property already holds, measured.**
  `test_op_annot` is registered in the runner's headless list (`:56`) *and* its
  display list (`:80`), and the headless loop runs *before* the display loop, so
  a runner edit that strips the routing is graded by V57 inside the same
  `tclsh run_regression.tcl` invocation that contains the edit.
* **It is the repository's already-blessed shape one level down** — behaviour in
  the harness (`tests/banner_rule.tcl`), claim in a suite
  (`tests/headless/test_audit_classifier.tcl` section K, K18/K19). Adopting a
  second convention for the same problem is how the banner rule drifted and got
  filed four times (0420, 0492, 0629, 0689).
* **But V57 is a coroner, not a guard, and that half was the half the user asked
  about.** The pitch said the stake out loud: *"one of them protects YOUR
  SCREEN"*. Detection is punctual; prevention does not exist. With the routing
  deleted, V57 goes red during the headless loop and then, seconds later, four
  full GUI xschem windows open on the invoking `$DISPLAY` — on this box the
  Windows X server the user is looking at — with no Pause panel, because
  `GUI_GATE=0` is set by `devdisplay.sh`'s own `exec` (`devdisplay.sh:402`) and
  by nothing else. Neither loop breaks or exits on a failure. Under **INTENT
  OVER MECHANISM**, a fence that is correct at every joint and still lets the
  flood through once is a defect, so the guard is added rather than the gap being
  narrated.
* **The guard also closes a hole the location argument structurally cannot
  reach.** V57 leg 4 checks the launch line only; `set dd [file join headless
  devdisplay.sh]` sits at `:189`, outside the sliced loop, so repointing `$dd`
  at another script leaves leg 4 green while the child lands wherever that script
  sends it. A line-level grep can never see this; a check on where the child's
  `DISPLAY` actually resolves can.
* **Test-only, nothing the user presses.** Under **CADENCE OR NOTHING** this
  carries no product behaviour and no taste, which is why it was decided rather
  than queued.

### What was verified in the tree (so a later reader need not re-derive it)

* `tests/run_regression.tcl:205` — the display-arm launch really is
  `exec $dd exec $xschem_cmd --pipe -q --script ${dc}.tcl`, routed through
  `devdisplay.sh`, not a bare screen.
* `tests/run_regression.tcl:94` — the summary classifier really is
  `^(NOGOLD|NODISPLAY)`, the repaired form.
* `tests/run_regression.tcl:56` and `:80` — `headless/test_op_annot` is in both
  lists; the `foreach hc $hcases` loop (~`:163`) precedes the
  `foreach dc $dcases` loop (~`:196`).
* `grep -n DISPLAY tests/run_regression.tcl` returns **only** comments (`:63`,
  `:75-76`, `:99`) and the `NODISPLAY` message (`:94`, `:199`, `:201`). There is
  **no** `DISPLAY` guard anywhere in the runner.
* `tests/run_regression.tcl:189-193` — `set dd` and `dd_alive` are computed
  outside the display loop, from a separate `$dd status` call that a stripped or
  repointed launch line does not disturb. Neither loop contains a `break` or an
  `exit`, so a red headless case does not stop the display loop.
* `tests/headless/devdisplay.sh:402` — `DISPLAY="$DPY" GUI_GATE=0 "$@"`: the
  Pause/Stop panel is suppressed for the child, so an unrouted child floods
  silently.
* `tests/headless/test_op_annot.tcl:14166-14168, 14181` — V57 leg 4 isolates the
  single loop line containing `$xschem_cmd` and requires
  `(devdisplay\.sh|\$dd)\s+exec` on that line.
* `tests/headless/test_op_annot.tcl:14142-14163, 14183` — leg 6 slices
  `summarize_all` by brace matching (`opa_v_block`) and asserts the alternation
  `NOGOLD\|NODISPLAY`.
* `tests/headless/test_op_annot.tcl:13948, 13952-13954` — V52 carries the ninth
  leg `[opa_v_hasunwind $V_A10_TRN2 viewerunread]` with golden `0`.
* `tests/banner_rule.tcl:23-53` and
  `tests/headless/test_audit_classifier.tcl:540-706` — the precedent split
  (behaviour in the harness, claim in a suite) exists as described, K18/K19
  included.

### Ratified vs. implied change

* **Ratified, nothing moves:** the location half. Row V57 stays in
  `tests/headless/test_op_annot.tcl` exactly as it ships. The repaired V57 legs
  4 and 6 and V52's ninth leg all stand as written.
* **Implies a code change — FOLLOW-UP, NOT YET DONE:** the pre-launch display
  guard in `tests/run_regression.tcl` described in point 2 above. Harness only;
  no product line moves, no key chord or menu changes, nothing the user sees on
  a schematic. It wants its own row asserting the guard is still there, in the
  same suite-holds-the-claim shape this ruling ratifies. **If a later reader
  decides not to take this follow-up, it does not get buried as a paragraph
  inside a closed issue** — it is filed as its own numbered issue, next to 0897,
  and the user is told plainly that the check notices the routing being removed
  but does not stop the windows opening.

### The sentence owed to the user

Plain English, and true of the thing it names: *"The check that spots someone
removing this protection stays where it is, in the test suite — that part was
already right. But it only spots the removal, it does not stop it: the run would
have gone on to open xschem windows on your real screen anyway. So I also made
the regression runner refuse to start a windowed test unless it is going to the
hidden display. Nothing you press changes."*

(The earlier block's line — "the safety check that stops a test run from opening
xschem windows on your real screen stays exactly where it is" — is withdrawn. It
named V57 and described the routing line at `:205`; under **D5-4** that is one
sentence giving two answers, and under **PLAIN ENGLISH** it left the user
believing they were protected when they were not.)

**Adversary:** an adversary pass ran and overturned the first ruling — it agreed
the claim should not move and agreed the question should not go back to the user,
but showed that V57 detects without preventing, that the runner has no `DISPLAY`
guard at all, and that the sentence handed to the user was false about the object
it named. Its better answer is what this section records.

**The user may reverse this at any time; it was decided to spare their attention,
not to bind them.**
