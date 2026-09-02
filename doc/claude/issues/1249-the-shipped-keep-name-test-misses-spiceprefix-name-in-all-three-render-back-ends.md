# 1249 — the shipped keep-name test misses `@spiceprefix@name`, in all three render back ends

Status: **FIXED** by item A3, 2026-09-02 (see the bottom of this file) ·
Branch: `fluid-editing`
Related: **1244**, item A3 of `doc/claude/op_param_batch/PLAN.md` (which owns all
three files and is the natural home, but is **not** assigned this)

## The defect

`hide_symbols` levels 1 and 2 suppress symbol text, and each render back end
carries a hand-written exemption so a device keeps its NAME. All three copies
are byte-identical and all three compare against two spellings only:

* `src/draw.c:873`
* `src/svgdraw.c:928`
* `src/psprint.c:1210`

```c
if( hide && text.txt_ptr && strcmp(text.txt_ptr,"@symname") && strcmp(text.txt_ptr,"@name") ) continue;
```

There is a **third** shipped name spelling, `@spiceprefix@name`, and it is not
in the list. So screen, SVG and PDF all lose those names together.

## The measurement (behavioural, not a code read)

Fixture `xschem_libs_newsym/examples/cmos_inv/schematic/cmos_inv.sch`, warmed SVG
export at viewport `{2000 1600 0 -520 420 -20}`, `src/cadence_style_rc` sourced:

```
hide_symbols=0 -> ... WP/LLP/1 M2 D {vgs= - } {vds= - } WN/LLN/1 M1 D ... R1 10 m=1 D A V1 Vmeas @name @symname
hide_symbols=2 -> R1 V1 Vmeas @name @symname
```

`R1`, `V1`, `Vmeas` (whose symbols carry `T {@name}`) keep their names.
`M1` and `M2` — `nmos4.sym` / `pmos4.sym`, whose name text is
`T {@spiceprefix@name}` (`xschem_library/devices/nmos4.sym:50`) — **lose theirs**.

## Blast radius, censused

Re-derived 2026-09-02 with a brace-balanced record scanner over `git ls-files`
(not a line grep), by item A2's implement pass:

| spelling | `.sym` records | `.sch` records |
|---|---|---|
| `@name` | 3,165 | 150 |
| `@symname` | 1,386 | 41 |
| **`@spiceprefix@name`** | **81** | **0** |

(3,686 `.sym` files / 47,334 `T` records; 990 `.sch` files / 4,009 `T` records.)

The 81 are gf180mcuD's whole FET family (57), the generic
`xschem_library/devices/` set (6: `nmos4`, `pmos4`, `nmos4_depl`, `rnmos4`,
`njfet`, `pjfet`) and the three OA/newsym/tests mirrors (6 each).

## Why item A2 filed it and did not fix it

Item A2's brief names it explicitly — *"draw.c:873's shipped keep-name test
MISSES it … Do NOT copy draw.c:873, it carries a measured bug"* — and A2's Files
cell is `src/xschem.h`, `src/actions.c` and its own suite. A2 did the opposite of
copying it: `annot_name_token()` (`src/actions.c`) compares against all **three**
spellings.

## It is pinned by a test, so the fix flips a row

`tests/headless/test_annot_declutter_1244.tcl` row **N14**, labelled
`1249 PINNED — WHOEVER FIXES 1249 FLIPS THIS ROW`, asserts the defect
behaviourally: at `hide_symbols=2` the `@name` devices keep their names and the
`@spiceprefix@name` FETs do not. It is the only evidence of this bug anywhere in
the tree. Fixing 1249 must change that row's expectation to `{1 1 1 1 1}`.

## Recommended repair (not taken here)

One predicate, three call sites — the same shape the S7 refactor gave
`text_hidden()`. `annot_name_token()` in `src/actions.c` **is already that
predicate**, is already whole-string and already knows all three spellings, so
the repair is to export it and replace the three `strcmp` pairs with a call.
That keeps one builder rather than four (invariant I1). It belongs to whoever
owns `draw.c` / `svgdraw.c` / `psprint.c` next — item A3 touches all three.

---

## FIXED by item A3, 2026-09-02

**BEFORE**, re-measured by item A3's measure agent — three byte-identical copies,
each sitting immediately *after* its `text_hidden()` call, so the rung and the
keep-name test are neighbours and were edited together:

```
src/draw.c:873:      if( hide && text.txt_ptr && strcmp(text.txt_ptr, "@symname") && strcmp(text.txt_ptr, "@name") ) continue;
src/svgdraw.c:928:   if( hide && text.txt_ptr && strcmp(text.txt_ptr, "@symname") && strcmp(text.txt_ptr, "@name") ) continue;
src/psprint.c:1210:  if( hide && text.txt_ptr && strcmp(text.txt_ptr, "@symname") && strcmp(text.txt_ptr, "@name") ) continue;

test_annot_declutter_1244.tcl:1007:   $N14_GOT {1 1 1 0 0}      <- over {R1 V1 Vmeas M1 M2}
ok:   N14 1249 PINNED: at hide_symbols=2 the at-name devices keep their names and
      the spiceprefix-at-name FETs lose theirs
```

**AFTER** — this file's own recommended repair, taken as recommended:
`annot_name_token()` (`src/actions.c`) loses its `static` and is declared in
`src/xschem.h`; all three copies become one call:

```c
if( hide && text.txt_ptr && !annot_name_token(text.txt_ptr) ) continue;
```

Four copies of one predicate are now one builder (invariant **I1**). Row **N14**
was flipped to `{1 1 1 1 1}` **deliberately**, with a comment saying so — it was
the only evidence of the bug anywhere in the tree — and row **A18** carries the
same claim under the A-section's own fixture. Row **A19** asserts structurally
that zero `strcmp(…,"@symname")` keep-name pairs remain in the three files.

**Rejected alternative**, recorded because it is cheaper and was genuinely close:
`!(text.flags & TEXT_ANNOT_NAME)` — one int test per text per instance per frame
instead of a trim plus three `strncmp`s, resting on the *same* single builder, so
this file's stated reasoning does not distinguish the two. It was rejected because
it trusts a **cached classification** inside three render loops where a stateless
predicate cannot be wrong, and because item A2 measured all 4,823 shipped name
records as already exact, so the string form costs nothing in coverage.

**Blast radius of the repair, censused by item A3's adversary pass** over all
44,177 `T` records in `xschem_library`, `sky130A`, `gf180mcuD`, `ihp-sg13g2` and
`xschem_libraries_oa`: **exactly 69 symbols render differently**, all of them the
`@spiceprefix@name` spelling this file names, and **zero** match only because
`annot_name_token()` adds a whitespace trim. Note the repair is **ungated by
`annot_show`** — it changes rendering for every user at `hide_symbols=2`, at
`hide_symbols=1` on subcircuits, and on any `HIDE_INST` instance. That is the
point of the fix, but it is a user-visible change with no mask behind it, shipped
inside a feature commit whose headline is a mask bit.

Sabotage `SB-1249-REVERT` (a two-spelling `annot_name_token`) reds nine rows —
N5, N6, N6b, N7, N14, A1, A8, A18, A27 — the best-covered mechanism in item A3.
