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
