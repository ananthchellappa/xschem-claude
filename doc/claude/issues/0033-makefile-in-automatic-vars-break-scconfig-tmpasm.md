# Issue 0033 — make automatic vars (`$@`/`$<`) in `src/Makefile.in` corrupt scconfig `tmpasm` generation → 0-byte `src/Makefile`

**Opened:** 2026-06-25
**Status:** ✅ RESOLVED (2026-06-25). Spell out filenames in the recipe instead of `$@`/`$<`.
Fixed on `fluid-editing` in `de04e5a0` (when the CIW-autocomplete feature was ported, commit
`b976619f`) and on `feature/autocomplete` itself in `22b93990`.
**Affects:** `src/Makefile.in` (the `xschem_subcommands.txt: scheduler.c` rule added by the CIW
autocomplete feature), and anyone who edits `Makefile.in` and re-runs `./configure`.
**Severity:** medium — a *silent broken build*: `./configure` writes a 0-byte `src/Makefile`, so
the next `make` fails with no obvious link back to the offending `Makefile.in` edit.
**Branch:** `fluid-editing`. See [[scconfig-tmpasm-makefile]] (memory), and the autocomplete port.

---

## 1. Symptom

After adding a new rule to `src/Makefile.in` and re-running `./configure`:

```
config.h:              ok
Makefile.conf:         ok
src/Makefile:          ERROR        <-- here
```

`src/Makefile` is left **0 bytes**, so the subsequent `make` cannot build anything. Crucially the
breakage is *latent*: a working tree that still has an old generated `src/Makefile` from a previous
`configure` keeps building fine, so the bad `Makefile.in` edit can sit unnoticed until the next
`configure` (a fresh checkout, a `configure` flag change, a CI clean build, …).

## 2. Root cause

`src/Makefile` is **generated from `src/Makefile.in` by scconfig's `tmpasm`** template processor
(`./configure` → `scconfig/hooks.c`: `tmpasm("../src","Makefile.in","Makefile")`). `tmpasm` uses
the **at-sign as its paired substitution delimiter** — the template is full of `@…@` pairs, e.g.:

```make
put /local/obj [@@/local/src@ @]
OBJ = @/local/obj@
@/local/o@: @/local/n@
	$(CC) -c $(CFLAGS) -o @/local/o@ @/local/n@
```

Every hand-written rule in the file therefore **spells out filenames** to avoid emitting a bare
at-sign. The CIW-autocomplete feature added a rule whose recipe used make's automatic variables:

```make
xschem_subcommands.txt: scheduler.c
	grep ... $< | sed ... > $@          # <-- $@ contains a lone at-sign
```

`$@` (the make "target" variable) is a `$` followed by an at-sign. To `tmpasm` that lone at-sign
looks like the *opening* of an `@…@` substitution; it scans forward to the next at-sign, swallows
everything in between, and the template falls apart → generation aborts → 0-byte output. `$<` is
harmless (no at-sign), but `$@` is fatal.

The upstream `feature/autocomplete` branch never tripped this because **it never re-ran
`./configure` after adding the rule** — it built against a `src/Makefile` generated before the rule
existed. The bug only surfaced when the feature was ported to `fluid-editing` and `configure` was
re-run to pick up the new rule.

## 3. Fix

Spell out the filenames, matching every other rule in the file:

```make
xschem_subcommands.txt: scheduler.c
	grep ... scheduler.c | sed ... > xschem_subcommands.txt
```

A guard comment was added at the rule — **itself written entirely without an at-sign**, because a
literal `@` (or `$@`) anywhere in `Makefile.in`, *including in a comment*, breaks `tmpasm` the same
way. (`tmpasm` does not understand make's `#` comments; it scans the whole file for `@`.) The first
attempt at the comment used the characters `$@` and `@…@` to *explain* the rule and re-broke
generation — the warning has to practise what it preaches.

## 4. How it was diagnosed / verified

- `./configure 2>&1 | grep -E 'src/Makefile:'` → `ERROR` (vs `ok`); `wc -c src/Makefile` → 0.
- Bisected by reverting `Makefile.in` to the pre-port version → `ok`; so the new rule was the cause.
- Confirmed the mechanism: every existing rule avoids `$@`/`$<`; the only new at-sign was `$@`.
- Verified the fix by regenerating: `src/Makefile` comes back non-empty with the rule present, the
  build runs the rule (276-entry `xschem_subcommands.txt`), and the autocomplete + base CIW headless
  tests pass. (On a git *worktree*, `./configure` aborts earlier on an unrelated scconfig/xcb
  assertion, so the fixed `Makefile.in` was validated by generating it in the main checkout.)

## 5. Prevention / best practices

- **Editing a generated-from-template file? Re-run the generator before trusting it.** A green build
  earlier in a session may just be reusing a stale generated artifact; `./configure` is what surfaces
  a latent `Makefile.in` error. Treat "I changed `Makefile.in` and it still builds" with suspicion
  until you have re-`configure`d.
- **Respect the template's reserved characters.** In a `tmpasm`-processed file the at-sign is
  reserved; never introduce a bare one — not in a recipe (`$@`), not in a comment, not in an echoed
  string. When in doubt, copy the shape of an existing rule (they all spell out filenames for exactly
  this reason).
- **A warning comment lives under the same constraints as the code it documents.** Don't quote the
  forbidden token to explain it; describe it in words ("the at-sign", "make's target variable").
- **Don't trust a feature branch's build hygiene just because its tests pass.** The autocomplete
  tests were green because the data file existed; the *generation path* (Makefile.in → configure)
  was never exercised on that branch. Porting work should re-run the full configure+build, not just
  the feature's own tests.

## 6. Notes

This is the kind of defect that is invisible in code review of the diff (the rule reads as perfectly
ordinary make) and invisible to the feature's own test suite — it only exists at the
template-processing layer, and only fires when the generator is actually run. The fix is trivial; the
lesson is about *when* breakage becomes visible, not about the one-line change.
