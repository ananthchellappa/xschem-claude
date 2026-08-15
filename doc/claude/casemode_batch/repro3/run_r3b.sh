#!/bin/bash
# Corrections + the xschem-side legs. rc is captured IMMEDIATELY (the first
# script lost it to a $(basename) between the run and the printf).
V=${1:-/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice}
S=${2:-/usr/local/bin/ngspice}
X=/home/qflow/dev/xschem/claude_1/xschem/src/xschem
D=$(cd "$(dirname "$0")" && pwd)/work2
rm -rf "$D"; mkdir -p "$D"; cd "$D" || exit 1
hdr(){ echo; echo "===== $* ====="; }
vars(){ if [ ! -f "$1" ]; then echo "ABSENT"; return; fi
  echo "$(grep -a '^Plotname:' "$1"|head -1|tr -d '\r') | $(grep -a '^No. Variables:' "$1"|head -1|tr -d '\r') | $(sed -n '/^Variables:/,/^\(Binary\|Values\):/p' "$1" 2>/dev/null | grep -aE '^[[:space:]]+[0-9]+[[:space:]]' | awk '{printf "%s ", $2}')"; }
NET='Vs In 0 DC 3
Rl In MidNode 1k
Rg MidNode 0 3k'
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

hdr "B1'  probe agrees with the run it describes (.spiceinit beside the deck)"
mkdir -p probe
cat > probe/deck.cir <<EOF
* probe deck
$NET
.temp 27
.save v(In)
.control
op
remzerovec
write $D/probe/out.raw
.endc
.end
EOF
echo 'set casemode=fold' > probe/.spiceinit
for m in "-D casemode=preserve" "-D casemode=distinguish"; do
  p=$(cd probe && printf 'echo CCM=$curcasemode\nquit 0\n' | $V -p $m 2>/dev/null | grep -a '^CCM=')
  (cd probe && rm -f out.raw; $V -b $m deck.cir >/dev/null 2>&1)
  printf '  spiceinit=fold  req %-22s probe:%-14s run: %s\n' "$m" "$p" "$(vars probe/out.raw)"
done
rm -f probe/.spiceinit
for m in "-D casemode=preserve" "-D casemode=distinguish"; do
  p=$(cd probe && printf 'echo CCM=$curcasemode\nquit 0\n' | $V -p $m 2>/dev/null | grep -a '^CCM=')
  (cd probe && rm -f out.raw; $V -b $m deck.cir >/dev/null 2>&1)
  printf '  no spiceinit    req %-22s probe:%-14s run: %s\n' "$m" "$p" "$(vars probe/out.raw)"
done

hdr "C4'  0072: rc, captured correctly"
printf '*\n.op\n.end\n' > dot.cir
printf '*\n.temp 27\n.control\nop\nremzerovec\nwrite %s/ctl.raw\n.endc\n.end\n' "$D" > ctl.cir
printf '*\nr1 0 0 1k\n.temp 27\n.control\nop\n.endc\n.end\n' > gnd.cir
printf '*\nr1 0 0 1k\n.op\n.end\n' > gnddot.cir
for b in "$V" "$S"; do n=$(basename $(dirname $b))/$(basename $b)
  $b -b dot.cir >/dev/null 2>e1; r1=$?
  rm -f ctl.raw; $b -b ctl.cir >/dev/null 2>e2; r2=$?
  $b -b gnd.cir >/dev/null 2>e3; r3=$?
  $b -b gnddot.cir >/dev/null 2>e4; r4=$?
  printf '  %-22s .op dotcard empty=%-4s ctrl-op empty=%-4s ctrl-op r1(0,0)=%-4s .op dotcard r1(0,0)=%s\n' "$n" "$r1" "$r2" "$r3" "$r4"
  printf '  %-22s   raw after ctrl-op: %s\n' '' "$(vars ctl.raw)"
done

hdr "C5'  rc / \$sim_status in OUR shape, captured correctly"
mkdeck absent.cir '.save v(nosuchnode)' 'op' 'print v(nosuchnode)' 'absent.raw'
mkdeck absentnp.cir '.save v(nosuchnode)' 'op' '' 'absentnp.raw'
mkdeck good.cir '.save v(In)
.save v(MidNode)' 'op' 'print v(In)' 'good.raw'
mkdeck folded.cir '.save v(midnode)' 'op' '' 'folded.raw'
run(){ local b=$1 f=$2 flag=$3 raw=$4; rm -f $raw; $b -b $flag $f >o.txt 2>e.txt; local r=$?
  printf '  %-14s %-11s %-24s rc=%-3s raw:%s\n' "$(basename $(dirname $b))" "$flag" "$f" "$r" "$(vars $raw)"; }
for b in "$V" "$S"; do
  run $b absent.cir "" absent.raw;   printf '  %-14s   token on log: %s\n' '' "$(cat o.txt e.txt|grep -a nosuchnode|head -2|tr '\n' '/')"
  run $b absentnp.cir "" absentnp.raw; printf '  %-14s   token on log: %s\n' '' "$(cat o.txt e.txt|grep -ac nosuchnode)"
  run $b good.cir "" good.raw
done
run $V folded.cir "-D casemode=distinguish" folded.raw
run $V folded.cir "-D casemode=preserve" folded.raw
hdr "C5''  the \$sim_status guard, our shape"
for kind in absent good; do
cat > g_$kind.cir <<EOF
* guard $kind
$NET
.temp 27
$( [ $kind = absent ] && echo '.save v(nosuchnode)' || echo '.save v(In)' )
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
write $D/g_$kind.raw
.endc
.end
EOF
for b in "$V" "$S"; do rm -f g_$kind.raw; $b -b g_$kind.cir >go.txt 2>ge.txt; r=$?
  printf '  %-14s %-7s rc=%-3s %-24s raw:%s\n' "$(basename $(dirname $b))" "$kind" "$r" "$(grep -a 'RUN-FAILED\|NO-SIM-STATUS' go.txt|tr '\n' ' ')" "$(vars g_$kind.raw)"; done
done

hdr "C7'  near-miss / analysis counts in OUR shape, distinguish"
$V -b -D casemode=distinguish folded.cir >c7o.txt 2>c7e.txt
printf '  Doing analysis: out=%s err=%s | differs-only-in-case: out=%s err=%s | experimental banner: %s\n' \
  "$(grep -ac 'Doing analysis' c7o.txt)" "$(grep -ac 'Doing analysis' c7e.txt)" \
  "$(grep -ac 'differs only in case' c7o.txt)" "$(grep -ac 'differs only in case' c7e.txt)" \
  "$(cat c7o.txt c7e.txt|grep -ac -i 'experimental')"

hdr "C8  save_all_v / savecurrents under preserve (.save all + .options savecurrents)"
cat > all.cir <<EOF
* save all
$NET
.temp 27
.options savecurrents
.save all
.control
op
remzerovec
write $D/all.raw
.endc
.end
EOF
for m in "-D casemode=fold" "-D casemode=preserve"; do rm -f all.raw; $V -b $m all.cir >/dev/null 2>&1; r=$?
  printf '  ver50 %-24s rc=%-3s %s\n' "$m" "$r" "$(vars all.raw)"; done

hdr "E  the xschem side reads these files (no source change yet)"
mkdeck e.cir '.save v(In)
.save v(MidNode)' 'tran 1u 10u' '' 'e_pres.raw'
rm -f e_pres.raw; $V -b -D casemode=preserve -D casemodewrite e.cir >/dev/null 2>&1
cp e_pres.raw e_hdr.raw
mkdeck e2.cir '.save v(In)
.save v(MidNode)' 'tran 1u 10u' '' 'e_fold.raw'
rm -f e_fold.raw; $V -b e2.cir >/dev/null 2>&1
echo "  preserve+header raw: $(vars e_hdr.raw)"
echo "  header lines       : $(grep -a '^Option:' e_hdr.raw | tr '\n' ' ')"
echo "  fold raw           : $(vars e_fold.raw)"
cat > rd.tcl <<EOF
set rc1 [xschem raw read $D/e_hdr.raw tran]
puts "XS: read(header-preserve)=\$rc1 list=[xschem raw list]"
puts "XS: value v(MidNode)=[catch {xschem raw value v(MidNode) 0} r1]/\$r1"
puts "XS: value v(midnode)=[catch {xschem raw value v(midnode) 0} r2]/\$r2"
xschem raw clear
set rc2 [xschem raw read $D/e_fold.raw tran]
puts "XS: read(fold)=\$rc2 list=[xschem raw list]"
puts DONE
EOF
timeout 60 $X --nogui --pipe -q --script rd.tcl 2>&1 | grep -a '^XS:\|^DONE\|rror' | head -20
echo; echo "workdir: $D"
