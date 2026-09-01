# 0689 — `run_regression.tcl`'s completion sentinel is `^OVERALL: ok$`, so any suite that prints a check count is reported as a HARNESS FAIL while green

STATUS: **FIXED 2026-08-25** by the 0689+0690+0698 crew. Filed four times before it
was fixed (0420, 0492, 0629, this one). T1 re-baselined in the same commit:
**3 counted FAIL lines → 0**.
FOUND IN: `tests/run_regression.tcl:117`. FIXED IN: `tests/banner_rule.tcl` (new,
the rule) + `tests/run_regression.tcl` (now a consumer) + `tests/headless/test_audit_classifier.tcl`
section K (19 rows).

---

## 1. The defect

```tcl
set sentinel 0
if {![catch {open ${hc}.log r} rf]} { set body [read $rf]; close $rf; set sentinel [regexp -line {^OVERALL: ok$} $body] }
if {$childcode != 0 || !$sentinel} {
  puts $af "HARNESS: ${hc} did not complete cleanly (exit=$childcode, OVERALL_ok=$sentinel) -- crashed, aborted mid-script, or a check failed: FAIL"
}
```

The regexp is anchored at both ends, so it cannot match a suite whose sentinel line
carries a count. `headless/test_pdk_launcher` prints

```
OVERALL: ok (30 checks)
```

with **zero** failed checks, and T1 duly reports

```
HARNESS: headless/test_pdk_launcher did not complete cleanly (exit=0, OVERALL_ok=0) -- crashed, aborted mid-script, or a check failed: FAIL
```

That is **one of the three FAIL lines in this branch's T1 baseline of record.** The
suite is green; the sentinel format is not.

## 2. Why it is worth a number rather than a shrug

A false red in the top-level tier is a tax on every crew that runs T1: each one has
to re-derive that this line is benign, and the day a *real* failure appears in that
suite it is indistinguishable from the standing noise. The failure mode also grows —
any suite that ever adds a count to its sentinel joins the list silently.

## 3. The fix, not applied here

Relax the anchor to `{^OVERALL: ok( |$)}` (or `{^OVERALL: ok\M}`). Not applied in this
run because T1's FAIL count is the baseline of record for a concurrently-running
batch, and changing it mid-run would make every crew's before/after diff meaningless.
Whoever fixes it should re-baseline T1 in the same commit and say so.

## 4. Still open

The fix, and a sweep of the other headless suites for the same sentinel drift.

---

# THE FIX (2026-08-25)

## 4. What the fix actually is — and section 3 above is WRONG as written

Section 3 recommends "relax the anchor to `{^OVERALL: ok( |$)}` (or
`{^OVERALL: ok\M}`)". **That sentence is refuted by measurement**, and this is the
one sentence of this issue the implementing crew did not take.

Measured on the real binary with three throwaway suites that die mid-script
(`xschem --nogui --pipe` **exits 0** on an uncaught mid-script Tcl error):

```
die_after_bare     exit=0  sentinel_cur=1 -> SCORED PASS | sentinel_new=1 -> SCORED PASS | death_line=1 | summarize_all_counts=0
die_after_counted  exit=0  sentinel_cur=0 -> HARNESS FAIL | sentinel_new=1 -> SCORED PASS | death_line=1 | summarize_all_counts=0
die_no_banner      exit=0  sentinel_cur=0 -> HARNESS FAIL | sentinel_new=0 -> HARNESS FAIL | death_line=1 | summarize_all_counts=0
```

Row 2 is the point: today a suite that prints a **counted** banner and then dies is
caught **only by accident** — the count breaks the anchor, not the death. Relax the
anchor alone and that accident is lost. The relaxation on its own is therefore a
**measured regression** on that shape: quieter, not better, and it would have gone
unnoticed for exactly the reason this defect survived four filings. (Row 1 shows the
hollow-pass hole was already open for all **131** bare-banner sites; `summarize_all`
never sees the death line either, because it neither ends in `FAIL` nor starts with
`FATAL`.)

So the relaxation shipped **paired with an independent death predicate**, which is
also what the driver brief asked for in words ("distinguish the suite finished and
reported from the suite died").

`tests/banner_rule.tcl`, three named procs, sourced by `run_regression.tcl`:

```tcl
proc banner_complete {body} { regexp -line {^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$} $body }
proc banner_died     {body} { regexp -line {^(FATAL: signal|Tcl_AppInit\(\) error)} $body }
proc regression_case_failed {childcode body} { ... exit 0 AND complete AND not died ... }
```

`banner_complete` is the **Tcl transcription of the already-shipped ERE at
`run_suites.sh:155`** — a port, not an invention. `banner_died` is `full_audit.sh`'s
own two crash literals, column-0 anchored.

## 5. AFTER

```
$ ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_pdk_launcher.tcl
OVERALL: ok (30 checks)          # exit 0, and T1 no longer synthesizes a HARNESS line
$ cd tests && tclsh run_regression.tcl ; grep -cE '(FAIL$|GOLD\?$|RESULT\?$|^FATAL)' results.log
0                                 # was 3
```

`test_audit_classifier` 50 → **69 checks**, ALL PASS. T2 `run.sh` `== HARNESS: PASS ==`
6/6, unmoved. No `src/` change, no build.

## 6. The banner census that made the sweep finite

Swept every `tests/headless/*.tcl`. The tree emits exactly three shapes: bare
`OVERALL: ok` (**131** sites), `OVERALL: ok (N checks)` (**5**: `test_pdk_launcher:119`,
`test_ihp_sg13g2_libmgr:195`, `test_descend_inert_class:183`,
`test_context_menu_descend_refusal_0249:110`, `test_descend_refusal_channel_0251:437`)
and `OVERALL: ok  (all checks passed)` — DOUBLE space (**2**:
`test_dblclick_connected_grow:334`, `test_select_same_net_by_label:259`). Only **two**
of those seven are in `hcases`, which is why there were exactly two false reds and not
seven; **the other five were latent** and adding any of them to `hcases` would have
produced an instant new one. All seven are accepted now.

## 7. Decisions (ladder rung → rejected alternative)

| # | rung | decision | rejected |
|---|---|---|---|
| D1 | **L1 (I1 by analogy)** | the rule moves into one shared procs file; `run_regression.tcl` becomes a **consumer** | keeping the regexp inline and locking only its spelling — the red phase could then assert spelling, not behaviour, and there is no callee to rename for sabotage |
| D2 | L2 | the completion predicate is the **port** of `run_suites.sh:155`'s ERE | 0629's `{^OVERALL: ok}` and 0492's `{^OVERALL: ok\M}` — both pass the pass/fail battery but additionally accept `OVERALL: ok<TAB>junk` / `OVERALL: okay then` (measured), leaving the readers disagreeing |
| D3 | L2 | ship the relaxation **only** with `banner_died` | this issue's own section-3 recommendation, unpaired — see section 4 |
| D4 | L2 | `banner_died` fires **unconditionally**, deliberately WITHOUT full_audit's `&& ! is_pass` | mirroring that clause — it re-opens the hollow-pass hole. The resulting asymmetry (run_regression stricter than the CI reader) is **filed as 0802**, not fixed |
| D5 | L2 + brief constraint | `couldn't execute "xschem"` / `exit 127` are **NOT** in the death set | folding them in "for symmetry" — it would blur the issue 0016 Part 4 distinction the brief forbade breaking. Both markers appear **0** times in the after-run `results.log`; that arm lives in the golden cases' `/bin/sh` jobs and the `xschemtest` guard, neither reached from this predicate |
| D6 | L2 | `[ \t]` not `[[:space:]]` on the Tcl side | Tcl's `-line` regexp lets a bracket class containing `\n` reach across the line boundary; K18 asserts the two spellings agree anyway |

## 8. Sabotage matrix (predicted → observed)

| variant | predicted red | observed |
|---|---|---|
| SAB-1 `banner_complete → 0` | K1,K2,K3,K4,K13,K18 + all 29 hcases HARNESS-fail | **exact**; T1 0 → 29 counted lines; K5-K8,K11,K12,K14,K15,K16 stayed green (the reject rows are not tautological) |
| SAB-2 `banner_complete → 1` | K5,K6,K7,K8,K15,K18 | **exact** (6 FAILED / 63 passed) |
| SAB-3 `banner_died → 0` — the brief's "strictly worse harness" | K9,K10,K12,K19 | **exact**. K1-K8, K11 and K13 **all stayed green**: the relaxation alone passes every row it was written for, and only the death predicate catches the swallowed death |
| SAB-4 `regression_case_failed → 0` | K12,K14,K15,K16 | **exact** |
| SAB-5 as literally specified (composite renamed **and** private copy pasted back) | K17 only | **6 red** — K17 plus K12-K16 reporting `NO_PROC`. The extra five are an artefact of the variant's own rename, not extra coverage; the variant's `how` was inconsistent with its own prediction |
| SAB-5b **pure drift** (rule file intact, private copy pasted into `run_regression`) | K17 only | **exact**, and T1 regained exactly the two HARNESS lines. K17 is both necessary and sufficient for the drift — without it the whole fix could be reverted with 68 green checks |

**One predicted red did not appear as predicted**: SAB-5's "every behavioural row
stays green". Recorded because it matters — SAB-5b is the variant that actually
models the real-world failure mode, and it is the one that vindicates K17.

## 9. Still open

* **0802** — `full_audit.sh` still scores pass-banner-then-death as PASS. Until it
  lands, two harnesses read the same log and disagree. That is a smaller version of
  the condition this issue exists to end.
* **0805** — `full_audit.sh`'s `is_pass` is prefix-anchored only, so it accepts
  `OVERALL: okay then` and `OVERALL: ok<TAB>junk` that the other two readers reject.
  Latent (no suite emits either), and the reason `banner_rule.tcl` no longer claims
  the three readers agree.
* **`banner_died` opens a new false-red surface of exactly this issue's class**: a
  future hcase that echoes a **child** xschem's `Tcl_AppInit() error` at column 0
  would be HARNESS-failed while every one of its checks passed. The sharefarm
  pattern that could do it already exists (`test_ase_core` NTD1-NTD7); measured
  today at **zero** occurrences across all 29 hcase logs, so it is latent.
* **K17's lock is regexp-shaped** (`regexp[^\n]*OVERALL: ok` in a non-comment line).
  A private copy rewritten as `string match {*OVERALL: ok*}` would slip past it.
* The five latent counted emitters are still **not** in `hcases`; adding them is now
  safe but was not done here.

