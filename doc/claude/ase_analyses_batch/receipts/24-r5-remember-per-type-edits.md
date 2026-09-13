# ⚖ R5 — the form remembers: per-type edits survive a click across the grid

**One task, issue 1445.** Scope was ⚖ **R5** of `DECISIONS.md` and nothing else. This is
the **first ruling in this batch that changes behaviour rather than ratifying it** — R1–R4
all landed on what the tree already did, and R5's recommendation was D4's opposite.

**Files changed** (tree left dirty; the driver commits):

| file | what |
|---|---|
| `src/ase_window.tcl` | three new procs + four call sites + the `chana_show` comment rewrite |
| `tests/headless/test_ase_dialogs.tcl` | section **GR5**, twelve rows, display arm; header index + floor paragraph |
| `doc/claude/issues/1445-the-form-forgot-what-you-typed-the-moment-you-clicked-another-analysis.md` | new |
| `doc/claude/issues/NUMBERING.md` | the 1445 entry, pointer 1445 → 1446 |
| this receipt | new |

**Nothing else.** `git status --porcelain` still shows `src/ase.tcl`,
`tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_persist.tcl`,
`tests/run_regression.tcl` and `tests/headless/test_ase_meas_1443.tcl` exactly as this task
found them — the other crew's, untouched, never `git add`ed. `run_regression.tcl` was not
run (T1 is the driver's, solo, issue 0990).

---

## 1. What changed, with anchors

`src/ase_window.tcl`, **9364 → 9503 lines** (+139, of which roughly 100 are comment).

| anchor | change |
|---|---|
| `:4748-4771` | the `chana_show` repopulate comment **rewritten** to describe what the code now does. It still names the reversed decision and its reason, and it still says the D4 in question is `doc/claude/ase_l_batch/prompts/item07_dialogs.md`'s and **not** `ase_analyses_batch/DECISIONS.md`'s |
| `:4734` | `choose_analyses` → `ase::ui::chana_cache_clear $key`, immediately after `dialog_frame`. **This is the load-bearing clear** — see §5 sabotage `e` |
| `:5112` | `ase::ui::chana_cache_clear` |
| `:5136` | `ase::ui::chana_cache_save` |
| `:5169` | `ase::ui::chana_cache_apply` |
| `:5215` | `chana_show` saves **before** `catch {destroy $w.form}` |
| `:5224`, `:5229` | `chana_show` sets `anshown` and empties `anbuilt` before building |
| `:5234` | `chana_show` builds from `chana_cache_apply … [chana_row …]` instead of `chana_row` alone |
| `:5317-5318` | `chana_show` snapshots `anbuilt` after the relabel pass |
| `:5502` | `chana_cancel` → `chana_cache_clear` |

**State:** `dlg($key,anedit,<type>)` (one dict per type), `dlg($key,anshown)`,
`dlg($key,anbuilt)`. Array slots on the existing `ase::ui::dlg`. **No new state key, no
schema change, nothing serialised**, and `ase::ui::close`'s `array unset dlg $key,*` already
covers all three.

Two design points worth the driver's eye:

* **The save goes in `chana_show`, not on the radiobutton's `-command`.** That is the one
  door every rebuild comes through — and it means `chana_adv_toggle` is covered too. Folding
  `▸ Advanced` open or shut discarded the form exactly as thoroughly as a radio click did;
  nobody had reported it because nobody thinks to type and *then* toggle. Rows GR5e and
  GR5l.
* **It saves under `anshown`, not `antype`.** Tk sets a radiobutton's `-variable` *before*
  it runs `-command`, so at save time `antype` is already the type being switched **to**.

---

## 2. ⚠ THE CORRECTION THAT MATTERS: IT REMEMBERS WHAT WAS **TOUCHED**, NOT WHAT WAS ON SCREEN

The brief's §2 mechanism facts are all correct as written, and the obvious implementation
they suggest — cache `chana_form_vals` for the outgoing type — **is wrong, measured**.

I built it that way first. The display arm reddened an **existing** row:

```
FAIL: GN7b the merged row overlays the form on the STORED row, so a hidden advanced
      field is not lost -- and it really is hidden -> {1 0 2n LOST} (exp {1 0 2n 1n})
```

The red was correct. `step` had been shown empty on an earlier visit to `tran` and never
typed into; caching "what was on screen" cached `step {}`, and the overlay then **deleted a
stored `step 1n`**. A cache that remembers the dialog's own defaults is a cache that
overwrites the file with them.

So `chana_cache_save` diffs the live form against `dlg($key,anbuilt)` — the snapshot taken
at the end of every build — and stores only the differences. **This is also what makes the
byte-identity constraint hold rather than merely survive**: the brief warns that "a cache
that re-supplied a value the user never typed would defeat `form_is_absent`", and the
touched-only rule means such a value never enters the cache at all. Sabotage **f** is that
paragraph as a mutation, and it reds GN7b again plus GR5f.

⚠ **The brief's warning was exactly right about the failure and understated where it
bites.** It named `form_is_absent` and the commit; the first thing the naive cache actually
broke was the *form*, one step earlier, by deleting a stored value on the way in.

---

## 3. Suite counts, from the `RESULT:` line

`tests/headless/test_ase_dialogs.tcl`, both arms, each under `timeout 300`:

| arm | before this task | after |
|---|---|---|
| headless (`./src/xschem --nogui --pipe -q --nolog`) | `RESULT: ALL PASS (37 checks)` | `RESULT: ALL PASS (37 checks)` |
| display (`devdisplay.sh exec ./src/xschem --pipe -q --nolog`) | `RESULT: 1 FAILED (299 passed)` | `RESULT: 1 FAILED (312 passed)` |

**300 → 313 on the display arm; headless unmoved at 37**, because every GR5 row drives
widgets and there is no schema half at all — that *is* the point of the change. Floor
paragraph and header index both updated in the same edit.

⚠ **THE ONE RED IS PRE-EXISTING AND IT IS NOT MINE.** `G2sens`, issue **1436**. I measured
the arm **before** touching anything and it was already there, with the identical actual
value `{1 1 0 1 0 Entry Entry normal}`. **The file's own paragraph says TWO rows are red on
this arm**; on every run I took today `GG9` **passed**, which is consistent with what that
paragraph already says about it — its premise depends on whether the capability cache is
warm, which is environmental. So: **one red today, not two, and the difference is the
environment and not this change.**

**The four other suites in the tree that drive the Choose Analyses dialog**
(`grep -ln chana tests/headless/*.tcl`, minus the two the other crew holds), both arms:

| suite | headless | display |
|---|---|---|
| `test_ase_optsheet_1441` | `ALL PASS (62 checks)` | `ALL PASS (87 checks)` |
| `test_ase_interact` | `ALL PASS (10 checks)` | `ALL PASS (64 checks)` |
| `test_ase_simcaps_0948` | `ALL PASS (199 checks)` | `ALL PASS (199 checks)` |

`test_ase_core.tcl` and `test_ase_persist.tcl` also drive it and were **not run**: the other
crew holds them and a concurrent run of the same suite shares its scratch directory.

---

## 4. The `.state` byte-identity measurement

Two measurements, because they answer different questions.

**(a) The corpus round-trips.** All 104 tracked `.state` files, loaded with
`ase::state_load` and re-written with `ase::state_save` into a scratch directory,
`md5sum`-compared:

```
$ timeout 300 ./src/xschem --nogui --pipe -q --nolog --script /tmp/state_roundtrip.tcl
STATE-ROUNDTRIP: 104 files, 0 differ
```

```
$ git status --porcelain -- '*.state'
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/tb_bandgap.state
```
— untracked, pre-existing at session start, not mine. **Zero tracked `.state` files
modified.**

**(b) The dialog writes the same bytes, which is the question this change could actually
break.** Row **GR5k** on the display arm: snapshot `ase::state_serialize`, open Choose
Analyses, `invoke` **all eleven** grid cells in turn, select `op`, press OK, and compare.
Equal. ⚠ OK is pressed on `op` because the bench carries an `op` row: pressing it on a type
with no stored row **appends a disabled row**, which is the shipped behaviour of the commit
door and not what this row is about.

Sabotage **c** (apply replaces instead of merging) reds **GR5k**, so the row is not vacuous.

---

## 5. Sabotage — nine mutations, generator at `/tmp/sab.py`

Every arm: `cp /tmp/ase_window.fixed.tcl src/ase_window.tcl` → apply → run the display arm
under `timeout 300` → restore by `cp` → `md5sum` compare. Final compare, printed:

```
4368262a5d85c6614ae9d334b4a591cd  src/ase_window.tcl
4368262a5d85c6614ae9d334b4a591cd  /tmp/ase_window.fixed.tcl
```

| # | what I broke | `RESULT:` | rows that reddened (beyond the standing `G2sens`) |
|---|---|---|---|
| **a** | `chana_cache_save` returns immediately — the cache never saves | `9 FAILED (304 passed)` | GR5a GR5d GR5e GR5f GR5h GR5i GR5j GR5l |
| **b** | `chana_cache_apply` returns `$row` — the cache never restores | `6 FAILED (307 passed)` | GR5a GR5d GR5e GR5j GR5l |
| **c** | apply **replaces** the stored row with the cache | `6 FAILED (307 passed)` | **GN7b** GR5c GR5d GR5k GR5l |
| **c2** | save **replaces** the type's earlier cache instead of merging | `3 FAILED (310 passed)` | GR5e GR5l |
| **c3** | one cache for the dialog instead of one per type | `6 FAILED (307 passed)` | GR5b GR5f GR5h GR5i GR5j |
| **d** | OK also commits the cached **non-visible** types | `2 FAILED (311 passed)` | GR5g |
| **e** | no `chana_cache_clear` when the dialog **opens** | `3 FAILED (310 passed)` | GR5f GR5i |
| **e2** | no `chana_cache_clear` on **Cancel** | `2 FAILED (311 passed)` | GR5h |
| **f** | the cache records every live value, not only what was touched | `3 FAILED (310 passed)` | **GN7b** GR5f |

Notes the driver should read rather than skim:

* **`e` and `e2` are complementary, and neither covers for the other.** Dropping the
  open-time clear reds **GR5i** and leaves GR5h green; dropping the Cancel clear reds
  **GR5h** and leaves GR5i green. The window manager's close button runs none of our close
  paths, which is why the open-time clear cannot be argued away.
* **Two sabotages redden an EXISTING row, `GN7b`** (issue 1435's). A feature whose only
  witnesses are its own new rows is a feature nothing else in the tree is watching.
* **`c2` exists because the brief's sabotage (c) only named the apply side.** There are
  **two** merges in this feature and the save-side one had no row until I wrote `GR5l` for
  it — that is the brief's own failure mode #4, *a sabotage missing from the generator
  entirely*, caught by asking "what else is a merge here".

### ⚠ Two of my own rows could not fail, and I found it by asking rather than by running

**Failure mode #1, in my own first cut.** GR5h and GR5i originally typed `500u` into `tran`
and then closed the dialog. `chana_cache_save` only runs on a **rebuild** — so nothing had
ever entered the cache, and both rows would have passed with **every clear removed**. Both
now click the `ac` cell first to force the save, and both carry a positive control
(`R5H_CACHED` / `R5I_CACHED`) proving the cache was non-empty at the moment of the close.
Sabotage **a** confirms it: with saving disabled, those two controls go to `0` and **both
rows red**.

**Positive controls elsewhere, per failure mode #3.** `GR5f`'s second term proves the cache
extractor returns something when it should, so its first term's emptiness is a measurement
and not a broken reader. `GR5a`, `GR5b`, `GR5g` and `GR5l` each carry an explicit
`expr {$x ne $y}` term proving the two fixtures **differ** — `tran` gets `stop 1u`, `ac` gets
`stop 1meg`, two different values under the **same field name**, which is what lets GR5b say
the cache is per type and not per field.

---

## 6. The residual case — measured, named, not fixed

**The one the brief asked about.** Type `500u` into `tran`, click `ac`, type `2meg` into
`ac`, press OK. Measured (this is row **GR5g** verbatim): the bench's `ac` row gets
`stop 2meg`, the bench's `tran` row still reads `stop 1u`, and the remembered `tran` edit
dies with the dialog. So the sequence *does* still lose an edit — it is remembered while the
dialog is open and dropped at OK. Per the brief I have not changed the commit semantics to
avoid it and have added no warning sentence; the shape is the user's to rule on.

**A second residual, found by measurement and not named in the brief.** A value typed under
`▸ Advanced` and then hidden by folding the disclosure shut is remembered by the cache and
shown again when it reopens (GR5l), but `chana_ok` reads only **live** widgets — so pressing
OK *while it is hidden* does not commit it. This is **unchanged from before** the task,
where the value was destroyed outright at the toggle, and strictly better; but
"remembered and not committed" is a new *shape* of the old loss. Widening what OK reads
(the cache for the visible type only — still not a multi-type write) would close it, and
that is a change to the commit door, which the brief put out of scope. Recorded here for
the driver to decide whether it is a follow-up.

---

## 7. Debts

* **No new user-facing sentence.** Nothing was minted: no new label, no new status line, no
  new refusal, no new banner text. `grep` over the diff of `src/ase_window.tcl` shows every
  added string literal is a comment or an array key. **No `owed.sh add rule` for copy.**
* **No `look` debt.** No new widget and nothing newly drawn — the only user-visible
  difference is the **content** of entries that already existed. Consistent with `DECISIONS.md`
  R5's own "no new widget and nothing newly drawn, so no `look` debt".
* **A suite debt is arguable and I did not file one**: the GR5 rows already ran on the dev
  display (`:99`, openbox 3.6.1 live, `AUDIT_SCREEN` default), which is where this batch's
  GUI rows live. If the driver wants the `:0` pass that CLAUDE.md asks for before calling a
  GUI feature done, `owed.sh add suite test_ase_dialogs` is the line — flagged rather than
  filed because it is the driver's batching call.

## 8. Corrections to the brief

1. **§2's mechanism facts are all correct**, and I verified each by reading before relying
   on it. The one that is *load-bearing in a way the brief does not say*: `chana_form_vals`
   answers for the fields **this rebuild put on screen**, so it is also the right reader for
   the save — but only after it is diffed against what the build put there. See §2 above.
2. **§5's sabotage list is one short.** (c) names the apply-side merge; there is a
   **second** merge on the save side, with its own failure shape (a value typed under
   Advanced, lost when the disclosure folds shut). Added as `c2`, with `GR5l` as the row.
3. **§5's "`test_ase_dialogs` has TWO STANDING RED ROWS on the display arm"** — today,
   **one**. `GG9` passed on every run I took, which the file's own paragraph already
   predicts (its premise depends on a cold capability cache). The paragraph is right; the
   count in the brief is a timestamp.
4. **§6's residual is real and there is a second one** (§6 above), in the same family and
   from a different direction.

## 9. Commands, for the driver to re-run

```sh
cd /home/analog/dev/xschem-claude
timeout 300 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl
timeout 300 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl
```
