# Package setup tracking
# Run these interactively — they are NOT idempotent

# 1. Package scaffold
usethis::create_package(".")
usethis::use_mit_license("New Graph Environment Ltd.")

# 2. Testing
usethis::use_testthat(edition = 3)

# 3. Documentation site
usethis::use_pkgdown()
usethis::use_github_action("pkgdown")

# 4. Dev directory (self-referential)
usethis::use_directory("dev")

# 5. Dependencies
usethis::use_package("commonmark")
usethis::use_package("gmailr")

# 6. Tests
usethis::use_test("mc_sig")
usethis::use_test("mc_md_render")
usethis::use_test("mc_send")

# 7. Build
devtools::document()
devtools::test()
devtools::check()
