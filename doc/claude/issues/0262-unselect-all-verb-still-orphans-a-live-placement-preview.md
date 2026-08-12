# 0262 — the bare `xschem unselect_all` verb still orphans a live placement preview, and it is the last terminal door

Status: **DECIDED and LANDED 2026-08-11** (item D8 of the 2026-08-11 unattended backlog run, at
`2f866dec`) — see *Resolution* at the bottom. The verb stays **ungated** on purpose; the terminal
half of the whole class is answered once, class-wide, by a **repairing**
`check_placement_preview_invariant()`. Item status **E**: the change is user-visible and no prior
ratification covers it, so a human must confirm the shape (the question is in decision **D4**).
The orphan object and its net rename are a **knowingly kept** residue.
Two of this issue's original claims were **measured FALSE** and are struck through below: "not
reachable from the GUI" (issue **0397**) and "the last terminal door" in the title (issue **0358**).
Area: `src/scheduler.c` (the `unselect_all` verb) vs `abort_placement_preview()` / the
`leave_placement_for()` door in `src/callback.c`
Tests: **asserted** since 2026-08-11 — `tests/headless/test_placement_preview_doors.tcl` section F,
29 new checks (177 → **206**), replacing the single `note:` line this issue used to be recorded by.
Found: 2026-08-08, closing issue **0242**
Related: **0242** (parent — the other nine doors are fixed), **0123** (the desync root), **0241**,
**0243** F2, **0263** (the other 0242 residue, fixed), **0397** (this door IS GUI-reachable),
**0358** (`save`, the second class-D door, still open), **0398** / **0399** / **0400** (filed by
this item's verification), `WIRING.md` §8 class **D**.

## Symptom

```tcl
set ::label_new_name FOO
xschem clear force ; xschem wire 0 0 100 0 ; xschem unselect_all
xschem add_wire_label -place      ;# preview on the cursor: ui=16424 sp=1
xschem unselect_all               ;# <-- the door
xschem abort_operation ; xschem abort_operation ; xschem abort_operation
```

```
after unselect_all : sympin_preview=1  START_SYMPIN=0  orphans=1
after 3x ESC       : sympin_preview=1  orphans=1   -> instance_net l1 p = FOO
```

Identical to 0242's headline repro: `unselect_all()` (`select.c`) zeroes `ui_state` wholesale
because the preview is selected, dropping `START_SYMPIN|STARTMOVE` without running the placement
teardown. `sympin_preview` / `wirelabel_preview` are not `ui_state` bits, so they survive, and the
preview instance was never `delete()`d — it is now a committed, connected, netlist-visible
`lab_pin` silently renaming the net. With `sympin_preview` stuck at 1, `callback.c`'s Button-1
select/grab block (guarded `!sympin_preview`) refuses every press and `wire_label_try_commit()`
refuses every drop, and ESC cannot repair it because `abort_placement_preview()` is gated on the
bit that is gone.

## Why 0242 did not fix it

0242 gated the nine doors that **arm a second gesture**, under the ratified rule "whatever you just
pressed is what you meant" (0240 / 0243 F2). `unselect_all` arms nothing — there is no second
gesture, so that rule has no subject and "abandon the preview" is not obviously what the caller
meant.

And the obvious placement is barred: the teardown must not go inside `unselect_all()` itself. That
is issue **0123**'s stated reason — 87 C call sites and 817 scripted ones, several inside netlisting
and live fluid passes, and it would make a *deselect* silently `delete()` objects. Gating the
scheduler **verb** is a smaller version of the same hazard: `xschem unselect_all` is called from
`src/xschem.tcl`, `property_form.tcl`, the test corpus and any user rc, almost always as a
housekeeping step and never as "cancel my pending gesture".

So the residue was left standing, reported rather than papered over. ~~It is not reachable from the
GUI: no key, menu item or toolbar button issues the bare verb while a preview is live.~~

> **STRUCK 2026-08-11 — MEASURED FALSE, issue 0397.** Two GUI routes, both reproduced: the
> **default chord Ctrl+Button2** (`button,2,ctrl,canvas,edit.cycle_pin_type` → `addpin::cycle_type`,
> whose re-arm guard tests `[winfo exists .addpin]` and so falls through for a live `.addlabel`
> preview) and the **Hilight ▸ Compare schematics** menu item, whose entire `-command` body is
> `xschem unselect_all ; xschem redraw`. This sentence was the sole premise of option 3 below, and
> its falsity is why the decision is option 2. `doc/claude/FAQ.md` Q41 had said so informally since
> 2026-08-09; this issue was never corrected until now.

> **ALSO STRUCK — the title's "the last terminal door".** `save`/`saveas`/Ctrl+S reaches the
> identical desync through `save_schematic()`'s own `unselect_all(1)` and additionally **persists**
> the undropped object into the `.sch` (issue **0358**, open). Measured by this item's scout, and
> not previously in 0358: the same save door also silently commits a live `PLACE_SYMBOL` preview
> (ui 8232 → 0, instance kept, `modified` → 0) and a pending `STARTMERGE` paste (ui 296 → 0, wires
> kept, `modified` → 0).

## Options (~~undecided — needs the same ratification 0243 F2 got~~ — **DECIDED 2026-08-11: option 2, in a repairing form. See the Resolution below; the reasoning here is kept as the record of what was weighed.**)

1. **Gate the verb** with `leave_placement_for("Deselect")`. One line, consistent with the other
   nine doors. Cost: a scripted deselect silently deletes the preview instance, and 817 call sites
   inherit that. Worst case is a helper proc that deselects mid-form and destroys a preview the
   user is still typing a name for.
2. **Self-heal at the tripwire.** `check_placement_preview_invariant()` already detects the state
   exactly and with no false positives; on detection it could clear `sympin_preview` /
   `wirelabel_preview` (no `delete()`, no undo, no object touched) and log loudly, exactly as
   `fluid_gesture_arm()` already does for a leaked snapshot. That converts every *remaining and
   every future* door from **terminal** to **orphan-only** — the canvas is never dead again — while
   still leaving the orphan visible and the log honest. It does not delete anything, so it carries
   none of option 1's risk.
3. **Do nothing**, keep the report. Correct only if the verb is genuinely unreachable while armed
   in practice.

**Recommendation: 2, then reconsider 1.** Option 2 removes the terminal half of the whole *class*
rather than this one instance, which is the property 0242 kept failing to get one door at a time.
It was deliberately not implemented in 0242 because the issue asked for a log-only tripwire and a
self-healing one is a behaviour change.

## Landmine

Option 2 must not fire during an arm. It does not today: the three `-place` arms were made atomic
in 0242 (`sympin_preview` is raised WITH `START_SYMPIN`, on the success path), which is what took
the tripwire from 11 false positives on a healthy 6-keystroke arm to zero. Any new placement arm
must keep that ordering, or a self-healing tripwire would clear a live preview's flag mid-arm.

---

# Resolution — 2026-08-11, item **D8** of the unattended backlog run (branch `open_pdk`, at `2f866dec`)

**RATIFIED: option 2, in a repairing form. The bare `xschem unselect_all` verb stays UNGATED,
permanently, and that carve-out is no longer an open question.**
`check_placement_preview_invariant()` (`src/callback.c`) is ratified as the permanent, **class-wide**
answer to the terminal half of `WIRING.md` §8 class **D** — but it no longer only reports: its
detection branch now calls a new `repair_orphan_placement_preview()`, which un-sticks
`sympin_preview`, `wirelabel_preview` and (conditionally) the `preview_sel` stamp, posts one held
status line, and **deletes nothing**.

Every door in the class — this verb, both GUI routes of issue **0397**, `save`/`saveas` (issue
**0358**), and any thirteenth door nobody has found — therefore goes from **TERMINAL** to
**ORPHAN-ONLY**, at one site, within one `xschem()` command or one `callback()` event of the door.

## 1. BEFORE — measured this run, quoted verbatim from the Measure agent's transcript

```
ARMED  : ui=16424 sp=1 inst=1
placement_preview: sympin_preview=1 outlived START_SYMPIN at xschem() entry (ui_state=0
  wirelabel_preview=1 instances=1) -- issue 0242: an ungated door cleared the gesture bits without
  tearing the preview down; click-select and wire_label_try_commit() are dead until the flag is cleared
DOOR   : ui=0 sp=1 START_SYMPIN=0 inst=1
ESCx3  : ui=0 sp=1 inst=1 mod=1
NETNAME: FOO
ABORTx3: ui=0 sp=1 inst=1 mod=1
STUCK  : sp=1
AFTERCLR: sp=0 inst=0
```

i.e. **neither** the new 0245 ESC terminal (`xschem escape`) **nor** `abort_operation` can repair
it; only `clear_drawing()` — reached by `clear`/`load`/`new`, i.e. **discarding the document** —
clears the flag. And the undropped `lab_pin` has already renamed the wire's net (`NETNAME: FOO`).

GUI route 1 of issue **0397**, reproduced headlessly by the Measure agent because
`info commands winfo` is empty under `--nogui` and the same fallback branch runs:

```
GUARD  : winfo-avail=0 addpin-exists=0
CYCLE  : ui=8 sp=1 START_SYMPIN=0 inst=1 err=0
ESC3   : ui=0 sp=1 inst=1 net=FOO
```

The `save` door (issue **0358**), same run:

```
ARMED2 : ui=16424 sp=1 mod=1
SAVEDOOR: ui=0 sp=1 inst=1 mod=0
N 0 0 100 0 {lab=BAR}
C {lab_pin.sym} 0 0 0 0 {name=l1 lab=BAR}
```

Blast radius of the *rejected* option, re-measured 2026-08-11 (0262's own figures were stale-low):

```
$ grep -rn 'xschem unselect_all' --include='*.tcl' --include='*.sh' --include='*.csv' . \
    | grep -v '^./doc/claude' | wc -l   ->  866
$ grep -n 'unselect_all(' src/*.c | grep -v 'void unselect_all' | wc -l   ->  82
```

## 2. AFTER — same fixture, post-fix

```
ARMED   ui=16424 sp=1 wlp=1 psel=1
xschem unselect_all
AFTER   ui=0 sp=0 wlp=0 psel=0 inst=1 mod=1
MSG     Pending placement abandoned by a deselect; object left in place   (hold=1)
```

and the canvas is provably alive again, end to end — the property the whole decision exists for:

```
arm -> bare verb -> REPAIRED sp=0 -> re-arm ui=16424 sp=1 psel=1
xschem add_wire_label -drop 50 0   ->  returns 1
END     ui=8 sp=0 inst=2
```

Before the fix that drop was refused **forever**. The knowingly kept residue is also visible above:
`inst=1` after the repair, and `xschem instance_net l1 p` is still `FOO`.

## 3. Decisions — every one with its ladder rung and its rejected alternative

| # | rung | decision | rejected alternative |
|---|---|---|---|
| **D1** | **R1**, corroborated by R2 | **Ratify option 2** — the repairing tripwire is the permanent class-wide answer; the bare verb stays ungated. R1: `unselect_all` **arms nothing**, so the ratified "whatever you just pressed is what you meant" rule (0240/0243 F2) has no subject. R2: 866 scripted / 82 C call sites, dominant idiom `xschem unselect_all ; xschem select <thing>` — a housekeeping PREFIX, not a gesture cancel. | **Option 1**, `leave_placement_for("Deselect")` at the verb. It closes exactly ONE of the three known doors and hands a `delete()` to all 866 sites, including `slickprop::restore_selection` (`src/property_form.tcl`), the Property-form **Cancel** path — which is this issue's own stated worst case. Issue **0123**'s objection, unchanged. |
| **D2** | R2 | **Option 3 (stay report-only) is rejected outright.** Its stated precondition — "genuinely unreachable while armed in practice" — was measured FALSE by issue **0397** on two routes, one of them a DEFAULT chord, and the resulting state is terminal with no in-session recovery but discarding the document. | Documenting the dead canvas as accepted behaviour, i.e. a shrug. |
| **D3** | R2 | **The repair is NON-DESTRUCTIVE.** It clears three fields and speaks once. The object the user never dropped **stays in the drawing and still renames its net**; `modified` is left exactly as the door left it. | The scout's third shape — running the full **stamped teardown** at repair time (technically available, since `preview_sel` survives the door). That is option 1's blast radius *deferred* and made *less* predictable: the `delete()` would land at a later, unrelated verb entry, would fire from the head of motion-event dispatch, and would cost a user OBJECT rather than a flag on any future false positive. |
| **D4** | **R3 — user-visible, no prior ratification** | XSCHEM now silently repairs a broken placement-preview state at the next command or event entry instead of leaving the canvas dead. **THE OPEN QUESTION FOR THE HUMAN:** *is "repair the flags, keep the object, say so once" the right user-facing answer — given that the kept object mutates the document while `modified` can still read 0 (issue **0398**) — or should the repair also delete the orphan, accepting a deferred `delete()` behind all 866 scripted `unselect_all` sites including the Property-form Cancel path?* | Deciding it silently. The item is status **E** on this alone. |
| **D5** | R2 | **The detection condition is UNCHANGED**: `sympin_preview && !(ui_state & START_SYMPIN)`. | Widening it to the `place_net_label()` class (`actions.c` sets `START_SYMPIN` with no `sympin_preview`) or to `PLACE_SYMBOL`/`PLACE_TEXT` mismatches. That surface has **never been measured for false positives**, whereas this condition produced exactly one true report and zero false positives across all 20 tiers — and a false positive now costs state rather than a log line. Recorded as doors-suite note **F17**. |
| **D6** | **R1** for bypass, R2 for readonly | Honours `xctx->gate_bypass` (issue **0247**'s ratified test-only construction seam, which every other gate honours and which the suite needs to BUILD this state) but **NOT** `xctx->readonly`. | Mirroring `leave_placement_for()`'s `if(xctx->readonly) return 1;`. That guard exists because *that* teardown IS a `delete()`; copying it here would leave read-only windows **terminally dead forever** — the strictly worse surprise. Verified post-fix: arm → `xschem set readonly 1` → bare verb → repaired, canvas alive. |
| **D7** | **R1** (issue 0241: a teardown must name what it is tearing down) | The repair speaks **once per episode on the status bar** — `statusmsg_hold(msg, 1)` so the coordinate readout cannot eat it (0248) — in addition to the `dbg(0)` stderr line, whose text is rewritten (it used to end "…are dead until the flag is cleared", now false). | stderr only. No GUI user reads stderr, and a repair the user cannot see is indistinguishable from the bug. |
| **D8** | R2 | **No `draw()` in the repair**: it repairs STATE, not PAINT. Any rubber ghost the dropped `STARTMOVE` left clears on the next full redraw, exactly as today. | A latched single `draw()` on the transition — it would run at the head of `callback()` entry, i.e. inside motion-event dispatch, which is the window-only-overlay erase hazard. |
| **D9** | R2 | **The ratified rule, in two parts, so the class does not stay half-open.** **A** — the TERMINAL half of class D is answered ONCE, at `repair_orphan_placement_preview()`; **no verb acquires a `delete()` for the sake of the flags alone**. **B** — a door that additionally **COMMITS or PERSISTS** the orphan still needs its own **VERB gate**, because a repair is retroactive and cannot un-write a file or un-emit a deck: `netlist` has that gate (**0263**), `save`/`saveas`/Ctrl+S does not (**0358**, still open, answer = the 0263 shape). | Folding a `save` gate into this item. 0263 decision **D9** already refused that paste for want of save-shaped tier evidence, and it is a different item. |
| **D10** | R2 | Keep the name `check_placement_preview_invariant()` and add a **named callee** `repair_orphan_placement_preview()`. | Renaming the tripwire to match its new job — two call sites plus six comment references churn for no behavioural gain, and a separate callee is what gives sabotage variants S1/S2/S3 a clean, scoped seam. |
| **D11** | R2 — **taken at implementation time, and load-bearing** | **The stamp clear is CONDITIONAL; the two flag clears are not.** Shipped: `if(!(xctx->ui_state & (PLACE_SYMBOL \| PLACE_TEXT \| STARTMERGE))) clear_placement_preview();` | The plan's unconditional `clear_placement_preview()`. `preview_sel` is **ONE slot shared** by the placement stamp and the merge stamp, and the co-armed order *placement then merge* (doors row **G9b**) **is this very desync** while `STARTMERGE` is live and the slot describes the PASTE. An unconditional clear would have destroyed the paste's identity, made its own cancel resolve 0 and delete nothing, and reddened the pre-existing green row "G9b after netlist: merge gone". This does **not** weaken row F4: in every door case `ui_state` is 0, so the stamp *is* cleared. Predicted as a hazard by the Red agent's note **F19** before implementation. |

### Why the two other clears are load-bearing, not hygiene

* **the stamp** — after the door, `preview_sel` names what is now an ordinary document object, so a
  later unrelated `place_text`/`place_symbol` abort would resolve it in
  `select_placement_preview()` and **delete the user's work**;
* **`wirelabel_preview`** — left stale, `end_place_move_copy_zoom()`'s `STARTMOVE` branch routes the
  **next** symbol drop into `wire_label_try_commit()`, which returns 0 while the branch still
  returns 1: the click is swallowed and the symbol can never be committed.

## 4. What shipped

* `src/callback.c` — new `int repair_orphan_placement_preview(void)` beside the tripwire; the
  tripwire's detection branch calls it **outside** the file-static `reported` latch (so a
  `gate_bypass`-suppressed episode is reported once and repaired on the first entry after the seam
  closes); the `dbg(0)` text rewritten; `leave_placement_for()`'s carve-out comment refreshed from
  "817 scripted call sites" to 866/82 and restated as the **ratified** rule D9 A+B rather than an
  open question.
* `src/xschem.h` — the `extern` beside the tripwire's.
* `src/scheduler.c` — the two existing tripwire sitings are **unchanged** (`callback()` entry;
  `xschem()` entry **before dispatch**, which is what makes the repair assertable headlessly: the
  very next verb after a door reports the repaired state). Two new **read-only** probes in the `get`
  chain, because two of the repair's three effects had no oracle: `xschem get preview_sel_n`
  (case `'p'`) and `xschem get wirelabel_preview` (case `'w'`; the following `wave_hilights` branch
  converted from `if` to `else if`).
* `tests/headless/test_placement_preview_doors.tcl` — section F rewritten from one `note:` line into
  **29 checks** (177 → **206**), F1–F16 plus notes F17/F18/F19.

## 5. Tests

Section F of `tests/headless/test_placement_preview_doors.tcl`:

| row | pins |
|---|---|
| **F1/F2** | after the bare verb the next verb reports `sp=0`, `START_SYMPIN` still 0, `desync=0` — repaired by clearing the FLAG, never by re-arming the bit |
| **F3/F7/F8** | the orphan (`orphans=1`), the modify flag and the renamed net (`FOO`) are **kept** — decision D3 written as a contract so nobody "improves" it into a deferred `delete()` |
| **F4/F5** | the stamp and the label flag are cleared (both need the new probes) |
| **F6** | the repair **names itself**, and the line is **held** |
| **F9/F10** | the two GUI routes of issue **0397** — `addpin::cycle_type` and the Compare-schematics `-command` body — are repaired |
| **F11/F12** | the `save` door (**0358**): canvas repaired (F11), object still **persisted into the .sch** (F12, asserted as a contract, not a wish) |
| **F13/F14** | the `gate_bypass` construction seam still opens the raw door, and the repair **resumes** when the seam closes |
| **F15/F16** | **no false positive** — six per-keystroke re-arms stay live and silent; the idle bare verb is a no-op and says nothing |
| **F17/F18/F19** | `note:` — the `place_net_label` class is *not* covered (D5); the `callback()` siting is *not* exercised headlessly; the G9b stamp hazard that produced D11 |

Tier table (baseline at `2f866dec` → after): shape_draw_gate 421→421, paste_modify_flag_0244
376→376, add_wire_label 182→182, placement_wire_gate 187→187, label_ride 157→157,
**placement_preview_doors 177→206**, label_strand_oracle 32→32, sch_add_pin 25→25, wire_split ok,
crossview_paste 28/0, instance_update 95→95, descend_inert_class 177→177, descend_symbol 38→38,
refusal_channel_0251 45→45, hi_descend 24→24, cadence_descend_newwin_ro 11→11, log_absorb 23→23,
wireedit ALL PASS, `headless/run.sh` 6 goldens PASS, `run_regression.tcl` exactly the 3
pre-existing `sg13g2_tests_ase` FAIL lines.

> **Note for future crews:** the "TIERS THAT MUST STAY GREEN (measured 2026-08-09 at `bc4ff4a2`)"
> table carried in this run's briefs is **stale** for four suites (add_wire_label 178 vs 182,
> placement_wire_gate 171 vs 187, placement_preview_doors 115 vs 177, sch_add_pin 21 vs 25) — they
> grew with the 0245 escape-terminal work. The `2f866dec` figures above are the correct ones.

## 6. Sabotage matrix — 7 variants, and the one prediction that did not appear

| variant | predicted red | observed |
|---|---|---|
| **S1** repair-off (`#define repair_orphan_placement_preview() 0` scoped around the tripwire) | 9 rows | **9 red** (14 check lines), doors 192/206 — exact match |
| **S2** stamp survives (`clear_placement_preview()` neutralised **inside the repair only**, the three other `callback.c` callers untouched) | F4 | **1 red**, doors 205/206 — surgically exact, no collateral |
| **S3** silent repair (`statusmsg_hold()` neutralised inside the repair only) | F6 | **1 red group / 2 check lines**, doors 204/206 — both halves of the 0241 rule independently pinned |
| **S4** label flag kept (delete the `xctx->wirelabel_preview = 0;` write) | F5 | **1 red**, doors 205/206 |
| **S5** scripted siting removed (the `xschem()`-entry call neutralised, `callback.c` siting live) | 9 rows | **9 red**, identical row set to S1 — the whole headless-assertable surface rides on the scheduler siting, as claimed |
| **S6** construction seam ignored (delete `if(xctx->gate_bypass) return 0;`) | F13 | **1 red**; F14 correctly stayed green, so F13/F14 genuinely separate *suppression* from *resumption* |
| **S7** detection widened **as written** (drop the `\|\| (ui_state & START_SYMPIN)` half of the guard *inside* the repair) | F15, A2, 0265 E2, 0265 E3, E5 | **0 red — doors 206/206 ALL PASS.** See below. |
| **S7b** the same intent at the **effective** site (the tripwire's own branch condition → `if(xctx->sympin_preview)`) | the same 5 | **5 red plus 63 more** — doors 138/206, paste_modify 363/376, placement_wire_gate 179/187 |

**The predicted red that did not appear, and why it is not a coverage hole.** S7 as written is
**semantically dead code**: the repair's internal guard re-tests exactly the predicate its only
caller, `check_placement_preview_invariant()`, has already tested, so mutating it cannot change
behaviour. Re-running the same intent at the load-bearing site (S7b) reddened all five predicted
rows and 63 more, across sections A/B/C/D/F/G and two other tier suites — the mechanism **is**
covered, heavily. **Consequence, recorded rather than fixed:** the
`|| (xctx->ui_state & START_SYMPIN)` half of the repair's own guard is defence in depth that no test
can ever turn red. It is kept (the function is `extern` and a future second caller would need it)
and is now commented as belt-and-braces, so a later reader does not mistake it for the load-bearing
guard — the load-bearing one is in the tripwire.

## 7. Adversary pass — what it could not break

A 22-verb door scan post-fix (bare verb, Compare-schematics body, `addpin::cycle_type`, `save`,
`saveas`, `undo`, `redo`, `select_all`, `descend`, `go_back`, `netlist`, `place_symbol`,
`place_text`, `merge`, `copy`, `paste`, `delete`, `hilight`, `edit_prop`, `zoom_full`, `search`,
readonly toggle): for each, arm → open the door → re-arm → `add_wire_label -drop`. **Every row
`desync=0` and ALIVE=1.** No door left terminal. Mid-arm false positives: **zero** tripwire lines
and zero repair messages across six healthy tier suites (the doors suite's six are all deliberate).
The shared-stamp conditional (D11) was attacked in both co-armed orders and held. `undo`/`redo` are
**not** doors — `pop_undo` and `mem_restore_slot` call `clear_drawing()` *before* `unselect_all(1)`,
and `clear_drawing()` already clears the flags. Read-only windows are repaired and stay alive
(D6). Neither forbidden shape is violated: no pure-commit coordinate form is gated, and the
`callback()` siting **refuses nothing and deletes nothing** — it fires only on an
already-violated invariant, so R1's "gates live at the verbs, never at the shared per-click
primitive" is not violated in substance.

## 8. Still open — nothing here is fixed

1. **THE RATIFICATION QUESTION (D4).** The item is status **E** on this alone.
2. **The modify flag can still lie about the kept orphan — issue 0398, filed.** On a *clean, saved*
   document the door leaves `inst=1` and a renamed net with `modified=0`; the buffer will close
   without a prompt. Doors row **F7** cannot see it, because the suite's `setup` guarantees
   `modified=1` from its own wire.
3. **The residue reaches the emitted deck.** Post door+repair the deck reads `R1 FOO GND 1k /
   R2 FOO GND 2k` on a buffer reporting `modified=0`, with 0263's netlist gate structurally blind
   (it keys on bits the door already dropped). Identical pre- and post-fix, so not a regression —
   but "orphan-only" understates what an orphan costs. Part of issue **0398**.
4. **The repair erases its own evidence, and mis-names its cause — issue 0399, filed.**
   `xschem get sympin_preview` can no longer report a desync (the getter's own entry repairs it
   first), so 0242's "how many doors are left is now an empirical question, permanently" holds only
   through `gate_bypass`. And the status line hardcodes *"by a deselect"*, which is wrong for the
   `save`/`saveas` route and for any future non-deselect door.
5. **One unreproduced anomaly — issue 0400, filed.** A single early run read
   `wirelabel_preview=1` after a repair that had demonstrably executed; 20 back-to-back repeats and
   every later run read 0, and it is not a stale-build artifact.
6. **`save`/`saveas`/Ctrl+S (issue 0358) keeps its own half.** The repair makes it non-terminal;
   it cannot un-write the file. Rule D9 B applies and the answer is the 0263 shape. **0358's scope
   must not be read as the complete list of COMMIT/PERSIST doors** — `save.c` alone has four
   `unselect_all` sites, and `descend_symbol`/autosave also reach `save_schematic()`.
7. **The repair is opt-out-able.** `xschem test_gate_bypass 1` from a user rc or a stray script
   disables it for the whole session, unguarded and unwarned. Acceptable for a test seam, stated
   here so it is not a surprise.
8. **The `callback()` siting is unverified at runtime** and cannot be isolated with the current
   oracles (the file-static `reported` latch removes the only stderr oracle, and every Tcl probe is
   itself a repair opportunity). If that one line is later broken, nothing in the tree turns red —
   S5 only reddens because it removes the *scheduler* siting. Doors note **F18** concedes this.
9. **D11's conditional is correct only because of an UNENFORCED invariant** — every arm stamps
   immediately before setting its bit (`paste.c`, `scheduler.c`, `actions.c`, `draw.c`; verified by
   inspection this run). Nothing checks it. A future arm that sets `PLACE_SYMBOL`/`PLACE_TEXT`/
   `STARTMERGE` without re-stamping would make the repair preserve a stale stamp naming a now-real
   object — exactly the deletion hazard the fix's own header calls load-bearing. Restated at the
   conditional in the code.
10. **Doors row F15's message half is near-vacuous** (`fmsg2` is captured after
    `xschem statusmsg "-"`, so a repair message posted *during* the six re-arms would be
    overwritten before the read). Its real strength is the `[sp] 1` / `[psel_set] 1` checks, and the
    zero-tripwire-lines measurement across six tier suites covers the rest.
