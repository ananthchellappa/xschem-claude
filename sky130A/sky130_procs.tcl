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

# ISSUE 0976: ASK WHAT MODEL THE DECK BUILT THIS DEVICE WITH, IN ONE PLACE.
#
# WHAT A READER WOULD OTHERWISE ASSUME: that `xschem translate <inst> @model` is
# the model, and that the two places below were just repeating themselves
# harmlessly. They were not. That verb answers from the LIVE DESIGN, which reads
# an instance property the netlister may never have written into the deck; the
# deck's answer comes from the symbol template unless the instance carries a
# `schematic=` attribute of its own. Measured on the shipped bandgap bench: for
# the two passgates whose schematic line overrides the p-channel model, the two
# answers differed, the name built from the live answer was in NO vector of the
# real results file, and the name built from the deck's answer was in it. The
# user saw a column of blanks in "Add FET param annotator" and a .save file full
# of devices ngspice would never report on, with nothing said.
#
# GUARD PDK-FALLBACK. src/op_annot.tcl is sourced unconditionally by
# src/xschem.tcl, so in the running program the shared resolver is always there.
# But this file can be sourced on its own by a script or a test, and a menu item
# that RAISES halfway through is worse than one that gives the old answer. So
# the old answer is the fallback, deliberately, and never the first choice.
proc sky130_model_netlist {instname} {
  if {[llength [info commands ::op_annot::model_netlist]]} {
    if {![catch {::op_annot::model_netlist $instname} m]} { return $m }
  }
  return [xschem translate $instname @model]
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
    set model [sky130_model_netlist $instname]
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
  set model [sky130_model_netlist $instname]
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
  #
  # ==========================================================================
  # ⚠ THE DEFAULT SIX — RULING D9 (the user, 2026-08-22). Spec §4.2a.
  # ==========================================================================
  #     id  gm  gds  vgs  vth  vds        and nothing else, on every PDK.
  # "Too many parameters displayed is just clutter." A block sits on top of the
  # schematic the designer is reading, so every row nobody looks at costs screen
  # and attention. GONE with this ruling: vdsat, cgg, cgso, cgdo, and the two
  # DERIVED rows ft and gm/id.
  #
  # ⚠ ft AND gm/id ARE NOT SIMULATOR DATA. Measured, `show <dev> : all` on
  # ngspice-46+ with real tt models: BSIM4 publishes gmbs gm gds vdsat vth id
  # ibd ibs gbd gbs isub igidl igisl igs igd igb igcs igcd vbs vgs vds cgg cgs
  # cgd c[bdsg][bdsg] capbd capbs qg qb qd qs qinv qdef gcrg gtau vgsteff vdseff
  # cgso cgdo cgbo weff leff — and NO ft, NO gm/id. Both were Tcl arithmetic in
  # this file (and, with a different formula, in IHP's). Dropping them removes a
  # computation, not a measurement.
  #
  # ⚠ THIS SUPERSEDES ISSUE 0429 RATHER THAN ANSWERING IT. cgso/cgdo are not in
  # the default set at all, so the "keep them or lose two rows" question is moot;
  # cgs/cgd are NOT substituted for anything (0429's own sketch, refuted by
  # arithmetic — cgs is NEGATIVE, and the swap made ft ~6x wrong).
  #
  # ⚠ ALL SIX ARE MEASURED SAVABLE ON BOTH ngspice GENERATIONS — the check 0429
  # said was owed, asserted against ngspice instead of against our own strings.
  # One card per parameter, real sky130 tt models, `.control … write … .endc`:
  #     /usr/bin/ngspice (42)     id gm gds vgs vth vds -> RAW, checkvalid=0
  #     /usr/local/bin (46+)      id gm gds vgs vth vds -> RAW, checkvalid=0
  # So no DEFAULT row can suppress a raw file on any supported ngspice.
  #
  # ⚠ AND vgs/vds ARE NOW params, NOT pinexpr. They are real BSIM4 instance
  # parameters (`vgs 0.896512`, `vds 1.79302` in the same show dump) and come
  # back as v(@m.…[vgs]) / v(@m.…[vds]) — kind 2, the existing convention. This
  # descriptor no longer carries a pinexpr at all, which takes issue 0446 (the
  # fabricated `vgs = 0` on a GND source) and issue 0444 (the load-bearing space
  # before `)`) OFF THE SHIPPED PATH. Neither C defect is fixed; both remain
  # reachable by a user who writes her own pinexpr, and their guardians live in
  # tests/headless/test_op_annot.tcl on test-local descriptors.
  #
  # RECOVERY for anyone who wants the old rows back is one round-trip in a
  # --script rc (invariant I5) — no rebuild, no restart, live on next redraw:
  #     set d [op_annot::descriptor nmos]
  #     dict set d params [concat [dict get $d params] {{vdsat vdsat 2} {cgg cgg 1}}]
  #     dict set d derived {{ft {$gm/(2*3.141592654*$cgg)}} {gm/id {$gm/$id}}}
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
  #
  # ⚠ TWO LISTS NOW, AND THEY ARE NOT THE SAME LIST (ruling DD-6, issue 1285).
  # A descriptor may carry `params` and, optionally, `shown`, and they have
  # different jobs: params is what the run computes — op_annot::_cards_for
  # builds the `.save` cards out of it, so a parameter must stay in that list
  # for its value to exist in the raw at all, even when nobody wants it drawn —
  # while shown is what the sheet draws, and op_annot::text is its only reader.
  # A descriptor that omits `shown`, which every register site in this tree
  # does, draws every `params` row exactly as it always has (invariant I7).
  # op_param_lists::apply writes both: the UNION of the annotation and summary
  # lists into `params`, and the annotation half of that union into `shown`.
  # ⚠ SINCE RULING DD-13 THAT UNION HAS A THIRD INPUT — this type's own
  # `declared` list, appended LAST (see the next paragraph) — so no edit to the
  # two lists above can ever remove a `.save` card the PDK asked for. DD-4
  # states the price out loud: a user who deletes a row to make the deck
  # smaller does not get a smaller deck.
  # Getting the two the wrong way round is how a wider `params` un-declutters
  # the schematic, and a `derived` row is why they must stay separate at all —
  # it reads the RUN, so it keeps its value when its operand is merely hidden
  # (ruling DD-9, issue 1289).
  #
  # ⚠ AND A THIRD LIST, WHICH YOU DO NOT WRITE BY HAND (ruling DD-13, issue
  # 1312): declared is what the PDK declared. op_annot::register alone writes it
  # -- it is stamped from this descriptor's own `params` the first time the
  # descriptor is registered, and PRESERVED verbatim ever after, so
  # op_param_lists::seed keeps answering the PDK's list no matter what the user
  # deletes from the two lists above. That preserve rule has one consequence
  # worth knowing: the RECOVERY round-trip above carries the key with it, so it
  # changes what the run computes and what the sheet draws but NOT what the
  # seed answers. To redeclare as well, add one line before re-registering --
  # dict unset d declared -- or register a fresh dict, which is what the
  # register call below already does.
  foreach _sky130_op_type {nmos pmos} {
    op_annot::register $_sky130_op_type {
      devproc sky130_op_devpath
      match   {*sky130_fd_pr/*}
      params  {{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}}
    }
  }
  unset _sky130_op_type
} else {
  puts stderr {sky130_procs.tcl: op_annot::register not available, OP annotation descriptors not registered}
}

