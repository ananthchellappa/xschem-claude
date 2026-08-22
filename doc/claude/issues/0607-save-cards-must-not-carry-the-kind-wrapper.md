# 0607 — a `.save` card built from `op_annot::vector` silently loses every current-type row

STATUS: **OPEN**, measured 2026-08-22 on branch `annotate` while preparing the
sky130 `bandgap_opamp` look. Blocks nothing today (no shipped code emits save
cards — S3 is unlanded), but it is a trap laid directly in S3's path.
Related: 0499(b), 0604 (I8), spec `op_annotation.md` §4.2a.

## The measurement

Three decks, identical but for one card, `/usr/local/bin/ngspice` 46+, sky130
`tb_bandgap`, device `M4` two levels down:

```
.save i(@m.x1.x1.xm4.msky130_fd_pr__pfet_01v8[id])   -> NOTHING saved
.save   @m.x1.x1.xm4.msky130_fd_pr__pfet_01v8[id]    -> saved
.save v(@m.x1.x1.xm4.msky130_fd_pr__pfet_01v8[id])   -> saved
```

In **both** working cases ngspice names the resulting vector
`i(@m.x1.x1.xm4.msky130_fd_pr__pfet_01v8[id])` in the raw — it applies the type
itself, from the parameter, and the wrapper in the *card* is not how you ask
for it.

The failure is **silent in every channel**: `rc=0`, no `checkvalid` warning, no
message in the log, and the raw is written normally with the other five
parameters present. The first full run of the 13-FET bench produced 78 cards
and a 15.8 MB raw in which exactly 65 of 78 vectors existed — 13 × 5. Nothing
said so.

## Why this is a trap and not a curiosity

`op_annot::vector` is documented as the **read** name and is correct as one: it
applies the descriptor's `kind` (0 -> `i(dev[p])`, 1 -> bare, 2 -> `v(dev[p])`,
after `token.c:4524`), and that is exactly how the vector is spelled *in the
raw*. So

```tcl
foreach row [dict get $d params] {
  lassign $row label param kind
  puts $fh ".save [op_annot::vector $inst $param]"     ;# WRONG, silently
}
```

reads as the obvious implementation, uses the one name builder invariant I1
asks for, and drops every `kind 0` row on the floor. A save card wants
`[op_annot::devpath $inst]$param` in brackets — the bare path, no wrapper.

Both prior hand-built runs happened to dodge it: `test_nmos` (sky130) and
`dc_lv_nmos` (IHP) were generated from `op_annot::devpath` and the param name
directly, never from `vector`. That is why this went unseen until a third
bench was built the other way.

## What to do

1. S3's `op_annot::save_cards` emits **bare** `<devpath>[<param>]`, and its
   guardians must include one row asserting no card contains `i(` or `v(`.
2. Say it in `op_annotation.md` §4.2a next to the `kind` table: **`kind` is a
   read-side spelling. Save cards never carry it.**
3. This is also the sharpest argument yet for **0604 / invariant I8**. Every
   channel ngspice offers was green; only counting the vectors against the
   cards found it. I8's "report requested-but-undelivered vectors in the CIW
   and logfile" is the only thing that would have caught this at the moment it
   happened rather than three steps later.
