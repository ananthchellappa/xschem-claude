# 0436 — save cards built from `op_annot::devpath` carry RAW-RELATIVE names, so a loaded raw silently collapses two instances onto one device path

Status: **FIXED AND VERIFIED IN S3b, THEN REVERTED WITH THE REST OF THE STEP —
the fix is not in the tree, it is preserved in
`doc/claude/issues/0442-attempt-2-reverted.patch`.**

⚠ **THE FIX IS GOOD; NOTHING HERE WAS REFUTED.** S3b built it as four named
seams and the S3b adversary attacked it along six independent lines — template
arm with a raw open two levels down, devproc arm, entry-relativity, vector
members, case folding, basis validation — and **could not break any of them**.
The step was reverted for an unrelated defect in the *filter* (issue 0442), and
this fix was carried out with it only because it lives in the same file. Whoever
retries S3 should re-apply the preserved patch rather than re-deriving this;
`git apply --check` on it was verified rc=0 against the post-revert tree, and a
round-trip was measured (apply → `ALL PASS (96 checks)`, revert → `ALL PASS (65
checks)`).

Previously: OPEN, measured, not fixed. This issue reverted step S3 (attempt 1).
Filed by the S3 write-up agent (op-annotation crew, branch `annotate`).
Found by the S3 adversary pass; reproduced independently by the write-up agent
from the C source before the revert was ordered.

Related: 0430 (the prototypes' `spiceprefix` bug — the *other* direction in which
the generic builder and the prototypes disagree), 0437 (the second defect that
reverted S3), spec §5 I1, spec §6 landmine 4.

## The claim that was refuted

S3 implemented `op_annot::save_cards`, a hierarchy walk emitting one bare
`.save [devpath][param]` card per device per descriptor parameter. Its own file
header asserted:

> So a walk run anywhere in the hierarchy emits TOP-RELATIVE names and the block
> is always a block for a deck of the TOP cell.

That is **false whenever a raw file is loaded whose `schname` matches a level
below the walk's entry** — and it is self-refuting on its own stated premise,
because the sentence immediately before it concedes that `sim_sch_path` is
"relative to the RAW LOAD LEVEL".

## The mechanism, confirmed in the C rather than inferred

Three links, none of which is visible from Tcl:

1. **`save.c:1260`, `:1410`, `:2153`** — at raw-read time,

   ```c
   my_strdup2(_ALLOC_ID_, &raw->schname, xctx->sch[xctx->currsch]);
   ```

   The raw is bound to **whatever cell the user was standing in when they loaded
   it**, not to the top of the design.

2. **`draw.c:2828-2838`** — `sch_waves_loaded()` walks *down from the current
   level* looking for a level whose schematic filename equals `raw->schname`:

   ```c
   for(i = xctx->currsch; i >= 0; i--) {
     if( !xctx->sch[i] ) continue;
     if( !strcmp(xctx->raw->schname, xctx->sch[i]) ) return i;
   }
   ```

   So the match point is **recomputed at every step of the walk**, and *any*
   level whose filename matches wins — including a second, unrelated instance of
   the same subcircuit.

3. **`scheduler.c:5150`** — `xschem get sim_sch_path` then discards everything
   above that level:

   ```c
   /* skip path components that are above the level where raw file was loaded */
   while(*path && skip < start_level) { if(*path == '.') skip++; ... }
   ```

`op_annot::devpath` → `op_annot::_simpath` → `xschem get sim_sch_path`. So every
card the walk emits inherits the stripping.

## What was measured

3-level fixture, a subcircuit instantiated **twice** from the top (`x1`, `x3`),
each containing a vector instance and a FET.

```
raw NOT loaded          -> 8 cards, 8 unique   (correct, top-relative)
raw loaded AT THE TOP   -> 8 cards, 8 unique   (correct)
raw loaded ONE LEVEL DOWN -> 8 cards, 5 UNIQUE (WRONG)
```

In the third case both `x1`'s and `x3`'s leaf device emit the identical card

```
.save @m.xa[1].xmleaf.nmyfet[id]
```

while `xschem netlist` says the real paths are `x1.xa[1].xmleaf` and
`x3.xa[1].xmleaf`. `op_annot::last_warnings` was **empty** — the wrong block is
byte-indistinguishable from a right one.

## Why this is reachable, not theoretical

The menu entry **immediately above** the one S3 added is "Annotate Operating
Point into schematic" (`src/xschem.tcl:14943`), which calls `xschem annotate_op`
with the level defaulting to the *current* level. Measured under xvfb, the two
sit at index 3 and index 4 of the same cascade. Annotate at the level you are
looking at, then click the next item down: that is the whole reproduction.

Severity is set by **R5 / issue 0434**: under the `.control … write … .endc`
idiom every shipped PDK bench uses, a card naming a device that is not in the
netlist makes ngspice write **no raw file at all**. So the generated `.save`
file does not merely mislabel some columns — it destroys the run it was
generated for. Under `ngspice -b -r` instead it fabricates a `0.0` column, which
is spec landmine 9 / **I3**'s "plausible wrong number".

## Why the prototypes are immune

`sg13g2_hier_sch_expand` (`ihp-sg13g2/sg13g2_procs.tcl:369`) and its sky130 twin
use `xschem get sch_path` with `startpath` arithmetic. `sch_path` is the plain
hierarchy path and **no raw can perturb it**. They emit entry-relative names,
which is a *different* known divergence (issue 0430's class) but is not
corrupted by simulator state.

So the regression was introduced precisely by S3's decision D9 — "call `devpath`,
never re-derive the path (I1)". That decision is right about not wanting a second
builder and wrong about the basis.

## Root cause, stated as a design fact

**`devpath` answers a READ name and a save card needs a WRITE name.**

* Reading a vector out of a *loaded* raw must be relative to the raw's level —
  that is what makes `xschem raw value` work at all.
* Writing a card into a deck that has *not been simulated yet* must be absolute
  from the deck's top — there is no raw to be relative to.

I1 said "one name builder, two consumers" and never noticed the two consumers
need two bases. That is the invariant's gap, now recorded in spec §5 I1.

## The fix (not applied — this is what the S3 retry must do)

Give the one builder an explicit basis rather than adding a second builder:

```tcl
op_annot::devpath <inst> ?basis?     ;# basis: read (default) | absolute
```

`absolute` uses `xschem get sch_path` (unperturbable) instead of
`sim_sch_path`; `save_cards` always asks for `absolute`. **Do not** put path
arithmetic in the walk — that recreates exactly the second builder I1 forbids,
and is what `startpath` was.

Cheap interim mitigation if the retry cannot afford the basis argument: have
`save_cards` push a warning through `last_warnings` (and refuse, or say so on the
status line) whenever `sch_waves_loaded()` reports a level below the walk's
entry. Today it is completely silent, which is the worst available behaviour.

## Test coverage — the reason 85 green checks missed it

```
$ grep -c 'raw_read\|annotate_op' tests/headless/test_op_annot.tcl
0
```

Every one of the S3 suite's 85 checks ran with **no raw loaded**, which is
exactly the state in which the read basis and the write basis coincide. A single
row that loads a raw one level down and asserts the cards are still unique would
have caught it. That row is now written into the plan's S3 acceptance cell.

---

# The reverted attempt — full record

`doc/claude/issues/0436-attempt-1-reverted.patch` (1032 lines, applies cleanly to
`2be60ece`). Everything below describes that patch, so the retry inherits the
reasoning and does not re-litigate it.

**What it contained:** `src/op_annot.tcl` +364 (public `save_cards`,
`last_warnings`, `write_save_file`; private seams `_cards_for`, `_descended`,
`_walk`, `_unwind`, `_restore`, `_block`), `src/xschem.tcl` +13 (one menu item
`Create device OP .save file` in the Simulation > Graphs cascade), and
`tests/headless/test_op_annot.tcl` +625 (Section S, 20 rows). Pure Tcl, no build.

**What it measured green:** 83 checks under
`--nogui --pipe -q --nolog`, 85 under `GUI_GATE=0 xvfb-run -a … --logdir`
(baseline was 65). T1 3 FAIL / 0 GOLD? / 0 RESULT? / 0 FATAL — identical to
baseline, same three pre-existing lines. T2 `HARNESS: PASS`, 6/6 goldens. The
whole `test_descend_*` family unchanged. It was refuted on **output correctness**,
not on any tier.

## Decisions, each with its ladder rung and rejected alternative

| # | decision | rung | rejected |
|---|---|---|---|
| D1 | Emit `.save all` (DOT-card), not the bare `save all` the brief and spec I2 literally said | **L1** (I2's *purpose*, rule R2) | the literal wording — measured to write no raw at all on 42 and 46+, i.e. strictly worse than omitting it. Issue 0434 |
| D2 | `save_cards` does **no** validation or filtering of what it emits | **L1** (I1) | a hardcoded invalid-param blocklist (a second policy that drifts from the descriptor); validating against a real raw at emit time (the raw does not exist yet). Consequence: sky130's `cgso`/`cgdo` reach the block — issue 0429, unratified |
| D3 | Restore `no_undo` to **0**, and probe the flag's *effect* rather than its value | **L2** | a 4-line C getter beside `scheduler.c:4898` — correct long-term, but it makes a pure-Tcl step a build step. Issue **0432** |
| D4 | Drive the descend decision off `currsch` before/after plus `descend_error`, never off `descend`'s return value; a class-1 refusal does **not** `go_back` | **L1** (I6) | porting the prototypes' arm verbatim, which the brief's "ported line by line removes most of the risk" invites. Issue **0433** |
| D5 | Unconditional catch-wrapped restore; unwind bounded by the **entry** level; `save_cards` re-raises | **L1** (I6 + 0431's prescription) | `src/xschem.tcl:3857`'s unwind-to-0 idiom (ascends past the caller); swallowing the error to return a partial block (landmine 9's fabricated zeros in another hat) |
| D6 | An empty walk returns `{}`, not a lone `.save all`; `save_cards` returns cards only, `write_save_file` adds the human header | **L2** | always emitting `.save all` (the menu would write a useless file and report success); returning the prose header from `save_cards` (S4 would have to strip it) |
| D7 | Warnings collected into `last_warnings`, not `puts`-ed; the entry `unselect_all` is kept and the selection is **not** restored | **L2** | round-tripping `xschem selected_set` — measured, it answers instance **names**, so a "restore" silently drops every wire and text |
| D8 | The walk suppresses its own action-log traffic, popped in the same unconditional restore block | **L2** | leaving the log noisy like the prototypes and filing it separately |
| D9 | Emit `devpath`'s names verbatim; do not move in the hierarchy and do not re-derive the path | **L1** (I1) | unwinding to `currsch` 0 and re-descending (destructive); refusing to run when `currsch != 0` (breaks S4). **⚠ THIS DECISION IS THE DEFECT ABOVE.** It is right that the walk must not do path arithmetic and wrong that `devpath`'s existing basis is the one a save card needs |
| D10 | Ship the new PDK-neutral menu item as-is | **L3** → status E | withholding it until 0429 is ratified |

## Sabotage matrix — 11 variants run against the attempt

| variant | predicted red | observed |
|---|---|---|
| `save_all_bare_spelling` | S2, S4, S5 | **all 3** + 3 collateral (S7/S14/S17 also assert whole-block text) |
| `cards_wrapped_not_bare` | S2, S3 | **both** + 3 collateral |
| `restore_flags_dead` | S8, S9, S10, S11, S12, S15 | **5 of 6** + S14 collateral — **S10 did not appear** |
| `restore_skipped_on_error` | S10, S11, S12 | **2 of 3** + S14/S15 collateral — **S10 did not appear**. S8/S9 stayed green **as required**, which is what proves S11/S12 are load-bearing |
| `descend_refusal_over_ascends` | S14, S15 | **exact hit, nothing else** |
| `skip_on_blank_descriptor_not_devpath` | S6, S18 | **exact hit, nothing else** |
| `derived_and_pinexpr_emitted` | S7 | **exact hit** |
| `menu_writer_dead` | S17 | **exact hit**; S19 correctly stayed green (it asserts the menu *entry*, not the writer) |
| extra: `x_swallow_error_return_partial` | S10 | **S10 red** + S13 collateral |
| extra: `x_unwind_not_bounded_by_entry` | S12 | **S12 only** — S12 is the sole guardian of the entry bound |
| extra: `x_log_suppress_not_popped` | S16 | **S16 red under xvfb+`--logdir`; ALL PASS (83) headless** |

**The two predicted reds that did not appear** (`S10` under `restore_flags_dead`
and under `restore_skipped_on_error`) were **prediction errors, not coverage
holes**: the re-raise lives in `save_cards`' own `return -options $opts $res`,
which neither sabotage touches, so gutting `_restore` cannot break propagation.
Disproved as a hole by the extra ninth variant, which turns S10 red immediately.

**The one real coverage weakness found by the matrix:** `x_log_suppress_not_popped`
— a defect that would silence the user's action log for the rest of the session —
reads **ALL PASS** under the default `--nolog` invocation. The step must ship both
invocations or that row is decoration.

## Still open (adversary residual risks, carried forward verbatim in substance)

* The basis argument is unimplemented; the retry owns it.
* `spice_ignore` instances are a second, independent source of not-in-the-netlist
  cards — issue **0437**.
* Not measured: whether `raw_level` (spec landmine 4's existing escape hatch)
  interacts with this, and what a *vector device* instance (`name=M1[3:0]` on a
  symbol carrying a descriptor) should emit. Both prototypes have the latter hole
  too.
* **`write_save_file`'s filename contradicts its own content.** Measured:
  descended one level into `vmid`, it wrote `<netlist_dir>/vmid.save` (named from
  `xschem get current_name`, the IHP idiom) whose body carried **top-relative**
  cards. `.include`d into the `vmid` testbench the filename advertises, every
  card names a device that does not exist. The prototype was self-consistent
  (entry-relative names *and* entry-relative filename); the port kept the
  filename convention and changed the name basis, and nothing reconciles them.
  Fixing 0436's basis makes the *content* right and leaves the *filename* still
  claiming a cell the block is not for — the retry must settle both.
* `save_cards` is **not re-entrant**: `_acc` and `warnings` are namespace
  variables reset at entry, so a descriptor `devproc` that itself called
  `save_cards` would clobber the outer walk. Contrived today; nothing prevents it.
* `_restore` writes `::keep_symbols` unconditionally, creating the global as 0 if
  it did not exist. Harmless in xschem (`xschem.tcl` always defines it) but it is
  state the walk did not find.
* The walk clears the user's selection by design (D7) and never restores it.
  Under X it also leaves the canvas without an explicit redraw after toggling
  `no_draw` around a descend/`go_back` round trip — **not verified on a real
  display**; the prototypes have the same shape.
* Decision **D2** (no validation) means sky130's `cgso`/`cgdo` (issue 0429) reach
  the new PDK-neutral menu item. Combined with R5's "one bad card, no raw at
  all", the item was about to ship knowingly able to produce a `.save` file that
  kills any shipped bench. That was the step's status-E question and **remains
  unanswered**: ship on bug-compatibility grounds, or correct the sky130
  registration / withhold the item until 0429 is ratified?
* The new menu item's **placement** was never ratified either: it sat in
  Simulation > Graphs only because the sibling "Annotate Operating Point into
  schematic" entry does, and the Graphs cascade is semantically about graphs. The
  alternative is the already-crowded top-level Simulation menu next to
  `Edit Netlist`.

# ============================================================================
# THE FIX, AS SHIPPED IN S3b (2026-08-16) — decisions D1/D2/D3/D4
# ============================================================================

Status of this issue: **FIXED**, with rows S20-S25 of
`tests/headless/test_op_annot.tcl` as the guardians and a four-variant sabotage
matrix proving each guardian is load-bearing.

## D1 — the basis lives ON THE ONE BUILDER, not beside it

`op_annot::devpath <instname> ?basis? ?root?`, values `read` (default, byte-for-
byte the old behaviour) and `deck`. Ladder rung L1, invariant I1.

REJECTED: a sibling proc `op_annot::deckpath` — two public names for one
decision is the drift I1 exists to forbid; and leaving the arithmetic in the
walk, which is precisely the prototypes' `startpath` this issue condemned.

## D2 — ⚠ `deck` MEANS ENTRY-RELATIVE, NOT LEVEL-0-ABSOLUTE. **This issue's own
## fix sketch proposed the other one, and it is the rejected alternative.**

This file's sketch says `absolute` = `xschem get sch_path` rooted at level 0.
S3b ruled the other way, on measurement rather than preference: **`xschem
netlist` invoked while descended into a cell writes THAT cell as the deck top**
(`**.subckt <cell>`, measured on this binary). So the deck a user simulates from
level N is rooted at level N, and only an entry-relative card names a device the
generated deck actually contains. It is also what both PDK prototypes'
`startpath` arithmetic produces — the arithmetic was in the wrong house, not
wrong — and it is what resolves this issue's own last residual below:

> **`write_save_file`'s filename contradicts its own content.**

Entry-relative content makes `<current cell>.save` honest: the file is named for
the cell it is a deck for. Row S24 asserts exactly that, and it is the row that
separates the two candidate definitions — they COINCIDE when the walk starts at
currsch 0, which is why every golden attempt 1 wrote was blind to the difference.

Rejected alternative, recorded per rung L2: level-0-absolute. It is the right
answer only for a user who always simulates from the top, and it makes the
filename lie for everyone else.

## D3 — a wrong basis is LOUD

An unrecognised basis raises naming `basis`; a `root` passed with basis `read`
raises naming `root`; and in `deck` a root that is not a prefix of the live
`sch_path` raises naming `root`. Rung L1 (this file's existing error discipline:
data conditions blank, caller bugs loud — applicable because `deck` is
unreachable from any draw / tcleval path).

This raise IS the brief's "impossible to get wrong by name" mechanism.
REJECTED: silently defaulting an unrecognised basis to `read`, which reproduces
this issue's failure shape exactly — a caller asks for the write name, gets the
read name, and nothing anywhere says so.

## D4 — ⚠ THE HALF THIS ISSUE DID NOT RECORD: `@path` IS A SECOND RAW-RELATIVE
## SOURCE, AND IT LIVES IN THE C

`@path` inside `xschem translate` (`token.c:4719`) is a byte-for-byte copy of
`sim_sch_path`'s stripping loop (`scheduler.c:5150`) — same skip counter, same
`sch_waves_loaded()` start level. gf180's and IHP's descriptors are `@path`
TEMPLATES while sky130's is a `devproc`. **A fix that swapped only
`op_annot::_simpath` would pass every sky130 test and leave gf180 and IHP
silently raw-relative.** So the `deck` basis `string map`s `@path` away before
translate sees it (`op_annot::_subst_path`) and hands the same prefix to a
devproc's `path` argument (`op_annot::_devproc_call`). The two arms have
separate test rows (S20/S21 template, S22 devproc) and separate sabotage
variants for exactly this reason — `basis_atpath_left_to_translate` leaves S22
green, `basis_devproc_not_plumbed` leaves S20/S21 green, and each is caught only
by its own row.

REJECTED: `subst` over the template (a template is user data; `subst` would
execute embedded `[...]`). `string map` only, with the documented consequence
that a literal `@pathological` is also rewritten.

## The four seams, and why they are four procs

`_check_basis` (validates, the only raiser), `_pathfor` (the ONE prefix),
`_subst_path` (template arm), `_devproc_call` (devproc arm). Each can be wrong
on its own while the other three are right, and each has its own sabotage
variant. Measured reds (`RESULT: ALL PASS (96 checks)` clean, headless):

```
basis_deckpath_is_simpath        -> S20 S21 S22 S24 S29   (S2/S3/S17 stay green)
basis_atpath_left_to_translate   -> S20 S21 S24 S29       (S22 stays green)
basis_devproc_not_plumbed        -> S22                   (S20/S21 stay green)
basis_validation_dead            -> S23a S23b S25         (S2/S20 stay green)
```

The first two produced one MORE red than predicted (S29, the `only_toplevel`
row, whose third walk enters descended and so also sees the prefix collapse).
Prediction error in the conservative direction; recorded rather than smoothed.
