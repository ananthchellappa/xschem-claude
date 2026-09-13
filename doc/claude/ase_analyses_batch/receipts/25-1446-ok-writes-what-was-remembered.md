# Issue 1446 — OK writes what the dialog remembered

**One task, issue 1446, Option B.** ⚖ R5 (issue 1445, commit `0d5f16b1`) made the
Choose Analyses form **remember** what you typed. It did not change what OK **reads**.
A value typed under `▸ Advanced` and then folded away was remembered — unfold and it
is there — and **silently not committed**, because `ase::ui::chana_ok` read the LIVE
widgets and `chana_adv_toggle` rebuilds through `chana_show`, which does
`destroy $w.form`. OK now reads the visible type's live widgets **merged over that
type's cache**. Same type, same row, one write.

⚠ **THE USER HAS NOT RULED.** The rule debt is standing (`owed.sh list` → `[1446]`,
0d old) and this is the *recommended* shape built ahead of the answer. It was kept
small and separable on purpose: **one new proc, one changed line**, its rows, and the
issue-file update. A ruling of **A** reverts it with `git checkout` of two hunks.

**Files changed** (tree left dirty; the driver commits):

| file | what |
|---|---|
| `src/ase_window.tcl` | one new proc + one changed reader line (9503 → **9547**, +44, 12 of them code) |
| `tests/headless/test_ase_dialogs.tcl` | section **GR6**, nine rows, display arm; header index + floor paragraph; one amended comment on `GN7b` (+369) |
| `doc/claude/issues/1446-a-value-the-dialog-remembered-and-ok-did-not-write.md` | the *What landed* section |
| this receipt | new |

**Nothing else.** The five files the other crew holds were never opened for writing;
`src/ase.tcl` was read only as `git show HEAD:src/ase.tcl`. `run_regression.tcl` was
not run (T1 is the driver's, solo, issue 0990). No `git add`, no commit.

⚠ **HEAD MOVED UNDER THIS TASK AND IT DOES NOT AFFECT THE NUMBERS.** The driver
committed the other crew's work mid-task (`0d5f16b1` → `1cc37ae6`), which is why
`git status` no longer lists `src/ase.tcl` et al. Both files this task touches are
**byte-identical at the new HEAD** to what the baseline was taken against —
`git show HEAD:src/ase_window.tcl | md5sum` = `4368262a…`, `…test_ase_dialogs.tcl` =
`f4611b03…`, the two md5s recorded at the start — so the before/after below is a
measurement of this change and of nothing else.

⚠ **AND `src/ase.tcl` WENT DIRTY AGAIN AT 08:51:13, AFTER EVERY MEASUREMENT HERE WAS
TAKEN.** The other crew resumed (+290 lines, none of them this change —
`git diff src/ase.tcl | grep -c chana_commit_vals` → `0`). My last write was 08:46:45
and my last suite run preceded it, so every number in this receipt was measured against
the `src/ase.tcl` at HEAD (md5 `614c3836…`). **A driver re-running §8 now is running
their in-progress file too**, which is the ordinary hazard of a shared clone: re-measure
rather than diffing against these numbers.

---

## 1. What changed, with anchors

| anchor | change |
|---|---|
| `ase::ui::chana_commit_vals` (`:5374`, between `chana_form_vals` and `chana_merged_row`) | **new**. The type's cache, filtered to that type's declared field names, with the live form merged **over** it |
| `ase::ui::chana_ok` (`:5460`, the `set vals` line after `set en`) | reads `chana_commit_vals` instead of `chana_form_vals`. **The only behavioural line in the diff** |

```tcl
proc ase::ui::chana_commit_vals {key type sim} {
  variable dlg
  set vals [dict create]
  if {$type ne {} && [info exists dlg($key,anedit,$type)]} {
    set cached $dlg($key,anedit,$type)
    foreach f [ase::ui::chana_fields $type $sim] {
      if {[dict exists $cached $f]} { dict set vals $f [dict get $cached $f] }
    }
  }
  return [dict merge $vals [ase::ui::chana_form_vals $key $type $sim]]
}
```

`git diff -U0 src/ase_window.tcl | grep '^+' | grep -v '^+#'` prints **12 lines**, all
of them above: no new state key, no schema change, **no new string literal**, and the
cache procs' contract untouched. `chana_ok`'s D6 probe reads the same `vals`, so the
commit door judges what it is about to store rather than a subset of it.

**CAN ONE OK NOW WRITE TWO TYPES? NO, AND IT IS A ROW AND NOT A SENTENCE.** **GR6e**
presses OK on `ac` with a folded `tran` edit **sitting in the cache and proven present**
(term 1 prints `tmax 7n`), and then asks for (a) the `ac` row written, (b) **no other
type's field name in it** — `[dict exists $R6E_AC tmax]` → 0 — and (c) **every other
row of the bench back byte for byte**. Sabotage **s6** (OK commits every cached type,
the issue's option C) reddens it, together with ⚖ R5's own `GR5g`.

---

## 2. Suite counts, from the `RESULT:` line

`tests/headless/test_ase_dialogs.tcl`, both arms, each under a hard timeout:

| arm | before this task | after |
|---|---|---|
| headless (`timeout 400 ./src/xschem --nogui --pipe -q --nolog`) | `RESULT: ALL PASS (37 checks)` | `RESULT: ALL PASS (37 checks)` |
| display (`timeout 500 devdisplay.sh exec ./src/xschem --pipe -q --nolog`) | `RESULT: 1 FAILED (312 passed)` | `RESULT: 1 FAILED (321 passed)` |

**313 → 322 on the display arm; headless unmoved at 37**, for GR5's reason — every GR6
row drives widgets and there is no schema half. Floor paragraph (`37 / 322`) and header
index (`GR6a-h`) both updated in the same edit.

⚠ **THE ONE RED IS `G2sens`, ISSUE 1436, AND IT IS NOT MINE.** Measured **before**
touching anything, with the identical actual value the driver's baseline and issue
1436 both record: `{1 1 0 1 0 Entry Entry normal}`. `GG9` passed on every run today,
as it did for receipt 24 — the file's own paragraph predicts that (its premise needs a
cold capability cache). So: **one red, the same one, before and after.**

**The three other suites in the tree that drive this dialog** and are not held by the
other crew, both arms — identical to receipt 24's numbers:

| suite | headless | display |
|---|---|---|
| `test_ase_optsheet_1441` | `ALL PASS (62 checks)` | `ALL PASS (87 checks)` |
| `test_ase_interact` | `ALL PASS (10 checks)` | `ALL PASS (64 checks)` |
| `test_ase_simcaps_0948` | `ALL PASS (199 checks)` | `ALL PASS (199 checks)` |

**The stock-binary rule does not apply and this says so instead of testing twice.**
Every row here is pure Tcl on the dialog's read path; nothing in this change reaches
what ASE-L emits, and no suite run for it starts a simulator.

---

## 3. The `.state` byte-identity measurement

**(a) The corpus round-trips.** All 104 tracked `.state` files, `ase::state_load`ed and
re-written with `ase::state_save` into a scratch directory, compared **byte for byte**:

```
$ git ls-files -- '*.state' | wc -l
104
$ timeout 300 ./src/xschem --nogui --pipe -q --nolog --script /tmp/state_roundtrip_1446.tcl
STATE-ROUNDTRIP-1446: 104 files, 0 differ
```

```
$ git status --porcelain -- '*.state'
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/tb_bandgap.state
```
— untracked, pre-existing at session start, not mine. **Zero tracked `.state` files
modified.**

**(b) The dialog writes the same bytes, which is the question this change could break.**
Row **GR6f**: snapshot `ase::state_serialize`, open Choose Analyses, invoke **all
eleven** grid cells and fold `▸ Advanced` **open and shut on each one**, select `ac`,
press OK, compare. Equal. The merge adds nothing because the cache holds only what was
**touched** (⚖ R5's rule, `GR5f`) and nothing here was.

---

## 4. Sabotage — eight mutations, generator at `/tmp/sab1446.py`

Every arm: `python3 /tmp/sab1446.py <id>` writes the mutant from a pristine copy → run
the display arm under `timeout 500` → restore by `cp` → md5 compare. Final compare,
printed:

```
84305618cc6a66c6825bf7c2734cc6cd  src/ase_window.tcl
84305618cc6a66c6825bf7c2734cc6cd  /tmp/ase_window.1446fixed.tcl
```

| # | what I broke | `RESULT:` | rows that reddened (beyond the standing `G2sens`) |
|---|---|---|---|
| **s1** | the merge removed — `chana_commit_vals` is `chana_form_vals` again | `5 FAILED (317 passed)` | GR6a GR6b GR6c GR6h |
| **s2** | a merged value no longer goes through `ase::ui::form_is_absent` | `11 FAILED (311 passed)` | GR6b GR6c **GR6f** + **G2c G2g G2h G2pz** |
| **s3a** | the merge takes another type's cache (field filter intact) | `4 FAILED (318 passed)` | GR6a GR6c GR6h |
| **s3b** | the same, and unfiltered | `4 FAILED (318 passed)` | GR6a GR6c GR6h |
| **s3c** | the merge takes the **last** cache, unfiltered — a foreign type's field leaks in | `4 FAILED (318 passed)` | GR6b **GR6e** GR6g |
| **s4** | live-widget precedence inverted — the cache wins over a standing widget | `2 FAILED (320 passed)` | GR6d |
| **s5** | the merge not filtered to this type's fields, so cached `enabled` leaks | `2 FAILED (320 passed)` | GR6g |
| **s6** | OK commits **every cached type** — the issue's option C, the D4 widening | `3 FAILED (319 passed)` | **GR5g** GR6e |

**Every GR6 row has at least one witness**: a s1/s3a/s3b, b s1/s2/s3c, c s1/s2/s3a/s3b,
d s4, e s3c/s6, f s2, g s3c/s5, h s1/s3a/s3b. **s6 reddens an EXISTING row** (`GR5g`,
⚖ R5's own D4 guard) — a feature whose only witnesses are its own new rows is a feature
nothing else in the tree is watching. **s2 reddens four rows from three earlier
sections** (`G2c G2g G2h G2pz`), which is the write-back rule being load-bearing well
outside this change.

### ⚠ One of my rows could not fail, and the fix is also a finding about `GR5k`

**Failure mode #1, in my own first cut.** GR6f was written as GR5k is — click every
cell, press OK **on `op`** — and it passed under **all eight** mutations. `op` has no
fields at all, so `chana_ok` writes nothing whatever the reader answers. It now presses
OK on **`ac`**, whose `sweep` is a `mode` field the form resolves to its `default dec`
at build time (`chana_field_row`'s combobox arm does resolve defaults; the entry arm
does not), so the form offers a value **no bench stores** — one of the two measured
cases in the write-back rule's own comment. With `form_is_absent` bypassed it now goes
red on `sweep dec`.

⚠ **`GR5k` HAS THE SAME HOLE AND IT IS NOT MINE TO CHANGE.** It presses OK on `op` for
a stated reason (a type with no stored row appends a disabled one), and `ac` satisfies
that reason as well as `op` does while actually having fields. Flagged for the driver.

### ⚠ A wrong-type cache is nearly inert, and the reason is worth keeping

s3a and s3b reddened **only** through the dialog's *initial* type: `choose_analyses`
preselects `op`, the first `chana_show` after it creates `anedit,op` as an **empty**
dict, and `lsort` puts `op` before `tran` — so "take the lexically first cache" takes
an empty one and the merge stops happening. The **foreign-key leak** needed **s3c**
(last cache, unfiltered) to appear at all, because with the field filter in place a
foreign cache can only supply field names the committed type also declares, and
**today no two analysis types share an `advanced 1` field name** (`tran` has
`tstart/tmax/uic`, `dc` `source2/start2/stop2/step2`, `noise` `contributors/ptssum`,
`disto` `f2overf1`) while every shared name (`stop`, `points`, `start`) is a visible
widget the live form wins on. **The field filter is what makes it harmless**, and
GR6e's third term is the row that says so.

---

## 5. Corrections to the brief

1. ⚠ **`chana_cache_apply` IS THE WRONG DIRECTION FOR THE COMMIT, and both the brief's
   §1 and the issue's option table name it.** `chana_cache_apply` is
   `dict merge $row $cache` — the **cache wins** — which is right for repopulating a
   form and wrong for OK: the brief's own trap 4 requires the **live widget** to win
   (typed, folded, unfolded, retyped). The commit needs `dict merge <cache> <live>`, a
   different merge, so this is a **new reader** rather than a reuse of that proc. Row
   GR6d, sabotage s4.
2. ⚠ **THE CACHE CONTAINS `enabled`, WHICH IS NOT A FIELD** — `chana_cache_save` stores
   it beside the fields (⚖ R5's `GR5j`) — and `chana_ok` owns that key itself from the
   live `anen`. A bare `dict merge` of the cache therefore hands the commit door a
   **stale Enable** that is written *after* `dict set row enabled $en`: tick the box,
   fold the disclosure, untick it, press OK, and the bench says ON while the box says
   OFF. Not in the brief's trap list. That is why the reader answers in **fields**;
   row GR6g, sabotage s5.
3. **The brief's baseline is exact.** headless `ALL PASS (37 checks)`, display
   `1 FAILED (312 passed)` with `G2sens` the only red and the identical actual value;
   `GG9` passed. Measured before any edit.
4. **A minimum-sabotage list of four was one short in the same way receipt 24's was.**
   The four named (merge removed, no `form_is_absent`, wrong cache, precedence
   inverted) leave the `enabled` leak and the multi-type widening unwitnessed — s5 and
   s6 — and the "wrong cache" one is nearly inert on its own (see §4).
5. ⚠ **READING `dlg($key,anen)` AFTER OK RAISES, AND IT KILLS THE FILE RATHER THAN
   REDDENING A ROW.** `chana_ok` ends in `chana_cancel`, which `array unset`s `anen`;
   the raise lands in the display block's outer `catch` and prints
   `UNEXPECTED ERROR: can't read "…,anen": no such element in array`, losing every row
   after it — measured, `2 FAILED (319 passed)` with GR6h simply absent. This is G2tf's
   documented failure shape, met again by a different route. Capture live dialog state
   **before** pressing OK.

---

## 6. Debts

* **No new user-facing sentence.** The whole diff of `src/ase_window.tcl` is 12 code
  lines and comments; no label, status line, refusal or banner text was minted. **No
  `owed.sh add rule` for copy.**
* **The ruling debt for the change itself already stands** — `owed.sh list` shows
  `[1446] … OK writes live widgets only: a folded Advanced field is remembered and not
  committed`, filed by the driver. **Not cleared, not touched**; only the user clears a
  rule.
* **No `look` debt.** No new widget and nothing newly drawn — the only user-visible
  difference is which value an existing row receives. Same call as receipt 24's.
* **A suite debt is arguable and I did not file one**: the GR6 rows ran on the dev
  display (`:99`, openbox live, `AUDIT_SCREEN` default), where this batch's GUI rows
  live. If the driver wants the `:0` pass CLAUDE.md asks for before calling a GUI
  feature done, `owed.sh add suite test_ase_dialogs` is the line — flagged rather than
  filed, because it is the driver's batching call and receipt 24 left the same one open.

---

## 7. The residual, named

`ase::ui::chana_merged_row` — the **precondition banner**'s reader, issue 1435 — was
left reading the live form alone. With a folded edit in the cache it therefore judges
the **stored** value while OK now writes the **remembered** one. **Row GR6h pins the
divergence**, and `GN7b`'s comment gained the exception rather than being left to read
falsely.

It changes **no sentence today**: `ase::precheck_banner` → `ase::analysis_needs`, and
no `needs` rule in the ngspice adapter reads an `advanced 1` field. It was left out
because issue 1446 is a change to the commit door that the user has not ruled on, and
widening a second surface with it would make the revert two features wide. **If the
ruling is B, closing it is one line** — `chana_merged_row` reads `chana_commit_vals`
too — and GR6h goes red to say it happened.

---

## 8. Commands, for the driver to re-run

```sh
cd /home/analog/dev/xschem-claude
timeout 400 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl
timeout 500 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl
timeout 300 ./src/xschem --nogui --pipe -q --nolog --script /tmp/state_roundtrip_1446.tcl
```
