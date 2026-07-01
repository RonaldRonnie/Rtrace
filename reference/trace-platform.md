# Trace Platform — metadata, module registry, and environment

The Trace Platform treats RTrace as its first module. Additional modules
(DataTrace, DocsTrace, PackageQA, future language modules) register here
at load time via
[`register_module()`](https://ronaldronnie.github.io/Rtrace/reference/register_module.md),
giving the platform a unified view of every installed capability.
