#!/bin/sh
# Reproduce every finding in ../FINDINGS.md.
#
#   ./run_all.sh [path-to-case-capable-ngspice] [path-to-baseline-ngspice]
#
# Defaults match the machine the findings were measured on. The baseline
# binary is optional and used only by finding 6.
set -u
NG=${1:-/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice}
OLD=${2:-/usr/local/bin/ngspice}
cd "$(dirname "$0")" || exit 1

rm -f ./*.raw ./sl.out ./spiceinit/*.raw 2>/dev/null
[ -x "$NG" ] || { echo "no case-capable ngspice at $NG"; exit 1; }
echo "case-capable: $NG"
"$NG" --version 2>&1 | sed -n '2p'
echo

hdr() { echo; echo "======================================================"; echo "$*"; echo "======================================================"; }

hdr "1. raw header carries no casemode"
rm -f divider.raw
"$NG" -b -n -D casemode=preserve divider.cir >/dev/null 2>&1
sed -n '1,12p' divider.raw | cat -v
echo "--> 'Command:' is present, nothing says how names were cased."

hdr "2. .save does NOT fold under preserve, but print DOES"
echo "--- print v(midnode), net is MidNode, casemode=preserve:"
"$NG" -b -n -D casemode=preserve print_lower.cir 2>&1 | grep -E '^v\(|Error'
echo "--- .save v(midnode), same net, same mode:"
rm -f save_lower.raw
"$NG" -b -n -D casemode=preserve save_lower.cir >sl.out 2>&1; rc=$?
grep -E 'Error' sl.out | head -2
echo "rc=$rc  (print returned the right value; .save killed the run)"
echo "--- same asymmetry on a current, .save i(vs) where the source is Vs:"
rm -f save_current_lower.raw
"$NG" -b -n -D casemode=preserve save_current_lower.cir >/dev/null 2>&1
echo "rc=$?   (.save i(Vs) is rc=0 -- only the folded spelling fails)"

hdr "3. the failed .save still writes a well-formed raw -- of the constants plot"
ls -la save_lower.raw 2>/dev/null
head -c 260 save_lower.raw 2>/dev/null | cat -v

hdr "4. nothing in the output names the offending token"
echo "--- grep the FULL output of the failing deck for 'midnode':"
"$NG" -b -n -D casemode=preserve save_lower.cir 2>&1 | grep -in 'midnode' \
  || echo "    (no match -- the token is never named)"
echo "--- for contrast, the message distinguish mode already has:"
"$NG" -b -n -D casemode=distinguish print_lower.cir 2>&1 | grep -i 'differs only in case'

hdr "5. .spiceinit silently overrides -D casemode="
cd spiceinit || exit 1
echo "--- .spiceinit says fold, flag says preserve, NO -n:"
rm -f divider.raw; "$NG" -b -D casemode=preserve deck.cir >/dev/null 2>&1
sed -n '/^Variables:/,/^Binary/p' divider.raw
echo "--- same, WITH -n:"
rm -f divider.raw; "$NG" -b -n -D casemode=preserve deck.cir >/dev/null 2>&1
sed -n '/^Variables:/,/^Binary/p' divider.raw
cd .. || exit 1

hdr "6. a misspelled variable NAME is silent; a bad VALUE is caught"
echo "--- -D CaseMode=preserve (capital M):"
"$NG" -b -n -D CaseMode=preserve divider.cir 2>&1 | grep -i 'casemode' \
  || echo "    (no diagnostic at all)"
echo "--- -D casemode=bogus:"
"$NG" -b -n -D casemode=bogus divider.cir 2>&1 | grep -i 'casemode'
if [ -x "$OLD" ]; then
  echo "--- and a build without the feature silently ignores the flag:"
  "$OLD" --version 2>&1 | sed -n '2p'
  rm -f divider.raw; "$OLD" -b -n -D casemode=preserve divider.cir >/dev/null 2>&1
  sed -n '/^Variables:/,/^Binary/p' divider.raw
fi

hdr "7. warnings print twice"
echo "--- count of the 'unknown casemode' line:"
"$NG" -b -n -D casemode=bogus divider.cir 2>&1 | grep -ci 'unknown casemode'
echo "--- count of the distinguish experimental banner:"
"$NG" -b -n -D casemode=distinguish case_collision.cir 2>&1 | grep -ci 'experimental'

hdr "8. \$casemode reports the REQUEST, not the EFFECT"
echo "--- case-capable build, -D casemode=preserve:"
printf 'echo $casemode\nquit\n' | "$NG" -p -n -D casemode=preserve 2>/dev/null | sed -n '2p'
if [ -x "$OLD" ]; then
  echo "--- build WITHOUT the feature, same flag (it folds everything):"
  printf 'echo $casemode\nquit\n' | "$OLD" -p -n -D casemode=preserve 2>/dev/null | sed -n '2p'
  echo "    ^ says 'preserve' while folding. The variable is a record of what"
  echo "      was asked for; nothing reports what is in effect."
fi

hdr "9. two nets differing only in case collapse silently under preserve"
rm -f case_collision.raw
"$NG" -b -n -D casemode=preserve case_collision.cir 2>&1 | grep -iE 'warn|error' \
  || echo "    (no diagnostic)"
sed -n '/^Variables:/,/^Binary/p' case_collision.raw
echo "--> Out and OUT became one net; the survivor carries capitals, so it"
echo "    reads as deliberate. distinguish gives two nets."

echo
echo "done."
