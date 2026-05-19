#!/usr/bin/env bash
tfp_usage() {
    echo "Usage: tfp [--summary|-s] [--verbose|-v] [plan_with_summary]"
    echo "       source /path/to/tfp.sh"
    echo ""
    echo "A utility to run terraform plan with optional resource summary"
    echo ""
    echo "Options:"
    echo "  --summary, -s      Show summary of affected resources (default: true)"
    echo "  --verbose, -v      Show terraform plan output (default: hidden)"
    echo "  plan_with_summary  Whether to show summary (true/false, default: true)"
    echo ""
    echo "Examples:"
    echo "  tfp                # Run terraform plan with summary, hide output"
    echo "  tfp --summary      # Run terraform plan with summary, hide output"
    echo "  tfp --verbose      # Run terraform plan with summary, show output"
    echo "  tfp -v -s          # Run terraform plan with summary, show output"
    echo "  tfp true           # Run terraform plan with summary, hide output"
    echo "  tfp false          # Run terraform plan without summary, hide output"
    echo ""
    echo "Note: This script can be sourced in .bashrc or run directly"
    echo "      When sourced, it provides the 'tfp' function globally"
}

tfp() {(

    set -euo pipefail
    # Default values
    local show_summary="true"
    local verbose="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                tfp_usage
                return 0
                ;;
            -s|--summary)
                show_summary="true"
                shift
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            true|false)
                show_summary="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                tfp_usage
                return 1
                ;;
        esac
    done

    if [[ "$show_summary" == "true" ]]; then
        if [[ "$verbose" == "true" ]]; then
            terraform plan -out=plan.tfplan
        else
            terraform plan -out=plan.tfplan >/dev/null
        fi

     terraform show -json plan.tfplan | jq -r '
        .resource_changes[]
        | select(.change.actions != ["no-op"])
        | {
            address: .address,
            action: (
                if (.change.actions | sort) == ["create","delete"] then "replace"
                else .change.actions[0]
                end
            )
            }
        ' | jq -s '
            group_by(.action)
            | .[]
            | "# \(. [0].action)",
            (.[].address)
        '

        rm plan.tfplan
    else
        if [[ "$verbose" == "true" ]]; then
            terraform plan
        else
            terraform plan >/dev/null
        fi
    fi
)}

# If script is run directly (not sourced), execute the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    tfp "$@"
fi