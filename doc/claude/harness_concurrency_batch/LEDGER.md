# Ledger — harness concurrency batch

Receipts collected by the driver. One row per dispatched task. A row is added only
when the receipt is in `receipts/` and the driver has read it.

| id | task | crew status | commit | result | issues |
|---|---|---|---|---|---|
| — | scaffolding | driver | `78d06f1e` | baseline recorded; R1 filed as a ruling debt against 0990 | — |
| **A1** | the RED suite | **DONE** | `5114dd8b` | 20 checks, **13 RED / 7 green**, identical across 4 runs | 1476 |
| **B1** | faces 1–3 | **DONE** | `5f7164d4` | **13 RED → 2 RED**, `2 FAILED (18 passed)`, **10 of 10** runs | 0867, 0990, 0384(part) |
| **C1** | face 4, the verdict | **DONE** | `43b40f04` | **2 RED → 0**, `ALL PASS (20 checks)` rc 0, **18 of 18** runs | 0955, 0905, 0384(rest) |
| **V1** | solo T1 verification | **DONE — GREEN** | `d4946b61` | **84 cases**, **374.6 s**, **ZERO counted failures**, **rc 0** | — |
| **D1** | the written record | **DONE** | `1a46c800` | 1476 minted (249 lines); 5 issues closed; NUMBERING + **five** CLAUDE.md corrections | 1476, 0384, 0867, 0955, 0905, 0990 |
| **D2** | the lying detail strings | **DONE** | — | **12 of 20 rows lied on the green path**; 16 rewritten; `ALL PASS (20 checks)` rc 0, **4 of 4** runs, byte-identical fingerprint `c1abe627a272` | — |

## D2's audit — V1's "at least seven" was a lower bound; the answer is 12

All 20 rows audited. **12 lied on the green path** — V1 named 7 (S2×3, R1a, D2a, V1a,
V2a) and **missed S1×3, C1b, D1a**. Two more (C1a, V2b) would have lied on the *red*
path. Two were honest but reported no observation at all (D2b, V1b — a green `V1b` was
indistinguishable from a vacuous one). Four were honest and left alone (S3a, R1b, D0a,
V0a). **16 rewritten.**

**The mechanism in `D2a` is the transferable lesson.** It already *had* a ternary,
keyed on `MINI-STARTUP-DIED` — so its else branch covered **two** states, "died without
that marker" and "green", and printed the red sentence for both. **A two-way ternary
over a three-state world is how a green path acquires a lie.**

`V2a` was worse than C1 recorded: besides "announced nothing" it ended "A whole run
reported success", when on green run B **refused with rc 2 and said so**.

A human now reads, for `S2`: `guarded-by-catch=0 per-run-target=1, and EITHER one
suffices` — which shows *which* of the two accepted fixes B1 actually shipped,
something the old string could not express, because it asserted both were absent.

## The `src_line` trap — ruled out three ways, including an adversarial control

1. **Mechanism** — every row's haystack enumerated from source (the three case files,
   `test_utility.tcl` child-probe stdout, scratch output files, `run_regression.tcl`).
   This file appears in none; `:112` is the `slurp` *definition*, not a call.
2. **Provenance** — three of the five newly-reported source values
   (`$testname/results.[pid]`, `set lock_file`, `REFUSING TO RUN`) are absent from this
   file entirely.
3. **Adversarial control** — an inert braced string planted at **line 109**, ahead of
   every candidate (since `src_line` takes the first match), carrying a fixed workroot,
   an unguarded wipe, `results.POISON.log` and a `lockfile_poison` line. Poisoned run:
   **still ALL PASS, and a diff of all 20 detail lines against the clean run is
   EMPTY** — no outcome and no reported value moved. Restored with verified md5.

Also checked: all three output classifiers are **column-0 anchored**, so a detail
string (always preceded by `ok:   <name> `) cannot forge a verdict; and
`test_ase_simchoice_1395`'s lint — the one external reader of this file's text — keys
on `ase::sim_register`-family tokens, of which zero are present.

## ⚠ Three findings D2 reported rather than fixed

1. **`V1a` is neither weakened nor strengthened** — predicate byte-identical, still a
   whole-file regexp a comment can satisfy. It now *prints the matched line*
   (`set lock_file "$log_fn.lock"` — real code), so a reader can see whether the
   evidence is code or prose.
2. **`D1a`'s needle `: exit -1` is a substring**, so it also counts B1's `-1001` /
   `-1002`. The logic is correct; the *name* is now narrow. Renaming was forbidden.
3. **A pre-existing comment at `:59` quotes a workroot value verbatim** — exactly B1's
   trap shape. Harmless today, loaded for anyone who later adds a self-reading row.
   Left in place because it carries the measured phantom counts.

Also: `S3a` still reports no observed value (adding one means new logic), and **three
header comments that asserted the opposite of the tree's state** were corrected —
"NOT REGISTERED IN ANY RUNNER YET", "13 are RED on today's tree", and a stale
`:295`/`:381` citation.

## ⚠ The crude-grep error, now four for four

D2 retracted its own prediction: it expected in-file `set log_fn "results.log"` to drop
2→1. Measured **unescaped 1→1, escaped 1→0** — `grep -F` cannot see the escaped
spelling. Both numbers are right and answer different questions, the same shape as
V1's 75-vs-69 and the driver's 16-vs-20. **That is a crude grep answering the wrong
question for the fourth time in one batch.** The batch's standing rule is now: take a
count from the artefact's own output, never from a grep.

## ⚠ DRIVER DECISION — the residuals get filed (D3), unchanged

1. **0905 shape (3) not implemented** — the `REGRESSION START/END` sentinel. A run
   **killed mid-write** can still leave a short `results.log` that reads green. The
   *collision* route is closed; the *interrupted-state* route is not.
2. **`headless/*.disp.log` names still not pid-qualified** — a standalone suite on
   `:99` is enrolled in no lock and **can still race a live T1**.
3. **0384 fix candidate 2 landed only in part** — no `exit 126` / `127` / `signal 15`
   → `INFRA:` distinction, so "the binary never ran" still reports as an ordinary
   counted failure.

## Resume point

Next: **V2** (final solo T1 — certifies the main task as committed, since D2 edited a
suite that runs *inside* T1), then **D3** (file the three residuals), then companions
E1 (0805+0802), E2 (0408a), E3 (1332-residual).
