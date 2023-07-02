data "archive_file" "visitorarchive" {
  source_file = "function.py"
  output_path = "function.zip"
  type        = "zip"
}

resource "aws_s3_bucket" "functionbucket" {
  bucket = "oscarvisitorcounter"
}
resource "aws_s3_object" "lambdavisitor" {
  bucket = aws_s3_bucket.functionbucket.id
  key    = "fucntion.zip"
  source = data.archive_file.visitorarchive.output_path
  etag   = filemd5(data.archive_file.visitorarchive.output_path)
}
resource "aws_dynamodb_table" "visitorcounter" {
  name         = "visitor-counter"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "id"
    type = "S"
  }
  hash_key = "id"
  ttl {
    enabled        = true
    attribute_name = "expiryPeriod"
  }
  point_in_time_recovery {
    enabled = true
  }
  server_side_encryption {
    enabled = true
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb-lambda-policy" {
  name = "dynamodb_lambda_policy"
  role = aws_iam_role.iam_for_lambda.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : ["dynamodb:*"],
        "Resource" : "${aws_dynamodb_table.visitorcounter.arn}"
      }
    ]
  })
}


resource "aws_lambda_function" "visitor-count" {
  s3_bucket = aws_s3_bucket.functionbucket.id
  s3_key    = aws_s3_object.lambdavisitor.key
  handler   = "function.lambda_handler"
  environment {
    variables = {
      databaseName = aws_dynamodb_table.visitorcounter.name
    }
  }
  timeout       = 10
  runtime       = "python3.9"
  function_name = "visitor-counter"
  role          = aws_iam_role.iam_for_lambda.arn
}

resource "aws_lambda_function_url" "visitor-count" {
  function_name      = aws_lambda_function.visitor-count.function_name
  authorization_type = "AWS_IAM"

  cors {
    allow_credentials = true
    allow_origins     = ["https://www.oscarcorner.com"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}
