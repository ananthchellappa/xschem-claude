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

---

# 11. The probe — casemode batch item 7

Item 6 built the model and started no process. **Item 7 starts it.** Authority:
`PLAN.md` §3b item 7, `DECISIONS.md` **B3** (the two probes, and "the probe needs
a hard timeout"), **A1** (the dialog offers only what the binary can deliver) and
**A2** (`.spiceinit` overrides, so ask the simulator instead of guessing). Checks
`CS167`–`CS172` in `tests/headless/test_sim_probe.tcl` — **49 of them**, counted
from a run; the whole file goes red when both source files are reverted to `HEAD`.

Item 7 is still **model plus mechanism**: it composes an argv, runs it, parses one
line and records the outcome through item 6's `sim_profile_probe_record`. It does
**not** touch `run_cmd` (item 8), it writes **no widget** (item 13), and it
delivers **no verdict** on a mismatch (B4 is item 8's).

## 11.1 RULING — there are TWO probes, and §3b's row blurs them

`PLAN.md` §3b item 7 says "**the capability probe** … cwd = **the deck's
directory**", which cannot be right as one sentence: at registration there is no
deck. `DECISIONS.md` B3 draws the distinction and says the plan blurs it —
"*B3 is only about the first*". So this item builds **one mechanism,
parameterised by cwd**, and names the two questions:

| | capability probe | run probe |
|---|---|---|
| asked | at registration (item 13's Add / **Test**) | immediately before each run (item 8) |
| question | "which modes can this binary **deliver**?" | "what mode will **this run** get?" |
| cwd | a **fresh empty directory**, created and removed | the **deck's own directory** |
| argv | the profile's `exe`/`args` (filtered, §11.2) /`-n`, plus `-D casemode=<m>` **per mode** | the same, `-D casemode=<requested>`, with `-exe`/`-args` overridable by item 8 (`CS173j`) |
| records | **yes** — `detected` + `probed` | **nothing** |
| entry point | `sim_profile_probe_capability` (`xschem.tcl`) | `ase::sim_probe_run` (`ase.tcl`) |

Both are needed and building only one would block an item: item 13 needs the
capability answer to build A1's dropdown, item 8 needs the run answer to apply
B4's policy.

**Why the run probe records nothing.** `detected` is a claim about a *binary*,
and item 13's dropdown is built from it. A run-probe answer is a fact about **one
directory** — a `.spiceinit` beside that deck can push it to `fold` — so storing
it would let one project's config permanently narrow what the user may select
everywhere else. `CS170i` pins it: after a run probe that measured `fold`,
`detected` still reads `fold preserve distinguish`.

**Where the code lives, and why not all of it in `ase.tcl`** (§3b's file column
says `ase.tcl`): the capability probe's caller is item 13's `simconf` dialog, in
`xschem.tcl`, and the thing being probed is a `sim()` row, whose whole accessor
layer item 6 put in `xschem.tcl`. So the mechanism sits beside the model, and
`ase.tcl` gets only the ASE-L-shaped wrapper that knows about states, rundirs and
deck paths. Same split item 6 used.

## 11.2 The transport — and the RULING that it is a batch deck, not the pipe

This item started from the shape `PLAN.md` F5 prescribes and the driver
re-measured minutes before dispatch:

```
$ printf 'echo CCM=$curcasemode\nquit\n' | ngspice -p [-n] [-D casemode=<m>]
```

It works, and **it is not what shipped**, because it needs a working **X
display**. Measured on this machine 2026-08-17, the identical command three
times:

| `$DISPLAY` | what ngspice `-p` does |
|---|---|
| `:0`, server out of client slots | `Maximum number of clients reached` / `Error: Can't open display: :0`, **exits without running our commands** — no answer at all |
| **unset** (headless server, CI box, remote sim host) | `ERROR: (external) no graphics interface;` and the process **DUMPS CORE** |
| `:99`, a live Xvfb | answers normally |

**This is not a hypothetical: it happened live inside this item.** A WSLg `:0`
filled up, and every real-binary check went from a clean `fold preserve
distinguish` to "unknown" — a binary that supports all three modes reported as
supporting none, which would have narrowed item 13's dropdown to `fold` because
an X server was busy. Exactly the silent-wrong-answer class this batch keeps
finding.

**So the probe runs a two-card batch deck instead**, written into a temp
directory of its own:

```
* xschem casemode capability probe
.control
echo CCM=$curcasemode
quit
.endc
.end
```

```
$ cd <the directory being asked about> ; $exe -b [args] [-n] [-D casemode=<m>] <abs deck path>
```

Measured with `-b`: identical answers with `$DISPLAY` unset, with `$DISPLAY`
exhausted and with a good one; and `-b` is also **nearer the real run**, which is
`ngspice -b <deck>` — A2 asks for the real argv. `CS170n` pins all three display
conditions in one expectation. The first line is a **title** on purpose: a deck
whose first line is a card loses that card silently, which killed a whole round
of this batch's earlier measurements (`CREW_BRIEF` §4); mutation **M37** removes
it and the real-binary checks go red.

**The deck never goes in `cwd`.** `cwd` is the question being asked — for a run
probe it is the user's own rundir — so the deck lives in a temp directory and is
deleted with it (`CS169p`). Measured, and it is what makes this possible:
**ngspice reads `.spiceinit` from the CWD** (and from `$HOME`), *not* from the
deck's directory, so an absolute deck path elsewhere costs nothing.

**The child's stdin is the null device.** Without that it inherits ours, and in
`--pipe` mode xschem's own stdin is the command channel: a simulator reading from
it would eat the commands driving xschem, and — since that channel never reaches
EOF — would then block until the deadline (`CS169q`).

### RULING — the profile's `args` are FILTERED before they reach a probe

`sim_probe_safe_args` drops two classes of word from the profile's `args`, and
both were **live defects found in review**, not theory. `sim_profile_valid`
cannot refuse either: any well-formed Tcl list is a valid `args`.

1. **Tcl exec redirection.** The argv is spliced into
   `open [list | $exe {*}$argv < $devnull 2>@1]`, which is exec *syntax*.
   Measured: `args {> zap.txt}` **created `zap.txt` in the probe's cwd** — the
   user's own run directory, for a run probe, which is precisely the leak
   `CS169p` guards the *deck* against — and returned `status error`;
   `args {| cat}` swallowed the answer, and the capability probe recorded that as
   "measured, delivers nothing", i.e. item 13's dropdown offering **no mode at
   all**. A bare operator (`>`, `<`, `2>`, `>>`, `>&`, `<@`, …) takes its
   filename word with it; an attached one (`2>/dev/null`) is one word; `|` and
   `|&` end the words that belong to this command.
2. **Output-directing simulator options** — `-o`/`--output`, `-r`/`--rawfile`,
   `--soa-log`, with their operands and `--opt=value` forms. `-r <raw> -o <log>`
   is the shape of an ordinary batch profile, and the run probe runs **in the
   deck's own directory**. Measured with the real `build-ver_50`: the probe
   **overwrote the previous run's `tb.log`** with its own two-line probe log,
   and — stdout now being in that file — answered `mode {}` for a binary that
   delivers all three modes. The same argv from a shell also **deletes** the
   named rawfile outright.

A probe wants the binary's identity and its `.spiceinit`/`-D` behaviour, never
the run's artifacts, so dropping these costs the measurement nothing.
`CS173`/`CS173b` drive the filter directly, `CS173i` drives the clobber with a
stand-in that writes its `-o` file, and `CS174` drives it end to end with a real
ngspice over a rundir holding `tb.raw`/`tb.log` (both byte-identical afterwards,
and the mode still comes back).

**DECLARED:** the option list is ngspice's, enumerated by hand. Another
simulator's equivalent needs adding. **Item 8's `run_cmd` must NOT inherit this
filter** — a real run's output files are the point; it inherits only the
redirection exposure, which is its own to handle.

The answers themselves, measured on `build-ver_50` (`Sat Aug 15 23:54`) and
`/usr/local/bin/ngspice` (46):

| binary / flag | the answer line |
|---|---|
| ver_50, no flag | `CCM=fold` |
| ver_50 `-D casemode=preserve` / `=distinguish` | `CCM=preserve` / `CCM=distinguish` (the latter behind an `experimental` warning banner) |
| ver_50 `-D casemode=sideways` | `Warning: unknown casemode 'sideways', using 'fold'` · `CCM=fold` |
| **stock 46**, with or without the flag | `Error: curcasemode: no such variable.` · **`CCM=`** |

**THE PARSING TRAP, kept even though the batch transport does not trigger it:**
in `-p` mode ngspice **echoes the command before answering it**, so the output
carries a literal `echo CCM=$curcasemode` line and "the first line containing
`CCM=`" reads back `$curcasemode`. Two independent defences, both in
`sim_probe_parse`: the answer must be a line that **starts** with `CCM=` (after a
`ngspice <n> -> ` prompt is stripped), and the value must be **letters only**,
which `$curcasemode` is not. They stay because every earlier note in this batch
records the pipe shape and because a future build may print an echo, a banner or
a prompt anywhere. `CS167`/`CS167b` carry both halves.

**`CCM=` with an EMPTY value is an ANSWER, not a silence** — see §11.4.

## 11.3 RULING — each mode is probed SEPARATELY (three invocations), not inferred

The cheap alternative was "if `$curcasemode` exists at all, the feature is
compiled in, so all three modes work" — one invocation. **Rejected**, and the
reason is measured rather than stylistic:

1. **`$curcasemode` reports the CURRENT mode, never the supported set.** A1's
   requirement is about what a **request** yields, so a request-versus-measurement
   comparison is the only thing that answers it.
2. **Item 3 measured a request that is silently ignored**: `-D CaseMode=` /
   `-D CASEMODE=` — a wrong-case **key** — leave `$curcasemode` at `fold` with no
   diagnostic, because it is a different variable, while a wrong-case **value**
   (`=PRESERVE`) works. Presence cannot see that class; asking for each mode and
   checking what came back can. `CS169h` drives exactly this shape with a
   stand-in binary that accepts every `-D casemode=` and always answers `fold`:
   the honest answer is `detected {fold}`, and the rejected design (mutation
   **M22**) reddens it by offering all three.
3. **A2's `.spiceinit` case has the same shape.** With one forcing `fold`, asking
   for `preserve` yields `fold`, so `preserve` is not deliverable *in this
   configuration* and A1 says it must not be offered.

Cost: three invocations, ~65 ms measured (21 ms each on `build-ver_50`); one
invocation for a binary with no casemode at all (§11.4's short circuit).
`PLAN.md` F5 recorded ~12 ms for the original probe, so this is the same order.

**The ruling is driven with NO simulator present, and that gap was real.**
`CS169h`'s `always_fold` stand-in answers `fold` whatever it is asked, so it
cannot tell "ask each mode" from "ask **one** mode three times": a mechanism that
asked the profile's single `casemode` three times — the rejected design wearing
three invocations — kept `CS169h` green and was caught only by the ver_50 legs,
which SKIP wherever that private build is absent. Two stand-ins close it by
reading `-D casemode=<m>` back out of their own argv: `CS173d` (echoes the
request → `detected {fold preserve distinguish}`) and `CS173e` (honours
`preserve`, silently downgrades `distinguish` → `detected {fold preserve}`, which
is the partial implementation A1 is actually about).

## 11.4 RULING — "no such variable" is an ANSWER, and it records `detected {fold}`

A released ngspice replies `Error: curcasemode: no such variable.` and prints
`CCM=` with an empty value. That is the **capability answer**, and the probe
records `detected {fold}`, `probed {time … mtime …}` — status `nocasemode`.

**Why this is not a B2b violation.** B2b rules that *absence of an answer* stays
`unknown`, permanently. Here the binary **answered**: it parsed our command and
named `curcasemode` as a variable it does not have. Both halves are required
before the claim fires — an empty value **and** an error line naming
`curcasemode` — so a program that merely prints `CCM=` (a truncated pipe,
something that is not ngspice) records nothing (`CS167e`, `CS169f`).

**Why `fold` rather than `{}`.** A1's consequence clause is explicit: *"No case
support ⇒ pre-fill `fold` and offer nothing else"*. Item 6's model expresses
"offer exactly fold" as `detected {fold}` (§4 row 1); recording `{}` would land on
§4 **row 3** — "measured, delivers nothing" — whose whole point is to offer the
user **nothing**, which is wrong for the ordinary `apt install` binary. The
`fold` half is measured twice, not assumed: `PLAN.md` F1/F5 recorded ngspice-46
folding for all four flag values, and this item re-measured
`/usr/local/bin/ngspice` accepting and ignoring `-D casemode=preserve`
(`CS171b`). **This is the one place the probe records a mode it did not watch a
run deliver**, and it is written here so nobody has to reverse-engineer it.

§4 row 3 stays reachable and is now driven for the first time: a binary that
answers `CCM=sideways` records `detected {}` with `probed` set, and
`sim_profile_selectable` answers `{}` (`CS169i`).

## 11.5 RULING — a TIMED-OUT leg never contributes a mode

A timed-out probe can carry a perfectly good `CCM=` line — measured with a
stand-in that answers and then blocks (`CS169j`: status `timeout`, parsed mode
`preserve`). The mode is still reported in the returned dict, and it is **not
recorded**:

* a process we had to **kill** did not complete a measurement, and B2b's rule for
  "no answer" is the conservative one;
* the fallback is byte-identical to today's behaviour — nothing recorded means
  `probed` stays empty, which item 6's §4 row 2 answers with `fold` alone;
* a probe that times out is a **defect signal** item 13 must show. `status`,
  `timedout` and `legs` carry it out for exactly that.

`CS169j` (a stand-in that answers, then hangs) and `CS170g` (a real ngspice that
hangs) pin it.

### RULING — and a TIMED-OUT LEG INVALIDATES THE WHOLE MEASUREMENT (`partial`)

The paragraph above was originally true only when **every** leg timed out, and
the mixed case — some legs answer, one stalls — was the sharper defect. Measured
with a stand-in that answers `preserve` and `distinguish` and sleeps on `fold`:

```
status = ok   detected = <preserve distinguish>   recorded = 1   stale = 0
```

`fold` — the global default, A1's pre-fill, and the one request no binary can
silently fail — was recorded as **not deliverable**, from one transient stall
(a loaded box, an NFS mount, a licence wait). And it is **worse than never
probing**: an unprobed row still offers `fold` (§4 row 2) and reads as stale, so
something re-probes it; a recorded row is not stale, so nothing ever does. The
returned `status` said `ok`, carrying no signal that a child had to be killed.

So an incomplete measurement is never recorded, and it says so:

| what happened | `status` | recorded |
|---|---|---|
| every leg completed, at least one answered | `ok` | yes |
| the binary said `no such variable` | `nocasemode` | yes (§11.4) |
| **some leg answered, some leg was killed or never started** | **`partial`** | **no** |
| nothing answered and something was killed | `timeout` | no |
| it ran and never answered | `unknown` | no |
| it could not be run | `error` | no |

`detected` in the returned dict still reports what *did* answer, as a display
value for item 13's "probe incomplete" case; the authority on whether it means
anything is `status`, and `timedout` is carried out beside it.

**The one exception is `nocasemode`**, which is a statement about the binary's
own variable namespace rather than a per-mode measurement: it settles the
question by itself and is recorded even if an earlier leg had to be killed.

`CS173f` drives the mixed case (`partial`, `recorded 0`, `probed` empty, `fold`
still selectable, still stale).

**The real binary's timed-out probe usually carries NOTHING**, which is a second
measurement in the same direction: a batch ngspice killed mid-run has flushed no
output at all — its stdout is block-buffered into the pipe, and `timeout 3` on a
deck whose `.control` blocks in `shell sleep` yields **0 bytes** (`CS170f`
asserts the empty parse deliberately). So under the shipped transport this ruling
costs nothing in the common case, and `CS169j` is what drives the case where an
answer *is* present and is discarded anyway.

## 11.6 RULING — the hard timeout is Tcl-native: deadline poll + kill

B3 makes the timeout **mandatory**, and there was no idiom in the tree to copy:
`ase.tcl`'s only exec is the blocking `exec {*}$cmd 2>@1`.

**The measurement that forced it**, re-taken 2026-08-17 on today's build, on the
pipe transport this item started from:

```
printf 'echo CCM=$curcasemode\n' | ngspice -p      # no `quit`
  -> still running at 8 s, 2.4 s user + 5.6 s system
```

So **EOF on stdin does not end an interactive ngspice** — closing our write end
was not a belt, `quit` was the only clean exit, and a hung probe is not even
idle, it **spins**. (The first attempt at this probe, during the decision
session, hung for two minutes. In a dialog that is a frozen window.)

**The batch transport removes that particular hang** — a deck ends at `.endc`
whether or not anyone says `quit` — and **the timeout is still mandatory**, for
two reasons that outlive the transport: B3 is a decision, not an optimisation;
and a simulator has other ways to block (a license checkout, an NFS stall, a
`shell` command in a `.control` block — which is exactly how `CS170f` hangs a
real ngspice for the drive).

Two acceptable routes; the choice and the reasons:

* **Chosen — non-blocking pipe + deadline poll + kill.** `open |… r`,
  `fconfigure -blocking 0`, `read`, `after 5` (which **does not process events**),
  compare against a deadline; on expiry kill the child, then close. Portable Tcl,
  no external tool, and **no event-loop re-entrancy** — which matters because the
  capability probe's caller is item 13's modal dialog and the run probe's is a run
  about to start; a `vwait` there would let another Test click, a window teardown
  or any other callback run *inside* the probe.
* **Rejected — `timeout(1)`.** Simple, but GNU/Linux-only, and this codebase
  ships on Windows (`XSchemWin/`).
* **Rejected — `fileevent` + `vwait` + an `after` cancel.** The portable-looking
  answer, and the re-entrancy above is why it is not used here.

**KILL BEFORE CLOSE — and the reason first written here was wrong.** The claim
was "`close` on a command pipeline waits for the child, so closing a hung probe
inherits the hang", with mutation **M14** (no kill) said to turn a 0.7 s deadline
into a two-minute call. That does not reproduce, because the channel is
`fconfigure -blocking 0` by then. Re-measured 2026-08-17 against a
`#!/bin/sh` + `exec sleep 40` child:

```
close on a NON-BLOCKING pipeline  ->  returns in 0 ms and DETACHES; the child is
                                      still alive afterwards
close on a BLOCKING pipeline      ->  waits for the child: 39702 ms
M14 (kill removed, shipped non-blocking channel), 700 ms deadline
                                  ->  returns in 705 ms, child survives
```

So the two facts are separate and both matter: **`fconfigure -blocking 0` is
load-bearing** — dropping it, or reordering the close ahead of it, is what would
make `close` inherit the hang and the timeout a lie — and **the kill is what
stops the child**, not what unblocks `close`. Without the kill the deadline still
fires on time and a spinning simulator is left running, which is the ~260-orphan
incident below; the term that reddens under M14 is `CS169b`'s `child=dead`.
`CS169b` asserts all three facts in one expectation — the deadline fired, the
call returned inside it, and the child is **dead**.

`sim_probe_kill` is the **one platform branch** in the probe. The unix arm
(`kill -9`) is driven by every timeout check; the **windows arm (`taskkill`) is
written from the documented interface and is UNVERIFIED** — there is no Windows
on this machine.

**DECLARED LIMIT — the kill reaches the child, not its grandchildren**, and this
one bit hard enough to be worth writing down. `pid $chan` gives the pipeline's
own process; if a configured `exe` is a *wrapper script* that starts the
simulator without `exec`, killing the wrapper leaves the simulator running.
Measured, by accident, during this item: an earlier test wrapper of exactly that
shape orphaned **~260 spinning `ngspice -p` processes** over a session, which
(a) drove the load average to 260 and made a full audit report bogus TIMEOUTs,
and (b) **exhausted the X server's client slots**, which is how the display
failure in §11.2 was discovered in the first place. A hung probe is not idle: it
spins, and it holds an X connection. The interactive transport is what made that
possible (a batch deck ends by itself), and a process-group kill is the real fix
if a wrapper `exe` ever becomes a supported shape.

**The same limit bit the test file itself**, and is worth recording because it is
the cheap half of the fix: the suite's hang stand-ins were `/bin/sh` scripts that
*ran* `sleep 120` instead of `exec`ing it, so every run of `test_sim_probe`
reparented **8 two-minute sleeps** to init — the ~260-orphan failure in miniature,
inside a suite `full_audit.sh` runs. They now `exec`, so the pid the probe kills
*is* the blocker. What remains is inherent: `CS170f` hangs a **real** ngspice with
`shell sleep`, whose `sh -c` is a grandchild the kill cannot reach; it is bounded
at 25 s instead of 60.

**The timeout is a ceiling, never a wait — and it bounds the WHOLE probe.**
`sim_probe_timeout` (`xschem.tcl`, `set_ne`, **5000 ms**) is ~240× a good probe.
An explicit argument beats the global beats the built-in default
(`CS168e`/`CS168f`).

It used to be **per leg**, which the text above did not say and which mattered:
`sim_profile_probe_capability` runs three sequential legs, the poll is `after ms`
with no event processing, and against a silent binary the interpreter therefore
blocked for **3 × 5000 = 15016 ms, measured** — while B3's entire reason for a
mandatory timeout is that item 13's dialog must not freeze. So the clock now
starts in `sim_profile_probe_capability`, each leg is given what is **left** of
it, and the loop stops when the budget is gone (the unstarted legs count as
incomplete, exactly like a killed one — §11.5). Re-measured at the shipped
default against the same silent binary: **5006 ms, `legs 1`**. `CS173g` pins the
bound and the leg count.

## 11.7 What the probe does to process state

`exec`/`open |…` cannot set a child's cwd, so the probe `cd`s, opens the pipe and
`cd`s **back before reading a byte** — `[pwd]` is process-global and the GUI
writes files relative to it. Every exit path restores it, including an
unreachable cwd, which is an `error` and not a probe (`CS169c`, `CS169e`).

Output is capped at 64 KB with a `truncated` flag; the channel keeps draining, so
a chatty binary cannot block on a full pipe and stall its own exit. **Not
driven** — declared.

**A temp directory name needs a counter, not a timestamp, and this was a real
bug.** `file mkdir` **succeeds silently on a directory that already exists**, so
two calls inside the same millisecond hand out the *same* directory — and the
second caller's cleanup deletes the first caller's. Measured: the capability
probe takes one for its cwd and each leg takes one for its deck, leg 1's cleanup
removed the cwd, and legs 2 and 3 then failed to `cd` into it — the probe
reported `error` for a binary that had just answered `fold`. `sim_probe_tmpdir`
now carries a per-process counter and refuses a name that exists; mutation
**M38** reverts it and reddens `CS170`.

**And the base is normalised**, because `$TMPDIR` is whatever the environment
says. A **relative** one (`TMPDIR=reltmp`) produced a relative deck path: the
deck was written correctly (that happens before the `cd`) but the child runs in
`cwd` and cannot open it. Measured with a stand-in that answers one mode when its
deck is readable and another when it is not — absolute `TMPDIR` → `preserve`,
relative → `fold`, with no error anywhere; a real ngspice would say "can't open
file" and the probe would report `unknown` for a perfectly good binary.
`file normalize` resolves against `[pwd]`, which is where a relative name would
have landed. `CS173c`.

## 11.8 The capability probe's cwd, and the layer nothing can exclude

The capability probe runs in a **fresh empty directory** (`sim_probe_tmpdir`,
`$TMPDIR`/`$TEMP`/`/tmp`), removed afterwards (`CS169l`), so that no `.spiceinit`
beside whatever the process's cwd happens to be answers for the binary.

`-cwd` overrides it, and that option is the whole of §11.1's "one mechanism,
parameterised by cwd" — a caller that wants the question asked *somewhere
specific* passes it. A caller-supplied directory is **never removed**; only a
temp directory the probe made itself is (`CS173h` asserts both halves, and that
the probe really runs there, with a stand-in that answers by what is in its own
cwd).

**It is still not a clean room, and this is measured, not theory.** A2 records
that `~/.spiceinit` — the **home** directory one — overrides `-D casemode=` just
as one beside the deck does, and it applies from **any** cwd:

```
.spiceinit beside the deck says fold, -D casemode=preserve  ->  fold
   the same, plus -n                                        ->  preserve
no .spiceinit anywhere,               -D casemode=preserve  ->  preserve
HOME/.spiceinit says fold,            -D casemode=preserve  ->  fold
```

(all four re-measured on today's build; `CS170c`–`CS170e`). So a capability
answer means "what this binary delivers **for this user, as configured today**",
which is also the answer A1 wants — a mode the user cannot actually obtain must
not be offered — and it is why the run probe exists as well. A user who knows
their `.spiceinit` is the problem turns on A2's per-profile `-n`, which reaches
both probes (`CS169o`, `CS170k`).

**How the `~/.spiceinit` layer is tested without touching a developer's home
directory:** ngspice honours `HOME` (measured), so the check points `HOME` at a
scratch directory for the duration and asserts the override **and** the control
answer with the real `HOME` in the same expectation (`CS170e`). Nothing in this
item ever writes to `~`.

`CS170e` used to carry a `home_restored=` term as well, and `CS170n` a
`display_restored=` one; **both were dropped, because neither could fail**. Each
re-read a variable the test itself had assigned two lines earlier, with no
product code in between that can touch it (nothing in the probe writes
`::env(HOME)` or `::env(DISPLAY)`; `sim_probe_tmpdir` only *reads* `TMPDIR`). They
read as environment-safety evidence and were bookkeeping. What does notice a
missed restore is the **control** probe in the same expectation: it re-asks with
the real `HOME` and requires `preserve` back.

## 11.9 B3's auto-probe gate

`sim_profile_probe_autoprobe_ok` answers 1 only when the executable's **filename**
contains `ngspice`, case-insensitively — B3's rule, for B3's reason: `casemode` is
an ngspice feature, so nothing else can answer, and this is what stops xschem
auto-launching a **licensed** simulator (Spectre, a commercial Xyce) that may
check out a license or take seconds to start, merely because somebody typed a
path into a dialog. Everything else gets the deliberate click of item 13's
**Test** button.

It reads `file tail`, not the path: a `Xyce` binary living under a directory
called `ngspice_builds` must **not** be auto-launched (`CS169k2`).

## 11.10 The ASE-L run probe

`ase::sim_probe_run $state ?-deck <path>? ?-cwd <dir>? ?-exe <path>? ?-args <l>?
?-timeout <ms>?` resolves the state's profile (item 6's `sim_profile_resolve`),
takes the **requested** mode from it, and probes with the run's own argv from the
**deck's own directory** (`-deck` supplies it; `-cwd` wins; otherwise
`ase::rundir`). It returns the measurement and **no verdict**:

```
tool index profile_status requested mode delivers agree answered status ms argv cwd out …
```

`mode` is the raw parse. **`delivers` is the mode this run will actually get**,
and `agree` compares it against `requested`; both are `{}` when nothing was
measured — B2b again: no answer is unknown, never `fold`. **B4's policy** —
`preserve` mismatch reports and continues, `distinguish` mismatch **refuses** — is
item 8's, and deliberately absent here; item 8 drives it off `delivers`/`agree`.

### RULING — `nocasemode` is a MEASURED delivery of `fold`

`delivers` exists because `mode` alone got the commonest real case wrong. A
released ngspice replies `Error: curcasemode: no such variable.` + an empty
`CCM=`; `mode` is then `{}`, and `agree` used to be `{}` too — documented in this
section as "nothing was measured". Measured, with `/usr/local/bin/ngspice` and a
real deck:

```
requested=preserve      status=ok  mode=<>  nocasemode=1  agree=<>     (before)
requested=distinguish   status=ok  mode=<>  nocasemode=1  agree=<>     (before)
```

`distinguish` against a binary that cannot do it is exactly the case B4 tells
item 8 to **REFUSE**, and the run probe was handing it "unknown". Worse, the two
halves of this item disagreed about the same bytes: §11.4 records that reply as
`detected {fold}` — an **answer**. So when `status` is `ok` and `nocasemode` is
1, `delivers` is `fold` and `agree` is `requested eq fold`. `CS173k` drives both
directions (a `distinguish` request → `agree 0`, a `fold` request → `agree 1`).

**It does not reimplement `run_cmd`'s fallback.** ASE-L today runs a bare
`ngspice` off `PATH` when a profile names no `exe` (`ase.tcl`, item 8's line to
change). A profile with no `exe` therefore returns status **`noexe`** rather than
guessing at an executable this item does not own; item 8 passes `-exe` for
whatever it is really about to run (`CS170l`).

## 11.11 What is NOT here

- **`run_cmd`** and B4's mismatch policy — item 8. Untouched: `ase.tcl`'s
  `run_cmd` is byte-identical.
- **Every pixel** — item 13: the Test button, the auto-probe on Add (this item
  ships only the *predicate*), the probe-driven pre-fill and the dropdown built
  from `sim_profile_selectable`.
- **`-D` for anything but `casemode`.** The probe composes exactly `-b`, the
  profile's `args` (filtered, §11.2), `-n`, `-D casemode=<m>` and its own deck
  path.
- **Any use of `ase::expand_path`.** Issue `0422` (a command substitution inside
  an array index runs during a *path* expansion) is pre-existing and unfixed; no
  probe path routes through it. `exe` is expanded by item 6's
  `sim_profile_expand_vars`, which refuses that shape.
- **Windows.** The `taskkill` arm, the `NUL` null device and the
  `C:/Windows/Temp` fallback are written, not measured.
- **The pipe transport is gone, not kept as a fallback.** A build too old to run
  a `.control` `echo` in batch mode would need one; none is in reach to measure,
  and a second transport nobody can exercise is worse than one that is driven.

---

# 12. The profile-aware run, and B4's mismatch policy

Casemode batch **item 8**. Authority: `DECISIONS.md` **B1** (the command is
built from the profile), **A2** (no `-n` by default; probe with the real argv
and run in whatever mode came back), **B4** (requested ≠ measured: `preserve`
reports and continues, `distinguish` **refuses**). `PLAN.md` §3b item 8.
Item 6 owns §1–§10, item 7 owns §11, this item owns §12. Checks
**`CS175`–`CS191`** in `tests/headless/test_sim_run_profile.tcl` — 38 of them,
counted from a run, every one with a mutation that drives it red.

Items 6 and 7 built a model and two probes that **no run consulted**. Until this
item `ase::backend::ngspice::run_cmd` was one line:

```tcl
proc run_cmd {state deckpath} { return [list ngspice -b $deckpath 2>@1] }
```

A bare `ngspice` off `PATH`, so ASE-L could not be pointed at a specific
simulator at all. Casemode is one consequence of that, not the whole of it.

## 12.1 The composed command

```
<exe> -b <profile args…> [-n] [-D casemode=<mode>] <deckpath> 2>@1
```

| word | source | rule |
|---|---|---|
| `exe` | `sim_profile_exe_path` | the resolved row's executable, else the bare `ngspice` this proc has always used. A row that **names** an exe we cannot locate never reaches here — §12.4 refuses. |
| args | the row's `args` | run-filtered by `ase::run_safe_args` (§12.2). Every option survives **except the `-o`/`--output` family**, which takes away the stdout ASE-L parses; `-r`/`--rawfile`/`--soa-log` are kept. Anything dropped is **reported** (§12.7). |
| `-n` | the row's `nospiceinit` | **off by default** (A2). This item is the first consumer of item 6's field; item 13 owns the checkbox. |
| `-D casemode=` | the requested mode | only when the request is **not** `fold` (§12.3). |
| `2>@1` | `run_cmd`'s own | folds stderr into the captured log, as before. A profile cannot unfold it: the filter drops redirections. |

The word order mirrors `sim_probe_argv`'s (§11.2) so the measurement describes
the run.

### RULING — the compatibility contract is a CHECK, not a hope

With no profile configured the composed list is **byte-identical** to
`[list ngspice -b $deckpath 2>@1]`, the literal it replaced. `CS175` compares
against that literal — and composes a *configured* row in the same assertion, so
it cannot pass by the feature being absent. This is what keeps the batch's
empty-audit contract intact: nothing below is reachable until a row carries an
`exe`, `args`, `nospiceinit`, or a `casemode` other than `fold`.

## 12.2 RULING — the run filter is NOT the probe filter, and must never become it

`sim_probe_safe_args` (§11.2) drops redirections **and every output-directing
option**. Every one of its reasons is about a *probe*: a probe may have no side
effects, so `-r`/`-o` had to go because they made the run probe overwrite the
previous run's outputs, and `> zap.txt` had to go because it wrote a file into
the probe's cwd — the user's own rundir.

**A real run legitimately needs `-r`.** That is xschem's own shipped batch shape:
`sim(spice,2,cmd)` — "Ngspice batch" — is `ngspice -b -r "$n.raw" "$N"`
(`src/xschem.tcl:4086`). Inheriting the probe's filter here would break
configured simulators for a reason nobody could find. `CS177c` reads both
filters on the same words (`-r`, `--rawfile`, `--soa-log`) and fails if they
ever agree about one.

> **Correction, recorded because it was load-bearing.** The first version of
> this ruling cited `sim(spice,1,cmd)` as `ngspice -b -r "$N.raw" -o "$N.out"
> "$N"` and used it to justify keeping `-o` as well. **No such row exists in
> this tree.** `sim(spice,1,cmd)` is `{ngspice "$N" -a}` ("Ngspice Control
> mode"), the batch row is `sim(spice,2,cmd)` above, and `grep -rn '\$N\.out'
> src/` matched nothing but that comment itself. xschem ships **no `-o`
> anywhere**. Once corrected, the surviving justification covers `-r` only —
> and `-r` is also the only one of the two that measures harmless.

`ase::run_safe_args` therefore drops two classes, and neither is a preference.

**(A) Exec-syntax words** — `execute` does `open "|$args"`, so these are not
arguments at all:

1. `>` `>>` `2>` `>&` … : ASE-L reads the run's output back out of
   `execute(data,$id)` and writes it to the log; a redirection silently empties
   that, so the log is written **empty** and `result_probe` finds no values — a
   run that looks fine and reports nothing.
2. A **bare** redirection operator additionally **eats the next word** as its
   filename. `run_cmd` appends `$deckpath` last, so a trailing `>` would consume
   the deck and ngspice would run with **no deck at all** (`CS177b`).
3. `|` / `|&` splice a foreign program into a pipeline we then report to the user
   as "the simulator", and everything after one was written for another program,
   so it goes too. `&` goes as well — **not** because it could background the
   run (an earlier draft of this comment said so and was wrong: `&` only
   backgrounds a Tcl pipeline as the **last** word, and `run_cmd` always appends
   the deck and `2>@1` after the filtered args), but because ngspice would
   otherwise be handed a literal `&` as an argument. `CS177`'s word list carries
   one.

### RULING — `-o` / `--output` is dropped too, and that is a measured carve-out

This is the one **simulator option** the run filter removes, and it is removed
for the same reason as class (A)(1) reached by a different route: `-o` sends the
stdout ASE-L parses to a file.

| | measured, 2026-08-17, real `/usr/local/bin/ngspice`, deck `v1 a 0 1 / r1 a 0 1k` |
|---|---|
| `ngspice -b d.cir` | `v(a) = 1.000000e+00` on **stdout** |
| `ngspice -b -o o.log d.cir` | stdout carries only `Comments and warnings go to log-file: o.log`; the numbers are in `o.log` |

Driven through `ase::run_deck` + `ase::wait` with a profile row carrying
`args {-o <rundir>/out.log}`, the second shape exits **0**, writes a
banner-only `<cell>_ase.log`, and `ase::last_result` comes back **EMPTY** with
no diagnostic — exactly the "runs fine and reports nothing" failure the filter
exists to prevent. `--output=<file>` behaves identically. The controls
`-r extra.raw` and `--rawfile=z.raw` were driven the same way and still yield
`va 1.000000e+00`, so this is a one-option carve-out, **not** a return to the
probe's filter (`CS186`).

All three spellings go: `-o <file>` (with its operand), `--output <file>`,
`--output=<file>`, `-o<file>`. **Declared:** the list is ngspice's, enumerated,
not derived, and it assumes `-o` is the only ngspice short option beginning with
`o` — true in ngspice 46 (`-b -s -i -n -t -r -o -p -q -a -D -h -v`).

**A dropped word is reported, never silent** (§12.7): the user typed it into a
profile field and it is not reaching the simulator (`CS186b`).

## 12.3 RULING — `-D casemode=` is emitted only for a request that is not `fold`

`fold` is what every user gets by default (A1, and `set_ne sim_case_mode fold`).
Appending `-D casemode=fold` to every ASE-L run forever would buy nothing:

| | measured |
|---|---|
| released ngspice-46 | **accepts and ignores** `-D casemode=` (A1) |
| `build-ver_50`, no `-D` at all | `CCM=fold` — the case-capable build already defaults to fold (measured 2026-08-17, `.control` `echo CCM=$curcasemode` under `-b`) |
| any binary, with a `.spiceinit` | `.spiceinit` **overrides** `-D casemode=`, beside the deck and in `$HOME` (A2) — so the flag cannot even enforce it |

What it *would* buy is a changed command line for every existing user, which is
the one thing §12.1's contract forbids. `CS176c` pins both directions.

**The global floor counts as a request.** `sim_case_mode` is documented as "the
mode we ask a simulator for when no simulator profile names one", so an rc that
sets it to `preserve` yields `-D casemode=preserve` with no profile row at all —
B1's "per profile, with a global floor" (`CS176d`).

## 12.4 RULING — a row naming an exe we cannot locate is a REFUSAL, in every mode

Not a fallback. Falling back to the bare `ngspice` off `PATH` would silently run
a **different simulator** than the one configured — which under a
`preserve`/`distinguish` request is exactly the silent substitution B4 exists to
prevent, and even under `fold` is not the simulator the user chose. With
`build-ver_50` having moved three times in four days, "the configured exe is
gone" is the normal case here, not an edge case. `CS180` drives it under a
**`fold`** request specifically, because the mode gate must not reach this check.

## 12.5 B4's policy, and what REFUSE means concretely

`ase::run_casemode_verdict` is a **pure function** of a request and item 7's
measurement, so the ruling is drivable without launching anything:

| requested | measured | action |
|---|---|---|
| `fold` (or none) | anything | **ok** — never reports, never refuses |
| `preserve` | `preserve` | ok |
| `preserve` | anything else, **or nothing** | **report**, and continue |
| `distinguish` | `distinguish` | ok |
| `distinguish` | anything else, **or nothing** | **REFUSE** |

**Why the split** (it overturned a flat "run and report"): a `distinguish`
downgrade means the simulator **merges nets the user deliberately kept
separate** — the same deck file, a *different circuit*. The run exits cleanly
and the numbers are wrong, the silent-wrong-answer class A1 was chosen to avoid;
and on a stock binary the merge is completely **silent**, because the
fold-collision warning does not exist there. A `preserve` downgrade is cosmetic:
same circuit, same numbers, lower-case labels.

### RULING — "not confirmed" is a refusal under `distinguish`

A timeout, an unlocatable executable, a probe that errored: none of them
*confirm* anything, and B4's clause is "confirmed to support it", not "not known
to fail". This is the clause that catches B4's own third route — **the binary
changing under the path** — because a moved `ver_50` probes as `noexe`
(`CS178c`). The other two routes B4 names are covered by the same probe: a
hand-edited `simrc`/rc naming a mode the binary cannot do, and a `.spiceinit`
override, both show up as a measured `delivers` that is not the request.

### RULING — a mismatch that is not a `distinguish` REQUEST reports, never refuses

B4 scopes the refusal to the *request*, and that is where the harm is: only a
`distinguish` request states "these nets are different", so only its downgrade
merges anything. The reverse — asked `fold`, got `distinguish` from a
`.spiceinit` — cannot merge nets; it can only split them, which shows up as an
absent vector rather than as a wrong number, and item 10's pre-flight owns that.

### What REFUSE means, concretely

Refusing after the deck is written, refusing before anything is generated, and
letting the run start and killing it are three different things. This is the
**second**: `ase::run_precheck` is called from `ase::run_deck` **before its first
`open`** — before the netlist is read, before the cosim VCDs are deleted, before
any `.so` is rebuilt, before the deck is written. A refusal therefore leaves:

- **no deck, no raw, no log, no VCD deleted, no `.so` rebuilt**, no process
  started, no `last_run` update, no completion callback;
- the previous run's files exactly as they were, and **the message says so** —
  it names the run directory and states that anything in it is from an earlier
  run (`CS181`, `CS181b`).

Item 10 is about a file that *looks like* a result (the twelve-constants raw);
this must not manufacture a new instance of that class, and a refusal that
writes nothing cannot. The one artefact that *has* been produced when
`ase::run` is the entry point is the circuit netlist `<rundir>/<cell>.spice`,
regenerated by `ase::netlist` before `run_deck` is reached — a **source**
artifact, never a result.

**The "no VCD deleted" half of that list is pinned by a check, not only by
words** (`CS190`). Two procs a few lines below the gate would break it if the
gate ever moved: `ase::cosim_save_map` **deletes** the sidecar
`<rundir>/<cell>_ase.cosim` when the map is empty, and
`ase::cosim_clear_artifacts` deletes every VCD the deck promises. Moving the
gate to just after `cosim_clear_artifacts` leaves `CS181` green and destroys the
previous run's cosim map; `CS190` drives a refusal against a netlist carrying a
real `d_cosim` card with both artefacts planted, and is the check that notices.

### RULING — the advice clause must name a lever that EXISTS

The refusal and report messages end with what to do about it, and on the
global-floor path (`status default` — no profile row at all, the request coming
from `sim_case_mode` in an rc) "point the profile at…" and "turn on the
profile's `-n`" name **a profile the session does not have**. So the clause
branches on the resolve status: with no row the message names `sim_case_mode`
and offers configuring a profile instead (`CS188`, which drives the floor path
with a real refusal and a real report and asserts the string does *not* say
"the profile's -n" — that leg had no coverage at all before).

The user sees the refusal as a red CIW line **and** as the error raised to the
caller. `ase_window.tcl`'s Run button (`do_run` / `do_run_existing`) catches
that error, echoes it `error` and turns the session status red — so in the GUI
the refusal line appears **twice**, once from the gate and once from the UI's
own catch. That duplication is deliberate rather than unnoticed: the gate's echo
is the only channel a *scripted* or headless caller has (and the only one that
reaches the action log at all when the caller swallows the error), and a refusal
is worth saying twice. Item 13 may dedupe it in the UI; nothing here may drop
the gate's copy.

## 12.6 RULING — the gate is armed only by a non-`fold` request

The probe costs up to `sim_probe_timeout` ms and runs immediately before the
run. It is skipped entirely for a `fold` request, which is every user who has
configured nothing. A1 is explicit: the mismatch warning "never fires for a
stock user — only for someone who deliberately requested a mode and did not get
it". `CS179d` reads the stand-in's own launch log, so it measures the launches
rather than an absence of output.

**Declared consequence:** a `.spiceinit` that turns a `fold` request into
`preserve` or `distinguish` is **not detected**. Detecting it would mean probing
every ASE-L run forever to compare `fold` against `fold`.

**The `exe` check of §12.4 is not gated on the mode** and runs on every
profile-composed run. Neither is the resolve-status report (§12.9) nor the
dropped-args report (§12.2): both are about a command that is not the command
the user configured, which is a harm independent of the mode.

### The probe's cwd is the RUNDIR, and that is a check now

A2's whole detection route is a `.spiceinit` **beside the deck**, so a probe
asked from anywhere else cannot see it. `ase::run_precheck` passes
`-cwd [ase::rundir $state]`, and `CS189` is the only assertion in the file that
can notice: its stand-in answers `CCM=fold` when a `.spiceinit` is in **its own
cwd** and `CCM=distinguish` when it is not, so with the marker planted in the
rundir a `distinguish` request REFUSES and without it the same row runs. Every
other stand-in in the suite answers the same mode from any directory, which is
why mutating the cwd used to leave the suite green.

### RULING — the policy applies only where the ngspice composer runs

`ase::run_composes_profile` compares the backend's `run_cmd` **hook identity**
against `::ase::backend::ngspice::run_cmd`. The policy describes exactly what
that proc builds, so it may only be applied where that proc is the composer: a
test backend with its own `run_cmd` (`test_ase_core` E2) hardcodes its own binary
and reads no profile, and a refusal about a profile exe it never runs would be a
lie. A sixth registered hook was rejected — `register_backend` requires all five
it knows, so adding one would break every already-registered backend.

The guard is driven **at the call site**, not only as a predicate: `CS180c`
tests `ase::run_composes_profile`, and `CS191` registers a second backend with
its own `run_cmd`, gives the *spice* profile an unlocatable `exe`, and asserts
`ase::run_deck` on that state runs to exit 0 without a refusal and without a
casemode line on the CIW. Deleting the guard (`if {1}`) leaves both
`test_sim_run_profile`'s predicate check and `test_ase_core` green, so `CS191`
is the one that notices.

## 12.7 The report reaches the CIW **and** the run log

§3b says "report in the log and the CIW". Item 14 found the hard way that a
channel can be **correct and still reach nobody** (its ERC window opens only on
error, so a warn-level diagnostic went nowhere). So both, and neither is
conditional on a window being open:

| channel | when | how |
|---|---|---|
| CIW pane | immediately, **before** the simulator starts | `::ase::echo … note` (dark orange) for a report, `… error` (red) for a refusal |
| action log (`Xschem.log`) | same call | `ase::echo`'s file half, `xschem log_action -result\|-error` |
| **the run log** `<rundir>/<cell>_ase.log` | when the run finishes | `ase::run_done`'s new optional `notes` argument, **prepended**, on its own line |

**Three kinds of line use those channels**, all assembled by `ase::run_precheck`
and all returned to `run_deck` as one newline-joined `notes` block:

1. the **casemode mismatch** report (B4's `report` verdict) — this section's
   original subject;
2. the **resolve-status** report (§12.9), when the row that will run is not the
   row the session stamped;
3. the **dropped-args** report (§12.2), naming the words the run filter removed.

(2) and (3) are emitted for a `fold` request too, so the `fold` early return
carries the accumulated notes rather than `{}`.

The run log half can only happen in `ase::run_done`, because that proc
**overwrites** the log with the captured output. The note goes **first**: a
mismatch is a statement about the whole run, and the head of the file is the one
place a reader who scrolls nothing at all still sees it. `notes` defaults to `{}`
so an ordinary run's log is byte-identical to before **and** a caller that
predates the parameter still works (`CS183`); `CS182` reads the note back out of
the log after a real `execute`, and `CS182b` is the control.

## 12.8 What is NOT here

- **`sod_expr`** (item 9), the **pre-flight / `$sim_status` guard / constants-raw
  rejection** (item 10), **`result_probe -nocase`** (item 11), **post-load
  current repair** (item 12), **every widget** (item 13). `render_deck` is
  byte-identical: this item changes the **command**, not the deck.
- **No real simulator is in the test.** Every launch is a `/bin/sh` stand-in, so
  the suite needs no ngspice and has no skip arm to mis-score. Two measurements
  were taken by hand against real binaries and are recorded rather than
  asserted: §12.3's "`build-ver_50` with no `-D` yields `CCM=fold`", and
  §12.2's `-o` table plus its end-to-end drive through `ase::run_deck` on
  `/usr/local/bin/ngspice` (`-o` → empty `last_result` before the fix,
  `va 1.000000e+00` after; `-r`/`--rawfile` unaffected either way).
- **The probe's argv and the run's argv differ by exactly `-r` / `--rawfile` /
  `--soa-log`**, because the probe filters those and the run keeps them. (`-o`
  is no longer part of that gap: both filters drop it, for different reasons.)
  Nothing about those options can change a case mode, so A2's "probe with the
  real argv" is honoured in substance; it is stated here rather than hidden.
- **`ase::expand_path` is untouched** — issue `0422`, pre-existing. `exe` is
  expanded by item 6's `sim_profile_expand_vars`, which refuses that shape; no
  new path routes through `expand_path`.
- **The refusal does not delete the previous run's artefacts.** Deleting a user's
  results because a *new* run was refused would be worse, and item 10 owns
  recognising a bad artefact on read. What this item owes — writing nothing new —
  it does.


## 12.9 RULING — a `stale` or `invalid` resolve is REPORTED, not refused

§8 states that `ase::sim_profile_resolve` returns four statuses and that "the
index still resolves: **item 8 decides whether to run it**, item 13 whether to
offer to re-point it". This is that decision, and it was missing from the first
version of this section: the status was computed and **no consumer read it**.

**What was at stake, measured.** With two stand-in binaries, a state stamped on
row `spice,5` named `Ngspice ver_50`, and that index coming to hold a row named
`Ngspice 44` (item 6's own "a row inserted above" scenario):

```
resolve-before: tool spice index 5 status ok      cmd: …/ngspice_ver50 -b … 2>@1
resolve-after:  tool spice index 5 status stale   cmd: …/ngspice_44     -b … 2>@1
```

— a **different binary**, with no word to the user. The `invalid` facet is the
same harm by another route: the stored index is gone, `resolve` falls back to
the tool's **default** row, and that row's `exe` runs instead. Before item 8
neither substitution was possible (`run_cmd` was a literal), so this item
created the exposure and owes the fix.

**Reported, not refused**, and the split is deliberate:

- the §12.4 **exe** guard refuses because its case has **no run left in it** —
  the named binary is not there and the only alternative *is* the silent
  substitution;
- here a real, configured, locatable simulator **is** resolved. Refusing would
  make a saved session unrunnable because somebody renamed a row, and §5 already
  rules that a hand-edited `simrc` "must not make a saved session unopenable".
  Reporting turns a silent substitution into a loud one, which is the whole
  complaint.
- The substitution cannot smuggle a **mode** past B4 either: the casemode probe
  runs against the binary that will *actually* run, so a stale row resolving to
  a folding binary under a `distinguish` request still **refuses**.

The message names the stamped name, the name the row carries now, and the
executable that will run (`CS187`); an `ok` resolve says nothing at all
(`CS187b`, the control — without it the report could fire on every run).
Item 13 owns *offering* to re-point the row; this item owes the sentence.

---

# 13. THE EXPRESSIONS ASE-L SHIPS — casemode item 9

`PLAN.md` §3b item 9 and §D6 part 1. `DECISIONS.md` **A1** (fold is the default,
so a stock user must see no change) and **B1** (the requested mode is the
profile's, with the global floor underneath). Item 6 owns §1–§10, item 7 §11,
item 8 §12.

Items 1–8 built the read path and the run command. This is the **write** path:
the two procs that turn a Direct-Plot / Select-On-Design click into the `.save`
and `print` cards of the deck about to be run.

Checks: `tests/headless/test_ase_sod_case.tcl`, `SC192`–`SC211b` (52), true
headless, no simulator involved — plus `test_ase_dialogs` **`G13`** (2), which
needs a real Tk dialog and therefore runs on the display arm.

## 13.1 What was there, and why it had to move

```tcl
proc ase::ui::sod_expr {kind token} {
  if {$kind eq {voltage}} { return "v([string tolower [string trimleft $token #]])" }
  return "i([string tolower $token])"
}
...
  return "v.[string tolower $path]$token"        ;# sod_qualify's current arm
```

Three unconditional folds. A net drawn `TopNet` reached the deck as `v(topnet)`
in **every** mode, and a source `Vs` two levels down as `i(v.xm.xl.vs)`.

| the card we emit | fold | preserve | distinguish |
|---|---|---|---|
| `.save v(TopNet)` (schematic case) | rc=0 → `v(topnet)` | rc=0 → `v(TopNet)` | rc=0 → `v(TopNet)` |
| `.save v(topnet)` (folded) | rc=0 → `v(topnet)` | rc=0 (upstream `0056`) | **rc=1, ZERO VECTORS, "analysis not run"** |

(`PLAN.md` §F2, re-measured 2026-08-14.) The bottom-right cell is the whole
reason this item exists: under `distinguish` a folded card does not mis-label a
trace, it **destroys the run** — every trace in the session, with rc=1 and a raw
file that exists and holds nothing.

## 13.2 RULING — the mode is a REQUIRED argument of `sod_expr`, never a default

`sod_expr {kind token mode}`. There is no default value and there must not be
one (`SC195`, which goes green the moment somebody adds `{mode fold}`).

The proc **must stay pure** — its own comment records that it is called with no
design loaded (`test_ase_interact` H1, `0161` HP1/HP2, and `SC196` here, which
renames the `xschem` command away and still expects an answer). So it cannot ask
the engine, and the mode has to arrive from outside. The two candidates were a
defaulted argument and a mirrored global; the argument won, and it is required
rather than defaulted because of the table above:

- a **defaulted** mode is a silent fold. Under `distinguish` a caller who forgot
  it loses the whole simulation, and **nothing on the ASE side says why** — the
  run comes back `rc=1` with a raw file that exists and holds no vectors.
  (Corrected in the fix round: an earlier wording said "with no diagnostic
  anywhere", and that is false as measured. `ver_50` *does* warn, precisely, once
  per vector, in its own log — `Warning: no vector named 'topnet'; 'TopNet'
  differs only in case (casemode=distinguish)` — alongside `Error: no data saved
  for Transient analysis; analysis not run`. The ruling stands on the `rc=1`
  half, which is the half ASE-L can see);
- a **required** mode is a Tcl error at the call site, at the first run.

There is exactly one production caller (`sod_click`), and the nine committed
assertions that called it with two arguments were restated with an explicit
`fold` — same ids, same expected strings, because `fold` is A1's default and
those strings are now this item's A1 guard as well as their own suites'.

Inside, anything that is **not** `preserve`/`distinguish` folds (`SC192d`,
`SC206`). An unrecognised mode must never fall through to "emit verbatim": that
is the same conservative direction A1 already takes, and it is the backstop that
lets §13.4 delegate instead of re-validating.

## 13.3 RULING — `sod_qualify` gains NO mode, and its prefix follows the TOKEN

The obvious shape was a second mode argument down here, so the current arm could
choose `v.` or `V.`. It is wrong twice.

**Wrong once because item 4 measured it.** Item 4's reviewers prescribed exactly
that — "`v.` when folding, `V.` otherwise" — and it was refuted on `ver_50` with
the device renamed (`receipts/04-hilight-senders.md`, `raw_case_mode.md` §11):

```
deck names the source `Vs`:  fold -> i(v.x1.vs)   preserve -> i(V.X1.Vs)
deck names the source `vs`:  fold -> i(v.x1.vs)   preserve -> i(v.X1.vs)
```

The prefix is **the device's own first character**, folded along with everything
else — not a letter chosen by the mode. `hilight.c`'s `sender_current_prefix()`
is the C half of the same rule (`buf[0] = t[0]`), and the two are two roads to
the same simulator: if they disagreed about the spelling of one current, one of
them would be wrong. `SC203`/`SC203b` reproduce **both** measured rows byte for
byte on a mixed-case fixture; `SC201` is the teeth against re-introducing a mode
branch here, and the reviewers' prescribed fix is mutation `M6`, which reddens
`SC203b` alone (an uppercasing prefix is invisible without a lower-case subject —
item 4's `M9` carry-forward).

**Wrong twice because the case mapping already has a home.** `sod_net_at`'s
comment states it: *"The simulator-side mapping belongs to sod_expr, and only
there."* Both folds in `sod_qualify` — the path, and the hard-coded lower-case
prefix letter — were that mapping leaking downhill. So:

```tcl
  return "[string index $token 0].$path$token"
```

`sod_qualify` now answers in the **schematic's own spelling**, identically in
every mode, and `sod_expr` folds the composed name when (and only when) the mode
is `fold`. This mirrors D3's result in backannotation: the mode does not get a
branch here, it **disappears** from here.

**Under `fold` this is byte-identical for every token whose first character folds
to `v`** — and that is the honest quantifier, corrected in the fix round. An
earlier wording here, in `sod_qualify`'s own comment and in the receipt said
"byte-identical for every token that can reach it", justified by "a SPICE voltage
source's name necessarily begins with `v`/`V`, and both accepted cell types are
templated V-devices". **The templates are only defaults.** `sod_click` validates
`cell::type` and takes `name` verbatim, so `V1`, `Vmeas`, `Vs` fold to the old
literal `v.` and **a device renamed away from v/V does not**:

| pick, `fold` mode | HEAD (`v.` literal) | here (token-derived) |
|---|---|---|
| `V1` at depth | `i(v.x1.x2.v1)` | `i(v.x1.x2.v1)` — same |
| `E1` at depth (`vsource_pwl.sym` ships `template="name=E1"`) | `i(v.x1.e1)` | `i(e.x1.e1)` — **moves** |
| `Imeas` at depth (renamed ammeter) | `i(v.x1.imeas)` | `i(i.x1.imeas)` — **moves** |

**Measured which of the two the simulator actually has** (`ver_50`, a VCVS `E1`
inside `X1`, `render_deck`'s own deck shape — analyses inside `.control`, bare
`write`, no vector list):

```
raw Variables:        time  i(e.x1.e1)  v(n1)  i(v.x1.v1)  i(v2)  v(x1.mid)  v(x1.vc)
.save i(e.x1.e1)  ->  rc 0, 1192-byte raw, the vector is there
.save i(v.x1.e1)  ->  "no data saved for Transient analysis; analysis not run",
                      570-byte empty raw — the whole run lost
```

So for those devices the old hard-coded `v.` was not "unchanged", it was
**broken**, and the derivation repairs it — in the direction of
`hilight.c`'s `sender_current_prefix()` (`buf[0] = t[0]`), which had the token
rule already. `SC211`/`SC211b` pin both columns on a fixture instance named `E1`.
(An `I`-named ammeter is a *current source* card in SPICE and has no branch
current at all; both spellings name nothing there. That is a schematic error, not
a case question.)

This is the **one** documented exception to A1 byte-identity in this item; §13.5's
table is otherwise exact.

## 13.4 Whose mode is it: the RUN's request, resolved once per gesture

`ase::ui::sod_case_mode {key}` → `ase::sim_profile_casemode` on the session's
state → the resolved profile row's `casemode`, else the global floor
`sim_case_mode`, else `fold` (§3, B1).

Stated rather than inherited: these strings are `.save`/`print` cards in a deck
**about to be run**, so the question is *what will this run be asked to do*. It
is **not** a loaded raw's `case_sensitive` and **not** a file's resolved verdict.
`raw_case_mode.md` §10 bars the floor from colouring a *file's* verdict; item 4
already ruled that a question about a **run's** data may use it, and item 8
treats the floor as a request. This is the run side of that line.

Resolved **once per gesture** (item 4's rule), in `sod_click`, before the bus
fan-out — so a bus's bits cannot disagree with one another (`SC204b`; mutation
`M9`, which passes the resolved mode only for the first bit, reddens it alone).
Once per **gesture**, not once per session or once per mode-arm: a memo across
clicks was tried as a sabotage in the fix round (`N10`) and reddens twenty
checks, `SC209c` among them.

**The SESSION's own row, driven** (fix round). Every `SC205`–`SC207` check passes
the literal key `k`, which names no session, so `ase::session_state` returns `{}`
and the answer comes from the tool's *default* row — a `sod_case_mode` that
ignored its key entirely stayed green across all of them (raised in review, with
a mutation). `SC209` closes it: a **real** session, stamped with
`ase::sim_profile_stamp` at a **non-default** row carrying `distinguish`, with the
floor at `fold` and the default row carrying no mode at all. `SC209` asserts the
stamped key answers `distinguish` **and** `k` answers `fold` in the same breath;
`SC209b` asserts the queued expression follows the stamped row; `SC209c` is the
control that the unstamped key, same floor and same click, still folds.

One qualification on "a deck about to be run": that is exactly true of `outputs`
mode. In `plot` mode the same fan-out sends the same expression to
`dp_queue`/`dp_finish` and the waveform viewer, where it is matched against an
already-loaded raw by the one-lookup authority rather than written into a deck.
The ruling is unchanged there (the requested run mode is still the best available
statement of how this session spells things) and no combination misbehaves —
under `fold` nothing moved, under requested-`preserve`/delivered-`fold` item 2's
case-blind rungs resolve it, and `distinguish` never has a raw because item 8
refuses the run — but the justification above is written for the deck consumer.

**It DELEGATES and does not re-validate.** The first cut ended with
`if {$m ne {preserve} && $m ne {distinguish}} { return fold }` — a second copy of
the validation `::sim_profile_casemode` already performs. It survived every
mutation green, and worse, it **masked** a real one: with the copy in place, a
`sod_case_mode` that bypassed the authority and read `$::sim_case_mode` raw still
folded garbage, so `SC206` could not see it. Deleted; `M10b` now reddens `SC206`,
`SC207b` and `SC207c` together. `sod_expr`'s "anything unrecognised folds" is the
backstop (§13.2).

**It asks with `init 0`, and that is a correctness fix, not a micro-optimisation**
(fix round). `ase::sim_profile_resolve` opens with `::set_sim_defaults` because
`sim()` is built lazily (§1, `CS163k`) — but **`::set_sim_defaults` is not a
read**. Its first loop is

```tcl
if { [info exists has_x] && [winfo exists .sim] } {
  foreach tool $sim(tool_list) { for {set i 0} {$i < $sim($tool,n)} {incr i} {
    set sim($tool,$i,cmd) [.sim.topf.f.scrl.center.$tool.r.$i.cmd get 1.0 {end - 1 chars}]
  } }
}
```

i.e. with the Simulation Configuration dialog open it **slurps every unsaved cmd
edit into the global array**. Reached from a Direct-Plot / Select-On-Design click
it therefore committed the user's in-progress typing and defeated that dialog's
Cancel — measured: `USER-IS-STILL-TYPING` in the spice row-0 box survived one
`sod_click`, and survived the Cancel after it. A pick is deliberately **read-only**
(issue 0204); it may not write unrelated global config. So:

- `ase::sim_profile_resolve {state {init 1}}` and
  `ase::sim_profile_casemode {state {init 1}}` gained a **read-only form**;
  `init 0` skips the lazy `set_sim_defaults`. Every existing caller keeps `1` and
  `CS163k` (resolve builds the array it reads) is untouched.
- `sod_case_mode` does the lazy build **itself, guarded**:
  `if {![info exists ::sim(tool_list)]} { catch {::set_sim_defaults} }`. That is
  the only state in which the array is missing, and it is a state in which `.sim`
  cannot exist either — `simconf` builds `sim()` before it builds the dialog — so
  the guarded call can never reach the slurp.

`SC208` pins that a pick makes **zero** `set_sim_defaults` calls; `SC208b` pins
that a virgin array is still built, once, with the right answer; and
`test_ase_dialogs` **`G13`** pins the symptom itself with a real dialog, a real
widget and a real edit.

**A THROW IS ANNOUNCED, NOT FOLDED SILENTLY** (fix round). The first cut wrapped
the whole resolve in a blanket `catch` and returned `fold` on any failure — which
is the very silent fold §13.2 made the `mode` argument required to prevent, only
one layer up: a `distinguish` session would emit folded cards with no error, no
CIW notice and no log line. An unknown key is *not* that case — it is the `{}`
state, which legitimately resolves to the tool's default row, and
`ase::session_state` cannot throw (its dict is initialised at namespace-eval
time). So the catch is narrowed to the resolver call, and on a genuine throw
`sod_case_mode` still answers `fold` (it cannot invent a mode) but says so
through `::ase::echo` first. `SC208c` pins both halves in one assertion.

## 13.5 A1, as a check rather than a hope

Under `fold` every composed expression is **byte-identical** to the literal the
shipped suites already assert. Those literals are repeated inside
`test_ase_sod_case.tcl` on purpose — this is where a fold regression is supposed
to be caught, and a check that only said "the two modes differ" would pass with
both of them wrong:

| literal | its home | here |
|---|---|---|
| `v(topnet)` | `0161` HP4 | `SC197` |
| `i(v9)` | `0161` HP5 | `SC198` |
| `v(x1.x2.mid)` | `0161` HP10 | `SC199b` |
| `i(v.x1.x2.v1)` | `0161` HP11 | `SC200` |
| `v(net1)`, `v(out)`, `i(v1)` | `unnamed_net` AN10–AN12, `interact` H1 | `SC192`–`SC194c` |
| `v(xm.xl.midnode)`, `i(v.xm.xl.vs)` | (new mixed-case fixture) | `SC202b`, `SC203c` |

Mutation `M18` (the fold arm disarmed) reddens fourteen of them at once; that is
the drive those guards exist for.

## 13.5b DECLARED DEPARTURE — `PLAN.md` §D3 says "unconditionally"

Said out loud rather than chosen quietly (`CREW_BRIEF` §2), because it was not
declared in the first cut and two reviewers raised it.

`PLAN.md` **§D3** says `sod_expr` stops folding **unconditionally** — "It does not
need to know the mode" — and buys one specific property with that: *a state file
written today is correct under a simulator installed tomorrow*, because the row
stores the schematic's own spelling and the mapping happens at deck-render time.

**This item is mode-CONDITIONAL instead, and the driver's `A1` instruction
outranks §D3.** A1 requires every shipped expression under `fold` to be
byte-identical to today's, and `fold` is the default at every stage; an
unconditional stop-folding would move ten committed assertions' *values* and every
stock user's deck with them. The audit-empty contract for items 1–9 is the same
statement from the other side.

**The consequence §D3 was buying, named:** the mode is resolved at **pick** time,
so an output row picked while the profile said `fold` stores `v(topnet)`
*forever*. Re-point that session at a `distinguish` profile later and
`render_deck` (`ase.tcl`, `.save [dict get $o expr]`) ships the folded card
verbatim — the bottom-right cell of §13.1's table, rc=1, zero vectors, analysis
not run. Reproduced end to end (real `ase::session_open`, real `sod_click`, real
`render_deck` hook) by two reviewers independently. Item 8 does not refuse it,
because requested == measured == `distinguish`; nothing on the path re-cases a
stored row.

**Owner:** filed as `doc/claude/issues/0423-a-fold-picked-output-row-goes-stale-under-a-later-distinguish-profile.md`,
so it cannot be lost between item 9 and item 10. It is **not** repaired here:
`PLAN.md` §D5 allows the distinguish-only re-case pass to be built or deferred
with a filed issue, and the driver's item-10 fence names only the pre-flight, the
`$sim_status` guard and the constants-raw rejection. Until it is built, the
mitigation is item 10's pre-flight, which must **REFUSE** such a run rather than
silently spell it wrong — see §13.6.

## 13.6 What this hands to items 10, 11 and 12

- **Item 11 (`result_probe -nocase`) is needed for exactly one combination**, and
  it is worth naming precisely because the plan's wording is broader than the
  truth. Under `fold` we now emit `v(in)` and ngspice echoes `v(in)` — a match.
  Under `preserve` **delivered**, we emit `v(In)` and it echoes `v(In)` — a
  match. The mismatch is B4's *run-and-report* path: **requested `preserve`,
  measured `fold`**. There we ship `v(In)` and `print` answers `v(in)`
  (`PLAN.md` §F3), and without item 11 the Outputs pane's Value column is
  silently empty for every mixed-case net. `distinguish` cannot reach this state
  — item 8 refuses the run.
- **Item 10's pre-flight** now compares expressions that carry the schematic's
  own case against the netlist map, which also carries it. Under `distinguish` a
  case-sensitive comparison is the right one; under `fold` the expression is
  already folded and the map is not, so the pre-flight must fold **both sides**
  or it will report every mixed-case net as absent.
- **Item 10 also inherits §13.5b's stale row** (`0423`). A row picked under a
  `fold` profile and run under a `distinguish` one is a *folded* expression the
  pre-flight will see as absent from a case-kept netlist map — which is the right
  answer, and the pre-flight must **refuse the run and say why** rather than pass
  it through. Item 9's expressions are correct for the mode that was requested
  when they were picked; nothing between the pick and `render_deck` re-cases
  them. Whoever builds the re-case pass closes `0423`.
- **Item 12's post-load repair** is still needed and is now *narrower*: a
  constructed current name (`i(V.Xm.Xl.Vs)`) is only as right as our model of the
  simulator's construction, and `get_raw_index`'s `i(v.x` fixup is item 2's, not
  ours.

## 13.7 What is NOT here

- **No simulator was launched by any check in this item.** The three-mode
  behaviour rests on item 4's measurements on `ver_50` (quoted above) and on
  `PLAN.md` §F1–§F4; nothing in `test_ase_sod_case.tcl` runs ngspice, and it
  needs none.
- **The deck itself is not re-measured.** These are the strings `render_deck`
  writes; that a `preserve` deck full of `v(TopNet)` cards runs green end to end
  on `ver_50` is asserted by `PLAN.md` §F2, not by a check here.
- **The Xyce arm is untouched and stays UNVERIFIED.** ASE-L's pick path has no
  Xyce branch at all; `hilight.c`'s does (item 4), and the two therefore differ
  for Xyce by construction.
- **`ase::ui::sod_rel_path` contains no fold** and was not modified; the
  dispatch's "three folds" are the two in `sod_expr` plus the one in
  `sod_qualify`.
- **Ammeters are reasoned about, not driven.** No check picks an `ammeter`
  instance; the claim that its *template* name is V-prefixed comes from
  `xschem_library/devices/ammeter.sym`'s `template="name=Vmeas"` — and §13.3 now
  says out loud that a template is only a default. The non-`v` prefix class is
  driven, on a `vsource` instance named `E1` (`SC211`), which is the same code
  path.
- **Four checks are fixture preconditions with no item-9 code beneath them and
  are NOT evidence**: `SC199` and `SC202` (the descend worked), `SC207` (the
  spice tool has a default profile row) and `G13 fixture` (the simconf row-0 cmd
  widget exists).
- **`SC208c-sane` is test hygiene**, not a product assertion: it checks the real
  `ase::sim_profile_casemode` was renamed back after `SC208c`'s stub. It has a
  drive anyway (`N11`/`N10`).
- **`sod_case_mode`'s `{}` normalisation has no behavioural drive** (`M17`
  survives green): `sod_expr` folds `{}` exactly as it folds `fold`. It is kept
  so the proc's own return value is always a mode name.
- **`doc/claude/code_analysis/ngspice_case_sensitivity.md:62` still quotes the
  two-argument call site.** Item 15 owns rewriting that file's §Part 3.

---

# 14. THE THREE DEFENCES — casemode item 10

`PLAN.md` §3b item 10 and §D5. `DECISIONS.md` **C3** (build both defences),
**C4** (all three, none redundant, with the measured guard shape) and **D1**
(the pre-flight *offers* the legacy corrections; never a silent re-case). Item 6
owns §1–§10, item 7 §11, item 8 §12, item 9 §13.

Checks: `tests/headless/test_ase_preflight.tcl`, **`PF212`–`PF220e`, 74 checks**,
true headless. Seventy-three of the seventy-four are driven by a mutation; the
one that is not is named in §14.8.

## 14.1 The defect, and why it is not a casemode defect

A `.save` of a node the circuit does not have **does not fail usefully**.
Re-measured 2026-08-17 in `render_deck`'s own deck shape (analyses inside
`.control`, bare `write`, no vector list), on **both** binaries:

```
.save v(nosuchnode) + tran
  rc=1
  "Error: no data saved for Transient analysis; analysis not run"
  ZERO mentions of the bad token on either stream
  ...and a 569-byte raw file IS WRITTEN:
      Title: Constant values
      Date: Sun Aug  2 23:29:26 UTC 2026     <- the BUILD stamp, not the run
      Command: ngspice-46, Build Sun Aug  2 23:29:26 UTC 2026
      Plotname: constants
      No. Variables: 12      (yes false true boltz c e echarge i kelvin no pi planck)
      No. Points: 1
```

`ver_50` is **identical to stock here** — upstream has withdrawn that fix three
times, which is why C3 rules differently from C1 (`v(all)`, fixed on ver_50,
left alone). So this is not a case-mode defect at all: it reaches every user of
every ngspice, from a plain typo, with no flag set.

Downstream, that file exists, parses and attaches, and the session shows twelve
mathematical constants where its waveforms should be. `rc=1` is a real
corroborating signal, but **it arrives with the file already written**, so it
cannot replace the content check.

**C4's table, and why none of the three is redundant:**

| defence | catches | blind to |
|---|---|---|
| (a) pre-flight (`ase::preflight_gate`) | the **specific bad expression**, named, before any simulator starts | a name that is legal only because an `.include`d PDK file defines it |
| (b) `$sim_status` guard (`render_deck`) | **any** failed analysis, leaving **no artefact at all** | any file we did not generate |
| (c) content check (`ase::raw_content_verdict`) | a bad file from **anywhere** — old, another tool's, pre-guard | cannot say **why** it is bad |

(c) is the cheapest (one comparison against `Plotname:`) and the only one that
can protect a raw someone hands you.

## 14.2 (a) The pre-flight

`ase::preflight_scan` is a **pure function** of a state and the circuit netlist
text, so every ruling below is drivable with no simulator and no files.

### RULING — the map is built from the NETLIST ARTIFACT, never from the schematic

The deck is what runs, and `ase::run_existing` deliberately runs a netlist the
design may no longer match (hand edits survive it, by design). Asking the
schematic would answer about a different circuit. `ase::netlist_map` parses:

```
scopes   <subckt name, folded> -> {nodes {..} devs {..} insts {<inst> <master>}}
         the TOP level is the scope named {}
globals  nodes visible in every scope (`.global`, plus `0`)
includes <scope> -> 1 for every scope carrying an `.include`/`.inc`/`.lib` card
```

### RULING (fix round) — a `+` CONTINUATION IS FOLDED ONTO ITS CARD, not skipped

The first cut skipped continuation lines, and an earlier revision of §14.7
justified it with "xschem's netlister does not emit them for element cards".
**That premise is false**: the user's own `~/.xschem/simulations/tb_bandgap.spice`
carries 46 of them (`0_examples_top.spice`, 439), all element-card continuations
of the `XM4 … \n+ mult=1` shape. Skipping them left a node declared only on a
continuation out of the map, and a legal run was **falsely refused** — the one
direction the pre-flight must never take. They are now folded onto the preceding
logical card before anything is parsed, which also fixes the X-card master being
read from the wrong token when the wrap lands between the last node and the
master (`PF221o`, `PF221p`, `PF221q`; mutation `F16`).

Shape verified against a real xschem netlist (`tests/headless/fixtures/ase_hier`
netlisted): the top-level body sits between `**.subckt` / `**.ends` **comment**
markers, real `.subckt`/`.ends` bodies follow, and an X-card's **last** non-`k=v`
token is its master.

### RULING — the map OVER-approximates, deliberately, and that is the safe direction

A device card's node count is device-dependent (`M` has four, `X` has as many as
its master), and a model name or a bare value is indistinguishable from a node
without a full device grammar. So **every non-`k=v` token after the instance
name is recorded as a node**. The error that introduces can only make a name
look *present* that is not — a miss, which defences (b) and (c) still catch. The
opposite error is a **false refusal**, which blocks work that would have
succeeded, and the pre-flight is the only one of the three that can do that.

Currents and voltages keep **separate name spaces** (`devs` vs `nodes`), because
`i(midnode)` is nonsense where `v(midnode)` is fine (`PF214h`; mutation `M16`,
one shared space, reddens ten checks).

### RULING — `unknown` is a REFUSAL TO JUDGE, and the gate never refuses on it

Four arms reach it, and each is a place where the netlist genuinely cannot
answer:

* an `@dev[param]` shape — simulator-constructed, item 12 / issue `0419`;
* a bracketed name that is not an exact hit — a bus bit is a whole sub-language
  (issue `0159`) and the **base name of `bus[1]` is not itself a node**, so a
  base-name test would false-refuse every bus;
* a hierarchy segment whose master subckt is **not in this netlist** — it came
  from an `.include`d PDK file. This is C4's named blind spot, written down as
  code rather than as a caveat;
* **(fix round)** a name that **nothing in its scope even folds to**, when that
  scope carries an `.include`/`.inc`/`.lib` card. See the ruling below.

An instance path segment that names **nothing in a scope we did parse** is
`absent`, not `unknown` (`PF214j`): that we can prove.

*(An earlier revision of this list named a fifth arm, "the empty case (no
top-level body parsed at all)". **That arm does not exist and never did**:
`ase::netlist_map` always creates the `{}` scope, so the `![dict exists $scopes
$scope]` test can never fire for the top level. Driven:
`ase::netlist_map "* only a comment\n.end\n"` gives `scopes {{}}` and
`ase::netlist_map_resolve voltage out 0` returns `absent`. The behaviour is
right — such a deck would have produced the constants raw anyway — only the
spec's claim was wrong.)*

### RULING (fix round) — AN INCLUDE-BEARING SCOPE STANDS DOWN, BUT ONLY WHERE IT IS BLIND

A design whose stimulus or supply cards live in an `.include`d file was
**refused outright** for a run the simulator completes perfectly: netlist
`.include stim.sp` + `R1 in out 1k`, output row `i(V1)` with `V1` defined in
`stim.sp` — measured `rc=0` and a 2071-byte transient raw. C4 says the
pre-flight is **blind** there, and blind means **stand down**, not refuse.

But downgrading *every* miss in an include-bearing scope would leave defence (a)
inert on every real design, since they all `.include` a PDK. So the downgrade is
narrowed to the case where this netlist genuinely has nothing to say: **no
stored name in that scope even folds to the one asked about**. A fold hit is a
proof about *this* netlist — it is D1's correction and issue `0423`'s whole
subject — and it keeps refusing (`PF221k`, `PF221l`, `PF221m`, `PF221n`;
mutations `F34`, `F35`, `F36`).

### RULING (fix round) — a mis-cased HIERARCHY SEGMENT is as fatal as a mis-cased leaf

`ase::netlist_map_resolve` returned the **leaf's** verdict and threw away the
case verdict of every intermediate segment. With the netlist spelling the
instance `X1`, a stale fold-picked `v(x1.out)` under `distinguish` therefore
resolved `present`: the pre-flight passed through, in silence, the exact `0423`
row it exists to catch — while the case-keeping binary aborts that analysis
(measured: `rc=1`, `RUN-FAILED`, no raw). Any segment that came back as a
fold-only hit now makes the whole identifier `absent`, carrying the
already-assembled whole-path correction (`PF221f`–`PF221i`; mutations `F32`,
`F33`).

### RULING (fix round) — `vi(...)`, `deriv(...)` AND FRIENDS ARE NOT `v()`/`i()` IDENTIFIERS

Unanchored, `([vi])\(` matched the `i(` inside ngspice's standard AC output form
`vi(out)`, which was then read as a **current named `out`**, looked up in the
device table, found absent, and the whole run **refused with a nonsense
diagnosis** — reachable straight from the free-text Expression entry of the
output editor. `deriv(time)` was read as `v(time)` the same way. The hole was
asymmetric (`vdb`/`vm`/`vp`/`vr` all passed), which is why no family-level test
could see it. The identifier regexp now requires a non-identifier character, or
the string start, in front of the letter. That costs the `vi`/`vdb`/… family
their pre-flight — a **miss**, still caught by (b) and (c) — and never a false
refusal (`PF221`–`PF221e`; mutations `F06`, `F07`, `F08`).

### RULING — under `fold` the pre-flight folds BOTH sides (§13.6's trap)

Item 9 emits `v(topnet)` under `fold` and the netlist says `TOPNET`. A
case-sensitive comparison would report **every mixed-case net in the design** as
absent and refuse the **default** mode's every run — worse than no pre-flight at
all. So the comparison is case-sensitive **only** when the requested mode is
`distinguish` (`PF214`; mutation `M8` removes the fold arm and reddens five).

The mode is the **run's request** — item 9 §13.4's ruling and item 8's source:
profile `casemode` → global floor `sim_case_mode` → `fold`. It is asked with
`init 0`, item 9's **read-only** form: a pre-flight is a question, and
`::set_sim_defaults` is not a read (§13.4).

### RULING — where the gate sits, and what REFUSE means here

`ase::preflight_gate` is called from `ase::run_deck` **immediately after the
netlist text is read** and before anything else: before `cosim_map`,
`cosim_save_map` (which deletes the sidecar), `cosim_clear_artifacts` (which
deletes every VCD the deck promises), any `.so` rebuild, the deck write and the
process. It cannot be item 8's neighbour any earlier than that, because it needs
the netlist text; everything between item 8's gate and this one only **reads**.

A refusal therefore leaves **no deck, no raw, no log, no deleted VCD, no rebuilt
`.so`, no `last_run`, no callback**, and the message says the rundir's files are
from an earlier run — item 8 §12.5's shape, and it matters more here than
anywhere: **item 10 exists because a file that looks like a result is not one,
so this gate must not manufacture a new instance of that class.** `PF216g` pins
it with a planted previous-run artefact, exactly as `CS181` does.

### RULING — every offending expression gets its OWN line, and `ase_preflight 0` is a real lever

Item 14's lesson is that a channel can be correct and still reach nobody. A
refusal is loud by nature, but a one-line summary of twelve corrections is a
summary nobody can act on, so the gate echoes **one `error` line per offender**
naming the expression, the identifier, and the correction when there is one
(`PF216c`, `PF217b`).

**Fix round — the HEAD counts EXPRESSIONS, the DETAIL LINES count identifiers.**
The head counted `[llength $rows]`, which is the number of offending
*identifiers*, and worded it as expressions (and drove the singular/plural off
it), so one output row naming two absent nodes announced "2 output expressions".
Rows are now grouped by expression: the head counts the groups, each identifier
still gets its own line, and the **correction is composed once per expression**
and offered on that expression's last line — a row naming two mis-cased nodes
has one repaired spelling, not two mutually exclusive halves (`PF221t`–`PF221v`,
`PF221z`; mutations `F49`, `F50`, `F51`, `F52`).

`ase_preflight 0` disables the refusal, and the refusal message says so. The
map's blind spot is real — a top-level node that only an `.include`d file
defines is the case the over-approximation cannot reach — and a user who is
right must not be locked out of their own simulator. Defences (b) and (c) are
unaffected by the flag, which is why giving the lever is cheap.

## 14.3 (b) The `$sim_status` guard

C4's shape, copied rather than reinvented, and re-measured here on both binaries
in this deck's own shape:

```
op                          <- each enabled analysis
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
...
remzerovec
write <abs path>
```

| | rc | stdout | file |
|---|---|---|---|
| bad run (`.save` of an absent node) | **1** | `RUN-FAILED` | **none written** |
| good run | 0 | — | the real raw |

Both `/usr/local/bin/ngspice` (46) and `build-ver_50`, identical.

**Trap 1 — `$sim_status` does not exist before the first analysis, and on a
build that has no such variable at all defence (b) is INERT.** The `$?` test in
front is the **marker that says so**: `NO-SIM-STATUS` in a run log means that
run was protected by (a) and (c) only (`PF218d`, `PF220d`).

**CORRECTION (fix round) — the `$?` test is NOT an error suppressor**, and an
earlier revision of this paragraph said it was ("hence the `$?` existence test
first", to avoid `Error: sim_status: no such variable.` reaching the log).
Re-measured 2026-08-17 on ngspice-46, the full guard alone in a `.control` block
with no analysis before it:

```
with the $?sim_status block     -> rc=1, log line 1 = Error: sim_status: no such variable.
without the $?sim_status block  -> rc=1, log line 1 = Error: sim_status: no such variable.
```

The two logs differ **only** by the `NO-SIM-STATUS` line: ngspice emits that
error at parse time regardless. The shipped guard is unaffected — `render_deck`
emits no guard at all in a deck with no analysis (`PF218e`), so as shipped the
guard is only ever parsed with an analysis in front of it — but the *rationale*
recorded for a "MEASURED, copy it" shape was wrong and is corrected here.

**Trap 2 — it is LAST-WRITER-WINS PER ANALYSIS, so one guard at the end is the
defect, not the fix.** Measured with a failing `dc` followed by a good `tran`:

```
guard only at the end   -> rc=0, a 2198-byte raw written, the failure MASKED
guard after each        -> rc=1, RUN-FAILED, nothing written
```

So the guard is emitted inside the analyses loop, after **each** analysis
(`PF218b`, `PF218c`; mutation `M35` is exactly C4's named defect and reddens
five checks).

**Fix round — the guard is now DRIVEN for all four analysis types.** The first
cut only ever rendered a deck of `op` and `tran`, so restricting the emission to
those two left five suites and 336 checks green with `dc` and `ac` completely
unguarded — and C4's masking measurement is built on exactly a failing `dc`.
`PF221al` renders `op`+`dc`+`ac`+`tran` and asserts one guard immediately after
**each**; `PF221am`/`PF221an` do the single-analysis `dc` and `ac` decks
(mutation `F63` is the reviewer's own `if {$type eq {op} || $type eq {tran}}`).

**The deck's shape is otherwise untouched** (`CREW_BRIEF` §4): no dot card for
the analyses, no `run`, and the `write` line still names **no vectors** —
upstream `0073` is unfixed and naming them writes two identical columns with
byte-identical names that no filter can separate. `PF218g`/`PF218h` are the
standing guards against drifting any of that.

**One committed assertion moved, and it is the golden deck** —
`test_ase_core`'s `D1`, restated in place with its id and a why-comment. It is
the drive for the emission itself: without the restatement the shipped suite
goes red the moment a guard is emitted, and with it a suppressed guard goes red.

## 14.4 (c) Content-based rejection

`ase::raw_content_verdict <path>` → `{ok constants appended plotname nvars
npoints signature why}`.

**The signature**, all four of C3's markers, measured on the real file:
`Plotname: constants`; `Title: Constant values`; `Date:` **equal to the build
stamp the `Command:` line repeats**; and `No. Variables:` at or below the twelve
the constants plot carries.

**RULING (fix round) — the count may CONTRADICT the plot name, not only
corroborate it.** `let`-created vectors written from the constants plot land in
a file headed `Plotname: constants` that holds **real user data** — the tree's
own `doc/claude/ngspice_upstream/feedback/…/repro/letonly.raw` is 14 variables
over 5 points. Rejecting on the plot name alone threw that data away while
asserting the file "holds ngspice's twelve built-in mathematical constants",
which it demonstrably does not. **More than twelve variables, or more than one
point, and the file is REPORTED rather than rejected** — the same treatment the
`appendwrite` shape already gets, and the same lean as everywhere else here.
The genuine 12-over-1 raw is still rejected, asserted in the same breath so
"never reject anything" cannot satisfy the check (`PF221ai`, `PF221aj`,
`PF221ak`; mutations `F72`, `F73`). `attach_dbs` reports any accepted verdict
that carries a `why`, at tag `note`.

**RULING — the count is a FLOOR and only ever corroboration.** A legitimate plot
can hold twelve vectors, so the count (and the `Date`) are recorded only once a
**decisive** marker has already fired. Otherwise the verdict prints
"No. Variables: 2 (the constants plot has 12)" about a perfectly good raw
(`PF219d`; mutation `M38`).

**RULING — the `set appendwrite` shape is REPORTED, not rejected.** C3 names it:
a constants plot hiding behind a real one. Plot 1 is genuine data and the C
reader selects a plot by `sim_type`, which `constants` never matches, so
rejecting the file would throw away a good result. Reproduced with
`set appendwrite` + `setplot const` + a second `write`: two plot headers in one
file, the second `constants`, 12 variables.

**RULING — a file it cannot parse as a spice raw is NOT judged.** Empty
`Plotname:` ⇒ the verdict says nothing at all, so VCD and table databases, and
any file that merely *quotes* the header (our own refusal message does, and so
does any run log that captured it), pass through untouched. Judging a format we
did not parse is how a content check turns into a false rejection (`PF219e3`,
`PF219f`).

**RULING — the scan is BOUNDED to the first and last 64 KB.** A plot header is a
few hundred bytes at the very start and an appended constants plot is 569 bytes
at the very end, so both shapes are reachable without reading a 50 MB raw on
every attach. `PF219e`'s fixture is deliberately over 64 KB so the tail read is
load-bearing (mutation `M41`).

**Where it is wired:** `ase::attach_dbs`, **before the registry is touched**. A
rejected file therefore leaves the previously loaded database exactly where it
was — "a stale-but-loaded DB beats an empty viewer" is that proc's own stated
policy, and a rejection that cleared first would trade one wrong answer for
another (`PF219k`; mutation `M45` moves the check one line later and reddens it
alone). The rejection is echoed at tag **`error`**; the appendwrite report at
`note`.

## 14.5 D1 — the corrections are OFFERED, and the confirmation is DEFERRED

The pre-flight is already computing the comparison a re-case pass needs, so an
absent identifier that folds to exactly **one** netlist name yields that name as
its correction — for the whole dotted path, not only the leaf, and for a
hierarchical current the branch prefix is **re-derived from the device's own
first character** (item 9 §13.3's ruling, `PF214g`). Two netlist names folding
together yield `ambiguous`: there is no correction to offer, only a question
(D2's rule, one layer up).

**RULING — the apply is an explicitly-invoked command, and the modal is not
built.** D1 says "applies them on confirmation", which implies a prompt. A modal
in the run path is a **pixel deliverable**, and this item's verdict would become
`[E]` with a fifth `look` debt for a dialog nobody has specified. What ships is:

* `ase::preflight_fix_session <key>` — rewrites that session's output rows from
  the corrections found against the **current** netlist artifact, marks the
  session dirty (the user still has to save), and echoes every rewrite;
* the refusal message **names that command**, beside the list of corrections it
  found;
* **nothing** rewrites a row implicitly. `PF217d` asserts the gate alone changes
  no stored row, and mutation `M27` — the gate silently applying the corrections
  and running on — is exactly D1's forbidden shape and reddens three checks.

**Why deferring the presentation is the right call and not a shortcut:** the
detection, the corrections and the apply are all headless-testable and all
driven; what is missing is one button. The refusal is already loud on the CIW,
in the action log and as the raised error, and item 13 owns the run-path UI
surface where such a button belongs. Building a prompt and calling the item
`[x]` was the one option the dispatch explicitly forbade; building it and taking
`[E]` would have bought a dialog no decision in this batch specifies.

## 14.6 Issue `0423` — NARROWED, not closed, and why

Item 9's declared departure (§13.5b) leaves a row picked under a `fold` profile
storing `v(topnet)` forever; run under a later `distinguish` profile the deck
ships that folded card and loses the whole run. §13.6 made the mitigation item
10's: **refuse and say why.**

That is built and driven end to end (`PF217`, `PF217b`): the folded row is
absent from a case-kept netlist map, the gate refuses, names both rows, offers
both corrections, and names issue `0423` in the message.

**It does not close `0423`**, and the reason is precise. The issue asks for a
**re-case pass**: expressions re-derived from the schematic in the mode about to
be requested, so a stored row is never stale in the first place. What is here is
a **confirmation-gated repair** of a session that has already gone stale, driven
from the netlist rather than from the schematic, and it inherits the map's
blind spots — an `.include`-scoped or bracketed name is `unknown`, so a stale
row of that shape is neither refused nor corrected. The silent-wrong-answer half
of `0423` is gone; the staleness itself is not. Recorded in the issue.

## 14.7 What is NOT here

- **The File → Open path is not wired to the content check.** C4 names it as the
  place only (c) can protect, and `ase::raw_content_verdict` is written to serve
  it — but the reader there is C (`xschem raw read`, `save.c`), and item 10's
  scope in `PLAN.md` §3b is `ase.tcl`. Every ASE-L attach goes through
  `ase::attach_dbs` and is covered; a raw opened straight from the File menu is
  **not**. Whoever wires the C reader should call the same rules, not a second
  copy of them.
- **THREE OTHER READ PATHS BYPASS DEFENCE (c), and they are named rather than
  guessed at.** Only `ase::attach_dbs` consults `raw_content_verdict`; grepped,
  the callers that read a raw *without* going through it are
  `wviewer::restore`'s inline attach (`wave_viewer.tcl:3876`), the cross-probe
  add path (`:3648`) and the Location bar (`:8211`), plus the C `File → Open`
  reader above. They are all *re-attach* paths for a file a run already
  produced, so the guard and the pre-flight cover the same defect upstream of
  them — but a constants raw handed to any of the four is still attached.
  Consolidating them behind one seam is a bigger change than this item's fence
  allows.
- **`wviewer::attach_raw` still returns 1 after a rejection**, exactly as it
  already does after a raw that fails to parse. Both of its callers ignore the
  return value (grepped: `ase_window.tcl:2202`, `:3827`), and the rejection is
  loud on the CIW, so this is pre-existing shape left alone rather than a new
  hole — but a future caller that reads it would be misled.
- **A rejected attach leaves the PREVIOUS run's data on screen.** That is
  `attach_dbs`' own stated policy ("a stale-but-loaded DB beats an empty
  viewer") and the alternative is an empty viewer with no explanation, but the
  only thing distinguishing the two on screen is the red CIW line.
- **`i(...)` of a device inside an `.include`d PDK subcircuit is `unknown`**, so
  a typo there is not caught by (a). It is caught by (b).
- ~~**A continuation line (`+`) is skipped, not parsed.**~~ **FIXED in the fix
  round, and the premise recorded here was false** — see §14.2's continuation
  ruling. Continuations are folded onto their card and driven (`PF221o`–`q`).
- **The `vi`/`vdb`/`vm`/`vp`/`vr` AC output family gets no pre-flight at all.**
  The anchor that stopped `vi(out)` being false-refused as a current also stops
  the node inside it being checked. That is a **miss**, caught by (b) and (c),
  and it is the deliberate direction. Declared, and `PF221c` pins that the whole
  family is left alone rather than half-parsed.
- **An include-bearing scope cannot refuse a name it has never heard of**
  (§14.2's stand-down ruling), so a genuine typo in a design that `.include`s
  its stimulus reaches (b) and (c) rather than (a). A **case** mistake in such a
  design is still refused, because a fold hit is a proof about this netlist.
- **A constants plot buried in the MIDDLE of a three-plot file is not seen** —
  the scan is head+tail (§14.4).
- **No `.spiceinit`, no profile and no ver_50 are involved anywhere in this
  item.** The mode only selects the comparison's case-sensitivity.
- **`ase_preflight` is a global, not a per-profile field.** It is an escape
  hatch for a defect in *our* map, not a property of a simulator, so it does not
  belong on a profile row.

## 14.8 Checks that are NOT evidence

- **`PF219h2`** ("the control database really did load") is a fixture
  precondition with no item-10 code beneath it. It exists so `PF219k` cannot
  compare one failure against another and pass on both — which is what it did
  before the control was added, because `xschem raw list` throws with nothing
  loaded and the check was comparing that error string with itself.
- **Half of the fix round's 40 checks are COVERAGE, not defect pins.**
  `PF221c`/`d`/`g`/`h`/`m`/`n`/`p`/`q`/`s`/`u`/`v`/`w`/`y`/`ad`/`ae`/`af`/`ah`/
  `aj`/`am`/`an` were already satisfied by the shipped code; they exist because
  a reviewer's mutation of that code left all 74 original checks green. Each has
  its own mutation in the fix round's table (`F07`, `F08`, `F17`, `F33`–`F36`,
  `F38`–`F40`, `F50`, `F51`, `F63`, `F72`, `F74`, `F84`). The other twenty went
  red against the first cut's own bytes and that master red is recorded in the
  receipt.
- **`PF220`'s legs are skipped, never failed, when no ngspice is on `PATH`**,
  and print no substring `full_audit.sh` scores a file on. They are the only
  end-to-end measurement in the file; everything else is a pure function.
