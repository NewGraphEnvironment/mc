#' Authenticate with Gmail
#'
#' Wrapper around [gmailr::gm_auth()] with the default New Graph
#' email address. Call once per session before [mc_send()].
#'
#' @param email Email address to authenticate as.
#'   Default uses `getOption("mc.from")`, then the `MC_FROM` environment
#'   variable. Errors if neither is set.
#'
#' @return Invisible `NULL`. Called for side effect of authenticating.
#'
#' @examples
#' \dontrun{
#' mc_auth()
#'
#' # Set globally in .Rprofile to avoid passing email every time:
#' options(mc.from = "you@example.com")
#' }
#'
#' @importFrom chk chk_string
#' @importFrom gmailr gm_auth
#' @export
mc_auth <- function(email = default_from()) {
  chk::chk_string(email)
  gmailr::gm_auth(email = email)
  invisible(NULL)
}


#' Get the default sender address
#'
#' Checks `getOption("mc.from")`, then `MC_FROM` env var.
#' Errors if neither is set.
#' @return Character string.
#' @noRd
default_from <- function() {
  from <- getOption("mc.from")
  if (!is.null(from)) return(from)
  env <- Sys.getenv("MC_FROM", unset = "")
  if (nzchar(env)) return(env)
  stop(
    "No default email found. Set options(mc.from = \"you@example.com\") ",
    "in .Rprofile or set the MC_FROM environment variable.",
    call. = FALSE
  )
}
