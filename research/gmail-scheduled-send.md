# Scheduled send and the Gmail API

**Verified:** 2026-11-15 · **Issues:** none; context for #12 · **Produced by:** the Gmail API
discovery document (`https://gmail.googleapis.com/$discovery/rest?version=v1`, revision
20261102), and read-only gmailr 3.0.0 calls against a mailbox holding one message scheduled in
the Gmail web app.

**The Gmail API cannot schedule a send.** `users.messages.send` and `users.drafts.send` take no
parameter except `userId`, and the discovery document contains no `sendAt`, `schedul`,
`sendTime` or `deliverAt`. Schedule send exists only in the Gmail web and mobile apps. Every
Gmail MCP server and client is built on this API, so none can schedule natively either. This is
why `mc_send(send_at = )` holds the message on the local machine (launchd, `at` or callr) and
sends it at the time.

**A message scheduled in the Gmail app is visible to the API, and cannot be edited through it.**

- `gm_messages(search = "in:scheduled")` finds it.
- It is a message, not a draft: its id is not among `gm_drafts()`.
- Gmail hides its `SCHEDULED` label: `gm_labels()` does not list it,
  `gm_messages(label_ids = "SCHEDULED")` fails with HTTP 400, and the message's `labelIds`
  show only labels such as `IMPORTANT`.
- The API never rewrites a message's content (it can change labels, trash or delete), so its
  subject and body cannot be changed. To edit one: Cancel send in Gmail, which returns it to
  Drafts; replace the draft by its `draft_id` with mc; schedule it again in Gmail.

**Not tested:** whether trashing or deleting a scheduled message through the API cancels the
send.
