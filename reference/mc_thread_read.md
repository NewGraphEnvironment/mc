# Read all messages in a Gmail thread

Fetches a thread by ID and returns each message's sender, date, subject,
and plain-text body. Useful for reviewing a conversation before
composing a follow-up with
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).

## Usage

``` r
mc_thread_read(thread_id)
```

## Arguments

- thread_id:

  Gmail thread ID (from
  [`mc_thread_find()`](https://newgraphenvironment.github.io/mc/reference/mc_thread_find.md)).

## Value

A data frame with columns `from`, `date`, `subject`, and `body`, ordered
oldest to newest.

## Examples

``` r
if (FALSE) { # \dontrun{
mc_thread_find("from:brandon subject:cottonwood")
mc_thread_read("19adb18351867c34")
} # }
```
