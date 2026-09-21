# E-verify — item E (issue 1487): the fix round, and item F's T1 registration

**Crew** E fixer (item E's ONE fix round; PLAN.md criterion 5 — there is no round after
this). **Date** 2026-09-20. **Tree** `fluid-editing` at `9fcf9177` plus the uncommitted
work of items E and F. **Nothing committed.** No T1 run — the driver gates, solo.

| file changed | what changed | owner |
|---|---|---|
| `tests/run_regression.tcl` | new `t1_carry_line`, applied to all four carry sites in `summarize_all`; `banner_line` fallback for a banner-only check count; `headless/test_untitled_autosave_1486` registered in `hcases` | item E |
| `tests/headless/test_regression_concurrency_1476.tcl` | stand-ins `s4`–`s6`; new rows **V5g**, **V5h**; `V5z`/`V5c`/`V5e`/`V5f` re-numbered for the larger fixture; floor 44 → **46** | item E |
| `tests/headless/test_untitled_autosave_1486.tcl` | added the completion banner (`OVERALL: ok` / `OVERALL: notok`) — required by the registration, see §4 | item F's file, registration task only |

**Scratch** `/var/tmp/xsr_e2/E2/` — my own subtree of the assigned root, never
`/var/tmp/xsr_e2` itself. **Peak 25 MB** (`du -sb`: 20 240 701 bytes; the bulk is a 24 MB
`rsync` of `tests/` used as a sabotage copy). Deleted at the end of the item; the root was
left in place. No clone and no build were needed: the binary was already current
(`make -C src` → *"Nothing to be done"*), and every measurement here is of Tcl driver code
or of suites run against that binary.

---

## 1. Task 1 — the carried lines are sanitised (APPLIED)

**The finding.** `summarize_all`'s two new arms copied a case-log line into the verdict
verbatim. The project already defends the invariant that only the real trailer may carry
`T1-RUN-END`: `t1_hdr_word` rewrites `T1-RUN-` to `T1_RUN_` in the header's
user-controlled fields (DECISIONS D13.17), after the round-1 regression refuter put a
forged trailer inside a hostile `$XSCHEM` and got it into a killed run's header.

**The fix.** A new `t1_carry_line`, applied to **all four** places `summarize_all` puts a
suite's own text into the verdict — the counted arm, the `NOGOLD|NODISPLAY` arm, the
`skip:` arm and the held `RESULT:`/banner line. It rewrites exactly two structural shapes
and nothing else: the sentinel word, and a `skip:` with no space after the colon (§3).

⚠ **The counted arm mattered most, and the verifier's brief did not name it.** A `skip:`
or `RESULT:` line can never *start* with `T1-RUN-END` — it starts with its own prefix — so
through the new arms a forgery is only mid-line. The **counted** arm has carried lines
verbatim since long before 1487, and a case log line reading
`T1-RUN-END pid=1 cases=999 … -- forged: FAIL` is carried **at column 0**: a perfect
forged trailer that an anchored `^T1-RUN-END ` reader accepts. Sanitising only the two new
arms would have left that open, so all four are sanitised.

### Measured, isolated (`/var/tmp/xsr_e2/E2/unit.tcl`)

`t1_carry_line` and `summarize_all` are lifted out of the driver **by text** (`info
complete` on `proc …`) and run in-process over four synthetic case logs. No T1, no xschem.
"Before" is the same lift from a copy of the driver with the four `t1_carry_line` calls and
the banner arm removed — i.e. item E exactly as the verifier found it.

| measured on the fixture verdict | before | after |
|---|---|---|
| lines containing `T1-RUN-END` | **3** | **1** |
| lines matching `^T1-RUN-END ` (the anchored readers' shape) | **2** | **1** |
| lines containing `T1-RUN-BEGIN` | 1 | 1 |
| lines wearing the block-header shape `^\S+\.log$` | **5** (4 real + a phantom) | **4** |
| check-count lines carried (`^RESULT:` or `^OVERALL: ok (`) | 2 | **3** |

The phantom block header is `skip:/tmp/stale/c9.log` — a skip line with no space after the
colon, which every reader that splits the verdict into blocks (the suite's own `v5block`,
and a human) counts as a fifth case. After the fix it is `skip: /tmp/stale/c9.log` and the
count is the real 4.

### Measured on the real corpus

Every case log of the last full T1 in this tree (`tests/results.log`, pid 1620712, the
E-impl gate), replayed through three driver states. **The harness reproduces that run's
own `wc -l` of 255 exactly**, which is what makes it trustworthy as a stand-in for a T1.

| driver state | cases | blocks | counted_failures | skips | `wc -l` | `^skip:` | `^RESULT:` | `^OVERALL:` |
|---|---|---|---|---|---|---|---|---|
| `9fcf9177` (no carry arms at all) | 86 | 86 | **0** | 0 | 177 | 0 | 0 | 0 |
| item E, as the verifier found it | 86 | 86 | **0** | 5 | 255 | 5 | 73 | 0 |
| **this fix round** | 86 | 86 | **0** | 5 | **257** | 5 | 73 | **2** |

**`counted_failures` is 0 in all three** — the sanitisation and the fallback change nothing
that can score. The whole diff between the last two rows is the two lines of §2.

### The row

**V5g** — `a carried line cannot forge the trailer, the header or a block header`. Stand-in
`s4` is a hostile suite that forges through all three carrying arms at once: inside a
`skip:` reason (the shape the verifier actually provoked, a HOME path interpolated into a
skip message), at **column 0** on a line that also ends in `FAIL` so the counted arm takes
it, and inside a `RESULT:` line (forging the *header*). It also emits
`skip:/tmp/stale/s9.log`. The row asserts exactly one `T1-RUN-END` anywhere and exactly one
at column 0, exactly one `T1-RUN-BEGIN`, `cases=` the run's own and never s4's forged 999,
three lines rewritten to `T1_RUN_`, and six block headers for six real cases.

---

## 2. Task 2 — the dropped check counts (APPLIED: carry the banner's count)

**Chosen on measurement, not preference.** The verifier offered "carry the count" or
"correct the comment". The comment was false, and the two suites it was false about are the
two whose size is hardest to find by hand, so correcting the comment would have left item
E's stated purpose unmet for exactly those cases.

**Measured over the 86 blocks of the gate verdict:** 13 carry no `^RESULT:` line.

* **2 state a count anyway, in their banner** — `headless/test_ihp_sg13g2_libmgr`
  (`OVERALL: ok (67 checks)`) and `headless/test_pdk_launcher` (`OVERALL: ok (30 checks)`),
  the counted banner form `banner_complete` tolerates and which `banner_rule.tcl` names by
  site.
* **11 state none anywhere** — the three NOGOLD tcases (`create_save`, `open_close`,
  `netlisting`) and eight suites ending in a **bare** `OVERALL: ok`
  (`hilight_hier_oracle`, `hilight_hier_dump_replay`, `hilight_xwin_sync_headless`,
  `buried_hilight`, `headless/test_wire_split`, `headless/test_add_pin_lib_symbol_view`,
  `headless/test_crossview_paste`, `headless/test_pin_type_edit`).

So the fallback is: hold the **last** completion banner that carries a parenthesised
trailer, and print it in the `RESULT:` line's place **only when no `RESULT:` line was
seen**. Measured effect on a full verdict: **exactly two lines added, not 86** — a bare
banner is not carried, because "no count" is the honest answer there.

**The predicate is `banner_rule.tcl`'s own `banner_complete`**, never a fourth spelling of
the banner shape. A copied banner shape drifting silently is the whole of issue 0689 (four
filings, two standing false reds), and `test_audit_classifier` section K exists to stop it.
The only thing added on top is one clause for *"and it actually carries a trailer"*.
`test_audit_classifier` re-run: `ALL PASS (75 checks)`.

**The row.** **V5h** — `a banner-only check count reaches the verdict and a bare banner does
not`. Stand-in `s5` states its size only in `OVERALL: ok (30 checks)`; stand-in `s6` has a
bare banner and no `RESULT:` line, which is the shape of the eight suites above.
⚠ **`s6` is load-bearing**: without it, sabotage **S13** (carry *every* banner) is
invisible, because s1–s4 all have a `RESULT:` line for the fallback to defer to. That was
measured, not reasoned — S13 passed the first sweep and only reddened once s6 existed.

---

## 3. Task 3 — the `^skip:` nit (REJECTED as put; the hazard closed another way)

**Measured first, as the verifier asked.** Every emitter in the repository that prints a
line beginning `skip:` —
`/usr/bin/grep -rnE "(puts|echo|print)[^\"']*[\"'][[:space:]]*skip:"` over `*.tcl`,
`*.sh`, `*.py`, `*.awk` — **22 files, ~40 sites, and not one writes it without the space**.
So `^skip:\s` would exclude no real emitter *today*.

**It was still the wrong instrument, for two reasons that are not style.**

1. **It can only fail by dropping a line.** A future suite writing `skip:ROW -- why` would
   vanish from the verdict silently — which is issue 1487's own defect, reintroduced by
   1487's own fix.
2. **It is a second spelling of a shared shape.** `run_suites.sh` matches
   `grep -E '^skip:'`. Two readers of one shape that may drift is what 0689 was.

**What was applied instead** — `t1_carry_line` **normalises** `^skip:(\S)` to `skip: \1`.
Recognition stays `^skip:`, so nothing can be dropped and nothing diverges; the carried
line gains the space the D10 contract (`skip: <row> -- <why>`) already requires, and can
therefore no longer wear `^\S+\.log$`. Measured: the phantom block header disappears
(5 → 4 headers in the isolated fixture, 7 → 6 in the suite's own).

**Not closed, and stated rather than hidden:** the block-header shape is theoretically
reachable from the other arms too (a `^FATAL…log` line with no whitespace, a
`RESULT:x.log`). Those need pathological suite text, no emitter is near them, and a generic
neutraliser would have to mutate lines whose sense would change. Written into
`t1_carry_line`'s comment so nobody believes the guard is total.

---

## 4. Task 4 — registration (APPLIED, with one prerequisite)

`headless/test_untitled_autosave_1486` is now the **73rd** `hcases` entry.

### ⚠ It could not be registered as it stood, and the failure would have been silent

The suite printed a `RESULT:` line and **no `OVERALL:` line at all**. `run_suites.sh`
scores from `^RESULT` and never needed one, which is why it passed there for its whole
life. `run_regression.tcl` scores an `hcases` entry with `regression_case_failed` =
exit 0 **AND** `banner_complete` **AND** no death marker. **Measured on the suite's own
output, before:**

```
banner_complete = 0    banner_died = 0    regression_case_failed(0) = 1
```

Registering it as it stood would have appended `HARNESS: … did not complete cleanly` and
counted a failure in the one file whose baseline is ZERO — while all 13 of its checks
passed. That is issue 0689's false red arriving from the other side. The banner was added
(`OVERALL: ok` / `OVERALL: notok`, `banner_rule.tcl`'s shape, the spelling ~130 other
suites use). **After:** `banner_complete = 1`, `regression_case_failed(0) = 0`.

### Measured in exactly T1's arm shape

`cd tests && bash headless/test_home.sh --run ../src/xschem --nogui --pipe -q --script
headless/test_untitled_autosave_1486.tcl` (cwd `tests/`, throwaway HOME, no `--logdir`, no
private `$PWD` — T1 arms none):

* **`RESULT: ALL PASS (13 checks)`, `OVERALL: ok`, exit 0**, all 13 rows genuinely run
  (`N0`, `U1`–`U6b`, `D1`, `D1b`, `D2`, `D3`, `S1` each printed with their detail).
* **~2 s wall clock** (2 s by `date`, 1.3 s by `time`), so T1's elapsed barely moves.
* All three readers agree: `run_suites.sh --nogui` → `PASS … ALL PASS (13 checks)`;
  `full_audit.sh test_untitled_autosave_1486` → `SUMMARY: 1 pass 0 fail 0 crash/timeout
  0 skip`, `SCRATCH: 0 leaked dir(s)`, `TREE: 0 appeared 0 vanished`.

### G2 needs nothing — measured, not assumed

`tests/headless/test_home_isolation.tcl` row **G2**, run in this tree with both new files
present:

```
ok: G2 … -- 717 scripts scanned, the whole repository. UNARMED: none. armed (25): …
```

**717** scanned (CLAUDE.md records 715 at round 4; the two new files are the difference),
**UNARMED: none**, and no allowlist entry matching nothing. `suite_cwd.sh` is not caught
because it **starts nothing**: its only `"$XSCHEM" --script` text is inside the usage
comment at the top, and G2 skips `^\s*#` lines. `test_untitled_autosave_1486.tcl` is
classified already (a `.tcl` that runs inside xschem and delegates to armed drivers).
`test_home_isolation` is `ALL PASS (116 checks)`, unchanged. **No arming and no allowlist
entry were added, and none is owed.**

---

## 5. Suites run, and the sabotage sweep

| suite | result |
|---|---|
| `test_regression_concurrency_1476` (`run_suites.sh --nogui`) | **`ALL PASS (46 checks)`** — was 44; V5g and V5h are the two new rows |
| `test_home_isolation` | `ALL PASS (116 checks)` |
| `test_audit_classifier` | `ALL PASS (75 checks)` |
| `test_untitled_autosave_1486` | `ALL PASS (13 checks)` — and `full_audit.sh`, and T1's own arm shape |

**Seven exact-string sabotages** (`/var/tmp/xsr_e2/E2/sabotage.py`), each applied to a
pristine `.orig` so none stacks on another, run in an `rsync` copy of `tests/` with `src`
symlinked (`/var/tmp/xsr_e2/E2/sab`; baseline there `ALL PASS (46 checks)`). **Every one
reddened exactly one row, the right one, and the other 45 stayed green in every run** — so
no pre-existing row of the suite is disturbed by this change.

| sabotage | rows it reddened |
|---|---|
| **S10** sentinel rewrite removed from `t1_carry_line` | `V5g` |
| **S11** skip-colon normalisation removed from `t1_carry_line` | `V5g` |
| **S12** banner-count fallback never used | `V5h` |
| **S13** a BARE completion banner is carried too | `V5h` |
| **S14** the COUNTED arm prints the raw line (pre-fix carry) | `V5g` |
| **S15** the SKIP arm prints the raw line (pre-fix carry) | `V5g` |
| **S16** the held `RESULT:`/banner line is printed raw | `V5g` |

The vacuity guard `V5z` is unchanged and still fires first if the fixture driver never
runs (E-impl's S9).

---

## 6. What the driver must update after the gate

**Read every number off `T1-RUN-END` and off the gate's own verdict; the figures below are
what to expect, not what to quote.**

* **Case count 87 → 88**, `blocks=` 86 → **87**, `planned_cases=` 88.
* **List lengths `3 / 73 / 11`** (`tcases` / `hcases` / `dcases`), taken by piping each
  `[list …]` block through `/usr/bin/grep -o '"[^"]*"' | wc -l`.
* **`wc -l` on a green verdict: 260.** Derived from a **measured** 87-block replay that
  includes the 1486 case's real log (`/var/tmp/xsr_e2/E2/corpus_88`), not from arithmetic
  on a sentence. The terms:

  ```
     2  sentinel lines (T1-RUN-BEGIN, T1-RUN-END)
  + 87  block header lines
  + 87  "Total num fail:" lines
  +  3  NOGOLD notes
  +  5  skip: lines               (issue 1487)
  + 74  RESULT: lines             (issue 1487; 73 + the new case's)
  +  2  OVERALL: ok (N checks)    (this fix round: the banner-only fallback)
  = 260
  ```

  ⚠ **Two of those terms are environment-dependent.** `skips=` is 5 on a box whose
  `XSCHEM_TEST_REAL_HOME` resolves the fork ngspice and **8** on one that does not (the
  stage-F gate's figure), and each extra skip is one more line. `wc -l` was already a poor
  constant to check against; it is worse now. The trailer states what matters.
* **`test_regression_concurrency_1476`'s floor: 44 → 46 checks.** CLAUDE.md does not quote
  that number, but the suite's own header does and has been updated.
* **The `skips=` field, the `NOTE:` line and the uncounted-lines bullet** are E-impl's and
  already written; this round adds no new trailer field.

---

## 7. Found outside the item (filed here, not fixed)

1. ⚠ **`tests/run_regression.tcl` is the one driver item F did NOT arm with `suite_cwd`,
   and registering this guard into T1 does not change that.** `run_suites.sh`,
   `full_audit.sh` and `gated_xschem.sh` each arm a private `$PWD`; T1 does not, so a T1
   run still writes `untitled~.sch` into `tests/`. **Measured:** `tests/untitled~.sch`
   exists in this tree with mtime **2026-09-20 21:42:19**, inside the window of E-impl's
   own gate run. Row `S1` of the 1486 suite checks the three shell drivers only and is
   structurally blind to the Tcl one. **Not fixed here**: it is item F's subject, it needs
   a Tcl port of `suite_cwd.sh` or `env PWD=` on four `exec` sites, and changing `$PWD` for
   all 88 cases needs a sweep this round has no budget for. It belongs with 0609/1480.
2. **`full_audit.sh` still drops per-row `skip:` lines** — E-impl's finding 1, unchanged
   and re-confirmed: its `SUMMARY:` line cannot say what was not measured. Same class as
   1487 in a different reader.
3. **The `t1_carry_line` guard is not total**, by construction: a carried line from the
   counted or `NOGOLD` arm with no whitespace at all and ending in `.log` would still wear
   the block-header shape. No emitter is near that shape; it is written into the proc's
   comment rather than left implicit.

---

## 8. What I did NOT do

* **No T1 run.** The driver gates, solo, and a number taken here would measure a tree with
  two items' uncommitted work and another crew's binary in it. The corpus replay in §1 is
  the controlled substitute and is faithful to the last real gate's `wc -l` byte for byte.
* **No change to `banner_rule.tcl` or to either shell reader.** The fallback consumes the
  shared rule rather than re-spelling it, so section K of `test_audit_classifier` has
  nothing new to lock (re-run green regardless).
* **No change to item F's logic.** The only edit to `test_untitled_autosave_1486.tcl` is
  the completion banner the registration requires, with the measurement that forced it in
  the comment beside it.
