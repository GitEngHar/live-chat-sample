# Primary database for message-api / rpc-server (users, rooms — see config/database.yml).
# Both run as separate ECS tasks with independent ephemeral filesystems, so this data
# needs to live somewhere both can reach; a real networked DB avoids the SQLite-over-NFS
# locking/permission issues a shared EFS volume would carry instead.
resource "aws_db_subnet_group" "primary" {
  name       = "${var.project}-db"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "PostgreSQL ingress from message-api and rpc-server"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL, from message-api"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.message_api_task.id]
  }

  ingress {
    description     = "PostgreSQL, from rpc-server"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rpc_task.id]
  }

  tags = { Name = "${var.project}-rds-sg" }
}

resource "random_password" "db" {
  length  = 32
  special = false # embedded in a URL below; keep it alphanumeric to sidestep URL-encoding pitfalls entirely
}

resource "aws_db_instance" "primary" {
  identifier = "${var.project}-db"

  engine         = "postgres"
  engine_version = "17"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "message_api_production"
  username = "message_api"
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.primary.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = { Name = "${var.project}-db" }
}

resource "aws_secretsmanager_secret" "database_url" {
  name = "${var.project}/${var.environment}/database-url"
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id     = aws_secretsmanager_secret.database_url.id
  secret_string = "postgresql://${aws_db_instance.primary.username}:${urlencode(random_password.db.result)}@${aws_db_instance.primary.address}:${aws_db_instance.primary.port}/${aws_db_instance.primary.db_name}"
}
