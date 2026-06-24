#!/bin/bash
set -e
PATCHED="$(pwd)/src/xschem"
SYSTEM="$(which xschem)"
TMPDIR=$(mktemp -d)

run_test() {
  local pdk=$1 rcfile=$2 schematic=$3
  echo "Testing $pdk: $(basename "$schematic")"

  $SYSTEM  --rcfile "$rcfile" --netlist_path "$TMPDIR/sys_$pdk"  \
           --pipe -q --no_x                                       \
           --script /tmp/netlist_one.tcl "$schematic" 2>/dev/null

  XSCHEM_SHAREDIR=/usr/local/share/xschem $PATCHED --rcfile "$rcfile" --netlist_path "$TMPDIR/pat_$pdk"  \
           --pipe -q --no_x                                       \
           --script /tmp/netlist_one.tcl "$schematic" 2>/dev/null

  mkdir -p "$TMPDIR/sys_$pdk" "$TMPDIR/pat_$pdk"

  for f in "$TMPDIR/sys_$pdk"/*.spice "$TMPDIR/sys_$pdk"/*.v \
           "$TMPDIR/sys_$pdk"/*.vhd; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    pat="$TMPDIR/pat_$pdk/$base"
    if [ ! -f "$pat" ]; then
      echo "  FAIL: $base not produced by patched binary"
      continue
    fi
    # Strip comment lines with paths/dates before diffing
    diff <(grep -v '^\*\|^-- \|^//\|sch_path\|sym_path' "$f") \
         <(grep -v '^\*\|^-- \|^//\|sch_path\|sym_path' "$pat") \
      && echo "  PASS: $base" || echo "  FAIL: $base differs"
  done
}

cat > /tmp/netlist_one.tcl << 'TCL'
xschem netlist
exit 0
TCL

run_test sky130 /home/nithin/eda/sky130/xschemrc /home/nithin/.ciel/ciel/sky130/versions/c95f23a75038d54d60ecc7ca060f53851f8f25e5/sky130A/libs.tech/xschem/xschem_verilog_import/counter.sch
run_test gf180  /home/nithin/eda/gf180/xschemrc  /home/nithin/.ciel/ciel/gf180mcu/versions/f3b5e46babb6b417f9a1a1b5c413f7dda6f68a51/gf180mcuD/libs.tech/xschem/tests/test_cap_mim_2f0fF.sch
run_test ihp    /home/nithin/eda/ihp/xschemrc    /home/nithin/.ciel/ciel/ihp-sg13g2/versions/ee974c3adc69d0f36adbf20577079f0df419d702/ihp-sg13g2/libs.tech/xschem/sg13g2_tests/tran_logic_not.sch

rm -rf "$TMPDIR"
