# Send or draft an email from a markdown file

The main function. Reads a markdown draft, renders to HTML, builds a
MIME message, and either creates a Gmail draft or sends immediately.

## Usage

``` r
mc_send(
  path = NULL,
  to,
  subject,
  cc = NULL,
  bcc = NULL,
  from = default_from(),
  thread_id = NULL,
  draft = TRUE,
  test = FALSE,
  sig = TRUE,
  sig_path = NULL,
  html = NULL,
  send_at = NULL
)
```

## Arguments

- path:

  Path to the markdown draft file. Passed to
  [`mc_md_render()`](https://newgraphenvironment.github.io/mc/reference/mc_md_render.md).

- to:

  Recipient email address (character string or vector).

- subject:

  Email subject line.

- cc:

  Optional CC recipients (character vector). Default `NULL`.

- bcc:

  Optional BCC recipients (character vector). Default `NULL`.

- from:

  Sender address. Default uses `getOption("mc.from")`, then the
  `MC_FROM` environment variable, then `"al@newgraphenvironment.com"` as
  a final fallback.

- thread_id:

  Gmail thread ID to reply into. Default `NULL` (new thread). Use
  [`mc_thread_find()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_find.md)
  to look up thread IDs.

- draft:

  Logical. If `TRUE` (default), create a Gmail draft. If `FALSE`, send
  immediately.

- test:

  Logical. If `TRUE`, override `to` with `from` (send to self) and
  ignore `cc` and `thread_id`. Default `FALSE`.

- sig:

  Logical. Append signature? Passed to
  [`mc_md_render()`](https://newgraphenvironment.github.io/mc/reference/mc_md_render.md).
  Default `TRUE`.

- sig_path:

  Path to a custom signature HTML file. Default `NULL` uses the bundled
  New Graph signature. Passed to
  [`mc_md_render()`](https://newgraphenvironment.github.io/mc/reference/mc_md_render.md).
  Ignored when `sig = FALSE` or when `html` is provided.

- html:

  Optional pre-rendered HTML body. If provided, `path` is ignored and
  this HTML is used directly.

- send_at:

  Schedule the email for later. Either a `POSIXct` datetime or a numeric
  number of minutes from now. Default `NULL` (send/draft immediately).
  When set, `draft` is forced to `FALSE` and the email is sent in a
  background R process via
  [`callr::r_bg()`](https://callr.r-lib.org/reference/r_bg.html).
  Requires the **callr** package.

## Value

When `send_at` is `NULL`, invisible `NULL`. When `send_at` is set,
returns the
[`callr::r_bg()`](https://callr.r-lib.org/reference/r_bg.html) process
handle invisibly. Use `$is_alive()` to check status or `$kill()` to
cancel.

## Details

Authenticates automatically if no active Gmail session is detected.

### Threading

Gmail's `gm_create_draft()` does **not** support `thread_id`. When
`draft = TRUE` and `thread_id` is set, `mc_send()` issues a warning
because the draft will not appear in the thread until manually sent from
the Gmail UI. Set subject to `"Re: Original Subject"` so Gmail's
thread-matching heuristic can place it correctly.

When `draft = FALSE` and `thread_id` is set, the message is sent
directly into the thread via `gm_send_message(thread_id = ...)`.

### Test mode

`test = TRUE` sends to yourself, strips CC, and ignores `thread_id` to
prevent accidental sends to real threads during development.

### Scheduled send

`send_at` runs a background R process on your machine. On macOS,
`caffeinate` is used to prevent idle sleep so the machine stays awake
until the email sends. The laptop lid can be closed as long as power is
connected.

- **Laptop powered on** — sends on time (caffeinate prevents sleep)

- **Laptop powered off** — process dies, email never sends

If caffeinate is bypassed and the machine sleeps through the send
window, a 5-minute grace period applies. Past that, the send is
**skipped** to prevent stale emails firing unexpectedly.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a draft (safe default)
mc_send("communications/draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs")

# Send into an existing thread
mc_send("communications/draft.md",
        to = "brandon@example.com",
        subject = "Re: Cottonwood plugs",
        thread_id = "19c05f0a98188c91",
        draft = FALSE)

# Test mode — sends to self
mc_send("communications/draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs",
        test = TRUE)

# Send in 10 minutes
proc <- mc_send("communications/draft.md",
                to = "brandon@example.com",
                subject = "Cottonwood plugs",
                send_at = 10)
proc$is_alive()  # check if still waiting
proc$kill()      # cancel

# Send at a specific time
mc_send("communications/draft.md",
        to = "brandon@example.com",
        subject = "Cottonwood plugs",
        send_at = as.POSIXct("2026-02-24 09:11:00"))
} # }
```
