# DocsTrace — Trace Platform Module 3

**Documentation Quality Analysis**

DocsTrace evaluates the documentation quality of R projects and packages,
checking everything from README completeness to vignette coverage, pkgdown
configuration, example quality, citation files, and changelog presence.

## Capabilities (v0.2.0)

| Check | Rule | Severity |
|-------|------|---------|
| README missing | `docstrace.readme` | warning |
| README quality (sections, word count) | `docstrace.readmeQuality` | info |
| No vignettes | `docstrace.vignettes` | info |
| No pkgdown configuration | `docstrace.pkgdown` | info |
| Missing or empty `\examples` blocks | `docstrace.examplesQuality` | info |
| No NEWS.md / CHANGELOG | `docstrace.changelogPresent` | info |
| No CONTRIBUTING.md | `docstrace.contributingGuide` | info |
| No CITATION / CITATION.cff | `docstrace.citationFile` | info |

## Planned Capabilities

- Roxygen2 parameter completeness (`@param`, `@return` coverage)
- Quarto / R Markdown document structure validation
- Cross-reference validation (broken `[function()]` links)
- API documentation coverage percentage
- Screenshot/vignette freshness check

## Running DocsTrace

```r
library(RTrace)

result <- run_docstrace_scan("path/to/project")
print(result$score)
reporter_console(result$diagnostics)
```

## CLI

```sh
rtrace docstrace path/to/project
```
