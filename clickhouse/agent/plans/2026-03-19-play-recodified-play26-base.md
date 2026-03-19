# Play Recodified Rewrite Plan

## Intent

- Rebuild `tools/play/play-recodified.html` from `tools/play/play-26.html` rather than from a bespoke rewrite.
- Preserve upstream structure and conventions where practical so a future PR back upstream remains realistic.
- Reintroduce the recodified features that still matter:
  - multi-statement execution
  - action/query history
  - tabbed multiple result sets
  - richer schema navigation
  - multiple saved connections in local storage

## Implementation Strategy

1. Reset `play-recodified.html` to the `play-26.html` baseline.
2. Identify the smallest upstream-friendly seams for extension:
   - connection inputs and menu/sidebar
   - query selection / execution flow
   - result rendering containers
   - history state management
3. Add localStorage-backed saved connections.
   - named connections
   - active connection selection
   - sync selected connection into existing URL/user/password inputs
4. Extend the existing database browser into a schema explorer.
   - keep databases/tables as the foundation
   - add grouping and lazy-loaded columns
   - add quick actions like insert/select/show
5. Port recodified multi-query support onto the `play-26` execution pipeline.
   - split selected text or full editor into statements
   - execute sequentially
   - isolate results per statement
   - preserve progress and cancellation semantics as far as practical
6. Add tabbed results and action history without breaking the upstream rendering model more than necessary.
7. Review the resulting diff for correctness without launching the page.

## Constraints

- Keep the file as a single self-contained HTML page.
- Avoid large stylistic departures from upstream unless needed for the new features.
- Favor code organization that could plausibly be proposed upstream later.
