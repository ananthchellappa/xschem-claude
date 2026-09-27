# C4 — the one output delta, closed; and the guard that took two rows' sabotage away

Stage C4. **One line of product change**, in `svg_draw_string_line()`: `svg_font_family[0] &&` on
the per-text `style="font-family:"` emission. With it the whole 1608 change is **output-neutral** —
byte-identical to `91bb1bd7` for every `font=` / `svg_font_name` value containing no `%`.

Three things I did **not** find where the brief said to look, all three reported below because each
one would have shipped as a false sentence:

1. **The threshold and pre-fix behaviour are EXACTLY as the earlier crew reported.** ≤79 emitted
   verbatim, ≥80 no attribute at `91bb1bd7`, `style="font-family:;"` after the fix. §1.
2. **`src/util.c`'s account of (D)'s threshold is REFUTED.** It said "a `font=` value of exactly 80
   characters"; a plain 80-character value emits **no attribute at all**. The one-byte-past store
   needs an **80-character literal run before the first conversion spec**. §2.
3. **The guard silently disarmed rows `F4` and `F4b`.** Their sabotage observable *was* the empty
   attribute. Driven: with only a real site reverted, `RESULT: 3 FAILED (31 passed)` and **F4
   GREEN**. Both fixtures repaired and re-driven. §5.

`tests/headless/test_snprintf_fmt_1608.tcl`: **34 → 37 checks**, `RESULT: ALL PASS (37 checks)` on
all three arms, **zero `skip:` lines** on all three. Object level: **exactly one** translation unit
changed, `svgdraw.o`; `util.o` is byte-identical.

---

## 1. THE THRESHOLD TABLE — BOTH DOORS, BOTH BINARIES, FIVE LENGTHS

**Instrument.** `probe.sh` in the session scratchpad. Per length N and door: a fixture carrying a
`font=` value of N literal `Q` characters (no `%`), then
`xschem load; xschem zoom_full; xschem print svg`, run as
`env -u DISPLAY HOME=<scratch> timeout 60 <binary> --nogui --pipe -q --script <file>`, and
`/usr/bin/grep -o 'style="font-family:[^"]*"'` over the emitted `.svg`. `zoom_full` is trap T1 of the
suite: without it no `<text>` element is emitted at all.

* **door `sch`** = `svg_draw()`'s `textfont` — a `.sch` whose only content is one text object
  carrying the value; **no instance**, so `svg_draw_symbol()` never runs.
* **door `sym`** = `svg_draw_symbol()`'s `textfont` — a `.sym` text carrying the value, instantiated
  in a `.sch` **with no text of its own**, so the emission can only have come from the symbol pass.

**BEFORE** = from-scratch build of `91bb1bd7` (`git clone --no-local --depth 1` of this repo at
HEAD → `./configure` → `make -C src`, exit 0). **AFTER0** = the working tree as I inherited it.
**FINAL** = the working tree with the guard.

| `font=` len | door | BEFORE (91bb1bd7) | AFTER0 (fix as landed) | FINAL (fix + guard) |
|---|---|---|---|---|
| 78 | sch | `style="font-family:<78×Q>;"` | `style="font-family:<78×Q>;"` | `style="font-family:<78×Q>;"` |
| 78 | sym | `style="font-family:<78×Q>;"` | `style="font-family:<78×Q>;"` | `style="font-family:<78×Q>;"` |
| 79 | sch | `style="font-family:<79×Q>;"` | `style="font-family:<79×Q>;"` | `style="font-family:<79×Q>;"` |
| 79 | sym | `style="font-family:<79×Q>;"` | `style="font-family:<79×Q>;"` | `style="font-family:<79×Q>;"` |
| 80 | sch | **(no attribute)** | `style="font-family:;"` | **(no attribute)** |
| 80 | sym | **(no attribute)** | `style="font-family:;"` | **(no attribute)** |
| 81 | sch | **(no attribute)** | `style="font-family:;"` | **(no attribute)** |
| 81 | sym | **(no attribute)** | `style="font-family:;"` | **(no attribute)** |
| 2000 | sch | **(no attribute)** | `style="font-family:;"` | **(no attribute)** |
| 2000 | sym | **(no attribute)** | `style="font-family:;"` | **(no attribute)** |

`rc=0`, `SVG-OK`, one `<text>` element and `text {font-family: Sans-Serif;}` in the embedded CSS in
every one of the thirty runs. Verbatim FINAL rows (the BEFORE and AFTER0 blocks are the same shape):

```
FINAL door=sch n=79   rc=0 svgok=1 text_elems=1 per_text_attrs=1 emitted_len=79   attrs=[style="font-family:Q{xN};"|] css=[text {font-family: Sans-Serif;}]
FINAL door=sym n=79   rc=0 svgok=1 text_elems=1 per_text_attrs=1 emitted_len=79   attrs=[style="font-family:Q{xN};"|] css=[text {font-family: Sans-Serif;}]
FINAL door=sch n=80   rc=0 svgok=1 text_elems=1 per_text_attrs=0 emitted_len=NONE attrs=[] css=[text {font-family: Sans-Serif;}]
FINAL door=sym n=80   rc=0 svgok=1 text_elems=1 per_text_attrs=0 emitted_len=NONE attrs=[] css=[text {font-family: Sans-Serif;}]
FINAL door=sch n=2000 rc=0 svgok=1 text_elems=1 per_text_attrs=0 emitted_len=NONE attrs=[] css=[text {font-family: Sans-Serif;}]
FINAL door=sym n=2000 rc=0 svgok=1 text_elems=1 per_text_attrs=0 emitted_len=NONE attrs=[] css=[text {font-family: Sans-Serif;}]
```

**AND THE STRONGER STATEMENT: the whole exported file is identical, not just the attribute.**
`md5sum` of the ten `.svg` files from BEFORE and from FINAL:

```
$ diff b2.md5 f2.md5 && echo "ALL TEN BYTE-IDENTICAL (final binary)"
ALL TEN BYTE-IDENTICAL (final binary)
```

**So the reported delta is confirmed, exactly, at the reported threshold.** The threshold is
`80 == S(svg_font_family)`: the `%s` arm needs `n + strlen(value) + 1 <= size`, so 79 is the longest
that fits.

**WHY `91bb1bd7` emitted nothing**, because the mechanism is what makes the guard the right cure
rather than a coincidence: with no conversion in the format, `my_snprintf`'s **tail copy**
`if(!overflow && n+l+1 <= size)` is the only writer on the path, and it **skips a run that does not
fit** — leaving `svg_font_family` holding the `svg_font_name` it had been pre-loaded with two lines
earlier, so the `strcmp` matched and no attribute was written. After the `"%s"` fix the value goes
through the `%s` arm, which writes `string[n+l] = '\0'` for the empty prefix **first** and only then
finds the value too long, so the array comes back **empty** and the `strcmp` differs.

---

## 2. ⚠ `src/util.c`'s ACCOUNT OF (D)'s THRESHOLD IS REFUTED — AND CORRECTED

`MY_SNPRINTF_PREFIX_GUARD` said, of the one-byte-past store:

> Driven at 91bb1bd7: svgdraw.c's svg_font_family is char[80], and a text object's `font=` value of
> **exactly 80 characters** emitted an 80-character font-family, i.e. its NUL landed at index 80,
> outside the array. rc 0, no signal, no message.

**A plain 80-character `font=` value emits no font-family attribute at all** — §1, measured. The
store `string[n+l] = '\0'` exists **only in the four conversion arms**, so what reaches it is
`l = fmt - prev == size`: the **literal run before the first conversion spec** being exactly 80
characters. Driven on the same from-scratch `91bb1bd7` build, `font=<N×Q>%d`:

| `font=` value | total length | BEFORE: emitted font-family | FINAL |
|---|---|---|---|
| `<78×Q>%d` | 80 | 78 characters | (no attribute) |
| `<79×Q>%d` | 81 | 79 characters | (no attribute) |
| `<80×Q>%d` | 82 | **80 characters — NUL at index 80, one past `char[80]`, rc 0, silent** | (no attribute) |
| `<81×Q>%d` | 83 | (no attribute) | (no attribute) |

Verbatim:

```
BEFORE prefixQ=80 value='<80xQ>%d' (len 82) rc=0 emitted_len=80 squashed=[style="font-family:Q{xN};"]
AFTER0 prefixQ=80 value='<80xQ>%d' (len 82) rc=0 emitted_len=0  squashed=[style="font-family:;"]
BEFORE prefixQ=81 value='<81xQ>%d' (len 83) rc=0 emitted_len=NONE squashed=[]
```

The comment now names the **run**, not the length of the value, and says in as many words that the
earlier sentence is refuted and how. The defect it describes is real and the fix (`>=`) is right;
only the input that reaches it was wrong. **This is exactly the class L9's second clause exists for**
— a figure the instrument does not reproduce — and it was inside the paragraph that fixes the very
off-by-one it mis-describes.

`<81×Q>%d` emitting nothing pre-fix is its own small confirmation of the mechanism: at `n+l = 81` the
old guard `n+l > size` **did** trip, the prefix write was skipped, `svg_font_family` kept its
pre-loaded `svg_font_name` and the `strcmp` matched.

---

## 3. WHERE THE CHANGE WENT, AND EVERY EMISSION POINT I FOUND

`svg_font_family` is `static char[80]` in `src/svgdraw.c`. Census of every reference
(`/usr/bin/grep -n 'svg_font_family' src/svgdraw.c`, plus `/usr/bin/grep -rn` over `src/` for the
name — it appears nowhere else):

| kind | function | note |
|---|---|---|
| **READ / EMIT** | `svg_draw_string_line()` | `if(strcmp(svg_font_family, tclgetvar("svg_font_name"))) fprintf(fd, "style=\"font-family:%s;\" ", …)` — **the only reader in the file. This is where the guard went.** |
| write | `svg_draw_symbol()` | `svg_font_name` pre-load — a 1608 site |
| write | `svg_draw_symbol()` | `textfont` (symbol text `font=`) — a 1608 site |
| write | `svg_draw_symbol()` pin-name pass | `name_font` of a `PINLAYER` rect, else `svg_font_name`. **Already `"%s"` at `91bb1bd7`; NOT a 1608 site.** See §4 |
| write | `svg_draw_annot_overlay()` | `ANNOT_OVERLAY_FONT`, a compile-time constant |
| write | `svg_draw()` | `svg_font_name` pre-load — a 1608 site |
| write | `svg_draw()` | `textfont` (schematic text `font=`) — a 1608 site |

**There is exactly ONE emission point for the per-text attribute**, so `svg_draw` and
`svg_draw_symbol` cannot disagree and there was nothing to make consistent between them — both doors
go through `svg_draw_string_line()`, which is why the table in §1 is identical column-for-column at
`sch` and `sym`. `old_svg_draw_string()` (the vector-font path, used when `text_svg` is false) emits
no `<text>` element and therefore no family at all.

**THE EMBEDDED CSS `<style>` RULE IS A SECOND, SEPARATE EMISSION POINT AND I DID NOT TOUCH IT.**
`svg_embedded_style()` writes `fprintf(fd, "text {font-family: %s;}\n", tclgetvar("svg_font_name"))`
— straight from the Tcl variable, **not** through `svg_font_family` and not through `my_snprintf`.
It cannot carry a truncated or empty value (it is the variable itself), so the guard does not apply
to it, and it is the companion assertion `F4`/`F4b` use to prove the variable really was set. It
does share limit `L5`: the value is unescaped there too.

The guard itself:

```c
  if(svg_font_family[0] && strcmp(svg_font_family, tclgetvar("svg_font_name")))
    fprintf(fd, "style=\"font-family:%s;\" ", svg_font_family);
```

**Not in `my_snprintf`**, per the brief: ~720 callers share it (P1's own census counts 720) and it
must not grow SVG-specific behaviour. `my_snprintf` returning 0 with an empty result is the
"did not fit" signal; the decision about what that means for an SVG document belongs in the SVG
back end. A 30-line comment at the guard records the measurement, the mechanism, the pin-name
exception and the `F4`/`F4b` consequence; the declaration comment now points at it.

---

## 4. ⚠ ONE SITE WHERE THE GUARD IS **NOT** THE PRE-FIX OUTPUT, DELIBERATELY

`svg_draw_symbol()`'s **pin-name pass** takes `svg_font_family` from a `PINLAYER` rect's `name_font`
token, and it **already used the `"%s"` form at `91bb1bd7`** — it is not one of the four sites 1608
changed. It also has **no pre-load of `svg_font_name` before it**, so the pre-fix "buffer keeps its
previous content" fallback that makes §1 neutral does not apply there: an over-long `name_font`
produced an **empty** family on **both** trees.

Driven, with a symbol carrying
`B 5 -22.5 -2.5 -17.5 2.5 {name=PA dir=in show_pinname=true name_font=<N×Q>}` instantiated in a
`.sch` with no text of its own:

```
BEFORE name_font=79xQ rc=0 svgok=1 text_elems=1 per_text_attrs=1 attrs=[style="font-family:Q{xN};"|]
AFTER0 name_font=79xQ rc=0 svgok=1 text_elems=1 per_text_attrs=1 attrs=[style="font-family:Q{xN};"|]
BEFORE name_font=80xQ rc=0 svgok=1 text_elems=1 per_text_attrs=1 attrs=[style="font-family:;"|]
AFTER0 name_font=80xQ rc=0 svgok=1 text_elems=1 per_text_attrs=1 attrs=[style="font-family:;"|]
FINAL  name_font=79xQ rc=0                      per_text_attrs=1 attrs=[style="font-family:Q{xN};"|]
FINAL  name_font=80xQ rc=0                      per_text_attrs=0 attrs=[]
```

So **the pre-fix tree emits the invalid `font-family:;` too**, at a site this issue never touched,
and the guard suppresses it. That is a deliberate improvement on the pre-fix output rather than a
match to it, and it is the reason the neutrality claim is worded as *"for every value containing no
`%`, at the sites 1608 changed"* and not *"byte-identical for every input"*. It is named in the
guard's comment, in the suite above `F10`, and in the issue file's Correction 9. **I did not add a
row for it**: the fixture needs a pin rect and the observable is the same guard `F10`/`F10b` already
fence, so a fourth row would fence nothing new — but the shape is written down, with the `B 5 …`
fixture, so anyone can re-drive it.

---

## 5. ⚠ THE GUARD DISARMED `F4` AND `F4b`, AND ONLY NON-BEHAVIOURAL ROWS NOTICED

This is the finding I would most want the driver to read. `F4` and `F4b` assert an **absence**: zero
per-text `style="font-family:"` attributes. Their sabotage observable — what made the absence
non-vacuous — was that reverting the site left `svg_font_family` **empty**, so
`style="font-family:;"` appeared. **The guard suppresses an empty family, so the refusal now
produces no attribute either, and the absence stopped distinguishing anything.**

Driven: guard in place, **only** `svg_draw()`'s `svg_font_name` site reverted to
`my_snprintf(svg_font_family, S(svg_font_family), tclgetvar("svg_font_name"))`, `make -C src`, armed
run:

```
FAIL     | test_snprintf_fmt_1608       run 1/1  RESULT: 3 FAILED (31 passed)
```

with **`F4` GREEN** and the three reds `W1`, `P1` and `X1` — the compiler's `-Wformat` opinion, the
`gcc -E` census and the citation checker, **not one of which runs the binary**. That is precisely the
gap `F4b` was invented to close (C2's receipt: "reverting that site reddened only W1 and P1"),
reopened one level down.

**THE CURE IS IN THE FIXTURE, NOT THE ASSERTION.** Both rows now set `svg_font_name` to
`Zz%-2000d` instead of `%-2000d`. On a correct binary the `"%s"` form round-trips the whole string
and it matches the variable, so the absence still holds. With the site reverted, `my_snprintf` writes
the literal prefix `Zz` and **then** refuses the spec — that ordering is `G9`'s subject — so the
family is `Zz`, which is **non-empty** and differs, and `style="font-family:Zz;"` appears. The prefix
also removes a second-order flake: nothing pushes a vararg at these doors, and with `Zz%-2000d` the
refusal happens before `sprintf()` is reached, so the garbage `int` is never read (trap T4's class).

Re-driven, same two sabotages, repaired fixtures:

```
# svg_draw()'s svg_font_name site reverted
FAIL     | test_snprintf_fmt_1608       run 1/1  RESULT: 3 FAILED (34 passed)
FAIL: F4   … (rc=0 death=0 per_text_attrs=1 want=0 text_elements=1 css={{text {font-family: Zz%-2000d;}}})
FAIL: P1
FAIL: W1

# svg_draw_symbol()'s svg_font_name site reverted
FAIL     | test_snprintf_fmt_1608       run 1/1  RESULT: 3 FAILED (34 passed)
FAIL: F4b  … (rc=0 death=0 per_text_attrs=1 want=0 text_elements=1 css={{text {font-family: Zz%-2000d;}}})
FAIL: P1
FAIL: W1
```

Both behavioural rows redden again. The comment above `F4` records the whole episode, including the
green-on-reverted measurement, so the next crew that changes the emission knows these two rows'
observable depends on it.

**GENERAL LESSON, carried forward rather than fixed:** a row whose observable is *the absence of a
malformed output* is disarmed by any later change that stops emitting that malformed output. Two of
the six section-F rows were of that shape. Nothing in the suite detects the condition automatically;
the only instrument that caught it was re-running the site-by-site sabotage after an unrelated
change, which is what this stage did.

---

## 6. THE NEW ROWS, AND THE TWO SABOTAGES

**`F10`** — a `.sch` text object whose `font=` value is **2000** characters, no `%`: text present,
**zero** per-text `style="font-family:"`. `svg_draw()`'s door.
**`F10b`** — the same value through `svg_draw_symbol()`'s door (a `.sym` text carrying it,
instantiated in a `.sch` with no text of its own). The two doors share one reader, so this row does
not fence a second guard; it fences the claim that the threshold and the absence are the same at
both, which is what makes §1's byte-identity claim cover a stranger's **symbol library** and not
only their schematic.
**`F11`** — the **boundary control**: a `font=` value of **79** characters still reaches the exported
font-family **verbatim, all 79 of them**.

**LENGTHS CHOSEN SO A BUFFER RESIZE READS CORRECTLY**, which is the one design decision here:
`F10`/`F10b` use 2000, far over any plausible size, so **enlarging** `svg_font_family` cannot redden
them; `F11` uses 79, which *is* `S(svg_font_family) - 1` at this commit, so **shrinking** the buffer
reddens `F11` and its detail prints the length that arrived — "the boundary moved", not a mystery.

### Sabotage A — the guard removed (`svg_font_family[0] &&` deleted)

```
FAIL     | test_snprintf_fmt_1608       run 1/1  RESULT: 2 FAILED (35 passed)
         | FAIL: F10 (1608) a .sch text object whose `font=` value is 2000 characters -- far longer than svg_font_family's char[80] and containing no `%` at all -- exports with the text present and ZERO per-text `style="font-family:"` attributes, which is byte-for-byte what 91bb1bd7 did. THE GUARD IS `svg_font_family[0] &&` in svg_draw_string_line(): without it the `"%s"` fix emits `style="font-family:;"`, an invalid CSS declaration asserting an empty font name where the absent attribute correctly says nothing. This is svg_draw()'s door (rc=0 death=0 per_text_attrs=1 want=0 text_elements=1)
         | FAIL: F10b (1608) the same over-long `font=` value reached through svg_draw_symbol()'s door -- a .sym text carrying it, instantiated in a .sch with no text of its own, so the emission can only have come from the symbol pass. Same absence, same reason. The two doors share ONE reader (svg_draw_string_line), so this row does not fence a second guard; it fences the claim that the threshold and the absence are the same at both, which is what makes the byte-identity claim in the comment above cover a stranger's SYMBOL LIBRARY and not only their schematic (rc=0 death=0 per_text_attrs=1 want=0 text_elements=1)
```

Exactly the two new absence rows, `per_text_attrs=1 want=0`. `F4`/`F4b` correctly stayed green — with
the guard gone the empty family emits again, and the real sites still round-trip.

### Sabotage B — the attribute never emitted (`if(0 && …)`)

```
FAIL     | test_snprintf_fmt_1608       run 1/1  RESULT: 5 FAILED (32 passed)
         | FAIL: F11 (1608 control, the BOUNDARY one) a `font=` value of 79 characters -- one less than S(svg_font_family) at this commit -- still reaches the exported font-family VERBATIM, all 79 characters of it. This is what stops F10/F10b being satisfied by a binary that dropped the attribute for everything, and it is the assertion that pins WHERE the boundary is: 79 emitted, 80 absent. A red here with an empty family means svg_font_family was made SMALLER -- the detail prints the length that did arrive (rc=0 death=0 emitted_lengths={10} want=79 nfams=1)
```

plus `F1`, `F2`, `F3` and `F5` (`fams={Sans-Serif}` — only the embedded CSS rule survives). So the
pairing holds in both directions: **`F10`/`F10b` cannot be satisfied by a binary that dropped the
attribute always, because `F11` and `F5` redden on exactly that.** `emitted_lengths={10}` is the
`Sans-Serif` from the CSS rule, which is `svg_fams`' only remaining match.

---

## 7. ⚠ A LATENT MISS IN `X1` THAT MY OWN COMMENT TRIPPED — FIXED IN THE CHECKER, NOT THE SOURCE

Adding a comment to `svgdraw.c` that names this suite's file made `X1` red on a citation **I did not
write**:

```
unknown={… {svgdraw.c: cites A36 (in "A36") -- no such row}}  other_suites=2
```

`Rows A36..A39 of tests/headless/test_annot_declutter_1244.tcl` is spelled with `..`, which is not in
`xIDL`'s separator set, so the id list stopped at `A36`; the text after the match was
`..A39 of tests/…`, so **attribution rule 1 never fired**, and rule 3 handed `A36` to the nearest
**preceding** `*.tcl` name in the file. That used to be `test_ps_valid_1350.tcl` (line ~493) and was
therefore counted in `other_suites`; my new comment (line ~553) became nearer, and the citation
landed on us. `L7` names "RULE 3 MISATTRIBUTION" as a known heuristic failure — this is it, live.

**Fixed in the checker**, not in the source: `..` is now a separator in `xIDL`, so rule 1 sees the
`of <path>.tcl` and attributes the whole range correctly. `xids()` then yields `A36` and `A39`
separately (it makes a range only out of `-`), which is the safe reading — no fabricated middle ids.

**I deliberately did NOT edit the source citation.** The declutter comment is **byte-identical in
`draw.c`, `svgdraw.c` and `psprint.c`** on purpose (its own text says the guard is byte-identical in
all three back ends); changing one copy would break that symmetry and changing all three would put
`psprint.c` in the change set for a two-character comment edit. I tried `A36-A39` in `svgdraw.c`,
saw the triplication, and reverted it. The suite records the miss and the reason at `xIDL` and in
`L7`.

---

## 8. THE THREE ARMS — VERBATIM

Armed spelling throughout (`run_suites.sh` arms the throwaway HOME). Rebuilt before each
(`make -C src`); no sabotage in the tree.

**Arm 1 — `--nogui`, `DISPLAY` unset by the driver**

```
$ tests/headless/run_suites.sh --nogui test_snprintf_fmt_1608
test home: throwaway /tmp/xschem-test-home.3062549.miBpgt (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (37 checks)
RESULT: 1/1 runs passed
```

**Arm 2 — display arm on the persistent dev display `:99`** (`devdisplay.sh status`: `display: :99`,
`state: alive`, `screen: 1920x1080x24`, `wm: openbox (Openbox)`)

```
$ tests/headless/run_suites.sh test_snprintf_fmt_1608
test home: throwaway /tmp/xschem-test-home.3063068.TNUgG0 (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (37 checks)
RESULT: 1/1 runs passed
```

**Arm 3 — no dev display reachable**, via a **read-only empty** `XSCHEM_DEVDISPLAY_DIR`
(`dr-xr-xr-x`), never `devdisplay.sh stop`:

```
$ XSCHEM_DEVDISPLAY_DIR=<scratch>/emptydd tests/headless/run_suites.sh test_snprintf_fmt_1608
test home: throwaway /tmp/xschem-test-home.3063609.1l1h46 (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: private Xvfb from :200 up, screen 1920x1080x24, wm openbox, GUI_GATE=0
             (AUDIT_DISPLAY=:0 to use the real screen, =none to skip GUI legs)
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (37 checks)
RESULT: 1/1 runs passed
```

`/usr/bin/grep -c 'skip:'` over each of the three logs: **0, 0, 0.** Same check count on all three,
so the suite still adds one case and no skip to T1.

---

## 9. OBJECT LEVEL — EXACTLY ONE TRANSLATION UNIT CHANGED

`src/scheduler.c` carries `__DATE__`/`__TIME__`, so the linked binary's md5 is not an identity check.
Compared `.o` files instead. Method, and its own validity check:

1. `md5sum src/*.o | sort -k2` with my change in → **post** set (40 objects).
2. Reversed both of my source edits textually (asserted one occurrence each), `make -C src` → **pre**
   set.
3. `diff` the two lists.
4. Restored the post sources, `make -C src` again, and compared to the **post** set — if the reversal
   had been inexact this would not reproduce.

```
=== object-level diff: pre-C4 vs post-C4 ===
33c33
< 6f1fee5d884914c49bb6e3917e792767  src/svgdraw.o
---
> ae3fd903db996f0efa16e49531aefb5d  src/svgdraw.o
=== changed TUs ===
src/svgdraw.o
```

```
REBUILD REPRODUCES THE POST-C4 OBJECTS EXACTLY (40/40 md5 match) -- the reversal was faithful
```

**One TU: `svgdraw.o`.** `util.o` is **byte-identical** — my `util.c` edit is comment-only and the
build carries no `-g` — which is itself the proof that §2 changed prose and nothing else. The other
38 objects are untouched. `make` recompiled only `util.c` and `svgdraw.c`; nothing recompiled
wholesale, so no header moved.

Files changed by this stage:

| file | what |
|---|---|
| `src/svgdraw.c` | the guard + its comment; one sentence added to the declaration comment. **The only TU that changed.** |
| `src/util.c` | comment only — §2's refutation. `util.o` byte-identical. |
| `tests/headless/test_snprintf_fmt_1608.tcl` | `F10`, `F10b`, `F11`; `F4`/`F4b` fixtures and prose; `xIDL` gains `..`; header fence map, `L7` and the `F5/F9/F11` control list. |
| `tests/run_regression.tcl` | the `hcases` rationale: 34 → **37 checks** on three arms, the guard, and round three's finding. |
| `doc/claude/issues/1608-…md` | **Correction 9** (the delta, the table, the pin-name exception, the `F4`/`F4b` disarm) and one paragraph in "What the fix is". `tclsh tests/headless/issue_stamp.tcl` → `ISSUE-STAMP: ok (0 problems)`. |

Per **L9** no sentence in any of these quotes a count produced by a command over the tree's own text,
and no figure that the instrument next to it cannot reproduce. The check total (37) is printed by the
suite on every run and is stated in `run_regression.tcl` with its own warning not to gate on it.

---

## 10. WHAT I DID NOT DO, AND WHAT DIFFERED FROM THE BRIEF

* **The brief expected more than one emission point** ("there may be more than one emission point,
  and an embedded CSS `<style>` rule as well as a per-text `style=` attribute"). There is **one**
  reader of `svg_font_family`. The embedded CSS rule exists and is a genuinely separate emission
  point, but it prints `tclgetvar("svg_font_name")` **directly** — it never touches
  `svg_font_family` or `my_snprintf`, so it cannot carry a truncated value and needs no guard. §3.
* **The brief expected to "make all of them consistent"** — there was nothing to reconcile between
  `svg_draw` and `svg_draw_symbol`; they share the reader, which §1's identical `sch`/`sym` columns
  confirm behaviourally rather than by inspection alone.
* **No row for the pin-name site.** §4 names it, measures it, gives the fixture, and explains why a
  fourth row would fence nothing the guard's own rows do not.
* **The `before` build is in the session scratchpad, not at a short path.** The brief asked for a
  short path; the scratchpad is ~100 characters before the clone name. I judged that irrelevant here
  because the short-path rule exists for `test_op_annot`/`test_annot_hier_0911`, which compare a
  status-bar sentence embedding an absolute path, and **I ran no suite in the clone** — only
  `./configure`, `make -C src` and direct `xschem print svg` invocations, none of which reads a
  status-bar string. Stating it rather than leaving it implied. (The T1 run below is in the **real
  tree**, whose path is short.)
* **I did not commit.** Working tree left with the change in and no sabotage: the guard is present
  (`/usr/bin/grep -c 'svg_font_family\[0\] && strcmp' src/svgdraw.c` → 1) and `src/xschem` is built
  from it.
* **Carried forward, not fixed** (both already named in the issue): `L5`, the value is still
  unescaped in the XML attribute — the guard reduces the shapes that reach it but changes nothing
  about escaping; and `L3`, the `%s` arm still discards a field width.
* **A general weakness I am naming rather than fixing:** two of section F's rows assert *the absence
  of a malformed output*, and that shape is disarmed by any later change that stops emitting the
  malformed output (§5). Nothing detects that automatically.

---

## 11. T1 SOLO, IN THE REAL TREE — GREEN

Not asked for by the brief, run because this stage changes **exported SVG bytes** and only two suites
in `tests/` mention `font-family` at all (`test_op_annot` and this one), which is a reason to check
rather than a reason to assume. `tclsh run_regression.tcl` from `tests/`, real tree (path 92
characters, so no `test_op_annot` path-elision red), **solo**: zero
`another regression run is live in this tree` lines in the run's output, and no
`results.<pid>.log` with a live `/proc/<pid>` before launch.

```
T1-RUN-BEGIN pid=3064765 script=run_regression.tcl start=2026-09-26 21:16:07 planned_cases=100 verdict=results.3064765.log home=throwaway binary=/home/analog/dev/xschem-claude/src/xschem canonical=results.log
T1-RUN-END pid=3064765 cases=100 blocks=99 counted_failures=0 skips=8 elapsed=592s end=2026-09-26 21:25:59
```

`counted_failures=0`; every `Total num fail:` line is `0`; `skips=8`, the same eight named rows as the
standing baseline (`test_op_annot`'s five display-only groups plus `test_input_line_inject_1352`,
`test_preview_name_inject_1601` and `test_generator_paren_1604` self-skipping their Tk rows on the
headless arm) — **none of them mine**. The two relevant case blocks:

```
headless/test_snprintf_fmt_1608.log
RESULT: ALL PASS (37 checks)
Total num fail: 0
headless/test_op_annot.disp.log
RESULT: ALL PASS (493 checks)
Total num fail: 0
```

`test_op_annot` reads `font-family` off the `<text>` element (`opa_o_style`) and compares it against a
twin rendered in the same process; its family is `ANNOT_OVERLAY_FONT`, a compile-time constant that
fits, so the guard cannot reach it — confirmed rather than argued.
