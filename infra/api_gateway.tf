resource "aws_apigatewayv2_api" "authentication" {
  name          = "${var.lambda_name}-${var.environment}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.frontend_allowed_origins
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 3600
  }
  description   = "API pública de autenticação do AutoFlow (${var.environment})"
}

resource "aws_apigatewayv2_integration" "authentication" {
  api_id                 = aws_apigatewayv2_api.authentication.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.cpf_validator.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds    = 15000
}

resource "aws_apigatewayv2_route" "login" {
  api_id    = aws_apigatewayv2_api.authentication.id
  route_key = "POST /auth/login"
  target    = "integrations/${aws_apigatewayv2_integration.authentication.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvocation-${var.environment}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cpf_validator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.authentication.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "authentication" {
  api_id      = aws_apigatewayv2_api.authentication.id
  name        = var.environment
  auto_deploy = true

  depends_on = [
    aws_apigatewayv2_route.login,
    aws_lambda_permission.api_gateway
  ]
}
