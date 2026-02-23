#' Authenticate with Gmail
#'
#' Wrapper around [gmailr::gm_auth()] with the default New Graph
#' email address. Call once per session before [mc_send()].
#'
#' @param email Email address to authenticate as.
#'   Default `"al@newgraphenvironment.com"`.
#'
#' @return Invisible `NULL`. Called for side effect of authenticating.
#'
#' @examples
#' \dontrun{
#' mc_auth()
#' }
#'
#' @export
mc_auth <- function(email = "al@newgraphenvironment.com") {
  gmailr::gm_auth(email = email)
  invisible(NULL)
}
