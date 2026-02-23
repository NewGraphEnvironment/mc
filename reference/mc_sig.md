# Return an email signature as HTML

Reads a signature HTML file. Defaults to the standard New Graph
signature bundled at `inst/sig/signature.html`. Pass a custom path to
use a different signature.

## Usage

``` r
mc_sig(path = NULL)
```

## Arguments

- path:

  Path to a signature HTML file. Default `NULL` uses the bundled New
  Graph signature.

## Value

A character string of HTML.

## Examples

``` r
if (FALSE) { # \dontrun{
cat(mc_sig())
cat(mc_sig("path/to/custom_sig.html"))
} # }
```
