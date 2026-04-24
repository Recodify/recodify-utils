# ClickHouse Play Extremes Investigation

## Plan

1. Inspect `clickhouse/tools/play/play-26.html` for any default `extremes` setting, checkbox state, or request builder logic that injects `extremes=1`.
2. Trace referenced JavaScript helpers and query execution code to determine whether the UI adds `extremes` automatically or simply forwards query text/settings.
3. Summarize the exact reason `SETTINGS extremes = 1` is active for the provided repro and separate UI behaviour from the engine failure mechanism.
