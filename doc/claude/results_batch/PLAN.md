# Results batch — PLAN

**Feature:** `Results ▸ Select…` — binding a saved simulation result to an ASE-L
session, so that the Calculator, the viewer and every consumer work against the
same chosen result.

**Authority:** `doc/claude/specs/results_selection.md` (966 lines, 19 sections,
ruled §17 by the user 2026-08-18). The spec's R-numbers are the contract; this
file only sequences them. **Where this file and the spec disagree, the spec
wins** — except for the two driver rulings in `DECISIONS.md` §B, which are newer.

**Base HEAD:** `226302f9`, branch `fluid-editing`. Nothing is pushed.

**Out of this batch, on purpose:**

- **Run history / per-run result directories** (R704, D7, driver ruling D-B).
- **Typed accessors `VT(out)`/`IT(...)`** — the half that makes a plotted name
  say which analysis it came from. Own spec
  (`doc/claude/specs/typed_signal_accessors.md`, ruled §17 Q1-Q5), own batch,
  **after** this one, blocked on issue **0512**. Spec §19 orders it that way
  deliberately: this batch settles *which file*, that one settles *which
  analysis inside it*.
- **Issue 0511** (`raw switch` `update_op()` gate mixes pre- and post-switch
  state) — low severity, both operands usually agree.
- **R605's clear-then-read ORDER** on the restore path. Bringing
  `wviewer::restore`'s inline attach onto `results::select` is item 6's business;
  changing the order is a measured behaviour change and is deferred.

---

## §1. The item list — AUTHORITATIVE

| # | slug | title | verdict expected | closes |
|---|---|---|---|---|
| 1 | `read-restamp-0509` | `xschem raw read` re-stamps on the dedupe path (R110, R112) | `[x]` | 0509 |
| 2 | `results-tcl-resolver` | `src/results.tcl` — pure resolver + registry readers (R201-R204, R304, R305) | `[x]` | — |
| 3 | `raw-select-subverb` | `xschem raw select <file> [type]` sub-verb (R301, R113, R114) | `[x]` | — |
| 4 | `results-select-orchestrator` | `results::select` — the one place that selects (R302, R303, R801-R805) | `[x]` | 0216 (shape) |
| 5 | `rawbar-load-reexpress` | `wviewer::rawbar_load` re-expressed on `results::select` (R501) | `[x]` | — |
| 6 | `persistence-write-side` | `viewer.rawfile` is finally WRITTEN (R601-R604) | `[x]` | — |
| 7 | `results-select-dialog` | `Results ▸ Select…` in ASE-L (R401-R407) | **`[E]`** | — |
| 8 | `waves-menu-cadence-gate` | Waves menu gated on `cadence_compat` (R505, §17.2) | `[x]` | 0508 |
| 9 | `kill-second-rawinfo-parser` | `raw_is_loaded`'s by-word parser dies (R304, T-K) | `[x]` | 0507 |
| 10 | `calculator-consumes-selection` | The Calculator consumes the session's selection (R305, R502, R503) | `[x]` | — |

**Dependency order is strict**: 2 needs 1's semantics settled, 3 needs 2, 4 needs
3, 5/6/7 each need 4, 9 needs 2, 10 needs 4. 8 is independent of 4 but is placed
after it so its refusal message can point at a `Results ▸ Select` that exists.

---

## §2. Re-grepped pointers — measured at `226302f9`, 2026-08-19

Do **not** trust a line number quoted anywhere else without re-grepping. These
were re-grepped for this plan.

| symbol | where |
|---|---|
| `extra_rawfile()` "file found: switch to it", arm 1 | `src/save.c:1916-1921` |
| `extra_rawfile()` "file found: switch to it", arm 2 | `src/save.c:1968-1975` |
| `extra_rawfile()` header comment | `src/save.c:1833` |
| the `raw` / `raw_query` dispatcher arm | `src/scheduler.c:10332` |
| `raw_clear` arm · `raw_read` arm | `src/scheduler.c:10761` · `:10776` |
| `xschem set raw_level` (re-stamps BOTH fields) | `src/scheduler.c:12275` |
| `xschem get raw_level` | `src/scheduler.c:5007` |
| `sch_waves_loaded()` (52 call sites) · `get_raw_index()` | `src/draw.c:2825` · `src/save.c:3406` |
| `wviewer::rawinfo_parse` (the correct, per-LINE parser) | `src/wave_viewer.tcl:2380` |
| `wviewer::db_label` · `wviewer::db_suffix` | `:2414` · `:2571` (**re-grepped 2026-08-20**; `:2401` was the pre-batch line) |
| `wviewer::rawbar_load` | `:8392` |
| `wviewer::rawhist_get` · `wviewer::rawhist_push` | `:8224` · `:8279` |
| `wviewer::snapshot` · its hardcoded `rawfile {}` | `:3982` · **`:3995`** |
| the build-order comment naming `rawfile {}` | `:3905` |
| `wviewer::restore` · its inline attach block | `:4042` · **`:4074-4081`** |
| `wviewer::browser_status` | `:10319` |
| `ase::raw_content_verdict` (the ONLY content check) | `src/ase.tcl:2794` |
| `ase::attach_dbs` (the run path — out of scope, §18) | `:2866` |
| `ase::last_rawfile` · `ase::rundir` · `ase::echo` | `:1952` · `:1643` · `:138` |
| `ase::ui::viewer_snapshot` · `ase::ui::viewer_restore` | `src/ase_window.tcl:4358` · `:4441` |
| ASE-L Results menu (2 adds, **no separator today**) | `src/ase_window.tcl:526-535` |
| `select_raw` (only `.raw` filetype filter in the tree) | `src/xschem.tcl:16672` |
| `load_raw` · `proc waves` | `:16874` · `:6373` |
| the Waves menubar cascade | `:17332-17348` (`Clear` at `:17335`) |
| ~~`raw_is_loaded` (the by-word parser, ZERO callers)~~ | **REMOVED by item 9** — `:6980-6997` is now the tombstone comment (spec R304c/R304d) |
| `calc::results_source` | `src/calculator.tcl:838` (consumer at `:892`) |
| `.calc.res.path` readonly · `.calc.res.browse` disabled | `src/calculator.tcl:712` · `:723-727` |
| `src/results.tcl` | **does not exist yet** |

---

## §3. Verification map — spec §12's invariants to items

| invariant | item |
|---|---|
| **T-A** first select of a not-yet-loaded file | 3 |
| **T-B** re-select while standing on a different cell (the R110 re-stamp) | 1 |
| **T-C** `rawbar_load` observably byte-identical | 5 |
| **T-D** a failed selection leaves the previous one intact | 3, 4 |
| **T-E** restore of a relative / of a deleted `viewer.rawfile` | 6 |
| **T-F** `snapshot` writes a non-empty `rawfile`; round-trip re-selects | 6 |
| **T-G** per-trace `%<rawfileA>` survives selecting B | 4 |
| **T-H** the four resolver statuses, one sentence each | 2 |
| **T-I** Calculator row and `results::current` agree | 10 |
| **T-J** a refused borrow ticket is reported as refused, not "no results" | 4 |
| **T-K** grep: no by-word parser of `xschem raw info` survives | 2, 9 — **DONE**, group AP `SEL459-SEL474` |
| **T-L** grep: no Waves *load* entry reaches `raw_clear` / `raw_read` | 8 |
| **T-M** a stamp that does not match the stack is not reported as success | 4 |

Suites: `tests/headless/test_results_select.tcl` (**new**, items 2-4 grow it),
plus additions to `test_ase_persist` (6), `test_calc_skeleton` (10),
`test_wave_sigbrowser_i1315` where a browser refresh is asserted (4, 5).

---

## §4. Item briefs

The driver passes each of these to `item_pipeline.js` as `args.brief`, verbatim.

### Item 1 — `read-restamp-0509`

**C.** In `extra_rawfile()`, both `what == 1` "file found: switch to it" branches
(`src/save.c:1916-1921` **and** `:1968-1975` — the arm is written twice, which is
half of why 0509 survived) must refresh `raw->schname` and `raw->level` from
`xctx->sch[xctx->currsch]` before returning. **No re-parse of the file.** Fix
`extra_rawfile()`'s header comment (`:1833`, *"return 1 if sucessfull, 0
otherwise"*) so it says what the return value means when the file was already
loaded (R112).

**R111 is binding: `xschem raw switch` keeps its behaviour and does NOT
re-stamp.** Switching is navigation between things already bound; re-binding is
what `read` is for.

**Non-goal, explicitly:** do not relax `sch_waves_loaded()` (`src/draw.c:2825`).
It has 52 call sites across seven files; widening the gate is its own change with
its own audit.

**T-B** is the check: read a raw under cell A, `xschem load` cell B, `raw read`
the same file there, and `xschem raw index <a known node>` must come back `>= 0`.
Sabotage: revert the re-stamp in one arm at a time — **both** arms need their own
red.

### Item 2 — `results-tcl-resolver`

**New file `src/results.tcl`.** Three procs, all pure or read-only:

- `results::resolve {state}` → the four statuses of spec §4: `default`, `ok`,
  `stale`, `invalid`. **It never throws and every status returns something
  usable** (R201, R202). `stale` = the content verdict refuses it, **or** its
  mtime is older than the netlist it came from; `stale` is still selectable and
  says why. `invalid` falls back to the derived path, never an error.
  The content half is `ase::raw_content_verdict` (`src/ase.tcl:2794`) — **the
  only content check in the tree. Do not reimplement it** (R203).
  The proc is **pure**: it reads the filesystem and returns a dict, never touches
  the registry (R204).
- `results::list {}` → `{{idx .. path .. type .. cur 0|1 label ..} ..}`, built on
  `wviewer::rawinfo_parse` (`:2380`) and `wviewer::db_label` (`:2401`).
  **There must not be a second parser for `xschem raw info`** (R304, issue 0507).
- `results::current {}` → the selected result's dict, or `{}`. It answers R103's
  three-part definition, so **a loaded-but-blind database is not a selection**:
  return `{}` when the stamp does not resolve against the current stack (F4).

**Wire it up so it actually ships**: source it from `src/xschem.tcl` next to the
other helper `.tcl` files **and add it to the install list**, then pin that with
a check. A new `.tcl` that is sourced but not installed is a known failure class
in this tree; do not let it recur silently.

**T-H** and the first half of **T-K**.

### Item 3 — `raw-select-subverb`

**C.** A new sub-verb `xschem raw select <file> [<type>]` in the **existing**
`raw` arm (`src/scheduler.c:10332`). **No new top-level `xschem` command
(R114) and no new C data structure (R113)** — the selection is `extra_idx` and
nothing else.

Semantics, in order (R301):

1. `(file, type)` already in the registry → `extra_rawfile(2, …)` (switch)
   **and** re-stamp per item 1's rule, because the user asked for *select*, not
   *navigate*. `<type>` is therefore **required** here, or resolve it from
   `results::list` first and pass the slot **index** — the switch-by-name loop
   refuses without it.

   > **SUPERSEDED by ruling R301b (item 3, `8377532a`).** `<type>` is
   > **OPTIONAL**: the verb routes through the `what == 1` dedupe arm, which
   > matches on filename alone, so L10's by-name refusal never applies. An
   > explicit type still works — R301b is a superset. There is **no by-index
   > form** (`raw select 0` → 0). The wrong text is kept in place because it is
   > what the item was briefed with, and R301b was measured against it.
2. otherwise → `extra_rawfile(1, …)` (read + make current + stamp).
3. **Never clear.** F7.

Return **three** values, not two: `2` selected-by-switch, `1` selected-by-read,
`0` refused.

**T-A** and **T-D**. T-A's wording matters: *"leaves that path present exactly
once in the registry and current"*, **not** "adds exactly one slot" — the first
read into an empty context also adopts the base raw into slot 0
(`src/save.c:1857-1862`).

### Item 4 — `results-select-orchestrator`

`results::select {path {sim_type {}} {opts {}}}` in `src/results.tcl`, returning
`{ok 0|1 how read|switch|refused path .. type .. status .. msg ..}`. It is the
**one** place that (R302):

- runs the resolver (item 2),
- calls `xschem raw select`,
- pushes to the MRU via `wviewer::rawhist_push` (`:8279`) — this is the shape
  that fixes issue **0216** for this path,
- calls `wviewer::casemode_invalidate` / `casemode_reapply`,
- refreshes a browser showing this context (`wviewer::browser_refresh $token 1`),
- writes the persistence slot (item 6 lands the writer; item 4 calls it),
- emits **one sentence** (§10).

Message discipline, binding: every refusal **returns a value and writes one
sentence — nothing throws** (R801). Channel by host: ASE-L → `ase::echo`
(`src/ase.tcl:138`), viewer sidebar → `wviewer::browser_status`
(`src/wave_viewer.tcl:10319`), Calculator → `calc::status`. **Never `puts`, never
the status bar directly** (R802). Sentences name the database by
**`wviewer::db_label`** — file tail + analysis — not by full path; the full path
lives in the balloon (R803).

**R804 is the sentence the whole feature exists for.** A selection that lands but
cannot resolve (F4) is reported as such, in those words, never as success:

> `Selected srlatch_ase.raw (dc), but this result was read against srlatch.sch and you are in tb_diff_amp.sch — no signal names will resolve until you return.`

**T-D**, **T-G**, **T-J**, **T-M**. T-M has a named sabotage: make
`results::select` return ok unconditionally and T-M must go red.

### Item 5 — `rawbar-load-reexpress`

Re-express `wviewer::rawbar_load` (`src/wave_viewer.tcl:8392-8424`) on
`results::select`. **Its user-visible behaviour must not change** (R501).

It is already correct on the hard points and each must survive: `file isfile`
guard, `switch_ctx` (a **move**, not a loan), additive read with **no** clear
(F7), `regenerate`, `browser_refresh`, `rawhist_push`, `rawbar_sync`,
`log_action`, and every refusal returning 0 with nothing thrown.

**Three of its five refusal arms write a one-line sidebar status; the
unknown-token arm and the failed-`switch_ctx` arm return silently.** The
re-expression must not quietly change which. `capture_live_view_state` and
`regenerate` are viewer concerns and **stay in `rawbar_load`**.

**T-C**: same rc, same registry delta, same MRU delta (with
`::update_recent_files` set and restored — L11), same status string, same two
arms silent.

### Item 6 — `persistence-write-side`

The read side is complete, covered and correct. **Nothing has ever written the
slot.**

- `wviewer::snapshot` (`:3982`) hardcodes `rawfile {}` at **`:3995`**. Write the
  selected result's path instead: **relative to `ase::rundir` when it is under
  it, absolute otherwise** (R602) — G11 already proves the relative form
  round-trips, and a relative path is what makes a state file movable.
  `snapshot` does not know the rundir, so either pass it in or relativise in
  `ase::ui::viewer_snapshot` (`src/ase_window.tcl:4358`), which does. **Decide
  that in the item, not in the patch**, and say which in the receipt. The
  build-order comment at `:4477` names `rawfile {}` too — update it.
- Re-express `ase::ui::viewer_restore` (`:3472-3504`) on `results::resolve`. It
  *already implements* §4's `ok`/`invalid` arms by hand (absolute-ise → `file
  isfile` → else `ase::last_rawfile`); that is the model, not a rewrite target.
- Bring `wviewer::restore`'s inline attach (`:4074-4081`) onto `results::select`
  (R605). **Do not change its clear-then-read ORDER** — that is a measured
  behaviour change and is out of this batch.
- A restored selection runs the resolver exactly as a fresh one does, and its
  status is reported **once**, on restore, through `ase::echo` (R604).

**T-F** (the assertion that would have failed for the whole life of the seam) and
**T-E** (extends `test_ase_persist` G10/G11). **T-E is the batch's one test that
can be green by not having run** — those legs self-skip without a usable DISPLAY
or without ngspice. **Assert the skip reason, not just the count.**

### Item 7 — `results-select-dialog` — PIXEL DELIVERABLE, `[E]`

A new `Select…` entry in ASE-L's existing Results menu
(`src/ase_window.tcl:526-535`), **above `Direct Plot`**. The menu has **no
separator today**, so add one if `Select…` is to be grouped apart. Hand-built
plain Tk `$top.mb.results add command` — ASE-L's menubar is **not** generated
from `actions.csv`, so **no CSV row is needed**; a key chord would need one plus
an `action_registry[]` entry in `callback.c`, and v1 has no chord (D8).

**ASE-L only** (U5). **No cascade is added to the waveform viewer's menubar**
(R504, D12): `tests/headless/test_wave_viewer.tcl:586-587` (G2) asserts the
cascade set is exactly `{File View Graph Cursors Options}`.

**Modeless** — no `grab`, no `tkwait` (R402). Not the vwait-latch chooser idiom
of `libmgr::view_dialog`, not the `tkwait window` idiom of
`save_as_cellview_dialog`. Widgets are the ASE house mix: plain Tk chrome painted
from `ase::palette` through `ase::ui::apply_theme` with the named ASE fonts, plus
`ttk::treeview -style Ase.Treeview` / `ttk::combobox` where a table or combobox
is needed (R403). Colours through the single accessor only.

Contents, top to bottom (R404): **Loaded** (`results::list`, current one marked,
`db_label` shown, full path in the balloon) · **Recent** (`wviewer::rawhist_get`,
newest first, entries already in the registry visually distinguished) · **Path**
(editable entry + `Browse…` → `select_raw`) · **Status** (the resolver's verdict
for the highlighted candidate, one sentence) · **Buttons** (`Select` · `Close`,
**no OK/Apply pair**).

**Loaded is listed first, deliberately inverting Cadence** (R405) — the common
case is "switch back to the one I had", which is free. Selecting is one gesture,
double-click or `Select`, and **the dialog stays open and refreshes**, because
comparing two runs means selecting twice (R406). The dialog reads the *host
session's* context via the borrow idiom; **a refused ticket is reported as
refused, never as "no results"** (R407, F6).

**Anti-vacuity:** existence + class + `cget` is not proof a control is mapped —
assert `winfo manager` / `winfo ismapped` / slave order.

**This item may not be verdicted `[x]`.** `[E]`, and it owes
`tests/headless/owed.sh add look`.

### Item 8 — `waves-menu-cadence-gate`

Gate, do not repair (U4, U12). Under `cadence_compat`, the **eight** loading
entries of the Waves cascade (`src/xschem.tcl:17332-17348`) — `Load first
analysis found`, `Op`, `Dc`, `Ac`, `Tran`, `Noise`, `Sp`, `Spectrum` — **and
`Op Annotate`** are blocked, with a sentence that names `cadence_compat` and
points at `ASE-L ▸ Results ▸ Select`. **`Clear` (`:17335`) and `External viewer`
keep working** — neither loads a result. Without `cadence_compat`, the menu
behaves exactly as it always has.

`cadence_compat` is an established gate, not a new mechanism: `set_ne
cadence_compat 0` (`src/xschem.tcl:18435`), a menu checkbutton (`:17177`), read
from C via `tclgetboolvar("cadence_compat")` (`src/callback.c:633`).

Background, for the comment you leave behind: `load_raw` (`:16874`) calls
`xschem raw_clear` and then `xschem raw_read`, **which itself clears the whole
registry** — so those eight entries silently discard every other loaded result
(issue 0508). `Op Annotate` calls `select_raw` directly.

**T-L** is a grep test: no Waves *load* entry reaches `xschem raw_clear` or the
registry-clearing `xschem raw_read`; the `Clear` entry is the sole permitted
caller. Drive the menu in **both** flag states.

### Item 9 — `kill-second-rawinfo-parser`

> **HISTORICAL — this brief is written in the present tense and the proc is
> GONE** (item 9, `70801385`, ruling R304c: removed, not re-expressed; a
> tombstone comment at `src/xschem.tcl:6980` keeps the file line-neutral,
> R304d). Kept as briefed, per this batch's convention.

Issue **0507**. `raw_is_loaded` (`src/xschem.tcl:6980`) parses `xschem raw info`
**by word** (`foreach {n f t} [lrange … 2 end]`), so it breaks on a path with a
space. It has **zero callers** — upstream `23092fc9` added it, `ad96e222` lost
the caller — so it is latent and cheap to remove now and expensive later. Its
warning comment carries **two rotted citations**; either they go with it or they
are re-grepped.

Remove it, or re-express it on `results::list`. **T-K** pins the ruling by grep.
Note what T-K is **not**: four line-wise readers already exist
(`wviewer::rawinfo_parse`, `ase::raw_indices` `src/ase.tcl:2935`,
`ase::raw_current` `:2943`, and the test helpers), so *"exactly one parser"* is
**not** the assertion. The assertion is that no **by-word** parser survives.

### Item 10 — `calculator-consumes-selection`

Four rulings land together (U3, U6, U7, U9):

- **Remove the `self` arm from `calc::results_source`** (`src/calculator.tcl:838`,
  consumer at `:892`) **entirely** — not demoted, removed. The Calculator never
  reads a raw that a legacy path put into a schematic window.
- **The Results Dir row PICKS.** It stops being a reporter: what the row names is
  what Evaluate reads, and changing the row changes what Evaluate reads. It is
  fed by `results::current` (R305).
- **Evaluate with no result refuses and names the next action**, in these words:
  *"No simulation results are loaded. Run a simulation, or pick an existing one
  with ASE-L ▸ Results ▸ Select."* The Calculator does **not** offer to launch
  ASE-L itself.
- **`Browse` stays disabled** (`.calc.res.browse`, `:723-727`), and the stub
  keeps its shape **and gains the reason in the code**: browsing to a result is
  `ASE-L ▸ Results ▸ Select`'s job. Update R502 in the spec to say so — it
  currently reads as "Browse becomes live", which U9 reverses.
- **A Calculator selection does not drag the waveform viewer with it** (U8).

`tests/headless/test_calc_skeleton.tcl` **S26** currently pins the old
self → viewer → ASE → none resolution. It is not deleted, it is **restated**, and
the receipt says why the expectation genuinely changed. **T-I.**

This item is the gate `doc/claude/calculator_batch` phase 3 has been waiting on;
say so in the commit body.
