# library_defs.tcl — library registry (Cadence cds.lib analog).
#
# Phase 1 of the library-manager work (see doc/claude/code_analysis/library_manager_design.md).
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

# The library.defs files listed in $XSCHEM_LIBRARY_DEFS, in listed order ("" if
# the variable is unset/empty). These are the EXPLICIT defs files.
proc library_explicit_defs_files {} {
  global XSCHEM_LIBRARY_DEFS OS
  if {![info exists XSCHEM_LIBRARY_DEFS] || $XSCHEM_LIBRARY_DEFS eq {}} { return {} }
  set sep [expr {$OS eq "Windows" ? {;} : {:}}]
  set out {}
  foreach f [split $XSCHEM_LIBRARY_DEFS $sep] { if {$f ne {}} { lappend out $f } }
  return $out
}

# Every library.defs DISCOVERABLE on the search list `pathlist`: one sitting in a
# pathlist dir or in its parent (the cds.lib / OA convention, where the defs file
# lives alongside the per-library subdirs). Deduped by normalized path, search
# order preserved. This is why the Library Manager can find a writable
# library.defs even when XSCHEM_LIBRARY_DEFS is unset (the default).
proc library_discovered_defs_files {} {
  global pathlist
  set out {}; set seen [dict create]
  if {[info exists pathlist]} {
    foreach dir $pathlist {
      foreach cand [list [file join $dir library.defs] \
                         [file join [file dirname $dir] library.defs]] {
        if {[file isfile $cand]} {
          set n [file normalize $cand]
          if {![dict exists $seen $n]} { dict set seen $n 1; lappend out $cand }
        }
      }
    }
  }
  return $out
}

# The user's personal library.defs (Cadence personal cds.lib analog):
# $USER_CONF_DIR/library.defs (typically ~/.xschem/library.defs). Historically the
# always-available, writable registry of last resort, so creating a library worked
# out of the box even with no $XSCHEM_LIBRARY_DEFS and no library.defs on the
# search path. That fallback is now OPT-IN: it is used (for read and write) only
# when the global `library_personal_defs` is set to 1. With it off (the default)
# we never read from nor auto-create libraries in ~/.xschem — a library needs an
# explicit $XSCHEM_LIBRARY_DEFS or a writable library.defs on the search path.
# Returns "" when disabled or when USER_CONF_DIR is unset.
proc library_personal_defs_file {} {
  global USER_CONF_DIR library_personal_defs
  if {![info exists library_personal_defs] || !$library_personal_defs} { return {} }
  if {![info exists USER_CONF_DIR] || $USER_CONF_DIR eq {}} { return {} }
  return [file join $USER_CONF_DIR library.defs]
}

# The ordered set of library.defs files the write side may append to / scan:
# explicit ($XSCHEM_LIBRARY_DEFS) first, then discovered on the search path, then
# the personal one in the user config dir (created on demand). Deduped by
# normalized path, order preserved.
proc library_candidate_defs_files {} {
  set out {}; set seen [dict create]
  set all [concat [library_explicit_defs_files] [library_discovered_defs_files]]
  set personal [library_personal_defs_file]
  if {$personal ne {}} { lappend all $personal }
  foreach f $all {
    set n [file normalize $f]
    if {![dict exists $seen $n]} { dict set seen $n 1; lappend out $f }
  }
  return $out
}

# The libraries that come from a loaded library.defs file (personal +
# discovered-on-the-path + explicit $XSCHEM_LIBRARY_DEFS), as an ordered dict
# {name -> abs path}. EXCLUDES the search-path auto-discovery (tag/basename
# libraries) that library_registry layers underneath. This is the Cadence notion
# of "a library defined in a library.defs" -- `xschem get_inst_lcv` reports an
# instance only when its symbol lives in one of these. Personal is parsed first,
# then discovered-on-the-path, then explicit, so the last-parsed wins on a name
# clash (explicit DEFINE beats all). A not-yet-created personal defs is skipped.
proc library_defs_registry {} {
  set defs [dict create]
  set personal [library_personal_defs_file]
  set order {}
  if {$personal ne {}} { lappend order $personal }
  foreach f [concat $order [library_discovered_defs_files] [library_explicit_defs_files]] {
    if {[file isfile $f]} { library_defs_parse_file $f defs }
  }
  return $defs
}

# The library registry as an ordered dict {name -> abs path}. Auto-discovered
# tags/basenames first, then defs files (so an explicit DEFINE overrides a tag).
# Among defs files, discovered-on-the-path ones are parsed before explicit
# $XSCHEM_LIBRARY_DEFS ones, so an explicit DEFINE keeps highest precedence.
proc library_registry {} {
  global pathlist library_registry_defs_only
  set defs [dict create]

  # sources on the search list (lower precedence than the defs files below):
  #  - a dir carrying a library.tag is a library with the tag's NAME
  #  - any other search-path dir is ALSO a library, named by its basename, so the
  #    Library Manager shows the user's existing (flat) libraries out of the box.
  #    First occurrence wins (mirrors the search order).
  # When `library_registry_defs_only` is 1 this auto-discovery is skipped entirely,
  # so ONLY the library.defs registries below define what libraries exist (used by
  # the Cadence-style setup, where the search path is not a library source).
  if {(![info exists library_registry_defs_only] || !$library_registry_defs_only) \
       && [info exists pathlist]} {
    foreach dir $pathlist {
      if {[file exists [file join $dir library.tag]]} {
        dict set defs [library_tag_name $dir] $dir
      } else {
        set bn [file tail [file normalize $dir]]
        if {$bn ne {} && ![dict exists $defs $bn]} { dict set defs $bn $dir }
      }
    }
  }

  # the defs-file libraries (higher precedence) layered on top, so a DEFINE
  # overrides an auto-discovered tag/basename of the same name.
  dict for {name path} [library_defs_registry] { dict set defs $name $path }
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

# --- The view-type model (ONE table, five consumers) ------------------------
# Codebase doctrine (copy_form.tcl header, cellview_resolve below): a view is a
# directory, and its TYPE comes from the extension of the <cell>.<ext> datafile
# inside it, never from the directory's name. That rule was previously spelled
# out four times, each with its own private extension switch, and they had
# drifted: `.v` was type `data` to copyform, opened with `xschem load` by
# libmgr::view_handler, and resolved to the SYMBOL view by lib_qualified_abs.
# `xschem load` on a `.v` does not fail -- it skips every line and leaves an
# empty schematic whose schname is the Verilog source, so the next save writes
# an empty .sch over the source. See the §B table in
# doc/claude/specs/mixed_signal_signal_browser.md.
#
# The `text` type (.md/.txt) is the same argument applied to PROSE, and it earns
# a row for a reason beyond safety: documentation nobody can find is
# documentation nobody reads. A cell's README belongs in its view list next to
# its schematic, where the Library Manager already sends people, not in a
# directory they must go spelunking for. Spec: doc/claude/specs/text_view_type.md.
#
# These four procs are that single table. Consumers:
#   copyform::view_type    ext  -> type            (src/copy_form.tcl)
#   library_new_view       type -> ext + seed      (below)
#   libmgr::view_handler   type -> open handler    (src/library_manager.tcl)
#   lib_qualified_abs      ext  -> view            (below)
#   alt2::*                which types toggle       (src/alt2_toggle_view.tcl)

# Datafile extension (with the dot, any case) -> view type. `data` is the
# catch-all for a view holding a file this editor has no model for.
proc view_type_of_ext {ext} {
  switch -- [string tolower $ext] {
    .sch          { return schematic }
    .sym          { return symbol }
    .state        { return state }
    .v    - .sv   { return verilog }
    .va   - .vams { return veriloga }
    .md   - .markdown - .txt - .text { return text }
    default       { return data }
  }
}

# View type -> every extension that reads back as that type, most canonical
# first. "" (empty list) for a type with no creatable datafile. `ngspice_state1`
# and friends are view NAMES that carry their type; string-match them here so
# callers need no second rule.
proc view_exts_of_type {type} {
  if {[string match *_state* $type] || $type eq "state"} { return {.state} }
  switch -- $type {
    schematic { return {.sch} }
    symbol    { return {.sym} }
    verilog   { return {.v .sv} }
    veriloga  { return {.va .vams} }
    text      { return {.md .txt} }
    default   { return {} }
  }
}

# The extension library_new_view creates for a type: the canonical one.
proc view_ext_of_type {type} { return [lindex [view_exts_of_type $type] 0] }

# View type -> who opens it:
#   editor  the xschem canvas (`xschem load`)   -- schematic, symbol
#   ase     the ASE-L simulation-state window   -- state
#   text    a text editor (edit_file)           -- verilog, veriloga, text
# `data` stays `editor` deliberately: that is the status quo for the unknown
# extension, and narrowing it is a separate decision from fixing the types this
# table knows are source code or prose.
proc view_type_opener {type} {
  if {[string match *_state* $type] || $type eq "state"} { return ase }
  switch -- $type {
    verilog - veriloga - text { return text }
    default                   { return editor }
  }
}

# Canonically-named view for a type (the New-View default, and alt2's default
# chooser selection). Same name as the type for every type we create.
proc view_default_name {type} { return $type }

# --- Phase 2: lib/cell/view resolution -------------------------------------
# A registered library 'libname' holds cell 'cell' whose 'view' datafile lives at
# <libpath>/<cell>/<view>/<cell>.<ext>. Returns the absolute path if that file
# exists, else "" (callers fall back to the legacy flat search).
proc cellview_resolve {libname cell view} {
  set lpath [library_resolve $libname]
  if {$lpath eq {}} { return {} }
  set ext [expr {$view eq "schematic" ? ".sch" : ".sym"}]
  # new lib/cell/view layout. Try the exact <cell>.<ext> first (canonical
  # schematic/symbol views and reference resolution: behavior unchanged).
  set cand [file join $lpath $cell $view $cell$ext]
  if {[file exists $cand]} { return $cand }
  # The view name is just a label; a view's editor type comes from the
  # <cell>.<ext> datafile it holds, not from the name. So an arbitrarily named
  # view ('sch_alt' holding <cell>.sch) still resolves to that file.
  set vd [file join $lpath $cell $view]
  if {[file isdirectory $vd]} {
    set hits [lsort [glob -nocomplain [file join $vd $cell.*]]]
    if {[llength $hits] > 0} { return [lindex $hits 0] }
  }
  # legacy flat layout (so the Library Manager can open/place flat cells, and a
  # lib-qualified ref to a flat lib resolves to the same file rule 3 would find)
  set flat [file join $lpath $cell$ext]
  if {[file exists $flat]} { return $flat }
  return {}
}

# cellview_resolve, but the answer must actually BE a view of type $view.
#
# cellview_resolve ends in a legacy flat-layout fallback that hands back
# <libpath>/<cell>.sym for any view name other than `schematic`. That is right
# for a flat library, whose only views ARE symbol and schematic — but it means
# asking a flat library for its `verilog` view returns the SYMBOL, the same
# class of silent wrong answer lib_qualified_abs used to give for `lib/cell.v`.
# So: take cellview_resolve's answer only when its extension reads back as the
# requested type, else look for the loose sibling <libpath>/<cell>.<ext> (the
# flat-library spelling of a source view, and upstream's own convention for a
# `.v` next to its symbol). "" when neither exists.
#
# Only meaningful for a view name that is also a TYPE; an arbitrarily-labelled
# view ('sch_alt') is not type-checkable and falls through to plain resolution.
proc cellview_resolve_typed {libname cell view} {
  set exts [view_exts_of_type $view]
  set p [cellview_resolve $libname $cell $view]
  if {$exts eq {}} { return $p }
  if {$p ne {} && [view_type_of_ext [file extension $p]] eq [view_type_of_ext [lindex $exts 0]]} {
    return $p
  }
  set lpath [library_resolve $libname]
  if {$lpath eq {}} { return {} }
  foreach e $exts {
    set flat [file join $lpath $cell$e]
    if {[file isfile $flat]} { return $flat }
  }
  return {}
}

# `xschem cellview_path <lib/cell> <view>` backend. The reference is "lib/cell"
# (a trailing .sym/.sch extension, if present, is ignored — the view argument
# governs). Returns the abs datafile path or "".
proc cellview_path {ref view} {
  if {![regexp {^([^/]+)/(.+)$} $ref -> libname rest]} { return {} }
  return [cellview_resolve $libname [file rootname $rest] $view]
}

# --- Phase 7a: tree enumeration (Library -> Cell -> View) ------------------
# Cells in a registered library: immediate subdirs that hold at least one view
# directory (a subdir containing a <cell>.<ext> datafile). Sorted, deduped.
proc library_cells {libname} {
  set lpath [library_resolve $libname]
  if {$lpath eq {}} { return {} }
  set cells {}
  # new lib/cell/view layout: subdirs holding a view dir with a <cell>.<ext>
  foreach d [glob -nocomplain -type d [file join $lpath *]] {
    set cell [file tail $d]
    if {[llength [glob -nocomplain [file join $d * $cell.*]]] > 0} { lappend cells $cell }
  }
  # legacy flat layout: <cell>.sym / <cell>.sch directly in the library dir
  foreach f [glob -nocomplain [file join $lpath *.sym] [file join $lpath *.sch]] {
    lappend cells [file rootname [file tail $f]]
  }
  return [lsort -unique $cells]
}

# Views present for a cell: subdirs of <lib>/<cell> that hold a <cell>.<ext>
# datafile (general over schematic/symbol/layout/...). Sorted.
proc cell_views {libname cell} {
  set lpath [library_resolve $libname]
  if {$lpath eq {}} { return {} }
  set views {}
  # new layout: subdirs of <lib>/<cell> holding a <cell>.<ext> datafile
  foreach d [glob -nocomplain -type d [file join $lpath $cell *]] {
    if {[llength [glob -nocomplain [file join $d $cell.*]]] > 0} { lappend views [file tail $d] }
  }
  # legacy flat layout: <cell>.sym -> symbol, <cell>.sch -> schematic
  if {[file isfile [file join $lpath $cell.sym]]} { lappend views symbol }
  if {[file isfile [file join $lpath $cell.sch]]} { lappend views schematic }
  return [lsort -unique $views]
}

# abs_sym_path rule 2: resolve a lib-qualified reference "lib/cell[.ext]" under
# the new layout. The view is inferred from the extension through the one
# view-type table above: .sch -> schematic, .v -> verilog, .va -> veriloga,
# .md/.txt -> text, and EVERYTHING else -> symbol. That last clause is why `default` cannot simply be
# view_type_of_ext's answer: a bare, extension-less "lib/cell" is the common
# case and must keep meaning "the symbol to instantiate". Only extensions the
# table actually names divert. Before this, `lib/cell.v` silently resolved to
# the SYMBOL view -- a reference to the Verilog source handing back a .sym.
# Returns "" on any miss so abs_sym_path falls through to legacy.
proc lib_qualified_abs {fname} {
  if {![regexp {^([^/]+)/(.+)$} $fname -> libname rest]} { return {} }
  if {[library_resolve $libname] eq {}} { return {} }
  set cell [file rootname $rest]
  switch -- [view_type_of_ext [file extension $rest]] {
    verilog  { return [cellview_resolve_typed $libname $cell verilog] }
    veriloga { return [cellview_resolve_typed $libname $cell veriloga] }
    text     { return [cellview_resolve_typed $libname $cell text] }
    schematic { set view schematic }
    default   { set view symbol }
  }
  return [cellview_resolve $libname $cell $view]
}

# "This cell's <view> view", given any reference to one of its other views
# (§B8 of doc/claude/specs/mixed_signal_signal_browser.md). Written for a
# symbol's display text / tclcommand, where the reference at hand is @symref:
#
#   T {tcleval([read_data [cellview_sibling_path @symref verilog]])} ...
#
# replacing the hardcoded `[xschem cellview_path <lib>/<cell> verilog]` that
# nails the library name into the symbol and breaks the moment the cell is
# copied to another library.
#
# Write @symref BARE, not {@symref}: the .sym T-record parser does not handle
# nested braces and truncates the record at the inner `}` ("WARNING: missing
# fields for Text object, ignoring"). Token substitution runs before the
# tcleval, so the brace would buy nothing anyway.
#
# Resolution order:
#   1. already lib-qualified ("lib/cell[.ext]", lib registered) -> straight to
#      cellview_resolve_typed, no filesystem walk;
#   2. anything else -> abs_sym_path it, then reverse-map the absolute path to
#      its {lib cell} with schematic_cellview and ask that cell;
#   3. flat/unregistered layout -> the sibling file next to it, <dir>/<cell><ext>,
#      which is exactly upstream's loose-file convention (abs_sym_path counter.v).
# Returns "" when nothing resolves, so a caller can report rather than paste a
# broken path into a netlist.
proc cellview_sibling_path {ref view} {
  if {$ref eq {}} { return {} }
  if {[regexp {^([^/]+)/([^/]+)$} $ref -> libname rest] &&
      [library_resolve $libname] ne {}} {
    return [cellview_resolve_typed $libname [file rootname $rest] $view]
  }
  set abs [abs_sym_path $ref]
  if {$abs eq {}} { return {} }
  set cv [schematic_cellview $abs]
  if {$cv ne {}} {
    lassign $cv lib cell _v layout
    if {$layout eq "nested"} { return [cellview_resolve_typed $lib $cell $view] }
  }
  # unregistered / loose-file layout: the sibling <dir>/<cell>.<ext> lying next
  # to the reference itself, which is upstream's convention for a `.v` beside
  # its symbol (`abs_sym_path counter.v`).
  foreach ext [view_exts_of_type $view] {
    set sib [file rootname $abs]$ext
    if {[file isfile $sib]} { return $sib }
  }
  return {}
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

# Reverse-resolve an absolute schematic/symbol file path to its library cell view.
# Returns {lib cell view layout} (layout = nested|flat), or {} if the path is not
# under any registered library. The longest matching library root wins (so a library
# nested inside another resolves to the inner one). Pure path/string work -- used by
# the library-aware "Make symbol from schematic" to decide where the symbol view
# goes. doc/claude/specs/create_symbol_view.md
proc schematic_cellview {abspath} {
  set abspath [file normalize $abspath]
  set best {}; set bestlen -1
  foreach pair [library_list] {
    set lname [lindex $pair 0]
    set lp [file normalize [lindex $pair 1]]/
    set pl [string length $lp]
    if {$pl <= $bestlen} { continue }
    if {![string equal -length $pl $lp $abspath/]} { continue }
    set comps [file split [string range $abspath $pl end]]
    set n [llength $comps]
    set root [file rootname [lindex $comps end]]
    if {$n == 3 && $root eq [lindex $comps 0]} {
      # nested: <cell>/<view>/<cell>.ext
      set best [list $lname [lindex $comps 0] [lindex $comps 1] nested]; set bestlen $pl
    } elseif {$n == 1} {
      # flat: <cell>.ext directly under the library root (no view dir)
      set best [list $lname $root {} flat]; set bestlen $pl
    }
  }
  return $best
}

# `xschem get_inst_lcv` backend: reverse-map a selected instance's symbol
# reference to its Cadence {library cell view} list. The reference is resolved to
# an absolute .sym path (abs_sym_path), then matched against the libraries
# defined in a loaded library.defs (library_defs_registry -- NOT the search-path
# auto-discovered ones). Only the Cadence layout is accepted: the path under the
# library must be exactly <cell>/<view>/<cell>.sym (the view dir holds a
# <cell>.sym; the view name is arbitrary, the type is always symbol). The
# longest-matching library wins. Returns {} (and the C caller errors) if the
# symbol is not in such a library -- e.g. a legacy flat <cell>.sym, or a library
# only present via the search path with no library.defs entry.
proc library_inst_lcv {ref} {
  set abspath [abs_sym_path $ref]
  if {$abspath eq {}} { return {} }
  set best {}; set bestlen -1
  dict for {lname lpath} [library_defs_registry] {
    regsub {/*$} $lpath {/} lpath
    set pl [string length $lpath]
    if {![string equal -length $pl $lpath $abspath]} { continue }
    set parts [file split [string range $abspath $pl end]]
    if {[llength $parts] != 3} { continue }
    lassign $parts cell view file
    if {[file rootname $file] ne $cell} { continue }
    if {[file extension $file] ne ".sym"} { continue }
    if {$pl > $bestlen} { set best [list $lname $cell $view]; set bestlen $pl }
  }
  return $best
}

# --- Phase 7b: mutation backend (Library Manager right-click context menu) ---
# Filesystem operations behind copy / rename / delete / new on the Library ->
# Cell -> View tree. Model (mirrors the read side above):
#   library = directory; cell = subdir holding view dirs (nested layout) OR
#   <cell>.{sym,sch} files directly in the library dir (legacy flat layout);
#   view   = <cell>/<view>/<cell>.<ext> (nested) or the flat file itself
#            (symbol -> .sym, schematic -> .sch).
# Each proc throws a Tcl error with a human-readable message on failure and
# returns "" on success, so GUI callers can `catch` and show the message.
# DELETES ARE RECOVERABLE: the target moves to <libpath>/.xschem_trash/.

# Classify a cell: "" (no such cell) | "nested" | "flat". Nested wins if both.
proc library_cell_layout {lib cell} {
  set lp [library_resolve $lib]
  if {$lp eq {}} { return {} }
  set cd [file join $lp $cell]
  if {[file isdirectory $cd] &&
      [llength [glob -nocomplain [file join $cd * $cell.*]]] > 0} { return nested }
  if {[file isfile [file join $lp $cell.sym]] ||
      [file isfile [file join $lp $cell.sch]]} { return flat }
  return {}
}

# The library's recoverable-delete directory.
proc library_trash_dir {libpath} { return [file join $libpath .xschem_trash] }

# Move $src (an absolute file or dir inside the library) into the library trash,
# uniquifying the basename so repeated deletes never collide. Returns the dest.
proc library_trash_move {libpath src} {
  set td [library_trash_dir $libpath]
  file mkdir $td
  set dst [file join $td [file tail $src]]
  set n 1
  while {[file exists $dst]} { set dst [file join $td "[file tail $src].$n"]; incr n }
  file rename -- $src $dst
  return $dst
}

# Delete a whole cell (all its views) -> trash.
proc library_delete_cell {lib cell} {
  set lp [library_resolve $lib]
  if {$lp eq {}} { error "no such library: $lib" }
  switch -- [library_cell_layout $lib $cell] {
    nested { library_trash_move $lp [file join $lp $cell] }
    flat {
      foreach ext {sym sch} {
        set f [file join $lp $cell.$ext]
        if {[file isfile $f]} { library_trash_move $lp $f }
      }
    }
    default { error "no such cell: $lib/$cell" }
  }
  return ""
}

# Delete a single view of a cell -> trash. The cell (and its other views) stays.
proc library_delete_view {lib cell view} {
  set lp [library_resolve $lib]
  if {$lp eq {}} { error "no such library: $lib" }
  switch -- [library_cell_layout $lib $cell] {
    nested {
      set vd [file join $lp $cell $view]
      if {![file isdirectory $vd]} { error "no $view view for $lib/$cell" }
      library_trash_move $lp $vd
    }
    flat {
      set f [file join $lp $cell.[expr {$view eq "schematic" ? "sch" : "sym"}]]
      if {![file isfile $f]} { error "no $view view for $lib/$cell" }
      library_trash_move $lp $f
    }
    default { error "no such cell: $lib/$cell" }
  }
  return ""
}

# The layout STYLE a library uses for newly created/copied cells: "nested"
# (Cadence-style lib/cell/view) or "flat" (<cell>.{sym,sch} in the library dir).
# Resolution, highest precedence first:
#   1. an explicit "LAYOUT nested|flat" line in the library's library.tag;
#   2. inferred from existing cells — any nested cell => nested, else any flat
#      cell => flat (so a library keeps using whatever style it already holds);
#   3. for an empty/unknown library, the global $library_default_layout (default
#      "nested", the tool's native style — library_new_cell always creates nested).
proc library_layout_style {lib} {
  global library_default_layout
  set lp [library_resolve $lib]
  if {$lp ne {}} {
    set tag [file join $lp library.tag]
    if {![catch {open $tag r} fp]} {
      while {[gets $fp line] >= 0} {
        if {[regexp {^\s*LAYOUT\s+(nested|flat)\y} [string trim $line] -> st]} { close $fp; return $st }
      }
      close $fp
    }
    set sawflat 0
    foreach cell [library_cells $lib] {
      switch -- [library_cell_layout $lib $cell] {
        nested { return nested }
        flat   { set sawflat 1 }
      }
    }
    if {$sawflat} { return flat }
  }
  if {[info exists library_default_layout] && $library_default_layout eq "flat"} { return flat }
  return nested
}

# Copy a cell (optionally into another library). The destination must not exist.
# The cell is written in the DESTINATION library's layout style (see
# library_layout_style), converting between flat and nested as needed: a flat
# source copied into a nested library becomes <dstcell>/<view>/<dstcell>.<ext>
# (.sch->schematic, .sym->symbol), and a nested source copied into a flat library
# is flattened to <dstcell>.<ext>. The cell datafile is renamed to <dstcell>.
proc library_copy_cell {srclib srccell dstlib dstcell} {
  set slp [library_resolve $srclib]
  set dlp [library_resolve $dstlib]
  if {$slp eq {}} { error "no such library: $srclib" }
  if {$dlp eq {}} { error "no such library: $dstlib" }
  set layout [library_cell_layout $srclib $srccell]
  if {$layout eq {}} { error "no such cell: $srclib/$srccell" }
  if {[library_cell_layout $dstlib $dstcell] ne {}} { error "cell already exists: $dstlib/$dstcell" }
  set style [library_layout_style $dstlib]
  if {$style eq "nested"} {
    set dd [file join $dlp $dstcell]
    file mkdir $dd
    if {$layout eq "nested"} {
      # nested -> nested: preserve the view dirs, rename each <srccell>.<ext>
      set sd [file join $slp $srccell]
      foreach vd [glob -nocomplain -type d [file join $sd *]] {
        set odir [file join $dd [file tail $vd]]
        file mkdir $odir
        foreach f [glob -nocomplain [file join $vd *]] {
          set tail [file tail $f]
          if {[file rootname $tail] eq $srccell} { set tail "$dstcell[file extension $tail]" }
          file copy -- $f [file join $odir $tail]
        }
      }
    } else {
      # flat -> nested: map each datafile to a view dir by extension
      foreach {ext view} {sch schematic sym symbol} {
        set f [file join $slp $srccell.$ext]
        if {[file isfile $f]} {
          set odir [file join $dd $view]
          file mkdir $odir
          file copy -- $f [file join $odir $dstcell.$ext]
        }
      }
    }
  } else {
    if {$layout eq "flat"} {
      # flat -> flat: copy the datafiles, renaming to <dstcell>
      foreach ext {sym sch} {
        set f [file join $slp $srccell.$ext]
        if {[file isfile $f]} { file copy -- $f [file join $dlp $dstcell.$ext] }
      }
    } else {
      # nested -> flat: flatten each view's <srccell>.<ext> to <dstcell>.<ext>
      foreach f [glob -nocomplain [file join $slp $srccell * $srccell.*]] {
        file copy -- $f [file join $dlp "$dstcell[file extension $f]"]
      }
    }
  }
  return ""
}

# Rename a cell. Same library => in-place rename (atomic where possible);
# different library => move (copy into dest, then trash the source). The
# destination must not already exist.
proc library_rename_cell {srclib srccell dstlib dstcell} {
  set slp [library_resolve $srclib]
  if {$slp eq {}} { error "no such library: $srclib" }
  if {[library_cell_layout $srclib $srccell] eq {}} { error "no such cell: $srclib/$srccell" }
  if {$srclib eq $dstlib && $srccell eq $dstcell} { return "" }
  if {[library_cell_layout $dstlib $dstcell] ne {}} { error "cell already exists: $dstlib/$dstcell" }
  if {$srclib ne $dstlib} {
    library_copy_cell $srclib $srccell $dstlib $dstcell
    library_delete_cell $srclib $srccell
    return ""
  }
  switch -- [library_cell_layout $srclib $srccell] {
    nested {
      set dd [file join $slp $dstcell]
      file rename -- [file join $slp $srccell] $dd
      foreach vd [glob -nocomplain -type d [file join $dd *]] {
        foreach f [glob -nocomplain [file join $vd $srccell.*]] {
          file rename -- $f [file join $vd "$dstcell[file extension $f]"]
        }
      }
    }
    flat {
      foreach ext {sym sch} {
        set f [file join $slp $srccell.$ext]
        if {[file isfile $f]} { file rename -- $f [file join $slp $dstcell.$ext] }
      }
    }
  }
  return ""
}

# Minimal but valid empty .sch/.sym body (the 6-record header). file_version is
# kept in step with XSCHEM_FILE_VERSION in xschem.h (informational on load).
proc library_write_empty_cellfile {path} {
  set ver "unknown"
  catch {set ver [xschem get version]}
  set fp [open $path w]
  puts $fp "v {xschem version=$ver file_version=1.3}"
  foreach r {G K V S E} { puts $fp "$r \{\}" }
  close $fp
}

# Write a plain-text view datafile (a source-code seed). Unlike write_data in
# xschem.tcl this lets the open error propagate, so the do_* callers' `catch`
# reports "permission denied" instead of silently creating nothing.
proc library_write_textfile {path body} {
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}

# Create a new, empty cell with one view (schematic by default). The argument is
# a view NAME; the datafile extension comes from the shared table when the name
# is also a known type, else the historical schematic-or-symbol rule. Without
# this a cell created with view `verilog` got an empty <cell>.sym inside it.
proc library_new_cell {lib cell {view schematic}} {
  set lp [library_resolve $lib]
  if {$lp eq {}} { error "no such library: $lib" }
  if {$cell eq {}} { error "cell name required" }
  if {[library_cell_layout $lib $cell] ne {}} { error "cell already exists: $lib/$cell" }
  set ext [view_ext_of_type $view]
  if {$ext eq {} || $ext eq {.state}} { set ext [expr {$view eq "schematic" ? ".sch" : ".sym"}] }
  set vd [file join $lp $cell $view]
  file mkdir $vd
  set df [file join $vd "$cell$ext"]
  # A brand-new cell has no symbol view yet, so a source seed is portless by
  # construction — the module header is still valid and states that plainly.
  switch -- [view_type_of_ext $ext] {
    verilog  { library_write_textfile $df [library_verilog_seed  $cell {}] }
    veriloga { library_write_textfile $df [library_veriloga_seed $cell {}] }
    default  { library_write_empty_cellfile $df }
  }
  return ""
}

# The first library.defs we can append to: explicit ($XSCHEM_LIBRARY_DEFS) first,
# then any discovered on the search path. A candidate qualifies if it exists and
# is writable, or (for an explicit entry) is absent with a writable parent dir so
# it can be created. Returns "" if none qualifies.
proc library_primary_defs_file {} {
  foreach f [library_candidate_defs_files] {
    if {[file isfile $f]} { if {[file writable $f]} { return $f }; continue }
    if {[file isdirectory [file dirname $f]] && [file writable [file dirname $f]]} { return $f }
  }
  return {}
}

# Create and register a new library: make $path (default <defs-dir>/<name>) and
# append "DEFINE <name> <path>" to the primary defs file (relative to the defs
# dir when possible, per the cds.lib convention).
proc library_new {name {path {}}} {
  if {$name eq {}} { error "library name required" }
  if {[library_resolve $name] ne {}} { error "library already exists: $name" }
  set defs [library_primary_defs_file]
  if {$defs eq {}} { error "no writable library.defs (set XSCHEM_LIBRARY_DEFS)" }
  set base [file dirname [file normalize $defs]]
  if {$path eq {}} { set path [file join $base $name] }
  file mkdir $path
  set np [file normalize $path]
  set store $np
  if {[string equal -length [string length "$base/"] "$base/" $np]} {
    set store [string range $np [string length "$base/"] end]
  }
  set fp [open $defs a]; puts $fp "DEFINE $name $store"; close $fp
  return ""
}

# Remove a library's DEFINE line(s) from the defs file(s) (files on disk are
# left untouched). Errors if the library is only auto-discovered (no DEFINE to
# remove — it comes from library.tag or a bare search-path dir).
proc library_unregister {name} {
  set removed 0
  foreach f [library_candidate_defs_files] {
    if {![file isfile $f]} { continue }
    set fp [open $f r]; set lines [split [read $fp] \n]; close $fp
    set out {}; set hit 0
    foreach line $lines {
      if {[regexp {^\s*DEFINE\s+(\S+)\s} $line -> dn] && $dn eq $name} { set hit 1; continue }
      lappend out $line
    }
    if {$hit} {
      if {![file writable $f]} { error "library.defs not writable: $f" }
      set fp [open $f w]; puts -nonewline $fp [join $out \n]; close $fp
      set removed 1
    }
  }
  if {!$removed} { error "library is auto-discovered (no DEFINE to remove): $name" }
  return ""
}

# --- view-level operations (nested lib/cell/view layout only) ----------------
# A view is a <cell>/<view>/ dir holding a <cell>.<ext> datafile; its editor
# type is that file's extension, so views are freely named. Flat cells have no
# separate per-view files, so these ops reject them (rename/copy the cell, or
# convert it, instead).

# The nested view dir <lib>/<cell>/<view> if it exists and holds <cell>.<ext>,
# else "".
proc library_view_dir {lib cell view} {
  set lp [library_resolve $lib]
  if {$lp eq {}} { return {} }
  set vd [file join $lp $cell $view]
  if {[file isdirectory $vd] && [llength [glob -nocomplain [file join $vd $cell.*]]] > 0} { return $vd }
  return {}
}

# Rename a view (relabel the dir). The cell's <cell>.<ext> datafile keeps the
# cell name; only the view label changes.
proc library_rename_view {lib cell oldview newview} {
  set lp [library_resolve $lib]
  if {$lp eq {}} { error "no such library: $lib" }
  if {$newview eq {}} { error "view name required" }
  if {$oldview eq $newview} { return "" }
  set vd [library_view_dir $lib $cell $oldview]
  if {$vd eq {}} { error "no nested view '$oldview' for $lib/$cell (flat cell has no separate view files)" }
  set dst [file join $lp $cell $newview]
  if {[file exists $dst]} { error "view already exists: $lib/$cell/$newview" }
  file rename -- $vd $dst
  return ""
}

# Copy a view to a new view name, optionally under another cell/library. When
# the destination cell differs, the <srccell>.<ext> datafile is renamed to the
# destination cell name. The destination view must not exist.
proc library_copy_view {sl sc sv dl dc dv} {
  set slp [library_resolve $sl]
  set dlp [library_resolve $dl]
  if {$slp eq {}} { error "no such library: $sl" }
  if {$dlp eq {}} { error "no such library: $dl" }
  if {$dv eq {}} { error "view name required" }
  set svd [library_view_dir $sl $sc $sv]
  if {$svd eq {}} { error "no nested view '$sv' for $sl/$sc (flat cell has no separate view files)" }
  set dvd [file join $dlp $dc $dv]
  if {[file exists $dvd]} { error "view already exists: $dl/$dc/$dv" }
  file mkdir $dvd
  foreach f [glob -nocomplain [file join $svd *]] {
    set tail [file tail $f]
    if {[file rootname $tail] eq $sc} { set tail "$dc[file extension $tail]" }
    file copy -- $f [file join $dvd $tail]
  }
  return ""
}

# --- pin list + source-view seeds (§B4) -------------------------------------
# A cell's symbol pins as a list of {name dir} pairs, in symbol-file order.
# Read by TEXT from the .sym rather than through `xschem load`, deliberately:
# this runs from the Library Manager while the user has a schematic open, and
# loading the symbol into the live context to count its pins would clobber it.
# Same B-record regexp modify_symbol_pins uses (src/xschem.tcl). Returns {} when
# the cell has no symbol view.
proc library_symbol_pins {lib cell} {
  set sym [cellview_resolve $lib $cell symbol]
  if {$sym eq {} || ![file isfile $sym]} { return {} }
  if {[catch {open $sym r} fp]} { return {} }
  set txt [read $fp]; close $fp
  set out {}
  foreach ln [split $txt \n] {
    if {![regexp {^B +[0-9]+ +[-0-9.]+ +[-0-9.]+ +[-0-9.]+ +[-0-9.]+ +\{(.*)\}} $ln -> props]} continue
    if {![regexp {name=([^ \}]+)} $props -> pname]} continue
    if {![regexp {dir=([^ \}]+)}  $props -> pdir]}  continue
    lappend out [list $pname $pdir]
  }
  return $out
}

# Split an xschem pin name into {basename range}, where range is a Verilog
# vector range ("[3:0]") or "". xschem spells a bus pin `count[3..0]`; a `:`
# spelling is accepted too so a hand-edited symbol still seeds correctly.
proc library_pin_split_bus {pname} {
  if {[regexp {^(.*)\[([0-9]+)(?:\.\.|:)([0-9]+)\]$} $pname -> base msb lsb]} {
    return [list $base "\[$msb:$lsb\]"]
  }
  return [list $pname {}]
}

# Pins grouped by direction, preserving symbol-file order within each group:
# {inputs outputs inouts}. Anything not in/out/inout is treated as an inout.
proc library_pins_by_dir {pins} {
  set in {}; set out {}; set io {}
  foreach p $pins {
    lassign $p pname pdir
    switch -- $pdir {
      in   { lappend in  $pname }
      out  { lappend out $pname }
      default { lappend io $pname }
    }
  }
  return [list $in $out $io]
}

# Seed body for a new `verilog` view. Port order is inputs, then outputs, then
# inouts -- the order a d_cosim `format` string declares its bracket groups
# (`format="@name [ @@clk ] [ @@count[3..0] ] @model"`), so a seeded module
# matches the symbol's wire protocol without hand-reordering.
proc library_verilog_seed {cell pins} {
  lassign [library_pins_by_dir $pins] ins outs ios
  set decl {}
  foreach {kw group} [list input $ins output $outs inout $ios] {
    foreach pname $group {
      lassign [library_pin_split_bus $pname] base range
      lappend decl [string trimright "    $kw $range"]\ $base
    }
  }
  set body "\`timescale 1ps/1ps\n\n"
  append body "// $cell — verilog view.\n//\n"
  if {[llength $pins]} {
    append body "// PORTS ARE FIXED BY THE SYMBOL VIEW ($cell/symbol/$cell.sym), from which\n"
    append body "// this header was seeded: inputs, then outputs, then inouts. Adding or\n"
    append body "// reordering a PORT here means editing the symbol too. Adding an INTERNAL\n"
    append body "// signal does not -- and internals are exactly what the co-simulation VCD\n"
    append body "// exists to expose (doc/claude/specs/mixed_signal_signal_browser.md).\n"
  } else {
    append body "// No symbol view found for this cell, so no ports could be seeded. Declare\n"
    append body "// them here and in the symbol; the two must agree.\n"
  }
  append body "\n"
  if {[llength $decl]} {
    append body "module $cell (\n[join $decl ",\n"]\n);\n\n"
  } else {
    append body "module $cell ();\n\n"
  }
  append body "endmodule\n"
  return $body
}

# Seed body for a new `veriloga` view. Verilog-A is ANALOG: its nodes reach the
# ngspice raw file directly through OSDI, so unlike a d_cosim `verilog` block it
# needs no VCD path to be plottable (§B9 of the mixed-signal spec). Ports are
# declared the Verilog-A way -- name list in the header, direction and
# discipline as separate statements.
proc library_veriloga_seed {cell pins} {
  lassign [library_pins_by_dir $pins] ins outs ios
  set names {}; set decl {}; set disc {}
  foreach {kw group} [list input $ins output $outs inout $ios] {
    foreach pname $group {
      lassign [library_pin_split_bus $pname] base range
      lappend names $base
      lappend decl [string trimright "  $kw $range"]\ $base\;
      lappend disc [string trimright "  electrical $range"]\ $base\;
    }
  }
  set body "\`include \"constants.vams\"\n\`include \"disciplines.vams\"\n\n"
  append body "// $cell — veriloga view.\n//\n"
  if {[llength $pins]} {
    append body "// Ports seeded from the symbol view ($cell/symbol/$cell.sym).\n"
  } else {
    append body "// No symbol view found for this cell, so no ports could be seeded.\n"
  }
  append body "\nmodule ${cell}([join $names {, }]);\n"
  if {[llength $decl]} { append body "[join $decl \n]\n[join $disc \n]\n" }
  append body "\n  analog begin\n  end\nendmodule\n"
  return $body
}

# Seed body for a new `text` view — the cell's documentation, opened from the
# Library Manager like any other view (doc/claude/specs/text_view_type.md).
# Markdown, because that is what the rest of this repo's prose is written in and
# it stays readable in a plain editor. Seeded with the heading and the view
# inventory rather than left empty: a blank file gets closed again, and the one
# thing the author always has to hand is what the cell already contains.
proc library_text_seed {lib cell view} {
  set body "# $cell\n\n"
  append body "<!-- $lib/$cell, `$view` view. Opened by the Library Manager in\n"
  append body "     the configured text editor; no xschem window is involved. -->\n\n"
  set views {}
  catch {set views [cell_views $lib $cell]}
  set others {}
  foreach v $views { if {$v ne $view} { lappend others $v } }
  if {[llength $others]} {
    append body "Views: [join $others {, }].\n\n"
  }
  append body "## What this cell is\n\n\n## How to use it\n\n"
  return $body
}

# Create a new empty view of a given editor type (schematic|symbol|verilog|
# veriloga|text|ngspice_state*) under a free name. The cell must already exist; the
# view must not. The type -> extension mapping is view_ext_of_type's, the one
# table (it used to be an inline `$type eq "symbol" ? "sym" : "sch"`, so every
# type that was not `symbol` or a state got a .sch datafile -- a `verilog` view
# was created as an empty SCHEMATIC). An ngspice_state* type seeds an ASE
# simulation-state view (doc/claude/specs/ase_l.md); verilog/veriloga seed a
# module header from the cell's symbol pins (§B4), because an empty .v is
# useless and a wrong-ported one is worse; `text` seeds a Markdown skeleton
# listing the cell's other views (doc/claude/specs/text_view_type.md).
proc library_new_view {lib cell view {type schematic}} {
  set lp [library_resolve $lib]
  if {$lp eq {}} { error "no such library: $lib" }
  if {$view eq {}} { error "view name required" }
  if {[library_cell_layout $lib $cell] eq {}} { error "no such cell: $lib/$cell" }
  set ext [view_ext_of_type $type]
  if {$ext eq {}} { error "unknown view type: $type" }
  set vd [file join $lp $cell $view]
  if {[file exists $vd]} { error "view already exists: $lib/$cell/$view" }
  file mkdir $vd
  set df [file join $vd "$cell$ext"]
  switch -- [view_type_of_ext $ext] {
    state {
      # The datafile is a serialized ase state dict, seeded VALID (never an
      # empty file — ase::state_load must not need an empty-file special case),
      # with design pointing at the cell's schematic view. If that view only
      # arrives later, ase::netlist errors cleanly — acceptable.
      set st [ase::state_default]
      dict set st design [list lib $lib cell $cell view schematic]
      ase::state_save $df $st
    }
    verilog {
      library_write_textfile $df [library_verilog_seed $cell [library_symbol_pins $lib $cell]]
    }
    veriloga {
      library_write_textfile $df [library_veriloga_seed $cell [library_symbol_pins $lib $cell]]
    }
    text {
      library_write_textfile $df [library_text_seed $lib $cell $view]
    }
    default {
      library_write_empty_cellfile $df
    }
  }
  return ""
}
