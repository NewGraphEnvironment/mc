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
  attachments = NULL,
  labels = NULL,
  labels_create = TRUE,
  html = NULL,
  send_at = NULL,
  scheduler = c("callr", "auto", "launchd", "at")
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
  `MC_FROM` environment variable. Errors if neither is set.

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

- attachments:

  Optional character vector of file paths to attach. Each file is
  attached via
  [`gmailr::gm_attach_file()`](https://gmailr.r-lib.org/reference/gm_mime.html).
  Default `NULL`.

- labels:

  Optional character vector of Gmail label names to apply to the
  resulting thread. Applied via
  [`mc_thread_modify()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_modify.md)
  after a successful draft creation or send. Labels are applied to the
  draft's thread on the draft path; in most cases Gmail keeps the same
  thread when the draft is sent from the UI, so labels carry over.

- labels_create:

  Logical. When `TRUE` (default), missing user labels in `labels` are
  auto-created via
  [`mc_label_ensure()`](https://newgraphenvironment.github.io/mc/reference/mc_label_ensure.md)
  before being applied — supports tag-as-you-go in YAML-driven drafts.
  Set `FALSE` to keep typo-guard behavior (errors on unknown labels,
  downgraded to a warning per the existing label tryCatch).

- html:

  Optional pre-rendered HTML body. If provided, `path` is ignored and
  this HTML is used directly.

- send_at:

  Schedule the email for later. Either a `POSIXct` datetime or a numeric
  number of minutes from now. Default `NULL` (send/draft immediately).
  When set, `draft` is forced to `FALSE` and the email is sent via the
  backend selected by `scheduler`.

- scheduler:

  Backend for scheduled send. One of `"callr"` (default —
  [`callr::r_bg`](https://callr.r-lib.org/reference/r_bg.html)
  background process; back-compat with prior versions), `"auto"`
  (resolves to OS-native: `launchd` on macOS, `at` on Linux),
  `"launchd"` (force macOS launchd), `"at"` (force Linux at — Phase 3,
  not yet implemented). Ignored when `send_at` is `NULL`. See the
  `Scheduled send` section in details for the lifecycle caveat that
  motivates `"auto"`.

## Value

When `send_at` is `NULL`, the Gmail thread ID of the resulting draft or
sent message, returned invisibly. May be `NULL` if the gmailr response
did not include one (e.g. mocked tests). When `send_at` is set, returns
a backend-specific scheduler handle invisibly:

- `scheduler = "callr"`: a
  [`callr::r_bg()`](https://callr.r-lib.org/reference/r_bg.html) process
  handle with `$is_alive()` / `$kill()` methods.

- `scheduler = "launchd"` (macOS) or `"auto"` on Darwin: a list with
  `$backend = "launchd"`, `$label`, `$plist` (path), and `$args_path`.
  Cancel manually via `launchctl unload <plist>` + `unlink` if needed.

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

`send_at` runs a background R process on your machine via
[`callr::r_bg()`](https://callr.r-lib.org/reference/r_bg.html). On
macOS, `caffeinate` is used to prevent idle sleep so the machine stays
awake until the email sends. The laptop lid can be closed as long as
power is connected.

- **Laptop powered on** — sends on time (caffeinate prevents sleep)

- **Laptop powered off** — process dies, email never sends

If caffeinate is bypassed and the machine sleeps through the send
window, a 5-minute grace period applies. Past that, the send is
**skipped** to prevent stale emails firing unexpectedly.

#### Lifecycle caveat (mc#36)

The [`callr::r_bg`](https://callr.r-lib.org/reference/r_bg.html)
background process can be cleaned up before fire time when its parent
context exits (one-shot `Rscript -e ...`, RStudio session that closes,
CI job). When that happens the send silently drops — the bg process is
gone before it could log a `STARTED` entry, and `caffeinate` exits when
its watched PID dies. `send_at` emits a
[`warning()`](https://rdrr.io/r/base/warning.html) on use to surface
this risk; future versions will add `scheduler = "auto"` backed by
OS-native primitives (`launchd` on macOS, `at` on Linux) that own their
own lifecycle.

Heartbeat log entries are written to `~/.mc/send_log.txt` so missed
fires are auditable from the log alone:

- `SCHEDULED` — written at submission with the target time

- `STARTED` — written at fire time, just before the actual send

- `SENT` / `SKIPPED` / `FAILED` — written at outcome

A `SCHEDULED` line with no follow-up `STARTED` entry means the
background process died before it fired.

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

# Attach files
mc_send("communications/draft.md",
        to = "brandon@example.com",
        subject = "Planting plan",
        attachments = c("data/plan.xlsx", "fig/map.pdf"))
} # }
```
