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
