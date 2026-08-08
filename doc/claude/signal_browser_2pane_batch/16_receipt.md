# Item 16 — the bars filter WHAT THE USER SEES. And item 11's eighth bind.

**Status: LANDED.** Two commits, two attributions, as the work order asked:
the label filter, then the hover tooltip that pays item 11's one acknowledged miss.

⚠ **THE NUMBER 16 IS USED TWICE IN THIS BATCH, and it is not a typo here.**
`PLAN.md`'s table row 16 is *"R9 — Ctrl-L → Ctrl-B, incl. the C-table row
deletion"*, which shipped long ago; **this** item 16 is the driver-raised one
scoped in `ITEM16_label_filter.md` after item 11 landed, and it has no PLAN row.
`test_wave_grid.tcl`'s GH8 comment refers to the *first* item 16. Nothing was
renumbered — noted so the next reader does not "fix" one of them.

Work order: `ITEM16_label_filter.md` (commit `2f7d45d6`). Everything below is a
value that was **run**, not a value that was reasoned to. Where the work order's
own numbers turned out to be wrong, the correction is stated with the
measurement, not silently applied.

---

## 1. The baselines, re-measured on the UNCHANGED tree first

| arm | before | after the filter | after the tooltip |
|---|---|---|---|
| headless, 14 files | **1602**, 0 fail | **1609**, 0 fail | **1610**, 0 fail |
| X arm, 11 suites | **11/11** | **11/11** | **11/11** |

The tooltip's own deltas: `test_wave_sigbrowser_sea` 74 → **79** (BQ75 ×2,
BQ76, BQ77 ×2, X only) and `test_wave_grid` 229/354 → **230/355** — GH8 runs one
leg per `data-bseq` row, so the fifteenth row is worth exactly one check on both
arms.

Per-suite, the only four counts that moved:

| suite | before | after | what was added |
|---|---|---|---|
| `test_wave_sigsearch` | 139 / 226 | 146 / **233** | SM29 (5) + SM30 (2) |
| `test_wave_sigbrowser` | 135 / 352 | 135 / **353** | BT25's route-independence leg |
| `test_wave_sigbrowser_sea` | 6 / 66 | 6 / **74** | BQ70-BQ74 (8, X only) |
| `test_wave_sigbrowser_i14` | 47 / 86 | 47 / **88** | BD57 (2, X only) |

⚠ **Two flakes appeared on the UNCHANGED tree and both passed on re-run**, so
neither is a regression: `test_wave_sigbrowser_i14` answered `NORESULT` once
(the WSLg Xwayland death) and `test_wave_modes` failed `MG16` once — the
key-delivery flake. Re-run: 86 and 485, exact.

---

## 2. ⚠⚠ THE WORK ORDER'S CALLER TABLE WAS INCOMPLETE, AND IT MATTERED

`ITEM16_label_filter.md` §4.1 threads the key through three rungs and has
`browser_match` pass it. **`browser_and` has TWO production callers, not one:**

| caller | file:line | inventory |
|---|---|---|
| `browser_match` | `wave_viewer.tcl:7927` | the CURRENT DB |
| `browser_refresh`, All-DBs loop | `wave_viewer.tcl:8110` | each FOREIGN DB |

Keying only the first would make the same two bar dicts mean two different
things depending on which DB a name came from — the user types one pattern, the
current DB answers about the label they can see and every foreign DB about the
raw name they cannot, with nothing on screen to say which. That is precisely the
failure `browser_match`'s own ⚠ was written to prevent, one level up. **Both
sites pass the key.**

It cost one new check, `BD57` in `test_wave_sigbrowser_i14.tcl`, and it is
BEHAVIOURAL rather than a source grep: the i14 All-DBs fixture is flat
(`v(alpha) v(beta) v(shared)` → labels `alpha beta shared`), so `alpha` —
whole-name anchored, no wildcards — matches **zero** raw names and **one**
label. The foreign DB's header appears only if that branch keys. Its negative
control asserts the raw-subject answer alongside, so "the header appeared"
cannot be confused with "the pattern was ignored". Band `BD57` was chosen
because `BD58` is free and **`BD60`-`BD70` are reserved by the PLAN for item
15** — nothing was renumbered.

## 3. Four other corrections to the work order, all made by measuring

* **§5 lists `:1507` as moving. It does not.** Both bars are empty there, so
  `browser_match_one` returns the identity and `{8 of 8}` + the whole `$BTFIX`
  holds against labels and raw names alike. Left untouched.
* **§5's table omits four lines that DO move** — `sigbrowser:1403`, `:1427`,
  `:1433` and `:1464`, the actual `check` bodies behind BT25/BT26. Re-patterned
  from the measurement rather than from the table.
* **§4.2 says `browser_match_one` is "pinned as PURE by BT14/BT15/BT16, all of
  which call them directly". Only `browser_and` is called directly** — 11 sites,
  all in `test_wave_sigbrowser.tcl`. `browser_match_one` appears in the test tree
  only inside BT01's source greps. Both greps survive an APPENDED argument
  (`string first` is a prefix test; `regexp -all {browser_match_one \$sigs}`
  still counts 1) and neither would survive inserting the key BEFORE the dict —
  which is the argument order that was used.
* **The tooltip miss was NOT recorded in `11_receipt.md` §8**, though the next
  session's prompt cites it as being there. §8 had three entries and none of them
  was the tooltip. The entry has been added, and marked paid, rather than left
  as a claim about a line that did not exist.
* **§8's "key the `-type` filter off the label" was predicted to red
  SM12/SM13/SM14.** It does not, and the reason is that the sabotage worth
  running is the CONDITIONAL one (`sig_type key(n)` only when a key is given):
  SM12-SM14 pass no key, so they cannot see it. **SM30 was written for exactly
  this** and is the check that reds. Stated because "the predicted checks stayed
  green" and "the sabotage did nothing" are different facts.

---

## 4. Two traps that cost real time

### 4.1 ⚠⚠ A COMMENT BETWEEN `switch` ARMS IS PARSED AS A PATTERN

The `-key` arm was first written with its rationale directly above it, inside
the option `switch`. Tcl answers:

```
extra switch pattern with no body, this may be due to a comment incorrectly
placed outside of a switch body - see the "switch" documentation
```

Nine reds across `test_wave_sigsearch` and `test_wave_sigbrowser`, every one of
them an `ERR:` string where a match was expected. The note now lives above the
proc, and says so, so the next person does not put it back.

### 4.2 ⚠⚠ NEVER EDIT THE SOURCE WHILE THE SABOTAGE DRIVER HOLDS IT

The sabotage driver checks `src/wave_viewer.tcl` out: it copies a backup,
patches, runs, and copies the backup back. An edit landing inside that window is
**silently discarded by the restore**, and the driver's own `diff -q` still
reports "restored byte-identical" — because it compares the backup against the
file it just wrote. This happened once, with the tooltip block; recovery was by
auditing every behavioural line of `git diff` against the intended change, which
found one sabotage line still applied (`S1`, left behind because the kill
pre-empted the restore). The driver now takes a **lock file** and carries an
`EXIT`/`INT`/`TERM` trap that restores the source, so an interrupted run cannot
leave a mutation behind.

### 4.3 The string-rep trap, again

`{ok {i(x1.x2.net5)}}` is not the string rep of `[list ok [list {i(x1.x2.net5)}]]`
— a one-element list's rep is bare. Two X-arm reds, on correct code. The file
headers warn about this and it still catches people; the expectations are now
built with `[list …]`.

---

## 5. What landed

### Source (`src/wave_viewer.tcl`) — the filter

* `sig_match` gains **`-key <command prefix>`**, default `{}` = identity. The
  key is applied to each element before the pattern; `lappend out $n` still
  appends the **original**. Computed BELOW the empty-pattern short-circuit, so a
  cleared bar pays nothing for a transform it would discard.
* **`-type` still reads the RAW element**, with the reason on the line.
* NEW `wviewer::browser_label_of {name}` — pure
  `browser_label(signal_entry(name))`, the one spelling of the filter subject.
* `browser_match_one {sigs d {key {}}}` and `browser_and {sigs d1 d2 {key {}}}` —
  optional and defaulted, which is what keeps BT14/BT15/BT16 green by
  construction.
* `browser_match` and `browser_refresh`'s All-DBs loop both pass
  `wviewer::browser_label_of`.

### Source — the tooltip (item 11's eighth bind)

* One new bind, `bind $f.pw.sea.c <Motion>`, in `browser_build` where GH8/GH9
  can count it. **GH8's literal `14` → `15`** and the guide gained its
  fifteenth `data-bseq` row, in the same commit as the bind.
* `browser_sea_tip` (the gesture), `browser_sea_tip_show`, `browser_sea_tip_hide`,
  `browser_sea_tip_watch`, `browser_sea_tip_path`; `seatipdelay` (600 ms) and
  `seatippoll` (200 ms) as variables, `seatipafter`/`seatipidx` per token.
* **The text is `browser_sea_name`, i.e. the FULL RAW NAME**, resolved through
  the row index exactly as every other gesture does.
* ⚠ **`balloon` could not be reused**: it BAKES its string into an `<Enter>`
  binding at attach time, and this tooltip's text changes per cell.
  `rawbar_sync`'s ⚠ records the same finding from the other side.
* ⚠ **The teardown is CODE, not a second bind.** A `<Leave>` would be an eighth
  `bind $f.` line documenting no gesture. Instead `browser_sea_tip_watch`
  re-arms while a tip is posted and drops it as soon as `winfo containing` stops
  answering the canvas. `forget` and `tab_drop_transients` both call
  `browser_sea_tip_hide` beside the menu unpost.
* `eval winfo containing …`, not `{*}` — Tk 8.4 compatibility, the same spelling
  `balloon_show` uses.

### Tests

* **NEW `BQ70`-`BQ74`** (`test_wave_sigbrowser_sea.tcl`, X): the driver's own
  case on the 424-name corpus at `g:x1` — `net*` → 26, `net1*` → 11, `*1` → 4
  (and its four are not all nets), `v(x1.net*` → 0 asserted as a VALUE with the
  caption naming the remedy, the survivors still RAW, and the type dropdown
  proved to still read the raw prefix in three legs.
* **NEW `BQ75`-`BQ77`**: the tooltip.
* **NEW `SM29`/`SM30`** (`test_wave_sigsearch.tcl`): `-key` as a pure option.
* **NEW `BD57`** (`test_wave_sigbrowser_i14.tcl`): §2 above.
* **Re-patterned**: BT25/BT26/BT27 (the 8/4/2/1 discriminator, both patterns now
  label-only), BW46 (`v(x1.x2*` → `net*`, `1 of 3` → `2 of 3`), BQ53
  (`v(x1.x2.net5*` → `net5*`, same one-row answer).
* **NOT moved, and checked**: BQ65/BQ66/BQ66b/BQ67 (`*net1*`, `*net12*`,
  `zzz-no-such-signal` — all label-safe), BW50 (`v`, matches nothing either
  way), the whole AT band (Add Trace stays raw), the whole BAR band (the bare
  widget), `test_wave_sigbrowser_2pane.tcl` (no bar at all).

### Docs

* `waveform_signal_browser_two_pane.md`: R8 amended, §5.4 gained the
  "filter subject, not identity" paragraph, **NEW §7.7** with the measurement
  table, the `[`-in-`string match` finding, the rejected alternatives and the
  two-caller rule.
* `waveform_signal_browser.md` §7: a new subsection stating the subject is the
  rendered label, with ruling 3 **unchanged in force**.
* `doc/waveform_viewer_guide.html` §11.6: the fifteenth `data-bseq` row.

---

## 6. Sabotages — RUN, not reasoned about

Each: patch, run, read the reds AND the check count, restore, `diff -q`. Source
restored byte-identical after every one.

| # | sabotage | reds | where |
|---|---|---|---|
| S1 | key the **`-type`** filter off the label too | **2** | SM30, BQ74 |
| S2 | make the key **unconditional** in `browser_match_one` | **4** | BT14 ×3, BT16 |
| S3 | return the **LABEL** instead of the original element | **19** | BQ53, BQ65 ×2, BQ66, BQ66b, BQ70, BQ71, BQ73, BQ74; SM29 ×3, SM30; BT25 ×2, BT26 ×3, BT27 |
| S4 | key the **first bar only**, not the second | **11** | BT26 ×5; BQ53, BQ70, BQ71, BQ72, BQ73, BQ74 |
| S5 | key **`add_trace_filter`** by mistake | **5** | AT08, AT11, AT13, AT14, AT20 |
| S6 | drop the key from the **All-DBs loop** | **1** | BD57 |
| S7 | drop the key from **`browser_match`** | **17** | BQ53, BQ70-BQ74 (6); BT25 ×4, BT26 ×5, BT27; BW46 |

Three of these need reading rather than counting:

* **S6 reds exactly one check, and that check did not exist before this item.**
  BD57 is the ONLY thing in the tree that sees the All-DBs loop lose its key —
  which is the whole argument of §2 restated as a measurement.
* **S2's four, not twelve.** §4.2 predicts BT14/BT15/BT16 = twelve checks. Only
  four DISCRIMINATE: BT15's dicts carry `*net5*` and type-only patterns that
  read the same against a label as against a raw name, and BT14's fifth check is
  two empty bars, i.e. the identity. Four is the honest number and it is
  non-zero, which is what the sabotage is for.
* **S1's two, and NOT BP43/BP45/BP49/BP50.** §8 predicts the BP band; it stays
  green (i1315, 167 checks, ALL PASS). The sabotage worth running is the
  CONDITIONAL one — `sig_type key(n)` only when a key is given — because an
  unconditional one is S2 wearing another hat. SM12-SM14 pass no key and cannot
  see it either. **SM30 was written for exactly this**, and BQ74 catches it on
  the live bar.

### The tooltip's own four

| # | sabotage | reds | where |
|---|---|---|---|
| T1 | the tip shows the **LABEL**, not the raw name | **2** | BQ75 ×2 |
| T2 | drop the **`<Motion>` bind** | **2** | GH8, GH9 |
| T3 | a **MISS** leaves the previous tip up | **1** | BQ76 |
| T4 | `tip_hide` stops cancelling the **pending** timer | **1** | BQ77 |

* **T2 reds the LEDGER and nothing else** — the sea suite stays at 79, because
  BQ75-BQ77 drive `browser_sea_tip` directly. That is the ledger doing exactly
  the job item 11 built it for, and it is why the literal, the guide row and the
  bind are in ONE commit.
* ⚠ **T3's first version reddened NOTHING and that was a BAD SABOTAGE, not a
  coverage hole.** The patch appended `if {0} { return -1 }` — dead code that
  changes no behaviour. Re-cut as a real mutation (skip the destroy unless the
  hit-test HIT), it reds BQ76. A sabotage that mutates nothing proves nothing,
  and reading its zero as "no check covers this" would have been the wrong
  conclusion twice over.

### On the first S5

⚠ **S5's FIRST run answered ZERO reds and that result is VOID, not a finding.**
It was taken while the source was in the corrupted state described in §4.2 (the
All-DBs key already missing, dropped by a bad restore). Re-run with the
pre-state ASSERTED (`browser_label_of` sites == 3 before patching), the same
mutation reds five AT checks. The assertion is now the first thing the sabotage
driver does — a sabotage measured on an unknown source state measures nothing.

---

## 7. Found, named, NOT fixed

* **`browser_show_path`'s bar clause is still stale** (item 11 §8 named it).
  Item 16 does not touch it: BX37/BX38 pin the strings verbatim.
* **Guide §11.2 prose is still pre-two-pane.** A prose pass is still owed.
* **`browser_state` can hold a raw-shaped pattern that no longer matches.**
  Declared in §4.4 of the work order and in the spec as a limit, not migrated.
* **The eyeball.** Every claim here is a measured value. Item 16 adds its own
  pixel claims to the queue: that `net*` typed at `x1` really does leave 26 rows
  drawn, and that the tooltip appears where the pointer is, after a beat, and
  goes when the pointer leaves the pane.
