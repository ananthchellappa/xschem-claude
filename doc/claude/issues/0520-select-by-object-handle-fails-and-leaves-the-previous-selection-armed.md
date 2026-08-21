# 0520 — `select` cannot read the handle `object` hands out: `@<id>` means index 0, and the stale selection gets deleted

**Status:** OPEN. Filed 2026-08-20 by the voice/natural-language design pass
(no repo edit outside this file). **Branch:** `fluid-editing`, HEAD `722ce61e`,
tracked tree clean. **Binary:** `src/xschem` built 2026-08-19 18:16; no `.c` in
the tree is newer, so every C claim below is about the shipped binary and the
source it was built from. Measured `--nogui --pipe -q --script` except the GUI
leg, which ran on the dev display `:99`.
**Area:** the eight `xschem select` arms (`src/scheduler.c:11620-11703`) and
their two resolvers — `get_instance()` (`:187-212`) for `instance`/`pin`, a bare
`atoi(argv[3])` for the other six (`:11648`, `:11657-11658`, `:11667-11668`,
`:11677-11678`, `:11687-11688`, `:11697`) — against the selector block the
`object` verb uses (`:9031-9060`). The same bare `atoi` reappears in eight
`setprop`/`getprop` arms (`:12756-12757`, `:12847`, `:12910`, `:13003-13004`,
`:13043-13044`, `:13087-13088`, `:5626-5627`, `:5663`).
**Severity:** live, user-reachable through the CIW without writing a script, and
silent in both directions at once. For `instance` a failed reference returns
`"0"` and leaves the **previous** selection armed, so the next `delete` / `move`
/ `copy` — none of which take a reference at all — acts on the wrong object.
For `wire` and `text` a handle is parsed as index **0**, the verb returns `"1"`,
and the wrong object is selected under a success code. `setprop wire @<id>`
needs no stale selection at all: it renames wire 0 and returns rc 0 with an
empty result — and neither does `setprop wire <a-net-name-typo>`, which renames
wire 0 the same way with no sigil anywhere in it.
The second half of the title is the *amplifier*, not a second thing to fix:
`select` is additive by design and the tree relies on that, so the lever is to
make the reference resolve (candidate **(a)**), never to make a failed `select`
clear the selection (candidate **(b)**, which would break the one recipe this
API was built for).

---

## What happens

`xschem object <type> @<id>` is the documented way to turn a durable handle back
into a live object, and it works for all seven drawable types. `xschem select`
does not understand the same string, and fails three different ways depending on
the type:

| `select <type>` | resolver | line | `@<id>` becomes | returns | what a caller sees |
|---|---|---|---|---|---|
| `instance` | `get_instance()` | `:11623` | `-1`, no-op | `"0"` | truthful failure code, **no error**, selection untouched |
| `pin <inst> <p>` | `get_instance()` | `:11635` | `-1`, no-op | `"0"` | same |
| `wire` | `atoi(argv[3])` | `:11648` | **index 0** | `"1"` | **false success**, wrong wire selected |
| `text` | `atoi(argv[3])` | `:11697` | **index 0** | `"1"` | **false success**, wrong text selected |
| `rect` | `atoi`,`atoi` | `:11667-11668` | — | `TCL_ERROR` | `xschem select: missing arguments.` |
| `line` | `atoi`,`atoi` | `:11657-11658` | — | `TCL_ERROR` | same |
| `poly` | `atoi`,`atoi` | `:11687-11688` | — | `TCL_ERROR` | same |
| `arc`  | `atoi`,`atoi` | `:11677-11678` | — | `TCL_ERROR` | same |

The four per-layer types are saved only by an accident of arity: they need
`<layer> <index>`, so the one-word handle form trips the guard at
`src/scheduler.c:11603-11607` before any parsing happens. Give them a layer word
— `xschem select rect 4 @2` — and they behave like `wire`.

`atoi` is the whole mechanism, and it is a **prefix parse, not a numeric test**.
It cannot fail. A *leading* non-digit gives 0: measured,
**`xschem select wire NOSUCHNAME` returns `1` and selects wire index 0**, exactly
as `@41` does. A *leading digit* is worse, because the wrong answer looks
plausible — measured, `select wire 40x` and `select wire 40.9` both select wire
40, and `select wire 1e2` selects wire **1**, not 100.

Exactly one malformed input is refused, and only by accident: `select wire -1`
returns `0`, caught by the `n >= 0` half of the bounds test
(`src/scheduler.c:11649`) rather than by anything that looked at the string.

That distinction is load-bearing for the fix. A resolver written as "reject any
selector that is not all-digits" would newly refuse `40.9` and `1e2`, which
succeed today — see candidate **(c)**. The tree already owns the strict test:
`isonlydigit()` (`src/token.c:4162-4181`), which `get_text()` uses
(`src/scheduler.c:158`) and which is exactly why `getprop text` is the one arm
in this family that refuses loudly. Measured side by side:

```
getprop text 1.9  -> rc1 {xschem getprop: text object not found:1.9}
select  text 1.9  -> rc0 {1}   selection {{text 1 3 2}}
getprop text 1e2  -> rc1 {xschem getprop: text object not found:1e2}
select  text 1e2  -> rc0 {1}   selection {{text 1 3 2}}
```

The read and the write of the same object disagree about what an index *is*.

### `object` and `select` accept disjoint selector sets

For every type except `instance`, no string is accepted by both verbs and
resolves to the object the caller meant (Reproducer leg B):

| selector | `object wire <sel>` | `select wire <sel>` |
|---|---|---|
| `@132` | wire index 40 | **index 0**, returns 1 |
| `#40` | wire index 40 | **index 0**, returns 1 |
| `40` | `""` (the bare arm is instance-only, `:9057-9060`) | index 40, returns 1 |
| `OUTI` | `""` | **index 0**, returns 1 |
| `#abc` | **wire index 0**, full descriptor, rc 0 | **index 0**, returns 1 |

So a script cannot probe with `object` and act with `select` by passing the
selector through. It has to unpack the descriptor. That is exactly what the
shipped cookbook does, and why it has to.

The last row is the only one where the two verbs *agree* — on wire 0, which is
neither caller's referent. **`object`'s own `#` branch runs the same bare
`atoi`** (`src/scheduler.c:9044-9045` — `c = atoi(sel + 1); i = atoi(comma + 1);`
with no digit test and no `strtol` endptr), so `xschem object wire #abc` answers
`type wire index 0 layer 1 id 92 name {}` under rc 0. Only the `@` branch is
safe, and only by luck: `strtoul("abc", NULL, 10)` is 0 and no live object ever
carries id 0, so `object wire @abc` correctly answers `""`. The `#` hole matters
because the fix below proposes extracting that block as *the* resolver — extract
it as it stands and the coercion travels straight into `select <type> #<junk>`.

### The silent-failure property, precisely

Measured (leg C), on `select instance` with `@<id>`, `#<index>`, an unknown
name, an out-of-range index and `-1` — all five behave identically:

* **rc is `TCL_OK`.** `catch {xschem select instance @6}` returns 0.
* **`::errorCode` and `::errorInfo` are untouched** (reset to `{}` before the
  call, still `{}` after).
* **The selection is not cleared.** `xschem selection` and `xschem get lastsel`
  are byte-identical before and after.
* **Nothing is written anywhere.** `select_element()` writes its status /
  infowindow lines only inside `if( !(fast & 1) )` on the success path
  (`src/select.c:1493-1518`); the failure path in the dispatcher writes only the
  Tcl result. At `-d 3` the only trace is the command echo
  (`xschem():xschem select instance @6`) — no `dbg()` line, no status bar, no
  stderr.

So the only channel is the return value, and for six of the eight arms that
channel is **wrong** — `"1"`. For `instance`/`pin` the `"0"` is truthful, but a
caller that guards with `catch` rather than the value cannot see it. **That is
not hypothetical**: `hi_descend_current` in shipped Tcl guards exactly that way —

```tcl
if {[catch {xschem select instance $instname fast}]} {
  ciw_echo "hi_descend: cannot select $instname" error; return 0
}
```
— `src/xschem.tcl:8215-8217`. Measured: `catch {xschem select instance NOPE fast}`
returns **0**, so this guard can never fire and `hi_descend_finish` runs with
nothing selected. (`select_inst`, `src/xschem.tcl:5970-5973`, does it correctly:
it tests the returned value.)

Note *which* half reaches this call site. `hi_descend_current` calls
`xschem unselect_all` on the line before (`src/xschem.tcl:8214`), so the stale
selection cannot bite here — it descends into nothing rather than into the wrong
thing. The silent-failure half is what bites, and it bites unconditionally. The
stale-selection half needs a caller that does *not* clear first, which is every
hand-typed CIW line and the `reselect` recipe in the cookbook.

### The compound: the wrong object is deleted

`delete`, `copy`, `cut`, `hilight`, `zoom_selected` and `move_objects` take no
object reference at all — they act on the current selection
(`src/scheduler.c:3180-3181`, `:2979`, `:6379-6389`, `:14465-14470`,
`:8086-8110`). The selection is therefore the *only* channel from "which object"
to "the mutator", and a failed `select` leaves the previous occupant in it:

```
select instance R0     -> 1  selection {{instance 5 1 357}}  instances 117  modified 0
select instance @357   -> 0  selection {{instance 5 1 357}}   <- unchanged
delete                 ->  instances 116  modified 1   <- R0, the PREVIOUS referent, is gone
```

### It does not need a stale selection — or a handle

`setprop` and `getprop` reach the same bare `atoi` for the same types, with no
selection involved:

```
wire  0 lab before 'E9'      wire 40 lab before 'OUTI'
setprop wire @496 lab ZZZ  -> rc0 {}
wire  0 lab after  'ZZZ'   <- WRONG OBJECT MUTATED; rc 0, empty result
wire 40 lab after  'OUTI'
getprop wire @496 lab      -> rc0 {ZZZ}   <- the READ answers for wire 0 too
```

**And it does not need a sigil either.** The sharpest form of this has no `@`,
no `#` and no handle in it — just a net name where an index was expected, which
is the mistake a person actually makes at the CIW. In the fixture the wire
*named* `OUTI` is wire 40:

```
wire  0 lab before 'E9'      wire 40 lab before 'OUTI'
setprop wire OUTI lab ZAP  -> rc0 {}
wire  0 lab after  'ZAP'   <- the wire NAMED OUTI is wire 40; wire 0 was renamed
wire 40 lab after  'OUTI'
```

That matters for how this file is read: it is not a quarrel about handle syntax.
`atoi(argv[3])` (`src/scheduler.c:12847`) turns *any* leading non-digit into
index 0, and the bounds test the arm does perform — `n >= 0 && n < xctx->wires`
— then waves index 0 through as perfectly in range.

`getprop text` is the one arm in this family that routes through a resolver
(`get_text()`, `src/scheduler.c:5643`, defined `:155-169`) and it refuses loudly
— `xschem getprop: text object not found:@65`. `setprop text`, four hundred
lines away in the same file, uses `atoi` (`:12910`) and rewrites text 0.

### The sweep: who accepts `@<id>` and who does not

Derived from the source (every `get_instance` / `get_text` / `get_symbol` call
site, every object-index `atoi` arm, the `*_id` / `*_index` family, the `object`
selector block and `net_selector_token`), then **every verb named below was run**
on the fixture at its own correct arity — which is what the "measured" column
means. Arity matters: `translate @6` and `set_pin_type @6 0 in` look silent until
you notice the first never reaches `get_instance()` (`argc > 3` guard) and the
second takes the *type* as `argv[2]`, not the instance. **Not measured:** all 322
`argv[1]` verbs individually — only the reference-taking ones below.

| class | who | selector it accepts | `@<id>` → | measured |
|---|---|---|---|---|
| **sigil handle** | `object <type> <sel>` (`:9031-9060`) | `@id`, `#index`, `#layer,index`, and for `instance` also a bare index or name | resolves | yes |
| **index-or-name** | 29 verbs over 32 call sites through `get_instance()` (+ the `object` name fallback) — enumerated in the two sub-rows | all-digit index, or the instance name | `-1` | all 29 measured |
| ↳ of those, **loud** (22) | `drc_check`, `get_sch_from_sym`, `getprop`, `hilight_instname`, `inst_name_text`, `instance_bbox`, `instance_coord`, `instance_net`, `instance_number`, `instance_pin_coord`, `instance_pins`, `move_instance`, `pin_escape_normal`, `pinlist`, `print_spice_element`, `recompute_inst_bbox`, `replace_symbol`, `reset_inst_prop`, `reset_symbol`, `set_pin_type`, `setprop`, `translate` | | `TCL_ERROR "… instance not found"` | yes |
| ↳ of those, **silent** (7) | **`select`** (`"0"`), `descend` / `descend_symbol` (`"0"`), `instance_id` / `instance_pos` / `hilight_buried` (`-1`), `instance_nodemap` (`""`) | | no error | yes |
| **bare `atoi` index** | `select` wire/text/line/rect/poly/arc; `setprop` wire/text/rect/line/poly/arc; `getprop` wire/rect — 14 arms | array index (per-layer types: layer + index) | **index 0**, silently | yes |
| **bare stable id, no sigil** | `wire_index`, `instance_index`, `text_index`, `rect_index`, `line_index`, `poly_index`, `arc_index` | the id itself, undecorated | `-1` | yes |
| ↳ same convention, **different failure** | `highlight_scope <scope> <id>` (`:6287-6290`) | the id itself, undecorated | `""` under **rc 0** (`highlight_scope cell @6`); the one-word `highlight_scope @6` is a usage `TCL_ERROR` | yes |
| **`@` as a type keyword** | `net`, `net_members` via `net_selector_token()` (`:8224-8249`) — `@wire <id>`, `@inst <id> <pin>` | `@` prefixes the **type word**; the id that follows must be bare | `net @wire @41` → `""` | yes |
| **bare index → id** | `wire_id`, `text_id`, `rect_id`, `line_id`, `poly_id`, `arc_id` | array index | **index 0** (`wire_id @6` → `1`, i.e. wire 0's id) | yes |
| ↳ the exception | `instance_id` (`:6750-6764`) | array index **or** the instance name | `-1` — it is the one `*_id` verb that routes through `get_instance()`, not `atoi` | yes |

**Four incompatible conventions for the same id, in one dispatcher**, measured
side by side in leg F. `@41` works in `object`; the same id must be written
bare after `@wire` in `net`; bare again in `wire_index`; and in `select` it is
not an id at all.

The doc comment over `select` uses the word `id` for the array index —
*"for all other objects 'id' is the position in the respective arrays"*,
`src/scheduler.c:11585-11593` — which is the same word `object`, `selection`,
`objects`, `*_id` and `*_index` all use for the stable id.

### The resolver exists, three times, and `select` calls none of them

`object`'s handle branch is not a helper; it is **inline in the `object` arm**
(`src/scheduler.c:9032-9041`), dispatching to four functions in `src/store.c`:
`wire_index_from_id` (`:445`), `inst_index_from_id` (`:559`),
`text_index_from_id` (`:627`), `gfx_index_from_id` (`:638`, which also returns
the layer). The identical seven-case switch is written out twice more in
`src/select.c` — `pop_undo_keep_selection`'s reselect-by-id
(`:2607-2615`) and `select_placement_preview` (`:2739-2747`) — both of which
*do* select by stable id. So the engine already selects by handle in two
internal paths; the Tcl verb is the one place it does not, and the only reason
is that the selector parser was never factored out of the `object` arm.

### Reachability — GUI, not just scripts

**The CIW is enough.** `ciw_exec` (`src/ciw.tcl:227-263`) evaluates whatever the
user types, and both `select` and `object` are in the build-generated
autocomplete list (`src/xschem_subcommands.txt:181` and `:242`). Measured on
`:99` (Reproducer 2): a user who reads a handle out of `xschem object wire @41`
and types `xschem select wire @41` on the next line gets `1` echoed back and
wire 0 selected.

**No caller in this tree passes a handle to `select`** — measured, the only
four `select … @` hits anywhere under `tests/`, `src/*.tcl` and `doc/` are in
this issue's own provenance document (`:58`, `:61`, `:724`, `:737`; the pattern
must tolerate repeated spaces — `grep -rnE 'select +(\$[a-zA-Z_]+|[a-z]+) +@'` —
because `:61` is written `select wire  @41`). So the wrong-object arm is reached today
only by a hand-written command or a new script; the *silent-failure* arm is
reached by anything. The reference-passing callers that exist are:

* **shipped Tcl, 8 sites.** `src/property_form.tcl:837` is the interesting one:
  it holds stable ids and calls `xschem instance_index $id` first
  (`:836`) precisely because `select` cannot take the handle.
  `src/xschem.tcl:5801`, `:5970`, `:6029`, `:6052`, `:7977`, `:8215`, `:8267`
  pass names or indices. (A ninth `grep` hit, `src/xschem.tcl:7909`, is prose
  inside the comment block above `proc open_sub_schematic`, not a call.)
* **tests, 746 sites** under `tests/` (`grep -rn 'xschem select
  \(instance\|wire\|text\|rect\|line\|poly\|arc\|pin\)' tests/ | wc -l`). Every
  one passes an index or a name.
* **the action log does not use this verb.** An interactive click logs
  `xschem select_at <x> <y>` (`src/util.c:456-466`, stashed at
  `src/scheduler.c:11770`), never `select <type> <ref>`, so replay is unaffected.
* **the TCP server** (`setup_tcp_xschem`, `src/xschem.tcl:18035`) hands whatever
  arrives to the same evaluator the CIW uses, so it inherits the CIW's exposure
  exactly.
* `xschemtest.tcl` does not use the verb.

### `modified` staying 1 after `undo` is *not* a second defect

Measured: after the compound above, `xschem undo` restores 117 instances and
leaves `modified` at 1; so does `xschem undo 0 0`. That is designed. The undo
verb's second optional argument is `set_modify`, defaulting to 1
(`src/scheduler.c:1326-1328`), and it only controls whether the restore
*asserts* dirtiness. Verified on **both** undo backends: `mem_restore_slot`
ends with `if(set_modify_status) set_modify(1);`
(`src/in_memory_undo.c:587`) and the disk backend does the same
(`src/save.c:6367`) — and that is the *only* `set_modify` either of them makes.
Nothing on an undo path clears the flag. The clearers are elsewhere: `mod & 1`
is 0 for both `set_modify(0)` and `set_modify(2)` (`src/actions.c:192-193`,
the `2` form being the "clear the flag, skip the title/tab/sim-button refresh"
save path, `src/save.c:5759-5760`), plus the direct `xctx->modified = 0` on
context init (`src/xinit.c:765`). None of the three is reachable from `undo`.
The clean/dirty bit is not part of an undo slot — `Undo_slot` (`src/xschem.h`,
ending `:988`) has no `modified` field — so no undo can restore it.

The practical consequence for a caller trying to detect a wrong-object
mutation: `modified` is monotone within a session and useless as a differ,
and `xctx->modify_seq` — the counter that *is* right for the job
(`src/xschem.h:1754`, issue 0267) — has no Tcl accessor at all.

## Reproducer

Self-contained, no PDK, no simulator, no display, no write under `~/.xschem`
(`::USER_CONF_DIR` is redirected and the recent-files/raw-history writers are
stubbed). Nothing is ever saved; the fixture is reloaded between mutating legs.
Save as `/tmp/repro_0520.tcl` and run from the repo root:

```sh
mkdir -p /tmp/repro_0520conf
./src/xschem --nogui --pipe -q --script /tmp/repro_0520.tcl
```

```tcl
# 0520 reproducer -- `xschem select <type> @<id>` vs the handle `xschem object`
# hands out.  Read-only on disk: nothing is saved, the fixture is reloaded
# between legs, and no file under ~/.xschem is touched.
set ::USER_CONF_DIR /tmp/repro_0520conf         ;# never ~/.xschem
set ::update_recent_files 0
proc write_recent_file {args} {} ; proc update_recent_file {args} {} ; proc rawhist_write {args} {}
proc p {s} {puts $s; flush stdout}
proc try {args} { set rc [catch {uplevel 1 [list xschem {*}$args]} r]
                  return [format "rc%d {%s}" $rc [string range $r 0 46]] }
set FIX [file normalize xschem_library/examples/mos_power_ampli.sch]

# Stable ids are per SESSION and keep counting across loads, so each LEG
# re-derives its handles after its reload.  Never hardcode one.
proc fresh {} {
  global FIX IID WID TID
  xschem load $FIX ; xschem unselect_all
  set IID [dict get [xschem object instance #5] id]
  set WID [dict get [xschem object wire     #40] id]
  set TID [dict get [xschem object text     #1]  id]
}
proc clr {} { xschem unselect_all }          ;# between rows: select only, no reload

fresh
p "fixture [file tail $FIX]: instances [xschem get instances]  wires [xschem get wires]\
  texts [xschem get texts]  objects [llength [xschem objects]]"
p "handles in THIS leg: instance #5 = @$IID   wire #40 = @$WID   text #1 = @$TID"

p ""
p "=== A. `object` resolves the handle; `select` fails, two different ways ==="
p [format "  %-30s -> %s" "object instance @$IID" [xschem object instance @$IID]]
p [format "  %-30s -> %s" "object wire @$WID" [xschem object wire @$WID]]
p [format "  %-30s -> %s" "object text @$TID" [xschem object text @$TID]]
p ""
foreach {t sel note} [list instance {@$IID} "silent no-op, and 0 IS the failure signal" \
                           instance {#5}    "the # index form fails too" \
                           instance 5       "bare index works" \
                           instance R0      "name works" \
                           wire     {@$WID} "WRONG WIRE, and rc says success" \
                           wire     {#40}   "ditto" \
                           wire     NOSUCH  "ditto -- a LEADING non-digit is index 0" \
                           wire     40      "bare index works" \
                           text     {@$TID} "WRONG TEXT, and rc says success"] {
  clr ; set s [subst $sel]
  p [format "  select %-8s %-7s -> %s  selection {%-18s}  %s" $t $s [xschem select $t $s] [xschem selection] $note]
}
p ""
p "  atoi is a PREFIX parse, not a numeric test -- a LEADING digit truncates:"
foreach {s note} [list 40x  "trailing junk dropped -> 40" \
                       40.9 "the fraction is dropped -> 40" \
                       1e2  "NOT 100: atoi stops at the 'e' -> 1" \
                       0x   "-> 0, same as any leading non-digit" \
                       -1   "the ONLY refused input: caught by the n >= 0 bounds test"] {
  clr
  p [format "  select wire     %-7s -> %s  selection {%-18s}  %s" $s [xschem select wire $s] [xschem selection] $note]
}
clr
p [format "  select %-8s %-7s -> %s" rect @$WID [try select rect @$WID]]
p "     ^ rect/line/poly/arc take <layer> <index>, so the one-word handle form"
p "       trips the arity guard and at least ERRORS."

p ""
p "=== B. for a wire, `object` and `select` accept DISJOINT selector sets ==="
fresh
p [format "  %-7s  %-45s  %s" selector "object wire <sel>" "select wire <sel> -> selection"]
foreach sel {{@$WID} {#40} 40 OUTI {#abc}} {
  clr ; set s [subst $sel]
  set o [xschem object wire $s]
  set r [xschem select wire $s]
  p [format "  %-7s  %-45s  %s -> {%s}" $s "{$o}" $r [xschem selection]]
}
p "  No string is accepted by both AND resolves to the wire the caller meant."
p "  The LAST row is the one where they AGREE -- on wire 0, which is neither's"
p "  referent: the `#` branch of the `object` selector runs the same bare atoi,"
p "  so `object` ITSELF coerces a malformed index to 0 and hands back a full,"
p "  authoritative-looking descriptor under rc 0."

p ""
p "=== C. what a caller can see when it fails ==="
fresh ; xschem select instance R0
p "  armed on R0:           selection {[xschem selection]}  lastsel [xschem get lastsel]"
set ::errorCode {} ; set ::errorInfo {}
set rc [catch {xschem select instance @$IID} r]
p "  select instance @$IID:   catch -> $rc   result -> '$r'   errorCode '$::errorCode'   errorInfo '$::errorInfo'"
p "  after the failure:     selection {[xschem selection]}  lastsel [xschem get lastsel]   <- STILL ARMED"
foreach bad {{@$IID} {#5} NOSUCH 99999 -1} {
  clr ; xschem select instance R0 ; set b [subst $bad]
  p [format "    select instance %-7s -> %s   selection after {%s}" $b [try select instance $b] [xschem selection]]
}
p "  and additivity -- which candidate (b) would break -- survives a failure:"
clr ; xschem select instance R0 ; xschem select instance NOSUCH ; xschem select wire 40
p "    select instance R0 / select instance NOSUCH / select wire 40"
p "      -> selection {[xschem selection]}  ([llength [xschem selection]] rows: the failure was SKIPPED, not fatal)"

p ""
p "=== D. the data-loss compound: the wrong object is deleted ==="
fresh
p "  select instance R0     -> [xschem select instance R0]  selection {[xschem selection]}  instances [xschem get instances]  modified [xschem get modified]"
p "  select instance @$IID    -> [xschem select instance @$IID]  selection {[xschem selection]}   <- unchanged"
xschem delete
p "  delete                 ->  instances [xschem get instances]  modified [xschem get modified]   <- R0, the PREVIOUS referent, is gone"
xschem undo
p "  undo                   ->  instances [xschem get instances]  modified [xschem get modified]"
xschem undo 0 0
p "  undo 0 0               ->  instances [xschem get instances]  modified [xschem get modified]   <- no undo path CLEARS the flag"

p ""
p "=== E. no stale selection needed: setprop takes the same bare atoi ==="
fresh
p "  wire  0 lab before '[xschem getprop wire 0 lab]'      wire 40 lab before '[xschem getprop wire 40 lab]'"
p "  setprop wire @$WID lab ZZZ  -> [try setprop wire @$WID lab ZZZ]"
p "  wire  0 lab after  '[xschem getprop wire 0 lab]'   <- WRONG OBJECT MUTATED; rc 0, empty result"
p "  wire 40 lab after  '[xschem getprop wire 40 lab]'"
p "  getprop wire @$WID lab      -> [try getprop wire @$WID lab]   <- the READ answers for wire 0 too"
p ""
p "  and it needs no HANDLE either -- a plain net-name typo is enough:"
fresh
p "  wire  0 lab before '[xschem getprop wire 0 lab]'      wire 40 lab before '[xschem getprop wire 40 lab]'"
p "  setprop wire OUTI lab ZAP   -> [try setprop wire OUTI lab ZAP]"
p "  wire  0 lab after  '[xschem getprop wire 0 lab]'   <- the wire NAMED OUTI is wire 40; wire 0 was renamed"
p "  wire 40 lab after  '[xschem getprop wire 40 lab]'"
fresh
p "  getprop text @$TID txt_ptr      -> [try getprop text @$TID txt_ptr]"
p "     ^ getprop text routes through get_text(): LOUD.  setprop text does not:"
p "  setprop text @$TID txt_ptr ZZZ  -> [try setprop text @$TID txt_ptr ZZZ]"
p "  text 0 after '[string range [xschem getprop text 0 txt_ptr] 0 21]'   text 1 after '[xschem getprop text 1 txt_ptr]'"

p ""
p "=== F. four id conventions live in the same dispatcher ==="
fresh
p "  1 sigil          object wire @$WID   -> [try object wire @$WID]"
p "  2 keyword, bare  net @wire $WID      -> [try net @wire $WID]"
p "                   net @wire @$WID     -> [try net @wire @$WID]"
p "  3 bare id        wire_index $WID     -> [try wire_index $WID]"
p "                   wire_index @$WID    -> [try wire_index @$WID]"
p "  4 bare index     select wire 40        -> [try select wire 40]"
p "                   wire_id 40           -> [try wire_id 40]   (index -> id)"
p ""
p "DONE"
exit 0
```

Actual output, `src/xschem` built 2026-08-19 18:16, HEAD `722ce61e`. Two
consecutive runs were byte-identical.

```
fixture mos_power_ampli.sch: instances 117  wires 91 texts 9  objects 225
handles in THIS leg: instance #5 = @6   wire #40 = @41   text #1 = @2

=== A. `object` resolves the handle; `select` fails, two different ways ===
  object instance @6             -> type instance index 5 layer 1 id 6 name {R0}
  object wire @41                -> type wire index 40 layer 1 id 41 name {}
  object text @2                 -> type text index 1 layer -1 id 2 name {}

  select instance @6      -> 0  selection {                  }  silent no-op, and 0 IS the failure signal
  select instance #5      -> 0  selection {                  }  the # index form fails too
  select instance 5       -> 1  selection {{instance 5 1 6}  }  bare index works
  select instance R0      -> 1  selection {{instance 5 1 6}  }  name works
  select wire     @41     -> 1  selection {{wire 0 1 1}      }  WRONG WIRE, and rc says success
  select wire     #40     -> 1  selection {{wire 0 1 1}      }  ditto
  select wire     NOSUCH  -> 1  selection {{wire 0 1 1}      }  ditto -- a LEADING non-digit is index 0
  select wire     40      -> 1  selection {{wire 40 1 41}    }  bare index works
  select text     @2      -> 1  selection {{text 0 3 1}      }  WRONG TEXT, and rc says success

  atoi is a PREFIX parse, not a numeric test -- a LEADING digit truncates:
  select wire     40x     -> 1  selection {{wire 40 1 41}    }  trailing junk dropped -> 40
  select wire     40.9    -> 1  selection {{wire 40 1 41}    }  the fraction is dropped -> 40
  select wire     1e2     -> 1  selection {{wire 1 1 2}      }  NOT 100: atoi stops at the 'e' -> 1
  select wire     0x      -> 1  selection {{wire 0 1 1}      }  -> 0, same as any leading non-digit
  select wire     -1      -> 0  selection {                  }  the ONLY refused input: caught by the n >= 0 bounds test
  select rect     @41     -> rc1 {xschem select: missing arguments.}
     ^ rect/line/poly/arc take <layer> <index>, so the one-word handle form
       trips the arity guard and at least ERRORS.

=== B. for a wire, `object` and `select` accept DISJOINT selector sets ===
  selector  object wire <sel>                              select wire <sel> -> selection
  @132     {type wire index 40 layer 1 id 132 name {}}    1 -> {{wire 0 1 92}}
  #40      {type wire index 40 layer 1 id 132 name {}}    1 -> {{wire 0 1 92}}
  40       {}                                             1 -> {{wire 40 1 132}}
  OUTI     {}                                             1 -> {{wire 0 1 92}}
  #abc     {type wire index 0 layer 1 id 92 name {}}      1 -> {{wire 0 1 92}}
  No string is accepted by both AND resolves to the wire the caller meant.
  The LAST row is the one where they AGREE -- on wire 0, which is neither's
  referent: the `#` branch of the `object` selector runs the same bare atoi,
  so `object` ITSELF coerces a malformed index to 0 and hands back a full,
  authoritative-looking descriptor under rc 0.

=== C. what a caller can see when it fails ===
  armed on R0:           selection {{instance 5 1 240}}  lastsel 1
  select instance @240:   catch -> 0   result -> '0'   errorCode ''   errorInfo ''
  after the failure:     selection {{instance 5 1 240}}  lastsel 1   <- STILL ARMED
    select instance @240    -> rc0 {0}   selection after {{instance 5 1 240}}
    select instance #5      -> rc0 {0}   selection after {{instance 5 1 240}}
    select instance NOSUCH  -> rc0 {0}   selection after {{instance 5 1 240}}
    select instance 99999   -> rc0 {0}   selection after {{instance 5 1 240}}
    select instance -1      -> rc0 {0}   selection after {{instance 5 1 240}}
  and additivity -- which candidate (b) would break -- survives a failure:
    select instance R0 / select instance NOSUCH / select wire 40
      -> selection {{instance 5 1 240} {wire 40 1 223}}  (2 rows: the failure was SKIPPED, not fatal)

=== D. the data-loss compound: the wrong object is deleted ===
  select instance R0     -> 1  selection {{instance 5 1 357}}  instances 117  modified 0
  select instance @357    -> 0  selection {{instance 5 1 357}}   <- unchanged
  delete                 ->  instances 116  modified 1   <- R0, the PREVIOUS referent, is gone
  undo                   ->  instances 117  modified 1
  undo 0 0               ->  instances 117  modified 1   <- no undo path CLEARS the flag

=== E. no stale selection needed: setprop takes the same bare atoi ===
  wire  0 lab before 'E9'      wire 40 lab before 'OUTI'
  setprop wire @496 lab ZZZ  -> rc0 {}
  wire  0 lab after  'ZZZ'   <- WRONG OBJECT MUTATED; rc 0, empty result
  wire 40 lab after  'OUTI'
  getprop wire @496 lab      -> rc0 {ZZZ}   <- the READ answers for wire 0 too

  and it needs no HANDLE either -- a plain net-name typo is enough:
  wire  0 lab before 'E9'      wire 40 lab before 'OUTI'
  setprop wire OUTI lab ZAP   -> rc0 {}
  wire  0 lab after  'ZAP'   <- the wire NAMED OUTI is wire 40; wire 0 was renamed
  wire 40 lab after  'OUTI'
  getprop text @65 txt_ptr      -> rc1 {xschem getprop: text object not found:@65}
     ^ getprop text routes through get_text(): LOUD.  setprop text does not:
  setprop text @65 txt_ptr ZZZ  -> rc0 {}
  text 0 after 'ZZZ'   text 1 after '@name'

=== F. four id conventions live in the same dispatcher ===
  1 sigil          object wire @769   -> rc0 {type wire index 40 layer 1 id 769 name {}}
  2 keyword, bare  net @wire 769      -> rc0 {name {OUTI} nwires 8 npins 7 anchor {inst 1035 }
                   net @wire @769     -> rc0 {}
  3 bare id        wire_index 769     -> rc0 {40}
                   wire_index @769    -> rc0 {-1}
  4 bare index     select wire 40        -> rc0 {1}
                   wire_id 40           -> rc0 {769}   (index -> id)

DONE
```

The stable ids climb between legs (`@6` → `@132` → `@240` …) because each leg
reloads the fixture and ids keep counting for the life of the session. That is
correct behaviour, and it is why the script derives every handle after its own
reload instead of hardcoding one.

## Reproducer 2 — the GUI route

The same defect with no script written: the CIW is a Tcl evaluator and both
verbs are in its autocomplete list. Save as `/tmp/repro_0520_gui.tcl`, run on
the dev display (`tests/headless/devdisplay.sh start` first):

```sh
DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --script /tmp/repro_0520_gui.tcl
```

```tcl
# 0520 leg G -- the GUI route: the CIW is a Tcl evaluator with `select` and
# `object` in its autocomplete list, so a user reaches this with no script.
set ::USER_CONF_DIR /tmp/repro_0520conf         ;# never ~/.xschem
set ::update_recent_files 0
proc write_recent_file {args} {} ; proc update_recent_file {args} {} ; proc rawhist_write {args} {}
proc p {s} {puts $s; flush stdout}
xschem load [file normalize xschem_library/examples/mos_power_ampli.sch]
ciw_create ; update idletasks ; update
proc ciw_type {cmd} {                      ;# type it, press Return, read the log pane back
  .ciw.c.e delete 1.0 end ; .ciw.c.e insert 1.0 $cmd
  set n [expr {int([lindex [split [.ciw.l.t index end] .] 0])}]
  ciw_exec ; update idletasks ; update
  return [string trim [.ciw.l.t get $n.0 end]]
}
set WID [dict get [xschem object wire #40] id]
set IID [dict get [xschem object instance #5] id]
p ""
p "user types:  xschem object wire @$WID"
p "CIW echoes:  [ciw_type "xschem object wire @$WID"]"
xschem unselect_all
p "user types:  xschem select wire @$WID"
p "CIW echoes:  [ciw_type "xschem select wire @$WID"]      <- reads as success"
p "really got:  [xschem selection]   (wire index [lindex [lindex [xschem selection] 0] 1], id [lindex [lindex [xschem selection] 0] 3])"
p ""
xschem unselect_all ; xschem select instance R0
p "armed on R0: [xschem selection]"
p "user types:  xschem select instance @$IID"
p "CIW echoes:  [ciw_type "xschem select instance @$IID"]"
p "really got:  [xschem selection]   <- unchanged; the next Delete hits R0"
p "DONE"
exit 0
```

Actual output, dev display `:99` (Xvfb 1920x1080x24 + openbox), same binary:

```
user types:  xschem object wire @41
CIW echoes:  type wire index 40 layer 1 id 41 name {}
user types:  xschem select wire @41
CIW echoes:  1      <- reads as success
really got:  {wire 0 1 1}   (wire index 0, id 1)

armed on R0: {instance 5 1 6}
user types:  xschem select instance @6
CIW echoes:  0
really got:  {instance 5 1 6}   <- unchanged; the next Delete hits R0
```

The process was killed by its own `exit 0`; nothing is left running.

## Why it matters

1. **A shipped, documented API round-trips through a verb that cannot read its
   own output.** `doc/handles_cookbook.md` — the hands-on manual for this
   feature — opens with a nine-line helper whose only job is to work around this:

   ```tcl
   proc select_descriptor {o} {
     set t [dict get $o type]; set i [dict get $o index]; set l [dict get $o layer]
     switch $t {
       wire - instance - text    { xschem select $t $i }
       rect - line - poly - arc   { xschem select $t $l $i }
     }
   }
   ```
   — `doc/handles_cookbook.md:33-39`. Every recipe in that file calls it
   (`:60`, `:164`), and the quick-reference table honestly records the reason:
   `xschem select <type> <index>` (`:277`), no handle form. `select_descriptor`
   exists solely because the resolver was never factored out of the `object`
   arm. The same workaround is in shipped Tcl —
   `src/property_form.tcl:836-837` converts a stable id through
   `xschem instance_index` before it can select.
2. **The documentation being correct is not a defence.** The docs already say
   index-only, and the trap fires anyway, because six of the eight arms accept
   *any* string and turn it into index 0. Measured:
   `xschem select wire NOSUCHNAME` returns `1`. A user or an agent that reads
   the descriptor `{type wire index 40 layer 1 id 41}` and reaches for the `id`
   field — the field the whole feature is named after — gets wire 0 under a
   success code.
3. **The mutators cannot help.** `delete`, `copy`, `cut`, `hilight`,
   `move_objects` and `zoom_selected` take no reference at all. There is no
   second chance to name the object; whatever the last successful `select` left
   in the selection is what they act on. That is what turns a failed
   *reference* into a lost *object*, and rc is 0 the whole way through.
4. **One shipped guard is already dead because of it.**
   `hi_descend_current`'s `catch` (`src/xschem.tcl:8215-8217`) was written to
   catch exactly this failure and can never fire, because `select` returns a
   value instead of an error. Whatever a future caller writes, half of them will
   guess the wrong one of the two conventions until the verb picks one.
5. **The inconsistency is the defect, not the individual arm.** In one
   dispatcher, the same stable id is written `@41` (`object`), `41` after a
   keyword (`net @wire 41`), `41` bare (`wire_index 41`), and is not accepted at
   all (`select`, `setprop`). `getprop text @2` refuses loudly while
   `setprop text @2` rewrites text 0 — the read and the write of the same
   attribute on the same object disagree about what a selector is.

## Fix — candidates in order

**(a) Route every reference-taking arm through one resolver — recommended.**
Extract `src/scheduler.c:9031-9060` (the `object` arm's selector block, 30
lines) into `static int object_index_from_selector(int type, const char *sel,
int *layer_out)`, forward-declared beside `object_type_from_name` and
`object_descriptor` at `:214-215` — the pattern already used for cross-group
helpers — and call it from the eight `select` arms (`:11620-11703`). `object`
itself becomes a two-line call, so the two verbs cannot drift again. The
resolver already returns the layer for the per-layer types
(`gfx_index_from_id`, `src/store.c:638`), so `xschem select rect @705` needs no
layer word; that means the arity guard at `:11603-11607` has to become
selector-aware — accept `argc == 4` for `rect`/`line`/`poly`/`arc` when
`argv[3]` starts with `@`, keep requiring five words otherwise. That guard is
the only fiddly part.
*Size:* `src/scheduler.c` only, ~60 lines changed, no header, no new file.
Extending it to the eight `setprop`/`getprop` arms (`:12756-12757`, `:12847`,
`:12910`, `:13003-13004`, `:13043-13044`, `:13087-13088`, `:5626-5627`, `:5663`)
is another ~40 lines and closes the `setprop wire @<id>` mutation and the
`getprop text` / `setprop text` disagreement; **do both, or the feature is still
half-present.**

**Compatibility — and the trap in the word "extract".** Lifting `:9031-9060`
*verbatim* and calling it from the eight `select` arms would regress the suite on
day one, because the `object` selector's bare arm is not the one `select` has:

```c
} else {                                  /* by name (instance only) */
  if(type == ELEMENT) { i = get_instance(sel); c = WIRELAYER; }
  else i = -1;                            /* <- src/scheduler.c:9059 */
}
```

A bare index falls through to `get_instance()` **only for `ELEMENT`**; every
other type gets `i = -1`. That is why leg B's third row reads
`object wire 40` → `""` while `select wire 40` → index 40, and why
`object text 1` is `""` while `select text 1` selects text 1 — measured, both
ways. So the extraction has to *widen* the bare arm as it moves, not copy it:

* **bare all-digit → array index, for every type**, bounds-checked exactly as the
  `#` arm already does at `:9047-9056`. Without this, `select wire 40`,
  `select text 0` and `select rect 5 2` all break — the **159** non-`instance`,
  non-`pin` call sites under `tests/` (wire 91, text 23, rect 42, line 1, poly 1,
  arc 1) plus `doc/handles_cookbook.md`'s own `select_descriptor`.
* **bare name → instance name**, `ELEMENT` only, as today.
* **the two-word `<layer> <index>` form has no counterpart in the `object`
  selector at all.** `object rect 5,2` is `""`; only `#5,2` is understood. The
  `rect`/`line`/`poly`/`arc` arms therefore keep their positional path and reach
  the resolver only when `argv[3]` carries a sigil.
* **fix the `#` arm's own `atoi` while it is being moved** (`:9044-9045`), or the
  index-0 coercion is carried into `select <type> #<junk>` rather than removed
  from it. `isonlydigit()` (`src/token.c:4162-4181`) is the test the tree
  already uses for this, in `get_text()` (`src/scheduler.c:158`).

With those four, every existing form keeps working: the **746** `select` call
sites under `tests/` (572 `instance`, 159 the six index types, 18 `pin`) and the
**8** shipped Tcl call sites all pass a bare index or a bare name, and every
literal one of them is all-digit.

**(b) Make a failed `select` clear the selection — not recommended, and the
hazard is concrete.** `select` is additive by design and the tree relies on it:
`tests/bus_transpose.tcl:96-98` builds a three-type selection with three
consecutive `select` calls, and `doc/handles_cookbook.md:53-63`'s `reselect`
loops one `select` per handle, *deliberately skipping* the handles that no
longer resolve — its documented return value is "how many of the handles were
still live" — and note it opens with `xschem unselect_all` (`:54`), so
additivity is exactly what makes the loop accumulate at all. Measured (leg C):
`select instance R0` / `select instance NOSUCH` / `select wire 40` leaves 2 rows
selected, the failure skipped. Clearing on
failure would wipe the N−1 objects already selected the first time one handle
went stale, i.e. it would break the single recipe this API was built for.
Clearing is the wrong lever.

**(c) Return a distinguishable error — recommended *alongside* (a), not instead
of it.** The right split is by *shape*, not by resolution: a selector that
cannot possibly be an index or a name for that type — a leading `@` or `#` that
does not resolve, or (for the `atoi` types) a string that is not an index at all
— should be `TCL_ERROR` with the text every `get_instance` caller already emits,
while a well-formed but absent reference keeps returning `"0"`. That preserves
`select_inst`'s value test (`src/xschem.tcl:5972`) and revives
`hi_descend_current`'s `catch` (`:8215`) at the same time. Without (a) this is
only a warning label; with (a) it is what stops the *next* bare `atoi` from
being added. *Size:* ~15 lines, same file, on top of (a).

**Pick the strictness deliberately.** `isonlydigit()` (`src/token.c:4162-4181`,
which allows a leading `-`) is the obvious test and is what `get_text()` uses —
but dropping it in *widens* the refusal set beyond the defect. Measured, these
succeed today and would newly become errors: `select wire 40x` → 40,
`select wire 40.9` → 40, `select wire 1e2` → **1**. Nothing in `tests/` or
`src/*.tcl` passes such a string (every literal argument is all-digit; the rest
are Tcl variables holding indices), so tightening is *available* — but it is a
second, separable decision and should be stated as one, not smuggled in as "make
`atoi` strict". The narrow version — error only on a leading `@` or `#` that did
not resolve — closes the reported defect and changes nothing else.

**(d) Document that `select` takes name-or-index only — provably not enough.**
It is already documented that way, twice: `src/scheduler.c:11589-11590` and
`doc/handles_cookbook.md:277`. Both were written before this measurement and
neither prevents `xschem select wire NOSUCHNAME` from returning `1`. A doc
cannot make `atoi` fail. What a doc pass *should* add — and this is worth doing
regardless — is fixing the word `id` in `src/scheduler.c:11585-11593`, where it
means "array index" while the same word means "stable id" in `object`,
`objects`, `selection`, `<type>_id` and `<type>_index`.

## Coverage

Nothing in the tree asserts any of this. `tests/stable_handles/` — 219 checks
across six `*_body.tcl` files, the suite that owns the handle feature — never
passes a handle to `select`; every `select` in it is positional
(`tests/stable_handles/gfx_body.tcl:137`, `:148`, `:161`, …). Across all of
`tests/` there are **746** `xschem select <type> <ref>` call sites and **zero**
use the `@` form, so no existing check can go red on this.

A test must assert:

1. **The round-trip closes, per type.** For all seven drawable types: read
   `xschem object <type> #<index>`, take its `id`, and assert
   `xschem select <type> @<id>` returns 1 **and** that
   `lindex [xschem selection] 0` names that same `index`/`id`. Asserting only
   the return value is exactly the hole that exists today — `select wire @41`
   already returns 1.
2. **The failure is a failure.** `select <type> @<nonexistent-id>` must not
   select anything, and must be distinguishable from success by the mechanism
   the fix chooses (value or error). Include `#<index>`, an out-of-range index
   and a non-numeric string, and assert for each of the six `atoi` types that
   the selection did **not** become index 0. *"Not index 0" is necessary but not
   sufficient* — `select wire 1e2` lands on wire **1**, so a fix that merely
   moved the coercion would pass that assertion. Start from `unselect_all` and
   assert the selection is **empty** after the failing select — not merely "not
   index 0", and not "cleared", which is item 4's business. Include `@<junk>`,
   `#<junk>` and a leading-digit string (`40x`, `40.9`, `1e2`) in the malformed
   set; if the fix takes the narrow option in candidate (c), record in the check
   which of those are expected to keep succeeding, so the strictness decision is
   asserted rather than assumed. Cover
   `object <type> #<junk>` in the same group: it answers a full index-0
   descriptor under rc 0 today, and it is the block the fix extracts.
3. **The previous selection is not inherited.** Arm a known object, issue a
   failing `select`, then `xschem delete`, then assert the object count and the
   surviving instance names. A check that stops at `xschem selection` after the
   failed select passes even in the shipped binary — the defect only becomes
   visible when the mutator runs.
4. **Additivity survives the fix.** Select three objects of three types, with a
   failing `select` in the middle, and assert three rows minus the failure — the
   check that makes candidate (b) impossible to ship by accident.
5. **`setprop`/`getprop` are in the same bound.** `setprop wire @<id> lab ZZZ`
   must not touch wire 0; `getprop wire @<id> lab` must not answer for wire 0;
   and `getprop text @<id>` / `setprop text @<id>` must agree with each other.
   Assert the *neighbour* object's attribute is unchanged, not just that the
   target's changed — the shipped bug leaves the target untouched and is
   invisible to a target-only check.
   **Include the sigil-free form.** A check built only from `@<id>` strings would
   go green against a fix that special-cased `@` and `#` and left `atoi` in
   place, and the sharpest case has no sigil in it: measured,
   `setprop wire OUTI lab ZAP` — a plain net-name typo, the mistake a person
   actually makes — returns rc 0 with an empty result and renames **wire 0**.
   Assert that a non-index, non-`@`, non-`#` selector mutates nothing. Do the
   same for `select`: `select wire NOSUCHNAME` must not select wire 0.
6. **The set of arms is closed.** A check that walks a hand-written list of
   seven types goes green the day an eighth reference-taking arm is added with a
   fresh `atoi`. Derive the type list from `xschem objects` (or from the same
   table `object_type_from_name` uses) so a new type cannot skip the bound.
7. **Sabotage direction:** revert one arm to `atoi(argv[3])` and only that arm's
   rows may go red; the other six stay green. Two disjoint red sets are the
   proof the check is per-arm and not a single round-trip that happens to
   exercise one path — the same argument `tests/headless/test_results_select.tcl`
   groups A/B make for issue 0509's twice-written branch.

Environment note: stable ids are session counters, not file constants. Every
check must derive its handle from a live `xschem object … #<index>` after its
own load, exactly as the reproducer does; a hardcoded `@41` goes red the first
time a fixture is loaded twice in one process.

## Related

- `doc/claude/suggestions/voice_control_natural_language_plan.md` (commit
  `722ce61e`) — where this was first measured, as correction 2 (`:52-64`) and
  hazard **R2** (`:717-742`). Its item **V4** (`:652`) proposes candidate (a).
  Nothing in this issue depends on that plan: the defect is in a shipped API and
  bites any caller.
- issue **0519** — *the TCP command server kills the editor three ways, every one
  answers like success, and one of the three needs no socket*. Filed the same day
  from the same design pass (its §8 R1). It is the channel this defect is worst
  on: `select`'s `"0"` / `"1"` is the only failure signal there is, and
  `xschem_getdata` replies with `catch`'s variable while dropping the return code
  it computed one line earlier (`src/xschem.tcl:5865`, `:5886-5887`), so a Tcl
  error and a Tcl result come back as the same bytes. The *Reachability* note
  above says the TCP server "inherits the CIW's exposure exactly": that holds for
  **which** commands can be issued — both evaluate with `uplevel #0` in the same
  interpreter (`src/xschem.tcl:5865`, `src/ciw.tcl:254`) — and not for what comes
  back. `ciw_exec` keeps the code and tags the two apart (`ciw_echo $res error`
  vs `ciw_echo $res result`, `src/ciw.tcl:258-261`) and captures the command's
  `puts` into the log pane (`:247-248`, spec
  `doc/claude/specs/ciw_puts_capture.md`); the socket does neither — 0519
  measures `puts $XSCHEM_LIBRARY_PATH` answering the empty string over the wire.
  So a wrong-object `select` is *less* visible over the socket than at the CIW,
  not equally visible. 0519 also names **0004** (*the TCP command server has no
  authentication and binds all interfaces*, OPEN since 2026-06-11) for who may
  reach that channel at all.
- `doc/handles_cookbook.md` — `select_descriptor` (`:33-39`) is the workaround in
  the shipped documentation; the quick-reference table (`:277`) records that
  `select` is positional.
- `doc/object_query_api.md`, `doc/stable_instance_handles.md`,
  `doc/stable_wire_handles.md`, `doc/stable_graphical_handles.md` — the per-type
  manuals for the handle the `select` verb cannot read. (None of these `.md`
  files is installed; `doc/Makefile:9-10` ships only `*.svg/*.html/*.css/*.png`.)
- `doc/claude/code_analysis/stable_handles_extension_strategy.md` — the
  architecture note this feature was built from. There is **no**
  `doc/claude/specs/` file for stable handles; this note and
  `doc/claude/suggestions/plan_stable_handles_step1.md` (the executed step-1
  plan, wires) are what stand in for one. Its §3c seam table names exactly the
  helper candidate **(a)** proposes — *"Validated object-arg resolver
  (`(type,index) → checked (i,col)`)"*, to be extracted *"when the next command
  parses an object index"*, killing *"defects #1/#2 + boilerplate"* (`:142`) —
  and §3d rules that the object-reference **convention** be locked early, so the
  next verbs *"follow it instead of inventing three more formats to reconcile
  later"* (`:145-153`). Both of its own triggers are met here: this issue counts
  four live conventions for one id and three hand-written copies of the same
  seven-case switch (`src/scheduler.c:9032-9041`, `src/select.c:2607-2615`,
  `:2739-2747`).
- `src/select.c:2607-2615` (`pop_undo_keep_selection`) and `:2739-2747`
  (`select_placement_preview`) — the engine already selects by stable id, twice,
  with the same seven-case switch candidate (a) would factor out.
- issue **0077** — the bounds checks added to `getprop rect` / `getprop wire`
  (`src/scheduler.c:5628-5634`, `:5663-5667`). They stopped the out-of-range
  *read*; they did not question what `atoi` does to an in-range-looking string.
- issue **0267** — `xctx->modify_seq` (`src/xschem.h:1754`), the counter that
  would let a caller detect an unintended mutation. It has no Tcl accessor, so
  `xschem get modified` (monotone within a session) is all a script has.
