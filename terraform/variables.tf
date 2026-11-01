variable "aws_region" {
  description = "AWS デプロイリージョン (デフォルト: 東京)"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "実行環境識別子 (dev, prod など)"
  type        = string
  default     = "prod"
}

variable "app_name" {
  description = "アプリケーション名プレフィックス"
  type        = string
  default     = "iris"
}

variable "alert_email" {
  description = "月額コスト超過アラート通知先メールアドレス (AWS Budgets)"
  type        = string
  default     = "alerts@example.com"
}

variable "monthly_budget_usd" {
  description = "費用通知の月額USD閾値。月500円の目標に対し利用条件と為替をデプロイ時に確認する"
  type        = number
  default     = 2
  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "通知閾値は0より大きい値が必要です。"
  }
}

variable "owner_id" {
  type    = string
  default = "028692f2-c4c5-4299-9eb0-0ae7ed02049c"
}
variable "cursor_secret" {
  description = "Persistent HMAC signing secret, supplied securely at deployment"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.cursor_secret) >= 32
    error_message = "Use at least 32 characters."
  }
}
variable "api_v3_enabled" {
  description = "Enable only after legacy writes stop and cloud migration is verified"
  type        = bool
  default     = false
}

variable "enable_cost_budget" {
  description = "Create a dedicated cost notification; staging can use the existing account-wide guard"
  type        = bool
  default     = true
}
