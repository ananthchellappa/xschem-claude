# Item 20 — the bars filter WHAT THE USER SEES

**Status: SCOPED, not implemented.** Driver-raised after item 11 landed.
Spec to amend: `doc/claude/specs/waveform_signal_browser_two_pane.md` (R8, §7.1)
and `doc/claude/specs/waveform_signal_browser.md` (§7, ruling 3).

---

## 1. The defect, in the driver's own words

> in tb_bandgap, descend to `x1` and there are signals named `net1`, `net2`. The user
> SHOULD be able to filter based on what is presented, not what the actual database
> value is. `net*` should show the netXYZ signals. User should not have to put in
> `*net*` or `v(x1.net*`.

**MEASURED on `tb_bandgap`'s `x1` level (43 own-level signals, shipped class policy):**

| the user types | matches against RAW today | matches against the R8 LABEL |
|---|---|---|
| `net*` | **0** | **26** |
| `net1*` | **0** | **11** |
| `*1` | **0** | **4** |
| `*net*` | 26 | 26 |
| `v(x1.net*` | 26 | 0 |

The pane renders `net1`; the matcher globs `v(x1.net1)`. Ruling 3 anchors wildcards to
the whole name, so a leading-anchored pattern can never match a wrapped name. **Only the
`*…*` substring form works, and only by accident.**

## 2. What this is called

**Articulatory directness** — Hutchins, Hollan & Norman, *Direct Manipulation Interfaces*
(HCI 1:4, 1985): an interface has *semantic* distance (can the language say what I mean?)
and *articulatory* distance (does the FORM of my input match the FORM of the output I am
looking at?). Typing `v(x1.net1)` at a pane displaying `net1` is pure articulatory
distance — same meaning, different surface form, and the user pays the translation.

Also, and all naming the same rule: Norman's **Gulf of Execution**; Nielsen heuristic **#2
Match between the system and the real world** ("speak the users' language rather than
system-oriented terms" — `v(…)` wrapping is SPICE raw-file syntax leaking up); Nielsen
**#6 Recognition rather than recall**; Shneiderman's **continuous representation of the
object of interest**. Practitioner shorthand: **WYSIWYS**, *filter on the display value,
not the raw value*. Negative framing: a **leaky abstraction** — the storage encoding has
surfaced in the query language.

## 3. ⚠ Three measurements that decide the design

**3.1 Pasting a raw name ALREADY does not work, for 292 of 1191 charge-pump names.**
`string match` treats `[` as a character class opener:

```
string match {i(@c.x1.c1[i])} {i(@c.x1.c1[i])}   ->  0
string match {i(v.x1.v1)}     {i(v.x1.v1)}       ->  1
```

`tb_bandgap`: 0 of 424 names contain `[`. `tb_charge_pump`: **292 of 1191**. So the
strongest objection to label-matching — *"but users paste raw names"* — is already false
for every device measurement in the corpus. It works today only for names without `[`.

**3.2 R8 labels carry ZERO glob metacharacters; raw names carry them almost always.**
Of the 190 class-filtered `tb_bandgap` names: **0** labels contain `[ ] * ? \`, while
**189 of 190** raw names contain `(`. The pattern language is clean on labels and
booby-trapped on raw names.

**3.3 Label collisions within one own-level node: ZERO on both committed corpora.**
Measured over `tb_bandgap` (424 and the 190 filtered) and `tb_charge_pump` (1191): 0
within-level collisions. Spec R8's measured "exactly four" are in *other* designs
(`tb_bandgap_opamp`, `tb_ft_test_2`, `test_ac`) and are an element's `@`-form measurement
against its bare branch current. **A filter is a display operation, not an identity
resolution**, so a collision would merely show both — consistent with the batch's own
standing rule that *the label is a display, never an identity*. Gestures still resolve
through the flow index into the full raw name. **This item does not weaken that rule.**

## 4. Scope

### 4.1 What changes

Exactly one subject: **the two browser bars now match the R8 label of each candidate, and
still return the RAW NAMES.**

```tcl
# NEW, PURE. name -> the label the lower pane renders for it.
proc wviewer::browser_label_of {name} {
  return [wviewer::browser_label [wviewer::signal_entry $name]]
}
```

`sig_match` gains ONE option, **`-key <command prefix>`**, default `{}` = identity: the
element is passed through `key` before the pattern is applied, and the ORIGINAL element is
what gets returned.

```tcl
      -key    { set key $v }
...
  foreach n $siglist {
    # ⚠ -type STAYS ON THE RAW NAME. sig_type reads the `v(`/`i(` prefix, which the
    # label deliberately destroys (a current renders `v1:i`). Keying the type filter
    # off the label would be a second, wrong encoding of the same fact.
    if {$type ne {all} && [wviewer::sig_type $n] ne $type} { continue }
    set k $n
    if {$key ne {}} { set k [eval $key [list $n]] }     ;# ⚠ NOT {*} — Tcl 8.4
    ...match $k..., lappend out $n
  }
```

Then the key is threaded, **as an optional trailing argument at every rung**, so nothing
that does not pass it changes:

```tcl
proc wviewer::browser_match_one {sigs d {key {}}}
proc wviewer::browser_and      {sigs d1 d2 {key {}}}
proc wviewer::browser_match    {token}   ;# passes -key wviewer::browser_label_of
```

### 4.2 ⚠⚠ WHY THE OPTIONAL-ARGUMENT SHAPE IS LOAD-BEARING, NOT STYLE

`browser_and` and `browser_match_one` are pinned as PURE procs by **BT14 (5 checks), BT15
(3) and BT16 (4)**, all of which call them directly with RAW patterns against a RAW name
list. Make the label transform unconditional and those twelve checks move for no reason —
they are testing the matcher, not the bars. With the key optional and defaulted, **all
twelve stay green by construction**, and each can gain a second leg proving the key
argument does what it says. Same argument, one layer down, for `sig_match`'s `-key`.

### 4.3 What must NOT change — three other callers of the same matcher

| caller | file:line | why it must stay raw |
|---|---|---|
| `graph_get_signal_list` | `src/xschem.tcl:4564` | the LEGACY `.graphdialog`. It strips `v(…)` itself and un-anchors the pattern. |
| `add_trace_filter` | `src/wave_viewer.tcl:12240` | the Add Trace dialog **displays the raw names it matched** (`$w.vars insert end $n`, `:12251`) and `add_trace_pick` copies that string into the Expression entry, which goes to `xschem raw add`. It is already WYSIWYS. Label-matching there would put un-plottable strings in the entry. |
| `searchbar_fire`'s validator | `src/wave_viewer.tcl:12064` | calls `sig_match` on an EMPTY list purely to compile the regexp. Subject-agnostic. |

⚠⚠ **`GSO01`-`GSO06` (`test_wave_sigsearch.tcl`) is a differential property oracle**: a
frozen `git show afdd44a0^` copy of the pre-retrofit `graph_get_signal_list` run against
the live one over 52 names × 94 patterns × 2 sorts = **10,340 comparisons, zero permitted
differences**. Any *semantic* change inside `sig_match` reds GSO01. Adding an option that
defaults to identity is not one — **but that is a claim to VERIFY by running it, not to
assume.** It is the single strongest reason to add `-key` rather than rewrite the match
loop.

### 4.4 Non-goals, declared

* **The tree is untouched.** §7.1 already scopes both bars to the lower pane. `x1*` will
  not match a NODE; matching node names is a separate question with its own rulings.
* **The `type` dropdown stays raw-keyed** (§4.1's ⚠). `-type v` still means "the raw name
  starts `v(`".
* **No `raw:` escape hatch, no label-OR-raw union.** A union makes *"why did that match?"*
  unanswerable and lets `*v(*` match a row whose label has no `v(`. If a paste path is
  wanted later it is its own item. Recorded as the rejected alternative, with §3.1 as the
  reason it costs less than it appears to.
* **Persistence is unaffected in shape.** `browser_state` stores the bar dicts verbatim
  (`search` / `filter` keys, `browser_state:9690-9694`); a *saved* raw-shaped pattern will
  simply stop matching after the upgrade. Declared limit, not a migration.

## 5. Existing checks it reds — MEASURED, per site

Only the **live-bar** paths move. Everything below is a browser bar with a raw-shaped
pattern; the R8-OK patterns (`*net5*`, `*net1*`, `*net12*`, `*beta*`, `*alpha*`, `.*`)
match identically against labels and do **not** move.

| id | file:line | pattern | today | after |
|---|---|---|---|---|
| BT25 ×3 | `test_wave_sigbrowser.tcl:1402/1409/1417` | `v(*)` | `4 of 8` | **0 of 8** — must re-pattern |
| BT26 ×2 | `:1463/1464` | `v(*)` | `2 of 8` | **0 of 8** |
| BT26 (`bt_distinct`) | `:1461` | four bar states | `distinct:4` | **collapses** — see §6 |
| BT27 ×2 | `:1500/:1507` | `v(*)` + regexp `.*net5.*` | `2 of 8` | recovery leg moves |
| BQ53 ×3 | `test_wave_sigbrowser_sea.tcl:283` | `v(x1.x2.net5*` | 23 → `{net5}` | **matches nothing** |
| BW46 ×2, BW47 | `test_wave_sigbrowser_panes.tcl:587` | `v(x1.x2*` | `3 of 3` → `1 of 3` | **stops moving the line**, which is BW46's anti-vacuity proof |

**≈ 16 checks, three files.** Nothing in `test_wave_sigsearch.tcl` moves (SM/BAR/AT/GSO
all reach `sig_match` without a key), and `test_wave_sigbrowser_2pane.tcl` has no bar at
all. BP43/BP45/BP49/BP50/BP57 carry `type v` and stay green **because the type filter
stays raw-keyed** — if that decision is ever revisited, those five move too.

## 6. The BT25/BT26/BT27 discriminator, rebuilt a THIRD time — already solved

Item 10 rebuilt this twice. Its four bar states must give four DIFFERENT signatures, and
the `bt_count` leg is what discriminates. **MEASURED on `$BTFIX`**, whose labels are
`{out out2 net5 net5 net5:i v1:i net1 vsweep}`:

| state | pattern | count |
|---|---|---|
| ALL | — | **8 of 8** |
| SEARCH | `net*` | **4 of 8** |
| FILTER | `*:i` | **2 of 8** |
| AND | both | **1 of 8** |

Four distinct values, and **both patterns are label-only** — `net*` is the driver's own
example and `*:i` is R8's current suffix. Neither means anything against a raw name, so
the discriminator now *demonstrates* the feature instead of merely surviving it. (Checked
exhaustively against the alternatives: `out*`/`net*`/`n*` × `*net5*`/`*1`/`*:i`; only
`net*` ∧ `*:i` yields four distinct counts.)

## 7. RED first

1. Add `BQ70`-`BQ7x` to `test_wave_sigbrowser_sea.tcl` — the driver's own case, on the
   424-name corpus at `g:x1`:
   * `net*` → **26** cells (today: 0).
   * `net1*` → **11**. `*1` → **4**.
   * `v(x1.net*` → **0**, asserted as a value: the raw form stops working, declared.
   * the surviving names are still RAW (`browser_sea_names` unchanged) — the label is a
     filter subject, never an identity.
   * a `-type i` leg proving the type dropdown still reads the raw prefix.
2. Add `SM29`/`SM30` to `test_wave_sigsearch.tcl` — `-key` as a pure option: identity by
   default, transform applied, **original element returned**, and `-type` unaffected.
3. Re-pattern the ≈16 sites in §5, using §6's table for BT25/26/27.
4. Only then touch `sig_match`, `browser_match_one`, `browser_and`, `browser_match`.

## 8. Sabotages

* Return the LABEL instead of the original element from `sig_match`'s `-key` arm →
  every gesture downstream plots a label; **BQ56/BQ58/BQ60 and BM33/BM43/BM45 red**
  (measured as item 11's S3: 26 reds over two files).
* Key the `-type` filter off the label too → SM12/SM13/SM14 and BP43/BP45/BP49/BP50 red.
* Make the key unconditional in `browser_match_one` → BT14/BT15/BT16 red (12 checks) —
  the check that the optional shape is doing its job.
* Pass the key at `browser_and` but not `browser_match_one` (or vice versa) → the two
  bars disagree, which is the exact failure `browser_match`'s ⚠ was written to prevent.
* Leave `add_trace_filter` keyed → its listbox shows labels and the Expression entry
  prefills an un-plottable string; the AT band reds.

## 9. Spec amendments owed

* **`waveform_signal_browser.md` §7** — the bars' subject is now the rendered label.
  Ruling 3 (whole-name anchoring) is UNCHANGED in force; it now anchors to the label,
  which is what makes `net*` work.
* **`waveform_signal_browser_two_pane.md` R8** — add: the label is also the FILTER
  SUBJECT. Restate, do not weaken, "the label is a display, never an identity": a filter
  selects what to show and resolves nothing.
* **A new §7.7** recording §3.1's measurement (raw-name paste is already broken for names
  containing `[`) as the reason the paste path was not preserved.

⚠ **Do not misread `src/wave_viewer.tcl:11709`**, *"`sig_match` must never see a label"*.
That is about the SEARCHBAR WIDGET's on-screen English (`Voltage`/`Shell`) versus
`sig_match`'s codes (`v`/`shell`) — a different sense of "label" entirely. It is not a
prohibition on this item, and the next reader will trip on it.

## 10. Where the same defect does NOT exist

Checked, so the item stays one item: the Add Trace dialog, the legacy `.graphdialog` and
the bare searchbar widget all **display the string they match**. The browser's lower pane
is the only surface in the codebase that renders a transformed name while filtering the
untransformed one — which is exactly what item 11's R8 labels introduced.
