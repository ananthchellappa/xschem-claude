# 0694 — `toggle_flag` discards the write's answer and returns nothing at all

Status: OPEN, FILED NOT FIXED. Filed 2026-08-25 by the 0691+0692 crew's sweep.
Related: 0691, 0679, 0652 (a report that lies), 0693.

⚠ **TITLE IS NARROWER THAN THE DEFECT. WIDENED 2026-08-25** by the same crew's
write-up pass, after the adversary showed the original filing named one call
site for a class with thirteen. See § "The class, enumerated" — `toggle_flag` is
the example, not the extent.

## The shape

`src/ase_window.tcl:794-807` (unmoved by the 0691+0692 edit) — `ase::ui::toggle_flag` discards
`ase::session_update`'s rc at `:805` and returns **nothing**. It is not a
fabricated witness (there is no witness to fabricate), which is why the sweep's
mechanical "last statement is an unconditional `return N`" enumeration does not
list it — recorded here so the filing is not narrower than the defect class.

Same family: a write that can fail, whose failure nobody can see. Every pane
toggle in the ASE-L window goes through it.

## The class, enumerated — thirteen sites, not one

`ase::session_update` is honest (it returns 0 for an unknown key). Every caller
below **discards that answer**, so a write that did not happen is invisible at
each one. Enumerated in `src/ase_window.tcl` after the 0691+0692 edit; the two
seams that DO measure it (`save_all_commit` :3241, `load_state_commit` :3746) are
excluded, being 0679's and 0691's repairs:

| line | proc | what the user did |
|---|---|---|
| :805 | `ase::ui::toggle_flag` | toggled a pane flag |
| :864 | `ase::ui::delete_selection` | deleted a row |
| :1362 | `ase::ui::temp_commit` | edited the temperature |
| :1457 | `ase::ui::add_variable_ok` | **OK** on Add Variable |
| :1507 | `ase::ui::variable_editor_ok` | **OK** on the variable editor |
| :1595 | `ase::ui::output_editor_ok` | **OK** on the output editor |
| :2065 | `ase::ui::sod_queue` | queued a stop-on-device |
| :2678 | `ase::ui::chana_ok` | **OK** on Choose Analysis |
| :2824 | `ase::ui::chana_x_ok` | **OK** on the analysis X dialog |
| :2932 | `ase::ui::design_ok` | **OK** on Design |
| :3098 | `ase::ui::listdlg_ok` | **OK** on a list dialog |
| :3133 | `ase::ui::listdlg_delete` | deleted from a list dialog |
| :3865 | `ase::ui::viewer_snapshot` | (⚠ cleared by 0691 — its `$st eq {}` guard fires first, so its discarded rc can only ever be 1) |

That is the **OK handler of nearly every ASE-L editor dialog**. The user's
2026-08-22 eyes-on session reported exactly this shape twice at the Save All
dialog (0679, 0692); nothing measured says the other eleven behave differently,
and nothing has driven them against a dead session.

⚠ The BRIEF's literal sweep — "every proc whose last statement is an
unconditional `return 1/0`" — **is** complete and was completed: 29 procs across
`src/ase_window.tcl` + `src/ase.tcl`, one survivor after the fix
(`ase::ui::raise_window_entry`, filed as 0693). This issue records that the
*defect class* the sweep was aimed at is wider than the syntactic pattern used
to find it. A future sweep should grep the discarded WRITE, not the trailing
`return`.

## Why it was NOT fixed in the 0691 pass

Giving it a witness changes its caller's contract. `ase::ui::pane_click`
(`:772-790`) ends in `return 1` at `:789`, and that return is **honest** — it
means "I handled the click" and is consumed by the `break` binding at `:715`.
Threading a write's answer up through it would change what that `1` means and
what the binding does with it. L2: out of 0691's blast radius, filed rather than
taken.

## Acceptance (when scheduled)

1. `toggle_flag` returns `ase::session_update`'s measured answer.
2. A failed toggle says so exactly once, tagged `error`, naming the key
   (issue 0635's rule; the `ase::ui::save_all_commit` / `load_state_commit`
   wording is the precedent).
3. `pane_click`'s "I handled the click" `1` and the `break` binding at `:715`
   are provably unchanged — a row that drives a real pane click.
4. The other twelve sites in the table are each driven against a session that is
   gone, and each either reports or is recorded as deliberately silent. A fix
   that repairs `toggle_flag` alone closes 1/13 of this and must not close the
   issue.
