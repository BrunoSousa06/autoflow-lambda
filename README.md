# AutoFlow — Lambda de Autenticação

AWS Lambda responsável pela autenticação de usuários da aplicação **AutoFlow** utilizando **CPF/CNPJ e senha**.

A função realiza a validação das credenciais diretamente no banco de dados PostgreSQL utilizado pela aplicação, gera um **JWT (JSON Web Token)** após uma autenticação bem-sucedida e disponibiliza o token para acesso às APIs protegidas do sistema.

Além do código da função serverless, este repositório também contém a infraestrutura necessária para provisionar a Lambda na AWS e permitir sua comunicação com o banco de dados **Amazon RDS PostgreSQL**.

---

## 📌 Objetivo

A Lambda tem como principal objetivo centralizar a autenticação dos usuários do AutoFlow utilizando CPF ou CNPJ como identificador.

O fluxo de autenticação é:

```text
Cliente
   │
   │ CPF/CNPJ + senha
   ▼
API Gateway
   │
   ▼
AWS Lambda
   │
   │ Consulta usuário
   ▼
Amazon RDS PostgreSQL
   │
   │ Retorna credenciais
   ▼
AWS Lambda
   │
   │ Valida senha com BCrypt
   │
   │ Gera JWT
   ▼
Cliente
   │
   │ Authorization: Bearer <token>
   ▼
APIs protegidas do AutoFlow
```

A Lambda **não realiza o cadastro de usuários**. Sua responsabilidade é validar as credenciais existentes e emitir o token de autenticação.

---

## 🔐 Processo de autenticação

A função recebe uma requisição contendo:

```json
{
  "cpf_cnpj": "12345678901",
  "senha": "senha-do-usuario"
}
```

O CPF/CNPJ pode ser enviado com ou sem formatação.

Por exemplo:

```json
{
  "cpf_cnpj": "123.456.789-01",
  "senha": "senha-do-usuario"
}
```

A Lambda remove automaticamente caracteres não nu
