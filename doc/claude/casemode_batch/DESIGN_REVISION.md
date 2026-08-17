# Design revision — stop folding on read, make the lookup case-insensitive

Written 2026-08-16, during the pre-item-1 Q&A. Supersedes `PLAN.md` §D1, §D2,
§5.6 and reshapes items 1, 2, 3 and 5. Nothing implemented yet.

**Origin.** The user asked, of question B2: *"Why do we care about the case of a
user opening a `.raw` directly? The file itself is the source of data to plot.
How does the `v(en)` vs `v(EN)` question arise?"*

That question is correct, and following it through produces a smaller and better
design than the plan had. This document records the reasoning, the code
evidence, and what it changes.

---

## 1. What the fold actually does — it is not about display

`get_raw_index()` (`src/save.c:2251`) is the one lookup everything goes through.
It transforms **the query** and looks the result up in a hash table of the
**stored** names:

```
try  v(EN)  ->  V(EN)  ->  v(en)  ->  v(v(EN))   [+ an "i(v.x" special case]
```

Today `read_dataset()` folds every stored name at `src/save.c:1008`. So:

| stored | query | outcome |
|---|---|---|
| `v(en)` | `v(en)` | hit, first rung |
| `v(en)` | `v(EN)` | hit, on the lowercase rung |

Both resolve. **That is the entire purpose of the fold** — not display, but
making queries from elsewhere still resolve.

Remove the fold naively and:

| stored | query | outcome |
|---|---|---|
| `v(EN)` | `v(EN)` | hit |
| `v(EN)` | `v(en)` | **miss** — every rung transforms the query; none matches a stored capital |

A schematic saved years ago with `node="v(en)"` in its graph settings silently
stops finding its trace. That is the regression the plan's `case_mode` gate was
designed to avoid, by keeping the fold on unless the user opted in.

## 2. Which paths actually need the mode

| path | where the name comes from | needs the mode? |
|---|---|---|
| open a raw, browse its list, click to plot | the file itself | **no** |
| `.sch` graph `node=` attribute | stored earlier, possibly folded | yes |
| cross-probe from schematic (Ctrl-K, `hilight.c`) | the schematic | yes |
| a typed expression | the user | yes |
| backannotation (`token.c`) | the schematic | yes |

The user's point stands exactly: the pure browse-and-plot path never leaves the
file's own spelling, so no mode is required there. The mode is only needed where
a name arrives from **outside** the file.

## 3. Three readers, three different policies — today

This is the finding that makes the revision obvious.

| reader | policy | site |
|---|---|---|
| `read_dataset()` — spice raw | **folds** | `save.c:1008` |
| `vcd_read()` — VCD | **verbatim** | `vcd_read.c:656` |
| `table_read()` — table | **verbatim** | `save.c:2119` |

Two of the three already store verbatim. And `vcd_read.c:140` carries an
explicit apology for the consequence:

> NAMES ARE STORED VERBATIM — a deliberate divergence from `read_dataset()`,
> which `strtolower()`s every variable name … The cost is that
> `get_raw_index()` probes verbatim, then uppercased, then lowercased, so a
> lower-case query does not find a mixed-case VCD name — the caller must use the
> name the browser shows.

So the mismatch this revision fixes is **already shipped and already
documented as a known cost**. The plan filed it separately as §5.6 / item D2, a
"deliberate sub-step with its own checks". Under the revised design it is not a
separate sub-step; it is the same fix.

## 4. The revised design

**Three rules.**

1. **All readers store names verbatim.** Delete the `strtolower(varname)` at
   `save.c:1008`. `vcd_read` and `table_read` already comply.
2. **The lookup becomes case-insensitive, exact-match-first.** After the
   verbatim rung and before the `v()`-wrap rung, try a case-folded match against
   the stored names.
3. **A per-`Raw` flag turns rule 2 off**, and only `distinguish` sets it. That
   is the mode's entire remaining job.

### How rule 2 is implemented

`raw->table` is an `Int_hashtable` keyed on the exact name. The cheapest correct
route is to **insert a second, folded alias entry** for any name that is not
already all-lowercase, with `XINSERT_NOREPLACE` so the first spelling wins.
Lookup then becomes: exact → folded query → existing rungs.

**Verified safe:** nothing in the tree enumerates the contents of `raw->table`.
The only references are `int_hash_init` (`save.c:1255`, `:1408`, `:2069`;
`vcd_read.c:644`) and `int_hash_free` (`save.c:1103`). Every listing — including
`xschem raw list` (`scheduler.c:10427`) — iterates `raw->names[]`, not the
table. So alias entries are invisible to every consumer and cannot appear as
phantom signals.

Cost: one extra hash entry per mixed-case name. Zero for a stock ngspice file,
where every name is already lowercase.

> **CORRECTION, 2026-08-16 (item 2).** The *mechanism* above is wrong in two
> ways; the *rule* and the invisibility argument are right and are what shipped.
> (a) The aliases cannot live in `raw->table`. D2 (adopted after this document
> was written) requires a colliding key to resolve to NOTHING, and the folded
> key of `v(EN)` in a database that also holds `v(en)` **is** a real stored
> name, so poisoning it would break the exact lookup D2 promises to leave alone;
> `raw_add_vector()` also tests that table for existence and would silently
> refuse a genuinely new vector, and `raw_renamevar()`/`raw_deletevar()` delete
> by `entry->token` and would delete the alias instead of the entry. So the
> index is a **second** table, `Raw.fold_table`. (b) `XINSERT_NOREPLACE` "so the
> first spelling wins" is exactly the guess D2 forbids. (c) It is built
> **lazily**, so the cost is zero rather than small for the stock case, and it
> must be **dropped** whenever `names[]` moves — `raw_deletevar()` re-indexes,
> and a surviving alias would return the wrong column. Full reasoning:
> `doc/claude/specs/raw_case_mode.md` §9.

### What the mode is still for

Only this: under `distinguish`, `EN` and `en` are two genuinely different
signals, so a folded fallback could return the wrong one. The flag suppresses
the alias insertion and the folded rung. Nothing else in the read path consults
it.

## 5. What visibly changes, and for whom

| user | today | after | changed? |
|---|---|---|---|
| stock apt ngspice | `v(en)` | `v(en)` | **no** — stock ngspice writes everything lowercase, so the fold is already a no-op (verified against a live run and both fixtures) |
| VCD files | verbatim | verbatim | **no** — but a lowercase query now resolves, which it did not before |
| table files | verbatim | verbatim | **no** — same lookup improvement |
| case-capable ngspice, `preserve` | `v(en)` | `v(EN)` | **yes — this is the feature** |
| Xyce | folded to `v(en)` | whatever Xyce wrote | **yes**, and this is the one unintended change |

**The Xyce row is the only unintended behaviour change, and it is unverified.**
The plan asserts Xyce writes `V(EN)` uppercase; there is no Xyce on this machine
and we have not measured it. Two things follow:

- Treat it as an open item, not a fact. Either obtain a Xyce raw to measure, or
  leave the fold in place for files whose header identifies Xyce.
- Note that a Xyce raw already gets one transformation applied
  (`:` hierarchy separators rewritten to `.`, `save.c:1010-1014`), so there is
  already a Xyce-shaped branch to hang a decision on.

## 6. One consumer that must keep folding

`ngspice::ngspice_data` is a **Tcl array published to scripts**, and its keys
come straight from `raw->names[i]` — `callback.c:1465` and `save.c:2013`. Tcl
array keys are case-sensitive, so if the stored names gain capitals, every key
in that array changes and `ngspice_backannotate.tcl` (and any user script
reading `$ngspice::ngspice_data(v(en))`) breaks.

**Ruling: keep publishing `ngspice_data` keys folded.** It is a published
interface, not a display surface, and decoupling it costs one `strtolower` at
the two publish sites. This also means plan §5.7 — "backannotation is left
folding and keeps working" — stays true for a better reason than the lookup
ladder's fallback rungs.

## 7. One consequence for the GUI override

Folding is destructive: once `v(EN)` has been lowercased to `v(en)`, the
capitals are gone from memory and cannot be recovered. So the user-facing
"read this file as `<mode>`" control must **re-read the file**, not flip a flag
on the loaded dataset.

Under the revised design this is much rarer — nothing folds on read any more, so
the only mode change that needs a re-read is toggling `distinguish`, and even
that only affects lookup, not stored names. In practice the control becomes
non-destructive.

## 8. AC files

The AC path derives three extra names per variable — `ph(…)`, `re(…)`, `im(…)`
— from `varname` **after** the fold (`save.c:1014-1035`). Storing verbatim means
those derived names carry case too, which is correct and consistent. No extra
work, but it is four names per variable rather than one, so the alias insertion
in rule 2 must cover all four.

> **CORRECTION, 2026-08-16 (item 1 fix round).** "No extra work" was wrong: it
> took one line. The derivation recognises the node inside a `v(` prefix with
> `strstr(varname, "v(") == varname`, a **case-sensitive** test that only ever
> matched because the fold had just lowercased `varname`. With the fold gone and
> the test untouched, a variable spelled `V(Out)` derived `ph(V(Out))` — a
> different STRING, not a differently-cased one — so `xschem raw index ph(Out)`
> returned `-1`, and rule 2's folded-alias rung could never repair it (folding
> `ph(V(Out))` yields `ph(v(out))`, never `ph(out)`). Uppercase `V(` is exactly
> the shape §5 and §10.1 believe Xyce writes. The prefix test is now
> case-insensitive; `varname` itself is still stored verbatim. See
> `doc/claude/specs/raw_case_mode.md` §8 and checks CS29–CS29d.

## 9. What this does to the plan

| plan item | was | becomes |
|---|---|---|
| **1** | `Raw.case_mode` (3-valued) + gate `read_dataset`'s fold on it | delete the fold outright; `Raw` gains a **boolean** `case_sensitive`, set only by `distinguish` |
| **2** | three-valued lookup ladder per mode | one ladder: exact → folded → `v()` wrap → `i(v.x` fixup, with the folded rung suppressed when `case_sensitive` |
| **3** | `sim_case_mode` global + `auto` sniff for the File→Open-raw path | **mostly disappears** — that path no longer needs a mode. What survives is the *requested* mode for runs, which lives on the simulator profile (B1) |
| **5** | viewer Tcl consults `xschem raw case` | still needed, but only for `distinguish` |
| **§5.6 / D2** | separate deliberate VCD sub-step | **absorbed** — same fix, no separate step |
| **§5.7** | backannotation survives via the ladder's fallback rungs | survives because `ngspice_data` keys stay folded (§6) — a stronger guarantee |

Net effect: items 1 and 2 get simpler, item 3 shrinks a lot, D2 disappears as a
separate unit, and the `auto` sniff question (B2a) loses most of its weight
because the read path no longer needs to guess anything.

> **CORRECTION, 2026-08-16 (item 3).** Row 3's "what survives is the *requested*
> mode for runs" is one of two things that survived, and the smaller one. The
> other is **B2a's four-source resolution**, and it survived as a **reporting**
> surface rather than a behavioural one: `xschem raw casemode` answers what mode
> a loaded file was written in — explicit setting → `Option: casemode=` header →
> schematic-name comparison → capital sniff — and **writes nothing**. That is
> what B2b is for: the behaviour under `unknown` is still fold, and the point is
> that the UI can say "mode unknown" instead of asserting a fact nobody
> established, and that a later fallback has something to hang off. The
> requested mode does live on the profile (item 6), with a validated global
> **floor** (`sim_case_mode`, default `fold`) underneath it for the no-profile
> path — and that floor is deliberately unreachable from the file resolver, so
> it can never turn an unknown file into a confident `fold`. Full contract and
> the measurements behind the header parse: `doc/claude/specs/raw_case_mode.md`
> §10; checks `CS50`–`CS64f`.

## 10. Open items this revision creates

1. **Xyce is unverified** (§5). Measure, or keep a Xyce-specific fold.
2. **Does any committed test assert a lowercase name from a VCD or table
   file?** Roughly 20 headless suites touch `raw read`/`raw list`. The
   "audit diff must be empty" rule means this needs a sweep before item 1, not
   after.
3. **`get_raw_index`'s `i(v.x` fixup** (`save.c:2274`) still hardcodes lowercase
   and still needs the case-aware treatment planned for item 2, plus the
   `@dev[param]` shape (`i(@R.X1.Rq[i])`) that round 3 found.

   > **CLOSED by item 2, 2026-08-16.** The rung is now
   > `my_strncasecmp(node, "i(v.x", 5)` — case-blind, and **anchored**: the old
   > `strstr()` matched anywhere but rewrote `inode[2]`/`inode[3]` regardless,
   > so a match at any other offset probed a garbage string. The root cause was
   > wider than "hardcodes lowercase": the whole ladder mutated its query buffer
   > in place, so the `v()` wrap and this rung both saw a lowercased query and
   > never the caller's spelling. The ladder no longer mutates. The
   > `@dev[param]` shape needs no rung of its own — it is an ordinary stored
   > name that rungs 1–2 resolve in any casing. See
   > `doc/claude/specs/raw_case_mode.md` §9, checks CS38c–CS38h, CS39b–CS39h
   > (the fixture carries a **bait** column `i(.x1.vp)`, the exact string the
   > unanchored rewrite produces, without which CS39f cannot fail).

4. **Alias collisions.** Two stored names folding to the same key is impossible
   for a spice raw under `preserve` (identity folds in the simulator) but is
   possible for VCD, where `Count` and `count` are legitimately two signals.
   `XINSERT_NOREPLACE` makes the first win; decide whether that silent
   first-wins is acceptable or wants a diagnostic.

   > **CLOSED — by `DECISIONS.md` D2 (no alias when two names collide), and
   > implemented in item 2.** First-wins was rejected: it answers a `COUNT`
   > query with an arbitrary `Count`. Both colliding names lose their alias;
   > exact lookups are untouched. Two consequences this section did not
   > anticipate, both recorded in `specs/raw_case_mode.md` §9: the rule cannot
   > be implemented inside `raw->table` at all (the poison value would destroy
   > the exact entry of whichever real name *is* the folded key, and
   > `raw_add_vector`/`raw_renamevar`/`raw_deletevar` would misread alias
   > entries), so the alias index is a **separate lazily-built table**; and
   > byte-identical duplicate names — which ngspice upstream `0073` really does
   > write — are deliberately **not** a collision.
