# 0225 — `browser_target_path` mis-decodes All-DBs `d:N|` ids, so "Descend to here" fires a garbage instance path

Status: **FIXED** 2026-08-08 — both sites, by TWO-PANE item 8 of the two-pane Signal Browser
batch (`doc/claude/specs/waveform_signal_browser_two_pane.md` §4.3).
Originally filed as: **OPEN**, pre-existing since single-pane Signal Browser item 14
(All DBs) met item 11 (`Descend to here`).
Found by: the two-pane batch's pre-item read of `browser_target_path`, in the same pass that
found 0217 — recorded there (`0217:190`, "The other live `browser_target_path` defect found
in the same pass … is a **separate** bug in the same proc. File and fix it independently")
and given its own number here so the parent spec can cite it.

## Symptom

With **All DBs** ticked the tree grows one level: each loaded results database becomes a top
node and `browser_rows_reparent` prefixes every id inside a *foreign* group with `d:<idx>|`.
A row that would be `g:x1.x2` in the current DB is `d:1|g:x1.x2` under the second one.

`browser_target_path` decoded a group id by stripping two characters by hand:

```tcl
set path [string range $id 2 end]      ;# "g:x1.x2" -> "x1.x2"
```

On `d:1|g:x1.x2` that yields `1|g:x1.x2`. The consequence is not a refusal — it is worse:

* **`Descend to here` is ENABLED on foreign rows**, because a non-empty string reads as a
  perfectly good instance path;
* the descend then walks toward an instance named `1|g:x1` and fails somewhere inside
  `hier_walk`, i.e. the failure surfaces one layer below where the mistake was made.

A second, byte-identical `string range $id 2 end` sat in `browser_show_path`, on the
`landed` value it reports back to the user — so the *message* could be wrong even when the
move was right. **Fixing one and not the other leaves the pair inconsistent**, which is why
the spec's ruling is "fix both or neither".

## Why it was invisible

The current DB is always group 0 and is **unprefixed** (`BD22`), so every single-DB fixture
and every All-DBs fixture that only ever descends inside the current design decodes
correctly. The defect needs *two* raws loaded **and** a gesture on a row belonging to the
*second* one.

## The fix

One decoder, `wviewer::browser_id_path`, called from both sites. It strips the optional
`d:<idx>|` DB prefix first and the `g:` / `s:` namespace second, so `d:1|g:x1.x2` and
`g:x1.x2` both answer `x1.x2` and the bare design root `g:` answers the empty string.

## Evidence

`tests/headless/test_wave_sigbrowser_2pane.tcl:844-849`, `TP44`, in both directions and in
one commit:

* `regexp -all {string range \$id 2 end}` over the bodies of `browser_target_path` **and**
  `browser_show_path` is `{0 0}` — the hand-strip is gone from **both**;
* the positive control on the same two bodies, `regexp -all {browser_id_path}` is `{1 1}` —
  they both call the one decoder, so `{0 0}` cannot be a proc that was simply deleted.

The parent spec's contract entry is `doc/claude/specs/waveform_signal_browser.md` §10.10.

## Related, and not the same

* **0212** — vector instance slices (`x1[3]`) are not addressable by `Descend to here`. That
  is path *arithmetic* below `hier_walk`; this was path *derivation* above it. Still open.
* **0217** — device-class prefixes rendering as fake hierarchy levels. Same proc, same
  reading pass, different defect. Fixed by TWO-PANE item 1.
