variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Ambiente que receberá os recursos da autenticação."
  default     = "homolog"

  validation {
    condition     = contains(["homolog", "production"], var.environment)
    error_message = "environment deve ser homolog ou production."
  }
}

variable "lambda_name" {
  type    = string
  default = "autoflow-cpf-validator"
}

variable "db_name" {
  type    = string
  default = "autoflow_db"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true

  validation {
    condition     = length(trimspace(var.jwt_secret)) >= 32
    error_message = "jwt_secret deve possuir pelo menos 32 caracteres."
  }
}

variable "jwt_expires_in_seconds" {
  type    = number
  default = 3600

  validation {
    condition     = var.jwt_expires_in_seconds > 0
    error_message = "jwt_expires_in_seconds deve ser maior que zero."
  }
}

variable "frontend_allowed_origins" {
  type        = list(string)
  description = "Origens autorizadas a chamar o login serverless pelo navegador."
  default     = ["http://localhost:4200"]
}

variable "role_arn" {
  default = "arn:aws:iam::264066152659:role/LabRole"
}
