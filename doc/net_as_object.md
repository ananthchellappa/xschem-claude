# Net as an object — `xschem net` / `xschem nets` / `xschem net_members`

*Hold a durable reference to "this net" across edits, and read its membership
by handle — even though a net has no struct, no array, and no id of its own.*

This is the net-level companion to the per-object stable handles
([`stable_wire_handles.md`](stable_wire_handles.md),
[`stable_instance_handles.md`](stable_instance_handles.md), …) and the uniform
[`object_query_api.md`](object_query_api.md). Those gave each *stored* object a
durable id; this gives you a durable way to name and read a **net**, which is
not stored at all.

Every code block below was run against a real build (see
`doc/claude/code_analysis/introspection_probes/probe7.tcl`).

---

## 1. Why a net is different

Wires, instances and shapes are *stored* — a struct in an array you can stamp
with an id. **A net is not.** A net is a *derived equivalence class* of
electrically-connected wire segments and pins, recomputed from scratch every
time connectivity is rebuilt. Its only identity today is a **string token** —
the net name — and that name is **derived and unstable**:

- it changes when you rename the driving label (to rename a net you edit a label
  *instance*, and the net name follows — the "authority" rule);
- two different nets at different hierarchy levels can share a token.

So a net name is the wrong thing to hold across edits, exactly as an instance
*name* was. The fix is the same: hold a **stable handle** and let the name be
the human form.

## 2. The idea: anchor on a stored object

A net's durable handle *is* the stable id of a wire or label-instance **on**
it — an *anchor*. You hold the anchor (a `wire_id` / `instance_id`, already
stable from steps 1-2); resolving it re-runs connectivity and gives you the
net's **current** token and members.

```tcl
xschem net @wire 1          ;# the net the wire with stable id 1 is on
;# -> name {MYNET} nwires 1 npins 1 anchor {inst 1 p}

xschem net @inst 1 p        ;# the net at instance-id 1's pin "p"
;# -> name {MYNET} nwires 1 npins 1 anchor {inst 1 p}

xschem net MYNET            ;# by current name (the human form; may alias)
;# -> name {MYNET} nwires 1 npins 1 anchor {inst 1 p}
```

The descriptor is a Tcl dict, so read fields by name:

| key | meaning |
| --- | --- |
| `name` | the net's current token (the human / cross-session form) |
| `nwires` | number of wire segments on the net |
| `npins` | number of instance pins on the net |
| `anchor` | a durable handle *to* the net: `{wire <id>}` or `{inst <id> <pin>}` |

The `anchor` the descriptor reports prefers the net's **driver** (a label/pin
instance — its naming authority) over a plain wire, so it points at the object
that actually *owns* the name. An anchorless net (no wire, no label) reports
`anchor {}`.

## 3. Enumerate nets

```tcl
xschem nets
;# -> {name {MYNET} nwires 1 npins 1 anchor {inst 1 p}} \
;#    {name {#net1} nwires 0 npins 1 anchor {}} ...
```

One descriptor per **distinct** net (deduped by token). `-selected` restricts to
the nets touched by the current selection:

```tcl
xschem select wire 0
xschem nets -selected
;# -> {name {MYNET} nwires 1 npins 1 anchor {inst 1 p}}
```

`nets -selected` rebuilds the selection array internally, so a **cold** call is
correct — it does *not* have the call-order coherence bug `resolved_net` has
(see §6).

## 4. Membership by handle

```tcl
xschem net_members @wire 1
;# -> wires {1} pins {{1 p}}
```

- `wires` — the stable **wire ids** of every segment on the net.
- `pins` — `{stable-instance-id pin-name}` for every instance pin on it
  (including the driving label/pin).

Because membership comes back as *handles*, it composes directly with the
uniform object API — resolve any member to a full descriptor:

```tcl
foreach pe [dict get [xschem net_members @wire 1] pins] {
    lassign $pe iid pin
    set inst [xschem object instance @$iid]   ;# -> type instance index .. id $iid name {..}
    puts "pin $pin on [dict get $inst name]"
}
```

## 5. The round trip the whole thing is for

Hold the anchor, edit the schematic, resolve it back. The net's *name* may have
changed under you; the *anchor* did not.

```tcl
set h [xschem wire_id 0]                      ;# the durable handle
dict get [xschem net @wire $h] name           ;# -> MYNET

# rename the net by editing its driver label (the authority rule):
xschem setprop instance l1 lab RENAMEDNET
xschem rebuild_connectivity

dict get [xschem net @wire $h] name           ;# -> RENAMEDNET  (new token!)
expr {[xschem wire_id 0] == $h}               ;# -> 1           (anchor unchanged)
```

A **dangling** anchor — you deleted the wire — resolves to an honest empty
string, never a different net that happens to sit where the old one did:

```tcl
xschem select wire 0; xschem delete
xschem net @wire $h                           ;# -> ""   (dangled, loud)
```

## 6. The coherence rule it fixes

`resolved_net` of the *selection* famously returns empty on a cold call and the
right net only after some unrelated query has rebuilt the selection array — the
"§2c" trap (`doc/claude/code_analysis/tcl_introspection_wire.md`). The net commands here
avoid it by contract: each one runs `prepare_netlist_structs(0)` first, and
`nets -selected` rebuilds the selection array too, so **a query never returns
stale data because of call order.** The characterization suite proves the old
trap (test NC3) and the new commands' freedom from it (test NH5).

## 7. What this does *not* do (and where it's headed)

- **Read-only.** These commands never select, rename, move, or create anything.
  Renaming a net (edit the driver label) and creating one are explicit
  follow-ons, not part of this cut. Writing a *wire's* `lab` is, as ever, a
  silent no-op the connectivity engine overwrites — the net name is owned by the
  driver, not the wire.
- **Current sheet.** Resolution operates at the current hierarchy level, like
  `instances_to_net` / `resolved_net`. Cross-hierarchy net identity
  (`(token, path)`) is a future direction.
- **No net registry.** A net still has no id of its own — the handle is the
  *anchor's* id. If you delete the anchor, the handle dangles (correctly). A
  future "real net registry" (ids carried across rebuilds by matching
  equivalence classes) is recorded as the next step if this proves limiting; see
  `doc/claude/code_analysis/net_identity_decision.md` (option c3).

---

*See `doc/claude/code_analysis/net_identity_decision.md` for why the handle is anchored on a
stored object (the ratified c2 design), the characterization +
implementation tests in `tests/stable_handles/net_*.tcl`, and
`doc/claude/code_analysis/step3_directions_guide.md` §4 for where this fits the larger
stable-handles effort.*
