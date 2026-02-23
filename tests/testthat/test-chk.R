# Minimal tests that chk validation catches bad types

test_that("mc_sig rejects non-string path", {
  expect_error(mc_sig(path = 123))
  expect_error(mc_sig(path = TRUE))
})

test_that("mc_md_render rejects bad types", {
  expect_error(mc_md_render(path = 123))
  expect_error(mc_md_render(path = "file.md", sig = "yes"))
  expect_error(mc_md_render(path = "file.md", sig_path = 123))
})

test_that("mc_auth rejects non-string email", {
  expect_error(mc_auth(email = 123))
  expect_error(mc_auth(email = NULL))
})

test_that("mc_send rejects bad types", {
  expect_error(mc_send(path = 123, to = "a@b.com", subject = "hi"))
  expect_error(mc_send(path = "f.md", to = 123, subject = "hi"))
  expect_error(mc_send(path = "f.md", to = "a@b.com", subject = 123))
  expect_error(mc_send(path = "f.md", to = "a@b.com", subject = "hi", draft = "yes"))
  expect_error(mc_send(path = "f.md", to = "a@b.com", subject = "hi", cc = 123))
  expect_error(mc_send(path = "f.md", to = "a@b.com", subject = "hi", bcc = 123))
  expect_error(mc_send(path = "f.md", to = "a@b.com", subject = "hi", thread_id = 123))
})

test_that("mc_thread_find rejects bad types", {
  expect_error(mc_thread_find(query = 123))
  expect_error(mc_thread_find(query = "test", n = "five"))
})
