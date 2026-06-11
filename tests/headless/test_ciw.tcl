# Integration smoke for the CIW (Command Interpreter Window, src/ciw.tcl) and
# the log_action CIW mirror / `xschem log_action` plumbing.
# Run under X with --pipe; pass --logdir so the log file lands in a temp dir:
#   DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_ciw.tcl
update idletasks

proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"
  if {!$ok} {incr ::fails}
}
set ::fails 0

# 1) the CIW auto-opened at startup: panedwindow, read-only log pane, entry
check "CIW toplevel exists"      [winfo exists .ciw]
check "panedwindow split"        [expr {[winfo exists .ciw.p] && [winfo class .ciw.p] eq {Panedwindow}}]
check "log pane is a text"       [expr {[winfo exists .ciw.l.t] && [winfo class .ciw.l.t] eq {Text}}]
check "log pane is read-only"    [expr {[.ciw.l.t cget -state] eq {disabled}}]
check "entry pane exists"        [expr {[winfo exists .ciw.c.e] && [winfo class .ciw.c.e] eq {Text}}]
check "entry is editable (log pane is not)" [expr {[.ciw.c.e cget -state] eq {normal}}]
check "sash has a fat grab target" [expr {[.ciw.p cget -sashwidth] >= 12}]

# the entry AREA grows when the sash is dragged up (the original entry widget
# kept its one-line height and left dead space -- the UX bug). Drive the sash
# programmatically. This needs the window mapped with settled geometry; under
# WSLg that is nondeterministic (issues 0001/0002), so guard on a sane initial
# height and skip rather than false-fail when the panedwindow has not laid out.
update
set h0 [winfo height .ciw.c.e]
if {[winfo viewable .ciw.p] && $h0 > 1} {
  set sxy [.ciw.p sash coord 0]
  .ciw.p sash place 0 [lindex $sxy 0] [expr {[lindex $sxy 1] - 120}]
  update
  set h1 [winfo height .ciw.c.e]
  check "entry height follows the sash" [expr {$h1 > $h0}]
  .ciw.p sash place 0 [lindex $sxy 0] [lindex $sxy 1]
  update
} else {
  puts "skip: entry-height-follows-sash (panedwindow not laid out -- environment, issue 0001)"
}

# 2) the action log is open (interactive session) and its path is queryable
set logf [xschem get actionlog_filename]
check "actionlog_filename set"   [expr {$logf ne {}}]

# 3) C mirror: an xschem log_action line lands in the pane (file checked below)
xschem log_action {xschem zoom_full}
update idletasks
set pane [.ciw.l.t get 1.0 end]
check "log_action mirrored to pane" [expr {[string first {xschem zoom_full} $pane] >= 0}]

# 4) mirror is substitution-safe: braces / brackets / $ pass through verbatim
set tricky {# marker {with braces} $dollar [brackets]}
xschem log_action $tricky
set pane [.ciw.l.t get 1.0 end]
check "tricky line verbatim in pane" [expr {[string first $tricky $pane] >= 0}]

# 5) typed command: echoed input-tagged, result shown result-tagged, entry cleared
.ciw.c.e insert end { xschem get instances }
ciw_exec
set pane [.ciw.l.t get 1.0 end]
check "typed cmd echoed with > prefix" [expr {[string first {> xschem get instances} $pane] >= 0}]
check "input tag used"             [expr {[llength [.ciw.l.t tag ranges input]] > 0}]
check "result tag used"            [expr {[llength [.ciw.l.t tag ranges result]] > 0}]
check "entry cleared after exec"   [expr {[.ciw.c.e get 1.0 end-1c] eq {}}]

# 5b) Return executes and does NOT leave a newline in the entry (the 'break'
# in the binding stops the Text class binding that would insert one).
# Synthesized key events need the widget focused (issue 0001 lesson); guard
# the check on focus actually landing so a focus-starved environment skips
# rather than false-fails, and clear the entry either way so nothing cascades.
.ciw.c.e insert end { xschem get zoom }
focus -force .ciw.c.e
update
if {[focus] eq {.ciw.c.e}} {
  event generate .ciw.c.e <Return>
  check "Return executes, no stray newline" [expr {[.ciw.c.e get 1.0 end-1c] eq {}}]
} else {
  puts "skip: Return-key check (no X focus -- environment, see issue 0001)"
}
.ciw.c.e delete 1.0 end

# 5c) Ctrl-Backspace deletes the previous word, shell-style (drive the proc
# directly -- key synthesis would need focus, see 5b)
.ciw.c.e insert end {xschem zoom_full   }
ciw_delete_word
check "Ctrl-BackSpace eats trailing space + word" \
  [expr {[.ciw.c.e get 1.0 end-1c] eq {xschem }}]
.ciw.c.e delete 1.0 end
check "Ctrl-BackSpace bound" [expr {[bind .ciw.c.e <Control-BackSpace>] ne {}}]

# 5d) Up/Down history: recall, walk older, and restore the stashed draft
.ciw.c.e insert end {set ciw_hist_probe_1 1}
ciw_exec
.ciw.c.e insert end {set ciw_hist_probe_2 2}
ciw_exec
.ciw.c.e insert end {half-typed draft}
ciw_hist_move -1
check "Up recalls newest command"  [expr {[.ciw.c.e get 1.0 end-1c] eq {set ciw_hist_probe_2 2}}]
ciw_hist_move -1
check "Up again walks older"       [expr {[.ciw.c.e get 1.0 end-1c] eq {set ciw_hist_probe_1 1}}]
ciw_hist_move 1
ciw_hist_move 1
check "Down restores stashed draft" [expr {[.ciw.c.e get 1.0 end-1c] eq {half-typed draft}}]
.ciw.c.e delete 1.0 end
check "Up/Down bound" [expr {[bind .ciw.c.e <Up>] ne {} && [bind .ciw.c.e <Down>] ne {}}]

# 6) error path: error text shown error-tagged
.ciw.c.e insert end {this_is_not_a_command}
ciw_exec
set pane [.ciw.l.t get 1.0 end]
check "error text shown"           [expr {[string first {invalid command name} $pane] >= 0}]
check "error tag used"             [expr {[llength [.ciw.l.t tag ranges error]] > 0}]

# 7) the file: header, log_action lines, raw typed command (no "> ", no result),
#    failed command as '# failed:' comment -- the whole file stays source-able
set fd [open $logf r]
set body [read $fd]
close $fd
set lines [split [string trimright $body \n] \n]
check "file header comment"        [expr {[string match {# xschem action log*} [lindex $lines 0]]}]
check "log_action line in file"    [expr {[lsearch -exact $lines {xschem zoom_full}] >= 0}]
check "tricky line verbatim in file" [expr {[lsearch -exact $lines $tricky] >= 0}]
check "typed cmd recorded raw"     [expr {[lsearch -exact $lines {xschem get instances}] >= 0}]
check "failed cmd is a comment"    [expr {[lsearch -exact $lines {# failed: this_is_not_a_command}] >= 0}]
check "no echo prefix in file"     [expr {[lsearch -glob $lines {> *}] < 0}]
check "no result/error text in file" [expr {[string first {invalid command name} $body] < 0}]
# source-ability: every line must be a comment or a known-good command here,
# so replaying the file into this same interpreter must not error
check "file is source-able"        [expr {![catch {uplevel #0 [list source $logf]} err]}]

# 8) closing the CIW withdraws (xschem survives); ciw_create re-shows it
eval [wm protocol .ciw WM_DELETE_WINDOW]
update idletasks
check "close withdraws, not destroys" [expr {[winfo exists .ciw] && [wm state .ciw] eq {withdrawn}}]
ciw_create
update idletasks
check "ciw_create re-shows"        [expr {[wm state .ciw] eq {normal}}]

# clean RAIL teardown (issue 0002 hardening): destroy the toplevel and let the
# event loop deliver it while the client is still alive, THEN exit
destroy .ciw
update

puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
