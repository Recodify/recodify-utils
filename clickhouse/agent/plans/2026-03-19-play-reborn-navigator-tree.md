# Play Reborn Navigator Tree Plan

## Goal

- Replace the current sidebar split between connection manager and separately opened schema explorer with a single navigator tree.

## Approach

1. Collapse the sidebar markup into one tree-oriented container.
2. Keep connection actions at the top level.
3. Render saved connections as tree nodes.
4. Auto-load schema for the active connection instead of requiring a separate explorer toggle.
5. Render databases under the active connection and keep lazy loading for tables and columns.
6. Reuse the existing table/column quick actions.
