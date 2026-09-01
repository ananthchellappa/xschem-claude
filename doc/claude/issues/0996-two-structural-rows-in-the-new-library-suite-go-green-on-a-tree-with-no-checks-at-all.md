# 0996 — two structural rows in the New-library suite go green on a tree with no checks at all

**Filed by the S5 sabotage pass, 2026-08-30.** Subject:
`tests/headless/test_lib_new_path_guards_0799.tcl` rows **R8a** and **R8d**.

Both rows grep `library_new`'s body for strings that also appear in the long
explanatory comment inside that body. `string first` finds the **comment** first,
so both rows measure the comment and report on the guards.

## R8d — "the checks run before the folder is created, not after"

`:205-208` computes `string first "library_dir_owner" $lnbody` against
`string first "file mkdir" $lnbody`.

Mutation **S5**: both guard blocks moved to immediately *after* `file mkdir $path`,
comment left in place. Real tree, rebuilt, both arms:

```
FAIL: R4b the refused press did not leave an empty folder behind (exists=1 => .../ghostdir)
ok:   R8d the checks run before the folder is created, not after (check-at=2393 mkdir-at=2744)
```

R8d reports **GREEN on a tree where the checks run after the folder is created** —
index 2393 is the comment line `# and "library_dir_owner" (rows R8a/R8c) and for
their order against the`; the real call sits at 3097 in the shipped body.

Consequence: the sabotage plan's *"R4b and R8d are the only two eyes on this"* is
wrong. There is **one** eye, R4b. Delete or weaken R4b and the ordering ships
unpinned while 29/44 stay green.

## R8a — "both folder checks sit in the one place every New library press goes through"

`:182-184` asserts only that the body contains the substrings `library.defs` and
`library_dir_owner`. Both live in the comment; `library.defs` additionally
appears in a pre-existing error string (`no writable library.defs (set
XSCHEM_LIBRARY_DEFS)`) that predates the fix entirely.

Mutation **S12** (not in the plan): delete **both** guard blocks outright, keep
the comment. Real tree, rebuilt:

```
headless: 18 FAILED (11 passed)   R2a-e R3a-d R4a-b R5a-c R6b R9a-c
display : 23 FAILED (21 passed)   the above + R11a-e
ok: R8a  both folder checks sit in the one place ... (library.defs=1 owner=1)
ok: R8b1 ok: R8b2 ok: R8c ok: R8d
```

R8a and R8d go green on a tree with **zero folder checks**.

## Not fatal, but the labels are false

The guards themselves *are* seen — 18 behavioural rows redden under S12, and
R2a/R3a call `library_new` directly, so "the checks live in the choke point" is
pinned behaviourally. What is wrong is that two rows announce a subject they do
not measure, which is exactly the shape a future editor trusts.

## The fix

* R8d: anchor on `set owner [library_dir_owner` (the call, not the word), or strip
  comments from the body before comparing indices —
  `regsub -all -line {^\s*#.*$} $lnbody {}`.
* R8a: fold into R8c (they measure the same comment block twice), or re-point it
  at the guard code — e.g. assert the body contains the refusal sentence itself,
  which only the guard carries.

---

## FIXED, 2026-08-31 (S5 repair pass)

The comments now come out of the body **before** any structural row looks at it:

```tcl
set lncode $lnbody
regsub -all -line {^[ \t]*#[^\n]*$} $lnbody {} lncode
```

* **R8a** re-pointed at the CODE — it asks for `library_dir_listfile` and for
  `set owner [library_dir_owner`, neither of which the note contains.
* **R8d** compares `set owner [library_dir_owner` against `file mkdir` in the
  **stripped** body.
* **R8c** keeps the raw body, because the note really is its subject.

Re-measured on the real tree:

| variant | before | after |
|---|---|---|
| all three checks deleted, note kept | R8a `ok`, R8d `ok` | **R8a FAIL, R8d FAIL** (with 22 behavioural reds) |
| checks moved after `file mkdir` | R8d `ok` (`check-at=2393`) | **R8d FAIL** (`check-at=1406 mkdir-at=439`) |

So the before-mkdir ordering has **two** eyes now, R4b and R8d, which is what the
plan claimed all along. R8b1-R8b4 and R8c correctly stay green when only the
`library_new` checks go — they measure the lookup and the note, not the checks.
