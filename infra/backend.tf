terraform {
  backend "s3" {
    bucket = "state-autoflow-terraform"
    key    = "lambda/terraform.tfstate"
    region = "us-east-1"
  }
}