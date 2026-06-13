# Stable instance handles — a user & developer manual

*How to hold on to a component instance across edits, why its name is not the
handle you think it is, and how the id was built.*

This manual covers the `xschem instance_id` / `xschem instance_index` commands
added on the `feature/stable-object-handles` branch (step 2 of the
stable-object identity work). It is the **sibling** of
[`stable_wire_handles.md`](stable_wire_handles.md): the mechanics, the
disk-vs-memory-undo contract, the "linear scan, not a map" rationale, and the
`xschem selection` row format are all **identical** to wires and explained in
full there. This document covers what is *different* about instances — namely
that an instance already has a name, and **the name is not a safe handle**.

Everything in the code blocks below was run against
`xschem_library/examples/mos_power_ampli.sch` (117 instances); the outputs are
real (`code_analysis/introspection_probes/probe4.tcl` reproduces them).

---

## 1. Instances have a name — so why add an id?

Unlike a wire, an instance carries a **name** (`instname`, e.g. `R25`,
auto-assigned at placement and unique within the schematic). It is tempting to
treat the name as the stable handle. It is not, for two reasons that bite
silently:

1. **Names are reused within a session.** Place three resistors → `R25 R37
   R38`. Delete `R37`. Place another resistor → it is auto-named **`R37`
   again**. A script that grabbed `R37` before the delete now points at a
   *different* instance, with no error.

2. **Names are user-editable and renamable.** `instname` is the `name=` token
   of the instance's property string, written into the `.sch` file. A user (or
   a script via `setprop instance <ref> name <new>`) can change it. Your held
   name then resolves to nothing — or worse, to whatever later reused it.

The numeric **id** has neither problem: it is monotonic, **never reused** within
a session, and **independent of the name** (survives a rename untouched). It is
the durable machine handle. The name remains the *human* and *cross-session*
form — see §4.

```tcl
xschem instance res.sym 4000 4000 0 0   ;# auto-named R25, say id 469
set id1 [xschem instance_id R25]         ;# -> 469
# delete it, place another resistor at the same spot:
xschem instance_id R25                   ;# -> 470   the NAME R25 came back...
xschem instance_index $id1               ;# -> -1    ...but the old ID is gone for good
```

## 2. The two commands

| Command | You give it | You get back |
| --- | --- | --- |
| `xschem instance_id <name\|index>` | an instance **name** *or* a current array **index** | that instance's stable **id** (or `-1` if it does not resolve) |
| `xschem instance_index <id>` | a stable **id** | the instance's **current index** (or `-1` if no live instance has that id) |

The input to `instance_id` is **polymorphic**, resolved by the same
`get_instance` rule the rest of the API uses: an all-digits argument is treated
as an **array index**, anything else as a **name**. (Corollary: an instance
literally named `5` is unreachable by name — a pre-existing quirk, not new.)

```tcl
set h [xschem instance_id R25]   ;# durable handle to "R25, right now"
# ... arbitrary edits: deletes that shift indices, copies, undo ...
set i [xschem instance_index $h] ;# where did it go? (-1 if it's gone)
if {$i >= 0} { puts "still at index $i: [xschem instance_coord $i]" }
```

Both commands are additive and **side-effect free** — they read state, they
never modify the schematic, undo stack, or selection.

### Ids appear in `xschem selection`

The selection enumerator returns one `{type index col id}` row per selected
object. The instance row used to carry `-1` in the id slot; it now carries the
real id:

```tcl
xschem select instance R25
xschem selection            ;# -> {instance 117 1 469}
#                                              │   └ stable id (== instance_id 117)
#                                              └ selection color
```

This is the same row shape wires use; see the wire manual §7.

## 3. The id-vs-name divergence, demonstrated

The headline behavior, all verifiable in one session:

| Operation | The **name** | The **id** |
| --- | --- | --- |
| neighbour deleted (index shifts) | still resolves | still resolves (`instance_index`) |
| **the instance itself deleted** | stops resolving | resolves to `-1` (loud dangle) |
| **delete + recreate (auto-name)** | **silently reused** — points elsewhere | **fresh id** — old id dangles `-1` |
| **rename** | old name dead, new name live | **unchanged** — same id resolves |
| memory undo + redo | round-trips | round-trips (same id) |
| disk undo restore | round-trips (in the file) | **invalidated** — fresh id, old dangles `-1` |
| save / close / reopen | persists | gone (session-only) |

Read it as: hold the **id** for any machine reference you keep across edits
within a session; use the **name** when you need something a human types or that
survives a reload. Neither alone covers every purpose — which is exactly why
both exist.

## 4. The role contract (don't mix them up)

- **`id`** — the canonical *durable session* identity. Monotonic, never reused,
  **not persisted**. What `selection` returns, what `instance_index` resolves,
  the right referent for a replay log or a held handle. Gone after a reload.
- **`name`** — the *human / cross-session* form. User-editable, **saved in the
  `.sch`**, reusable and renamable. The only thing that still means "the same
  instance" after save / close / reopen — but **never hold it across edits as a
  machine handle**.

The full rationale (why "both", the safety/consistency/ergonomics analysis, the
reference-convention sub-decision) is in
[`../code_analysis/instance_identity_decision.md`](../code_analysis/instance_identity_decision.md).

## 5. Undo semantics (identical to wires)

- **Memory undo** round-trips ids: undo dangles the handle, redo brings back the
  *same* id resolving to the same instance (memory undo copies whole structs).
- **Disk undo** is **invalidate-on-restore**: a disk-undo restore re-reads the
  `.sch` and mints *fresh* ids, so a held id dangles `-1` after the cycle and
  the restored instance carries a new id. The file-persisted **name** still
  resolves. This is the same settled contract as wires (their §8) — a `-1` after
  a disk-undo is correct, not a bug.

## 6. How it was built (one line, because of the funnel)

Instances are born four different ways (interactive placement, file load,
copy, paste/merge), each initialising the struct differently — so there is no
single birth *factory* like wires have. Step-2 Phase C funneled all four through
one **birth chokepoint**, `inst_register(n)` in `src/store.c`. Stamping identity
was then a single line there:

```c
void inst_register(int n)
{
 xctx->inst[n].id = ++xctx->inst_id_counter;  /* never reused, not persisted */
 xctx->instances++;
}
```

`inst_index_from_id()` resolves an id back to an index by a **linear scan** of
the array — deliberately not a maintained map, for the same reason as wires: the
id rides *inside* the struct, so the array itself is the authoritative
id→index relation under every mutation (compaction, swap, undo) with no cache to
go stale. The wire manual §8.3 explains this choice at length; it applies
verbatim here. The counter (`inst_id_counter`) lives in the per-window `Xschem_ctx` and
survives `clear`/`load`, so ids are never reused within a context's lifetime.

---

*See also: [`stable_wire_handles.md`](stable_wire_handles.md) for the shared
mechanics and the full developer walkthrough;
[`../code_analysis/instance_identity_decision.md`](../code_analysis/instance_identity_decision.md)
for the design decision.*
