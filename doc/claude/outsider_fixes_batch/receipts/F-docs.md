# F-docs: stage F documentation crew (CLAUDE.md, issue files, NUMBERING)

**Status: DONE.** The crew did not commit, stash or reset. HEAD is `7a46275f` throughout.

Tags: **M** = measured (I ran it, and the output is quoted), **R** = read from source or
artefact, **I** = inferred.

## Verification (M)

| check | result |
|---|---|
| `HOME=<scratch> tclsh tests/headless/issue_stamp.tcl`, run after every edit, and last after the final CLAUDE.md edit | `self-test PASSED (87 parser cases)`, `history: full`, **`ISSUE-STAMP: ok (0 problems)`**, rc 0 |
| `… issue_stamp.tcl report` | `carrying a **STAMP:** line : 17`: the 10 from before, the 6 new files, and 1481. `/usr/bin/grep -rln '^\*\*STAMP:\*\*'` also answers 17. Not vacuous. |
| red first on a new file (1488, in place, restored) | `tree=1234567` → `1488: malformed stamp -- tree=1234567 is not a revision`, rc 1. Stamp line deleted → `1488 (…): a NEW issue file with no **STAMP:** line`, rc 1. Restored **md5-identical**. |
| `cd tests && env -u DISPLAY HOME=<scratch> timeout 900 ../src/xschem --nogui --pipe -q --script headless/test_issue_stamp.tcl` | rc 0, **`RESULT: ALL PASS (93 checks)`**, `OVERALL: ok`, 93 `ok`, 0 `FAIL`, **0 `skip`** |

## Numbers minted (M, by CLAUDE.md's two-check procedure)

* **Pointer:** `**The next free number is 1482.**`. **Band check:** 1482–1488 are in no
  reserved band.
* **Cross-clone check:** the glob matched both clones. `ls ~/dev/*/doc/claude/issues/<n>-*`
  was silent for 1482–1488.
* **But `/usr/bin/grep -lw 1482` hit BOTH `NUMBERING.md`s.** Each hit is that clone's live
  pointer line, and op-wcard's `NUMBERING.md` is **byte-identical** to this one (`cmp`).
  The procedure reads any `NUMBERING.md` hit as taken, and op-wcard's own next filing would
  take 1482 (issue 1400's shape). So **1482 is skipped**, which NUMBERING records, and
  **1483–1488** are minted (each silent on both checks).
* **NUMBERING.md** records the skip, the six entries, and **`The next free number is
  1489.`** The pointer grep (`… | grep -v '~~' | tail -n1`) answers 1489. My prose was
  reworded so that it does not contain the pointer phrase.
* ⚠ **Residual risk (I):** op-wcard's pointer still reads 1482, so its next filings walk
  into 1483–1488. It must run the cross-clone check too. Nothing in this clone can prevent
  that.

## Files

New issue files, each stamped
`claim=open tree=7a46275f stamped=2026-09-18 … by=F-docs`:

| # | item | file | `fix=` `open=` |
|---|---|---|---|
| 1483 | (a) F14, re-attributed | `doc/claude/issues/1483-four-t1-suites-segfault-mid-run-under-nogui-when-display-is-unset-so-a-headless-box-never-sees-zero.md` | none, 1 |
| 1484 | (b) uppercase path | `doc/claude/issues/1484-an-uppercase-letter-in-the-checkout-path-turns-five-ase-suites-red.md` | none, 1 |
| 1485 | (c) nine git-export suites | `doc/claude/issues/1485-nine-t1-suites-go-red-in-a-git-archive-export-because-they-read-their-corpus-through-git.md` | none, 9 |
| 1486 | (d) cwd writes | `doc/claude/issues/1486-suites-write-the-untitled-autosave-into-their-cwd-and-the-checkouts-op-param-project-file-is-the-users-not-litter.md` | partial, 2 |
| 1487 | (e) `summarize_all` drops `skip:` | `doc/claude/issues/1487-the-t1-verdict-cannot-show-that-a-case-skipped-rows-because-summarize-all-drops-skip-lines.md` | none, 1 |
| 1488 | (f) `test_wave_markers` on an attached display | `doc/claude/issues/1488-test-wave-markers-hangs-when-run-suites-attaches-to-a-persistent-dev-display.md` | none, 1 |

(g) was skipped, as briefed.

Edited:
* `CLAUDE.md`;
* `doc/claude/issues/0891-…md`: an ADDENDUM for D8, and its stamp re-dated;
* `doc/claude/issues/1481-…md`: an UPDATE with 87/76, and now stamped;
* `doc/claude/issues/NUMBERING.md`.

## What the measurements changed about the brief (read these first)

1. **(a) The segfault is mid-suite, NOT on exit (M).** The brief and the S2c critic said
   "segfault on exit". I ran all four with DISPLAY unset and a scratch HOME at `7a46275f`:
   * `unused_attr_0970`: 57 `ok` rows then signal 11, after `UF28`;
   * `auto_specialize_1201`: 66 rows, after `AS65`;
   * `optier_0963`: 88 rows, after `S13`;
   * `op_annot`: 341 rows, after `W30a`.

   These are the same rows S1 recorded. The gate's own DISPLAY-set logs give 67, 85, 109
   and 485 checks. The code after each last row loads a sheet and descends or walks into a
   child (R), and the crash handler names the child (`passgate`, `aswv`, `uapass`). So the
   common factor is a descend or walk under `--nogui` with no display (I).
2. **(d) D12's op_param line is wrong, and dangerous if acted on (R).**
   `<repo>/.xschem/op_param_lists.conf` (untracked, mtime 2026-09-09 09:58:51, 19 rows, M)
   is **the user's own Save**. Issue 1381 Part 2 records one being quarantined as "litter"
   on 2026-09-07, and `src/op_param_lists.tcl`'s DD-6 comment names the user's file.
   * The three suites that exercise the tier guard it by identity (`H1`, `SD4`, `BT9`).
   * No crew in the batch measured a suite writing it.

   1486 files the D12 line **corrected**, and says so at its head. **DECISIONS.md D12 still
   reads as if the file were litter. That is the driver's file to amend. I did not edit it.**
3. **(e) The stage-F gate is itself the evidence (M).**
   * Its case logs carry **8 `skip:` lines** and `results.1176485.log` carries **0**.
   * `test_ase_converge_1459` ran **70** checks (not 76) and `test_ase_sp_1452` **58** (not
     61). The gate's HOME `/var/tmp/xschem_fixes/gate_f/home` has **no `dev/`**, so the
     fork ngspice was absent.
   * **So the stage-F gate did not exercise D10's fork-ngspice legs.** Every case is still
     green, but the verdict could not say so, which is 1487.

## CLAUDE.md: passage by passage

* **Single-case command.** It now arms a throwaway: `t1_arm_home` at source time, with a
  banner (R).
* **Under "A BARE `xschem` ON PATH".** The damage is now contained: the critic's F10
  red-first (base 729 `recent_files` lines, fix canary identical, R), and `binary=`.
* **The NOGOLD bullet's bare command** became `tests/headless/run_suites.sh --nogui <t>`.
  * The bare spelling is kept, with its real-HOME warning (D9).
  * **190 of 405** `test_*.tcl` have a non-comment `source … scratch.tcl` (M). A bare
    name-grep says 191, because `test_issue_stamp.tcl` mentions it only in comments. That
    is why the suite printed no `note:` in my run.
* **The `T1-RUN-BEGIN` field list** gained `home= binary=` before `canonical=`, with
  their values and sanitising.
  * The coordinates `:694`/`:916` had rotted to `:1003`/`:1293` at `7a46275f` (M, grep).
* **Case counts** (M, all from the artefacts):
  * 87 cases, 86 blocks, lists 3/72/11 (the `grep -o` pipe);
  * 87 `Start` / 87 `Finish` and 0 peer lines in `gate_f.out`;
  * `wc -l` **177**, with a new 177 breakdown block.
  * The "READ THE NEXT WARNING" pair is kept, with a note that 85 is now neither
    quantity.
  * **Two failure figures are added, both measured by other crews:** 185 = 87/86/8 (the
    regression refuter ×5, R3 prover ×2), and **181 = 85/84/8** (R3 prover base).
  * The latter makes the old *"nobody has run an 85-case verdict with failures"* false,
    so that sentence is corrected.
* **The 1481 paragraphs.**
  * The trigger is narrowed by D8: NODISPLAY only with no Xvfb, HARNESS FAIL counted when
    Xvfb will not start.
  * "Derived, not measured" is retired: S1's 85/74/11 NODISPLAY ×3, and R3's 87/76.
  * The coordinates are now `:1190`/`:1212`/`:1245` at `7a46275f` (M). They were +349,
    +356 and +358: not uniform.
* **The "84 for today's 85" `Total num fail:` rule** now says 86 for 87.
* **The current-baseline paragraph** gains the 87-case gate (rc 0, 517 s, header, private
  `:100`) and its two gaps (DISPLAY-unset → 1483; skips → 1487).
  * The following "That gate went RED" was re-anchored to "The 85-case gate (`1acae0b0`)".
    Otherwise my insertion would have hijacked its antecedent.
* **The `xschemtest.tcl` bullet:** not armed by hand (D13.1).
* **New subsection "The throwaway test home":**
  * what arms: the list the brief gave, checked against G2's ARM regex (R);
  * what does not;
  * the G2 guard, stated as "a new launcher reddens T1 until armed" (R, from the row
    definition);
  * the four variables, and D13.2's scoped exceptions;
  * the pointer to D4–D20.
* **Dev-display section:**
  * the bare command keeps the real HOME;
  * the standalone suites are now HOME-armed too;
  * a new option 3 (only `run_suites.sh` arms HOME; `devdisplay.sh exec` routes the
    display only);
  * the dev display is started with the real HOME by design, auto-started only if the
    state dir exists;
  * the `test_wave_markers` TIMEOUT (→ 1488).
* **Display-arm knobs:** `AUDIT_XVFB_BASE` (default 200, never below 100; R,
  `xvfb_arm.sh`).
* **Watchdog paragraph:** 190/405 at `7a46275f`; the bare command keeps the real HOME, and
  `run_suites.sh --nogui` gets both bounds and a throwaway.
* **Issue numbering:** a new file needs a valid stamp or T1's `test_issue_stamp` row `D9`
  ("the gate is GREEN on the real corpus", R) goes red. Grandfathering is by exact name.
  The note adds the rules on the header window, the a–f letter and the ancestor of HEAD
  (D15.4), and points at the spec.

**Beyond the brief's list: three passages that were false by now (M); the banner one was made false by `2cf01084` on 2026-09-17, not by this batch, fixed in
the file's voice:**
* the "HARNESS ITSELF STILL PRINTS THE REFUTED SENTENCE" paragraph. The banner was
  corrected in **`2cf01084`** (09-17 09:00), found by `git log -S`, and its text was read
  at HEAD;
* the `t1_live_runs` coordinate: `:656-665` → `:946`;
* the fossil paragraph's "the tree now runs 85".

## Deviations

1. **1481 is now stamped** (`fix=untried open=1`), and **0891's stamp is re-dated**
   (`tree=7a46275f stamped=2026-09-18 by=F-docs`, claim and counts unchanged). I
   re-verified each against the tree:
   * 1481's `continue` is still ahead of `Finish` (R).
   * 0891's follow-up 3 is still open: `dcases` still lists `test_annot_stale_0684`, and the
     gate printed its display-arm `Start` (M).
   * 0891's follow-ups 1 and 2 have landed (`t1_timeout`, `fconfigure $fd -buffering
     line`, R).

   The spec says a stamp is updated when the file is re-verified. The checker is green with
   both.
2. **I ran four suites (M)** with `env -u DISPLAY` and scratch HOMEs, to measure (a). They
   left four emergency-save dirs in `/tmp`, named in their outputs, and four
   `tests/headless/.scratch/_<suite>_<pid>` corpses, matched by suite, pid (dead) and
   second. **All eight were removed.**
3. **Not filed (not in the brief's (a)–(f)):**
   * D12's sixth bullet (`ngspice -p` writes `~/.ngspice_history`, origin unknown);
   * the S2c critic's problem 9 remainders: F28's NOGOLD part, and F43's 84–107 MB of
     gitignored output and the `.actionlogs` mkdir. F43's `untitled~.sch` part is in 1486,
     which cross-references 0609/1480.
4. **The batch checksum manifest** (`xschem_manifest_fixes.md5`, cited by other receipts)
   was not found under `/var/tmp` or `~/.claude` at depth ≤ 4. So I did not run a manifest
   check. The real-home check below is by `find -newer`.

## Open problems for the driver

1. **Amend DECISIONS.md D12's op_param line** (see "What the measurements changed" 2)
   before anyone acts on it. 1486 carries the correction.
2. **The stage-F gate did not exercise the D10 fork legs** (converge 70, sp 58). If the
   commit message or LEDGER says the gate proved D10, it did not. The R2 refuters' 76/61 is
   the D10 evidence.
3. `ngspice -p`, F28 NOGOLD and F43: still unfiled (deviation 3).
4. op-wcard's pointer at 1482 (see "Numbers minted").
5. The LEDGER row for F is the driver's. I did not touch LEDGER or DECISIONS.

## Real home and constraints (M)

* Every xschem/tclsh run used `HOME=/var/tmp/xschem_fixes/fdocs/{home,h_<suite>}` with
  `DISPLAY` unset. Nothing ran with `HOME=/home/analog`.
* `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate ~/.cache/openbox
  -newer /var/tmp/xschem_fixes/fdocs/home` (my first action) printed **nothing**, at the
  end.
* The newest `/tmp/Xschem.log*` is `.4` (09-17 23:35), so no interactive session was
  running.
* The driver's gate snapshots, compared read-only:
  * `scratchpad/realhome_before.txt` = `realhome_after.txt` (`cmp`);
  * `gate_f/canary_before.txt` = `canary_after.txt` (`cmp`, 66 lines).
* **Not touched:** `:99`, `~/.claude/xschem_dev_display`, `~/.claude/gui_test_gate` and
  `~/.claude/xschem_owed`. **Read only, never written:** `~/dev/xschem-op-wcard` (its
  `NUMBERING.md` and its issues listing).
* No commit, stash or reset.
* **Scratch left for the driver:** `/var/tmp/xschem_fixes/fdocs`. It holds the four
  `*.nodisp.out` files that 1483 cites, `istamp_suite.out`, and the scratch HOMEs.
