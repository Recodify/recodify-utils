# Restore Collapsed Table Default

## Plan

1. Inspect the play UI code that renders database tables and decides whether each table starts expanded or collapsed.
2. Patch the default state so tables render collapsed until explicitly opened, preserving lazy column loading behavior.
3. Review the affected code path for consistency and report the exact change made without running the app.
