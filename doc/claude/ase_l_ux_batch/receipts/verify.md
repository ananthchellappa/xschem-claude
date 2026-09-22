# Adversarial verification — Stage 3, F1, F2

**Crew:** ADVERSARIAL VERIFIER. **Tree:** `fluid-editing` @ `6a0d1126`, working tree
**uncommitted**, as the implementer left it. **Date:** 2026-09-21.
**Input:** `receipts/impl.md`, `receipts/recon.md`, `PLAN.md`, `LEDGER.md`, `README.md`.
**Binary:** `make -C src` → `Nothing to be done for 'all'` before the first measurement, so
`src/xschem` (1 688 152 bytes, 22:50:07) is this tree. The changed files are all `.tcl` and
are read from `src/` at run time.
**Isolation:** my own private **Xvfb `:241`** + openbox 3.6.1, `HOME=/var/tmp/xsr_ux/v1/h`,
`GUI_GATE=0`. The dev display `:99` was never touched and is still up; `~/.claude` was never
written; no commit; no `git checkout`/`restore`/`stash`/`clean` at any point — every revert
was `git show HEAD:<f> > <f>` or a `perl -0pi` edit, and every restore was a `cp` from a
pristine copy taken before the first edit, **md5-verified after each one**.
**Scratch:** `/var/tmp/xsr_ux/v1` (18 characters), **peak 2 816 KiB**, deleted at the end.

Code is cited by proc name. The tree is **byte-identical to the delivered state** at the end
of this run — `git diff --stat` reproduces the opening snapshot exactly and the untracked set
is unchanged.

---

## Verdict

**No blocker.** Every claim in `impl.md` that I re-ran reproduced, three of the seven
sabotages reproduced **exactly** (count *and* row names), and the pre-existing 295 checks all
still pass against the changed sources. Two rulings were correctly refused rather than
assumed, and the technical premise of each verifies.

Findings below: **0 blocker · 0 must · 3 should · 4 nit.**

---

## 1. Measured true — what I ran myself

### 1.1 The suite, reproduced on an independent display

| run | result |
|---|---|
| `test_ase_window`, GUI arm, delivered tree (via `run_suites.sh`) | **ALL PASS (333 checks)** |
| `test_ase_window`, GUI arm, delivered tree (second run, after all sabotage/restore cycles) | **ALL PASS (333 checks)** |
| `test_ase_window`, `--nogui` arm, delivered tree | **71 checks, OVERALL: ok** |

Both figures match `impl.md`. No `SKIPPED:` line appeared in either arm, so the 333 is the
full complement — including `UX1499a9`, which self-skips on a window manager that will not
squeeze the status segment.

### 1.2 The floor — nothing pre-existing was lost

The sharpest form of check (4): **HEAD's test file against the delivered sources.**

| arm | result |
|---|---|
| `git show HEAD:tests/headless/test_ase_window.tcl`, GUI arm, delivered sources | **ALL PASS (295 checks)**, 0 FAIL |
| same, `--nogui` arm | **56 checks, OVERALL: ok** |

So the floor really is **295 → 333** and **56 → 71**, and not one pre-existing check was
broken, skipped or silently dropped by the source change.

**+38 new `check` calls**, counted off the diff: 15 `RD1498*` (headless) + 23 GUI
(1 `UX open_state` fixture anchor + 5 `UX1498*` + 10 `UX1499a*` + 5 `UX1499b*` + 2
`UX1499c*`). 295 + 38 = 333. ✔

### 1.3 Sabotage — three reproduced exactly, one whole-change revert

| sabotage (mine) | measured | `impl.md` claimed |
|---|---|---|
| `ase::quiet` body → bare `uplevel` | **3 FAILED (68 passed)** — `RD1498g` `RD1498h` `RD1498h3` | 3 FAILED (68), same three ✔ |
| `ase::ui::tip_attach` → `return $W` | **2 FAILED (331 passed)** — `UX1499a` `UX1499a10` | 2 FAILED (331), same two ✔ |
| `results_refill` dropped from `load_state_commit` | **2 FAILED (331 passed)** — `UX1498c` `UX1498d` | 2 FAILED (331), same two ✔ |
| **both source files reverted to HEAD**, new tests kept | `UX1498a` `UX1498a2` `UX1498c` `UX1498d` `UX1499a` red by name, plus three `UNEXPECTED ERROR` aborts | — |

A narrower variant is worth recording because it shows the rows are *specific*, not a block:
deleting only the one-line mute check inside `ase::echo` (leaving `ase::quiet`'s counter
intact) reds **2**, not 3 — `RD1498g` and `RD1498h` — and leaves `RD1498h3` green, which is
correct, because `h3` asserts the counter and not the mute.

The whole-change revert also reproduced the **defect narrative** verbatim, which is the part
that matters: `UX1498c` returned `{1 10}` where the fix returns `{1 812.3m}` — the previous
state's number standing under the new state's output name — and `UX1498d` returned
`{1 7.778}`, the planted value still on screen after loading a state whose rundir holds no
raw. Both halves of issue 1498 are real and are now pinned.

### 1.4 Nothing user-visible moved that the plan did not authorise

Three independent measurements, all on check (2):

* **No new user-facing text at all.** Every added non-comment line in `src/ase.tcl` and
  `src/ase_window.tcl` was scanned for `ase::echo`, `-text`, `-label`, `wm title`,
  `tk_messageBox` and `puts`: **zero hits.** The only new strings in the diff are comments.
* **The log window is the same size.** The pack→grid move was reproduced standalone with the
  identical widget options: `PACK(before) 689x412` · `GRID(after, hsb hidden) 689x412` ·
  `GRID(after, hsb shown) 689x425`. **No size change while the bar is hidden**; +13 px of
  height only when a line actually overflows, which is what stage 3(ii) asks for.
* **`ase::quiet` has exactly one caller** — `results_from_disk`, at `src/ase_window.tcl:2442`.
  This is the load-bearing claim behind the implementer's "the silence is not a ruling", and
  it verifies: the mute can only ever wrap code that did not exist before, so **no message
  the user used to see can have become invisible.**

The three genuinely new user-visible behaviours are exactly the three the plan names:
numbers in the Value column (F2), a tooltip on a clipped cell (3(i)), and a horizontal bar in
the log window (3(ii)). See finding **S1** for the one place the *instance* deviates from the
plan's wording.

### 1.5 The two refused rulings — both premises verify

* **⚖ R-U2** (`Results > Select`). `ase::has_results` → `ase::results_stale`
  (`src/ase.tcl:17891`, `:17944`) are keyed on **the session's own** `last_rawfile` against
  **the session's own** `deck_file`. Confirmed by reading: neither can be pointed at a
  hand-picked file, so feeding the Value column from `rsel_commit`'s selection really would
  bypass issue 0838's guard. **Refusing the plan's third call site was right**, and raising it
  rather than deciding it is right — the user would see different numbers under the same
  names, which is squarely theirs.
* **⚖ R-U1** (the visible `…`). The plan's `Rulings: none` for stage 3 rests on a
  precondition — *"the full string stays in the item's `-values`; only the DISPLAY is
  truncated"* — that a `ttk::treeview` cannot satisfy. I reviewed the argument in issue 1499
  and did **not** independently measure it; it is consistent with ttk's documented behaviour.
  Either way the ellipsis changes what the user reads in a cell, so holding it is correct.

`impl.md` also calls the reader through `[ase::backend_hook $sim result_probe] $st $logtext`,
which is the **same call shape** `ase::run_done` already uses at `src/ase.tcl:17670`. The
"no backend hardcoded into the UI" claim verifies.

### 1.6 The batch record matches the tree

| claim | measured |
|---|---|
| item 1 = `5fb8f465` | exists, `fix(1396): Save State asked nothing before it destroyed an existing state`, `src/ase_window.tcl` +172/−11 ✔ |
| item 2 = `4ddc4900` | exists, `fix(1398): ASE-L rendered in a typeface nobody chose`, `ase_window.tcl` + `xschem.tcl` ✔ |
| item 2 follow-up = `2f1fad58` | exists, `fix(1398): ASE-L came back three points smaller than it went in`, `src/cadence_style_rc` +25 only ✔ |
| README's `git diff --stat 437a3add 2f1fad58 -- src/` = **+742/−56** | exact, across exactly those three files ✔ |
| README's *"~300 commits"* since `437a3add` | **299** ✔ (33 of them touch `ase_window.tcl`) |
| PLAN's baseline of **7 491** lines | exact at `437a3add` ✔ |
| `pane_hscroll` → `hscroll_autohide` rename | **zero live-code leftovers** tree-wide ✔ |
| `tclsh tests/headless/issue_stamp.tcl` | `self-test PASSED (180 parser cases)` → **`ok (0 problems)`** ✔ |
| 1498/1499 free, pointer → 1600 | band check silent; the only other-clone hits are op-wcard's **band table** and its **example line**, no issue file; 1600 is what CLAUDE.md's own rule prescribes ✔ |
| *"no repo litter"* | untracked set **unchanged** from session start; `.xschem/` and `debug_st1/` carry Sep 5/Sep 9 mtimes and predate this work ✔ |

The README's former *"Nothing here has been implemented"* is gone and the replacement is
accurate. `2f1fad58` now has its own ledger row, and item 2 has its hash.

### 1.7 Neighbouring suites, re-run by me on the delivered tree

```
test_ase_window   ALL PASS (333)      test_ase_core     ALL PASS (675)
test_ase_persist  ALL PASS (153)      test_op_annot     ALL PASS (492)
test_ase_dialogs  4 FAILED (385 passed)   <- PRE-EXISTING, proved independently (S2)
```

All four green counts match `impl.md` exactly. **T1 was not run** — the driver gates, solo.

---

## 2. Findings

### S1 · should — the status-bar tooltip landed on two segments the plan does not name, and not on the one it does

`PLAN.md` stage 3(i) authorises the tooltip on *"the three panes, the Simulators `Program`
column and the status bar's **last** segment."*

Measured, from the four `ase::ui::tip_attach` call sites and the `pack` order in
`ase::ui::build`: the bar packs `win sep1 stat sep2 temp sep3 sim sep4 state sep5 health`, so
the **last** segment is `health` — and `health` is **not armed**. Armed instead are
`status.sim` and `status.state`. `health` is not a word but a built string
(`"<prefix> <val> <name>, <val> <name>, …"` from `ase::ui::health_text`), so it is
clippable and the plan's choice was not arbitrary.

Likewise `simulators_dialog` arms the **whole** `$w.tv`, not the `Program` column the plan
names — so a clipped cell in any of that table's columns now offers a tip.

**Why it is a `should` and not a blocker:** no wording, sizing or placement changed — this
adds a hover affordance, gated on real clipping, in a class the stage explicitly authorises.
The reasoning is written into the source comment at the call site. **What is missing is that
neither `impl.md` nor issue 1499 records it as a departure from the plan's text**, so an
auditor asking "did stage 3(i) ship what it said?" gets a different answer from the plan than
from the tree. Either arm `health` too, or say in the issue file that the plan's "last
segment" was read as "the segments that carry a name".

### S2 · should — `test_ase_dialogs`'s pre-existing red is real, but the receipt's "identical seven rows" does not reproduce

`impl.md` §6 and `LEDGER.md` both record **7 FAILED (382 passed)**, rows `G2sens`, `G2f`,
`G8c` ×2, `GG3`, `GG9`, `GN1b`.

Measured here on `:241` + openbox 3.6.1: **4 FAILED (385 passed)** — `G2sens`, `GG3`, `GG9`,
`GN1b`. The suite total is 389 either way; my four are a strict subset of their seven.

**I confirmed the conclusion independently and by a stronger route than the count:** both
changed source files were replaced with `git show HEAD:` copies and the suite re-run on the
same display → **identical `4 FAILED (385 passed)`, identical four rows**, then restored and
md5-verified. So the red is **not** caused by this change. ✔

But the *number* is display-dependent, and `impl.md` presents it as a fixed fact
("the identical seven rows, the identical values"). A later crew using 7/382 as a gate
baseline will read a spurious change. **Record it as environment-dependent, or as a range.**
This also makes the implementer's decision not to file an issue for it look better than
stated: the flakiness *is* the evidence it is environment-shaped.

### S3 · should — the new headless block sits outside a `catch`, and a raise in it silently costs ~250 checks

Measured on the full revert: `ase::ui::results_from_disk` being undefined produced

```
ok:   P4 arg_summary dc row
UNEXPECTED ERROR: invalid command name "ase::ui::results_from_disk"
ok:   D1398 the shipped dark option database really is in force ...
UNEXPECTED ERROR (D1398 block): invalid command name "w1f_colscan"
...
RESULT: 8 FAILED (42 passed)
```

The `RD1498` block is inserted at file scope just after `P4`, and a raise inside it skips
**everything between `P4` and the `D1398` block** — the whole `L1398` and `W` sections — and
then cascades into `D1398`, whose `w1f_colscan` is defined in the block that never ran. The
suite still prints a plausible verdict: `8 FAILED (42 passed)`, where the suite runs 333.

The implementer **documented this exact hazard** in `impl.md` §8 as a warning for the next
crew, and wrapped the new **GUI** block in `if {[catch { … } ux_bigerr]}` — but left the new
**headless** block unguarded, which is the inconsistency. This is the coverage-loss class of
issue 1487 (a verdict that does not say what it lost). Internal engineering, so not a ruling:
wrap the `RD1498` block the same way the `UX` block is wrapped.

### N1 · nit — `impl.md` §4's row arithmetic is off by one in one line

`impl.md` says *"**`UX1499a`–`UX1499a10`** (11 checks, GUI)"* and *"15 headless + 22 GUI"*.
Counted off the diff: `UX1499a`, `a2`…`a10` is **10** rows, and the GUI total is **23**
including the `UX open_state -> 1` fixture anchor. The totals still land correctly
(295 + 38 = 333), and `NUMBERING.md`'s own "20 rows" (1498) and "17 rows" (1499) are both
**exactly right** — it is only the receipt's breakdown line that slipped.

### N2 · nit — README understates the file it is warning about

README says `src/ase_window.tcl` is *"12 000+ lines against the plan's 7 491"*. Measured:
**15 454** in the working tree (**15 170** at `6a0d1126`). True as written, but the point of
the sentence is the size of the drift, and 15 k makes it better than 12 k does.

### N3 · nit — the status-bar tips are pointer-anchored, where the tree documents widget-anchored as load-bearing for status bars

`ase::ui::tip_show` calls `balloon_show $W $txt 0`. That is **exactly** what the neighbouring
`ase::ui::rsel_tip_show` does, so the in-file convention is followed and the "one renderer"
claim is honest. But `balloon_clipped`'s own header (`src/xschem.tcl`, issue 1368) records
`pos 1` rather than `pos 0` for clipped **labels**, and gives the reason in terms of a status
bar: *"A status bar sits on the bottom edge of its window, which is exactly where
`balloon_show`'s vertical FLIP is load-bearing."* The status-bar segments armed by S1 go
through `label_clipped` (the right gate) but then render at `pos 0`.

`balloon_show` has clamps for both anchors, so this may well be fine — but it is **untested
by construction** (the rendered balloon is not drivable from a script; the implementer
declares this). Worth an eye when the R-U1 eyeball debt is paid.

### N4 · nit — `tip_motion` does the full resolve on every `<Motion>` event

`tip_motion` calls `tip_text` → `cell_tip_text` (three `$W identify` calls plus a
`font measure`) **before** comparing against the cached answer, so the work happens per
motion event on three treeviews rather than per change. Bounded and cheap, and the caching is
on the answer — which is the correct thing to cache, per `balloon_clipped`'s header. Only
worth revisiting if a pane ever gets large.

---

## 3. Two things the driver still owes

1. **`owed.sh add rule 1499`** (⚖ R-U1) and **`owed.sh add rule 1498`** (⚖ R-U2). Verified
   outstanding: `~/.claude/xschem_owed/rule/` carries **no** entry for either number. The
   implementing crew was forbidden to write `~/.claude`, and so was I.
2. **The T1 gate**, solo. Not run by either crew, by instruction.

`test_ase_dialogs`' four (or seven) reds are **pre-existing and proved so twice** — do not
read them as this item's.

---

# Fix round — the one round, 2026-09-21

**Crew:** FIXER. **Tree:** `fluid-editing` @ `6a0d1126`, working tree **uncommitted**, as
the implementer left it and the verifier confirmed it.
**Input:** `receipts/recon.md`, `receipts/impl.md`, and §2 of this file.
**Binary:** `make -C src` → `Nothing to be done for 'all'` before the first measurement, so
`src/xschem` (1 688 152 bytes, 22:50:07) is this tree. Everything changed is `.tcl`, read
from `src/` at run time.
**Isolation:** my own private **Xvfb `:251`** + openbox 3.6.1, `HOME=/var/tmp/xsr_ux2/f1/h`,
`TMPDIR` inside the same scratch, `GUI_GATE=0`. The dev display `:99` was never touched and
is still the only abstract socket besides `X0`; `~/.claude` was never written; no commit; no
`git checkout`/`restore`/`stash`/`clean` at any point — every revert was `git show HEAD:<f> >
<f>` or a `perl -pi` edit, and **every restore was a `cp` from a pristine copy taken before
the first edit, md5-verified immediately after.**
**Scratch:** `/var/tmp/xsr_ux2` (16 characters), **peak 4 544 KiB** on disk / 4 461 KiB
apparent, deleted at the end. Nothing outside it was created.

## Verdict

**S3 fixed and proved by A/B. S1 fixed rather than merely recorded — and recorded as well.
S2, N1 and N2 corrected in the documents. N3 applied and upgraded from a nit on
measurement. N4 left, with the reason.**

`test_ase_window` **ALL PASS (336)** GUI · **ALL PASS (71)** `--nogui`. The +3 is three new
rows; nothing pre-existing moved.

---

## S3 · FIXED — the `RD1498` block now has its own `catch`, and the A/B is the proof

The block sat at file scope inside the outer `catch` that opens above the `W` section, so a
raise anywhere in it skipped every row from there to that catch's closing arm and then
cascaded into `D1398`, whose `w1f_colscan` is defined in a section that never ran.

**The fix** (`tests/headless/test_ase_window.tcl`): `if {[catch { … } rd_bigerr]}` around
the fixture and the rows, with `puts "UNEXPECTED ERROR (RD1498 block): …"` and `incr fail` —
the same idiom the `UX`, `D1398` and `R` blocks already use in this file, and at the same
zero indentation as the `R` block, so the diff is six lines and reviewable at a glance.

⚠ **The two `proc` definitions are deliberately left OUTSIDE the guard.** `rd1498_raw` is
called by the `UX1499` block later in the file, so a `catch` that swallowed the proc
definitions would convert one dead block into two. They are the first statements in the
section and cannot realistically fail; everything that can is inside.

**Proved by forcing the exact hazard `impl.md` §8 documents** — a state view type with no
`_state` in it, which `library_new_view` refuses with `unknown view type`. Identical
sabotage, identical display, identical sources; only the test file differs:

| | verdict | what the suite said |
|---|---|---|
| **A — as delivered** | `RESULT: 2 FAILED (63 passed)` | `UNEXPECTED ERROR: unknown view type: ngspice_rd1498X` (the **outer** catch — it does not name the block) then `UNEXPECTED ERROR (D1398 block): invalid command name "w1f_colscan"` |
| **B — wrapped (the fix)** | `RESULT: 1 FAILED (318 passed)` | `UNEXPECTED ERROR (RD1498 block): unknown view type: ngspice_rd1498X` — one line, named |

**A reports 65 of 333 checks and calls the run 97 % green.** B reports **319 of 333** and
one named failure: `333 − 318 = 15`, which is exactly the `RD1498` block's own 15 rows and
nothing else. The `L1398`, `W`, `D1398`, `UX1498` and `UX1499` sections all ran in B — 32
`W1a` rows, 17 `UX1499`, 11 `D1398`, 7 `L1398` and the rest — and all of them were absent
from A.

⚠ **A second finding fell out of this, and it is the driver's to weigh, not mine to fix.**
My first sabotage was the verifier's — deleting `ase::ui::results_from_disk` — and it is
*broader than the RD1498 block*, because `ase::ui::close` calls `results_refill` → the
deleted proc. It therefore raises at `H4`, long **before** the `RD1498` block, and the
suite reported `RESULT: 3 FAILED (13 passed)` — **13 checks of 333, and a verdict line that
looks like an ordinary red.** The S3 wrap cannot help there and is not meant to: the
swallowing catch is the pre-existing outer one spanning the whole `H`/`P`/`L1398`/`W`/`R`
body, which has been in this file since long before this batch. **Wrapping that properly is
a restructure of the file, not a fix-round edit**, so I am naming it rather than doing it.
It is the same class as issue **1487** (a verdict that does not say what it lost) and it is
worth a number of its own.

## S1 · FIXED, and the departures are now written down in both places

The plan authorises the tooltip on *"the three panes, the Simulators `Program` column and
the status bar's **last** segment."* Two things differed; I judged them separately, on
measurement, and they went opposite ways.

**`health` — armed.** Measured before deciding: `ase::ui::health_text` returns `{}` unless
`ase::runhealth_strip` produces counters, which needs `runhealth` on the bench, **which none
of the 104 committed benches sets**; and `ase::ui::label_tip_text` returns `{}` for an empty
`-text` before it ever reaches the gate. So arming it is **one word** in an existing
`foreach`, through the same gate and the same renderer, and on every bench in the tree it
changes nothing a user can see. It is trivially the same class of change — and it moves the
code *towards* the plan's wording rather than further from it. Done:
`foreach _seg {sim state health}`.

**The Simulators dialog — left as the whole table, deliberately.** Narrowing `simulators_dialog`
to the `Program` column means teaching the handler a column allow-list, and the effect would
be to leave a clipped cell in another column of that same table unreadable — the precise
defect this issue exists to close. The gate is per cell and unchanged, so a cell that fits
still offers nothing. **This one is a real departure from the plan's text and it stays**,
which is why it is now written down.

**Both are recorded** in issue 1499 under a new heading — *"Two departures from `PLAN.md`
stage 3(i)'s wording, both deliberate, both recorded"* — with the mechanism and the reason,
so an auditor asking *"did stage 3(i) ship what it said?"* gets the same answer from the
issue file as from the tree. Neither is a ruling: no wording, sizing or placement changes and
no new text appears anywhere, so under the standing rule they are mine to decide and state.

**Pinned**, because a departure nobody can re-derive is a departure nobody will maintain:

* `UX1499a9b` — all three segments armed, `health` named as the one `PLAN.md` names.
* `UX1499a9c` — the anti-vacuity half: `health` carries no text and owes no tip, so arming
  it is invisible to a user who never asked for the counters.

## S2 · CORRECTED — and measured a third time

`test_ase_dialogs`' pre-existing red is **display-dependent and is not a gate baseline.**
Three private Xvfb displays, all openbox 3.6.1, all against `6a0d1126` sources:

| display | verdict | rows |
|---|---|---|
| `:235` (implementer) | 7 FAILED (382 passed) | `G2sens` `G2f` `G8c` ×2 `GG3` `GG9` `GN1b` |
| `:241` (verifier) | 4 FAILED (385 passed) | `G2sens` `GG3` `GG9` `GN1b` |
| **`:251` (this round)** | **4 FAILED (385 passed)** | **`G2sens` `GG3` `GG9` `GN1b`** |

Suite total **389** on all three. I proved it pre-existing independently rather than
inheriting the conclusion: **both** changed sources replaced with `git show HEAD:` copies,
suite re-run on the same display → **byte-identical verdict, the identical four rows** —
then restored from the pristine copies and md5-verified (`1a844581…` / `0167978e…`).

**Stated the way it should be used, in `impl.md` §6 and `LEDGER.md`:** an environment-shaped
red of **4 to 7 rows out of 389**, pre-existing at `6a0d1126`, proved three times by the
source-swap. **Quote the proof method, never the number** — a crew holding 7/382 that
measures 4/385 reads a four-row improvement that did not happen, and one holding 4/385 that
measures 7/382 reads a regression that did not happen either.

## N1 · CORRECTED — `impl.md` §4

`UX1499a`…`a10` is **10** rows, not 11; the GUI total is **23**, not 22 (the breakdown
omitted the `UX open_state -> 1` fixture anchor). Counted off `git diff -U0 HEAD` rather
than by hand. ⚠ **The instructive part is why it survived:** 295 + 15 + 23 = 333 checks out,
and so does 295 + 15 + 22 + 1. **The sum was right while two of its terms were wrong**, so
the total could not catch it. Corrected in place with a dated note, plus today's figures —
`UX1499a` is now **13** rows, the GUI total **26**, the new-check total **41**, the suite
**336** / **71**.

## N2 · CORRECTED — `README.md`

`src/ase_window.tcl` at `6a0d1126` is **15 177** lines, measured twice by two methods
(`wc -l` and `awk 'END{print NR}'`, both agreeing because the file ends in a newline);
**15 454** in the working tree as delivered, **15 480** after this round; **7 491** at the
plan's baseline `437a3add`. The README's *"12 000+ lines"* was true and understated the
drift the sentence exists to warn about by 3 000 lines — "12 000+" reads as a file that grew
by half, and **the file has doubled**. ⚠ This finding's own figure is off too: N2 above says
**15 170** for `6a0d1126`, which is 7 short. Take 15 177.

## N3 · APPLIED — and it is stronger than a nit once the precedent is checked

`tip_show` passed `balloon_show … 0` (pointer-anchored) for **every** class. The defence was
that `ase::ui::rsel_tip_show` does the same. **It does — but it is bound to `$f.tv`, a
Treeview**, so the in-file precedent covers treeviews only and is **silent about labels**.
The documented, *measured* rule for a clipped **label** points the other way, and states its
reason in terms of a status bar: `balloon_clipped`'s header (`src/xschem.tcl`, issue 1368)
records `pos 1` after a moved `pos 0` tip was seen landing under the pointer, destroyed by
its own `<Leave>`, and flickering **25 times in 1.5 s** — *"A status bar sits on the bottom
edge of its window, which is exactly where `balloon_show`'s vertical FLIP is load-bearing."*
ASE-L's bar is `pack -side bottom`. So one side of this had a measurement and the other had
a misread precedent.

**The fix is four lines**, and it is the same class split `tip_text` already makes:

```tcl
proc ase::ui::tip_show {W txt} {
  set pos 1
  if {![catch {winfo class $W} cls] && $cls eq {Treeview}} { set pos 0 }
  catch {balloon_show $W $txt $pos}
}
```

A treeview **cell** keeps `pos 0` — `pos 1` would anchor at the whole table's bottom-left
corner, which on an eight-row pane can be far from the row under the pointer.

⚠ **And it turns out not to be "untested by construction" after all**, which is the part
worth keeping. The *rendered balloon* is undrivable — `balloon_show` returns early unless
the X pointer is physically over the widget — but **which anchor is asked for** is perfectly
drivable: row `UX1499a11` renames `balloon_show`, records `{class pos}` for one cell and two
labels, restores it, and asserts `{{Treeview 0} {Label 1} {Label 1}}`. That converts a
convention into a rule the tree enforces and leaves only the pixels as an eyeball debt.

## N4 · LEFT, and this is the reason

`tip_motion` resolves through `tip_text` → `cell_tip_text` (three `$W identify` calls and a
`font measure`) before comparing against its cache. I looked for the cheap safe version and
**there isn't one.** The only meaningful short-circuit is to cache the `(item, column)` the
pointer is over and skip the resolve when it has not moved — and that is caching the
**wrong key**. A cell's *text* can change under a stationary pointer (`results_refill`
repaints the Value column on a Load State) and so can its *width* (a dragged divider), and
in both cases a coordinate-keyed cache serves a stale tip or withholds an owed one.
`balloon_clipped`'s own header records this exactly — *"A periodic caller must therefore
cache on the ANSWER — the string and the clipped verdict — and not on the pixels"* — after
issue 1384 shipped a status-bar tooltip that was unreachable 3/3 for the neighbouring
version of this mistake. **The code already caches on the answer, which is the correct key.**
The cost being optimised is four widget queries per motion event on panes of `-height 8`;
the risk being taken is a staleness class with a shipped precedent. Not worth it. The
verifier's own framing stands: revisit only if a pane ever gets large.

---

## Suites re-run after every edit

All on the private Xvfb `:251`, openbox 3.6.1, throwaway `HOME` (via `run_suites.sh`) or
`HOME=/var/tmp/xsr_ux2/f1/h` (for the direct runs that needed the suite's own stdout).

```
test_ase_window          ALL PASS (336)   <- 333 + UX1499a9b, a9c, a11
test_ase_window --nogui  ALL PASS  (71)   <- unchanged; the three new rows are GUI
test_ase_core            ALL PASS (675)   test_ase_interact    ALL PASS  (64)
test_ase_persist         ALL PASS (153)   test_ase_final       ALL PASS  (82)
test_ase_view            ALL PASS  (36)   test_ase_simdlg_0937 ALL PASS  (55)
test_ase_simwin_variant_1471 ALL PASS (21) test_op_annot       ALL PASS (492)
test_ase_dialogs         4 FAILED (385 passed)  <- PRE-EXISTING, proved again (S2)
```

Every green count matches `impl.md` and the verifier exactly. `tclsh
tests/headless/issue_stamp.tcl` → `self-test PASSED (180 parser cases)` → **`ok (0
problems)`**. **T1 was NOT run** — the driver gates, solo.

## Sabotage — every one whose code I changed, re-run; every new behaviour, red by name

Restored by `cp` from a pristine copy and **md5-verified after each one**; no
`git checkout`/`restore`/`stash`/`clean` at any point.

| sabotage | result | rows red |
|---|---|---|
| `RD1498` fixture raise, **block un-wrapped** | `2 FAILED (63 passed)` of 333 | — *the defect: the verdict names no block and loses 268 checks* |
| `RD1498` fixture raise, **block wrapped** | `1 FAILED (318 passed)` of 333 | `UNEXPECTED ERROR (RD1498 block)` — *the fix* |
| `health` left un-armed (S1 reverted) | 1 FAILED (335) | `UX1499a9b` |
| `tip_show` → `pos 0` for every class (N3 reverted) | 1 FAILED (335) | `UX1499a11` |
| `tip_attach` → no-op *(re-run)* | 3 FAILED (333) | `UX1499a` `UX1499a9b` `UX1499a10` |
| `results_from_disk` → `{}` *(re-run)* | 7 FAILED (329) | the same seven rows |
| `load_state_commit` → no refill *(re-run)* | 2 FAILED (334) | `UX1498c` `UX1498d` |
| clip gate → always true *(re-run)* | 2 FAILED (334) | `UX1499a5` `UX1499a7` |
| **restored** | **ALL PASS (336)** | md5 of all three files back to the delivered/fixed values |

The four re-runs red **the identical rows** at exactly `+3` passed, which is the three new
rows and nothing else — so the fix round moved no pre-existing coverage. `tip_attach` is the
one that gained a row, correctly: neutering it now also un-arms `health`.

## What this round did NOT touch

`src/ase.tcl` is **byte-identical** to the delivered state (`1a844581…`). No `owed.sh`
entry was written — `~/.claude` is the driver's, and ⚖ **R-U1** (issue 1499) and ⚖ **R-U2**
(issue 1498) are still outstanding there. No T1. No commit. Nothing under `sky130A/`.

## Left for the driver

1. **`owed.sh add rule 1499`** (R-U1) and **`owed.sh add rule 1498`** (R-U2) — unchanged
   from §3 above, still outstanding.
2. **The T1 gate**, solo.
3. **A number for the outer-catch hole**, if the driver wants one: a raise anywhere in the
   `H`/`P`/`L1398`/`W`/`R` body of `test_ase_window.tcl` is swallowed by one file-scope
   `catch` that names no block, and the suite reported **13 of 333 checks** as `3 FAILED (13
   passed)` when one `src` proc went missing. Pre-existing, issue 1487's class, and a
   restructure rather than an edit — see the ⚠ under S3.
4. **The eyeball debt is now narrower but not gone.** `UX1499a11` pins which anchor each
   class asks for; nobody has yet seen either balloon rendered on a screen.
