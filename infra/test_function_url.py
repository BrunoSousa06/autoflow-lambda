import pathlib
import unittest


ROOT = pathlib.Path(__file__).parent


class FunctionUrlConfigurationTest(unittest.TestCase):
    def test_url_defaults_to_iam_and_demo_is_explicitly_opt_in(self):
        variables = (ROOT / "variables.tf").read_text(encoding="utf-8")
        lambda_tf = (ROOT / "lambda.tf").read_text(encoding="utf-8")
        self.assertIn('variable "enable_lambda_function_url"', variables)
        self.assertRegex(variables, r'enable_lambda_function_url"\s*\{[^}]*default\s*=\s*true')
        self.assertRegex(variables, r'enable_academic_demo_function_url"\s*\{[^}]*default\s*=\s*false')
        self.assertIn('resource "aws_lambda_function_url" "cpf_validator"', lambda_tf)
        self.assertIn('count              = var.enable_lambda_function_url || var.enable_academic_demo_function_url ? 1 : 0', lambda_tf)
        self.assertIn('authorization_type = var.enable_academic_demo_function_url ? "NONE" : "AWS_IAM"', lambda_tf)
        self.assertIn('var.environment == "homolog"', lambda_tf)
        self.assertIn('var.academic_demo_environment_confirmed', lambda_tf)

    def test_public_permissions_are_conditional_and_limited_to_function_url(self):
        lambda_tf = (ROOT / "lambda.tf").read_text(encoding="utf-8")
        permissions = [line.strip() for line in lambda_tf.splitlines() if line.strip().startswith(("resource \"aws_lambda_permission\"", "count ", "action ", "principal ", "invoked_via_function_url", "function_url_auth_type"))]
        self.assertEqual(sum(line.startswith("count ") and "||" not in line and "var.enable_academic_demo_function_url ? 1 : 0" in line for line in permissions), 2)
        self.assertTrue(any(line.startswith("action ") and line.endswith('= "lambda:InvokeFunctionUrl"') for line in permissions))
        self.assertTrue(any(line.startswith("action ") and line.endswith('= "lambda:InvokeFunction"') for line in permissions))
        self.assertTrue(any(line.startswith("invoked_via_function_url ") and line.endswith("= true") for line in permissions))
        self.assertEqual(permissions.count('function_url_auth_type = "NONE"'), 1)

    def test_lambda_runtime_and_network_configuration_are_unchanged(self):
        lambda_tf = (ROOT / "lambda.tf").read_text(encoding="utf-8")
        function = lambda_tf.split('resource "aws_lambda_function" "cpf_validator" {', 1)[1].split("\n}", 1)[0]
        self.assertIn('runtime          = "python3.12"', function)
        self.assertIn('timeout          = 15', function)
        self.assertIn('memory_size      = 256', function)
        self.assertIn("vpc_config", function)
        self.assertIn('data.terraform_remote_state.db.outputs.lambda_security_group_id', function)

    def test_function_url_has_no_api_gateway_or_static_aws_keys(self):
        files = [path.read_text(encoding="utf-8") for path in ROOT.glob("*.tf")]
        source = "\n".join(files)
        self.assertNotIn("aws_apigatewayv2_", source)
        self.assertNotIn("aws_access_key_id", source)
        self.assertNotIn("aws_secret_access_key", source)


if __name__ == "__main__":
    unittest.main()
