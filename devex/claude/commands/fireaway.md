---
name: fireaway
description: |
  calls a sequence of other custom claude commands
example: |
  /commit
  git push origin [current branch]
  /mkpr
```
---

## Rules

- DO NOT `git add`. Changes will have been staged already.
- DO NOT offer to add if no changes staged, abort.
- DO NOT push changes.
- DO NOT add attribution.
- DO NOT add co-author lines.
- DO only create the commit message based on the stages changes.
- DO NOT include details of changes that are not staged
