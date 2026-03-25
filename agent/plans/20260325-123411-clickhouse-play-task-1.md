# ClickHouse Play Task 1 Plan

## Goal

Make the active connection clearer in `clickhouse/tools/play/play-reborn.html` while working with a query.

## Approach

1. Inspect the existing connection-selection UI and active-connection state handling.
2. Add a more explicit active-connection indicator in the main work area near the query editor.
3. Strengthen the selected connection affordance in the navigator so the active row is obvious at a glance.
4. Keep the change lightweight by reusing existing connection state and summary formatting.
5. Verify by reviewing the diff and checking the updated markup, styles, and state wiring without running the app.
