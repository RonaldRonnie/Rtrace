# Package QA Engine

Evaluates an R package's metadata quality: DESCRIPTION completeness,
NAMESPACE hygiene, NEWS.md/ChangeLog, LICENSE presence, test coverage
scaffolding, and CRAN/Bioconductor convention compliance.

## Details

Only meaningful when run against an R package (a directory containing a
DESCRIPTION file). Non-package projects are skipped silently.
