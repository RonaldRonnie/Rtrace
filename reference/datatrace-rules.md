# DataTrace rules

Rules for evaluating research dataset quality. All are prefixed
`datatrace.*`. They differ from the code-analysis rules in that their
`check_fn` receives a `data_files` data frame from
[`scan_data_files()`](https://ronaldronnie.github.io/Rtrace/reference/scan_data_files.md)
rather than an `rtrace_context` – they are run by the DataTrace engine,
not the standard rule engine.

## Details

For compatibility with the standard rule engine interface (which passes
an `rtrace_context`), DataTrace rules implement an additional
`check_datatrace(data_files, root)` method on the Rule object. The
standard `check(context, params)` is a no-op so that the rule can be
registered in the global registry without interfering with standard
scans.
