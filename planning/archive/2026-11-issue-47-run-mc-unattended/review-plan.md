# Plan review — #47 (Plan agent, delivered 2026-11-05 ~03:25Z, after Phases 1–4 had landed)

Written by the parent session from the agent's reply (the Plan type cannot write files). Disposition per finding:

| # | Category | Finding | Disposition |
|---|----------|---------|-------------|
| 1 | Blocker | `gargle::gargle_oauth_cache()` is `NA` in a fresh session, not a path; resolve as gargle does (`rappdirs::user_cache_dir("gargle")` for NA/TRUE, abort on FALSE) | Already in 6d629fb (`auth_cache_dir()`); adding a test for the unset option with rappdirs mocked |
| 2 | Gap | `gm_oauth_client()` is NULL in every fresh session; fallback `gm_default_oauth_client()` can be NULL too | Already aborts with an mc message in `auth_client_name()`; adding a test |
| 3 | Gap | Gargle cache is shared with other Google packages: narrow tokens by client id, so a mismatch names only same-id tokens | Taken |
| 4 | Gap | Local "no sender/credentials" run re-reads `~/.Renviron` and the gargle cache, so it does not reproduce CI | Taken: re-run with `R_ENVIRON_USER=/dev/null` and `gargle_oauth_cache = FALSE` |
| 5 | Gap | `test-mc_send.R` "caffeinate is not called when send_at is NULL" has no `from`, no `gm_send_message` mock and a `tryCatch`: empty on CI, can send a real email locally | Taken: mock the send, pass `from`, drop the `tryCatch` |
| 6 | Gap | `vignettes/tables-in-emails.Rmd` scheduled-send section uses callr handle methods (`proc$is_alive()`) | Taken |
| 7 | Gap | callr warning advises `scheduler = "auto"`, which errors where callr is now the fallback | Taken: reword |
| 8 | Assumption | A matching name is necessary, not sufficient: gargle's key also hashes scopes | Documented in `?mc_auth_check` |
| 9 | Assumption | Linux default `at` may be absent | Taken as a clear error from `schedule_at()` naming the fix; no silent fallback, since #8 decided Linux resolves to `at` |
| 10 | Ordering | Phase 4 should update the tests relying on the old default before the code change | Noted; both landed in one commit (2c8d9c2), no stray launchd jobs found |
