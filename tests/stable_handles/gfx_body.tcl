# Characterization tests for the GRAPHICAL object lifecycle (rect/line/poly/arc)
# — Phase A of the stable-object-handles step-3 work. These lock the CURRENT
# behavior as observed through the Tcl surface, so the upcoming lifecycle funnel
# refactor (route every per-layer rects/lines/polygons/arcs ++/--/= through one
# family in store.c) is provably behavior-identical. They must be green at every
# commit from Phase A on.
#
# Sourced by gfx_wrap.tcl, which provides `check`, `xcheck`, `::qo_dir`.
#
# THE NEW WRINKLE vs wires/instances: graphical objects live in PER-LAYER arrays
# (xctx->rect[layer][index], count xctx->rects[layer]). An object is addressed by
# the pair (layer, index), and that pair is what `xschem selection` returns as
# {type index col id} with col == the layer. There is no name and (today) no id,
# so a held (layer,index) dangles silently across a delete — the §2e hazard with
# no handle at all. That is exactly what Phase D will cure.
#
# Lifecycle sites exercised (census in code_analysis/graphical_lifecycle_census.md):
#   BIRTH store fns   -> GC2  (xschem rect/line/polygon/arc ...)   [store.c]
#   BIRTH merge fns   -> GC13 (xschem copy + paste)                [paste.c]
#   BIRTH load fns    -> every reload                              [save.c]
#   DEATH delete      -> GC3 / GC5                                 [select.c:399-488]
#   REORDER-SHIFT pos>=0 insert -> GC9 (rect/line only, Tcl-reachable) [store.c]
#   REORDER-SWAP  change_elem_order -> GC8                         [editprop.c:1104]
#   BULK_RESET clear  -> GC10                                      [actions.c:1096]
#   undo restore (both backends) -> GC4 / GC12
# NOT covered (honest gaps, per green-but-hollow rule 4):
#   DEATH check_collapsing_objects (degenerate cleanup, move.c:133) — only fires
#   after a move/copy that makes a rect zero-area or a line zero-length; not
#   cleanly reachable as an isolated op from Tcl. The Phase C funnel routes it
#   through the same death door, covered structurally by the byte-compare drift
#   check (GC12) over move-bearing cycles, not directly here.

### stub every modal dialog BEFORE any code path can reach one
rename tk_messageBox _real_tk_messageBox
proc tk_messageBox {args} {return ok}
rename tk_getOpenFile _real_tk_getOpenFile
proc tk_getOpenFile {args} {return {}}
catch {rename alert_ _real_alert_}
proc alert_ {args} {return 1}

set FIX /tmp/sh_gfx_fixture.sch

# sorted, geometry-only graphical-object list (the B/L/P/A save records) from a
# saveas. A record's first char is B(rect) L(line) A(arc) P(poly); each is one
# line `<C> <layer> <coords...> {prop}`. The SET of records is the behavior we
# preserve; per-layer array order is an implementation detail Phase C may change.
proc gfx_snapshot {tag} {
  set f /tmp/sh_gfx_snap_$tag.sch
  file delete -force $f
  xschem saveas $f schematic
  set fd [open $f r]; set data [read $fd]; close $fd
  set out {}
  foreach line [split $data \n] {
    if {[regexp {^[BLPA] } $line]} { lappend out $line }
  }
  return [lsort $out]
}
# count snapshot records of a given prefix letter (B/L/P/A) on a given layer,
# or all layers if layer is {}
proc count_recs {tag letter {layer {}}} {
  set n 0
  foreach r [gfx_snapshot $tag] {
    if {[string index $r 0] ne $letter} continue
    if {$layer ne {} && [lindex $r 1] != $layer} continue
    incr n
  }
  return $n
}
proc nrect {c} {return [xschem get rects $c]}
proc nline {c} {return [xschem get lines $c]}
proc npoly {c} {return [xschem get polygons $c]}
proc read_file {f} { set fd [open $f r]; set d [read $fd]; close $fd; return $d }
# body from the first "G {" record onward — skips the v{} header that memory
# undo is known not to round-trip (same quirk the wire/instance suites lock)
proc body_after_header {f} {
  set lines [split [read_file $f] \n]
  set i [lsearch -glob $lines {G \{*}]
  return [join [lrange $lines $i end] \n]
}
# build a controlled, fully-known fixture: layer 5 = 3 rects + 1 line + 1 poly,
# layer 6 = 1 rect + 1 arc. Saved to $FIX so reload exercises the load births.
proc gfx_build {} {
  global FIX
  xschem set modified 0
  xschem clear force schematic
  xschem set rectcolor 5
  xschem rect 0   0 100 100
  xschem rect 200 0 300 100
  xschem rect 400 0 500 100
  xschem line 0 500 600 500
  xschem polygon 0 700 100 700 50 800
  xschem set rectcolor 6
  xschem rect 1000 0 1100 100
  xschem arc 1000 1000 50 0 360 6
  xschem saveas $FIX schematic
}
proc reload {} {
  global FIX
  xschem set modified 0
  xschem load $FIX
}

### GC1 — fixture builds and reloads with the expected per-layer population
gfx_build
reload
set ::base_snap [gfx_snapshot base]
check {GC1a fixture: 3 rects + 1 line + 1 poly on layer 5} \
  {[nrect 5] == 3 && [nline 5] == 1 && [npoly 5] == 1}
check {GC1b fixture: 1 rect + 1 arc on layer 6} \
  {[nrect 6] == 1 && [count_recs gc1 A 6] == 1}
check {GC1c snapshot has 4 rects + 1 line + 1 poly + 1 arc = 7 records} \
  {[llength $::base_snap] == 7}

### GC2 — create a rect (BIRTH: storeobject) on layer 5
reload
xschem set rectcolor 5
set before [nrect 5]
xschem rect 700 0 800 100
check {GC2a create rect: layer-5 count +1} {[nrect 5] == $before + 1}
set s2 [gfx_snapshot gc2]
set diff {}
foreach l $s2 {if {[lsearch -exact $::base_snap $l] < 0} {lappend diff $l}}
check {GC2b create rect: snapshot gains exactly the new rect record} \
  {$diff eq {{B 5 700 0 800 100 {}}} && [llength $s2] == [llength $::base_snap] + 1}
xschem unselect_all
xschem select rect 5 [expr {[nrect 5] - 1}]
set row [lindex [xschem selection] 0]
check {GC2c selection row is {rect <idx> 5 -1} (col == layer 5, id -1 today)} \
  {[lindex $row 0] eq {rect} && [lindex $row 2] == 5 && [lindex $row 3] == -1}

### GC3 — delete it (DEATH: delete_objects)
xschem unselect_all
xschem select rect 5 [expr {[nrect 5] - 1}]
xschem delete
check {GC3a delete rect: count back to baseline} {[nrect 5] == 3}
check {GC3b delete rect: snapshot equals baseline set} {[gfx_snapshot gc3] eq $::base_snap}

### GC4 — undo/redo round-trip of a DELETE (the undoable op), BOTH backends.
### NOTE: programmatic graphical create (`xschem rect ...`) does NOT push undo
### (unlike `xschem instance`), so the undoable cycle is delete->undo, not
### create->undo; GC4e locks that asymmetry explicitly.
foreach utype {disk memory} {
  reload
  xschem undo_type $utype
  xschem unselect_all
  xschem select rect 5 2
  xschem delete
  check "GC4a ($utype) delete a fixture rect: layer-5 count 3->2" {[nrect 5] == 2}
  xschem undo
  check "GC4b ($utype) undo restores the deleted rect" {[nrect 5] == 3}
  xschem redo
  check "GC4c ($utype) redo re-deletes" {[nrect 5] == 2}
  xschem undo
  check "GC4d ($utype) undo again: snapshot equals baseline" \
    {[nrect 5] == 3 && [gfx_snapshot gc4_$utype] eq $::base_snap}
}

### GC4e — programmatic graphical create is NOT undoable (the rect/line/polygon/
### arc scheduler commands do not call push_undo): undoing right after a create
### does not remove it. A real, surprising behavior worth locking before the
### funnel touches anything.
reload
xschem undo_type memory
xschem set rectcolor 5
xschem rect 700 0 800 100
check {GC4e-pre create rect: layer-5 count 3->4} {[nrect 5] == 4}
xschem undo
check {GC4e undo-of-create leaves the rect (create not pushed to undo)} {[nrect 5] == 4}

### GC5 — THE per-layer index dangle (the §2e analog, the whole motivation).
### Locks today's behavior: a rect's array INDEX is unstable across a delete of
### an EARLIER rect on the same layer (compaction shifts it down), and there is
### NO name and NO id to fall back on — the held (layer,index) silently names a
### different rect. This is what Phase D cures with an id.
reload
xschem set rectcolor 5
xschem rect 700 0 800 100   ;# a 4th rect on layer 5, at index 3
set idx_new [expr {[nrect 5] - 1}]
# capture which rect lives at idx_new via its save coords
xschem unselect_all
xschem select rect 5 $idx_new
set row_before [lindex [xschem selection] 0]
check {GC5a created rect sits at the highest index on its layer} {$idx_new == 3}
# delete rect at index 0 on layer 5 -> every later index shifts down by 1
xschem unselect_all
xschem select rect 5 0
xschem delete
check {GC5b INDEX is unstable: layer-5 rect count drops to 3, indices renumber} \
  {[nrect 5] == 3}
# the rect that WAS at idx 3 is now reachable only at idx 2 — the raw index
# we held (3) now names a DIFFERENT rect (or is out of range): the dangle
xschem unselect_all
set sel3 [xschem select rect 5 3]
check {GC5c the held index 3 no longer addresses the rect (out of range now)} \
  {$sel3 == 0}

### GC6 — layer independence: deleting on layer 5 does not disturb layer 6
reload
set l6_before [nrect 6]
xschem unselect_all
xschem select rect 5 0
xschem delete
check {GC6 layer 6 rect count unchanged by a layer-5 delete} {[nrect 6] == $l6_before}

### GC7 — all four types create + their save-record format (B/L/P/A)
reload
xschem set rectcolor 7
xschem rect 2000 0 2100 100
xschem line 2000 200 2100 200
xschem polygon 2000 400 2100 400 2050 500
xschem arc 2000 600 40 0 180 7
set s7 [gfx_snapshot gc7]
set new {}
foreach l $s7 {if {[lsearch -exact $::base_snap $l] < 0} {lappend new $l}}
check {GC7 the four new records are one each B/L/P/A on layer 7} \
  {[lsearch -exact $new {B 7 2000 0 2100 100 {}}] >= 0 && \
   [lsearch -exact $new {L 7 2000 200 2100 200 {}}] >= 0 && \
   [lsearch -exact $new {P 7 3 2000 400 2100 400 2050 500 {}}] >= 0 && \
   [lsearch -exact $new {A 7 2000 600 40 0 180 {}}] >= 0 && \
   [llength $new] == 4}

### GC8 — reorder-swap (change_elem_order) on rects within a layer: executes and
### preserves the SET (the per-layer analog of the instance CHI9 swap)
reload
set snap8a [gfx_snapshot gc8a]
xschem unselect_all
xschem select rect 5 2          ;# select the last rect on layer 5
xschem change_elem_order 0      ;# move it to index 0
check {GC8a swap executed: layer-5 rect count unchanged} {[nrect 5] == 3}
check {GC8b swap preserves the rect SET (snapshot unchanged)} \
  {[gfx_snapshot gc8b] eq $snap8a}

### GC9 — positional-insert reorder (pos>=0), reachable from Tcl for rect/line:
### inserting at a position shifts later same-layer rects up by one
reload
xschem set rectcolor 5
xschem rect 900 0 950 100 1       ;# insert at position 1 on layer 5
check {GC9a positional insert: layer-5 rect count +1} {[nrect 5] == 4}
xschem unselect_all
xschem select rect 5 1
set row9 [lindex [xschem selection] 0]
check {GC9b the inserted rect now occupies index 1} \
  {[lindex $row9 0] eq {rect} && [lindex $row9 1] == 1 && [lindex $row9 2] == 5}

### GC10 — bulk reset (clear_drawing sets every per-layer count to 0)
reload
xschem set modified 0
xschem clear force schematic
check {GC10 clear force schematic: zero rects/lines/polys on layers 5,6} \
  {[nrect 5] == 0 && [nline 5] == 0 && [npoly 5] == 0 && [nrect 6] == 0}

### GC11 — selection enumerates ALL four graphical types with col == layer and
### id == -1 (no stable id yet). Phase D fills the id; GC11's id assertions are
### the ones that flip there.
reload
xschem unselect_all
xschem select_all
set rows [xschem selection]
# collect the distinct types present among graphical rows
set types {}
foreach r $rows {
  set t [lindex $r 0]
  if {$t in {rect line poly arc} && [lsearch -exact $types $t] < 0} {lappend types $t}
}
check {GC11a select_all enumerates all four graphical types} \
  {{rect} in $types && {line} in $types && {poly} in $types && {arc} in $types}
# every graphical row carries col==layer (a valid layer index) and id==-1 today
set all_minus1 1
set col_is_layer 1
foreach r $rows {
  if {[lindex $r 0] ni {rect line poly arc}} continue
  if {[lindex $r 3] != -1} {set all_minus1 0}
  if {[lindex $r 2] < 0} {set col_is_layer 0}
}
check {GC11b every graphical row's id slot is -1 today (no stable id)} {$all_minus1 == 1}
check {GC11c every graphical row's col is a valid layer (>= 0)} {$col_is_layer == 1}

### GC12 — whole-pipeline drift detector (byte-level), like CHI6. Uses the
### undoable delete->undo cycle (create is not pushed to undo, GC4e).
reload
xschem saveas /tmp/sh_gfx_save_clean1.sch schematic
reload
xschem saveas /tmp/sh_gfx_save_clean2.sch schematic
check {GC12a save is deterministic (two clean saves byte-identical)} \
  {[read_file /tmp/sh_gfx_save_clean1.sch] eq [read_file /tmp/sh_gfx_save_clean2.sch]}
reload
xschem undo_type disk
xschem unselect_all
xschem select rect 5 0
xschem delete
xschem undo
xschem saveas /tmp/sh_gfx_save_disk.sch schematic
check {GC12b disk delete+undo cycle: save byte-identical to clean save} \
  {[read_file /tmp/sh_gfx_save_disk.sch] eq [read_file /tmp/sh_gfx_save_clean1.sch]}
reload
xschem undo_type memory
xschem unselect_all
xschem select rect 5 0
xschem delete
xschem undo
xschem saveas /tmp/sh_gfx_save_mem.sch schematic
check {GC12c memory delete+undo cycle: save body identical from G record onward} \
  {[body_after_header /tmp/sh_gfx_save_mem.sch] eq [body_after_header /tmp/sh_gfx_save_clean1.sch]}

### GC13 — copy/paste as BIRTH (merge_rect path, paste.c): pasting a selected
### rect adds one to its layer. Exercises the merge birth door that the Phase C
### funnel will route through the same chokepoint as the store births.
reload
xschem unselect_all
xschem select rect 5 0
set before [nrect 5]
xschem copy
xschem paste 500 0
check {GC13 copy+paste a rect (merge_rect birth): layer-5 count +1} \
  {[nrect 5] == $before + 1}

### GH1–GH11 — session-stable graphical-object ids (Phase D of the step-3 plan).
### Committed RED first per the TDD discipline: every xcheck below logs XFAIL
### until the D2 implementation lands, then flips to a plain check. GH7 (disk
### undo = invalidate-on-restore) flips to a HARD check too, like the instance
### HI7 — the disk-undo contract is already settled for the whole effort.
###
### Surface under test (additive, per-type, two scheduler subcommands each;
### the index is the per-layer PAIR {layer index} because graphical objects
### live in per-layer arrays):
###   xschem <type>_id <layer> <index>  → session-stable id (or -1)
###   xschem <type>_index <id>          → {layer index} (or -1)
### for <type> in rect line poly arc. One SHARED id space across all four
### types (a rect and a line never collide on id value).
###
### Conventions: wrappers h_gid/h_gidx catch the "invalid command" error so the
### RED suite runs to completion (-2 sentinel, transparent once the commands
### exist). The id is the ONLY handle (graphical types have no name).

proc h_gid {type c n} {
  if {[catch {xschem ${type}_id $c $n} r]} {return -2}
  return $r
}
proc h_gidx {type id} {
  if {[catch {xschem ${type}_index $id} r]} {return -2}
  return $r
}

### GH1 — created objects have positive, pairwise-distinct ids ACROSS all four
### types (one shared id space): a rect, a line, a poly and an arc
reload
xschem set rectcolor 5
xschem rect 700 0 800 100
xschem line 700 200 800 200
xschem polygon 700 400 800 400 750 500
xschem set rectcolor 6
xschem arc 700 600 30 0 180 6
set ir [h_gid rect 5 [expr {[nrect 5] - 1}]]
set il [h_gid line 5 [expr {[nline 5] - 1}]]
set ip [h_gid poly 5 [expr {[npoly 5] - 1}]]
set ia [h_gid arc 6 0]
xcheck {GH1 four new objects have positive pairwise-distinct ids (shared id space)} \
  {$ir > 0 && $il > 0 && $ip > 0 && $ia > 0 && \
   $ir != $il && $ir != $ip && $ir != $ia && $il != $ip && $il != $ia && $ip != $ia}

### GH2 — the §2e per-layer scenario: hold a rect's id, delete an EARLIER rect
### on the SAME layer; the held rect's array index shifts down by the
### compaction but the id still resolves to its new {layer index}, and the id
### round-trips there (proving it is the same rect — ids are unique)
reload
xschem set rectcolor 5
xschem rect 700 0 800 100        ;# 4th rect on layer 5, at index 3
set ida [h_gid rect 5 3]
xschem unselect_all
xschem select rect 5 0           ;# delete the lowest-index rect on layer 5
xschem delete
set loc [h_gidx rect $ida]
xcheck {GH2a id survives an earlier-rect delete; resolves to the shifted {5 2}} \
  {$loc eq {5 2}}
xcheck {GH2b round-trip: rect_id at the resolved location returns the held id} \
  {$ida > 0 && [h_gid rect 5 2] == $ida}

### GH3 — delete the held rect itself: the id dangles LOUDLY (-1), not a stranger
reload
xschem set rectcolor 5
xschem rect 700 0 800 100
set ida [h_gid rect 5 [expr {[nrect 5] - 1}]]
xschem unselect_all
xschem select rect 5 [expr {[nrect 5] - 1}]
xschem delete
xcheck {GH3 deref after own deletion returns -1} {[h_gidx rect $ida] == -1}

### GH4 — no id reuse: create→delete→create at the same coords mints a fresh id
reload
xschem set rectcolor 5
xschem rect 700 0 800 100
set id4a [h_gid rect 5 [expr {[nrect 5] - 1}]]
xschem unselect_all
xschem select rect 5 [expr {[nrect 5] - 1}]
xschem delete
xschem rect 700 0 800 100
set id4b [h_gid rect 5 [expr {[nrect 5] - 1}]]
xcheck {GH4 recreated rect at same coords gets a fresh id} \
  {$id4a > 0 && $id4b > 0 && $id4a != $id4b}

### GH5 — memory-undo round-trip. Graphical create is not undoable (GC4e), so
### the undoable cycle is delete→undo: deleting dangles the id, undo restores
### the SAME id (memory undo copies whole structs, the id rides free)
reload
xschem undo_type memory
xschem set rectcolor 5
xschem rect 700 0 800 100
set id5 [h_gid rect 5 [expr {[nrect 5] - 1}]]
xschem unselect_all
xschem select rect 5 [expr {[nrect 5] - 1}]
xschem delete
set gone [h_gidx rect $id5]
xschem undo
set back [h_gidx rect $id5]
xcheck {GH5a memory undo: deleted rect's id dangles} {$gone == -1}
xcheck {GH5b memory undo restores the SAME id resolving to the rect} \
  {[lindex $back 0] >= 0 && [h_gid rect [lindex $back 0] [lindex $back 1]] == $id5}
xschem undo_type memory

### GH6 — the DESIGN CALL, characterized to the implementation reality: a layer
### change is `xschem set rectcolor <c>` on a selection, which change_layer()
### implements as DELETE+RECREATE. So the id does NOT survive a layer change —
### the reconstructed rect on the new layer gets a FRESH id and the old id
### dangles. (A held id is stable only within a layer-stable lifetime.)
reload
xschem set rectcolor 5
xschem rect 700 0 800 100
set id6 [h_gid rect 5 [expr {[nrect 5] - 1}]]
set l6_before [nrect 6]
xschem unselect_all
xschem select rect 5 [expr {[nrect 5] - 1}]
xschem set rectcolor 6           ;# selection present -> change_layer(): rect moves to layer 6
# GH6a exercises only change_layer() (no new id surface), so it is true TODAY —
# a plain check characterizing the delete+recreate move; GH6b/GH6c (the id half)
# are the id-dependent XFAILs.
check {GH6a layer change moved the rect to layer 6 (count +1 there)} \
  {[nrect 6] == $l6_before + 1}
xcheck {GH6b the old id dangles after the layer change (delete+recreate)} \
  {[h_gidx rect $id6] == -1}
set id6b [h_gid rect 6 [expr {[nrect 6] - 1}]]
xcheck {GH6c the reconstructed rect on layer 6 carries a fresh id} \
  {$id6b > 0 && $id6b != $id6}

### GH7 — disk-undo round-trip = invalidate-on-restore (settled, like HI7/wire
### D3): a disk-undo restore re-reads the .sch (no id persisted) and mints a
### fresh id, so the held id dangles -1 and the restored rect carries a new id.
reload
xschem undo_type disk
xschem set rectcolor 5
xschem rect 700 0 800 100
set id7 [h_gid rect 5 [expr {[nrect 5] - 1}]]
xschem unselect_all
xschem select rect 5 [expr {[nrect 5] - 1}]
xschem delete
xschem undo
set after7 [h_gidx rect $id7]
set id7b [h_gid rect 5 [expr {[nrect 5] - 1}]]
xcheck {GH7a disk undo+restore: the held id is invalidated (dangles -1)} \
  {$after7 == -1}
xcheck {GH7b disk undo+restore: the restored rect carries a fresh id} \
  {$id7b > 0 && $id7b != $id7}
xschem undo_type memory

### GH8 — copy/paste (merge_rect birth) gets a FRESH id distinct from the source
reload
xschem set rectcolor 5
xschem rect 700 0 800 100
set src8 [h_gid rect 5 [expr {[nrect 5] - 1}]]
xschem unselect_all
xschem select rect 5 [expr {[nrect 5] - 1}]
xschem copy
xschem paste 500 0
set id8 [h_gid rect 5 [expr {[nrect 5] - 1}]]
xcheck {GH8 paste/merge birth gets a fresh id distinct from the source} \
  {$id8 > 0 && $src8 > 0 && $id8 != $src8}

### GH9 — the selection enumerator carries the real id for graphical rows:
### {rect <idx> <layer> <id>} with <id> == rect_id <layer> <idx> > 0
reload
xschem set rectcolor 5
xschem rect 700 0 800 100
xschem unselect_all
xschem select rect 5 [expr {[nrect 5] - 1}]
set row [lindex [xschem selection] 0]
set sidx [lindex $row 1]
set slay [lindex $row 2]
set sid  [lindex $row 3]
xcheck {GH9 selection rect row carries the real id (== rect_id layer idx > 0)} \
  {$sid > 0 && $sid == [h_gid rect $slay $sidx]}

### GH10 — one SHARED id space: a rect and a line get distinct ids, and neither
### type's resolver answers the other's id (type-scoped resolvers)
reload
xschem set rectcolor 5
xschem rect 700 0 800 100
set rid [h_gid rect 5 [expr {[nrect 5] - 1}]]
xschem line 700 200 800 200
set lid [h_gid line 5 [expr {[nline 5] - 1}]]
xcheck {GH10a rect id and line id are distinct (shared counter)} {$rid != $lid && $rid > 0 && $lid > 0}
xcheck {GH10b line_index does not resolve a rect's id (type-scoped resolver)} \
  {[h_gidx line $rid] == -1}
xcheck {GH10c rect_index does not resolve a line's id} \
  {[h_gidx rect $lid] == -1}

### GH11 — positional-insert reorder (GR1): inserting a rect at a position mints
### a fresh id for the inserted rect, while the shifted rect keeps its id
reload
xschem set rectcolor 5
set id_at1_before [h_gid rect 5 1]    ;# the rect currently at index 1
xschem rect 900 0 950 100 1           ;# insert at position 1
set id_inserted [h_gid rect 5 1]      ;# the new rect now occupies index 1
set id_shifted  [h_gid rect 5 2]      ;# the old index-1 rect shifted to index 2
xcheck {GH11a the inserted rect at index 1 has a fresh id} \
  {$id_inserted > 0 && $id_inserted != $id_at1_before}
xcheck {GH11b the shifted rect kept its id (now at index 2)} \
  {$id_shifted == $id_at1_before && $id_at1_before > 0}

xschem set modified 0
