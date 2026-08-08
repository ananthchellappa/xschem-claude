# TWO-PANE item 13 — receipt

`browser_reveal` / `browser_tree_apply` under collapsed-by-default.
Spec `doc/claude/specs/waveform_signal_browser_two_pane.md` **R1 / R3 / §4.2 / §7.3**.
Work item: `PLAN.md` two-pane item 13 (**not** single-pane item 13).

Measured 2026-08-07/08 on `d5372433` + the item-12 tree, **Xvfb arm** (unattended
window, 393 min left at the first run, 356 at the last — no window-manager claim
anywhere in this item).

| | |
|---|---|
| ships as | **`9d5cdd26`** (fixup) on top of **`24fb6769`** (the item) |
| ledger mark | **`[E]` — DONE-PIXEL.** Never `[x]`: the deliverable is visible UI and no check in this batch judges pixels. The eyeball script is **§9**. |
| arms | headless **1619 / 0 fail** · X **11/11, 2149** |
| sabotages | **9/9 fire exactly on target** (8 the item's, 1 the verifier's own) |
| independently re-run | both arms, from a clean tree, by the item-13 verifier — not adopted from the implementer's numbers |

---

## 0. FIXUP — what the adversarial verifier found, and what changed

The item shipped as `24fb6769`. A verifier rejected it on **one real coverage
hole** plus two bookkeeping faults. All three are fixed in `9d5cdd26`; **no
behaviour changed** — `git diff 24fb6769 9d5cdd26 -- src/wave_viewer.tcl` has
**zero non-comment lines**, every added and removed line begins with `#`. The
second verifier checked that line by line rather than taking the claim.

### (a) THE HOLE — the headline claim had no OBSERVABLE witness ✔ FIXED

Every live witness for "the reveal expands the CHAIN and stops, the TARGET is
left closed" — `BW68` leg 5 and `BX31` leg 3 — reveals **`g:x1.x2`**, and
`BW69` in this same band **asserts that node is CHILDLESS** (`{0 1 0 {}}`). On a
childless row `-open` is a value ttk stores and reports but **never renders**:
there is no expander either way, so the claim changed nothing the user could see.

The verifier proved it with a sabotage the whole batch was blind to:

```
V4  (strictly ADDITIVE, guarded so it can only OPEN, never close;
     written `-open true` so BW15's literal regexp cannot match it)
  if {[llength [$tv children $id]] > 0} { catch {$tv item $id -open true} }
```

That is **exactly the pre-item-13 behaviour in the only node class where it is
observable**, and on `24fb6769` it passed all four suites in BOTH arms.

**Fix: `BW77` + `BW78`, on the SHIPPED panes fixture — no new fixture.** `g:x1`
is already in that fixture and HAS children (`{g:x1.x2 g:x1.y3}`, measured).

| id | claim | RED-FIRST evidence |
|---|---|---|
| `BW77` | a reveal onto a node **that has children** opens the chain ABOVE it and leaves the node itself CLOSED | **RED under V4**, `panes` 81 checks / **1** red — `BW77` and nothing else; `i12` 123/0, `i1315` 167/0 |
| `BW78` | `BW77`'s POSITIVE CONTROL: that target really HAS CHILDREN and `-open` round-trips on it — the leg `BW69` could not carry | green (declared control); it is what makes `BW77`'s `0` a **visible** claim rather than a stored attribute |

`BW77` leg 6 is spent on `g:x1.x2`, a **DESCENDANT** (in this fixture `g:x1` has
no same-level sibling), so it restates `S2`'s "not a subtree" claim on the
observable node. Legs 3/4 still exclude "the reveal did nothing"; leg 1's
`none` still proves the tree was fully collapsed on entry.

**Band re-measured before use**: highest `BW` in `tests/headless/*.tcl` **and**
the batch docs was `BW76`. `BW77`/`BW78` are the first free. Nothing renumbered;
item 15's `BD60`-`BD70` untouched (the fixup diff adds no `BD` id).

### (b) THE EYEBALL — owed, and it had been filed as a "declared limit" ✔ FIXED

The deliverable is visible UI, and no check judges the pixels. The old §7 bullet
("`browser_reveal`'s `-open` deletion is not observable in the `sea` pane by a
check here") **filed that as a limit when it is an owed eyeball** — and it is
the same blind spot that hid (a): *"no check judges the pixels"* was recorded as
acceptable instead of as a debt. Item 13 is now **`[E]`** in the LEDGER with a
queue row; the script is **§9**.

### (c) THE MIS-CITATION ✔ FIXED

`browser_reveal`'s rewritten header cited **§4.2** for "the target is left
closed". §4.2 (`:250-253`) rules only on WHO may reach `see` and that the
persisted open set beats it; it says **nothing** about the target's own row. The
ruling is **R3** (`:107`, the §2.1 rulings table: *"The lower pane shows the
selected node's own-level signals only — not descendants"*). The header now says
so and says what §4.2 *is*, so a later reader does not go hunting. Both spec
sections were read verbatim by the second verifier, not taken on trust. The
receipt's OTHER §4.2 citation — the union refusal in **§8** — is
verbatim-correct and stands.

---

## 1. The baselines, before and after

Both arms were reproduced on the UNCHANGED tree **before a line was written**, so
every red afterwards is attributable to this item.

| arm | recorded baseline (item 12, `e5347591`) | re-measured before | after `24fb6769` | **after `9d5cdd26` (ships)** |
|---|---|---|---|---|
| headless, 14 files | **1618**, 0 fail | **1618**, 0 fail ✔ | 1619, 0 fail | **1619**, 0 fail |
| X, 11 suites | **11/11**, 2136 | **11/11**, 2136 ✔ | 11/11, 2147 | **11/11, 2149** |

**Per-file headless, after (verifier's own run, parsed from each file's own
`RESULT:` line):** sigsearch 146, sea 6, sigbrowser 135, 2pane 108, **panes 15**,
i11 50, i12 40, i1315 80, i14 47, grid 230, modes 212, viewer 57, markers 437,
tabs 56 = **1619**. The ONLY delta from the recorded baseline is `panes` +1.

**Per-suite X, after:** **panes 81**, sigbrowser 353, sea 79, i11 74, i12 123,
i1315 167, i14 91, 2pane 108, sigsearch 233, grid 355, modes 485 = **2149**. The
whole +13 is inside item 13's own file. `i12` staying at **123** is the proof
that `BX31`'s third leg is a **LEG, not a check**; `i1315` staying at **167** is
the proof that the `BP54` change is a **comment**, not an expected value.

**Why +13 and not +12:** 12 distinct ids, 13 check *calls* — `BW74` is used
twice (the §7.3 root fallback, and its REFUSED other reading). Measured:
`grep -cE '^\s*check \{BW(15|68|69|7[0-9])' test_wave_sigbrowser_panes.tcl` == 13.
The LEDGER's one-line count said "12 checks" and has been corrected in the same
pass that recorded this verdict.

**The LEDGER baseline is therefore MOVED, not drifted**, and the reason is
written beside the new numbers there. Nothing was silently adopted: the second
verifier re-ran both arms itself from a clean tree (`git status --porcelain -uno`
empty before and after every run) and the numbers below are that run's.

**No baseline fail, and no known flake fired.** `BR25`, `MG16` and a whole-suite
`NORESULT` from a WSLg Xwayland death are the three the LEDGER lists; the Xvfb
arm is immune to the third and the other two did not appear in any run.

### Frozen oracles — re-grepped after every source edit

| oracle | expected | measured |
|---|---|---|
| `BW53` — `$tv see` count in `browser_populate` / `browser_reveal` | `{0 1}` | `{0 1}` ✔ |
| `BD06` — bare `browser_alldbs` file-wide | 2 | 2 ✔ |
| `BW59` — bare `browser_devint` / `browser_srccur` | `{2 2}` | `{2 2}` ✔ |
| `BP07`/`BT08`/`BW09`/`BW10` — `browser_width`'s four literals | green | green ✔ |
| `GH0`/`GH2`/`GH4`/`GH8`/`GH9` — 16 keys / 11 accelerators / **15** browser gesture rows | green | green ✔ (item 13 adds no `bind`, no key, no accelerator) |
| `GS0`-`GS3` — spec↔source proc lockstep | green | green ✔ (nothing renamed, nothing deleted) |
| the `.ph` byte-identical pins (`BD52`, `BX37`, `BX42`, `BX44`-`BX46`, `BH50`, `BH51`, `BH54`) | green | green ✔ — item 13 changes no `browser_say` wording |
| `BP01`/`BR01` — "every proc body was found" | green | green ✔ |
| `browser_root_id` bare-name count | 7 → **8** (one new call site) | 8 ✔, and **no check counts it** — grepped; the only bare-name counters are `browser_alldbs`, `browser_devint`, `browser_srccur` |

**No accessor is named in any comment added to `src/wave_viewer.tcl`** — the
standing rule item 12 paid for. See §3.3: the fixup's first draft broke it and
was reworded before it could ship.

`make -C src` says *"Nothing to be done"*: this item is Tcl + tests + docs and
touches no compile unit.

---

## 2. ⚠⚠ What the PLAN got wrong — with the measurement that says so

Seven items, every one caught by measuring rather than by reading.

| # | PLAN says | MEASURED |
|---|---|---|
| 1 | `browser_reveal` at `src/wave_viewer.tcl:7650` | **`:9468`** (drift +1818) |
| 2 | `browser_tree_apply` at `:8137` | **`:10008`** (drift +1871) |
| 3 | band `BW50`-`BW58` | **all nine spent**: `BW50`-`BW53` by item 10, `BW56`-`BW58` by item 12. First free measured **`BW68`**; the one SOURCE check takes **`BW15`** out of this file's own 01-19 "both arms" block, so `--nogui` gets a witness (1618 → 1619) |
| 4 | `BX31 \| i12:412`, edit = add `[$BXTV item {g:} -open]` | `i12:555/558/561`, and **the prescribed leg is IMPOSSIBLE**: `BX20` (`i12:521-524`) asserts `$BXTV exists {g:}` == 0 — that fixture is deliberately the no-root shape. A third leg on the TARGET is used instead |
| 5 | `BP53 … keep {0 1}` | under the PLAN's **own** union it reads `{1 1 {g:x1 g:y3}}` — **the PLAN's prescription reds its own "unchanged" claim** |
| 6 | `BP54 … new column {0 g:x1 0}` via `$BPT parent`/`exists` | stale — that was PLAN item 10's *proposal*; item 10 actually shipped `bp_order_probe` → `{1 0 g:x1.x2}` (`i1315:1495`) |
| 7 | union the selection's ancestor chain into the applied open set | **REFUSED — spec §4.2.** Full evidence in §8 |

### 2.1 The node ids are not the PLAN's either

Every PLAN check for this item names `g:y3`. **MEASURED: there is no `g:y3` in
`test_wave_sigbrowser_panes.tcl`** — its fixture tree is exactly
`{g: g:x1 g:x1.x2 g:x1.y3}`, and `g:y3` belongs to
`test_wave_sigbrowser_i1315.tcl`'s raw-backed fixture (`BP43a`). `BW51`/`BW52`/
`BW53`/`BW55` as written are **unwritable in the file the PLAN puts them in**.

Worse, `g:x1` is the root's **only** child, so the PLAN's *"a SIBLING of an
ancestor stays collapsed"* is not expressible on this tree at all. The real
discriminator is the **target's** sibling `g:x1.y3` — `BW68` leg 6.

`BW54` as the PLAN writes it (`{{g: g:x1} visible}`) is not merely unwritable but
**a §4.2 violation dressed as a target**: measured,
`browser_tree_apply {open {g:} sel {g:x1.x2}}` gives openset `{g:}` with the
selection collapsed out of view, and under the corrected scope it must STAY that
way.

### 2.2 Two PLAN checks measured VACUOUS before they were written

* **`BW56`** *("a multi-id `sel` narrows to its first surviving id")* — today's
  keep-all **already** answers `g:x1.x2`, because only one id survives. Reshaped:
  `BW72`/`BW73` use **two** survivors, which is the only non-vacuous form.
* **`BW58`** *("reveal on `{}` answers 0 and leaves the selection alone")* —
  already true, and `BX33` (`i12:607-611`) already owns the claim. Kept only as
  `BW71`, a **paired** control that makes the same call on a real id.

---

## 3. Traps that cost real time — all found by running, not by reading

### 3.1 ⚠⚠ THE HEADLINE CLAIM HAD NO OBSERVABLE WITNESS

The item was **rejected** for it. Full account in §0(a); recorded here as the
trap it is, because the shape generalises: *a claim about a widget attribute is
only a claim about the UI on the node class where the attribute is RENDERED.*
`-open` on a childless ttk row is stored, reported, and drawn nowhere. Twelve
green checks and eight green sabotage rows all sat on such a row.

The tell was available the whole time and nobody read it: `BW69`, in the same
band, **asserts the witness node is childless**. The evidence that the claim was
untested was written three lines below the claim.

### 3.2 ⚠⚠ R10's `Ctrl-Alt-V` DOES NOT EXIST YET — a false `[F]` waiting to happen

The first verifier's own remedy wording told the eyeballer to reach the browser
with **Ctrl-Alt-V**. Grepped `src/*.tcl` and `src/*.c` for
`Control-Alt-v` / `Control-Alt-V` / `Alt-Control-v`: **nothing anywhere.** R10's
chord is TWO-PANE **item 17b**'s unshipped work, and the LEDGER's own dependency
table says so ("*hard*: there is no `Control-Alt-v` binding anywhere in `src/`
yet"). Following the wording literally would have had a human press a dead key
and report item 13 as **`[F]`**.

The live route today is **Tools → Show in Signal Browser**, accelerator
**Ctrl+5**, `-command "ase::show_in_browser_for_current …"` at
`src/xschem.tcl:14942`. Both §9 and the LEDGER's eyeball row say so, with an
explicit note to re-read the step after 17b lands.

### 3.3 ⚠⚠ THE BARE-NAME COMMENT RULE CAUGHT THE FIXUP'S FIRST DRAFT

Item 12 paid for this rule once (`BD06` counted `browser_alldbs` bare, file-wide,
and a *mention in prose is indistinguishable from a call site*). The fixup's
first draft of `browser_reveal`'s header named **`browser_tree_apply`** in prose.

Measured before acting: no check counts that bare name today, and the full X arm
passed with it present. It was reworded anyway — to *"the STATE-RESTORE path's
business"* — so the invariant *"no accessor is named in any comment in this
file"* stays **literally** true rather than true-by-luck, and `panes`/
`sigbrowser`/`i12` were re-run after the reword (81 / 353 / 123, all PASS).

### 3.4 `BW75` WAS ASSERTING ITS OWN NO-OP

First cut, four legs, claim: *"with no design root the fallback is a no-op"*.
That is byte-identical to *"there is no fallback at all"*, so it was **green
before item 13's code existed** — the exact shape item 12 shipped twice. See §7.

### 3.5 `xarm.sh suites` TAKES FULL TEST-FILE NAMES

`doc/claude/signal_browser_2pane_batch/xarm.sh suites` wants
`test_wave_sigbrowser_panes`, **not** the short suite labels the LEDGER's table
uses (`panes`). A short name does not error usefully — it **FATALs** with
*"no such test file"*, which reads at a glance like a broken suite rather than a
typo'd argument.

### 3.6 THE MEASUREMENT ITSELF NEEDS A CONTROL

The second verifier's first parse of the headless arm scored **0 checks** on a
wrong `RESULT:` regexp. It fixed the parser instead of believing it. A harness
that reports zero is not reporting green; the same disbelief is what
`BW78`/`BW69` buy at the check level.

### 3.7 THE §4.2 MIS-CITATION

A citation that points at a real section which rules on a *different* question is
worse than no citation: it survives review, because the section exists. Fixed in
§0(c). The rule it leaves behind: **cite the sentence, not the section.**

---

## 4. What landed

### Source — `src/wave_viewer.tcl`, two procs, four comment rewrites

* **`wviewer::browser_reveal` (`:9468`)** — deleted exactly **one line**,
  `catch {$tv item $id -open 1}`. `$tv selection set`, `$tv focus`,
  `update idletasks` and `$tv see` are byte-identical.
  **No expand-ancestors loop was written**: `see` IS the expansion (MEASURED —
  from a fully collapsed tree, revealing `g:x1.x2` opens `g:` and `g:x1` and
  leaves `g:x1.y3` closed), so a loop would be dead code no sabotage could reach.
  Header paragraph rewritten in place: the target is left closed, and the ruling
  is **R3** — the lower pane is what answers "what is inside".
* **`wviewer::browser_tree_apply` (`:10008`)** — selection-first / open-set-last
  order untouched. The `keep` block now narrows to the **first surviving id**
  (§7.3), and an all-dead-but-non-empty `sel` falls back to the design root read
  from the **row model** (`browserrows($token)`), never from the widget. An
  **empty** `sel` stays a no-op. `variable browserrows` added.
* **Four stale comments rewritten in place, none deleted:**
  1. `browser_reveal`'s *"Opening the TARGET … is wanted"* → the R3 reason it is not;
  2. `browser_tree_apply`'s *"`browser_reveal` is NOT reused here: it also
     force-opens the node it lands on"* → that reason is now false; the surviving
     reason is that a restore must let the **open set** win;
  3. `browser_tree_state`'s *"THE DEFAULT IS ALL-OPEN AND EMPTY-SELECTION,
     because `browser_populate` inserts every row `-open 1`"* — **stale since
     two-pane item 10**, which inverted both signs and never fixed it;
  4. **(fixup)** `browser_reveal`'s header again: R3 named as the ruling, §4.2
     described for what it actually is, and the accessor name removed (§3.3).
* A `⚠⚠⚠` block on `browser_tree_apply` recording the **refused** union (§8).

### Tests

* **`tests/headless/test_wave_sigbrowser_panes.tcl`** — the whole surface.
  `BW15` (`:304`) in the file's own **01-19 "both arms"** block, so the item has
  a `--nogui` witness; `BW68`-`BW78` (`:1287`-`:1415`) in the X-only block.
  **13 check calls, 12 ids** — headless 14 → **15**, X 68 → **81**.
* **`tests/headless/test_wave_sigbrowser_i12.tcl`** — `BX31` **restated with a
  third leg** (§5). Count unchanged at **123**.
* **`tests/headless/test_wave_sigbrowser_i1315.tcl`** — `BP54`'s **comment**
  rewritten (§5). Count unchanged at **167**.
* **No check was deleted anywhere in this item.**

---

## 5. Every existing check restated, and why

| check | what changed | why, and why not deletion |
|---|---|---|
| **`BX31`** (`i12:555/558/561`) | **a third leg**, `{visible 1}` → `{visible 1 0}` | its two old legs pin "scrolled into view" + "selected"; neither can see the new claim. The PLAN's prescribed leg (`[$BXTV item {g:} -open]`) is impossible on this fixture — `BX20` asserts the root does not exist — so the leg lands on the TARGET. A LEG, not a check: `i12` stays at 123 |
| **`BP54`** (`i1315:1495`) | **its comment only** — the expected value is untouched and it stays green | it previously said, in so many words, *"TWO-PANE ITEM 13 REDS THIS CHECK BY DESIGN"*. It does not: the union that would have red it was **refused** (§8). The comment is now the record of the refusal rather than a stale prediction |
| **`BW68`** | **NOT changed, NOT deleted** by the fixup | it stays the **childless-node** witness, and its leg 6 is a true SIBLING — a claim `BW77`'s fixture position cannot make (`g:x1` has no same-level sibling). `BW77` is **additive beside it**, not a replacement: `BW68` was insufficient, not wrong |
| **`BW69`** | **NOT changed** | its `{0 1 0 {}}` is now load-bearing **in the opposite direction**: it is the PROOF that `BW68` sits on an unobservable row. Cited as such in the source comment, §0(a), and the LEDGER entry |
| **`BW53`** (frozen) | not restated — recorded because it is the **tightest constraint on the patch** | it counts `$tv see`: 0 in `browser_populate`, 1 in `browser_reveal`. The patch had to delete `$tv item -open` and **not** `$tv see`, and add neither a second `see` nor an expand loop. It held |
| **`BW24`** (item 12's) | untouched | carried forward from item 12's receipt: it, not `BW56`, is the build-time default pin item 14 will have to restate |

---

## 6. Sabotages — 9 rows, all reverted, all attributable

**Driver contract (both rounds):** a lock dir; an `EXIT`/`INT`/`TERM` trap that
restores from a **byte-exact backup** (never `git checkout --`); a **pre-state
run asserting the expected check count and 0 red BEFORE patching**; an md5
compare that **ABORTS if the mutation never reached disk**; the patched line
re-read off disk and the full injection `diff` echoed; a `diff -q` restore proof;
and an output filter that counts **`NORESULT`, `TIMEOUT` and `UNEXPECTED ERROR`
as reds**.

*"failed exactly"* = the injection reds the checks named and **no others**, with
no check-count shortfall (an early abort that hides checks is not a pass).
*"positive control"* = the check that stayed **green** and thereby excludes the
rival explanation *"something else broke"*.

### 6.1 The item's own round (`scratchpad/sab13.sh` + `patch13.py`) — src md5 `7eff8bb4…` before and after every row

| # | injection | reds | failed exactly? | positive control | reverted? |
|---|---|---|---|---|---|
| **S1** | re-add `catch {$tv item $id -open 1}` | `BW15`, `BW68` (leg 5), `BX31` (leg 3) — 2 files | **yes** | `BW69` green → the `-open` **read** is not what broke | yes, `diff -q` clean |
| **S2** | open every child of every ancestor (a subtree reveal) | `BW68` (legs 5 **and** 6: `{none 1 1 1 1 1 visible g:x1.x2}`), `BX31` | **yes** | **`BW15` stays green** — the discriminator between S2 and S1; `BW68` legs 3/4 green exclude "the reveal did nothing" | yes |
| **S3** | delete `$tv see` | `BW15`, `BW53`, `BW68` (panes); `BX31`, `BX32`, `BX33`, `BX34`, `BX39`, `BX42`×2, `BX43`, `BX51` (i12); `BQ53` (sea) | **yes** — wide **and entirely attributable**: every red is a visibility/scroll claim | `BW69`/`BW70`/`BW71` green → the selection still moves | yes |
| **S4** | **implement the PLAN's union** | `BW76` (panes), `BP53` + `BP54` (i1315) — 3 files, one proc | **yes** | `BW72`/`BW73`/`BW74` green → "the narrowing broke" excluded | yes |
| **S5** | narrow with `lindex $sel 0` (existence check kept) | `BW73` **alone** | **yes** | **`BW72` green is the discriminator** | yes |
| **S6** | drop the "was non-empty" guard | `BW74`b **alone** (`{g:x1.y3 1 g: g:}` vs `{… g:x1.y3 …}`) | **yes** | `BW74`a green | yes |
| **S7** | read the root from the widget, not the row model | `BW75` **alone** | **yes** | `BW74`a green | yes |

No zero-red rows; no run showed a check-count shortfall.

### 6.2 The fixup round (`scratchpad/sab13fix.sh` + three `tclsh` patch scripts)

Same contract, with the pre-state printed as a **check count** rather than an
anchor count.

| # | injection | reds | failed exactly? | positive control | reverted? |
|---|---|---|---|---|---|
| **S8** = **`V4`** | **the FIRST VERIFIER'S OWN** — additive re-open of the target, guarded on `[llength [$tv children $id]] > 0`, written `-open true` so `BW15`'s literal regexp cannot match | **`BW77` ALONE** — `panes` 81/1, `i12` 123/0, `i1315` 167/0 | **yes**, and it is the hole's closure: **this reds NOTHING on `24fb6769`** | `BW78` green → "the read broke" excluded; `BW68` green → it is *silent on childless nodes*, which IS the blind spot | yes, byte-identical |
| **S1** (re-run) | verbatim re-add of `catch {$tv item $id -open 1}` | `BW15`, `BW68`, **`BW77`** (panes 81/3); `BX31` (i12 123/1) | **yes** | `BW78` green | yes |
| **S2** (re-run) | open the target and every descendant | `BW68`, **`BW77`** (panes 81/2); `BX31` (i12 123/1) | **yes** | **`BW15` still green** — still the S2/S1 discriminator; `BW68`/`BW77` legs 3/4 green | yes |

**The radius of S1/S2 widened by exactly one check, and that is the fix** —
`BW77` is not a new claim, it is the old claim measured where a user can see it.

### 6.3 THE SECOND VERIFIER'S OWN UNNAMED SABOTAGE — `S9`

Deliberately a **mechanism nobody in this item had named**. All eight prior
injections reach the defect through `$tv item $id -open …`. `S9` never writes
`-open` at all. In `browser_reveal`, `if {[catch {$tv see $id}]} { set ok 0 }`
became a scroll to the target's **first child**:

```
set sabseetgt $id
catch {if {[llength [$tv children $id]] > 0} { set sabseetgt [lindex [$tv children $id] 0] }}
if {[catch {$tv see $sabseetgt}]} { set ok 0 }
```

`see` opens every **ancestor** of what it is given, so seeing a child opens the
**target** — exactly the pre-item-13 observable behaviour, restored *through ttk*
rather than through an explicit open. It side-steps `BW15`'s literal source
regexp, it is invisible to S1/S2/V4's shape, and on a childless target it is a
**no-op** (so it is silent at `BW68`/`BX31` — precisely the blind spot the first
verifier found).

| # | injection | reds | failed exactly? | positive control | reverted? |
|---|---|---|---|---|---|
| **S9** | `see` the target's first CHILD instead of the target | **`BW77` and nothing else** — `panes` **81**/1 (count held, no shortfall), `i12` 123/0, `i1315` 167/0, `sigbrowser` 353/0 | **yes** | `BW78` green → "the read broke" excluded; **`BW68` green** → the S9/S1 discriminator | yes — pre-state asserted 81/0 **before** patching, md5 `61ded6bb…` → `aac41766…` → restored **byte-identical**, clean re-run 81/0 |

**Why this row matters more than the eight before it:** the item's headline claim
now has teeth on the node class where a user can see it, and **the teeth are not
specific to the one injection that exposed the hole.** A defect reintroduced by a
route nobody anticipated is still caught.

The second verifier also **reproduced `V4` itself** against the fixed tree under
the same contract: `panes` 81/1 = `BW77` alone, `i12` 123/0, restore byte-identical,
md5 back to `61ded6bb…`. The closure is attributable to exactly one check.

### 6.4 One honest inconsistency in the md5 record

The item's own round asserts src md5 **`7eff8bb4…`** before and after every row;
the verifier's round asserts **`61ded6bb…`**. They differ because the comment
reword of §3.3 landed **between** the two rounds — the second round ran on the
committed tree (`md5sum src/wave_viewer.tcl` == `61ded6bb03d9386aa6e7f555d1d8c405`
today). Different files, same contract. Recorded rather than smoothed over,
because a receipt that quietly harmonises two md5s is a receipt whose md5s mean
nothing.

---

## 7. What was VACUOUS on the red run, and what was done about it

* **`BW75` — mine, and the RED run is the only reason it is known.** Its first
  cut had four legs and asserted only *"with no design root the fallback is a
  no-op"*, which is byte-identical to *"there is no fallback at all"*: green
  before item 13's code existed. **Reworked to six legs** — legs 5-6 repeat the
  *same call* on the *restored* model, where the fallback must fire. Red-first on
  leg 6.
* **The five other green-before checks were each inspected on the red run** —
  `BW69`, `BW70`, `BW71`, `BW74`b, `BW76`. Each is a **declared** control that
  carries its positive evidence **in the same tuple** as its stability claim,
  which is what the anti-vacuity rule asks for. None was left as a bare "nothing
  changed".
* **Two PLAN checks were measured vacuous before being written** and reshaped
  rather than shipped: `BW56` and `BW58` (§2.2).
* **The fixup added NONE.** `BW77` was measured **RED-FIRST under the V4
  injection** — `panes` 81 checks / 1 red, `BW77` and nothing else. `BW78` is
  green before AND after and is **declared** as such: it is `BW77`'s positive
  control (this target HAS children, `-open` round-trips on it). Without `BW78`,
  `BW77`'s `0` leg would be re-running `BW69`'s mistake one level up.

---

## 8. Every divergence

**D1 — ⚠ ONE PLAN CLAUSE REFUSED: the union.** PLAN item 13 has three clauses;
two are implemented, the third is refused.

| clause | verdict |
|---|---|
| `browser_reveal` opens the ancestor chain, not the target | **KEPT** — as a one-line DELETION, not a loop |
| §7.3's narrowing lands in `browser_tree_apply` | **KEPT** |
| union the *selection's ancestor chain* into the applied open set | **REFUSED — spec §4.2** |

Spec §4.2 (`doc/claude/specs/waveform_signal_browser_two_pane.md:250-253`):

> the persisted `open` set must beat it — BP54 already pins that a persisted
> collapse beats `see`'s ancestor-expansion, **and that check stays green**.

MEASURED on the panes fixture, before any code changed:

* with **no `open` key** the open pass is skipped entirely and `see` has already
  opened the whole chain (`J-noopen = {1 1 {g: g:x1}}`) — the union is a
  **no-op exactly where it would be harmless**;
* with `{open {g: g:x1.y3} sel {g:x1.x2}}` the open pass runs last and leaves
  `g:x1` **closed** (`I-order = {1 0 {g: g:x1.y3} g:x1.x2}`) — the one state the
  union would flip, i.e. **a §4.2 violation exactly where it bites**.

It also breaks round-trip idempotency: the widened set is what the next
`browser_state` persists, so a user's collapse dissolves over sessions.
The union is now **sabotage S4** and reds `BW76` + `BP53` + `BP54` across three
files, with `BW72`/`BW73`/`BW74` green so "the narrowing broke" is excluded.
The refusal is recorded in **four** places: here, a `⚠⚠⚠` block on
`browser_tree_apply`, `BW76`'s own check name and comment, and the rewritten
`BP54` comment.

**D2 — the band is `BW15` + `BW68`-`BW78`, not the PLAN's `BW50`-`BW58`.** All
nine PLAN ids are spent (§2, row 3).

**D3 — the node ids are `g:x1` / `g:x1.x2` / `g:x1.y3`.** There is no `g:y3` in
this file (§2.1).

**D4 — `BX31`'s prescribed leg is impossible** and a TARGET leg is used instead
(§2, row 4; §5).

**D5 — no expand-ancestors loop was written.** `see` IS the expansion, measured;
a loop would be unreachable dead code (§4).

**D6 — `BW54` as the PLAN writes it is not written**, because under the corrected
scope it is a §4.2 violation rather than a target (§2.1).

**D7 — `BW56`/`BW58` reshaped, not written**, having measured vacuous (§2.2).

**D8 — the fixup shipped TWO checks where the verifier proposed ONE.** A lone
`BW77` would repeat the exact defect being fixed, one level up: `-open 0` on
`g:x1` means something **only if that node really has children**, and nothing in
the file asserted it. `BW78` is the positive control `BW69` could not carry, and
the fixture claim (`{g:x1.x2 g:x1.y3}`) is **measured**, not assumed.

**D9 — `BW77`'s leg 6 is a DESCENDANT, not a sibling**, despite the helper's
parameter name. MEASURED: `g:x1` is the root's only child, so it has no
same-level sibling; the leg is spent restating S2's "not a subtree" claim on the
observable node, and **the check comment says so** so a later reader does not
mis-read the tuple.

**D10 — the eyeball script says Ctrl+5, not R10's Ctrl-Alt-V**, against the first
verifier's own wording. Grepped: no `Control-Alt-v` binding exists anywhere in
`src/`. Following the wording literally would have produced a **false `[F]`**
(§3.2).

**D11 — the fixup's first-draft comment named `browser_tree_apply`** and was
reworded to *"the STATE-RESTORE path's business"* even though no check counts
that bare name, to keep the "no accessor is named in any comment" invariant
literally true; `panes`/`sigbrowser`/`i12` re-run after (§3.3).

**D12 — `browser_reveal`'s header cites R3, not §4.2** (§0(c)).

**D13 — bookkeeping, corrected at the ledger stage:** the LEDGER's item-13 line
said *"12 checks"*. There are **13 check calls over 12 ids** (`BW74` twice),
which is why `panes` moves +13. Corrected in the LEDGER; measured in §1.

---

## 9. THE OWED EYEBALL — item 13 is `[E]`, not `[x]`

No check in this batch judges pixels, and item 13's deliverable is visible UI.
`BW77`/`BW78` pin the widget **STATE** (`-open` reads 0 on a node that HAS
children); what they cannot judge is that the state **reads as the right thing on
screen**.

**Script — 2 minutes, needs a real display (Xvfb cannot answer it):**

1. Open the waveform viewer on a raw with hierarchy and show the sidebar.
2. In the schematic, select **an instance that CONTAINS other instances** — a
   group, not a leaf device. This is the whole point: on a childless node the
   claim is invisible, which is exactly how the hole in §0(a) survived.
3. **Tools → Show in Signal Browser** (accelerator **Ctrl+5** today —
   ⚠ **R10's Ctrl-Alt-V does not exist yet**, it is TWO-PANE item 17b's job, so
   an eyeballer following R10 literally will press a dead key and report a false
   `[F]`. **Re-read this step after 17b lands.**)
4. **(a)** The tree row for that instance scrolls into view, is selected, and its
   **expander stays CLOSED** — its ancestors above it are open, its own children
   are not shown.
5. **(b)** The LOWER pane fills with **that node's own-level signals** — this is
   R3, and it is the justification for (a). If the lower pane is empty or shows
   the parent's signals, (a) is wrong even though `BW77` is green.
6. **(c)** Click the expander by hand: it opens normally. The reveal declined to
   open it; it did not disable it.

**A LEAF instance answers nothing** — that node class is exactly where the
batch's checks were blind.

Fail on any of (a)/(b)/(c) → item 13 goes **`[F]`**, not `[E]`.

---

## 10. Declared limits

* **`BW77`/`BW78` pin WIDGET STATE, not PIXELS.** That the collapsed expander and
  the filled lower pane read correctly on screen is §9's owed eyeball. The fixup
  **narrows** the gap; it does not remove it.
* **The whole item is X-only bar one check.** `browser_reveal` and
  `browser_tree_apply` both need a live `ttk::treeview`, so `--nogui` sees only
  `BW15` and the headless total sits at 1619. That is a property of the procs,
  not a gap in the checks, and it is why `BW15` exists at all.
* **Measured under Xvfb, which has no window manager.** Nothing in item 13 needs
  one (it is all inside one toplevel), and the LEDGER records the Xvfb arm
  reproducing the `:0` arm exactly — so these numbers are comparable across the
  handback.
* **§9's step 3 is TIME-DEPENDENT.** It names Ctrl+5 because R10's Ctrl-Alt-V
  does not exist yet. Whoever lands item 17b must re-read that step. Flagged
  inline in both this receipt and the LEDGER's eyeball row.
* **The empty-`sel` reading of §7.3 is a RULING, not a derivation.** §7.3 says
  *"a list whose ids have all gone falls back to the root"*; an empty list has no
  ids that have gone. Adopted: the fallback fires only when `sel` was NON-empty.
  `browser_state_apply` passes `sel {}` for every legacy and default state, so
  the other reading would move the selection on **every** plain restore. Pinned
  by `BW74`b, red by S6.
* **The UI route `browser_show_path` is still pinned only on a CHILDLESS target.**
  (Second verifier's declared residual, not a defect.) `i12`'s fixture is
  deliberately the no-root shape and `BX20` asserts `g:x1.x2`/`g:x1.y3` are
  leaves, so a guarded re-open placed in **`browser_show_path`** instead of
  `browser_reveal` would evade every check. That would be a **new** defect in
  item 12's proc rather than a regression of item 13's claim — and §9 step 2
  exercises exactly that full route (Ctrl+5 → `ase::show_in_browser_for_current`
  → `browser_show_path` → `browser_reveal`) on a node with children, which is
  where it belongs. Recorded so the next reader does not rediscover it as a
  surprise.
* **This receipt's earlier measurement block is left standing, not rewritten.**
  The pre-fixup numbers (`panes` 79 / X 2147) appear in §1's table with the
  post-fixup ones beside them, rather than being overwritten, so the record of
  what the **rejected** version measured survives.

---

## 11. Owed to the next item

* **Item 13 unblocks item 14 (persistence) and is one of item 18's three
  dependencies** (12 ✔, 13 ✔, 17b outstanding).
* **The LEDGER baseline MOVED and is already updated**: headless **1619**
  (`panes` 15), X **2149** (`panes` 81). Item 14's verifier compares against
  *those*, not against 1618/2136.
* **`browser_sash {token {want {}}}` ALREADY EXISTS** and is already driven by
  `BW33` (`panes:453`). PLAN item 14's *"a new `browser_sash`"* is wrong.
* **PLAN item 14's band `BP60`-`BP69` is ALREADY PART-SPENT**: measured `BP` max
  is 61, so `BP60`/`BP61` are taken. **First free is `BP62`.**
* **First free ids after item 13, re-measured across `tests/headless/*.tcl` and
  the batch docs:** `BW` **79** (highest in use is 78, and 77/78 occur only in
  the new block), `BX` **54**, `BD` max 59 with item 15 owning `BD60`-`BD70`.
* **Item 13 adds no state key**, so `MG9` and `BP42`'s key list are untouched.
  It also adds no `bind`, no key and no accelerator, so `GH0`/`GH2`/`GH4`/`GH8`/
  `GH9` are untouched at 16 / 11 / **15**.
* **Item 12's carried note still stands:** the build-time default pin is `BW24`,
  not `BW56`. If item 14 makes the defaults come from a persisted file, `BW24` is
  the check to restate.
* **The eyeball is owed** (§9, LEDGER queue row). It blocks nothing, but item 13
  cannot become `[x]` until a human has run it — and a **LEAF** instance does not
  count.
