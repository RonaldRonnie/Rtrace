# Register a rule in the global rule registry

Built-in rules call this at package load time. Third-party packages may
call the exported `rtrace::register_rule()` from their own `.onLoad()`
to add rules without forking RTrace (see ADR 0002's plugin-system
section).

## Usage

``` r
register_rule(rule)
```

## Arguments

- rule:

  A [Rule](https://ronaldronnie.github.io/Rtrace/reference/Rule.md)
  instance.

## Value

Invisibly, the rule id.
