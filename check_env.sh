#!/bin/bash
# ================================================================================
# File: check_env.sh
#
# Purpose:
#   Pre-flight validation.  Confirms all required tools and environment variables
#   are present before any infrastructure is created or destroyed.
#
# Required tools:
#   oci, terraform, docker, jq, envsubst
#
# Required environment variables:
#   TF_VAR_tenancy_ocid     OCI tenancy OCID
#   TF_VAR_compartment_id   OCI compartment OCID
#   TF_VAR_region           OCI region (e.g., us-ashburn-1)
#   TF_VAR_ocir_username    OCIR Docker login (namespace/user@email)
#   TF_VAR_ocir_token       OCI auth token (create in Console: Identity → Auth Tokens)
# ================================================================================

set -euo pipefail

all_ok=true

# ------------------------------------------------------------------------------
# Tool checks
# ------------------------------------------------------------------------------

echo "NOTE: Validating required commands..."

commands=("oci" "terraform" "docker" "jq" "envsubst")

for cmd in "${commands[@]}"; do
  if command -v "$cmd" &> /dev/null; then
    echo "NOTE: ${cmd} found."
  else
    echo "ERROR: ${cmd} is not in PATH."
    all_ok=false
  fi
done

# ------------------------------------------------------------------------------
# Environment variable checks
# ------------------------------------------------------------------------------

echo "NOTE: Validating required environment variables..."

vars=(
  "TF_VAR_tenancy_ocid"
  "TF_VAR_compartment_id"
  "TF_VAR_region"
  "TF_VAR_ocir_username"
  "TF_VAR_ocir_token"
)

for var in "${vars[@]}"; do
  if [[ -n "${!var:-}" ]]; then
    echo "NOTE: ${var} is set."
  else
    echo "ERROR: ${var} is not set."
    all_ok=false
  fi
done

if [[ "$all_ok" = false ]]; then
  echo "ERROR: One or more checks failed. Aborting."
  exit 1
fi

# ------------------------------------------------------------------------------
# OCI CLI connectivity check
# ------------------------------------------------------------------------------

echo "NOTE: Checking OCI CLI connection..."

oci iam compartment get \
  --compartment-id "${TF_VAR_compartment_id}" \
  --query 'data.name' \
  --raw-output > /dev/null

echo "NOTE: OCI CLI connection verified."
echo "NOTE: All environment checks passed."
