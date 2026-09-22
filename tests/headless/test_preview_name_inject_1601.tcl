# tests/headless/test_preview_name_inject_1601.tcl
#
# ISSUE 1601 -- a file NAME was a script in the Open and Insert preview bindings.
#
# A Tk binding script, and an `after` script, are Tcl SOURCE: they are parsed
# fresh every time they fire. Four sites in src/xschem.tcl spliced a file name
# into one of those strings, so the name was code.
#
#   SITE 1  proc file_dialog_display_preview   (the Open dialog)
#     bind .load.l.paneright.draw <Expose>    [subst {... draw ... "$f"}]
#     bind .load.l.paneright.draw <Configure> [subst {... draw ... "$f"}]
#   SITE 2  proc file_chooser_draw_preview     (the Insert dialog)
#     bind .ins.center.right <Expose>    "... draw .ins.center.right {$f}"
#     bind .ins.center.right <Configure> "... draw .ins.center.right {$f}"
#   SITE 3  proc file_chooser_preview
#     after cancel "file_chooser_draw_preview {$file_chooser(f)}"
#   SITE 4  proc file_chooser_preview
#     after 200    "file_chooser_draw_preview {$f}"
#
# MEASURED at f8647d8d, on :99, through the SHIPPED Open dialog: a real
# schematic named `pwn[set ::CANARY OPEN_DIALOG]ed.sch`, selected with the
# shipped <ButtonRelease-1> binding, executed `set ::CANARY OPEN_DIALOG` the
# moment the preview pane received an <Expose>. Site 1 is double-quoted, so
# `[...]` and a `"` escape both execute; sites 2-4 are brace-quoted inside a
# double-quoted string, so a `}` in the name terminates the group early and the
# remainder executes. Nobody has to type anything: the payload is a FILE NAME,
# and it arrives by any route a file arrives by.
#
# The fix builds every one of the four as a LIST, which quotes each element for
# exactly one round of parsing -- exactly what a binding and an `after` get.
#
# ⚠ `after cancel` MATCHES ON THE SCRIPT STRING. Sites 3 and 4 are a pair: if
# only one is converted, the cancel silently stops matching and a stale preview
# redraw survives. Section C measures that pairing directly, on both arms, and
# C5 shows the mismatch the old spelling would now produce.
#
# SECTIONS
#   S1-S15  STRUCTURAL, both arms. No interpolated binding or `after` survives
#           in these procs, and none anywhere else in src/xschem.tcl. The file
#           is read with COMMENT LINES STRIPPED, because the comments above the
#           fixes quote the defective lines verbatim and a raw grep would answer
#           "still broken" forever.
#   C1-C5   CANCEL PAIRING, both arms. Plain-Tcl `after`: the list-built cancel
#           matches the list-built schedule for a plain name, a name with a
#           space, a name with a close brace and a name with brackets; and the
#           OLD interpolated spelling does NOT match, which is why both sites
#           had to change together.
#   B1-B18  BEHAVIOURAL, DISPLAY ARM ONLY. Real files with hostile names on
#           disk, the real procs, real <Expose> events, the real
#           `file_chooser_preview` scheduling and cancelling path, and the real
#           `load_file_dialog` -- with a canary in the interpreter that must
#           stay quiet. These need Tk (`toplevel`, `winfo`, `bind`, `event
#           generate`), which does not exist under --nogui, so on the headless
#           arm they print one `skip:` line.
#
# ARMED SPELLINGS
#   tests/headless/run_suites.sh test_preview_name_inject_1601            (both)
#   tests/headless/run_suites.sh --nogui test_preview_name_inject_1601    (S+C)
# Registered in tests/run_regression.tcl in BOTH `hcases` and `dcases`, for the
# same reason test_input_line_inject_1352 is.
#
# FLOOR: 20 checks headless (S+C), 38 on the display arm. Measured 2026-09-22.
# RAISED, NEVER LOWERED.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
proc skiprow {names why} { puts "skip: $names -- $why" ; flush stdout }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]

set XTCL [file join $repo src xschem.tcl]

proc slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
## Comment lines removed. The fixes' own comment blocks QUOTE the defective
## lines verbatim, so a structural row reading the raw file would answer "the
## bug is still here" forever.
proc nocomment {text} {
  set out {}
  foreach l [split $text "\n"] {
    if {[regexp {^[ \t]*#} $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
proc scount {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
## The body of `proc <name>` only: its `proc` line to the first column-0 `}`.
## ZZNOPROC if the proc is not there at all, so no row can pass by finding
## nothing.
proc proc_body {src name} {
  set on 0 ; set out {}
  foreach l [split $src "\n"] {
    if {$on} {
      if {[regexp {^\}} $l]} { return [join $out "\n"] }
      lappend out $l
      continue
    }
    if {[regexp "^proc\[ \t\]+$name\[ \t\]" $l]} { set on 1 }
  }
  if {$on} { return [join $out "\n"] }
  return ZZNOPROC
}

set SRC   [slurp $XTCL]
set FILE  [nocomment $SRC]
set BODY1 [proc_body $FILE file_dialog_display_preview]
set BODY2 [proc_body $FILE file_chooser_draw_preview]
set BODY3 [proc_body $FILE file_chooser_preview]

# ===========================================================================
# SECTION S -- STRUCTURAL. Both arms. This is what reddens if a fix is edited
# away textually without anybody opening a dialog.
# ===========================================================================
check_true {S1 proc file_dialog_display_preview is still in src/xschem.tcl} \
  [expr {$BODY1 ne {ZZNOPROC} && $BODY1 ne {}}]
check_true {S2 proc file_chooser_draw_preview is still in src/xschem.tcl} \
  [expr {$BODY2 ne {ZZNOPROC} && $BODY2 ne {}}]
check_true {S3 proc file_chooser_preview is still in src/xschem.tcl} \
  [expr {$BODY3 ne {ZZNOPROC} && $BODY3 ne {}}]

## SITE 1 -------------------------------------------------------------------
check {S4 Open preview binds a list-built script} \
  [scount $BODY1 {[list xschem preview_window draw .load.l.paneright.draw $f]}] 1
check {S5 Open preview <Expose> and <Configure> both bind that script} \
  [expr {[scount $BODY1 {bind .load.l.paneright.draw <Expose> $preview_script}]
       + [scount $BODY1 {bind .load.l.paneright.draw <Configure> $preview_script}]}] 2
check {S6 no `subst` anywhere in file_dialog_display_preview} \
  [scount $BODY1 {subst}] 0
## Anywhere in the file: a second dialog copied from this one would be the same
## defect under another name.
check {S7 no subst-built preview bind anywhere in xschem.tcl} \
  [scount $FILE "\[subst \{xschem preview_window draw"] 0

## SITE 2 -------------------------------------------------------------------
check {S8 Insert preview binds a list-built script} \
  [scount $BODY2 {[list xschem preview_window draw .ins.center.right $f]}] 1
check {S9 Insert preview <Expose> and <Configure> both bind that script} \
  [expr {[scount $BODY2 {bind .ins.center.right <Expose> $preview_script}]
       + [scount $BODY2 {bind .ins.center.right <Configure> $preview_script}]}] 2
check {S10 no brace-quoted Insert preview bind anywhere in xschem.tcl} \
  [scount $FILE "\"xschem preview_window draw .ins.center.right \{\$f\}\""] 0

## SITES 3 and 4 ------------------------------------------------------------
check {S11 after 200 schedules the redraw through list} \
  [scount $BODY3 {after 200 [list file_chooser_draw_preview $f]}] 1
check {S12 after cancel cancels through list} \
  [scount $BODY3 {after cancel [list file_chooser_draw_preview $file_chooser(f)]}] 1
## ⚠ THE PAIRING ROW. `after cancel` matches on the script string, so the two
## must be built the same way. Exactly two list-built `file_chooser_draw_preview`
## scripts exist in the whole file: the schedule and the cancel.
check {S13 the schedule and the cancel are the only two, both list-built} \
  [scount $FILE {[list file_chooser_draw_preview}] 2
## ⚠ S15 EXISTS BECAUSE THE FIX'S OWN COMMENT BROKE THE PROC ONCE. A comment
## inside a proc body sits inside a brace-quoted word, and Tcl counts braces
## before it ever notices a `#`. The first draft of the SITE 2 comment quoted the
## hostile file name verbatim -- a close brace, then later a reopening one -- and
## that silently ended the enclosing `if` early: the bind lines below it ran
## unguarded and the body's own closing brace became a command, so
## file_chooser_draw_preview raised `invalid command name "}"` on EVERY call.
## Measured, not imagined. This row reads the RAW bodies, comments included.
proc comment_brace_faults {body} {
  set bad 0
  foreach l [split $body "\n"] {
    if {![regexp {^[ \t]*#} $l]} { continue }
    set d 0 ; set dip 0
    for {set i 0} {$i < [string length $l]} {incr i} {
      set c [string index $l $i]
      if {$c eq "\\"} { incr i ; continue }
      if {$c eq "\{"} { incr d } elseif {$c eq "\}"} { incr d -1 }
      if {$d < 0} { set dip 1 }
    }
    if {$d != 0 || $dip} { incr bad }
  }
  return $bad
}
set RAW1 [proc_body $SRC file_dialog_display_preview]
set RAW2 [proc_body $SRC file_chooser_draw_preview]
set RAW3 [proc_body $SRC file_chooser_preview]
check {S15 every comment line inside the three preview procs is brace-balanced} \
  [expr {[comment_brace_faults $RAW1] + [comment_brace_faults $RAW2]
       + [comment_brace_faults $RAW3]}] 0
check {S14 no interpolated after for file_chooser_draw_preview anywhere} \
  [expr {[scount $FILE "\"file_chooser_draw_preview \{\$f\}\""]
       + [scount $FILE "\"file_chooser_draw_preview \{\$file_chooser(f)\}\""]}] 0

# ===========================================================================
# SECTION C -- THE CANCEL PAIRING. Both arms: `after` is core Tcl and needs no
# Tk and no event loop to schedule, cancel and report.
# ===========================================================================
proc cancel_matches {name} {
  set id [after 60000 [list file_chooser_draw_preview $name]]
  after cancel [list file_chooser_draw_preview $name]
  set still [expr {[lsearch -exact [after info] $id] >= 0}]
  catch {after cancel $id}
  return [expr {$still ? 0 : 1}]
}
check_true {C1 list-built cancel matches a list-built schedule: plain name} \
  [cancel_matches {/tmp/x/plain.sch}]
check_true {C2 ... a name with a SPACE} \
  [cancel_matches {/tmp/x/two words.sch}]
check_true {C3 ... a name with a CLOSE BRACE} \
  [cancel_matches "/tmp/x/close\}brace.sch"]
check_true {C4 ... a name with BRACKETS and a dollar} \
  [cancel_matches {/tmp/x/q[set ::PWNED X]$v.sch}]
## ⚠ C5 is why sites 3 and 4 had to change TOGETHER. The old interpolated
## spelling produces a different string from the list-built schedule, so a
## half-done fix would leave the cancel silently not matching.
set _id [after 60000 [list file_chooser_draw_preview {/tmp/x/plain.sch}]]
set _f {/tmp/x/plain.sch}
after cancel "file_chooser_draw_preview {$_f}"
check_true {C5 the OLD interpolated cancel does NOT match the list-built schedule} \
  [expr {[lsearch -exact [after info] $_id] >= 0}]
catch {after cancel $_id}

# ===========================================================================
# SECTION B -- BEHAVIOURAL. Real hostile file names on disk, the real procs,
# real events. DISPLAY ARM ONLY.
# ===========================================================================
set BROWS {B1/B2/B3/B4/B5/B6/B7/B8/B9/B10/B11/B12/B13/B14/B15/B16/B17/B18}

if {![info exists ::has_x] || !$::has_x} {
  skiprow $BROWS "these rows put files with hostile names on disk, call the\
 real preview procs, deliver real <Expose> events to real widgets and open the\
 real Open dialog; all of that needs Tk -- toplevel, winfo, bind and event\
 generate do not exist under --nogui -- so the arm that measures them is\
 tests/headless/run_suites.sh test_preview_name_inject_1601"
} else {

set scratch [test_scratch pvinj]

## ⚠ Tk's stock bgerror pops a MODAL dialog, and xschem's alert_ pops another.
## An injected script that merely RAISES would wedge this suite on :99 (and, on
## a real desktop, wedges the user's Open dialog on every single <Expose>).
## Trap both so a row can report instead of hanging.
set ::BGERR {}
proc ::bgerror {m} { lappend ::BGERR $m }
proc ::alert_ {txtlabel {position +200+300} {nowait {0}} {yesno 0}} {
  lappend ::BGERR "alert_ $txtlabel" ; return ok
}
proc bgclear {} { set ::BGERR {} }
proc bgquiet {} { return [expr {$::BGERR eq {} ? 1 : 0}] }

## The canary. `info exists` on it is the whole question: it is set only by a
## FILE NAME being EXECUTED.
proc arm {} { catch {unset ::PWNED} ; bgclear }
proc fired {} { return [expr {[info exists ::PWNED] ? "FIRED-$::PWNED" : "no"}] }

## A real, loadable schematic under a hostile name.
set fp [open [file join $repo tests headless fixture_0098_pre.sch] r]
set BODYSCH [read $fp] ; close $fp
proc victim {name} {
  global scratch BODYSCH
  set p [file join $scratch $name]
  set f [open $p w] ; puts -nonewline $f $BODYSCH ; close $f
  return $p
}
## Site 1 is double-quoted: `[...]` and a `"` escape are the live shapes.
set V_BRACKET [victim {q[set ::PWNED BRACKET]z.sch}]
set V_QUOTESC [victim "x\"; set ::PWNED QUOTE_ESCAPE; format \".sch"]
set V_QUOTE   [victim "q\"uote.sch"]
## Sites 2/3/4 are brace-quoted: an unbalanced close brace is the live shape.
## (Spelled out, not printed: a bare brace in a comment INSIDE this `else` body
## would close the body -- Tcl counts braces before it ever sees a `#`.)
set V_BRACE   [victim "a\}; set ::PWNED BRACE_ESCAPE; format \{b.sch"]
set V_CBRACE  [victim "close\}brace.sch"]
set V_PLAIN   [victim {plain.sch}]

## Every victim must actually pass is_xschem_file, or the rows below would be
## measuring a file the preview never sees.
check_true {B1 every hostile name is a real schematic the preview would accept} \
  [expr {[is_xschem_file $V_BRACKET] ne {0} && [is_xschem_file $V_QUOTESC] ne {0}
      && [is_xschem_file $V_QUOTE]   ne {0} && [is_xschem_file $V_BRACE]   ne {0}
      && [is_xschem_file $V_CBRACE]  ne {0} && [is_xschem_file $V_PLAIN]   ne {0}}]

## --- SITE 1, the Open dialog's preview pane --------------------------------
## file_dialog_display_preview never calls `preview_window create`, so no slot
## is taken here and the draw itself is a no-op; the binding script is still
## built and still EVALUATED, which is where the injection was.
proc site1 {p} {
  catch {destroy .load}
  toplevel .load
  frame .load.l ; frame .load.l.paneright
  frame .load.l.paneright.draw -width 200 -height 200 -background white
  pack .load.l ; pack .load.l.paneright ; pack .load.l.paneright.draw
  arm
  file_dialog_display_preview $p
  set script [bind .load.l.paneright.draw <Expose>]
  update idletasks
  catch {event generate .load.l.paneright.draw <Expose>}
  update
  set res [list [fired] $script [bgquiet]]
  bind .load.l.paneright.draw <Expose> {}
  bind .load.l.paneright.draw <Configure> {}
  catch {destroy .load}
  update
  return $res
}

set r [site1 $V_BRACKET]
check {B2 Open preview: a command-substitution name does NOT execute} [lindex $r 0] no
check {B3 Open preview: the bound script is the name as DATA} [lindex $r 1] \
  [list xschem preview_window draw .load.l.paneright.draw $V_BRACKET]
set r [site1 $V_QUOTESC]
check {B4 Open preview: a quote-escape name does NOT execute} [lindex $r 0] no
set r [site1 $V_QUOTE]
check {B5 Open preview: a name with a quote does NOT execute} [lindex $r 0] no
check {B6 Open preview: a name with a quote no longer raises into bgerror} [lindex $r 2] 1

## --- SITE 2, the Insert dialog's preview pane ------------------------------
## ⚠ file_chooser_draw_preview DOES call `preview_window create`. A toplevel
## destroyed without a matching `close` leaves preview_window()'s static
## tkpre_window[] dangling and the next draw segfaults -- so close every slot.
catch {destroy .ins}
toplevel .ins
frame .ins.center
frame .ins.center.right -width 200 -height 200
frame .ins.center.left
listbox .ins.center.left.l
pack .ins.center ; pack .ins.center.left ; pack .ins.center.left.l ; pack .ins.center.right
update

proc site2 {p} {
  set ::file_chooser(action) {}
  arm
  catch {file_chooser_draw_preview $p}
  set script [bind .ins.center.right <Expose>]
  update idletasks
  catch {event generate .ins.center.right <Expose>}
  update
  set res [list [fired] $script [bgquiet]]
  catch {xschem preview_window close .ins.center.right {}}
  bind .ins.center.right <Expose> {}
  bind .ins.center.right <Configure> {}
  return $res
}

set r [site2 $V_BRACE]
check {B7 Insert preview: a close-brace escape name does NOT execute} [lindex $r 0] no
check {B8 Insert preview: the bound script is the name as DATA} [lindex $r 1] \
  [list xschem preview_window draw .ins.center.right $V_BRACE]
set r [site2 $V_CBRACE]
check {B9 Insert preview: a lone close brace no longer raises into bgerror} [lindex $r 2] 1

## ⚠ B17 and B18 are the behavioural half of S15. A brace fault in a comment
## inside file_chooser_draw_preview does not stop the file loading and does not
## stop the bindings being set -- it ends the enclosing `if` early, so the proc
## raises at its own closing brace AND runs its body even when .ins is gone.
## Both symptoms are measured, because the structural row alone would not catch
## a fault introduced some other way. B18 is further down, once .ins is gone.
set ::file_chooser(action) {}
check {B17 file_chooser_draw_preview returns cleanly on a plain schematic} \
  [catch {file_chooser_draw_preview $V_PLAIN}] 0
catch {xschem preview_window close .ins.center.right {}}
bind .ins.center.right <Expose> {}
bind .ins.center.right <Configure> {}

## --- SITES 3 and 4, through the real file_chooser_preview ------------------
## The real proc: it cancels the pending redraw for the PREVIOUS selection and
## schedules one for the new selection, both by script string.
proc pending_scripts {} {
  set out {}
  foreach id [after info] {
    set s [lindex [after info $id] 0]
    if {[string match {file_chooser_draw_preview*} $s]} { lappend out $s }
  }
  return $out
}
set ::file_chooser(fullpathlist) [list $V_BRACE $V_PLAIN]
catch {unset ::file_chooser(f)}
.ins.center.left.l delete 0 end
.ins.center.left.l insert end one two
.ins.center.left.l selection clear 0 end
.ins.center.left.l selection set 0
arm
catch {file_chooser_preview} e1
set sched [pending_scripts]
check {B10 file_chooser_preview schedules the redraw as DATA} $sched \
  [list [list file_chooser_draw_preview $V_BRACE]]

## Let the 200 ms timer fire for real. .ins is still up, so the redraw really
## runs; the canary says whether the NAME ran.
set ::WAITDONE 0
after 500 {set ::WAITDONE 1}
vwait ::WAITDONE
check {B11 the scheduled redraw does not execute the hostile name when it fires} \
  [fired] no
catch {xschem preview_window close .ins.center.right {}}

## Now the cancel: select the other entry while a redraw is pending, and the
## pending one must be gone. This is the `after cancel` proof in the real proc.
catch {unset ::file_chooser(f)}
.ins.center.left.l selection clear 0 end
.ins.center.left.l selection set 0
arm
catch {file_chooser_preview}
set before [pending_scripts]
.ins.center.left.l selection clear 0 end
.ins.center.left.l selection set 1
catch {file_chooser_preview}
set after_ [pending_scripts]
check {B12 a pending redraw for a hostile name IS scheduled before the cancel} \
  $before [list [list file_chooser_draw_preview $V_BRACE]]
check {B13 the next selection CANCELS it -- only the new one is left} \
  $after_ [list [list file_chooser_draw_preview $V_PLAIN]]
## Only OUR pending redraws -- cancelling everything would take xschem's own
## periodic timers with it.
foreach id [after info] {
  if {[string match {file_chooser_draw_preview*} [lindex [after info $id] 0]]} {
    catch {after cancel $id}
  }
}
catch {xschem preview_window close .ins.center.right {}}
bind .ins.center.right <Expose> {}
bind .ins.center.right <Configure> {}
catch {destroy .ins}
update

## The `winfo exists .ins` guard must still guard the WHOLE proc body: with the
## browser gone the proc does nothing and raises nothing.
check {B18 file_chooser_draw_preview is a silent no-op when .ins is absent} \
  [catch {file_chooser_draw_preview $V_PLAIN}] 0

## --- THE ISSUE'S OWN REPRO, through the shipped Open dialog ----------------
## `load_file_dialog` blocks in `tkwait window .load`, so it is driven from the
## event loop exactly the way a person drives it: select the row, let the
## shipped <ButtonRelease-1> binding run, let the preview pane be exposed.
set ::DRV {}
set ::DRVOK 0
proc drv {victim tries} {
  if {![winfo exists .load.l.paneright.f.list]} {
    if {$tries <= 0} { lappend ::DRV NODIALOG ; catch {destroy .load} ; return }
    after 50 [list drv $victim [expr {$tries - 1}]]
    return
  }
  set tail [file tail $victim]
  set idx -1
  for {set i 0} {$i < [.load.l.paneright.f.list index end]} {incr i} {
    if {[.load.l.paneright.f.list get $i] eq $tail} { set idx $i ; break }
  }
  if {$idx < 0} { lappend ::DRV NOTLISTED ; catch {destroy .load} ; return }
  .load.l.paneright.f.list selection clear 0 end
  .load.l.paneright.f.list selection set $idx
  .load.l.paneright.f.list activate $idx
  event generate .load.l.paneright.f.list <ButtonRelease-1>
  update
  set ::DRVSCRIPT [bind .load.l.paneright.draw <Expose>]
  arm
  update idletasks
  event generate .load.l.paneright.draw <Expose>
  update
  set ::DRVOK 1
  catch {.load.buttons_bot.cancel invoke}
  catch {destroy .load}
}

set ::file_dialog_files1 [list $scratch]
set ::file_dialog_index1 0
set ::INITIALINSTDIR $scratch
catch {file_dialog_set_names1}
set ::DRVSCRIPT {}
after 100 [list drv $V_BRACKET 120]
set ::GUARD [after 60000 {catch {destroy .load}}]
catch {load_file_dialog {issue 1601 probe} {*.sch} INITIALINSTDIR 1 0}
catch {after cancel $::GUARD}
catch {destroy .load}

## ⚠ WITHOUT THIS ROW THE NEXT ONE COULD PASS BY NOT HAPPENING: "the canary did
## not fire" is satisfied by a dialog that never opened.
check_true {B14 the shipped Open dialog really opened and really previewed the file} \
  [expr {$::DRVOK == 1 && $::DRV eq {}}]
check {B15 the shipped Open dialog: the hostile name did NOT execute} [fired] no
check {B16 the shipped Open dialog: its <Expose> script is the name as DATA} \
  $::DRVSCRIPT [list xschem preview_window draw .load.l.paneright.draw $V_BRACKET]

}
# --- verdict ---------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
## Both sentinels: run_suites.sh scores `RESULT: ALL PASS`, tests/banner_rule.tcl
## -- the rule run_regression.tcl consumes -- scores ONLY a whole-line
## `OVERALL: ok`. A suite printing one of them is scored a HARNESS FAILURE by the
## other however many of its own checks passed.
if {$fail == 0} {
  puts "OVERALL: ok"
} else {
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
