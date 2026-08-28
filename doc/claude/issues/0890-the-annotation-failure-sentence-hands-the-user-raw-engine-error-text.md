# 0890 — the annotation failure sentence hands the user raw engine error text

**Status:** **OPEN**, and **latent as far as I could measure** — see the negative
result below, which is the useful half of this file. Found by the item A11
verification pass, re-measured at write-up 2026-08-28. Wording, not behaviour.

## The sentence

`src/ase_window.tcl`, minted once (that part is 0886's D5-4 fix and is correct):

    proc ase::ui::annot_fail_msg {path e} {
      return "ase: could not put the results from '$path' onto the schematic. The reason given was: $e"
    }

Both call sites (`src/ase_window.tcl:2392` and `:2396`) pass `$e` straight from

    catch {xschem annotate_op $path …} e

The frame is plain English. `$e` is not: it is whatever the engine raised,
un-translated, spliced into a user-facing line. The house standard 0886 was
written to (*"no internal vocabulary anywhere the user can see it"*) does not
survive a clause the mint does not control.

## The negative measurement, so nobody re-derives it

**I could not make `xschem annotate_op` raise at all.** On the shipped binary,
2026-08-28:

| call | result |
|---|---|
| `annotate_op /tmp/definitely_not_here_zz/run.raw 999999` | rc 0, no raise |
| `annotate_op` (no path — falls back to the preferences path) | rc 0, no raise |
| `annotate_op <path> notanint` | rc 0, no raise |
| `annotate_op <path> a b c` | rc 0, no raise |

It writes its complaint to stderr instead —

    raw_read(): failed to open file /tmp/definitely_not_here_zz/run.raw for reading
    extra_rawfile() read: … not found or no "op" analysis

— and returns success. That is consistent with `cadence::annot_mode`'s own
recorded finding (`utils/annot_mode.tcl`): *"RE-ASKED, never taken from
annotate_op's rc: measured, it returns 0 for a file that does not exist and for
one that will not parse."*

So this sentence is very likely **unreachable today**, and that is the second
half of the finding: a user-facing sentence exists for a condition the engine
never signals, and if the engine is ever made to raise — which the `catch` here
plainly expects — the first thing the user will read is C-function text.

## What to do

Two independent pieces, either order:

1. Give the clause a translation layer, or drop `$e` from the user's sentence and
   send it to the log instead: *"ase: could not put the results from '<path>'
   onto the schematic. See the log for what the reader reported."*
2. Decide whether the `catch` should stay at all, given the engine does not
   raise. If it is dead, say so in a comment rather than leaving a live-looking
   error path nobody can exercise.

## Why no row saw it

Row `A11-8` counts where the fragment appears — it is a D5-4 structural row and
it does its job. Nothing constrains what actually arrives through `$e`, and
nothing could, because no test can reach a raise either.
