# AI Recommendation Engine

Provider-agnostic recommendation layer that enriches diagnostics with
contextual explanations, impact assessments, and actionable fix
suggestions. The engine is designed so that the underlying AI provider
(Claude, GPT-4, a local model, or a deterministic rule-lookup table) can
be swapped without changing the recommendation API contract.

## Details

Today's implementation uses a comprehensive deterministic rule-lookup
table (no network calls, no API keys required) that covers all 16+
built-in rules plus the new platform module rules. Future provider
adapters can be registered via
[`register_recommendation_provider()`](https://ronaldronnie.github.io/Rtrace/reference/register_recommendation_provider.md).
