# Negative stripe-angles must RENDER (tilted the opposite way), not silently fall back to flat.
# GUI headless (needs X to rasterize). Renders a thick striped highlighted wire to PNG and counts
# drawn (non-black) pixels. A horizontal wire's -A render is the vertical mirror of its +A render,
# so the two must have ~equal drawn area; and a tilted render covers less than the perpendicular
# (angle 0) one. Before the fix, draw.c gated the cairo stripe path on `angle > 0`, so negative
# angles rendered as flat angle-0 dashes (drawn area == angle 0, and != the +A mirror).
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_angle_render.tcl
# NOTE: print-png on WSLg has a rare fresh-process flake (see net-hilight-styles memory); rerun.

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
set tmp [file join [pwd] _nhrender_[pid]] ; file delete -force $tmp ; file mkdir $tmp

proc render {angle outfile} {
  global tmp
  xschem clear force schematic ; xschem set modified 0
  xschem wire -200 0 200 0
  set ::net_hilight_style [list [list 0 4 14 {8 8} $angle 0 none 0]]
  xschem update_net_hilight_style
  xschem unselect_all ; xschem select wire 0 ; xschem hilight
  update idletasks
  xschem print png $outfile 800 400 -250 -100 250 100
  update idletasks
}
proc nonblack {png} {
  set img [image create photo -file $png]
  set W [image width $img] ; set H [image height $img] ; set n 0
  for {set y 0} {$y < $H} {incr y} {
    for {set x 0} {$x < $W} {incr x} {
      lassign [$img get $x $y] r g b
      if {$r || $g || $b} { incr n }
    }
  }
  image delete $img ; return $n
}

render 0   $tmp/a0.png   ; set n0   [nonblack $tmp/a0.png]
render 40  $tmp/ap.png   ; set np   [nonblack $tmp/ap.png]
render -40 $tmp/an.png   ; set nn   [nonblack $tmp/an.png]
puts "drawn pixels: angle0=$n0  angle+40=$np  angle-40=$nn"

# N1: a -40 stripe is actually TILTED, so it covers clearly less than the perpendicular (angle 0)
check "N1 angle -40 renders tilted (not flat like angle 0)" \
  [expr {$nn < $n0 * 0.9}] "(nn=$nn n0=$n0 ratio=[format %.3f [expr {$nn*1.0/$n0}]])"

# N2: -40 is the EXACT vertical mirror of +40 -> equal drawn area. The mirror is deterministic
# (diff 0 across runs), so the tight bound also catches a missing fabs() coverage slack, which
# leaves a far-end gap (~59px here) that this would otherwise miss with a loose tolerance.
check "N2 angle -40 mirrors +40 (equal drawn area, fabs coverage)" \
  [expr {abs($nn - $np) <= 20}] "(nn=$nn np=$np diff=[expr {abs($nn-$np)}])"

file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
