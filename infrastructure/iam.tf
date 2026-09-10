data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

##### Shared task execution role #####
# Used by the ECS agent to pull images from ECR, write to CloudWatch Logs, and resolve
# `secrets` (RAILS_MASTER_KEY / ANYCABLE_SECRET / Valkey URL) from Secrets Manager at
# task startup. This is distinct from the per-service task roles below, which are for
# AWS API calls made by application code at runtime.
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution_secrets" {
  statement {
    sid     = "ReadTaskSecrets"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.rails_master_key.arn,
      aws_secretsmanager_secret.anycable_secret.arn,
      aws_secretsmanager_secret.valkey_url.arn,
      aws_secretsmanager_secret.ghcr_credentials.arn,
      aws_secretsmanager_secret.database_url.arn,
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name   = "${var.project}-ecs-task-execution-secrets"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution_secrets.json
}

##### Per-service task roles #####
# Empty for now (none of the services call AWS APIs from application code yet); kept
# separate per service so least-privilege permissions can be attached later without
# touching the execution role or other services.
resource "aws_iam_role" "frontend_task" {
  name               = "${var.project}-frontend-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role" "message_api_task" {
  name               = "${var.project}-message-api-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role" "rpc_server_task" {
  name               = "${var.project}-rpc-server-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role" "anycable_go_task" {
  name               = "${var.project}-anycable-go-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}
