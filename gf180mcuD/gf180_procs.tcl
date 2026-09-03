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
  # ⚠ THE DEFAULT SIX — RULING D9 (the user, 2026-08-22). Spec §4.2a.
  #     id  gm  gds  vgs  vth  vds        and nothing else, on every PDK.
  # GONE from this descriptor: vdsat, and the derived row gm/id. "Too many
  # parameters displayed is just clutter."
  #
  # ⚠ vgs/vds ARE NOW params, NOT pinexpr, so this descriptor carries no pinexpr
  # at all and the load-bearing-space trap (issue 0444) and the fabricated
  # `vgs = 0` on a GND source (issue 0446) are OFF THE SHIPPED PATH. Neither C
  # defect is fixed; both remain reachable by a user-written pinexpr, and their
  # guardians live on test-local descriptors in test_op_annot.tcl.
  #
  # ⚠ MEASURED ON GF180 ITSELF, not inherited from the sky130 measurement —
  # nfet_03v3, models/design.ngspice + sm141064.ngspice typical, one deck, both
  # ngspice binaries, `.control … write … .endc`:
  #     rc=0 checkvalid=0 raw written on BOTH, with vectors
  #       i(@m.xm1.m0[id])  @m.xm1.m0[gm]  @m.xm1.m0[gds]
  #       v(@m.xm1.m0[vgs]) v(@m.xm1.m0[vth]) v(@m.xm1.m0[vds])
  # i.e. exactly the 0/1/2 kind convention already in the descriptor.
  #
  # RECOVERY for the old rows is one round-trip in a --script rc (invariant I5):
  #     set d [op_annot::descriptor nmos]
  #     dict set d params [concat [dict get $d params] {{vdsat vdsat 2}}]
  #     dict set d derived {{gm/id {$gm/$id}}}
  #     op_annot::register nmos $d
  # A first-class means for a user to choose her own set now EXISTS, and this
  # is it: the OP parameter list store, src/op_param_lists.tcl. It SEEDS from
  # the descriptor registered just below (ruling D-7 -- seed from the PDK, the
  # user's file wins per class) and keeps the user's own choice in
  # <project>/.xschem/op_param_lists.conf, with ~/.xschem/op_param_lists.conf as
  # the user-global fallback. That settings file is DATA and is never sourced
  # (ruling DD-3): a strict parser reads it and runs nothing in it, so it can be
  # shared with a teammate. See doc/claude/specs/op_param_lists.md section 4.4.
  # The RECOVERY round-trip above is untouched and is still the quickest way to
  # change one list from an rc (invariant I5, live on the next redraw).
  foreach _gf180_op_type {nmos pmos} {
    op_annot::register $_gf180_op_type {
      devpath {\@m.@path@spiceprefix@name\.m0}
      match   {*gf180mcu_pr/*}
      params  {{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}}
    }
  }
  unset _gf180_op_type
} else {
  puts stderr {gf180_procs.tcl: op_annot::register not available, OP annotation descriptors not registered}
}
