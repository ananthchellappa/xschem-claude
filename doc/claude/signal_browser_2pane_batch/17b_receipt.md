# Item 17b — R10: `Ctrl-Alt-V` via the C action registry

Two-pane item 17b (**not** single-pane 17, and not the whole of two-pane item 17
— the selection arm shipped in `882694cc`). Spec
`doc/claude/specs/waveform_signal_browser_two_pane.md` R10, §7.8, §8.2.
**One commit, `c5a55dd8`, unpushed** — the C registry row, the C binding, the
`actions.csv` row, the regenerated `keybindings.csv`, the `cadence_style_rc`
deletion, the menu accelerator, two source comments and the guide prose
together, plus two test files.

Verdict **DONE**, `[x]`. **One eyeball is owed and it is not a pixel** (§11).

**The one-line reason this item is not cosmetic, and it is a measurement:**
`bind .drw <Control-Key-5>` was **EMPTY in the shipped default profile** —
`cadence_style_rc` is opt-in — while the Tools cascade advertised `Ctrl+5` to
everybody. The accelerator was a lie for every non-cadence user. R10 makes it
true for all of them *and* remappable through `xschem bind` / `keybindings.csv`.

---

## 1. The baselines, re-measured on the UNCHANGED tree first

Both reproduced exactly before a line was written, so every red afterwards is
attributable to this item.

| arm | recorded | measured before | after item 17b |
|---|---|---|---|
| headless, 15 files | **1649**, 0 fail | **1649**, 0 fail | **1658**, 0 fail |
| X, 12 suites (`xarm.sh suites`, `SUITE_TIMEOUT=400`) | **12/12**, 2215 | **12/12**, 2215 | **12/12**, **2230** |
| the 3 out-of-baseline X-only suites | 13 / 17 / 70 | 13 / 17 / 70 | **13 / 17 / 70** |

Per-file headless, after: sigsearch 146, sea 6, sigbrowser 135, 2pane 108,
panes 15, i11 50, **i12 40**, i1315 88, i14 56, grid 231, modes 212, viewer 57,
markers 437, tabs 56, **keys 21**. Sum verified = **1658**.

Per-suite X, after: panes 81, sigbrowser 353, sea 79, i11 74, **i12 126**,
i1315 190, i14 107, 2pane 108, sigsearch 233, grid 356, modes 488, **keys 35**.
Sum verified = **2230** = 2215 + 15.

**Only the two files this item touches moved.**
`test_wave_sigbrowser_keys` +9 headless / +12 under X (`BK20`-`BK28` run in both
arms, `BK29`-`BK31` are X-only). `test_wave_sigbrowser_i12` **does not move
headless at all** — `BX54`-`BX56` are X-only and the five restated ids
(`BX11`, `BX12`, `BX13`, `BX43`, `BX44`) were restated **in place with no change
in call count**, so 123 → 126 under X and 40 → 40 headless. The other ten suites
and the other thirteen headless files are byte-identical.

**Not adopted from the implementer's run.** The verifier re-measured both arms
independently — all 15 headless files by hand, 12/12 through `xarm.sh suites`
under Xvfb — and both sums were re-derived rather than read off a total. It also
confirmed **neither moved suite printed a `SKIPPED` line**, so 35 is not a masked
34 and 126 is not a masked 125: `BX43`'s retargeted real-key leg really fired.
Before measuring anything it ran `cd src && make`, which answered *"Nothing to be
done"* — the shipped binary was built from the committed `callback.c` (item 16's
§4.4 hazard, honoured).

**Twelve further non-batch suites were run once**, because an empty
"no non-baseline fails" claim over 12+3 suites would have held by luck of scope:
this item touches `callback.c`, `actions.csv`, `keybindings.csv` and
`xschem.tcl`'s menubar. `test_accelerators`, `test_binding_precedence`,
`test_remap`, `test_perform_action_check_unique_names`, `test_keybind_snap_grid`,
`test_gesture_bindings`, `test_mouse_bindings`, `test_clone_canvas_bindings`,
`test_altf5_ciw`, `test_graph_context` — **all ALL PASS**. The two that did not
report clean (`test_action_log_dispatch` NORESULT,
`test_cadence_window_hop_log` SKIP) were re-run by hand under Xvfb **with
`--logdir`** and both give ALL PASS: the harness passes `--nolog`, so it is an
**invocation artefact, not a regression**. None of the twelve is adopted into
the baseline.

---

## 2. ⚠⚠ THE PLAN SAYS TWO SUITES RED BY DESIGN. THEY DO NOT.

> PLAN item 17: *"`test_bindings_file` and `test_keybindings_help` red by
> design."*

**Measured, before and after, through `xarm.sh one`: 13 → 13 and 17 → 17.**
When the item is done *correctly* neither moves, because each is a **LOCKSTEP
TRIPWIRE** for one leg of the C / `keybindings.csv` / `actions.csv` triangle:

* `test_bindings_file` regenerates the csv from the live table and demands
  **byte-identity** with the shipped file. It goes red exactly when the C table
  and the csv disagree — proven by **S1** (csv mods hand-spelled `alt+ctrl`,
  13 → 12) and **S5** (`ACTX_OVER_GRAPH` in the C, csv untouched, 13 → 12).
* `test_keybindings_help` renders every bound id and prints `(bare: <id>)` when
  `actions.csv` has no label for it. It goes red exactly when a binding ships
  without its documentation row — proven by **S2a** (17 → 16, printing
  `(bare: wave.show_in_signal_browser)`).

A "red by design" prediction is worse than a wrong count: it invites the next
implementer to *accept* a red in those files. **They are oracles, not
casualties.** Both remain **X-only** (they throw `invalid command name "focus"` /
`"winfo"` under `--nogui`) and in **neither** baseline.

**And the PLAN's "existing checks it reds" list is empty where it should name
four.** `BX11`, `BX12`, `BX43` and `BX44` all carry `Ctrl-5` literals and all
had to be restated; none is mentioned. They were found by grep, not by the PLAN
(§8). The worst of them is `BX43`, which **installed the binding it then drove** —
green no matter what the tool shipped.

---

## 3. What the PLAN and the spec got wrong, with the measurement that says so

### 3.1 Anchors

| cited | actual |
|---|---|
| PLAN edit 1 `callback.c:4677` `action_registry[]` | `:4677`. **EXACT** |
| PLAN edit 2 `callback.c:4920` `init_input_bindings()` | `:4920`. **EXACT** |
| PLAN edit 2 `dispatch_input_action (:5178-5195)` | proc starts `:5162`, Tcl arm `:5186-5203`, the `fprintf` exactly at `:5195`. Range partially inside; the **claim** (a CONSTANT string, no `%`-substitution) is CONFIRMED |
| PLAN edit 2 `callback()` calls `handle_window_switching` at `:8611` | `:8617` (+6) — and the *mechanism* sentence is wrong, see §3.3 |
| PLAN edit 2 `ase::show_in_browser_for_current`'s `{win {}}` arm, `ase.tcl:1054`, body `:1054-1107` | `:1098`, body `:1098-1207`. **+44, and the body is 110 lines not 54** — item 17's own `882694cc` moved it |
| PLAN edit 6 the `hier_now` pivot, `ase.tcl:1075` | `:1122` (+47) |
| PLAN edit 4 `mods_name`, `callback.c:5271` | `:5279` (+8). Its `ctrl+shift+alt+super` order CONFIRMED at `:5283-5286` |
| PLAN edit 3 `test_keybindings_help.tcl:38-49` renders `(bare: <id>)` | comment `:35-38`, loop `:39-46`, the check at `:47-48`. Covered |
| PLAN edit 5 `cadence_style_rc:245` | `:245`. **EXACT** — but its comment block `:234-244` carries two more `Ctrl-5`/`Ctrl+5` literals the PLAN does not name |
| PLAN edit 5 `xschem.tcl:14939` `-accelerator Ctrl+5` | `:14942` (label `:14941`) |
| PLAN edit 6 `new_prop_string()`, `token.c:795-833` | `:779-837` |
| PLAN reds `BX13` at `i12:338-341`, control leg at `:342` | BX13's legs are `:342` / `:348` / `:352`; **`:342` is BX13's FIRST leg, not its control**, and `:338-341` is the comment above it |
| `17_receipt.md:92` — the guide's Ctrl-5 prose is in **§11.4** | it is **§11.5** (`browser-hier`, guide `:1081`/`:1094`). §11.4 is `browser-loc`, The Location bar |
| PLAN §2 preamble *"exact as cited: `keybindings.csv:23` and `:46`"* | **STALE POST-ITEM-16** — the file is 66 lines and item 16 deleted the row that was `:23`. Not an item-17b anchor; recorded so nobody re-uses it |

### 3.2 Numbers

1. **"Five coordinated edits" (PLAN) / "four" (spec §8.2) — measured SEVEN
   literal `Ctrl-5` sites over FIVE files**, plus the two C edits, the
   `actions.csv` row and the csv regeneration:
   `cadence_style_rc:234,243,245`, `xschem.tcl:14942`,
   **`wave_viewer.tcl:9608`**, **`ase.tcl:1017`** and
   **`doc/waveform_viewer_guide.html:1094`**. The last three are named by
   **neither** document. All three were fixed, and the `wave_viewer.tcl` comment
   names **no accessor** (§4.4).
2. **The BK band.** PLAN's heading says `BK20`-`BK32`; its own code block lists
   `BK20`-`BK35` — **internally inconsistent, 14 ids under a 13-id heading**.
   Measured first free is `BK19`, but `16_receipt.md` §11 **reserves `BK19` to
   item 16's file band**, so this item took **`BK20`-`BK31`** and left `BK19`
   unspent. Verified by grep across `BK\d\d` in `tests/` and `doc/claude/`:
   `BK20`-`BK31` have exactly one check call each; `BK19` and `BK32` appear only
   as band prose. **Next free `BK32`.**
3. **The BX band.** Spent: `BX01`-`BX18`, `BX20`, `BX30`-`BX53`
   (`BX19` and `BX21`-`BX29` are pre-existing gaps — **do not back-fill**).
   First free `BX54`, corroborated by `15_receipt.md:484`. Took
   **`BX54`-`BX56`**. **Next free `BX57`.**
4. **PLAN edit 6 / `BK30`-`BK35`, "THE NEW CAPABILITY", already shipped.**
   `882694cc` landed it as `ase::browser_sel_segment` (`ase.tcl:1082-1096`) plus
   steps 3b (`:1130-1160`) and 6b (`:1181-1194`), covered by `BX16`-`BX18`
   headless and `BX51`-`BX53` under X. **`BK30`-`BK35` exist nowhere as check
   ids** — verified by measurement before deciding. Restated through the new
   gesture at `BX56`, **not duplicated**.
5. **No collisions in the C table.** `grep -n 'ctrl+alt' src/keybindings.csv
   src/mousebindings.csv` = **0** in both, and the live
   `lsearch -glob {* ctrl+alt *}` = -1; `^key,118,` = **0** and
   `lsearch -glob {key 118 *}` = -1. This row is the **first `ctrl+alt` row in
   the C table**. (`actions.csv` had exactly one `Ctrl+Alt` accel already —
   `file.save_as_symbol` — but display-only, with no C row.)
6. **`case 'v'` really has no colliding arm.** `callback.c:6964-7025`:
   `rstate==0`, `rstate == ControlMask` and `EQUAL_MODMASK`; and
   `#define EQUAL_MODMASK ((rstate == Mod1Mask) || (rstate == Mod4Mask))`
   (`:27`) is an **exact** test, so `ControlMask|Mod1Mask` matched nothing.
7. **The binding table's length is the only count oracle available.**
   `[llength [xschem bindings dump]]` measured **71** before (item 16 predicted
   72 → 71 and it is confirmed), **72** after; `keybindings.csv` **66 → 67**
   lines. No pre-existing test asserts either, which is why `BK29`/`BK31` do
   (§10 limit 6).
8. **`BK28`'s keysym-53 leg is a PRE-EXISTING zero** — `grep ',53,'` = 0 and the
   live dump has no `key 53` row, because the old chord was a Tk `bind` the table
   cannot see. The scout flagged it as vacuous-as-written; it ships **paired in
   one tuple** with the positive legs (§7).
9. **`keybinding_chord_label key 118 ctrl+alt` measured `Ctrl+Alt+v` —
   LOWERCASE.** The menu accelerator is `Ctrl+Alt+V` (house style). Two literals,
   on purpose (§10 limit 5).
10. **`regexp -all {Show in Signal Browser} src/xschem.tcl` = 1.** That is
    `BX12` leg 2, a bare-phrase file-wide count — the `BD06` landmine, on
    `xschem.tcl` instead of `wave_viewer.tcl` (§4.4).

### 3.3 The PLAN's safety argument for the argument-less command is imprecise

The PLAN justifies the no-window Tcl command by saying `callback()` calls
`handle_window_switching(win_path)`, so the context is already right. Measured:
`handle_window_switching` switches **only** on `event == FocusIn || Expose ||
EnterNotify` (`callback.c:8497-8498`). **A KeyPress does not switch context.**
The conclusion still holds — the context is correct because the preceding
Enter/Focus set it — but it is a *different sentence*, and it is the sentence
that makes the `{win {}}` arm right rather than lucky. Corrected in the C
comment, not left in the PLAN's form.

---

## 4. Four traps that cost real time — all found by running

### 4.1 ⚠⚠ THE FIRST RED RUN OF `i12` HUNG, AND THE CAUSE WAS A CONTROL I WROTE

`handle_key_press` looks a **printable** keysym up under `rstate` =
`state & ~ShiftMask` (`callback.c:5963`, `:1019-1020`). The "inert" near-miss
control I had chosen — state **5** (Ctrl+Shift) — is therefore state **4**:
`case 'v'` / `ControlMask` = **clipboard paste**, `merge_file(2, ".sch")`, whose
file dialog is **MODAL**. The suite sat there for ten minutes with a `go_back`
queued behind the dialog and had to be killed.

Found by reading the C, not by guessing. The near-miss controls were re-chosen
**by measurement** (state **68** = Ctrl+Super: right shape, wrong modifier, no
`case 'v'` arm, not equal to 12) and the trap is written into `BX54`'s own
comment so the next person does not "tidy" them back:

```
state 4  (Ctrl)       -> clipboard PASTE, merge_file(2,".sch")   [MODAL]
state 5  (Ctrl+Shift) -> Shift STRIPPED, so it is state 4 again  [MODAL]
state 8  (Alt)        -> vertical flip; nothing selected ARMS a click-prompt
state 13 (Ctrl+Alt+Shift) -> STRIPPED to 12: the chord FIRES
```

**The consequence is reported, not smoothed over: `BX56` never got an
initial-red measurement**, because the run died in the `BX51` block before
reaching it. Its red evidence comes from sabotage **S2b** and, independently,
from the verifier's own sabotage (§6.3) instead. That is a gap in the
*procedure*, and it is stated as one.

### 4.2 ⚠⚠ `event generate <Control-Alt-Key-v>` DELIVERS STATE 131076, NOT 12

Measured with a `%s` spy under Tk 8.6.14. Tk's **`Alt` pattern modifier is the
virtual META bit** (1<<17), not `Mod1Mask`. A test written the obvious way
**fails on correct code**. `<Control-Mod1-Key-v>` delivers **12** =
`ControlMask|Mod1Mask` — what the C row matches and what a physical Alt sets.
Written into `BX43`'s comment and into the `init_input_bindings` comment.

### 4.3 ⚠⚠ `BX43` WAS DRIVING A BINDING THE TEST ITSELF HAD INSTALLED

Item 12 could not source `cadence_style_rc` (it installs every cadence bind and
sources eight util files), so `BX43` re-bound the exact rc line by hand and then
drove it. That made the check **green no matter what the tool shipped** — the
same shape two-pane item 16 caught at `BS46`. Left alone, it would have gone on
passing while testing a chord the tool no longer has.

The hand-installed `bind .drw <Control-Key-5>` is **deleted**. `BX43` now drives
`<Control-Mod1-Key-v>` through the **shipped** table or not at all, keeping its
`<Control-Key-6>` negative control and its self-SKIP banner. **Measured green
with a real key on the green tree — it did not skip.**

### 4.4 THE BARE-NAME LANDMINE, ON A FILE NOBODY WAS WATCHING

Item 12's `BD06` rule is *"no accessor is named in any comment in
`wave_viewer.tcl`"*. This item's `wave_viewer.tcl` edit is a **section comment**
at `:9608`, and it honours the rule: it names **no accessor**.

The live trap was elsewhere. `BX12` leg 2 is
`[regexp -all {Show in Signal Browser} $bx_xsrc] 1` over **`src/xschem.tcl`** —
the same bare-phrase file-wide count, on a different file. This item writes five
comment lines into `xschem.tcl` right above the menu entry, and **not one of them
contains the phrase**. Proven live rather than asserted: sabotage **S8** writes
`# Show in Signal Browser` there and reds `BK27` leg 2 and `BX12` leg 2, with
`BK27` leg 1 staying green (the accelerator is still right).

### 4.5 The csv is REGENERATED, never hand-edited

Item 16's §4.1 trap applies unchanged: `save_input_bindings_file` writes the
**live** table and the shipped csv is loaded into it at startup, so regenerating
in place reproduces whatever is already there. The file was **moved aside and
generated from the builtins**, and came back as the previous file plus exactly
one line — **66 → 67, the new row at 66, `Alt-2` still last at 67**, which is
why the new `set_input_binding` sits *before* the Alt-2 row that carries the
*"Kept LAST so it is the last key row when keybindings.csv is regenerated"*
comment.

---

## 5. What landed

### Source

**`src/callback.c` — two edits, and the id appears exactly twice.**

* A registry row after `edit.add_wire_label`:
  `{ "wave.show_in_signal_browser", NULL, "ase::show_in_browser_for_current",
  "Show in Signal Browser" }` — Tcl-backed, `fn` NULL. The 4-initializer form
  leaves `ActionDef`'s `mutates` field 0 by aggregate-init default, matching the
  neighbouring rows; the comment's `mutates=0` claim was **verified against the
  struct** (`:4668`), not assumed. Revealing a hierarchy position changes no
  schematic content, so it works in a read-only view.
* `set_input_binding(DEV_KEY, 'v', ControlMask|Mod1Mask, ACTX_CANVAS,
  "wave.show_in_signal_browser");` in `init_input_bindings`, placed before the
  Alt-2 row (§4.5).
* **The Tcl command takes no window argument, and that is asserted, not
  assumed** (`BK23` leg 3). `dispatch_input_action` runs a **constant** string —
  there is no `%`-substitution — so a command written with an argument would be
  dispatched literally, and the logged replay line is context-free **by design**.
  The comment records §3.3's correction rather than the PLAN's sentence.

**`src/actions.csv`** — one row, `menu=tools`, display accel `Ctrl+Alt+V`. This
is what the cheat-sheet and the palette read; without it the help text renders
`(bare: wave.show_in_signal_browser)`. **Verified, not assumed, that it adds no
second Tools entry beside the hand-built one:** `build_menu_from_table` is called
**only** with `file` (`action_registry.tcl` ← `xschem.tcl:14511`).

**`src/keybindings.csv`** — regenerated (§4.5): `key,118,ctrl+alt,canvas,
wave.show_in_signal_browser,`.

**`src/cadence_style_rc`** — the `bind .drw <Control-Key-5>` line **and its
eleven-line comment block** replaced by a tombstone that records *why* the
reversal happened (an opt-in profile file cannot ship a default; a Tk `bind` is
invisible to `xschem bind`) and states that **re-adding a bind here would quietly
take R10 away again**. Ctrl-4 and Ctrl-$ are deliberately untouched — they are
`BK25`'s positive control.

**`src/xschem.tcl`** — the Tools entry's `-accelerator Ctrl+5` → `Ctrl+Alt+V`.
The `-command` is **unchanged** and still passes `${topwin}.drw`: a menu click
knows which window it happened in; a key press is already in one.

**`src/ase.tcl:1017`** and **`src/wave_viewer.tcl:9608`** — comment literals
retargeted. The `wave_viewer.tcl` one names no accessor (§4.4).

**`doc/waveform_viewer_guide.html:1094`** — §11.5 prose, inside a `<kbd>` run.
**No `data-seq` / `data-menu` row was added**, which is what keeps
`test_wave_grid`'s `GH0` at 16/11 and `BX13`'s tuple at zeros.

### Tests

* **`tests/headless/test_wave_sigbrowser_keys.tcl` — `BK20`-`BK31`, +9 headless
  (12 → 21) / +12 under X (23 → 35).** `BK20`-`BK28` are FILE/SOURCE claims that
  run in both arms; `BK29`-`BK31` are the X-only live-table block —
  `bindings dump` row + length, the generated cheat-sheet, and the
  unbind/rebind round trip. All three X helpers (`bk_row`, `bk_nrows`,
  `bk_n53`) return the assertable value **`NO-DUMP`** on an unreadable dump, so
  *"the table vanished"* can never answer 0 and read as *"the row is correctly
  absent"*. The file's band line was rewritten to
  `BK01-BK18 item 16 / BK19 UNSPENT (reserved) / BK20-BK31 two-pane item 17b`.
* **`tests/headless/test_wave_sigbrowser_i12.tcl` — `BX54`-`BX56`, +0 headless /
  +3 under X (123 → 126)**, plus five ids restated in place (§8). `BX54`/`BX55`
  drive `xschem callback` **numerically** rather than through `event generate`,
  so they are deterministic and are the item's **hard** behavioural oracles;
  `BX43` (the real key) rides `event generate` and self-skips under a WSLg stall,
  which is exactly why the pair exists.

---

## 6. Sabotages — RUN

Driver: lock file, `EXIT`/`INT`/`TERM` trap, a **pre-state count asserted before
every patch**, a post-write re-read proving the mutation is really on disk,
byte-exact restore from backup (never `git checkout --`), and a filter that
**counts `NORESULT` and `TIMEOUT` as REDS** (item 16's lesson: an anchored
`^(PASS|FAIL|RESULT)` filter scores a hung suite as a clean zero). C sabotages
were `touch`ed before `make` (item 16 §4.4). **No row scored zero.**

### 6.1 The item's own nine

| # | sabotage | failed **exactly** | reds | positive control | reverted |
|---|---|---|---|---|---|
| **S1** | `keybindings.csv` mods hand-spelled `alt+ctrl` | **yes** | `BK21` leg 1 (keys headless 21 → 20 ok / 1 FAIL) + `test_bindings_file` 13 → 12 | `BK22`/`BK23`/`BK24`-`BK28` **green** — the live table is built from the C builtins, so the chord still WORKS; the red is FILE drift | yes |
| **S2a** | delete the `actions.csv` row | **yes** | `BK20`; X `BK20`+`BK30`; `test_keybindings_help` 17 → 16 printing `(bare: wave.show_in_signal_browser)` | `BK29`/`BK31` **green** — the chord works, only its documentation is missing. Run twice (headless + X) because `BK30` is X-only | yes |
| **S2b** | comment out the **registry row**, keep the `set_input_binding` | **yes** | keys headless `BK22`, `BK23`; i12 X `BX54`, `BX55`, `BX56`; keys X `BK22`, `BK23`, `BK31` | **`BK29` STAYS GREEN** — see below. `BK23`'s red is an ADDITIONAL red from the same cause (its leg 2 counts the Tcl command string, which lives in the deleted row): recorded, not hidden | yes |
| **S3** | revert **both** C edits + the csv row, bind it in `cadence_style_rc` instead | **yes** | keys headless `BK21`, `BK22`, `BK23`, `BK26`; keys X those four + `BK29`, `BK30`, `BK31` | **`BK24`/`BK25`/`BK27`/`BK28` GREEN**, and that is the whole point — an rc bind is indistinguishable from a registry row **except through the un-bind** | yes |
| **S4** | revert `xschem.tcl:14942` only (rc line still deleted) | **yes** | keys headless `BK27` leg 1; i12 headless `BX12` leg 1 | `BK21`/`BK24`/`BK26`/`BK28` green — the chord works and **the MENU LIES**; no behavioural check can see it | yes |
| **S5** | `ACTX_OVER_GRAPH` instead of `ACTX_CANVAS` (+`touch`+`make`) | **yes** | keys headless `BK23`; keys X `BK23`, `BK17`, `BK29`, `BK31`; `test_bindings_file` 13 → 12 | `BK17` is **item 16's** byte-identity check reacting to the same C/csv divergence — same cause, recorded | yes |
| **S6** | re-add the rc `bind .drw <Control-Key-5>` line (**additive**, not a move) | **yes** | keys headless `BK24`; i12 headless **both** `BX11` legs | everything else GREEN — this is what makes `BK24` a **MOVE** claim rather than an ADD claim, and what makes `BX11`'s inversion worth keeping | yes |
| **S7** | add a `data-seq="Control-Alt-Key-v"` row to the guide | **yes** | keys headless `BK28` + `BK10`; i12 headless `BX13`; `test_wave_grid` 5 reds (`GH0` ×2, `GH1`, `GH2`, `GH4`) | **the four-file lockstep tripwire fires across all four files** while everything behavioural stays green | yes |
| **S8** | write `# Show in Signal Browser` as a **comment** in `src/xschem.tcl` | **yes** | keys headless `BK27` leg 2 (`2` not `1`); i12 headless `BX12` leg 2 (`{2 1}` not `{1 1}`) | `BK27` leg 1 GREEN — the accelerator is still right. Item 12's `BD06` landmine proven **live on `xschem.tcl`** instead of asserted | yes |

**Zero-red rows: none.**

### 6.2 The pair that decided the item, and two PLAN predictions that were wrong

**`S2b` + `BK29` — the result that justifies `BX54` existing.** With the registry
row gone but `set_input_binding` intact, the **live `xschem bindings dump` still
shows the row** (`BK29` green, 72 rows, correct label in the csv) while the chord
does nothing at all. **A binding-table check cannot see a missing registry row.**
That is why the behavioural drive at `BX54` is not redundant with `BK29`, and it
is exactly the shape a green-but-hollow test set misses. The PLAN predicted
`BK30` would red here; **it does not, and correctly** — the dump row and the csv
label both survive.

**`S3` — an rc bind is behaviourally identical, and it answers the scout's open
question.** `BK24`/`BK25`/`BK27`/`BK28` stay green under it, so *"the chord
works"* is not evidence that R10 happened; only `BK31`/`BX55`'s **un-bind** can
tell a registry row from a Tk bind. It also settled by measurement something the
scout could only ask: **the `i12` fixture does not source `cadence_style_rc`**
(which is why item 12's `BX43` hand-installed the bind), so an rc-only chord is
dead there too.

**`S5` — the PLAN predicted `BK21` reds. It does not, and correctly:** the csv
**file** was not touched by that sabotage, which is precisely why
`test_bindings_file` is the tripwire that catches it.

**Two explained count movements, neither a shortfall.** Under `S2b` the i12 X
count drops 126 → 124 because `BX43`'s two real-key legs **self-SKIP** with
nothing bound. Under `S7` the grid count rises 231 → 233 because `GH1`/`GH4` loop
**per guide row** and the sabotage adds one. Both are consequences of the
sabotage's own nature.

**Two rows not re-run under X, for budget, and said so rather than implied:**
`BX54` under `S5` and `BX44` leg 1 under `S4`. In both cases a **same-cause**
check *was* measured red (`BK29` for `S5`, `BX12` leg 1 for `S4`).

### 6.3 ⚠⚠ THE VERIFIER'S OWN SABOTAGE — NOT ON THE LIST ABOVE

Aimed at the item's **central safety argument**, which no named sabotage touched.
The whole design rests on the dispatcher running a **constant, argument-less**
string, which is only safe because the Tcl proc has a `{win {}}` default arm. So
the default was removed:

```
src/ase.tcl:  proc ase::show_in_browser_for_current {{win {}}}  ->  {win}
```

(backup taken; the mutation proven on disk by an md5 diff before running).

**The prediction, and why it was non-obvious:** `BX43`/`BX54`/`BX55` **cannot
see this**, because they install a spy
`proc ::ase::show_in_browser_for_current {{win {}}}` that supplies the default
itself and forwards one argument to the real proc — **the spy absorbs the
sabotage**. Only `BX56` runs after the spy is renamed away, i.e. only `BX56`
drives the C dispatcher into the **real** proc with no argument.

> **It red `BX56` alone.** i12 under X = **125 passed / 1 failed**, reading
> `{{} X2 {}}` against `{g:x1 X2 g:x1.x2}` — the empty tree selections are the
> swallowed `wrong # args` inside the check's own `catch`. **Count held at 126**
> (no early abort, no shortfall); nothing else red. Restored byte-exact (md5
> match, `git status` clean) and re-run green at 126/126.

**Verdict: the feature is covered where it matters — and the covering check is
`BX56`, the one check that never got an initial-red measurement because the first
red run hung (§4.1). This sabotage supplies the red evidence that run owed.**

---

## 7. Checks that were VACUOUS on the red run, and what was done about them

The red run is the only reason any of this is known. *A check that passes before
you wrote the code is a check to stop and look at.*

| check | why it was already green | disposition |
|---|---|---|
| `BK25` | it is **`BK24`'s positive control**: `cadence_style_rc` still binds `Control-Key-4` and `Control-Key-dollar`, true before and after | **KEPT, deliberately.** Without it `BK24` is green on a **deleted or emptied** rc. Non-vacuity proven by **S6**, where it stays green while `BK24` reds |
| `BK26` leg 1 (no `Control-(Alt|Mod1)-Key-v` in the rc) | true **before the code existed** — nothing bound it | **KEPT, paired in the SAME tuple** with leg 2 (the C `set_input_binding` line). The red run answered `{0 0}` against `{0 1}`, so the check **failed red as designed**. **S3** proves the pair: leg 1 goes to 1 when an rc bind is added |
| `BK28` legs 3 and 4 (no `data-seq="Control-Alt-Key-v"`, no `data-menu="Show in Signal Browser"`) | **pre-existing zeros** | **KEPT.** Leg 1 — the new `<kbd>` prose run — is what makes them non-vacuous: the red run answered `{0 1 0 0}` against `{1 0 0 0}`. **S7** fires leg 3 |
| `BK29` leg 2 (no canvas row for keysym 53) | **pre-existing zero**, and the PLAN itself named it as vacuous | **KEPT, in one tuple** with leg 1 (the row is present) and leg 3 (the dump is 72); the red run answered `{0 0 71}`. It is the statement that the move was not "fixed" by **adding** a 53 row |
| `BK31` leg 3 (the dump is 71 after the unbind) | read 71 on the **red** run too — there was nothing to unbind | **KEPT.** Legs 1/4/5 carry the claim; the tuple red as `{0 0 71 0 71}`. The 71 is what makes the two 72s mean anything |
| `BX13`'s three zeros | passed on the red run and stay green in value — **the PLAN says so explicitly** (*"stays at `{0 0}` in value"*) | **WIDENED, not re-purposed.** It is a stability claim, not a behavioural one; its non-vacuity is proven by **S7**, where the **new** middle zero reds. Its `data-seq="Key-E"` control leg is kept **verbatim** |
| `BX56` | **NEVER OBSERVED RED ON THE INITIAL RED RUN** | **A GAP IN THE PROCEDURE, not a vacuity finding.** The red run hung in the `BX51` block before reaching it (§4.1). Its red evidence comes from **S2b** and from the verifier's own sabotage (§6.3). Stated rather than glossed |

---

## 8. Every existing check restated, and why

**Nothing was deleted. Nothing was renumbered. No new `check` call was added to
any existing file** — the five `i12` restatements are all in place, which is why
`i12` headless stays at 40.

### 8.1 `tests/headless/test_wave_sigbrowser_i12.tcl` — five ids, four of them unnamed by the PLAN

* **`BX11` leg 1** — *"`cadence_style_rc` binds `.drw <Control-Key-5>` … and
  BREAKs"*, expected 1. **INVERTED to expect 0**, same id, same file.
* **`BX11` leg 2** — `[regexp -all {<Control-Key-5>} $bx_rc] 1`. **INVERTED to 0
  AND WIDENED** with two positive controls in the same tuple (Ctrl-4 and Ctrl-$
  still bound), so the absence **cannot be satisfied by an emptied rc**. The
  precedent is item 16's `test_key_graph_context` inversion.
* **`BX12` leg 1** — the Tools-cascade regexp, **retargeted in place**,
  `Ctrl\+5` → `Ctrl\+Alt\+V`. The `-command` half is unchanged **on purpose**: a
  menu click knows its window.
* **`BX12` leg 2** — `[regexp -all {Show in Signal Browser} $bx_xsrc] 1` over
  `src/xschem.tcl`. **UNTOUCHED ON PURPOSE** — it is the `BD06` comment landmine
  on a different file, and it is why no comment this item writes into
  `xschem.tcl` contains that phrase. Proven live by **S8**.
* **`BX13`** — **WIDENED** from two zeros to three (the old chord's `data-seq`,
  the **new** chord's `data-seq`, the `data-menu`), control leg kept verbatim.
  The old zero **alone** would now be trivially true of a chord that no longer
  exists.
* **`BX43`** — **RETARGETED, and its hand-installed bind DELETED** (§4.3). Now
  drives `<Control-Mod1-Key-v>` through the shipped table; the `<Control-Key-6>`
  negative control and the self-SKIP banner are kept. **Measured green with a
  real key** on the green tree.
* **`BX44` leg 1** (X-only) — the live `entrycget -accelerator` read; middle
  element retargeted `{Ctrl+5}` → `{Ctrl+Alt+V}`. Despite its id range it is
  **not** a `.ph` status-line pin; `BX45`/`BX46` are, and they are untouched.

### 8.2 `tests/headless/test_wave_sigbrowser_keys.tcl` — the band line

Rewritten to `BK01-BK18 item 16 / BK19 UNSPENT (reserved) / BK20-BK31 two-pane
item 17b`, **next free `BK32`**, per the scout's measured reservation. `BK19`
left unspent.

### 8.3 The three out-of-baseline X-only suites — CHECKED, not assumed

`test_bindings_file` **13**, `test_keybindings_help` **17**,
`test_key_graph_context` **70**: run before and after through `xarm.sh one`, all
PASS, all **unmoved**. The PLAN says the first two red by design; they do not
(§2), and both were proven to fire under sabotage. `test_key_graph_context` was
additionally **grepped** — it names only keys 97/98/102/65361-65364/32, nothing
about 118 or `v`.

### 8.4 Frozen oracles confirmed unmoved

`GH0`'s 16/11, `GH1`-`GH6`, `GH8`-`GH10`, `GS0`-`GS3`, `BT08`/`BT09`,
`BS01`-`BS05`, `BS09`, `BS42`, `BS45`, `BS46`, `BP07`, `MG9`, `BP02`, `MD9`,
`BK03`'s whole-list `graphkeys` control, and the whole item-12 `.ph` carry-in
(`BD52`, `BX37`, `BX42`, `BX44`-`BX46`, `BH50`, `BH51`, `BH54`) — **all measured
green, all untouched.** Named here so the record says *checked*, not *assumed*.

Re-greped by the verifier as well: `show_in_signal_browser` appears in
`callback.c` **exactly twice** (the registry row and the `set_input_binding`) —
the added C comment does **not** repeat the id, so `BK22` leg 2 is honest. And
`Control-Key-5` survives in exactly **two places, both `callback.c` comments**
(`:4827`, `:5130`) — `grep -c Control-Key-5 src/cadence_style_rc` = **0**, so
`BK24`'s and `BX11`'s absence claims are about a literal that is genuinely gone
from the rc rather than one that moved down a line.

---

## 9. Every divergence

1. **SCOPE, per the driver note:** edits 1-5 and checks `BK20`-`BK29` + `BX13`.
   **Edit 6** (the selected-instance arm) and `BK30`-`BK35` already shipped in
   `882694cc`; verified by measurement that `BK30`-`BK35` exist nowhere as check
   ids, then **restated through the new gesture at `BX56` rather than
   duplicated** (§3.2 item 4).
2. **CHECK-ID BANDS.** Took `BK20`-`BK31` (not the PLAN's `BK20`-`BK32`/`BK35`,
   whose heading and code block are internally inconsistent) and `BX54`-`BX56`.
   `BK19` left **unspent**, reserved to item 16's file band.
3. **SEVEN literal sites over FIVE files**, not the PLAN's "five coordinated
   edits" nor the spec §8.2's "four" (§3.2 item 1).
4. **The guide's Ctrl-5 prose is §11.5**, not §11.4 as `17_receipt.md:92` says.
5. **The PLAN's safety argument for the argument-less command is imprecise** and
   is corrected **in the C comment**, not merely in this receipt (§3.3).
6. **The PLAN says `test_bindings_file` and `test_keybindings_help` red by
   design. Measured: they do not** (§2). Its "existing checks it reds" list also
   misses `BX11`, `BX12`, `BX43` and `BX44` entirely.
7. **`BX11`'s inversion did NOT add a check call** (2 before, 2 after), so
   `i12`'s headless count stays at **40** rather than moving to 41 as the scout's
   plan predicted. The extra positive-control legs ride inside the existing
   tuple.
8. **The initial `i12` red run HUNG and had to be killed** (§4.1). Cause found by
   reading the C, control re-chosen by measurement, trap written into the check.
   Consequence: `BX56` has no initial-red measurement.
9. **`BX54` asserts that state 13 (Ctrl+Alt+Shift) FIRES** rather than being
   refused. This contradicts the PLAN's implied "exact mods" framing and is the
   **measured** truth: Shift is stripped for printable keysyms, and a shifted `v`
   arrives as keysym 86 anyway.
10. **Two sabotage predictions in the PLAN are wrong and are corrected with the
    measurement**: `S2b` does **not** red `BK30`, and `S5` does **not** red
    `BK21` (§6.2).
11. **`BK17` and `BK10` red as collateral under `S5` and `S7`** — item 16's
    checks reacting to the same cause. Recorded rather than filtered out.
12. **The receipt itself was written by the ledger stage, not the implementer.**
    The implementer runs under a standing instruction not to write report `.md`
    files, so every fact this document carries was first put in the **commit body
    of `c5a55dd8`** and in the structured handback. Nothing here is
    reconstructed: the commit body, the diff and the verifier's re-runs are the
    sources.

---

## 10. Declared limits

**1. A Ctrl+Alt+NumLock drive (state 28) recorded ONE call where reading says
ZERO — UNATTRIBUTED, and therefore NOT ASSERTED.** `key_chord_has_binding`
(`callback.c:5155`) compares mods for **equality** (`b->mods == mods`, and
28 ≠ 12); `kmods = (key < 0xff00) ? rstate : state` (`:5963`) strips only
`ShiftMask`; and a grep for `Mod2Mask`/`LockMask` in `callback.c` finds
**none**. By the code it must record zero. The discrepancy was not attributed
inside this item's budget, so **the leg was removed from `BX54`** rather than
pinned to a number nobody can explain. The check carries a comment saying so and
naming it as owed. The verifier read the same three sites independently and
**agrees the refusal is correct**. Everything `BX54` *does* assert (state 12
fires, state 13 fires because Shift is stripped, state 68 does not) is explained
and reproducible.

**2. Alt-alone (state 8) and Ctrl-alone (state 4) are DELIBERATELY NOT DRIVEN
behaviourally.** Both are real shipped actions on keysym 118: state 8 is a
vertical flip that, with nothing selected, **arms a click-to-flip prompt** in
`ui_state`; state 4 (or state 5, which becomes 4) is clipboard paste, whose
**modal** file dialog hung the whole suite (§4.1). Their evidence is `BK23`'s
source grep plus `EQUAL_MODMASK` being an exact test.

**3. `BX43`'s real-key leg SELF-SKIPS** rather than failing when `send_key`
cannot confirm delivery (the `BS46` rule). **Its red state is a printed
`SKIPPED` line and a COUNT shortfall with zero failures** — diff the count, not
the fail count. On the accepted run it did **not** print, so 126 is real. Its
hard twins are `BX54`/`BX55`, which drive `xschem callback` numerically.

**4. Two rows were not re-run under X, for time budget:** `BX54` under `S5` and
`BX44` leg 1 under `S4`. A same-cause check was measured red in each case
(`BK29`, `BX12` leg 1). Stated rather than implied.

**5. The menu accelerator and the cheat-sheet DIFFER BY CASE, shipped that way
on purpose.** `Ctrl+Alt+V` is house style (cf. `file.save_as_symbol`'s
`Ctrl+Alt+S`); `keybinding_chord_label` renders keysym 118 through `format %c`
and so emits `Ctrl+Alt+v`. `BK20`/`BK27` pin the uppercase literal, `BK30` the
lowercase one. **Do not copy either into the other's check.** A user who reads
both surfaces sees two spellings of one chord — a judgement call, flagged
because only an eyeball settles it.

**6. `BK29` leg 3 and `BK31` legs 3/5 pin the LIVE binding table's total length
at 72 (71 mid-unbind).** Any future item that adds or removes **any** binding
anywhere in the C table reds this batch-local file. That is deliberate — it is
this item's only count oracle and no pre-existing test asserts the length — but
**the next person to touch `init_input_bindings` will meet it**.

**7. `BK26` is titled "no rc file binds the chord in EITHER Tk spelling" but
greps only `src/cadence_style_rc`.** `src/xschemrc` and
`src/net_hilight_style_rc` are never read, so a `bind .drw <Control-Mod1-Key-v>`
added to `xschemrc` would defeat R10's remappability and red nothing —
`BX55`/`BK31` drive `xschem callback` numerically and bypass Tk binds entirely,
so they cannot see it either. **Verified by grep that today no rc binds it**, so
the claim is true as shipped, and the PLAN's own literal has the same
narrowness. Worth widening whenever someone next touches that file.

**8. The X arm was measured under Xvfb**, which has **no window manager and no
compositor**, so no decoration / stacking / raise / **chord-grab** claim is
testable there. For this item that is not a formality — see §11.

---

## 11. Owed / for the next item

* **⚠ ONE EYEBALL IS OWED, AND IT IS NOT A PIXEL — which is why this item is
  `[x]` with no eyeball-queue row.** Press a **physical Ctrl+Alt+V on the real
  `:0` display**, over a design canvas, and confirm the Signal Browser reveals
  the current hierarchy position. The entire X arm ran under **Xvfb**, which has
  no window manager and no compositor, so it **cannot see a desktop-environment
  grab of the chord** — and `Ctrl+Alt+V` is R10's chosen chord, in the exact
  family desktop environments like to take. One press after the handback. If it
  is grabbed, that is a **chord** problem for R10 to reopen, not a code defect:
  every route below the keymap is measured.
* **Item 17b unblocks item 18** (R12's auto-tick, reveal, and say so). Item 18
  drives the same reveal path; **`BX56` is the check that pins the C-dispatcher
  route into the `{win {}}` arm**, and it is the only one that can see that arm
  (§6.3). Do not weaken it.
* **NEXT FREE ids: `BK32` and `BX57`.** `BK19` is **unspent and reserved** to
  item 16's file band (`16_receipt.md` §11); do not take it. `BX19` and
  `BX21`-`BX29` are pre-existing gaps — **do not back-fill them**.
* **⚠ THE COUNT TRIPWIRE, for item 18 and 19.** `BK29`/`BK31` assert the live
  binding table is **72** rows (71 mid-unbind). Any C-table change reds them
  (§10 limit 6).
* **⚠ THE THREE OUT-OF-BASELINE X-ONLY SUITES STILL MUST BE RUN BY HAND.**
  `test_bindings_file` (13), `test_keybindings_help` (17),
  `test_key_graph_context` (70). All three are outside both baselines, and the
  two binding suites **throw under `--nogui`** — a green 15-file / 12-suite run
  proves nothing about any of them. Item 18 touches no C table, but item 19's
  documentation sweep touches `actions.csv` territory.
* **⚠ ITEM 19 OWNS THE DOCUMENT CORRECTIONS THIS ITEM MEASURED.** Spec §8.2 says
  *"four coordinated edits"*; it is **seven literal sites over five files**
  (§3.2). `17_receipt.md:92` says the guide prose is §11.4; it is **§11.5**
  (`browser-hier`). The PLAN's item-17 heading and code block disagree about the
  BK band. And the PLAN's *"reds `test_bindings_file` / `test_keybindings_help`
  by design"* must be **struck**, not merely annotated — it invites the next
  implementer to accept a red in an oracle (§2).
* **⚠ `BK26`'s rc grep is narrower than its title** (§10 limit 7). One extra
  `xschemrc` / `net_hilight_style_rc` read closes it. The shipped code is
  correct; this is about the oracle.
* **⚠ THE STATE-28 QUESTION IS STILL OPEN** (§10 limit 1). It is either a real
  dispatch surprise or a harness artefact, and whoever settles it owns the
  `BX54` leg that was deliberately left out.
* **⚠ The item-13 eyeball row in `LEDGER.md` was corrected by this stage**, not
  reflowed: it told the human to press **Ctrl+5**, which this item deletes. It
  now names `Ctrl+Alt+V` and `c5a55dd8`. Nothing else in the queue was touched.
