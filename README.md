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

O pacote `lambda.zip` sincronizado localmente corresponde byte a byte ao código implantado. `handler.py` contém uma variante local diferente; a diferença está documentada no checkpoint de migração. O pipeline que fecha a URL recupera e valida o `CodeSha256` do pacote implantado, evitando publicar a variante local durante essa operação. Atualizações de código devem ser planejadas separadamente.

## Pipeline e validação

O workflow executa testes e validação Terraform. O fechamento da URL é manual, exclusivo de homologação, exige a variável de aprovação `API_GATEWAY_HOMOLOGATED` e valida que o plano contém somente a mudança para `AWS_IAM` e a remoção das duas permissões públicas. Durante esse fechamento, o pipeline usa o pacote implantado; o apply permanece condicionado à aprovação explícita do plano.

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
