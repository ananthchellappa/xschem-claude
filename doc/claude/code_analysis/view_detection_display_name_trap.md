# Tutorial — one truth, one oracle: don't re-derive state from a display string

A short, transferable lesson from issue 0140 (Add-Pin dead in a library-manager symbol view). The
topic is bigger than xschem: **when two pieces of code must agree on the same fact, they must read
the same source of truth. Re-deriving that fact from a human-facing projection — a display name, a
title, a formatted label — silently disagrees the moment the projection is lossy.** The concrete
case is "is the current view a symbol?", decided one way in C and another way in Tcl.

## 1. The setup: a view-aware form that picks one of two verbs

The Add-Pin form (`p`) does different things per view. In a **symbol** view a pin is a PINLAYER
rect; in a **schematic** view a pin is an ipin/opin/iopin instance. So the Tcl form chooses the C
verb by asking "which view am I in?":

```tcl
# src/xschem.tcl  (before)
proc addpin::place_verb {} {
  return [expr {[string match {*.sym} [xschem get current_name]] ? "add_symbol_pin" : "add_sch_pin"}]
}
```

Looks reasonable. Symbol files end in `.sym`; match the name, pick the verb. It even passed its
tests, and it worked every time the author tried it — on a fresh `untitled.sym`.

The C side already had its *own* answer to the same question, used by the verb it guards:

```c
/* src/actions.c */
int editing_symbol_view(void) {
  const char *s = xctx->sch[xctx->currsch];        /* the REAL loaded file path */
  size_t len = strlen(s);
  return (len >= 4 && !strcmp(s + len - 4, ".sym"));
}
/* src/scheduler.c: add_sch_pin -place refuses in a symbol view */
if(editing_symbol_view()) { Tcl_ResetResult(interp); return TCL_OK; }   /* no-op */
```

Two functions, one question, **two different inputs**: the Tcl form reads `current_name`; the C
guard reads `xctx->sch[currsch]`. Nobody noticed they weren't the same string.

## 2. The bug: the display name is a lossy projection

`xschem get current_name` is what the **user sees** — a title-bar reference, deliberately made
portable and short. For a symbol that lives inside a registered library, `rel_sym_path` routes
through `lib_qualified_rel` (library_defs.tcl), which returns the Cadence-style **`lib/cell`** form
and **drops the extension**:

```tcl
if {[regexp {^([^/]+)/symbol/([^/]+)$} $rest -> cell file]} {
  if {[file rootname $file] eq $cell ...} { set best "$lname/$cell" }   ;#  <- no .sym
}
```

So the same symbol, opened two ways, has two display names:

| opened as | `current_name` | `*.sym` match | `editing_symbol_view()` |
|---|---|---|---|
| File → New Symbol | `untitled.sym` | **1** | 1 |
| from a library (existing, or "Make symbol from schematic") | `mylib/cell` | **0** | 1 |

`editing_symbol_view()` is right both times (the file on disk is still `…/cell.sym`). The string
match is right only when the display name happens to keep the extension. In a library it doesn't, so
`place_verb` returned `add_sch_pin`, the schematic verb — which the C guard **correctly** refuses in
a symbol view. Net effect: the form armed a verb that did nothing. No `START_SYMPIN`, no cursor
preview, no drop. The user typed a name, clicked, and nothing happened.

The failure is invisible because both sides are individually "correct": the string match faithfully
reports what the *name* says; the guard faithfully refuses a schematic pin in a symbol. The bug lives
in the **gap between two oracles**, not in either one.

## 3. Why the masking made it worse

The one view that keeps `.sym` in its display name is the untitled scratch symbol — exactly the view
a developer reaches for when "just testing add-pin." So the happy path and the tested path were the
*only* paths where the two oracles agree. The feature shipped green. The bug waited for a real
library symbol, which is the *normal* case for an actual user. **A heuristic that agrees with the
truth on your test fixtures and diverges on real data is worse than an obvious bug — it buys a false
green.**

## 4. The fix: expose the real oracle, delete the proxy

Don't teach Tcl to re-derive symbol-ness from a name it can only see in projected form. Give it the
authoritative function the C guard already uses.

```c
/* src/scheduler.c — xschem get editing_symbol_view */
else if(!strcmp(argv[2], "editing_symbol_view")) {
  Tcl_SetResult(interp, my_itoa(editing_symbol_view()), TCL_VOLATILE);
}
```

```tcl
# src/xschem.tcl  (after)
proc addpin::place_verb {} {
  return [expr {[xschem get editing_symbol_view] ? "add_symbol_pin" : "add_sch_pin"}]
}
```

Now the form and the guard read the **same** `xctx->sch[currsch]`. There is one oracle. The display
name is never consulted for a control decision — only for display.

## 5. The transferable rules

1. **One fact, one source of truth.** If code A guards a decision and code B routes to A, both must
   read the same underlying state. Two functions computing "the same" boolean from two different
   inputs is a latent disagreement, not a coincidence.
2. **A display string is a projection, not a fact.** Names, titles, and labels are lossy on purpose
   (they're shortened, localized, made portable). Never recover a control-flow boolean from one.
   `string match`/regex on a user-facing name is a smell wherever the answer already exists as state.
3. **When C owns the truth, expose it — don't re-implement it in the other language.** The cheap,
   correct move here was one `xschem get` accessor, not a smarter Tcl string test. A re-implementation
   inherits none of the original's future fixes and drifts on the first edge case (here: libraries).
4. **Test the real shape, not the convenient one.** `untitled.sym` was the fixture *because* it was
   easy to spin up — and it was the single input where the wrong oracle looked right. If a code path
   fans out by data shape (library vs plain file vs untitled), the test matrix must include each
   shape, especially the one that matches production.
5. **Mind the dispatch you're extending.** The `xschem get` handler is a `switch(argv[2][0])` — an
   accessor added under the wrong first-letter `case` compiles fine and silently returns `""`. During
   this very fix the branch first landed in `case 'c'` (next to `current_name`) and `get` returned
   empty; the symptom of a mis-cased branch is "the feature is just gone," not a compile error.
   (See the scheduler letter-dispatch discipline.)

The one-line version: **if the truth already exists as state, read the state — never reverse-engineer
it from the label you printed for a human.**
