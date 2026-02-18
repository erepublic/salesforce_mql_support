locals {
  sandbox_api_name    = "${var.name_prefix}-mql-api-sandbox"
  production_api_name = "${var.name_prefix}-mql-api-production"
  resource_path       = "summarize"
}

resource "aws_api_gateway_rest_api" "sandbox" {
  name = local.sandbox_api_name
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  tags = var.tags
}

resource "aws_api_gateway_rest_api" "production" {
  name = local.production_api_name
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  tags = var.tags
}

resource "aws_api_gateway_resource" "sandbox_summarize" {
  rest_api_id = aws_api_gateway_rest_api.sandbox.id
  parent_id   = aws_api_gateway_rest_api.sandbox.root_resource_id
  path_part   = local.resource_path
}

resource "aws_api_gateway_resource" "production_summarize" {
  rest_api_id = aws_api_gateway_rest_api.production.id
  parent_id   = aws_api_gateway_rest_api.production.root_resource_id
  path_part   = local.resource_path
}

resource "aws_api_gateway_method" "sandbox_post_summarize" {
  rest_api_id      = aws_api_gateway_rest_api.sandbox.id
  resource_id      = aws_api_gateway_resource.sandbox_summarize.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "production_post_summarize" {
  rest_api_id      = aws_api_gateway_rest_api.production.id
  resource_id      = aws_api_gateway_resource.production_summarize.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "sandbox_post_summarize" {
  rest_api_id             = aws_api_gateway_rest_api.sandbox.id
  resource_id             = aws_api_gateway_resource.sandbox_summarize.id
  http_method             = aws_api_gateway_method.sandbox_post_summarize.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.sandbox_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "production_post_summarize" {
  rest_api_id             = aws_api_gateway_rest_api.production.id
  resource_id             = aws_api_gateway_resource.production_summarize.id
  http_method             = aws_api_gateway_method.production_post_summarize.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.production_lambda_invoke_arn
}

# Deployments/stages so the invoke URL matches /<env>/summarize pattern.
resource "aws_api_gateway_deployment" "sandbox" {
  rest_api_id = aws_api_gateway_rest_api.sandbox.id

  triggers = {
    redeploy = sha1(jsonencode({
      method_id = aws_api_gateway_method.sandbox_post_summarize.id
      resource  = aws_api_gateway_resource.sandbox_summarize.id
      sandbox   = var.sandbox_lambda_invoke_arn
    }))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.sandbox_post_summarize]
}

resource "aws_api_gateway_deployment" "production" {
  rest_api_id = aws_api_gateway_rest_api.production.id

  triggers = {
    redeploy = sha1(jsonencode({
      method_id = aws_api_gateway_method.production_post_summarize.id
      resource  = aws_api_gateway_resource.production_summarize.id
      prod      = var.production_lambda_invoke_arn
    }))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.production_post_summarize]
}

resource "aws_api_gateway_stage" "sandbox" {
  rest_api_id   = aws_api_gateway_rest_api.sandbox.id
  deployment_id = aws_api_gateway_deployment.sandbox.id
  stage_name    = "sandbox"
  tags          = var.tags
}

resource "aws_api_gateway_stage" "production" {
  rest_api_id   = aws_api_gateway_rest_api.production.id
  deployment_id = aws_api_gateway_deployment.production.id
  stage_name    = "production"
  tags          = var.tags
}

# Lambda invoke permissions (scoped to stage + resource + method).
resource "aws_lambda_permission" "sandbox" {
  statement_id  = "AllowInvokeFromApiGatewaySandbox"
  action        = "lambda:InvokeFunction"
  function_name = var.sandbox_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.sandbox.execution_arn}/sandbox/POST/${local.resource_path}"
}

resource "aws_lambda_permission" "production" {
  statement_id  = "AllowInvokeFromApiGatewayProduction"
  action        = "lambda:InvokeFunction"
  function_name = var.production_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.production.execution_arn}/production/POST/${local.resource_path}"
}

# API keys and usage plans (separate keys per env).
resource "aws_api_gateway_api_key" "sandbox" {
  name  = "${var.name_prefix}-sandbox-key"
  value = var.sandbox_api_key_value
  tags  = var.tags
}

resource "aws_api_gateway_api_key" "production" {
  name  = "${var.name_prefix}-production-key"
  value = var.production_api_key_value
  tags  = var.tags
}

resource "aws_api_gateway_usage_plan" "sandbox" {
  name = "${var.name_prefix}-sandbox-plan"
  api_stages {
    api_id = aws_api_gateway_rest_api.sandbox.id
    stage  = aws_api_gateway_stage.sandbox.stage_name
  }
  tags = var.tags
}

resource "aws_api_gateway_usage_plan" "production" {
  name = "${var.name_prefix}-production-plan"
  api_stages {
    api_id = aws_api_gateway_rest_api.production.id
    stage  = aws_api_gateway_stage.production.stage_name
  }
  tags = var.tags
}

resource "aws_api_gateway_usage_plan_key" "sandbox" {
  key_id        = aws_api_gateway_api_key.sandbox.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.sandbox.id
}

resource "aws_api_gateway_usage_plan_key" "production" {
  key_id        = aws_api_gateway_api_key.production.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.production.id
}

