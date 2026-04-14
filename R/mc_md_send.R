#' Send or draft an email from a markdown file with YAML frontmatter
#'
#' One-file workflow: reads metadata (`to`, `subject`, optional `cc`, `bcc`,
#' `thread_id`, `attachments`, `from`) from the YAML frontmatter at the top
#' of a markdown draft and dispatches to [mc_send()]. Lets callers keep each
#' logical email in a single `.md` file instead of splitting subject, body,
#' and recipients across a paired `.R` script.
#'
#' @param path Path to the markdown draft (with YAML frontmatter).
#' @param draft Logical. If `TRUE` (default), create a Gmail draft.
#' @param test Logical. Test mode — sends to self, strips cc/thread_id.
#' @param override Named list of arguments to override frontmatter values
#'   at call time (e.g. `list(draft = FALSE)` to send). Overrides merge
#'   **after** frontmatter, so `override` wins.
#'
#' @return Invisibly returns whatever [mc_send()] returns.
#'
#' @details
#' Required frontmatter fields: `to`, `subject`. Missing either triggers an
#' error that names the file.
#'
#' @examples
#' \dontrun{
#' # Draft from a frontmattered .md
#' mc_md_send("communications/20260413_cindy_newsletter_draft.md")
#'
#' # Send for real, overriding the default draft = TRUE
#' mc_md_send(
#'   "communications/20260413_cindy_newsletter_draft.md",
#'   override = list(draft = FALSE)
#' )
#' }
#'
#' @importFrom chk chk_string chk_flag chk_list
#' @export
mc_md_send <- function(path, draft = TRUE, test = FALSE, override = list()) {
  chk::chk_string(path)
  chk::chk_flag(draft)
  chk::chk_flag(test)
  chk::chk_list(override)

  meta <- mc_md_meta(path)

  required <- c("to", "subject")
  missing <- setdiff(required, names(meta))
  if (length(missing) > 0) {
    stop(
      "Missing required frontmatter field(s) in ", path, ": ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  args <- list(
    path = path,
    to = meta$to,
    subject = meta$subject,
    cc = meta$cc,
    bcc = meta$bcc,
    thread_id = meta$thread_id,
    attachments = meta$attachments,
    draft = draft,
    test = test
  )
  if (!is.null(meta$from)) args$from <- meta$from
  if (!is.null(meta$sig)) args$sig <- meta$sig
  if (!is.null(meta$sig_path)) args$sig_path <- meta$sig_path

  if ("path" %in% names(override)) {
    stop(
      "`override` cannot change `path` — frontmatter is already read from ",
      "the original file. Call mc_md_send() on the new path instead.",
      call. = FALSE
    )
  }
  for (key in names(override)) args[[key]] <- override[[key]]

  invisible(do.call(mc_send, args))
}
