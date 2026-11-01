# 1. 支出テーブル (iris_expenses)
resource "aws_dynamodb_table" "expenses" {
  name         = "${var.app_name}_expenses_${var.environment}"
  billing_mode = "PAY_PER_REQUEST" # オンデマンド従量課金（常時無料枠 25GB 内で完全0円運用可能）
  hash_key     = "user_id"
  range_key    = "expense_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "expense_id"
    type = "S"
  }

  attribute {
    name = "spent_at"
    type = "S"
  }

  # 日付範囲クエリ用 GSI (月別・日別集計用)
  global_secondary_index {
    name            = "user_spent_at_index"
    hash_key        = "user_id"
    range_key       = "spent_at"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = false # 個人利用のため無効化（コスト削減）
  }

  tags = {
    Name = "${var.app_name}-expenses"
  }
}

# 2. カテゴリマスターテーブル (iris_categories)
resource "aws_dynamodb_table" "categories" {
  name         = "${var.app_name}_categories_${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "category_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "category_id"
    type = "S"
  }

  tags = {
    Name = "${var.app_name}-categories"
  }
}

# 3. 予算設定テーブル (iris_budgets)
resource "aws_dynamodb_table" "budgets" {
  name         = "${var.app_name}_budgets_${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "budget_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "budget_id"
    type = "S"
  }

  tags = {
    Name = "${var.app_name}-budgets"
  }
}

resource "aws_dynamodb_table" "category_budgets" {
  name         = "${var.app_name}_category_budgets_${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "category_id"
  attribute {
    name = "user_id"
    type = "S"
  }
  attribute {
    name = "category_id"
    type = "S"
  }
}
resource "aws_dynamodb_table" "metadata" {
  name         = "${var.app_name}_sync_metadata_${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "lock_type"
  attribute {
    name = "user_id"
    type = "S"
  }
  attribute {
    name = "lock_type"
    type = "S"
  }
}

# Version 3 tables are created alongside legacy tables; never replace live keys in place.
resource "aws_dynamodb_table" "v3" {
  for_each         = toset(["expenses", "categories", "budgets", "metadata", "domain_events"])
  name             = "${var.app_name}_${each.key}_v3_${var.environment}"
  billing_mode     = "PAY_PER_REQUEST"
  stream_enabled   = each.key == "domain_events"
  stream_view_type = each.key == "domain_events" ? "NEW_IMAGE" : null
  hash_key         = "ownerId"
  range_key        = "id"
  attribute {
    name = "ownerId"
    type = "S"
  }
  attribute {
    name = "id"
    type = "S"
  }
  lifecycle {
    prevent_destroy = true
  }
}
