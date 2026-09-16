# ⚖ R9 rulings A3, A4 and A5 — a refusal names the caption the user can see

**One task from the driver: implement A3, A4 and A5**, ruled in `R9_COPY_REVIEW.md` §A3/§A4/§A5.
Files touched, and nothing else: `src/ase.tcl`, `src/ase_window.tcl`, `tests/headless/test_ase_core.tcl`,
`tests/headless/test_ase_dialogs.tcl`, `R9_COPY_REVIEW.md`, and this receipt.

No C. No new `.tcl` file, so no `src/Makefile.in` / `./configure` obligation.

HEAD was `a7bd53b7` at hand-over and is `a7bd53b7` now. **No commit, no `git add`, no
stash/restore/checkout/clean/push.** `tests/run_regression.tcl` **NOT run** — the driver's, solo
(issue 0990). `owed.sh count` is **187 rule, 71 look, 11 suite** before and after: nothing added,
nothing cleared, ledger never written so no backup was needed. `~/.xschem/recent_files` is
**untouched at 2026-09-13 18:53:01** (issue 0924 canary), checked at the start and at the end.
**`/usr/bin/ngspice` was never invoked**, no simulation was run, and no deck was written under
`sky130A/`.

**104 of 104** tracked `.state` files round-trip byte-identically — `tracked 104`, `bad {}`,
**`control_disagrees 1`, `control_agrees 1`** — driven as a **proc** (`ase_state_roundtrip`), never
by running `state_roundtrip.tcl` as a script. Measured **four times**: before the change, after the
source change, on the finished tree, and on the tree as it hands over.

---

## ⚠ THE HEADLINE: THE RULING'S HARD REQUIREMENT DELETED A SECOND BODY THAT WAS ALREADY THERE

A3 says *"one accessor, never a second table"*. The obvious implementation — a slot→caption map in
the refusal path — would have passed **every other row in this section** and rotted the same day,
because **A4 and A5 reword four of these captions in this very commit**. So the caption rule now has
exactly one body, `ase::caption_of`, and every surface asks it.

**The survey that preceded the design found the tree already had the second body.**
`ase::ui::meas_flabel` was a **byte-for-byte copy of `ase::ui::form_label`'s body** over the other
field registry — declared label, else `[string totitle]`, plus the unit in parentheses, plus the
colon. It is now a one-line delegation. That is receipt 53's `valuelabels`/`nz_*` lesson arriving
from the other side, and it was found by grepping for the *shape* (`string totitle`, `dict get $fd
label`) rather than for a name I expected — receipt 53's C21 point.

The split that makes one body possible across two registries:

| proc | file | what it is |
|---|---|---|
| `ase::caption_of {fd field {modeval {}}}` | `ase.tcl` | **the rule**, over a descriptor dict |
| `ase::field_caption {sim type field {modeval {}}}` | `ase.tcl` | analysis-registry resolver |
| `ase::field_caption_for_row {sim type row field}` | `ase.tcl` | resolves the row's own mode first |
| `ase::ui::form_label` | `ase_window.tcl` | **adds the colon** — a form asks a question |
| `ase::ui::meas_flabel` | `ase_window.tcl` | measurement-registry resolver + colon |

It takes a **descriptor**, not a `sim`/`type`, precisely because there are two registries
(`ase::field_descriptor` and `ase::meas_kind_field`) holding the same *shape* of descriptor. That
lets both share one body without pretending the two tables are one.

## What changed, by handle

| handle | was | now |
|---|---|---|
| `R9-003` | `Stop` | **`Stop value`** |
| `R9-004` | `Step` | **`Step size`** |
| `R9-017` | `Start recording at` | **`Start time`** |
| `R9-025` | `Start recording at (s):` | **`Start time (s):`** |
| `R9-062` | `needs a value for 'stop'` | **`needs a value for 'Stop time (s)'`** |
| `R9-063` | `'uic' must be on or off` | **`'Use initial conditions' must be on or off`** |
| `R9-064` | `cannot read 'zz' as a number for 'step'` | **`… for 'Time step (s)'`** |
| `R9-075` / `R9-076` | `needs 'ptssum' to be at least 1` | **`needs 'Report every N points' to be at least 1`** |
| `R9-159` | `needs a value for 'step'` | **`needs a value for 'Time step (s)'`** |
| `R9-356` | `'fft' reads a transient…` | **`'FFT spectrum' reads a transient…`** |
| `R9-361` | `…SEGFAULTS for TRIGTARG.` | **`…SEGFAULTS for Delay (TRIG ... TARG).`** |

⚠ **`R9-063` and `R9-064` are the fifth and sixth sites, and they are a finding.** The brief named
four handles and said the list was *"a starting point, not a boundary"*. Grepping every refusal that
interpolates a slot name found `ase::analysis_emit_msg`'s `boolval` and `fill` clauses have the
identical defect — R9-076's own note predicted it (*"the sibling clauses `missing` and `fill` have
the same defect"*). All four are fixed by one change at the call sites, because the renderer is fed
the caption rather than teaching four clauses to look one up.

**Measured, not asserted** (`PROBE` log, `scratchpad/a345/logs/probe.log`):

```
needs a value for 'Stop time (s)'
'Use initial conditions' must be on or off
cannot read 'zz' as a number for 'Time step (s)'
needs 'Points per octave' to be at least 1
needs 'Report every N points' to be at least 1
```

## ⚠ THE LITERAL IN `ase::analysis_emit_msg` DID NOT CHANGE, AND THAT IS THE DESIGN

`missing` still reads `"needs a value for '$f'"`. What changed is what is **fed** to it:
`ase::analysis_emit_check` resolves the caption and passes it as `$f`. Three consequences a verifier
should check rather than take on trust:

* the renderer stays a **pure sentence-builder with no lookup in it**, so all four sibling clauses
  were fixed at once and `ase.tcl:30837`'s trnoise `fill` — which was **already** passing a label —
  stops being an exception and becomes the model;
* **a reader grepping the document's `text` blocks sees no diff** for R9-062/075/159. The entries
  now carry a `*Rendered:*` line, which is where the change is visible;
* **the verdict tuple's field element is still the SLOT.** This is load-bearing and is pinned by row
  **LB2**: `ase::ui::chana_ok` takes element 1 and asks `ase::ui::form_has` and
  `ase::field_descriptor` about it — both keyed by the slot — to land the focus in the offending box
  and to append *" It is under Advanced."* A tuple carrying the caption would have broken the focus
  and the Advanced clause **while the sentence read perfectly**.

## A3's sharpest half: the caption is resolved PER ROW

`ac`'s and `noise`'s `sweep` declares `relabels points`, so **one slot wears three captions**. A
refusal that resolved the caption without the row would tell a user who picked `oct` to go and fix
`Points per decade` — a caption not on their screen, which is A3's own defect re-created one layer
in. `ase::field_caption_for_row` reads the row's stored mode, falling back to the mode field's
`default` (what the form shows when the row stores nothing). Measured: `{}`→`Points per decade`,
`dec`→`Points per decade`, `oct`→`Points per octave`, `lin`→`Number of points`. Row **LB3**; sabotage
**S3** reds it alone.

## A4 — and the asymmetry is pinned, because it looks like untidiness

`Stop value` / `Step size` on dc; `Time step (s)` / `Stop time (s)` on tran and `Stop frequency (Hz)`
on ac **unchanged**. `Stop time` puts the role first and `Time step` the quantity; `.tran tstep
tstop` is how a designer reads it. **The asymmetry is the user's ruling**, pinned by **LB6** the way
A1 pinned `SEGFAULTS` and A2 pinned `dec`/`oct`/`lin`.

## A5 — the meaning MOVED, and here is the detail line carrying it

The brief's acceptance criterion. `Start recording at (s):` → `Start time (s):`, **and the fact that
caption was carrying now lives under the form**, as a new `tstart_note` precondition on the tran
entry rendered by `ase::precheck_banner` into `$w.note`. Measured, rendered:

```
⚠ ngspice still simulates from 0 and only discards the output before 5u, so this
shortens the results file and not the run. Fix: clear Start time (s) to keep the
whole waveform
```

**It speaks only when the field is set** — an empty `tstart` has nothing to explain, so none of the
104 committed benches shows it (row **LB8**). `caution` is the mildest verdict `ase::precheck_worst`
ranks; there is no `note` level and inventing one would be its own ruling. The caption in the fix is
**asked for, never spelled**, so it cannot go stale the next time this caption is ruled on.

⚠ **A consequence to see rather than discover later:** `ase::analysis_needs` also feeds the
bench-wide `ase::analysis_precheck`, so an **enabled** tran row with `tstart` set will also show this
line in the pre-run advice block. That is arguably right — it is a true thing about the run — but it
is a second surface, and I did not invent a mechanism to suppress it.

## Suites — name diff on BOTH arms

`nogui` = `./src/xschem --nogui --pipe -q --nolog`; `disp` = `devdisplay.sh exec` on **`:99`**
(Xvfb, **openbox 3.6.1**, `1920x1080x24`, `devdisplay.sh status` = alive).

| suite | before (nogui / disp) | after | rows changed |
|---|---|---|---|
| `test_ase_core` | 653 / 653 | **662 / 662** | **LB1–LB9 gained**; 8 moved |
| `test_ase_dialogs` | 37 / 386 passed | 37 / **387 passed** | **G2dc gained**; 5 moved |
| `test_ase_preflight` | 238 | 238 | — |
| `test_ase_optsheet_1441` | 64 / 89 | 64 / 89 | — |
| `test_ase_meas_1443` | 113 | 113 | — ⚠ **NOT cover for `meas_flabel` — see the driver correction below** |
| `test_ase_window` | 56 | 56 | — |
| `test_ase_trnoise_1466` | 80 | 80 | — |
| `test_ase_trnoise_gui_1467` | 63 | 63 | — |

Floors raised with each file's own paragraph: core **653 → 662**, dialogs display **386 → 387**
(headless unmoved at 37, every new row being a widget row inside the display guard).

**Moved, not gained — core (8):** `EK1`, `EK4`, `AC1`, `AC2`, `TF3`, `PZ3`, `SE3`, `MP11`.
**EK4 got stronger rather than merely moving**: it now builds its clause from the caption the way the
gate does, so its substring term proves the frame wraps the clause **and** that the clause is the one
made from the caption.

**Moved, not gained — dialogs display (5):** `G2c` (A5's caption), and `G2tf`/`G2pz`/`G2sens`/`G2f`,
each of which searched the dialog's status line for a **slot name**. Each now searches for the
**caption** and carries a new term demanding **the quoted slot be absent**.

⚠ **That absence term is the point, and two of the four were weak without it.** `G2sens` searched
for the three letters `out`, which any sentence about an output may contain by accident; `G2f`
searched for `step`, which is a substring of the tran form's `Time step`. This is receipt 53's
correction **C2** in a new dress — an assertion that passes through a coincidence proves nothing —
and it is why the suite gestures use the words on screen.

⚠ **`test_ase_dialogs`' display arm carries ONE red before AND after: `G2sens`** (the field-build
row), actual `{1 1 0 1 0 Entry Entry normal}`. **Issue 1436**, red on the pristine tree in the same
session, and **not mine**. T1 runs this file on neither arm.

## Sabotage — ten arms, every guard a COUNTED DIFF, every arm red by name

Each arm: restore from the finished snapshot with plain `cp` → locate the target by a grep that
**must match exactly once or the arm aborts** → plant → **diff against the snapshot and require
exactly the intended line counts** → run → restore. ⚠ **No md5 was used as a sabotage guard**: A1's
verifier had an arm lose its line address and become a global substitution while an md5 check passed.

⚠ **The red-extractor was fed the empty case before it was trusted.** Both controls returned
`DIED(no RESULT line)`, never `(none)` — a gate that answers "no failures" to silence is decoration,
and this batch has discarded five results to exactly that hole.

| | sabotage | diff guard | reds |
|---|---|---|---|
| S1 | `caption_of` loses its never-empty guard | −1/+0 | **`LB4`** alone |
| S2 | the `belowmin` refusal names the slot again | −1/+1 | **`LB3` `MP11`** |
| S3 | `field_caption_for_row` forgets the row's mode | −1/+1 | **`LB3`** alone |
| S4 | `meas_flabel` keeps its own copy of the rule | −1/+11 | **`LB5`** alone |
| S5 | A4 reversed — dc `Stop` goes bare | −1/+1 | `LB6` · **`G2dc`** |
| S6 | A5 reversed — the caption is an instruction | −1/+1 | `LB7` · **`G2c`** |
| S7 | the note is dropped from tran's `needs` | −1/+1 | **`LB8`** alone |
| S8 | the detail line stops saying "simulates from 0" | −1/+1 | **`LB7`** alone |
| S9 | the S-parameter refusal shouts the token again | −1/+1 | **`LB9`** alone |
| S10 | A1's `SEGFAULTS` lowercased | −1/+1 | **`LB9`** alone |

**S2 reds two rows and that is declared, not discovered**: `belowmin` feeds both `MP11`'s golden and
`LB3`'s per-row caption sentence. Seven of the ten arms red exactly one row, so these are not rows
that redden at everything.

**Ends on a positive restored-tree row**: `src/ase.tcl` and `src/ase_window.tcl` md5-equal to the
finished snapshot, **`test_ase_core` ALL PASS (662)** and **dialogs display 387 passed (`G2sens`
only)**.

## Corrections — three things I got wrong, two of them caught by measurement

| | |
|---|---|
| **C1** | ⚠ **I claimed the wrong guard in a source comment, and the sabotage caught it.** The `meas_rule` comment said `SEGFAULTS` is *"pinned by test_ase_preflight's section PF234"*. Arm **S10** lowercased it and `test_ase_preflight` came back **ALL PASS (238)**. `PF234a` pins a **different** occurrence — the `disto` precondition's `ngspice SEGFAULTS,` at `ase.tcl:13098` — and that suite has never looked at this sentence. **`LB9` is the only row standing between this exception and a tidy-up.** The comment now says so. Had I not sabotaged it, a false citation would have shipped. |
| **C2** | ⚠ **I overclaimed a guard and corrected it before it shipped.** Both the source comment and the R9 entry said *"Row LB7 fails if it is ever hardcoded"*. That is **false**: a frozen copy of today's caption is byte-identical to what the accessor returns, so nothing reddens at the moment somebody freezes it. What LB7 really catches is the *consequence* — the day the caption is reworded, the accessor moves and the frozen copy does not. Found while writing the sabotage plan, when I could not construct an arm for my own claim. All three places now state the weaker, true guarantee. |
| **C3** | `G2dc`'s golden was written as a literal brace-string `{{Start:} {Stop value:} …}` and reddened against the canonical list form (`Start:` needs no braces). Rewritten as `[list …]`. A one-line Tcl-formatting slip, caught by the run, recorded because it briefly looked like a real caption failure. |

## ⚠ Found and NOT fixed — stated plainly

1. **The dc form's `Start` is still bare.** A4's ruling header says *"no caption is bare"* but its
   **table names `Stop` and `Step` only**, so `Start` is reported rather than tidied by a crew.
   It is pinned as-is by **LB6**'s last term and **G2dc**'s, so the next reader sees where the ruling
   actually stopped instead of inferring it was missed. **This is the driver's to raise with the user.**
2. **The `spec` measurement form's `Start` / `Stop` / `Step` (unit Hz) are also bare** —
   `src/ase.tcl` `spec` entry, handles in the `R9-334`…`R9-337` band. R9's own notes call these
   *"§A4's inconsistency, one dialog further on"* and *"a third/fourth instance of the same bare
   word"*. **Outside A4's table, so untouched.**
3. **`R9-361`'s remedy still names ngspice's deck words `FIND, MIN, MAX or AVG`**, not the four kind
   labels, so a user still cannot look those six words up in the picker. R9-361's own note raises it;
   §A3's ruling does not cover it; left for §A12's crew.
4. **`unknownkey` deliberately still names the user's own typed key** (`has a setting named
   'legacykey' that ASE-L cannot emit`), and `group` still names the group (`second sweep`). Neither
   is a form caption — the first is a word the user typed into the Options editor — so resolving them
   through the caption accessor would be wrong. Not an oversight.
5. **`ase::ui::nz_arg_label`** (`ase_window.tcl`) is a *third* variant of the caption shape, over the
   stimuli/trnoise registry, with a `unit source` special case the other two lack. **Not folded in**:
   it is not the same rule, and forcing it would be scope this ruling does not cover. Reported so the
   "one accessor" claim is not read more widely than it was measured.
6. **No `:0` or `$DISPLAY` run was taken** — the display arm here is `:99`. **No pixel deliverable is
   claimed** and no `look` debt is discharged by anything here.

## New copy — reported, not ruled on

Implementing A5 **mints two sentences the user has never seen**, exactly as implementing A1 minted
`R9-727`/`R9-728`: A5 ruled that the meaning must *move*, not what words should carry it.

* **`R9-729`** · caution — `$sim still simulates from 0 and only discards the output before $_ts, so this shortens the results file and not the run`
* **`R9-730`** · fix — `clear $caption to keep the whole waveform`

Both are recorded in `R9_COPY_REVIEW.md` §A5 under a `⚖ NEW COPY THIS RULING PRODUCED` block marked
**NOT YET RULED ON**, following A1's precedent, and the header count moves **728 → 730** (line 14).
Issue count stays 38: these arise from a ruling, not from an issue.

⚠ **Bookkeeping, measured:** `grep -c '^\*\*R9-'` is **727** and distinct anchored handles **726**,
*unchanged* — R9-729/730 live inside a blockquote and so do not match the anchor, exactly as
R9-727/728 do not. That is why 726 bare handles coexists with the document's *"730 strings"*.

⚠ **No `owed.sh add rule` was filed for these two, and that is a judgement I am flagging upward
rather than making silently.** The standing rule says a new user-facing sentence gets a `rule` debt;
against that, ⚖ R9 **is** the open ruling that collects exactly these, the document now carries them
as unratified, and A1's two were handled the same way with no debt filed. Given issue 1400's
cross-clone destruction risk I did not write the shared ledger on my own initiative. **If the driver
wants a debt, it is one command.**

## What rests on sabotage, and what rests on a name diff alone

**On sabotage (a named row reddened and was restored):** every claim about `LB1`–`LB9`, `G2dc`,
`G2c`, and the one-accessor property. **On a measured rendered string** (probe logs, quoted above):
every sentence in the handle table. **On a name diff alone — weaker, and said so:** the six suites
that did not move (`preflight`, `optsheet`, `meas`, `window`, both `trnoise`) are regression cover; I
did not sabotage them to prove they *could* move. **`test_ase_meas_1443` is the one that matters
there**, because it is `meas_flabel`'s regression cover and it is green at 113 against the
delegation — but its rows were not individually proven to witness a `meas_flabel` change.

> ### ⚠ DRIVER CORRECTION, 2026-09-16 — this paragraph's doubt was right, and understated
>
> **`test_ase_meas_1443` is not `meas_flabel`'s regression cover. It cannot be.** The verifier
> replaced the proc body with `error "…WAS CALLED"` and the suite still finished **`ALL PASS
> (113)`** — it never calls it. So "113 green" is not weak evidence for the delegation, it is
> **no evidence at all**, and the suite-table row above has been corrected to say so.
> **`LB5` is the only headless cover** for that delegation.
>
> This crew flagged the right suite for the right reason and then trusted it one notch too far.
> Naming the doubt is what let the verifier aim at it — which is the whole argument for writing
> down what rests on a name diff.
>
> **And "one accessor, never a second table" is REFUTED as stated.** Three further bodies resolve
> captions their own way: `ase::meas_verdict`, `ase::meas_template_expand` and
> `ase::ui::meas_tpl_show`. **Two of them are refusals that drop the unit** — `needs a value for
> Fundamental` against a form captioned `Fundamental (Hz):` — which is **§A3's own defect, still
> live, in the measurement registry**, across 14 measured divergent fields. The claim is true of
> the *analysis* registry, which is what was sabotaged; it was never true of the measurement one.
> **This is scheduled as A3's remainder in task 3**, not raised as a new ruling: finishing §A3
> where it does not yet reach is implementing a ruling already given.
>
> Two further narrowings recorded rather than left to be rediscovered: **`LB2`'s
> Advanced-clause half is a construction argument, not a demonstrated red** (no field is both
> `advanced 1` and `required 1`; the focus half *is* demonstrated, and breaks for real when the
> tuple carries the caption), and **§A5's form-note surface is gated on a warm netlist** —
> `precheck_banner` returns `state cold` otherwise, so the fact is reachable but not
> unconditionally on screen.

## Hygiene

* **Every command carried a `timeout`.** One command (the sabotage campaign) exceeded the foreground
  window and was backgrounded by the harness; **I polled it myself in the foreground under a
  self-announcing deadline** (`FINISHED after 10s (11 arms)`), never left it to wake me. Every waiting
  loop reported progress and liveness on the way out. No run ended without a named verdict.
* **Processes matched by NAME** (`ps -eo comm=,args=` with `$1=="sh"`), never `pgrep -f` or a pattern
  my own argv contained. **No `pkill`.** Alive at hand-over and named rather than waved past: `Xvfb`
  (the shared `:99` dev display) and **two `xschem`** processes that predate this session. **No
  `ngspice` process at any point** — I started no simulator.
* **Binary always by path** (`./src/xschem`, `devdisplay.sh exec ./src/xschem`), always `--nolog`,
  never `--logdir`, never a bare `xschem`.
* **Snapshots archived.** Pristine and finished copies are moved to
  `…/scratchpad/a345/ARCHIVED_DO_NOT_RESTORE/` and `sab.sh` is renamed `sab.sh.disarmed`, so a stale
  waiter cannot fire a restore over a later tree. **Campaign logs are kept** beside them as this
  receipt's evidence (`logs/sab_results.txt`, `logs/probe*.log`, 66 files).
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching anything.**
