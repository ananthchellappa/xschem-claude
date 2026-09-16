# ⚖ R9 ruling A2 — the picker shows the readable word and the deck keeps ngspice's

**One task from the driver: implement the user's ruling A2**, recorded in the `## A2` section of
`R9_COPY_REVIEW.md`. Files touched, and nothing else: `src/ase.tcl`, `src/ase_window.tcl`, two
suites (`test_ase_core`, `test_ase_dialogs`), `R9_COPY_REVIEW.md`, and this receipt.

No C. No new `.tcl` file, so no `src/Makefile.in` / `./configure` obligation.

HEAD was `252fee2d` at hand-over and is `252fee2d` now. **No commit, no `git add`, no
stash/restore/checkout/clean/push.** `tests/run_regression.tcl` **NOT run** — the driver's, solo.
`owed.sh count` is **187 rule, 70 look, 11 suite** before and after: **no `rule` debt added** (this
*is* the ruling being implemented) and **none cleared**. The ledger was never written, so no backup
was needed.

**104 of 104** tracked `.state` files round-trip byte-identically — `tracked 104`, `bad {}`,
**both controls 1** — driven as a **proc** (`ase_state_roundtrip`), never by running
`state_roundtrip.tcl` as a script. Measured three times: before, mid-change and on the final tree.

---

## ⚠ THE HEADLINE: THE MECHANISM THE RULING ASKED FOR WAS ALREADY IN THE TREE

The review's recommendation was *"display the readable word, emit the deck word. The mapping costs
one dictionary per picker."* It costs less than that, because **`valuelabels` is an existing
descriptor key with existing readers**: `trrandom`'s `dist` argument has carried
`valuelabels {1 Uniform 2 Gaussian 3 Exponential 4 Poisson}` since issue 1467, and
`ase::ui::nz_value_label` / `nz_value_of` / `nz_value_labels` have been mapping it — both
directions, identity fallback on each — in the trnoise editor all along.

So A2 is **one contract read by a second surface**, not a second contract:

* the four ruled fields declare `valuelabels` beside the `values` they already declare;
* three generic readers — `ase::field_value_label`, `ase::field_label_value`,
  `ase::field_value_labels` — went into `ase.tcl` on the **schema** side (they spell no simulator's
  syntax; they only read a declared dict, which is why D34/D36 put them there);
* **the three `nz_*` procs became one-line wrappers onto them.** Two implementations of one rule is
  the drift this batch exists to delete — the next correction would have been made to one and not
  the other — so there is now exactly one body. `test_ase_trnoise_gui_1467` (63 checks) and
  `test_ase_trnoise_1466` (80) are both **ALL PASS** against the wrappers.

⚠ **I had already written a second implementation before I found `nz_value_of`.** My first grep was
`nz_value_label\|nz_value_labels\|nz_value_from\|nz_label_value` — it missed the reverse reader
because it is spelled `nz_value_of`, and on that evidence I was one step from reporting the trnoise
commit path as a shipped defect that stores display words. It does not: `ase_window.tcl:6692` calls
it. **A grep that invents the name it expects is not a survey**, which is this batch's own C21
lesson arriving from the naming side.

---

## What changed, by handle

| handle | was | now | the deck still says |
|---|---|---|---|
| `R9-046` | `vol` | **`Voltage`** | `vol` |
| `R9-047` | `cur` | **`Current`** | `cur` |
| `R9-048` | `pz` | **`PZ`** | `pz` |
| `R9-049` | `pol` | **`Poles`** | `pol` |
| `R9-050` | `zer` | **`Zeroes`** | `zer` |
| `R9-053` | `dc ac` | **`DC AC`** | `dc`, `ac` |
| ✅ `R9-054` | `dec` (`oct`, `lin`) | **unchanged** | `dec`, `oct`, `lin` |

**No handle was added and none renumbered; the count stays 728.** Every new word REPLACES a handled
string one-for-one — R9-046's slot still names *"the first item of the Input type drop-down"* and its
text moved, exactly as A1 moved R9-011's from `Number of points (2 gives ONE point)` to
`Number of points`. Nothing is orphaned without a handle, which is the case that obliged A1's driver
to mint R9-727/R9-728 afterwards. Bookkeeping, measured: **727 lines match `^**R9-`, 726 distinct**,
identical to HEAD; the one `uniq -d` hit is the prose range header
`**R9-294 … R9-372 are consumed unchanged**` at line 5905, not a duplicate handle, and R9-727/728
live inside a blockquote so they do not match the anchor — which is why 726 bare handles coexists
with the document's *"728 strings"*. All of that is unchanged by me.

A scan of every fenced `text` block confirms the move: `vol$`, `cur$`, `pol$`, `zer$`, `^pz$`,
`^dc ac$` now return **0** hits, and `Voltage`/`Current`/`PZ`/`Poles`/`Zeroes`/`DC AC`/`dec` return
**1** each.

## ⚠ THE DECK IS BYTE-IDENTICAL TO `252fee2d`, PROVEN BY DIFF AND NOT BY READING THE CODE

An 89-line dump of every emitted surface a `kind mode` field can reach — `ase::analysis_line` for
all twelve `pz` combinations, all three `sens` modes, all four sweep values on each of
`ac`/`noise`/`disto`/`sp`, plus `op`/`dc`/`tran`/`tf`, plus `analysis_emit_check` and
`ase::field_value` for every one, plus each field's declared `values`/`default` — rendered on the
working tree and on the tree at `252fee2d`, and diffed.

**IDENTICAL, 89/89 lines.** The pristine copies were verified `md5 == git show 252fee2d:` *before*
the swap, the tree was restored with plain `cp` (never `-p`) under an `EXIT INT TERM HUP` trap, and
the restored md5s were checked after. `PZ2e` and `MP13`, the two rows that assert the registry still
spells ngspice's own words, **do not move** — that is the contract, not an accident.

## The exception is pinned by a row, which was the most important part of the task

`dec`/`oct`/`lin` stay as they are because the user ruled them so in the same breath as ruling the
other five expanded. Mechanically the sweep fields simply declare no `valuelabels` and both readers
are identity for such a field — which means **the exception is invisible in the source**, exactly
the shape A1's `SEGFAULTS` / `NOT OFFERED:` rows exist for.

**`test_ase_core` row `PZ2f`** is the pin. It carries a non-vacuity half on purpose: a tree where the
mapping was never built satisfies *"the sweeps are unlabelled"* trivially, so the row also demands
that the five ruled values DO map, that the map is exactly the ruling's, and that
`field_label_value(field_value_label(v)) == v` closes for **every declared value of every `kind mode`
field**. Sabotage **S4** — giving `ac`'s sweep a `valuelabels` — reds `PZ2f`, `G2e` and `G2g`.

⚠ **And `PZ2f` pins the deck separately from the screen, because nothing else does.**
`ase::analysis_emit_check` does **not** validate a `kind mode` value against its declared `values` —
only `real int time freq` reach the number check, by the deliberate allow-list issue 1416 installed.
So a display word that leaked into a row would be written into the deck **verbatim, at rc 0, with
nothing anywhere complaining.** That is why the mapping lives at the widget and
`ase::ui::form_get` maps back at the single funnel every commit path already goes through.

## Suites — name diff on BOTH arms

Row names **gained** and **lost**, not counts alone. `nogui` = `./src/xschem --nogui --pipe -q
--nolog`; `disp` = `devdisplay.sh exec` on `:99` (Xvfb + openbox 3.6.1, `1920x1080x24`).

| suite | before (nogui / disp) | after | rows changed |
|---|---|---|---|
| `test_ase_core` | 652 / 652 | **653 / 653** | **`PZ2f` gained**, both arms |
| `test_ase_dialogs` | 37 / 385 passed | 37 / **386 passed** | **disp: `G2a2` gained**; `G2pz` MOVED; nogui 0 |
| `test_ase_trnoise_gui_1467` | (not baselined) | 63 ALL PASS | wrapper regression |
| `test_ase_trnoise_1466` | (not baselined) | 80 ALL PASS | wrapper regression |

Floors raised with the file's own paragraph in both files: core **652 → 653**, dialogs display
**385 → 386** (headless unmoved at 37, every new row being a widget row inside the display guard).

⚠ **`G2pz` CANNOT APPEAR IN A NAME DIFF** — its golden and its gesture both changed and its name did
not. Sabotage **S1**, **S2**, **S6** and **S8** are what prove it moved.

⚠ **`test_ase_dialogs`' display arm carries ONE red before AND after: `G2sens`**, with the identical
actual value `{1 1 0 1 0 Entry Entry normal}` the file's own header records verbatim. It is
**issue 1436**, red on the pristine tree in the same run, and it is **not mine**. T1 runs this file
on **neither** arm.

**The whole ASE family was swept** for a stale golden my reader change might have touched:
**44 `test_ase_*` suites headless — 42 PASS, 2 SKIP**, the two being `test_ase_dirty` and
`test_ase_log_seam_0207`, which self-skip for want of X on that arm (nothing ran; not a pass). They
are the same two receipt 52b names.

## Sabotage — eight arms, every one red by name

Each arm: restore from the finished snapshot → mutate → **diff and require EXACTLY the intended
number of lines to have moved** → run → restore. ⚠ **The guard is not "the md5 moved"**: A1's
verifier had an arm lose its line address and become a global substitution while the md5 check
passed. Every arm below moved **1 line**, checked by `diff | grep -c '^>'`, and `S4` resolved its
line number by `grep` first because its target text occurs four times.

⚠ **The red-extractor was itself fed the empty case before it was trusted** — an empty log and a log
with no `RESULT:` line both returned `DIED(...)`, never `(none)`. A gate that answers "no failures"
to silence is decoration, and this batch has discarded five results to exactly that hole.

| | sabotage | reds |
|---|---|---|
| S1 | `pz.transfer` loses its `valuelabels` | `G2pz` `G2a2` · `PZ2f` |
| S2 | `pz.mode` loses its `valuelabels` | `G2pz` `G2a2` · `PZ2f` |
| S3 | `sens.mode` loses its `valuelabels` | `PZ2f` alone |
| S4 | **the exception reversed** — `ac.sweep` gains labels | `G2e` `G2g` · `PZ2f` |
| S5 | `form_get` loses the display→deck map | `G2pz` `G2a2` · core clean |
| S6 | `chana_field_row` loses the deck→display map | `G2pz` `G2a2` · core clean |
| S7 | `field_label_value` loses its identity fallback | `PZ2f` alone |
| S8 | the ruled spelling `Zeroes` becomes `Zeros` | `G2pz` · `PZ2f` |

**S5 is the arm that matters** — it is the one that would put a display word in the `.state` file and
the deck — and its blast radius is exactly the two widget rows while `test_ase_core` stays **653 ALL
PASS**, which is the widget-only containment the design claims. **S3 and S7 red one row each**, so
`PZ2f` is not a row that reds at everything.

**Ends on a positive restored-tree row**: `src/ase.tcl` `c72f09aa…` and `src/ase_window.tcl`
`1709a76a…`, both equal to the finished snapshot, with **core 653 ALL PASS** and **dialogs 386 passed
(`G2sens` only)**.

## Corrections

| | |
|---|---|
| **C1** | **Receipt 52's correction C2, met again and not learned from a document.** My first `PZ2f` used `expr {[dict exists $fd valuelabels] ? LABELLED : bare}`. Tcl's `expr` takes `yes`/`no`/`true`/`false` as boolean literals and rejects every other bareword, so it **raised**: the suite died at 466 of 653 with `invalid bareword "LABELLED"` and **printed no `RESULT:` line at all**. Rewritten with `if`, and the reason is recorded in the row so nobody re-derives it a third time |
| **C2** | **The `G2pz` pick row was passing by accident and would have shipped that way.** It gestured `$top.chana.form.mode set pol` — the DECK word — and `ase::field_label_value` falls back to identity, so the row went on storing `pol` **with the display map never once consulted**. MEASURED: on the first full run after the source change, that row stayed green while the mapping was live. The gesture now uses `Poles`/`Current`, the words a user can actually see, and the row became a real write-direction proof |
| **C3** | **`valuelabels` and its two readers already existed** (headline). My first design minted a parallel mechanism; it was deleted in favour of wrapping |
| **C4** | **A name diff alone would have reported `G2pz` as untouched.** Its golden moved from `vol pz {vol cur} {pz pol zer}` and its gesture moved with it, under an unchanged row name — so the sabotage arms, not the diff, are its evidence |

## `Zeroes` vs `Zeros` — the answer, reported rather than decided

**Shipped as the user ruled it: `Zeroes`.** But the tree is consistent the other way and the driver
should see that before this lands.

* Every occurrence of the plural noun in the tree spells it **`zeros`** — twelve in `src/` (including
  `ase.tcl`'s own pz comments, *"no zeros at all"*), and the APPENDIX throughout. `zeroes` appears
  **only as the verb** (*"`notrnoise` zeroes white and 1/f"*), which is a different word.
* ⚠ **`PLAN.md` line 2226 proposes the plot label for this very analysis as `{Poles and zeros}`.**
  That is the closest sibling copy there is, and it disagrees with the picker this ruling just
  shipped.
* **No *shipped* user-facing string used either spelling before now**, so nothing on screen is
  contradicted today. The collision arrives the first time that plot label lands.

I did not introduce a second spelling silently and I did not overrule the ruling: it is shipped as
`Zeroes`, pinned by `PZ2f` and `G2pz` (sabotage S8), and flagged in R9-050's note so the user can
settle `Zeroes`-everywhere or `Zeros`-everywhere in one word.

## ⚠ Found and NOT fixed — stated plainly

1. **`ase::analysis_emit_check` does not validate a `kind mode` value against its declared `values`.**
   A row carrying `Voltage` would render `pz in 0 out 0 Voltage pz` into the deck at rc 0 with no
   complaint from anything. This is **pre-existing** and not introduced by A2 — the allow-list is
   issue 1416's deliberate fix for the opposite defect — and A2 does not make it reachable, because
   the display word is mapped back at `form_get`. I did not add the membership check: it would be a
   new refusal path and a new sentence, which is the user's to rule on, not mine. `PZ2f`'s header
   records the gap at the point someone would need it.
2. **`test_ase_trnoise_gui_1467` and `test_ase_trnoise_1466` have no BEFORE baseline from me.** They
   are green after the change (63 / 80) and they are the wrapper's regression cover, but I ran them
   only on the finished tree.
3. **The ASE family sweep was headless only.** The two SKIPs above were not re-run on `:99`.
4. **`full_audit.sh` was not run**, and no `:0` / `$DISPLAY` run was taken — the display arm here is
   `:99`. No pixel deliverable is claimed.
5. **The `Find: PZ` collision R9-048's old note recorded survives the change** — the picker value is
   still spelled like the analysis type shown in the grid. The ruling changed the case, not the
   collision.

## Debts — queue

**Nothing added, nothing cleared. 187 rule, 70 look, 11 suite, before and after.** No new
user-facing sentence that is the user's to rule on — every string here is the ruling's own required
content. ⚠ **A `look` debt was considered and NOT filed**: A2 changes seven words inside three
existing comboboxes and adds no widget, no layout and no drawing. If the driver wants an eyeball on
the `pz` and `sens` forms reading `Voltage` / `PZ` / `DC`, that is a `look` and it is the driver's
call rather than mine. ⚠ **A `suite` debt for a `:0` run was likewise considered and NOT filed**, for
the same reason. The one judgement I flag upward is the `Zeroes`/`Zeros` spelling above, which is
recorded in R9-050's note rather than as a debt because the ruling already answered it.

## Hygiene

* **Every command carried a `timeout`.** Two commands exceeded the foreground window and were
  backgrounded by the harness; **both were polled by me in the foreground under a self-announcing
  deadline** (`FINISHED after 0s` / `after 80s`), never left to wake me. Nothing was stopped for
  memory, so no run lacks a verdict.
* **No simulation was run at all, and none was needed** — every row here is pure Tcl that never
  starts a simulator, which the brief's testing discipline says to state rather than test twice. The
  emitted-deck claim is a diff of rendered text against `252fee2d`, not a run. **No deck lived under
  `sky130A/`**; the one probe script is in the scratchpad. `/usr/bin/ngspice` was **never invoked**,
  so it was neither crashed nor hung.
* **Binary always by path** (`./src/xschem`, `devdisplay.sh exec ./src/xschem`), always `--nolog`,
  never `--logdir`, never a bare `xschem`.
* ⚠ **`~/.xschem` — checked rather than assumed.** `recent_files` is **untouched at 2026-09-13
  18:53**, the issue 0924 canary, unchanged across this whole task.
* **Processes matched by NAME** (`ps -eo comm=` / `ps -eo pid,lstart,comm=`), never `pgrep -f` or a
  pattern my own argv contained. **No `pkill`.** **No background process of this crew is running.**
  Alive at hand-over and named rather than waved past: `Xvfb` pid 1116 (**Sep 15 08:09:29**, the
  shared `:99` dev display) and **two `xschem`** pids 807232 / 809774 (**Sep 15 22:42:28** and
  **22:46:56**) — the same two pids and start times receipts 52 and 52b name, predating my session
  (Sep 16 07:37) by nine hours. One `ngspice` appeared in a single `ps` sample and was gone from the
  next; **it is not mine**, since I started no simulator.
* **Snapshots**: pristine and finished copies were taken before any mutation and are **now moved to
  `…/scratchpad/a2/ARCHIVED_DO_NOT_RESTORE/`** at hand-over, so a stale waiter cannot fire a restore
  over a later tree. Campaign logs are kept beside them as the evidence this receipt points at.
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching anything.**

## What binds later stages

1. **A `values` picker displays `valuelabels` and stores the declared value**, and the readers are
   `ase::field_value_label` / `ase::field_label_value` / `ase::field_value_labels`. A new `kind mode`
   field gets a `valuelabels` entry or it ships ngspice's raw keyword to the user. The `nz_*` trio
   are wrappers — **do not re-implement the rule in either place.**
2. **`dec`/`oct`/`lin` staying lowercase is a USER RULING, not an omission** (`PZ2f`). A consistency
   pass that labels them has reversed the user.
3. **`ase::ui::form_get` is the only place a display word becomes a deck word.** Any new reader of a
   form combobox must go through it, not through `[$w.$field get]`, or the display word reaches the
   state file and the deck — where `analysis_emit_check` will not stop it.
4. **A suite gesture on a mapped picker must use the word on screen.** `set pol` passes through the
   identity fallback and proves nothing; `set Poles` is the test.
