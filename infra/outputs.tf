output "lambda_security_group_id" {
  description = "Security group da Lambda; pode ser informado no SG do RDS"
  value       = aws_security_group.lambda.id
}

output "lambda_function_name" {
  value = aws_lambda_function.cpf_validator.function_name
}

output "lambda_invoke_command" {
  value = "aws lambda invoke --function-name ${aws_lambda_function.cpf_validator.function_name} --cli-binary-format raw-in-base64-out --payload '{\"cpf\":\"52998224725\"}' response.json"
}