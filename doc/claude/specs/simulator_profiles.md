# Simulator profiles — exe, args, requested case mode, `-n`

Casemode batch **item 6**. Authority: `doc/claude/casemode_batch/DECISIONS.md`
**B1** (both halves), with **A1**'s requested-vs-measured split and **A2**'s
per-profile `-n`. `PLAN.md` §3b item 6. Companion spec:
`doc/claude/specs/raw_case_mode.md` §10 (the *file's* mode, and the global
floor).

Item 6 is the **model only**: the fields, their validation, their persistence,
and the ASE-L state key that names a profile. **No probe runs** (item 7), **no
run path changes** (item 8), **no widget exists** (item 13). Checks
`CS150`–`CS166` in `tests/headless/test_sim_profiles.tcl` — **82 of them**,
counted from a run, and every one of them has a mutation that drives it red.

> **Three defects were found in this item's own first cut and fixed here**, each
> measured before it was believed. They are recorded in place below rather than in
> a changelog, because each one is a rule somebody would otherwise re-break:
> §5's persistence guard shipped a value that made a user's whole `simrc`
> unsourceable (`CS153e`); §5's normalizer skipped exactly the row shape an
> ordinary `-n` user gets back out of their own `simrc` (`CS151g`); and §8's
> resolver read a `sim()` array that nothing had built yet (`CS163k`).

---

## 1. Why the existing `sim()` array, and not a registry

`PLAN.md` §3 proposed a new file, `$USER_CONF_DIR/ase_simulators`. **B1
overturned that**: xschem already has a simulator configuration system, and
building a second one beside it was wrong.

| what | where |
|---|---|
| GUI | `Simulation ▸ Configure simulators and tools` — `simconf`, `src/xschem.tcl` |
| settings file | `$USER_CONF_DIR/simrc` (typically `~/.xschem/simrc`) — plain Tcl, hand-editable |
| rc route | `cadence_style_rc` or any `--script` rc — plain Tcl, same globals |

The **actual** gap B1 identified is that ASE-L ignores all of it: `run_cmd`
(`src/ase.tcl:3360`, re-grepped) is one hardcoded line,
`return [list ngspice -b $deckpath 2>@1]` — a bare `ngspice` off `PATH`. Casemode
is one consequence of that, not the whole of it. Item 8 closes it; item 6 gives
it something to read.

**Why the fields are structured rather than parsed out of `cmd`.** Existing
`sim($tool,$i,cmd)` entries are free-form command *strings* with substitutions,
and one of the shipped defaults is

```tcl
set sim(spice,0,cmd) {$terminal -e {ngspice -i "$N" -a || sh}}
```

— ngspice **nested inside a terminal launch**. There is no reliable way to say
which token of an arbitrary shell string is the executable, so the row gains an
`exe` field instead of anyone trying.

## 2. The row shape

`cmd`, `name`, `fg`, `st` are **untouched** and keep driving the Simulation menu.
Six fields are added, in this canonical order (`sim_profile_field_defaults` is
the single source of truth; the normalizer, reader, writer, persister and tests
all walk that one list):

| field | default | meaning |
|---|---|---|
| `exe` | *empty* | the executable, a path or a bare name. Empty = **no profile executable**, i.e. today's behaviour. |
| `args` | *empty* | extra arguments, a Tcl list, composed after `exe`. |
| `casemode` | *empty* | the **requested** mode: `fold` \| `preserve` \| `distinguish`. Empty = this profile names none, and the global floor answers. |
| `detected` | *empty* | what the binary was **measured** to deliver: a subset of `{fold preserve distinguish}`. Empty = never probed = **unknown** (B2b). |
| `probed` | *empty* | provenance of that measurement: `{time <epoch> mtime <epoch>}`. Empty = never probed. |
| `nospiceinit` | `0` | A2's per-profile `-n` (`--no-spiceinit`). |

`exe`/`args` are stored **verbatim**, including a `$`, and are subject to the
same use-time `subst` the `cmd` strings already get (`simulate` does
`subst -nobackslashes $sim($tool,$def,cmd)`). That is why the persister braces
them exactly as it braces `cmd` — see §5.

### RULING — no built-in row gets an `exe`

Every shipped default row leaves `exe` empty (`CS151d`). Two reasons, both
practical: an empty `exe` means "behave exactly as before" (the menu runs `cmd`;
ASE-L falls back to a bare `ngspice`, item 8), and a populated default would make
a re-saved `simrc` differ from the one the previous xschem wrote, breaking §5's
byte-identity.

### RULING — `casemode` and `detected` are SEPARATE fields, permanently

A1 bars anyone from selecting a mode their simulator will silently ignore. That
is a comparison between a **request** and a **measurement**, so the two must be
storable independently — a single field cannot express "the user asked for
`preserve` and this binary was measured to deliver only `fold`", which is exactly
the state item 13's dropdown and item 8's mismatch policy (B4) both act on.
`CS156` asserts one such disagreement in a single assertion: `requested` is
`preserve` **and** `supports preserve` is 0.

### RULING — a row must always carry a `cmd`

`exe`/`args` do **not** replace `cmd`. The Simulation menu, `sim_is_ngspice`,
`sim_is_xyce`, `sim_is_vacask` and the C callers of `sim(spicewave,%d,name)` all
read the old fields, and an *older* xschem reading a new `simrc` has nothing else
to launch. Whoever adds a row (item 13's Add) owes it a `cmd`.

## 3. Requested mode = profile, then floor

B1 is "per profile, **with a global floor**". `sim_profile_casemode $tool $idx`:

1. the row's own `casemode`, if it is one of the three modes;
2. else the global floor `sim_case_mode` (`raw_case_mode.md` §10), if valid;
3. else `fold`.

The floor is validated here too, so a `set sim_case_mode sideways` in an rc
cannot become a request (`CS155d`). `unknown` is **not** a requestable mode
(`CS154c`): it is the absence of an answer about a *file*, never something to ask
of a run.

**The floor is the only place a mode is asserted without evidence**, and that is
deliberate and already ruled in `raw_case_mode.md` §10: a request about a run we
are about to make is not a claim about a file somebody else wrote. Nothing here
can leak into `xschem raw casemode`'s answer.

## 4. RULING — what a user may SELECT (`sim_profile_selectable`)

| `detected` | `probed` | selectable |
|---|---|---|
| non-empty | anything | exactly that, in canonical order — A1 |
| empty | **empty** (never probed) | **`fold` alone** |
| empty | non-empty (**measured**, delivers nothing we recognise) | **nothing** (`{}`) |

**The third row is a correction, and it was a real defect.** The first revision
keyed the fallback off `detected` being empty, so it could not tell "never
measured" from "measured and it delivers nothing" — and
`sim_profile_probe_record $tool $idx {}` is a documented, legal call meaning
exactly the latter. Measured on this tree: a freshly probed row (`stale=0`) was
offered `fold` by `sim_profile_selectable` while `sim_profile_supports … fold`
answered `0` in the same breath. Two procs of one item disagreeing about one
binary, with A1's rule broken for the *only* binary anybody had actually
measured. The fallback now keys off **`probed`**, and an empty answer is what
lets item 13's dropdown say "probed: no supported mode" instead of offering a
mode the model refuses (`CS156g`).

The second row is not an invention of a fact. `fold` is what a released ngspice
does whether or not it was asked — it accepts `-D casemode=preserve` and
**ignores it**, measured on `/usr/local/bin/ngspice` (46) — so `fold` is the one
request no binary can silently fail. Offering everything would violate A1;
offering nothing would make the field unsettable before a probe. This is also
what makes item 13's pre-fill *probe-driven rather than constant*, which is A1's
own consequence clause: probe, and the other modes appear.

`sim_profile_supports` answers **0 for every mode, including `fold`**, while
`detected` is empty (`CS156b`). "Unknown" is not a capability claim (B2b);
`selectable` is a UI affordance, `supports` is an assertion about the binary, and
they must not be the same function.

**Declared: one guard in `sim_profile_supports` is unreachable by construction and
no check can move it.** Its opening `if {![sim_casemode_valid $mode]} { return 0 }`
is redundant *today*, provably: `sim_profile_detected` filters the stored list
through the canonical three, so a mode outside them cannot be in `$d` and the
`lsearch` below already answers 0 for one. Deleting that line alone leaves the
suite green — driven, and recorded rather than papered over. It is kept as defence
in depth for the day `detected`'s filter changes; the accompanying check `CS156e`
asserts the *behaviour* (a non-mode is refused, a measured mode is accepted), not
that line. The two sibling guards the same review flagged — the `llength` arms of
`sim_profile_valid` for `args` and `detected` — turned out to be reachable after
all and are now driven by `CS154g`, in both the write and the read direction.

## 5. Persistence — and the two halves of backward compatibility

`save_sim_defaults` writes a profile field **only when it differs from its
default**, braced exactly like `cmd`/`name`:

```tcl
set sim(spice,2,exe) {$env(HOME)/dev/ngspice}
set sim(spice,2,casemode) {preserve}
```

**Half 1 — an old `simrc` read by new code.** A row from a `simrc` that predates
these fields carries `cmd`/`name`/`fg`/`st` and nothing else (the built-in
defaults branch is skipped entirely when a `simrc` exists), so
`sim_profile_normalize` runs on every route out of `set_sim_defaults` that built
the array **or changed a row count** (the ruling below) and gives every configured
row every field. Reads do not
depend on it — `sim_profile_get` is defensive — but item 13's widgets will, since
a Tk `-textvariable` on a missing array element creates it empty and would lose a
`0` default.

`tests/headless/fixtures/simrc_pre_casemode` was generated by the **pre-change**
`save_sim_defaults`, and `CS150` requires that loading it and re-saving it produce
**byte-identical** output; `CS150b` keeps that honest by asserting the fixture
mentions none of the new fields.

**Be exact about what `CS150` proves, because the first draft of this paragraph
was not.** The *post*-change `save_sim_defaults` emits these same bytes for a
default configuration — that is the property being asserted, so the fixture
cannot by itself distinguish "written before the change" from "regenerated
after it". `CS150` therefore asserts **determinism + additivity**: the new code
appends not one line to a row nobody configured (and, incidentally, that the
normalizer's row-count memo — an ordinary `sim` array element — never reaches the
file either). The genuine before/after evidence is a separate, manual step,
recorded in `receipts/06-simulator-profiles.md`: `src/xschem.tcl` swapped for
`git show HEAD:src/xschem.tcl`, a `simrc` generated with that pre-item-6
persister, `cmp` against the fixture — byte-identical — then restored and
md5-verified. Do not cite `CS150` as the before/after comparison; cite the
receipt.

#### RULING — the normalizer is UNCONDITIONAL; the guard belongs to its caller

`sim_profile_normalize` walks every field of every row, every time it is called.
It must not decide "this row is already shaped" from one field, and the first
revision of this item did exactly that — it probed the **last** field,
`nospiceinit`, on the stated grounds that the six are "only ever set as a group".

**That is false for the one route that matters, and it shipped a hole. Measured:**
the persister writes only what differs from the default, so a user who changed
nothing but A2's `-n` box gets a `simrc` row carrying `nospiceinit` **alone**; the
short circuit then skipped that row and left `exe args casemode detected probed`
missing on it for the rest of the session. Perfectly ordinary configuration.
`CS151g` drives it through a real save and reload, with the one-field shape
asserted in the same expectation so the check cannot go vacuous.

The cost that short circuit was buying is real — `set_sim_defaults` is the lazy
accessor `sim_is_ngspice`/`sim_is_xyce`/`sim_is_vacask` call per cross-probe, and
`xschem get_fqdevice` (`token.c`) reaches `sim_is_xyce` from a
`node="tcleval(…)"` attribute, i.e. from a **graph redraw**, which is item 3's
"never poll a walk from a redraw". So it is bought at the caller instead.

#### RULING (revised) — the caller's guard is a ROW-COUNT MEMO, not "did this call rebuild the array"

The first revision of the caller-side guard was `sim` absent, or `reset` — "did
this call **build** the array". **That was wrong, and it left the second
population route B1 and the item scope both name completely unshaped.** An rc —
`cadence_style_rc`, `~/.xschem/xschemrc` — calls `set_sim_defaults` and *then*
appends a row:

```tcl
set sim(spice,5,cmd) {ngspice -b "$N"} ; set sim(spice,5,name) {ver_50}
set sim(spice,5,exe) /home/qflow/dev/ngspice_test/build-ver_50/src/ngspice
incr sim(spice,n)
```

`sim` exists by then, so no later `set_sim_defaults` ever walked again — and every
reader is a later `set_sim_defaults` (`sim_is_xyce`, `sim_is_ngspice`, `simconf`,
`simulate`). **Measured:** that row kept `args casemode detected probed
nospiceinit` **missing for the whole session**, i.e. exactly the hazard the
normalizer exists to keep away from item 13's `-textvariable` widgets, and the
check that claimed to cover it passed only because the *test* called
`sim_profile_normalize` by hand — which no production path does once the array
exists.

The guard is now `sim_profile_normalize_if_changed`: it remembers the per-tool row
counts the last walk saw (`sim(profile_shape)`) and walks whenever they move. A
row can only become unshaped by *appearing*, and a row can only appear by moving
some `sim($tool,n)`, so this is complete for the property in question while
keeping the redraw path off the walk. The memo lives **inside the `sim` array** on
purpose: every route that resets the configuration does it by `unset sim`, so the
memo is invalidated for free, where a separate global would go stale and silently
skip the one walk that mattered. **Measured, 500 iterations with the array already
built and unchanged: 8.36 µs for the unconditional walk, 1.0 µs for the old
rebuild flag, 1.6 µs for the memo** (the walk itself is 19.6 µs, once per build
and once per row-count change). `CS151f` drives the rc route with **no** hand call
to the normalizer; `CS151i` drives the memo's two answers, so it cannot pass by
always walking or never walking.

**Half 2 — a new `simrc` read by an old xschem.** It cannot see anything new:
every reader of `sim` names its suffix explicitly (`cmd`, `name`, `fg`, `st`,
`n`, `default`, plus `sim(spicewave,%d,name)` and `sim(spicewave,default)` from
C in `hilight.c`, `scheduler.c` and `callback.c`), and **nothing in the tree does
`array names sim` or `array get sim`** — verified by grep. Extra elements are
unreachable, not merely harmless. Combined with "write only what differs", a
configuration nobody has touched produces a file with no new lines at all.

### Validation happens on WRITE and again on READ

`sim_profile_set` refuses an unknown field, an out-of-range row and an invalid
value. But a hand-edited `~/.xschem/simrc` is plain Tcl and **never passes
through the setter**, so `sim_profile_get` validates too and returns the field's
**default** for a value that fails — `casemode sideways` reads as "no mode
requested" and `detected {yes please}` as "never probed" (`CS154b`, `CS156f`).
The read half is the one that matters; a believed garbage value would become a
capability claim.

### RULING — the persistence guard is the ROUND TRIP, not `info complete`

One validation rule is about the file rather than the value. The writer emits
exactly one line per field,

```tcl
set sim(<tool>,<i>,<field>) {<value>}
```

so the only storable values are the ones that come back out of **that line**
unchanged **when the `simrc` is SOURCED**. `sim_profile_valid` therefore parses the
line as a list and requires three words whose third is byte-equal to the value. It
refuses an unbalanced open brace and a trailing backslash (`CS153d`) and still
accepts a `$`, a space, a newline and **balanced** inner braces (`CS153f`).

##### …and the list parse is not the whole round trip either

The list parse alone was the **second** revision of this guard, and it shipped the
same class of bug one layer down. `llength`/`lindex` are the **list** parser; the
`simrc` is read by `source`, the **script** parser; and inside braces those two
disagree on exactly one thing — the script parser performs one substitution,
**backslash-newline → space**, and the list parser performs none. **Measured end to
end through `save_sim_defaults` + `source`:** an `args` value of `x`, backslash,
newline, `y` (`78-5c-0a-79`) passed the guard, was written, and came back as `x`,
space, `y` (`78-20-79`), and a **second save then differed from the first** — so
the byte-stability `CS153f`/`CS158d` advertise broke on a value the guard had
accepted. A **bare CR** is the same defect by another route: channel translation
turns it into a newline on the way in (`78-0d-79` → `78-0a-79`, measured), so it
cannot survive either.

Both are refused outright. The lookalikes are **not**: a lone backslash and a bare
newline round-trip byte-identically (measured in the same probe), and refusing
them would turn the guard into a refuse-everything. `CS153g` asserts both
directions in one expectation, and `CS153f` remains the "a real value survives a
real save and reload" half.

**`info complete` was the first guard here and it is not this test.** Measured: the
three characters `a`, close-brace, `b` pass it — the braced form is "complete" —
so the value was stored and written, and sourcing the emitted line failed with
`extra characters after close-brace`, taking the **whole of `~/.xschem/simrc`**
with it. That is the precise failure the guard exists to prevent, and it was
shipped by the check that claims to cover it. `CS153e` now drives it; `CS153f` is
the acceptance half, so a guard that refuses everything cannot pass either.

Two notes for whoever touches this next. `cmd` and `name` have **no** such guard
and have carried the same hazard since long before this batch — left alone
deliberately, because changing what the shipped persister accepts is not item 6's
business. And a comment inside a Tcl proc body is still inside that body's
braces: an unbalanced brace in a comment *about* this defect aborted the source of
all of `xschem.tcl`, so both the code comment and the check build the value from
`\175`.

#### RULING — an invalid hand-edited value is DROPPED at the next save, not preserved

The persister reads through `sim_profile_get`, so a value a user hand-edited into
their own `simrc` that fails validation is **not written back**. Stated plainly
because it is user-visible and the first draft of this spec only implied it.
**Measured:** append `set sim(spice,2,casemode) {Preserve}` (capitalised) to a
generated `simrc`, reload, then save — as the dialog's *Accept, Save and Close*
does — and that one line is gone, the neighbouring `exe` and `nospiceinit` lines
survive, and the model answers `fold` with no warning anywhere.

The alternative was considered and rejected: writing the **raw** element back can
emit a line that makes the *whole* `simrc` unsourceable (`a`, close-brace, `b` is
the measured example two rulings up), which is strictly worse than losing one
field, and the value is by definition one the entire program already treats as
absent. The right place to *report* a typo is item 13's dialog, which has a user
in front of it; item 6 has no channel that is not a `puts`. `CS158g` pins the
behaviour, including that the valid field on the same row survives, so this is a
drop and not a wipe.

### `exe` is expanded — variables only

`exe` is stored verbatim so an rc can write `$env(HOME)/dev/ngspice` the way every
`cmd` string already does; without expansion `sim_profile_exe_path` answers `{}`
for a perfectly good profile and `sim_profile_probe_stale` then reports "stale"
forever. A profile field is **config data** — a hand-edited `simrc`, a shipped rc,
later a dialog — so asking *where the binary is* must not be able to run a
process, least of all from a redraw. An unset variable means "cannot locate", not
an error (`CS157j`).

#### RULING — `subst -nocommands` IS NOT A SANDBOX; this path uses no `subst` at all

The first revision used `subst -nocommands -nobackslashes` and said so in this
spec, in the code, and in `CS157k`. **All three gave false assurance.**
**Measured on Tcl 8.6.14:**

```tcl
set ::RAN 0 ; subst -nocommands -nobackslashes {$A([set ::RAN 1])/ngspice}
# -> error `can't read "A(1)"`, and ::RAN is now 1
```

Tcl still evaluates a `[…]` that sits inside the **array index** of a variable
substitution, because the index is parsed as a script word before the (suppressed)
command-substitution pass applies. Driven end to end on this tree: an `exe` of
`$env([exec touch <path>])/ngspice` **created that file during a pure staleness
query**, while `sim_profile_exe_path` returned `{}` and looked innocent. `CS157k`
passed throughout, because a *top-level* `[…]` is the one shape `-nocommands` does
suppress.

`sim_profile_expand_vars` replaces it: it walks the string and expands only
`$name`, `${name}` and `$name(index)`, resolving each through `set` at global
level; an index containing `[`, `]`, `$` or a backslash is **refused** with an
error rather than resolved. `CS157k` keeps the top-level case and `CS157l` adds the
array-index case, asserting the refusal *and* the absence of the side effect —
because `set` does not substitute inside a variable *name* either, so the side
effect alone would not prove which mechanism refused.

**The same hole is still open in `ase::expand_path`** (`src/ase.tcl`), which expands
**model paths out of a state file** with the identical
`subst -nocommands -nobackslashes`. It is pre-existing, its consumers are other
items', and changing model-path semantics is not item 6's to do — so it is left in
place, flagged in a comment at its own definition, and recorded here. Whoever owns
model paths next should route it through `::sim_profile_expand_vars` (or its own
equivalent) and can reuse `CS157l`'s shape as the check.

## 6. RULING — `sim_is_xyce` does NOT consult `exe`

It keeps reading the configured `cmd`, and only `cmd` (`CS160`, `CS160b`).

1. **Item 4 made it load-bearing.** `hilight.c`'s cross-probe senders resolve
   Xyce's uppercase spelling through it (`raw_case_mode.md` §11), on the stated
   grounds that a *sender* may trust configured identity where a *reader* cannot
   identify a file. Changing what it answers changes fold-vs-uppercase behaviour
   in C, four items after the fact.
2. **`cmd` is still what the Simulation menu runs.** `exe`/`args` are additive
   and drive ASE-L's run path (item 8). A row whose `cmd` launches ngspice in a
   terminal while its `exe` points at Xyce cannot exist today and can only be
   created by item 13; deciding what it means is item 13's business, not a silent
   side effect of adding a field.
3. If a later item wants exe-awareness, the shape is a **separate** predicate
   consulted by the run path, leaving the menu path's answer byte-identical.

## 7. Probe provenance, without a probe

`sim_profile_probe_record $tool $idx $modes` stores the **outcome** of item 7's
probe: `detected` (filtered to the known modes, canonical order) and `probed`
`{time <now> mtime <exe mtime>}`. It starts no process.

`sim_profile_probe_stale` answers 1 when the profile was never probed, has no
`exe`, has an `exe` that cannot be found, or has an `exe` whose **mtime has moved
since the probe**. It `stat`s a file; it never runs one. The mtime half is not
belt: the case-capable ngspice build moved **three times in four days** during
this batch (`LEDGER.md`), so a stale measurement is the normal case, and item 7's
own contract ("assert on `$curcasemode` and on measured output, never on 'this
build has fix X'") depends on knowing when a measurement went out of date.

## 8. The ASE-L state key `sim_profile`

ASE-L's part is only to **name** the row a session runs with. The mode itself is
*not* stored in the state file: it is a property of the binary, and a state
carrying its own copy would go stale the moment the profile changed.

```
sim_profile {tool spice index 2 name {Ngspice batch}}
```

- `schema_keys` gains `sim_profile` **right after `simulator`**, because it
  qualifies it (`CS161b`).
- `omit_if_empty` gains it too, and that is what keeps every state file written
  before item 6 round-tripping **byte-identically** (`CS165`, and `ST13` in
  `test_ase_cosim.tcl`). `version` stays **1** — `ase::state_load` merges the
  file over `ase::state_default`, so an old file gains the key with its default
  and keeps everything it had; the number is reserved for a change an old loader
  could *misread*.
- Two committed checks were **RESTATED, not renumbered**: "exactly the 16 schema
  keys" in `test_ase_core.tcl` and `test_ase_persist.tcl` are now 17. The
  closed-set property they exist for is unchanged; only the set is.

### `ase::sim_profile_resolve` — four statuses

| status | when | index returned |
|---|---|---|
| `default` | the state names no profile — every state file written before item 6 | the tool's own `default` row |
| `ok` | it names a configured row | that row |
| `stale` | it names a configured row whose `name` no longer matches the one stamped | that row |
| `invalid` | it names a tool or an index that does not exist | the backend tool's default row |

**Why `stale` exists.** Rows are addressed by **index**, and inserting a row
above silently re-points every state that stored one — the silent-wrong-answer
family this batch keeps finding. So `ase::sim_profile_stamp` records the row's
`name` beside the index, and a disagreement is reported rather than run blindly.
The index still resolves: item 8 decides whether to run it, item 13 whether to
offer to re-point it.

**Why `invalid` falls back instead of erroring.** A `simrc` the user edited must
not make a saved session unopenable. It says so in the status rather than
pretending.

#### RULING — the index is CANONICALIZED once it has passed validation

The stored index is used as an **array key**, and `string is integer -strict`
accepts non-canonical spellings: `02`, `-0`, and a value with surrounding
whitespace. Each of those passed the range test and then indexed
`sim(spice,02,…)` — an element that does not exist — while `resolve` reported
status **`ok`**, the one status item 8 is told it may run. **Measured:** with
`sim(spice,2,casemode)` set to `preserve`, a state naming `index 02` resolved `ok`
and `ase::sim_profile_casemode` answered `fold`; the session's requested case mode
silently lost, and reported as fine.

`resolve` therefore normalizes (`int($idx)`) before using the value as a key and
before returning it, rather than refusing: only a hand-edited state file can
produce such a spelling (we always write a canonical integer), and the rule for
one of those is the same as for `invalid` above — do not make a saved session
unopenable. `CS163l` pins it with `index 02`, including that the resolved mode is
the row's own.

### RULING — `resolve` builds the array it reads

`sim()` is **lazy**. Nothing populates it at startup; its five xschem readers
(`sim_is_ngspice`, `sim_is_xyce`, `sim_is_vacask`, `simconf`, `simulate`) each
open with a `set_sim_defaults` for exactly that reason. `ase::sim_profile_resolve`
now does too, and it is not belt: **measured**, a session that had not yet touched
the Simulation menu resolved a virgin state to **`index -1`** — "the tool's default
row" naming no row at all, out of a tool that has three, which item 8 would have
had to read as "no profile". 1.0 µs when the array is already there (`CS163k`).

The `sim_profile_*` accessors in `xschem.tcl` deliberately do **not** do this:
they are reached *from* `set_sim_defaults` (via `save_sim_defaults` →
`sim_profile_get`), and a lazy init down there would recurse.

`CS163k` also forced a piece of abort-proofing worth copying: with the lazy init
removed, the array stayed unset and the next checks' bare `$::sim(spice,2,name)`
raised, ending the file with **no `RESULT` line** — under which the sabotage reads
as "nothing went red". The suite now restores the array immediately after that
check. Same trap the ledger records from items 1, 2 and 5b.

### Two declared limits of `resolve`, neither fixed here

- A state may name a **row of another tool** (`{tool verilog index 0}` under
  `simulator ngspice`) and it resolves `ok`, because the row exists. Deciding
  whether a cross-tool profile is meaningful belongs to whoever composes an argv
  from it (item 8), not to a model that only records what was asked for.
- `stamp` on a row whose `name` is empty records an empty name, and the staleness
  test skips an empty stored name — so such a row can never report `stale`. Every
  shipped row has a name; a row without one can only come from item 13's Add,
  which owes it a `cmd` and a `name` anyway (§2's third ruling).

**The integer test on the index is load-bearing, not belt** (`CS163j`, found by
sabotage M34): Tcl's `<` and `>=` fall back to **string** comparison for a
non-numeric operand, and `2x` compares below `5` as a string, so a bounds test
alone would pass a non-existent row through as `ok`. There is deliberately **no**
separate "is this a valid dict?" guard: `dict exists` returns 0 for an invalid
dict rather than raising (measured, Tcl 8.6), so a malformed value reads as
"names no index" and lands on the same range check.

`ase::backend_tool` maps a backend name (`ngspice`) to the `sim(tool_list)` tool
whose rows configure it (`spice`), defaulting to `spice` because every backend
this file can register renders a spice deck.

## 9. No Tk

`src/ase.tcl` is sourced at startup and runs true-headless (`test_ase_core`), so
nothing here may reach for Tk. The whole of `test_sim_profiles.tcl` runs under
`--nogui`, and `CS166` adds a static guard: `info body` of all 22 new procs must
name no Tk command, with a missing proc landing in the same list so the check
cannot pass by finding nothing. `ase::sim_profile_casemode` calls
`::sim_profile_casemode` **absolutely qualified** — the two differ only in
namespace, and the relative name would resolve against `ase` first and recurse
forever, which is the same trap `ase.tcl`'s 56 `::ase::echo` call sites document.

## 10. What is NOT here

- **The probe** (item 7), including its mandatory hard timeout. `probed`/
  `detected` are storage for its answer.
- **`run_cmd`** (item 8): composing `exe`, `args`, `-n` and the requested mode
  into an argv, and B4's mismatch policy (`preserve` reports, `distinguish`
  refuses).
- **The dialog** (item 13): per-row exe/args/casemode widgets, the Test button,
  auto-probe gated on an `*ngspice*` filename (B3), and the probe-driven
  pre-fill. Every pixel is item 13's.
- **Any `cmd` rewriting.** Nothing derives a `cmd` from an `exe` or vice versa.

### RULING — `netlist_case_mode()` stays unwired, and this is where that is said

`save.c:netlist_case_mode()` returns `sim_case_mode_floor()` and its own comment
says it "exists so that item 6 has exactly ONE place to layer that on". **Item 6
deliberately does not layer it**, and the reason is not simply "no C in this item":

1. **It would change nothing today.** A profile whose `casemode` is empty resolves
   to the floor by definition (§3), and no shipped row carries a `casemode` — so
   the wired and unwired answers are identical for every configuration that can
   exist before item 13 gives anyone a way to set one.
2. **It would put behaviour where no consumer can exercise it.** The netlister
   question is item 14's, already committed and green; re-pointing its authority
   for zero observable difference is a change whose only possible effect is an
   audit row moving, against a batch contract of an empty audit diff.

So the layering point stays exactly one line, and this is the expression that goes
in it when a consumer needs it — the requested mode of the row the current netlist
type will actually launch:

```tcl
sim_profile_casemode $netlist_type [sim_profile_default_index $netlist_type]
```

Whoever wires it owns two things this item did not do: a `-1` index (a tool with
no configured row) and the fact that `netlist_type` is not always a `sim()` tool
name.
