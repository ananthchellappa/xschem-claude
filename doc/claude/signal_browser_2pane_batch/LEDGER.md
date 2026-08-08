# Two-pane Signal Browser — batch LEDGER

> **⚠ ITEM NUMBERING.** Always write `two-pane item N`. The single-pane plan
> (`doc/claude/signal_browser_batch/PLAN.md`, items 1-16) is a different batch and
> the number 16 has already meant three things. The rule and its history are in
> `PLAN.md`'s header block.

This file is the **state of the batch**. The driver reads it and nothing else to
decide what runs next; the pipeline's ledger stage is the only thing that writes
it. `PLAN.md` stays the spec — it is never edited by the batch.

Scope: `PLAN.md` items **13, 14, 15, 16, 17b, 18, 19**. Everything else is done.

---

## Recorded baseline — the contract every verifier compares against

Measured **2026-08-08** after two-pane item 16, both arms green.
Re-measure before item 17b and record any drift here; do **not** silently adopt a
new baseline.

> **⚠ THE BASELINE MOVED WITH ITEM 16 — headless 1637 → 1649 over FIFTEEN files,**
> **X 2192 → 2215 over TWELVE suites.**
> **Reason, in one line:** item 16 added ONE file,
> `test_wave_sigbrowser_keys.tcl` (band `BK`) — **12** checks headless, **23**
> under X — and **every other file and every other suite is byte-identical in
> both arms**. The item-16 implementer RE-MEASURED the item-15 baseline on the
> unchanged tree first (headless 1637, X 11/11 2192, every per-file and
> per-suite figure EXACT, no drift), so the delta is attributable.
>
> **⚠ THE ITEM-16 NOTE BELOW SAYS "the two binding suites". IT IS THREE.**
> `test_bindings_file.tcl`, `test_keybindings_help.tcl` **and
> `test_key_graph_context.tcl`** are all outside both baselines, and the third is
> the one item 16 reds. Post-item ok-counts: **13 / 17 / 70** (key_graph_context
> was 69; +1 is the explicit absence claim item 16 added beside its inverted
> behavioural leg). A green 15-file / 12-suite run proves NOTHING about them.

> **⚠ THE BASELINE MOVED WITH ITEM 15 — headless 1628 → 1637, X 2174 → 2192.**
> **Reason, in one line:** item 15 added **18 check calls** and they are all in
> two files — `i14` 47 → **56** headless (`BD60`-`BD66b`, the nine PURE checks)
> and 91 → **107** in X (those nine plus `BD67`/`BD68`/`BD69`/`BD70`/`BD70b`/
> `BD70c`/`BD70d`), and `i1315` 188 → **190** in X only (`BP43a`'s new negative
> control and `BP47b`, the id-scheme control — the headless arm is unchanged at
> 88). Every other file and every other suite is byte-identical in both arms.
> Not adopted from the implementer's run: **both arms were re-measured
> independently by the item-15 verifier** — all 14 headless files run by hand
> (1637 / 0 fail, every per-file figure exact) and all 11 X suites through
> `xarm.sh suites` under Xvfb with `SUITE_TIMEOUT=400` (11/11, 2192). The
> item-15 implementer had also RE-MEASURED the item-14 baseline on the unchanged
> tree first — headless 1628, X 11/11 2174, every per-file and per-suite figure
> EXACT, no drift — so these deltas are attributable.
>
> **The item-14 note, kept:** **THE BASELINE MOVED WITH ITEM 14 — headless**
> **1619 → 1627, X 2149 → 2170,**
> **AND AGAIN WITH ITS FIXUP — headless 1627 → 1628, X 2170 → 2174.**
> **The fixup's whole delta is in `i1315`:** 87 → **88** headless (`BP75`, the
> both-arms SOURCE half) and 184 → **188** in X (`BP75` + `BP76`'s fixture +
> `BP76` + `BP77`). Every other file and every other suite is byte-identical to
> the item-14 figures below in both arms. The fixup closes two coverage holes
> the item's verifier found by sabotage — swapping `browser_state_apply`'s two
> fallback constants, and dropping the sash preference on a restore into a
> never-shown sidebar — **both of which were fully green across four and three
> suites respectively.** Receipt `14_receipt.md` §9.
> **Reason, per file:** `i1315` 80 → **87** headless / 167 → **184** in X
> (`BP62`-`BP68`, 7 both-arms PURE/SOURCE calls, plus the 10-call `BP69`-`BP74`
> real-viewer block); `grid` 230 → **231** / 355 → **356** (`GH8`'s per-row loop
> gained the sixteenth guide row); `modes` 485 → **488** in X only (`MG18`,
> three calls inside the existing `has_x` gate — the headless arm is unchanged
> at 212); `panes` **unchanged** at 15/81 (`BW59` restated in place, no new
> call). Every other file and every other suite is byte-identical in both arms.
> The item-14 implementer RE-MEASURED the item-13 baseline on the unchanged tree
> first — headless 1619, X 2149, every per-file and per-suite figure EXACT, no
> drift — so these deltas are attributable.
>
> **The item-13 note, kept:** THE BASELINE MOVED WITH ITEM 13 — headless
> 1618 → 1619, X 2136 → 2149.
> **Reason, in one line:** item 13 added 13 check calls and they are *all* in
> `test_wave_sigbrowser_panes.tcl` — `panes` 14 → **15** headless (the single
> both-arms SOURCE check `BW15`) and 68 → **81** in X (`BW15` + `BW68`-`BW78`);
> every other file and every other suite is byte-identical in both arms.
> Not adopted from the implementer's own run: both arms were **re-measured
> independently by the item-13 verifier** from a clean tree, and the headless
> per-file split below is that verifier's, parsed from each file's own
> `RESULT:` line. The previous baseline (item 12, `e5347591`) was headless
> **1618** / X **2136** with `panes` at 14 and 68.

**headless — 1637 checks over 14 files, 0 fail**
(`env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <f>` from the repo root)

| file | checks | file | checks |
|---|---|---|---|
| `test_wave_sigsearch` | 146 | `test_wave_sigbrowser_i14` | **56** |
| `test_wave_sigbrowser_sea` | 6 | `test_wave_grid` | 231 |
| `test_wave_sigbrowser` | 135 | `test_wave_modes` | 212 |
| `test_wave_sigbrowser_2pane` | 108 | `test_wave_viewer` | 57 |
| `test_wave_sigbrowser_panes` | 15 | `test_wave_markers` | 437 |
| `test_wave_sigbrowser_i11` | 50 | `test_wave_tabs` | 56 |
| `test_wave_sigbrowser_i12` | 40 | | |
| `test_wave_sigbrowser_i1315` | 88 | `test_wave_sigbrowser_keys` | **12** |
| | | **TOTAL** | **1649** |

**X arm — 11/11 suites**, run through `xarm.sh suites …` with `SUITE_TIMEOUT=400`.

> **⚠ MEASURED 2026-08-07: the Xvfb arm reproduces the `:0` arm EXACTLY.** All
> eleven per-suite counts identical, 11/11 both ways, **2136 checks** either way
> (that equivalence was established at the item-12 baseline; item 13 moves the
> total to **2149**, item 14 to **2170**, its fixup to **2174** and item 15 to
> **2192** — see the table; the equivalence itself is unaffected).
> So a number measured before the handback is directly comparable with one
> measured after it, and the unattended window costs no fidelity. What Xvfb
> cannot do is any claim needing a **window manager** — decoration, iconify,
> stacking, raise, geometry echo. Nothing in items 13-19 needs one; if something
> turns out to, it is an eyeball, not a check.

| suite | checks | suite | checks |
|---|---|---|---|
| `panes` | 81 | `2pane` | 108 |
| `sigbrowser` | 353 | `sigsearch` | 233 |
| `sea` | 79 | `grid` | 356 |
| `i11` | 74 | `modes` | 488 |
| `i12` | 123 | | |
| `i1315` | **190** | `keys` | **23** |
| | | **TOTAL** | **2215** |
| `i14` | **107** | | |

**Baseline fails: NONE.** Any fail is the item's problem. Known flakes that are
*not* regressions and must be re-run before being called a fail: `BR25`
(a `<Return>` through a bare `event generate`), `MG16` (key delivery), and a
whole-suite `NORESULT` from a WSLg Xwayland death (reachable only after the
handback — Xvfb is immune).

---

## The unattended window, and the handback

The user granted **7 hours of free test running from 2026-08-07 23:21 MST**, then
wants the GUI-test-gate widget raised so they have control again.

| | |
|---|---|
| deadline | **1786195286** = Sat 2026-08-08 **06:21:26 MST** |
| stored in | `DEADLINE` (epoch seconds) beside `xarm.sh` — the only clock anything reads |
| before it | private **Xvfb**. No gate, the user's screen untouched, Xwayland death cannot reach the batch |
| after it | the real **`:0` under the gate panel**, which `xarm.sh` **raises if it is not already up** |

**Every X-arm run goes through `xarm.sh`** (`suites` / `one` / `mode`) so the
switchover is automatic and no agent has to check a clock. Nothing else may call
`run_suites.sh`, `gated_xschem.sh` or `./src/xschem` for an X run.

Extending or ending the unattended window is a one-line edit to `DEADLINE`.

After the handback the panel's **Pause and Stop are the user's authority.** A run
that stalls may simply be paused — check `~/.claude/gui_test_gate/control`, wait,
and never work around it with `GUI_GATE=0`.

The `--nogui` headless arm needs no display at all and is unaffected by any of this.

---

## Ledger

Marks: `[ ]` not started · `[x]` done, test-verified · `[E]` done, **eyeball
owed** (a pixel/feel deliverable no test can judge) · `[D]` deferred, with reason
· `[F]` failed, needs a human.

- [E] 13 — `browser_reveal` / `browser_tree_apply` under collapsed-by-default
      **-> DONE-PIXEL (`9d5cdd26`)**, on `24fb6769`. `[E]` and never `[x]`: the
      deliverable is visible UI and no check in this batch judges pixels.
      — **13 check calls over 12 ids** (`BW15` + `BW68`-`BW78`; `BW74` is used
      twice, which is why `panes` moves +13 and not +12), `BX31` restated with a
      third leg. Headless **1618 → 1619**, X **11/11**, 2136 → **2149**
      (`panes` 68 → **81**, everything else byte-identical). **9/9 sabotages fire
      exactly on target** — 8 the item's own, plus `S9`, the verifier's own
      unnamed mechanism (it never writes `-open` at all: it `see`s the target's
      first CHILD, so ttk opens the target as an ancestor). `S9` reds `BW77` and
      nothing else.
      **⚠ FIXUP after an adversarial verifier rejected `24fb6769`.** Its own
      sabotage `V4` — an ADDITIVE re-open of the target guarded on
      `[llength [$tv children $id]] > 0` — was **fully green**: every live
      witness of the headline claim landed on `g:x1.x2`, which `BW69` itself
      asserts is CHILDLESS, and `-open` on a childless row is never rendered.
      `BW77`/`BW78` move the claim onto `g:x1`, which HAS children; `V4` now
      reds `BW77` and nothing else. Two bookkeeping faults fixed with it: the
      header's §4.2 citation for "leave the target closed" is **R3**, and this
      item is `[E]`, not `[x]`.
      **⚠ ONE PLAN CLAUSE REFUSED**: the selection's ancestor chain is NOT
      unioned into the applied open set — spec §4.2 forbids it and `BP54` is
      named there as a check that "stays green". The union is now sabotage S4
      and reds `BW76`+`BP53`+`BP54` across three files. See `13_receipt.md`.
- [F] 14 — Persistence: `sash` / `devint` / `srccur` **-> FAILED (`1990d00e`).**
      **Rejected a SECOND time by its verifier, for the same class of defect as
      the first rejection.** The failure block is at the end of this item; the
      record of what did land is kept in full below it. Had it passed it would
      have been `[E]` and never `[x]`: the deliverable is a remembered split and
      two remembered boxes, and no check in this batch judges what the restored
      sidebar LOOKS like. Eyeball script: `14_receipt.md` §7.7 — **not to be
      actioned while the item is `[F]`.**
      — **21 new check calls** (`BP62`-`BP74` in `i1315`, `MG18` in `modes`, one
      more leg through `GH8`'s per-row loop) + **6 restated, none deleted**
      (`BP10` `BP13` `BP43` `BP45` `BW59` `GH8`). Headless **1619 -> 1627**,
      X **11/11**, 2149 -> **2170**. **8/8 sabotages fire.**
      **⚠ THE ITEM IS ONE LINE.** `browser_sash`'s read arm used to SEED
      `browsersash($token) = 0.55`, and `browser_show` calls it twice on its
      pack branch — so "has a preference" and "has been shown" were the same
      fact and spec §9's `sash 0` was not expressible. The layout default is now
      a LOCAL; `browser_sash_pref` (pure) is the persisted reader and
      `browser_sash_drop` + a `<ButtonRelease-1>` on `$f.pw` is the ONLY writer.
      The accessor's return contract is deliberately UNCHANGED — `sea.tcl`
      captures and restores it, and a pref-returning read arm would leave the
      sea squeezed for the rest of that file.
      **⚠ THREE SABOTAGE PREDICTIONS WERE WRONG AND ARE CORRECTED IN THE
      RECEIPT.** (a) the pixel-persisting drop reds `BP70` ALONE — the
      accessor's `0 < want < 1` guard makes it fail CLOSED, so `BP72` cannot
      see it; (b) inserting the keys mid-dict reds `BP10` ALONE — `browser_state`
      starts FROM the default dict and `dict set` preserves key position, so the
      predicted `BP41`/`BP42`/`MG9` cascade is impossible; (c) re-seeding the
      sash reds `BP69` ALONE — `BP41`/`BP42`/`MG9` all read never-shown
      sidebars. **`BP69`, `BP70` and `BP10` are each the SOLE witness to their
      defect; none may be weakened.**
      **⚠⚠ REJECTED BY ITS VERIFIER, THEN FIXED UP.** Two sabotages the item had
      NOT named stayed **fully green**: swapping `browser_state_apply`'s two
      fallback constants (`i1315` 184, `panes` 81, `modes` 488, `sea` 79 — four
      suites, zero reds) and dropping the sash preference on a restore into a
      never-shown sidebar (`i1315` 184, `panes` 81, `sea` 79). Both are LIVE
      paths: `ase_window.tcl` persists the session `viewer` dict to a FILE, so
      every pre-`91c6c828` state file enters the key-absent branch; and the
      hidden-sidebar store is the behaviour `declaredLimits` chose on purpose.
      The fixup adds **`BP75`** (SOURCE, both arms), **`BP76`** (a legacy dict
      applied to a window driven to the OPPOSITE pair) and **`BP77`** (a restore
      into a never-shown sidebar) plus one fixture call — **4 new check calls,
      none restated, none deleted** — taking headless **1627 -> 1628** and
      X **2170 -> 2174**, all of it in `i1315`. It also corrects a **false
      sabotage claim shipped in `src/wave_viewer.tcl`** (the comment still
      predicted S7's four-oracle cascade after the receipt had disproved it;
      re-measured on the fixup tree S7 reds **`BP69` + `BP77`**, 186/2, and
      `BP41`/`BP42`/`MG9` measure GREEN) and removes the **two bare proc names**
      the item wrote into a comment, which would have pre-poisoned any future
      `BD06`/`BW59`-style count. Receipt `14_receipt.md` §9. **Next free `BP78`;
      `BD60`-`BD70` still item 15's.**
      **⚠ A COVERAGE HOLE WAS MEASURED AND CLOSED MID-ITEM.** Restoring a class
      box by `invoke` (a RELATIVE toggle) was caught only by SOURCE checks:
      every behavioural round trip asks for the OPPOSITE of the fresh default,
      so one flip lands right by coincidence. `BP74` gained an IDEMPOTENCE leg
      (apply the same dict twice) and the sabotage was re-run — it now reds
      `BP74` behaviourally.
      **⚠ `BW24` was NOT restated**, contradicting items 12 and 13's forecasts:
      `browser_build` still seeds `0`/`1` and a restore only overrides when a
      state dict is applied. See `14_receipt.md`.
      **⚠⚠ FAILED (`1990d00e`) — A THIRD COVERAGE HOLE OF THE SAME FAMILY, FOUND
      BY THE VERIFIER'S OWN FRESH SABOTAGE `V4`, IS STILL OPEN.** ONE CHARACTER
      in the sash accessor's store guard (`src/wave_viewer.tcl:8163`,
      `$want > 0` -> `$want >= 0`, i.e. stop REFUSING spec §9's `sash 0`) goes
      **fully green**: `i1315` **188 ALL PASS** (count held) and `sea` **79 ALL
      PASS**, zero reds — while the same driver in the same session red `V1`
      (`BP75`+`BP76`), `V2`-literal (`BP70`+`BP72`+`BP77`), `V2b` (`BP77`) and
      `S7` (`BP69`+`BP77`) exactly, each with a printed proof-of-mutation. It is
      NOT defensive code: the item's own comment at
      `src/wave_viewer.tcl:10380-10383` cites that guard BY NAME as the reason
      the sash restore "needs no gate of its own", and **nothing measures it** —
      the third written justification this item ships with no oracle behind it.
      It is MORE live than either hole the fixup closed: `browser_state` writes
      `sash 0` for every user who never dragged the sash, so ANY restore of a
      browser dict from such a user (changed width, filter, dest, open set,
      selection — anything) runs that line with `$want` 0. Measured on both
      trees with the same probe: shipped `pref=0.42 frac=0.42 px=210`;
      sabotaged `pref=0 frac=0.0 px=0` — **the tree pane collapses to nothing
      and the two-pane browser is destroyed, silently, with every check in the
      batch green.** Remedy is ONE check, **`BP78`** (free, and the file header
      already reserves it), in the same X block: apply
      `[dict replace $bp_st14 shown 1 sash 0]` to a window carrying a known
      non-zero preference and assert the fraction and `sashpos 0` are unchanged
      and non-zero, with a leg proving the preference was really there first.
      Receipt `14_receipt.md` §10.
      **⚠ THE BASELINE HELD AND THE CODE IS NOT REVERTED.** The verifier
      re-measured both arms independently on `1990d00e` — headless **1628 /
      0 fail**, X **11/11, 2174**, every per-file and per-suite figure EXACT
      against the table above — and MEASURED the source-diff provenance rather
      than taking it (`git diff 91c6c828 1990d00e -- src/wave_viewer.tcl`
      filtered for non-comment `+`/`-` lines yields **zero**, so the fixup's
      behaviour-change-free claim is true line by line). The recorded baseline
      above is therefore the FAILED tree's. **If a human reverts `91c6c828` or
      `1990d00e`, that baseline must be re-measured before item 15 runs.**
      Nothing downstream is blocked — the dependency table gates on 13 and 16,
      not on 14 — so the batch continues at item 15.
      **⚠ Two minor findings, recorded not fixed.** (a) The fixup commit's
      opening line says "three checks" while its own body says "FOUR NEW CHECK
      CALLS"; both readings are defensible (three claims + one fixture call) but
      a check COUNT is this batch's only witness to vacuity, so the skimmable
      sentence is the wrong one to round down. (b) The tree carries an
      **uncommitted** modification to `13_receipt.md` (mtime 00:42:21, ~68 min
      BEFORE the `1990d00e` commit at 01:50:36 — item 13's leftover, not an
      item-14 scope violation). Land it or drop it before item 15.
- [E] 15 — R7: All-DBs headers + a design root per DB **-> DONE-PIXEL
      (`e1cfd5ff`)**. `[E]` and never `[x]`: the deliverable is a tree whose top
      level changes shape on screen, and no check in this batch judges pixels —
      the new checks judge widget STATE (ids, text, `-open`, selection), and the
      X arm ran under **Xvfb**, with no window manager. Eyeball script:
      `15_receipt.md` §11.
      — **18 new check calls** (`BD60`-`BD66b` PURE + `BD67`-`BD70d` in `i14`,
      `BP43a`'s negative control + `BP47b` in `i1315`) + **15 restated, none
      deleted**, three of which are TOMBSTONES whose own comments already spelled
      out what item 15 owed (`BD48c`, `BD50c`, `BP43a`). Headless **1628 →
      1637**, X **11/11**, 2174 → **2192**. **7/7 of the item's own sabotages
      fire**, plus **three the verifier invented** (`VS1`/`VS2`/`VS3`) and a
      verbatim replay of `S6`; every positive control held and the tree was
      restored byte-exact each time.
      **⚠ THE PLAN'S CENTRAL PRESCRIPTION WAS REFUSED, ON A MEASUREMENT.** PLAN
      item 15 gives group 0 a `d:0|` prefix. It gets a HEADER and keeps its BARE
      ids. Spec §4.3's closing sentence rules the same way, but the deciding fact
      came out of the FIRST RED RUN: the prefix would carry the DB's **registry
      index**, which is not a property of the design, and `i1315`'s restore
      fixture moves the current DB from slot **1** to slot **0** — so every
      persisted `d:1|g:x1.x2` would name a row that no longer exists and the
      user's selection and open set would silently evaporate, reding
      `BP52`-`BP55` with **no defect in the persistence code at all**. The
      verifier reproduced this from the other side: sabotage `VS3` (collapse
      "absent" and "deliberately empty" prefix) reds 17 in `i14` and 9 in
      `i1315` **including `BP52`-`BP55`**. Blast radius fell from ~20 existing
      checks to 15; six the PLAN's design would have re-keyed (`BD51b`, `BD54`,
      `BD58b`, `BP52`, `BP54`, `BP55`) stayed byte-identical, and that is the
      evidence for the ruling. `BP47b` pins the drift AND the survival, on
      literals rather than on "they are equal".
      **⚠ FOUR MORE PLAN ERRORS, EACH MEASURED.** (a) `BD67`'s prescribed
      `db_label $cur` throws `wrong # args` — the proc takes TWO. (b) `BD68`'s
      `{d:0 d:1}` and `BD70`'s `{d:0|g:}` name the WRONG DB: in the `i14` fixture
      the current DB is registry slot **1** (`BD31`/`BD31b`/`BD43` pin it), so
      every X check now derives its header id from the ENGINE and `BD67` asserts
      the derived index itself. (c) `BD65`'s id is backwards for that fixture.
      (d) The break-list names **2** existing checks and describes `BD51` in a
      form two-pane item 10 had already replaced; the real radius is **15**.
      **⚠ ONE VACUITY CAUGHT BY THE RED RUN, FIXED AND NOT EXCUSED.** `BD69` as
      first written asserted item 10's already-shipped box-OFF shape and PASSED
      before the code existed. Its reading became a CAPTURE folded into `BD68`'s
      own tuple as leg 1, and the `BD69` id was re-spent on a red-before claim —
      R5's guard that a search keystroke never re-opens a DB header the user
      collapsed. **`BD69` is the SOLE witness to the mirror defect** (opening the
      header on EVERY populate, the verifier's `VS2`); `BD70b` is the sole
      witness to the opposite one (`S6`, never opening it). Neither may be
      weakened. ⚠ `15_receipt.md` shipped one sentence misattributing `S6` to
      `BD69`; corrected in §7 after the verifier replayed `S6` verbatim.
      **⚠ TWO SPEC CLAUSES DIVERGED FROM, BOTH FLAGGED.** §4.1's "this is the
      single change in `browser_populate`" becomes two (the current DB's header
      is born open as well as its root, or R4's selected root sits inside a
      collapsed parent and §4.2 forbids `see` there — `BW53`); and §4.3's
      "unlabelled" clause is now stale. **Item 19 owns the spec edit.**
      **⚠ SIX DECLARED LIMITS, two of them asserted as VALUES in checks rather
      than only in prose** (`BP53` leg 4, `BD70d`). The one item 16+ should know:
      a persisted **DB-header** open state does not survive a registry renumber —
      §4.2 says the persisted `open` set wins and it named the old slot, so the
      header comes back COLLAPSED. Selection and instance-node collapse survive,
      which is the whole point of the unprefixed ids. **Next free `BD71` /
      `BP78`.**
- [x] 16 — R9: Ctrl-L → Ctrl-B, incl. the C-table row deletion
      Receipt `16_receipt.md`. **Both baselines RE-MEASURED EXACT on the unchanged
      tree first** (headless 1637/0, X 11/11 2192, every per-file and per-suite
      figure), so every red is attributable. New file
      `tests/headless/test_wave_sigbrowser_keys.tcl`, band **BK01-BK18**,
      **NEXT FREE BK19** (BK20+ is item 17b's). Headless **1637 → 1649** over
      **15** files, X **2192 → 2215** over **12** suites; the whole delta is the
      new file (+12 / +23) and every other file and suite is byte-identical.
      **⚠ THREE out-of-baseline suites, not the two this LEDGER's item-16 NOTE
      names.** `test_key_graph_context.tcl` is in NEITHER baseline and is the one
      this item actually reds — twice. Pre/post ok-counts: bindings_file 13/13,
      keybindings_help 17/17, **key_graph_context 69 → 70**.
      **⚠ TWO PLAN CHECKS WERE VACUOUS AND WERE REPLACED.** `BK02` as prescribed
      searched a literal it had written itself (green before, after, and under
      the sabotage it was named for); it now EXTRACTS `set fwd [expr {…}]` from
      the source and EVALUATES it (red `1 1 0 1 1 1` → green `1 0 0 1 1 1`), with
      the membership claim moved to `BK03` on the LIVE `graphkeys`. `BK06` used
      `[xschem get sym_txt]`, which **does not exist** — it returns `""`, so the
      PLAN's landmine witness would have compared `""` to `""` and passed with
      sym_txt flipped. Everything reads `$::sym_txt`.
      **⚠ THE SABOTAGE THAT DECIDED THE ITEM.** `S1b'` keeps the carve-out text
      byte-identical and re-opens the 98 hole alone: `BK01`/`BK02` stay GREEN and
      **`BK12` reds `{1 1 1 0 1}`** — forwarded, `sym_txt` FLIPPED, `graph_flags`
      unmoved, i.e. the forward reached the C switch's ControlMask arm. Had it
      red nothing, the two behavioural checks would have been redundant with the
      source greps. `S3` (delete the bare-b idle row too) **TIMED OUT** — bare `b`
      falls through to the merge-schematic modal — which is why a sabotage filter
      MUST count TIMEOUT as a red; its isolating evidence was
      `test_key_graph_context:323` going red in the same run.
      **⚠ THE PLAN'S BREAK LIST IS WRONG TWICE.** It says S6 reds "GH1 alone";
      measured radius is **8 legs across 3 files** (GH1+GH3 headless, GH1+GH3+GH5
      +GH6 under X, BS09 ×2). And it never names `test_key_graph_context.tcl` at
      all, which is the item's real blast radius.
      **⚠ TWO DECLARED LIMITS, both from measurement.** (8) `graph_use_ctrl_key 1`
      users lose their only cursor-B chord (default is commented out; bare `b`
      measured still working, `graph_flags` 0 → 4). (9) Ctrl+b over a graph
      EMBEDDED IN A SCHEMATIC now toggles `sym_txt`, **measured 0 → 1** — a
      schematic-editor behaviour change no part of the PLAN mentions, pinned by an
      inverted check rather than left for the next reader to file as a bug.
      **⚠ REGENERATION TRAP.** `save_input_bindings_file` writes the LIVE table and
      the shipped csv is LOADED INTO IT at startup, so regenerating in place
      reproduces the deleted row **moved to the end of the file** — a diff that
      reads as harmless reordering. Move the csv aside and generate from the
      builtins. Spec §8.1 anchors corrected (all stale by ~+2300), its "nothing
      user-visible is lost" and "the schematic side is untouched" both replaced
      with the measurements, §10 gained limits 8 and 9, §13 gained the eighth file.
      **No eyeball owed** — every claim is a bind, a dump row, a byte-compare or a
      Tcl variable.
- [ ] 17b — R10: `Ctrl-Alt-V` via the C action registry (the half `882694cc` left)
- [ ] 18 — R12: auto-tick, reveal, and say so
- [ ] 19 — Docs, oracles, the four-file lockstep, 0217 closed

### Dependencies — the driver enforces these before launching

| item | needs | notes |
|---|---|---|
| 13 | 10 ✔ | ready |
| 14 | 12 ✔, 13 | **hard**: persistence with nothing to persist is not implementable |
| 15 | 4 ✔, 8 ✔, 10 ✔ | ready; independent of 13/14 |
| 16 | 9 ✔ | ready; **touches C + the generated key table** |
| 17b | 16 | **hard**: there is no `Control-Alt-v` binding anywhere in `src/` yet |
| 18 | 12 ✔, 13, 17b | |
| 19 | all | runs last regardless, and documents whatever actually shipped |

**Run order: 13 → 14 → 15 → 16 → 17b → 18 → 19.** Strictly sequential, never two
in flight — every item touches `src/wave_viewer.tcl` and the same test files.

A `[D]`/`[F]` on **13** blocks 14 and 18; on **16** blocks 17b and 18. In both
cases the driver skips the dependants with `[D] blocked by item N` and carries
on to the next runnable item rather than stopping the batch. **15 and 19 always
run** — 15 depends on nothing outstanding and 19 documents whatever shipped.

---

## Eyeball queue

Pixel items may **never** be marked `[x]`. `[E]` + a row here.

| item | commit | what to look at | eyeballed? |
|---|---|---|---|
| 16 | *(this item)* | **NONE OWED.** Every claim is a bind, a `xschem bindings dump` row, a file byte-compare or a Tcl variable — there is no pixel deliverable. The one thing a human might still want to *feel* is the chord itself: press **Ctrl-B** over a plotted strip and confirm the sidebar toggles and the symbol text on the schematic behind it does **not** change. That is `BK12`+`BK18` restated in fingers, not a gap in coverage. | n/a |
| 15 | `e1cfd5ff` | With **two raws loaded**, tick the **All-DBs** box. The tree's TOP LEVEL must become one row per database — **the current one included** — and each header must carry that database's **own** design root, named for **its own** raw (not the current design's name under a foreign header). The current DB's header **and** root come back **OPEN**; the foreign header stays **COLLAPSED**. Then collapse a header by hand and **type in the search bar** — it must stay collapsed. Judge indentation, nesting legibility and label truncation on a **real** raw path. Full script: `15_receipt.md` §11. **A one-DB tree answers nothing**, and neither does the box left OFF. | ☐ |
| 14 | *(this item)* | Drag the **sash** small, tick **Show device internals**, save/quit/reopen: both must come back. Then reopen into a **shorter** window — the sash must return to the same *proportion*, not the same pixel row. A window you never drag must have **no `browser` key** in its state at all. Full script: `14_receipt.md` §7.7. | ☐ |
| 13 | `24fb6769` + `9d5cdd26` | **Tools → Show in Signal Browser** (Ctrl+5 today; R10's Ctrl-Alt-V is item 17b's and does NOT exist yet) with an instance that **CONTAINS other instances** selected. (a) the tree row scrolls in, is selected, expander stays **CLOSED**; (b) the LOWER pane fills with **that node's own-level signals**; (c) clicking the expander still opens it. Full script: `13_receipt.md` §9. **A LEAF instance answers nothing** — that node class is exactly where the batch's checks were blind. | ☐ |

---

## Carried in from item 12 — read before item 14 or 18

* **`.ph` is still class-filter blind.** It is `"[llength $names] of $total
  signals"` — bar-matched only — so R11's boxes move the tree, the sea and
  `browserseaent` but not that line. Spec §6 lists the status line in its "one
  consistent set"; §7.2 puts the per-node caption on `$f.pw.sea.st` instead.
  **Untouched on purpose**: `BD52`, `BX37`, `BX42`, `BX44`-`BX46`, `BH50`,
  `BH51`, `BH54` pin `.ph` byte-identically. Whoever takes §7.2's three-state
  caption settles it; nobody else may move it.
* ~~**`browser_state` is untouched**, so both R11 boxes reset to 0/1 on every
  window build. That is item 14's whole job.~~ **SETTLED by two-pane item 14:**
  all three fields now ride in the `browser` sub-dict. The build still seeds the
  boxes; a restore overrides.
* **Item 12's build-time default pin is `BW24`, not `BW56`.** ~~If item 14 makes
  the defaults come from a persisted file, `BW24` is the check to restate.~~
  **It did not**: `browser_build` still seeds `0`/`1` and only an applied state
  dict overrides. `BW24` is green untouched, and that is the record of the
  decision rather than an oversight.
