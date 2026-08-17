# gf180mcuD helper procs — GF180MCU menu.
#
# The open_pdks gf180mcuD xschem tree (SYSTEM, read-only) ships NO custom Tcl
# procs in its xschemrc (unlike sky130): device operating-point annotation is
# built into each primitive symbol as hidden tcleval(gm=..)/tcleval(id=..) T
# lines (toggle via layer visibility / the symbol's own probe text), and there
# is no PDK-specific DRC proc. So this file is intentionally small — a working
# GF180MCU menu shell to hang future PDK helpers off, plus the one genuinely
# useful entry: drop the models block that every gf180 testbench embeds.
#
# Requires $::180MCU_MODELS to be set by cadence_style_rc.

# Executed after each window finishes initialization (see user_startup_commands).
# Adds a GF180MCU menu, mirroring the SKY130 menu in ../sky130A/sky130_procs.tcl.
proc gf180_menupdk {} {
  global has_x
  if { ![info exists has_x] } { return }
  set topwin [xschem get top_path]

  # Idempotent: the rc calls this directly for the window that already exists AND
  # leaves it in user_startup_commands for windows created later, so for any one
  # window it can be reached twice; a second `menu` on the same path would error.
  if {[winfo exists $topwin.menubar.gf180mcu]} { return }

  # insert before the 'Netlist' menu
  $topwin.menubar insert Netlist cascade -label GF180MCU -menu $topwin.menubar.gf180mcu
  menu $topwin.menubar.gf180mcu -tearoff 0

  ## Drop the SPICE models block that every gf180 testbench uses. code_shown
  ## renders its contents on the schematic; only_toplevel keeps it out of subckts.
  $topwin.menubar.gf180mcu add command -label {Add models block (typical)} -command {
    xschem place_symbol devices/code_shown {
name=MODELS
only_toplevel=true
format="tcleval( @value )"
value="
.include $::180MCU_MODELS/design.ngspice
.lib $::180MCU_MODELS/sm141064.ngspice typical
"
spice_ignore=false
    }
  }

  ## Convenience: report where the models are vendored (useful when a .lib fails).
  $topwin.menubar.gf180mcu add command -label {Models path...} -command {
    if {[info exists ::180MCU_MODELS]} {
      tk_messageBox -type ok -icon info -title {GF180MCU models} \
        -message "180MCU_MODELS =\n$::180MCU_MODELS"
    } else {
      tk_messageBox -type ok -icon warning -title {GF180MCU models} \
        -message {180MCU_MODELS is not set.}
    }
  }
}

########################## op_annot descriptors (S2) #########################
# doc/claude/specs/op_annotation.md §4.2. gf180 has NO prototype save/display
# procs to port — annotation lives entirely inside the 19 FET symbols as
# `tcleval(gm=[ngspice::get_node …\@m.${path}@spiceprefix@name\.m0\[gm\]])`
# texts. Those texts are therefore the ORACLE for the descriptor below, and they
# are uniformly `m0` across all 19 nfet*/pfet* symbols (measured, not assumed).
#
# ⚠ THE TEMPLATE MUST BE ESCAPED — issue 0422. `xschem translate` tokenises on
# whitespace only (token.c:24), so an unescaped `.` does NOT terminate an
# @-token and an @-token that misses get_tok_value() appends NOTHING: the
# unescaped spelling yields a plausible wrong string with no error at all. The
# escaping below is the shipped symbols' own.
#
# ⚠ GUARDED, NOT MERELY APPENDED — see the same block in
# ../sky130A/sky130_procs.tcl for the measurement (a raise here abandons the
# rest of cadence_style_rc, menu and all, while still exiting 0). `register`'s
# own malformed-dict raise is deliberately NOT caught.
if {[info commands ::op_annot::register] ne {}} {
  # ⚠ BOTH nmos AND pmos (§4.2 registers only nmos; op_annot's key is an exact
  # index, not the prototypes' `[pn]mos` regexp).
  # ⚠ `match`: issue 0425 — `type=nmos` is shared with sky130, IHP and
  # xschem_library/devices/nmos.sym.
  foreach _gf180_op_type {nmos pmos} {
    op_annot::register $_gf180_op_type {
      devpath {\@m.@path@spiceprefix@name\.m0}
      match   {*gf180mcu_pr/*}
      params  {{id id 0} {gm gm 1} {gds gds 1} {vth vth 2} {vdsat vdsat 2}}
      derived {{gm/id {$gm/$id}}}
      pinexpr {{vgs {expr(@#1:spice_get_voltage - @#2:spice_get_voltage)}}
               {vds {expr(@#0:spice_get_voltage - @#2:spice_get_voltage)}}}
    }
  }
  unset _gf180_op_type
} else {
  puts stderr {gf180_procs.tcl: op_annot::register not available, OP annotation descriptors not registered}
}
