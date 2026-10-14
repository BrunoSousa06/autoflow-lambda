# Variables e secrets

Catálogo observado no workflow, Terraform e runtime da função. O deploy configurado é somente `homolog`; produção é planejada para outra branch. CI em push/PR não exige secrets nem variables GitHub. O job Terraform usa Environment `homolog`; existência e proteções reais não foram verificadas.

## GitHub Actions — Secrets

| Nome | Tipo / finalidade | Onde configurar; origem | CI / CD | Exemplo seguro | Consumidor; default/ausência |
|---|---|---|---|---|---|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | Secrets; credenciais temporárias da mesma sessão AWS | Environment `homolog`; sessão AWS Academy Learner Lab | CD | Não aplicável | `.github/workflows/pipeline.yml`; obrigatórios no job AWS, sem defaults. |
| `DATABASE_USERNAME`, `DATABASE_PASSWORD` | Secrets; credenciais de conexão DB Lambda | Environment `homolog`; credenciais do usuário de homolog | CD/runtime | Não aplicável | Workflow → `TF_VAR_db_username/password` → Lambda; sem defaults, sensíveis. |
| `JWT_SECRET` | Secret; chave HS256 de assinatura JWT | Environment `homolog`; segredo compatível com backend | CD/runtime | Não aplicável | Workflow → `TF_VAR_jwt_secret`; obrigatório, sem default; Terraform valida mínimo de 32 caracteres. |

## GitHub Actions — Variables

| Nome | Finalidade | Onde; origem | CI / CD | Exemplo seguro | Consumidor; default/ausência |
|---|---|---|---|---|---|
| `AWS_REGION` | Região AWS | Environment `homolog` | CD | `us-east-1` | Workflow/provider/backend; obrigatória, sem default efetivo no job. |
| `AWS_EXPECTED_ACCOUNT_ID` | Conta esperada pelo guard | Environment `homolog` | CD | `123456789012` | Workflow/scripts; obrigatória. |
| `AWS_TERRAFORM_STATE_BUCKET` | Bucket state Terraform | Environment `homolog` | CD | `autoflow-tfstate-homolog-exemplo` | Workflow/backend/input; obrigatório, apesar de Terraform declarar default local. |
| `AWS_TF_STATE_KEY` | Key state próprio Lambda | Environment `homolog` | CD | `homolog/lambda/terraform.tfstate` | Backend do workflow; obrigatória, sem default no workflow. |
| `AWS_INFRA_STATE_KEY`, `AWS_RDS_STATE_KEY` | Keys remotas VPC/EKS e RDS | Environment `homolog` | CD | `homolog/infra/terraform.tfstate`; `homolog/rds/terraform.tfstate` | Workflow checa existência; Terraform usa data sources; sem defaults efetivos de workflow. |
| `AWS_LAMBDA_EXECUTION_ROLE_ARN` | Role de execução Lambda | Environment `homolog`; ARN aprovado | CD | `arn:aws:iam::123456789012:role/exemplo-lambda` | Workflow → `TF_VAR_role_arn`; Terraform permite null localmente, mas workflow valida não vazio. |
| `TERRAFORM_APPLY_APPROVAL_CONFIGURED` | Guard adicional Apply | Environment `homolog`; `true` após required reviewers | CD quando `deploy=true` | `true` | Workflow; ausente/diferente bloqueia Apply; não substitui required reviewers. |

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

`pipeline.yml` inputs `deploy` e `allow_destructive` têm default `false`. O job de plan só roda em `workflow_dispatch` na branch `develop`; não se documenta produção como deploy implementado. O zip/package é construído no CI, sem valores de deploy.

**Divergências:** os secrets `DATABASE_USERNAME/PASSWORD` são mapeados para Terraform `db_username/password`, mas o runtime Lambda lê `DB_USERNAME/PASSWORD`. Terraform `environment` aceita `production`, enquanto o workflow fixa `homolog`; essa aceitação no código não habilita deploy de produção. Terraform `terraform_state_bucket` tem default, mas o workflow exige variável explícita. O backend API Gateway correspondente configura Lambda no repositório `autoflow-infra` (`AWS_LAMBDA_FUNCTION_NAME`).

**Fontes:** `.github/workflows/pipeline.yml`, `infra/variables.tf`, `infra/lambda.tf`, `handler.py`, `build.sh`, `README.md`.
