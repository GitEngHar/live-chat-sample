# ElastiCache (Valkey) — AnyCable broker/pub-sub backend, replacing the `redis` container
# used in docker-compose for local dev. Replication group with Multi-AZ automatic
# failover, at-rest + in-transit encryption, and an AUTH token.

resource "aws_elasticache_subnet_group" "valkey" {
  name       = "${var.project}-valkey"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "valkey" {
  name        = "${var.project}-valkey-sg"
  description = "Valkey (ElastiCache) ingress from anycable-go only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Valkey, from anycable-go"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.anycable_task.id]
  }

  tags = { Name = "${var.project}-valkey-sg" }
}

# AWS auth tokens may not contain '/', '"', or '@'.
resource "random_password" "valkey_auth" {
  length           = 32
  special          = true
  override_special = "!&#$^<>-"
}

resource "aws_elasticache_replication_group" "valkey" {
  replication_group_id = "${var.project}-valkey"
  description          = "Valkey for AnyCable broker/pub-sub"

  engine         = "valkey"
  engine_version = var.valkey_engine_version
  node_type      = var.valkey_node_type
  port           = 6379

  num_cache_clusters         = var.valkey_num_cache_clusters
  automatic_failover_enabled = var.valkey_num_cache_clusters > 1
  multi_az_enabled           = var.valkey_num_cache_clusters > 1

  subnet_group_name  = aws_elasticache_subnet_group.valkey.name
  security_group_ids = [aws_security_group.valkey.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"
  auth_token                 = random_password.valkey_auth.result

  # Dev environment: apply engine version / config changes right away instead of
  # waiting for the next maintenance window.
  apply_immediately = true
}

resource "aws_secretsmanager_secret" "valkey_url" {
  name = "${var.project}/${var.environment}/valkey-url"
}

resource "aws_secretsmanager_secret_version" "valkey_url" {
  secret_id = aws_secretsmanager_secret.valkey_url.id
  # urlencode the token: it can contain URI-reserved characters (e.g. "#", which starts
  # a fragment) that would otherwise silently truncate or corrupt the URL.
  secret_string = "rediss://:${urlencode(random_password.valkey_auth.result)}@${aws_elasticache_replication_group.valkey.primary_endpoint_address}:6379"
}
