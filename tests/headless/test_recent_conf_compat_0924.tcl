# The File > Open Recent list survives a stock xschem sharing the same
# ~/.xschem — issue 0924.
#
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_recent_conf_compat_0924.tcl
#
# WHAT BROKE. The user reported File > Open Recent going empty "each time you do
# some work". Measured cause, two halves that feed each other:
#
#   READ  — load_recent_file `source`d $USER_CONF_DIR/recent_files INSIDE the
#           proc. Stock xschem (and every build of ours before 6be62c26) writes
#           the list as an unnamespaced `set recentfile {...}`; in a proc frame
#           that name is a throwaway LOCAL. The list was read, dropped on the
#           floor, and tctx::recentfile stayed {} — an empty menu, no error.
#   WRITE — write_recent_file emitted only the tctx:: name, which a stock xschem
#           cannot read. It therefore started from an empty list and rewrote the
#           whole file (mode "w") holding only the one schematic it had just
#           opened. The user's ten entries were gone from DISK, not just from
#           the menu.
#
# Measured on this machine: /usr/local/bin/xschem is 3.4.6 (Jan 2025), has no
# `no_recent_files` gate at all, and is what a bare `xschem` on PATH resolves
# to. One automation run through it emptied the list.
#
# The fix is symmetric: source at global scope and adopt the legacy name if the
# namespaced one came back empty; and write BOTH names so the old build reads
# the real list instead of starting from nothing. Every group below has a
# positive or negative twin so it cannot go green by disabling what it guards.

set failed 0
set checks 0
proc ck {name cond} {
  global failed checks
  incr checks
  if {[uplevel 1 [list expr $cond]]} { puts "ok:   $name" } else { puts "FAIL: $name"; incr failed }
}

set TMP [file join /tmp xschem_recentconf_test_[pid]]
file mkdir $TMP

# Never touch the user's real conf: point USER_CONF_DIR at the temp dir for the
# duration and put it back at the end.
set SAVED_CONF $USER_CONF_DIR
set SAVED_GATE [expr {[info exists ::update_recent_files] ? $::update_recent_files : 1}]
set RF $TMP/recent_files

proc putconf {text} {
  global RF
  set fd [open $RF w]; puts $fd $text; close $fd
}
proc getconf {} {
  global RF
  if {![file exists $RF]} { return {} }
  set fd [open $RF r]; set d [read $fd]; close $fd; return $d
}

set USER_CONF_DIR $TMP

# ------------------------------------------------------------------ group C1
# READ: a conf left behind by a stock xschem must still populate the menu.
putconf {set recentfile {/x/a.sch /x/b.sch /x/c.sch}}
load_recent_file
ck "C1  a LEGACY conf (unnamespaced `set recentfile`) populates the menu list" \
   {[llength [set tctx::recentfile]] == 3}
ck "C1a and in order, most recent first" \
   {[lindex [set tctx::recentfile] 0] eq {/x/a.sch}}

# POSITIVE TWIN: the current format still reads, so C1 cannot pass by having
# broken the namespaced path.
putconf {set tctx::recentfile {/y/p.sch /y/q.sch}}
load_recent_file
ck "C1b POSITIVE TWIN: the current namespaced conf still reads" \
   {[set tctx::recentfile] eq {/y/p.sch /y/q.sch}}

# NEGATIVE TWIN: a conf that names neither leaves the list empty. No phantom
# entries, and no leftovers from the previous load.
putconf {# nothing here}
load_recent_file
ck "C1c NEGATIVE TWIN: a conf setting neither name yields an EMPTY list" \
   {[set tctx::recentfile] eq {}}

# ------------------------------------------------------------------ group C2
# The legacy name must not survive as a global — a stale ::recentfile would
# out-live the conf it came from and could be adopted by a later, unrelated load.
putconf {set recentfile {/x/a.sch}}
load_recent_file
ck "C2  the legacy global does not leak past the load that used it" \
   {![info exists ::recentfile]}

# ------------------------------------------------------------------ group C3
# WRITE: the conf must carry BOTH names, or a stock xschem starts from empty.
set ::update_recent_files 1
set tctx::recentfile {/x/a.sch /x/b.sch}
write_recent_file
set txt [getconf]
ck "C3  the written conf carries the namespaced name" \
   {[string match "*set tctx::recentfile {/x/a.sch /x/b.sch}*" $txt]}
ck "C3a the written conf ALSO carries the legacy name a stock xschem reads" \
   {[string match "*\nset recentfile {/x/a.sch /x/b.sch}*" "\n$txt"]}
ck "C3b both names hold the SAME list" \
   {[regexp {set tctx::recentfile \{([^\}]*)\}} $txt -> a] &&
    [regexp {\nset recentfile \{([^\}]*)\}} "\n$txt" -> b] && $a eq $b}

# ------------------------------------------------------------------ group C4
# The whole round trip. Stand in for the stock build by rewriting the conf the
# way it does: legacy name only, its newly-opened file prepended, everything
# else it did not understand dropped.
set tctx::recentfile {/x/a.sch /x/b.sch /x/c.sch}
write_recent_file
set seen_by_stock {}   ;# stays empty if the legacy line is absent -> a clean FAIL below
regexp {\nset recentfile \{([^\}]*)\}} "\n[getconf]" -> seen_by_stock
ck "C4  a stock xschem reading our conf sees the REAL list, not an empty one" \
   {$seen_by_stock eq {/x/a.sch /x/b.sch /x/c.sch}}
putconf "set recentfile {/x/new.sch $seen_by_stock}"
load_recent_file
ck "C4a and reading back what it wrote loses nothing" \
   {[set tctx::recentfile] eq {/x/new.sch /x/a.sch /x/b.sch /x/c.sch}}

# ------------------------------------------------------------------ group C5
# Issue 0839's empty-entry filter must apply to an adopted legacy list too --
# an empty element is what made Ctrl+Shift+O load nothing at all.
putconf "set recentfile {/x/a.sch {} /x/b.sch}"
load_recent_file
ck "C5  an empty element in a LEGACY conf is filtered out (issue 0839)" \
   {[lsearch -exact [set tctx::recentfile] {}] == -1}
ck "C5a and the real entries around it survive" \
   {[set tctx::recentfile] eq {/x/a.sch /x/b.sch}}

# ------------------------------------------------------------------ group C6
# When both names are present the namespaced one wins: it is the only one that
# can carry a list this build wrote, and the legacy line may be a stale copy.
putconf "set tctx::recentfile {/y/fresh.sch}\nset recentfile {/x/stale.sch}"
load_recent_file
ck "C6  with both names present the namespaced list wins" \
   {[set tctx::recentfile] eq {/y/fresh.sch}}

# ------------------------------------------------------------------ group C7
# The automation gate (issue 0119) must be untouched by any of this: a gated
# session still never rewrites the user's conf.
putconf {set tctx::recentfile {/x/keep.sch}}
set ::update_recent_files 0
set tctx::recentfile {/x/should_not_be_written.sch}
write_recent_file
ck "C7  a gated (test/automation) session still does not write the conf" \
   {[string match "*keep.sch*" [getconf]]}
set tctx::recentfile {/x/inmem.sch}
update_recent_file /x/nope.sch
ck "C7a and update_recent_file changes neither the list nor the conf when gated" \
   {[set tctx::recentfile] eq {/x/inmem.sch} && [string match "*keep.sch*" [getconf]]}

# ------------------------------------------------------------------ group C9
# REACHABILITY, not just presence. C3a only proves the legacy line is IN the
# file; what matters is whether a foreign reader that SOURCES the file ever gets
# to it. The conf is executed, not parsed, so a reader whose Tcl has no `tctx`
# namespace RAISES on `set tctx::recentfile ...` and abandons the rest of the
# file. A child interp is exactly that reader: fresh, and with no tctx in it.
set ::update_recent_files 1
set tctx::recentfile {/x/a.sch /x/b.sch}
write_recent_file
set ip [interp create]
catch {$ip eval [list source $RF]}
set reached [expr {[$ip eval {info exists recentfile}] ? [$ip eval {set recentfile}] : {NEVER-REACHED}}]
interp delete $ip
ck "C9  a reader with no tctx namespace still REACHES the legacy list" \
   {$reached eq {/x/a.sch /x/b.sch}}

# NEGATIVE TWIN: the child interp really is a strict reader. Hand it a conf
# holding ONLY the namespaced line and it must come away with nothing -- if this
# passes trivially then C9 proves nothing.
putconf {set tctx::recentfile {/x/a.sch}}
set ip [interp create]
catch {$ip eval [list source $RF]}
set strict [expr {[$ip eval {info exists recentfile}] ? {LEAKED} : {NEVER-REACHED}}]
set nsfail [catch {$ip eval {namespace exists tctx}} nsres]
interp delete $ip
ck "C9a NEGATIVE TWIN: that same reader gets NOTHING from a tctx-only conf" \
   {$strict eq {NEVER-REACHED}}
ck "C9b and it really lacks the namespace (so C9 tested what it claims)" \
   {!$nsfail && !$nsres}

# ----------------------------------------------------------------- group C10
# No conf at all -- a first-ever launch. Must yield an empty list, not an error
# and not a leftover from whatever was loaded before.
set tctx::recentfile {/x/leftover.sch}
file delete -force $RF
set rc [catch {load_recent_file} lerr]
ck "C10 a missing conf loads cleanly (no error)" {$rc == 0}
ck "C10a and leaves an EMPTY list, not the previous one" \
   {[set tctx::recentfile] eq {}}

# restore: the user's conf dir and the gate, before anything else can write
set USER_CONF_DIR $SAVED_CONF
set ::update_recent_files $SAVED_GATE
ck "C8  the test restored USER_CONF_DIR" {$USER_CONF_DIR eq $SAVED_CONF}
ck "C8a and left the automation gate as it found it" \
   {$::update_recent_files == $SAVED_GATE}

file delete -force $TMP
# The completion banner run_regression.tcl actually reads is `OVERALL: ok` --
# see tests/banner_rule.tcl banner_complete. A suite that ends on `RESULT: ALL
# PASS` alone (the shape test_reopen_recent.tcl uses, which is NOT registered)
# scores a harness FAIL no matter how green its checks are.
if {$failed} {
  puts "RESULT: $failed FAILED ($checks checks)"
  puts "OVERALL: notok"
} else {
  puts "RESULT: ALL PASS ($checks checks)"
  puts "OVERALL: ok"
}
flush stdout
exit [expr {$failed == 0 ? 0 : 1}]
