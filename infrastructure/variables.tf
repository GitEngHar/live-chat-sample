variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use for authentication"
  type        = string
  default     = "cinema-ai"
}

variable "project" {
  description = "Project name, used as a prefix/tag for created resources"
  type        = string
  default     = "live-chat"
}

variable "environment" {
  description = "Deployment environment name (used for tagging)"
  type        = string
  default     = "dev"
}

# --- DNS / certificates ---
# The domain must already be registered with a public Route 53 hosted zone in this
# account (dns.tf reads it via data "aws_route53_zone"). Terraform requests and
# DNS-validates the ACM certificate and creates the alias records.

variable "domain_name" {
  description = "Apex domain, already hosted in Route 53 (frontend + message-api /api/* on the ALB)"
  type        = string
  default     = "gitenghar-live-chat.com"
}

variable "cable_subdomain" {
  description = "Subdomain for anycable-go's WSS endpoint (NLB), e.g. \"cable\" -> cable.<domain_name>"
  type        = string
  default     = "cable"
}

variable "api_subdomain" {
  description = "Subdomain for message-api, host-routed on the same ALB as the frontend (its routes aren't mounted under /api, so path-based routing can't be used), e.g. \"api\" -> api.<domain_name>"
  type        = string
  default     = "api"
}

# --- Container images ---

variable "anycable_go_image" {
  description = "Container image for the anycable-go-pro server (pulled directly from ghcr.io, not built from this repo)"
  type        = string
  default     = "ghcr.io/anycable/anycable-go-pro:1.6"
}

variable "ghcr_username" {
  description = "GitHub username/org for pulling the private anycable-go-pro image from ghcr.io"
  type        = string
  default     = ""
}

variable "ghcr_token" {
  description = "GitHub PAT (classic, read:packages scope) for pulling the private anycable-go-pro image from ghcr.io"
  type        = string
  sensitive   = true
  default     = ""
}

variable "image_tag" {
  description = "Tag to deploy for images built from this repo (message-api, rpc-server, frontend) and pushed to the ECR repositories created here"
  type        = string
  default     = "latest"
}

# --- Secrets (sensitive; supply via terraform.tfvars or -var, never commit) ---

variable "rails_master_key" {
  description = "Rails master key (config/master.key) for message-api / rpc-server"
  type        = string
  sensitive   = true
}

# --- ECS task sizing ---

variable "task_cpu" {
  description = "Map of Fargate task vCPU units per service"
  type        = map(number)
  default = {
    frontend    = 256
    message-api = 256
    rpc-server  = 256
    anycable-go = 256
  }
}

variable "task_memory" {
  description = "Map of Fargate task memory (MiB) per service"
  type        = map(number)
  default = {
    frontend    = 512
    message-api = 512
    rpc-server  = 512
    anycable-go = 512
  }
}

# --- Valkey (ElastiCache) ---

variable "valkey_node_type" {
  description = "ElastiCache node type for the Valkey replication group"
  type        = string
  default     = "cache.t4g.micro"
}

variable "valkey_engine_version" {
  description = "Valkey engine version. AnyCable's Redis-backed presence feature requires Valkey >= 9.0 (uses hash field TTL commands introduced there) — see https://docs.anycable.io/anycable-go/presence."
  type        = string
  default     = "9.1"
}

variable "valkey_num_cache_clusters" {
  description = "Number of nodes in the Valkey replication group (>= 2 for Multi-AZ automatic failover)"
  type        = number
  default     = 2
}
