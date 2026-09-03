# 1262 — `raw_deletevar()` shifts `names[]` and `values[]` but leaves `cursor_b_val[]` behind

**Filed** 2026-09-02 by item **A6**. Found while placing `Raw.dims0` beside
`Raw.cursor_b_val`. **Measured, not fixed. Pre-existing — A6 did not cause it.**

## The defect

`raw_deletevar()` (`src/save.c`) removes column *n* and re-packs the arrays that
follow it: `names[]` is shifted, `values[]` is shifted, `nvars` is decremented
and `raw->table` is rebuilt. **`cursor_b_val[]` is neither shifted nor
shrunk.** It is the array `xschem raw value <v> -1` reads — the operating-point
number every annotation on the schematic is drawn from.

So after `xschem raw del <name>`, every column from the deleted index onward
reports **its neighbour's** OP number, silently and plausibly. That is the exact
failure ruling **D5-1** is about: a plausible wrong number on a schematic is
worse than none.

## How it was found

Item A6-b added `Raw.dims0`, one byte per column, and had to decide what
`raw_deletevar()` should do with it. The array **is** shifted there — correctly,
in the same loop that shifts `names[]`. Writing that loop is what exposed the
neighbouring array that is not.

Reproduced separately by the adversary pass: `xschem raw del` of a normal column
sitting before another leaves the surviving columns each reporting their
neighbour's value.

**A6 deliberately did not touch `cursor_b_val`.** The two arrays are therefore
now *knowingly* inconsistent after a delete: the absence byte follows its column
and the value does not. That is harmless today only because the value was
already wrong.

## Fix shape

One shift, in the loop that already shifts `names[]`, plus the matching
`my_realloc`. Guard it on `raw->cursor_b_val` being non-NULL, as `dims0` is:
a reader that never allocated it must not be handed uninitialised bytes.

## Still open

All of it. Not on any item of the op-param batch — feature A closed at A7.
