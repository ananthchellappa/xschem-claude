# 0239 — `select_dangling_nets()` doc says pins are excluded (they are not), ignores connect-by-name, and its second pass skips `skip_instance()`

Status: **OPEN** — mostly a documentation-truthfulness fix; one small real inconsistency. **The label exclusion itself is deliberate and must not be "fixed".**
Area: `src/select.c` `select_dangling_nets()` (`:323-476`); the doc comments at `src/select.c:342`, `src/scheduler.c:10669`, `doc/xschem_man/developer_info.html:1489, 2419-2422`
Tests: none — this is a doc/comment change plus one guard
Found: 2026-08-05, while grounding `doc/claude/code_analysis/net_label_model_instance_vs_wire_attached.md`
Related: none. `select_dangling_nets` has **zero** hits anywhere under `doc/claude/`; the many issues using the word "dangling" (0040, 0092, 0103, 0109, 0132) are all about wire ends left by fluid drag/rotate, not this function.

> **Noted 2026-08-06, still unaffected.** `wire_label_ride.md` S3 (RIDE) landed: a net label now
> follows the copper it names when that copper moves, rotates or flips. Nothing here changes —
> S3 is per-gesture and move-scoped, it adds no propagation rule, and it never creates or destroys
> a label. This issue's *deliberate* label exclusion stays consistent with that design. The stage
> that will actually touch this function is **S6** (R8, delete/copy propagation, `wire_label_ride.md`
> §5.7): "delete a wire deletes its labels" has to reconcile with `select_dangling_nets()`
> semantics, and open question 4 flags `select.c:780` as the site. Not scheduled.

## First, what is *not* a defect

The initial suspicion was that excluding `type=="label"` from the connectivity pass is an
oversight producing false positives. **It is not.** The exclusion is the command's
specification:

```
Changelog:297-298
Add command "xschem select_dangling_nets" that selects all labels/wires that are not connected
  to any non-label/non-probe components
```

(commit `75e5d3d5`, 2023-09-14). Making labels count as terminators would gut the command
— nearly every net in a real schematic carries a `lab_pin`, so it would stop reporting the
leftover stubs it exists to find, and would silently change any user script built on the
2023 semantics (the command returns `xctx->lastsel`, so callers branch on the count). It
would also make the second pass (`select.c:407-429`) unreachable in practice.

The second suspicion — that a label which *missed* the wire is reported by nothing — is
also **wrong**. A third pass exists and works:

```c
src/select.c:431-445
  /* select dangling labels/probes (not connected to anything) */
  for(i = 0; i < xctx->instances; i++) {
    int dangling = 1;
    …
    if( type && (!strcmp(type, "label") || !strcmp(type, "probe")) ) {
      get_inst_pin_coord(i, 0, &x0, &y0);
      get_square(x0, y0, &sqx, &sqy);
      for(wireptr = xctx->wire_spatial_table[sqx][sqy]; wireptr; wireptr = wireptr->next) {
        int n = wireptr->n;
        if (touch(xctx->wire[n].x1, …, x0, y0)) {
          dangling = 0; /* inst[i] connected to a wire */
```

Measured: a stray `lab_pin` at (400,400) touching nothing **was** selected.

## The actual defects

### A — the doc contradicts the code about pins

```c
src/select.c:342
      /* Mark nets connected to non pin/label/probe components as NOT dangling (table[w] = 1) */

src/select.c:355-357
      if( type && (!strcmp(type, "label") || !strcmp(type, "probe") )) {
        continue;
      }
```

`ipin`/`opin`/`iopin` are **not** excluded — a hierarchy port *does* mark a wire connected.
The same wrong claim appears in the user-facing text:

```c
src/scheduler.c:10668-10670
    /* select_dangling_nets
     *   Select all nets/labels that are dangling, ie not attached to any non pin/port/probe components
```

and at `doc/xschem_man/developer_info.html:1489`. Only the Changelog wording
("non-label/non-probe") matches the implementation.

Measured asymmetry, one script:

```
N 0 0 100 0 {lab=VDD}       <- only attachment: lab_pin p1
N 0 100 100 100 {lab=VDD}   <- lab_pin p2 + res R1 pin
N 0 200 100 200 {lab=IN}    <- only attachment: ipin p3
C {devices/lab_pin.sym} 400 400 … {name=p4 lab=STRAY}   <- touches nothing

xschem load dang.sch; xschem select_dangling_nets; xschem delete
->  sel=3, selected_set = {p1} {p4}
    before: wires=3 insts=5     after: wires=2 insts=3
    surviving: (0,100)-(100,100) and (0,200)-(100,200)
```

The label-only wire was deleted; the **ipin**-terminated wire survived.

### B — connect-by-name is not considered, and the manual's recipe then deletes real nets

Label connectivity is by **name**, and this function is purely geometric. In the run above,
wire (0,0)-(100,0) carries `lab_pin lab=VDD` and is electrically the same net as the wire
with `R1` on it — yet it is flagged dangling. The manual's own recipe then deletes it:

```
doc/xschem_man/developer_info.html:2419-2422
# If after some editing or deletions dangling nets are present
# they can all be selected. Deletion may be done with a "xschem delete" command.
xschem select_dangling_nets
```

This is an intent/documentation gap, not a coding error — but it is the one that can
actually cost a user a net.

### C — the second pass omits `skip_instance()`

Passes 1 (`select.c:351`) and 3 (`:453`) call `skip_instance()`; pass 2 (`:415-418`) does
not. An `lvs_ignore`'d label attached to a dangling wire is therefore still selected. Small
and self-contained.

## Fix

Documentation truthfulness plus the one guard. No behavioural change to the exclusion.

```c
src/select.c:342
  /* Mark nets connected to non label/probe components as NOT dangling (table[w] = 1).
   * NOTE: ipin/opin/iopin DO count as a connection. */
```

```c
src/scheduler.c:10669
   *   Select all nets/labels that are dangling, ie not attached to any non-label/non-probe
   *   component (hierarchy pins ipin/opin/iopin DO count as a connection).
   *   NOTE: label-to-label connectivity is by NAME and is NOT considered here, so a wire
   *   connected only via a matching label elsewhere is reported dangling.
```

Mirror the same sentence at `doc/xschem_man/developer_info.html:1489`, and add the caveat
next to the delete recipe at `:2419`.

For C, add the missing `skip_instance()` guard to the second pass at `select.c:415-418`,
matching passes 1 and 3.

If someone genuinely wants "a label counts as a terminator", that is a **new opt-in mode**,
not a fix: it needs a second table pass keyed on expanded label names, because labels
connect by name — a purely geometric change at `select.c:355` would still be wrong.

## Risks

- **Exposure is low.** `grep -rn "dangling" --include=*.tcl` finds no menu item, no button
  and no key binding anywhere in `src/xschem.tcl` or the helper `.tcl` files. The command
  has no menu name; it is reachable only from the Tcl console or a script, exactly as the
  manual shows. So the whole issue is visible to scripting users only.
- **Doc-only changes are risk-free here.** `scheduler.c:10671-10676` is the sole caller;
  there is no C-internal and no in-tree Tcl caller.
- **The function has real side effects regardless**: it mutates `.sel` on wires and
  instances and calls `rebuild_selected_array()` / `draw_selection()` (`select.c:474-476`).
  Any test harness invoking it must `unselect_all()` afterwards.
- The `skip_instance()` addition changes what gets selected for `lvs_ignore`'d labels. Tiny
  blast radius, but it is a behaviour change — mention it in the commit.
