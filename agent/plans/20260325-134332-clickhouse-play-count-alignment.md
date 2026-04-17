# ClickHouse Play Count Alignment Plan

## Goal

Fix the remaining section-header count alignment issue in `clickhouse/tools/play/play-reborn.html`.

## Approach

1. Give the section count a fixed-width slot so digit-count changes do not shift the right edge.
2. Right-align the count text and use tabular numerals for more consistent visual spacing.
3. Verify with diff review and a JavaScript syntax parse without launching the page.
