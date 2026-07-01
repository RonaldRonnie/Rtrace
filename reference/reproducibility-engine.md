# Reproducibility Engine

Evaluates how reproducible an R project is, producing a 0–100 score and
a set of diagnostics. The engine inspects both the static code (via the
existing `rtrace_context` AST analysis) and the project's file system
(renv.lock presence, DESCRIPTION fields, etc.).

## Details

The score is intended to be complementary to the architecture score
produced by the core RTrace engine: both live on the same 0–100 scale
and both feed into the Trace Platform's overall platform health score.
