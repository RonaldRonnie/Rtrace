# Escape text for safe embedding in HTML

Diagnostic `file`, `message`, and `suggestion` fields originate from
scanned source code (file paths, string literals quoted back into
messages), so they must be escaped before being embedded in a generated
HTML report — see
[SECURITY.md](https://github.com/rtrace-dev/rtrace/blob/main/SECURITY.md).

## Usage

``` r
html_escape(x)
```

## Arguments

- x:

  Character vector.

## Value

Character vector with `& < > " '` replaced by HTML entities.
