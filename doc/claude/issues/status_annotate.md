# Where branch `annotate` actually stands — 2026-08-24

> The other `status.md` in this folder belongs to **`fluid-editing`** and its
> 02xx numbering. This file is `annotate`'s, covering **0600–0667**. The two do
> not share a number space; do not merge them.

**68 issues filed in three days. 16 closed, 52 open.** That number looks alarming
and is partly misleading, so the first job of this file is to say which 52.

---

## 1. The honest breakdown of the 52

| # | class | what it means | count |
|---|---|---|---|
| A | **the user hit it** | reported from a real bench, still not fixed | **5** |
| B | **can bite a real user** | structural, nobody has hit it yet | **4** |
| C | **we broke it ourselves** | introduced by one of OUR fixes in the last 72h, found by our own adversary legs | **9** |
| D | **rulings, not defects** | shipped behaviour nobody ratified; the code works, the decision is unmade | **14** |
| E | **test/environment holes** | the suite is blind somewhere; no live defect | **6** |
| F | **deferred by the user** | explicitly parked | **2** |
| G | remainder | small, measured, unprioritised | 12 |

**Class C is the count inflating itself, and it is the process working, not
failing.** Every one of those nine was found by the adversary leg of the crew
that wrote the code, *before* it reached the user — 0652 against 0648's fix,
0664/0665/0666 against 0658's, 0640 against 0635's, 0641 against 0618's. The
alternative is not "nine fewer bugs", it is nine bugs shipped silently. Two
fixes were refuted by their own adversaries and **reverted rather than shipped**
(0617's blank-row message, 0616's first cut).

**Class D is not brokenness at all.** Fourteen decisions are sitting in the queue
waiting for a human. The code runs; it just runs a way nobody has ratified.

So the sentence "a lot of things are broken" is true of roughly **nine items**
(A + B), not fifty-two.

---

## 2. Class A — the user hit these, they are still open

| id | what you saw |
|---|---|
| 0649 | the simulation-log window shows the raw stream, never the framed log file — no scrollback, no filename, no completion line |
| 0612 | reproduced twice on the real screen |
| 0617 (display half) | a sheet whose OP rows are blank says nothing. An attempt was made and **REFUTED on your own bench family** — 35 of 104 `.state` files carry `savecurrents`, which gives every device a free `i(@dev[id])`, so the any-membership test declared a 5-of-6-blank sheet healthy. Reverted. |
| 0625 | a missing vector renders `-`, not blank — I3 says blank |
| 0647 | the design window may be *under* the restored waveform viewer rather than gone |

---

## 3. Class B — structural, and one of them is in a different league

### 0663 ✅ FIXED 2026-08-24 — it was the only item here that stopped the tool from starting

```
BEFORE                                          AFTER (src/xinit.c:3571)
error at the TOP of any late-sourced helper  -> exit 139  ->  exit 1, file named
error at the END of it                       -> exit 139  ->  exit 1, file named
the file ABSENT (the pure 0424 shape)        -> exit 139  ->  exit 1, file named
```

One line, to stderr **and** the durable log, once per failure:
`STARTUP ABORTED: <sourced> did not finish. Failing file: <helper> line N.
Cause: <the error>. …` — where before, the durable log got **nothing** and the
`error {...}` shape named the helper nowhere at all.

Fixed in C at **one call site**, covering all fifteen bare sources and any added
later. `src/xschem.tcl` was deliberately not touched. Answered as **(b)
announce-and-abort**, against the driver's recommended (a) — status **E**, the
ruling is in `owed.sh`. ⚠ **Not 100% closed**: a *non-error* early `return` still
segfaults (**0671**), the announcement can name the wrong file (**0672**), and a
plain interactive GUI launch still hangs on a modal instead (**0669**).

`src/xschem.tcl` sources sixteen helpers with a **bare `source`**. An error inside
one propagates out of `xschem.tcl`, so the rest of that file never runs — no
statusbar widgets, no `build_widgets`, no colour setup. `source_tcl_file()`
(`src/xinit.c:1513`) prints and returns; **`Tcl_AppInit` ignores the return value**
(`src/xinit.c:3406`) and walks on into `tclgetdoublevar("cairo_font_line_spacing")`
against variables nobody set. That is the crash.

**This is the root cause of issue 0424, not a relative of it.** 0424 lost
`op_annot.tcl` from the install list; 275 in-tree checks stayed green and the
*installed* binary was dead on arrival. The fix then was to add the file back to
the install list. The crash mechanism was never touched, and `op_annot.tcl` was
still one of the sixteen bare sources until 0663 landed. It still is — that is
now deliberate: the C backstop covers it, so **do not add `catch` wrappers**.

The test suite is **structurally blind** to it: in-tree, `XSCHEM_SHAREDIR`
resolves to `src/`, so a file missing from the install list is still found. Only
an installed-tree check or a deliberate sharedir farm
(`tests/headless/sharefarm.tcl`, new) can see it.

Exactly one of the sixteen is now guarded, by 0658:

```
14854:  if {[catch {source $XSCHEM_SHAREDIR/ciw.tcl} ciw_source_err]} {   <- guarded
14796:  source $XSCHEM_SHAREDIR/op_annot.tcl                              <- 0424's own file
14802:  source $XSCHEM_SHAREDIR/ase.tcl
14804:  source $XSCHEM_SHAREDIR/ase_window.tcl
        ... twelve more, all bare
```

The others: **0619** (`ps_colors[cadlayers]` heap over-read), **0641** (the log is
truncated at launch), **0632** (the OP walk rewrites `~` autosave backups of
ancestor cells you never touched).

---

## 4. The notify channel is half-built and currently lands nowhere

Three days of work built a real notification channel (0650, 0658) and it is
**not yet reaching you**:

* **0655** — the ASE session window, the one you drive simulations from, still
  has no notice sink at all.
* **0659** — a CIW that is *open but stacked behind* the design window reaches
  **zero visible sinks**. It tests as open and behaves as shut. Measured:
  `ismapped 1 · viewable 1 · statusbar unchanged`.
* **0667** — the degraded mode is log-only, so a GUI user sees nothing on screen.
* **0654 / 0660** — the drawing-window fallback field is 28 chars, silently
  clipping, shared, last-writer-wins, and carries no remedy. It structurally
  **cannot** carry the menu-path-plus-command sentence ruling R-0653-d requires.
* **0664 / 0665 / 0666** — introduced by 0658's own fix. One notice can write
  **two** durable lines, and can claim "DEGRADED" while the channel is fully live.
* **0674 / 0675 / 0677** — batched and **attempted 2026-08-25; reverted** (§6d).
  Still open. **0675 is the one that makes the rest matter**: the announcement
  measures PROC IDENTITY, not SINK REACHABILITY, so the channel can be ALIVE by
  its own test and reach nobody, silently. Measured at HEAD: `degraded=0`,
  `notify` returns 1, witness `sinks={ciw log}`, and **zero** sinks reached.
* **0800** — the popup sink is the one nothing measures: an **iconified**
  `.xschem_notify` is still recorded as a reached sink. Bears on ratification
  [0650](b) — a ruling for `::notify_style popup` makes it the *only* on-screen
  sink.
* **0699** — `notify_log` returns 1 and the witness names `log` while
  `actionlog_suppress` discards every byte. The sink the table calls "always".

Net effect: **the machinery to tell you why an annotation is blank now exists,
and there is no reliable place for it to appear.** That is the single most
important gap on this branch, and it is what 0653 was ratified to close.

---

## 5. ~~RECOMMENDED FIRST ACTION~~ ✅ DONE 2026-08-24 — 0663 was fixed as a class, in C

**This section's recommendation was carried out.** It is kept, not deleted,
because its reasoning is what the crew was measured against and points 1-5 below
all held up. **The new first action is item 1 of "Then, in order".**

What landed: `if(source_tcl_file(name) != TCL_OK) xschem_startup_abort(name);` at
`src/xinit.c:3571`, plus four C89 statics. Not `ciw.tcl` again; not sixteen
`catch` wrappers — and the crew *measured* why the wrappers would not have
worked: with all fifteen sources wrapped, **2 of 16 still exit 139**, because
`src/xschem.tcl:14569` `load_action_table` and `:16873` `wviewer::rawhist_load`
are bare top-level **calls** that escape a source-only catch. Point 3 below was
therefore an understatement.

⚠ **Point 4 below turned out to be wrong on one clause.** It predicted 0658's
per-file `catch` "becomes redundant". Measured: it is **not** redundant. Under
the (b)-shaped fix that wrapper is the only thing keeping a broken `ciw.tcl`
alive-and-degraded rather than clean-aborting, so removing it is a behaviour
regression. The ruling did **not** generalise for free either — it changed shape:
0663's question is now "should xschem's own helpers abort or continue", and
`ciw.tcl` is the deliberate exception.

New issues filed by that crew: **0668-0673**. Number the next from **0674**.

The original text follows.

Not `ciw.tcl` again. Not sixteen `catch` wrappers. Fix
`Tcl_AppInit` / `source_tcl_file` so a failed helper source cannot walk on into
unset variables.

**Why this one first, ahead of the notify work and ahead of class A:**

1. **It is the only item on the branch that makes the tool not start.** Exit 139
   at launch outranks every blank row and every missing message.
2. **It has already shipped once** (0424) and was closed with a band-aid on the
   install list. It will ship again — sixteen files are exposed and a
   seventeenth added next year gets it wrong by default.
3. **Wrapping each source is sixteen chances to miss one.** A single fix in
   `Tcl_AppInit` covers every helper including ones not yet written.
4. **It dissolves an open ruling instead of adding one.** 0663's question — "should
   a broken `ciw.tcl` start degraded rather than SIGSEGV?" — is currently scoped
   to one file. Fix the class and the answer generalises for free, and 0658's
   per-file `catch` becomes redundant rather than becoming a pattern to copy
   fifteen more times.
5. **It disturbs nothing else.** It is in C, below all the Tcl work; the notify
   crews can proceed afterward without rebasing around it.

Cost: one crew. C change plus a sharedir-farm suite that is already written.

### Then, in order

1. ~~**0664 + 0665 + 0666 as one crew**~~ — **DONE 2026-08-24** (status E).
   0665 and 0666 FIXED; **0664 only PARTIALLY** — its replacement sentence was
   refuted by the crew's own adversary leg and corrected in the write-up, and
   the real fix is **issue 0675**: `notify_channel_degraded` measures **proc
   identity, not sink reachability**, so a `ciw.tcl` failing between `notify`
   (`:256`) and `ciw_echo` (`:464`) is announced as a *fault* while the pane is
   dead for the session. **Fold 0675 into the 0655+0659+0667 crew below** — it
   is the same question ("where does a notice actually land") and fixing it
   around them would be wasted work. Also filed: 0674, 0676, 0677.
2. **0655 + 0659 + 0667 as one crew** — all three are "where does a notice land
   when the CIW cannot take it". Needs your 0655 ruling first (recommendation:
   an ASE session-window notice segment; the statusbar demotes to a pointer).
3. **0653's annotation consumer** — the six blank-causes in `op_annot::text`, the
   per-pass tally, the remedy strings. This is what you originally asked for; it
   is last because it needs a channel that works.
4. **0649**, the log window.

---

## 6. What is NOT broken

Worth stating, because the issue count hides it.

* The OP-annotation feature works end to end on a real bench. Measured on
  `tb_bandgap`: `id = 4.944u | gm = 7.749u | gds = 9.592u | vgs = 1.805 |
  vth = 1.017`, with node voltages surviving (365 before, 365 after).
* The chords behave as ruled: `6` adds OP info **and branch currents**, `Alt-6`
  adds node voltages **alone**, `Ctrl-6` clears — two additive setters and one
  clear-all, never a toggle. ⚠ **The branch-current membership was REVERSED on
  2026-08-24 (issue 0678)** after the user drove the real bench: it used to ride
  `Alt-6` with the node voltages. A device's terminal current is device OP info;
  a node voltage is a property of the net. Colour is unchanged (layer 17).
* ngspice does **not** need modifying. A bare `show` in a `.control` block dumps
  every OP parameter of every device (spec §3.1, rule R5); save cards stay
  primary because `show` is operating-point only.
* Tiers at HEAD: `test_ase_core` **172** · `test_ase_log_seam_0207` **48** ·
  `test_startup_guard_0663` 22 · `test_ase_final` 67 · `test_ase_dialogs`
  166 · `test_ase_window` 182 · `test_ase_cosim` 341 · `test_op_annot` **335** ·
  T2 6/6. T1's 3 FAIL are pre-existing and unrelated, as is `test_ciw`'s 1
  (issue 0670). (`test_ase_core` 159→172 and the seam 41→48 on 2026-08-24, the
  0664+0665+0666 crew.) ⚠ `test_ase_core`'s NTD block reads spawned children's
  `Xschem.log` and flaked **once in 20 runs** — issue **0676**, a harness
  fragility, not a product defect.

## 6a. 0683 + 0684 — attempted, refuted, reverted 2026-08-25

The binding pair 0682 left behind. A complete pure-Tcl fix reached **22 / 207 / 342**
ALL PASS with a fully trustworthy 8-variant sabotage matrix, then failed its own
acceptance under adversarial probing and was **reverted in full**. Suites are back at
**10 / 199 / 341**; T1 and T2 unmoved; no build was run or needed.

Three refutations, each re-measured on a clean tree: (1) the orphan state is still
reachable through sanctioned doors — annotate from ASE-L, `File > Open` another cell,
close the session — because `annot_show` is per-**window** while a session's handle on
its design is a **cellview path** (issue **0688**); (2) 0684's headline case, a re-run
with annotation simply left on, still paints the previous run's number — the three
rows written for it all untick first, so none could see it; (3) the 0685 workaround
destroyed a loaded waveform database when the re-read failed, where the old guard had
survived.

Filed by that crew: **0685** (`annotate_op` reuses a stale registry database at the
same path), **0686** (`ase::ui::close` leaves the design annotated — the sixth orphan
producer), **0687** (`test_backannotate_digital` litter + a guard that misses it),
**0688** (the reason for the revert), **0689** (`run_regression.tcl`'s sentinel
false-reds a suite printing a count), **0690** (`test_ihp_sg13g2_libmgr`'s golden is
one library behind). **0689 + 0690 are all three FAIL lines in this branch's T1
baseline.** Next free number: **0693** (see §6b).

Full record: `doc/claude/suggestions/next_session_prompt_op_annotation.md`, block
"⚠ 0683 + 0684 — ATTEMPTED, REFUTED, REVERTED"; issue **0683 §7** and **0684 §7**;
spec §6a/§6b.

## 6b. ✅ 0679 — FIXED 2026-08-25. THE ONE ITEM ON THAT QUEUE THE USER PERSONALLY HIT

You ran without "Save device OP parameters" checked, got the notice, pasted the
command it printed, **were told `1`**, and the box was still unticked. Both halves
of that are now fixed, pure Tcl, no rebuild.

```
BEFORE                                                   AFTER
REGISTERED sky130_tests_ase/tb_bandgap/ngspice_state1     unchanged
PRINTED    sky130_tests_ase/tb_bandgap/schematic          .../ngspice_state1
update_rc 0  apply_rc 1  gate_real 0                      gate really goes to 1
```

**(a)** The remedy key was *built* from the state's DESIGN cellview while every
session registers under its STATE view — two independent constructions of one
string, which could never agree for any session on any cell. It is now a **lookup
in the registry** (`ase::op_cards_remedy_key`), and when it cannot resolve exactly
one session it prints the menu path and **no command** rather than a key nobody is
under. **(b)** `ase::ui::save_all_apply` ended in a hardcoded `return 1`, so the
`1` you read was manufactured; it now returns `ase::session_update`'s answer and
echoes one error line naming the key when it fails. `save_all_ok` was audited the
same way.

**A third symptom nobody had recorded**: because the 0648 re-arm sits *below*
`session_update`'s early return, the failed remedy also ate the latch — after
following the advice you would **never be told again** for that cellview. Fixed by
the same change (`run1 nudges 1 / told 1 / run2 nudges 0` → the re-arm lands).

Suites **76 / 202 / 172 / 342 / 10** ALL PASS (`test_ase_final` +9 rows,
`test_ase_window` +3 GUI rows); T1/T2 unmoved. Status **E** — one ruling is owed
(should a failed paste **raise** so the CIW red-tags it, rather than return `0`
plus one sentence?) and one **`look`** debt: everything was proven on Xvfb `:99`
against `test_nfet_final`; **please repeat your own gesture on `tb_bandgap`.**

Filed by that crew and **since FIXED (2026-08-25)**: **0691** (`do_load_state_from`
fabricates its witness the same way; `do_save_state_as` and `ase::session_close`
are weaker arms) and **0692** (a `Save All` dialog left **open** while you paste
the remedy snapshots the old value and writes it back on OK — silently undoing the
remedy, while OK's `1` is perfectly truthful. The 0679 fix is what creates that
window). See §6b.

Full record: issue `0679-*.md` (§FIXED), plan block
"✅⚠ 0679 — LANDED 2026-08-25", spec §I1 and the ratification table.

## 6b. 0691 + 0692 — the fabricated witness one proc over, and the stale dialog

**LANDED 2026-08-25, status E. Pure Tcl, no rebuild.** Both were filed by the
0679 crew with the measurement already done; this crew verified, fixed and swept.

**0691** — three procs stopped manufacturing a `1`: `do_load_state_from` (through
a new named seam `ase::ui::load_state_commit`, the twin of 0679's
`save_all_commit`), `ase::session_close`, and `do_save_state_as` (which now
**refuses before any write**, through a new `ase::session_exists`). Measured
`do_load_state_from(BOGUS) 1 → 0`, `session_close(NEVER_HELD) 1 → 0`.
⚠ `do_save_state_as` was worse than filed: for an unknown key `session_path`
returns `{}` — the same marker as a registered-but-UNTITLED session (issue 0141) —
so it ran the adopt arm, **created a view and wrote a state file to disk**, and
returned 1.

**0692** — an open `Save All` dialog is no longer a snapshot. OK now reconciles
per field (the user's value for a box they touched, the LIVE value for one they
did not) and ESC diffs against the as-opened seed. `gate_after_ok 0 → 1`;
`phantom_discard_notices 1 → 0`. `save_all_ok`'s `1` was honest throughout and was
**not** changed — the repair is to the staleness.

**THE SWEEP**: 29 procs ending in an unconditional `return 0/1`; 3 fixed, 2 issues
filed covering 3 procs, 6 measured honest, ~20 recorded as unexercised rather than
implied clean.

Suites **208 / 172 / 78 / 342 / 10** ALL PASS (`test_ase_window` +6,
`test_ase_dialogs` +6, `test_ase_final` +2); T1/T2 unmoved.

⚠ **It shipped with two measured residuals, and one of them is blocking.**
**0695** — an *untouched* box takes the live value but the checkbutton does not
follow it, so an open dialog can DISPLAY a ticked box while OK writes it **off**
(reached with `Save All` open, then `Session > Load State`, then OK). That deck
then goes out with no OP save cards while the dialog says they are on, so 0695 is
**not** the cosmetic lag it was first filed as. **0696** — a *new* false "NOT
applied" notice on hand-tick + external write + ESC, a gesture HEAD was silent
about.

Filed by this crew and NOT fixed: **0693** (`design_window` +
`raise_window_entry` report a raise they never verified — this **refutes** a
sentence in 0691 that cleared `raise_window_entry`), **0694** (`toggle_flag`,
widened to the real class: **13** discarded `ase::session_update` call sites, the
OK handler of nearly every ASE-L editor dialog), **0695** and **0696**.
**Next free number: 0697.** *(now 0699 — see §6c)*

Full record: issues `0691-*.md` / `0692-*.md` (both §AFTER), plan block
"✅⚠ 0691+0692 — LANDED 2026-08-25", spec §0692 and the ratification table.

## 6c. ✅ 0695 + 0696 — the box that follows, and the ESC notice that stopped lying

**LANDED 2026-08-25, status E. Pure Tcl, ONE product file, no rebuild.** These
were the two residuals §6b shipped with, fixed the same day as **one item**
because both ask one question: *what does this dialog consider the user's intent,
once the checkbutton's value can move underneath them?*

**0695** — an open `Save All` dialog's checkbuttons now **follow** a write that
lands behind them, painted from the very dict OK will write, so what you see is
what OK writes. Measured through two shipped menu items:
`WU-B2 … box_still=1 → 0` with `gate_after_ok=0` unchanged — the fix is that the
**box** moved, not that the gate did.

**0696** — the ESC arm stopped reporting a discard for a setting that DID apply.
Hand-tick a box, let an external write set the same blanket to the same value,
press ESC: `notices 1 → 0`, `gate_after_esc=1` unchanged. The two contrast arms did
not move (a plain hand tick still reports exactly once; an untouched dialog is
still silent).

**The mechanism, because it binds anything that touches this dialog:** "touched" is
now an **event on the widget** (`-command`), never a value diff — measured in both
directions, a value diff either silently discards the user's own tick or reinstates
0692's phantom notice. The as-opened `seed` record is **deleted**.

Suites **214 / 174 / 341 / 78** ALL PASS (`test_ase_window` +6, `test_ase_dialogs`
+2); T1/T2 unmoved.

⚠ **What is still owed to you.** Rule debt **[0692]** was RESTATED, not answered:
the box now moves under your eyes **with no word said** — acceptable, or should the
tool SAY the dialog raced? A `look` debt names four bench gestures (the two fixes
plus two controls that must not move). **Suites green, please look.**

Filed by this crew and NOT fixed: **0697** (`ase::session_open`'s re-open refresh
arm replaces a clean session's state from disk without firing the notify hook — so
0695's symptom survives on that one path, and the title's dirty marker and status
bar do not refresh either) and **0698** (`test_ase_final` passes `--nogui` and
aborts under X; pre-existing, and invisible because the branch baseline only ever
ran it headless). **Next free number: 0699** *(now 0802 — see §6d)*.

Full record: issues `0695-*.md` / `0696-*.md` (both §RESOLUTION), plan block
"✅⚠ 0695+0696 — LANDED 2026-08-25", spec §0692 and the ratification table.

## 6d. 0674 + 0675 + 0677 — attempted, refuted, reverted 2026-08-25

The notify-channel cluster, batched deliberately: **four crews had filed 24 issues
against this one channel and closed 6**, each seeing only its own slice and each
filing the next crew's work. Batching was right. The fix was not.

A complete pure-Tcl implementation reached **188 / 55 / 23 / 79 / 214 / 174** ALL
PASS across six suites with a trustworthy 8-variant sabotage matrix, then failed
its own acceptance under adversarial probing and was **reverted in full**. `src/`
is byte-identical to `e9232ec3`; suites re-verified after the revert at
**172 / 48 / 22 / 78 / 214 / 174**; T1 and T2 unmoved; no build run or needed.

It built exactly what the brief asked for — **ONE** predicate,
`xschem::notify_reach`, answering "can a notice reach a human right now" per sink
over `visible | blind | dead | off`, consumed by both sink gates and all three
announcements, plus a third voice (`NOTICE CHANNEL UNREACHABLE`), one channel
exit, two **existing** I1 breaches collapsed, and 0662 closed.

**The refutation, re-measured by the write-up agent before reverting:** three arms
probed the widget actually written; the **fourth asserted**. The popup arm never
looked at `.xschem_notify`. So in the shipped opt-in `popup` style, with the other
sinks destroyed and one ordinary click (`wm iconify`), the channel passed its
**own new test**, returned "delivered", named a sink, reached nobody, and said
nothing — verbatim the state the brief demanded the red phase construct. The
item's whole subject survived into its own fix as a better-hidden instance.

The 1885-line diff is preserved and re-appliable at
`doc/claude/evidence/0674_0675_0677_attempt/`. **Most of it is right.**

Filed by this crew: **0699** (`notify_log` claims the durable sink while
`actionlog_suppress` discards every byte), **0800** (the popup mark claims an
iconified popup — HEAD-level, 0662's shape one sink over) and **0801**
(`test_ase_window` is load-sensitive: 2 red in 48 runs, and 3/3 red on **pristine**
code under 12-way load). **Next free number: 0802.** ⚠ The sequence across the
reserved block is **0698 · 0699 · 0800 · 0801 · 0802** — never 0700.

Rule debts **[0650] [0655] [0664] [0677]** restated, never answered; three `look`
debts added. Nothing cleared, converted or discharged.

Full record: `doc/claude/suggestions/next_session_prompt_op_annotation.md`, block
"❌ 0674+0675+0677 — ATTEMPTED, MEASURED GREEN, AND REVERTED"; issues **0674**,
**0675**, **0677** (each §2026-08-25); spec §the notify channel + ratification
row 0650.

---

## 7. A note on elapsed time, so the next long run is not a mystery

Two crews have appeared to take 5–7 hours. Both were the **Windows host sleeping
and freezing the whole WSL2 VM** — 1.93 h of real agent work inside 7.38 h of wall
clock on the 0658 run, with all three live agents freezing within 47 seconds of
each other. `tests/headless/runtime_gaps.sh` now decomposes any run and names the
cause from the `btime` contradiction. The host sleep timeout has since been set
to Never.
