# Authenticate with Gmail

Wrapper around
[`gmailr::gm_auth()`](https://gmailr.r-lib.org/reference/gm_auth.html)
with the default New Graph email address. Call once per session before
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md).

## Usage

``` r
mc_auth(email = "al@newgraphenvironment.com")
```

## Arguments

- email:

  Email address to authenticate as. Default
  `"al@newgraphenvironment.com"`.

## Value

Invisible `NULL`. Called for side effect of authenticating.

## Examples

``` r
if (FALSE) { # \dontrun{
mc_auth()
} # }
```
