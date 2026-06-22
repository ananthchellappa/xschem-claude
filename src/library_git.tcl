# library_git.tcl — git revision-control backend for the Library Manager.
# specs/library_git.md (Phase 1). Pure Tcl `exec git` wrappers; the C engine and
# the .sch/.sym record format are untouched (no rebuild needed beyond installing
# this file). Mirrors library_defs.tcl conventions: throw a Tcl error with a
# human-readable message on failure, return "" on success, so GUI callers `catch`.
#
# THE CENTRAL INVARIANT (spec §2). A "library" is a DIRECTORY with no fixed
# relationship to a git repo. Every action resolves, from the target's ABSOLUTE
# path, two values and never special-cases standalone-vs-subdir:
#
#   root     = git -C <abspath> rev-parse --show-toplevel   ("" => not under git)
#   pathspec = <abspath> made relative to root              (lib_git_relpath)
#
# then runs `git -C <root> … -- <pathspec>`. Because root is derived from the path
# itself, a library that IS the repo root and a library buried deep in a bigger
# repo collapse to the same two values; the `-- <pathspec>` scoping guarantees an
# operation on one library never touches a sibling library in the same repo.

# Per-path cache for the (relatively expensive) toplevel lookup. Reset when the
# registry or working set changes meaningfully.
array set ::lib_git_root_cache {}
proc lib_git_reset_cache {} { array unset ::lib_git_root_cache; array set ::lib_git_root_cache {} }

# A directory we can hand to `git -C`: the path itself if it is a dir, else its
# parent (so a cell/view DATAFILE path resolves to its enclosing repo too).
proc lib_git__dir {abspath} {
  if {[file isdirectory $abspath]} { return $abspath }
  return [file dirname $abspath]
}

# Capability flags: {git ?lfs?}. `git` present iff a git is on PATH; `lfs` present
# iff `git lfs` is installed (the per-repo lock-capability check happens later).
proc lib_git_available {} {
  set caps {}
  if {![catch {exec git --version}]} { lappend caps git }
  if {![catch {exec git lfs version}]} { lappend caps lfs }
  return $caps
}

# Repo toplevel for <abspath>, or "" if it is not under any git repo (case E).
# Derived FROM the path, so it is correct whether the root equals the library dir
# (case A) or sits far above it (cases B–D). Cached per normalized path.
proc lib_git_root {abspath} {
  set key [file normalize $abspath]
  if {[info exists ::lib_git_root_cache($key)]} { return $::lib_git_root_cache($key) }
  set dir [lib_git__dir $key]
  set root ""
  if {[file isdirectory $dir] && \
      ![catch {exec git -C $dir rev-parse --show-toplevel} out]} {
    set root [file normalize [string trim $out]]
  }
  set ::lib_git_root_cache($key) $root
  return $root
}

# <abspath> made relative to <root> (the pathspec). "." when abspath == root (a
# standalone library: the pathspec is the whole repo, which IS the library).
proc lib_git_relpath {root abspath} {
  set root [file normalize $root]
  set abspath [file normalize $abspath]
  if {$abspath eq $root} { return "." }
  set rl [file split $root]
  set al [file split $abspath]
  set n [llength $rl]
  if {[llength $al] > $n && [lrange $al 0 [expr {$n - 1}]] eq $rl} {
    return [file join {*}[lrange $al $n end]]
  }
  # Not under root (shouldn't happen for a resolved target): best-effort tail.
  return $abspath
}

# {root pathspec} for <abspath>, or {} if it is not under git (case E).
proc lib_git_context {abspath} {
  set root [lib_git_root $abspath]
  if {$root eq ""} { return {} }
  return [list $root [lib_git_relpath $root $abspath]]
}

# --- path -> cellview attribution -------------------------------------------
# Map a path RELATIVE TO A LIBRARY dir to its "cell/view" key, or "" when the
# path is not a cell datafile. Shared by status, checkouts and the bold tag.
#   nested: <cell>/<view>/<cell>.<ext>     -> "<cell>/<view>"
#   flat:   <cell>.sym -> "<cell>/symbol", <cell>.sch -> "<cell>/schematic"
# Excludes the recoverable-delete trash and ~-backing files (spec §7).
proc lib_git_cellview {libpath rel} {
  set comps [file split $rel]
  set n [llength $comps]
  if {$n == 0} { return "" }
  if {[lindex $comps 0] eq ".xschem_trash"} { return "" }
  set base [lindex $comps end]
  if {[string match "*~" $base]} { return "" }
  if {$n == 3} {
    set cell [lindex $comps 0]
    set view [lindex $comps 1]
    if {[file rootname $base] eq $cell} { return "$cell/$view" }
    return ""
  } elseif {$n == 1} {
    set cell [file rootname $base]
    switch -- [file extension $base] {
      .sym    { return "$cell/symbol" }
      .sch    { return "$cell/schematic" }
      default { return "" }
    }
  }
  return ""
}

# Classify a git porcelain XY status code into the spec's vocabulary.
proc lib_git__state {code} {
  if {$code eq "??"} { return untracked }
  set x [string index $code 0]
  set y [string index $code 1]
  if {$x ne " " && $x ne "?"} { return staged }
  if {$y eq "M" || $y eq "D"} { return modified }
  return clean
}

# dict {cell/view -> untracked|modified|staged} for a library, scoped to that
# library's pathspec only (so a sibling library in the same repo never leaks in).
# Returns {} when the library is not under git (graceful, case E).
proc lib_git_status_map {libpath} {
  set ctx [lib_git_context $libpath]
  if {$ctx eq {}} { return {} }
  lassign $ctx root pathspec
  set libpath [file normalize $libpath]
  # -uall: list untracked FILES individually (default collapses an untracked
  # directory to one entry, which would hide per-cell/view granularity).
  if {[catch {exec git -C $root status --porcelain -z -uall -- $pathspec} out]} { return {} }
  set map [dict create]
  set fields [split $out "\0"]
  set i 0
  set N [llength $fields]
  while {$i < $N} {
    set f [lindex $fields $i]
    incr i
    if {$f eq ""} { continue }
    set code [string range $f 0 1]
    set path [string range $f 3 end]
    # rename/copy entries carry the original path in the next -z field; skip it.
    if {[string index $code 0] eq "R" || [string index $code 0] eq "C" || \
        [string index $code 1] eq "R" || [string index $code 1] eq "C"} { incr i }
    set abs [file normalize [file join $root $path]]
    if {$abs ne $libpath && ![string match "$libpath/*" $abs]} { continue }
    set cv [lib_git_cellview $libpath [lib_git_relpath $libpath $abs]]
    if {$cv eq ""} { continue }
    dict set map $cv [lib_git__state $code]
  }
  return $map
}

# Set (dict cell/view -> 1) of tracked datafiles in a library — drives the bold
# tag. {} when not under git.
proc lib_git_tracked_set {libpath} {
  set ctx [lib_git_context $libpath]
  if {$ctx eq {}} { return {} }
  lassign $ctx root pathspec
  set libpath [file normalize $libpath]
  if {[catch {exec git -C $root ls-files -z -- $pathspec} out]} { return {} }
  set acc [dict create]
  foreach path [split $out "\0"] {
    if {$path eq ""} { continue }
    set abs [file normalize [file join $root $path]]
    set cv [lib_git_cellview $libpath [lib_git_relpath $libpath $abs]]
    if {$cv ne ""} { dict set acc $cv 1 }
  }
  return $acc
}

# Formatted history (git log) for one root over a list of pathspecs. "" on error.
proc lib_git_log {root pathspecs} {
  if {$root eq ""} { return "" }
  # The format must be ONE argument: a literal in-word quote would make Tcl split
  # it on spaces, so build it from a variable (single word under substitution).
  set fmt "%h  %ad  %an  %s"
  set cmd [list git -C $root log --date=short --pretty=format:$fmt]
  if {[llength $pathspecs]} { lappend cmd -- {*}$pathspecs }
  if {[catch {exec {*}$cmd} out]} { return "" }
  return $out
}

# Structured history for the two-pane History dialog: one dict per commit
# (hash, short, date "YYYY-MM-DD HH:MM", author, subject, body), newest-first,
# scoped to the pathspecs. {} when not under git / on error. Fields are delimited
# by US (0x1f) and records by RS (0x1e) so a multiline body is captured intact.
proc lib_git_log_records {root pathspecs} {
  if {$root eq ""} { return {} }
  set US "\x1f"; set RS "\x1e"
  set fmt "%H${US}%h${US}%ad${US}%an${US}%s${US}%b${RS}"
  # the date pattern holds a space, so keep --date as ONE argument (a literal
  # in-word quote would make Tcl/exec split it — same trap as lib_git_log's fmt).
  set datearg "--date=format:%Y-%m-%d %H:%M"
  set cmd [list git -C $root log $datearg --pretty=format:$fmt]
  if {[llength $pathspecs]} { lappend cmd -- {*}$pathspecs }
  if {[catch {exec {*}$cmd} out]} { return {} }
  set recs {}
  foreach rec [split $out $RS] {
    set rec [string trimleft $rec "\n"]
    if {$rec eq ""} { continue }
    set f [split $rec $US]
    if {[llength $f] < 6} { continue }
    lassign $f hash short date author subject
    set body [string trim [join [lrange $f 5 end] $US]]
    lappend recs [dict create hash $hash short $short date $date \
                              author $author subject $subject body $body]
  }
  return $recs
}

# Commit ONLY the given pathspecs under one root (the case-C invariant: a
# library-level check-in never sweeps a sibling library or unrelated repo files).
proc lib_git_commit {root pathspecs message} {
  if {$root eq ""} { error "not under git revision control" }
  if {[string trim $message] eq ""} { error "commit message required" }
  exec git -C $root add -- {*}$pathspecs
  exec git -C $root commit -m $message -- {*}$pathspecs
  return ""
}

# Roll the given pathspecs back to HEAD (revert staged + worktree edits). Used by
# Cancel checkout; destructive, so the GUI confirms first.
proc lib_git_restore {root pathspecs} {
  if {$root eq ""} { error "not under git revision control" }
  exec git -C $root checkout HEAD -- {*}$pathspecs
  return ""
}

# --- lock / checkout layer ---------------------------------------------------
# Baseline = a LOCAL edit-lock that works on any git repo with no server: a
# marker recorded under the repo's git dir, plus the status-derived "your
# uncommitted edits". Opportunistic upgrade to Git LFS locks when the repo's
# remote supports the lock API (detected at runtime; absent => local fallback).

# Does this repo support LFS locks? `git lfs locks` succeeds only when lfs is
# installed AND a lock-capable remote answers; otherwise we use the local model.
proc lib_git__lfs_repo {root} {
  if {$root eq ""} { return 0 }
  return [expr {![catch {exec git -C $root lfs locks}]}]
}

proc lib_git__marker_file {root} {
  set gd [exec git -C $root rev-parse --git-dir]
  if {[file pathtype $gd] ne "absolute"} { set gd [file join $root $gd] }
  return [file join $gd xschem_lib_checkouts]
}
proc lib_git__markers {root} {
  set f [lib_git__marker_file $root]
  if {![file exists $f]} { return {} }
  set fp [open $f r]; set data [read $fp]; close $fp
  set out {}
  foreach line [split $data "\n"] {
    set l [string trim $line]
    if {$l ne ""} { lappend out $l }
  }
  return $out
}
proc lib_git__marker_write {root items} {
  set fp [open [lib_git__marker_file $root] w]
  foreach l $items { puts $fp $l }
  close $fp
}
proc lib_git__marker_add {root pathspec} {
  set cur [lib_git__markers $root]
  if {[lsearch -exact $cur $pathspec] >= 0} { return }
  lappend cur $pathspec
  lib_git__marker_write $root $cur
}
proc lib_git__marker_remove {root pathspec} {
  set cur [lib_git__markers $root]
  set i [lsearch -exact $cur $pathspec]
  if {$i < 0} { return }
  lib_git__marker_write $root [lreplace $cur $i $i]
}

# Check out a cell/view datafile: take an LFS lock when available, and always
# record a local marker (the GUI also clears the per-window read-only flag).
proc lib_git_checkout {abspath} {
  set ctx [lib_git_context $abspath]
  if {$ctx eq {}} { error "not under git revision control: $abspath" }
  lassign $ctx root pathspec
  if {[lib_git__lfs_repo $root]} { catch {exec git -C $root lfs lock $pathspec} }
  lib_git__marker_add $root $pathspec
  return ""
}

# Cancel a checkout: roll the datafile back to HEAD, release any LFS lock, drop
# the local marker. Destructive (the GUI confirms first).
proc lib_git_cancel_checkout {abspath} {
  set ctx [lib_git_context $abspath]
  if {$ctx eq {}} { error "not under git revision control: $abspath" }
  lassign $ctx root pathspec
  catch {lib_git_restore $root [list $pathspec]}
  if {[lib_git__lfs_repo $root]} { catch {exec git -C $root lfs unlock $pathspec} }
  lib_git__marker_remove $root $pathspec
  return ""
}

# The library's checked-out cell/views. Under LFS: the lock list (other users
# too). Locally: your uncommitted edits (modified/staged) UNION explicit markers,
# so a view you checked out but have not edited yet still shows. Sorted keys.
proc lib_git_checkouts {libpath} {
  set ctx [lib_git_context $libpath]
  if {$ctx eq {}} { return {} }
  lassign $ctx root libspec
  set libpath [file normalize $libpath]
  set acc [dict create]
  dict for {cv state} [lib_git_status_map $libpath] {
    if {$state eq "modified" || $state eq "staged"} { dict set acc $cv 1 }
  }
  foreach ps [lib_git__markers $root] {
    set abs [file normalize [file join $root $ps]]
    if {$abs ne $libpath && ![string match "$libpath/*" $abs]} { continue }
    set cv [lib_git_cellview $libpath [lib_git_relpath $libpath $abs]]
    if {$cv ne ""} { dict set acc $cv 1 }
  }
  return [lsort [dict keys $acc]]
}

# --- multi-library Maintain reports (spec §2.1 grouping, §4.1 surface) --------
# Bucket the selected LIBRARY NAMES by their repo root (the single most important
# invariant): libraries sharing a root (two libs in one repo) land in one group
# so they can be addressed in one git call with multiple pathspecs; libraries in
# different repos get separate groups; a library not under git (or not found)
# buckets under root "". Group order follows first-seen root. Each group is
#   {root {lib pathspec} {lib pathspec} ...}
# and is therefore directly usable as `git -C <root> … -- <pathspecs>`.
proc lib_git_group_by_root {libnames} {
  set order {}
  set buckets [dict create]
  foreach lib $libnames {
    set path [library_resolve $lib]
    set root ""; set pathspec ""
    if {$path ne ""} {
      set ctx [lib_git_context $path]
      if {$ctx ne {}} { lassign $ctx root pathspec }
    }
    if {![dict exists $buckets $root]} { lappend order $root; dict set buckets $root {} }
    dict lappend buckets $root [list $lib $pathspec]
  }
  set out {}
  foreach root $order { lappend out [linsert [dict get $buckets $root] 0 $root] }
  return $out
}

# Show Status report (read-only text): a per-library section listing the
# library's UNTRACKED cellviews and its PENDING-commit (modified/staged) ones.
# Each library is scoped to its own pathspec, so a sibling library in the same
# repo never leaks in. Non-git / unknown libraries are noted, never fatal.
proc lib_git_status_report {libnames} {
  set out ""
  foreach lib $libnames {
    append out "Library: $lib\n"
    set path [library_resolve $lib]
    if {$path eq ""} { append out "  (library not found)\n\n"; continue }
    if {[lib_git_root $path] eq ""} { append out "  (not under git revision control)\n\n"; continue }
    set map [lib_git_status_map $path]
    set untracked {}; set pending {}
    foreach cv [lsort [dict keys $map]] {
      switch -- [dict get $map $cv] {
        untracked        { lappend untracked $cv }
        modified - staged { lappend pending [list $cv [dict get $map $cv]] }
      }
    }
    if {![llength $untracked] && ![llength $pending]} {
      append out "  (nothing untracked or pending)\n\n"; continue
    }
    if {[llength $untracked]} {
      append out "  Untracked:\n"
      foreach cv $untracked { append out "    $cv\n" }
    }
    if {[llength $pending]} {
      append out "  Pending commit:\n"
      foreach p $pending { append out "    [lindex $p 0]  ([lindex $p 1])\n" }
    }
    append out "\n"
  }
  return $out
}

# History report (read-only text): the git log of each selected library's
# pathspec, one per-library section, concatenated. Non-git / unknown libraries
# are noted, never fatal.
proc lib_git_history_report {libnames} {
  set out ""
  foreach lib $libnames {
    append out "Library: $lib\n"
    set path [library_resolve $lib]
    if {$path eq ""} { append out "  (library not found)\n\n"; continue }
    set ctx [lib_git_context $path]
    if {$ctx eq {}} { append out "  (not under git revision control)\n\n"; continue }
    lassign $ctx root pathspec
    set log [lib_git_log $root [list $pathspec]]
    if {[string trim $log] eq ""} { append out "  (no history)\n\n"; continue }
    foreach line [split $log "\n"] { append out "  $line\n" }
    append out "\n"
  }
  return $out
}
