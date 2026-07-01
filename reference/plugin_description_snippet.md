# Generate a DESCRIPTION snippet for a plugin package

Helper for plugin package authors: returns the DESCRIPTION field lines
that register a package as an RTrace plugin.

## Usage

``` r
plugin_description_snippet(module_id = NULL)
```

## Arguments

- module_id:

  Optional character scalar; if provided, also registers as a platform
  module with this id.

## Value

Character scalar of DESCRIPTION lines to add.
