# 0452 — Edit Properties' `hide` checkbox destroys an annotation class

Status: OPEN, measured, deliberately NOT fixed by S7.
Filed by: S7 (annotation classes). Blast radius grew the moment S7 landed.

## What

`src/property_form.tcl:115` declares the text `hide` token as
`[dict create tok hide label {Hidden} widget bool on true]`, and
`slickprop::bool_checked` (:267-277) returns 1 for ANY non-empty, non-false
value. So the dialog models a token that now has FOUR meaningful values
(`true`, `instance`, `op`, `voltage`) as a two-state checkbox.

Measured on this tree, before S7:

* a text carrying `hide=op` or `hide=voltage` ticks the "Hidden" box — a lie
  even then, because both rendered visibly;
* the raw value survives an untouched OK (the dialog only rewrites tokens the
  user actually changed);
* removing the token and putting it back -- untick, OK, reopen, tick -- does not
  restore `hide=op`: it writes `hide=true`, permanently.

## Why it matters more now

Before S7 the rewrite was inert: `hide=op` set no flag bit (strboolcmp,
util.c:72), so `op` and `true` differed only on disk. After S7 they are
different classes with different gates, and the rewrite silently converts an
annotation into an unconditional hide that no `annot_show` setting can bring
back. That is silent data loss on a shipped dialog.

## Why S7 did not fix it

S7's brief is "ONE commit, no behaviour change mixed in", and turning the bool
widget into a choice widget changes a shipped dialog's contract. Decision D6.
The CURRENT wrong behaviour is pinned by rows PF-S7a..d in
`tests/property_form/body.tcl`, so that fixing it reds a named line rather than
silently changing an unasserted behaviour.

## Fix sketch

Give `hide` a `widget choice` with values `{} true instance op voltage`, or a
bool plus a class selector. Whichever shape wins, the round-trip of an untouched
non-boolean value must stay byte-identical.
