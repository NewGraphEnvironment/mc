# Code-check round 3: `43-inline-images` at 7b28e3f

## Checklist read

- **code-check.md** (37 H3): I read the prose of all 14 under `## Mechanisms`, skipping table rows: "A guard that fails toward pass", "A fixture that cannot reach the failure mode", "A proxy is not the property", "Verification that reads its own output", "A guard's scope, escape hatches, and remedies", "A fix lands in one of two callers that share a harness", "Restore the bug and prove the guard fires", "A shared working tree, and what generators leave in it", "Zero-length, empty, and unset are three different things", "One fact derived twice", plus the headings and opening prose of "A wrapper's exit is not the work", "The probe is broken before the world is", "Written data outlives the fix" and "Serialization loses meaning silently". I also read "Percent-encode a URL at construction, not at consumption". I did not read 22.
- **code-check-r.md** (117 H3): I read "Cross-function consistency for label/string normalization", "`ifelse()` with an all-NA test returns a logical vector, whatever `yes` and `no` are", "`strsplit()` drops a trailing empty field, so a trailing separator vanishes", "`nzchar(NA)` is TRUE — non-empty checks silently pass NA", "`vapply(..., USE.NAMES = FALSE)` strips ALL dimnames, row names included" and "Tests that silently do not run". I did not read 111.
- **code-check-shell.md** (70 H3): I read none of them, because the diff has no shell, sed, git or gh code. I did not read 70.
- **code-check-spatial.md** (94 H3): I read none of them, because the diff has no spatial code. I did not read 94.

## Method

I ran probes against `pkgload::load_all()` of the checkout and changed no files. They tested the shared helpers on comments, stray quotes, multibyte text in UTF-8 and in a C locale (as a launchd job runs), a tag split over lines, uppercase tags, valueless attributes, invalid UTF-8, a 914 KB kable, and backtracking inputs (`strrep("<a ", 20000)`, an unterminated quote ahead of 20k tags).

## Findings

- **[severity: fragile]** R/mc_md_render.R:221-223 (`start_tag_regex()`) — **Mechanism: the shared tag reader treats a quote as the start of a value wherever it appears in a tag. Browsers (HTML5 tokenizer) and `tag_attrs()` start a value only after `=`.** A stray `"` or `'` outside a value position therefore makes the regex look for a closing quote further down the document. One of two things happens. If no closing quote turns up before the match fails, that tag is skipped entirely. If one does, the "tag" runs on and swallows the real tags after it. Measured:
  - `<img alt="6" pipe" src="cid:card">` is a tag a browser draws (`src=cid:card`), but `cid_refs()` returns `character(0)`.
  - `<td title="5" pipe">a</td>…` leaves that td unstyled.
  - Before r2, `[^>]*` bounded this damage to one tag. Now it can run across tags.
  - A real producer writes these quotes. Verified with kableExtra 1.x: `cell_spec(x, tooltip = 'it\'s "5" > 4')` writes `title="it's "5" > 4"` unescaped. One `"` in tooltip text (6" pipe) is enough.
  - The markdown path is not exposed: commonmark refuses raw inline HTML with malformed attributes and escapes it. The exposed paths are `mc_compose()` HTML strings and kable parts, `mc_send(html=)`, and a custom `sig_path`.

  Everywhere this reaches:
  - `cid_walk()` (generic name), R/mc_deliver.R:429. The reference is missed, so the check fails toward pass when `inline_images = NULL`, warns "not referenced" when the image is given, and the preview leaves the image broken.
  - `style_tag()`, R/mc_md_render.R:163. The cell is skipped or a later cell swallowed.
  - `inject_link_target()`, R/mc_md_render.R:194. The link gets no target.

  When a run swallows tags, `tag_attrs()` disagrees with the regex. Its unanchored tokenizer skips characters it cannot match, so it reads attributes out of the swallowed span, which happens to recover some references. The two helpers do not agree on where values end. Suggested fix: accept a quoted run only after `=`, and treat any other quote as an ordinary character. Use a possessive loop so the extra alternative cannot backtrack exponentially, for example `<(?:name)(?:\s(?:=\s*(?:"[^"]*"|'[^']*')|[^>])*+)?>`. Then take `/?>` from the end of the match as `style_tag()` already does.
  - **Rule:** code-check-r.md "Cross-function consistency for label/string normalization"

- **[severity: bug]** R/mc_deliver.R:429 (`cid_walk()`, via `start_tag_regex()`) — **Mechanism: the shared scanner has no idea of regions that are not markup.** It reads `<letter…>` inside HTML comments, and inside CDATA and `<script>`/`<style>`/`<textarea>` raw text, as tags. Commonmark's tagfilter escapes those three elements in markdown; `mc_compose()` HTML strings are not filtered. Commenting an image out is the ordinary way to drop it temporarily, and that now blocks the send. Measured through `mc_md_render()` on a draft containing
  ```
  <!-- <img src="cid:logo"> dropped for now -->
  ![card](cid:card)
  ```
  Commonmark passes the comment through verbatim, `cid_refs()` returns `"logo" "card"`, and `check_inline_images(c(card = f), h)` stops with "HTML references cid: logo with no matching inline image". No client draws a commented-out image. The function's own doc says a reference "is what a client draws". It also works the other way: an image still listed in `inline_images` whose only reference is commented out gives no "not referenced" warning, and the image goes out as an unreferenced part.

  Everywhere this reaches:
  - `cid_walk()`: false references in the send check and in the scheduled re-check, and the preview rewrites inside the comment (harmless).
  - `style_tag()` and `inject_link_target()`: they edit tags inside comments, which is invisible and harmless.

  Only the cid path changes behaviour. Fix: before scanning, blank out `<!--…-->` (and CDATA) spans with a non-tag placeholder of the same length, or remove them, in the copy the walker reads.
  - **Rule:** code-check.md "A proxy is not the property"

- **[severity: bug]** R/mc_md_render.R:171-177 (`style_tag()`), with `tag_attrs()` R/mc_md_render.R:251-257 — **Mechanism: `tag_attrs()` gives "attribute present with no value" (`style`, or `style=` before `>`) the value `""` and `vstart = NA`. `style_tag()` treats `""` as a present value it can edit and splices at the NA position.** Measured: `inline_table_styles('<td style>x</td>')` returns `NA"border: 1px solid #ddd; padding: 8px;"NAx</td>`. `paste0(substr(t, 1, NA), …)` writes the literal `NA` and the `<td` is lost, so the table structure breaks. The same happens for `<th style>`, `<table style>` and `style=>`. Likelihood is low, since neither commonmark nor kable writes a valueless style, but a hand-written HTML part can, and the output is corrupt rather than unstyled. Of the three `tag_attrs()` consumers, only `style_tag()` splices at `vstart` without checking it. `cid_walk()` reaches the splice only after a value has changed, and a valueless attribute cannot change. Fix: branch on `is.na(a$vstart[i])` and handle it like the no-style case (replace the bare attribute, or append ` style="…"`).
  - **Rule:** code-check.md "Zero-length, empty, and unset are three different things"

- **[severity: fragile]** R/mc_deliver.R:90 / R/mc_deliver.R:429 — **`check_inline_images()` now runs `gregexpr(perl = TRUE)` over the whole body on every send and draft, including `html=` passthrough and the signature.** On invalid UTF-8 (for example a latin1-encoded custom `sig_path`, which `mc_sig()` reads with `readLines()` and no encoding), `gregexpr` warns "input string 1 is invalid UTF-8" and returns no match. Measured: every send then carries that warning, and `cid_refs()` returns `character(0)`, so an unmatched `cid:` passes the check (fails toward pass). Before this branch the signature never went through a regex, because `inline_table_styles()` ran before it was appended. Low likelihood, but each send gets a new warning that does not name its cause.
  - **Rule:** code-check.md "A guard that fails toward pass"

## Checked and sound (no finding)

- **Backtracking:** none. The alternatives in `start_tag_regex()` are disjoint by first character, and PCRE makes `[^"]*"` possessive automatically. The pathological inputs ran in ≤ 0.013 s.
- **`cid_walk()` rewriting right to left:** positions stayed valid when the value changed length, with multibyte text before, inside and after the values. Checked in UTF-8 and under `LC_ALL=C` with HTML round-tripped through `write_scheduled_args()`/`read_scheduled_args()`. In check mode the HTML comes back `identical()` in both locales.
- **Tags split over lines, uppercase tags and attributes, `<` or `>` inside quoted values, `<thead>` versus `th`:** all correct.
- **The enumeration in findings.md:** complete. Grepping `R/` for `regmatches|gregexpr|regexpr|sub\(|gsub` turns up no other parser of HTML structure besides the out-of-scope `mc_thread_find.R` strippers. `mc_scroll()` and `preview_header()` only build HTML.
- **Speed:** a 5000-row kable (914 KB) takes about 5.8 s in `inline_table_styles()` and 7.1 s in `cid_refs()`, from one `data.frame` per tag. That is slow on very large tables but nothing breaks.
