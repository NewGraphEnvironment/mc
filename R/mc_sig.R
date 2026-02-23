#' Return an email signature as HTML
#'
#' Reads a signature HTML file. Defaults to the standard New Graph signature
#' bundled at `inst/sig/signature.html`. Pass a custom path to use a
#' different signature.
#'
#' @param path Path to a signature HTML file. Default `NULL` uses the
#'   bundled New Graph signature.
#'
#' @return A character string of HTML.
#'
#' @examples
#' \dontrun{
#' cat(mc_sig())
#' cat(mc_sig("path/to/custom_sig.html"))
#' }
#'
#' @export
mc_sig <- function(path = NULL) {
  if (is.null(path)) {
    path <- system.file("sig", "signature.html", package = "mc")
    if (path == "") {
      stop("Signature template not found. Reinstall mc package.", call. = FALSE)
    }
  }
  if (!file.exists(path)) {
    stop("Signature file not found: ", path, call. = FALSE)
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}
