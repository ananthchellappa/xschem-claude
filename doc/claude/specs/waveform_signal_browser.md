# The Waveform Viewer's Signal Browser

Status: **SPEC** — as-built. Signal Browser batch, `doc/claude/signal_browser_batch/PLAN.md`
(items 1-16), receipts `doc/claude/signal_browser_batch/receipts/`.

Related:
`doc/claude/specs/waveform_viewer.md` · `doc/claude/specs/waveform_viewer_modes.md` ·
`doc/claude/specs/waveform_viewer_tabs.md` · `doc/claude/specs/wave_trace_hilight.md` ·
`references/viva_cadence_waveform_viewer.md` §13 item 1 (the upstream feature this ports)
· `doc/waveform_viewer_guide.html` §11 (the user-facing page).

---

## 0. What this document is, and why it exists in this shape

The Signal Browser is a port of Cadence ViVA's signal browser + search box onto the xschem
waveform viewer. `references/viva_cadence_waveform_viewer.md` describes the **upstream**
feature. This document describes **what shipped**, and — far more importantly — **the
places where the port deliberately or necessarily differs, and the measurements that
forced each difference.**

Roughly a third of what follows contradicts the plan the batch started from. Every such
correction below was *measured against a running binary*, not reasoned about. Where a
statement is a measurement it says so, with the numbers. Where it is a policy choice it
says so, with the alternative that was rejected. **A reader who trusts only the parts
marked MEASURED will still be right about everything load-bearing.**

There is no upstream document for §10 (hierarchy sync): ViVA has no documented equivalent
of "put the schematic where the browser is". This spec is the only record.

---

## 1. The shape of the thing

A left sidebar inside the waveform viewer's own toplevel, top to bottom:

```
+-- $top.wvbrowser --------------+---------------------------------+
| [ .../bd_a.raw  v] [Browse...] |                                 |
| [All v][pattern ][Shell v][ ]  |                                 |
|        Match case [ ] All DBs  |          the canvas             |
|                     [Search]   |          ($top.drw)             |
| [Plot]                         |                                 |
| +- tree -------------------+   |                                 |
| | v bd_a.raw (tran)        |   |                                 |
| |   v x1                   |   |                                 |
| |     v x2                 |   |                                 |
| |       v(x1.x2.net5)      |   |                                 |
| |   v(out)                 |   |                                 |
| +--------------------------+   |                                 |
| [All v][filter ][Shell v]...   |                                 |
| Signal Browser (14 signals)    |                                 |
+--------------------------------+---------------------------------+
```

* **Location bar** (item 13) — which `.raw` is loaded, with a 20-deep history.
* **Search bar** (items 4, 14) — the primary filter, with the All-DBs scope box.
* **Plot toolbar** (item 9) — one button; the destination lives in the context menu.
* **Tree** (items 8, 9) — hierarchy groups plus signal leaves.
* **Filter bar** (item 9) — a second, button-less search bar; ANDed with the first.
* **Status line** (items 8, 9) — counts, and decision 4's second error surface.

---

## 2. Settled decisions

The batch settled 31 rulings; the ~16 below are the ones that are **design** rather than
process. Each is SETTLED — a later change needs a new ruling, not a code review.

| # | Decision |
|---|---|
| 1 | The browser is a **left sidebar inside the viewer toplevel**, `$top.wvbrowser`, packed `-side left -fill y -before $top.drw` (§6). |
| 2 | **The match subject is the FULL raw name**, `v(out)` — never the stripped `out`. The type filter derives from the `v(`/`i(` prefix, so stripping would destroy the information the type dropdown needs. Governs every new surface. **One exception: ruling 16 (§4).** |
| 3 | **Wildcards are whole-name anchored**, per ViVA. Shell: `string match` is already whole-string. RegExp: wrap as `^(?:$pat)$`. |
| 4 | **An invalid regexp is an ERROR shown in the search bar, not a silent match-all.** |
| 5 | **Search is live-as-you-type AND has a Search button.** |
| 6 | **Default is case-INsensitive** (`Match case` off), matching ViVA. |
| 7 | **Default syntax is `Shell`**, matching `viva.filter textFilterType string "shell"`. |
| 8 | **No new C code.** A C defect found in scope is FILED and ROUTED AROUND, never patched (§15: 0212, 0213). |
| 10 | **Hierarchy sync pivots on `xschem get sim_sch_path`**, never `sch_path` (§10). Name-addressed (`descend -inst`), never coordinate- or index-addressed — which makes a sync replayable in the action log for free. |
| 11 | **A failed sync ROLLS BACK**, and **neither direction ever fails silently.** |
| 13 | **Browser state derives from `xschem raw list` / `xschem raw`, NEVER from the rect model** — issue 0186 is open and blanks the document under a CIW `xschem reload`. |
| 14 | **`signal_list`'s `path`/`leaf` split the UNWRAPPED name** (§5). |
| 16 | **The legacy `.graphdialog` matches the STRIPPED name** — the one exception to decision 2 (§4). |
| 17 | **Where a claim and its coverage disagree, WIDEN THE COVERAGE OR NARROW THE CLAIM — never neither.** A check NAME that overstates what it pins is itself a defect. |
| 20 | **The search bar KEEPS its Search button**; `-showbutton 0` is the Filter-bar variant. |
| 24 | **`wviewer::plot_dest <token>` is THE destination accessor.** Nothing re-implements the policy. |
| 30 | **Every design-window-coupled item gets its own test process** (§16). |

---

## 3. Divergences from ViVA, and why

### 3.1 Whole-name anchoring, and the glob features Cadence never documented

ViVA anchors its wildcards to the whole name. The shell arm gets that for free —
`string match` is whole-string — and the regexp arm gets it by wrapping the user's pattern
as `^(?:$pat)$`.

A side effect worth stating: xschem's shell mode is **Tcl's `string match`**, so it also
supports `?` (one character) and `[a-z]` ranges. ViVA documents only `*`. These are extra
capability, not a compatibility break, and they are documented in the user guide.

### 3.2 An invalid pattern is an ERROR, not "show everything"

`src/xschem.tcl` records the legacy behaviour this replaces, in the block comment headed
`THE MATCH SUBJECT IS THE STRIPPED NAME`: the old Graph dialog did
`if {$err} {set pattern {}}`, so a typo in a regexp **widened into "show every signal"**.
For a search box that is the worst possible failure — the user gets a plausible-looking
full list and no indication anything went wrong.

`wviewer::sig_match` returns `{err {message}}` instead. The message is displayed in the
bar's error label **and** mirrored into the browser status line, because the label clips
(§7, declared limit D1).

### 3.3 Live-as-you-type AND a Search button

ViVA is click-to-apply only, because its databases are huge. xschem's sweep is
sub-millisecond over a raw file's variable list, so live filtering costs nothing.
Decision 5 ships **both**, and the button is not decoration — it is the affordance a user
coming from ViVA reaches for.

**The button charges a real price, and it was measured.** One `searchbar_build` wants
**755 px** (680 with `-showbutton 0`). At the derived sidebar width the Search button is
mapped but the error label is not (§7). Keeping the button and clipping the label was the
choice; re-laying out the bar would have needed a `[D]`.

### 3.4 The match subject is the full raw name

Decision 2. `v(out)`, not `out`. The type dropdown reads the `v(`/`i(` prefix off the same
string the pattern matches, so there is exactly one subject and the two can never disagree.

### 3.5 ⚠ ViVA's unit-collision rule is PERMANENTLY NOT IMPLEMENTABLE

ViVA refuses to overlay traces whose units disagree (volts on an amps axis). **xschem has
no unit metadata at all.** `read_dataset` (`src/save.c`) discards ngspice's per-variable
type field when it parses a `.raw`; nothing downstream ever sees it, and no other code path
carries it either.

**This is a permanent divergence, not a TODO.** Implementing it means changing the raw
reader in C to retain and expose the per-variable type — a different piece of work with a
different blast radius. Anyone tempted to add a unit rule must start there.

### 3.6 `@`-form terminal currents classify as `other`

`wviewer::sig_type` implements decision 2's contract verbatim: classify on a leading `v(`
or `i(`. ngspice's `@m.x1.m1[id]` terminal-current form therefore classifies **`other`**,
while the neighbouring `ase::ui::output_kind` (`src/ase_window.tcl`) calls a leading
`@` a *current*.

**Two classifiers in this codebase disagree about `@`, on purpose and visibly.** A real raw
carries `@`-form currents, so a user picking **Current** in the type dropdown will not see
them; they appear under **Other** and under **All**. Declared, pinned by a check, and left
as it is — widening `sig_type` would have made the browser's dropdown disagree with the
matcher's `-type` filter, which is the thing decision 2 exists to prevent.

---

## 4. The legacy `.graphdialog` exception (ruling 16)

The Graph dialog's signal-list filter was retrofitted onto the shared matcher — find it in
`src/xschem.tcl` by the comment `The Graph dialog's signal-list filter, retrofitted onto the
shared matcher`. **It keeps matching the STRIPPED name** (`out`, not `v(out)`), which is the
ONE exception to decision 2. Three deltas were found when the retrofit landed:

| delta | resolution |
|---|---|
| 1. subject was the stripped name | **REVERSED into the ruling** — the legacy dialog keeps the stripped subject; changing it would silently break every saved workflow that types `out`. Recorded verbatim in that proc's header comment, item (a). |
| 2. unanchored substring match | **REVERSED** — the dialog now anchors like everything else. |
| 3. ARE directors / embedded options became an ERROR | **ACCEPTED as a ruled divergence.** |

**Delta 3 in full**, because it will look like a bug to somebody: Tcl's ARE directors
(`***=foo`) and embedded options (`(?i)x`) are legal **only at the very start of a regular
expression**. Wrapping the user's pattern as `^(?:$pat)$` puts them in the middle, where
they raise *"quantifier operand invalid"*. So `(?i)foo` gets an error instead of a
case-insensitive match.

This is **inherent to wrapping the user's pattern at all** — i.e. inherent to decision 3.
The supported way to ask for case-insensitivity is the `Match case` box / `-case 0`.
**Do not file this as a bug.**

---

## 5. Widget and proc contracts, as shipped

Signatures read from `src/wave_viewer.tcl` at ship time. `test_wave_grid.tcl`'s GS0-GS2
legs assert this list against the source in both directions, so a rename here that is not a
rename there turns the suite red.

### The matcher and the inventory

- `wviewer::sig_type` — `{name}` -> `v` | `i` | `other`, on a leading `v(` / `i(`
  (case-insensitive). See §3.6 for the `@` divergence. THE one classifier; the browser's
  dropdown and `sig_match -type` both call it, so they cannot drift.
- `wviewer::sig_match` — `{siglist pattern args}` -> `{ok {names}}` | `{err {msg}}`.
  Options: `-syntax shell|regexp` (default `shell`), `-case 0|1` (default `0` =
  case-INsensitive), `-type all|v|i|other` (default `all`), `-sort 0|1|-1` (`0` = raw order,
  default). `siglist` is a **Tcl list, not a newline blob** — splitting `xschem raw list` is
  `signal_list`'s job, in one place. The pattern is **never trimmed and never eval'd**: it
  reaches `string match` / `regexp` as data only, so a leading `-` or a `[` cannot become an
  option or a command substitution. An **empty pattern matches everything** and that is
  CODED as a short-circuit, not inherited — `string match {} x` is 0.
- `wviewer::sig_bare` — `{name}` strips ONE `<fn>(...)` wrapper: `v(x1.x2.net5)` ->
  `x1.x2.net5`. **For path/leaf splitting only** (ruling 14); nothing here feeds `sig_match`.
- `wviewer::sig_declass` — `{bare}` -> `{class rest}`. Strips ngspice's device-class tag
  from an **unwrapped** name: `m.x1.xm1.mod#body` -> `{m x1.xm1.mod#body}`. `class` is `{}`
  and `rest` is the input unchanged when there is no tag. **Rule:** first segment matches
  `^@?[a-z]$` case-insensitively **AND at least two segments follow**. Issue 0217.
- `wviewer::sig_class` — `{tag}` -> `net` | `devnode` | `devmeas` | `srcbranch`. THE one
  classifier, and it keys on the **tag**, never on the leaf's shape (see the ⚠ below).
- `wviewer::sig_split` — `{name}` -> `{path leaf}`, split on the LAST dot of the **UNWRAPPED,
  DECLASSED** form.
- `wviewer::signal_entry` — `{name}` -> `{name type leaf path class}` for one raw name.
- `wviewer::signal_list` — `{token}` -> list of those dicts, for the token's **current** raw.
  Returns `{}` — never throws — when the token is unknown, when the context switch is
  REFUSED, or when there is no raw. "Nothing to browse" is an ANSWER.
- `wviewer::signal_list_all` — `{token}` -> every loaded results database's inventory,
  current one FIRST: `{{idx .. path .. type .. cur 0|1 label .. names {..}} ...}`. §11.
- `wviewer::rawinfo_parse` — `{text}` -> `{cur <n> dbs {{idx .. path .. type ..} ...}}`.
  PURE; parses `xschem raw info` per LINE (§11).
- `wviewer::db_label` — `{path type}` -> the tree header for one database, e.g.
  `bd_a.raw (tran)`. PURE.

⚠ **Ruling 14, stated because it is the one contract people get wrong.** `path`/`leaf`
split the **UNWRAPPED** name. `v(x1.x2.net5)` gives `path x1.x2`, `leaf net5`. Taken
literally against the full raw name it would give `path v(x1`, `leaf net5)` — **which is
why item 9's tree never grows a node called `v(x1`.**

⚠ **Ruling 14's ONE amendment (issue 0217).** The class strip is a step *before* the split,
not instead of it — `path`/`leaf` still split the unwrapped name, they just split it after
`sig_declass` has removed a leading device-class tag. Ruling 14 exists so the tree never
grows a root node called `v(x1`; the strip exists so it never grows one called `m` either.
MEASURED across 22 real ngspice-46 raws: **2026 of 2338 hierarchical signals — 87% — filed
under a fake root** (`m` 1400, `@m` 360, `v` 155, `@c` 61, `@r` 24, `@b` 15, `@q` 10, `n` 1)
before the strip landed. `tb_bandgap`'s netlist has exactly **one** subcircuit instance.

⚠ **`sig_class` keys on the TAG, never on the leaf's shape.** Issue 0217:44 records "100% of
device leaves contain `#`". That is true forward and **false backward**: six *real design
nets* end in `#` — xschem's auto-generated net names, e.g. `v(x2.x1.a_27_47#)` in
`tb_charge_pump`. A classifier keyed on "the leaf contains `#`" misfires on all six. Pinned
by DC25 **with a positive control on the same fixture** (the identical leaf shape *with* a
tag must still classify `devnode`, or the check proves nothing).

### The destination

- `wviewer::plot_dest` — `{{token {}}}` -> `append` | `replace` | `newstrip` | `newtab`.
  **THE destination accessor** (ruling 24): the Add Trace dialog, `plot_signals` and the
  browser's three plot gestures all call it, and nothing re-implements the policy.
  ⚠ It **DEFAULTS to `append`** for an unset or unknown token rather than returning `{}`,
  and that is deliberate: a caller asking about a window that is not there must get the
  **harmless** policy, never one that destroys traces.

### The search bar megawidget

- `wviewer::searchbar_build` — `{parent args}` -> the frame path (default `$parent.wvsearch`).
  Options `-command`, `-showbutton 0|1`, `-name <child>`, `-alldbs 0|1`. `-command` fires as
  `<cb> <pattern> <syntax> <case> <type>` — the last three **already in `sig_match`'s codes**
  — on every live keystroke, on either dropdown's selection, on the Match-case toggle and on
  the Search button. `-showbutton 0` **omits** the button (it is not merely unpacked, so
  `winfo exists $w.search` is a truthful test of the variant); that is the **Filter-bar
  variant**, decision 20. `-alldbs 1` adds the All-DBs scope box; the bar itself does
  nothing with the value — scoping is the consumer's business.
  Widget order is ViVA §3.2's: `[type][pattern][syntax][ ]Match case [ ]All DBs [Search] <err>`.
- `wviewer::searchbar_get` — `{w}` -> `{pattern .. syntax .. case .. type ..}`, and
  ⚠ **`alldbs` is a CONDITIONAL FIFTH KEY** present only on a bar built `-alldbs 1`. The
  shipped contract is that this dict has exactly the four (`test_wave_sigsearch.tcl` BAR11
  pins it), so every consumer reads the fifth with `dget ... alldbs 0`. Returns `{}` for a
  widget that is not a live search bar — callers poll it from `after` handlers and snapshot
  code, where a hard error on a torn-down widget is the wrong answer.
- `wviewer::searchbar_set` — `{w d}` -> 1/0. `searchbar_get`'s inverse; get/set compose to
  an identity. **Missing keys fall back to the DEFAULTS, not to "leave it alone"** — a
  restore of a dict that predates a field must leave a fresh bar's state, not the previous
  session's residue.

### The sidebar

- `wviewer::browser_build` — `{token top}` builds the sidebar **HIDDEN**, and it is out of
  `open` for the same reason `tabbar_build` is: a viewer that never opens the browser keeps
  its canvas geometry **byte-identical** to the pre-browser viewer, which every
  viewport-derived assertion in the wave suites depends on.
- `wviewer::browser_show` — `{token}` packs/unpacks it. **SHOW = REPOPULATE** (§6, D6).
- `wviewer::browser_toggle` — `{{want {}} {token {}}}` -> the NEW state, or `{}` plus a CIW
  error. `{}` inverts, `0`/`1` set. Returns early when the state already matches — which is
  why an already-shown sidebar is deliberately not repopulated by item 12's command.
- `wviewer::browser_width` — `{token {want {}}}`. §6. **The width is derived, not fixed.**
- `wviewer::browser_rows` / `_reparent` / `_multi` — the tree model. §8.
- `wviewer::browser_menu_build` — `{token ids}` — the RMB menu. §9.
- `wviewer::browser_state` — `{token}` -> the persistence dict. §13.
- `wviewer::browser_state_apply` — `{token d}` -> 1/0. §13.

### The Location bar

- `wviewer::rawbar_load` — `{token path}` -> 1 on success, 0 on every refusal, and **every
  refusal leaves the previous raw AND the tree exactly as they were.** §12.
- `wviewer::rawbar_commit` — `{token}` — the ONE commit path: `<Return>`,
  `<<ComboboxSelected>>` and `Browse...` all end here, so no route can apply a policy
  another route skips.
- `wviewer::attach_raw` — `{token rawfile sim_type}` — the **ASE re-run** attach path.
  §12, declared limit L-13a: it does NOT enter the raw history.

### Hierarchy sync (item 11's four primitives)

- `wviewer::hier_split` — `{p}` -> segment list. **THE trailing-dot normaliser**: `x1.x2.`
  -> `{x1 x2}`, `` -> `{}`. §10.
- `wviewer::hier_common` — `{a b}` -> length of the **BYTE-exact** common prefix.
  ⚠ Deliberately NOT case-insensitive. §10.3.
- `wviewer::hier_plan` — `{cur target}` -> `{<levels to ascend> <segments to descend>}`. PURE.
- `wviewer::hier_same` — `{a b}` -> the **`-nocase`** final-verify comparator. §10.3.
- `wviewer::hier_now` — `{}` -> where the current xschem context sits, as a segment list.
  **THE ONLY PIVOT READ IN THE FEATURE**, and it never throws. Reads `sim_sch_path`;
  `sch_path` is forbidden here (decision 10).

---

## 6. The sidebar: packing and width

### Packing

```tcl
pack $f -side left -fill y -before $top.drw      ;# src/wave_viewer.tcl, browser_show
```

The `-before $top.drw` is the **`readout_show` idiom** and it is load-bearing. The canvas is
already packed with `-fill both -expand 1`; a plain `-side left` afterwards puts the sidebar
**after** the greedy slave in packing order, and the packer gives it whatever is left —
which is nothing. `-before` inserts it ahead of the canvas in the packing list, and the
canvas then expands into the remainder.

The editor's own toolbar wants the same left slot (`pack $topwin.toolbar -side left -fill y
-before $topwin.drw`, `src/xschem.tcl`), but `open` already `pack forget`s it per window and
nothing re-shows it in a viewer, so the two left bars cannot stack today.

### ⚠ The width is DERIVED, not a constant

`wviewer::browser_width`:

```
w   = reqwidth($f.wvsearch) - reqwidth($f.wvsearch.err)     ; the base
w   = want                                                  ; item 15 override, if positive
cap = int(0.45 * winfo width $top)   ; if w > cap, w = cap
                                     ; if w < 240, w = 240
pack propagate $f 0                  ; so an over-wide child CLIPS, never widens
```

**Do not read "the sidebar is 583 px" out of this document.** 583 px was the **measured
result at a 1400 px toplevel** — 42% of the window, inside the 45% cap by design. At any
other window size the derivation gives a different number. The cap and the floor are the
contract; 583/1400 is the measurement that demonstrated it.

The subtraction of the error label's reqwidth is what buys the fit: one search bar wants
755 px, the error label 172 of them, and the remainder is what actually has to be usable.

### ⚠ D8 — `update idletasks` before measuring, and the bug it fixed

MEASURED: a frame's `reqwidth` is computed by the packer **on the idle queue**. Straight
after `pack $f`, `winfo reqwidth $f.wvsearch` still reports **1**, so `755 - 172` evaluated
as `1 - 1 = 0` and the **240 px floor** took over:

```
top w=1400  sidebar w=240   <- the FLOOR, not the intended 583
search x=0 w=1 mapped=0     <- decision 5 silently defeated
```

One `catch {update idletasks}` before the measurement fixes it:

```
top w=1400  sidebar w=583  canvas w=817
search x=502 w=69 mapped=1     <- decision 5 honoured
err    x=577       mapped=0    <- DECLARED LIMIT D1
```

**The second-order effect is the more instructive one.** With the sidebar collapsed to
240 px the search entry was clipped off-screen, and **Tk would not deliver a synthetic
`<KeyRelease>` to it at all** — so the live-filter checks failed with the tree simply not
changing, which reads exactly like "the callback is not wired". *A pixel bug masquerading
as a logic bug.* Anyone debugging "the browser's live filter does not fire" should check
the geometry first.

Idle tasks only, never `update`: this is a gesture path, so nothing re-enters.

### ⚠ D6 — SHOW = REPOPULATE; the inventory is a SNAPSHOT

`browser_show`'s pack branch calls `browser_refresh $token 1`. The signal inventory is a
**snapshot taken when the sidebar is shown**, not a live read. That is what makes a
keystroke in either bar cost **no context loan** — the issue-0173 enter/leave bracket is
taken once per show, not once per character.

Consequence, declared: a raw loaded by some other route while the sidebar is already
visible does not appear until a re-show. The Location bar (§12) closes this for its own
loads by calling `browser_refresh` itself.

---

## 7. The Search bar and the Filter bar

Two `searchbar_build` instances in one sidebar:

| | child | button | All DBs | callback |
|---|---|---|---|---|
| **Search** (top) | `$f.wvsearch` | yes (decision 20) | yes (`-alldbs 1`) | `browser_search_cb` |
| **Filter** (bottom) | `$f.wvfilter` | no (`-showbutton 0`) | no | `browser_filter_cb` |

They are **ANDed**: `browser_and` intersects the two match sets. The Filter bar narrows a
list that has already been fetched, which is why a DB scope there would mean nothing — and
two All-DBs boxes would be two answers to one question.

### ⚠ D1 — the error label is clipped, and the message is mirrored

The bars are wider than any sane sidebar: 755 px with the button, 680 without (type 97,
pat 204, syntax 87, case 92, search 69, err 172, plus padding). At the derived 583 px the
**Search button is mapped (x=502) and the error label is NOT (x=577, `ismapped 0`)**.

Decision 4 — "an invalid regexp is an error, not a silent match-all" — would therefore have
been *invisible*, which is the same failure it exists to prevent. It survives because the
message is **mirrored into the browser status line** at the bottom of the sidebar, which is
inside the visible width.

`$w.err` carries a fixed `-width 24` and no `-expand`, so its requested width is the same
whether the message is empty or 200 characters. That is the mechanism behind "the error
label does not resize the bar": a long message **clips** rather than pushing `Search` off
the end. The clip budget is deliberate. If a consumer ever needs the full text in the bar,
the right answer is a tooltip, not an elastic label.

---

## 8. The tree

`$f.tvf.tv`, a `ttk::treeview -show tree -selectmode extended`.

Row ids: **`g:<dotted path>`** for a hierarchy group, **`s:<name>`** for a signal leaf
(disambiguated with a `#N` suffix when a name repeats — which is why a leaf's path is
resolved through the ROW's stored `name`, never through its id). A group id **IS** the
dotted instance path, which is what item 11 descends on.

Groups come from `sig_split`'s `path`, one node per dot segment (decision 14). Under
All-DBs the whole tree gains a per-database header level, `db_label`'d as
`bd_a.raw (tran)` — parenthesised deliberately, because a design-hierarchy instance name
contains neither a space nor a bracket, so a header can never be mistaken for a hierarchy
segment by `browser_node_for`.

### ⚠ D3 — a double-click on a GROUP does not plot

ttk's own expand/collapse owns `<Double-Button-1>` on a group row. The browser's
`<Double-Button-1>` binding therefore passes `groups 0` and plots leaves only. **MMB
(`<Button-2>`) and the `Plot` button do plot a group's leaves.**

This is a LIMIT, not a defect: fighting ttk for that gesture would cost group
expand/collapse, which is worth more. The asymmetry is asserted in both directions so the
zero is a rule rather than a dead recorder.

Relatedly, none of the tree's bindings needs a `break` to keep xschem's canvas bindings
out. MEASURED: the bindtags of a treeview inside a viewer toplevel are
`{<tv> Treeview <top> all}` — **the canvas is not among them** (`set_bindings` binds
`win_path`, not the toplevel), the toplevel carries only Expose/Visibility/FocusIn, and
`bind all` has nothing relevant. The `break` on `<Button-3>` and `<Key-E>` is **defence in
depth against a future toplevel-level binding, not the mechanism.**

⚠ This directly overturned a plan rationale (ruling 28): 0178's "Button3 swallow" argument
does **not** transfer from a canvas to a `ttk::treeview`, and the premise behind a whole
planned item was false.

### ⚠ D7 — "row order" means RAW-FILE order, not the tree's visual order

ttk **re-parents a late arrival under the group it belongs to**. A raw listing
`v(x1.x2.n) v(x1.y3.n) i(x1.x2.n)` therefore **draws** the two `x1.x2` leaves adjacent,
while `browser_leaf_names` still returns them first-and-last. **Plotting a group plots in
raw order**, which is not the order the user sees.

Stated rather than papered over, and the check that pins it says "in raw order" — because a
check named "in order" would overstate what it measures (ruling 17).

---

## 9. The context menu (RMB)

`browser_menu_build` builds it; `browser_menu_post` posts it in **root** coordinates.
Entries: `Plot (<destination>)`, a destination cascade, Copy names, Send to Add Trace,
`Descend to here`.

### ⚠ `Replace -> appends` is a DELIBERATE SURFACING, not a typo

Under **multi-plot**, `replace` clears nothing. That is structural: `plan_plot`'s multi arm
lands every signal either in a strip it CREATES or in a REUSED EMPTY strip, never on an
occupied one, so there is by construction nothing for `replace` to clear. The `clear` key
is still emitted (the shape tracks the destination) but is **always empty**, and Replace is
behaviourally identical to Append there.

Item 7 declared the limit. Item 10 **put it in the menu label** rather than hiding the
entry:

```tcl
if {$code eq {replace} && [wviewer::plot_mode $token] eq {multi}} { append lab { -> appends} }
```

Removing the entry instead would have made the cascade disagree with the Add Trace dialog's
dropdown, which offers all four. **Both** the top `Plot (...)` entry and the cascade's
Replace entry take their label from the one `dest_menu_label`, so the two can never drift.

Making Replace mean "wipe the whole plot area" under multi would be a *different policy*
from "clear the target graph's traces first", which is the one item 7 was given. Changing
it is a new decision, not a bug fix.

---

## 10. HIERARCHY SYNC

Two commands, mirror images:

* **`Descend to here`** (item 11) — browser row -> put the *schematic* there.
  `Key-E` on the viewer canvas and on the tree; View menu; RMB menu.
* **`Show in Signal Browser`** (item 12) — schematic position -> select and scroll the
  *browser* node. `Ctrl-5` on `.drw` (`src/cadence_style_rc`); design window Tools menu
  (`src/xschem.tcl`).

**ViVA has no documented equivalent.** There is no upstream doc to fall back on, and the
plan the batch started from was **wrong about all six points below.** Each correction was
measured.

### 10.1 ⚠ The pivot is `sim_sch_path`, and `sch_path` is WRONG

`xschem get sim_sch_path` (`src/scheduler.c`, the `sim_sch_path` arm) computes
`path = xctx->sch_path[currsch] + 1` and then runs a **skip loop seeded by
`sch_waves_loaded()`** — i.e. it strips the levels above the schematic the raw was read at.
It is **sim-root-relative**. MEASURED on `tests/headless/fixtures/wvhier`, `currsch` 2,
`sch_path` fixed at `.X1.X2.`:

| `raw_level` | `sim_sch_path` |
|---|---|
| 0 | `X1.X2.` |
| 1 | `X2.` |
| 2 | `` (empty) |

The raw file's own signal names (`v(x1.x2.net5)`) are measured from the **sim root**, so
`sim_sch_path` is the only getter that speaks the same coordinate system. `sch_path` is
**absolute**; using it puts the sync one or more levels off — **silently and plausibly**,
which is the worst kind of wrong.

### 10.2 ⚠ THE ARM NO TEST CAN REACH

**With no raw loaded, the two getters are BYTE-IDENTICAL.** `sch_waves_loaded()` is `-1`,
so the C skip loop never runs and `sim_sch_path` degrades to `sch_path` minus its leading
dot.

Consequences, all real:

* **No behavioural test can distinguish decision 10 on that arm.** The guard is therefore a
  **SOURCE check** (grep the implementation for `sch_path`), not a value check. That is not
  laziness; it is the only oracle that exists.
* Item 11's plan-named sabotage — swap `sim_sch_path` for `sch_path` — **did not fire at
  all** until the fixture was given `xschem raw new` + `xschem set raw_level 1`. A sabotage
  can be a no-op against correct code and prove nothing (ruling 23).
* It is also the reason `hier_origin_ok` exists (§10.7): the degraded getter is *correct*
  exactly when the design window's top IS the session's design, and when it is not, **the
  pivot and the verify share the same wrong origin**, so the walk lands N levels off and
  reports success. **Only the guard can see that.** An oracle can be blind (ruling 26).

### 10.3 ⚠ Trailing dot, empty at the root, and the case rule

`sim_sch_path` answers `x1.x2.`, `x1.` and `` — **a trailing dot, and EMPTY at the sim
root.** The plan's algorithm compared that string straight against a dotted browser path
having neither. `hier_split` is THE normaliser and the only place that knows this.

**Case is where the plan was most wrong.** ngspice **lowercases**: the raw (and therefore
the tree) says `x1.x2`, while the schematic instance is `X2` and `get_instance()`
(`src/scheduler.c`) is a plain `strcmp`. So:

* **Exact-first + `-nocase` retry when resolving a segment is NECESSARY** — without the
  case-insensitive candidate the feature finds nothing on any real raw.
* **…AND NOT SUFFICIENT.** The **final verify must also be `-nocase`**, or a *correct* walk
  of `x1.x2` lands on the schematic's own spelling `x1.X2` and is rejected by its own
  verify. Reproduced before the fix: `CASE hgo x1.x2 -> {err {verify failed} {}}`.

Item 11 therefore **split the comparison in two, and the split is the point**:

| proc | comparison | why |
|---|---|---|
| `hier_common` (prefix) | **byte-exact** | A design carrying BOTH `x1` and `X1` (the `wvhier` fixture does) must, from `X1.X2`, share NO prefix with target `x1` — so it ascends twice and descends into the OTHER instance. A `-nocase` prefix would keep the walk **inside the wrong subtree while reporting success.** |
| `hier_same` (verify) | **`-nocase`** | Above. |

`hier_resolve` follows the same rule one layer down: **exact wins always**, and the
case-insensitive candidate is returned only if the whole level found no exact hit — so a
level carrying both `x1` and `X1` resolves each to itself.

⚠ `hier_resolve` scans **by index**, never `xschem getprop instance <name> name`. MEASURED:
`get_instance()` treats an **all-digit** argument as an INDEX, so a by-name lookup of a
numeric segment would silently answer with some other instance. Declared limit, unguarded:
a raw's path segments are SPICE instance names, which cannot be all digits.

### 10.4 ⚠ Confirm every step by READBACK, never by `catch`

Both primitives lie by omission:

* **`xschem descend -inst <name>`** returns the **STRING `0` WITHOUT THROWING** for a
  non-subcircuit or a raised semaphore. MEASURED: `descend -inst V9` returns `0`, no throw,
  no movement — **`catch` alone sees nothing.**
* **`xschem go_back`** returns **void**, is a silent no-op at semaphore != 0, and returns
  **WITHOUT ascending** when the user cancels the save prompt.

So every rung asserts on the world: ascend requires the depth read back from `hier_now` to
have **DECREASED**; descend requires **BOTH** the result string `1` **AND** the depth to
have **GROWN**. Counting the steps we think we took is not enough — `descend_schematic()`
extends `sch_path` **before** `load_schematic()`, so a failed load leaves the tree one level
deep while returning 0.

### 10.5 The algorithm (`hier_walk`)

```
0. start = hier_now.  If start and target are BYTE-identical -> {ok already <path>},
   NOTHING touched: no selection change, no redraw.
1. hier_plan -> {nup segs}
2. ASCEND nup times with `xschem go_back`, re-reading hier_now after each,
   requiring the depth to have DECREASED.
3. DESCEND each segment: hier_resolve -> `xschem descend -inst`, requiring the
   result string `1` AND the depth to have GROWN.
4. VERIFY with hier_same (-nocase).
5. ANY failure and rollback -> re-walk to `start` with rollback OFF, then report.
```

Returns `{ok <landed>}` | `{ok already <path>}` | `{err <reason> <where we are>}`, and
**never throws** — it rides a menu entry and a key binding, and a throw in either pops
bgerror, which is modal under X.

**Step 5 is decision 11: a failed sync ROLLS BACK**, in both directions. The rollback is
the same primitive as the walk (the walk is idempotent), so there is no second code path
that could be wrong.

Declared, not hidden: **a successful walk CLEARS THE SELECTION at every level it
traverses**, because both `descend -inst` and `go_back` call `unselect_all(1)` in C. The
`already` path does not. Also declared: a **case-mismatched** already-at-target deliberately
re-walks and lands correctly, reporting the schematic's spelling.

### 10.6 ⚠ Vector instance slices are NOT addressable — issue 0212

`x1[3]` is refused with a named reason. A bracketed segment cannot be reached by
`descend -inst`, which addresses whole instances. Deferred, filed as
`doc/claude/issues/0212-descend-to-here-cannot-address-a-vector-instance-slice.md`, and
`hier_resolve` returns the sentinel `VECTOR` so the refusal message can name the cause.

### 10.7 ⚠ THE ASYMMETRY BETWEEN ITEMS 11 AND 12 — a known limit, recorded not papered over

When the design window sits on an **ancestor** of the session's design, the two directions
behave differently **on purpose**:

| direction | behaviour |
|---|---|
| **Item 11**, browser -> schematic | **REFUSES.** `hier_origin_ok` returns 0 when `xschem raw loaded` is `-1` *and* `ase::ui::sod_base_level` is non-zero — i.e. when the degraded `sim_sch_path` (§10.2) is measured from a different origin than the browser's names. It refuses rather than guessing. |
| **Item 12**, schematic -> browser | **MAPS.** `browser_origin_drop {level rawlevel}` drops `level` leading segments to convert a window-relative position into a browser-relative one. |

MEASURED IDENTITY behind item 12's arithmetic: with no raw loaded, `sim_sch_path` degrades
to the window's whole path, so dropping `level` segments reproduces
`ase::ui::sod_rel_path $level` **exactly, without reading `sch_path`** (which decision 10
forbids). A **negative** drop means the raw was read BELOW the session's design; the two
origins cannot be reconciled and item 12 **refuses** rather than guessing.

**Browser->schematic refuses what schematic->browser handles.** Closing the gap means
changing item 11 and was out of scope. Filed as
`doc/claude/issues/0215-hierarchy-sync-is-asymmetric-between-items-11-and-12.md`.

### 10.8 The schematic side: read the pivot BEFORE opening the viewer

`ase::show_in_browser_for_current` (`src/ase.tcl`):

```
0. CONTEXT — switch to the window the gesture fired in (%W), VERIFY BY READBACK
   (`new_schematic switch` silently no-ops under a raised semaphore).
1. SESSION — ase::session_for_current (issue 0168: nearest ANCESTOR wins).
2. ⚠ READ THE PIVOT NOW, BEFORE ANY VIEWER IS TOUCHED.
3. ORIGIN — browser_origin_drop; a negative drop is REFUSED.
4. wviewer::open $key   (raise-or-open, 0 for unknown token, 0 headless)
5. SIDEBAR — un-hide if hidden.
6. wviewer::browser_show_path — speaks on every branch.
7. CONTEXT IS LEFT ON THE VIEWER.
```

⚠ **Step 2's position is the whole point of the comment that guards it.** MEASURED:
`wviewer::open` and the sidebar show both **MOVE the xschem context to the viewer window**,
and `sim_sch_path` read there answers about the viewer's own untitled buffer. Reading the
pivot after the raise is a silent, plausible wrong answer.

Step 7 is declared, not accidental: the exact mirror of item 11 leaving the context on the
design window. The window the user is now looking at is the one the context points at.

Also declared: **the sidebar un-hide is NOT rolled back on a failed sync.** The `err` and
no-raw branches leave the sidebar shown, which matches the plan ("show it as part of the
command") and is asserted deliberately. It is not a decision-11 violation — decision 11 is
about the *hierarchy position*, and that is rolled back.

`browser_show_path` returns `{ok <id> <path>}` | `{partial <id> <landed> <asked>}` |
`{root <asked>}` | `{err <reason>}`. `partial` selects the **deepest ancestor that exists**
and says so; `root` **clears** the selection and scrolls home, which IS the answer for the
sim root; `err` **leaves the selection alone** — decision 11's mirror, a failed sync leaves
the user where they were.

`browser_reveal` is shaped around one ttk fact: **`$tv see $id` IS the expansion** — it sets
every ancestor's `-open` and then scrolls, so an explicit expand-ancestors loop would be
dead code no sabotage could reach. And `$tv exists {}` is TRUE (the root), so the empty id
is refused explicitly — otherwise `selection set {}` would silently CLEAR the selection and
report success.

### 10.9 The multi-row rule

`browser_target_path` resolves a **set** of selected rows to ONE path **only when every row
yields the same path**. A disagreeing set is an `err` and the menu entry stays DISABLED.
Chosen against a silent first-wins (ruling 17), and declared rather than hidden.

---

## 11. All DBs (item 14)

The All-DBs box widens a search to **every loaded results database**, not just the current
one.

⚠ **The source of truth is the ENGINE REGISTRY, not the browser's own history.**
`xctx->extra_raw_arr` (`src/xschem.h`) is manipulated by `extra_rawfile()`
(`src/save.c`) and printed by `xschem raw info`'s `what == 4` arm. Item 13's raw *history*
(§12) is a UI convenience and a different thing entirely. `xschem raw list` only ever sees
the **current** entry, so All-DBs must walk.

`signal_list_all` therefore does what `signal_list` deliberately never does: **it moves the
engine's current-DB pointer and puts it back.** That adds a failure mode (a REFUSED restore)
which `signal_list`'s twelve call sites do not have — which is exactly why the two are
separate procs rather than one generalised one. `signal_list` stays the authority for the
current DB, and no browser read has ever been able to move the user's current DB.

### ⚠ The measured bug the naive version had

The first cut skipped the DB switch whenever `idx == cur` — **correct only on the first
iteration.** After visiting a foreign DB the engine pointer is on *that* DB, so the current
DB's own turn read the **previous DB's names**, and the scan answered the same inventory
twice. The fix is a `here` variable that **tracks where the engine actually is**.

**A check that had only counted the entries would have gone green.** It was caught by a
per-DB *names* leg. This is ruling 17 in miniature: a count check named as if it pinned
content.

### Other properties

* The **restore is UNCONDITIONAL and outside the loop's own catch**: a refused switch, an
  empty DB or a throw all still land back on the DB the user was on.
* **Nothing calls `update` or `after`** — a redraw running while the current DB is swapped
  would draw the wrong waveforms.
* **Nothing calls `xschem raw clear`** — item 13's atomicity rule, inherited (§12).
* `rawinfo_parse` parses `xschem raw info` **per LINE**, a deliberate improvement over the
  legacy per-WORD parse in `src/xschem.tcl` (`lrange [xschem raw info] 2 end`), where **a path
  containing a space shifts every subsequent field.**

---

## 12. The Location bar and the raw history (item 13)

`$f.loc`: a `ttk::combobox` plus a `Browse...` button.

* **`Browse...` is packed `-side right` FIRST**, and that is forced rather than stylistic.
  `browser_width` sets `pack propagate $f 0` and fixes the frame's width, so a child wider
  than that is **CLIPPED, never accommodated**. The packer serves slaves in packing order,
  so the fixed-width button must claim its slot before the stretchy entry.
* **The combobox is `-width 18` and `-justify right`**, which is the whole of the long-path
  answer: the fixed width stops reqwidth growing with the text (a real raw path is easily
  120 characters), and right-justification means the part that stays on screen is the
  **TAIL — the file name** — rather than a useless run of leading directories. The full path
  lives in the balloon, **re-attached by `rawbar_sync` on every load.**
* History cap **20** (`wviewer::rawhist_max`, from `::raw_history_max`, `src/xschem.tcl`).
  It is a **global**, not per-token: "the last raws I opened" is a property of the user.
* `Browse...` **reuses** `select_raw` (`src/xschem.tcl`) rather than reimplementing it. That
  is `tk_getOpenFile`, i.e. MODAL, so the route is never exercised headlessly; only its
  wiring is assertable. Declared limit.

### ⚠ `rawbar_load` does NOT `raw clear` first — and that is the atomicity

`attach_raw`'s first act **is** `catch {xschem raw clear}`. `rawbar_load`'s deliberately is
not. MEASURED: with raw A current, `xschem raw read <garbage>` returns 0 and leaves **both**
`raw rawfile` and `raw list` on A — **the engine's read is atomic as long as nothing cleared
the old data first.** Clearing would turn a typo in an editable path entry into *"your
waveforms are gone"*.

The cost is declared: **raws ACCUMULATE** in `xctx->extra_raw_arr` rather than replacing one
another. That accumulation is what All-DBs (§11) then walks.

`rawbar_load` also calls `browser_refresh $token 1` **after the successful read and inside
it** — D6 (§6) means the tree would otherwise show the OLD raw's signal list under the new
raw's waveforms, and placing the refresh inside the success branch means a failed read
cannot replace a good tree with an empty one. It captures the live view state first
(issue 0194's rule) and regenerates with `skip_ranges`, so the new raw autozooms instead of
being drawn in the outgoing raw's window.

### Declared limits

* **L-13a — `attach_raw` (the ASE re-run path) does NOT enter the raw history.** The raw a
  user works with most is therefore absent from the dropdown. Chosen for blast radius:
  `attach_raw` is referenced by other suites' assertions. Filed as
  `doc/claude/issues/0216-attach-raw-bypasses-the-raw-history.md`.
* **L-13b — raws ACCUMULATE** (above). That is what buys failed-read atomicity.
* **L-13c — the dropdown shows NORMALISED ABSOLUTE paths.** `rawhist_add` stores the
  normalised absolute form, which is what makes the dedup real: `./a.raw` and
  `/full/path/a.raw` are one entry, not two.

---

## 13. Persistence (item 15)

`wviewer::browser_state` / `browser_state_apply` add a gated **`browser`** key to the
viewer's `snapshot` / `restore`. Fields: `shown`, `width`, `search`, `filter`, `dest`,
`open` (expanded node ids), `sel`, `hist`.

* `{}` in, `0` out — the **back-compat arm**: a state file with no `browser` key leaves the
  fresh window exactly as `open` built it.
* **Step order is forced, twice over.** The width goes AFTER `browser_show` (the pack branch
  recomputes it); the tree state goes AFTER it too (that call repopulates the tree from
  `xschem raw list` and wipes both fields). Both go only when the sidebar restores **shown**
  — D6 again: there is no populated tree while it is hidden.
* It writes `dest` and `browser` **directly** rather than through `set_plot_dest` /
  `browser_toggle`, which both `log_action`: a rebuild must not fill the replay log with
  lines nobody typed. The VALUE still goes through `dest_norm`, so a garbage `dest` in a
  hand-edited state file lands on the harmless policy (`append`).
* `browser_width`'s `want` parameter **widened** the proc, it did not replace it: `{}` is
  literally the pre-item-15 path, and a positive integer replaces the derived base and then
  takes **the same cap and floor**. So a restored width cannot exceed 45% of a toplevel that
  is now smaller than the one it was measured on. **Declared consequence: the dict field
  round-trips exactly, the PIXELS do not when the window changed size.**

---

## 14. Every declared limit, in one table

| id | limit | where | issue |
|---|---|---|---|
| **D1** | The bars are wider than any sane sidebar; at the derived width the **error label is clipped** (`ismapped 0`). Decision 4 survives only because the message is mirrored into the status line. | §7 | — |
| **D2** | **Replace does nothing under multi-plot** — a gesture offering Replace in multi mode is really offering Append. Surfaced in the menu label (`Replace -> appends`) rather than hidden. | §9 | — |
| **D3** | **A double-click on a GROUP does not plot** — ttk owns that gesture. MMB and the Plot button do. | §8 | — |
| **D6** | **The inventory is a SNAPSHOT** taken when the sidebar is SHOWN, not a live read. | §6 | — |
| **D7** | **"Row order" means RAW-FILE order**, not the tree's visual order — ttk re-parents a late arrival under its group. | §8 | — |
| **D8** | `browser_width` needs `update idletasks`; without it the derivation collapses to the 240 px floor and Tk will not deliver synthetic keys to the clipped entry. | §6 | — |
| **U** | **ViVA's unit-collision rule is NOT IMPLEMENTABLE** — `read_dataset` (`src/save.c`) discards ngspice's per-var type, so xschem has no unit metadata at all. A **permanent divergence, not a TODO.** | §3.5 | — |
| **@** | `@`-form terminal currents classify as `other`, disagreeing with `ase::ui::output_kind`. On purpose and visibly. | §3.6 | — |
| **R16-3** | ARE directors / embedded options (`***=`, `(?i)x`) are an **ERROR**, inherent to wrapping the user's pattern in `^(?:$pat)$` at all. Accepted, ruled. | §4 | — |
| **VEC** | Vector instance slices (`x1[3]`) are **not addressable** by `Descend to here`. | §10.6 | **0212** |
| **ASYM** | Items 11 and 12 are **deliberately asymmetric** on an ancestor design window: 11 REFUSES, 12 MAPS. | §10.7 | **0215** |
| **L-13a** | `attach_raw` (the ASE re-run path) does **not** enter the raw history. | §12 | **0216** |
| **L-13b** | `rawbar_load` does not clear the previous raw, so raws **accumulate**. That is what buys failed-read atomicity. | §12 | — |
| **L-13c** | The dropdown shows **normalised absolute** paths — which is what makes the dedup real. | §12 | — |
| **IDX** | `hier_resolve` scans by index because `get_instance()` treats an all-digit argument as an index. Unreachable from the browser (SPICE names cannot be all digits). | §10.3 | — |
| **MOD** | `Browse...` is `tk_getOpenFile`, i.e. modal; only its wiring is assertable headlessly. | §12 | — |
| **SEL** | A successful `Descend to here` **clears the schematic selection** at every level it traverses (C's `unselect_all(1)`). The `already` path does not. | §10.5 | — |

---

## 15. Open issues

* **`doc/claude/issues/0186-viewer-context-destroyed-by-reload-and-inplace-loads.md`** —
  **OPEN.** A CIW `xschem reload` (and the routing-exempt in-place loads) blanks a live
  waveform viewer's document. It needs C. **Every item from 8 on was required to route
  around it** — decision 13: browser state derives from the raw verbs, NEVER from the rect
  model. Re-measured at batch start and it still reproduces; additionally measured then:
  **the raw SURVIVES a reload intact**, reload frees **no Tk widget**, and under a real
  DISPLAY a reload on a viewer also **HANGS on a modal `alert_`**.
* **`doc/claude/issues/0212-descend-to-here-cannot-address-a-vector-instance-slice.md`** —
  §10.6. Filed by item 11, routed around.
* **`doc/claude/issues/0213-read-raw-ascii-point-overruns-its-buffer.md`** — ⚠ **a REAL,
  PRE-EXISTING C DEFECT.** A malformed ASCII `Values:` block overruns
  `read_raw_ascii_point`'s fixed `char line[1024]` (`src/save.c`, two call sites in the
  count pass and the read loop). Found by item 13 while hand-writing fixtures. **Filed, not
  fixed** — it is C, and decision 8 forbids C in this batch. Item 13's test routes around
  the unsafe path.
* **`doc/claude/issues/0214-readonly-is-cleared-on-a-failed-load.md`** — `xctx->readonly = 0`
  in `load_schematic`'s `reset_undo` arm runs **before** the fopen test, so **any** read-only
  buffer whose file has been removed comes back **writable**. Not viewer-specific. Split out
  of 0186; needs C.
* **`doc/claude/issues/0215-hierarchy-sync-is-asymmetric-between-items-11-and-12.md`** —
  §10.7.
* **`doc/claude/issues/0216-attach-raw-bypasses-the-raw-history.md`** — §12, L-13a.

---

## 16. Test map, and the transferable lessons

### Which file covers what

| file | covers |
|---|---|
| `tests/headless/test_wave_sigsearch.tcl` | items 1-7: `sig_match`, `sig_type`, `signal_list`, the search bar megawidget, `plot_dest`, the legacy `.graphdialog` retrofit |
| `tests/headless/test_wave_sigbrowser.tcl` | items 8-10: the sidebar, the tree, the context menu. **FROZEN** — several legs are source greps pinned to literals |
| `tests/headless/test_wave_sigbrowser_i11.tcl` | item 11, `Descend to here` |
| `tests/headless/test_wave_sigbrowser_i12.tcl` | item 12, `Show in Signal Browser` (and BX13, which pins the guide's row counts — see below) |
| `tests/headless/test_wave_sigbrowser_i1315.tcl` | items 13 + 15: the Location bar, the raw history, persistence |
| `tests/headless/test_wave_sigbrowser_i14.tcl` | item 14, All DBs |
| `tests/headless/wvbs_common.tcl` | shared fixture helpers — **not a case**, by design |
| `tests/headless/test_wave_grid.tcl` | the **doc oracles**: GH0-GH7 (guide rows vs `install_default_binds` / `build_menubar`), GH8/GH9 (the browser's own widget gestures vs `browser_build`), GH10 (`§N` refs resolve), GS0-GS3 (this spec's contract list vs source, and its issue references vs the issue directory) |
| `tests/headless/fixtures/wvhier/` | the hierarchy-sync fixture: a design carrying **both** `x1` and `X1`, which is what makes the byte-exact/`-nocase` split testable |

### ⚠ Ruling 30 — every design-window-coupled item gets its OWN PROCESS

MEASURED: at **489 checks** the single browser test file was **killed mid-run ~90% of the
time with ZERO check failures.** That is a footprint problem, not a code problem, and it is
indistinguishable from a passing run unless you count the checks. Splitting the file
(commit `18c45a16`) fixed it. **A whole file dying with zero check failures is the box, not
your code** — and the counter-evidence is the check count, not the exit status.

### The lessons this batch paid for

* **Ruling 29 — THE VACUOUS-CHECK TRAP, the batch's most productive finding.**
  *A negative check is worthless without a PROVEN POSITIVE CONTROL on the same fixture.*
  Caught **five** times: a check asserting "X does not appear" that would also have passed
  if the extraction found nothing at all, or if the file failed to parse. The discipline:
  **RUN the sabotage. Do not reason about whether the check would catch it.**
* **Ruling 17 — widen the coverage or narrow the claim, never neither.** A check NAME that
  overstates what it pins is itself a defect. §11's `here`-tracking bug and §8's D7 are both
  instances.
* **Ruling 22 — when a name fails and you suspect yourself, the decisive evidence is an A/B
  with your own change reverted**, same run count, comparing fail *rates* and fail *shapes*.
  Not a re-run count. (`test_wave_trace_menu` is ~50% flaky and will happily "confirm" any
  hypothesis you re-run enough times.)
* **Ruling 23 — a sabotage may legitimately fail a SUPERSET of its predicted check, and a
  plan-named sabotage may prove NOTHING.** Four items had to substitute or add their own.
  §10.2 is the clearest case: the named sabotage was a no-op against correct code.
* **Ruling 26 — an oracle can be BLIND, and an oracle can be WRONG ON CORRECT CODE.** Verify
  what a named oracle *measures*, not merely that it can see the thing. §10.2 again.
* **Ruling 28 — a plan rationale is not evidence.** 0178's Button3 swallow did not transfer
  to a `ttk::treeview` (§8), and the premise behind a whole item was false.
* **Ruling 25 — a dead agent is not a verdict.**
