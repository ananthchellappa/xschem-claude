# Decisions — issue 1607 batch

## E1 — the driver's prediction for Stage A, registered BEFORE the measurement

Recorded at `cff55068`, before the Stage A crew reported, so that the crew's valgrind run
tests this rather than confirming it. If the measurement refutes it, the refutation stands
and this entry stays as written.

**Prediction: `svgdraw.c` has the same call shape and not the defect.** The reasoning is a
structural difference between the two back ends, not an absence of evidence:

* **PostScript colour is sticky graphics state.** `set_ps_colors()` emits an `RGB`
  operator that persists until the next one, so `ps_draw_symbol()` has to *restore* the
  layer colour after drawing text in a different one. Five sites do:
  `psprint.c:1946`, `:1980`, `:2013`, `:2030`, `:2064`. Three of them pass `c`, and in the
  pseudo-layer pass `c == cadlayers`. **That restore is the defect** — it is the only place
  that asks for the colour of an index that is not a layer.
* **SVG colour is per element.** `svg_draw_string_line()` writes `#rrggbb` into the element
  it is about to emit. There is no sticky state, so there is nothing to restore, and
  `svgdraw.c` has **no** analog of those five sites — `/usr/bin/grep -n '!= c)' src/svgdraw.c`
  returns nothing.
* **Every read is dominated by a range clamp.** The four callers that reach
  `svg_colors[layer]` pass a value clamped immediately above them:
  `svgdraw.c:947` (`textlayer`), `:1007` (`plw`), `:1048` (the annotation overlay) and
  `:1356` (schematic-own text), each of the form
  `if(x < 0 || x >= cadlayers) x = <a real layer>`.
* **The pseudo-layer pass never even reaches the geometry.** `svg_draw_symbol()` opens with
  `if(layer == cadlayers) goto draw_texts;` at `:823`, and in that pass `c == layer`, so
  `c_for_text` takes `TEXTLAYER` or `TEXTWIRELAYER` — both real layers — rather than `c`.

**Why this matters more than a patch.** Adding `if(layer >= cadlayers) return;` to
`svg_draw_string_line()` would be cheap, harmless and would leave the question unanswered
forever: the issue would close on a guard nobody could show had ever fired. A proof that
the path is safe is the better artefact, and it is falsifiable — valgrind either reports a
read past the `svg_colors` block or it does not.

⚠ **What would refute it.** Any invalid read attributable to `svgdraw.c`; any call path
reaching an unguarded read with the index at `cadlayers`; or a clamp that is textually
present but does not dominate the read (e.g. sits in a branch the pseudo-layer pass skips).

## E2 — the guard the port chose is the THIRD answer, and it stays

`set_ps_colors()` returning early means the pseudo-layer gets **no colour emitted at all**,
rather than a zeroed palette entry or the last real layer's. Issue 1607 listed the other
two and not this one, and issue 1353's comment block in `src/psprint.c` records why it is
defensible: every drawing site sets its own colour before drawing, so the restore is
redundant for correctness, measured render-identical on 313 of 314 sheets.

Stage B tests that claim on the **display** arm, which nobody has done. The decision is
kept unless that raster comparison finds a page where suppressing the restore changes what
is drawn.

## E2b — a correction to receipt C, made by the driver on re-checking

Receipt C says `tests/headless/test_nh_export_custom_color.tcl` "self-skips without Tk/X …
and note that uppercase `SKIP:` is the exact shape run_regression's `summarize_all` does
**not** collect". Two things are wrong with that, and the true finding is larger.

* Its skip is `puts "RESULT: SKIP (needs Tk/X; custom-color resolution needs X)"`, which is a
  **`RESULT:` line**. Since issue 1487 each case's last `RESULT:` line is published into the
  verdict, so if this suite ran it would be visible — just not counted in `skips=`.
* It does not run. **`/usr/bin/grep -n nh_export_custom_color tests/run_regression.tcl`
  returns nothing**: the suite is in neither `hcases` nor `dcases`. It is the only place in
  the tree asserting the content of a `print ps` / `print svg` file, and the gate never
  executes it.

So the real statement is *an unregistered suite*, not an invisible skip. Recorded here rather
than acted on: registering it would change `cases=`/`blocks=` and, per its own guard, add a
skip on the headless arm — a scope decision that belongs to whoever owns the custom-colour
feature (issue 0044), not to this batch. Named so the next person does not rediscover it.

## E3 — item 3 is scoped to what is not already asserted

`test_ps_valid_1350.tcl` already owns the colour rows. Adding a row that re-asserts
in-gamut colour would grow the suite without growing coverage. The two gaps are
**determinism across runs** (the property the issue is named for, asserted nowhere) and
**the SVG path** (no coverage anywhere). Rows go in the suite that already owns this code
rather than a new file, unless the SVG half needs its own fixtures — Stage C decides that
on evidence.
