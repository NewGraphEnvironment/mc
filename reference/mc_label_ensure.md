# Ensure Gmail user labels exist (create any missing)

Looks up existing user labels via
[`gmailr::gm_labels()`](https://gmailr.r-lib.org/reference/gm_labels.html)
and creates any name in `label_names` that doesn't yet exist. No-op for
labels already present. System label names (INBOX, STARRED, etc.) are
skipped — those are built into Gmail and cannot be created. System-label
match is case-insensitive so `"Inbox"`, `"inbox"`, and `"INBOX"` are all
skipped.

## Usage

``` r
mc_label_ensure(label_names)
```

## Arguments

- label_names:

  Character vector of Gmail label names to ensure exist.

## Value

Invisibly returns `label_names`.

## Details

Useful for the YAML-driven label workflow in
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
/
[`mc_md_send()`](https://newgraphenvironment.github.io/mc/reference/mc_md_send.md):
new project tags can land in frontmatter without needing to be created
in the Gmail UI first. Also handy for seeding a project's full label set
up front.

## Examples

``` r
if (FALSE) { # \dontrun{
# Tag-as-you-go: works even if "project-foo" doesn't exist yet
mc_label_ensure(c("project-foo", "urgent"))
mc_thread_modify("18171fb2cec08e9d", add = c("project-foo", "urgent"))

# Seed a project's labels in one shot
mc_label_ensure(c("client/Acme", "client/Acme/in-flight",
                  "client/Acme/done"))
} # }
```
