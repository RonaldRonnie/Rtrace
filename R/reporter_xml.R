#' Render a diagnostic set as XML
#'
#' Schema:
#' ```xml
#' <rtrace-report schemaVersion="1">
#'   <summary error="1" warning="2" info="0"/>
#'   <diagnostics>
#'     <diagnostic ruleId="..." severity="error" file="..." line="1" column="2">
#'       <message>...</message>
#'       <suggestion>...</suggestion>
#'     </diagnostic>
#'   </diagnostics>
#' </rtrace-report>
#' ```
#' `line`/`column` attributes are omitted when unknown. `<suggestion>` is
#' omitted when the diagnostic has none. Built with
#' [`xml2`](https://xml2.r-lib.org/), which handles attribute/text escaping,
#' so this reporter requires the `xml2` package (`Suggests`, not a hard
#' dependency — see [ADR 0002](https://github.com/rtrace-dev/rtrace/blob/main/dev/adr/0002-core-architecture.md)
#' on keeping the core dependency footprint light).
#'
#' @param diagnostics An `rtrace_diagnostic_set`.
#' @return Character scalar XML text.
#' @export
reporter_xml <- function(diagnostics) {
  stopifnot(inherits(diagnostics, "rtrace_diagnostic_set"))
  if (!requireNamespace("xml2", quietly = TRUE)) {
    rlang::abort("reporter_xml() requires the 'xml2' package. Install it with install.packages('xml2').")
  }

  s <- summary(diagnostics)
  doc <- xml2::xml_new_root("rtrace-report", schemaVersion = "1")

  summary_node <- xml2::xml_add_child(doc, "summary")
  xml2::xml_set_attr(summary_node, "error", as.character(s[["error"]]))
  xml2::xml_set_attr(summary_node, "warning", as.character(s[["warning"]]))
  xml2::xml_set_attr(summary_node, "info", as.character(s[["info"]]))

  diagnostics_node <- xml2::xml_add_child(doc, "diagnostics")
  for (d in diagnostics$diagnostics) {
    node <- xml2::xml_add_child(diagnostics_node, "diagnostic")
    xml2::xml_set_attr(node, "ruleId", d$rule_id)
    xml2::xml_set_attr(node, "severity", d$severity)
    xml2::xml_set_attr(node, "file", d$file)
    if (!is.na(d$line)) xml2::xml_set_attr(node, "line", as.character(d$line))
    if (!is.na(d$column)) xml2::xml_set_attr(node, "column", as.character(d$column))

    message_node <- xml2::xml_add_child(node, "message")
    xml2::xml_set_text(message_node, d$message)

    if (!is.null(d$suggestion) && nzchar(d$suggestion)) {
      suggestion_node <- xml2::xml_add_child(node, "suggestion")
      xml2::xml_set_text(suggestion_node, d$suggestion)
    }
  }

  as.character(doc)
}
