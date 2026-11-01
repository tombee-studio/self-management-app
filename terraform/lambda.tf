# Lambda ソースコードの自動 ZIP 化
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../server"
  excludes    = ["test/**", "node_modules/.cache/**"]
  output_path = "${path.module}/lambda_function_payload.zip"
}

# 同期 Lambda 関数
resource "aws_lambda_function" "sync" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.app_name}-sync-handler-${var.environment}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "nodejs22.x"
  timeout          = 10  # 秒
  memory_size      = 128 # MB (最小サイズでコスト最小化)

  environment {
    variables = {
      METADATA_TABLE   = aws_dynamodb_table.v3["metadata"].name
      EXPENSES_TABLE   = aws_dynamodb_table.v3["expenses"].name
      CATEGORIES_TABLE = aws_dynamodb_table.v3["categories"].name
      BUDGETS_TABLE    = aws_dynamodb_table.v3["budgets"].name
      EVENTS_TABLE     = aws_dynamodb_table.v3["domain_events"].name
      OWNER_ID         = var.owner_id
      CURSOR_SECRET    = var.cursor_secret
    }
  }

  tags = {
    Name = "${var.app_name}-sync-lambda"
  }
}

# Committed event inserts are delivered after the business transaction by DynamoDB Streams.
resource "aws_lambda_event_source_mapping" "domain_events" {
  event_source_arn  = aws_dynamodb_table.v3["domain_events"].stream_arn
  function_name     = aws_lambda_function.sync.arn
  starting_position = "TRIM_HORIZON"
  batch_size        = 10
  filter_criteria {
    filter {
      pattern = jsonencode({ eventName = ["INSERT"] })
    }
  }
  depends_on = [aws_iam_role_policy.lambda_stream]
}
