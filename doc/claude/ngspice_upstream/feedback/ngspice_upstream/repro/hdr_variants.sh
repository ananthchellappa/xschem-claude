#!/bin/sh
# Build the spliced raw headers doc/codex/issues/0061 quotes, from ascii_raw.cir.
#
#   ./hdr_variants.sh [path-to-ngspice]
#
# run_all.sh finding 1 already makes ascii_raw.raw and hdr_option.raw; this
# script remakes those two and adds the four one-line variants 0061 uses.
# The *.raw products are gitignored (they carry a Date: stamp and a build
# stamp), so they are regenerated rather than committed -- every byte of them
# comes from ascii_raw.cir plus the one spliced line named below.
set -u
NG=${1:-/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice}
cd "$(dirname "$0")" || exit 1
[ -x "$NG" ] || { echo "no ngspice at $NG"; exit 1; }

rm -f ascii_raw.raw
"$NG" -b -n ascii_raw.cir >/dev/null 2>&1

# Each variant is ascii_raw.raw with exactly one line spliced in after
# "Plotname:", which is where run_all.sh finding 1 puts "Option: casemode=preserve".
splice() {                      # splice <outfile> <line>
    awk -v ins="$2" '/^Plotname:/{print; print ins; next} {print}' \
        ascii_raw.raw > "$1"
}

splice hdr_option.raw "Option: casemode=preserve"
splice hdr_ngb.raw    "Option: ngbehavior = hs"
splice hdr_numdgt.raw "Option: numdgt = 12"
splice hdr_cmd.raw    "Command: echo COMMAND-LINE-EXECUTED"
splice hdr_cmdset.raw "Command: set casemode=preserve"

# and the name-spelling matrix of 0061's Impact table
splice hdr_optname_mixed.raw "Option: CaseMode=preserve"
splice hdr_optname_upper.raw "Option: CASEMODE=preserve"
splice hdr_optval_upper.raw  "Option: casemode=PRESERVE"
splice hdr_optval_mixed.raw  "Option: casemode=Preserve"

# and the misplaced case: the same line placed BEFORE Plotname:
awk '/^Plotname:/{print "Option: casemode=preserve"} {print}' \
    ascii_raw.raw > hdr_option_early.raw

ls -1 hdr_*.raw
