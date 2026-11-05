# Check that a cached Gmail token will be found without a browser

Run before anything that sends without a person at the keyboard
(`Rscript`, cron, CI). gargle finds a cached token partly by the name of
the OAuth client it was minted under, and it computes that name afresh
in every session. When the stored and computed names differ,
non-interactive auth fails with gargle's generic "Can't get Google
credentials", even though the token is still valid. `mc_auth_check()`
compares the two names and, when they differ, says which they are and
how to fix it.

## Usage

``` r
mc_auth_check(email = default_from(), cache = NULL)
```

## Arguments

- email:

  Email address whose cached token to check. Default uses
  `getOption("mc.from")`, then the `MC_FROM` environment variable.

- cache:

  Path to gargle's token cache. Default `NULL` uses the
  `gargle_oauth_cache` option, else gargle's default cache directory.

## Value

`TRUE`, invisibly, when a cached token for `email` matches the session's
OAuth client. Errors otherwise.

## Details

The check is necessary, not sufficient. gargle's cache key also covers
the scopes a token was granted, so a token whose client name matches but
which was minted with narrower scopes than gmailr requests is still not
found. Tokens for the same email minted by other Google packages, under
other OAuth clients, are ignored.

The check is for the account named by `email`. A scheduled send that
fires later authenticates through gmailr's own default, the
`GMAILR_EMAIL` environment variable or the `gargle_oauth_email` option,
and with neither set gargle takes the first matching cached token. Set
`GMAILR_EMAIL` to the same address for unattended sends, so the token
checked is the one used.

The check reads the context of the R process it runs in: its OAuth
client, its cache option and the rlang it has loaded. Run it the way the
send will run: from a fresh process started in your home directory
(`cd ~ && Rscript -e 'mc::mc_auth_check()'`), because a launchd job
starts in `/` and reads `~/.Renviron` and `~/.Rprofile`, never a
project's. Keep `GMAILR_OAUTH_CLIENT`, `GMAILR_EMAIL` and `MC_FROM` in
`~/.Renviron`: a launchd job does not see variables exported from a
shell profile.

## Troubleshooting

**Upgrading rlang invalidates the gargle token cache.** gargle names the
OAuth client `<project_id>_<hash>`, where the hash comes from
[`rlang::hash()`](https://rlang.r-lib.org/reference/hash.html), and that
function's output changed in rlang 1.3.0. A token minted under the older
rlang carries the old name, so a session running the newer rlang does
not find it. An interactive session hides this, because it offers the
cached tokens rather than matching them strictly.

To fix it:

1.  Start a fresh R session, so the rlang loaded is the one installed.
    Re-authenticating from a session started before the upgrade writes
    the token under the old name again.

2.  Move the stale token file this function names out of the cache.

3.  Run
    [`mc_auth()`](https://newgraphenvironment.github.io/mc/reference/mc_auth.md)
    and complete the browser flow.

4.  Run `mc_auth_check()` again from a non-interactive session, e.g.
    `Rscript -e 'mc::mc_auth_check()'`.

## See also

[`mc_auth()`](https://newgraphenvironment.github.io/mc/reference/mc_auth.md)
to authenticate.

## Examples

``` r
if (FALSE) { # \dontrun{
# Before a scheduled or cron-driven send
mc_auth_check()

mc_auth_check("you@example.com")
} # }
```
