# Net highlight style editor — persistence scaffolding (plan slice 1).
# Pure Tcl, true headless (no X): the "seen"-marker writer, the located style-conf
# writer, and their startup-style round-trip (write -> clear -> source -> restored).
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_nh_editor_persist.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# Isolate from the real ~/.xschem: point USER_CONF_DIR at a throwaway dir.
set tmp [file join [pwd] _nhepersist_[pid]]
file delete -force $tmp
file mkdir $tmp
set ::USER_CONF_DIR $tmp

# --- 1) the harmless "seen" marker -------------------------------------------
check "S1a net_hilight_editor_seen global exists" \
  [info exists ::net_hilight_editor_seen] \
  "(=> [expr {[info exists ::net_hilight_editor_seen] ? $::net_hilight_editor_seen : {<unset>}}])"

set ::net_hilight_editor_seen 0
set rc1 [catch {write_net_hilight_editor_seen} e1]
check "S1b write_net_hilight_editor_seen runs" [expr {$rc1 == 0}] "(rc=$rc1 $e1)"
set marker $tmp/net_hilight_editor_seen
check "S1c marker file written" [file exists $marker] "(=> $marker)"
set ::net_hilight_editor_seen 0
catch {source $marker}
check "S1d sourcing marker sets seen=1" [expr {$::net_hilight_editor_seen == 1}] "(=> $::net_hilight_editor_seen)"

# --- 2) the located style-table conf -----------------------------------------
set want {{0 4 1 {} 0 0 none 0} {1 red 3 {6 4} 30 0 march_fwd 2} {2 #00ff00 2 {} 0 250 none 0}}
set ::net_hilight_style $want
set ::net_hilight_editor_seen 1
set conf $tmp/net_hilight_style
set rc2 [catch {write_net_hilight_style_conf $conf} e2]
check "S2a write_net_hilight_style_conf runs" [expr {$rc2 == 0}] "(rc=$rc2 $e2)"
check "S2b conf file written" [file exists $conf] "(=> $conf)"

# simulate a fresh session: clear both, then source the conf
set ::net_hilight_style {}
set ::net_hilight_editor_seen 0
set rc3 [catch {source $conf} e3]
check "S2c conf sources cleanly" [expr {$rc3 == 0}] "(rc=$rc3 $e3)"
check "S2d table round-trips exactly" [expr {$::net_hilight_style eq $want}] "(=> $::net_hilight_style)"
check "S2e conf restores seen=1" [expr {$::net_hilight_editor_seen == 1}] "(=> $::net_hilight_editor_seen)"

file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
