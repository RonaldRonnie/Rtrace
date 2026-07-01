# JTrace — Future Trace Platform Module

**Architecture Governance for Java and Kotlin Projects**

JTrace is a planned Trace Platform module that will bring the same
architecture governance capabilities RTrace provides for R to Java and Kotlin
codebases. It will integrate with existing Java static analysis tools
(Checkstyle, SpotBugs, PMD, ArchUnit) and surface their findings as
`rtrace_diagnostic` objects so they appear in the unified platform dashboard
alongside R findings.

## Planned Architecture

```
JTrace
├── Source: Java / Kotlin source files
├── Tool integration:
│   ├── Checkstyle (style + convention)
│   ├── SpotBugs (bug patterns)
│   ├── PMD (code quality)
│   └── ArchUnit (architecture tests)
├── Converts findings → rtrace_diagnostic
└── Registers as Trace Platform module
```

## Interface Contract

See `/platform/interfaces/language_module_interface.md` for the full
contract. JTrace will implement:

```r
# In jtrace's .onLoad()
RTrace::register_module(list(
  id          = "jtrace",
  name        = "Architecture Governance (Java/Kotlin)",
  version     = "1.0.0",
  description = "Static analysis and architecture governance for Java/Kotlin projects.",
  languages   = c("java", "kotlin"),
  scan_fn     = jtrace::run_jtrace_scan,
  score_fn    = function(d) RTrace::compute_score(d, error_penalty = 10)
))
```

## Status

Planned. The interface contract and directory stub are in place so that
future development can proceed without redesigning the platform.

## Contributing

If you are interested in contributing JTrace, see
`/platform/interfaces/language_module_interface.md` and open an issue at
the Trace Platform repository.
