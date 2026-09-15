# 1470 — A build that cannot do what ASE-L offers is never named, and a command line that crashes it gets no warning

**Status:** FIXED pending the driver — Stage 16 task 1 of the ASE-L analyses batch
(`doc/claude/ase_analyses_batch/PLAN.md` §16a–§16d, debt **M21**), receipt
`doc/claude/ase_analyses_batch/receipts/46-stage-16-deck.md`. Filed 2026-09-15 by the Stage 16
task 1 crew at the moment the work needed a number. **Task 2** — the Simulators-window row, its
`look` debt and 16e's release note — is not part of this issue's fix.

## What the user meets

Four things, and the first is the one Stage 16 exists for.

1. **A command line that kills the simulator gets no word before or after.** A pre-command reading
   `unset temp` on apt 45.2 — the ngspice the current Ubuntu LTS ships — ends the run with SIGABRT,
   rc 134, and the abort does not flush stdio: the log is destroyed and nothing anywhere says why.
   `define` + use, and `load` of a raw carrying a computed-variable header, do the same by other
   arms. *TRANSCRIBED* from `evidence/fork-dependencies.md` §3–§4 (B1.1–B1.4); **not re-run** —
   this batch does not crash the user's simulator to confirm a crash (D50, `CREW_BRIEF.md`). Two
   quieter kinds of line misbehave on the same builds: a bare `gnd` in an `echo`/`shell`/`write`
   argument becomes ` 0 `, and `write <file> ALL` writes **no file at rc 0**.
2. **What the build cannot do is measured and never said.** *MEASURED* 2026-09-15 through
   `ase::sim_capabilities_path` on all three binaries: apt 45.2 answers `casemode_detected {fold}`,
   `altshow_op_dump 0`, `keyword_case 0`, `gnd_literal 0`; stock 47 answers `{fold}` and `0 0` for
   the two defect keys; the fork answers `{fold preserve distinguish}` and `1` everywhere. ASE-L
   used those answers to gate its own behaviour and told the user none of it.
3. **An ASE-L run's rawfile never says which case mode wrote it (debt M21).**
   `ase::run_casemode_flag` returned `-D casemode=<m>`; the classic path's `sim_run_flags` returns
   `-D casemode=<m> -D casemodewrite`. *MEASURED* on the fork, ASE-L's own deck shape: without
   `casemodewrite` the raw has no `Option:` line; with it, `Option: casemode=preserve`. So the
   header parser's SOURCE 2 could never fire on a file ASE-L caused.
4. **The wrong explanation for a long deck (16d).** A build on the per-device operating-point shape
   because its `show` printer is unsound was told *"there is a much shorter way your simulator
   would accept, but it is all or nothing"* — true, and not the reason.

## The fix

* **16a** — `ase::variant_frame` / `ase::variant_sentence` / `ase::variant_say` /
  `ase::variant_report` (schema) over the adapter's new `variant_notes {caps}` hook (content). Four
  frames — nothing measured, nothing missing, something missing, **measured but not completely**.
  Said in the run log (CIW + the log header's `notes`) once per binary per session, deltas only.
* **16b** — `ase::backend::ngspice::lint_control_text {lines caps}`, the five patterns, run by
  `ase::preflight_notes` on the pre-flight pass (after `ase::run_precheck`, before
  `ase::preflight_gate` and before the first delete). It warns, never rewrites, and quotes the line.
  D47's warn/refuse policy is `ase::preflight_policy`; the ngspice adapter licenses no refusal.
* **16c** — `ase::backend::ngspice::scripts_dir_of {sourcepath}` (the parse rule) and
  `cosim_shim_verdict {scripts_dir}` (the two installation greps). Not yet wired to a say-site.
* **16d** — reason token `dumpunsound` on `ase::op_save_tier`, with its own sentence tail.
* **M21** — `ase::run_casemode_flag` returns `-D casemode=<m> -D casemodewrite`.

Suite: `tests/headless/test_ase_variant_1470.tcl`. Rows that moved, each with a comment naming this
issue: `test_op_dump_altshow` T2, `test_ase_optier_0963` X5, `test_sim_run_profile`
CS176/CS176c/CS176d/CS176e, `test_ase_simdlg_0937` S29.

## Rulings this leaves with the user (`owed.sh add rule 1470`)

Every new sentence (⚖ R9, `R9_COPY_REVIEW.md` section *Issue 1470*, R9-678 … R9-719), plus four
choices the crew made in the recommended shape:

1. **The run log says only a delta** — frames 3 and 4. Frame 2 (*"can do everything"*) shrinks to
   nothing there, and frame 1 (*"press Detect"*) belongs to the Simulators window, because on the Run
   path `ase::cap_report` already owns the sentences for a program that did not answer.
2. **Patterns 1–3 warn on every binary, the fork included** — the key that could silence them is
   the probe D50 refuses.
3. **Pattern 4 is confined to commands whose arguments are text** (the reader's case-preserving
   list) and pattern 5 to `write`/`wrdata` — so `print v(gnd)` and `print ALL`, which work
   everywhere, are not nagged.
4. **`dumpunsound` only when the printer is MEASURED unsound** — an absent key still reads `unsafe`.
