# mc

> Mail Composer. Three lines to draft an email.

Compose, draft, and send emails from markdown files via the Gmail API.
Wraps [gmailr](https://gmailr.r-lib.org/) to eliminate the 80 lines of
boilerplate that every email script repeats.

## Installation

``` r
pak::pak("NewGraphEnvironment/mc")
```

## Usage

Write your email body in markdown. Everything above the `---` separator
is a human-readable envelope (notes for the author) and is stripped by
[`mc_md_render()`](https://newgraphenvironment.github.io/mc/reference/mc_md_render.md)
before conversion. Recipients, subject, and other envelope fields are
set as R parameters in
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).

``` markdown
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

``` r
library(mc)
mc_auth()
mc_send("communications/draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs - 2026 planting")
```

That creates a Gmail draft with HTML formatting and the standard
signature appended. When you’re ready to send for real:

``` r
mc_send("communications/draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs",
        draft = FALSE)
```

## Tables in emails

Need an R-generated table in your email? Use `mc_compose()` to mix
markdown files, HTML, and kable/kableExtra objects:

``` r
df <- data.frame(Site = c("Nechako", "Mackenzie"), Plugs = c(4000, 3000))

body <- mc_compose(
  "communications/intro.md",
  knitr::kable(df, format = "html"),
  "<p>Let me know if this looks right.</p>"
)

mc_send(html = body, to = "brandon@example.com", subject = "Planting plan")
```

See
[`vignette("tables-in-emails")`](https://newgraphenvironment.github.io/mc/articles/tables-in-emails.md)
for kableExtra styling tips and Gmail limitations.

## Functions

| Function                                                                                   | What it does                                                       |
|--------------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| [`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)               | Draft or send an email from a markdown file                        |
| `mc_compose()`                                                                             | Combine markdown, HTML, and kable objects into one email body      |
| [`mc_auth()`](https://newgraphenvironment.github.io/mc/reference/mc_auth.md)               | Authenticate with Gmail                                            |
| [`mc_md_render()`](https://newgraphenvironment.github.io/mc/reference/mc_md_render.md)     | Convert a single markdown file to HTML                             |
| [`mc_sig()`](https://newgraphenvironment.github.io/mc/reference/mc_sig.md)                 | Return an email signature as HTML (bundled default or custom path) |
| [`mc_thread_find()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_find.md) | Search Gmail for thread IDs                                        |

## Threading

Reply into an existing conversation:

``` r
# Find the thread
mc_thread_find("from:brandon subject:cottonwood")

# Send into it
mc_send("draft.md",
        to = "brandon@example.com",
        subject = "Re: Cottonwood plugs",
        thread_id = "19c05f0a98188c91",
        draft = FALSE)
```

**Note:** `gm_create_draft()` does not support `thread_id`. Drafts are
always standalone. Use `draft = FALSE` to send directly into a thread,
or send the draft manually from the Gmail UI (Gmail will match by
subject line if it starts with “Re:”).

## Test mode

Send to yourself to preview:

``` r
mc_send("draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs",
        test = TRUE)
```

Test mode redirects to your own address, strips CC/BCC, and ignores
`thread_id`.

## License

MIT
