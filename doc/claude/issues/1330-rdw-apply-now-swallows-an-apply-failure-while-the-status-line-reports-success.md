# 1330 — `rdw::_apply_now` swallows an `apply` failure while the status line reports success

**Status: FILED, NOT FIXED.** Found by item **B5-3**'s adversary, reproduced
independently by the write-up agent. Subject: `rdw::_apply_now`
(`src/rdw.tcl`) and the call order inside `rdw::button`.

## The shape

`rdw::button` composes its whole status sentence from `rdw::_edit` — the
decision core — **and only then** calls `rdw::_apply_now`, whose three calls
are each wrapped in a bare `catch` and which returns `{}` unconditionally:

```tcl
catch {::op_param_lists::apply}
if {$t ne {}} { catch {::op_param_lists::apply $t} }
catch {xschem redraw}
return {}
```

`op_param_lists::apply` reports through its own `said` tail. Nothing reads it
back. So **any** failure inside `apply` — a descriptor that will not
re-register, a malformed union, an `op_annot::register` raise — is invisible,
and the user is shown the sentence that was true one step earlier.

## The measurement

Before (source read, `src/rdw.tcl`): `_apply_now`'s body is three `catch`es and
a bare `return {}`; `rdw::button` calls `_edit` before `_apply_now`.

After (measured on this tree, `./src/xschem --nogui --pipe -q --nolog`, with
`::op_param_lists::apply` replaced by a proc that raises):

```
APPLY_NOW_RC   = 0
APPLY_NOW_RES  = ''   (empty = the failure is invisible to every caller)
EDIT_BEFORE_APPLY = 1 (1 = the sentence is built before apply runs)
```

The adversary reached the same state without a synthetic proc, through the
direct `::op_annot::desc` door of issue **1326**: `shown` came back `NOKEY` and
`said` carried `cannot register the parameter lists` **twice**, while the status
line reported the edit had landed.

## Why it was built this way, and why that reason is now thin

`_apply_now` is deliberately silent because ruling **DD-6**'s two calls are
belt-and-braces: the bare `apply` covers the class's mapped siblings, the typed
one covers a `type=` token the class map does not name (issue **1279**), and
*either* may legitimately answer nothing. A raise, though, is not "answered
nothing" — it is the store telling the caller it could not do the job.

## Recommended fix

One `said`-tail read **after** `_apply_now`, in the shape `rdw::_edit` already
uses for `set_list`: capture the store's report count before the call, read the
tail after, and append it to the status sentence when it is non-empty. That is
`rdw::_store_tail`'s existing idiom moved one call later — no new rule, no new
wording, and it satisfies the same principle the success-arm read satisfies
(issue **1288**: "the two doors reach the same verdict with the same sentence
and the user is told once").

Rejected: making `_apply_now` raise (it runs on every button press and a raise
inside a Tk `-command` reaches `bgerror`, which is issue **0803**'s modal-hang
shape); returning a value nobody is obliged to read (the same silence with more
code).

## Acceptance

A row that forces `apply` to fail and asserts the status line SAYS SO — and its
partner, that an ordinary successful press gains no extra clause. Two-sided, or
the fence passes by being unconditional.

## Still open

Nothing today reaches this in production: the only measured route to an `apply`
failure is the duplicate-label descriptor of issue 1326, and **DD-15** now
refuses that at `op_annot::register`. This is a **silent-failure channel**, not
a live defect — which is exactly the kind that surfaces the first time some
later item gives `apply` a second way to fail.
