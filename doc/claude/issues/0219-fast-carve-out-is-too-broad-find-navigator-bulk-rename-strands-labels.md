# 0219 — the `-fast` carve-out is too broad: Find Navigator bulk port rename strands the net labels

Status: **OPEN**
Severity: medium (silent disconnect — the exact failure the feature exists to prevent)
Introduced by: `74ef1aed`, arrived on `fluid-editing` via merge 3 (`958ada03`).
Found by: the merge-3 interaction audit — **two independent lenses** filed this separately.

## Symptom

`Ctrl+Shift+G` opens the Find Navigator with Object type **`port`** preselected
(`utils/find_helper.tcl:53`, combobox at `:558-559`). Fill the *"Rename (regsub on Name)"*
panel (`:598`) with From `IN` / To `IN_N` and press **Run** (`:619`).

Every matched `ipin`/`opin`/`iopin` `lab` is rewritten; every `lab_pin`/`lab_wire` that
carried the old name keeps it. Meanwhile *Symbol > "Renaming a pin renames its net labels"*
is checked **ON**, and renaming any one of those same pins through the `q` Edit Pin form
**does** propagate. The two routes now disagree, and neither warns at rename time.

The orphaned labels do remain visible to `sym_vs_sch_pins`, so this is not evidence-free the
way a *partial* propagation would be — but it is the pre-feature silent-disconnect behaviour
on the branch's default bulk-rename gesture.

## Mechanism

`find_helper::do_rename` issues

```tcl
xschem setprop -fast instance $i $tok $new     ;# utils/find_helper.tcl:335
```

inside its own `push_undo`/`no_undo` transaction (`:326-345`). `find_helper::name_token`
(`:90-93`) returns `lab` for every object type except `instance`, and the default type is
`port` — so the Find Navigator's default Rename target **is** a pin's `lab`.

The scheduler gate is `if(fast != 1) propagate_pin_rename(inst, old_lab);`
(`src/scheduler.c:11536`), so `fast == 1` skips propagation entirely.

## Why the exemption's own rationale does not cover this

The commit justifies the `-fast` exemption solely with `utils/bus_resize.tcl` — *"issues one
`-fast` setprop per selected pin AND label under a single outer undo"*. That is verified true
for `utils/bus_resize.tcl:156-169` / `:201-211`, where propagating would double-edit objects
the loop is about to edit itself.

It is provably inapplicable to `find_helper`: `find_helper::type_ok` (`:96-103`) makes `port`
and `netlabel` **mutually exclusive**, so the sweep renames only ports and never touches a
label; and `do_rename` supplies its own `push_undo`/`no_undo`/`set_modify`/`redraw`, so the
"no undo, no draw" half of the rationale does not hold either.

`-fast` is being used as a proxy for "the caller also edits the labels", and that proxy is
wrong for at least one caller.

## Suggested fix

Make the carve-out explicit rather than piggy-backed on `-fast`: either a distinct
`-nopropagate` flag for the `bus_resize` loop, or have `find_helper::do_rename` drop `-fast`
for the `port` type (it already owns undo/redraw). Whichever way, the two rename routes must
agree.

## Related

`utils/bus_resize.tcl:165` (bus transpose, ALT+Shift+wheel) is the *correct* `-fast` caller —
leave it exempt. See also [0220](0220-change-index-plus-minus-can-cascade-across-a-selection.md).
