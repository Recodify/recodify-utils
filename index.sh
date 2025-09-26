#!/bin/bash

# Recodify Utils - Source all tools

: "${RECODIFY_ROOT:?RECODIFY_ROOT not set}"

# devex
. "$RECODIFY_ROOT/devex/github/mkpr.sh"
. "$RECODIFY_ROOT/devex/claude/setup.sh"
. "$RECODIFY_ROOT/devex/claude/claude-run.sh"
#. "$RECODIFY_ROOT/devex/general/disable-capslock.sh"

# tools
. "$RECODIFY_ROOT/tools/mnt-forever.sh"
. "$RECODIFY_ROOT/tools/tx-benchmark.sh"


. "$RECODIFY_ROOT/infra/terraform/tfp.sh"
