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

If `devtools` itself won't install in your environment (it pulls in `fs`
>= 2.1.0, which needs `libuv`, which needs `cmake` — a real, fairly common
sandboxed-environment limitation, not specific to this package), the
pieces it wraps work fine installed individually and used directly — this
is how the package was developed in such an environment:

```r
install.packages(c("roxygen2", "testthat", "rcmdcheck", "pkgdown",
                    "yaml", "cli", "R6", "rlang", "jsonlite"))
pkgload::load_all()                                  # instead of devtools::load_all()
roxygen2::roxygenise()                                # instead of devtools::document()
testthat::test_dir("tests/testthat")                  # instead of devtools::test()
rcmdcheck::rcmdcheck(args = "--no-manual")             # instead of devtools::check()
```

## Before opening a pull request

1. `devtools::document()` (or `roxygen2::roxygenise()`) — regenerate `man/`
   and `NAMESPACE` from roxygen comments. Do not hand-edit `NAMESPACE` or
   files under `man/`.
2. `devtools::test()` (or `testthat::test_dir("tests/testthat")`) — all
   tests must pass.
3. `devtools::check()` (or `rcmdcheck::rcmdcheck()`) — should be free of
   errors and warnings; new NOTEs should be explained in the PR
   description.
4. Add a `NEWS.md` bullet under the current development-version heading
   describing the user-visible change.
5. If you added or changed a rule, update its entry in
   `dev/rules-reference.md` and add positive/negative fixtures to
   `tests/testthat/test-rules-builtin.R`.

## Adding a new built-in rule

See [dev/rule-authoring-guide.md](dev/rule-authoring-guide.md) for the
full walkthrough, including why rules are registered centrally rather
than via a top-level `register_rule()` call in each rule's own file. In
short:

1. Create `R/rules_<category>.R` with a `rule_<name>()` constructor
   function that returns a `Rule` instance — it does **not** call
   `register_rule()` itself.
2. Add `register_rule(rule_<name>())` to `.onLoad()` in `R/zzz.R`.
3. Add it to [`inst/templates/rtrace.yml`](inst/templates/rtrace.yml) and
   document it in `dev/rules-reference.md`.
4. Add test cases to `tests/testthat/test-rules-builtin.R`: at least one
   fixture that should trigger the rule and one that should not.

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
