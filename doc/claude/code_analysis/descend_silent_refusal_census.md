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
