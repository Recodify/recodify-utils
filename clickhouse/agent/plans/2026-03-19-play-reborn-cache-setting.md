# Play Reborn Query Cache Setting

## Goal

- Add an explicit UI setting in `tools/play/play-reborn.html` to control whether interactive execution writes results to the ClickHouse query cache for later download reuse.

## Approach

1. Add a checkbox to the existing download dropdown.
2. Persist the setting in `localStorage`.
3. Default the setting to off.
4. Gate the interactive `postImpl` query-cache parameters behind the setting.
5. Gate the download query-cache read settings behind the same setting.

## Expected Outcome

- Default behavior matches safe interactive querying.
- Users can opt into the cloud-oriented cache reuse workflow when they want it.
