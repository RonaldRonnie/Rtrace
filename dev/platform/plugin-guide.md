# Trace Platform — Plugin Development Guide

This guide explains how to build a plugin that adds new rules, or a full
new language module, to the Trace Platform.

---

## Quick Start: Adding a Custom Rule

```r
# Install RTrace
install.packages("RTrace")  # or devtools::install_github("rtrace-dev/rtrace")

# Create a custom rule in any R script
library(RTrace)

my_rule <- Rule$new(
  id               = "custom.noFoo",
  description      = "Flags calls to foo() which has been deprecated in our codebase.",
  default_severity = "warning",
  default_params   = list(),
  check_fn = function(context, params) {
    diags <- list()
    for (i in seq_len(nrow(context$files))) {
      hits <- find_calls(context$asts[[context$files$path[i]]], "foo")
      for (j in seq_len(nrow(hits))) {
        diags[[length(diags) + 1]] <- new_diagnostic(
          rule_id    = "custom.noFoo",
          severity   = "warning",
          file       = context$files$rel_path[i],
          line       = hits$line1[j],
          message    = "foo() is deprecated; use bar() instead.",
          suggestion = "Replace foo() with bar()."
        )
      }
    }
    diags
  }
)

register_rule(my_rule)

# Run a scan — your rule is now active
result <- run_scan("path/to/project")
reporter_console(result)
```

---

## Creating a Plugin Package

A plugin package lets you distribute custom rules to your team or publish
them for the R community.

### 1. Create the package

```r
usethis::create_package("myplugin")
```

### 2. Add the plugin DESCRIPTION field

```
Config/rtrace/plugin: true
```

This tells the Trace Platform's plugin discovery to load your package.

### 3. Register rules in `.onLoad()`

```r
# R/zzz.R
.onLoad <- function(libname, pkgname) {
  RTrace::register_rule(my_custom_rule_one())
  RTrace::register_rule(my_custom_rule_two())
}
```

### 4. Implement your rules

Follow the Rule authoring guide at `dev/rule-authoring-guide.md`.

### 5. Test with the platform

```r
library(myplugin)   # triggers .onLoad() → register_rule()
RTrace::list_rules()  # should include your rules
```

---

## Automatic Plugin Discovery

When the Trace Platform loads, it scans `.libPaths()` for packages with
`Config/rtrace/plugin: true` in their DESCRIPTION. This means your team
members don't need to manually load your plugin — installing the package
is enough.

```r
# Trigger discovery manually (also called at package load)
RTrace::discover_plugins(verbose = TRUE)
# [RTrace plugin] Loaded 'myplugin'

# List all installed plugins
RTrace::list_plugin_packages()
# [1] "myplugin"
```

To opt out of automatic discovery, set:
```
Config/rtrace/plugin: false
```

---

## Creating a Platform Module

A platform module goes further than a rule plugin: it registers a new
scanning engine (e.g., for a different language) that participates in
`platform_scan()` and appears in the dashboard.

```r
# In your module package's .onLoad()
.onLoad <- function(libname, pkgname) {
  # Register rules as usual
  RTrace::register_rule(my_language_rule_1())
  
  # Also register as a platform module
  RTrace::register_module(list(
    id          = "myplugin",
    name        = "My Language Module",
    version     = as.character(utils::packageVersion("myplugin")),
    description = "Static analysis for My Language.",
    languages   = c("mylang"),
    
    scan_fn = function(root, config) {
      # Run your analysis; return an rtrace_diagnostic_set
      my_scan(root)
    },
    
    score_fn = function(diagnostics) {
      RTrace::compute_score(diagnostics,
        error_penalty   = 10,
        warning_penalty = 3,
        info_penalty    = 1
      )
    }
  ))
}
```

### DESCRIPTION for a module package

```
Config/rtrace/plugin: true
Config/rtrace/module-id: myplugin
```

---

## Engine-Specific Rule Constructors

For rules that operate on data files, project metadata, or documentation
rather than R source code, use the engine-specific constructors:

```r
# DataTrace rule (receives a data_files data frame)
rule <- datatrace_rule(
  id               = "datatrace.myCheck",
  description      = "Flags...",
  default_severity = "warning",
  datatrace_fn = function(data_files, root, params) {
    # data_files: data.frame from scan_data_files()
    # Return list of rtrace_diagnostic
    list()
  }
)

# DocsTrace rule (receives the project root path)
rule <- docstrace_rule(
  id               = "docstrace.myCheck",
  description      = "Flags...",
  docstrace_fn = function(root, params) {
    list()
  }
)

# PackageQA rule (receives the project root path)
rule <- packageqa_rule(
  id               = "packageqa.myCheck",
  description      = "Flags...",
  packageqa_fn = function(root, params) {
    list()
  }
)
```

---

## Rule Naming Convention

| Prefix | Module | Example |
|--------|--------|---------|
| `structure.` | File structure | `structure.requiredDirs` |
| `dependency.` | Dependency graph | `dependency.circular` |
| `complexity.` | Code complexity | `complexity.cyclomatic` |
| `antipattern.` | Code anti-patterns | `antipattern.setwd` |
| `documentation.` | Roxygen2 docs | `documentation.missing` |
| `testing.` | Test suite | `testing.missingTests` |
| `package.` | Package conventions | `package.deprecatedApi` |
| `ecosystem.` | Framework-specific | `ecosystem.shinyStructure` |
| `reproducibility.` | Reproducibility | `reproducibility.renvLock` |
| `datatrace.` | Data quality | `datatrace.readError` |
| `docstrace.` | Doc quality | `docstrace.readme` |
| `packageqa.` | Package QA | `packageqa.licensePresent` |
| `custom.` | Your organization's rules | `custom.noFoo` |

---

## Adding a Recommendation

When your rule fires, the recommendation engine provides context to users.
Register a built-in recommendation by extending the provider's lookup table,
or use `register_recommendation_provider()` for a fully custom provider:

```r
# Custom static recommendations via a simple provider
register_recommendation_provider(
  id          = "myplugin-recs",
  description = "Recommendations for myplugin rules",
  provider_fn = function(diagnostic, context_hint = NULL) {
    if (diagnostic$rule_id == "custom.noFoo") {
      return(new_recommendation(
        rule_id    = "custom.noFoo",
        why        = "foo() was deprecated in our API v2.0.",
        impact     = "foo() will be removed in v3.0.",
        fix        = "Replace all foo() calls with bar().",
        references = c("https://internal-wiki.example.com/migration-guide"),
        priority   = "high"
      ))
    }
    # Fall back to built-in for other rules
    RTrace:::builtin_recommendation(diagnostic)
  }
)

set_recommendation_provider("myplugin-recs")
```

---

## Publishing Your Plugin

1. Build and check: `devtools::check()`
2. Publish on CRAN or GitHub
3. Announce in the Trace Platform community

Users install and discover automatically:
```r
install.packages("myplugin")
# Next time RTrace loads: [RTrace plugin] Loaded 'myplugin'
```
