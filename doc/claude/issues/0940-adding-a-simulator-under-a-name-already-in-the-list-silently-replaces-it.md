# 0940 — adding a simulator under a name already in the list silently replaces it

**Status: OPEN.** Measured on the `Setup > Simulators…` dialog that issue 0937
shipped, and reproduced first-hand at the registry level by the write-up agent.

**This is the same defect row S9 exists to prevent, reachable through the other
button.** `ase::ui::simdlg_ok` carries an entry's extra arguments and its backend
through an **Edit** untouched — that is what S9 pins. The **Add** path runs the
same code with empty values and has no guard and no row.

## What the user does

Press `Add…`, type a name that is **already** in the list, give it a different
program, press OK.

## What happens

The existing entry is replaced, its extra arguments and its backend are wiped,
and the dialog reports **success**:

```
F2 before: args='-b --define x' backend='ngspice'
F2 after : args='' backend='' path=/tmp/wu0937/bin/ngb
F2 entries now = ng  (an Add added nothing; it replaced)
F2 register returned 1 and said: ''
```

`ase::sim_register` does a bare `dict set simulators $name [dict create …]` with
no already-registered check, and says nothing. The status line then reads *"The
simulator named ng is the one that will be used…"*, so every visible signal is
green while the user's settings are gone.

Combined with **0939**, `Add…` onto a name a startup configuration file declared
does the same takeover.

## Why this matters here specifically

The item brief names this failure mode by name: *"validation feedback shown IN
the dialog, not only in the CIW, because silence is this area's failure mode."*
An Add that overwrites is the one gesture in this dialog that destroys something,
and it is the one gesture that says nothing at all.

## What is still open

The fix is a decision, not just code. Either **refuse** the Add and say the name
is taken (offer Edit instead), or **confirm** it and say what will be lost. The
first is more consistent with the dialog's read-only Name field in Edit mode —
a rename is already Remove-then-Add — and does not need a new sentence about
discarded settings. Both need a new minted sentence under **D5-4**.

## Acceptance rows this needs

An Add onto an existing name must either leave the entry untouched and explain,
or preserve `-args`/`-backend` — asserted through the real `Add…` button and the
real OK button, the way S9 drives the Edit path.
