# sky130 helper procs (DRC, FET operating-point save/annotate, SKY130 menu).
# Extracted verbatim from the open_pdks PDK xschemrc (SYSTEM, read-only) so the
# workarea is self-contained. Requires $::SKYWATER_MODELS to be set by the rc.
# Path refs adapted to OA lib/cell form (registry-only mode).

proc sky130_fet_drc {instance symbol model w l {nf 1}} {
  set res {}
  # puts "$instance $model $symbol w=$w l=$l nf=$nf"
  if { [string is double $w] && [string is double $l] && [string is integer $nf]} {
    # not *_nf.sym devices: get single finger width
    if {![regexp {fet.*_nf\.sym$} $symbol]} {
      set w [expr { double($w) / double($nf)}]
    }
    switch -regexp $model {
      {[np]fet_01v8$} {
        if { $w < 0.42 } {
          append res "${instance} ($model): finger width is too small, w / nf = $w" \n
        }
        if { $l < 0.15 } {
          append res "${instance} ($model): length is too small, l = $l" \n
        }
      }
      {pfet_01v8_lvt$} {
        if { $w < 0.42 } {
          append res "${instance} ($model): finger width is too small, w / nf = $w" \n
        }
        if { $l < 0.35 } {
          append res "${instance} ($model): length is too small, l = $l" \n
        }
      }
      {nfet_01v8_lvt$} {
        if { $w < 0.42 } {
          append res "${instance} ($model): finger width is too small, w / nf = $w" \n
        }
        if { $l < 0.15 } {
          append res "${instance} ($model): length is too small, l = $l" \n
        }
      }
      {[np]fet_g5v0d10v5$} {
        if { $w < 0.42 } {
          append res "${instance} ($model): finger width is too small, w / nf = $w" \n
        }
        if { $l < 0.5 } {
          append res "${instance} ($model): length is too small, l = $l" \n
        }
      }
      {pfet_g5v0d16v0$} {
        if { $w < 5 } {
          append res "${instance} ($model): finger width is too small, w / nf = $w" \n
        }
        if { $l < 0.66 } {
          append res "${instance} ($model): length is too small, l = $l" \n
        }
      }
      {nfet_g5v0d16v0$} {
        if { $w < 5 } {
          append res "${instance} ($model): finger width is too small, w / nf = $w" \n
        }
        if { $l < 0.7 } {
          append res "${instance} ($model): length is too small, l = $l" \n
        }
      }
    } ;# switch
  }
  return $res
}




# writes the .save instructions for given FET instance 
proc sky130_write_save_lines {type model schpath spiceprefix instname} {
  global sky130_sch_expand
  if {[regexp {[pn]mos} $type]} {
    set m msky130_fd_pr__$model
    if {[regexp {g5v0d16} $model]} {set m xsky130_fd_pr__$model.msky130_fd_pr__${model}_base
    } elseif {[regexp {20v0_(iso|nvt)} $model]} {set m msky130_fd_pr__${model}_base
    } elseif {[regexp {20v0} $model]} {set m m1}
    set devpath [string tolower @m.$schpath$spiceprefix$instname.$m]

    append sky130_sch_expand(savelist) ".save $devpath\[gm\]\n"
    append sky130_sch_expand(savelist) ".save $devpath\[gds\]\n"
    append sky130_sch_expand(savelist) ".save $devpath\[vth\]\n"
    append sky130_sch_expand(savelist) ".save $devpath\[vdsat\]\n"
    append sky130_sch_expand(savelist) ".save $devpath\[cgg\]\n"
    append sky130_sch_expand(savelist) ".save $devpath\[cgso\]\n"
    append sky130_sch_expand(savelist) ".save $devpath\[cgdo\]\n"
  }
}

############ sky130_sch_expand
# This proc traverses the hierarchy and prints all instances in design.
proc sky130_sch_expand {{only_subckts 1} {all_hierarchy 1} {pattern {.*}}} {
  global sky130_sch_expand keep_symbols 
  set sky130_sch_expand(savelist) {}
  set sky130_sch_expand(only_subckts) $only_subckts
  set sky130_sch_expand(all_hierarchy) $all_hierarchy
  set sky130_sch_expand(startpath) [string length [xschem get sch_path]]
  set save_keep $keep_symbols
  set keep_symbols 1
  xschem unselect_all
  xschem set no_draw 1 ;# disable screen update
  xschem set no_undo 1 ;# disable undo 

  sky130_hier_sch_expand 0 $only_subckts $all_hierarchy $pattern

  xschem set no_draw 0
  xschem set no_undo 0
  set keep_symbols $save_keep
  return {}
}

# recursive procedure used by sky130_sch_expand
proc sky130_hier_sch_expand {{level 0} {only_subckts 0} {all_hierarchy 1} {pattern {.*}}} {
  global nolist_libs sky130_sch_expand

  set schpath [string range [xschem get sch_path] $sky130_sch_expand(startpath) end]
  set instances  [xschem get instances]
  for {set i 0} { $i < $instances} { incr i} {
    set instname [xschem getprop instance $i name]
    # puts "sky130_hier_sch_expand: instname=$instname schpath=$schpath"
    set symbol [xschem getprop instance $i cell::name]
    set spiceprefix [xschem getprop instance $i spiceprefix]
    set model [xschem translate $instname @model]
    set abs_symbol [abs_sym_path $symbol]
    set type [xschem getprop symbol $symbol type]

    if {$only_subckts && ($type ne {subcircuit})} { continue }
    set skip 0
    foreach j $nolist_libs {
      if {[regexp $j $abs_symbol]} {
        set skip 1
        break
      }
    }
    if {$skip} { continue }
    if {$type ne {subcircuit} && ![regexp $pattern $symbol]} {
      continue
    }

    sky130_write_save_lines $type $model $schpath $spiceprefix $instname
 
    if {$type eq {subcircuit} && $all_hierarchy} {
      set ninst [lindex [split [xschem expandlabel $instname] { }] 1]
      for {set n 1} {$n <= $ninst} { incr n} {
        if {$n == 1} {
          xschem select instance $i
          set res [xschem descend $n 2]
          # ensure previous descend was successful
          if {$res} {
            incr level
          } else { ;# descended into a blank schematic. Go back.
            xschem go_back 2
            puts "Can not descend into $instname"
            break
          }
        }
        if {$n > 1} {
          xschem change_sch_path $n
        }
        set dp [sky130_hier_sch_expand $level $only_subckts 1 $pattern]
        if {$n == $ninst} {
          xschem go_back 2
          incr level -1
        }
      }
    }
  }
  return 1
}
############ /sky130_sch_expand

# generate the .save lines to save all mos parameters
proc sky130_save_fet_params {} {
  global sky130_sch_expand
  sky130_sch_expand 0 1 {[pn]fet} 
  return "* Place this .save file with a .include line in your testbench\n\n$sky130_sch_expand(savelist)"
}

# displays mos parameters simulation data , used in symbol sky130_fd_pr/annotate_fet_params
proc sky130_display_fet_params {instname} {
  set txt {}
  set schpath [xschem get sim_sch_path]
  set symbol [xschem getprop instance $instname cell::name]
  set spiceprefix [xschem getprop instance $instname spiceprefix]
  set model [xschem translate $instname @model]
  set type [xschem getprop symbol $symbol type]

  if {[regexp {[pn]mos} $type]} {
    set m msky130_fd_pr__$model
    if {[regexp {g5v0d16} $model]} {set m xsky130_fd_pr__$model.msky130_fd_pr__${model}_base
    } elseif {[regexp {20v0_(iso|nvt)} $model]} {set m msky130_fd_pr__${model}_base
    } elseif {[regexp {20v0} $model]} {set m m1}
    set devpath [string tolower @m.$schpath$spiceprefix$instname.$m]

    append txt "gm    = [to_eng [xschem raw value $devpath\[gm\] -1]]\n"
    append txt "gds   = [to_eng [xschem raw value $devpath\[gds\] -1]]\n"
    append txt "vth   = [to_eng [xschem raw value v($devpath\[vth\]) -1]]\n"
    append txt "vdsat = [to_eng [xschem raw value v($devpath\[vdsat\]) -1]]\n"
    append txt "cgg   = [to_eng [xschem raw value $devpath\[cgg\] -1]]\n"
    append txt "cgdo  = [to_eng [xschem raw value $devpath\[cgdo\] -1]]\n"
    append txt "cgso  = [to_eng [xschem raw value $devpath\[cgso\] -1]]\n"
    set pi 3.141592654
    set gm [xschem raw value $devpath\[gm\] -1]
    set cgg [xschem raw value $devpath\[cgg\] -1]
    set cgdo [xschem raw value $devpath\[cgdo\] -1]
    set cgso [xschem raw value $devpath\[cgso\] -1]
    if {[catch { expr $gm / 2 / $pi / ($cgg + $cgdo + $cgso)} ft]} {
      set ft {}
    }
    append txt "ft    = [to_eng ${ft}]\n"
  }
  return $txt
}


# these commands are executed when xschem has completed initialization.
# add a SKY130 menu entry
proc sky130_menupdk {} {
  global has_x netlist_dir
  if { [info exist has_x] } {
    set topwin [xschem get top_path]

    # Idempotent: the rc calls this directly for the window that already exists
    # AND leaves it in user_startup_commands for windows created later, so for
    # any one window it can be reached twice; a second `menu` command on the same
    # path would error out.
    if {[winfo exists $topwin.menubar.sky130]} { return }

    # insert before the 'Netlist' menu
    $topwin.menubar insert Netlist cascade -label SKY130 -menu $topwin.menubar.sky130
    menu $topwin.menubar.sky130 -tearoff 0

    ## Create one entry
    $topwin.menubar.sky130 add command -label {Create FET .save file} -command {
      ## to save in simulation directory:
      write_data [sky130_save_fet_params] $netlist_dir/[file rootname [file tail [xschem get current_name]]].save
      textwindow $netlist_dir/[file rootname [file tail [xschem get current_name]]].save
      ## to save in schematic directory:
      # write_data [sky130_save_fet_params] [file rootname [xschem get schname]].save
      # textwindow [file rootname [xschem get schname]].save
    }
    ## Create one entry
    $topwin.menubar.sky130 add command -label {Add models symbol} -command {
      xschem place_symbol devices/code {
name=TT_MODELS
only_toplevel=true
format="tcleval( @value )"
value="
** opencircuitdesign pdks install
.lib $::SKYWATER_MODELS/sky130.lib.spice tt
"
spice_ignore=false
      }
    }

    ## Create one entry
    $topwin.menubar.sky130 add command -label {Add FET param annotator} -command {
      proc get_sel_inst_name {} {
        set selset [lindex [xschem selected_set] 0]
        if {$selset ne {}} {
          set name [xschem getprop instance $selset name]
          xschem place_symbol sky130_fd_pr/annotate_fet_params "name=annot1 ref=$name"
        } else {
          xschem place_symbol sky130_fd_pr/annotate_fet_params
        }
      }
      get_sel_inst_name
    }

  }
}

########################## op_annot descriptors (S2) #########################
# doc/claude/specs/op_annotation.md §4.2. These hand sky130's device-naming
# rules to the ONE generic name builder (src/op_annot.tcl) that invariant I1
# requires, so the save-card emitter and the on-screen display stop being two
# independent copies of the switch below.
#
# ⚠ A DEVPROC, NOT SPEC §4.2's SINGLE TEMPLATE. §4.2 shows
#   devpath {\@m.@path@spiceprefix@name\.msky130_fd_pr__@model}
# and that is wrong for three model families. sky130_write_save_lines:76-78 has
# FOUR inner-device spellings and `xschem translate` cannot express a switch.
# Measured on the shipped sky130_tests/test_nmos: the single template mismatches
# 35 of the prototype's 119 cards (the g5v0d16v0 and 20v0 families, e.g. proto
# `@m.xm6.xsky130_fd_pr__nfet_g5v0d16v0.msky130_fd_pr__nfet_g5v0d16v0_base[gm]`
# vs template `@m.xm6.msky130_fd_pr__nfet_g5v0d16v0[gm]`); the devproc below is
# byte-identical 119/119. Per landmine 9 a wrong name does not blank at read
# time — ngspice fabricates a 0.0 column — so shipping the template would put
# plausible zeros on three families of device.

# The devproc contract is fixed by op_annot.tcl: <inst> <model> <path> <prefix>.
# ⚠ NO `string tolower` here (op_annot::devpath lowercases every exit, and a
# devproc that lowercased its own answer would be a second copy of that
# decision) and NO `getprop instance … spiceprefix` (measured EMPTY when the
# token lives in the symbol template=; the prefix arrives as an argument, from
# `xschem translate`).
proc sky130_op_devpath {instname model path spiceprefix} {
  set m msky130_fd_pr__$model
  if {[regexp {g5v0d16} $model]} {
    set m xsky130_fd_pr__$model.msky130_fd_pr__${model}_base
  } elseif {[regexp {20v0_(iso|nvt)} $model]} {
    set m msky130_fd_pr__${model}_base
  } elseif {[regexp {20v0} $model]} {
    set m m1
  }
  return "@m.$path$spiceprefix$instname.$m"
}

# ⚠ GUARDED, NOT MERELY APPENDED. Measured: a raise inside a PDK procs file
# prints `Tcl_AppInit() error: can not execute <rc>` and ABANDONS the rest of
# cadence_style_rc — the SKY130 menu, user_startup_commands, the library-manager
# autostart — while still exiting 0. Issue 0424 (an installed tree can ship
# xschem.tcl sourcing an uninstalled op_annot.tcl) makes `invalid command name`
# a live possibility here. What is NOT caught is `register`'s own malformed-dict
# raise: that is an rc typo and must stay loud (op_annot.tcl's error discipline).
if {[info commands ::op_annot::register] ne {}} {
  # ⚠ BOTH nmos AND pmos. §4.2 registers only `nmos`; the prototypes branch on
  # `regexp {[pn]mos}` while op_annot's key is an exact array index, so a
  # verbatim copy would leave all 17 sky130 PMOS symbols unannotated in silence.
  # ⚠ `id` IS CARRIED although sky130_write_save_lines never saves it — every
  # shipped sky130 FET symbol displays `id=@spice_get_node i(…[id])`. Issue 0427.
  # ⚠ `match`: issue 0425 — `type=nmos` is shared with gf180, IHP and
  # xschem_library/devices/nmos.sym.
  # ⚠ pinexpr uses the SHIPPED spelling (nfet_01v8.sym:65-66), not §4.2's
  # `{@#1 - @#2}` shorthand, which has no evaluator anywhere in the tree.
  # Pin order measured from the B records: D=0 G=1 S=2 B=3.
  # ⚠ derived rows are SELF-CONTAINED — `ft` inlines its own capacitance sum
  # rather than referencing a derived label, so S5 needs no evaluation order.
  #
  # ==========================================================================
  # ⚠ cgso AND cgdo ARE DELIBERATELY ABSENT — ISSUE 0429, RULING D8 (status E)
  # ==========================================================================
  # The prototype `sky130_write_save_lines` saves them and this descriptor used
  # to inherit them. RE-MEASURED on BOTH ngspice binaries installed here, one
  # parameter per throwaway deck, real sky130 tt models, under the
  # `.control … write … .endc` idiom every shipped PDK bench uses:
  #
  #   /usr/bin/ngspice (42)        gm cgg cgs cgd -> raw written, 0 warnings
  #                                cgso cgdo      -> exit 0, ONE `checkvalid`
  #                                                  line, and NO RAW FILE AT ALL
  #   /usr/local/bin/ngspice (46+) cgso cgdo      -> raw written, real values
  #                                                  (2.463135e-16 each)
  #
  # So on 42 a single unknown model parameter suppresses the WHOLE raw while the
  # exit status stays 0 — silent, total waveform loss. S3 ships the first
  # PDK-neutral `Create device OP .save file` menu item, i.e. the first time this
  # descriptor is handed to every PDK's users as a generated deck, and a feature
  # that destroys the data it exists to display is not shippable. The two rows
  # go, and `ft` becomes gm/(2*pi*cgg).
  #
  # RECOVERY for a 46+ user who wants them back is one `op_annot::register`
  # round-trip in their own rc (I5) — no rebuild, no restart:
  #     set d [op_annot::descriptor nmos]
  #     dict set d params [concat [dict get $d params] {{cgso cgso 1} {cgdo cgdo 1}}]
  #     op_annot::register nmos $d
  #
  # REJECTED (a): keep them — correct on 46+, catastrophic on 42, and the
  # generated deck cannot know which ngspice will run it.
  # REJECTED (b): issue 0429's OWN fix sketch, relabelling to `cgs`/`cgd`.
  # Refuted by arithmetic: cgs measures NEGATIVE (-5.52e-16) and cgd is three
  # orders down (6.04e-19), so ft's denominator would go from
  # cgg+cgdo+cgso = 1.254e-15 to cgg+cgd+cgs = 2.097e-16 — a silently ~6x wrong
  # fT on every sky130 FET on EVERY ngspice, i.e. exactly I3's
  # plausible-wrong-number arriving from a "fix".
  # REJECTED (c): a per-parameter descriptor guard plus a simulator-version
  # probe — new descriptor grammar, policy back inside the emitter, and the
  # probe cannot know which ngspice will run the generated deck. Filed forward.
  foreach _sky130_op_type {nmos pmos} {
    op_annot::register $_sky130_op_type {
      devproc sky130_op_devpath
      match   {*sky130_fd_pr/*}
      params  {{id id 0} {gm gm 1} {gds gds 1} {vth vth 2} {vdsat vdsat 2}
               {cgg cgg 1}}
      derived {{ft    {$gm/(2*3.141592654*$cgg)}}
               {gm/id {$gm/$id}}}
      pinexpr {{vgs {expr(@#1:spice_get_voltage - @#2:spice_get_voltage)}}
               {vds {expr(@#0:spice_get_voltage - @#2:spice_get_voltage)}}}
    }
  }
  unset _sky130_op_type
} else {
  puts stderr {sky130_procs.tcl: op_annot::register not available, OP annotation descriptors not registered}
}

