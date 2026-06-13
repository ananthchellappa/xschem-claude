# Characterization tests for the INSTANCE (component) lifecycle — Phase A of
# the stable-object-handles step-2 work. These lock the CURRENT behavior as
# observed through the Tcl surface, so the upcoming lifecycle funnel refactor
# (route every instances++/--/= through one family in store.c) is provably
# behavior-identical. They must be green at every commit from Phase A on.
#
# Sourced by inst_wrap.tcl, which provides `check`, `xcheck`, `::qo_dir`.
#
# Lifecycle sites exercised (census: code_analysis/instance_lifecycle_census.md):
#   BIRTH place_symbol  -> CHI1 (xschem instance ...)
#   BIRTH load_inst     -> every reload
#   BIRTH move-copy     -> CHI4 (copy_objects)        [move.c:972]
#   BIRTH merge_inst    -> CHI5 (copy + paste)        [paste.c:312]
#   DEATH delete_objects-> CHI2 / CHI3                [select.c:582]
#   BULK_RESET clear    -> CHI10                      [actions.c:1073]
#   undo restore (both backends) -> CHI3 / CHI6
#   REORDER-SWAP change_elem_order -> CHI9            [editprop.c:1100]
# NOT covered (honest gaps, per green-but-hollow rule 4):
#   REORDER-SHIFT place_symbol pos>=0 — the `xschem instance` command
#   hardcodes pos=-1, so the positional-insert shift is unreachable from Tcl.
#
# Conventions (same as the wire suite):
#   - All edits on /tmp/sh_inst_fixture.sch (a copy) — never the repo file.
#   - `xschem set modified 0` before every load (dodges the save-prompt modal).
#   - The instance snapshot is PLACEMENT-ONLY (symbol + x y rot flip) and
#     SORTED: the *set* of instances is the behavior we preserve; array order
#     is an implementation detail already unstable today (CHI7) and the funnel
#     must stay free to change it. Property drift is covered separately by the
#     byte-compare checks (CHI6).

### stub every modal dialog BEFORE any code path can reach one
rename tk_messageBox _real_tk_messageBox
proc tk_messageBox {args} {return ok}
rename tk_getOpenFile _real_tk_getOpenFile
proc tk_getOpenFile {args} {return {}}
catch {rename alert_ _real_alert_}
proc alert_ {args} {return 1}

### fixture: a /tmp copy of the 117-instance example
set REPO [file normalize $::qo_dir/../..]
set FIX /tmp/sh_inst_fixture.sch
file copy -force $REPO/xschem_library/examples/mos_power_ampli.sch $FIX

proc reload {} {
  global FIX
  xschem set modified 0
  xschem load $FIX
}
proc ninst {} {return [xschem get instances]}
# 1 if instance <name> resolves, 0 if not (select returns "1"/"0", no error)
proc resolves {name} {
  xschem unselect_all
  set r [xschem select instance $name]
  xschem unselect_all
  return $r
}
# current array index of instance <name>, or -1 (via the selection enumerator)
proc idx_of {name} {
  xschem unselect_all
  if {[xschem select instance $name] == 0} { xschem unselect_all; return -1 }
  set row [lindex [xschem selection] 0]
  xschem unselect_all
  return [lindex $row 1]
}
# sorted, placement-only instance list (symbol + x y rot flip) from the saved
# .sch C-records. The C-record's first line is `C {sym} x y rot flip {prop...`;
# multi-line props continue on lines that do NOT start with "C ", so the
# regex over first-lines captures every instance's placement exactly once.
proc inst_snapshot {tag} {
  set f /tmp/sh_inst_snap_$tag.sch
  file delete -force $f
  xschem saveas $f schematic
  set fd [open $f r]; set data [read $fd]; close $fd
  set out {}
  foreach line [split $data \n] {
    if {[regexp {^C \{([^\}]*)\} (\S+) (\S+) (\S+) (\S+)} $line -> sym x y rot flip]} {
      lappend out "C {$sym} $x $y $rot $flip"
    }
  }
  return [lsort $out]
}
proc read_file {f} {
  set fd [open $f r]; set d [read $fd]; close $fd
  return $d
}
# content from the first "G {" record onward — skips the v{...} header, which
# memory undo is known not to round-trip (same quirk the wire suite locks)
proc body_after_header {f} {
  set lines [split [read_file $f] \n]
  set i [lsearch -glob $lines {G \{*}]
  return [join [lrange $lines $i end] \n]
}

### CHI1 — create an instance (BIRTH: place_symbol)
reload
set ::base_n [ninst]
set ::base_snap [inst_snapshot base]
check {CHI1pre fixture has 117 instances} \
  {$::base_n == 117 && [llength $::base_snap] == 117}
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
check {CHI1a create: instance count +1} {[ninst] == $::base_n + 1}
set s1 [inst_snapshot chi1]
set diff {}
foreach l $s1 {if {[lsearch -exact $::base_snap $l] < 0} {lappend diff $l}}
check {CHI1b create: snapshot gains exactly the new instance placement} \
  {$diff eq {{C {res.sym} 3000 3000 0 0}} && [llength $s1] == $::base_n + 1}
check {CHI1c created instance resolves by name} {[resolves AAA] == 1}

### CHI2 — delete it (DEATH: delete_objects)
xschem unselect_all
xschem select instance AAA
xschem delete
check {CHI2a delete: count back to baseline} {[ninst] == $::base_n}
check {CHI2b delete: instance no longer resolves by name} {[resolves AAA] == 0}
check {CHI2c delete: snapshot equals baseline set} {[inst_snapshot chi2] eq $::base_snap}

### CHI3 — undo/redo round-trip, BOTH undo backends
foreach utype {disk memory} {
  reload
  xschem undo_type $utype
  xschem unselect_all
  xschem instance res.sym 3000 3000 0 0 {name=AAA}
  xschem unselect_all
  xschem select instance AAA
  xschem delete
  check "CHI3a ($utype) create+delete: baseline count" {[ninst] == $::base_n}
  xschem undo
  check "CHI3b ($utype) undo restores the deleted instance" \
    {[ninst] == $::base_n + 1 && [resolves AAA] == 1}
  xschem redo
  check "CHI3c ($utype) redo re-deletes" {[ninst] == $::base_n && [resolves AAA] == 0}
  xschem undo
  xschem undo
  check "CHI3d ($utype) full unwind: snapshot equals baseline" \
    {[ninst] == $::base_n && [inst_snapshot chi3_$utype] eq $::base_snap}
}

### CHI4 — copy as BIRTH (move_objects copy path): a duplicate is a new
### instance with a FRESH unique name; the original is untouched
reload
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
xschem unselect_all
xschem select instance AAA
set before [ninst]
xschem copy_objects 500 0
check {CHI4a copy_objects: count +1} {[ninst] == $before + 1}
set newidx [expr {[ninst] - 1}]
set newrow [xschem instance_coord $newidx]
check {CHI4b the copy carries a FRESH name (not AAA) at the offset coords} \
  {[lindex $newrow 0] ne {AAA} && [lindex $newrow 0] ne {} && \
   [lindex $newrow 2] == 3500 && [lindex $newrow 3] == 3000}
check {CHI4c original AAA is unchanged and still resolves} \
  {[resolves AAA] == 1 && [string trim [xschem instance_coord AAA]] eq {{AAA} {res.sym} 3000 3000 0 0}}

### CHI5 — paste as BIRTH (merge_inst path): copy to clipboard + paste adds one
reload
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
xschem unselect_all
xschem select instance AAA
set before [ninst]
xschem copy
xschem paste 600 0
check {CHI5 copy+paste (merge_inst): count +1} {[ninst] == $before + 1}

### CHI6 — whole-pipeline drift detector (byte-level)
reload
xschem saveas /tmp/sh_inst_save_clean1.sch schematic
reload
xschem saveas /tmp/sh_inst_save_clean2.sch schematic
check {CHI6a save is deterministic (two clean saves byte-identical)} \
  {[read_file /tmp/sh_inst_save_clean1.sch] eq [read_file /tmp/sh_inst_save_clean2.sch]}

reload
xschem undo_type disk
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
xschem unselect_all
xschem select instance AAA
xschem delete
xschem undo
xschem undo
xschem saveas /tmp/sh_inst_save_disk.sch schematic
check {CHI6b disk-undo edit cycle: save byte-identical to clean save} \
  {[read_file /tmp/sh_inst_save_disk.sch] eq [read_file /tmp/sh_inst_save_clean1.sch]}

reload
xschem undo_type memory
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
xschem unselect_all
xschem select instance AAA
xschem delete
xschem undo
xschem undo
xschem saveas /tmp/sh_inst_save_mem.sch schematic
check {CHI6c memory-undo edit cycle: save body identical from G record onward} \
  {[body_after_header /tmp/sh_inst_save_mem.sch] eq [body_after_header /tmp/sh_inst_save_clean1.sch]}

### CHI7 — THE identity characterization (the §2e analog for instances).
### Locks today's behavior: an instance's array INDEX is unstable across a
### delete of an earlier instance (compaction shifts it down), but the NAME is
### a stable handle that still resolves. This is the crucial difference from
### wires (which had NO stable handle) and the fact that shapes Phase D: do
### instances need a numeric id, or does the name suffice?
reload
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
set idx_before [idx_of AAA]
check {CHI7a created instance has a valid index} {$idx_before >= 0}
# delete a LOW-index instance (index 0) so every later index shifts down by 1
xschem unselect_all
xschem select instance 0
xschem delete
set idx_after [idx_of AAA]
check {CHI7b INDEX is unstable: AAA's index shifted down by the compaction} \
  {$idx_after == $idx_before - 1}
check {CHI7c NAME is stable: AAA still resolves and keeps its coords} \
  {[resolves AAA] == 1 && [string trim [xschem instance_coord AAA]] eq {{AAA} {res.sym} 3000 3000 0 0}}

### CHI8 — selection side effects (instances flow through `selection` and
### `selected_set`). The id slot in the instance row was -1 through Phase A-C
### (no stable id yet); Phase D fills it with the real session-stable id, so
### CHI8c was DELIBERATELY flipped from `== -1` to `> 0 && == instance_id` at
### the GREEN commit (a characterization test whose locked behavior changed
### by design — see HI9 for the dedicated id assertion).
reload
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
xschem unselect_all
xschem select instance AAA
check {CHI8a lastsel 1 after selecting one instance} {[xschem get lastsel] == 1}
check {CHI8b first_sel reports type ELEMENT(8)} {[lindex [xschem get first_sel] 0] == 8}
set row [lindex [xschem selection] 0]
check {CHI8c selection row is {instance <idx> 1 <id>} (col WIRELAYER, real id now)} \
  {[lindex $row 0] eq {instance} && [lindex $row 2] == 1 && \
   [lindex $row 3] > 0 && [lindex $row 3] == [xschem instance_id [lindex $row 1]]}
check {CHI8d selected_set lists the instance by name} \
  {[lsearch -exact [xschem selected_set] {AAA}] >= 0}

### CHI9 — reorder-swap (change_elem_order) executes and preserves the SET
reload
set snap0 [inst_snapshot chi9pre]
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
set name0_before [lindex [xschem instance_coord 0] 0]
set snap_with_aaa [inst_snapshot chi9with]
xschem unselect_all
xschem select instance AAA
xschem change_elem_order 0
check {CHI9a swap executed: AAA now sits at array index 0} \
  {[lindex [xschem instance_coord 0] 0] eq {AAA} && $name0_before ne {AAA}}
check {CHI9b swap preserves the instance SET (placement snapshot unchanged)} \
  {[inst_snapshot chi9post] eq $snap_with_aaa}
check {CHI9c both swapped instances still resolve by name} \
  {[resolves AAA] == 1 && [resolves $name0_before] == 1}

### CHI10 — bulk reset (clear_schematic sets instances = 0)
reload
xschem set modified 0
xschem clear force schematic
check {CHI10 clear force schematic: zero instances} {[ninst] == 0}

### HI1–HI9 — session-stable instance ids (Phase D of the step-2 plan).
### Committed RED first per the TDD discipline: every xcheck below logs XFAIL
### until the D2 implementation lands, then flips to a plain check. Unlike the
### wire suite (whose H7 stayed XFAIL pending the D3 disk-undo decision), the
### disk-undo behavior for instances is ALREADY settled for the whole effort
### (invalidate-on-restore, wire D3), so HI7 flips to a hard check at GREEN too.
###
### Surface under test (additive, two scheduler subcommands):
###   xschem instance_id <name|index>  → session-stable id of that instance (or -1)
###   xschem instance_index <id>       → current array index of that instance (or -1)
###
### Role contract (code_analysis/instance_identity_decision.md): the id is the
### canonical *durable session* handle (monotonic, never reused, NOT persisted);
### the name is the *human / cross-session* form (user-editable, file-persisted,
### REUSABLE — R37 came back after a delete, verified). The headline divergence:
### a name reuses and renames; an id never does (HI4, HI8).
###
### Conventions (mirroring the wire H-block):
### - wrappers h_iid/h_iidx catch the "invalid command" error so the RED suite
###   runs to completion; they return -2 (never a legal result) while the
###   commands do not exist, transparent once they do.
### - instance_id accepts a name OR an index (get_instance: digits→index, else
###   name); instance_index takes an id.

proc h_iid {ref} {
  if {[catch {xschem instance_id $ref} r]} {return -2}
  return $r
}
proc h_iidx {id} {
  if {[catch {xschem instance_index $id} r]} {return -2}
  return $r
}

### HI1 — ids of created instances are positive and pairwise distinct
reload
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
xschem instance res.sym 3100 3000 0 0 {name=BBB}
xschem instance res.sym 3200 3000 0 0 {name=CCC}
set ida [h_iid AAA]
set idb [h_iid BBB]
set idc [h_iid CCC]
check {HI1 created instances have positive pairwise-distinct ids} \
  {$ida > 0 && $idb > 0 && $idc > 0 && $ida != $idb && $ida != $idc && $idb != $idc}

### HI2 — the §2e scenario (CHI7 analog): hold id(A), delete an EARLIER
### instance (index 0). A's array index shifts down by the compaction, but the
### id still resolves to A's current index and that index dereferences to A.
reload
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
set ida [h_iid AAA]
set idx_before [idx_of AAA]
xschem unselect_all
xschem select instance 0
xschem delete
set idx_a [h_iidx $ida]
check {HI2a id survives an earlier-instance delete; index shifted down by 1} \
  {$idx_a >= 0 && $idx_a == $idx_before - 1}
set coord {}
if {$idx_a >= 0} {set coord [string trim [xschem instance_coord $idx_a]]}
check {HI2b resolved index dereferences to A's coords} \
  {$coord eq {{AAA} {res.sym} 3000 3000 0 0}}

### HI3 — delete A itself: the handle dangles LOUDLY (-1), it does not silently
### name a stranger like a raw index would after compaction
reload
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
set ida [h_iid AAA]
xschem unselect_all
xschem select instance AAA
xschem delete
check {HI3 deref after own deletion returns -1} {[h_iidx $ida] == -1}

### HI4 — THE headline: no id reuse, but the NAME reuses. Create an auto-named
### resistor, capture name+id, delete it, create another at the same coords:
### the auto-name comes back (R25→delete→R25, verified) but the id is FRESH.
### A script holding the NAME now silently references a different instance; a
### script holding the ID gets a clean fresh value it can tell apart.
reload
xschem unselect_all
xschem instance res.sym 4000 4000 0 0
set i1 [expr {[ninst] - 1}]
set name1 [lindex [xschem instance_coord $i1] 0]
set id1 [h_iid $i1]
xschem unselect_all
xschem select instance $i1
xschem delete
xschem unselect_all
xschem instance res.sym 4000 4000 0 0
set i2 [expr {[ninst] - 1}]
set name2 [lindex [xschem instance_coord $i2] 0]
set id2 [h_iid $i2]
check {HI4 name is REUSED but the id is FRESH (the R37 hazard, now safe)} \
  {$name1 ne {} && $name1 eq $name2 && $id1 > 0 && $id2 > 0 && $id1 != $id2}

### HI5 — memory-undo round-trip: undo dangles the id, redo restores the SAME
### id resolving to the same instance (mem undo copies whole structs both ways,
### census "facts banked for Phase D" — no undo code touched)
reload
xschem undo_type memory
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
set ida [h_iid AAA]
xschem undo
set gone [h_iidx $ida]
xschem redo
set back [h_iidx $ida]
check {HI5a memory undo: id of the undone instance dangles} {$gone == -1}
set coord {}
if {$back >= 0} {set coord [string trim [xschem instance_coord $back]]}
check {HI5b memory redo: the same id resolves again to A} \
  {$back >= 0 && $coord eq {{AAA} {res.sym} 3000 3000 0 0}}
xschem undo_type memory

### HI6 — copy/merge births get FRESH ids (each is a birth through
### inst_register: CHI4 copy_objects path, CHI5 copy+paste/merge_inst path)
reload
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
set ida [h_iid AAA]
xschem unselect_all
xschem select instance AAA
xschem copy_objects 500 0
set idx_copy [expr {[ninst] - 1}]
set id_copy [h_iid $idx_copy]
check {HI6a copy_objects birth gets a fresh id distinct from the source} \
  {$id_copy > 0 && $ida > 0 && $id_copy != $ida}
reload
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
set ida [h_iid AAA]
xschem unselect_all
xschem select instance AAA
xschem copy
xschem paste 600 0
set idx_paste [expr {[ninst] - 1}]
set id_paste [h_iid $idx_paste]
check {HI6b copy+paste/merge_inst birth gets a fresh id} \
  {$id_paste > 0 && $ida > 0 && $id_paste != $ida}

### HI7 — disk-undo round-trip: invalidate-on-restore (settled, same as wire
### D3). Disk undo restores by re-reading the .sch through load_inst, which
### mints a fresh id, so the originally-held id dangles (-1) while the restored
### instance carries a NEW id; the NAME (file-persisted) still resolves. The
### behavior is already decided for the whole effort, so this flips to a hard
### check at GREEN (it does not stay XFAIL like wire H7 did).
reload
xschem undo_type disk
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
set ida [h_iid AAA]
xschem undo
xschem redo
set old_resolves [h_iidx $ida]
set new_id [h_iid AAA]
check {HI7a disk undo+redo: the originally-held id is invalidated (dangles -1)} \
  {$old_resolves == -1}
check {HI7b disk undo+redo: restored instance carries a fresh id; name still resolves} \
  {$new_id > 0 && $new_id != $ida && [resolves AAA] == 1}
xschem undo_type memory

### HI8 — id survives RENAME, name does not. Stamp id(A); rename A via attribute
### edit (`setprop instance <ref> name <new>` — the space form works; the
### `name=` token form is a no-op, GUI hazard noted). The id still resolves to
### the same instance, but the OLD name no longer does and the NEW one now does.
reload
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
set ida [h_iid AAA]
xschem unselect_all
xschem setprop instance AAA name ZZZREN
set idx_after [h_iidx $ida]
check {HI8a id survives rename: instance_index id(A) still resolves} {$idx_after >= 0}
# HI8b exercises only rename/name behavior (no new id surface), so it is true
# TODAY — a plain check that characterizes the "name does not survive" half of
# the divergence; HI8a/HI8c (the "id survives" half) are the id-dependent XFAILs.
check {HI8b name does NOT survive: old name dangles, new name resolves} \
  {[resolves AAA] == 0 && [resolves ZZZREN] == 1}
check {HI8c the id resolves to the renamed instance (same slot, new name)} \
  {$idx_after >= 0 && [lindex [xschem instance_coord $idx_after] 0] eq {ZZZREN}}

### HI9 — the selection enumerator now carries the real instance id:
### {instance <idx> <col> <id>} with <id> == instance_id <idx> > 0
### (this is the slot CHI8c currently locks at -1; CHI8c flips at GREEN)
reload
xschem unselect_all
xschem instance res.sym 3000 3000 0 0 {name=AAA}
xschem unselect_all
xschem select instance AAA
set row [lindex [xschem selection] 0]
set sel_idx [lindex $row 1]
set sel_id [lindex $row 3]
check {HI9 selection instance row carries the real id (== instance_id idx > 0)} \
  {$sel_id > 0 && $sel_id == [h_iid $sel_idx] && [h_iid $sel_idx] == [h_iid AAA]}

xschem set modified 0
