---
name: commit
description: |
  Crafts a commit message and runs `git commit` against the current branch.
example: |
  git commit -m "Implement Lambda execution role assumption for integration tests \
    \
    - Added sts:AssumeRole permission for Lambda execution roles in bootstrap stack \
    - Added LambdaExecutionRoleArn output to app stack for workflow access \
    - Updated deploy workflow to assume Lambda execution role before running tests \
    - Tests now run with same DynamoDB permissions as production Lambda \
    - Ensures runtime permission validation and catches permission gaps \
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
