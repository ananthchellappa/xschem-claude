# 0691 — `do_load_state_from` fabricates its witness the same way `save_all_apply` did

Status: **FIXED 2026-08-25** by the 0691+0692 crew (three arms + a sweep); see
§ "AFTER". Filed 2026-08-25 by the 0679 crew, from the
"ALSO CHECK, because the same shape is likely nearby" clause of 0679's brief.
Related: 0679 (the same defect, fixed), 0652 (a report that lies), 0664, 0677.

## The shape

`src/ase_window.tcl:3575-3587`, `ase::ui::do_load_state_from`
(⚠ the line numbers first filed here, ~:3526-3538, were pre-fix; re-verified
after the 0679 commit):

```tcl
  ...
  if {<the file will not load>} { return 0 }     ;# honest about the FILE
  ase::session_update $key $st                   ;# rc DISCARDED
  ...
  return 1                                       ;# <-- always
```

It returns 0 for an unloadable **file** and never for an unknown **key**, so
"Load State into a session that is gone" reports success and changes nothing.

## Measured (headless, no X, at HEAD 4d958cb3, before the 0679 fix)

```
session_update(bogus)      : 0    <- honest
do_load_state_from(bogus)  : 1    <- fabricated
save_all_apply(bogus)      : 1    <- the 0679 defect, now fixed
```

The 0679 fix repaired `save_all_apply` (through the new named writer
`ase::ui::save_all_commit`) and audited `save_all_ok`. It deliberately did not
touch this proc: out of that item's scope.

## The weaker second arm

`ase::ui::do_save_state_as` (`src/ase_window.tcl:3766-3815`) discards
`ase::session_adopt`'s rc at **:3804**, but only on the untitled arm and it has
real `return 0`s elsewhere. Same class, smaller blast radius.

## Cleared by measurement, do NOT re-file

All 13 procs in `src/ase_window.tcl` ending in a bare `return 1` were scored for
(i) any earlier `return 0` and (ii) a discarded `session_update`/`session_adopt`
rc. Only the two above qualify. In particular `viewer_snapshot` is
**honest**: its `if {$st eq {}} { return 0 }` fires first, so its
discarded rc can only ever be 1. `raise_window_entry` has an
unconditional `return 1` but performs no key lookup and no write — it is a
"done" signal, not a witness.

## A THIRD ARM, ADDED 2026-08-25 BY THE 0679 WRITE-UP PASS

`ase::session_close` (`src/ase.tcl:2803`) is the same shape one file over:

```tcl
proc ase::session_close {key} {
  variable sessions
  if {[dict exists $sessions $key]} { dict unset sessions $key }
  return 1                                   ;# <-- always
}
```

It reports success for a key it never held. **Inert today**: its one production
caller (`src/ase_window.tcl:310`) discards the value, and ~14 test call sites do
too. But it is a witness that cannot fail sitting in the session model itself, and
the next caller that reads it inherits the lie. Fix it in the same pass as the two
above — it is a three-line change (`return [dict exists ...]` before the unset).

## Related

**0692** — the stale open `Save All` dialog silently reverting the remedy. Same
family (a truthful `1` returned while the user's setting is lost), different
mechanism: a dialog record that is seeded once and never refreshed.

## Fix (when it is scheduled)

Route both through a named commit seam the way 0679 did, so the honesty is
independently neutralizable, and echo one `error`-tagged sentence naming the
key. Audit every caller for what it does with a 0.

## Acceptance

1. `ase::ui::do_load_state_from <unregistered-key> <loadable-file>` returns 0,
   and returns 1 for a registered key in the same tuple (non-vacuity).
1b. `ase::session_close <never-registered-key>` returns 0, and 1 for a live one
   in the same tuple.
2. Exactly one `ase::echo`, tagged `error`, naming the key.
3. The existing Load State rows stay green.


---

# AFTER — fixed 2026-08-25, three arms

## What shipped

Three procs stopped fabricating a witness, all pure Tcl (no build; `xschem`
sources `.tcl` at startup):

1. **`ase::ui::do_load_state_from`** (`src/ase_window.tcl:3697`) now early-returns
   0 through a new named seam **`ase::ui::load_state_commit`** (`:3745`), the
   exact twin of 0679's `save_all_commit`: `set rc [ase::session_update ...]`,
   one caught `error`-tagged echo naming the key on failure, `return $rc`.
   `populate`/`viewer_restore` are **skipped** on the failed arm — repopulating
   panes from a session that is gone would blank a live window as a side effect
   of a *refused* import.
2. **`ase::session_close`** (`src/ase.tcl:2822`) → `if {![dict exists $sessions
   $key]} { return 0 }` before the unset.
3. **`ase::ui::do_save_state_as`** (`:3931`) gained an **early registration
   guard** before any write, using a new **`ase::session_exists`**
   (`src/ase.tcl:2836`).

## The measured before → after

Acceptance rows 1, 1b and 2, from the Measure agent's transcript and re-run
after the fix:

```
BEFORE                                AFTER
  session_update(BOGUS)      = 0        = 0    (unchanged; it was always honest)
  do_load_state_from(BOGUS)  = 1        = 0    <- acceptance 1
  session_close(NEVER_HELD)  = 1        = 0    <- acceptance 1b
  session_close(registered)  = 1        = 1    (non-vacuity: still 1 for a live key)
  session_close(same key,2x) = 1        = 0
  session_exists(NEVER_HELD)  n/a       = 0    (the new accessor)
```

Acceptance 2 (exactly one `error`-tagged sentence naming the key) is satisfied
**structurally**, not by luck: the file arm and the key arm both return early, so
they are mutually exclusive by construction. Row H4d exists to keep it that way.
Acceptance 3 (existing Load State rows green): `test_ase_dialogs` 166 → 172 ALL
PASS, `test_ase_final` 76 → 78, `test_ase_window` 202 → 208.

## Why `do_save_state_as` got a GUARD and not a measured adopt

L2. Measured reachability: for an unknown key `ase::session_path` returns `{}` —
**the same value that marks a registered-but-UNTITLED session** (issue 0141) — so
at HEAD control reached the `own eq {}` adopt arm, **created a view, wrote a
defaults-state file to disk**, discarded `session_adopt`'s 0 and returned 1. The
guard removes the lie *and* the litter, and cannot touch a registered key
(`test_ase_savestate_adopt` 26/26 green, untitled arm included).
REJECTED: measuring the adopt after the fact — the file is already on disk by
then, and it forces a fresh decision about whether the Save-As dialog stays up on
a partial success, which 0679's precedent does not obviously settle.

## Why `session_close` was fixed although every caller discards it

L2. Third instance of the 0652 class in three days; three lines; provably inert
today (one production caller at `ase_window.tcl:310`, after its own
`dict exists $wins` guard; no test asserted the return). REJECTED leaving it as
"harmless" — the next caller to read it inherits the lie.
⚠ `ase::ui::close` now has **two guards in a row** (its own `wins` check, then
this answer). They are NOT the same predicate — a window can be gone while the
session is live — so do not wire them together.

## THE SWEEP — full disposition, nothing passed over

29 procs across `src/ase_window.tcl` + `src/ase.tcl` end in an unconditional
`return 0`/`return 1`.

* **FIXED (3)**: `do_load_state_from`, `ase::session_close`, `do_save_state_as`.
* **FILED (2 issues, 3 procs)**: **0693** — `ase::ui::design_window` plus its
  engine `ase::ui::raise_window_entry`, one issue because fixing either alone
  proves nothing. **0694** — `ase::ui::toggle_flag` (widened after the fact: the
  discarded-`session_update` class has **thirteen** call sites, not one).
* **MEASURED HONEST, no action (6)**: `session_update`, `session_setattr`,
  `session_save`, `save_all_apply`, `save_all_commit` (0679's repair holding),
  `viewer_snapshot`, and `design_window` on an unresolvable key.
* **NOT INDIVIDUALLY DRIVEN, and saying so (~20)**: each carries an earlier
  `return 0` guard, so its trailing `return 1` legitimately means "no guard
  fired". Recorded as unexercised, **not** implied clean.

Post-fix receipt: `sweep2.tcl … | grep other_returns=0` returns **one** line
(`ase::ui::raise_window_entry`, filed as 0693); before the fix it returned two.

## ⚠ THIS ISSUE CONTAINS A SENTENCE THAT IS NOW REFUTED

§ "Cleared by measurement, do NOT re-file" says of `raise_window_entry`: *"it
performs no key lookup and no write — it is a 'done' signal, not a witness."*
**Right about the key lookup, wrong about the mechanism.** Measured: against a
bogus entry `{99999 .nosuchtoplevel}` the bare `xschem new_schematic switch` does
not throw, nothing is raised, and the proc reports `1` (`catch=0 rc=1`). It is
the engine behind `ase::ui::design_window`'s unverified claim. Filed as **0693**.

## Sabotage matrix

| variant | predicted red | observed |
|---|---|---|
| SAB-0691-A — `load_state_commit` returns a manufactured 1 (write + echo kept) | H4b | H4b only ✔ |
| SAB-0691-A2 — measured but silent | H4c | H4c only ✔ |
| SAB-0691-B — `session_close` still unsets but always returns 1 | F20a | F20a ✔ (F20b correctly stayed green) |
| SAB-0691-C — `session_exists` blinded to always 1 | H3b | H3b, all four terms ✔ |

No predicted red failed to appear. A/A2 pairing confirms no single row covers
both the witness and the sentence.

## Still open

* **0693** and **0694** (above), both filed, neither fixed.
* Rule debt **[0679]** — return 0 + echo vs RAISE on a missing session, and
  whether OK should still close the dialog on a failed apply — is **restated,
  not answered**. `load_state_commit` follows 0679's precedent (return 0 + one
  echo) provisionally.
* The two production callers of `do_load_state_from` (`:3564` as
  `ase::ui::confirm`'s detached `oncmd`, and `:3566`) still **discard** the rc.
  The non-silence reaches the user through the seam's one echo. Making `confirm`
  rc-carrying is a contract change to every confirm caller — out of scope, and
  the reason acceptance 2 is about the echo and not the return.
