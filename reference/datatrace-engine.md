# DataTrace Engine

Evaluates the quality and FAIR-compliance of research datasets stored in
a project. Scans for CSV, TSV, and Excel files, inspects their headers,
checks for schema consistency across multiple files of the same type,
detects missing metadata, and assesses FAIR (Findable, Accessible,
Interoperable, Reusable) readiness.

## Details

Unlike the code-centric engines, DataTrace operates on tabular data
files rather than R source files — it uses only base R's
[`read.csv()`](https://rdrr.io/r/utils/read.table.html) for CSV handling
to avoid introducing heavy data-package dependencies.
