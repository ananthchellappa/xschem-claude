# Library & Instance commands — user guide

*Find a cell, report what an instance is, and place instances — from the
keyboard, the menus, or Tcl.*

This guide covers the commands added for the Cadence-style library workflow:

| Command | What it does |
| --- | --- |
| [`xschem library_manager`](#library_manager) | open the Library Manager, optionally on a given Library/Cell/View |
| [`xschem get_inst_lcv`](#get_inst_lcv) | report the Library/Cell/View of the selected instance |
| [`xschem create_instance`](#create_instance) | open the Create Instance form, optionally pre-filled |
| [Library Manager helpers](#libmgr-helpers) | `libmgr::selection`, `libmgr::locate`, … |

Every command has **two faces**:

- the **`xschem <cmd>`** dispatcher form — logged, replayable, bindable to a key,
  reachable from menus and the CIW;
- a **`namespace::proc`** Tcl form — the underlying procedure, handy when you are
  already scripting in Tcl and do not need logging.

Lists are the common currency. `get_inst_lcv` *returns* a `{lib cell view}` Tcl
list; `library_manager` and `create_instance` *accept* one. So they compose
directly — that is the whole point (see [Recipes](#recipes)).

Every code block below was run against a real build.

---

## <a name="library_manager"></a>1. `xschem library_manager` — open / locate

Opens the Library Manager (a single, reused window). With no argument it just
opens or raises it. With an argument it **pre-selects and scrolls to** an entry.

The argument is **one Tcl list**:

| argument | effect |
| --- | --- |
| *(none)* | open / raise the window |
| `libName` | select that library |
| `{libName cellName}` | select library + cell |
| `{libName cellName viewName}` | select down to the view |

```tcl
# dispatcher form
xschem library_manager                        ;# open / raise
xschem library_manager devices                ;# select the 'devices' library
xschem library_manager {devices nmos3 symbol} ;# select devices ▸ nmos3 ▸ symbol
```

```tcl
# namespace form (identical behavior, not logged)
libmgr::open
libmgr::open devices
libmgr::open {devices nmos3 symbol}
```

> **Why a list and not three arguments?** Tcl command substitution `[...]`
> produces *one* value, so `xschem library_manager [xschem get_inst_lcv]` passes
> the whole `{lib cell view}` straight through — no `{*}` expansion needed. A
> single-element list is just a library name, and a library name that contains
> spaces stays unambiguous.

---

## <a name="get_inst_lcv"></a>2. `xschem get_inst_lcv` — what is this instance?

Reports the **Library / Cell / View** of the one selected instance, as a
`{lib cell view}` list:

```tcl
xschem get_inst_lcv
# => devices nmos3 symbol
```

Rules:

- **Exactly one instance** must be selected, otherwise it errors
  (`exactly one instance must be selected`). Wrap it in `catch` when binding it
  to a key (the selection may be empty or be something else).
- It reports an instance only when its symbol lives in a library **defined in a
  loaded `library.defs`** and laid out in the Cadence structure
  `<libpath>/<cell>/<view>/<cell>.sym`. The **view** is the actual view-directory
  name (its *type* is always a `.sym` symbol, but the *name* is arbitrary). A
  flat/legacy symbol, or one only reachable via the search path with no
  `library.defs` entry, is reported as *not in a Cadence library*.

**The two faces.** `get_inst_lcv` is a C dispatcher command — the part that
checks "exactly one instance is selected" lives in the engine. Its Tcl backend is
the global-namespace proc **`::library_inst_lcv`**, but that one is *not* a drop-in
twin: it takes a symbol **reference** (not the selection) and does no
selection-check:

```tcl
xschem get_inst_lcv                       ;# selection-aware (the normal form)
::library_inst_lcv devices/nmos3          ;# backend: reverse-map a symbol ref
```

So for everyday use call `xschem get_inst_lcv`; reach for `::library_inst_lcv`
only when you already have a symbol reference in hand.

---

## <a name="create_instance"></a>3. `xschem create_instance` — place an instance

Opens the **Create Instance** form: a properties-style dialog with **Library
Name / Cell Name / View Name / Instance Name** fields and a **Browse…** button.
There is no "Place" button — as soon as the fields name a real symbol view the
preview attaches to the cursor; **click the canvas to drop**, repeatedly, until
**Esc**. A blank View means no preview (nothing to place). The **Instance Name**,
if set, becomes the placed instance's `name=`.

Like `library_manager`, it takes one optional list — `{lib cell view}` (plus an
optional 4th element for the instance name) — that **pre-fills the form** (even if
it is already open) and arms the preview:

```tcl
# dispatcher form
xschem create_instance                              ;# open the form (last fields kept)
xschem create_instance {devices nmos3 symbol}        ;# pre-fill + arm
xschem create_instance {devices nmos3 symbol M1}     ;# …and name it M1
```

```tcl
# namespace form
ciform::open
ciform::open {devices nmos3 symbol}
ciform::open {devices nmos3 symbol M1}
```

**Browse → the Library Browser.** The Browse button opens a 3-column
Library / Cell / (symbol) View picker. It is *live*: every click is applied to the
form immediately (there is no OK/Apply — only **Cancel**, and **Esc** closes it).
Clicking a cell that has exactly one symbol view also fills the View field.

---

## <a name="libmgr-helpers"></a>4. Library Manager helpers (Tcl)

These have no `xschem …` dispatcher form; they are pure Tcl, for scripting.

| proc | returns / does |
| --- | --- |
| `libmgr::selection` | the current panes' selection, graded: `{}`, `{lib}`, `{lib cell}`, or `{lib cell view}` |
| `libmgr::locate {lcv}` | select + scroll to a `{lib cell view}` (cell/view optional) |
| `libmgr::open {lcv}` | what `xschem library_manager` calls |

`libmgr::selection` is the inverse of `libmgr::locate` — what one selects, the
other reports — so they round-trip:

```tcl
libmgr::selection            ;# => devices crystal symbol
libmgr::locate [libmgr::selection]    ;# re-selects the same entry
```

---

## <a name="recipes"></a>5. Recipes — keyboard shortcuts

The commands compose into one-key gestures. Bind them on the drawing canvas
`.drw`. Put these in your `xschemrc`, a `--script` file, or paste them in the CIW.

> Function keys (`F2`, `F3`, …) and `Ctrl-`/`Alt-` combos are safest — they do not
> collide with xschem's single-letter commands. If you bind a plain letter, append
> `; break` so xschem's own handler for that key does not also fire.

### 5.1 Select an instance → locate its cell in the Library Manager

Click an instance, press the key, and the Library Manager opens with that
instance's Library ▸ Cell ▸ View highlighted and scrolled into view — handy for
finding a similarly named cell nearby.

```tcl
proc locate_selected_in_libmgr {} {
  if {[catch {xschem get_inst_lcv} lcv]} {
    puts "select exactly one instance first ($lcv)"
    return
  }
  xschem library_manager $lcv
}
bind .drw <Key-F2> {locate_selected_in_libmgr; break}
```

The heart of it is the composition `xschem library_manager [xschem get_inst_lcv]`;
the proc just adds a friendly message when the selection is not a single instance.

### 5.2 Select a cell in the Library Manager → place it with one key

Pick a Library ▸ Cell ▸ View in the Library Manager, move to the schematic, and
press the key — the symbol attaches to the cursor for an immediate drop, **without
opening the Create Instance form or making any selection there**.

```tcl
proc place_libmgr_selection {} {
  set sel [libmgr::selection]
  if {[llength $sel] < 2} { puts "select at least a cell in the Library Manager"; return }
  lassign $sel lib cell view
  if {$view eq ""} { set view symbol }      ;# default to the symbol view
  set f [xschem cellview_path "$lib/$cell" $view]
  if {$f eq "" || ![string match *.sym $f]} { puts "no symbol view for $lib/$cell"; return }
  xschem place_symbol $f                      ;# cursor preview; click to drop
}
bind .drw <Key-F3> {place_libmgr_selection; break}
```

This is the *direct* route: `xschem place_symbol <file>` is the engine's native
placement, so it bypasses the form entirely.

**Variant — via the form (pre-filled, no manual picking).** If you would rather
go through the Create Instance form (to get its Instance-Name field, recursion
guard and keep-placing loop) but still skip the manual selection, feed the
Library Manager's selection straight into it:

```tcl
bind .drw <Key-F4> {xschem create_instance [libmgr::selection]; break}
```

### 5.3 Clone the selected instance's cell

A combination of the two read/place commands — place another copy of whatever
cell the selected instance is an instance of:

```tcl
bind .drw <Key-F5> {catch {xschem create_instance [xschem get_inst_lcv]}; break}
```

---

## 6. Quick reference

```tcl
# read
xschem get_inst_lcv                 ;# {lib cell view} of the selected instance
libmgr::selection                   ;# {lib cell view} selected in the Library Manager

# open / locate
xschem library_manager              ;# open the Library Manager
xschem library_manager {L C V}      ;# …and locate L/C/V        (libmgr::open)
libmgr::locate {L C V}              ;# locate in an open Library Manager

# place
xschem create_instance              ;# open the Create Instance form
xschem create_instance {L C V}      ;# …pre-filled               (ciform::open)
xschem create_instance {L C V name} ;# …with an instance name
xschem place_symbol <file.sym>      ;# place a symbol directly (no form)

# compose
xschem library_manager [xschem get_inst_lcv]   ;# locate the selected instance's cell
xschem create_instance [libmgr::selection]     ;# place the Library Manager's selection
```
