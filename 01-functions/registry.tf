# ================================================================================
# OCIR Container Repository and Image Build
# ================================================================================
# Creates the OCI Container Registry repository that holds the notes-functions
# Docker image, then builds and pushes the image as part of terraform apply.
# The image tag is derived from a hash of the function source files so that
# code changes force a new tag — which in turn updates the Function resources
# that reference the image path.
# ================================================================================

# --------------------------------------------------------------------------------
# Tenancy namespace — required to construct the full OCIR image path
# --------------------------------------------------------------------------------
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}

# --------------------------------------------------------------------------------
# Locals: image path and host
# --------------------------------------------------------------------------------
locals {
  ocir_host = "${var.region}.ocir.io"

  # Content-based tag: first 8 chars of the combined source hash.
  # When any source file changes, the tag changes and Function resources
  # detect the updated image attribute without manual intervention.
  image_tag = substr(
    sha256(join("", [
      filesha256("${path.module}/code/func.py"),
      filesha256("${path.module}/code/requirements.txt"),
      filesha256("${path.module}/code/Dockerfile"),
    ])),
    0, 8
  )

  image_path = "${local.ocir_host}/${data.oci_objectstorage_namespace.ns.namespace}/notes-functions:${local.image_tag}"
}

# --------------------------------------------------------------------------------
# OCIR Repository
# --------------------------------------------------------------------------------
resource "oci_artifacts_container_repository" "notes" {
  compartment_id = var.compartment_id
  display_name   = "notes-functions"
  is_public      = false
}

# --------------------------------------------------------------------------------
# Build and Push
# --------------------------------------------------------------------------------
# Runs docker build + login + push during terraform apply.  Sensitive OCIR
# credentials are passed via environment variables to avoid shell injection.
# The trigger hash matches local.image_tag so a rebuild only occurs when the
# function source actually changes.
# --------------------------------------------------------------------------------
resource "null_resource" "build_push" {
  triggers = {
    # Rebuild whenever the image tag (content hash) changes.
    image_tag = local.image_tag
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      OCIR_TOKEN    = var.ocir_token
      OCIR_USERNAME = var.ocir_username
      OCIR_HOST     = local.ocir_host
      IMAGE_PATH    = local.image_path
    }

    command = <<-EOT
      set -euo pipefail
      echo "NOTE: Building Docker image $IMAGE_PATH..."
      docker build -t "$IMAGE_PATH" ./code/

      echo "NOTE: Logging into OCIR..."
      echo "$OCIR_TOKEN" | docker login "$OCIR_HOST" -u "$OCIR_USERNAME" --password-stdin

      echo "NOTE: Pushing image to OCIR..."
      docker push "$IMAGE_PATH"
    EOT
  }

  depends_on = [oci_artifacts_container_repository.notes]
}
