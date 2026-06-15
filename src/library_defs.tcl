# library_defs.tcl — library registry (Cadence cds.lib analog).
#
# Phase 1 of the library-manager work (see code_analysis/library_manager_design.md).
# Read-only model only: it answers "what libraries exist and where do they live",
# and changes NOTHING about reference resolution (that is Phase 2). A library is a
# NAME -> directory mapping drawn from two sources:
#
#   1. library.defs files listed in $XSCHEM_LIBRARY_DEFS (colon-separated on Unix,
#      semicolon on Windows). Each file holds lines:
#          DEFINE <name> <path>
#      with '#' comments and blank lines ignored. <path> is subject to ${VAR}
#      environment-variable expansion and a leading '~' (HOME) expansion.
#
#   2. auto-discovery: any directory on the cleaned search list ($pathlist) that
#      contains a "library.tag" file is itself a library. Its name comes from the
#      tag's "NAME <name>" line, or the directory basename if absent. This bridges
#      the legacy "just add the dir to XSCHEM_LIBRARY_PATH" workflow.
#
# Precedence: an explicit DEFINE wins over an auto-discovered tag of the same
# name; among defs files (and repeated DEFINEs) the last one read wins.

# Expand ${VAR} and a leading ~ in a defs path. Unknown ${VAR} is left verbatim.
proc library_defs_expand_path {path} {
  global env
  regsub {^~$}  $path $env(HOME)   path
  regsub {^~/} $path "$env(HOME)/" path
  while {[regexp {\$\{([A-Za-z_][A-Za-z0-9_]*)\}} $path -> var]} {
    if {[info exists env($var)]} {
      regsub -all "\\\$\\{$var\\}" $path $env($var) path
    } else {
      break
    }
  }
  return $path
}

# Parse one library.defs file, appending name->path into the dict in `defsvar`.
# A relative DEFINE path is resolved against the directory of the defs file (the
# cds.lib convention), so a committed library.defs is location-independent.
proc library_defs_parse_file {fname defsvar} {
  upvar 1 $defsvar defs
  if {[catch {open $fname r} fp]} { return }
  set base [file dirname [file normalize $fname]]
  while {[gets $fp line] >= 0} {
    set line [string trim $line]
    if {$line eq {} || [string index $line 0] eq "#"} { continue }
    if {[regexp {^DEFINE\s+(\S+)\s+(.+)$} $line -> name path]} {
      set p [library_defs_expand_path [string trim $path]]
      if {[file pathtype $p] ne "absolute"} { set p [file normalize [file join $base $p]] }
      dict set defs $name $p
    }
  }
  close $fp
}

# Read the name for a tagged directory: the "NAME <name>" line in library.tag,
# else the directory basename.
proc library_tag_name {dir} {
  set tag [file join $dir library.tag]
  if {![catch {open $tag r} fp]} {
    while {[gets $fp line] >= 0} {
      set line [string trim $line]
      if {[regexp {^NAME\s+(\S+)} $line -> name]} { close $fp; return $name }
    }
    close $fp
  }
  return [file tail $dir]
}

# The library registry as an ordered dict {name -> abs path}. Auto-discovered
# tags first, then defs files (so an explicit DEFINE overrides a tag).
proc library_registry {} {
  global XSCHEM_LIBRARY_DEFS pathlist OS
  set defs [dict create]

  # source 2 (lower precedence): tagged dirs on the search list
  if {[info exists pathlist]} {
    foreach dir $pathlist {
      if {[file exists [file join $dir library.tag]]} {
        dict set defs [library_tag_name $dir] $dir
      }
    }
  }

  # source 1 (higher precedence): the defs files
  if {[info exists XSCHEM_LIBRARY_DEFS] && $XSCHEM_LIBRARY_DEFS ne {}} {
    set sep [expr {$OS eq "Windows" ? {;} : {:}}]
    foreach f [split $XSCHEM_LIBRARY_DEFS $sep] {
      if {$f ne {} && [file exists $f]} { library_defs_parse_file $f defs }
    }
  }
  return $defs
}

# `xschem libraries` backend: sorted list of {name path} pairs.
proc library_list {} {
  set out {}
  set defs [library_registry]
  foreach name [lsort [dict keys $defs]] {
    lappend out [list $name [dict get $defs $name]]
  }
  return $out
}

# `xschem library <name>` backend: the library's path, or "" if undefined.
proc library_resolve {name} {
  set defs [library_registry]
  if {[dict exists $defs $name]} { return [dict get $defs $name] }
  return {}
}

# --- Phase 2: lib/cell/view resolution -------------------------------------
# A registered library 'libname' holds cell 'cell' whose 'view' datafile lives at
# <libpath>/<cell>/<view>/<cell>.<ext>. Returns the absolute path if that file
# exists, else "" (callers fall back to the legacy flat search).
proc cellview_resolve {libname cell view} {
  set lpath [library_resolve $libname]
  if {$lpath eq {}} { return {} }
  set ext [expr {$view eq "schematic" ? ".sch" : ".sym"}]
  set cand [file join $lpath $cell $view $cell$ext]
  if {[file exists $cand]} { return $cand }
  return {}
}

# `xschem cellview_path <lib/cell> <view>` backend. The reference is "lib/cell"
# (a trailing .sym/.sch extension, if present, is ignored — the view argument
# governs). Returns the abs datafile path or "".
proc cellview_path {ref view} {
  if {![regexp {^([^/]+)/(.+)$} $ref -> libname rest]} { return {} }
  return [cellview_resolve $libname [file rootname $rest] $view]
}

# abs_sym_path rule 2: resolve a lib-qualified reference "lib/cell[.ext]" under
# the new layout. The view is inferred from the extension (.sch -> schematic,
# else symbol). Returns "" on any miss so abs_sym_path falls through to legacy.
proc lib_qualified_abs {fname} {
  if {![regexp {^([^/]+)/(.+)$} $fname -> libname rest]} { return {} }
  if {[library_resolve $libname] eq {}} { return {} }
  switch -- [file extension $rest] {
    .sch    { set view schematic }
    default { set view symbol }
  }
  return [cellview_resolve $libname [file rootname $rest] $view]
}

# rel_sym_path rule 2: if 'symbol' is an absolute path to a SYMBOL view inside a
# registered library (<libpath>/<cell>/symbol/<cell>.sym) return the portable
# "lib/cell" reference (longest-matching library wins). Else "" and the caller
# uses the legacy prefix stripping. Schematic-view paths are left to legacy here
# (lib-qualified schematic references are handled in Phase 4 / descend).
proc lib_qualified_rel {symbol} {
  set best {}; set bestlen -1
  foreach pair [library_list] {
    set lname [lindex $pair 0]; set lpath [lindex $pair 1]
    regsub {/*$} $lpath {/} lpath
    set pl [string length $lpath]
    if {[string equal -length $pl $lpath $symbol]} {
      set rest [string range $symbol $pl end]
      if {[regexp {^([^/]+)/symbol/([^/]+)$} $rest -> cell file]} {
        if {[file rootname $file] eq $cell && $pl > $bestlen} {
          set best "$lname/$cell"; set bestlen $pl
        }
      }
    }
  }
  return $best
}
