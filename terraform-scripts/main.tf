# S3 Bucket for Raw Ingestion (Bronze Layer)
resource "aws_s3_bucket" "bronze_layer" {
  bucket        = "${var.project_name}-bronze-${var.environment}"
  force_destroy = true

  tags = {
    Name        = "Bronze Layer"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 Bucket for Cleaned Data (Silver Layer)
resource "aws_s3_bucket" "silver_layer" {
  bucket        = "${var.project_name}-silver-${var.environment}"
  force_destroy = true
  tags = {
    Name        = "Silver Layer"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 Bucket for Analytics Data (Gold Layer)
resource "aws_s3_bucket" "gold_layer" {
  bucket        = "${var.project_name}-gold-${var.environment}"
  force_destroy = true

  tags = {
    Name        = "Gold Layer"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 Bucket for Failed/Malformed Records (DLQ)
resource "aws_s3_bucket" "dlq_layer" {
  bucket        = "${var.project_name}-dlq-${var.environment}"
  force_destroy = true

  tags = {
    Name        = "Dead Letter Queue"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_ecr_repository" "ingestion_repo" {
  name                 = "nhtsa-ingestion-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 1. CloudWatch Log Group for container output
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/nhtsa-ingestion"
  retention_in_days = 7
}

# 2. ECS Cluster
resource "aws_ecs_cluster" "lakehouse_cluster" {
  name = "nhtsa-lakehouse-cluster"
}

# 3. IAM Execution Role (pulls image from ECR & sends logs to CloudWatch)
resource "aws_iam_role" "ecs_execution_role" {
  name = "nhtsa_ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 4. IAM Task Role (grants Python/boto3 access to S3 Bronze)
resource "aws_iam_role" "ecs_task_role" {
  name = "nhtsa_ecs_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_s3_write_policy" {
  name        = "nhtsa_ecs_s3_write_policy"
  description = "Allows ingestion container to write data to Bronze bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.bronze_layer.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_s3_write_policy.arn
}

# 5. ECS Fargate Task Definition
resource "aws_ecs_task_definition" "ingestion_task" {
  family                   = "nhtsa-ingestion-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 512 MB
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "nhtsa-ingestion-container"
      image     = "${aws_ecr_repository.ingestion_repo.repository_url}:latest"
      essential = true

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = "us-east-2"
          "awslogs-stream-prefix" = "ingestion"
        }

      }
    }
  ])
}

# 1. Zip the Lambda code automatically
# 2. IAM Role for Lambda
resource "aws_iam_role" "lambda_validator_role" {
  name = "nhtsa_lambda_validator_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# CloudWatch logs policy for Lambda
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_validator_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 Read permission for the Bronze bucket
resource "aws_iam_policy" "lambda_s3_read_policy" {
  name        = "nhtsa_lambda_s3_policy"
  description = "Allows Lambda validator to manage Bronze and DLQ layers"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.bronze_layer.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.dlq_layer.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_read_attach" {
  role       = aws_iam_role.lambda_validator_role.name
  policy_arn = aws_iam_policy.lambda_s3_read_policy.arn
}

# 3. Lambda Function
resource "aws_lambda_function" "validator" {
  filename         = "${path.module}/lambda_validator.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_validator.zip")
  function_name    = "nhtsa-bronze-validator"
  role             = aws_iam_role.lambda_validator_role.arn
  handler          = "lambda_validator.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      DLQ_BUCKET = aws_s3_bucket.dlq_layer.id
    }
  }
}

# 4. Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.validator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bronze_layer.arn
}

# 5. S3 Bucket Notification Trigger
resource "aws_s3_bucket_notification" "bronze_upload_trigger" {
  bucket = aws_s3_bucket.bronze_layer.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.validator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_s3_to_invoke_lambda]
}