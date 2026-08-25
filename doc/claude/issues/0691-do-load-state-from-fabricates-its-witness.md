# 0691 — `do_load_state_from` fabricates its witness the same way `save_all_apply` did

Status: OPEN, FILED NOT FIXED. Filed 2026-08-25 by the 0679 crew, from the
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
