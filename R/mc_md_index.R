#' Index markdown email drafts under a directory
#'
#' Scans a directory tree for markdown drafts matching `pattern` and returns
#' a data frame summarising their frontmatter. Turns a compost-style
#' `communications/` folder into a searchable archive without querying
#' Gmail.
#'
#' Files without YAML frontmatter are included with `NA` for all metadata
#' columns so missing drafts are visible in the index rather than hidden.
#'
#' @param dir Directory to scan. Defaults to `"communications"`.
#' @param pattern Regex matched against filename (not path). Default
#'   `"_draft\\.md$"` matches compost draft naming.
#' @param recursive Logical. Recurse into subdirectories? Default `TRUE`.
#'
#' @return A data frame with columns `path`, `date`, `to`, `cc`, `subject`,
#'   `thread_id`, `has_attachments`. `date` is parsed from an 8-digit
#'   `YYYYMMDD_` prefix in the basename when present, else `NA`. Multi-value
#'   fields (`to`, `cc`) are collapsed with `", "`.
#'
#' @examples
#' \dontrun{
#' mc_md_index("communications/")
#' mc_md_index() |> dplyr::filter(grepl("cindy", to))
#' }
#'
#' @importFrom chk chk_string chk_flag
#' @export
mc_md_index <- function(dir = "communications", pattern = "_draft\\.md$",
                        recursive = TRUE) {
  chk::chk_string(dir)
  chk::chk_string(pattern)
  chk::chk_flag(recursive)

  files <- list.files(dir, pattern = pattern, recursive = recursive,
                      full.names = TRUE)

  empty <- data.frame(
    path = character(0),
    date = as.Date(character(0)),
    to = character(0),
    cc = character(0),
    subject = character(0),
    thread_id = character(0),
    has_attachments = logical(0),
    stringsAsFactors = FALSE
  )
  if (length(files) == 0) return(empty)

  rows <- lapply(files, index_row)
  do.call(rbind, rows)
}


#' Build a one-row index data frame for a markdown draft
#' @noRd
index_row <- function(path) {
  meta <- tryCatch(
    mc_md_meta(path),
    error = function(e) {
      warning("Could not parse frontmatter in ", path, ": ",
              conditionMessage(e), call. = FALSE)
      list()
    }
  )
  date <- parse_filename_date(basename(path))
  collapse <- function(x) {
    if (is.null(x)) return(NA_character_)
    paste(as.character(x), collapse = ", ")
  }
  data.frame(
    path = path,
    date = date,
    to = collapse(meta$to),
    cc = collapse(meta$cc),
    subject = collapse(meta$subject),
    thread_id = collapse(meta$thread_id),
    has_attachments = !is.null(meta$attachments) && length(meta$attachments) > 0,
    stringsAsFactors = FALSE
  )
}


#' Parse leading YYYYMMDD from a filename
#' @noRd
parse_filename_date <- function(name) {
  m <- regmatches(name, regexpr("^[0-9]{8}", name))
  if (length(m) == 0) return(as.Date(NA))
  suppressWarnings(as.Date(m, format = "%Y%m%d"))
}
