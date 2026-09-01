# 0986 — six halves of the new netlist warning's guards can be deleted with every check green

*(The filename says five. Five were found on the first pass; a sixth — the `%`
sigil half of GUARD UA-FMT — turned up when the whole pass was repeated on 27
fresh builds, and is in the addendum at the end. The filename is left alone so
the number that has already been cited elsewhere still resolves.)*

**Filed** 2026-08-30, by the S4c sabotage pass. **Status** open.
**Parent** issue 0984 (the same complaint, one round earlier). **Subject**
`warn_unused_instance_attr()` and its helpers in `src/token.c`, pinned by
`tests/headless/test_unused_attr_0970.tcl`.

## What was done

Every guard S4c added was neutralized ONE AT A TIME against a real rebuild —
callee bodies gutted to `return 0;`, guard lines deleted outright, never a
prefixed comment — and the suite re-run on the resulting binary. 16 planned
variants plus 8 extra probes, 24 builds. The tree was restored between each
one with `cp` + `touch` (never `cp -p`) and the baseline re-asserted green
before the next.

**Nineteen of the twenty-four variants reddened a row**, most of them exactly
the row the plan named. The five below did not. Each was applied alone, built,
and run: `RESULT: ALL PASS (40 checks)`, `OVERALL: ok`, rc=0.

## The five that no row can see

### 1. The instance-side half of GUARD UA-ALTFMT — behaviour, live, untested
`any_format_uses_token()` loops the six format-attribute names over the SYMBOL's
property string and then again over the INSTANCE's. Delete the second loop
entirely and all 40 checks pass. The loop is not dead code — an instance
carrying its own `verilog_format` really does silence a token, and the same
instance without one reports it — but the only format override anywhere in the
fixture file is on a symbol (`uafmt.sym`). One fixture instance carrying its own
`spectre_format` closes this and gap 2 together.

### 2. Five of the six names in `fmt_attrs[]`
Cutting the array from `{format, spice_format, vhdl_format, verilog_format,
tedax_format, spectre_format}` to `{verilog_format}` leaves all 40 checks green.
Only `verilog_format` has a witness (UF7). A symbol whose only reader is its
`spectre_format` would silently start being called dead.

### 3. Any ONE name deleted from `unused_attr_stoplist[]`
UF14 parses the name list out of the very source file it is testing, so removing
a name removes it from the row's own iteration too. Deleting `"url"` scores
`names=55`, still passes the `>= 50` assertion, and nothing ever exercises `url`.
Only four of the fifty-six names have an independent witness — `place`,
`sig_type`, `device_model` (UB5) and `select` (UF19) — so the other fifty-two can
each be deleted one at a time with the whole tier green. UF14 *did* close what
0984 gap 1 asked for (all 56 are now exercised beside a control, 3 of 55 before);
it just cannot see a name go missing. Freezing the expected list in the row
closes it.

### 4. The early-return restore of the netlister's token-found flag — THE SERIOUS ONE
`warn_unused_instance_attr()` restores `xctx->tok_size` in two places: once on
the early return GUARD UA-POLY takes, once at the end. UB9's third assertion is
`[u_count $UB_FN {xctx->tok_size = }] >= 1`, a count over both. Delete the
early-return restore alone and UB9 stays `{1 1 1}` and every check passes.

That path is not obscure: it is the one every instance carrying `schematic=`
takes, and the function's own comment says it is 6 of sky130A's 10 remaining
hits. With the restore gone the netlister's "token absent" flag is left holding
whatever the last `tedax_sym_def` lookup wrote, on every such instance, while
`print_spice_element()` is still resolving the format string.

**This is the same defect UB9 was re-anchored to fix, one level down.** The
re-anchor is real — deleting the latch line now reddens UB9 `{1 0 1}`, where the
old loose spelling could not fail — but only the latch half got anchored on its
own variable. Fix: assert `[u_count $UB_FN {xctx->tok_size = saved_tok_size}] == 2`.

### 5. The destination-buffer clamp inside `unused_attr_elide()`
`if(max_chars > dest_size - 4) max_chars = dest_size - 4;` deletes clean.
Inert today — every call site passes a `max_chars` far below its buffer — but it
is the only thing stopping the `!from_tail` branch writing two bytes past `dest`,
and a future call site that passes a larger cap gets no warning from any row.

## Not counted here: two blocks their own comments call unreachable

The token-level `schematic`/`*_sym_def` name list inside the loop, and the two
fallbacks in GUARD UA-SHEET, also delete clean. Both are documented in the source
as belt-and-braces for a state that cannot occur ("an instance carrying one of
these never gets here"; "for a caller that never went through either"). They are
recorded for completeness, not as gaps.

## One predicted red that did not appear, with its cause

The plan predicted SAB-NAME (deleting GUARD UA-NAME's first-character test)
would take the shipped sky130 bench count from 0 to 8. It did not: UF15 reddened
and UB8 stayed green at 0.

Cause, measured: `sky130_tests/lvtnot/symbol/lvtnot.sym` writes its own
`template=` over three physical lines with SPICE-style `+` continuation markers.
So `get_tok_value(templ, "+", 0)` finds a `+`, GUARD UA-TMPL — which did not
exist when that prediction was written — now calls `+` a symbol-declared
parameter, and the bare `+` on that bench is silenced twice over. The shipped
bench is therefore no longer an independent witness for UA-NAME. UF15, the
fixture 0984 gap 2 added for exactly this reason, is the only one left, and it
works.

Worth noting on its own: **GUARD UA-TMPL accepts `+` as a declared parameter
name.** Harmless today only because UA-NAME runs first in the loop and sets
`skip` before UA-TMPL is consulted.

## Evidence

Restored tree proved clean: `src/token.c` byte-identical to its pre-sabotage
copy, `grep -rn SABOTAGE src/` empty, and the rebuilt `src/xschem` **byte-identical
to the pre-sabotage binary**. Tier green on that binary — test_ase_core 182,
test_ase_final 80, test_ase_final_gf180 34, test_ase_cosim 341,
test_annot_blank_cause_0909 27, test_hash_extra_node_warn_0165 15,
test_unused_attr_0970 40; on the dev display test_ase_view 36, test_ase_persist 109,
test_ase_plot 150, test_ase_window 228, test_ase_dialogs 174, test_wave_viewer 404
(with `--logdir`; 401 under `--nolog`, G1c self-skips). T1 solo: rc=0, 6m12s,
53 blocks all `Total num fail: 0`, zero counted failures, 0 launch failures.

## Re-run 2026-08-30, independently, and a SIXTH half

The whole pass above was repeated from scratch on a fresh set of 27 builds --
16 planned variants, 2 the plan never named, and 9 probes -- each mutation
applied alone to a pristine copy of `src/token.c`, rebuilt, run, then restored
with `cp` + `touch` and the baseline re-asserted at `RESULT: ALL PASS (40
checks)` before the next one. Every result above reproduced exactly, including
all five gaps. Two things are new.

**The `%` half of GUARD UA-FMT has no row either.** `format_uses_token()` accepts
both sigils, `if((*p != '@' && *p != '%') || strncmp(...)) continue;`. Narrow it
to `'@'` alone and all 40 checks pass. This is not a dead branch: the netlister
treats `%tok` exactly like `@tok` while it parses a format string
(`print_spice_element()`, `if(state==TOK_BEGIN && (c=='@'||c=='%') && !escape)`),
so a subcircuit whose format reads `%W` really does consume `W`, and with the
half deleted the user is told that setting reached nothing. Inert on the shipped
tree only by accident: the twelve `%` format strings in the library are on
`type=vsource` and `type=xline` symbols, which GUARD UA-TYPE excludes before the
question is ever asked. One fixture symbol whose format reads `%tok` closes it.

**A sabotage variant for GUARD UA-SYMNAME now exists, and it bites.** The plan
had none because the guard was added during implementation. Gutting
`symbol_name_uses_token()` to `return 0;` reddens UF18 and nothing else, so the
guard is pinned. Likewise `unused_attr_elide()`'s `from_tail` half, which the
plan folded into SAB-ELIDE: disabling the tail branch alone reddens UF20 alone.

**The two halves of GUARD UA-ELIDE separate cleanly**, which the first pass did
not check: removing only the length cap reddens UF10 and only UF10; removing only
the whitespace flattening reddens UF11 and UF12 and neither of the others. Both
halves are seen.

**SAB-NAME's missing red re-confirmed, with its cause proved rather than argued.**
Deleting GUARD UA-NAME's first-character test alone still reddens UF15 only, and
the shipped bench count stays 0. Deleting UA-NAME *and* GUARD UA-TMPL together
takes that count to exactly the 8 the plan predicted, so UA-TMPL is demonstrably
what absorbs the bare `+` -- `lvtnot.sym` writes its `template=` over three lines
with `+` continuation markers, and `get_tok_value(templ, "+", 0)` finds one.

---

# CLOSED by item S4d, 2026-08-30 — started at 6, ended at 0

**Status** fixed. The diagnostic was rewritten for issues 0987/0988/0989 in the
same pass, so the mutation check below covers **every** guard half in it, old and
new, and not merely the six this issue named.

## The six halves as filed, and what now sees each one

| gap | the half | who sees it now | mutation-verified |
|---|---|---|---|
| 1 | the **instance-side** format-string lookup | `UF25` — an instance bringing its own Spectre line reading a token nothing else mentions | deleting it reddens `UF25` **alone** |
| 2 | the alternate format attributes (`spectre_`, `vhdl_`, `tedax_`, `verilog_`) | `UF24a`, `UF24b`, `UF24c`, `UF7` — one exact format name each | removing each row reddens exactly its own witnesses |
| 3 | one name deleted from the read-for-itself list | `UF14`, now frozen name for name and in order | deleting `"url"` reddens `UF14` **alone** |
| 4 | the **early-return** restore of the netlister's token-found flag | `UB9`, re-anchored from a loose `>= 1` to a count of exactly 2 | deleting it reddens `UB9` **alone** |
| 5 | the shortener's destination clamp | `UF21`, structural | deleting it reddens `UF21` **alone** |
| 6 | the `%` half of the format sigil test | `UF23` — a cell reading a setting with a percent sign, the deck really carrying `M=4` | deleting it reddens `UF23` **alone** |

Gaps 5 and 6 are worth separating. Gap 6 is **behavioural**: no shipped symbol
uses a `%` sigil, so it needed a fixture, and the row checks both halves — the
tool stays quiet **and** the deck really carries the value, so calling it dead
would have been a demonstrable lie. Gap 5 is unreachable by arithmetic from all
five call sites (120 into 160 bytes, 60 into 80; the clamp fires only above 156
and 76), and shortening a field the reader needs just to make it reachable would
trade a deliverable for a test — so it is pinned structurally, deliberately.

## The whole diagnostic, mutation-verified: 37 mutations, 37 reds

Each mutation was applied **alone** to `src/token.c` against the same green
baseline, rebuilt, run, and restored with an mtime bump (`cp backup src/token.c`
then `touch`, never `cp -p`). Afterwards `grep -rn SABOTAGE src/` is empty,
`src/token.c` is byte-identical to its pre-mutation copy, and the restored
baseline is green at 57 checks.

| mutation | rows that went red |
|---|---|
| `ua_reach()` always answers "nothing anywhere" | UF1 UF2 UF4 UF7 UF24a-c UF25 UF27 UF28 UN1 UN3 UN4 |
| `ua_reach()` always answers "another netlist carries it" | UB1 UF3 UF5 UF10 UF11 UF13 UF24d UN1-UN5 |
| the resolved-format test gutted | UB1-UB8 UF6 UF19 UF23 |
| the `%` sigil half dropped | **UF23** |
| whole-token test replaced by a substring test | **UB4** |
| GUARD UA-LVSFMT deleted | **UF26** |
| the instance-side format lookup deleted | **UF25** |
| the symbol-side format lookup deleted | UF4 UF7 UF24a-c UF26 |
| the Spectre row removed | UF24a UF25 |
| the VHDL row removed | UF2 UF4 UF24b UF27 UN1 UN3 |
| the Verilog row removed | UF7 UN1 UN3 UN4 |
| the tEDAx row removed | **UF24c** |
| the symbol half of the do-not-write marks | UN2 UN4 |
| the instance half of the do-not-write marks | **UN5** |
| GUARD UA-FMTWINS deleted | **UF4** |
| GUARD UA-GENTIME deleted | **UF27** |
| `symbol_declares_param()` gutted | UF1 UF2 UF4 UF27 UN1 UN3 UN4 |
| GUARD UA-EXTRA deleted | UB1 UF5 |
| the format list hardcoded to "VHDL or Verilog" | UF4 UF7 UF24a-c UF25 UF27 UN4 |
| the format list's overflow stop deleted | **UF22** (structural) |
| the read-for-itself list loop gutted | UB5 UF14 UF18 UN5 |
| one name (`url`) deleted from that list | **UF14** |
| the cell-parameter list made unconditional | **UN1** |
| the cell-parameter list emptied | UF14b UF19 |
| GUARD UA-NAME deleted | UB8 UF8 UF15 |
| GUARD UA-TYPE deleted | UB6 UB7 UB8 UF19 |
| GUARD UA-POLY deleted | UB3 UB7 UB8 UB9 UF18 |
| the token-found flag latch deleted | **UB9** |
| the early-return restore deleted | **UB9** (structural) |
| the sheet name replaced by a literal | UF8 UF9 UF20 |
| the shortener's length cap deleted | **UF10** |
| the shortener's whitespace flattening deleted | UF11 UF12 |
| the shortener's keep-the-end branch disabled | **UF20** |
| the shortener's destination clamp deleted | **UF21** (structural) |
| GUARD UA-SYMNAME gutted | **UF18** |
| a second hand-off to the info window added | 37 rows |
| the destructive clause added to the new sentence | **UF28** |

## One mutation that did NOT redden anything, and what it cost

Appending the accusing sentence's own offer onto the new sentence as
**"Or take it off."** — one capital letter — left all 57 checks green.
`UF28`'s needles were case-sensitive, so a sentence that told the user to delete
a setting the VHDL netlist carries would have shipped. The row now lowercases
every line before matching, and matches on `take it off` and `schematic=` rather
than the full clauses. Re-run after that change, the same mutation reddens
`UF28` alone. **This is the only escape found in 37 mutations, and it was in a
row written this session** — the guard was there, the anchor was not.

## Two predicted reds that did not appear, with their causes

* Gutting `symbol_declares_param()` was predicted to redden `UF14b`. It does not,
  and cannot: with that function returning 0, `select` is excused
  *unconditionally*, which is exactly the answer `UF14b` demands on a cell whose
  template does not declare it. The mutation is caught by six other rows.
* Deleting GUARD UA-NAME's first-character test still does not move the shipped
  bench count, for the cause this issue already proved: GUARD UA-TMPL absorbs
  `lvtnot.sym`'s `+` continuation marker.

## Two halves that are deliberately invisible, disclosed rather than hidden

Neither can hide a defect, and both say so in the source:

1. **The `xctx->format &&` condition on GUARD UA-LVSFMT** is a *cost* guard. When
   `xctx->format` is NULL the resolved format string **is** the plain `format`
   attribute, resolved by the same four steps, so the second lookup would return
   the answer the first test already gave. Removing the condition changes no
   output; it only pays two `get_tok_value()` calls per token per instance on
   every ordinary SPICE netlist. Deleting the whole line, though, reddens `UF26`.
2. **The per-token reset of `reach` and `carriers`** is defensive: `ua_reach()`
   assigns `reach` on every path that can reach the print block, so the reset
   cannot change what the user sees. It is there so a later hand adding a test
   between the two cannot inherit the previous token's answer.

## Count

**Started at 6** halves no row could see. **Ended at 0**, with 37 of 37
mutations reddening at least one row, and the suite at **57 checks** (from 40).

---

## ADDENDUM, 2026-08-30 — the S4d SABOTAGE pass. The count did NOT end at 0

An independent mutation pass on a real rebuild — **50 mutations, one per build,
each applied alone from a pristine `src/token.c`, restored with `cp` + `touch`
(never `cp -p`) and the baseline re-asserted green at 57 checks between every
one** — reproduces the six original gaps as CLOSED, and finds **seven more that
the S4d code itself introduced**. The paragraph above should read *started at 6,
closed 6, opened 7*.

### The six original gaps: confirmed closed, each by the row the plan named

| gap | mutation | reddened |
|---|---|---|
| 1 instance-side format lookup | `SAB-altfmt_inst` | `UF25` **alone** |
| 2 the alternate format rows | `SAB-altfmt_spectre/vhdl/verilog/tedax` | `UF24a`+`UF25` / `UF24b`+4 / `UF7`+3 / `UF24c` **alone** |
| 3 a deleted stoplist name | `SAB-stop_one` (drop `url`) | `UF14` **alone** |
| 4 the early-return `tok_size` restore | `SAB-toksize_early` | `UB9` **alone** |
| 5 the shortener's destination clamp | `SAB-elide_clamp` | `UF21` **alone** |
| 6 the `%` sigil half | `SAB-fmt_sigil` | `UF23` **alone** |

Also confirmed single-row: `SAB-lvsfmt` → `UF26`; `SAB-fmtwins` → `UF4`;
`SAB-gentime` → `UF27`; `SAB-stop2_off` → `UN1`; `SAB-toksize_latch` → `UB9`;
`SAB-elide_cap` → `UF10`; `SAB-elide_tail` → `UF20`; `SAB-symname` → `UF18`;
`SAB-destructive` → `UF28`; `SAB-join_clamp` → `UF22`; `SAB-type` → `UB6`;
`SAB-poly` → `UB3`.

### The seven new halves, each deletable with `RESULT: ALL PASS (57 checks)`

1–4. **The four `| *_SHORT` bits** in `ua_reach()`'s `ua_backend_carries()`
   calls. Deleting any one, or all four, is 57/57 green. Filed as **0991** with
   a measured wrong sentence.
5. **The instance-wins-over-symbol structure of `ua_fmt_attr_state()`.** The
   source goes out of its way to call the OR "wrong twice over" — restoring the
   OR is 57/57 green. Measured: an instance carrying its own
   `spectre_format` that does not read the token flips from the true accusing
   sentence to `a Spectre netlist of the same cell does carry it`. Only `xIX`
   carries an instance-side format attribute, and it sets the one token its own
   line reads, so instance-wins and OR give the identical answer on all 57 checks.
   FIX: one more instance on `uaalt_top`, with `spectre_format` reading a
   DIFFERENT token from the one it sets, asserting kind A.
6. **The `f && f[0]` half of the presence test** in `ua_fmt_attr_state()`.
   Filed as **0992** — it ships a destructive false accusation and a fabricated
   carrier name, and the CORRECT fix is also 57/57 green.
7. **The `", "` branch of the carriers join** (`sep = (i == n - 1) ? " or " : ", "`).
   Replacing `", "` with `""` is 57/57 green. `ua_carriers` word-matches the four
   names independently, so any separator scores the same list, and nothing in the
   shipped library or the suite produces a three-carrier line, so the branch is
   never executed. Under the PLAIN ENGLISH ruling `a VHDL, Verilog netlist` would
   ship unseen. FIX: a fixture cell reading one token from three of its netlist
   lines, with a row demanding the joined string verbatim.

### Two more invisible halves that are NOT declared in the source

Neither hides a defect; both should get the one-line "invisible on purpose" note
the other two have, or a later hand will file them as gaps again.

* `carriers[0] = '\0'` at the top of `ua_reach()` — the only caller already
  resets it per token. Deleting it is 57/57 green.
* GUARD UA-POLY's own six token names (`schematic`, `*_sym_def`) — the comment
  says an instance carrying one never gets here, which is true; deleting the
  block is 57/57 green. Declared dead deliberately, so this is a documentation
  nit, not a gap.

### Two predicted reds that did NOT appear, with causes

* **`SAB-EXTRA` was predicted to redden `UF3`; it reddens `UB1` and `UF5` only.**
  `UF3`'s subject is the shipped ROM's `VSSBPIN`, and `lvnand2.sym` carries
  `extra="VCCPIN VSSPIN"` **and no `template=` at all**. `symbol_declares_param()`
  returns 0 at its `if(!templ || !templ[0])` line, so GUARD UA-EXTRA is never
  reached on that instance. `UF5` is the row that sees the guard, and it reddens.
* **`SAB-STOP` was predicted to redden `UF19`; it reddens `UB5`, `UF14`, `UF18`
  and `UN5`.** `select` is no longer on the unconditional stoplist — this item
  moved it to `unused_attr_cellparam_stoplist[]` for 0989 — so gutting the
  unconditional list cannot reach `UF19`. `SAB-stop2_empty` reddens `UF19`, which
  is the right guard.

Two further plan predictions were naming artifacts rather than misses:
`UF24d` under `SAB-REACH-NOWHERE` (it is the CONTROL row, and demands kind A,
which is what that mutation forces everywhere), and the "VLTOK arm of UF24d" under
`SAB-ALTFMT-VERILOG` (there is no such row; `UF7` covers `verilog_format`, and it
reddens). One plan prediction was **beaten**: `SAB-NAME` was expected not to move
`UB8`, and it reddens `UB8`, `UF15` and `UF8`.


---

# THE SEVEN ARE CLOSED — the S4d repair pass, 2026-08-30

**Started at 7 halves no row could see, ended at 0, and this time the sentence
was earned by rebuilding the tool without each half and watching a row redden.**
Every mutation below was applied ALONE to a pristine `src/token.c`, built,
run, and restored with `cp` + `touch` (never `cp -p`) before the next one. The
suite went 57 → 66 checks.

| the half | the row that now sees it | the mutation, and what reddened |
|---|---|---|
| `\| VHDL_SHORT` | UF30a | `SHORT-vhdl` → UF30a alone |
| `\| VERILOG_SHORT` | UF30b | `SHORT-verilog` → UF30b alone |
| `\| SPECTRE_SHORT` | UF30c | `SHORT-spectre` → UF30c alone |
| `\| TEDAX_SHORT` | UF30d | `SHORT-tedax` → UF30d alone |
| instance-wins, not OR | UF31 | `FMT-OR-ONLY` → UF31 alone |
| the presence test (0992) | UF33a, UF33b | `PRESENCE-old` → UF33a UF33b; `PRESENCE-noempty` → UF33a |
| the `", "` branch | UF29, UF30a-d | `SEP-empty` and `SEP-noor` → UF29 UF30a-d |

Three of the seven were live defects, not merely unwitnessed guards, and each
was FIXED in the code as well as pinned: issues **0991** (no code change needed
— the guard was right, the fixture was missing), **0992** (the presence test),
**0993** (the new GUARD UA-EMPTY, which had no code to neutralize at all).

## The two undeclared-invisible halves

* `carriers[0] = '\0'` at the top of `ua_reach()` — now carries the same
  "deliberately invisible to any row" note the other two have, naming why
  (the only caller resets it one line before the call) and saying explicitly
  that no test row should be written to see it.
* GUARD UA-POLY's six token names already carried theirs; left alone.

## New witnesses, described so a later hand does not re-derive them

* **`uajoin_top.sch`** — five copies of a cell all four backends carry the
  setting through. The first is the ONLY sheet in this tree, shipped or fixture,
  that produces more than two carriers, so it is the only witness the commas
  have. The other four carry one `short`-spelled do-not-write mark each.
* **`uaov_top.sch`** — the cell's Spectre line reads one setting and the copy on
  the sheet brings its own Spectre line reading another, so OR and copy-wins
  disagree there and nowhere else.
* **`uaefmt_top.sch`** and **`uamtv_top.sch`** — the two empty shapes, and the
  two rows that netlist their own sheet to VHDL and to Verilog and read the
  product rather than trusting the sentence.

## A note on the mutation harness, since this is the third pass on this file

The harness refuses to build when the anchor did not match exactly once — a
mutation that silently fails to apply reads as "no row can see this guard" and
is the precise way a sabotage run lies. One mutation in this pass (`TMPL-gut`)
was rejected at the compiler instead, for unbalanced braces in the replacement;
it was rewritten and then reddened 14 rows. Neither was scored as a clean delete.

## Where the numbers stand

Suite: `RESULT: ALL PASS (66 checks)` / `OVERALL: ok`, on both arms.
Whole-library noise sweep, unchanged to the line by the three code fixes:
`sheets_with_lines=17 lines=141 A=98 B=43 suspect=43 loose=120`.
