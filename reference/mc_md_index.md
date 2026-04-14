# Index markdown email drafts under a directory

Scans a directory tree for markdown drafts matching `pattern` and
returns a data frame summarising their frontmatter. Turns a
compost-style `communications/` folder into a searchable archive without
querying Gmail.

## Usage

``` r
mc_md_index(
  dir = "communications",
  pattern = "_draft\\.md$",
  recursive = TRUE
)
```

## Arguments

- dir:

  Directory to scan. Defaults to `"communications"`.

- pattern:

  Regex matched against filename (not path). Default `"_draft\\.md$"`
  matches compost draft naming.

- recursive:

  Logical. Recurse into subdirectories? Default `TRUE`.

## Value

A data frame with columns `path`, `date`, `to`, `cc`, `subject`,
`thread_id`, `has_attachments`. `date` is parsed from an 8-digit
`YYYYMMDD_` prefix in the basename when present, else `NA`. Multi-value
fields (`to`, `cc`) are collapsed with `", "`.

## Details

Files without YAML frontmatter are included with `NA` for all metadata
columns so missing drafts are visible in the index rather than hidden.

## Examples

``` r
if (FALSE) { # \dontrun{
mc_md_index("communications/")
mc_md_index() |> dplyr::filter(grepl("cindy", to))
} # }
```
