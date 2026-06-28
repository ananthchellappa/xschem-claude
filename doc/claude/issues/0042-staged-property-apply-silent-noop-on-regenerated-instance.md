# Issue 0042 — Staged property Apply silently no-ops when the target instance was regenerated/invalidated

**Opened:** 2026-06-26
**Status:** OPEN
**Severity:** MEDIUM-HIGH — silent edit loss; the user believes the property edit applied but it did not.
**Branch:** `fluid-editing`.
**Source:** `/code-review high` this session (workflow `wf_1a6ce6c4-0d9`), finding #4 (CONFIRMED).
**Affects:** `src/editprop.c` `apply_instance_properties()` (~:1040), called from `scheduler.c:193`
for `xschem apply_properties`. Resolves the target via `inst_index_from_id(displayed_id)` (a
stable-id linear scan) and returns 0 (no-op) when `idx < 0`. Related: [[slick-property-forms]],
[[stable-object-handles]].

---

## 1. Symptom

With the staged-commit per-field property form, if the edited instance is regenerated, deleted, or
invalidated (e.g. an intervening undo, a symbol reload, or a regenerate-abstract between opening Edit
Properties and pressing Apply/OK), the property edits are **silently discarded** — no error is shown,
the form closes as if successful.

## 2. Root cause

`apply_instance_properties()` resolves its target by the stable id captured when the form opened
(`inst_index_from_id(displayed_id)`). When no live instance still carries that id the function returns
0 and applies nothing, but the caller treats it as success and surfaces no error.

## 3. Fix sketch

When the id no longer resolves (`idx < 0`), surface the failure: `ciw_echo` + a `tk_messageBox`
("the object being edited no longer exists; changes were not applied"), and keep the form open (or
refuse to close) rather than silently dropping the edit. Optionally re-resolve by a secondary key
(position/name) before giving up. Add a test: open the form, invalidate the instance (undo), Apply →
assert a non-zero/error result and a CIW message rather than a silent 0.

## 4. Acceptance

A staged property Apply against a vanished/regenerated instance reports the failure to the user instead
of silently succeeding.
