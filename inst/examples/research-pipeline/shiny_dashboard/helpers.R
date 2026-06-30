source("analysis/clean_data.R")
library(shiny)

format_summary_label <- function(n_rows, n_cols) {
  paste0(n_rows, " rows x ", n_cols, " cols")
}
