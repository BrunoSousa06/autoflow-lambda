variable "region" {
  type    = string
  default = "us-east-1"
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
  default   = "postgres"
  sensitive = true
}

variable "db_password" {
  type      = string
  default   = "postgres"
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  default   = "82fdsb565fd"
  sensitive = true
}

variable "jwt_expires_in_seconds" {
  type    = number
  default = 3600
}

variable "role_arn" {
  default = "arn:aws:iam::724623091343:role/LabRole"
}