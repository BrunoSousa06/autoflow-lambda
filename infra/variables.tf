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
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "jwt_expires_in_seconds" {
  type    = number
  default = 3600
}

variable "role_arn" {
  default = "arn:aws:iam::264066152659:role/LabRole"
}