#!/bin/sh
# Reproduce every finding in ../FINDINGS.md.
#
#   ./run_all.sh [path-to-case-capable-ngspice] [path-to-baseline-ngspice]
#
# Defaults match the machine the findings were measured on. The baseline
# binary is optional and used by findings 1, 2, 3, 4, 6 and 8.
#
# WHAT THIS SCRIPT SHOWS TODAY. The findings were measured on 2026-08-12 and
# three of them have since moved in this tree, so against $NG those sections
# now measure where they landed and against $OLD they still show the defect as
# reported. Each one carries a comment above its header saying what moved and
# which issue moved it:
#
#   2  FIXED  doc/codex/issues/0056  .save resolves case like print again
#   3  OPEN   doc/codex/issues/0059  a fix landed and was WITHDRAWN 2026-08-13:
#                                    every discriminator tried also refused a
#                                    nutmeg session's own 'let' vectors, which
#                                    live in the constants plot too
#   4  HALF   doc/codex/issues/0057  a .save token with a case variant among
#                                    the run's names now names both spellings;
#                                    an absent name with NO case variant is
#                                    silent again -- that half shipped, fired
#                                    on correct decks, and was withdrawn
#   7  FIXED  doc/codex/issues/0058  the announcements are latched to one run
#
# Findings 1, 3, 5, 6, 8 and 9 reproduce unchanged. Three parts were decided or
# withdrawn rather than fixed and say so where they are measured: the whole of
# finding 3 (0059 Resolution), within it the STALE plot written after a good
# analysis and a failed rerun, which was decided rather than attempted
# (doc/claude/decisions/0017 decision 1, the one decision there the withdrawal
# leaves standing), and finding 4's absent-name half (doc/codex/issues/0057
# Status). The decks and the commands are the ones the report used; only the
# flags that stopped reaching their case have moved.
set -u
NG=${1:-/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice}
OLD=${2:-/usr/local/bin/ngspice}
cd "$(dirname "$0")" || exit 1

rm -f ./*.raw ./sl.out ./spiceinit/*.raw ./count/*.raw 2>/dev/null
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
echo
echo "--- and a NEW header key is not skipped by readers -- it aborts the load:"
rm -f ascii_raw.raw
"$NG" -b -n ascii_raw.cir >/dev/null 2>&1
awk '/^Command:/{print; print "Casemode: preserve"; next} {print}' \
  ascii_raw.raw > hdr_newkey.raw
printf 'load hdr_newkey.raw\nquit\n' | "$NG" -p -n 2>&1 | grep -A2 -i 'strange line'
if [ -x "$OLD" ]; then
  echo "    same on the baseline build:"
  printf 'load hdr_newkey.raw\nquit\n' | "$OLD" -p -n 2>&1 | grep -i 'strange line'
fi
echo
echo "--- 'Option:' after 'Plotname:' IS parsed, by the UNMODIFIED baseline:"
awk '/^Plotname:/{print; print "Option: casemode=preserve"; next} {print}' \
  ascii_raw.raw > hdr_option.raw
if [ -x "$OLD" ]; then
  printf 'load hdr_option.raw\ndisplay\necho casemode-is $casemode\nquit\n' \
    | "$OLD" -p -n 2>&1 | grep -E 'strange|misplaced|voltage|^casemode-is' | head -4
  echo "--> loads clean AND the mode lands in the plot's environment."
else
  echo "    (skipped: no baseline binary at $OLD)"
fi

# FINDING 2 IS FIXED IN THIS TREE, and the section below now measures the fix
# rather than the defect. doc/codex/issues/0056 replaced .save's byte-exact
# name_eq() with vec_name_eq(), so under preserve a .save resolves a mis-cased
# name exactly as print does -- which is what FINDINGS.md finding 2 asked for.
# The section keeps the same decks and the same commands; what moved is their
# output. It is written as a comparison of the two modes because that is what
# is left of the asymmetry: under fold and preserve BOTH commands resolve
# case-insensitively, and under distinguish BOTH are exact, which is that
# mode's contract and not a defect. The baseline binary at $OLD still shows
# the reported behaviour on the prompt route at the end of the section.
hdr "2. .save folded where print folded -- FIXED; distinguish keeps exact match"
echo "--- net is MidNode; both decks spell it midnode.  casemode=preserve:"
printf '    print v(midnode) -> %s\n' \
  "$("$NG" -b -n -D casemode=preserve print_lower.cir 2>&1 | grep -E '^v\(' | head -1)"
rm -f save_lower.raw
"$NG" -b -n -D casemode=preserve save_lower.cir >sl.out 2>&1; rc=$?
printf '    .save v(midnode) -> rc=%s  raw: %s\n' "$rc" \
  "$(ls -la save_lower.raw 2>/dev/null | awk '{print $5" bytes"}' | grep . || echo none)"
sed -n '/^Variables:/,/^Binary/p' save_lower.raw 2>/dev/null
echo "--> both resolve, and the raw carries the netlist's own spelling."
echo "    Read the FIRST column: v(MidNode) is the answer this section is about."
echo "    The second, v(all), is not a net and is not this finding.  The .save"
echo "    leaves this plot holding exactly one vector, and a wildcard that"
echo "    matches exactly one vector is renamed to the wildcard's own text"
echo "    (ft_evaluate(), src/frontend/evaluate.c); the bare 'write' then finds"
echo "    its scale missing under that name and adds it back, so one vector is"
echo "    written twice with the same value.  Pre-existing and mode independent"
echo "    -- byte for byte on the baseline binary too -- and filed as"
echo "    doc/codex/issues/0064.  Nothing else in this script depends on it."
echo "--- the same two under casemode=distinguish, where exact IS the contract:"
printf '    print v(midnode) -> %s\n' \
  "$("$NG" -b -n -D casemode=distinguish print_lower.cir 2>&1 \
     | grep -E '^v\(|differs only in case' | head -1)"
rm -f save_lower.raw
"$NG" -b -n -D casemode=distinguish save_lower.cir >sl.out 2>&1; rc=$?
printf '    .save v(midnode) -> rc=%s  raw: %s\n' "$rc" \
  "$(ls save_lower.raw 2>/dev/null || echo none)"
grep -E 'Error' sl.out | head -2
echo "--> both miss, both by design, and neither is the other's exception."
echo "--- and on a branch current, the source is Vs, casemode=preserve:"
rm -f save_current_lower.raw
"$NG" -b -n -D casemode=preserve save_current_lower.cir >/dev/null 2>&1
echo ".save i(vs)  rc=$?"
sed 's/\.save i(vs)/.save i(Vs)/' save_current_lower.cir > save_current_upper.cir
"$NG" -b -n -D casemode=preserve save_current_upper.cir >/dev/null 2>&1
echo ".save i(Vs)  rc=$?   (both spellings now, where only i(Vs) used to work)"
rm -f save_current_upper.cir save_current_upper.raw
echo "--- the prompt route, which the report measured under fold: the same save"
echo "    typed at -p against plain.cir, which carries no .save of its own:"
for tok in 'v(MIDNODE)' 'v(MidNode)' 'v(midnode)'; do
  printf '    save %-12s -> %s\n' "$tok" \
    "$(printf 'source plain.cir\nsave %s\nop\ndisplay\nquit\n' "$tok" \
       | "$NG" -p -n -D casemode=fold 2>&1 | grep -E '^Name:' | tail -1)"
done
echo "--> all three reach the op plot now.  The baseline build, where only the"
echo "    folded spelling did, is the finding as reported:"
if [ -x "$OLD" ]; then
  printf '    baseline, save v(MIDNODE) -> %s\n' \
    "$(printf 'source plain.cir\nsave v(MIDNODE)\nop\ndisplay\nquit\n' \
       | "$OLD" -p -n 2>&1 | grep -E '^Name:' | tail -1)"
else
  echo "    (skipped: no baseline binary at $OLD)"
fi

# FINDING 3 IS NOT FIXED. It was fixed in this tree and the fix was WITHDRAWN
# on 2026-08-13; doc/codex/issues/0059 is Open and its Resolution section is
# the account. Three generations of guard refused a bare write of a plot
# nothing had chosen, and all three also refused a plain nutmeg session that
# builds vectors with 'let' and writes them -- because those vectors live in
# the constants plot, which is exactly the plot the guard read as evidence
# that nothing had been chosen. A guard that writes no file for correct work
# is worse than the defect, which at least labels its file "Plotname:
# constants". So this section measures the defect as reported, on BOTH
# binaries, plus the shape that ended the attempt.
#
# Two things about the decks below have not changed and still need saying:
#   - The six decks that spell a net "midnode" where the netlist says "MidNode"
#     only miss under -D casemode=distinguish; since 0056 a .save resolves that
#     spelling under preserve, so preserve takes the healthy path and shows
#     nothing. Those are save_lower, seq, rc0, status_probe, write_named and
#     write_named_capture, and each carries the flag below.
#   - Row 2 of 0059 -- the STALE plot written after a good op and a failed
#     rerun -- was decided rather than fixed and still behaves as reported;
#     doc/claude/decisions/0017 decision 1 is the record, and it is the one
#     decision in that file the withdrawal leaves standing.
hdr "3. the failed .save wrote a well-formed raw -- of the constants plot (OPEN)"
rm -f save_lower.raw
"$NG" -b -n -D casemode=distinguish save_lower.cir >sl.out 2>&1
echo "    file written: $(ls -la save_lower.raw 2>/dev/null || echo none)"
sed -n '1,6p' save_lower.raw 2>/dev/null
echo "--> the 570-byte 'Plotname: constants' raw the report quotes is still"
echo "    written.  The baseline binary writes the same thing:"
echo "--- mode independent: .save v(nosuchnode), baseline binary, no -D:"
if [ -x "$OLD" ]; then
  rm -f nocase.raw; "$OLD" -b -n nocase.cir >/dev/null 2>&1
  echo "    rc=$?"; ls -la nocase.raw 2>/dev/null; head -4 nocase.raw 2>/dev/null
else
  echo "    (skipped: no baseline binary at $OLD)"
fi
echo "--- but ONE resolvable name keeps the run alive (.save v(nosuchnode) v(In)):"
rm -f save_partial_miss.raw; "$NG" -b -n save_partial_miss.cir >/dev/null 2>&1
echo "    rc=$?"; sed -n '1,4p' save_partial_miss.raw 2>/dev/null
echo "--- with a good op earlier, the STALE plot is written and both tells vanish:"
rm -f seq.raw; "$NG" -b -n -D casemode=distinguish seq.cir >/dev/null 2>&1
sed -n '1,11p' seq.raw 2>/dev/null
echo "--- rc was no defence either -- a later good analysis exits 0 over the"
echo "    bogus raw:"
rm -f rc0.raw; "$NG" -b -n -D casemode=distinguish rc0.cir >/dev/null 2>&1
echo "    rc=$?  file written: $(ls rc0.raw 2>/dev/null || echo none)"
sed -n '1,4p' rc0.raw 2>/dev/null
echo "--- and 'destroy' reaches the same file with no failed analysis at all,"
echo "    which is where a fix has to look at more than the plot's identity:"
rm -f destroy_curplot.raw; "$NG" -b -n destroy_curplot.cir 2>/dev/null | grep -E 'curplot-'
echo "    file written: $(ls destroy_curplot.raw 2>/dev/null || echo none)"
sed -n '1,4p' destroy_curplot.raw 2>/dev/null
echo "--- one shape 0059 did not name at first, and which any fix must also"
echo "    cover: a plot the deck DID choose, with nothing in it"
echo "    (op, setplot new, bare write) -- the file is the constants plot again:"
rm -f spn.raw
printf '* setplot new\nVs In 0 DC 3\nRl In MidNode 1k\nRg MidNode 0 3k\n.control\nop\nsetplot new\nwrite spn.raw\n.endc\n.end\n' \
  | "$NG" -b -n >/dev/null 2>&1
echo "    file written: $(ls -la spn.raw 2>/dev/null || echo none)"
sed -n '1,4p' spn.raw 2>/dev/null
echo "--- AND THE SHAPE THAT ENDED THREE ROUNDS OF FIXING: the same constants"
echo "    plot, holding a nutmeg session's OWN vectors.  This must keep being"
echo "    written, and every guard tried so far refused it:"
rm -f letonly.raw
printf 'set filetype=ascii\nlet x = vector(5)\nlet y = x*2\nwrite letonly.raw\nquit\n' \
  | "$NG" -p -n >/dev/null 2>&1
echo "    file written: $(ls -la letonly.raw 2>/dev/null || echo none)"
sed -n '6,7p;21,22p' letonly.raw 2>/dev/null
echo "--- the NAMED write already refuses, on two different streams:"
rm -f write_named.raw
"$NG" -b -n -D casemode=distinguish write_named.cir >/dev/null 2>wn.err
echo "    rc=$?  file written: $(ls write_named.raw 2>/dev/null || echo none)"
grep -E "checkvalid|during 'write'" wn.err
echo "    ...and a deck's '>&' captures only the cp_err half:"
"$NG" -b -n -D casemode=distinguish write_named_capture.cir 2>/dev/null | grep -E '^captured:'
rm -f wn.err write_named_capture.txt
echo "--- what a DECK can see, and a raw-file consumer cannot:"
"$NG" -b -n -D casemode=distinguish status_probe.cir 2>/dev/null | grep -E 'status-is'

# FINDING 4 IS HALF FIXED IN THIS TREE, by doc/codex/issues/0057, and the half
# that is not fixed was tried and withdrawn rather than left undone. What lands
# is the CASE NEAR MISS: a .save token that misses AND has a case variant among
# the run's own names is now reported, naming both spellings. A .save token
# that is simply absent -- no case variant anywhere -- is silent again, exactly
# as in stock ngspice-46; the wider report shipped in three earlier rounds and
# fired on correct decks (0057's Status lists six), so it was replaced by the
# two-condition rule decision 2 of doc/claude/decisions/0001-distinguish.md
# already carried. Read 0057's Status and Resolution 1 before re-measuring this
# section: the zeros below are the withdrawal, not a regression.
# One flag moved with the fix: the decks that spell 'midnode' only fail under
# distinguish since 0056, so that is the mode they are run in here.
hdr "4. the offending token is named when it is a CASE near miss -- HALF FIXED"
echo "--- grep the FULL output of the failing deck for 'midnode', run under"
echo "    casemode=distinguish (under preserve it resolves and does not fail):"
"$NG" -b -n -D casemode=distinguish save_lower.cir 2>&1 | grep -in 'midnode' \
  || echo "    (no match -- the token is never named)"
echo "--> the near miss IS named, and names both spellings.  This is finding 4's"
echo "    own deck and its own ask, met."
echo "--- a name no card defines at all, .save v(nosuchnode), all three modes."
echo "    This is the half that was withdrawn, so expect zeros:"
for m in fold preserve distinguish; do
  "$NG" -b -n -D casemode=$m save_absent.cir >sa.out 2>sa.err; rc=$?
  echo "    $m rc=$rc  hits for 'nosuchnode' on both streams: $(cat sa.out sa.err | grep -ic nosuchnode)"
done
if [ -x "$OLD" ]; then
  "$OLD" -b -n save_absent.cir >sa.out 2>sa.err; rc=$?
  echo "    baseline (no casemode support) rc=$rc  hits: $(cat sa.out sa.err | grep -ic nosuchnode)"
fi
rm -f sa.out sa.err
echo "    what the run does say, verbatim (it names the analysis, not the token):"
"$NG" -b -n -D casemode=fold save_absent.cir 2>&1 \
  | grep -E 'no data saved|aborted' | sed 's/^/      /'
echo "--> NOT named, on this build or the baseline, in any mode: an absent name"
echo "    with no case variant is not a case defect and no longer reports."
echo "    rc=1 either way, so the run still fails loudly; what is missing is"
echo "    the token.  doc/codex/issues/0057 Status, paragraph 2."
echo "--- the PARTIAL miss, .save v(In) v(midnode): rc=0 in both modes, and the"
echo "    difference is that preserve now SAVES the net rather than dropping it:"
rm -f save_partial_lower.raw
"$NG" -b -n -D casemode=preserve save_partial_lower.cir >sp.out 2>sp.err
echo "    preserve    rc=$?  stderr bytes: $(wc -c < sp.err)"
grep -i 'midnode' sp.out | sed 's/^/      /' \
  || echo "      (the requested name is nowhere in either stream)"
rm -f save_partial_lower.raw
"$NG" -b -n -D casemode=distinguish save_partial_lower.cir >sp.out 2>sp.err
echo "    distinguish rc=$?  stderr bytes: $(wc -c < sp.err)"
grep -i 'midnode' sp.err | sed 's/^/      /' \
  || echo "      (the requested name is nowhere in either stream)"
rm -f sp.out sp.err
echo "--- the control-language 'save' is the same path, and follows it:"
for m in preserve distinguish; do
  rm -f save_cmd_lower.raw
  "$NG" -b -n -D casemode=$m save_cmd_lower.cir >scl.out 2>scl.err; rc=$?
  "$NG" -b -n -D casemode=$m save_lower.cir >/dev/null 2>sl.err
  echo "    $m rc=$rc  stderr identical to the .save deck's: $(cmp -s scl.err sl.err && echo yes || echo no)  midnode hits: $(cat scl.out scl.err | grep -ic midnode)"
done
rm -f scl.out scl.err sl.err save_lower.raw save_cmd_lower.raw
echo "--- what a DECK reads back, via op >& + fopen/fread, under distinguish:"
"$NG" -b -n -D casemode=distinguish save_guard_probe.cir 2>/dev/null \
  | grep -E 'GUARD-|SHELL-CAT-ABOVE'
echo "    the capture itself:"
sed 's/^/      /' sgp_cap.txt 2>/dev/null
echo "--> the run-level error IS in the capture, and is no longer its FIRST"
echo "    line: 0057's warning precedes it and this probe reads one line, so it"
echo "    prints GUARD-NOT-CAPTURED. A guard deck has to scan the capture."
echo "    'shell cat' of the same file still prints nothing before"
echo "    SHELL-CAT-ABOVE -- it is not flushed yet."
rm -f sgp_cap.txt
echo "--- .print and .save side by side, same net, same spelling.  A hit is a"
echo "    stderr LINE mentioning the requested name, so the counts measure"
echo "    whether the token is named, not how alike the wording is:"
for d in asym_save_mid asym_save_nosuch asym_print_mid asym_print_nosuch; do
  for m in fold preserve distinguish; do
    "$NG" -b -n -D casemode=$m $d.cir >as.out 2>as.err; rc=$?
    hits=$(cat as.err | grep -icE 'midnode|nosuchnode')
    echo "    $d $m rc=$rc stderr-hits=$hits"
  done
done
rm -f as.out as.err
echo "--> the two are NOT alike, and the difference has two halves:"
echo "    * the case near miss (_mid, casemode=distinguish): both name the"
echo "      token.  Different counts, same fact -- .save prints 0057's warning"
echo "      once, .print prints it once per resolution attempt plus its own"
echo "      'not available or has zero length', so 1 against 3.  In fold and"
echo "      preserve both are 0 because both resolve; nothing to report."
echo "    * the absent name (_nosuch): .print names it in every mode, .save in"
echo "      none.  That is the withdrawn half above, not an oversight of this"
echo "      section: .print's tokens reach the same save list carrying an"
echo "      analysis, and it is the 'saves[i].analysis' gate on \"can't parse\""
echo "      -- untouched by 0057, present in stock -- that prints them."
echo "    rc is 1 on both sides wherever the name does not resolve, in every"
echo "    mode, so no run in this table succeeds silently."

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
  echo "--- but an INVALID value does separate the builds (count of the warning):"
  echo "    baseline : $("$OLD" -b -n -D casemode=bogus divider.cir 2>&1 | grep -ci 'unknown casemode')"
  echo "    this one : $("$NG"  -b -n -D casemode=bogus divider.cir 2>&1 | grep -ci 'unknown casemode')"
fi
echo "--- what no probe reaches is 'preserve': control-language names never fold:"
for m in fold preserve distinguish; do
  printf '    %-12s -> %s\n' "$m" \
    "$(printf 'let MixedCase = 1\ndisplay\nquit\n' | "$NG" -p -n -D casemode=$m 2>/dev/null \
       | grep -i 'mixedcase *:' | awk '{print $1}')"
done
echo "--> so detecting 'preserve' needs a deck. It needs no raw file, though:"
printf '* preserve probe\nVs In 0 DC 3\nRl In MidNode 1k\nRg MidNode 0 3k\n.control\nop\ndisplay\n.endc\n.end\n' \
  | "$NG" -b -n -D casemode=preserve 2>/dev/null | grep -i 'midnode'
printf '* preserve probe\nVs In 0 DC 3\nRl In MidNode 1k\nRg MidNode 0 3k\n.control\nop\ndisplay\n.endc\n.end\n' \
  | "$NG" -b -n -D casemode=fold 2>/dev/null | grep -i 'midnode'

# FINDING 7 IS FIXED IN THIS TREE, by doc/codex/issues/0058 and
# doc/claude/decisions/0016: the announcement is latched, so each warning is
# printed once per run and no longer once per inp_readall() call. Every count
# below reads 1 where the report measured 1, 2 or 3 depending on how many files
# the run happened to read. The baseline binary is the unfixed comparison.
hdr "7. warnings printed once per file read, not once per run -- FIXED"
echo "--- count of the 'unknown casemode' line:"
"$NG" -b -n -D casemode=bogus divider.cir 2>&1 | grep -ci 'unknown casemode'
echo "--- count of the distinguish experimental banner:"
"$NG" -b -n -D casemode=distinguish case_collision.cir 2>&1 | grep -ci 'experimental'
echo "--- the count used to track inp_readall() calls; it no longer moves with"
echo "    how many files the run reads:"
echo "    no spinit, -n              : $(SPICE_SCRIPTS=. "$NG" -b -n -D casemode=bogus divider.cir 2>&1 | grep -ci 'unknown casemode')"
echo "    spinit, -n                 : $("$NG" -b -n -D casemode=bogus divider.cir 2>&1 | grep -ci 'unknown casemode')"
echo "    spinit + .spiceinit, no -n : $("$NG" -b -D casemode=bogus count/deck.cir 2>&1 | grep -ci 'unknown casemode')"
echo "--- a 'source' is a second read and still announces only once:"
echo "    relatch_source.cir, distinguish : $("$NG" -b -n -D casemode=distinguish relatch_source.cir 2>&1 | grep -ci 'experimental')"

hdr "8. \$casemode reports the REQUEST, not the EFFECT"
echo "--- case-capable build, -D casemode=preserve:"
printf 'echo $casemode\nquit\n' | "$NG" -p -n -D casemode=preserve 2>/dev/null | sed -n '2p'
if [ -x "$OLD" ]; then
  echo "--- build WITHOUT the feature, same flag (it folds everything):"
  printf 'echo $casemode\nquit\n' | "$OLD" -p -n -D casemode=preserve 2>/dev/null | sed -n '2p'
  echo "    ^ says 'preserve' while folding. The variable is a record of what"
  echo "      was asked for; nothing reports what is in effect."
fi
echo "--- it diverges on THIS build too: 'set' after the deck was read:"
"$NG" -b -n late_set.cir 2>/dev/null | grep -iE 'midnode|casemode-is'
echo "--> folded names, and \$casemode says preserve."
echo "--- finding 5 is NOT a second instance -- there the variable tracks the effect:"
rm -f spiceinit/divider.raw
(cd spiceinit && "$NG" -b -D casemode=preserve deck.cir >/dev/null 2>&1)
printf '    raw says   : %s\n' "$(sed -n '/^Variables:/,/^Binary/p' spiceinit/divider.raw | sed -n '2p' | tr -s ' \t' ' ')"
printf '    $casemode  : %s\n' "$(cd spiceinit && printf 'echo $casemode\nquit\n' | "$NG" -p -D casemode=preserve 2>/dev/null | sed -n '2p')"
echo "--- report_probe.cir: same deck, same flag, both binaries (doc/codex/issues/0060):"
for b in "$NG" "$OLD"; do
  [ -x "$b" ] || continue
  printf '    %-28s -> %s\n' "$(basename "$(dirname "$b")")/$(basename "$b")" \
    "$("$b" -b -n -D casemode=preserve report_probe.cir 2>/dev/null \
       | grep -iE '^ +midnode |^casemode-is' | tr -s ' \n' ' ')"
done
echo "--- three_way_probe.cir: guide section 2's probe DOES separate all three modes:"
for m in fold preserve distinguish; do
  printf '    %-12s -> %s\n' "$m" \
    "$("$NG" -b -n -D casemode=$m three_way_probe.cir 2>/dev/null \
       | grep -i '^caseprobe = \|^CaseProbe = ' | tr -s ' \n' ' ')"
done
if [ -x "$OLD" ]; then
  printf '    %-12s -> %s\n' "baseline/pres" \
    "$("$OLD" -b -n -D casemode=preserve three_way_probe.cir 2>/dev/null \
       | grep -i '^caseprobe = \|^CaseProbe = ' | tr -s ' \n' ' ')"
fi
echo "--- relatch_source.cir: a 'source' is a second inp_readall(), an .include is not:"
"$NG" -b -n -D casemode=preserve relatch_source.cir 2>/dev/null \
  | grep -iE '^ +(midnode|bb) '
printf '    unknown-casemode count, divider.cir       : %s\n' \
  "$("$NG" -b -n -D casemode=bogus divider.cir 2>&1 | grep -ci 'unknown casemode')"
printf '    unknown-casemode count, include_count.cir : %s\n' \
  "$("$NG" -b -n -D casemode=bogus include_count.cir 2>&1 | grep -ci 'unknown casemode')"

hdr "9. two nets differing only in case collapse silently under preserve"
rm -f case_collision.raw
"$NG" -b -n -D casemode=preserve case_collision.cir 2>&1 | grep -iE 'warn|error' \
  || echo "    (no diagnostic)"
sed -n '/^Variables:/,/^Binary/p' case_collision.raw
echo "--> Out and OUT became one net; the survivor carries capitals, so it"
echo "    reads as deliberate. distinguish gives two nets."

echo
echo "done."
