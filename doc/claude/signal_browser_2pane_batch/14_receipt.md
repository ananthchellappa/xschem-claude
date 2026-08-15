# TWO-PANE item 14 — receipt

Persistence of `sash` / `devint` / `srccur`.
Spec `doc/claude/specs/waveform_signal_browser_two_pane.md` **§9 / R11**.
Work item: `PLAN.md` two-pane item 14 (**not** single-pane item 14, which is
All-DBs and is already shipped — the two collide on the number and on the word
"conditional key").

Measured 2026-08-08 on `9d5cdd26` + the item-13 tree, **Xvfb arm** (unattended
window, ~5 h left at the first run). No window-manager claim anywhere in this
item.

## ⛔ VERDICT: **FAILED** — `1990d00e`

Rejected a **second** time by the same adversarial verifier, for the **same
class of defect** as the first rejection: a written justification with no oracle
behind it. The verifier's own fresh, previously unnamed sabotage **`V4`** — one
character in the sash accessor's store guard — goes **fully green** across
`i1315` (188) and `sea` (79), and the source comment four lines from the two
holes the fixup just closed cites that guard **by name** as the reason the sash
restore needs no gate. **§10 is the failure.** Everything above §10 is the
record of what did land, kept in full and unchanged, because the code is
committed and **not** reverted.

| | |
|---|---|
| verdict | **FAILED** — third coverage hole open, §10 |
| arms | headless **1627 / 0 fail** · X **11/11, 2170** — **after the verification fixup (§9): headless 1628 · X 2174**, both RE-MEASURED independently by the verifier, exact |
| baseline it started from | headless **1619**, X **2149** — both RE-MEASURED on the unchanged tree first, both EXACT, no drift |
| new check calls | **21** + **4** in the fixup = 25 (21 in `i1315`, 3 in `modes`, 1 in `grid`'s per-row loop) |
| existing checks restated | **6** — `BP10` `BP13` `BP43` `BP45` `BW59` `GH8`. None deleted, none deleted in the fixup either. |
| sabotages | **8/8** of the item's fire · **4/4** of the fixup's fire · **`V4`, the verifier's own unnamed one, FIRES NOTHING** |
| owed to the next item | **§12** — `BP78`, and why the item cannot be `[E]` until it exists |

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

> ⚠ **That same `$want > 0` guard is what §10 is about.** It is load-bearing in
> two directions — it protects `sea.tcl`'s restore *and* it is cited as the
> reason spec §9's `sash 0` needs no gate — and **no check measures the second
> direction**.

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

The fixup's own deltas are §9.6. The **verifier's independent re-measurement** of
the final tree is §10.1 and matches both tables to the digit.

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

The fixup had **no RED run of its own** (the code under test had already landed
in `91c6c828`); what replaces it there is the sabotage campaign, and the vacuity
argument for each of the four new checks is **§9.7**.

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

**Why each**, in one line: `BP10` is the append rule's only guard;
`BP13`/`BP43`/`BP45` are the three round-trip shapes and every one of them has
to grow by exactly the three new fields or the field is untested; `BW59` is the
bare-name file-wide count and the number physically changed; `GH8` is the
three-file lockstep literal and the source gained a binding.

`BW59` deserves its own paragraph. It is a **bare-name file-wide count**
(`browser_devint` / `browser_srccur` over the whole source, comments included),
and the number had to grow from 2 to 4. A bigger number alone is a **weaker**
check — four reads crammed onto the filter path and none in the state pair
satisfies `{4 4}`. So the restatement **enumerates the four sites in the check
text** and **adds a per-proc leg** (`browser_refresh` must hold exactly one of
each), which is the "one place for a scoping sabotage to land" claim the number
used to buy. ⚠ Corollary, obeyed: **no comment in `src/wave_viewer.tcl` names
either accessor** — that is how item 12 red `BD06`. ⚠⚠ SCOPE, ADDED BY THE
FIXUP: that sentence is true of these **two** accessors only. It was **not**
true of the two procs this item introduced until §9.4 fixed them, and the
commit message's broader wording was wrong. See §9.4.

`GH8`/`GH9` are the **three-file lockstep** (`bind $f.pw <ButtonRelease-1>` in
the source, a `data-bseq` row in the guide, the literal in the test). All three
moved in this one commit. `GH9` alone would have stayed **green** on a half-done
edit where both sides moved and the literal did not — which is why `GH8`'s
literal is asserted separately.

**Nothing was restated in the fixup, and nothing was deleted in either round.**

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
| **S7** | restore the `set browsersash($token) 0.55` seed inside `browser_sash` (the one-line revert of A2) | **`BP69` alone** | ✘ **CORRECTED.** Scout predicted `BP41`/`BP42`/`MG9` too. They cannot see it: the seed is only written once `browser_sash` has RUN, and it only runs from `browser_show`'s pack branch — `BP41`, `BP42` and `MG9` all read windows whose sidebar was **never shown**. `BP69` is the **only** witness in the tree at the time of this measurement, and its leg 2 ("the live split really is non-zero") is what stops it being green on an unmapped pane. ⚠ RE-MEASURED AFTER THE FIXUP: with `BP77` in the file it now reds **`BP69` + `BP77`** (186 / 2) — see §9.3; `BP41`/`BP42`/`MG9` are still GREEN |

**No sabotage fired nothing.** Every mutation was proved on disk by `diff`
before its run and every restore was proved byte-identical after it; the clean
re-run after the campaign was green at the same five counts.

### 5.1 The discipline columns, per row

`failedExactly` = the measured red set is exactly the checks that own the claim,
no collateral and no shortfall. `positive control` = what proves a green row
would have been visible. `reverted` = the restore was proved, not assumed.

| # | failedExactly | positive control | reverted |
|---|---|---|---|
| S1 | **broad, on target** — 12 reds, every one a reader of the persisted field; no collateral outside the claim | pre-state counts asserted 184/81/356/488/79; all five held during the run | ✔ `diff` byte-identical |
| S2 | ✔ **`BP70` alone** | as above; count held at 184 | ✔ `diff` |
| S3 | **broad, on target** — 12 reds, all of them defaults readers | as above | ✔ `diff` |
| S4 | ✔ **`BP10` alone** | as above | ✔ `diff` |
| S5a | ✔ three, all `shown`-restore checks | as above | ✔ `diff` |
| S5b | ✘ **first pass** (SOURCE-only + `BW59`) → ✔ **after `BP74` gained the idempotence leg**, re-run | as above; count held at 184 across BOTH passes, so the first pass was a real hole and not a truncation | ✔ `diff`, both passes |
| S6 | ✔ four, two files, one deleted line | as above | ✔ `diff` |
| S7 | ✔ **`BP69` alone** at the time; **`BP69` + `BP77`** after the fixup (§9.3), both exact | as above; `modes` 488 and `panes` 81 stayed green, which is the control that says `BP41`/`BP42`/`MG9` genuinely cannot see it | ✔ `diff` |

---

## 6. PLAN divergences

Fourteen from the item, four more from the fixup (§9.8). The PLAN's item-14 text
is largely a record of the pre-item-9 tree.

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
and is shipping anyway with the limit stated. 1-8 are the item's; 9-13 were
added by the fixup.

1. **The item's user-visible effect is not judged by any check at pixel level.**
   Every claim here is a STATE claim: the dict carries the field, the widget's
   sash fraction lands within 0.03. Whether the restored split *looks* like the
   one the user chose is an **eyeball** — script in §7.7 below. The ledger mark
   would therefore have been `[E]`, never `[x]`; it is `[F]` for §10.
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
   ⚠ **This limit was UNMEASURED and the verifier's `V2` proved it** — now only
   PARTLY closed by `BP77`; see §9.1 and limit 11.
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
9. **`BP76` and `BP77` are X-arm only.** `browser_state_apply` needs a real
   registered window, so neither claim is expressible under `--nogui`; `BP75` is
   the both-arms half and is deliberately a SOURCE check for that reason. **A
   green headless run proves nothing about either restore path.**
10. **`BP77` covers a NEVER-SHOWN sidebar, not a `pack forget`-ed one.** It
    asserts the hidden-sidebar STORE through the accessor's own guard on a fresh
    viewer whose `.wvbrowser` was built but never packed. Tk keeps the last
    geometry on an unmapped-after-mapped widget, so `winfo height` there is not 1
    and the guard is not taken. That is a different path and **it is unmeasured**.
11. **Limit 3 is only PARTLY closed.** `BP77` pins that the preference is stored
    and that opening the sidebar applies it. It does **not** pin the pixel
    appearance of the restored split — that is still §7.7's eyeball.
12. **`V2`'s literal form is not a single-target oracle.** A plain move of the
    store below the guard reds `BP70` and `BP72` as well as `BP77`, because it
    also stales `frac`. `BP77` is the sole oracle for the coverage hole but NOT
    the sole oracle for that particular source edit; a future editor who moves
    the line sees three reds, two of which are a different bug. See §9.5.
13. **Xvfb arm throughout** (272 min of the unattended window left at the last
    run). No window-manager claim anywhere in the item or the fixup — no
    decoration, iconify, stacking, raise or geometry echo — so the Xvfb/`:0`
    equivalence recorded in the LEDGER's baseline applies unqualified.

### 7.7 The eyeball script

**Do not action this while the item is `[F]`.** It is kept here because it is
the deliverable's only pixel judge and §10's fix does not change it.

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
5. ⚠ **Added by §10, and the one that matters most now:** load a session saved
   by a user who **never touched the sash** (so its `browser` dict carries
   `sash 0`) but did change something else — width, filter, dest, the open set.
   **The split must be the ordinary default. It must not collapse.**

---

## 8. Next free ids

`MG19` · `BW79` · `GH` unchanged. **`BD60`-`BD70` remain two-pane item 15's and
were not taken.** (`BP75`-`BP77` were taken by §9.)

**`BP78` is free but SPOKEN FOR** — it is the id §10's missing check must take,
and the `i1315` header already reserves it. First genuinely free `BP` after that
is `BP79`.

---

## 9. FIXUP after adversarial verification — `BP75`/`BP76`/`BP77`

The item was **rejected** by its verifier, who ran four sabotages of its own.
**Two stayed fully green**, and those two are the finding. Everything in this
section is a MEASUREMENT on the fixup tree, not a prediction.

### 9.1 Two coverage holes, both on LIVE user paths

| | the mutation | before the fixup | after |
|---|---|---|---|
| **V1** | swap the two fallbacks in `browser_state_apply` — `dget $d devint 0` → `1` and `dget $d srccur 1` → `0` | **fully green**: `i1315` 184, `panes` 81, `modes` 488, `sea` 79 — four suites, zero reds | reds **`BP75`** + **`BP76`**, count held at **188** |
| **V2** | move the sash accessor's `set browsersash($token) $want` from BEFORE its `$h <= 1` guard to AFTER it, so a restore into a never-shown sidebar DROPS the preference | **fully green**: `i1315` 184, `panes` 81, `sea` 79 | reds **`BP77`**, count held at **188** |

Neither is defensive code. **V1's branch is reached by every state file written
before `91c6c828`**: `ase_window.tcl`'s Save State / Load State persists the
session `viewer` dict — `browser` sub-dict and all — to a FILE, and a legacy
file has no `devint`/`srccur` key, so a swap restores that session with device
internals **ON** and source currents **OFF**, inverted from R11 and silent.
**V2's branch is the behaviour `declaredLimits` chose on purpose** ("a restore
of a HIDDEN sidebar STORES the sash preference but cannot APPLY it … chosen
over dropping the preference"); the choice was declared, that it was unmeasured
was not.

**Why the batch could not see either.** Every behavioural round trip in the
item (`BP43`, `BP45`, `BP71`, `BP74`) supplies all three keys, so the
key-ABSENT path was never entered; and `BP71`'s restore lands on a window whose
pane is already mapped, because `BP69` toggles the sidebar ON as its first act
and the whole group inherits that. **A fresh viewer's sidebar is BUILT but
never packed** — that is the state both defects need and the state the new
block runs in.

### 9.2 The three new checks

| id | arm | claim |
|---|---|---|
| `BP75` | **both** | the two fallback constants, EXTRACTED AS VALUES, are R11's asymmetric `0`/`1` **and** are the same pair `browser_state_default` ships. Both start `{NO-MATCH}`, so a deleted or renamed line cannot go green |
| `BP76` | X | a **PRE-ITEM state dict** (`devint`/`srccur`/`sash` all removed) applied to a window first driven to the OPPOSITE pair `{1 0}` lands on `{0 1}`. Leg 1 proves it really departed, so `{0 1}` cannot be "already like that" and cannot be "the writer did nothing" — both of those read `{1 0}` |
| `BP77` | X | a restore into a **never-shown** sidebar cannot APPLY the sash (leg 2: `winfo height` ≤ 1, and `>= 0` so an `ERR:` read cannot satisfy it) but **STORES** it anyway (leg 3), and opening the sidebar then lands on the restored `0.44` rather than the `0.55` layout default (leg 4). Leg 1 pins the preference at `0` beforehand |

Plus one `BP76 (FIXTURE)` call — the viewer opens, its `.wvbrowser` is **not**
packed, its `.pw` **does** exist. **4 new check calls**, none restated, none
deleted.

### 9.3 The false sabotage claim, corrected IN THE SOURCE

The comment inside the sash accessor said S7 "reds `BP69` …, `BP41`, `BP42` and
`MG9` — four oracles across three files". **The receipt's §5 had already
corrected that and the source had not**, so the file hardest to re-measure from
was the one still carrying the disproved prediction. Re-measured here, on the
fixup tree:

* **S7 reds `BP69` and `BP77`** — `i1315` **186 passed / 2 failed**, count held
  at 188. `BP77` is new since the last measurement and is red for the right
  reason: `BP76`'s apply calls the accessor, and the restored seed puts a
  preference into a window nobody chose one for, which is the defect stated
  exactly. **Before `BP77` existed the answer was `BP69` ALONE (183 / 1)**, the
  figure §5 and the verifier both measured.
* **`BP41`, `BP42`, `MG9` MEASURE GREEN** — `test_wave_modes.tcl` **488**,
  `test_wave_sigbrowser_panes.tcl` **81**, both untouched. They cannot see it:
  the seed is only written once the accessor has RUN, which happens from
  `browser_show`'s pack branch, and all three read sidebars that were never
  shown.

The source comment now states that, including the pre-`BP77` figure.
**Independently re-measured by the verifier** on the shipped tree, same two
reds, with `BP69`'s printed value `{0.55 1 {shown width open sel sash}}` against
its expected `{0 1 {shown width open sel}}` — the PLAN's four-oracle prediction
is now disproved a fourth time.

### 9.4 The bare-name corollary, restated ACCURATELY

§4 of this receipt claimed "no comment in `src/wave_viewer.tcl` names either
accessor". That is **true as written** (it scopes to the two R11 accessors, and
the file-wide counts are `4` and `4`, all real call sites — `BW59` is honest).
**The commit message generalised it to "No accessor is named in any comment",
and that was FALSE**: the comment above the sash accessor spelled **both** procs
this item introduced. Nothing was red — no check counts those two bare names —
but it pre-poisons any future `BD06`/`BW59`-style count on them, which is the
exact trap the corollary exists to avoid.

Fixed by describing the two neighbours **by role** instead of by name, and by
writing the rule into the accessor's header so the next editor inherits it.
File-wide bare-name counts now, all four, all real call sites — **re-grepped
independently by the verifier on the shipped tree, with line numbers**:

| name | count | sites |
|---|---|---|
| `browser_sash_pref` | **2** | `proc` at `:8226`; the state reader at `:10295` |
| `browser_sash_drop` | **2** | the `bind` at `:7284`; `proc` at `:8246` |
| `browser_devint` | **4** | `:8353`, `:8515`, `:10296`, `:10350` |
| `browser_srccur` | **4** | `:8359`, `:8516`, `:10297`, `:10351` |

### 9.5 A sabotage that did NOT fire exactly, and what was done

The verifier's V2 as literally described — *move* the store below the guard —
also reds **`BP70`** and **`BP72`**, because the `set frac` block sits between
the two and the moved store leaves `frac` STALE: the accessor then snaps the
sash back to `0.55` in the middle of a real drag. That is a second, larger
defect riding along, so it is **not** a clean oracle for the coverage hole.
**V2b** was run instead — the store is dropped only when the pane is unmapped
(`&& $h0 > 1`), the mapped path byte-for-byte unchanged — and it reds
**`BP77` ALONE**, 187 passed / 1 failed, count held at 188. Both forms are
recorded because the difference is the point: `BP77` is the precise oracle, and
the collateral reds under the literal move are a different bug.

**The verifier re-ran both forms and got the same answer** — V2-literal
185/3 (`BP70`, `BP72`, `BP77`), V2b 187/1 (`BP77`) — and recorded that the
divergence was reported against the implementer's own interest rather than
dressed up as a clean hit.

### 9.6 Arms after the fixup

| arm | was (item 14) | now |
|---|---|---|
| headless | 1627 | **1628** — `i1315` 87 → **88** (`BP75`), every other file byte-identical |
| X | 2170 | **2174** — `i1315` 184 → **188** (`BP75`, `BP76` fixture, `BP76`, `BP77`), every other suite byte-identical |

Sabotage driver: lock dir, `EXIT`/`INT`/`TERM` restore trap, pre-state md5
assert against a byte-exact backup (**not** `git checkout` — the fixup was
uncommitted while it ran), proof-of-mutation-on-disk, printed diff,
diff-verified restore, and `NORESULT` counted as red. Every restore verified
byte-identical; the clean re-run after them is green at 88 headless / 188 X.

### 9.7 Vacuity on the fixup — there was no RED run, so the SABOTAGE is the measurement

The code under test landed in `91c6c828`, so a from-scratch RED run was not
available. The equivalent measurement for a coverage-hole fixup is the sabotage
campaign, and **every one of the four new checks was proved non-vacuous by a
mutation that reds it**: `BP75` and `BP76` by V1, `BP77` by V2b alone and again
by V2-literal and by S7. The `BP76 (FIXTURE)` call is the only one not
individually sabotaged; it is a precondition (the viewer opened, `.wvbrowser`
is NOT packed, `.pw` DOES exist) and its middle leg is what makes `BP77`'s
leg 2 meaningful.

Anti-vacuity was **built into each check rather than assumed**:

* `BP75`'s two extracted constants both start `{NO-MATCH}`, so a deleted or
  renamed line is RED, not green. A bare `regexp` boolean would have gone green
  on a missing line.
* `BP76` leg 1 asserts the window really reached the OPPOSITE pair `{1 0}`
  first, so the `{0 1}` in leg 3 can be neither "it was already like that" nor
  "the writer did nothing" — both of those read `{1 0}`.
* `BP77` leg 2 is `$bp_h77 >= 0 && $bp_h77 <= 1`. The `>= 0` exists because
  `bs_num` answers `-1` on an `ERR:` read and `-1 <= 1` would otherwise be
  silently true — i.e. "the widget vanished" would have gone green.

The frozen oracles were re-grepped after every source edit and are unmoved:
`browser_devint` 4, `browser_srccur` 4 (`BW59`'s `{4 4 1 1}` still honest),
`browser_sash_pref` 2, `browser_sash_drop` 2 — all eight real call sites, zero
in comments. `GH8`/`GH9`'s `bind $f.` lockstep (16) is untouched; `grid` re-run
at 231 headless / 356 X.

### 9.8 Fixup divergences

15. **Problem 4 was accepted only in PART, with evidence.** §4's sentence is
    TRUE as written — it scopes to `browser_devint`/`browser_srccur`, whose
    file-wide counts are 4 and 4, all real call sites, so `BW59` is honest. What
    was false was the **commit message's** generalisation to "No accessor is
    named in any comment". Fixed at the source; §4 was given an explicit SCOPE
    clause rather than rewritten as if it had been wrong.
16. **The verifier's V2 could not be reproduced as a clean single-target
    sabotage** — §9.5. Rather than accept a three-red "confirmation" or weaken
    `BP77`, V2b was constructed to isolate the declared defect exactly. **Both**
    forms are recorded, because the difference between them is itself the
    finding.
17. **The MEASUREMENT overrode the first fix written for problem 3.** The
    corrected comment initially said S7 reds "`BP69` ALONE", which is what §5
    and the verifier had both measured. Re-running S7 on the fixup tree measured
    **`BP69` AND `BP77`** (186/2), because `BP76`'s apply calls the accessor.
    The comment now states the current measurement **and** the pre-`BP77`
    figure, so neither reading is a trap.
18. **The id band was extended rather than squeezed.** `BP75` is a both-arms
    SOURCE check and `BP76`/`BP77` are real-viewer, so the file header's
    "62-68 SOURCE / 69-74 REAL viewer" blocking was amended to add
    "75 SOURCE / 76-77 REAL viewer", with the arm carried in the id. Measured
    free first: `BP75`-`BP78` appear nowhere else in `tests/headless/`.
    `BD60`-`BD70` were NOT taken and remain item 15's. **Confirmed by the
    verifier**, who re-measured the band independently.
19. **The fixup adds 4 check CALLS where four problems might suggest more.**
    Problems 3 and 4 are comment defects with no behavioural surface, so they
    are fixed by correcting the comments, not by inventing checks that assert
    prose.

---

## 10. ⛔ WHY THE ITEM FAILED — `V4`, and a THIRD hole of the same family

The verifier's fourth sabotage was **fresh and unnamed anywhere** — not in the
PLAN, not in the item, not in this receipt, not in the fixup. It is the reason
the verdict is FAILED.

### 10.1 The verifier re-measured everything first

Nothing below rests on the implementer's own numbers.

| | measured by the verifier |
|---|---|
| headless, all 14 files, run as `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <f>` | **1628, 0 fail** — sigsearch 146, sea 6, sigbrowser 135, 2pane 108, panes 15, i11 50, i12 40, **i1315 88**, i14 47, grid 231, modes 212, viewer 57, markers 437, tabs 56 |
| X, through `xarm.sh suites` (Xvfb, 267 min left at start) | **11/11, 2174** — panes 81, 2pane 108, sigbrowser 353, sigsearch 233, sea 79, grid 356, i11 74, modes 488, i12 123, **i1315 188**, i14 91 |
| arithmetic back to the recorded baseline | item-13 1619/2149 → item-14 `91c6c828` 1627/2170 (headless i1315 +7, grid +1; X i1315 +17, modes +3, grid +1) → fixup 1628/2174, the whole fixup delta in `i1315` |
| source-diff provenance | `git diff 91c6c828 1990d00e -- src/wave_viewer.tcl` filtered for non-`#` `+`/`-` lines yields **ZERO** — the fixup's behaviour-change-free claim is true line by line |
| baseline fails / known flakes | **none hit** |
| tree afterwards | `src/wave_viewer.tcl` md5 `cbffb617eb31e0e194cdef52459b22b8` = the pre-sabotage backup; `git status --short src tests` shows no modified tracked file; the probe file deleted |

### 10.2 `V4` — one character, fully green

```
-  if {[string is double -strict $want] && $want > 0 && $want < 1}
+  if {[string is double -strict $want] && $want >= 0 && $want < 1}
```

`src/wave_viewer.tcl:8163`, the sash accessor's store guard. The mutation is
"stop **REFUSING** spec §9's `sash 0`".

| | |
|---|---|
| `test_wave_sigbrowser_i1315.tcl` | **188, ALL PASS** — count held, zero reds |
| `test_wave_sigbrowser_sea.tcl` | **79, ALL PASS** — zero reds |
| failedExactly | ✘ **it fires NOTHING** |
| positive control | the **same driver, same session** red `V1` (`BP75`+`BP76`), `V2`-literal (`BP70`+`BP72`+`BP77`), `V2b` (`BP77`) and `S7` (`BP69`+`BP77`) **exactly**, each with a printed proof-of-mutation md5 and diff. The driver is provably not at fault |
| reverted | ✔ md5 back to the pristine backup, `git status` clean, probe deleted |

### 10.3 It is a real behavioural defect, not a decorative guard — PROVED, both trees

The verifier copied `i1315` to a non-`test_*` filename, inserted **one**
measurement line, ran it on the pristine and on the sabotaged tree, and deleted
it. The measurement: apply a browser dict whose `sash` is **0** into a **SHOWN**
sidebar that already carries a **0.42** preference.

| tree | result |
|---|---|
| shipped | `pref=0.42 frac=0.42 px=210 h=500` — the split is preserved |
| under `V4` | `pref=0 frac=0.0 px=0 h=500` — **the tree pane is collapsed to zero pixels and the two-pane browser is destroyed** |

Silently, with every check in the batch green.

### 10.4 Why this is the SAME defect class as V1 and V2, four lines over

`src/wave_viewer.tcl:10380-10383` states, as **item 14's own justification** for
why the sash restore needs no gate:

> `sash 0` (spec §9's default, i.e. nobody chose a split) is REFUSED by the
> accessor's own `$want > 0 && $want < 1` guard, so a default state file leaves
> the layout default alone rather than collapsing a pane. That is why this line
> needs no gate of its own.

**Nothing measures it.** And it is **more** live than either hole the fixup just
closed: `browser_state` writes `sash 0` for **every user who never dragged the
sash**, so any restore of a browser dict from such a user — changed width,
filter, dest, open set, selection, anything — runs that line with `$want` 0.
V1 needed a legacy state file; V2 needed a hidden sidebar; **V4 needs only a
user who never touched the sash.**

The fixup's own new comment, two lines above this one, says of the neighbouring
choice *"THAT CHOICE IS NOW A CHECK, NOT JUST A DECLARED LIMIT"*. This one is
still just a declared limit.

### 10.5 The remedy — one check, `BP78`

In the same X block, and the `i1315` header already reserves the id:

* apply `[dict replace $bp_st14 shown 1 sash 0]` to a window carrying a **known
  non-zero** preference;
* assert the fraction **and** `sashpos 0` are **unchanged and non-zero**;
* carry a leg proving the preference was really there first — without it the
  check is green on a window that never had one, which is the exact vacuity
  shape §9.7 spends three bullets on.

Expected effect on the arms: headless unchanged at 1628 (X-only claim),
X `i1315` 188 → 189, total 2174 → 2175. **Measure it; do not adopt it.**

---

## 11. Two minor findings — recorded, not fixed, non-blocking

1. **The fixup commit message's opening line says "three checks" while its own
   body says "FOUR NEW CHECK CALLS".** Both are defensible readings — three
   claims plus one fixture call — but the header sentence is the one a reader
   skims, and a check COUNT is this batch's only witness to vacuity. The
   skimmable sentence is the wrong one to round down.
2. **The working tree carries an uncommitted modification to
   `doc/claude/signal_browser_2pane_batch/13_receipt.md`.** It is **not** this
   item's file and it predates the fixup commit by ~68 minutes (mtime 00:42:21,
   commit 01:50:36), so it is item 13's leftover and **not** an item-14 scope
   violation — but the tree is not clean. Land it or drop it before item 15.

---

## 12. Owed / for the next item

* **⛔ `BP78` is owed before item 14 can leave `[F]`.** §10.5 is the whole
  specification of it. Until it exists, `src/wave_viewer.tcl:10380-10383` is a
  written justification with no oracle, and a one-character relaxation of the
  guard collapses the two-pane browser with the suite green.
* **The eyeball is owed too, but AFTER the check.** §7.7 has gained a fifth
  step for exactly the `sash 0` path `V4` exposed. The ledger row stands but
  **must not be actioned while the item is `[F]`** — eyeballing a build whose
  known defect is invisible to the checks teaches nothing.
* **The recorded baseline is the FAILED tree's, and the code is NOT reverted.**
  Headless **1628** / X **2174** on `1990d00e`, verifier-measured, every
  per-file and per-suite figure exact. If a human reverts `91c6c828` or
  `1990d00e`, the LEDGER's baseline must be **re-measured** before item 15 runs,
  not arithmetically backed out.
* **Nothing downstream is blocked.** The dependency table gates on 13 and 16,
  not on 14; item 18 needs 12 ✔, 13 and 17b. The batch continues at item 15,
  whose `BD60`-`BD70` band was deliberately left untaken.
* **`.ph` is still class-filter blind** — carried in from item 12, untouched
  here on purpose, and still owed to whoever takes spec §7.2's three-state
  caption. `BD52`, `BX37`, `BX42`, `BX44`-`BX46`, `BH50`, `BH51`, `BH54` pin it
  byte-identically and all are green.
* **`browser_sash`'s read arm still answers the LAYOUT default, not the
  preference** — deliberately, because `sea.tcl` captures and restores that
  value. Two readers, two contracts. Any future item tempted to "unify" them
  should read §1's trap paragraph and S1's twelve reds first.
* **The three sabotage predictions the PLAN got wrong (§5 S2, S4, S7) are
  corrected in the source as well as here.** `BP69`, `BP70` and `BP10` are each
  the SOLE witness to their defect. **None may be weakened**, and `BP69` now has
  a second witness (`BP77`) only for the S7 mutation, not for its own claim.
