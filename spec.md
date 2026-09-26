# Especificacao - autoflow-lambda

## 1. Objetivo

Este repositorio implementa e provisiona uma AWS Lambda Python para validar um CPF contra a tabela `clientes` do PostgreSQL e emitir um JWT quando o CPF existe.

A funcao nao cria API Gateway, banco, VPC ou regras do Security Group do banco. Ela depende dos repositorios `autoflow-infra` e `autoflow-db`.

## 2. Fluxo da funcao

A entrada pode ser um evento direto ou um evento com `body`:

1. A funcao le o CPF do evento.
2. Se necessario, decodifica `body` Base64.
3. Se o body for string JSON, faz o parse.
4. Remove pontuacao e caracteres nao numericos.
5. Exige exatamente 11 digitos.
6. Abre uma conexao PostgreSQL com timeout de conexao de 5 segundos.
7. Executa uma consulta parametrizada em `clientes.cpf_cnpj`.
8. Fecha cursor e conexao.
9. Se existir, gera JWT HS256 com `sub`, `cpf`, `iat` e `exp`.
10. Retorna o token como Bearer.

Respostas principais:

- `200`: CPF encontrado, token, tipo Bearer e validade.
- `400`: body invalido ou CPF com formato incorreto.
- `404`: CPF nao encontrado.
- `500`: falha de banco, JWT ou erro inesperado.

O handler esta em `handler.py` e o ponto de entrada Terraform e `handler.lambda_handler`.

## 3. Empacotamento e runtime

O script `build.ps1`:

1. Remove `build`.
2. Instala dependencias de `requirements.txt` em `build`.
3. Copia `handler.py` para `build`.
4. O Terraform compacta `build` em `lambda.zip` usando `archive_file`.

Configuracao da funcao:

- Runtime Python 3.12.
- Timeout de 15 segundos.
- Memoria de 256 MB.
- Rebuild quando `handler.py` ou `requirements.txt` muda.

Dependencias declaradas:

- `psycopg2-binary` para PostgreSQL.
- `PyJWT` para JWT.
- `boto3`, atualmente sem uso direto no handler.

## 4. Infraestrutura Terraform

O repositorio provisiona:

- AWS Lambda.
- IAM Role assumivel pelo servico Lambda.
- Politica para criar, consultar e remover ENIs.
- Security Group da Lambda.
- Pacote ZIP da funcao.
- Backend Terraform em S3.
- Leitura dos estados remotos `infra/terraform.tfstate` e `rds/terraform.tfstate`.

A funcao e conectada:

- A VPC do estado `autoflow-infra`.
- As subnets privadas do mesmo estado.
- Ao Security Group criado localmente.

O Security Group da Lambda nao possui ingress e libera egress para `0.0.0.0/0`. O Security Group do banco precisa permitir entrada originada pelo Security Group da Lambda.

## 5. Configuracao e dependencias

Variaveis importantes:

- Regiao AWS.
- Nome da funcao.
- Nome do banco.
- Usuario e senha do banco.
- Segredo JWT.
- Expiracao do JWT.

O Terraform injeta como variaveis de ambiente da Lambda:

- Host e porta do RDS obtidos do estado remoto.
- Nome do banco.
- Credenciais PostgreSQL.
- Segredo e validade do JWT.

Ordem de dependencias:

1. `autoflow-infra` cria VPC e subnets privadas.
2. `autoflow-db` cria RDS e publica endpoint/porta.
3. A regra do Security Group do RDS permite o Security Group da Lambda.
4. Este repositorio cria a funcao e injeta os outputs dos estados remotos.
5. A funcao pode ser invocada diretamente por outro componente AWS ou ferramenta de teste.

## 6. Limites do repositorio

Nao sao provisionados aqui:

- API Gateway ou URL HTTP publica.
- Autorizacao da invocacao por outro servico.
- Rate limiting ou throttling.
- Banco PostgreSQL.
- VPC, subnets e rotas.
- Secrets Manager ou Parameter Store.
- Dashboards ou alarmes dedicados.

Os outputs expostos incluem nome da funcao, Security Group e comando de invocacao.

## 7. Alteracoes futuras

Alteracoes no payload precisam preservar a compatibilidade entre evento direto e evento com `body`. Mudancas na consulta devem manter parametrizacao para evitar injecao SQL. Mudancas no JWT precisam ser coordenadas com qualquer consumidor que valide `sub`, `cpf`, emissao, expiracao ou o algoritmo.

Mudancas de rede devem ser feitas em conjunto com `autoflow-infra` e `autoflow-db`, pois a Lambda apenas consome seus estados e nao possui os recursos de rede.

## 8. Pontos de atencao

- Senha do banco e segredo JWT possuem defaults hardcoded e podem ficar no estado Terraform e no ambiente da Lambda.
- Dependencias nao estao fixadas em versoes.
- O build executado no Windows pode instalar binarios incompatíveis com o runtime Linux da Lambda, especialmente `psycopg2-binary`.
- A validacao verifica apenas 11 digitos; nao valida os digitos verificadores do CPF.
- O handler abre uma nova conexao a cada invocacao.
- Nao ha logging explicito nem permissao dedicada de logs CloudWatch descrita no Terraform.
- O egress do Security Group e amplo.
- Sem API Gateway, a funcao nao fornece por si so um endpoint HTTP publico.
