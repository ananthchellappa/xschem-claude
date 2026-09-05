# 1331 — the narrow arm refuses a symbol path containing a space, in the store's own internal jargon

**Status: FILED, NOT FIXED.** Found by item **B5-3**'s adversary, reproduced
independently by the write-up agent. Subject: `rdw::_edit`'s `narrow` arm
(`src/rdw.tcl`) and `op_param_lists::_key_why`.

## The shape

`rdw::_edit`'s narrow arm has two up-front guards, each with a complete
sentence AND a way forward:

* no cell name → *"this device's symbol has no cell name, so there is no
  device-flavor entry to write. **Choose every device of class `X` instead.**"*
* glob metacharacters in the cell name → *"…a key written from it would never
  match this device again. **Choose every device of class `X` instead.**"*

A cell name containing **whitespace** matches neither. It falls past both into
`op_param_lists::set_list`, and the user is handed the store's raw internal
wording.

## The measurement

Before: the two guards above, each measured and each offering the class-wide
alternative.

After (measured on this tree, `./src/xschem --nogui --pipe -q --nolog`, a
narrow Delete of `gm` on a symbol at `/home/u/My Designs/sp.sym` — an entirely
ordinary path):

```
CN='/home/u/My Designs/sp.sym' P=gm -> refused ::
  the flavor key "spxcls {/home/u/My Designs/sp.sym}" has a field that is empty
  or carries whitespace, so it could not be written back
CN='sp.sym'                    P=gm -> ok      :: removed gm from the annotation
  list for cell sp.sym only. …
```

The same run confirms the sibling guard still fires correctly:

```
CN='a[bc].sym' P=gm -> refused :: the cell name a[bc].sym contains glob
  characters, and a device-flavor entry is matched as a glob - a key written
  from it would never match this device again. Choose every device of class
  spxcls instead.
```

## What is wrong with the sentence

1. **Brace syntax is exposed.** `"spxcls {/home/u/My Designs/sp.sym}"` is a Tcl
   list rendering of an internal two-element key. The user never typed it and
   cannot act on it.
2. **"empty or carries whitespace" is ambiguous** — it names two different
   causes and says which applies to neither.
3. **No way forward.** Both sibling guards end in *"Choose every device of class
   `X` instead."* This one does not, and the class-wide edit **does** work —
   measured: broad scope on the same subject is accepted.

Nothing is stored and nothing is mis-written. This is a wording defect in the
one feature whose stated standard is that different facts get different,
complete sentences.

## Recommended fix

A **third up-front guard** in `rdw::_edit`'s narrow arm, beside the two that
already exist, so the refusal is minted where the other two are and carries
their shape: name the cell, say a device-flavor key cannot hold whitespace, and
end in *"Choose every device of class `X` instead."*

Rejected: rewording `op_param_lists::_key_why` — it is the STORE's sentence to
the store's own callers, it is correct in its own units, and window row
**BT22** exists precisely so `rdw.tcl` does not reach into the store's private
vocabulary. Two doors, one rule, two audiences.

## Acceptance

A row driving a narrow edit on a cell name with a space and asserting the
refusal names the cell, does NOT contain a brace, and DOES contain the
class-wide alternative — plus its partner, that broad scope on the same subject
is accepted and stores.

## Still open

`op_param_lists::_key_why`'s "empty or carries whitespace" wording stays as-is;
it is the store talking to the store.
