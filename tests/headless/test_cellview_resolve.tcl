# Phase 2 (library-manager) — lib/cell/view resolver, the core.
# Teaches reference resolution the new layout WITHOUT breaking the old:
#   xschem cellview_path <lib/cell> <view>  -> abs datafile path or ""
#   abs_sym_path: rule 1 (abs/url) -> rule 2 (lib-qualified, new layout)
#                 -> rule 3 (legacy flat search, unchanged)
#   rel_sym_path: a SYMBOL-view path inside a registered library -> "lib/cell";
#                 everything else falls back to the legacy prefix stripping.
# A lib-qualified reference is "lib/cell" with the view inferred from context
# (symbol to instantiate, schematic via the .sch extension); a registered
# library resolves to <libpath>/<cell>/<view>/<cell>.<ext>.
#
# Run under X with --pipe from src/:
#   ./xschem --pipe -q --script ../tests/headless/test_cellview_resolve.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc cvp {ref view} {
  if {[catch {xschem cellview_path $ref $view} r]} { return "<no-cmd>" }
  return $r
}

# --- fixture: one new-layout library (newlib) + one legacy flat dir (flatlib) ---
set tmp [test_scratch cellview_test]
file mkdir $tmp/newlib/inv/symbol $tmp/newlib/inv/schematic $tmp/flatlib
proc touch {f} { set fp [open $f w]; puts $fp "v {xschem version=3.4.0 file_version=1.3}"; close $fp }
touch $tmp/newlib/inv/symbol/inv.sym
touch $tmp/newlib/inv/schematic/inv.sch
touch $tmp/flatlib/myflatres.sym
# alternately-named views: a view's editor type comes from the <cell>.<ext>
# file it holds, NOT from the dir name. 'sch_alt' is a schematic view (holds
# inv.sch); 'sym_alt' is a symbol view (holds inv.sym).
file mkdir $tmp/newlib/inv/sch_alt $tmp/newlib/inv/sym_alt
touch $tmp/newlib/inv/sch_alt/inv.sch
touch $tmp/newlib/inv/sym_alt/inv.sym

set SYM $tmp/newlib/inv/symbol/inv.sym
set SCH $tmp/newlib/inv/schematic/inv.sch

# register newlib via a defs file (registry-only, NOT on the search path so only
# rule 2 can find it); put flatlib on the legacy search list.
set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE newlib $tmp/newlib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs
lappend ::pathlist "$tmp/flatlib"

# --- CV1/CV2 — cellview_path resolves each view ----------------------------
check "CV1 cellview_path symbol view"    [expr {[cvp newlib/inv symbol]    eq $SYM}] "(=> [cvp newlib/inv symbol])"
check "CV2 cellview_path schematic view" [expr {[cvp newlib/inv schematic] eq $SCH}] "(=> [cvp newlib/inv schematic])"

# --- CV3 — unknown library -> "" -------------------------------------------
check "CV3 cellview_path unknown lib empty" [expr {[cvp nolib/inv symbol] eq ""}] "(=> '[cvp nolib/inv symbol]')"

# --- CV4 — abs_sym_path: lib-qualified, no extension -> SYMBOL view ----------
check "CV4 abs_sym_path lib/cell -> symbol" [expr {[abs_sym_path newlib/inv] eq $SYM}] "(=> [abs_sym_path newlib/inv])"

# --- CV5 — abs_sym_path: lib-qualified .sch -> SCHEMATIC view ----------------
check "CV5 abs_sym_path lib/cell.sch -> schematic" [expr {[abs_sym_path newlib/inv.sch] eq $SCH}] "(=> [abs_sym_path newlib/inv.sch])"

# --- CV6 — legacy flat fallback (rule 3) still resolves --------------------
check "CV6 legacy flat ref still resolves" [expr {[abs_sym_path myflatres.sym] eq "$tmp/flatlib/myflatres.sym"}] "(=> [abs_sym_path myflatres.sym])"

# --- CV7 — lib-qualified ref to an UNREGISTERED lib falls through to legacy --
# 'bogus' is not a library; abs_sym_path must not invent a new-layout path,
# it falls to the legacy current-dir fallback (string ends with the ref).
check "CV7 unregistered lib falls through to legacy" \
  [expr {[string match "*/bogus/x.sym" [abs_sym_path bogus/x.sym]]}] "(=> [abs_sym_path bogus/x.sym])"

# --- CV8 — rel_sym_path inverse: symbol-view path -> lib/cell ---------------
check "CV8 rel_sym_path symbol path -> lib/cell" [expr {[rel_sym_path $SYM] eq "newlib/inv"}] "(=> [rel_sym_path $SYM])"

# --- CV9 — round-trip stability for the symbol view ------------------------
check "CV9 abs(rel(symbol)) is stable" [expr {[abs_sym_path [rel_sym_path $SYM]] eq $SYM}] "(=> [abs_sym_path [rel_sym_path $SYM]])"

# --- CV10 — rel of a non-library path uses legacy prefix stripping ----------
# flatlib is on the search list but NOT a registered library, so its files
# relativize the old way (strip the path prefix -> bare name).
check "CV10 non-library path uses legacy rel" \
  [expr {[rel_sym_path "$tmp/flatlib/myflatres.sym"] eq "myflatres.sym"}] "(=> [rel_sym_path $tmp/flatlib/myflatres.sym])"

# --- CV11/CV12 — arbitrarily-named views resolve by the file they hold -------
# The view name is a free label; resolution must follow the <cell>.<ext> file,
# so a schematic view called 'sch_alt' opens its inv.sch (previously returned "").
check "CV11 alt-named schematic view resolves" \
  [expr {[cvp newlib/inv sch_alt] eq "$tmp/newlib/inv/sch_alt/inv.sch"}] "(=> [cvp newlib/inv sch_alt])"
check "CV12 alt-named symbol view resolves" \
  [expr {[cvp newlib/inv sym_alt] eq "$tmp/newlib/inv/sym_alt/inv.sym"}] "(=> [cvp newlib/inv sym_alt])"

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
