# 1200 — New library cannot find a library list to write to, and says so in a line of jargon

**Status:** OPEN. **Filed 2026-08-31** by the S5 write-up pass, while committing
the `0799` work.
**Owner:** `src/library_defs.tcl` (`library_new`).
**Related:** `0799` (the New-library work, which made this sentence land in a
place it never used to reach), `[[0999]]` (the other prompt-window debt left from
the same item).

---

## What the user does

**Library Manager ▸ right-click the Library pane ▸ New library…**, type a name,
press OK — in a session that has no library list it can write to. That is not
exotic: it is what a first run looks like before anybody has set one up.

## What the user reads

> **new library failed: no writable library.defs (set XSCHEM_LIBRARY_DEFS)**

Measured today on the committed tree, on both arms. Headless:

```
primary defs file: ''
library_new NEWLIB {} -> rc=1
what library_new says: no writable library.defs (set XSCHEM_LIBRARY_DEFS)
```

and on the dev display, driving the actual window:

```
outcome: seen2  (polls=2)
the red line at the top of the New-library window reads:
  new library failed: no writable library.defs (set XSCHEM_LIBRARY_DEFS)
the Library Manager status line reads:
  new library failed: no writable library.defs (set XSCHEM_LIBRARY_DEFS)
```

## Why that is a defect

The standing **PLAIN ENGLISH** ruling (user, verbatim 2026-08-27): *"wording too
cryptic. Give it in plain english with context, 9th grade level."* — say what
happened **and** what the user can do about it. This sentence does neither in
words a user has. It names a **file** the user has never seen, an **environment
variable** the user is not told how to set or to what, and gives no hint that the
usual fix is a one-line setting in `~/.xschem/xschemrc`. Compare the three
sentences `0799` added right beside it, which name the folder, say what would go
wrong, and end with a thing to do.

`0799` did not create this sentence — it predates the whole item. What `0799`
changed is **where it lands**. Before, a refused New library closed its window and
left the reason on a status bar behind it. Now the window comes back with the
reason on a red line across its top, so this is the first sentence a new user
reads inside the dialog they are trying to use. A line of jargon got promoted.

## Why it was not fixed in the 0799 commit

Widening an untested user-facing string inside a repair pass is the trade this
branch has been burned by: `0799`'s own first implementation went green on both
arms while being wrong in four ways (`[[0995]]`–`[[0998]]`). This sentence has
**no test row anywhere** (`grep -rn "no writable library.defs" tests/` finds
nothing), and no other file references it, so changing it would have been an
unmeasured edit riding a commit whose subject was something else.

## Adjacent, and deliberately not lumped in

The other two sentences `library_new` can produce were measured at the same time
and are terse but comprehensible — they name the thing the user typed and are not
in the same class:

```
empty name        -> new library failed: library name required
name already used -> new library failed: library already exists: libA
```

Worth re-reading when this one is fixed, not worth a separate issue.

## What a fix has to be

1. **One sentence, minted in `library_new`** and rendered by callers (D5-4) —
   the same seam the three `0799` sentences already use, so the Library Manager
   status line and the New-library window's red line stay identical.
2. It must say **what happened** in the user's terms ("there is no library list
   this session can write to, so there is nowhere to record a new library") and
   **what to do** — name the usual remedy concretely, i.e. where the list normally
   lives and the one line that points at it.
3. It must be **true in both setups**. `library_primary_defs_file` returns empty
   for more than one reason (nothing configured at all; configured but not
   writable). If the sentence claims which, it must have checked — D5-1.
4. **A row that can see it.** The cheapest is a headless row in
   `tests/headless/test_lib_new_path_guards_0799.tcl`'s fixture shape: isolate
   `::USER_CONF_DIR`, clear `::XSCHEM_LIBRARY_DEFS` and `::pathlist`, assert
   `library_new` errors and that the sentence contains the remedy. Mutation-verify
   it: deleting the remedy clause must redden the row.
