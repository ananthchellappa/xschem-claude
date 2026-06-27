# Building objects in C — a tutorial, with the wire as the running example

XSCHEM is C89. The stable-object-handles effort will add object-like
discipline to it, so it is worth being precise about what "an object" means,
what C++ does for you that C makes you do by hand, where the traps are, and
what each choice costs at runtime. Every example below is a wire, because
the wire is small enough to see whole and it already exhibits every problem
we care about (see `tcl_introspection_wire.md`).

An *object* is three things bundled together:

1. **data** — the bytes;
2. **invariants** — statements about the data that must always hold
   ("`node` matches what the connectivity engine computed", "`bus` mirrors
   the `bus=` token in `prop_ptr`");
3. **lifetime** — a well-defined birth, ownership while alive, and death.

C gives you language support for exactly one of the three: `struct` handles
the data. Invariants and lifetime are *conventions* in C; in C++ they are
*language features* (constructors/destructors, access control). That single
sentence is most of this document; the rest is worked examples.

## 1. Birth: construction

Here is the wire, abridged from `xschem.h:453`:

```c
typedef struct {
  double x1, y1, x2, y2;
  short  end1, end2;     /* endpoint junction state  : derived */
  short  sel;
  char  *node;           /* computed net name        : derived, owned */
  char  *prop_ptr;       /* attribute string         : owned */
  double bus;            /* cache of "bus=" token    : derived */
  int    flags;          /* cache of *_ignore tokens : derived */
} xWire;
```

### What C++ gives you

A constructor is code that *cannot be skipped*. If `xWire` were a C++ class,

```cpp
class Wire {
public:
  Wire(double x1, double y1, double x2, double y2, const char *props);
  ...
};
Wire w;                  // error unless a default ctor exists
Wire w(0,0,100,0,"");    // always runs the ctor: every field initialized,
                         // every invariant established, no exceptions
```

There is no way to obtain a `Wire` whose fields are garbage. The compiler
enforces it at every creation site, including ones written years later by
someone who never read your documentation.

### What you do in C

You write a function and *hope everyone calls it*:

```c
/* the only sanctioned way to create a wire */
void wire_init(xWire *w, double x1, double y1, double x2, double y2,
               const char *props)
{
  w->x1 = x1; w->y1 = y1; w->x2 = x2; w->y2 = y2;
  w->end1 = w->end2 = 0;
  w->sel = 0;
  w->node = NULL;
  w->prop_ptr = props ? my_strdup_str(props) : NULL;
  w->bus = wire_bus_from_props(w->prop_ptr);   /* establish invariant */
  w->flags = wire_flags_from_props(w->prop_ptr);
}
```

XSCHEM does this — `storeobject()` in `store.c` is the wire factory — and
it mostly works. The traps:

- **Trap 1: the bypass.** Nothing stops `xWire w; w.x1 = ...` with the other
  nine fields uninitialized. In C++ that is a compile error; in C it is a
  latent crash that valgrind may or may not catch.
- **Trap 2: the growing struct.** Add a field to `xWire` (this happened:
  `bus` in 2017, `flags` later) and you must find *every* place a wire is
  born, copied, or loaded from file and update each one. A C++ member
  initializer (`int flags = 0;` in the class body) updates every creation
  site at once. In C the compiler is silent; the bug surfaces as garbage in
  the one path you forgot.
- **Trap 3: half-construction.** If the C init function can fail in the
  middle (say `my_strdup` of a second string fails after the first
  succeeded), you must hand-unwind what was done. A C++ constructor that
  throws automatically destroys the already-constructed members.

The C89 wrinkle: C99 designated initializers (`(xWire){.x1 = 0, ...}`) at
least zero unnamed fields, but C89 has neither those nor compound literals,
so factory functions are the *only* line of defense in this codebase.

## 2. Death: destruction and RAII

### What C++ gives you

The destructor runs **deterministically** — scope exit, `delete`, container
removal — whether the exit is normal, early-`return`, or an exception
unwinding through. This is RAII, and it is the single biggest practical
difference between the languages:

```cpp
{
  Wire w(0,0,100,0,"lab=OUT");
  if (something()) return;   // ~Wire() runs: prop string freed
  ...
}                            // ~Wire() runs here too. Leaks are structural
                             // impossibilities, not discipline.
```

### What you do in C

Free by hand, on **every** exit path:

```c
void wire_clear(xWire *w)
{
  my_free(_ALLOC_ID_, &w->prop_ptr);
  my_free(_ALLOC_ID_, &w->node);
}
```

and the classic mitigation for multi-exit functions, the cleanup label:

```c
int f(void) {
  char *a = NULL, *b = NULL;
  int ret = -1;
  if (!(a = my_malloc(_ALLOC_ID_, 100))) goto done;
  if (!(b = my_malloc(_ALLOC_ID_, 100))) goto done;
  ret = 0;
done:
  my_free(_ALLOC_ID_, &b);  /* my_free tolerates NULL and nulls the ptr */
  my_free(_ALLOC_ID_, &a);
  return ret;
}
```

- **Trap 4: the forgotten path.** Every early `return` added in maintenance
  is a potential leak. There is a reason XSCHEM's allocator wrappers
  (`my_malloc`/`my_free` with the `_ALLOC_ID_` numeric tags and the
  `-d 3 -l log` leak tracer) exist: they are *instrumentation compensating
  for the absence of RAII*. C++ would not need the tags; C without the tags
  would be unmaintainable at this size.
- **Trap 5: double free.** Freeing through two aliases of the same pointer.
  `my_free` nulling its argument helps, but only for frees through the
  *same* alias — see copying, next, where this trap actually lives.

## 3. Copying: the deepest C trap of all

C happily copies structs by assignment:

```c
xWire a, b;
wire_init(&a, 0,0,100,0, "lab=OUT");
b = a;               /* compiles, runs, looks fine                  */
wire_clear(&a);      /* frees a.prop_ptr ... which is b.prop_ptr    */
puts(b.prop_ptr);    /* use-after-free; later wire_clear(&b) double-frees */
```

The assignment copied the *pointer*, not the string — a **shallow copy** of
an owning pointer, and now two objects believe they own one string. This is
not exotic: `b = a` on any struct with a `char *` is this bug. It is why
`my_strdup` calls blanket the XSCHEM codebase — every real copy of a wire
must be spelled:

```c
void wire_copy(xWire *dst, const xWire *src)
{
  *dst = *src;                                /* fields + caches      */
  dst->prop_ptr = NULL; dst->node = NULL;     /* un-alias             */
  my_strdup(_ALLOC_ID_, &dst->prop_ptr, src->prop_ptr);  /* deep copy */
  my_strdup(_ALLOC_ID_, &dst->node,     src->node);
}
```

C++ formalizes this as the **rule of three** (now five): if a class needs a
custom destructor, it needs a custom copy constructor and copy assignment
too (and move variants), and — crucially — *the compiler calls yours
automatically on every `b = a`*. You cannot forget at the call site, only
at the definition site, once. Or you sidestep the whole issue:
`std::string prop;` copies, moves and frees itself correctly with zero code
written. In C, the trap re-arms at every single assignment, `memcpy`,
by-value parameter, and `realloc`-grown array forever.

(Look at `update_recent_dir` from the file-open work, or any Tcl-side code:
Tcl strings are immutable values precisely so that scripting never meets
this trap. The C core has no such luxury.)

## 4. Invariants: encapsulation is what XSCHEM actually lacks

This is the section that explains the bugs found in
`tcl_introspection_wire.md` §2c/§2d.

The wire has four derived fields (`node`, `bus`, `flags`, plus the `lab`
token that the connectivity engine stamps back into `prop_ptr` —
`netlist.c:1051`). Each has an invariant tying it to other state. In C++
you would make the data `private` and force every mutation through methods
that maintain the invariants:

```cpp
class Wire {
  std::string props_;
  double bus_;                  // always == parsed "bus=" token
public:
  void set_prop(std::string_view tok, std::string_view val) {
    props_ = subst_token(props_, tok, val);
    bus_   = parse_bus(props_);          // invariant maintained HERE,
    invalidate_connectivity();           // in ONE place, unskippably
  }
};
```

The compiler stops anyone — including you, tired, in two years — from
writing `props_` directly and leaving `bus_` stale.

In C, `wire->prop_ptr` is writable by every line of every file. The
discipline must be social, and the analysis shows it eroding in exactly the
predicted ways:

- `setprop wire` (scheduler.c) remembers to refresh `bus` and `flags` but
  not the connectivity caches → `resolved_net` goes silent right after.
- `resolved_net` reads `sel_array` without rebuilding it → answers depend
  on which query ran before (scheduler.c:5189).
- the connectivity engine writes the `lab` token *into* the user-visible
  attribute string, so a scripted `setprop wire n lab X` is silently
  reverted — two owners for one datum and no fence between them.

None of these are stupidity; they are the *default outcome* of invariants
enforced by convention across 100k lines. The C mitigation is the same
shape as the C++ one, minus the compiler's help: **declare accessor
functions the only legal mutation path** and make the raw field morally
private (`/* private: use wire_set_prop() */`, or the harder version: move
the struct definition out of the public header so other files only hold an
opaque `Wire *` — true encapsulation, at the cost of losing direct field
reads and inlining unless you provide getters).

## 5. Identity: the problem C++ would *not* have solved

It is worth being honest about where C++ stops helping, because it is the
exact problem this branch exists for.

XSCHEM stores wires in one contiguous array, `xctx->wire[]`, and deletion
compacts the array — the probe showed index 6 naming a *different wire*
after a delete. Pointers are no better: `realloc` growth moves the whole
array, invalidating every `xWire *` in flight.

C++ would change the syntax, not the physics. A `std::vector<Wire>` migrates
objects on growth and on `erase()` exactly the same way; holding an iterator
across a mutation is undefined behavior, the same dangling reference with a
fancier name. (`shared_ptr`/`weak_ptr` would give safe *dangling detection*,
but only by giving up the contiguous array — see §6.)

The actual solution is the same in both languages: a **handle** — a small
value that names the object indirectly, with liveness verifiable:

```c
typedef struct { int idx; unsigned gen; } WireHandle;

typedef struct {
  unsigned gen;        /* bumped every time this slot is reused */
  int      live;
} SlotMeta;

/* parallel to xctx->wire[]: */
SlotMeta wire_meta[/* same length */];

xWire *wire_deref(WireHandle h)
{
  if (h.idx < 0 || h.idx >= xctx->wires)      return NULL;
  if (!wire_meta[h.idx].live)                 return NULL;
  if (wire_meta[h.idx].gen != h.gen)          return NULL;  /* stale! */
  return &xctx->wire[h.idx];
}
```

Sixteen lines. A handle held across a delete-and-reuse now *fails loudly*
(`NULL`) instead of silently denoting a stranger. The generation counter is
the whole trick — index alone (what the Tcl API uses today) is a handle
with no liveness check, which is precisely the §2e bug. This pattern
("slot map" / "generational arena") is how game engines, Vulkan, and the
Linux kernel (file descriptors + generation in some subsystems) all solve
it — in C. Note it also hands the action-logging effort its deferred issue
0005 (stable referents for replay) for free, and compaction can be kept by
adding one `id → idx` remap table maintained at the two places the array
is reordered.

## 6. Performance: what each choice costs

The folklore is "C++ is slower". The truth is per-feature, and mostly the
costs are *optional*:

| Feature | Runtime cost | Notes |
| --- | --- | --- |
| classes, methods, access control | **zero** | a member function is a plain function with `this`; `private` is compile-time only |
| constructors/destructors, RAII | **zero** vs *correct* C | the dtor emits the same `free` you should have written; cost only vs *buggy* C that skipped it |
| templates (`std::vector<Wire>`) | **zero** abstraction cost | monomorphized at compile time; the cost is compile *time* and code size |
| virtual dispatch | one indirect call through the vtable | identical cost to a C function pointer — which XSCHEM already uses (`xctx->push_undo`, the disk/memory undo switch). Cost appears only where you opt in |
| exceptions | ~zero on the non-throwing path (table-driven), expensive to throw | the real costs: code size, and every function must be unwind-safe — which is RAII again |
| `std::string` everywhere | small-string optimization helps, but implicit copies allocate | a careless C++ port of `prop_ptr` code could easily be *slower* than the current `my_strdup` discipline |

Where C wins for an XSCHEM-shaped program:

- **Layout control / data-oriented design.** `xctx->wire[]` is a contiguous
  array of 72-byte structs. Drawing or hit-testing 10,000 wires walks it
  linearly — the prefetcher loves it. The *idiomatic-OO* C++ alternative,
  `std::vector<std::unique_ptr<Wire>>` (or worse, `shared_ptr`), turns that
  into a pointer chase with a cache miss per wire. This is the one place
  naive C++ genuinely loses big, and it is XSCHEM's hot path. (Disciplined
  C++ — `std::vector<Wire>` by value — matches C exactly; the trap is that
  OO habits push toward heap-per-object.)
- **Predictability.** No hidden allocations, copies, or conversions; what
  the code says is what the CPU does. In C++ an innocent-looking
  `f(wire)` can invoke a deep copy constructor; in C, struct-by-value is
  visible and rare.
- **Build/ABI simplicity** — relevant for a tool distributed as source to
  every Unix under the sun, which is xschem's actual install base.

The synthesis — and the design stance for this branch — is the
game-industry one: **keep the C arrays (data-oriented, fast), and add by
convention the two C++ features that matter (construction discipline and
mutation-path discipline), plus generational handles, which C++ would not
have provided anyway.** That captures perhaps 90 % of the safety value at
0 % runtime cost on the hot paths, with no language migration.

## 7. Cheat sheet

| C++ feature | What it buys | The C substitute | Residual trap in C |
| --- | --- | --- | --- |
| constructor | can't create an invalid object | factory function (`storeobject`) | bypass; forgotten field on struct growth |
| destructor / RAII | can't leak on any exit path | `wire_clear` + `goto done` idiom + leak tracer | every new early return |
| copy ctor / rule of three | `b = a` deep-copies automatically | explicit `wire_copy`; never assign owning structs | every assignment re-arms the trap |
| `private` + methods | invariants maintained in one place | accessor functions + opaque pointer (optionally) | any direct field write compiles fine |
| `weak_ptr` / iterators (still unsafe!) | — | **generational handles** (§5) | none — this is the part C does as well as C++ |
| `std::vector` | growth, but moves elements | `my_realloc` arrays — same semantics | same dangling problem; handles fix both |

If the reader takes one thing away: the compiler-enforced part of C++ is
construction, destruction, and copying. Those are exactly the three places
the C traps live, so in C they must become *named functions plus a rule
that nobody bypasses them*. The identity problem — the reason this branch
exists — is not on that list: it is solved the same way in both languages,
and the C solution (slot map + generation counts) is small, fast, and
proven.
