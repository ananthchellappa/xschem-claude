#!/bin/bash
# Round-3 verification against OUR deck shape (ase.tcl render_deck):
#   control-only analyses (op/dc/ac/tran as control commands, no dot card),
#   .save per output, print per output, remzerovec, bare `write <abs path>`.
# Run:  ./run_r3.sh
V=${1:-/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice}
S=${2:-/usr/local/bin/ngspice}
D=$(cd "$(dirname "$0")" && pwd)/work
rm -rf "$D"; mkdir -p "$D"; cd "$D" || exit 1

hdr(){ echo; echo "===== $* ====="; }
vars(){ # $1 = raw file -> "n | name0 | name1 ..."
  if [ ! -f "$1" ]; then echo "ABSENT"; return; fi
  local n; n=$(grep -a '^No. Variables:' "$1" | head -1 | tr -d '\r')
  local pn; pn=$(grep -a '^Plotname:' "$1" | head -1 | tr -d '\r')
  local vl; vl=$(sed -n '/^Variables:/,/^\(Binary\|Values\):/p' "$1" 2>/dev/null | \
    grep -aE '^[[:space:]]+[0-9]+[[:space:]]' | awk '{printf "%s ", $2}')
  echo "$pn | $n | $vl"
}
opt(){ grep -ac '^Option:' "$1" 2>/dev/null | tr -d '\n'; grep -a '^Option:' "$1" 2>/dev/null | head -2 | tr '\n' ' '; }

# ---- the divider netlist, as our netlister emits it (schematic case) --------
NET='Vs In 0 DC 3
Rl In MidNode 1k
Rg MidNode 0 3k'

# ase-shaped deck. $1 = save spelling(s) (newline sep), $2 = analysis cmds,
# $3 = print lines, $4 = raw name, $5 = extra control lines (before analysis)
mkdeck(){ local f=$1 saves=$2 ana=$3 prints=$4 raw=$5 extra=$6
cat > "$f" <<EOF
* ase-shape deck
$NET
.temp 27
$saves
.control
$extra
$ana
$prints
remzerovec
write $D/$raw
.endc
.end
EOF
}

echo "ver_50: $($V --version 2>&1 | head -2 | tail -1)"
echo "stamp : $(printf '*\n.end\n' > s.cir; $V -b -n -r s.raw s.cir >/dev/null 2>&1; grep -a '^Command:' s.raw)"
echo "stock : $($S --version 2>&1 | head -2 | tail -1)"

# ============================================================ A. core enabler
hdr "A1  our shape, schematic-case .save, op — labels per mode"
mkdeck a1.cir '.save v(In)
.save v(MidNode)' 'op' 'print v(In)
print v(MidNode)' 'a1.raw'
for m in "" "-D casemode=fold" "-D casemode=preserve" "-D casemode=distinguish"; do
  rm -f a1.raw; $V -b $m a1.cir >a1.out 2>a1.err; rc=$?
  printf '  %-28s rc=%-3s %s\n' "ver50 ${m:-<noflag>}" "$rc" "$(vars a1.raw)"
  printf '  %-28s print echoes: %s\n' '' "$(grep -a '^v(' a1.out | tr '\n' ' ')"
done
rm -f a1.raw; $S -b a1.cir >a1s.out 2>a1s.err; rc=$?
printf '  %-28s rc=%-3s %s\n' 'stock-46' "$rc" "$(vars a1.raw)"
printf '  %-28s print echoes: %s\n' '' "$(grep -a '^v(' a1s.out | tr '\n' ' ')"

hdr "A2  legacy state file: FOLDED .save spelling (0056)"
mkdeck a2.cir '.save v(midnode)' 'op' 'print v(midnode)' 'a2.raw'
for m in "-D casemode=fold" "-D casemode=preserve" "-D casemode=distinguish"; do
  rm -f a2.raw; $V -b $m a2.cir >a2.out 2>a2.err; rc=$?
  printf '  %-28s rc=%-3s %s\n' "ver50 $m" "$rc" "$(vars a2.raw)"
done

hdr "A3  branch currents + hierarchy (F4 / item 2 fixup / item 12)"
cat > a3.cir <<EOF
* hier current
.subckt divsub A Mid
Vp A Mid DC 0
Rq Mid 0 2k
.ends
Vs In 0 DC 3
X1 In Mid divsub
.temp 27
.save i(Vs)
.save v(In)
.control
op
print i(Vs)
remzerovec
write $D/a3.raw
.endc
.end
EOF
for m in "-D casemode=fold" "-D casemode=preserve"; do
  rm -f a3.raw; $V -b $m a3.cir >a3.out 2>a3.err; rc=$?
  printf '  %-28s rc=%-3s %s\n' "ver50 $m" "$rc" "$(vars a3.raw)"
done

# ============================================================ B. probe
hdr "B1  \$curcasemode probe with real argv, cwd = deck dir"
mkdir -p probe; cp a1.cir probe/
echo 'set casemode=fold' > probe/.spiceinit
for m in "-D casemode=preserve" "-D casemode=distinguish"; do
  got=$( cd probe && printf 'echo CCM=$curcasemode\nquit 0\n' | $V -p $m 2>/dev/null | grep -a '^CCM=' )
  ( cd probe && rm -f "$D/b1.raw"; $V -b $m a1.cir >/dev/null 2>&1 )
  printf '  cwd=deck  %-24s probe:%-16s real run: %s\n' "$m" "$got" "$(vars b1.raw)"
done
# wrong cwd (the trap)
got=$( printf 'echo CCM=$curcasemode\nquit 0\n' | $V -p -D casemode=preserve 2>/dev/null | grep -a '^CCM=' )
echo "  cwd=elsewhere -D casemode=preserve  probe:$got   <- confidently wrong if run uses probe/"
echo -n "  stock probe: "; printf 'echo CCM=$curcasemode\nquit 0\n' | $S -p 2>&1 | grep -a 'CCM\|such variable' | tr '\n' ' '; echo

# ============================================================ C. round-3 items
hdr "C1  phantom v(all): one saved vector, OUR shape (bare write)"
mkdeck c1.cir '.save v(In)' 'op' 'print v(In)' 'c1.raw'
for b in "$V" "$S"; do
  rm -f c1.raw; $b -b c1.cir >/dev/null 2>&1
  printf '  %-28s %s\n' "$(basename $(dirname $b))/$(basename $b)" "$(vars c1.raw)"
done
mkdeck c1t.cir '.save v(In)' 'tran 1u 10u' 'print v(In)' 'c1t.raw'
for b in "$V" "$S"; do
  rm -f c1t.raw; $b -b c1t.cir >/dev/null 2>&1
  printf '  %-28s (tran) %s\n' "$(basename $(dirname $b))/$(basename $b)" "$(vars c1t.raw)"
done

hdr "C2  duplicate column 0073: does OUR bare write hit it?"
mkdeck c2.cir '.save v(In)
.save v(MidNode)' 'op' '' 'c2.raw'
for b in "$V" "$S"; do rm -f c2.raw; $b -b c2.cir >/dev/null 2>&1
  printf '  %-28s op 2-save bare write: %s\n' "$(basename $b)" "$(vars c2.raw)"; done
# and the shape 0073 is about, for contrast: named vectors on the write line
cat > c2b.cir <<EOF
* named write
$NET
.temp 27
.save v(In)
.control
op
write $D/c2b.raw v(In)
.endc
.end
EOF
for b in "$V" "$S"; do rm -f c2b.raw; $b -b c2b.cir >/dev/null 2>&1
  printf '  %-28s op 1-save write f v(In): %s\n' "$(basename $b)" "$(vars c2b.raw)"; done
# dc sweep, our shape
mkdeck c2c.cir '.save v(In)
.save v(MidNode)' 'dc Vs 0 3 1' '' 'c2c.raw'
for b in "$V" "$S"; do rm -f c2c.raw; $b -b c2c.cir >/dev/null 2>&1
  printf '  %-28s dc  2-save bare write: %s\n' "$(basename $b)" "$(vars c2c.raw)"; done

hdr "C3  Option: casemode= header in OUR shape (set casemodewrite)"
mkdeck c3.cir '.save v(In)
.save v(MidNode)' 'op' '' 'c3.raw' 'set casemodewrite'
for m in "-D casemode=preserve" "-D casemode=fold"; do
  rm -f c3.raw; $V -b $m c3.cir >/dev/null 2>&1
  printf '  %-28s control `set casemodewrite`: [%s]\n' "$m" "$(opt c3.raw)"
done
mkdeck c3b.cir '.save v(In)' 'op' '' 'c3b.raw'
rm -f c3b.raw; $V -b -D casemode=preserve -D casemodewrite c3b.cir >/dev/null 2>&1
printf '  %-28s -D casemodewrite (bare)    : [%s]\n' '' "$(opt c3b.raw)"
rm -f c3b.raw; $V -b -D casemode=preserve -D casemodewrite=TRUE c3b.cir >/dev/null 2>&1
printf '  %-28s -D casemodewrite=TRUE      : [%s]\n' '' "$(opt c3b.raw)"
rm -f c3b.raw; $V -b -D casemode=preserve c3b.cir >/dev/null 2>&1
printf '  %-28s no gate                    : [%s]\n' '' "$(opt c3b.raw)"

hdr "C4  0072 .op abort: our control-only shape vs a dot card"
printf '*\n.op\n.end\n' > c4dot.cir
printf '*\n.temp 27\n.control\nop\nremzerovec\nwrite %s/c4.raw\n.endc\n.end\n' "$D" > c4ctl.cir
for b in "$V" "$S"; do
  $b -b c4dot.cir >/dev/null 2>c4dot.err; printf '  %-24s .op DOT card, empty netlist   rc=%s  %s\n' "$(basename $b)" "$?" "$(head -c 90 c4dot.err|tr '\n' ' ')"
  rm -f c4.raw; $b -b c4ctl.cir >/dev/null 2>c4ctl.err; printf '  %-24s `op` in .control, empty net   rc=%s  %s\n' "$(basename $b)" "$?" "$(head -c 90 c4ctl.err|tr '\n' ' ')"
done
# non-ground-node-free but non-empty (the netlister-can-emit-this case)
printf '*\nr1 0 0 1k\n.control\nop\n.endc\n.end\n' > c4g.cir
for b in "$V" "$S"; do $b -b c4g.cir >/dev/null 2>&1; printf '  %-24s r1 0 0 + control op          rc=%s\n' "$(basename $b)" "$?"; done

hdr "C5  rc and \$sim_status in OUR shape (absent node / mis-cased .save)"
mkdeck c5.cir '.save v(nosuchnode)' 'op' 'print v(nosuchnode)' 'c5.raw'
for b in "$V" "$S"; do rm -f c5.raw; $b -b c5.cir >c5.out 2>c5.err
  printf '  %-24s .save absent node   rc=%-3s raw:%s\n' "$(basename $b)" "$?" "$(vars c5.raw)"
  printf '  %-24s   token named on either stream: %s\n' '' "$(cat c5.out c5.err | grep -ac nosuchnode)"
done
mkdeck c5b.cir '.save v(midnode)' 'op' '' 'c5b.raw'
rm -f c5b.raw; $V -b -D casemode=distinguish c5b.cir >c5b.out 2>c5b.err
printf '  %-24s folded .save, distinguish   rc=%-3s raw:%s\n' 'ver50' "$?" "$(vars c5b.raw)"
# guard version
cat > c5g.cir <<EOF
* guard in our shape
$NET
.temp 27
.save v(nosuchnode)
.control
op
if \$?sim_status = 0
  echo NO-SIM-STATUS
end
if \$sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
write $D/c5g.raw
.endc
.end
EOF
for b in "$V" "$S"; do rm -f c5g.raw; $b -b c5g.cir >c5g.out 2>c5g.err
  printf '  %-24s guarded             rc=%-3s %s raw:%s\n' "$(basename $b)" "$?" "$(grep -a 'RUN-FAILED\|NO-SIM-STATUS' c5g.out|tr '\n' ' ')" "$(vars c5g.raw)"
done
# guard on a GOOD deck (must not fire)
cat > c5h.cir <<EOF
* guard, good deck
$NET
.temp 27
.save v(In)
.control
op
if \$sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
write $D/c5h.raw
.endc
.end
EOF
for b in "$V" "$S"; do rm -f c5h.raw; $b -b c5h.cir >c5h.out 2>c5h.err
  printf '  %-24s guard on GOOD deck  rc=%-3s %s raw:%s\n' "$(basename $b)" "$?" "$(grep -ac RUN-FAILED c5h.out)" "$(vars c5h.raw)"
done

hdr "C6  fold collision warning (Q3 / item 14a)"
cat > c6.cir <<EOF
* collision
V1 in 0 dc 1.5
R1 in Out 1k
R2 out 0 1k
.temp 27
.control
op
.endc
.end
EOF
for m in "" "-D casemode=fold" "-D casemode=preserve" "-D casemode=distinguish"; do
  $V -b $m c6.cir >c6.out 2>c6.err
  printf '  %-28s %s\n' "ver50 ${m:-<noflag>}" "$(cat c6.out c6.err | grep -a 'differ only in case' | head -2 | tr '\n' '/')"
done
$S -b c6.cir >c6s.out 2>c6s.err
printf '  %-28s %s\n' 'stock-46' "[$(cat c6s.out c6s.err | grep -ac 'differ only in case') lines]"

hdr "C7  near-miss warning count in OUR shape (R4: 1 sim, not 2)"
mkdeck c7.cir '.save v(midnode)' 'op' '' 'c7.raw'
$V -b -D casemode=distinguish c7.cir >c7.out 2>c7.err
printf '  analyses=%s  nearmiss stdout=%s stderr=%s\n' "$(grep -ac 'Doing analysis' c7.out c7.err | paste -sd+ | bc)" "$(grep -ac 'differs only in case' c7.out)" "$(grep -ac 'differs only in case' c7.err)"

# ============================================================ D. no-opt-in safety
hdr "D1  byte-identity, our shape, no flags: ver_50 vs stock-46"
mkdeck d1.cir '.save v(In)
.save v(MidNode)' 'tran 1u 10u' '' 'd1.raw'
rm -f d1.raw; $V -b d1.cir >/dev/null 2>&1; cp d1.raw d1_v.raw
rm -f d1.raw; $S -b d1.cir >/dev/null 2>&1; cp d1.raw d1_s.raw
for f in d1_v d1_s; do grep -av '^Date:\|^Command:' $f.raw > $f.cmp; done
if cmp -s d1_v.cmp d1_s.cmp; then echo "  IDENTICAL ($(stat -c%s d1_v.raw) vs $(stat -c%s d1_s.raw) bytes raw)"; else echo "  DIFFER:"; cmp d1_v.cmp d1_s.cmp | head -3; fi

echo; echo "workdir: $D"
