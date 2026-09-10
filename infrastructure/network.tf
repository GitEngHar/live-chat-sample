module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.project}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  # コスト削減のため NAT Gateway は使わない。
  # ECS タスク (Fargate) は public subnet + パブリック IP を割り当て、IGW 経由で直接
  # ECR/CloudWatch Logs/Secrets Manager にアクセスする。
  # ElastiCache (Valkey) はインターネットアクセスが不要なので private subnet に置く。
  enable_nat_gateway = false
  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

##### Security Groups #####

resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "Ingress from the internet to the ALB (frontend/message-api)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP (redirects to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-alb-sg" }
}

resource "aws_security_group" "nlb" {
  name        = "${var.project}-nlb-sg"
  description = "Ingress from the internet to the NLB (anycable-go WebSocket)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "WSS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-nlb-sg" }
}

resource "aws_security_group" "frontend_task" {
  name        = "${var.project}-frontend-task-sg"
  description = "ECS task SG for the frontend service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "From ALB"
    from_port       = 5173
    to_port         = 5173
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-frontend-task-sg" }
}

resource "aws_security_group" "message_api_task" {
  name        = "${var.project}-message-api-task-sg"
  description = "ECS task SG for the message-api service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "From ALB"
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-message-api-task-sg" }
}

resource "aws_security_group" "anycable_task" {
  name        = "${var.project}-anycable-task-sg"
  description = "ECS task SG for the anycable-go-pro service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "WebSocket, from NLB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb.id]
  }

  # anycable-go serves the WebSocket and the HTTP broadcast endpoint (POST /_broadcast)
  # on the same port (see its own boot log: "Accept broadcast requests at
  # http://0.0.0.0:8080/_broadcast") — there's no separate broadcast port to open.
  ingress {
    description     = "HTTP broadcast, from message-api"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.message_api_task.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-anycable-task-sg" }
}

resource "aws_security_group" "rpc_task" {
  name        = "${var.project}-rpc-task-sg"
  description = "ECS task SG for the rpc-server service (internal gRPC only, called by anycable-go)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "gRPC, from anycable-go"
    from_port       = 50051
    to_port         = 50051
    protocol        = "tcp"
    security_groups = [aws_security_group.anycable_task.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-rpc-task-sg" }
}

##### Target Groups #####

# name_prefix (max 6 chars) + create_before_destroy: a plain `name` can't be reused for
# forced replacements (e.g. changing `port`) because the old target group can't be
# deleted while a listener/rule still references it, and AWS won't allow two target
# groups with the same name to coexist during the swap.
resource "aws_lb_target_group" "anycable_tg" {
  name_prefix = "any-"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    protocol = "TCP"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "message_api_tg" {
  name_prefix = "api-"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    protocol = "HTTP"
    path     = "/up"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "frontend_tg" {
  name_prefix = "fe-"
  port        = 5173
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    protocol = "HTTP"
    path     = "/"
  }

  lifecycle {
    create_before_destroy = true
  }
}

##### Load Balancers #####

# Network Load Balancer: TLS termination for the anycable-go WebSocket endpoint.
resource "aws_lb" "live_chat_net_lb" {
  name               = "${var.project}-net-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [for subnet in module.vpc.public_subnets : subnet]
  security_groups    = [aws_security_group.nlb.id]

  tags = {
    Environment = var.environment
  }
}

resource "aws_lb_listener" "tls" {
  load_balancer_arn = aws_lb.live_chat_net_lb.arn
  port              = 443
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.site.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.anycable_tg.arn
  }
}

# Application Load Balancer: frontend (default) + message-api (path-based routing on /api/*).
resource "aws_lb" "live_chat_app_lb" {
  name               = "${var.project}-app-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [for subnet in module.vpc.public_subnets : subnet]
  security_groups    = [aws_security_group.alb.id]

  tags = {
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.live_chat_app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.live_chat_app_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.site.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

resource "aws_lb_listener_rule" "message_api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.message_api_tg.arn
  }

  condition {
    host_header {
      values = ["${var.api_subdomain}.${var.domain_name}"]
    }
  }
}
