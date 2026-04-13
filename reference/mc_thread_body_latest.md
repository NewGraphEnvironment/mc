# Return the latest top-level message body in a thread

Convenience wrapper over
[`mc_thread_read()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_read.md)
that pulls the most recent message in a thread and, by default, strips
quoted reply history so you get just what was actually written at the
top. Useful for recording what was sent, comparing draft vs sent, or
scanning thread activity.

## Usage

``` r
mc_thread_body_latest(
  thread_id,
  strip_quotes = TRUE,
  status = c("any", "sent", "draft")
)
```

## Arguments

- thread_id:

  Gmail thread ID.

- strip_quotes:

  Logical. If `TRUE` (default), remove lines starting with `>` plus the
  `"On ... wrote:"` attribution line that Gmail inserts above quoted
  history.

- status:

  One of `"any"` (default), `"sent"`, or `"draft"`. Restricts the pool
  of messages considered when selecting the latest.

## Value

A single character string with the latest body (or `""` if none).

## Examples

``` r
if (FALSE) { # \dontrun{
mc_thread_body_latest("19cd3565c3161b4b")
mc_thread_body_latest("19cd3565c3161b4b", strip_quotes = FALSE)
} # }
```
