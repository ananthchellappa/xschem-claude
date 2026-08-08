# TWO-PANE item 19 — Docs, oracles, the four-file lockstep, 0217 closed

**Status: DONE, then FIXED UP once.** Committed, not pushed.
Everything below is **measured**, not quoted from the PLAN.

> ## ⚠⚠ FIX-UP (2026-08-08) — read this before the numbers below
>
> Item 19's verifier **rejected the item** and was right twice. Both findings are
> repaired in the fix-up commit; the sections below are the ORIGINAL item's
> record and are corrected in place where they were false.
>
> **1. THE ITEM'S OWN THESIS FAILED ON THE ITEM'S OWN DELIVERED PROSE.** The
> verifier reverted `doc/waveform_viewer_guide.html` §11.7 *"What is
> remembered"* wholesale to its pre-two-pane single-pane wording — dropping the
> sash split, **both** class-box names and the entire fraction-vs-pixels
> paragraph — and **all four suites that read the guide stayed ALL PASS with
> every count unchanged** (grid 267, sigbrowser 135, i12 40, keys 25). Zero
> reds, zero dropped legs. §11.7 is the **only** user-facing documentation of
> TWO-PANE item 14's whole feature and the exact text item 14's still-unticked
> eyeball row asks a human to confirm. `GS24` asks the **whole file** and all
> four of its phrases also occur in §11.0/§11.2; `GS26` pins the Ctrl-B prose
> only; `GH10` counts headings, which a body rewrite leaves alone. **`GS28`**
> (5 legs) closes it, section-scoped. **The general rule: a doc oracle must be
> scoped to the section it is the oracle for.**
>
> **2. A CORRECTED NUMBER SURVIVED AS A STALE COPY 415 LINES UP IN THE SAME
> FILE, AND THIS RECEIPT SAID OTHERWISE.** §8 below claimed the wrong
> `tb_charge_pump` triple lived in **two** places and that item 19 "corrected
> both files in one commit". It lived in **three**: the source comment, §5.4,
> and **§0's opening motivation table** — the most-read table in the document —
> which kept `| tb_charge_pump | 1191 | 110 |` under the header *"of which are
> design nets"*. Provably the same metric: the `tb_bandgap` row above it reads
> `424 | 139` and §5.4 states *"Design nets only would be 139"*. **Independently
> re-measured at the fix-up** with the shipped procs on the committed fixture:
> histogram net **120**, srcbranch **26**, devmeas **283**, devnode **762**
> (sums to 1191); `1191 → 146 → 120`, nets-only **119** (the 120th is `time`,
> the sweep variable, class `net`). Corrected to **119**, and **`GS29`** (2
> legs) now forbids the recurrence by requiring §0's table and §5.4's
> `nets-only **N**` to agree, with the `tb_bandgap` row as the positive control.
>
> **3. Two MINOR overclaims, both narrowed rather than argued away.** `GH11`'s
> declared limit said it cannot see a bind on a **literal** path; the pattern
> `^\s*bind \$[a-z]` also cannot see one spelled from an **uppercase-initial
> variable** (`bind $Foo <…>`). Now stated as *"every bind spelled from a
> lower-case-initial variable is counted"*. And `GS22`'s **title** claimed the
> spec "NAMES every proc the two-pane batch minted" when the roster is 17
> hand-picked names — `browser_sash_pref`, `browser_sash_drop`,
> `browser_tree_state`, `browser_tree_apply`, `browser_device_paths`,
> `browser_sea_layout` and `browser_sea_names` are covered only indirectly by
> `GS23`'s exact 57. The in-file comment was honest; the title was not, and
> **titles are what a later reader trusts**. Retitled, and the comment now names
> the seven omissions.
>
> **Fix-up totals: headless 1705 / 0 over 15 files** (only `grid` moved,
> 267 → **274**); **X 11/12 measurable = 2162**, every per-suite figure equal to
> the verifier's post-item numbers plus the same +7 in `grid` (356 → 392 → 399).
> Out-of-baseline 13 / 17 / 70 unmoved. **`test_wave_sigbrowser_i12`'s X figure
> could not be measured** — see the declared limit in §9.
>
> **Nothing here is visually verified.** The eyeball queue keeps its four
> unticked rows, and §11.7 is now doubly owed one: an oracle pins the *words*,
> not that the sash and the boxes behave as the words say.

---

## 1. What this item did NOT do, and why

Half the item's stated scope was already landed and one bullet was actively
wrong. None of that is a reason to defer; all of it is a reason to say so.

| PLAN bullet | disposition |
|---|---|
| `0217-*.md` closed **and `git add`ed** — "it is currently **untracked**" | **ALREADY DONE.** `git ls-files doc/claude/issues/0217-*` returns the file; `git status --porcelain doc/claude/issues/` is empty; it was committed in `422b3f55` and its header already read `Status: **FIXED** 2026-08-07`. Both halves. |
| fix §5.4's stated rule to the measured hybrid (§0.1) | **ALREADY DONE**, and the spec is *more* correct than the PLAN: it carries the leading-`@` strip and corrects the PLAN's own claim of zero label collisions to a measured **four**, pinned by `TP19`. |
| fix §14's device-node counts (78→84, 278→303) | **REFUSED — executing it injects an error.** §3.3 already carries 84/303 *and rules in writing* that §14's 78/278 is a **different metric** (nodes minted *only* by device paths) inside an audit of another document's verbatim awk. Both numbers are right about their own question. The refusal is now **written into §14** so nobody executes the bullet later. |
| fix M6's 11→9 | **ALREADY DONE** — §2.2 M6 reads "9 of 22". |
| add declared limit 8 (`graph_use_ctrl_key`) | **ALREADY DONE**, and there is a **ninth** (the Ctrl+b / `sym_txt` consequence). |
| record the `d:N|` fix as closed | **HALF DONE.** §11's table already said FIXED; the numbered **issue file did not exist**. Filed as **0225** (next free measured; 0224 was the highest) and cited. |
| "the fourteen `data-bseq` rows final" | **WRONG NUMBER — measured SIXTEEN**, and `GH8`'s literal already said 16. History: 6 → 7 → 14 → 15 → 16. **Item 19 added and removed no row.** |
| §9.1's Ctrl-B row | **ALREADY DONE** by two-pane item 16. |
| §11 prose rewritten for two panes | **GENUINELY OWED, and it was the item's real work.** |

**Still owed after this item, recorded not fixed:** §7.2's three-state caption
(the `.ph` count line is still class-filter blind), and `browser_show_path`'s
stale bar clause. Neither is item 19's, and twelve byte-identity checks pin the
first.

---

## 2. Check ids — MEASURED before use

**The PLAN's `GS10`-`GS15` are ALL FIVE SPENT.** `GS` names two unrelated blocks
inside `test_wave_grid.tcl` — the spec oracles `GS0`-`GS3` and the
grid-selection-survival block `GS0`-`GS14`, no gaps — **and** the prefix is owned
by `test_wave_sigsearch.tcl` (`GS01`-`GS21`). First id colliding with nothing in
either owning file: **`GS22`**. Taken: **`GS22`-`GS27`**, and **`GS28`-`GS29`**
at the fix-up (band re-measured then: `GS` was spent to exactly 27 across every
`tests/headless/*.tcl` and every batch doc, so 28/29 collide with nothing).
**Next free: `GS30`.**

`GH11` free (highest was `GH10`). `BP78` free and reserved by
`test_wave_sigbrowser_i1315.tcl:45`'s own header. Adjacent bands re-measured so
nothing was taken by accident: `BT`→47, `BX`→56, `BD`→70 (item 15's, untouched),
`BW`→78, `BK`→43.

---

## 3. The checks

**`GH11` + its control** (`test_wave_grid.tcl`, both arms). `GH8` and `GH9` are
both anchored on the literal `bind $f.`; a gesture bound through a widget alias
is invisible to **both**, so a shipped undocumented gesture is a state the pair
reports as green. `GH11` counts the wider `^\s*bind \$[a-z]` and requires
equality with `GH9`'s counter. **The control's floor is 16, not the PLAN's 14** —
a 14-floor survives deleting two binds.

**`GS22`** — the parent spec names the batch's **seventeen load-bearing** procs,
with the source-side existence count in the **same tuple** so the list can never
name a ghost. **`browser_tree` and `browser_sea` are deliberately absent** —
neither proc exists (two-pane item 1 never landed, `09_receipt.md:26-27`), and
naming them would have red exactly two `GS1` legs.

> ⚠ **TITLE CORRECTED AT THE FIX-UP.** It read *"NAMES every proc the two-pane
> batch minted"*, which the roster does not do — it is 17 hand-picked names, and
> `browser_sash_pref`, `browser_sash_drop`, `browser_tree_state`,
> `browser_tree_apply`, `browser_device_paths`, `browser_sea_layout` and
> `browser_sea_names` are covered only indirectly by `GS23`'s exact 57. The
> in-file comment was already honest about the roster being hard-coded; the
> title was not, and **titles are what a later reader trusts**. The comment now
> also names the seven omissions so the gap is legible without a diff.
The PLAN's "reds existing: …" column did not mention `GS1` at all.

**`GS23`** — duplicate-freeness **and the exact length** (57). An exact ledger,
not a floor, because a file that aborts early prints a plausible fail count while
silently dropping `GS1` legs; the LENGTH is the only witness to that.
`GS0`'s floor is separately moved `>= 20` → `>= 48` in place.

**`GS24`** — the guide's browser section names both panes and both checkbox
labels. **`GS25`** — the `data-seq` table: no row for the renamed chord, none for
the schematic chord, and Ctrl-B and Key-E ARE there, all four in one tuple.
**`GS26`** — the same claim one surface over, on the **prose**. **`GS27`** — 0217
and 0225 are cited, and the cited total is exactly 8.

**`BP78`** (`test_wave_sigbrowser_i1315.tcl`, **X-only**) — the store guard
itself. Seven legs in one tuple: the preference before, the pane really mapped,
the accessor's return on a refused `0`, the untouched preference, the untouched
live split, and a **positive control** driving `0.30` through the same call. It
restores the borrowed fraction **after** every leg is asserted, to `BP77`'s own
0.44, so what `BP47` inherits is byte-identical to before.

---

## 4. THE RED RUN, and the three checks that were green before the work

Red run: **245 checks, 10 fail** on `test_wave_grid` — exactly the predicted
count. Red: `GS0`, four `GS2` legs, `GS22`, `GS23`, `GS24`, `GS26`, `GS27`.

**THREE CHECKS PASSED BEFORE THE ITEM'S DOCS EXISTED and they are declared, not
hidden:**

* **`GS25`** — two-pane item 16 had already renamed the chord in the *table*, so
  `{0 0 1 1}` was already true. It is a **regression GUARD**, not red-first
  coverage.
* **`GH11`** and **`GH11 (CONTROL)`** — `bind $[a-z]` already equalled
  `bind $f.` = 16. Also guards.

Each already carries its positive control in the **same tuple** (`GS25`'s two
positive legs; `GH11`'s `>= 16` counter), so none can go green on a stripped
guide or a renamed proc. **Their only positive evidence is the sabotage run**,
and `S3`/`S4(iv)`/`S5b` supply it. `BP78` is the same shape one file over: it
closes a coverage hole rather than pinning new code, and `S6` is its evidence.

---

## 5. Runs

**Both baselines RE-MEASURED EXACT on the unchanged tree first**, so every red
afterwards is attributable.

| arm | before | after |
|---|---|---|
| headless, 15 files | **1662 / 0**, every per-file figure exact | **1698 / 0** |
| X, 12 suites (`xarm.sh suites`, `SUITE_TIMEOUT=400`) | **2244** | **2281** |
| out of both baselines, X-only | 13 / 17 / 70 | **13 / 17 / 70** |

**Only two figures moved:**

* `test_wave_grid` **231 → 267** headless and **356 → 392** under X — the same
  **+36**, and every term is accounted for: `GS1` **+19** (contract list
  38 → 57), `GS2` **+6** (roster 23 → 29), `GS3` **+2** (6 → 8 cited issues),
  `GS22`-`GS27` **+6**, `GH11` **+2**, `GH10` **+1** (the §11 rewrite adds one
  NEW distinct §-ref, `§11.2`; 14 → 15 distinct).
* `test_wave_sigbrowser_i1315` **190 → 191 under X only** (`BP78` needs a mapped
  panedwindow); its headless count is **88, unchanged**.

Every other per-file and per-suite figure is byte-identical in both arms.
Re-confirmed on the **post-sabotage** tree through `xarm.sh suites`:
`grid` 392, `i1315` 191, `panes` 81 (control).

### 5.1 ⚠ The `:0` arm was unreliable today, and none of it is a regression

* **Three whole-suite deaths**, each with `X connection to :0 broken`: `i12` and
  `i1315` pre-item, `sigbrowser` post-item. The gate **panel itself** died and
  was revived once (`events.log`).
* `i12` died four times running on `:0` at three different points, and answered
  **126 / 0** first try under **Xvfb**. `i1315` answered **190 / 0** under Xvfb.
  That is how the pre-item baseline was made attributable rather than merely
  re-attempted.
* One `BP56` FAIL post-item — "the restored width was really applied to the
  frame", `{240 240}` vs `{260 260}` — a **window-manager geometry echo**, same
  class as the known `BP72`/`BP77` flakes. Passed on re-run on `:0` **and** under
  Xvfb (191 / 0 both).
* `test_key_graph_context` **TIMEOUT at 400 s on its first batched attempt**,
  then **70 / 0 standalone twice** — exactly the documented behaviour.

`GUI_GATE` was never set to 0 on `:0`, the panel was never killed, and no bare
`./src/xschem` loop was used for an X-arm run. Xvfb was used only to
re-attribute a run that had already died on `:0`.

---

## 6. Frozen oracles, re-grepped after the work

| oracle | expected | measured |
|---|---|---|
| `GH0` | 16 `data-seq`, 11 `data-accel` | **16 / 11** |
| `GH8`/`GH9` | 16 `data-bseq`, 16 `bind $f.` | **16 / 16** |
| `GH11` | `bind $[a-z]` == `bind $f.` | **16 == 16** |
| `GH10` | every guide `§N` resolves | 15 distinct, all resolve |
| `BW59` | `browser_devint` 5, `browser_srccur` 5 | **5 / 5**, and `browser_alldbs` **2**, `device internals to reach` **1** |
| `BT09` | guide 16 / 11 | green |
| `BX13` | grid literals 16 / 11 as **text**; guide legs `{0 0 0}` + `Key-E` 1 | green |
| `GS3` | every cited issue resolves to exactly one file | **8 / 8** |
| the twelve `.ph` byte-identity pins | untouched | untouched — item 19 writes no status string |
| `BP54`/`BP53`/`BW76` | the ancestor-chain union stays refused | green; §4.2 now says so in writing |

---

## 7. Sabotages — 8 run, 8 fired

Driver: `flock`ed, `trap … EXIT INT TERM` restoring from a **byte-exact backup**
(never `git checkout --`, which would have deleted the uncommitted item),
asserting the **pre-state check count** before patching, proving the mutation
reached **disk**, and `diff`ing the restore. Its filter counts `NORESULT`,
`TIMEOUT` and `X connection … broken` as **reds**.

| # | injection | predicted | **MEASURED** |
|---|---|---|---|
| S1 | a contract line for `browser_zznosuch` | one `GS1` leg red, naming it | **exactly one `GS1` leg, naming `browser_zznosuch`**, + `GS23` (the exact ledger, 58 vs 57). `GS22` GREEN. Count **267 → 268**. |
| S2 | delete the 19 lines the item added | `GS22` + `GS23` red, count falls | `GS0` + 4 `GS2` legs + `GS22` + `GS23`; **count 267 → 248**, the real witness |
| S3 | restore the pre-two-pane §11 wording | `GS24` **and** `GS26` | **both** — they are *not* redundant: one pins the vocabulary, the other the chord. Count 267 → 265 (two §-refs gone). |
| S4(i) | a 17th `data-seq` row in the **guide** | GH0/GH2 + BT09 or BX13 | `GH0` + `GH1` + `GH2` + **`BT09`** ×2; **`BX13` GREEN** — it reads the *test file*, not the guide |
| S4(ii) | bump `[llength $gh_seqs] 16` → 17 in the **test file** | GH0 + BX13 | `GH0` + **`BX13`**; `BT09` **green** |
| S4(iii) | a 17th `data-bseq` row in the guide | GH8 + GH9 | `GH8` ×2 (count + the orphan per-row leg) + `GH9` |
| S4(iv) | delete one `bind $f.` from `browser_build` | GH9 + GH11 + a GH8 leg | `GH8` leg + `GH9` + **`GH11`'s CONTROL** — both counters fall together, so it is the **floor** that fires. That is exactly why the floor is 16 and not 14. |
| S5 | rewrite an existing bind through an alias | `GH11` **alone** | **PREDICTION FAILED: `GH8` + `GH9` + `GH11`.** GH8's per-row leg greps the literal the rewrite deleted, so this is *not* the blind spot. |
| S5b | **ADD** a new gesture through an alias | `GH11` alone | **`GH11` RED ALONE, `GH8` and `GH9` GREEN, count unchanged.** That green pair *is* the finding, and `S5b` is the correct statement of the hole. |
| S6 | relax `$want > 0` → `>= 0` | `BP78` alone | **`BP78` alone**, count held at **191**; `BP69`/`BP70`/`BP77` green |

Every mutation restored byte-exact; the final clean re-runs are the 1698 / 2281
above.

### 7b. The FIX-UP's sabotages — six, all fired

Same protocol, tightened: lock dir, `EXIT/INT/TERM` trap restoring both targets,
a **pre-state count asserted green before any patch** (the driver aborts if not),
the mutation **proven on disk by grep** before any result is believed, `diff` on
the restore, and an output filter in which **`TIMEOUT` and `NORESULT` are reds**
(`0 999`), never a clean zero. All four guide-reading suites run per sabotage.

| # | mutation | predicted | **measured** |
|---|---|---|---|
| **SAB-B** | the verifier's own: revert guide §11.7 wholesale to single-pane wording | `GS28`'s four phrase legs, nothing else | **EXACTLY that.** grid `274 → 274` **count held**, 4 fails, all `GS28`; `GS28 (CONTROL)` **green**; sigbrowser 135 / i12 40 / keys 25 all green and unmoved |
| **SAB-B2** | drop **only** `split between the two panes` from the remembered list | one `GS28` leg | **one leg, count held at 274.** The legs are individually live, not all-or-nothing |
| **SAB-B3** | rename the `<h3 id="browser-state">` anchor (**the CONTROL's own sabotage**) | control **+** all four legs | **5 fails, count held.** The control is not vacuous |
| **SAB-C** | restore the stale `\| tb_charge_pump \| 1191 \| 110 \|` — *the actual defect* | `GS29` alone | **`GS29` alone**, count held |
| **SAB-C2** | leave §0 right and rot §5.4's `nets-only **119**` instead | `GS29` alone | **`GS29` alone.** It reds on a stale copy in **either** direction, not just the one that happened |
| **SAB-C3** | rot the `tb_bandgap` **positive control** row `424\|139 → 424\|140` | `GS29` alone | **`GS29` alone.** The term that says "the extractor found something" is itself pinned |

⚠⚠ **THE FIRST SAB-B ATTEMPT WAS A DRIVER BUG AND THE COUNT CAUGHT IT — which
is the whole reason the count is diffed and not just the fail total.** My
reconstructed pre-item paragraph wrote `&sect;8` where the shipped text has a
literal `§8`, and **`§8` occurs exactly once in the entire guide, inside §11.7**.
So `GH10` lost one leg and grid fell `274 → 273`: a *second* check firing for a
reason that had nothing to do with the claim under test. The tell was the
verifier's own masking guard — they reported the section-ref count **unchanged
at 24/24**. Re-run faithfully with the literal `§`, the refs held at 24 and only
`GS28` moved. **A sabotage that reds the right check for the wrong reason is not
evidence.**

Also measured during SAB-B, and it *is* the finding restated: with §11.7 gutted,
`grep -c 'Show source currents'` on the guide still answers **2**. That surviving
pair elsewhere in the file is precisely why `GS24`'s whole-file `bs_all_in`
stayed green through the verifier's revert.

---

## 8. The one source edit, and the protocol it went through

`src/wave_viewer.tcl`'s comment above `browser_class_filter` claimed
`tb_charge_pump: 1191 -> 137 -> 111, nets-only 110`.

> ⚠ **CORRECTED AT THE FIX-UP — THIS PARAGRAPH WAS FALSE AS WRITTEN.** It said
> "The same figures sat in two-pane §6" and, in the spec, "corrected **both
> files** in one commit". There were **THREE** sites, not two: the source
> comment, two-pane §5.4, and **two-pane §0's motivation table**, which kept the
> stale `110` and was missed. The verifier found it. A number corrected in the
> place you happen to be looking at is not a number corrected — which is exactly
> why `GS29` is a **within-file agreement** oracle rather than a spot literal.

**Wrong by exactly 9 in every term.** RE-MEASURED on the committed
fixture with the shipped proc (and re-measured a second time, independently, at
the fix-up — same figures):

```
tb_charge_pump  1191 -> 146 (devint 0) -> 120 (devint 0 + srccur 0), nets-only 119
histogram: net 120, srcbranch 26, devmeas 283, devnode 762   (sums to 1191)
tb_bandgap      424 -> 190 -> 140, nets-only 139             (CORRECT, unchanged)
```

The `tb_bandgap` triple in the same sentence re-measures **right**, which is what
makes the correction attributable rather than a rewrite. Protocol, the same one
item 18's fix-up used: the four bare-name counts taken **before and after**
(`browser_devint` 5, `browser_srccur` 5, `browser_alldbs` 2,
`device internals to reach` 1 — identical), and `git diff` filtered to
non-comment lines proven **EMPTY**. `BW59` and `BD06` green.

**No accessor is named in any comment this item wrote** — the `BD06` trap that
red item 12.

---

## 9. Declared limits

1. **Nothing in this batch is visually verified.** Items 13, 14, 15 and 18 are
   `[E]`/`[F]` with unticked rows in the eyeball queue and this item ticked none
   of them. No sentence in any file this item wrote says or implies otherwise.
2. **Two-pane item 14 stays `[F]`.** `BP78` closes the hole its verifier named,
   but the item's mark is its verifier's, not item 19's, and the sash eyeball is
   still owed.
3. **The `.ph` count line is still class-filter blind** and belongs to §7.2's
   three-state caption. Recorded in the parent spec's limit table (`CNT`) and in
   two-pane §7.2; **not moved**, because twelve checks pin that string
   byte-exactly.
4. **`browser_show_path`'s bar clause is still stale.** Receipts 11 and 20 both
   name it and both decline it; so does this one.
5. **`GS23` is an exact ledger and will red on the next contract-list edit.**
   That is deliberate — it is what makes `S2`'s count-fall visible — but it is a
   cost the next item pays.
6. **`GS24`/`GS26` pin English prose.** A rewording that keeps the meaning and
   changes the words reds them. Accepted: the alternative is a doc oracle that
   cannot see the defect it exists for (the guide described a single-pane browser
   on the wrong key for three items and **no check saw it**).
7. **`BP78` is X-only.** The store guard can only be exercised against a mapped
   `ttk::panedwindow`, so the headless total does not carry it.
8. **`GH11` cannot see a bind written with a literal path** (`bind .foo.bar <…>`)
   — only one spelled from a `$variable`. Narrower claim than "every bind is
   counted", stated rather than overclaimed.
   ⚠ **NARROWED AGAIN AT THE FIX-UP**: the pattern is `^\s*bind \$[a-z]`, so it
   needs a `$` **and a lower-case initial** and is blind to `bind $Foo <…>` as
   well. Neither form exists in `browser_build` (measured) and neither matches
   the file's lower-case-local convention. Honest claim: **"every bind spelled
   from a lower-case-initial variable is counted"**.
9. **`test_wave_sigbrowser_i12`'s X figure is UNMEASURABLE on `:0` today**, and
   that is environmental, not the fix-up's. **Nine** consecutive runs (one
   batched, seven through `xarm.sh one`, one more through `xarm.sh suites`) all
   ended `X connection to :0 broken` at **teardown**, after **124 of 126 checks
   had printed `ok` and ZERO had failed**. **Proven not mine by A/B**: the
   `test_wave_grid.tcl` from `HEAD` (the exact tree the verifier measured i12 at
   126 on) was swapped back in and i12 died **identically, twice**, then the
   fix-up file was restored byte-identical. `xarm.sh` chooses Xvfb only before
   its `DEADLINE`, and **editing `DEADLINE` to force Xvfb would circumvent the
   user's handback**, so it was not done. Headless `i12` is **40 / 0,
   unchanged**, and the only file i12 reads that this fix-up touches is
   `test_wave_grid.tcl` *as text* — `BX13`'s two literals (`gh_seqs 16`,
   `gh_menus 11`) are untouched and green in both arms.
   ⚠ **AND `:0` DEGRADED PROGRESSIVELY DURING THE FIX-UP, WHICH IS ITSELF THE
   EVIDENCE.** `test_wave_sigbrowser_i1315` **PASSED at 191** in the first X
   sweep of this same tree and then `NORESULT`ed in the final sweep and on three
   standalone re-runs afterwards. Nothing in the tree changed between those two
   sweeps. A suite that answers 191 and later cannot answer at all, on identical
   bytes, is measuring the **server**, not the code — so the 2162 is taken from
   the sweep in which each suite actually reported, and both sweeps agree on
   **every** figure that reported in both.
10. **`GS28` pins WORDS, not BEHAVIOUR.** It cannot tell that the sash actually
   persists or that the boxes actually restore — only that §11.7 still claims
   they do. Item 14's eyeball row is still the only thing that can close that
   gap, and it is still unticked.

---

## 10. Divergences from the PLAN

1. `GS10`-`GS15` → **`GS22`-`GS27`** (all five colliding, measured).
2. `GH11`'s control floor **`>= 16`**, not `>= 14`.
3. The PLAN's `GS10` list dropped `browser_tree` and `browser_sea` (**neither
   proc exists**; naming them reds `GS1` twice).
4. "the fourteen `data-bseq` rows" → **sixteen**, and untouched.
5. `>= 48` floor satisfied at **57**, not the PLAN's 48-by-arithmetic.
6. §14's `78→84 / 278→303` **REFUSED**; the refusal written into §14.
7. Six PLAN bullets were already landed; executing them would have been churn.
8. The four-file lockstep is **not** "BT09 **or** BX13" — they are different
   levers and both were measured.
9. `S5` as the PLAN framed it does **not** isolate `GH11`; `S5b` does.
10. "All eight `--nogui` files" → **fifteen** files and **twelve** X suites.
11. §12.1's accessor instruction rewritten as **history** (never introduced),
    not as work owed.
12. Item 18's three handed-on divergences (§3.3 rows-vs-nodes, §8.2's "prefix",
    §7.4's "is logged") were all closed here; §7.4's correction is that the
    auto-tick writes **no log line at all**.
