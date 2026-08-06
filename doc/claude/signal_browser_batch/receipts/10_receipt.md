# Item 10 — RMB context menu on a browser row — receipt

**Verdict: `[E]` — DONE-PIXEL** (PIXEL item — never `[x]`). Implemented, suites
green, three implementer sabotages plus one unnamed verifier sabotage run and
reverted. The pixels are NOT claimed from the suite; the owed Eyeball note is at
the bottom (§10).

**Commit: `809cb979b047a9cb1bd434826d018157308712c8`** — one commit, NOT pushed.
`git show --stat` re-run by the verifier: the commit touches EXACTLY these three
files, no scope leak, and no C (settled decision 8 honoured).

Files touched: `src/wave_viewer.tcl`, `tests/headless/test_wave_sigbrowser.tcl`,
`doc/claude/signal_browser_batch/receipts/10_receipt.md`.
Test file: `tests/headless/test_wave_sigbrowser.tcl` (appended, decision 9;
prefix `BM`). Checks: **+107 added, 323 total** in the X arm (was 216); **134**
in `--nogui` (was 91, +43). Both counts re-measured independently by the
verifier and matched exactly.

**Non-baseline fails: NONE** (§9 for the implementer's audit, §12.4 for the
verifier's independent one and the `test_wave_axis_zoom` A/B that cleared it).

---

## 0. The carried-forward fix (driver note b) — SWAPPED, not renamed

`test_wave_sigbrowser.tcl:1496` and `:1509` called
`::wviewer::browser_plot_selection $tok` directly while their names said
"gesture". Both are now `pcall $BTVF.tb.plot invoke`.

**Why swap and not narrow the names:** ruling 17 prefers WIDENING. `invoke` is
the real button route, is synchronous with no focus/mapping dependence (zero
added WSLg flake), the selection is already set by the preceding line so the
semantics are byte-identical, and it closes the exact gap item 9's verifier
exposed — no single check spanned *real button route → real trace*.
**Ruling-23 superset declared:** a future sabotage severing the Plot button's
`-command` now fails BT30/31/32 **and** BT44's two, instead of leaving BT44
green.

One more test-side change was FORCED, not opportunistic: `bt_spy_on`'s recorder
took `{token exprs {colors {}}}`, and `plot_signals` grew a 4th parameter. A
3-parameter spy would have taken the real call as "too many arguments",
`browser_plot_ids`' own catch would have swallowed it, and **every** BT gesture
check would have read as "the gesture did nothing". The spy now carries and
records `destover`.

---

## 1. What shipped

| proc | role |
|---|---|
| `plot_signals {token exprs {colors {}} {destover {}}}` | the ONE-SHOT override, resolved once, BEFORE `dest_prepare` |
| `browser_plot_ids {token ids {destover {}}}` | pure pass-through — reads no destination itself |
| `dest_menu_label {token code}` | `dest_label` + the multi-plot Replace suffix, ONE place |
| `ctx_menu_child {m name}` | themed SUBMENU of a context menu (sibling of `ctx_menu_widget`) |
| `browser_menu_ids {token W x y}` | the fail-closed gate |
| `browser_menu_names {token ids}` | ids → raw names, deduped, RAW-FILE order (D7) |
| `browser_menu_build {token ids}` | rebuilt per post; the 8-entry table |
| `browser_menu_post` / `browser_menu_unpost` | 1/0, TOTAL by construction / idempotent |
| `browser_copy_names {token ids}` | newline-joined onto the X clipboard |
| `browser_send_to_add_trace {token ids}` | `add_trace_dialog` + prefilled `.expr` |

Binding: one `<Button-3>` on `$f.tvf.tv` beside item 9's two.
Teardown: `browser_menu_unpost` added to **both** `wviewer::forget` and
`wviewer::tab_drop_transients`.

The menu, by index (BM23 asserts exactly this, by index):

```
0  command   <the name>  |  "N signals"        disabled
1  separator
2  command   Plot (<window destination>)        normal
3  cascade   Plot to  ->  Append / Replace / New Strip / New Tab
4  command   Send to Add Trace...               normal
5  command   Copy name | Copy names (N)         normal
6  separator
7  command   Descend to here                    DISABLED, no -command  <- item 11
```

---

## 2. ⚠ THE PLAN'S CENTRAL PREMISE WAS WRONG, AND THE RECEIPT SAYS SO

The PLAN asked for "the Tcl-only Button3 swallow issue 0178 established for the
legend — the canvas RMB must not also fire". **That swallow does not transfer to
this surface and nothing here needs it.** Measured three ways and re-measured
from source at implementation time:

1. `/usr/share/tcltk/tk8.6/ttk/treeview.tcl` binds **no** `<Button-3>` on the
   Treeview class.
2. `bind all <Button-3>` is empty — no hits anywhere in the Tk library or `src/`.
3. The tree's bindtags are `{<tv> Treeview <top> all}`; the CANVAS is not among
   them (`set_bindings` binds `win_path`, not the toplevel), and the viewer
   toplevel carries only `<FocusIn>`/`<Destroy>`.

The `break` was kept anyway, as **defence in depth** against a future toplevel-
or `all`-level `<Button-3>`, and **BM01's third leg is named to say exactly
that**. There is no check in this file called "the swallow keeps the canvas out".

The negative claim itself is carried by **BM35** (structure: five `bind` reads
all empty, four bindtags, canvas absent, *plus* a positive leg proving the tree
really does carry the item-10 binding) and **BM42** (behaviour, below).

---

## 3. Oracles — what they MEASURE, not merely what they can see (ruling 26/26b)

A Tk `menu` is not a widget tree: `winfo children` sees nothing, `entrycget
-label` **throws** on a separator, `$m index end` returns the literal string
`none` on an empty menu, and a `tk_popup` that never posted looks exactly like
one that posted and was dismissed. So:

* **`bm_entries $m`** → `type|label|state` per index, `pcall` per field, with an
  `ERR:` normalised to the empty string — a separator is the legal, assertable
  row `separator||` instead of an abort.
* **`bm_menu_state $m`** → **five** distinguishable values:
  `absent` / `empty` / `built:N` / `posted:N` / `unreadable`.
  **All four of the first are OBSERVED FOR REAL:** `absent` (BM20, and again
  after teardown), `empty` (BM20, on a menu built by hand — proving `absent` and
  `empty` are two answers, not one symptom), `built:N` and `posted:N` (BM34).
  `dismissed` is the `built:N` that FOLLOWS a `posted:N`, and BM34 asserts the
  whole five-step sequence as one value:
  `{absent built:8 posted:8 built:8 absent}`.

**Exactly ONE real `tk_popup`** is taken, in the throwaway fixture, as the last
thing BM34 does, `catch`-wrapped with an unconditional unpost after it —
`tk_popup` takes a GLOBAL GRAB that would swallow every later leg. Everywhere
else it is spied. That single real post is what makes `posted:8` a measurement
rather than an inference.

Every hard-coded row id and menu index goes through `pcall` (driver note f:
item 9's sabotage (c) aborted 51 checks on one unguarded `$tv parent`).

---

## 4. The negative control has a positive control (driver note d)

* **BM41 — POSITIVE.** A real `<ButtonPress-3>`/`<ButtonRelease-3>` on the REAL
  viewer canvas records **2** `btn3_filter` calls, through a rename-recorder
  that **delegates** to the real proc. Without this, BM42's zero would pass
  identically if `btn3_filter` had never been wired into the fixture at all.
* **BM42 — NEGATIVE, both halves in ONE tuple.** A real `<Button-3>` on a
  browser row gives `{canvas-calls 0, popped-menu-is-ours 1, state built:8}`.
  "The gesture did nothing" is therefore **not** a passing answer.
  **Proven non-vacuous by sabotage (b):** with the binding severed the tuple
  reads `{0 0 absent}` — the canvas-calls ZERO survives while the other two
  halves fail. That is the measurement that says the zero is a rule.

---

## 5. Decisions this item made, stated rather than inherited silently

* **RMB ON A GROUP POSTS AND ACTS ON ITS LEAVES** (`groups`-1 semantics, like
  MMB and the Plot button) — NOT the double-click's refusal. Item 9's D3 exists
  solely to yield the double-click gesture to ttk's expand/collapse; **ttk owns
  no Button-3**, so there is nothing to yield. Pinned by BM27.
* **THE RMB NEVER MUTATES THE SELECTION** (item 9's selection-independence
  precedent). BM28 asserts it on a selected AND an unselected row.
* **AN RMB ON BLANK TREE SPACE POSTS NOTHING AT ALL** — not a menu of dead
  entries. BM21 asserts the return is 0 **and** the oracle still says `absent`,
  which is why `empty` had to be a distinct oracle value.
* **`Copy name` is a DYNAMIC label** (`Copy name` / `Copy names (N)`).
  Deviation from the PLAN's fixed `Copy name`, recorded here: a singular label
  over a 3-row selection is precisely the ruling-17 defect.
* **The multi-plot Replace limit is SURFACED IN THE LABEL, not hidden.** Under
  multi the entry reads `Replace -> appends`, from **one** shared
  `dest_menu_label` used by BOTH the top `Plot (...)` entry and the cascade's
  Replace entry, so the two can never drift (BM32 asserts both surfaces in both
  modes). The entry is still OFFERED — removing it would make the cascade
  disagree with the Add Trace dialog's dropdown, which offers all four.
* **ASCII, not UTF-8, in the two new labels** (`-> appends`, `Send to Add
  Trace...` rather than `→` / `…`): deviation from the PLAN's spelling, taken to
  keep the labels free of any source-encoding question. Recorded, not silent.

## 6. Declared limits

* **D-10a** With a MULTI-ROW target, `Send to Add Trace...` prefills the **FIRST
  name only** — the Expression entry holds ONE expression. A batch goes through
  the dialog's own multi-select listbox (item 6) or through Plot. **Asserted AS
  a limit** (BM45's second leg), not hidden.
* **D-10b** `Plot to → Replace` under multi-plot really Appends (inherited,
  ruling 24 / item 9's D2). Surfaced in the label; the behaviour is unchanged.
* **D-10c** A multi-row menu target acts in **RAW-FILE order** (item 9's D7),
  not the tree's visual order. BM12 pins the exact reversed case
  `v(x1.x2.n) v(x1.y3.n) i(x1.x2.n)` returning the two `x1.x2` leaves
  first-and-last while ttk DRAWS them adjacent.
* **D-10d** Direct `$menu invoke` on `Plot to → New Tab` runs
  `dest_prepare → new_tab → tab_drop_transients`, which now unposts and
  **destroys the very menu whose entry is executing**. Down the REAL route Tk
  unposts before invoking, so this is safe; the direct-invoke path is the one
  place it is not, so BM44's New Tab leg is `pcall`-guarded and asserts only the
  tab count and the untouched policy. (It is also the route that MEASURES the
  teardown: BM46's first half reads `absent` immediately afterwards.)
* **D-10e** Nothing in the browser menu is reachable by key or menubar
  accelerator, deliberately: `test_wave_grid`'s GH0 literals (15 guide rows /
  10 `data-menu`/`data-accel` pairs) are therefore UNCHANGED by item 10.

---

## 7. ⚠ A REAL DEFECT THIS ITEM SHIPPED AND BM33 CAUGHT

`browser_copy_names` first wrote `clipboard clear -displayof $top`. This
namespace **already owns a `wviewer::clipboard`** (the trace clipboard's
0-argument test seam, ~4500 lines further down), and Tcl resolves an unqualified
command in the ENCLOSING NAMESPACE FIRST — so the call hit that proc, threw
"called with too many arguments", was swallowed by the proc's own `catch`, and
the entry **silently did nothing, with no message**. Every structural check was
green; only BM33's real `clipboard get` saw it.

Fixed by fully qualifying `::clipboard`, and now pinned **twice**: BM09 at the
source (2 × `::clipboard`, 0 × bare) and BM33 behaviourally.

---

## 8. Sabotage verification

Pristine post-implementation copies of both files were kept in the scratchpad
and every injection diffed against **them** (`git checkout --` would have
discarded the whole uncommitted item).

### (a) PLAN-NAMED — drop the `break` from the tree's `<Button-3>` body
**Predicted: BM01's third leg ONLY, and no behavioural check at all.**
**Measured, FULL X arm: exactly that.** `1 FAILED (322 passed)` —
`BM01 the tree's Button-3 body ends in 'break' (defence in depth; BM35/BM42 are
what keep the canvas out)`. `--nogui`: same single name.

**This is the honest result, and it is the point:** the PLAN's named sabotage
**cannot** fire behaviourally on this surface, because the bindtag chain
contains no other `<Button-3>` handler and does not contain the canvas. It is
the measurement that PROVES the swallow is inert here; it is **not** evidence
that the menu works. That is what (b) and (c) are for.

### (b) SUBSTITUTE — sever the whole `bind $f.tvf.tv <Button-3>`
**Predicted: BM42's posted half and everything downstream of a real post, with
BM42's canvas-calls half staying GREEN.**
**Measured: `10 FAILED (312 passed)`** — BM01 ×3 (the source greps go too, the
binding is gone), BM35's positive leg, **BM42 `{0 0 absent}` vs `{0 1 built:8}`
— the canvas-calls ZERO survived**, BM43 ×2, BM44 ×2, BM45. BM46 self-skipped
("only one tab") because BM44's New Tab leg never ran — a printed SKIP, not a
fail. A ruling-23 superset, every member attributable; nothing was weakened to
manufacture a single target. **The fixture group (BM20-BM36) stayed green
throughout, correctly: it drives the `browser_menu_post` SEAM, while BM40-BM47
drive the Tk ROUTE.** That split is what makes this sabotage read cleanly.

### (c) SUBSTITUTE — make `Plot to` PERMANENT (cascade `-command` calls `set_plot_dest` first)
**Predicted: BM04 + BM31.**
**Measured: `11 FAILED (312 passed)`** — BM03's code-not-label leg, BM04,
BM24 (the resolved commands), **BM31 ×5 — including all three teeth: the
recorder saw `destover {}` instead of `newstrip`, `plot_dest` came back
`newstrip`/`newtab`, `dest($token)` had been CREATED, and the action log
carried a `set_plot_dest` line** — BM32's single-mode leg, and BM44 ×2 on the
real viewer. A superset of the prediction, all of it the same defect.

Note the shape this catches is *wider* than the injected one: a **save /
set / restore** variant would leave `plot_dest` back at `append` and would beat
a naive "the destination is still append" check — but it would still have
CREATED `dest($token)` and still have written **two** `set_plot_dest` lines, and
BM31's other two teeth are aimed at exactly that.

**Revert:** each injection reverted from the pristine copy, `diff` clean against
it, and the clean re-run is **`RESULT: ALL PASS (323 checks)`** (X) /
**`ALL PASS (134 checks)`** (`--nogui`).

---

## 9. Suites

Normal gating applied in full — the 6-hour test-at-will authorization had
lapsed. Every X-arm run went through `tests/headless/gated_xschem.sh`; the full
audit through `tests/headless/full_audit.sh`, which is gated at its own start.
**The panel PAUSED mid-item and the run was WAITED OUT** (one stale gated
process was killed rather than left stalled, and re-run afterwards);
`GUI_GATE=0` was never set and no gate file was ever hand-written. The source
and pure halves of all three sabotages were taken in the `--nogui` arm, which
needs no display and no gate — which is why the pause cost minutes, not the item.

`/mnt/wslg/stderr.log` was grepped for `X connection to :0 broken` before
interpreting any audit (ruling 19).

### Full audit — `251 PASS / 27 FAIL / 6 SKIP` (284 classified)

Compared as **SETS** against the 16 HARD names, never as counts.

* **All 16 HARD names failed, and nothing else HARD-shaped did.** ✅
* **7 documented FLAKY names**, every one on the PLAN's FLAKY list:
  `test_altf5_ciw`, `test_ase_unnamed_net` (AN8), `test_fluid_bodyshove_guards_0132`,
  `test_graph_context`, `test_pristine_untitled_viewer_0172`,
  `test_wave_markers` (MF1), `test_wire_vertex_grab`.
* **2 VOID results — `X connection to :0 broken` (ruling 19), CORROBORATED.**
  `test_add_pin_lib_symbol_view` and `test_wave_sigsearch` each carry the string
  in their own block (audit log lines 357 and 2488), and
  `/mnt/wslg/stderr.log` carries the matching
  `weston_wm_handle_map_request: Assertion !window->shsurf failed` plus a WSLGd
  weston restart at **14:47:22**, inside this audit's window. A run containing
  that is not a measurement. `test_add_pin_lib_symbol_view` has the same
  precedent from item 8's verifier audit (off-list, passes solo).
* **6 SKIP** — the environmental self-skip family wearing its usual labels
  (`_0114`, `_0106`, `_0111`, `_0108`, `_0098`, `test_ase_savestate_adopt`).
  Six at once is explicitly documented as non-evidence.
* **2 off-list, re-run: `test_cmdmode_descend_0201` and `test_wave_split_strip`**
  (SG10 `and the box zoom still happened (x-span narrowed)` — a real-gesture
  box-zoom leg, in the RMB family but on the CANVAS, which item 10 does not
  touch). See the re-run line below.

**RE-RUN: ALL FOUR OFF-LIST / VOID NAMES CLEARED, so `nonBaselineFails` is EMPTY.**

| name | solo result |
|---|---|
| `test_wave_split_strip` | `ALL PASS (221 checks)` — SG10's box zoom is a real-gesture WSLg flake, and my diff replaces **four** source lines, none of them in `btn3_filter`, `ctx_menu_post` or any canvas binding |
| `test_wave_sigsearch` | `ALL PASS (194 checks)` — the X-death was the whole story |
| `test_cmdmode_descend_0201` | `ALL PASS` |
| `test_add_pin_lib_symbol_view` | `PASS=12 FAIL=0 / OVERALL: ok` (run DIRECTLY — this suite prints `OVERALL:`, not `RESULT:`, so `run_suites.sh` scores it `NORESULT`; a harness format mismatch, not a failure) |

---

## 10. Eyeball owed (`[E]` — NOT claimed from a green suite)

The suite cannot see any of this. What a human must look at:

1. The menu **posts at the pointer**, in root coordinates — not at the window
   corner and not at the tree's origin. (BM22 pins the root-coord CONTRACT at
   the seam; whether the pointer is where the user thinks it is, is pixels.)
2. On a row, **nothing is greyed except `Descend to here`** and the header.
3. An RMB on **blank tree space below the last row shows no menu at all** —
   not a menu of dead entries.
4. `Plot (Append)` and `Plot to → Replace -> appends` **read sanely** at the
   sidebar's measured 583 px, and the cascade opens to the right without
   running off the toplevel.
5. The submenu carries the ASE palette (it is a separate widget from the parent
   menu; `ctx_menu_child` re-applies the theme, but only an eyeball can say it
   matches).

**If the eyeball FAILS, it does not un-do the ledger mark** — it files the defect
and the item returns. Nothing in §1-§9 is a pixel claim.

---

## 11. Sabotage table (ledger form)

`failedExactly` = the measured fail-set was EXACTLY the predicted one. A `no` is
qualified in the note; per ruling 23 a strict SUPERSET whose every extra member
is the same claim observed at another level is sanctioned, and no check was
weakened to manufacture a smaller number.

| # | injection | predicted | measured | failedExactly | reverted |
|---|---|---|---|---|---|
| (a) | **PLAN-NAMED** — drop the `break` from the tree's `<Button-3>` body | BM01's third leg only, and NO behavioural check | `1 FAILED (322 passed)` — exactly `BM01 the tree's Button-3 body ends in 'break' (defence in depth; BM35/BM42 are what keep the canvas out)`; same single name in `--nogui` | **yes** | **yes** |
| (b) | **SUBSTITUTE** — sever the whole `bind $f.tvf.tv <Button-3>` | BM42's posted half + everything downstream of a real post, with BM42's canvas-calls half staying GREEN | `10 FAILED (312 passed)` — BM01 ×3, BM35's positive leg, BM42, BM43 ×2, BM44 ×2, BM45 | **no** (ruling-23 superset) | **yes** |
| (c) | **SUBSTITUTE** — make `Plot to` PERMANENT (cascade `-command` calls `set_plot_dest` first) | BM04 + BM31 | `11 FAILED (312 passed)` — BM03's code-not-label leg, BM04, BM24, BM31 ×5 (all three teeth), BM32's single-mode leg, BM44 ×2 | **no** (ruling-23 superset) | **yes** |
| (v) | **VERIFIER, UNNAMED** — in `plot_signals` flip the one-shot resolution from `$destover eq {}` to `$destover ne {}`, so the override is silently discarded while every source grep still matches | (verifier's own, undeclared to the implementer) | `4 FAILED (318 passed)` — BM44 `Plot to → New Strip`, BM44 `Plot to → New Tab`, BT44 under `newstrip`, BM46's tab switch | — | **yes**, `git checkout --` then `diff -q` against the pristine copy → IDENTICAL, clean re-run green |

Row-by-row notes:

* **(a) is the honest negative result and it is the point.** The PLAN's named
  sabotage CANNOT fire behaviourally on this surface (§2). It was run anyway,
  and BM01 is named to claim only what it pins. No check in this file is called
  "the swallow keeps the canvas out".
* **(b)'s decisive value** is the tuple `{0 0 absent}` against `{0 1 built:8}`:
  the canvas-calls ZERO SURVIVED while the posted half and the state failed —
  the measurement that proves the negative control is not vacuous (§4). BM46
  self-SKIPPED ("only one tab") because BM44's New Tab leg never ran — a printed
  skip, not a fail. The `browser_menu_post` SEAM group (BM20-BM36) stayed green
  throughout, correctly: it is a different level from the Tk ROUTE group.
* **(c)'s teeth are aimed WIDER than the injected shape** — a save/set/RESTORE
  variant would leave `plot_dest` back at `append` and beat a naive "still
  append" check, but would still have CREATED `dest($token)` and written TWO
  `set_plot_dest` lines, which BM31's other two teeth catch.
* **(v) is the one that matters most for hollowness** (§12.2).

Revert method, stated not glossed: injections (a)-(c) were taken while the item
was UNCOMMITTED, so `git checkout --` would have discarded the whole item;
pristine post-implementation copies were kept in the scratchpad and each
injection diffed against **them**. The verifier, working against commit
`809cb979`, used `git checkout --` normally and confirmed the revert
byte-for-byte.

---

## 12. Independent verification (verifier stage)

**Result: `ok: true`, `scopeClean: true`.** Every number below was re-measured by
the verifier, not read off this receipt.

### 12.1 Re-runs that reproduced the claims

* `git show --stat 809cb979` → EXACTLY 3 files; no scope leak, no C.
* `--nogui` arm → `RESULT: ALL PASS (134 checks)`.
* X arm, gated (`run_suites.sh`) → `RESULT: ALL PASS (323 checks)`. 323 − 216
  (item 9's baseline) = **107 added**, confirmed by measurement, and again after
  all sabotage/A-B work.
* All 876 added test lines READ hunting tautologies and self-computed
  assertions: **none found**. Expected values are hard-coded literals; the one
  derived expectation (BM22's root-coord fallback) checks a real derivation rule
  against an independent computation. Recorders carry positive AND negative
  controls in both directions (BM30's disabled-entry zero is followed by a live
  re-record; BM41 proves the canvas handler fires 2× before BM42 asserts zero).
* Anchors re-verified FROM SOURCE rather than from this receipt:
  `ctx_menu_popup` really takes `{W m px py rx ry}` and derives root coords when
  `rx/ry < 0`; `ctx_menu_widget` mints with `-tearoff 0` (so BM23's index table
  is right); `browser_menu_unpost` sits INSIDE `forget`'s `dict exists $windows`
  block, BEFORE `dict unset windows`, so `ctx_menu_drop` can still resolve
  `$top`; `set_plot_dest` really routes through `wviewer::log_action` (so
  BM31's action-log leg is well-aimed); `wviewer::clipboard` really is a
  0-argument proc in the same namespace, so §7's `::clipboard` qualification is
  a genuine fix, not style.
* The PLAN's central premise independently re-measured: `btn3_filter` is at
  `src/wave_viewer.tcl:9879` — NOT the PLAN's `:7680`, and not the scout's
  `:9656` either; a stale citation twice over. It is a CANVAS-level filter that
  swallows the C forward on a legend press, structurally inapplicable to a
  separate `ttk::treeview`. **The verifier's ruling: the downgrade of sabotage
  (a) to "one source check, no behavioural check" is correct and honest, not an
  excuse.**
* Droppings: no `bm_item10.raw` anywhere in the tree,
  `git status --porcelain -- src tests/headless` EMPTY, 0 `xschem` and 0
  gated/`run_suites` processes left alive.

### 12.2 The verifier's own UNNAMED sabotage — and its outcome

Aimed at the item core and **deliberately designed to evade every source-level
check**: in `plot_signals`, `$destover eq {}` → `$destover ne {}`, so the
one-shot override is silently discarded while all three of BM05's greps
(`wviewer::plot_dest $token` ×1, `dest_norm $destover` ×1, `set dest [expr` ×1)
still match.

**Outcome — X arm: `4 FAILED (318 passed)`**: BM44 `Plot to → New Strip` really
created a strip (0 vs 1), BM44 `Plot to → New Tab` added a tab (0 vs 1), BT44
the Plot-button gesture under `newstrip`, BM46 the tab switch inside New Tab.
`--nogui` stayed `ALL PASS (134)` — **correctly**, that arm is source/pure by
declared design.

**Reading: the behavioural coverage is REAL, not hollow.** A defect that no grep
could see was caught by four independent behavioural legs on the real viewer.
Reverted and re-run green.

### 12.3 Gating

Every X-arm run went through `run_suites.sh` / `gated_xschem.sh` /
`full_audit.sh`, on BOTH sides. The implementer's 6-hour authorization had
lapsed, so normal gating applied in full: the panel PAUSED twice mid-item and
was WAITED OUT (~35 min); when the window lapsed again mid-verification the
verifier WAITED it out (~8 min on the sigsearch re-run). **`GUI_GATE=0` was
never set and no gate file was ever hand-written, on either side.** One stale
gated process on each side was confirmed dead / killed rather than left
stalled, and re-run. The source and pure halves of all sabotages were taken in
the `--nogui` arm, which needs no display and no gate — which is why the pauses
cost minutes, not the item.

### 12.4 The verifier's full audit, and `test_wave_axis_zoom`

`full_audit.sh` run start to finish by the verifier: **284 classified,
255 PASS / 26 FAIL / 3 SKIP**, compared as SETS.

* **All 16 HARD names present and nothing else HARD-shaped** (`ase_log_seam_0207`,
  `ase_window`, `cadence_drag`, `ciw`, `fluid_editing`, `gf180mcud_libmgr`,
  `ihp_sg13g2_libmgr`, `lib_manager_gui`, `lib_manager_locate`, `lib_sweep`,
  `phase3_mints`, `reopen_readonly`, `rotate_stretch_short_0104`, `select_at`,
  `selflog_output`, `sky130a_libmgr`).
* **8 documented FLAKY names** (`altf5_ciw`, `ase_persist`, `ase_unnamed_net`,
  `nh_anim_rearm`, `wave_hilight`, `wave_markers`, `wave_snap`,
  `wave_trace_menu`). **3 SKIP** = the environmental self-skip family.
* **4 VOID runs** carrying `X connection to :0 broken`
  (`test_add_pin_lib_symbol_view`, `test_ase_unnamed_net`, `test_wave_snap`,
  `test_wave_trace_menu`), CORROBORATED in `/mnt/wslg/stderr.log` by
  `weston_wm_handle_map_request: Assertion !window->shsurf failed` + a WSLGd
  weston restart at **15:49:32**, inside the audit's window (ruling 19). Those
  runs are not measurements. Re-run solo, gated:
  `test_add_pin_lib_symbol_view` → `PASS=12 FAIL=0 / OVERALL: ok` (confirming
  the harness FORMAT claim — it prints `OVERALL:`, not `RESULT:`, so
  `run_suites.sh` scores it `NORESULT`); `test_wave_sigsearch` → 2/2
  `ALL PASS (194)`; `test_wave_split_strip` → `ALL PASS (221)`;
  `test_wave_tabs` → `ALL PASS (172)`.
* ⚠ **`test_wave_axis_zoom` FAILED in the verifier's audit (CV7 ×2) and is on
  NEITHER the HARD nor the FLAKY list** — by the letter of the brief, the
  verifier's to explain. Explained per **ruling 22 by A/B, not by re-run count**:
  `src/wave_viewer.tcl` reverted to `46f89349` → 4/4 `ALL PASS (370 checks)`;
  restored to item-10 HEAD → 6/6 `ALL PASS (370 checks)`. Every failing shape is
  the `graph_at_pointer` probe=-1,-1 / CV1-CV7-CV8 root-coords family (the
  documented TG9 class), which item 10 **cannot reach**: it adds no canvas
  binding and no pointer code. Cleared as environmental.
  **`nonBaselineFails` therefore stands EMPTY** — the two audits simply drew
  different flakes (the implementer's drew `test_wave_split_strip` SG10).
  **DRIVER ACTION CARRIED FORWARD:** add `test_wave_axis_zoom` (CV1/CV7/CV8) to
  the PLAN's FLAKY list so item 11 does not re-derive this.

### 12.5 Two MINOR open notes (no coverage missing, nothing to redo)

1. **Ruling-17 self-consistency.** The item narrowed BM46's name from "posted
   menu" to "built menu", but left the same overstatement in **BM42** ("a REAL
   RMB … POSTS the menu…") and **BM30** ("invoking `Plot` PLOTS that row") — in
   both, `tk_popup` / `plot_signals` is spied for that whole arm, so what is
   really pinned is "`tk_popup` was called with the menu" and "the recorder saw
   the call". The asserted TUPLES are honest (BM42 asserts `built:8`, not
   `posted:8`) and the real trace is covered by BM43. A naming inconsistency in
   applying its own declared fix, not a defect in what is pinned.
2. **A leg with no positive control.** BM31's action-log tooth asserts
   `lsearch -glob $::bm_log_calls {*set_plot_dest*}` == −1, but nothing in that
   window proves the `bm_log_on` recorder captured anything at all, so on
   correct code the −1 is vacuous; it only discriminates under the exact defect
   shape it targets. The verifier confirmed FROM SOURCE that `set_plot_dest`
   really calls `wviewer::log_action`, so the leg IS correctly aimed, and
   BM31's other two teeth carry the claim independently. **Worth a one-line
   positive control if this file is touched again** (item 11 touches this menu).

---

## 13. Divergences from the PLAN — the complete list, each with its reason

Every one of these is recorded, none silent. §-references point at where the
divergence is argued in full.

| # | divergence | reason |
|---|---|---|
| 1 | **The PLAN's central premise is void**: "follow the Tcl-only Button3 swallow issue 0178 established for the legend (`wave_viewer.tcl:7680`)". | The swallow does not transfer to a `ttk::treeview`, measured three ways (§2). The cited line number is also stale — the mechanism is in `btn3_filter`, a CANVAS-level filter. The `break` is kept as defence in depth against a future toplevel/`all`-level binding, and BM01 is NAMED to claim only that. |
| 2 | **PLAN sabotage (1) does not fire behaviourally.** | Direct consequence of #1. Run anyway and reported honestly: 1 source check, 0 behavioural checks (§11 row (a)). Two substitutes (b)/(c) carry the real load, per the scout's warning. |
| 3 | **Driver note (b) carried-forward fix: SWAPPED both BT44 legs to `$BTVF.tb.plot invoke`** rather than narrowing the check names. | Ruling 17 prefers WIDENING. `invoke` is the real button route, synchronous, with no focus/mapping dependence (zero added WSLg flake); the selection is already set by the preceding line so semantics are byte-identical; and it closes the exact gap item 9's verifier exposed — no single check spanned *real button route → real trace*. Ruling-23 superset declared (§0). |
| 4 | **FORCED test-side change**, not opportunistic: item 9's `bt_spy_on` recorder now carries and records `destover`. | `plot_signals` grew a 4th parameter. A 3-parameter spy would have taken the real call as "too many arguments", `browser_plot_ids`' own catch would have swallowed it, and EVERY BT gesture check would have read as "the gesture did nothing" (§0). |
| 5 | **`Copy name` is a DYNAMIC label** (`Copy name` / `Copy names (N)`), not the PLAN's fixed `Copy name`. | A singular label over a 3-row selection is precisely the ruling-17 defect (§5). |
| 6 | **ASCII, not UTF-8, in the two new labels**: `Replace -> appends` and `Send to Add Trace...` (PLAN wrote `→` and `…`). | Keeps the labels free of any source-encoding question (§5). |
| 7 | **GROUP DECISION, deliberate**: an RMB on a GROUP row DOES post and DOES act on its leaves (`groups`-1, like MMB and the Plot button) — NOT the double-click's refusal. | Item 9's D3 exists solely to yield the DOUBLE-CLICK gesture to ttk's expand/collapse; **ttk owns no `<Button-3>`**, so there is nothing to yield. Pinned by BM27 (§5). |
| 8 | **The cascade is added UNCONDITIONALLY** (`-menu $sub`, possibly empty). | So the entry INDICES are a fixed table BM23 can assert BY INDEX, instead of a function of whether Tk minted the submenu. (Eyeball clause 4 exists because of this.) |
| 9 | **BM34's oracle sequence differs from the PLAN's** `unpost → built:N (dismissed)`. | `ctx_menu_drop` DESTROYS the widget, so unpost yields `absent`. The MEASURED five-step sequence is `absent → built:8 → posted:8 → built:8` (a bare `$m unpost`, i.e. dismissed) `→ absent` (`browser_menu_unpost`). `empty` is observed separately on a hand-built menu (BM20) — which is what proves `absent` and `empty` are two answers, not one symptom (§3). |
| 10 | **BM08's second leg was narrowed** from a `\n\s+return 0` regexp to a plain `return 0` count of 2. | The regexp measured 0: the `return 0`s live on `if {...} { return 0 }` lines, not at line starts. Caught by the first `--nogui` run, BEFORE any claim was made on it. |
| 11 | **Two check NAMES narrowed post-hoc under ruling 17**: BM31's log leg ("NOTHING was written to the action log" → it only pins "no `set_plot_dest` line"); BM46's first leg ("posted menu" → "built menu", since `tk_popup` is spied for that whole arm). | Names must claim only what is pinned. See §12.5 note 1 for the two places the same narrowing was NOT applied. |
| 12 | **One comment edited outside the strict diff**: `tab_drop_transients`' "both context menus" → "all three context menus (item 10 added the browser's)". | One line, inside a proc this item edits, to stop the prose contradicting the code. |
| 13 | **Receipt filename**: the PLAN's Receipt line for item 10 says `receipts/10_receipt.md` and that is what exists. | No divergence — recorded because items 7-9 all had wrong Receipt lines; item 10's is correct and the scout confirmed it. |

**Not applicable — the FAILED clause.** The verdict is `[E]`, not FAILED, so
there is no "what a human must look at first to triage a failure". The human
attention this item DOES owe is the eyeball list in §10, and the one driver
action in §12.4 (add `test_wave_axis_zoom` to the FLAKY list).
