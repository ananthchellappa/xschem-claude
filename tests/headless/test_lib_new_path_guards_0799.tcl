# tests/headless/test_lib_new_path_guards_0799.tcl
#
# Issue 0799 -- Library Manager, right-click the Library pane, "New library...":
# the press is accepted, silently, when the Directory you pick is
#   (a) the folder that HOLDS your library list -- whatever that list file is
#       called -- so every cell you later save lands loose beside your real
#       libraries instead of inside one; or
#   (b) a folder that IS already one of your libraries, which gives one folder a
#       second name, so work done under one name quietly turns up under the other.
#
# ISSUE NUMBER: 0799 is the SYNTHESIS branch's number and it is correct here.
# 0700-0799 is reserved in doc/claude/issues/NUMBERING.md precisely because that
# branch owns the block; this issue was authored there (its own header says
# "Branch: synthesis", and it cross-references 0792 and 0798, neither of which
# exists on annotate -- 0792 is about vimport::create_library, code this branch
# does not have). Nothing on annotate FILED into the reserved block; a briefing
# document was carried across. Renumbering it would give one user complaint two
# identities. Follow-ups this branch filed for it are annotate's own numbers:
# 0995, 0996, 0997, 0998, 0999.
#
# The user's words: "why does library manager > New Library menu item allow a
# user to do something so stupid?", asked of a DEFINE line naming a git-tracked
# PDK root that a New-library press had written.
#
# See doc/claude/issues/0799-new-library-accepts-a-folder-that-is-already-a-library-or-the-root-that-holds-them-all-and-registers-it-without-a-word.md
#
# TWO ARMS, TWO LEGITIMATE COUNTS (issue 0994). Rows R1-R9 and R14 need no
# windows; rows R10-R13 and R15 drive the New-library window and only exist
# where Tk does.
#   headless     -> 36 checks
#       ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_lib_new_path_guards_0799.tcl
#   dev display  -> 55 checks
#       tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_lib_new_path_guards_0799.tcl
# Reporting one number against the other arm reads as a standing red. Say which
# arm produced the number.

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}
# substring test that never treats the needle as a glob pattern -- the refusal
# sentences and the folder paths both carry characters string match would eat.
proc has_text {haystack needle} { expr {[string first $needle $haystack] >= 0} }

proc defs_lines {f} {
  if {[catch {open $f r} fp]} { return {} }
  set txt [read $fp]; close $fp
  set out {}
  foreach l [split $txt \n] { if {[string trim $l] ne {}} { lappend out [string trim $l] } }
  return $out
}
proc defs_has_define {f name} {
  foreach l [defs_lines $f] {
    if {[regexp {^DEFINE\s+(\S+)\s} $l -> n] && $n eq $name} { return 1 }
  }
  return 0
}

source [file join [file dirname [info script]] scratch.tcl]

# --- what the session looked like before us, so we can hand it back ----------
set saved_defs [expr {[info exists ::XSCHEM_LIBRARY_DEFS] ? $::XSCHEM_LIBRARY_DEFS : {}}]
set saved_path [expr {[info exists ::pathlist] ? $::pathlist : {}}]
set saved_conf [expr {[info exists ::USER_CONF_DIR] ? $::USER_CONF_DIR : {}}]
set saved_only [expr {[info exists ::library_registry_defs_only] ? $::library_registry_defs_only : 0}]
set saved_pers [expr {[info exists ::library_personal_defs] ? $::library_personal_defs : 0}]

# --- FIXTURE A: one registry root holding a library list and three libraries --
# libA and libB are ordinary relative entries. ghost is a library whose folder
# was never created on disk. libC is spelled the awkward way a real hand-edited
# library.defs sometimes is -- an ABSOLUTE path with a "/./" in it, which the
# reader deliberately does not tidy up.
set tmp [test_scratch lib0799a]
file mkdir [file join $tmp libA] [file join $tmp libB] [file join $tmp libC]
file mkdir [file join $tmp conf0]
set defsA [file join $tmp library.defs]
set fp [open $defsA w]
puts $fp "# fixture for issue 0799"
puts $fp "DEFINE libA libA"
puts $fp "DEFINE libB libB"
puts $fp "DEFINE ghost ghostdir"
puts $fp "DEFINE libC $tmp/./libC"
close $fp

set ::XSCHEM_LIBRARY_DEFS $defsA
set ::pathlist {}
set ::library_personal_defs 0
set ::library_registry_defs_only 0
set ::USER_CONF_DIR [file join $tmp conf0]

# === R1 -- THE ORDINARY PRESS, WHICH MUST KEEP WORKING =======================
# Leave the Directory blank and you get a new folder inside the registry root.
# That is the normal, correct press and it is what a badly aimed refusal breaks
# first, so it is a check in its own right.
set r1_before [defs_lines $defsA]
set r1rc [catch {library_new NORMAL {}} r1e]
check "R1a a New library with the Directory left blank is still accepted" \
  [expr {$r1rc == 0}] "(rc=$r1rc err='$r1e')"
check "R1b it lands in a new folder inside the folder that holds the library list" \
  [expr {[file normalize [library_resolve NORMAL]] eq [file normalize [file join $tmp NORMAL]]}] \
  "(=> '[library_resolve NORMAL]')"
check "R1c that folder really was created" \
  [file isdirectory [file join $tmp NORMAL]] "(=> [file join $tmp NORMAL])"
set r1_after [defs_lines $defsA]
check "R1d exactly one line was added to the library list, in the short form" \
  [expr {[llength $r1_after] == [llength $r1_before] + 1 \
         && [lindex $r1_after end] eq "DEFINE NORMAL NORMAL"}] \
  "(added='[lindex $r1_after end]')"

# === R2 -- THE FOLDER THAT HOLDS THE LIBRARY LIST IS REFUSED =================
set r2rc [catch {library_new ROOTLIB $tmp} r2e]
check "R2a picking the folder that holds your library list is refused" \
  [expr {$r2rc == 1}] "(rc=$r2rc err='$r2e')"
check "R2b the refusal names the folder the user picked" \
  [has_text $r2e [file normalize $tmp]] "(err='$r2e')"
check "R2c the refusal says in plain words that this folder holds the library list" \
  [expr {[has_text $r2e "library list"] && [has_text $r2e "library.defs"]}] "(err='$r2e')"
check "R2d nothing called ROOTLIB was added to the libraries" \
  [expr {[library_resolve ROOTLIB] eq {}}] "(=> '[library_resolve ROOTLIB]')"
check "R2e no ROOTLIB line was written into the library list" \
  [expr {![defs_has_define $defsA ROOTLIB]}] "(lines=[llength [defs_lines $defsA]])"

# === R3 -- A FOLDER THAT IS ALREADY A LIBRARY IS REFUSED =====================
# The path is handed over already tidy, so this row is about the check itself
# and not about spelling -- R5 covers spelling.
set r3rc [catch {library_new INSIDE_A [file join $tmp libA]} r3e]
check "R3a picking a folder that is already one of your libraries is refused" \
  [expr {$r3rc == 1}] "(rc=$r3rc err='$r3e')"
check "R3b the refusal names the library that folder already is" \
  [has_text $r3e "libA"] "(err='$r3e')"
check "R3c nothing called INSIDE_A was added to the libraries" \
  [expr {[library_resolve INSIDE_A] eq {}}] "(=> '[library_resolve INSIDE_A]')"
check "R3d no INSIDE_A line was written into the library list" \
  [expr {![defs_has_define $defsA INSIDE_A]}] {}

# === R4 -- A REFUSED PRESS LEAVES NO EMPTY FOLDER BEHIND =====================
# ghost is a library whose folder does not exist yet, so this is the one row
# that can see whether the checks run before or after the folder is created.
set ghostdir [file join $tmp ghostdir]
set r4rc [catch {library_new GHOST2 $ghostdir} r4e]
check "R4a a folder that is a library only on paper is refused too, by name" \
  [expr {$r4rc == 1 && [has_text $r4e "ghost"]}] "(rc=$r4rc err='$r4e')"
check "R4b the refused press did not leave an empty folder behind" \
  [expr {![file exists $ghostdir]}] "(exists=[file exists $ghostdir] => $ghostdir)"

# === R5 -- ODD SPELLINGS OF THE SAME FOLDER DO NOT SLIP PAST =================
set r5arc [catch {library_new SLASHY [file join $tmp libA]/} r5ae]
check "R5a a trailing slash does not get past the refusal" \
  [expr {$r5arc == 1 && [has_text $r5ae "libA"]}] "(rc=$r5arc err='$r5ae')"
set r5brc [catch {library_new DOTTY [file join $tmp libB .. libA]} r5be]
check "R5b a path written the long way round does not get past the refusal" \
  [expr {$r5brc == 1 && [has_text $r5be "libA"]}] "(rc=$r5brc err='$r5be')"
set r5crc [catch {library_new INSIDE_C [file join $tmp libC]} r5ce]
check "R5c an oddly written entry in the library list is still recognised" \
  [expr {$r5crc == 1 && [has_text $r5ce "libC"]}] "(rc=$r5crc err='$r5ce')"

# === R6/R7 -- FIXTURE B: a library that came from the search path ============
# By default every folder on the search path is already a library the user can
# see in the Library pane, even with no line in any library list. The check has
# to see those too.
set tmp2 [test_scratch lib0799b]
file mkdir [file join $tmp2 autolib] [file join $tmp2 autolib2]
set defsB [file join $tmp2 library.defs]
set fp [open $defsB w]; puts $fp "# fixture B for issue 0799"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defsB
set ::pathlist [list "$tmp2/./autolib" [file join $tmp2 autolib2]]

check "R6a with the usual settings a plain search-path folder is already a library" \
  [expr {[library_resolve autolib] ne {}}] "(=> '[library_resolve autolib]')"
set r6rc [catch {library_new SECOND [file join $tmp2 autolib]} r6e]
check "R6b giving that folder a second name is refused, and the refusal names it" \
  [expr {$r6rc == 1 && [has_text $r6e "autolib"]}] "(rc=$r6rc err='$r6e')"

# R7 -- the Cadence-style setup, where the search path is NOT a library source.
# There a search-path folder is not a library yet, so naming it is the ordinary
# way to adopt it and must stay allowed. This row is what proves the check did
# not reach further than it was asked to.
#
# autolib2 and NOT autolib, which is what this row used to use: a control has to
# be independent of the row above it. Measured under mutations S3 and S6 -- both
# break R6b, so SECOND really does get written into fixture B's library list,
# so autolib then HAS an owner, so R7 fails as well and the mutation looks like
# it broke the control too. A row that only passes when the row above it passed
# is not a control. autolib2 is named by nothing and reached by nothing else.
set ::library_registry_defs_only 1
set r7rc [catch {library_new SECOND2 [file join $tmp2 autolib2]} r7e]
check "R7 in the Cadence-style setup a search-path folder is not a library yet, so naming it is allowed" \
  [expr {$r7rc == 0}] "(rc=$r7rc err='$r7e')"
set ::library_registry_defs_only 0

# back to fixture A
set ::XSCHEM_LIBRARY_DEFS $defsA
set ::pathlist {}

# === R8 -- THE PARTS NO BEHAVIOUR CAN SEE ====================================
set lnbody {}
if {[info commands library_new] ne {}} { set lnbody [info body library_new] }
# THE COMMENTS COME OUT FIRST (issue 0996). A whole-line "#" comment inside the
# proc body is matched by string first exactly like code is, and there is a long
# note inside library_new that names every word these rows look for. Until this
# strip went in, R8a and R8d were reading THAT NOTE and reporting on the checks:
# a tree with BOTH folder checks deleted and the note left alone reddened 18
# behavioural rows and left R8a and R8d saying "ok". R8c is the one row whose
# subject really IS the note, so it keeps the raw body.
set lncode $lnbody
regsub -all -line {^[ \t]*#[^\n]*$} $lnbody {} lncode
set r8a_list [has_text $lncode "library_dir_listfile"]
set r8a_own  [has_text $lncode {set owner [library_dir_owner}]
check "R8a both folder checks sit in the one place every New library press goes through" \
  [expr {$r8a_list && $r8a_own}] "(listfile-check=$r8a_list owner-check=$r8a_own)"
if {[info commands library_dir_owner] eq {}} {
  check "R8b1 the folder-to-library lookup names the library that owns a folder" 0 \
    "(there is no library_dir_owner)"
  check "R8b2 the folder-to-library lookup stays quiet about a folder no library owns" 0 \
    "(there is no library_dir_owner)"
  check "R8b3 the lookup recognises that same folder written with a trailing slash" 0 \
    "(there is no library_dir_owner)"
  check "R8b4 and written the long way round, out through another folder and back" 0 \
    "(there is no library_dir_owner)"
} else {
  set r8own NONE
  catch {set r8own [library_dir_owner [file join $tmp libA]]}
  check "R8b1 the folder-to-library lookup names the library that owns a folder" \
    [expr {$r8own eq "libA"}] "(=> '$r8own')"
  file mkdir [file join $tmp plainfolder]
  set r8non NONE
  catch {set r8non [library_dir_owner [file join $tmp plainfolder]]}
  check "R8b2 the folder-to-library lookup stays quiet about a folder no library owns" \
    [expr {$r8non eq {}}] "(=> '$r8non')"
  # R8b3/R8b4 -- issue 0995. R5a and R5b look like they cover this and they do
  # not: library_new tidies the path BEFORE it calls the lookup, so no row that
  # goes through library_new can reach the untidy branch, and the two rows above
  # hand over paths that are already tidy. Deleting the lookup's own tidy-up left
  # both arms at ALL PASS. These two ask the lookup directly, the way the next
  # caller will -- a folder name typed into a box, or one that came back from a
  # directory picker, neither of which arrives tidy.
  set r8slash NONE
  catch {set r8slash [library_dir_owner "[file join $tmp libA]/"]}
  check "R8b3 the lookup recognises that same folder written with a trailing slash" \
    [expr {$r8slash eq "libA"}] "(=> '$r8slash')"
  set r8dot NONE
  catch {set r8dot [library_dir_owner [file join $tmp libB .. libA]]}
  check "R8b4 and written the long way round, out through another folder and back" \
    [expr {$r8dot eq "libA"}] "(=> '$r8dot')"
}
check "R8c the note recording which check lives where, and why, is still there" \
  [expr {[has_text [string tolower $lnbody] "structural"] \
         && [has_text $lnbody "vimport::create_library"]}] \
  "(structural=[has_text [string tolower $lnbody] {structural}] vimport=[has_text $lnbody {vimport::create_library}])"
set r8io [string first {set owner [library_dir_owner} $lncode]
set r8im [string first "file mkdir" $lncode]
check "R8d the checks run before the folder is created, not after" \
  [expr {$r8io >= 0 && $r8im >= 0 && $r8io < $r8im}] "(check-at=$r8io mkdir-at=$r8im)"

# === R9 -- THE REFUSAL REACHES THE STATUS LINE, WORD FOR WORD ================
# MGRROOT and not ROOTLIB: on an UNFIXED tree R2 above has already registered
# ROOTLIB, so re-using the name here would be refused for the wrong reason
# ("that name is taken") and this row would go green while the defect is live.
#
# The same trap one level down, measured under mutation S1: R2's success does not
# only take the NAME, it takes the FOLDER -- ROOTLIB's path becomes this very
# folder, so MGRROOT is then refused by the OTHER check ("that folder is already
# the library 'ROOTLIB'") and all three R9 rows went green on a tree with the
# folder-that-holds-the-list check deleted. Take R2's registration back out, so
# what R9 sees is only what R9 asked about. On a healthy tree R2 registered
# nothing and this is a no-op.
catch {library_unregister ROOTLIB}
set r9rc [catch {libmgr::do_new_library MGRROOT $tmp} r9r]
check "R9a the Library Manager's New library refuses the same folder" \
  [expr {$r9rc == 0 && $r9r == 0}] "(rc=$r9rc result='$r9r')"
set r9status {}
if {[info exists ::libmgr::last_status]} { set r9status $::libmgr::last_status }
check "R9b the sentence the user reads names the folder they picked" \
  [has_text $r9status [file normalize $tmp]] "(status='$r9status')"
set r9prc [catch {library_new PROBE $tmp} r9pe]
check "R9c it is the SAME sentence, not a second one written somewhere else" \
  [expr {$r9prc == 1 && $r9pe ne {} && $r9status ne {} && [has_text $r9status $r9pe]}] \
  "(refusal='$r9pe' status='$r9status')"

# --- clear anything an unfixed run registered, so the window rows start clean -
foreach n {ROOTLIB MGRROOT INSIDE_A GHOST2 SLASHY DOTTY INSIDE_C PROBE SECOND SECOND2} {
  catch {library_unregister $n}
}

# === R10-R13 -- THE NEW-LIBRARY WINDOW =======================================
if {[info commands winfo] eq {}} {
  puts "note: no Tk in this session -- the New-library window rows are display-arm only"
} else {
  set ::active_poll none
  library_manager
  update idletasks

  # ---- A WINDOW THAT WILL NOT LET GO IS A HANG, NOT A RED (issue 0998) ------
  # Every row below drives libmgr::ctx_new_library, which since 0799 re-opens the
  # New-library window until it is told to stop. If that loop ever loses its way
  # out, these rows do not fail -- the suite STOPS, with no RESULT line and no
  # OVERALL line, and it is registered in tests/run_regression.tcl's dcases, so
  # it would take the whole regression run down with it. Measured: deleting the
  # loop's one way out gave exit 124 at a 90 s timeout, 33 ok rows, and R12a --
  # the row written to catch exactly that -- never ran at all.
  #
  # So the pollers below hand over to this watchdog the moment they stop
  # watching: the next window the loop tries to open raises an error instead of
  # opening, which unwinds ctx_new_library and turns the hang into red rows that
  # say what happened. Setting the dialog's done flag cannot do this job -- a
  # broken loop reads that as one more Cancel and opens the window again.
  set ::nl_wd_tripped 0
  set ::nl_wd_fired 0
  rename ::libmgr::newlib_dialog ::libmgr::real_newlib_dialog
  proc ::libmgr::newlib_dialog {{name {}} {path {}} {msg {}}} {
    if {$::nl_wd_tripped} {
      incr ::nl_wd_fired
      error "watchdog: the New library window kept coming back after the test stopped answering it"
    }
    return [::libmgr::real_newlib_dialog $name $path $msg]
  }
  # called from every poller branch that returns without scheduling itself again
  proc nl_wd_stop_watching {} { set ::nl_wd_tripped 1 }

  # --- R10 -- the window can be opened holding a name, a directory and a reason
  proc r10_probe {} {
    set ::r10_name NONE
    set ::r10_path NONE
    set ::r10_msg_exists 0
    set ::r10_msg NONE
    catch {set ::r10_name [.libmgr.nl.name get]}
    catch {set ::r10_path [.libmgr.nl.pf.path get]}
    catch {set ::r10_msg_exists [winfo exists .libmgr.nl.msg]}
    if {$::r10_msg_exists} { catch {set ::r10_msg [.libmgr.nl.msg cget -text]} }
    catch {set ::libmgr::dlg_done 0}
  }
  set ::r10_name NONE ; set ::r10_path NONE ; set ::r10_msg_exists 0 ; set ::r10_msg NONE
  set r10aid [after 250 r10_probe]
  set r10rc [catch {libmgr::newlib_dialog SEEDNAME /seed/path {REFUSAL TEXT 0799}} r10res]
  catch {after cancel $r10aid}
  catch {destroy .libmgr.nl}
  check "R10a the New-library window can come back holding the name you typed" \
    [expr {$::r10_name eq "SEEDNAME"}] "(rc=$r10rc err='$r10res' name='$::r10_name')"
  check "R10b and holding the directory you typed" \
    [expr {$::r10_path eq "/seed/path"}] "(rc=$r10rc path='$::r10_path')"
  check "R10c and showing the reason at the top of the window" \
    [expr {$::r10_msg_exists && [has_text $::r10_msg "REFUSAL TEXT 0799"]}] \
    "(rc=$r10rc shown=$::r10_msg_exists text='$::r10_msg')"

  set ::r10_msg_exists 0
  set r10bid [after 250 r10_probe]
  set r10brc [catch {libmgr::newlib_dialog} r10bres]
  catch {after cancel $r10bid}
  catch {destroy .libmgr.nl}
  check "R10d an ordinary New-library window carries no reason line at all" \
    [expr {$r10brc == 0 && $::r10_msg_exists == 0}] "(rc=$r10brc shown=$::r10_msg_exists)"

  # --- R11 -- refused: the window comes back with what you typed and why ------
  # The window is destroyed and rebuilt between tries, so a marker child widget
  # is how we tell the second window from the first.
  set ::r11_dir $tmp
  set ::r11_polls 0 ; set ::r11_state 0 ; set ::r11_gen2 0 ; set ::r11_done none
  set ::r11_name NONE ; set ::r11_path NONE ; set ::r11_msg NONE ; set ::r11_msg_exists 0
  proc r11_poll {} {
    if {$::active_poll ne "r11"} return
    incr ::r11_polls
    if {$::r11_polls > 60} {
      set ::r11_done capped
      nl_wd_stop_watching
      catch {set ::libmgr::dlg_done 0}
      return
    }
    if {[winfo exists .libmgr.nl]} {
      if {$::r11_state == 0} {
        catch {frame .libmgr.nl.__gen1}
        catch {.libmgr.nl.name delete 0 end ; .libmgr.nl.name insert 0 ROOTLIB}
        catch {.libmgr.nl.pf.path delete 0 end ; .libmgr.nl.pf.path insert 0 $::r11_dir}
        set ::r11_state 1
        catch {set ::libmgr::dlg_done 1}
        after 60 r11_poll
        return
      } elseif {$::r11_state == 1 && ![winfo exists .libmgr.nl.__gen1]} {
        set ::r11_gen2 1
        catch {set ::r11_name [.libmgr.nl.name get]}
        catch {set ::r11_path [.libmgr.nl.pf.path get]}
        catch {set ::r11_msg_exists [winfo exists .libmgr.nl.msg]}
        if {$::r11_msg_exists} { catch {set ::r11_msg [.libmgr.nl.msg cget -text]} }
        set ::r11_state 2
        set ::r11_done seen2
        nl_wd_stop_watching
        catch {set ::libmgr::dlg_done 0}
        return
      }
    }
    after 60 r11_poll
  }
  set ::active_poll r11
  after 60 r11_poll
  set r11rc [catch {libmgr::ctx_new_library} r11res]
  # If the window does not come back, nothing is pumping the event loop any
  # more, so pump it here rather than waiting for a person.
  for {set i 0} {$i < 110 && $::r11_done eq "none"} {incr i} {
    update
    after 40 {set ::r11_tick 1}
    vwait ::r11_tick
  }
  set ::active_poll none
  catch {destroy .libmgr.nl}
  check "R11a a refused New library brings the window back instead of closing over it" \
    [expr {$::r11_gen2 == 1}] "(outcome=$::r11_done polls=$::r11_polls rc=$r11rc err='$r11res')"
  check "R11b the window that comes back still holds what you typed" \
    [expr {$::r11_name eq "ROOTLIB" && $::r11_path eq $tmp}] \
    "(name='$::r11_name' path='$::r11_path')"
  check "R11c and it tells you why, naming the folder" \
    [expr {$::r11_msg_exists && [has_text $::r11_msg [file normalize $tmp]]}] \
    "(shown=$::r11_msg_exists text='$::r11_msg')"
  check "R11d and after Cancel nothing was added to the libraries" \
    [expr {$r11rc == 0 && [library_resolve ROOTLIB] eq {}}] \
    "(rc=$r11rc => '[library_resolve ROOTLIB]')"
  set r11sb NONE
  catch {set r11sb [.libmgr.status cget -text]}
  check "R11e the Library Manager status line still carries the reason too" \
    [has_text $r11sb [file normalize $tmp]] "(status='$r11sb')"

  # --- R12 -- Cancel always gets you out ------------------------------------
  set ::r12_polls 0 ; set ::r12_state 0 ; set ::r12_gen2 0 ; set ::r12_done none
  proc r12_poll {} {
    if {$::active_poll ne "r12"} return
    incr ::r12_polls
    if {$::r12_polls > 40} {
      set ::r12_done capped
      nl_wd_stop_watching
      catch {set ::libmgr::dlg_done 0}
      return
    }
    if {[winfo exists .libmgr.nl]} {
      if {$::r12_state == 0} {
        catch {frame .libmgr.nl.__gen1}
        set ::r12_state 1
        catch {set ::libmgr::dlg_done 0}
        after 60 r12_poll
        return
      } elseif {$::r12_state == 1 && ![winfo exists .libmgr.nl.__gen1]} {
        set ::r12_gen2 1
        set ::r12_done seen2
        nl_wd_stop_watching
        catch {set ::libmgr::dlg_done 0}
        return
      }
    }
    if {$::r12_state == 1 && $::r12_polls > 12} { set ::r12_done onlyone ; nl_wd_stop_watching ; return }
    after 60 r12_poll
  }
  set r12_before [lsort [libmgr::lib_names]]
  set ::nl_wd_tripped 0
  set ::active_poll r12
  after 60 r12_poll
  set r12rc [catch {libmgr::ctx_new_library} r12res]
  for {set i 0} {$i < 40 && $::r12_done eq "none"} {incr i} {
    update
    after 40 {set ::r12_tick 1}
    vwait ::r12_tick
  }
  set ::active_poll none
  catch {destroy .libmgr.nl}
  set r12_after [lsort [libmgr::lib_names]]
  check "R12a Cancel still gets you out of New library for good" \
    [expr {$r12rc == 0 && $::r12_done ne "capped"}] "(rc=$r12rc outcome=$::r12_done err='$r12res')"
  check "R12b Cancel added nothing to the libraries" \
    [expr {$r12_before eq $r12_after}] "(before='$r12_before' after='$r12_after')"
  check "R12c Cancel did not re-open the window" \
    [expr {$::r12_gen2 == 0}] "(outcome=$::r12_done polls=$::r12_polls)"

  # --- R13 -- the ordinary press, through the window this time ---------------
  set ::r13_polls 0 ; set ::r13_state 0 ; set ::r13_gen2 0 ; set ::r13_done none
  proc r13_poll {} {
    if {$::active_poll ne "r13"} return
    incr ::r13_polls
    if {$::r13_polls > 40} {
      set ::r13_done capped
      nl_wd_stop_watching
      catch {set ::libmgr::dlg_done 0}
      return
    }
    if {[winfo exists .libmgr.nl]} {
      if {$::r13_state == 0} {
        catch {frame .libmgr.nl.__gen1}
        catch {.libmgr.nl.name delete 0 end ; .libmgr.nl.name insert 0 FRESHLIB}
        catch {.libmgr.nl.pf.path delete 0 end}
        set ::r13_state 1
        catch {set ::libmgr::dlg_done 1}
        after 60 r13_poll
        return
      } elseif {$::r13_state == 1 && ![winfo exists .libmgr.nl.__gen1]} {
        set ::r13_gen2 1
        set ::r13_done seen2
        nl_wd_stop_watching
        catch {set ::libmgr::dlg_done 0}
        return
      }
    }
    if {$::r13_state == 1 && $::r13_polls > 12} { set ::r13_done onlyone ; nl_wd_stop_watching ; return }
    after 60 r13_poll
  }
  set ::nl_wd_tripped 0
  set ::active_poll r13
  after 60 r13_poll
  set r13rc [catch {libmgr::ctx_new_library} r13res]
  for {set i 0} {$i < 40 && $::r13_done eq "none"} {incr i} {
    update
    after 40 {set ::r13_tick 1}
    vwait ::r13_tick
  }
  set ::active_poll none
  catch {destroy .libmgr.nl}
  check "R13a a New library with a blank Directory is accepted first time, no second window" \
    [expr {$r13rc == 0 && $::r13_gen2 == 0}] "(rc=$r13rc outcome=$::r13_done err='$r13res')"
  check "R13b it appears in the Library pane" \
    [expr {[library_resolve FRESHLIB] ne {}}] "(=> '[library_resolve FRESHLIB]')"
  check "R13c and it sits inside the folder that holds the library list" \
    [expr {[file normalize [library_resolve FRESHLIB]] eq [file normalize [file join $tmp FRESHLIB]]}] \
    "(=> '[library_resolve FRESHLIB]' want '[file join $tmp FRESHLIB]')"

  # --- R15 -- the window going away is a way out too -------------------------
  # Issue 0998, the other half of it. The re-prompt loop's ONE way out is "the
  # window returned nothing". The window's own close button -- the X in its
  # title bar -- was wired to nothing at all, so pressing it made the window
  # disappear while New library went on waiting for an answer that could never
  # arrive; closing the Library Manager took this window with it the same way.
  # Both now mean what Cancel means. This row makes the window vanish without
  # anybody answering it and asks whether New library came back.
  set ::r15_polls 0 ; set ::r15_state 0 ; set ::r15_gen2 0 ; set ::r15_done none
  set ::r15_proto NONE ; set ::r15_rescued 0
  set ::nl_wd_tripped 0
  proc r15_poll {} {
    if {$::active_poll ne "r15"} return
    incr ::r15_polls
    if {$::r15_polls > 40} {
      set ::r15_done capped
      nl_wd_stop_watching
      catch {set ::libmgr::dlg_done 0}
      return
    }
    if {[winfo exists .libmgr.nl]} {
      if {$::r15_state == 0} {
        catch {set ::r15_proto [wm protocol .libmgr.nl WM_DELETE_WINDOW]}
        catch {frame .libmgr.nl.__gen1}
        set ::r15_state 1
        catch {destroy .libmgr.nl}
        after 60 r15_poll
        return
      } elseif {$::r15_state == 1 && ![winfo exists .libmgr.nl.__gen1]} {
        set ::r15_gen2 1
        set ::r15_done seen2
        nl_wd_stop_watching
        catch {set ::libmgr::dlg_done 0}
        return
      }
    }
    if {$::r15_state == 1 && $::r15_polls > 12} {
      # The window is gone. If New library is STILL waiting -- the dialog sets
      # its done flag to -1 just before it waits, and nothing has changed it --
      # then nothing ended the wait, which IS the defect. Poke it, and remember
      # that we had to, so the row below reports a red instead of the suite
      # stopping dead with no banner.
      if {[info exists ::libmgr::dlg_done] && $::libmgr::dlg_done == -1} {
        set ::r15_rescued 1
        catch {set ::libmgr::dlg_done 0}
      }
      set ::r15_done gone
      nl_wd_stop_watching
      return
    }
    after 60 r15_poll
  }
  set r15_before [lsort [libmgr::lib_names]]
  set ::active_poll r15
  after 60 r15_poll
  set r15rc [catch {libmgr::ctx_new_library} r15res]
  for {set i 0} {$i < 40 && $::r15_done eq "none"} {incr i} {
    update
    after 40 {set ::r15_tick 1}
    vwait ::r15_tick
  }
  set ::active_poll none
  catch {destroy .libmgr.nl}
  check "R15a the New-library window's close button is wired to a way out" \
    [expr {$::r15_proto ne {} && $::r15_proto ne "NONE"}] "(handler='$::r15_proto')"
  check "R15b a New-library window that goes away unanswered does not leave New library waiting" \
    [expr {$r15rc == 0 && $::r15_rescued == 0 && $::r15_done ne "capped"}] \
    "(rc=$r15rc outcome=$::r15_done had-to-poke-it=$::r15_rescued err='$r15res')"
  check "R15c and nothing was added to the libraries" \
    [expr {$r15_before eq [lsort [libmgr::lib_names]]}] \
    "(before='$r15_before' after='[lsort [libmgr::lib_names]]')"
  check "R15d in every row above the window let go when it was told to, with no rescue" \
    [expr {$::nl_wd_fired == 0}] "(rescues=$::nl_wd_fired)"

  # put the real New-library window back, so nothing after this point runs
  # against the watchdog wrapper
  rename ::libmgr::newlib_dialog {}
  rename ::libmgr::real_newlib_dialog ::libmgr::newlib_dialog
}

# === R14 -- THE LIBRARY LIST IS NOT ALWAYS CALLED library.defs ===============
# Issue 0997. XSCHEM_LIBRARY_DEFS names a FILE and puts no requirement on what it
# is called -- the whole format is the Cadence cds.lib analog and people do call
# it cds.lib. The first version of this refusal looked for a file literally
# called library.defs sitting in the folder, and then told the user, in the
# sentence they read, that the folder holds THEIR library list. Two different
# questions, and the gap was reachable both ways.
set tmp3 [test_scratch lib0799c]
file mkdir [file join $tmp3 libX] [file join $tmp3 libY]
set defsC [file join $tmp3 cds.lib]
set fp [open $defsC w]
puts $fp "# fixture C for issue 0997 -- the list is called cds.lib, not library.defs"
puts $fp "DEFINE libX libX"
puts $fp "DEFINE libY libY"
close $fp
set ::XSCHEM_LIBRARY_DEFS $defsC
set ::pathlist {}

set r14rc [catch {library_new JUNK $tmp3} r14e]
check "R14a the folder that holds your library list is refused even when the list is not called library.defs" \
  [expr {$r14rc == 1}] "(rc=$r14rc err='$r14e')"
check "R14b and the refusal names the list file the user actually has" \
  [expr {[has_text $r14e "cds.lib"] && ![has_text $r14e "library.defs"]}] "(err='$r14e')"
check "R14c nothing called JUNK was written into that library list" \
  [expr {[library_resolve JUNK] eq {} && ![defs_has_define $defsC JUNK]}] \
  "(=> '[library_resolve JUNK]')"

# The other direction. A folder holding SOMEBODY ELSE'S library list -- another
# project's tree, a PDK you checked out -- is still refused, because it is still
# a folder that holds libraries. What it must NOT do is call that list yours:
# it is not one of the lists this session reads, and a sentence saying otherwise
# states a fact nobody measured (D5-1).
set foreignroot [file join $tmp3 foreignroot]
file mkdir $foreignroot
set fp [open [file join $foreignroot library.defs] w]
puts $fp "# some other project's library list"
close $fp
set r14drc [catch {library_new FOREIGN $foreignroot} r14de]
check "R14d a folder holding some other project's library list is refused too" \
  [expr {$r14drc == 1}] "(rc=$r14drc err='$r14de')"
check "R14e and that refusal does not tell the user it is their own library list" \
  [expr {![has_text [string tolower $r14de] "your library list"]}] "(err='$r14de')"

# --- hand the session back ---------------------------------------------------
if {$saved_defs ne {}} { set ::XSCHEM_LIBRARY_DEFS $saved_defs } else { catch {unset ::XSCHEM_LIBRARY_DEFS} }
set ::pathlist $saved_path
if {$saved_conf ne {}} { set ::USER_CONF_DIR $saved_conf } else { catch {unset ::USER_CONF_DIR} }
set ::library_registry_defs_only $saved_only
set ::library_personal_defs $saved_pers

# --- verdict -----------------------------------------------------------------
# THE DUAL BANNER IS REQUIRED BY tests/run_regression.tcl's hcases list, which
# this file is registered in. banner_complete needs a WHOLE-LINE "OVERALL: ok"
# as well as the RESULT line; registering a suite there without one reproduces
# the completion-sentinel false red filed four times as 0420 / 0492 / 0629 / 0689.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
