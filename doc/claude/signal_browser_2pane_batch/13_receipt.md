# TWO-PANE item 13 — receipt

`browser_reveal` / `browser_tree_apply` under collapsed-by-default.
Measured 2026-08-07/08 on `d5372433` + the item-12 tree, Xvfb arm (unattended
window, 393 min left at start — no window-manager claim in this item).

---

## 1. THE DIVERGENCE — one PLAN clause REFUSED, and the evidence for it

PLAN item 13 has three clauses. Two are implemented; the third is refused.

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

**The union is now sabotage S4.** MEASURED, injected into the shipped code:

```
SABOTAGE S4  (implement the PLAN's union)
  panes   FAIL -> BW76
  i12     PASS (123)
  i1315   FAIL -> BP53, BP54
  sea     PASS (79)
```

Three files, one proc, and `BW72`/`BW73`/`BW74` stay green so "the narrowing
broke" is excluded. The refusal is recorded in **four** places: this receipt, a
`⚠⚠⚠` block on `browser_tree_apply` in `src/wave_viewer.tcl`, `BW76`'s own check
name and comment, and the rewritten `BP54` comment in
`test_wave_sigbrowser_i1315.tcl` (which previously said, in so many words, "TWO-PANE
ITEM 13 REDS THIS CHECK BY DESIGN" — it does not, and that sentence is now the
record of the refusal instead of a prediction).

---

## 2. Source — `src/wave_viewer.tcl`, two procs, three comment rewrites

**`wviewer::browser_reveal` (`:9468`)** — deleted exactly one line,
`catch {$tv item $id -open 1}`. `$tv selection set`, `$tv focus`,
`update idletasks` and `$tv see` are byte-identical. **No expand-ancestors loop
was written**: `see` IS the expansion (MEASURED — from a fully collapsed tree a
reveal of `g:x1.x2` opens `g:` and `g:x1` and leaves `g:x1.y3` closed), so a loop
would be dead code no sabotage could reach. Header paragraph rewritten in place
to say the target is now left closed and why (R3: the lower pane answers "what is
inside").

**`wviewer::browser_tree_apply` (`:10008`)** — selection-first / open-set-last
order untouched. The `keep` block now narrows to the **first surviving id**
(§7.3), and an all-dead-but-non-empty `sel` falls back to the design root read
from the **row model** (`browserrows($token)`), never from the widget. An
**empty** `sel` stays a no-op. `variable browserrows` added.

**Three stale comments rewritten in place** (none deleted):
1. `browser_reveal`'s "Opening the TARGET … is wanted" → now the R3 reason it is not;
2. `browser_tree_apply`'s "`browser_reveal` is NOT reused here: it also force-opens
   the node it lands on" → that reason is now false; the surviving reason is that a
   restore must let the open set win;
3. `browser_tree_state`'s "THE DEFAULT IS ALL-OPEN AND EMPTY-SELECTION, because
   `browser_populate` inserts every row `-open 1` and clears the selection" —
   **stale since two-pane item 10, which inverted both signs and never fixed it.**

---

## 3. The band — MEASURED, and it is not the PLAN's

The PLAN assigns `BW50`-`BW58`. **All nine are spent**: `BW50`-`BW53` by item 10,
`BW56`-`BW58` by item 12. First free id measured `BW68`. The one SOURCE check
takes `BW15` out of this file's own 01-19 "both arms" block, so the `--nogui` arm
gets a witness (1618 → 1619).

| id | claim | RED run |
|---|---|---|
| `BW15` | SOURCE: the target-open line is gone, `see` still there exactly once | **RED** `{1 1 1}` vs `{1 0 1}` |
| `BW68` | reveal opens the ANCESTOR CHAIN and nothing else | **RED** leg 5 `1` vs `0` |
| `BW69` | `-open` really is a live discriminator on the childless target | green (declared control) |
| `BW70` | R1: more than one subtree at once, and a reveal closes none | green (declared control) |
| `BW71` | the empty-id refusal, PAIRED with the same call on a real id | green (declared, owner `BX33`) |
| `BW72` | §7.3: two survivors narrow to the first | **RED** `{1 {g:x1.x2 g:x1.y3}}` |
| `BW73` | …first **surviving**, not `lindex 0` | **RED** same |
| `BW74`a | all-dead `sel` → the design root | **RED** leg 3 `g:x1.y3` vs `g:` |
| `BW74`b | an EMPTY `sel` is NOT "all dead" | green (declared) |
| `BW75` | the NO-ROOT arm is a no-op, and the SAME call on the restored model is not | **RED** leg 6 (after rework) |
| `BW76` | §4.2: the persisted open set still BEATS `see` | green before AND after, on purpose |
| `BX31` | restated, third leg: the TARGET is left closed | **RED** `{visible 1 1}` vs `{visible 1 0}` |

### The node ids are not the PLAN's either

Every PLAN check names `g:y3`. **MEASURED: there is no `g:y3` in
`test_wave_sigbrowser_panes.tcl`** — its fixture tree is exactly
`{g: g:x1 g:x1.x2 g:x1.y3}`, and `g:y3` belongs to `test_wave_sigbrowser_i1315.tcl`'s
raw-backed fixture (`BP43a`). `BW51`/`BW52`/`BW53`/`BW55` as written are unwritable
here. Worse, `g:x1` is the root's **only** child, so the PLAN's "a SIBLING of an
ancestor stays collapsed" is not expressible on this tree at all. The real
discriminator is the **target's** sibling `g:x1.y3`, which is `BW68` leg 6.

### The RED run found one vacuous check — and it was mine

`BW75`'s first cut had four legs and asserted only "with no design root the
fallback is a no-op". **That is byte-identical to "there is no fallback at all",
so it was green before item 13's code existed** — exactly the shape item 12
shipped twice. Reworked to six legs: legs 5-6 repeat the *same call* on the
*restored* model, where the fallback must fire. It is now red-first on leg 6.
The other five green-before checks (`BW69`, `BW70`, `BW71`, `BW74`b, `BW76`) were
each inspected on the red run and each is a **declared** control carrying its
positive evidence in the same tuple.

---

## 4. Five PLAN numbers re-measured and found wrong

| PLAN says | MEASURED |
|---|---|
| `browser_reveal` at `:7650` | `src/wave_viewer.tcl:9468` (drift +1818) |
| `browser_tree_apply` at `:8137` | `:10008` (drift +1871) |
| `BX31 \| i12:412`, edit = add `[$BXTV item {g:} -open]` | `i12:555/558/561`; **the prescribed leg is IMPOSSIBLE** — `BX20` (`i12:521-524`) asserts `$BXTV exists {g:}` == 0, the deliberate no-root fixture. A third leg on the TARGET is used instead |
| `BP53 … keep {0 1}` | under the PLAN's own union it reads `{1 1 {g:x1 g:y3}}` — **the PLAN's prescription reds its own "unchanged" claim** |
| `BP54 … new column {0 g:x1 0}` | stale: item 10 shipped `bp_order_probe` → `{1 0 g:x1.x2}` (`i1315:1495`) |

Two PLAN checks were MEASURED **vacuous** and re-shaped rather than written:
`BW56`'s one-survivor narrowing (today's keep-all already answers `g:x1.x2`, so
`BW72`/`BW73` use two survivors) and `BW58`'s empty-id reveal (already 0 with the
selection untouched; its owner is `BX33`, and `BW71` carries it only as a paired
control).

---

## 5. Measurements

**Baselines re-measured on the unchanged tree first**, both matching the LEDGER
exactly: headless **1618 / 0 fail**, all 14 per-file counts identical; X arm
**11/11**, all 11 per-suite counts identical (2136).

**After.** Headless **1619 / 0 fail** — `panes` 14 → **15** (`BW15`), every other
file byte-identical. X arm **11/11**, 2147 — `panes` 68 → **79** (`BW15` +
`BW68`-`BW76`), every other suite byte-identical including `i12` at **123** (the
`BX31` change is a LEG, not a check).

**Frozen oracles re-grepped after the patch:**

| oracle | expected | measured |
|---|---|---|
| `BW53` — `$tv see` in `browser_populate` / `browser_reveal` | `{0 1}` | `{0 1}` ✔ |
| `BD06` — bare `browser_alldbs` file-wide | 2 | 2 ✔ |
| `BW59` — bare `browser_devint` / `browser_srccur` | `{2 2}` | `{2 2}` ✔ |
| `BP07`/`BT08`/`BW09`/`BW10` — `browser_width`'s four literals | green | green ✔ |
| `GH0`/`GH2`/`GH4`/`GH8`/`GH9` — 16 keys / 11 accelerators / **15** browser gesture rows | green | green ✔ (item 13 adds no bind) |
| `GS0`-`GS3` — spec↔source proc lockstep | green | green ✔ (nothing renamed, nothing deleted) |
| the `.ph` byte-identical pins (`BD52`, `BX37`, `BX42`, `BX44`-`BX46`, `BH50`, `BH51`, `BH54`) | green | green ✔ — item 13 changes no `browser_say` wording |
| `BP01`/`BR01` — "every proc body was found" | green | green ✔ |

`browser_root_id`'s bare-name count moves 7 → 8 (one new call site). **No check
counts it** — grepped; the only bare-name counters are `browser_alldbs`,
`browser_devint`, `browser_srccur`. **No accessor is named in any comment added
to `src/wave_viewer.tcl`.**

---

## 6. Sabotages — 7/7, under a locked, trapped, pre-state-asserting driver

Driver: `scratchpad/sab13.sh` + `patch13.py`. Lock dir, `EXIT`/`INT`/`TERM` trap
restoring from a **byte-exact backup** (never `git checkout --` — the item is
uncommitted), a pre-state anchor-count assertion before every patch, a
post-write re-read off disk, `diff -q` after every restore, and an output filter
that counts **NORESULT and TIMEOUT as reds**. Source md5 `7eff8bb4…` before and
after every row.

| # | injection | reds | verdict |
|---|---|---|---|
| S1 | re-add `catch {$tv item $id -open 1}` | `BW15`, `BW68` (leg 5), `BX31` (leg 3) — 2 files | exact; `BW69` green, so the *read* is not what broke |
| S2 | open every child of every ancestor (a subtree reveal) | `BW68` (legs 5 **and** 6 — `{none 1 1 1 1 1 visible g:x1.x2}`), `BX31` | exact; **`BW15` stays green**, which is what tells S2 from S1; `BW68` legs 3/4 green exclude "reveal did nothing" |
| S3 | delete `$tv see` | `BW15`, `BW53`, `BW68` (panes); `BX31`, `BX32`, `BX33`, `BX34`, `BX39`, `BX42`×2, `BX43`, `BX51` (i12); `BQ53` (sea) | wide **and entirely attributable**: every red is a visibility/scroll claim. `BW69`/`BW70`/`BW71` green — the selection still moves |
| S4 | **the PLAN's union** | `BW76`, `BP53`, `BP54` — 3 files | exact; this row IS the divergence's evidence |
| S5 | narrow with `lindex $sel 0` (existence check kept) | `BW73` alone | exact; **`BW72` green is the discriminator** |
| S6 | drop the "was non-empty" guard | `BW74`b alone (`{g:x1.y3 1 g: g:}` vs `{… g:x1.y3 …}`) | exact; `BW74`a green |
| S7 | read the root from the widget, not the row model | `BW75` alone | exact; `BW74`a green |

No zero-red rows.

---

## 7. Declared limits

* **The whole item is X-only bar one check.** `browser_reveal` and
  `browser_tree_apply` both need a live `ttk::treeview`, so `--nogui` sees only
  `BW15`. That is a property of the procs, not a gap in the checks, and it is
  why `BW15` exists at all.
* **Measured under Xvfb, which has no window manager.** Nothing in item 13
  needs one (it is all inside one toplevel), and the LEDGER records that the
  Xvfb arm reproduced the `:0` arm exactly.
* **`browser_reveal`'s `-open` deletion is not observable in the `sea` pane by a
  check here.** R3's "the lower pane is the answer" is *why* the target is left
  closed; that the sea then shows the node's own level is `BW35`'s and item 11's
  claim, not restated here.
* **The empty-`sel` reading of §7.3 is a ruling, not a derivation.** §7.3 says
  "a list whose ids have all gone falls back to the root"; an empty list has no
  ids that have gone. Adopted: the fallback fires only when `sel` was NON-empty.
  `browser_state_apply` passes `sel {}` for every legacy and default state, so
  the other reading would move the selection on every plain restore. Pinned by
  `BW74`b, red by S6.

---

## 8. Heads-up for the item-14 scout

* **`browser_sash {token {want {}}}` ALREADY EXISTS** and is already driven by
  `BW33` (`panes:453`). PLAN item 14's "a new `browser_sash`" is wrong.
* **PLAN item 14's band `BP60`-`BP69` is ALREADY PART-SPENT**: measured `BP` max
  is 61, so `BP60`/`BP61` are taken. First free is `BP62`.
* Item 12's carried-in note still stands: item 12's build-time default pin is
  `BW24`, not `BW56`; if item 14 makes the defaults come from a persisted file,
  `BW24` is the check to restate.
* Item 13 adds **no state key**, so `MG9` and `BP42`'s key list are untouched.
