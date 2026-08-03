#!/usr/bin/env wish
# pdk_launcher.tcl — pick a PDK, pick a log directory, launch xschem.
#
# Replaces having to remember and retype
#     src/xschem --script sky130A/cadence_style_rc --logdir /tmp
#
# The PDK list is DISCOVERED, not hard-coded: every immediate subdirectory of the
# repo that contains a `cadence_style_rc` becomes an entry, so a new workarea
# shows up here the moment it is created — nothing in this file needs editing.
# Two synthetic entries are always offered: the repo's own Cadence UX with no
# PDK, and plain xschem with no rc at all.
#
# Settings persist to ~/.xschem/pdk_launcher.conf so the next launch starts where
# the last one left off.
#
# Run:  ./pdk_launcher.sh          (from the repo root)
#   or: wish tools/launcher/pdk_launcher.tcl

# Skipped under ::PDK_LAUNCHER_NO_UI so the headless test can source this file
# with a plain tclsh, no display required.
if {![info exists ::PDK_LAUNCHER_NO_UI]} { package require Tk }

# ---------------------------------------------------------------------------
# Locate the repo from THIS script (tools/launcher/pdk_launcher.tcl), so the
# launcher works from any cwd.
# ---------------------------------------------------------------------------
set REPO [file normalize [file join [file dirname [info script]] .. ..]]
set XSCHEM [file join $REPO src xschem]
set CONF [file join $::env(HOME) .xschem pdk_launcher.conf]

# ---------------------------------------------------------------------------
# Discover PDK workareas.  Returns a list of {label rcpath} pairs.
# ---------------------------------------------------------------------------
# A workarea is a directory holding BOTH a cadence_style_rc and its own library
# registry. The registry is what separates a real PDK workarea from src/, which
# also ships a cadence_style_rc (the repo's plain Cadence UX) but is not a PDK —
# that one is offered as a synthetic entry below instead.
proc discover_pdks {repo} {
    set out {}
    foreach d [lsort [glob -nocomplain -type d [file join $repo *]]] {
        set rc [file join $d cadence_style_rc]
        if {![file isfile $rc]} { continue }
        if {![file isfile [file join $d xschem_libs library.defs]]} { continue }
        lappend out [list [file tail $d] $rc]
    }
    return $out
}

set PDKS [discover_pdks $REPO]
# Synthetic entries. {} means "no --script at all".
lappend PDKS [list "(no PDK — repo Cadence UX)" [file join $REPO src cadence_style_rc]]
lappend PDKS [list "(plain xschem — no rc)" {}]

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
set S(pdk)      [lindex [lindex $PDKS 0] 0]
set S(logdir)   /tmp
set S(netdir)   ""
set S(cell)     ""
set S(extra)    ""
set S(norecent) 1
set S(quit)     0

# ---------------------------------------------------------------------------
# Config persistence — a plain `key value` file, one per line. Unknown keys are
# ignored so an older/newer launcher cannot choke on the file.
# ---------------------------------------------------------------------------
proc load_conf {} {
    global S CONF
    if {![file isfile $CONF]} { return }
    if {[catch {set f [open $CONF]} ]} { return }
    foreach line [split [read $f] \n] {
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} { continue }
        set k [lindex $line 0]
        set v [join [lrange $line 1 end]]
        if {[info exists S($k)] && $k ne "quit"} { set S($k) $v }
    }
    close $f
}

proc save_conf {} {
    global S CONF
    catch {file mkdir [file dirname $CONF]}
    if {[catch {set f [open $CONF w]}]} { return }
    puts $f "# xschem PDK launcher settings"
    foreach k {pdk logdir netdir cell extra norecent} {
        puts $f "$k $S($k)"
    }
    close $f
}

# ---------------------------------------------------------------------------
# Build the argv the way exec will receive it. Returns a Tcl LIST — the preview
# is only a rendering of this, so what you read is exactly what runs.
# ---------------------------------------------------------------------------
proc build_cmd {} {
    global S PDKS XSCHEM
    set cmd [list $XSCHEM]
    foreach pair $PDKS {
        if {[lindex $pair 0] eq $S(pdk)} {
            set rc [lindex $pair 1]
            if {$rc ne ""} { lappend cmd --script $rc }
            break
        }
    }
    if {[string trim $S(logdir)] ne ""} { lappend cmd --logdir [string trim $S(logdir)] }
    if {[string trim $S(netdir)] ne ""} { lappend cmd --netlist_path [string trim $S(netdir)] }
    # NOTE: there is deliberately no -q option here. In xschem `-q` is --quit
    # ("Quit after doing things (no interactive mode)"), NOT "quiet" -- this
    # launcher used to offer it as a quiet flag and default it ON, so every
    # launch opened a window and immediately exited. There is no quiet flag.
    if {$S(norecent)} { lappend cmd --norecent }
    foreach a [string trim $S(extra)] { lappend cmd $a }
    if {[string trim $S(cell)] ne ""} { lappend cmd [string trim $S(cell)] }
    return $cmd
}

# No-op before the UI exists, so the command-building logic can be exercised
# headlessly (tests/headless/test_pdk_launcher.tcl sources this file with
# ::PDK_LAUNCHER_NO_UI set).
proc refresh_preview {args} {
    global S
    if {![winfo exists .f.prev]} { return }
    .f.prev configure -state normal
    .f.prev delete 1.0 end
    .f.prev insert 1.0 [join [build_cmd] " "]
    # Grow to fit. A fixed height silently CLIPS the tail of the command — and the
    # tail is where the schematic and the flags land, i.e. exactly what you came to
    # check. Long workarea paths plus a long --logdir overflow 4 lines easily.
    # Counted in DISPLAY lines (post-wrap), not logical lines, which are always 1.
    set dl [.f.prev count -displaylines 1.0 end]
    if {$dl < 2} { set dl 2 }
    if {$dl > 8} { set dl 8 }   ;# cap, then it scrolls rather than eating the window
    .f.prev configure -height $dl
    .f.prev configure -state disabled
}

# ---------------------------------------------------------------------------
# Validation + launch
# ---------------------------------------------------------------------------
proc do_launch {} {
    global S XSCHEM
    if {![file executable $XSCHEM]} {
        tk_messageBox -icon error -title "xschem not built" -message \
            "No executable at:\n$XSCHEM\n\nBuild it first:  cd src && make"
        return
    }
    set ld [string trim $S(logdir)]
    if {$ld ne "" && ![file isdirectory $ld]} {
        if {[tk_messageBox -icon question -type yesno -title "Create log directory?" \
                -message "Log directory does not exist:\n$ld\n\nCreate it?"] eq "yes"} {
            if {[catch {file mkdir $ld} e]} {
                tk_messageBox -icon error -title "Cannot create" -message $e ; return
            }
        } else { return }
    }
    set nd [string trim $S(netdir)]
    if {$nd ne "" && ![file isdirectory $nd]} {
        if {[catch {file mkdir $nd} e]} {
            tk_messageBox -icon error -title "Cannot create netlist dir" -message $e ; return
        }
    }
    set cell [string trim $S(cell)]
    if {$cell ne "" && ![file isfile $cell]} {
        tk_messageBox -icon error -title "No such file" -message "Schematic not found:\n$cell"
        return
    }
    set cmd [build_cmd]
    # -q / --quit makes xschem "quit after doing things (no interactive mode)": the
    # window flashes up and disappears. Nothing here adds it, but it can still
    # arrive through Extra args, and the symptom (a launcher that appears to do
    # nothing) gives no hint of the cause — so name it.
    if {[lsearch -exact $cmd -q] >= 0 || [lsearch -exact $cmd --quit] >= 0} {
        if {[tk_messageBox -icon warning -type okcancel -title "-q means QUIT" -message \
             "The command contains -q / --quit.\n\nIn xschem that means \"quit after\
              doing things\" -- it is NOT a quiet flag. The window will open and close\
              immediately.\n\nLaunch anyway?"] ne "ok"} { return }
    }
    save_conf
    # Detached: the launcher must not die with the editor, and vice versa. stderr
    # is folded into the log dir when one was given, else left on the terminal.
    if {[catch {exec {*}$cmd &} e]} {
        tk_messageBox -icon error -title "Launch failed" -message $e
        return
    }
    set ::status "launched: [file tail [lindex $cmd 0]] ([clock format [clock seconds] -format %H:%M:%S])"
    if {$S(quit)} { exit 0 }
}

# ---------------------------------------------------------------------------
# UI
#
# Sourcing this file with ::PDK_LAUNCHER_NO_UI set loads the logic above and
# stops here — that is how the headless test drives build_cmd/discover_pdks
# without needing a window.
# ---------------------------------------------------------------------------
if {[info exists ::PDK_LAUNCHER_NO_UI]} { return }

load_conf
# A workarea named in the config may since have been removed.
set known 0
foreach pair $PDKS { if {[lindex $pair 0] eq $S(pdk)} { set known 1 } }
if {!$known} { set S(pdk) [lindex [lindex $PDKS 0] 0] }

wm title . "xschem — PDK launcher"
wm resizable . 1 0

# Force a theme that actually DRAWS its indicators and entry borders. The stock
# X11 default theme on this setup renders radio/check indicators and entry
# reliefs invisibly against a light background — the window looks like plain
# text and you cannot see which PDK is selected. clam is present in every Tk 8.5+
# and draws all three properly; fall back silently if a build lacks it.
catch {ttk::style theme use clam}

# Type scale: body 12 pt, heading 14 pt (Tk's stock defaults are 10 and 12).
# Configuring the NAMED fonts is what makes this stick — every ttk style resolves
# its -font to TkDefaultFont, so setting it here moves labels, radios,
# checkbuttons, buttons and entries together instead of per-widget. These named
# fonts are process-local, so nothing outside this launcher is affected.
font configure TkDefaultFont -size 12   ;# labels, radios, checks, buttons, entries
font configure TkTextFont    -size 12
font configure TkHeadingFont -size 12
font configure TkFixedFont   -size 12   ;# the Command preview text widget

# The heading is a named font derived from TkDefaultFont rather than the partial
# spec `{-weight bold}` it used before: a partial spec makes Tk fill family and
# size from the X resource default, which is why that label rendered 12 pt while
# everything around it was 10 — inconsistent by accident, not by intent.
font create PdkHeadingFont {*}[font actual TkDefaultFont]
font configure PdkHeadingFont -size 14 -weight bold

set f [ttk::frame .f -padding 10]
pack $f -fill both -expand 1

set r 0
ttk::label $f.lpdk -text "PDK" -font PdkHeadingFont
grid $f.lpdk -row $r -column 0 -sticky w -pady {0 2}
incr r

# radio per discovered workarea — a short list, and radios show every option at
# once, which a combobox would hide.
foreach pair $PDKS {
    set label [lindex $pair 0]
    set rc    [lindex $pair 1]
    set w $f.pdk$r
    # No second path column: it duplicated the label, clipped at the window edge,
    # and the Command preview below already shows the exact rc that will be used.
    ttk::radiobutton $w -text $label -value $label -variable S(pdk) -command refresh_preview
    grid $w -row $r -column 0 -columnspan 4 -sticky w -padx 12
    incr r
}

ttk::separator $f.sep1 -orient horizontal
grid $f.sep1 -row $r -column 0 -columnspan 4 -sticky ew -pady 8
incr r

proc dirrow {parent row label var {isfile 0}} {
    global S
    ttk::label $parent.l$row -text $label
    grid $parent.l$row -row $row -column 0 -sticky w
    ttk::entry $parent.e$row -textvariable S($var) -width 42
    grid $parent.e$row -row $row -column 1 -columnspan 2 -sticky ew -padx 4
    ttk::button $parent.b$row -text "Browse…" -width 9 -command [list browse $var $isfile]
    grid $parent.b$row -row $row -column 3 -sticky w
    bind $parent.e$row <KeyRelease> refresh_preview
}

proc browse {var isfile} {
    global S REPO
    if {$isfile} {
        set p [tk_getOpenFile -title "Select schematic" -initialdir $REPO \
                   -filetypes {{"Schematics" {.sch}} {"Symbols" {.sym}} {"All files" *}}]
    } else {
        set init $S($var)
        if {$init eq "" || ![file isdirectory $init]} { set init $REPO }
        set p [tk_chooseDirectory -title "Select directory" -initialdir $init -mustexist 0]
    }
    if {$p ne ""} { set S($var) $p ; refresh_preview }
}

dirrow $f $r "Log directory"     logdir ; incr r
dirrow $f $r "Netlist directory" netdir ; incr r
dirrow $f $r "Schematic (opt.)"  cell 1 ; incr r

ttk::label $f.lex -text "Extra args"
grid $f.lex -row $r -column 0 -sticky w
ttk::entry $f.eex -textvariable S(extra) -width 42
grid $f.eex -row $r -column 1 -columnspan 2 -sticky ew -padx 4
bind $f.eex <KeyRelease> refresh_preview
incr r

ttk::checkbutton $f.cr -text "don't touch Open Recent (--norecent)" \
    -variable S(norecent) -command refresh_preview
grid $f.cr -row $r -column 1 -columnspan 3 -sticky w -padx 4 -pady {6 0}
incr r

ttk::separator $f.sep2 -orient horizontal
grid $f.sep2 -row $r -column 0 -columnspan 4 -sticky ew -pady 8
incr r

ttk::label $f.lprev -text "Command"
grid $f.lprev -row $r -column 0 -sticky nw
text $f.prev -height 4 -width 52 -wrap word -relief flat -background [ttk::style lookup TFrame -background]
grid $f.prev -row $r -column 1 -columnspan 3 -sticky ew -padx 4
incr r

ttk::checkbutton $f.cquit -text "quit launcher after starting xschem" -variable S(quit)
grid $f.cquit -row $r -column 1 -columnspan 3 -sticky w -padx 4 -pady {6 0}
incr r

set bf [ttk::frame $f.btns]
grid $bf -row $r -column 0 -columnspan 4 -sticky ew -pady {10 0}
ttk::button $bf.launch -text "Launch" -command do_launch
ttk::button $bf.quit   -text "Quit"   -command {save_conf; exit 0}
pack $bf.quit -side right
pack $bf.launch -side right -padx {0 6}
set ::status ""
ttk::label $bf.st -textvariable ::status -foreground gray40
pack $bf.st -side left
incr r

grid columnconfigure $f 1 -weight 1
grid columnconfigure $f 2 -weight 1

bind . <Return> do_launch
bind . <Escape> {save_conf; exit 0}
refresh_preview
focus .f.btns.launch
