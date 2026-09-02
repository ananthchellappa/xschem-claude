# 1249 — the shipped keep-name test misses `@spiceprefix@name`, in all three render back ends

Status: **open** (measured behaviourally by item A2's implement pass, 2026-09-02;
**not fixed** — item A2 owns none of the three files) · Branch: `fluid-editing`
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
