# 0184 — `idxsize` leaks across parses and corrupts the heap on the NEXT bus label

Status: **OPEN** — reproduced, measured, **not fixed**. Found while running the issue-0182
label battery; it is a *different* defect from 0182 and survives 0182's fix.
Area: `src/expandlabel.y` — the `static int idxsize` and the seven `index` / `index_nobracket`
allocation sites
Tests: none yet
Found: 2026-07-31, by extending the 0182 battery
Related: 0182 (same file, same battery, unrelated mechanism), 0183

## The bug

`expandlabel.y:46` keeps the size of the bus-index array in a **file-static**:

```c
#define INITIALIDXSIZE 8
static int idxsize=INITIALIDXSIZE;
```

Every `index:` / `index_nobracket:` production that *starts* an array allocates
`INITIALIDXSIZE` ints (`expandlabel.y:426`, `:444`, `:458`, `:468`, `:523`, `:541`, `:555`),
but `check_idx()` (`:220-228`) grows it only when the element count reaches `idxsize`:

```c
static void check_idx(int **ptr,int n)
{
 if(n>=idxsize)
 {
  idxsize*=2;
  my_realloc(_ALLOC_ID_, ptr, idxsize*sizeof(int));
 }
}
```

So `idxsize` must describe *the array just allocated*. It is only reset to `INITIALIDXSIZE`
at the **end** of the four `B_NAME '[' index ']'` productions (`:387`, `:397`, `:407`,
`:417`) — i.e. on the success path. **A label that grows the array and then hits a syntax
error never reduces those productions, so the reset never runs.** `idxsize` stays large for
the rest of the process, and the *next* bus label allocates 8 ints while `check_idx()`
believes it has room for 32 — a plain heap buffer overflow.

## Reproduce

Two labels, one process. The first is malformed *inside* the brackets, so it grows the
array and dies before the reset:

```sh
cd src
cat > /tmp/idx.tcl <<'EOF'
puts "A=[xschem expandlabel {a[0:20,]}]"
puts "B=[xschem expandlabel {b[0:15]}]"
puts "C=[xschem expandlabel {c[0:31]}]"
EOF
./xschem --nogui --pipe -q --nolog --script /tmp/idx.tcl
```

Measured on both the pre-0182 and post-0182 binaries (2026-07-31):

```
syntax error in a[0:20,]
A=a[0:20,] -1
B=b[0],b[1],...,b[15] 16      <- 16 ints written into an 8-int allocation
realloc(): invalid next size  <- glibc aborts, exit 134
```

`a[0:20,]` builds 21 elements, doubling `idxsize` 8 -> 16 -> 32. The `index ',' B_IDXNUM`
continuation then wants a `B_IDXNUM` and gets `]`, so `yyparse()` errors out with `idxsize`
at 32. `b[0:15]` allocates 8 ints, `check_idx()` never fires (16 < 32), and the 16th write
runs off the end. `c[0:31]` never gets to print — glibc kills the process first.

This is memory corruption, not a NULL deref: the write lands in the allocator's bookkeeping,
so *where* it detonates depends on the heap layout. A schematic with one malformed bus label
can therefore make an apparently unrelated later label crash the editor.

## Why it is NOT issue 0182

0182 is about `expandlabel_strmult{,2}()` and `expandlabel_strbus*()` dereferencing NULL /
reading `n[1]` when a sub-expression collapses to zero width. Its fix makes those return
NULL. This one needs *no* zero multiplicity at all: `a[0:20,]` and `b[0:15]` are both
perfectly ordinary bus ranges. It reproduces identically before and after 0182's fix.

## The fix

`idxsize` should be established where the array it describes is **allocated**, not where it
is consumed. Add `idxsize = INITIALIDXSIZE;` next to each of the seven
`$$=my_malloc(_ALLOC_ID_, INITIALIDXSIZE*sizeof(int));` sites, which makes the invariant hold
on every path including the error paths. The four existing resets at the end of the
`B_NAME '[' index ']'` productions then become redundant but harmless.

Rejected alternative: resetting `idxsize` at the top of `expandlabel()`. That fixes this
reproduction but not the general case — two `index` arrays inside one label (`a[0:20],b[0:3]`)
are still described by a single static, and only the reduce-order of LALR keeps them from
overlapping today.

## What is NOT wrong here

The four-argument bus form with a zero repetition count (`a[3:0:1:0]`) leaves `$$[0] == 0`
but does **not** grow `idxsize`, so it does not feed this bug. That shape is 0182.
