# TWO-PANE item 16 — R9: Ctrl-L → Ctrl-B, incl. the C-table row deletion

**One commit.** Bind, key_filter carve-out, C-table row deletion, csv
regeneration and guide rename together, plus the new `BK` file and three
existing files restated.

---

## 1. Baselines, RE-MEASURED FIRST on the unchanged tree

| arm | recorded | measured | drift |
|---|---|---|---|
| headless, 14 wave files | 1637 / 0 fail | **1637 / 0 fail** | none; every per-file figure EXACT |
| X, 11 suites via `xarm.sh suites` (`SUITE_TIMEOUT=400`) | 11/11, 2192 | **11/11, 2192** | none; every per-suite figure EXACT |

**THREE out-of-baseline suites, not two.** The LEDGER's item-16 NOTE names
`test_bindings_file.tcl` and `test_keybindings_help.tcl`. It misses
`test_key_graph_context.tcl`, which is the one this item actually reds — twice.
Pre-item ok-counts, measured: **13 / 17 / 69**, all `ALL PASS`.

---

## 2. Result

| arm | before | after | why it moved |
|---|---|---|---|
| headless | 1637 over 14 files | **1649 over 15 files** | `test_wave_sigbrowser_keys` is new: **+12**. Every other file byte-identical. |
| X | 11/11, 2192 | **12/12, 2215** | the same new file: **+23**. Every other suite byte-identical. |
| `test_bindings_file` | 13 ok | **13 ok** | unchanged — the csv was REGENERATED, not hand-edited |
| `test_keybindings_help` | 17 ok | **17 ok** | unchanged — it excepts `graph.forward` explicitly |
| `test_key_graph_context` | 69 ok | **70 ok** | +1: the deletion became an explicit ABSENCE claim beside the inverted behavioural leg |

No count moved without a reason.

---

## 3. Anchors: what the PLAN and the spec got wrong

| cited | actual |
|---|---|
| PLAN §1 `wave_viewer.tcl:9372-9373` (guard + bind) | `:11642-11643` before the item, `:11668-11670` after. **+2270 / +2296** |
| PLAN §1 the rejection paragraph `:9364` | `:11634-11637` before, rewritten to `:11628-11667` after |
| PLAN §2 `key_filter`'s graphkeys arm `:11214` | `set fwd` at `:13484` before, **`:13520`** after |
| spec §8.1 `:9288-9291` and `:11130-11139` | both stale by ~+2300; corrected in the spec, in place |
| PLAN §4 `test_bindings_file.tcl:28-31` | the keybindings byte-compare is `:29-30` |
| PLAN reds `BS05 (:143) leg 1` | `:144`, and it is BS05's **second** `check_true` |
| PLAN reds `BS42 (:531)` | `:535-538`, literal on `:538` |
| PLAN reds `BS45 (:560-570)` | `:563-574`; count (5) correct |
| PLAN reds `BS46 (:581-590)` | `:582` and **`:592`** — the second call is outside the cited range — plus a third literal in the SKIPPED banner at `:585` the PLAN does not mention |
| PLAN reds `GH3 (:426-433)` | `:426-431`; `:433` is GH4 |
| PLAN reds `GH5/GH6 (:1057-1087)` | GH5 `:1078-1080`, GH6 **`:1100-1107`** — GH6 is outside the cited range entirely |
| PLAN "the eight `--nogui` files" | **14** files / 1637 checks. "Eight" is a stale single-pane figure; the correct done-when is 15 files plus three out-of-baseline suites. |
| PLAN "`set fwd` appears once in the repo" | `grep -rn 'set fwd' src/` = **4**. The *expression* appears once (`grep 'set fwd \[expr'` = 1), and "no test reads it" is **CONFIRMED** (`grep -rn 'set fwd' tests/` = 0). |
| spec §8.1 "a pure rename across 13 sites" | **12** measured literal sites (7 in `wave_viewer.tcl` — a raw grep says 11 but 4 are `Ctrl-LMB`/`Ctrl+Left`; 2 in the guide, one carrying two literals) plus the C deletion, the csv regeneration and the carve-out, which are not renames |

**THE FILE THE PLAN NEVER NAMES.** `tests/headless/test_key_graph_context.tcl`
asserts the CURRENT behaviour of exactly the row this item deletes, at `:128-134`
and `:155-157`, and is in **neither** baseline. A green 14-file / 11-suite run
proves nothing about it.

---

## 4. Two PLAN checks were VACUOUS and were replaced

**`BK02` as prescribed** was
`[lsearch -exact {97 98 100 115 109 116 65 66 77} 98] 1` — it searches a literal
the check itself wrote. Green before the code, green after, and green under the
very sabotage ("delete 98 from `graphkeys`") it was named to catch. **Replaced**
by a check that EXTRACTS `set fwd [expr {…}]` from the shipped source and
EVALUATES it for six `(N,s)` pairs. Measured red `1 1 0 1 1 1`, green
`1 0 0 1 1 1`. The membership claim moved to `BK03`, which reads the LIVE
`$::wviewer::graphkeys` and asserts the WHOLE list, so a deletion of ANY member
is visible.

**`BK06` as prescribed** used `[xschem get sym_txt]`. **Measured: that getter
does not exist** — `catch {xschem get sym_txt}` returns 0 with the result `""`.
The PLAN's landmine witness would have compared `""` to `""` and passed **with
sym_txt flipped**. Every `sym_txt` reading in this file uses the Tcl mirror
`$::sym_txt`.

---

## 5. The red run — five checks passed before the code existed

All five are declared, and none is a stability claim standing alone.

| check | why it was already green | disposition |
|---|---|---|
| `BK03` | it is the POSITIVE CONTROL: `graphkeys` must NOT change | kept; it carries the WHOLE list, so it reds under sabotage **S2** (measured) |
| `BK05` | it is `BK04`'s control: the bare-b row must survive | kept, **and `BK04` was rewritten to carry the same control in its own tuple** so `BK04` is not vacuous on "the csv is empty" |
| `BK07` leg 1 / `BK08` leg 1 | `wvproc_body` found the proc | fixture assertions; a `{}` body would make every later leg meaningless |
| `BK10` | green by design — the guide's 16/11 and grid's two literals do not move under a rename | kept and **declared in its own comment as the only permitted exception**; it is the standing guard that the rename was an EDIT and not an ADDITION |

`BK17`'s first leg was **rewritten after the red run**: it read
`bs_set [save_input_bindings_file …]`, and that proc returns the empty string, so
the leg answered 0 for a successful generation. It now asserts the generated file
holds >40 `key,` rows — otherwise a generation that silently wrote nothing would
let leg 2 compare two empty reads and pass.

**`BK18`'s real-key leg went SILENT in the red run, not red** — `send_key` on an
unbound chord burns its 200-iteration budget and prints `SKIPPED`. That is the
BS46 shape and the reason the X count is 22 red / **23** green. Diff the COUNT.

---

## 6. Existing checks RESTATED, never deleted

`tests/headless/test_wave_sigbrowser.tcl` (marked FROZEN by parent-spec ruling 30
— a warning, not a prohibition; item 11 rewrote a BT09 leg in place and that is
the precedent): **BS03 ×2, BS04, BS05, BS09 ×2, BS42, BS45 ×5, BS46 ×2 + its
banner**, all retargeted in place with a `TWO-PANE item 16 (R9)` comment. No new
`check` call, no renumbering — the file is 135 headless / 353 X either side.

`tests/headless/test_key_graph_context.tcl`, **which the PLAN never names**:

* `:128-134` — the `key 98 ctrl graph graph.forward` term dropped out of the
  conjunction and became an **explicit absence assertion** beside its positive
  control (the bare-b idle row). +1 check.
* `:155-157` — **INVERTED**. Measured on both sides of the deletion:
  `overgraph-CtrlB-toggles-sym_txt` **0 → 1**. Its surviving positive control is
  the canvas leg, measured **1 both sides**.

`test_wave_grid`'s GH1/GH3/GH5/GH6 are loops over the guide's own values — no
literal to edit, and they are the lockstep tripwire. Left alone; **sabotage S6
proves they fire**.

---

## 7. Sabotages — every one injected, proven on disk, run, restored, diffed

Driver: lock file, EXIT/INT/TERM trap, pre-state assertion (`ALL PASS (12)`),
on-disk proof of each mutation, byte-exact restore from backup (never
`git checkout --`), restore diffed. **The output filter counts NORESULT and
TIMEOUT as REDS**, which mattered twice.

| # | sabotage | fired | positive control | verdict |
|---|---|---|---|---|
| **S1a** | carve-out reverted to the old single-keysym form | `BK01`, `BK02`, `BK12`, `BK18` (real-key leg) | `test_wave_sigbrowser` **353 GREEN** — bind, menu and guide are fine, the ROUTING is not | exact |
| **S1b** | blanket `set fwd 1` after the carve-out | **TIMEOUT** | — | **red, but non-isolating**: it also defeated the Ctrl-D carve-out, so `BK14`'s Ctrl-d drive forwarded to the schematic `case 'd'`/ControlMask = `delete_files()`, a MODAL FILE DIALOG, and the suite hung. Re-run as **S1b'** |
| **S1b'** | `if {$N == 98} { set fwd 1 }` — re-opens the 98 hole ONLY, carve-out text intact | see §7.1 | | THE coverage-hole test |
| **S2** | 98 deleted from `graphkeys` instead of carved out | `BK03`, `BK13` | `test_wave_markers` **437 GREEN** (MD9 reads `graphkeys` too) | exact |
| **S3** | the BARE-b idle row deleted too (rebuild + regen) | see §7.1 | | |
| **S4** | csv HAND-EDITED (two rows swapped), C table correct | `BK17` **and nothing else in the file** (`BK04`/`BK05`/`BK06`/`BK16` all GREEN) + `test_bindings_file` | the 22 other checks | exact — this is why `BK17` sits on this item |
| **S5** | C deletion done, csv NOT regenerated | `BK04`, `BK16`, `BK17` + `test_bindings_file` | | exact, the mirror of S4 |
| **S6** | guide row renamed back, bind left at Ctrl-B | `BK09`; `test_wave_grid` **GH1 + GH3** headless and **GH1 + GH3 + GH5 + GH6** under X; `test_wave_sigbrowser` **BS09 ×2** | | **THE PLAN IS WRONG**: it says "GH1 red alone". Measured radius is **8 legs across 3 files**. |
| **S7** | chord relocated off the WaveViewer tag | `BK07`, `BK15` ×2 (+ `BK11` as collateral: the first patch called a proc that does not exist and the viewer failed to open) | | re-run as **S7'** with a valid relocation |

**Zero-red rows: none.** Every sabotage moved at least one check.

### 7.1 The two sabotages that had to be re-shaped, and the one that decided the item

**`S1b'` — THE COVERAGE-HOLE TEST.** Round 1's blanket `set fwd 1` also defeated
the Ctrl-D carve-out and hung the suite on `delete_files()`'s modal, which is a
red that isolates nothing. Re-shaped to `if {$N == 98} { set fwd 1 }` — the
carve-out TEXT stays byte-identical, so every source grep still sees it, and only
the 98 hole re-opens. **Result:**

```
ON DISK: injected lines = 1 ; carve-out text still present = 1
RESULT: 2 FAILED (21 passed)
  BK12 -> {1 1 1 0 1}  (exp {1 0 0 0 0})
  BK18 -> {1 1 1}      (exp {1 1 0})
```

`BK01` and `BK02` stayed **GREEN**. Read `BK12`'s tuple: `over 1`, `fwd 1`,
**`dsym 1` — `sym_txt` FLIPPED** — `dgf 0`, `dcvb 1`. `graph_flags` did not move
and `sym_txt` did, which is the proof that the forward reached the C switch's
`ControlMask` arm rather than the graph arm: the over_graph row it used to land
on is gone. **This is the whole justification for the two behavioural checks.**
Had `S1b'` red nothing, `BK12`/`BK18` would have been redundant with the source
greps and the item would have had no behavioural coverage at all.

**`S3` — TIMEOUT, and a correct one.** Deleting the bare-b idle over_graph row
(rebuild + regen; `regenerated 98 rows = 0` on disk) makes bare `b` fall through
to the C switch's *merge schematic*, a modal file dialog, and the keys suite
hangs. Counted as a **RED** by the driver's filter, which is exactly why the
filter must count `TIMEOUT` — an anchored `^(PASS|FAIL|RESULT)` filter would have
scored a hung suite as a clean zero. The isolating evidence came from the same
run's second suite: `test_key_graph_context` red on **two** checks, including
`:323` *"4 sem-first chords have idle_only over_graph rows"* — the free
cross-file positive control the PLAN does not know exists.

**`S7'`.** Round 1's patch called a proc that does not exist, so the viewer
failed to open and `BK11` red as collateral from the patch. Re-shaped to a real
relocation (`bind all` + a class test). **Result: `BK07` + `BK15` ×2 red,
`BK11` GREEN, everything else GREEN** — behaviourally indistinguishable, and only
the tag/sweep legs see it.

**Clean re-run after every round: `ALL PASS (12)` headless, `ALL PASS (23)` X,
`test_bindings_file` and `test_key_graph_context` GREEN. Restore diffed
byte-identical on all four held files.**

---

## 8. Declared limits

**8. A user who sets `graph_use_ctrl_key 1` loses their only cursor-B chord.**
`access_cond` (`src/callback.c:991`) is `!graph_use_ctrl_key || (state &
ControlMask)`, so in that profile bare `b` never reached cursor B and Ctrl+b was
the only way in — and Ctrl+b is now the Signal Browser. It is **commented out by
default** (`src/xschemrc:716`), and the shipped profile was **measured
unaffected**: bare `b` over a strip still moved `graph_flags` 0 → 4 and flipped
the Tcl `cvb` mirror (`BK13`). Shipped stated rather than conditioning the
carve-out on `graph_use_ctrl_key`, which would be inventing a ruling to dodge a
limit. Spec §10 limit 8.

**9. Ctrl+b over a graph EMBEDDED IN A SCHEMATIC now toggles `sym_txt`.**
**Measured 0 → 1.** Nobody asked for it; it is a consequence of R9's ruling, not
of R9's intent, and no part of the PLAN says the item changes schematic-editor
behaviour. Pinned by an INVERTED check in `test_key_graph_context.tcl` whose
surviving positive control is the canvas leg (measured 1 both sides). Spec §10
limit 9. The **viewer** is unaffected — its `key_filter` carve-out refuses the
forward before the C dispatch sees the chord.

**10. `BK18`'s real-key leg self-skips** rather than failing when `send_key`
cannot confirm delivery (the BS46 rule). Its red state is a printed `SKIPPED` and
a check COUNT of 22 instead of 23 with zero failures. **Diff the count.** The hard
oracles are `BK12` (the direct `key_filter` drive) and `BK15` (the binding).

**11. `BK18`'s search-entry leg pins a MEASURED value, not a predicted one.** Tk
maps `<<PrevChar>>` to `<Control-Key-b>`, so the browser's search entry is a
candidate consumer the old chord never had. It does not fire — the WaveViewer tag
is on the CANVAS and the entry carries neither it nor a toplevel that has it — but
`bind Entry <Control-Key-b>` answering `{}` is **not** evidence of that (the
binding is on the virtual event). The expected literal comes from the run.

---

## 9. The csv regeneration trap, measured

`save_input_bindings_file` writes the LIVE table, and the shipped csv is
**loaded into that table at startup**. Regenerating with the old file still in
place therefore reproduced the deleted row — merely **moved to the end of the
file** (`23d22 < key,98,ctrl,… / 67a67 > key,98,ctrl,…`), which is a diff a
careless eye reads as "reordered, harmless". The correct operation is to move the
csv aside and generate from the **builtins**: the result is the previous file
minus exactly one line, in place (`23d22`, nothing else).

`XSCHEM_SHAREDIR` resolves to `<repo>/src` for an in-tree run, so
`src/keybindings.csv` is the file and there is no `~/.xschem/keybindings.csv` to
shadow it.

---

## 10. Bookkeeping

* **`NEXT FREE IN THIS FILE: BK19.`** `BK01-BK18` are spent. `BK20+` belongs to
  two-pane item 17b by the PLAN; taking it would repeat the item-10/item-12
  `BW40` collision.
* Nothing here is a pixel deliverable — every claim is a bind, a dump row, a file
  byte-compare or a Tcl variable. **No eyeball is owed.**
* `test_wave_sigbrowser.tcl` is marked FROZEN. It was retargeted **in place**,
  with attribution on every leg, nothing deleted and nothing renumbered —
  item 11's BT09 rewrite is the precedent.
* Spec §8.1 anchors were corrected in place and its two wrong claims replaced
  with the measurements; §10 gained limits 8 and 9; §13 gained the eighth test
  file and the three-out-of-baseline-suites warning. **Item 19 should re-check
  §8.1's line numbers once more** — they moved again when this item rewrote the
  paragraph.
