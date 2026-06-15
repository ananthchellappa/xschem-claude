# Phase 1 (library-manager) — library registry, read-only query API.
# Proves the two new queries and their two sources, with NO change to reference
# resolution (that is Phase 2):
#   xschem libraries        -> sorted list of {name path} pairs
#   xschem library <name>   -> the library's absolute path, or "" if undefined
# Sources:
#   1. library.defs files listed in $XSCHEM_LIBRARY_DEFS (colon-separated):
#      lines "DEFINE <name> <path>", '#' comments + blanks ignored, path
#      supports ${VAR} env expansion and a leading ~.
#   2. auto-discovery: any dir on XSCHEM_LIBRARY_PATH that contains a
#      "library.tag" file is a library; its name is the tag's "NAME <name>"
#      line, or the directory basename if absent.
#   Precedence: an explicit DEFINE wins over an auto-discovered tag of the
#   same name; among defs files, the last DEFINE of a name wins.
#
# Run under X with --pipe from src/:
#   DISPLAY=:0 ./xschem --pipe -q --script ../tests/headless/test_library_defs.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# value for library <name>, or "<no-cmd>" if the subcommand does not exist (RED)
proc lib_path {name} {
  if {[catch {xschem library $name} r]} { return "<no-cmd>" }
  return $r
}
# is {name path} present in `xschem libraries`?
proc lib_listed {name path} {
  if {[catch {xschem libraries} r]} { return 0 }
  foreach pair $r { if {[lindex $pair 0] eq $name && [lindex $pair 1] eq $path} { return 1 } }
  return 0
}

# --- fixture: a temp tree with a defs file (2 libs + 1 var-expanded) and a
#     separately tagged library reachable via XSCHEM_LIBRARY_PATH ------------
set tmp [file join [pwd] _libdefs_test_[pid]]
file delete -force $tmp
file mkdir $tmp/liba $tmp/libb $tmp/varlib $tmp/tagged $tmp/tagged_noname

set ::env(LIBDEFS_TESTVAR) $tmp
set defs [file join $tmp library.defs]
set fp [open $defs w]
puts $fp "# a comment line"
puts $fp ""
puts $fp "DEFINE liba $tmp/liba"
puts $fp "DEFINE libb $tmp/libb"
puts $fp "DEFINE varlib \${LIBDEFS_TESTVAR}/varlib"
close $fp

# tagged library with an explicit NAME
set fp [open $tmp/tagged/library.tag w]; puts $fp "NAME mytag"; close $fp
# tagged library WITHOUT a NAME -> falls back to dir basename
set fp [open $tmp/tagged_noname/library.tag w]; puts $fp "# no name here"; close $fp

# point xschem at the defs file and make the two tagged dirs discoverable.
# Auto-discovery scans the cleaned search list `pathlist`; append to it directly
# (writing XSCHEM_LIBRARY_PATH fires a GUI write-trace that is inert headless).
set ::XSCHEM_LIBRARY_DEFS $defs
lappend ::pathlist "$tmp/tagged" "$tmp/tagged_noname"

# --- LD1 — DEFINE entries resolve ------------------------------------------
check "LD1a library liba resolves" [expr {[lib_path liba] eq "$tmp/liba"}] "(=> [lib_path liba])"
check "LD1b library libb resolves" [expr {[lib_path libb] eq "$tmp/libb"}] "(=> [lib_path libb])"

# --- LD2 — undefined library yields "" -------------------------------------
check "LD2 unknown library is empty" [expr {[lib_path nosuchlib] eq ""}] "(=> '[lib_path nosuchlib]')"

# --- LD3 — ${VAR} expansion in a DEFINE path -------------------------------
check "LD3 \${VAR} expands in defs path" [expr {[lib_path varlib] eq "$tmp/varlib"}] "(=> [lib_path varlib])"

# --- LD4 — auto-discovery of a tagged dir, name from NAME line --------------
check "LD4 tagged dir discovered by NAME" [expr {[lib_path mytag] eq "$tmp/tagged"}] "(=> [lib_path mytag])"

# --- LD5 — tagged dir without NAME falls back to basename ------------------
check "LD5 tagged dir name falls back to basename" \
  [expr {[lib_path tagged_noname] eq "$tmp/tagged_noname"}] "(=> [lib_path tagged_noname])"

# --- LD6 — `xschem libraries` lists them all -------------------------------
check "LD6a libraries lists liba"  [lib_listed liba  "$tmp/liba"]  {}
check "LD6b libraries lists mytag" [lib_listed mytag "$tmp/tagged"] {}

# --- LD7 — explicit DEFINE wins over an auto-discovered tag of same name ----
# add a tag dir named "liba" on the path; the DEFINE above must still win.
file mkdir $tmp/decoy
set fp [open $tmp/decoy/library.tag w]; puts $fp "NAME liba"; close $fp
lappend ::pathlist "$tmp/decoy"
check "LD7 DEFINE beats tag of same name" [expr {[lib_path liba] eq "$tmp/liba"}] "(=> [lib_path liba])"

# --- LD8 — a RELATIVE DEFINE path resolves against the defs file's dir -------
# (cds.lib convention -> a committed library.defs is location-independent)
set fp [open $defs a]; puts $fp "DEFINE rellib ./liba"; close $fp
check "LD8 relative DEFINE path resolves to defs dir" \
  [expr {[lib_path rellib] eq [file normalize "$tmp/liba"]}] "(=> [lib_path rellib])"

# --- cleanup ---------------------------------------------------------------
file delete -force $tmp

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
