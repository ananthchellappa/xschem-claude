# PLAN — OP parameter lists, the authoritative item list

Spec: `doc/claude/specs/op_param_lists.md`
Rulings: `DECISIONS.md` (D-1 … D-8) — **read that first, it overrides the spec**
Measurements: `doc/claude/code_analysis/1244_op_param_list_measurements.md`
Issues: **1244** (declutter) · **1245** (Results Display Window)

Eight items. Each is independently testable and names its own files, so two
items that do not share a file may run concurrently. The dependency edges are
the only ordering constraint.

```
A1 ──┐
A2 ──┴─> A3                     (feature A — 1244)

B1 ──┐
B2 ──┼─> B5                     (feature B — 1245)
B3 ──┴─> B4
```

---

## A1 — the mask bit and the chord  ✅ **DONE (status E), 2026-09-02**

**Do.** Add `ANNOT_SHOW_NOPARAM 8` to the `annot_show` mask. Add
`cadence::annot_declutter toggle` in `utils/annot_mode.tcl`, writing the mask
**only** through `xschem set annot_show N` (never a bare `set ::annot_show` —
the C field reads stale and the variable is an integer, so `true` atoi's to 0).
Bind `<Control-Alt-Key-6>` in `src/cadence_style_rc`, **explicitly and with a
trailing `break`**.

**Why it is not free.** Tk matches a pattern whose modifiers are a *subset* of
the event's, so today `Ctrl-Alt-6` falls into `<Alt-Key-6>` and switches node
voltages on. This item's headline check is that it no longer does.

**Files.** `src/xschem.h` · `utils/annot_mode.tcl` · `src/cadence_style_rc` ·
new `tests/headless/test_annot_declutter_1244.tcl`

**Accept.** A chord matrix fired with `event generate` under all four profiles:
`6`→`|=1`, `Ctrl-6`→`0`, `Alt-6`→`|=2`, `Alt-Shift-6`/`Alt-asciicircum`→bit2,
`Ctrl-Alt-6`→toggles bit3 **and leaves bit1 alone**. Plus: `rectcolor` unchanged
throughout, and `xschem set annot_show true` still reads back 0 (the trap, pinned
so nobody "fixes" it).

**Landed.** `tests/headless/test_annot_declutter_1244.tcl`, **36 checks, ALL
PASS**. Audit **364/11/0/2 of 377 → 365/11/0/2 of 378**, the eleven reds
identical by name. Full record:
`doc/claude/op_param_batch/receipts/A1.md`. **Status E** — the three status
sentences are unratified (`rule` debt 1244) and the ON one describes the world
A3 creates. Filed and not fixed: **1246**, **1247**, **1248**.

**⚠ Deviation, deliberate, and it binds every later item.** This item's Do cell
said "register it in `tests/headless/full_audit.sh`". **That file was not edited
and must not be.** Registration on this tree *is* the
`ls "$HERE"/test_*.tcl | sort` glob at `:393`; the three named lists
(`nogui_tests`, `logdir_tests`, `nolog_tests`) are opt-ins for special run modes,
and putting an `event generate` suite on `nogui_tests` strips X and breaks
`bind` outright. **Every new suite in this batch moves the audit denominator, so
diff by name and status, never by count.**

---

## A2 — the name classifier  ✅ **DONE (status x), 2026-09-02**

**Do.** Add `TEXT_ANNOT_NAME 1024` and set it in `set_text_flags()`
(`src/actions.c:1289`) beside the existing `annot_content_class()` call, on a
**whole-string** match (the existing classifier's discipline) against the three
spellings: `@name`, `@spiceprefix@name`, `@symname`.

**Why three.** Measured across 3,686 shipped `.sym` files: `@name` 3,165,
`@symname` 1,386, `@spiceprefix@name` 81. `draw.c:873`'s shipped keep-name test
misses the third, which is gf180's FETs and the generic `devices/nmos4.sym`. Do
not copy that test — it carries a measured bug.

**Files.** `src/xschem.h` · `src/actions.c` · rows in A1's suite

**Accept.** All three spellings classify; a text merely *containing* `@name`
(e.g. `x=@name`) does **not**; the bit is additive and changes no existing
`hide=` behaviour; `flags` is still never serialised.

**From A1, 2026-09-02.** `src/xschem.h` moved: A1 inserted 32 lines
**immediately after** `ANNOT_SHOW_TRAN`, a pure insertion, so `ANNOT_SHOW_OP`,
`ANNOT_SHOW_VOLTAGE` and `ANNOT_SHOW_TRAN` are still at 432/433/454 and
**everything below 454 shifted by +32**. `TEXT_ANNOT_NAME 1024` belongs in the
*other* block, beside `TEXT_ANNOT_CURRENT 512` — a different block, so the two
edits do not collide — but **do not cite a line number in any comment you add**:
A2's own insertion shifts the mask block in turn. A1's suite already exists and
already carries the three readers A2 needs (`opa_n_grep`, `opa_proc_src`,
`opa_n_rcbind`, the last extended with a `declutter` arm); append rows to it and
keep the banner shape `RESULT: ALL PASS (N checks)` / `RESULT: N FAILED`.

**Landed.** `#define TEXT_ANNOT_NAME 1024` beside `TEXT_ANNOT_CURRENT 512`, a new
`static annot_name_token()` in `src/actions.c`, and one call in
`set_text_flags()`. Suite **36 → 52 checks, ALL PASS** (new section N; the two
extra rows over the planned 50 are N6b/N8b, see below). Every tier
name-identical to the baseline; audit denominator unchanged at **378** because
A2 added rows, not a suite. Eight sabotage variants, **every predicted red
observed**. Full record: `doc/claude/op_param_batch/receipts/A2.md`. Filed and
not fixed: **1249**, **1250**. **Status x** — nothing is user-visible until A3
(measured cross-binary: the SVG and the round-trip `.sch` are byte-identical to
the pre-A2 build) — but one **`rule` debt is wanted before A3 lands**, see below.

---

### What A2 learned that binds item A3

1. ⚠ **The bit is set UNCONDITIONALLY, outside the `annot_class_free()` gate**,
   and the spec's *"one more implicit content class beside `annot_content_class()`'s
   existing two"* implied otherwise. The gate exists for one mechanism — the two
   class bits are a **visibility authority** that `text_hidden()` early-returns
   on before `show_hidden_texts` — and `TEXT_ANNOT_NAME` is deliberately absent
   from the content-class-to-mask helper, so that mechanism does not exist for
   it. **The consequence is invisible until A3's rung lands**, which is why
   `rule` debt **`1244_A2_name_bit_vs_hide_true`** is wanted **first**: *should a
   `hide=true` `@name` be drawn under declutter with View > Show hidden texts
   ON?* A2 chose yes. Zero shipped symbols in any PDK are affected either way.
2. ⚠ **`HIDE_TEXT_PARAM` does not exist and must not be invented.** The spec's
   §4.1/A2 snippet predates D-1; the rung's test is *"carries neither
   `TEXT_ANNOT_NAME` nor an annotation class"*. `TEXT_ANNOT_NAME 1024` is the
   **eleventh and last** documented power of two in `xText.flags`, and A3 needs
   no bit of its own — its per-instance gate cannot live there at all.
3. ⚠ **Do NOT add a NAME arm to the content-class-to-mask helper.** Row **N9** is
   labelled PERMANENT and applies to A3 too: a NAME arm there makes every `@name`
   on every symbol follow `annot_show`, and additionally blanks the **eleven
   shipped `@name` FLOATERS** on `mos_power_ampli.sch` / `pv_ngspice.sch` and
   their four mirrors (a schematic-own floater is not exempted by the ctx guard).
   `test_op_annot`'s row U35 **cannot** catch it — it counts calls, not contents.
   A3's rung goes in `text_hidden`, **after** the class tests.
4. ⚠ **`xText.flags` is NOT observable from Tcl and the obvious probe lies.**
   `xschem get text_flags` does not raise — it returns the **empty string**
   through the generic `get` fall-through, with or without an index; only
   `xschem text_flags 0` errors. `scheduler.c` reads `text[i].flags` once (a
   `TEXT_FLOATER` test) and never exposes `text_hidden`. So A2's positive rows
   are **structural** (C function-body slices via the new `dc_cbody`) and its
   behavioural rows can only be **negative**. **A3 hits the same wall**, and A3
   already owns `scheduler.c`-adjacent work nowhere — decide explicitly whether
   to add a three-line reflection accessor or to say in writing that it did not.
5. ⚠ **Structural rows need MUTATION testing, not just the sabotage list.** All
   eight A2 variants were caught, and the adversary then found **two further
   mutations that passed every row**: `len >= 5` instead of `len == 5` (which
   classifies `@name_foo`, `@names` and ~34 shipped `@name <param>` records — the
   brief's own ACCEPT row) and `annot_name_token(t->prop_ptr)` (feature wholly
   inert). Closed by rows **N6b** and **N8b**, both re-run against the mutations.
   Budget a mutation pass for A3's structural rows.
6. ⚠ **A red row whose expected value is produced by a path the RED state cannot
   execute is not a tested row.** A2's RED pass wrote `regexp "…$L(…)"` — bare
   `$L(` is a Tcl **array** reference. It could not fire during RED (`dc_cbody`
   returned `{}` for a function that did not exist yet), and the moment the C
   landed it aborted the suite mid-run with `variable isn't array`: 40 `ok` rows
   and **no verdict**. Run every new row once against the GREEN tree too.
7. ⚠ **`owed.sh add rule <id>` dedupes by id and writes with `>` — it
   OVERWRITES.** `add rule 1244` would have silently destroyed item A1's standing
   1244 question. A crew of parallel items on one feature number must suffix the
   id (A2 used `1244_A2_name_bit_vs_hide_true`). Worth fixing in `owed.sh`.
8. **The rows A3 inherits by name.** **N10** is labelled `A3 MUST REPLACE THIS
   ROW` for the same reason issue 1248's row I2 is — an honest behavioural proof
   of `get_annot_overlay()`'s synthetic `text_hidden(HIDE_TEXT_OP,
   TEXT_CTX_INSTANCE)` call needs a raw fixture in `test_op_annot.tcl`'s
   `opa_o_mkrlraw` shape. **N14** is labelled `1249 PINNED — WHOEVER FIXES 1249
   FLIPS THIS ROW`. **N9** and **N13** are PERMANENT.
9. **A2's fixture works where nand2 does not.**
   `xschem_libs_newsym/examples/cmos_inv/schematic/cmos_inv.sch` loads cleanly
   under `src/cadence_style_rc` (14 instances, 2 texts) and carries all three
   spellings on one sheet — `M1`/`M2` from `@spiceprefix@name`, `R1`/`V1`/`Vmeas`
   from `@name`, plus the schematic-own literals — at viewport
   `{2000 1600 0 -520 420 -20}`. **Use it when replacing I2/I3** rather than
   hunting for another.
10. ⚠ **42 shipped records put the name and a parameter in ONE `T` record** (29
    `.sym` + 13 `.sch`, 11 distinct strings: `@name\n@value` in `isource` and
    `filesource`, `@symname\n@file`, `@name\n@wn/@ln\n@modeln` in `inv-2`,
    `passgate`, sky130's `passgate_nlvt`, …). Whole-string correctly denies them
    the bit, so **A3's rung makes those devices lose their NAMES along with their
    parameters.** A consequence of **D-1**, not a bug — but user-visible and
    unratified. A3 should surface it, not discover it.
11. **The comment inside `text_hidden()`** — *"set_text_flags only adds it when
    the `hide=` chain set no bit"* — is now true only of the two mask-named bits.
    A2 could not edit that function. **A3 owns it; tighten the wording.**
12. ⚠ **Issue 1250: a T1 red naming `test_annot_stale_0684` F17 or F21 is NOT
    evidence about the change under test.** Its status-message rows are
    sensitive to the scratch path length (`_annot_fit` elides at 255 bytes and
    the sentence embeds the raw's absolute path, which `test_scratch` builds from
    the repo location **and the pid**): deterministic red at a scratch root of
    124 bytes, green at 120, shipped default 54. **Separately unexplained**, F21
    red once in a real `run_regression.tcl` run at the default path and did not
    reproduce in 3 further T1 runs or 10 standalone ones. Re-run solo and
    standalone before attributing it, and record both numbers.

---

## A3 — the draw rung and the per-instance gate  ✅ **DONE (status E), 2026-09-02**

**Do.** One rung in `text_hidden()`: in an instance context, with **both**
`ANNOT_SHOW_OP` and `ANNOT_SHOW_NOPARAM` set, hide any text carrying neither
`TEXT_ANNOT_NAME` nor an annotation class. Per D-6 the rung fires only for
instances whose `op_annot::text` block is non-blank — and because symbol texts
are **shared by every instance of a symbol** (`draw_symbol` walks
`symptr->text[j]`), that gate cannot live in `xText.flags`; carry it as a new
context value `TEXT_CTX_INSTANCE_ANNOTATED` at the six instance call sites.

**⚠ The eleventh call site.** `src/actions.c:1832`, inside
`get_annot_overlay()`, calls `text_hidden(HIDE_TEXT_OP, TEXT_CTX_INSTANCE)` with
a **synthetic literal** — it is asking "would an OP text show right now?" as a
proxy for "should the overlay paint?". The new rung must sit **after** the class
tests so this answer is unchanged. A declutter that switches the annotation
overlay off is the feature eating itself.

**Also owns the three defects A1 found and correctly did not fix:**

* **1246** — `Waves > Op Annotate` does `xschem set annot_show 3` at
  `src/xschem.tcl:17299` and `:17725`, a **hard set** that silently clears the
  declutter bit. Make it OR in `1|2` and leave bit 3 alone. (Adds
  `src/xschem.tcl` to this item's files.)
* **1247** — `annot_show_set()` (`src/actions.c:1406`) stamps `xctx->annot_root`
  for **any** nonzero mask, so two `Ctrl-Alt-6` presses — a net-zero pair whose
  advertised effect is nothing — convert an `xschemrc`-armed annotation into one
  a later `File > Open` clears. Pre-existing mechanism (issue **0688**); A1 owned
  no C file that could fix it. You do.
* **1248** — A1's suite proves the mask arithmetic well and the **rendering** not
  at all: its "A3 MUST REPLACE" tripwire runs on a fixture that cannot see the
  mask, so it cannot trip. **Replacing it with a real rendering check is this
  item's obligation, not an optional extra** — A1's status sentence *"a device
  showing operating-point values draws its name and those values only"* is a
  promise only this item can make true, and the driver accepted that wording on
  the explicit condition that A3 proves it.

* **1249** — the shipped keep-name test misses `@spiceprefix@name` in **all
  three render back-ends** (`draw.c:873` and its siblings in `svgdraw.c` /
  `psprint.c`). Measured by A2 and reproduced: at `hide_symbols=2` the render
  shows `@name` and `@symname` and drops the `@spiceprefix@name` instances
  entirely. You are rewriting exactly those loops, and A2 has already given you
  the correct predicate — `TEXT_ANNOT_NAME`. Fix it as you pass.

**Files.** `src/xschem.h` · `src/actions.c` · `src/draw.c` · `src/svgdraw.c` ·
`src/psprint.c` · `src/select.c` · `src/xschem.tcl` (1246) · rows in A1's suite

**Accept.** Per PDK (sky130, gf180, IHP): with annotation + declutter on, an
annotated FET draws its name and its OP block and nothing else; a subcircuit
instance is untouched; a descriptor-less cap/res is untouched. With
`ANNOT_SHOW_OP` clear the declutter bit changes **nothing**. The `.sch` bytes
are **byte-identical** across a toggle and the modify flag is not set. SVG and
PS exports agree with the screen. And the click target: `select.c:709` shrinks
the with-text bbox that `findnet.c:461` gates on, so record what happens to
`find_closest_element` rather than discovering it later.

**From A1, 2026-09-02 — four things that bind this item.**

1. **⚠ ROW I2's FIXTURE CANNOT SEE THE MASK — issue 1248.** A1's row I2 is
   labelled "A3 MUST REPLACE", but it renders `nand2.sch` with no raw and eight
   unresolved symbols, and *every* mask exports byte-identically there —
   measured `0=1 1=1 2=1 3=1 8=1 9=1 11=1`, **including 1 vs 3**, a pair that
   genuinely differ in meaning. **A3 can land, work perfectly, and leave I2
   green.** Replacing the row means replacing the fixture: a real raw, in
   `test_op_annot.tcl`'s `opa_o_mkrlraw` shape, so that 1 vs 3 differ *before*
   A3 lands and the row has a non-vacuity control. Row I3 (invariant I-C,
   permanent) needs the same fixture for the same reason.
2. **Use the SPEC's `text_hidden` call-site list, §2.3 — re-verified against the
   tree on 2026-09-02 and correct.** Eleven sites: `draw.c:872, 1140, 10307,
   10688` · `svgdraw.c:927, 1334` · `psprint.c:1209, 1710` · `select.c:709` ·
   `actions.c:1832` (the synthetic literal) · `actions.c:6324`. Six of them are
   `TEXT_CTX_INSTANCE`: `draw.c:872, 1140, 10307`, `svgdraw.c:927`,
   `psprint.c:1209`, `select.c:709`. **The list in CLAUDE.md and in the crew
   brief is stale on nine of ten entries** and names `actions.c:4422`, which is
   not a call site at all.
3. **Exposure grows here.** Issue **1246** (`Waves > Op Annotate` hard-sets
   `annot_show 3`, silently clearing bit 3) is invisible today and user-visible
   the moment A3 makes the bit hide text. Issue **1247** (a net-zero pair of
   presses arms the 0688 root-change clear) is the same shape.
4. **`cadence::_annot_msg` is blind to bit 3** — it switches on `$mask & 7`
   (`utils/annot_mode.tcl:906`), so after the declutter a subsequent `6` writes
   a status line that says nothing about the hidden parameters. A1 left it alone
   deliberately: row V21 of `test_op_annot.tcl` golds its eight arms
   byte-for-byte and A1 owns neither file. **A3 should decide whether to close
   that gap**, because A3 is the item that makes the silence wrong.

**Landed.** `text_hidden()` split into a `static text_hidden_core(flags, ctx, n)`
holding the five existing arms verbatim plus **one** new rung, a two-line
`text_hidden(flags, ctx)` delegate passing `n = -1`, and a new
`text_hidden_inst(flags, n)` at the six instance sites. The D-6 gate is
`annot_instance_annotated(n)` = `get_annot_overlay()`'s own precondition chain,
factored out as `annot_overlay_gate(n)`, **plus** a non-blank
`annot_overlay_cached_text(n)`. All four inherited defects fixed: **1246**
(both writers, bit-wise), **1247** (the exact-XOR stamp rule), **1248** (rows
I2/I3/N10/N14 replaced against a live fixture), **1249** (`annot_name_token()`
exported, three `strcmp` pairs become one call). Suite **52 → 82 checks, ALL
PASS**; `test_op_annot` 492, `test_annot_show_menu` 36, `test_annot_stale_0684`
52, T1 zero solo, T2 HARNESS PASS 6/6, `test_ase_window` 1 FAILED (227) — the
recorded pre-existing W7 red, bit-identical. Eight sabotage variants plus two
supplementary ones; the adversary did not refute. Full record:
`doc/claude/op_param_batch/receipts/A3.md`. Filed and not fixed: **1251**,
**1252**, **1253**, **1254**. **Status E** — two ladder-L3 questions are the
user's (below) and the per-PDK pixels are a `look` debt.

**The headline, measured on `cmos_inv.sch` + a descriptor + an OP raw:**

```
BEFORE   SVG identical 1 vs 9 : 1
         mask 9 texts: ... WP/LLP/1 M2 D {vgs=- - -} {vds=- - -} WN/LLN/1 M1 D vgs=0 vds=0 ...
AFTER    SVG identical 1 vs 9 : 0        (and 0 vs 8 : 1 — the bit alone still does nothing)
         mask 9 texts: ... M2 - {zid =} {zgm =} M1 - {zid =} {zgm =} ... R1 10 m=1 ...
```

---

### What A3 learned that binds the later items

1. ⚠ **`TEXT_CTX_INSTANCE_ANNOTATED` WAS REJECTED — the instance travels as a
   THIRD ARGUMENT.** `annot_class_mask()` and `annot_text_layer()` both open with
   `ctx != TEXT_CTX_INSTANCE`, so a fourth context value silently kills the
   implicit node-voltage class **and** 0615's colour override on exactly the
   annotated instances the feature targets — and a ctx *value* cannot carry a
   per-instance datum anyway, so each of the six sites would have had to compute
   the gate itself. **Any new instance-context call site must call
   `text_hidden_inst(flags, n)`, never `text_hidden(flags, TEXT_CTX_INSTANCE)`.**
   Row **A22** is the census: exactly six, `draw.c` 3 · `svgdraw.c` 1 ·
   `psprint.c` 1 · `select.c` 1.
2. ⚠ **`src/scheduler.c` joined this item's file set** and the PLAN's Files cell
   did not name it. One line — `annot_overlay_sync();` beside the existing
   `annot_show_sync_cache();` in the `update_all_sym_bboxes` arm — without which
   the shipped `annotate_op; update_all_sym_bboxes; redraw` computes every bbox,
   and therefore the **click target**, from the pre-annotate cache. It is
   currently **guarded by no test row** (issue **1254**).
3. ⚠ **THE CLICK TARGET MOVED, AND ITEM B4 CLICKS THESE DEVICES.** Measured on
   `cmos_inv` at mask 9: `M1`'s with-text bbox `x2` goes **177.376 → 157.433**,
   and `xschem instance_at <x> -170` stops answering `M1` at x = 160/170/175
   while 130/140/150 still answer (the surviving `@name` still stretches the box).
   Descriptor-less `R1` does not move at any mask. **B4 must call
   `xschem update_all_sym_bboxes` before its first pick** or its picks read from a
   stale overlay epoch — issue **1252**, whose exposure is exactly a hand-written
   pick path. Recorded as `rule` debt `1244_A3_click_target`.
4. ⚠ **Row U35 of `test_op_annot.tcl` constrains what may be written in
   `actions.c`.** It golds "`annot_class_mask(` appears exactly twice — defined
   once, called once", and it also forbids the folded
   `flags & (TEXT_ANNOT_VOLTAGE | TEXT_ANNOT_CURRENT)` spelling (issue 0678's
   landmine). A3's planned three-arm `annot_declutter_exempt()` reddened it on the
   first build; the shipped one is the single reachable test,
   `(flags & TEXT_ANNOT_NAME)`, and its soundness rests on the rung's **placement**
   below both class arms — pinned by row **A20**. A later item that moves the rung
   must move that reasoning with it.
5. ⚠ **The overlay's synthetic probe is safe twice over, and only one of the two
   is behavioural.** `get_annot_overlay()`'s `text_hidden(HIDE_TEXT_OP,
   TEXT_CTX_INSTANCE)` is byte-unchanged and now also passes `n = -1`. Sabotage
   `SB-OVERLAY-EATS-ITSELF` as the plan wrote it (repoint the probe at
   `text_hidden_inst`) is **behaviourally inert** — `HIDE_TEXT_OP` is 64, the mask
   helper returns 0 for it, and the probe returns at the arm above the rung — so
   only the structural row A21 notices. A supplementary variant that killed the
   overlay for real reds row **A9** at `{0 8 0 0}` against `{0 8 0 8}`, so A9 is
   not vacuous. **Overlay paint deltas per two warmed exports, hold later items to
   these: masks 0/1/8/9 → 0/+8/0/+8.**
6. ⚠ **D-6 SHIPPED AS "THE DESCRIPTOR RESOLVES", NOT "GOT OP NUMBERS", and that
   is a question for the user, not a settled fact.** `op_annot::text` emits
   blank-**valued** rows when the raw publishes nothing for a registered device,
   so a registered FET over a dead or partial raw is decluttered **while its block
   shows `zid =` with no number**. Reproduced twice, first-hand. Given measured
   rule **R1** (`gm`/`gds`/`vth` exist only if the deck saved them explicitly;
   `save all` does not include them) this is **common, not a corner**. `rule` debt
   `1244_A3_blank_valued_block`; it is this item's E question.
7. **The PDK symbols' own `hide=true` operating-point texts are hidden by the
   rung** once View > Show hidden texts is on — which is the state **both** shipped
   Op-Annotate menu bodies create one line before writing the mask (3 such texts in
   sky130 `nfet_01v8`, 2 in gf180 `nfet_03v3`, 0 in IHP). They are replaced by the
   overlay block, so nothing is lost on screen, but it is a user-visible trade the
   plan never stated. `rule` debt `1244_A3_hide_true_op_texts`.
8. **The 42 one-record `name+parameter` symbols (A2's note 10) are spared on this
   tree**, and by the gate rather than by luck: every shipped PDK descriptor is
   match-narrowed (`{*sky130_fd_pr/*}`, `{*gf180mcu_pr/*}`, `{*sg13g2_pr/*}`) and
   registers only `nmos`/`pmos` (+ IHP `vertical_npn`), so none of the 42 gets a
   devpath. **Live only for a user's own `op_annot::register`.**
9. **1249's repair is UNGATED by `annot_show`** — censused over all 44,177 `T`
   records in five libraries, **exactly 69 symbols** now draw a name they did not
   draw before, at `hide_symbols=2`, at `hide_symbols=1` on subcircuits, and on any
   `HIDE_INST` instance. Intended; no other text moves; but it is a user-visible
   change with no mask behind it.
10. **P6 pin-owned pin names survive the declutter** (issue **1253**) — they are a
    **fourth** pass, gated by `pin_name_visible()` in `draw.c` / `svgdraw.c` /
    `psprint.c`, not by `text_hidden()`. Inert on the acceptance rows (all four
    pins of each of the three PDK FETs spell `show_pinname=false`), live for the
    2,968 shipped records that spell `true`. The one-line repair is in the issue.
11. **`cadence::_annot_msg`'s `& 7` blindness was NOT closed (issue 1251), and the
    decision is written down rather than left implied.** `utils/annot_mode.tcl` is
    **item A4's** file and row V21 of `test_op_annot.tcl` golds all eight arms
    byte-for-byte. **A4 should take 1251 with 1250** — the recommended repair
    appends a clause instead of widening the switch, so V21 keeps passing on the
    `& 7` part.
12. **A2's open question (its note 4) is answered NO, in writing:** no
    `xschem text_hidden` reflection verb was added. A3 had three independent
    *behavioural* windows on the predicate that A2 lacked — the SVG and PS renders,
    `xschem instance_bbox`, and `xschem instance_at` — so rows A19–A22 corroborate
    rather than carry the proof, and widening the dispatcher for a test-only verb
    was not warranted.
13. ⚠ **Anchors: `src/actions.c` line numbers below ~1300 are stale by +69 in the
    brief, the spec and this file** (A2's `dcbb85c3` inserted 69 lines).
    `text_hidden` was `:1610` not `:1541`, the eleventh call site `:1901` not
    `:1832`, `annot_show_set` `:1475` not `:1406`, the schematic-context site
    `:6393` not `:6324`. **Spec §2.3 has been corrected.** The `draw.c` /
    `svgdraw.c` / `psprint.c` / `select.c` / `xschem.tcl` anchors were all correct
    as filed. Post-A3, `src/xschem.tcl`'s two mask writers are at **:17311** and
    **:17749**.

---

## A4 — the status line is not path-length-sensitive  ✅ **DONE (status E), 2026-09-02**

**Do.** Fix issue **1250**. `cadence::_annot_fit` (`utils/annot_mode.tcl:724`)
elides anything over 255 bytes, and the held status line embeds a scratch path,
so `test_annot_stale_0684`'s status rows go red when the path is long — and F21
flaked once at the **default** path, i.e. in an ordinary run.

**Why it is its own item and not a footnote.** T1's baseline is **zero** counted
failures, and CLAUDE.md's rule is that *a standing red is a defect, not
furniture*. This one is worse than standing: it is intermittent, so a crew that
re-runs and sees green waves it through. That is precisely how this branch has
already shipped two defects past twenty-eight passing checks.

**Also fix 1251.** `cadence::_annot_msg` builds the sentence shown after every
annotation key by switching on the mask **with the top bit masked off**, so the
status line is blind to the declutter bit: press `Ctrl-Alt-6` and the line
describes a state that is no longer the whole truth. Same file, same proc family.

**Files.** `utils/annot_mode.tcl` · `tests/headless/test_annot_stale_0684.tcl` ·
rows in `tests/headless/test_annot_declutter_1244.tcl`

**⚠ ALSO TAKE ISSUE 1251, added 2026-09-02 by item A3.** `cadence::_annot_msg`
switches on `[expr {$mask & 7}]` (`utils/annot_mode.tcl:906`), so it cannot
mention the declutter bit: **now that A3's rung has landed, mask 1 and mask 9
draw different sheets and produce the same sentence** — press `6` after a
`Ctrl-Alt-6` and the editor says "showing operating point values" about a sheet it
has just stripped every parameter from. A4 is the only item that owns the file.
The recommended repair **appends** a clause rather than widening the switch, so
row **V21** of `test_op_annot.tcl` (which golds all eight arms byte-for-byte) keeps
passing on the `& 7` part — and the appended clause counts against the same
255-byte `_annot_fit` budget this item is fixing.

**Accept.** The status rows pass at the default scratch path **and** under a
deliberately long one — drive both, do not argue from the code. Run T1 solo
**four times** and show four zeros; one green run is not evidence about an
intermittent red. Do not widen the 255-byte cap without reading issue **0886**,
where the elision was chosen.

**Landed.** The 255-byte cap is **untouched** — 0639 rejects both widening
`char statusmsg_text[256]` and shortening the path in the mint, so **1250 part 1
is fixed test-side**: the six path-sensitive rows now compose the whole expected
sentence and render **the expectation** through `cadence::_annot_fit` before
comparing (the BC5/BC5b idiom of `test_annot_blank_cause_0909.tcl`), which is
also strictly stronger than the old two-anchor `string match`. **1250 part 2 was
never a path defect**: it is a one-second `file mtime` race in
`op_annot::_db_stat`, forced on demand and fixed in row F21's own staging, with
row **F49** as its deterministic twin. **1251** is a pure minter,
`cadence::_annot_declutter_clause {mask}`, gated on **bit 3 AND bit 0** (D-8) and
appended after 0909's cause and before the state clause; `Alt-Shift-6` composes
at the **call site** because `_annot_tran_msg` takes no mask and is golded in a
file this item does not own. Suites: `test_annot_stale_0684` **52 → 54**,
`test_annot_declutter_1244` **82 → 93**; `test_op_annot` 485/492,
`test_annot_blank_cause_0909` 27, `test_annot_hier_0911` 15,
`test_results_freshness` 21, `test_annot_show_menu` 36,
`test_annot_op_behind_tran_1242` 22, all unchanged. T1 **solo ×4, four zeros**.
Full record: `doc/claude/op_param_batch/receipts/A4.md`.
Full audit `SUMMARY: 365 pass  11 fail  0 crash/timeout  2 skip  (total 378)`,
the eleven reds **identical by name** to `audit_A3_2026-09-02.txt`. Filed and not
fixed: **1255**, **1256**. **Status E** — the clause is a fourth unratified
sentence (`owed.sh` rule debt `1251`).

**⚠ THE ADVERSARY REFUTED THIS ITEM ONCE, AND THE REPAIR IS WHY THE COUNT IS 93
AND NOT 92.** A4 first shipped the clause behind a fourth condition,
`$state eq {live} || $state eq {loaded}`, on issue 0909's `canask` reasoning.
**The premise was false and was measured false**: item A3's rung is gated on
`annot_overlay_gate(n)` **and a non-blank `op_annot::text` block**, not on numbers
arriving — `src/actions.c:2075` says so in as many words — so with **no raw
loaded at all** the sheet is stripped just the same:

```
raw loaded = -1
mask 1 texts = MC1 CW=1u {cid =}
mask 9 texts = MC1 {cid =}
```

`noraw` is the most common press there is (`6` before the simulation has been
run), so the suppressed sentence was the inaccurate one. The gate was deleted,
row **S8**'s third leg inverted, row **B1** widened to sweep all eight states,
and row **E6** added to drive it end to end with no results file. Before the
repair the `state-gate-restored` sabotage reddened **nothing**; it now reds three
rows. **This repair was made by the write-up agent after Verify-C, so it has no
independent adversary pass** — the re-verification (tiers, five sabotage
variants, T1 ×4 solo, full audit) is one agent's.

---

### What A4 learned that binds later items

1. **⚠ `test_annot_declutter_1244` emits NO `RESULT:` line under `--nogui`.** It
   needs X (`bind` / `event generate`). Run it as
   `tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script …`.
   A crew that runs it headless reads silence as a pass. Its count is now **93**.
2. **⚠ A ROW THAT ONLY EVER WARMS TO A LOADED RAW CANNOT SEE A `noraw` DEFECT.**
   Every one of rows E1–E5 calls `c_press`, which does `dc_setmask 1 ; dc_fire
   <Key-6>` first. That is why an entire section agreed with a wrong gate. Any
   later item asserting annotation behaviour should carry at least one row with
   **no results file on disk at all** — and note `xschem raw clear` only
   *unloads*: the press re-reads the file from `$::netlist_dir` and lands on
   `loaded`, so a genuine `noraw` row needs its own empty directory (row E6).
3. **The declutter fires on DESCRIPTOR RESOLUTION, not on numbers arriving.** A
   registered device over a dead raw is decluttered while its block shows blank
   rows (`src/actions.c:2075`, rule debt `1244_A3_blank_valued_block`). Item A5's
   blank-block gate is the same fact from the other side — whatever A5 decides
   there, **the 1251 clause's truth condition moves with it**, and row E6 is the
   row that will notice.
4. **The 255-byte budget now has a bit-3 consumer, and it is nearly full.** Row
   A11-10 of `test_op_annot.tcl` and row V21 sweep masks **0..7 only** (verified
   by reading them), so nothing outside `test_annot_declutter_1244.tcl` row **B1**
   budgets a bit-3 sentence. Measured at an ordinary 55-byte path: with issue
   0909's cause present the clause is amputated at masks **11, 13 and 15** in
   every state and never at mask 9. Anything a later item adds to this sentence
   competes for the same bytes.
5. **Issue 1250's own recommended repair is refuted and must not be re-attempted:**
   *"assert the message against the CIW sentence, which `_annot_say` emits
   whole"*. The `6` / `Alt-6` success path never calls `_annot_say` —
   `utils/annot_mode.tcl:1569` writes the bar directly and the CIW leg emits only
   the cause + types clause. **No whole copy of the mask+state sentence exists.**
6. **Two doors, one bit.** `src/xschem.tcl:17311` and `:17749` (the stock
   `Waves > Op Annotate` menu) preserve bit 3 and emit **no status sentence at
   all** — issue **1256**, filed and not fixed. Whoever next owns `src/xschem.tcl`
   should mint the clause from `cadence::_annot_declutter_clause` when it exists,
   not spell it a second time (invariant I1).
7. **T1 is trustworthy again for the rest of this batch.** The ~1.1 % per-run
   intermittent red was `file mtime`'s one-second granularity, not the elision;
   the product half is issue **1255**, filed and unfixed, so a suite elsewhere
   that stamps and rewrites inside one second keeps the same flake shape.

---

## A5 — D-1 / D-6 conformance, and the staleness A3 left  ✅ **DONE (status E), 2026-09-02**

A3 landed the rung and measured four things it could not fix inside its own
scope. Three are conformance gaps against rulings the user has already given,
which makes them obligations rather than polish.

**A5-a — the gate must require a VALUE, not a resolving descriptor.**
A3's gate is "the `op_annot::text` block is non-blank", which is what the
overlay paints. But a registered device over a **dead raw** renders label-only
rows — `zid =`, `zgm =`, with nothing after them — and that block is non-blank,
so the device is decluttered.

⚠ **And item A4 measured that it is worse than "a dead raw".** With **no raw
loaded at all** — `xschem raw loaded` = −1, i.e. before any simulation has been
run — the sheet is still stripped:

```
mask 1  ->  MC1 CW=1u {cid =}
mask 9  ->  MC1 {cid =}
```

So a user who presses `6` then `Ctrl-Alt-6` before simulating loses `CW=1u` and
gets an empty label in exchange. That is the whole feature inverted, and it is
reachable in the first thirty seconds of using it. The user loses `W/L` and gains two empty labels:
strictly worse than before. **RULING D-6 says the declutter reaches instances
that "got OP numbers", and a label with no number did not get one.** Require at
least one row with an actual value. (Driver ruling, recorded in `LEDGER.md`;
`rule 1244_A3_blank_valued_block` stays on the user's queue for confirmation.)

**A5-b — 1253, pin names.** D-1 is explicit, in the user's own words, that pin
labels are in scope. A3's rung sits in `text_hidden()`, which gates the loop over
a symbol's `text[]` records — and **not** the fourth pass, the P6 feature that
draws a pin's name from the pin's own tokens behind `pin_name_visible()`
(`draw.c:959`, `svgdraw.c:986`, `psprint.c:1279`). So a symbol spelling
`show_pinname=true` keeps its pin names on a fully decluttered device. That is a
straight D-1 violation, in three back-ends.

**A5-c — 1252, the stale gate.** The per-instance gate is **fresh at one
`symbol_bbox()` caller and stale at the other**, so a decluttered device's
with-text bbox is correct by one path and wrong by the other. Same shape as issue
**0453**. Item B4 clicks these devices, so this must be right before B4 runs.

**A5-d — 1254, two coverage holes.** The `scheduler.c` overlay-sync line is
guarded by nothing, and row A17 is vacuous. Neither is a defect in the shipped
feature; both are places the suite stays green while the feature breaks — which
is the exact failure mode this branch has a standing rule about.

**Files.** `src/actions.c` · `src/draw.c` · `src/svgdraw.c` · `src/psprint.c` ·
`src/select.c` · `src/scheduler.c` · `tests/headless/test_annot_declutter_1244.tcl`

**Accept.** A dead-raw device keeps its parameters and is not decluttered.
`show_pinname=true` pin names vanish under declutter in all three back-ends. The
gate agrees at both `symbol_bbox()` callers — drive both, do not reason about it.
The two vacuous rows fail when the feature is sabotaged.

**Landed.** Five added code lines and one 12-line pure function, across five `.c`
files. **A5-a**: `annot_block_has_value()` — per line of the cached block, after
the first `=`, any character that is not a space or a tab — and
`annot_instance_annotated()` returns it. **A5-b**: one shared
`if(text_hidden_inst(0, n)) continue;` immediately after the `pin_name_visible()`
anchor in `draw.c`, `svgdraw.c` and `psprint.c` (issue 1253's own one-liner,
verbatim). **A5-c**: `annot_overlay_sync()` in the `recompute_inst_bbox` arm of
`scheduler()`. **A5-d**: rows A15 and A17 repaired in place and **shown failing**
under the sabotage that used to leave them green. `src/select.c` is in the Files
cell and was **deliberately not edited** — `symbol_bbox()` has no P6 pin pass, so
hiding a pin name moves no bbox.

**INVALIDATION RECEIPT (the brief's explicit question, against 0466 §S9b): A5-a
rides NO NEW HOOK.** `annot_block_has_value()` is a **pure function** of the string
`annot_overlay_cached_text()` already returns — no `tcleval`, no `tclgetvar`, no
`xschem raw value` — so the gate acquires **zero** invalidation inputs of its own
and cannot be staler than the block `get_annot_overlay()` paints. It rides the one
wholesale flush the overlay cache already performs on every epoch move (raw
pointer / level / nvars / annot_p, `annot_show`, `modify_seq`, `data_seq`,
`schhash`, `desc_gen`) plus the explicit bumps in `clear_drawing` (`src/actions.c`
— the `xschem reload` path 0466 was filed about; **0466's own text cites `:2321`
and is stale**), `set_modify`, `remove_symbols`, `save.c`'s raw vector edits,
`update_op()` and the scheduler's `raw set` arm. Measured: flushes 21 → 22 on an
`op_annot::register`, 24 → 25 on an `annotate_op`. Row **A35** asserts the purity
as *structure*. The only way to re-open 0466 here is to answer from a **second**
source; that is deliberately not done.

**Suites.** `test_annot_declutter_1244` **93 → 105** checks, ALL PASS. T1 zero,
T2 6/6, and the whole annotation + pin-name + pick families unmoved. Full audit
`SUMMARY: 365 pass  11 fail  0 crash/timeout  2 skip  (total 378)`, diffed **by
name and status** against `audit_A4_2026-09-02.txt`: **empty**, 385 sorted verdict
lines each side. Sabotage: six variants, every predicted red observed;
`SB7b` → **A15** (it reddened nothing before) and `SB-GATE-ALWAYS` → **A17** (it
left A17 green before) are the two 1254 deliverables, shown failing both ways.
Issues **1252**, **1253**, **1254** closed. Filed and not fixed: **1257**,
**1258**, **1259**, **1260**, **1261**. **Status E** — see below.

---

### What A5 learned that binds later items

1. **⚠ ITEM B4 MUST STILL REFRESH THE BBOXES, AND FOR A SHARPER REASON THAN 1252
   (issue 1260).** A5-c fixed the `recompute_inst_bbox` door, but **`xschem setprop
   instance` and `xschem move_instance … nodraw` still write the click box from a
   stale gate** — measured, with the frame on screen showing the text while
   `instance_at 430 -245` answers empty over it. **A5-a widened the first of
   those**: before A5-a a label-only block still opened the gate, so a rename over
   a dead raw flipped nothing; now an ordinary property edit is enough. B4 calls
   `xschem update_all_sym_bboxes` before its first pick **and carries a row that
   reds if it does not**.
2. **⚠ "The gate agrees at both `symbol_bbox()` callers" is true of the
   overlay-cache half only.** The **mask** half is deliberately not synced at
   `recompute_inst_bbox` (`annot_show_sync_cache()` ends in the 0688 backstop,
   which can *clear* the mask, in a verb documented as not redrawing). Measured
   with a bare `set ::annot_show`: the two doors answer **opposite** picks. Latent
   — shipped code always writes through `xschem set annot_show` — but do not quote
   the accept sentence as more than it is. Issue **1260** part 3.
3. **⚠ ITEM A6 INHERITS A5-a's CONSEQUENCE (issue 1257).** With no results file
   `Ctrl-Alt-6` now hides **nothing**, and `cadence::_annot_declutter_clause` is
   still gated on bit 3 AND bit 0 only, so the held line still says other device
   text is hidden. Row **E6** golds the gap on purpose. A6 owns `src/xschem.tcl`
   and not `utils/annot_mode.tcl`, so whoever takes 1257 must be given that file.
4. **⚠ ITEM B1 INHERITS THE ABSENT-vs-ZERO HALF (issue 1259).** A raw publishing
   `0.0` renders `zid = 0` and **opens** A5-a's gate. B1's own rule — *"a
   zero-length or `dims=0` vector is **absent**, not zero"* — is exactly the
   distinction the block string does not carry, and `savecurrents` publishing
   sky130 `ig`/`is`/`ib` as 0 makes it a real PDK case, not a fixture artefact.
5. **⚠ TWO SUITE READERS PUNISH COMMENT PROSE IN `draw.c` / `svgdraw.c` /
   `psprint.c`.** Row **A22** of the declutter suite (`opa_n_grep`) counts comment
   lines, so `text_hidden_inst(` written in prose inflates its census; and row
   **L27** of `test_op_annot.tcl` asserts the literal `HIDE_TEXT` survives in
   exactly **one** `.c` file. Both reddened A5's first draft — L27 took T1 with it.
   Reword; do not widen either reader.
6. **⚠ `draw.c` HAS A BEHAVIOURAL SEAM AFTER ALL (issue 1261).** A5 believed the
   screen leg was structural-only because `draw()`'s body is inside `if(has_x)`.
   `print_image()` calls `draw()`, so a warm-then-real `xschem print png` pair at a
   **tight** viewport measures a pin name going away: **12912 → 8301** bytes, with
   an **8744 / 8744** `show_pinname=false` control. At the suite's usual wide
   viewport the name is zoom-culled at both masks and the PNGs are byte-identical —
   which is how it was missed. `draw.c`'s leg of 1253 is guarded by a grep census
   today; the row and its sabotage are specified in 1261 for whoever may rebuild.
7. **The A5-a gate is a PURE FUNCTION on purpose, and that is not decoration.**
   Any later "improvement" that asks `::op_annot::_annotated`, `xschem raw value`
   or a fresh `tcleval` from inside the gate re-opens issue **0466**. Row A35 reds
   if you do.
8. **⚠ ORDER IS LOAD-BEARING when measuring a stale cache.** Any sync — a draw, an
   export, `update_all_sym_bboxes` — repairs it, after which the two doors agree.
   The stale reading must be taken **first**; two attempts at the A5-c measurement
   were lost to exactly this.

---

## ⚠ FEATURE A CLOSES AT A7. A DRIVER BOUNDARY, SET 2026-09-02.

Feature A is six landed items and **sixteen filed issues** (1246-1261). Every one
was measured and several were real defects — a D-1 violation, an intermittent T1
red, and a feature that inverted itself before you had simulated. The crews did
exactly what they should. But three consecutive items have now each produced
residue from the item before, and that recursion has to be bounded by a decision
rather than by exhaustion.

**A6 and A7 close feature A.** Anything found after A7 is **filed and deferred to
a later batch** — not spawned as another item. Feature B has not started, and it
is the half the user actually asked for first.

**⚠ STATUS, 2026-09-03: the boundary HOLDS but neither closing item has landed.**
A6 is `[F]` (destroyed by its own write-up agent) and A7 is `[F]` (refuted by its
own adversary and reverted). Both are preserved as patches in this directory and
both re-apply cleanly to `355a3dc6`. Feature A's *design* is closed; its last two
items are re-runs, not new work, and A7's re-run is **four lines** of correction on
top of its own patch (issue **1270**). Anything found after A7 is still filed and
deferred — A7 filed 1270 and grew nothing.

---

## A6 — close the value gate and the last bbox doors  ⛔ **NOT LANDED (status F), 2026-09-02 — implemented and verified, then DESTROYED BY ITS OWN WRITE-UP AGENT. Re-run it; the work is preserved.**  *(needs A5)*

Three pieces of correctness residue in what A5 just built. All C.

**A6-a — 1258, the value gate accepts a descriptor label containing `=`.** The
gate decides "did this row get a number" by looking for a value after the label;
a label that itself contains an `=` fools it. A gate that can be fooled by data
is not a gate.

**A6-b — 1259, the value gate accepts a published zero.** So a `savecurrents`
run still declutters. ⚠ This is the trap the batch's own measurements recorded
twice before it was written: `.options savecurrents` publishes a sky130 FET's
`ig`/`is`/`ib` as **zero-length** vectors, and an explicit `save …[ib]` card
yields a **`dims=0`** column of `0.0`. Both are **absent**, and neither says so on
stderr. See `doc/claude/code_analysis/1244_op_param_list_measurements.md` §22 and
the spec's landmine 11. Absent is not zero, and a real measured 0.0 is not absent
— distinguish them, do not pick whichever is easier.

**A6-c — 1260, 1252's residue.** Two *more* `symbol_bbox()` doors, plus the mask
half of the gate. A5 measured the live case itself: after
`setprop instance M1 name MZ1` the render shows `MZ1 VCW=1u PD {zid =} {zgm =}`
while the stored bbox is unchanged and `instance_at` disagrees with what is
drawn. **Item B4 clicks these devices.** This is the last chance to make every
door agree before something depends on it.

**Files.** `src/actions.c` · `src/draw.c` · `src/svgdraw.c` · `src/psprint.c` ·
`src/select.c` · `tests/headless/test_annot_declutter_1244.tcl`

**Accept.** A label containing `=` does not satisfy the gate. A published zero
does not, and an absent vector does not, and a genuinely measured `0.0` **does**
— three rows, not one. Every `symbol_bbox()` door agrees after a rename, drive
each. `instance_at` and the render agree on the same fixture.

---

### ⛔ WHAT HAPPENED TO A6, AND WHAT THE NEXT CREW MUST DO FIRST

**A6 was implemented, built, and passed every verification pass. Then the
write-up agent ran `git checkout -- src/save.c` to undo a one-paragraph comment
edit and destroyed A6-b's entire implementation in that file** — ~99 uncommitted
lines, never staged, unrecoverable from `git fsck` (nine dangling blobs, none of
them it). **Nothing else was touched.** The step is **F** for that reason and
that reason only.

**The work is NOT lost.** Two durable copies exist in this commit:

1. `doc/claude/op_param_batch/A6_working_tree_UNVERIFIED.patch` — the complete
   working-tree diff, all eight files, 1072 lines.
2. The working tree itself, left in place and **not** reverted.

**Seven of the eight files in that patch are BYTE-IDENTICAL to what Verify-A,
Verify-B and Verify-C measured** — `src/actions.c`, `src/select.c`,
`src/xschem.h`, `src/scheduler.c`, `src/ase.tcl`, `src/wave_viewer.tcl` and
`tests/headless/test_annot_declutter_1244.tcl` (120 checks, ALL PASS, re-run by
the write-up agent). **`src/save.c` is a hand RECONSTRUCTION** from a verbatim
capture of 88 of its ~97 changed lines plus one 8-line hunk (the
`raw_deletevar()` `dims0` shift) rewritten from its description. It has **never
been compiled**: the write-up agent is forbidden to build and was denied the
attempt. One independent landmark does check out — the reconstruction lands
`extra_rawfile()`'s `what == 4` printer at **exactly line 2475**, the line the
implement pass's restated `save.c:2475-2488` citation was verified against — but
that is a consistency check, not a compile.

**FIRST ACTION FOR WHOEVER PICKS THIS UP, in order.** Do **not** re-derive the
design; it is all recorded in issues 1258 / 1259 / 1260 and below.

1. `cd src && make`. If `src/save.c` does not build, fix it against issue 1259's
   "What changed" section, which names every hunk and every guard.
2. Re-run `tests/headless/test_annot_declutter_1244.tcl` — expect **120 checks,
   ALL PASS**. Rows **A45 A46 A47 A48** are precisely the ones that exercise the
   reconstructed file.
3. Re-run the raw-reader family, which exercises `read_dataset()` and
   `raw_deletevar()`: `test_raw_read_dispatch` (137), `test_raw_read_failure_0306`
   (63), `test_zero_point_raw_0836` (74), `test_backannotate_digital` (84),
   `test_spice_get_node_0861` (23), `test_results_select` (377).
4. Full audit, diffed **by name and status** against
   `doc/claude/op_param_batch/audit_A6_2026-09-02.txt` (committed here):
   **364 pass / 12 fail / 0 crash / 2 skip of 378**, twelve names listed below.
5. Then commit, and the step is **E**, not `x` — see "the two things that keep
   A6 off `x` even when it builds".

**⚠ THE BASELINE OF RECORD MOVED and it is not A6's doing.** The brief said
365/11; the Measure agent measured **364 pass / 12 fail / 0 crash / 2 skip of
378** and Verify-A reproduced it byte-identically. The one addition is
`test_wave_sigbrowser_i12` check **BX42**, deterministic on the persistent `:99`
display with openbox live and **PASS on a WM-less private Xvfb** — window-manager
dependent, no part of A6's subject. The Measure agent's two candidate causes were
"A5's binary introduced it" and "accumulated openbox state"; Verify-A then found
the dev display had been **restarted** (Xvfb pid 28419, not the 25524 the Measure
agent recorded) and BX42 still failed, which weakens the accumulated-state
hypothesis. **A5 committed no audit transcript**, so its "365/11, re-measured
identical" is unverified. Twelve names: `test_altf5_ciw`, `test_ase_core`,
`test_ase_window`, `test_cadence_drag`, `test_cosim_golden_e2e`,
`test_lib_manager_gui`, `test_lib_sweep`, `test_rotate_stretch_short_0104`,
`test_selflog_output`, `test_wave_sigbrowser_0312`, `test_wave_sigbrowser_i12`,
`test_wave_sigbrowser_keys`. Skips unchanged: `test_expose_repaint`,
`test_window_report`.

### The two things that keep A6 off `x` even when it builds

1. **⚠ A6-b IS A PARTIAL CLOSE OF 1259, and the adversary pass refuted its
   headline.** `dims=0` is the detector for the `.control` + `write` flavour
   **only**. On **xschem's own shipped simulate command** —
   `ngspice -b -r "$n.raw" "$N"`, `src/xschem.tcl:3854` — an unsatisfiable
   `.save` card, *including everything `.options savecurrents` adds for a FET's*
   `ig`/`is`/`ib`, is written as an **ordinary `current` column of 0.0 with no
   `dims=0` token at all**. Re-measured independently by the write-up agent,
   ngspice 45.2, BSIM4:

   ```
           5       i(@m1[is])      current
           6       i(@m1[ig])      current
           7       i(@m1[ib])      current
   $ grep -ac 'dims=' sc.raw
   0
   $ head -1 sc.err
   Warning: unrecognized variable - @m1[is]
   PT0 i(@m1[id]) = 0.00031215789
   PT0 i(@m1[ib]) = 0
   ```

   **So on that path a `savecurrents` run still declutters** — the literal title
   of issue 1259. Filed as **1263**. The ACCEPT row's third absent state,
   *zero-length*, is unhandled for a related reason (**1264**): a genuinely
   zero-length vector makes `write` refuse the whole plot and produce **no raw at
   all**, so it never reaches xschem as a zero-length vector.
2. **The user-visible change is unratified.** A parameter that used to print `0`
   now prints **blank**. The question is in the receipt and belongs on
   `owed.sh add rule`.

---

### What A6 learned that binds later items

1. **⚠ ITEM B1 INHERITS MORE OF 1259 THAN A5 THOUGHT, and it inherits a SEAM
   rather than a blank slate.** A5's lesson 4 said B1 inherits the absent-vs-zero
   half. It now inherits: the `dims=0` flavour **closed** behind one exported
   predicate `raw_vector_absent()` (`src/save.c`, prototype in `src/xschem.h`),
   and **1263** + **1264** open. **Widen that one predicate; do not build a second
   detector** — invariant I1, and two independent answers to one question is how
   1252 became 1260. The only remaining carrier for 1263 is the simulator's
   **stderr** (`Warning: unrecognized variable - <name>`), which must be captured
   at simulate time and carried beside the raw — asking for it from inside the
   gate re-opens issue **0466** and reds row A35.
2. **⚠ ITEM B4 STILL MUST REFRESH THE BBOXES — the instruction survives A6
   intact, for a NEW reason (issue 1266).** A6-c made all **39** `symbol_bbox()`
   callers fresh by syncing inside the callee, which closes 1252/1260 completely.
   But `xschem annotate_op` and `xschem raw clear` change the gate's answer while
   calling `symbol_bbox()` **not at all**, so the stored click box and the render
   disagree until something triggers a bbox pass. Driven both directions:
   after `annotate_op`, `instance_at 430 -245` answers `M1` **over blank canvas**;
   after `raw clear`, a click **on the visible text** answers **nothing**. The
   shipped chord paths call `update_all_sym_bboxes` and are safe;
   `op_annot::db_attach`'s own return path, ASE flows and a user typing the verb
   are not. **B4 calls `xschem update_all_sym_bboxes` before its first pick and
   carries a row that reds if it does not.**
3. **⚠ ISSUE 1252's RECORDED REASONING IS NOW WRONG IN THE TREE, deliberately.**
   A6-c put the sync inside `symbol_bbox()` — the option 1252 rejected. Both of
   1252's reasons were answered, not ignored: re-entrancy is already closed by
   `annot_overlay_busy` (set around exactly the `tcleval` that re-enters), and
   cost by the bit-3 prefilter, which makes the sync a **no-op whenever the
   declutter is unarmed** — every load, every netlist pass, every other suite, all
   378 audit cases. Measured flush delta **0**. 1252's issue file has been
   updated; do not "restore" the rejection.
4. **⚠ A SUITE ROW'S GOLDEN WAS MOVED, NOT ITS READER.** Row **A41**'s fifth
   golden went `select.c` **0 → 1** with the argument written beside it. That is
   the third time this suite has had a golden edited; the rule that made it legal
   is that the **regexp was not widened**. Widening the reader so the count does
   not move is the failure filed as 1248 and 1254. Keep the distinction.
5. **⚠ `annot_show_sync_cache()` IS NOW A SPLIT.** It is
   `annot_show_pull_cache()` (the `annot_show` + `annot_voltage_layer` pull) plus
   `annot_show_check_root()` (the 0688 backstop). Anything that needs the mask
   mirror fresh on a **read-only** path calls the pull; anything that is a real
   entry point calls the whole thing. The backstop can `annot_show_set(0)`, and a
   verb that computes geometry must not be able to disarm the annotation.
   `annot_show_check_root()`'s tree-wide census stays **3** (`test_op_annot` Y11).
6. **⚠ TWO SUITE COUNTS ARE ARM-DEPENDENT, NOT CHANGE-DEPENDENT.** `test_op_annot`
   is **485 under `--nogui`** and **492 under Tk**; `test_deselect_mode` is **9**
   and **18**. Both files were unmodified throughout. A crew that measures a
   baseline headless and re-measures under Tk will report a phantom regression.
   **Say which arm every count was taken on.**
7. **⚠ `test_raw_read_dispatch` HANGS under a display.** It is on
   `full_audit.sh`'s `nogui_tests` list and stalls at check SC06 with Tk live.
   Run it `--nogui`.
8. **⚠ EDITING `src/save.c` MOVES A CITATION UNDER A RESOLVE-CHECK.** Rows
   **SEL468 / SEL469** of `test_results_select.tcl` resolve two `.tcl` comments
   that cite `extra_rawfile()`'s `what == 4` printer by line number. Inserting
   anything above it reds the suite — **by design**; the check's own prose tells
   you to re-grep and restate. About a dozen such `save.c:NNNN` citations exist in
   `.tcl` comments and **only those two are under a check**; several are already
   rotted by up to 1874 lines (`src/op_annot.tcl:385`). Filed as **1268**.
9. **⚠ THREE COVERAGE HOLES IN A6's OWN SUITE (issue 1267).** The `dims=0`
   **parse** is guarded by row **A45 alone** (A48's structural legs do not move
   when the parser is dead). The defence of the numbered-point data-inspection
   read is **one list element of A48**, and neither `test_raw_read_dispatch` (137
   checks) nor `test_spice_get_node_0861`'s SGN13/14/22 notices when it breaks.
   And the hazard the pull/backstop split exists to prevent has **no behavioural
   coverage at all** — `test_op_annot` Y11 is a *census* and cannot see a new
   **transitive** caller. Close hole 3 with a row that warms the mask, **swaps the
   root sheet**, then calls `recompute_inst_bbox` and asserts the mask survives.
10. **⚠ THE ABSENCE RULE REACHED ONE OF THREE READERS of `raw->cursor_b_val[]`
    (issue 1265).** `xschem raw value <v> -1` blanks a `dims=0` column;
    `src/token.c`'s six `@spice_get_*` branches and `ngspice::ngspice_data` still
    publish the fabricated `0`. `ngspice::get_current` is used by **five shipped
    library schematics**, so the split is reachable on a stock sheet.
11. **⚠ `raw_deletevar()` SHIFTS `names[]` AND `values[]` AND NOT `cursor_b_val[]`
    (issue 1262).** Pre-existing. After `xschem raw del`, every column from the
    deleted index on reports its neighbour's OP number. Found only because A6-b
    had to decide what to do with the array beside it.
12. **⚠ NEVER `git checkout -- <file>` TO UNDO AN EDIT IN A CREW RUN.** It
    discards *every* uncommitted change in that file, not the last one, and an
    unstaged change leaves no blob for `git fsck` to find. Undo an edit with the
    inverse edit. This paragraph exists because that command cost this batch a
    verified implementation.

---

## A7 — the wording follows the gate, and the guards stop lying  ✅ **DONE, 2026-09-03. FEATURE A IS CLOSED.**

> The crew reached `[F]` honestly: its own adversary refuted the central
> mechanism (issue **1270** — the declutter counter counted the *rung*, not what
> came off the sheet), and it reverted rather than ship a suite that was green
> over a live lie. Nothing was lost — every line was preserved as
> `A7_working_tree_REFUTED.patch`, dry-run-applied to a pristine extraction
> before the revert. The driver re-did it from that patch plus a four-line repair
> at A7's own edit point and two new rows, **A64/A65**, both proved by sabotage
> rather than asserted. Issues **1255, 1256, 1257, 1261** are closed; **1270** is
> fixed and carries the residual risks that survive it.
>
> **Next: B1-B5, the Results Display Window** — the half the user described first
> and at greater length, still unstarted.

**A7-a — 1257, the status clause claims a declutter that no longer happens.**
With no results file, `Ctrl-Alt-6` now correctly hides nothing — but the held
line still says other device text is hidden. **Driver ruling: the clause follows
the gate.** Item A1 already minted the right sentence for this exact state
(*"Decluttering is on, but nothing changes yet: it applies only while
operating-point values are showing. Press 6 to show them."*), so this is a
consistency fix, not a new product decision, and the press is **not** refused —
the user asked for a mode, and a mode you cannot arm before simulating would be
worse than one that tells you it is waiting.

**A7-b — 1256**, the stock `Waves > Op Annotate` menu is silent about the
declutter, so the menu and the keys describe the same state differently.

**A7-c — 1255**, `db stat` mtime granularity is one second, so a staleness
**guard** cannot tell a raw rewritten inside the same second. It fails in the
safe-looking direction: it says "fresh" when it does not know.

**A7-d — 1261**, `draw.c`'s leg of 1253 is guarded by **source text** rather than
by behaviour — and `print png` is a real window onto that path, so the guard can
be green while the back-end is wrong.

**Files.** `utils/annot_mode.tcl` · `src/xschem.tcl` · `src/op_annot.tcl` ·
`tests/headless/test_annot_declutter_1244.tcl` · `tests/headless/test_op_annot.tcl`

**Accept.** The clause is absent when nothing was hidden and present when
something was — drive both. The menu and every chord emit the same clause for
the same state; drive both doors, do not compare source. A raw rewritten inside
one second is detected as changed. 1261's guard fails when the back-end is
sabotaged, driven through `print png` rather than read out of the source.

### ⛔ WHAT HAPPENED TO A7, AND WHAT THE NEXT CREW MUST DO FIRST

**A7 was implemented, built, and passed T1/T2/T3 and the full audit with the
twelve-name baseline reproduced exactly. Its adversary pass then found that the
central mechanism answers the wrong question, and the item was reverted.** The
refutation is **issue 1270**; read it before touching anything here.

**1. THE BINARY IS AHEAD OF THE TREE RIGHT NOW.** `src/xschem` (2026-09-03
02:03:58) carries A7's C change; the reverted sources do not. The write-up agent
could not rebuild (crew rule 2). The revert leaves every source **newer** than
the binary, so `make -q` reports out of date — but this is batch trap 1 and it is
armed. **Rebuild first**, then check
`strings src/xschem | grep -c annot_declutter_count`: **0** on the reverted tree,
**2** once the patch below is re-applied.

**2. THE WORK IS PRESERVED AND RE-APPLIES CLEANLY.**
`doc/claude/op_param_batch/A7_working_tree_REFUTED.patch` — 1802 lines, md5
`fe5571930f02cdaa3f816b1e3b3ab871`, dry-run-verified against a pristine
`git archive` extraction of all eight files at `355a3dc6` **before** anything was
reverted. `patch -p1 <` it and the whole item is back: the C seam, the three Tcl
producers, the stock menu helper, the bounded-window stamp, and **14 new suite
rows** (`test_annot_declutter_1244` 120 → 132, `test_annot_stale_0684` 54 → 56,
both ALL PASS). Nothing needs re-deriving.

**3. THE FIX IS FOUR LINES, INSIDE A7's OWN EDIT POINT.** `++annot_declutter_count`
sits at `text_hidden_core()`'s rung `return 1`, which is **above** the
`show_hidden_texts` / `HIDE_TEXT` / `HIDE_TEXT_INSTANTIATED` arms — so it counts
*"the rung said hide first"*, not *"this text would otherwise have been drawn"*.
Bump it only when the tail below would have returned 0. The exact replacement is
in issue 1270, and the `show_hidden_texts` arm of it is load-bearing in the
direction people will forget: both Op-Annotate menu bodies turn that switch **on**
one line before writing the mask, so there the rung really does take the text
away and the counter **must** bump.

**4. THE ROW THAT WOULD HAVE CAUGHT IT, AND MUST BE ADDED.** A fixture whose only
non-`@name` text carries `hide=instance` — the shape of **57 shipped
`xschem_library/devices/*.sym`** — with a valued raw: the sheet identical at mask
1 and mask 9 (assert the SVG bytes equal), **no** clause from `6`, **DC_ARM** from
`Ctrl-Alt-6`, **silence** from both menu doors; plus its twin with
`show_hidden_texts` on, where all four must speak. Driven, this is what the
shipped binary does today:

```
   mask1 texts=MP {aid = 12.3u}
   mask9 texts=MP {aid = 12.3u}
   SVG BYTES IDENTICAL: YES
   chord 6 -> mask 9, clause PRESENT   (A7 requires: absent)
```

### What A7 learned that binds later items

1. **⚠ THE DECLUTTER HAS FOUR STATES, NOT THREE.** The driver's brief said
   *"three states, three sentences — hid something / armed but nothing to hide /
   not armed"*. Measured, there are four: **no raw** (`raw loaded` -1), **dead raw**
   (loads and annotates, publishes no matching vector), **valued raw**, and
   **valued raw whose text was already invisible**. The dead-raw state is the one
   that forces a C seam — `op_annot::_annotated` answers 1 and
   `cadence::annot_mode`'s `state` reads `live` there, identically to a valued raw,
   so **every Tcl-only repair fixes the no-raw state and goes on lying**. Any
   later item that wants to know "is this sheet decluttered" must ask a
   measurement, not the mask and not `_annotated`.

2. **⚠ A7's Files cell was wrong and the next one may be too.** It named no `.c`
   file; the honest fix needs `src/actions.c`, `src/xschem.h` and
   `src/scheduler.c`. That overrun was correct and is not the reason A7 failed.
   Row **L27** of `test_op_annot.tcl` is the trap it navigates: the literal
   `HIDE_TEXT` must appear in exactly ONE `.c` and `text_hidden` in exactly five,
   counted by `string first` over the **whole file including comments** — so a new
   accessor, *or even a comment*, in `scheduler.c` naming either token reds L27 and
   takes T1 with it. A7's arm named neither and `grep -c 'text_hidden\|HIDE_TEXT'
   src/scheduler.c` stayed 0. Keep it that way.

3. **⚠ ROW A62's SHAPE IS A TRAP FOR EVERY MENU-DOOR ROW, INCLUDING B-FEATURE
   ONES (issue 1270).** A driver that does `catch {$menu invoke $idx}` cannot see a
   raise, and `xschem set annot_show` runs **early** in the `-command` body — so the
   mask is already merged and a planted sentinel already untouched when the raise
   happens, and every "the door ran and said nothing" leg still passes. A7's own
   sabotage proved this on a coarse twin that provably raises. **A menu-door row
   needs a leg asserting the invoke did not raise, or a bgerror count.**

4. **The `Waves > Op Annotate` door is unreachable under the cadence profile.**
   `src/cadence_style_rc:40` sets `cadence_compat 1`, and `waves_gate_blocked` is
   the left term of that entry's guard, so it refuses and pops a **blocking**
   `alert_` (`tkwait window .alert`) — in the one profile where the clause producer
   exists. The door that can speak under cadence is **Graphs**. Any row touching
   Waves needs the `alert_`, `ase::annot_binding_ok` and `select_raw` stubs, and
   must toggle `::cadence_compat` explicitly. This bites **B4**.

5. **`xschem print png` is a real behavioural window onto `draw()`** — A7-d proved
   it, and proved a grep census cannot see `if(0 && text_hidden_inst(0, n))` while
   the PNG row can. But it is **display-arm only**: under `--nogui` `print png`
   writes no file, silently, rc 0. Any later back-end row must carry `> 0` and
   PNG-magic legs or it passes vacuously. Assert **relations**, never absolute byte
   sizes — they are cairo/libpng/display dependent and A7's differ from issue
   1261's by ~3 KB.

6. **A bounded content fingerprint on the staleness stamp is affordable and a
   full-file one is not.** Head 4096 + tail 4096 measures 3.7–5.0 µs across a
   276 B and a 1.2 MB raw; a full-file `zlib crc32` measures **258 µs** and reds
   row F35's `big <= 3*small + 100` budget leg; `exec stat -c %.9Y` measures
   1460–1772 µs, reds two more legs, forks per press and is GNU-only. The residue
   — 82 % of a 45 KB raw is blind, 99.3 % of a 1.2 MB one — is measured in issue
   1255 and must be stated, not glossed. **B1 inherits this** if it touches
   `db_current`.

7. **The baseline of record is still the TWELVE names in
   `audit_A6_2026-09-03.txt`.** A7's audit reproduced them verdict-for-verdict
   (a 378-line diff came back **empty**). Note `test_ase_core`'s C11 red is caused
   by a **gitignored** `untitled~.sch` in the repo root that
   `test_backannotate_digital` rewrites; deleting it would turn that suite green
   and shrink the baseline to eleven **with no code change** — a phantom fix. It is
   deliberately left in place. Also: `test_raw_read_dispatch` is `--nogui`-only
   (137 checks in 1.1 s; on `:99` it had emitted 94 ok lines at a 500 s timeout).

8. **The brief's issue-numbering block is stale and self-contradictory** ("from
   0619 upward", "hard ceiling 0499"). `doc/claude/issues/NUMBERING.md` is the only
   authority; after A7 the next free number is **1271**.

---

## B1 — the backend seam  ✅ **DONE, 2026-09-03 (driver re-do after an [F])**  *(no dependencies)*

> **⚠ FROM A6 (2026-09-02).** B1's rule *"a zero-length or `dims=0` vector is
> **absent**, not zero"* is **half answered already**, behind ONE exported
> predicate: `raw_vector_absent()` (`src/save.c`, prototype `src/xschem.h`), fed
> by `raw_line_dims_zero()` and `Raw.dims0`. **Widen that predicate; do not build
> a second detector** (invariant I1). Still open and inherited: **1263** — on
> `ngspice -b -r`, which is what `src/xschem.tcl:3854` runs, an unsatisfiable
> `.save` card arrives as an ordinary `current` column of 0.0 with **no `dims=0`
> token**, so the only carrier is the simulator's **stderr** and it must be
> captured at simulate time, never asked for from inside the gate (issue 0466,
> row A35). Also **1264** (a zero-length vector destroys the raw entirely) and
> **1265** (the rule reached one of three readers of `cursor_b_val[]`).
> ✅ **A6 DID land after all** — the crew returned `[F]` because it had destroyed
> its own unstaged work and was then blocked from building, but the driver built
> the reconstruction, ran the suite and committed it as **`c8bb41f9`**. So
> `raw_vector_absent()` is **in the tree now**; read it there, not from
> `A6_working_tree_UNVERIFIED.patch`.

**Do.** `ase::backend::ngspice::op_param_set <devpath>` → ordered `{param value}`
pairs, read **from the run's own raw**, plus a capability answer saying whether
the backend can enumerate. Pure Tcl, no UI, no deck change.

**⚠ D-4 and D-5 are the whole item.** No `show` parse, no catalogue, no
probe-and-prune. A zero-length or `dims=0` vector is **absent**, not zero. The
seam exists so the user's custom ngspice can supply a wildcard later without
anything above it changing.

**⚠ FEATURE A NOW DEPENDS ON THAT ABSENT-vs-ZERO DISTINCTION — issue 1259.** Item
A5-a's declutter gate asks whether a rendered block row carries anything after the
`=`, and a raw publishing `0.0` renders `zid = 0` and **opens** it — so a
`savecurrents` run (sky130 `ig`/`is`/`ib` published as 0; `save [ib]` giving a
`dims=0` column of `0.0`) declutters a sheet whose whole annotation is zeros. The
block string cannot carry the distinction and must not be re-derived from a second
source (issue 0466). If `op_param_set` publishes absence as a first-class answer,
say so in 1259 so the gate can read it.

**Files.** `src/ase.tcl` · new `tests/headless/test_rdw_seam_1245.tcl`

**Accept.** Against a **fabricated raw** (no ngspice needed): a device with six
saved params returns six pairs in order; an unknown device returns empty, not an
error; a `dims=0` column is omitted; the capability answer is honest. Plus the
multi-primitive case of D-3 — one `XR1` resolving to its several primitives.

---

### ⚠ B1 RETURNED **[F]**, AND THE RE-DO COST THREE EDITS AND TWELVE ROWS

**⚠ THIS SECTION IS HISTORY NOW. The seam IS in the tree.** It was refuted,
reverted, and re-done by the driver on the same day, exactly as A7 was: apply
the crew's preserved patch, fix the two named blockers, prove the fixes with
rows that red without them. **37 → 49 checks, ALL PASS.** What follows is kept
because every later item reads the seam, and the two blockers are the two ways
to get it wrong again.

**The crew was right to return `[F]`.** Its own adversary refuted the central
read, it reproduced the attack first-hand before deciding, it reverted by
reverse-applying its diff rather than with `git checkout --`, and it preserved
275 lines of `src/ase.tcl` plus a 908-line suite as
`doc/claude/op_param_batch/B1_working_tree_REFUTED.patch`, dry-run-verified to
apply to `9f1d9153`. Nothing was lost and nothing was retyped. Full record:
`doc/claude/op_param_batch/receipts/B1.md`; the defect is **1272**.

**Why it was refuted, in one line.** It read values through
`op_annot::raw_or_blank` and did **not** pass them through `op_annot::_finite`,
so a **binary** raw carrying a NaN — which is what a real `write` produces, and
`src/save.c` records that *ngspice-46 on this box* emits all four non-finite
spellings — comes back as `devices {@m.x1.m1 {{id nan} …}}`: `nan` in the
**value** bucket of a seam whose own contract says `absent` carries the columns
the simulator did not compute. B3 rendering that puts **`id = nan`** on a
schematic, which is verbatim what invariant **I3** forbids.

**The suite was green at 37/37 with that live**, because it had no non-finite
row. That is A7's lesson wearing a new costume: not a measurement taken at the
wrong seam, but a fence built around every question its author had thought of.

#### The two blockers, and how each was actually fixed

1. **The non-finite. FIXED IN THE ACCESSOR, NOT IN THE CALLER — issue 1272,
   option 1.** `op_annot::raw_or_blank` gated on `string is double -strict`,
   which **accepts `nan` and `inf`**, and the only thing rejecting them was a
   *second, separate* `op_annot::_finite` call that all five existing consumers
   happened to make. Fixing it at B1's caller would have left correctness a
   property of whether the next author read those five sites. So the three
   outcomes now live in one new accessor, **`op_annot::raw_class`** → `{absent |
   nonfinite | value} <text>`, and `raw_or_blank` is one line on top of it:
   every present and future consumer is correct by default, and the seam that
   needs the third outcome has one place to get it.
   **The non-finite got its own bucket, not `absent`.** Both render blank today,
   so folding them was tempting and is wrong: *"the raw does not carry `id`"* and
   *"the raw carries `id` and the simulator produced NaN"* are different facts,
   and the second — a device that did not converge — is the one a designer most
   wants to be told about. It is a result, not a gap.
   **The fixture had to be BINARY**, and that is the whole reason the defect
   shipped green: an ascii raw flattens `nan`→`0`, `inf`→`0`,
   `1e999`→`1.0000001e+38` in `my_atof()`'s continuation path, so an ascii
   version of every row below passes against the defect. Row **NF0** exists only
   to prove the fixture really carries a non-finite, so the five rows after it
   cannot pass vacuously.
2. **The one-character-segment over-strip. FIXED BY GATING THE STRIP ON `@`.**
   `ase::op_dev_norm` dropped **any** leading one-char segment, so `norm(a.b.c)`
   = `b.c` and a request whose first segment is a one-character subcircuit
   instance silently returned `state ok, devices {}` — byte-identical to
   "unknown device", which is a wrong answer wearing a healthy state.
   The repair is one condition: **strip the element letter only when the string
   was `@`-prefixed.** That works because the element letter only ever arrives in
   ngspice's own spelling, which is always `@`-prefixed — `ase::op_param_split`
   takes the device from its `@` to the end, and every real request producer
   (gf180's literal `{\@m.@path@spiceprefix@name\.m0}`, sky130's devproc) is
   `@`-prefixed too. A bare `a.b.c` is not raw spelling and keeps every segment.
   *Rejected: trying both readings.* It never loses a match, but request `a.b`
   would then also collect every device under `b`. Silent over-collection for
   silent under-collection is not a trade.
   *Cost, stated:* a caller writing raw spelling **without** the `@`
   (`m.x1.m1`) no longer matches. No producer in this tree does that.

#### What the re-do added, and what proves it

Twelve rows, in two new sections, all of which red without their fix:

| section | rows | sabotage verdict |
|---|---|---|
| **NF** — the non-finite, on a **binary** fixture | NF0 … NF7 | remove the finite gate from `raw_class` → **NF1 NF2 NF5 NF6 NF7 red**, nothing else |
| **DN** — the one-character segment | DN1 … DN4 | restore the unconditional strip → **DN1 DN3 red**, nothing else |
| the bucket choice itself | NF6 | route the non-finite into `absent` → **NF6 red**, nothing else |

Row **I3** (the structural "one value accessor" fence) named `raw_or_blank` and
**caught the repair that fixed its own item** — it was re-aimed at `raw_class`,
which is the fence working, not the fence being wrong. What it protects is
unchanged: `op_param_set` reads through ONE published accessor and calls
`xschem raw value` nowhere itself.

**Feature A did not move**, which is issue 1272's acceptance row 5 and the
thing most at risk from changing a shared accessor: `test_op_annot` 485 ALL
PASS, `test_annot_declutter_1244` **134 ALL PASS** on the dev display,
`test_annot_stale_0684` 56, `test_annot_blank_cause_0909` 27,
`test_ase_optier_0963` 94 — every one unmoved.

#### What B1 SETTLED, and what binds B2 · B3 · B4 · B5

* **⚠ THE RETURN SHAPE IS AN ANSWER DICT, NOT FLAT PAIRS — spec §4.2 B5's own
  sentence is WRONG and is amended.** `{devices absent complete state}`. The
  refutation is measured, not stylistic: §3.1's `XR1` resolves to
  `r.xr1.x0.rend1` **and** `r.xr1.x0.rend2`, both publishing a parameter spelled
  `i`, so a flat `{param value}` list loses which primitive each number belongs
  to and **ruling D-3 becomes unimplementable**. DD-1's corollary independently
  forbids handing a caller the pairs without the incompleteness.
  ⚠ **THE RE-DO MADE IT FIVE KEYS, NOT FOUR:**
  `{devices absent nonfinite complete state}`. **B3 must render from five.**
  `nonfinite` carries `{<rawdev> <param> <text>}` triples — columns the raw DOES
  hold for a device that did not converge. B3 rendering them as blanks is
  acceptable; B3 rendering them as `absent` is a lie, and B3 rendering their
  text is `id = nan` on a schematic, which invariant I3 forbids.
  ⚠ **AND AN EMPTY `nonfinite` IS NOT PROOF THE RUN CONVERGED** — the same NaN
  in an ascii raw arrives as a finite `0` and lands in `devices`. That
  asymmetry is `src/save.c`'s, is deliberate there, and is recorded as
  still-open at the end of issue 1272.
* **⚠ Q10 IS ANSWERED: YES.** `ngspice -b -r` on a deck with `.op` then `.tran`
  writes **one** file holding **two** plots; `xschem raw read <f>` lands on the
  Operating Point, `xschem annotate_op <f> 0` publishes (`raw annot` = `0 0 -1`)
  and `raw value <v> -1` returns real device numbers. So the RDW **is** reachable
  after an ordinary OP+TRAN run and `update_op()`'s op/dc guard is never reached
  with `sim_type=tran` on that path. **B3's suite can assert this rather than
  ask it.** Two caveats: on the `.control`+`write` writer the second `write`
  overwrites the first without `set appendwrite`; and once the tran slot is read
  it becomes **current**, at which point `raw list` answers about the transient.
* **⚠ THE SEAM READS THE CURRENT SLOT AND CHOOSES NOTHING.** Every `xschem raw`
  verb reads `xctx->raw`. A user who was looking at waveforms has a **transient**
  slot current. B1 refuses that with `state not_op`, checked **before** the
  published-yet gate — order is load-bearing, because
  `backannotate_at_cursor_b_pos()` sets `annot_p` on any swept database, so a
  transient with cursor B placed answers interpolated numbers at point −1.
  **B4/B3's consequence, unratified (`rule` debt `1245_B1_not_op_refusal`):** key
  3 pressed while a transient is loaded says *"no operating point"* rather than
  silently printing transient numbers.
* **⚠ POINT −1 IS THE ONLY HONEST READER, AND ONLY AFTER `update_op()`.** A
  `dims=0` column answers the empty string at point −1 and `0` at point 0; a
  genuinely computed `0.0` answers `0` at both. But **before** publication point
  −1 is empty for **every** vector — so absence may be reported only in state
  `ok`, or the seam says *"the simulator did not compute id"* about a run nobody
  annotated.
* **⚠ THE CAPABILITY IS DECLARED, AND `blanket_op_save` IS A TRAP.** `src/ase.tcl`
  already answers B1's own question — *can one card save every parameter of a
  device at once* — by **probe**, which D-4/DD-1 forbid. Reaching it is also
  operationally poisonous: `ase::sim_capabilities` builds a workdir and **starts
  the user's simulator** on a cache miss, on a path with no Run behind it. Any
  later item that "removes the duplication" by reading that key is violating a
  ruling. Rows C3/C4 of the preserved suite are the fence.
* **⚠ NEITHER HOOK MAY JOIN `register_backend`'s required-hook `foreach`.**
  `test_ase_core.tcl:1116` and `:1171` hand-build **five**-hook registrations that
  raise if a sixth becomes required, in a suite that already carries a baseline
  red where a second is easy to misread as pre-existing. Ride in the dict like
  `capabilities` does. Same rule for **B2** and **B5**.
* **A NEW `.tcl` FILE IS NOT FREE, BUT B1 NEEDED NONE.** `src/ase.tcl` is already
  sourced and installed, so B1 was pure Tcl with **no build and no
  `./configure`**. **B2 and B3 both add new files** and therefore both owe the
  `Makefile.in` install **and** uninstall lines plus `./configure` — receipt
  `grep -c <newfile> src/Makefile` = **2** (issue 0424).
* **Harness arms, twice paid for.** Suites on `full_audit.sh`'s `nogui_tests`
  (`test_ase_optier_0963`, `test_raw_read_dispatch`) **hang** on the display arm
  and pass in under 300 s with `--nogui` — they shell out to real ngspice dozens
  of times. `test_ase_log_seam_0207` needs `--logdir <tmpd>` and **no** `--nolog`.
  A number taken on the wrong arm is fiction.
* **The `untitled~.sch` phantom can vanish under a suite sweep**, and with it gone
  `test_ase_core` goes ALL PASS (182) — the phantom fix the brief forbids,
  arriving by accident. Re-check it before any audit taken straight after a sweep;
  `test_backannotate_digital` recreates it.

---

## B2 — the list store and the settings file  ✅ **DONE (status E), 2026-09-03**  *(no dependencies)*

**Do.** The class map (`type=` token → broad class: `nmos`/`pmos`→`mos`,
`res`/`poly_resistor`/`high_precision_poly_resistor`/`high_precision_poly_p`→
`resistor`, `capacitor`/`moscap`→`capacitor`, `diode`→`diode`,
`vertical_npn`/`vertical_pnp`→`bipolar`), extendable by the user. The three
lists per class. **D-7: seed from the PDK's `op_annot::register` calls, the
user's file wins per class.** Atomic write-beside-and-move (issue 0937). The
window and the CIW name the exact path on every Save.

**Files.** new `src/op_param_lists.tcl` (+ `src/Makefile.in` install **and**
uninstall, then re-run `./configure`) · new
`tests/headless/test_op_param_store_1245.tcl`

**Accept.** `grep -c op_param_lists.tcl src/Makefile` is **2**. A user entry
overrides its class and leaves the others seeded. Round-trips through a
save/reload. An interrupted write never truncates. The vocabulary really is
ragged — sky130 spells a resistor three ways — so the map is data, not a
`switch`.

---

#### What B2 SHIPPED, and what binds B3 · B5

**Landed as `src/op_param_lists.tcl`** (752 lines, pure Tcl, no C), sourced
bare from `src/xschem.tcl:16756`, installed and uninstalled from
`src/Makefile.in`'s `install_shares` — receipt `grep -c op_param_lists.tcl
src/Makefile` **0 → 2**, `./configure` re-run, `Makefile.conf` byte-identical
across runs. New suite `tests/headless/test_op_param_store_1245.tcl`, **ALL
PASS (39)**, registered by `full_audit.sh:393`'s glob with that file unedited;
the audit denominator moves **379 → 380**.

* **⚠ THE SETTINGS FILE IS `<pwd>/.xschem/op_param_lists.conf`, AND THE WORD
  `<project>` WAS B2'S TO PICK — IT IS UNRATIFIED.** DD-3 names the tier and
  leaves the word undefined; there is no `<dir>/.xschem/` precedent in this
  tree. B2 shipped **pwd** by ladder L2, because `xschem get current_dirname`
  **moves under a descend** (a Save taken inside a PDK library cell would write
  the project file into the PDK tree and the next read would not find it) while
  pwd is stable for a whole session, and because `xinit.c:3500-3515`'s
  `./xschemrc` is the tree's only analogue. **Rule debt 1273**; it is one proc
  to move. **B3 and B5 must name the path they resolve through
  `op_param_lists::conf_path project`, never build one themselves**, or the two
  halves can diverge the moment this is overruled.
* **⚠ THE TIER WIN IS PER (scope, key, listname), WHICH REFINES DD-3.** DD-3
  says the project file wins *"per class"*; B2 shipped per **list**, which is
  finer and never coarser — a project file that customises `mos annotation` no
  longer silently discards the user-global's `mos summary`. **Rule debt 1275**
  carries the whole grammar, which DD-3 does not state. Row **T2** is the single
  row that flips if the driver disagrees.
* **THE GRAMMAR, so B5 writes what the reader reads.** Whitespace-delimited,
  every row self-contained (so skipping a malformed one cannot silently
  reassign the rows after it), `#` and blank skipped, trailing `\r` trimmed,
  `-encoding utf-8` pinned on **both** channels with `-translation` left at
  `auto`:
  `version 1` · `class <type-token> <broad-class>` ·
  `list <scope> <key> <listname>` ·
  `param <scope> <key> <listname> <label> <rawparam> <kind>`.
  `scope` ∈ {class, flavor}, `listname` ∈ {annotation, summary}. A `param` row
  implicitly declares its list; the `list` row exists only to express an
  **emptied** list, which stays empty rather than degrading to the seed.
* **⚠ FIELDS ARE SPLIT WITH `regexp -inline -all {\S+}`, NEVER `llength` /
  `lindex` ON THE LINE.** Measured: `llength "mos annotation { id 0"` **raises**
  `unmatched open brace in list`, so a stray `{` in a teammate's file would kill
  the reader from inside. A parser its own input can raise in is not a strict
  parser. Any later row-reader must copy this.
* **LIST 3 (`all`) IS NEVER PERSISTED** (D-4). `owns` answers 0 for it always,
  `effective` answers `{}`, and a conf row naming it is reported and skipped
  with a sentence saying why. **B5's Add-from-list-3 writes into `annotation` or
  `summary`**, and needs no slot of its own — spec §4.2 B7 already greys its
  Delete.
* **`owns 1` WITH AN EMPTY LIST AND `owns 0` ARE DIFFERENT FACTS, AND B3 MUST
  NOT COLLAPSE THEM.** *Not customised* (fall back to the seed) versus *the user
  emptied this* (show nothing) is the same absent-vs-value distinction that
  refuted B1 the day before (issue 1272), one class further out.
* **`op_param_lists::apply` IS THE ONLY DOOR THAT REACHES THE SCREEN, AND B5
  MUST USE IT.** Only `op_annot::register` bumps `::op_annot::gen`, which
  `actions.c:2032` folds into the overlay epoch; a direct `set
  ::op_annot::desc(...)` is stored, correct in Tcl and **invisible** (invariant
  I5). `apply` is deliberately **called from nowhere** in B2: `op_param_lists.tcl`
  is sourced *before* any PDK `_procs.tcl` runs, so an auto-apply would write
  into an empty registry and `register`'s REPLACE semantics would discard it.
* **FIRST-REGISTERED-WINS IS UNIMPLEMENTABLE AS THE DRIVER STATED IT** —
  `::op_annot::desc` is a Tcl array and `op_annot` publishes no enumerator, so
  B2 shipped *first in lexical order of the `type=` token* (deterministic, and
  it coincides with registration order for all three shipped PDKs). Issue
  **1274**, one-line repair named, not fixed here.
* **⚠ THE THREE PDK COMMENT LINE NUMBERS IN THIS PLAN AND IN THE BRIEF ARE
  WRONG FOR TWO OF THE THREE.** The *"A first-class means for a user to choose
  her own set is OWED and TBD"* line is at `sky130A/sky130_procs.tcl:396`,
  `gf180mcuD/gf180_procs.tcl:102`, `ihp-sg13g2/sg13g2_procs.tcl:750` — sky130's
  `:405` is `} else {` and IHP's `:749` is a recovery-recipe line. **Grep for
  the text, never seek by line.** All three now point at
  `src/op_param_lists.tcl`; each file's invariant-I5 recovery recipe above it is
  untouched and still round-trips (rows C0/C1).

##### ⚠ SIX DEFECTS THE ADVERSARY MEASURED IN B2's OWN NEW CODE. B3 AND B5 INHERIT ALL SIX.

None is live today — `grep` for `op_param_lists::` outside its own file and its
suite returns nothing — and **all six become live the moment B3 calls
`effective` or B5 calls `write_conf` / `apply`. Fix them at B2's seam, not in
the UI.** B2's suite fences **none** of them; 39/39 is a statement about the
fence (B1's lesson, one item later).

| # | what | who trips it |
|---|---|---|
| **1276** | `write_conf` returns **1 with no report** when the target is a **directory** (the temp is moved *inside* it) or a **symlink** (replaced by a regular file, real target untouched). Save says it worked; the settings are gone | **B5**'s Save |
| **1277** | the **flavor glob wins by `lsort` order**, not narrowness or file order — `*fet*` beats `*nfet_01v8*` in both insertion orders — and a flavor key carries **no class**, so it can answer another class's query. The class field is a **grammar** change, so settle it *before* the first flavor entry is written | **B5**'s scope dialog |
| **1278** | a shared conf can **freeze the consumer**: `effective` runs `string match` on an unbounded pattern from the file (129 ms at 9 stars, >70 s at 13), accepted at load with zero reports. The parser is safe; the consumer is not | **B3**'s redraw |
| **1279** | bare `apply` iterates the **class map**, so a type the map does not name is never a candidate — the list is stored, correct, and **invisible** (`gen` never moves, invariant I5). Every unmapped shipped token inherits it | **B5**'s Save |
| **1280** | `apply` writes list 1 into `params`, and `op_annot::_cards_for` emits one `.save` per `params` row — so **trimming the annotation list stops the deck saving what the summary list asks for**, and those rows go permanently blank (R1, I3). ⚠ the fix carries a **user question**: does Delete stop *drawing*, or stop *saving*? | **B5**'s Delete |
| **1281** | writing the **project** file exports the author's **user-global** map and lists into it — the store keeps no provenance. For a file whose headline is shareability, Save checks in one person's personal taste | **B5**'s Save |

* **EVERY REPORT GOES TO stderr AND AN UNREAD BUFFER.** `_say` writes stderr
  plus an internal `reports` list readable as `op_param_lists::said`. Nothing
  reads it yet and the GUI shows stderr nowhere, so today every *"reported and
  skipped"* outcome — a malformed row in a teammate's file, the class-seed
  divergence — is, to a GUI user, **silence**. **B3 owes that channel**: drain
  `said` into the CIW after every `load`/`write_conf`.
* **Minor, measured, not defects.** A UTF-8 BOM is silently tolerated (Tcl's
  `\S` treats U+FEFF as space, so a Notepad-saved conf parses). An NBSP inside a
  label is reported and skipped, symmetrically with `_triple`'s `\s` rejection —
  no silent rewrite either way. Label/param **case is preserved and never
  folded**, which is required, because `op_annot::vector` builds the raw name
  from the exact `param` string.

---

## B3 — the window  ✅ **DONE (status E), 2026-09-03**

**Do.** `src/rdw.tcl`, namespace **`rdw::`** (⚠ `results::` is taken by
`Results > Select`). Singleton toplevel, raise-if-exists. A **string-backed,
read-only, `-exportselection`** text pane; newest dump on top. A button column:
Up · Down · Delete · Add · Save, greyed per the spec's table.

**⚠ Not `textwindow`.** `xschem.tcl:13567` takes a *filename*, opens an
*editable* widget, and its Save writes back to that file. Building on it would
offer to save the dump over a design file.

**Files.** new `src/rdw.tcl` (+ `Makefile.in` ×2, `./configure`) ·
`src/xschem.tcl` (the menu entry) · new `tests/headless/test_rdw_window_1245.tcl`

**Accept.** `grep -c rdw.tcl src/Makefile` is **2**. Opens, raises, closes,
reopens. Text is selectable and copyable and cannot be edited. Survives
`--nogui` by not being constructed there.

---

#### What B3 SHIPPED, and what binds B4 · B5

**Landed as `src/rdw.tcl`** (675 lines, pure Tcl, no C), sourced bare from
`src/xschem.tcl:16790`, one entry on the **main** menubar at `:17607`, installed
and uninstalled from `src/Makefile.in`'s `install_shares` — receipt
`grep -c rdw.tcl src/Makefile` **0 → 2** (`src/Makefile:228` install,
`:292` uninstall), `./configure` re-run with `config.h` and `Makefile.conf`
byte-identical across it. New suite `tests/headless/test_rdw_window_1245.tcl`,
**ALL PASS 32 (`--nogui`) / 42 (`:99`)**, registered by `full_audit.sh:393`'s
glob with that file unedited; the audit denominator moves **380 → 381**.

**The receipt was proved installed, not by proxy.** `make install DESTDIR=<tmp>`
ships `rdw.tcl` beside `op_param_lists.tcl`, and the **installed** binary run
against the **installed** sharedir starts `rc=0` (not 139) with `rdw` live.
Issue **0424**'s failure mode is closed in fact.

* **⚠ THE `--nogui` ARM IS THE ONE THAT CATCHES THE WINDOW BEING BROKEN, AND
  VICE VERSA — BOTH ARMS ARE LOAD-BEARING.** Measured, not argued:
  `SB-PANE-EDITABLE` (the pane made writable) reds **only** on `:99` and the
  headless arm is ALL PASS; `SB-HAVETK-TRUE` (the live-Tk guard forced true)
  reds **6 rows on `--nogui`** and is ALL PASS 42/42 on the display. A suite with
  either arm alone passes while the other half is dead. B4 and B5 must keep
  adding rows to **both**.
* **THE THREE SEAMS B3 MINTED. DRIVE THEM; DO NOT MINT A SECOND.** This is
  invariant **I1**'s shape (one builder, two consumers) applied to the window:
  * **`::rdw::listkind` + `rdw::set_list {annotation|summary|all}`** is *the*
    list-identity state. **B4 owns the keys that select a list and must call that
    setter.** `rdw::button_state {id kind}` is spec §4.2 B7's table **as data**,
    so B5 can assert the greying with no Tk at all.
  * **`rdw::dump {instname}`** is the whole round trip — header →
    `op_annot::devpath` → the seam → push — and is what **B4's keys should
    call**. `rdw::sim` resolves the backend; the seam is **never** named by its
    proc name (row `S1` is structural for exactly that reason).
  * **`::rdw::blocks`** is the store, newest-first, namespace state that works
    headless. The pane is only its projection. **B4's key `4`** (*clear
    everything but the most recent*) operates on that list, not on the widget.
* **`rdw::status {msg}` SETS THE VARIABLE ALWAYS AND THE WIDGET ONLY IF IT
  EXISTS**, which is what makes the inert path drivable in the `--nogui` arm.
  **B5's Save must name the exact settings-file path there**, and must resolve it
  through `op_param_lists::conf_path project` (B2's rule) rather than building
  one.
* **⚠ B3 CALLS `op_param_lists::` NOWHERE, SO B2's SIX DEFECTS ARE STILL NOT
  LIVE — AND B5 IS THE ITEM THAT MAKES THEM LIVE.** In particular **1278**'s
  unbounded-glob freeze was listed above as landing on *"B3's redraw"*: it does
  **not**, because the greying keys on list **identity**, never on list
  **content**. Whoever first calls `effective` from the window inherits it.
* **⚠ PLAN's B2 NOTE *"B3 owes that channel: drain `said` into the CIW after
  every `load`/`write_conf`"* HAS NO TRIGGER IN B3 AND MOVES TO B5.** B3's
  buttons are inert by its own brief, so B3 calls neither `load` nor
  `write_conf`; a channel drained after calls that never happen is untestable.
  **B5 ships Save and therefore owns the drain.**
* **THE BUTTONS ARE BUILT, GREYED AND INERT.** Five ids `up down delete add
  save`, every enabled one routing to `rdw::inert`, which names itself **and
  names item B5** in the window's own status line. **B5 replaces `rdw::inert`,
  it does not add a parallel command path.**
* **⚠ THE WINDOW OPENED FROM THE MENU TODAY IS COMPLETELY BLANK** — pane empty,
  status empty — because **B4 ships the keys that put a dump in it**. That is by
  design and in scope, but it means *"Tools > Results Display Window"* is a
  dead-looking entry until B4 lands. If B4 slips, consider whether the empty
  window should say how to fill it.
* **SEVEN USER-VISIBLE SENTENCES WERE MINTED AND ARE UNRATIFIED** (rule debt
  `1245_B3_window_wording`), including a **FIFTH silence nobody specified**:
  `state ok` with nothing in any bucket, which under measured rule **R1** is the
  **common** case. **B4 and B5 must not reword these ad hoc** — they are locked
  by golden rows in B3's suite, and the user has not ruled on them.
* **THE UNION IS THE RENDERER'S LOAD-BEARING RULE.** A device can appear in
  **no** `devices` entry at all: an all-`dims=0` device answers
  `devices {} absent {...} state ok`, and a binary NaN/Inf device answers
  `devices {} nonfinite {...} state ok`. The row set is built from the union of
  all three buckets' rawdev names. **Any later code that walks
  `dict keys [dict get $ans devices]` prints an empty dump for a real, named,
  non-converged device.**
* **Q6's HEADER SHIPPED AS THE DEFAULT, NOT RE-LITIGATED.** Line 1 is
  `<inst>:` + `sch_path` with leading **and** trailing dots stripped and dots →
  slashes, kept rooted; line 2 is `op_annot::devpath`'s **own** string, dimmed.
  ⚠ **At the top sheet `sch_path` is `.`, so the header degenerates to `M1:/`** —
  an edge nobody has ruled, now locked by rows `H1`/`H2` so it cannot drift
  silently.
* **Q10 IS NOW AN ASSERTION, NOT A QUESTION** (row `Q1`): one raw holding an
  `Operating Point` plot then a `Transient Analysis` plot, annotated, renders the
  six real numbers with the honesty line.
* **Minor, measured, not defects.** `test_startup_guard_0663.tcl`'s **header
  prose is stale** — it says *"FIFTEEN helpers"* and cites `:14568`/`:14796`/
  `:14815` where the real lines are `:16749`/`:16756` and the block now runs to
  ~`:16828` with `rdw.tcl` in it. **No CHECK counts the sources**, so the suite
  is PASS and adding a helper reds nothing; the prose is simply one more helper
  out of date. `src/actions.csv` is **untouched** (outside B3's Files cell) —
  Calculator has a `tools` row there feeding the command palette and cheat-sheet,
  `build_menu_from_table` is `file`-only (`xschem.tcl:17075`) so no csv row can
  duplicate the hand-written entry, and **the palette row is deferred to B4**,
  which owns the keys.

##### ⚠ THE IMPLEMENTER EDITED ONE ROW OF ITS OWN NEW SUITE — read this before trusting `M1`

Row `M1`'s third leg was **unsatisfiable by any correct Makefile** and was
repaired in the same item. It counted **substring occurrences** and expected 2,
but its own name says *"so `grep -c` is 2"* and `grep -c` counts **lines**.
scconfig's install template names the file on **both sides of the copy**
(`install -f rdw.tcl "$(XSHAREDIR)"/rdw.tcl`), so every shipped helper is
**3 substrings on 2 lines** — verified against `op_param_lists.tcl`,
`results.tcl` and `calculator.tcl`, none of which B3 touched. The leg is now a
**line** count, still expecting 2, with the measurement written into the file as
a comment. **The row is not weakened**: its first two legs still pin exactly one
install line and exactly one uninstall line **by name**, so "2" cannot be reached
by two install lines and no uninstall line, which was the row's whole point.

##### ⚠ THREE DEFECTS B3's OWN PASSES MEASURED. B4 AND B5 INHERIT THEM.

| # | what | who trips it |
|---|---|---|
| **1282** | the RDW renders a **DC sweep as an operating point**. The seam's allow-list is `{op dc}`, so a `dc` raw answers `ok` with real point-0 numbers and the block says *"operating-point columns"* with `dc` nowhere. `ctx` already carries `simtype`; only the `not_op` arm uses it. ⚠ the choice — name it / render it silently / refuse it — is the **user's**, and refusing reaches into **B1's landed seam**. Part 2: `rdw::sim` collapses *not registered* and *registered without the hook* into one sentence | **B5** (first to set `::rdw::sim`) |
| **1283** | three things **B3's own suite** claims to fence and does not, behind a green 32/42: newest-first **store** order has no headless witness at all (row `Q1b` pushes one block and asserts it is at index 0 — true either way); the union's **cross-bucket order** is unfenced on both arms; the **inert-button message** is fenced only on the display arm | **B4** (its Files cell already says *rows in B3's suite*) |
| **1284** | a **backend's answer dict** can make the window lie, blank or **raise** — `format_answer` treats the five-key dict as trusted and it is whatever a **D-5** backend hands it. Unreachable through ngspice; live for the second backend | whoever adds backend #2 |

---

## B2a — harden what B2 and B3 shipped  ⛔ **NOT LANDED (status F), 2026-09-03.** Re-done as **B2a-2**, which was ALSO reverted — **read the B2a-2 section below, not this one, and apply the B2a-2 patch.**  *(blocks B4 and B5)*

**Scope was nine filed issues**: 1276–1281 in `src/op_param_lists.tcl`,
1282–1284 in `src/rdw.tcl` and its suite. All nine were implemented, both suites
grew (store 39→56, window 32→43 headless / 42→53 on `:99`), seventeen sabotage
variants each red exactly their own rows, and Verify-A found no regression.
**It was still reverted**, because the adversary pass refuted the central claim
and the write-up agent reproduced three of its attacks independently.

> **THE WORK IS PRESERVED AND MUST NOT BE RETYPED.**
> `doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` — 2,506 lines
> across four files — **applies clean to `825cd3bd`**. The next crew's job is
> **apply → fix the three holes below → re-verify**, not reconstruct. Each of
> the nine issue files carries the full record of the attempt under a
> *"Why this was reverted"* heading.

### The three holes that forced the revert — fix these in the re-do

| # | Where | What is wrong, measured |
|---|---|---|
| **1** | **1284**, `rdw::_answer_flaw` | **A REGRESSION AGAINST HEAD.** It runs *before* the state check and treats an **absent `devices` key** as a flaw, so a third-party backend answering a refusal minimally (`{state no_raw}` — the natural spelling) gets *"the reader answered in a shape this window could not read"* where HEAD correctly says *"No simulation results are loaded."* Three correct sentences replaced by one false accusation, in the exact class **D-5** says the user's own custom ngspice will occupy. **Fix:** take the state verdict first and validate only the `ok` path, or treat an absent `devices` as an empty bucket exactly as `absent`/`nonfinite` already are. |
| **2** | **1277**, `_flavor_order` | **DD-2 IS NOT IMPLEMENTED.** The primary sort key is **fewest `*`**, and fewest-stars is not narrowness: `sky130_fd_pr__*` (the whole PDK) beats `*nfet_01v8_lvt*`, and a bare `*` beats it too — **in both insertion orders**. That is this issue's own filed defect under its own fix. Worse, `write_body` writes *"narrowest matching glob of that class wins"* into every settings file it emits. **Fix:** rank by literal (non-`*`) length or matched-prefix specificity. Separately, the v2 **round trip corrupts any glob with a Tcl list metacharacter** (writer interpolates a list rep, reader splits on whitespace) — `a[nm]fet*` returns brace-quoted and can never match, zero reports. |
| **3** | **1281**, provenance | **A LEAK BECOMES SILENT DATA LOSS.** With the user and project files overriding the same key, `load` then `write_conf <user path>` **deletes the user's own personal rows from the user's own file** — `rc=1`, `reports=0` — because the override stamped them `project` and the store keeps no user-tier copy. HEAD merely leaks; this destroys. **Fix:** keep a **per-tier value store**, not one flat store plus an origin stamp; a one-word origin discards the losing value at load time and the writer then has nothing to write. |

### What the suites could not see, and must now fence

Every one of the three hid behind a green suite, and each for the same
structural reason — **the fence only asks the question its author thought of**:

* `rw_ansd` **always** constructs all five answer keys, so no row can express a
  devices-less answer → hole 1 invisible.
* every flavor glob in the store suite is **2-star** (`*fet*`, `*nfet_01v8*`,
  `*_1v8_x`, `*t*`), so no row pits a 1-star broad glob against a 2-star narrow
  one → hole 2 invisible. Row F5's round-trip fence uses `*nfet*`, which has no
  metacharacter → the corruption invisible too.
* rows T4/T5 never construct a **tier conflict** (the same key in both files)
  → hole 3 invisible.

**This is the batch's lesson for the fourth consecutive item.** B1 was green at
37/37 while returning `nan`; B2 and B3 were green while shipping nine defects;
B2a was green at 56/43/53 with seventeen sabotage variants while carrying a
regression. **A green count is a statement about the fence.**

### What still binds the next crew, revert or no revert

* **The grammar deadline is unchanged and still free.** Nothing writes a flavor
  row until **B5**, so v2 remains an *edit* rather than a migration. Issue
  **1275** is still the ratification door and is back on the user's queue with
  corrected wording.
* **Issue 1285 survives the revert and BLOCKS B5.** `op_annot::text`
  (`op_annot.tcl:1726`, params loop `:1741`) draws the on-sheet rows from the
  **same `params` list** `_cards_for` turns into `.save` cards, so **DD-4's two
  clauses cannot both be true of one field**. That is a property of
  `825cd3bd` + DD-4, not of B2a's code. Answer it before the re-do, not after.
* **Issue 1286** — `ase::sim_write_conf` (`src/ase.tcl:1999-2034`), the writer
  `write_conf` was copied from, carries **both** of 1276's holes structurally.
  Another item's file; filed, not fixed.
* **DD-5's quoted specimen wording is FALSE** and must not be pasted verbatim by
  whoever re-does 1282: `save.c:1073` and `:1120` rename a **multi-point
  `Operating Point`** plot to `dc` themselves, so "not a standalone operating
  point" is wrong for a case save.c creates. Rule debt **1282**.
* **`src/ase.tcl:8803` must stay untouched** — `test_rdw_seam_1245`'s row `G3b`
  is a cross-language fence counting save.c's own `op`/`dc` `strcmp`s, and
  **DD-5 forbids the narrowing anyway**.
* **No build, no `Makefile.in`.** Both files are already installed
  (`grep -c op_param_lists.tcl src/Makefile` = 2, `grep -c rdw.tcl` = 2). Pure
  Tcl; xschem sources `.tcl` at startup.

---

## B2a-2 — the re-do of B2a  ⛔ **NOT LANDED (status F), 2026-09-03 — apply + fix three + add DD-6, all done and green, REFUTED AND REVERTED AGAIN.**  *(still blocks B4 and B5)*

**Scope was 1276–1285 plus ruling DD-6.** B2a's patch was applied unchanged (not
retyped), its three refuted fixes re-fixed, and DD-6's display key added.
Everything the item was asked to produce, it produced:

* store **39 → 71**, RDW window **32 → 49** headless / **42 → 59** on `:99`;
* `test_op_annot` **485/492** and `test_annot_declutter_1244` **134** unmoved,
  `test_rdw_seam_1245` **49** unmoved (the Feature A fences held);
* audit back at **367 pass / 12 fail / 0 crash / 2 skip of 381**, non-PASS diff
  **empty by name and verdict**; T1 at zero;
* **red-before-green on every row**, each carrying the adversary's own
  reproduced input;
* a **ten-variant** sabotage matrix, trustworthy, with the two predicted-reds
  that did not appear explained and closed by an added variant.

**It was reverted anyway.** The adversary refuted the central claim and the
write-up agent **reproduced four attacks first-hand** before deciding.

> **THE WORK IS PRESERVED AND MUST NOT BE RETYPED — AND IT NOW CONTAINS BOTH
> ATTEMPTS.** `doc/claude/op_param_batch/B2a-2_working_tree_REVERTED.patch`
> (md5 `1977a39e5d419d31fcbbbc3932c2606f`, 3,573 lines, eight files) **applies
> clean to `849f2231`**, verified with `git apply --check` in both directions.
> **Use this patch, not B2a's** — it is a superset. The third crew's job is
> **apply → fix the four holes below → re-verify**.

### What is SOUND in the patch and must be kept

* **1276, 1278, 1279, 1280, 1282, 1283** — untouched by either adversary, twice.
* **1284 — the fix is right and survived a 22-shape adversarial matrix with no
  counterexample.** State first, shape only under `ok`, an absent bucket empty
  rather than malformed; row **F26** fences the *order* structurally. Apply
  unchanged.
* **1277's round-trip half** — `_key_fields` emitting class and glob as two
  separate unquoted fields in **both** the `list` and the `param` row. Nine
  metacharacters round-trip clean where eight of nine corrupted.
* **All of DD-6 except two points** — the key name `shown`, the fall-back, the
  `_cards_for`/`_claims`/`_kind` split, invariant **I7**'s row, and the
  empty-`shown`-draws-nothing decision.

### The four holes that forced the second revert

| # | Where | What is wrong, reproduced by the write-up agent |
|---|---|---|
| **1** | **1277**, the emitted sentence | **THE FILE STILL LIES ABOUT ITS OWN PRECEDENCE — a named ACCEPT row.** The re-keyed order (most non-wildcard chars, then fewest wildcards, then lexical) fixes the bare `*` **only among `*`-only globs**. Measured: `_flavor_order {* **}` → bare `*` **wins**; `{* ?*}` → bare `*` **wins** though `?*` is strictly narrower; `{*ab* ?ab?}` on cell `xaby` → the **broader** glob wins. `?` is counted as a wildcard (so it *reduces* the literal count) but its narrowing is never credited, and `_glob_why` caps only `*`. The file nonetheless prints *"So a bare `*` is always the last resort"*. Row **F6b**'s fence is **all `*`**, so it cannot see it. **Fix:** credit `?` as narrowing (it matches exactly one character), re-check `**`, and **generate the fence from the emitted comment** so the two cannot drift a third time. |
| **2** | **1277**, key identity | **The v2 flavor key is a two-element Tcl list used as an array index and is not canonicalised.** `set_list flavor {mos a[nm]fet*} …` and `_parse_line`'s `list`-built key are **different indices**; after a round trip `owns` is 0, setting it again makes a **second** `owned` slot, and `write_conf` then emits **two** `list` rows and two conflicting `param` rows, one silently discarded, **zero reports**. **New with grammar v2** (a v1 key was one element). **Fix:** canonicalise with `list` at both doors. |
| **3** | **1281**, the default-skip | **A SECOND SILENT DELETION OF A ROW THE USER TYPED.** With the shipped default already `nmos → mos`, a **user** file carrying the explicit pin `class nmos mos` and a **project** file carrying `class nmos weirdclass`: `write_conf <user path>` returns **rc=1, zero reports**, and the user's file afterwards holds **`version 2` and nothing else**. The fix's own improvement causes it — the default check now compares against `_tier_class` (the user's own value) instead of the merged one, so the row is skipped as "not an override". HEAD leaked a wrong value there; this destroys the line. Row **T6** cannot see it: its contested token maps to a **non-default** value. **Fix:** a row a tier's file *contains* is written back to that tier even when its value equals the default. |
| **4** | **1285 / DD-6** | **Two claims the code asserts in writing are false.** (a) *"`shown` is always a SUBSET of the union by construction"* — `_save_set` dedups by **label** and `set_list` accepts a duplicate label (issue **1288**), so `apply` itself produces `shown` ⊄ `params` and `op_annot::_kind`/`vector` **raise**; the same run emits a `.save` card **twice**, against rule **R1**. (b) *"gains no raise site that issue 0447 does not already cover"* — a descriptor with `shown` = `{a` registers cleanly (`register` validates only `dict size`) and then **raises on every redraw**, in a proc C calls per instance per redraw, with `params` well formed. **Fix:** validate `shown` in `register`, not in `text`; and fix **1288** in the same pass or stop relying on the subset. |

#### What B4 learned that binds every later step

* **The batch's lesson, for the fifth consecutive item: a green count is a
  statement about the fence, not about the code.** B2a-2 was green at 71/49/59
  with ten sabotage variants and **red-before-green on every row**, and still
  carried four defects. Red-first is necessary and is **not sufficient** — every
  one of the four hid in a case the row's author did not think to construct
  (a `?` glob, a default-valued token, a duplicate label, a malformed new key).
  **When a row asserts a sentence, generate the row from the sentence.**
* **A comment that denies a hazard is worse than no comment.** Three of the four
  holes are places where the code *asserts in writing* that it is safe: the
  emitted precedence sentence, the subset guarantee, the no-new-raise-door
  claim. Each assertion was written by the agent that introduced the
  counterexample. **Do not write a guarantee you have not fenced.**
* **New issues from this item: 1287** (the `apply`→`seed` clobber, live at HEAD,
  and DD-6 makes it wider), **1288** (`set_list` accepts a duplicate label its
  own parser rejects — a HEAD defect, and the root of hole 4a), **1289** (DD-6
  blanks a `derived` row whose operand it removed — **a property of the ruling**,
  it needs a **ruling**, and it binds B5), **1290** (`test_ase_optier_0963` X7
  is an intermittent red).
* **Capture any seed BEFORE the first `apply`** (issue 1287) or an acceptance
  row fences the union and passes while the defect is live. One false-clean was
  produced exactly this way.
* **`doc/claude/op_param_batch/receipts/B2a.md` does not exist** and never did —
  the B2a record is the LEDGER rows, commit `849f2231`, and the issue files.
  The brief that sent the second crew told it to read that file first.
* **Unchanged and still true:** the grammar deadline is free until B5 writes the
  first flavor row; `src/ase.tcl:8803` must stay untouched (row `G3b`); no
  build, no `Makefile.in` — both files are already installed.

## B2b — what the sheet draws  ✅ **LANDED, status E, 2026-09-03.** DD-6 as amended + 1285 + 1289/DD-9. *(unblocks B5's Delete; one question is the user's)*

**Scope was exactly three things** — issue **1285**, issue **1289**, and the
**DD-6 amendment** — and nothing else was touched. This is the first of the
three items the B2a/B2a-2 bundle was split into, and the split worked: the two
guarantees that refuted B2a-2 are now **built** rather than asserted, and the
seven issues that rode along with them last time were not in this commit at all.

**What shipped.**

* `src/op_annot.tcl` — the optional descriptor key **`shown`**, plus
  `op_annot::_display_rows`, plus DD-9's split inside `op_annot::text`.
  * **`params` is what the run computes; `shown` is what the sheet draws.**
    `_cards_for`, `_claims` and `_kind` stay on `params` and **must**, or a user
    who hides a row also stops the deck saving it.
  * **DD-9 in one line: `vars` is built over `params`, rows are drawn over
    `shown`.** The `params` loop stayed exactly where it was and stayed the only
    place that reads the raw, so the proc gains **no new `xschem` call and no new
    raise site** (row **D9** counts both structurally: 1 and 0, unmoved). The
    narrowed rows are minted from that same pass's label→value cache — never a
    second read loop, never a swap of the list the loop walks.
  * **A malformed `shown` is treated as ABSENT, full stop.** `_display_rows` is
    the `op_annot::_matches` idiom with the catch enclosing **the `lindex` of
    every row**, because two different malformed shapes reach it and a guard that
    closes one leaves the other open (below).
  * **A `shown` row whose label is in no `params` row draws BLANK** — no read, no
    `_kind`, no raise (**I3**) — whoever wrote the key.
* `src/op_param_lists.tcl`, **`apply` only** — `_apply_owns`, `_save_set`,
  `_show_set`, and two passes. `params` gets the annotation ∪ summary union over
  `effective` (never `get_list`, so an unowned list answers the PDK seed and the
  union can only be a **superset**); `shown` gets **that union filtered by the
  annotation list's labels**, so the subset holds **by construction** for every
  input.
* One comment block in each of the three PDK `_procs.tcl` naming which list is
  which. Every shipped register site still declares `params` alone, so every
  shipped PDK draws exactly as it did (**I7**, row **D1**).
* `tests/headless/test_op_param_store_1245.tcl` **39 → 51**. `test_op_annot`
  **485/492** and `test_annot_declutter_1244` **134** unmoved, by name and count.

#### What B4 learned that binds every later step

* **⚠ THE BRIEF'S OWN FIXTURE DID NOT EXIST, AND THE ISSUE SAID SO TWICE.**
  *"IHP ships the fixture: `gm/id` and `ft`"* is **false on this tree**, as are
  issue 1289's lines 39 and 74 and the same sentence in the spec. Measured: all
  four shipped register sites carry `devpath`/`devproc` + `match` + `params` and
  **nothing else**; every `derived` in the three PDK files sits inside the
  **recovery-recipe comment** (ruling D9 removed them), and `test_op_annot`'s
  `P_DERIVEDACC` golds `derived` = `{}` for all seven shipped types. DD-9's
  substance was unaffected — the fixture is **built** from that documented recipe
  under **I5**, which is what the recipe is for. **Corrected in place** in the
  issue and the spec. *Before writing a row that asserts a PDK ships something,
  grep the PDK.*
* **A `catch {llength …}` is not a list guard.** Two shapes, both measured:
  `{broken` makes even `llength` raise, but `{id id 0} {d "x}` has `llength`
  **2** and raises only at the `lindex` of its **second row**. The guard has to
  walk the rows. Issue 1285's own "Still open" item 2 and spec §4(b) both
  recommended the register-side `llength` check; **both are refuted** and both
  are corrected.
* **The fallback deliberately hands back NOTHING**, so `params` is still walked
  unvalidated and issue **0447**'s door is still open. Wrapping that walk too
  would close a filed defect **by accident** and turn it into a silently blank
  sheet. Row **D7** here and **K17** in `test_op_annot` fence it from both sides,
  and the `blanket_catch` sabotage reds both. **Do not "harden" that walk.**
* **⚠ THREE NEW ISSUES, AND TWO OF THEM ARE B5's PROBLEM BEFORE THEY ARE
  ANYONE'S.**
  * **1291 — `apply` now RAISES on a malformed registered `params`**, because
    `_save_set`/`_show_set` walk `effective`, which falls through to `seed`, i.e.
    the registered string verbatim. A/B measured on issue 0447's own shape: HEAD
    `rc=0`, after B2b `rc=1 unmatched open brace in list` with nothing written.
    **Latent — `apply` has no caller until B5 — so B5 must settle it before
    wiring a button to it.** Recommended: skip the class and `_say` why.
  * **1292 — narrowing is ONE-WAY.** Nothing removes `shown`, and `apply`
    deliberately skips a class the user owns nothing for, so `reset` + `apply`
    leaves the sheet narrowed for the session. **B5's Reset/Defaults button
    cannot be built on `reset` + `apply` as it stands.** The honest fix is the
    pristine-descriptor stash issue **1287** already needs.
  * **1293** — a duplicate `params` label gives the narrowed sheet (FIRST wins)
    and a `derived` row (`_evalrow`, LAST wins) different values. Unreachable
    through `apply`, which dedups by label. Decide it with **1288**.
* **Issue 1287 got WIDER, not fixed.** After an apply, `seed` answers the
  **union**, so the PDK's own list is unrecoverable without a restart. It is
  assigned to none of B2b/B2c/B2d.
* **`shown`'s ABSENCE IS MEANINGFUL and PRESENT-AND-EMPTY IS NOT ABSENT.** An
  empty `shown` draws no `params` rows at all, and because the declutter's gate
  is `actions.c:1764` → `annot_instance_annotated()` →
  `annot_block_has_value()` over the **rendered block**, a device whose block
  goes empty also **drops out of the declutter** and the texts it was hiding come
  back. That is **the item's status-E question** (below), it is on the owed
  ledger as rule debt `1285_empty_display_key`, and row **D10** fences it either
  way to a one-line change.
* **The declutter is coupled to what `text` DRAWS.** Any later item that changes
  which rows are minted changes which instances declutter. There is no test that
  will tell you; the coupling is one C call deep.
* **B2c and B2d are untouched by this.** `apply`'s conf reader and writer, the
  flavor grammar and the RDW window were not opened. The two `look` debts B2a-2
  recorded remain stale except one: **`DD-6 narrowing on the schematic` is TRUE
  AGAIN VERBATIM** and was not re-filed.
* **Unchanged and still true:** no build, no `Makefile.in` — both files are
  already installed; pure Tcl takes effect on the next launch.

---

## B2c — the settings file on disk  ⛔ **NOT LANDED (status F), 2026-09-03. Third revert on the same two issues.**  *(still blocks B5)*

**Scope was exactly four issues** — **1277** (the flavor class field + DD-8 file
order), **1281** (DD-7 read-modify-write Save), **1276** (the writer's two
target guards) and **1288** (one duplicate-label rule at both doors). The item
was deliberately small: it is the **second** of the three the B2a bundle was
split into, and its two headline issues are **the exact two that were
implemented twice and refuted twice**.

Everything the item was asked to produce, it produced:

* store suite **56 → 79**, ALL PASS headless and on `:99`;
* `test_op_annot` **485/492**, `test_annot_declutter_1244` **134**,
  `test_rdw_seam_1245` **49**, `test_rdw_window_1245` **32** — all unmoved;
* full audit back at **367 pass / 12 fail / 0 crash / 2 skip of 381**, non-PASS
  diff **empty by name and verdict**, and identical at **check** level (25 FAIL
  lines → 25);
* **red-before-green on every one of the four**, each red being the previous
  crews' own measurements reproduced;
* an **eight-variant / ten-arm** sabotage matrix, trustworthy, with all four
  predicted-reds-that-did-not-appear explained by construction and one arm
  *added* by the sabotage agent to close a gap it found.

**It was reverted anyway.** The adversary refuted the central claim, and the
write-up agent **reproduced the refutation first-hand** — plus three more — on
the working tree before deciding.

> **THE WORK IS PRESERVED AND MUST NOT BE RETYPED.**
> `doc/claude/op_param_batch/B2c_working_tree_REVERTED.patch` (2,095 lines, two
> files) **applies clean to `adc08706`**, verified with `git apply --check` in
> **both** directions and round-tripped twice during the write-up. It is a much
> smaller and much better patch than B2a-2's: **no provenance machinery, no
> glob ranking.**

### What is SOUND in the patch and must be kept

* **1276 — both guards, untouched by three adversaries now.** `_resolve_target`
  (16-hop bounded symlink walk, `file normalize [file join [file dirname $p]
  $tgt]` — the relative-target correction issue 1276's own recommended one-liner
  gets wrong) and `_target_why`. Directory target, relative-target symlink from
  a different cwd, dangling link, 20-hop chain, unreadable target: all correct,
  all with a sentence. **Apply unchanged.**
* **1288 — the shared rule.** `_dup_index` + `_dup_why` lifted out of
  `_parse_line` and called by **both** doors. The API report is byte-identical
  to the file report with the `<path>:<line>: ` prefix and `: <line>` suffix
  removed, computed in one run. **Apply unchanged**, and note it moves row
  **D5**'s golden (below).
* **1277's file-order half — DD-8 is correct and is the first thing in this
  batch that got it right.** `variable keyorder`, a plain list appended on first
  sight of a key, consumed by `effective` and by the writer. All three glob
  pairs both crews got backwards, in **both** insertion orders, 6/6 = the first
  row in the file, **including a bare `*` above `*nfet_01v8_lvt*`**. **No
  ranking proc exists** — no `_flavor_order`, no narrowness metric, no
  `maxstars`.
* **1277's class half** — `_flavor_matches_class`, so `effective capacitor` no
  longer answers with a `mos` flavor's list.
* **1277's metacharacter half** — `_key_fields` emitting class and glob as two
  separate unquoted fields in **both** the `list` and the `param` row, plus
  canonicalisation in `_key` alone. Nine `format %c` shapes round-trip clean.
  **And the brief's "reject at write time" arm is NOT needed**: measured, nine
  of ten shapes already round-trip at HEAD and the corruption is *created* by
  v2's whole-key interpolation. Refusing would cost `[nm]` and `\*`, both
  documented `string match` features. Only whitespace is refused, as HEAD does.
* **Row F5, and it is the single best thing in the patch.** It **generates its
  own case from the emitted comment** — regexps the two specimen globs and the
  cell name out of the freshly written file's `e.g.` line, builds both orders,
  asserts the stated winner and the flip. Delete or falsify the sentence and F5
  reds. That is issue 1277's "still open" item 2, and it is the row both
  previous crews failed. **Keep this shape and copy it wherever a comment makes
  a promise.**

### The hole that forced the third revert

| # | Where | What is wrong, reproduced by the write-up agent |
|---|---|---|
| **1** | **1281 / DD-7**, `_row_id` vs `_parse_line` | **A ROW THIS BUILD CANNOT PARSE IS DELETED ON SAVE — rc=1, ZERO reports.** Issue **1294**. The writer's merge classifier `_row_id` validates verb → scope → arity and **nothing else**; the reader `_parse_line` also runs `_valid_list`, the livelist guard and `_triple`. So `param class mos annotation NEWROW raw ratio` is *rejected by the reader* ("kind \"ratio\" is not an integer") and *identified by the writer* as key `{class mos annotation}` — and when that key is dirty the group is rebuilt and the row is gone. Measured 5/5 unparseable kinds. **DD-7's own sentence — "you cannot delete a row you never parsed into a model" — is falsified by its own implementation**, and so is the emitted header's *"rows a newer xschem wrote that this one does not understand"*. **Row T4 cannot see it: T4's future row has an unknown VERB, the one class `_row_id` genuinely cannot identify.** Blast radius measured exactly: `stamp=0` + change the same key → **deleted** (the real Save path); `stamp=1` (any direct `load_conf`) + change *any* key → **deleted**; `stamp=0` + change another key → survives. **Fix:** `_parse_line` calls `_row_id`, so there is genuinely one builder — the shape this item's own plan specified in writing and the code did not build. |

### Three more measured, filed, and NOT the reason for the revert

* **1295 — the merge silently rewrites line endings.** A teammate's CRLF file
  comes back all-LF, rc=1, zero reports; every untouched line's bytes change.
  `_read_lines` correctly reuses the parser preamble (`string trimright \r`),
  which is right for a parser and wrong for a preserver. **Row P4 fences the
  parse, not the merge** — the scout named this in advance and the row was not
  written. Makes every save a whole-file diff, against the file's own reason to
  exist. Same issue: an interleaved user comment between two `param` rows of a
  dirty key moves **after** the rebuilt group.
* **1296 — an existing file never gains the precedence sentence, and needs a
  RULING.** B2c's ladder-L2 decision *"the header goes only into a file with no
  lines"* (taken for DD-7, fenced by row W9) collides with the item's **named
  ACCEPT row** *"the sentence the file emits is TRUE of the code that emits
  it"*. Measured: a pre-existing file saved with a new v2 flavor row has
  `FIRST ONE IN THIS FILE WINS` **zero** times, keeps a v1 grammar block
  directly above a 5-field v2 row, and still declares `version 1`. Harmless
  today (no file exists in the wild — which is exactly why the grammar bump is
  being done now), **real from B5 onward**. Three options costed in the issue;
  **(b), migrate the version row and refresh the header, is the recommendation.**
* **1294's secondary** — `_key` silently **truncates** a >2-element flavor key,
  so `owns`/`get_list` answer for a key `set_list` refuses. Three doors, two
  rules: **a new two-door disagreement of exactly the class 1288 was filed
  about, introduced by the fix for it.** Latent; B5's scope dialog is the first
  door that could reach it.

#### What B4 learned that binds every later step

* **⚠ THE LESSON, AND IT IS NEW: under a read-modify-write, the WRITER'S ROW
  CLASSIFIER MUST BE EXACTLY AS STRICT AS THE READER.** DD-7's safety argument
  is *"you cannot delete a row you never parsed"* — that holds only while the
  writer cannot **identify** a row the reader refused. Any laxity in the
  classifier converts DD-7 from a preservation mechanism into a deletion
  mechanism, silently, with rc=1. **This binds any future DD-7 implementation
  and it is not obvious from the ruling's text.**
* **A "future row" fixture must use a KNOWN verb with an unreadable field, not
  an unknown keyword.** An unknown keyword is the easy case and it is the one
  every crew writes. The rows a newer build actually emits are known verbs whose
  value vocabulary grew. T4 passed on the easy case for a whole verification
  chain.
* **DD-8 is settled and correct — do not reopen it.** File order works, the file
  documents itself, and the F5 shape proves the sentence. This is the one design
  question in the batch that three attempts have now converged on. The next crew
  should **apply the patch**, not re-derive the ordering.
* **Row D5 (item B2b's) moves when 1288 is fixed, and that is correct.** D5 was
  built *on* 1288's open door — its own comment said *"Issue 1288 is LIVE on
  this tree"* — so closing 1288 changes its golden from `{{A id 0} {A gm 1}}` to
  `{{A gm 1}}`. B2c edited only the golden and the prose, never `_save_set` /
  `_show_set` / `apply`, and SB-DUP-BLIND still reds D5 alongside E1–E4, so the
  row stays non-vacuous. **Expect this again; it is not a regression.**
* **`set_list`'s contract changes** — a malformed **triple** stays an
  all-or-nothing refusal, a duplicate **label** becomes a reduction returning 1.
  That is a **ladder-L3** change to a written contract and is on the user's
  queue as rule debt **1288**.
* **Two `load_conf` behaviours are now pinned by five existing green rows.** A
  direct `load_conf` **must** stamp its keys and `load` (the two-tier startup
  restore) **must not**, or M3, X3 and P5 go red and P4 passes vacuously. This
  is the scout's "#1 seam", it was confirmed by sabotage arm SB-DIRTY-NEVER
  (which reds exactly those rows), and it is the only reading that satisfies
  DD-7 literally on the real Save path. **Spell it `load_conf {path {stamp 1}}`
  — the required arity must not move (row J1 / OL_API pins it), and the same
  goes for `write_body {fp {old {}}}`.**
* **⚠ PROCESS: a sibling agent mutating the shipped source in place voids
  another agent's tiers.** Verify-A's first T1 finished while a sabotage arm was
  installed in `src/op_param_lists.tcl` and had to be discarded and re-run under
  an md5 guard; Verify-C's first suite number was void for the same reason.
  **Sabotage must be run on a COPY, or under a lock.** Nothing in a transcript
  says the tree moved underneath a measurement. Before committing, `grep -c
  SABOTAGE src/op_param_lists.tcl` must be **0** on a reverted tree (1 if the
  patch is applied — the one legitimate mention in `_keys`' comment).
* **T1 is not reliably zero on this box.** A solo T1 during this write-up
  returned **3** counted failures, all `test_ase_optier_0963`
  (X1 `NORAW`, X2 `ZZNOTRUN`, plus the HARNESS line) on a tree **byte-identical
  to HEAD**; the suite then passed **94/94 in isolation**, and a second solo T1
  came back at **0 counted / 117 lines**, the baseline exactly. That is issue
  **1290** — filed as X7, so **widen 1290: it is the whole suite's simulator
  launch, not one check.** Two measurements, so do not carry the 3 forward.
* **Unchanged and still true:** pure Tcl, no build, no `Makefile.in` — both
  files are already installed (`grep -c op_param_lists src/Makefile` = 2);
  `xschem` sources `.tcl` at startup, so the change takes effect on the next
  launch. The grammar deadline is still free **until B5 writes the first flavor
  row** — but it is now the *only* thing left blocking it, so B5 must not start
  before this patch lands.

---

## B2d — the window's robustness  ✅ **LANDED, status E, 2026-09-04.** 1284 + 1282 (both parts) + 1283. *(the last of the B2a split; unblocks B4 and B5)*

**Done.** `src/rdw.tcl` and `tests/headless/test_rdw_window_1245.tcl` only. Pure
Tcl, no build, no `Makefile.in` (`grep -c rdw.tcl src/Makefile` = 2 before and
after). Suite **32 → 52 (`--nogui`)** and **42 → 62 (`:99`)**, additive; the
`src/rdw.tcl` hunks of `B2a-2_working_tree_REVERTED.patch` lifted verbatim, the
other six files in that patch never touched.

**⚠ THE THIRD SMALL ITEM TO LAND WHERE TWO BIG ONES LANDED NOTHING.** B2a and
B2a-2 each carried nine interlocked issues, went green everywhere, were refuted,
and reverted all nine. The split works: B2b, the 1291 driver fix, B2c's re-do and
now B2d have all landed. **Keep later items this size.**

### What a later item must know

* **`rdw::_line {tag text}` EXISTS, AND EVERY LINE APPENDED TO A BLOCK GOES
  THROUGH IT.** Not `[list $tag $text]`. `block_text` joins the entries with a
  newline, so one entry containing one is one block rendering as three different
  line counts — 4 entries, 5 lines of paste text, 7 lines in the Tk pane, all
  measured on one answer. The escape was `_state_sentence`'s echo of the
  backend's own `state`, and it survived the first pass of this very item: F20
  fences a newline in a value, a parameter name and a device name; F25 fences the
  unrecognised-state arm with the newline-free word `sideways`; the two crossed
  the class and missed at their intersection. **Row F29 fences the emit point
  now. A new `lappend out [list …]` is a defect.**
* **`rdw::dump_devpath` DOES NOT PUT `simtype` IN THE CTX — issue 1298, and it
  is aimed at B4 and B5.** The DD-5 analysis sentence is built by
  `_analysis_line`, whose gate returns `{}` when the ctx carries no `simtype`.
  `rdw::dump` sets it; the door does not, and the door is what B4 and B5 call.
  Measured: the same answer through a door-shaped ctx renders `mentions-dc = 0`,
  byte-identical to the pre-DD-5 defect. **Either fix 1298 (one line in the
  door) or set `simtype` yourself, and carry a row.**
* **`::rdw::sim` now selects between TWO refusals, not one.** B5 is the first
  thing that sets it. `_sim_refusal` asks `ase::backend_names` for membership
  *before* calling `ase::backend_hook`; do not parse the hook's error string.
  Row Q8 registers a second backend and **restores `::ase::backends`** — a row
  that forgets to reds Q5.
* **Two stale anchors, both re-read on this tree.** `int update_op()` is at
  **`save.c:3550`** and its op/dc guard at **`:3780`** — the crew brief's
  `save.c:1988` is stale. `ase::backend_hook`'s *"unknown hook"* error is at
  **`ase.tcl:553`**, not `:552` as the preserved patch's comment said; corrected
  in the shipped comment and in the suite.
* **Sabotage attribution shifted by one row, and it is the fix's doing.**
  `_value_text` → identity used to red F19 **and** F20; it now reds F19 only,
  because a value's newline is collapsed twice — once for the column-width
  computation, once at the emit point. F20's newline half is still fenced by
  `_oneline` and by `_line`. Do not "restore" the old attribution.
* **F16 locks bucket order, not raw-file order**, within a device: measured,
  then non-finite, then absent. It was true and written down nowhere. If a later
  item wants raw-file order, F16 is the row that will say so — change it
  deliberately, do not weaken it.

### Status E — the one question that is the user's

The shipped DD-5 sentence is **not** the ruling's quoted specimen, and
`src/save.c` is what moved it: `:1073` and `:1120` both rename a **multi-point
`Operating Point`** plot's `sim_type` to `dc`, so DD-5's *"these numbers come
from the `dc` analysis at its first point"* would tell a user who ran nothing but
an operating point that they ran a sweep. Row Q6 reproduces it on a real
three-point raw. **DD-5's decision — render it, name the analysis, option (a) —
is implemented unchanged; only the specimen wording is refused, and only on a
measurement.** Rule debts `1282_analysis_sentence_wording` and
`1284_four_new_sentences`; look debt for the five new on-screen sentences.

### Filed, not fixed

**1297** (`"a op analysis"`, the article) · **1298** (the door has no `simtype`)
· **1299** (four remaining edges of the answer-shape predicate: a device that
names nothing, `_nonfinite_text` still discarding its argument, minimum-arity
truncation, and `_named`'s `string trim` vs the seam's exact-empty).

---

## B4 — the keys and the two grammars  ✅ **LANDED as B4-3, status E, 2026-09-04.**  *(needed B3; unblocks B5)*
### Three attempts: B4 [F], B4-2 [F], **B4-3 [E] — landed.**

> **✅ THE FEATURE IS IN THE TREE.** B4-3 applied
> `doc/claude/op_param_batch/B4-2_working_tree_REVERTED.patch` whole and added
> **exactly three lines of code**, both fixes one-liners in `src/rdw.tcl`:
> `set land {} ; catch {set land [focus]}` + `if {$land ne {.rdw}} { return 0 }`
> at `:1215-1216` (issue **1306**) and `unset -nocomplain pick(suspended)` at
> `:1449` (issue **1305**, option a1). Pure Tcl — **no build, no `./configure`**;
> `grep -c rdw.tcl src/Makefile` = 2 before and after.
> Suites: window **58 → 76** `--nogui` / **68 → 86** on `:99`, keys suite **30**
> on `:99` (skips headless). Receipt:
> `doc/claude/op_param_batch/receipts/B4-3.md`.

### ⚠ WHAT B4-3 LEARNED THAT BINDS B5 AND EVERY LATER CREW

1. **⛔ ISSUE 1306's OWN "Recommended fix (option a)" CODE LINE IS REFUTED.**
   `if {[winfo exists .rdw] && [string match .rdw* [focus]]} { ... }` — printed
   in the issue *and* in B4-3's own brief — **does not fix the defect**: `.rdw*`
   matches the descendant `.rdw.p.t` as readily as the toplevel, so the click is
   still bounced. Measured by **three independent agents on both display arms**
   (`DET-B ... verdict=BOUNCED  [CAND-A ... 3/3 BOTH arms]`), and re-run as
   sabotage `SB-1306-BRIEFLINE` against the shipped tree → `RED:F3 RED:F4
   RED:K16`. **The test is EXACT EQUALITY against the toplevel.** The
   discriminator is the one the WM supplies: the map-time grant lands on the
   **toplevel**, every deliberate landing lands on a **child**. Row `K16` keeps
   `string match` out of that proc permanently. **The lesson is general: a
   recommended fix in an issue file is a hypothesis, not a measurement.**
2. **⚠ A `[focus]`-DEPENDENT FIXTURE IS NON-DETERMINISTIC ON BOTH ARMS.** The
   as-written 1306 repro went 5/5 green then 5/5 red on the **same unmodified
   tree** twenty minutes apart on WM-less Xvfb, and is **vacuous on `:99`**
   because the WM's grant has already spent the one-shot. Pointer parking does
   not cure it (5,5 and 960,540 both tried). **The cure is to assert the state
   you inherit and then RE-ARM IT BY HAND** (`set ::rdw::focus_pending 1`) before
   the gesture. Deterministic on both arms after that: BOUNCED 5/5 unfixed, KEPT
   4/4 fixed. This is B4's `V8` failure in a third costume — *ordering inside a
   suite is part of the fixture*, and so is any flag the environment might spend
   for you.
3. **⚠ A STRUCTURAL ROW THAT MATCHES A SEQUENCE **NAME** PROVES NOTHING.** Old
   row `K14` stayed green under `bind $cv <B1-Motion> {}` — a bind that
   **destroys** rather than seizes — because `rw_has` is a substring test.
   Hardened `K14` now asserts, per sequence: a **non-empty script**, a
   write-back **from the stored predecessor**, and the seize/release **pairing**.
   The pairing leg is load-bearing, not decoration: all four of `.drw`'s
   predecessors are the **empty string**, so `SB-K14-CROSSED` (swap the
   Escape/B1-Motion write-backs) leaves the whole behavioural keys suite at
   `ALL PASS (30)` and only `K14` sees it. **Assert content, never a mention.**
4. **⚠ THE KEYS SUITE IS SOLO-RUN EVIDENCE, AND SO IS THE TREE.** B4-3's own
   Verify-A and Verify-C both recorded ~25% spurious reds that turned out to be
   **another crew agent running sabotage directly on `src/rdw.tcl` in the shared
   working tree**. Hard rule 3 exists for this. **Take a before/after `md5sum`
   of every tracked file you measure, per run**, and discard any run whose
   signature moved. Both agents did, and both got zero flake once isolated.
5. **⚠ TWO NEW ISSUES FILED, both measured, neither fixed, both affecting B5's
   ground.** **1308** — the Results window now *holds* the keyboard (correct,
   and the point of 1306) and **nothing on it ends the command mode**: `ESC` and
   a bare `2` are bound on the **canvas**, `.rdw` has neither. **1309** — a list
   key pressed during a suspended descend leaves the **descend** unterminable,
   because the seize `break`s both of `hi_descend_pick_arm`'s terminals; after
   it, `cmdmode::suspend_all` returns 0 forever, so **no later descend suspends
   any command mode**. Both are **identical on the pre-fix arm** — B4-3 neither
   causes nor fixes them. **B5 adds buttons to this window: if any of them takes
   focus, read 1308 first.**
6. **⚠ 1305's FILED TRANSCRIPT IS NOT USER-REACHABLE AS FILED.** The double
   seize needs `cmdmode::resume_all` to run while the mode is live, and every
   real terminal is eaten by the seize itself (that is issue 1309). Row `D3`
   calls `resume_all` directly and says so. **The fix is defence-in-depth, not
   the unrecoverable session-wide seize the issue describes** — do not
   over-credit it, and do not assume the class is closed.
7. **The `%W` first cut in `rdw::_focus_handback` is unfenced dead weight.**
   Deleting it on a copy left both suites fully green. Harmless (the landing
   test subsumes it), but `K15` fences only that the binding *passes* `%W`, not
   that anything consults it.

### The B4-2 table below is now HISTORY — kept because two of its three rows are still live

`1306` and `1305` are **fixed** (see above). **`1307` is still open** and gained
a second half from B4-3: option a1's stated cost is that a descend landing on a
**different** canvas never rehomes the mode. Recorded on 1307, **no new number
minted**.

### B4-2 (2026-09-04) — it closed all five of B4's holes and was refuted on three NEW ones

B4-2 did what it was asked. Every one of B4's five holes was fixed and fenced
red-before-green; T1 zero, T2 6/6, window suite **58 → 74** headless / **68 →
84** on `:99`, a restored **27**-check keys suite, a full audit
**367/12/0/2 of 381 → 368/12/0/2 of 382** whose non-PASS **name** diff was one
line (`> PASS|test_rdw_keys_1245`) with all 43 failing-check detail lines
byte-identical, and an eight-variant sabotage matrix run on copies.

**Its adversary then refuted the central claim on three counts, and the write-up
agent reproduced all three first-hand before reverting.** Full record:
`doc/claude/op_param_batch/receipts/B4-2.md`.

| # | issue | what is wrong |
|---|---|---|
| **1** | **1306** | **THE FOCUS HAND-BACK BOUNCES A DELIBERATE CLICK INTO THE TEXT PANE.** `rdw::_focus_handback`'s `%W eq .rdw` guard is reasoned from bindtags; the mechanism is X's **ancestor `FocusIn` chain**, which delivers `%W = .rdw` (detail `NotifyNonlinearVirtual`) when focus crosses into `.rdw.p.t`. Measured, both halves in one process on a WM-less server: a real first-of-session dump leaves `focus_pending 1`, and the user's next click into the pane is bounced to the canvas. The pane is what the feature exists for — the user's own use is pasting dumps into review documents. The code's stated cost says the bounce hits *"the window's FRAME — not its text"*; it hits the text. |
| **2** | **1305** | **A KEY PRESSED WHILE A DESCEND HAS THE MODE SUSPENDED SEIZES THE CANVAS FOR THE SESSION.** `rdw::pick_start` falls through into `_pick_seize` without clearing `pick(suspended)`, so `resume_all` seizes a second time and latches **the seize's own scripts** as predecessors; `ESC` restores them and a second `ESC` returns 0. Every click dumps, nothing can be selected again, the rubber band is dead — **the inverse of the user's own *"clicking will not change selected set"***. The control names the cause: `ase::ui::select_on_design` runs the same sequence clean because it **ends the previous mode first**, which `rdw::pick_start`'s comment argues against copying. |
| **3** | **1307** | **A NEW WINDOW OR TAB INHERITS A LIVE SEIZE, and this one is TRUE OF THE TREE TODAY.** `clone_canvas_bindings` (`xinit.c:2121`, `:2337`) copies `.drw`'s bindings onto every new canvas; the mode's end cleans only the canvas it seized. `cmdmode.tcl:44-50` documents the hazard and its invariant covers **only the descend chain** — `File > New Window` has no suspend site. Measured against **shipped ASE with no B4-2 code loaded**. **Not B4-3's to fix** (the door is `cmdmode::suspend_all` before `schematic_in_new_window`), but B4-3 must not widen it silently. |

**⚠ 1304's fourth sequence WIDENS 1305 and 1307 both.** Once
`<B1-Motion> {break}` is in the seized set it joins whatever leaks, so 1304's
*transient* harm becomes *permanent* on a canvas nobody can un-seize. **Land
1305's fix with 1304's, not after it.**

### What B4-2 proved works, and B4-3 must not re-litigate

* **1303's unsnapped default** — `rdw::pick_click` reads `xschem get
  mousex`/`mousey` with **no** grid fallback (the fallback *is* the defect) and
  refuses through the one CIW channel instead. `grep -c 'mousex_snap'
  src/rdw.tcl` = 0, comments included.
* **1304's fourth sequence** — measured: an 8-step drag with the mode live
  leaves `ui_state 0`, `lastsel 0`, `selection` empty mid-drag, after the
  release and after `ESC`, against a pre-fix `ui_state 24` / `lastsel 20`. And a
  plain no-button `<Motion>` still moves `xschem get mousex`, so the seize
  blinds C only while Button 1 is held.
* **Hole 5's ordering** — `rdw::key` resolves the selection before anything
  moves. Verify-C attacked all three of these and failed.
* **The `cadence_style_rc` bind block and its `%s & 0x4c` guard** — byte-identical
  to B4's, twice survived sabotage. **Do not redesign.**

### Three more things B4-2 measured that B4-3 must carry

* **⚠ ROW K14 CANNOT TELL A SEIZING BIND FROM A DESTROYING ONE.** Sabotage
  `SB-NO-MOTION-SEIZE` turned `bind <B1-Motion> {break}` into
  `bind <B1-Motion> {}` — which **destroys** the binding, i.e. the pre-fix
  behaviour — and K14 **stayed green on both arms**, because the sequence name
  still appears twice in the body. The exposure is the **headless** arm, where
  the keys suite self-skips and K14 is the only fence for 1304. **Fence a
  non-empty script, not a mention.** Recorded on issue 1304.
* **⚠ `rdw::key` with nothing selected, when `pick_start` returns 0** (no Tk, or
  no `current_win_path`), still moves `::rdw::listkind` and reports nothing —
  hole 5's shape on the branch its fix did not cover.
* **⚠ THE KEYS SUITE IS SOLO-RUN EVIDENCE.** Verify-C measured
  `2 FAILED (25 passed)` with another agent's `test_ase_plot.tcl` sharing `:99`,
  and `ALL PASS (27)` on four subsequent solo runs. A suite whose subject is
  keyboard focus is perturbable by any other X client on the display.
* **⚠ A ROW FOR 1306 CANNOT RUN ON `:99`/openbox AS THE SUITES ARE WRITTEN.**
  The WM consumes the one-shot flag before any row can observe it — which is
  exactly why 27 green checks and eight sabotage variants missed it. Arm the
  flag deliberately, or run that row WM-less (`AUDIT_WM=none`).

### The five holes of the FIRST attempt (B4), all now FIXED in the preserved patch — kept for the record

#### What B4 produced, and why it was reverted anyway

Everything the item was asked for, it produced, and every tier was clean:

* the four guarded binds in `src/cadence_style_rc`, both grammars, the command
  mode, `cmdmode::register`, key 4, the one-line refusals;
* window suite **56 → 68** headless / **66 → 78** on `:99`, plus a new
  **21**-check `tests/headless/test_rdw_keys_1245.tcl` on `:99`;
* T1 at **zero**, T2 6/6, `test_op_annot` **485/492** and
  `test_annot_declutter_1244` **134** unmoved;
* audit **368 pass / 12 fail / 0 crash / 2 skip of 382**, non-PASS diff **empty
  by name and verdict**, whole-transcript diff **one line** (the SUMMARY);
* an **eight-variant** sabotage matrix, trustworthy, every predicted red
  appearing on the arm predicted.

**It was reverted anyway.** The adversary refuted the central claim on three
counts and the write-up agent **reproduced the sharpest one first-hand** before
deciding. Two of the three are defects in *shipped* code that B4 merely
inherited by copying the ASE precedent — which is why they are issue files and
not just patch holes.

#### The five holes that forced B4's revert — ALL FIVE ARE FIXED IN `B4-2_working_tree_REVERTED.patch`

| # | Where | What is wrong, and who measured it |
|---|---|---|
| **1** | **issue 1303** — `rdw::pick_click`'s coordinate default | **THE WINDOW CAN NAME A DEVICE THE USER DID NOT CLICK.** `scheduler.c` exposes only `mousex_snap`/`mousey_snap`; every C click path reads the **unsnapped** `xctx->mousex/mousey`. Reproduced by the write-up agent on the shipped `cmos_inv.sch`: exact `175.175 -199.612` → `M1`, snapped `180 -200` → `R1`. Swept over every instance bbox: **6.4% miss, 0.5% wrong device**, silently. This is invariant **I3**'s plausible-wrong-answer class one object further out. **Fix:** issue 1303 option (a) — an unsnapped accessor in `scheduler.c`. **DONE by the driver in `0ce85dda`**, and B4-2 consumed it: `xschem get mousex`/`mousey`, no grid fallback. |
| **2** | **issue 1304** — the seize's missing `<B1-Motion>` | **A DRIFTED CLICK CHANGES THE SELECTION — the user's own headline requirement.** The mode seizes press, release and Escape and **not** motion, so C keeps getting Button1Mask motion and starts a rubber band it never terminates. Measured: 1 px of drift leaves `ui_state 16` alive **after `ESC`**; an eight-step drag selects **13 objects**; the no-mode control terminates at `ui_state 8`. **Fix:** seize `<B1-Motion>` with `break` and hand it back in the same released-latch proc. Live in `ase_window.tcl` too. |
| **3** | the first dump of a session | **`ESC` CANNOT LEAVE THE MODE ON FIRST USE.** `rdw::open` ends in `focus .rdw`; `rdw::_focus_canvas`'s `focus -force` then loses the race against the WM focusing the newly **mapped** toplevel. Measured on a fresh session with `.rdw` not yet built: after the first click `[focus]` is `.rdw` and a real `<Key-Escape>` does **not** run `rdw::pick_end` — the mode stays live and seized. Second dump onward, focus is `.drw` and `ESC` works. **Row V8 passed anyway**, because the row before it pressed key 4, which maps `.rdw` by a different path. **Fix:** re-force after `update idletasks`, or do not `focus .rdw` from `rdw::open` while a pick mode is live — and write the row so it maps `.rdw` **inside itself**. |
| **4** | `rdw::show`, and the suite | **A HOLE NO VARIANT WAS PREDICTED TO FIND.** Deleting `rdw::open` from `rdw::show` reds **nothing** — 68/78/21 all green — while a user pressing `1` with a device selected in a fresh session sees **nothing at all** and the block lands silently in the store (measured: `winfo exists .rdw` 0, blocks 1, pane absent). No row in either suite ever presses a dump key with `.rdw` absent. **Fix:** one row — destroy `.rdw`, select one instance, press key 1, assert the window exists *and* the pane names the device. |
| **5** | `rdw::key`, the refused path | **A REFUSED KEY STILL MOVES THE LIST IDENTITY.** `rdw::key` calls `rdw::set_list` **before** resolving the selection, so pressing `2` with three objects selected refuses in the CIW *and* silently changes `::rdw::listkind` to `summary` and re-greys the buttons. Unspecified, unfenced, visible. **Fix:** resolve first, set the list only on the path that dumps — or rule that the list identity is a mode setting and say so on screen. |

#### What B4 learned that binds every later step

* **⚠ ~~`xschem get mousex` DOES NOT EXIST~~ — IT DOES NOW, since `0ce85dda`.**
  `xschem get mousex` / `mousey` answer the UNSNAPPED schematic coordinates
  (`scheduler.c:5047`, `:5051`) beside the snapped pair at `:5055`/`:5059`, and
  window-suite rows **P1**/**P2** fence both. **The rule that still binds B5 and
  every future canvas pick: never resolve a click through `mousex_snap`.** The
  snapped pair is for PLACING geometry. Measured on the shipped `cmos_inv.sch`,
  one pixel apart: `175.175 -199.612 → M1`, `180 -200 → R1`. And note a
  synthetic `<Motion>` cannot carry that pair (it lands at `173.959/-200.828`,
  where both pairs answer `M1`), so an event-only row is **vacuous** for 1303.
* **⚠ A PICK FIXTURE BUILT FROM BBOX CENTRES CANNOT SEE A COORDINATE DEFECT.**
  `bbox_centre` was adopted (correctly) so the A3 declutter numbers would not be
  transcribed — and a centre snaps safely, so the whole 21-check suite was blind
  to hole 1. Drive at least one pick at a point measured to **straddle** an edge.
* **⚠ A ROW THAT DEPENDS ON STATE THE PREVIOUS ROW LEFT BEHIND IS NOT A FENCE.**
  Holes 3 and 4 both hid behind `.rdw` having been mapped by an earlier section.
  A row about first-use must construct first-use inside itself.
* **The batch's lesson, for the sixth consecutive item: a green count is a
  statement about the fence, not about the code.** B4 was green at 68/78/21
  with eight sabotage variants, every predicted red appearing, and still carried
  five defects — three of them on the item's own Accept cell.
* **`logic_set`'s displacement was never the risk.** It was measured
  (`grep -rn logic_set tests/` returns nothing), guarded (`%s & 0x4c`, the
  tree's own `hi_descend_keybind_script` shape), and the guard survived its own
  sabotage variant with `Ctrl-1`/`Ctrl-3`/`Alt-2` all intact. **Keep that part
  of the patch unchanged.**
* **Issue 1301 is now measured and UNFENCED** — its pinning row went away with
  the reverted suite. The cadence profile's own `Ctrl-x` descend still never
  suspends a command mode, and ASE Direct Plot has it too.


> **⚠ FROM A6 (2026-09-02).** A6-c closed **every** `symbol_bbox()` door by
> syncing inside the callee, so 1252/1260 are done. **The instruction to call
> `xschem update_all_sym_bboxes` before B4's first pick still stands**, for a new
> reason: `xschem annotate_op` and `xschem raw clear` move the gate's answer
> while calling `symbol_bbox()` **not at all** (issue **1266**, driven both
> directions — a click lands on blank canvas one way and misses visible text the
> other). Carry a row that reds if the refresh is removed.

**Do.** Bind bare `1`/`2`/`3`/`4` in `src/cadence_style_rc` with `break` (D-2).
**noun-verb**: one instance selected → dump it. **verb-noun**: nothing selected →
seize `<ButtonPress-1>` and `<Key-Escape>` like ASE Direct Plot does, resolve
each click with `xschem instance_at` so **the selection never changes**, and
`cmdmode::register` so a descend can suspend and resume it. Refuse in one short
CIW line for >1 selected, or nothing available.

**⚠ What it costs.** `logic_set` has no menu entry and no second accelerator, so
inside the cadence profile these keys are its only door. `xschem logic_set n`
stays scriptable. Say so in the commit.

**⚠ THE CLICK TARGET MOVED UNDER YOU — item A3, 2026-09-02.** With annotation +
declutter on, a decluttered device's **with-text** bbox shrinks to what is still
drawn, and `find_closest_element()` gates candidates on exactly that box. Measured
on `cmos_inv` at mask 9: `M1`'s `x2` 177.376 → 157.433, and
`xschem instance_at <x> -170` stops answering `M1` at x = 160/170/175 while
130/140/150 still answer. Descriptor-less instances do not move. Two consequences
for this item: **(a)** a pick fixture written against pre-A3 coordinates will miss;
**(b)** the gate behind that box is refreshed at only four sites (issue **1252**),
so **call `xschem update_all_sym_bboxes` before the first pick** or the pick reads
a stale overlay epoch and answers over blank canvas. `xschem instance_at` itself is
still the right verb — read-only, selects nothing.

**⚠ AND ITEM A5 MADE (b) SHARPER, NOT SOFTER — issue 1260.** A5-c fixed the
`recompute_inst_bbox` door, but **`xschem setprop instance` and `xschem
move_instance … nodraw` still write the click box from a stale gate**, measured
after the fix: the frame on screen showed `MZ1 VCW=1u PD {zid =} {zgm =}` while
`instance_at 430 -245` answered **empty** over it, and one
`update_all_sym_bboxes` then answered `MZ1`. A5-a *widened* this — before it, a
label-only block still opened the gate, so a rename over a dead raw flipped
nothing; now an ordinary property edit is enough. **So: refresh before the first
pick, and carry a row that reds if the refresh is dropped.** Also note the mask
half of the gate is still unsynced at `recompute_inst_bbox` (1260 part 3): a bare
`set ::annot_show` makes the two doors answer opposite picks. Write the mask
through `xschem set annot_show`, never a bare `set`.

> **⚠ FROM B2d (2026-09-04).** You will call `rdw::dump_devpath`, and it does
> **not** put `simtype` in the ctx — `rdw::dump` does. `_analysis_line`'s gate
> then returns `{}` and ruling DD-5's sentence silently disappears, putting a DC
> sweep back under an operating-point heading (issue **1298**, measured, one-line
> fix recommended). Fix 1298 or set `simtype` yourself, and carry a row. Also:
> every line you append to a block goes through `rdw::_line`, never
> `[list $tag $text]` — row **F29**.

**Files.** `src/cadence_style_rc` · `src/rdw.tcl` · rows in B3's suite

**Accept.** Both grammars. Escape leaves the mode with bindings restored. A
descend mid-mode suspends and resumes on the **descended** canvas. Clicking in
verb-noun mode leaves `xschem selection` byte-identical. Each refusal is one
line.

---

## B5 — the button column and the two scope dialogs  *(needs B2, B3, and see B2a)*

> **✅ SUPERSEDED 2026-09-04 — B4 LANDED as B4-3. The keys ARE in the tree.**
> Bare `1`/`2`/`3`/`4` on the canvas in the cadence profile (ruling **D-2**),
> both grammars, the verb-noun command mode, and the focus hand-back. A key now
> puts a block in the window, so you can drive your buttons against a populated
> pane. **Do not retype any of it and do not apply either preserved patch — they
> are history.** `rdw::dump <instname>` remains the seam's only door and still
> fills `sim` **and** `simtype` itself (issue 1298); build a ctx by hand and you
> lose ruling **DD-5**'s analysis sentence.
>
> **⚠ FOUR THINGS FROM B4-3 THAT REACH YOUR OWN CODE:**
>
> * **Issue 1308 (new, filed not fixed): the window now HOLDS the keyboard and
>   nothing on it ENDS the command mode.** `ESC` and the four list keys are
>   bound on the **canvas**; `.rdw` has none of them. **You are adding buttons
>   to this window.** Tk buttons do not take focus on X, which is the only
>   reason the button column currently hands the keyboard back — an entry, a
>   listbox or a `-takefocus 1` button of yours **changes that**, and it changes
>   it into 1308's stuck state. Read the issue before you place a focusable
>   widget.
> * **Issue 1309 (new, filed not fixed):** a list key during a suspended descend
>   leaves the descend unterminable and `cmdmode::suspend_all` stuck at 0
>   thereafter. If any dialog of yours suspends a command mode, it inherits this.
> * **Issue 1303 is FIXED and consumed** — `xschem get mousex` / `mousey`
>   (`scheduler.c:5047`, `:5051`) are the **unsnapped** pair and are what
>   `rdw::pick_click` defaults from, with **no** grid fallback (the fallback
>   *is* the defect: measured `175.175 -199.612 → M1` vs `180 -200 → R1`, 0.5%
>   of a whole-sheet sweep naming a different device silently). **Any dialog of
>   yours that resolves a canvas position must read the same pair.** Row `K13`
>   reds if the snapped spelling reappears anywhere, code or comment.
> * **`xschem instance_at`** (`scheduler.c:6972` — *not* `6919`, the older
>   anchor is stale by 53 lines) is the read-only pick and selects nothing.
>   **Never `select_at`.** And call `xschem update_all_sym_bboxes` before a
>   pick: `findnet.c:461` gates on the **cached** instance bbox (issues 1266,
>   1260). Rows `P1`/`P2` red if that refresh is removed.

> **⚠ FROM B2d (2026-09-04), AND ONE BLOCKER IS GONE.** B2a's window work
> **landed** — issues 1284, 1282 (both parts) and 1283 are fixed, suite 52/62.
> You are the first thing that sets `::rdw::sim`, and it now chooses between TWO
> refusals: *"no simulator named X is registered"* and *"X is registered but
> declares no `op_param_set` hook"*. `rdw::_sim_refusal` asks
> `ase::backend_names` for membership before calling `ase::backend_hook` — do not
> parse the hook's error string. A row that registers a second backend **must
> restore `::ase::backends`**, or row Q5 reds. Issue **1298** applies to you too
> if you call `dump_devpath` with a ctx of your own.

> **⚠ THREE BLOCKERS. B2a AND B2a-2 BOTH ATTEMPTED THIS GROUND AND BOTH WERE
> REVERTED (2026-09-03) — apply
> `doc/claude/op_param_batch/B2a-2_working_tree_REVERTED.patch` and fix the four
> holes in the B2a-2 section above before starting here.**
>
> **⚠ AND THE SETTINGS FILE IS NOW THE ONLY THING BETWEEN YOU AND THE GRAMMAR
> DEADLINE.** Item **B2c** re-did 1276/1277/1281/1288 on the driver's settled
> designs DD-7 and DD-8, went green everywhere, and was **reverted a third
> time** on issue **1294** — one named hole in one proc. Its patch,
> `doc/claude/op_param_batch/B2c_working_tree_REVERTED.patch`, is small, carries
> **no provenance machinery and no glob ranking**, and applies clean to
> `adc08706`. **B5 writes the first flavor row, and the moment it does, every
> settings file in the wild is v1 and the grammar bump becomes a migration.** So
> that patch must land — apply it, fix 1294 (`_parse_line` must call `_row_id`),
> and decide **1296** — *before* you write a file.
> 0. ~~**Issue 1289 needs a RULING before Delete ships.**~~ **RULED DD-9 and
>    LANDED by item B2b, 2026-09-03.** `op_annot::text` builds `vars` over
>    `params` and draws over `shown`, so a derived row keeps its value when its
>    operand is merely hidden. (Note the issue's *"IHP registers exactly such
>    rows"* was **false** — no shipped descriptor carries `derived` at all; the
>    fixture is built from the recovery recipe under **I5**.)
> **AND THE TWO ALREADY KNOWN:**
> 1. ~~**Issue 1285 is ANSWERED by ruling DD-6 and IMPLEMENTED in the B2a-2
>    patch, but not landed.**~~ **LANDED by item B2b**, with both of the wrong
>    points fixed the way the DD-6 amendment requires: `shown` is derived by
>    **filtering** the list written to `params` (so the subset holds by
>    construction, whether or not **1288** is ever fixed) and a malformed `shown`
>    is treated as **absent**, never raising. Do not rewrite either.
>    **⚠ BUT B2b LEFT YOU TWO OF ITS OWN, BOTH IN THE BUTTONS YOU ARE ABOUT TO
>    BUILD:** issue **1291** — `apply` **raises** on a malformed registered
>    `params` (`_save_set`/`_show_set` → `effective` → `seed`, the registered
>    string verbatim); HEAD returned `rc=0`. You are its first caller: settle it
>    before wiring Apply. And issue **1292** — nothing ever removes `shown`, so
>    **Reset/Defaults cannot be built on `reset` + `apply`**; the sheet stays
>    narrowed for the session. Both are latent only because nothing calls
>    `apply` yet.
>    **⚠ AND ONE QUESTION IS THE USER'S, NOT YOURS:** an **empty** `shown` draws
>    no `params` rows, so deleting the last row makes the whole OP block vanish
>    *and* drops the device out of the declutter (`actions.c:1764` →
>    `annot_instance_annotated()` → `annot_block_has_value()` reads the rendered
>    block). Recorded as rule debt `1285_empty_display_key`; row **D10** fences
>    whichever way it is ruled.
> 2. **You are the first caller of `write_conf` and of the flavor-row grammar.**
>    Both are unfixed at `825cd3bd`: `write_conf` reports success while writing
>    somewhere else (**1276**) and flattens the two tiers (**1281**), and a
>    flavor row still carries **no class** (**1277**), with precedence falling to
>    `lsort`. **The moment B5 writes the first flavor row the grammar change
>    stops being an edit and becomes a migration** — so land B2a's re-do first.

**Do.** Up/Down reorder in all three lists. Delete and Add per the spec's table,
each raising a **scope dialog** — *this device flavor only* vs *every device of
this class* — which writes a `match` glob or a class entry respectively. Save
writes the settings file.

**⚠ Modal dialogs hang headless suites** (issue 0803). The dialog needs a
test-drivable path in the **first** commit, not retrofitted.

**Files.** `src/rdw.tcl` · `src/op_param_lists.tcl` · rows in B2's and B3's suites

**Accept.** Reorder persists through Save/reload. Narrow scope touches one
flavor and leaves siblings alone; broad scope moves the class. Delete is greyed
on list 3. Add from list 3 asks *which* list. Every dialog is driven headlessly.

**⚠ B5 STARTS BY PAYING B2's SIX (see "What B2 SHIPPED" above).** Five of the
six land on this item's own buttons and none is fenced by B2's suite:
**1276** (Save reports success when the file went elsewhere), **1279** (Save
cannot reach a type the class map does not name — the list is stored and
invisible), **1281** (Save exports the author's personal global settings into
the team's file), **1277** (the scope dialog's flavor glob wins by `lsort` order
and carries no class — this one is a **grammar** change, so it must be settled
*before* the first flavor entry is written, i.e. before B5's first commit), and
**1280** (Delete trims the deck's `.save` cards, blanking the summary list —
and its fix carries a **user question**: does Delete stop *drawing*, or stop
*saving*?). Fix them in `src/op_param_lists.tcl`, not in the button column.

---

## What A1 learned that every later item needs

* **Issue numbers come from `doc/claude/issues/NUMBERING.md` and nowhere else.**
  The crew brief's "number from 0619 upward" and "hard ceiling 0499" are **both
  false on this tree** — `0619`…`0629` exist as files. **The next free number is
  1249**; 1244 and 1245 stay reserved as feature numbers with no files.
* **The default `xschemrc` does NOT source `src/cadence_style_rc`.** A bare
  `./src/xschem --pipe --script t.tcl` has no `::cadence` namespace at all and
  every `.drw` chord bind is the empty string. Any suite or probe that touches a
  cadence chord must `source .../src/cadence_style_rc` first — this cost A1's
  measure pass a whole probe run.
* **`full_audit.sh` is not edited to register a suite.** The glob at `:393` is
  the registration. Every new suite moves the denominator, so **the baseline
  diff is by name and status** — A1 went 377 → 378 and its +1 is its own suite.
* **The item's own suite is not the tier list.** A1's 36 checks were green while
  `run_regression.tcl` was red on a *structural* contract in a file A1 does not
  own (`test_op_annot.tcl` row A11-2: every line in `utils/annot_mode.tcl` that
  writes `xschem statusmsg -hold` must name `_annot_fit` on the **same line**).
  Run T1 solo, every time, and read it.
* **`callback.c`'s layer-select arm is `:7470 case '6':` / `:7474
  if(state==ControlMask)`** — the brief's `callback.c:7272` is a mouse
  select-by-area and is wrong.
* **`event generate` is fine for Tk-side chords.**
  `test_wave_sigbrowser_i12.tcl:1141`'s warning that `<Control-Alt-Key-…>` "does
  not work under `event generate`" is true only for a **C-side** handler reading
  the numeric `%s` (a synthesised Alt sets the virtual META bit, not Mod1). A Tk
  `bind` pattern matches fine — A1 confirmed it both ways, including with a
  physical `-state 12`.
* **Nothing installs `utils/`** (issue **0458**, pre-existing and open), yet the
  installed `cadence_style_rc` sources twelve helpers from it. In-tree
  everything passes because `XSCHEM_SHAREDIR` resolves to `src/`. Any item that
  adds a `src/*.tcl` still owes `Makefile.in` ×2 and a `./configure` (issue
  0424); an item that adds a `utils/*.tcl` inherits 0458.

---

## Verification, every item

* Its own suite green, registered in `tests/headless/full_audit.sh`.
* A **name+status diff** against the baseline below — never a count.
* `cd tests && tclsh run_regression.tcl`, **solo** (issue 0990).
* A `look` debt for anything only an eyeball can judge. Never report a pixel
  deliverable done on a green suite.

**Baseline**, taken at `9ef4a37e` on the dev display: **364 pass / 11 fail /
0 crash-timeout / 2 skip of 377**, the eleven being `test_altf5_ciw`,
`test_ase_core`, `test_ase_window`, `test_cadence_drag`, `test_cosim_golden_e2e`,
`test_lib_manager_gui`, `test_lib_sweep`, `test_rotate_stretch_short_0104`,
`test_selflog_output`, `test_wave_sigbrowser_0312`, `test_wave_sigbrowser_keys`.
No new red names. A red going green is fine and gets recorded.
