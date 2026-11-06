#' Preview composed HTML in a browser before sending
#'
#' Writes composed HTML to a local file and opens it in the default browser
#' so markdown rendering issues (mis-nested links, stray backticks,
#' unintended list formatting, signature layout) can be caught before
#' creating a Gmail draft.
#'
#' Accepts either a raw HTML string or a path to a `.md` draft. When a
#' `.md` path is passed, the frontmatter envelope (To / Cc / Subject /
#' Thread / Attachments) is rendered above the body so recipient or
#' subject mistakes are visible too.
#'
#' @param html Either a character string of HTML (e.g. from [mc_compose()])
#'   or a path to a `.md` draft file. A `.md` path is detected by the
#'   combination of `endsWith(x, ".md")` and `file.exists(x)`.
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
#' # From raw HTML
#' html <- mc_compose("communications/project/draft.md")
#' mc_preview(html)
#'
#' # Directly from a frontmattered .md — shows envelope above body
#' mc_preview("communications/20260413_cindy_newsletter_draft.md")
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

  if (endsWith(html, ".md") && file.exists(html)) {
    meta <- mc_md_meta(html)
    body <- preview_inline_images(mc_md_render(html), meta[["inline_images"]])
    html <- paste0(preview_header(meta), body)
  }

  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  writeLines(html, path)
  if (open) utils::browseURL(path)
  invisible(path)
}


#' Point `cid:` references at the image files, for a browser preview
#'
#' A browser cannot resolve `cid:`, so each reference to a frontmatter inline
#' image becomes a `file://` URL to the image itself. Only the references a
#' send checks are rewritten (`cid_walk()`), so the preview matches the email.
#' @param html Rendered body.
#' @param inline_images Frontmatter `inline_images` (named list or vector).
#' @return HTML with `cid:<name>` replaced where the image is known.
#' @noRd
preview_inline_images <- function(html, inline_images) {
  imgs <- unlist(inline_images)
  # The same references a send checks, and only those (cid_walk())
  cid_walk(html, replace = function(id) {
    if (!id %in% names(imgs) || !file.exists(imgs[[id]])) return(NA_character_)
    file_url(imgs[[id]])
  })$html
}


#' A file:// URL for a local path, percent-encoded (internal)
#'
#' Forward slashes on every platform and each path segment percent-encoded,
#' so a space, `#`, `?`, `%` or `"` in a name cannot change the URL or end the
#' attribute, and the result is safe as a regex replacement.
#' @param path Existing file path.
#' @return Character `file:///...` URL.
#' @noRd
file_url <- function(path) {
  p <- normalizePath(path, winslash = "/")
  segs <- strsplit(p, "/", fixed = TRUE)[[1]]
  drive <- grepl("^[A-Za-z]:$", segs)
  # repeated = TRUE: otherwise a segment already holding "%xx" is left whole
  segs[!drive] <- vapply(segs[!drive], utils::URLencode, "", reserved = TRUE, repeated = TRUE,
                         USE.NAMES = FALSE)
  out <- paste(segs, collapse = "/")
  paste0("file://", if (startsWith(out, "/")) "" else "/", out)
}


#' Build an HTML header table from frontmatter metadata
#'
#' Renders To / Cc / Bcc (if present) / Subject / Thread / Attachments /
#' Inline images (if present) as
#' a simple inline-styled table above the preview body.
#' @param meta Named list from [mc_md_meta()].
#' @return HTML string.
#' @noRd
preview_header <- function(meta) {
  dash <- "\u2014"
  fmt <- function(x) {
    if (is.null(x) || length(x) == 0) return(dash)
    paste(as.character(x), collapse = ", ")
  }
  rows <- list(
    c("To", fmt(meta[["to"]])),
    c("Cc", fmt(meta[["cc"]]))
  )
  if (!is.null(meta[["bcc"]])) rows[[length(rows) + 1]] <- c("Bcc", fmt(meta[["bcc"]]))
  rows <- c(rows, list(
    c("Subject", fmt(meta[["subject"]])),
    c("Thread", fmt(meta[["thread_id"]])),
    c("Attach", fmt(meta[["attachments"]]))
  ))
  imgs <- unlist(meta[["inline_images"]])
  if (length(imgs)) {
    rows[[length(rows) + 1]] <- c("Inline", fmt(paste0(names(imgs), ": ", imgs)))
  }
  row_html <- vapply(rows, function(r) {
    sprintf(
      paste0(
        '<tr>',
        '<th style="text-align:left; padding:4px 12px 4px 0; ',
        'color:#555; white-space:nowrap;">%s</th>',
        '<td style="padding:4px 0;">%s</td>',
        '</tr>'
      ),
      r[1], htmlEscape(r[2])
    )
  }, character(1))
  paste0(
    '<table style="border-collapse:collapse; margin-bottom:16px; ',
    'padding-bottom:12px; border-bottom:1px solid #ddd; ',
    'font-family:sans-serif; font-size:13px;">',
    paste(row_html, collapse = ""),
    '</table>'
  )
}


#' Minimal HTML escaping for preview header values
#' @noRd
htmlEscape <- function(x) {  # nolint: object_name_linter
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}
