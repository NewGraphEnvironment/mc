# mc <img src="man/figures/logo.png" align="right" height="139" alt="mc hex sticker" />

> Mail Composer. Three lines to draft an email.

Compose, draft, and send emails from markdown files via the Gmail API. Wraps
[gmailr](https://gmailr.r-lib.org/) to eliminate the 80 lines of boilerplate
that every email script repeats.

## Installation

```r
pak::pak("NewGraphEnvironment/mc")
```

## Setup

Set your default sender address in `~/.Rprofile`:

```r
options(mc.from = "you@example.com")
```

Or via environment variable in `~/.Renviron`:

```
MC_FROM=you@example.com
```

Then authenticate once per machine:

```r
mc_auth()
```

## Usage

Write your email body in markdown. Everything above the `---` separator is
a human-readable envelope (notes for the author) and is stripped by
`mc_md_render()` before conversion. Recipients, subject, and other
envelope fields are set as R parameters in `mc_send()`.

```markdown
# Email to Brandon - Cottonwood

**Subject:** Cottonwood plugs - 2026 planting
**To:** brandon@example.com

---

Hi Brandon,

Quick question about the cottonwood plugs.

Thanks,
Al
```

Draft it in three lines:

```r
library(mc)
mc_draft("communications/draft.md",
         to = "brandon@example.com",
         subject = "Cottonwood plugs - 2026 planting")
```

That creates a Gmail draft with HTML formatting and the standard signature
appended. Authentication happens automatically via cached OAuth tokens
(run `mc_auth()` once per machine to set up).

When you're ready to send for real, name the act:

```r
mc_send("communications/draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs")
```

`mc_draft()` can only draft and `mc_send()` can only send — there is no flag
that flips one into the other. The same split applies to the frontmatter-driven
pair, `mc_md_draft()` and `mc_md_send()`.

## Tables in emails

Need an R-generated table in your email? Use `mc_compose()` to mix markdown
files, HTML, and kable/kableExtra objects:

```r
df <- data.frame(Site = c("Nechako", "Mackenzie"), Plugs = c(4000, 3000))

body <- mc_compose(
  "communications/intro.md",
  knitr::kable(df, format = "html"),
  "<p>Let me know if this looks right.</p>"
)

mc_send(html = body, to = "brandon@example.com", subject = "Planting plan")
```

Large tables? Wrap in `mc_scroll()` for horizontal/vertical scrolling:

```r
mc_compose(
  "<p>Full dataset:</p>",
  mc_scroll(knitr::kable(big_df, format = "html"), direction = "both")
)
```

See `vignette("tables-in-emails")` for kableExtra styling and scrolling examples.

## Reference

Full function documentation with examples: [newgraphenvironment.github.io/mc](https://newgraphenvironment.github.io/mc/)

## Threading

Reply into an existing conversation:

```r
# Find the thread
mc_thread_find("from:brandon subject:cottonwood")

# Read the conversation to review context
mc_thread_read("19c05f0a98188c91")

# Include drafts in the thread (adds a status column: "sent" / "draft")
mc_thread_read("19c05f0a98188c91", drafts = TRUE)

# Send into it
mc_send("draft.md",
        to = "brandon@example.com",
        subject = "Re: Cottonwood plugs",
        thread_id = "19c05f0a98188c91")
```

**Note:** `gm_create_draft()` does not support `thread_id`. Drafts are always
standalone, and `mc_draft()` warns if you pass one. Use `mc_send()` to deliver
straight into a thread, or send the draft manually from the Gmail UI (Gmail
will match by subject line if it starts with "Re:").

## Scheduled send

Send an email later with `send_at` — either minutes from now or a specific
time. Use `scheduler = "auto"` for durable OS-native scheduling (recommended):

```r
# Send in 10 minutes via launchd (macOS) or atd (Linux)
mc_send("draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs",
        send_at = 10,
        scheduler = "auto")

# Send at a specific time
mc_send("draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs",
        send_at = as.POSIXct("2026-02-24 09:11:00"),
        scheduler = "auto")
```

The `scheduler` argument selects the backend:

- `"callr"` (default for backward compatibility) — `callr::r_bg` background R
  process. Survives some session lifecycles but **can be cleaned up if its
  parent context exits** (one-shot `Rscript -e`, RStudio sessions that close,
  CI). Emits a `warning()` on use steering you toward `"auto"`.
- `"auto"` — resolves to `launchd` on macOS or `at` on Linux. The OS-native
  daemon owns the job lifecycle independent of any R session — survives
  shell exit, parent process death, and (on macOS) sleep/wake cycles.
- `"launchd"` / `"at"` — force a specific backend.

Heartbeat log entries land in `~/.mc/send_log.txt` so missed fires are
auditable from the log alone:

- `SCHEDULED` at submission with the target time
- `STARTED` at fire, just before the actual send
- `SENT` / `SKIPPED` / `FAILED` at outcome

A `SCHEDULED` line with no follow-up `STARTED` means the bg process died
before firing — the failure mode that the OS-native backends solve.

On macOS, `caffeinate` keeps the machine awake until the email sends (callr
backend only — launchd handles wake/sleep itself). If the machine sleeps
through the send window with the callr backend, a 5-minute grace period
applies — past that, the send is skipped to prevent stale emails.

Outcomes also trigger a macOS desktop notification on success, skip, or failure.

## Labels

Apply Gmail labels to threads via `mc_send(labels = ...)` or in YAML
frontmatter as `labels:`. Missing user labels are auto-created on first use
(via `mc_label_ensure()`):

```r
mc_send("draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs",
        labels = c("project-x", "urgent"))
```

```yaml
---
to: brandon@example.com
subject: Cottonwood plugs
labels:
  - project-x
  - urgent
---
```

Pass `labels_create = FALSE` for strict typo-guard (errors on unknown labels).
After-the-fact labelling on existing threads via `mc_thread_modify(thread_id, add = ...)` —
also accepts Gmail system labels like `INBOX`, `STARRED`, `TRASH` for
archive / star / trash workflows.

## Sending to yourself

`to_self = TRUE` redirects to your own address, strips CC/BCC, and ignores
`thread_id`:

```r
mc_send("draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs",
        to_self = TRUE)
```

It caps who receives the message — it does not stop the send. If you want
nothing delivered at all, use `mc_draft()`.

## License

MIT
