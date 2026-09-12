# Stage 3 — The form stops lying

**Seven commits, not the planned one.** `4216c8b2` (issue 1413) landed first and is not a Stage 3
item at all; it is the thing without which no Stage 3 number could be trusted.

| commit | issue | subject |
|---|---|---|
| `234d1b86` | **1414** | a skipped value would have emitted an empty word and shifted every value after it |
| `5a88836a` | **1415** | one refusal reader, and the number alphabet the simulator actually reads |
| `865c2b08` | **1416** | a skipped start time let the maximum step be read as one |
| `14be0470` | **1417** | the form offered an entry for everything, and said "Points:" for both AC sweeps |
| `71e4454b` | **1418** | Options collected settings, round-tripped them, and never emitted them |
| `0d1be0fe` | **1419** | the one escape from a typed form that actually emits |
| `b32b0337` | **1420** | the Arguments column listed values the deck would never carry |

**Floors:** `test_ase_core` 289 → **348** · `test_ase_simcaps_0948` 158 → **164** ·
`test_ase_dialogs` display 236 → **265**, headless 37 unmoved · `test_ase_persist` 47 (broken) →
**148**. **Forty-four sabotages**, all verified to redden. T1 solo at zero on every commit — and
from `4216c8b2` onward that number finally includes `test_ase_core`.

---

## What the stage was for, in one sentence

`ase::ui::chana_options` collected free-text name/value pairs, round-tripped them through the state
file, rendered them in the Arguments column, and **never emitted them**. Its own header comment said
so. Measured end to end: type `uic 1`, `tstart 5u`, `tmax 1n` into a tran row, see all three
confirmed in the pane, and the deck says `tran 10n 200u`.

The fix was not to make free text emit. It was to **delete free text**: every parameter a type
genuinely has became a typed field, everything else is refused, and the one honest hatch — `x` —
actually emits.

---

## Five things the plan said that the tree refuted

Every one was found by **measuring the 104 committed benches** rather than by reading the sketch
again, and four of the five would have shipped as a defect.

1. **`@target` appears in ZERO committed rows; `source` appears in 36.** A required `@target` slot
   raises on every one of them. The field is `source`.
2. **`{tran @step @stop @tstart! @tmax! @uic?}` has `?` and `!` swapped** against the grammar C1
   shipped. `!` resolves a non-bool through `field_emits`, which returns the **default** when the
   key is absent — so a defaulted `tstart` emits `tran 1n 10u 0` for every committed row and moves
   all 104 goldens.
3. **"The literal word `temp`, else a voltage source" mislabels seven committed benches.** The
   corpus carries `I0`, `i0` and `i1`. And `Vres` is a **voltage source whose name contains `res`**,
   so the test must be the first character and never a substring.
4. **ngspice does not warn on `1M`.** Measured: `1.000000e-03` with zero warning lines. `M` is
   milli, users mean Mega, nine orders of magnitude silently — so ASE-L warns where the simulator
   will not.
5. **`grid` is not a parameter of the analysis card at all.** `interp` and `linearize` are
   `.control` commands that run before and after it; the plan's own M8 row admits two of its three
   arms are Stage 6. Deferred, so it ships measured on all three.

---

## What Stage 3 learned that binds later stages

**A test that asserts a refusal is satisfied by a door that refuses everything.** Row G2b — *an
enabled tran with a blank step is rejected* — would have stayed green through a change that made the
dialog refuse every legal transient in the tree. The converse row is not optional and has to be
written at the same time, because afterwards nobody remembers the door had two sides. The same shape
appeared twice more: **G2j** exists so a sabotage can tell "closed the door" from "broke the
editor", and **G2h** exists because G2c only ever leaves the checkbox *clear* — which a checkbutton
wired to nothing satisfies perfectly.

**Pin the claim, not the fixture.** Row Q1 asserted the whole `dc` emit template as evidence for a
statement about its *first word*, and reddened the moment `dc` legitimately gained four slots. Row
VB3's first draft pinned a whole deck against one rendered 300 lines earlier and failed on the
`write` line's raw-file path, because a later fixture moves the rundir. **A row whose expectation is
wider than its own sentence reds for reasons unrelated to its subject — and a row that reds for the
wrong reason is a row that eventually gets deleted rather than fixed.**

**A sabotage that makes the suite DIE is a weaker result than one that makes a row go red.** Two
sabotages this stage did the former: `form_get` calling `get` on a checkbutton, and
`analysis_verbatim` without its catch. Both are caught by the tree (neither prints `OVERALL: ok`),
but the only thing naming the defect is a line number. Where it is cheap, call the proc inside the
**row's own** `catch` and assert the return code; that is the difference between a defect someone
fixes and one someone bisects.

**An allow-list, not a deny-list, for anything that classifies a declared kind.** The number check
read *"parse anything that is not one of two named kinds"*, and the first field whose legal values
were words — `sweep`, with `dec`/`oct`/`lin` — came back `bad notanumber`. **A deny-list assumes
every kind nobody has thought of yet belongs to the checked class**, so the next one any adapter
invents is born broken, and born broken in the direction that refuses legal work.

**A write-back rule is a byte-identity rule.** Giving a field a richer control changes what it
answers when untouched: a checkbutton says `0` where an entry says empty, a combobox says `dec`
where a bench stores nothing. Both keys change no deck line and both break the round trip **the
first time a user opens the dialog and presses OK**. A field writes a key only when its value
differs from what the deck would have said without it.

**Positional grammars need a word for "left out".** "Skip it" and "emit nothing" are different
instructions: the second silently promotes whatever stands to the right. `whenskipped` belongs on
the **field**, because the field is the thing that knows whether it occupies a position.

**And a comment can be the defect, written down and shipped.** *"DECK emission of extra keys stays
deferred (v1 limit, documented here)"* described this stage's entire subject as a design note and
left it in place for a year.
