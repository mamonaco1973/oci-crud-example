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
# ================================================================================

set -euo pipefail

: "${TF_VAR_tenancy_ocid:?ERROR: TF_VAR_tenancy_ocid is required}"
: "${TF_VAR_compartment_id:?ERROR: TF_VAR_compartment_id is required}"
: "${TF_VAR_region:?ERROR: TF_VAR_region is required}"
: "${TF_VAR_ocir_username:?ERROR: TF_VAR_ocir_username is required}"
: "${TF_VAR_ocir_token:?ERROR: TF_VAR_ocir_token is required}"

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
  --compartment-id "${TF_VAR_compartment_id}" \
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

# ================================================================================
# End of script
# ================================================================================
