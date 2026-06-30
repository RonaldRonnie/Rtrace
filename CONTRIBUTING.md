# Contributing to RTrace

Thank you for considering a contribution. RTrace follows a standard R
package development workflow.

## Development setup

```r
install.packages(c("devtools", "roxygen2", "testthat", "usethis", "yaml",
                    "cli", "R6", "rlang", "jsonlite", "rcmdcheck", "pkgdown"))
devtools::load_all()
devtools::test()
```

## Before opening a pull request

1. `devtools::document()` — regenerate `man/` and `NAMESPACE` from roxygen
   comments. Do not hand-edit `NAMESPACE` or files under `man/`.
2. `devtools::test()` — all tests must pass.
3. `devtools::check()` — should be free of errors and warnings; new NOTEs
   should be explained in the PR description.
4. Add a `NEWS.md` bullet under `# RTrace (development version)` describing
   the user-visible change.
5. If you added or changed a rule, update its entry in
   `dev/rules-reference.md` and add a fixture in
   `tests/testthat/fixtures/`.

## Adding a new built-in rule

See [dev/rule-authoring-guide.md](dev/rule-authoring-guide.md) for the
full walkthrough. In short:

1. Create `R/rule_<name>.R` defining an `R6::R6Class` rule and calling
   `register_rule()` at the bottom of the file.
2. Add `tests/testthat/test-rule-<name>.R` with at least one fixture that
   should trigger the rule and one that should not.
3. Document the rule's `type` key, parameters, and default severity in
   `dev/rules-reference.md`.

## Adding a new reporter

Implement a function matching `function(diagnostics, ...)` returning a
character string (or, for interactive reporters, writing to stdout), wire
it into the `--format` switch in `R/cli_commands.R`, and add
`tests/testthat/test-reporter-<name>.R`. See
[ADR 0002](dev/adr/0002-core-architecture.md#reporters-r-reporter_r) for the
reporter contract.

## Commit and PR style

* Keep commits small and focused; one logical change per commit.
* Write commit messages and PR titles in the imperative mood
  ("Add circular dependency rule", not "Added" or "Adding").
* Reference the relevant issue number where applicable.

## Code style

RTrace is, fittingly, linted with `lintr` and formatted with `styler` in CI
(see [ADR 0001](dev/adr/0001-rtrace-scope-and-positioning.md) for why
RTrace itself does not reimplement style linting). Run both locally before
pushing:

```r
styler::style_pkg()
lintr::lint_package()
```

## Reporting bugs / requesting features

Use the GitHub issue templates under `.github/ISSUE_TEMPLATE/`. Security
issues should follow [SECURITY.md](SECURITY.md) instead of a public issue.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).
