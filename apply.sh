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
# Required environment variables (set before running):
#   TF_VAR_tenancy_ocid     OCI tenancy OCID
#   TF_VAR_compartment_id   OCI compartment OCID
#   TF_VAR_region           OCI region (e.g., us-ashburn-1)
#   TF_VAR_ocir_username    OCIR Docker login (format: namespace/user@email)
#   TF_VAR_ocir_token       OCI auth token (create in Console: Identity → Auth Tokens)
# ================================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Environment validation
# ------------------------------------------------------------------------------

echo "NOTE: Running environment validation..."
./check_env.sh

# ------------------------------------------------------------------------------
# Phase 1: Deploy Functions, NoSQL, and API Gateway
# ------------------------------------------------------------------------------
# Terraform's null_resource builds and pushes the Docker image to OCIR as
# part of this apply before the Function resources are created.
# ------------------------------------------------------------------------------

echo "NOTE: Deploying Functions, NoSQL table, and API Gateway..."

cd 01-functions || {
  echo "ERROR: 01-functions directory missing."
  exit 1
}

terraform init
terraform apply -auto-approve

# Retrieve the API Gateway base URL from Terraform output.
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

# Substitute the API base URL into the HTML template.
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
