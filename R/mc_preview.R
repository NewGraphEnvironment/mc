#' Preview composed HTML in a browser before sending
#'
#' Writes the output of [mc_compose()] (or any HTML string) to a temp file
#' and opens it in the default browser. Catches markdown rendering issues
#' (mis-nested links, stray backticks, unintended list formatting, signature
#' layout) locally before creating a Gmail draft.
#'
#' @param html A character string containing HTML, typically from
#'   [mc_compose()].
#' @param open Logical. If `TRUE` (default in interactive sessions), open
#'   the file with [utils::browseURL()]. When `FALSE`, only write the file.
#'
#' @return The tempfile path, invisibly.
#'
#' @examples
#' \dontrun{
#' html <- mc_compose("communications/project/draft.md")
#' mc_preview(html)
#' }
#'
#' @importFrom chk chk_string chk_flag
#' @importFrom utils browseURL
#' @export
mc_preview <- function(html, open = interactive()) {
  chk::chk_string(html)
  chk::chk_flag(open)

  path <- tempfile(fileext = ".html")
  writeLines(html, path)
  if (open) utils::browseURL(path)
  invisible(path)
}
