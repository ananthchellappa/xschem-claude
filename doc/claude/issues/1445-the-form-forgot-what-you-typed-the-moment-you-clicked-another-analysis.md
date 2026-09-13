# 1445 — The form forgot what you typed the moment you clicked another analysis

**Status:** FIXED. ⚖ **R5** of `doc/claude/ase_analyses_batch/DECISIONS.md`, answered by
the user on 2026-09-13. Files: `src/ase_window.tcl`,
`tests/headless/test_ase_dialogs.tcl` (section **GR5**, twelve rows, display arm).

## What the user experienced

`doc/claude/ase_l_ux_batch/FINDINGS.md` recorded it from their own seat, in their own
words:

> *"PROBE after ac->tran round trip, stop = '200u' — typing survived? 0 — I typed 500u,
> clicked the ac radio, clicked back, and 500u was gone."*

Clicking a cell in the Choose Analyses type grid ran `ase::ui::chana_show`, which does
`catch {destroy $w.form}` and rebuilds the form from the **stored** state row. Anything
typed and not yet committed died with the widgets. Issue **1411** had just turned that row
into a wrapping grid of **eleven** types, so clicking across the grid to see what each
analysis offers — the first thing a new user does — cost them whatever they had typed,
every time.

⚠ **AND THE TYPE GRID WAS NOT THE ONLY DOOR.** `ase::ui::chana_adv_toggle` rebuilds
through the same proc, so folding the `▸ Advanced` disclosure open or shut discarded the
form just as thoroughly. Nobody ever reported that one, because nobody thought to type and
*then* toggle. Row **GR5e** is it, and **GR5l** is the longer journey it hides: type into
`tmax` under Advanced, fold the section shut, and the value was gone before the user could
press OK.

## The decision that was reversed, and the one that was not

The discarding was **D4** of `doc/claude/ase_l_batch/prompts/item07_dialogs.md` —
*"in-form edits of the previous type are DISCARDED — deterministic, no hidden multi-type
writes"*. The user ruled:

> *"Make it remember — that's a more professional UI. We are trying to be better than
> Cadence"*

⚠ **THIS IS NOT `ase_analyses_batch/DECISIONS.md`'s OWN D4**, which is about the two
optional per-row keys `id` and `x`. Reversing *that* one would change the state schema.
Two files, two D4s, one number; the source comment and this issue both name the file.

⚠ **D4's REASON SURVIVED ITS OWN REVERSAL.** *"Deterministic, no hidden multi-type
writes"* defends the **commit**, and nothing is written until OK either way — the reason
never defended the discarding, it was merely attached to it. So the commit does **not**
change: `ase::ui::chana_ok` still writes the visible type and only it, and it never reads
the cache. Row **GR5g** is that sentence as a measurement.

## What shipped

Three procs in `src/ase_window.tcl` and four call sites.

| proc | what it does |
|---|---|
| `ase::ui::chana_cache_save` | before every rebuild, diff the live form against what this dialog put in it and store the **differences** under `dlg($key,anedit,<type>)`, merged over that type's earlier cache |
| `ase::ui::chana_cache_apply` | when repopulating, `dict merge` the type's cache **over** the stored row |
| `ase::ui::chana_cache_clear` | drop the whole cache: called from `choose_analyses` (every open) and `chana_cancel` (every close) |

* **The save goes in `chana_show`, not on the radiobutton's `-command`**, because that is
  the one door every rebuild comes through — which is how the `▸ Advanced` toggle got
  fixed for free.
* **It saves under `anshown`, not `antype`.** Tk sets a radiobutton's `-variable` *before*
  it runs `-command`, so by the time the save runs `antype` is already the type being
  switched **to**. `anshown` names the type whose widgets are actually standing.
* **No new state key, no schema change, nothing serialised.** One array slot per open
  dialog per type.

## ⚠ IT REMEMBERS WHAT WAS **TOUCHED**, AND THAT WAS MEASURED RATHER THAN PREFERRED

The first cut cached every live value of the outgoing form. It reddened an **existing**
row — `GN7b` in `tests/headless/test_ase_dialogs.tcl` — and the red was correct: a `step`
the user had never typed was cached as the empty string and the overlay then **deleted a
stored `step 1n`**. A cache that remembers what was on screen is a cache that overwrites
the file with the dialog's own defaults.

So a field is an edit only when its live value differs from `dlg($key,anbuilt)`, the
snapshot taken at the end of every build. That is also what makes the byte-identity
constraint hold: `ase::ui::form_is_absent` exists to stop a form writing a key no bench
carries (`uic 0`, `sweep dec`), and an untouched field never enters the cache in the first
place, so there is nothing for it to re-supply.

## ⚠ THE ADVANCED-FIELD TRAP, WHICH IS THE SHARPEST WAY TO GET THIS WRONG

`ase::ui::form_has` is **false for a widget that was never built**, so a field behind
`▸ Advanced` is absent from everything the form can report while the disclosure is closed.
Both halves of this feature therefore **merge and never replace**:

* **the apply** merges the cache over the stored row — replacing would delete every key the
  disclosure was hiding, *silently*, because the form would look exactly right (**GR5d**);
* **the save** merges into the type's earlier cache — replacing would throw away a value
  typed under Advanced at the moment the user folded the section shut (**GR5l**).

`ase::ui::chana_merged_row`'s own header comment already says the first half for the
precondition banner; this is the same sentence one proc further out.

## The residual case, measured and NOT fixed

With "commit only the visible type", this sequence still loses an edit: type into `tran`,
click `ac`, press OK. **Measured** (`GR5g`): the `ac` edit is written, the bench's `tran`
row is untouched, and the remembered `tran` edit is dropped when the dialog closes. The
user ruled on this exact shape today and the ruling did not ask for a multi-type write, so
the behaviour is recorded rather than changed.

**A second residual, found by measurement rather than named in the brief.** A value typed
under `▸ Advanced` and then hidden by folding the disclosure shut is remembered by the
cache and shown again when the disclosure reopens — but `chana_ok` reads only **live**
widgets, so pressing OK while it is hidden does not commit it. That is unchanged from
before this issue (where the value was destroyed outright at the toggle), and it is
strictly better than before; but "remembered and not committed" is a new *shape* of the old
problem and it is written down here rather than fixed, because widening what OK reads is a
change to the commit door and the commit door was explicitly out of scope.

## Test

`tests/headless/test_ase_dialogs.tcl` section **GR5**, twelve rows, **display arm only**
(`run_regression.tcl` runs this file on neither of its arms, so a T1 zero exercises none of
them). Floor **37 headless / 300 → 313 display**.

Sabotage matrix — nine mutations, each restored by `cp` with an md5 compare:

| sabotage | rows that reddened |
|---|---|
| **a** the cache never saves | GR5a GR5d GR5e GR5f GR5h GR5i GR5j GR5l |
| **b** the cache never restores | GR5a GR5d GR5e GR5j GR5l |
| **c** apply REPLACES the stored row | **GN7b** GR5c GR5d GR5k GR5l |
| **c2** save REPLACES the type's earlier cache | GR5e GR5l |
| **c3** one cache for the dialog, not one per type | GR5b GR5f GR5h GR5i GR5j |
| **d** OK commits the cached non-visible types | GR5g |
| **e** no clear when the dialog opens | GR5f GR5i |
| **e2** no clear on Cancel | GR5h |
| **f** the cache records every live value, not only what was touched | **GN7b** GR5f |

⚠ **`e` AND `e2` ARE COMPLEMENTARY AND THAT IS THE POINT.** Dropping the clear on *open*
reds **GR5i** and leaves GR5h green; dropping the clear on *Cancel* reds **GR5h** and
leaves GR5i green. Two clears, two rows, neither covering for the other — the window
manager's close button runs none of our close paths, so the open-time clear cannot be
removed on the grounds that Cancel already does it.

⚠ **TWO SABOTAGES REDDEN AN EXISTING ROW, `GN7b`**, which was written for issue 1435's
precondition banner and is the row that caught the first cut of this change. A feature
whose only witnesses are its own new rows is a feature nothing else in the tree is
watching.

**Byte identity.** The 104 committed `.state` files round-trip through
`ase::state_load` + `ase::state_save` with **0 of 104 differing**, and **GR5k** asks the
same question from the GUI side: open Choose Analyses, click all eleven cells, press OK,
and `ase::state_serialize` returns the same bytes as never opening the dialog. Zero tracked
`.state` files are modified by this change.

Receipt: `doc/claude/ase_analyses_batch/receipts/24-r5-remember-per-type-edits.md`.
