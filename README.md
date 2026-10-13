# AutoFlow — Lambda de autenticação

Este repositório contém uma função AWS Lambda que valida CPF/CNPJ e senha usando PostgreSQL e emite o JWT consumido pelas APIs protegidas. A arquitetura pretendida é Frontend Angular → Kong OSS no EKS → AWS Lambda → PostgreSQL RDS privado. O handler e o Terraform descrevem a implementação local; a existência e a execução dos recursos na AWS precisam ser verificadas separadamente.

O Terraform deste repositório não declara AWS API Gateway. O modo acadêmico pode mudar temporariamente a autorização da Function URL existente para `NONE`; esse modo e as permissões públicas correspondentes ficam desabilitados por padrão. A integração pela rota do Kong permanece bloqueada até aprovação da exposição e TLS público. Consulte [operações do Kong](../autoflow/docs/kong-gateway-operations.md) e a [especificação de demonstração](../docs/specs/kong-lambda-function-url/implementacao-demonstracao.md).

O `JWT_SECRET` da Lambda deve corresponder ao fornecido ao backend. O token usa HS256, contém o CPF/CNPJ normalizado no claim `sub` e o backend consulta o perfil atual do usuário no banco; o claim `role` do token não concede permissões.

Para o perfil `CLIENTE`, a Lambda exige registro correspondente em `clientes` com `status = ATIVO`. Cliente inexistente ou inativo recebe a mesma resposta `401` de credencial inválida e nenhum token é emitido.

## Contrato de login

`POST /auth/login` é uma rota pública. O corpo deve ser JSON:

```json
{
  "cpf_cnpj": "cpf-ou-cnpj-sintetico",
  "senha": "senha-do-usuario"
}
```

O documento pode conter pontuação. A resposta de sucesso é `200`:

```json
{
  "token": "<jwt>",
  "tokenType": "Bearer",
  "expiresIn": 3600
}
```

| Status | Situação | Resposta observada |
|---|---|---|
| `400` | JSON, documento ou senha inválidos | Mensagem de validação |
| `401` | CPF/CNPJ ou senha incorretos, cliente inexistente/inativo | `CPF/CNPJ ou senha inválidos.` |
| `500` | Falha interna ao consultar o banco | `Erro ao acessar o banco de dados.` |

## Infraestrutura declarada

`infra/lambda.tf` declara a função de autenticação em Python 3.12, empacotamento local do código, timeout de 15 segundos, execução nas subnets privadas recebidas do state de infraestrutura, Security Group recebido do state RDS e variáveis de ambiente para banco e JWT. `var.role_arn` continua sendo fornecida externamente; este Terraform não cria nem altera a role de execução. `enable_lambda_function_url=true` por padrão preserva a URL homologada existente no state sob `AWS_IAM`; `enable_academic_demo_function_url=false` por padrão. No modo acadêmico a mesma URL muda para `NONE` e são criadas duas permissões `Principal="*"` condicionadas à invocação via Function URL. Não altera handler, Lambda, VPC ou RDS. Os valores de credenciais são inputs Terraform; não os registre em documentação, logs ou arquivos versionados.

### Integração Kong e IAM

O plugin `aws-lambda` precisa obter credenciais temporárias por uma identidade IAM associada ao workload Kong no EKS (por exemplo, IRSA ou EKS Pod Identity, conforme a configuração adotada). Credenciais AWS estáticas não devem ser configuradas no Kong. A identidade de invocação do Kong é distinta da `var.role_arn`, que é a role de execução da Lambda e deve continuar externa. A política da identidade do Kong precisa permitir `lambda:InvokeFunction` somente para o ARN da função/ambiente necessário.

Para invocação na mesma conta, a autorização pode ser concedida pela política identity-based da identidade do Kong e, em geral, não é necessária `aws_lambda_permission`. Se o Kong invocar uma função em outra conta, a política resource-based da Lambda também precisará autorizar a identidade específica do Kong; nesse cenário uma `aws_lambda_permission` pode ser necessária, restrita ao principal/ARN apropriado. A topologia de contas e o método de identidade ainda precisam ser confirmados antes de decidir ou criar essa permissão. Não criar permissão pública ou irrestrita. A pendência de identidade/política IAM do Kong, incluindo `lambda:InvokeFunction`, impede considerar a integração concluída.

O Learner Lab pode limitar a criação/configuração de roles, políticas, IRSA/Pod Identity ou permissões Lambda, além de usar credenciais temporárias com expiração. A autorização da role externa de execução Lambda e a identidade do Kong devem ser verificadas no ambiente autorizado; não presumir que a role disponível no Lab possa assumir ambas as responsabilidades.

Function URLs usam eventos e respostas compatíveis com payload HTTP API v2.0. O handler consome `body` e `isBase64Encoded` e devolve `statusCode`, `headers` e `body`; a AWS converte os campos em resposta HTTP. `AWS_IAM` exige SigV4 por chamada e permissões `lambda:InvokeFunctionUrl` e `lambda:InvokeFunction`. `NONE` admite invocação sem assinatura: a URL é publicamente invocável diretamente pela Internet e não fica restrita ao Kong. No modo acadêmico são declaradas `lambda:InvokeFunctionUrl` com condição `lambda:FunctionUrlAuthType=NONE` e `lambda:InvokeFunction` com `lambda:InvokedViaFunctionUrl=true`. Ao desativar o modo, Terraform remove as permissões e restaura `AWS_IAM`. Use somente CPFs/CNPJs fictícios e senhas de teste; nunca use conta real ou dados de produção. Não usar segredo compartilhado como falsa garantia de isolamento. O modo não é adequado para produção.

### Ativação e rollback do modo acadêmico

Faça apenas Plan localmente e solicite revisão/aprovação antes de qualquer Apply. Confirme state/conta por mecanismo operacional já aprovado e não exponha segredos no terminal. No PowerShell, a ativação planejada é:

```powershell
Set-Location .\autoflow-lambda
bash ./build.sh
Set-Location .\infra
$env:TF_VAR_academic_demo_environment_confirmed = "true"
terraform plan -var="enable_lambda_function_url=true" -var="enable_academic_demo_function_url=true" -var="academic_demo_environment_confirmed=true" -out=demo.tfplan
terraform show -no-color demo.tfplan
# Apply somente após aprovação explícita do plan revisado:
# terraform apply demo.tfplan
```

O Plan deve mostrar atualização da URL existente de `AWS_IAM` para `NONE` e duas permissões públicas limitadas ao uso da Function URL; não deve substituir/destroçar `aws_lambda_function_url`, alterar `aws_lambda_function` ou tocar em VPC/RDS. O rollback, preferencialmente imediato após o teste, é:

```powershell
terraform plan -var="enable_lambda_function_url=true" -var="enable_academic_demo_function_url=false" -var="academic_demo_environment_confirmed=false" -out=rollback.tfplan
terraform show -no-color rollback.tfplan
# Após aprovação do plan de rollback:
# terraform apply rollback.tfplan
```

O rollback esperado atualiza a mesma URL para `AWS_IAM` e remove ambas as permissões acadêmicas; confirme no Plan que não sobra `Principal="*"` de demonstração. Não desligue `enable_lambda_function_url` em homologação. A expiração da sessão Learner Lab pode impedir rollback imediato; não há garantia de execução automática.

O Kong atual publica NLB `internet-facing` e não tem certificado público válido comprovado. A rota de autenticação não será habilitada nesse NLB. HTTP público não é adequado para transmitir senhas reais. A chamada direta da Function URL também continua acessível fora do Kong enquanto `NONE` estiver ativo.

### State e pipeline

Não foi encontrado arquivo de State Terraform no checkout local. O State S3 configurado externamente pelo pipeline não foi lido nesta alteração, portanto não é possível confirmar se ele contém endereços `aws_apigatewayv2_*` ou `aws_lambda_permission.api_gateway`. Como a remoção desses endereços da configuração pode resultar em destruição no próximo apply, o pipeline foi limitado a validar e gerar plan e não executa apply automático. Antes de habilitar apply, inspecione o State remoto correto e revise o plan; se houver recursos legados, avalie a estratégia de retirada/importação do State e o impacto no tráfego, sem aprovar destruição antes dessa confirmação.

`infra/backend.tf` declara o backend S3 do State Terraform; não há dependência de API Gateway nele. O workflow configura bucket e key por GitHub Actions Variables (`AWS_TERRAFORM_STATE_BUCKET` e `AWS_TF_STATE_KEY` no environment GitHub `homolog`/`production`) e não depende de arquivos tfvars versionados. Inputs não sensíveis usam `TF_VAR_*` originados de GitHub Variables; credenciais AWS e valores sensíveis requeridos pelo código usam GitHub Secrets. A existência/ownership dos states remotos, recursos AWS e autorização efetiva não foram confirmados por este README.

## Execução local e testes

Pré-requisitos: Python 3.12. O Terraform local depende também da configuração do state e dos dados remotos referenciados em `infra/data.tf`.

Para configurar uma execução local, defina no ambiente do processo `AWS_PROFILE`, `AWS_REGION`, `AWS_EXPECTED_ACCOUNT_ID`, `TF_VAR_aws_allowed_account_ids` (JSON de uma lista), `TF_VAR_aws_profile`, `TF_VAR_terraform_state_bucket`, `TF_VAR_infra_state_key`, `TF_VAR_rds_state_key` e os valores `TF_VAR_*` obrigatórios de role/banco/JWT pelo mecanismo local seguro. O guard `scripts/verify_aws_account.py` deve ser executado antes de qualquer operação AWS. O backend pode ser configurado sem arquivo auxiliar com `terraform init -backend-config="bucket=$TF_STATE_BUCKET" -backend-config="key=$TF_STATE_KEY" -backend-config="region=$AWS_REGION" -backend-config="encrypt=true" -backend-config="use_lockfile=true"`; use somente bucket/key aprovados e state reconciliado.

```bash
python -m pip install -r requirements.txt
python -m unittest discover -s . -p "test_*.py" -v
```

### Empacotamento e ciclo Terraform

O `build.sh` cria `lambda.zip` reproduzível para Linux x86-64/Python 3.12. Execute sempre nesta ordem: **build → Terraform Plan → revisão integral do plano → Apply autorizado**. O Terraform consome diretamente `lambda.zip`; ele não reinstala dependências nem recompacota `build/`. O pipeline cria o ZIP no job de Plan antes de inicializar/planejar Terraform. O Apply não é automático e só deve ocorrer após aprovação explícita do plano e confirmação do state/conta/ambiente.

```bash
bash ./build.sh
cd infra
terraform init -input=false -reconfigure \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="key=$TF_STATE_KEY" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"
terraform plan -input=false -out=autoflow-lambda.tfplan
terraform show -no-color autoflow-lambda.tfplan
# Somente após revisar e obter autorização explícita:
terraform apply -input=false autoflow-lambda.tfplan
```

Proteja o plan file, pois pode conter dados sensíveis; não o versione nem publique. Revise integralmente o plano e o state antes de qualquer Apply; execute Apply somente com autorização explícita e usando exatamente o plano revisado. O pipeline não executa Apply automático. O arquivo `lambda.zip`, a pasta `build/` e os plans são artefatos locais ignorados pelo Git e precisam existir ou ser gerados na sequência apropriada.

Para uma invocação manual, substitua `<NOME_DA_FUNCAO>` pelo nome retornado pelo output `lambda_function_name`. O payload abaixo usa valores fictícios apenas para ilustrar o formato; não representa credenciais válidas:

```bash
aws lambda invoke \
  --function-name <NOME_DA_FUNCAO> \
  --cli-binary-format raw-in-base64-out \
  --payload '{"cpf_cnpj":"00000000000","senha":"SENHA_FICTICIA_NAO_UTILIZAR"}' \
  response.json
```

Validação estática do Terraform, somente após confirmar as dependências locais e providers:

```bash
cd infra
terraform init -backend=false -input=false
terraform validate
```

Não execute `terraform plan` ou `terraform apply` contra AWS sem confirmar conta, perfil, states e autorização. Validação local de handler/infraestrutura não equivale a invocação ou deploy na AWS.
