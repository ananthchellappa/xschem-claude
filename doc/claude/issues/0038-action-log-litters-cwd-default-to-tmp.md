# Issue 0038 — action log defaults to the cwd, littering the repo root and `src/` with `Xschem.log[.N]`

**Opened:** 2026-06-26
**Status:** ✅ RESOLVED (2026-06-26). `init_action_log()` now defaults the no-`--logdir` log
location to the temp dir (`$TMPDIR`, else `/tmp`) instead of the current working directory; the
cwd is used only as a last resort when no temp dir exists. Fixed on `fluid-editing`.
**Affects:** `src/util.c` (`init_action_log`); anyone who launches the GUI from inside the source
tree (`./xschem` from the repo root, or `cd src && ./xschem` per CLAUDE.md) without passing
`--logdir`. Previously reported informally in an earlier session (the
[[action-logging]] memory noted "repo-root Xschem.log* are the user's interactive logs — leave
them"); this issue supersedes that guidance — the user now wants them out of the tree.
**Severity:** low — disposable, already-gitignored files; pure working-tree clutter, no data loss
and no effect on commits. Annoying because the rotation keeps **up to 10 per directory** and the
files reappear in *every* directory the GUI is launched from.
**Branch:** `fluid-editing`. See [[action-logging]] (feature), [[user-run-config]] (the user runs
`src/xschem --script src/cadence_style_rc --logdir /tmp`, so their *own* runs already avoid this).

---

## 1. Symptom

The repo root and `src/` accumulate files like:

```
Xschem.log  Xschem.log.1  Xschem.log.2 … Xschem.log.9
src/Xschem.log  src/Xschem.log.1 … src/Xschem.log.9
```

Each is tiny (often just the 20-byte header `# xschem action log`). They are listed in
`.gitignore` (`Xschem.log` / `Xschem.log.*`, which match at any depth, so the `src/` copies are
ignored too) and none are tracked — so this never pollutes a commit. It is purely visual/working-
tree clutter that returns after every interactive run.

## 2. Root cause

`init_action_log()` (`src/util.c`) opens a fresh per-session action log for any **interactive**
run (`has_x` true) or whenever `--logdir` is given. When `--logdir` is *not* given it chose the
**current working directory**:

```c
  } else {
    my_strncpy(dir, ".", S(dir));   /* <-- logs land wherever xschem was launched */
  }
```

The slot picker then writes `Xschem.log`, or the first free `Xschem.log.<n>` up to
`ACTIONLOG_KEEP` (= 10), recycling the oldest when all are taken. So each directory the GUI is
launched from collects its own cap-10 pile.

The original Phase-0 policy comment reasoned that logging only for interactive sessions "keeps
headless/script/test runs from littering the cwd." That assumed *interactive* ⇒ *the user wants a
log next to their work*. It breaks for this project's workflow: the developer (and the headless
GUI smoke/verify runs that set `DISPLAY` and are therefore `has_x` = true) launch the binary
**from inside the source tree** — repo root and `src/` — so "the cwd" is exactly the tree we don't
want littered. The `src/Xschem.log*` timestamps lined up with recent in-tree GUI runs, confirming
the source, not with the user's normal `--logdir /tmp` invocation.

## 3. Fix

The action log is a disposable test/replay artifact, so default it to the temp dir instead of the
cwd (the user's own runs already point `--logdir` at `/tmp`; this just makes the *default* match):

```c
  } else {
    /* No --logdir: the action log is a disposable test/replay artifact, so
     * default it to the temp dir ($TMPDIR, else /tmp) rather than the cwd. This
     * stops interactive runs launched from the source tree (repo root or src/)
     * from littering it with Xschem.log[.N] files (issue 0038). Fall back to the
     * cwd only when no temp dir is usable (e.g. a platform without /tmp). */
    const char *tmp = getenv("TMPDIR");
    if(!tmp || !tmp[0]) tmp = "/tmp";
    if(!stat(tmp, &buf) && S_ISDIR(buf.st_mode)) my_strncpy(dir, tmp, S(dir));
    else my_strncpy(dir, ".", S(dir));
  }
```

`--logdir` still overrides (and is still fatal if its dir can't be created, per spec); `--nolog`
and true-headless (`!has_x`) runs still create no log at all. CIW (which finds the file via
`xschem get actionlog_filename`) follows the new location transparently. Rotation/cap behaviour is
unchanged — it just happens in `/tmp`, which the OS reaps and which is out of the working tree.

## 4. How it was diagnosed / verified

- Located the writer: `grep` for `Xschem.log` → `actionlog_name()` / `init_action_log()` in
  `src/util.c`; confirmed the `else` branch set `dir = "."`.
- Confirmed it is not a git leak: `git check-ignore -v` shows `.gitignore:30/31` cover both the
  root and `src/` copies; `git ls-files` lists none of them.
- After the fix, rebuilt and ran a **bare interactive** session (`DISPLAY=:0`, no `--logdir`, no
  `--nolog`) from a clean throwaway cwd, time-bounded (the log is created at `main.c:100`, before
  any window opens, so a GUI hang doesn't affect the check):
  - **No `Xschem.log` appeared in the cwd** (leak gone).
  - A fresh `/tmp/Xschem.log.3` appeared (next free slot after the user's existing 0/1/2),
    containing exactly the `# xschem action log` header.
- Removed the existing stray piles from the repo root and `src/` (disposable, gitignored).

## 5. Prevention / best practices

- **Don't default tool-generated scratch files to the cwd when the cwd is routinely a source
  tree.** "Interactive ⇒ user wants it here" is a poor proxy when the program is launched from
  inside its own repo (directly or by GUI smoke tests). A temp/state dir is the safer default;
  let `--logdir` opt into a specific place.
- **Verify file-creation side effects from a clean throwaway cwd**, not the repo — a change that
  "stops littering" is only proven by launching from an empty dir and confirming nothing lands
  there *and* that it landed where intended.
- When a memory/comment says "these stray files are expected, leave them," treat that as a smell:
  re-confirm with the user rather than carrying it forward — intent changes.

## 6. Notes

This pairs with the regression-harness / action-registry fixes in `gh_issue_1.md` from the same
review pass. Unlike those, the change here is a behaviour default, not a correctness bug: the old
location was *working as written*, just writing to an inconvenient place.
