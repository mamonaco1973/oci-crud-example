#!/bin/bash
# ================================================================================
# File: apply.sh
#
# Purpose:
#   Orchestrates end-to-end deployment of the Notes CRUD application on OCI.
#
#   Phase 1 (01-functions):
#     - Builds the Docker image for all five OCI Functions
#     - Pushes the image to OCI Container Registry (OCIR)
#     - Creates: VCN, NoSQL table, Functions Application, API Gateway, IAM
#
#   Phase 2 (02-webapp):
#     - Injects the API Gateway URL into the HTML template
#     - Uploads the static web UI to OCI Object Storage
#
# No environment variables are required.  Everything is derived automatically
# from ~/.oci/config and the OCI CLI.  An OCIR auth token is created on the
# first run and saved to ~/.oci/ocir_token for reuse on subsequent runs.
#
# Optional env var:
#   OCI_COMPARTMENT_ID  Defaults to tenancy OCID from ~/.oci/config when unset
# ================================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Environment validation
# ------------------------------------------------------------------------------

echo "NOTE: Running environment validation..."
./check_env.sh

# ------------------------------------------------------------------------------
# Derive OCI identifiers from ~/.oci/config
# ------------------------------------------------------------------------------

TENANCY_OCID=$(awk -F'=' '/^tenancy[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ~/.oci/config)
REGION=$(awk -F'=' '/^region[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ~/.oci/config)
USER_OCID=$(awk -F'=' '/^user[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ~/.oci/config)

# Compartment falls back to tenancy root when OCI_COMPARTMENT_ID is not set.
if [ -z "${OCI_COMPARTMENT_ID:-}" ]; then
  OCI_COMPARTMENT_ID="$TENANCY_OCID"
  echo "NOTE: OCI_COMPARTMENT_ID not set — using tenancy OCID as compartment."
fi

NAMESPACE=$(oci os ns get --query 'data' --raw-output)

# OCIR username: namespace/user-ocid (works for local and federated users).
OCIR_USERNAME="${NAMESPACE}/${USER_OCID}"
OCIR_HOST="${REGION}.ocir.io"

echo "NOTE: Region      - ${REGION}"
echo "NOTE: Namespace   - ${NAMESPACE}"
echo "NOTE: Compartment - ${OCI_COMPARTMENT_ID}"

# ------------------------------------------------------------------------------
# OCIR auth token — created once, cached in ~/.oci/ocir_token
# ------------------------------------------------------------------------------
# OCI auth tokens can only be read at creation time.  On first run this block
# creates one via the OCI CLI and writes it to the cache file.  Subsequent
# runs reuse the cached value.  If the cache is lost, delete the file and
# re-run; a new token will be created (max 2 tokens per user — old ones may
# need to be deleted first in the Console under Identity → Users → Auth Tokens).
# ------------------------------------------------------------------------------

TOKEN_FILE="${HOME}/.oci/ocir_token"

if [ -f "${TOKEN_FILE}" ] && [ -s "${TOKEN_FILE}" ]; then
  echo "NOTE: Using cached OCIR token from ${TOKEN_FILE}"
  OCIR_TOKEN=$(cat "${TOKEN_FILE}")
else
  echo "NOTE: No cached OCIR token found — creating one via OCI CLI..."
  OCIR_TOKEN=$(oci iam auth-token create \
    --user-id "${USER_OCID}" \
    --description "notes-crud-ocir" \
    --query 'data.token' \
    --raw-output)

  echo "${OCIR_TOKEN}" > "${TOKEN_FILE}"
  chmod 600 "${TOKEN_FILE}"
  echo "NOTE: OCIR token created and saved to ${TOKEN_FILE}"
fi

# Export as Terraform variables.
export TF_VAR_tenancy_ocid="$TENANCY_OCID"
export TF_VAR_compartment_id="$OCI_COMPARTMENT_ID"
export TF_VAR_region="$REGION"
export TF_VAR_ocir_username="$OCIR_USERNAME"
export TF_VAR_ocir_token="$OCIR_TOKEN"

# ------------------------------------------------------------------------------
# Phase 1: Deploy Functions, NoSQL, and API Gateway
# ------------------------------------------------------------------------------

echo "NOTE: Deploying Functions, NoSQL table, and API Gateway..."

cd 01-functions || {
  echo "ERROR: 01-functions directory missing."
  exit 1
}

terraform init
terraform apply -auto-approve

API_BASE=$(terraform output -raw api_gateway_endpoint)

cd ..

echo "NOTE: API Gateway endpoint - ${API_BASE}"

# ------------------------------------------------------------------------------
# Phase 2: Build and deploy the static web application
# ------------------------------------------------------------------------------

echo "NOTE: Building static web application..."

cd 02-webapp || {
  echo "ERROR: 02-webapp directory missing."
  exit 1
}

export API_BASE

envsubst '${API_BASE}' < index.html.tmpl > index.html || {
  echo "ERROR: Failed to generate index.html"
  exit 1
}

terraform init
terraform apply -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Post-deployment validation
# ------------------------------------------------------------------------------

echo "NOTE: Running post-deployment validation..."
./validate.sh

# ================================================================================
# End of script
# ================================================================================
