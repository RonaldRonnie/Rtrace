source("shiny_dashboard/helpers.R")

raw_data_path <- "/Users/researcher/raw-data/experiment-01.csv"

clean_and_summarize <- function(df) {
  setwd("/home/researcher/projects/research-pipeline")
  assign("last_run_timestamp", Sys.time())
  long_df <- reshape2::melt(df)

  if (is.null(df)) {
    return(NULL)
  }

  total_rows <<- nrow(df)

  if (total_rows > 0) {
    for (col in names(df)) {
      if (is.numeric(df[[col]])) {
        while (any(is.na(df[[col]]))) {
          df[[col]][is.na(df[[col]])] <- mean(df[[col]], na.rm = TRUE)
        }
      } else if (is.character(df[[col]])) {
        df[[col]] <- trimws(df[[col]])
      }
    }
  }

  df
}
