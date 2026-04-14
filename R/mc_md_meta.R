#' Read YAML frontmatter from a markdown email draft
#'
#' Parses the YAML frontmatter block at the top of a markdown file and
#' returns it as a named list. Returns an empty list when the file has
#' no frontmatter.
#'
#' @param path Path to the markdown file.
#'
#' @return A named list of frontmatter fields.
#'
#' @examples
#' \dontrun{
#' mc_md_meta("communications/20260413_cindy_newsletter_draft.md")
#' }
#'
#' @importFrom chk chk_string
#' @export
mc_md_meta <- function(path) {
  chk::chk_string(path)
  parse_frontmatter(path)$meta
}
