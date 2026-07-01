# Render a diagnostic set as XML

Schema:

    <rtrace-report schemaVersion="1">
      <summary error="1" warning="2" info="0"/>
      <diagnostics>
        <diagnostic ruleId="..." severity="error" file="..." line="1" column="2">
          <message>...</message>
          <suggestion>...</suggestion>
        </diagnostic>
      </diagnostics>
    </rtrace-report>

`line`/`column` attributes are omitted when unknown. `<suggestion>` is
omitted when the diagnostic has none. Built with
[`xml2`](https://xml2.r-lib.org/), which handles attribute/text
escaping, so this reporter requires the `xml2` package (`Suggests`, not
a hard dependency — see [ADR
0002](https://github.com/rtrace-dev/rtrace/blob/main/dev/adr/0002-core-architecture.md)
on keeping the core dependency footprint light).

## Usage

``` r
reporter_xml(diagnostics)
```

## Arguments

- diagnostics:

  An `rtrace_diagnostic_set`.

## Value

Character scalar XML text.
