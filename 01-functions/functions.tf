# ================================================================================
# OCI Functions Application and Functions
# ================================================================================
# Deploys a Functions Application (logical container for functions) and five
# individual Function resources — one per CRUD operation.  All five use the
# same Docker image (local.image_path) distinguished by the FUNCTION_TYPE
# environment variable, which the handler() dispatcher reads at runtime.
# ================================================================================

# --------------------------------------------------------------------------------
# Functions Application — groups the five functions under a shared VCN subnet
# --------------------------------------------------------------------------------
resource "oci_functions_application" "notes" {
  compartment_id = var.compartment_id
  display_name   = "notes-app"
  subnet_ids     = [oci_core_subnet.public.id]
}

# --------------------------------------------------------------------------------
# Shared function config — merged with FUNCTION_TYPE per function below
# --------------------------------------------------------------------------------
locals {
  fn_config = {
    NOSQL_TABLE_NAME = oci_nosql_table.notes.name
    COMPARTMENT_ID   = var.compartment_id
  }
}

# --------------------------------------------------------------------------------
# create-note — POST /notes
# --------------------------------------------------------------------------------
resource "oci_functions_function" "create_note" {
  application_id     = oci_functions_application.notes.id
  display_name       = "create-note"
  image              = local.image_path
  memory_in_mbs      = "256"
  timeout_in_seconds = 30
  config             = merge(local.fn_config, { FUNCTION_TYPE = "create" })

  depends_on = [null_resource.build_push]
}

# --------------------------------------------------------------------------------
# list-notes — GET /notes
# --------------------------------------------------------------------------------
resource "oci_functions_function" "list_notes" {
  application_id     = oci_functions_application.notes.id
  display_name       = "list-notes"
  image              = local.image_path
  memory_in_mbs      = "256"
  timeout_in_seconds = 30
  config             = merge(local.fn_config, { FUNCTION_TYPE = "list" })

  depends_on = [null_resource.build_push]
}

# --------------------------------------------------------------------------------
# get-note — GET /notes/{id}
# --------------------------------------------------------------------------------
resource "oci_functions_function" "get_note" {
  application_id     = oci_functions_application.notes.id
  display_name       = "get-note"
  image              = local.image_path
  memory_in_mbs      = "256"
  timeout_in_seconds = 30
  config             = merge(local.fn_config, { FUNCTION_TYPE = "get" })

  depends_on = [null_resource.build_push]
}

# --------------------------------------------------------------------------------
# update-note — PUT /notes/{id}
# --------------------------------------------------------------------------------
resource "oci_functions_function" "update_note" {
  application_id     = oci_functions_application.notes.id
  display_name       = "update-note"
  image              = local.image_path
  memory_in_mbs      = "256"
  timeout_in_seconds = 30
  config             = merge(local.fn_config, { FUNCTION_TYPE = "update" })

  depends_on = [null_resource.build_push]
}

# --------------------------------------------------------------------------------
# delete-note — DELETE /notes/{id}
# --------------------------------------------------------------------------------
resource "oci_functions_function" "delete_note" {
  application_id     = oci_functions_application.notes.id
  display_name       = "delete-note"
  image              = local.image_path
  memory_in_mbs      = "256"
  timeout_in_seconds = 30
  config             = merge(local.fn_config, { FUNCTION_TYPE = "delete" })

  depends_on = [null_resource.build_push]
}
