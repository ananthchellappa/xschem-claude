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

---

## A6 — close the value gate and the last bbox doors  *(needs A5)*

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

## A7 — the wording follows the gate, and the guards stop lying  *(needs A6)*

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

---

## B1 — the backend seam  *(no dependencies)*

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

## B2 — the list store and the settings file  *(no dependencies)*

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

## B3 — the window  *(no dependencies)*

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

## B4 — the keys and the two grammars  *(needs B3)*

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

**Files.** `src/cadence_style_rc` · `src/rdw.tcl` · rows in B3's suite

**Accept.** Both grammars. Escape leaves the mode with bindings restored. A
descend mid-mode suspends and resumes on the **descended** canvas. Clicking in
verb-noun mode leaves `xschem selection` byte-identical. Each refusal is one
line.

---

## B5 — the button column and the two scope dialogs  *(needs B2, B3)*

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
