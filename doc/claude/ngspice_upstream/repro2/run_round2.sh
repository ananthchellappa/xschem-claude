#!/bin/sh
# Reproduce every finding in ../REPLY.md — the second round, measured 2026-08-14
# against the tree that answered the first round.
#
#   ./run_round2.sh [path-to-case-capable-ngspice] [path-to-baseline-ngspice]
#
# Defaults match the machine the findings were measured on. The baseline binary
# is used by R1, R2, R3 and R6 — three of the six reproduce on stock ngspice-46
# and are not casemode defects at all, which is most of their point.
#
# Round 1 lived in ../repro/ and its updated form came back in
# ../feedback/ngspice_upstream/repro/. Nothing here supersedes those; these are
# the shapes round 1 did not measure.
set -u
NG=${1:-/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice}
OLD=${2:-/usr/local/bin/ngspice}
cd "$(dirname "$0")" || exit 1

rm -f ./*.raw ./*.out ./*.err ./probe/*.raw 2>/dev/null
[ -x "$NG" ] || { echo "no case-capable ngspice at $NG"; exit 1; }
echo "case-capable: $NG"
"$NG" --version 2>&1 | sed -n '2p'
[ -x "$OLD" ] && { echo "baseline:     $OLD"; "$OLD" --version 2>&1 | sed -n '2p'; }

hdr() { echo; echo "======================================================"; echo "$*"; echo "======================================================"; }
vars() { strings "$1" 2>/dev/null | sed -n '/^Variables:/,/^Binary:/p' | grep -a '(' | tr -s ' \t' ' '; }
plotname() { grep -a '^Plotname:' "$1" 2>/dev/null; }

# ---------------------------------------------------------------------------
hdr "R1. the same failure exits 0 inside .control and 1 outside it"
echo "--- plain deck, no .control (the shape round 1 measured):"
rm -f plain_fail.raw
"$NG" -b -n -D casemode=distinguish -r plain_fail.raw plain_fail.cir >/dev/null 2>&1
echo "    rc=$?   $(plotname plain_fail.raw)"
echo "--- same .save, same mode, wrapped in .control run/write:"
rm -f ctl_fail.raw
"$NG" -b -n -D casemode=distinguish ctl_fail.cir >/dev/null 2>&1
echo "    rc=$?   $(plotname ctl_fail.raw)"
echo "--> rc is the defence the response asks a client to keep. A deck that"
echo "    drives the run from .control -- which is how a generated deck names"
echo "    its own rawfile -- does not have it."

# ---------------------------------------------------------------------------
hdr "R2. the constants artefact is reachable in every mode, on stock too"
for m in fold preserve distinguish; do
  rm -f absent.raw
  out=$("$NG" -b -n -D casemode=$m absent.cir 2>&1); rc=$?
  echo "    $NG -D casemode=$m   rc=$rc  $(plotname absent.raw)"
  echo "      mentions of the offending token 'nosuchnode': $(echo "$out" | grep -aic nosuchnode)"
done
if [ -x "$OLD" ]; then
  rm -f absent.raw
  "$OLD" -b -n absent.cir >/dev/null 2>&1
  echo "    stock ngspice-46, no flag at all      rc=$?  $(plotname absent.raw)"
fi
echo "--> .save of a node that is in no netlist. Not a case near-miss, so 0057"
echo "    is silent by design; rc=0 per R1; the raw parses and holds twelve"
echo "    built-in constants. Nothing on any channel says the run failed."

# ---------------------------------------------------------------------------
hdr "R3. a deck with exactly one saved vector gains a phantom v(all)"
rm -f one_save.raw two_save.raw
"$NG" -b -n -D casemode=preserve one_save.cir >/dev/null 2>&1
echo "    .save v(In)                    ->$(vars one_save.raw | tr '\n' '|')"
"$NG" -b -n -D casemode=preserve two_save.cir >/dev/null 2>&1
echo "    .save v(In) / .save v(MidNode) ->$(vars two_save.raw | tr '\n' '|')"
if [ -x "$OLD" ]; then
  rm -f one_save.raw
  "$OLD" -b -n one_save.cir >/dev/null 2>&1
  echo "    stock, .save v(In)             ->$(vars one_save.raw | tr '\n' '|')"
fi
echo "--> one saved vector in the deck, two in the rawfile. The second is named"
echo "    v(all) and reaches a consumer's signal list as if it were a net."

# ---------------------------------------------------------------------------
hdr "R4. 0058 latched the announcements; the 0057 warning still doubles"
rm -f ctl_fail.raw
"$NG" -b -n -D casemode=distinguish ctl_fail.cir >r4.out 2>r4.err
echo "    'differs only in case'  stdout=$(grep -ac 'differs only in case' r4.out) stderr=$(grep -ac 'differs only in case' r4.err)"
echo "    'experimental' banner   stdout=$(grep -ac experimental r4.out) stderr=$(grep -ac experimental r4.err)"
rm -f ctl_fail.raw
"$NG" -b -n -D casemode=bogus ctl_fail.cir >r4b.out 2>r4b.err
echo "    'unknown casemode'      stdout=$(grep -ac 'unknown casemode' r4b.out) stderr=$(grep -ac 'unknown casemode' r4b.err)"
echo "--> the two announcements 0058 latched now fire once. The near-miss"
echo "    warning, which shipped after it, fires twice per token."

# ---------------------------------------------------------------------------
hdr "R5. \$curcasemode is faithful to .spiceinit -- and to the DECK's directory"
probe() { printf 'echo CCM=$curcasemode\nquit\n' | "$@" -p 2>/dev/null | grep -ao 'CCM=[a-z]*' | tail -1; }
( cd probe && rm -f deck.raw
  echo "    cwd=probe/ (.spiceinit says fold), -D preserve, no -n:"
  echo "      probe says            $(probe "$NG" -D casemode=preserve)"
  "$NG" -b -D casemode=preserve deck.cir >/dev/null 2>&1
  echo "      the real run writes  $(vars deck.raw | head -1)"
  echo "    same, with -n:"
  echo "      probe says            $(probe "$NG" -n -D casemode=preserve)" )
echo "    cwd=repro2/ (no .spiceinit), deck still in probe/, no -n:"
rm -f probe/deck.raw deck.raw
echo "      probe says            $(probe "$NG" -D casemode=preserve)   <- WRONG"
"$NG" -b -D casemode=preserve probe/deck.cir >/dev/null 2>&1
echo "      the real run writes  $(vars deck.raw | head -1)"
echo "--> the probe tracks the real run only when its cwd is the deck's own"
echo "    directory, because that is where .spiceinit is searched. Note the"
echo "    rawfile landed in cwd, not beside the deck: 'write' is cwd-relative."
if [ -x "$OLD" ]; then
  echo "    baseline, which has no such variable:"
  printf 'echo CCM=$curcasemode\nquit\n' | "$OLD" -p -n >r5.out 2>r5.err
  echo "      rc=$? stdout=[$(grep -a '^CCM=' r5.out)] stderr=[$(grep -ai curcase r5.err)]"
fi

# ---------------------------------------------------------------------------
hdr "R6. 0067 -- set then unset of a simulator variable aborts, on stock too"
printf 'source probe/deck.cir\nset temp=27\nunset temp\nquit 0\n' | "$NG" -p -n >/dev/null 2>&1
echo "    case-capable build  rc=$?"
if [ -x "$OLD" ]; then
  printf 'source probe/deck.cir\nset temp=27\nunset temp\nquit 0\n' | "$OLD" -p -n >/dev/null 2>&1
  echo "    stock ngspice-46    rc=$?"
fi
echo "--> 134 is SIGABRT. Corroborating the newest item in the response, which"
echo "    it flags as the least-scrutinised."

rm -f ./*.out ./*.err
echo
echo "done."
