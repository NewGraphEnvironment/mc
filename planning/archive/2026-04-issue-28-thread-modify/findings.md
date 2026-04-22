# Findings — mc_thread_modify()

## gmailr API (verified 2026-04-21)

### gm_modify_thread() — BROKEN in gmailr 3.0.0

```
gm_modify_thread(id, add_labels = character(0), remove_labels = character(0), user_id = "me")
```

Should accept label IDs and POST to `users.threads.modify`. In practice
every call returns HTTP 400 because the function source is:

```r
body <- rename(list(add_labels = add_labels, remove_labels = remove_labels))
req  <- POST(..., body = body, encode = "json", gm_token())
```

`rename()` expects `...` and renames via `name_map` (e.g., `add_labels` →
`addLabelIds`). Calling `rename(list(...))` passes the whole list as a
single positional arg — `rename()` doesn't recurse in, so the list is
stored under a key derived from deparsed call expression:

```
{"list(add_labels = add_labels, remove_labels = remove_labels)": {
    "add_labels": "STARRED", "remove_labels": []
}}
```

Gmail rejects the malformed envelope. Verified with direct httr POST
using the correct camelCase payload — Gmail accepts it and returns 200.

**Fix upstream:** replace `rename(list(...))` with `rename(...)`. Filed
as a gmailr issue.

**Workaround in mc:** `gmail_modify_thread()` internal helper POSTs
directly to `https://www.googleapis.com/gmail/v1/users/me/threads/{id}/modify`
using `httr::POST` + `gmailr::gm_token()`. Label IDs wrapped in
`as.list()` so `httr`'s `encode = "json"` (which uses `auto_unbox = TRUE`)
still serialises length-1 vectors as JSON arrays.

### gm_labels()

```
gm_labels(user_id = "me")
```

Returns `$labels` — a list of records with `id`, `name`, `type`
(`"system"` or `"user"`). System labels have `id == name` (INBOX, SENT,
UNREAD, STARRED, IMPORTANT, TRASH, SPAM, DRAFT, CHAT). User labels have
opaque IDs (`Label_7`) and display names.

## Design decisions

### Name resolution precedence

If a user creates a label named `"STARRED"` (unusual but possible),
prefer the **system interpretation**. System labels are documented and
stable; shadowing is almost always a mistake.

Resolver flow for each input name:
1. Match against system label list — return unchanged.
2. Look up in `gm_labels()` user labels — return `id`.
3. Not found → error with list of available user labels.

### Why names and not IDs

User-label IDs (`Label_47`) are opaque and tied to account state — not
portable, not meaningful. mc's point is reducing boilerplate, so
accepting names is the ergonomic win. Extra `gm_labels()` call is
cheap, and skipped entirely when every input is a system label.

### Error shape

```
Label(s) not found: "foo", "bar"
Available user labels: "Invoiced", "Archived", "Clients/Acme"
```

## Naming

`mc_thread_modify()` chosen over `mc_thread_label()` because the
function covers more than labeling in the colloquial sense:
- Archive: `remove = "INBOX"`
- Trash: `add = "TRASH"`
- Star: `add = "STARRED"`
- Mark read: `remove = "UNREAD"`

`_modify` matches both the Gmail API verb (`threads.modify`) and
gmailr's function name (`gm_modify_thread`).
