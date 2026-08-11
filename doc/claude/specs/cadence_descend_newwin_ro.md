# Ctrl-Shift-X → descend into selected instance's schematic, new window, read-only

Status: SPEC. Related memory: [[cadence-bindkeys]], [[hi-descend]],
[[descend-newwin-return-chain]], [[descend-readonly]], [[cadence-note-nav]],
[[user-run-config]].

## 1. Goal

In the user's Cadence interaction mode (`src/cadence_style_rc`), add **Ctrl-Shift-X**:
descend into the **schematic view** of the **one selected instance**, opened in a
**new top-level window**, **read-only**. No-op unless *exactly one* instance is
selected.

This is the keyboard shortcut for the exact flow the user does today by hand:
select an instance → press **E** → tick the **New Window** destination radio →
press **OK** (Mode defaults to Read-only).

## 2. Why not the existing shortcuts

Two nearby Cadence binds look similar but are NOT this:

- **Ctrl-X** `cadence::descend_into_inst` — descends in the **current** window
  (`xschem descend`), read-only by the cadence default. Same window, not new.
- **Ctrl-Shift-N** `cadence::open_inst_sch_readonly` — opens the instance's schematic
  read-only in a new window via `xschem schematic_in_new_window force window`, which
  loads it as a **fresh top-level** (currsch 0, parent hierarchy path lost). It is an
  *open*, not a *descend*.

The requested feature is a real **descend** into a new window: the parent hierarchy
path is preserved (`copy_hierarchy`), the child is linked back to its parent window for
the Ctrl-E / Alt-E return chain (issue 0053), and highlights are copied — everything the
`E` dialog's "New Window" path already does.

## 3. Mechanism (no C, no new Tcl engine)

The `hi_descend` engine (`src/xschem.tcl`, [[hi-descend]]) already implements exactly this
path. The `E`-dialog OK button with New Window + Read-only calls:

```
hi_descend_do $inst $view {} new_window $iter readonly
```

so the scripted equivalent is simply:

```tcl
hi_descend target=new_window mode=readonly
```

- `target=new_window` → `hi_descend_newwin ... window`: opens a real OS window, descends
  keeping the hierarchy path, records the parent-window return link, copies highlights,
  defers the full-zoom repaint (WSLg race, issue 0035/0037).
- `mode=readonly` → after the descend, `xschem set readonly 1` + `xschem set_modify 0`
  (a fresh browse view carries no edits, shows no bogus `*`, never prompts on close).
- default view (no `view=`/`type=`) → the cell's `schematic` view (schematic type).

## 4. Exactly-one-instance gate

The user wants a strict "one instance selected, else does nothing" (silent no-op, like
Ctrl-X `descend_into_inst`). `cadence::one_instance_selected` already encodes this:
`lastsel == 1` AND `first_sel` type == 8 (ELEMENT/instance). A mixed rubber-band
(instance + wire, `lastsel == 2`) or an empty / text-only selection fails the gate.

Note this is stricter than bare `hi_descend`, which would descend into the *first*
selected instance of several and would emit a CIW error on an empty selection. The gate
makes the shortcut a clean silent no-op in every non-single-instance case.

### 4a. Amendment, 2026-08-10 (crew item D6, issue 0259)

**The memo read above was a bug and is gone.** `first_sel` is a *sticky memo*:
`set_first_sel()` (`src/select.c:1142`) stores only into an empty slot, and the slot is emptied
only by `unselect_all`/delete. Select a wire, then an instance, then deselect the wire, and the
selection really is exactly one instance — `lastsel 1`, `selected_set {x1}` — while `first_sel`
still names the WIRE, so the gate refused a selection `xschem descend` accepted. The gate now asks
the live selection:

```tcl
[xschem get lastsel] == 1 && [lindex [xschem selection] 0 0] eq {instance}
```

`xschem selection` (not `selected_set`, and *not* `xschem get selection`, which is an unknown key
that answers empty — issue 0392) carries type words and indices only, so a `name=` holding an
unbalanced brace cannot make the gate throw (issue 0388). The accept/reject set described above is
unchanged in every case this section enumerates; only the false refusal is gone. Pinned by
`GATE-none` / `GATE-multi` / `GATE-nonelem` / `GATE-stale*` / `GATE-brace*` in
`tests/headless/test_cadence_descend_newwin_ro.tcl`.

**The silence is re-affirmed, not reversed.** Issue 0259 part 2 argues that these three verbs
should `ciw_echo` on a genuine refusal, the way the other fourteen refusal sites in
`cadence_nav.tcl` do. D6 deliberately did **not** do that: the preference recorded in this section
is the *user's*, and an unattended crew does not overturn a recorded user preference. The question
is escalated instead — if Ctrl-X / Ctrl-Shift-X should speak when the gate genuinely refuses, this
section is the place to change first.

## 5. Implementation

New proc in `utils/cadence_nav.tcl`:

```tcl
# Ctrl-Shift-X: descend into the one selected instance's schematic view in a NEW
# top-level window, read-only -- the exact flow of E -> [x] New Window -> OK. No-op
# unless exactly one instance is selected. A real descend (parent hierarchy path
# preserved, return-chain linked), unlike Ctrl-Shift-N (open_inst_sch_readonly),
# which opens the child as a fresh top-level.
proc cadence::descend_into_inst_newwin_ro {} {
  if {![cadence::one_instance_selected]} { return }
  hi_descend target=new_window mode=readonly
}
```

New bind in `src/cadence_style_rc` (near the Ctrl-X / Ctrl-Shift-N binds):

```tcl
# Ctrl-Shift-X : descend into the selected instance's schematic in a NEW window,
# read-only (the E-dialog "New Window" path). No-op unless exactly one instance
# selected. GOTCHA (same as Ctrl-Shift-N above): with Shift held the "x" key emits
# the capital "X" keysym, so bind Key-X.
bind .drw <Control-Shift-Key-X> {cadence::descend_into_inst_newwin_ro; break}
```

The `break` stops the chord reaching the generic `<KeyPress>` → C dispatcher. Capital
`X` because Shift changes the produced keysym (same reason the file binds `Key-N`,
`Key-C` for the other Shift chords).

## 6. Test

`tests/headless/test_cadence_descend_newwin_ro.tcl`, true-headless
(`src/xschem --nogui --pipe -q --nolog --script ...`), reusing the `hi_descend`
fixture (`tests/headless/fixtures/hi_descend/hidlib`, top.sch with instance `x1`):

- **GATE-none**: nothing selected → no new window, currsch unchanged (stays 0).
- **GATE-multi**: instance `x1` + a wire selected → no new window, currsch 0 (the
  exactly-one gate rejects a 2-element selection).
- **DESCEND**: only `x1` selected → windows count +1, `currsch == 1`,
  `sch_path == .x1.`, schname contains `/schematic/leaf.sch`, `readonly == 1`.

The new-window path works under `--nogui` (the SELNW check in `test_hi_descend.tcl`
already exercises `hi_descend target=new_window` headless).
