#' Render a markdown draft to HTML email body
#'
#' Reads a markdown file, strips everything above the first `---` separator
#' (header metadata), converts the remaining markdown to HTML, inlines table
#' styles for Gmail compatibility, and appends the New Graph signature.
#'
#' @param path Path to the markdown draft file.
#' @param sig Logical. Append a signature? Default `TRUE`.
#' @param sig_path Path to a custom signature HTML file. Default `NULL`
#'   uses the bundled New Graph signature. Ignored when `sig = FALSE`.
#'
#' @return A character string of HTML ready for [mc_send()].
#'
#' @details
#' Gmail strips `<style>` blocks from HTML emails. This function adds inline
#' styles to `<table>`, `<th>`, and `<td>` elements so tables render correctly.
#'
#' The markdown file should follow the compost template format:
#'
#' ```
#' # Email to Recipient - Topic
#'
#' **Subject:** ...
#'
#' **To:** ...
#'
#' ---
#'
#' Hi Name,
#'
#' Body text here.
#' ```
#'
#' Everything above and including the `---` line is stripped. Everything below
#' is converted to HTML.
#'
#' @examples
#' \dontrun{
#' html <- mc_md_render("communications/20260222_brandon_cottonwood_draft.md")
#' cat(html)
#' }
#'
#' @export
mc_md_render <- function(path, sig = TRUE, sig_path = NULL) {
  chk::chk_string(path)
  chk::chk_flag(sig)
  chk::chk_null_or(sig_path, vld = chk::vld_string)
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }

  raw <- paste(readLines(path, warn = FALSE), collapse = "\n")

  # Strip header: everything up to and including the --- separator
  body_md <- sub("^[\\s\\S]*?---\\s*\\n", "", raw, perl = TRUE)

  # Convert markdown to HTML
  body_html <- commonmark::markdown_html(body_md, extensions = TRUE)

  # Inline table styles for Gmail compatibility
  body_html <- inline_table_styles(body_html)

  # Append signature

  if (sig) {
    body_html <- paste0(body_html, "\n", mc_sig(path = sig_path))
  }

  body_html
}


#' Add inline styles to HTML tables for Gmail
#'
#' Gmail strips `<style>` blocks so table styling must be inline.
#'
#' @param html Character string of HTML.
#' @return HTML with inline table styles.
#' @noRd
inline_table_styles <- function(html) {
  html <- gsub(
    "<table>",
    '<table style="border-collapse: collapse; margin: 12px 0;">',
    html, fixed = TRUE
  )
  html <- gsub(
    "<th>",
    '<th style="border: 1px solid #ddd; padding: 8px; text-align: left; background-color: #f5f5f5;">',
    html, fixed = TRUE
  )
  html <- gsub(
    "<td>",
    '<td style="border: 1px solid #ddd; padding: 8px;">',
    html, fixed = TRUE
  )
  html
}
