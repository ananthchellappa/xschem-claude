# The Signal Browser, two-pane — SPEC

Status: **SPEC — IN BUILD.** Items 1-2 landed (`422b3f55`, `d30f8f99`). Written 2026-08-07 on branch `fluid-editing`, before any
code. Every number in it was measured on this machine during the recon that preceded it;
nothing is inherited unverified.

**Parent spec:** `doc/claude/specs/waveform_signal_browser.md` (the as-built single-pane
browser). This document does not replace it — it specifies the rebuild, and the parent is
amended item by item as each proc lands (GS1 forbids naming a proc in the parent spec
before it exists; see §12.3).

**Prerequisite defect:** `doc/claude/issues/0217-raw-device-class-prefixes-render-as-fake-hierarchy-levels.md`.
**Supersedes:** `doc/claude/suggestions/signal_browser_declass_class_toggle_work_order.md`
§7 (the six rulings it says are owed are all taken below) and
`doc/claude/suggestions/next_session_signal_browser_hierarchy.md` §"THE THREE FEATURES"
item 3.
**Operational map:** `doc/claude/code_analysis/signal_browser_reference.md` — still correct
about the pipeline, wrong about §1/§9 and the "~3 in 10" at `:100`
(`signal_browser_teardown_scoping.md` §7-F has the correction).

---

## 0. Why the browser is being rebuilt

The shipped browser puts hierarchy groups and signal leaves in **one interleaved tree**.
Measured against 22 real ngspice-46 raws, that does not scale and it is not what the tool
it ports from does:

| design | signals listed today | of which are design nets |
|---|---|---|
| `tb_bandgap` | 424 | 139 |
| `tb_charge_pump` | 1191 | 110 |

77.2% of all corpus signals (2051 of 2656) and 86.7% of hierarchical ones (2026 of 2338)
are ngspice device-class artefacts filed under a **fake** top-level node — `m`, `v`, `@m`,
`@c`, `@r`, `@b`, `@q`, `n` — none of which is an instance in any design (issue 0217).

Cadence separates the two axes. ViVA 6.1's own stated rationale, verbatim: *"Data display
is separated between two panes … This separation allows compact representation of long
signal lists."* Its Results Browser is a hierarchy tree plus a signal list, and clicking a
tree node **drills down** — it replaces the list with that node's own children rather than
flattening every descendant.

This spec ports that separation.

---

## 1. The shape of the thing

The sidebar keeps its position, its width derivation and its outer packing exactly as
shipped (`$top.wvbrowser`, packed `-side left -fill y -before $top.drw`, §6 of the parent
spec, decision 1). What changes is what sits between the Search bar and the Filter bar.

```
+-- $top.wvbrowser ---------------+---------------------------------+
| [ .../tb_bandgap.raw  v][Browse]|                                 |
| [All v][pattern  ][Shell v][ ]  |                                 |
|        Match case [ ] All DBs   |                                 |
|                      [Search]   |                                 |
| [Plot]                          |                                 |
| [ ] Show device internals       |   <- R11(a), default OFF        |
| [x] Show source currents        |   <- R11(b), default ON         |
| +- UPPER: instance tree ------+ |                                 |
| | v tb_bandgap            [^] | |          the canvas             |
| |   > x1                  [ ] | |          ($top.drw)             |
| |   > x2                  [v] | |                                 |
| | <=====h-scroll=========>    | |                                 |
| +=============SASH============+ |                                 |
| +- LOWER: sea of names -------+ |                                 |
| | vbg     net1    v1:i        | |                                 |
| | clk     start   v2:i        | |                                 |
| | vss     en_n    vcc:i       | |                                 |
| | vcc     e5_int1 time        | |                                 |
| | <=====h-scroll only=====>   | |                                 |
| +-----------------------------+ |                                 |
| [All v][filter ][Shell v]...    |                                 |
| Signal Browser (18 of 190)      |                                 |
+---------------------------------+---------------------------------+
```

**Upper pane** — the instance hierarchy. Nodes are instances, never signals. Collapsed by
default. Both scrollbars. Exactly one node selected at all times.

**Lower pane** — the "sea of names". The signals owned by the selected node's **own level
only**, flowed column-major: fill a column top to bottom, then start the next column to
the right. The number of rows per column is whatever the pane's current height allows.
**Horizontal scrollbar only** — there is deliberately no vertical one, because a name is
never below the fold; it is only ever to the right.

The two panes are the two children of a vertical `ttk::panedwindow`, so the split is
draggable.

---

## 2. Rulings

All 23 are settled. A later change needs a new ruling, not a code review. **R** = ruled by
the driver; **M** = ruled by the implementer under delegated authority, and each M-ruling
names the measurement that forced it.

### 2.1 Driver rulings

| # | Ruling |
|---|---|
| **R1** | The upper pane shows **instances only**, collapsed by default, any number of subtrees expanded at once. Device wrappers are **hidden by default** and revealed by R11(a). |
| **R2** | The tree has exactly **one root node, named for the design**, and it is **selected when the browser opens**. Top-level signals are the root's own-level signals. |
| **R3** | The lower pane shows the selected node's **own-level signals only** — not descendants. Column-major flow, rows-per-column from the available height, **horizontal scrollbar only**. |
| **R4** | Tree selection is **single** (`-selectmode browse`). There is always exactly one node selected: either the design root or a descended instance. |
| **R5** | **Both** search bars (Search AND Filter, ANDed as today) filter **the lower pane only**. The tree **never auto-opens** on a search. |
| **R6** | A plot gesture on a **tree** node stays **recursive** — `browser_leaf_names` is untouched. Rationale, driver's own: plotting everything under a block is how you find what is coupling into a signal you see a kink on. |
| **R7** | **All DBs**: with the box ticked, per-database headers become the tree's **top level**, above each DB's design root. |
| **R8** | Lower-pane labels, Cadence convention: **voltages bare** (`net5`); **currents `<instance>:<param>`** with the model name dropped (`xm1:id`, `v1:i`, `c1:i`). The full raw name stays in the tooltip and on copy. |
| **R9** | **Ctrl-L → Ctrl-B** for the browser toggle. See §8.1 — this overrides an in-source rejection. |
| **R10** | **Ctrl-Alt-V replaces Ctrl+5** as "Show in Signal Browser", routed through the **C action registry** so it is remappable. Nothing selected → reveal the current descend level. One instance selected → reveal that instance, as if the user had descended into it. |
| **R11** | **Two independent checkboxes**: (a) *Show device internals*, default **OFF**; (b) *Show source currents*, default **ON**. (a) governs both the tree's device nodes and the signal list. |
| **R12** | Ctrl-Alt-V aimed at a device instance whose node is hidden **auto-ticks (a)**, reveals it, and **says so** in the status line. The box stays ticked. |

### 2.2 Implementer rulings

| # | Ruling | The measurement that forced it |
|---|---|---|
| **M1** | 0217's `sig_declass` + the `class` field land **first, as their own commit**, before any pane work. | Without it 77.2% of corpus signals carry a fake hierarchy level and every node count in this spec is wrong. |
| **M2** | The sea of names is a plain Tk **`canvas`**. | Tk 8.6.14 (the linked version) has **no cell selection** in `ttk::treeview` — an N-column tree would let the user select N unrelated signals at once. `listbox` has no per-item font and cannot Shift-select across columns. `text` gives character-range selection. |
| **M3** | The panes are **stacked** in a vertical `ttk::panedwindow`; the sash persists as a **fraction**, never pixels. | The sidebar is already width-capped at `0.45 × window` (≈450 px at the spawn size of 1000×829), so a side-by-side split halves an already-narrow pane. Stacked fits 14+18 rows spawned, 23+36 maximized. |
| **M4** | The tree's column `#0` becomes **`-stretch 0` with an explicit width**, and gains `-xscrollcommand`. | `#0` is `-stretch 1` inside a `pack propagate 0` fixed-width frame, so it **always fits** — an h-scrollbar added without this change is decorative. Longest full raw name is 63 chars ≈ 537 px at the measured 8.53 px mean advance. |
| **M5** | **`browser_width` is untouched** — the 0.45 cap, the 240 floor and all four source literals stay. | Pinned twice: BT08 (`test_wave_sigbrowser.tcl:784-797`) and BP07 (`_i1315.tcl:730-745`), whose own comment forbids factoring the clamp into a helper. |
| **M6** | `browser_rows`' **anypath flat-mode gate is computed on the PRE-filter set**. | 9 of 22 corpus designs flip to flat mode — tree gone, full raw names as row text — if internals and source currents are hidden and the gate is computed after. |
| **M7** | **No legacy single-pane mode.** | A dual mode doubles the layout-coupled test surface, which recon measured at 79 of 933 checks concentrated almost entirely in one item. |
| **M11** | The tree's **design root is inserted `-open 1`**; every other node `-open 0`. | "Collapsed by default" taken literally including the root renders the whole tree as one line, which is not navigation. Ruled after the plan pass flagged it. |
| **M8** | The **sweep variable is not special-cased** in v1; it stays an ordinary row. | 8 of 22 raws are Operating-Point and have **no** sweep variable at all — index 0 is an ordinary signal (`i(vc1)`). "Index 0 is the sweep var" would hide a real signal in 8 designs. |
| **M9** | Vector slices `xm1[0]`..`xm1[9]` are **ten sibling nodes**; params parse from a **trailing** bracket only. | 30 corpus signals carry an *embedded* bracket inside a path segment. A naive "first `[..]` is the param" parser reads `[0]`..`[9]` as params. Issue 0212's descend refusal (`hier_resolve`'s `VECTOR` sentinel) is already correct and stays. |
| **M10** | `tests/headless/test_wave_sigbrowser.tcl` **may be widened.** | Ruling 30's purpose was to stop one 489-check file being killed mid-run by WSLg ~90% of the time, not to freeze its assertions. Item 13 already widened BS22/BT21's child set. Files stay under ~150 checks. |

---

## 3. The data model

### 3.1 `sig_declass` — the fifth key and the strip

`wviewer::sig_split` today splits the **unwrapped** name on its last dot. It gains one step
in front: strip an ngspice device-class tag.

**The rule**, sound by SPICE grammar rather than by heuristic: if the first segment of the
unwrapped name matches `^@?[a-z]$` **case-insensitively** *and* **at least two segments
follow**, it is a device-class tag — strip it, then split normally.

Why it cannot over-reach: a hierarchy level in a raw name comes from a *subcircuit
instance*, and SPICE requires subcircuit instances to begin with `X`. A one-letter segment
therefore cannot be a subcircuit instance. Corroborated across the corpus: every real path
segment starts with `x` (85 of 85); every fake root matches `^@?[a-z]$`. Zero overlap.

`sig_declass` **hands the stripped tag back** to `signal_entry` rather than discarding it.
That tag is the *only* evidence a segment is a device, and it exists for exactly one
instant — once stripped, `x1.x1.x1.xm1` cannot be told from a chain of real subcircuits.

⚠ **Ruling 14 stays true and needs one amendment**: `path`/`leaf` still split the
*unwrapped* name. The class strip is a step *before* the split, not instead of it.

### 3.2 The `class` field

`signal_entry` returns `{name type leaf path}` today. It gains a fifth key, `class`:

| value | what it is | example | corpus count |
|---|---|---|---|
| `net` | a design net, or a top-level source's branch current | `v(x1.adj)`, `i(v1)` | 605 |
| `devnode` | a device internal node | `v(m.x1.xm1.msky…#body)` | 1401 |
| `devmeas` | a device parameter accessor | `i(@m.x1.xm1.msky…[id])` | 464 |
| `srcbranch` | the branch current of a source **inside** a subcircuit | `i(v.x1.v1)` | 155 |

⚠ **The classifier keys on the stripped tag, never on the leaf's shape.** 0217:44 records
"100% of device leaves contain `#`". That is true forward and **false backward**: six real
*design* nets end in `#` — xschem's auto-generated net names, e.g.
`v(x2.x1.a_27_47#)` in `tb_charge_pump`. A classifier keyed on "the leaf contains `#`"
misfires on all six.

Mapping from tag to class:

```
tag {}   -> net                          (no tag: a design net or a top-level current)
tag v    -> srcbranch                    (i(v.<path>.<src>))
tag @X   -> devmeas                      (parameter accessor, X in m c r b q)
tag X    -> devnode                      (internal node, X in m n)
```

### 3.3 Node classification for the tree

R1's discriminator is the class field, **not** the segment spelling.

⚠ **MEASURED: "only x-prefixed segments" is a no-op.** All 85 distinct post-declass path
segments in the corpus start with `x` — sky130 wraps its MOSFETs in pcell subcircuits, so
`xm1` is grammatically a real X-instance. There is no lexical test.

**The rule:** a node is a **device node** — and therefore hidden while R11(a) is off — if
and only if **every signal at or under it is device-classed** (`devnode` or `devmeas`).

That formulation is deliberate. `xr1.x0` in the corpus carries design nets `t1`/`t2` **and**
`@r…[i]` measurements, so a set-subtraction rule would wrongly delete a node holding real
nets. The "every signal" rule keeps it.

**What the rule actually hides**, measured by running R1's own quantifier over the corpus —
kept iff **any** signal at-or-under the node is `net` or `srcbranch`:

| design | nodes total | kept (tree shows) | hidden as device-only |
|---|---|---|---|
| `tb_bandgap` | 128 | **44** | **84** |
| `tb_charge_pump` | 316 | **13** | **303** |

⚠ These are **not** the 78 / 278 that §14 quotes from the older work order. That figure is a
different metric — nodes minted *only* by device paths — and it undercounts, because a node
minted by a real net's path can still be hidden when every signal under it turns out to be
device-classed. Both numbers are right about their own question; only the table above is
right about **what the user will see**.

⚠ **Pure ancestors.** 18 of `tb_bandgap`'s 128 nodes and 25 of `tb_charge_pump`'s 316 have
**no own-level signals at all** — they exist only because a descendant does. The rule
above evaluates over *at or under*, so a pure ancestor is judged by its descendants and is
kept whenever any descendant is a real net. A node with no signals anywhere under it
cannot arise, because nodes are minted from signal paths.

**The lower pane legitimately renders EMPTY for a pure ancestor.** That is a correct
answer, not a bug, and it must be distinguishable in the status line from "the filter hid
everything" (§7.3).

---

## 4. The upper pane — the instance tree

### 4.1 Contract

* Row ids keep the shipped namespaces (`g:<dotted prefix>`, `d:<idx>` for All-DBs headers)
  so `browser_node_for`, `browser_target_path` and item 12's whole path survive. **No leaf
  (`s:`) rows appear in the tree any more.**
* One new id: the design root. It is a group row whose id is `g:` (empty prefix) and whose
  text is the design name.
* `-selectmode browse` (R4). The selection is never empty: on populate, if the previously
  selected id survives it is restored, otherwise the root is selected.
* Inserted **closed** (`-open 0`) — R1. This is the single change in `browser_populate`.
* Both scrollbars (M4).
* Double-click keeps ttk's expand/collapse — it always did, and D3 already documents that
  a group double-click does not plot.
* MMB and the Plot button keep the **recursive** `browser_leaf_names` behaviour (R6).
* `Key-E` (`Descend to here`) stays on the tree. It is a navigation action.

### 4.2 `browser_reveal` versus collapsed-by-default

⚠ **This is the sharpest interaction in the batch.** `browser_reveal` calls `$tv see`, and
**`see` force-opens every ancestor of the target**. So does `browser_tree_apply`'s restore
path. Under collapsed-by-default that is exactly right for a *deliberate* reveal
(Ctrl-Alt-V, item 12) and exactly wrong for a *populate*.

**Rule:** `see` may only be reached from a user-initiated reveal. `browser_populate` must
never call it, and the persisted `open` set must beat it — BP54 already pins that a
persisted collapse beats `see`'s ancestor-expansion, and that check stays green.

### 4.3 All DBs (R7)

With the box off the tree is exactly one design root and its instances.

With it on, the tree grows one level: each loaded raw is a top node (`d:<idx>`), and each
DB's design root is its child. `browser_rows_reparent` already prefixes every id in a
foreign group with `d:N|`, which is what makes this work without an id collision.

⚠ **`browser_target_path` is broken on those rows today** and must be fixed in this batch:
it does `[string range $id 2 end]` to strip a `g:` prefix, which mis-decodes `d:N|g:x1.x2`
into `N|g:x1.x2` — so "Descend to here" is *enabled* on foreign rows and fires a garbage
instance path. A second identical `string range` sits in `browser_show_path`. **Fix both
or neither.**

**On open with All DBs ticked**, the selected node is the **current** DB's design root —
the current DB is always group 0, unlabelled and unprefixed, and that invariant (BD22) is
what makes "current" well-defined when two DBs have different top cells.

---

## 5. The lower pane — the sea of names

### 5.1 Why a canvas

Enumerated and rejected, against Tk 8.6.14:

| candidate | why not |
|---|---|
| `ttk::treeview`, N columns | **No cell selection in 8.6.** `-selectmode` is `extended`/`browse`/`none`; there is no `cell` mode and no `-selecttype` in `libtk8.6.so`. An N-column layout would only ever select N unrelated signals at once. |
| side-by-side `listbox`es | No per-item font (only fg/bg), and each listbox owns its own selection, so Shift-click cannot cross a column boundary. |
| `text` widget | Requires fixed-width padded pre-formatting and yields character-range selection — the wrong shape entirely. |
| **`canvas`** | **Chosen.** Column-major flow, horizontal-only scroll, multi-select, per-item styling and O(1) hit-testing all fall out of it. |

Tk 8.6 ships a working reference for the flow: `::tk::IconList::Arrange`
(`/usr/share/tcltk/tk8.6/iconlist.tcl:301-376`; flow loop `:334-351`, scrollregion clamped
to the widget height `:359-368`, `itemsPerColumn` `:370`, `DrawSelection` `:378-397`).

**Copy the ~75-line algorithm; do not reuse the class.** `::tk::IconList` is declared
private and experimental (`megawidget.tcl:1-15`), requires an image per batch, exposes no
per-item colour API, and binds no `<Button-3>`.

**One deliberate divergence:** IconList hit-tests with `find closest`, which is O(n) in
canvas items. Because the flow is a regular grid, the hit-test is arithmetic:

```
col = int(canvasx / colWidth)
row = int(canvasy / rowHeight)
idx = col * itemsPerColumn + row        ;# out of range -> no hit
```

O(1), and it cannot mis-hit into the gap between columns the way `find closest` can.

### 5.2 Geometry

* `rowHeight` is read at runtime: `font metrics AseEntryFont -linespace` plus padding.
  **Never hardcoded.** Measured on this machine: Arial 13 → Liberation Sans, linespace
  19.93 px at X11's default 1.3333 px/pt scaling — but `tk scaling` differs per display
  and the shipped scrollable-frame idiom already hardcodes 24 px for exactly this row
  (`src/xschem.tcl:1683-1685`), which is a coincidence of one machine, not a contract.
* `colWidth` is the widest rendered label in the current list plus a gutter, measured with
  `font measure`, floored at a minimum so a list of one-character names does not produce
  fifty columns.
* `itemsPerColumn = max(1, int(paneHeight / rowHeight))`. It is recomputed on
  `<Configure>` — dragging the sash reflows the pane, which is the whole point of R3.
* `-scrollregion` spans `{0 0 <ncols*colWidth> <paneHeight>}`. The **height is clamped to
  the widget**, which is what makes the pane scroll horizontally and *only* horizontally.
* No `-yscrollcommand`, no vertical scrollbar. If a single column cannot fit one row the
  pane is too short to be useful and the sash is the remedy.

### 5.3 Selection and gestures

Selection is a **set** of indices, drawn by `DrawSelection` as rectangles behind the text
(`-fill` from the theme's select colour, no stipple).

| gesture | behaviour |
|---|---|
| LMB click | select one, replacing the set |
| Shift-LMB | extend from the anchor, in **flow order** (down the column, then to the next) |
| Ctrl-LMB | toggle one, keeping the set |
| Double-LMB | plot the selection |
| MMB | plot the selection |
| RMB | post the existing browser context menu, scoped to the selection |

These six are the sea-of-names' `bind $f.` lines, and they cost six new `data-bseq` rows in
the user guide — see §12.2.

### 5.4 Labels (R8)

| raw name | rendered | class |
|---|---|---|
| `v(vbg)` | `vbg` | net |
| `v(x1.adj)` | `adj` | net |
| `i(v1)` | `v1:i` | net |
| `i(v.x1.v1)` | `v1:i` | srcbranch |
| `i(@m.x1.xm1.msky130_fd_pr__nfet_01v8[id])` | `xm1:id` | devmeas |
| `i(@c.x1.c1[i])` | `c1:i` | devmeas |
| `v(m.x1.xm1.msky130_fd_pr__nfet_01v8#body)` | `xm1:#body` | devnode |

⚠⚠ **THE RULE BELOW REPLACES A WRONG ONE, AND THE CORRECTION WAS MEASURED, NOT ARGUED.**
The first draft of this section said "the instance half is the **last path segment**". That
contradicts this section's own table: `i(@c.x1.c1[i])` has last path segment `x1`, giving
`x1:i`, not the `c1:i` the table demands. Both candidate rules were run over all 2656
corpus names:

| candidate rule | reproduces the 7 rows above | label collisions **within one own-level node** |
|---|---|---|
| last path segment (as first written) | 6 of 7 | **29** (`n_diffamp` `xr1`, `test_analog`, `montecarlo_mismatch_sim`, …) |
| **the hybrid, below** | **7 of 7** | **4** |

**The rule.** For a device-classed signal the instance half is the **leaf's base** — unless
that base is *model-shaped*, in which case it is the **last path segment**. A base is
model-shaped when it contains `_`.

The asymmetry is not arbitrary: sky130 names the device *inside* a pcell wrapper after its
model (`msky130_fd_pr__nfet_01v8`), so there the wrapper `xm1` is the instance the user
drew. A discrete `c1`/`r1`/`q1` has no wrapper and **is** its own instance. One rule, two
shapes, because the corpus genuinely has two shapes.

The param half is the content of the **trailing** bracket (M9), or `i` when there is none.

⚠ **Strip one leading `@` from the instance half.** 25 of 2656 corpus names are untagged
single-segment `@`-forms (11 of them in `cmos_ac_sweep`), and `i(@ibias[current])` would
otherwise render `@ibias:current`.

If a per-class table is ever preferred to the `_` heuristic — `@m`/`@n` carry a model
segment, `@c`/`@r`/`@l`/`@b`/`@q` do not — it is a one-proc swap and nothing downstream
moves.

⚠ Only nine distinct params exist in the whole corpus: `[id]` 356, `[i]` 114,
`[current]` 11, `[vth]` 3, `[is]`/`[ie]`/`[ic]`/`[ib]` 2 each, `[vbe]` 2, `[gm]` 1. No
translation table is needed or wanted — the param is passed through verbatim.

⚠ **Two signals can render to the same label.** Measured over all 2656 corpus names, this
rule collides **exactly four times within one own-level node**, and all four are the same
shape: an element's `@`-form device measurement and its bare branch current render
identically — `i(@be5[i])`/`i(be5)` in `tb_bandgap_opamp`, `i(@l1[i])`/`i(l1)` and
`i(@l2[i])`/`i(l2)` in `tb_ft_test_2`, `i(@l1[i])`/`i(l1)` in `test_ac`. Pinned by TP19.

The batch plan claimed this rule collides **zero** times; it does not, and the correction
was made by re-running the measurement rather than by trusting it. Four is acceptable
because the label is a *display*, never an identity: every gesture resolves through the row
index into `browser_label_full`, the tooltip shows the raw name, and the status line counts
names rather than labels, so a collision stays visible.

⚠ **Cadence's exact spelling, for the record.** The prompt's `/I0/M1:d` exists in neither
Cadence namespace. The real forms are `/I0/M1/D` (schematic/OSS: leading slash, all slash)
and `I0.M1:d` (simulator/raw: dot hierarchy, colon terminal). R8 follows the **raw**
namespace, which is the one our names come from.

---

## 6. Filters (R11)

Two checkbuttons in the sidebar, each with its own namespace variable, each persisted.

| box | default | when unticked hides | `tb_bandgap` 424 → |
|---|---|---|---|
| Show device internals | **off** | `devnode` + `devmeas` | 190 |
| Show source currents | **on** | — | — |
| both restrictive | | `devnode` + `devmeas` + `srcbranch` | 140 |

Design nets only would be 139; the 140th is the sweep variable, which M8 leaves alone.

⚠ **The much-quoted "424 → 139" is wrong as a description of hiding device internals.**
It requires hiding source-branch currents *and* the sweep variable. Hiding internals alone
gives 190. `tb_charge_pump`: 1191 → 137 → 111, nets-only 110.

**Placement:** checkbuttons in `browser_build`, not options on `searchbar_build`. A
checkbutton uses `-command`, not `bind $f.`, so GH9's `bind $f.` count is unaffected by
them. The `-alldbs 1` precedent shows the searchbar route, but `searchbar_get` already
emits a conditional key and BAR11 pins the plain bar's dict to exactly four keys — a fifth
conditional key is blast radius for no gain.

**The filter applies where `browser_match` already narrows the snapshot**, so the tree, the
sea of names, the status line and every gesture see one consistent set — with the single
exception M6 carves out: the anypath flat-mode gate is computed on the **pre**-filter set.

---

## 7. Interactions the rulings do not state outright

Resolved here so nobody rediscovers them mid-implementation.

### 7.1 What the tree shows while a search is active

**Nothing changes.** R5 scopes both bars to the lower pane, so the tree's node set is
derived from the **unfiltered** inventory (minus R11's class filter, which is not a search).
A pattern that matches nothing leaves the tree intact and the sea of names empty.

The alternative — pruning the tree to nodes with surviving signals — was rejected: it makes
the navigation surface flicker under the user's fingers while they type, which is the
defect R5 exists to fix, merely relocated.

### 7.2 What the status line says

`"<shown> of <own-level> signals"` for the selected node, plus the All-DBs suffix as
shipped. Three states must be distinguishable, because they have different remedies:

| state | line |
|---|---|
| pure ancestor, no own-level signals | `x1.x2 has no signals of its own` |
| filter hid everything | `0 of 43 signals (the Search/Filter bar is hiding them)` |
| class filter hid everything | `0 of 43 signals (device internals are hidden)` |

The existing `browser_bars_active` already answers the middle case; the third needs its
twin.

### 7.3 Restoring a multi-selection saved by the shipped version

`browser_state` persists `sel` as a **list**, and BP10 pins the state dict's key set in
**order** (it is compared as a string). Under R4 the tree can only hold one selection.

**Rule:** `sel` stays a list — the key set and its order are untouched, so BP10, BP13,
BP45, MG9 and the snapshot gate all stay green. On restore, a list of more than one id is
**narrowed to its first element that still exists**; a list whose ids have all gone falls
back to the root. No key is added, no key is removed, no key moves.

### 7.4 R12's auto-tick and the replay log

`browser_state_apply` deliberately writes `dest` and `browser` **directly** rather than
through `set_plot_dest`/`browser_toggle`, because those `log_action` — a rebuild must not
fill the replay log with lines nobody typed.

R12's auto-tick is the opposite case: it *is* a user-initiated change, from a key the user
pressed. It goes through the normal toggle path and **is** logged. One keystroke, one log
line.

### 7.5 The tree node whose list is empty because of the class filter

Reachable: tick nothing, select a wrapper that survived because a descendant carries a real
net, and its own level may still be all-device. §7.2's third state covers it. The node is
**not** hidden — R1's rule is about the node's whole subtree, and the lower pane is about
one level.

### 7.6 `browser_leaf_names` is not modified

R6 keeps it recursive. The lower pane needs a *different* question answered — "the names at
exactly this level" — so it gets its own selector proc. Adding one reds nothing; changing
`browser_leaf_names` would red BT13, BM12, BT29 and BT32, and would break the one gesture
the driver explicitly asked to preserve.

---

## 8. Keys

### 8.1 Ctrl-L → Ctrl-B (R9) — overriding an in-source rejection

`src/wave_viewer.tcl:9288-9291` records, verbatim, that Ctrl-B was considered and rejected:

> ⚠ Ctrl-B WAS CONSIDERED AND REJECTED: 98 IS a graphkeys member, membership is
> unconditional on modifiers (see key_filter's note), the csv carries
> `key,98,ctrl,graph,graph.forward`, and callback.c toggles cursor B on 'b' — one keystroke
> would have done both.

Every word of that is still true. The ruling overrides it, and here is the whole cost:

* `key_filter`'s graphkeys arm (`:11130-11139`) already carries **exactly one** modifier
  carve-out, for Ctrl-D, because a forwarded Ctrl-D lands on a modal file dialog over a
  read-only viewer. Keysym 98 joins it:

  ```tcl
  set fwd [expr {!(($N == 100 || $N == 98) && ($s & 4))}]
  ```

* `src/keybindings.csv:23` (`key,98,ctrl,graph,graph.forward`) is **deleted**, and the file
  regenerated so `test_bindings_file.tcl:22-32`'s byte-identity check stays green.

* **Nothing user-visible is lost.** Verified in C: `src/callback.c:1647` handles `'b'` with
  **no modifier test at all**, so bare `b` still toggles waveform cursor B. Ctrl+b was only
  ever a duplicate of bare `b`. The driver's ruling, in their words: *"bare `b` is
  sufficient."*

* The **schematic** side is untouched — `case 'b'` under `ControlMask` toggles `sym_txt`
  (`src/callback.c:6035-6047`) and lives in the canvas context, which a WaveViewer bindtag
  binding cannot reach.

The change is otherwise a **pure rename** across 13 sites, so the guide's 16/11 counts do
not move (§12.2).

### 8.2 Ctrl-Alt-V (R10, R12)

**Nothing collides.** No Tk bind on any widget or tag for `Control-Alt-v`/`V`; no row in
the C input-binding table for keysym 118 or 86; `case 'v'` (`src/callback.c:6956-7016`) has
arms for `rstate==0`, `ControlMask` and `EQUAL_MODMASK` only, and `EQUAL_MODMASK` is an
**exact** test (`(rstate==Mod1Mask)||(rstate==Mod4Mask)`), so `ControlMask|Mod1Mask` matches
nothing. `parse_mods` already accepts `ctrl+alt`.

**Route: the C action registry**, Tcl-backed, following the `view.toggle_view_type` / Alt-2
template. That is the only route that satisfies "remappable" — a `bind .drw` in
`cadence_style_rc` is one line but is not in the table.

Four coordinated edits, and two tests that punish getting them out of step:

* `src/callback.c` — an `action_registry[]` row and an `init_input_bindings()` chord.
* `src/actions.csv` — one row. `test_keybindings_help.tcl:38-49` requires every dumped id
  (except `graph.forward`) to have one, or it renders as `(bare: <id>)`.
* `src/keybindings.csv` — **regenerated**, not hand-edited.
  `test_bindings_file.tcl:22-32` requires byte-identity with a fresh
  `save_input_bindings_file`, and `mods_name` emits its parts in the fixed order
  `ctrl+shift+alt+super` (`src/callback.c:5271`), so the row must read
  `key,118,ctrl+alt,canvas,<id>,`.
* `src/cadence_style_rc:245` and `src/xschem.tcl:14939` — the old Ctrl-5 bind and menu
  accelerator move to Ctrl+Alt+V.

⚠ **The guide gains no row for it.** BX13 (`_i12.tcl:338-341`) asserts that a *schematic*
key adds no `data-seq`/`data-menu` row to the **waveform viewer** guide, and Ctrl-5 is the
precedent it was written against. Keep it that way.

**Behaviour.** The "nothing selected" arm is already shipped, in full:
`ase::show_in_browser_for_current` (`src/ase.tcl:1054-1107`) is the only production caller
of `browser_show_path`. Its rung order is load-bearing and is not to be rearranged —
`hier_now` is read at `:1075` **before** `wviewer::open` at `:1087`, because opening the
viewer moves the xschem context and `sim_sch_path` read there answers about the viewer's own
untitled buffer.

The **new** capability is the selected-instance arm. It composes the pivot with the
selection:

```
target = hier_now()                       ;# the window's current descend path
if exactly one instance is selected:
    target = target + [selected instance name]
```

The instance name comes from the same `name=` token that `hier_resolve` compares against
(`new_prop_string()`, `src/token.c:795-833`), so the two agree by construction. More than
one instance selected, or a selection that is not an instance, falls back to the
nothing-selected arm — a reveal is a navigation aid, not a multi-target operation.

**R12's auto-tick** sits between the walk and the reveal: if the resolved node is absent
from the current row set *and* the class filter is why, tick R11(a), refresh, re-resolve,
and prefix the status message with `showing device internals to reach <node>`.

---

## 9. Persistence

`browser_state`'s dict gains **three new top-level keys**, appended after `hist`:

| key | holds | default |
|---|---|---|
| `sash` | the pane split as a **fraction** of the panedwindow's height | `0` |
| `devint` | R11(a), *show device internals* | `0` |
| `srccur` | R11(b), *show source currents* | `1` |

⚠ **Two riding-inside-an-existing-key schemes were considered and are WRONG.** Both were
killed by reading the code, not by taste:

* **`width` cannot carry the sash.** `browser_state` validates it with
  `string is integer -strict` and zeroes anything else (`src/wave_viewer.tcl:8101-8102`),
  so a `{450 0.4}` two-element list is silently discarded and the sash never persists —
  a silent-green failure of exactly the shape this subsystem has shipped twice.
* **`filter` cannot carry the checkboxes.** That sub-dict is `searchbar_get`'s verbatim
  output (`:10379-10399`), and BP10 pins it at exactly **4** keys.

So three new top-level keys it is, and their cost is paid explicitly:

| check | file:line | what changes |
|---|---|---|
| BP10 | `_i1315.tcl:781-782` | `[dict keys]` `{shown width search filter dest open sel hist}` → `{… hist sash devint srccur}`. **ORDER-SENSITIVE** — `browser_state_is_default` compares the dict as a **string**, so the three go on the end, in this order, in `browser_state_default` *and* in `browser_state`'s build. |
| BP13 | `_i1315.tcl:809-822` | seven counting fields → **ten**; `srccur`'s non-default value is `0`, not `1`. |
| BP45 | `_i1315.tcl:1224-1232` | eight `{NO-KEY}`-sentinel reads → **eleven**. |
| BP41 | `_i1315.tcl:1145` | a fresh window equals `browser_state_default` — still true, with the three new defaults. |

**MG9 stays green** and this is worth being exact about, because it is the one cross-file
check the batch does not own: `test_wave_modes.tcl:1314-1315` pins the **snapshot's** key
list (`{open sharedx rawfile graphs mode target}`), and `browser` is one *value* inside it.
Adding keys **inside** the `browser` dict does not change the snapshot's key list. BP42
(no `browser` key on a default window) and BP44 (`browser` is the LAST key when non-default)
are likewise untouched — but `browser_state_is_default` now has three more ways to be false,
so a window that ticks a checkbox and changes nothing else **will** start emitting a
`browser` key it did not emit before. That is correct, and BP02's "exactly one emission
site" check is what proves it did not grow a second one.

---

## 10. Declared limits

1. **A raw loaded after the sidebar was shown needs a re-show** (D6, inherited). Any new
   path that loads a raw must call `browser_refresh $token 1`.
2. **Two signals can render to the same label** (§5.4). Display, not identity.
3. **The sweep variable is an ordinary row** (M8). It sorts and filters like any other.
4. **Vector instance slices are not addressable by `Descend to here`** — issue 0212,
   unchanged. They *are* ten distinct, selectable tree nodes (M9).
5. **`Descend to here` on a device node** walks toward an instance that has a schematic
   only if the pcell wrapper has one. sky130's do; a bare primitive would not. It fails
   loudly through `hier_walk`'s readback, which is the correct behaviour, and is not
   specially handled.
6. **The lower pane renders empty for a pure ancestor** — 18 of 128 nodes in `tb_bandgap`.
   Correct, and §7.2 makes it legible.
7. **`Replace` appends under multi-plot** (ruling 24, inherited, surfaced not fixed).

---

## 11. Open issues touched

| # | what | this batch |
|---|---|---|
| **0186** | viewer context destroyed by reload / in-place loads | still OPEN; decision 13 still routes around it — browser state derives from `xschem raw list`, never from the rect model |
| **0212** | vector instance slices not addressable | unchanged; M9 makes them visible but not descendable |
| **0213** | malformed ASCII `Values:` overruns `read_raw_ascii_point` (**real C crash**, `src/save.c:406`) | unchanged. **Do not hand-write truncated `Values:` blocks in fixtures.** |
| **0214** | `readonly` cleared on a failed load | unchanged |
| **0215** | items 11/12 hierarchy sync asymmetry | unchanged |
| **0216** | `attach_raw` bypasses the raw history | unchanged |
| **0217** | device-class prefixes as fake hierarchy levels | **FIXED** by M1 |
| *new* | `browser_target_path` mis-decodes `d:N\|` All-DBs ids (§4.3) | **FIXED**, both sites |

Decision 8 ("no new C code") was **batch-scoped and has expired with that batch**. R9 and
R10 both touch C. That is a deliberate, ruled reopening — not a casual one — and it is
scoped to the input-binding tables. 0213 remains open and is explicitly **not** in scope;
this is the written disposition the teardown study asked for.

---

## 12. What must move in lockstep

### 12.1 Widget paths

`<top>.wvbrowser.tvf.tv` is spelled longhand at nine sites in `src/wave_viewer.tcl`
(`:6670, :6716, :6801, :7434, :7578, :7624, :7627, :8033, :8065`) — there is no accessor —
and `.wvbrowser` appears **73 times** across `tests/headless` and **22 times** in
`src/*.tcl`. The tree moves into the panedwindow, so every one of those nine moves.

**Introduce an accessor** (`browser_tree`, `browser_sea`) in the same item, and re-point the
nine. The test literals are docked paths and only move where the widget genuinely moved.

### 12.2 The doc oracles

| oracle | file:line | current | after |
|---|---|---|---|
| GH0 | `test_wave_grid.tcl:405-406` | 16 keys, 11 accelerators | **unchanged** — Ctrl-L→Ctrl-B is a rename |
| BT09 | `test_wave_sigbrowser.tcl:824` | the same 16/11 | **unchanged** |
| BX13 | `_i12.tcl:332-335` | reads `test_wave_grid.tcl` **as text** | **unchanged** |
| GH8 | `test_wave_grid.tcl:473-478` | 6 `data-bseq` gestures | **12** — the sea of names adds six |
| GH9 | `test_wave_grid.tcl:485-486` | 6 `bind $f.` in `browser_build` | **12**, in lockstep with GH8 |
| guide | `doc/waveform_viewer_guide.html:483-490` | `data-seq="Control-Key-l"`, `<kbd>Ctrl-L</kbd>`, `data-accel="Ctrl+L"` | Ctrl-B, plus six new `data-bseq` rows |

⚠ **16/11 is pinned in four places** — the guide, GH0, BT09 and BX13 — and BX13 reads
`test_wave_grid.tcl` as *text*. Keeping the key change a pure rename is what keeps all four
untouched, and it is the single cheapest decision in this batch.

### 12.3 The parent spec

GS1 (`test_wave_grid.tcl:535-538`) requires every line in
`doc/claude/specs/waveform_signal_browser.md` matching `^- \`wviewer::([a-z0-9_]+)\`` to
resolve to a real proc. **A contract entry for a proc that does not exist yet reds GS1.**

Therefore: the parent spec's contract entries land in the **same commit** as their procs,
never ahead of them. GS2's hard-coded 23-name list must all keep appearing; none of them is
deleted by this batch.

---

## 13. Test footprint

Ruling 30 stands: **every design-window-coupled item gets its own process.** At 489 checks
one file was killed mid-run by WSLg ~90% of the time with **zero check failures** — a
failure mode that looks exactly like flakiness and is not.

Baseline, re-measured and green: `--nogui` 660 checks across seven files (sigsearch 107,
sigbrowser 135, i11 50, i12 29, i1315 80, i14 47, grid 212).

Keep every file under ~150 checks. `wvbs_common.tcl` stays **deliberately not** named
`test_*.tcl` — `full_audit.sh` globs `test_*.tcl`, and a prelude with that name runs as a
case, reports zero checks, prints no `RESULT` line and scores FAIL forever.

**The two test-design rules this subsystem paid most for:**

1. A negative check is worthless without a proven positive control on the same fixture, and
   you find that out by **running the sabotage** — never by reasoning about whether the
   check would catch it. Five vacuous checks shipped and were caught this way.
2. **A check that throws is a check that deletes evidence.** An unguarded read threw into
   the file's outer catch and silently aborted 51 later checks while the printed fail count
   still looked plausible. Make "the thing I am reading is gone" an *assertable value*,
   distinct from "present but empty".

---

## 14. Corrections this spec makes to existing docs

Apply when next editing the files named.

1. **`signal_browser_declass_class_toggle_work_order.md` §2.2** — the device-node
   percentages are wrong in 4 of 5 rows. Re-running the doc's own verbatim awk:
   `tb_bandgap` 78/128 = 61% ✓; `tb_charge_pump` 278/316 = **88%** (doc says 89%);
   `tb_bandgap_opamp` 33/38 = **87%** (doc 92%); `sky130_oscillator` 34/46 = **74%**
   (doc 78%); `test_analog` 18/28 = **64%** (doc 79%). The raw counts are right.
2. **`0217:129`** names `tests/headless/test_ase_hier_pick_0161.tcl` as affected by the
   declass fix. **It is not** — that file calls no `wviewer::` proc; it merely contains the
   literal `i(v.x1.x2.v1)` as an ASE pick-naming expectation produced by ASE's own naming
   code.
3. **`0217:44`** — "100% leaf contains `#`" is true forward, **false backward** (§3.2).
4. **`signal_browser_declass_class_toggle_work_order.md` §3** — "browser session state
   (`:8105-8143`)" drifted: `browser_state` is at `:8093`, `browser_state_apply` at `:8134`.
   And "BAR11 pins the plain bar's dict … (`:6611`)" cites a *comment* inside
   `browser_alldbs`; the real contract is `searchbar_get` (`:10379-10399`) and the check is
   `test_wave_sigsearch.tcl:1181-1183`.
5. **`browser_show_path`'s root return.** The header comment (`:7596`) and the parent spec
   (`:667`) both promise `{root <asked>}`; `browser_say`'s root arm hardcodes
   `[list root {}]` (`:7734`) and the caller passes `browser_say $token root {} {} {}`
   (`:7641`). The test pins the **actual** value (`_i12.tcl:459`), so fixing the code reds a
   green test. **Fix the docs, not the code** — the value is load-bearing nowhere.
6. **The derived sidebar width** is quoted as 583 px in source (`:6479`, `:7755`) and 668 px
   in `next_session_signal_browser_hierarchy.md:75`. Neither is a literal in code — the
   expression is evaluated live — so neither is authoritative and neither should be quoted
   as "the" base.
7. **`signal_browser_reference.md`** §1, §9 and the "~3 in 10" at `:100` remain known-wrong;
   the corrections are in `signal_browser_teardown_scoping.md` §7-F. The loan does **not**
   fail 3 times in 10 — it fails deterministically under a raised semaphore
   (`src/xinit.c:1833`) and never otherwise: 0 refusals in 300, 10 of 10 with the semaphore
   raised.
8. **`signal_browser_reference.md:142`** says "214 of the browser's checks run in the
   `--nogui` arm". Stale rather than wrong: `135 + 50 + 29 = 214` was exactly the three
   files that existed when the line was written. It is **448** across all six browser files
   today, 660 including `test_wave_grid.tcl`.
