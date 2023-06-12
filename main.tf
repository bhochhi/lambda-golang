terraform {
  required_version = "<= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0.0"
    }
  }
}
# Configure the AWS provider
provider "aws" {
  region = "us-east-1" # Set your desired region
}
data "aws_caller_identity" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  environment    = "v1"
  lambda_handler = "lambda-golang"
  name           = "lambda-hello"
  random_name    = "Morty"
  region         = "us-east-1"
}


data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "./bin/lambda-golang"
  output_path = "./bin/lambda-golang.zip"
}






# Create the Lambda function
resource "aws_lambda_function" "lambda-golang" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = local.name
  role             = aws_iam_role.hello_lambda_role.arn
  handler          = local.lambda_handler
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)
  runtime          = "go1.x"
  memory_size      = 1024
  timeout          = 30

  environment {
    variables = {
      RANDOM_NAME = local.random_name
    }
  }
}


data "aws_iam_policy_document" "assume_role" {
  policy_id = "${local.name}-lambda"
  version   = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Create the IAM role for the Lambda function
resource "aws_iam_role" "hello_lambda_role" {
  name               = "${local.name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

// Logs Policy
data "aws_iam_policy_document" "logs" {
  policy_id = "${local.name}-lambda-logs"
  version   = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]

    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.name}*:*"
    ]
  }
}


resource "aws_iam_policy" "logs" {
  name   = "${local.name}-lambda-logs"
  policy = data.aws_iam_policy_document.logs.json
}
resource "aws_iam_role_policy_attachment" "logs" {
  depends_on = [aws_iam_role.hello_lambda_role, aws_iam_policy.logs]
  role       = aws_iam_role.hello_lambda_role.name
  policy_arn = aws_iam_policy.logs.arn
}


// Log group
resource "aws_cloudwatch_log_group" "log" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 1
}

# Allow API gateway to invoke the hello Lambda function.
resource "aws_lambda_permission" "hello_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda-golang.arn
  principal     = "apigateway.amazonaws.com"
}



# Create the API Gateway
resource "aws_api_gateway_rest_api" "hello_lambda_api" {
  name        = local.name
  description = "hello labmda API"
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.hello_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


# Create the API Gateway resource and method
resource "aws_api_gateway_resource" "hello_resource" {
  rest_api_id = aws_api_gateway_rest_api.hello_lambda_api.id
  parent_id   = aws_api_gateway_rest_api.hello_lambda_api.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "hello_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello_lambda_api.id
  resource_id   = aws_api_gateway_resource.hello_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "endpoint" {
  rest_api_id = aws_api_gateway_rest_api.hello_lambda_api.id
  resource_id = aws_api_gateway_resource.hello_resource.id
  http_method = aws_api_gateway_method.hello_method.http_method
  status_code = "200"
}

# Create the API Gateway integration with the Lambda function
resource "aws_api_gateway_integration" "hello_lambda_integration" {
  depends_on = [aws_api_gateway_method.hello_method, aws_api_gateway_method_response.endpoint]

  rest_api_id             = aws_api_gateway_rest_api.hello_lambda_api.id
  resource_id             = aws_api_gateway_resource.hello_resource.id
  http_method             = aws_api_gateway_method.hello_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda-golang.invoke_arn
}


resource "aws_api_gateway_integration_response" "endpoint" {
  depends_on = [aws_api_gateway_integration.hello_lambda_integration]

  rest_api_id = aws_api_gateway_rest_api.hello_lambda_api.id
  resource_id = aws_api_gateway_resource.hello_resource.id
  http_method = aws_api_gateway_method.hello_method.http_method
  status_code = aws_api_gateway_method_response.endpoint.status_code

  response_templates = {
    "application/json" = ""
  }
}


# Create the API Gateway deployment
resource "aws_api_gateway_deployment" "lambda-golang" {
  depends_on = [aws_api_gateway_integration_response.endpoint]

  rest_api_id = aws_api_gateway_rest_api.hello_lambda_api.id
  description = "Deployed endpoint at ${timestamp()}"
}
resource "aws_api_gateway_stage" "lambda-golang" {
  stage_name    = local.environment
  rest_api_id   = aws_api_gateway_rest_api.hello_lambda_api.id
  deployment_id = aws_api_gateway_deployment.lambda-golang.id
}

resource "aws_lambda_permission" "lambda-golang" {
  statement_id  = "${local.name}-AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name =  aws_lambda_function.lambda-golang.arn
  principal = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:${local.region}:${local.account_id}:${aws_api_gateway_rest_api.hello_lambda_api.id}/*/${aws_api_gateway_method.hello_method.http_method}${aws_api_gateway_resource.hello_resource.path}"
}


module "cors" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.hello_lambda_api.id
  api_resource_id = aws_api_gateway_resource.hello_resource.id

  allow_headers = [
    "Authorization",
    "Content-Type",
    "X-Amz-Date",
    "X-Amz-Security-Token",
    "X-Api-Key",
    "X-Charge"
  ]
}
