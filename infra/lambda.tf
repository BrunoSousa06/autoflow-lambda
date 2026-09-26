resource "aws_lambda_function" "cpf_validator" {
  function_name    = var.lambda_name
  role             = var.role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
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