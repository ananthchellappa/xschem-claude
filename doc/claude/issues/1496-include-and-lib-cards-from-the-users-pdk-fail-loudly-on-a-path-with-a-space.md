# 1496 — `.include` and `.lib` cards from the user's own PDK setup fail the run outright on a path with a space

**STAMP:** `v1 claim=open tree=a1314271 stamped=2026-09-20 fix=untried open=4 by=C-docs`

**Status: OPEN — filed 2026-09-20** by the stranger-reds batch, from item C's implement
round (`receipts/C-impl.md` §7.1), its adversarial verifier (`C-verify.md` §1.5 and finding
**F3**) and its fix round (§F1.2, §F5, §F7.2), under batch decision **D8**: a finding
outside the item being worked is written down and filed, never fixed on the way past.

**Class** product defect, user-facing, **loud**. **Related: issues 1484 and 1490**, which
are the same trigger — a path the simulator cannot take literally — fixed in
`a1314271` for every **control** line ASE-L writes. This file is the remainder: the **deck
cards**, and specifically the ones whose path comes from the user's own PDK setup rather
than from ASE-L.

⚠ **This is the opposite failure direction from 1484/1490, and that is the reason it is
filed separately rather than folded in.** Those two lost a user's artifacts **silently at
rc 0**. These cards fail **loudly, at rc 1, with the run producing nothing** — a different
severity, a different remedy, and a different owner: the path belongs to the user's PDK,
not to ASE-L. A verifier flagged the omission in as many words (`C-verify.md` **F3**): the
finding *"exists only in `C-impl.md` §7.1 — no issue file mentions it"*.

---

## What happens

A user whose models live under a path with a space — `/mnt/c/Users/Jane Doe/pdk/`, the
ordinary Windows home seen from WSL, or `~/Documents/My Designs/pdk/` — starts a
simulation. ngspice cannot find the include file, prints an error and **exits 1**. Nothing
is salvaged, because nothing ran.

## MEASURED

All measurements below are the receipts' own, taken with decks written by hand, ngspice
run, and the result read off its exit code and its output. Two binaries throughout:
**`/usr/bin/ngspice` 45.2** and the ASE registry's fork
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (**46+**).

### 1. The bare card, which is what ASE-L emits today

`C-impl.md` §7.1, a `.lib` inside a directory named `w s`:

```
.include /x/w s/f.lib
    -> Error: Could not find include file /var/tmp/xsr_c/qa/w      rc 1
```

The path is cut at the first space, exactly as the control lines were — this is the same
word splitting traced in issue 1490 — but the deck reader **stops** instead of writing
somewhere unexpected.

### 2. Quoting, re-measured by the adversarial verifier (`C-verify.md` §1.5), ngspice 45.2

| card | bare | `"…"` | `'…'` |
|---|---|---|---|
| `.include` | **rc 1** | rc 0 | rc 0 |
| `.lib` | **rc 1** | **rc 1** | **rc 1** |

> Both fail **loudly**, unlike the control lines.

### 3. Two corrections the fix round made to the sentence above (`C-impl.md` §F7.2)

Both re-measured on **both** binaries with a **load-bearing** include — a `.param rv=7700`
that has to reach the circuit, checked as `v(1)/i(v1) = -7.70000e+03`, so that "rc 0" cannot
mean "silently included nothing":

* §7.1 said *"Double quotes fix `.include`"*. → **Either quoting fixes it.** Single: rc 0
  with the `.param` reaching the circuit. Double: rc 0.
* §7.1 said *"nothing fixes `.lib`"*. → **True only of 45.2.** Quoting fixes `.lib` on the
  **fork (46+)** — `'…'` and `"…"` both rc 0 — and **all three forms are rc 1 on 45.2**.

### 4. A RELATIVE `.lib` resolves on both binaries — the only measured remedy for 45.2

`C-impl.md` §F7.2: `.lib m.lib tt` from a spaced directory resolves on both binaries,
measured **twice** — with cwd inside the spaced directory, **and** with the deck named by an
absolute spaced path from elsewhere. That is the same relative-path remedy
`ase::cosim_rewrite` and the `cap_deck_*` probes already use.

⚠ **It helps exactly where the space sits in a directory the deck and the target share** —
ASE-owned artifacts, and `test_ase_core`'s `E1` case. **It does not help a PDK elsewhere on
disk**, which is this issue's subject.

### 5. `.include` quoting per character — the table that says quoting is never worse

`C-impl.md` §F1.2, 26 directories, one per character, bare vs `'…'` vs `"…"`, load-bearing,
both binaries:

* `space` and `;` — **bare BAD**, single OK, double OK
* `'` — bare OK, **single BAD**, double OK
* `"` — bare OK, single OK, **double BAD**
* the other 23 (`% + , : = ~ ! # @ ( ) [ ] & * ? \ | < > ^ -`) — all three OK

> So there is **no character for which the new quoting is worse than the bare form**, except
> a path carrying both `'` and `"` at once — which fails **loudly**, at rc 1.

That table was measured for the `opstate` `force` `.include`, which **is** fixed in
`a1314271`. It transfers to the models cards because it is a property of ngspice's deck
reader, not of the call site — **that transfer is INFERRED**, and the models cards
themselves have not been re-run through it.

### 6. An apostrophe kills `.lib` on every form, and takes a suite with it

`C-impl.md` §F5, scratch at `…/ap/O'Br`:

| card | bare | `'…'` | `"…"` |
|---|---|---|---|
| `.include …/O'Br/p.inc` | **rc 0** | rc 1 | rc 0 |
| `.lib …/O'Br/m.lib tt` | **rc 1** | **rc 1** | **rc 1** |

The event probe deck carries the fixture's `.lib`, so it dies, and `CI2` `CI3` `CI4` `CI6`
`CI8` `CI9` `EM*` `RF*` `UN1` go red with it — **all of them on `HEAD` too**, so this is
pre-existing and not a regression of `a1314271`.

## The rows this causes

MEASURED, in a space **checkout** (`C-impl.md` §F3 and §F7.2):

| suite | rows |
|---|---|
| `test_ase_core` | `E1a` `E1b` `E1c` `E1f` — the suite is `671+4` in a space checkout, `675` in a plain one |
| `test_ase_events_1465` | `CI2` `CI3` `CI6` `CI8` |
| `test_ase_events_1465`, apostrophe tree | the 21 rows of §F5, red on `HEAD` and on the fix alike |

A space **scratch** does not reproduce the `test_ase_core` rows: *"`$models` is `[file join
$repo sky130A …]`"*, so the **checkout** has to move.

⚠ **One earlier attribution here was refuted by measurement, and it is worth knowing.**
`C-impl.md` §7.1 also filed `test_ase_converge_1459 EE5` under this class. It is **not**:
§F4.1 measured that `EE5` is ASE-L's own `opstate` `force` `.include`, and reverting only
that one fix takes the suite in a space tree from **ALL PASS (77)** to **4 FAILED**
including `EE5/apt` and `EE5/fork`. `EE5` is fixed in `a1314271` and is not part of this
issue.

## READ, not measured

* **Where the cards are emitted.** `ase::backend::ngspice` writes both — `.include`/`.lib`
  from the **models list**, and `.include` again from `opstate_lines`' `force` restore.
  **The second one is fixed** in `a1314271`; the models list is not. (READ of
  `src/ase.tcl`.)
* **`event_probe` is a second deck builder**, re-implementing `render_deck`'s
  `.include`/`.lib`/`.param`/`pre_commands` emission, so **any quoting added for this issue
  must land in both places**. A comment in `src/ase.tcl` now says so in the code, which is
  the durable half. (READ, `C-impl.md` §F7.4 / `C-verify.md` `C5b`.)
* **`pre_commands` interpolates `$::VAR` into a word that may split.** READ by item C's
  verifier and **not measured**; handed on here with that provenance and nothing more.

## INFERRED

* That quoting the models `.include` is safe, by transfer from §5's per-character table
  (measured on a different call site).
* That a user with a spaced PDK path meets rc 1 rather than a silent loss. The
  **mechanism** is measured; **no bench has been run end to end with a real PDK under a
  spaced path** — the measurements above are hand-written decks and the suites' own
  fixtures.

## Fix direction

1. **Quote the models `.include`** with the same conditional rule `a1314271` already uses
   for the `opstate` `force` card — bare when `path_bare_ok` says the path is safe, single
   quotes otherwise, double quotes when the path holds an apostrophe. `path_quoted` in
   `src/ase.tcl` is the existing helper; do not write a second one.
2. **`.lib` on 45.2 cannot be quoted.** The measured remedy is a **relative** card, which
   only works when the deck and the library share a directory. For a PDK elsewhere on disk
   there is no measured remedy on 45.2 at all, so the honest shapes are: emit a path
   relative to the deck where one can be computed, and otherwise **refuse by name** the way
   `render_deck` already refuses `$`, a backquote, a brace and a control character — never
   emit a card that will exit 1 three seconds later with no explanation.
3. **Land any change in `event_probe` too**, or the probe deck keeps the defect.
4. **Add a row.** None of the rows listed above is a deliberate test of this: they are
   collateral. A row that names a PDK path with a space and asserts what the deck emits
   would make the defect visible to T1, which it is not today.

## Still open (4)

1. No fix: the models `.include`/`.lib` cards are still emitted bare.
2. `.lib` with a space has **no measured remedy at all on ngspice 45.2** for a library
   outside the deck's own directory (relative works only when they share one; quoting works
   only on the fork, 46+).
3. `event_probe`'s duplicate emission is documented in a code comment and otherwise
   untouched, so a fix applied in one place will leave the other.
4. No dedicated row, and no end-to-end measurement with a real PDK under a spaced path.

## Evidence

`doc/claude/stranger_reds_batch/receipts/C-impl.md` §7.1 (the original finding), §F1.2 (the
per-character `.include` table), §F3 (the three-tree census), §F4.1 (the `EE5` refutation),
§F5 (the apostrophe tree) and §F7.2 (the two corrections and the relative-`.lib`
measurement); `receipts/C-verify.md` §1.5 (the quoting table, re-measured) and finding
**F3** (that this was written down but not filed);
`doc/claude/stranger_reds_batch/DECISIONS.md` **D8**.
Code: `ase::backend::ngspice`'s models-list emission, `opstate_lines`, `event_probe`,
`path_quoted` and `path_bare_ok`, all in `src/ase.tcl`.
