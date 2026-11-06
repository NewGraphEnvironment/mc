#' Create a Gmail draft from a markdown file with YAML frontmatter
#'
#' Reads metadata (`to`, `subject`, optional `cc`, `bcc`, `thread_id`,
#' `draft_id`, `attachments`, `inline_images`, `labels`, `from`) from the YAML
#' frontmatter at the top of a markdown draft and dispatches to [mc_draft()].
#'
#' Drafts only. Nothing passed here sends — use [mc_md_send()] to deliver.
#'
#' @inheritParams mc_md_send
#'
#' @return Invisibly returns what [mc_draft()] returns: a list with
#'   `draft_id`, `thread_id` and `message_id`.
#'
#' @details
#' Required frontmatter fields: `to`, `subject`. Missing either triggers an
#' error that names the file.
#'
#' The file keeps track of its own draft. When a draft is created, its id is
#' written into the frontmatter as `draft_id:` (that one line is added or
#' changed; the rest of the file is left as it was). Running the same file
#' again replaces that draft in place, and only that draft. If the draft has
#' since been sent or deleted, a new one is created and its id written in.
#' Delete the `draft_id:` line to start a fresh draft. Replacing overwrites
#' the draft as it stands in Gmail, including any edits made there.
#'
#' With `to_self = TRUE` the draft is a separate test copy: the file's
#' `draft_id` is not used and the copy's id is not recorded, so the tracked
#' draft is left alone. [mc_md_send()] ignores `draft_id`.
#'
#' A `thread_id` in the frontmatter creates the draft in that conversation.
#' See [mc_draft()].
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
  # Read here rather than in md_dispatch_args(), which mc_md_send() shares:
  # a send has no draft to replace.
  file_id <- mc_md_meta(path)$draft_id
  if (identical(file_id, "")) file_id <- NULL
  # A to_self draft is a test copy, never the file's tracked draft: it neither
  # replaces that draft nor is recorded in its place. Read from args, after
  # override, which can set to_self too.
  test_copy <- isTRUE(args$to_self)
  if (is.null(args$draft_id) && !test_copy) args$draft_id <- file_id
  res <- do.call(mc_draft, args)
  new_id <- res$draft_id
  if (!test_copy && is.character(new_id) && length(new_id) == 1 &&
        nzchar(new_id) && !identical(new_id, file_id)) {
    # The draft exists by now, so a failed write warns rather than errors:
    # the caller still gets the id, and the warning carries it.
    tryCatch(
      {
        frontmatter_set(path, "draft_id", new_id)
        message("Recorded draft_id ", new_id, " in ", path)
      },
      error = function(e) {
        warning(
          "Draft ", new_id, " created, but its id was not recorded in ",
          path, ": ", conditionMessage(e), call. = FALSE
        )
      }
    )
  }
  invisible(res)
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
    inline_images = if (is.null(meta$inline_images)) NULL else unlist(meta$inline_images),
    labels = meta_labels,
    to_self = to_self
  )
  if (!is.null(meta$from)) args$from <- meta$from
  if (!is.null(meta$sig)) args$sig <- meta$sig
  if (!is.null(meta$sig_path)) args$sig_path <- meta$sig_path

  if ("path" %in% names(override)) {
    stop(
      "`override` cannot change `path` - frontmatter is already read from ",
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
