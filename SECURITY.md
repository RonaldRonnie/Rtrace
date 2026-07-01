# Security Policy

## Supported Versions

RTrace is pre-1.0. Security fixes are applied to the latest released
minor version and to the development branch (`main`). There is no
long-term support branch until 1.0.0 ships.

| Version              | Supported |
|----------------------|-----------|
| latest release       | yes       |
| development (`main`) | yes       |
| older releases       | no        |

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security
vulnerabilities.

Instead, email `security@rtrace.dev` with:

- a description of the issue and its potential impact,
- steps to reproduce (a minimal R project/config that triggers it),
- the RTrace version (`rtrace::rtrace_version()`) and R version
  (`R.version.string`) you tested against.

You should receive an acknowledgment within 5 business days. We will
work with you to validate, fix, and coordinate disclosure before any
public announcement.

## Scope Notes

RTrace parses and statically analyzes R source files; it does not
execute the R code it scans. The primary security surface is:

- **Configuration parsing** (`rtrace.yml`) — handled via
  [`yaml::read_yaml()`](https://yaml.r-lib.org/reference/read_yaml.html)
  with `eval.expr = FALSE` to avoid executing arbitrary R code embedded
  in configuration files.
- **Report rendering** — HTML/Markdown reporters must escape file paths
  and diagnostic messages that originate from scanned source code before
  embedding them in generated reports, to avoid injection when reports
  are viewed in a browser or rendered in CI dashboards.

If you find a case where RTrace executes code from a scanned project
rather than only parsing it, that is a vulnerability and should be
reported via the process above.
