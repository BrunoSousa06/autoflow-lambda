resource "aws_security_group" "lambda" {
  name        = "${var.lambda_name}-sg"
  description = "Acesso da Lambda ao PostgreSQL do AutoFlow"
  vpc_id      = data.terraform_remote_state.infra.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}