import base64
import json
import os
import re
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
import psycopg2


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(body),
    }


def _request_body(event):
    body = event.get("body", event)

    if isinstance(body, str):
        if event.get("isBase64Encoded"):
            body = base64.b64decode(body).decode("utf-8")

        return json.loads(body)

    return body


def _cpf_digits(cpf):
    return re.sub(r"\D", "", str(cpf or ""))


def _get_connection():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "autoflow_db"),
        user=os.environ["DB_USERNAME"],
        password=os.environ["DB_PASSWORD"],
        connect_timeout=5,
    )


def _find_user_by_cpf(cpf):
    connection = _get_connection()

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    c.id AS cliente_id,
                    c.cpf_cnpj,
                    u.id AS usuario_id,
                    u.senha,
                    u.role
                FROM clientes c
                INNER JOIN usuarios u
                    ON u.id = c.usuario_id
                WHERE c.cpf_cnpj = %s
                """,
                (cpf,),
            )

            row = cursor.fetchone()

            if not row:
                return None

            return {
                "cliente_id": row[0],
                "cpf_cnpj": row[1],
                "usuario_id": row[2],
                "senha": row[3],
                "role": row[4],
            }

    finally:
        connection.close()


def _password_matches(password, password_hash):
    if not password_hash:
        return False

    try:
        return bcrypt.checkpw(
            password.encode("utf-8"),
            password_hash.encode("utf-8"),
        )
    except (ValueError, TypeError):
        return False


def _generate_token(user):
    now = datetime.now(timezone.utc)

    expires_in = int(
        os.getenv("JWT_EXPIRES_IN_SECONDS", "3600")
    )

    payload = {
        "sub": user["cpf_cnpj"],
        "cpf": user["cpf_cnpj"],
        "clienteId": user["cliente_id"],
        "usuarioId": user["usuario_id"],
        "role": user["role"],
        "iat": now,
        "exp": now + timedelta(seconds=expires_in),
    }

    return jwt.encode(
        payload,
        os.environ["JWT_SECRET"],
        algorithm="HS256",
    ), expires_in


def lambda_handler(event, context):
    try:
        payload = _request_body(event)

        if not isinstance(payload, dict):
            return _response(
                400,
                {"message": "O corpo da requisição deve ser um JSON válido."},
            )

        cpf = _cpf_digits(payload.get("cpf"))
        senha = payload.get("senha")

    except (TypeError, ValueError, json.JSONDecodeError):
        return _response(
            400,
            {"message": "O corpo da requisição é inválido."},
        )

    if len(cpf) != 11:
        return _response(
            400,
            {"message": "O CPF deve conter 11 dígitos."},
        )

    if not senha or not isinstance(senha, str):
        return _response(
            400,
            {"message": "A senha é obrigatória."},
        )

    try:
        user = _find_user_by_cpf(cpf)

        # Não diferencia CPF inexistente de senha incorreta.
        if not user:
            return _response(
                401,
                {"message": "CPF ou senha inválidos."},
            )

        if not _password_matches(
            senha,
            user["senha"],
        ):
            return _response(
                401,
                {"message": "CPF ou senha inválidos."},
            )

        token, expires_in = _generate_token(user)

        return _response(
            200,
            {
                "token": token,
                "tokenType": "Bearer",
                "expiresIn": expires_in,
            },
        )

    except psycopg2.Error:
        return _response(
            500,
            {"message": "Erro ao acessar o banco de dados."},
        )

    except Exception:
        return _response(
            500,
            {"message": "Não foi possível realizar a autenticação."},
        )