# Play Reborn Navigator Polish Plan

## Goal

- Improve the new navigator tree in `tools/play/play-reborn.html` with clearer action ownership, lighter styling, and collapsible tree behavior.

## Changes

1. Make navigator colors theme-aware so light and dark mode both remain readable.
2. Remove the redundant top-pane connection bar and move connection editing into the navigator itself.
3. Keep header controls minimal: icon-style `New` and refresh only.
4. Add expand/collapse toggles for connections and database nodes.
5. Persist tree expansion state and sidebar collapsed state in browser local storage.
6. Cache loaded tables per active connection so re-renders and filtering do not force repeated fetches.
7. Add connection-local menu actions and right-click support for edit/delete flows.
8. Replace destructive table clicks with explicit, non-destructive query insertion actions.
9. Replace the table action strip with a compact overflow menu, including a `Query log` action.
10. Move live connection status into a navigator footer and use double-click for column-name insertion.
11. Tighten navigator density by compacting connection summaries and constraining table/column overflow.
12. Clean up row alignment, spacing, and type hierarchy, remove the yellow progress styling, and add icons to the context menu.
13. Rename table menu items to `Generate ...`, add an `Insert INSERT` helper, and make the download cache toggle more visible inside the download dropdown.
14. Make `Insert INSERT` generate a column-populated template from `system.columns` and pin the navigator footer/status to the bottom of the sidebar.
15. Add `Generate SELECT count(*)` to the table context menu.
16. Hide table engines and column types by default, with a persisted navigator toggle to show them when needed.
17. Rebalance table and column row layout so names take precedence over metadata when space is tight.
18. Add a persisted horizontal resize handle for the navigator sidebar.

## Verification

- Static JavaScript syntax check only:
  `perl -0ne 'print $1 if /<script type="text\\/javascript">(.*)<\\/script>/s' tools/play/play-reborn.html | node --check`
