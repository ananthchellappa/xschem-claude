# RECEIPT B — issue 1625: the vertical-justification control moves to the property edit form

**Stage:** B · **Issue:** 1625 (minted by the driver; this crew minted nothing)
**Date:** 2026-09-30 · **Tree at start:** `c5a11808`, branch `fluid-editing`
**State left:** **uncommitted**, both test arms green. No commit, no push, no gate, no stash,
no `owed.sh clear`.
**`git status --short` at finish:**

```
 M doc/claude/specs/add_wire_label.md
 M src/property_form.tcl
 M src/xschem.tcl
 M tests/headless/test_add_wire_label.tcl
?? .xschem/
?? doc/claude/wire_label_vjust_batch/receipts/B-move-vjust.md
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
```

`.xschem/` and `sky130A/…/debug_st1/` were already there at `c5a11808` (they are in the session's
opening git status); the third `??` is this receipt. Nothing else was created, and **no tracked file
outside those four was touched** — in particular no `xschem_library/` file: every probe that wrote
anything wrote into the session scratchpad or a `test_scratch` directory.

---

## 0. The ruling this implements

> "When commas are used in the create form, that's multiple labels, not a bus. So the user can
> only specify bits of a bus using the property edit form."
> — the user, 2026-09-30

Issue 1623 was right about the **rendering** and wrong about **where the control lives**. The
rendering is untouched here (see §4). What moved is the checkbox.

**Why the move is mechanical and not a matter of taste.** Once a comma in the create form always
splits, every label that form produces is a **single token**. A single token has nothing to stack —
that is the user's own diagnostic (`busname<3:0>` must render identically either way), and rows
`V4`/`V13` have pinned it since 1623. So a vertical-justification control on the create form has
nothing to act on. It belongs where a multi-token bus label can exist: the Edit Properties form.

---

## 1. What changed, file by file, by symbol

### `src/xschem.tcl` — the create form loses the control

* **`namespace eval addlabel`** — the `variable vjust 0` declaration is **gone**.
* **`addlabel::start_pass`** — the `if {$vjust} { … set pending [list [join $toks ,]] } else { … }`
  branch is **gone**; the body is now the single unconditional line
  `set pending [addlabel::expand_names $name $split_bus]`. The proc declares no `vjust` and reads
  no flag of any kind.
* **`addlabel::arm`** — `set ::label_new_vjust $vjust` became **`set ::label_new_vjust 0`**, still
  published on *every* re-arm. **This is load-bearing, not tidiness.** `place_wire_label()`
  (`src/actions.c`) still reads that global and writes `vjust=1` from it; with no control on the
  form, simply *not touching* the global would let one stray `1` — from an old script, a replayed
  action log, or a pre-1625 session — silently stack every label the form placed from then on, with
  nothing anywhere to turn it off. Row `V20c` fences exactly that, and sabotage **S8** confirms it
  is the only row that does.
* **`addlabel::on_vjust_change`** — **deleted**.
* **`addlabel::open`** — the `ttk::checkbutton $w.f.vjust …` and its `grid $w.f.vjust -row 3 …`
  line are **deleted**. Verified live on `:99`: the form opens clean and its children are exactly
  `{lname TLabel} {ename TEntry} {split TCheckbutton} {multi TCheckbutton}`,
  `winfo exists .addlabel.f.vjust` → 0, and typing `a,b,c` gives `pending = a b c` with
  `::label_new_vjust` 0.
* **Comments retargeted** on the `addlabel` namespace header, `addlabel::split_display_tokens` and
  `addlabel::name_ok`, because all three described the removed mechanism.

**`addlabel::expand_names` and its 14 rows: untouched**, as instructed.

**`addlabel::split_display_tokens`: KEPT, and it is not dead.** Its caller for building a `lab=`
is gone, but it is still reached as the per-token splitter inside `addlabel::name_ok`'s comma-list
arm — the validator a comma-containing `lab=` has to pass, and that spelling is now the *only*
route to a stacked label. Its header comment now says so, and names rows `V1`–`V5` (the
display-line contract) and `V12b` (the C side's matching collapse) as its fences. Deleting it
would have required deleting five rows, which is forbidden.

### `src/property_form.tcl` — the property form gains the control

Four new pure procs, in a commented block placed immediately after `text_bool_value` (the
precedent they imitate):

* **`slickprop::symbol_type {symbol}`** — the symbol's `type` global attribute, with the *same*
  load-on-throw shape as the existing `template_of`: `getprop` throws when the symbol is not in
  this context's table yet, `load_symbol` keys it under its `rel_sym_path`, so every name form is
  tried rather than only the one handed in.
* **`slickprop::inst_schema {symbol}`** — returns
  `[list [dict create tok vjust label {Stack V} widget bool on 1]]` when
  `symbol_type` is `label`, else `{}`. **Keyed on the symbol's TYPE, not its file name**, so a
  user's own label cell (a copied `lab_pin`, a `lib/cell/view` ref) gets the control too —
  `type=label` is what the netlister itself dispatches on.
* **`slickprop::inst_owned {symbol}`** — the token names, **derived from `inst_schema`** rather
  than hand-kept (a second list is the same defect one level up, per the `X1` lesson in
  `test_snprintf_fmt_1608.tcl`).
* **`slickprop::inst_bool_value {symbol tok loaded chk0 chk}`** — the write-back, an exact sibling
  of `text_bool_value`: the schema knows the on-value, the generic `bool_value` decides.

Wired into the form at three points:

* **`slickprop::build_fields`** — declares `variable chk` and adds `array unset chk` beside the
  existing `array unset cur`; computes `ischema`/`iowned` from `$::symbol` (both in `catch`, beside
  the existing `cellform_ns` lookup); **skips an owned token in the generic field loop**
  (`if {[lsearch -exact $iowned $tok] >= 0} continue`, placed *before* the Extra-divider logic so a
  label whose only undeclared token is `vjust` does not grow an empty "Extra (undeclared)"
  heading); and, after the loop, renders one `checkbutton` per schema row in the same three columns
  as a text row (modified-cue dot | right-aligned label | widget), recording
  `cur(bool,…)`, `cur(on,…)`, `cur(chk0,…)`, `cur(loaded,…)` and appending to `cur(tokens)`.
  The tick state lives in `slickprop::chk(<tok>)`.
* **`slickprop::field_value`** — a new first branch: for a bool row, return
  `bool_value $cur(on,$tok) $cur(loaded,$tok) $cur(chk0,$tok) $chk($tok)`. Everything downstream
  (`collect_changes`, `result`, `update_dirty`, `is_dirty`, `do_apply`) is unchanged and works
  through it.
* **`slickprop::edit_form`** — the initial-focus loop now skips a bool row
  (`selection range` / `icursor` are entry methods a checkbutton does not have, and a symbol's
  `select` attr could in principle name one).

**Why the skip in `build_fields` matters, stated exactly:** `vjust` is declared in no label
template, so a prop string that *carries* it is also listed by `to_fields` as an undeclared
"Extra". Without the skip, one token gets two widgets, lands in `cur(tokens)` twice, and
`collect_changes` asks `field_value` about it twice. See §3, sabotage **S4** — the first version of
row `V33` did **not** catch this, and the sabotage is what named the right fixture.

### `doc/claude/specs/add_wire_label.md`

Form sketch loses the checkbox line ("Three behaviours ship now" → "Two"). The
*Vertical justification* section is rewritten: it quotes the ruling, spells out the mechanical
consequence, documents `inst_schema`/`inst_owned`/`Stack V` and the `type=label` keying, states the
user's new route in one sentence, records why `::label_new_vjust 0` is published actively, and
retitles the fence paragraph with the new row families and their two arms. It also records that
`split_display_tokens` is kept and why.

### `tests/headless/test_add_wire_label.tcl`

See §2 and §5.

---

## 2. RED FIRST — the failing rows, verbatim, before any product change

Nine rows were written and run against the **unfixed** tree (`c5a11808`, binary rebuilt: `make -C
src` → "Nothing to be done", already current). Command:

```
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_add_wire_label.tcl
```

```
FAIL: V19 the create form owns NO vjust variable, and a stray one planted in its namespace cannot collapse the comma list into one label -- tokenisation branches on nothing -> {1 1 {bg_trim[3:0],en_fast,iref_trim[2:0]}} (exp {0 3 {bg_trim[3:0]}}) : FAIL
FAIL: V24 the create-form control is GONE FROM THE SOURCE, not merely inert: addlabel::open builds no vjust checkbutton, on_vjust_change no longer exists, and start_pass holds no branch on any flag -- an inert widget would still invite the user to tick it -> {1 1 1} (exp {0 0 0}) : FAIL
FAIL: V25 slickprop::inst_schema offers exactly ONE bool row for a type=label symbol: the vjust token, whose on-value is the same 1 place_wire_label() writes -> {threw (invalid command name "slickprop::inst_schema")} (exp {1 vjust bool 1}) : FAIL
FAIL: V26 the row carries the visible checkbox wording, so the control is a TICK BOX beside Center V and not a free-text token entry the user has to spell -> {threw (invalid command name "slickprop::inst_schema")} (exp {Stack V}) : FAIL
FAIL: V27 GUARD a non-label symbol is offered NOTHING -- vjust is a net-label display flag, not a generic instance attribute, and a resistor form must not grow a checkbox for it -> {threw (invalid command name "slickprop::inst_schema")} (exp {0}) : FAIL
FAIL: V28 the form OWNS the token: inst_owned names vjust, and to_fields ALSO lists it (as an undeclared Extra) for a prop that holds it -- so without the owned list ONE token would get TWO widgets and collect_changes would see it twice -> {threw (invalid command name "slickprop::inst_owned")} (exp {vjust 1 1}) : FAIL
FAIL: V30 write-back BOTH ways: ticking an unflagged label writes vjust=1, unticking a flagged one REMOVES the token (empty value -> subst_tok <NULL>), and an UNTOUCHED box returns its loaded value VERBATIM -- so collect_changes omits it and an unusual hand-written spelling survives -> {threw (invalid command name "slickprop::inst_bool_value")} (exp {1 {} 1 true}) : FAIL
FAIL: V31 END TO END on the real drawing: ... -> {{threw (invalid command name "slickprop::inst_bool_value")} {threw (invalid command name "slickprop::inst_bool_value")} {threw (invalid command name "slickprop::inst_bool_value")} {threw (invalid command name "slickprop::inst_bool_value")} 1 0 1 1 1} (exp {ok ok ok ok 1 1 1 1 1}) : FAIL
FAIL: V32 the core is WIRED INTO the form and not sitting unused: build_fields consults inst_owned (to skip the duplicate Extra) and renders inst_schema, and field_value reads a bool field back through bool_value -- every row above would pass with no checkbox on screen at all -> {0 0 0 0} (exp {1 1 1 1}) : FAIL
RESULT: 9 FAILED (224 passed)
OVERALL: notok
```

Note every row **FAILED, none THREW**: the `v_try` wrapper (already in the suite) turned each
missing command into the legible sentinel `threw (invalid command name "…")` instead of aborting
the suite. Two rows added later (`V33`–`V38` on the Tk arm, and `V39`) were verified red by
sabotage instead — see §3, **S1/S4/S13/S14b**.

## GREEN, both arms, after the change

```
$ ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_add_wire_label.tcl
SKIP: V33-V38 need a Tk arm (no widgets under --nogui) -- run tests/headless/run_suites.sh test_add_wire_label
RESULT: ALL PASS (234 checks)
OVERALL: ok

$ tests/headless/run_suites.sh test_add_wire_label
test home: throwaway /tmp/xschem-test-home.<pid>.XXXXXX (your HOME is untouched; …)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_add_wire_label          run 1/1  RESULT: ALL PASS (223 checks)
RESULT: 1/1 runs passed
```

224 → **234** headless (+10: nine red-first rows plus `V39`), 207 → **223** on the Tk arm
(+16: the same ten, minus the five `V.5` rows that skip there, plus the six new `V.8` rows and
`V39`).

**Neighbouring suites, unaffected and re-measured:**

```
$ tests/headless/run_suites.sh --nogui test_create_instance test_isources test_vpwl test_vpulse \
      test_sch_add_pin test_add_pin_lib_symbol_view test_hash_label_crash_0156 test_add_wire_label
NORESULT | test_create_instance         run 1/8 (exit 0 — binary never reported)
PASS     | test_isources                run 2/8  RESULT: ALL PASS (9 checks)
PASS     | test_vpwl                    run 3/8  RESULT: ALL PASS (13 checks)
PASS     | test_vpulse                  run 4/8  RESULT: ALL PASS (6 checks)
PASS     | test_sch_add_pin             run 5/8  RESULT: ALL PASS (34 checks)
PASS     | test_add_pin_lib_symbol_view run 6/8  RESULT: ALL PASS (via OVERALL: ok sentinel)
PASS     | test_hash_label_crash_0156   run 7/8  RESULT: ALL PASS (23 checks)
PASS     | test_add_wire_label          run 8/8  RESULT: ALL PASS (233 checks)
```

`test_create_instance`'s `NORESULT` is **my invocation, not my change**: that suite needs Tk
(`invalid command name "winfo"`, its own line 76), is in **neither** `hcases` nor `dcases`, and
passes on the display arm — `tests/headless/run_suites.sh test_create_instance` → `PASS … ALL
PASS`. (The 233 there predates `V39`.)

**The property-form core suite**, the correctness gate `build_fields` rests on, run the way its own
header specifies (from `src/`, Tk arm):

```
$ cd src && DISPLAY=:99 HOME=<scratch> ./xschem -q --pipe --nolog --script ../tests/property_form/wrap.tcl
/tmp/sh_pf_test.log: 288 PASS, 0 FAIL, DONE
```

⚠ Run from the repo root instead, `PF9a` fails (`tested a meaningful number of real instances
(> 50)`) because `PF9` loads `../xschem_library/examples/mos_power_ampli.sch` relative to CWD. That
is the suite's documented CWD requirement, not a regression.

---

## 3. Sabotage — site by site, and the two that had to be fixed

Each sabotage was applied to the working tree, both arms re-run, then the file restored from a
scratch backup (never `git checkout`, which would have destroyed uncommitted work). "Tk arm" =
`DISPLAY=:99 HOME=<scratch> ./src/xschem -q --pipe --nolog --script <suite>`, baseline 223.

| # | what was broken | headless reds | Tk-arm reds |
|---|---|---|---|
| S1 | `inst_schema` returns `{}` unconditionally | V25 V26 V28 V30 V31 (V39 after it existed) | + V33 V34 V35 V36 V37 |
| S2 | `inst_schema` drops the `type=label` test (offers it for every symbol) | V27 | + V38 |
| S3 | the visible label changed to `Vertically justified` | V26 | — |
| S4 | the `iowned` skip removed from `build_fields` | **none** (no widgets headless) | V33 |
| S5 | the bool branch removed from `field_value` | V32 | + V34 V35 V36 V37 |
| S6b | `inst_bool_value` returns `$on` always (ignores the tick state) | V30 V31 | same |
| S7 | the `if {$vjust}` branch restored in `start_pass` | V19 V24 | — |
| S8 | `arm` stops publishing `::label_new_vjust 0` | V20c | — |
| S9b | the create-form checkbutton re-added to `addlabel::open` | V24 | — |
| S10 | schema on-value `1` → `0` | V25 V30 V31 | + V35 |
| S11 | `symbol_type` blinded (returns `""` always) | V25 V26 V28 V30 V31 | — |
| S13 | `cur(chk0,…)` hard-wired to 0 (wrong baseline) | **none** | V36 V37 |
| S14b | `inst_schema` empty, re-run to verify `V39` | V25 V26 V28 V30 V31 **V39** | — |

**TWO SABOTAGES SURVIVED ON THE FIRST ATTEMPT AND BOTH WERE FIXED BY CHANGING THE ROW, NOT THE
SABOTAGE.** They are the most useful thing in this receipt:

* **S4 survived.** Row `V33`'s first fixture used a prop with **no** `vjust` token, so `to_fields`
  listed nothing for the generic loop to duplicate and the collision could not arise — deleting the
  skip changed nothing observable. `V33` now builds from `{name=l1 lab=a,b,c vjust=1}` (the token
  *present*), and additionally asserts the whole token list holds **no duplicate at all**
  (`llength $toks == llength [lsort -unique $toks]`), not only that `vjust` appears once. That
  comment is written into the row. S4 then reddens `V33` on the Tk arm. Headless cannot see it —
  inherent, there are no widgets — and that is stated in the row's own block comment.
* **S14 survived** (the first attempt at verifying `V39`). `V39` asserted the three-line
  progression `abs((h3-h1) - 2*(h2-h1)) < 0.01`, which is **vacuously true when nothing stacks at
  all** — all three heights are then equal. Fixed by adding the growth element
  `h2 > h1 + 1.0` (which `V31` already carried). S14b then reddens `V39`. **This is the
  "fence keyed to a symptom" trap from CLAUDE.md in its arithmetic form**: a relation among
  differences is satisfied by the degenerate case.

**One sabotage is reported as a pre-existing gap, not a survivor of mine.** Breaking
`slickprop::text_bool_value` (the *text* panel's wrapper, one line above my block) reddens
**nothing** in `test_add_wire_label` — correctly, it is not this suite's subject. Its fences are
rows `TX9`/`TX10` of `tests/property_form/body.tcl`, and **that suite is in neither `hcases` nor
`dcases`**, so nothing gates it. I did not widen its coverage: registering it is a separate,
gated change (its epilogue is `DONE`, not the `OVERALL: ok` sentinel `banner_complete` requires,
and it needs Tk, so it would be a `dcases` entry with a banner fix first). Flagged for the driver.

---

## 4. `sym_text_vstack()` and its six call sites: NOT TOUCHED

No change to `src/draw.c`, `src/svgdraw.c`, `src/psprint.c`, `src/select.c` or `src/actions.c`.
The transform is already general — it stacks any instance carrying a truthy `vjust` whose `@lab`
record holds a comma — so nothing in it needed to know that the flag now arrives from a different
form. Rows `V11`–`V17`, `V12b` and `V21`–`V23` still hold it shut and all still pass.

The checkbox's on/off semantics were matched to the C rather than the reverse: `sym_text_vstack()`
gates on `strboolcmp(vj, "true")`, so any truthy value stacks and `0`/`false`/`no`/absent does not.
`bool_checked`'s default arm already has exactly that rule, which is why no new predicate was
written. Rows `V29` (pure) and `V37` (Tk: `vjust=true` ticked, `vjust=0` unticked) pin the
agreement.

---

## 5. Every row that was restated, and what each now asserts

**Nothing was deleted.** Five rows asserted the create-form behaviour being removed; each still
measures the same plumbing and now asserts the ruling instead of the branch. They live in the
`V.5` block, which is guarded to run **only headless** (it stubs `proc winfo`, and under a real
`$DISPLAY` that replaces Tk's builtin while `rename winfo {}` destroys it).

| row | was | now |
|---|---|---|
| `V18` | "GUARD **with the flag OFF** the same typed entry is still a QUEUE of three separate labels" | "a comma in the create form **ALWAYS** separates labels: the typed entry is a QUEUE of three, **and no flag can make it one** (the user's ruling)". Same measurement, the `set addlabel::vjust 0` line gone. |
| `V19` | "**with the flag ON** the same entry becomes ONE label whose name is the whole comma list" — i.e. it pinned the branch | "the create form owns **NO** vjust variable, and a **stray one planted in its namespace** cannot collapse the comma list into one label — tokenisation branches on nothing". Asserts `[info exists ::addlabel::vjust]` is 0 **before** planting one, then that `start_pass` still yields the 3-name queue. Moved to **last** in the block on purpose (a planted stray is read by an unfixed `start_pass`, so any row after it would be measuring the stray), and wrapped in `v_try`. |
| `V20` | "the armed preview stores the canonical comma list **and carries the per-instance flag**" | "the armed preview stores the **HEAD token** verbatim with ZERO newlines and carries **NO** vjust token — the create form never writes one". The zero-newlines half is unchanged. |
| `V20b` | "**the flag** and the name both survive a re-arm" | "**the name** survives a re-arm **and the instance still carries no vjust token**". |
| `V20c` | "clearing the flag re-arms with NO vjust token on the instance" | **the stale-global fence**: "a stale `::label_new_vjust=1` cannot put a vjust token on a form-placed label — every arm republishes 0". Plants `1` in the global, re-arms, asserts both the absent token *and* that the global is back to `0`. This is the row that makes the active clear in `addlabel::arm` non-deletable (sabotage S8). |

Rows `V1`–`V17`, `V12b` and `V21`–`V23` were **not** touched: `V1`–`V5` still pin
`split_display_tokens` (still reached, §1), `V6`–`V10` still pin `name_ok`'s comma-list arm (still
the validator a property-form comma list must pass), and the renderer/netlist rows are unaffected.

### New rows

**`V.7`, headless, runs on both arms** (9 rows): `V24` the create-form control is gone from the
source (not merely inert) · `V25` the schema's shape · `V26` the visible wording · `V27` GUARD a
non-label symbol is offered nothing · `V28` the `inst_owned` / `to_fields` collision · `V29` GUARD
the tick state off the token value · `V30` write-back both ways plus the verbatim-preserve ·
`V31` END TO END on the real drawing, exact line counts by arithmetic progression, and unticking
collapses back · `V32` the core is wired into the form (the row that stops a pure core passing
everything above while no checkbox exists) · `V39` the user's whole journey.

**`V.8`, a Tk arm only** (6 rows, `V33`–`V38`): one token gets one widget and it is a
`Checkbutton`; absent/present token tick state; the cardinal invariant under an untouched box; the
`vjust=true` / `vjust=0` spellings; the resistor guard. Guarded by `if {[info commands winfo] eq
{}}` and printing an **uppercase** `SKIP:` under `--nogui`, exactly as sections `W` and `V.5`
already do in this file — uppercase so `summarize_all`'s `^skip:` predicate does not count it into
T1's `skips=`. Built in a **withdrawn** toplevel (the recipe `tests/property_form/body.tcl` uses)
so nothing appears on the display, and `.pf` is destroyed at the end.

### One measurement worth keeping

`V31` first failed on **arithmetic, not on the product**: `text_bbox()`'s box carries a
zoom-dependent fractional margin, so in this fixture one line is 20.27 units. Rounded, the
progression is 20 / 41 / 61 and `h1 + 2*(h2-h1)` doubles the rounding error to 62. Both `V31` and
`V39` therefore use a new unrounded helper `v_hf` and a 0.01 tolerance. The standing warning at the
head of section `V` ("never absolute coordinates") already said not to trust absolute numbers; this
is the same trap one level in, on a *relation* among rounded numbers.

---

## 6. Wording: `Stack V` — chosen, and why

**The chosen string is `Stack V`.** Reasoning:

* It matches the **existing vocabulary of the same form**. `slickprop::text_schema` already ships
  `Center H` and `Center V` — a verb plus an axis letter. `Stack V` reads the same way and sits
  beside them without looking imported.
* It is **terse** and carries no acronym (the repo's UI-copy rule: terse, acronyms UPPERCASE —
  there is no acronym here, so nothing to uppercase). The other bool labels on this form are
  `Bold`, `Italic`, `Hidden`, `Floater`, `Show name` — one or two words.
* It says **what happens**, which the old string did not. "Vertically justified" is
  typographically wrong: justification is alignment to a margin, not stacking. The box puts one
  bus token per line; "stack" is the word for that.

**⚠ This is the user's own phrase being replaced.** They coined "vertical justification", which is
why issue 1623 is named for it. So a ruling is genuinely available here, and the alternatives, with
their costs:

* `Vertically justified` — their own words, maximal recognition, but long for this column and
  describes the wrong typographic operation.
* `Stacked` — shortest, but silent about the axis and about what is stacked.
* `One per line` — clearest to a first-time reader, but breaks the `Center H`/`Center V` idiom.

The string is a one-word edit: row `V26` asserts it directly and is the only place in the tree that
spells it, so changing it costs one line of product and one of test. **The word `vjust` stays as the
stored token regardless** — it is on disk in any file already saved with 1623's build.

---

## 7. Does removing the create-form control dissolve `rule/1623`? — YES, with evidence

The debt on the user's queue reads, verbatim from `~/.claude/xschem_owed/rule/1623`:

> "Split bus is silently ignored when Vertically justified is ticked -- a ticked box that does
> nothing, with no status copy saying so. What should it say, or should the box grey out?"

**The state it describes can no longer be entered.** Three independent pieces of evidence:

1. **There is no box to tick on that form.** Measured live on `:99`: `addlabel::open` returns 0 and
   `.addlabel.f`'s children are exactly `lname`/`ename`/`split`/`multi`;
   `winfo exists .addlabel.f.vjust` → 0. Row `V24` asserts `info body addlabel::open` contains no
   `vjust`, that `addlabel::on_vjust_change` does not exist, and that `start_pass` holds no branch
   on any flag. Sabotage **S9b** (checkbox re-added) reddens `V24`.
2. **"Split bus" can no longer be bypassed.** `addlabel::start_pass` is now the single line
   `set pending [addlabel::expand_names $name $split_bus]` — `split_bus` is consulted on every
   pass, with no branch that can skip it. Row `V18` asserts the queue splits; row `V19` asserts
   that even a stray `::addlabel::vjust 1` planted in the namespace cannot change it. Sabotage
   **S7** (branch restored) reddens `V19` and `V24`.
3. **The two controls are now on different forms, acting on different things.** "Split bus" is a
   create-form variable read only by `expand_names` inside `start_pass`, and it decides *how many
   labels get placed*. `Stack V` is a property-form bool on *one already-placed instance*, and it
   decides *how that one label's comma list is laid out*. They cannot be set on the same operation,
   so neither can silently ignore the other. Row `V39` drives the only surviving route to a stacked
   label end to end.

**So the question retires**, and with it the sub-question "should the box grey out" — there is no
box. ⚠ **I did not clear the debt** (`owed.sh clear rule` is forbidden to me and it is the user's
queue). The driver should put it to the user as "this is retired by 1625, may we clear it?" rather
than as a design question. The `rule/1623` entry's `ref:` still points at the 1623 issue file,
which is correct history.

**No new `rule` or `look` debt was filed by this stage.** The wording choice in §6 is the one thing
a human might overrule, and it is stated here for the driver to raise as part of the same
conversation rather than as a second queue item — one ruling at a time.

---

## 8. Expected T1 movement — 112 / 111 / 0 / 8, i.e. **no movement**

Baseline at `c5a11808`: `cases=112 blocks=111 counted_failures=0 skips=8`.

* **cases 112, blocks 111 — unchanged.** No suite was registered or de-registered;
  `tests/run_regression.tcl` is not modified (`git status` shows it clean). `test_add_wire_label`
  remains a single `hcases` entry (`grep -c` → 1, at `headless/test_add_wire_label`).
* **`counted_failures` 0 — unchanged.** Both arms of the only changed suite are green, and the
  seven neighbouring suites that touch the changed procs are green.
* **`skips=` 8 — unchanged.** The new `V.8` block prints **`SKIP:`** in uppercase.
  `summarize_all`'s predicate is `[regexp {^skip:} $line]` (read at HEAD), so an uppercase
  `SKIP:` is not collected — the same reason sections `W` and `V.5` in this same file have never
  contributed to the count. Verified by reading the proc, not by inference.
* **`wc -l` of the verdict — unchanged.** No `skip:` or `RESULT:` line is added or removed; the
  case's existing `RESULT:` line simply now reads `ALL PASS (234 checks)` instead of
  `(224 checks)`.

⚠ CLAUDE.md's own warning applies: `skips=8` has now held across many figures by coincidence of
what was registered, and this change is a **fourteenth** figure that keeps it at 8 for yet another
reason (a suite whose new block self-skips in **uppercase**, on a suite registered in `hcases`
alone). **Read the trailer, do not check against 8.**

**I did not run a full T1** — instructed not to.

---

## 9. What I did NOT do, and what is unverified

* **No commit, no push, no gate, no stash.** Work left uncommitted in the four files above.
* **No issue file, and `NUMBERING.md` not updated.** `doc/claude/issues/1625-*.md` does not exist
  and `NUMBERING.md` still says "The next free number is 1625." The driver minted 1625 and told me
  not to mint another, so the bookkeeping is the driver's — but CLAUDE.md requires the number to be
  recorded in `NUMBERING.md` **in the same commit**, so **this is an action item for the driver**.
  `tclsh tests/headless/issue_stamp.tcl` → `ISSUE-STAMP: ok (0 problems)` right now, and will stay
  ok only if any new issue file carries a valid `**STAMP:**` line.
* **No C change.** `place_wire_label(const char *name, int vjust)` keeps its parameter and
  `scheduler.c` keeps reading `::label_new_vjust`. I considered removing both and decided against
  it: the Tcl side now actively publishes 0, which row `V20c` fences, and removing a C signature
  plus its dispatcher read is a wider change than the ruling requires. **The cost is honest and
  worth naming: the C path can still write `vjust=1`, and the only thing keeping it quiet is one
  Tcl line.** If the driver prefers the parameter gone, `V20c` is the row that would need
  restating.
* **`build_fields` is fenced on a Tk arm that T1 does not run.** `test_add_wire_label` is in
  `hcases` alone, so `V33`–`V38` gate nothing; they run under
  `tests/headless/run_suites.sh test_add_wire_label` and under `full_audit.sh` (which globs
  `tests/headless/test_*.tcl`). Adding the suite to `dcases` would put them in front of a gate and
  is itself a change that needs gating — out of scope here, and flagged.
* **No human has seen the new checkbox.** Its existence, class, label text, tick state and
  write-back are all measured mechanically (`V25`–`V38`, and the live `addlabel::open` inspection),
  and the drawing it produces is measured end to end (`V31`, `V39`). What is **unverified** is
  purely cosmetic: where the row sits visually relative to the fields above it (it is appended
  after the template-derived fields and after any "Extra" section, in the same three-column grid),
  and whether `Stack V` reads well at the form's font size. **I filed no `look` debt for it** — the
  driver may prefer to roll it into the §6 wording conversation, since the same reply would cover
  both.
* **Not measured:** the `apply_properties` route was confirmed to add *and* remove the token in a
  standalone probe, but the committed rows install the property string with
  `xschem setprop instance <n> allprops`, because `apply_properties` needs `::symbol` and
  `::user_wants_copy_cell` set the way the live form sets them and a probe that gets that wrong
  silently re-points the instance's master (observed: a bogus symbol and a wrong bbox). The form's
  own `do_apply` path is unchanged by this stage and is exercised by
  `tests/property_form/body.tcl`'s `NA*` rows (288 PASS, above).
