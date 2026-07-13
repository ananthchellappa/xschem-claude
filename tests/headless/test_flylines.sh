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

# ---------------------------------------------------------------------------
rm -rf "$TMP"
if [ "$fail" = 0 ]; then echo "RESULT: ALL PASS"; else echo "RESULT: $fail FAILED"; exit 1; fi
