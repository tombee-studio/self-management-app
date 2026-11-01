terraform {
  required_version = ">= 1.5.0"
}
variable "cursor_secret" {
  type      = string
  sensitive = true
}
variable "owner_id" {
  type = string
}
module "iris" {
  source             = "../.."
  environment        = "stg"
  owner_id           = var.owner_id
  cursor_secret      = var.cursor_secret
  api_v3_enabled     = true
  enable_cost_budget = false
}
output "api_endpoint" {
  value = module.iris.api_endpoint
}
output "v3_tables" {
  value = module.iris.v3_tables
}
