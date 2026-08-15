# Item 08 — PIXEL — browser sidebar shell (empty) — LEDGER RECEIPT

Batch `signal_browser_batch`, branch `fluid-editing`. HEAD at item start `e5d3a8f7`
(item 7's fixup). Date 2026-08-05. Written by the ledger stage from the implementer
result **and** the independent verifier result. The implementer's long-form receipt is
preserved **verbatim** as the appendix at the bottom of this file — nothing it said was
dropped, including its own account of the void first attempt. Where the two disagree,
§1-§10 wins.

---

## 1. Verdict

**`[E]` — DONE-PIXEL.** Implemented, measured, sabotage-verified twice over, and
eyeballed by the implementer; the eyeball row is still queued for a human because a
PIXEL item's deliverable is visible UI that no test can judge.

The mark is `[E]`, **not `[x]`**, and that is not a formality here: the item's own
acceptance sentence ("sidebar width is sane and the divider is draggable if one is
added") contains a clause that **no shipped check can evaluate** — and, as it happens,
one that is **not applicable at all**, because no divider was added. See §6.

Attempt 1 of this item was **VOID, not a defer** — the scout subagent died on
`API Error: Connection closed mid-response` and the pipeline recorded a transport
failure as an engineering judgement. That `[D]` was revoked the same day, the pipeline
now returns `INFRA_FAILURE` and touches no ledger line in that case, and attempt 2 ran
from scratch with no anchors carried over. The appendix's "ATTEMPT 1 — VOID" section is
the durable record of it.

---

## 2. Commits and files touched

**Commit: `f3c89935`** — `feat(wviewer): Signal Browser sidebar shell`. NOT pushed.

⚠ **The appendix names `1b9aa319` twice** (its "Verdict" heading and its sabotage-order
line). That object was **amended away** and is reachable from no branch
(`git log --all --oneline | grep 1b9aa319` returns nothing); the amend carried the
sabotage and eyeball measurements. The shipped commit is **`f3c89935`** and nothing
else. The appendix is preserved verbatim per convention, so the stale hash stands there;
**this section supersedes it.**

| file | what changed |
|---|---|
| `src/wave_viewer.tcl` | the two arrays (`browser` authority + `browsershow` Tk mirror); `forget`'s declare+unset; `browser_build`, `browser_shown`, `browser_show`, `sync_browser_mirror`, `browser_toggle`, `browser_from_menu`, `browser_toggle_at`; the `open` call site; the `<Control-Key-l>` default bind; the `View > Signal Browser` checkbutton |
| `doc/waveform_viewer_guide.html` | one §9.1 row — `data-seq="Control-Key-l"`, `data-menu="Signal Browser" data-accel="Ctrl+L"` |
| `tests/headless/test_wave_grid.tcl` | GH0's two hard-coded literals, 14 → 15 and 9 → 10 |
| `tests/headless/test_wave_sigbrowser.tcl` | **NEW FILE** — the second test file of decision 9 |
| `doc/claude/signal_browser_batch/receipts/08_receipt.md` | the implementer receipt, now preserved below as the appendix — **written but NOT committed**, see below |

Deliberately **not** committed: `PLAN.md` and this receipt's ledger sections — the
driver's files, dirty on arrival, the shape item 7 established.

⚠ **Correction to the implementer's `filesTouched`:** it lists this receipt among the
files it touched, which is true (it wrote it) but reads as if it were in the commit.
`f3c89935` contains **exactly four** files — `src/wave_viewer.tcl`,
`doc/waveform_viewer_guide.html`, `tests/headless/test_wave_grid.tcl`,
`tests/headless/test_wave_sigbrowser.tcl`. This file is **untracked**, as are
`00_receipt.md` and `01_receipt.md`; receipts `02`-`07` are tracked and modified. That
split is pre-existing and not item 8's to resolve, but it is worth the driver's attention:
**this batch's durable record is currently half untracked.**

**Scope: CLEAN.** The verifier confirmed the diff touches nothing outside the item's
declared files.

---

## 3. Tests and check counts

| | |
|---|---|
| test file | `tests/headless/test_wave_sigbrowser.tcl` — **NEW**, created by this item |
| checks ADDED | **84** |
| checks TOTAL in that file | **84** (all of them; the file did not exist before) |
| of those, green in the `--nogui` arm | **28** (source-level / pure-Tcl only) |
| collateral file | `test_wave_grid.tcl` — no checks added, two literals bumped; **245** green after |

Both counts were independently re-measured by the verifier: X arm `ALL PASS (84)`,
`--nogui` arm `ALL PASS (28)` with both X-only groups printing their
`SKIPPED: <group> (Tk/X arm only)` banner (deliberately *not* a `full_audit` `is_skip`
string, so a blocked group cannot inflate the suite's skip count).

The file's header fixes the conventions items 9-15 inherit: one prefix per item
(8 = `BS` … 15 = `BP`), numbers blocked by arm (01-19 both, 20-39 throwaway-toplevel
fixture, 40-59 real viewer), `pcall`, the `::bgerror` override that prints AND increments
`::fail`, `bs_wait_mapped` (the `at_wait_mapped` idiom — polls the PRECONDITION and
RETURNS the mapping, so a budget expiry cannot masquerade as a result), never-throwing
readers, and `ds_spy`-shaped call recorders with POSITIVE and NEGATIVE controls.

**Driver note (c), answered:** a frame that was never created, a `pack forget` that
silently did nothing, and a correctly hidden frame all look identical to a naive check.
`bs_packed` cannot throw and every use is paired with a `winfo exists` assertion;
`bs_order top a b` returns an assertable STRING (`a-before-b` / `a-after-b` / `a-missing`
/ `b-missing` / `no-top`) because `pack info` does not report `-before` and slave ORDER
is the only thing that can see it. BS20 pins that the frame does NOT exist before the
build, so BS21's "exists AND unpacked" cannot be BS20's picture again.

---

## 4. Sabotage tables

Order, both rounds: build → suites green → **COMMIT** → inject → run → `git diff` →
revert → clean re-run. `git checkout -- src/wave_viewer.tcl` is the correct revert form
**here** precisely because the item was committed first; the diff was confirmed to hold
nothing but the injection before each revert and to be empty after.

### 4.1 Implementer — the two PLAN-named injections

| # | injection | target | failedExactly | fails measured | reverted |
|---|---|---|---|---|---|
| (a) | drop `-before $top.drw` from `browser_show` | BS01 (source idiom) + BS24 (fixture slave order) | **NO** | **3** — BS01, BS24, BS43 | **YES**, diff empty after |
| (b) | delete the single `wviewer::sync_browser_mirror` call from `browser_toggle` | BS34 (mirror stale after a COMMAND toggle) + BS46 when the real key delivers | **NO** | **3** — BS08, BS34, BS46 | **YES**, diff empty after |

Neither extra is a blanket break. In **(a)**, BS43 is the SAME claim observed on the
REAL viewer's slave order — one claim at three levels (source, fixture, live), which
ruling 23 sanctions. In **(b)**, BS08 is the same single line seen at SOURCE level (it
asserts the sync precedes `browser_show`). **No check was weakened to manufacture a
single-target number** (ruling 17).

Two measurements inside these runs matter more than the counts:

* **(a) BS26 (canvas width) and BS27 (sidebar width) stayed GREEN** — see §7.1. This is
  the run that PROVES the plan's own named oracle is blind.
* **(b) BS35 and BS43 stayed GREEN as predicted.** On the MENU route Tk writes the
  mirror itself before `-command` runs, so the missing sync is invisible there. That
  asymmetry is what makes the injection meaningful.

Recorded rather than papered over: **only the FIRST BS34 leg fires.** After the
stale-mirror ON, a second command toggle takes the authority back to 0 and the stale
mirror is accidentally right again, so the OFF leg passes.

Clean re-run after both reverts: `test_wave_sigbrowser` 84, `test_wave_grid` 245,
`test_wave_viewer` 400, `test_wave_tabs` 172 — 4/4 ALL PASS.

### 4.2 Verifier — its OWN unnamed sabotages, and their outcomes

Both were invented by the verifier, named by nobody, and **both were CAUGHT**.

| # | injection | outcome | fails measured | reverted |
|---|---|---|---|---|
| S1 | `browser_show`'s `-side left` → `-side right` | **CAUGHT** | **2** — BS01 (source idiom literal) and BS25 (`{right y}` vs `{left y}`) | **YES**, diff empty after |
| S2 | delete `if {$new == $cur} { return $cur }` from `browser_toggle` **only** (leaving `grid_toggle`'s identical line alone) | **CAUGHT** | **4** — BS28 ×2 (both `ds_spy` NEGATIVE controls: 1 `log_action` and 1 `browser_show` recorded where 0 required, likewise the bad-word refusal), BS32 (2 replay lines, not 1), BS33 (`browser_show` ran twice) | **YES**, clean re-run 84/84 |

S2 is the interesting one: it is the idempotence guard, it is invisible to every count
check, and it was caught by the **negative** controls — the same "make the thing you must
observe an assertable value" move that items 4, 6 and 7 each had to learn separately.

**No verifier sabotage survived.** (Contrast item 4, whose U2 survived and became item
5's to close.)

---

## 5. Non-baseline fails

**EMPTY — and that is corroborated, not asserted.**

| run | result |
|---|---|
| `full_audit.sh` (implementer) | **262 pass / 18 fail / 0 crash / 4 skip** of 284; zero `X connection to :0 broken` |
| `full_audit.sh` (verifier) | **264 pass / 19 fail / 0 crash / 1 skip** of 284; `wireedit` 52/52; SCRATCH 0 leaked dirs |

Both fail SETs are the **16 HARD baseline names**, each on exactly the check `PLAN.md`'s
baseline block records for it, plus a small number of off-list names — **and the off-list
names DIFFER between the two runs**, which is itself the evidence that they are
environmental rather than item 8's:

* implementer: `test_multi_window` (MWf) and `test_readonly_action_dispatch` — 3/3 PASS
  solo each, and both already logged as load flakes in receipts `00`, `01` and `02`;
* verifier: `test_altf5_ciw` and `test_verb_noun_descend_0200` (**both on the documented
  FLAKY list**, each failing its documented check), plus `test_add_pin_lib_symbol_view`,
  which PASSES solo — see §5.1.

All **16 `wave_*` suites PASSED in the verifier's audit**, including
`test_wave_sigbrowser`, `test_wave_grid`, `test_wave_sigsearch`, `test_wave_tabs`,
`test_wave_viewer`, `test_wave_modes` and the ~50%-flaky `test_wave_trace_menu`. No fail
in either audit is attributable to item 8.

### 5.1 One disclosed measurement caveat (the verifier's, not hidden)

The verifier's audit log contains **exactly one `X connection to :0 broken`** — the
string the baseline says makes a run "not a measurement". It was **localised rather than
re-run blind** (the audit cost ~90 min under gate holds): the string appears in exactly
one test's captured output, `test_add_pin_lib_symbol_view`, whose ENTIRE output is that
single line; it is the 6th test alphabetically, so it ran at ~10:01:30, and
`~/.claude/gui_test_gate/events.log` records `panel death detected -- reviving` +
`X server may be restarting` at **10:01:37**. No other test's output contains the string,
and that test PASSES when re-run through `full_audit`. Everything else in the run is
uncontaminated. Recorded here so a future reader can judge the localisation rather than
inherit a conclusion.

---

## 6. Eyeball — what `[E]` owes (the queue row's long form)

The PLAN's line: *"the canvas does not jump or repaint wrong on toggle (WSLg repaint is a
known trap here); sidebar width is sane and the divider is draggable if one is added."*

**What the implementer already looked at**, on a real sky130A viewer
(`test_nfet_final/ngspice_state1`), 1000x620, two strips, driven through the MENU route,
three `xwd` captures:

```
1_hidden   top=1000x620  drw=1000x596  sidebar=unpacked
2_shown    top=1000x620  drw= 834x596  sidebar=166
3_hidden   top=1000x620  drw=1000x596  sidebar=unpacked
```

* The **toplevel width never moves**; the canvas gives up exactly the sidebar's 166 px
  and takes them back. `1_hidden` and `3_hidden` are **byte-identical** (md5
  `45606cf3…`) — the round trip leaves no residue, no stale region, no half-repainted
  strip. In `2_shown` both strips have **REFIT** to the narrower canvas (full-width axes,
  both x-axes still labelled 0…10u) rather than being clipped, because the toggle rides
  the existing `<Configure>` → `configure_apply` capture+regenerate pump.
* **Sidebar width 166 px comes purely from the placeholder label's `-width 22`** — no
  `pack propagate 0`, no explicit frame width, no hard-coded pixels. BS27 makes ">1 px"
  assertable; "sane" is the eyeball's word.
* **NO DIVIDER/SASH WAS ADDED**, so "the divider is draggable" is **NOT APPLICABLE** and
  is **not claimed**. Item 8's content is a placeholder label only.

**What is still owed to a human, stated as limits rather than as reassurance:** three
still frames, one machine, ONE window size, no claim about intermediate frames or about a
narrow window — and the narrow window is exactly where §7.1's blind oracle would have
mattered. Two layout facts are recorded so they do not read later as regressions: the
status bar spans the full width (so the sidebar stops at it), and the readout bar is
packed `-before $top.drw` **on demand**, which makes ITS width order-dependent against
the sidebar in a way the status bar's is not (§9, item 15's to settle).

⚠ **A near-false finding, recorded because it nearly shipped as one.** The first capture
attempt produced a **BLACK canvas in frame 1** and was nearly written up as a repaint
defect. It was a harness bug: an over-wide `catch` in a throwaway script swallowed an
`xschem raw list` error, so `wviewer::regenerate` never ran and nothing had been drawn.
With the catch narrowed, frame 1 is correct and frames 1 and 3 are byte-identical. Same
lesson as the rest of this batch — the blank frame could have masqueraded as a result.

---

## 7. Divergences from the PLAN — every one, with its reason

### 7.1 THE PLAN'S OWN SABOTAGE-(a) ORACLE DOES NOT WORK — measured, not argued

The item says: *"drop `-before $top.drw` → a geometry check fails (assert the canvas
keeps non-zero width)"*. **It cannot.** The canvas is packed `-side right -fill both
-expand true`, so dropping `-before` squeezes the **SIDEBAR**, not the canvas — and only
when the toplevel is narrow. Under sabotage (a), **BS26 (canvas width) and BS27 (sidebar
width) both stayed GREEN**, exactly as the scout predicted before the run.

The working discriminator is pack-**SLAVE-ORDER** (BS24 fixture, BS43 real viewer), the
house oracle already used at `test_wave_tabs.tcl` with the comment *"`pack info` does not
report `-before`; the SLAVE ORDER is what `-before` set"*. The width legs ship as
documented regression guards and say so in the file. **Items 9-15 must not reach for a
width oracle here.**

### 7.2 The cited `readout_show` anchor had drifted

Settled decision 1 and the item body both cite `src/wave_viewer.tcl:6563`;
`readout_show` is at **`:7067`** (+504 lines). The thing it names exists and is exactly
the template described — only the number was stale.

### 7.3 Neither named sabotage was single-target

(a) failed 3 where 2 were predicted; (b) failed 3 where 1-2 were predicted. In both
cases the extra is the SAME claim observed at another level (source / fixture / real
viewer), sanctioned by ruling 23. **No check was weakened** to manufacture a smaller
number, per ruling 17. Full detail in §4.1.

### 7.4 Placement: one contiguous block

The whole browser family (`build` + `shown` + `show` + `sync` + `toggle` + `from_menu` +
`toggle_at`) lives as one block after `grid_toggle_at`, rather than splitting
`browser_build` up beside `tabbar_build` as the plan sketched. **Placement only; no check
depends on it.**

### 7.5 `wviewer::open` did NOT gain the two `variable` declarations

The plan specified `variable browser; variable browsershow` in `open`. `open` never
references them — `browser_build` owns the seeding, the way `tabbar_build` owns the tab
bar — so the declarations would have been dead code.

### 7.6 A DELIBERATE TIGHTENING of the `grid_toggle_from_menu` precedent

`browser_from_menu` re-syncs the mirror on a refusal **only when the token still has a
window**. The `grid` twin re-syncs unconditionally, which for a dead token would CREATE
the stray array entry `forget`'s own comment exists to prevent. **BS36 pins the tightened
behaviour.**

### 7.7 BS44 asserts a type, not a value

`xschem get graph_rects` is asserted to be an INTEGER rather than the literal `0` the
plan implied. A fresh viewer's rect count is a property of the fixture state file, not of
item 8; pinning it would have coupled this item to an unrelated fact.

### 7.8 GUI gate — a 24-minute pause, waited out

The panel was PAUSED ~08:58 → 09:22 with the 6-hour authorization expired. The run was
left enrolled and waiting: `GUI_GATE` was not touched, no gate file was hand-written, no
bare loop was used. It resumed on its own and **every measurement is from an approved
window**. (The verifier's audit likewise absorbed ~55 min of human PAUSE holds across
~90 min wall.)

### 7.9 Mandatory collateral the item's Files line did not list

`doc/waveform_viewer_guide.html` (one §9.1 row) and `test_wave_grid.tcl` (GH0's two
literals, 14 → 15 and 9 → 10). Not optional: GH0-GH4 enforce "every shipped WaveViewer
default has a guide row and every guide row is shipped" by COUNT and by literal spelling,
and `test_wave_grid` is on **neither** baseline list, so a miss would have read as item
8's regression. Green afterwards at 245.

### 7.10 The eyeball harness bug

Recorded in §6 rather than here, because it produced no change to shipped code — but it
is a divergence from the clean narrative and belongs in the record.

---

## 8. Verifier problems carried forward (none blocking)

The verifier returned `ok: true, scopeClean: true` and **no blocker**. Its reported
problems, all carried forward rather than fixed here (this stage may not touch `src/` or
`tests/`):

1. **`tests/headless/test_wave_sigbrowser.tcl:27` says "14 run in both arms"; the
   measured number is 28.** The line sits inside the block the file itself labels *"THE
   ARM STATEMENT, and it is the most important line in this header"*, and **items 9-15
   inherit this header verbatim as their convention contract**, so the wrong number
   propagates. The arm BLOCKING is correct; only the summary count is wrong. One-word
   fix. **Do it before item 9.**
2. **Four NEW stale line anchors**, shipped by the item whose own divergence list opens
   by correcting a stale line anchor: `wave_viewer.tcl:5822` says `readout_show (:7080)`
   (it is `:7261`); `:359` says `tab_thaw, :9330` (it is `:9526`; `:9330` is a
   `bind $wp <Button-5>` line); the appendix says `snapshot (:2585)` (it is `:2609`) and
   cites `:8534` for the graphkeys-modifier note (it is `:8728`). All comment/prose; **no
   code or check depends on any of them.** Item 4's P1 already asked for grep-able
   phrases instead of numbers — this is the fourth item to pay for ignoring it.
3. **This receipt named the wrong commit twice** (`1b9aa319`). Corrected in §2; the
   appendix is preserved verbatim, so the stale hash survives there by convention.
4. **An observation for item 15, not a defect and not in scope for a shell**: see §9.
5. **A test-naming nit, no action needed**: BS12 is named *"`browser_toggle` on an
   unknown token is a spoken refusal, not a throw"* but asserts only the return value
   (`{}`); nothing pins that `ciw_echo` was actually called. The name promises slightly
   more than the check delivers. The verifier checked all 84 and found **no other check
   that asserts a tautology or asserts on a value it computed itself**. (BS26 carries a
   literal `{ismapped}` token in both `got` and `exp`, but that is a self-documenting
   label inside a tuple whose other four elements are real program reads.)

---

## 9. Carried forward to items 9-15

* **The waiver is INTACT.** `pack $f -side left -fill y -before $top.drw` is settled
  decision 1 verbatim and the exact line item 0 measured surviving an `xschem reload`
  (`receipts/00_precondition.md` §3). **BS01 asserts that literal string and names itself
  the check that guards the waiver** — if a later item changes that line, it has re-opened
  the items-8-15 auto-defer question.
* **Two arrays, and they must stay two.** `::wviewer::browser($token)` is the AUTHORITY;
  `::wviewer::browsershow($token)` exists only because Tk's checkbutton `-variable` needs
  a global. Collapse them and they can never disagree — sabotage (b) becomes unfireable.
* **PER TOKEN, NOT PER TAB.** `layouts` and `cvr` are frozen/thawed by
  `tab_freeze`/`tab_thaw`; a sidebar over the WINDOW's raw inventory (one xctx, one raw,
  shared by every tab) must not blink on a tab switch.
* **Built HIDDEN out of `open`** (the `tabbar_build` rule), so a viewer that never opens
  the browser has byte-identical canvas geometry — pinned on a REAL fresh viewer by
  BS40/BS41.
* **`browser_toggle` does not capture, regenerate or switch context** (BS08 asserts all
  three as zero counts). The resize already rides `<Configure>` → `on_configure` →
  `configure_apply`; a second one would double-fold and double-draw, and a context switch
  would be a 0173-style loan taken for nothing.
* **The three-path key check is written at the binding site**, and `<Control-Key-l>` is
  clean on all three: 108 is not in `graphkeys`; its only `keybindings.csv` row is
  `key,108,0,canvas,edit.add_wire_label,1` (bare `l`, mod 0); no rc binds it, so
  `clone_canvas_bindings` has nothing to copy and BS45 proves survival across a real
  `strip_bindings` sweep; and the body `break`s. **Ctrl-B was considered and REJECTED** —
  98 IS a `graphkeys` member and membership is unconditional on modifiers.
* **Every later item that adds a viewer key or a menu accelerator owes the guide row AND
  both `test_wave_grid` GH0 literal bumps** (§7.9).
* **Item 15 inherits two things.** `wviewer::snapshot` was NOT touched, so sidebar
  visibility does not survive save/restore — a decision, not an oversight. And
  `readout_show` packs the readout bar `-side bottom -fill x -before $top.drw` **on
  demand**, so unlike the always-built status bar its width is **order-dependent**:
  enable cursors first and the bar spans the window; show the sidebar first and it is
  confined to the canvas column. Cosmetic, invisible to every current check, item 8 ships
  no divider — but it is the kind of thing that reads as a regression later.
* **The editor toolbar shares the LEFT slot** (`pack $topwin.toolbar -side left -fill y
  -before $topwin.drw`, `xschem.tcl:13096`). `wviewer::open` already `pack forget`s it
  per viewer window and nothing re-shows it in a viewer, so the two left bars cannot
  stack today. One comment at `browser_show`, no guard — as the scout advised.
* **Item 7's declared limit still stands**: `wviewer::plot_dest <token>` is THE
  destination accessor, and Replace does nothing under multi-plot. A browser gesture
  offering Replace while the window is in multi mode is offering Append.

---

## 10. If a human looks at one thing

This item **did not fail**, so nothing here is a triage instruction. If you have one
minute, spend it on **§7.1**: the plan named an oracle, the scout said it would not fire,
and the sabotage run **measured** it not firing while the item still shipped a working
discriminator. That sequence — predicted, measured, replaced, documented in the test file
itself — is the reusable part of this item, and it is what items 9-15 should copy the next
time a plan hands them an oracle.

If you have a second minute, do the **eyeball on a NARROW window** (§6). Every capture so
far is 1000x620, and narrow is precisely where the geometry the plan worried about
actually bites.

---

# APPENDIX — implementer long-form receipt, preserved verbatim

This file's original content, written by the implementer alongside `f3c89935` (but not
inside it — §2). Kept whole; where it and §1-§10 above disagree, §1-§10 wins. **Two known errors in it, both already corrected
above:** it names commit `1b9aa319` (amended away; the real commit is `f3c89935` — §2),
and it cites `wviewer::snapshot` at `:2585` and a graphkeys note at `:8534` (they are
`:2609` and `:8728` — §8.2). Its "ATTEMPT 1 — VOID" section is retained in full: it is
the record of the infrastructure failure that briefly wore a `[D]`, and the rule it
earned.

---

# Item 08 — PIXEL — browser sidebar shell (empty) — VOID ATTEMPT, then see below

Batch `signal_browser_batch`, branch `fluid-editing`. HEAD `e5d3a8f7`. Date 2026-08-05.

---

## ATTEMPT 1 — VOID. Not a defer. Not a failure of the item.

The first pipeline run for item 8 recorded `[D] DEFERRED: the scout agent returned
nothing`. **That mark was wrong and the driver revoked it the same day.**

What actually happened: the scout subagent died mid-run with

```
[scout:08] failed: API Error: Connection closed mid-response.
```

`agent()` returns `null` when a subagent dies on a terminal API error, and
`item_pipeline.js` tested `if (!scout || scout.verdict !== 'PROCEED')` — so a **dead
agent was indistinguishable from a scout that had examined the code and judged the item
not worth doing.** The ledger stage then faithfully wrote that non-verdict into `PLAN.md`
and produced a receipt reasoning at length about why the item could not proceed.

Nothing about item 8 was actually learned. No implementer ran, no verifier ran, no code
was written, no test was added, nothing was committed. `git status` confirmed `src/` and
`tests/` were untouched and HEAD was still `e5d3a8f7`.

### Why this was worth fixing rather than just re-running

A `[D]` in this batch is not a shrug — it is an input to the next batch, and the PLAN says
so explicitly (*"a `[D]` reason is the input to the next batch. Do not summarise"*). An
infrastructure failure wearing the costume of an engineering judgement is the worst kind of
entry in a file whose whole purpose is to be trusted months later by someone who was not
here. Left alone it would have read as *"we looked at the sidebar and decided against it"* —
and it would have taken items 9-15 down with it, since they depend on this shell.

### The fix, applied before re-launching

`item_pipeline.js` now separates the two cases. A `null` scout returns
`verdict: 'INFRA_FAILURE'`, logs it, and **touches no ledger line and writes no receipt**;
only a scout that actually returned `verdict: 'DEFER'` can produce a `[D]`. This protects
the eight items that run through the same pipeline after this one.

### The rule this earns, for any future batch harness

**Distinguish "the agent said no" from "the agent never spoke."** Any pipeline that
collapses a transport error into a domain verdict will eventually write a confident,
well-formatted, entirely fictional conclusion into the permanent record — and the better
the harness is at generating prose, the more convincing that fiction will be. This is the
same family as the batch's own repeated testing lesson (rulings 17 and driver note (c)):
make the failure mode an **assertable value**, never something that can masquerade as a
result.

---

## ATTEMPT 2

Re-launched from scratch on 2026-08-05 with the fixed pipeline. Its outcome — whatever it
turns out to be — is recorded below by that run's ledger stage. This section stands as the
record of the void attempt, so nobody later mistakes attempt 1's `[D]` for a considered
judgement about the sidebar.

### Verdict: `[E]` — implemented, measured, eyeballed. Commit `1b9aa319`.

Attempt 1 left no anchors, so everything below was re-verified from source. **One cited
anchor had drifted and is corrected here: `readout_show` is at `src/wave_viewer.tcl:7067`,
not `:6563` — +504 lines.** The thing it names exists and is exactly the template the item
describes.

| file | what |
|---|---|
| `src/wave_viewer.tcl` | the two arrays; `forget`'s declare+unset; `browser_build`, `browser_shown`, `browser_show`, `sync_browser_mirror`, `browser_toggle`, `browser_from_menu`, `browser_toggle_at`; the `open` call site; the `<Control-Key-l>` default; the `View > Signal Browser` checkbutton |
| `doc/waveform_viewer_guide.html` | one §9.1 row (`data-seq="Control-Key-l"`, `data-menu="Signal Browser" data-accel="Ctrl+L"`) |
| `tests/headless/test_wave_grid.tcl` | GH0's two hard-coded literals, 14 → 15 and 9 → 10 |
| `tests/headless/test_wave_sigbrowser.tcl` | **NEW** — the second test file of decision 9 |

Not committed, deliberately: `PLAN.md` and this receipt are the driver's files and were
dirty on arrival (the shape item 7 established).

---

#### 1. The core decision, implemented exactly — and the waiver is intact

`wviewer::browser_show` packs

```tcl
pack $f -side left -fill y -before $top.drw
```

which is settled decision 1 verbatim and the exact line item 0 measured surviving an
`xschem reload` (`receipts/00_precondition.md` §3). **No divergence from the measured
idiom, so the items-8-15 waiver stands.** BS01 asserts the literal string in the source and
names itself, in the test file, as the check that guards the waiver.

Nothing in item 8 reads the rect model (decision 13). The shell has no content yet; items
9+ must source it from `xschem raw list` / `xschem raw`.

---

#### 2. The bindtag key — the WRITTEN three-path collision check, and the three paths

Chosen: **`<Control-Key-l>`** (keysym 108). The three paths `wave_viewer.tcl` documents per
key, run and recorded verbatim at the binding site:

1. **`key_filter` / `graphkeys` → the C dispatcher.** 108 is NOT in
   `variable graphkeys {97 98 100 115 109 116 65 66 77}` (`wave_viewer.tcl:320`), so
   `key_filter` forwards nothing and the C dispatcher never sees the chord.
   `src/keybindings.csv` has exactly ONE row for 108 — `key,108,0,canvas,edit.add_wire_label,1`
   — BARE `l`, mod 0, ctx `canvas`: a Ctrl chord does not match it, and a viewer canvas
   could not reach it anyway. `callback.c:6374 case 'l'` under `ControlMask` makes a
   schematic from the selected symbol; same forward, same unreachability.
   **Ctrl-B was considered and REJECTED**: 98 IS a `graphkeys` member, membership is
   unconditional on modifiers (`wave_viewer.tcl:8534`), `key,98,ctrl,graph,graph.forward`
   is live, and C toggles cursor B on `b` — one keystroke would have done both.
2. **an rc `bind .drw` cloned by `clone_canvas_bindings`, swept by `strip_bindings`.**
   `grep -rn 'Control-Key-l>|Control-l>' --include=*.tcl --include=*_rc --include=*.c .`
   returns NOTHING — no rc binds it, so `clone_canvas_bindings` has nothing to copy.
   BS45 additionally asserts survival across a REAL `strip_bindings` sweep on a live canvas.
3. **the `break`.** The body is `{wviewer::browser_toggle_at %W; break}`. BS03 pins it at
   source level, BS45 on the running viewer.

Mandatory collateral, done: `test_wave_grid` GH0-GH4 enforce "every shipped WaveViewer
default has a guide row and every guide row is shipped", by COUNT and by literal spelling.
The guide row plus the two literal bumps were required; `test_wave_grid` is in neither
baseline list, so a miss would have read as item 8's regression. Measured green afterwards:
245 checks, and GH0's two legs green in the `--nogui` arm as well.

---

#### 3. Two arrays, not one — which is what gives sabotage (b) an injection point

`::wviewer::browser($token)` is the AUTHORITY; `::wviewer::browsershow($token)` exists only
because Tk's checkbutton `-variable` needs a global. This is the shipping `gridshow` shape.
Collapse them and the two can never disagree — the sabotage becomes unfireable, which is
exactly what the plan forbade. `browser_toggle` PUSHES the mirror through
`wviewer::sync_browser_mirror`; deleting that one call is the injection.

PER TOKEN, NOT PER TAB, deliberately: `layouts` and `cvr` are frozen/thawed by
`tab_freeze`/`tab_thaw`, and a sidebar over the WINDOW's raw inventory (one xctx, one raw,
shared by every tab) must not blink on a tab switch. Items 9-15 inherit this.

---

#### 4. The new test file, and the conventions it fixes for items 9-15

`tests/headless/test_wave_sigbrowser.tcl`. **84 checks under X; 28 of them source/pure and
therefore also green under `--nogui`.** The header states loudly that **a green `--nogui`
run proves nothing about the sidebar** — the `--nogui` arm is source-level and pure-Tcl
only, because `wviewer::open` returns 0 without `::has_x` and `pack`/`winfo` need a display.
Arm blocking is by number: 01-19 both arms, 20-39 the throwaway-toplevel fixture, 40-59 the
real viewer. Prefixes are one per item and never reused (8 = `BS`, 9 = `BT`, 10 = `BM`,
11 = `BH`, 12 = `BX`, 13 = `BR`, 14 = `BD`, 15 = `BP`).

Carried over rather than invented: `check`/`check_true`, `pcall` (`{args}` + `uplevel 1`),
the `::bgerror` override that PRINTS and INCREMENTS `::fail`, `wvproc_body`,
`viewer_ready`/`send_key`, the `at_wait_mapped` idiom (as `bs_wait_mapped` — polls the
PRECONDITION and RETURNS the mapping so a budget expiry cannot masquerade), the `ms_err`
never-throwing-reader idiom, and `ds_spy_*` call recorders with a POSITIVE and a NEGATIVE
control (BS28 is the negative half, BS32/BS33 the positive).

**Driver note (c) — the answer to the widget-state masquerade.** A frame that was never
created, a `pack forget` that silently did nothing, and a correctly hidden frame all look
identical to a naive check. Two helpers fix that:

* `bs_packed` — `expr {[catch {pack info $w}] ? 0 : 1}`. Cannot throw. Every use is PAIRED
  with a `winfo exists` assertion, so "hidden" and "destroyed" are never conflated.
* `bs_order top a b` — returns an ASSERTABLE STRING, never a boolean and never an
  exception: `a-before-b` / `a-after-b` / `a-missing` / `b-missing` / `no-top`. `pack info`
  does not report `-before`; the SLAVE ORDER is the only thing that can see it (the house
  oracle, `test_wave_tabs.tcl`).

And the before-picture is asserted, not assumed: **BS20 pins that the frame does NOT exist
before `browser_build`** (`{0 0 a-missing}`), so BS21's `{1 Frame 0}` — exists AND is not
packed, two positive assertions — cannot be BS20's picture again.

---

#### 5. Suites

Everything through `tests/headless/run_suites.sh` / `gated_xschem.sh`. **The 6-hour
test-at-will authorization had expired, and the panel was PAUSED for ~24 minutes
(08:58 → 09:22).** The run was left enrolled and waiting; `GUI_GATE` was NOT touched, no
gate file was hand-written, and no bare loop was used. It resumed on its own and every
measurement below is from an approved window.

| run | result |
|---|---|
| `test_wave_sigbrowser` `--nogui` | ALL PASS (28) |
| `test_wave_sigbrowser` X arm | ALL PASS (84), no self-skip printed — BS46's real Ctrl-L DELIVERED |
| `test_wave_grid` / `viewer` / `tabs` / `modes` / `sigsearch` | ALL PASS — 245 / 400 / 172 / 485 / 194 |
| **full_audit.sh** | **262 pass, 18 fail, 0 crash/timeout, 4 skip (total 284)**; zero `X connection to :0 broken` |

**The fail SET, compared as a set:** all **16 HARD baseline names**, each failing on
exactly the check `PLAN.md`'s Baseline block records for it (W7, FE8, GUI8+GUI9, LM-LOC3,
R10, `rot180-ip`, the P1/P1b/P2/P3/P4 `test_lib_sweep` block, the action-log cluster
PS*/SA*, and the three PDK `library_list = exactly the N intended libs` lines with the
user-level `{SANDBOX TEST ...}` extras). Plus **two names on NEITHER list**:

* `test_multi_window` — MWf. Re-ran **3/3 PASS** (15 checks each).
* `test_readonly_action_dispatch` — re-ran **3/3 PASS** (`ACTION_READONLY_TEST_PASS`).

Both are already recorded as load flakes in receipts `00`, `01` and `02` of this batch.
No A/B revert was needed: neither passes anywhere near `wave_viewer.tcl`, and both cleared
on 3/3 solo re-runs.

---

#### 6. Sabotage — MEASURED, not predicted

Order: build → suites green → **COMMIT (`1b9aa319`)** → inject → run → `git diff` → revert
with `git checkout -- src/wave_viewer.tcl` → clean re-run. The checkout form is correct
HERE precisely because the item was committed first (the PLAN's warning about `checkout`
applies while an item is UNCOMMITTED); the diff was confirmed to hold nothing but the
sabotage before each revert, and to be empty after.

**(a) drop `-before $top.drw`** — `pack $f -side left -fill y`.
**Measured: 3 fails.**

| check | what it saw |
|---|---|
| BS01 | the source idiom is gone |
| BS24 | `bs_order` → `a-after-b` (the fixture's slave order) |
| BS43 | `{1 1 a-after-b}` (the same claim on the REAL viewer's slave order) |

Predicted was {BS01, BS24}. **BS43 is a third observation of the ONE claim** — source,
fixture toplevel, real viewer — which ruling 23 sanctions; no check was weakened to
manufacture a smaller number. **BS26 and BS27 stayed GREEN, exactly as the scout warned**:
dropping `-before` squeezes the SIDEBAR, not the canvas, and only on a narrow toplevel, so
the canvas-width and sidebar-width legs are documented in the file as REGRESSION GUARDS and
explicitly not the discriminator. **The oracle the item's own plan named ("assert the canvas
keeps non-zero width") does NOT work, and this run is the measurement that says so.**

**(b) delete the single `wviewer::sync_browser_mirror $token` line from `browser_toggle`.**
**Measured: 3 fails.**

| check | what it saw |
|---|---|
| BS08 | source: the sync no longer precedes `browser_show` |
| BS34 | `{1 0 1}` — toggled to 1, authority 1, **mirror still 0** (the hard oracle) |
| BS46 | `{0 1 0}` — the real Ctrl-L leg, which delivered this run |

Predicted was {BS34, BS46-when-it-delivers}; BS08 is the same single line seen at source
level. **BS35 and BS43 stayed GREEN as predicted**, and that asymmetry is the whole point:
on the MENU route Tk writes the mirror itself before `-command` runs, so the missing sync is
invisible there. A blanket break would have proved much less.
One honest detail: only the FIRST BS34 leg fires. After the stale-mirror ON, a second
command toggle takes the authority back to 0 and the stale mirror is accidentally right
again, so the OFF leg passes. Recorded rather than papered over.

Clean re-run after both reverts: `test_wave_sigbrowser` 84, `test_wave_grid` 245,
`test_wave_viewer` 400, `test_wave_tabs` 172 — 4/4 ALL PASS.

---

#### 7. EYEBALL — `[E]`. What was LOOKED AT, and nothing beyond it

A real sky130A viewer (`test_nfet_final/ngspice_state1`), 1000x620, two strips, driven
through the **menu** route and captured with `xwd` at three moments
(harness outside the repo; PNGs in the session scratchpad):

```
1_hidden   top=1000x620  drw=1000x596  sidebar=unpacked
2_shown    top=1000x620  drw= 834x596  sidebar=166
3_hidden   top=1000x620  drw=1000x596  sidebar=unpacked
```

* **(i) The canvas does not jump, and the round trip is pixel-exact.** The TOPLEVEL width
  never moves; the canvas gives up exactly the sidebar's 166 px and takes them back.
  `1_hidden.png` and `3_hidden.png` are **byte-identical** (md5
  `45606cf3…`), so hidden → shown → hidden returns the window pixel-for-pixel to its
  original frame — no residue, no stale region, no half-repainted strip. In `2_shown` both
  strips have REFIT to the narrower canvas (full-width axes, both x-axes still labelled
  0…10u) rather than being clipped — the toggle deliberately rides the existing
  `<Configure>` → `on_configure` → `configure_apply` capture+regenerate pump, and that is
  what refits them. WSLg repaint is the known trap here and it did not bite in these three
  captures.
  ⚠ **What this does NOT establish**: three still frames on one machine at one size. It is
  not a claim about intermediate frames, about a narrow window, or about a machine other
  than this one. **No claim of general visual correctness is made.**
  ⚠ **A first attempt at this capture produced a BLACK canvas in frame 1 and I nearly wrote
  it up as a repaint defect.** It was a harness bug: an over-wide `catch` swallowed a
  `xschem raw list` error and `wviewer::regenerate` never ran, so nothing had been drawn
  yet. Re-run with the catch narrowed, frame 1 is correct. Recorded because it is the same
  lesson as everything else in this batch — the blank frame could have masqueraded as a
  result.
* **(ii) The sidebar's width is sane**: 166 px, driven purely by the placeholder label's
  `-width 22` in `AseLabelFont`. No `pack propagate 0`, no explicit frame width, no
  hard-coded pixel number. BS27 makes ">1 px" assertable; "sane" is this eyeball.
* **(iii) NO DIVIDER/SASH WAS ADDED.** Item 8's content is "a placeholder label only", so
  the item's own "the divider is draggable if one is added" is **NOT APPLICABLE** and is
  NOT claimed.
* **(iv) One layout fact worth knowing before item 9 fills the panel**: the viewer's own
  status bar (`$top.wvstatus`, packed `-side bottom -fill x -before $top.drw` and therefore
  EARLIER in the slave order) spans the FULL window width, so the sidebar runs from the top
  of the window down to the status bar, not to the bottom edge. That is the conventional
  arrangement and no change is proposed; it is recorded so nobody reads it later as a
  regression.

---

#### 8. Declared limits and deliberate divergences

* **No persistence.** `wviewer::snapshot` (`:2585`) was NOT touched, so sidebar visibility
  does not survive a session save/restore. Item 15 inherits this as a decision to make.
* **`browser_toggle` does not capture, regenerate or switch context** — BS08 asserts all
  three as zero counts. The canvas resize already goes `<Configure>` → `on_configure` →
  `configure_apply`, which captures and regenerates; a second one here would double-fold
  and double-draw, and a context switch would be a 0173-style loan taken for nothing.
* **One deliberate tightening of the `grid_toggle_from_menu` precedent.**
  `browser_from_menu` re-syncs the mirror on a refusal ONLY when the token still has a
  window: re-syncing a dead token would CREATE the stray array entry `forget`'s own comment
  exists to prevent. BS36 pins it (`browser_from_menu` on a windowless token refuses, and
  leaves no authority entry behind).
* **Two plan details not followed, both immaterial and both stated:** the browser section
  lives beside `grid_toggle_at` as one contiguous block rather than split between there and
  `tabbar_build` (placement only, no check depends on it); and `wviewer::open` did NOT gain
  `variable browser; variable browsershow` declarations, because `open` never references
  them — `browser_build` owns the seeding, the way `tabbar_build` owns the tab bar.
* **The editor toolbar shares the LEFT slot** (`pack $topwin.toolbar -side left -fill y
  -before $topwin.drw`, `xschem.tcl:13096`). `wviewer::open` already `pack forget`s it per
  window and nothing re-shows it in a viewer, so the two left bars cannot stack today. One
  comment line at `browser_show`, no guard — as the scout advised.
