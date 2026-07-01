# Trace Platform unified scoring system

Every Trace Platform module produces a `trace_score` – a 0-100 integer
derived from a weighted combination of rule violations and their
severities. This file defines the shared computation contract and
convenience constructors used by all modules.
