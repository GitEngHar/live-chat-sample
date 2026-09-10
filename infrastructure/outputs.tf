output "site_url" {
  description = "Frontend URL"
  value       = "https://${var.domain_name}"
}

output "api_url" {
  description = "message-api URL (host-routed on the same ALB as the frontend)"
  value       = "https://${var.api_subdomain}.${var.domain_name}"
}

output "cable_url" {
  description = "anycable-go WSS endpoint"
  value       = "wss://${var.cable_subdomain}.${var.domain_name}/cable"
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB (frontend + message-api, host-based routing)"
  value       = aws_lb.live_chat_app_lb.dns_name
}

output "nlb_dns_name" {
  description = "Public DNS name of the NLB (anycable-go WebSocket, wss://.../cable)"
  value       = aws_lb.live_chat_net_lb.dns_name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.live_chat.name
}

output "ecr_repository_urls" {
  value = {
    message_api = aws_ecr_repository.message_api.repository_url
    frontend    = aws_ecr_repository.frontend.repository_url
  }
}

output "valkey_primary_endpoint" {
  description = "Valkey primary endpoint (host only; see valkey_url secret for the full rediss:// URL with auth token)"
  value       = aws_elasticache_replication_group.valkey.primary_endpoint_address
}

output "secrets_manager_arns" {
  value = {
    rails_master_key = aws_secretsmanager_secret.rails_master_key.arn
    anycable_secret  = aws_secretsmanager_secret.anycable_secret.arn
    valkey_url       = aws_secretsmanager_secret.valkey_url.arn
  }
}
