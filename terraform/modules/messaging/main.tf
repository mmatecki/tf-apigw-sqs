resource "aws_api_gateway_rest_api" "this" {
  name        = var.apigw_name
  description = "Allows publish messages to SQS queue with HTTP REST call"
  endpoint_configuration {
    types = ["PRIVATE"]
  }
  policy = data.template_file.apigw_vpc_policy.rendered
}

resource "aws_api_gateway_resource" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "messages"
}

resource "aws_api_gateway_method" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this.id
  http_method   = "POST"
  authorization = "NONE"
  request_models = {
    "application/json" = aws_api_gateway_model.this.name
  }
  request_validator_id = aws_api_gateway_request_validator.this.id
}


resource "aws_api_gateway_integration" "this" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.this.id
  http_method             = aws_api_gateway_method.this.http_method
  type                    = "AWS"
  integration_http_method = "POST"

  uri                  = "arn:aws:apigateway:${var.region}:sqs:path/${aws_sqs_queue.this.name}"
  passthrough_behavior = "NEVER"
  credentials          = aws_iam_role.this.arn

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($util.escapeJavaScript($input.json('$')))"
  }
}

resource "aws_api_gateway_method_response" "publish_message_ok_200" {
  depends_on  = [aws_api_gateway_method.this]
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this.id
  http_method = aws_api_gateway_method.this.http_method
  status_code = "201"
}

resource "aws_api_gateway_method_response" "publish_message_fail_5xx" {
  depends_on  = [aws_api_gateway_method.this]
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this.id
  http_method = aws_api_gateway_method.this.http_method
  status_code = "500"
}

resource "aws_api_gateway_method_response" "publish_message_fail_4xx" {
  depends_on  = [aws_api_gateway_method.this]
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this.id
  http_method = aws_api_gateway_method.this.http_method
  status_code = "400"
}

resource "aws_api_gateway_integration_response" "publish_message" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this.id
  http_method = aws_api_gateway_method.this.http_method
  status_code = aws_api_gateway_method_response.publish_message_ok_200.status_code

  depends_on = [aws_api_gateway_integration.this]
}

resource "aws_api_gateway_integration_response" "publish_message_fail_5xx" {
  rest_api_id       = aws_api_gateway_rest_api.this.id
  resource_id       = aws_api_gateway_resource.this.id
  selection_pattern = "5\\d{2}"
  http_method       = aws_api_gateway_method.this.http_method
  status_code       = aws_api_gateway_method_response.publish_message_fail_5xx.status_code

  depends_on = [aws_api_gateway_integration.this]
}

resource "aws_api_gateway_integration_response" "publish_message_fail_4xx" {
  rest_api_id       = aws_api_gateway_rest_api.this.id
  resource_id       = aws_api_gateway_resource.this.id
  selection_pattern = "4\\d{2}"
  http_method       = aws_api_gateway_method.this.http_method
  status_code       = aws_api_gateway_method_response.publish_message_fail_4xx.status_code

  depends_on = [aws_api_gateway_integration.this]
}

resource "aws_api_gateway_model" "this" {
  rest_api_id  = aws_api_gateway_rest_api.this.id
  name         = "MessageModel"
  description  = "Message model"
  content_type = "application/json"
  schema       = data.template_file.message_schema.rendered
}

data "template_file" "message_schema" {
  template = file("${path.module}/templates/request_schema.json")
}

resource "aws_api_gateway_request_validator" "this" {
  name                  = "apigw-validate-request"
  rest_api_id           = aws_api_gateway_rest_api.this.id
  validate_request_body = true
}

resource "aws_api_gateway_stage" "this" {
  stage_name = "main"
  rest_api_id = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = "main"

  triggers = {
    redeployment = sha1(join(",", list(
      jsonencode(aws_api_gateway_integration.this),
    )))
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_api_gateway_integration.this, aws_api_gateway_method.this]
}

resource "aws_sqs_queue" "this" {
  name = "message-queue"
}