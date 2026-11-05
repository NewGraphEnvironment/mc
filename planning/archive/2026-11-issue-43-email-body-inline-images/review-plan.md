# Plan review — #43 batch (Plan agent, 2026-11-05)

Ran in the background after the baseline; Phases 1-4 had landed by the time it reported, so it
reviewed the code as well. Recorded by the parent session (Plan agents cannot write files).

## Context claims re-probed
- Confirmed: JSON drops vector names; list form reads back as named list; paths not absolute at
  baseline; #42 cause; aligned cells unstyled; titled links; `mc_compose.R:69`; public repo and the
  session link in PR #44's body.
- Partly wrong: old `cid:` regex needed a token char right after the colon, so `acid: strong` never
  fired; only `Placid:calm`-style text did. The landed test uses `Placid:calm`, so it was red first.

## Blocker
None.

## Gaps
1. `cid:` scan misses `background="cid:x"`, `url(cid:x)`, unquoted `src=cid:x`; counts `data-src`.
2. `inject_link_target()`: fragment links `href="#sec"` get `target="_blank"`; `has()` greps the whole
   tag so `title="no target=here"` suppresses the target; plan text says a targeted link is "left
   alone" while code still adds `rel`.
3. `style_tag()`: unquoted `style=margin:0` not seen, second style appended. Low priority.
4. `mc_preview()` (`R/mc_preview.R:46-50`) shows `cid:` images broken; envelope lists Attach, not
   inline images.
5. Docs: `R/mc_md_send.R:3-4` frontmatter keys omit `inline_images`; `@param inline_images` omits the
   markdown `![alt](cid:name)` form and the YAML mapping shape; CLAUDE.md:33 "the one JSON writer"
   now has a paired reader; NEWS entry not in Phase 7.
6. Scheduled images (and attachments) are read at fire time, so a `tempfile()` image is gone once
   its session ends. Undocumented for both.
7. Phase 5 mechanics: use `extract_body()`, header case-insensitive, markdown image syntax.

## Ordering
- Findings now need follow-up commits, not plan edits.
- Phase 6 can change what Phase 5 asserts; re-run Phase 5 after any Phase 6 change.

## Acceptance
- Phase 1 callr test mocks `schedule_send`, so `r_bg` itself is not exercised (RDS keeps names;
  low risk, but the box overclaims).
- Guard has no Content-ID with `.` or `@`; its name-extraction regex stops at the first `)`, so
  normalising before `list()` is load-bearing: add a comment.
- No live scheduled send with an inline image (#47's defect class was fire-time context).
- Phase 5 reads back the MIME mc sent: proves the md + sig + MIME pipeline, not rendering. Gmail
  web opens every link in a new tab anyway, so #35 matters for other clients.
- Phase 6 needs a pass/fail rule for "chip" set before looking.

## Scope
- Phase 3 extras (single quotes, case, idempotency): cheap and tested, no action.
- `mailto:` getting `target="_blank"` is a choice in neither #35 nor the gate: record it.
- Before gate decision 3: dropping `name =`/`filename =` on the inline part may remove a chip in some
  clients; one argument, but needs the owner's word given "no workaround in mc".
