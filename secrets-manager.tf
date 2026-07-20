# =============================================================================
# Secrets Manager Integration (Optional)
# =============================================================================
# Instead of passing credentials in plaintext via tfvars, reference a
# Secrets Manager secret ARN. The secret should be a JSON object with the
# keys expected by the integration (e.g. client_id, client_name, client_secret).
#
# Usage in terraform.tfvars:
#   dynatrace_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-secret"
#
# The secret JSON should contain:
#   {"client_id": "...", "client_name": "...", "client_secret": "..."}
# =============================================================================

variable "dynatrace_secret_arn" {
  description = "Secrets Manager ARN containing Dynatrace OAuth credentials (JSON with client_id, client_name, client_secret). Set to empty to use plaintext in var.integrations instead."
  type        = string
  default     = ""
}

variable "dynatrace_account_urn" {
  description = "Dynatrace account URN (required when using dynatrace_secret_arn)"
  type        = string
  default     = ""
}

variable "dynatrace_env_id" {
  description = "Dynatrace environment ID (required when using dynatrace_secret_arn)"
  type        = string
  default     = ""
}

# Fetch the secret only when the ARN is provided
data "aws_secretsmanager_secret_version" "dynatrace" {
  count     = var.dynatrace_secret_arn != "" ? 1 : 0
  secret_id = var.dynatrace_secret_arn
}

locals {
  # Parse the secret JSON when available
  dynatrace_from_secrets_manager = var.dynatrace_secret_arn != "" ? jsondecode(
    data.aws_secretsmanager_secret_version.dynatrace[0].secret_string
  ) : null
}

# Register Dynatrace using credentials from Secrets Manager
resource "awscc_devopsagent_service" "dynatrace_from_sm" {
  count        = var.dynatrace_secret_arn != "" ? 1 : 0
  service_type = "dynatrace"

  service_details = {
    dynatrace = {
      account_urn = var.dynatrace_account_urn
      authorization_config = {
        o_auth_client_credentials = {
          client_id     = local.dynatrace_from_secrets_manager.client_id
          client_name   = local.dynatrace_from_secrets_manager.client_name
          client_secret = local.dynatrace_from_secrets_manager.client_secret
        }
      }
    }
  }
}

# Associate Dynatrace with the agent space
resource "awscc_devopsagent_association" "dynatrace_from_sm" {
  count          = var.dynatrace_secret_arn != "" ? 1 : 0
  agent_space_id = awscc_devopsagent_agent_space.main.id
  service_id     = awscc_devopsagent_service.dynatrace_from_sm[0].service_id

  configuration = {
    dynatrace = {
      env_id = var.dynatrace_env_id
    }
  }

  depends_on = [awscc_devopsagent_service.dynatrace_from_sm]
}
