# ================================================================================
# OCI Provider and Variables
# ================================================================================
# Configures the OCI Terraform provider and declares input variables consumed
# by all Terraform files in this module.  Variables are supplied at apply time
# via TF_VAR_* environment variables set in apply.sh / check_env.sh.
# ================================================================================

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Auth uses ~/.oci/config by default (API key mode).
provider "oci" {
  region = var.region
}

# ================================================================================
# Variables
# ================================================================================

variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy (root compartment)"
  type        = string
}

variable "compartment_id" {
  description = "OCID of the compartment where all resources are created"
  type        = string
}

variable "region" {
  description = "OCI region identifier (e.g., us-ashburn-1)"
  type        = string
}

variable "ocir_username" {
  description = "OCIR Docker login username (format: tenancy-namespace/user@email)"
  type        = string
}

variable "ocir_token" {
  description = "OCI auth token used as the Docker password for OCIR login"
  type        = string
  sensitive   = true
}
