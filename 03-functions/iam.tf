# ================================================================================
# IAM — Dynamic Group and Policies
# ================================================================================
# Two sets of IAM grants are required:
#
# 1. Functions → NoSQL
#    A Dynamic Group matches all OCI Functions in the notes compartment.
#    An IAM policy grants that group rights to manage NoSQL rows and use
#    the NoSQL table.  The Resource Principal signer in func.py relies on
#    this to authenticate SDK calls without embedding credentials.
#
# 2. API Gateway → Functions
#    A service-principal policy allows the API Gateway service itself to
#    invoke Functions within the compartment.  Without this, API Gateway
#    cannot trigger function execution.
#
# Dynamic groups and tenancy-scoped policies must be created in the root
# compartment (var.tenancy_ocid), not in a child compartment.
# ================================================================================

# --------------------------------------------------------------------------------
# Dynamic Group — matches all Functions in the notes compartment
# --------------------------------------------------------------------------------
resource "oci_identity_dynamic_group" "notes_functions" {
  compartment_id = var.tenancy_ocid # Dynamic groups live at the tenancy root
  name           = "notes-functions-dg"
  description    = "OCI Functions in the notes compartment (Resource Principal auth)"

  # ALL{} syntax required for Identity Domain-enabled tenancies (IDCS backend).
  matching_rule = "ALL {resource.type = 'fnfunc', resource.compartment.id = '${var.compartment_id}'}"
}

# --------------------------------------------------------------------------------
# Policy — Functions can manage NoSQL rows
# --------------------------------------------------------------------------------
resource "oci_identity_policy" "functions_nosql" {
  compartment_id = var.tenancy_ocid
  name           = "notes-functions-nosql"
  description    = "Allow notes functions to read and write NoSQL rows"

  statements = [
    "Allow dynamic-group notes-functions-dg to manage nosql-rows in compartment id ${var.compartment_id}",
    "Allow dynamic-group notes-functions-dg to use nosql-tables in compartment id ${var.compartment_id}",
  ]
}

# --------------------------------------------------------------------------------
# Policy — API Gateway can invoke Functions
# --------------------------------------------------------------------------------
# Uses the service principal condition so the API Gateway service identity
# (not a user or instance) is the one allowed to call Functions.
# --------------------------------------------------------------------------------
resource "oci_identity_policy" "apigateway_functions" {
  compartment_id = var.tenancy_ocid
  name           = "notes-apigateway-invoke"
  description    = "Allow API Gateway to invoke notes functions"

  statements = [
    join(" ", [
      "Allow any-user to use functions-family in compartment id ${var.compartment_id}",
      "where ALL {",
      "  request.principal.type = 'ApiGateway',",
      "  request.resource.compartment.id = '${var.compartment_id}'",
      "}",
    ]),
  ]
}
