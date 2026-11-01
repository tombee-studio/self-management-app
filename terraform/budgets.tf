# 月額費用通知（課金停止・上限保証ではない）
resource "aws_budgets_budget" "cost_safety_guard" {
  count             = var.enable_cost_budget ? 1 : 0
  name              = "${var.app_name}-monthly-cost-guard-${var.environment}"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_usd
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80 # 予測が設定予算の80%に到達した場合
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100 # 実費が設定予算へ到達した場合
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}

# Preserve the existing production resource address when enabling the optional budget.
moved {
  from = aws_budgets_budget.cost_safety_guard
  to   = aws_budgets_budget.cost_safety_guard[0]
}
