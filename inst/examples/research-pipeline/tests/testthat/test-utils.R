test_that("celsius_to_fahrenheit converts correctly", {
  expect_equal(celsius_to_fahrenheit(0), 32)
})

test_that("robust_mean trims outliers", {
  expect_equal(robust_mean(c(1, 2, 3, 100)), mean(c(1, 2, 3, 100), trim = 0.1, na.rm = TRUE))
})
