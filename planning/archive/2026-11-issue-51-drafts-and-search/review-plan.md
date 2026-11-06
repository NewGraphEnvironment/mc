# Plan review: #51 batch (Plan agent, delivered 2026-11-05 ~23:45Z)

Spawned 23:34Z against the baseline (90b7419) while Phases 1–2 were landing. Findings returned as reply text and written here by the parent session. Each finding was probed before it was acted on (`scratchpad/probe.R`, results below).

## Verdicts

| ID | Finding | Probe | Verdict / action |
|----|---------|-------|------------------|
| B1 | `draft_id` reaching `mc_send()` through `mc_md_send()` → unused-argument error; tests stub `mc_send` as `function(...)` | `mc_md_send(p, override = list(draft_id = "r1"))` with the real `mc_send` → `unused argument (draft_id = "r1")` | Real, narrower than stated: the frontmatter line does not reach `mc_send` (read in `mc_md_draft()`, not `md_dispatch_args()`); an `override` does. Fix: `mc_md_send()` errors on `override$draft_id` with a pointer to `mc_md_draft()`, tested against the real `mc_send` signature |
| A1 | JSON (non-upload) endpoint may cap below 35 MB | needs live Gmail | Integration test with an attachment over 5 MB on create and update; fallback is the multipart upload URI if it fails |
| A2 | `drafts.update` without `threadId` may move a threaded draft out of its thread | live | Integration: update a threaded draft, check threadId kept |
| A3 | Hand-added labels lost on replace | live | Integration probe; document |
| A4 | Malformed id gives 400, not 404 | live | Integration probe; document that only "not found" falls back |
| A5 | Header lookup error could stop sends that work today | reasoning | Adopt: unreadable thread errors; a thread with no usable `Message-ID` warns and sends with `threadId` only |
| A6 | `References` never folded, 998-char limit | 30 refs → longest header line 1811 chars | Real. Keep the first id plus the last 10 |
| G1 | Existing tests that break | grep | Known; handled phase by phase |
| G2 | Write-back must skip NULL/empty id and compare against the file | — | Already so in Phase 2 (`is.character`, compared to `file_id`); add `nzchar` |
| G3 | `draft_id: ""` accepted → PUT to `drafts/` | `chk_null_or("", vld_string)` → accepted | Real. `mc_draft()` rejects `""`; `mc_md_draft()` treats `""` as absent |
| G4 | `frontmatter_set()` robustness | flow-style block + appended line → YAML parse error | (c)/(e) real: verify by re-parsing the temp file before the move, else refuse. (a): block regex differs from `parse_frontmatter()`'s only in what whitespace it tolerates; cross-checked by a test rather than refactoring the reader. (b)(d)(f) already handled |
| G5 | Gmail may ignore `threadId` | live | Adopt: warn when the returned threadId differs from the one asked for |
| G6 | 404 fallback must keep the thread | — | Adopt in Phase 3 |
| G7 | Replacing overwrites hand edits; a `to_self` run after a real draft overwrites the reviewed draft | reasoning | Real, and it contradicts the gate text's to_self note. Correction: `mc_md_draft(to_self = TRUE)` neither uses nor records the file's `draft_id` (a test copy is never the tracked draft). Explicit `mc_draft(draft_id =, to_self = TRUE)` still honoured. Docs say replace overwrites Gmail edits |
| G8 | Explain `message_id` | — | Adopt in docs |
| G9 | `References` fallback to `In-Reply-To`; skip TRASH/SPAM | — | Adopt |
| G10 | Bad thread on a scheduled send shows only at fire time | — | Not adopted: same as today (`gm_send_message` fails at fire time too); out of scope |
| G11 | NEWS must list behaviour changes | — | Adopt in Phase 5 |
| O1 | Phase 2 text says thread routing; code routes draft_id only | — | Code is right; Phase 3 adds thread routing |
| O2 | Headers and `Re:` between `to_self` and `gm_subject()` | — | Adopt |
| S1/S2 | the internal communications convention and `email-draft` skill say drafts cannot thread, and the skill commits before `mc_md_draft()` writes the id | — | Filed in the internal conventions repo |
| S3 | `mc_md_send()` leaves the file's draft in Gmail | — | Adopt: a message naming the draft still there (mc never deletes) |
| S4 | `extract_header()` ignoring case; preview/index extras | — | Header case adopted; extras not adopted |
