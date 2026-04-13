# Search Gmail at the message level

Like
[`mc_thread_find()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_find.md)
but returns one row per message rather than per thread. Useful when
timed sends, re-threads, or manually moved drafts scatter a logical
conversation across multiple thread IDs and you want to locate a
specific message directly.

## Usage

``` r
mc_message_find(
  query,
  n = 10,
  after = NULL,
  before = NULL,
  status = c("any", "sent", "draft")
)
```

## Arguments

- query:

  Gmail search query.

- n:

  Maximum number of results. Default `10`.

- after, before:

  Optional date filters. `Date` or `"YYYY-MM-DD"` string. See
  [`mc_thread_find()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_find.md).

- status:

  One of `"any"` (default), `"sent"`, or `"draft"`. `"sent"` restricts
  to non-draft messages; `"draft"` searches drafts instead of messages.

## Value

A data frame with columns `message_id`, `thread_id`, `from`, `to`,
`subject`, `date`, and `status`, most recent first. Returns an empty
data frame (same columns) when no messages match.

## Examples

``` r
if (FALSE) { # \dontrun{
mc_message_find("to:cindy newsletter", after = Sys.Date() - 1)
mc_message_find("subject:invoice", status = "sent")
mc_message_find("subject:draft-only", status = "draft")
} # }
```
