# Save Plan Command

## Usage
```
/save-plan <filename> "<content>"
```

## Description
Creates a structured plan document with checklist tracking in `.claude/plans/<filename>.md`. Useful for persisting any plan, checklist, or structured document for future reference and progress tracking.

## Examples

### Save a project plan
```
/save-plan migration "
# Database Migration Plan

## Phase 1 - Analysis
- [ ] Audit current schema
- [ ] Identify breaking changes
- [ ] Create migration scripts

## Phase 2 - Execution
- [ ] Test in dev environment
- [ ] Run migration in staging
- [ ] Validate data integrity
- [ ] Deploy to production
"
```

### Save a troubleshooting checklist
```
/save-plan debug-checklist "
# API Debugging Checklist

## Initial Checks
- [ ] Check service health endpoints
- [ ] Verify environment variables
- [ ] Review recent deployments
- [ ] Check error logs

## Deep Dive
- [ ] Trace request flow
- [ ] Check database connections
- [ ] Validate external integrations
- [ ] Review performance metrics
"
```

## Implementation
When this command is run, it should:
1. Create the `.claude/plans/` directory if it doesn't exist
2. Write the content to `.claude/plans/<filename>.md`
3. Add a timestamp to track when the plan was created
4. Confirm the plan was saved and show the file path

## File Structure
Plans are stored in:
```
.claude/
├── plans/
│   ├── <filename>.md
│   └── ...
└── commands/
    └── save-plan.md
```