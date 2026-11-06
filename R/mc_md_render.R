#' Render a markdown draft to HTML email body
#'
#' Reads a markdown file, strips everything above the first `---` separator
#' (header metadata), converts the remaining markdown to HTML, inlines table
#' styles for Gmail compatibility, and appends the New Graph signature.
#'
#' @param path Path to the markdown draft file.
#' @param sig Logical. Append a signature? Default `TRUE`.
#' @param sig_path Path to a custom signature HTML file. Default `NULL`
#'   uses the bundled New Graph signature. Ignored when `sig = FALSE`.
#'
#' @return A character string of HTML ready for [mc_send()].
#'
#' @details
#' Gmail strips `<style>` blocks from HTML emails. This function adds inline
#' styles to `<table>`, `<th>`, and `<td>` elements so tables render correctly.
#'
#' Every link gets `target="_blank" rel="noopener noreferrer"`, so a reader
#' clicking it in webmail opens a new tab rather than leaving their inbox. A
#' link that already sets `target` or `rel` keeps its own value.
#'
#' The markdown file should follow the compost template format:
#'
#' ```
#' # Email to Recipient - Topic
#'
#' **Subject:** ...
#'
#' **To:** ...
#'
#' ---
#'
#' Hi Name,
#'
#' Body text here.
#' ```
#'
#' Everything above and including the `---` line is stripped. Everything below
#' is converted to HTML.
#'
#' @examples
#' \dontrun{
#' html <- mc_md_render("communications/20260222_brandon_cottonwood_draft.md")
#' cat(html)
#' }
#'
#' @importFrom chk chk_string chk_flag chk_null_or vld_string
#' @importFrom commonmark markdown_html
#' @export
mc_md_render <- function(path, sig = TRUE, sig_path = NULL) {
  chk::chk_string(path)
  chk::chk_flag(sig)
  chk::chk_null_or(sig_path, vld = chk::vld_string)
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }

  raw <- paste(readLines(path, warn = FALSE), collapse = "\n")

  # Strip header: everything up to and including the --- separator
  body_md <- strip_md_header(raw)

  # Convert markdown to HTML
  body_html <- commonmark::markdown_html(body_md, extensions = TRUE)

  # Inline table styles for Gmail compatibility, and links in a new tab
  body_html <- inline_table_styles(body_html)
  body_html <- inject_link_target(body_html)

  # Append signature

  if (sig) {
    body_html <- paste0(body_html, "\n", mc_sig(path = sig_path))
  }

  body_html
}


#' Strip the header above the first `---` separator in markdown
#'
#' Handles two header styles:
#' - YAML frontmatter: file starts with `---\n...\n---\n`. Strips through the
#'   closing `---\n`.
#' - Legacy compost template header: strips everything up to and including the
#'   first `---\n`.
#'
#' Used by both [mc_md_render()] and `resolve_part()` in [mc_compose()].
#' If no `---` is found, the full text is returned unchanged.
#' @param md Character string of raw markdown.
#' @return Markdown with header stripped.
#' @noRd
strip_md_header <- function(md) {
  if (grepl("^---\\s*\\n", md, perl = TRUE)) {
    # YAML frontmatter — strip opening `---` line through matching closing one
    return(sub("^---\\s*\\n[\\s\\S]*?\\n---\\s*\\n", "", md, perl = TRUE))
  }
  if (grepl("---", md, fixed = TRUE)) {
    sub("^[\\s\\S]*?---\\s*\\n", "", md, perl = TRUE)
  } else {
    md
  }
}


#' Parse YAML frontmatter from a markdown file
#'
#' Returns `list(meta = <named list>, body = <character>)`. When the file
#' has no YAML frontmatter, `meta` is an empty list and `body` is the full
#' file contents.
#'
#' @param path Path to the markdown file.
#' @return List with `meta` (named list) and `body` (character).
#' @noRd
parse_frontmatter <- function(path) {
  if (!file.exists(path)) stop("File not found: ", path, call. = FALSE)
  raw <- paste(readLines(path, warn = FALSE), collapse = "\n")
  m <- regmatches(
    raw,
    regexpr("^---\\s*\\n([\\s\\S]*?)\\n---\\s*(\\n|$)", raw, perl = TRUE)
  )
  if (length(m) == 0) {
    return(list(meta = list(), body = raw))
  }
  yaml_block <- sub("^---\\s*\\n([\\s\\S]*?)\\n---\\s*(\\n|$)", "\\1", m,
                    perl = TRUE)
  meta <- yaml::yaml.load(yaml_block)
  if (is.null(meta)) meta <- list()
  body <- sub("^---\\s*\\n[\\s\\S]*?\\n---\\s*(\\n|$)", "", raw, perl = TRUE)
  list(meta = meta, body = body)
}


#' Set one top-level key in a markdown file's YAML frontmatter (internal)
#'
#' Replaces the line `key: ...` in the frontmatter block, or adds it as the
#' block's first line (after the opening `---`, where it cannot fall inside a
#' block scalar that ends the block), and leaves every other byte of the file as it was
#' (line endings included). The block is the one `parse_frontmatter()` reads.
#' The file is written to a temporary file beside it and moved into place.
#'
#' @param path Path to the markdown file.
#' @param key Top-level key, e.g. `"draft_id"`.
#' @param value A string of letters, digits, `_` and `-`, written quoted.
#' @return `path`, invisibly.
#' @noRd
frontmatter_set <- function(path, key, value) {
  if (!grepl("^[A-Za-z0-9_-]+$", value)) {
    stop("Refusing to write ", key, " value '", value, "' to ", path, call. = FALSE)
  }
  # Write the file a symlink points to, not over the link: the rename below
  # replaces whatever sits at `path`.
  path <- normalizePath(path, mustWork = TRUE)
  txt <- rawToChar(readBin(path, "raw", file.size(path)))
  # The block parse_frontmatter() reads, with its line endings kept
  hit <- regmatches(txt, regexec(
    "^(---[ \\t]*\\r?\\n)([\\s\\S]*?)(\\r?\\n---[ \\t]*(?:\\r?\\n|$))([\\s\\S]*)$",
    txt, perl = TRUE, useBytes = TRUE
  ))[[1]]
  if (length(hit) == 0) {
    stop("No YAML frontmatter block found in ", path, call. = FALSE)
  }
  block <- hit[3]
  eol <- if (grepl("\\r\\n$", hit[2], useBytes = TRUE)) "\r\n" else "\n"
  line <- paste0(key, ': "', value, '"')
  pattern <- paste0("(?m)^", key, ":[^\\r\\n]*")
  n <- lengths(regmatches(block, gregexpr(pattern, block, perl = TRUE, useBytes = TRUE)))
  if (n > 1) stop("More than one `", key, ":` line in ", path, call. = FALSE)
  block <- if (n == 1) {
    sub(pattern, line, block, perl = TRUE, useBytes = TRUE)
  } else {
    paste0(line, eol, block)
  }
  tmp <- tempfile(tmpdir = dirname(path), fileext = ".md")
  writeBin(charToRaw(paste0(hit[2], block, hit[4], hit[5])), tmp)
  # Read the result back before it replaces the file: the key must read as the
  # value and every other key as it did. A block the line cannot be added to
  # (flow style, say) is refused and the file left alone.
  expected <- parse_frontmatter(path)$meta
  expected[[key]] <- value
  got <- tryCatch(parse_frontmatter(tmp)$meta, error = function(e) NULL)
  if (is.null(got) || !setequal(names(got), names(expected)) ||
        !identical(got[names(expected)], expected)) {
    unlink(tmp)
    stop("Writing `", key, ":` would not read back as written", call. = FALSE)
  }
  Sys.chmod(tmp, file.info(path)$mode)
  if (!file.rename(tmp, path)) {
    unlink(tmp)
    stop("Could not write ", path, call. = FALSE)
  }
  invisible(path)
}


#' Add inline styles to HTML tables for Gmail
#'
#' Gmail strips `<style>` blocks so table styling must be inline.
#' Handles bare tags (from commonmark), tags with attributes but no style
#' (commonmark's aligned cells, `<th align="left">`), and tags with an existing
#' `style` attribute (kable/kableExtra), whose declarations are kept after
#' ours. Each tag is matched once, so each declaration is written once, and a
#' tag that already starts with our declarations is left alone.
#'
#' @param html Character string of HTML.
#' @return HTML with inline table styles.
#' @noRd
inline_table_styles <- function(html) {
  cell_css <- "border: 1px solid #ddd; padding: 8px;"
  html <- style_tag(html, "table", "border-collapse: collapse; margin: 12px 0;")
  html <- style_tag(html, "th", cell_css)
  html <- style_tag(html, "td", cell_css)
  html
}


#' Put `css` first in the style of every `<tag>` (internal)
#'
#' @param html Character string of HTML.
#' @param tag Element name, lower case, e.g. `"td"`.
#' @param css Declarations to add.
#' @return HTML with each `<tag>` styled once.
#' @noRd
style_tag <- function(html, tag, css) {
  rewrite_start_tags(html, function(t, name) {
    if (name != tag) return(t)
    a <- tag_attrs(t)
    i <- match("style", a$name)
    if (is.na(i)) {
      return(sub("\\s*/?>$", paste0(' style="', css, '">'), t, perl = TRUE))
    }
    # Valueless (`style`, `style=`): replace the whole attribute
    if (is.na(a$vstart[i])) {
      return(paste0(substr(t, 1, a$astart[i] - 1), ' style="', css, '"',
                    substr(t, a$astart[i] + a$alen[i], nchar(t))))
    }
    if (startsWith(a$value[i], css)) return(t)
    # Rewrite the style value in place, quoted, our declarations first
    new <- paste0('"', css, if (nzchar(a$value[i])) " ", gsub('"', "&quot;", a$value[i], fixed = TRUE), '"')
    if (nzchar(a$quote[i]) && a$quote[i] == "'") {
      new <- paste0("'", css, if (nzchar(a$value[i])) " ", a$value[i], "'")
    }
    paste0(substr(t, 1, a$vstart[i] - 1), new, substr(t, a$vstart[i] + a$vlen[i], nchar(t)))
  })
}


#' Open every link in a new tab (internal)
#'
#' Adds `target="_blank"` and `rel="noopener noreferrer"` to each `<a>` tag
#' that has an `href`, leaving any `target` or `rel` it already sets. A link to
#' an anchor in the message (`href="#notes"`) is left alone.
#'
#' @param html Character string of HTML.
#' @return HTML with each link opening in a new tab.
#' @noRd
inject_link_target <- function(html) {
  rewrite_start_tags(html, function(t, name) {
    if (name != "a") return(t)
    a <- tag_attrs(t)
    href <- a$value[match("href", a$name)]
    # Not a link, or a link within the message, which stays in the message
    if (is.na(href) || startsWith(trimws(href), "#")) return(t)
    add <- c(
      if (!"target" %in% a$name) 'target="_blank"',
      if (!"rel" %in% a$name) 'rel="noopener noreferrer"'
    )
    if (length(add) == 0) return(t)
    sub("\\s*>$", paste0(" ", paste(add, collapse = " "), ">"), t, perl = TRUE)
  })
}


#' The grammar of one HTML attribute (internal)
#'
#' As an HTML reader tokenizes it: a name, which may contain a stray quote
#' (`pipe"`), then optionally `=` and a value. A quote starts a value only
#' after `=`. Shared by `start_tag_regex()` and `tag_attrs()`, so the two agree
#' about where every value ends.
#'
#' @param capture Capture the name (group 1) and raw value (group 2)?
#' @return A PCRE fragment.
#' @noRd
html_attr_regex <- function(capture = FALSE) {
  g <- if (capture) "(" else "(?:"
  paste0(g, "[^\\s/>=]++)(?:\\s*=\\s*", g, "\"[^\"]*\"|'[^']*'|[^\\s>]*))?")
}


#' A regex for any HTML start tag, outside comments and raw text (internal)
#'
#' Attributes are consumed by `html_attr_regex()`, so a `>` or a stray quote
#' inside a value (kableExtra writes tooltips unescaped) does not end the tag.
#' Comments, CDATA and the contents of `<script>` and `<style>` are skipped,
#' as a reader skips them. It matches every tag name, so a scan consumes each
#' tag whole and never reads markup inside another tag's value; pick a tag by
#' name afterwards, as `rewrite_start_tags()` does.
#'
#' @return A PCRE pattern matching one whole start tag.
#' @noRd
start_tag_regex <- function() {
  skip <- "(?:<!--.*?-->|<!\\[CDATA\\[.*?\\]\\]>|<(script|style)\\b.*?</\\1\\s*>)(*SKIP)(*FAIL)|"
  paste0("(?s)", skip, "<[A-Za-z][A-Za-z0-9-]*(?:\\s+", html_attr_regex(), ")*+\\s*/?>")
}


#' Rewrite each HTML start tag in turn (internal)
#'
#' The one walk over start tags, shared by the table styles, the link pass and
#' the cid reader, so all three see the same tags. A body that is not valid
#' UTF-8 (a latin1 signature, say) has its bad bytes replaced with `?` first;
#' otherwise the regex fails and the walk sees nothing.
#'
#' @param html Character string of HTML.
#' @param fun Function of the tag text and its lower-case name, returning the
#'   tag to put in its place.
#' @return HTML with each start tag replaced by `fun()`'s result.
#' @noRd
rewrite_start_tags <- function(html, fun) {
  if (!validUTF8(html)) html <- iconv(html, "UTF-8", "UTF-8", sub = "?")
  m <- gregexpr(start_tag_regex(), html, perl = TRUE)
  regmatches(html, m) <- lapply(regmatches(html, m), function(tags) {
    vapply(tags, function(t) {
      fun(t, tolower(regmatches(t, regexpr("(?<=^<)[A-Za-z][A-Za-z0-9-]*", t, perl = TRUE))))
    }, character(1), USE.NAMES = FALSE)
  })
  html
}


#' Read the attributes of one HTML start tag (internal)
#'
#' Tokenizes left to right, so a quoted value is consumed by the attribute it
#' belongs to and text inside it (`title="a style=b"`) is never read as an
#' attribute of its own.
#'
#' @param tag One start tag, e.g. `'<td align="left" style="x">'`.
#' @return Data frame: `name` (lower case), `value` (unquoted, `""` when
#'   absent), `quote` (`"\""`, `"'"` or `""`), `vstart`/`vlen`, the position
#'   and length of the raw value in `tag` (`NA` when there is none, as in
#'   `style` or `style=`), and `astart`/`alen`, the whole attribute with its
#'   leading space.
#' @noRd
tag_attrs <- function(tag) {
  body_start <- regexpr("^<[A-Za-z][A-Za-z0-9-]*", tag, perl = TRUE)
  offset <- attr(body_start, "match.length")
  rest <- substr(tag, offset + 1, nchar(tag))
  # \G: each attribute starts where the last one ended, as in start_tag_regex()
  m <- gregexpr(paste0("\\G\\s+", html_attr_regex(capture = TRUE)), rest, perl = TRUE)[[1]]
  empty <- data.frame(name = character(), value = character(), quote = character(),
                      vstart = integer(), vlen = integer(), astart = integer(), alen = integer())
  if (m[1] == -1) return(empty)
  cs <- attr(m, "capture.start")
  cl <- attr(m, "capture.length")
  name <- tolower(substring(rest, cs[, 1], cs[, 1] + cl[, 1] - 1))
  has_value <- cl[, 2] > 0
  raw <- ifelse(has_value, substring(rest, cs[, 2], cs[, 2] + cl[, 2] - 1), "")
  quote <- ifelse(grepl("^[\"']", raw) & nchar(raw) >= 2 & substr(raw, 1, 1) == substring(raw, nchar(raw)),
                  substr(raw, 1, 1), "")
  value <- ifelse(nzchar(quote), substr(raw, 2, nchar(raw) - 1), raw)
  data.frame(
    name = name, value = value, quote = quote,
    vstart = ifelse(has_value, cs[, 2] + offset, NA_integer_),
    vlen = ifelse(has_value, cl[, 2], NA_integer_),
    astart = as.integer(m) + offset, alen = attr(m, "match.length")
  )
}
