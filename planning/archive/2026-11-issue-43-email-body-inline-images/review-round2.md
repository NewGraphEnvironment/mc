# Code review, round 2: branch `43-inline-images` (whole branch, focus on 9d8bae0)

## Checklist read

- **code-check.md** (37 H3s): read the prose (table rows skipped) of all 14 H3s under `## Mechanisms`: A guard that fails toward pass; A fixture that cannot reach the failure mode; A proxy is not the property; Verification that reads its own output; A guard's scope, escape hatches, and remedies; A fix lands in one of two callers that share a harness; Restore the bug and prove the guard fires; A shared working tree, and what generators leave in it; A wrapper's exit is not the work; Zero-length, empty, and unset are three different things; The probe is broken before the world is; Written data outlives the fix; Serialization loses meaning silently; One fact derived twice. Also read: Percent-encode a URL at construction, not at consumption; An assertion that matches an interpolated value cannot see the claim around it. Not read: 21.
- **code-check-r.md** (117 H3s): read `sub()` takes one replacement, not one per element; `ifelse()` with an all-NA test returns a logical vector; `vapply(..., USE.NAMES = FALSE)` strips ALL dimnames; `strsplit()` drops a trailing empty field; `data.frame()` recycles a scalar against a zero-length column; `paste()` with a zero-length argument returns length ONE; Under `R CMD check`, tests run from a temp dir against the INSTALLED package; A `function(...)` mock hides arguments the real callee no longer accepts; `\<` and `\>` are word boundaries in R's default regex; `nzchar(NA)` is TRUE. Index lines checked for `$` partial matching, testthat expectations (`expect_message`, `expect_match` on empty input) and `tryCatch`. Not read in full: 107.
- **code-check-shell.md** (70 H3s): read "A variable in a sed replacement is parsed, so its `\` and `&` are not literal" (the same trap as a `gsub()` replacement). Not read: 69. The branch has no shell code.
- **code-check-spatial.md** (94 H3s): none apply (no spatial code). Not read: 94.

## Findings

- **[bug]** R/mc_md_render.R:163 (`style_tag`), R/mc_md_render.R:194 (`inject_link_target`), R/mc_deliver.R:405 (`cid_refs`): the round-1 fix tokenizes attributes with `tag_attrs()`, but each caller still finds the tag with `[^>]*`. So a `>` inside a quoted attribute value ends the "tag" early, and `tag_attrs()` gets a truncated tag. This is the round-1 mechanism again, one axis over: the attribute reader is now right, but the tag boundary is still a regex over the whole body. kableExtra really produces this: `cell_spec("site", link = "https://a.com", tooltip = "flow > 5 m3/s")` emits `<a href="https://a.com" ... title="flow > 5 m3/s">site</a>` with the `>` unescaped. Measured outputs:
  - `inject_link_target()` / `mc_compose()` on that link: `... title="flow target="_blank" rel="noopener noreferrer"> 5 m3/s">site</a>`. The link does not open in a new tab, and ` 5 m3/s">` shows as visible text in the sent email.
  - `inline_table_styles('<td title="1 > 0" align="left">x</td>')` gives `<td title="1 style="border: 1px solid #ddd; padding: 8px;"> 0" align="left">x</td>`: the cell markup is corrupt and ` 0" align="left">` renders. `main` left this tag alone, because its patterns needed `style="` or a bare `<td>`, so this is a regression.
  - `cid_refs('<img alt="flow > 5" src="cid:missing">')` finds nothing. `check_inline_images(NULL, ...)` then passes, and the email goes out with a broken image, where the guard exists to raise an error. With `c(logo = f)` and `src="cid:logo"`, it warns "not referenced" about an image that is referenced.

  commonmark escapes `>` in attributes as `&gt;`, so only raw HTML, kable and kableExtra parts reach this. Fix: find tag boundaries with a pattern that consumes quoted values, e.g. `<[A-Za-z][^\s/>]*(?:\s+[^\s"'>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'>]+))?)*\s*/?>` (case-insensitive), or have the tokenizer return where the tag ends. Use it in all three places.
  - **Rule:** code-check.md "A proxy is not the property"

- **[bug]** R/mc_preview.R:85 (`file_url`): `utils::URLencode(seg, reserved = TRUE)` keeps the default `repeated = FALSE`. When a segment already contains `%` followed by two hex digits, it returns that segment unchanged and encodes nothing in it. Then the space, `#`, `"` and `\` that `file_url()`'s doc promises to neutralise all pass through raw. Measured:
  - `file.path(tempdir(), 'fig "v2" 10%ab \\1.png')` previews as `<img src="file:///.../fig "v2" 10%ab .png" alt="x">`. The `"` ends the attribute, and the `gsub()` replacement swallows `\1` as a backreference.
  - `café 50%ab.png` gives `file:///.../café 50%ab.png`, which `URLdecode()`s to a different path, so the browser's request for `%ab` (byte 0xAB) is for the wrong file and the preview image breaks.

  The new test's fixture (`fig 100%.png`, `My Drive #1`) has no `%` followed by two hex digits, so it cannot reach this. Fix: `repeated = TRUE`. `URLencode("a b 10%ab", reserved = TRUE, repeated = TRUE)` returns `a%20b%2010%25ab`. Add a `%ab` segment to the test fixture.
  - **Rule:** code-check.md "A proxy is not the property" (URLencode takes "contains %XX" to mean "already encoded")

- **[fragile]** R/mc_preview.R:71 (`preview_inline_images`): the round-1 fix taught the send-side scan (`cid_refs`) to read `cid:` only from `src`/`background`/`style url()` attributes. The preview still `gsub()`s `cid:<id>` across the whole body. So `<code>src=cid:card</code>` in prose and `data-src="cid:card"` both preview as file URLs. The message actually sent keeps them as `cid:card`, so the preview shows a body different from the one sent. Measured: `preview_inline_images('<p>Use <code>src=cid:card</code></p><img data-src="cid:card">', list(card = f))` rewrites both. This affects the preview only, so it is not a delivery bug. Fix: rewrite only the attribute values `cid_refs()` reads, through the same tag and tokenizer path.
  - **Rule:** code-check.md "A fix lands in one of two callers that share a harness"

## Checked and clean

- `tag_attrs()` positions with multibyte text (é, CJK, emoji): `vstart`/`vlen` and `substr()` agree in a UTF-8 locale, and the rewrite is correct. A launchd job's R has a UTF-8 locale too: `env -i` Rscript reports `en_CA` with UTF-8.
- Uppercase tags and attribute names, newlines inside a tag, boolean attributes (`nowrap`, `data-x`), `=` with spaces, self-closing `/>` (unquoted `src=cid:a/>` still yields `a`), single-quoted style values, and commonmark's escaped `&gt;`/`&quot;` all behave correctly.
- An attribute glued to the previous one with no whitespace (`align="left"style="x"`) is missed and gains a second `style`. Browsers keep the first `style`, so our CSS is dropped. Neither commonmark nor kable emits this, so it is not reported.
- Round trip of `write_scheduled_args()`/`read_scheduled_args()` for named `inline_images` (one or several entries, and `null` when there are none): names survive. `$` partial matching is not reachable.
- The integration assertions are no longer vacuous: a missing `<table>` errors on `[[1]]` rather than passing.
