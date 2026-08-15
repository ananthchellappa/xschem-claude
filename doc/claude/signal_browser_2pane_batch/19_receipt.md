# Item 19 — Docs, oracles, the four-file lockstep, 0217 closed

Two-pane item 19 (**not** single-pane item 19). Spec
`doc/claude/specs/waveform_signal_browser_two_pane.md`; parent spec
`doc/claude/specs/waveform_signal_browser.md`. PLAN
`doc/claude/signal_browser_2pane_batch/PLAN.md` item 19.

**Status: DONE (`589d7424`), REJECTED by its verifier, FIXED UP (`b5a57db6`),
ACCEPTED.** Committed, not pushed. Everything below is **measured**, not quoted
from the PLAN — and where the item's own first round said something false, the
sentence is corrected **in place** with a visible note saying what it used to say,
because this receipt is the batch's durable record.

**The one-line verdict.** The item's real work was the guide's §11 rewrite and a
band of doc oracles; its thesis was *"a doc that rots must red a check"*. **The
thesis failed on the item's own delivered prose** — §11.7, the only user-facing
documentation of two-pane item 14's entire feature, could be reverted wholesale to
its pre-two-pane wording with all four guide-reading suites ALL PASS and every
count unchanged. `GS28` closes that; `GS29` closes a corrected number that
survived as a stale copy 415 lines up in the same file. Both findings were the
verifier's, both were real, neither was argued away.

---

## 1. The baselines, re-measured on the UNCHANGED tree first

Both arms reproduced exactly before a line was written, so every red afterwards is
attributable to this item.

| arm | baseline | re-measured | after item 19 | after the FIX-UP |
|---|---|---|---|---|
| headless, 15 files | **1662** / 0 | **1662** / 0, every per-file figure exact | **1698** / 0 | **1705** / 0 |
| X, 12 suites (`xarm.sh suites`, `SUITE_TIMEOUT=400`) | **2244** | **2244**, every per-suite figure exact | **2281** | **2287** |
| out of BOTH baselines, X-only | 13 / 17 / 70 | 13 / 17 / 70 | 13 / 17 / 70 | **13 / 17 / 70** |

**Per-file headless, after:** sigsearch 146, sea 6, sigbrowser 135, 2pane 108,
panes 15, i11 50, i12 40, i1315 88, i14 56, **grid 274**, modes 212, viewer 57,
markers 437, tabs 56, keys 25 = **1705**, summed by hand.

**Per-suite X, after:** panes 81, 2pane 108, sigbrowser 353, sigsearch 233,
sea 79, **grid 399**, i11 74, modes 488, i12 **126**, i1315 **190**, keys 49,
i14 107 = **2287**, summed by hand.

**Only two files moved across the whole item, and every term is accounted for:**

* `test_wave_grid` **231 → 267 → 274** headless and **356 → 392 → 399** under X —
  the same delta in both arms both times.
  * the item's **+36**: `GS1` **+19** (contract list 38 → 57), `GS2` **+6**
    (roster 23 → 29), `GS3` **+2** (6 → 8 cited issues), `GS22`-`GS27` **+6**,
    `GH11` **+2**, `GH10` **+1** (the §11 rewrite adds one NEW distinct §-ref,
    `§11.2`; 14 → 15 distinct).
  * the fix-up's **+7**: `GS28` **+5**, `GS29` **+2**.
* `test_wave_sigbrowser_i1315` **190 → 191 under X only** (`BP78` needs a mapped
  panedwindow); its headless count is **88, unchanged**.

Every other per-file and per-suite figure is byte-identical in both arms, in both
rounds.

### 1.1 What the verifier re-measured rather than adopted — and the number it closed

The fix-up's own run reported **"11/12 measurable = 2162"** and declared
`test_wave_sigbrowser_i12`'s X figure **unmeasurable** (§9, limit 9). Its verifier
**measured it: `i12` = 126 ALL PASS on `:0`, first try.** So:

* the X arm is **12/12 = 2287**, not 11/12 = 2162;
* `2244 + 36 + 7` reconciles **EXACTLY**, so no drift was hiding behind the
  missing figure;
* declared limit 9 is **closed, not carried**.

It also **attributed** the `+7` instead of believing it: `589d7424`'s
`test_wave_grid.tcl` was checked back into the tree and answered **267 / 0 ALL
PASS**, then restored byte-identical (`cmp`). So the pre-fix-up tree was green and
all seven are genuinely new checks.

Two further figures of the fix-up's are corrected by measurement, neither a defect:

* **`i1315`'s X count is not stably 191.** `BP56`'s pixel leg is **gated**, and
  190 and 191 were both observed on consecutive standalone runs of **identical
  bytes**. The baseline's 190 and the item's 191 are both real; the total reads
  **2287** at 190 and **2288** at 191.
* *"`test_key_graph_context` did **NOT** stall this session"* was **luck, not a
  property.** It stalled and emitted fails on the verifier's first attempt and
  answered **70 ALL PASS** on re-run — exactly what the baseline predicts.

### 1.2 The `:0` arm was unreliable on both days, and none of it is a regression

* **Item-19 day:** three whole-suite deaths (`i12` + `i1315` pre-item,
  `sigbrowser` post-item), each `X connection to :0 broken`; the **gate panel
  itself** died and was revived once; one `BP56` geometry-echo FAIL (240 vs 260
  px) that passed on re-run; `test_key_graph_context` TIMEOUT at 400 s on its
  first batched attempt, then 70 / 0 standalone twice. The two pre-item deaths
  were re-measured under **Xvfb** (`i12` **126**, `i1315` **190**) so the baseline
  is *attributable*, not merely re-attempted.
* **Fix-up day:** `:0` **degraded progressively**. `i1315` **answered 191** in the
  first X sweep of this exact tree, then `NORESULT`ed in the final sweep and on
  three standalone re-runs, **with the tree unchanged between them**. A suite that
  answers 191 and later cannot answer at all, on identical bytes, is measuring the
  **server**. Every figure that reported in both sweeps is identical.
* **Verifier's day:** `test_wave_sigbrowser` NORESULT inside the batched sweep →
  **353 ALL PASS** standalone; **`MG13`** in `test_wave_modes` → **488 ALL PASS**
  standalone (key-delivery class, sibling of the listed `MG16`); **`BP77`** in
  `i1315` (the listed `:0` geometry echo).

`GUI_GATE` was never set to 0, the panel was never killed, no bare `./src/xschem`
loop was used for an X run, and **`DEADLINE` was never edited to force Xvfb** —
that would circumvent the user's handback. Xvfb was used only to re-attribute a
run that had already died on `:0`. **A `NORESULT` is not a measurement.**

---

## 2. What the PLAN got wrong, with the measurement that says so

### 2.1 Half the item's stated scope was already landed, and one bullet was wrong

| PLAN bullet | disposition |
|---|---|
| `0217-*.md` closed **and `git add`ed** — "it is currently **untracked**" | **ALREADY DONE.** `git ls-files doc/claude/issues/0217-*` returns the file; `git status --porcelain doc/claude/issues/` is empty; committed in `422b3f55`, header already read `Status: **FIXED** 2026-08-07`. Both halves. |
| fix §5.4's stated rule to the measured hybrid (§0.1) | **ALREADY DONE**, and the spec is *more* correct than the PLAN: it carries the leading-`@` strip (25 of 2656) and corrects the PLAN's own claim of zero label collisions to a measured **four**, pinned by `TP19`. |
| fix §14's device-node counts (78→84, 278→303) | **REFUSED — executing it injects an error.** §3.3 already carries 84/303 *and rules in writing* that §14's 78/278 is a **different metric** (nodes minted *only* by device paths) inside an audit of another document's verbatim awk. Both numbers are right about their own question. The refusal is now **written into §14** so nobody executes the bullet later. |
| fix M6's 11→9 | **ALREADY DONE** — §2.2 M6 reads "9 of 22". |
| add declared limit 8 (`graph_use_ctrl_key`) | **ALREADY DONE**, and there is a **ninth** (the Ctrl+b / `sym_txt` consequence, pinned in `test_key_graph_context.tcl`). |
| record the `d:N\|` fix as closed | **HALF DONE.** §11's table already said FIXED; the numbered **issue file did not exist** — it lived only as a paragraph inside `0217:190`. Filed as **0225** (next free measured; 0224 was highest) and cited. |
| "the fourteen `data-bseq` rows final" | **WRONG NUMBER — measured SIXTEEN**, and `GH8`'s literal already said 16. History: 6 → 7 (item 10) → 14 (item 11) → 15 (the hover tooltip) → 16 (item 14's sash release). **Item 19 added and removed no row.** |
| §9.1's Ctrl-B row | **ALREADY DONE** by two-pane item 16. |
| §11 prose rewritten for two panes | **GENUINELY OWED, and it was the item's real work.** |

### 2.2 The check ids the PLAN handed out were all spent

**`GS10`-`GS15` are ALL FIVE SPENT.** `GS` names two unrelated blocks inside
`test_wave_grid.tcl` — the spec oracles `GS0`-`GS3` and the grid-selection-survival
block `GS0`-`GS14`, no gaps — **and** the prefix is owned by
`test_wave_sigsearch.tcl` (`GS01`-`GS21`). First id colliding with nothing in
either owning file: **`GS22`**. Taken **`GS22`-`GS27`**, and **`GS28`-`GS29`** at
the fix-up (band re-measured again then across every `tests/headless/*.tcl` and
every batch doc: `GS` was spent to exactly 27, so 28/29 collide with nothing).
**Next free `GS30`.** `GH11` was free (highest `GH10`); `BP78` free and reserved by
`test_wave_sigbrowser_i1315.tcl:45`'s own header. Adjacent bands re-measured so
nothing was taken by accident: `BT`→47, `BX`→56, `BD`→70 (item 15's, untouched),
`BW`→78, `BK`→43.

### 2.3 The PLAN's `GS10` list would have red `GS1` **twice**

It named `browser_tree` and `browser_sea`. **MEASURED: neither proc exists** —
two-pane item 1 (the accessor) never landed, and `09_receipt.md:26-27` says so
outright. `GS1` loops the spec's contract list against the source, so naming them
would have red exactly two legs. They are kept **off** the roster and §12.1 is
rewritten to record the accessor as **never introduced** rather than as work owed.

### 2.4 `GH11`'s prescribed control floor was satisfiable by a broken tree

The PLAN wanted `[expr {$gh_nbb >= 14}] 1`. **Measured `$gh_nbb` = 16**, so a
`>= 14` floor stays green after **two binds are deleted**. Shipped floor: **16**.
Sabotage `S4(iv)` is the proof — deleting one `bind $f.` drops *both* counters
together, so it is the **floor** that fires, not the equality.

### 2.5 Four spec figures were stale, and one was wrong nobody had flagged

* §12.1's inventory ("17 `tvf.tv` in src, 73 `.wvbrowser` and 21 `tvf.tv` in
  tests, **nine** longhand sites") → **measured 6 longhand, 20 `tvf.tv` in src, 25
  `.wvbrowser` in `src/*.tcl` (0 outside `wave_viewer.tcl`), 87 `.wvbrowser` and
  55 `tvf.tv` across `tests/headless`.** All four stale.
* §12.2's "`GH8` 6 → **12**, `GH9` 6 → **12**" → **16 / 16**.
* §13's "baseline `--nogui` 660 checks across seven files" and the PLAN's
  competing **694** → **1662 over FIFTEEN files** (and twelve X suites).
* §13's "`BK19` next free" → **`BK` spent to `BK43`; `BK44` next.**
* **The one nobody flagged, and it was wrong in three places:** §6/§5.4 and the
  source comment above `browser_class_filter` all read
  `tb_charge_pump: 1191 -> 137 -> 111, nets-only 110`. **Wrong by exactly 9 in
  every term.** See §8.

---

## 3. The traps that cost real time — every one found by running

### 3.1 ⚠⚠ THE `&sect;` DRIVER BUG, CAUGHT BY THE **COUNT** AND NOT THE FAIL TOTAL

The first `SAB-B` attempt (replaying the verifier's §11.7 revert) reconstructed the
pre-item paragraph with `&sect;8` where the shipped guide has a **literal `§8`** —
and **`§8` occurs exactly once in the entire guide, inside §11.7**. So `GH10` lost
one leg and grid fell **274 → 273**: a *second* check firing for a reason that had
nothing to do with the claim under test. The tell was the verifier's own masking
guard — it reported the guide's §-marker count **unchanged at 24/24**. Re-run
faithfully with the literal `§`, refs held at 24 and **only `GS28` moved**.

**A sabotage that reds the right check for the wrong reason is not evidence**, and
the only thing that says so is diffing the **count**, not the fail total.

### 3.2 ⚠⚠ A SECTION-SCOPED CHECK WRITTEN WITHOUT `bs_flat` REDS ON **CORRECT** TEXT

The guide hard-wraps its prose, so `<b>Show device\ninternals</b>` carries the
string *"Show device internals"* **nowhere in the raw bytes**. `bs_flat`
(tags → spaces, whitespace runs → one space) is **required**, not cosmetic. The
companion `bs_section` returns **`{}`** for a missing anchor — a VALUE, never a
throw — so a vanished section reds the control leg instead of aborting the file
(`SAB-B3` proves it).

And the extraction control's floor is deliberately **low** (`>= 300` against 936
shipped and ~350 for the reverted wording) so it stays a **control** and does not
quietly become the discriminator.

### 3.3 `i12` DIED NINE TIMES AT TEARDOWN, AND THE A/B IS WHAT MADE IT ENVIRONMENTAL

Nine consecutive runs (1 batched, 7 via `xarm.sh one`, 1 via `xarm.sh suites`) all
ended `X connection to :0 broken` at **teardown**, each after **124 of 126 checks
had printed `ok` with ZERO fails**. Proven not-mine by A/B: `HEAD`'s
`test_wave_grid.tcl` was swapped back in — the exact tree `i12` had measured 126 on
— and it died **identically, twice**; the fix-up file was then restored
byte-identical. Headless `i12` is **40 / 0 unchanged**, and the only file `i12`
reads that this fix-up touches is `test_wave_grid.tcl` **as text** (`BX13`'s two
literals, untouched and green in both arms). The verifier later measured 126 on a
healthier server; see §1.1.

### 3.4 `git checkout --` WAS REFUSED DURING THE A/B, AND THE REFUSAL WAS **CORRECT**

It would have discarded the then-uncommitted fix-up. The A/B was done instead by
backing the working file up, writing `HEAD`'s version with `git show`, running, and
restoring from the backup (verified byte-identical). No `git reset --hard`, no
`git add -A`, no push; the commit staged an explicit four-file list.

### 3.5 ⚠⚠ THE VERIFIER'S **OWN** SABOTAGE DRIVER LEFT MUTATIONS ON DISK — AND SAID "byte-identical: True"

Recorded because it is the exact trap this discipline names, reproduced inside the
harness built to catch it. For the two cases that patched the **same file twice**,
its `patch()` re-took the backup **after** the first mutation, so the restore
silently left a mutation behind while printing *"byte-identical: True"*, and the
post-restore suite run came back **fully green**. Only `git status` caught it.

The X arm had already run with that residue present. The two residual mutations
were **precisely the two it had just proved red nothing anywhere**, both files were
restored from `git show HEAD:`, and `test_wave_grid` was re-measured clean on both
arms (**274 headless / 399 X**, both ALL PASS). Final tree byte-identical to
`HEAD`. **No measurement is contaminated** — but the failure mode is real and the
next driver should take its backup **once, before the first patch**.

### 3.6 The `BD06` bare-name protocol, on a comment-only source edit

The item's one `src/` edit is a **comment**. Protocol anyway: the four frozen
bare-name counts taken before and after (`browser_devint` 5, `browser_srccur` 5,
`browser_alldbs` 2, `device internals to reach` 1 — identical), `browser_sash` 6 +
`_pref` 2 + `_drop` 2, and `git diff` filtered to non-comment lines proven
**EMPTY**. `BW59` and `BD06` green. **No accessor is named in any comment this
item wrote** — the trap that red item 12.

---

## 4. What landed

### 4.1 Source (`src/wave_viewer.tcl`) — ONE comment, in the item; NONE in the fix-up

* The item corrected the `tb_charge_pump` triple in the comment above
  `browser_class_filter` (§8), under the `BD06` protocol above.
* **The fix-up touches no `src/` file at all.** `git diff --name-only HEAD --
  src/` is empty and `src/wave_viewer.tcl` is byte-identical to `HEAD`, so the
  frozen bare-name oracles cannot have moved. Re-grepped anyway.

### 4.2 Docs

* `doc/waveform_viewer_guide.html` — **§11 rewritten for two panes** (the item's
  real work): §11.0's "search box, a hierarchy tree" replaced with the two-pane
  description and the **Ctrl-B** chord; §11.2 retitled *"The two panes"* and its
  stale *"Selection is extended — Shift and Ctrl work as usual"* corrected to the
  shipped single-selection tree (*"Selection here is single: Shift and Ctrl do
  not extend it"* — the tree ships `-selectmode browse`, pinned at `panes:218`)
  with the extended-selection sentence moved to where it is true, the **lower**
  pane; §11.7 *"What is remembered"* extended with the sash split, both class
  boxes and the fraction-vs-pixels paragraph. **The fix-up does not touch this
  file at all** (0 files in its diff) — item 19 had already written §11.7
  *correctly*; the verifier's finding was a **missing oracle**, not missing text.
  Guide data-attribute diff is empty by construction and §-refs held at **24**.
* `doc/claude/specs/waveform_signal_browser.md` (parent) — §14's declared-limit
  table, §15's open issues (**0217** and the new **0225**), §16's test map (the
  four new files), and the contract list **38 → 57** names.
* `doc/claude/specs/waveform_signal_browser_two_pane.md` — §12.1 rewritten as
  history, §14's refusal written in, §3.3/§8.2/§7.4 (item 18's three handed-on
  divergences), §0's motivation table `110` → **119**, and the general rule the
  fix-up earned: **a doc oracle must be scoped to the section it is the oracle
  for.**
* `doc/claude/issues/0225-*.md` — filed and `git add`ed in the same commit that
  cites it, because `GS3` resolves every cited issue to exactly one file.

### 4.3 Tests

* `test_wave_grid.tcl` — **`GS22`-`GS27`** (+6), **`GH11`** + its control (+2),
  `GH10` +1 by its own per-ref loop, `GS1` +19 and `GS2` +6 and `GS3` +2 by
  **their** own loops; then the fix-up's **`GS28`** (5 legs) and **`GS29`**
  (2 legs). `GS0`'s floor and `GS2`'s roster restated **in place** (§6).
* `test_wave_sigbrowser_i1315.tcl` — **`BP78`**, X-only, seven legs in one tuple:
  the preference before, the pane really mapped, the accessor's return on a
  refused `0`, the untouched preference, the untouched live split, and a
  **positive control** driving `0.30` through the same call. It restores the
  borrowed fraction **after** every leg is asserted, to `BP77`'s own 0.44, so what
  `BP47` inherits is byte-identical to before.

### 4.4 The two fix-up checks, in one sentence each

* **`GS28`** (5 legs, `test_wave_grid.tcl`) — the guide's §11.7 still says the
  sash split is remembered, names **both** class boxes, and keeps the
  fraction-not-pixels paragraph; **scoped to that section** via `bs_section` +
  `bs_flat`, with a `GS28 (CONTROL)` leg proving the section was found and is not
  a stub.
* **`GS29`** (2 legs) — a **within-file agreement** oracle: two-pane §0's
  motivation table row must equal §5.4's `nets-only **N**`, with the `tb_bandgap`
  row as the **positive control**, plus a `GS29 (CONTROL)` leg proving the spec
  was read at all (a `>= 20000`-char floor).

---

## 5. The checks that were VACUOUS on the red run, and what was done about them

The house rule earned its keep in both rounds: *a check that passes before you
wrote the code is a check to stop and look at.* **Nothing was hidden and nothing
was removed** — each is declared in the file as a regression **guard**, and each
carries its positive control in the **same tuple**.

**Item round — red run 245 checks / 10 fail on `test_wave_grid`, exactly the
predicted count.** Red: `GS0`, four `GS2` legs, `GS22`, `GS23`, `GS24`, `GS26`,
`GS27`.

| green-before | why | what was done |
|---|---|---|
| `GS25` | two-pane item 16 had already renamed the chord **in the table**, so `{0 0 1 1}` was already true | kept as a **regression guard**, declared in the file; its two positive legs are in the same tuple, so it cannot go green on a stripped guide. Positive evidence: `S3` |
| `GH11` | `bind $[a-z]` already equalled `bind $f.` = 16 | same; its `>= 16` counter is the control. Positive evidence: `S5b` |
| `GH11 (CONTROL)` | ditto | same. Positive evidence: `S4(iv)` |

**Fix-up round — SIX of the seven new checks passed on the red run**, and this is
the honest statement of why: **item 19 had already written §11.7 correctly. The
defect was the MISSING ORACLE, not missing text.**

| green-before | why | what was done |
|---|---|---|
| `GS28 (CONTROL)` + `GS28`'s four phrase legs (**5 checks**) | the prose they pin was already shipped and correct | declared in the file comment as **regression guards on already-shipped prose**. Their ONLY positive evidence is the sabotage run: `SAB-B` reds all four legs alone with the control green; `SAB-B3` reds control + four. Recorded in the fix-up header, not smoothed over |
| `GS29 (CONTROL)` (the `>= 20000`-char floor) | an **extraction control by construction**, in the same block as the claim it guards | its sabotage is implicit in `SAB-C`/`C2`/`C3`, all of which red `GS29` while the control stays **green** — proving the control is not the discriminator |
| — | — | — |
| **`GS29` itself was RED** | the genuine, previously-unseen defect: §0's stale `110` | **the one new check with real red-first evidence** |

`BP78` is the same shape one file over: it closes a **coverage hole** rather than
pinning new code, and `S6` is its evidence.

---

## 6. Every existing check restated — and why. **None was deleted.**

| check | restatement | why | count effect |
|---|---|---|---|
| `GS0` | floor `>= 20` → **`>= 48`** in place | the contract list really grew (38 → 57); a 20-floor no longer witnesses anything | **0** |
| `GS2` | roster **23 → 29** (`sig_declass`, `browser_tree_rows`, `browser_class_filter`, `browser_level_names`, `browser_label`, `browser_flow_layout`) | six procs shipped by this batch were missing from the source→spec direction; all six exist, so the roster *can* grow | **+6** |
| `GS22` | **TITLE restated in place**, expected value `[list {} 17]` and all legs **byte-identical** | it read *"the parent spec's contract list NAMES every proc the two-pane batch minted"*. The roster is **17 hand-picked names**, so the title overclaimed. It now names itself as a seventeen-proc load-bearing roster and points at `GS23`'s exact 57. **Titles are what a later reader trusts** | **0** |
| `GH11` | **no check changed** — only its declared-limit **comment** narrowed | the pattern `^\s*bind \$[a-z]` is also blind to `bind $Foo <…>`, not just to a literal path. Honest claim: *"every bind spelled from a lower-case-initial variable is counted"*. No live instance of either blind form exists in `browser_build` (measured) | **0** |
| `GS24`, `GS26` | **LEFT EXACTLY AS THEY ARE** | they are correct about what they assert (whole-file vocabulary; the Ctrl-B prose). They were simply never the oracle for §11.7. `GS28` is added **beside** them rather than replacing or widening either, so no existing expected literal moves | **0** |
| `GH8`, `GH9`, `GH0`, `GH2`, `GH4`, `GH1`, `GH3`, `GH7` | untouched | the item adds and removes **no** `data-seq`, `data-accel` or `data-bseq` row and no `bind $f.` | **0** |
| `GH10` | untouched; its **per-ref loop** grew by one | the §11 rewrite cites one NEW distinct §-ref (`§11.2`), 14 → 15 distinct | **+1** |
| the twelve `.ph` byte-identity pins (`BD52`, `BX37`, `BX42`, `BX44`-`BX46`, `BH50`, `BH51`, `BH54`, …) | untouched | item 19 writes no status-line string | **0** |
| `BW59`, `BD06`, `BT08`, `BP07`, `BS01`, `BS02` | untouched, re-grepped before and after | the one source edit is a comment, and no accessor is named in it | **0** |
| `BT09`, `BX13` | untouched, and **measured as two different levers** (§7, `S4`) | the PLAN's "`BT09` *or* `BX13`" is neither an *or* nor one lever | **0** |
| `BP54`, `BP53`, `BW76` | untouched, green | the ancestor-chain union stays **refused**; §4.2 now says so in writing, and no doc sentence this item wrote claims the union happens | **0** |

---

## 7. Sabotages — **16 run, 16 fired**, in three rounds

Driver, both of the item's rounds: `flock`ed lock, `trap … EXIT INT TERM`
restoring from a **byte-exact backup** (never `git checkout --`, which would have
deleted the uncommitted work), the **pre-state check count asserted green before
any patch** (abort if not), the mutation **proven on disk by grep** before any
result is believed, `diff` on the restore, and an output filter in which
`NORESULT`, `TIMEOUT` and `X connection … broken` count as **reds** — never a
clean zero. All four guide-reading suites run per fix-up sabotage.

### 7.1 The item's eight

| # | injection | predicted | **MEASURED** | fired exactly? | positive control | reverted |
|---|---|---|---|---|---|---|
| `S1` | a contract line for `browser_zznosuch` | one `GS1` leg red, naming it | **exactly one `GS1` leg, naming `browser_zznosuch`**, + `GS23` (exact ledger, 58 vs 57). `GS22` **GREEN**. Count 267 → **268** | **YES** | count rose by exactly 1 | byte-exact |
| `S2` | delete the 19 lines the item added | `GS22` + `GS23` red, count falls | `GS0` + four `GS2` legs + `GS22` + `GS23`; **count 267 → 248** — the count-fall is the real witness | **YES** | the 19-line fall itself | byte-exact |
| `S3` | restore the pre-two-pane §11 wording | `GS24` **and** `GS26` | **both** — they are *not* redundant: one pins the vocabulary, the other the chord. Count 267 → 265 (two §-refs gone) | **YES** | `GS25` stayed green | byte-exact |
| `S4(i)` | a 17th `data-seq` row in the **guide** | GH0/GH2 + `BT09` **or** `BX13` | `GH0` + `GH1` + `GH2` + **`BT09`** ×2; **`BX13` GREEN** — it reads the *test file*, not the guide | **YES** (PLAN's "or" wrong) | `BX13` green is the finding | byte-exact |
| `S4(ii)` | bump `[llength $gh_seqs] 16` → 17 in the **test file** | GH0 + BX13 | `GH0` + **`BX13`**; **`BT09` green** | **YES** | `BT09` green is the finding | byte-exact |
| `S4(iii)` | a 17th `data-bseq` row in the guide | GH8 + GH9 | `GH8` ×2 (count + the orphan per-row leg) + `GH9` | **YES** | `GH11` green | byte-exact |
| `S4(iv)` | delete one `bind $f.` from `browser_build` | GH9 + GH11 + a GH8 leg | `GH8` leg + `GH9` + **`GH11`'s CONTROL** — both counters fall together, so it is the **floor** that fires. Exactly why the floor is 16 and not 14 | **YES** | the floor *is* the control | byte-exact |
| `S5` | rewrite an **existing** bind through an alias | `GH11` **alone** | **PREDICTION FAILED: `GH8` + `GH9` + `GH11`.** `GH8`'s per-row leg greps the literal the rewrite deleted, so this is *not* the blind spot | **NO — corrected by `S5b`** | — | byte-exact |
| `S5b` | **ADD** a new gesture through an alias (`bind $zzc <Button-4>`) | `GH11` alone | **`GH11` RED ALONE, `GH8` and `GH9` GREEN, count unchanged.** That green pair **is** the finding, and `S5b` is the correct statement of the hole | **YES** | `GH8`/`GH9` green | byte-exact |
| `S6` | relax `$want > 0` → `>= 0` (the store guard) | `BP78` alone | **`BP78` alone**, count held at **191**; `BP69`/`BP70`/`BP77` green | **YES** | the three green siblings | byte-exact |

### 7.2 The fix-up's six

| # | mutation | predicted | **MEASURED** | fired exactly? | positive control | reverted |
|---|---|---|---|---|---|---|
| `SAB-B` | **the item-19 verifier's own, replayed faithfully**: revert guide §11.7 wholesale to single-pane wording (sash bullet, both box names, the whole fraction paragraph) | `GS28`'s four phrase legs, nothing else | **EXACTLY that.** grid **count HELD at 274**, 4 fails, all `GS28`; **`GS28 (CONTROL)` GREEN**; sigbrowser 135 / i12 40 / keys 25 all green and unmoved. **On the PRE-fix-up tree this exact mutation was fully green in all four suites — that is the hole this closes** | **YES** (after the `&sect;` correction, §3.1) | control green; §-refs held 24/24 | byte-exact |
| `SAB-B2` | drop **only** the sash bullet, leaving the fraction paragraph and both box names intact | one `GS28` leg | **one leg, count held at 274.** The four legs are individually live, not all-or-nothing on the section | **YES** | the other three legs green | byte-exact |
| `SAB-B3` | rename the `<h3 id="browser-state">` anchor — **the CONTROL's own sabotage** | control **+** all four legs | **5 fails, count held at 274.** Proves the extraction control is not vacuous and that a vanished section is an assertable **VALUE**, not a throw | **YES** | the control *is* the target | byte-exact |
| `SAB-C` | restore the stale `\| tb_charge_pump \| 1191 \| 110 \|` — **the actual defect** | `GS29` alone | **`GS29` alone**, count held at 274 | **YES** | `GS29 (CONTROL)` green | byte-exact |
| `SAB-C2` | leave §0 right and rot **§5.4's** `nets-only **119**` instead | `GS29` alone | **`GS29` alone.** It reds on a stale copy in **either** surface, not just the one that happened to occur | **YES** | `GS29 (CONTROL)` green | byte-exact |
| `SAB-C3` | rot the `tb_bandgap` **positive control** row `424\|139 → 424\|140` | `GS29` alone | **`GS29` alone.** The term whose job is to say *"the extractor found something"* is itself pinned, so `GS29` cannot go green on an extractor that found nothing | **YES** | the control *is* the target | byte-exact |

Also measured during `SAB-B`, and it **is** the finding restated: with §11.7
gutted, `grep -c 'Show source currents'` on the guide still answers **2**. That
surviving pair elsewhere in the file is precisely why `GS24`'s whole-file
`bs_all_in` stayed green through the verifier's revert.

### 7.3 The verifiers' OWN sabotages — three, none on anybody's list

**(V0) The item-19 verifier's, which rejected the item.** The wholesale §11.7
revert, taken from `git show c5a55dd8:doc/waveform_viewer_guide.html`. On the
shipped item it was **fully green across all four guide-reading suites with every
count unchanged** (grid 267, sigbrowser 135, i12 40, keys 25). That is the entire
reason `GS28` exists. Replayed by the fix-up as `SAB-B` and **again by the fix-up's
own verifier**, independently: four legs red **ALONE**, control green, count HELD
at 274, guide §-markers held at 24 (so **not** the `&sect;` driver bug), other
three suites unmoved, restore byte-identical, clean re-run green.

**(V1) The THIRD SITE — and it is still not covered.** The verifier's finding #2
was that a corrected number survived as a **stale copy**, and the triple lived in
**three** places: the source comment above `browser_class_filter`, spec §5.4, and
spec §0's table. `GS29` is a **within-file** agreement oracle and closes §5.4 ↔ §0.
So the fix-up's verifier rotted the remaining site — `src/wave_viewer.tcl` back to
`tb_charge_pump: 1191 -> 137 -> 111, nets-only 110` — and ran **all 15 headless
files**. **IT STAYED FULLY GREEN: zero reds, every count exact.** The one site
item 19 actually **edited in source** is the one site the new oracle cannot see.
Honestly scoped in the check title (*"elsewhere in the same file"*) and in a
divergence bullet — but the commit and receipt prose read broader than the check
is, so it is now **declared limit 11** (§9).

**(V2) The OTHER chartered correction has no doc oracle.** Item 19's scope bullet
names *"fix §14's device-node counts (78→84, 278→303)"*. The verifier reverted
exactly that table row pair in the spec (303 → 278, 84 → 78): **GREEN in grid,
sigbrowser, i12 and keys, all counts exact.** Severity is genuinely lower than V1
because **`TP35`** in `test_wave_sigbrowser_2pane` pins **84** and **303** against
the committed fixture, so the *numbers* cannot drift silently in code — only the
doc sentence can rot, and it would then disagree with a green check. Recorded as
**declared limit 12**, not fixed: this receipt's §2.1 **refuses** that bullet on a
measurement, and the refusal is written into §14.

Both were run under the same lock-file + `EXIT/INT/TERM`-trapped driver that
asserts a green pre-state count, asserts the anchor occurs exactly once, proves the
mutation reached disk, and re-runs after restore — the driver whose backup bug is
recorded in §3.5.

---

## 8. The one source edit, and the protocol it went through

`src/wave_viewer.tcl`'s comment above `browser_class_filter` claimed
`tb_charge_pump: 1191 -> 137 -> 111, nets-only 110`.

> ⚠ **CORRECTED AT THE FIX-UP — THIS PARAGRAPH WAS FALSE AS WRITTEN.** It said
> *"The same figures sat in two-pane §6"* and, in the spec, *"corrected **both
> files** in one commit"*. There were **THREE** sites, not two: the source
> comment, two-pane §5.4, and **two-pane §0's motivation table**, which kept the
> stale `110` under the header *"of which are design nets"* and was missed.
> Provably the same metric: the `tb_bandgap` row above it reads `424 | 139` and
> §5.4 states *"Design nets only would be 139"*. The verifier found it. **A number
> corrected in the place you happen to be looking at is not a number corrected** —
> which is exactly why `GS29` is a **within-file agreement** oracle rather than a
> spot literal. (A spot literal would have caught *this instance*; the agreement
> form catches the **class**.)

**Wrong by exactly 9 in every term.** RE-MEASURED on the committed fixture with the
shipped proc, re-measured a second time independently at the fix-up, and a **third
time by the fix-up's verifier with its own script** — same figures all three times:

```
tb_charge_pump  1191 -> 146 (devint 0) -> 120 (devint 0 + srccur 0), nets-only 119
histogram: net 120, srcbranch 26, devmeas 283, devnode 762   (sums to 1191)
all 120 survivors are class `net`; `time` is line 1 of the fixture  =>  119
tb_bandgap      424 -> 190 -> 140, nets-only 139             (CORRECT, unchanged)
```

The `tb_bandgap` triple in the same sentence re-measures **right**, which is what
makes the correction attributable rather than a rewrite — and it is `GS29`'s
positive control for the same reason. Protocol (item 18's fix-up's): the four bare
name counts taken **before and after** (`browser_devint` 5, `browser_srccur` 5,
`browser_alldbs` 2, `device internals to reach` 1 — identical), and `git diff`
filtered to non-comment lines proven **EMPTY**. `BW59` and `BD06` green.

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
   Deliberate — it is what makes `S2`'s count-fall visible — but a cost the next
   item pays.
6. **`GS24`/`GS26` pin English prose.** A rewording that keeps the meaning and
   changes the words reds them. Accepted: the alternative is a doc oracle that
   cannot see the defect it exists for — the guide described a single-pane browser
   on the wrong key for three items and **no check saw it**.
7. **`BP78` is X-only.** The store guard can only be exercised against a mapped
   `ttk::panedwindow`, so the headless total does not carry it.
8. **`GH11` is blind to a bind on a LITERAL path** (`bind .foo.bar <…>`) **and to
   one spelled from an uppercase-initial variable** (`bind $Foo <…>`) — the
   pattern is `^\s*bind \$[a-z]`. Neither form exists in `browser_build` today
   (measured) and neither matches the file's lower-case-local convention. Honest
   claim: **"every bind spelled from a lower-case-initial variable is counted"**.
   *(Narrowed at the fix-up from the item's original, wider claim.)*
9. ~~**`test_wave_sigbrowser_i12`'s X figure is UNMEASURABLE on `:0` today.**~~
   **CLOSED BY THE FIX-UP'S VERIFIER: it measured 126 ALL PASS on `:0`, first
   try.** The record of *why* the fix-up could not is kept in §3.3 (nine teardown
   deaths, A/B-proven environmental, `DEADLINE` deliberately not edited) because
   the degradation is real and the next reader will meet it. The X arm is
   **12/12 = 2287**, not 11/12 = 2162, and the limit is closed rather than
   carried.
10. **`GS28` pins WORDS, not BEHAVIOUR.** It cannot tell that the sash actually
    persists or that the class boxes actually restore — only that §11.7 still
    **claims** they do. Two-pane item 14's eyeball row is the only thing that can
    close that gap, and it is still unticked. Recorded at the head of the ledger's
    eyeball queue so a later reader cannot mistake a green `GS28` for visual
    verification.
11. **⚠ NEW, FROM THE FIX-UP'S VERIFIER: `GS29` CANNOT SEE THE THIRD SITE.** The
    triple lived in three places; `GS29` is a **within-file** oracle over two.
    Rotting `src/wave_viewer.tcl`'s `browser_class_filter` comment back to
    `1191 -> 137 -> 111, nets-only 110` — **the one site item 19 actually edited
    in source** — leaves **all 15 headless files GREEN with every count exact**.
    The check title says *"elsewhere in the same file"* and a divergence bullet
    calls it a within-file oracle, so it is honestly **scoped**; but the commit
    message and this receipt's earlier prose (*"`GS29` forbids recurrence"*) read
    **broader than the check is**, and that is the overclaim being retracted here.
12. **⚠ NEW: §14's device-node counts have no doc oracle.** Reverting the spec's
    `303 → 278` and `84 → 78` rows reds **nothing**. `TP35` pins 84 and 303
    against the committed fixture **in code**, so only the prose can rot — but it
    is the same shape as the finding that got this item rejected, one section
    away from the section that was fixed.
13. **⚠ NEW: `GS22`'s replacement comment overstates by the same kind of margin
    as the title it replaced.** It says the batch's other minted procs are
    *"covered only INDIRECTLY, by `GS23`'s exact 57"*. **MEASURED: 28 procs minted
    by two-pane item 11** — the whole `browser_sea_draw` / `_hit` / `_click` /
    `_colw` / `_rowh` / `_canvas` / `_configure` / `_label` / `_own` / `_extend` /
    `_say` / `_toggle` / `_descend_to` / `_copy_names` / `_sel_names` /
    `_target_path` / `_send_to_add_trace` / `_plot_at` / `_plot_idx` /
    `_menu_build` / `_ids` / `_post` / `_unpost` / `_tip` family — appear
    **nowhere** in the parent spec, so `GS23`'s 57 does not cover them either. The
    57-name list is plainly a **curated public-surface contract** (it names
    `browser_sea_build`/`_layout`/`_names`/`_refresh`/`_selection` and deliberately
    omits the drawing internals), which is a defensible shipped reality — but the
    PLAN's chartered *"every proc this batch minted is named"* is **not literally
    met**. One sentence, not a rework.

---

## 10. Divergences from the PLAN

1. `GS10`-`GS15` → **`GS22`-`GS27`** (all five colliding, measured), plus
   `GS28`-`GS29` at the fix-up. **Next free `GS30`**; the `GH` band untouched
   beyond `GH11`.
2. `GH11`'s control floor **`>= 16`**, not `>= 14`.
3. The PLAN's `GS10` list dropped `browser_tree` and `browser_sea` — **neither
   proc exists**; naming them reds `GS1` twice.
4. "the fourteen `data-bseq` rows" → **sixteen**, and untouched by this item.
5. `>= 48` floor satisfied at **57**, not the PLAN's 48-by-arithmetic.
6. §14's `78→84 / 278→303` **REFUSED**; the refusal written into §14 so nobody
   executes the bullet later. (Its cost is declared limit 12.)
7. Six PLAN bullets were already landed; executing them would have been churn.
8. The four-file lockstep is **not** "`BT09` **or** `BX13`" — they are different
   levers and both were measured (§7.1 `S4(i)`/`S4(ii)`).
9. `S5` as the PLAN framed it does **not** isolate `GH11`; **`S5b` does**.
10. "All eight `--nogui` files" → **fifteen** files and **twelve** X suites.
11. §12.1's accessor instruction rewritten as **history** (never introduced), not
    as work owed.
12. Item 18's three handed-on divergences (§3.3 rows-vs-nodes, §8.2's "prefix",
    §7.4's "is logged") were all closed here; §7.4's correction is that the
    auto-tick writes **no log line at all**.
13. **The fix-up touches `doc/waveform_viewer_guide.html` in ZERO places.** Item
    19 had already written §11.7 correctly; the finding was a **missing oracle**,
    not missing text, so the repair is entirely in the test file plus the docs
    that mis-described it.
14. **The fix-up touches no `src/` file.** `git diff --name-only HEAD -- src/` is
    empty, so the frozen bare-name oracles cannot have moved — re-grepped anyway.
15. **`GS29` is deliberately a within-file AGREEMENT oracle**, not a spot literal
    pinning 119. A spot literal would have caught *this instance*; the agreement
    form catches the **class** — a number corrected in one place and left stale in
    another, which is what actually happened. `SAB-C2` shows it reds from the
    other surface too.
16. **`GS29`'s patterns are ASCII-only on purpose.** §5.4's sentence uses a
    Unicode arrow; a pattern containing it would depend on the encoding the test
    file reads the spec under. `nets-only \*\*N\*\*` is the same anchor with no
    non-ASCII byte.
17. **`PLAN.md:1364` also carries the stale figure** (*"tb_charge_pump drops
    1191 → 137"*). **NOT corrected:** `PLAN.md` is a forecast document explicitly
    outside item 19's scope, and the batch rule is that the PLAN gets corrected
    **in the receipt** rather than rewritten. Flagged here rather than silently
    fixed or silently ignored.
18. **The false claims were corrected IN PLACE**, in both the spec (§5.4's
    *"corrected both files in one commit"*) and this receipt (§8's *"The same
    figures sat in two-pane §6"*), each with a visible note saying what it used to
    say and why it was wrong — not quietly reworded.

---

## 11. Owed / for the next item

* **The batch is closed, and the eyeball queue is not.** Four rows remain
  unticked — **18, 15, 14, 13** — and **item 14 is `[F]`**. `GS28` makes §11.7's
  *words* stop rotting; only item 14's row can say the words are not confidently
  describing a feature that does not work.
* **`GS29`'s third site (declared limit 11).** The `browser_class_filter` source
  comment carries the same triple with **no oracle at all**. Whoever next touches
  that comment either keeps it right by hand or widens the oracle across the file
  boundary.
* **§14's device-node counts (declared limit 12)** have no doc oracle; `TP35`
  pins the numbers in code, so the exposure is prose-only.
* **`GS23`'s exact 57 is not "every proc the batch minted" (declared limit 13)** —
  28 of item 11's `browser_sea_*` internals are in neither the roster nor the
  contract list. If a later item wants the PLAN's literal charter, that is the
  gap, and it is a **policy decision** (curated public surface vs. full
  inventory), not an oversight to patch blindly.
* **§7.2's three-state caption** still owns the `.ph` count line's class-filter
  blindness, and **`browser_show_path`'s bar clause** is still stale. Neither is
  item 19's; twelve byte-identity checks pin the first.
* **`GS23` will red on the next contract-list edit** — by design. Budget one
  restatement.
* **Next free ids, all re-measured, none taken on trust:** `GS30`, `GH12`,
  `BP79`, `BK44`, `BD71`, `BT48`, `BX57`, `BW79`. Next free issue number:
  **0226** (0225 filed by this item).
* **Driver discipline, from §3.5:** take the sabotage backup **once, before the
  first patch**. A harness that re-takes it per patch will restore a mutated file,
  print *"byte-identical: True"*, and run green.
