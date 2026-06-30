# Configuration Reference

RTrace is configured by a single YAML file, conventionally `rtrace.yml` at
the project root. `rtrace init` writes a starter copy from
[`inst/templates/rtrace.yml`](../inst/templates/rtrace.yml).

## Top-level keys

```yaml
version: 1

project: my-project

layers:
  analysis: ["analysis/**"]
  shiny: ["shiny/**", "app/**"]

exclude:
  - "data-raw/**"

rules:
  - type: antipattern.setwd
    enabled: true
    severity: error
```

| Key | Required | Type | Description |
|---|---|---|---|
| `version` | yes | integer | Config schema version. Currently always `1`. |
| `project` | no | string | A display name, used in CLI/report output. |
| `layers` | no | mapping | Layer name -> one or more glob patterns (relative to the project root). Used by `dependency.forbidden` and `dependency.circular`. Files matching no layer are placed in a synthetic `(unassigned)` layer. |
| `exclude` | no | list of strings | Glob patterns excluded from scanning, in addition to RTrace's built-in defaults (`.git/**`, `renv/**`, `packrat/**`, `man/**`, `*.Rcheck/**`, `docs/**`, `_book/**`, `.rtrace_cache/**`). |
| `rules` | no | list | Rule declarations (see below). Unset = no rules run. |

## Glob syntax

RTrace's globs support `*` (any characters except `/`), `**` (any
characters, including `/`), and `?` (a single character), matched against
POSIX-style relative paths. See [`glob_to_regex()`](../R/walker.R).

## Rule entries

Each entry under `rules:` declares one rule:

```yaml
- type: complexity.cyclomatic   # required: a known rule id
  enabled: true                 # optional, default true
  severity: warning             # optional: error | warning | info; defaults to the rule's own default
  max: 15                       # rule-specific parameters, if any
```

* `type` must be one of the ids returned by `rtrace list-rules` (validated
  by `rtrace validate`/`validate_config()` — unknown types are a hard
  error, not a silently-ignored typo).
* `enabled` defaults to `true` if omitted.
* `severity` overrides the rule's own default severity for this project. If
  omitted, the rule's default is used (see
  [Rules Reference](rules-reference.md) for each rule's default).
* All other keys on the entry become that rule's `params` (e.g. `max`,
  `dirs`, `from`, `to`). See [Rules Reference](rules-reference.md) for what
  each rule accepts.

Some rules express one relationship per entry — for example,
`dependency.forbidden` takes a single `from`/`to` pair. Declare it multiple
times for multiple forbidden pairs:

```yaml
rules:
  - type: dependency.forbidden
    from: analysis
    to: shiny
  - type: dependency.forbidden
    from: shiny
    to: data-raw
```

## Defaults

If no `rtrace.yml` is found and none is passed via `--config`, RTrace uses
[`default_config()`](../R/config.R): no layers (so layer-based rules are
inactive), and a baseline rule set with sensible default
severities/thresholds — see that function's source for the exact list.

## Validating configuration

```sh
rtrace validate .
```

runs [`validate_config()`](../R/config.R) without performing a scan: it
checks `version` is present, `layers` are named, every `rules[].type` is
registered, and every `severity` is one of `error`/`warning`/`info`.
Unknown *top-level* keys produce a warning (forward-compatible); unknown
rule `type` values are a hard error.
