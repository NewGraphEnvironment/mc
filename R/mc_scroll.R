#' Wrap a table in a scrollable container for email
#'
#' Wraps HTML table output in a `<div>` with `overflow` CSS so large
#' tables scroll horizontally, vertically, or both in Gmail.
#'
#' @param table A kable/kableExtra object or a character string of HTML.
#' @param direction Scroll direction: `"wide"` (horizontal), `"long"`
#'   (vertical), or `"both"`. Default `"both"`.
#' @param max_height Maximum height before vertical scrolling kicks in.
#'   Default `"400px"`. Ignored when `direction = "wide"`.
#'
#' @return A character string of HTML with the table inside a scrollable div.
#'
#' @examples
#' \dontrun{
#' df <- data.frame(x = 1:50, y = rnorm(50))
#'
#' # Vertical scroll
#' mc_scroll(knitr::kable(df, format = "html"), direction = "long")
#'
#' # Horizontal scroll
#' mc_scroll(knitr::kable(wide_df, format = "html"), direction = "wide")
#'
#' # Use with mc_compose
#' body <- mc_compose(
#'   "<p>Here's the data:</p>",
#'   mc_scroll(knitr::kable(df, format = "html"))
#' )
#' }
#'
#' @export
mc_scroll <- function(table, direction = "both", max_height = "400px") {
  chk::chk_string(direction)
  chk::chk_string(max_height)

  if (!direction %in% c("wide", "long", "both")) {
    stop('`direction` must be "wide", "long", or "both".', call. = FALSE)
  }

  # Convert kable objects to character
  if (inherits(table, c("knitr_kable", "kableExtra"))) {
    table <- as.character(table)
  }
  chk::chk_string(table)

  style <- switch(direction,
    wide = "overflow-x: auto; max-width: 100%;",
    long = paste0("overflow-y: auto; max-height: ", max_height, ";"),
    both = paste0("overflow: auto; max-height: ", max_height, "; max-width: 100%;")
  )

  paste0('<div style="', style, '">', table, "</div>")
}
