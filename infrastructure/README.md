# infrastructure

Terraform for the AWS resources behind this project: an ECS Fargate cluster
running the four services (`frontend`, `message-api`, `rpc-server`,
`anycable-go-pro`), an ALB (frontend + message-api) and NLB (anycable-go WSS),
an ElastiCache (Valkey) replication group used as the AnyCable broker/pub-sub
backend, IAM roles/policies, ECR repositories, and Secrets Manager secrets.

| File          | Contents                                                |
| ------------- | -------------------------------------------------------- |
| `main.tf`     | Provider / terraform block                               |
| `network.tf`  | VPC, security groups, ALB, NLB, target groups, listeners  |
| `dns.tf`      | Route 53 zone lookup, ACM cert + DNS validation, alias records |
| `ecs.tf`      | ECS cluster, Service Connect namespace, task defs/services |
| `iam.tf`      | Task execution role + per-service task roles              |
| `ecr.tf`      | ECR repos (message-api, frontend)                         |
| `secrets.tf`  | Secrets Manager: rails master key, anycable shared secret |
| `valkey.tf`   | ElastiCache (Valkey) replication group + secret            |
| `variables.tf`| Inputs                                                    |
| `outputs.tf`  | Outputs                                                   |

`frontend/Dockerfile` builds a static bundle (Vite) served by nginx on port
5173. `VITE_API_BASE_URL` / `VITE_CABLE_URL` are baked in at build time
(`import.meta.env`), so they must be passed as `--build-arg`s when building
the image, not as ECS task env vars — see the comment in `ecs.tf` next to the
`frontend` task definition for the exact command, using `alb_dns_name` /
`nlb_dns_name` from `terraform output`.

## Prerequisites

- Terraform >= 1.5 (`terraform version`)
- AWS credentials for the target account, either via environment variables
  (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN`) or a
  named profile in `~/.aws/config` / `~/.aws/credentials`

## Usage

```bash
cd infrastructure

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: domain_name defaults to gitenghar-live-chat.com (must be a
# public Route 53 hosted zone in this account); override aws_region/aws_profile as needed

terraform init
terraform plan -var="rails_master_key=$(cat ../message-api/config/master.key)"
```

State is local (`terraform.tfstate` in this directory, gitignored) — there is
no remote backend configured, so `plan`/`apply` work standalone on a laptop.

To apply against a non-default profile without editing `terraform.tfvars`:

```bash
terraform plan -var="aws_profile=your-profile-name"
```
