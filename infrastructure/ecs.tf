resource "aws_ecs_cluster" "live_chat" {
  name = "${var.project}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.live_chat.arn
  }
}

# Service Connect namespace, so services reach each other by short DNS name
# (message-api, rpc-server, anycable-go) the same way the docker-compose setup does,
# without exposing rpc-server or the internal broadcast port publicly.
resource "aws_service_discovery_http_namespace" "live_chat" {
  name = var.project
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project}/frontend"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "message_api" {
  name              = "/ecs/${var.project}/message-api"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "rpc_server" {
  name              = "/ecs/${var.project}/rpc-server"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "anycable_go" {
  name              = "/ecs/${var.project}/anycable-go"
  retention_in_days = 30
}

##### message-api #####

resource "aws_ecs_task_definition" "message_api" {
  family                   = "${var.project}-message-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu["message-api"]
  memory                   = var.task_memory["message-api"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.message_api_task.arn

  container_definitions = jsonencode([
    {
      name      = "message-api"
      image     = "${aws_ecr_repository.message_api.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [
        { name = "http", containerPort = 3001, protocol = "tcp" }
      ]
      environment = [
        { name = "RAILS_ENV", value = "production" },
        { name = "FRONTEND_ORIGIN", value = "https://${var.domain_name}" },
        # anycable-go serves /_broadcast on the same port as the WebSocket server (8080),
        # not a separate port — see the comment on the anycable-go security group.
        { name = "ANYCABLE_HTTP_BROADCAST_URL", value = "http://anycable-go:8080/_broadcast" },
        # The Dockerfile's final stage runs as a non-root user (USER 1000:1000), which
        # can't bind port 80 (a privileged port) on Fargate's kernel — even though it
        # works locally on some Docker setups. Point Thruster at 3001 (Puma/Rails itself
        # still binds its own default of 3000 behind it — reusing 3000 here would make
        # Thruster and Puma fight over the same port: "Address already in use").
        { name = "HTTP_PORT", value = "3001" },
      ]
      secrets = [
        { name = "RAILS_MASTER_KEY", valueFrom = aws_secretsmanager_secret.rails_master_key.arn },
        { name = "ANYCABLE_SECRET", valueFrom = aws_secretsmanager_secret.anycable_secret.arn },
        { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.message_api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "message_api" {
  name            = "message-api"
  cluster         = aws_ecs_cluster.live_chat.id
  task_definition = aws_ecs_task_definition.message_api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Rails boot (db:prepare against RDS on cold connection) can take 30-40s; without a
  # grace period the ALB health check starts failing the new task before it's ready,
  # and ECS kills it and keeps the old one instead of completing the rollout.
  health_check_grace_period_seconds = 90

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.message_api_task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.message_api_tg.arn
    container_name   = "message-api"
    container_port   = 3001
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.live_chat.arn

    service {
      port_name      = "http"
      discovery_name = "message-api"
      client_alias {
        port     = 3001
        dns_name = "message-api"
      }
    }
  }

  depends_on = [aws_lb_listener.http]
}

##### rpc-server #####
# Same codebase/image as message-api, run with a different command. Internal only
# (called by anycable-go over Service Connect) — not attached to any load balancer.

resource "aws_ecs_task_definition" "rpc_server" {
  family                   = "${var.project}-rpc-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu["rpc-server"]
  memory                   = var.task_memory["rpc-server"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.rpc_server_task.arn

  container_definitions = jsonencode([
    {
      name      = "rpc-server"
      image     = "${aws_ecr_repository.message_api.repository_url}:${var.image_tag}"
      essential = true
      command   = ["bundle", "exec", "anycable"]
      portMappings = [
        { name = "grpc", containerPort = 50051, protocol = "tcp" }
      ]
      environment = [
        { name = "RAILS_ENV", value = "production" },
        { name = "ANYCABLE_RPC_HOST", value = "0.0.0.0:50051" },
      ]
      secrets = [
        { name = "RAILS_MASTER_KEY", valueFrom = aws_secretsmanager_secret.rails_master_key.arn },
        { name = "ANYCABLE_SECRET", valueFrom = aws_secretsmanager_secret.anycable_secret.arn },
        { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rpc_server.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "rpc_server" {
  name            = "rpc-server"
  cluster         = aws_ecs_cluster.live_chat.id
  task_definition = aws_ecs_task_definition.rpc_server.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.rpc_task.id]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.live_chat.arn

    service {
      port_name      = "grpc"
      discovery_name = "rpc-server"
      client_alias {
        port     = 50051
        dns_name = "rpc-server"
      }
    }
  }

}

##### anycable-go-pro #####

resource "aws_ecs_task_definition" "anycable_go" {
  family                   = "${var.project}-anycable-go"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu["anycable-go"]
  memory                   = var.task_memory["anycable-go"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.anycable_go_task.arn

  container_definitions = jsonencode([
    {
      name      = "anycable-go"
      image     = var.anycable_go_image
      essential = true
      repositoryCredentials = {
        credentialsParameter = aws_secretsmanager_secret.ghcr_credentials.arn
      }
      portMappings = [
        # WebSocket and the HTTP broadcast endpoint (/_broadcast) both live on this
        # one port — see the security group comment for why there's no 8090 here.
        { name = "ws", containerPort = 8080, protocol = "tcp" },
      ]
      environment = [
        { name = "ANYCABLE_HOST", value = "0.0.0.0" },
        { name = "ANYCABLE_PORT", value = "8080" },
        { name = "ANYCABLE_RPC_HOST", value = "rpc-server:50051" },
        # Redis Brokerを有効化 (Reliable Streams / history + セッション再開)
        { name = "ANYCABLE_BROKER", value = "redis" },
        # message-apiからのHTTPブロードキャストを引き続き受け付けつつ、
        # ノード間の再配信にredisx(Redis Streams)も使う
        { name = "ANYCABLE_BROADCAST_ADAPTER", value = "http,redisx" },
        # AnyCable複数台間の再配信
        { name = "ANYCABLE_PUBSUB", value = "redis" },
        { name = "ANYCABLE_HISTORY_LIMIT", value = "100" },
        { name = "ANYCABLE_HISTORY_TTL", value = "300" },
        { name = "ANYCABLE_SESSIONS_TTL", value = "300" },
        { name = "ANYCABLE_PRESETS", value = "broker" },
        { name = "ANYCABLE_PRESENCE", value = "true" },
        { name = "ANYCABLE_PRESENCE_TTL", value = "15" },
      ]
      secrets = [
        { name = "ANYCABLE_REDIS_URL", valueFrom = aws_secretsmanager_secret.valkey_url.arn },
        { name = "ANYCABLE_SECRET", valueFrom = aws_secretsmanager_secret.anycable_secret.arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.anycable_go.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "anycable_go" {
  name            = "anycable-go-pro"
  cluster         = aws_ecs_cluster.live_chat.id
  task_definition = aws_ecs_task_definition.anycable_go.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.anycable_task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.anycable_tg.arn
    container_name   = "anycable-go"
    container_port   = 8080
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.live_chat.arn

    service {
      port_name      = "ws"
      discovery_name = "anycable-go"
      client_alias {
        port     = 8080
        dns_name = "anycable-go"
      }
    }
  }

  depends_on = [aws_lb_listener.tls]
}

##### frontend #####
# NOTE: frontend/ does not yet have a production Dockerfile — this task definition can't
# actually be deployed until one is added and pushed to aws_ecr_repository.frontend. It's
# wired up now so the rest of the stack (SG, target group, ALB routing, IAM, Service
# Connect) doesn't need to change again once that image exists.

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu["frontend"]
  memory                   = var.task_memory["frontend"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.frontend_task.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.frontend.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [
        { name = "http", containerPort = 5173, protocol = "tcp" }
      ]
      # Vite bakes VITE_* into the static bundle at `docker build` time (import.meta.env),
      # so they can't be set here as container runtime env vars — pass them as build args
      # instead, e.g.:
      #   docker build \
      #     --build-arg VITE_API_BASE_URL=https://${var.api_subdomain}.${var.domain_name} \
      #     --build-arg VITE_CABLE_URL=wss://${var.cable_subdomain}.${var.domain_name}/cable \
      #     -t ${aws_ecr_repository.frontend.repository_url}:${var.image_tag} frontend/
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "frontend" {
  name            = "frontend"
  cluster         = aws_ecs_cluster.live_chat.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.frontend_task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = "frontend"
    container_port   = 5173
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.live_chat.arn

    service {
      port_name      = "http"
      discovery_name = "frontend"
      client_alias {
        port     = 5173
        dns_name = "frontend"
      }
    }
  }

  depends_on = [aws_lb_listener.http]
}
