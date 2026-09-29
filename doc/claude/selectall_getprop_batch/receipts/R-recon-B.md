# Receipt — Stage R, recon crew B (`getprop`'s missing object-type arms)

**Scope:** PLAN.md Stage B questions **7–12 only**. Read-only recon. Nothing in the tree was
changed; this receipt is the only file created. Measured at **`b89fddda`** against the
in-tree `src/xschem` (mtime 2026-09-29 00:29, not rebuilt — see "What I did NOT do").

**Instrument.** Four throwaway Tcl scripts plus one fixture `.sch`, all under
`/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-.../scratchpad/R-recon-B/`, run as
`timeout 60 ./src/xschem --pipe -q --nogui --script <script>` from the repo root. `--nogui`
on every invocation, so nothing touched the user's real `$DISPLAY`. Scripts: `q7.tcl` (every
arm × every arity), `q7b.tcl` (setprop→disk→getprop round trip), `q10.tcl` (creation verbs,
id→index chain), `recipe.tcl` (fixture recipe), `wq.tcl` (`with_quotes`, red-row shape).
All output quoted below is verbatim.

**HOME was not armed** — the task brief explicitly permitted the bare
`./src/xschem --pipe -q --nogui --script <scratchpad script>` spelling for this recon, and I
used it rather than `run_suites.sh`. Checked afterwards: **nothing in `~/.xschem/` was
written.** Every mtime there (`.clipboard.sch` 20:31, `geometry` 01:46, `recent_files` 23:35,
`raw_history` 22:11, …) predates the probe window, which ran ~04:3x–04:4x. So on this build
`--pipe -q --nogui --script` is clean against the real HOME, at least for a script that only
loads, saves to an absolute scratch path, and reads properties.

---

## Q7 — the actual `getprop` arms. **The driver's list is right about the arms and wrong about the behaviour.**

There is exactly **one** `getprop` dispatch site: the `else if(!strcmp(argv[1], "getprop"))`
branch inside **`xschem_cmds_g()`** in `src/scheduler.c`. No Tcl shim exists
(`/usr/bin/grep -rn "rename xschem\|proc xschem " src/*.tcl` → nothing), so this branch is
the whole read surface.

The branch is a flat `else if` chain on `argv[2]` with **seven** arms:
`instance`, `instance_notcl` (same arm, `with_quotes=2`), `instance_pin`, `symbol`, `rect`,
`text`, `wire`. Then the chain simply **ends** — there is no `else` and no unknown-type
error.

### What the driver got right
* `instance` / `instance_notcl` / `symbol` do return a full property string — **when the
  attribute argument is omitted.** With an attribute they return one token.
* `rect` / `text` / `wire` are token-only: omitting the token is an **arity error**, not a
  whole-string read.
* `line` / `poly` / `arc` have **no arm**.

### ⚠ What the driver got wrong, and it changes Stage B's fence design

**The absence of an arm is not an error. It is a silent empty success.** Verbatim, `q7.tcl`:

```
getprop line 4 0      -> OK: ||
getprop poly 4 0      -> OK: ||
getprop arc 4 0       -> OK: ||
getprop line 4 0 myline   -> OK: ||
getprop poly 4 0 mypoly   -> OK: ||
getprop arc 4 0 myarc     -> OK: ||
getprop zzz           -> OK: ||
getprop zzz 1 2 3     -> OK: ||
getprop line          -> OK: ||
```

and the `catch` return codes, verbatim from `wq.tcl`:

```
catch rc for 'getprop line 4 0 fmt'  = 0 , result = ||
catch rc for 'getprop line 99 0 fmt' = 0 , result = ||
catch rc for 'getprop line 4 0'      = 0 , result = ||
catch rc for 'getprop rect 4 0'      = 1 , result = |xschem getprop rect needs <color> <n> <token>|
```

Consequences the implementer must not miss:

1. **A red row written as "it errors today, it must succeed tomorrow" would be wrong** —
   `catch` is `0` today. The red must assert on the **value**: today `{}`, tomorrow the
   stored value. (This is also the `catch`-not-`raise` discipline the brief demands: nothing
   here raises, so no wrapping is needed, but nothing here is distinguishable from "attribute
   absent" either.)
2. **`getprop line 99 0 fmt` — a garbage layer — also returns `{}` with rc 0.** So the
   bad-index fence for the new arms is a genuine red too: today silence, tomorrow an error.
3. `getprop` **silently accepts any unknown type name**, unlike the sibling locate API:
   `xschem object polygon #4,0 -> ERROR: xschem object: unknown type`. Noted as a decision
   under "What the implementer needs".

### ⚠ The second correction: `text` is not token-only, and `setprop` already has the three missing arms

* **`text` has two pseudo-tokens** that are not attributes at all:
  `getprop text 0 txt_ptr -> OK: |hello world|` and `getprop text 0 size -> OK: |0.4|`
  (the latter returns `xctx->text[n].xscale`). `size` is **undocumented** — it exists only as
  an inline `/* pseudo-token: the text's xscale (display size) */` comment inside the arm, not
  in the `getprop` doc block, and therefore not in the shipped manual either.
* **`setprop` HAS `line`, `arc` and `poly` arms** — in `xschem_cmds_s()`, added by "audit 0063
  atom 10", whose own comment says *"these had NO setprop case at all (audit 0063 gap)"*. So
  the real shape of the gap is an **asymmetry, not a hole**: from Tcl you can already *write*
  a line/poly/arc property and you cannot read it back. Proved end-to-end in `q7b.tcl` — write,
  save to disk, grep the disk, read back:

```
setprop line 4 0 zz 9 -> OK: ||
setprop arc 4 0 zz 7  -> OK: ||
setprop poly 4 0 zz 8 -> OK: ||
--- read back what setprop wrote, from disk ---
L 4 0 0 100 0 {myline=Lvalue dash=4
zz=9}
A 4 200 200 25 0 360 {myarc=Avalue fill=full dash=5
zz=7}
P 4 3 0 100 50 150 100 100 {mypoly=Pvalue fill=true dash=3
zz=8}
--- can getprop read ANY of it? ---
getprop line 4 0 zz -> OK: ||
getprop arc 4 0 zz  -> OK: ||
getprop poly 4 0 zz -> OK: ||
```

**That round trip is the strongest red row available**, and it needs no fixture file.

* **`allprops` is a `setprop`-only spelling.** `getprop` does not honour it — it falls through
  to `get_tok_value(prop, "allprops")`, which is empty:
  `getprop rect 4 0 allprops -> OK: ||`, `getprop text 0 allprops -> OK: ||`,
  `getprop wire 0 allprops -> OK: ||`.
* The correct type name is **`poly`**, not `polygon`, for both `getprop`'s siblings and
  `object_type_from_name()`: `getprop polygon 4 0 mypoly -> OK: ||` (silent miss) while
  `getprop poly …` would be the arm. Note the **creation verb is `xschem polygon`** — the
  tree is inconsistent here already and `poly` is the property-side spelling.

### The corrected table

| `argv[2]` | arm exists | full prop string | token read | bad ref | notes |
|---|---|---|---|---|---|
| `instance` | yes | **yes** (omit attr) | yes, `with_quotes=0`; `cell::X` reads the symbol's prop; `cell::name` returns the symbol file name | `TCL_ERROR` `xschem getprop: instance not found:<ref>` | ref = name **or** index |
| `instance_notcl` | yes (same arm) | **yes** | yes, `with_quotes=2` | same | flavour, not a type |
| `instance_pin` | yes | **yes** for the pin rect (omit attr) | yes, `with_quotes=0`, with `attr(pin)`/`attr(n)`/symbol-pin fallback and slot splitting | **silent `{}`** for an unknown pin and for an unknown attr | `getprop instance_pin p9 nosuchpin -> OK: \|\|` |
| `symbol` | yes | **yes** (omit attr) | yes, `with_quotes` = optional arg, default 0 | `TCL_ERROR` `Symbol not found` | |
| `rect` | yes | **no** — omitting the token is an arity error | yes, `with_quotes` = optional arg 6, default 0 | `TCL_ERROR` `xschem getprop: rect not found: <c> <n>` (issue 0077 bounds check) | |
| `text` | yes | **no** | yes, `with_quotes` **hardcoded 2**; plus pseudo-tokens `txt_ptr` and `size` | `TCL_ERROR` `xschem getprop: text object not found:<n>` | `n` may be the `name` attribute (`get_text()`) |
| `wire` | yes | **no** | yes, `with_quotes` **hardcoded 2** | `TCL_ERROR` `xschem getprop: wire not found: <n>` (issue 0077 bounds check) | |
| `line` | **no** | no | **no** — silent `{}` | **silent `{}`** | `setprop line` exists |
| `poly` | **no** | no | **no** — silent `{}` | **silent `{}`** | `setprop poly` exists |
| `arc` | **no** | no | **no** — silent `{}` | **silent `{}`** | `setprop arc` exists |

Arity errors for the token-only arms (verbatim): `xschem getprop rect needs <color> <n> <token>`,
`xschem getprop text needs <n> <token>`, `xschem getprop wire needs <n> <token>`. With no
subcommand at all: `xschem getprop needs instance|instance_pin|wire|symbol|text|rect` — that
message is the canonical arm list and **must be extended** by Stage B.

⚠ **`with_quotes` is already inconsistent across shipped arms** and the implementer has to
pick for the new three. Measured in `wq.tcl` on a value `fmt="a b" esc=x\y`:

```
rect fmt  (wq default 0) -> OK: |a b|
rect fmt  wq=1           -> OK: |"a b"|
rect fmt  wq=2           -> OK: |a b|
wire fmt  (hardcoded 2)  -> OK: |a b|
wire fmt  extra arg 0    -> OK: |a b|      <- the extra arg is IGNORED by the wire arm
```

---

## Q8 — what line, poly and arc actually store

From `src/xschem.h`, the structs (`xLine`, `xPoly`, `xArc`) as of `b89fddda`:

* **`xLine`** — `double x1, x2, y1, y2`; `unsigned short sel`; **`char *prop_ptr`**;
  `short dash`; `double bus`; `unsigned int id`.
* **`xPoly`** — `int points`; `double *x, *y`; `unsigned short *selected_point`;
  `unsigned short sel`; **`char *prop_ptr`**; `short fill`; `short dash`; `double bus`;
  `unsigned int id`.
* **`xArc`** — `double x, y, r, a` (start angle), `b` (arc angle); `unsigned short sel`;
  **`char *prop_ptr`**; `short fill`; `short dash`; `double bus`; `unsigned int id`.

**Every one carries a `prop_ptr`, so the read needs no new storage** — it is
`get_tok_value(prop_ptr, tok, wq)`, exactly what the `rect` arm does. The spec's claim
("This is missing dispatcher surface, not missing engine capability") is confirmed.

`dash`, `fill` and `bus` are **caches derived from `prop_ptr`**, recomputed by the `setprop`
arms after every write (`l->bus = get_attr_val(get_tok_value(l->prop_ptr, "bus", 0))`, etc.).
A *read* arm must not touch them. Note `xLine` has **no `fill`** — a fenced `fill` read on a
line must come from `prop_ptr` like anything else, and Stage B should not invent a `fill`
pseudo-token for lines.

Geometry (`x1/y1/x2/y2`, the poly point arrays, the arc's `r/a/b`) is **not** in `prop_ptr`
and is therefore **not** reachable by a property read. Whether `getprop` should grow geometry
pseudo-tokens the way `text` grew `size` is a scope question — see "What the implementer
needs". The `id` field is already reachable via `xschem object`.

---

## Q9 — exact syntax, and the `setprop` counterpart to mirror

**Existing `getprop` syntax**, from the arm bodies (not from the doc block, which is
incomplete):

```
xschem getprop instance      <name|index> [attr]
xschem getprop instance_notcl <name|index> [attr]
xschem getprop instance_pin  <inst> <pin|pinnum> [pin_attr]
xschem getprop symbol        <sym_name> [attr] [with_quotes]
xschem getprop rect          <layer> <index> <attr> [with_quotes]
xschem getprop text          <index|name> <attr|txt_ptr|size>
xschem getprop wire          <index> <attr>
```

**There is a `setprop` counterpart, and it already covers the three missing types.** From
`xschem_cmds_s()`:

```
xschem setprop [-fast|-fastundo] line <layer> <index> <token>|allprops [value]
xschem setprop [-fast|-fastundo] arc  <layer> <index> <token>|allprops [value]
xschem setprop [-fast|-fastundo] poly <layer> <index> <token>|allprops [value]
```

Bad-reference behaviour there is a hard error, verbatim:
`setprop line 9 0 zz 9 -> ERROR: xschem setprop line: wrong layer or line number`.

So the mirror is unambiguous: **`<layer> <index> <token>`, type name `line` / `poly` / `arc`,
and an error (not silence) on a bad layer/index.** That is simultaneously the `rect` getprop
shape and the `setprop` line/poly/arc shape — the two conventions agree, so no tradeoff.

The only genuinely open spelling is the **whole-property-string** form, where the two shipped
conventions disagree:
* `getprop` says *omit the token* (`getprop instance p9` → `name=p9 lab=VDD`);
* `setprop` says *the literal token `allprops`*.

`allprops` is currently a guaranteed-empty read on every arm, so adding it breaks nothing.
Recommendation in the final section.

⚠ **The doc block is a shipped surface and is already stale.** `doc/xschem_man/developer_info.html`
carries the `getprop` and `setprop` comment blocks **verbatim** (its own HTML comment says the
list was *"generated in xschem src dir with `./extract_scheduler_cmd_help.awk scheduler.c`"*).
That extractor **no longer exists anywhere in the tree** (`find . -name "extract_scheduler*"
-not -path "./.git/*"` → nothing), so the block is hand-pasted now. And the precedent is that
the 0063 change did **not** update either: `/usr/bin/grep -c "setprop line\|setprop arc\|setprop
poly" doc/xschem_man/developer_info.html` → **0**, and the C `setprop` doc block itself does not
document its own line/arc/poly arms. Stage B should at minimum extend the **C** doc block and the
`"xschem getprop needs …"` error string; the HTML is a hand edit with a precedent for skipping it.

---

## Q10 — `xschem object` / `objects`, and the address API the new arms compose with

**Yes, a full address-only API exists, and a `<layer> <index>` getprop grammar composes with
it exactly, with no new selector syntax needed.**

`xschem object <type> <selector>` (`xschem_cmds_o()`, helpers `object_type_from_name()` and
`object_descriptor()`) returns one bare Tcl dict `{type T index I layer C id ID name {N}}`,
or `{}` on a miss. Types: `wire|instance|rect|line|poly|arc|text` — **`poly`, and an unknown
type is a hard error.** Selectors: `@<id>` (stable id), `#<index>` (flat types),
`#<layer>,<index>` (rect/line/poly/arc), `<name>` (instance only).

`xschem objects [-type T] [-selected] [-layer L]` is the bulk enumerator, one `{…}` per
object across all seven types. `xschem object_at <x> <y>` is the read-only pick, returning a
`type index col id` row byte-identical to `xschem select_at`.

Verbatim from `q10.tcl` / `q7b.tcl`:

```
objects -> {type wire index 0 layer 1 id 1 name {}} {type rect index 0 layer 4 id 698 name {}} \
           {type line index 0 layer 4 id 697 name {}} {type poly index 0 layer 4 id 699 name {}}
object line #4,0  -> OK: |type line index 0 layer 4 id 697 name {}|
object line @697  -> OK: |type line index 0 layer 4 id 697 name {}|
object line #99,0 -> OK: ||
object poly #4,0  -> OK: |type poly index 0 layer 4 id 700 name {}|
object polygon #4,0 -> ERROR: xschem object: unknown type
objects -type line -> |{type line index 0 layer 4 id 697 name {}} {type line index 0 layer 5 id 698 name {}}|
```

**And there is a second, even more direct bridge**: per-type id→position verbs that return
exactly the `"<layer> <index>"` pair a `<layer> <index>` getprop arm wants —
`arc_index`, `line_index`, `poly_index`, `rect_index`, `instance_index`, `text_index`,
`wire_index` (all in `scheduler.c`, all built on `gfx_index_from_id()` /
`*_index_from_id()`), returning `-1` on a miss:

```
line_index 697 -> OK: |4 0|
poly_index of poly -> OK: |4 0|
line_index bogus -> OK: |-1|
```

So the durable-handle chain closes today without any new selector grammar:

```tcl
set d  [lindex [xschem objects -type line] 0]
set li [xschem line_index [dict get $d id]]      ;# -> "4 0"
xschem getprop line {*}$li mytoken               ;# <- the only missing link
```

`xschem selection` (from `sel_array`) returns `{wire 0 1 1} {rect 0 4 698} {line 0 4 697}
{poly 0 4 699}` — a `type index layer id` row, a different shape from `objects`. That
inconsistency is the spec's D8 and is explicitly out of scope.

---

## Q11 — which suite carries the fence

**`tests/headless/test_getprop_index_bounds.tcl` is the right home, and it is already
registered and already banner-compliant.**

* **Registered:** `tests/run_regression.tcl` line 33 at `b89fddda`, inside
  `set hcases [list` (which opens at line 27; `set dcases [list` does not open until line
  605). So it is an **`hcases`-only** case — headless arm only, no display arm, and therefore
  **adding rows to it moves no case count and adds no `skip:`**. The driver's
  `107/106/0/8` baseline should be unchanged if Stage B extends this suite rather than
  creating a new one.
* **Banner:** its epilogue is
  `if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 }`.
  `puts "OVERALL: ok"` emits a whole line `OVERALL: ok`, which matches
  `banner_complete`'s `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$` in `tests/banner_rule.tcl`.
  It also prints a `RESULT:` line, which `summarize_all` publishes. **Nothing to fix.**
* **Fit:** the suite is issue 0077's bounds fence — "`getprop wire` / `getprop rect` must
  bounds-check the caller-supplied index" — and its own header states *"Reaching `OVERALL: ok`
  is itself the core assertion"*. Bad-layer/bad-index behaviour for the new `line`/`poly`/`arc`
  arms is the same concern in the same suite, and the PLAN's constraint (*"A bad index or a
  missing object must return an error … Fence that"*) lands here naturally.
* **It builds its own fixture with no file on disk** (`xschem wire 0 0 100 0`,
  `xschem rect 4 0 0 50 50`) and does **not** source `scratch.tcl`, so it has no watchdog and
  prints no `note:`. Extending it in the same style keeps it self-contained.

**Working fixture recipe for the three new arms** (measured, `recipe.tcl`) — note the layer is
`rectcolor` (default **4**) for `line`/`polygon`/`rect`/`wire`, but an **explicit argument**
for `arc`:

```tcl
xschem line    0 0 100 0 -1 {myline=Lvalue dash=4}          ;# layer = rectcolor
xschem rect    0 20 40 60 -1 {myrect=Rvalue dash=2}         ;# layer = rectcolor
xschem polygon 0 100 50 150 100 100 {mypoly=Pvalue fill=true}  ;# >=3 pts, odd trailing arg = props
xschem arc     200 200 25 0 360 4 {myarc=Avalue fill=full}  ;# x y r a b LAYER [props]
xschem wire    400 0 400 100 -1 {lab=MYNET mywire=Wvalue}
```

Two traps found the hard way:
* `xschem arc 200 200 25 0 360` (no layer) **silently creates nothing** and returns `1` — it
  takes the GUI-arm branch (`argc > 7` is false). My first probe lost its arc this way.
* `xschem text` is **not** `<txt> x y rot flip xscale yscale props`. `create_text()` is called
  as `(layer=argv[9], x=argv[2], y=argv[3], rot=argv[4], flip=argv[5], txt=argv[6],
  prop=argv[7], scale=argv[8], argv[8])` — i.e. `xschem text <x> <y> <rot> <flip> <txt>
  <props> <scale> <layer>`. My wrong-order call produced `T {0} 0 300 300 0 0.4 0.4 {0.4}` on
  disk. `text` is not in Stage B's scope, but a fixture that needs a text should use a `.sch`
  on disk or this order.

---

## Q12 — the existing spec, and whether it constrains the answer

**`doc/claude/specs/property_introspection.md` exists, is `Status: PROPOSED … No code yet`,
and commits to NO syntax.** 87 lines. It offers two named candidates and explicitly says
*"Two directions, not mutually exclusive"*:

* **A — extend `getprop` per type.** *"Add a whole-string form (token omitted → return
  `prop_ptr`) for `wire`/`text`/`rect`, and add `line`/`poly`/`arc` arms."*
* **B — add property enumeration to the uniform API.** A `-props` flag on `xschem
  object`/`objects` appending `props {k v k v …}`.

**Stage B as scoped in the PLAN is candidate A**, and the spec's own §4 already writes A's
whole-string spelling as *token omitted*, not `allprops`. That is the closest thing to a
commitment in the document.

**It is partly stale**, in three measurable ways:

1. **Every line number in it is wrong.** It cites `getprop` at `src/scheduler.c:2686`, the
   instance whole-string at `:2707`, symbol at `:2776`, and the arm range as `:2686-2820`. At
   `b89fddda` the branch is at **5923** and the arms run to **6070**. (Also `token.c:308` for
   `list_tokens` — unverified, I did not check that one.)
2. **Its table is right but incomplete.** It does not record `text`'s `txt_ptr`/`size`
   pseudo-tokens, and it does not record that the failure mode for `line`/`poly`/`arc` is a
   **silent empty string rather than an error** — which is the single most decision-relevant
   fact and the thing the driver's scouting also missed.
3. **It never mentions that `setprop` already has `line`/`arc`/`poly` arms**, so it frames the
   gap as three types being unreachable when in fact they are **writable but not readable**.
   Its §3 sentence *"a script can find and select any object but can only inspect the
   properties of two of eight families"* should read *"can find, select and MODIFY any object,
   but can only inspect two"*.

Its one hard constraint is worth honouring: *"Any implementation must reuse the existing
bounds-check discipline (cf. issue 0077 / the `object #index` range-check) so a new read path
does not reintroduce the OOB defect."*

Two further docs it points at, both consistent with the above and neither adding a syntax
commitment: `object_model_architecture_primer.md` §8 (writes the blocked
`objects -selected` → `getprop` → `list_tokens` chain and names the middle step as the gap)
and `object_model_agent_reference.md` §11 (a `-props` sub-dict recipe, i.e. candidate B).

**Enumeration already works once the whole string is reachable:**
`xschem list_tokens [xschem getprop instance p9] 0 -> OK: |name lab|`, and
`xschem list_tokens {} 0 -> OK: ||` (no raise on empty). So `get_properties_names` needs no
new verb — only a whole-string read per type.

---

## What the implementer needs

**Grammar — the mirror that both shipped conventions already agree on:**

```
xschem getprop line <layer> <index> <token> [with_quotes]
xschem getprop poly <layer> <index> <token> [with_quotes]
xschem getprop arc  <layer> <index> <token> [with_quotes]
```

Type names **`line` / `poly` / `arc`** (matching `object_type_from_name()` and the `setprop`
arms — *not* `polygon`). `with_quotes` optional, default **0**, copying the `rect` arm
verbatim; do **not** copy `wire`/`text`'s hardcoded `2`, and do not "fix" those two (that is
the PLAN's "existing arm's behaviour is wrong rather than missing" clause — report, don't
change).

**Bad reference → `TCL_ERROR`**, matching both the `rect` getprop arm and the `setprop`
line/poly/arc arms. Suggested message spelling, following the `rect` arm exactly:
`xschem getprop: line not found: <c> <n>`. Guard shape, lifted from the `setprop` arm:
`if(!(c >= 0 && c < cadlayers && n >= 0 && n < xctx->lines[c]))` — and `xctx->polygons[c]`,
`xctx->arcs[c]` for the other two. Arity error below 6 args, matching
`xschem getprop rect needs <color> <n> <token>`.

**Seams, all in `src/scheduler.c`:**
* `xschem_cmds_g()` — the `getprop` branch. Three new `else if(argc > 2 && !strcmp(argv[2],
  "line"))` arms appended after the `wire` arm, before the branch's closing brace.
* The arm-list error string `"xschem getprop needs instance|instance_pin|wire|symbol|text|rect"`
  in that same branch — extend it, or it becomes a lie.
* The `getprop` doc block immediately above the branch — it is the source text of
  `doc/xschem_man/developer_info.html`'s help list (extractor now absent; hand edit).
* `xschem_cmds_s()`'s `setprop` line/arc/poly arms are the reference implementation for the
  bounds guard and the type-name spelling. **Do not modify them** (PLAN: out of scope).
* No new allocation is needed — `Tcl_SetResult(interp, (char *)get_tok_value(...), TCL_VOLATILE)`
  as `rect` does. So no `_ALLOC_ID_` question arises. C89: declare at block top, as the
  neighbouring arms do.

**The red row that already works, no fixture file needed** (the asymmetry, which is legible
and cannot raise):

```tcl
xschem line 0 0 100 0 -1 {}
xschem setprop line 4 0 probe 111
check "getprop line reads what setprop wrote" [xschem getprop line 4 0 probe] 111
#   today: {}    (rc 0, silent)   ->  tomorrow: 111
check "getprop line bad layer errors" [catch {xschem getprop line 99 0 probe}] 1
#   today: 0     (silent)         ->  tomorrow: 1
```

Same three lines for `poly` and `arc`. Both directions are red today and neither raises.

**Three decisions Stage B must make. My recommendation on each, none of them a user ruling
in my judgement except possibly the first:**

1. **Whole-string form.** Recommend **both**: implement *token omitted → return `prop_ptr`*
   for the three new arms **and** for `rect`/`text`/`wire` (which is candidate A as the spec
   words it, and what unblocks `list_tokens` for five types — the actual point of wish-list
   item 21), and additionally accept `allprops` as a synonym so the `setprop` spelling round
   trips. Adding `allprops` breaks nothing: it reads empty on every arm today, measured.
   ⚠ Making `getprop rect 4 0` stop erroring **is** a behaviour change to a shipped arm — it
   turns an error into a value. It is the change the spec asks for and the wish-list item
   needs, but the PLAN's Stage B scope says "close the gaps question 7 actually establishes",
   so it is the driver's call whether that is in this commit or a second one. **This is the one
   item I would put in front of the user**, because it is the grammar they will type.
2. **Unknown type name.** `getprop zzz` returns `{}` today while `object zzz` errors.
   Recommend **leaving it silent** in this commit and filing it — flipping it to an error is a
   behaviour change to the existing dispatcher, not a missing arm, and the PLAN forbids silently
   changing existing behaviour.
3. **Geometry pseudo-tokens** (`x1`, `r`, `points`, …) for the new arms. Recommend **no** —
   `text`'s `size` is the only precedent, it is undocumented, and geometry is not `prop_ptr`.
   Out of scope for item 21, which asks for *properties*.

**User-visible surfaces either way:** the new command grammar itself (the user writes Tcl and
asked for this), the `xschem getprop needs …` error message, the `getprop` doc block, and
`doc/xschem_man/developer_info.html` if regenerated. No dialog, menu, keybinding or status-bar
text is touched.

---

## What I got wrong during the stage, and what corrected me

1. **I initially accepted "no arm at all" as meaning "it errors".** The binary corrected me:
   `catch {xschem getprop line 4 0 fmt}` returns **0** with an empty result. Had I written the
   receipt from the code read alone I would have handed the implementer a red row that was
   already green-looking. Reading the `else if` chain and noticing it has **no terminating
   `else`** is what made me go and measure it.
2. **I assumed `setprop` had the same gap as `getprop`** and nearly wrote "neither direction
   works for line/poly/arc". A grep for `setprop` turned up `xschem_cmds_s()`'s own comment —
   *"these had NO setprop case at all (audit 0063 gap)"* — i.e. that gap was closed long ago.
   This reframes the whole item from "three types are unreachable" to "three types are
   writable but not readable", and it hands Stage B a much better red row.
3. **My first arc fixture silently created nothing.** `xschem arc 200 200 25 0 360` returned
   `1`, looked fine, and produced no arc — `setprop arc 4 0 k v` then errored "wrong layer or
   arc number" and that error is what exposed it. The layer is a mandatory 6th argument for
   `arc` and *not* for `line`/`rect`/`polygon`. Anyone writing the fence fixture will hit this.
4. **My first `xschem text` fixture wrote garbage** (`T {0} 0 300 300 0 0.4 0.4 {0.4}`) because
   I assumed the argument order from the record format. Reading `create_text()`'s call site
   corrected me. Not in scope, but recorded because the arg order is genuinely surprising.
5. I looked for `extract_scheduler_cmd_help.awk` expecting to run it and **it does not exist**,
   which is why I checked whether the HTML was stale instead of assuming it regenerates.

## What I did NOT do, and why

* **No file in the repo was changed** other than creating this receipt. No code, no commit, no
  `git` write of any kind.
* **I did not rebuild `src/xschem`.** Every measurement is against the binary as found (mtime
  2026-09-29 00:29, `b89fddda` is the checked-out HEAD and `git status` showed no modified
  tracked files). The brief's "no test harness builds" warning applies to audits meant as
  evidence; if the driver wants these numbers re-taken on a freshly built binary, every probe
  script is preserved under the scratchpad and re-runs in under a minute each.
* **No T1 run**, full or partial, and I did not run `test_getprop_index_bounds.tcl` — the brief
  reserves the gate for the driver and warns that hand-run suites can redden a live gate. I
  read the suite and its registration instead. **Unverified by execution:** that the suite
  currently passes. I only verified that it is registered in `hcases` and that its epilogue
  text matches `banner_complete`'s regex.
* **I did not touch Stage A's territory** — nothing about `ctrl+a`, `keybindings.csv`,
  `select.c`, or the waveform trace-selection model.
* **I did not verify `list_tokens`'s location at `token.c:308`** as the spec claims; I verified
  the *verb* works from Tcl, which is what Stage B depends on.
* **I could not settle** whether widening `getprop rect`/`text`/`wire` to a whole-string form
  belongs in this commit, because that is a scope/ratification question rather than a factual
  one. What would settle it: the driver deciding, or the user answering the single question in
  recommendation 1 above.
* **Unmeasured:** whether any shipped Tcl caller relies on `getprop <unknown-type>` returning
  empty rather than erroring. I did not exhaustively audit every `getprop` call site for a
  *variable* type argument; `/usr/bin/grep -n getprop src/*.tcl` showed only literal
  `instance`, `instance_notcl` and `symbol` types, which is suggestive but not a proof.

## Where the PLAN and the BRIEF are wrong

* **PLAN Q7's premise "Verify each of the nine".** There are **seven** arms and **ten**
  plausible names (the eight object families plus `instance_notcl` and `instance_pin`).
  `instance_notcl` is a *flavour* of the instance arm (one `with_quotes` value), not an
  object type, and `symbol` is not a drawable object. The count in the question is not a real
  set; the table above is.
* **PLAN Stage B, "which is expected to be arms for line, poly and arc, plus whatever rect /
  text / wire cannot currently report".** Correct as far as it goes, but it omits the finding
  that **`setprop` already has the three arms**, which changes both the framing (asymmetry,
  not absence) and the grammar question (the mirror is already decided by `setprop`).
* **PLAN Stage B, "Out of scope: … any change to `setprop`".** Fine as written, and now easy —
  nothing needs to change there. Worth noting the corollary: `setprop`'s own **doc block** does
  not document its line/arc/poly arms, so if Stage B fixes the `getprop` doc block it will leave
  a visible asymmetry in the shipped manual. That is a pre-existing debt, not Stage B's.
* **CREW_BRIEF, "`getprop` has arms for … rect / text / wire (token-only)".** Right for `rect`
  and `wire`; `text` also serves `txt_ptr` and the undocumented `size`.
* **CREW_BRIEF, "and **no arm at all** for line, poly or arc".** True of the dispatcher, but
  the brief's emphasis invites the wrong red row. The observable behaviour is a **silent empty
  success at rc 0**, for a bad layer as well as for a valid one.
* **The brief's ⚠ "A row must FAIL, not THROW" does not bite here** — nothing in the
  line/poly/arc path raises on the broken tree, so the red rows need no `catch` wrapper (the
  bad-index row *uses* `catch` as its assertion, which is the opposite direction).
* **`doc/claude/specs/property_introspection.md` needs the three corrections in Q12** before
  anyone builds from it; its line numbers are off by roughly 3200 lines.
