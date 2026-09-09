output "ivs_stream_state_change_rule_arn" {
  description = "ARN of the EventBridge rule matching IVS Stream State Change events"
  value       = aws_cloudwatch_event_rule.ivs_stream_state_change.arn
}
