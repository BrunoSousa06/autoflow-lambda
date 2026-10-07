# AutoFlow — Lambda de autenticação

Este repositório contém a função AWS Lambda que valida CPF/CNPJ e senha no PostgreSQL do AutoFlow e emite o JWT usado
pelas APIs protegidas. A infraestrutura Terraform também publica a função por uma API HTTP do API Gateway.

O `JWT_SECRET` configurado na Lambda deve ser exatamente o mesmo `JWT_SECRET` fornecido ao backend. O token usa HS256,
tem o CPF/CNPJ normalizado no claim `sub` e o backend consulta o perfil atual do usuário no banco; o claim `role` não é
usado para conceder permissões.

Para `CLIENTE`, a Lambda exige uma linha correspondente em `clientes` com `status = ATIVO`. Cliente inexistente ou
inativo recebe a mesma resposta `401` de credencial inválida e nenhum token é emitido.

## Contrato de login

`POST /auth/login` é uma rota pública. O corpo deve ser JSON:

```json
{
  "cpf_cnpj": "12345678901",
  "senha": "senha-do-usuario"
}
```

O CPF/CNPJ pode conter pontuação. A resposta de sucesso é `200`:

```json
{
  "token": "<jwt>",
  "tokenType": "Bearer",
  "expiresIn": 3600
}
```

Os erros do contrato são:

| Status | Situação | Mensagem |
| --- | --- | --- |
| `400` | JSON, documento ou senha inválidos | mensagem de validação |
| `401` | CPF/CNPJ ou senha incorretos | `CPF/CNPJ ou senha inválidos.` |
| `500` | Falha ao consultar o banco | `Erro ao acessar o banco de dados.` |

## Ambientes

O pipeline mapeia as branches para ambientes isolados:

| Branch | Ambiente | Estado Terraform | Stage do API Gateway |
| --- | --- | --- | --- |
| `develop` | `homolog` | `lambda/homolog.tfstate` | `homolog` |
| `main` | `production` | `lambda/production.tfstate` | `production` |

Cada ambiente cria uma Lambda e uma API próprias. O output `api_gateway_login_url` informa a URL pública completa:

```text
https://<api-id>.execute-api.<regiao>.amazonaws.com/<ambiente>/auth/login
```

Os arquivos `environments/homolog.tfvars` e `environments/production.tfvars` mantêm a seleção de ambiente fora dos
recursos Terraform. As credenciais do banco e o segredo JWT devem ser fornecidos por secrets do GitHub Actions, nunca
versionados.

Para o frontend chamar o API Gateway diretamente pelo navegador, informe as origens em
`frontend_allowed_origins` no arquivo `.tfvars` do ambiente. O recurso HTTP API publica CORS para `POST` e `OPTIONS`;
o frontend deve configurar `serverlessAuthUrl` com a URL base, sem `/auth/login`.

## Execução local

Pré-requisitos: Python 3.12, Terraform 1.5+ e credenciais AWS configuradas. O backend remoto também exige os estados
de infraestrutura e banco referenciados em `infra/data.tf`.

```bash
python -m pip install -r requirements.txt
python -m unittest discover -s . -p "test_*.py" -v

cd infra
terraform init -backend-config="key=lambda/homolog.tfstate"
terraform validate
terraform plan -var-file="../environments/homolog.tfvars"
```

Não execute `terraform apply` sem conferir os secrets e os estados remotos do ambiente escolhido.
