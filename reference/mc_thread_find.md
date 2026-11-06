# Search Gmail for thread IDs

Searches Gmail messages and returns matching thread IDs. Useful for
finding the `thread_id` to pass to
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
when replying into an existing conversation.

## Usage

``` r
mc_thread_find(query, n = 5, after = NULL, before = NULL)
```

## Arguments

- query:

  Gmail search query. Takes the same search operators as the Gmail
  search box, such as `from:`, `to:`, `subject:`, `has:attachment`,
  `newer_than:7d`, `is:unread` and `in:drafts`, combined with spaces
  (and), `OR`, `-` (not) and quotes for exact phrases. The full list is
  in Google's [search operator
  reference](https://support.google.com/mail/answer/7190).

- n:

  Maximum number of results. Default `5`.

- after, before:

  Optional date filters. `Date` object or character string in
  `"YYYY-MM-DD"` form. Translated to Gmail's `after:` / `before:`
  operators (inclusive/exclusive semantics follow Gmail's behaviour:
  `after:` is inclusive, `before:` is exclusive).

## Value

A data frame with columns `thread_id`, `from`, `subject`, and `date`,
sorted by most recent first.

## Examples

``` r
if (FALSE) { # \dontrun{
# One sender, one topic
mc_thread_find("from:brandon.geldart subject:cottonwood")

# Recent mail only
mc_thread_find("from:brandon newer_than:7d")

# Mail with an attachment, an exact phrase, and a word left out
mc_thread_find('has:attachment "site plan" -invoice')

# Either of two senders, unread
mc_thread_find("from:(brandon OR cindy) is:unread", n = 10)

# Date filters as arguments
mc_thread_find("newsletter", after = Sys.Date() - 7)
} # }
```
