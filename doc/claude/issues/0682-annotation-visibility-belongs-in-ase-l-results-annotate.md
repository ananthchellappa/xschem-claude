# 0682 — annotation visibility belongs in ASE-L `Results > Annotate`, not the schematic's View menu

STATUS: **RULED 2026-08-24. IMPLEMENTED 2026-08-25 — awaiting the user's ratification (rule debt [0682]) and their eyes (look debt).**
Reverses: [0457](0457-annot-show-has-no-stock-affordance.md) decision (b).
Supersedes: the wording question raised by [0678](0678-branch-currents-are-gated-by-alt-6-but-belong-to-6.md) — see §5.
Related: 0613, 0614, 0615, 0621, 0678, 0681.

---

## 1. The ruling, verbatim

Asked which wording the `View > Show / Hide` checkbutton should carry, the user
rejected the question's premise:

> What is View > Show? We want to be like Cadence. It needs to ONLY be in
> ASE-L > Results > Annotate > Operating Point Info.

Asked what a user should do who has annotations on screen with no ASE-L window
open:

> results (including OP info) only make sense when there is a result loaded -
> meaning an ASE-L is active, to which this schematic is "bound". We're trying to
> be the same as Cadence. Departures from legacy Xschem are OK.

Two rulings, and the second is the load-bearing one.

## 2. What this reverses, and why that is not a criticism of 0457

0457(b) was ruled **by the same user two days earlier**, on 2026-08-22: the
control was to be "a View-menu checkbutton pair". It was implemented that day and
has shipped since. This issue reverses that placement.

It should be recorded as a **reversal, not a repair**. 0457(b) answered the
question it was asked — *where can this control live without new C code* — and
answered it correctly. The question it was not asked, and which the user has now
answered, is *where would a person coming from Cadence look for it*. Those have
different answers, and only the second one matters for the product this is trying
to be.

The same shape as 0678, which reversed 0614's decision D4 a day after the same
user ratified it. A ruling reversed on new grounds is the process working.

## 3. The state of the destination — it is a stub

`src/ase_window.tcl:530-535`:

```tcl
menu $top.mb.results.annotate -tearoff 0
$top.mb.results.annotate add command -label {Operating Point info} \
  -state disabled
$top.mb.results.annotate add command -label {DC Node Voltages} \
  -state disabled
$top.mb.results add cascade -label Annotate -menu $top.mb.results.annotate
```

Both entries are **permanently greyed out**. `grep -n 'results.annotate'` returns
only these four lines and nothing anywhere calls `entryconfigure` on them. There
is no code behind either item.

**So this is not a move.** It is: build the two ASE-L controls for the first time,
then delete the View pair. Anyone estimating this as "relocate two checkbuttons"
will be wrong by the whole implementation.

## 4. What the second ruling settles

The obvious objection to an ASE-L-only control is the orphan case: annotations on
a schematic whose ASE-L window has been closed, with no menu anywhere to switch
them off. Outside the cadence profile there are no `6`/`Ctrl-6` chords either, so
the user would be back to editing `~/.xschem/xschemrc` — **which is the exact
complaint 0457 was filed about.**

The user's answer dissolves the case rather than handling it: results only exist
while a result is loaded, and a loaded result means a live ASE-L session the
schematic is bound to. There is no "annotated schematic with no session" state to
design an escape hatch for. If one is reachable today, that is a **binding
defect** to be found and fixed, not a menu to be added.

That is a stronger ruling than any of the three options offered, and it is why
none of them was chosen. It also explicitly licenses divergence from stock
xschem: *"Departures from legacy Xschem are OK."*

**Implementation consequence, and it must be verified rather than assumed**: the
annotation visibility state has to be reachable from, and meaningful within, the
ASE-L session that owns the result. `xctx->annot_show` is currently a per-context
C field with a mirrored Tcl variable, owned by nothing. Whether it should become
session-scoped is the first thing to measure. **Do not assume it already is.**

## 5. This supersedes 0678's wording question

Rule debt `[0678]` asks whether the bit0 checkbutton should read *"Show device OP
/ branch current annotation"* (shipped) or *"Show device OP annotation"*. Under
this ruling **the checkbutton it is asking about ceases to exist**, and the ASE-L
entries already carry Cadence's own names — `Operating Point info` and
`DC Node Voltages` — which name neither subclass.

The debt is left standing, because a rule debt clears only when the user says so
and no other command may convert or discharge one. It is annotated here as moot.
It should be cleared with `owed.sh clear rule 0678` at the user's word, not by
this file.

## 6. Open, to be decided by measurement rather than asked

Recorded so they are not silently invented during implementation:

1. **Checkbutton or command?** Cadence's Results > Annotate is a mode selection,
   and the shipped stubs are `add command`. The two annot bits are booleans, so
   `add checkbutton` bound to the mask is the honest widget. Assume checkbutton
   unless the ASE-L menu conventions say otherwise.
2. **Per-session or global?** See §4. Measure `annot_show`'s current ownership
   before choosing.
3. **What enables them.** They are `-state disabled` today; something must decide
   live-vs-greyed. The natural test is "this session has a loaded result", which
   is the same predicate §4 leans on — so it wants to exist exactly once.
4. **The `6` / `Alt-6` / `Ctrl-6` chords stay.** The user confirmed on a real
   bench that all three behave correctly (0678). Nothing here touches them.
5. **`annot_show_menu_sync` / `annot_show_menu_apply`** (`src/xschem.tcl`) exist
   to serve the View pair and are pinned by `test_annot_show_menu.tcl` rows
   A4/A5/A19. Deleting the pair without re-pointing those is how the suite goes
   green over a control nobody can reach.


---

# IMPLEMENTATION RECORD — 2026-08-25

Pure Tcl. No `make`, no `./configure`: `src/ase.tcl`, `src/ase_window.tcl` and
`src/xschem.tcl` are all already sourced and already installed
(`grep -c ase_window.tcl src/Makefile` = 2, install + uninstall, unchanged; no new
`.tcl` file). The binary is untouched — `src/xschem` dated 2026-08-24 18:40:47,
and `find src -maxdepth 1 \( -name '*.c' -o -name '*.h' -o -name '*.y' -o -name '*.l' \) -newer src/xschem`
returns nothing.

## A. BEFORE — the measured state, verbatim from the Measure agent

```
BEFORE: ase::open_state -> 1
BEFORE: ase window = .ase4  (exists=1)
BEFORE: submenu .ase4.mb.results.annotate exists = 1
BEFORE: submenu -postcommand = {}
BEFORE: ASE-L Results>Annotate {Operating Point info}: type=command state=disabled -command={} -variable=NO-SUCH-OPTION
BEFORE: ASE-L Results>Annotate {DC Node Voltages}: type=command state=disabled -command={} -variable=NO-SUCH-OPTION
BEFORE: invoke {Operating Point info} returned {}
BEFORE: annot_show before invokes = 0 ; after both invokes = 0
BEFORE: View>Show/Hide -postcommand = {annot_show_menu_sync}
BEFORE: View>Show/Hide[6] type=checkbutton label={Show device OP / branch current annotation} -variable=annot_show_op -command={annot_show_menu_apply}
BEFORE: View>Show/Hide[7] type=checkbutton label={Show node voltage annotation} -variable=annot_show_voltage -command={annot_show_menu_apply}
BEFORE: View pair drives mask: op=1 volt=0 -> annot_show = 1
BEFORE: View pair drives mask: op=1 volt=1 -> annot_show = 3
BEFORE: ase::session_for_current on this schematic = {}   (no ASE-L session anywhere)
BEFORE: annot_show=0 : bbox width i_none=72 i_op=0 i_volt=0
BEFORE: annot_show=1 : bbox width i_none=72 i_op=72 i_volt=0
BEFORE: annot_show=2 : bbox width i_none=72 i_op=0 i_volt=72
BEFORE: annot_show=3 : bbox width i_none=72 i_op=72 i_volt=72
BEFORE: after bare `set ::annot_show 0` (no xschem set): get=3 ::annot_show=0
BEFORE: after `xschem update_all_sym_bboxes` (a bulk eval): get=0 ::annot_show=0
```

§3 is **confirmed and understated**: `-command` was not merely inert, it was the
empty string, there was no `-variable` option at all, and the submenu carried no
`-postcommand`. Invoking both entries moved nothing.

§4's ownership question is **answered**: `xctx->annot_show` (xschem.h:2241) is
per-context, but `annot_show_sync_cache()` (actions.c:1321-1325) does
`xctx->annot_show = tclgetintvar("annot_show")` at all eight bulk-evaluation entry
points — the C field is a per-frame **pull-cache** of the one global Tcl var. The
last two BEFORE lines are that proof. What makes the mask behave per-context is
that `annot_show` is in `tctx::global_list`, so a tab/window switch swaps the Tcl
var and snapshots the outgoing one into `::tctx::<win_path>(annot_show)`.

## B. AFTER

```
ok:   W1a1 both Annotate entries are checkbuttons, not commands
ok:   W1a5 predicate FALSE -> the postcommand DISABLES both entries poisoned to normal
ok:   W1a7 predicate TRUE  -> the postcommand ENABLES both entries poisoned to disabled
ok:   W1a8  design mask 2 -> tick {Operating Point info} -> 3   (bit1 PRESERVED)
ok:   W1a9  tick it again -> 2                                  (the off-ramp)
ok:   W1a10 mask 2 is reachable from ASE-L (the three chords cannot make it)
ok:   W1a12 FOREIGN PULL: the ticks report the DESIGN's mask (1), not the current one's (3)
ok:   W1a13 FOREIGN PUSH: the DESIGN's mask gains bit1, the decoy's is untouched
ok:   W1a14 unreachable design: NO context's mask moves, and the tick snaps back
ok:   W1a15 ticking a bit ON attaches the session's raw when the design has none
ok:   W1a16 the invoke ran (mask -> 2) AND a loaded database is never thrown away
ok:   B10 src/ase_window.tcl carries exactly one mask writer, inside ase::ui::annot_apply (1 1)
RESULT: ALL PASS (199 checks)   test_ase_window   (was 182)
RESULT: ALL PASS (10 checks)    test_annot_show_menu (was 26 — see §D)
RESULT: ALL PASS (335 checks)   test_op_annot     (was 335)
```

Built: `ase::has_results` (src/ase.tcl) and six procs in src/ase_window.tcl —
`annot_design_win`, `annot_mask`, `annot_menu_sync`, `annot_goto_design`,
`annot_ensure_loaded`, `annot_apply` — plus the two entries turned into
checkbuttons with a `-postcommand`, and `annot(key,op|volt)` cleaned in
`ase::ui::close`. Deleted: both View checkbuttons, their `-postcommand`, both
procs `annot_show_menu_sync`/`annot_show_menu_apply` (replaced by a headstone
comment naming the reversal), and the two derived `set_ne annot_show_op/voltage`
seeds. `set_ne annot_show 0` is KEPT — that is the mask default (0621), not a
control. The `6`/`Alt-6`/`Ctrl-6` chords and `utils/annot_mode.tcl`'s behaviour are
byte-identical, and could not have been reached: they write the mask themselves and
never went through the deleted procs.

## C. Decisions, with ladder rung and rejected alternative

| # | Decision | Rung | Rejected, and why |
|---|---|---|---|
| D1 | **checkbutton**, not command | L2 | `add command` (the stub's shape) — it cannot display state, and state is the entire content of a visibility control. The bits are booleans (xschem.h:431) and `text_hidden()` gates them independently. ASE-L has no menu-checkbutton convention to violate: it had no menu checkbuttons at all. |
| D2 | the mask **stays per design context**; it does NOT become session-scoped | L2 | a per-session mask — it needs the C pull-cache taught, at all eight bulk-eval entry points, where a session's value lives, and it would make `6` and the ASE-L tick describe different things. The ASE-L control REACHES the design context instead. |
| D3 | the predicate is **`ase::has_results {key}`** = `[ase::last_rawfile $key] ne {}`, defined once | L2 (borrowing I1's argument) | `xschem raw loaded` and `op_annot::_annotated` — both CONTEXT-scoped, so read from a plain Tk toplevel they measure whichever design is current; `_annotated` additionally greys the control exactly when the user wants to turn annotation ON. |
| D4 | greying **and** the tick PULL ride one `-postcommand` | L1 (**I5**) | a refresh from `ase::ui::session_changed` (fires only on session notify, so every chord press leaves a stale tick), and no PULL at all. A user's own rc, the chords and both Op-Annotate items all write this mask without telling any menu. |
| D5 | the PUSH reaches the design via `raise_design_editor <dpath> ifhidden` **and verifies it** | L2 | `always` (issue 0616 measured a WSLg re-map + ~32px NW creep per click), a blind `new_schematic switch` (landmine 17: it silently no-ops under a raised semaphore, so the write lands in a foreign sheet), and opening the design window as a side effect of a visibility toggle. |
| D6 | the new mask is composed **bit-wise** from the design's live value | L2 | whole-mask composition from both ticks (the View pair's shape) — the ticks were painted before any context switch, so it can write a stale OTHER bit over the design's real value; and a pure XOR toggle, which ignores what the tick now shows. |
| D7 | the PULL reads the design's mask **without switching context** | L2 | switching inside a `-postcommand` (a menu that mutates state and moves focus while posting can unpost itself), and reading `$::annot_show` (measured: it describes whichever context wrote last). |
| D8 | ticking a bit ON **attaches the session's raw** when the design has none | **L3** | visibility-only — smallest, but measured that ASE-L never loads a raw into the DESIGN context (`grep -rn 'annotate_op\|raw_read' src/ase.tcl src/ase_window.tcl src/wave_viewer.tcl` returns nothing), so after a real Netlist-and-Run a visibility-only tick renders blanks (I3) and the control looks dead on the very next bench run. Also rejected: calling `cadence::annot_mode` (annot_mode.tcl is not sourced in the stock tree). **See 0684 — this arm has two measured defects.** |
| D9 | the labels stay **verbatim**: `Operating Point info` / `DC Node Voltages` | **L3** | relabelling to the View pair's class-partitioning wording — it would contradict the ruling's own words. **Consequence recorded, not hidden: 0678's PARTITION property is lost** (bit0 gates device OP info AND branch currents, and `Operating Point info` does not name currents). Old row A19 has no successor. This is what makes rule debt [0678] moot; only the user may clear it. |
| D10 | the stock off-ramp closes here and reopens only when **0683** lands | **L3** | fixing it inside this item — the brief forbids it, and it is a different defect: five producers reach a non-zero mask with no ASE-L session. |

## D. The three test traps, stated explicitly

1. **`test_annot_show_menu.tcl` A1–A19** (the brief named A4/A5/A19; the true set
   was wider). The file's SUBJECT was reversed, not shrunk. The deletion half is
   now B1–B10 — every B1–B8 row a negative claim, with B9/B10 as the positive
   counterweight so "deleted the control and built nothing" cannot pass. The
   BEHAVIOURAL half moved whole into `test_ase_window.tcl` as W1a1–W1a17.
   **26 → 10 here, but 543 → 544 across the three annotation suites.** Nothing was
   deleted to reach green. Row A19's partition claim is the one deliberate loss
   (decision D9).
2. **`test_ase_window.tcl:478-481`** — a trap the brief did not name. It PINNED
   both Annotate entries as `-state disabled`; those two goldens were replaced by
   W1a1–W1a4 (shape) and W1a5–W1a17 (behaviour). 182 → 199.
3. **`test_op_annot.tcl` N22/N22b/N22c** — also unnamed by the brief. Source-contract
   greps over `src/xschem.tcl`. **Re-pointed**, not relaxed: the shipped writers are
   now `{2 in src/xschem.tcl, 1 in src/ase_window.tcl}`.

## E. Sabotage matrix

| variant | predicted red | observed | verdict |
|---|---|---|---|
| S1 `annot_apply` neutered | 7 | **7** — W1a8 {2 vs 3}, W1a9, W1a10 {0 vs 2}, W1a13 {1 0 vs 3 0}, W1a15, plus unpredicted W1a14 and W1a16 | caught; W1a6 correctly stayed green (its claim is "nothing is written") |
| S2 `annot_menu_sync` neutered | 6 | **12** — W1a5, W1a7, W1a11 {9 9 vs 1 0}, W1a12, W1a14, cascading into W1a6/8/9/10/13/15/16 | caught |
| S3 predicate stuck TRUE | 3 | **2** — W1a5 {normal normal vs disabled disabled}, W1a6 | caught, weakly: W1a6's behavioural half stayed 1 because the bit arithmetic was a fixed point that run |
| S4 `annot_goto_design` claims success without switching | 2 | **3** — W1a13 read `{1 2}`: the design stayed at 1 and the **DECOY took the write**, landmine 17 caught exactly | best variant, no misses |
| S5 `annot_mask` stuck at 0 | 3 | **3** — W1a11 {0 0}, W1a12, plus W1a9 | caught |
| S6 the DELETION reverted | 7 | **7** — all of B2, B3, B4 {1 1 vs 0 0}, B5, B6 {3 1 1 vs 2 1 1}, B7, N22 {3 1 vs 2 1}; B1 (over-deletion guard) correctly stayed green | the delete-half rows are not vacuous |

### E1. FOUR PREDICTED REDS THAT DID **NOT** APPEAR — and the repair

This is the part worth keeping. Three rows carried comments claiming they were
sabotage-proof, and **all three claims were false for the same reason**: `.`
matches a newline in Tcl regexp, so a pattern like
`{proc ase::ui::annot_apply \{.*?xschem set annot_show}` runs out of a live no-op
**shim**'s header and into the renamed `..._real` body below it.

* **B10** (`test_annot_show_menu.tcl`) stayed GREEN under S1 with the control fully dead.
* **N22b** (`test_op_annot.tcl`) — identical mechanism, identical false comment.
* **N22c** — collateral, off every prediction list: stayed green under S5 with the
  mask reader fully neutered.
* **W1a14** (`test_ase_window.tcl`) stayed GREEN under S5 by **aliasing**: it
  expected tick `0` while the design mask was 1, and a reader stuck at 0 produces
  the same 0.

**Repaired in this commit, and the repair re-measured**: a `proc_src`/`opa_proc_src`
helper slices the proc's OWN body out before matching, and W1a14's design mask
moved 1 → 3 so the expected tick is 1, which a stuck-at-0 reader cannot produce.
Re-run under the same sabotage:

```
S1 -> FAIL: B10 ... (got '1 0' want '1 1')      + FAIL: N22b -> {1 1 0} (exp {1 1 1})
S5 -> FAIL: W1a14 -> {3 0 0} (exp {3 0 1})      + FAIL: N22c -> {1 0 0} (exp {1 1 1})
restore (cp + touch) -> md5 b145b1ab..., grep -rn SABOTAGE src/ empty,
                        199 / 10 / 335 ALL PASS again
```

**B9 is a wrong prediction rather than a defect**: it asserts `info procs`
presence, and a no-op shim IS a defined proc. Its own header disclaims behavioural
coverage. But it means `test_annot_show_menu`'s entire anti-hollow guard rests on
B10 — which is why B10's hole mattered.

## F. Still open

1. **Decision D8's arm is guarded on the wrong predicate — [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md).**
   Two measured defects: the previous run's numbers persist forever (ngspice
   overwrites one stable raw path in place, and the guard early-returns), and an
   unrelated waveform-graph raw (`xschem raw_read`, `annot_p = -1`) blocks the
   attach entirely so the mask goes on and nothing renders. Filed, not fixed.
2. **[0683](0683-annotation-is-reachable-with-no-bound-ase-l-session.md) is a
   BLOCKING sibling.** With the View pair gone, a stock user who clicks
   `Waves > Op Annotate` or `Simulation > Graphs > Annotate` is ON with no menu
   that turns it off — verbatim the 0457 complaint by another road.
3. **Scope mismatch**: the greying predicate is SESSION+FILE-scoped while the
   payload is DESIGN-CONTEXT-scoped. "Enabled" does not imply "you are about to
   see *this session's* results". The benign end is measured (design open nowhere
   → enabled but inert, refusal reported through `ase::echo`); the harmful end is
   item 1.
4. **One unreproduced anomaly**, reported rather than claimed: an adversary probe
   once read mask 2 → 3 while `annot_design_win` returned `{}` and
   `annot_goto_design` should have refused. Six subsequent runs refused correctly.
   If real it is a landmine-17 violation. Worth one deliberate re-probe with the
   menu POSTED at the moment of the invoke — the one condition that could not be
   held constant.
5. **A DESCENDED design window is uncovered by any row.** `annot_design_win`'s
   field-6 arm exists for issue 0168's descended case and `annot_ensure_loaded`
   hands `annotate_op` a level from `ase::session_for_current`, but the suite's
   design sits at top level. A wrong level renders BLANK, not red
   (`sch_waves_loaded()` silently returns -1).
6. **Two ASE-L sessions open at once** is untested end-to-end. The session-keyed
   `annot(key,...)` array is the right shape and odd keys were probed
   (`lib/my cell/schematic`, `lib/foo(1)/schematic`, `lib/a,b/schematic` all work),
   but no row opens a second session.
7. **`xschem set annot_show $new` is the one uncaught call** in an otherwise fully
   catch-wrapped `annot_apply`; a raise there becomes a Tk background error
   mid-gesture. And `annot_apply` never re-checks `ase::has_results` — the only
   gate is the entry's `-state`, which Tk enforces for clicks but not for a
   scripted `invoke`, nor if the raw is deleted after the menu was posted.
8. **`annot_mask` returns 0 both for "the mask is 0" and for "I could not read
   it"** — indistinguishable, so a resolution failure paints two unticked boxes
   rather than reporting anything.
