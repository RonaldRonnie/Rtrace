# Render a diagnostic set as colored console output

Render a diagnostic set as colored console output

## Usage

``` r
reporter_console(diagnostics, use_color = cli::num_ansi_colors() > 1)
```

## Arguments

- diagnostics:

  An `rtrace_diagnostic_set`.

- use_color:

  Logical; whether to use ANSI color. Defaults to
  `cli::num_ansi_colors() > 1`.

## Value

Invisibly, the character string written to the console.
