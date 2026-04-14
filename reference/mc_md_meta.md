# Read YAML frontmatter from a markdown email draft

Parses the YAML frontmatter block at the top of a markdown file and
returns it as a named list. Returns an empty list when the file has no
frontmatter.

## Usage

``` r
mc_md_meta(path)
```

## Arguments

- path:

  Path to the markdown file.

## Value

A named list of frontmatter fields.

## Examples

``` r
if (FALSE) { # \dontrun{
mc_md_meta("communications/20260413_cindy_newsletter_draft.md")
} # }
```
