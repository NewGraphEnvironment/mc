# Modify a Gmail thread's label state (archive, trash, star, label, etc.)

Adds and/or removes labels on a thread in one call. Accepts user-defined
label names or Gmail system labels (INBOX, STARRED, UNREAD, IMPORTANT,
TRASH, SPAM, SENT, DRAFT). Covers common operations beyond "labeling":
archive (`remove = "INBOX"`), star (`add = "STARRED"`), trash
(`add = "TRASH"`), mark-read (`remove = "UNREAD"`).

## Usage

``` r
mc_thread_modify(thread_id, add = NULL, remove = NULL, create_missing = FALSE)
```

## Arguments

- thread_id:

  Gmail thread ID (e.g. from
  [`mc_thread_find()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_find.md)).

- add:

  Character vector of label names to add. `NULL` for none.

- remove:

  Character vector of label names to remove. `NULL` for none.

- create_missing:

  Logical. When `TRUE`, calls
  [`mc_label_ensure()`](https://newgraphenvironment.github.io/mc/reference/mc_label_ensure.md)
  on `add` before resolving names — any user label in `add` that doesn't
  yet exist is created. Defaults `FALSE` (strict: errors on unknown
  labels) so existing callers keep their typo guard.

## Value

Invisibly returns the gmailr response.

## Details

Pass **names**, not IDs. User-label names resolve to opaque IDs via
[`gmailr::gm_labels()`](https://gmailr.r-lib.org/reference/gm_labels.html).
System labels pass through unchanged. When a user label's name collides
with a system label ID (e.g. a user label named `"STARRED"`), the system
interpretation wins — almost always what's intended.

At least one of `add` or `remove` must be non-`NULL`. The `gm_labels()`
call is skipped entirely when every input is a system label.

Set `create_missing = TRUE` when applying labels from a YAML-driven
workflow (e.g. via
[`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md))
so new project tags don't error on first use. See
[`mc_label_ensure()`](https://newgraphenvironment.github.io/mc/reference/mc_label_ensure.md)
for the underlying primitive.

## Examples

``` r
if (FALSE) { # \dontrun{
# Apply a user label
mc_thread_modify("18171fb2cec08e9d", add = "Clients/Acme")

# Archive and mark read in one call
mc_thread_modify("18171fb2cec08e9d", remove = c("INBOX", "UNREAD"))

# Star a thread
mc_thread_modify("18171fb2cec08e9d", add = "STARRED")

# Status transition
mc_thread_modify("18171fb2cec08e9d", add = "Done", remove = "Pending")
} # }
```
