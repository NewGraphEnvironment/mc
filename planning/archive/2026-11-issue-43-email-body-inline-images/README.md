## Outcome

This was move 2 of 3 from #43, one PR for four changes to the HTML body mc builds:

- **Inline images (#43):** the `inline_images` argument, which the branch already had, now with `main` merged in.
- **Links in a new tab (#35).**
- **Table styles written once (#42).** Aligned cells also get their border now, where before they got none.
- **Integration tests from a `.md` file with the signature (#10).**

Merging main showed that a scheduled send would drop the images' Content-ID names in the args JSON. Main's own round-trip guard from #47 caught it. `write_scheduled_args()` now writes the field as a JSON object, and a new `read_scheduled_args()` reads it back.

The larger lesson came from review. The first versions found tags, attributes and `cid:` references with a separate regex at each call site, and each review round found the next place where those regexes and an HTML reader disagreed:

- **Round 1:** a code span counted as a reference, and the style pass quoted text inside other attributes' values.
- **Round 2:** a `>` inside a quoted value ended the tag.
- **Round 3:** a stray quote broke the match, and tags inside comments were read.
- **Round 4:** each pass walked only its own tag name, so markup inside another tag's value counted as a tag.

The design that ended it is one walk over every start tag (`rewrite_start_tags()`) built on one attribute grammar (`html_attr_regex()`), which the tag regex and the tokenizer (`tag_attrs()`) share. All three passes (styles, links, the `cid:` reader `cid_walk()`) go through it, and the loop ended on an enumeration showing nothing that reads HTML structure sits outside these helpers (`findings.md`, round 4). Gmail renders inline parts inside gmailr's `multipart/mixed` with no attachment card, so no gmailr change was needed: see [research/gmail-inline-images.md](../../../research/gmail-inline-images.md).

## Measurement

- **Unit suite:** 600 pass, 0 fail. Before the merge, the original branch had 411 pass with auth disabled.
- **Integration (`MC_RUN_INTEGRATION=true`, real Gmail):** 38 pass, 0 fail, both before and after the review fixes.
- **Live launchd scheduled send** with a relative image path: SCHEDULED 07:09:52Z, fired 07:11:52Z, SENT 07:11:54Z. The args JSON carried `{"card": "<absolute path>"}`, and Gmail stored `Content-Id: <card>` with an inline disposition.
- **Attachment-card check:** the owner looked at three to-self messages and one message to a second inbox, in Gmail web and on a phone, and saw no card on any of them. A probe with no `filename` on the part looked the same.
- **Review:** one plan review and four `/code-check` rounds, which found 4, 3, 4 and 3 fragile-or-bug issues. Rounds 2 to 4 each found their main defect inside the previous round's fix. The loop ended on an enumeration, not on a quiet round.
- **Speed on hostile inputs:** under 0.02 s each. 120 KB of table cells takes about 1.9 s, because each tag builds a data frame; accepted.
- **Lint:** no lints added compared with `main` (51 rows on both sides, all in files the branch does not touch).

Wrong turn, kept: the first chip answer read "chip in Gmail web only". A follow-up question that defined "chip" found that no card had appeared on any message.

Closed by: PR #44
