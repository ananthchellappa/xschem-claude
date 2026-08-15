# Item 12 — the two checkboxes stop being inert

Two-pane item 12 (**not** single-pane item 12). Spec
`doc/claude/specs/waveform_signal_browser_two_pane.md` R11 and §6.
Work order: `doc/claude/suggestions/next_session_2pane_item12.md`.

---

## 1. The baselines, re-measured on the UNCHANGED tree first

Both reproduced exactly before a line was written, so every red afterwards is
attributable to this item.

| arm | baseline | measured | after item 12 |
|---|---|---|---|
| headless, 14 files | **1618**, 0 fail | **1618**, 0 fail | **1618**, 0 fail |
| X, 11 suites | **11/11** | **11/11** | **11/11** |

Per-suite headless: sigsearch 146, sea 6, sigbrowser 135, 2pane 108, panes 14,
i11 50, i12 40, i1315 80, i14 47, grid 230, modes 212, viewer 57, markers 437,
tabs 56. Per-suite X: panes 53, sigbrowser 353, sea 79, i11 74, i12 123,
i1315 167, i14 88, 2pane 108, sigsearch 233, grid 355, modes 485.

**After:** X `panes` 53 → **68** (+15), `i14` 88 → **91** (+3). Every other
count byte-identical on both arms. The headless arm does not move at all —
item 12's whole surface is a live widget, so all 18 checks sit in the X-only
blocks.

`timeout 15 xdpyinfo -display :0` returned 0 before each run; no WSLg death and
no known flake (`BR25`, `MG16`) fired this session.

---

## 2. ⚠⚠ THE PLAN SAYS THIS ITEM REDS NOTHING. IT REDS `BW25`.

`test_wave_sigbrowser_panes.tcl:BW25` asserted `-command` was `{}` on both
boxes, and **item 9 said at the time that this item would break it**:

> INERT. Item 12 wires them; wiring them now reds this and steals item 12's
> own attribution.

The PLAN's *"Existing checks it reds: None"* did not carry that forward, and the
work order repeated it. Verified by running, not by reading: `BW25` was one of
the 15 reds on the RED run.

`BW25` is **restated, not deleted**. Its inert claim is false by design now; what
survives the wiring is the half item 9 cared about — both boxes wired to *the
same* command, naming *this window's* token. A copy-paste that leaves one box on
another window's token is invisible to every arithmetic check in the new band
(they all drive `$tok`) and shows up only as a viewer whose checkbox moves a
different viewer's tree.

The work order's other two nominations, `BQ67c` and `BQ50`'s `190`, both **held**
— as predicted, because this item does not change the defaults. `GH0`'s 11
accelerators and `GH4` did not move.

---

## 3. What the PLAN got wrong, with the measurement that says so

Re-measured through the shipped pipeline on `fixtures/tb_bandgap_vars.txt`
before any expected literal existed:

| devint | srccur | signals | tree rows (R2 root) | rows without root |
|---|---|---|---|---|
| 0 | 1 (**shipped**) | **190** | **45** | 44 |
| 1 | 1 | **424** | **129** | 128 |
| 0 | 0 | **140** | **45** | 44 |
| 1 | 0 | **374** | **129** | 128 |

1. **The band.** PLAN gives item 12 `BW40`-`BW49`; item 10 spent BW40-BW53 in
   `panes` and BW53-BW55 in `_i1315`. First free is **`BW56`**, as the work
   order said. Used BW56-BW67. Nothing renumbered.
2. **The node counts 44/128 are wrong; measured 45/129** — the same off-by-one
   item 11 corrected once already. Spec §3.3's 44 counts *instance* nodes; R2's
   design root is the 45th **row**. The four SIGNAL totals do reproduce exactly.
3. **`srccur` does not move the node count.** 45 either way, 129 either way. A
   node-count leg on the source-currents box is **vacuously green**, so `BW61`
   asserts the node count only across `devint` and says so in its own name;
   `srccur` is asserted through the signal total in `BW60`.
4. **The All-DBs check cannot live in `BD60`-`BD70`** — `20_receipt` §"" reserves
   those for item 15. **`BD58` is free**, and that is what this item used.

---

## 4. Three traps that cost real time — all found by running

### 4.1 ⚠⚠ BD06's BARE-NAME GREP CAUGHT *ME*, ON THE EXISTING ACCESSOR

The work order warned that `browser_refresh`'s item-10 comment already named
both of item 12's future accessors, so a `BD06`-style count would start at 1.
Handled: the comment was reworded, and `BW59` counts each new name and gets 2.

**What actually broke was the other direction.** The new accessors' own comment
block said *"the same rule `browser_alldbs` above is built on"* — and `BD06`
counts **`browser_alldbs`** bare, file-wide, expecting 2. It got **3**, on the
first otherwise-green run of `i14`. The mention in prose is indistinguishable
from a call site, which is the whole point of the rule.

**The standing rule, now written into the source:** *no accessor is named in any
comment in this file, including the ones the comment is comparing itself to.*
The blocks say "the two boxes" and "the All-DBs reader directly above".

### 4.2 ⚠⚠ `BW63`'s OWN CONTROL ATE THE FIXTURE

`BW63` claims a toggle does not re-enter the engine. Its control — the leg that
proves the spy can count at all — has to make `signal_list` actually run, and
the only route is `browser_refresh $tok 1`. But `browser_reload`'s entire job is
to **overwrite `browsersigs($token)`** from that read, and with no raw loaded in
this fixture the read correctly answers `{}`.

So the control deleted the 424-name corpus, and `BW63`, `BW65` and `BW66` all
failed on an **empty browser** rather than on anything they claim. The control
now re-seeds what it consumed, before the measurement.

### 4.3 TWO CHECKS WERE GREEN BEFORE THE CODE EXISTED

The RED run is the only reason this is known. With `-command {}` an `invoke`
does nothing, so:

* `BW63` — the spy counted 0 because nothing ran. A zero means nothing without a
  leg that made the spy count *and* a leg that says the toggle still worked.
* `BW65` — "the open set did not change" is exactly what an **unwired** box
  produces. The scope change (190 → 424 → 190) is now carried in the same tuple.

Both were rewritten and both went red. The house rule earned its keep twice in
one item: *a check that passes before you wrote the code is a check to stop and
look at.*

### 4.4 `BW61` WAS READING ITS OWN HELPER'S RESTORE

Filed as a fourth, smaller one because the **sabotage run** is what exposed it,
not the RED run. `BW61`'s second leg was named *"(THE SHIPPED DEFAULT) devint 0 +
srccur 1 is what a user gets"* — and it stayed **green under S2**, the sabotage
that swaps both seeded defaults in `browser_build`, because `bw_four` sets both
arrays explicitly on its way out. It was asserting its own helper's restore.

Restated to what it actually measures (the sweep leaks no state forward). The
build-time pin is `BW24` (item 9's), which reds on S2 as it should.

---

## 5. What landed

### Source (`src/wave_viewer.tcl`)

* **`wviewer::browser_devint`** and **`wviewer::browser_srccur`**, modelled on
  the All-DBs reader: one accessor per box, **one read site each**, optional
  `want` so the read and the write cannot hold two copies of the default. An
  unknown token answers R11's default (0 / 1) rather than `{}` — which would
  reach `browser_class_filter`'s `if {$devint && $srccur}` as a **throw**, not a
  filter. Per **token**, never per namespace.
* **`-command [list wviewer::browser_refresh $token]` on both checkbuttons.**
  `browser_refresh`, never `browser_reload`: a toggle re-scopes the snapshot the
  browser already holds and must not re-enter the engine.
* **`browser_refresh` reads each box ONCE into a local and uses it TWICE** —
  the current DB's `browser_class_filter` and the All-DBs loop's, replacing item
  10's hardcoded `0 1` at both. Both had to move together; see §6 S3.
* Item 9's *"⚠ NO `-command`"* note and item 10's *"THE DEFAULTS ARE HARDCODED
  HERE"* note both rewritten in place rather than deleted, so the record of what
  changed and why survives.

### Tests

* `test_wave_sigbrowser_panes.tcl` — **`BW56`-`BW67`**, +15 checks (53 → 68),
  and `BW25` restated. The 424-name corpus is hand-seeded the same way the sea
  suite does it, and **`BW67` asserts the restore** rather than leaving it to a
  trailing `catch` — a restore nobody checks is a restore that silently stops
  happening, and every later BW check would then inherit a 424-name browser.
* `test_wave_sigbrowser_i14.tcl` — **`BD58`/`BD58b`/`BD58c`**, +3 (88 → 91). The
  foreign inventory is hand-seeded rather than added to the fixture raws: the
  real `bd_a`/`bd_b` are all `net`-classed, and giving them a device signal
  would move `bd_rows`' length and red BD50c/BD51c for no gain.

---

## 6. Sabotages — RUN

Driver: lock file, `EXIT`/`INT`/`TERM` trap, a **pre-state count asserted before
every patch**, a post-write re-read proving the mutation is really on disk, and
a filter that counts `NORESULT`/`TIMEOUT` as reds. Source `diff -q` clean after
every row. **No row scored zero and no run showed a check-count shortfall.**

| # | sabotage | reds | where |
|---|---|---|---|
| S1 | share ONE `-variable` between the two boxes | **2** | panes: BW06, BW62 |
| S2 | swap R11's two seeded defaults (devint 1 / srccur 0) | **2** | panes: BW24, BW56 |
| S3 | wire the CURRENT-DB site, leave All-DBs at `0 1` | **1** | i14: **BD58** |
| S4 | read a box inside `browser_reload` as well | **1** | panes: BW59 |
| S5 | `-command` calls `browser_reload` | **5** | panes: BW62, BW63, BW64, BW65, BW66 |
| S6 | mirror of S3: leave the CURRENT-DB site at `0 1` | **6** | panes: BW60, BW61, BW62, BW63, BW65, BW66 |

**S3 is the row that justifies `BD58` existing.** It reds **exactly one check, in
the other file**. All 15 checks of the new `BW56` band stay green through it,
because they drive the current DB only — so without `BD58` a checkbox that
governs the tree the user is looking at and silently *not* the foreign inventory
beside it would have shipped green. That is item 20's `browser_and` lesson, one
item over, and S6 is its mirror: wire All-DBs only and `BD58` stays green while
six panes checks fall.

**S1 did NOT collapse `BW60`'s four totals, contrary to the PLAN's prediction.**
The PLAN's sabotage note assumes the totals are driven through the widget; they
are driven by writing the two `-variable` arrays directly, which a shared
`-variable` does not affect. The check that catches it is `BW62`, the **real
`invoke` gesture**. Recorded because the PLAN's expected-reds column is wrong
here in a way that would read as a coverage hole.

---

## 7. Owed / for the next item

* **Item 12 unblocks item 14 (persistence) and item 18 (R12's auto-tick).**
  Persistence was explicitly NOT touched — `browser_state` is untouched, so the
  two boxes reset to 0/1 on every window build. Item 14 owns that.
* **The `.ph` status line is still class-filter blind.** It is
  `"[llength $names] of $total signals"` — bar-matched only — so ticking a box
  moves the tree, the sea and `browserseaent` but not that line. Spec §6 lists
  the status line in its "one consistent set", while §7.2 puts the per-node
  caption on `$f.pw.sea.st` instead. **Not changed here**: a dozen checks across
  four files pin `.ph` byte-identically (BD52, BX37, BX42, BX44-BX46, BH50,
  BH51, BH54) and the work order does not scope it. Whoever takes §7.2's
  three-state caption should settle it then.
* `BW61`'s build-time twin is `BW24`. If item 14 makes the defaults come from a
  persisted file, `BW24` is the check that has to be restated, not `BW56`.
