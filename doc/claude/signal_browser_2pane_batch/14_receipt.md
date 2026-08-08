# TWO-PANE item 14 — receipt

Persistence of `sash` / `devint` / `srccur`.
Spec `doc/claude/specs/waveform_signal_browser_two_pane.md` **§9 / R11**.
Work item: `PLAN.md` two-pane item 14 (**not** single-pane item 14, which is
All-DBs and is already shipped — the two collide on the number and on the word
"conditional key").

Measured 2026-08-08 on `9d5cdd26` + the item-13 tree, **Xvfb arm** (unattended
window, ~5 h left at the first run). No window-manager claim anywhere in this
item.

| | |
|---|---|
| arms | headless **1627 / 0 fail** · X **11/11, 2170** |
| baseline it started from | headless **1619**, X **2149** — both RE-MEASURED on the unchanged tree first, both EXACT, no drift |
| new check calls | **21** (17 in `i1315`, 3 in `modes`, 1 in `grid`'s per-row loop) |
| existing checks restated | **6** — `BP10` `BP13` `BP43` `BP45` `BW59` `GH8`. None deleted. |
| sabotages | **8/8 fire, none fires nothing** — but **three of the eight fire on a different target set than the PLAN predicted**, and those corrections are §5 |

---

## 1. What shipped

Five edits in `src/wave_viewer.tcl`, one row in `doc/waveform_viewer_guide.html`,
and the four-file test lockstep.

| # | where | what |
|---|---|---|
| A1 | `browser_state_default` | three keys **APPENDED** after `hist`: `sash 0`, `devint 0`, `srccur 1` |
| A2 | `browser_sash` | the layout default 0.55 became a **LOCAL** — it no longer SEEDS `browsersash($token)` |
| A3 | `browser_sash_pref` **(new)** | the persisted preference. PURE. `0` = nobody chose a split |
| A4 | `browser_sash_drop` **(new)** + one `bind` in `browser_build` | the sash's `<ButtonRelease-1>`: reads the live split, stores it as a FRACTION |
| A5 | `browser_state` / `browser_state_apply` | reader appends three `dict set`s; writer restores the boxes BEFORE `browser_show` and the sash AFTER the width |

**A2 is the item.** Everything else is plumbing around it. `browser_sash`'s read
arm used to write `browsersash($token) = 0.55` on first call, and `browser_show`
calls it twice on its pack branch — so after any show, a window nobody had
touched carried a stored 0.55, and "has a preference" and "has been shown" were
the same fact. With the default held in a local, `[info exists
browsersash($token)]` means EXACTLY "somebody chose a split", which is the only
thing that makes spec §9's `sash 0` expressible at all.

### The trap that shape avoids, stated once

`browser_sash`'s read arm is **not a getter**: it APPLIES the split and answers
the LAYOUT default on an untouched window. Read that from `browser_state` and
`browser_state_is_default`'s whole-dict string compare is false **forever** —
every viewer's snapshot grows a `browser` key and `MG9` in
`test_wave_modes.tcl`, a file this batch does not own, goes red. **Measured:**
sabotage `S1` does exactly this and reds **12 checks across two files**,
including `MG9`.

The obvious "fix" — make `browser_sash`'s read arm answer the preference — is
**worse and was refused**. `test_wave_sigbrowser_sea.tcl:407/433` captures that
value, squeezes the pane to 0.90 and restores it; a read arm answering 0 makes
the restoring call fail the accessor's own `$want > 0` guard and leaves the sea
squeezed for the rest of that file. Two readers, two contracts, both documented
at their definitions.

---

## 2. Counts, per file, with the reason each one moved

**headless 1619 → 1627**, 14 files, 0 fail.

| file | was | now | why |
|---|---|---|---|
| `test_wave_sigbrowser_i1315` | 80 | **87** | `BP62`-`BP68` (7 new PURE/SOURCE calls) |
| `test_wave_grid` | 230 | **231** | `GH8`'s per-row loop gained one guide row |
| every other file | — | — | byte-identical |

**X 2149 → 2170**, 11/11.

| suite | was | now | why |
|---|---|---|---|
| `i1315` | 167 | **184** | +7 as above, +10 for the `BP69`-`BP74` real-viewer block |
| `grid` | 355 | **356** | the same guide row |
| `modes` | 485 | **488** | `MG18`, three calls |
| `panes` | 81 | **81** | `BW59` restated **in place** — no new call |
| every other suite | — | — | byte-identical |

---

## 3. RED FIRST — and what the RED run actually found

Every new and restated check was written and run **before** a line of
`src/wave_viewer.tcl` moved. RED run: **i1315 8 FAILED / 79 passed** headless,
**19 FAILED / 165 passed** in X; `grid` 2 FAILED; `modes` 1 FAILED (X);
`panes` 1 FAILED (X). Counts on the RED run already matched the post-item
counts, which is what makes a later shortfall detectable.

### Vacuous on the RED run, and what was done about each

1. **`BP13`'s three new `0` legs passed before the code existed.** `dict replace`
   on a key the dict does not HAVE is an **insert**, so `is_default` answered 0
   because the dict grew a key, not because the field counts. **Cured in the same
   check**: three more legs replace each field with its **own default** and
   demand `1`, which is only reachable once the key is really in the default
   dict. Ten legs became thirteen; the check call count did not move.
2. **`BP63` legs 2-3, `BP66` leg 4, `BP67` leg 2, `BP68` leg 3, `BP74` leg 1**
   were all green on the RED run. Each is a "this must stay zero" leg and each is
   carried in the **same tuple** as a leg that was RED — none shipped as a
   standalone check. That is the required shape, recorded rather than hidden.
3. **`BP69 (FIXTURE)` and `BP71 restore returns 1` passed on the RED run.** They
   are preconditions, deliberately separate calls so "the fixture broke" and
   "the claim is false" are different lines in the log.
4. **`BP69`'s third leg was measured WRONG TWICE on real runs.** First spelling
   asked `browser_state_is_default` on the raw dict and reported 0 for the
   `shown 1` the check had itself set; second spelling patched `shown` back and
   still reported 0 (`width`, from `browser_show`'s pack branch). Rather than
   bolt on a third `dict replace`, the leg now uses a new helper
   `bp_nondefault_keys` that **names the departing keys** — measured
   `{shown width open sel}`, all four traceable to the toggle the check has to
   perform (`sel`/`open` are item 10's R4 selection and `see`'s ancestor
   expansion). A NEW departure is now a NEW name and cannot be papered over.

---

## 4. Existing checks restated (never deleted)

| check | file | from | to |
|---|---|---|---|
| `BP10` | `i1315` | 8 keys | 11, the three **appended** |
| `BP13` | `i1315` | 7 legs | **13** — 10 "is 0", 3 "is 1 at its own default" (§3.1) |
| `BP43` | `i1315` | 6-leg tuple | 9 — the fixture now departs in all three new fields |
| `BP45` | `i1315` | 8 sentinel reads | 11 |
| `BW59` | `panes` | `{2 2}` | `{4 4 1 1}` — **the PLAN omitted this one** |
| `GH8` | `grid` | literal 15 | 16, in lockstep with the guide row and the `bind` |

`BW59` deserves its own paragraph. It is a **bare-name file-wide count**
(`browser_devint` / `browser_srccur` over the whole source, comments included),
and the number had to grow from 2 to 4. A bigger number alone is a **weaker**
check — four reads crammed onto the filter path and none in the state pair
satisfies `{4 4}`. So the restatement **enumerates the four sites in the check
text** and **adds a per-proc leg** (`browser_refresh` must hold exactly one of
each), which is the "one place for a scoping sabotage to land" claim the number
used to buy. ⚠ Corollary, obeyed: **no comment in `src/wave_viewer.tcl` names
either accessor** — that is how item 12 red `BD06`.

`GH8`/`GH9` are the **three-file lockstep** (`bind $f.pw <ButtonRelease-1>` in
the source, a `data-bseq` row in the guide, the literal in the test). All three
moved in this one commit. `GH9` alone would have stayed **green** on a half-done
edit where both sides moved and the literal did not — which is why `GH8`'s
literal is asserted separately.

---

## 5. Sabotages — 8 injected, 8 fired, THREE fired differently than predicted

Driver: `scratchpad/i14/sabo.sh`. Lock file, `EXIT/INT/TERM` trap restoring
`src/wave_viewer.tcl` from a **byte-exact backup** (never `git checkout --`: the
item was uncommitted), PRE-STATE counts asserted before the first patch, a
`diff` proving each mutation reached disk, a `diff` proving each restore, and an
output filter that counts **`NORESULT`, `TIMEOUT` and `X connection … broken` as
REDS** and flags any file whose **count** moved. Five files per run:
`i1315`, `panes`, `grid`, `modes`, `sea`.

Every row below is a **measurement**. Counts held at 184/81/356/488/79 on every
single run — no file aborted early, so no red set is a truncation.

| # | mutation | fired on | predicted? |
|---|---|---|---|
| **S1** | `browser_state` reads the **live split** (`sashpos 0` / `winfo height`) instead of the preference | **12 reds, 2 files.** `i1315`: `BP63` `BP64` `BP69` `BP73` `BP41`×2 `BP42` `BP46` `BP58`. `modes`: **`MG9`** + `MG18`×2 | ✔ and then some — the PLAN said "four oracles across three files"; measured **twelve across two**, `panes`/`grid`/`sea` untouched |
| **S2** | `browser_sash_drop` stores the **pixel** `$p` instead of `$p/$h` | **`BP70` alone** | ✘ **CORRECTED.** PLAN predicted `BP72`'s fraction leg too. It cannot: `BP72` restores through `browser_state_apply` → the **accessor**, which the drop's bug never reaches. The accessor's `$want > 0 && $want < 1` guard **refuses** every real pixel count, so the pixel bug **fails closed** — a drag stores nothing at all. `BP70` is the only oracle, which is exactly why `BP70` exists |
| **S3** | `srccur` defaults to **0** in `browser_state_default` | **12 reds, 2 files.** `i1315`: `BP62` `BP13` `BP69` `BP73` `BP41`×2 `BP42` `BP46` `BP58`. `modes`: `MG9` + `MG18`×2 | ✔ for `BP62`/`BP13`. ✘ for the PLAN's "`MG10` red" — `MG10` belongs to a different item; `MG18` is the twin, and it *does* red |
| **S4** | the three keys **inserted mid-dict** (after `dest`) in `browser_state_default` | **`BP10` alone** | ✘ **CORRECTED, and the PLAN's rationale is wrong.** Both the PLAN and the scout predicted `BP41`/`BP42`/`MG9` would cascade "because the string compare then never matches `browser_state`'s build order". They cannot: `browser_state` **starts from** `browser_state_default` and `dict set`s into it, and `dict set` on an existing key **preserves its position** — so the reader's key order *always* follows the default's. `BP10` is the whole guard on the append rule, and that is now the reason it exists |
| **S5a** | restore the sidebar's shown state through `browser_toggle` instead of the direct `set browser($token)` | `BP65` `BP66` `BP74` | ✔ (this is the substitute; see the divergence list — the PLAN's own S5 reds nothing) |
| **S5b** | restore a class box by `$f.opt.dev invoke` — a **relative** toggle | `BP65` `BP66` **`BP74`** (`i1315`) + **`BW59`** (`panes`) | ⚠ **A MEASURED COVERAGE HOLE, THEN CLOSED.** On the first pass this fired only on the SOURCE checks and `BW59`: every behavioural round trip in the file asks for the OPPOSITE of the fresh window's default, so one flip lands on the right answer by coincidence. `BP74` was given an **idempotence leg** (apply the SAME dict TWICE — a write is idempotent, a toggle flips back) and the sabotage was **re-run**: it now reds `BP74` behaviourally. Counts unchanged at 184 |
| **S6** | delete the `<ButtonRelease-1>` bind from `browser_build` | **4 reds, 2 files.** `i1315`: `BP68` `BP70`. `grid`: `GH8`'s per-row leg + `GH9` | ✔ exactly — four oracles, two files, one line. This is the sabotage that proves the feature can fire for a user |
| **S7** | restore the `set browsersash($token) 0.55` seed inside `browser_sash` (the one-line revert of A2) | **`BP69` alone** | ✘ **CORRECTED.** Scout predicted `BP41`/`BP42`/`MG9` too. They cannot see it: the seed is only written once `browser_sash` has RUN, and it only runs from `browser_show`'s pack branch — `BP41`, `BP42` and `MG9` all read windows whose sidebar was **never shown**. `BP69` is the **only** witness in the tree, and its leg 2 ("the live split really is non-zero") is what stops it being green on an unmapped pane |

**No sabotage fired nothing.** Every mutation was proved on disk by `diff`
before its run and every restore was proved byte-identical after it; the clean
re-run after the campaign was green at the same five counts.

---

## 6. PLAN divergences

Fourteen. The PLAN's item-14 text is largely a record of the pre-item-9 tree.

1. **"`browser_state` writes them through … a new `browser_sash {token {want {}}}`"**
   — **it is not new.** `browser_sash` shipped with two-pane item 9 and is driven
   by `BW33` and by `sea.tcl`. What item 14 adds is `browser_sash_pref` and
   `browser_sash_drop`; the accessor's contract is deliberately **unchanged**.
2. **"Two new arrays declared and unset in the teardown block"** — **all three
   already existed** (`browsersash`/`browserdev`/`browsersrc`, declared,
   re-declared in the teardown proc, unset there) and are pinned by `BW14`. This
   item added **none** and touched none of the three unsets.
3. **"`browsersash($token)` is written only by the panedwindow's
   `<ButtonRelease-1>`"** — **false twice** on the pre-item tree: there was no
   such binding anywhere in `src/`, and `browser_sash` itself seeded the array
   unconditionally. Item 14 **made** the statement true (S6 and S7 are the two
   halves of it as sabotages).
4. **Band `BP60`-`BP70`** — `BP60`/`BP61` are **spent** (the teardown pair,
   `i1315:1625/1636/1638`). Took **`BP62`-`BP74`**. Third time a band in this
   PLAN has been already-spent.
5. **"Add `MG10` to `test_wave_modes.tcl`"** — **`MG10` is spent**
   (`modes:2129-2190`, the schematic-side entry points, ~20 checks). Took
   **`MG18`**.
6. **"`test_wave_modes.tcl` green at 214"** — measured base is **212 headless /
   485 X**, and `MG9`'s whole block is **X-only** (inside the `has_x` gate), so
   214 is unreachable in the headless arm at all. Replaced with measured deltas:
   **212 unchanged / 485 → 488**. 214 looks like a transcription of the stale
   "grid 214" figure at `PLAN.md:27`.
7. **"`BP45` … `sel` becomes `{g:x1.x2}`"** — already so since item 10/13
   reworked the fixture. No edit owed and none made.
8. **PLAN §2 preamble "`bind $f.` in `browser_build` = 6; `data-bseq` rows = 6"**
   — measured **15 and 15** before this item, **16 and 16** after.
9. **"Existing checks it reds: `BP10`, `BP13`, `BP45`"** — **incomplete.**
   `BW59` (`panes`), `GH8` and `GH9` (`grid`) also red and were restated. `BW59`
   in particular is a bare-name count the PLAN never mentions.
10. **PLAN sabotage "write `devint` through the checkbutton's `-command` on
    restore → BP70 red"** — **reds nothing**: the boxes' `-command` is
    `browser_refresh`, which does not log. Replaced with **S5a** (restore
    `shown` through `browser_toggle`) and **S5b** (`invoke`, a relative toggle).
11. **S2's predicted target set was wrong** — see the sabotage table. The
    pixel bug fails **closed**, so `BP66`/`BP72` cannot see it.
12. **S4's predicted cascade was wrong, and so was its stated mechanism** — see
    the table. `dict set` preserves key position, so the reader can never
    disagree with the default's order.
13. **S7's predicted cascade was wrong** — `BP41`/`BP42`/`MG9` all read
    never-shown sidebars and cannot see a seed written on the pack branch.
14. **The scout's predicted deltas were short.** Predicted `i1315` X 167 → 180
    and `modes` 485 → 487; measured **184** and **488** — the X block was
    written as 10 calls, not 6, and `MG18` as 3 calls, not 2. Headless 1627 and
    `grid` 231/356 were predicted exactly.

Helpers the PLAN's draft checks assumed (`bp_roundtrip`, `bp_log_delta`,
`bp_order`, `bs_sash_frac $PW` as a bare read) do not exist or would have made
the check assert its own helper's restore. Two new local helpers were written
instead — `bp_order3` (an assertable **string**: `ok` / `missing:<needle>` /
`wrong:<i> <j> <k>`, never a boolean and never a throw) and `bp_nondefault_keys`
(the **names** of the departing fields, never a boolean) — and everything else
was inlined so nothing restores what it asserts.

---

## 7. Declared limits

Each of these was **MEASURED not to work** (or measured to be unmeasurable here)
and is shipping anyway with the limit stated.

1. **The item's user-visible effect is not judged by any check at pixel level.**
   Every claim here is a STATE claim: the dict carries the field, the widget's
   sash fraction lands within 0.03. Whether the restored split *looks* like the
   one the user chose is an **eyeball** — script in §7.7 below. The ledger mark
   is therefore `[E]`, never `[x]`.
2. **The two class boxes are behavioural NO-OPS on this file's fixture.** `brP`
   and `brA` are plain voltages with no device-classed and no `srcbranch` names,
   so `devint`/`srccur` change nothing visible in `i1315`. That is deliberate —
   it is what lets `BP43`'s fixture depart in all three fields without moving
   `BP43a`/`BP47`-`BP56`'s tree, sea and width values — but it means
   `BP43`/`BP45`/`BP71`/`BP73`/`BP74` are **state claims only**. The behavioural
   claim belongs to `BW60`-`BW62` in `panes` (the measured 424-name corpus and
   the two real `invoke` gestures) and is not re-litigated here.
3. **A restore of a HIDDEN sidebar stores the sash preference but cannot apply
   it.** The accessor's `$h <= 1` guard makes the apply a no-op on an unmapped
   pane; `browser_show`'s `after idle` re-apply puts it in place the moment the
   user opens the sidebar. Chosen over dropping the preference, which would make
   "snapshot taken with the browser closed" silently forget a split the user set.
4. **`browser_sash_drop` fires on ANY `<ButtonRelease-1>` on `$f.pw`**, including
   a release that moved nothing. It then re-stores the fraction that is already
   there — an idempotent write, not a behaviour change, and the price of having
   exactly one writer. A release on the tree or the sea goes to those widgets.
5. **Xvfb has no window manager**, so `BP72`'s `wm geometry` shrink is a raw X
   resize rather than a WM-mediated one. The fraction claim holds either way
   (`bs_wait_sash` reads the widget, not the WM), but a claim about *decorated*
   resize would be an eyeball, not a check. Nothing in this item needs one.
6. **`ttk` re-proportions the sash on a resize all by itself** — MEASURED
   240/600 → 90/300 with nothing helping it. That is why `BP72` carries a
   pre-apply leg; without it a "the fraction came back" check is green on the
   widget's own arithmetic. It also means the sash preference and ttk's own
   behaviour **agree** on a plain resize, so `BP72` is only distinguishable
   because the target (0.62) differs from what ttk lands on.
7. **`.ph`, the sidebar's status line, is still class-filter blind** — carried in
   from item 12 and **deliberately untouched**. It is bar-matched only, so R11's
   boxes move the tree, the sea and `browserseaent` but not that line. `BD52`,
   `BX37`, `BX42`, `BX44`-`BX46`, `BH50`, `BH51`, `BH54` pin it byte-identically
   and all are green. Whoever takes spec §7.2's three-state caption settles it.
8. **`BW24` was NOT restated, by design.** Item 12's and item 13's receipts both
   flagged it as "the check item 14 will have to restate IF it makes the defaults
   come from a persisted file". It does **not**: `browser_build` still seeds
   `0`/`1`, and a restore only overrides when a state dict is applied. `BW24` is
   green untouched, and that is the record of the decision.

### 7.7 The eyeball script

1. Open a viewer with a raw loaded, open the Signal Browser, **drag the sash**
   so the tree is clearly smaller than usual, and tick **Show device
   internals**.
2. Save the session, quit, reopen. **The split must come back where you left
   it, and the box must still be ticked.**
3. Resize the window **shorter** and reopen the session again. The sash must
   come back at the same *proportion* of the sidebar, not the same number of
   pixels down — i.e. it must not sit off the bottom or hard against the top.
4. On a **fresh** window that you never drag: the split must be the ordinary
   default and the session file must contain **no** `browser` key at all.

---

## 8. Next free ids

`BP75` · `MG19` · `BW79` · `GH` unchanged. **`BD60`-`BD70` remain two-pane item
15's and were not taken.**
