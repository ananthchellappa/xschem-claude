# 0376 — `load_schematic()`'s failed-open arm reads 4 bytes before `name[]` for a filename shorter than 4 characters

Status: **OPEN — STUB, claimed by item D5 (descend census part 2), deliberately NOT fixed there.**
Source-read only; no transcript. Noticed while editing the adjacent lines for
[0261](0261-descend-reports-success-on-a-blank-page.md).

Area: `src/save.c:3817-3819`, inside the `fd == NULL` arm of `load_schematic()`:

```c
      len = strlen(name);
      if(!strcmp(name + len - 4, ".sym")) {
```

`len` is unguarded. For any `name` shorter than 4 bytes — `"/a"`, `"ab"` — `name + len - 4`
points *before* the `char name[PATH_MAX]` buffer and `strcmp` reads it. The same idiom
appears nowhere else in the function; every other extension test in the file goes through
`add_ext()` / `get_cell_w_ext()`.

The header of the function says "ALWAYS use absolute pathname for fname", which makes a
1–3 byte name unreachable through the shipped callers as far as a source read can tell, so
this is filed as a latent unguarded read rather than a live crash. It is still a one-line
fix (`if(len >= 4 && !strcmp(name + len - 4, ".sym"))`) and it sits in the exact arm D5
edits, so it is recorded here rather than fixed silently or left unrecorded.

## What a fix needs

1. Confirm the reachability claim — grep every `load_schematic()` caller for a path that can
   be shorter than 4 bytes (`load_backup_as`, `go_back`, the `xschem load` branch,
   `descend_symbol`'s `sympath`, `font.c:34`).
2. Add the length guard.
3. A row in an existing suite only if step 1 finds a reachable caller; otherwise the guard
   lands uncovered and is documented as such.
