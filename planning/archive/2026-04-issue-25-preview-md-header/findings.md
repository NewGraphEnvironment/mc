# Findings

## Current mc_preview signature

```
mc_preview(html, path = file.path(tools::R_user_dir("mc", "cache"), "preview.html"), open = TRUE)
```

The first arg is `html`. Issue #25 wants to also accept a `.md` path. Renaming `html` → `x` would be a breaking change; safer is to keep arg name but document that it accepts either.

Conflict: the current signature also has `path` as the *output* file location. If we accept an input `.md` path via the first arg, we have two "paths" semantically. Keep first arg named `html` (treated as "input: html string or .md path") and keep second arg `path` as output location — document clearly.

## Detection heuristic

- `endsWith(x, ".md") && file.exists(x)` → treat as .md path
- Otherwise treat as HTML string

Guard against false positives: an HTML string that happens to be exactly a filename ending in `.md`. Low probability in practice.

## Header rendering

Use a plain HTML table with inline styles (consistent with existing `inline_table_styles()` usage, Gmail-safe anyway). Fields: To, Cc, Bcc (if present), Subject, Thread, Attach. Em-dash `—` for empty.

## Dependencies

`mc_md_meta()` and `mc_md_render()` are already exports in this package.
