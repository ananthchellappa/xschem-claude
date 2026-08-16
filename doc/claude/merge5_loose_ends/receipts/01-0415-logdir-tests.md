# Item 01 — issue 0415: two tests missing from `logdir_tests`

Base HEAD `938388a5`, branch `fluid-editing`, dev display `:99`, `GUI_GATE=1` on every run I launched
(`full_audit.sh` forces `GUI_GATE=0` for itself on `:99` — its own business). **[x]**: no pixels, two audit rows.

## 1. Files changed

```
 doc/claude/issues/0415-two-tests-missing-from-logdir-tests.md | 61 ++++++++++++++++++--
 tests/headless/full_audit.sh                                  | 18 +++++++
 tests/headless/test_ase_log_seam_0207.tcl                     |  9 +++-
 tests/headless/test_select_at.tcl                             |  8 ++-
 4 files changed, 90 insertions(+), 6 deletions(-)
```
Plus this receipt and the archived audit under `doc/claude/merge5_loose_ends/` (new dir).
**Exactly ONE non-comment line changed in the whole diff** — `+  test_ase_log_seam_0207 test_select_at \` in
`logdir_tests`. `git diff -U0` on the two `.tcl` files, filtered for lines not starting with `#`, is empty; the
other 17 harness lines are the rationale comment above the list. `full_audit.sh` is still mode 755. A duplicate
receipt (`receipts/01-logdir-tests-0415.md`, written before the mandated filename was known) was folded into
this one and removed — full text kept at `scratchpad/closer/01-logdir-tests-0415.md.SUPERSEDED`.

## 2. Decisions taken, and the evidence

**Grant the flag by list membership, not an extra invocation.** `--nolog` + `--logdir` is a fatal abort
(`src/util.c:344-349`), so safety was proven three ways, not asserted: (a) sourced under `AUDIT_LIB_ONLY=1` and
enumerated with the harness's own `in_list` — `logdir_tests ∩ nolog_tests = ∅`, `logdir_tests ∩ nogui_tests = ∅`
(the nogui arm passes `--nolog --nogui`), `nolog_tests` holds only `test_nolog`; (b) `full_audit.sh:435-449` is
an `if/elif` chain whose FIRST arm is `logdir_tests`, so a name takes exactly one arm whatever the lists say;
(c) `run_suites.sh --nolog` **cannot arise** — no such option exists, nolog is that script's default *mode*
(`run_suites.sh:58`), and passing it explicitly gives `run_suites: unknown option --nolog`, exit 2, before any
binary starts. The binary guard was fired directly too: exit 1, `--nolog and --logdir are mutually exclusive`.

**RULING — `test_ciw` and `test_selflog_output` are NOT part of this fix.** `open_pdk_merge5_result.md` §6 names
them alongside 0415, so a ruling was owed. Both were **already** on `logdir_tests` (`full_audit.sh:81`, `:84`) — no membership to add — and neither red is a missing
log: the baseline shows `test_ciw` printing `ok: actionlog_filename set` then `FAIL: no result/error text in
file`, and `test_selflog_output` printing `ok - action log open` then six `FAIL - key <mod>-<k> logs …` rows
(the documented WSLg `event generate` flake). What §6 records for them is a `run_suites.sh` **invocation-mode**
mismatch, not a list gap. Not widened, so the audit delta stays the predicted two rows. Ruling written into the
issue file ("Not widened, deliberately"); no new spec clause, because the exclusivity is already law in
`src/util.c` and both consumers honour it structurally.

**Correct the "loses all 26" figure** (confirmed review finding, reproduced). With the names removed: `RESULT:
16 FAILED (10 passed)`. The 10 survivors — PS1, PS7c, PS9, PS10a, PS10b, PS11, PS12b, PS13, RP2, RP3 — assert
*absences* and pass vacuously over a log that was never opened. Wording now in the harness comment, the test
header and the issue: **all 26 are worthless without the flag, but only 16 say so.** The other confirmed finding
(a receipt md5 matching no file on disk; an archive shot 2.5 min *before* the last source edit) was cured by
re-measuring, not re-labelling. One stale citation found while closing and fixed: the issue said
`full_audit.sh:432-446` for the dispatch chain; it is `435-449` in the shipped file.

**The comment-only header edits to both `.tcl` files are part of the fix, not widening:** the absent "registered
in `full_audit.sh` `logdir_tests`" pointer — carried by 50 sibling suites, not the "~60" an earlier draft
claimed — is half of why the gap survived undetected.

## 3. Tests, check count, verbatim RESULT lines

No new checks: a harness list edit adds **zero** `.tcl` assertions, and the suites it resurrects were already
written and correct; the drives in §4 stand in for a new-check sabotage. `test_ase_log_seam_0207` (26 checks,
banner-reported) + `test_select_at` (**15** top-level `check` calls, no count in its banner — the earlier
reported 14 was a miscount) = **41 checks**.

```
$ GUI_GATE=1 tests/headless/run_suites.sh --logdir test_ase_log_seam_0207 test_select_at
PASS     | test_ase_log_seam_0207       run 1/2  RESULT: ALL PASS (26 checks)
PASS     | test_select_at               run 2/2  RESULT: ALL PASS
RESULT: 2/2 runs passed
```

Full `tests/headless/full_audit.sh` on `:99` (21:37:54 → 21:50:40), nothing else running, no `make` in flight,
against the files being committed; archived at `doc/claude/merge5_loose_ends/audit_item01_2026-08-15.txt` (the
fixer's earlier archive of the same delta is kept in the scratchpad).

```
SUMMARY: 316 pass  15 fail  0 crash/timeout  0 skip  (total 331)
WIREEDIT: PASS
SCRATCH:  0 leaked dir(s)
TREE:     0 appeared  0 vanished (report only, gitignored paths excluded; issues 0352/0353)
```

Diffed by test NAME and STATUS against `doc/claude/batch_F/baseline_status_2026-08-15_postmerge5.txt`
(314/17/0/0 of 331) — same 331 names both sides, none added, none dropped:

```
test_ase_log_seam_0207: FAIL -> PASS
test_select_at:         FAIL -> PASS
```

**That is the whole delta, in both directions**, so no standalone re-attribution was owed. The 15 remaining reds
are the baseline's 17 minus these two, name for name — all previously documented (W7, the four libmgr
environment reds, the WSLg key-delivery flakes, and the rest).

## 4. Sabotage table

| check / drive | what was broken | red? | restored green? |
|---|---|---|---|
| **Drive 1** — `test_ase_log_seam_0207` row | the list edit itself: `full_audit.sh` replaced by the byte-exact pre-item file (`md5 2786696d…` = `git show HEAD:`), never `git checkout` | **yes** — first failing line `FAIL: PS0 action log open (needs --logdir) -> {0} (exp {1}) : FAIL`, `RESULT: 16 FAILED (10 passed)` | **yes** — restored to the shipped file (`md5 b9a769b714e6c2d54bcf074a80592903`), `RESULT: ALL PASS (26 checks)` |
| **Drive 2** — `test_select_at` row | same single list edit (name absent → the audit falls to the final `else` arm and passes `--nolog`) | **yes** — first failing line `FAIL: action log open`, then SA5/SA6b/SA7b/SA8b; `RESULT: 5 FAILED`, exactly the five names 0415 filed | **yes** — `RESULT: ALL PASS` |
| **Seam sabotage** — PS3, PS5, PS6, PS7a, PS7a2, PS7b, PS7d, PS12a | `src/ase.tcl:134-135`: `return ;# SABOTAGE` above the two `xschem log_action -result\|-error` calls, cutting the FILE half of `ase::echo` (Tcl, no rebuild) | **yes** — `RESULT: 8 FAILED (18 passed)`, red exactly on the "…in the LOG FILE" checks while pane-only PS2/PS4/PS8 stayed green | **yes** — byte-exact restore (`md5 81c66a72…` both sides, `git status src/ase.tcl` clean), `ALL PASS (26 checks)` |

**Unsabotaged, therefore NOT evidence:** the 10 vacuous absence-asserters above (they survive both a missing log
*and* the seam being cut) and `test_select_at`'s other 10 checks (fixture, SA1, SA1b, SA2, SA2b, SA3, SA4, SA6a,
SA7a, SA8a). A reviewer's stimulus-removal probe showed SA5/SA7b/SA8b cannot pass without their behaviour —
weaker than a code sabotage, recorded as such.

## 5. What was NOT verified

* **No `:0` run.** All runs on `:99`. Judged not owed (the change alters no editor runtime behaviour, only which
flag the harness passes), but a reviewer called it an `[E]`-vs-`[x]` question worth naming, since these 41
checks had never executed under the audit before. No `owed.sh look` entry: nothing here is pixels.
* **Reviewer findings raised but NOT confirmed: none.** Both confirmed ones are fixed above.
* **Reviewer not-proven items carried forward:** whether `test_ciw`/`test_selflog_output` go green under
`run_suites.sh --logdir` (their reds were shown *not* to be log-open failures, which is all the ruling needs,
but the alternate mode was never run); and whether all 10 vacuous survivors are vacuous (PS9, PS10, PS13
spot-checked only).
* **`open_pdk_merge5_result.md:157` still says "(Both are issue 0415's `logdir_tests` gap.)"** — overturned by
the ruling above but left uncorrected: it is a historical merge record and this batch's shared context file, so
editing it is the driver's call. **Flagged.**
* **Pre-existing, not fixed here:** `run_suites.sh <name>` in its default mode still runs all `logdir_tests`
members with `--nolog`, and `owed.sh drain` (`owed.sh:306`) hands names to it with no mode flag, so a suite debt
against any logdir-arm test could never clear. `full_audit.sh:176-178` also still lists `test_select_at` among
suites that "only ever print `OVERALL: ok`", which is false.
