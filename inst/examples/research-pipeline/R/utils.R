#' Convert Celsius to Fahrenheit
#'
#' @param celsius Numeric vector of temperatures in Celsius.
#' @return Numeric vector of temperatures in Fahrenheit.
celsius_to_fahrenheit <- function(celsius) {
  celsius * 9 / 5 + 32
}

#' Compute a trimmed mean with a default trim fraction
#'
#' @param x Numeric vector.
#' @param trim Fraction to trim from each end. Default 0.1.
#' @return Numeric scalar.
robust_mean <- function(x, trim = 0.1) {
  mean(x, trim = trim, na.rm = TRUE)
}
