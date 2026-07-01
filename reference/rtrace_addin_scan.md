# RStudio Addin: scan the active project and view an HTML report

Detects the current RStudio project, runs a scan, writes an HTML report
(see
[`reporter_html()`](https://rtrace-dev.github.io/rtrace/reference/reporter_html.md))
to a temp file, and opens it in the RStudio Viewer pane — or the default
browser outside RStudio. Registered via `inst/rstudio/addins.dcf` as
"RTrace: Scan Project" in RStudio's Addins menu.

## Usage

``` r
rtrace_addin_scan()
```

## Value

Invisibly, the path to the generated HTML report.

## Details

The logic that matters (project-root detection, report-path selection,
running the scan and writing the report) is factored out into
independently-testable internal helpers in `R/addin.R`; this function
itself is a thin wrapper around them plus the final
[`rstudioapi::viewer()`](https://rstudio.github.io/rstudioapi/reference/viewer.html)/[`browseURL()`](https://rdrr.io/r/utils/browseURL.html)
call, which requires an interactive session and isn't exercised by the
automated test suite.
