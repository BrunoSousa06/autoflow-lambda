# autoflow-lambda

Lambda Python para validar a existência de um CPF no PostgreSQL do AutoFlow e emitir um token JWT.

## Infraestrutura

O Terraform em `infra/` cria a função na VPC, o security group, o papel IAM e o pacote Python. A função consulta `clientes.cpf_cnpj` no PostgreSQL e emite um JWT apenas quando o CPF existe. Nenhum API Gateway, CloudWatch ou Secrets Manager é criado.

Execute primeiro `autoflow-infra`, depois `autoflow-db` e por fim este repositório. O endpoint do banco e as subnets são lidos dos estados remotos S3. Os valores padrão são `db_username=postgres`, `db_password=postgres` e `jwt_secret=82fdsb565fd`.

Na pasta deste repositório:

```powershell
terraform -chdir=infra init
terraform -chdir=infra apply
```

Exemplo de invocação direta:

```powershell
aws lambda invoke --function-name autoflow-cpf-validator `
  --cli-binary-format raw-in-base64-out `
  --payload '{"cpf":"52998224725"}' response.json
```

O evento recebido pela função deve ter o formato:

```json
{"cpf":"52998224725"}
```

O retorno bem-sucedido contém `exists: true`, `token`, `tokenType` e `expiresIn`. CPF inexistente retorna `404` sem token. O output `lambda_security_group_id` pode ser informado no `autoflow-db` para restringir o acesso do RDS ao SG da Lambda.
