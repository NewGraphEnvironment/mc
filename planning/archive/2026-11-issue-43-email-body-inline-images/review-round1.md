# Review round 1: branch 43-inline-images (diff 74026018...HEAD, excl. man/ planning/)

## Checklist read

- **code-check.md** (17 read, 20 not read): all 14 H3s under `## Mechanisms` (prose, table rows skipped); "Percent-encode a URL at construction, not at consumption"; "Bare `y`, `n`, `on`, `off`, `yes`, `no` are booleans in YAML 1.1"; "An assertion that matches an interpolated value cannot see the claim around it".
- **code-check-r.md** (11 read, 106 not read): "`vapply(..., USE.NAMES = FALSE)` strips ALL dimnames, row names included"; "`$` on a list partial-matches, so a longer sibling key answers for a missing one"; "`[[` on a named ATOMIC vector with an absent key is an error, not `NULL`"; "`unlist()` prefixes a `split()` group's name, so reassembling by name silently yields all-NA"; "`c(name = x)` keeps `x`'s own name, so a value from a named vector becomes `name.X`"; "R's `yaml` returns a mixed int/float sequence as a list, not a numeric vector"; "`tempfile()` lives in the session tempdir, so a path printed in an error names a file R is about to delete"; "`sub()` takes one replacement, not one per element"; "`\<` and `\>` are word boundaries in R's default regex, not escaped `<` and `>`"; "A `function(...)` mock hides arguments the real callee no longer accepts"; "`file(open = "wb", encoding = )` does not re-encode on write" (the `(*UCP)` / locale bullets only).
- **code-check-shell.md** (1 read, 69 not read): "A variable in a sed replacement is parsed, so its `\` and `&` are not literal".
- **code-check-spatial.md** (0 read, 94 not read): nothing spatial in the diff.

## Verification done

- Unit suite, run in a detached worktree of HEAD: 230 results, failed 0, error 0.
- I checked gmailr 3.0.0's `gm_attach_part()` / `as.character.mime()`. The inline part goes in at index >= 3, `id` becomes `Content-Id: <id>`, and `disposition`/`filename`/`name` go to `Content-Disposition`/`Content-Type` as intended. `gm_attach_file()` hard-codes `disposition = "attachment"`, so calling `gm_attach_part()` directly is correct.
- JSON round trip: a JSON `null` reads back as `NULL` (not a list), so `read_scheduled_args()` leaves an absent or NULL `inline_images` alone. The object form reads back as a named list and is `unlist()`ed to a named character vector, as the tests assert.
- Styling and links with non-ASCII HTML give correct output under both a UTF-8 and a C `LC_CTYPE`.
- The probes behind each finding below are in the scratchpad (`probe1.R`, `probe2.R`). Each finding's output was measured.

## Findings

- **[severity: fragile]** R/mc_preview.R:71-72 — `preview_inline_images()` pastes the raw `normalizePath()` result into a `file://` URL and passes it as the **replacement** of a `perl = TRUE` `gsub()`. That breaks in two ways:
  - **Windows:** `normalizePath()` returns backslashes there, which the replacement reads as escapes (`\U`, `\L`, `\E`, `\1`). Measured: the path `C:\Users\al\fig.png` came out as `src="file://C:sersalfig.png"`. Even without the mangling, `file://C:\...` is not a valid file URL.
  - **Any platform:** the path is not percent-encoded. A `#`, `?` or `%` in a directory or file name changes the URL: `/Users/al/My Drive/fig#1.png` becomes a fragment. A `"` ends the `src` attribute.

  This affects only the browser preview; sending is fine. But the preview is the one place a user checks the inline images, and the default scheduler code treats non-mac/Linux hosts as supported. Fix: build the URL with forward slashes and percent-encoding, and substitute it literally, for example by splitting on the match or using `regmatches<-`, rather than through a regex replacement string.
  - **Rule:** code-check.md "Percent-encode a URL at construction, not at consumption"

- **[severity: fragile]** R/mc_deliver.R:370-375 — the `cid:` reference scan accepts an unquoted `src=`, so text inside a code span counts as a reference. Measured: the markdown `` `src=cid:q` `` renders to `<p><code>src=cid:q</code></p>`, and `check_inline_images(NULL, html)` stops with "HTML references cid: q but no inline_images were given." There is no override, so an email that shows this syntax as inline code (an email about using mc, for example) cannot be sent or drafted. Fenced code blocks and quoted forms are safe, because commonmark escapes the quote to `&quot;`. The cost is low-probability but it is a hard refusal. A possible fix is to scan with `<code>...</code>` spans removed first.
  - **Rule:** none

- **[severity: fragile]** R/mc_md_render.R:167 — `style_tag()` quotes an unquoted `style=` value by running its regex over the whole tag, quoted attribute values included. Measured: `<td title="a style=b">` becomes `<td title="a style="border: 1px solid #ddd; padding: 8px; b"">`, which is malformed HTML, and the cell loses its styling. The sibling `inject_link_target()` in the same file blanks quoted values before it looks for attribute names, for exactly this reason. `style_tag()` does not. This needs ` style=` inside a quoted value of a table, th or td tag (for example a kableExtra tooltip `title`), so it is rare.
  - **Rule:** none

- **[severity: fragile]** tests/testthat/test-integration.R:438 — `expect_length(gregexpr("border-collapse", table_tag, fixed = TRUE)[[1]], 1)` passes when the declaration is **absent**: `gregexpr()` returns `-1`, which has length 1. The assertion meant to show "the table declaration is written once" cannot tell once from zero, and no other line in this test checks that `border-collapse` reached the table. Count matches, for example `sum(gregexpr(...)[[1]] > 0) == 1` or the `count_fixed()` helper used in test-mc_md_render.R.
  - **Rule:** code-check.md "A guard that fails toward pass"

No bug- or security-severity issues found. The scheduled-send path is correct: relative paths are normalised after the existence check, names survive the JSON round trip, and the callr path keeps the named vector. So are the `to_self` handling, the duplicate/empty/NA-name checks (NA names fail the token regex) and the draft path.
