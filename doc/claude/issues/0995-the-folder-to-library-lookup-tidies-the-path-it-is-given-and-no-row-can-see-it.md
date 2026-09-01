# 0995 — the folder-to-library lookup tidies the path it is given, and no test row can see it

**Filed by the S5 sabotage pass, 2026-08-30.** Subject: the 0799 fix
(`src/library_defs.tcl`, `proc library_dir_owner`).

## What the code does

```tcl
proc library_dir_owner {dir} {
  set n [file normalize $dir]          ;# <-- THIS LINE
  dict for {lname lpath} [library_registry] {
    if {[file normalize $lpath] eq $n} { return $lname }
  }
  return {}
}
```

The comment above it says, correctly, that **neither** normalize is decoration.
The registry-side one is pinned by two rows (R5c, R6b). The argument-side one is
pinned by **nothing**.

## Measured

Mutation **S4** — the whole variant is `set n $dir` instead of
`set n [file normalize $dir]`, applied to the real tree, rebuilt, run on both arms:

| arm | result |
|---|---|
| `./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_lib_new_path_guards_0799.tcl` | **RESULT: ALL PASS (29 checks)**, exit 0 |
| `tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script …` | **RESULT: ALL PASS (44 checks)**, exit 0 |

Zero reds, both arms. The sabotage plan for this item states *"S4 MUST REDDEN R5a
and R5b"*. It reddens neither.

**Why R5a/R5b cannot see it:** `library_new` computes
`set np [file normalize $path]` and hands the already-tidy `$np` to
`library_dir_owner`, so the trailing-slash row (R5a) and the dot-dot row (R5b)
never reach the untidy branch. The only two rows that call `library_dir_owner`
directly, R8b1 and R8b2
(`tests/headless/test_lib_new_path_guards_0799.tcl:192,197`), both pass tidy
paths as well.

**The line is live, not dead code.** Same probe, same fixture, two builds:

```
shipped   PROBE tidy   : 'libA'   PROBE slash : 'libA'   PROBE dotdot : 'libA'
S4 mutant PROBE tidy   : 'libA'   PROBE slash : ''       PROBE dotdot : ''
```

(`library_dir_owner <root>/libA/` and `library_dir_owner <root>/libB/../libA`.)

## Why it matters

`library_dir_owner` is a public proc in a sourced Tcl file. `library_new` is its
only caller **today**; the comment above it explicitly invites a second one
("so a mutation run has a callee it can no-op and the suite has a handle it can
unit-test"). The next caller that hands it a path straight from a Directory entry
or a `tk_chooseDirectory` result gets a silent wrong answer, and the suite stays
at 29/44.

## The fix

One extra row beside R8b1/R8b2 — call `library_dir_owner` directly with an
untidy path:

```tcl
check "R8b3 the folder-to-library lookup recognises a folder written the long way round" \
  [expr {[library_dir_owner [file join $tmp libB .. libA]] eq "libA"}] ...
```

Verified: that row is red under S4 and green on the shipped tree.

---

## FIXED, 2026-08-31 (S5 repair pass)

Two rows added beside R8b1/R8b2 in `tests/headless/test_lib_new_path_guards_0799.tcl`,
calling `library_dir_owner` **directly** with the two untidy spellings, which is
how the next caller will reach it (a folder name typed into a box, or one handed
back by a directory picker):

```
R8b3 the lookup recognises that same folder written with a trailing slash
R8b4 and written the long way round, out through another folder and back
```

Re-measured with variant S4 applied to the real tree (`set n $dir`):

```
FAIL: R8b3 the lookup recognises that same folder written with a trailing slash (=> '')
FAIL: R8b4 and written the long way round, out through another folder and back (=> '')
RESULT: 2 FAILED (34 passed)     exit 1
```

Green on the shipped tree, both arms. The guard is no longer unseen.
