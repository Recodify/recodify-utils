# ClickHouse Play Indentation Follow-up Plan

## Goal

Fix the remaining navigator header layout and child indentation issues in `clickhouse/tools/play/play-reborn.html`.

## Approach

1. Move section `+` / `-` controls into the section header bar, before the count.
2. Remove the extra wrapper layout that split the section header visually.
3. Reintroduce consistent indentation for section children.
4. Increase column-list indentation so expanded column names align under their parent row.
5. Verify with diff review and a JavaScript syntax parse without launching the page.
