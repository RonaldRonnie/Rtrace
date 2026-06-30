# CLI Reference

The CLI is a thin dispatcher ([`rtrace_cli()`](../R/cli_commands.R)) over
the same R functions available programmatically — every command composes
`resolve_config()` / `run_scan()` / a reporter, all of which are exported
and usable directly from R.

## Invocation

Once installed:

```sh
rtrace <command> [path] [--flag value ...]
```

Without a system-wide `rtrace` on `PATH` (e.g. running from a package
checkout):

```sh
Rscript -e 'RTrace::rtrace_cli(commandArgs(TRUE))' <command> [path] [--flag value ...]
```

`[path]` defaults to `.` for every command that accepts it.

## Commands

### `scan [path]`

Scans `path` and reports diagnostics.

| Flag | Default | Description |
|---|---|---|
| `--config <file>` | `<path>/rtrace.yml` if present, else built-in defaults | Use a specific config file. |
| `--format console\|json\|markdown\|sarif\|html\|csv\|xml` | `console` | Output format. `sarif` produces a SARIF 2.1.0 log suitable for GitHub code scanning upload; `html` is a standalone, dependency-free report; `xml` requires the `xml2` package. |
| `--output <file>` | stdout | Write the report to a file (ignored for `console`, which always writes to stdout). |
| `--fail-on error\|warning` | `error` | Severity threshold for a nonzero exit status. |
| `--cache` | off | Reuse a `.rtrace_cache/ast-cache.rds` AST cache from a prior run for files whose content hash hasn't changed, instead of re-parsing them. Only the parse step is cached — diagnostics are always recomputed for the full project, so results are identical with or without `--cache`. Off by default so a scan never writes files to your project directory unless you ask. See [ADR 0002](adr/0002-core-architecture.md). |

Exit status: `0` if no diagnostic at or above `--fail-on` was found, `1`
otherwise.

### `init [path]`

Writes a starter `rtrace.yml` to `path` (from
[`inst/templates/rtrace.yml`](../inst/templates/rtrace.yml)).

| Flag | Description |
|---|---|
| `--force` | Overwrite an existing `rtrace.yml`. Without it, `init` exits `1` if the file already exists. |

### `validate [path]`

Loads and [validates](configuration-reference.md#validating-configuration)
the configuration without scanning. Exits `1` and prints every problem
found if invalid.

| Flag | Description |
|---|---|
| `--config <file>` | Use a specific config file instead of `<path>/rtrace.yml`. |

### `list-rules`

Prints every registered rule: id, default severity, description.

### `describe-rule <id>`

Prints a single rule's id, description, default severity, and default
parameters. Exits `1` if `<id>` is not registered.

### `config [path]`

Prints the resolved configuration (after merging `rtrace.yml` with
defaults) and, for each declared rule, whether it's enabled and its
effective severity.

### `version`

Prints the installed RTrace version and the running R version.

### `help`

Prints command usage. Also shown for an unrecognized command (which exits
`1`) or no command at all (which exits `0`).

## Exit statuses at a glance

| Command | `0` means | `1` means |
|---|---|---|
| `scan` | no diagnostic at/above `--fail-on` | at least one such diagnostic, or a scan error |
| `init` | file written | file already exists (without `--force`) |
| `validate` | configuration valid | configuration invalid |
| `describe-rule` | rule found and printed | unknown rule id |
| everything else | command ran | unknown command |
