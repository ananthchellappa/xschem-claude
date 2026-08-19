# 0503 — a `fold`-picked output row goes stale under a later `distinguish` profile

**Status:** OPEN, **NARROWED by casemode item 10** (2026-08-17) — the silent
half is gone, the staleness is not. See "What item 10 changed" below.
**Area:** ASE-L write path (`src/ase_window.tcl` `sod_click` / `sod_expr`,
`src/ase.tcl` `render_deck`).
**Spec:** `doc/claude/specs/simulator_profiles.md` §13.5b, §13.1, §13.6.
**Plan:** `PLAN.md` §D3 (the property this trades away), §D5 (which allows the
repair to be deferred behind a filed issue — this one).

## What happens

Casemode item 9 made `ase::ui::sod_expr` fold **only** when the run's requested
case mode is `fold`, and resolves that mode at **pick** time
(`ase::ui::sod_case_mode`, once per gesture). The composed string is what gets
stored in the session's output row, and `render_deck` emits it verbatim:

```tcl
  ## src/ase.tcl, render_deck
  .save [dict get $o expr]
```

So a row picked while the profile said `fold` stores `v(topnet)` permanently. Point
that same session at a `distinguish` profile afterwards and the deck ships
`.save v(topnet)` for a net drawn `TOPNET`. Measured (`PLAN.md` §F2, and
re-measured on `ver_50` twice in item 9's review):

```
.save v(topnet)  under casemode=distinguish
  -> rc=1, 570-byte raw with no vectors,
     "Error: no data saved for Transient analysis; analysis not run"
```

That is not a mis-labelled trace. It is **every trace in the session**, gone.

## Reproducer

Real `ase::session_open`, real `ase::ui::sod_click`, real
`[ase::backend_hook ngspice render_deck]`; no stubs on the write path:

1. open a session on `tests/headless/fixtures/ase_hier`;
2. set the spice tool's resolved profile row `casemode` to `fold`;
3. `ase::ui::sod_click S 50 0` on the `TOPNET` wire
   → session output row `{name {} expr v(topnet) plot 0 save 1}`;
4. set the SAME row's `casemode` to `distinguish`;
5. render the deck
   → `.save v(topnet)` / `print v(topnet)`.

Item 8 does **not** refuse this run: requested == measured == `distinguish`, so
its mismatch policy has nothing to complain about.

## Why item 9 did not fix it

`PLAN.md` §D3 prescribed the fold-free shape precisely to avoid this — "it does
not need to know the mode", so "a state file written today is correct under a
simulator installed tomorrow". The driver's **A1** instruction outranked it: every
shipped expression under `fold` must stay byte-identical, `fold` is the default at
every stage, and the batch's audit-diff contract for items 1–9 is empty. A
mode-conditional fold is the only shape that satisfies both A1 and the
`distinguish` requirement. Declared in spec §13.5b.

## The repair, when someone takes it

A **distinguish-only re-case pass** at run time (`PLAN.md` §D5): before rendering,
re-derive each output row's expression from the schematic's own spelling in the
mode about to be requested, rather than trusting the mode it was picked in. The
raw ingredients already exist — `sod_qualify` answers mode-free in the schematic's
spelling and `sod_expr` does the whole mapping — but the row stores only the
finished string, so the pass needs the row to also carry the *unmapped* token
(kind + qualified name), or needs to re-resolve it.

**Until then**, item 10's pre-flight is the mitigation: a folded expression is
absent from a case-kept netlist map, so the pre-flight sees it and must **refuse
the run and say why**, never pass it through. Whoever builds the re-case pass
closes this issue.

## Not this issue

- A mode switch under `fold` or `preserve` is harmless — `preserve` accepts the
  folded spelling (upstream `0056`) and `fold` is what the row already holds.
- The Outputs pane's echo mismatch (requested `preserve`, measured `fold`) is
  casemode item 11's `result_probe -nocase`, spec §13.6.

## What item 10 changed (2026-08-17) — and why this stays OPEN

Item 10's pre-flight (`ase::preflight_gate`, spec §14.2/§14.6) is the mitigation
§13.6 assigned it, and it is built and driven end to end
(`tests/headless/test_ase_preflight.tcl` `PF217`, `PF217b`):

* the folded row is **absent** from a case-kept netlist map, so the run
  **REFUSES** before any deck, raw or log is written;
* the refusal names every stale row, offers the netlist's own spelling for each
  (`v(topnet)` → `v(TOPNET)`, `-i(v.x1.x2.v1)` → `-i(V.x1.x2.V1)`, the branch
  prefix re-derived from the device's first character), and names this issue;
* `ase::preflight_fix_session <key>` applies those corrections to the session's
  output rows **on an explicit call** — D1's "on confirmation", never a silent
  rewrite (`PF217d` asserts the gate alone rewrites nothing).

**So the silent-wrong-answer half of this issue is closed: a stale row can no
longer produce a clean-looking run with no data.**

**It stays OPEN because the repair this issue asks for is a different thing.**
The repair is a *re-case pass*: re-derive each row's expression **from the
schematic**, in the mode about to be requested, so a stored row is never stale.
What item 10 built is a confirmation-gated repair of a session that has *already*
gone stale, derived from the **netlist**, and it therefore inherits the netlist
map's blind spots (spec §14.2): an identifier scoped inside an `.include`d PDK
subcircuit, an `@dev[param]` name, or a bus bit resolves to `unknown`, so a stale
row of that shape is neither refused nor corrected. Whoever builds the re-case
pass — the row carrying its unmapped token (kind + qualified name), or
re-resolving it at render time — closes this.

**Fix round, 2026-08-17 — the mitigation reaches TWO more shapes, and the issue
is still open for the same reason.** Reviewers of item 10's first cut found the
mitigation had two holes squarely in this issue's own territory, both now fixed
and driven:

* a **mis-cased hierarchy segment** (`v(x1.out)` where the netlist spells the
  instance `X1`) resolved `present` on the strength of its correctly-cased leaf,
  so the pre-flight passed a stale `0503` row through in silence — while the
  case-keeping binary aborts that analysis (`rc=1`, `RUN-FAILED`, no raw).
  Any segment that comes back a fold-only hit now makes the whole identifier
  `absent`, carrying the whole-path correction (`PF221f`–`PF221i`);
* a stale row of the **differential** shape `v(a,b)`, or a **derived** row with
  two mis-cased identifiers, was refused with a correction that could not be
  applied: the offer was built by a literal `string map` of `v(<ident>)`, which
  matches nothing inside `v(a,b)` and could rewrite only the first identifier of
  a derived row while still reporting success. The offer is now composed by
  identifier POSITION and repairs a row whole (`PF221x`–`PF221ab`).

Also narrowing the blind-spot list quoted above: a name in an `.include`-bearing
scope is `unknown` **only when nothing in that scope even folds to it**; a fold
hit — which is precisely this issue's shape — still refuses and still offers the
correction (spec §14.2).

**Still open, unchanged in kind**: this remains a confirmation-gated repair of a
session that has already gone stale, derived from the netlist. The re-case pass
the issue asks for — the row carrying its unmapped token, or re-resolved from
the schematic at render time — is what closes it.
