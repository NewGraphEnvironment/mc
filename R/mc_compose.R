#' Compose an HTML email from mixed content
#'
#' Combines markdown files, HTML strings, and kable/kableExtra table objects
#' into a single HTML email body. Use this when you need R-generated tables
#' or other dynamic content mixed with prose.
#'
#' @param ... Parts to compose, in order. Each can be:
#'   \describe{
#'     \item{Markdown file path}{A `.md` file path. The header above `---` is
#'       stripped (if present) and the body is converted to HTML.}
#'     \item{HTML string}{A character string of raw HTML, passed through as-is.}
#'     \item{kable/kableExtra object}{Output from [knitr::kable()] or
#'       kableExtra functions. Converted to character automatically.}
#'   }
#' @param sig Logical. Append signature? Default `TRUE`.
#' @param sig_path Path to a custom signature HTML file. Default `NULL`.
#'
#' @return A character string of HTML ready for the `html` argument of
#'   [mc_send()].
#'
#' @details
#' Gmail cannot render scrolling tables or CSS-class-based styling.
#' For tables that look good in email:
#' - Use [knitr::kable()] for clean, simple tables
#' - Use `kableExtra::row_spec()` and `kableExtra::column_spec()` for
#'   inline styling (colors, bold, backgrounds)
#' - Avoid `bootstrap_options` like `"striped"` — the CSS classes are
#'   stripped by Gmail
#'
#' `mc_compose()` automatically adds border and padding inline styles
#' to all `<table>`, `<th>`, and `<td>` elements for Gmail compatibility.
#'
#' @examples
#' \dontrun{
#' # Prose + table + more prose
#' df <- data.frame(Site = c("Nechako", "Mackenzie"), Plugs = c(4000, 3000))
#'
#' body <- mc_compose(
#'   "communications/intro.md",
#'   knitr::kable(df, format = "html"),
#'   "communications/closing.md"
#' )
#' mc_send(html = body, to = "someone@example.com", subject = "Update")
#'
#' # Inline markdown (no file needed)
#' body <- mc_compose(
#'   "<p>Hi Brandon,</p>",
#'   knitr::kable(df, format = "html"),
#'   "<p>Let me know if this looks right.</p>"
#' )
#' }
#'
#' @export
mc_compose <- function(..., sig = TRUE, sig_path = NULL) {
  chk::chk_flag(sig)
  chk::chk_null_or(sig_path, vld = chk::vld_string)

  parts <- list(...)

  if (length(parts) == 0) {
    stop("Provide at least one content part.", call. = FALSE)
  }

  html_parts <- vapply(parts, resolve_part, character(1))

  body_html <- paste(html_parts, collapse = "\n")
  body_html <- inline_table_styles(body_html)

  if (sig) {
    body_html <- paste0(body_html, "\n", mc_sig(path = sig_path))
  }

  body_html
}


#' Resolve a content part to an HTML string
#'
#' @param part A markdown file path, HTML string, or kable object.
#' @return A character string of HTML.
#' @noRd
resolve_part <- function(part) {
  # kable / kableExtra objects
  if (inherits(part, c("knitr_kable", "kableExtra"))) {
    return(as.character(part))
  }

  # Must be character at this point
  if (!is.character(part) || length(part) != 1) {
    stop(
      "Each part must be a file path (string), HTML string, or kable object.",
      call. = FALSE
    )
  }

  # Markdown file — render it
  if (grepl("\\.md$", part, ignore.case = TRUE) && file.exists(part)) {
    raw <- paste(readLines(part, warn = FALSE), collapse = "\n")
    # Strip header above --- if present
    if (grepl("---", raw, fixed = TRUE)) {
      raw <- sub("^[\\s\\S]*?---\\s*\\n", "", raw, perl = TRUE)
    }
    return(commonmark::markdown_html(raw, extensions = TRUE))
  }

  # Raw HTML string — pass through
  part
}
