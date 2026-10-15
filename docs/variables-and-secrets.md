# Variables e secrets

Catálogo necessário para o workflow versionado. CI em PR/push roda sem AWS credentials; o plan automático não entra no Environment para não aguardar aprovação. Portanto, configure as variables e secrets AWS/runtime como configurações do repositório (disponíveis nos jobs), ou use secrets/variables de organização acessíveis ao repositório. O job Apply entra no Environment `homolog`, que deve ter Required reviewers configurados. A aprovação nativa é a barreira do job `environment: homolog`; a variable de aprovação abaixo é somente um guard adicional.

## GitHub Actions — Secrets

| Nome | Tipo / finalidade | Onde configurar; origem | CI / CD | Exemplo seguro | Consumidor; default/ausência |
|---|---|---|---|---|---|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | Secrets; credenciais temporárias da mesma sessão AWS | Repository secrets (ou organização acessível ao repositório); sessão AWS Academy Learner Lab | Plan e Apply | Não aplicável | `.github/workflows/pipeline.yml`; obrigatórios e usados em `configure-aws-credentials`. |
| `DATABASE_USERNAME`, `DATABASE_PASSWORD` | Secrets; credenciais de conexão DB Lambda | Repository secrets (ou organização acessível ao repositório); credenciais do usuário de homolog | Plan e Apply/runtime | Não aplicável | Workflow → `TF_VAR_db_username/password` → Lambda; sem defaults, sensíveis. |
| `JWT_SECRET` | Secret; chave HS256 de assinatura JWT | Repository secret (ou organização acessível ao repositório); segredo compatível com backend | Plan e Apply/runtime | Não aplicável | Workflow → `TF_VAR_jwt_secret`; obrigatório, sem default; Terraform valida mínimo de 32 caracteres. |

## GitHub Actions — Variables

| Nome | Finalidade | Onde; origem | CI / CD | Exemplo seguro | Consumidor; default/ausência |
|---|---|---|---|---|---|
| `AWS_REGION` | Região AWS | Repository variable | Plan e Apply | `us-east-1` | Workflow/provider/backend; validada contra a região esperada. |
| `AWS_EXPECTED_ACCOUNT_ID` | Conta esperada pelo guard | Repository variable | Plan e Apply | `108798852045` | Workflow compara com `sts get-caller-identity`. |
| `AWS_TERRAFORM_STATE_BUCKET` | Bucket de states Terraform existente | Repository variable | Plan e Apply | `autoflow-tfstate-learnerlab-108798852045-us-east-1` | Workflow/backend; validado e usado sem criar bucket. |
| `AWS_TF_STATE_KEY` | Key state próprio Lambda | Repository variable | Plan e Apply | `lambda/terraform.tfstate` | Backend do workflow; validada e preservada. |
| `AWS_INFRA_STATE_KEY`, `AWS_RDS_STATE_KEY` | Keys remotas EKS e RDS | Repository variables | Plan e Apply | `eks/terraform.tfstate`; `rds/terraform.tfstate` | Workflow valida objetos e Terraform lê data sources; preservadas. |
| `AWS_LAMBDA_EXECUTION_ROLE_ARN` | Role de execução Lambda | Repository variable; ARN aprovado | Plan e Apply | `arn:aws:iam::108798852045:role/<role-existente>` | Workflow → `TF_VAR_role_arn`; valida não vazio. |
| `TERRAFORM_APPLY_APPROVAL_CONFIGURED` | Guard operacional adicional | Environment variable `homolog`; `true` somente após configurar Required reviewers | Apply | `true` | Ausente/diferente bloqueia Apply; não substitui a proteção nativa do Environment. |

## Terraform inputs — `infra/variables.tf`

| Input | Tipo / finalidade | Obrigatoriedade / default | Origem/consumidor |
|---|---|---|---|
| `region` | Região AWS | Opcional; `us-east-1` | GitHub `AWS_REGION` via `TF_VAR_region`. |
| `aws_profile` | Perfil AWS local | Opcional; `null` | Credenciais do processo; workflow não injeta. |
| `aws_allowed_account_ids` | Lista de contas autorizadas | Obrigatório; sem default; valida lista não vazia e IDs de 12 dígitos | Workflow transforma `AWS_EXPECTED_ACCOUNT_ID` em lista. |
| `environment` | Nome ambiente Lambda | Opcional; `homolog`; aceita homolog/production no Terraform | Workflow fixa `TF_VAR_environment=homolog`. |
| `lambda_name` | Nome base função | Opcional; `autoflow-cpf-validator` | Terraform. |
| `db_name` | Nome DB | Opcional; `autoflow_db` | Terraform/runtime. |
| `db_username`, `db_password` | Usuário e senha DB | Obrigatórios; sem defaults; sensíveis | Secrets `DATABASE_USERNAME/PASSWORD`. |
| `jwt_secret` | Segredo HS256 | Obrigatório; sem default; sensível; mínimo 32 caracteres | Secret `JWT_SECRET`. |
| `jwt_expires_in_seconds` | Duração JWT | Opcional; `3600`, deve ser > 0 | Terraform/runtime; handler tem fallback `3600`. |
| `role_arn` | Role de execução | Opcional `null` no Terraform | GitHub `AWS_LAMBDA_EXECUTION_ROLE_ARN`; obrigatório operacionalmente no workflow. |
| `terraform_state_bucket` | Bucket de states | Opcional no Terraform; default `state-autoflow-terraform` | Workflow injeta `AWS_TERRAFORM_STATE_BUCKET`, exigido operacionalmente. |
| `infra_state_key`, `rds_state_key` | Keys remotas | Defaults `infra/terraform.tfstate`, `rds/terraform.tfstate` | Variables GitHub `AWS_INFRA_STATE_KEY`, `AWS_RDS_STATE_KEY`; checadas pelo workflow. |

## Runtime da função e configuração local

| Nome | Tipo / finalidade | Onde configurar; origem | CI / CD | Exemplo seguro | Consumidor; default/ausência |
|---|---|---|---|---|---|
| `DB_HOST` | Variável de aplicação; host PostgreSQL | Variáveis de ambiente Lambda/local; output do state RDS | CI não; CD/runtime | `db.example.invalid` | `handler.py`; obrigatória, acesso direto `os.environ`. |
| `DB_PORT`, `DB_NAME` | Variáveis de aplicação; porta e database | Runtime/local | CI não; CD/runtime | `5432`, `autoflow_db` | `handler.py`; defaults `5432`, `autoflow_db`. Terraform input `db_name` define o database. |
| `DB_USERNAME`, `DB_PASSWORD` | Variáveis de aplicação; autenticação DB | Runtime derivado do Secret; local via ambiente seguro | CI não; CD/runtime | Não aplicável | `handler.py`; obrigatórias. GitHub usa `DATABASE_USERNAME/PASSWORD`, Terraform recebe `db_username/password` e configuração Lambda usa nomes `DB_*`. |
| `JWT_SECRET`, `JWT_EXPIRES_IN_SECONDS` | Variáveis de aplicação; assinatura e duração JWT | Runtime Lambda/local seguro | CI não; CD/runtime | Não aplicável; `3600` | `handler.py`; segredo obrigatório, duração default `3600`; alinhamento de segredo com backend necessário. |

`pipeline.yml` executa CI em PRs para `develop`/`main` e pushes nessas branches. Push em `develop` executa CI → Plan; Apply usa o plano da mesma execução, espera aprovação manual do Environment `homolog`, valida SHA-256 e repete o guard. O artifact é confidencial e retido por um dia. Nenhum bucket/state é criado ou migrado; não há Apply em PR nem deploy de produção.

**Divergências:** os secrets `DATABASE_USERNAME/PASSWORD` são mapeados para Terraform `db_username/password`, mas o runtime Lambda lê `DB_USERNAME/PASSWORD`. Terraform `environment` aceita `production`, enquanto o workflow fixa `homolog`; essa aceitação no código não habilita deploy de produção. Terraform `terraform_state_bucket` tem default, mas o workflow exige variável explícita. O backend API Gateway correspondente configura Lambda no repositório `autoflow-infra` (`AWS_LAMBDA_FUNCTION_NAME`).

**Fontes:** `.github/workflows/pipeline.yml`, `infra/variables.tf`, `infra/lambda.tf`, `handler.py`, `build.sh`, `README.md`.
