# mc <img src="man/figures/logo.png" align="right" height="139" alt="mc hex sticker" />

> Mail Composer. Three lines to draft an email.

Compose, draft, and send emails from markdown files via the Gmail API. Wraps
[gmailr](https://gmailr.r-lib.org/) to eliminate the 80 lines of boilerplate
that every email script repeats.

## Installation

```r
pak::pak("NewGraphEnvironment/mc")
```

## Usage

Write your email in markdown:

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

Send it in three lines:

```r
library(mc)
mc_auth()
mc_send("communications/draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs - 2026 planting")
```

That creates a Gmail draft with HTML formatting and the standard signature
appended. When you're ready to send for real:

```r
mc_send("communications/draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs",
        draft = FALSE)
```

## Functions

| Function | What it does |
|----------|-------------|
| `mc_send()` | Draft or send an email from a markdown file |
| `mc_auth()` | Authenticate with Gmail |
| `mc_md_render()` | Convert markdown to HTML (strip header, inline table styles, append sig) |
| `mc_sig()` | Return the standard NGE signature as HTML |
| `mc_thread_find()` | Search Gmail for thread IDs |

## Threading

Reply into an existing conversation:

```r
# Find the thread
mc_thread_find("from:brandon subject:cottonwood")

# Send into it
mc_send("draft.md",
        to = "brandon@example.com",
        subject = "Re: Cottonwood plugs",
        thread_id = "19c05f0a98188c91",
        draft = FALSE)
```

**Note:** `gm_create_draft()` does not support `thread_id`. Drafts are always
standalone. Use `draft = FALSE` to send directly into a thread, or send the
draft manually from the Gmail UI (Gmail will match by subject line if it
starts with "Re:").

## Test mode

Send to yourself to preview:

```r
mc_send("draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs",
        test = TRUE)
```

Test mode redirects to your own address, strips CC, and ignores `thread_id`.

## License

MIT
