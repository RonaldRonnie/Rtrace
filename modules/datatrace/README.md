# DataTrace — Trace Platform Module 2

**Research Dataset Quality and FAIR Compliance**

DataTrace evaluates the quality of tabular research datasets (CSV, TSV,
Excel, Parquet) stored in a project. It ships as built-in rules within the
RTrace package (prefixed `datatrace.*`) and will eventually graduate into a
standalone package for teams that need dataset governance independent of R
code analysis.

## Capabilities (v0.2.0)

| Check | Rule | Severity |
|-------|------|---------|
| Parse errors | `datatrace.readError` | error |
| Missing column headers | `datatrace.missingHeader` | warning |
| Encoding issues (non-UTF-8) | `datatrace.encodingIssue` | warning |
| No data files in data/ | `datatrace.noDataFiles` | info |
| Large uncompressed CSV (>10 MB) | `datatrace.largeCsvNoCompression` | info |
| No data dictionary / codebook | `datatrace.schemaDocumentation` | info |
| Files outside data/ directory (FAIR: Findable) | `datatrace.fairFindable` | info |

## Planned Capabilities

- Excel file validation (.xlsx, .xls)
- Parquet / Arrow schema validation
- Duplicate row detection
- Schema drift detection across dataset versions
- Missing-value ratio analysis
- FAIR principle scoring (Findable, Accessible, Interoperable, Reusable)
- Data provenance tracking (via CSV lineage metadata)

## Running DataTrace

```r
library(RTrace)

# Standalone DataTrace scan
result <- run_datatrace_scan("path/to/project")
print(result$score)
print(result$data_files)   # data frame of found data files
reporter_console(result$diagnostics)

# As part of full platform scan
platform_result <- platform_scan("path/to/project")
```

## CLI

```sh
rtrace datatrace path/to/project
rtrace platform-scan path/to/project  # includes DataTrace
```
