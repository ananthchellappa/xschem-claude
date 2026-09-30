# RECEIPT R — stacked bus-label rendering, read-only recon

**Stage:** R · **Crews:** 3 parallel, read-only · **Date:** 2026-09-29 · **Tree:** `1f42914d`
**Changed in the tree:** nothing. All three crews reported `git status --short` byte-identical to the
session-start snapshot.

## The feature, as the user defined it

New-list wish item **2**, the "vertical justification" half. ⚠ It is **not** typography. The user
labels a bus by typing a comma-separated token list — their example, an 8-bit bus:
`bg_trim<3:0>,en_fast,iref_trim<2:0>`. The flag controls that list's LAYOUT:

* **off** — one line: `bg_trim<3:0>,en_fast,iref_trim<2:0>`
* **on** — stacked, one token per line, **single-spaced with no blank line between them**

The user's own diagnostic: *"`busname<3:0>` will not render any different with vertical
justification"* — a single token has nothing to stack. Opt-in ("if user wants"), so a checkbox is
right. The driver had proposed two wrong readings first (rotate the text along the wire; re-anchor
via `hcenter`/`vcenter`) and both were withdrawn — neither stacks anything, and neither would change
a single-token label either, which is the test that should have caught them.

## Headlines

1. **Multi-line rendering already works end to end, and the spacing requirement is already met.** A
   newline in `lab=` renders as a real stack today with zero code changes, measured at **1.1470x**
   font height on every export path. **Not a blocker.**
2. ⚠⚠ **But a newline must NEVER reach the stored `lab=`.** Measured: it produces a SPICE card split
   across physical lines, and the bus expander concatenates tokens into wrong bit names.
3. ⚠⚠⚠ **`<3:0>` IS NOT A BUS RANGE IN XSCHEM, and getting it wrong is SILENT.** The user's typed
   spelling netlists WRONG with zero warnings. The form already normalises `<>`→`[]`, so there is no
   existing behaviour of displaying angle brackets.
4. **The comma is ALREADY a label separator**, so the user's example places THREE labels today. The
   flag therefore changes TOKENISATION, not only display — the two checkboxes turn out to be the two
   readings of a comma.
5. **The two crews DISAGREE on the mechanism** (a derived token in `translate()` versus a
   per-instance token read at six draw sites). Both arguments are recorded below; the driver has not
   resolved it, and the implementing crew must, under the constraint that no newline may reach any
   netlist path.

| angle | verdict on the driver's lean |
|---|---|
| ANGLE 1 — can xschem render multi-line text at all, and with | **CONFIRMED** |
| ANGLE 2 — where a per-instance display flag lives, and what  | **CONFIRMED** |
| ANGLE 3 — what must the stored `lab=` look like, and who alr | **CONFIRMED** |


==============================================================================

## ANGLE 1 — can xschem render multi-line text at all, and with what line spacing?

**Verdict on the driver's lean:** `CONFIRMED`

### What was measured

Headline: **multi-line text works end to end today, single-spaced, and a newline in `lab=` already renders as a stack with ZERO code changes. Line spacing is NOT a blocker.** All measurements at HEAD `1f42914d`, `HAS_CAIRO 1` (config.h), binary `/home/analog/dev/xschem-claude/src/xschem` built 21:35 today, all probes `--nogui` into my own scratch.

**(a) The newline survives the `.sch` text and property records.** `save_ascii_string()` (`src/save.c`) escapes only `\`, `{`, `}` and writes a newline literally inside `{...}`; `load_ascii_string()` (same file) reads to the matching unescaped `}` and passes newlines through. Measured round-trip via `xschem saveas` into scratch then reload:
```
raw prop 0 = <<name=pA lab="bg_trim<3:0>
en_fast
iref_trim<2:0>">>
pA lab=<<bg_trim<3:0>
en_fast
iref_trim<2:0>>> nl=2
```

**(b) Every renderer and both measurers honour `\n`.** Screen cairo: `draw_string()` (cairo branch, `src/draw.c`) splits on `\n`, calling `cairo_draw_string_line()` per line. Screen non-cairo: `draw_string()` (`#else` branch, same file) advances `yy` on `\n`. SVG: `svg_draw_string()` → `svg_draw_string_line()` (`src/svgdraw.c`). PS/PDF: `ps_draw_string()` → `ps_draw_string_line()` (`src/psprint.c`). Box + hit-test: `text_bbox()` / `text_bbox_nocairo()` (`src/actions.c`) both count lines and size `hh` accordingly, so bbox tracks draw.

**(c) `@lab` expansion preserves the newline; the stack already renders.** Chain is `draw_symbol()` → `translate(n, text.txt_ptr)` (`src/token.c`) → `translate3()` → `draw_string()`. In `translate()` the generic instance-token branch does `value = get_tok_value(xctx->inst[inst].prop_ptr, token+1, 0)` then `memcpy(result+result_pos, valstr, len+1)` — verbatim, no filtering. **Answer to the key question: a `lab` value containing a newline renders as TWO REAL LINES today.** Measured — a `devices/lab_pin.sym` instance with `lab="bg_trim<3:0>\nen_fast\niref_trim<2:0>"` exported via `xschem print svg` gave three separate elements:
```
<text ... font-size="49.5762" transform="translate(586.721, 98.9232)" >bg_trim&lt;3:0&gt;</text>
<text ... font-size="49.5762" transform="translate(586.721, 155.787)" >en_fast</text>
<text ... font-size="49.5762" transform="translate(586.721, 212.651)" >iref_trim&lt;2:0&gt;</text>
```
Not a literal escape, not one line, not a break.

**(d) LINE SPACING: single-spaced, measured ratio 1.1470. NO BLANK LINE.** `cairo_draw_string_line()`: `line_delta = (lineno*fontheight*cairo_font_line_spacing)` with `fontheight = fext.height` from `cairo_font_extents()`; `cairo_font_line_spacing` is 1.0 (`src/globals.c`, and `set_ne cairo_font_line_spacing 1.0` in `src/xschem.tcl`, mirrored in `xinit.c`). So the pitch is exactly one font height — the normal typographic single space. `svg_draw_string_line()` and `ps_draw_string_line()` use `line_delta = lineno*fontheight` with `height = size*xctx->mooz * 1.147`. Measured from the SVG above: label font-size 49.5762, pitch 155.787−98.9232 = 56.8638 → **1.1470**. Generic text font-size 60.0923, y −156.96 / −88.0341 / −19.1082, pitch 68.9259 → **1.1470**. Identical, and nowhere near the 2.0+ that would read as a blank line.

**(e) The only route to a gap is a pre-existing global preference, and it cannot reach export.** I set `::cairo_font_line_spacing 2.0` and re-exported: the SVG came back **byte-identical** (same y values 98.9232 / 155.787 / 212.651). So export is pinned at 1.147 and can never show a gap; only the screen path scales, and only for a user who tuned that knob in their xschemrc.

**(f) Cairo vs non-cairo differ in pitch but both stack.** The vector-font paths (`draw_string()` `#else` branch, `old_svg_draw_string()`, `old_ps_draw_string()`) advance by `(FONTHEIGHT+FONTDESCENT+FONTWHITESPACE)*yscale` = 40+15+10 = **65 units against a FONTHEIGHT of 40 → 1.625× glyph height** (`src/xschem.h` macros). Airier than cairo's 1.147, still not a blank line, and `text_bbox_nocairo()` uses the same 65 so its box matches. Neither path fails to stack; this build ships cairo anyway.

**(g) Existing multi-line rendering to imitate.** A shipped library file already does it: `/home/analog/dev/xschem-claude/xschem_library/devices/intuitive_interface_cheatsheet.sch` carries multi-line `T {...}` records, e.g. `T {(Enable Options → Intuitive Click & Drag interface` / `or add: \`set intuitive_interface 1\` in xschemrc file).} 1090 -13440 0 0 1 1 {hcenter=1 layer=1}`. Multi-line schematic text is production, not a curiosity.

**(h) Storage quoting is mandatory — and `subst_token()` already does it for you.** `SPACE(c)` in `src/token.c` is `( c=='\n' || c==' ' || c=='\t' || c=='\0' || c==';' )`, so an UNQUOTED newline ends the value in `get_tok_value()`. Measured, same schematic, `lab=bg_trim<3:0>` + bare newline + `en_fast`:
```
pB lab=<<bg_trim<3:0>>>  bytes=12  nl_count=0
```
A hand-written single backslash does not save it either — `load_ascii_string()` eats it, leaving the bare newline. But `subst_token()` auto-quotes: `if(strcmp(tok, "name") && !is_quoted(new_val) && strpbrk(new_val, ";\n \t"))`. Measured `xschem setprop instance pC lab "aa\nbb"`:
```
after setprop raw = <<name=pC lab="aa
bb">>
post-reload pC lab=<<aa
bb>> nl=1
```

**(i) Split on the TYPED commas, not the bus-expanded bits — the user's own diagnostic proves it.** `xschem expandlabel`:
```
expandlabel {bg_trim[3:0],en_fast,iref_trim[2:0]} -> <<...8 names... 8>>
expandlabel {bg_trim[3:0]} -> <<bg_trim[3],bg_trim[2],bg_trim[1],bg_trim[0] 4>>
```
If vjust split the expanded list, `busname[3:0]` would stack 4 lines — contradicting the user's "renders identically either way". Split the stored comma list.

**(j) The red-first fence is already reachable and headless.** `xschem translate <inst> <string>` is Tcl-exposed (`scheduler.c`, the `translate` branch, resolving via `get_instance()` then `translate(i, argv[3])`). Measured today:
```
pB translate @lab        -> <<bg_trim<3:0>,en_fast>>  bytes=20 nl=0
pB translate @lab_vstack -> <<>>  bytes=0
```
So an absent derived token yields the **empty string**, not the literal (`translate()` falls back to the literal only for `%`, never `@`). That is the red the implementer will see.

### Recommended mechanism

**Confirmed, and the consequence is worse than the driver's "risk the netlist" — it is a syntactically broken netlist.** Measured: a `lab_pin` with `lab="bg_trim<3:0>\nen_fast"` on a wire feeding `devices/res.sym`, netlisted to scratch, produced
```
**.subckt nl
R1 bg_trim<3:0>
en_fast bg_trim<3:0> 1k
**.ends
```
The `R1` card is split across two physical lines. So the stored `lab=` MUST stay comma-separated; stacking is rendering-only.

**Mechanism: a derived token resolved inside `translate()` (`src/token.c`), gated by a per-instance `vjust=` attribute.**

Why there and nowhere else: **all six sites that render or measure a symbol's text call `translate(n, text.txt_ptr)`** — `draw.c` (three: the symbol-text loop in `draw_symbol()`, the second loop, and the `10516` site), `svgdraw.c`, `psprint.c`, and `select.c`'s hit-tester. One addition covers screen, SVG, PS/PDF, bbox and hit-test at once. That is exactly invariant **I1**, written up in `src/xschem.h` above `text_hidden()`/`text_hidden_inst()`: *"Four copies, one builder"*, and the same file records what the alternative cost — three byte-identical `strcmp` pairs that *"missed `@spiceprefix@name`, so at hide_symbols=2 gf180's whole FET family lost its names."* Touch the six draw loops separately and you have re-created that defect.

Precedent to imitate, by symbol:
- **Derived tokens already live in `translate()`**: `@spice_get_voltage`, `@schname`, `@schverilogprop`, `@time_last_modified`, `@#<n>:net_name`, `@spiceprefix` (the last has an explicit suppression branch: `else if(!sp_prefix && !strcmp(token, "@spiceprefix"))`), plus `get_pin_attr(token, inst, engineering)` for pin-derived values. A token whose value is another token's value with a transform applied is squarely inside this pattern.
- **Per-instance override of shared symbol text**: `get_sym_text_size()` and `get_sym_text_layer()` (both `src/draw.c`) read `text_size_%d` / `text_layer_%d` off `xctx->inst[inst].prop_ptr`, precisely because `symptr->text[]` is shared by every instance. `text_hidden_inst(flags, n)` exists for the same reason — `src/xschem.h` states it: *"cannot live in xText.flags, because draw_symbol() walks symptr->text[j] and that array is SHARED by every instance of the symbol; the instance index is how it travels instead."* `translate()` already takes `inst`, so the instance index is in hand.

Concretely, the cheapest shape: in `translate()`'s generic instance-token branch, after `value = get_tok_value(...)` resolves `lab`, consult `get_tok_value(xctx->inst[inst].prop_ptr, "vjust", 0)` and, when true, substitute the comma-split-on-newlines form of the value. One hook, no new symbol text record, no change to `lab_pin.sym`, and `@lab` stays the only spelling the symbol carries — so existing files render unchanged (no `vjust=` ⇒ no transform). Reject the alternative of adding a second `T {@lab_vstack}` record to `lab_pin.sym` gated per instance: it doubles the symbol's text array, needs a hide predicate on both records, and every other label symbol would need the same surgery.

Storage side: nothing to build. `subst_token()` (`src/token.c`) auto-quotes any non-`name` value containing `;`, `\n`, space or tab, and `xschem setprop instance <n> vjust 1` needs no quoting at all. Writing `vjust=1` is a bare integer — the whole quoting question disappears once the newline never reaches `lab=`, which is the second reason to prefer this shape.

Fence: add rows to the already-registered `/home/analog/dev/xschem-claude/tests/headless/test_add_wire_label.tcl` asserting `xschem translate <inst> {@lab}` (canonical comma form, unchanged) and the stacked form, plus a `regexp {\n\n}` == 0 row for the no-blank-line requirement and an identity row for the single-token diagnostic (`[xschem translate pA {@lab_vstack}]` eq `[xschem translate pA {@lab}]`). All work under `--nogui` — measured. For a renderer-level row, `xschem print svg` into scratch and assert the per-line y pitch equals 1.147 × font-size (measured constants: 49.5762 / 56.8638).

### Blockers

**No blocker in the rendering engine.** Multi-line text, its bbox, its hit-test and all four output back ends already work, and the spacing is already single. The feature needs no new drawing code.

**The real blockers are in the form, and both are product-shaped.** They make the obvious approach — "read the commas the user typed in the Name field" — impossible as written, because in that field a comma already means something else:

1. **`addlabel::expand_names {s split_bus}` (`src/xschem.tcl`) turns the typed string into a QUEUE of SEPARATE label instances**, splitting on `regexp -all -inline {[^,\s]+}` — commas AND whitespace. `addlabel::start_pass` feeds that list to `addlabel::arm` one token at a time, and `addlabel::arm`'s own status text says so: *"type a Label Name (space/comma-separated for several), then move onto the canvas"*. Typing the user's example today places **three labels**, not one label on three lines. vjust must suppress the queue split for its pass — which is a change to an existing, shipped, status-bar-advertised behaviour, not a new field.

2. **`addlabel::name_ok` rejects the user's example outright**, so the form would refuse to arm at all. After `string map {< \[ > \]}` the pattern is `^[^][{}<>;:]+(\[[0-9]+(:[0-9]+)?\])?$` — a bracket-free base plus at most ONE trailing bus suffix and nothing after it. `bg_trim[3:0],en_fast,iref_trim[2:0]` fails, and `addlabel::arm` then takes the `status_error` branch (*"has a syntax error -- fix it to place"*) with `armed 0`. The validator must be relaxed on the vjust path.

Neither is an engine limit; both are decisions about what the Name field means when vjust is on. That is user-visible, so it belongs to the driver/user, not to the implementer — but it must be settled before the form work starts, because it determines whether vjust reuses the Name field or needs its own.

Nothing else forces a workaround. The `vjust=` attribute can be written with `xschem setprop instance` with no quoting, and `translate()` already receives the instance index it needs.

### The fence

**`/home/analog/dev/xschem-claude/tests/headless/test_add_wire_label.tcl` — it EXISTS, it is REGISTERED, and its epilogue DOES print the sentinel. Nothing needs registering.**

- Registered at line 42 of `/home/analog/dev/xschem-claude/tests/run_regression.tcl` (at `1f42914d`) as `"headless/test_add_wire_label"`, inside **`hcases` alone** — `set hcases [list` is at line 27, `set dcases [list` at line 608, and the entry falls between. So one case, no skip, on the headless arm.
- Epilogue, verbatim from the file's last two lines:
```
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
```
`puts "OVERALL: ok"` is a whole line with nothing appended, so it matches `banner_complete`'s `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$` in `/home/analog/dev/xschem-claude/tests/banner_rule.tcl`. This suite is **not** in the unregisterable `test_wave_sigbrowser*` family that CLAUDE.md warns about — it was checked against `banner_complete`, not against `run_suites.sh`.
- It runs headless: the suite stubs Tk (it `rename`s `winfo` and restores it), and everything my angle needs — `xschem load`, `xschem translate`, `xschem getprop`, `xschem setprop`, `xschem print svg` — I measured working under `--nogui`.
- The suite currently contains **zero** occurrences of `vjust` (`/usr/bin/grep -n vjust` → no match), so every row added is genuinely new coverage rather than a rename.

Because the fence already exists and already gates, the red-first sequence costs no registration commit: add the failing rows to this suite, show the red (`xschem translate pB {@lab_vstack}` → `<<>>` today), then implement. Armed spelling for the arm: `tests/headless/run_suites.sh --nogui test_add_wire_label`.

### Traps

**T1 — ⚠ THE SHIPPED SPEC STATES THE TWO READINGS THE DRIVER ALREADY WITHDREW.** `/home/analog/dev/xschem-claude/doc/claude/specs/add_wire_label.md` line 47: *"**Vertically justified** — reserved, disabled. (Will later rotate/vcenter the label text.)"* — i.e. `lab_orient()`-style rotation and the `vcenter` attribute, both explicitly refuted. Line 32 also shows it as `[ ] Vertically justified (inert — deferred)`. An implementer who reads the spec instead of the user's statement builds the wrong feature. **Correct the spec in the same commit.** This is the highest-value item here.

**T2 — the form's comma already means "several separate labels".** `addlabel::expand_names` splits on `[^,\s]+` into a queue; `addlabel::arm`'s status says *"space/comma-separated for several"*. Opposite of vjust. See Blockers.

**T3 — `addlabel::name_ok` rejects the user's example**, so the form never arms. See Blockers.

**T4 — `addlabel::expand_names` normalises `<`/`>` to `[`/`]`** (`string map {< \[ > \]}`), and that is the ONLY reason the user's `<3:0>` spelling is an 8-bit bus. Measured at the expander, which sees only what was stored:
```
expandlabel {bg_trim<3:0>,en_fast,iref_trim<2:0>} -> <<bg_trim<3:0>,en_fast,iref_trim<2:0> 3>>
expandlabel {bg_trim[3:0],en_fast,iref_trim[2:0]} -> <<...,iref_trim[0] 8>>
```
`::bus_replacement_char` is empty. Do **not** "fix" the angle form inside `expandlabel` — the conversion belongs where it already is, in the form.

**T5 — ⚠ comment contradicts code in `subst_token()` (`src/token.c`).** Comment: `/* quote new_val if it contains newlines and not "name" token */`. Code: `strpbrk(new_val, ";\n \t")` — semicolon, newline, space and tab. Exactly the class CLAUDE.md fences as limit L9.

**T6 — `is_quoted()` (`src/token.c`) is naive**: `if(s[0] == '"' && s[len - 1] == '"') return 1;`. A value like `"a" b "c"` is read as already-quoted, so `subst_token()` does not re-quote it and the interior space truncates it on the next `get_tok_value()`. Low risk for a bus token list, real for pasted text. Note `xis_quoted()` exists alongside and is escape-aware — the naive one is what `subst_token()` calls.

**T7 — ⚠ the stack is LEFT-aligned with a ragged RIGHT edge, even though the wire label is right-anchored.** `cairo_draw_string_line()` for `rot==0 && flip==1` does `ix = ix - longest_line` for **every** line, where `longest_line` is the whole block's width (from `text_bbox`), not that line's own; `llength` is passed in but used only for the `if(llength==0) return;` guard. Measured: all three of pA's lines start at x=586.721, so `iref_trim<2:0>` reaches the anchor and `en_fast` stops well short of the wire. `lab_pin.sym`'s record is `T {@lab} -7.5 -8.125 0 1 0.33 0.33 {}` — **flip=1** — so every label on that side is affected. A neat left-aligned column is plausibly exactly what the user wants, but they have not ruled on it: **route it, do not decide it.**

**T8 — the stack grows DOWNWARD from the anchor, across the wire.** Measured y 98.9232 → 155.787 → 212.651, increasing. `lab_pin.sym`'s `@lab` anchor is at symbol y0 = −8.125, just above the pin, so an N-token stack extends down over the wire and pin. There is **no per-instance dy override for a symbol text** today — `get_sym_text_size()` and `get_sym_text_layer()` cover size and layer only — so raising the block by (N−1) lines would mean a new per-instance attr on their precedent (`text_dy_%d`), or accepting downward growth. Either way it is a visible layout consequence, not a detail.

**T9 — `cairo_font_line_spacing` is honoured on screen and IGNORED by every export back end.** `cairo_draw_string_line()` multiplies by it; `svg_draw_string_line()` and `ps_draw_string_line()` use a bare `line_delta = lineno*fontheight`. Proven, not inferred: at `::cairo_font_line_spacing 2.0` the re-exported SVG was **byte-identical** (same y 98.9232 / 155.787 / 212.651). Pre-existing divergence, but it means a user who tuned that knob gets a stacked label that looks different on screen and in a PDF — and the screen is the only place the user's forbidden blank line can appear.

**T10 — in headless export, the bbox is measured with a different metric than the draw uses.** `text_bbox()` (`src/actions.c`) falls back to `text_bbox_nocairo()` when `!has_x && !xctx->cairo_ctx` — pitch 65 units per line — while `svg_draw_string()`/`ps_draw_string()` draw at `height = size*xctx->mooz*1.147`. Only the `textclip()` decision rides on it, so the risk is a clip verdict taken on the wrong height. Pre-existing; flagged because a multi-line block is far likelier to reach a clip edge than any single line was.

**T11 — do not rely on a backslash in a hand-written `.sch`.** `load_ascii_string()` consumes a single `\` as an escape, so `lab=a\<newline>b` arrives as a bare newline and truncates. Only double-quoting works in the file, and only `\\` survives as a literal backslash. Irrelevant if you follow the recommendation (no newline in `lab=` at all), but it will bite anyone hand-building a fixture.

### `git status --short` on finishing

Literal output of `git status --short` in /home/analog/dev/xschem-claude on completion:

```
?? .xschem/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
```

Both were present in the session-start snapshot, byte-identical — I added neither. `git diff --stat` is empty: no tracked file changed. Nothing was written into the repo, no commit, no stash.

Every write went to `/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/probe/`: my fixtures `ml.sch`, `nl.sch`; my probe scripts `probe.tcl`..`probe6.tcl`; outputs `out.txt`..`out5.txt`, `stdout*.txt`, `stderr*.txt`, `ml.svg`, `ml_ls2.svg`, `netl/nl.spice`. Both `xschem saveas` calls targeted scratch paths I had just created (`ml_rt.sch`, `ml_rt2.sch`) — never a tracked path and never the file the probe had loaded; xschem also left its own `ml_rt~.sch` backup there. Note for the driver: that probe directory additionally contains `home`, `meg.tcl`, `out.sch`, `out2.sch`, `out3.sch` and `p.tcl`..`p8.tcl`, which are **not mine** — sibling crews in this workflow run share the same session scratchpad path, so treat that directory as shared rather than as one crew's record.


==============================================================================

## ANGLE 2 — where a per-instance display flag lives, and what reads it

**Verdict on the driver's lean:** `CONFIRMED`

### What was measured

THE CRUX IS CONFIRMED: the visible text belongs to the SYMBOL.

`draw_symbol()` (src/draw.c) takes its text attributes from the shared symbol array, not the instance:

    for(j=0;j< symptr->texts; ++j) {
      get_sym_text_size(n, j, &xscale, &yscale);
      text = symptr->text[j];            /* <-- STRUCT COPY out of the SHARED array */
      ...
      my_strdup2(_ALLOC_ID_, &txtptr, translate(n, text.txt_ptr));

`symptr` is `xctx->inst[n].ptr + xctx->sym`. Every attribute drawn (`text.rot`, `text.flip`,
`text.hcenter`, `text.vcenter`, `symptr->text[j].layer`, `symptr->text[j].font`, the
TEXT_BOLD/ITALIC/OBLIQUE flags) is symbol-owned and shared by every instance. Only two things
are per-instance: the instance's own `rot`/`flip` (combined arithmetically with the text
record's) and the STRING, which comes from `translate(n, text.txt_ptr)` expanding `@lab`
against `xctx->inst[n].prop_ptr`.

The tree already states this crux in words, at the declaration of `text_hidden_inst` in
src/xschem.h: "The declutter's per-instance gate (ruling D-6) cannot live in xText.flags,
because draw_symbol() walks symptr->text[j] and that array is SHARED by every instance of the
symbol; the instance index is how it travels instead."

THE PRECEDENT, IN FULL — THERE ARE THREE SITES, NOT ONE, AND THE THIRD IS THE BEST TEMPLATE.

(1) READER. `get_sym_text_layer(int inst, int text_n, int *layer)` in src/draw.c, verbatim:

      *layer = -1;
      if(sym_n >= 0 && xctx->sym[sym_n].texts > text_n) {
        if(xctx->inst[inst].prop_ptr && strstr(xctx->inst[inst].prop_ptr, "text_layer_")) {
          my_snprintf(attr, S(attr), "text_layer_%d", text_n);
          tl = get_tok_value(xctx->inst[inst].prop_ptr, attr, 0);
        } else {
          xctx->tok_size = 0;
        }
        if(xctx->tok_size) { lay = atoi(tl); if(lay >= 0 && lay < cadlayers) *layer = lay; }
      }

Its twin `get_sym_text_size(int inst, int text_n, double *xscale, double *yscale)` reads
`text_size_%d` the same way and falls back to `symptr->text[text_n].xscale/yscale` when absent.
Shape to copy exactly: index `<n>` is `j`, the position of the `T {...}` record in the .sym
file; absent token -> the symbol default; the `strstr` fast path MUST manually set
`xctx->tok_size = 0` in its else arm, because `tok_size` is a shared global side-channel written
by `get_tok_value` and a stale nonzero would make the code `atoi(NULL)`.

(2) INDEX RESOLVER + READBACK SEAM. `xschem inst_name_text <inst>` in `scheduler()`
(src/scheduler.c) finds the label text record by STRING MATCH, not by hardcoded index:

      for(j = 0; j < xctx->sym[symn].texts; ++j) {
        const char *tp = xctx->sym[symn].text[j].txt_ptr;
        if(tp && !strcmp(tp, "@lab")) { idx = j; break; }
      }
      ... get_sym_text_size(i, idx, &xs, &ys);
      my_snprintf(buf, S(buf), "%d %.10g", idx, xs);

Returns `"<index> <effective size>"`, or `""` for a non-label symbol. This is both the robust
index resolver and a ready-made headless assertion seam.

(3) WRITERS — two, one C and one Tcl.
  * C, at creation: `add_pin_stubs()` in src/actions.c appends the token to the prop string it
    hands `place_symbol()`:
        my_mstrcat(_ALLOC_ID_, &prop, "name=l0 lab=", netname ? netname : "",
                   " text_size_0=", szbuf, NULL);
        place_symbol(-1, lab_sym, g.x2, g.y2, lrot, lflip, prop, 0, first, 0);
  * Tcl, post-hoc on a selected instance: `textsize_apply` in utils/text_resize.tcl (the
    CTRL+Plus/Minus feature) builds `[list instance $d(index) text_size_$ti $nt]` where `$ti`
    came from `xschem inst_name_text`, and hands it to `busresize::apply_changes`
    (utils/bus_resize.tcl), which is:
        xschem push_undo
        ... xschem setprop -fast instance $idx $arg $val
            xschem recompute_inst_bbox $idx
        xschem redraw
    That `recompute_inst_bbox` call is the part an implementer forgets.

ENUMERATION — every per-instance override of a symbol TEXT, complete:
  * `text_layer_<n>=` -> get_sym_text_layer (draw.c, svgdraw.c, psprint.c)
  * `text_size_<n>=`  -> get_sym_text_size  (draw.c x3, svgdraw.c, psprint.c, select.c, scheduler.c)
  * `hide_texts=true` -> HIDE_SYMBOL_TEXTS bit, parsed in src/actions.c (`get_tok_value(inst->prop_ptr,
    "hide_texts",0)`), gates the WHOLE text loop at all four back ends; whole-instance, not per-record
  * `hide=true` -> HIDE_INST; plus the annotation declutter via `text_hidden_inst(flags, n)`
  * the STRING itself, via `translate(n, ...)` / `translate3(..., inst[n].prop_ptr, ...)`
  * `xctx->inst[n].color` (highlight) — per instance but not a token
That is all. There is NO per-instance override of font, rot, flip, hcenter or vcenter.

THE SIX READER CALL SITES (xschem.h names them as a canonical set; all six have the identical
`translate(n, text.txt_ptr)` -> draw/measure shape, so one shared helper slots into all six):
  draw_symbol() and draw_temp_symbol() and inst_text_bbox() (src/draw.c),
  svg_draw_symbol() (src/svgdraw.c), ps_draw_symbol() (src/psprint.c),
  symbol_bbox() (src/select.c).

THE RENDERER ALREADY STACKS ON '\n' — NOTHING TO BUILD THERE. Measured, not inferred. All five
string writers split on `\n` and emit one line per split with a `lineno`-scaled offset: cairo
`draw_string`/`cairo_draw_string_line`, nocairo `draw_string`, `svg_draw_string`,
`ps_draw_string`, `old_ps_draw_string`. `text_bbox()` (src/actions.c) counts them
(`if((str)[c++]=='\n') {(*cairo_lines)++; h++; length=0;}`), so the bbox — and therefore the
click target through symbol_bbox, and the redraw box — grows automatically.

LIVE RENDER PROOF (my probe, three lab_pin instances, `xschem print svg`, text_svg default 1):

  <text ... transform="translate(25.8227, 58.5895)" >bg_trim[3:0],en_fast,iref_trim[2:0]</text>
  <text ... transform="translate(584.823, 243.771)" >bg_trim[3:0]</text>
  <text ... transform="translate(584.823, 304.519)" >en_fast</text>
  <text ... transform="translate(584.823, 365.266)" >iref_trim[2:0]</text>
  <text ... transform="translate(903.823, 552.408)" >a</text>
  <text ... transform="translate(903.823, 673.903)" >b</text>

Instance 1 (`lab=bg_trim[3:0],en_fast,iref_trim[2:0]`) = ONE line — the vjust-OFF rendering.
Instance 2 (`lab="...\n...\n..."`) = THREE lines, y-deltas 60.748 and 60.747, uniform,
single-spaced, same x (584.823) so left-aligned, growing DOWNWARD from the anchor — exactly the
vjust-ON picture. `cairo_font_line_spacing` defaults to 1.0 (src/globals.c), so single-spacing
is the default, not a setting.
Instance 3 (`lab="a\n\nb"`, a DOUBLE newline) = TWO lines at 552.408 and 673.903, delta
121.495 = 2 x 60.748. THE BLANK LINE IS REAL AND MEASURED.

### Recommended mechanism

STORE: keep `lab=` canonical and comma-separated. Add a sibling per-instance token
`text_vjust_<n>=1`, imitating `text_layer_<n>=` / `text_size_<n>=` exactly (same family, same
index convention, same absent-token-means-default rule).

READ: one new helper in src/draw.c beside its two siblings —

    void sym_text_vstack(int inst, int text_n, char **s)

— byte-for-byte the `get_sym_text_layer` shape (`strstr(prop_ptr, "text_vjust_")` fast path
with the mandatory `xctx->tok_size = 0;` else arm, `get_tok_value(..., "text_vjust_%d", 0)`),
which when the token is truthy rewrites `*s` in place, replacing each run of separators with a
single `\n` and dropping empty tokens. ONE helper, SIX call sites, called as the LAST transform
before the draw/measure call at each: `draw_symbol()`, `draw_temp_symbol()`, `inst_text_bbox()`
(draw.c), `svg_draw_symbol()` (svgdraw.c), `ps_draw_symbol()` (psprint.c), `symbol_bbox()`
(select.c). Prototype next to the other two in src/xschem.h (~line 3256). Six copies of the
logic is the drift the codebase calls invariant I1 and forbids.

DO NOT put the transform in `translate()` (src/token.c). It is tempting — it would cover all six
sites with one edit — and it is wrong: `translate()` is called from 77 sites including
netlist.c, spice_netlist.c, spectre_netlist.c, verilog_netlist.c and save.c. Newlines would
reach the deck.

WRITE, at creation (the primary path): mirror `add_pin_stubs()`. Give `place_wire_label()` a
second parameter — `int place_wire_label(const char *name, int vjust)` — and build

    my_mstrcat(_ALLOC_ID_, &prop, "name=l1 lab=", name, vjust ? " text_vjust_0=1" : "", NULL);

Precedent for the index literal `0`: `add_pin_stubs()` already hardcodes `text_size_0=` for
lab_pin.sym. If you prefer the robust form, resolve the index the way `xschem inst_name_text`
does (strcmp the record's `txt_ptr` against `"@lab"`).

The flag reaches C exactly the way the Add-Pin form's direction does. `addpin::` sets
`::pin_new_name` + `::pin_new_dir`; the `add_sch_pin -place` arm of `scheduler()` reads both
with `tclgetvar` and passes both to `place_sch_pin(nm, dr)`. Copy it: `addlabel::arm` sets
`::label_new_name` and a new `::label_new_vjust` beside it; the `add_wire_label -place` arm
(src/scheduler.c, which today reads only `tclgetvar("label_new_name")`) reads both and calls
`place_wire_label(nm, vjust)`.

WRITE, post-hoc on an existing label (optional, if a right-click "stack bus labels" is wanted):
`textsize_apply` in utils/text_resize.tcl is the whole template — `xschem inst_name_text $idx`
for the record index, then `busresize::apply_changes {{instance $idx text_vjust_$ti 1}}`, which
does `push_undo` + `setprop -fast instance` + `recompute_inst_bbox` + `redraw`.

SAVE/LOAD AND UNDO COST NOTHING. `save_inst()` -> `save_ascii_string(inst[i].prop_ptr, fd, 1)`
writes the prop verbatim; `in_memory_undo.c` stores `iptr[i].prop_ptr`. Measured: I placed
`name=l3 lab=plain text_size_0=0.8` through `place_symbol` and read it back intact
(`xschem getprop instance 2` -> `name=l3 lab=plain text_size_0=0.8`,
`getprop instance 2 text_size_0` -> `0.8`), so `new_prop_string` preserves an unrecognised
token. The only code that must additionally know about the flag is the bbox path, and it does
not need to be taught: `symbol_bbox()`/`inst_text_bbox()` call the same helper and `text_bbox()`
counts the newlines.

RE-ARM IS SAFE FOR A PROP TOKEN, AND THAT IS NOT LUCK — IT IS WHY THE FLAG MUST GO THROUGH C.
The `-place` re-arm in `scheduler()` deletes the old preview (`select_placement_preview() > 0` ->
`delete(0)`) and calls `place_wire_label(nm)` again, which REBUILDS the prop from scratch. So a
token supplied by C is regenerated on every keystroke and cannot be lost. The earlier recon's
finding that ORIENTATION is lost on re-arm has the same cause read the other way:
`place_wire_label` passes literal `0, 0` for rot/flip, so anything the user did to the preview
instance by hand is discarded. COROLLARY: if the flag were applied from Tcl after placement
(`xschem setprop instance ...`), it WOULD be wiped on the next keystroke. Do not do that on the
`-place` path.

### Blockers

TWO BLOCKERS, BOTH IN TCL, AND THEY MAKE THE OBVIOUS "JUST ENABLE THE CHECKBOX" IMPOSSIBLE.
Measured with the two procs' own bodies under `tclsh` on the user's exact example:

  expand_names(user example) = {bg_trim[3:0]} en_fast {iref_trim[2:0]}  (n=3)
  name_ok(whole comma list, <> form)   = 0
  name_ok(whole comma list, [] form)   = 0
  name_ok(single token bg_trim<3:0>)   = 1
  name_ok(en_fast)                     = 1

(1) `addlabel::expand_names` (src/xschem.tcl) tokenises on `regexp -all -inline {[^,\s]+}`, so a
COMMA IS ALREADY A LABEL SEPARATOR. The user's `bg_trim<3:0>,en_fast,iref_trim<2:0>` becomes a
QUEUE OF THREE labels placed one at a time. The vjust feature needs the same string to be ONE
label. The two readings of a comma are in direct conflict and `expand_names` must branch on
vjust: vjust off -> today's behaviour untouched; vjust on -> return a single-element list
holding the whole (normalised, separator-collapsed) entry.

(2) `addlabel::name_ok` REJECTS the whole comma list — its regexp
`^[^][{}<>;:]+(\[[0-9]+(:[0-9]+)?\])?$` permits at most ONE trailing bus suffix, so anything
after `[3:0]` fails. `addlabel::arm` gates on it:

    if {![addlabel::name_ok $current]} { ... addlabel::status_error "'$current' has a syntax
    error -- fix it to place (use \[\] or <> for buses)" ; return }

So with today's Tcl, ticking vjust and typing the user's example arms NOTHING — red status, no
preview, no instance. `name_ok` needs a vjust-aware form that validates each comma token
separately and requires all of them to pass.

Neither blocker is in C. The C side of this feature is small; the form is where the work is.

MINOR, SAME AREA: the checkbox is `-state disabled` and has no `-command`, so besides enabling
it you must add `-command addlabel::on_vjust_change` -> `addlabel::start_pass`, or toggling the
box will not re-arm the preview (compare `on_split_change`, which exists for exactly this).
And the status line "type a Label Name (space/comma-separated for several)" now states something
that is only true with vjust off — user-visible copy, so the driver's call, not mine.

### The fence

`tests/headless/test_add_wire_label.tcl` fences this. It IS REGISTERED — once, in `hcases`
alone (`"headless/test_add_wire_label" \` in tests/run_regression.tcl; `grep -c` over the whole
file returns 1, and 0 inside the `dcases` block). Its epilogue is

    if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
    else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }

so it emits the bare `OVERALL: ok` whole-line sentinel `banner_complete` (tests/banner_rule.tcl)
requires, with `RESULT:` printed BEFORE it — note that ordering is the opposite of the
`RESULT:`-last convention CLAUDE.md records for `wvbs_finish`; `summarize_all` publishes a
case's LAST `RESULT:` line, and here there is only one, so it is fine either way. It prints zero
`skip:` lines, so registering rows here does not move `skips=`.

Baseline measured just now:
    $ timeout 240 tests/headless/run_suites.sh --nogui test_add_wire_label
    test home: throwaway /tmp/xschem-test-home.1088384.hiuaDz (your HOME is untouched; ...)
    display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
    PASS     | test_add_wire_label          run 1/1  RESULT: ALL PASS (196 checks)
    RESULT: 1/1 runs passed

It is pure headless (does NOT source scratch.tcl, so no watchdog and no scratch helper), fakes
`winfo` so the `addlabel::` procs are drivable under `--nogui`, and already has the exact idioms
a red-first vjust row needs: `proc inst_lab {i} {xschem getprop instance $i lab}`,
`xschem instance [find_file_first lab_pin.sym] 200 0 0 0 {name=l1 lab=Z}`, and direct calls to
`addlabel::expand_names` / `addlabel::start_pass` / `addlabel::arm`.

THE READER HALF HAS NO REGISTERED FENCE TODAY, AND THE TWO SUITES THAT COVER THE PRECEDENT ARE
BOTH UNREGISTERABLE AS WRITTEN. `tests/text_size.tcl` and `tests/wire_stub_netlabel.tcl` are the
only suites exercising `text_size_<n>`; neither appears in run_regression.tcl and NEITHER PRINTS
`OVERALL: ok` — they end `puts "text_size: all checks PASS"` and `puts "ALL PASS
(wire_stub_netlabel)"` respectively. That is precisely the `test_wave_sigbrowser*` defect family
CLAUDE.md records: `run_suites.sh` and `full_audit.sh` accept those spellings, `banner_complete`
does not. So do not try to hang reader rows off them; put them in `test_add_wire_label`.
(`tests/headless/test_empty_value_swallows_token_0183.tcl` also mentions the tokens and is
likewise unregistered — one of the 334.)

A FULLY MECHANICAL RED-FIRST ROW FOR THE RENDER HALF, no eyes needed: `xschem print svg` works
under `--nogui` (I used it), `text_svg` defaults to 1 (src/globals.c), and `xschem zoom_full` is
MANDATORY first — without it my first two probes produced an SVG containing only the background
rect and no `<text>` at all, because nothing was inside the view. Then count `<text>` elements
and assert the `translate(x, y)` y-deltas are uniform: 1 element for the comma form, 3 with
uniform spacing for the vjust form, and — the row that fences "no blank lines" — 3 and not a
2x-delta gap for an entry with a doubled or trailing separator. `xschem inst_name_text <inst>`
is the second, cheaper seam (asserts the resolved record index without rendering).

### Traps

1. ⚠ A NEWLINE IN AN UNQUOTED `lab=` SILENTLY TRUNCATES THE LABEL. `#define SPACE(c)` in
src/token.c is `( c=='\n' || c==' ' || c=='\t' || c=='\0' || c==';' )`, so a newline ENDS a
token. Measured:
    xschem translate3 {@lab} 0 "lab=bg_trim[3:0]\nen_fast\niref_trim[2:0]"  =>  bg_trim[3:0]
The other two bus names are parsed as bare tokens and vanish. `xschem subst_tok "lab=a\nen_fast"
en_fast <NULL>` returns `name=l1 lab=a\n`, proving `en_fast` really was read as its own token.

2. ⚠⚠ AND THE QUOTED FORM IS WORSE, NOT SAFER — THIS IS THE REAL REFUTATION. A double-quoted
value DOES carry a newline (`lab="a\nb"` round-trips, and `subst_token` AUTO-QUOTES when you
write a newline value), so a careless implementer will find that "it works". Then the bus
expander corrupts it. `xschem expandlabel` (the bison grammar in src/expandlabel.y, which the
netlister and bus machinery use):

    bg_trim[3:0],en_fast,iref_trim[2:0]  =>  bg_trim[3],bg_trim[2],bg_trim[1],bg_trim[0],
                                             en_fast,iref_trim[2],iref_trim[1],iref_trim[0]   8
    bg_trim[3:0]\nen_fast               =>  bg_trim[3]en_fast,bg_trim[2]en_fast,
                                             bg_trim[1]en_fast,bg_trim[0]en_fast              4

The newline is swallowed as whitespace and the two tokens are CONCATENATED into one bit name.
Four plausible-looking, wholly wrong net names, with no error. That is the measurement that
settles the driver's lean: the COMMA is the bus-concatenation operator in that grammar, and it is
what makes the user's 8-bit example eight bits.

3. ⚠ THE USER'S OWN EXAMPLE, TYPED LITERALLY, IS NOT AN 8-BIT BUS UNTIL `<>` IS NORMALISED.
`xschem expandlabel {bg_trim<3:0>,en_fast,iref_trim<2:0>}` returns the string unchanged with
count 3. Only the square-bracket spelling expands to 8. The normalisation that saves it is the
`string map {< \[ > \]}` inside `addlabel::expand_names` / `addlabel::name_ok`, which a
vjust-aware rewrite of those two procs must keep doing per token.

4. ⚠ A DOUBLED OR TRAILING SEPARATOR PRODUCES A REAL BLANK LINE — the thing the user explicitly
forbade. `cairo_draw_string_line()` opens `if(llength==0) return;` so the empty line draws
nothing, but the caller still does `++lineno`, so it consumes a full line of height, and
`text_bbox` still does `h++`. Measured above: `lab="a\n\nb"` rendered two `<text>` elements
121.495 apart against 60.748 for a single-spaced pair. The stacking helper MUST collapse runs of
separators and drop empty tokens: `a,,b` -> 2 lines, `a,b,` -> 2 lines.

5. THE INDEX `<n>` IS POSITIONAL IN THE .sym FILE. For xschem_library/devices/lab_pin.sym the
records are `T {@lab} -7.5 -8.125 0 1 0.33 0.33 {}` (index 0) then
`T {@spice_get_voltage} ... {layer=15}` (index 1). `add_pin_stubs()` already bets on 0, so the
bet is precedented — but a reordered or site-local lab_pin.sym breaks it silently. The tree
already contains the fix: resolve the index by `strcmp(txt_ptr, "@lab")`, which is what
`xschem inst_name_text` does.

6. `xctx->tok_size` IS A SHARED GLOBAL SIDE-CHANNEL, and the `strstr` fast path in both existing
readers exists only to avoid a `get_tok_value` call — which is exactly why each has to set
`xctx->tok_size = 0` by hand in its else arm. Omit that line and a stale nonzero from an earlier
lookup makes the code `atoi()` a NULL. `ua_instance_eligible_ex()` in src/token.c latches and
restores `tok_size` for the same reason, with a comment saying an observer "may never become the
reason a real netlist value goes missing".

7. A COMMENT/CODE CONTRADICTION, exactly the class CLAUDE.md warns about. The header of the
`addlabel` namespace in src/xschem.tcl says: *"'Place multiple labels at once' and 'Vertically
justified' are reserved (inert) for later"* and the variable is declared `variable vjust 0 ;#
reserved (inert)`. Both are true of the CODE, and both are now false of the FEATURE — and the
same header's sentence "the Label Name field takes one or more names (a QUEUE)" describes the
comma semantics that vjust overturns. Three sentences in one comment block need to change with
this work, or the file becomes its own counterexample.

8. NOT A TRAP, CHECKED SO NOBODY ELSE SPENDS THE TIME: the new token will NOT trip the
"unused instance attribute" diagnostic. `ua_token_lost()` matches the stoplist with plain
`strcmp`, and `text_vjust_0` is not on it — but `ua_instance_eligible_ex()` opens with
`if(!type || strcmp(type, "subcircuit")) return 0;`, and lab_pin.sym declares `type=label`. The
diagnostic never looks at a net label. This is also why the shipped `text_size_0=` from
`add_pin_stubs` has never produced a warning.

9. BBOX AND DRAW ALREADY DISAGREE SLIGHTLY, and the helper must not paper over it:
`draw_symbol()` and `draw_temp_symbol()` run `translate()` THEN `translate3()`;
`symbol_bbox()` and `inst_text_bbox()` run `translate()` only. Insert the stacking call after
whatever the site's LAST transform is, per site — not at a uniform position in a diff.

10. The stack grows DOWNWARD and LEFT-ALIGNED from the anchor (lab_pin.sym's `@lab` record is
rot=0 flip=1, so the cairo path does `ix -= longest_line` once for all lines). A three-token
stacked label therefore extends further below its connection point than the one-line form, and
because `symbol_bbox()` folds text into `inst[i].x1..y2`, THE CLICK TARGET MOVES WITH IT. That
is the correct answer, and it is user-visible; the same consequence is recorded for
`text_hidden_inst` in src/actions.c as rule debt 1244_A3_click_target, which is the precedent
for filing a `look`/`rule` debt here rather than treating it as invisible.

### `git status --short` on finishing

?? .xschem/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/

Byte-identical to the session-start snapshot; both entries pre-existed (`.xschem/` mtime Sep 9
09:58, untouched). I made no edits, no commits and no writes into the repo. All probe scripts,
outputs and the four generated SVGs live under
/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/a2/.
Every xschem invocation was `timeout <n> env -u DISPLAY ./src/xschem --nogui -q --script ...`
(the user's real X server at 172.20.160.1:0 was never touched), no `xschem save`/`saveas` was
ever called, and the one suite run went through `tests/headless/run_suites.sh --nogui`, which
armed a throwaway HOME (/tmp/xschem-test-home.1088384.hiuaDz).


==============================================================================

## ANGLE 3 — what must the stored `lab=` look like, and who already splits on commas?

**Verdict on the driver's lean:** `CONFIRMED`

### What was measured

HEADLINE, and it is the one thing that changes the design: **the comma form netlists correctly ONLY with SQUARE brackets. The angle-bracket form the user types produces a silently WRONG netlist.** Both measured end to end.

METHOD. Built a scratch library (all under my scratchpad, nothing in the repo): `bus8.sym` = one 8-bit bus pin `name=P[7:0]`, `type=subcircuit`, `format="@name @pinlist @symname"`; `bus8.sch` = `ipin.sym lab=P[7:0]`; four top schematics each with a bus wire from a `lab_pin.sym` to that pin, differing ONLY in the `lab=` spelling. Then `xschem netlist` under `--nogui`, `netlist_dir` pointed at scratch. The `x1 … bus8` line IS the answer: it shows, in pin order, exactly which nets the label produced.

(1) `lab=bg_trim[3:0],en_fast,iref_trim[2:0]` — **CORRECT**:
    x1 bg_trim[3] bg_trim[2] bg_trim[1] bg_trim[0] en_fast iref_trim[2] iref_trim[1] iref_trim[0] bus8
    Eight nets, right order, zero warnings on stderr. `xschem expandlabel` agrees: mult **8**.
    → The comma form IS canonical today. The feature's premise holds.

(2) `lab=bg_trim<3:0>,en_fast,iref_trim<2:0>` (what the user TYPES) — **SILENTLY WRONG**:
    x1 bg_trim<3:0> en_fast iref_trim<2:0> bg_trim<3:0> en_fast iref_trim<2:0> bg_trim<3:0> en_fast bus8
    `xschem expandlabel {bg_trim<3:0>,en_fast,iref_trim<2:0>}` → mult **3**, not 8. `<` and `>` are ordinary IDENTIFIER characters in `parselabel.l`'s `LAB`/`LAB_NUM`/`LAB_NUM_SP` classes — NOT bus-range delimiters. So `bg_trim<3:0>` is ONE scalar net whose name happens to contain `<3:0>`. The 3-element list is then cycled over the 8 pins; `bg_trim<3:0>` lands on pins 7, 4 and 1. **Zero warnings, zero yyerror lines** (I counted: all 14 `yyerror` lines in the run came from case 3 below, none from this one). `hilight_net_pin_mismatches()` (hilight.c) could catch it, but it is a user-invoked highlight command, not a netlist-time guard.

(3) `lab="bg_trim[3:0]\nen_fast\niref_trim[2:0]"` (quoted, real newlines) — **MANGLED + error dialog**:
    x1 bg_trim[3]en_fast bg_trim[3]en_fast bg_trim[3]en_fast bg_trim[3]en_fast bg_trim[3]en_fast bg_trim[3]en_fast bg_trim[3]en_fast
    + bg_trim[3]en_fast
    iref_trim
    bg_trim[2]en_fast
    iref_trim
    … iref_trim bus8
    The newline after `]` drives `parselabel.l` into its `parse_trailer` start condition (`\]/[^*,)]` → `BEGIN(parse_trailer)`), so `en_fast\niref_trim` is absorbed as a bus TRAILER and concatenated onto every bit. Net names contain literal newlines, so the SPICE deck itself is broken across physical lines — unparseable by any simulator. And stderr carried `yyerror(): yyparse():syntax error` + `syntax error in bg_trim[3:0]…`; `expandlabel()` in `parselabel.l` follows that with `if(has_x) tcleval(cmd)` on a `tk_messageBox -icon error`, so in a GUI session the user gets an error popup per netlist.

(4) `lab=bg_trim[3:0]` + raw unquoted newlines — **SILENTLY TRUNCATED**:
    x1 bg_trim[3] bg_trim[2] bg_trim[1] bg_trim[0] bg_trim[3] bg_trim[2] bg_trim[1] bg_trim[0] bus8
    `xschem getprop instance 1 lab` returned `bg_trim[3:0]` and nothing else. `SPACE(c)` in `src/token.c` is `( c=='\n' || c==' ' || c=='\t' || c=='\0' || c==';' )`, and `get_tok_value`'s state machine leaves TOK_VALUE on an unquoted space, so a raw newline TERMINATES the value. Tokens 2 and 3 become stray bare tokens in `prop_ptr`. Round-tripped through `xschem saveas` to scratch, both the comma form and the quoted-newline form survive verbatim — `save_ascii_string` (save.c) escapes only `\`, `{`, `}`, so a newline is written literally inside the `{…}` block and the quotes are what preserve it. So the newline form is STORABLE. It is just wrong.

BONUS, and it settles the bracket question: `bus_replacement_char` is the sanctioned route to angle brackets in output. With `::bus_replacement_char {<>}` and the SAME stored `lab=bg_trim[3:0],en_fast,iref_trim[2:0]` the netlist became
    x1 bg_trim<3> bg_trim<2> bg_trim<1> bg_trim<0> en_fast iref_trim<2> iref_trim<1> iref_trim<0> bus8
    .subckt bus8 P<7> P<6> … P<0>
`expandlabel()` does that substitution itself (`str_char_replace(dest_string.str, '[', bus_char[0])`, gated on `xctx->netlist_type == CAD_SPICE_NETLIST`), driven by `netlist_options()` in netlist.c / `spice_netlist.c`. **`[hi:lo]` is the canonical STORED spelling; `<>` in the netlist is a user preference, never a stored form.**

WHO CONSUMES `lab=`, and what each requires (all want the same thing: expandlabel-parseable, comma-separated, `[hi:lo]` ranges):
- `net_name()` in **src/token.c** — the single canonical consumer. Calls `expandlabel()` on the instance's node and returns the comma-separated expanded bit list plus `*multip`. Everything downstream inherits its spelling requirement.
- `expandlabel()` in **src/parselabel.l** (+ the bison grammar in `expandlabel.y`) — fast path `if(!strpbrk(s, "*,.:") || s[0] == '$')` returns the string untouched; anything with a comma or colon goes through the parser. The comma is the grammar's LIST separator (`{SP},{SP}` → returns `','`). A newline is `{SP}` at top level but is ALSO inside `LAB_NUM_SP` and `IDX_LAB_NUM_SP`, which is why it gets glued into identifiers instead of separating them.
- `bus_hilight_hash_lookup()` in **src/hilight.c** — `expandlabel()`s the token, then walks the result splitting on `,` and inserting ONE hash entry per bus element. Its own fast path is `if( token[0] == '#' || !strpbrk(token, "*,.:"))`. So highlighting depends on the comma spelling exactly as netlisting does.
- `resolved_net()` in **src/hilight.c** (~line 2868) — `expandlabel()` then `my_strtok_r(n_s1, ",", …)` per bit, for raw-file net resolution.
- `hilight_net_pin_mismatches()`, `hilight_parent_pins()` etc. — same `expandlabel` + comma-walk shape.
- **src/findnet.c** — does NOT read `lab=` directly; it works off the wire's resolved `node`, i.e. downstream of `net_name()`.
- `print_spice_subckt_nodes()` / the `@pinlist` handlers in **src/token.c** — where the expanded list is emitted into the deck.
- `lab_pin.sym`'s own `format="*.alias @lab"` also interpolates the raw `lab=` value (it produced no line in my minimal top, but it is a text consumer of the raw string).

`addlabel::expand_names` (src/xschem.tcl), read line by line and measured:
- Tokenises with `regexp -all -inline {[^,\s]+}` — **commas and whitespace are the SAME separator**. `a, b ,  c` → 3 tokens; `A B` → 2 tokens; `a,,b` → 2 tokens; ` , ,a, ` → 1 token. Empty runs and leading/trailing separators vanish. **The separators are DISCARDED — the returned list cannot tell the caller whether the user typed commas or spaces.**
- Then `string map {< \[ > \]}` per token — **always**, even with Split bus OFF. Measured: `expand_names {bg_trim<3:0>,en_fast,iref_trim<2:0>} 0` → `{bg_trim[3:0]} en_fast {iref_trim[2:0]}`, i.e. **3 tokens, square-bracketed**.
- With `split_bus 1` the same input gives 8 tokens, one per bit.
- Guards worth knowing: `scan %d` forces decimal (so `A[08:0]` is 9 bits, not an octal throw), and a range wider than 4096 is kept as a single vector token.

Is its token list the right source for the DISPLAY lines? **No, on three counts.**
1. It discards the separators, so it cannot distinguish "one stacked label" from "three separate labels" — and those are exactly the two things vjust has to tell apart.
2. With Split bus ON it returns 8 tokens, not 3 — the wrong granularity for stacking.
3. It normalises `<>`→`[]`. **But note carefully: that normalisation is not a bug to route around, it is what makes the netlist correct.** The right shape is a separator-preserving tokeniser (or reading `$addlabel::name` directly) for the DISPLAY lines, and `expand_names`-style normalisation for the STORED value.

Is there an existing canonical "split a label list for display" helper? **No — this would be the first.** Every comma splitter in the Tcl tree splits the OUTPUT of `xschem expandlabel` (the already-expanded bit list), never a user-typed token list: `op_annot::_elements` in src/op_annot.tcl, the vector-instance descend in src/xschem.tcl (`set inst_list [split [lindex [xschem expandlabel …] 0] {,}]`), `src/ase.tcl` (3 sites), `src/ase_window.tcl`. `addlabel::expand_names` is the ONLY tokeniser of a user-typed label list in the tree.

The RENDERING side already works, which is worth knowing before anyone reaches for a new mechanism: `lab_pin.sym` draws the name with a single text object `T {@lab} -7.5 -8.125 0 1 0.33 0.33 {}`; `draw_symbol()` in src/draw.c substitutes it with `translate(n, text.txt_ptr)` (which is `get_tok_value(prop,"lab",0)`, newlines preserved — measured) and hands it to `draw_string()`, which splits on `'\n'` and lays out consecutive lines. Cairo path advances by `fext.height` per line, non-Cairo by `(FONTHEIGHT+FONTDESCENT+FONTWHITESPACE)*yscale`. **One `\n` per break = single-spaced consecutive lines, no blank line**; `text_bbox()` counts `no_of_lines`/`longest_line` so the bbox grows correctly. A blank line can only appear if someone emits `\n\n` or a trailing `\n`.

`vjust` has exactly FOUR mentions in the entire tree, all in src/xschem.tcl — the namespace comment, `variable vjust 0`, the `ttk::checkbutton … -state disabled`, and its `grid`. Zero readers, as stated.

### Recommended mechanism

Both halves of the lean are confirmed — `lab=` stays comma-separated, stacking is display-only — with ONE addition the lean does not mention and must not be read as excluding: **the stored `lab=` must also be square-bracket normalised.** "Canonical comma-separated form" means comma-separated AND `[hi:lo]`, never the `<…>` the user typed.

CONCRETE SHAPE, by symbol:

1. STORAGE stays exactly as it is. `addlabel::arm` sets `::label_new_name`; `xschem add_wire_label -place` → `place_wire_label(name)` in src/actions.c builds `"name=l1 lab=" + name` and hands it to `place_symbol()`. Do not touch that string. The only change is WHAT `::label_new_name` holds: with vjust ON it must be the whole comma list, joined with `,` and `<>`→`[]` normalised — i.e. `bg_trim[3:0],en_fast,iref_trim[2:0]`. Exactly the spelling measured correct.

2. A NEW separator-preserving tokeniser beside `addlabel::expand_names`, e.g. `addlabel::split_display_tokens {s}`, returning the tokens the user separated with COMMAS only (`regexp -all -inline {[^,]+}` then `string trim`), with `<>`→`[]` applied to each. Precedent to imitate: `addlabel::expand_names` itself — pure Tcl, no Tk, headless-testable, documented with its rules in the comment above it, rows in section A of `tests/headless/test_add_wire_label.tcl`. Do NOT extend `expand_names` in place: 14 existing rows pin its current contract and its whitespace-and-comma equivalence is load-bearing for the multi-label queue.

3. RENDERING needs no new engine. `draw_string()` already stacks on `'\n'`. The question is only how the newline reaches `@lab`, and there are two candidate shapes, both display-only:
   (a) a second symbol, e.g. `lab_pin_vjust.sym`, identical to `lab_pin.sym` but whose text object is a `tcleval(...)`-wrapped expression that rewrites the commas of `@lab` to newlines. Precedent: `tcl_hook2()` in src/token.c already routes any value whose text starts with `tcleval(` through Tcl, and `get_tok_value(…, 0)` calls it — that is the sanctioned display-time hook. `place_wire_label` would pick the symbol name by the flag instead of hardcoding `lab_pin.sym`.
   (b) an extra instance attribute (e.g. `vjust=1`) written next to `lab=`, read in `draw_symbol()` where `txtptr` is built, turning `,`→`\n` in the substituted string only. Precedent: `translate3(txtptr, 0, xctx->inst[n].prop_ptr, …)` is already called there, so the instance property string is already in hand at that exact site.
   (a) is the cheaper and safer one: it changes no C, keeps `lab=` untouched, and puts the whole feature behind a symbol choice. Whichever is chosen, the split must be `,`→`\n` one-for-one — never `\n\n`, never a trailing `\n` — or the user's "no blank lines" rule breaks.

4. `addlabel::name_ok` MUST be extended, or the feature cannot arm at all. Measured: `name_ok {bg_trim[3:0],en_fast,iref_trim[2:0]}` = **0**, and `name_ok {bg_trim[3:0],en_fast}` = **0**. Its regex is `^[^][{}<>;:]+(\[[0-9]+(:[0-9]+)?\])?$` — the base class excludes `[`, `]` and `:`, so at most ONE bracketed suffix is allowed and anything after it is rejected. (`name_ok {a,b}` = 1, because a comma is legal in the base — so it fails only for the bracketed multi-token case, which is precisely the user's example.) Fix by validating PER TOKEN: split with the new helper and require every token to satisfy today's `name_ok`. That keeps one definition of a valid name.

5. RED-first rows, all in `tests/headless/test_add_wire_label.tcl` (already registered, see fence):
   - section A, pure Tcl: `split_display_tokens {bg_trim<3:0>,en_fast,iref_trim<2:0>}` → 3 tokens, square-bracketed; whitespace inside a token preserved or trimmed per the decision; `a,,b` → 2; and a row asserting the joined-with-`\n` display string has **exactly 2** newline characters and no `\n\n` (that is the row that fences the user's "no blank lines" rule mechanically).
   - a storage row: place with vjust ON, then `xschem getprop instance <i> lab` must equal `bg_trim[3:0],en_fast,iref_trim[2:0]` — square, comma-separated, no newline.
   - a netlist-spelling row that needs no new suite because `xschem expandlabel` is headless: `[lindex [xschem expandlabel {bg_trim[3:0],en_fast,iref_trim[2:0]}] 1]` == `8`, AND a companion row asserting the angle form gives `1`/`3` — i.e. a row that FAILS if anyone ever "fixes" the form to store what the user typed. That pair is the fence over the whole premise of this feature.
   - a `name_ok` row on the full comma list, currently 0, which is your red.
   Name each row after its METHOD and put the failure's cause in the name, per the repo convention (e.g. "vjust display string has one newline per comma, never two").

### Blockers

TWO hard blockers, both in the existing form, both of which the obvious implementation walks straight into.

**BLOCKER 1 — today the comma is a SEPARATOR, so the user's example currently places THREE labels, not one.** Measured: `addlabel::expand_names {bg_trim<3:0>,en_fast,iref_trim<2:0>} 0` → `llength 3`. The queue machinery then places them one at a time: `addlabel::start_pass` sets `pending`, `addlabel::arm` arms `[lindex $pending 0]`, `addlabel::after_drop` advances. The feature as the user defined it needs the SAME typed text to become ONE label whose `lab=` is the whole comma list — even with vjust OFF, where it renders on one line. So vjust is not a display-only flag in the form's own logic: **it changes the TOKENISATION, from "these are N labels" to "this is one label with N lines".** That forces the implementer to branch at `addlabel::start_pass`, not merely at draw time. It does NOT weaken the driver's lean about the stored value — `lab=` is still comma-separated with the rendering separate — but it does mean "vjust is purely a display concern" is false at the form level.

**BLOCKER 2 — `addlabel::name_ok` refuses the comma list, so no preview ever arms.** Measured `name_ok {bg_trim[3:0],en_fast,iref_trim[2:0]}` = 0 and `name_ok {bg_trim[3:0],en_fast}` = 0. `addlabel::arm` does `if {![addlabel::name_ok $current]} { set armed 0; … status_error }`, so with vjust ON and nothing else changed the user gets a red status line and can never drop the label. This must be fixed in the same change or the feature is dead on arrival.

A third thing that is not a blocker but forces a decision: **whitespace and commas are indistinguishable after `expand_names`** (`[^,\s]+` discards both). With vjust ON, is `bg_trim<3:0> en_fast` (spaces) one stacked label or two separate labels? The current data structure cannot answer, which is the mechanical reason a NEW helper is needed rather than a flag on the old one. My recommendation is that vjust splits on commas only and leaves whitespace as part of a token, but that is a user-visible answer and belongs to whoever files the ruling.

No blocker on the storage side: the comma form already netlists, already highlights, and already round-trips through save/load. Nothing in the engine needs changing for it.

### The fence

`tests/headless/test_add_wire_label.tcl`.

- EXISTS: yes. 196 checks, green at HEAD (`1f42914d`).
- REGISTERED: **yes**, in `hcases` of `tests/run_regression.tcl` as `"headless/test_add_wire_label"` (one entry; `dcases` has zero). So it gates commits already, and adding rows to it needs no new registration and costs no new case and no new `skip:`.
- BANNER SENTINEL: **yes**, correct. Its epilogue is `if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } else { … puts "OVERALL: notok"; exit 1 }`. The bare `OVERALL: ok` matches `banner_complete`'s `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$` in `tests/banner_rule.tcl`. **This suite does NOT have the `wvbs_finish` defect** — no risk of the `809c03d1`-style red where all a suite's own checks pass but `banner_complete` never fires.
- Verified green with the armed spelling, `timeout 240 tests/headless/run_suites.sh --nogui test_add_wire_label`:
      test home: throwaway /tmp/xschem-test-home.1087125.7Q0xHV (your HOME is untouched; …)
      display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
      PASS     | test_add_wire_label          run 1/1  RESULT: ALL PASS (196 checks)
      RESULT: 1/1 runs passed
- Section A of that file is pure-Tcl `expand_names` rows with no Tk, so the new tokeniser's rows and the `name_ok` row drop straight in. The netlist-spelling rows also fit there because `xschem expandlabel` needs no display and no simulator.
- Its header already states the red-first contract ("Every assertion FAILS before the implementation … -> RED, and passes after"), which is the discipline the pinned red-first memory requires.

Nothing about this angle needs a display arm or a new suite.

### Traps

1. ⚠ **THE BIGGEST ONE: `<>` in `lab=` is not a bus range, and getting it wrong is SILENT.** `bg_trim<3:0>` is a single scalar net whose name contains `<3:0>`; the netlister cycles the short list over the wide pin and emits a plausible-looking deck with the wrong connectivity. Zero stderr output, zero yyerror, zero dialog — I counted the `yyerror` lines and all 14 came from the newline case, none from this one. An implementer who "preserves the user's text" to satisfy the display requirement ships exactly this. Anyone eyeballing the netlist sees eight net names and moves on.

2. **A CONTRADICTION BETWEEN THE BRIEF AND THE CODE, and the code wins.** The brief says the user "typed `bg_trim<3:0>` with ANGLE brackets and expects to SEE angle brackets", and warns that reusing `expand_names` "would silently rewrite the user's text". Read the other way: the form ALREADY rewrites it, and always has. `expand_names` is the only path to `::label_new_name` (`start_pass` → `pending` → `current` → `arm`), so a label typed today as `bg_trim<3:0>` is placed as `lab=bg_trim[3:0]` and DRAWN as `bg_trim[3:0]`. There is no existing behaviour of showing angle brackets to preserve. Preserving them for display would be NEW, would make the drawn text differ from the netlisted name, and cannot be done in `lab=` at all. If the user genuinely wants to see `<>`, the existing supported answer is the `bus_replacement_char` preference ("Enter two characters to replace default bus [] delimiters", src/xschem.tcl) — which I measured turning the SAME stored `lab=…[3:0]…` into `bg_trim<3>…` in the deck. That is a user-visible product question, not an engineering one; it wants a ruling, and it should not be decided by an implementer reaching for `string map` in a draw routine.

3. **The spec file contradicts the user's definition of the checkbox, twice.** `doc/claude/specs/add_wire_label.md` says "**Vertically justified** — reserved, disabled. (**Will later rotate/vcenter the label text**.)" and the namespace comment in src/xschem.tcl says the two reserved boxes "are reserved (inert) for later". The spec sentence is exactly the rotate/vcenter reading the driver already proposed and withdrew. Update that line in the same commit or the next reader re-derives the wrong feature from the spec.

4. **A raw newline in a property value is silently truncated, not rejected.** `SPACE(c)` in src/token.c includes `'\n'`, so `get_tok_value` ends the value there: measured `lab=` came back as `bg_trim[3:0]` with tokens 2 and 3 gone, and they linger in `prop_ptr` as stray bare tokens. Storing a newline requires double quotes (`lab="a\nb"`), which DOES round-trip through `xschem saveas`/load — so the wrong design is easy to build, easy to save, and only fails at netlist time. Note the asymmetry: `save_ascii_string` escapes `\`, `{`, `}` and NOT `\n`, so the file format is happy while the reader is not.

5. **`;` is also whitespace to `get_tok_value`** (`SPACE(c)` includes `';'`). If anyone ever proposes a different in-value separator, a semicolon is not it.

6. `expandlabel()` returns a **shared static buffer** (`dest_string.str`). src/flyline.c's comment spells it out: "expandlabel returns a shared buffer -- strdup each result before the next call clobbers it". Any new C reader must `my_strdup` immediately.

7. `expandlabel()`'s fast path is `if(!strpbrk(s, "*,.:") || s[0] == '$')`. A label with `<>` but no `:` — `a<3>` — takes the fast path and is never parsed at all. So the angle-bracket failure mode differs between `a<3>` (fast path, one net) and `a<3:0>` (parsed, still one net): same wrong answer by two different routes, which makes it harder to spot in a debugger.

8. `expandlabel()` applies `bus_char` substitution **only when `xctx->netlist_type == CAD_SPICE_NETLIST`**, yet `spectre_netlist.c`, `tedax_netlist.c` and `spice_netlist.c` all set `bus_char` from the same `bus_replacement_char` variable. Someone measuring the `<>` preference against Spectre or tEDAx may get a different answer than my SPICE measurement. I did not measure those; do not assume.

9. **Do not key a row on the ABSENCE of the malformed output** (the CLAUDE.md warning about symptom-keyed fences). "the netlist contains no `bg_trim<3:0>`" stops fencing anything the moment the display path changes. Assert the correct shape: mult == 8, and the eight expected names in order.

10. My probe used `xschem saveas` — and it went to my scratch directory. That is the mechanism that gutted `nand2.sch` for the earlier crew: `saveas` needs a destination and takes the loaded file's path if you do not give it one. `xschem_library/examples/nand2.sch` is intact at HEAD (35 lines of `N`/`C` records present); I checked.

### `git status --short` on finishing

?? .xschem/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/

(Identical to the session-start snapshot — both entries pre-existed. No tracked file touched, no commit, no write into the repo. Everything I created lives under /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/a3/ : probes p1-p6.tcl, their .out/.stdout, lib/{bus8.sym,bus8.sch,top_sq.sch,top_ang.sch,top_nlq.sch,top_nlraw.sch} and out/*.spice + the two saveas round-trips. The one suite I ran, tests/headless/run_suites.sh --nogui test_add_wire_label, used its own throwaway HOME.)
