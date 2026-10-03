output "lambda_security_group_id" {
  description = "Security group da Lambda; pode ser informado no SG do RDS"
  value       = aws_security_group.lambda.id
}

output "lambda_function_name" {
  value = aws_lambda_function.cpf_validator.function_name
}

output "lambda_invoke_command" {
  value = "aws lambda invoke --function-name ${aws_lambda_function.cpf_validator.function_name} --cli-binary-format raw-in-base64-out --payload '{\"cpf_cnpj\":\"52998224725\",\"senha\":\"123456\"}' response.json"
}

output "api_gateway_id" {
  description = "ID da API HTTP de autenticação no ambiente atual"
  value       = aws_apigatewayv2_api.authentication.id
}

output "api_gateway_invoke_url" {
  description = "URL base da API HTTP de autenticação no ambiente atual"
  value       = aws_apigatewayv2_stage.authentication.invoke_url
}

output "api_gateway_login_url" {
  description = "URL pública de login no ambiente atual"
  value       = "${trimsuffix(aws_apigatewayv2_stage.authentication.invoke_url, "/")}/auth/login"
}
