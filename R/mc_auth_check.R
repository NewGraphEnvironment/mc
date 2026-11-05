#' Check that a cached Gmail token will be found without a browser
#'
#' Run before anything that sends without a person at the keyboard (`Rscript`,
#' cron, CI). gargle finds a cached token partly by the name of the OAuth
#' client it was minted under, and it computes that name afresh in every
#' session. When the stored and computed names differ, non-interactive auth
#' fails with gargle's generic "Can't get Google credentials", even though the
#' token is still valid. `mc_auth_check()` compares the two names and, when they
#' differ, says which they are and how to fix it.
#'
#' @param email Email address whose cached token to check. Default uses
#'   `getOption("mc.from")`, then the `MC_FROM` environment variable.
#' @param cache Path to gargle's token cache. Default `NULL` uses the
#'   `gargle_oauth_cache` option, else gargle's default cache directory.
#'
#' @return `TRUE`, invisibly, when a cached token for `email` matches the
#'   session's OAuth client. Errors otherwise.
#'
#' @details
#' The check is necessary, not sufficient. gargle's cache key also covers the
#' scopes a token was granted, so a token whose client name matches but which
#' was minted with narrower scopes than gmailr requests is still not found.
#' Tokens for the same email minted by other Google packages, under other OAuth
#' clients, are ignored.
#'
#' The check is for the account named by `email`. A scheduled send that fires
#' later authenticates through gmailr's own default, the `GMAILR_EMAIL`
#' environment variable or the `gargle_oauth_email` option, and with neither
#' set gargle takes the first matching cached token. Set `GMAILR_EMAIL` to the
#' same address for unattended sends, so the token checked is the one used.
#'
#' The check reads the context of the R process it runs in: its OAuth client,
#' its cache option and the rlang it has loaded. Run it the way the send will
#' run: from a fresh process started in your home directory
#' (`cd ~ && Rscript -e 'mc::mc_auth_check()'`), because a launchd job starts
#' in `/` and reads `~/.Renviron` and `~/.Rprofile`, never a project's. Keep
#' `GMAILR_OAUTH_CLIENT`, `GMAILR_EMAIL` and `MC_FROM` in `~/.Renviron`: a
#' launchd job does not see variables exported from a shell profile.
#'
#' @section Troubleshooting:
#' **Upgrading rlang invalidates the gargle token cache.** gargle names the
#' OAuth client `<project_id>_<hash>`, where the hash comes from
#' `rlang::hash()`, and that function's output changed in rlang 1.3.0. A token
#' minted under the older rlang carries the old name, so a session running the
#' newer rlang does not find it. An interactive session hides this, because it
#' offers the cached tokens rather than matching them strictly.
#'
#' To fix it:
#'
#' 1. Start a fresh R session, so the rlang loaded is the one installed.
#'    Re-authenticating from a session started before the upgrade writes the
#'    token under the old name again.
#' 2. Move the stale token file this function names out of the cache.
#' 3. Run [mc_auth()] and complete the browser flow.
#' 4. Run `mc_auth_check()` again from a non-interactive session, e.g.
#'    `Rscript -e 'mc::mc_auth_check()'`.
#'
#' @seealso [mc_auth()] to authenticate.
#'
#' @examples
#' \dontrun{
#' # Before a scheduled or cron-driven send
#' mc_auth_check()
#'
#' mc_auth_check("you@example.com")
#' }
#'
#' @importFrom chk chk_string chk_null_or vld_string
#' @export
mc_auth_check <- function(email = default_from(), cache = NULL) {
  chk::chk_string(email)
  chk::chk_null_or(cache, vld = chk::vld_string)

  dir <- auth_cache_dir(cache)
  if (!dir.exists(dir)) {
    stop(
      "No token cache at ", dir, ". Run mc_auth() from an interactive ",
      "session to create one.",
      call. = FALSE
    )
  }

  client <- auth_client()
  expected <- client$name

  # gargle names cache files <hash>_<email>, the hash in hex, and matches the
  # whole email: a suffix test would take sales_al@ for al@.
  files <- list.files(dir, pattern = "^[0-9a-f]+_")
  files <- files[sub("^[0-9a-f]+_", "", files) == email]

  # The cache is shared with other Google packages, so keep only tokens minted
  # for this OAuth client (same id). A stale token has the same id and a
  # different name.
  toks <- lapply(files, function(f) {
    tryCatch(readRDS(file.path(dir, f)), error = function(e) NULL)
  })
  ids <- vapply(toks, function(tok) {
    scalar_chr(tok$client$id %||% tok$app$key)
  }, character(1))
  same_client <- !is.na(ids) & ids == client$id
  files <- files[same_client]
  toks <- toks[same_client]

  if (length(files) == 0) {
    stop(
      "No cached gmailr token for ", email, " in ", dir, ". Run mc_auth(\"",
      email, "\") from an interactive session.",
      call. = FALSE
    )
  }

  stored <- vapply(toks, function(tok) {
    scalar_chr(tok$client$name %||% tok$app$appname %||% tok$app$name)
  }, character(1))

  if (expected %in% stored) {
    message(
      "Cached token for ", email, " matches OAuth client ", expected, "."
    )
    return(invisible(TRUE))
  }

  found <- paste0("  ", files, ": ", ifelse(is.na(stored), "(unreadable)",
                                            stored), collapse = "\n")
  stop(
    "No cached token for ", email, " matches this session's OAuth client ",
    expected, ". Tokens found:\n", found, "\n",
    "gargle derives the client name from rlang::hash(), so this usually ",
    "follows an rlang upgrade. Fix: start a fresh R session, move the file(s) ",
    "above out of ", dir, ", then run mc_auth(\"", email, "\"). ",
    "See ?mc_auth_check.",
    call. = FALSE
  )
}


#' A single string, or `NA` for anything else
#' @noRd
scalar_chr <- function(x) {
  if (is.character(x) && length(x) == 1 && !is.na(x)) x else NA_character_
}


#' OAuth client this session would authenticate with
#'
#' The configured client when there is one, else the one gmailr would
#' configure from its default JSON, as `gmailr::gm_auth()` does. Returns
#' `list(name, id)`.
#' @noRd
auth_client <- function() {
  client <- gmailr::gm_oauth_client()
  if (is.null(client)) {
    path <- gmailr::gm_default_oauth_client()
    if (is.null(path) || !nzchar(path)) {
      stop(
        "No OAuth client configured. Set GMAILR_OAUTH_CLIENT to the path ",
        "of the client JSON, or call gmailr::gm_auth_configure().",
        call. = FALSE
      )
    }
    client <- gargle::gargle_oauth_client_from_json(path)
  }
  list(name = client$name, id = client$id)
}


#' Directory gargle caches tokens in
#'
#' Resolves the `gargle_oauth_cache` option as gargle does: a path is used as
#' given, `NA` or `TRUE` mean gargle's default directory, `FALSE` means caching
#' is off.
#' @noRd
auth_cache_dir <- function(cache = NULL) {
  if (!is.null(cache)) return(cache)
  opt <- gargle::gargle_oauth_cache()
  if (isFALSE(opt)) {
    stop(
      "gargle token caching is off (options(gargle_oauth_cache = FALSE)), ",
      "so there is no cached token to check.",
      call. = FALSE
    )
  }
  if (is.na(opt) || isTRUE(opt)) {
    return(rappdirs::user_cache_dir("gargle"))
  }
  opt
}
