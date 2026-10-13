resource "aws_lambda_function" "cpf_validator" {
  function_name    = "${var.lambda_name}-${var.environment}"
  role             = var.role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = "${path.module}/../lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda.zip")
  timeout          = 15
  memory_size      = 256

  vpc_config {
    subnet_ids = data.terraform_remote_state.infra.outputs.private_subnet_ids

    security_group_ids = [
      data.terraform_remote_state.db.outputs.lambda_security_group_id
    ]
  }

  environment {
    variables = {
      AUTOFLOW_ENVIRONMENT   = var.environment
      DB_HOST                = data.terraform_remote_state.db.outputs.postgres_endpoint
      DB_PORT                = tostring(data.terraform_remote_state.db.outputs.postgres_port)
      DB_NAME                = var.db_name
      DB_USERNAME            = var.db_username
      DB_PASSWORD            = var.db_password
      JWT_SECRET             = var.jwt_secret
      JWT_EXPIRES_IN_SECONDS = tostring(var.jwt_expires_in_seconds)
    }
  }
}

# Preserve a URL/state existente. AWS_IAM é o padrão; NONE só é habilitado
# explicitamente para a demonstração acadêmica e torna a URL pública.
resource "aws_lambda_function_url" "cpf_validator" {
  count              = var.enable_lambda_function_url || var.enable_academic_demo_function_url ? 1 : 0
  function_name      = aws_lambda_function.cpf_validator.function_name
  authorization_type = var.enable_academic_demo_function_url ? "NONE" : "AWS_IAM"

  lifecycle {
    precondition {
      condition     = !var.enable_academic_demo_function_url || (var.enable_lambda_function_url && var.environment == "homolog" && var.academic_demo_environment_confirmed)
      error_message = "Modo acadêmico exige Function URL habilitada, environment=homolog e confirmação explícita de ambiente sem produção."
    }
  }
}

# As duas ações são exigidas pelas Function URLs atuais. InvokeFunction fica
# limitado a invocações via URL; FunctionUrlAuthType limita a URL ao modo NONE.
resource "aws_lambda_permission" "academic_demo_function_url" {
  count                  = var.enable_academic_demo_function_url ? 1 : 0
  statement_id           = "AllowAcademicDemoFunctionUrlInvokeUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.cpf_validator.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "academic_demo_invoke_via_url" {
  count                    = var.enable_academic_demo_function_url ? 1 : 0
  statement_id             = "AllowAcademicDemoInvokeViaFunctionUrl"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.cpf_validator.function_name
  principal                = "*"
  invoked_via_function_url = true
}
