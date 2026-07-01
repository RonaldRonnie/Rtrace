# Register a Trace Platform module

Called at package-load time by RTrace itself and by any future sibling
module (DataTrace, DocsTrace, PackageQA, etc.) that wants the platform
to know it is present.

## Usage

``` r
register_module(module)
```

## Arguments

- module:

  A named list with at minimum:

  - `id` Character scalar. Unique module id (e.g. `"rtrace"`).

  - `name` Character scalar. Human-readable name.

  - `version` Character scalar. Module version string.

  - `description` Character scalar. One-line description.

  - `scan_fn` Optional function `function(root, config)` that the
    platform's
    [`platform_scan()`](https://ronaldronnie.github.io/Rtrace/reference/platform_scan.md)
    calls to run the module.

  - `score_fn` Optional function `function(diagnostics)` returning a
    named list `list(score=, label=, breakdown=)`.

## Value

Invisibly the module id.
