# Read frontmatter and assemble dispatch arguments (internal)

Shared by
[`mc_md_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_md_draft.md)
and
[`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md).

## Usage

``` r
md_dispatch_args(path, to_self = FALSE, override = list())
```

## Arguments

- path:

  Path to the markdown draft (with YAML frontmatter).

- to_self:

  Logical. If `TRUE`, address the message to the sender and drop `cc`,
  `bcc` and `thread_id`, so it reaches nobody else. Default `FALSE`.
  Caps the recipients; does not stop the send.

- override:

  Named list of arguments to override frontmatter values at call time
  (e.g. `list(subject = "New subject")`). Overrides merge **after**
  frontmatter, so `override` wins.

## Value

Named list of arguments for
[`mc_draft()`](https://newgraphenvironment.github.io/mc/reference/mc_draft.md)
/
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).
