# 0679 — the printed remedy names a key no session is under, and `save_all_apply` reports success anyway

Status: OPEN. **Reproduced by the user on their bench, then reproduced exactly by the
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
