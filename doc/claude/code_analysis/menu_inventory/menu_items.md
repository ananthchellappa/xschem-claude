# xschem menu inventory (draft action table)

Auto-extracted from `src/xschem.tcl` by `extract_menu.py`. 242 items across 22 menus.

Types: command=160, checkbutton=46, cascade=21, radiobutton=15

Items with an accelerator label: 127/242. Toggle items (check/radio, -variable bound): 61.

## `(top)`  (15 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| File | cascade |  |  | `` | 10185 |
| Edit | cascade |  |  | `` | 10187 |
| Options | cascade |  |  | `` | 10189 |
| View | cascade |  |  | `` | 10191 |
| Properties | cascade |  |  | `` | 10193 |
| Layers | cascade |  |  | `` | 10196 |
| Tools | cascade |  |  | `` | 10198 |
| Symbol | cascade |  |  | `` | 10200 |
| Highlight | cascade |  |  | `` | 10202 |
| Simulation | cascade |  |  | `` | 10204 |
| Help | cascade |  |  | `` | 10206 |
| - | command |  |  | `` | 10448 |
| Netlist | command |  |  | `xschem netlist -erc` | 10449 |
| Simulate | command |  |  | `simulate_from_button` | 10452 |
| Waves | cascade |  |  | `` | 10457 |

## `edit`  (23 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Undo | command | U |  | `xschem undo; xschem redraw` | 10413 |
| Redo | command | Shift+U |  | `xschem redo; xschem redraw` | 10414 |
| Copy | command | Ctrl+C |  | `xschem copy` | 10415 |
| Cut | command | Ctrl+X |  | `xschem cut` | 10416 |
| Paste | command | Ctrl+V |  | `xschem paste` | 10417 |
| Delete | command | Del |  | `xschem delete` | 10418 |
| Select all | command | Ctrl+A |  | `xschem select_all` | 10419 |
| Duplicate objects | command | C |  | `xschem copy_objects` | 10420 |
| Move objects | command | M |  | `xschem move_objects` | 10421 |
| Move objects stretching attached wires | command | Control+M |  | `xschem move_objects stretch` | 10422 |
| Move objects adding wires to connected pins | command | Shift+M |  | `xschem move_objects kissing` | 10424 |
| Horizontal Flip in place selected objects | command | Alt-F |  | `xschem flip_in_place` | 10426 |
| Vertical Flip in place selected objects | command | Alt-V |  | `xschem flipv_in_place` | 10428 |
| Rotate in place selected objects | command | Alt-R |  | `xschem rotate_in_place` | 10430 |
| Vertical Flip selected objects | command | Shift-V |  | `xschem flipv` | 10432 |
| Horizontal Flip selected objects | command | Shift-F |  | `xschem flip` | 10434 |
| Rotate selected objects | command | Shift-R |  | `xschem rotate` | 10436 |
| Unconstrained move | radiobutton |  | constr_mv | `xschem set constr_mv 0` | 10438 |
| Constrained Horizontal move | radiobutton | H | constr_mv | `xschem set constr_mv 1` | 10440 |
| Constrained Vertical move | radiobutton | V | constr_mv | `xschem set constr_mv 2` | 10442 |
| Push schematic | command | E |  | `xschem descend` | 10444 |
| Push symbol | command | I |  | `xschem descend_symbol` | 10445 |
| Pop | command | Ctrl+E |  | `xschem go_back` | 10446 |

## `file`  (21 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Clear Schematic | command | Ctrl+N |  | `xschem clear schematic` | 10225 |
| Clear Symbol | command | Ctrl+Shift+N |  | `xschem clear symbol` | 10229 |
| Component browser | command | Shift-Ins, Ctrl-I |  | `if {$new_file_browser} { file_chooser } else { load_file_dialog {In...` | 10233 |
| Open | command | Ctrl+O |  | `xschem load` | 10241 |
| Open in new window | command | Alt+O |  | `xschem load_new_window` | 10242 |
| Open last closed | command | Ctrl+Shift+T |  | `xschem load -gui -lastclosed` | 10244 |
| Open most recent | command | Ctrl+Shift+O |  | `xschem load -gui -lastopened` | 10246 |
| Open recent | cascade |  |  | `` | 10248 |
| Create new window/tab | command | Ctrl+T |  | `xschem new_schematic create` | 10251 |
| Open selected schematic in new window | command | Alt+E |  | `open_sub_schematic` | 10254 |
| Open selected symbol in new window | command | Alt+I |  | `xschem symbol_in_new_window` | 10257 |
| Delete files | command | Shift-D |  | `xschem delete_files` | 10260 |
| Save | command | Ctrl+S |  | `xschem save` | 10261 |
| Merge | command | B |  | `xschem merge` | 10262 |
| Reload | command | Alt+S |  | `if {[alert_ "Are you sure you want to reload?" {} 0 1] == 1} { xsch...` | 10263 |
| Save as | command | Ctrl+Shift+S |  | `xschem saveas` | 10269 |
| Save as symbol | command | Ctrl+Alt+S |  | `xschem saveas {} symbol` | 10270 |
| Image export | cascade |  |  | `` | 10273 |
| Start new Xschem process | command | X |  | `xschem new_process` | 10284 |
| Close schematic | command | Ctrl+W |  | `xschem exit` | 10287 |
| Quit Xschem | command | Ctrl+Q |  | `quit_xschem` | 10290 |

## `file.im_exp`  (6 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| EPS Selection Export | command |  |  | `xschem print eps` | 10275 |
| PDF/PS Export | command | * |  | `xschem print pdf` | 10276 |
| PDF/PS Export Full | command |  |  | `xschem print pdf_full` | 10277 |
| Hierarchical PDF/PS Export | command |  |  | `xschem hier_psprint` | 10278 |
| PNG Export | command | Ctrl+* |  | `xschem print png` | 10279 |
| SVG Export | command | Alt+* |  | `xschem print svg` | 10280 |

## `file.recent`  (1 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| [file | command |  |  | `xschem load -gui {$i}` | 1306 |

## `help`  (4 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Help | command | ? |  | `textwindow \"${XSCHEM_SHAREDIR}/xschem.help\" ro` | 10219 |
| Keys | command |  |  | `textwindow \"${XSCHEM_SHAREDIR}/keys.help\" ro` | 10221 |
| Show Keybindings | command |  |  | `show_bindkeys` | 10222 |
| About XSCHEM | command |  |  | `about` | 10223 |

## `hilight`  (18 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Set schematic to compare and compare with | command |  |  | `xschem compare_schematics; set compare_sch 1` | 10665 |
| Swap compare schematics | command |  |  | `swap_compare_schematics` | 10668 |
| Compare schematics | checkbutton |  | compare_sch | `xschem unselect_all xschem redraw` | 10671 |
| View only Probes | checkbutton | 5 | only_probes | `xschem only_probes` | 10677 |
| Highlight net-pin mismatches on sel. instances | command | Shift-X |  | `xschem net_pin_mismatch` | 10680 |
| Highlight duplicate instance names | command | # |  | `xschem check_unique_names 0` | 10684 |
| Rename duplicate instance names | command | Ctrl+# |  | `xschem check_unique_names 1` | 10686 |
| Select overlapped instances | command |  |  | `xschem warning_overlapped_symbols 1; xschem redraw` | 10688 |
| Propagate Highlight selected net/pins | command | Ctrl+Shift+K |  | `xschem hilight drill` | 10690 |
| Increment Hilight Color | checkbutton |  | incr_hilight | `` | 10692 |
| Highlight selected net/pins | command | K |  | `xschem hilight` | 10694 |
| Send selected net/pins to Viewer | command | Alt+G |  | `xschem send_to_viewer` | 10696 |
| Select hilight nets / pins | command | Alt+K |  | `xschem select_hilight_net` | 10698 |
| Un-highlight all net/pins | command | Shift+K |  | `xschem unhilight_all` | 10701 |
| Un-highlight selected net/pins | command | Ctrl+K |  | `xschem unhilight` | 10703 |
| Show labels on unconnected instance pins | command |  |  | `xschem show_unconnected_pins` | 10706 |
| Auto-highlight net/pins | checkbutton |  | auto_hilight | `` | 10708 |
| Enable highlight connected instances | checkbutton |  | en_hilight_conn_inst | `` | 10710 |

## `layers`  (1 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| $laylab | command |  |  | `xschem set rectcolor $j; reconfigure_layers_button $topwin` | 11033 |

## `option`  (22 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Color Postscript/SVG | checkbutton |  | color_ps | `if { $color_ps==1 } {xschem set color_ps 1} else { xschem set color...` | 10293 |
| Transparent SVG background | checkbutton |  | transparent_svg | `` | 10297 |
| Debug mode | checkbutton |  | menu_debug_var | `if { $menu_debug_var==1 } {xschem debug 1} else { xschem debug 0}` | 10299 |
| Undo buffer on Disk | checkbutton |  | undo_type | `switch_undo` | 10303 |
| Enable stretch | checkbutton | Y | enable_stretch | `` | 10306 |
| Enable infix-interface | checkbutton |  | infix_interface | `` | 10308 |
| Enable orthogonal wiring | checkbutton | Shift-L | orthogonal_wiring | `` | 10310 |
| Unsel. partial sel. wires after stretch move | checkbutton |  | unselect_partial_sel_wires | `` | 10312 |
| Auto Join/Trim Wires | checkbutton |  | autotrim_wires | `if {$autotrim_wires == 1} { xschem trim_wires xschem redraw }` | 10315 |
| Persistent wire/line place command | checkbutton |  | persistent_command | `` | 10322 |
| Intuitive Click & Drag interface | checkbutton |  | intuitive_interface | `xschem set intuitive_interface $intuitive_interface` | 10324 |
| Crosshair | cascade |  |  | `` | 10328 |
| Replace \[ and \] for buses in SPICE netlist | command |  |  | `input_line "Enter two characters to replace default bus \[\] delimi...` | 10341 |
| Group bus slices in Verilog instances | checkbutton |  | verilog_bitblast | `` | 10345 |
| Draw grid | checkbutton | % | draw_grid | `xschem redraw` | 10347 |
| Half Snap Threshold | command | G |  | `xschem set cadsnap [expr {$cadsnap / 2.0} ]` | 10352 |
| Double Snap Threshold | command | Shift-G |  | `xschem set cadsnap [expr {$cadsnap * 2.0} ]` | 10355 |
| Variable grid point size | checkbutton |  | big_grid_points | `xschem redraw` | 10358 |
| No XCopyArea drawing model | checkbutton | Ctrl+$ | draw_window | `if { $draw_window == 1} { xschem set draw_window 1} else { xschem s...` | 10362 |
| Fix for GPUs with broken tiled fill | checkbutton |  | fix_broken_tiled_fill | `if { $fix_broken_tiled_fill == 1} { xschem set fix_broken_tiled_fil...` | 10368 |
| Fix broken RDP mouse coordinates | checkbutton |  | fix_mouse_coord | `xschem set fix_mouse_coord $fix_mouse_coord` | 10379 |
| Netlist format / Symbol mode | cascade |  |  | `` | 10384 |

## `option.crosshair`  (3 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Draw snap cursor | checkbutton | Alt-Z | snap_cursor | `` | 10332 |
| Draw crosshair | checkbutton | Alt-X | draw_crosshair | `` | 10334 |
| Crosshair size | command |  |  | `input_line "Enter crosshair size (int, 0 = full screen width):" "se...` | 10336 |

## `option.netlist`  (8 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Flat netlist | checkbutton | : | flat_netlist | `if { $flat_netlist==1 } {xschem set flat_netlist 1} else { xschem s...` | 10388 |
| Split netlist | checkbutton |  | split_files | `` | 10393 |
| Spectre netlist | radiobutton | Ctrl+Shift+V | netlist_type | `xschem set netlist_type spectre; xschem redraw` | 10395 |
| Spice netlist | radiobutton | Ctrl+Shift+V | netlist_type | `xschem set netlist_type spice; xschem redraw` | 10398 |
| VHDL netlist | radiobutton | Ctrl+Shift+V | netlist_type | `xschem set netlist_type vhdl; xschem redraw` | 10401 |
| Verilog netlist | radiobutton | Ctrl+Shift+V | netlist_type | `xschem set netlist_type verilog; xschem redraw` | 10404 |
| tEDAx netlist | radiobutton | Ctrl+Shift+V | netlist_type | `xschem set netlist_type tedax; xschem redraw` | 10407 |
| Symbol global attrs | radiobutton | Ctrl+Shift+V | netlist_type | `xschem set netlist_type symbol; xschem redraw` | 10410 |

## `prop`  (7 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Edit | command | Q |  | `xschem edit_prop` | 10560 |
| Edit with editor | command | Shift+Q |  | `xschem edit_vi_prop` | 10561 |
| View | command | Ctrl+Shift+Q |  | `xschem view_prop` | 10562 |
| Toggle *_ignore attribute on selected instances | command | Shift+T |  | `xschem toggle_ignore` | 10563 |
| Change selected object insertion order | command | Shift+S |  | `xschem change_elem_order -1` | 10565 |
| Edit Header/License text | command | Shift+B |  | `update_schematic_header` | 10567 |
| Edit file (danger!) | command | Alt+Q |  | `xschem edit_file` | 10569 |

## `simulation`  (21 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Set netlist Dir | command |  |  | `set local_netlist_dir 0 set_netlist_dir 1` | 10713 |
| Set top level netlist name | command |  |  | `input_line {Set netlist file name} {xschem set netlist_name} [xsche...` | 10718 |
| Set netlist / graph / annotation precision | command |  |  | `input_line "Enter precision (int):" "set ev_precision" $ev_precision` | 10722 |
| Show netlist after netlist command | checkbutton | Shift+A | netlist_show | `` | 10726 |
| Keep symbols when traversing hierarchy | checkbutton |  | keep_symbols | `` | 10728 |
| Use netlist directory | radiobutton |  | local_netlist_dir | `set_netlist_dir 1` | 10730 |
| Use 'simulation' dir in schematic dir | radiobutton |  | local_netlist_dir | `set_netlist_dir 1` | 10733 |
| Use 'simulation/\[schname\]' dir in schematic dir | radiobutton |  | local_netlist_dir | `set_netlist_dir 1` | 10736 |
| Configure simulators and tools | command |  |  | `simconf` | 10739 |
| List running sub-processes | command |  |  | `` | 10741 |
| List running sub-processes | command |  |  | `list_running_cmds` | 10743 |
| View last job data | command |  |  | `if { [info exists execute(data,last)] } { viewdata $execute(data,la...` | 10747 |
| View last job errors | command |  |  | `if { [info exists execute(error,last)] } { viewdata $execute(error,...` | 10752 |
| Utile Stimuli Editor (GUI) | command |  |  | `inutile [xschem get current_dirname]/stimuli.[file rootname [file t...` | 10757 |
| Utile Stimuli Translate | command |  |  | `inutile_translate [xschem get current_dirname]/stimuli.[file rootna...` | 10760 |
| Shell [simulation path] | command |  |  | `if { [set_netlist_dir 0] ne "" } { get_shell $netlist_dir }` | 10763 |
| Edit Netlist | command |  |  | `edit_netlist [xschem get netlist_name fallback]` | 10768 |
| Send highlighted nets to viewer | command | Ctrl+Shift+X |  | `xschem create_plot_cmd` | 10770 |
| Changelog from current hierarchy | command |  |  | `viewdata [list_hierarchy]` | 10772 |
| Graphs | cascade |  |  | `` | 10778 |
| LVS | cascade |  |  | `` | 10804 |

## `simulation.graph`  (6 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Auto highlight plotted nets | checkbutton |  | auto_hilight_graph_nodes | `` | 10780 |
| Add waveform graph | command |  |  | `xschem add_graph` | 10782 |
| Add waveform reload launcher | command |  |  | `xschem place_symbol [find_file_first launcher.sym] "name=h5\ndescr=...` | 10783 |
| Annotate Operating Point into schematic | command |  |  | `set tctx::retval [select_raw [xschem get topwindow]] set show_hidde...` | 10788 |
| Live annotate probes with 'b' cursor | checkbutton |  | live_cursor2_backannotate | `` | 10798 |
| Hide graphs if no spice data loaded | checkbutton |  | hide_empty_graphs | `xschem redraw` | 10800 |

## `simulation.lvs`  (5 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| LVS netlist + Top level is a .subckt | checkbutton |  | lvs_netlist | `` | 10806 |
| Upper case .SUBCKT and .ENDS | checkbutton |  | uppercase_subckt | `` | 10808 |
| Top level is a .subckt | checkbutton |  | top_is_subckt | `` | 10810 |
| Set 'lvs_ignore' variable | checkbutton |  | lvs_ignore | `xschem rebuild_connectivity; xschem unhilight_all` | 10813 |
| Use 'spiceprefix' attribute | checkbutton |  | spiceprefix | `xschem redraw` | 10816 |

## `sym`  (17 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Show symbols | cascade |  |  | `` | 10572 |
| Set symbol width | command |  |  | `input_line "Enter Symbol width ($symbol_width)" "set symbol_width" ...` | 10585 |
| Make symbol from schematic | command | A |  | `xschem make_symbol` | 10589 |
| Make schematic from symbol | command | Ctrl+L |  | `xschem make_sch` | 10591 |
| Make schematic and symbol from selected components | command | Ctrl+Shift+H |  | `xschem make_sch_from_sel` | 10593 |
| Attach net labels to component instance | command | Shift+H |  | `xschem attach_labels` | 10595 |
| Create symbol pins from selected schematic pins | command | Alt+H |  | `schpins_to_sympins` | 10597 |
| Place symbol pin | command | Alt+P |  | `xschem add_symbol_pin` | 10599 |
| Place schematic input port | command | Ctrl+P |  | `xschem net_label 2` | 10601 |
| Place schematic output port | command | Ctrl+Shift+P |  | `xschem net_label 3` | 10603 |
| Place net pin label | command | Alt+L |  | `xschem net_label 1` | 10605 |
| Place net wire label | command | Alt+Shift+L |  | `xschem net_label 0` | 10607 |
| Change selected inst. texts to floaters | command |  |  | `xschem floaters_from_selected_inst` | 10609 |
| Unselect attached floaters | command |  |  | `xschem unselect_attached_floaters` | 10611 |
| List of nets | cascade |  |  | `` | 10615 |
| Search all search-paths for schematic associated to symbol | checkbutton |  | search_schematic | `` | 10629 |
| Allow duplicated instance names (refdes) | checkbutton |  | disable_unique_names | `` | 10632 |

## `sym.list`  (5 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Print list of highlight nets | command | J |  | `xschem print_hilight_net 1` | 10618 |
| Print list of highlight nets, with buses expanded | command | Alt-Ctrl-J |  | `xschem print_hilight_net 3` | 10620 |
| Create labels from highlight nets | command | Alt-J |  | `xschem print_hilight_net 4` | 10622 |
| Create labels from highlight nets with 'i' prefix | command | Alt-Shift-J |  | `xschem print_hilight_net 2` | 10624 |
| Create pins from highlight nets | command | Ctrl-J |  | `xschem print_hilight_net 0` | 10626 |

## `sym.sym`  (3 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Show symbol details | radiobutton | Alt+B | hide_symbols | `xschem set hide_symbols $hide_symbols; xschem redraw` | 10575 |
| Show instance Bounding boxes for subcircuit symbols | radiobutton | Alt+B | hide_symbols | `xschem set hide_symbols $hide_symbols; xschem redraw` | 10578 |
| Show instance Bounding boxes for all symbols | radiobutton | Alt+B | hide_symbols | `xschem set hide_symbols $hide_symbols; xschem redraw` | 10581 |

## `tools`  (21 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Insert symbol | command | Ins, Shift-I |  | `xschem place_symbol` | 10634 |
| Insert text | command | T |  | `xschem place_text` | 10635 |
| Insert wire | command | W |  | `xschem wire` | 10636 |
| Insert snap wire | command | Shift+W |  | `xschem snap_wire` | 10637 |
| Insert line | command | L |  | `xschem line` | 10638 |
| Insert rect | command | R |  | `xschem rect` | 10639 |
| Insert polygon | command | P |  | `xschem polygon` | 10640 |
| Insert arc | command | Shift+C |  | `xschem arc` | 10641 |
| Insert circle | command | Ctrl+Shift+C |  | `xschem circle` | 10642 |
| Insert JPG/PNG/SVG image | command |  |  | `xschem add_image` | 10643 |
| Grab screen area | command | Print Scrn |  | `xschem grabscreen` | 10644 |
| Search | command | Ctrl+F |  | `property_search` | 10646 |
| Align to Grid | command | Alt+U |  | `xschem align` | 10647 |
| Execute TCL command | command | = |  | `tclcmd` | 10648 |
| Join/Trim wires | command | & |  | `xschem trim_wires` | 10649 |
| Break wires at selected instance pins | command | ! |  | `xschem break_wires` | 10651 |
| Remove wires running through selected inst. pins | command | Ctrl-! |  | `xschem break_wires 1` | 10653 |
| Break wires at mouse position | command | Alt-Shift-Right Butt. |  | `xschem wire_cut noalign` | 10655 |
| Break wires at mouse position, align cut point | command | Alt-Right Butt. |  | `xschem wire_cut` | 10657 |
| Select all connected wires/labels/pins | command | Shift-Right Butt. |  | `xschem connected_nets` | 10659 |
| Select conn. wires, stop at junctions | command | Ctrl-Righ Butt. |  | `xschem connected_nets 1` | 10662 |

## `view`  (17 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Redraw | command | Esc |  | `xschem redraw` | 10486 |
| Fullscreen | command | \\ |  | `if {\$fullscreen == 1} {set fullscreen 2} ;# avoid hiding menu in t...` | 10487 |
| Zoom Full | command | F |  | `xschem zoom_full` | 10492 |
| Zoom In | command | Shift+Z |  | `xschem zoom_in` | 10493 |
| Zoom Out | command | Ctrl+Z |  | `xschem zoom_out` | 10494 |
| Zoom box | command | Z |  | `xschem zoom_box` | 10495 |
| Set snap value | command |  |  | `input_line "Enter snap value (float):" "xschem set cadsnap" $cadsnap` | 10496 |
| Set grid spacing | command |  |  | `input_line "Enter grid spacing (float):" "xschem set cadgrid" $cadgrid` | 10500 |
| Toggle colorscheme | command | Shift+O |  | `xschem toggle_colorscheme` | 10504 |
| Dim colors | command |  |  | `color_dim` | 10507 |
| Change current layer color | command |  |  | `change_color` | 10510 |
| Reset all colors to default | command |  |  | `reset_colors 1` | 10513 |
| Toggle variable line width | checkbutton | _ | change_lw | `xschem set change_lw $change_lw` | 10518 |
| Set line width | command | Alt+- |  | `input_line "Enter linewidth (float):" "xschem line_width"` | 10520 |
| Set grid point size | command |  |  | `input_line "Enter Grid point size (int or -1: $grid_point_size)" "s...` | 10524 |
| Tabbed interface | checkbutton |  | tabbed_interface | `setup_tabbed_interface` | 10528 |
| Show / Hide | cascade |  |  | `` | 10531 |

## `view.show`  (7 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| Show ERC Info window | checkbutton |  | show_infowindow | `if { $show_infowindow != 0 } {wm deiconify .infotext } else {wm wit...` | 10535 |
| Visible layers | command |  |  | `select_layers xschem redraw` | 10540 |
| Symbol text | checkbutton | Ctrl+B | sym_txt | `xschem set sym_txt $sym_txt; xschem redraw` | 10545 |
| Show Toolbar | checkbutton |  | toolbar_visible | `if { \$toolbar_visible } \" toolbar_show $topwin\" else \"toolbar_h...` | 10548 |
| Horizontal Toolbar | checkbutton |  | toolbar_horiz | `if { \$toolbar_visible } \" toolbar_hide $topwin; toolbar_show $top...` | 10552 |
| Show hidden texts | checkbutton |  | show_hidden_texts | `xschem update_all_sym_bboxes; xschem redraw` | 10556 |
| Draw grid axes | checkbutton |  | draw_grid_axes | `xschem redraw` | 10558 |

## `waves`  (11 items)

| label | type | accel | variable | command | line |
|---|---|---|---|---|---|
| External viewer | command |  |  | `waves external` | 10460 |
| Clear | command |  |  | `xschem raw_clear` | 10462 |
| Load first analysis found | command |  |  | `waves {}` | 10464 |
| Op Annotate | command |  |  | `set tctx::retval [select_raw [xschem get topwindow]] set show_hidde...` | 10465 |
| Op | command |  |  | `waves op` | 10474 |
| Dc | command |  |  | `waves dc` | 10475 |
| Ac | command |  |  | `waves ac` | 10476 |
| Tran | command |  |  | `waves tran` | 10477 |
| Noise | command |  |  | `waves noise` | 10478 |
| Sp | command |  |  | `waves ac` | 10479 |
| Spectrum | command |  |  | `waves ac` | 10480 |

