# Item 16 — R9: Ctrl-L → Ctrl-B, incl. the C-table row deletion

Two-pane item 16 (**not** single-pane item 16). Spec
`doc/claude/specs/waveform_signal_browser_two_pane.md` R9, §8.1, §10, §13.
**One commit, `08c37980`, unpushed** — bind, `key_filter` carve-out, C-table row
deletion, csv regeneration and guide rename together, plus one new test file and
three existing test files restated.

Verdict **DONE**, `[x]`. **No eyeball is owed** (§11).

---

## 1. The baselines, re-measured on the UNCHANGED tree first

Both reproduced exactly before a line was written, so every red afterwards is
attributable to this item.

| arm | recorded | measured before | after item 16 |
|---|---|---|---|
| headless, 14 files | **1637**, 0 fail | **1637**, 0 fail | **1649**, 0 fail, over **15** files |
| X, 11 suites (`xarm.sh suites`, `SUITE_TIMEOUT=400`) | **11/11**, 2192 | **11/11**, 2192 | **12/12**, **2215** |

Per-file headless, after: sigsearch 146, sea 6, sigbrowser 135, 2pane 108,
panes 15, i11 50, i12 40, i1315 88, i14 56, grid 231, modes 212, viewer 57,
markers 437, tabs 56, **keys 12**. The fourteen pre-existing files sum to
**exactly 1637** and every per-file figure is byte-identical to the record.

Per-suite X, after: panes 81, sigbrowser 353, sea 79, i11 74, i12 123, i1315 190,
i14 107, 2pane 108, sigsearch 233, grid 356, modes 488 (sum **2192**, every
baseline suite byte-identical), **keys 23** → **2215**.

**The whole delta is one new file.** `tests/headless/test_wave_sigbrowser_keys.tcl`
is +12 headless and +23 under X. Nothing else moved in either arm.

**THREE out-of-baseline suites, not the two the LEDGER's item-16 note named.**
`test_key_graph_context.tcl` is in **neither** baseline and is the one this item
actually reds — twice. Pre → post ok-counts, measured: **13 → 13** / **17 → 17** /
**69 → 70**. All three are **X-only**: the two binding suites throw under
`--nogui` (`invalid command name "focus"` / `"winfo"`), so their figures are
reproducible only through `xarm.sh one <suite>`.

**Not adopted from the implementer's run.** The verifier re-measured both arms
independently: all 15 headless files run by hand, and 12/12 through `xarm.sh
suites` under Xvfb. It also confirmed the keys suite printed **no `SKIPPED`
line** — so `BK18`'s real-key leg really fired and 23 is not a masked 22 (§10
limit 3). Before measuring anything it ran `cd src && make`, which answered
*"Nothing to be done for all"*, proving the shipped binary was built from the
committed `callback.c`.

---

## 2. ⚠⚠ THE PLAN NEVER NAMES THE FILE THIS ITEM ACTUALLY REDS

`tests/headless/test_key_graph_context.tcl` asserts the **current behaviour of
exactly the row this item deletes**, at two sites, and is in neither baseline. A
green 15-file / 12-suite run proves nothing about it. The PLAN's break list, the
work order and the LEDGER's own item-16 note all miss it.

* `:128-134` *"Group B over_graph rows present"* — a conjunction that includes
  `key 98 ctrl graph graph.forward`.
* `:155-157` *"over-graph Ctrl+b leaves sym_txt"* — the behavioural half.

Both went red on the item, and both are **restated rather than deleted** (§8).
The count moved **69 → 70**.

**Proved from the other side, by the verifier, not taken on trust:** the
*pre-item* copy of that file was checked out under a non-`test_*` name and run
against the **new** binary → **67 ok + 2 FAIL = 69**, the two failures being
exactly those two claims, the second printing `(0 == 1)`. So the 69 baseline is
real, the two reds are real, and declared limit 9 is a measurement rather than a
deduction. Probe removed; `tests/headless/` clean afterwards.

**And the PLAN's break list is wrong a second time.** It predicts sabotage S6
("guide row renamed back") reds *"GH1 alone"*. **Measured radius: 8 legs across
3 files** — `BK09`; `test_wave_grid` GH1+GH3 headless and GH1+GH3+GH5+GH6 under
X; `test_wave_sigbrowser` BS09 ×2. The PLAN's claim was true only *before* this
item retargeted the BS legs.

---

## 3. What the PLAN and the spec got wrong, with the measurement that says so

### 3.1 Anchors

| cited | actual |
|---|---|
| PLAN §1 `wave_viewer.tcl:9372-9373` (guard + bind) | `:11642-11643` before the item, `:11668-11670` after. **+2270 / +2296** |
| PLAN §1 the rejection paragraph `:9364` | `:11634-11637` before, rewritten to `:11628-11667` after |
| PLAN §2 `key_filter`'s graphkeys arm `:11214` | `set fwd` at `:13484` before, **`:13520`** after |
| spec §8.1 `:9288-9291` and `:11130-11139` | both stale by ~+2300; corrected in the spec, in place |
| PLAN §4 `test_bindings_file.tcl:28-31` | the keybindings byte-compare is `:29-30` (`:31-32` is the mousebindings twin) |
| PLAN reds `BS05 (:143) leg 1` | `:144`, and it is BS05's **second** `check_true` |
| PLAN reds `BS42 (:531)` | `:535-538`, literal on `:538` |
| PLAN reds `BS45 (:560-570)` | `:563-574`; the count (5) is correct |
| PLAN reds `BS46 (:581-590)` | `:582` and **`:592`** — the second call is outside the cited range — plus a third literal in the `SKIPPED` banner at `:585` the PLAN does not mention |
| PLAN reds `GH3 (:426-433)` | `:426-431`; `:433` is GH4 |
| PLAN reds `GH5/GH6 (:1057-1087)` | GH5 `:1078-1080`, GH6 **`:1100-1107`** — GH6 is outside the cited range entirely |

Anchors that were **exact**: `callback.c:4988` (the deleted row), `:991`
(`access_cond`), `:1647` (bare `b`), `:6035` (the `ControlMask` arm),
`keybindings.csv:23`, `xschemrc:716`, `wave_viewer.tcl:320` (`graphkeys`) and
`:347`, guide `:483-490`, and every BS/GH leg *count*.

### 3.2 Numbers

1. **The band.** PLAN gives item 16 `BK01`-`BK09`. Measured free by three greps
   (zero shipped `BK` ids anywhere in `tests/` or `doc/claude/`), so the band
   `BK01`-`BK19` was taken and **`BK01`-`BK18` are spent, next free `BK19`**.
   `BK20+` is item 17b's by the PLAN; taking it would repeat the
   item-10/item-12 `BW40` collision. Re-greped by the verifier across
   `BK01`-`BK29`: no collision.
2. **PLAN "`set fwd` appears once in the repo".** `grep -rn 'set fwd' src/` =
   **4**. The *expression* appears once (`grep 'set fwd \[expr'` = 1), and *"no
   test reads it"* is **CONFIRMED** (`grep -rn 'set fwd' tests/` = **0**). That
   zero is the item's whole justification for a new file.
3. **PLAN "the eight `--nogui` files".** The recorded headless baseline is
   **14** files / 1637 checks. "Eight" is a stale single-pane-batch figure; the
   correct done-when is **15** files plus three out-of-baseline suites.
4. **Spec §8.1 "a pure rename across 13 sites".** **12** measured literal edit
   sites: `wave_viewer.tcl` **7** (a raw grep says 11, but 4 are `Ctrl-LMB` /
   `Ctrl+Left` false positives), the guide **2** lines (one carrying two
   literals), plus the C deletion, the csv regeneration and the carve-out —
   which are not renames. 13 is defensible only if the rewritten rejection
   paragraph counts as a site.
5. **The binding table has no count oracle.** `[llength [xschem bindings dump]]`
   = **72** rows and `keybindings.csv` = **67** lines before the item; no test
   asserts either, so the deletion moves 72 → 71 and 67 → 66 with nothing to
   satisfy. This is why `BK16` reads the specific **row**, not the length.
6. **GH0's 16/11 and BT09/BX13 do not move**, as the PLAN says — confirmed:
   `grep -c 'data-seq="'` = 16 and the menu/accel pairs = 11, both unchanged by
   a rename. Those are the checks that would catch a rename done by **adding** a
   guide row instead of editing one.

---

## 4. Four traps that cost real time — all found by running

### 4.1 ⚠⚠ REGENERATING THE CSV IN PLACE REPRODUCES THE ROW YOU JUST DELETED

`save_input_bindings_file` writes the **live** table, and the shipped csv is
**loaded into that table at startup**. Regenerating with the old file still in
place therefore wrote the deleted row back — merely **moved to the end of the
file** (`23d22 < key,98,ctrl,… / 67a67 > key,98,ctrl,…`), a diff a careless eye
reads as "reordered, harmless".

The correct operation is to **move the csv aside and generate from the
builtins**: the result is the previous file minus exactly one line, in place
(`23d22`, nothing else). `XSCHEM_SHAREDIR` resolves to `<repo>/src` for an
in-tree run, so `src/keybindings.csv` is the file and no `~/.xschem/` copy
shadows it.

### 4.2 ⚠⚠ THE X FIXTURE HAS TO PLOT TWO STRIPS, AND RE-ESTABLISH CONTEXT EVERY DRIVE

The PLAN mentions neither, and the item cannot be tested without both.

`key_filter` forwards a graphkey only when `over_graph` is true, and `over_graph`
consults `graphbb` — **empty on a viewer with nothing plotted**. Measured on the
bare BSV fixture: `over_graph` answers **0 at every pixel**, every graphkey is
swallowed, and a landmine check written on that fixture is green *for a reason
unrelated to the carve-out*. `mq_layout`'s recipe (from `test_wave_markers`)
makes `graphbb` cover the canvas.

A context re-establish loop is **mandatory** beside it: with a single `switch`
before the block, drive 1 saw `over_graph 1` and **drives 2-6 all saw 0**.

### 4.3 THE PLAN'S OWN LANDMINE WITNESS COULD NOT READ THE LANDMINE

`BK06` as prescribed used `[xschem get sym_txt]`. **Measured: that getter does
not exist** — `catch {xschem get sym_txt}` returns 0 with the result `""`. The
check would have compared `""` to `""` and **passed with `sym_txt` flipped**.
Independently re-probed by the verifier, same answer. Everything in the file
reads the Tcl mirror `$::sym_txt`. See §7.

### 4.4 ⚠⚠ `cp -p` + `make` SILENTLY KEEPS THE SABOTAGED BINARY — A DRIVER HAZARD

Found by the **verifier**, hitting it in its own driver. Restoring `src/callback.c`
from a `cp -p` backup and re-running `make` is a **no-op**: `cp -p` preserves the
*original* mtime, which is older than the `callback.o` the sabotage just built,
so `make` prints *"Nothing to be done for all"* and the binary keeps the
**sabotaged object file**. A "clean re-run" measured in that state is measuring
the sabotage. Remedy: `touch src/callback.c && make`, or restore without `-p`.

**Consequence recorded honestly:** if the item's own driver used `cp -p` for the
two C-side sabotages (S4/S5), their post-sabotage clean re-runs are not
trustworthy on their own merits. They are independently corroborated by the
verifier's `SV-A` (§6.3), which covers the same code from a different angle and
whose re-measurements were made on a correctly rebuilt binary.

---

## 5. What landed

### Source

* **`src/wave_viewer.tcl`** — the guard and `bind WaveViewer <Control-Key-b>
  {wviewer::browser_toggle_at %W; break}`; the `build_menubar` checkbutton
  accelerator `Ctrl+B`; the **`key_filter` carve-out**, which is the item's real
  content:

  ```tcl
  set fwd [expr {!(($N == 100 || $N == 98) && ($s & 4))}]
  ```

  i.e. keysym 98 gains a **modifier** carve-out beside Ctrl-d's. **`graphkeys`
  itself is untouched** — `{97 98 100 115 109 116 65 66 77}` — so bare `b` still
  reaches the C side and still toggles cursor B. The old *"Ctrl-B was considered
  and rejected"* paragraph is **rewritten in place**, not deleted, so the record
  of the reversal survives.
* **`src/callback.c`** — `set_input_binding(DEV_KEY, 'b', ControlMask,
  ACTX_OVER_GRAPH, "graph.forward")` **deleted** (was `:4988`). The bare-`b`
  idle over_graph row is **kept** — deleting it is sabotage S3 and it hangs the
  suite (§6.2).
* **`src/keybindings.csv`** — **regenerated from the builtins**, never
  hand-edited (§4.1). Previous file minus exactly one line.
* **`doc/waveform_viewer_guide.html`** — the one row's `data-seq`, `data-accel`
  and `<kbd>` renamed. An **edit**, not an addition — which is what keeps GH0's
  16/11 and BX13 green.
* **`doc/claude/specs/waveform_signal_browser_two_pane.md`** — §8.1's stale
  anchors corrected and its **two wrong claims replaced with the measurements**
  (§9); §10 gained limits 8 and 9; §13 gained the eighth test file and the
  three-out-of-baseline-suites warning.

### Tests

* **`tests/headless/test_wave_sigbrowser_keys.tcl` — NEW**, band `BK01`-`BK18`,
  **12 headless / 23 under X**. Carries the two behavioural checks that are the
  only things in the repo able to see `set fwd` (`BK12`, `BK18`), the live
  `graphkeys` whole-list control (`BK03`), the live `xschem bindings dump` row
  (`BK16`) and the csv-generation byte-compare (`BK17`).
* **`tests/headless/test_wave_sigbrowser.tcl`** — retargeted **in place**. **353
  check calls before and after**, and the verifier confirmed the **set of BS ids
  is byte-identical** between `08c37980^` and `08c37980` (sorted-unique diff
  empty): nothing deleted, nothing renumbered, no new `check` call.
* **`tests/headless/test_key_graph_context.tcl`** — one claim restated as an
  explicit **absence**, one **inverted**; **69 → 70**.

**On the "how many legs were retargeted" nit, settled by measuring instead of
asserting.** Three different numbers appeared in the drafts (12, 13, 14). The
measurable facts are: **23** lines carrying a `Ctrl-L` literal removed, **28**
carrying a `Ctrl-B` literal added, of which **6** are the `TWO-PANE item 16 (R9)`
attribution comments → **22** non-comment lines. The leg *label* is not a
measured quantity and should not be quoted; **353/353 and the identical id set
are**, and they are what proves the file was retargeted rather than rewritten.

---

## 6. Sabotages — RUN

Driver: lock file, `EXIT`/`INT`/`TERM` trap, a **pre-state count asserted before
every patch** (`ALL PASS (12)`), a post-write re-read proving the mutation is
really on disk, byte-exact restore from backup (never `git checkout --`), and the
restore diffed. **The output filter counts `NORESULT` and `TIMEOUT` as REDS** —
which mattered twice: two sabotages hung on C modal dialogs, and an anchored
`^(PASS|FAIL|RESULT)` filter would have scored a hung suite as a clean zero.
**No row scored zero.** Clean re-run after every round.

### 6.1 The item's own nine

| # | sabotage | failed **exactly** | reds | positive control | reverted |
|---|---|---|---|---|---|
| **S1a** | carve-out reverted to the old single-keysym form | **yes** | `BK01`, `BK02`, `BK12`, `BK18` (real-key leg) — 4 red / 19 green | `test_wave_sigbrowser` **353 ALL PASS** — bind, menu and guide untouched, only the ROUTING broken | yes |
| **S1b** | blanket `set fwd 1` after the carve-out | **no** | **TIMEOUT** (counted red) | — | yes |
| **S1b′** | `if {$N == 98} { set fwd 1 }` — re-opens the 98 hole only, carve-out text byte-identical | **yes** | `BK12`, `BK18` — 2 red / 21 green | `BK01`+`BK02` stay **GREEN** (the source is intact) | yes |
| **S2** | 98 **deleted** from `graphkeys` instead of carved out | **yes** | `BK03`, `BK13` — 2 red / 21 green | `test_wave_markers` **437 ALL PASS** (MD9 reads `graphkeys` too) | yes |
| **S3** | the **bare-b** idle over_graph row deleted too (rebuild + regen) | **no** | keys suite **TIMEOUT**; `test_key_graph_context` red on 2 incl. `:323` | `:323` itself — the free cross-file control the PLAN does not know exists | yes |
| **S4** | `keybindings.csv` **hand-edited** (two rows swapped), C table correct | **yes** | `BK17` **alone** — 1 red / 22 green — + `test_bindings_file` | `BK04`, `BK05`, `BK06`, `BK16` all **GREEN**: a csv edit cannot unbind anything | yes |
| **S5** | C row deleted, csv **not** regenerated | **yes** | `BK04`, `BK16`, `BK17` — 3 red / 20 green — + `test_bindings_file` | the exact mirror of S4 | yes |
| **S6** | guide row renamed back to Ctrl-L, bind left at Ctrl-B | **yes** | **8 legs / 3 files**: `BK09`; grid GH1+GH3 headless, GH1+GH3+GH5+GH6 under X; `BS09` ×2 | the bind/menu legs stay green — it is a *documentation* drift | yes |
| **S7** | chord relocated off the `WaveViewer` tag | **no** | `BK07`, `BK15` ×2 **plus `BK11` as collateral from my own patch** | — | yes |
| **S7′** | chord on a `bind all` + a class test instead | **yes** | `BK07`, `BK15` ×2 — 3 red / 19 green, `BK11` **GREEN** | `BK12`/`BK18` stay green — behaviourally indistinguishable, which is the point | yes |

**Zero-red rows: none.**

### 6.2 The three rounds that had to be re-shaped, and the one that decided the item

**`S1b′` — THE COVERAGE-HOLE TEST, and the result that decided the item.**
Round 1's blanket `set fwd 1` also defeated the **Ctrl-D** carve-out, so `BK14`'s
Ctrl-d drive forwarded to the schematic `case 'd'` / ControlMask =
`delete_files()`, **a modal file dialog**, and the suite hung — a red that
isolates nothing. Re-shaped to `if {$N == 98} { set fwd 1 }`, which leaves the
carve-out **text byte-identical** so every source grep still sees it and only the
98 hole re-opens:

```
ON DISK: injected lines = 1 ; carve-out text still present = 1
RESULT: 2 FAILED (21 passed)
  BK12 -> {1 1 1 0 1}  (exp {1 0 0 0 0})
  BK18 -> {1 1 1}      (exp {1 1 0})
```

`BK01` and `BK02` stayed **GREEN**. Read `BK12`'s tuple: `over 1`, `fwd 1`,
**`sym_txt` FLIPPED**, `graph_flags` **unmoved**, `cvb` moved. `graph_flags` did
not move and `sym_txt` did — proof the forward reached the C switch's
`ControlMask` arm rather than the graph arm, because the over_graph row it used
to land on is gone. **Had `S1b′` red nothing, `BK12`/`BK18` would have been
redundant with the source greps and the item would have had no behavioural
coverage at all.**

**`S3` — TIMEOUT, and a correct one.** With no over_graph row at all, bare `b`
falls through to the C switch's *merge schematic* modal (`regenerated 98 rows = 0`
on disk). Its isolating evidence came from the same run's **second** suite:
`test_key_graph_context` red on two checks including `:323` *"4 sem-first chords
have idle_only over_graph rows"*.

**`S7′`.** Round 1's patch called `wviewer::all_canvases`, which does not exist,
so the viewer failed to open and `BK11` red **as collateral from my own patch**
rather than from the relocation. Re-shaped to a real relocation.

### 6.3 ⚠⚠ THE VERIFIER'S OWN TWO SABOTAGES — NEITHER ON THE LIST ABOVE

Both aimed at the item core, both applied with a pre-state assertion, proven on
disk, run, then reverted from byte-exact backups and **md5-verified**.

**`SV-A` — "THE C HALF OF THE ITEM NEVER HAPPENED, DONE TIDILY."** The item only
ever tested the *inconsistent* halves: S4 hand-edits the csv while C is correct,
S5 deletes the C row while the csv is stale. Neither covers the likeliest
real-world half-done state: **the `callback.c` row still present AND the csv
correctly regenerated to match it**, with the Tcl carve-out, bind, menu and guide
all shipped. In that state the **viewer behaves perfectly** — `key_filter`
refuses the forward, so `BK12` cannot see it — which is exactly the shape a
green-but-hollow test set misses.

> **It red.** headless keys **2 FAILED / 10 passed** (`BK04`, `BK06`); X keys
> **3 FAILED / 20 passed** (`BK04`, `BK06`, `BK16` — the live `bindings dump`
> row); `test_key_graph_context` **2 FAILED / 68 passed** — *both* restated
> claims, the explicit absence and the inverted behavioural leg, the latter
> printing `(0 -> 0)`, i.e. `sym_txt` correctly stopped toggling.
> `test_bindings_file` stayed **ALL PASS 13**, which is right: C and csv agree,
> so byte-identity holds. Counts held exactly on every run (10+2=12, 20+3=23,
> 68+2=70) — no silent early abort.

**Verdict: the C-table deletion is genuinely covered, by four checks in two files
rather than the one the PLAN predicted.**

**`SV-B` — `($s & 4)` → `($s == 4)`.** A one-character narrowing that keeps the
bitmask *idea* but makes it an exact match, so **Ctrl+Alt+b** (`s=12`) and
**NumLock+Ctrl+b** (`s=20`) start forwarding again and flip `sym_txt` behind the
browser. Chosen because `BK02` was predicted **blind** to it: `BK02` evaluates
the shipped expression for six `(N,s)` pairs whose masks are only ever 0 or 4,
and all six answers are identical under `&` and `==`. `BK12`/`BK14` drive `s=4`
only, so they are blind too.

> **It red `BK01` alone**, both arms (headless 1/11, X 1/22), counts held. The
> suite is **not** hollow — but the only witness is an exact source-text regexp.
> **Non-blocking** (the shipped code uses `&`, the correct NumLock-safe form),
> **recorded as an open coverage note**: one extra pair, `{98 12}`, closes it.
> See §11.

Both reverted, md5 clean, clean re-run **ALL PASS (12)**.

---

## 7. Checks that were VACUOUS on the red run, and what was done about them

The red run is the only reason any of this is known. *A check that passes before
you wrote the code is a check to stop and look at.*

| check | why it was already green | disposition |
|---|---|---|
| `BK02` **as the PLAN prescribed it** | `[lsearch -exact {97 98 100 115 109 116 65 66 77} 98] 1` — it searches **a literal the check itself wrote**. Green before the code, green after, and **green under the very sabotage (S2) it was named to catch.** | **REPLACED.** The id now EXTRACTS `set fwd [expr {…}]` from the shipped source and EVALUATES it for six `(N,s)` pairs: measured red `1 1 0 1 1 1`, green `1 0 0 1 1 1`. Proven non-vacuous by `S1b′`. Its blind spot is `SV-B` (§6.3, §11). |
| `BK06` **as the PLAN prescribed it** | used `[xschem get sym_txt]`, which **does not exist** and returns `""` — the landmine witness would have compared `""` to `""` **with `sym_txt` flipped**. | **REPLACED** with the Tcl mirror `$::sym_txt`. Reds under `SV-A`. |
| `BK03` | it is the declared **positive control**: `graphkeys` must NOT change | **KEPT, and strengthened past the PLAN's version**: it reads the LIVE `$::wviewer::graphkeys` and asserts the **whole list** byte-exactly, so a deletion of *any* member is visible. **S2 proves it fires.** |
| `BK05` | it is `BK04`'s control — the bare-b csv row must survive | **KEPT, and `BK04` was rewritten** to carry the same control as leg 2 of its own tuple, so `BK04` is no longer vacuous on "the csv is empty" / "the regeneration wrote nothing". |
| `BK07` leg 1, `BK08` leg 1 | `wvproc_body` found the proc | **KEPT as fixture assertions.** A `{}` body would make every later leg of those ids meaningless while looking green. |
| `BK10` | green **by design**, before and after | **KEPT and declared in its own comment as the file's only permitted exception.** It is the standing guard that the rename was an **EDIT** of the guide's one row and not an **ADDITION** of a second — a distinction GH0's 16/11 counts cannot make alone. Sabotage-invisible by construction: it is a tripwire, not coverage. |
| `BK13`, `BK14` ×2, `BK18`'s search-entry leg | stability claims about things this item must **not** change | **KEPT.** None is a bare "nothing changed": `BK13` reds under S2 and S3; `BK18`'s entry leg is the measured pin on a **new** collision class (§10 limit 4). |
| `BK17` leg 1 | **not a red-run pass but a red-run DEFECT found the same way**: it read `bs_set [save_input_bindings_file …]`, and that proc returns the **empty string**, so the leg answered 0 for a perfectly good generation | **REWRITTEN** to assert the generated file holds >40 `key,` rows — otherwise a generation that silently wrote nothing would let leg 2 compare two empty reads and pass. |
| `BK18`'s real-key leg | **did not go red — it went SILENT.** `send_key` on an unbound chord burns its 200-iteration budget and prints `SKIPPED`, dropping the X count 23 → 22 **with zero failures** (the BS46 shape) | **KEPT self-skipping deliberately**, with `BK12` as the hard oracle beside it, because its only signal cannot distinguish a WSLg delivery stall from a broken binding. **Its red state is a count shortfall — diff the COUNT, not the fail count.** §10 limit 3. |

---

## 8. Every existing check restated, and why

**Nothing was deleted. Nothing was renumbered. No new `check` call was added to
any existing file except the one absence claim in §8.2.**

### 8.1 `tests/headless/test_wave_sigbrowser.tcl` — retargeted in place

`BS03` ×2, `BS04`, `BS05`, `BS09` ×2, `BS42`, `BS45` ×5, `BS46` ×2 and its
`SKIPPED` banner: every `Ctrl-L` literal became `Ctrl-B`, each with a
`TWO-PANE item 16 (R9)` comment. **135 headless / 353 X on both sides**, and the
BS id set is byte-identical across the commit.

The file is marked **FROZEN** by parent-spec ruling 30. That is a **warning, not
a prohibition**, and item 11's in-place `BT09` rewrite is the precedent followed.
A rename that left these legs on the old chord would be a lie in the test suite,
not a preserved baseline.

### 8.2 `tests/headless/test_key_graph_context.tcl` — the file the PLAN never names

* `:128-134` — the `key 98 ctrl graph graph.forward` term **dropped out of the
  conjunction and became an explicit ABSENCE assertion**, placed beside its
  positive control (the bare-b idle row, which is *not* deleted). **+1 check,
  69 → 70.** This is the one new call in an existing file, and `SV-A` reds it.
* `:155-157` — **INVERTED**, not deleted:
  *"over-graph Ctrl+b leaves `sym_txt`"* → *"over-graph Ctrl+b now TOGGLES
  `sym_txt` too (two-pane item 16 deleted the graph routing row, so the canvas
  arm owns the chord everywhere)"*. **Measured both sides of the deletion: 0 → 1.**
  Its surviving positive control is the canvas leg
  (*"canvas Ctrl+b toggles sym_txt"*, measured **1 both sides**), which is what
  makes the inverted leg a **routing** statement rather than a *"Ctrl+b is
  broken"* statement.

### 8.3 `tests/headless/test_wave_grid.tcl` — GH1, GH3, GH5, GH6: LEFT ALONE ON PURPOSE

They are **loops over the guide's own `data-seq` / `data-accel` values**, so they
carry no literal to edit and they red the instant the guide and the source drift.
That is the four-file lockstep tripwire, and **S6 fired all four**. `grid` is 231
headless / 356 X on both sides.

### 8.4 Frozen oracles confirmed unmoved

`GH0`'s 16/11, `GH2`, `GH4`, `GH8`'s 16, `GH9`, `GH10`, `GS0`-`GS3`, `BT09`'s
`{16 11}` and `{0 0}`, `BX13`, `BS01`/`BS02`, `BT08`/`BP07`, `MD9`, `EG8`,
`test_key_graph_context:135-137`, `:150-152`, `:323`, and the whole item-12
`.ph` carry-in (`BD52`, `BX37`, `BX42`, `BX44`-`BX46`, `BH50`, `BH51`, `BH54`) —
**all measured green, all untouched.** Named here so the record says *checked*,
not *assumed*.

**The bare-name landmine was re-greped, and it is the one that catches
comments.** Every accessor this commit newly names in a `wave_viewer.tcl`
**comment** (`browser_toggle_at`, `strip_bindings`, `clone_canvas_bindings`,
`waves_callback`, `sync_browser_mirror`, `over_graph`, `key_filter`,
`browser_show`, `browser_from_menu`, `graphkeys`) was checked against every
file-wide `$wsrc` bare-name count in the repo. The only such counts are
`browser_alldbs` == 2 (`i14:355`) and `browser_devint` / `browser_srccur`
(`panes:923`) — **no overlap**, and both suites are green. Item 12's §4.1 rule
held.

---

## 9. Every divergence

1. **`BK02` replaced** — the PLAN's version was vacuous (§7).
2. **`BK06` replaced** — the PLAN's oracle does not exist (§4.3, §7).
3. **The id layout diverges from the PLAN's `BK01`-`BK09`.** The band
   `BK01`-`BK19` was measured free; `BK01`-`BK18` are spent. The PLAN's
   `BK05`/`BK06`/`BK07` semantics were redistributed, and the two real-event
   claims (search entry, canvas) share **`BK18` as two legs of one question** —
   *where does a real event land* — rather than spilling into `BK19` and
   colliding with item 17b.
4. **The X fixture plots two strips and re-establishes context every drive**
   (§4.2). The PLAN mentions neither and the item is untestable without both.
5. **The PLAN's break list is wrong about S6** — "GH1 alone" vs a measured 8 legs
   across 3 files (§2).
6. **The PLAN never names `test_key_graph_context.tcl`** (§2), and the LEDGER's
   item-16 note says *two* out-of-baseline binding suites when it is **three**.
   Both corrected in the LEDGER.
7. **The PLAN's done-when says "the eight `--nogui` files"** — stale; it is 15
   files plus three out-of-baseline suites (§3.2).
8. **Spec §8.1 had two wrong claims, both corrected with the measurement.**
   (a) *"Nothing user-visible is lost … `callback.c:1647` handles `'b'` with no
   modifier test at all"* — it is `else if(key == 'b' && access_cond)`, i.e.
   **gated**; the shipped-default half was measured true, the
   `graph_use_ctrl_key` half is now **limit 8**. (b) *"The schematic side is
   untouched"* — deleting the over_graph row is exactly what changes it (measured
   0 → 1), now **limit 9**. Its *"pure rename across 13 sites"* is **12**
   measured literal sites. All of §8.1's line anchors were stale by ~+2300 and
   are corrected in place — **item 19 must re-check them once more**, because the
   paragraph rewrite moved them again.
9. **Two sabotages were re-run in a different shape**, and both round-1 versions
   are reported rather than hidden (§6.2): `S1b`'s blanket also defeated the
   Ctrl-D carve-out and hung on `delete_files()`'s modal; `S7`'s first patch
   called a proc that does not exist, so `BK11` red as collateral from my own
   patch.
10. **The csv regeneration needed a step the PLAN does not describe** (§4.1).
11. **The "how many legs" figure was retired rather than picked.** Three drafts
    carried three different numbers; the measured facts (353/353, identical id
    set, 23 removed / 28 added / 6 comments) are reported instead (§5).

---

## 10. Declared limits

**1 (spec §10 limit 8). A user who sets `graph_use_ctrl_key 1` loses their only
cursor-B chord.** `access_cond` (`src/callback.c:991`) is `!graph_use_ctrl_key ||
(state & ControlMask)`, so in that profile bare `b` never reached cursor B and
Ctrl+b was the only way in — and Ctrl+b is now the Signal Browser. It is
**commented out by default** (`src/xschemrc:716`; `xschem.tcl:15684` defaults it
to 0), and the shipped profile was **measured unaffected**: bare `b` over a strip
still moved `graph_flags` 0 → 4 and flipped the Tcl `cvb` mirror (`BK13`).
Shipped **stated** rather than conditioning the carve-out on `graph_use_ctrl_key`
— that would be inventing a ruling to dodge a limit. Premise independently
confirmed in the source by the verifier.

**2 (spec §10 limit 9). Ctrl+b over a graph EMBEDDED IN A SCHEMATIC now toggles
`sym_txt`. Measured 0 → 1.** Nobody asked for it; it is a consequence of R9's
ruling, not of R9's intent, and **no part of the PLAN says this item changes
schematic-editor behaviour** — this is the first item in the batch that does.
Pinned by an **inverted check** whose surviving positive control is the canvas
leg (measured 1 both sides), so the next reader finds a record instead of filing
a bug. The **viewer** is unaffected: its `key_filter` carve-out refuses the
forward before the C dispatch sees the chord. Confirmed independently by running
the pre-item `test_key_graph_context.tcl` against the new binary (§2).

**3. `BK18`'s real-key leg SELF-SKIPS** rather than failing when `send_key`
cannot confirm delivery (the BS46 rule). **Its red state is a printed `SKIPPED`
line and an X count of 22 instead of 23 with zero failures.** Any later verifier
must **diff the COUNT**. The hard oracles are `BK12` (the direct `key_filter`
drive) and `BK15` (the binding shape). On the accepted run the line did **not**
print, so 23 is real.

**4. `BK18`'s search-entry leg pins a MEASURED value, not a predicted one.** Tk
maps `<<PrevChar>>` to `<Control-Key-b>`, so the browser's search entry is a
candidate consumer the old chord never had. It does not fire — the `WaveViewer`
tag is on the **canvas** and the entry carries neither it nor a toplevel that has
it — but `bind Entry <Control-Key-b>` answering `{}` is **not** evidence of that,
because the binding is on the virtual event. The expected literal comes from the
run.

**5. `BK02` cannot distinguish `($s & 4)` from `($s == 4)`.** Its six `(N,s)`
pairs use only masks 0 and 4; `BK12`/`BK14` drive `s=4`. A narrowing that leaks
**Ctrl+Alt+b** and **NumLock+Ctrl+b** through to the C switch is caught **only**
by `BK01`'s exact source-text regexp. Found by the verifier's `SV-B` (§6.3).
Non-blocking — the shipped expression uses `&`, the correct form — and the remedy
is one extra pair (§11).

**6. The X arm was measured under Xvfb** (`xarm.sh`, unattended window), which
has **no window manager**, so no decoration / iconify / stacking / raise /
geometry claim is testable there. Nothing in this item needs one — every claim is
a bind, an `xschem bindings dump` row, a file byte-compare or a Tcl variable —
and the batch has measured the Xvfb arm to reproduce the `:0` arm exactly.

---

## 11. Owed / for the next item

* **Item 16 unblocks item 17b** (R10's `Ctrl-Alt-V` via the C action registry)
  and, with 13, item 18. `BK20+` is item 17b's band; **`BK19` is this file's next
  free id** and belongs to item 16's file only.
* **⚠ ONE OPEN COVERAGE NOTE, from the verifier's `SV-B`.** `BK02` is blind to a
  `&` → `==` narrowing in the carve-out. **Whoever next touches
  `test_wave_sigbrowser_keys.tcl` should add the pair `{98 12}`** (Ctrl+Alt+b) to
  `BK02`'s table, and ideally `{98 20}` (NumLock+Ctrl+b). One line, and it closes
  the last mask-shaped hole. The shipped code is correct; this is about the
  oracle, not the behaviour.
* **⚠ THE THREE OUT-OF-BASELINE SUITES MUST BE RUN BY HAND, UNDER X.**
  `test_bindings_file` (13), `test_keybindings_help` (17) and
  `test_key_graph_context` (**70**) are in neither baseline, and the last is the
  one this item moved. **Both binding suites throw under `--nogui`** — a green
  15-file / 12-suite run proves nothing about any of them. Item 17b touches the
  same C table and will move them again.
* **⚠ `cp -p` + `make` is a no-op** (§4.4). Any driver restoring a `.c` file from
  a timestamp-preserving backup must `touch` it before rebuilding, or its "clean
  re-run" is measuring the sabotage.
* **⚠ Item 19 must re-check spec §8.1's line anchors once more.** They were
  corrected in place here, and then the paragraph rewrite moved them again. §13's
  file list and §10's limits 8 and 9 are current as of this commit.
* **⚠ Limit 9 is loud on purpose.** Ctrl+b over a schematic-embedded graph
  toggling `sym_txt` is exactly the kind of thing a later reader files as a bug.
  It is spec-mandated, declared, and pinned by a check with a surviving positive
  control. Do not "fix" it without reopening R9.
* **NO EYEBALL IS OWED**, which is worth stating because this batch usually owes
  one. Every claim is a bind, a live `xschem bindings dump` row, a file
  byte-compare, a Tcl variable, or a **runtime** `entrycget -accelerator` —
  verified: `test_wave_sigbrowser.tcl:543` reads the live menu entry's
  accelerator and `test_wave_grid.tcl:1107` compares it against the guide's
  `data-accel` for every row, so *"the View menu says Ctrl+B"* is measured, not
  eyeballed. The only thing a human might still want to **feel** is the chord:
  press **Ctrl-B** over a plotted strip and confirm the sidebar toggles while the
  symbol text on the schematic behind it does not. That is `BK12` + `BK18`
  restated in fingers, not a gap in coverage.
