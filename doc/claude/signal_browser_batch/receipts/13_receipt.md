# Item 13 — PIXEL — Location bar + last-20 raw history — receipt

**Verdict: `[E]` — implemented, tested, sabotage-verified; NOT `[x]`, and NO
visual claim is made** (driver note (a): this is a PIXEL item, so the eyeball in
§9 is owed to a human and nothing in the suite substitutes for it).

Implemented in **Tcl only** — settled decision 8 honoured, no `.c` file touched.
**Four sabotages** injected (the PLAN's two, plus one the PLAN did not name that
carries the D6 load, plus one added to prove a check was not vacuous); each fired
its predicted target plus, where it happened, a **declared superset** (ruling 23);
each reverted; clean re-run green.

**A REAL DEFECT WAS FOUND BY A WORLD-ASSERTING CHECK — see §5.** `rawhist_write`'s
bare `open`/`close` resolved to this namespace's own `wviewer::open {token}` /
`wviewer::close {token}`, threw, and was swallowed by its own `catch`: **no store
was ever written** while every structural check stayed green. That is driver note
(e)'s `clipboard clear` defect, verbatim, and it was caught exactly the way the
note said to catch it — by reading the file back off disk, not by observing a
non-throwing return.

---

## 1. THE ANCHORS — every one re-verified from source (driver note (g))

| cited | actual | verdict |
|---|---|---|
| PLAN: `select_raw` at `src/xschem.tcl:14209`, a bare `tk_getOpenFile` | **`:14290`** — `proc select_raw {{parent {.}}}`, body is a bare `tk_getOpenFile` guarded by `[info exists has_x]` | **DRIFT +81**, description exact |
| PLAN: the history is "persisted in the config the same way other viewer prefs are" | **NO SUCH MECHANISM.** `grep -c USER_CONF_DIR src/wave_viewer.tcl` was **0** before this item — not one viewer pref was persisted anywhere | **FALSE PREMISE**, see §2 |
| PLAN Test: "append to `test_wave_sigbrowser.tcl`" | superseded by ruling 30 / `18c45a16`; that file is FROZEN at 324 checks (BS/BT/BM), `_i11.tcl` 700 lines (BH), `_i12.tcl` 927 (BX), `wvbs_common.tcl` 260 (not a case, by design) | **SUPERSEDED** |
| scout: `load_recent_file` `xschem.tcl:2507` | `:2507` | EXACT |
| scout: `update_recent_file` `:2535` | `:2535` | EXACT |
| scout: `update_recent_dir` `:2562` | **`:2559`** | DRIFT −3 |
| scout: `write_recent_file` `:2577` | `:2577` | EXACT |
| scout: `load_net_hilight_conf` `:737` | `:737` | EXACT |
| scout: the 0119 gate — `xinit.c:3295` sets `no_recent_files`, `xschem.tcl:15752` turns it into `update_recent_files 0`, `xinit.c:3809-3812` brackets `source_tcl_file` | all present; **MEASURED live** in a `--pipe -q --script` process: `update_recent_files=0 no_recent_files=1 USER_CONF_DIR=/home/qflow/.xschem` | EXACT |
| scout: `browser_show_path` `:7010`, restore block `:7038-7062` | `:7010` | EXACT |
| scout: `browser_reload` `:6041`, `browser_show` `:7208`, `browser_refresh` `:6093`, `browser_width` `:7156`, `signal_list` `:1734`, `attach_raw` `:2529`, `browser_build` `:5961`, `browser_copy_names` `:6413`, `wviewer::clipboard` `:11498` | all EXACT (pre-edit line numbers) | EXACT |
| scout: `full_audit.sh:118` `mapfile -t files < <(ls "$HERE"/test_*.tcl \| sort)` | `:118`, verbatim | EXACT |
| scout: `test_wave_grid.tcl:248-252` gx lists, `:292` GX4 | `:248-252` and `:292` (pre-edit) | EXACT |
| scout: `scheduler.c:9517` `raw`/`raw_query` | `:9517` | EXACT |

**Measured facts the implementation rests on** (four `--nogui` probe runs, no repo
file touched — every one reproduced independently of the scout):

* `xschem raw read <path> [type]` returns `"1"`/`"0"` and **never throws**.
* A failed read is **ATOMIC**: with A current, reading a garbage file returns `0`
  and leaves `raw rawfile` = A and `raw list` = A's names untouched. Reading a
  nonexistent path likewise.
* `raw read` is **ADDITIVE**: A then B (no clear) leaves both in `extra_raw_arr`.
* `wviewer::attach_raw` **destroys** that atomicity — its first act is
  `catch {xschem raw clear}` (`wave_viewer.tcl:2538`).
* Hand-written ASCII rawfiles read cleanly (`points=3, vars=3, datasets=1
  sim_type=tran`) — **no simulator needed** for the real-raw group.
* Tk 8.6.14; `ttk::combobox` accepts `-justify right` and defaults to
  `-state normal`.

---

## 2. THE FALSE PREMISE, AND WHAT WAS SUBSTITUTED

The PLAN says the history is "persisted in the config **the same way other viewer
prefs are**". There is no such way: before item 13, `src/wave_viewer.tcl` did not
mention `USER_CONF_DIR` once and no `wviewer` preference was written to any file.

**Substituted: the `recent_files` cluster's shape**, which is the nearest real
house precedent and is the same *kind* of thing (a per-user MRU list):

| recent_files | item 13 |
|---|---|
| `$USER_CONF_DIR/recent_files`, a Tcl-sourceable file | `$USER_CONF_DIR/raw_history`, a Tcl-sourceable file |
| `load_recent_file` at startup (`xschem.tcl:2507`, called `:16183`) | `wviewer::rawhist_load`, called from `xschem.tcl` beside it |
| `update_recent_file` — newest first, deduped, capped, then `write_recent_file` | `wviewer::rawhist_push` → `rawhist_add` (pure) → `rawhist_write` |
| gated on `update_recent_files` | gated on **the same flag** |

**This is a premise correction, not a design substitution**, and the cap lives in
`xschem.tcl` as `raw_history_max` (`set_ne`, default 20) so it is a normal,
overridable config var like every other one in that block.

⚠ **The gate is deliberately the SHARED `update_recent_files`, not a private
flag.** That flag is the only one covering *both* halves of issue 0119: C forces
it 0 for a hard-gated automation session (`--nogui`/`--pipe`/`--norecent`) **and**
saves/zeroes/restores it around `source_tcl_file` so a `--script` BODY is gated
even inside an otherwise ungated GUI session (`xinit.c:3809`). A private flag
would be 1 in that second window — i.e. it would reopen 0119.

---

## 3. WHAT SHIPPED

### `src/wave_viewer.tcl` (+263, no deletions)

* `variable rawhist {}` in the namespace block, next to `browsersigs` /
  `browserrows`. **Global, not per-token**: "the last raws I opened" is a property
  of the user, exactly like `tctx::recentfile`, and every viewer window offers the
  same dropdown.
* `rawhist_path` — `$USER_CONF_DIR/raw_history`, derived **at call time** so a test
  can repoint `USER_CONF_DIR` and get a real end-to-end write (this is what makes
  §5's positive control possible at all).
* `rawhist_max` — `::raw_history_max`; non-integer or ≤ 0 falls back to 20.
* `rawhist_add {hist path {max 20}}` — **PURE**: no widget, no `xschem`, no file
  I/O, no namespace variable. Newest first, deduped on `file normalize`, capped.
  Purity is what lets every ordering/dedup/cap claim run in the `--nogui` arm,
  i.e. on the arm the degraded box does not keep killing.
* `rawhist_get` / `rawhist_load` (never throws) / `rawhist_write`.
* `rawhist_push` — **the only gated site**; suppresses the in-memory append *and*
  the disk write, `update_recent_file` parity.
* `rawbar_sync` — writes the path into the combobox, refreshes `-values`, and
  **re-attaches** the balloon (see §9).
* `rawbar_load {token path}` — the loader; body order is load-bearing, see §4.
* `rawbar_commit` (both bindings) and `rawbar_browse` (`select_raw` reused) —
  **one commit path**, `searchbar_fire`'s rule.
* `browser_build` — the `$f.loc` row: `Browse...` packed `-side right` FIRST, then
  the `ttk::combobox -width 18 -justify right`; `pack $f.loc -side top -fill x`
  above `$f.wvsearch`; `<Return>` and `<<ComboboxSelected>>` both → `rawbar_commit`.

### `src/xschem.tcl` (+16, no deletions)

* `set_ne raw_history_max 20`, immediately after the `update_recent_files` block —
  in the user-history cluster, because that is what it is.
* `wviewer::rawhist_load`, beside `load_recent_file` / `load_net_hilight_conf`.

**That is the whole of "config var registration in `src/xschem.tcl`".**
`write_recent_file` / `tctx::recentfile` are **not touched** — the store is
separate by the item's own instruction.

---

## 4. `rawbar_load`'s BODY ORDER, AND WHY EACH STEP IS WHERE IT IS

1. unknown token → 0.
2. empty / not a file → status line names it, **return 0, no tree change, no
   history append**.
3. `switch_ctx` — `attach_raw`'s precedent: a **MOVE**, not a 0173 loan
   (`regenerate` goes through `with_edit`, which deliberately does not restore).
4. `capture_live_view_state` — **issue 0194 and `test_wave_grid`'s GX1 rule**: a
   Location-bar load swaps the DATA under a plot the user built, so the strips,
   the traces and the selection carry forward and the regenerate owes the fold.
5. `xschem raw read $path` — **NO `raw clear` first.** Deliberate divergence from
   `attach_raw`. The engine's read is atomic *only* while nothing cleared the old
   data first; clearing would turn a typo in an editable path entry into "your
   waveforms are gone". Cost declared in §8.
6. `rc != 1` → status line names the failure, **return 0 with the previous raw and
   the tree untouched**.
7. `regenerate`.
8. `browser_refresh $token 1` — **item 9's D6**, the driver's headline concern in
   note (f). `browser_show`'s pack branch was its ONLY caller, so without this the
   user gets the new raw's waveforms under the old raw's signal list.
9. `rawhist_push` (self-gating) — **only on success**: a path that could not be
   read is not a raw the user opened and must not take one of twenty slots.
10. `rawbar_sync`, then `log_action`.

**On the divergence from BX39** (driver note (f) asked for item 12's
improve-or-restore refresh, not a second one with different failure semantics):
item 13 delivers the **same guarantee by a different mechanism, and the mechanism
is the stronger one**. BX39 has to *repair* after a reload that may have emptied
the tree, because its trigger is a path miss on a tree it already has. Item 13's
trigger is a deliberate raw swap, so the failure is caught one step earlier — the
reload is **never started** on a failed read (step 6 returns before step 8), which
is why BR45/BR46 can assert the tree is byte-identical rather than merely restored.
A stale tree kept across a *successful* swap would be a lie, so the success path
refreshes unconditionally; that is the point of sabotage (d) in §6.

---

## 5. ⚠ THE REAL DEFECT: `wviewer::open` / `wviewer::close` SHADOW `open` / `close`

Driver note (e) named the hazard and it fired on the first X-arm run.

`rawhist_write` was written with the obvious `if {[catch {open $f w} fd]} {...}`.
This namespace defines `proc wviewer::open {token}` and `proc wviewer::close
{token}`, and Tcl resolves an unqualified command name in the **current namespace
first**, so that line called `wviewer::open` with two arguments, threw
`wrong # args`, and the surrounding `catch` swallowed it. `rawhist_write` returned
0 forever and **the store was never written**.

Every structural check was green. What caught it was `BR50 ...and the store FILE
now exists` plus `BR50 ...and SOURCING it yields a list headed by A`, i.e. a check
that goes and looks at the world. Fixed by fully qualifying: `::open`, `::close`.
Pinned so it cannot come back silently by `BR03 ...and it qualifies open/close,
which this namespace SHADOWS`.

Swept: `grep -oP '^proc wviewer::\K[a-z_]+' | grep -x` against every Tcl command
the new procs use — `open` and `close` are the **only** two collisions in the
namespace.

---

## 6. SABOTAGES — RUN, NOT REASONED ABOUT (ruling 29)

A pristine post-implementation copy of every touched file was kept in the
scratchpad and each injection was `diff`ed against it before the run; **`git
checkout --` was never used while the item was uncommitted** (it would have
discarded the whole item). Each run below is the **X arm** of the BR file, so all
71 checks were live.

| # | injection | predicted | **actually fired** |
|---|---|---|---|
| **(a)** PLAN | drop the `file normalize` dedup filter from `rawhist_add` | BR12 (2 legs), BR17 (2 legs); superset BR13/BR51 possible | **exactly BR12 ×2 + BR17 ×2, 4 fails.** BR13/BR51 did **not** move (their fixtures use distinct paths) — the declared superset did not materialise, and that is reported rather than the prediction being renamed |
| **(b)** PLAN | delete the `update_recent_files` guard from `rawhist_push` | BR52 legs 2+3, BR02 source legs | **BR02 ×2 + BR52 leg 2 + BR52 leg 3 + `BR54`, 5 fails.** ⚠ **BR54 is a legitimate superset and the most valuable result in this table**: with the gate gone, the earlier ungated-fixture loads wrote **`/home/qflow/.xschem/raw_history` — the USER'S REAL FILE**. That is issue 0119 reproduced live. (The file did not exist before and was **deleted** immediately after the sabotage run; `BR54` confirms the shipped code leaves it absent.) |
| **(c)** SUBSTITUTED, not in the PLAN | delete `browser_refresh $token 1` from `rawbar_load` | BR44 + BR07 | **BR07 ×2 + BR43 + BR44 + BR45 + BR46 + BR52 leg 4, 7 fails** — declared superset: with no refresh at all the inventory is **empty**, so every leg that reads it moves |
| **(d)** ADDED to kill a vacuity worry | make the refresh conditional on an EMPTY inventory (the `browser_show_path` miss-only shape) | BR44's second leg only | **exactly BR44 leg 2 + BR45 + BR46 (the same inventory re-asserted), 3 fails; `BR43` stayed GREEN.** ⚠ **This is the proof that BR44 is not vacuous**: it fails with the tree showing `{time v(in) v(out)}` — A's signals under B's waveforms — which is precisely item 9's D6 defect, and it is the only sabotage of the four that produces a *stale* tree rather than an empty one |

Sabotage (c) alone would have left a doubt the driver's note (f) points straight
at: a "refresh only when the snapshot is empty" implementation passes BR43 and is
still broken. (d) was injected to answer that doubt with a run instead of an
argument, and it fires exactly one behavioural leg.

After each: `diff` against the pristine copy showed **only** the sabotage, the
file was restored from that copy, and the clean re-run was green
(**X arm 71/71, `--nogui` arm 37/37**).

---

## 7. THE TEST FILE, AND THE FOOTPRINT CLAIM (driver notes (b) and (c))

**`tests/headless/test_wave_sigbrowser_i1315.tcl`** — new, 662 lines, prefix
**`BR`**, with **`BD`** (item 14) and **`BP`** (item 15) reserved in its header.
Sets `::wvbs_tag wvsigbrowser_i1315` / `::wvbs_name test_wave_sigbrowser_i1315`
and sources `wvbs_common.tcl` exactly as `_i11` and `_i12` do. **No `gold/` entry**
— `full_audit.sh` classifies these cases by their `RESULT:` banner, no gold
machinery applies. Skip banners are `SKIPPED: <group> (Tk/X arm only)`, never one
of `is_skip`'s three fatal strings.

**Checks: X arm 71, `--nogui` arm 37.** Every check name is distinct, so a
sabotage is attributable to exactly one.

* **BR01-BR09** source, both arms — every proc body FOUND first (the `wvproc_body`
  vacuity trap), `rawhist_add` is pure, the gate is spelled and **ordered before**
  the write, the store is its own, `browser_build` builds and packs `.loc` above
  the search bar, Browse reuses `select_raw` and rolls no second `tk_getOpenFile`,
  GX1's order restated locally, `raw clear` count 0, the push is after the
  bail-out, the D6 refresh is present and inside the success path, the combobox is
  `-width 18 -justify right`, the balloon is in `rawbar_sync` and **not** in
  `browser_build`, both bindings and Browse end in the same loader, and BT09's
  no-bump claim restated for item 13's own bodies.
* **BR10-BR18** pure, both arms — the whole history algebra.
* **BR20-BR27** throwaway toplevel — the child set, the six-slave recipe with
  `.loc` first, the combobox's state/justify/width, Browse packed FIRST and to the
  right, `-values` mirroring, `<Return>` and `<<ComboboxSelected>>` reaching the
  same commit proc through a **proc spy** (so what is observed is the binding, not
  a re-reading of what it is believed to say), and every entry point answering 0
  for an unknown token rather than throwing.
* **BR40-BR54** real viewer + two hand-written 3-point ASCII raws.

⚠ **THE FOOTPRINT CLAIM, STATED AND MEASURED RATHER THAN INHERITED.** Ruling 30's
split point was the fixture cost, not the check count: the deaths landed in `BH5x`
and `BX4x/BX5x`, the only two groups holding a real viewer **and the real design
window** at once. BR40-BR54 holds a real viewer, two ~400-byte raws and **no
design window** — no `xschem load` of a design, no hierarchy walk, no second
toplevel. That is item 8's BSV footprint plus two small files, i.e. strictly less
than BH5x/BX4x. Raw loads are a new axis, which is why the raws are hand-written
3-point files rather than a simulator run. **Items 14 and 15 must re-measure
before appending** — item 14 holds two raw DBs open at once, item 15 adds
destroy/restore cycles; both are new axes on the same dimension, and neither
inherits this claim. Stated in the file's own header too.

### The negative claim and its positive control (driver note (d), ruling 29)

"A `--script` load does not append" is trivially true in a `--pipe` process and is
indistinguishable from four other worlds. So:

* **BR50/BR51 are the POSITIVE CONTROL, and they run first** — gate opened,
  `::USER_CONF_DIR` repointed at the scratch dir: the in-memory list really moves,
  the file really appears, and **sourcing that file in a FRESH SLAVE `interp`**
  yields a list headed by A. The slave interp is not decoration: the store line is
  fully qualified (`set ::wviewer::rawhist {…}`), so sourcing it in this
  interpreter would both clobber the live variable and let the read be satisfied
  by state already in memory.
* **BR52 leg 1 kills "the load never happened"** — `xschem raw rawfile` moved from
  B back to A. Legs 2 and 3 then assert the in-memory list and the file bytes are
  **identical**, and leg 4 that the tree still followed the raw (the gate
  suppresses the HISTORY only).
* **BR41 is a named positive control for the whole real-raw group** — a direct
  `xschem raw read A` returns 1 and `raw list` is A's names, so the hand-written
  fixtures are proven real before any claim is made about them.
* **BR40 and BR54 are named FIXTURE/TEARDOWN checks**, so a dead prologue fails a
  check instead of vanishing into a green skip, and the user's real
  `~/.xschem/raw_history` is asserted untouched.

### The frozen file — three shipped checks WIDENED, none deleted (ruling 17)

`test_wave_sigbrowser.tcl` is frozen against *new items appending checks*, not
against *repairing a claim an earlier item made that is no longer true*. Adding
`.loc` falsifies three equalities, and item 9's own `WIDENED BY ITEM 9, NOT
DELETED` comment at `:291-298` is the precedent:

| line | was | now |
|---|---|---|
| `:303` | `BS22 the frame's children are exactly item 9's set` | `…exactly item 13's set`, `.loc` added |
| `:1079` | `BT21 the sidebar's children are exactly the item-9 set` | `…the item-13 set`, `.loc` added |
| `:1099` | `BT21 …the exact five-slave stack` | `…the exact six-slave stack`, `.loc` first; the `-side` leg gains `.loc → top` |

**The NAMES changed with the sets.** A check name that says "item 9's set" while
pinning item 13's is itself a defect (ruling 17's corollary). `BT08` survives
untouched — its guard is `regexp {pack \$f }` with a trailing space, which
`pack $f.loc` does not match (verified: `BT08` green in every run).

### `test_wave_grid.tcl` — `gx_must` gains `rawbar_load`

`GX4` counts `wviewer::regenerate $token` emitters and asserts the count equals
`llength(gx_must)+llength(gx_pre)+llength(gx_exempt)`. Measured before this item:
17 + 7 + 3 = 27, and `grep -c` = 27. `rawbar_load` makes 28, so `rawbar_load` was
added to `gx_must` (17 → 18) and the stale "these twelve do" / "12 + 7 + 3"
comments were corrected — an overstating comment is the same defect class as an
overstating check name. `GX1` then *requires* the capture-before-regenerate order
in `rawbar_load`, which §4 step 4 already does. `test_wave_grid` was **251/251
green** with the change in.

---

## 8. DECLARED LIMITS — stated, not buried

1. **`attach_raw` (the ASE re-run path) does NOT enter the history.** Raws loaded
   by an ASE re-run will not appear in the Location dropdown — arguably the user's
   most common raw. Chosen for blast radius: `attach_raw` is referenced by
   `test_wave_grid`'s `gx_must`/`GX9` and by two `ase_window.tcl` call sites.
   **Offered as a follow-up issue**, not hidden.
2. **Browse… is `tk_getOpenFile`, i.e. MODAL, and is never exercised headlessly.**
   Only its existence, its packing and the fact that it routes to `select_raw`
   (rather than a second hand-rolled dialog) are assertable. A green suite does
   **not** imply Browse was clicked.
3. **`rawbar_load` does not clear the previous raw, so raws ACCUMULATE in
   `xctx->extra_raw_arr`.** Deliberate — it is what buys the failed-read atomicity
   (§4 step 5) — and it prepares item 14's ground (`xschem raw info` enumerates
   them; `xschem raw switch <path>` goes back).
4. **The PLAN's persistence premise was false** — `recent_files`' shape was
   substituted (§2).
5. **The BX39 divergence** — same guarantee, earlier and stronger mechanism (§4).
6. **The dropdown shows normalised absolute paths.** `rawhist_add` stores
   `file normalize`d forms, so a relative path typed into the bar comes back
   absolute. That is what makes the dedup real; it is a visible behaviour, so it
   is declared.

**NEW ISSUE TO FILE (C, therefore out of scope under decision 8 — filed, not
fixed):** a **malformed ASCII `Values:` block** (point values not terminated by an
empty line) drives `read_raw_ascii_point` (`src/save.c`) past the end of its `tmp`
buffer and xschem dies with `FATAL: signal 11`. A Location bar lets a user type
**any** path straight into `xschem raw read`, which widens exposure to this hole.
The well-formed-but-not-a-raw case is **safe** (measured: returns 0 cleanly), which
is why `BR46` uses a plain text file and never a truncated `Values:` block.

---

## 9. THE EYEBALL — OWED TO A HUMAN, AND NOTHING BELOW IS CLAIMED AS VERIFIED

Verdict `[E]`. **No visual correctness is asserted.** What the code does about
width is stated as mechanism, not as an observed result:

* the combobox is `-width 18`, so the packer's `reqwidth` cannot grow with the
  text (a real raw path is easily 120 characters);
* it is `-justify right`, so the part that stays on screen is the **tail** — the
  file name — rather than a run of leading directories;
* the full path lives in a **balloon re-attached on every load** (`balloon` bakes
  its string in at bind time, so a once-attached tooltip would show the path the
  bar held when the sidebar was built, forever);
* `Browse...` is packed `-side right` **FIRST**, because `browser_width` sets
  `pack propagate $f 0` and fixes the frame width (item 9's D1, a measured 583 px
  floored at 240): an over-wide child is **clipped, not accommodated**, and the
  packer serves slaves in packing order.

**Steps for the human:** open a viewer, Ctrl-L to show the sidebar, then

1. type a **very long** path into the Location bar — the sidebar must not widen,
   and the **tail** must be what shows;
2. hover it — the balloon must carry the **full** path;
3. confirm **`Browse...` is still fully visible** at the measured 583 px and has
   not been clipped off the right edge;
4. drop the combobox open and confirm the entries read sanely at that width;
5. load a second raw from the bar and confirm the tree **visibly changes** to the
   new raw's signals.

---

## 10. VERIFICATION

Authorization epoch checked with `date +%s` before every run (grant expires
1786020948; every run in this receipt was well inside it). Every log grepped for
`X connection to :0 broken` before being interpreted.

| run | result |
|---|---|
| `test_wave_sigbrowser_i1315` `--nogui` | **37/37** (×3, incl. post-sabotage clean re-runs) |
| `test_wave_sigbrowser_i1315` X arm | **71/71** (×3, incl. post-sabotage clean re-runs) |
| `test_wave_grid` X arm | **251/251** |
| `test_wave_sigbrowser` X arm | see §10.1 |
| `test_wave_sigbrowser_i11` X arm | **74/74** |
| `test_wave_sigbrowser_i12` X arm | **92/92** |
| `full_audit.sh` | §10.2 |

### 10.1 `BT45` — NOT ITEM 13's, and settled by an A/B, not a re-run count

`BT45 the sidebar is narrower than the canvas on a real viewer` failed once early
with `not-narrower (w=400 240 160 settled)`. The driver's baseline says BT45 was
widened by the ruling-30 round and "if it flaps again, that is a regression in the
widening". It is not, and here is the measurement rather than the argument.

**Mechanism, measured with an instrumented probe** (real viewer, sidebar toggled
on, widths sampled for 2 s):

```
top width before toggle: 400   reqwidth 1067
reqw wvsearch=755  err=172   ->  755-172 = 583   (item 9's D1 number)
cap = 0.45 * 400 = 180  <  floor 240   ->  sidebar 240, canvas 160
```

The viewer toplevel's **requested** width is 1067 but the WM had not applied it.
`browser_width` runs once, at toggle time, and the frame width is then FIXED
(`pack propagate 0`), so a toggle taken while the WM is behind pins the sidebar at
the 240 floor for the rest of the run. `bs_wait_widths` polls the toplevel width
for *stability*, and 400 is perfectly stable when the WM never acts — the widening
cannot see that failure mode.

**A/B, ruling 22.** Same probe, 6 runs each arm:

| arm | runs ending at `top=400` (the fail shape) |
|---|---|
| item 13 present | 2 / 6 |
| **item 13 reverted (HEAD)** | **1 / 6** |

The fail shape **reproduces with item 13 reverted**. Full-file A/B: 8 runs of
`test_wave_sigbrowser` with the change (3 BT45 fails, all `top=400`), 5 runs with
`src/wave_viewer.tcl`, `src/xschem.tcl` and the frozen test file restored to HEAD
(0 fails, but also 0 runs where the WM lagged). Item 13 was restored from the
scratchpad pristine copies afterwards and re-verified byte-identical.

**Not fixed here, on purpose.** The honest repair is not a helper tweak: the
sidebar width is computed **once** from whatever the toplevel width happened to be
at toggle time and never recomputed, so *any* later comparison of sidebar against
canvas is racy by construction. That is item 9's check and item 9's
`browser_width`; rewriting either is outside item 13's scope. **Owed to the
driver's FLAKY list**, with the mechanism above.

### 10.2 The full audit

⚠ **THE FIRST AUDIT ATTEMPT IS NOT A MEASUREMENT AND IS DISCARDED.**
`/mnt/wslg/stderr.log` records `weston … terminated with signal 6` at **03:08:48**
and again at **03:11:04** — the run started at 03:08:38, i.e. weston aborted **ten
seconds in** (`weston_wm_handle_map_request: Assertion !window->shsurf failed`,
then `failed to write to XWayland fd: Broken pipe`). Ruling 19's instruction
applied exactly: check `/mnt/wslg/stderr.log` before blaming anything. The log is
kept as `audit1_ABORTED_weston_death.log`. The run was killed and restarted once X
answered `xdpyinfo` again. **`wsl --shutdown` was NOT run — that is the user's
call alone.**

**THE MEASURED RUN** (`scratchpad/audit_i13_run1.log`, `grep -c 'X connection to
:0 broken'` = **0**, so it IS a measurement):

```
SUMMARY: 252 pass  23 fail  0 crash/timeout  12 skip  (total 287)
WIREEDIT: PASS
SCRATCH:  0 leaked dir(s)
```

**NON-BASELINE FAILS: NONE.** Sets compared, never counts (the baseline says the
totals are not reproducible and that three more cases now exist).

**23 fails = 15 of the HARD 16 + 8 names, every one of which is on the FLAKY
list**, and each on the check the FLAKY list names where it names one:

| off-the-HARD-list fail | status |
|---|---|
| `test_altf5_ciw` | FLAKY — failed `rebound Alt-F5 raises CIW again` |
| `test_ase_unnamed_net` | FLAKY, and the documented check: **`AN8 empty-space click queues nothing`** |
| `test_graph_context` | FLAKY |
| `test_palette` | FLAKY |
| `test_remap` | FLAKY |
| `test_sod_pick_no_select_0204` | FLAKY |
| `test_wave_markers` | FLAKY, and the documented check: **`MF1 the anchor really SLID`** |
| `test_wire_vertex_grab` | FLAKY |

`test_rotate_stretch_short_0104` (HARD) **passed** this run — the baseline warns
the HARD set flaps in exactly this direction; `test_fluid_editing` and
`test_cadence_drag`, which the baseline also flags as flapping, both failed.

**Every file this item touched or created PASSED in the audit:**
`test_wave_sigbrowser` (the three widened checks — and BT45 green), `test_wave_grid`
(GX1/GX4 with `rawbar_load` classified), `test_wave_sigbrowser_i11`,
`test_wave_sigbrowser_i12`, and **`test_wave_sigbrowser_i1315`**.

**0 crash/timeout and 0 leaked scratch dirs** — the new file's fixtures clean up
after themselves (`wvbs_finish` → `test_scratch_drop`), including the two raws and
the throwaway `conf/` dir.

---

## 11. COMMIT

ONE commit on `fluid-editing`, subject
`feat(wviewer): Location bar + last-20 raw history` (49 chars), **NOT pushed**.
Six files staged as an explicit list; no `git add -A`, no `git commit -a`.

⚠ **THE HASH IS DELIBERATELY NOT WRITTEN HERE.** This receipt is *inside* the
commit, so any hash it names is the hash of a commit that no longer exists —
naming one and then amending produced `f44e82e7` → `f492180d` → … , each superseded
by the amend that recorded it. The implementer reported the final hash to the
driver instead; `git log --oneline --grep 'Location bar + last-20'` resolves it.

**Six files, explicit list, no `git add -A`, NOT pushed:**

| file | change |
|---|---|
| `src/wave_viewer.tcl` | +263, 0 deletions |
| `src/xschem.tcl` | +16, 0 deletions |
| `tests/headless/test_wave_grid.tcl` | +15 −4 (`gx_must` + the stale comments) |
| `tests/headless/test_wave_sigbrowser.tcl` | +19 −8 (the three widened checks) |
| `tests/headless/test_wave_sigbrowser_i1315.tcl` | new, 662 lines |
| `doc/claude/signal_browser_batch/receipts/13_receipt.md` | this receipt |

**No `.c` file** — settled decision 8 honoured. The batch bookkeeping files
(`PLAN.md`, other receipts, `DRIVER_PROMPT.md`, `item_pipeline.js`, the baseline
logs) are **not** in this commit; the driver's ledger commit picks them up.
