# Search Gmail for thread IDs

Searches Gmail messages and returns matching thread IDs. Useful for
finding the `thread_id` to pass to
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
when replying into an existing conversation.

## Usage

``` r
mc_thread_find(query, n = 5)
```

## Arguments

- query:

  Gmail search query. Supports the same syntax as the Gmail search box
  (e.g., `"from:brandon subject:cottonwood"`).

- n:

  Maximum number of results. Default `5`.

## Value

A data frame with columns `thread_id`, `from`, `subject`, and `date`,
sorted by most recent first.

## Examples

``` r
if (FALSE) { # \dontrun{
mc_thread_find("from:brandon.geldart subject:cottonwood")
mc_thread_find("from:brandon newer_than:7d")
} # }
```
