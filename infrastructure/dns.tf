# Route 53 zone for the domain (already exists / registered outside this config).
data "aws_route53_zone" "primary" {
  name         = var.domain_name
  private_zone = false
}

# Single cert covering the apex (frontend on the ALB), the api subdomain (message-api,
# also on the ALB but host-routed — message-api's routes aren't mounted under /api and
# ALB forward actions can't rewrite paths) and the cable subdomain (anycable-go on the
# NLB, which can't share a hostname with the ALB).
resource "aws_acm_certificate" "site" {
  domain_name = var.domain_name
  subject_alternative_names = [
    "${var.api_subdomain}.${var.domain_name}",
    "${var.cable_subdomain}.${var.domain_name}",
  ]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.primary.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# Apex domain -> ALB (frontend)
resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.live_chat_app_lb.dns_name
    zone_id                = aws_lb.live_chat_app_lb.zone_id
    evaluate_target_health = true
  }
}

# api.<domain> -> same ALB (message-api, host-based routing)
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${var.api_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.live_chat_app_lb.dns_name
    zone_id                = aws_lb.live_chat_app_lb.zone_id
    evaluate_target_health = true
  }
}

# cable.<domain> -> NLB (anycable-go WSS)
resource "aws_route53_record" "cable" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${var.cable_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.live_chat_net_lb.dns_name
    zone_id                = aws_lb.live_chat_net_lb.zone_id
    evaluate_target_health = true
  }
}
