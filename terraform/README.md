# tfp - Terraform Plan with Summary

A utility to run `terraform plan` with an optional resource summary that shows which resources will be affected, grouped by action type.

## Features

- Runs `terraform plan` with optional output suppression
- Provides a clean summary of affected resources grouped by action (create, update, delete, replace)
- Can be used as a standalone script or sourced for global function access
- Supports both verbose and quiet modes
- JSON parsing of terraform plan for accurate resource change detection

## Usage

```bash
# As standalone script
./tfp.sh [options]

# Or source into .bashrc for global 'tfp' command
source /path/to/recodify-utils/infra/terraform/tfp.sh
tfp [options]

Options:
  --summary, -s      Show summary of affected resources (default: true)
  --verbose, -v      Show terraform plan output (default: hidden)
  plan_with_summary  Whether to show summary (true/false, default: true)
  -h, --help         Show help message
```

## Example Commands

```bash
# Run terraform plan with summary, hide output (default behavior)
tfp

# Run terraform plan with summary and show verbose output
tfp --verbose
tfp -v

# Run terraform plan with summary, explicit
tfp --summary

# Run terraform plan without summary
tfp false

# Show help
tfp --help
```

## Example Output

When running with summary (default):

```
# create
aws_instance.web_server
aws_security_group.web_sg

# update
aws_route53_record.www

# delete
aws_s3_bucket.old_bucket

# replace
aws_launch_template.app_template
```

## How It Works

1. Runs `terraform plan -out=plan.tfplan` to generate a plan file
2. Uses `terraform show -json` to convert the plan to JSON format
3. Parses the JSON with `jq` to extract resource changes
4. Groups resources by action type (create, update, delete, replace)
5. Displays a clean summary organized by action
6. Cleans up temporary plan file

## Dependencies

- `terraform` - Terraform CLI
- `jq` - JSON processor for parsing terraform plan output

## Installation for Shell Integration

Add to your .bashrc or .zshrc:
```bash
source /path/to/recodify-utils/infra/terraform/tfp.sh
```

## Notes

- Requires `terraform` and `jq` to be installed
- Must be run in a directory containing Terraform configuration
- The script creates a temporary `plan.tfplan` file which is automatically cleaned up
- Replace actions are detected when a resource has both create and delete actions