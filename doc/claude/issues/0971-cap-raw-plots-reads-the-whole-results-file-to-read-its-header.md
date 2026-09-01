# 0971 — the results-file reader used to load the whole file to read its headers

**FIXED 2026-08-30** in the same pass that filed it (the S4a repair pass), and
filed anyway because the behaviour it fixes is invisible to every behavioural
row in the tree.

## What it was

`ase::cap_raw_plots` answers "what plots are in this results file, and what
vectors does each one name". It did that by pulling the ENTIRE file into a
string first:

    set t [read $f]

For the capability probe's own scratch file — a few kilobytes of ASCII — that
is fine, and it is the only caller the proc had when it was written.

## Why it stopped being fine

Issue **0965**'s run report needs the Operating Point plot's variable list out of
**the user's own results file**, to compare what the deck asked for with what
came back. Measured on the shipped `sky130_tests_ase/tb_bandgap` bench, that
file is **69,595,016 bytes** with the device requests scoped to the operating
point, and was **144,455,860 bytes** before issue 0964 scoped them. This box has
about 7.8 GB.

And issue **0964** put the operating point **LAST** in the deck, so no read of
the first few kilobytes can find the plot the report needs. The reader has to
walk past the payload — which its own `Binary:` arithmetic already knew how to
do, having been written to skip exactly `points × variables × 8` bytes
(×16 when complex).

## The fix

`gets` the header lines and `seek` forward over each binary payload, instead of
slurping. The answers do not change.

## ⚠ Why this is filed at all

**Nothing a suite can observe went red for it, and nothing would have.** Every
existing row of `tests/headless/test_ase_simcaps_0948.tcl` stayed green under
the slurp and stays green under the stream. That is the recorded reason row
**H3**'s structural half — the comment-stripped body of `ase::cap_raw_plots`
must not contain a whole-file read — is not optional: it is the only thing that
can see a reader quietly loading 69 MB to read 40 lines.

H3's behavioural half is not a formality either: it builds a results file whose
Operating Point plot is the LAST one, behind a binary payload, so a reader that
stopped early or mis-stepped the payload would answer wrongly.
