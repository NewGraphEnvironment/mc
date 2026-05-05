#' Ensure Gmail user labels exist (create any missing)
#'
#' Looks up existing user labels via [gmailr::gm_labels()] and creates any
#' name in `label_names` that doesn't yet exist. No-op for labels already
#' present. System label names (INBOX, STARRED, etc.) are skipped — those
#' are built into Gmail and cannot be created. System-label match is
#' case-insensitive so `"Inbox"`, `"inbox"`, and `"INBOX"` are all skipped.
#'
#' @param label_names Character vector of Gmail label names to ensure exist.
#'
#' @return Invisibly returns `label_names`.
#'
#' @details
#' Useful for the YAML-driven label workflow in [mc_send()] / [mc_md_send()]:
#' new project tags can land in frontmatter without needing to be created
#' in the Gmail UI first. Also handy for seeding a project's full label set
#' up front.
#'
#' @examples
#' \dontrun{
#' # Tag-as-you-go: works even if "project-foo" doesn't exist yet
#' mc_label_ensure(c("project-foo", "urgent"))
#' mc_thread_modify("18171fb2cec08e9d", add = c("project-foo", "urgent"))
#'
#' # Seed a project's labels in one shot
#' mc_label_ensure(c("client/Acme", "client/Acme/in-flight",
#'                   "client/Acme/done"))
#' }
#'
#' @importFrom chk chk_character
#' @importFrom gmailr gm_create_label
#' @export
mc_label_ensure <- function(label_names) {
  chk::chk_character(label_names)
  if (length(label_names) == 0) return(invisible(label_names))

  existing <- fetch_user_labels()
  sys <- system_labels()
  is_system <- toupper(label_names) %in% sys
  candidates <- label_names[!is_system]
  to_create <- setdiff(candidates, names(existing))

  for (nm in to_create) {
    gmailr::gm_create_label(nm)
  }
  invisible(label_names)
}
