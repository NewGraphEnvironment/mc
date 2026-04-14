# Findings

## Existing header handling (mc_md_render.R)

`strip_md_header()` strips everything up to & including first `---\n` (non-greedy). This would mangle YAML frontmatter which has a closing `---` too. Need to detect YAML frontmatter (file starts with `---\n`) and strip through the matching closing `---\n` instead of the first one.

## Current draft template pattern

```
# Email to X - Topic
**Subject:** ...
**To:** ...
---
body
```

YAML frontmatter pattern will be:
```
---
to: ...
subject: ...
---
body
```

Strip logic: if raw starts with `^---\s*\n`, find the next `^---\s*\n` and strip through it. Otherwise fall back to existing behavior.

## Filename date convention

`YYYYMMDD_recipient_topic_draft.md`. Parse first 8 digits at basename start as date (NA if no match).

## mc_send arg mapping

Frontmatter keys → `mc_send` args (1:1): `to`, `cc`, `bcc`, `subject`, `thread_id`, `attachments`, `from`, `sig`, `sig_path`. `mc_md_send` override lets callers bump `draft`, `test`, etc. at call time.
