from handler import lambda_handler
import json

import os

os.environ["DB_HOST"] = "127.0.0.1"
os.environ["DB_PORT"] = "5432"
os.environ["DB_NAME"] = "autoflow_db"
os.environ["DB_USERNAME"] = "postgres"
os.environ["DB_PASSWORD"] = "postgres"
os.environ["JWT_SECRET"] = "8aF3mK9pQ2xV7nRt5YcW1zLb4DsH6jTe0UrN8gXp3CvM7qAz9FkP2hYs6BwLd4Xe"
os.environ["JWT_EXPIRES_IN_SECONDS"] = "3600"


event = {
    "body": json.dumps({
        "cpf_cnpj": "52998224725",
        "senha": "Senha@1234"
    }),
    "isBase64Encoded": False
}

response = lambda_handler(event, None)

print(response)