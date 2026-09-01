# 0925 — saved net-highlight styles are discarded at every startup

**Status:** **OPEN, MEASURED, NOT FIXED.** Found 2026-08-29 by the adversarial
review of the [0924](0924-file-open-recent-empties-whenever-a-stock-xschem-touches-the-same-conf.md)
fix, and re-measured independently before filing.

**This is 0924's read half, unfixed, 1770 lines above the fix, in the same file.**

---

## 1. What the user sees

They open **Tools > Net highlight styles…**, build a style table, and save it to
the location the dialog itself describes as *"loads automatically next session"*.
Next session it is **not** loaded: the built-in default table is in force and
their rows are gone from the running program. Nothing is printed.

The same proc also loads the breadcrumb that records the editor has been opened
at least once, so the command palette's first-launch emphasis on that entry
**comes back every session** no matter how many times they use it.

## 2. The measurement

`src/xschem.tcl:737-746`:

```tcl
proc load_net_hilight_conf {} {
  global USER_CONF_DIR
  foreach f {net_hilight_editor_seen net_hilight_style} {
    if {[file exists $USER_CONF_DIR/$f]} {
      if {[catch {source $USER_CONF_DIR/$f} err]} {
```

Both files persist **unqualified** names — `set net_hilight_editor_seen 1`
(written at `src/xschem.tcl:706` and `:727`) and `set net_hilight_style {...}`
(`:728`). `source` runs in its caller's frame; the proc declares only
`global USER_CONF_DIR`. So both names become **proc-locals** and die when the
proc returns. Exactly what `set recentfile {...}` did in 0924.

Measured in an isolated `HOME` holding a one-line
`~/.xschem/net_hilight_editor_seen` that says `set net_hilight_editor_seen 1`:

```
file on disk says: set net_hilight_editor_seen 1
SEEN = <0>
```

The `catch` never fires, so there is no diagnostic. `load_net_hilight_conf` is
called at top level from `src/xschem.tcl:17396` — this is the real startup path,
not a corner.

The style file ends with `catch {xschem update_net_hilight_style}`, which cannot
rescue it: that recompiles from the **global**, which the source never touched.

## 3. Why this is NOT the 0924 cross-version story

`grep -c net_hilight /usr/local/share/xschem/xschem.tcl` is **0**. Stock xschem
has no idea these files exist and never writes them. There is no old build to
blame and **no write-half destruction — the conf on disk is intact, merely
ignored.** That is why this is filed separately rather than folded into 0924.

## 4. The test that should have caught it is green

`tests/headless/test_nh_editor_persist.tcl:43-46` sources the conf **itself, at
global script scope**, instead of calling `load_net_hilight_conf`. At global
scope the unqualified names land where they are wanted, so the suite's
persistence checks pass over a product loader that does not work. Nothing in
`tests/` calls `load_net_hilight_conf` at all (`grep` = 0 hits).

**This is the standing-red class in reverse**: not a red that is furniture, but a
green that never touched the product path it names.

## 5. The fix

The same one-line repair 0924 used, and measured green by the review agent
without editing the tree:

```tcl
uplevel #0 [list source $USER_CONF_DIR/$f]
```

Tcl 8.4-safe. The names are unqualified by design here (unlike 0924 there is no
second spelling to reconcile), so no compat line is needed — only the scope.

The test must change with it: call `load_net_hilight_conf` rather than sourcing
the conf by hand, or the suite goes on being green either way.

## 6. Severity

**Medium, not high.** No data is destroyed on disk. The measured losses are the
first-launch emphasis returning every session, and a saved table being replaced
by the default in the live session. A later Save from the editor would then write
the defaulted table back over the user's file — read from the code
(`src/xschem.tcl:1423-1431`, snapshot taken from the live table at `:1606`),
**not measured**, and it is the reason this should not sit indefinitely.

The user's own `~/.xschem` holds `net_hilight_editor_seen` but no
`net_hilight_style`, so what they are losing today is the breadcrumb.
