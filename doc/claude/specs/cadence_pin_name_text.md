# Cadence-style pin-owned name text (symbol pins)

Status: **SPEC / PLAN — not started.** Written 2026-06-29 on branch `fluid-editing`.
This is **Thread A**, the prerequisite for `doc/claude/specs/wire_stub_netlabel.md` (Thread B):
once a pin owns its name text, "the pin's text size" is well-defined and wire-stub
labels can read it. Pick-up-here handoff doc.

Related: `[[pin-selection]]`, `doc/claude/specs/pin_selection.md`, `[[wire-stub-netlabel]]`.

---

## 1. Goal / requirements (as stated by the user)

Make symbol pins behave like Cadence:

1. **At creation, each pin gets accompanying name text owned by the pin.** The text *is*
   the pin name. (Users may still add other, unrelated text to a symbol freely.)
2. **Delete the pin → its name text is deleted** (the text is part of the pin).
3. **Select+edit the name text (in symbol view) = edit the pin name.** Editing the text
   content is no different from renaming the pin.
4. **User may modify the text's size and location.**
5. **A per-pin property controls whether the name text is displayed.**
6. **A migration script** (Python) to convert existing `.sym` files — one file at a time,
   OR a whole directory tree recursively (e.g. `xschem_libraries_oa`).

---

## 2. Critical context: xschem ALREADY has a weak version of this

This is **not a greenfield** design. xschem already represents a pin-name label as a
**real, separate `T` text record** whose content equals the pin name, loosely linked to
the pin. We are formalizing that into true ownership. Verified facts:

- **A symbol is edited with the SAME editor/arrays as a schematic.** In symbol-edit mode
  pins are `xctx->rect[PINLAYER]` (PINLAYER = 5, `xschem.h:169`) and texts are
  `xctx->text[]` — edited by the general ops in `move.c`/`select.c`/`editprop.c`/
  `actions.c`. Symbol mode is detected from the `.sym` extension / header / zero
  instances (`save.c:3770-3795`), setting `xctx->netlist_type = CAD_SYMBOL_ATTRS`.
- **`add_symbol_pin` already creates a name text + a stub line next to the pin**
  (`scheduler.c:220-270`):
  ```c
  storeobject(-1, x-2.5,y-2.5, x+2.5,y+2.5, xRECT, PINLAYER, 0, "name=<n> dir=<d>");
  create_text(draw, x+25, y-5, 0, 0, name, NULL, 0.2, 0.2);   /* the NAME label */
  storeobject(-1, x, y, x+20, y, LINE, linecol, 0, NULL);     /* a connection stub */
  ```
  Side (left/right) is chosen by direction (`out`/`inout` → flip, label on the left).
  **BUT** the *interactive* (no-arg) path (`scheduler.c:263`) makes ONLY the rect
  (`name=XXX\ndir=inout`) — no label. Inconsistency to fix.
- **Editing a text already renames the matching pin** (`editprop.c:730-760`): on a text
  content change, it scans PINLAYER rects; if a pin's `name=` equals the text's old
  content AND the text sits near that pin (within `cadgrid` tolerances), it rewrites the
  pin's `name=` via `subst_token`, then updates the text. So a **text→pin name sync by
  name-match + proximity** is already in place. (The `if(x==0) else` branch there is
  vestigial — both arms identical.)
- **Real libraries split ~15% / ~85%**: ~15% of symbols already carry a literal
  `T {<pinname>}` label per pin (e.g. `ngspice/opamp_65nm.sym`, `logic/ram.sym`,
  `generators/my_inv.sym`); ~85% have pin rects with NO visible name label
  (`devices/nmos4.sym`, `logic/iv.sym`, …). 1711 `.sym` total, 1454 with ≥1 pin, 257
  with 0 pins. `@#N:net_name` (64 syms) and `@#N:pinnumber` (1001 syms) are positional
  per-pin *number/net* displays, NOT name labels (always `@`-prefixed).

**Implication:** the cheapest, most idiomatic design *reuses* this — keep the name label
as a real `T` text, and add (a) an ownership MARKER, (b) cascade-delete, (c) the reverse
name sync, (d) a show/hide property, (e) consistent creation, (f) migration. Almost all
of the user's "edit/move/resize the text" requirements then come **for free** from the
existing text machinery, and **display on placed instances needs no new draw code** (a
symbol's `T` records already render on its instances).

---

## 3. Data-model decision

### 3.1 Recommended: **Model B — formalize the real bound text** (NOT a rendered attr)

Two candidate models were considered:

- **Model A — rendered name (attributes on the pin rect).** Store `name_size`/offset/
  rot/show on the pin's `B`-record prop; `draw_symbol` renders `name=` as text; no
  separate object. *Pros:* single source of truth; auto delete-cascade. *Cons:* needs a
  whole NEW sub-object UI to select/move/resize/content-edit the rendered text (none of
  the existing text machinery applies); new draw code for both symbol-edit and instances;
  fights how xschem already works. **Heavy.**
- **Model B — real `T` text owned by the pin (RECOMMENDED).** Keep the label as a normal
  `T` record; mark it as owned; bind it to the pin; cascade on delete; sync the name both
  ways. *Pros:* reuses ALL existing select/move/rotate/flip/interactive-resize
  (`edit.text_grow`/`edit.text_shrink`)/content-edit/save/load/copy/paste/undo; instance
  display free; matches the existing partial implementation and the ~15% libraries.
  *Cons:* the name string exists in two places (pin `name=` and the label `txt_ptr`) kept
  in sync — but that is exactly how xschem already behaves, and is the only duplication.

**Recommendation: Model B.** Treat the pin rect `name=` as **authoritative**; keep the
label text content identical to it via sync at the few edit choke points.

> Rejected sub-variant: making the label content a token like `@pinname` that resolves to
> the owning pin's name (single-source, no sync). It breaks requirement 3 ("edit text =
> edit name" — you'd be editing a token, not the name) and there is no such per-text
> "my pin's name" token in symbol context. Not worth inventing.

### 3.2 The ownership scheme (Option B — CHOSEN 2026-06-29)

**Authoritative state = the pin rect's `B`-record tokens. There is NO separate persisted
name `T` record.** Each pin rect carries, in its `prop_ptr`:
- `name=<pinname>` — the pin name (authoritative; already present). The label content IS
  this string (decision 4 — the name is stored ONCE).
- `dir=<dir>` — already present.
- `show_pinname=true|false` — per-pin display flag (default true for new pins; migrated
  pins per §5.2). Effective visibility also respects the global toggle (§4.8).
- Label LAYOUT, written only when non-default (defaults computed from pin side + size):
  `name_dx name_dy` (anchor offset from the pin center, symbol coords),
  `name_size` (scale), `name_rot` (0–3), `name_flip` (0/1), optional
  `name_hcenter name_vcenter name_font`.

**In symbol-edit mode**, xschem materializes a real, session-only `xText` **view** of each
shown pin name, so the existing select / move / rotate / flip / interactive-resize /
content-edit machinery all apply. The view:
- is bound to its pin by the pin's session `id` (`xRect.id`, `xschem.h:544`) and carries a
  transient **SYNTH** marker (a new non-persisted `xText` flag);
- is **derived** — regenerated from the pin tokens at load, after copy/paste, and after
  undo/redo (never the source of truth);
- is **skipped at save** — `write_xschem_file` never emits SYNTH views as `T` records.

**Write-through (edits update the pin tokens immediately):**
- move/rotate/flip/resize the view → update `name_dx/name_dy/name_rot/name_flip/name_size`
  on the owning pin (at the operation END);
- edit the view content → rename the pin (`name=`); the view content follows (decision 3:
  editing the text == renaming the pin).

**On placed instances**, pin names render directly from the symbol's pin tokens in
`draw_symbol` (gated by visibility) — no materialized view needed there.

New tokens (`show_pinname`, `name_*`) are plain prop tokens → **no file_version bump**;
older xschem preserves unknown tokens on round-trip (`subst_token` verbatim,
`token.c:1378-1390`) but will not RENDER pin names (and shows no stray `T`, since there is
none) — the accepted Option-B trade.

> Materialization SCOPE — **CHOSEN: Way A (2026-06-29).** Materialize editable views ONLY
> for the symbol being edited; render instance pin names directly from pin tokens in
> `draw_symbol` (the shared `sym[]` cache is never augmented with synthetic texts).
> (Rejected: synth into the `sym[]` cache to reuse the text loop — pollutes the cache.)

### 3.2.1 LOCKED user decisions (2026-06-29)
1. **Model B** — proceed.
2. **Show/hide:** per-pin property, PLUS a **global toggle that WINS** (global override
   takes precedence over the per-pin flag). §4.8.
3. **The label cannot be deleted as a standalone object.** Hiding is done via the pin's
   display property — never by deleting the label. §4.5.
4. **The accompanying text *is* the pin name.** There is exactly **one** displayable text
   per pin — the name. (Not a free, independently-authored string; users may still add
   *other* unrelated texts to the symbol, but those are not pin labels.) §4.2.
5. **Adoption (migration):** adopt an existing literal label and attach it to the pin
   **only when the text exactly matches the pin name**. Otherwise set the pin's display
   property to **hidden** and leave the non-matching legacy text as ordinary stray text
   (a note) — do not adopt or delete it. §5.2.

### 3.3 Pin↔label IDENTITY across copy / duplicate pins (the open question)

Pins can be copied; a symbol/schematic may contain **any number of pins with identical
names** (intentional duplicates, or transient duplicates right after a copy). So
binding the label to its pin by **name** (today's `editprop.c` rule) or by **position**
is NOT sufficient. Runtime `id` (now confirmed on both `xRect` `xschem.h:544` and
`xText`) is stable within a session but **is not saved to file**, so it cannot be the
durable identity. Options:

- **Option A — persistent pin-key token (keep the label as a real `T` record).** Pin rect
  carries `pinid=<k>`; its label `T` carries `pinlabel=<k>`. Bind by exact key. `k` =
  per-symbol monotonic counter (max+1); mint a NEW key when a pin is copied (and on
  cross-file paste, renumber on collision). Survives save/load/undo/paste automatically
  (tokens are deep-copied). Migration assigns keys; adoption is trivial (existing `T`
  just gains a key). *Pros:* least code, max machinery reuse, trivial adoption. *Cons:*
  the name is stored twice (pin `name=` + label content) and must be sync-kept; the label
  is still an independent on-disk object, so decisions 3 & 4 ("can't delete", "exactly
  one") are enforced by CODE not structure; keys add file clutter; copy must re-key.

- **Option B — fold the label INTO the pin (no separate persisted object) [RECOMMENDED].**
  On disk the pin rect carries `name=`, `show_pinname=`, and label LAYOUT tokens
  (`name_dx name_dy name_size name_rot name_flip [name_font]`, offsets relative to the
  pin) — there is **no standalone name `T` record**. On LOAD, synthesize a real `xText`
  bound to its pin by the session `id` (so all editing machinery still applies); on SAVE,
  fold the label's current geometry back into the owning pin's tokens and skip emitting a
  standalone `T`. *Pros:* the identity problem **vanishes on disk** (the label is
  literally part of the pin); duplicate/copied pins are automatically correct (each pin
  carries its own tokens); the label cannot be deleted alone and is exactly one per pin
  (decisions 3 & 4 enforced **structurally**); the name is stored **once** (decision 4);
  the Thread-B size getter reads `name_size` directly. *Cons:* more upfront work
  (synthesize-on-load + serialize-on-save, in `load_schematic`/`load_sym_def` and
  `write_xschem_file`; maintain the in-session rect↔text link through copy/paste/undo);
  adoption converts a matching `T` into pin tokens then drops the `T`; an OLDER xschem
  opening a NEW file won't render pin names (acceptable — it also won't show a stray `T`).

- **Option C — runtime id only.** Rejected for persistence: `xRect.id`/`xText.id` are not
  saved, so they can't survive reopen. Usable only as an in-memory accelerator under A/B.

- **Option D — position / pin-index (`@#N`-style) binding.** Rejected as primary: breaks
  under move, reorder, duplicate, and overlap. Keep only as a migration heuristic.

**CHOSEN: Option B (2026-06-29).** It dissolves the identity problem and structurally
enforces decisions 3 & 4. §3.2 and §4/§5 are written for B. (Option A retained above only
as the rejected alternative / rationale.)

---

## 4. Component design (Option B)

> **Under B the label is a DERIVED session view, not a stored object.** That means the
> hard parts of the old plan disappear: there is no persistent binding, and delete/copy/
> undo "cascades" are automatic because the view is regenerated from the pin tokens. The
> genuinely NEW machinery is exactly three seams: **(S1) synthesize views on load**,
> **(S2) write-through on edit**, **(S3) skip views on save** (fold geometry into pin
> tokens). The subsections describe behavior in those terms.

### 4.1 Pin creation — write tokens, materialize a view
- Factor a single `create_pin(x, y, name, dir)` helper that: stores the pin rect with
  `name= dir= show_pinname=true` (+ default `name_*` layout) and materializes its view
  (S1). Route BOTH `add_symbol_pin` paths through it — today the scripted path
  (`scheduler.c:240-246`) creates a standalone `T`, and the interactive path
  (`scheduler.c:263`) creates no label at all; under B neither should create a persisted
  `T` — they set tokens + synth a view.
- **Default placement/size/orientation:** keep today's feel (offset ~±25 from the pin,
  size 0.2, side by direction). Make the default size a tunable Tcl var
  (`sym_pin_name_size`, default 0.2). Reuse the pin-facing/outward logic
  (`wire_stub_netlabel.md §4.3`) to orient per side.
- **Symbol-from-schematic** (`[[symbol-view-create]]`) and `.sym` generators just emit pin
  tokens (no `T`) — or rely on migration.

### 4.2 Display
- **Symbol-edit:** the SYNTH view is a normal text → drawn by the existing `draw_texts:`
  loop (`draw.c:823-890`), gated by the visibility rule (§4.8) on its owning pin.
- **Instances:** add a small pass in `draw_symbol` to render each pin's `name=` from the
  symbol's pin tokens (`name_*`, `show_pinname`), gated by visibility — the symbol cache
  has the pins but no SYNTH views (per the §3.2 scope decision). Existing zoom-cull
  (`xscale*FONTWIDTH*mooz<1`), `hide_texts`/`show_hidden_texts` still apply.

### 4.3 Select / move / resize / rotate / flip
- Acting on the VIEW works via existing text handling (`move.c:1859-1903`,
  `edit.text_grow`/`edit.text_shrink`); each such edit **writes through** to the pin's
  `name_*` tokens (S2).
- **"Label follows pin" is free:** `name_dx/name_dy` are offsets *relative to the pin*, so
  after a pin rect is moved/rotated/flipped, simply **regenerate its view** at the new pin
  position with the same offset → it stays attached, no move-set juggling. (Open nuance:
  when a single pin is rotated, do we rotate the label too? REC: keep the label's own
  `name_rot` unless the user changed it.)

### 4.4 Name sync — both directions
- **View → pin (write-through, S2):** editing a SYNTH view's content renames its owning
  pin (`name=`). The existing text→pin code (`editprop.c:730-760`) becomes the basis,
  but now keyed off the SYNTH marker + the view's `owner_pin_id` (not name+proximity).
- **Pin → view:** when `name=` changes via the pin property path (`edit_rect_property`,
  `editprop.c:258-359`), just regenerate the owning pin's view (content = new name).

**Two property dialogs, one logical entity (confirmed UX, 2026-06-29):** in the symbol
editor —
- **`Q` on the PIN** (rect property dialog) → edit `name=` (and `dir`, `show_pinname`,
  layout tokens); changing the name updates the displayed text (regenerate view).
- **`Q` on the displayed NAME TEXT** (the SYNTH view) → edit size / font / etc. (writes
  through to `name_size`/`name_font`/… on the pin), AND editing the text *content* renames
  the pin (write-through to `name=`).
So either dialog edits the same pin; name is bidirectional. (Layout tokens must cover
everything the text dialog/ops can change: `name_dx name_dy name_rot name_flip
name_xscale name_yscale name_font name_hcenter name_vcenter`; `name_size` is shorthand
when xscale==yscale.)

### 4.5 Delete (req. 2 + decision 3)
- **Delete a pin → its view goes too, automatically.** The view is derived from the pin
  tokens; when the pin rect is deleted in `delete()` (`select.c:525`), drop its SYNTH view
  (it has nothing to regenerate from). One `push_undo` wraps the op → atomic undo.
- **Delete the view alone: DISALLOWED (decision 3).** In `delete()`'s text loop
  (`select.c:547-575`), **skip SYNTH views** unless their owning pin is also being deleted.
  The label is never an independently destroyable object; hiding is via `show_pinname`.

### 4.6 Copy / paste
- The pin's layout + show flag + name travel in the pin rect's `prop_ptr` (copied/pasted
  wholesale by `copy_objects` `move.c:636` / `paste.c`). After the pin is copied/pasted
  **and its name uniquified**, simply **regenerate its view** (S1) from the new tokens —
  no binding to thread, no separate label to copy. SYNTH views in the selection are NOT
  copied as objects (skip them in `copy_objects`); they're rebuilt from the copied pins.
- This is the payoff of Option B: the previously "most delicate site" is now a regenerate.

### 4.7 Undo / redo / save / load
- **Save (S3):** `write_xschem_file` skips SYNTH views; pin tokens are already authoritative
  (write-through), so nothing to fold at save time beyond ensuring tokens are current.
- **Load (S1):** after `load_schematic` (symbol-edit doc), synthesize a view per shown pin.
- **Undo/redo:** snapshots/restores pin rects (authoritative tokens) normally
  (`in_memory_undo.c`); after a restore, **regenerate views** from the restored pins
  (treat views as derived — simplest and always-consistent; do not rely on snapshotting
  the transient views).

### 4.8 Show/hide property UI (req. 5) — global toggle WINS (decision 2)
- Per-pin: a **"Show name"** checkbox in the pin property dialog bound to `show_pinname`
  (default true).
- Global: a tri-state view toggle `show_pin_names` (mirrored C↔Tcl, `MIRRORED IN TCL`):
  `on` → force-show all pin names, `off` → force-hide all, `auto` → defer to each pin's
  `show_pinname`. **The global setting WINS** when it is `on`/`off`; per-pin only applies
  in `auto`. Effective visibility = `global==on ? show : global==off ? hide :
  pin.show_pinname`. Draw gate (§4.2) evaluates this.

### 4.9 Netlist / ERC invariance
- The label is **display-only**; netlisting reads the pin rect `name=` (unchanged), so
  **netlist output must be byte-identical** — assert via the `tests/netlisting` golden
  suite. `check.c` (symbol consistency): add a warning for a pin whose owned label is
  missing/mismatched, and for duplicate pin names (which make the binding ambiguous).

---

## 5. Migration script (req. 6)

A standalone **Python 3** tool (no xschem dependency), operating textually on `.sym`
files. Lives under `src/` or `doc/claude/` tooling (decide placement); shipped as a
utility, documented.

### 5.1 CLI
```
migrate_pin_names.py FILE.sym                 # one file
migrate_pin_names.py --dir DIR [--recursive]  # a tree (e.g. xschem_libraries_oa)
  --dry-run            # report only, write nothing
  --backup / --no-backup   # default: write FILE.sym.bak before editing
  --adopt / --no-adopt     # adopt existing literal labels vs always create new (default: adopt)
  --default-size 0.2       # hsize/vsize for created labels
  --show / --no-show       # initial show_pinname for created/adopted labels (default: show)
  --exclude GLOB ...       # skip paths
  --report FILE            # machine-readable summary (json/csv)
  -v                       # verbose per-pin actions
```

### 5.2 Algorithm (per `.sym`)
1. **Parse brace-aware** (NOT naive line split): `T {...}` text can contain newlines
   inside braces; honor escapes `\{ \} \\` (matches `save.c` `load/save_ascii_string`).
   Tokenize records by leading tag (`v K G V S F E L B A P T N C`).
2. **Skip whole-file** if: 0 pins; symbol `type=` is `label`/`launcher`/`logo`/`probe`/
   `architecture`/`noconn`/`title`/etc.; or it's a netlist-only / analyses symbol.
3. **Enumerate pins** = `B 5 ...` records in file order (index = order). Extract `name=`
   (handle quotes + bus brackets `A[max:0]`; preserve verbatim). Skip pins whose name is
   `@`-templated.
4. For each pin (decision 5):
   - If the pin is **already migrated** (Option A: a `pinlabel` text bound to it; Option B:
     it already has `name_*` layout tokens) → **idempotent skip**.
   - Else if a **literal label exists whose text EXACTLY matches the pin name** (`T
     {<exactname>}`, no `@`, near the pin) → **adopt** it as the pin's label
     (Option A: add the key token; Option B: fold its geometry into the pin's `name_*`
     tokens and drop the `T`), `show_pinname=true`.
   - Else → **create** a default label for the pin (Option A: a `T {<name>}` near the pin
     mirroring `add_symbol_pin` offsets; Option B: default `name_*` tokens) and set the
     pin **hidden** (`show_pinname=false`) — so the pin has an (off) name ready, and any
     non-matching legacy text in the symbol is left untouched as ordinary stray text.
5. **Preserve formatting** of all untouched lines exactly (line-oriented edits; only
   add/modify affected `B`/`T` records) to keep diffs minimal and avoid reflow bugs.
6. Write `.bak`, then the file (unless `--dry-run`). Emit a per-file summary
   (created/adopted/skipped/warnings).

### 5.3 Migration edge cases (must handle)
- **Bus pins** `name=A[max:0]`, `DIN[width-1:0]` → copy the bracketed name verbatim.
- **Duplicate pin names** (`short.sym` two `A`; `conn_10x2.sym`) → can't bind by name
  alone; bind by nearest-pin/position and WARN; never create two labels for one text.
- **Already-labeled (~15%)** → adopt, don't duplicate.
- **`@#N:net_name` / `@#N:pinnumber` / `@`-anything** → never treat as a name label.
- **0-pin symbols (257), label/logo/etc. types** → skip.
- **Idempotency** → re-running must be a no-op (the `pinlabel=true` marker is the guard).
- **Generators** (`generators/`, `symgen/`, scripts that *emit* `.sym`) → migrating their
  output is fine, but the generator may overwrite later; note as a follow-up to also
  update generators.
- **Embedded symbols inside `.sch`** (`[ ... ]` blocks, `embed=true`) → none found in the
  stock library; document that the script targets standalone `.sym` only (a `.sch`-aware
  mode is a possible later extension).
- **Schematic pins** (`C type=ipin/opin/iopin` instances) → NEVER touched; we only edit
  `B` layer-5 records in `.sym`.
- **File hygiene**: UTF-8; preserve trailing newline; skip non-`.sym`; follow/ignore
  symlinks deliberately; handle read-only files (warn/skip); large trees (stream files).

---

## 6. Things you might have overlooked (anticipated)

1. **Instance display, not just symbol-edit.** Pin names should (optionally) show on
   placed instances — free in Model B, but interacts with existing per-instance
   `@#N:net_name`/`pinnumber` texts, `hide_texts`, and `show_hidden_texts`. Decide
   default visibility on instances vs only in symbol-edit.
2. **The interactive add-pin path currently makes NO label** (`scheduler.c:263`) — fix so
   all creation paths produce an owned label.
3. **"Label follows pin" on move** (§4.3) — without it, moving a pin orphans its label.
4. **Copy/paste uniquification** (§4.6) — copied pins are renamed; the label + binding
   must follow, or you get a label pointing at the wrong/duplicate name.
5. **Duplicate / empty / `@`-templated pin names** — break name-based binding; need
   proximity fallback + warnings; never auto-rename a user's pins to disambiguate.
6. **Bus pins** — bracketed names must survive verbatim in label, sync, and migration.
7. **Name stored ONCE** (pin `name=`; under Option B there is no persisted label string).
   The only sync is the in-session VIEW content ↔ pin `name=` (write-through); on disk
   there is nothing to keep consistent. Still ensure scripted `setprop name=` / bus-style
   renames regenerate the view.
8. **Netlist invariance** — display-only; assert golden netlists unchanged (§4.9).
9. **Don't double-draw / don't double-migrate** existing literal labels (~15%) — adopt via
   marker, idempotent.
10. **Default size & the wire-stub dependency** — Thread B reads "the pin's text size"
    from the owned label's `yscale`; ensure that getter (`get_pin_name_size`) reads the
    bound label, with a default when `show_pinname=false`/no label.
11. **Backward compatibility** — old symbols (no marker) opened in new xschem must look
    unchanged: do NOT auto-generate owned labels on load; only creation + migration
    produce them. New tokens are ignored by old xschem (no version bump).
12. **show/hide precedence** — per-pin `show_pinname` vs a global view toggle (§4.8).
13. **Delete-label-alone semantics** (§4.5) and **rotate-single-pin** (§4.3) — define.
14. **Generators & symbol-from-schematic** must emit owned labels (§4.1).
15. **`@#N:pinnumber` proximity collisions** — a created name label must not overlap the
    common pinnumber text; offset rule should avoid the layer-13 number texts.
16. **Performance** on large schematics — show/hide lookup per label; cache per symbol.
17. **Tcl mirroring** for any new global var; **check.c/ERC** warnings; **docs/tutorial**
    update (`tutorial_create_symbol.html` shows the old manual `@#N` method).
18. **Undo atomicity** — pin+label create/delete must be one undo step (single push_undo).

---

## 7. Decisions
**Resolved (2026-06-29 — see §3.2.1):** (1) Model B. (2) per-pin + global toggle, global
wins. (3) label cannot be deleted alone; hide via pin property. (4) the label IS the name,
exactly one per pin. (5) adopt only on exact name match, else hide + leave stray text.

**Resolved:** (6) **Identity = Option B** (chosen 2026-06-29, §3.3) — label folded into the
pin tokens, no separate persisted object.

**Resolved (2026-06-29):**
- **A. Default label size:** tunable Tcl var `sym_pin_name_size`, default **0.2**.
- **B. Migration tool location:** **`tools/migrate/`** (Python).

- **C. Materialization scope:** **Way A** — editable views only in symbol-edit; instances
  draw names directly from pin tokens; the `sym[]` cache is never augmented (§3.2 note).

**All design decisions are now LOCKED.** Ready to implement from §8 (P0).

---

## 8. Phased implementation plan (Option B)
- **P0 — token + view model. [DONE 2026-06-29, branch `cadence-pin-name-text`, uncommitted]**
  Tokens `show_pinname` + `name_dx/dy/size/rot/flip` read by `synth_pin_views()`. The view
  marker is a single new transient field **`xText.owner_pin_id`** (`xschem.h`; =owning
  pin's `xRect.id`, 0 = ordinary text) — no flag bit needed. `synth_pin_views()` +
  static helpers `pin_dtok`/`pin_name_shown`/`pin_name_view_of` in `actions.c` (after
  `set_text_flags`). `owner_pin_id` initialized at ALL text-birth sites: `create_text`
  (actions.c), `load_text`/`merge_text` (save.c/paste.c), `copy_objects` (move.c).
  `create_pin()` deferred to P2 (not needed to test P0/P1). "Owned" pin == has a
  `show_pinname` token (legacy pins have none → never auto-shown → appearance preserved).
- **P1 — persistence seams (S1 + S3). [DONE 2026-06-29, uncommitted]** S1: `synth_pin_views()`
  called at end of `load_schematic` (after symbol-mode detection), gated on
  `netlist_type==CAD_SYMBOL_ATTRS`. S3: `save_text()` skips texts with `owner_pin_id!=0`.
  **Undo needs NO special code** — views live in `xctx->text[]`, so `owner_pin_id` rides
  the struct-copy in `in_memory_undo.c` snapshot/restore and `xRect.id` survives restore,
  keeping the link valid (the earlier "regenerate on undo" idea would DOUBLE views — not
  done). Test `tests/pin_name_text.tcl` (12 checks, `--nogui`, standalone like
  `pin_select.tcl`): synth-on-load count, save-skip (0 `T`), byte-identical round-trip,
  legacy/hidden negatives, mixed stray-`T`+view. ALL PASS; core regression
  (create_save/open_close/netlisting) clean.
- **P2 — creation.** Route BOTH `add_symbol_pin` paths through `create_pin` (tokens + view,
  no standalone `T`); default placement/size (`sym_pin_name_size`).
- **P3 — write-through (S2).** View move/resize/rotate/flip/content-edit → pin tokens
  (`move_objects` END + `editprop.c`); pin rename (`edit_rect_property`) → regenerate view.
- **P4 — delete + copy/paste.** `delete()` skips lone SYNTH views, drops a deleted pin's
  view; `copy_objects`/paste skip view objects and regenerate after name-uniquify.
- **P5 — show/hide.** Global tri-state `show_pin_names` (wins) + per-pin `show_pinname` +
  pin-dialog checkbox; visibility rule in the draw gate.
- **P6 — instance display.** `draw_symbol` pass rendering pin names from symbol pin tokens.
- **P7 — ERC/check + netlist invariance + docs/tutorial.**
- **P8 — migration script** + fixtures (the §5 representative files) + idempotency/dry-run/
  backup tests; supervised run over `xschem_library` (+ the user's `xschem_libraries_oa`).
- **P9 — Thread B getter** `get_pin_name_size` reads `name_size`; unblock wire-stubs.

## 9. Test plan
- Headless `.tcl`: create pin → assert rect + `pinlabel=true` text with content==name +
  `show_pinname=true`; rename via pin dialog → label updates; rename via text edit → pin
  updates; delete pin → label gone (1 undo restores both); delete label alone → pin stays;
  move pin → label follows; copy pin → unique name + bound label; toggle show_pinname →
  draw-gated; save/load round-trip preserves all tokens; **netlisting golden unchanged**.
- Migration: run on fixtures → assert created/adopted/skipped counts, idempotent re-run is
  a no-op, `--dry-run` writes nothing, bus/dup-name handled, `.bak` created.

## 10. Quick reference — verified file:line
| What | Where |
|---|---|
| Symbol-edit uses live arrays; mode detect | `save.c:3770-3795` (`CAD_SYMBOL_ATTRS`); PINLAYER=5 `xschem.h:169` |
| Pin = `B 5 ... {name= dir=}`; load/save | `save.c:3010-3070` (load_box), `save.c:2568-2571` (save) |
| Text = `T {..} x y rot flip xs ys {props}` | `save.c:2588-2593` / `2812-2836`; escapes `save.c:2508`,`3254` |
| Add a pin (rect+label+stub) | `add_symbol_pin` `scheduler.c:220-270`; `create_text` `actions.c:3968` |
| Text→pin rename sync (existing) | `editprop.c:730-760` (name-match + proximity) |
| Pin (rect) property edit | `edit_rect_property` `editprop.c:258-359`; dispatch `editprop.c:1445` |
| Text property/content/size edit | `edit_text_property` `editprop.c:647-776`; content `:759`, size `:773-775` |
| Interactive text resize | actions `edit.text_grow`/`edit.text_shrink` `callback.c:2940-2942` |
| Move/rotate/flip text | `move_objects` text branch `move.c:1859-1903` |
| Delete (single choke point) | `delete()` `select.c:525`; text-del loop `:547-575`; rect-del `:402-418` |
| Copy text/rect | `copy_objects` `move.c:636` (text `:904-958`, rect `:845-902`) |
| Paste | `paste.c` `merge_text:29`, `merge_box:72` |
| Undo snapshot/restore | `in_memory_undo.c` text `:364-376`/`:508-523`, rect `:314-320` |
| Token read/modify (unknown preserved) | `get_tok_value` `token.c:438`; `subst_token` `token.c:1234`, preserve `:1378-1390` |
| Per-pin attr ref on instances | `get_pin_attr` `token.c:4166-4292` (`@#N:attr`) |
| File version (no bump needed) | `XSCHEM_FILE_VERSION "1.3"` `xschem.h:27` |
| Pin coord on instance (Thread B) | `get_inst_pin_coord` `netlist.c:753` |
| Library survey | 1711 `.sym`; 1454 with pins; ~15% pre-labeled; dup names: `short.sym`,`conn_10x2.sym` |
