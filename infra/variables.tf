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
  default   = "8aF3mK9pQ2xV7nRt5YcW1zLb4DsH6jTe0UrN8gXp3CvM7qAz9FkP2hYs6BwLd4Xe"
  sensitive = true
}

variable "jwt_expires_in_seconds" {
  type    = number
  default = 3600
}

variable "role_arn" {
  default = "arn:aws:iam::264066152659:role/LabRole"
}