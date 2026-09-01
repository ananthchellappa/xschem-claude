# 0648 — the OP-card nudge goes silent on exactly the re-run the user makes after acting on it

STATUS: **FIXED 2026-08-23 (status E — one ruling owed, see §Outcome).** Reported
by the user 2026-08-23, reproduced and root-caused the same day. Compound defect: 0636's once-per-cellview latch + a dialog that
discards on close + no positive confirmation anywhere. Related: 0617, 0633, 0636.

---

## What the user did, and saw

> "OP analysis only. No OP info is available with key 6. I get id = blank, gm =
> blank. Node voltages are displayed with Alt-6 and Ctrl-6 does its job. Then, I
> went to Outputs > Save and checked the 'Save device OP parameters'. I re-ran
> the sim and still don't get OP info. This is for tb_bandgap in
> sky130_test_ase."

**The second run said nothing at all.** That silence is the defect.

## The backend is NOT at fault — measured on the user's exact cell

`tb_bandgap`, sky130 descriptors registered, gate forced on in a headless driver:

```
gate=1  op_enabled=1   design_is_dirty=0   op_cards_hit=1
save_cards            -> 469 lines
rendered deck         -> 794 lines, 516 .save lines, 468 device-param cards
                         .save @m.x1.x1.xm4.msky130_fd_pr__pfet_01v8[id]  ...
```

So S3 and S4 work on `tb_bandgap`. (Worth recording: the S4 crew's 468-card
evidence was taken on **`tb_bandgap_opamp`**, a *different* cell — that one yields
187. Both work; the benches are not interchangeable and a report must name which.)

The failure is entirely in front of the gate: **`save_op_params` was never 1 for
the run the user made.**

## The three defects, in the order they bite

### 1. The latch suppresses the message on the re-run (the sharp one)

`ase::op_cards_nudge_ok` (`src/ase.tcl`) keys `op_nudged` on
`lib/cell/view` alone, sets it on first use, and **never resets it** — not on a
state change, not on a gate change:

```tcl
if {[dict exists $op_nudged $k]} { return 0 }
dict set op_nudged $k 1
```

So the sequence a user actually performs is:

| step | gate | what the tool says |
|---|---|---|
| run 1 | off | the nudge: "Tick Outputs > Save All > Save device OP parameters" |
| user ticks the box, tick does not commit (see 2) | off | — |
| run 2 | off | **nothing. The latch already fired.** |

The message exists precisely to tell the user the gate is off, and it is
suppressed on the one run where the user has already tried to turn it on and
needs to know they failed. 0636 asked whether the cadence should be once-per-cell
or every-netlist; this is a third answer neither option covered: **once per
cellview *per gate state*, so a run that is still card-less after the user acted
speaks again.**

### 2. The Save All dialog discards the tick unless OK is pressed

`ase::ui::save_all_dialog` binds the three checkbuttons to `dlg($key,*)` and
commits **only** in `ase::ui::save_all_ok`, which runs from the `OK` button (or
`<Return>`). Every other exit — the `Cancel` button, `ESC` via
`bind_dialog_esc`, the window-manager close — reaches `save_all_cancel`, which
does `array unset dlg $key,opparams` and destroys the window. The tick vanishes
with no indication it was discarded.

That is conventional dialog behaviour, and it is still a trap **here**, because
the dialog's entire content is three checkboxes: a user who ticks one has
expressed the whole intent, and a checkbutton visibly toggling reads as
"applied". Nothing on screen distinguishes committed from discarded.

### 3. Nothing ever confirms the cards WERE emitted

There is a channel for the gate being off (the nudge), for a refusal (0633/0635),
and for under-emission (`last_warnings`). There is **no** message for the success
case. So a user who fixes the gate cannot tell the difference between "it worked"
and "it silently failed again" without descending and pressing `6`.

## What to do

1. **Reset or refine the latch.** Key it on cellview *and* the gate state, or
   clear `op_nudged` in `ase::session_update` when `save_op_params` changes. A
   card-less OP run after the user has touched the setting must speak.
2. **Make the tick's fate visible.** Either commit the three blankets live (no
   OK needed — they are preferences, not a transaction), or say on close that
   changes were discarded. Live-commit is the smaller surprise and matches how
   the rest of the Outputs pane behaves; if OK is kept, the discard must be
   stated.
3. **Confirm success once, quietly.** One line naming the count when cards are
   emitted — `ASE: 468 device OP save cards added` — closes the loop and makes
   0617's diagnosis unnecessary in the common case.

## Landmines

- 0636's latch exists for a real reason: three identical lines per session per
  cell, into a pane and a log people diff. Do not simply delete it.
- `save_op_params` is in `ase::omit_if_empty` and OFF must stay `{}`, never `0`,
  or the key lands in every `.state` a user saves and the 104 committed
  byte-identical fixtures redden.
- The dialog's widget paths (`.allv .alli .levels .btns.proceed`) are what the
  dialog suites drive. Changing the commit model must not rename them.
- A success line must not fire on the `ase::run_existing` path, where the cards
  come from a captured artifact and may not describe this deck (spec landmine 2).

## Acceptance

- Run with the gate off, tick the box, run again with the gate *still* off: the
  second run **says so**.
- Ticking the box and dismissing the dialog by ESC / window close either commits
  or states that it did not.
- A run that emits cards says how many, once.
- The 104 committed `.state` files stay byte-identical.


---

# Outcome — LANDED 2026-08-23, status **E**

Two of the three filed defects were real; **section 3 is refuted** (see below).
The fix is pure Tcl (`src/ase.tcl`, `src/ase_window.tcl`) — no `.c`, no
`Makefile.in`, no `./configure`, no build.

## BEFORE — the measured transcript, verbatim

Driver on the user's exact cell, `sky130_tests_ase/tb_bandgap`, with
`sky130A/sky130_procs.tcl` sourced and `op_annot::descriptor nmos` asserted
non-empty **first** (without it every card count reads zero and the emitter
looks broken — it is not):

```
descriptor nmos registered: 1   gate=''  op_enabled=1
RUN 1 (gate off) said: 1 line(s): {ASE: device operating-point parameters (gm,
   gds, vth, ...) were NOT saved in this deck. Tick Outputs > Save All > Save
   device OP parameters to annotate them (issue 0617).}
RUN 2 (gate STILL off) said: 0 line(s):    <== THE DEFECT
RUN 3 (gate on) said: 1 line(s): {ASE: 468 device OP save card(s) added to the deck.}
```

and the dialog half, under Tk on `:99` with **openbox 3.6.1 live** (not a bare
Xvfb — that distinction is what makes the WM row evidence):

```
wm protocol WM_DELETE_WINDOW on the dialog: ''   (empty = NO handler)
gate before tick         : ''
dlg(opparams) after tick : 1   checkbutton is visibly ON
gate after tick          : ''   <-- STILL OFF, the tick is dialog-local
gate after ESC           : ''   <-- DISCARDED, and nothing was said
dlg record after WM close: 1    <-- 1 = save_all_cancel NEVER RAN
OK path: gate = '1'
```

## AFTER — the same driver, same cell, same WM

```
RUN 1 (gate off)         -> the 0617 nudge, as before
TICK + ESC               -> ASE: Save All was closed without OK — 'Save device
                            OP parameters' was NOT applied. Reopen Outputs >
                            Save All and press OK.
gate after ESC           : ''    (still off — nothing commits on ESC)
RUN 2 (gate STILL OFF)   -> THE NUDGE FIRES AGAIN        <== acceptance row 1
OK                       -> gate '1'
RUN 3                    -> ASE: 468 device OP save card(s) added to the deck.
```

`wmctrl -i -c` on the Tk **wrapper** window (a genuine ICCCM close from openbox,
not the suite's `uplevel #0 [wm protocol …]` shortcut) destroys the dialog **and**
emits the same discard sentence. ⚠ `winfo id` returns Tk's *inner* window, which
carries no `WM_PROTOCOLS`; probing that one and concluding "the handler does not
work" is a targeting error, and it cost the adversary agent a false alarm.

## The finding that reshaped the fix

**This issue's own first suggestion does not satisfy this issue's own acceptance
row 1.** Keying the latch on "cellview **and** the gate state" leaves run 2
silent, because in the user's sequence the gate is **OFF on both runs** — the
tick never committed — so `(cell, off)` is the same key twice. Defects 1 and 2
are therefore **not independent**: the re-arm trigger cannot be the gate's
*value*, it has to be the user's **act**.

Two acts now give a cellview its turn back:

| act | path |
|---|---|
| `save_op_params` actually changes value | `ase::session_update` (old-vs-new compare) |
| an `opparams` tick is **discarded** by the Save All dialog | `ase::ui::save_all_cancel` |

## What landed

`src/ase.tcl`
- `ase::op_gate_on {v}` — **one** normaliser for `save_op_params`, 1 iff the
  value is literally `1`. Three consumers replace their private copies:
  `op_cards_capture` (was `ne {1}`), `render_deck` (was `eq {1}`), and the new
  change detector. Invariant **I1** applied to a gate rather than a vector name —
  two independent normalisations of one key already existed and 0637 is the
  standing proof that the drift bites here. Behaviour byte-identical: `0`, `{}`,
  absent and truthy-not-`1` all stay OFF, so **0637 is untouched**.
- `ase::op_cards_nudge_key {state}` — the latch key lifted out of
  `op_cards_nudge_ok`; one builder, two consumers (the take and the re-arm).
- `ase::op_cards_nudge_rearm {state}` — `dict unset op_nudged <key>`. Idempotent,
  never raises, writes nothing into the state. It is **not**
  `op_cards_nudge_reset`, which forgets *every* cellview and remains the test seam.
- `ase::op_cards_gate_changed {old new}` — its own proc so the guard is
  independently testable and neutralizable.
- `ase::op_cards_count {block}` — the `.save @*` counter lifted into a named
  callee so the success sentence has something a sabotage can neutralize.
- `ase::session_update` re-arms **only when the gate actually moved**, under
  `catch`. Never unconditionally: this proc is the write path for every pane
  mutation (`toggle_flag`, the variables/outputs/analyses editors, the
  temperature field) and an unconditional clear re-creates 0636's
  three-identical-lines-per-session defect. `F19h` pins that.

`src/ase_window.tcl` — **OK-commit is KEPT** (decision D1)
- `ase::ui::save_all_current {key}` — the three blankets as the state holds them,
  normalised. One normaliser, two consumers: `save_all_dialog` seeds from it,
  `save_all_cancel` diffs against it.
- `ase::ui::save_all_close {key}` — the pure teardown (the old cancel body).
  `save_all_ok` now calls **this**, not `save_all_cancel`, so the OK path can
  never emit a discard line by accident.
- `ase::ui::save_all_report_discard {key pending}` — one plain (not `error`)
  `ase::echo` naming the dropped boxes. Precedent for wording and tag:
  `ase::ui::close`'s "closed $key with unsaved state edits (discarded)".
- `ase::ui::save_all_cancel {key}` — diffs, re-arms on a discarded `opparams`
  tick only, reports, then closes. **Name and one-argument signature unchanged**:
  `dialog_buttons` wires ESC and the Cancel button to it centrally.
- `ase::ui::dialog_close_protocol {w cmd}` — registers `wm protocol
  WM_DELETE_WINDOW`, called **only** from `save_all_dialog`.

Widget paths `.allv .alli .opparams .levels .btns.proceed .btns.cancel` and grid
rows `{1 2 3 4}` are unchanged. No new writer of `save_op_params` was introduced,
so OFF stays `{}` **by construction**.

## ⚠ Two sentences in the text above are WRONG, and were measured wrong

1. §2 says "the `Cancel` button, `ESC` …, **the window-manager close** — [all]
   reach `save_all_cancel`". **The WM close did not.** `ase::ui::dialog_frame`
   registers no `wm protocol WM_DELETE_WINDOW` (the only one in
   `ase_window.tcl` was `:277`, the session toplevel), so Tk's built-in default
   destroyed the toplevel and the cancel path never ran — proof: after a real WM
   close the `dlg` record still **existed**, which `save_all_cancel` would have
   unset. A "changes were discarded" notice placed only in `save_all_cancel`
   would have been silent on exactly the path the user's window manager offers.
2. §3 says "There is **no** message for the success case". **There is, and there
   was when this issue was written.** `src/ase.tcl` already echoed
   `ASE: $n device OP save card(s) added to the deck.`;
   `git log -S'device OP save card(s) added to the deck'` returns exactly one
   commit, **44f52f9a, 2026-08-23 06:28 (S4)** — twelve hours before this issue
   was committed (`7bc7b61c`, 18:27) — and the spec documents it at
   `op_annotation.md` "the card count on success". It also already honoured the
   `run_existing` landmine **by construction**: `op_cards_capture` has exactly
   one call site, inside `ase::netlist`. The line was **pinned, not added**:
   `F19k`/`F19l` are the first test coverage it has ever had. (`grep -rn
   "card(s) added" tests/` returned nothing before this step.)

## Decisions, with ladder rung and rejected alternative

| # | rung | decision | rejected |
|---|---|---|---|
| D1 | L2 — and it **refutes this issue's recommendation** | **Keep OK-commit**; make the discard visible. | *Live-commit the three blankets.* The refuted sentence is "Live-commit is the smaller surprise and matches how the rest of the Outputs pane behaves." Measured against it: (a) the precedent it points at, `ase::ui::toggle_flag`, is a **pane** click, not a dialog — no ASE dialog live-commits, so the reference class is wrong; (b) `test_ase_dialogs`' GE1–GE16 header states **zero state mutation** as a property of *every* ASE dialog and `specs/ase_l.md` "Dialog style" states it as spec — live-commit is a contract change across the whole dialog family plus a forced edit to GE10 and to the spec, the opposite of least-surprise and smallest-blast-radius; (c) it makes Cancel a lie and OK a no-op, honestly requiring relabelled buttons in the **shared** `dialog_buttons` (8 dialogs); (d) it introduces a **new writer** of `save_op_params` that must re-implement the `{}`-never-`0` branch — the one landmine this issue calls load-bearing. |
| D2 | L1 — **I1** | One `op_gate_on`, three consumers; one `op_cards_nudge_key`, two consumers. | Leaving the two private gate tests and rebuilding the key inline in the re-arm — three lines saved, the exact silent-drift shape I1 forbids. |
| D3 | L2 | The re-arm trigger is the user's **act**, not the gate's value. | This issue's own "key it on cellview AND the gate state" — measured, it fails acceptance row 1. Also rejected: deleting the latch (0636's landmine) and "nudge every netlist" (reddens `F19b`, green today and pinning the silence deliberately). |
| D4 | L2 | Register `wm protocol` in `save_all_dialog` **only**, via a one-line registrar. | Registering it in the shared `dialog_frame`, changing WM-close semantics for ~8 untested dialogs at once. Filed as **0651**. |
| D5 | L2 | The notice fires for **any** of the three blankets and **names** the dropped ones; plain tag, not `error`. | Reporting `opparams` only (leaves the same trap on the other two); the `error` tag (a deliberate ESC is not an error). |
| D6 | L2 | Only an `opparams` discard **re-arms**; a discarded `allv`/`alli` is reported but does not re-nudge. | Re-arming on any pending checkbox — 0636 noise for an unrelated setting. |
| D7 | L2 | Defect 3 is refuted, so **pin** it, do not add it. | Adding a second success line; moving the count into `render_deck` to widen its reach — `render_deck` runs on the `run_existing` path where the block came from an artifact that may not describe this deck (spec landmine 2). |
| D9 | L2 | Hook the re-arm into `ase::session_update` **only**. | Hooking `session_open`/`session_load`/`session_revert` too — four more sites, four more chances to fire on a load and re-create 0636's noise. A revert that moves the gate costs at most one suppressed nudge. |
| D10 | L2 (guard on D2) | `op_gate_on` is 1 **iff** literally `1`. | Making the extraction the place to "fix" 0637 — that ruling is with the user, and it would flip the gate for any state hand-edited to `save_op_params yes`. |

## 0636 is NOT decided by this

0636 asked *once-per-cell* vs *every-netlist*. This step's answer — **once per
cellview, re-armed when the user acts on the setting** — is a **third option
0636 never offered**. 0636's rule row stays open with the user; a new
`owed.sh add rule 0648` row carries this step's own question.

## Tests

New in `tests/headless/test_ase_final.tcl` (53 → 62): `F19f` key builder,
`F19n` the latch is per-cellview **behaviourally**, `F19g` **the acceptance row
headless**, `F19h` the 0636 noise guard, `F19i` the reverse edge, `F19j` the
normalisation table, `F19k`/`F19l` the success-line pin and its non-vacuity
control, `F19m` the `{}`-never-`0` guard.

New in `tests/headless/test_ase_dialogs.tcl` (158 → 166): `GE10b` the
`wm protocol` is registered, `GE10c`/`GE10d` the discard is stated once and
names the box, `GE10e` non-vacuity (nothing touched → silence), `GE10f` **the
acceptance row, GUI side**, `GE10g` the WM-close path behaves as ESC, and two
`GE10h` rows asserting **zero state mutation survives the fix** — the row that
would have gone red under live-commit, and the reason GE10's own contract is
left untouched.

Both test diffs are **purely additive**: `git diff` shows zero deleted lines, so
no existing assertion was weakened.

## Sabotage matrix

| variant | predicted red | observed |
|---|---|---|
| SAB-A `op_cards_nudge_rearm` emptied | F19g F19i GE10f | **exact** (3) |
| SAB-B `op_cards_gate_changed` → 1 | F19h F19j | **exact** (2) |
| SAB-C `op_cards_gate_changed` → 0 | F19g F19i F19j | **exact** (3) |
| SAB-D `save_all_report_discard` emptied | GE10c GE10d GE10g | **exact** (3); GE10f stayed GREEN as predicted → re-arm and report are independently wired |
| SAB-E `dialog_close_protocol` emptied | GE10b GE10g | **exact** (2); GE10c–GE10f GREEN → ESC and WM paths separately covered |
| SAB-F `op_cards_count` → 0 | F19k | **exact** (1) — the sentence is still echoed once, only the number lies |
| SAB-G `op_gate_on` → 1 | 7 rows | **15 red** — 6 of 7 hit + 9 over-coverage (F19g F19i F19l, C5 marker, C8 the one `.save all` (I2), two F18 rows). **GE10c missed** — see below |
| SAB-H `op_cards_nudge_key` → `{}` | F19f F19g GE10f | **1 red at first: F19f only.** See below |

**Predicted reds that did NOT appear, and what they mean.**

- **SAB-H / F19g and GE10f.** With the key collapsed to `{}`, both stayed green,
  and the reason is structural: the take (`op_cards_nudge_ok`) and the re-arm
  (`op_cards_nudge_rearm`) call the **same** builder, so a uniformly-wrong key is
  self-consistent and no behavioural row can see it. That is I1 working — but it
  exposed a **real hole**: *nothing in either suite ever nudged two cellviews in
  one process*, so the latch's per-cellview scope was asserted only by F19f's
  return-value equality. Under a wrongly-scoped key, cellview A's nudge would
  permanently eat cellview B's — the exact class of silence this issue is about.
  **Closed in this same commit** by `F19n`, which takes the latch on one cell and
  asserts a *different* cell still speaks; re-running SAB-H now gives
  `F19n -> {1 0 0} (exp {1 0 1})`, 2 FAILED / 60 passed.
- **SAB-G / GE10c.** With `op_gate_on` forced to 1, `save_all_current` reports
  `opparams=1`, so the dialog seeds the box ON and the test's `invoke`
  **un-ticks** it; the pending-vs-current diff is still non-empty, so the discard
  still fires once. GE10c's mechanism is polarity-agnostic. Its own claim stays
  honestly covered (SAB-D reds it), but **GE10c must not be counted as protection
  for the normaliser** — SAB-G reddened 15 other rows, which is where that
  coverage lives.

## Suites

`test_ase_final` 53 → **62 ALL PASS** (headless), `test_ase_dialogs` 158 → **166
ALL PASS** (`:99`, `GUI_GATE=0`, openbox live), `test_ase_core` **130**,
`test_ase_window` **179**, `test_ase_persist` **109**/**17**, `test_ase_cosim`
**341**, `test_op_annot` **330**/**336**, `test_annot_show_menu` **25**,
`test_launch_context` PASS, `test_traversal_flag_leak` **11**, T1 **3** counted
lines (the same three pre-existing: the `sg13g2_tests_ase` `library_list` drift
and 0629's anchored `OVERALL: ok` sentinel ×2), T2 **HARNESS: PASS 6/6**.
Acceptance row 4: **104** committed `.state` files, **0** not byte-identical on
load→serialize, **0** containing the string `save_op_params`.

## Still open

- **0652 — the phantom discard, a NEW defect this change introduces.**
  `save_all_cancel` diffs against `save_all_current`, which **re-reads the live
  state at cancel time** instead of a snapshot taken at dialog-open. The dialog
  is modeless, so a Session > Revert while it is up makes the tool assert a
  setting "was NOT applied" when it **is** applied, and spuriously re-arm the
  nudge. Same class as `save.c` RULING D5-1 / invariant **I3**: a plausible wrong
  sentence is worse than none. At HEAD this path was silent and could not lie.
- **0650 — the channel.** Every sentence in this feature goes only to
  `::ciw_echo` (a separate, closable `.ciw` toplevel) and a `#= ` line in
  `Xschem.log`. The ASE session window has **no sink**. The user's report never
  mentions seeing the run-1 nudge at all, so the new discard line inherits
  exactly the same invisibility.
- **0651 — the shared `dialog_frame` WM-close bypass** still affects ~8 other ASE
  dialogs, each leaking its `dlg`/`edrow`/`edchk` records, with no test coverage.
- Two other silent-discard routes this fix does **not** reach, both measured:
  **reopening** Save All after a tick (`dialog_frame`'s `catch {destroy $w}` runs
  neither the protocol nor the cancel path — records go 1 → 0, zero lines), and
  **closing the session window** with a ticked dialog open (`ase::ui::close` does
  `array unset dlg $key,*` — zero lines, **and not re-armed**). Acceptance row 2
  names only ESC and the dialog's own window close, so neither breaks it; both
  are the same trap this issue was filed about. Folded into 0651.
- `ase::session_revert` / `ase::session_load` bypass the re-arm by design (D9).
- If one `session_update` changes the design cellview **and** the gate together,
  the re-arm targets the **new** cellview and the old one stays latched. Deep
  corner, recorded not fixed.
- Pre-existing **I1** deviation, untouched here: `op_annot::_cards_for` builds
  `${dev}[param]` itself instead of going through `op_annot::vector`/`_wrap`.
  Benign today (shared `devpath`, agreement pinned against real ngspice by
  `test_ase_final` F16/F17) and would fail silently if the bracket shape changed.
- Cosmetic: the discard sentence says "Reopen Outputs > Save All" while the menu
  label is literally `Save All…`.

## Status E — the ruling owed

Three behaviours changed for a user with no prior ratification, and D1
deliberately rejected this issue's own recommendation:

> When a card-less OP run has already nudged this cellview once, should the tool
> speak **again** after the user touches *Save device OP parameters* (this step:
> yes — once per cellview, **re-armed on the user's act**), and should the Save
> All dialog keep **OK-commit and state the discard** (this step: yes) rather
> than live-committing the three blankets as this issue recommended?

`owed.sh add rule 0648` plus a `look` row — the discard line lands in the CIW,
and whether the user actually sees it there is precisely what **0650** is about.

---

## A coverage hole the sabotage pass exposed, and did NOT close

Variant **SAB-H** collapsed `op_cards_nudge_key` to `{}` and predicted `F19g` and
`GE10f` would redden. **Both stayed green**, and the reason is structural rather
than accidental: the take (`op_cards_nudge_ok`) and the re-arm
(`op_cards_nudge_rearm`) call the *same* key builder, so a uniformly-collapsed key
is self-consistent and no behavioural row can observe it. That is invariant **I1**
working as designed — a single builder cannot drift against itself.

But it exposes a real gap. **No suite ever nudges two different cellviews in one
process.** Every latch row in `test_ase_final` drives `sky130_tests/test_nfet_final`
and every one in `test_ase_dialogs` drives `aselib/nfet_clean`. So the latch's
*per-cellview* property is asserted only by `F19f`, and only as a return-value
equality — never behaviourally.

Under a collapsed or wrongly-scoped key, **cellview A's nudge would permanently eat
cellview B's** — which is precisely the class of user-visible silence this issue is
about — and only that one value assertion would catch it.

The row that would close it does not exist: take the latch on a state whose design
cell is A, then assert `op_cards_nudge_ok` still returns 1 for a state whose design
cell is B. Owed.

## A second mis-prediction, recorded so it is not mistaken for coverage

**SAB-G** forced `op_gate_on` to 1 and predicted `GE10c` red; it stayed green.
With the gate reading on, `save_all_dialog` seeds the checkbutton ON and the test's
`invoke` *un*-ticks it — the pending-vs-current diff is still non-empty, so the
discard still fires once. `GE10c`'s mechanism is polarity-agnostic. Its own claim
("a ticked box dropped by ESC is REPORTED, exactly once") stays honestly covered —
**SAB-D** reds it — but `GE10c` must **not** be counted as protection for the
`op_gate_on` normaliser. That normaliser is covered elsewhere: SAB-G reddened 15
rows across `F19`, `F19j`, `F18`, `C5`, `C8`, `G5c`.
