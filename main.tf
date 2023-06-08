

# Configure the AWS provider
provider "aws" {
  region = "us-east-1"  # Set your desired region
}

# Create the Lambda function
resource "aws_lambda_function" "hello_lambda" {
  filename         = "hello_lambda.zip"
  function_name    = "hello_lambda"
  role             = aws_iam_role.hello_lambda_role.arn
  handler          = "main"
  runtime          = "go1.x"
  source_code_hash = sha256(filebase64("hello_lambda.zip"))
}

# Create the IAM role for the Lambda function
resource "aws_iam_role" "hello_lambda_role" {
  name = "hello_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach the necessary IAM policy to the Lambda role
resource "aws_iam_role_policy_attachment" "AWSLambdaBasicExecutionRole" {
  role       = aws_iam_role.hello_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach the necessary IAM policy to the Lambda role
resource "aws_iam_role_policy_attachment" "describe-my-ec2" {
  role       = aws_iam_role.hello_lambda_role.name
  policy_arn = "arn:aws:iam::610591786715:policy/describe-my-ec2"
}

# Create the API Gateway
resource "aws_api_gateway_rest_api" "hello_lambda_api" {
  name        = "hello_lambda_api"
  description = "Example API"
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

# Create the API Gateway integration with the Lambda function
resource "aws_api_gateway_integration" "hello_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.hello_lambda_api.id
  resource_id             = aws_api_gateway_resource.hello_resource.id
  http_method             = aws_api_gateway_method.hello_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello_lambda.invoke_arn
}

# Create the API Gateway deployment
resource "aws_api_gateway_deployment" "hello_lambda_deployment" {
  depends_on  = [aws_api_gateway_integration.hello_lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.hello_lambda_api.id
  stage_name  = "test"
}

# Output the API Gateway endpoint URL
output "api_endpoint" {
  value = aws_api_gateway_deployment.hello_lambda_deployment.invoke_url
}
