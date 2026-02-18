locals {
  env         = var.env_name
  lambda_name = "${var.name_prefix}-summarizer-${local.env}"

  ddb_table_name = "${var.name_prefix}-idempotency-${local.env}"
  dlq_name       = "${var.name_prefix}-dlq-${local.env}"

  secret_salesforce_name = "${var.name_prefix}/${local.env}/salesforce"
  secret_hubspot_name    = "${var.name_prefix}/${local.env}/hubspot"
  secret_openai_name     = "${var.name_prefix}/${local.env}/openai"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.lambda_src_dir
  output_path = "${path.module}/.terraform-artifacts/${local.lambda_name}.zip"
}

resource "aws_sqs_queue" "dlq" {
  name = local.dlq_name
  tags = var.tags
}

resource "aws_dynamodb_table" "idempotency" {
  name         = local.ddb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "idempotencyKey"

  attribute {
    name = "idempotencyKey"
    type = "S"
  }

  ttl {
    attribute_name = var.idempotency_ttl_attr
    enabled        = true
  }

  tags = var.tags
}

resource "aws_secretsmanager_secret" "salesforce" {
  name = local.secret_salesforce_name
  tags = var.tags
}

resource "aws_secretsmanager_secret" "hubspot" {
  name = local.secret_hubspot_name
  tags = var.tags
}

resource "aws_secretsmanager_secret" "openai" {
  name = local.secret_openai_name
  tags = var.tags
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${local.lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem"
    ]
    resources = [aws_dynamodb_table.idempotency.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      aws_secretsmanager_secret.salesforce.arn,
      aws_secretsmanager_secret.hubspot.arn,
      aws_secretsmanager_secret.openai.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    resources = [aws_sqs_queue.dlq.arn]
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "${local.lambda_name}-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "lambda" {
  function_name = local.lambda_name
  role          = aws_iam_role.lambda_role.arn

  runtime = var.lambda_runtime
  handler = var.lambda_handler

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = {
      ENVIRONMENT               = local.env
      IDEMPOTENCY_TABLE_NAME    = aws_dynamodb_table.idempotency.name
      IDEMPOTENCY_TTL_ATTRIBUTE = var.idempotency_ttl_attr
      SALESFORCE_SECRET_ARN     = aws_secretsmanager_secret.salesforce.arn
      HUBSPOT_SECRET_ARN        = aws_secretsmanager_secret.hubspot.arn
      OPENAI_SECRET_ARN         = aws_secretsmanager_secret.openai.arn
      DLQ_URL                   = aws_sqs_queue.dlq.url
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.lambda_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    FunctionName = aws_lambda_function.lambda.function_name
  }

  alarm_description = "Lambda errors > 0 in 5 minutes."
  tags              = var.tags
}

resource "aws_cloudwatch_metric_alarm" "dlq_visible" {
  alarm_name          = "${local.dlq_name}-messages-visible"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  alarm_description = "DLQ has messages visible."
  tags              = var.tags
}

