#' Send an email from a markdown file with YAML frontmatter
#'
#' One-file workflow: reads metadata (`to`, `subject`, optional `cc`, `bcc`,
#' `thread_id`, `attachments`, `labels`, `from`) from the YAML frontmatter at
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
  args <- md_dispatch_args(path, to_self = to_self, override = override)
  invisible(do.call(mc_send, args))
}
