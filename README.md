# Lambda de autenticação do AutoFlow

Este repositório mantém a função Python 3.12 que autentica clientes pelo PostgreSQL e emite JWT HS256. O caminho de autenticação implantado é **Frontend Angular → Amazon API Gateway HTTP API → integração AWS_PROXY → Lambda → RDS PostgreSQL**. O backend Spring Boot valida o JWT nas rotas protegidas.

O API Gateway é proprietário da integração nativa e da permissão `lambda:InvokeFunction` restrita à rota de login. O Terraform deste repositório gerencia somente a função e sua configuração de execução. A Function URL legada e as duas permissões públicas foram removidas em homologação; a função e a permissão do API Gateway foram preservadas.

## Contrato de login

`POST /auth/login` recebe JSON com `cpf_cnpj` e `senha`. O documento pode conter pontuação. A Lambda valida o documento, busca o usuário e o cliente ativo, compara a senha BCrypt e retorna um JWT. Para `CLIENTE`, o registro associado precisa estar com `status = ATIVO`.

```json
{
  "cpf_cnpj": "documento-ficticio",
  "senha": "senha-de-teste"
}
```

Resposta positiva:

```json
{
  "token": "<jwt>",
  "tokenType": "Bearer",
  "expiresIn": 3600
}
```

| Status | Significado |
|---|---|
| `200` | Credenciais válidas; JWT emitido |
| `400` | Corpo, documento ou campos inválidos |
| `401` | Credenciais inválidas ou cliente inexistente/inativo |
| `500` | Falha interna ao consultar o banco |

O `JWT_SECRET` da Lambda precisa corresponder ao do backend. O token usa `sub` com o documento normalizado e `role`; o backend carrega o perfil atual do usuário no banco e não concede acesso somente com base no claim `role`.

## Terraform e segurança

`infra/lambda.tf` declara a função existente em subnets privadas, Security Group do RDS, timeout de 15 segundos e memória de 256 MB. A role de execução é fornecida externamente. Credenciais de banco e JWT são inputs sensíveis; forneça-as somente pelo mecanismo protegido do ambiente e não as registre em arquivos, logs ou planos publicados.

O plan de retirada da URL deve conter somente a destruição de `aws_lambda_function_url.cpf_validator[0]` e dos dois statements públicos legados. Não deve atualizar `aws_lambda_function.cpf_validator` nem remover a permissão nativa do API Gateway. O plano é aprovado separadamente antes do Apply; não recrie a URL ou permissões públicas.

O checkpoint registra que, em 13/10/2026, `lambda.zip` e `handler.py` foram sincronizados com o pacote implantado, sem publicar atualização da função. Essa é uma evidência registrada naquela data, não uma verificação do artefato AWS atual. Alterações de código devem ser planejadas separadamente e não inferidas do workflow de Terraform.

## Pipeline e validação

Consulte o [catálogo de variables e secrets](docs/variables-and-secrets.md) e o [histórico](docs/variables-changelog.md) para configuração do GitHub Actions, Terraform e runtime.

CI executa automaticamente em Pull Requests e pushes para `develop` e `main`, com testes Python, auditoria de dependências e validação Terraform; esses eventos não aplicam infraestrutura. O CD é iniciado somente por `workflow_dispatch` em `develop`, usa o Environment `homolog` e executa plan, validação de conta/state e gate de destruições. O Apply requer input `deploy`, `TERRAFORM_APPLY_APPROVAL_CONFIGURED=true` e `allow_destructive=true` quando houver exclusões/substituições. Esse flag exige Required reviewers, mas não prova que estejam configurados no GitHub; a configuração real e execuções do workflow não foram verificadas. Não há CD de produção declarado.

Secrets referenciados pelo workflow: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `DATABASE_USERNAME`, `DATABASE_PASSWORD` e `JWT_SECRET`. Variables incluem `AWS_REGION`, `AWS_EXPECTED_ACCOUNT_ID`, `AWS_TERRAFORM_STATE_BUCKET`, `AWS_TF_STATE_KEY`, `AWS_INFRA_STATE_KEY`, `AWS_RDS_STATE_KEY` e `AWS_LAMBDA_EXECUTION_ROLE_ARN`, além de `TERRAFORM_APPLY_APPROVAL_CONFIGURED`. Configure nomes/valores no GitHub Environment apropriado; não copie valores sensíveis para documentação.

```bash
python -m pip install -r requirements.txt
python -m unittest discover -s . -p "test_*.py" -v
```

Para validar o Terraform sem acessar o backend remoto:

```bash
cd infra
terraform init -backend=false -input=false
terraform validate
```

O state S3 e os states remotos consumidos devem ser os autorizados para a conta e ambiente esperados. Não aplique planos que incluam alteração de código Lambda durante o fechamento da URL.
