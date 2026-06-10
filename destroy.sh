#!/bin/bash
# ================================================================================
# File: destroy.sh
#
# Purpose:
#   Tears down the Notes application stack deployed by apply.sh.
#   Destroys resources in reverse order: web app first, then backend.
#
#   Note: The OCIR container repository cannot be deleted by Terraform while
#   images exist in it.  This script purges all images from the repo before
#   running terraform destroy to avoid a dependency error.
#
# No environment variables required — all values derived from ~/.oci/config.
# ================================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Derive OCI identifiers (same logic as apply.sh)
# ------------------------------------------------------------------------------

TENANCY_OCID=$(awk -F'=' '/^tenancy[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ~/.oci/config)
REGION=$(awk -F'=' '/^region[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ~/.oci/config)
USER_OCID=$(awk -F'=' '/^user[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ~/.oci/config)

if [ -z "${OCI_COMPARTMENT_ID:-}" ]; then
  OCI_COMPARTMENT_ID="$TENANCY_OCID"
fi

NAMESPACE=$(oci os ns get --query 'data' --raw-output)
OCIR_USERNAME="${NAMESPACE}/${USER_OCID}"

# Read cached OCIR token — needed by Terraform variables even during destroy.
TOKEN_FILE="${HOME}/.oci/ocir_token"
OCIR_TOKEN=""
if [ -f "${TOKEN_FILE}" ]; then
  OCIR_TOKEN=$(cat "${TOKEN_FILE}")
fi

export TF_VAR_tenancy_ocid="$TENANCY_OCID"
export TF_VAR_compartment_id="$OCI_COMPARTMENT_ID"
export TF_VAR_region="$REGION"
export TF_VAR_ocir_username="$OCIR_USERNAME"
export TF_VAR_ocir_token="${OCIR_TOKEN:-dummy}"

# ------------------------------------------------------------------------------
# Destroy static web application
# ------------------------------------------------------------------------------

echo "NOTE: Destroying web application..."

cd 02-webapp || {
  echo "ERROR: 02-webapp directory missing."
  exit 1
}

terraform init
terraform destroy -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Purge OCIR images before backend destroy
# ------------------------------------------------------------------------------
# Terraform cannot delete an OCIR repository while it still contains images.
# Enumerate all images in the compartment and delete any from notes-functions.
# ------------------------------------------------------------------------------

echo "NOTE: Purging OCIR images from notes-functions repository..."

IMAGE_IDS=$(oci artifacts container image list \
  --compartment-id "${OCI_COMPARTMENT_ID}" \
  --all \
  --query 'data.items[].id' \
  --output json 2>/dev/null | \
  jq -r '.[] // empty' 2>/dev/null || true)

if [[ -n "${IMAGE_IDS}" ]]; then
  echo "${IMAGE_IDS}" | while read -r IMG_ID; do
    echo "NOTE: Deleting image ${IMG_ID}..."
    oci artifacts container image delete \
      --image-id "${IMG_ID}" \
      --force 2>/dev/null || true
  done
else
  echo "NOTE: No OCIR images found to delete."
fi

# ------------------------------------------------------------------------------
# Destroy Functions, NoSQL, and API Gateway
# ------------------------------------------------------------------------------

echo "NOTE: Destroying Functions, NoSQL, and API Gateway..."

cd 01-functions || {
  echo "ERROR: 01-functions directory missing."
  exit 1
}

terraform init
terraform destroy -auto-approve

cd ..

echo "NOTE: Infrastructure teardown complete."

# ------------------------------------------------------------------------------
# Delete OCIR auth token and remove local cache
# ------------------------------------------------------------------------------
# The token was created by apply.sh and occupies one of the user's two
# allowed auth token slots.  Delete it by matching on the description used
# at creation time, then remove the local cache file.
# ------------------------------------------------------------------------------

echo "NOTE: Deleting OCIR auth token..."

TOKEN_ID=$(oci iam auth-token list \
  --user-id "${USER_OCID}" \
  --query "data[?description=='notes-crud-ocir'].id | [0]" \
  --raw-output 2>/dev/null || echo "")

if [[ -n "${TOKEN_ID}" && "${TOKEN_ID}" != "null" ]]; then
  oci iam auth-token delete \
    --user-id "${USER_OCID}" \
    --auth-token-id "${TOKEN_ID}" \
    --force
  echo "NOTE: OCIR auth token deleted."
else
  echo "NOTE: No notes-crud-ocir auth token found — skipping."
fi

rm -f "${TOKEN_FILE}"
echo "NOTE: Removed cached token file ${TOKEN_FILE}."

# ================================================================================
# End of script
# ================================================================================
