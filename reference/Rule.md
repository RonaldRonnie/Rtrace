# Rule base class

Every built-in and third-party RTrace rule is an instance of this `R6`
class. See `vignette("rule-authoring-guide")` or
`dev/rule-authoring-guide.md` for a full walkthrough of writing a new
rule.

## Public fields

- `id`:

  Character scalar, unique rule identifier (e.g.
  `"complexity.cyclomatic"`). Used as the `type` key in `rtrace.yml`.

- `description`:

  Character scalar, one-line human-readable summary shown by
  `rtrace describe-rule`.

- `default_severity`:

  One of `"error"`, `"warning"`, `"info"`.

- `default_params`:

  Named list of default parameter values.

## Methods

### Public methods

- [`Rule$new()`](#method-Rule-initialize)

- [`Rule$check()`](#method-Rule-check)

- [`Rule$clone()`](#method-Rule-clone)

------------------------------------------------------------------------

### `Rule$new()`

#### Usage

    Rule$new(
      id,
      description,
      check_fn,
      default_severity = "warning",
      default_params = list()
    )

#### Arguments

- `id`:

  Rule id.

- `description`:

  One-line description.

- `check_fn`:

  A function `function(context, params)` returning a list of
  `rtrace_diagnostic` objects. Evaluate this rule against a context

- `default_severity`:

  Default severity.

- `default_params`:

  Default parameters.

------------------------------------------------------------------------

### `Rule$check()`

#### Usage

    Rule$check(context, params = self$default_params)

#### Arguments

- `context`:

  An `rtrace_context`.

- `params`:

  Named list of resolved parameters (defaults merged with any user
  overrides).

#### Returns

A list of `rtrace_diagnostic` objects.

------------------------------------------------------------------------

### `Rule$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Rule$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
