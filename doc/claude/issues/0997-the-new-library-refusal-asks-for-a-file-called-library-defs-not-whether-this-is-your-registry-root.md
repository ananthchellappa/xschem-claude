# 0997 — the New-library refusal asks "is there a file called library.defs here?", not "is this your registry root?"

**Filed by the S5 sabotage pass, 2026-08-30.** Subject: `src/library_defs.tcl`,
the first of 0799's two directory checks.

```tcl
if {[file isfile [file join $np library.defs]]} { error "'$np' is the folder that holds your library list …" }
```

The sentence claims a fact about **this session's registry**. The test is a
hardcoded **filename**. Those are different questions, and the gap is reachable
in both directions.

## Direction 1 — the issue's own harm survives the fix

`library_explicit_defs_files` (`src/library_defs.tcl:73-78`) splits
`$XSCHEM_LIBRARY_DEFS` and imposes no filename at all; the file's own header calls
the format "a cds.lib analog". Measured on the **fixed, restored, rebuilt** tree:

```
registry list file: <root>/cds.lib   containing  DEFINE libA libA / DEFINE libB libB
library_new JUNK <root>   ->  rc=0 err=''
library_resolve JUNK      ->  <root>
```

That is byte-for-byte the user's complaint — a `DEFINE` naming the root that holds
all the libraries — accepted without a word, on the tree that is supposed to have
fixed it. Same one click in the UI: `libmgr::newlib_browse`
(`src/library_manager.tcl:1177-1189`) opens the directory picker on
`[file dirname $defs]`, i.e. that very root, whatever the file is called.

## Direction 2 — the sentence asserts something it did not measure (D5-1)

A folder that is **not** part of this session's registry but happens to contain a
file named `library.defs` — another project's tree, a checked-out PDK — is refused
with *"'…' is the folder that holds **your** library list"*. False for that
session.

The same refusal then gives advice that is wrong for that input: *"Leave the
Directory blank to make a new folder there"*. A blank Directory creates the folder
under the **primary library.defs directory**, not under the folder the user picked.
Measured: refusing `<tmp>/unrelated` and then following the advice creates
`<tmp>/OTHER`, not `<tmp>/unrelated/OTHER`.

## No row covers either direction

`tests/headless/test_lib_new_path_guards_0799.tcl` always names the fixture file
`library.defs` and always builds the root inside the session, so all eleven planned
mutations plus five of mine can pass while this is live.

## The fix

`library_new` already has the real answer two lines earlier:
`set base [file dirname [file normalize $defs]]`. Compare `$np eq $base` (or loop
`library_candidate_defs_files`) instead of testing for the literal filename. Both
directions close together, and the sentence becomes true of what it measured.

Add two rows: a fixture whose list file is spelled `cds.lib` (must be refused), and
a folder holding a foreign `library.defs` outside the session's registry (must be
accepted, or refused with a sentence that does not say "your").

---

## FIXED, 2026-08-31 (S5 repair pass)

`library_new` now asks the question its sentence answers. New proc
`library_dir_listfile` (`src/library_defs.tcl`) walks
`library_candidate_defs_files` — the very list the write side appends to — and
returns the name of the list file that lives in that directory, whatever it is
called. The primary defs file is always one of its entries, so this subsumes a
bare `$np eq $base` and also catches the secondary roots that would have missed.

**Three situations, three sentences**, because they are three different facts and
only one may be stated about the user's own setup:

1. *"'…' is the folder your library list lives in - the file 'cds.lib' in it is
   the list that says where all your libraries are - so it is the folder that
   HOLDS your libraries, not a library itself. …"*
2. *"'…' holds a library list of its own - there is a library.defs file in it -
   so it is a folder that holds libraries, not a library itself. It is not one of
   the library lists this session is reading, so it belongs to some other setup. …"*
3. the unchanged *"'…' is already the library '…'."*

Direction 2's advice was wrong as well and is fixed with it: the old sentence said
*"Leave the Directory blank to make a new folder there"*, which creates the folder
somewhere else entirely when the refused folder is not the primary root. It now
says a new folder *"will be made for you beside your main library list"*, which is
true of what the blank case actually does.

Five rows added (**R14a-R14e**, headless, so both arms): a fixture whose list file
is called `cds.lib` must be refused and the refusal must name `cds.lib` and not
`library.defs`; and a folder holding a foreign `library.defs` must still be
refused but must not call that list the user's own. Re-measured with the pre-fix
filename-only check put back:

```
FAIL: R14a ... refused even when the list is not called library.defs
FAIL: R14b and the refusal names the list file the user actually has
FAIL: R14c nothing called JUNK was written into that library list
FAIL: R14e and that refusal does not tell the user it is their own library list
```
