output "api_endpoint" {
  description = "Flutter アプリから接続する API Gateway HTTP API エンドポイント URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "expenses_table" {
  description = "DynamoDB 支出テーブル名"
  value       = aws_dynamodb_table.expenses.name
}

output "categories_table" {
  description = "DynamoDB カテゴリテーブル名"
  value       = aws_dynamodb_table.categories.name
}

output "budgets_table" {
  description = "DynamoDB 予算テーブル名"
  value       = aws_dynamodb_table.budgets.name
}

output "v3_tables" {
  description = "Migration table mapping; events is the domain_events table"
  value = {
    expenses   = aws_dynamodb_table.v3["expenses"].name
    categories = aws_dynamodb_table.v3["categories"].name
    budgets    = aws_dynamodb_table.v3["budgets"].name
    metadata   = aws_dynamodb_table.v3["metadata"].name
    events     = aws_dynamodb_table.v3["domain_events"].name
  }
}
