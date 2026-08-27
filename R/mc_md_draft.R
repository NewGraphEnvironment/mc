#' Create a Gmail draft from a markdown file with YAML frontmatter
#'
#' Reads metadata (`to`, `subject`, optional `cc`, `bcc`, `thread_id`,
#' `attachments`, `labels`, `from`) from the YAML frontmatter at the top of a
#' markdown draft and dispatches to [mc_draft()].
#'
#' Drafts only. Nothing passed here sends — use [mc_md_send()] to deliver.
#'
#' @inheritParams mc_md_send
#'
#' @return Invisibly returns whatever [mc_draft()] returns.
#'
#' @details
#' Required frontmatter fields: `to`, `subject`. Missing either triggers an
#' error that names the file.
#'
#' A `thread_id` in the frontmatter warns: `gmailr::gm_create_draft()` cannot
#' thread a draft. See [mc_draft()].
#'
#' @seealso [mc_md_send()] to send, [mc_draft()] for the argument-driven form.
#'
#' @examples
#' \dontrun{
#' mc_md_draft("communications/20260413_cindy_newsletter_draft.md")
#' }
#'
#' @importFrom chk chk_string chk_flag chk_list
#' @export
mc_md_draft <- function(path, to_self = FALSE, override = list()) {
  args <- md_dispatch_args(path, to_self = to_self, override = override)
  invisible(do.call(mc_draft, args))
}


#' Read frontmatter and assemble dispatch arguments (internal)
#'
#' Shared by [mc_md_draft()] and [mc_md_send()].
#'
#' @inheritParams mc_md_send
#' @return Named list of arguments for [mc_draft()] / [mc_send()].
#' @keywords internal
md_dispatch_args <- function(path, to_self = FALSE, override = list()) {
  chk::chk_string(path)
  chk::chk_flag(to_self)
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

  # yaml.load() returns list() for empty flow-style arrays (`labels: []`)
  # and for explicit nulls (`labels: ~`). Coerce to NULL so chk_null_or()
  # accepts these as "no labels" rather than rejecting list().
  meta_labels <- meta$labels
  if (is.list(meta_labels) && length(meta_labels) == 0) meta_labels <- NULL

  args <- list(
    path = path,
    to = meta$to,
    subject = meta$subject,
    cc = meta$cc,
    bcc = meta$bcc,
    thread_id = meta$thread_id,
    attachments = meta$attachments,
    labels = meta_labels,
    to_self = to_self
  )
  if (!is.null(meta$from)) args$from <- meta$from
  if (!is.null(meta$sig)) args$sig <- meta$sig
  if (!is.null(meta$sig_path)) args$sig_path <- meta$sig_path

  if ("path" %in% names(override)) {
    stop(
      "`override` cannot change `path` — frontmatter is already read from ",
      "the original file. Call the function on the new path instead.",
      call. = FALSE
    )
  }
  # `override` is a back door into the dispatch arguments, so dropping the
  # `draft`/`test` formals is not enough on its own — without this, a stale
  # `override = list(draft = FALSE)` would reach an unused-argument error that
  # never explains which function to call instead (#39).
  if ("draft" %in% names(override)) {
    stop(
      "`draft` is no longer an argument. Use mc_md_draft() to create a ",
      "draft, or mc_md_send() to send.",
      call. = FALSE
    )
  }
  if ("test" %in% names(override)) {
    stop(
      "`test` has been renamed to `to_self`.",
      call. = FALSE
    )
  }
  for (key in names(override)) args[[key]] <- override[[key]]

  args
}
