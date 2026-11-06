#' Send an email from a markdown file with YAML frontmatter
#'
#' One-file workflow: reads metadata (`to`, `subject`, optional `cc`, `bcc`,
#' `thread_id`, `attachments`, `inline_images`, `labels`, `from`) from the YAML frontmatter at
#' the top of a markdown draft and dispatches to [mc_send()]. Lets callers
#' keep each logical email in a single `.md` file instead of splitting
#' subject, body, and recipients across a paired `.R` script.
#'
#' Sends. To produce a Gmail draft for review instead, use [mc_md_draft()].
#'
#' @param path Path to the markdown draft (with YAML frontmatter).
#' @param to_self Logical. If `TRUE`, address the message to the sender and
#'   drop `cc`, `bcc` and `thread_id`, so it reaches nobody else. Default
#'   `FALSE`. Caps the recipients; does not stop the send.
#' @param override Named list of arguments to override frontmatter values
#'   at call time (e.g. `list(subject = "New subject")`). Overrides merge
#'   **after** frontmatter, so `override` wins.
#'
#' @return Invisibly returns whatever [mc_send()] returns.
#'
#' @details
#' Required frontmatter fields: `to`, `subject`. Missing either triggers an
#' error that names the file.
#'
#' @seealso [mc_md_draft()] to draft from frontmatter, [mc_send()] for the
#'   argument-driven form.
#'
#' @examples
#' \dontrun{
#' mc_md_send("communications/20260413_cindy_newsletter_draft.md")
#'
#' # Check the rendering in a real inbox without involving anyone else
#' mc_md_send("communications/20260413_cindy_newsletter_draft.md",
#'            to_self = TRUE)
#' }
#'
#' @importFrom chk chk_string chk_flag chk_list
#' @export
mc_md_send <- function(path, to_self = FALSE, override = list()) {
  if ("draft_id" %in% names(override)) {
    stop(
      "`draft_id` replaces a draft, and mc_md_send() sends a new message. ",
      "Use mc_md_draft() to replace a draft.",
      call. = FALSE
    )
  }
  args <- md_dispatch_args(path, to_self = to_self, override = override)
  res <- do.call(mc_send, args)
  # mc never deletes a draft, so the file's draft is still in Gmail after the
  # send; say so, or it can be sent a second time by hand.
  draft_id <- mc_md_meta(path)[["draft_id"]]
  if (is.character(draft_id) && length(draft_id) == 1 && nzchar(draft_id)) {
    message("Draft ", draft_id, " from this file is still in Gmail. ",
            "mc does not delete drafts.")
  }
  invisible(res)
}
