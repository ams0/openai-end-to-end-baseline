locals {
  # Customer Usage Attribution Id
  cua_id = "a52aa8a8-44a8-46e9-b7a5-189ab3a64409"
  
  # Common tags
  common_tags = {
    Environment = "Production"
    Project     = "OpenAI-Baseline"
    ManagedBy   = "Terraform"
  }
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}