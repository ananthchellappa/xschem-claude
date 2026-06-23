# Issue 0019 — "Descend schematic (edit)" reuses widget name `.ctxmenu.b22`, breaking the right-click menu in cadence mode

**Opened:** 2026-06-22
**Status:** ✅ RESOLVED 2026-06-22 (branch `fluid-editing`). The new "Descend schematic
(edit)" button was renamed `.ctxmenu.b22` → `.ctxmenu.b26` (the guarded pack updated to
match); its `retval 22` command is unchanged, so callback.c is untouched. Regression test
`tests/headless/test_context_menu_descend_edit.tcl` (RED→GREEN): under `descend_readonly=1`
+ a selection, `context_menu` builds without error and the edit-descend and rotate items
exist as distinct widgets.
**Affects:** the canvas right-click context menu (`context_menu`, `src/xschem.tcl`) whenever
`descend_readonly` is set AND an object is selected. `descend_readonly=1` is the
**`src/cadence_style_rc` default**, so this is the user's normal run mode.
**Severity:** high — every right-click with a selection throws a Tcl error and the context
menu fails to build (no menu appears).
**Branch:** `fluid-editing`. See [[descend-readonly]].

---

## 1. Symptom

Running under `cadence_style_rc` (where `set descend_readonly 1`), select any object and
right-click on the canvas: the context menu does not appear. Tk raises
`window name "b22" already exists in parent` from inside `context_menu`.

## 2. Root cause

`context_menu` (`src/xschem.tcl`) builds the menu buttons fresh on each invocation. The new
"Descend schematic (edit)" item was added with the widget name `.ctxmenu.b22`:

```tcl
# src/xschem.tcl:9539
if {[info exists ::descend_readonly] && $::descend_readonly} {
  button .ctxmenu.b22 -text {Descend schematic (edit)} ... \
    -command {set tctx::retval 22; destroy .ctxmenu}
}
```

but `.ctxmenu.b22` is **already used**, unconditionally, by the pre-existing "Rotate
selection" button further down the same `if {$selection}` block:

```tcl
# src/xschem.tcl:9562
button .ctxmenu.b22 -text {Rotate selection} ... \
  -command {xschem rotate; destroy .ctxmenu}
```

When `descend_readonly` is on and there is a selection, both `button .ctxmenu.b22 ...`
calls run in the same pass. The second one errors because the widget already exists,
aborting `context_menu` — so no menu is shown.

The packing is also doubled: the new guard packs b22 once, then the original line packs it
again:

```tcl
# src/xschem.tcl:9618
if {[winfo exists .ctxmenu.b22]} { pack .ctxmenu.b22 -fill x -expand true }
# src/xschem.tcl:9620
pack .ctxmenu.b22 .ctxmenu.b23 -fill x -expand true
```

Even if the create error were swallowed, the intended "Descend (edit)" entry would be lost
(b22 ends up being the Rotate button) and Rotate would be packed twice.

## 3. Fix

Give the new "Descend schematic (edit)" button a **fresh, unused widget name** (e.g.
`.ctxmenu.b26` — verify it is not used elsewhere in `context_menu`), keep its
`set tctx::retval 22` command (callback.c case 22 is correct and unaffected), and pack that
new name in the `if {[winfo exists ...]}` guard. Remove the now-stale assumption that the
guarded pack and the unconditional `pack .ctxmenu.b22 .ctxmenu.b23` refer to different
widgets. The C side (`callback.c` case 22 → descend then force editable) needs no change.

## 4. Tests

No existing headless test exercises `context_menu` button construction under
`descend_readonly=1`. Add a GUI-headless check that, with `descend_readonly` set and a
selection, calling `context_menu` builds without error and both a "Descend schematic
(edit)" entry and a "Rotate selection" entry exist as distinct widgets. Sabotage-verify by
reintroducing the duplicate name and confirming the test reddens.
