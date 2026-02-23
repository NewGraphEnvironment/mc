# Return the standard New Graph email signature as HTML

Reads the signature template bundled at `inst/sig/signature.html`. Used
by
[`mc_md_render()`](https://newgraphenvironment.github.io/mc/reference/mc_md_render.md)
to append the signature automatically.

## Usage

``` r
mc_sig()
```

## Value

A character string of HTML.

## Examples

``` r
if (FALSE) { # \dontrun{
cat(mc_sig())
} # }
```
