# API Gateway (HTTP API v2 - REST API 比約70%安価、低レイテンシー)
resource "aws_apigatewayv2_api" "sync_api" {
  name          = "${var.app_name}-sync-api-${var.environment}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "x-user-id"]
    max_age       = 3600
  }

  tags = {
    Name = "${var.app_name}-sync-http-api"
  }
}

# デフォルトステージ（自動デプロイ有効）
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.sync_api.id
  name        = "$default"
  auto_deploy = true
}

# Lambda 統合
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.sync_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.sync.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# ルート定義
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.sync_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "commands" {
  count     = var.api_v3_enabled ? 1 : 0
  api_id    = aws_apigatewayv2_api.sync_api.id
  route_key = "POST /commands"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}
resource "aws_apigatewayv2_route" "queries" {
  count     = var.api_v3_enabled ? 1 : 0
  api_id    = aws_apigatewayv2_api.sync_api.id
  route_key = "POST /queries"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "payment_get" {
  count     = var.api_v3_enabled ? 1 : 0
  api_id    = aws_apigatewayv2_api.sync_api.id
  route_key = "GET /payment"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "payment_post" {
  count     = var.api_v3_enabled ? 1 : 0
  api_id    = aws_apigatewayv2_api.sync_api.id
  route_key = "POST /payment"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway から Lambda を呼び出す許可
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sync.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.sync_api.execution_arn}/*/*"
}
