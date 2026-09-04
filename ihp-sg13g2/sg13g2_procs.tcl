# IHP SG13G2 helper procs — DRC checks, FET/BIP operating-point save + annotate,
# and the IHP menu.
#
# Ported from the IHP-Open-PDK files `libs.tech/xschem/xschem-drc` and
# `libs.tech/xschem/xschem-menu` (SYSTEM, read-only) so this workarea is
# self-contained. Requires $::MODELS_NGSPICE, set by cadence_style_rc.
#
# Three deliberate differences from the PDK originals:
#
#  1. Every proc is prefixed `sg13g2_`. The PDK defines bare `fet_drc`,
#     `save_params`, `display_fet_params`, ... straight into the global
#     interpreter; in a workarea where sky130A and gf180mcuD procs may also be
#     loaded those names would collide. The migrated symbols call the prefixed
#     names — build_ihp_sg13g2.sh rewrites the call sites to match, so the two
#     halves must be renamed together.
#
#  2. place_symbol arguments use the OA lib/cell form (`devices/code_shown`, not
#     `devices/code_shown.sym`). The workarea runs registry-only
#     (library_registry_defs_only 1), where a trailing .sym does not resolve.
#
#  3. The models symbol emits ABSOLUTE `.lib` paths via $::MODELS_NGSPICE. The
#     PDK version emits bare names (`.lib cornerMOSlv.lib mos_tt`) and leans on
#     ngspice's cwd search, which only works when the sim is launched from the
#     models directory. See doc/claude/specs/ihp_sg13g2_workarea.md.
#
# The Xyce menu entry of the PDK original is omitted: this workarea vendors the
# ngspice models only, and sg13g2_tests_xyce is not migrated.

############################################################ DRC checks ######
# IHP SG13G2 mosfet dimension checks
proc sg13g2_fet_drc {instance symbol model w l ng } {
  set res {}
  # strip off the "u" suffix
  regsub {u$} $w {} w
  regsub {u$} $l {} l
  if { [string is double $w] && [string is double $l] && [string is integer $ng]} {

  # calculate finger width
    set w [expr { double($w) / double($ng)}]

    switch -regexp $model {
      {sg13_lv_nmos$} {
        if { $w < 0.13 } {
          append res "${instance} ($model): finger width is too small, w/ng = $w, min. w/ng > 0.13u" \n
        }
        if { $w > 10.0 } {
          append res "${instance} ($model): finger width is too big, w/ng = $w, max. w/ng < 10.0u" \n
        }
        if { $l < 0.13 } {
          append res "${instance} ($model): length is too small, l = $l, min l > 0.13u" \n
        }
        if { $l > 10.0 } {
          append res "${instance} ($model): length is too big, l = $l, max l < 10.0u" \n
        }
      }
      {sg13_lv_pmos$} {
        if { $w < 0.13 } {
          append res "${instance} ($model): finger width is too small, w/ng = $w, min. w/ng > 0.13u" \n
        }
        if { $w > 10.0 } {
          append res "${instance} ($model): finger width is too big, w/ng = $w, max. w/ng < 10.0u" \n
        }
        if { $l < 0.13 } {
          append res "${instance} ($model): length is too small, l = $l, min. l > 0.13u" \n
        }
        if { $l > 10.0 } {
          append res "${instance} ($model): length is too big, l = $l, max l < 10.0u" \n
        }
      }
      {sg13_hv_nmos$} {
        if { $w < 0.3 } {
          append res "${instance} ($model): finger width is too small, w/ng = $w, min w/ng > 0.3u" \n
        }
        if { $w > 10.0 } {
          append res "${instance} ($model): finger width is too big, w/ng = $w, max. w/ng < 10.0u" \n
        }
        if { $l < 0.45 } {
         append res "${instance} ($model): length is too small, l = $l, min. l > 0.45u" \n
        }
        if { $l > 10.0 } {
          append res "${instance} ($model): length is too big, l = $l, max l < 10.0u" \n
        }
      }
      {sg13_hv_pmos$} {
        if { $w < 0.3 } {
          append res "${instance} ($model): finger width is too small, w/ng = $w, min. w/ng > 0.3u" \n
        }
        if { $w > 10.0 } {
          append res "${instance} ($model): finger width is too big, w/ng = $w, max. w/ng < 10.0u" \n
        }
        if { $l < 0.4 } {
          append res "${instance} ($model): length is too small, l = $l, min. l > 0.4u" \n
        }
        if { $l > 10.0 } {
          append res "${instance} ($model): length is too big, l = $l, max l < 10.0u" \n
        }
      }
    } ;# switch
  }
  return $res
}

# IHP SG13G2 resistor dimension checks
proc sg13g2_res_drc {instance symbol model w l } {
  set res {}
  regsub {u$} $w {} w
  regsub {u$} $l {} l
  if { [string is double $w] && [string is double $l] } {

    switch -regexp $model {
      {rsil$|rppd$} {
        if { $w < 0.5e-6 } {
          append res "${instance} ($model): resistor width is too small, w = $w, min. w > 0.5u" \n
        }

        if { $l < 0.5e-6 } {
          append res "${instance} ($model): resistor length is too small, l = $l, min. l > 0.5u" \n
        }
      }
      {rhigh$} {
        if { $w < 0.5e-6 } {
          append res "${instance} ($model): resistor width is too small, w = $w, min. w > 0.5u" \n
        }

        if { $l < 0.96e-6 } {
          append res "${instance} ($model): resistor length is too small, l = $l, min. l > 0.96u" \n
        }
      }
    } ;# switch
  }
  return $res
}

# IHP SG13G2 MiM capacitor dimension checks
proc sg13g2_mim_drc {instance symbol model w l } {
  set res {}

  if { [string is double $w] && [string is double $l] } {
    set area [expr { double($w) * double($l) * 1.0e+12}]

    if { $w < 1.14e-6 } {
      append res "${instance} ($model): MiM capacitor width is too small, w = $w, min. w > 1.14 um" \n
    }

    if { $area < 1.3 } {
       append res "${instance} ($model): MiM capacitor area is too small, area = $area, min. area > 1.3 um2" \n
    }

    if { $area > 5625.0 } {
       append res "${instance} ($model): MiM capacitor area is too big, area = $area, max. area < 5625.0 um2" \n
    }
  }
  return $res
}

# IHP SG13G2 HBT dimension checks
proc sg13g2_hbt_drc {instance symbol model Nx El } {
  set res {}
  if { [string is integer $Nx] || [string is double $El]} {

    switch -regexp $model {
      {npn13G2$} {
        if { $Nx < 1 } {
          append res "${instance} ($model):  Number of emmiters Nx = $Nx must be in range 1-10" \n
        }
        if { $Nx > 10 } {
          append res "${instance} ($model): Number of emitters Nx = $Nx must be in range 1-10" \n
        }
      }
      {npn13G2l$} {
        if { $Nx < 1 } {
          append res "${instance} ($model):  Number of emmiters Nx = $Nx must be in range 1-4" \n
        }
        if { $Nx > 4 } {
          append res "${instance} ($model): Number of emitters Nx = $Nx must be in range 1-4" \n
        }
        if { $El < 1.0 } {
          append res "${instance} ($model): Emitter length El = $El too small, min. El > 1.0 " \n
        }
        if { $El > 2.5 } {
          append res "${instance} ($model): Emitter length El = $El too big, max. El < 2.5 " \n
        }
      }
      {npn13G2v$} {
        if { $Nx < 1 } {
          append res "${instance} ($model):  Number of emmiters Nx = $Nx must be in range 1-4" \n
        }
        if { $Nx > 4 } {
          append res "${instance} ($model): Number of emitters Nx = $Nx must be in range 1-4" \n
        }
        if { $El < 1.0 } {
          append res "${instance} ($model): Emitter length El = $El too small, min. El > 1.0 " \n
        }
        if { $El > 5 } {
          append res "${instance} ($model): Emitter length El = $El too big, max. El <= 5 " \n
        }
      }

      {npn13G2_5t$} {
        if { $Nx < 1 } {
          append res "${instance} ($model):  Number of emmiters Nx = $Nx must be in range 1-10" \n
        }
        if { $Nx > 10 } {
          append res "${instance} ($model): Number of emitters Nx = $Nx must be in range 1-10" \n
        }
      }
      {npn13G2l_5t$} {
        if { $Nx < 1 } {
          append res "${instance} ($model):  Number of emmiters Nx = $Nx must be in range 1-4" \n
        }
        if { $Nx > 4 } {
          append res "${instance} ($model): Number of emitters Nx = $Nx must be in range 1-4" \n
        }
        if { $El < 1.0 } {
          append res "${instance} ($model): Emitter length El = $El too small, min. El > 1.0 " \n
        }
        if { $El > 2.5 } {
          append res "${instance} ($model): Emitter length El = $El too big, max. El < 2.5 " \n
        }
      }
      {npn13G2v_5t$} {
        if { $Nx < 1 } {
          append res "${instance} ($model):  Number of emmiters Nx = $Nx must be in range 1-4" \n
        }
        if { $Nx > 4 } {
          append res "${instance} ($model): Number of emitters Nx = $Nx must be in range 1-4" \n
        }
        if { $El < 1.0 } {
          append res "${instance} ($model): Emitter length El = $El too small, min. El > 1.0 " \n
        }
        if { $El > 5 } {
          append res "${instance} ($model): Emitter length El = $El too big, max. El <= 5 " \n
        }
      }
    } ;# switch
  }
  return $res
}

# IHP SG13G2 antenna diode checks
proc sg13g2_diode_drc {instance symbol model w l } {
  set res {}
  regsub {u$} $w {} w
  regsub {u$} $l {} l
  if { [string is double $w] && [string is double $l]} {

    switch -regexp $model {
      {dantenna} {
        if { $w < 0.78 } {
          append res "${instance} ($model): Diode width w = $w too small, min w > 0.78 um" \n
        }
        if { $l < 0.78 } {
          append res "${instance} ($model): Diode length l = $l too small, min l > 0.78 um" \n
        }
      }
      {dpantenna} {
        if { $w < 0.78 } {
          append res "${instance} ($model): Diode width w = $w too small, min w > 0.78 um" \n
        }
        if { $l < 0.78 } {
          append res "${instance} ($model): Diode length l = $l too small, min l > 0.78 um" \n
        }
      }
    } ;# switch
  }
  return $res
}

# IHP SG13G2 S-Varicap checks
proc sg13g2_svaricap_drc {instance symbol model w l Nx} {
  set res {}

  # Validate Nx
  if {![string is integer -strict $Nx] || $Nx < 1 || $Nx > 10} {
    append res "${instance} ($model): Nx = $Nx is invalid, must be an integer between 1 and 10" \n
    return $res
  }

  # Remove 'u' suffix if present
  regsub {u$} $w {} w_clean
  regsub {u$} $l {} l_clean

  # Convert to double
  if {![string is double $w_clean] || ![string is double $l_clean]} {
    append res "${instance} ($model): Invalid width or length format" \n
    return $res
  }

  # Accept only the two valid (w, l) combinations
  set valid_comb1 [expr abs($w_clean - 3.74) < 1e-6 && abs($l_clean - 0.3) < 1e-6]
  set valid_comb2 [expr abs($w_clean - 9.74) < 1e-6 && abs($l_clean - 0.8) < 1e-6]

  if {!($valid_comb1 || $valid_comb2)} {
    append res "${instance} ($model): Invalid (w,l) combination. Allowed: (3.74u, 0.3u) or (9.74u, 0.8u)" \n
    return $res
  }

  return $res
}

############################# save and display MOSFET / HBT parameters #######

# writes the .save instructions for a given FET or BIP instance
proc sg13g2_write_save_lines {type model schpath spiceprefix instname} {
  global sg13g2_sch_expand
  if {[regexp {[pn]mos} $type]} {
    set m n$model
    set devpath [string tolower @n.$schpath$spiceprefix$instname.$m]

    append sg13g2_sch_expand(savelist) ".save $devpath\[ids\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[gm\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[gds\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[vth\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[vgs\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[vdss\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[vds\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[cgg\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[cgsol\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[cgdol\]\n"
  } elseif {[regexp {vertical_npn} $type]} {
    if {[regexp {_5t$} $model]} {
      set model [string range $model 0 end-3]
    }
    set m q$model
    set devpath [string tolower @q.$schpath$spiceprefix$instname.$m]

    append sg13g2_sch_expand(savelist) ".save $devpath\[gm\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[go\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[gmu\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[gpi\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[gx\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[vbe\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[vbc\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[ib\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[ic\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[cbe\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[cbc\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[cbep\]\n"
    append sg13g2_sch_expand(savelist) ".save $devpath\[cbcp\]\n"
  }
}

############ sg13g2_sch_expand
# This proc traverses the hierarchy and prints all instances in design.
proc sg13g2_sch_expand {{only_subckts 1} {all_hierarchy 1} {pattern {.*}}} {
  global sg13g2_sch_expand keep_symbols
  set sg13g2_sch_expand(savelist) {}
  set sg13g2_sch_expand(only_subckts) $only_subckts
  set sg13g2_sch_expand(all_hierarchy) $all_hierarchy
  set sg13g2_sch_expand(startpath) [string length [xschem get sch_path]]
  set save_keep $keep_symbols
  set keep_symbols 1
  xschem unselect_all
  xschem set no_draw 1 ;# disable screen update
  xschem set no_undo 1 ;# disable undo

  sg13g2_hier_sch_expand 0 $only_subckts $all_hierarchy $pattern

  xschem set no_draw 0
  xschem set no_undo 0
  set keep_symbols $save_keep
  return {}
}

# recursive procedure used by sg13g2_sch_expand
proc sg13g2_hier_sch_expand {{level 0} {only_subckts 0} {all_hierarchy 1} {pattern {.*}}} {
  global nolist_libs sg13g2_sch_expand

  set schpath [string range [xschem get sch_path] $sg13g2_sch_expand(startpath) end]
  set instances  [xschem get instances]
  for {set i 0} { $i < $instances} { incr i} {
    set instname [xschem getprop instance $i name]
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

    sg13g2_write_save_lines $type $model $schpath $spiceprefix $instname

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
        set dp [sg13g2_hier_sch_expand $level $only_subckts 1 $pattern]
        if {$n == $ninst} {
          xschem go_back 2
          incr level -1
        }
      }
    }
  }
  return 1
}
############ /sg13g2_sch_expand

# generate the .save lines for all FET and HBT parameters
proc sg13g2_save_params {} {
  global sg13g2_sch_expand
  set fet_bip_list {}
  sg13g2_sch_expand 0 1 {npn}
  append fet_bip_list $sg13g2_sch_expand(savelist)
  sg13g2_sch_expand 0 1 {[pn]mos}
  append fet_bip_list $sg13g2_sch_expand(savelist)
  return "* Place this .save file with a .include line in your testbench\n\n$fet_bip_list"
}

# return numeric value or "" if missing
proc sg13g2_raw_or_double {path} {
  if {[catch {xschem raw value $path -1} v]} { return "" }
  if {[string is double -strict $v]} { return $v }
  return ""
}

# wrap to_eng; yield "NaN" for non-numeric
proc sg13g2_to_eng_safe {v} {
  if {[string is double -strict $v]} { return [to_eng $v] }
  return "NaN"
}

# displays mos parameter simulation data; used by symbol sg13g2_pr/annotate_fet_params
proc sg13g2_display_fet_params {instname} {
  set txt {}
  set schpath     [xschem get sim_sch_path]
  set symbol      [xschem getprop instance $instname cell::name]
  set spiceprefix [xschem getprop instance $instname spiceprefix]
  set model       [xschem translate $instname @model]
  set type        [xschem getprop symbol $symbol type]

  if {[regexp {[pn]mos} $type]} {
    set m n$model
    set devpath [string tolower @n.$schpath$spiceprefix$instname.$m]

    set ids   [sg13g2_raw_or_double "i($devpath\[ids\])"]
    set gm    [sg13g2_raw_or_double "$devpath\[gm\]"]
    set gds   [sg13g2_raw_or_double "$devpath\[gds\]"]
    set vth   [sg13g2_raw_or_double "v($devpath\[vth\])"]
    set vgs   [sg13g2_raw_or_double "v($devpath\[vgs\])"]
    set vdss  [sg13g2_raw_or_double "v($devpath\[vdss\])"]
    set vds   [sg13g2_raw_or_double "v($devpath\[vds\])"]
    set cgg0  [sg13g2_raw_or_double "$devpath\[cgg\]"]
    set cgdol [sg13g2_raw_or_double "$devpath\[cgdol\]"]
    set cgsol [sg13g2_raw_or_double "$devpath\[cgsol\]"]

    # summed Cgg = cgg + cgdol + cgsol, or NaN if any missing
    if {[string is double -strict $cgg0] && [string is double -strict $cgdol] && [string is double -strict $cgsol]} {
      set cgg_sum [expr {$cgg0 + $cgdol + $cgsol}]
    } else {
      set cgg_sum ""
    }

    append txt "ids   = [sg13g2_to_eng_safe $ids]\n"
    append txt "gm    = [sg13g2_to_eng_safe $gm]\n"
    append txt "gds   = [sg13g2_to_eng_safe $gds]\n"
    append txt "vth   = [sg13g2_to_eng_safe $vth]\n"
    append txt "vgs   = [sg13g2_to_eng_safe $vgs]\n"
    append txt "vdss  = [sg13g2_to_eng_safe $vdss]\n"
    append txt "vds   = [sg13g2_to_eng_safe $vds]\n"
    append txt "cgg   = [sg13g2_to_eng_safe $cgg_sum]\n"

    # ft and gm/id only if inputs numeric
    set pi 3.141592654
    if {[string is double -strict $gm] && [string is double -strict $cgg_sum] && $cgg_sum != 0} {
      set ft [expr {$gm / (2.0 * $pi * $cgg_sum)}]
    } else {
      set ft ""
    }
    append txt "ft    = [sg13g2_to_eng_safe $ft]\n"

    if {[string is double -strict $gm] && [string is double -strict $ids] && $ids != 0} {
      set gmid [expr {$gm / $ids}]
    } else {
      set gmid ""
    }
    append txt "gm/id = [sg13g2_to_eng_safe $gmid]\n"
  }
  return $txt
}

# displays bipolar parameter simulation data; used by symbol sg13g2_pr/annotate_bip_params
proc sg13g2_display_bip_params {instname} {
  set txt {}
  set schpath     [xschem get sim_sch_path]
  set symbol      [xschem getprop instance $instname cell::name]
  set spiceprefix [xschem getprop instance $instname spiceprefix]
  set model       [xschem translate $instname @model]
  set type        [xschem getprop symbol $symbol type]

  if {[regexp {vertical_npn} $type]} {
    if {[regexp {_5t$} $model]} {
      set model [string range $model 0 end-3]
    }
    set m q$model
    set devpath [string tolower @q.$schpath$spiceprefix$instname.$m]

    # raw reads with guards
    set gm   [sg13g2_raw_or_double "$devpath\[gm\]"]
    set go   [sg13g2_raw_or_double "$devpath\[go\]"]
    set gx   [sg13g2_raw_or_double "$devpath\[gx\]"]
    set gmu  [sg13g2_raw_or_double "$devpath\[gmu\]"]
    set gpi  [sg13g2_raw_or_double "$devpath\[gpi\]"]
    set vbe  [sg13g2_raw_or_double "v($devpath\[vbe\])"]
    set vbc  [sg13g2_raw_or_double "v($devpath\[vbc\])"]
    set ib   [sg13g2_raw_or_double "i($devpath\[ib\])"]
    set ic   [sg13g2_raw_or_double "i($devpath\[ic\])"]
    set cbe  [sg13g2_raw_or_double "$devpath\[cbe\]"]
    set cbc  [sg13g2_raw_or_double "$devpath\[cbc\]"]
    set cbep [sg13g2_raw_or_double "$devpath\[cbep\]"]
    set cbcp [sg13g2_raw_or_double "$devpath\[cbcp\]"]

    # prints
    append txt "gm   = [sg13g2_to_eng_safe $gm]\n"
    append txt "go   = [sg13g2_to_eng_safe $go]\n"

    # rin = 1/gx + 1/(gmu + gpi)
    if {[string is double -strict $gx] && $gx != 0 && \
        [string is double -strict $gmu] && [string is double -strict $gpi] && ($gmu + $gpi) != 0} {
      set rin [expr {1.0/$gx + 1.0/($gmu + $gpi)}]
    } else {
      set rin ""
    }
    append txt "rin  = [sg13g2_to_eng_safe $rin]\n"

    append txt "vbe  = [sg13g2_to_eng_safe $vbe]\n"

    # vce = vbe - vbc
    if {[string is double -strict $vbe] && [string is double -strict $vbc]} {
      set vce [expr {$vbe - $vbc}]
    } else {
      set vce ""
    }
    append txt "vce  = [sg13g2_to_eng_safe $vce]\n"

    append txt "ib   = [sg13g2_to_eng_safe $ib]\n"
    append txt "ic   = [sg13g2_to_eng_safe $ic]\n"
    append txt "cbe  = [sg13g2_to_eng_safe $cbe]\n"
    append txt "cbc  = [sg13g2_to_eng_safe $cbc]\n"

    # ft = gm / (2*pi*(cbe + cbc + cbep + cbcp))
    set pi 3.141592654
    if {[string is double -strict $gm] && \
        [string is double -strict $cbe] && [string is double -strict $cbc] && \
        [string is double -strict $cbep] && [string is double -strict $cbcp]} {
      set csum [expr {$cbe + $cbc + $cbep + $cbcp}]
      if {$csum != 0} {
        set ft [expr {$gm / (2.0 * $pi * $csum)}]
      } else {
        set ft ""
      }
    } else {
      set ft ""
    }
    append txt "ft   = [sg13g2_to_eng_safe $ft]\n"
  }
  return $txt
}

# Run after each window is created (the rc appends this to user_startup_commands):
# add an IHP menu.
proc sg13g2_menupdk {} {
  global has_x netlist_dir
  if { [info exists has_x] } {
    set topwin [xschem get top_path]

    # Idempotent: the rc calls this directly for the window that already exists
    # AND leaves it in user_startup_commands for windows created later, so for
    # any given window it can be reached twice. A second `menu` command on the
    # same path would error out.
    if {[winfo exists $topwin.menubar.ihp]} { return }

    # insert before the 'Netlist' menu
    $topwin.menubar insert Netlist cascade -label IHP -menu $topwin.menubar.ihp
    menu $topwin.menubar.ihp -tearoff 0

    $topwin.menubar.ihp add command -label {Create FET and BIP .save file} -command {
      file mkdir $netlist_dir
      write_data [sg13g2_save_params] $netlist_dir/[file rootname [file tail [xschem get current_name]]].save
      textwindow $netlist_dir/[file rootname [file tail [xschem get current_name]]].save
    }

    # Absolute model paths through $::MODELS_NGSPICE — see header note 3.
    #
    # The `.control pre_osdi ... .endc` preamble registers the Verilog-A modules
    # (psp103 for the MOS devices, r3_cmc for the resistors, mosvar for the
    # varicaps) BEFORE the deck is parsed. Without it every MOS / resistor /
    # varicap instance dies at "Unable to find definition of model". `pre_osdi`
    # rather than `osdi` because a plain `osdi` inside .control runs after
    # parsing, and ngspice has no `.osdi` dot-card.
    $topwin.menubar.ihp add command -label {Add Ngspice models symbol} -command {
      xschem place_symbol devices/code_shown {
name=Libs_Ngspice
only_toplevel=false
format="tcleval( @value )"
value="
.control
pre_osdi $::SG13G2_OSDI/psp103.osdi
pre_osdi $::SG13G2_OSDI/psp103_nqs.osdi
pre_osdi $::SG13G2_OSDI/r3_cmc.osdi
pre_osdi $::SG13G2_OSDI/mosvar.osdi
.endc
.lib $::MODELS_NGSPICE/cornerMOSlv.lib mos_tt
.lib $::MODELS_NGSPICE/cornerMOShv.lib mos_tt
.lib $::MODELS_NGSPICE/cornerHBT.lib hbt_typ
.lib $::MODELS_NGSPICE/cornerRES.lib res_typ
.lib $::MODELS_NGSPICE/cornerCAP.lib cap_typ
"
      }
    }

    $topwin.menubar.ihp add command -label {Add FET param annotator} -command {
      set selset [lindex [xschem selected_set] 0]
      if {$selset ne {}} {
        xschem place_symbol sg13g2_pr/annotate_fet_params "name=annot1 ref=[xschem getprop instance $selset name]"
      } else {
        xschem place_symbol sg13g2_pr/annotate_fet_params
      }
    }

    $topwin.menubar.ihp add command -label {Add BIP param annotator} -command {
      set selset [lindex [xschem selected_set] 0]
      if {$selset ne {}} {
        xschem place_symbol sg13g2_pr/annotate_bip_params "name=annot1 ref=[xschem getprop instance $selset name]"
      } else {
        xschem place_symbol sg13g2_pr/annotate_bip_params
      }
    }
  }
}

########################## op_annot descriptors (S2) #########################
# doc/claude/specs/op_annotation.md §4.2. This is a DATA lift of
# sg13g2_write_save_lines (:304-341): its two `if/elseif` arms become two
# registrations, its ten FET `.save` lines and thirteen HBT ones become the
# `params` lists IN THAT ORDER, and its device-path concatenation becomes the
# template / devproc below. Nothing of its control flow survives — S3's generic
# hierarchy walk plus these descriptors replace it.
#
# ⚠ THE PROTOTYPE PROCS ABOVE ARE LEFT EXACTLY AS THEY WERE, ON PURPOSE. They
# are the acceptance ORACLE: tests/headless/test_op_annot.tcl rows P19/P20/P21
# diff `.save [op_annot::devpath $i][param]` against live `sg13g2_save_params`
# output on dc_lv_nmos / dc_lv_pmos / dc_hbt_13g2_5t and require it byte for
# byte (10, 10 and 26 cards). Editing them in the same step would destroy the
# only evidence the generalization lost nothing.
#
# ⚠ THE CARDS ARE BARE. The diff goes through `devpath`, never `vector`:
# measured on ngspice-42, `.save i(@n.…[ids])` puts NOTHING in the raw while
# `.save @n.…[ids]` yields `i(@n.…[ids])` — ngspice applies the i()/v() wrapper
# itself from the parameter's own type (spec §3 R4).
#
# ⚠ kinds are NOT invented here: they are sg13g2_display_fet_params:461-470 and
# sg13g2_display_bip_params:524-536 read off verbatim (`i($devpath[ids])` -> 0,
# bare `$devpath[gm]` -> 1, `v($devpath[vth])` -> 2). Those lines are the only
# authority for kind in the tree, and a wrong kind makes the save card succeed
# while the read silently misses.

# The ONE part of the prototype that cannot be a template: `xschem translate`
# has no regsub, so the `_5t` model-suffix strip (:321-324) needs a devproc.
# ⚠ NO `string tolower` (op_annot::devpath lowercases every exit) and NO
# `getprop instance … spiceprefix` (the prototype's :374/:453/:512 read it that
# way and work only because IHP's own test schematics spell `spiceprefix=` on
# the instance line; the prefix arrives here as an argument, from `translate`).
proc sg13g2_op_npn_devpath {instname model path spiceprefix} {
  if {[regexp {_5t$} $model]} {
    set model [string range $model 0 end-3]
  }
  return "@q.$path$spiceprefix$instname.q$model"
}

# ⚠ GUARDED, NOT MERELY APPENDED — see ../sky130A/sky130_procs.tcl for the
# measurement. `register`'s own malformed-dict raise is deliberately NOT caught.
if {[info commands ::op_annot::register] ne {}} {
  # ⚠ BOTH nmos AND pmos, sharing one dict: measured on dc_lv_pmos, IHP spells
  # the inner device `n<model>` for the PMOS too (`@n.xm1.nsg13_lv_pmos`).
  # ⚠ `match`: issue 0425 — `type=nmos` is shared with sky130, gf180 and
  # xschem_library/devices/nmos.sym.
  # ⚠ NO pinexpr: vgs and vds are saved DEVICE parameters on this PDK, so they
  # are already rows in `params` and need no pin-voltage expression. Since
  # ruling D9 that is true of sky130 and gf180 too — BSIM4 publishes vgs/vds as
  # instance parameters — so NO shipped descriptor carries a pinexpr any more.
  #
  # ⚠ THE DEFAULT SIX — RULING D9 (the user, 2026-08-22). Spec §4.2a.
  #     id  gm  gds  vgs  vth  vds        and nothing else, on every PDK.
  # "Too many parameters displayed is just clutter." GONE from this descriptor:
  # vdss, cgg, cgsol, cgdol, and the three derived rows cgg_tot, ft and gm/id.
  # No simulator computes ft or gm/id — they were Tcl arithmetic here and, with
  # a DIFFERENT formula, in sky130's procs file.
  #
  # ⚠ THE LABEL IS `id`, THE PARAMETER IS STILL `ids`. IHP spells the current
  # `ids` where BSIM4 spells it `id`; the descriptor's {label param kind} triple
  # exists for exactly this, and one display vocabulary across all three PDKs is
  # worth more than matching the raw's spelling on screen.
  #
  # ✅ MEASURED ON A REAL RAW, 2026-08-22 — and the claim this comment used to
  # make ("no IHP parameter name can be checked against a real raw here") was
  # WRONG, not merely cautious. It was measured against /usr/bin/ngspice (42),
  # which supports OSDI v0.3 while the vendored psp103.osdi targets v0.4, and
  # then generalised to "this box". THE BOX HAS TWO ngspice BINARIES:
  #
  #     /usr/bin/ngspice       (42)    pre_osdi psp103.osdi -> "couldn't be
  #                                    loaded ... only supports OSDI v0.3"
  #     /usr/local/bin/ngspice (46+)   pre_osdi psp103.osdi -> loads, and the
  #                                    bench runs
  #
  # On 46+, sg13g2_tests/dc_lv_nmos with these six as its `.save` file: rc=0,
  # ZERO checkvalid warnings, and every vector present in the shapes the `kind`
  # convention predicts --
  #     i(@n.xm1.nsg13_lv_nmos[ids])   @n.xm1.nsg13_lv_nmos[gm] / [gds]
  #     v(@n.xm1.nsg13_lv_nmos[vgs]) / [vth] / [vds]
  # then annotated live: ids 259.1u, gm 464u, gds 17.78u, vgs 1.2, vth 0.2966,
  # vds 1.5. So this PDK's six are MEASURED, exactly like sky130's and gf180's,
  # not inferred from being a subset of the prototype's list.
  #
  # ⚠ WHAT IS STILL TRUE: an IHP bench needs ngspice-46+. On 42 it does not fail
  # in the annotation path, it fails to simulate at all.
  #
  # RECOVERY for the old rows is one round-trip in a --script rc (invariant I5):
  #     set d [op_annot::descriptor nmos]
  #     dict set d params [concat [dict get $d params] \
  #        {{vdss vdss 2} {cgg cgg 1} {cgsol cgsol 1} {cgdol cgdol 1}}]
  #     dict set d derived {{cgg_tot {$cgg + $cgsol + $cgdol}} \
  #        {ft {$gm/(2*3.141592654*($cgg + $cgsol + $cgdol))}} {gm/id {$gm/$id}}}
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
  #
  # ⚠ vertical_npn BELOW IS UNTOUCHED BY D9 — the six are MOS quantities and an
  # HBT has no vgs. Whether a bipolar default wants the same trim is OPEN.
  foreach _sg13g2_op_type {nmos pmos} {
    op_annot::register $_sg13g2_op_type {
      devpath {\@n.@path@spiceprefix@name\.n@model}
      match   {*sg13g2_pr/*}
      params  {{id ids 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}}
    }
  }
  unset _sg13g2_op_type

  # ⚠ THIRTEEN params, in sg13g2_write_save_lines:327-339's order. Spec §4.2
  # shows six ({ic ib gm go vbe vbc}); that list silently drops gmu gpi gx cbe
  # cbc cbep cbcp, and with them the prototype's `rin` and `ft`.
  # ⚠ RULING D9b (the user, 2026-08-22): "For ANY PDK, ANY device, only display
  # max of six parameters UNLESS there is a setting to do otherwise. We can't
  # have BJT (NPN,PNP) causing clutter." This descriptor shipped SIXTEEN rows —
  # thirteen params and three derived — and is the case that prompted the rule.
  #
  # The cap itself is enforced in op_annot::text (spec §4.2b), so an untrimmed
  # descriptor would not actually paint sixteen rows. It would paint the first
  # six IN DECLARED ORDER, which here was `gm go gmu gpi gx vbe` — the internal
  # small-signal conductances and no current at all. A cap chooses how MANY; a
  # descriptor still has to choose WHICH, so this list is reordered and trimmed
  # rather than left to be truncated.
  #
  # The six mirror the MOS six as closely as a bipolar allows: output current,
  # input current, transconductance, output conductance, and the two junction
  # voltages.
  #     MOS   id   —    gm  gds  vgs  vds
  #     BJT   ic   ib   gm  go   vbe  vbc
  #
  # ⚠ `vce` IS NOT HERE, AND THAT IS A CONSEQUENCE OF THE CAP, NOT AN OVERSIGHT.
  # psp103 publishes vbe and vbc, not vce; the prototype showed vce as a DERIVED
  # row over both. A derived row can only reference labels that are THEMSELVES
  # displayed rows, so `vce` costs three rows (vbe, vbc, vce) to show one number
  # — seven in total, one over the cap, and the cap would then drop `vce` itself
  # as the last row. Showing vbe and vbc directly gives the reader the same
  # information (vce = vbe - vbc) inside the budget. To get the derived row back:
  #     set d [op_annot::descriptor vertical_npn]
  #     dict set d derived {{vce {$vbe - $vbc}}}
  #     set ::op_annot_max_rows 7
  #
  # GONE, and recoverable in one round-trip in a --script rc (invariant I5):
  # gmu gpi gx cbe cbc cbep cbcp, and the derived rin, vce and ft.
  #     set d [op_annot::descriptor vertical_npn]
  #     dict set d params [concat [dict get $d params] \
  #        {{gmu gmu 1} {gpi gpi 1} {gx gx 1} {cbe cbe 1} {cbc cbc 1}}]
  #     dict set d derived [concat [dict get $d derived] \
  #        {{rin {1.0/$gx + 1.0/($gmu + $gpi)}}}]
  #     set ::op_annot_max_rows 0
  # ⚠ NOTE THE LAST LINE. Adding rows is not enough — the cap must be lifted too,
  # or the extra rows are built and then dropped.
  op_annot::register vertical_npn {
    devproc sg13g2_op_npn_devpath
    match   {*sg13g2_pr/*}
    params  {{ic ic 0} {ib ib 0} {gm gm 1} {go go 1} {vbe vbe 2} {vbc vbc 2}}
  }
} else {
  puts stderr {sg13g2_procs.tcl: op_annot::register not available, OP annotation descriptors not registered}
}
