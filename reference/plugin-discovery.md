# Plugin Discovery System

Automatic plugin discovery was deferred from the 0.1.0 release (noted in
ADR 0002 and the roadmap). This module implements it: at package load
time (and on-demand via
[`discover_plugins()`](https://ronaldronnie.github.io/Rtrace/reference/discover_plugins.md))
the discovery system scans every installed package for a
`Config/rtrace/plugin` field in its DESCRIPTION file. When found, it
calls [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) on
that package, which triggers the package's own `.onLoad()` to
self-register its rules via the existing `rtrace::register_rule()` hook.

## Details

The same field name convention also applies to platform modules: a
package with `Config/rtrace/platform-module: true` in DESCRIPTION will
have its `register_platform_module()` (or equivalent) function called.
