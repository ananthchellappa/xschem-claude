#
#  File: pin_name_text.tcl
#
#  Headless regression for Cadence-style pin-owned name text (Option B), phases P0-P1:
#  on load, materialize an editable pin-name "view" (a transient xText) for every OWNED
#  + SHOWN symbol pin; never persist those views on save (S3); regenerate on load (S1).
#  See doc/claude/specs/cadence_pin_name_text.md
#
#  Run UNDER xschem:
#      cd tests
#      ../src/xschem --nogui --pipe -q --script pin_name_text.tcl
#

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

set wd [file normalize ./pin_name_text_work]
file delete -force $wd
file mkdir $wd

# write a minimal symbol file: standard header + caller-supplied body
proc write_sym {path body} {
  set fp [open $path w]
  puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
  puts $fp "G {}"
  puts $fp "K {type=subcircuit}"
  puts $fp "V {}"
  puts $fp "S {}"
  puts $fp "E {}"
  puts -nonewline $fp $body
  close $fp
}

# count lines in a file matching a glob pattern
proc count_lines {path pat} {
  set n 0
  set fp [open $path r]
  while {[gets $fp line] >= 0} { if {[string match $pat $line]} { incr n } }
  close $fp
  return $n
}

# ---------------------------------------------------------------------------
# 1. OWNED + SHOWN pin (show_pinname=true), NO standalone T in the file.
#    On load, exactly one synthesized name view must appear (S1).
# ---------------------------------------------------------------------------
set f1 $wd/owned.sym
write_sym $f1 "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=true name_dx=20 name_dy=-5 name_size=0.2}\n"
xschem load $f1
check "owned pin: one PINLAYER rect"     [xschem get rects 5] 1
check "owned pin: one synth view"        [xschem get texts]   1

# ---------------------------------------------------------------------------
# 2. Save must NOT persist the view (S3): saved file has 0 T records, keeps the pin.
# ---------------------------------------------------------------------------
set o1 $wd/owned_out.sym
xschem saveas $o1 symbol
check "save: view not persisted (0 T)"   [count_lines $o1 "T *"]   0
check "save: pin B record kept"          [count_lines $o1 "B 5 *"] 1
check "save: show_pinname token kept"    [expr {[count_lines $o1 "*show_pinname=true*"] >= 1}] 1

# ---------------------------------------------------------------------------
# 3. Round-trip: reload the saved file (view re-synthesized, S1) and save again ->
#    byte-identical, proving views never leak and load is deterministic.
# ---------------------------------------------------------------------------
xschem load $o1
check "reload: one synth view again"     [xschem get texts] 1
set o2 $wd/owned_out2.sym
xschem saveas $o2 symbol
set same [expr {![catch {exec cmp -s $o1 $o2}]}]
check "round-trip byte-identical"        $same 1

# ---------------------------------------------------------------------------
# 4. Negative: a LEGACY pin (no show_pinname token) must NOT get a view.
# ---------------------------------------------------------------------------
set f2 $wd/legacy.sym
write_sym $f2 "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n"
xschem load $f2
check "legacy pin: no synth view"        [xschem get texts] 0

# ---------------------------------------------------------------------------
# 5. Negative: OWNED but HIDDEN (show_pinname=false) must NOT get a view.
# ---------------------------------------------------------------------------
set f3 $wd/hidden.sym
write_sym $f3 "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=false name_size=0.2}\n"
xschem load $f3
check "hidden pin: no synth view"        [xschem get texts] 0

# ---------------------------------------------------------------------------
# 6. Mixed: an owned pin + a legacy pin + a real stray T. Only the owned pin gets a
#    view; the stray T persists on save, the view does not.
# ---------------------------------------------------------------------------
set f4 $wd/mixed.sym
write_sym $f4 "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=true name_size=0.2}\nB 5 -2.5 17.5 2.5 22.5 {name=B dir=in}\nT {hello} 30 30 0 0 0.2 0.2 {}\n"
xschem load $f4
# in memory: stray "hello" (1) + synth view for A (1) = 2
check "mixed: stray T + one synth view"  [xschem get texts] 2
set o4 $wd/mixed_out.sym
xschem saveas $o4 symbol
check "mixed save: only stray T persists" [count_lines $o4 "T *"]   1
check "mixed save: two pins kept"         [count_lines $o4 "B 5 *"] 2

file delete -force $wd

if {$nfail == 0} { puts "ALL PASS (pin_name_text)" } else { puts "$nfail FAILURES (pin_name_text)" }
