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
