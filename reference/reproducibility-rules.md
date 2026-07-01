# Reproducibility rules

Eight rules that catch the most common R reproducibility hazards. All
are prefixed `reproducibility.*` so the reproducibility engine can
batch-run them. Each is also independently usable in a standard
`rtrace.yml`.

## Details

Existing anti-pattern rules (`antipattern.setwd`,
`antipattern.hardcodedPath`, `antipattern.globalAssign`) already cover
some reproducibility concerns; these rules address the remaining
surface: dependency locking, random seeds, temp-file hygiene, external
downloads, environment variables, and session information.
