# Issue #39 — Split mc_send() into mc_draft() and mc_send()

`mc_send()` selected between drafting and sending with a single boolean, so one
character separated a reversible act from an irreversible one — and the
argument that read as protective, `test`, only rewrote recipients. In August
2026 that combination delivered a message to nine external recipients when a
draft was intended. The fix moves the verb into the function name:
`mc_draft()` can only draft, `mc_send()` can only send, and both frontmatter
wrappers split the same way. `test` becomes `to_self`, which describes what it
does. Shipped as v0.3.0 (breaking, no deprecated alias).

Two things surfaced during exploration that the issue had not anticipated, and
both changed the work: `override` in the frontmatter wrappers is a back door
into the dispatch arguments, so removing the formals was not enough on its own;
and two integration tests relied on the old `draft = TRUE` default, so a
blanket flag rename would have left them sending while asserting the message
appeared `in:drafts`.

Downstream compost migration (~35 scripts) is deliberately not on this branch.

Closed by PR — see `git log --oneline main..39-split-mc-send-into-mc-draft-and-mc-send`.
