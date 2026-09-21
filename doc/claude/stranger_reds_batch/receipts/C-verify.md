# C-verify — adversarial verification of item C (issues 1484 + 1490)

Lens: **is the defect really gone, in every shape a real path takes?**
Tree: `0eed8a1b` plus the working-tree edits listed in `C-impl.md` §6, rebuilt
(`make -C src` → "Nothing to be done", binary `src/xschem` of 16:43).
Scratch root `/var/tmp/xsr_c/v1`, deleted; peak **1.7 GB**.
Binaries: `/usr/bin/ngspice` 45.2 and the registry's fork
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (46+), both on every measurement
below unless stated.

**Verdict: the fix holds, and it holds much more widely than the receipt claims.
Two defects found, neither a regression against `HEAD`, both silent-or-false in
exactly the way this batch exists to stop.**

---

## 1. What I re-measured, and what it came back as

### 1.1 The mechanism — re-traced from scratch, not read off the receipt

Hand-written decks, ngspice run, filesystem inspected. Both faces reproduce exactly:

| deck said | ngspice wrote | rc | stderr |
|---|---|---|---|
| `wrs2p …/tr/Cap/o.s2p` (lowercase sibling present) | `…/tr/cap/o.s2p` | 0 | nothing |
| `set >> …/Cap/o.set`, `wrnodev …/Cap/o.nodev` | `…/cap/o.set`, `…/cap/o.nodev` | 0 | nothing |
| `write …/Cap/o.raw`, `echo … >> …/Cap/o.echo` | `…/Cap/…` (correct) | 0 | — |
| `wrs2p …/tr/w s/o.s2p` + `write …/tr/w s/o.raw` | ONE file `…/tr/w`, 652 B | 0 | nothing |

So: **case folding on the non-whitelisted commands, word splitting on all of them.**
The receipt's table is correct row for row.

**The ngspice READ is correct verbatim.** `src/frontend/inpcom.c:2209-2222` is the
whitelist (`.lib`, `.inc`, then under `comfile || is_control || starhash`: `write`,
`wrdata`, `codemodel`, `osdi`, `pre_osdi`, `echo`, `shell`, `source`, `cd`, `load`,
`setcs`, `strcmp`, `strstr`); `:2179-2192` is the separate `>`-redirect exemption for
`print`/`eprint`/`eprvcd`/`asciiplot`. `wrs2p`, `set`, `meas`, `wrnodev` are on neither.

**The double-quote trap is real.** `wrs2p "<plain path>"`, `write "…"`, `wrnodev "…"`
in a directory with neither a capital nor a space: **rc 0, not one file written**, on
both binaries. The obvious remedy is a second silent defect; the receipt is right to
refuse it.

**The `setcs` + `$var` remedy works for the folded commands.** `set >>`, `wrnodev`,
`meas … >>` and `echo … >>` through `setcs p = '/…/Cap/…'` all landed in `Cap/`, with
`cap/` empty, on both binaries.

**`shell mv -f "$p" "$q"` works**, measured for a `w s` directory and an `O'Br`
directory, both binaries, tmp gone and final present.

### 1.2 The product consequence — measured independently, outside the suites

Base arm built by exporting `HEAD:src/ase.tcl` over a copy of `src/`; the same probe
script renders the deck through `ase::backend::ngspice::render_deck` and runs it.

| run directory | base (`HEAD`) | fix |
|---|---|---|
| `…/plain` | 3/3 artifacts, correct | 3/3 correct |
| `…/Cap` (lowercase sibling present) | s2p in **`…/cap/`** | 3/3 in `Cap/`, sibling empty |
| `…/w s` | everything collapsed into ONE file `…/w` | 3/3 in `w s/`, nothing beside |

rc 0 in all six. **Contents verified, not just existence:** the Touchstone export and
the `.raw` are **byte-identical across the three shapes** once the `!Generated`/`Date:`
timestamp line is dropped (s2p md5 `96b52864…`, raw md5 `1953effe…`), and the s2p is a
real `# Hz S RI R 50` 2-port with the deck's three frequency points.

**And the deck on an ordinary path is byte-identical to `HEAD`'s** (diff of the two
rendered `plain` decks with the root normalised: no difference).

### 1.3 The suites

All eleven touched suites, developer's condition, `run_suites.sh --nogui`:

`test_ase_sp_1452` **69** · `test_ase_meas_1443` **117** · `test_ase_events_1465` **88** ·
`test_ase_core` **675** · `test_ase_converge_1459` **76** · `test_ase_effective_1442` **97** ·
`test_ase_preflight` **242** · `test_ase_trnoise_1466` **80** · `test_ase_campaign_1462` **161** ·
`test_ase_optier_0963` **109** · `test_ase_simcaps_0948` **211** — **11/11 ALL PASS**.

The receipt's growth claim checks out against a `HEAD` export: `sp_1452` 58 → 69,
`meas_1443` 115 → 117, `events_1465` 87 → 88, `core` 675 → 675, `converge_1459` 76 → 76.

Capital scratch (`XSCHEM_TEST_SCRATCH=…/Cap`): `sp_1452` 69, `converge_1459` 76,
`core` 675 — all green.
Space scratch (`…/s p`): `sp_1452` 69, `core` 675, `meas_1443` 117,
`effective_1442` 97 green; `events_1465` 4 red (`CI2` `CI3` `CI6` `CI8`), which is
the `.include`/`.lib` class of §7.1 and not this call site.

`test_ase_trnoise_1466` at a space scratch is **18 FAILED on the fix and 18 FAILED on
`HEAD`** — confirming §7.4's "all red on the base".

### 1.4 T1, solo, independently

```
T1-RUN-BEGIN pid=868677 … planned_cases=87 home=throwaway
             binary=/home/analog/dev/xschem-claude/src/xschem canonical=results.log
T1-RUN-END   pid=868677 cases=87 blocks=86 counted_failures=0 elapsed=541s
```
87 `Start` / 87 `Finish`, **zero** `another regression run is live`, `wc -l` **177**,
86 `Total num fail:` lines, zero counted lines. The green shape exactly.

### 1.5 §7.1 re-measured, with one correction

`.include` / `.lib` pointing into a `w s` directory, ngspice 45.2:

| card | bare | `"…"` | `'…'` |
|---|---|---|---|
| `.include` | **rc 1** | rc 0 | **rc 0** |
| `.lib` | **rc 1** | **rc 1** | **rc 1** |

Both fail **loudly**, unlike the control lines. The receipt says *"Double quotes fix
`.include`"* — **single quotes fix it too**. `.lib` is unfixable by quoting, as stated.

§7.2 also stands: `ase::op_dump_reachable_dir` still refuses a capital or a space and
`src/op_annot.tcl` is untouched.

### 1.6 Refusals are not a regression

`{`, `$` and backquote were measured on **bare** `write` on the unfixed path: none of
the three lands the file (`{}` and `$` write nothing; the backquote **ran the text as a
command** and left a stray file `a`). So converting them into a named raise loses
nothing that ever worked, and the raise is loud at the product level —
`ase::run_deck` re-raises, `ase::ui::do_run` catches, `ase::ui::run_raised` echoes the
sentence and reddens the status segment.

---

## 2. Findings

### F1 — a path with a NEWLINE, TAB, CR, VT or FF is escaped and STILL silently lost

`path_bare_ok` rejects them (they are outside `[A-Za-z0-9_./-]`), so `path_quoted`
accepts them and emits `setcs v = '<path with a control character>'`. A newline **splits
the deck line in two**; a tab is not protected by ngspice's single quotes either.

Measured, both binaries, one directory per character, deck rendered by the real emitter:

| run directory | rc | artifacts in it | stray |
|---|---|---|---|
| `nl\nnl` | 0 | **none** | `…/sh3/nl`, 2680 B |
| `ta\tb` | 0 | **none** | none |
| `cr\rc` | 0 | **none** | none |
| `vt\x0bv` | 0 | **none** | none |
| `ff\x0cf` | 0 | **none** | none |

Nothing on stderr in any of them. **This is the same silent-loss signature as the defect
being fixed**, produced by the code that claims to have handled it. It is not a
regression — `HEAD` loses these too — but the fix's own contract says it does not.

`ase::op_dump_reachable_dir`, forty lines away in the same file, already refuses
`[ \t\n]`. The one-line fix is to widen `path_quoted`'s refusal regexp from
`[\$`\{\}]` to also cover control characters, by name, the way the other four are.
No encoding can carry a newline on a line-oriented format, so **refusal is the answer,
not a better quote.**

No T1 row sees this, and neither suite predicate (`cp_needs`, `ck_word`) can — both are
copies of `path_bare_ok`'s regexp, so they share its blind spot exactly.

### F2 — five rows go NEWLY RED for a tester whose path contains an apostrophe

`path_quoted` correctly falls back to double quotes for `'` (and I measured that it
works end to end on both binaries: `O'Brien`, `q'`, `O'Brien Designs`, `a'b"c` all
round-trip). The **suites' own expectations hard-code single quotes**.

Measured, same scratch shape (`/var/tmp/xsr_c/v1/O'Br*`), `HEAD` export vs this tree:

| suite | `HEAD` red rows | fix red rows | newly red |
|---|---|---|---|
| `test_ase_sp_1452` | `SE1` `SE2` `SE3` (×2 binaries) = 6 | `SL4` `CP1` `CP2` `CP3` = 4 | **`SL4` `CP1` `CP2` `CP3`** |
| `test_ase_events_1465` | 32 rows incl. `EE3..EE10` ×2 | 22 rows | **`EV1`** |
| `test_ase_preflight` | `PF220`, `PF220e` | `PF220e` | none |

The product half is a clear win — every end-to-end row (`SE1`–`SE3`, `EE3`–`EE10`,
`PF220`) goes **green**, which is the escape working. But `C-impl.md` §5's *"ZERO newly
red"* was measured only in capital and space trees; in an apostrophe tree it is **five
rows**, and every one of them is a **false** red: the deck is right and the expectation
is wrong. `EV1`'s own message says so —
`got {}` vs `exp {{setcs asevcd = '…/O'Br7/…'}}` while the emitter wrote `"…"`.

A stranger who unpacks into `~/O'Brien/xschem/` therefore sees four red rows in the one
suite whose subject is this defect. Fix: give `cp_want`/`ck_word`/`EV1`/`SL4` the same
quote-choice rule `path_quoted` uses (single unless the path holds `'`, then double).

### F3 — §7.1 is written down but not FILED

PLAN criterion 4 says a finding outside the item is *written down **and filed***.
`.include` with a space (rc 1) and `.lib` with a space (rc 1, no quoting helps) is a
**product** defect that stops a run outright for a user with models under
`/mnt/c/Users/Jane Doe/pdk/`, and it exists only in `C-impl.md` §7.1 — no issue file
mentions it (`/usr/bin/grep -rln 'Could not find include file' doc/claude/issues/`
finds nothing). The crew was told not to edit `doc/claude/`, so this is the driver's to
close, not a crew defect.

---

## 3. Shapes measured GOOD (deck rendered by the real emitter, run, filesystem asked)

Both binaries, one directory per shape, "GOOD" = the Touchstone export **and** the
results file in the directory the deck named, and nothing beside them:

`O'Brien` · `O'Brien Designs` · `q'` · `a'b"c` · `q"uote` · `br[k]` · `bs\x` ·
`Müller` · `日本語` · `-dash` · a **200-char** component · a **255-char** component ·
a 255-char component with a capital · `sp<space>xxx…` (253) · `bang!` · `semi;` ·
`star*` · `tilde~` · `pct%` · `hash#` · `amp&` · `pipe|` · `paren()` · `car^et` ·
`pl+us=eq,co:lon` · nested paths of total length **149 / 277 / 533 / 1045**.

Refused loudly, by name, and measured not to work bare on `HEAD` either:
`d$r` · ``b`q`` · `{br}` · `a'b\c` (apostrophe + backslash) · `bs\x` and `q"uote`
**on the shell line only** (`shell_word`).

Not only the checkout: the **cell name** carries the same shapes. `SpBench` in a
lowercase run directory escapes the folded `wrs2p` and leaves the whitelisted `write`
bare; `my cell` escapes everything; both land correctly on both binaries.

---

## 4. What I did not verify

* The receipt's **147 rows / 17 suites** space-tree census and **12 rows / 6 suites**
  capital census. Reproducing them needs three full checkouts; I verified the
  mechanism, the product and the per-suite behaviour instead.
* The eleven sabotages. I re-derived the same conclusion from the other direction:
  `HEAD`'s emitter reds `SE1`/`SE2`/`SE3` and `EE3`–`EE10` at an apostrophe path where
  the fix greens them, which is a non-vacuity demonstration on rows the implementer did
  not use.
* `test_ase_optier_0963 Z6` and `test_ase_variant_1470 OT1` in a capital tree (§5's two
  survivors) — not re-measured.

## 5. Housekeeping

Real `HOME` untouched (`~/.xschem` and `~/.xschem/recent_files` mtimes still Sep 17);
`:99` attached, never started or stopped by me; `~/.claude` and `~/dev/xschem-op-wcard`
not touched; nothing committed; no repo file changed. `/var/tmp/xsr_c` deleted,
peak **1.7 GB**.

---

# FIX-ROUND VERIFICATION — 2026-09-20

**Appended by the FIXER, below the adversarial verifier's receipt; nothing above this line
was changed.** This section records what happened to each of the ten findings above and to
the `completeness` verifier's seven, every one of them re-measured here before being acted
on. The full measurements are in `C-impl.md`'s **FIX ROUND** section; this is the verdict
list. `src/ase.tcl` after this round: md5 `973ffc3f1510254bc90dc92dd26ad285`.

## Verdicts

| # | finding | verdict | what happened |
|---|---|---|---|
| 1 | control characters escaped and still silently lost (`should`) | **CONFIRMED, FIXED** | Reproduced exactly: five run directories, rc 0, nothing on stderr, **zero** artifacts, a 2680-byte stray `…/nl` for the newline. `path_quoted` refuses all of them by name now; row **`CP5b`** pins it through `path_quoted` **and** `path_word`, and reddens on the revert. |
| 2 | five rows newly red at an apostrophe path (`should`) | **PARTLY CONFIRMED, FIXED — and the diagnosis of `EV1` was wrong** | The four `test_ase_sp_1452` rows are exactly as reported: **4 FAILED (65 passed)**, `SL4`/`CP1`/`CP2`/`CP3`, deck right and expectation wrong. Fixed by `cp_quoted`; now **ALL PASS (73)**. **`EV1` is not a quote mismatch.** `got {}` means the deck carries **no `setcs asevcd` line at all** — the event probe died on the fixture's `.lib`, measured: `.lib` with an apostrophe is rc 1 **bare, single-quoted and double-quoted**. `EV1` is red on `HEAD` too; the arm comparison is base **33 FAILED** against fix **21 FAILED**, i.e. **12 rows greened and none newly red**. `ev_pre` was widened anyway (it is the same rule and the sabotage reddens it), but the row's apostrophe red belongs to the `.lib` issue. |
| 3 | §7.1 written down but not FILED (`should`, process) | **CONFIRMED, LEFT FOR THE DRIVER** | Re-checked: no issue file mentions it. A crew may not edit `doc/claude/issues/`. It is in `C-impl.md` §F7.2 with two corrections to the original sentence (next row, and the `completeness` verifier's `.lib` finding). |
| 4 | "double quotes fix `.include`" (`nit`) | **CONFIRMED, CORRECTED** | Measured on both binaries with a **load-bearing** include (`.param rv` reaching the circuit): single quotes rc 0, double quotes rc 0, bare rc 1. Corrected in `C-impl.md` §F7.2. |
| 5 | apostrophe + double quote unpinned (`nit`) | **CONFIRMED, PINNED** | Re-measured with the exact emitter form (`setcs v = "/…/a'b"c/o.raw"`, an unescaped `"` inside the quoted word): rc 0 on both binaries, both artifacts in the named directory, nothing stray. Row **`CP5c`**. |
| 6 | `D1`'s golden is a tautology about the escape (`nit`) | **CONFIRMED, DOCUMENTED** | `D1` left as it is. Its comment and `ck_word`'s now say the second opinion covers the **rendering** and not the **predicate**, and name `CP5b` as the row that carries the predicate — which is precisely the axis finding 1 slipped through. |
| C1 | `opstate_lines`' `force` arm unquoted (`must`, completeness) | **CONFIRMED, FIXED** | Reproduced end to end on both binaries: `w s` run directory → `Could not find include file …/w`, rc 1, **no raw file at all**. Fixed with `.include [path_quoted $path]` behind `path_bare_ok … 0`. Now rc 0 and a raw file in all three shapes, with `plain` and `Cap` still bare. `WR4b` de-tautologised, **`WR4b2`** added. ⚠ **This also refutes `C-impl.md` §7.1's attribution of `EE5`**: reverting only this fix takes `test_ase_converge_1459` in a space tree from **ALL PASS (77)** to **4 FAILED** including `EE5/apt` and `EE5/fork`. |
| C2 | `test_ase_core` is not 675 in a space condition; `.lib` is fixable by a relative path (`must`, completeness) | **CONFIRMED, CORRECTED** | A space **checkout** gives `671+4` (`E1a` `E1b` `E1c` `E1f`) — a space **scratch** does not, because `$models` is `[file join $repo sky130A …]`. §5's space column corrected. Relative `.lib` re-measured green on both binaries, cwd inside the spaced directory **and** deck named by an absolute spaced path from elsewhere. **New:** quoting fixes `.lib` on the **fork (46+)** and not on 45.2 — "nothing fixes `.lib`" was true only of 45.2. |
| C3 | the CELL NAME is a trigger neither issue names (`should`, completeness) | **CONFIRMED, FIXED AND PINNED** | Measured at the product level, all-lowercase run directory, cell `LACGbench`: `HEAD` writes **three of six** artifacts as `lacgbench_ase.*`; the fix writes all six as asked. Row **`CP7`** runs the simulator on each binary and asks the filesystem for both the named and the folded spellings. §4's "byte for byte" now carries the caveat "and an all-lowercase cell name". |
| C4 | the refusal arrives mid-render, outside the refusal tier (`should`, completeness) | **CONFIRMED AS AN OBSERVATION, REJECTED FOR THIS ROUND** | The raise is real and the behaviour change is real. But `render_deck` already raises this way for four other refusal families, the raise is loud at the product level (§1.6 above), and there is **no global preflight refusal list** to add a rundir refusal to — `ase::ui::conv_refusals` is the Convergence dialog's own. Choosing where the user meets it is user-visible product design, not implementation. Recorded in `C-impl.md` §F7.3 as a deliberate silent-loss→hard-refusal change and handed to the driver. |
| C5a | `ase::op_dump_reachable_dir` incomplete (`nit`, completeness) | **CONFIRMED, FIXED** | `show all > /…/my$dir/f.txt` → `Error: dir: no such variable.`, rc 0, nothing written; **and** `/…/o'b/f.txt` the same, which the finding did not have. The guard routes through `path_bare_ok $dir 1` now, so guard and escape are one rule. Row **`X4b`**. Refusing costs only the fast shape. |
| C5b | `event_probe` is a second deck builder (`nit`, completeness) | **CONFIRMED, DOCUMENTED** | A comment in `src/ase.tcl` names it as the second emitter of the same cards and says any `.include` quoting must land in both. The `pre_commands` `$::VAR` word-split is READ, not measured, and is handed to the driver with that provenance. |
| C5c | duplicated `setcs` lines (`nit`, completeness) | **REJECTED** | Cosmetic, and rows in several suites pin deck line **positions** (`CK13c` reads a window of four consecutive lines). Not worth the blast radius in a capped round. |

## What I measured independently of the findings

* **The three-shape row list, re-run from three real checkouts** (`/var/tmp/xsr_c/{plain,Cap,w s}/x`), 14 suites each: plain **14/14 ALL PASS**; `Cap` green but for `OT1`, `Z6` and one `NORESULT`; space as §7.4 predicts plus the corrected `test_ase_core`. Table in `C-impl.md` §F3.
* **The product export in all three shapes**, `HEAD`'s emitter against this one, six artifacts: base **6 / 3 / 1**, fix **6 / 6 / 6**, rc 0 throughout.
* **`.include` quoting per character**, 26 directories, bare vs `'…'` vs `"…"`, load-bearing, both binaries. The result that makes `C1` safe: **no character for which the new quoting is worse than bare**, except a path carrying `'` and `"` at once — which fails loudly.
* **⚠ A NEW STRANGER FINDING: `test_op_dump_altshow` DIES in a capital checkout** — `NORESULT (exit 0 — binary never reported)`, `op_annot` raising on a dump ngspice folded into `…/cap/…`. **Measured identically with `HEAD:src/ase.tcl` in the same tree**, so it is pre-existing. It is a **seventh** suite for issue 1484, it is **not a T1 case**, and its shape is a suite **death**, not a red — the one shape a green T1 cannot see. For the driver.
* **Each product change reverted on its own** and the suites re-run, so every new row is shown non-vacuous and every space-tree red is shown pre-existing. Table in `C-impl.md` §F4; the three edited files verified byte-identical after each.

## Housekeeping (fix round)

Scratch `/var/tmp/xsr_c`, peak **1.30 GiB** (`du -sb` 1 393 668 247 B), **deleted**. Real
`HOME` untouched — `~/.xschem` and `~/.xschem/recent_files` still carry their Sep 17 mtimes;
`~/.claude/xschem_dev_display` still Sep 20 14:37, from before this session. The dev display
`:99` was never started or stopped; every suite ran with `AUDIT_DISPLAY=none` through
`run_suites.sh`, which arms a throwaway HOME. `~/dev/xschem-op-wcard` not touched;
`~/dev/ngspice` read only. Nothing committed. Files changed are the six listed in
`C-impl.md` §F6 (five of them already `M` before this round; `tests/headless/test_op_dump_altshow.tcl`
is the one new entry in `git status`).
