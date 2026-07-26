# Characterization + handle tests for the TEXT object type (step-3, the 7th and
# last drawable type to receive a session-stable id). Committed RED first: the
# TH* tests are xcheck (XFAIL) until the C lands, then flip to check; the
# characterization test that locks today's id-slot=-1 (TC3b) flips at GREEN.
#
# Sourced by text_wrap.tcl, which provides `check`, `xcheck`, `::qo_dir`.
#
# text is a FLAT array (single index, no per-layer addressing), with the same
# lifecycle shape as wires: births at create_text (actions.c), merge_text
# (paste.c), the move-copy path (move.c) and load_text (save.c); one delete
# compaction (select.c); the clear reset; a change_elem_order swap. So the
# surface mirrors wires:
#
#   xschem text_id <index>   -> session-stable id (or -1)
#   xschem text_index <id>   -> current index (or -1)
#
# text remains PURE ANNOTATION — no pin, no connectivity, ignored by the
# netlister. This adds only identity, nothing about its role.

rename tk_messageBox _real_tk_messageBox
proc tk_messageBox {args} {return ok}
rename tk_getOpenFile _real_tk_getOpenFile
proc tk_getOpenFile {args} {return {}}
catch {rename alert_ _real_alert_}
proc alert_ {args} {return 1}

# text has no `get texts`; count via the (already-shipped) uniform enumerator
proc ntext {} {return [llength [xschem objects -type text]]}
proc h_tid {n}  { if {[catch {xschem text_id $n}  r]} {return -2}; return $r }
proc h_tidx {id} { if {[catch {xschem text_index $id} r]} {return -2}; return $r }
proc clean {} { xschem set modified 0; xschem clear force schematic }

### TC1 — create a text (BIRTH: create_text)
clean
xschem text 0 0 0 0 alpha {} 0.3 0
check {TC1 create text: count 0->1} {[ntext] == 1}

### TC2 — delete it (DEATH: delete_objects compaction)
xschem unselect_all
xschem select text 0
xschem delete
check {TC2 delete text: count 1->0} {[ntext] == 0}

### TC3 — selection row shape. col is TEXTLAYER(3); the id slot was -1 through
### steps 1-3 and is filled by this work, so TC3b was flipped from "== -1" at
### the GREEN commit (a characterization whose locked behavior changes by
### design — see also the object suite's O10 and the wire suite's S3d).
clean
xschem text 100 100 0 0 beta {} 0.3 0
xschem unselect_all
xschem select text 0
set row [lindex [xschem selection] 0]
check {TC3a selection row is {text <idx> 3 <id>} (col == TEXTLAYER 3)} \
  {[lindex $row 0] eq {text} && [lindex $row 2] == 3}
check {TC3b selection text row carries a real id (> 0, == text_id idx)} \
  {[lindex $row 3] > 0 && [lindex $row 3] == [h_tid [lindex $row 1]]}

### TH1 — created texts have positive, pairwise-distinct ids
clean
xschem text 0   0 0 0 t0 {} 0.3 0
xschem text 100 0 0 0 t1 {} 0.3 0
xschem text 200 0 0 0 t2 {} 0.3 0
set a [h_tid 0]; set b [h_tid 1]; set c [h_tid 2]
check {TH1 created texts have positive pairwise-distinct ids} \
  {$a > 0 && $b > 0 && $c > 0 && $a != $b && $a != $c && $b != $c}

### TH2 — the §2e scenario: hold a text's id, delete an EARLIER text; the index
### shifts but the id still resolves, and round-trips (proving it is the same)
clean
xschem text 0   0 0 0 t0 {} 0.3 0
xschem text 100 0 0 0 t1 {} 0.3 0
xschem text 200 0 0 0 t2 {} 0.3 0
set id2 [h_tid 2]
xschem unselect_all
xschem select text 0
xschem delete
check {TH2a id survives an earlier-text delete; index shifts 2->1} {[h_tidx $id2] == 1}
check {TH2b round-trip: text_id at the resolved index returns the held id} \
  {$id2 > 0 && [h_tid 1] == $id2}

### TH3 — delete the held text itself: the id dangles loudly (-1)
clean
xschem text 0 0 0 0 t0 {} 0.3 0
set id [h_tid 0]
xschem unselect_all
xschem select text 0
xschem delete
check {TH3 deref after own deletion returns -1} {[h_tidx $id] == -1}

### TH4 — no id reuse: create->delete->create mints a fresh id
clean
xschem text 0 0 0 0 t0 {} 0.3 0
set id4a [h_tid 0]
xschem unselect_all
xschem select text 0
xschem delete
xschem text 0 0 0 0 t0 {} 0.3 0
set id4b [h_tid 0]
check {TH4 recreated text gets a fresh id} {$id4a > 0 && $id4b > 0 && $id4a != $id4b}

### TH5 — memory-undo round-trip. Scripted graphical/text creates now push their
### own undo checkpoint (issue 0127 coord-arm fix: rect/line/arc de1b75d4, text
### residual), but TH5 keeps using the delete->undo cycle it was written around:
### delete dangles the id, undo restores the SAME id (memory undo copies whole
### structs)
clean
xschem undo_type memory
xschem text 0 0 0 0 t0 {} 0.3 0
set id5 [h_tid 0]
xschem unselect_all
xschem select text 0
xschem delete
set gone [h_tidx $id5]
xschem undo
set back [h_tidx $id5]
check {TH5a memory undo: deleted text's id dangles} {$gone == -1}
check {TH5b memory undo restores the SAME id} {$back >= 0 && [h_tid $back] == $id5}
xschem undo_type memory

### TH6 — disk-undo round-trip = invalidate-on-restore (settled D3): the held
### id dangles -1, the restored text carries a fresh id
clean
xschem undo_type disk
xschem text 0 0 0 0 t0 {} 0.3 0
set id6 [h_tid 0]
xschem unselect_all
xschem select text 0
xschem delete
xschem undo
check {TH6a disk undo+restore: the held id is invalidated (dangles -1)} \
  {[h_tidx $id6] == -1}
set id6b [h_tid 0]
check {TH6b disk undo+restore: the restored text carries a fresh id} \
  {$id6b > 0 && $id6b != $id6}
xschem undo_type memory

### TH7 — copy as BIRTH (move-copy path): the copy gets a FRESH id
clean
xschem text 0 0 0 0 t0 {} 0.3 0
set src [h_tid 0]
xschem unselect_all
xschem select text 0
xschem copy_objects 500 0
set idc [h_tid [expr {[ntext] - 1}]]
check {TH7 copy_objects birth gets a fresh id distinct from the source} \
  {$idc > 0 && $src > 0 && $idc != $src}

clean
