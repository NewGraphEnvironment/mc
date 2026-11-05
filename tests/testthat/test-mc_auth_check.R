# mc_auth_check() compares the OAuth client name stored in each cached token
# with the name this session computes. gargle derives that name from
# rlang::hash(), whose output changed in rlang 1.3.0, so an rlang upgrade leaves
# valid tokens that non-interactive auth can no longer find (#38).
#
# These tests write fake tokens (plain lists with the fields gargle stores) to a
# temp cache dir; no real credential is read.

local_token_cache <- function(tokens, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  for (file in names(tokens)) saveRDS(tokens[[file]], file.path(dir, file))
  dir
}

fake_token <- function(name, id = "gm-id", field = c("client", "app")) {
  field <- match.arg(field)
  if (field == "client") {
    list(client = list(name = name, id = id),
         app = list(appname = name, key = id))
  } else {
    list(app = list(appname = name, key = id))
  }
}

test_that("mc_auth_check passes when a cached token matches the session's client", {
  local_mocked_bindings(auth_client = function() list(name = "proj_new", id = "gm-id"), .package = "mc")
  cache <- local_token_cache(list(
    "aaa111_al@example.com" = fake_token("proj_new")
  ))
  expect_true(suppressMessages(mc_auth_check("al@example.com", cache = cache)))
})

test_that("mc_auth_check reads the name from a token stored with only $app", {
  local_mocked_bindings(auth_client = function() list(name = "proj_new", id = "gm-id"), .package = "mc")
  cache <- local_token_cache(list(
    "aaa111_al@example.com" = fake_token("proj_new", field = "app")
  ))
  expect_true(suppressMessages(mc_auth_check("al@example.com", cache = cache)))
})

test_that("mc_auth_check names both client names and the fix on a mismatch", {
  local_mocked_bindings(auth_client = function() list(name = "proj_new", id = "gm-id"), .package = "mc")
  cache <- local_token_cache(list(
    "aaa111_al@example.com" = fake_token("proj_old")
  ))
  err <- expect_error(mc_auth_check("al@example.com", cache = cache))
  expect_match(conditionMessage(err), "proj_old", fixed = TRUE)
  expect_match(conditionMessage(err), "proj_new", fixed = TRUE)
  expect_match(conditionMessage(err), "rlang", fixed = TRUE)
  expect_match(conditionMessage(err), "mc_auth(\"al@example.com\")", fixed = TRUE)
  expect_match(conditionMessage(err), "aaa111_al@example.com", fixed = TRUE)
})

test_that("mc_auth_check passes when any of several tokens for the email matches", {
  local_mocked_bindings(auth_client = function() list(name = "proj_new", id = "gm-id"), .package = "mc")
  cache <- local_token_cache(list(
    "aaa111_al@example.com" = fake_token("proj_old"),
    "bbb222_al@example.com" = fake_token("proj_new")
  ))
  expect_true(suppressMessages(mc_auth_check("al@example.com", cache = cache)))
})

test_that("mc_auth_check ignores tokens cached for other emails", {
  local_mocked_bindings(auth_client = function() list(name = "proj_new", id = "gm-id"), .package = "mc")
  cache <- local_token_cache(list(
    "aaa111_someone@example.com" = fake_token("proj_new"),
    "bbb222_xal@example.com" = fake_token("proj_new"),
    "ccc333_sales_al@example.com" = fake_token("proj_new")
  ))
  expect_error(
    mc_auth_check("al@example.com", cache = cache),
    "No cached gmailr token for al@example.com"
  )
})

test_that("mc_auth_check errors when the cache dir does not exist", {
  local_mocked_bindings(auth_client = function() list(name = "proj_new", id = "gm-id"), .package = "mc")
  missing_dir <- file.path(withr::local_tempdir(), "nope")
  expect_error(
    mc_auth_check("al@example.com", cache = missing_dir),
    "No token cache"
  )
})

test_that("mc_auth_check errors when gargle's token cache is turned off", {
  local_mocked_bindings(auth_client = function() list(name = "proj_new", id = "gm-id"), .package = "mc")
  withr::local_options(gargle_oauth_cache = FALSE)
  expect_error(mc_auth_check("al@example.com"), "caching is off")
})

test_that("mc_auth_check uses the gargle_oauth_cache option as the cache dir", {
  local_mocked_bindings(auth_client = function() list(name = "proj_new", id = "gm-id"), .package = "mc")
  cache <- local_token_cache(list(
    "aaa111_al@example.com" = fake_token("proj_new")
  ))
  withr::local_options(gargle_oauth_cache = cache)
  expect_true(suppressMessages(mc_auth_check("al@example.com")))
})

test_that("mc_auth_check validates its arguments", {
  expect_error(mc_auth_check(email = 1, cache = tempdir()))
  expect_error(mc_auth_check(email = "al@example.com", cache = 1))
})

test_that("mc_auth_check ignores tokens for the email minted under other clients", {
  local_mocked_bindings(
    auth_client = function() list(name = "proj_new", id = "gm-id"),
    .package = "mc"
  )
  cache <- local_token_cache(list(
    "aaa111_al@example.com" = fake_token("drive_client", id = "drive-id")
  ))
  expect_error(
    mc_auth_check("al@example.com", cache = cache),
    "No cached gmailr token for al@example.com"
  )
  # A stale gmailr token beside it: only the gmailr one is named
  cache <- local_token_cache(list(
    "aaa111_al@example.com" = fake_token("drive_client", id = "drive-id"),
    "bbb222_al@example.com" = fake_token("proj_old")
  ))
  err <- expect_error(mc_auth_check("al@example.com", cache = cache))
  expect_match(conditionMessage(err), "proj_old", fixed = TRUE)
  expect_no_match(conditionMessage(err), "drive_client", fixed = TRUE)
})

test_that("mc_auth_check reads gargle's default dir when the option is unset", {
  local_mocked_bindings(
    auth_client = function() list(name = "proj_new", id = "gm-id"),
    .package = "mc"
  )
  cache <- local_token_cache(list(
    "aaa111_al@example.com" = fake_token("proj_new")
  ))
  withr::local_options(gargle_oauth_cache = NULL)
  local_mocked_bindings(
    user_cache_dir = function(appname, ...) {
      if (identical(appname, "gargle")) cache else stop("unexpected appname")
    },
    .package = "rappdirs"
  )
  expect_true(suppressMessages(mc_auth_check("al@example.com")))
})

test_that("auth_client explains a missing OAuth client", {
  local_mocked_bindings(
    gm_oauth_client = function() NULL,
    gm_default_oauth_client = function() NULL,
    .package = "gmailr"
  )
  expect_error(mc:::auth_client(), "No OAuth client configured")
})
