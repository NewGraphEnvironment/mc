#' Return the standard New Graph email signature as HTML
#'
#' Reads the signature template bundled at `inst/sig/signature.html`.
#' Used by [mc_md_render()] to append the signature automatically.
#'
#' @return A character string of HTML.
#'
#' @examples
#' \dontrun{
#' cat(mc_sig())
#' }
#'
#' @export
mc_sig <- function() {
  sig_path <- system.file("sig", "signature.html", package = "mc")
  if (sig_path == "") {
    stop("Signature template not found. Reinstall mc package.", call. = FALSE)
  }
  paste(readLines(sig_path, warn = FALSE), collapse = "\n")
}
