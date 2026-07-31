# 0179 — tEDAx netlist SEGFAULTS on a symbol with `extra=` but no `extra_pinnumber=`

Status: **OPEN** (found 2026-07-30 while measuring 0165 D3; no fix attempted yet)
Area: `src/token.c` `print_tedax_element()`, `src/util.c` `my_strtok_r()`
Tests: none yet
Related: 0165 (the measurement that turned it up), 0156

## What happens

Netlisting to tEDAx a design containing an instance whose symbol carries

- a non-empty `tedax_format` (or an instance-level one), **and**
- an `extra="…"` list, **and**
- **no** `extra_pinnumber=` on either the instance or the symbol

kills the process with `FATAL: signal 11`. It is not format-dependent and not `#`-dependent — the
0165 fixture merely happened to have this shape.

MEASURED at `7791a85e`, `--nogui`:

```
STEP load
STEP set tedax
STEP netlist
EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_d0165_top_dfacbfacbc

FATAL: signal 11
```

Adding `extra_pinnumber="9"` to the symbol, **or** removing `extra=`, makes the same design netlist
cleanly. Both controls measured.

## Why

`print_tedax_element()` (`src/token.c:3118`) declares

```c
char *extra_pinnumber_token, *extra_pinnumber_ptr;
char *saveptr1, *saveptr2;                            /* :3129 -- UNINITIALISED */
```

and fills `extra_pinnumber` at `:3140-3142` from the instance, then the symbol. `my_strdup()` leaves
the destination **`NULL`** when the source is absent or empty, so a symbol with no `extra_pinnumber`
leaves `extra_pinnumber == NULL`.

The emission loop at `:3234` then does

```c
for(extra_ptr = extra, extra_pinnumber_ptr = extra_pinnumber; ; extra_ptr=NULL, ...) {
  extra_pinnumber_token = my_strtok_r(extra_pinnumber_ptr, " ", "", 0, &saveptr1);
```

With `extra_pinnumber_ptr == NULL`, `my_strtok_r()` (`src/util.c:159`) skips its `if(str)` first-call
branch at `:164-166` and goes straight to

```c
while(**saveptr && strchr(delim, **saveptr) ) {   /* :168 */
```

dereferencing an uninitialised `saveptr1`. The `extra` side is safe only by accident: `extra` is
non-`NULL` whenever the loop is entered, so `saveptr2` is always initialised.

Even if the deref is survived, `extra_pinnumber_token` stays `NULL` and is then passed to
`my_snprintf(netstring, S(netstring), "net:%s", extra_pinnumber_token)` (`:3243`) and to
`fprintf(fd, "conn %s %s %s %s %d", …)` (`:3251`) — two more `%s`-with-`NULL`.

## Reach

**Zero committed designs.** No stock symbol pairs `type=subcircuit` with `tedax_format`, and the
529 `xschem_library/` symbols that carry both `tedax_format` and `extra=` all also carry
`extra_pinnumber=`. It is latent, and a user hand-writing a `tedax_format` on a symbol that already
has `extra=` is the way in.

## Fix shape (not yet decided)

The minimal correct change is to initialise both save pointers and to give the loop a NULL-safe
token, e.g. treat a missing `extra_pinnumber` the same way the pin loop treats a missing
`pinnumber` — `"--UNDEF--"` (`:3217`). Whether the whole `conn` line should be suppressed instead of
emitted with `--UNDEF--` is a product decision, not a crash-fix one.

Note the same uninitialised-`saveptr` pattern should be swept for elsewhere: `my_strtok_r()` gives no
diagnostic for a `NULL` first argument, so every call whose first argument can be `NULL` is the same
bug.

## Reproduce

Symbol:

```
K {type=subcircuit
format="@name @pinlist @HN @symname"
tedax_format="footprint @name dip8"
template="name=x1 HN=VDD"
extra="HN"}
```

with one pin `B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout pinnumber=1}`, a trivial schematic behind
it, one instance of it in a top cell, then `xschem set netlist_type tedax; xschem netlist`.

A regression leg must run the binary as a **subprocess** (`exec $xbin --nogui --pipe -q --nolog
--script <child>`) or the segfault takes the whole test file down — copy the `child` proc from
`tests/headless/test_hash_label_crash_0156.tcl`.
