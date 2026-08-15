# Item 04 — phase 1d: the keypad (RULING-2) and the function browser over one catalogue

Ledger row 4; plan 1.6–1.7; spec §4 W26–W31, §7.1, §7.2, R413, RULING-2, RULING-3.
**Verdict `[E]`** — the last two placeholders are gone, every pane holds its real
controls, and all of it is still inert. **438 checks** (was 327 at phase 1b, 415
as first shipped), 22 + 20 sabotages, no suite moved. The payload is a window full
of names and operators; 438 green checks cannot judge whether it reads.

Captures: `04-phase1d.png` (as first shipped) and **`04-phase1d-fixes.png`** (after
the fix round below), both default first open, 656x680, dev display `:99`.

> **⚠ §8 IS THE FIX ROUND.** Three reviewers raised sixteen findings against the
> first cut of this item; every confirmed one is applied there, with its own
> sabotage. Read §8 before trusting a number in §1–§7 — five of them moved.

## 1. Files changed

```
 doc/claude/specs/calculator.md        |  ~90 +-
 src/calculator.tcl                    | ~470 +-
 tests/headless/test_calc_skeleton.tcl | ~430 +-
```
Plus this receipt and `04-phase1d.png`. **No rebuild** — `calculator.tcl` is sourced
at runtime (`xschem.tcl:14381`). `LEDGER.md`, `recon/`, `ref/` untouched (driver's).

## 2. What landed

- **The keypad** (W29–W31): `.calc.pad.k1..k12` — the twelve **binary operator**
  tokens `+ - * / ** ? == != > < >= <=`, four to a row — and `.calc.pad.u1..u4`
  (`user 1`..`user 4`) as a 2×2 block. No digit key, no `±`, no `.`.
- **The function browser** (W26–W28): `.calc.fn.cat` (readonly combobox, §7.1's
  eight values, initial `Special Functions`) and `.calc.fn.list`, a **canvas** of
  56 names in six column-major columns, with `.calc.fn.hsb` under it and
  `.calc.fn.vsb` beside it. Switching category repopulates.
- **The catalogue** — `calc::catalogue`, 108 six-field rows, the single source for
  the list, the greyed entries and the hover help (R413).
- `calc::placeholder` deleted with its last two callers.

## 3. Rulings taken, and why (all written into the spec, with rationale)

| ruling | evidence | written into |
|---|---|---|
| **The keypad set is the twelve binary tokens.** `±` and `.` dropped | neither is in §3.2; both belong to typing a literal, which RULING-2 hands to the keyboard. `.` is not even lexable alone — `strtod(".")` fails, so §3.1 looks it up as a **vector name** and the whole expression returns `-1`. A key survives RULING-2 because R510/R511 give a binary-operator *button* stack semantics no keystroke has; a digit has no second meaning | spec §4 W30 |
| **`.calc.fn.list` is a `canvas`** | the requirements are the signal browser's (many columns, one-cell click, per-cell greying, per-cell hover) and its enumeration applies verbatim (`wave_viewer.tcl:9429-9436`): treeview has no cell selection **and its tags are per row**, so `dft` could not be greyed without greying its five neighbours; side-by-side listboxes each own their own `xview`, so W28's one h-scrollbar could not scroll the grid; a text widget gives character-range selection | spec §4 W28 |
| **Entries render alphabetically**, `All` is synthetic, the row schema is six fields | table order is §7.2's, which is the order to *read the spec* in and the wrong one to *look a name up* in; the reference sorts the same way | spec §7.1 |
| **`calc::status` takes `record`, defaulting to 1**; hover passes 0 | help is a legend, not an event. 56 entries under a moving pointer would spend R509's whole 50-entry cap on tooltips and evict the messages the history exists for | spec R507 |
| **`.calc.pw.bot.pad -minsize` STAYS at 140** — the phase-0 look debt, settled | measured against the real buttons: `winfo reqwidth .calc.pad` = **128**, `winfo reqwidth .calc.pw.bot.pad` = **140** (the labelframe's `-padx 4` a side + border). 140 is not 25 px of slack over the reference's ~115: it is what this pane's contents ask for, to the pixel. **Lowering it to 128 was tried and clipped the keypad**: the first-open sash gave the pane 138 and `.calc.pad` rendered 126/128. A ~112 px pane is reachable by stacking the four `user N` buttons in one column, and was rejected — seven rows tall, and the four read as a list rather than as the block the reference draws. **S4's number is therefore unchanged**; what changed is that S22 now pins it to `winfo reqwidth` so it can never again be a guess | `build_panes`, S22 |
| **The five T-verbs that stand on `dft` carry route `N`** | §7.2 marks them "T (on dft)"; with `dft` absent there is no T to write, so the route the Calculator would have to build is the N one. This keeps the **table** the single source for the disabled state, which is RULING-3's requirement; each row's help still says which opcode it stands on | spec §7.2a |

### The audited catalogue defects (`recon/catalogue_defects.md`)

**Applied: D1, D2, D3, D4, D5, D6, D7.** None rejected.
- **D1** category `Special` → `Special Functions`, in the data. Had it shipped, the
  *default* category rendered empty.
- **D2** `lshift` is now a **T** route emitting nothing. The prescribed `del()`
  recipe cannot work and reads out of bounds in shipped C (`save.c:2585`-2607 →
  `ravg_store` writes `arr[i][last+1]` past a `my_calloc(last+1)`); confirming and
  filing that is item 12's, and this item deliberately does not emit the composition.
- **D3** added the `returns` field; `integ` (scalar) and `iinteg` (wave) are no
  longer byte-identical rows.
- **D4/D5/D7** are spec corrections, checked against the C: `MAX` returns the
  *greater* operand (so `max()` is a **floor**, §3.2 had it inverted); `CPH`
  unwraps by **360**; `/` with a zero divisor yields 0 only when the dividend is
  also 0 and otherwise `y[p-1]`, the previous point of the *destination* column.
- **D6** `groupDelay` emits **`cph() deriv() -360 /`**, not the spec's
  `cph() deriv()` negated — φ is in degrees and `deriv()` differentiates against
  **Hz, not ω**, so the spec's string was short of −dφ/dω by π/90. Shipping it
  verbatim would have been wrong with nothing to notice it.

## 4. Tests

`tests/headless/test_calc_skeleton.tcl` — new **S22** (keypad), **S23** (browser),
**S24** (catalogue). **415 checks, was 327.** Verbatim: `RESULT: ALL PASS (415 checks)`.

**One check RESTATED, and it lost its subject rather than changing it.** S14's two
per-pane "placeholder hint wears the muted role / panel background" checks (4 checks)
covered widgets that no longer exist: item 4 filled the last two panes, so
`calc::placeholder` is deleted. What survives is the half with teeth — *no* pane may
carry a hint, now over all five — plus a new check that the proc is gone with its
last caller. Net −3 checks from S14, +91 new. Nothing renumbered, nothing else deleted.

**Non-vacuity, measured**: with `HEAD:src/calculator.tcl` in place the suite reports
`86 FAILED (329 passed)` and **every check still runs** — no abort. Exactly 7 of the
91 new checks pass without the feature, and all 7 are named fixture preconditions or
positive controls (`S22 first open returns .calc`, `S22 reopen returns .calc`, the
three `pre-press/pre-hover/pre-click snapshot is real` controls, `S23 the greyed
colour is not the live one`, `S24 fixture: the spec's §3.2 lists 52 tokens`).
Getting there took three rounds: the first cut had **13** vacuous passes and **died
in the outer catch** feeding `ERR:invalid command name ".calc.fn.list"` — a
*four-element list* — to `expr` as a float, with S24 never run. Every "nothing bad
is present" check in the new bands now carries its own count.

## 5. Sabotage — 22 breaks, 22 reds, every one restored from a byte-exact backup

Driven by `scratchpad/sab.py`, which md5-verifies the restore after each run.

| # | broken | first red check |
|---|---|---|
| A | a row loses its `returns` field | `S24 every row is a well-formed six-field row -> {average=arity5}` |
| B | one special row back to category `Special` (D1) | `S23 the default category renders all 56 -> {55}` |
| C | the Complex category emptied | `S24 every §7.1 category has entries, in the spec's numbers -> {…2…}` |
| D | initial category not `Special Functions` | `S23 the initial category is Special Functions -> {Arithmetic}` |
| E | `N` stops meaning disabled (RULING-3) | `S24 the disabled set is the ledger's N routes…` |
| F | duplicate name in a category | `S24 no two rows share a name within a category` |
| G | `db20()` → `db20` in an insert | `S24 every emitted token is one the engine lexes -> {60 db20():db20}` |
| H | a `7` key returns to the pad (RULING-2) | `S22 no digit, decimal point or sign key -> {17 .calc.pad.k13=7}` |
| I | pad `-minsize` 140 → 100 | `S4 -minsize -> {100}` + `S22 the keypad is not squeezed -> clipped(126/128)` |
| J | hover records into the history | `S23 hovering records nothing in the history` |
| K | the list laid out row-major | `S23 the first column holds the first names…` |
| L | greyed entries painted the live colour | `S23 exactly the N-route… are greyed -> {…dft=#000000…}` |
| M | click bound to the shared tag, not the entry's | `S23 every entry carries its own click and hover binding` |
| N | a category switch does not repopulate | `S23 switching category repopulates the list` |
| O | `lshift` back to `C`/`del()` (D2) | `S24 D2: lshift is a T route and emits nothing` |
| P | `groupDelay` back to `cph() deriv() -1 *` (D6) | `S24 D6: groupDelay carries the degrees-per-Hz conversion` |
| Q | `integ`/`iinteg` identical again (D3) | `S24 D3: integ and iinteg are no longer byte-identical` |
| R | a pane keeps a placeholder hint | `S14 a filled pane keeps no placeholder hint` |
| S | the scrollregion never grows | `S23 the six columns are wider than the visible list…` |
| T | a 120-character help line | `S24 every help line is short enough for the status entry` |
| U | a disabled entry goes inert instead of explaining | `S23 clicking an N-route entry explains why…` |
| V | the keypad stops speaking (R506) | `S22 every operator key names itself and its phase` |

## 6. Audit diff, by name and status

Through `run_suites.sh` on `:99`, against `receipts/00b-audit-baseline-2026-08-14.txt`:
`test_calc_skeleton` **PASS→PASS** (415 checks, was 327), `test_wave_viewer`
**PASS→PASS** (400), `test_accelerators` **PASS→PASS**, `test_bindings_file`
**PASS→PASS**. **No suite moved in either direction.** No other suite greps
`calc::` or `calculator` (`grep -rln` over `tests/`). `full_audit.sh` is item 99's.

## 7. What was NOT verified

- **THE PIXELS.** `[E]`. Look debt recorded, **uncleared** — only the user clears one.
  Unjudged: whether six columns at the default size are *readable* (§11.4 says this
  is exactly the thing no test can answer); whether the greyed N-route names read as
  information or as breakage; whether a list that needs **both** scrollbars at first
  open (8 of 10 rows, ~4.5 of 6 columns visible) is right, or whether the browser
  should get more of the window; the keypad's ~200 px of empty pane below the user
  buttons; and `**`/`?`/`>=` as button labels.
- **The phase-0 look debt is answered, not cleared.** *"Calculator phase 0 keypad
  pane width"* is a **look** debt, and a look debt clears only when the user says so
  (`owed.sh clear look <id>`) — this item did not touch it. What it did is settle the
  engineering half with a measurement (§3, row 6) and put the judgement under a check
  instead of a guess. The new look debt asks the user to judge the same pane with the
  real buttons in it.
- **`:0`.** Everything ran on `:99`. The existing `test_calc_skeleton` suite debt
  covers it; S22/S23 add rendered-geometry legs (`winfo containing`, canvas bboxes)
  of exactly the kind WSLg's async `<Configure>` traffic can move.
- **Not sabotaged, therefore not evidence:** `S22/S23 parent is .calc` (in Tk the
  path *is* the parent — only deleting the widget reddens them) and the four fixture
  /control checks named in §4.
- **Deliberately absent:** any selection *rendering* in the function list — a click
  reports and nothing else, because insertion is phase 5 and a highlight nothing
  reads is state without a reader. Mouse-wheel scrolling on the canvas, likewise.
- **Latent, recorded not fixed:** `calc::fn_fill` rebuilds every canvas item on a
  category switch (108 items worst case) — fine at this size, and the item ids are
  the binding keys, so any future incremental update must re-bind.


---

# 8. THE FIX ROUND (post-review)

Sixteen confirmed findings from three review lenses, deduplicated to **eleven
distinct defects**. All eleven applied; **none rejected**. Suite **415 → 438
checks** (+23), 20 fresh sabotages, `RESULT: ALL PASS (438 checks)`.

## 8.1 What was wrong and what it is now

| # | Defect | Fix | Files |
|---|--------|-----|-------|
| 1 | **W30 called `?` binary.** The shipped ruling said "the twelve **binary** tokens" and grounded itself in R510/R511's two-operand button rule. `?` is the engine's ternary `COND` (`#define COND 49`, `src/save.c:2361`, dispatched at `2531-2536` under `if(stackptr2 > 2)`, consuming **three** entries). The item's own catalogue row got it right, so the one ruling and the one table disagreed inside one commit — and phase 4 / ledger item 10 reads W30 as its contract. | W30 now reads "eleven binary tokens plus the ternary `?`, which R510 does not describe", states the C evidence, and **explicitly hands phase 4 the three-operand rule** (`<third> <second> <top> ?`) with the failure it prevents. Mirrored in the `calc::pad_keys` header comment and the S22 comment in the suite. | spec, `.tcl`, test |
| 2 | **No stacking guard on `.calc.fn`.** `lower .calc.fn` left `RESULT: ALL PASS (415 checks)` while the entire 56-name browser sat behind the panedwindow, `ismapped` still 1. The keypad, packed by the identical `pack -in` rule, had two such guards. | Three legs added: `.calc.fn` above `.calc.pw` in `winfo children .calc`; `winfo containing` at `.calc.fn`'s centre; and — the frame can be on top with the canvas covered — `winfo containing` at **`.calc.fn.list`'s** centre. | test |
| 3 | **The refusal string overflowed the status entry.** `.calc.status.msg` is 613 px; `function spectralPower is not available: needs a new C opcode; no N-route function ships in v1` is 94 chars / 666 px, of which 85 rendered — it ended `...no N-route function sh`. Only the *table's* `help` was bounded; the string `fn_click` **composes** was not. RULING-3's stated point is that a greyed entry carries information. | `fn_reason N` → `needs a C opcode not in v1` (same line now 67 chars / 474 px). New S24 leg bounds the **composed** line for every dead row, count riding along. | `.tcl`, test |
| 4 | **`.calc.pw.bot.pad -minsize` was a hardcoded 140 equal to the pane's request to the pixel — zero slack** — beside a comment claiming "a keypad that grows carries the minimum with it", which no code did. At `TkDefaultFont -size 12` the pane requests 164 against a pinned 140 and the keypad renders 143/152: **clipped**. | New `calc::apply_pane_minsize` (§8.2) makes the phase-0 numbers **floors** and raises them to the contents' real request. At the shipped font the pad still lands on **140**, so S4's number is unchanged — the sanctioned exception was not spent. | `.tcl` |
| 5 | **`.calc.pw.bot -minsize` was below its own contents.** Filling the pane took its `reqheight` 67 → 158 while the minimum stayed at the placeholder-era 140, so dragging the bottom sash to its **own legal floor** clipped `user 3`/`user 4` by 3 px — a pane whose stated minimum hides a control, which is exactly what landmine D3's `-minsize` exists to prevent. No check covered a dragged sash. | Same mechanism: derived to **158**. **S4's number for this pane changes 140 → 158** — the second amendment to a frozen phase-0 minsize, made deliberately, in the same commit as the check, and argued here. Two new S22 legs: `-minsize >= reqheight` (font-independent), and a real **drag to the floor** that then measures `user 1..4` against `.calc.pad`'s bottom edge. | `.tcl`, test |
| 6 | **Three of four C-route compositions were pinned by nothing.** Only `groupDelay` had a literal (via D6). Rewriting `rms` → `dup() + avg() ln()`, `dBm` → `log10() 20 * 30 -`, `rmsNoise` → `dup() / integ() abs()` kept every shape check green: still route C, still >1 token, every token in the 52-token set. A wrong composition is not a crash, it is a plausible number three phases later. | All four pinned by literal, each with the arithmetic it stands on written beside it, **plus** a leg asserting those four *are* the whole C-route set (so the block cannot silently pin a subset). | test |
| 7 | **`calc::fn_fill` kept the scroll position.** A canvas keeps `xview`/`yview` across `delete all`; only the scrollregion changed. Scroll `All` to its far corner (what dragging `.calc.fn.hsb` does — its `-command` *is* `.calc.fn.list xview`), switch to `Special Functions`, and 28 of 56 entries were off-screen with the whole alphabetical head above the top edge. | `$c xview moveto 0 ; $c yview moveto 0` after the scrollregion, in **both** exits of `fn_fill`. Three new legs: a *fixture* proving the list really was scrolled off first, the two views back at 0, and — not just two numbers — that `average`/`bandwidth`/`clip` are back inside the visible window. | `.tcl`, test |
| 8 | **Neither `-xscrollcommand` nor `-yscrollcommand` was asserted**, so both bars could be permanently dead with the suite green (`get` → `0 0 0 0`, no thumb). The check named *"the horizontal scrollbar reports a partial view"* read `.calc.fn.list xview` — **the canvas**, not the bar. | The two options asserted directly; the partial-view check **re-pointed at `.calc.fn.hsb get`** (a real two-element float pair, second < 1.0, second > first), and the same leg added for `.calc.fn.vsb`, which R112 makes load-bearing here. | test |
| 9 | **The disabled state was not proved table-derived.** R413 makes the table the single source for three things; only the *help* had a coupling check. Replacing `lsearch $dead $route` with a hardcoded list of the fourteen names — literally the second table R413 forbids — left all 415 green. | Two legs. (a) Per entry, `-fill` compared against the **route field of that entry's own row** — catches any divergence. (b) The one that catches an *equivalent* hardcoded list: at runtime the test **moves the dead-route set** (`fn_dead_routes` → `{N X T}`), repaints, and asserts the greying followed (14 → 48 → 14). Sabotage **I** is the reviewer's exact reproducer and leg (b) reddens on it alone. A third leg asserts every greyed entry refuses with **its own route's** reason. | test |
| 10 | **`::calc::fnitem` was write-only** — rebuilt both directions on every `fn_fill`, 112 entries live, read by no code and no test. | Deleted, with its declaration. `grep -rn fnitem src/ tests/` is now empty. | `.tcl` |
| 11 | **`calc::fn_unhover {name}` never read `name`.** The guard was on the shared `fnhelp`, so entry B's `<Leave>` could retire entry A's line — and the canvas does deliver that sequence. | The guard is now **per entry**: the leaving entry's own help from the table must be both what `fnhelp` holds and what is on the status line. New leg: hover A, `<Leave>` B, A's line survives. (Sabotage **K**.) | `.tcl`, test |

**Also fixed, from the same findings:** the two stale layout-arithmetic comment
blocks (`calc::pw_list`'s margin table said `.calc.pw.bot 67 (-minsize 140)` and
`calc::min_floor`'s sum said `140`) are re-measured to **158** with the measured
first-open allocation — the pw_list block's own instruction, *"If a later item
changes a pane's contents, re-measure"*, is the one the first cut did not follow.

**Already gone, no action:** `tests/headless/probe_calc_fn.tcl` and
`probe_calc_min.tcl`. `ls tests/headless/probe_calc_*.tcl` →
*"No such file or directory"*; `git status --short tests/headless/` lists only the
modified suite. The droppings were removed before this round started.

## 8.2 The mechanism (`calc::apply_pane_minsize`)

The phase-0 `-minsize` numbers stay in `build_panes` as **floors** — nothing can
lower a minimum below what phase 0 wrote — and a new pass raises the **two panes
item 4 filled** to what their contents really request:

```
.calc.pw     .calc.pw.bot      reqheight    ->  140 floor, 158 applied
.calc.pw.bot .calc.pw.bot.pad  reqwidth     ->  140 floor, 140 applied
```

Only those two, deliberately: the other four panes' contents landed in items 1–2,
no finding re-judged them, and phase-0 layout is otherwise frozen. (Applying it to
all six would move `.calc.pw.buf` 70 → 124 and `.calc.pw.stk` 80 → 133, which is
arguably right and is *not this item's call*.)

It runs **after** `restore_layout` — so a saved sash is replayed first and then
clamped upward, the way `apply_minsize` already self-heals a clipped toplevel
geometry — and **before** the `<Configure>` binding exists, so the
`update idletasks` it needs cannot re-enter `save_layout` (**landmine D6**).

## 8.3 Evidence

**Suite:** `RESULT: ALL PASS (438 checks)`. Four named suites through
`run_suites.sh` on `:99`: `test_calc_skeleton` 438, `test_wave_viewer` 400,
`test_accelerators`, `test_bindings_file` — `4/4 runs passed`, all four **PASS in
`00b-audit-baseline-2026-08-14.txt`**, so **no test moved in either direction by
name or status**. Three more the driver did not name (`test_wave_tabs` 172,
`test_binding_precedence` PASS, `test_palette` — see §8.4).

**Non-vacuity:** with `git show HEAD:src/calculator.tcl` in place the suite reports
`110 FAILED (328 passed)` and **runs to the end**. It did not, at first: the new
drag leg used a bare `winfo rooty .calc.pad`, which threw against a keypad-less
tree and took the whole file down in the outer catch with S23/S24 never run — the
exact trap this file records twice. Every number the new legs feed to `expr` is now
proved numeric first and the `rename` pair is guarded.

**Sabotage: 20 breaks, each restored from a byte-exact backup** (`md5` of
`src/calculator.tcl` `14128a26…` before and after all twenty). Every check added or
changed in this round is covered; the table is in the fixer's report. The two worth
naming here:

- **I** — the reviewer's own reproducer (hardcoded name list, contents identical to
  the table) reddens exactly one check, the runtime dead-route repaint. The
  per-entry coupling leg alone does *not* catch it, which is why leg (b) exists.
- **A/C/S** — three independent ways of defeating the derived minimum, each
  reddening the same three: `S4 .calc.pw.bot -minsize`, `S22 the bottom pane's
  minimum covers what it holds, vertically too`, and `S22 the user buttons survive
  a drag to the bottom pane's own minimum`.

## 8.4 Still open after the fix round

- **`test_palette` prints no `RESULT:` line**, so `run_suites.sh` scores it
  `NORESULT`. Proved **not this item's doing** by A/B: with `HEAD`'s
  `calculator.tcl` in place the output is byte-identical (`EVENT opens palette:
  yes`, no `RESULT:`). Baseline lists it `PASS`, so the baseline was produced by
  `full_audit.sh`, which scores it differently. Not touched.
- **The pixels, again.** `[E]`. A **new look debt** is recorded (uncleared) for
  `04-phase1d-fixes.png`: the refusal line now reads to the end — judge whether the
  shorter reason still says enough; the category sweep now snaps back to the
  top-left; and the bottom pane can no longer be dragged small enough to clip
  `user 3`/`user 4`. The original phase-1d look debt stands, uncleared.
- **`:0`.** Everything ran on `:99`. The existing `test_calc_skeleton` suite debt
  covers it, and this round *adds* rendered-geometry legs (a real sash drag, two
  more `winfo containing` probes, canvas bboxes after a repaint) of exactly the kind
  WSLg's async `<Configure>` traffic can move.
- **The `raise` loop in `build_panes` is still dead code for both new widgets**
  (reviewer problem [3], not a defect and not in the confirmed set): Tk already
  stacks later-created siblings above earlier ones, so deleting the loop leaves the
  suite green while an explicit `lower` reddens three checks. Left alone — it is
  cheap insurance if the creation order ever changes — but the comment calling it
  "the stacking guard every `pack -in` row has paid for" overstates what the code
  does.

---

# 9. PER-CHECK SABOTAGE MAP (appended by the closer)

§5 lists the item round by *break*; §8.3 pointed at the fixer's report for the fix
round. Both are transcribed here by *check*, so every check added or changed by
item 4 has a row and the three that have none are named as unsabotaged. Ids `[A..]`
are the verification round's driver, `[A]..[X]` the fix round's. Every break was
reverted from a byte-exact md5-verified backup and re-run green (`src/calculator.tcl`
`8cb530b2…` through the verification round, `14128a26…` through the fix round).

## 9.1 Verification round — 85 breaks, every one red, every one restored

| check | broken | red | restored |
|---|---|---|---|
| S22 first open returns .calc | [A01] `calc::open` returns `.nope` | yes (10) | yes |
| S22 reopen returns .calc | [A01] same | yes | yes |
| S22 .calc.pad class | [A02] `frame` → `labelframe` | yes (3) | yes |
| S22 .calc.pad parent is .calc | [A03] `destroy .calc.pad` | yes (21) | yes |
| S22 drawn in the Keypad pane | [A04] `pack -in` → `place -x 0 -y 0` | yes (3) | yes |
| S22 keypad stacks above the panedwindow | [E01] `lower .calc.pad` | yes (3) | yes |
| S22 keypad is the topmost widget at its own centre | [E01] same | yes (3) | yes |
| S22 the twelve operator keys, in order, all pressable | [A06] `k3 -state disabled` | yes (2) | yes |
| S22 the pad holds exactly 12 keys + 4 user buttons, no strays | [A12] a fifth user button | yes (5) | yes |
| S22 no digit, decimal point or sign key (RULING-2) | [A08] `?` → `.` | yes (4) | yes |
| S22 there is no k13, and there is a k12 | [A09] a 13th token `abs()` | yes (7) | yes |
| S22 a fresh window still has no digit key | [A09] same | yes (7) | yes |
| S22 the key set is the ruled twelve | [A10] `pad_keys` reordered | yes (3) | yes |
| S22 the four user buttons, with the spec's labels | [A11] `-text "user $i"` → `"u$i"` | yes (1) | yes |
| S22 there is no u5, and there is a u4 | [A12] fifth user button | yes (5) | yes |
| S22 every key wears the palette | [A13] `k1 -background #123456` | yes (1) | yes |
| S22 the pad frame wears the panel colour | [A14] pad `-background grey40` | yes (1) | yes |
| S22 every operator key names itself and its phase (R506) | [A15] `pad_click` phase 2 → 3 | yes (1) | yes |
| S22 every user button names itself and its phase (R506) | [A16] user phase 9 → 8 | yes (1) | yes |
| S22 no key touched the buffer | [A17] `pad_click` writes to `.calc.buf` | yes (1) | yes |
| S22 no key touched the stack | [A18] `pad_click` pushes on `.calc.stk.list` | yes (2) | yes |
| S22 the keypad pane's minimum covers what it holds | [A19] pad `-minsize` 140 → 100 | yes (3) | yes |
| S22 the keypad is not squeezed at first open | [A19] same | yes (3) | yes |
| S22 all sixteen keypad buttons are on screen at first open | [A20] `pad_cols` 4 → 1 | yes (1) | yes |
| S22 the pre-press snapshot is real text | — | **UNSABOTAGED** (positive control) | — |
| S23 .calc.fn class | [B01] `frame` → `labelframe` | yes (1) | yes |
| S23 .calc.fn parent is .calc | [B02] `destroy .calc.fn` | yes (30) | yes |
| S23 drawn in the Functions pane | [B03] `pack -in` → `place` | yes (2) | yes |
| S23 .calc.fn.cat class | [B04] combobox → `ttk::spinbox` | yes (1) | yes |
| S23 .calc.fn.list class | [B05] canvas → `text` | yes (13) | yes |
| S23 the category values are §7.1's, in order | [B06] `fn_categories` reordered | yes (1) | yes |
| S23 the initial category is Special Functions | [B07] initial `set {Arithmetic}` | yes (12) | yes |
| S23 a fresh window opens on Special Functions | [B07] same | yes (12) | yes |
| S23 the category chooser is readonly | [B08] `-state normal` | yes (1) | yes |
| S23 the chooser binds combo_letter_cycle | [B09] the `bind <Key>` line deleted | yes (1) | yes |
| S23 the chooser does not borrow the status history's offset style | [B10] `Calc.Field.TCombobox` → `Calc.TCombobox` | yes (1) | yes |
| S23 the list wears the field colour | [B11] canvas `-background grey70` | yes (1) | yes |
| S23 both scrollbars exist, drive the list and wear the palette | [B12] hsb `-command … yview` | yes (1) | yes |
| S23 the horizontal scrollbar is the horizontal one | [B13] hsb `-orient vertical` | yes (1) | yes |
| S23 the scrollregion is a real four-tuple | [B14] `-scrollregion {0 0 0 0}` | yes (3) | yes |
| S23 the six columns are wider than the visible list… | [B15] scrollregion width forced to 10 | yes (2) | yes |
| S23 the horizontal scrollbar reports a partial view | [B15] same | yes (2) | yes |
| S23 the default category renders all 56 of its entries | [B16] `lrange … 1 end` | yes (10) | yes |
| S23 a fresh window renders that category | [B16] same | yes (10) | yes |
| S23 …and they are the catalogue's names, alphabetically | [B17] `lsort -dictionary` dropped | yes (2) | yes |
| S23 the rendered names are exactly the table's for that category | [B18] `average` drawn `AVERAGE` | yes (4) | yes |
| S23 the entries are laid out in six columns | [B19] `fn_cols` 6 → 4 | yes (4) | yes |
| S23 the first column holds the first names… (column-major) | [B20] index → row-major | yes (2) | yes |
| S23 exactly the N-route and out-of-scope entries are greyed (RULING-3) | [B21] `fieldfg` unconditionally | yes (1) | yes |
| S23 the greyed colour is not the live one | [B22] `disabledfg` mapped to `fieldfg` | yes (3) | yes |
| S23 all fourteen greyed entries are RENDERED, not removed | [B23] dead rows dropped from `fn_entries` | yes (11) | yes |
| S23 every entry carries its own click and hover binding | [B24] per-item `<Enter>` bind deleted | yes (1) | yes |
| S23 hovering an entry shows its one-line help (R413) | [B26] `fn_hover` hardcodes a second-table string | yes (4) | yes |
| S23 the help comes from the table, not a second one | [B26] same | yes (4) | yes |
| S23 hovering records nothing in the history | [B27] hover passes `record 1` | yes (1) | yes |
| S23 the pre-hover history snapshot is real | [B28] `calc::status` `record` default → 0 | yes (11) | yes |
| S23 leaving retires the help line | [B29] `fn_unhover` early-returns | yes (1) | yes |
| S23 leaving does not wipe a message written after the hover | [B30] `fn_unhover` clears unconditionally | yes (1) | yes |
| S23 clicking a live entry is inert and names its phase | [B31] `fn_click` phase 5 → 4 | yes (2) | yes |
| S23 clicking an N-route entry explains why it cannot be used | [B32] `fn_reason N` → `{}` | yes (2) | yes |
| S23 clicking an out-of-scope entry explains why too | [B33] `fn_reason X` reworded | yes (1) | yes |
| S23 no function click touched the buffer | [B34] `fn_click` writes to `.calc.buf` | yes (1) | yes |
| S23 no function click touched the stack | [B35] `fn_click` pushes on the Stack | yes (1) | yes |
| S23 a real click on an entry reaches its handler | [B36] per-item `<Button-1>` bind deleted | yes (2) | yes |
| S23 switching category repopulates the list | [B37] `fn_cat_changed` counts instead of filling | yes (2) | yes |
| S23 the category switch says what it did (R506) | [B38] message → `functions changed` | yes (1) | yes |
| S23 the All category shows every row of the table | [B39] the `All` arm dropped | yes (3) | yes |
| S23 the pre-click buffer snapshot is real text | — | **UNSABOTAGED** (positive control) | — |
| S24 the catalogue is a real, non-empty list | [C01] `calc::catalogue` returns `{}` | yes (39) | yes |
| S24 the schema is the six ruled fields | [C02] `returns` dropped from `fn_fields` | yes (1) | yes |
| S24 every row is a well-formed six-field row | [C03] `stddev` loses `returns` | yes (3) | yes |
| S24 every §7.1 category has entries, in the spec's numbers | [B39]/[C04]/[C05] | yes (3) | yes |
| S24 the DEFAULT category is the one that must not be empty (D1) | [C06] `clip` categorised `All`; also [C05] | yes (10) | yes |
| S24 every row's category is a §7.1 value, never the synthetic All | [C06] same | yes (10) | yes |
| S24 All is the union, not a category | [B39] the `All` arm dropped | yes (3) | yes |
| S24 no two rows share a name within a category | [C07] a second `average` row | yes (13) | yes |
| S24 no name is duplicated across the whole table either | [C08] `idx()` renamed `abs()` | yes (2) | yes |
| S24 the non-Special categories are exactly the §3.2 token set | [C09] `sgn()` renamed `sign()` | yes (2) | yes |
| S24 every primitive is route P and inserts itself verbatim | [C10] `sqrt()` insert → `abs()` | yes (1) | yes |
| S24 every emitted token is one the engine lexes, or a number | [C11] `rms` emits `mean()` | yes (1) | yes |
| S24 every C-route composition is more than one token (L3) | [C12] `dBm` reduced to `log10()` | yes (1) | yes |
| S24 P and C rows emit, T/N/X rows emit nothing | [C13] T-route `stddev` given an insert | yes (2) | yes |
| S24 D1: the special rows carry the combobox's own category string | [C05] `average` back to `Special` | yes (11) | yes |
| S24 D2: lshift is a T route and emits nothing | [C14] `lshift` back to C/`del()` | yes (3) | yes |
| S24 D3: integ and iinteg are no longer byte-identical rows | [C15] `iinteg` reverted to `integ`'s fields | yes (1) | yes |
| S24 D3: …and it is the returns field that separates them | [C01] catalogue emptied (⚠ blunt: [C15] leaves it green by design) | yes (39) | yes |
| S24 D6: groupDelay carries the degrees-per-Hz conversion | [C16] back to `cph() deriv() -1 *` | yes (1) | yes |
| S24 the disabled set is the ledger's N routes plus the out-of-scope rows | [C17] `psd` route N → T; also [C20] | yes (2) | yes |
| S24 a live route has no refusal reason, a dead one does | [B32] `fn_reason N` → `{}`; also [C18] | yes (2) | yes |
| S24 every help line is short enough for the status entry | [C19] `average` help past 72 chars | yes (4) | yes |
| S24 fixture: the spec's §3.2 lists 52 tokens | — | **UNSABOTAGED** (fixture literal) | — |
| S14 a filled pane keeps no placeholder hint (RESTATED) | [D02] a hint packed back into the Keypad pane | yes (3) | yes |
| S14 the placeholder proc is gone with its last caller | [D01] `calc::placeholder` resurrected | yes (1) | yes |

## 9.2 Fix round — 24 breaks, every one red, every one restored

| check | broken | red | restored |
|---|---|---|---|
| S22 the bottom pane's minimum covers what it holds, vertically too | [A] `.calc.pw.bot` row dropped from `apply_pane_minsize`; also [C],[S] | yes (3) | yes |
| S22 the user buttons survive a drag to the bottom pane's own minimum | [A] same — the leg that drags the sash to the floor | yes (3) | yes |
| S4 `.calc.pw.bot -minsize` (CHANGED 140 → 158) | [A]/[C]/[S], three ways of defeating the derived minimum | yes | yes |
| S4 `.calc.pw.bot.pad -minsize` (mechanism changed, number unchanged) | [B] pad row dropped + floor 140 → 100 | yes (3) | yes |
| S22 the keypad pane's minimum covers what it holds (re-run) | [B] same | yes (3) | yes |
| S22 the keypad is not squeezed at first open (re-run) | [B] same | yes (3) | yes |
| S23 the function browser stacks above the panedwindow | [D] `lower .calc.fn` (the reviewer's reproducer) | yes (3) | yes |
| S23 the function browser is the topmost widget at its own centre | [D] same | yes (3) | yes |
| S23 the function LIST is the topmost widget at its own centre | [D] same | yes (3) | yes |
| S23 the list reports its view back to both scrollbars | [E] both `-*scrollcommand` deleted | yes (3) | yes |
| S23 the horizontal scrollbar reports a partial view (re-pointed at `hsb get`) | [E]; also [G] | yes (3) | yes |
| S23 the vertical scrollbar reports a partial view too (R112) | [E] same | yes (3) | yes |
| S23 switching category scrolls the new list back to its top-left | [F] the `xview/yview moveto 0` pair removed | yes (2) | yes |
| S23 …and the head of the alphabet is on screen again | [F] same | yes (2) | yes |
| S23 fixture: the list really was scrolled off its origin first | [G] scrollregion width forced to 10 | yes (3) | yes |
| S23 the greying is read off the table's route field, not a second list | [J] hardcoded greying + `psd` route moved | yes (5) | yes |
| S23 moving the dead-route set repaints the greying | [I] hardcoded list AGREEING with the table | yes (1) | yes |
| S23 the repaint left the same 56 entries behind | [T] `$c delete all` removed | yes (7) | yes |
| S23 every greyed entry refuses with its own route's reason | [J]; also [W],[T] | yes (5) | yes |
| S23 hovering B does not let A's `<Leave>` wipe B's line | [K] `fn_unhover` back to the shared-`fnhelp` guard | yes (1) | yes |
| S23 leaving retires the help line (subject rewritten) | [U] `fn_unhover` early-returns | yes (1) | yes |
| S23 leaving does not wipe a message written after the hover (subject rewritten) | [V] guard dropped entirely | yes (2) | yes |
| S23 clicking an N-route entry explains why it cannot be used (text changed) | [H] the 94-char reason restored; also [W] | yes (2) | yes |
| S23 clicking an out-of-scope entry explains why too (subject rewritten) | [X] `fn_reason X` → `maybe later` | yes (1) | yes |
| S24 every refusal line fn_click composes fits the status entry too | [H] same | yes (2) | yes |
| S24 a live route has no refusal reason, a dead one does (subject rewritten) | [W] `fn_reason N` → `{}` | yes (4) | yes |
| S24 the `?` row is on the keypad, in Arithmetic, emitting the bare token | [Q] `?` categorised Trigonometric | yes (2) | yes |
| S24 …and its help states THREE operands, not two (COND) | [R] help rewritten as two operands | yes (1) | yes |
| S24 the C-route composition for rms is exactly the ruled RPN | [L] `rms` → `dup() + avg() ln()` | yes (1) | yes |
| S24 the C-route composition for dBm is exactly the ruled RPN | [M] `dBm` → `log10() 20 * 30 -` | yes (1) | yes |
| S24 the C-route composition for rmsNoise is exactly the ruled RPN | [N] `rmsNoise` → `dup() / integ() abs()` | yes (1) | yes |
| S24 the C-route composition for groupDelay is exactly the ruled RPN | [O] back to `cph() deriv() -1 *` | yes (2) | yes |
| S24 …and those are every C-route row there is | [P] `stddev` turned into a fifth C route | yes (4) | yes |

**Three checks have no row and are therefore not evidence** — `S22 the pre-press
snapshot is real text`, `S23 the pre-click buffer snapshot is real text`, `S24
fixture: the spec's §3.2 lists 52 tokens`. All three are fixture preconditions or
positive controls: they assert the *test's own* sentinel arrived, which is what
makes the purity and lexability checks beside them non-vacuous. No sabotage of
item-4 code can redden them. ⚠ Two more are covered only by widget *deletion* —
`S22/S23 parent is .calc` ([A03]/[B02]) — because in Tk the path is the parent.
