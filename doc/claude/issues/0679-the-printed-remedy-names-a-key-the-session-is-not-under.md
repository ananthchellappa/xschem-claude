# 0679 — the printed remedy names a key no session is under, and `save_all_apply` reports success anyway

Status: FIXED 2026-08-25; the D6/D7 ruling debt is SETTLED 2026-08-29 (ratified as shipped — see RULING at the foot; one wording fix owed as follow-up). STILL OPEN items 2-8 remain. **Reproduced by the user on their bench, then reproduced exactly by the
driver.** Filed 2026-08-24. Related: 0653 (R-0653-d requirement 3, which this
violates), 0648, 0652, 0664, 0677.

## The user's report, verbatim

> I did a run without "Save device OP parameters" checked, and, when I tried to
> display OP info with 6, I get the required message in the CIW. However, when I
> entered the suggested command into the CIW (and get a 1 as result), if I go into
> the Menu : ASE-L > Outputs > Save All, I don't see that box checked after doing
>
>     ase::ui::save_op_params_on sky130_tests_ase/tb_bandgap/schematic

The notice worked. The remedy did not. **This is the exact failure R-0653-d
requirement 3 was written to prevent** — "advice that half-works: the user follows
correct-looking instructions and still sees blanks".

## Measured by the driver, headless on `:99`

```
REGISTERED: sky130_tests_ase/tb_bandgap/ngspice_state1
REMEDYKEY : sky130_tests_ase/tb_bandgap/schematic
update_rc : 0        <- ase::session_update: "unknown key"
apply_rc  : 1        <- ase::ui::save_all_apply: "success"
gate_real : 0        <- the gate never moved
```

## TWO defects, and the second is the dangerous one

### (a) the key comes from the wrong namespace

A session is registered under `ase::session_key $lib $cell $view` where `$view` is
the **state view the user opened** — `ngspice_state1` (`src/ase.tcl:2773`, in
`open_state`).

The remedy key is built by `ase::op_cards_nudge_key` (`src/ase.tcl:608-616`), which
reads `state -> design -> {lib cell view}` — the **design the state points at**,
whose view is `schematic`. `src/ase.tcl:715-717` then prints that as the command.

So the notice confidently prints a key that no session is ever registered under. It
is not a typo or a stale string: the two keys are built from **different fields of
the same state**, and they will never agree for any ASE session, on any cell.

### (b) `save_all_apply` fabricates its own success

`src/ase_window.tcl:2915-2923`:

```tcl
proc ase::ui::save_all_apply {key allv alli opparams} {
  set st [ase::session_state $key]      ;# returns {} for an unknown key, no error
  dict set st save_all_v ...
  ase::session_update $key $st          ;# returns 0 for an unknown key -- DISCARDED
  ase::ui::populate $key                ;# no-op with no window
  return 1                              ;# <-- always
}
```

`ase::session_update` is **honest**: `src/ase.tcl:2644-2646` documents "Returns 1, or
0 for an unknown key" and does exactly that. `save_all_apply` throws that answer away
and returns a hardcoded `1`.

That `1` is what the user saw, and it is why they trusted the command had worked.
**This is issue 0652's defect class — a report that lies — in a third place**, after
0664 (a DEGRADED claim on a live channel) and 0677. A witness that cannot fail is not
a witness.

⚠ Fixing (a) alone would hide (b) rather than fix it: the key would match, the return
would be right by luck, and the fabricated `1` would sit there waiting for the next
caller to pass a bad key.

## Fix

1. **`save_all_apply` returns what `session_update` returned.** Every caller must be
   audited for what it does with a 0 — the dialog's OK path in particular must not
   silently swallow a failed apply.
2. **The remedy prints the key the session is actually under.** It has that key in
   hand: the notice is emitted from a path that already knows the session. Do not
   "fix" this by making `op_cards_nudge_key` return the state view — that proc is
   also the LATCH key (`op_cards_nudge_rearm`, `src/ase.tcl:622`), and changing it
   silently re-scopes the 0648 latch, which is the defect 0648 was filed for.
   **Two consumers, two meanings: give the remedy its own builder or pass the
   registered key down.**
3. A test that **executes the printed command and then asserts the gate is on by
   `ase::op_gate_on`** — R-0653-d requirement 1, which was specified for exactly this
   and evidently did not cover the key.

## Why the existing test passed

The 0658 crew's remedy test executed the command against a key **it had constructed
itself** rather than one taken from a live session, so both sides of the comparison
carried the same wrong view and the round trip closed. Record this as the coverage
hole: a remedy test must take its key from the SESSION REGISTRY, never build one.

---

# ✅ FIXED 2026-08-25 (status **E** — one unratified question, below)

Both halves fixed. Commit: see `git log --grep '(0679)'`. Pure Tcl, two product
files, **no rebuild** (`xschem` sources `.tcl` at startup; zero `.c/.h/.y/.l`
touched, `src/Makefile.in` untouched, so no `./configure` and no Makefile
receipt was owed).

## ⚠ EVERY LINE NUMBER IN THE TEXT ABOVE HAD DRIFTED

Corrected, and re-verified against the tree **after** the fix:

| the text above says | it is actually |
|---|---|
| `save_all_apply` at `ase_window.tcl:2915-2923` | **`:3200`** |
| `open_state`'s `session_key` at `ase.tcl:2773` | **`:2839`** (the `session_key` call inside it) |
| `session_update` docstring at `ase.tcl:2644-2646` | **`:2716`** |
| the remedy built at `ase.tcl:715-717` | **`:753-762`** (inside `op_cards_capture`, `:734`) |
| `ciw_exec`'s `uplevel #0` at `ciw.tcl:250` | **`:598`** (`:249` is a *comment* about it) |
| the label constants at `ase_window.tcl:2878-2880` | **`:3173-3175`** |

## BEFORE — the Measure agent's transcript, verbatim

Headless, no X, no ngspice, on the committed fixture
`sky130_tests/test_nfet_final` (the user's own cell `sky130_tests_ase/tb_bandgap`
was driven separately by the adversary pass, below):

```
[repro] open_state rc : 1
[repro] REGISTERED    : sky130_tests/test_nfet_final/ngspice_state1
[repro] REMEDY CMD    : ase::ui::save_op_params_on sky130_tests/test_nfet_final/schematic
[repro] KEY MATCH     : 0
[repro] ciw_exec code : 0
[repro] ciw_exec res  : 1      <-- what the user reads in the CIW
[repro] gate before   : 0
[repro] gate after    : 0   <-- 1 = the box the user opens is ticked
[repro] save_all_current opparams: 0
[repro] session_state(remedy key) : {}
[repro] session_update(remedy key): 0
[repro] save_all_apply(remedy key): 1
```

**A THIRD SYMPTOM NOBODY HAD RECORDED**, and it is the worst of the three:

```
[silence] run1 nudges : 1
[silence] exec result : 1
[silence] run2 nudges : 0   <-- 0 = the user is now told NOTHING
```

The 0648 re-arm lives **inside** `ase::session_update` (`ase.tcl:2716`), *below*
its `if {![dict exists $sessions $key]} { return 0 }`. So the broken key also ate
the re-arm: the user follows correct-looking advice, is told it worked, gets
nothing, and is then **never told again for that cellview in that session**.
It is not a third fix — it is a third acceptance row on the same one. Proof:
running the *shipped, unmodified* `save_op_params_on` against the **registered**
key already produced `gate after: 1`, `dlg opparams: 1`.

## AFTER

```
[repro] REGISTERED    : sky130_tests/test_nfet_final/ngspice_state1
[repro] REMEDY CMD    : ase::ui::save_op_params_on sky130_tests/test_nfet_final/ngspice_state1
[repro] KEY MATCH     : 1        (was 0)
[repro] ciw_exec res  : 1
[repro] gate after    : 1        (was 0)
[repro] save_all_current opparams: 1   (was 0)
[repro] save_all_apply(bogus key) : 0  (was a fabricated 1)
```

and **on the user's own cell**, driven end to end by the adversary pass through
`ciw_exec`'s own seam (`uplevel #0`), from the committed `.state` which has no
`save_op_params` key and an enabled `op` analysis — their exact configuration:

```
REGISTERED : sky130_tests_ase/tb_bandgap/ngspice_state1
PRINTED    : ase::ui::save_op_params_on sky130_tests_ase/tb_bandgap/ngspice_state1
key-in-registry : 1
ciw_exec res    : 1
gate after      : 1
save_all_current opparams : 1
```

That last value is the one `save_all_dialog` seeds the checkbutton from — i.e.
literally the box they opened and found unticked.

## What changed

**(a) the key** — `src/ase.tcl`. `ase::op_cards_nudge_key` is **byte-untouched**
(it is the 0648 latch key; retargeting it is what this issue's own fix item 2
forbids). Three new procs:

* `ase::sessions_for_design {lib cell view}` (`:2913`) — the loop lifted
  **verbatim** out of `session_for_design`, returning **every** match in registry
  order.
* `ase::session_for_design` (`:2955`) is now literally
  `lindex [ase::sessions_for_design ...] 0` — its first-match contract preserved
  by construction, not by a second loop (invariant **I1**).
* `ase::sessions_for_state {state}` (`:2938`) — every key whose live state
  serialises equal to `$state`, through the same canonical `ase::state_serialize`
  that `session_dirty` uses.
* `ase::op_cards_remedy_key {state}` (`:648`) — **a lookup, never a second
  construction**. Order: exactly-one exact-state match → else exactly-one session
  on the design cellview → else `{}`. Whole body caught; never raises.

`op_cards_capture` (`:753`) now calls it. The pre-existing `if {$opk ne {}}`
guard is unchanged, so an unresolvable session prints the **menu path and no CIW
command** rather than a key nobody is under.

**(b) the witness** — `src/ase_window.tcl`. New named seam
`ase::ui::save_all_commit {key st}` (`:3240`): `set rc [ase::session_update ...]`,
and on `!$rc` one **caught** `::ase::echo` of one `error`-tagged sentence naming
the key, then `return $rc`. `save_all_apply` (`:3200`) is now
`set rc [save_all_commit ...]; populate; return $rc` — the hardcoded `return 1`
is gone and the `{}`-never-`0` expr is preserved **verbatim** (the 104 committed
`.state` files). `save_op_params_on` (`:3252`) was **not edited**; it inherits the
honest value. **The caller audit this issue demanded**: `save_all_ok` (`:3305`)
now captures and returns the rc and its two early guards return a real `0`.

Rendered failure text, verified:

```
ase: no ASE-L session is open under 'foo/bar/baz'; the Save All settings were NOT applied.
```

## Decisions (ladder rung, and the rejected alternative)

| # | rung | decision | rejected |
|---|---|---|---|
| D1 | **L1 (I1)** | the remedy gets its **own** key source and it is a **registry lookup**; `op_cards_nudge_key` untouched | retargeting `op_cards_nudge_key` to the state view — it is the 0648 latch key (`:622` re-arm, `:654` take, pinned by F19f); re-scoping it is the defect 0648 was filed for |
| D2 | L2 | resolution order **exact-state → unique-design → `{}`** | (i) `session_for_design` first-match — can name a plausible **sibling** session and repeat this issue's own class, advice that half-works; (ii) exact-match-only — drops the in-flight-mutated-state case the suites' `dict set st rundir …; ase::netlist $st` idiom exercises today |
| D3 | L2 | when nothing resolves, print the **menu path and NO command** | printing a key nobody is under, i.e. HEAD. R-0653-d req 2's own sentence — *"a wrong direction printed with authority is worse than printing none"* — governs the command field at least as hard, because `ciw_exec` makes the command the **executable** one of the two |
| D4 | L2 | Option A, reverse lookup **at the notice site** | Option B, threading the registered key down `ase::netlist` → `ase::run` → `op_cards_capture` — three public signatures, and `test_ase_core:402` pins the command set while `:502/:558/:615/:643` call `op_cards_capture` with two args. Recorded so a later crew does not re-litigate it |
| D5 | L2 | the honest return goes through a **named seam** `save_all_commit` | an inline `return [ase::session_update …]` — offers no callee to stub short of `session_update` itself, which reddens the whole session model and discriminates nothing (SAB-B/-B2 exist because of this) |
| **D6** | **L3** | on rc==0 **echo one error line naming the key**, and the remedy still **returns 0 rather than raising** | (i) silence + a bare `0` in the CIW — honest but mute; (ii) **raising**, so `ciw_exec` red-tags it via `ciw_echo $res error` — it converts a value-returning proc into a throwing one, needs `catch` at every future caller including `save_all_ok`, 0666 already records raises leaking out of the echo family, and it lands in the same `#!` error-to-log path where `test_ciw` is **already 1-red at HEAD** |
| D7 | L2 | `save_all_ok` returns the rc but **still closes the dialog** on a failed apply | holding it open — the user cannot repair a vanished session from inside that dialog; the non-silence lives in the shared writer's echo, which both paths inherit *because* they share the writer |
| D8 | **L1 (I1)** | `session_for_design` re-expressed as `lindex [sessions_for_design …] 0` | a second private loop inside the resolver — the exact two-builders shape this whole issue is about |
| D9 | — | `do_load_state_from` / `do_save_state_as` **filed, not fixed** | fixing them here — out of this item's scope per the brief. Filed as **0691** |

**D6 and D7 are user-visible and unratified — this issue is status E.** A `rule`
debt is on the ledger (`owed.sh`, id `0679`). The question is in "Still open".

## Sabotage matrix — 7 variants, 5 exact, 2 supersets, **1 predicted red that did not appear + 1 that could not run**

| variant | predicted | observed |
|---|---|---|
| **A** `op_cards_remedy_key` → `{}` | 9 red | **superset**: all 9 + F19r. Must-stay-green all held (F19v F19w F19q W1w W1r/W1t/W1u) |
| **A2** the **shipped bug reintroduced verbatim** (`session_key {*}[op_cards_nudge_key $state]`) | 7 red | **superset**: all 7 + F19r F19s F19s2. **F19o SHAPE ROW stayed GREEN — that green IS the proof that shape-and-completeness-only coverage was the hole HEAD's 67/67 fell through.** The plan's "F19s2 must stay green" prediction was **wrong**: F19s2 also catches the shipped construction. Extra coverage, not a hole |
| **B** `save_all_commit` → writes then `return 1` | F19v F19w W1w | **exact**. Every (a)-half row held green → the two defects are covered **independently**, not by one lucky row |
| **B2** the return kept, the **report** dropped | F19w W1w | **exact**. F19v held green, proving the "not silent" row does not ride on the return value |
| **C** `save_all_apply` → `return 1` (the standing **SAB-N6** control) | 7 red | **superset**: 8. **BOTH** the remedy row (F19p) **and** the menu OK row (W1w) went red → R-0653-d req 3 is met, the two paths really are one proc. ⚠ **F19p2 predicted red, stayed GREEN** — see below |
| **D** `sessions_for_design` → `{}` | 6 red | 5 red + 1 **never ran** + 31 unlisted (`test_wave_sigbrowser_i12` BX41-BX56, which exploits first-match **by name**). F19t/F19p/W1v held green — the exact-state route is independent, which is simultaneously the **I1 proof** that Launch and the remedy share ONE lookup |
| **E** `sessions_for_state` → `{}` | F19y | **exact, and it is the sharpest discriminator in the set** — F19y is the *only* row in either suite that can see it, because a single-session registry is rescued by the design fallback |

⚠ **THE TWO MISSES, AND THEY MATTER MORE THAN THE FIVE HITS.**

* **F19p2 cannot detect an always-1 writer travelling a GOOD key.** Under SAB-C
  both its terms are legitimately 1 — `f19p_val=1` from the stub and
  `f19p2_honest=1` because `session_update` really does succeed on the registered
  key. Its own comment claims *"a value that cannot disagree with session_update
  is a value that cannot lie"*; that is **only true when the key is bad**. The
  mechanism **is** covered (F19v went red under SAB-C), so this is a **mis-stated
  row, not a blind spot** — but do not cite F19p2 as the fabricated-witness guard.
* **`test_ase_launch:214` (G2) is not an independent guard.** Under SAB-D the
  suite **aborts** at `UNEXPECTED ERROR: invalid command name ".body.ana.tv"`
  right after G1, so 8 checks including all four G2 rows never execute
  (23 passed + 7 FAILED vs 38 at baseline; `grep -c G2` = 0 under sabotage vs 4
  at baseline). The first-match contract *is* guarded — `:146` (L7) and `:186`
  (G1) both went red — but `:214` sits downstream of an aborting row.

⚠ **THE CREW'S OWN RESTORE ASSERTION CANNOT SEE THIS SABOTAGE.** The protocol
says *assert `grep -rn SABOTAGE src/` is empty* — but the technique (correctly)
renames the callee to `<proc>_sabreal` and appends a stub, leaving no such
comment. **`grep -rn SABOTAGE src/` was 0 the entire time the tree was
neutralized**, and one verify pass recorded 10 spurious failures from a tree
mutating under it. The assertion that actually discriminates is
**`grep -rn '_sabreal' src/`** plus a `git diff --numstat` fingerprint. Every
agent in this crew should use that instead.

## Tests

`tests/headless/test_ase_final.tcl` **67 → 76**, `test_ase_window.tcl`
**199 → 202** (GUI legs), `test_ase_core.tcl` 172 → 172 (C0 extended in place).

**The coverage hole this issue names is closed literally.** HEAD's F19o did
`set f19o_key [cx {ase::session_key {*}[ase::op_cards_nudge_key $stoff]}]` — it
registered a session under **the same wrong builder the product used**, so the
round trip closed and the suite was ALL PASS with the defect live. Every new row
takes its key from `dict keys $::ase::sessions`, never builds one.

New rows: **F19t** (the printed key is in the registry), **F19o1** (non-vacuity:
the two namespaces genuinely differ on this fixture), **F19p/F19p2** (execute,
then the gate is on), **F19u** (the third symptom: the re-arm landed), **F19v**
(0/0 for a bogus key and 1/1 for the live one *in the same tuple*, so a proc
hardwired either way fails), **F19w** (exactly one `error`-tagged echo naming the
key, zero on success), **F19s/F19s2** (the refusal to guess, both arms),
**F19y** (the disambiguator), **F19x** (I1 on the lookup), and on the GUI side
**W1v** (the user's gesture read off the **live checkbutton's own `-variable`**,
never from the return value), **W1v2**, **W1w** (the OK-path audit).

## ⚠ STILL OPEN

1. **D6/D7 ARE UNRATIFIED — the question for the user.** *When the pasted
   `ase::ui::save_op_params_on <key>` cannot find a session, should it (a) return
   `0` and echo one error line — as implemented — or (b) **raise**, so `ciw_exec`
   red-tags it through `ciw_echo $res error`?* Same row: `save_all_ok` returns the
   rc but **still closes the dialog** on a failed apply. On the `rule` ledger.
2. **A STALE OPEN `Save All` DIALOG SILENTLY REVERTS THE REMEDY — filed as
   0692.** Driven end to end: `seed=0 remedy_rc=1 gate_after_remedy=1
   box_still=0 ok_rc=1 gate_after_ok=0`. The fix is what makes that window
   meaningful, and OK's `1` is now *truthful* while the setting is lost.
3. **The ambiguity refusal is silent about itself.** With two sessions on one
   design and no exact-state match — or none registered — the notice keeps its
   3-segment menu path and simply carries no command, with no sentence saying one
   was withheld. That is D3 and it is the right call, but a reviewer must not read
   a missing command as a regression.
4. **The confident-wrong-match window.** If any future caller ever holds a session
   state **across an event-loop turn** before netlisting, and a sibling session's
   live state happens to serialise equal to that stale copy, the exact-state route
   returns exactly one hit and the remedy names the **sibling** with full
   authority. Unreachable today only because both GUI entry points
   (`ase_window.tcl:4188` Netlist, `:4358` Netlist-and-Run) read and use the state
   in one command with no turn in between.
5. **`save_all_apply` / `save_op_params_on` can still RAISE** on a *registered*
   key whose state is malformed (measured: `missing value to go with key`).
   Pre-existing — the `dict set st …` lines precede the update at HEAD too — but
   `save_all_ok` is a Tk `-command`, so from the menu that surfaces as a
   **bgerror**, not as the new one-sentence report.
6. **`ase::session_close` (`ase.tcl:2803`) returns `1` whether or not the key
   existed** — the same fabricated-witness shape, one file over. Inert today (its
   one production caller, `ase_window.tcl:310`, discards the value). Recorded in
   **0691**.
7. **ZERO `:0` coverage.** Everything here is `--nogui` or Xvfb `:99`; W1v/W1v2/W1w
   have never run on Xwayland `:0`, and the user's report is a real bench. A
   `look` debt is on the ledger; the pre-existing `suite test_ase_window` `:0`
   debt covers the suite half.
8. **Count drift that will look like a regression:** `test_ase_launch` reports
   **22** checks headless and **38** X-armed (GUI legs self-skip). Diff the
   verdict, not the count.

---

# RULED 2026-08-29 — D6 and D7 ratified as shipped, with one wording fix owed

Decided under the user's explicit instruction of 2026-08-29 ("decide the 23, leave
0861 and 0299 for me"). This closes item 1 of "STILL OPEN" above. Items 2-8 are
untouched and stay open.

## Verified in the tree before ruling (line numbers as of this date)

| what was checked | where | what it actually does |
|---|---|---|
| the honest return | `src/ase_window.tcl:3500` `save_all_commit` | `set rc [ase::session_update ...]`; on `!$rc` one **caught** `::ase::echo ... error`; `return $rc`. No raise. |
| the shared writer | `src/ase_window.tcl:3460` `save_all_apply` | returns `save_all_commit`'s rc; the hardcoded `return 1` is gone |
| the pasted remedy | `src/ase_window.tcl:3512` `save_op_params_on` | plain call through the shared writer; inherits the honest value |
| the menu OK path | `src/ase_window.tcl:3583` `save_all_ok` | captures the rc, runs `save_all_close` **unconditionally**, then `return $rc`; both early guards `return 0` |
| the honest callee | `src/ase.tcl:2796` `session_update` | `if {![dict exists $sessions $key]} { return 0 }` — docstring is true |
| where the command window puts the answer | `src/ciw.tcl:609` `ciw_exec` | `set code [catch {uplevel #0 $cmd} res]`; `$code` -> `ciw_echo $res error`, else a non-empty result -> `ciw_echo $res result` |
| where the error line lands | `src/ciw.tcl:256` `xschem::notify` SINK 1 | `::ciw_echo $line $tag` — so an `error`-tagged notice is **already** styled as an error in the command-window pane, with no raise |
| the test that pins it | `tests/headless/test_ase_final.tcl:866` F19w | asserts count==1, tag==`error`, key present. **Does not pin the sentence text**, so a rewording costs no golden churn |

The single fact that settles D6: the alternative's only claimed benefit — the line
being red-tagged in the command window — **is already delivered today**, by
`ase::echo`'s `error` tag travelling SINK 1. Raising would buy the same red line and
add a throw to a value-returning proc.

## D6 — RATIFIED AS SHIPPED

A pasted `ase::ui::save_op_params_on <key>` that finds no open session **returns 0
and echoes one error-tagged sentence naming the key. It does not raise.**

* **Cadence.** A SKILL command that cannot do its job prints to the CIW and returns
  a false value; it does not abort the session. Shipped behaviour is the
  Cadence-compatible one, so CADENCE-OR-NOTHING points at ratify, not at the raise.
* The raise buys **no visible difference** (see the SINK 1 finding above) and costs
  a `catch` at every present and future caller, including the Tk `-command`
  `save_all_ok`, where an uncaught throw surfaces as a bgerror instead of a
  sentence. Issue 0666 already records raises leaking out of the echo family.

## D7 — RATIFIED AS SHIPPED

`save_all_ok` returns the apply's rc and **still closes the Save All form** on a
failed apply.

* The only way the apply fails from that button is that the session the form
  belongs to is **gone from the registry**. The form cannot repair that from the
  inside, so holding it open strands the user on a form for a dead session.
* Cadence forms close on OK and report trouble in the CIW; that is exactly this
  shape. The non-silence lives in the shared writer's one error line, which the OK
  path inherits *because* it shares the writer (R-0653-d req 3).

## THE ONE THING THAT MUST CHANGE — the sentence, under PLAIN ENGLISH

The mechanism is ratified; **the wording is not**. Today it reads:

```
ase: no ASE-L session is open under 'foo/bar/baz'; the Save All settings were NOT applied.
```

That says what happened and **not what the user can do about it**, which is half of
the user's standing PLAIN ENGLISH ruling ("say what happened AND what the user can
do about it, 9th grade level"). Commit b5d5b24f applied that ruling across the
annotation surface and to five sentences in this same file; this one was missed.

**Instruction to the codebase:** in `ase::ui::save_all_commit`
(`src/ase_window.tcl:3500`), keep the return, the single echo and the `error` tag
exactly as they are, and reword the sentence to drop the `ase:` prefix and add the
remedy half — naming the menu path through the existing mint
`ase::ui::remedy_op_params_menu` (`src/ase_window.tcl:3437`) rather than retyping
it, per D5-4. Shape:

```
No ASE-L session is open for '<key>', so the Save All settings were not changed.
Open that cellview in ASE-L and set it from <Outputs > Save All... > Save device OP parameters (gm, gds, vth, ...)>.
```

F19w (`tests/headless/test_ase_final.tcl:866`) asserts count/tag/key-present only,
so it stays green across the rewording; that is the row to keep, not to relax.

**Not in scope of this ruling:** the raise, the form-close, and STILL OPEN items
2-8. Nothing else in `save_all_commit` / `save_all_apply` / `save_all_ok` moves.

---

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim, on 2026-08-29:

> **"decide the 23, leave 0861 and 0299 for me"**

A read-only audit of the 57-entry ruling queue classified 25 debts as questions whose
answer is cheap and obvious — things that should be **decided** rather than put to the
user. **This debt was one of the 23** the user then handed over. (0861 and 0299 stay
with the user and are not touched here.) This closes item **1** of "STILL OPEN" above.
Items **2-8 stay open and unchanged**.

⚠ **This section SUPERSEDES the wording instruction in the `# RULED 2026-08-29` block
immediately above it.** That block's D6 and D7 rulings stand exactly as written; its
proposed replacement sentence does **not** ship, for the three reasons in R3 below.
The earlier block is left byte-untouched on purpose — an append-only record — so read
the two together, with this one winning on wording.

### The ruling, as an instruction to the codebase

**R1 (D6) — ratified as shipped. Nothing moves.**
When the user pastes `ase::ui::save_op_params_on <key>` into the command window and no
ASE-L session is open under that name, the command keeps **printing one red line in the
command window and returning `0`**. It must **not** be changed to throw an error.

**R2 (D7) — ratified as shipped. Nothing moves.**
Pressing **OK** in the **Save All** form keeps **closing the form**, even when the
settings could not be saved because the session behind the form is gone. The report
lives in the one red line in the command window, which the OK path inherits because
both paths share one writer.

**R3 (the sentence) — one code change is owed, and it is NOT the sentence the block
above proposes.** The failure line must gain a remedy half under PLAIN ENGLISH, but the
remedy must talk about the **session**, never about a named checkbox, and **all three
sibling sentences must be reworded together from ONE mint**. Shape:

```
ASE-L is not open for 'lib/cell/view', so the Save All settings were not saved.
Open that cellview in ASE-L again, then set them there.

ASE-L is not open for 'lib/cell/view', so the state was not loaded.
Open that cellview in ASE-L again, then load the state there.

ASE-L is not open for 'lib/cell/view', so the state was not saved to lib/cell/view.
Open that cellview in ASE-L again, then save it there.
```

### Why

**R1.** The single fact that settles it, and the one the original proposal never
checked: **the only benefit the raise was supposed to buy is already delivered.**
`ase::echo "..." error` travels `xschem::notify` **SINK 1** (`src/ciw.tcl:297-301`),
which calls `::ciw_echo $line error` unconditionally and first — so the sentence is
**already styled red in the command-window pane, with no raise anywhere**. Raising buys
the user **no visible difference** and costs a `catch` at every present and future
caller, including the **OK** button's own handler, where an uncaught throw would
surface as a bare Tk error box instead of a sentence. Issue **0666** already records
raises leaking out of this echo family. **CADENCE OR NOTHING** points the same way: a
SKILL command that cannot do its job prints to the CIW and returns a false value; it
does not abort the session. Shipped behaviour is the Cadence-shaped one.

**R2.** **INTENT OVER MECHANISM.** The only way OK's save can fail is that the session
the form belongs to has left the registry, and a form for a dead session cannot repair
it from the inside — holding it open strands the user on a window that can never
succeed. Cadence forms close on OK and report trouble in the CIW. In production this is
**near-vacuous anyway**: closing an ASE-L window (`ase::ui::close`,
`src/ase_window.tcl:300-321`) drops the session, the window record and that window's
dialog records in one go, so a live **Save All** form sitting over a dead session is not
reachable by any normal gesture — the suite has to close the session by hand to build
one. Ratifying a near-vacuous behaviour costs nothing.

**R3.** Three reasons the block above's sentence must not ship, each checked in the tree:

1. **It puts a caller-specific checkbox in a shared writer.** `save_all_commit`
   (`:3500`) is reached from two places: the pasted remedy (`save_op_params_on`,
   `:3512`, which forces only the OP-parameters box on) and the **Save All** form's
   **OK** (`:3583`, which applies all three boxes). A remedy naming *"Save device OP
   parameters (gm, gds, vth, ...)"* points a user who ticked **Save all voltages** at a
   box they never touched. The file states this rule about its own twin at `:4139`:
   *"its own sentence and not save_all_commit's, whose wording is Save-All-specific and
   would be wrong for an import."*
2. **It would desynchronize three byte-parallel siblings.** `src/ase_window.tcl` carries
   the same template three times — `:3503`, `:4152`, `:4355` — and the comment at
   `:4131` says the twin exists so *"the two read alike"*. Rewriting one and leaving two
   cryptic manufactures a second **0661** (that file already carries a filed drift
   defect of exactly this shape: two spellings of the same menu path, `string match`
   against both returns 0). Fixing a PLAIN ENGLISH miss by minting a **D5-4** miss is
   the wrong trade.
3. **On the OK path that remedy is a loop.** R2 closes the form; the sentence would then
   tell the user to open **Outputs > Save All...** and tick a box — the gesture that just
   failed, on a form just closed under them, which fails identically because the session
   is gone. The true remedy for this failure is never a menu path inside ASE-L; it is
   *"that ASE-L session is closed — open the cellview again"*.

A fourth, mechanical reason: the remedy **cannot travel as structured fields on this
channel**. `proc xschem::notify_safe {msg {tag {}}}` (`src/xschem.tcl:15168`) takes a
message and a tag only and drops `-short`/`-menu`/`-command`, so an instruction to name
the menu path forces it into baked prose — the shape **R-0653-d** forbids
(`src/ciw.tcl:245`: *"`-menu` and `-command` are DISTINCT FIELDS, not prose baked into
the message"*), already filed as open class **0674**. A session-level remedy needs no
menu field at all, so that limitation stops mattering.

### What was verified in the tree (2026-08-29 — do not re-derive)

| what was checked | where | what it actually does |
|---|---|---|
| the honest return | `src/ase_window.tcl:3500` `save_all_commit` | `set rc [ase::session_update $key $st]`; on `!$rc` **one caught** `::ase::echo ... error`; `return $rc`. **No raise anywhere** — R1 ships as ratified |
| the shared writer | `src/ase_window.tcl:3460` `save_all_apply` | returns `save_all_commit`'s rc; the hardcoded `return 1` is gone; the `{}`-never-`0` expr preserved |
| the pasted remedy | `src/ase_window.tcl:3512` `save_op_params_on` | a plain call through the shared writer; inherits the honest value; forces **only** the OP-parameters box |
| the form's OK | `src/ase_window.tcl:3583` `save_all_ok` | captures the rc, runs `save_all_close` **unconditionally**, `return $rc`; both early guards `return 0` — R2 ships as ratified; applies **all three** boxes |
| the honest callee | `src/ase.tcl:2796` `session_update` | `if {![dict exists $sessions $key]} { return 0 }` — the docstring is true |
| **the deciding fact** | `src/ciw.tcl:297-301` `xschem::notify` SINK 1 | `::ciw_echo $line $tag`, unconditional and first — an `error`-tagged echo is **already red in the command-window pane without any raise** |
| where the command window puts the answer | `src/ciw.tcl:609` `ciw_exec` | `set code [catch {uplevel #0 $cmd} res]`; non-zero -> `ciw_echo $res error`, else a non-empty result -> `ciw_echo $res result`. So a bad key prints the red sentence, then a bare `0` |
| the three siblings | `src/ase_window.tcl:3503`, `:4152`, `:4355` | the identical `ase: no ASE-L session is open under '$key'; ...` template, three times; `:4131` says they must read alike |
| the label mint | `src/ase_window.tcl:3433-3442` | `lbl_outputs` / `lbl_save_all` / `lbl_save_op_params` and `remedy_op_params_menu` — the D5-4 mint the rejected sentence would have rendered through |
| the session teardown | `src/ase_window.tcl:300-321` `ase::ui::close` | drops the session, the `wins` entry and `dlg($key,*)` in one proc — a live Save All form over a dead session is unreachable by a normal gesture |
| the channel's field limit | `src/xschem.tcl:15168` `notify_safe` | `{msg {tag {}}}` only; `-menu`/`-command`/`-short` are dropped |
| the test that pins it | `tests/headless/test_ase_final.tcl:858-873` F19w | asserts `{1 error 1 0}` — count, tag, key-substring, zero-on-success. **The sentence text is NOT pinned**, so a rewording costs no golden churn and needs no test relaxed |
| the six rows that glob the old literal | `test_ase_window.tcl:977, :989, :1098`; `test_ase_dialogs.tcl:1066, :1076, :1117` | they match `*NOT applied*` on the **ESC/Cancel discard** sentence at `src/ase_window.tcl:3879`, which `save_all_commit` never emits — **unaffected** by the R3 rewording |

### Does anything move?

**R1 and R2 ratify shipped behaviour — nothing moves.** No code change, no test change.

**R3 implies a code change, and it is FOLLOW-UP WORK NOT YET DONE.** Exactly:

* Mint **one** helper in `src/ase_window.tcl` that takes the session key and the thing
  that did not happen, and renders `ASE-L is not open for '<key>', so <what> Open that
  cellview in ASE-L again, then <verb> there.`
* Route **all three** call sites through it — `:3503` (Save All settings were not
  saved), `:4152` (the state was not loaded), `:4355` (the state was not saved to
  `$l/$c/$v`) — so the three stay in sync instead of drifting.
* Everything else in `save_all_commit` / `save_all_apply` / `save_all_ok` stays byte-
  identical: the `set rc [ase::session_update ...]`, the single **caught** echo, the
  `error` tag, `return $rc`, and the unconditional close.
* **F19w stays green unmodified** (count/tag/key only), and the six `*NOT applied*`
  rows stay green because they read the ESC discard sentence, not this one.

**Acceptable alternative if a crew would rather batch wording work:** rule R1/R2 here
and carry R3 into the surface-wide plain-English pass where **0886** and **0888**
already sit. Commit `b5d5b24f`'s own message warns that *"a behaviour or wording change
smuggled into one is how defects ship"*. What is **not** acceptable either way is a
named checkbox in the shared writer's failure line.

**Adversary:** an adversary pass ran against this ruling. It could not shake D6 or D7 —
it re-measured SINK 1 and found the raise buys no visible difference, and found D7 more
settled than argued because `ase::ui::close` makes a dead-session form unreachable — but
it **overturned the proposed replacement sentence** on the three grounds recorded in R3,
and that overturn is what ships as R3 above.

**The user may reverse this at any time; it was decided to spare their attention, not to
bind them.**
