# The descend silent-refusal census — one channel, thirteen sites

Item D4, run 2026-08-09, branch open_pdk. Closes 0249, 0254, 0256, 0366 and the refusal half
of 0251. Leaves 0369 open (see "the site that got away").

This document is the master record for the mechanism: the site table, the loud/silent policy,
the decision ladder, and the sabotage matrix. The individual issue files carry their own
BEFORE/AFTER transcripts.

## The finding

Descend had **thirteen refusal sites and no status protocol**. Only one of them
(`CADMAXHIER`, `src/save.c:5558`) said anything, via `dbg(0)` to stderr — visible to a
terminal-launched user, discarded by a desktop launch. At the callers the situation was
worse: `descend_symbol()`'s `int` was destroyed at all three call sites
(`src/callback.c:4875` and `:6978` called it as a void statement; the dispatcher called it
without binding the value and then ran `Tcl_ResetResult`), so

```
A1 nothing selected   : descend_symbol -> ''   currsch=0
A2 one instance (OK)  : descend_symbol -> ''   currsch=1
```

A refused descend and a successful one were the **same string**. That is why
`src/xschem.tcl` inferred success from `[xschem get currsch]` rising, and said so in a
comment.

`xschem descend` was not much better: four unrelated causes collapsed to one `'0'`, and a
fifth (`semaphore != 0`) never entered the function at all and was also `'0'`.

## The mechanism

`char descend_err[192]` on `Xschem_ctx` — **per context**, because `open_sub_schematic` and
`hi_descend_newwin` switch contexts mid-flight and a file-scope static would be read in the
wrong window. Exposed as `xschem get descend_error`. Six named callees in `src/actions.c`:

| callee | job |
|---|---|
| `descend_clear_error()` | both verbs clear on entry — a stale reason can never read as fresh |
| `descend_set_error(code, detail, msg, speak)` | records `code` or `code:detail`, **always** |
| `descend_speak_p(speak)` | the loud/silent **predicate**, its own function so it can be sabotaged |
| `descend_speak(msg)` | `statusmsg_hold(msg, 1)` — never `dbg(0)` |
| `descend_pick_target(&n, multi_ok, verb)` | the ELEMENT-counting target rule (0249, 0366) |
| `descend_missing_sym(n, symname)` | the `---MISSING SYMBOL---` placeholder (0254) |

Speaking uses `statusmsg_hold()` because a plain `statusmsg()` is already clobbered by
`select.c`'s info line — measured, and the whole of 0248:

```
E2 (before) after a refusal, statusmsg = 'n=   1 x = 590  y = 675  w = 220 h = 50'
E2 (after)  after a refusal, statusmsg = 'Descend symbol: select an instance to descend into'
E3 (after)  after a refusal, statusmsg_hold = '1'
```

A new dispatcher option `xschem statusmsg -hold <text>` gives the Tcl side the same
discipline; the bare form is byte-identical.

## The site table

Tokens: `maxdepth`, `busy`, `no-selection`, `no-instance-selected`, `multi-selection`,
`missing-symbol:<name>`, `not-descendable:<type>`, `no-schematic`, `save-cancelled`,
`save-failed`, `iter-cancelled`, `load-failed`.

| site | token | speaks? | why |
|---|---|---|---|
| `CADMAXHIER`, both verbs | `maxdepth` | **loud** | the user asked and hit a hard limit |
| picker: 0 ELEMENTs | `no-selection` / `no-instance-selected` | **loud** | the user pressed the key |
| picker: >1, `descend_symbol` | `multi-selection` | **loud** | genuinely ambiguous |
| missing-symbol placeholder, both verbs | `missing-symbol:<name>` | **loud** | you clicked it to find out what broke |
| `get_sch_from_sym` empty | `no-schematic` | **loud** | |
| save failed | `save-failed` | **loud** | |
| load failed (`descend` only) | `load-failed` | **loud** | **the hierarchy ALREADY ADVANCED** |
| dispatcher semaphore gate | `busy` | record-only | not a refusal, a re-entrancy block |
| user pressed Cancel | `save-cancelled`, `iter-cancelled` | record-only | Cancel is its own feedback |
| generic type guard, `src/actions.c` | `not-descendable:<type>` | **record-only — SILENT** | see below |

**`load-failed` is not a refusal.** It is documented as *requiring* a `go_back`: `currsch` is
incremented before the load, so the caller is already one level down. No in-tree caller
honours that yet — 0250, still open.

## The policy the mechanism had to preserve

`tests/headless/test_descend_inert_class.tcl` is a **committed regression lock**: 262 shipped
annotation symbols (`lab_pin`, `gnd`, `vdd`, `ipin`/`opin`, title blocks, launchers, probes)
must be refused **silently** by the guard at `src/actions.c:3684-3688`, on the policy

> silence is correct exactly when nothing the user saw, typed or clicked promised a descend.

So the channel had to be **recorded always and spoken selectively** — loud where the user
pressed `i` on something they picked, silent where they pressed `e` on a label they never
meant to descend. Flattening it either way is a regression: making everything loud adds a
status line per label press; making everything silent is the original defect.

### Making the split falsifiable

The first implementation passed `msg = NULL` at the silent sites. Sabotage S3
(`descend_speak_p` → `1`) then left the lock **green** — the silence came from a missing
string, not from policy, which is one refactor away from flipping. Corrected: the silent
sites now **compose their message and pass `speak = 0`**, so `descend_speak_p()` is the single
switch. S3 now turns all 34 inert "silent" rows red. This is the one place the implementation
deliberately did *more* than the plan, and it is what makes the policy testable.

## Decision ladder

| # | rung | decision | rejected |
|---|---|---|---|
| D1 | R1 | reason is a SECOND channel, never a widened result | returning a reason from `xschem descend` — 7 load-bearing consumers incl. a string compare |
| D2 | R1 | record always, speak selectively | "every refusal speaks" — breaks the 262-symbol lock |
| D3 | R1 spirit / R2 phrasing | `descend_symbol` guard → "exactly one ELEMENT" | message-only (would print "select exactly one instance" while one *is* selected); full unification (silent arbitrary pick) |
| D4 | R2 | `descend` keeps "first ELEMENT, any count" | tightening to match `descend_symbol` (removes shipped capability); uncommenting `lastsel != 1` (miscounts `INST_PIN`) |
| D5 | R2 | `type=="missing"` its own loud refusal, before the generic guard | leaving it in the generic guard — forces the flattening D2 forbids |
| D6 | **R3** | `xschem descend_symbol` evaluates to `"1"`/`"0"` | keeping `ResetResult` + the `currsch` proxy |
| D7 | R1 | `hi_descend_finish` reads the real return; missing `else` echoes the reason | keeping both proxy and return |
| D8 | R2 | `open_sub_schematic` derives its target from `selected_set` | replacing it with `hi_descend_newwin` — changes Alt+E semantics |
| D9 | R2 | table-full hijack closed in Tcl | the C return-value plumbing — deferred, recorded as 0373 |
| D10 | R1 | context-menu log gated on the verb's result | leaving it — the only place a silent refusal *corrupts a record* |

**The bounding safety property:** no descend that succeeds today stops succeeding. The single
withdrawn success is 0366's false one.

**D10 was narrowed during implementation.** The blanket gate suppressed the inert `'# '`
marker that `test_context_menu_log.tcl` pins, so it became
`(!verb_refused || logcmd[0] == '#')`: a `'#'` marker is inert commentary about what was
*picked* — replay skips it, so it cannot lie — while a command line replays and must not
describe work that never happened.

## Sabotage matrix

| # | variant | predicted | observed |
|---|---|---|---|
| S1 | `descend_set_error` → no-op | 10 red | 13 red (all 10 + 3 bonus) |
| S2 | `descend_speak` → no-op | 3 red | 2 red — **inert class stayed 177 ok** |
| S3 | `descend_speak_p` → `1` | 4 red | 2 red — 34 inert rows + R16; **all token rows stayed green** |
| S4 | `Tcl_ResetResult` restored | 5 red | 9 red; R28 lost to an abort → **0368** |
| S5 | legacy picker macro | 7 red | 5 red; R05/R06 unmoved |
| S5b | *added by Verify-B*: true pre-fix rule | — | 8 red incl. R05, R06 |
| S6 | `descend_missing_sym` → `0` | 4 red | 4 red + 2 bonus |
| S7 | `newwin_open_ok` → `1` | 2 red | 2 red |
| S8 | `newwin_descend_failed` → `1` | 3 red | 1 red (R23) |

The S2/S3 pair is the load-bearing control: muting the loud half leaves the silent half green,
and unmuting the silent half leaves every token green. Record and speak are genuinely
separate mechanisms, not one code path with a flag.

### Predicted reds that did not appear

- **S4 / R28** — never *ran*. S4 makes the 0251 suite abort mid-file
  (`expected boolean value but got ""`), and the abort exits 0 with no FAIL line and no
  `OVERALL:` line, so a FAIL-grepping harness scores it green. Filed as **0368**. The blanket
  remedy ("require an `OVERALL:` line") is blocked by `test_placement_preview_doors`, which
  emits none by design.
- **S3 / R14** — a real coverage hole. The stderr-noise recipe cannot catch speak-everything,
  because `descend_speak()` never writes to stderr. **R11 and R16 are the only checks that
  cover the split.** The plan's claim that R14 covered it was wrong.
- **S3 / R13** — structurally unreachable: a successful descend never calls
  `descend_set_error`.
- **S2, S8 / R22, R26** — mis-scoped: a lone wire refuses *earlier*, at the Tcl-side target
  derivation, and never reaches the C speaker or the teardown proc. Consequence:
  `newwin_descend_failed` has exactly **one** covering row → **0371**.
- **S5 / R05, R06** — not a hole. S5's macro reproduced `descend_schematic`'s legacy guard,
  not `descend_symbol`'s `lastsel > 1`; Verify-B added **S5b** (the true pre-fix rule) and both
  rows went red. This is why a sabotage variant must be shaped like the defect it claims to
  restore.

## The site that got away — 0369

The census counted **refusals**. It did not count **failures after commitment**, and there is
one: `descend_symbol()` drops `load_schematic()`'s result (`src/save.c:5686`) and returns 1
unconditionally, having already done `++xctx->currsch`. Its sibling `descend_schematic()`
gained the `load-failed` token in this very commit; `descend_symbol()` did not.

```
A1c| RESULT descend_symbol -> {1}
A1c| RESULT currsch 0 -> 1  sch=doomed.sym       <- file deleted before the call
A1c| RESULT descend_error={}                      <- documented as "succeeded"
```

This makes the channel's contract false on one path, and self-logs a phantom replayable
action-log line. It is a **coverage gap, not a regression** (the unconditional `return 1`
predates D4), but it is the reason this item was **not** certified `x`.

A warning for whoever fixes it: the adversary's original repro measured this against a
**sabotaged binary** (its fixture never resolved, so the symptom actually came from S6). A
valid test must first assert that the symbol resolved, or it silently degrades into the
already-fixed 0254 path and passes for the wrong reason. See 0369.

## Follow-ups

0369 (the gap above), 0370 (`hi_descend_newwin` never got the two new guards), 0371 (the new
teardown's modify-flag lie), 0372/0373 (the teardown defects that make 0371 possible),
0368 (a Tcl suite that aborts mid-file scores green), and 0250 (nobody honours `load-failed`).

---

# D5 attempt (2026-08-10) — built, verified, then **REVERTED**

**Outcome: the fix was reverted. Nothing from it is in the tree.** The source at this commit is
byte-identical to `b1326180` (D4). Read this section before re-attempting 0250/0252/0253/0261/0369
— the mechanism was sound, and it was killed by a landmine nobody had measured
([0379](../issues/0379-get-sym-type-returns-empty-while-an-instance-is-selected.md)).

## What was built

One mechanism, layered on D4's *reason* channel (`xctx->descend_err`). D4 gave a descend a reason;
what was still missing was a **verdict** — nobody could say whether the load landed on the cell
that was asked for.

1. **Verdict.** `xctx->load_verdict` + `load_malformed`, with
   `LOAD_V_{OK,NOFILE,FABRICATED,NORECORDS,GENFAIL,GENWARN}`. `read_xschem_file()` became
   `static int` returning a record count; `pclose()`'s wait status was decoded under `__unix__`.
   `load_schematic()`'s own `int` return was left **byte-identical in meaning** — `src/xinit.c:3697`
   and `:3713` do `if(!file_loaded) tcleval("exit 1")`, so lowering it would make xschem exit 1 at
   startup on an empty start cell.
2. **Discriminator.** `get_sch_from_sym()` stayed `void` and set `xctx->sch_origin_explicit`, so
   an explicit `schematic=` token could be told apart from a derived `<symname>.sch`.
3. **Refuse before the push.** `descend_probe_target()` / `descend_symbol_probe()` refused an
   explicit-but-missing target *before* `xctx->currsch++`, so no unwind was ever needed.
4. **Honour the verdict after the push**, on both `descend_symbol` arms (that is 0369).
5. **Chooser filter** — `hi_descend_row_offerable` stopped offering a schematic row the C guard
   would veto (0252). **This is the step that killed the item.**
6. **Thresholds** — `hi_descend`'s gate moved `>= 2` → `!= 0`, and `descend_unwind_if_pushed`
   replaced the unconditional `xschem go_back 2` in `hier_traversal` and both PDK copies (0253).

## Measured BEFORE (verbatim)

```
0250-A descend returned  : '0'
0250-A descend_error     : 'load-failed'
0250-A currsch AFTER     : 1
0250-A cell exists on disk: 0
0250-A after drawing wire: wires=1 modified=1
0250-A backup written    : 1
0252   row view='schematic' label='schematic' path='.../devices/res.sch' EXISTS=0
0252 descend_error       : 'not-descendable:resistor'
0253 sem=1 descend       : '0' err='busy' currsch=0
0253 sem=2 hi_descend    : '' err='busy'   <- STALE token from the sem=1 call
0261a exit-3 generator   : descend='1' err='' currsch=1 wires=1 readonly=0
0261b truncated child : descend='1' err='' currsch=1 instances=0 wires=1
0261c descend_error      : ''   <- EMPTY == 'the descend worked'
0369 LOG: descend_symbol lines in Xschem.log = 1 : {xschem descend_symbol -inst xg1}
```

## Measured AFTER (the fix did work, on the paths it was aimed at)

```
E3 ... records schematic-not-found:<file>  (refused BEFORE currsch++, so E5: no <cell>~.sch)
E7 ... reported as a CREATION (msg {Descend: creating new schematic e_newcell})
F1/F3 generator-emitting-nothing and 0-byte child -> ret=0 moved=1 err=empty-file, spoken
F4 header-only (well-formed, object-free) child   -> ret=1 err={}   (comp3_empty preserved)
SY1 ... (got ret={0} err={symbol-not-found:gone_d5.sym})
SY3 ... (got ret={0} err={no-symbol-path})
L1 the failed descend_symbol writes NO phantom `xschem descend_symbol -inst xd1` line
```

Tiers were clean (`shape_draw 421→421`, `doors 177→177`, `inert_class 177→177` silence lock intact,
`refusal_channel_0251 34→67`, `descend_symbol 32→38`, `log_absorb 25→29`, regression suite still
exactly its 3 known-red lines).

## Why it was reverted

### Killer — the 0252 chooser filter breaks the create-the-child flow (write-up agent, measured)

`hi_descend_row_offerable` decides via `xschem get_sym_type $symabs`. That command **returns empty
whenever an instance is selected** — which is precisely the state the user is in when they select an
instance and press descend. Measured on the D5 binary, same instance, same sheet:

```
1 fresh           type='resistor'
4 after unselect  type='resistor'
5 after select_inst type=''        <- the normal GUI gesture
```

So for a `type=subcircuit` whose child `.sch` does not exist yet, the filter evaluates
`'' in {subcircuit primitive}` → false, then `[file exists $defsch]` → false, and drops the row:

```
ns.sch exists = 0 (create-the-child flow)
BY NAME  rows = {schematic ... /ns.sch} {symbol ... /ns.sym}
SELECTED rows = {symbol ... /ns.sym}          <- schematic view GONE
```

The plan's bounding property — *"no descend that succeeds today stops succeeding"* — is therefore
**false**. The whole point of the explicit-vs-derived discriminator was to preserve
create-the-child-by-descending, and the chooser filter removed it through the one surface a user
actually drives. **Row V5 passed only because the suite addresses instances by name (`inst=XN`),
never with a live selection** — a green suite hiding a broken workflow. The root cause is
pre-existing C behaviour, now filed as
[0379](../issues/0379-get-sym-type-returns-empty-while-an-instance-is-selected.md); `get_sym_type`'s
implementation was *not* touched by D5, which merely made it load-bearing.

### Second regression — the channel newly asserted success on a refusal (found, then fixed, then reverted with the rest)

`hi_descend` gained an unconditional `xschem set descend_error {}` on entry, so every Tcl-level bail
left the channel reading `{}` — which **this document (above) defines as "succeeded"**. At 0252's own
headline case:

```
RAW  verb : ret=0 err='not-descendable'
CHOOSER   : ret=0 err=''                       <- byte-identical to a success
SUCCESS   : ret=1 err=''
```

Before D5 that path left a *stale* token; after D5 it positively asserted success. A repair (opt-in
token stamping through `hi_descend_refuse`) was written and measured green, then reverted along with
everything else. Kept as [0378](../issues/0378-hi-descend-tcl-level-bails-leave-descend-error-unreadable.md)
so a re-attempt does not re-introduce it.

## Decisions, with ladder rung and rejected alternative

| Rung | Decision | Rejected |
|---|---|---|
| **R3** | An **explicit** `schematic=` naming a missing file is refused *before* `currsch++`. Derived `<symname>.sch` still descends (create-the-child). | A blanket probe-and-refuse on any missing target — deletes the measured create-the-child workflow. |
| R2 | Discriminator carried on `xctx->sch_origin_explicit`, set by `get_sch_from_sym()`. | Widening `get_sch_from_sym()`'s `void` signature (also called from netlisting, `go_back`, and the `xschem get_sch_from_sym` command); re-deriving the token with duplicate `get_tok_value()` calls that would drift from the resolver. |
| R2 | The verdict is a **second** channel; `load_schematic()`'s `int` keeps its exact meaning. | Lowering `ret` for content failures — `xinit.c:3697/:3713` exit the process, and 5 other callers would silently inherit a new meaning. |
| R2 | After a post-push content failure the level **stays advanced**; the verb returns 0 and names the escape. | Auto-unwinding via `go_back` — a full parent reload, a phantom `xschem go_back` log line, and it would flip what "descend returned 0" implies about `currsch` for every in- and out-of-tree caller. |
| R2 | A generator that exits nonzero **with** records, and a load with malformed records, **warn** and still load. Only zero-records refuses. | Hard-failing any nonzero generator exit — a compatibility break aimed at the sites that use generators most. |
| **R1** (0243 F2 — gates at the verbs, never the shared primitive) | 0252's message is spoken at `hi_descend`, the surface the user drove; the C type guard stays byte-silent. | Making the C guard speak — needs a hand-maintained whitelist and would re-litigate the 177-check inert-class silence lock D4 ratified. |
| R2 | `hi_descend`'s gate → `!= 0`. `case 'e'`/`'i'` deliberately **not** moved ([0374](../issues/0374-descend-keys-run-at-semaphore-1-while-a-property-dialog-holds-sel-array-indices.md)). | Raising the Tcl surface to `>= 2` — re-opens `editprop.c:279-283/:395-397` writing back through `sel_array` indices snapshotted across `tkwait`. |
| R2 | The traversal unwind keys off the **`currsch` delta**, in one proc shared by `hier_traversal` and both PDK copies. | A new `xschem get descend_advanced` accessor (second API for a fact `currsch` already reports); having each caller classify the token (couples every walk to a vocabulary this item was changing). |

## Sabotage matrix (8 variants; Verify-B `trustworthy: true`)

| Variant | Predicted | Observed |
|---|---|---|
| S1-probe | 5 red | **3 red** (E2, E3, E5). E1/E4 stayed green — see below. |
| S2-origin | 4 red | 8 red (4 predicted + 4 bonus in `log_absorb`) |
| S3-verdict | 4 red | 5 red covering 3 predicted; **F5 stayed green** |
| S4-symprobe | 3 red | 2 red (SY1, SY3); **L1 stayed green** |
| S5-speak | 7 red | 10 red (all 7 + 3 bonus). Inert-class silence lock correctly stayed green. |
| S6-chooserfilter | 1 red | 1 red (V1) |
| S7-surfacespeak | 3 red | 4 red covering 2; **G3 stayed green** |
| S8-unwind | 1 red | 1 red (H1). Covers all three call sites — the PDK copies hold no local definition. |

**Predicted reds that did not appear** (all explained, none a hole in the mechanism):

- **E1** asserts only `ret==0`, and the pre-fix behaviour *already* returned 0 with `load-failed`.
  The row was green before D5 and green with D5's central mechanism neutralized — **it covers
  nothing this item added.** The pre-push mechanism is carried entirely by E2/E3/E5.
- **E4** — the post-push `load-failed` arm also speaks a held message naming the same file, so the
  row cannot discriminate pre-push refusal from post-push strand. It does cover the *speak*
  mechanism (red under S5), just not the refusal it is filed under.
- **F5** — `load_records_verdict()` does `(void)malformed`; the warning is driven by
  `xctx->load_malformed` read directly at `actions.c:4107`. Bonus variant S3b (zero the counter)
  turned F5 and only F5 red. The plan drew the mechanism boundary in the wrong place.
- **L1** — defended in depth: the pre-push probe, the post-load `if(!load_ok)` guard and
  `load_schematic()`'s own zero each independently suppress the phantom line. Only the two-site
  sabotage S4d turned it red.
- **G3** — the token stamp is a separate statement from the speak; bonus variant S7b (remove the
  stamp, keep the speak) turned G3 and only G3 red.

## Still open

Everything below was measured and is **not** fixed (the fix is reverted). The first item is the one
that must be solved before 0252 is attempted again.

- **[0379] `get_sym_type` returns empty while an instance is selected.** Any type-based chooser
  filter is unsafe until this is fixed or the type is read another way. This is the landmine.
- **[0378] Tcl-level `hi_descend` bails leave `descend_error` unreadable** (stale today, empty under
  the reverted fix). A re-attempt must stamp a token at those bails.
- **Non-schematic content still loads as success.** `read_xschem_file()`'s `default:` arm counts
  every unknown token as a record, so an HTML 404 page or a line of prose saved as `.sch` yields
  `ret=1 err='' objs=0` and a blank page. Only 0-byte and whitespace-only files reach
  `NORECORDS`. The verdict's "at least one record" rule is a **token count, not a parse-success
  count** — 0261b's headline survives for every non-schematic file. Counting only *recognised* tags
  (or counting `default:` hits into `load_malformed`) is the missing piece.
- **A generator that prints a diagnostic banner and exits 0** produces `ret=1 err='' objs=0` — no
  warning, no token. `pclose()`'s status only bites when the generator emitted literally nothing.
- **`descend_symbol` into a `.sym` containing prose** → `ret=1 err=''`, same root cause.
- **The pre-push probe is `stat()`, i.e. ENOENT-only.** An explicit target that exists but is mode
  `000`, or is a directory, still strands with the level advanced and still gets a `<cell>~.sch`
  written beside the real unreadable cell — 0250's full symptom set, including the on-disk harm.
  `access(R_OK)` plus an `S_ISREG` test would close it without touching the derived/new-child split.
- **Action-log asymmetry only half-moved.** `new-child` logs correctly, but its three post-push
  siblings (`empty-file`, `generator-failed`, `load-failed`) advance the level and log nothing,
  while the following `go_back` *is* logged — so a replay pops a level it never pushed.
- **GENWARN and malformed>0 return 1 with `descend_error` EMPTY** by ratified decision, so a
  scripted caller cannot see a damaged load at all; only a human watching the status line can.
- **`descend_unwind_if_pushed` calls `xschem go_back 2`**, a silent no-op at `semaphore != 0`
  ([0377](../issues/0377-go-back-at-nonzero-semaphore-is-a-silent-no-op-that-records-nothing.md)).
  All three call sites discard its return, so a walk that unwinds while busy continues at the wrong
  level.
- **`get_sch_from_sym`'s fallback block only consults `file_exists` when `has_x` is set**, so with
  `fallback != 0` and no X the explicit token is always replaced by the derived name and the
  discriminator cannot fire. Pre-existing, but it bounds where the probe applies.
