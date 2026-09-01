# `doc/claude/3rd_party/`

Bug reports and findings about software **we do not own**, written up here before
(or instead of) being filed upstream.

A defect that turns out to live in someone else's code still costs us the
investigation, and the investigation is worth keeping: the next person to see the
same symptom should find the answer here rather than re-run the bisect. These
files are also drafted to be *pasteable* upstream — environment block, minimal
repro, evidence, workaround — so filing is a copy, not a rewrite.

Conventions:

* One file per upstream defect, named `<project>-<short-symptom>.md`.
* State plainly what is **proven** and what is **hypothesis**. An upstream
  maintainer's time is spent on the gap between the two.
* Record the workaround at the top, because that is what a reader with the same
  symptom actually needs first.
* Link to the internal issue in `doc/claude/issues/` that paid for the work.
* **Nothing here is filed automatically.** Filing is an outward-facing action and
  needs the maintainer's — the human's — explicit go-ahead, including a check
  that no personal data rides along in an attached log or dump.

| file | upstream project | status |
|---|---|---|
| `vcxsrv-compositewm-gdi-exhaustion.md` | [VcXsrv](https://github.com/marchaesen/vcxsrv) | drafted, **not filed** |
