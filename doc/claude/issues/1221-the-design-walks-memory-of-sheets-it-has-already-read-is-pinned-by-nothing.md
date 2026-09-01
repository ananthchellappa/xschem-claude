# 1221 - the design walk's memory of sheets it has already read is pinned by nothing

**Filed by** item S6b's sabotage pass, 2026-08-31. **Severity** medium (a hang, not
a wrong answer). **Area** `auto_spec_scan_file()`, src/actions.c.

## What is wrong

Before XSCHEM invents a cell name it reads the design's sheet files to learn which
names designers have already typed. That walk steps from a sheet into the sheets it
places, so two sheets that place each other would walk for ever. Two things stop it:
a depth limit, and a memory of which files it has already been through.

Row **AS74** exists to require both by reading the code, precisely because a missing
bound does not make a suite fail, it makes the suite **hang**, and a hang is not a
test result. Its own words say so.

**The depth limit really is pinned. The memory is not.** AS74 asks for it like this:

```tcl
[expr {[as_count $AS_SCANF {seen}] >= 1 ? 1 : 0}]
```

That counts the word `seen` anywhere in the function. The function's own parameter is
called `seen`, and the two recursive calls pass it along. So the count is **3 with the
entire memory deleted**, and `>= 1` is satisfied by the parameter name alone.

## Measured

Deleting both lookups -- the whole memory of where the walk has been --

```c
  if(str_hash_lookup(seen, path, "", XLOOKUP)) return;
  str_hash_lookup(seen, path, "1", XINSERT);
```

and rebuilding leaves `test_auto_specialize_1201` at **RESULT: ALL PASS (77 checks)**
and `test_unused_attr_0970` at 67. Nothing anywhere goes red.

For contrast, deleting the depth limit alone **does** redden AS74, and deleting both
reddens it -- so the row's red under the plan's SAB-SCANBOUND variant was earned
entirely by the depth limit. The memory half has shipped untested.

## Why it matters

The depth limit is `CADMAXHIER`, which is **40**. With the memory gone, a design whose
sheets form a diamond -- two sub-sheets that both place a third, the ordinary shape of
any reused cell -- is re-read once per path rather than once per file. Depth 40 of that
is up to 2^40 file reads. The user sees a netlist that never finishes.

## The repair

One element, asserting the memory is actually consulted rather than merely named:

```tcl
[as_count $AS_SCANF {str_hash_lookup(seen, path}]
```

expected 2. That counts the lookup and the insert, and it cannot be satisfied by a
parameter name.

## Related

Same class as **1217** (a row printing a claim it never checks) and **1222**, both
filed against rows minted in this same pass.

---

## CLOSED 2026-08-31 by item S6b's REPAIR pass

Row **AS74**'s hollow element is gone. It asked whether the word `seen` occurred
at all, which the walk's own parameter name satisfied; it now counts
`str_hash_lookup(seen,` inside `auto_spec_scan_file()` and requires **2** -- the
lookup that asks whether this sheet has been read and the insert that records
that it has. Neither can be satisfied by a parameter name.

Measured: deleting both lines reddens AS74 and nothing else. The depth-limit
element is unchanged and still earns its own red.
