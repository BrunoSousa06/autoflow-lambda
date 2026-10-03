import base64
import json
import os
import unittest
from unittest.mock import patch

import psycopg2

from handler import lambda_handler


class LambdaHandlerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ["JWT_SECRET"] = "test-secret"
        os.environ["JWT_EXPIRES_IN_SECONDS"] = "3600"

    @staticmethod
    def gateway_event(body, encoded=False):
        serialized_body = json.dumps(body) if not isinstance(body, str) else body

        if encoded:
            serialized_body = base64.b64encode(serialized_body.encode("utf-8")).decode("ascii")

        return {
            "version": "2.0",
            "routeKey": "POST /auth/login",
            "rawPath": "/auth/login",
            "body": serialized_body,
            "isBase64Encoded": encoded,
            "requestContext": {},
        }

    @staticmethod
    def response_body(response):
        return json.loads(response["body"])

    def test_deve_emitir_token_para_login_valido_via_api_gateway(self):
        user = {
            "usuario_id": 1,
            "cpf_cnpj": "52998224725",
            "senha": "hash",
            "role": "CLIENTE",
        }

        with patch("handler._find_user_by_document", return_value=user) as find_user, patch(
            "handler._password_matches", return_value=True
        ), patch("handler._generate_token", return_value=("jwt-token", 3600)):
            response = lambda_handler(
                self.gateway_event(
                    {"cpf_cnpj": "529.982.247-25", "senha": "Senha@1234"},
                    encoded=True,
                ),
                None,
            )

        self.assertEqual(response["statusCode"], 200)
        self.assertEqual(self.response_body(response)["token"], "jwt-token")
        self.assertEqual(self.response_body(response)["tokenType"], "Bearer")
        find_user.assert_called_once_with("52998224725")

    def test_deve_retornar_400_para_json_invalido(self):
        response = lambda_handler(self.gateway_event("{"), None)

        self.assertEqual(response["statusCode"], 400)
        self.assertEqual(
            self.response_body(response)["message"],
            "O corpo da requisição é inválido.",
        )

    def test_deve_retornar_400_para_documento_invalido(self):
        response = lambda_handler(
            self.gateway_event({"cpf_cnpj": "123", "senha": "Senha@1234"}),
            None,
        )

        self.assertEqual(response["statusCode"], 400)
        self.assertIn("11 dígitos", self.response_body(response)["message"])

    def test_deve_retornar_401_para_credenciais_invalidas(self):
        with patch("handler._find_user_by_document", return_value=None):
            response = lambda_handler(
                self.gateway_event(
                    {"cpf_cnpj": "52998224725", "senha": "Senha@1234"}
                ),
                None,
            )

        self.assertEqual(response["statusCode"], 401)
        self.assertEqual(
            self.response_body(response)["message"],
            "CPF/CNPJ ou senha inválidos.",
        )

    def test_deve_retornar_500_quando_banco_falhar(self):
        with patch(
            "handler._find_user_by_document",
            side_effect=psycopg2.Error("database unavailable"),
        ):
            response = lambda_handler(
                self.gateway_event(
                    {"cpf_cnpj": "52998224725", "senha": "Senha@1234"}
                ),
                None,
            )

        self.assertEqual(response["statusCode"], 500)
        self.assertEqual(
            self.response_body(response)["message"],
            "Erro ao acessar o banco de dados.",
        )


if __name__ == "__main__":
    unittest.main()
