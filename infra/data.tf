data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket = "state-autoflow-terraform"
    key    = "infra/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = "state-autoflow-terraform"
    key    = "rds/terraform.tfstate"
    region = var.region
  }
}

data "archive_file" "lambda" {
  depends_on  = [null_resource.lambda_dependencies]
  type        = "zip"
  source_dir  = "${path.module}/../build"
  output_path = "${path.module}/../lambda.zip"
}

resource "null_resource" "lambda_dependencies" {
  triggers = {
    requirements = filemd5("${path.module}/../requirements.txt")
    handler      = filemd5("${path.module}/../handler.py")
  }

  provisioner "local-exec" {
    command     = "powershell -ExecutionPolicy Bypass -File ${path.module}/../build.ps1"
    working_dir = path.module
  }
}