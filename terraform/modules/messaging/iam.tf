data "template_file" "apigw_vpc_policy" {
  template = file("${path.module}/templates/apigw_vpc_policy.json")

  vars = {
    vpcId = var.vpc_id
  }
}

data "template_file" "apigw_to_sqs_policy" {
  template = file("${path.module}/templates/apigw_to_sqs_policy.json")

  vars = {
    sqsArn = aws_sqs_queue.this.arn
  }
}

data "template_file" "apigw_role" {
  template = file("${path.module}/templates/apigw_role.json")
}

resource "aws_iam_role" "this" {
  name               = "${var.apigw_name}-role"
  assume_role_policy = data.template_file.apigw_role.rendered
}

resource "aws_iam_role_policy" "apigw_to_sqs_policy" {
  name = "apigw_to_sqs_policy"
  role = aws_iam_role.this.id

  policy = data.template_file.apigw_to_sqs_policy.rendered
}
