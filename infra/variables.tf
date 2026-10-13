variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  description = "Perfil AWS opcional fornecido pela configuração local do processo."
  type        = string
  default     = null
}

variable "aws_allowed_account_ids" {
  description = "Contas AWS permitidas para este provider; fornecidas externamente por ambiente."
  type        = list(string)

  validation {
    condition     = length(var.aws_allowed_account_ids) > 0 && alltrue([for id in var.aws_allowed_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "aws_allowed_account_ids deve conter pelo menos um ID de conta AWS válido, fornecido externamente."
  }
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

variable "enable_lambda_function_url" {
  description = "Cria uma Function URL privada com autorização AWS_IAM; desabilitada até existir caller SigV4 aprovado."
  type        = bool
  default     = false
}

variable "role_arn" {
  description = "Role de execução Lambda aprovada para o ambiente selecionado."
  type        = string
  default     = null
}

variable "terraform_state_bucket" {
  description = "Bucket que contém os states Terraform consumidos pela Lambda."
  type        = string
  default     = "state-autoflow-terraform"
}

variable "infra_state_key" {
  description = "Key do state de VPC/EKS consumido pela Lambda."
  type        = string
  default     = "infra/terraform.tfstate"
}

variable "rds_state_key" {
  description = "Key do state RDS consumido pela Lambda."
  type        = string
  default     = "rds/terraform.tfstate"
}
