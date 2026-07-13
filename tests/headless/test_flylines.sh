#!/bin/sh
# Hover fly-lines -- connectivity/clustering logic (Track A), headless.
# See doc/claude/specs/hover_flylines.md and
#     doc/claude/suggestions/flyline_implementation_plan.md
#
# Drives the read-only query command `xschem flylines net <name> | at <x> <y>` and asserts
# on its returned dict. Runs --nogui (pure data, no display). --norecent belt-and-suspenders
# (the session is already --script/--pipe gated, commit 3dc41ba2) so the user's recent list
# is never touched.
#
#   sh tests/headless/test_flylines.sh
# Prints "RESULT: ALL PASS" / "RESULT: N FAILED"; exits nonzero on failure.

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
XSCHEM="$REPO/src/xschem"
FIX="$HERE/flylines"
TMP=$(mktemp -d /tmp/xschem_flylines.XXXXXX)
fail=0

ok()  { echo "ok:   $1"; }
bad() { echo "FAIL: $1  [got: $2]"; fail=$((fail+1)); }

if [ ! -x "$XSCHEM" ]; then echo "FATAL: $XSCHEM not built"; exit 3; fi

# probe NAME FIXTURE EXPR  -- optionally load FIXTURE (or "" for none), eval EXPR, echo result.
probe() {
  _n=$1; _fx=$2; _expr=$3
  {
    echo "set fd [open {$TMP/$_n.out} w]"
    [ -n "$_fx" ] && echo "if {[catch {xschem load {$_fx}} e]} {puts \$fd \"LOADERR: \$e\"; close \$fd; return}"
    echo "if {[catch {$_expr} r]} {puts \$fd \"ERR: \$r\"} else {puts \$fd \$r}"
    echo "close \$fd"
  } > "$TMP/$_n.tcl"
  HOME="$TMP" timeout 30 "$XSCHEM" --nogui --pipe -q --nolog --norecent --script "$TMP/$_n.tcl" >/dev/null 2>&1
  cat "$TMP/$_n.out" 2>/dev/null
}

# ---- A0: command skeleton -------------------------------------------------
r=$(probe a0_usage "" 'xschem flylines')
case "$r" in
  ERR:*) ok "A0 no-subcommand -> error" ;;
  *)     bad "A0 no-subcommand should error" "$r" ;;
esac

r=$(probe a0_empty "" 'xschem flylines net foo')
[ "$r" = "net {} members {} clusters {} segments {}" ] \
  && ok "A0 unknown net -> empty dict" \
  || bad "A0 empty-dict shape" "$r"

# ---- A1: net resolution ---------------------------------------------------
r=$(probe a1_byname "$FIX/two_clk_no_wire.sch" 'lindex [xschem flylines net CLK] 1')
[ "$r" = "CLK" ] && ok "A1 net CLK resolves by name" || bad "A1 net-by-name" "$r"

r=$(probe a1_atpoint "$FIX/two_clk_no_wire.sch" 'lindex [xschem flylines at 0 0] 1')
[ "$r" = "CLK" ] && ok "A1 net resolves at a point on a label" || bad "A1 net-at-point" "$r"

r=$(probe a1_unknown "$FIX/two_clk_no_wire.sch" 'lindex [xschem flylines net NOPE] 1')
[ "$r" = "" ] && ok "A1 unknown net name -> empty" || bad "A1 unknown-net" "$r"

# ---- A2: member enumeration ----------------------------------------------
r=$(probe a2_members "$FIX/clk_members4.sch" 'llength [dict get [xschem flylines net CLK] members]')
[ "$r" = "4" ] && ok "A2 net CLK has 4 members (2 wires + 2 label pins)" || bad "A2 member count" "$r"

r=$(probe a2_kinds "$FIX/clk_members4.sch" \
  'set m [dict get [xschem flylines net CLK] members]; list [llength [lsearch -all -inline -index 0 $m wire]] [llength [lsearch -all -inline -index 0 $m pin]]')
[ "$r" = "2 2" ] && ok "A2 members split 2 wires + 2 pins" || bad "A2 member kinds" "$r"

r=$(probe a2_members_none "$FIX/clk_members4.sch" 'llength [dict get [xschem flylines net NOPE] members]')
[ "$r" = "0" ] && ok "A2 unknown net -> 0 members" || bad "A2 members none" "$r"

# ---- A3: physical clustering (the core; implicit-only distinction) --------
# fixture-A: two CLK labels, NO wire between -> two disjoint clusters
r=$(probe a3_nowire "$FIX/two_clk_no_wire.sch" 'llength [dict get [xschem flylines net CLK] clusters]')
[ "$r" = "2" ] && ok "A3 two labels, no wire -> 2 clusters" || bad "A3 no-wire clusters" "$r"

# fixture-B: same two labels joined by a drawn wire -> ONE cluster
r=$(probe a3_wired "$FIX/two_clk_wired.sch" 'llength [dict get [xschem flylines net CLK] clusters]')
[ "$r" = "1" ] && ok "A3 two labels joined by wire -> 1 cluster" || bad "A3 wired clusters" "$r"

# clk_members4: wire1+label1 touch / wire2+label2 touch, the two groups gap-separated -> 2
r=$(probe a3_two "$FIX/clk_members4.sch" 'llength [dict get [xschem flylines net CLK] clusters]')
[ "$r" = "2" ] && ok "A3 members4 -> 2 clusters" || bad "A3 members4 clusters" "$r"

# every member belongs to exactly one cluster (partition is complete + disjoint)
r=$(probe a3_partition "$FIX/clk_members4.sch" \
  'set d [xschem flylines net CLK]; set n [llength [dict get $d members]]; set s 0; foreach c [dict get $d clusters] {incr s [llength [dict get $c members]]}; list $n $s')
[ "$r" = "4 4" ] && ok "A3 clusters partition all 4 members" || bad "A3 partition" "$r"

# A3 adversarial: a pin on a wire MIDDLE (T-junction) joins that wire (point-on-segment),
# an isolated same-name label stays separate -> 2 clusters over 3 members
r=$(probe a3_midwire "$FIX/pin_mid_wire.sch" \
  'set d [xschem flylines net CLK]; list [llength [dict get $d clusters]] [llength [dict get $d members]]')
[ "$r" = "2 3" ] && ok "A3 pin mid-wire (T) unions; isolated stays -> 2 clusters" || bad "A3 mid-wire" "$r"

# A3 adversarial: 3 wires end-to-end + 1 label all propagate to CLK and union transitively -> 1
r=$(probe a3_chain "$FIX/wire_chain.sch" \
  'set d [xschem flylines net CLK]; list [llength [dict get $d clusters]] [llength [dict get $d members]]')
[ "$r" = "1 4" ] && ok "A3 transitive wire chain -> 1 cluster (4 members)" || bad "A3 chain" "$r"

# A3 adversarial: three isolated same-name labels -> 3 disjoint clusters
r=$(probe a3_three "$FIX/three_clusters.sch" 'llength [dict get [xschem flylines net CLK] clusters]')
[ "$r" = "3" ] && ok "A3 three isolated labels -> 3 clusters" || bad "A3 three" "$r"

# ---- A4: cluster anchors --------------------------------------------------
# each cluster reports an anchor at a member point; the two label clusters -> the two pins
r=$(probe a4_anchors "$FIX/two_clk_no_wire.sch" \
  'set a [list]; foreach c [dict get [xschem flylines net CLK] clusters] {lappend a [dict get $c anchor]}; lsort $a')
[ "$r" = "{0 0} {200 0}" ] && ok "A4 cluster anchors are the two label pins" || bad "A4 anchors" "$r"

# a mixed cluster (wire + pins) anchors on a PIN (electrical), not the wire midpoint
r=$(probe a4_pinpref "$FIX/two_clk_wired.sch" \
  'dict get [lindex [dict get [xschem flylines net CLK] clusters] 0] anchor')
[ "$r" = "0 0" ] && ok "A4 mixed cluster anchors on a pin, not wire midpoint" || bad "A4 pin-pref" "$r"

# ---- A5: star segments + implicit-only rule -------------------------------
# N clusters -> N-1 segments from the hub (cluster 0 for the `net` form)
r=$(probe a5_three "$FIX/three_clusters.sch" 'llength [dict get [xschem flylines net CLK] segments]')
[ "$r" = "2" ] && ok "A5 three clusters -> 2 star segments" || bad "A5 three segs" "$r"

r=$(probe a5_nowire "$FIX/two_clk_no_wire.sch" 'dict get [xschem flylines net CLK] segments')
[ "$r" = "{0 0 200 0}" ] && ok "A5 two clusters -> 1 segment hub->other" || bad "A5 nowire seg" "$r"

# implicit-only rule: two labels joined by a wire are ONE cluster -> ZERO segments
r=$(probe a5_wired "$FIX/two_clk_wired.sch" 'llength [dict get [xschem flylines net CLK] segments]')
[ "$r" = "0" ] && ok "A5 wired pair (1 cluster) -> 0 segments (implicit-only)" || bad "A5 wired seg" "$r"

# a single-cluster net -> no fly-lines
r=$(probe a5_single "$FIX/one_label.sch" 'llength [dict get [xschem flylines net CLK] segments]')
[ "$r" = "0" ] && ok "A5 single cluster -> 0 segments" || bad "A5 single seg" "$r"

# `at` form: the hub is the cluster UNDER THE CURSOR -> segment starts at that anchor
r=$(probe a5_hub_at "$FIX/two_clk_no_wire.sch" 'dict get [xschem flylines at 200 0] segments')
[ "$r" = "{200 0 0 0}" ] && ok "A5 at-form hub is the hovered cluster" || bad "A5 hub-at" "$r"

# ---- A6: exclude auto-named (#net) nets -----------------------------------
# a bare wire gets an auto name (#netN); it can never connect implicitly -> excluded entirely
r=$(probe a6_bare_net "$FIX/bare_wires.sch" 'lindex [xschem flylines at 50 0] 1')
[ "$r" = "" ] && ok "A6 hover on a #net wire -> net excluded (empty)" || bad "A6 bare net" "$r"

r=$(probe a6_bare_full "$FIX/bare_wires.sch" 'xschem flylines at 50 0')
[ "$r" = "net {} members {} clusters {} segments {}" ] \
  && ok "A6 #net query yields the empty dict" || bad "A6 bare full" "$r"

r=$(probe a6_bare_byname "$FIX/bare_wires.sch" 'lindex [xschem flylines net #net1] 1')
[ "$r" = "" ] && ok "A6 explicit net #net1 also excluded" || bad "A6 bare byname" "$r"

# ---- A7: bus aggregate-per-label (per-bit overlap) ------------------------
# bus_shared: two A[1:0] labels + one A[0] label, none wired.
# hovering the bus A[1:0] aggregates every object sharing ANY bit -> all 3 labels
r=$(probe a7_bus_members "$FIX/bus_shared.sch" 'llength [dict get [xschem flylines net {A[1:0]}] members]')
[ "$r" = "3" ] && ok "A7 bus A[1:0] aggregates all bit-sharing labels (3)" || bad "A7 bus members" "$r"

r=$(probe a7_bus_segs "$FIX/bus_shared.sch" \
  'set d [xschem flylines net {A[1:0]}]; list [llength [dict get $d clusters]] [llength [dict get $d segments]]')
[ "$r" = "3 2" ] && ok "A7 bus -> 3 clusters, 2 star segments" || bad "A7 bus segs" "$r"

# scalar A[0] is a bit of the bus -> links to both A[1:0] labels too (symmetric) -> 3
r=$(probe a7_bit_link "$FIX/bus_shared.sch" 'llength [dict get [xschem flylines net {A[0]}] members]')
[ "$r" = "3" ] && ok "A7 scalar A[0] links the bus labels carrying that bit (3)" || bad "A7 bit link" "$r"

# per-bit PRECISION: A[1] is carried only by the two bus labels, NOT the A[0] scalar -> 2
r=$(probe a7_bit_precise "$FIX/bus_shared.sch" 'llength [dict get [xschem flylines net {A[1]}] members]')
[ "$r" = "2" ] && ok "A7 A[1] matches only bus labels, not A[0] (precise)" || bad "A7 bit precise" "$r"

# ---- A9: config-var defaults ---------------------------------------------
r=$(probe a9_defaults "" 'list $flylines $flylines_show_globals $flylines_cap $flylines_width $flylines_dash')
[ "$r" = "0 0 32 1 4" ] && ok "A9 config-var defaults present" || bad "A9 defaults" "$r"

# ---------------------------------------------------------------------------
rm -rf "$TMP"
if [ "$fail" = 0 ]; then echo "RESULT: ALL PASS"; else echo "RESULT: $fail FAILED"; exit 1; fi
