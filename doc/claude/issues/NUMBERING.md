# Issue number reservations — read before filing

Two blocks are reserved for other branches. Filing into them collides with work
this branch cannot see, and the 02xx renumbering recorded in `status.md` is what
that costs to undo.

| block | owner | rule |
|---|---|---|
| **0500–0599** | the fluid-editing branch | after **0499**, the next number is **0600** |
| **0700–0799** | reserved (user, 2026-08-24) | after **0699**, the next number is **0800** |

So the filing sequence is:

```
… 0498  0499  0600  0601 …  0698  0699  0800  0801 …
```

Highest filed on `annotate` as of 2026-08-24: **0677** (0668-0673 filed by the
0663 crew; **0674-0677 by the 0664+0665+0666 crew**). The next number is
**0678**.

`status.md` covers the fluid-editing branch and its 02xx numbering.
`status_annotate.md` covers this branch, 0600–0673. They do not share a number
space.
