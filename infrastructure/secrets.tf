resource "aws_secretsmanager_secret" "rails_master_key" {
  name = "${var.project}/${var.environment}/rails-master-key"
}

resource "aws_secretsmanager_secret_version" "rails_master_key" {
  secret_id     = aws_secretsmanager_secret.rails_master_key.id
  secret_string = var.rails_master_key
}

# Shared secret between message-api/rpc-server (anycable-rails) and anycable-go, used to
# authenticate WebSocket connections. Generated once and stored, never entered by hand.
resource "random_password" "anycable_secret" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "anycable_secret" {
  name = "${var.project}/${var.environment}/anycable-secret"
}

resource "aws_secretsmanager_secret_version" "anycable_secret" {
  secret_id     = aws_secretsmanager_secret.anycable_secret.id
  secret_string = random_password.anycable_secret.result
}

# ghcr.io/anycable/anycable-go-pro is a private image (AnyCable Pro license); ECS needs
# registry credentials to pull it. Set ghcr_username / ghcr_token (a GitHub PAT with
# read:packages, tied to the account/org the license is granted to) via terraform.tfvars
# or -var — until then this secret holds empty credentials and the pull keeps failing
# with 401, same as it does today.
resource "aws_secretsmanager_secret" "ghcr_credentials" {
  name = "${var.project}/${var.environment}/ghcr-credentials"
}

resource "aws_secretsmanager_secret_version" "ghcr_credentials" {
  secret_id = aws_secretsmanager_secret.ghcr_credentials.id
  secret_string = jsonencode({
    username = var.ghcr_username
    password = var.ghcr_token
  })
}
