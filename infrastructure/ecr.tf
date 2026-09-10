# anycable-go-pro is pulled directly from ghcr.io (see var.anycable_go_image); no ECR repo needed for it.

resource "aws_ecr_repository" "message_api" {
  name                 = "${var.project}/message-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "message_api" {
  repository = aws_ecr_repository.message_api.name
  policy     = local.ecr_expire_untagged_policy
}

# frontend does not yet have a production Dockerfile in frontend/ — this repository is
# created so the ECS task definition below has somewhere to pull from once one is added.
resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project}/frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name
  policy     = local.ecr_expire_untagged_policy
}

locals {
  ecr_expire_untagged_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images after 14 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 14
      }
      action = {
        type = "expire"
      }
    }]
  })
}
