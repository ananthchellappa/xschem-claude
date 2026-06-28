# Issue 0044 — a custom-RGB net-highlight style must export (SVG/PDF) in its actual color, not the
# fixed fallback layer color. get_color() collapses a custom style (color_layer<0) to a fallback layer
# for the layer-indexed SVG/PS exporters; the export must paint the highlighted wire/symbol in the
# style's real RGB (SVG: an inline style override of the CSS class color), so it matches the display.
#
# Uses a NON-palette color (#1a9b8c teal) so a match cannot be a coincidence with a layer color.
# Needs Tk/X: resolving a custom color to its RGB goes through X (resolve_hilight_style_rgb guards on
# has_x), exactly as the on-screen path does. Run:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_export_custom_color.tcl

if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; custom-color resolution needs X)"; flush stdout; exit 0 }

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }

set dir [file join [pwd] _nhexport_[pid]] ; file delete -force $dir ; file mkdir $dir

# style 0 = a custom TEAL color (#1a9b8c, color_layer<0), thick solid; highlight a wire with it
set ::net_hilight_style {{0 #1a9b8c 4 {} 0 0 none 0}}
catch {xschem update_net_hilight_style}
xschem clear force ; xschem set_modify 0
xschem wire 0 0 200 0
xschem unselect_all ; xschem select wire 0 ; xschem hilight
update idletasks

# export SVG of the area around the wire
set svgf [file join $dir wire.svg]
catch {xschem print svg $svgf 0 0 -50 -50 250 50} e
check "E1 SVG export produced a file" [expr {[file exists $svgf] && [file size $svgf] > 0}] \
  "(rc=$e size=[expr {[file exists $svgf] ? [file size $svgf] : -1}])"

set fd [open $svgf r] ; set svg [read $fd] ; close $fd

# the highlighted wire must carry the custom color #1a9b8c as an inline stroke (SVG uses CSS class
# colors; the fix adds an inline style="stroke:#..." override on the highlighted element).
check "E2 custom highlight color appears in the SVG" [expr {[string match -nocase *1a9b8c* $svg]}] \
  "(found=[expr {[string match -nocase *1a9b8c* $svg] ? 1 : 0}])"
check "E3 custom color is an inline stroke override" [regexp -nocase {stroke:#1a9b8c} $svg] {}

# not-hollow guard: a drawn path/circle element carries the inline custom stroke (not e.g. a stray
# comment or the layer CSS block, which would still be the wrong fallback color).
set elem_has_color 0
foreach ln [split $svg \n] {
  if {[regexp {<(path|circle)[^>]*stroke:#1a9b8c} $ln]} { set elem_has_color 1 ; break }
}
check "E4 a drawn element (path/circle) has the custom stroke" $elem_has_color {}

# PS/PDF path: set_ps_colors emits the color as an inline "r g b RGB" triple (each component /256).
# #1a9b8c = 26/155/140 -> 0.101562 0.605469 0.546875 ; the fallback layer would emit a different triple.
set psf [file join $dir wire.ps]
catch {xschem print ps $psf 0 0 -50 -50 250 50} e
check "E5 PS export produced a file" [expr {[file exists $psf] && [file size $psf] > 0}] "(rc=$e)"
set fd [open $psf r] ; set ps [read $fd] ; close $fd
check "E6 PS emits the custom color as an RGB triple" [regexp {0\.101562 [0-9.]+ [0-9.]+ RGB} $ps] \
  "(found=[regexp {0\.101562 [0-9.]+ [0-9.]+ RGB} $ps])"

file delete -force $dir
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
