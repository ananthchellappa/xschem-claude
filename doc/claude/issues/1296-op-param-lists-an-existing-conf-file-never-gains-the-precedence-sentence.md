# 1296 — an existing settings file never gains the precedence sentence, and a v1 file keeps `version 1` while gaining v2 rows

**Status: MEASURED, FILED, NEEDS A RULING.** Found by item **B2c**'s adversary
pass and reproduced by the write-up agent, 2026-09-03, before B2c was reverted.

**This is a collision between two things the item was told to do**, not a slip.
It needs a decision, not a line, and that is why it is filed rather than fixed.

---

## The two rules that collide

1. **The item's named ACCEPT row** — *"The precedence sentence the file emits is
   TRUE of the code that emits it"* — the row **both previous crews failed**,
   and the reason DD-8 exists: *"because it is file order, the file itself is
   the documentation."*
2. **B2c's ladder-L2 decision** — *"the header block and the `version` row are
   emitted ONLY into a file that has no lines yet. An existing file is edited at
   the rows this session changed and decorated nowhere."* Taken to satisfy DD-7
   (*preserve every row verbatim*) and fenced by row **W9** (same store to the
   same path twice must be byte-identical).

**Both are right and they cannot both hold.** Rule 2 means rule 1 is true only
of files this build created from scratch — and *every* file is a pre-existing
file from its second save onward.

## The measurement (2026-09-03)

A file that already exists, carrying a hand-written header and `version 1`:

```
# my own header
# list <scope> <key> <listname>
version 1
class nmos mos
```

Load it, add a v2 flavor entry, save. **The file afterwards, verbatim:**

```
# my own header
# list <scope> <key> <listname>
version 1
class nmos mos
list flavor mos *nfet* annotation
param flavor mos *nfet* annotation FL id 0
```

```
write=1  says_FIRST_ONE_WINS=0  version_rows=1  v1_line=1  has_v2_flavor_row=1
```

Three separate problems in six lines:

* **The precedence rule is absent.** `regexp -all {FIRST ONE IN THIS FILE WINS}`
  = **0**. The file documents no precedence at all, which is what HEAD does —
  so the acceptance row is satisfied only for fresh files.
* **The grammar block contradicts the rows beneath it.** `# list <scope> <key>
  <listname>` (v1, 4 fields) sits directly above `list flavor mos *nfet*
  annotation` (v2, 5 fields).
* **The file declares a version whose grammar it violates.** It says
  `version 1` and carries v2 rows. A v1 reader drops those rows as a wrong field
  count; a v2 reader re-emits the version-mismatch report on **every** load,
  forever.

## Severity, honestly stated

**Today: none.** No settings file exists in the wild — nothing calls the writer
yet, and the v1→v2 grammar bump is being done *now* precisely so that no v1 file
is ever created. So the `version 1` half is forward-looking.

**From B5 onward: real.** Once B5 writes the first file, every subsequent save
is the "existing file" case, and the precedence sentence — the one thing DD-8
relies on to explain itself — is never re-emitted into a file the user grew.

## The options, costed

| # | option | cost |
|---|---|---|
| **a** | Emit the precedence paragraph when the file carries **no `#` block at all**, and leave a file that has one alone. | Cheapest. Loses the paragraph for any file whose owner wrote their own comment first — including the v1 file above. |
| **b** | Emit or **refresh** the header when the `version` row is **absent or stale**, and migrate the version row alone. | Fixes all three problems. Migrating the version row is **not an inference** — the grammar of every non-flavor row is unchanged between v1 and v2, so a v1 file's other rows are already valid v2. Costs one branch and edits a file the user wrote. |
| **c** | Accept that pre-existing files are undocumented, and **say so** in the emitted header and in issue **1275**. | Zero code. Makes the acceptance row's scope explicit instead of quietly narrow. |

**(b) is the recommendation** — it is the only one under which a user who opens
their settings file finds the rule that governs it, and the version row it
migrates is the single row whose meaning genuinely changed.

**Any of the three is defensible. Silence is not**, because a stale v1 header
now sits directly above rows whose field count it contradicts, and the file's
whole justification under DD-8 is that it documents itself.

## Still open

* This is on the user's queue as part of rule debt **1275** (the grammar
  ratification door). The precedence sentence and the v1→v2 migration are the
  two things 1275 must carry that it does not carry today.
