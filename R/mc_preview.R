#' Preview composed HTML in a browser before sending
#'
#' Writes the output of [mc_compose()] (or any HTML string) to a temp file
#' and opens it in the default browser. Catches markdown rendering issues
#' (mis-nested links, stray backticks, unintended list formatting, signature
#' layout) locally before creating a Gmail draft.
#'
#' @param html A character string containing HTML, typically from
#'   [mc_compose()].
#' @param path File path to write the preview to. Defaults to a stable
#'   location under [tools::R_user_dir()] (`mc/cache/preview.html`) so the
#'   file persists after the R session exits and can be opened manually.
#' @param open Logical. If `TRUE` (default), open the file with
#'   [utils::browseURL()]. When `FALSE`, only write the file.
#'
#' @return The file path, invisibly.
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
mc_preview <- function(html,
                       path = file.path(
                         tools::R_user_dir("mc", "cache"), "preview.html"
                       ),
                       open = TRUE) {
  chk::chk_string(html)
  chk::chk_string(path)
  chk::chk_flag(open)

  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  writeLines(html, path)
  if (open) utils::browseURL(path)
  invisible(path)
}
