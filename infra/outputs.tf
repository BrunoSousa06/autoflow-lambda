output "lambda_function_name" {
  value = aws_lambda_function.cpf_validator.function_name
}

output "lambda_function_url" {
  description = "Endpoint HTTPS da Function URL existente; não é segredo. Pode ser publicamente invocável durante o modo acadêmico."
  value       = try(aws_lambda_function_url.cpf_validator[0].function_url, null)
}
