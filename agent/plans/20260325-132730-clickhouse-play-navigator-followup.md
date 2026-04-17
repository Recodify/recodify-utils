# ClickHouse Play Navigator Follow-up Plan

## Goal

Fix the navigator regressions reported after tasks 5-9 and refine the hierarchy controls in `clickhouse/tools/play/play-reborn.html`.

## Approach

1. Fix the broken table/view section expander by persisting collapsed group state correctly.
2. Tighten navigator indentation so group headers and child rows align consistently.
3. Replace the table icon set with clearer small-scale glyphs and add distinct materialized-view treatment.
4. Add `+` / `-` controls to database and section headers, backed by persisted table expansion state.
5. Cache loaded column metadata so expanded rows can be restored efficiently after rerenders.
6. Verify with diff review and a JavaScript syntax parse without launching the page.
