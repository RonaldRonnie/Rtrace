# Construct a trace_recommendation

Construct a trace_recommendation

## Usage

``` r
new_recommendation(
  rule_id,
  why = NULL,
  impact = NULL,
  fix = NULL,
  examples = character(0),
  references = character(0),
  priority = c("medium", "high", "critical", "low"),
  provider = "builtin"
)
```

## Arguments

- rule_id:

  Character scalar rule id.

- why:

  Character scalar; why this violation matters.

- impact:

  Character scalar; what can go wrong if ignored.

- fix:

  Character scalar; recommended remediation.

- examples:

  Character vector; one or more concrete code examples.

- references:

  Character vector; URLs to documentation or best-practice guides.

- priority:

  One of `"critical"`, `"high"`, `"medium"`, `"low"`.

- provider:

  Character scalar; which provider generated this.

## Value

A `trace_recommendation` object.
