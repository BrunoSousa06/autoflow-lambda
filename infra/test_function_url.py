import pathlib
import unittest


ROOT = pathlib.Path(__file__).parent


class FunctionUrlConfigurationTest(unittest.TestCase):
    def test_url_is_conditional_and_iam_protected(self):
        variables = (ROOT / "variables.tf").read_text(encoding="utf-8")
        lambda_tf = (ROOT / "lambda.tf").read_text(encoding="utf-8")
        self.assertIn('variable "enable_lambda_function_url"', variables)
        self.assertRegex(variables, r'enable_lambda_function_url"\s*\{[^}]*default\s*=\s*false')
        self.assertIn('resource "aws_lambda_function_url" "cpf_validator"', lambda_tf)
        self.assertIn('count              = var.enable_lambda_function_url ? 1 : 0', lambda_tf)
        self.assertIn('authorization_type = "AWS_IAM"', lambda_tf)
        self.assertNotIn('authorization_type = "NONE"', lambda_tf)

    def test_function_url_has_no_api_gateway_or_static_aws_keys(self):
        files = [path.read_text(encoding="utf-8") for path in ROOT.glob("*.tf")]
        source = "\n".join(files)
        self.assertNotIn("aws_apigatewayv2_", source)
        self.assertNotIn("aws_access_key_id", source)
        self.assertNotIn("aws_secret_access_key", source)


if __name__ == "__main__":
    unittest.main()
