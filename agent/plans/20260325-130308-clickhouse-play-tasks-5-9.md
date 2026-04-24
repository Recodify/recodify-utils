# ClickHouse Play Tasks 5-9 Plan

## Goal

Implement tasks 5 through 9 from `clickhouse/tools/play/tasks.md` in `clickhouse/tools/play/play-reborn.html`.

## Approach

1. Extend the table context menu with generated SQL helpers for column-list `SELECT` and `DROP TABLE`/`DROP VIEW`.
2. Extend the connection context menu with a dashboard shortcut derived from the connection URL.
3. Add explicit expand-all / collapse-all controls for the active connection in the navigator header.
4. Introduce persisted navigator state for collapsible table/view sections within each database.
5. Prettify the connection manager with stronger section headers and lightweight font-based icons for connection, database, table, and view items.
6. Review the diff and verify wiring without launching the page.
