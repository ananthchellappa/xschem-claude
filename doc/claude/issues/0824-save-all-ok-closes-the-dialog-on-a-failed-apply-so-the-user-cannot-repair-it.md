# 0824 — `save_all_ok` closes the Save All dialog on a FAILED apply, so the user cannot repair the failure from inside it

Status: **OPEN — read from source 2026-08-25 by the lead, NOT run.** See §4 for
exactly what is measured and what is not.
FOUND IN: `src/ase_window.tcl:3352` (`ase::ui::save_all_ok`).
RELATED: **[0679](0679-the-printed-remedy-names-a-key-the-session-is-not-under.md)**
— this is that issue's **D7**, and the reason it is filed separately is in §1.
Family: 0691, 0692, 0695, 0696 (the Save All dialog's staleness work).

---

## 1. Why this is an issue and not a ruling

0679 carries D7 on the owed ledger as part of a **rule** debt — something for the
user to ratify. Reading it against the source, it does not belong there.

D7, verbatim from the ledger entry:

> Also D7: `save_all_ok` now returns the rc but STILL CLOSES the dialog on a
> failed apply (a user cannot repair a vanished session from inside it).

A dialog that closes on failure and discards the user's unapplied input is a
defect in any reading of any UI. There is no version of "ratify this" that makes
it the intended behaviour — the user would be ruling between *a bug* and *not a
bug*. **D6 in the same debt is a genuine ruling** (return `0` and echo one
error-tagged sentence, versus raise) and stays where it is; only D7 moves.

⚠ **The rule debt [0679] is NOT cleared and must not be** — D6 still needs the
user. This issue takes D7 out of the question so the ruling that remains is a real
one.

## 2. The defect, as source

`src/ase_window.tcl:3346-3353`, the whole tail of `ase::ui::save_all_ok`:

```tcl
  set vals [ase::ui::save_all_resolve $key]
  set rc [ase::ui::save_all_apply $key \
    [dict get $vals allv] [dict get $vals alli] [dict get $vals opparams]]
  ## 0648: the CLOSE half, never save_all_cancel. …
  ase::ui::save_all_close $key
  return $rc
```

`save_all_close` is **unconditional**. `$rc` is computed, never consulted, and
returned to a caller that the menu path discards. So the two outcomes are:

| apply | dialog | user's boxes | what the user sees |
|---|---|---|---|
| succeeds (`rc` 1) | closes | written | correct |
| **fails (`rc` 0)** | **closes anyway** | **discarded** | a dialog that vanished as if it had worked |

And the failure is reachable, not theoretical. `save_all_apply` (`:3200-3211`)
returns whatever `save_all_commit` returns, and 0679's own work exists **because**
that can be 0 — the session key is not registered. 0679 shipped the honest return
value and the error-tagged sentence naming the key; **it did not stop the dialog
from closing over it.**

## 3. Why the remedy 0679 shipped does not cover it

0679's remedy echoes one error-tagged sentence naming the session key, so the user
is told. Being told is not being able to act: the sentence lands in the CIW while
the dialog carrying the user's three checkbutton decisions has already been
destroyed. To retry, the user must reopen Save All and re-make every choice —
and the state that made the first attempt fail is unchanged, so the obvious retry
fails identically.

This is the same shape as the family it sits in. 0691/0692/0695/0696 were all
about the Save All dialog **telling the truth about its own state**; a dialog that
disappears on failure tells the user nothing at the one moment it matters most.

## 4. ⚠ What is measured and what is NOT

**Measured: nothing at runtime.** This issue is **read from source**, not run.
Specifically:

* `save_all_close` being unconditional is **certain** — it is one statement with
  no guard, quoted whole above.
* `save_all_apply` returning `save_all_commit`'s answer is **certain** (`:3208`).
* That `save_all_commit` returns 0 for an unregistered key is taken from **0679's
  own write-up**, not re-measured here.
* **The user-visible consequence is inferred, not observed.** Nobody has opened
  the dialog against a vanished session and watched it close.

**The measurement that would settle it**, and it is small: register a session,
open Save All, tick all three boxes, unregister the session behind the dialog
(the arrangement 0691/0692 already build fixtures for), press OK. Expect: dialog
gone, `rc` 0, an error-tagged CIW line naming the key, and the three ticks lost.

**Do not fix this on the strength of the reading alone.** Two defects have shipped
past twenty-eight passing checks on this branch, and one of this session's nine
fabricated-witness instances was exactly a plausible inference written up as an
observation.

## 5. The fix, when someone takes it

One line, and the shape is already decided by the comment sitting above it:

```tcl
  if {$rc} { ase::ui::save_all_close $key }
  return $rc
```

⚠ **The 0648 comment at `:3349-3351` is binding and must survive**: the OK path
closes with `save_all_close`, **never** `save_all_cancel`, so that OK can never
emit a discard notice by accident. Leaving the dialog open on failure does not
change that — it must still not emit a cancel/discard notice, because nothing was
discarded and nothing was cancelled.

**Open sub-question for whoever fixes it** (a small ruling, worth attaching to
0679's existing debt rather than minting a new one): on a failed apply, should the
dialog merely **stay open**, or stay open **and** carry the error sentence inside
itself rather than only in the CIW? Staying open is the minimum and is
unambiguous; an in-dialog message is better but adds a surface, and 0806 has just
ruled that the CIW is the place notices go.

## 6. Acceptance

1. A failed apply leaves the dialog **open** with the user's three checkbutton
   values **intact**.
2. A successful apply still closes it — via `save_all_close`, not
   `save_all_cancel` (0648).
3. A failed apply still emits 0679's error-tagged sentence naming the key, exactly
   once, and emits **no** discard/cancel notice.
4. `save_all_ok` still returns the real `rc` in both arms (0679's D6; it is honest
   today and must stay honest).
5. **The counterweight**: a row asserting the dialog is GONE after a successful
   apply must accompany any row asserting it SURVIVES a failed one — otherwise
   "never close it" passes acceptance 1 and breaks the shipped path. This is the
   0682 crew's anti-hollow pattern and it applies exactly here.
