# ClickHouse Play Section Controls Removal Plan

## Goal

Remove the section-level `+` / `−` controls from the navigator group headers and add clearer separation between database blocks in `clickhouse/tools/play/play-reborn.html`.

## Approach

1. Remove the group-header action controls from the `Tables` / `Views` / `Materialized Views` render path.
2. Keep the group count and collapse toggle intact.
3. Add a visual separator between sibling database sections using CSS rather than extra DOM.
4. Verify with diff review and a JavaScript syntax parse without launching the page.
