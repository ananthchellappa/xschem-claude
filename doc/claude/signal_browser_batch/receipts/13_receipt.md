# Item 13 — PIXEL — Location bar + last-20 raw history — receipt

**Verdict: `[E]` — implemented, tested, sabotage-verified; NOT `[x]`, and NO
visual claim is made** (driver note (a): this is a PIXEL item, so the eyeball in
§9 is owed to a human and nothing in the suite substitutes for it).

Implemented in **Tcl only** — settled decision 8 honoured, no `.c` file touched.
**Seven sabotages** injected in total (the PLAN's two, one the PLAN did not name
that carries the D6 load, one added to prove a check was not vacuous, and **three
more in the fixup round** — §12); each fired its predicted target plus, where it
happened, a **declared superset** (ruling 23); each reverted; clean re-run green.

⚠ **THIS RECEIPT HAS BEEN REPAIRED ONCE. READ §12 WITH §6-§8.** An adversarial
verifier found that the first shipping's suite stayed **fully green with the
Location bar's own `rawbar_sync` call deleted** and with the startup
`rawhist_load` deleted — i.e. the two lines the headline deliverable *is* were
uncovered — plus a false "filed as its own issue" claim, an undeclared
per-window limit and one tautological check leg. §12 is what was done about each.

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

**Checks: X arm 85, `--nogui` arm 40** (71/37 as first shipped; **+14/+3 added by
the fixup round — §12**, which is also where `BR19` and `BR28/BR29` below come
from). Every check name is distinct, so a sabotage is attributable to exactly
one.

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
* **BR19** (fixup round, §12) both arms — the STARTUP RESTORE, proven in a
  `--nogui` CHILD PROCESS started with `HOME` inside the scratch dir, plus the
  source leg naming the one top-level call site in `xschem.tcl`.
* **BR20-BR29** throwaway toplevels — the child set, the six-slave recipe with
  `.loc` first, the combobox's state/justify/width, Browse packed FIRST and to the
  right, `-values` mirroring, `<Return>` and `<<ComboboxSelected>>` reaching the
  same commit proc through a **proc spy** (so what is observed is the binding, not
  a re-reading of what it is believed to say), every entry point answering 0
  for an unknown token rather than throwing, and (fixup round) **BR28/BR29 — a
  SECOND window**, proving the dropdown fans out and the Location text does not.
* **BR40-BR54** real viewer + two hand-written 3-point ASCII raws. The fixup
  round added the legs that read the **Location widget itself** after a real
  load — entry text, `<Enter>` balloon and `-values` — see §12.

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
7. **A load in one viewer refreshes every viewer's DROPDOWN but only the loading
   viewer's Location TEXT and balloon.** `rawhist` is one global list, so the
   `-values` fan out (`rawbar_sync`, and `BR28` is the only thing that can see
   it); the entry text and the tooltip name the raw *that window* is showing, and
   a load elsewhere did not change that. ⚠ **This was an UNDECLARED limit in the
   first shipping** — the fanout did not exist at all, so a second viewer built
   earlier kept its build-time dropdown for the whole session. Fixed and covered
   in the fixup round (§12, defect **P4**).

**ISSUE 0213, FILED** —
`doc/claude/issues/0213-read-raw-ascii-point-overruns-its-buffer.md`. C, therefore
out of scope under decision 8: a **malformed ASCII `Values:` block** (point values
not terminated by an empty line) drives `read_raw_ascii_point` (`src/save.c:406`)
past the end of the `tmp` buffer `read_raw_data_block` sized at one slot per
variable, and xschem dies — `FATAL: signal 11`, or `double free or corruption` in
the next `free_rawfile`, depending on what the overflow lands on. A Location bar
lets a user type **any** path straight into `xschem raw read`, which widens
exposure to this hole. The well-formed-but-not-a-raw case is **safe** (measured:
returns 0 cleanly), which is why `BR46` uses a plain text file and never a
truncated `Values:` block. ⚠ **The first shipping SAID this was filed when it was
not** (in this section, and in a comment in the test file); the issue exists now,
with the standalone repro and the mechanism — see §12, defect **P3**.

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

⚠ **The counts in this table are the FIRST SHIPPING's.** The fixup round moved
them to **85 / 40** and re-ran everything — §12.

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

⚠ **TWO commits now**: the original below, plus the FIXUP commit
`fix(wviewer): cover the Location bar's own sync + startup restore`
(4 files: `src/wave_viewer.tcl`, `tests/headless/test_wave_sigbrowser_i1315.tcl`,
the new `doc/claude/issues/0213-…md`, and this receipt), also **NOT pushed** —
see §12.

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

---

## 12. THE FIXUP ROUND — what the adversarial verifier found, and the repair

One repair attempt on six reported problems. **Four were real defects in this
item, one was a real documentation falsehood, one is not item 13's.** Nothing was
argued away; every fix is pinned by a sabotage that was RUN.

### P1 (decisive) — the item's headline call was UNCOVERED

The verifier deleted `wviewer::rawbar_sync $token $path` from `rawbar_load` — the
**only** call site in the tree — and **all 71 checks stayed green**. What that
silently killed: the Location entry never follows a load, the full-path balloon
(the PLAN's explicit Eyeball requirement) is never attached at all, and the
dropdown's `-values` never refresh within a session. Every existing leg was blind
to it: `BR24` calls `rawbar_sync` **directly** on a hand-made token, and no
behavioural leg after the real `BR42/BR44/BR50` loads ever read the widget.

Driver note (e)'s rule — *assert on the WORLD, never on "the command returned"* —
had been applied to the disk write and **not** to the widget the feature IS.

**Repair — six new legs, all reading the real combobox in the real viewer:**

| leg | reads |
|---|---|
| `BR42 (CONTROL) before any load the bar is blank and has no balloon` | `[$cb get]` = `{}`, `bind $cb <Enter>` = `{}` — without this, "the bar shows A" cannot be told from "it always showed A", and "there is a balloon" cannot be told from one baked in at build time |
| `BR42 …the LOCATION BAR followed the load: it now reads A` | `[$cb get]` |
| `BR42 …and the full-path balloon now names A` | the real `<Enter>` script (`balloon` substitutes its string in at bind time, so the path being *in the binding* is the path being *in the tooltip*) |
| `BR44 …and so did the bar and its balloon: B now, A gone` | B present **and A absent** — which is what makes it a RE-ATTACHMENT claim rather than "A was there once" |
| `BR46 …and the Location bar still names the raw that IS loaded` | a REFUSED load must not rewrite the bar |
| `BR50/BR51 …and the DROPDOWN now offers it / offers BOTH, newest first` | `[$cb cget -values]` after the two ungated loads |

**Sabotage V3 re-run (the verifier's own injection, reproduced):** delete
`wviewer::rawbar_sync $token $path` from `rawbar_load` →
**`6 FAILED (79 passed)`, exactly those six legs and nothing else.** Reverted from
the pristine copy, clean re-run **85/85**.

### P2 — persistence was only half-proven: nothing read the store back

Deleting `wviewer::rawhist_load` from `src/xschem.tcl`'s startup block also left
the suite fully green: `BR50/BR51` prove the WRITE, `BR03` only greps the reader's
body. With that line gone the history is written every session and never
restored, and the dropdown is empty at every startup.

**Why no check in this file could see it:** the read happens **once, at process
startup, before the test script is sourced**. By the time any check runs it has
already happened or already not.

**Repair — `BR19`, a `--nogui` CHILD PROCESS.** `xinit.c:3035` derives
`USER_CONF_DIR` from `$HOME`, so the test seeds
`<scratch>/fakehome/.xschem/raw_history`, sets `::env(HOME)` to that scratch home
for exactly one `exec`, runs
`[info nameofexecutable] --nogui --pipe -q --nolog --script <probe>`
(the `test_undo_link_symbols.tcl` child-process idiom), restores `HOME`, and reads
the child's stdout:

* `BR19 xschem.tcl calls rawhist_load ONCE, at top level (startup)` — a
  `^wviewer::rawhist_load$` line count, so a deletion **localises in one line**;
* `BR19 (CONTROL) the child ran and its USER_CONF_DIR is the scratch home` —
  without it, an empty history could not be told from "the `HOME` override
  silently failed"; it also proves the child never read the user's real config;
* `BR19 a FRESH xschem RESTORES the persisted history at startup` — the child
  prints back the exact seeded list.

**Sabotage V4:** delete the startup call → **`2 FAILED (83 passed)`** — the source
leg and the restore leg, with the CONTROL leg **green** (so the failure is the
restore, not a broken fixture). Reverted, clean re-run **85/85**.

### P3 — "filed as its own issue" WAS FALSE. It is filed now: 0213

The C SIGSEGV claim was true; the claim that it had been *filed* was not.
Reproduced independently before writing anything:

```
Warning: ascii block is not of correct size
…
free_rawfile(): clearing data
double free or corruption (out)      ← same defect, other landing site than SIGSEGV
```

`doc/claude/issues/0213-read-raw-ascii-point-overruns-its-buffer.md` now carries
the standalone repro, the mechanism (`read_raw_ascii_point` takes `tmp` but **not
its capacity**; its loop ends only on a blank line or EOF, so an unterminated
point walks into the next one, writing past a `rawvars`-element buffer — the
`!= rawvars` warning at `save.c:504/531` is a post-mortem, not a guard) and the
shape of a fix. The test-file comment and §8 now name **0213** instead of claiming
an unfiled filing. **No `.c` file was touched** (decision 8).

### P4 — the per-window limit was real, and is now FIXED rather than declared

`rawhist` is one **global** list; `-values` was set per window at `browser_build`
time and refreshed only for the **loading** window. A second viewer whose sidebar
was built earlier kept its build-time dropdown for the rest of the session, which
contradicted the receipt's own "every viewer window offers the same dropdown".

`rawbar_sync` now fans the `-values` out to every other open viewer whose
Location row exists, and **only** the `-values`: the entry text and the balloon
stay per-window, because they name the raw *that* window is showing and a load
elsewhere did not change it. Both halves are asserted, and they need a second
window to be visible at all:

* `BR28 (FIXTURE) a second window's sidebar builds with an EMPTY dropdown` — the
  positive control, so `BR28` cannot pass on a dropdown that was already right;
* `BR28 a sync in window 1 fans the shared history out to window 2's dropdown`;
* `BR29 …but window 2 keeps its OWN (blank) Location text and balloon`.

**Sabotage V5:** delete the fanout loop → **`1 FAILED (84 passed)`**, exactly the
fanout leg. Reverted, clean re-run **85/85**.

### P5 — the `BR54` tautology, replaced by two readings of the world

`BR54`'s first leg asserted `$::USER_CONF_DIR eq $br_conf0` two lines after the
teardown assigned exactly that — it could not fail. Removed. `BR54` now:

* captures the user's real store's **existence AND bytes** up front and compares
  both at teardown (existence alone would pass over a rewrite on a machine where
  the file already exists);
* adds `BR54 …while this run's writes DID land, in the scratch store`, so
  "nothing was ever written anywhere" cannot pass as "nothing was written to the
  user's file".

**That the new `BR54` has force is not an argument — it FIRED.** Re-running PLAN
sabotage **(b)** (delete the 0119 gate) produced **`5 FAILED`**: `BR02` ×2,
`BR52` legs 2-3 and **`BR54`**, because the ungated `BR42/BR44` loads — which run
*before* `::USER_CONF_DIR` is repointed — wrote **`/home/qflow/.xschem/raw_history`,
the user's real file**. Issue 0119 reproduced live. ⚠ **Anyone re-running
sabotage (b) writes that file**: it is created only by the sabotage, it did not
exist before (proof: the file the sabotage wrote contains *only* the two scratch
paths — a non-empty startup history would have been carried into it), a copy was
kept in the scratchpad, and it was **deleted immediately after**; the shipped code
leaves it absent, which `BR54` re-asserts.

### P6 — the two off-baseline audit names are NOT item 13's

`test_cmdmode_descend_0201` and `test_lib_manager_checkin` appear on neither the
HARD 16 nor the FLAKY list; the verifier's own re-runs cleared both 3/3, and one
of the two died on `XIO: fatal IO error 22 … on X server ":0"`. **For the
driver's FLAKY list**, with the same status as §10.1's `BT45`.

### The re-run PLAN sabotages, after the fixup

| # | injection | fired |
|---|---|---|
| **(a)** | drop the `file normalize` dedup | **4**: `BR12` ×2, `BR17` ×2 — unchanged by the fixup |
| **(b)** | delete the `update_recent_files` gate | **5**: `BR02` ×2, `BR52` ×2, **`BR54`** (see P5) |
| **V3** | delete the `rawbar_sync` call | **6**: the P1 legs |
| **V4** | delete the startup `rawhist_load` | **2**: the P2 legs |
| **V5** | delete the fanout loop | **1**: the P4 leg |

Every injection was `diff`ed against the scratchpad pristine copies before its
run and restored from them afterwards (`git checkout --` was not used: the fixup
was uncommitted, and it would have discarded it).

### Fixup verification

| run | result |
|---|---|
| `test_wave_sigbrowser_i1315` X arm | **85/85** (×4 clean, plus every post-sabotage revert) |
| `test_wave_sigbrowser_i1315` `--nogui` arm | **40/40** |
| `test_wave_sigbrowser` (FROZEN, untouched by the fixup) | 6 runs incl. the audit's: **5 PASS**, 1 × `BT45 not-narrower (w=400 240 160 settled)` — §10.1's exact shape and numbers, verbatim including the widths |
| `test_wave_sigbrowser` with `src/wave_viewer.tcl` restored to HEAD | **6/6 PASS** (the ruling-22 A/B: 1-in-6 with, 0-in-6 without — rates indistinguishable at these counts, and a combobox `-values` fanout cannot reach a toplevel the WM never grew) |
| `test_wave_grid` | **251/251** ×2, plus the audit's |
| `full_audit.sh` | §12.1 |

### 12.1 The fixup's full audit

`scratchpad/audit1.log`, **`grep -c 'X connection to :0 broken'` = 0**, so it is a
measurement. `date +%s` = 1786014975 at launch, inside the grant (1786020948).

```
SUMMARY: 253 pass  23 fail  0 crash/timeout  11 skip  (total 287)
WIREEDIT: PASS
SCRATCH:  0 leaked dir(s)
```

**NON-BASELINE FAILS: NONE** — sets compared, not counts.

* **15 of the HARD 16.** `test_rotate_stretch_short_0104` **SKIPPED** this run
  (the environmental self-skip family the baseline warns flaps in name and
  count); it did not fail.
* **8 more, every one on the FLAKY list**: `test_ase_unnamed_net` (on its
  documented `AN8 empty-space click queues nothing`), `test_graph_context`,
  `test_launch_context`, `test_palette`, `test_pristine_untitled_viewer_0172`,
  `test_remap`, `test_sod_pick_no_select_0204`, `test_wave_hilight` (on its
  documented `WD2`/`WD2c`).
* **The two names the verifier could not place both PASSED here** —
  `test_cmdmode_descend_0201` and `test_lib_manager_checkin` — as did
  `test_hover_highlight`, which died on an X error in the verifier's run. Their
  status is unchanged: **for the driver's FLAKY list, not item 13's.**
* **Every file this item touches PASSED**: `test_wave_sigbrowser`,
  `test_wave_grid`, `test_wave_sigbrowser_i11`, `_i12` and
  **`test_wave_sigbrowser_i1315`** — and `0 leaked scratch dir(s)`, so `BR19`'s
  throwaway `fakehome/.xschem` (which the child process *creates*, template
  `xschemrc` and all) is cleaned up with the rest.

**Files the fixup touched:** `src/wave_viewer.tcl` (the fanout, +18),
`tests/headless/test_wave_sigbrowser_i1315.tcl` (+14 X-arm / +3 `--nogui` checks),
`doc/claude/issues/0213-…md` (new), this receipt. **No `.c` file, and the frozen
`test_wave_sigbrowser.tcl` and `test_wave_grid.tcl` were NOT re-touched.**

---

## 13. LEDGER STAGE — the record, written AFTER both commits landed

Everything below is the pipeline's ledger stage, not the implementer's. It is
written after `8655fd3b` and `76bd7c04` are both in history and immutable, which
is why it can name hashes where §11 deliberately could not: §11 was written
*inside* the commit it would have had to name.

### 13.1 Verdict and commits

**Verdict: `[E]` — DONE-PIXEL.** Not `[x]`. The deliverable is visible UI; the
suite pins mechanism, ordering and world-state, and **no check in it can say the
Location bar looks right**. §9 is owed to a human and is queued in `PLAN.md`'s
Eyeball queue.

| commit | subject | pushed? |
|---|---|---|
| `8655fd3b` | `feat(wviewer): Location bar + last-20 raw history` | **no** |
| `76bd7c04` | `fix(wviewer): cover the Location bar's own sync + startup restore` | **no** |

Both on `fluid-editing`, files staged as explicit lists (no `git add -A`, no
`git commit -a`). Verifier confirmed `git status --short src/ tests/headless/`
clean after its own seven sabotage injections and reverts.

### 13.2 Files touched — the union of both commits

| file | `8655fd3b` | `76bd7c04` |
|---|---|---|
| `src/wave_viewer.tcl` | +263 −0 | +27 −8 (the `-values` fanout) |
| `src/xschem.tcl` | +16 −0 | — |
| `tests/headless/test_wave_sigbrowser_i1315.tcl` | new, 662 lines | +200 −15 |
| `tests/headless/test_wave_sigbrowser.tcl` | +19 −8 (3 checks WIDENED, ruling 17) | — |
| `tests/headless/test_wave_grid.tcl` | +15 −4 (`gx_must` gains `rawbar_load`) | — |
| `doc/claude/issues/0213-read-raw-ascii-point-overruns-its-buffer.md` | — | new, +114 |
| `doc/claude/signal_browser_batch/receipts/13_receipt.md` | new, +511 | +256 −18 |

**No `.c` file in either commit** — settled decision 8, confirmed independently by
the verifier with `git show --stat` on both hashes.

### 13.3 Test file and check counts

**`tests/headless/test_wave_sigbrowser_i1315.tcl`** — NEW file, prefix `BR`, with
`BD` (item 14) and `BP` (item 15) reserved in its header. No `gold/` entry.

| arm | added by this item | total in the file |
|---|---|---|
| X (Tk) | **85** (71 first shipping + 14 fixup) | **85** — the file is new, so added = total |
| `--nogui` | **40** (37 + 3) | **40** |

Both arms green at `76bd7c04`, re-measured by the verifier from a clean tree
before it touched anything. Two OTHER files gained checks under ruling 17, and
they are widenings of existing claims, not item-13 coverage:
`test_wave_sigbrowser.tcl` (3 checks — item 9's sidebar child-SET claim was
falsified by the new `.loc` row) and `test_wave_grid.tcl` (`gx_must` gains
`rawbar_load` so `GX4`'s count claim stays true).

### 13.4 SABOTAGE TABLE — ledger form, `failedExactly` / `reverted` per row

Seven injections in total: the PLAN's two, two the implementer added in the first
round, and three in the fixup round (two of them the verifier's own, reproduced
rather than accepted on report). **Every row was RUN** (ruling 29).

| # | round | injection | predicted | fired | `failedExactly` | `reverted` |
|---|---|---|---|---|---|---|
| **(a)** PLAN | first + re-run | drop the `file normalize` dedup from `rawhist_add` | `BR12` ×2, `BR17` ×2 | **4** — exactly those; `BR13`/`BR51` did NOT move, so the declared superset did not materialise and that is reported rather than the prediction renamed | **true** | true |
| **(b)** PLAN | first + re-run | delete the `update_recent_files` 0119 gate from `rawhist_push` | `BR02` ×2 (source), `BR52` legs 2-3 | **5** — the four predicted **plus `BR54`** | **false** (DECLARED superset) | true |
| **(c)** implementer, substituted | first | delete `browser_refresh $token 1` from `rawbar_load` | `BR07` + `BR44` | **7** — `BR07` ×2, `BR43`, `BR44`, `BR45`, `BR46`, `BR52` leg 4 | **false** (DECLARED superset: no refresh at all ⇒ an EMPTY inventory, so every leg reading it moves) | true |
| **(d)** implementer, added | first | make the refresh conditional on an EMPTY inventory (the `browser_show_path` miss-only shape) | `BR44` leg 2 only | **3** — `BR44` leg 2, `BR45`, `BR46` (the same inventory re-asserted); **`BR43` stayed GREEN** | **false** (declared superset, same assertion thrice) | true |
| **V3** verifier's, reproduced | fixup | delete the only `wviewer::rawbar_sync $token $path` call from `rawbar_load` | the 6 new widget legs | **6** — `BR42` bar-follows-load, `BR42` balloon-names-A, `BR44` bar+balloon-followed-to-B, `BR46` refusal-leaves-bar, `BR50` dropdown-offers-A, `BR51` dropdown-offers-both (79 passed) | **true** | true |
| **V4** verifier's, reproduced | fixup | delete `wviewer::rawhist_load` from `src/xschem.tcl`'s startup block | `BR19` source leg + `BR19` behavioural leg | **2** (83 passed); `BR19`'s CONTROL leg stayed GREEN, so it reads as "the restore did not happen", not "the child/`HOME` fixture broke" | **true** | true |
| **V5** implementer's, new | fixup | delete the `-values` fanout loop from `rawbar_sync` | `BR28` fanout leg | **1** (84 passed); `BR28`'s FIXTURE leg (window 2 builds with an EMPTY dropdown) is the positive control that stops it passing on an already-correct value | **true** | true |

**Revert method** (stated, not glossed): during the first round the item was
UNCOMMITTED, so `git checkout --` would have discarded it — a pristine
post-implementation copy was kept in the scratchpad, each injection `diff`ed
against it before the run and restored from it after. The verifier, working
against a commit, used targeted `git checkout -- <file>` after confirming with
`git diff` that the file held nothing but the injection.

⚠ **Row (b) has a footprint outside the repo.** With the gate gone the ungated
`BR42/BR44` fixture loads run *before* `::USER_CONF_DIR` is repointed and write
`/home/qflow/.xschem/raw_history` — **the user's real file**, i.e. issue 0119
reproduced live. It did not exist beforehand (proof: the file the sabotage wrote
contained only the two scratch paths; a non-empty startup history would have been
carried into it), a copy was kept in the scratchpad, and it was deleted
immediately. **Verified absent again by the verifier after all seven of its own
runs.** Anyone re-running (b) recreates it.

### 13.5 The verifier's own UNNAMED sabotages, and their outcomes

Beyond reproducing V3/V4/V5, the verifier injected **four sabotages the repair did
not claim** — the point being that a repair aimed at a named hole can close that
hole and leave a differently-shaped one beside it.

| # | injection | outcome | what it settles |
|---|---|---|---|
| **V6** | keep the startup call site but **gut the read inside the proc** — `if {[catch {source $f}]}` → `if {[catch {list $f}]}` | **2 FAILED**, and critically the `BR19` SOURCE-count leg stayed **GREEN** while the `BR19` behavioural leg fired | The discriminator for P2. A grep-proxy dressed as behaviour would have failed both legs together; this proves `BR19`'s new leg is a real reading of a fresh process |
| **V7** | delete `catch {wviewer::browser_refresh $token 1}` from `rawbar_load` (item 9's D6, driver note (f)) | **7 FAILED** — `BR07` ×2 (source + ordering), `BR43`, `BR44` inventory, `BR45`, `BR46`, `BR52` | Independently reproduces the implementer's row (c); the D6 tree-refresh deliverable is genuinely covered, not covered-by-assertion |
| **V8** | delete the `catch {balloon $cb ...}` line from `rawbar_sync` — i.e. kill **the PLAN's Eyeball deliverable** (the full-path tooltip) while leaving entry text and `-values` intact | **4 FAILED** — `BR08` (structural) plus the `BR42`/`BR44`/`BR46` balloon legs | The tooltip is covered BEHAVIOURALLY (the real `<Enter>` script), not by a source grep. This is the one the eyeball-owed item most needed |
| **V9** | narrower than V3: remove only `catch {$cb configure -values [wviewer::rawhist_get]}` **for the loading window**, keeping the fanout loop | **4 FAILED** — `BR24`, `BR28`'s own-window leg, `BR50`, `BR51` | The own-window dropdown is covered INDEPENDENTLY of the new fanout; the P4 fix did not become the only thing holding `BR50/BR51` up. No hollow spot |

Final state after all injections: **X arm 85/85, `--nogui` arm 40/40, `git status
--short src/` empty.**

### 13.6 Non-baseline fails

**NONE.** Two full audits, sets compared and never counts.

| audit | summary | X deaths | verdict |
|---|---|---|---|
| first shipping (`audit_i13_run1.log`) | `252 pass  23 fail  0 crash/timeout  12 skip` | `grep -c 'X connection to :0 broken'` = **0** | 15 of the HARD 16 + 8 FLAKY names |
| fixup (`scratchpad/audit1.log`, launched epoch 1786014975, inside the grant) | `253 pass  23 fail  0 crash/timeout  11 skip  (total 287)`, `WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)` | **0** | 15 of the HARD 16 (`test_rotate_stretch_short_0104` **self-SKIPPED**, did not fail) + 8 FLAKY: `test_ase_unnamed_net`, `test_graph_context`, `test_launch_context`, `test_palette`, `test_pristine_untitled_viewer_0172`, `test_remap`, `test_sod_pick_no_select_0204`, `test_wave_hilight` |

The verifier read `audit1.log` itself rather than accepting the table. **Every
file this item touches PASSED** in it — `test_wave_sigbrowser`, `test_wave_grid`,
`test_wave_sigbrowser_i11`, `_i12` and `test_wave_sigbrowser_i1315` — as did
`test_cmdmode_descend_0201`, `test_lib_manager_checkin` and
`test_hover_highlight`, the three names the verifier could not place in its own
earlier run. **`0 leaked scratch dir(s)`**; `tests/headless/.scratch` holds only
`0211`, dated Aug 3, i.e. predating this item.

**One flake reported, not chased:** `test_wave_sigbrowser` (FROZEN, untouched by
the fixup) failed `BT45` once in 6 runs with `not-narrower (w=400 240 160
settled)` — §10.1's shape and numbers verbatim. Ruling-22 A/B: 1-in-6 with the
fixup, 0-in-6 with `src/wave_viewer.tcl` restored to HEAD, and it PASSED in the
full audit. A combobox `-values` fanout cannot reach a toplevel the WM never grew.
**For the driver's FLAKY list; the mechanism is item 9's `browser_width`.**

### 13.7 DIVERGENCES FROM THE PLAN — the complete list, each with its reason

1. **The persistence premise was FALSE, and `recent_files`' shape was substituted.**
   PLAN: "persisted in the config the same way other viewer prefs are". Measured:
   `grep -n USER_CONF_DIR src/wave_viewer.tcl` = **0 hits**; no wviewer pref is
   persisted anywhere. *Reason:* the named mechanism does not exist. The real
   house precedent is `load_recent_file` / `update_recent_file` /
   `write_recent_file` (newest-first, deduped, capped, Tcl-sourceable file under
   `USER_CONF_DIR`), so the store is its own `$USER_CONF_DIR/raw_history` with
   `$::raw_history_max` registered in `xschem.tcl` beside the other viewer vars.
   §2.
2. **The test lives in a NEW file, not appended to `test_wave_sigbrowser.tcl`.**
   *Reason:* superseded by driver ruling 30 / commit `18c45a16` — that file is
   FROZEN at items 8/9/10 (324 X checks). `_i1315.tcl` follows `_i11`/`_i12`'s
   pattern and sources `wvbs_common.tcl`. §7.
3. **Seven sabotages, not the PLAN's two.** *Reason:* (c) carries driver note
   (f)'s D6 load, which the PLAN never named; (d) exists to prove `BR44` is not
   vacuous by producing a STALE tree rather than an empty one; V3/V4/V5 come from
   the fixup round. §6, §12.
4. **P4 — the undeclared per-window limit was FIXED, not merely declared.**
   `rawbar_sync` now fans the dropdown `-values` out to every other open viewer,
   and only the `-values`. *Reason:* ruling 17 says widen the coverage or narrow
   the claim; the receipt's existing claim ("every viewer window offers the same
   dropdown") was the honest one, so the code was made true rather than the claim
   shrunk. `BR28`/`BR29` + sabotage V5. §12 P4, declared limit 7.
5. **P3 — fixed by ACTUALLY FILING the issue, not by deleting the sentence.**
   `doc/claude/issues/0213-read-raw-ascii-point-overruns-its-buffer.md`. *Reason:*
   the C defect is real and was reproduced independently here (`Warning: ascii
   block is not of correct size` → `double free or corruption (out)` in
   `free_rawfile`; SIGSEGV in the verifier's variant), and a Location bar widens
   exposure to it. **No `.c` file touched** — settled decision 8. §12 P3.
6. **`BR19` spawns a `--nogui` CHILD PROCESS with `::env(HOME)` pointed at a
   scratch fakehome** (the `test_undo_link_symbols.tcl` idiom), and `BR28/BR29`
   build a SECOND throwaway toplevel. *Reason:* the startup read happens before
   the test script is sourced, so nothing in-process can observe it — a source
   grep alone is exactly what let sabotage V4 pass. Both are footprint axes the
   file's header did not originally claim; the header now declares them (no X
   connection, ~1.5 s). §12 P2.
7. **Two FROZEN test files were touched, +3 checks and one `gx_must` entry.**
   PLAN's Files line named only `src/wave_viewer.tcl` and `src/xschem.tcl`.
   *Reason:* ruling 17 — the new `.loc` row falsified item 9's sidebar child-SET
   claim in `test_wave_sigbrowser.tcl`, and `test_wave_grid.tcl`'s `GX4` count
   claim needed `rawbar_load` classified in `gx_must`. Widenings of existing
   claims, declared; both files PASS. §7.
8. **The BX39 divergence** — item 12's improve-or-restore refresh shape was not
   copied; `rawbar_load` gets the same guarantee **earlier and more strongly** by
   not clearing the previous raw at all. *Reason:* a failed read then cannot have
   replaced anything. §4, declared limit 5.
9. **`attach_raw` (the ASE re-run path) does NOT enter the history**, so the
   dropdown is not literally "the last 20 raw files opened". *Reason:* blast
   radius — `attach_raw` is referenced by `test_wave_grid`'s `gx_must`/`GX9` and
   two `ase_window.tcl` call sites. Offered as a follow-up issue, not hidden.
   Declared limit 1.
10. **The full audit was launched detached** (`nohup` + background poll).
    *Reason:* the Bash tool caps a foreground command at 10 minutes and the audit
    takes ~33; the first attempt was killed by that cap and **discarded**, not
    interpreted. (An earlier attempt was discarded for a different reason —
    weston aborted ten seconds in; §10.2.)
11. **`BT45` reported, not chased.** *Reason:* ruling 22 A/B says it reproduces
    with item 13 reverted, and the honest repair is a rewrite of item 9's
    `browser_width` (the sidebar width is computed once at toggle time and never
    recomputed) — outside item 13's scope. §10.1.
12. **Anchor drift, recorded for the next items:** `select_raw` is
    `xschem.tcl:14290`, not the PLAN's `:14209`; item 15's
    `wviewer::snapshot`/`restore` are `wave_viewer.tcl:2628`/`:2675`, ~460 lines
    off the PLAN's `:2165`/`:2212`. And, measured for free while probing:
    **`xschem raw info` DOES enumerate the extra raws**, which removes item 14's
    "`[D]` if there is no getter" risk. §1.

### 13.8 If this had FAILED — what a human would look at first

It did not fail; this row is here because the ledger schema asks for it, and
because the two coverage holes §12 describes were *found by a verifier and not by
a suite*. Should anything about item 13 come back:

1. **`§12` before `§6`.** The first shipping was fully green with the feature's
   own `rawbar_sync` call deleted. Any future doubt about this item should start
   by re-running V3 and V4 — if they stop firing exactly 6 and exactly 2, the
   coverage has rotted back to where it was.
2. **`/home/qflow/.xschem/raw_history` must not exist** unless the user has
   really opened raws from the bar in a GUI session. Its presence after a
   headless run means the 0119 gate is gone.
3. **Issue `0213` is still open and is C.** A crash reached through the Location
   bar is most likely a malformed ASCII raw, not this item's Tcl.
